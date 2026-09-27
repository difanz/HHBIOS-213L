"""Foreign-stack ABI and instruction budgets for the linked text routines."""
import struct

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
from unicorn import x86_const as reg

from qa.spec.build import ROOT, build_mixed

pytestmark = pytest.mark.unit


@pytest.fixture(scope='module', params=['8086', '386', '586'])
def textops(request, assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('textops') / 'textops.com'
    return build_mixed(ROOT/'qa/harness/textops.asm', out, source_dir, assembler,
                       request.param, ('frame', 'text_edit'))


def run_textop(binary, operation, text, previous=None, column=0, count=1, flags=0x602):
    symbols = dict(zip(('frame', 'same', 'shift', 'previous', 'offset', 'column'),
                       struct.unpack_from('<6H', binary)))
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    uc.mem_write(0x10100, binary)
    uc.mem_write(0x40000, text)
    if previous is not None:
        uc.mem_write(0x10000+symbols['previous'], previous)
    uc.mem_write(0x10000+symbols['column'], struct.pack('<H', column))
    initial = dict(CS=0x1000, DS=0x1000, ES=0x4000, SS=0x8000, SP=0xf000,
                   EAX=0x12345678, EBX=0x23450000, ECX=0x34560000 | count,
                   EDX=0x45670000, ESI=0x56781234, EDI=0x67892345, EBP=0x789a3456,
                   EFLAGS=flags)
    if operation == 'frame':
        initial['DS'] = 0x5000
    for name, value in initial.items():
        uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)
    uc.mem_write(0x8f000, b'\x00\xff')
    instructions = []
    uc.hook_add(UC_HOOK_CODE, lambda uc, address, size, _: instructions.append(address))
    uc.emu_start(0x10000+symbols[operation], 0x1ff00, count=10000)
    assert uc.reg_read(reg.UC_X86_REG_IP) == 0xff00
    assert uc.reg_read(reg.UC_X86_REG_SP) == 0xf002
    for name, value in initial.items():
        if name not in ('SP', 'EFLAGS'):
            assert uc.reg_read(getattr(reg, 'UC_X86_REG_'+name)) == value, name
    result_flags = uc.reg_read(reg.UC_X86_REG_EFLAGS)
    assert result_flags & 0x600 == flags & 0x600
    assert bytes(uc.mem_read(0x40000, len(text))) == text
    return bool(result_flags & (0x40 if operation == 'frame' else 1)), len(instructions)


@pytest.mark.parametrize('flags', [2, 0x202, 0x602])
def test_shared_text_preserves_foreign_stack_and_registers(textops, flags):
    text = b'A\x07' * 80
    result, instructions = run_textop(textops, 'same', text, b'A'*80, flags=flags)
    assert result and instructions < 500
    assert not run_textop(textops, 'shift', text, b'A'*80, flags=flags)[0]
    # Ordinary ASCII needs no corner-table scan.
    result, instructions = run_textop(textops, 'frame', text, flags=flags)
    assert not result and instructions < 130


@pytest.mark.parametrize('count', [1, 2])
def test_shared_text_deletion_keeps_fixed_border_and_ignores_attributes(textops, count):
    previous = b'|Chinese: '+bytes(range(0xa1, 0xb1))+b' text'+b' '*38+b'|'+b' '*10
    assert len(previous) == 80
    column, border = 11, 69
    current = previous[:column]+previous[column+count:border]+b' '*count+previous[border:]
    text = b''.join(bytes((ch, (i*7) & 255)) for i, ch in enumerate(current))
    result, instructions = run_textop(textops, 'shift', text, previous, column, count)
    assert result and instructions < 800
    damaged = bytearray(text)
    damaged[2] ^= 1
    assert not run_textop(textops, 'shift', bytes(damaged), previous, column, count)[0]
