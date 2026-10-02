"""Real-mode VBE bank-window scroll. Bytes and switch counts, not milliseconds."""
import shutil
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos

pytestmark = pytest.mark.dos

SETTINGS = """
[dosbox]
machine=svga_s3
[cpu]
core=normal
cycles=30000
[video]
vmemsize=8
allow high definition vesa modes=true
allow unusual vesa modes=true
vesa modelist width limit=0
vesa modelist height limit=0
"""


def _sample(text, mode, name):
    header = f'BENCH mode={mode:04X} method=far'
    start = text.index(header)
    line = next(ln for ln in text[start:].splitlines() if ln.startswith(name + ' '))
    fields = dict(part.split('=', 1) for part in line.split() if '=' in part)
    return {key: int(value) for key, value in fields.items()}


def test_bank_window_scroll_switches(assembler, dosbox_binary, tmp_path):
    com = tmp_path / 'BANKWIN.COM'
    built = subprocess.run(
        [assembler, '-q', '-3', '-bin', f'-Fo{com}', str(ROOT / 'qa/harness/bankwin.asm')],
        capture_output=True)
    blob = com.read_bytes() if com.is_file() else b''
    assert built.returncode == 0 and b'SCROLL1' in blob, built.stderr.decode('latin1', 'replace')
    shutil.copy(ROOT / 'fonts/HH20.FNT', tmp_path / 'HH20.FNT')
    files = run_dos(dosbox_binary, tmp_path, ['BANKWIN S'], timeout=90, settings=SETTINGS)
    text = files['BENCH.TXT'].read_text()
    assert 'STATUS=ok' in text
    assert 'PROBE mode=0114 far=1' in text
    assert 'FAIL=1' not in text
    # Pitch 1600 is one contiguous span. Pitch 2048 copies each 1600-byte row.
    span = _sample(text, 0x114, 'SCROLL1')
    rows = _sample(text, 0x117, 'SCROLL1')
    assert span['bytes'] == 920000 and rows['bytes'] == 920000
    assert span['switches'] == 251 and rows['switches'] == 800
    assert span['switches'] < rows['switches']
