"""Exercise the DOS UI with physical keys and inspect the saved configuration."""
import os
import json
import shutil
import struct
import subprocess
import time

import pytest

from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_setup import setup_guest
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_legacy import legacy_ini, ini_values, LEGACY_VALUES
from qa.spec.dos import ROOT
from qa.spec.pixels import native_rows


def assert_native_caption(directory, capture, text):
    """Compare visible VESA text with the distributed bitmap, including gaps."""
    pixels = subprocess.check_output(['convert', str(directory/capture['file']),
                                      '-depth', '8', 'rgb:-'])
    width = capture['width']
    mask = bytes(green > 100 for green in pixels[1::3])
    screen = [mask[start:start + width] for start in range(0, len(mask), width)]
    glyphs = []
    for character in text:
        code = int.from_bytes(character.encode('gb2312'), 'big')
        glyphs.append(tuple((left << 10) | right for left, right in
                            zip(native_rows(code), native_rows(code, 1))))
    expected = [bytes((glyph[row] >> bit) & 1
                      for glyph in glyphs for bit in range(19, -1, -1))
                for row in range(23)]
    anchor = max(range(23), key=lambda row: sum(expected[row]))
    for row in range(anchor, len(screen) - 23 + anchor + 1):
        col = screen[row].find(expected[anchor])
        while col >= 0:
            if all(screen[row - anchor + offset][col:col + len(bits)] == bits
                   for offset, bits in enumerate(expected)):
                return
            col = screen[row].find(expected[anchor], col + 1)
    pytest.fail(f'Caption missing or overwritten in {capture["file"]}: {text}')


