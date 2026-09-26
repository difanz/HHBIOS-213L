"""Execute VGA's real INT 10h entry against controlled VBE BIOS responses."""
import os
import re
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

pytestmark = pytest.mark.unit
NAMES = ('INT_10', 'D_INT10', 'D_INT16', 'K_INT8', 'D_VBEBUSY', 'QA_BIOS', 'QA_ENTRY')


@pytest.fixture(scope='session')
def vbe_driver(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('vbe-api')
    source = (source_dir / 'VGA.ASM').read_bytes()
    # A nested query models a BIOS re-entering INT 10h during its mode set.
    footer = b'''QA_BIOS:
        CMP AX,4F02H
        JNZ QA_RET
        PUSH AX
        MOV AX,4F01H
        PUSHF
        CALL DWORD PTR CS:QA_ENTRY
        POP AX
QA_RET: INT 0F1H
        IRET
QA_ENTRY DW INT_10,0
        DB 'HHVBE1'
        DW ''' + ','.join(NAMES).encode() + b'\nSEG_A ENDS'
    source, n = re.subn(rb'SEG_A\s+ENDS', lambda _: footer, source)
    assert n == 1
    path = out / 'vga.asm'
    path.write_bytes(source)
    p = subprocess.run([assembler, '-q', '-Zm', '-0', '-bin', '-I'+str(source_dir),
                        '-Fo'+str(out / 'vga.com'), str(path)], capture_output=True,
                       env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    assert p.returncode == 0, p.stdout+p.stderr
    raw = (out / 'vga.com').read_bytes()
    return raw, dict(zip(NAMES, struct.unpack_from('<7H', raw, raw.rindex(b'HHVBE1')+6)))


def run_entry(binary, function, status, active):
    raw, symbols = binary
    uc = Uc(UC_ARCH_X86, UC_MODE_16)
    uc.mem_map(0, 0x100000)
    code, keyboard, stack = 0x10000, 0x20000, 0x80000
    uc.mem_write(code+0x100, raw)
    uc.mem_write(code+0x100, bytes([active]))
    uc.mem_write(keyboard+0x100, bytes([0x12, 0x12, active]))
    timer = 0x75 if active else 0xeb
    uc.mem_write(code+symbols['K_INT8'], bytes([timer]))
    uc.mem_write(code+symbols['D_INT16'], struct.pack('<H', keyboard//16))
    uc.mem_write(code+symbols['D_INT10'], struct.pack('<HH', symbols['QA_BIOS'], code//16))
    uc.mem_write(code+symbols['QA_ENTRY']+2, struct.pack('<H', code//16))
    initial = dict(AX=function, BX=0x8101, CX=0x5678, DX=0x9abc, SI=0x6789,
                   DI=0x789a, BP=0xabcd, DS=0x3000, ES=0x4000)
    calls = []

    def put(name, value):
        uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)

    def get(name):
        return uc.reg_read(getattr(reg, 'UC_X86_REG_'+name))

    def bios(uc, number, _):
        assert number == 0xf1
        ax = get('AX')
        calls.append(ax)
        # Every input, including mode flags and the ES:DI buffer, reaches BIOS.
        for name, value in initial.items():
            if name != 'AX':
                assert get(name) == value, name
        if function == 0x4f02:
            assert uc.mem_read(code+symbols['K_INT8'], 1) == b'\xeb'
            assert uc.mem_read(code+symbols['D_VBEBUSY'], 1) == b'\x01'
        put('AX', status if ax == function else 0x004f)

    uc.hook_add(UC_HOOK_INTR, bios)
    for name, value in dict(initial, CS=code//16, SS=stack//16, SP=0xff00, EFLAGS=0x202).items():
        put(name, value)
    uc.mem_write(stack+0xff00, struct.pack('<HHH', 0xff00, code//16, 0x202))
    uc.emu_start(code+symbols['INT_10'], code+0xff00, count=10000)
    assert get('IP') == 0xff00 and get('SP') == 0xff06
    assert get('EFLAGS') & 0x200
    assert get('AX') == status
    for name, value in initial.items():
        if name != 'AX':
            assert get(name) == value, name
    suspended = function == 0x4f02 and status == 0x004f
    assert uc.mem_read(code+symbols['K_INT8'], 1) == bytes([0xeb if suspended else timer])
    assert uc.mem_read(code+0x100, 1) == bytes([0 if suspended else active])
    assert uc.mem_read(keyboard+0x101, 2) == bytes([0xff if suspended else 0x12, active])
    assert uc.mem_read(code+symbols['D_VBEBUSY'], 1) == b'\0'
    assert calls == ([0x4f01, 0x4f02] if function == 0x4f02 else [function])


@pytest.mark.parametrize('active', [0, 1])
@pytest.mark.parametrize('status', [0x004f, 0x014f, 0x024f, 0x034f, 0x4f02])
def test_vbe_mode_result_and_recursion(vbe_driver, status, active):
    run_entry(vbe_driver, 0x4f02, status, active)


@pytest.mark.parametrize('function', [0x4f00, 0x4f01, 0x4f03, 0x4f04, 0x4f05, 0x4fff])
def test_vbe_other_calls_do_not_suspend(vbe_driver, function):
    run_entry(vbe_driver, function, 0x004f, 1)
