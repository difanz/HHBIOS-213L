"""Interactive SETUP returns an empty normal console to DOS."""
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT
from qa.spec.test_application import keyboard_config
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup import setup_guest
from qa.spec.test_setup_ui import run_setup_ui

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def setup_exit_probe(tmp_path_factory):
    output = tmp_path_factory.mktemp('setup-exit-probe') / 'SETUP.COM'
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/setupexit.c',
                    str(output)], cwd=ROOT, check=True, capture_output=True)
    return output


@pytest.mark.parametrize('driver,language,cpu', [
    ('', 'EN', '8086'), ('', 'ZH', '8086'),
    ('VGA', 'EN', '386'), ('VGA', 'ZH', '386'),
    ('VESA', 'EN', '386'), ('VESA', 'ZH', '386'),
    ('VESA /M:106 /R:50 /F:F1620.FNT', 'ZH', '386'),
])
def test_setup_exit_clears_cells_without_resetting_resident_display(
        dosbox_binary, setup_guest, setup_exit_probe, driver, language, cpu):
    # DOS resolves the observer COM first; it explicitly executes SETUP.EXE
    # and captures the screen before the command interpreter resumes.
    shutil.copy2(setup_exit_probe, setup_guest)
    keyboard_config(setup_guest)
    if '/R:50' in driver:
        shutil.copy2(ROOT / 'fonts/large/F1620.FNT', setup_guest)
    startup = f'READ5\nCKBD /E\n{driver}' if driver else ''
    run_setup_ui(dosbox_binary, setup_guest, f'/{language}',
                 ['capture', 'Alt-x'], startup=startup, cpu=cpu)
    assert_console_exit(*[(setup_guest / name).read_bytes()
                          for name in ('BEFORE.BIN', 'AFTER.BIN')])


def test_setup_exit_under_msdos(dosbox_binary, setup_guest, setup_exit_probe, msdos_image):
    image, copy_in, read = copy_disk(msdos_image, setup_guest)
    for name in ('SETUP.EXE', 'READ5.COM', 'CKBD.COM', 'VESA.COM', 'HZK16', 'HH20.FNT'):
        copy_in(setup_guest / name, '::HHBIOS/' + name)
    copy_in(setup_exit_probe, '::HHBIOS/SETUP.COM')
    commands = ['@ECHO OFF', 'CD \\HHBIOS', 'READ5', 'CKBD /E', 'VESA /F:HH20.FNT',
                'SETUP.COM /ZH', 'IF ERRORLEVEL 1 GOTO FAILED',
                'ECHO complete>C:\\DONE.TXT', ':FAILED', 'C:\\DOS\\SHUTDOWN /S']
    (setup_guest / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(setup_guest / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    run_setup_ui(dosbox_binary, setup_guest, '', ['capture', 'Alt-x'], boot_image=image)
    assert read('DONE.TXT').strip() == b'complete'
    assert_console_exit(read('HHBIOS/BEFORE.BIN'), read('HHBIOS/AFTER.BIN'))


def assert_console_exit(before, after):
    previous, current = [struct.unpack_from('<15H', data) for data in (before, after)]
    assert current[:4] == previous[:4], 'logical mode, geometry or page changed'
    assert current[4] == 0, 'cursor did not return to the top left'
    assert current[5] == previous[5] & 0x1f1f, 'cursor shape was not restored'
    assert current[6:] == previous[6:], 'resident driver or surface changed'
    text_end = 30 + current[1] * current[2] * 2
    assert after[30:text_end] == b' \x07' * (current[1] * current[2])
    if current[7]:
        _, _, rows, _, _, _, _, _, _, height, pitch, top, scale, cell_height, _ = current
        plane_bytes = height * pitch
        status_top = (top + rows * cell_height * scale) * pitch
        status_end = status_top + cell_height * scale * pitch
        assert len(after) == len(before) == text_end + plane_bytes * 4
        status = []
        for plane in range(4):
            start = text_end + plane * plane_bytes
            # The first character line may contain the blinking caret. The
            # rest of the console must also be black in actual scanout.
            first_line_end = (top + cell_height * scale) * pitch
            assert not any(after[start + first_line_end:start + status_top])
            old = before[start + status_top:start + status_end]
            new = after[start + status_top:start + status_end]
            assert new == old, 'HHBIOS status bar changed on SETUP exit'
            status.append(old)
        assert any(any(plane) for plane in status), 'status bar was not visible'
