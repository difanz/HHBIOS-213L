"""Real editors: rendered glyphs, per-key cursor/row data, and saved bytes."""
import shutil
import subprocess
import zipfile
import struct
import json

import pytest

from qa.spec.dos import ROOT, digest, run_dos
from qa.spec.machine import FRAME_ALIASES
from qa.spec.test_dos_display import guest_build  # shared build fixture

pytestmark = pytest.mark.application
ARCHIVE_SHA256 = 'c72678d79a66bb2ac28f612d4c63970e58b29c26f9ef4a30d1317105306ffe9c'


@pytest.fixture
def application_dir(guest_build, tmp_path):
    for file in guest_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    build = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/appcap.c',
                            str(tmp_path / 'APPCAP.COM'), 'qa/harness/appcap.asm'],
                           cwd=ROOT, capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    return tmp_path


def install_tvedit(pytestconfig, directory):
    archive = pytestconfig.getoption('--tvedit').resolve()
    assert archive.is_file(), 'Fetch the pinned tvedit archive using qa/README.md before selecting application tests'
    assert digest(archive) == ARCHIVE_SHA256, 'tvedit archive hash changed'
    with zipfile.ZipFile(archive) as package:
        (directory / 'TVEDIT.EXE').write_bytes(package.read('tvedit.exe'))


def keyboard_config(directory):
    # Normal display settings without optional IME table loads.
    config = [2, 1, 5, 0x39, 0, 0x1e, 0x1a, 0x4e, 0x4a, 0, 2,
              0x64, 0x68, 0x69, 0x6a, 0x6b, 0x66, 0x6d, 0x6c,
              0x71, 0x86, 0x85, 0x62, 0x70, 0x67, 0, 0,
              0x4e, 0x30, 0x4e, 0x4e, 0x4e]
    (directory / '213L.INI').write_bytes(''.join(f'{n:02X}\r\n' for n in config).encode('ascii'))


@pytest.mark.dos
def test_resident_mode_switch_preserves_typeahead(dosbox_binary, application_dir):
    directory = application_dir
    keyboard_config(directory)
    build = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/keyapi.c',
                            str(directory / 'KEYAPI.COM')], cwd=ROOT, capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    run_dos(dosbox_binary, directory, ['CKBD', 'KEYAPI queue', 'KEYAPI off',
            'KEYAPI queue', 'CKBD /E', 'KEYAPI on',
            'KEYAPI queue', 'CKBD /B', 'KEYAPI off'])


@pytest.fixture
def tvedit_dir(pytestconfig, application_dir):
    install_tvedit(pytestconfig, application_dir)
    return application_dir


def test_tvedit_real_chinese_file(dosbox_binary, tvedit_dir):
    tmp_path = tvedit_dir
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


@pytest.mark.parametrize('editor', ['tvedit', 'borland', 'msedit', 'edit2', 'tc201', 'tc30', 'pct9'])
@pytest.mark.parametrize('enabled', [False, True], ids=['byte-mode', 'hanzi-mode'])
@pytest.mark.parametrize('scenario', ['movement', 'trail-delete', 'trail-backspace'])
def test_editor_edits_saved_bytes(pytestconfig, dosbox_binary, application_dir, editor, enabled, scenario):
    exercise_editor(pytestconfig, dosbox_binary, application_dir, editor, enabled, scenario)


@pytest.mark.parametrize('editor', ['borland', 'tc30'])
@pytest.mark.parametrize('loader', ['READ4', 'READ5'])
def test_borland_dpmi_font_memory(pytestconfig, dosbox_binary, application_dir, editor, loader):
    exercise_editor(pytestconfig, dosbox_binary, application_dir, editor, True, 'movement', loader)


