"""Compare the production dword scanner with the x86 word instruction."""
import struct

import pytest
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ

from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


def cases():
    for count in (0, 1, 2, 3, 4, 79, 80, 81, 1999, 2000, 3440, 4000):
        positions = [None]
        if count:
            positions += sorted({0, min(1, count - 1), count // 2, count - 1})
        for position in positions:
            yield count, position


@pytest.mark.parametrize('count,position', list(cases()))
@pytest.mark.parametrize('flags', [0x002, 0x242])
def test_dword_scan_matches_first_unequal_word(vesa_driver, count, position, flags):
    raw, symbols = vesa_driver
    machine = Driver((raw, dict(symbols)), lambda m: pytest.fail('Unexpected BIOS call'))
    machine.symbols['reference_words'] = 0xff10
    machine.uc.mem_write(0x1ff10, b'\xf3\xa7\xc3')  # REPE CMPSW; RET
    source = struct.pack('<' + 'H' * count, *(index * 317 & 65535 for index in range(count)))
    target = bytearray(source)
    if position is not None:
        # Differences alternate between glyph and attribute bytes.
        target[2 * position + (position & 1)] ^= 0x80
    machine.uc.mem_write(0x60102, source)
    machine.uc.mem_write(0x70106, bytes(target))
    inputs = dict(AX=0x95a7, BX=0x2345, CX=count, DX=0x4567,
                  SI=0x102, DI=0x106, BP=0x789a, DS=0x6000, ES=0x7000,
                  EFLAGS=flags)
    reads, instructions = [], []
    machine.uc.hook_add(UC_HOOK_MEM_READ,
                        lambda uc, access, address, size, value, _: reads.append((address, size)),
                        begin=0x60000, end=0x7ffff)
    machine.uc.hook_add(UC_HOOK_CODE,
                        lambda uc, address, size, _: instructions.append(address))
    machine.run('reference_words', **inputs)
    expected = {name: machine.get(name) for name in inputs if name != 'EFLAGS'}
    expected_zf = machine.get('EFLAGS') & 0x40
    reference_instructions = len(instructions)
    reads.clear()
    instructions.clear()
    machine.run('compare_text_words', **inputs)
    assert {name: machine.get(name) for name in expected} == expected
    assert machine.get('EFLAGS') & 0x40 == expected_zf
    assert machine.get('EFLAGS') & 0x600 == flags & 0x600
    for address, size in reads:
        start = 0x60102 if address < 0x70000 else 0x70106
        assert start <= address and address + size <= start + 2 * count
    assert bytes(machine.uc.mem_read(0x60102, len(source))) == source
    assert bytes(machine.uc.mem_read(0x70106, len(target))) == bytes(target)
    if count >= 1999 and position is None:
        assert len(instructions) < reference_instructions * 0.52
