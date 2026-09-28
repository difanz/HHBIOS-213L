"""Production drawing transactions retain text ownership across nested work."""
import struct

import pytest
from unicorn import UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn import x86_const as reg

from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


class TextAperture:
    """External VGA registers and BIOS bank selection, without driver stubs."""

    def __init__(self, image, rows=25):
        self.gc = [3, 1, 7, 5, 2, 16, 1, 15, 90]
        self.seq = [3, 1, 1, 0, 2]
        self.gc_index, self.seq_index = 7, 3
        self.initial = (self.gc[:], self.seq[:], self.gc_index, self.seq_index)
        self.bank = 6
        self.banks = []
        self.fail_restore = False
        self.visible = True
        self.writes = 0
        self.text = bytearray(b' \x07' * (80 * rows))
        self.text[6:10] = b'\xd6\x07\xd0\x07'
        self.pending_irq = False
        self.inject_on_port = False
        self.injected = 0
        self.machine = Driver(image, self.bios)
        machine = self.machine
        for name, value in dict(text_rows=rows, text_cells=80 * rows,
                                page_bytes=8192, text_bank=6, bank_step=1).items():
            machine.write(name, struct.pack('<H', value))
        machine.write('last_row', bytes([rows - 1]))
        machine.write('active', b'\1')
        machine.write('banked_text', b'\1')
        machine.write('text_transfer', b'\xa5' * len(self.text))
        machine.uc.mem_write(0xb8000, bytes(self.text))
        machine.uc.hook_add(UC_HOOK_INSN, self.input_port, None, 1, 0, reg.UC_X86_INS_IN)
        machine.uc.hook_add(UC_HOOK_INSN, self.output_port, None, 1, 0, reg.UC_X86_INS_OUT)
        machine.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.text_access,
                            begin=0xb8000, end=0xb8000 + len(self.text) - 1)
        machine.uc.hook_add(UC_HOOK_CODE, self.interrupt_at_boundary)
        # An IRQ saves its caller, makes the public boundary query, records
        # the answer, and returns through real interrupt frames.
        code = b'\x66\x60\x1e\x06\xb8\x10\x14\xba\x03\x00\x9c\x9a'
        code += struct.pack('<HH', machine.symbols['int10_handler'], 0x1000)
        code += b'\x2e\xa3\x80\x00\x2e\x89\x1e\x82\x00'
        code += b'\x2e\x89\x0e\x84\x00\x07\x1f\x66\x61\xcf'
        machine.uc.mem_write(0x30000, code)

    def update_mapping(self):
        visible = self.bank == 6 and (self.gc[6] & 12) in (0, 12) and self.seq[4] == 2
        if visible == self.visible:
            return
        machine = self.machine
        if self.visible:
            self.text[:] = machine.uc.mem_read(0xb8000, len(self.text))
        self.visible = visible
        machine.uc.mem_write(0xb8000, bytes(self.text) if visible else b'\xa5' * len(self.text))

    def bios(self, machine):
        assert machine.get('AX') == 0x4f05
        bank = machine.get('DX')
        self.banks.append(bank)
        if bank == 6 and self.fail_restore:
            machine.put('AX', 0x014f)
            return
        self.bank = bank
        self.update_mapping()
        machine.put('AX', 0x004f)

    def input_port(self, uc, port, size, _):
        assert size == 1
        if port == 0x3ce:
            return self.gc_index
        if port == 0x3cf:
            return self.gc[self.gc_index]
        if port == 0x3c4:
            return self.seq_index
        if port == 0x3c5:
            return self.seq[self.seq_index]
        pytest.fail(f'unexpected input port {port:04x}')

    def output_port(self, uc, port, size, value, _):
        if port == 0x3ce:
            self.gc_index = value & 255
            if size == 2:
                self.gc[self.gc_index] = value >> 8
        elif port == 0x3cf:
            self.gc[self.gc_index] = value
        elif port == 0x3c4:
            self.seq_index = value & 255
            if size == 2:
                self.seq[self.seq_index] = value >> 8
        elif port == 0x3c5:
            self.seq[self.seq_index] = value
        else:
            pytest.fail(f'unexpected output port {port:04x}')
        self.update_mapping()
        if self.inject_on_port:
            self.inject_on_port = False
            self.pending_irq = True

    def text_access(self, uc, access, address, size, value, _):
        assert self.visible, 'CPU accessed B800 while graphics owned its aperture'
        if access == UC_MEM_WRITE:
            self.writes += size

    def interrupt_at_boundary(self, uc, address, size, _):
        machine = self.machine
        if not self.pending_irq or not machine.get('EFLAGS') & 0x200:
            return
        self.pending_irq = False
        self.injected += 1
        sp = machine.get('SP') - 6
        machine.uc.mem_write(machine.get('SS') * 16 + sp, struct.pack(
            '<3H', machine.get('IP'), machine.get('CS'), machine.get('EFLAGS')))
        machine.put('SP', sp)
        machine.put('CS', 0x3000)
        machine.put('IP', 0)
        machine.put('EFLAGS', machine.get('EFLAGS') & ~0x300)

    def assert_restored(self):
        assert (self.gc, self.seq, self.gc_index, self.seq_index) == self.initial
        assert self.bank == 6 and self.visible