def exercise_editor(pytestconfig, dosbox_binary, application_dir, editor, enabled, scenario, loader=None):
    tmp_path = application_dir
    command = 'TVEDIT VIEW.TXT'
    if editor == 'tvedit':
        install_tvedit(pytestconfig, tmp_path)
    elif editor == 'borland':
        directory = pytestconfig.getoption('--borland-bin')
        if directory is None:
            pytest.skip('Borland binaries not supplied; set BORLAND_BIN or --borland-bin')
        assert directory.is_dir(), f'Borland BIN directory missing: {directory}'
        for name in ('BC.EXE', 'DPMI16BI.OVL', 'DPMILOAD.EXE', 'DPMIMEM.DLL'):
            shutil.copy2(directory / name, tmp_path / name)
        command = 'BC VIEW.TXT > EDITOR.LOG'
    elif editor in ('msedit', 'edit2'):
        option = '--qbasic' if editor == 'msedit' else '--msedit2'
        executable = pytestconfig.getoption(option)
        if executable is None:
            pytest.skip(f'MS-DOS editor not supplied; set {option}')
        name = 'QBASIC.EXE' if editor == 'msedit' else 'EDIT.COM'
        shutil.copy2(executable, tmp_path / name)
        command = 'QBASIC /EDITOR VIEW.TXT' if editor == 'msedit' else 'EDIT VIEW.TXT'
        (tmp_path / 'EXITKEYS.BIN').write_bytes(struct.pack('<3H', 0x2100, 0x48e0, 0x1c0d))
    elif editor in ('tc201', 'tc30'):
        directory = pytestconfig.getoption('--dos-apps')
        if directory is None:
            pytest.skip('DOS application fixtures not supplied; set DOS_APPS or --dos-apps')
        shutil.copy2(directory / editor / 'TC.EXE', tmp_path / 'TC.EXE')
        if editor == 'tc30':
            for name in ('DPMI16BI.OVL', 'DPMILOAD.EXE', 'DPMIMEM.DLL'):
                shutil.copy2(directory / editor / name, tmp_path / name)
        command = 'TC VIEW.TXT'
    elif editor == 'pct9':
        directory = pytestconfig.getoption('--pctools')
        if directory is None:
            pytest.skip('PC Tools not supplied; set PCTOOLS_DIR or --pctools')
        for name in ('mformat', 'mcopy', 'mtype'):
            assert shutil.which(name), f'PC Tools tests require mtools: {name}'
        for file in directory.iterdir():
            if file.is_file():
                shutil.copy2(file, tmp_path / file.name.upper())
        config = tmp_path / 'PCSHELL.CFG'
        raw = config.read_bytes()
        assert b'ActiveWindow= Tree1' in raw
        config.write_bytes(raw.replace(b'ActiveWindow= Tree1', b'ActiveWindow= List1'))
        command = 'PCSHELL D: /NF /25 /IM'
        (tmp_path / 'START.TXT').write_bytes(b"You haven't done an application search yet.")
        (tmp_path / 'STARTKEY.BIN').write_bytes(struct.pack('<5H', 0x011b, 0x2100, 0x2267, 0x1265, 0x1c0d))
        (tmp_path / 'EXITKEYS.BIN').write_bytes(struct.pack('<5H', 0x3d00, 0x2100, 0x4800, 0x1c0d, 0x1c0d))
    (tmp_path / 'application.json').write_text(json.dumps({
        'editor': editor, 'command': command,
        'files': {p.name: digest(p) for p in tmp_path.iterdir()
                  if p.suffix in ('.EXE', '.OVL', '.DLL', '.CFG', '.MND', '.MNC') or p.name == 'EDIT.COM'},
    }, indent=2)+'\n')
    original = 'HHBIOS-QA\r\n中文测试abc\r\n'.encode('gb2312')
    (tmp_path / 'VIEW.TXT').write_bytes(original)
    if editor == 'pct9':
        subprocess.run(['mformat', '-C', '-i', str(tmp_path / 'DATA.IMG'), '-f', '1440', '::'], check=True)
        subprocess.run(['mcopy', '-i', str(tmp_path / 'DATA.IMG'), str(tmp_path / 'VIEW.TXT'), '::VIEW.TXT'], check=True)
    # Down, Home, Right, Right, Left, Delete, Backspace, F2 (save).
    keys = [0x5000, 0x4700, 0x4d00, 0x4d00, 0x4b00, 0x5300, 0x0e08, 0x3c00]
    if editor == 'pct9':
        keys[:2] = [0x4700, 0x5000]  # PC Tools Home goes to the top of the view.
    if scenario != 'movement':
        # Move one ASCII column on the first line, then vertically onto a trail.
        keys = [0x4700, 0x4d00, 0x5000,
                0x5300 if scenario == 'trail-delete' else 0x0e08, 0x3c00]
    if editor in ('msedit', 'edit2'):
        keys[-1:] = [0x2100, 0x5000, 0x5000, 0x1c0d]  # File > Save
        keys = [k | 0xe0 if k in (0x5000, 0x4700, 0x4d00, 0x4b00, 0x5300) else k for k in keys]
    elif editor == 'pct9':
        keys.append(0x1c0d)  # Acknowledge "File saved successfully."
    (tmp_path / 'KEYS.BIN').write_bytes(struct.pack(f'<{len(keys)}H', *keys))
    keyboard_config(tmp_path)
    switch = '/E' if enabled else '/B'
    setup = ['imgmount d DATA.IMG -t floppy'] if editor == 'pct9' else []
    if loader is None:
        loader = 'READ5' if editor in ('pct9', 'tc201') else 'READ2'
    assert (tmp_path / (loader+'.COM')).is_file(), f'missing font reader: {loader}'
    files = run_dos(dosbox_binary, tmp_path, setup+['SNAPSHOT font', 'CKBD > CKBD.LOG',
                      f'{loader} > FONTLOAD.LOG', 'VGA > VGA.LOG', ('CMODE 3 > CMODE.LOG', 3),
                      f'CKBD {switch} > KEYMODE.LOG',
                      'APPCAP install', command, 'C:', 'APPCAP dump'], timeout=45,
                      physical_keys=True)
    log = files['KEYLOG.BIN'].read_bytes()
    assert len(log) == 164*(len(keys)+1)
    records = [(struct.unpack_from('<HH', log, i), log[i+4:i+164])
               for i in range(0, len(log), 164)]
    assert [key for (key, cursor), row in records] == [0]+keys
    if scenario == 'movement':
        initial_col = records[2][0][1] & 255
        width = 2 if enabled else 1
        assert [r[0][1] & 255 for r in records[2:8]] == [
            initial_col, initial_col+width, initial_col+2*width, initial_col+width,
            initial_col+width, initial_col]
        after_delete = '中测试abc'.encode('gb2312') if enabled else b'\xd6'+'文测试abc'.encode('gb2312')
        result = ('测试abc' if enabled else '文测试abc').encode('gb2312')
        assert after_delete in records[6][1][::2]
        assert result in records[7][1][::2]
    else:
        initial_col = records[1][0][1] & 255
        assert records[3][0][1] & 255 == initial_col+1
        result = '文测试abc'.encode('gb2312')
        if not enabled:
            result = (b'\xd6' if scenario == 'trail-delete' else b'\xd0')+result
        assert result in records[4][1][::2]
        assert records[4][0][1] & 255 == initial_col+(not enabled and scenario == 'trail-delete')
    expected = b'HHBIOS-QA\r\n'+result+b'\r\n'
    if editor in ('tc201', 'pct9'):
        expected += b'\x1a'  # These editors write the DOS text EOF marker.
    saved = files['VIEW.TXT'].read_bytes()
    if editor == 'pct9':
        saved = subprocess.run(['mtype', '-i', str(files['DATA.IMG']), '::VIEW.TXT'],
                               check=True, capture_output=True).stdout
        (tmp_path / 'SAVED.TXT').write_bytes(saved)
    assert saved == expected
