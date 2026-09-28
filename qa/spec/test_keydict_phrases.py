"""Run CKBD phrase scans, prompts, selection and edits through real XMS reads."""
import re
import struct

import pytest

from qa.spec.build import build_mixed, source_file
from qa.spec.test_keytable import SYMBOLS, Tables, phrase_fixture

pytestmark = pytest.mark.unit

PHRASE_SYMBOLS = tuple(dict.fromkeys((*SYMBOLS,
    'S_DICT_OPEN', 'Q_HANDLE', 'Q_SEG', 'Q_BASE', 'Q_CACHE', 'Q_PAGE', 'Q_SERIAL',
    'L_A634', 'S_A694', 'S_A980', 'AF9_A', 'D_BUF', 'A_BUF', 'D_2B98',
    'D_95D5', 'D_95D6', 'D_9597', 'D_9648', 'D_2BD2', 'D_2BB9')))


@pytest.fixture(scope='module', params=['8086', '386', '586'])
def phrase_binary(assembler, source_dir, tmp_path_factory, request):
    output = tmp_path_factory.mktemp('keydict-phrases')
    source = source_file(source_dir, 'CKBD.ASM').read_bytes()
    footer = (b"DB 'HHPHRASE'\r\nDW " + ', '.join(PHRASE_SYMBOLS).encode() +
              b'\r\nSEG_TAIL ENDS')
    source, count = re.subn(rb'SEG_TAIL\s+ENDS', lambda unused: footer, source)
    assert count == 1
    path = output / 'ckbd.asm'
    path.write_bytes(source)
    binary = build_mixed(path, output / 'CKBD.COM', source_dir, assembler, request.param)
    values = struct.unpack_from('<' + 'H' * len(PHRASE_SYMBOLS), binary,
                                binary.rindex(b'HHPHRASE') + 8)
    return binary, dict(zip(PHRASE_SYMBOLS, values))


class PhraseMachine(Tables):
    def __init__(self, binary, compact, indexed=False):
        payload, dictionary, _, self.queries, self.hanzi = phrase_fixture()
        super().__init__(binary, payload)
        self.output = bytearray()
        self.selected = {}
        self.cursor = 0
        self.beeps = 0
        self.basic_end = len(dictionary)
        self.capacity = self.basic_end + 2048
        struct.pack_into('<H', dictionary, 8, self.capacity)
        self.original = bytes(dictionary)
        self.word('D_PY', self.base)
        self.word('D_SPCZ', 0x4000)
        self.uc.mem_write(0x40000, bytes(dictionary) + bytes(2050))
        if indexed:
            self.call('S_PHRASE_OPEN')
            assert self.read('P_HANDLE') != b'\0\0'
        if compact:
            old_end = 0x4000 + self.capacity // 16 + 1
            self.call('S_DICT_OPEN', BP=old_end, DS=0x7000)
            assert self.read('Q_HANDLE') != b'\0\0'
            assert self.get('BP') < old_end
            assert self.get('DS') == 0x7000
            physical_end = int.from_bytes(self.read('Q_CACHE'), 'little') + 2048
            # Released conventional bytes must not masquerade as the old file.
            self.uc.mem_write(0x40000 + physical_end,
                              b'\xa5' * (self.capacity + 2 - physical_end))
        self.moves.clear()

    def interrupt(self, uc, number, unused):
        if number != 0x10:
            return super().interrupt(uc, number, unused)
        ax = self.get('AX')
        if ax >> 8 == 2:
            self.cursor = self.get('DX')
        elif ax >> 8 == 8:
            self.put('AX', 0x0700 | self.selected[self.cursor])
        elif ax == 0x0e07:
            self.beeps += 1
        elif ax == 0x1403:
            self.output.append(self.get('DX') & 255)
        elif ax == 0x1401:
            self.output.clear()
        else:
            assert ax in (0x1401, 0x1402, 0x1405), hex(ax)

    def search(self, keys):
        self.write('D_2CC1', keys)
        self.write('D_2BB9', b'\x08')
        self.word('D_9597', 0)
        self.write('D_2BD2', b'\0')
        self.write('D_9648', bytes(44))
        self.call('S_A9000', DX=0)
        return (self.read('D_9597'), self.read('D_2BD2', 1), self.read('D_9648', 44))

    def choose(self, index=0):
        self.call('L_A634', AX=index)
        count = self.read('D_95D5', 1)[0]
        assert self.read('D_95D6', 1)[0] == count
        return self.read('D_959D', count)

    def append(self, text):
        positions = [0x0400 + i for i in range(len(text))]
        self.selected = dict(zip(positions, text))
        self.write('D_BUF', struct.pack('<' + 'H' * len(positions), *positions))
        self.word('A_BUF', self.symbols['D_BUF'] + len(text) * 2)
        self.call('AF9_A', BX=0)


