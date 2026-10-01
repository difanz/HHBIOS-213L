"""Direct-color linear framebuffer console on a BIOS-selected VBE mode."""
import os
import shutil
import struct
import subprocess

import pytest

from qa.spec.build import asm_includes, source_file
from qa.spec.dos import ROOT, run_dos
from qa.spec.pixels import native_rows

pytestmark = pytest.mark.dos


@pytest.fixture(scope='module')
def linear_guest(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('lfb-guest')
    env = {k: v for k, v in os.environ.items() if k != 'JWASM'}
    result = subprocess.run([assembler, '-q', '-Zm', '-bin', *asm_includes(source_dir),
                             f'-Fo{out}/READ5.COM', str(source_file(source_dir, 'READ5.ASM'))],
                            env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    built = subprocess.run(['bash', 'tools/build-vesa.sh', str(out / 'VESA.COM'), str(source_dir)],
                           cwd=ROOT, env=dict(env, JWASM=assembler), capture_output=True, text=True)
    assert built.returncode == 0, built.stdout + built.stderr
    return out

RGB = (
    (0x00, 0x00, 0x00), (0x00, 0x00, 0xaa), (0x00, 0xaa, 0x00), (0x00, 0xaa, 0xaa),
    (0xaa, 0x00, 0x00), (0xaa, 0x00, 0xaa), (0xaa, 0x55, 0x00), (0xaa, 0xaa, 0xaa),
    (0x55, 0x55, 0x55), (0x55, 0x55, 0xff), (0x55, 0xff, 0x55), (0x55, 0xff, 0xff),
    (0xff, 0x55, 0x55), (0xff, 0x55, 0xff), (0xff, 0xff, 0x55), (0xff, 0xff, 0xff),
)


def pack_channel(value, size, position):
    if size < 8:
        value >>= 8 - size
    return (value & ((1 << size) - 1)) << position


def pack_color(index, masks):
    red, green, blue = RGB[index]
    return (pack_channel(red, masks[0], masks[1]) |
            pack_channel(green, masks[2], masks[3]) |
            pack_channel(blue, masks[4], masks[5]))


def test_vesa_direct_color_linear_console(dosbox_binary, linear_guest, tmp_path):
    for name in ('READ5.COM', 'VESA.COM'):
        shutil.copy2(linear_guest / name, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    shutil.copy2(ROOT / 'fonts/HH20.FNT', tmp_path)
    for source, output in (('qa/harness/selectlfb.c', 'LFBSEL.COM'),
                           ('qa/harness/vesalfb.c', 'LFBDUMP.COM')):
        built = subprocess.run(['bash', 'tools/build-watcom-com.sh', source,
                                str(tmp_path / output)], cwd=ROOT, capture_output=True, text=True)
        assert built.returncode == 0, built.stdout + built.stderr
    settings = '\n' + (ROOT / 'qa/profiles/vesa-hd.conf').read_text()
    files = run_dos(dosbox_binary, tmp_path,
                    ['READ5', 'LFBSEL', 'CALL VMODE.BAT', 'LFBDUMP'],
                    timeout=60, settings=settings)
    if 'UNSUP.TXT' in files:
        pytest.skip('BIOS published no direct-color linear console mode')
    data = files['VLF.BIN'].read_bytes()
    status = data[0]
    assert status == 0, status
    fields = struct.unpack_from('<16H', data, 1)
    (bpp, byte_n, pitch, width, height, vx, vy, scale, fw, rh, cell_w, cell_h,
     idle_lo, idle_hi, edit_lo, edit_hi) = fields
    masks = tuple(data[1 + 32:1 + 38])
    assert bpp in (15, 16, 32) and byte_n == (4 if bpp == 32 else 2)
    assert cell_w == fw * scale and cell_h == rh * scale and pitch >= width * byte_n
    assert (idle_hi, idle_lo) == (0, 0)
    edited = (edit_hi << 16) | edit_lo
    plane = pitch * height
    assert 0 < edited < min(65536, max(plane // 8, 1)), edited
    pixels = data[1 + 38:]
    row_bytes = cell_w * byte_n
    assert len(pixels) == 3 * cell_h * row_bytes

    def cell(index):
        base = index * cell_h * row_bytes
        return [pixels[base + y * row_bytes:base + (y + 1) * row_bytes] for y in range(cell_h)]

    def value_at(row, x):
        raw = row[x * byte_n:(x + 1) * byte_n]
        return int.from_bytes(raw, 'little')

    blank = cell(0)
    background = pack_color(0, masks)
    assert all(value_at(row, x) == background for row in blank for x in range(cell_w))
    if fw == 10 and rh == 23:
        foreground = pack_color(14, masks)
        background = pack_color(1, masks)
        for half in (0, 1):
            glyph = native_rows(0xd6d0, half)
            drawn = cell(1 + half)
            for y in range(23):
                for x in range(10):
                    ink = (glyph[y] >> (9 - x)) & 1
                    expected = foreground if ink else background
                    for sy in range(scale):
                        for sx in range(scale):
                            assert value_at(drawn[y * scale + sy], x * scale + sx) == expected
    else:
        foreground = pack_color(14, masks)
        background = pack_color(1, masks)
        seen = {value_at(row, x) for row in cell(1) for x in range(cell_w)}
        assert foreground in seen and background in seen


def _bench_fields(text):
    header = {}
    rows = {}
    for line in text.splitlines():
        if line.startswith('STATUS='):
            for part in line.split():
                key, value = part.split('=', 1)
                header[key] = value
        elif ' ' in line:
            name, rest = line.split(' ', 1)
            rows[name] = {key: int(value) for key, value in
                          (part.split('=') for part in rest.split())}
    return header, rows


def test_lfb_dirty_refresh_byte_budget(dosbox_binary, linear_guest, tmp_path):
    """Idle stores nothing, and dirty work grows from a few cells to a full frame.

    Absolute milliseconds are not asserted: the PIT sample is for the note in
    qa/lfb-bench.md, while the byte counter is the stable contract.
    """
    for name in ('READ5.COM', 'VESA.COM'):
        shutil.copy2(linear_guest / name, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    shutil.copy2(ROOT / 'fonts/HH20.FNT', tmp_path)
    built = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/lfbbench.c',
                            str(tmp_path / 'LFBBEN.COM')], cwd=ROOT, capture_output=True, text=True)
    assert built.returncode == 0, built.stdout + built.stderr
    listed = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/lfblist.c',
                             str(tmp_path / 'LFBLIST.COM')], cwd=ROOT, capture_output=True, text=True)
    assert listed.returncode == 0, listed.stdout + listed.stderr
    settings = '\n' + (ROOT / 'qa/profiles/vesa-hd.conf').read_text()
    modes = run_dos(dosbox_binary, tmp_path, ['LFBLIST'], timeout=30, settings=settings)
    catalog = modes['MODES.TXT'].read_text().lower() if 'MODES.TXT' in modes else ''
    saw = False
    for mode in ('114', '245'):
        if f'mode={mode} ' not in catalog and f'mode={mode}\n' not in catalog:
            continue
        saw = True
        case = tmp_path / mode
        case.mkdir()
        for name in ('READ5.COM', 'VESA.COM', 'LFBBEN.COM', 'HZK16', 'HH20.FNT'):
            shutil.copy2(tmp_path / name, case)
        files = run_dos(dosbox_binary, case,
                        ['READ5', f'VESA /M:{mode} /F:HH20.FNT', 'LFBBEN'],
                        timeout=120, settings=settings)
        header, rows = _bench_fields(files['BENCH.TXT'].read_text())
        assert header.get('STATUS') == 'ok', header
        assert header.get('MODE') == mode
        assert int(header['BPP']) in (15, 16, 32)
        pitch = int(header['PITCH'])
        height = int(header['H'])
        idle = rows['IDLE8']['bytes']
        sparse = rows['SPARSE4']['bytes']
        line = rows['LINE80']['bytes']
        full = rows['FULL_BLANK']['bytes']
        hanzi = rows['FULL_HANZI']['bytes']
        assert idle == 0
        assert 0 < sparse < line < full
        assert full == hanzi == rows['FULL_BLANK2']['bytes']
        assert full < pitch * height
    if not saw:
        pytest.skip('BIOS published neither mode 114h nor 245h')
