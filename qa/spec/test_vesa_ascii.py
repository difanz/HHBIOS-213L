"""Execute the printable-cell fast path and its classifier fallback."""
import struct

import pytest
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE

from qa.spec.test_vesa_api import Driver, vesa_driver
from qa.spec.test_legacy_video_irq import LegacyVideo, legacy_video

pytestmark = pytest.mark.unit


@pytest.fixture(scope='module')
def classified_page(vesa_driver):
    machine = Driver(vesa_driver, lambda m: m.put('AX', 0x004f))
    machine.write('active', b'\1')
    machine.write('banked_text', b'\1')
    text = b' \x07' * 2000
    machine.uc.mem_write(0xb8000, text)
    machine.run('refresh_dirty', limit=100000000)
    # Retain policy state established by the production classifier. No
    # private offsets or test-only initialization of its state are needed.
    return bytes(machine.uc.mem_read(0x10000, 65536))


def make_driver(image, classified, rows=25, page=0):
    banks = []

    def bios(machine):
        assert machine.get('AX') == 0x4f05
        banks.append(machine.get('DX'))
        machine.put('AX', 0x004f)

    machine = Driver(image, bios)
    machine.uc.mem_write(0x10000, classified)
    for name, value in dict(text_rows=rows, text_cells=rows * 80,
                            page_bytes=8192, active_page=page, text_bank=6,
                            raster_height=600 // (rows + 1)).items():
        machine.write(name, struct.pack('<H', value))
    machine.write('last_row', bytes([rows - 1]))
    text = bytearray(b' \x07' * (rows * 80))
    # Chinese and already converted frame cells may remain elsewhere.
    text[160:164] = b'\xd6\x1e\xd0\x1e'
    text[320:328] = b'\x12\x07' * 4
    machine.write('shadow', bytes(text))
    base = 0xb8000 + page * 8192
    machine.uc.mem_write(base, bytes(text))
    glyphs, writes = [], []

    def glyph(uc, address, size, _):
        stack = machine.get('SS') * 16 + machine.get('SP')
        glyphs.append(struct.unpack('<H', uc.mem_read(stack + 2, 2))[0])

    machine.uc.hook_add(UC_HOOK_CODE, glyph,
                        begin=0x10000 + machine.symbols['font_draw'],
                        end=0x10000 + machine.symbols['font_draw'])
    machine.uc.hook_add(UC_HOOK_MEM_WRITE,
                        lambda uc, access, address, size, value, _: writes.append(size),
                        begin=base, end=base + len(text) - 1)
    return machine, text, base, glyphs, writes, banks


def refresh(machine, flags=0x602):
    registers = dict(AX=0x1234, BX=0x2345, CX=0x3456, DX=0x4567,
                     SI=0x5678, DI=0x6789, BP=0x789a, ES=0x8000)
    machine.run('refresh_dirty', limit=100000000, EFLAGS=flags, **registers)
    assert all(machine.get(name) == value for name, value in registers.items())
    assert machine.get('EFLAGS') & 0x600 == flags & 0x600


@pytest.mark.parametrize('rows,page', [(25, 0), (43, 1), (50, 3)])
@pytest.mark.parametrize('attribute_only', [False, True])
def test_ascii_refresh_draws_only_changed_cells(vesa_driver, classified_page, rows, page, attribute_only):
    machine, text, base, glyphs, writes, banks = make_driver(vesa_driver, classified_page, rows, page)
    last = len(text) - 2
    text[0:2] = b' \x1e' if attribute_only else b'A\x07'
    text[last:last + 2] = b' \x4b' if attribute_only else b'Z\x07'
    machine.uc.mem_write(base, bytes(text))
    refresh(machine)
    assert glyphs == ([32, 32] if attribute_only else [65, 90])
    assert not writes, 'printable cells must not rewrite the text aperture'
    assert machine.read('shadow', len(text)) == bytes(text)
    assert machine.read('text_transfer', len(text)) == bytes(text)
    assert banks == [0, 6]
    # A repeated refresh must not paint the unchanged Chinese or frame cells.
    glyphs.clear()
    refresh(machine)
    assert glyphs == [] and not writes


@pytest.mark.parametrize('old,new', [(0x20, 0x1f), (0x20, 0x7f), (0x20, 0xd6),
                                   (0xd6, 0x20), (0xdf, 0x20),
                                   (ord('['), ord('A')), (ord('A'), ord(']')),
                                   (ord('+'), ord('-'))])
def test_late_classification_change_keeps_earlier_shadow_for_fallback(
        vesa_driver, classified_page, old, new):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    text[-2] = old
    machine.write('shadow', bytes(text))
    text[0] = ord('A')
    text[-2] = new
    machine.uc.mem_write(base, bytes(text))
    refresh(machine)
    assert sum(writes) == len(text), 'unsafe candidate bypassed the full classifier'
    assert ord('A') in glyphs, 'preflight changed shadow before discovering a later fallback'
    assert machine.read('shadow', len(text)) == bytes(machine.uc.mem_read(base, len(text)))


@pytest.mark.parametrize('change', ['policy', 'hanzi', 'font'])
def test_classifier_state_changes_force_full_refresh(vesa_driver, classified_page, change):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    if change == 'policy':
        machine.write('policy', b'\1')
    elif change == 'hanzi':
        machine.write('hanzi', b'\0')
    else:
        machine.run('invalidate')
    text[0] = ord('A')
    machine.uc.mem_write(base, bytes(text))
    refresh(machine)
    assert sum(writes) == len(text)
    assert len(glyphs) > 1000


def test_ascii_directory_anchor_reclassifies_unchanged_branch(vesa_driver, classified_page):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    # The raw C0 C4 pair gains a tree anchor from ASCII characters above it.
    text[20:26] = b'[\x07A\x07]\x07'
    text[182:192] = b'\xc0\x07\xc4\x07[\x07 \x07]\x07'
    machine.write('shadow', bytes(text))
    text[22] = ord('+')
    machine.uc.mem_write(base, bytes(text))
    refresh(machine)
    assert sum(writes) == len(text)
    assert 0xc0c4 not in glyphs, 'tree branch was drawn as a Hanzi pair'
    assert 0xc0 in glyphs and 0xc4 in glyphs


def test_wide_drawing_state_keeps_full_classifier(vesa_driver, classified_page):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    # Execute the production wide entry's first instruction. Its width
    # remains owned until draw returns; no guessed private state offset.
    machine.put('CS', 0x1000)
    machine.uc.emu_start(0x10000 + machine.symbols['draw_wide'], 0x1ff00, count=1)
    text[0] = ord('A')
    machine.uc.mem_write(base, bytes(text))
    refresh(machine)
    assert sum(writes) == len(text)


def test_vesa_hanzi_toggle_repaints_unchanged_text(vesa_driver, classified_page):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    for enabled in (False, True):
        glyphs.clear()
        writes.clear()
        machine.write('hanzi', bytes([enabled]))
        refresh(machine)
        assert sum(writes) == len(text)
        assert (0xd6d0 in glyphs) == enabled
        assert machine.read('shadow', len(text)) == bytes(text)
        glyphs.clear()
        writes.clear()
        refresh(machine)
        assert not glyphs and not writes


def test_vesa_stream_fetches_each_new_chinese_pair_once(vesa_driver, classified_page):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    phrase = '中文测试输入界面'.encode('gb2312')
    total = 0
    for column, byte in enumerate(phrase):
        text[2 * (5 * 80 + column)] = byte
        machine.uc.mem_write(base, bytes(text))
        glyphs.clear()
        refresh(machine, 0x202)
        total += sum(code >= 256 for code in glyphs)
        text[:] = machine.uc.mem_read(base, len(text))
    assert total == len(phrase) // 2


@pytest.mark.parametrize('code', [0xaf, 0xb0, 0xb3, 0xba, 0xc4, 0xdf, 0xe0])
def test_downloaded_glyphs_keep_their_bytes_during_full_classification(
        vesa_driver, classified_page, code):
    machine, text, base, glyphs, writes, _ = make_driver(vesa_driver, classified_page)
    custom = bytearray(256)
    custom[code] = 1
    machine.write('font_custom', bytes(custom))
    # Repetition makes ordinary CP437 cells eligible for horizontal/vertical
    # frame conversion. Downloaded symbols must still reach the font API
    # independently, including both sides of the B0..DF classifier range.
    for row in range(5, 8):
        offset = 2 * (row * 80 + 10)
        text[offset:offset + 8] = bytes([code, 7]) * 4
    machine.uc.mem_write(base, bytes(text))
    refresh(machine)
    assert glyphs.count(code) == 12
    assert not any(value > 255 and (value >> 8 == code or value & 255 == code)
                   for value in glyphs)
    assert bytes(machine.uc.mem_read(base, len(text))) == bytes(text)
    assert machine.read('shadow', len(text)) == bytes(text)


def test_shared_hanzi_toggle_repaints_unchanged_text(machine):
    from qa.spec.machine import CODE, blank, put
    text = blank()
    put(text, 1, 2, '中文')
    machine.scan(text)
    for opcode in (0xeb, 0x74):
        address = CODE + machine.symbols['hanzi_switch']
        machine.uc.mem_write(address, bytes([opcode]))
        # Host memory writes do not invalidate Unicorn's translated blocks.
        machine.uc.ctl_remove_cache(address, address + 1)
        machine.scan(text)
        expected = ('char', 0xd6, 7) if opcode == 0xeb else ('hanzi-left', 0xd6d0, 7)
        assert machine.cell(1, 2) == expected
        assert machine.draws
        machine.scan(text)
        assert not machine.draws


@pytest.mark.parametrize('opcode', [0x74, 0xeb])
def test_legacy_timer_reads_hanzi_opcode_not_its_address(legacy_video, opcode):
    if legacy_video[0] not in ('VGA', 'EGA', 'HGA'):
        pytest.skip('This driver does not install a refresh timer.')
    machine = LegacyVideo(legacy_video)
    machine.write('D_INT8', struct.pack('<HH', 0xf000, 0x1000))
    machine.write('D_8', b'\1')
    machine.write('K_INT8', b'\x75')
    machine.write('D_B800', struct.pack('<H', 0xb800))
    machine.write('D_ZBFS', b'\3')
    machine.write('D_LASTMODE', b'\3')
    machine.write('D_LASTHZ', b'\x74')
    machine.write('K_HZ1', bytes([opcode]))
    text = b' \x07' * 2000
    machine.write('D_XPQ', text)
    machine.uc.mem_write(0xb8000, text)
    reached = []
    for name in ('S_XR', 'L_0830'):
        def observe(uc, address, size, name):
            reached.append(name)
            uc.emu_stop()
        machine.uc.hook_add(UC_HOOK_CODE, observe, name,
                            begin=machine.address(name), end=machine.address(name))
    machine.enter('INT_8', expect_return=False)
    assert reached == ['L_0830' if opcode == 0x74 else 'S_XR']
