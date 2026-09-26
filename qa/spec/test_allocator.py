"""Fault injection at the DOS API boundary of each production UMB allocator."""
import os
import re
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

pytestmark = pytest.mark.unit
MODULES = ('CGA', 'CKBD', 'EGA', 'HGA', 'INT10K', 'INT10V', 'PRNT', 'PRTH',
           'READ16', 'READ24', 'READ3', 'READ4', 'READ5', 'READSL', 'VGA')


@pytest.fixture(scope='session', params=MODULES)
def allocator(request, source_dir, assembler, tmp_path_factory):
    name = request.param
    source = (source_dir / f'{name}.ASM').read_bytes()
    routines = []
    for symbol in ('S_GETUMB', 'S_UMB', 'S_GETXMS'):
        match = re.search(rb'^'+symbol.encode()+rb'\s+PROC\b.*?^'+symbol.encode()+rb'\s+ENDP',
                          source, re.M | re.S)
        if match:
            routines.append(match[0])
    # Assemble the actual procedures, retaining their branches and API calls.
    # Only their load-time variables and caller-provided size are supplied here.
    out = tmp_path_factory.mktemp('allocator-'+name)
    harness = out / 'allocator.asm'
    harness.write_bytes(b'SEG_A SEGMENT\nASSUME CS:SEG_A, DS:SEG_A\nORG 100H\n'
                        b'DW S_GETUMB, D_UMB, D_LEN\nBEGIN EQU 1234H\n'
                        b'D_UMB DW 0\nD_LEN DW 123H\nD_NCFP DW 0\nD_UMB0 DW 0\nD_XMS DD 0\n'
                        + b'\n'.join(routines) + b'\nSEG_A ENDS\nEND\n')
    binary = out / 'allocator.com'
    p = subprocess.run([assembler, '-q', '-Zm', '-bin', f'-Fo{binary}', str(harness)],
                       capture_output=True, env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    assert p.returncode == 0, p.stdout + p.stderr
    return binary.read_bytes()


@pytest.mark.parametrize('failure', [None, 'old-dos', 0x5800, 0x5802, 'link', 'strategy', 0x48])
@pytest.mark.parametrize('initial', [(0, 0), (2, 1)])
def test_umb_allocation_restores_dos_state(allocator, failure, initial):
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    base = 0x10000
    uc.mem_write(base+0x100, allocator)
    entry, result, length = struct.unpack_from('<3H', allocator)
    state = dict(strategy=initial[0], linked=initial[1], allocations=0)

    def get(name):
        return uc.reg_read(getattr(reg, 'UC_X86_REG_'+name))

    def put(name, value):
        uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)

    def interrupt(uc, number, _):
        ax, bx = get('AX'), get('BX')
        put('EFLAGS', get('EFLAGS') & ~1)
        if number == 0x2f and ax == 0x4300:
            put('AX', 0)  # DOS can provide UMBs without an XMS entry point.
            return
        assert number == 0x21, f'unexpected interrupt {number:02x}'
        failed = (failure == ax or (failure == 0x48 and ax >> 8 == 0x48) or
                  (failure == 'link' and ax == 0x5803 and bx == 1) or
                  (failure == 'strategy' and ax == 0x5801 and bx == 0x41))
        if failed:
            put('AX', 8 if ax >> 8 == 0x48 else 1)
            put('EFLAGS', get('EFLAGS') | 1)
        elif ax == 0x3000:
            put('AX', 3 if failure == 'old-dos' else 5)
        elif ax == 0x5800:
            put('AX', state['strategy'])
        elif ax == 0x5802:
            put('AX', state['linked'])
        elif ax == 0x5803:
            state['linked'] = bx
        elif ax == 0x5801:
            state['strategy'] = bx
        elif ax >> 8 == 0x48:
            assert (state['strategy'], state['linked']) == (0x41, 1)
            assert bx == struct.unpack('<H', uc.mem_read(base+length, 2))[0]
            assert bx in (0x123, 0x124)
            state['allocations'] += 1
            uc.mem_write(0xd0000, b'M'+struct.pack('<HH', 0x1000, bx)+b'\0'*11)
            put('AX', 0xd001)
        else:
            pytest.fail(f'unexpected DOS call {ax:04x}')

    uc.hook_add(UC_HOOK_INTR, interrupt)
    for name, value in dict(CS=0x1000, DS=0x1000, ES=0x2345, SS=0x3000, SP=0xfffc,
                            BP=0x1234, EFLAGS=0x202).items():
        put(name, value)
    uc.mem_write(0x3fffc, b'\x00\xff')
    uc.emu_start(base+entry, base+0xff00, count=1000)
    assert get('IP') == 0xff00 and get('SP') == 0xfffe
    assert get('ES') == 0x2345
    assert (state['strategy'], state['linked']) == initial
    allocated = struct.unpack('<H', uc.mem_read(base+result, 2))[0]
    assert allocated == (0xd001 if failure is None else 0)
    assert state['allocations'] == (1 if failure is None else 0)
    if allocated:
        assert struct.unpack('<H', uc.mem_read(0xd0001, 2))[0] == allocated
