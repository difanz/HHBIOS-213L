"""Physical menu input while a foreground program waits inside real MS-DOS."""
import os
import re
import signal
import struct
import subprocess
import time

import pytest

from qa.spec.dos import ROOT
from qa.spec.test_dos_display import guest_build
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_memory import Arena, memory_build
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_application import keyboard_config

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def keymenu_build(tmp_path_factory):
    output = tmp_path_factory.mktemp('keymenu-dos') / 'KEYMENU.COM'
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/keymenu.c',
                    str(output)], cwd=ROOT, check=True, capture_output=True)
    return output


def press(keyboard, chord, settle=.15):
    keys = chord.split('+')
    for key in keys:
        keyboard.event(key, True)
        time.sleep(.06)
    for key in reversed(keys):
        keyboard.event(key, False)
    time.sleep(settle)


def operate_menu(keyboard, process):
    keyboard.server.settimeout(25)
    client, _ = keyboard.server.accept()
    with client:
        client.settimeout(15)
        # Two complete load/unload cycles, including uppercase confirmation.
        for cycle in range(2):
            for step, answer in enumerate((['n'], ['Shift_L+n'], ['Escape'],
                                           ['Return', 'x', 'Return', 'n'],
                                           ['y' if cycle == 0 else 'Shift_L+y'])):
                request = b''
                while len(request) < 2:
                    chunk = client.recv(2-len(request))
                    assert chunk, 'guest exited before completing its menu checks'
                    request += chunk
                assert struct.unpack('<H', request)[0] == 0x7000+step
                # Release the guest into DOS's blocking read before IRQ1.
                client.sendall(b'\xa5')
                time.sleep(.15)
                press(keyboard, 'Control_L+F5')
                if step == 0 and keyboard.screenshots:
                    keyboard.capture(f'menu-groups-{cycle}')
                press(keyboard, '2')
                if step == 0 and keyboard.screenshots:
                    keyboard.capture(f'menu-display-{cycle}')
                press(keyboard, 'Escape')
                # 4 opens 退出, then 1 runs 退出汉字 and its confirmation.
                for key in ('4', '1'):
                    press(keyboard, key)
                time.sleep(1)
                if keyboard.screenshots:
                    keyboard.capture(f'confirmation-{cycle}-{step}')
                for index, key in enumerate(answer):
                    press(keyboard, key, settle=0 if index == len(answer)-1 else .15)
                # Type immediately while cancellation can still be repainting.
                # The menu must preserve this foreground key, not clear the queue.
                press(keyboard, 'period')
                if keyboard.screenshots and (cycle, step) != (1, 4):
                    keyboard.capture(f'answer-{cycle}-{step}')
        assert process.wait(timeout=20) == 0


@pytest.mark.parametrize('display', ['VGA', 'VESA'])
@pytest.mark.parametrize('low', [False, True], ids=['umb', 'conventional'])
@pytest.mark.parametrize('input_mode', ['dos', 'bios', 'poll'])
def test_menu_cancel_unload_and_reload(dosbox_binary, msdos_image, memory_build,
                                     keymenu_build, tmp_path, pytestconfig, display, low,
                                     input_mode):
    run_menu_case(dosbox_binary, msdos_image, memory_build, keymenu_build,
                  tmp_path, pytestconfig, display, low, input_mode)


def test_menu_with_native_24_pixel_font(dosbox_binary, msdos_image, memory_build,
                                      keymenu_build, tmp_path, pytestconfig):
    run_menu_case(dosbox_binary, msdos_image, memory_build, keymenu_build,
                  tmp_path, pytestconfig, 'VESA', False, 'dos',
                  video_options=' /M:104 /F:F1229.FNT')


def run_menu_case(dosbox_binary, msdos_image, memory_build, keymenu_build,
                  tmp_path, pytestconfig, display, low, input_mode, machine='svga_s3',
                  video_options=''):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5', 'CKBD', display):
        copy_in(memory_build / (name+'.COM'), '::HHBIOS/'+name+'.COM')
    if video_options:
        copy_in(ROOT/'fonts/large/F1229.FNT', '::HHBIOS/F1229.FNT')
    copy_in(memory_build/'MEMORY.COM', '::MEMORY.COM')
    copy_in(keymenu_build, '::KEYMENU.COM')
    # Exercise both the distribution's Scroll Lock binding and the historical
    # left Shift binding. Shift used for N/Y must stay inside the open menu.
    keyboard_config(tmp_path)
    settings = (tmp_path/'213L.INI').read_bytes().split(b'\r\n')
    settings[9] = b'02H' if low else b'10H'
    (tmp_path/'213L.INI').write_bytes(b'\r\n'.join(settings))
    copy_in(tmp_path/'213L.INI', '::HHBIOS/213L.INI')
    (tmp_path/'SCREEN.KEY').touch()
    copy_in(tmp_path/'SCREEN.KEY', '::SCREEN.KEY')
    startup = read('AUTOEXEC.BAT')
    startup, count = re.subn(rb'(?im)^CALL HHBIOS\.BAT', b'REM load in test', startup)
    assert count == 1
    suffix = ' /N' if low else ''
    commands = ['@ECHO OFF', 'CD \\', 'MEMORY BEFORE.TXT']
    for cycle in range(2):
        commands += ['CD \\HHBIOS', 'READ5'+suffix, 'CKBD /E'+suffix, display+suffix+video_options,
                     'CD \\', f'MEMORY LIVE{cycle}.TXT', 'KEYMENU '+input_mode,
                     'IF ERRORLEVEL 1 GOTO FAILED', f'MEMORY FREE{cycle}.TXT']
    commands += ['ECHO complete>DONE.TXT', ':FAILED', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(startup+b'\r\n'+('\r\n'.join(commands)+'\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    with PhysicalKeyboard(tmp_path, pytestconfig.getoption('--screenshots')) as keyboard:
        config = ('[sdl]\noutput=surface\nautolock=false\n'
                  f'mapperfile={ROOT}/qa/dosbox-x.map\n'
                  f'[dosbox]\nmachine={machine}\nmemsize=16\n[cpu]\ncycles=30000\n')
        config += keyboard.config + ('\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
                                      f'imgmount c "{image}" -ide 1m\nboot c:\n')
        (tmp_path/'dosbox.conf').write_text(config)
        env = dict(os.environ, DISPLAY=keyboard.name, SDL_VIDEODRIVER='x11', SDL_AUDIODRIVER='dummy')
        with (tmp_path/'dosbox.log').open('wb') as log:
            process = subprocess.Popen([str(dosbox_binary), '-conf', str(tmp_path/'dosbox.conf')],
                                       cwd=tmp_path, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                operate_menu(keyboard, process)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
    assert read('DONE.TXT').strip() == b'complete'
    read('BEFORE.TXT')
    before = Arena(tmp_path/'BEFORE.TXT')
    for cycle in range(2):
        read(f'LIVE{cycle}.TXT')
        read(f'FREE{cycle}.TXT')
        live = Arena(tmp_path/f'LIVE{cycle}.TXT')
        freed = Arena(tmp_path/f'FREE{cycle}.TXT')
        for interrupt in (9, 0x16, 0x28):
            assert (live.resident(interrupt) < 0xa000) == low
        assert freed.vectors == before.vectors
        assert (freed.xms, freed.ems) == (before.xms, before.ems)
        assert freed.occupied() == before.occupied()
        assert freed.occupied(True) == before.occupied(True)