def phrase_keys(machine, *indices):
    codes = struct.unpack('<6768H', machine.payload)
    return bytes(96 + (codes[index] & 31) for index in indices)


@pytest.mark.parametrize('indexed', [False, True])
def test_compact_search_prompt_and_selection_match_conventional_dictionary(phrase_binary, indexed):
    direct = PhraseMachine(phrase_binary, False)
    compact = PhraseMachine(phrase_binary, True, indexed)
    extension = direct.hanzi(313) + direct.hanzi(211)
    for machine in (direct, compact):
        machine.append(extension)
    queries = [b'zzzz', b'~~~?', *direct.queries[:4],
               phrase_keys(direct, 310, 511, 912) + b'`',
               phrase_keys(direct, 220, 520, 820, 1120)]
    for keys in queries:
        expected = direct.search(keys)
        assert compact.search(keys) == expected, keys
        for machine in (direct, compact):
            machine.output.clear()
            machine.call('S_A694')
        assert compact.output == direct.output, keys
        for index in range(expected[1][0]):
            for machine in (direct, compact):
                machine.write('D_2BB9', b'\x08')
            assert compact.choose(index) == direct.choose(index), (keys, index)
        assert compact.read('T_FAULT', 1) == b'\0'
    handle = int.from_bytes(compact.read('Q_HANDLE'), 'little')
    assert any(move[1] == handle for move in compact.moves)


def test_phrase_scan_and_selection_without_any_xms_manager(phrase_binary):
    local = PhraseMachine(phrase_binary, False)
    compact = PhraseMachine(phrase_binary, True, True)
    local.word('T_HANDLE', 0)
    local.blocks.clear()
    local.allocated = False
    local.uc.mem_write(0x10000 + local.base, local.payload)
    for keys in local.queries[:4]:
        expected = local.search(keys)
        assert compact.search(keys) == expected
        for index in range(expected[1][0]):
            for machine in (local, compact):
                machine.write('D_2BB9', b'\x08')
            assert local.choose(index) == compact.choose(index)
    assert local.moves == []
    assert local.read('T_FAULT', 1) == b'\0'


@pytest.mark.parametrize('foreign', [False, True])
@pytest.mark.parametrize('repeat', [False, True])
def test_grouped_candidate_selection_keeps_offsets_and_repeated_words(
        phrase_binary, foreign, repeat):
    machine = PhraseMachine(phrase_binary, True)
    first, ignored, second = (machine.hanzi(index) for index in (17, 23, 91))
    data = bytes(code & 127 for code in first) + ignored + second
    segment = 0x5000 if foreign else 0x4000
    offset = 4094  # the first and selected words lie on different cache pages
    if foreign:
        machine.uc.mem_write(segment * 16 + offset, data)
    else:
        handle = int.from_bytes(machine.read('Q_HANDLE'), 'little')
        machine.blocks[handle][offset:offset + len(data)] = data
    machine.word('D_2B98', segment)
    machine.write('D_2BB9', bytes([8 | (0x80 if repeat else 0)]))
    machine.write('D_9648', struct.pack('<HBB', offset, 4, 2))
    expected = first * (2 if repeat else 1) + second * (2 if repeat else 1)
    assert machine.choose() == expected
    assert machine.read('T_FAULT', 1) == b'\0'


