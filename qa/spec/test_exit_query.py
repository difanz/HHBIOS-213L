"""Execute the base reader's shared unload-range and native-mode helpers."""
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
from unicorn import x86_const as reg

pytestmark = pytest.mark.unit


@pytest.fixture(scope='module')
def exit_helpers(assembler, source_dir, tmp_path_factory):
    directory = tmp_path_factory.mktemp('exit-query')
    names = ['L_EXITQUERY', 'S_EXIT_KEEP_NATIVE', 'TSR', 'TSRD', 'TSRC']
    source = ('.model tiny\n.code\norg 100h\nstart: ret\n'
              'TSRD dw 2\nTSRC dw 4\nTSR dd 64 dup (0)\n'
              'include EXITQUERY.INC\nDB "EXIT-HELPERS"\nDW ' +
              ','.join('offset ' + name for name in names) + '\nend start\n')
    path = directory / 'exit.asm'
    path.write_text(source)
    output = directory / 'exit.com'
    subprocess.run([assembler, '-q', '-0', '-bin', '-I' + str(source_dir / 'common'),
                    '-Fo' + str(output), str(path)], check=True, capture_output=True)
    binary = output.read_bytes()
    offset = binary.index(b'EXIT-HELPERS') + len(b'EXIT-HELPERS')
    addresses = dict(zip(names, struct.unpack_from('<5H', binary, offset)))
    return binary, addresses


def machine(fixture):
    binary, addresses = fixture
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    uc.mem_write(0x10100, binary)
    uc.reg_write(reg.UC_X86_REG_CS, 0x1000)
    uc.reg_write(reg.UC_X86_REG_SS, 0x7000)
    uc.reg_write(reg.UC_X86_REG_SP, 0xff00)
    return uc, addresses


@pytest.mark.parametrize('columns,rows,keep', [(40, 25, 0), (80, 25, 0), (80, 43, 0),
                                            (80, 50, 0), (132, 50, 1), (80, 60, 1)])
def test_native_mode_reset_boundary(exit_helpers, columns, rows, keep):
    uc, addresses = machine(exit_helpers)
    uc.mem_write(0x44a, struct.pack('<H', columns))
    uc.mem_write(0x484, bytes([rows - 1]))
    uc.mem_write(0x7ff00, struct.pack('<H', 0xff00))
    uc.reg_write(reg.UC_X86_REG_ES, 0x3456)
    uc.emu_start(0x10000 + addresses['S_EXIT_KEEP_NATIVE'], 0x1ff00, count=1000)
    assert uc.reg_read(reg.UC_X86_REG_AX) == keep
    assert uc.reg_read(reg.UC_X86_REG_ES) == 0x3456


@pytest.mark.parametrize('kind', [0, 1, 2, 3])
@pytest.mark.parametrize('target', [0, 0x2000, 0x3000, 0x4000, 0x5000, 0x6000])
def test_public_unload_range_query(exit_helpers, kind, target):
    uc, addresses = machine(exit_helpers)
    uc.mem_write(0x10000 + addresses['TSR'], struct.pack('<8H', 0x2000, 0, 0x3000, 0,
                                                      0x4000, 0, 0x5000, 0))
    saved = {'BX': target, 'CX': 0x1234, 'SI': 4, 'DI': kind, 'BP': 0x5678,
             'DS': 0x2345, 'ES': 0x3456}
    for name, value in saved.items():
        uc.reg_write(getattr(reg, 'UC_X86_REG_' + name), value)
    uc.mem_write(0x7ff00, struct.pack('<3H', 0xff00, 0x1000, 0x202))
    uc.emu_start(0x10000 + addresses['L_EXITQUERY'], 0x1ff00, count=1000)
    ranges = {0: [0x2000, 0x3000, 0x4000, 0x5000], 1: [0x4000, 0x5000],
              2: [0x5000], 3: []}
    assert uc.reg_read(reg.UC_X86_REG_AX) == int(target in ranges[kind])
    assert uc.reg_read(reg.UC_X86_REG_DX) == 0x4a06
    for name, value in saved.items():
        assert uc.reg_read(getattr(reg, 'UC_X86_REG_' + name)) == value
