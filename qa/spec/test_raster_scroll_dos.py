"""Native-font scrolling under the MS-DOS kernel and memory managers."""
import os
import struct

import pytest

from qa.spec.dos import run_process
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_font20 import sized_font
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_widescreen import HD_SETTINGS
from qa.spec.test_vesa import vesa_build

pytestmark = pytest.mark.dos


@pytest.mark.parametrize('mode,width,height,plane_bytes', [
    ('102', 8, 16, 60000), ('104', 12, 29, 98304),
    ('106', 16, 39, 163840), ('242', 24, 41, 259200),
])
def test_msdos_native_font_scroll_matches_redraw(dosbox_binary, vesa_build,
                                                msdos_image, tmp_path, mode,
                                                width, height, plane_bytes):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM', 'VESATEST.COM'):
        copy_in(vesa_build / name, '::HHBIOS/' + name)
    keyboard_config(tmp_path)
    (tmp_path / 'CUSTOM.FNT').write_bytes(sized_font(width, height))
    for name in ('213L.INI', 'CUSTOM.FNT'):
        copy_in(tmp_path / name, '::HHBIOS/' + name)
    commands = [
        '@ECHO OFF', 'CD \\HHBIOS', 'READ5', 'CKBD /E',
        f'VESA /M:{mode} /F:CUSTOM.FNT > LOAD.TXT',
        'IF ERRORLEVEL 1 GOTO END', 'VESATEST scroll',
        'IF ERRORLEVEL 1 GOTO END', 'ECHO complete>C:\\RESULT.TXT',
        ':END', 'C:\\DOS\\SHUTDOWN /S',
    ]
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = ('[sdl]\noutput=surface\n[dosbox]\nmemsize=16\n'
              '[cpu]\ncore=normal\ncycles=30000\n' + HD_SETTINGS +
              '\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
              f'imgmount c "{image}" -ide 1m\nboot c:\n')
    (tmp_path / 'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')],
                tmp_path, 120, dict(os.environ, SDL_VIDEODRIVER='dummy',
                                   SDL_AUDIODRIVER='dummy'))
    assert read('RESULT.TXT').strip() == b'complete', read('HHBIOS/LOAD.TXT')
    raw = read('HHBIOS/SCROLL.BIN')
    operations = [(False, 1, 0, 24, 0, 79), (True, 3, 0, 24, 0, 79),
                  (False, 2, 3, 20, 0, 79), (True, 1, 3, 20, 0, 79),
                  (False, 1, 3, 20, 5, 74), (False, 25, 0, 24, 0, 79)]
    capture_size = 4000 + 4 * plane_bytes
    record_size = 4000 + 2 * capture_size
    assert len(raw) == len(operations) * record_size
    for step, (down, count, top, bottom, left, right) in enumerate(operations):
        record = raw[step * record_size:(step + 1) * record_size]
        before = struct.unpack_from('<2000H', record)
        expected = list(before)
        for row in range(top, bottom + 1):
            source = row - count if down else row + count
            for column in range(left, right + 1):
                expected[row * 80 + column] = (before[source * 80 + column]
                    if top <= source <= bottom else 0x1e20)
        assert struct.unpack_from('<2000H', record, 4000) == tuple(expected), step
        # The forced repaint must match every accelerated pixel, including
        # bank boundaries, margins, split attributes and the IME strip.
        assert record[4000:4000 + capture_size] == record[4000 + capture_size:], step
