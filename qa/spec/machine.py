"""Real x86 instructions, synthetic RAM, and an observable drawing boundary.

This layer proves classification, damage tracking and memory safety; it does
not prove VGA port programming, interrupt timing or font pixels.
"""
import struct

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn import x86_const as reg

NAMES = ('scan', 'char', 'hanzi', 'shadow', 'mode', 'hanzi_switch',
         'teletype', 'return', 'pending', 'direct', 'stroke', 'keypos')
CODE, SCREEN, STACK = 0x10000, 0x20000, 0x30000

# Public CP437 conversion codes, shared with DOS programs through INT 10h.
FRAME_ALIASES = dict(zip(range(0xb0, 0xe0), bytes.fromhex(
    '80 81 82 14 83 84 85 b7 b8 86 15 87 88 bd be 89 '
    '8a 8b 8c 8d 12 8e 8f 90 91 92 93 94 95 13 96 97 '
    '98 99 9a d3 d4 d5 d6 9b 9c 9d 9e 82 9f 82 82 a0')))


def blank():
    return bytearray(b' \x07' * 2000)


def put(screen, row, col, text, attr=7):
    if isinstance(text, str):
        text = text.encode('gb2312')
    assert 0 <= row < 25 and 0 <= col and col + len(text) <= 80
    for i, code in enumerate(text):
        screen[2 * (80 * row + col + i):2 * (80 * row + col + i) + 2] = bytes((code, attr))


class DisplayMachine:
    def __init__(self, binary):
        self.symbols = dict(zip(NAMES, struct.unpack_from(f'<{len(NAMES)}H', binary)))
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x40000)
        self.uc.mem_write(CODE + 0x100, binary)
        self.uc.mem_write(SCREEN, bytes(blank()))
        self.uc.mem_write(CODE + self.symbols['shadow'], bytes(blank()))
        self.pixels = [('char', 32, 7)] * 2000
        self.draws = []
        self.writes = []
        self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self._guard,
                         begin=SCREEN, end=SCREEN + 0xffff)
        for symbol in ('char', 'hanzi'):
            address = CODE + self.symbols[symbol]
            self.uc.hook_add(UC_HOOK_CODE, self._draw, user_data=symbol,
                             begin=address, end=address)

    def _guard(self, uc, access, address, size, value, _):
        assert SCREEN <= address and address + size <= SCREEN + 4000, (
            f'out-of-screen access: {address - SCREEN:#x}, size={size}')
        # Unicorn's access constants are distinct from hook constants.
        from unicorn import UC_MEM_WRITE
        if access == UC_MEM_WRITE:
            self.writes.append((address - SCREEN, size, value))

    def _draw(self, uc, address, size, kind):
        ax, bx, dx = (self.read(x) for x in ('AX', 'BX', 'DX'))
        row, col = dx >> 8, dx & 255
        assert row < 25 and col < 80, f'draw outside screen: {row},{col}'
        index = row * 80 + col
        if kind == 'char':
            assert self.read('CX') == 1
            self.pixels[index] = ('char', ax & 255, bx & 255)
        else:
            assert col < 79, f'cross-row hanzi: {row},{col}'
            self.pixels[index] = ('hanzi-left', ax, bx >> 8)
            self.pixels[index + 1] = ('hanzi-right', ax, bx & 255)
        self.draws.append((kind, row, col, ax, bx))

    def read(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_' + name))

    def write(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_' + name), value)

    def call(self, symbol, **registers):
        for name, value in dict(CS=0x1000, DS=0x2000, ES=0x1000, SS=0x3000,
                                SP=0xfffc, EFLAGS=2).items():
            self.write(name, value)
        for name, value in registers.items():
            self.write(name, value)
        self.uc.mem_write(STACK + 0xfffc, struct.pack('<H', 0xff00))
        self.uc.emu_start(CODE + self.symbols[symbol], CODE + 0xff00,
                          timeout=5_000_000, count=2_000_000)
        assert self.read('IP') == 0xff00, 'routine did not return within execution budget'
        assert self.read('SP') == 0xfffe, 'unbalanced stack'

    def scan(self, screen, mode=3):
        self.input = bytes(screen)
        self.uc.mem_write(SCREEN, bytes(screen))
        self.uc.mem_write(CODE + self.symbols['mode'], bytes((mode,)))
        self.draws.clear()
        self.writes.clear()
        self.call('scan')
        for offset, size, value in self.writes:
            assert size == 1 and offset % 2 == 0, 'scanner changed an attribute'
            assert value == FRAME_ALIASES.get(self.input[offset]), (
                f'write outside the frame conversion contract: {offset}, {value:#x}')

    def cell(self, row, col):
        return self.pixels[row * 80 + col]
