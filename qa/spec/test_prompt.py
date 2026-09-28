"""IME row pixels, independently of an application's own status/footer row."""
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, plane_bits, run_dos
from qa.spec.pixels import colored_rows, native_rows
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def prompt_build(tmp_path_factory):
    out = tmp_path_factory.mktemp('prompt')/'PRMTEST.COM'
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh',
                             'qa/harness/prompt.c', str(out)],
                            cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    return out


@pytest.mark.parametrize('keep', [False, True])
def test_prompt_lifetime_bitmaps_and_visibility(dosbox_binary, guest_build, prompt_build, tmp_path, keep):
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        shutil.copy2(guest_build/name, tmp_path)
    for name in ('HZK16', 'HH20.FNT'):
        shutil.copy2(ROOT/'fonts'/name, tmp_path)
    shutil.copy2(prompt_build, tmp_path)
    keyboard_config(tmp_path)
    if not keep:
        config = tmp_path/'213L.INI'
        config.write_bytes(b'00'+config.read_bytes()[2:])
    files = run_dos(dosbox_binary, tmp_path, ['READ5', 'CKBD', 'VESA', 'PRMTEST'],
                    timeout=90, settings='\n[dosbox]\nmachine=svga_s3\n')
    raw = files['PROMPT.BIN'].read_bytes()
    frames = []
    while raw:
        assert len(raw) >= 16
        width, height, pitch, rows, ch, ox, oy, scale = struct.unpack_from('<8H', raw)
        assert scale == 1 and ox+800 <= width and oy+(rows+1)*ch <= height
        size = pitch*ch
        assert len(raw) >= 16+4*size
        planes = [raw[16+p*size:16+(p+1)*size] for p in range(4)]
        frames.append((rows, ch, ox, pitch, planes))
        raw = raw[16+4*size:]
    assert [f[0] for f in frames] == [25, 25, 50, 43, 43, 25, 25, 25]

    def cell(frame, col, glyph, attribute):
        rows, ch, ox, pitch, planes = frame
        for p, plane in enumerate(planes):
            actual = plane_bits(plane, pitch, ox+col*10, 0, 10, ch)
            assert actual == colored_rows(glyph, 10, ch, attribute, p), (rows, col, p)

    # Opening is optional. A closed bar stays hidden through repaint.
    for n in (0, 7):
        if keep:
            cell(frames[n], 1, native_rows(0xd3a2), 0x70)
        else:
            assert not any(b for plane in frames[n][-1] for b in plane)
    assert not any(b for plane in frames[6][-1] for b in plane)
    for frame in frames[1:6]:
        cell(frame, 0, native_rows(ord('A')), 0x2e)
        for half in (0, 1):
            cell(frame, 1+half, native_rows(0xd6d0, half), 0x2e)
        cell(frame, 3, native_rows(ord('C')), 0x2e)
        for col in range(70, 76):
            cell(frame, col, native_rows(ord('Z')), 0x3f)
        for col, source in ((76, 0), (77, 1), (78, 0)):
            glyph = bytes(((source*16+y)*7+3) & 255 for y in range(16))+b'\0\0'
            cell(frame, col, glyph, 0x4b)
        cell(frame, 79, native_rows(ord('B')), 0x2e)
