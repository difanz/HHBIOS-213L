"""Font choice follows the physical surface and the application's text rows."""
import ctypes as C
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, plane_bits, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_font20 import sized_font
from qa.spec.test_text_modes import textmode_build
from qa.spec.test_variable_font import sample_text, assert_cells
from qa.spec.test_vesa import vesa_build


class FontInfo(C.Structure):
    _fields_ = [(name, C.c_ushort) for name in
                ('format', 'width', 'height', 'record_bytes', 'records')] + [
                ('payload_bytes', C.c_uint)]


class Layout(C.Structure):
    _fields_ = [('height', C.c_ushort), ('scale', C.c_ushort), ('area', C.c_uint)]


@pytest.fixture(scope='module')
def font_layout(tmp_path_factory):
    library = tmp_path_factory.mktemp('font-layout') / 'layout.so'
    subprocess.run(['cc', '-std=c99', '-Wall', '-Wextra', '-Werror', '-shared', '-fPIC',
                    str(ROOT / 'src/common/font_layout.c'), '-o', str(library)], check=True)
    dll = C.CDLL(str(library))
    dll.FitFont.argtypes = [C.POINTER(FontInfo), C.c_ushort, C.c_ushort,
                           C.c_ushort, C.POINTER(Layout)]
    dll.BetterFont.argtypes = [C.POINTER(FontInfo), C.POINTER(FontInfo),
                              C.c_ushort, C.c_ushort, C.c_ushort]
    return dll


@pytest.mark.unit
@pytest.mark.parametrize('screen', [(800, 600), (1024, 768), (1280, 800),
                                  (1366, 768), (1920, 1080), (1920, 1200)])
