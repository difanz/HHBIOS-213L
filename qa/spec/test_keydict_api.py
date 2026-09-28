"""The public CSP interface executed through CKBD's real interrupt entry."""
import struct

import pytest

from qa.spec.test_keytable import Tables, table_binary, phrase_fixture

pytestmark = pytest.mark.unit


class DictionaryApi(Tables):
    def __init__(self, binary, cached):
        payload, dictionary, _, _, _ = phrase_fixture()
        super().__init__(binary, payload)
        self.base = len(dictionary)
        extension = '中文'.encode('gb2312') + b','
        dictionary += extension
        self.used = len(dictionary)
        self.capacity = self.used + 1024
        struct.pack_into('<HH', dictionary, 6, self.used, self.capacity)
        self.original = bytes(dictionary) + b'\0\0'
        self.word('D_SPCZ', 0x4000)
        self.uc.mem_write(0x40000, self.original)
        self.write('T_LOCAL', bytes([not cached]))
        self.call('S_DICT_OPEN', BP=0x4000 + (self.capacity + 15)//16 + 1)
        assert bool(int.from_bytes(self.read('Q_HANDLE'), 'little')) == cached

    def api(self, operation, **registers):
        inputs = dict(CS=0x1000, DS=0x7000, ES=0x5000, SS=0x8000, SP=0xf000,
                      AX=0x2e00+operation, BX=0x4b48, CX=self.capacity+2,
                      DX=0x5678, DI=0x100, SI=0x789a, BP=0x89ab, EFLAGS=0x602)
        inputs.update(registers)
        for name, value in inputs.items():
            self.put(name, value)
        self.uc.mem_write(inputs['SS']*16+inputs['SP'],
                          struct.pack('<HHH', 0xff00, 0x1000, inputs['EFLAGS']))
        self.uc.emu_start(0x10000+self.symbols['INT_16'], 0x1ff00, count=5000000)
        assert self.get('IP') == 0xff00 and self.get('SP') == inputs['SP']+6
        changed = {'AX', 'SP'}
        if self.get('AX') == 0x4b48:
            changed.add('DX')
            if operation == 0:
                changed.add('CX')
        for name, value in inputs.items():
            if name not in changed:
                assert self.get(name) == value, name
        return self.get('AX')

    def snapshot(self):
        assert self.api(1) == 0x4b48
        return bytes(self.uc.mem_read(0x50100, self.capacity+2)), self.get('DX')


@pytest.mark.parametrize('cached', [False, True])
def test_snapshot_and_update_preserve_format_and_live_extension(table_binary, cached):
    machine = DictionaryApi(table_binary, cached)
    assert machine.api(0) == 0x4b48
    assert (machine.get('CX'), machine.get('DX')) == (machine.capacity+2, machine.base)
    data, serial = machine.snapshot()
    assert data == machine.original.ljust(machine.capacity+2, b'\0')
    replacement = '新词'.encode('gb2312') + b','
    for extension in (replacement, b'', replacement*2):
        image = bytearray(data)
        end = machine.base + len(extension)
        struct.pack_into('<H', image, 6, end)
        image[machine.base:end+2] = extension+b'\0\0'
        machine.uc.mem_write(0x50100, bytes(image))
        assert machine.api(2, DX=serial) == 0x4b48
        serial += 1
        assert machine.get('DX') == serial
        data, token = machine.snapshot()
        assert token == serial
        assert data[machine.base:end+2] == extension+b'\0\0'
        assert data[16:machine.base] == machine.original[16:machine.base]
        assert machine.read('D_INKEY', 1) == machine.read('D_PUMP', 1) == b'\0'


@pytest.mark.parametrize('cached', [False, True])
@pytest.mark.parametrize('bad', ['generation', 'header', 'used', 'terminator',
                                'odd_phrase', 'short_buffer', 'wrap_buffer', 'busy'])
def test_failed_updates_leave_dictionary_and_generation_unchanged(table_binary, cached, bad):
    machine = DictionaryApi(table_binary, cached)
    before, serial = machine.snapshot()
    image = bytearray(before)
    arguments = dict(DX=serial)
    if bad == 'generation':
        arguments['DX'] += 1
    elif bad == 'header':
        image[0] ^= 2
    elif bad == 'used':
        struct.pack_into('<H', image, 6, machine.capacity+1)
    elif bad == 'terminator':
        image[machine.used] = 1
    elif bad == 'odd_phrase':
        image[machine.base+3] = ord(',')
    elif bad == 'short_buffer':
        arguments['CX'] = machine.capacity+1
    elif bad == 'wrap_buffer':
        arguments['DI'] = 65535-machine.capacity
    else:
        machine.write('D_INKEY', b'\1')
    machine.uc.mem_write(0x50100, bytes(image))
    assert machine.api(2, **arguments) == 0
    if bad == 'busy':
        assert machine.read('D_INKEY', 1) == b'\1'
        machine.write('D_INKEY', b'\0')
    assert machine.snapshot() == (before, serial)


def test_failed_snapshot_does_not_publish_partial_dictionary(table_binary):
    machine = DictionaryApi(table_binary, True)
    machine.failure = 'move'
    assert machine.api(1) == 0
    assert machine.read('D_INKEY', 1) == machine.read('D_PUMP', 1) == b'\0'
    machine.failure = None
    data, serial = machine.snapshot()
    assert data == machine.original.ljust(machine.capacity+2, b'\0') and serial == 0


def test_replacing_dictionary_invalidates_snapshot_without_retargeting_cache(table_binary):
    machine = DictionaryApi(table_binary, True)
    _, serial = machine.snapshot()
    replacement = bytearray(machine.original)
    replacement[32] ^= 1  # Same format and size, different immutable contents.
    machine.uc.mem_write(0x60000, bytes(replacement))
    machine.api(0, AX=0x2003, BP=0x6000, CX=0, DX=0)
    after, generation = machine.snapshot()
    assert generation == serial+1
    assert after == bytes(replacement).ljust(machine.capacity+2, b'\0')
    assert machine.api(2, DX=serial) == 0
