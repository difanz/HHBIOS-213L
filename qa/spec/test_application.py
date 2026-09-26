"""A real third-party editor, ordinary GB2312, with no leading-space workaround."""
import shutil
import subprocess
import zipfile

import pytest

from qa.spec.dos import ROOT, digest, run_dos
from qa.spec.machine import FRAME_ALIASES
from qa.spec.test_dos_display import guest_build  # shared build fixture

pytestmark = pytest.mark.application
ARCHIVE_SHA256 = 'c72678d79a66bb2ac28f612d4c63970e58b29c26f9ef4a30d1317105306ffe9c'


def test_tvedit_real_chinese_file(pytestconfig, dosbox_binary, guest_build, tmp_path):
    archive = pytestconfig.getoption('--tvedit').resolve()
    assert archive.is_file(), 'Fetch the pinned tvedit archive using qa/README.md before selecting application tests'
    assert digest(archive) == ARCHIVE_SHA256, 'tvedit archive hash changed'
    for file in guest_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    with zipfile.ZipFile(archive) as package:
        (tmp_path / 'TVEDIT.EXE').write_bytes(package.read('tvedit.exe'))
    build = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/appcap.c',
                            str(tmp_path / 'APPCAP.COM'), 'qa/harness/appcap.asm'],
                           cwd=ROOT, capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    lines = ['HHBIOS-QA', '中文测试 Han', '喃後岐徵 VGA']
    (tmp_path / 'VIEW.TXT').write_bytes(('\r\n'.join(lines)+'\r\n').encode('gb2312'))
    files = run_dos(dosbox_binary, tmp_path, ['SNAPSHOT font', 'READ2 > READ2.LOG',
                                      'VGA > VGA.LOG', ('CMODE 3 > CMODE.LOG', 3),
                                      'APPCAP install', 'TVEDIT VIEW.TXT', 'APPCAP dump'], timeout=45)
    raw = files['APP.BIN'].read_bytes()
    assert len(raw) == 18416 and raw[:7] == b'\1HHAPP1'
    text, plane = raw[16:4016], raw[4016:]
    chars = text[::2]
    font = files['FONT.BIN'].read_bytes()
    hzk = (ROOT / 'fonts/HZK16').read_bytes()
    # Text placement comes from the editor. Find the unique complete fixture
    # line, then require exact HZK pixels for every Chinese character.
    for line in lines[1:]:
        encoded = line.encode('gb2312')
        assert chars.count(encoded) == 1
        index = chars.index(encoded)
        row, col = divmod(index, 80)
        assert row < 10 and col+len(encoded) <= 80
        for i in range(0, 8, 2):
            lead, trail = encoded[i:i+2]
            offset = ((lead-0xa1)*94+trail-0xa1)*32
            glyph = hzk[offset:offset+32]
            for half in range(2):
                cell = index+i+half
                attr = text[2*cell+1]
                fg, bg = (255 if attr & 2 else 0), (255 if attr & 32 else 0)
                expected = bytes((b & fg) | ((255 ^ b) & bg) for b in glyph[half::2]+b'\0\0')
                actual = bytes(plane[(row*18+y)*80+col+i+half] for y in range(18))
                assert actual == expected, f'tvedit glyph at {row},{col+i+half}'
    # At least two top-window corners, checked positively against the BIOS font.
    corner_codes = {code: code for code in (0xc9, 0xbb)}
    corner_codes.update({FRAME_ALIASES[code]: code for code in (0xc9, 0xbb)})
    corners = [i for i, code in enumerate(chars[:800]) if code in corner_codes]
    assert len(corners) >= 2
    for cell in corners:
        row, col = divmod(cell, 80)
        code, attr = text[2*cell:2*cell+2]
        code = corner_codes[code]
        glyph = font[code*16:(code+1)*16]
        fg, bg = (255 if attr & 2 else 0), (255 if attr & 32 else 0)
        expected = bytes((b & fg) | ((255 ^ b) & bg) for b in glyph+glyph[-2:])
        assert bytes(plane[(row*18+y)*80+col] for y in range(18)) == expected
