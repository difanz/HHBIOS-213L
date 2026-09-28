"""Dirty-row scans retain pairing while avoiding unchanged prefix glyphs."""
import pytest

from qa.spec.machine import SCREEN, DisplayMachine, blank, put

pytestmark = pytest.mark.unit


def test_streamed_chinese_fetches_each_completed_pair_once(machine):
    phrase = '中文测试输入界面'.encode('gb2312')
    screen = blank()
    machine.scan(screen)
    fetches = 0
    for column, byte in enumerate(phrase):
        screen[2 * (5 * 80 + column)] = byte
        machine.scan(screen)
        fetches += sum(kind == 'hanzi' for kind, *_ in machine.draws)
        screen = bytearray(machine.uc.mem_read(SCREEN, 4000))
    # The previous row scan fetched all preceding Hanzi again for each byte:
    # n completed pairs caused n*n font fetches. Only n are needed here.
    pairs = len(phrase) // 2
    assert fetches == pairs
    assert fetches < pairs * pairs


@pytest.mark.parametrize('cell,replacement,attribute', [
    (0, 0xce, 7), (1, 0xc4, 7), (2, 0xd6, 7), (3, 0xd0, 7),
    (4, 32, 7), (5, 32, 7), (6, 0xb2, 0x1e), (7, 0xe2, 0x4b),
])
def test_prefix_boundary_edits_match_a_complete_redraw(machine, display_binary, cell, replacement, attribute):
    screen = blank()
    put(screen, 4, 8, '╔════════════╗'.encode('cp437'))
    put(screen, 5, 8, b'\xba' + '中文测试输入'.encode('gb2312') + b'\xba')
    put(screen, 6, 8, '╚════════════╝'.encode('cp437'))
    machine.scan(screen)
    screen = bytearray(machine.uc.mem_read(SCREEN, 4000))
    screen[2 * (5 * 80 + 9 + cell):2 * (5 * 80 + 10 + cell)] = bytes([replacement, attribute])
    machine.scan(screen)
    reference = DisplayMachine(display_binary)
    reference.scan(screen)
    assert machine.pixels == reference.pixels
    # The source and attributes are also part of the interface to DOS apps.
    assert machine.uc.mem_read(SCREEN, 4000) == reference.uc.mem_read(SCREEN, 4000)


@pytest.mark.parametrize('mode', [0, 1, 2, 3])
def test_policy_change_repaints_unchanged_hanzi_prefix(machine, display_binary, mode):
    screen = blank()
    put(screen, 3, 0, '中文测试输入界面')
    machine.scan(screen, (mode + 1) % 4)
    screen = bytearray(machine.uc.mem_read(SCREEN, 4000))
    machine.scan(screen, mode)
    reference = DisplayMachine(display_binary)
    reference.scan(screen, mode)
    assert machine.pixels == reference.pixels
    assert len(machine.draws) > 1900
