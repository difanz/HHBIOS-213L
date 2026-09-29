"""DOSSHELL selects its own VGA text modes, using real keys and mouse events."""
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, digest, run_dos
from qa.spec.pixels import native_rows
from qa.spec.test_dos_display import guest_build
from qa.spec.test_application import keyboard_config
from qa.spec.machine import FRAME_ALIASES

pytestmark = pytest.mark.application
FRAME_SIZE = 8280
MARKER = 'HHBIOS-GRID 中文测试'.encode('gb2312')
EXIT = [0x2100, 0x4800, 0x1c0d]


@pytest.fixture(scope='session')
def shellcap_build(tmp_path_factory):
    out = tmp_path_factory.mktemp('shellcap')/'SHELLCAP.COM'
    p = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/shellcap.c',
                        str(out), 'qa/harness/appcap.asm', 'qa/harness/videolog.asm'],
                       cwd=ROOT, capture_output=True, text=True)
    assert p.returncode == 0, p.stdout+p.stderr
    return out


@pytest.fixture
def shell_dir(pytestconfig, shellcap_build, tmp_path):
    source = pytestconfig.getoption('--dosshell')
    if source is None:
        pytest.skip('Supply --dosshell or DOSSHELL_DIR for the real DOS Shell tests')
    if not pytestconfig.getoption('--screenshots'):
        pytest.skip('DOSSHELL tests require --screenshots to verify physical scanout')
    for name in ('DOSSHELL.EXE', 'DOSSHELL.VID', 'DOSSHELL.INI', 'DOSSHELL.HLP'):
        path = source/name
        assert path.is_file(), path
        shutil.copy2(path, tmp_path/name)
    ini = tmp_path/'DOSSHELL.INI'
    source_ini_sha256 = digest(ini)
    raw = ini.read_bytes()
    assert raw.count(b'title = Command Prompt') == 1, 'Expected the supplied standard VGA configuration'
    ini.write_bytes(raw.replace(b'title = Command Prompt', b'title = '+MARKER))
    (tmp_path/'application.json').write_text(json.dumps(dict(
        application='MS-DOS Shell', source_ini_sha256=source_ini_sha256,
        files={p.name: digest(p) for p in tmp_path.iterdir()}), indent=2)+'\n')
    shutil.copy2(shellcap_build, tmp_path)
    return tmp_path