@pytest.mark.parametrize('phase', ['entry', 'exit'])
@pytest.mark.parametrize('rows', [25, 50])
def test_keyboard_irq_sees_complete_snapshot_during_mapping_changes(vesa_driver, phase, rows):
    aperture = TextAperture(vesa_driver, rows)
    machine = aperture.machine
    aperture.inject_on_port = phase == 'entry'
    machine.run('begin_draw')
    assert machine.get('AX') == 1
    aperture.inject_on_port = phase == 'exit'
    machine.run('end_draw', AX=0x1234, BX=0x2345, DS=0x1000, ES=0x4567)
    assert aperture.injected == 1
    result = struct.unpack('<3H', machine.uc.mem_read(0x30080, 6))
    assert result == (1, 0x4b48, 0x1000 + machine.symbols['text_transfer'] // 16)
    assert (machine.get('AX'), machine.get('BX'), machine.get('ES')) == (0x1234, 0x2345, 0x4567)
    assert machine.read('text_transfer', len(aperture.text)) == bytes(aperture.text)
    assert aperture.banks == [0, 6]
    aperture.assert_restored()


@pytest.mark.parametrize('failed_restore', [False, True])
def test_nested_refresh_defers_frame_alias_writeback_until_text_is_mapped(vesa_driver, failed_restore):
    aperture = TextAperture(vesa_driver)
    machine = aperture.machine
    original = bytearray(aperture.text)
    original[160:168] = b'\xc4\x07' * 4
    machine.uc.mem_write(0xb8000, bytes(original))
    machine.run('begin_draw')
    registers = dict(AX=0x1234, BX=0x2345, CX=0x3456, DX=0x4567,
                     SI=0x5678, DI=0x6789, BP=0x789a, ES=0x8000)
    machine.run('refresh_dirty', limit=100000000, **registers)
    assert all(machine.get(name) == value for name, value in registers.items())
    expected = bytes(original[:160] + b'\x12\x07' * 4 + original[168:])
    assert machine.read('text_transfer', len(original)) == expected
    assert aperture.banks == [0] and aperture.writes == 0
    aperture.fail_restore = failed_restore
    machine.run('end_draw', **registers)
    assert all(machine.get(name) == value for name, value in registers.items())
    assert aperture.banks == [0, 6]
    if failed_restore:
        assert machine.read('active') == b'\0'
        assert aperture.writes == 0 and aperture.text == original
    else:
        aperture.assert_restored()
        assert bytes(machine.uc.mem_read(0xb8000, len(original))) == expected
        assert aperture.writes == len(original)
    # A repeated close must neither replay a pending copy nor switch a bank.
    machine.run('end_draw')
    assert aperture.banks == [0, 6]
