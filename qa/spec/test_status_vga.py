"""The complete VGA status strip must fit before direct B800 text memory."""
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.dos


@pytest.mark.parametrize('options', ['', ' /Z'], ids=['direct-text', 'graphics'])
def test_vga_status_frame_and_restore(dosbox_binary, guest_build, tmp_path, options):
    for name in ('VGA.COM', 'CKBD.COM', 'READ5.COM'):
        shutil.copy2(guest_build / name, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    keyboard_config(tmp_path)
    config = tmp_path / '213L.INI'
    config.write_bytes(b'00' + config.read_bytes()[2:])
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/statusv.c',
                    str(tmp_path / 'STATUSV.COM')], cwd=ROOT, check=True, capture_output=True)
    files = run_dos(dosbox_binary, tmp_path, ['READ5', 'CKBD', 'VGA' + options, 'STATUSV'],
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    data = files['STATUSV.BIN'].read_bytes()
    assert len(data) == 2 + 3 * 4 * 65536
    start, = struct.unpack_from('<H', data)
    assert start == (0 if options else 0xe020)
    status = (start + 450 * 80) & 65535
    saved = (start + 480 * 80) & 65535
    for plane in range(4):
        frames = [data[2 + (frame * 4 + plane) * 65536:][:65536] for frame in range(3)]
        before, opened, closed = frames
        expected = bytearray(before)
        expected[saved:saved + 2400] = before[status:status + 2400]
        assert closed == expected, 'Closing changed pixels outside the save area'
        for row in range(30):
            color = 15 if row == 0 else 8 if row == 29 else 7
            expected[status + row * 80:status + (row + 1) * 80] = bytes([
                255 if color & (1 << plane) else 0]) * 80
        assert opened == expected, 'Opening changed application pixels or B800 text'
