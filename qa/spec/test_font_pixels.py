"""Source-pixel witnesses: do not use the generated font as its own oracle.

HEX rows below are verbatim GNU Unifont 18.0.01 bitmaps (SIL OFL 1.1,
see fonts/OFL.txt), from the source identified in fonts/HH20.json.
"""
import hashlib
import json

import pytest

from qa.spec.dos import ROOT
from qa.spec.pixels import native_rows

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('char,traditional,hex_rows', [
    ('中', False, '01000100010001003FF8210821082108210821083FF821080100010001000100'),
    ('文', False, '020001000100FFFE10101010082008200440028001000280044008203018C006'),
    ('汉', True, '0110211017FE111081F040404BF80A4813F81040E7FC20402FFE20A02110060C'),
    ('龙', True, '104008407E7E2440187EFF02007E7E40427E7E40427E7E40427E42404A42443E'),
])
def test_cjk_preserves_native_source_pixels(char, traditional, hex_rows):
    code = int.from_bytes(char.encode('gb2312'), 'big')
    left = native_rows(code, traditional=traditional)
    right = native_rows(code, 1, traditional)
    rows = [(a << 10) | b for a, b in zip(left, right)]
    assert rows[:2] == [0, 0] and rows[18:] == [0]*5
    assert all(row & 0xc0003 == 0 for row in rows)  # two empty columns each side
    actual = b''.join((row >> 2).to_bytes(2, 'big') for row in rows[2:18])
    assert actual == bytes.fromhex(hex_rows)


def test_font_provenance_matches_distributed_bitmap():
    metadata = json.loads((ROOT/'fonts/HH20.json').read_text())
    raw = (ROOT/'fonts/HH20.FNT').read_bytes()
    assert hashlib.sha256(raw).hexdigest() == metadata['sha256']
    assert metadata['payload_bytes'] == len(raw)-32
