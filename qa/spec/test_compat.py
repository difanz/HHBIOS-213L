"""Command-line, BIOS and DOS filename compatibility observations."""
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_memory import Arena, memory_build
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def compat_binary(tmp_path_factory):
    out = tmp_path_factory.mktemp('compat-build') / 'COMPAT.COM'
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/compat.c', str(out)],
                            cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    return out


@pytest.fixture
def compat_dir(guest_build, compat_binary, tmp_path):
    for file in guest_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(compat_binary, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    return tmp_path


@pytest.mark.parametrize('resident', [False, True])
def test_bios_mode_query(dosbox_binary, compat_dir, resident):
    commands = ['READ2', 'VGA'] if resident else []
    files = run_dos(dosbox_binary, compat_dir, commands + ['COMPAT modes'])
    assert struct.unpack('<4H', files['MODES.BIN'].read_bytes()) == (3, 3, 0x12, 0x12)


def test_vbe_query(dosbox_binary, compat_dir):
    files = run_dos(dosbox_binary, compat_dir, ['COMPAT vbe'],
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    assert files['VSTATUS.BIN'].read_bytes() == b'\x4f\0\x4f\0'
    info, mode = files['VBE.BIN'].read_bytes(), files['VMODE.BIN'].read_bytes()
    assert len(info) == 512 and info[:4] == b'VESA'
    assert struct.unpack_from('<H', info, 4)[0] >= 0x102
    assert struct.unpack_from('<H', info, 18)[0] > 0
    assert len(mode) == 256 and mode[0] & 1
    assert struct.unpack_from('<2H', mode, 18) == (640, 480)
    assert mode[25] == 8


def test_gb2312_filename_roundtrip(dosbox_binary, compat_dir):
    # Establish emulator/filesystem support before involving HHBIOS.
    for resident in (False, True):
        directory = compat_dir / str(resident)
        directory.mkdir()
        for path in compat_dir.iterdir():
            if path.is_file():
                shutil.copy2(path, directory)
        commands = ['READ2', 'VGA'] if resident else []
        files = run_dos(dosbox_binary, directory, commands + ['COMPAT filename'])
        error, = struct.unpack('<H', files['CREATE.BIN'].read_bytes())
        if not resident and error:
            pytest.skip(f'emulator rejects GB2312 filename before HHBIOS: DOS error {error}')
        assert error == 0, 'HHBIOS interfered with DOS filename creation'
        assert files['NAME.BIN'].read_bytes() == '中文.TXT'.encode('gb2312')
        assert files['CONTENT.BIN'].read_bytes() == b'GBK\n'


def test_command_line_help_modes_and_duplicate_install(dosbox_binary, memory_build, tmp_path):
    for file in memory_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    keyboard_config(tmp_path)
    files = run_dos(dosbox_binary, tmp_path, [
        'MEMORY BEFORE.TXT', 'VGA /? > VGA.TXT', 'CKBD /? > CKBD.TXT',
        'MEMORY HELP.TXT', ('CMODE > MODE3.TXT', 3), ('CMODE 12', 0x12),
        ('CMODE > MODE12.TXT', 0x12), ('CMODE 3', 3), 'READ5', 'CKBD',
        'MEMORY FIRST.TXT', ('CKBD > ALREADY.TXT', 1), 'MEMORY SECOND.TXT',
        'MEMORY off', 'MEMORY FREE.TXT'])
    assert b'VGA [/B]' in files['VGA.TXT'].read_bytes()
    assert b'2.13L' in files['CKBD.TXT'].read_bytes()
    assert b'Curent displey mode is 03.' in files['MODE3.TXT'].read_bytes()
    assert b'Curent displey mode is 12.' in files['MODE12.TXT'].read_bytes()
    assert b'CKBD IS ALREADY!' in files['ALREADY.TXT'].read_bytes()
    before, help_, first, second, freed = (Arena(files[name+'.TXT'])
                                          for name in ('BEFORE', 'HELP', 'FIRST', 'SECOND', 'FREE'))
    for a, b in ((before, help_), (first, second), (before, freed)):
        assert a.vectors == b.vectors
        assert (a.occupied(), a.occupied(True), a.xms, a.ems) == (
                b.occupied(), b.occupied(True), b.xms, b.ems)
