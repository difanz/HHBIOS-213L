"""Execute the production EMS paths with manager failures at API boundaries."""
import os
import re
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

pytestmark = pytest.mark.unit
SYMBOLS = ('INT_7F', 'S_READ', 'D_HJ', 'D_HF', 'D_PMJ', 'D_PMF', 'D_SEG')


@pytest.fixture(scope='session')
def ems_binary(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('ems-api')
    source = (source_dir / 'READ4.ASM').read_bytes()
    footer = b"DB 'HHEMS1'\r\nDW "+', '.join(SYMBOLS).encode()+b'\r\nCSEG ENDS'
    source, count = re.subn(rb'CSEG\s+ENDS', lambda _: footer, source)
    assert count == 1
    path = out / 'reader.asm'
    path.write_bytes(source)
    p = subprocess.run([assembler, '-q', '-Zm', '-bin', '-I'+str(source_dir),
                        '-Fo'+str(out / 'reader.com'), str(path)], capture_output=True,
                       env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    assert p.returncode == 0, p.stdout + p.stderr
    raw = (out / 'reader.com').read_bytes()
    symbols = dict(zip(SYMBOLS, struct.unpack_from('<7H', raw, raw.rindex(b'HHEMS1')+6)))
    return raw, symbols


def exercise(binary, entry, failure):
    raw, symbols = binary
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    code, frame, stack = 0x10000, 0xe0000, 0x80000
    uc.mem_write(code+0x100, raw)
    caller_pages = b''.join(bytes([0x31+i])*16384 for i in range(4))
    uc.mem_write(frame, caller_pages)
    previous_glyph = bytes([0x55])*32
    uc.mem_write(code, previous_glyph)
    glyph = bytes(range(32))
    for name, value in dict(D_HJ=11, D_HF=12, D_PMJ=15, D_PMF=15, D_SEG=frame//16).items():
        uc.mem_write(code+symbols[name], struct.pack('<H', value))
    state = dict(saved=None, allocated=False, opened=False, calls=[])

    def get(name):
        return uc.reg_read(getattr(reg, 'UC_X86_REG_'+name))

    def put(name, value):
        uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)

    def interrupt(uc, number, _):
        ah, al = get('AX') >> 8, get('AX') & 255
        state['calls'].append((number, ah))
        if number == 0x21:
            put('EFLAGS', get('EFLAGS') & ~1)
            if ah == 0x3d:
                state['opened'] = True
                put('AX', 7)
            elif ah == 0x3f:
                assert state['opened'] and get('BX') == 7
                put('AX', 64)  # short read ends this small font fixture
            elif ah == 0x3e:
                assert state['opened'] and get('BX') == 7
                state['opened'] = False
                put('AX', 0)
            else:
                pytest.fail(f'unexpected DOS function {ah:02x}')
            return
        assert number == 0x67
        failed = (failure == 'allocate' and ah == 0x43 or
                  failure == 'save' and ah == 0x47 or
                  failure == f'map{al}' and ah == 0x44)
        put('AX', (0x8800 if failed else 0) | al)
        if failed:
            return
        if ah == 0x43:
            state['allocated'] = True
            put('DX', 11)
        elif ah == 0x47:
            assert state['saved'] is None
            assert get('DX') in (11, 12), 'must use the font handle, not the caller handle'
            state['saved'] = bytes(uc.mem_read(frame, 65536))
        elif ah == 0x44:
            uc.mem_write(frame+al*16384, glyph + bytes(16384-32))
        elif ah == 0x48:
            assert state['saved'] is not None
            uc.mem_write(frame, state['saved'])
            state['saved'] = None
        elif ah == 0x45:
            assert state['allocated']
            state['allocated'] = False
        else:
            pytest.fail(f'unexpected EMS function {ah:02x}')

    uc.hook_add(UC_HOOK_INTR, interrupt)
    for name, value in dict(CS=code//16, DS=code//16, ES=code//16,
                            SS=stack//16, SP=0xff00, EFLAGS=0x202,
                            AX=0x100 if entry == 'INT_7F' else ord('J'), DX=0xa1a1).items():
        put(name, value)
    uc.mem_write(stack+0xff00, struct.pack('<3H', 0xff00, code//16, 0x202))
    uc.emu_start(code+symbols[entry], code+0xff00, count=10000)
    assert get('IP') == 0xff00
    assert get('SP') == 0xff00 + (6 if entry == 'INT_7F' else 2)
    assert get('DS') == code//16
    assert get('EFLAGS') & 0x200, 'interrupts left disabled'
    assert bytes(uc.mem_read(frame, 65536)) == caller_pages
    assert state['saved'] is None
    if entry == 'INT_7F':
        assert bytes(uc.mem_read(code, 32)) == (previous_glyph if failure else glyph)
    else:
        assert bool(get('EFLAGS') & 1) == bool(failure)
        assert state['allocated'] == (failure is None)
        assert not state['opened']
    return state


@pytest.mark.parametrize('failure', [None, 'save', 'map0'])
def test_ems_glyph_restores_caller_on_failure(ems_binary, failure):
    state = exercise(ems_binary, 'INT_7F', failure)
    if failure == 'save':
        assert state['calls'] == [(0x67, 0x47)]


@pytest.mark.parametrize('failure', [None, 'allocate', 'save', 'map0', 'map1'])
def test_ems_loader_releases_failed_allocations(ems_binary, failure):
    exercise(ems_binary, 'S_READ', failure)