@pytest.mark.parametrize('rows', [25, 43, 50])
def test_native_cell_uses_available_height_including_status(font_layout, screen, rows):
    width, height = screen
    font = FontInfo(2, width // 80, height // (rows + 1), 0, 1, 40000)
    result = Layout()
    if font.height < 16:
        assert not font_layout.FitFont(font, width, height, rows, result)
        return
    assert font_layout.FitFont(font, width, height, rows, result)
    assert (result.height, result.scale) == (font.height, 1)
    assert result.area == 80 * font.width * (rows + 1) * font.height
    legacy = FontInfo(1, 10, 23, 70, 100, 40736)
    if (font.width, font.height) != (10, 23):
        assert font_layout.BetterFont(font, legacy, width, height, rows)


@pytest.mark.unit
def test_native_strike_wins_over_an_exact_double(font_layout):
    small = FontInfo(2, 8, 16, 32, 1, 33768)
    native = FontInfo(2, 16, 32, 128, 1, 33864)
    assert font_layout.BetterFont(native, small, 1280, 832, 25)
    assert not font_layout.BetterFont(small, native, 1280, 832, 25)


def install_fonts(directory, build):
    for path in build.glob('*.COM'):
        shutil.copy2(path, directory)
    for name in ('HZK16', 'HH20.FNT'):
        shutil.copy2(ROOT / 'fonts' / name, directory)
    for width, height in ((12, 29), (12, 17), (16, 39), (16, 23), (16, 20)):
        (directory / f'F{width:02}{height:02}.FNT').write_bytes(sized_font(width, height))
    # An otherwise attractive file must not be accepted on its filename alone.
    (directory / 'F9999.FNT').write_bytes(sized_font(24, 64)[:-1])
    keyboard_config(directory)


@pytest.mark.dos
@pytest.mark.parametrize('storage', ['xms', 'ems'])
def test_auto_font_changes_with_rows_and_survives_state_restore(
        dosbox_binary, vesa_build, textmode_build, tmp_path, storage):
    install_fonts(tmp_path, vesa_build)
    shutil.copy2(textmode_build, tmp_path)
    commands = ['READ5' if storage == 'xms' else 'READ4', 'CKBD', 'VESA /M:106']
    for rows in (25, 43, 50, 25):
        (tmp_path / f'T{rows}.BIN').write_bytes(b'\1' + sample_text(rows))
    for index, rows in enumerate((25, 43, 50, 25)):
        commands += [f'TEXTMODE {rows}', 'VESATEST stateall',
                     f'COPY T{rows}.BIN INPUT.BIN > NUL', 'SNAPSHOT',
                     f'COPY SNAP00.BIN S{index}.BIN > NUL']
    files = run_dos(dosbox_binary, tmp_path, commands, timeout=100,
                    settings='\n[dosbox]\nmachine=svga_s3\n' +
                    ('\n[dos]\nxms=false\nems=true\n' if storage == 'ems' else ''))
    for index, (rows, height) in enumerate(((25, 39), (43, 23), (50, 20), (25, 39))):
        shot = Snapshot.read(files[f'S{index}.BIN'])
        assert (shot.width, shot.height, shot.rows, shot.cell_width, shot.cell_height) == (
            1280, 1024, rows, 16, height)
        assert shot.origin_x == 0
        assert 0 <= shot.origin_y < (rows + 1) // 2 + 1
        text = sample_text(rows)
        assert shot.text == text
        assert_cells(shot, text, 16, height)


@pytest.mark.dos
def test_explicit_font_overrides_the_installed_catalog(dosbox_binary, vesa_build, tmp_path):
    install_fonts(tmp_path, vesa_build)
    (tmp_path / 'CUSTOM.FNT').write_bytes(sized_font(12, 17))
    text = sample_text()
    (tmp_path / 'INPUT.BIN').write_bytes(b'\1' + text)
    files = run_dos(dosbox_binary, tmp_path,
                    ['READ5', 'VESA /M:104 /F:CUSTOM.FNT', 'SNAPSHOT'],
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    shot = Snapshot.read(files['SNAP00.BIN'])
    assert (shot.cell_width, shot.cell_height) == (12, 17)
    assert_cells(shot, text, 12, 17)


@pytest.mark.dos
@pytest.mark.parametrize('mode,rows,width,height', [(0x104, 43, 12, 17),
                                                   (0x106, 25, 16, 39),
                                                   (0x106, 50, 16, 20)])
def test_bundled_pack_pixels_at_screen_edges(dosbox_binary, vesa_build, tmp_path,
                                            mode, rows, width, height):
    install_fonts(tmp_path, vesa_build)
    for path in (ROOT / 'fonts/large').glob('*.FNT'):
        shutil.copy2(path, tmp_path)
    text = sample_text(rows)
    (tmp_path / 'INPUT.BIN').write_bytes(b'\1' + text)
    files = run_dos(dosbox_binary, tmp_path,
                    ['READ5', 'CKBD', f'VESA /M:{mode:x} /R:{rows}', 'SNAPSHOT'],
                    settings='\n[dosbox]\nmachine=svga_s3\n', timeout=90)
    shot = Snapshot.read(files['SNAP00.BIN'])
    assert (shot.cell_width, shot.cell_height, shot.rows) == (width, height, rows)
    assert shot.text == text
    font = (ROOT / 'fonts/large' / f'F{width:02}{height:02}.FNT').read_bytes()
    stride = (2 * width + 7) // 8
    record_bytes = (stride * height + 1) & ~1
    for row in (0, rows // 2, rows - 1):
        for column in (0, 1, 2, 76, 77, 78):
            code = 65 if column % 4 == 0 else 0xd6d0
            slot = code if code < 256 else 256 + (code // 256 - 0xa1) * 94 + (code & 255) - 0xa1
            record, = struct.unpack_from('<H', font, 32 + slot * 2)
            offset = 32 + 8434 * 4 + record * record_bytes
            half = width if column % 4 == 2 else 0
            attribute = text[(row * 80 + column) * 2 + 1]
            for plane in range(4):
                expected = []
                for y in range(height):
                    packed = int.from_bytes(font[offset + y * stride:offset + (y + 1) * stride], 'big')
                    expected.append(sum(1 << (width - 1 - x) for x in range(width)
                        if attribute & (1 << (plane if packed & (1 << (stride * 8 - 1 - x - half))
                                             else plane + 4))))
                actual = plane_bits(shot.planes[plane], shot.pitch,
                    shot.origin_x + column * width, shot.origin_y + row * height, width, height)
                assert actual == tuple(expected), (row, column, plane)
    shot.save_ppm(tmp_path / 'console.ppm')
