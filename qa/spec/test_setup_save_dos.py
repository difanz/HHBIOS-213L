"""Repeat SETUP saves through the real MS-DOS filesystem and C runtime."""
import os
from pathlib import Path
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, digest, run_process
from qa.spec.test_dos_display import guest_build
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_legacy import ini_values, legacy_ini


@pytest.mark.dos
def test_msdos_repeated_save_replaces_backup_pair(
        dosbox_binary, msdos_image, guest_build, pytestconfig, tmp_path):
    setup = pytestconfig.getoption('--setup-exe')
    if setup is None:
        pytest.skip('Supply --setup-exe for the production setup program')
    source_hash = digest(msdos_image)
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    with image.open('rb') as disk:
        disk.seek(454)
        volume = f'{image}@@{struct.unpack("<I", disk.read(4))[0] * 512}'
    subprocess.run(['mmd', '-i', volume, '::SETPAIR'], check=True)
    copy_in(Path(setup), '::SETPAIR/SETUP.EXE')
    for name in ('READ5.COM', 'CKBD.COM', 'VGA.COM'):
        copy_in(guest_build / name, '::SETPAIR/' + name)
    copy_in(ROOT / 'fonts/HZK16', '::SETPAIR/HZK16')
    read('HHBIOS/PYMB')
    copy_in(tmp_path / 'HHBIOS/PYMB', '::SETPAIR/PYMB')

    original_ini = legacy_ini()
    original_batch = b'@ECHO OFF\r\nREM original startup\r\n'
    for name, data in {'213L.INI': original_ini, 'HHBIOS.BAT': original_batch,
                       '213L.BAK': b'older ini', 'HHBIOS.BAK': b'older batch'}.items():
        (tmp_path / name).write_bytes(data)
        copy_in(tmp_path / name, '::SETPAIR/' + name)

    commands = [
        '@ECHO OFF', 'CD \\SETPAIR', 'SETUP /REPORT > BEFORE.TXT',
        'SETUP /AUTO /FONT:XMS /VIDEO:VGA /IME:PY > SAVE1.TXT',
        'IF ERRORLEVEL 1 GOTO FAILED',
        'COPY /B HHBIOS.BAT FIRST.BAT > NUL',
        'IF ERRORLEVEL 1 GOTO FAILED',
        'COPY /B 213L.INI FIRST.INI > NUL',
        'IF ERRORLEVEL 1 GOTO FAILED',
        'COPY /B HHBIOS.BAK FIRSTB.BAK > NUL',
        'IF ERRORLEVEL 1 GOTO FAILED',
        'COPY /B 213L.BAK FIRSTI.BAK > NUL',
        'IF ERRORLEVEL 1 GOTO FAILED',
        'SETUP /AUTO /FONT:XMS /VIDEO:VGA /IME:NONE /LOW /BYTE > SAVE2.TXT',
        'IF ERRORLEVEL 1 GOTO FAILED', 'SETUP /REPORT > AFTER.TXT',
        'ECHO complete>C:\\RESULT.TXT', 'GOTO END',
        ':FAILED', 'ECHO failed>C:\\RESULT.TXT', ':END', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    (tmp_path / 'dosbox.conf').write_text(
        '[sdl]\noutput=surface\n[dosbox]\nmachine=svga_s3\nmemsize=16\n'
        '[cpu]\ncore=normal\ncputype=386\ncycles=30000\n[autoexec]\n'
        'imgmount 0 empty -fs none -t floppy\n'
        f'imgmount c "{image}" -ide 1m\nboot c:\n')
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')],
                tmp_path, 90,
                dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('RESULT.TXT').strip() == b'complete', read('SETPAIR/SAVE1.TXT')
    first_batch = read('SETPAIR/FIRST.BAT')
    first_ini = read('SETPAIR/FIRST.INI')
    assert read('SETPAIR/FIRSTB.BAK') == original_batch
    assert read('SETPAIR/FIRSTI.BAK') == original_ini
    assert read('SETPAIR/HHBIOS.BAK') == first_batch
    assert read('SETPAIR/213L.BAK') == first_ini
    final_batch = read('SETPAIR/HHBIOS.BAT')
    final_ini = read('SETPAIR/213L.INI')
    assert final_batch != first_batch
    assert b'.\\CKBD.COM /B /N' in final_batch
    assert ini_values(first_ini)[29:] == b'YNN'
    assert ini_values(final_ini)[29:] == b'NNN'
    assert [line[2:] for line in final_ini.splitlines(keepends=True)] == [
        line[2:] for line in original_ini.splitlines(keepends=True)]
    assert final_ini.endswith(b'\x1a')
    assert read('SETPAIR/BEFORE.TXT') == read('SETPAIR/AFTER.TXT')
    listing = subprocess.check_output(['mdir', '-b', '-i', volume, '::SETPAIR'])
    assert b'.$$$' not in listing
    assert digest(msdos_image) == source_hash, 'The original QA disk must remain untouched'
