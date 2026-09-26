"""Execute the production key filter; application updates are explicit inputs.

The real editor tests separately prove that these updates occur in an app.
"""
import os
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

from qa.spec.machine import CODE, SCREEN, STACK, blank, put

pytestmark = pytest.mark.unit
BS, DEL, LEFT, RIGHT = 0x0e08, 0x5300, 0x4b00, 0x4d00


@pytest.fixture(scope='session')
def key_binary(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('key-assembly') / 'key.com'
    p = subprocess.run([assembler, '-q', '-Zm', '-bin', f'-I{source_dir}',
                        f'-Fo{out}', 'qa/harness/keyedit.asm'], capture_output=True,
                       env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    assert p.returncode == 0, p.stdout + p.stderr
    return out.read_bytes()


class Keyboard:
    def __init__(self, binary, display):
        self.entry, self.enabled, self.state = struct.unpack_from('<3H', binary)
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0xc0000)
        self.uc.mem_write(CODE+0x100, binary)
        self.uc.mem_write(CODE+self.enabled, b'\1')
        self.uc.mem_write(0x44a, b'\x50\0')
        self.display = display
        self.screen_segment = 0xb800
        self.keys = []
        self.uc.hook_add(UC_HOOK_INTR, self.interrupt)

    def get(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_'+name))

    def set(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)

    def interrupt(self, uc, number, _):
        if number == 0x60:
            function = self.get('AX') >> 8
            assert function in (0, 1, 0x10, 0x11)
            if function & 1:
                self.set('EFLAGS', (self.get('EFLAGS') & ~64) | (0 if self.keys else 64))
                if self.keys:
                    self.set('AX', self.keys[0])
            else:
                assert self.keys, 'unexpected blocking BIOS read'
                self.set('AX', self.keys.pop(0))
        else:
            assert number == 0x10 and self.get('AX') == 0x1410
            self.display.uc.mem_write(SCREEN, bytes(uc.mem_read(self.screen_segment*16, 4000)))
            self.display.call('keypos', DX=self.get('DX'))
            self.set('AX', self.display.read('AX'))
            self.set('BX', self.display.read('BX'))
            self.set('CX', self.screen_segment if self.display.read('CX') else 0)

    def screen(self, text, col, row=4, start=3):
        raw = blank()
        put(raw, row, start, text)
        # An ordinary application window with a fixed right border.
        put(raw, row, 0, b'\x15', 0x1f)
        put(raw, row, 70, b'\x15', 0x1f)
        self.uc.mem_write(self.screen_segment*16, bytes(raw))
        self.uc.mem_write(0x450, bytes((col, row)))

    def call(self, ah=0, key=None):
        if key is not None:
            self.keys.append(key)
        for k, v in dict(CS=0x1000, DS=0x1000, SS=0x3000, SP=0xfffc,
                         EFLAGS=0x202, AX=ah << 8).items():
            self.set(k, v)
        self.uc.mem_write(STACK+0xfffc, b'\x00\xff')
        before = bytes(self.uc.mem_read(self.screen_segment*16, 4000))
        self.uc.emu_start(CODE+self.entry, CODE+0xff00, count=100000)
        assert self.get('IP') == 0xff00 and self.get('SP') == 0xfffe
        assert bytes(self.uc.mem_read(self.screen_segment*16, 4000)) == before
        return self.get('AX') if self.get('EFLAGS') & 1 else None


@pytest.fixture
def keyboard(key_binary, machine):
    return Keyboard(key_binary, machine)


@pytest.mark.parametrize('key,col,updated,newcol,first,second', [
    (BS, 7, b'\xd6\xd0\xceabc', 6, BS, BS),
    (DEL, 5, b'\xd6\xd0\xc4abc', 5, DEL, DEL),
    (LEFT, 7, '中文abc'.encode('gb2312'), 6, LEFT, LEFT),
    (RIGHT, 5, '中文abc'.encode('gb2312'), 6, RIGHT, RIGHT),
    # A mouse or vertical movement can put the cursor between the two bytes.
    (BS, 6, b'\xd6\xd0\xc4abc', 5, BS, DEL),
    (DEL, 6, b'\xd6\xd0\xc4abc', 5, BS, DEL),
])
@pytest.mark.parametrize('read,peek', [(0, 1), (0x10, 0x11)])
def test_pair_edit_and_idempotent_peek(keyboard, key, col, updated, newcol, first, second, read, peek):
    if key == BS and col == 6 and read == 0x10:
        second = 0x53e0
    keyboard.screen('中文abc', col)
    assert keyboard.call(read, key) == first
    keyboard.screen(updated, newcol)
    keyboard.keys.append(0x1e61)  # already queued real input must follow the companion
    assert keyboard.call(peek) == second
    assert keyboard.call(peek) == second
    assert keyboard.call(read) == second
    assert keyboard.call(read) == 0x1e61
    assert keyboard.call(peek) is None


@pytest.mark.parametrize('key,col,updated,newcol', [
    (BS, 7, '中abc', 5),       # application already deleted the whole character
    (DEL, 5, '中abc', 5),
    (LEFT, 7, '中文abc', 5),
    (RIGHT, 5, '中文abc', 7),
    (BS, 7, '中文abc', 7),    # read-ahead / ignored key
    (DEL, 5, '中文abc', 5),
    (DEL, 5, 'abc', 3),       # selection deletion
    (DEL, 5, '中abc', 3),
])
def test_no_extra_key_for_other_application_updates(keyboard, key, col, updated, newcol):
    keyboard.screen('中文abc', col)
    assert keyboard.call(key=key) == key
    keyboard.screen(updated, newcol)
    assert keyboard.call(1) is None


@pytest.mark.parametrize('key,col', [(BS, 8), (DEL, 7), (LEFT, 6), (RIGHT, 6), (BS, 0), (DEL, 79)])
def test_single_byte_and_boundary_keys(keyboard, key, col):
    keyboard.screen('中文abc', col)
    assert keyboard.call(key=key) == key
    assert keyboard.uc.mem_read(CODE+keyboard.state, 1) == b'\0'


@pytest.mark.parametrize('address,value', [(0x417, 1), (0x417, 4), (0x417, 8),
                                         (0x462, 1), (0x461, 0x20), (0x44a, 40)])
def test_modified_keys_and_other_screen_contexts(keyboard, address, value):
    keyboard.screen('中文abc', 5)
    keyboard.uc.mem_write(address, bytes((value,)))
    assert keyboard.call(key=DEL) == DEL
    assert keyboard.uc.mem_read(CODE+keyboard.state, 1) == b'\0'


def test_disabled_filter_preserves_the_bios_request(keyboard):
    keyboard.uc.mem_write(CODE+keyboard.enabled, b'\0')
    keyboard.screen('中文abc', 5)
    assert keyboard.call(key=DEL) is None
    assert keyboard.keys == [DEL]


def test_peek_before_application_update_does_not_cancel_companion(keyboard):
    keyboard.screen('中文abc', 5)
    assert keyboard.call(key=RIGHT) == RIGHT
    for _ in range(3):
        assert keyboard.call(0x11) is None
    keyboard.screen('中文abc', 6)
    assert keyboard.call(0x11) == RIGHT
    assert keyboard.call(0x10) == RIGHT


def test_trail_delete_has_same_value_in_peek_and_read(keyboard):
    keyboard.screen('中文abc', 6)
    assert keyboard.call(0x11, DEL) == BS
    assert keyboard.call(0x11) == BS
    assert keyboard.call(0x10) == BS
    keyboard.screen(b'\xd6\xd0\xc4abc', 5)
    assert keyboard.call(0x11) == DEL
    assert keyboard.call(0x10) == DEL


def test_enhanced_trail_delete_preserves_its_companion_encoding(keyboard):
    keyboard.screen('中文abc', 6)
    assert keyboard.call(0x11, 0x53e0) == BS
    assert keyboard.call(0x10) == BS
    keyboard.screen(b'\xd6\xd0\xc4abc', 5)
    assert keyboard.call(0x11) == 0x53e0
    assert keyboard.call(0x10) == 0x53e0


def test_monochrome_screen_and_changed_screen_segment(keyboard):
    keyboard.screen_segment = 0xb000
    keyboard.screen('中文abc', 5)
    assert keyboard.call(key=DEL) == DEL
    keyboard.screen(b'\xd6\xd0\xc4abc', 5)
    assert keyboard.call(1) == DEL
    assert keyboard.call() == DEL
    keyboard.screen('中文abc', 5)
    assert keyboard.call(key=DEL) == DEL
    keyboard.screen_segment = 0xb800
    keyboard.screen(b'\xd6\xd0\xc4abc', 5)
    assert keyboard.call(1) is None


@pytest.mark.parametrize('policy,value', [('mode', 0), ('direct', 0), ('hanzi_switch', 0xeb)])
def test_inactive_display_policy_cancels_pending_key(keyboard, policy, value):
    keyboard.screen('中文abc', 5)
    assert keyboard.call(key=DEL) == DEL
    keyboard.screen(b'\xd6\xd0\xc4abc', 5)
    keyboard.display.uc.mem_write(CODE+keyboard.display.symbols[policy], bytes((value,)))
    assert keyboard.call(1) is None


@pytest.mark.parametrize('text', ['中文abc', '╔═╗', '╓─╖', '╒═╕', '屯屯屯'])
def test_keyboard_boundary_query_agrees_with_rendering(machine, text):
    screen = blank()
    encoded = text.encode('cp437' if text.startswith('╔') or text.startswith('╓') or text.startswith('╒') else 'gb2312')
    put(screen, 3, 2, encoded)
    if text.startswith(('╔', '╓', '╒')):
        put(screen, 4, 2, b'\xb3')
        put(screen, 4, 4, b'\xb3')
    machine.scan(screen)
    for col in range(80):
        role = machine.cell(3, col)[0]
        expected = {'char': 0, 'hanzi-left': 1, 'hanzi-right': 2}[role]
        machine.call('keypos', DX=0x300+col)
        assert machine.read('AX') == expected
        assert machine.read('BX') == 0x4b48
