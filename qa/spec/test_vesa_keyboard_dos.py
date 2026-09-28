"""Physical Ctrl+F7 round trips with a real MS-DOS BIOS input loop."""
import os
import re
import signal
import struct
import subprocess
import time

import pytest

from qa.spec.dos import ROOT
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_dos_display import guest_build
from qa.spec.test_keymenu_dos import press
from qa.spec.test_msdos import copy_disk, msdos_image

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def vesakey_build(tmp_path_factory):
    output = tmp_path_factory.mktemp('vesakey') / 'VESAKEY.COM'
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/vesakey.c',
                    str(output)], cwd=ROOT, check=True, capture_output=True)
    return output


@pytest.mark.parametrize('mode,rows', [(0x102, 25), (0x106, 43), (0x106, 50)])
@pytest.mark.parametrize('low', [False, True], ids=['umb', 'conventional'])
def test_physical_native_text_round_trip(dosbox_binary, msdos_image, guest_build,
                                       vesakey_build, tmp_path, pytestconfig,
                                       mode, rows, low):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        copy_in(guest_build / name, '::HHBIOS/' + name)
    copy_in(vesakey_build, '::VESAKEY.COM')
    (tmp_path / 'SCREEN.KEY').touch()
    copy_in(tmp_path / 'SCREEN.KEY', '::SCREEN.KEY')
    startup, count = re.subn(rb'(?im)^CALL HHBIOS\.BAT', b'REM load in test',
                            read('AUTOEXEC.BAT'))
    assert count == 1
    suffix = ' /N' if low else ''
    commands = ['@ECHO OFF', 'CD \\HHBIOS', 'READ5' + suffix, 'CKBD /E' + suffix,
                f'VESA /M:{mode:x} /R:{rows}' + suffix, 'CD \\', 'VESAKEY',
                'IF ERRORLEVEL 1 GOTO FAILED', 'ECHO complete>DONE.TXT',
                ':FAILED', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(
        startup + b'\r\n' + ('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    with PhysicalKeyboard(tmp_path, pytestconfig.getoption('--screenshots')) as keyboard:
        config = ('[sdl]\noutput=surface\nautolock=false\n'
                  f'mapperfile={ROOT}/qa/dosbox-x.map\n'
                  '[dosbox]\nmachine=svga_s3\nmemsize=16\n[cpu]\ncycles=30000\n')
        config += keyboard.config + ('\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
                                      f'imgmount c "{image}" -ide 1m\nboot c:\n')
        (tmp_path / 'dosbox.conf').write_text(config)
        env = dict(os.environ, DISPLAY=keyboard.name, SDL_VIDEODRIVER='x11',
                   SDL_AUDIODRIVER='dummy')
        with (tmp_path / 'dosbox.log').open('wb') as log:
            process = subprocess.Popen([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')],
                                       cwd=tmp_path, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                keyboard.server.settimeout(30)
                client, _ = keyboard.server.accept()
                with client:
                    client.settimeout(30)
                    for step in range(1, 5):
                        request = b''
                        while len(request) != 2:
                            chunk = client.recv(2 - len(request))
                            assert chunk, 'guest exited before the native-text round trip'
                            request += chunk
                        assert struct.unpack('<H', request)[0] == 0x7200 + step
                        if keyboard.screenshots:
                            keyboard.capture(f'before-switch-{step}')
                        client.sendall(b'\xa5')
                        time.sleep(.15)
                        press(keyboard, 'Control_L+F7')
                    assert process.wait(timeout=30) == 0
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
    assert read('DONE.TXT').strip() == b'complete'
    data = read('VESAKEY.BIN')
    assert len(data) == 6 * 14
    records = list(struct.iter_unpack('<7H', data))
    assert records[0] == (0, 0x12, 1, 3, mode, 0, rows)
    for step in range(1, 5):
        if step % 2:
            assert records[step] == (step, 3, 0, 3, 3, 1, 25)
        else:
            assert records[step] == (step, 0x12, 0, 0x12, mode, 0, 25)
    assert records[5] == (5, 0x12, 1, 3, mode, 0, 25)
