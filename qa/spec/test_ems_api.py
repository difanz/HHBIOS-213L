"""Execute the production EMS paths with manager failures at API boundaries."""
import os
import re
import struct
import subprocess

import pytest
from qa.spec.build import source_file, asm_includes
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

pytestmark = pytest.mark.unit
SYMBOLS = ('INT_7F', 'S_READ', 'D_HJ', 'D_HF', 'D_PMJ', 'D_PMF', 'D_SEG')


@pytest.fixture(scope='session')
def ems_binary(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('ems-api')
    source = source_file(source_dir, 'READ4.ASM').read_bytes()
    footer = b"DB 'HHEMS1'\r\nDW "+', '.join(SYMBOLS).encode()+b'\r\nCSEG ENDS'
    source, count = re.subn(rb'CSEG\s+ENDS', lambda _: footer, source)
    assert count == 1
    path = out / 'reader.asm'
    path.write_bytes(source)
    p = subprocess.run([assembler, '-q', '-Zm', '-bin', *asm_includes(source_dir),
                        '-Fo'+str(out / 'reader.com'), str(path)], capture_output=True,
                       env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    assert p.returncode == 0, p.stdout + p.stderr
    raw = (out / 'reader.com').read_bytes()
    symbols = dict(zip(SYMBOLS, struct.unpack_from('<7H', raw, raw.rindex(b'HHEMS1')+6)))
    return raw, symbols


def font_glyph(handle, index):
    """Distinct words expose wrong pages, offsets, fonts and copy lengths."""
    return struct.pack('<16H', *(index ^ (handle << 12) ^ (word * 0x421)
                                for word in range(16)))


def exercise(binary, entry, failure, glyph_index=0, traditional=False,
             last_page=15, flags=0x202):
    raw, symbols = binary
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    code, frame, stack = 0x10000, 0xe0000, 0x80000
    uc.mem_write(code+0x100, raw)
    caller_pages = b''.join(bytes([0x31+i])*16384 for i in range(4))
    uc.mem_write(frame, caller_pages)
    previous_glyph = bytes([0x55])*32
    uc.mem_write(code, previous_glyph)
    guard = bytes([0xa5])*32
    uc.mem_write(code+32, guard)
    glyph = font_glyph(12 if traditional else 11, glyph_index)
    for name, value in dict(D_HJ=11, D_HF=12, D_PMJ=last_page,
                            D_PMF=last_page, D_SEG=frame//16).items():
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
        if entry == 'INT_7F':
            assert not get('EFLAGS') & 0x200, 'EMS mapping must be atomic'
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
            handle, page = get('DX'), get('BX')
            assert handle in (11, 12) and 0 <= page < 16
            uc.mem_write(frame+al*16384, b''.join(
                font_glyph(handle, page*512+i) for i in range(512)))
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
    hanzi = ((glyph_index//94+0xa1) << 8) | (glyph_index%94+0xa1)
    preserved = dict(AX=0 if traditional else 0x100, BX=0x1234, CX=0x2345,
                     SI=0x3456, DI=0x4567, BP=0x5678, DS=0x7000, ES=0x6000)
    inputs = preserved if entry == 'INT_7F' else dict(AX=ord('J'), DS=code//16, ES=code//16)
    for name, value in dict(CS=code//16, SS=stack//16, SP=0xff00,
                            EFLAGS=flags, DX=hanzi, **inputs).items():
        put(name, value)
    uc.mem_write(stack+0xff00, struct.pack('<3H', 0xff00, code//16, flags))
    uc.emu_start(code+symbols[entry], code+0xff00, count=10000)
    assert get('IP') == 0xff00
    assert get('SP') == 0xff00 + (6 if entry == 'INT_7F' else 2)
    assert bytes(uc.mem_read(frame, 65536)) == caller_pages
    assert state['saved'] is None
    if entry == 'INT_7F':
        assert {name: get(name) for name in preserved} == preserved
        assert get('DX') == code//16
        assert get('EFLAGS') & 0x600 == flags & 0x600, 'caller IF/DF changed'
        no_glyph = failure or glyph_index//512 > last_page
        assert bytes(uc.mem_read(code, 32)) == (previous_glyph if no_glyph else glyph)
        assert bytes(uc.mem_read(code+32, 32)) == guard, 'glyph buffer overrun'
    else:
        assert get('DS') == code//16
        assert get('EFLAGS') & 0x200, 'interrupts left disabled'
        assert bool(get('EFLAGS') & 1) == bool(failure)
        assert state['allocated'] == (failure is None)
        assert not state['opened']
    return state


@pytest.mark.parametrize('failure', [None, 'save', 'map0'])
@pytest.mark.parametrize('glyph_index', [0, 511, 512, 8177])
def test_ems_glyph_restores_caller_on_failure(ems_binary, failure, glyph_index):
    state = exercise(ems_binary, 'INT_7F', failure, glyph_index)
    if failure == 'save':
        assert state['calls'] == [(0x67, 0x47)]


@pytest.mark.parametrize('traditional', [False, True])
@pytest.mark.parametrize('glyph_index', sorted(
    {0, 93, 94, 8177} | {page*512+edge for page in range(1, 16) for edge in (-1, 0)}))
def test_ems_glyph_page_and_row_boundaries(ems_binary, glyph_index, traditional):
    exercise(ems_binary, 'INT_7F', None, glyph_index, traditional)


@pytest.mark.parametrize('flags', [0x002, 0x202, 0x602])
def test_ems_glyph_preserves_caller_flags(ems_binary, flags):
    exercise(ems_binary, 'INT_7F', None, 511, flags=flags)


@pytest.mark.parametrize('last_page,glyph_index', [(0, 512), (7, 4096), (15, 8192)])
def test_ems_glyph_beyond_last_page_keeps_previous_buffer(ems_binary, last_page, glyph_index):
    state = exercise(ems_binary, 'INT_7F', None, glyph_index, last_page=last_page)
    assert state['calls'] == []


@pytest.mark.parametrize('failure', [None, 'allocate', 'save', 'map0', 'map1'])
def test_ems_loader_releases_failed_allocations(ems_binary, failure):
    exercise(ems_binary, 'S_READ', failure)