def exercise(binary, directory, build, display, mode, actions, clicks):
    commands = []
    if display == 'vesa':
        for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
            shutil.copy2(build/name, directory)
        for name in ('HZK16', 'HH20.FNT'):
            shutil.copy2(ROOT/'fonts'/name, directory)
        keyboard_config(directory)
        commands = ['READ5', 'CKBD /E', 'VESA']
    (directory/'ACTIONS.BIN').write_bytes(struct.pack('<'+'H'*len(actions), *actions))
    (directory/'MOUSE.JSN').write_text(json.dumps(clicks)+'\n')
    files = run_dos(binary, directory, commands+['SHELLCAP DOSSHELL.EXE /T:'+mode],
                    timeout=120, physical_keys=True, screenshots=True,
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    data = files['SHELL.BIN'].read_bytes()
    assert len(data) == actions.count(0xffff)*FRAME_SIZE
    frames = []
    for offset in range(0, len(data), FRAME_SIZE):
        raw = data[offset:offset+FRAME_SIZE]
        meta = struct.unpack_from('<12H', raw)
        bda = raw[24:280]
        cols, rows = struct.unpack_from('<H', bda, 0x4a)[0], bda[0x84]+1
        assert cols == 80 and meta[1] == cols*rows*2
        assert actions[meta[0]] == 0xffff
        frames.append(dict(meta=meta, bda=bda, rows=rows, text=raw[280:280+meta[1]]))
    after = files['AFTER.BIN'].read_bytes()
    assert len(after) == 256 and after[0x49] == 3 and after[0x84]+1 == 25
    assert struct.unpack_from('<H', after, 0x85)[0] == 16
    assert json.loads(files['PHYSICAL-KEYS.JSON'].read_text()) == actions
    return frames, files


def screen_pixels(directory, frame, rows):
    """Check the real SDL image against the distributed font, including row 49.

    Compare glyph shapes using their two observed colors, so app palette choices
    and SDL DAC quantization cannot turn an unreadable screen into a pass.
    """
    meta, text = frame['meta'], frame['text']
    assert frame['rows'] == rows
    chars = text[::2]
    assert chars.count(MARKER) == 1
    assert b'F10=Actions' in chars[-80:]
    width, height, ox, oy, scale, ch, logical_rows = (*meta[2:4], *meta[7:12])
    assert logical_rows == rows and scale == 1
    assert ox+800 <= width and oy+(rows+1)*ch <= height
    shots = json.loads((directory/'screenshots.json').read_text())
    shot = shots[meta[0]]
    assert (shot['width'], shot['height']) == (width, height)
    rgb = subprocess.check_output(['convert', str(directory/shot['file']), '-depth', '8', 'rgb:-'])
    assert len(rgb) == width*height*3

    def glyph(cell, code, half=0, expected=None):
        row, col = divmod(cell, 80)
        inset = row == rows and oy + (rows + 1) * ch + 2 <= height
        if expected is None:
            expected = native_rows(code, half)[:ch]
        ink, paper = set(), set()
        for y, bits in enumerate(expected):
            for x in range(10):
                start = ((oy+row*ch+y+inset)*width+ox+col*10+x)*3
                (ink if bits & (1 << (9-x)) else paper).add(rgb[start:start+3])
        assert len(ink) == len(paper) == 1 and ink != paper, (row, col, hex(code))

    start = chars.index(MARKER)+12
    for i in range(0, 8, 2):
        code = int.from_bytes(MARKER[12+i:14+i], 'big')
        for half in (0, 1):
            glyph(start+i+half, code, half)
    footer = chars.rindex(b'F10=Actions')
    for i, code in enumerate(b'F10=Actions'):
        glyph(footer+i, code)
    # Adjacent open-top pane rails and the first directory branch must remain
    # CP437 strokes, even though their bytes also spell valid Chinese words.
    for col in (35, 36):
        for row in (6, 7, 8):
            glyph(row*80+col, 0xb3)
    raw_codes = {alias: code for code, alias in FRAME_ALIASES.items()}
    frame_chars = bytes(raw_codes.get(code, code) for code in chars)
    branches = [cell for cell in range(len(chars)-4)
                if frame_chars[cell] in (0xc0, 0xc3) and
                frame_chars[cell+1:cell+3] == b'\xc4[']
    assert branches
    for cell in branches:
        glyph(cell, frame_chars[cell])
        glyph(cell+1, 0xc4)
    # The system IME row is separate from the application's last text row.
    for col, char in ((1, '英'), (3, '文')):
        code = int.from_bytes(char.encode('gb2312'), 'big')
        for half in (0, 1):
            glyph(rows*80+col+half, code, half)
    for col, code in enumerate(b'2.13L', 10):
        glyph(rows*80+col, code)
    # CKBD's original four-cell bitmap, written before its version string.
    logo = bytes([
        255,128,128,159,177,129,131,134,140,152,176,177,191,128,128,255,
        255,0,0,0,128,128,0,0,0,0,0,152,152,0,0,255,
        255,0,0,48,113,240,48,48,48,48,48,49,252,0,0,255,
        255,1,1,249,141,13,13,121,13,13,13,141,249,1,1,255])
    for col in range(4):
        expected = tuple(sum(((logo[col*16+y*16//20] >> (7-x*8//10)) & 1)
                             << (9-x) for x in range(10)) for y in range(20))
        glyph(rows*80+76+col, 0, expected=(expected+(0,)*3)[:ch])


@pytest.mark.parametrize('mode,rows', [('L', 25), ('H2', 50)])
def test_dosshell_directory_branches(dosbox_binary, guest_build, shell_dir, mode, rows):
    for name in ('APPS', 'DOCS', 'TOOLS'):
        (shell_dir/name).mkdir()
    (shell_dir/'APPS'/'EDITORS').mkdir()
    frames, _ = exercise(dosbox_binary, shell_dir, guest_build, 'vesa', mode,
                         [0xffff]+EXIT, [])
    chars = frames[0]['text'][::2]
    raw_codes = {alias: code for code, alias in FRAME_ALIASES.items()}
    assert bytes(raw_codes.get(code, code) for code in chars).count(b'\xc3\xc4[') >= 2
    screen_pixels(shell_dir, frames[0], rows)


@pytest.mark.parametrize('display', ['native', 'vesa'])
@pytest.mark.parametrize('mode,rows', [('L', 25), ('H1', 43), ('H2', 50)])
def test_dosshell_text_modes_and_mouse(dosbox_binary, guest_build, shell_dir, display, mode, rows):
    # A physical click must open File in the application's selected geometry.
    # These points lie inside File for both eight- and nine-dot native VGA text.
    x, y = (36, 24 if rows == 25 else 12)
    if display == 'vesa':
        x, y = (45, 34) if rows == 25 else (285, 40 if rows == 43 else 32)
    item_row = rows//2+4
    item_x, item_y = 84, item_row*(16 if rows == 25 else 8)+4
    if display == 'vesa':
        item_x = 105 if rows == 25 else 345
        item_y = item_row*23+11 if rows == 25 else (
            6+item_row*23+11 if rows == 43 else 2+item_row*20+10)
    # Select (single click, never launch) the program item below row 24 in
    # high modes. A mouse driver still clamped to 25 rows cannot pass this.
    actions = [0xffff, 0xfffe, 0xffff, 0xfffe, 0xffff, 0x011b]+EXIT
    frames, files = exercise(dosbox_binary, shell_dir, guest_build, display, mode,
                             actions, [dict(x=item_x, y=item_y), dict(x=x, y=y)])
    assert [f['rows'] for f in frames] == [rows]*3
    assert MARKER in frames[0]['text'][::2]
    if display == 'vesa':
        screen_pixels(shell_dir, frames[0], rows)
    cell = frames[0]['text'][::2].index(MARKER)
    assert cell//80 == item_row
    assert MARKER in frames[1]['text'][::2]
    assert frames[1]['text'][2*cell+1] != frames[0]['text'][2*cell+1], (
        'Click below row 24 did not select the program item')
    assert b'Exit' not in frames[0]['text'][::2]
    assert b'Exit' in frames[2]['text'][::2], 'Mouse click did not open the File menu'
    video = list(struct.iter_unpack('<4H', files['VIDEO.BIN'].read_bytes()))
    if rows > 25:
        assert any(ax == 0x1110 and bx == 0x800 and cx == 256 for ax, bx, cx, dx in video)


@pytest.mark.parametrize('display', ['native', 'vesa'])
@pytest.mark.parametrize('rows', [43, 50])
def test_dosshell_display_dialog_roundtrip(dosbox_binary, guest_build, shell_dir, display, rows):
    # Choose a different row count by mouse in DOSSHELL's own dialog, then
    # reopen it at that row count and select Low Resolution with Home/Enter.
    x, y = (300, 168 if rows == 43 else 184)
    if display == 'vesa':
        x, y = (330, 240 if rows == 43 else 264)
    actions = [0xffff, 0x1800, 0x2064, 0xffff, 0xfffe, 0x1c0d, 0xffff,
               0x1800, 0x2064, 0x4700, 0x1c0d, 0xffff]+EXIT
    frames, _ = exercise(dosbox_binary, shell_dir, guest_build, display, 'L',
                         actions, [dict(x=x, y=y)])
    assert [f['rows'] for f in frames] == [25, 25, rows, 25]
    dialog = frames[1]['text'][::2]
    assert b'Screen Display Mode' in dialog
    assert b'43 lines  High Resolution 1' in dialog
    assert b'50 lines  High Resolution 2' in dialog
    for frame in (frames[0], frames[2], frames[3]):
        assert MARKER in frame['text'][::2]
        if display == 'vesa':
            screen_pixels(shell_dir, frame, frame['rows'])
