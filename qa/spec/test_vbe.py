"""VBE 1.x callers sharing a display with the resident VGA driver."""
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, run_dos
from qa.spec.machine import blank, put
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build, assert_pixels

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def vbe_binary(tmp_path_factory):
    out = tmp_path_factory.mktemp('vbe-build') / 'VBE.COM'
    p = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/vbe.c', str(out)],
                       cwd=ROOT, capture_output=True, text=True)
    assert p.returncode == 0, p.stdout+p.stderr
    return out


def prepare(directory, guest_build, vbe_binary, resident):
    directory.mkdir()
    for file in (*guest_build.glob('*.COM'), vbe_binary):
        shutil.copy2(file, directory)
    shutil.copy2(ROOT / 'fonts/HZK16', directory)
    keyboard_config(directory)
    screen = blank()
    put(screen, 2, 10, '中文'.encode('gb2312'))
    (directory / 'INPUT.BIN').write_bytes(bytes([3])+bytes(screen))
    return ['READ5', 'CKBD', 'VGA'] if resident else []


def assert_chinese(files):
    shot = Snapshot.read(files['SNAP00.BIN'])
    font = (ROOT / 'fonts/HZK16').read_bytes()
    for col, (hi, lo) in zip((10, 12), ((0xd6, 0xd0), (0xce, 0xc4))):
        offset = ((hi-0xa1)*94 + lo-0xa1)*32
        glyph = font[offset:offset+32]
        for half in range(2):
            assert_pixels(shot, 2, col+half, glyph[half::2]+b'\0\0', 7)


@pytest.mark.parametrize('adapter', ['vesa_oldvbe', 'vesa_nolfb', 'svga_s3'])
@pytest.mark.parametrize('number', [0x101, 0x103], ids=['640x480', '800x600'])
@pytest.mark.parametrize('method', ['banked', 'far'], ids=['int10', 'WinFuncPtr'])
def test_vbe_banked_coexistence(dosbox_binary, guest_build, vbe_binary, tmp_path, adapter, number, method):
    observed = []
    for resident in (False, True):
        directory = tmp_path / str(resident)
        commands = prepare(directory, guest_build, vbe_binary, resident)
        commands += [f'VBE {method} {number:x}']
        if resident:
            commands += ['SNAPSHOT']
        files = run_dos(dosbox_binary, directory, commands,
                        settings=f'\n[dosbox]\nmachine={adapter}\n')
        ctrl, mode = (files[n+'.BIN'].read_bytes() for n in ('CTRL', 'MODE'))
        assert len(ctrl) == 544 and ctrl[:16] == b'\xa5'*16 and ctrl[272:] == b'\xa5'*272
        assert len(mode) == 288 and mode[:16] == mode[-16:] == b'\xa5'*16
        assert ctrl[16:20] == b'VESA'
        version, = struct.unpack_from('<H', ctrl, 20)
        if adapter == 'vesa_oldvbe':
            assert version == 0x102
        else:
            assert version >= 0x200
        mi = mode[16:272]
        width, height = struct.unpack_from('<HH', mi, 18)
        assert (width, height) == ((640, 480) if number == 0x101 else (800, 600))
        stride, = struct.unpack_from('<H', mi, 16)
        expected = bytes((i ^ (i >> 8) ^ (i >> 16)) & 255 for i in range(stride*height))
        assert files['FRAME.BIN'].read_bytes() == expected
        assert number in struct.unpack('<'+'H'*(files['LIST.BIN'].stat().st_size//2), files['LIST.BIN'].read_bytes())
        observed.append((ctrl[16:22], ctrl[26:30], ctrl[34:36], mode, files['LIST.BIN'].read_bytes()))
        if resident:
            assert_chinese(files)
    assert observed[0] == observed[1], 'resident driver changed VBE capability results'


def test_vbe_failed_mode_keeps_chinese(dosbox_binary, guest_build, vbe_binary, tmp_path):
    directory = tmp_path / 'invalid'
    commands = prepare(directory, guest_build, vbe_binary, True)
    files = run_dos(dosbox_binary, directory, commands+['VBE invalid 1ff', 'SNAPSHOT'],
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    assert_chinese(files)
