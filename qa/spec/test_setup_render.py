"""Check resident SETUP captions against the installed font pixels."""
import json
import subprocess

import pytest

from qa.spec.dos import ROOT
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup import setup_guest
from qa.spec.test_setup_font_dos import font_rows
from qa.spec.test_setup_ui import run_setup_ui


def assert_caption(directory, capture, text, font):
    pixels = subprocess.check_output(['convert', str(directory/capture['file']),
                                      '-depth', '8', 'rgb:-'])
    width = capture['width']
    mask = bytes(green > 100 for green in pixels[1::3])
    screen = [mask[start:start + width] for start in range(0, len(mask), width)]
    cell_width = int.from_bytes(font[8:10], 'little')
    height = int.from_bytes(font[10:12], 'little')
    glyphs = []
    for character in text:
        code = int.from_bytes(character.encode('gb2312'), 'big')
        glyphs.append(tuple((left << cell_width) | right for left, right in
                            zip(font_rows(font, code, 0), font_rows(font, code, 1))))
    expected = [bytes((glyph[row] >> bit) & 1
                      for glyph in glyphs for bit in range(cell_width*2 - 1, -1, -1))
                for row in range(height)]
    anchor = max(range(height), key=lambda row: sum(expected[row]))
    for row in range(anchor, len(screen) - height + anchor + 1):
        col = screen[row].find(expected[anchor])
        while col >= 0:
            if all(screen[row - anchor + offset][col:col + len(bits)] == bits
                   for offset, bits in enumerate(expected)):
                return
            col = screen[row].find(expected[anchor], col + 1)
    pytest.fail(f'Caption missing or overwritten in {capture["file"]}: {text}')


@pytest.mark.dos
@pytest.mark.parametrize('mode,rows,font_name', [
    ('102', 25, 'HH20.FNT'), ('104', 25, 'F1229.FNT'),
    ('104', 43, 'F1217.FNT'), ('106', 50, 'F1620.FNT')])
def test_setup_resident_home_captions(dosbox_binary, setup_guest, msdos_image,
                                      mode, rows, font_name):
    image, copy_in, read = copy_disk(msdos_image, setup_guest)
    for name in ('SETUP.EXE', 'READ5.COM', 'CKBD.COM', 'VESA.COM', 'HZK16', 'HH20.FNT'):
        copy_in(setup_guest/name, '::HHBIOS/'+name)
    for path in (ROOT/'fonts/large').glob('F????.FNT'):
        copy_in(path, '::HHBIOS/'+path.name)
    commands = ['@ECHO OFF', 'C:\\DOS\\VBMOUSE.EXE install low', 'CD \\HHBIOS',
                'READ5', 'CKBD /E', f'VESA /M:{mode} /R:{rows}', 'SETUP /ZH',
                'ECHO complete>C:\\DONE.TXT', 'C:\\DOS\\SHUTDOWN /S']
    (setup_guest/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands)+'\r\n').encode())
    copy_in(setup_guest/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    mouse = mode == '104' and rows == 25
    actions = [{'x': 45, 'y': 25}, 'capture']
    if mouse:
        # Hover over the right half of 言, then leave. The UI cursor inverts
        # one text cell; moving it away must restore the complete caption.
        actions += [{'x': 818, 'y': 485}, 'capture',
                    {'x': 45, 'y': 25}, 'capture']
    actions += ['Alt-m', 'Escape', 'capture', 'Alt-x']
    run_setup_ui(dosbox_binary, setup_guest, '', actions, boot_image=image)
    assert read('DONE.TXT').strip() == b'complete'
    captures = json.loads((setup_guest/'screenshots.json').read_text())
    font_directory = ROOT/'fonts' if font_name == 'HH20.FNT' else ROOT/'fonts/large'
    font = (font_directory/font_name).read_bytes()
    home = [item for item in captures if item['before_key'] == 'dialog']
    if mouse:
        regions = [subprocess.check_output([
            'convert', str(setup_guest/item['file']), '-crop', '904x667+60+36',
            '-depth', '8', 'rgb:-']) for item in home[:3]]
        assert regions[0] != regions[1], 'The mouse must actually reach the button'
        assert regions[0] == regions[2], 'Mouse movement left damaged screen cells'
    for capture in captures:
        if capture['before_key'] == 'dialog':
            assert (capture['width'], capture['height']) == {
                '102': (800, 600), '104': (1024, 768), '106': (1280, 1024)}[mode]
            for caption in ('字库存放', '程序驻留', '显示驱动', '输入码表', '整字编辑'):
                assert_caption(setup_guest, capture, caption, font)