@pytest.mark.parametrize('foreign', [False, True])
def test_contiguous_candidate_copy_preserves_exact_bytes(phrase_binary, foreign):
    machine = PhraseMachine(phrase_binary, True)
    data = b'ASCII:' + machine.hanzi(17) + machine.hanzi(91)
    offset = 2047
    segment = 0x5000 if foreign else 0x4000
    if foreign:
        machine.uc.mem_write(segment * 16 + offset, data)
    else:
        handle = int.from_bytes(machine.read('Q_HANDLE'), 'little')
        machine.blocks[handle][offset:offset + len(data)] = data
    machine.word('D_2B98', segment)
    machine.write('D_2BB9', b'\0')
    machine.write('D_9648', struct.pack('<HBB', offset, len(data), 0))
    assert machine.choose() == data
    assert machine.read('T_FAULT', 1) == b'\0'


@pytest.mark.parametrize('compact', [False, True])
def test_alt_f9_appends_at_physical_tail_but_keeps_logical_header(phrase_binary, compact):
    machine = PhraseMachine(phrase_binary, compact)
    first, second = machine.hanzi(313) + machine.hanzi(211), machine.hanzi(514) * 3
    initial_blocks = {handle: bytes(data) for handle, data in machine.blocks.items()}
    for index, text in enumerate((first, second), 1):
        machine.append(text)
        assert machine.beeps == 0
        assert int.from_bytes(machine.read('Q_SERIAL'), 'little') == index
    expected = first + b',' + second + b',\0\0'
    physical = 16 if compact else machine.basic_end
    assert bytes(machine.uc.mem_read(0x40000 + physical, len(expected))) == expected
    assert int.from_bytes(machine.uc.mem_read(0x40006, 2), 'little') == (
        machine.basic_end + len(expected) - 2)
    assert int.from_bytes(machine.uc.mem_read(0x40004, 2), 'little') == machine.basic_end
    assert initial_blocks == {handle: bytes(data) for handle, data in machine.blocks.items()}
    # A full extension must leave header, bytes and generation unchanged.
    end = int.from_bytes(machine.uc.mem_read(0x40006, 2), 'little')
    machine.uc.mem_write(0x40008, struct.pack('<H', end + len(first)))
    before = bytes(machine.uc.mem_read(0x40000, machine.capacity + 2))
    machine.append(first)
    assert machine.beeps == 1
    assert machine.read('Q_SERIAL') == b'\x02\0'
    assert bytes(machine.uc.mem_read(0x40000, machine.capacity + 2)) == before


def test_alt_f9_respects_replacement_dictionary_segment(phrase_binary):
    machine = PhraseMachine(phrase_binary, True)
    owner_before = bytes(machine.uc.mem_read(0x40000, machine.capacity + 2))
    dictionary = machine.original + bytes(2050)
    machine.uc.mem_write(0x50000, dictionary)
    machine.word('D_SPCZ', 0x5000)  # the legacy AH=20h table-replacement interface
    text = machine.hanzi(313) + machine.hanzi(211)
    machine.append(text)
    assert machine.read('Q_SEG') == b'\0\x40'
    assert machine.beeps == 0
    assert machine.read('Q_SERIAL') == b'\1\0'
    assert bytes(machine.uc.mem_read(0x40000, len(owner_before))) == owner_before
    assert bytes(machine.uc.mem_read(0x50000 + machine.basic_end, len(text) + 3)) == (
        text + b',\0\0')
    assert int.from_bytes(machine.uc.mem_read(0x50006, 2), 'little') == (
        machine.basic_end + len(text) + 1)


@pytest.mark.parametrize('operation', ['scan', 'comma', 'select', 'prompt'])
def test_dictionary_read_failure_returns_without_publishing_partial_input(
        phrase_binary, operation):
    machine = PhraseMachine(phrase_binary, True)
    machine.failure = 'move'
    machine.word('D_2B98', 0x4000)
    machine.write('D_2BB9', b'\x08')
    machine.write('D_9648', struct.pack('<HBB', 2047, 6, 0))
    if operation == 'scan':
        machine.search(b'zzzz')
    elif operation == 'comma':
        machine.call('S_A980', DS=0x4000, SI=2047)
    elif operation == 'select':
        assert machine.choose() == b''
    else:
        machine.write('D_2BD2', b'\1')
        machine.word('D_9597', 1)
        machine.call('S_A694')
        assert not machine.output
    assert machine.read('T_FAULT', 1) == b'\1'
    assert machine.read('Q_PAGE') == b'\xff\xff'
