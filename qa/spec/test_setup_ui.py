"""Exercise the DOS UI with physical keys and inspect the saved configuration."""
import os
import struct
import subprocess
import time

import pytest

from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_setup import setup_guest
from qa.spec.test_msdos import copy_disk, msdos_image


def run_setup_ui(binary, directory, options, keys_to_press, *, cpu='386', boot_image=None, settings=''):
    with PhysicalKeyboard(directory, screenshots=True) as keyboard:
        config = ('[sdl]\noutput=surface\nshowmenu=false\nautolock=false\nmouse_emulation=locked\n'
                  '[dos]\nvmware=true\n'
                  '[dosbox]\nmachine=svga_s3\n'
                  f'[cpu]\ncore=normal\ncputype={cpu}\ncycles=30000\n'
                  f'{settings}\n'
                  '[autoexec]\n'
                  f'mount c "{directory}"\nc:\n'
                  f'SETUP {options}\nif errorlevel 1 goto failed\n'
                  'echo done>DONE.TXT\nexit\n:failed\necho failed>FAIL.TXT\nexit\n')
        if boot_image:
            config = config.split('[autoexec]')[0] + (
                '[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
                f'imgmount c "{boot_image}" -ide 1m\nboot c:\n')
        (directory/'dosbox.conf').write_text(config)
        with (directory/'dosbox.log').open('wb') as log:
            process = subprocess.Popen(
                [str(binary), '-conf', str(directory/'dosbox.conf')], cwd=directory,
                env=dict(os.environ, DISPLAY=keyboard.name, SDL_VIDEODRIVER='x11',
                         SDL_AUDIODRIVER='dummy'), stdout=log, stderr=subprocess.STDOUT)
            try:
                time.sleep(3)
                deadline = time.monotonic() + 30
                while True:
                    assert process.poll() is None, 'SETUP exited before showing its UI'
                    keyboard.capture('startup')
                    shot = directory/keyboard.captures[-1]['file']
                    pixels = subprocess.check_output(['convert', str(shot), '-depth', '8', 'rgb:-'])
                    blue = sum(b > 100 and r < 30 and g < 30
                               for r,g,b in zip(pixels[::3], pixels[1::3], pixels[2::3]))
                    ready = blue > len(pixels)/3*.8
                    if ready:
                        keyboard.captures[-1]['before_key'] = 'home'
                        break
                    assert time.monotonic() < deadline, 'SETUP did not show its dialog'
                    time.sleep(.5)
                for key in keys_to_press:
                    if isinstance(key, tuple):
                        col, row = key
                        width = keyboard.captures[-1]['width']
                        assert keyboard.t.XTestFakeMotionEvent(
                            keyboard.display, -1, col*width//80+width//160, row*16+8, 0)
                        keyboard.x.XSync(keyboard.display, 0)
                        time.sleep(.25)
                        for pressed in (1, 0):
                            assert keyboard.t.XTestFakeButtonEvent(keyboard.display, 1, pressed, 0)
                            keyboard.x.XSync(keyboard.display, 0)
                            time.sleep(.15)
                        time.sleep(.4)
                        continue
                    if key == 'capture':
                        keyboard.capture('dialog')
                        continue
                    alt = key.startswith('Alt-')
                    key = key.removeprefix('Alt-')
                    if alt:
                        keyboard.event('Alt_L', True)
                    keyboard.event(key, True)
                    time.sleep(.08)
                    keyboard.event(key, False)
                    if alt:
                        keyboard.event('Alt_L', False)
                    time.sleep(.4)
                process.wait(timeout=15)
                if not boot_image:
                    assert (directory/'DONE.TXT').exists()
                    assert not (directory/'FAIL.TXT').exists()
            finally:
                if process.poll() is None:
                    keyboard.capture('failure')
                    process.kill()
                    process.wait()


@pytest.mark.dos
@pytest.mark.parametrize('language',['EN','ZH'])
def test_setup_controls_save_selected_configuration(dosbox_binary, setup_guest, language):
    run_setup_ui(dosbox_binary, setup_guest, f'/{language} /FONT:XMS /VIDEO:102', [
        # Change both radio groups, then cancel: neither change may be saved.
        'Alt-m', 'Down', 'Tab', 'Down', 'Escape',
        # Select EMS and conventional residency, then accept.
        'Alt-m', 'Down', 'Tab', 'Down', 'capture', 'Return',
        'Alt-v', 'Up', 'Return',
        # Enable Wubi and disable whole-character editing.
        'Alt-i', 'Alt-w', 'Tab', 'space', 'capture', 'Return',
        'F2', 'capture', 'Return',
        'F3', 'End', 'capture', 'Alt-s', 'Return', 'Alt-x',
    ])
    batch = (setup_guest/'HHBIOS.BAT').read_text()
    assert '.\\READ4.COM /N' in batch
    assert '.\\VGA.COM /N' in batch
    assert '.\\CKBD.COM /B /N' in batch
    assert '.\\WBX.COM' in batch
    assert '.\\READ2.COM' not in batch and '.\\VESA.COM' not in batch
    assert (setup_guest/'213L.INI').is_file()


@pytest.mark.dos
@pytest.mark.parametrize('language',['EN','ZH'])
def test_setup_runs_on_8086_and_cancel_writes_nothing(dosbox_binary, setup_guest, language):
    run_setup_ui(dosbox_binary, setup_guest, f'/{language}',
                 ['F3', 'capture', 'Escape', 'Alt-x'], cpu='8086')
    assert not (setup_guest/'HHBIOS.BAT').exists()
    assert not (setup_guest/'213L.INI').exists()


@pytest.mark.dos
@pytest.mark.parametrize('language,home_row,preview_row',[('EN',19,21),('ZH',21,23)])
def test_setup_mouse_save_under_msdos(dosbox_binary, setup_guest, msdos_image,
                                     language, home_row, preview_row):
    image, copy_in, read = copy_disk(msdos_image, setup_guest)
    copy_in(setup_guest/'SETUP.EXE', '::HHBIOS/SETUP.EXE')
    # Keep the boot image's memory managers; run SETUP before HHBIOS.
    startup = ['@ECHO OFF', 'C:\\DOS\\VBMOUSE.EXE install low', 'CD \\HHBIOS',
               f'SETUP /{language} /IME:NONE', 'IF ERRORLEVEL 1 GOTO FAILED',
               'ECHO complete>C:\\DONE.TXT', 'GOTO END', ':FAILED',
               'ECHO failed>C:\\DONE.TXT', ':END', 'C:\\DOS\\SHUTDOWN /S']
    (setup_guest/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(startup)+'\r\n').encode())
    copy_in(setup_guest/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    # Remove prior backups only in this disposable image, so Save can succeed.
    with image.open('rb') as disk:
        disk.seek(454)
        offset = struct.unpack('<I', disk.read(4))[0]*512
    subprocess.run(['mdel', '-i', f'{image}@@{offset}',
                    '::HHBIOS/HHBIOS.BAK', '::HHBIOS/213L.BAK'], capture_output=True)
    run_setup_ui(dosbox_binary, setup_guest, '', [
        (41, home_row), 'capture', (56, preview_row),
        (41, home_row), (25, preview_row), 'capture', 'Return',
        (66, home_row),
    ], boot_image=image)
    assert read('DONE.TXT').strip() == b'complete'
    assert b'REM HHBIOS startup - generated by SETUP.EXE' in read('HHBIOS/HHBIOS.BAT')
    assert read('HHBIOS/HHBIOS.BAK')


@pytest.mark.dos
@pytest.mark.parametrize('language',['EN','ZH'])
def test_setup_selects_wide_mode_and_text_layout(dosbox_binary, setup_guest, language):
    from qa.spec.dos import ROOT
    run_setup_ui(dosbox_binary,setup_guest,
                 f'/{language} /VIDEO:1920x1080 /TEXT:80x25 /IME:NONE',[
        'Alt-v', 'Tab', 'Down', 'Down', 'capture', 'Return', 'F3', 'capture',
        'Alt-s', 'Return', 'Alt-x'],settings=(ROOT/'qa/profiles/vesa-hd.conf').read_text())
    batch = (setup_guest/'HHBIOS.BAT').read_text()
    assert '.\\VESA.COM /M:242 /R:50' in batch
