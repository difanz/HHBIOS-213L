"""The QBASIC IDE's split-window border, distinct from EDIT /EDITOR."""
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_dosshell import shellcap_build, FRAME_SIZE, EXIT
from qa.spec.pixels import native_rows
from qa.spec.machine import FRAME_ALIASES

pytestmark = pytest.mark.application


def test_qbasic_split_window_border(pytestconfig, dosbox_binary, guest_build,
                                    shellcap_build, tmp_path):
    source = pytestconfig.getoption('--qbasic')
    if source is None or not pytestconfig.getoption('--screenshots'):
        pytest.skip('Requires --qbasic and --screenshots')
    shutil.copy2(source, tmp_path/'QBASIC.EXE')
    shutil.copy2(shellcap_build, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        shutil.copy2(guest_build/name, tmp_path)
    for name in ('HZK16', 'HH20.FNT'):
        shutil.copy2(ROOT/'fonts'/name, tmp_path)
    keyboard_config(tmp_path)
    (tmp_path/'MARKER.TXT').write_bytes(b'Untitled')
    actions = [0x011b, 0xffff]+EXIT
    (tmp_path/'ACTIONS.BIN').write_bytes(struct.pack('<5H', *actions))
    files = run_dos(dosbox_binary, tmp_path,
                    ['READ5', 'CKBD /E', 'VESA', 'SHELLCAP QBASIC.EXE'],
                    physical_keys=True, screenshots=True,
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    raw = files['SHELL.BIN'].read_bytes()
    assert len(raw) == FRAME_SIZE
    assert b'Untitled' in raw[280:4280:2]
    assert json.loads(files['PHYSICAL-KEYS.JSON'].read_text()) == actions
    chars = raw[280:4280:2]
    meta = struct.unpack_from('<12H', raw)
    width, height = meta[2:4]
    ox, oy, scale, cell_height, rows = meta[7:12]
    assert (scale, rows) == (1, 25)
    shots = json.loads(files['SCREENSHOTS.JSON'].read_text())
    rgb = subprocess.check_output(['convert', str(tmp_path/shots[1]['file']),
                                   '-depth', '8', 'rgb:-'])
    assert len(rgb) == width*height*3
    # These actual IDE cells form a short cap above the scrollbar's up arrow.
    # C3 C4 is also a valid GB2312 pair; bytes alone cannot prove correct output.
    assert chars[2*80+79] == 0x18
    for col, code in enumerate((0xc3, 0xc4, 0xbf), 77):
        assert chars[80+col] in (code, FRAME_ALIASES[code])
        ink, paper = set(), set()
        for y, bits in enumerate(native_rows(code)[:cell_height]):
            for x in range(10):
                offset = ((oy+cell_height+y)*width+ox+col*10+x)*3
                (ink if bits & (1 << (9-x)) else paper).add(rgb[offset:offset+3])
        assert len(ink) == len(paper) == 1 and ink != paper, (col, hex(code))
