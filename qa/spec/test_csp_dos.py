"""CSP disk merging and live edits under a booted MS-DOS kernel."""
import os
import re
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_process
from qa.spec.test_application import keyboard_config
from qa.spec.test_csp import csp_binary, dictionary, encoded, extension_bytes
from qa.spec.test_dos_display import guest_build
from qa.spec.test_msdos import copy_disk, msdos_image

pytestmark = pytest.mark.dos


@pytest.fixture(scope='module')
def csp_drive(tmp_path_factory):
    output = tmp_path_factory.mktemp('csp-drive') / 'CSPDRIVE.COM'
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/cspdrive.c', str(output)],
                    cwd=ROOT, check=True, capture_output=True)
    return output


@pytest.mark.parametrize('local', [False, True])
def test_msdos_csp_preserves_live_extensions_and_saves_basic_dictionary(
        dosbox_binary, msdos_image, guest_build, csp_binary, csp_drive, tmp_path, local):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM'):
        copy_in(guest_build / name, '::HHBIOS/' + name)
    (tmp_path / 'CSP.COM').write_bytes(csp_binary)
    copy_in(tmp_path / 'CSP.COM', '::HHBIOS/CSP.COM')
    copy_in(csp_drive, '::HHBIOS/CSPDRIVE.COM')
    keyboard_config(tmp_path)
    settings = (tmp_path / '213L.INI').read_bytes().splitlines()
    settings[28] = b'31'  # 1 KiB of mutable phrase space.
    settings[29] = b'59'  # The immutable pinyin table can use XMS.
    (tmp_path / '213L.INI').write_bytes(b'\r\n'.join(settings) + b'\r\n')
    copy_in(tmp_path / '213L.INI', '::HHBIOS/213L.INI')
    (tmp_path / 'PYMB').write_bytes(b'\xb0\xa1' * 286 + struct.pack('<6768H', *([0x8041] * 6768)))
    copy_in(tmp_path / 'PYMB', '::HHBIOS/PYMB')
    two = [('中', ['国'] * 2200), ('人', ['民'])]
    original = dictionary(two=two)
    end = struct.unpack_from('<H', original, 6)[0]
    (tmp_path / 'SPCZ.DAT').write_bytes(original[:end])
    copy_in(tmp_path / 'SPCZ.DAT', '::HHBIOS/SPCZ.DAT')
    (tmp_path / 'CSP.IN').write_bytes(encoded('中美') + b'\r\r4\r')
    copy_in(tmp_path / 'CSP.IN', '::HHBIOS/CSP.IN')
    startup = re.sub(rb'(?im)^CALL HHBIOS.BAT\s*$', b'', read('AUTOEXEC.BAT'))
    (tmp_path / 'STARTUP.BAT').write_bytes(startup)
    copy_in(tmp_path / 'STARTUP.BAT', '::STARTUP.BAT')
    commands = ['@ECHO OFF', 'CALL C:\\STARTUP.BAT', '@ECHO OFF', 'CD \\HHBIOS',
                'READ5', 'CKBD' + (' /C' if local else ''),
                'CSPDRIVE ' + ('local' if local else 'xms'),
                'IF ERRORLEVEL 1 GOTO FAILED', 'ECHO complete>C:\\DONE.TXT',
                ':FAILED', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = (ROOT / 'qa/dosbox.conf').read_text()
    config += f'\n[dosbox]\nmachine=svga_s3\n[autoexec]\nimgmount c "{image}" -ide 1m\nboot c:\n'
    (tmp_path / 'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')], tmp_path, 90,
                 dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    status = read('HHBIOS/CSPDRV.TXT').strip()
    assert status == b'0', read('HHBIOS/CSP.LOG')
    assert read('DONE.TXT').strip() == b'complete'
    before, after = read('HHBIOS/BEFORE.BIN'), read('HHBIOS/AFTER.BIN')
    assert extension_bytes(before) == extension_bytes(after) == extension_bytes(original)
    basic = struct.unpack_from('<H', before, 4)[0]
    assert before[:6] == after[:6] and before[8:basic] == after[8:basic]
    expected = dictionary(two=[*two, ('北', ['京'])], three=['中国话', '中国人'],
                          multi=['中华人民共和国', '中华人民'], extension=[], reserve=0)[:-2]
    struct.pack_into('<H', expected, 8, 0)
    assert read('HHBIOS/SPCZ.DAT') == expected