def run_setup_ui(binary, directory, options, keys_to_press, *, cpu='386', boot_image=None,
                 settings='', startup='', finish='', machine='svga_s3'):
    with PhysicalKeyboard(directory, screenshots=True) as keyboard:
        config = ('[sdl]\noutput=surface\nshowmenu=false\nautolock=false\nmouse_emulation=locked\n'
                  '[dos]\nvmware=true\n'
                  f'[dosbox]\nmachine={machine}\n'
                  f'[cpu]\ncore=normal\ncputype={cpu}\ncycles=30000\n'
                  f'{settings}\n'
                  '[autoexec]\n'
                  f'mount c "{directory}"\nc:\n'
                  f'{startup}\n'
                  f'SETUP {options}\nif errorlevel 1 goto failed\n'
                  f'{finish}\n'
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
                    ready = blue > len(pixels)/3*.75
                    if machine == 'hercules':
                        # The monochrome backend uses a black desktop. Its
                        # bordered dialog must contain visible text before keys.
                        ready = sum(max(rgb) > 100 for rgb in zip(
                            pixels[::3], pixels[1::3], pixels[2::3])) > len(pixels)/3*.02
                    if ready:
                        keyboard.captures[-1]['before_key'] = 'home'
                        break
                    assert time.monotonic() < deadline, 'SETUP did not show its dialog'
                    time.sleep(.5)
                for key in keys_to_press:
                    if isinstance(key, (tuple, dict)):
                        if isinstance(key, tuple):
                            col, row = key
                            width = keyboard.captures[-1]['width']
                            x, y = col*width//80+width//160, row*16+8
                            click = True
                        else:
                            x, y = key['x'], key['y']
                            click = key.get('click', False)
                        assert keyboard.t.XTestFakeMotionEvent(
                            keyboard.display, -1, x, y, 0)
                        keyboard.x.XSync(keyboard.display, 0)
                        time.sleep(.25)
                        if click:
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
@pytest.mark.parametrize('machine', ['cga', 'ega', 'hercules'])
def test_setup_english_on_legacy_adapters(dosbox_binary, setup_guest, machine):
    run_setup_ui(dosbox_binary, setup_guest, '/EN', ['capture', 'Alt-x'],
                 cpu='8086', machine=machine)
    assert not (setup_guest/'HHBIOS.BAT').exists()
    assert not (setup_guest/'213L.INI').exists()


@pytest.mark.dos
@pytest.mark.parametrize('language', ['EN', 'ZH'])
def test_setup_legacy_dialog_cancel_preserves_existing_settings(dosbox_binary, setup_guest,
                                                                language):
    original = legacy_ini()
    (setup_guest/'213L.INI').write_bytes(original)
    run_setup_ui(dosbox_binary, setup_guest, f'/{language} /VIDEO:VGA', [
        'Alt-k', 'space', 'Tab', 'Down', 'capture', 'Escape',
        # Ctrl+F5 -> Alt+F1 is already assigned. The nested error dialog must
        # return to the same draft, and canceling must retain both bindings.
        'Alt-k', 'Alt-f', 'Alt-e', *(['Down'] * 4), 'Alt-o', 'capture',
        'Return', 'Escape', 'Escape',
        'Alt-d', 'space', 'capture', 'Escape',
        'Alt-a', 'Down', 'Alt-d', 'capture', 'Escape',
        'F3', 'Alt-s', 'Return', 'Alt-x',
    ], cpu='8086')
    assert (setup_guest/'213L.INI').read_bytes() == original
    assert (setup_guest/'213L.BAK').read_bytes() == original
    assert ini_values((setup_guest/'213L.INI').read_bytes()) == LEGACY_VALUES


@pytest.mark.dos
@pytest.mark.parametrize('language', ['EN', 'ZH'])
def test_setup_print_font_files_save_named_faces(dosbox_binary, setup_guest, language):
    shutil.copy2(ROOT/'build/READ24.COM', setup_guest)
    shutil.copy2(ROOT/'fonts/large/HH24.FNT', setup_guest)
    filename = [*'hh24', 'period', *'fnt']
    run_setup_ui(dosbox_binary, setup_guest, f'/{language} /VIDEO:VGA', [
        'Alt-a', 'Tab', 'Tab', 'Tab', 'space', 'Alt-f',
        *filename, 'Tab', *filename, 'capture', 'Alt-o', 'Alt-o',
        'F3', 'capture', 'Alt-s', 'Return', 'Alt-x',
    ])
    batch = (setup_guest/'HHBIOS.BAT').read_text().upper().splitlines()
    assert '.\\READ24.COM /F0:HH24.FNT /F1:HH24.FNT' in batch


@pytest.mark.dos
@pytest.mark.parametrize('language', ['EN', 'ZH'])
def test_setup_legacy_controls_save_exact_configuration(dosbox_binary, setup_guest, language):
    original = legacy_ini()
    (setup_guest/'213L.INI').write_bytes(original)
    for module in ('INT10K', 'PRNT', 'READ16'):
        shutil.copy2(ROOT/'build'/f'{module}.COM', setup_guest)
    run_setup_ui(dosbox_binary, setup_guest, f'/{language} /VIDEO:VGA', [
        'Alt-k', 'space', 'Tab', *(['Down'] * 4), 'Alt-r',
        # A Great Wall mapping plus an ordinary F1 binding are distinct codes.
        'Alt-f', 'Alt-e', *(['Up'] * 26), 'Alt-o', 'Alt-o', 'Alt-o',
        'Alt-d',
        *(['space', 'Tab'] * 11),
        'Tab', 'Down', 'Down',
        'Alt-l', 'Alt-e', *(['Up'] * 13), 'Tab', 'Down',
        'Alt-o', 'Alt-o', 'Alt-o',
        'Alt-a', 'Down', 'Tab', 'Home', *(['Down'] * 6), 'Tab', 'space',
        'capture', 'Alt-o', 'F3', 'capture', 'Alt-s', 'Return', 'Alt-x',
    ], cpu='8086')
    expected = bytearray(LEGACY_VALUES)
    expected[:4] = bytes.fromhex('89 86 A6 39')
    expected[5] = 0x21
    expected[10:18] = bytes.fromhex('01 3B F1 F2 F3 F4 F5 F6')
    expected[27:29] = b'Y9'
    saved = (setup_guest/'213L.INI').read_bytes()
    assert ini_values(saved) == expected
    expected_lines = original.splitlines(keepends=True)
    for index, value in enumerate(expected):
        if value != LEGACY_VALUES[index]:
            expected_lines[index] = f'{value:02X}'.encode() + expected_lines[index][2:]
    assert saved == b''.join(expected_lines)
    assert (setup_guest/'213L.BAK').read_bytes() == original
    batch = (setup_guest/'HHBIOS.BAT').read_text().splitlines()
    assert '.\\INT10K.COM' in batch
    assert '.\\READ16.COM' in batch
    assert '.\\PRNT.COM 5' in batch


@pytest.mark.dos
@pytest.mark.parametrize('driver,language', [('VGA', 'EN'), ('VGA', 'ZH'), ('VESA', 'ZH')])
def test_setup_resident_ui_preserves_driver_and_configuration(dosbox_binary, setup_guest,
                                                              driver, language):
    original = legacy_ini()
    (setup_guest/'213L.INI').write_bytes(original)
    run_setup_ui(dosbox_binary, setup_guest, f'/{language}', [
        'Alt-k', 'capture', 'Escape', 'Alt-d', 'capture', 'Escape',
        'Alt-a', 'capture', 'Escape', 'Alt-x'],
        startup=f'READ5\nCKBD /E\n{driver}\nSETUP /REPORT > BEFORE.TXT',
        finish='SETUP /REPORT > AFTER.TXT')
    assert (setup_guest/'213L.INI').read_bytes() == original
    assert not (setup_guest/'HHBIOS.BAT').exists()
    assert (setup_guest/'BEFORE.TXT').read_bytes() == (setup_guest/'AFTER.TXT').read_bytes()
    if driver == 'VESA' and language == 'ZH':
        captures = json.loads((setup_guest/'screenshots.json').read_text())
        keyboard = next(item for item in captures if item['before_key'] == 'dialog')
        assert_native_caption(setup_guest, keyboard, '键盘设置')
        assert_native_caption(setup_guest, keyboard, '仿长城键盘')
        assert_native_caption(setup_guest, keyboard, '双拼词组扩展区')


@pytest.mark.dos
@pytest.mark.parametrize('language,home_row,preview_row',[('EN',20,21),('ZH',22,23)])
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
