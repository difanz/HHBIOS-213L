"""Pinyin query semantics and the actual 16-bit Watcom/interrupt boundary."""
import struct

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
from unicorn import x86_const as reg

from qa.spec.build import ROOT, build_mixed

pytestmark = pytest.mark.unit


@pytest.fixture(scope='module', params=['8086', '386', '586'])
def pinyin_binary(request, assembler, source_dir, tmp_path_factory):
    output = tmp_path_factory.mktemp('pinyin') / 'pinyin.com'
    return build_mixed(ROOT/'qa/harness/pinyin.asm', output, source_dir, assembler,
                       request.param, ('pinyin',))


def prepare(binary, spelling, flags=0x602, length=None):
    symbols = dict(zip(('entry', 'length', 'input', 'query', 'abbreviated',
                        'last_key', 'display_count', 'display_keys'),
                       struct.unpack_from('<8H', binary)))
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    uc.mem_write(0x10100, binary)
    if length is None:
        length = len(spelling)
    original = spelling.ljust(10, b'\x5a')
    uc.mem_write(0x10000+symbols['input'], original)
    uc.mem_write(0x10000+symbols['query'], b'\xa5'*10)
    uc.mem_write(0x10000+symbols['length'], bytes([length]))
    initial = dict(CS=0x1000, DS=0x1000, ES=0x4000, SS=0x8000, SP=0xf000,
                   EAX=0x12345678, EBX=0x2345ab00 | length, ECX=0x3456cdef,
                   EDX=0x4567abcd, ESI=0x5678cdef, EDI=0x6789abcd,
                   EBP=0x789acdef, EFLAGS=flags)
    for name, value in initial.items():
        uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)
    uc.mem_write(0x8f000, b'\x00\xff')
    uc.emu_start(0x10000+symbols['entry'], 0x1ff00, count=10000)
    assert uc.reg_read(reg.UC_X86_REG_IP) == 0xff00
    assert uc.reg_read(reg.UC_X86_REG_SP) == 0xf002
    for name, value in initial.items():
        if name not in ('SP', 'EFLAGS'):
            mask = 0xffff0000 if name in ('EBX', 'EBP') else 0xffffffff
            assert uc.reg_read(getattr(reg, 'UC_X86_REG_'+name)) & mask == value & mask, name
    assert uc.reg_read(reg.UC_X86_REG_EFLAGS) & 0x600 == flags & 0x600
    assert bytes(uc.mem_read(0x10000+symbols['input'], 10)) == original
    assert uc.mem_read(0x10000+symbols['length'], 1) == bytes([length])
    count = uc.reg_read(reg.UC_X86_REG_BP)
    keys = struct.pack('<H', uc.reg_read(reg.UC_X86_REG_BX))[:count]
    read = lambda name, size: bytes(uc.mem_read(0x10000+symbols[name], size))
    assert read('last_key', 1) == (spelling[-1:] if 1 <= length <= 8 else b'\0')
    assert read('display_count', 2) == struct.pack('<H', int(count == 2))
    assert read('display_keys', 2) == (keys if count == 2 else b'\0\0')
    return keys, read('query', 10), read('abbreviated', 1) != b'\0'


@pytest.mark.parametrize('spelling, keys, working, abbreviated', [
    (b'a', b'a', b'a', False),
    (b'zh', b'zh', b'zh', False),
    (b'ch', b'ch', b'ch', False),
    (b'sh', b'sh', b'sh', False),
    (b'zha', b'va', b'vaa', True),
    (b'chi', b'ii', b'iii', True),
    (b'shu', b'uu', b'uuu', True),
    (b'zhong', b'vs', b'vongg', True),
    (b'chang', b'ih', b'iangg', True),
    (b'shuang', b'ux', b'uuangg', True),
    (b"shuang'", b'ux', b"uuang''", True),
    (b'ang', b'ag', b'ang', True),
    (b"ang'", b'', b"ang'", False),
    (b"an'", b'', b"an'", False),
    (b"ba'", b'ba', b"ba'", False),
    (b"bai'", b'bl', b"bai'", True),
    (b"bian'", b'bb', b"bian'", True),
    (b"niang'", b'nx', b"niang'", True),
    (b'abc', b'', b'abc', False),
    (b'zzz', b'', b'zzz', False),
    (b'zhzz', b'', b'vzzz', True),
    (b'abcdefgh', b'', b'abcdefgh', False),
    (b'zhabcdef', b'', b'vabcdeff', True),
    (b"shuang''", b'', b"uuang'''", True),
])
@pytest.mark.parametrize('flags', [2, 0x202, 0x602])
def test_query_and_phrase_spelling(pinyin_binary, spelling, keys, working, abbreviated, flags):
    assert prepare(pinyin_binary, spelling, flags) == (
        keys, working.ljust(10, b'\xa5'), abbreviated)


# Historical codebook, including abbreviated finals used by phrase input.
FINALS = dict(pair.split(':') for pair in (
    'ai:l an:j ao:k ei:d en:f on:s ou:p ia:r ie:t ih:x ij:b ik:m in:n io:s '
    'iu:q is:s ua:w ue:w uh:x ui:v uj:z ul:y un:c uo:o ve:w '
    'ang:h eng:g ong:s ian:b iao:m ing:y ion:s uai:y uan:z '
    'iang:x iong:s uang:x').split())


@pytest.mark.parametrize('final, key', FINALS.items())
@pytest.mark.parametrize('initial, query_initial', [('b', 'b'), ('zh', 'v'),
                                                   ('ch', 'i'), ('sh', 'u')])
def test_final_codebook(pinyin_binary, final, key, initial, query_initial):
    for separator in ('', "'"):
        spelling = (initial+final+separator).encode()
        keys, _, abbreviated = prepare(pinyin_binary, spelling)
        assert keys == (query_initial+key).encode()
        assert abbreviated


@pytest.mark.parametrize('length', [0, 9, 10, 255])
def test_invalid_length_leaves_resident_buffers_alone(pinyin_binary, length):
    assert prepare(pinyin_binary, b'abcdefgh', length=length) == (b'', b'\xa5'*10, False)
