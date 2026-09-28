"""An idle COMMAND prompt and partially typed line survive hotkey unload."""
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
from qa.spec.test_text_modes import textmode_build

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def prompt_build(tmp_path_factory):
    output = tmp_path_factory.mktemp('prompt-build') / 'PROMPT.COM'
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/promptcheck.c',
                    str(output), 'qa/harness/appcap.asm'], cwd=ROOT, check=True,
                   capture_output=True)
    return output


@pytest.mark.parametrize('display,rows', [('VGA', 25), ('VESA', 25), ('VESA', 43), ('VESA', 50)])
def test_pending_command_survives_unload(dosbox_binary, msdos_image, guest_build,
                                        prompt_build, textmode_build, tmp_path,
                                        display, rows):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5', 'CKBD', display):
        copy_in(guest_build / (name + '.COM'), '::HHBIOS/' + name + '.COM')
    copy_in(prompt_build, '::PROMPT.COM')
    copy_in(textmode_build, '::TEXTMODE.COM')
    startup, count = re.subn(rb'(?im)^CALL HHBIOS\.BAT', b'REM load in observer',
                             read('AUTOEXEC.BAT'))
    assert count == 1
    startup += (b'\r\n@ECHO OFF\r\nCD \\\r\nC:\\PROMPT.COM\r\n'
                b'IF ERRORLEVEL 1 GOTO FAILED\r\nECHO complete>DONE.TXT\r\n'
                b':FAILED\r\nC:\\DOS\\SHUTDOWN /S\r\n')
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(startup)
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    commands = ['@ECHO OFF', 'CD \\HHBIOS', 'READ5', 'CKBD', display,
                'CD \\', f'TEXTMODE {rows} select', 'PROMPT $P$G', 'COMMAND.COM']
    (tmp_path / 'LOAD.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'LOAD.BAT', '::LOAD.BAT')
    with PhysicalKeyboard(tmp_path, True) as keyboard:
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
                    for step in range(3):
                        packet = b''
                        while len(packet) < 2:
                            chunk = client.recv(2 - len(packet))
                            assert chunk, read('PROMPT.TXT')
                            packet += chunk
                        assert struct.unpack('<H', packet)[0] == 0x7100 + step
                        keyboard.capture(('prompt', 'pending-line', 'unloaded')[step])
                        client.sendall(b'\xa5')
                        if step == 0:
                            for key in ['e', 'c', 'h', 'o', 'space', 'k', 'e', 'e', 'p']:
                                press(keyboard, key)
                        elif step == 1:
                            for key in ['Control_L+F5'] + ['Right'] * 4 + ['Return']:
                                press(keyboard, key)
                            time.sleep(1)
                            keyboard.capture('confirm-unload')
                            press(keyboard, 'y')
                        else:
                            # Observation is complete before the first Enter.
                            for key in ['Escape', 'e', 'x', 'i', 't', 'Return']:
                                press(keyboard, key)
                    assert process.wait(timeout=20) == 0
            finally:
                if process.poll() is None:
                    keyboard.capture('final-state')
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
    assert read('DONE.TXT').strip() == b'complete'
    frames = read('PROMPT.BIN')
    assert len(frames) == 2 * 8256
    before, after = frames[:8256], frames[8256:]
    assert before[0x84] + 1 == rows
    assert after[0x84] + 1 == rows
    assert after[0x49] == 3
    assert after[0x50:0x52] == before[0x50:0x52], 'cursor moved after unload'
    assert after[256:256 + rows * 160] == before[256:256 + rows * 160]
    cursor = struct.unpack_from('<H', after, 0x50)[0]
    line = after[256 + (cursor >> 8) * 160:256 + (cursor >> 8) * 160 + 160:2]
    assert line.startswith(b'C:\\>echo keep')
