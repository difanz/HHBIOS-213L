"""Installed font metadata, display choices and extended-memory budgets."""
import ctypes as C
import shutil
import struct

import pytest

from qa.spec.dos import ROOT
from qa.spec.test_setup import Choices, DisplayMode, Files, capable, setup_policy
from qa.spec.test_setup_display import add_mode, mode_info

pytestmark = pytest.mark.unit


def write_font(path, width, height, records=1, legacy=False):
    record_bytes = (((2 * width + 7) // 8) * height + 1) & ~1
    payload_bytes = 8434 * 4 + records * record_bytes
    header = struct.pack('<8sHHHHI12x', b'HH20F01\n' if legacy else b'HHFONT2\n',
                         width, height, 8434, records, payload_bytes)
    path.write_bytes(header + bytes(payload_bytes))
    return payload_bytes


def scan(lib):
    result = Files()
    lib.hh_scan.argtypes = [C.POINTER(Files)]
    lib.hh_scan(result)
    return result


def chosen(lib, files, width, height, rows):
    lib.hh_font.argtypes = [C.POINTER(Files), C.c_uint, C.c_uint, C.c_uint]
    lib.hh_font.restype = C.c_char_p
    return lib.hh_font(files, width, height, rows)


def test_catalog_checks_headers_and_exact_lengths(setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_font(tmp_path/'HH20.FNT', 10, 23, legacy=True)
    write_font(tmp_path/'F1729.FNT', 17, 29)
    for name, suffix in [('F0010.FNT', b'\0'), ('F0011.FNT', None)]:
        path = tmp_path/name
        write_font(path, 12, 24)
        path.write_bytes(path.read_bytes() + suffix if suffix else path.read_bytes()[:-1])
    write_font(tmp_path/'F0012.FNT', 25, 24)  # Beyond the runtime width limit.
    write_font(tmp_path/'HH32.FNT', 16, 32)  # Printing fonts are not display candidates.
    files = scan(setup_policy)
    assert {font.name for font in files.display_fonts[:files.display_font_count]} == {
        b'HH20.FNT', b'F1729.FNT'}
    assert chosen(setup_policy, files, 1366, 768, 25) == b'F1729.FNT'
    assert chosen(setup_policy, files, 800, 600, 25) == b'HH20.FNT'
    assert chosen(setup_policy, files, 1366, 768, 50) is None


def test_auto_font_opens_higher_text_rows_without_hh20(setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_font(tmp_path/'F1729.FNT', 17, 29)
    write_font(tmp_path/'F1717.FNT', 17, 17)
    files = scan(setup_policy)
    assert not files.size[10]
    mode = DisplayMode(0x221, 1366, 768, 3, 1)
    setup_policy.hh_rows.argtypes = [C.POINTER(DisplayMode), C.POINTER(Files)]
    assert setup_policy.hh_rows(mode, files) == 3
    assert chosen(setup_policy, files, 1366, 768, 25) == b'F1729.FNT'
    assert chosen(setup_policy, files, 1366, 768, 43) == b'F1717.FNT'


def test_native_full_screen_font_wins_over_scaled_legacy(setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_font(tmp_path/'HH20.FNT', 10, 23, legacy=True)
    write_font(tmp_path/'F1023.FNT', 10, 23)
    write_font(tmp_path/'F2441.FNT', 24, 41)
    files = scan(setup_policy)
    assert chosen(setup_policy, files, 800, 600, 25) == b'HH20.FNT'
    assert chosen(setup_policy, files, 1920, 1080, 25) == b'F2441.FNT'


@pytest.mark.parametrize('version,pages', [(0x100, 1), (0x200, 0)])
def test_unbanked_mode_requires_legacy_renderer_font(setup_policy, tmp_path,
                                                     monkeypatch, version, pages):
    monkeypatch.chdir(tmp_path)
    write_font(tmp_path/'F1023.FNT', 10, 23)
    scanned = scan(setup_policy)
    machine, files = capable()
    files.display_font_count = scanned.display_font_count
    files.display_fonts = scanned.display_fonts
    machine.vbe_version = version
    add_mode(setup_policy, machine, 0x102, mode_info(800, 600, pages=pages))
    assert machine.display_modes[0].banked == 0
    choices = Choices(font=0, video=1, rows=25)
    assert b'No installed VESA font' in setup_policy.hh_validate(machine, files, choices)
    write_font(tmp_path/'HH20.FNT', 10, 23, legacy=True)
    scanned = scan(setup_policy)
    files.display_font_count = scanned.display_font_count
    files.display_fonts = scanned.display_fonts
    assert setup_policy.hh_validate(machine, files, choices) is None


def test_required_font_memory_counts_selected_payload_not_optional_fonts(
        setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    selected_bytes = write_font(tmp_path/'F1729.FNT', 17, 29, records=5000)
    write_font(tmp_path/'F1717.FNT', 17, 17, records=16868)
    write_font(tmp_path/'F2441.FNT', 24, 41, records=16868)
    scanned = scan(setup_policy)
    machine, files = capable()
    files.display_font_count = scanned.display_font_count
    files.display_fonts = scanned.display_fonts
    files.size[10] = 0
    add_mode(setup_policy, machine, 0x221, mode_info(1366, 768))
    choices = Choices(font=0, video=7, mode=0x221, rows=25)
    machine.ems_pages = 0
    machine.xms_total = machine.xms_largest = (selected_bytes + 1023) // 1024 + 36 + 256
    assert setup_policy.hh_validate(machine, files, choices) is None
    machine.xms_largest -= 1
    assert b'Insufficient XMS/EMS' in setup_policy.hh_validate(machine, files, choices)


def test_shipped_pack_covers_supported_screen_grids(setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    for path in (ROOT/'fonts/large').glob('F????.FNT'):
        shutil.copy2(path, tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT', tmp_path)
    files = scan(setup_policy)
    assert files.display_font_count == 17
    for width, height, rows, expected in [
        (800, 600, 25, b'HH20.FNT'), (1024, 768, 43, b'F1217.FNT'),
        (1280, 1024, 50, b'F1620.FNT'), (1366, 768, 25, b'F1729.FNT'),
        (1366, 768, 43, b'F1717.FNT'), (1920, 1080, 25, b'F2441.FNT'),
        (1920, 1080, 43, b'F2424.FNT'), (1920, 1080, 50, b'F2421.FNT')]:
        assert chosen(setup_policy, files, width, height, rows) == expected


def test_catalog_bound_matches_driver_scan_limit(setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_font(tmp_path/'HH20.FNT', 10, 23, legacy=True)
    for index in range(257):
        write_font(tmp_path/f'F{index:04}.FNT', 12, 24)
    files = scan(setup_policy)
    assert files.display_font_count == 257
    assert files.display_font_truncated == 1


def test_family_counts_distinct_fonts_and_bios_fallback_rows(
        setup_policy, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    legacy_bytes = write_font(tmp_path/'HH20.FNT', 10, 23, legacy=True)
    rows43_bytes = write_font(tmp_path/'F1217.FNT', 12, 17)
    rows50_bytes = write_font(tmp_path/'F1620.FNT', 16, 20)
    files = scan(setup_policy)
    machine, _ = capable()
    choices = Choices(font=0, video=1, rows=25)
    setup_policy.hh_font_family.argtypes = [C.POINTER(type(machine)),
                                           C.POINTER(Files), C.POINTER(Choices)]
    setup_policy.hh_font_family.restype = C.c_ulong
    assert setup_policy.hh_font_family(machine, files, choices) == (
        legacy_bytes + rows43_bytes + rows50_bytes)
    machine.modes = 1  # No taller BIOS fallback mode was detected.
    assert setup_policy.hh_font_family(machine, files, choices) == legacy_bytes
