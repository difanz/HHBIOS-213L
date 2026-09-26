"""Execute the linked production 8086 C/ASM driver across its IRQ boundary."""
import ctypes
import os
import re
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn import x86_const as reg

from qa.spec.dos import ROOT

pytestmark = pytest.mark.unit


@pytest.fixture(scope='session')
def vesa_driver(assembler, source_dir, tmp_path_factory):
    out=tmp_path_factory.mktemp('vesa-api')/'VESA.COM'
    p=subprocess.run(['bash','tools/build-vesa.sh',str(out),str(source_dir)],
                     cwd=ROOT, env=dict(os.environ,JWASM=assembler),capture_output=True,text=True)
    assert p.returncode==0, p.stdout+p.stderr
    symbols={name: int(segment,16)*16+int(offset,16)
             for segment,offset,name in re.findall(r'^([0-9a-f]{4}):([0-9a-f]{4})[ +*]*\s+_(\w+)$',
                                                   out.with_suffix('.map').read_text(),re.M)}
    return out.read_bytes(),symbols


@pytest.mark.parametrize('status',[0x004f,0x014f,0x024f,0x034f,0x4f02])
@pytest.mark.parametrize('active',[0,1])
def test_vesa_interrupt_context_and_failed_modes(vesa_driver,status,active):
    raw,s=vesa_driver
    uc=Uc(UC_ARCH_X86,UC_MODE_16); uc.mem_map(0,0x100000)
    base=0x10000
    uc.mem_write(base+0x100,raw)
    uc.mem_write(base+s['resident_segment'],struct.pack('<H',base//16))
    uc.mem_write(base+s['keyboard_segment'],struct.pack('<H',0x2000))
    uc.mem_write(base+s['active'],bytes([active]))
    uc.mem_write(base+s['old10'],struct.pack('<HH',0xf000,base//16))
    # The original BIOS makes a nested query through the real driver entry.
    nested=b'\x3d\x02\x4f\x75\x0b\x50\xb8\x01\x4f\x9c\x9a'+struct.pack('<HH',s['int10_handler'],base//16)+b'\x58\xcd\xf1\xcf'
    uc.mem_write(base+0xf000,nested)
    initial=dict(AX=0x4f02,BX=0x8101,CX=0x4567,DX=0x6789,SI=0x789a,DI=0x9abc,BP=0xabcd,DS=0x3000,ES=0x4000)
    calls=[]
    def get(n): return uc.reg_read(getattr(reg,'UC_X86_REG_'+n))
    def put(n,v): uc.reg_write(getattr(reg,'UC_X86_REG_'+n),v)
    def bios(uc,number,_):
        assert number==0xf1
        function=get('AX'); calls.append(function)
        assert get('SS')==base//16, 'BIOS must run on resident stack'
        for name,value in initial.items():
            if name!='AX': assert get(name)==value,name
        assert uc.mem_read(base+s['busy'],1)==b'\1'
        put('AX',status if function==0x4f02 else 0x004f)
    uc.hook_add(UC_HOOK_INTR,bios)
    for name,value in dict(initial,CS=base//16,SS=0x8000,SP=0xff00,EFLAGS=0x602).items(): put(name,value)
    uc.mem_write(0x8ff00,struct.pack('<HHH',0xff00,base//16,0x602))
    uc.emu_start(base+s['int10_handler'],base+0xff00,count=100000)
    assert get('IP')==0xff00 and get('SP')==0xff06 and get('SS')==0x8000
    assert get('AX')==status
    assert get('EFLAGS') & 0x600 == 0x600
    for name,value in initial.items():
        if name!='AX': assert get(name)==value,name
    assert uc.mem_read(base+s['active'],1)==bytes([0 if status==0x004f else active])
    assert uc.mem_read(base+s['busy'],1)==b'\0'
    assert uc.mem_read(base+s['stack_bottom'],2)==b'\x5a\xa5'
    assert calls==[0x4f01,0x4f02]


class Surface(ctypes.Structure):
    _pack_=1
    _fields_=[(n,ctypes.c_uint16) for n in ('width','height','pitch','segment','window_kb','granularity_kb','mode')]+[
        (n,ctypes.c_uint8) for n in ('window','format','bpp','planes','red_size','red_pos','green_size','green_pos','blue_size','blue_pos')]+[('physical',ctypes.c_uint32)]


@pytest.fixture(scope='session')
def layout_library(source_dir,tmp_path_factory):
    out=tmp_path_factory.mktemp('vesa-layout')/'layout.so'
    p=subprocess.run(['cc','-shared','-fPIC','-Wall','-Wextra','-Werror','-DVESA_HOST',str(source_dir/'vesa.c'),'-o',str(out)],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    lib=ctypes.CDLL(str(out))
    for fn in (lib.vesa_console_layout,lib.vesa_layout):
        fn.argtypes=[ctypes.POINTER(Surface),ctypes.c_void_p,ctypes.c_uint16,ctypes.c_uint16]
        fn.restype=ctypes.c_int
    return lib


@pytest.fixture
def layout(layout_library):
    return layout_library.vesa_console_layout


@pytest.mark.parametrize('version,attributes',[(0x100,0x1b),(0x101,0x1b),(0x102,0x19),(0x200,0x19),(0x300,0x19)])
@pytest.mark.parametrize('window',[0,1])
def test_vesa_layout_uses_advertised_window(layout,version,attributes,window):
    info=bytearray(256)
    struct.pack_into('<H',info,0,attributes); info[2+window]=7
    struct.pack_into('<HH',info,4,16,64)
    struct.pack_into('<H',info,8+window*2,0xa000)
    struct.pack_into('<HHH',info,16,100,800,600)
    info[24:28]=bytes([4,4,1,3])
    s=Surface(); buf=ctypes.create_string_buffer(bytes(info))
    assert layout(ctypes.byref(s),buf,version,0x321)==1
    assert (s.width,s.height,s.pitch,s.window,s.granularity_kb,s.mode,s.format)==(800,600,100,window,16,0x321,3)


@pytest.mark.parametrize('offset,value',[(0,0x1a),(0,0x3b),(0,0x5b),(2,1),(4,0),(6,32),(9,0xb0),(16,80),(18,0),(20,0),(24,1),(25,8),(27,6)])
def test_vesa_rejects_incompatible_layout_without_partial_output(layout,offset,value):
    info=bytearray(256)
    struct.pack_into('<HBBHHHHIHHHHBBBB',info,0,0x1b,7,0,64,64,0xa000,0,0,100,800,600,0x1008,4,4,1,3)
    info[offset]=value
    s=Surface(); ctypes.memset(ctypes.byref(s),0xa5,ctypes.sizeof(s))
    before=bytes(s)
    assert layout(ctypes.byref(s),ctypes.create_string_buffer(bytes(info)),0x102,0x102)==0
    assert bytes(s)==before


@pytest.mark.parametrize('width,height,bpp,model,pitch,masks',[
    (640,480,4,3,80,()),(1024,768,4,3,128,()),(1280,1024,8,4,1280,()),
    (800,600,15,6,1600,(5,10,5,5,5,0)),
    (1024,768,16,6,2112,(5,11,6,5,5,0)),
    (800,600,24,6,2400,(8,16,8,8,8,0)),
    (1280,1024,32,6,5120,(8,0,8,8,8,16)),
])
def test_geometry_and_pixel_format_are_decoded_independently_of_console(layout_library,width,height,bpp,model,pitch,masks):
    info=bytearray(256)
    struct.pack_into('<HBBHHHHIHHHHBBBB',info,0,0x9b,7,0,16,64,0xa000,0,0,pitch,width,height,0x1008,4 if model==3 else 1,bpp,1,model)
    if masks: info[31:37]=bytes(masks)
    struct.pack_into('<I',info,40,0xe0000000)
    s=Surface(); buf=ctypes.create_string_buffer(bytes(info))
    assert layout_library.vesa_layout(ctypes.byref(s),buf,0x200,0x321)==1
    assert (s.width,s.height,s.pitch,s.bpp,s.format,s.physical)==(width,height,pitch,bpp,model,0xe0000000)
    if masks: assert (s.red_size,s.red_pos,s.green_size,s.green_pos,s.blue_size,s.blue_pos)==masks
    # Describing a format must not select a renderer that cannot draw it.
    assert layout_library.vesa_console_layout(ctypes.byref(s),buf,0x200,0x321)==0


@pytest.mark.parametrize('failure',[None,'old-dos',0x5800,0x5802,'link','strategy',0x48])
@pytest.mark.parametrize('initial',[(0,0),(2,1)])
def test_vesa_umb_allocator_restores_dos_state(vesa_driver,failure,initial):
    raw,s=vesa_driver
    uc=Uc(UC_ARCH_X86,UC_MODE_16); uc.mem_map(0,0x100000)
    base=0x10000; uc.mem_write(base+0x100,raw)
    uc.mem_write(base+s['resident_paragraphs'],struct.pack('<H',0x400))
    state=dict(strategy=initial[0],linked=initial[1],allocations=0)
    def get(n): return uc.reg_read(getattr(reg,'UC_X86_REG_'+n))
    def put(n,v): uc.reg_write(getattr(reg,'UC_X86_REG_'+n),v)
    def dos(uc,number,_):
        assert number==0x21
        ax,bx=get('AX'),get('BX'); put('EFLAGS',get('EFLAGS') & ~1)
        failed=failure==ax or (failure==0x48 and ax >> 8==0x48) or (failure=='link' and ax==0x5803 and bx==1) or (failure=='strategy' and ax==0x5801 and bx==0x41)
        if failed: put('AX',8); put('EFLAGS',get('EFLAGS') | 1)
        elif ax==0x3000: put('AX',3 if failure=='old-dos' else 5)
        elif ax==0x5800: put('AX',state['strategy'])
        elif ax==0x5802: put('AX',state['linked'])
        elif ax==0x5803: state['linked']=bx
        elif ax==0x5801: state['strategy']=bx
        elif ax >> 8==0x48:
            assert (state['strategy'],state['linked'],bx)==(0x41,1,0x400)
            state['allocations']+=1; put('AX',0xd001)
        else: pytest.fail(f'unexpected DOS service {ax:04x}')
    uc.hook_add(UC_HOOK_INTR,dos)
    for n,v in dict(CS=base//16,DS=base//16,ES=0x4321,SS=0x8000,SP=0xff00,EFLAGS=0x202).items(): put(n,v)
    uc.mem_write(0x8ff00,struct.pack('<H',0xff00))
    uc.emu_start(base+s['S_UMB'],base+0xff00,count=1000)
    assert get('IP')==0xff00 and get('SP')==0xff02 and get('ES')==0x4321
    assert (state['strategy'],state['linked'])==initial
    assert state['allocations']==(failure is None)
    if failure is None: assert uc.mem_read(0xd0001,2)==b'\1\xd0'


class Driver:
    """Linked production code; only the external BIOS is substituted."""
    def __init__(self, image, bios):
        raw,self.symbols=image
        self.uc=Uc(UC_ARCH_X86,UC_MODE_16); self.uc.mem_map(0,0x100000)
        self.uc.mem_write(0x10100,raw)
        self.write('resident_segment',struct.pack('<H',0x1000))
        self.write('old10',struct.pack('<HH',0xf000,0x1000))
        self.uc.mem_write(0x1f000,b'\xcd\xf1\xcf')
        def interrupt(uc,number,_):
            assert number==0xf1, f'unexpected interrupt {number:02x}'
            bios(self)
        self.uc.hook_add(UC_HOOK_INTR,interrupt)

    def get(self,name): return self.uc.reg_read(getattr(reg,'UC_X86_REG_'+name))
    def put(self,name,value): self.uc.reg_write(getattr(reg,'UC_X86_REG_'+name),value)
    def write(self,name,value): self.uc.mem_write(0x10000+self.symbols[name],value)
    def read(self,name,n=1): return bytes(self.uc.mem_read(0x10000+self.symbols[name],n))

    def run(self,entry='int10_handler',limit=300000,**registers):
        near=entry!='int10_handler'
        for name,value in dict(CS=0x1000,DS=0x1000,SS=0x1000 if near else 0x8000,
                               SP=0xe000,EFLAGS=0x202,**registers).items(): self.put(name,value)
        address=(self.get('SS')<<4)+self.get('SP')
        frame=struct.pack('<H',0xff00) if near else struct.pack('<HHH',0xff00,0x1000,0x202)
        self.uc.mem_write(address,frame)
        self.uc.emu_start(0x10000+self.symbols[entry],0x1ff00,count=limit)
        assert self.get('IP')==0xff00
        assert self.get('SP')==0xe000+len(frame)
        assert self.read('stack_bottom',2)==b'\x5a\xa5'


@pytest.mark.parametrize('failed_bank',[0,1])
def test_bank_failure_stops_access_and_disables_renderer(vesa_driver,failed_bank):
    calls=[]
    def bios(m):
        assert m.get('AX')==0x4f05
        bank=m.get('DX'); calls.append(bank)
        m.put('AX',0x014f if bank==failed_bank else 0x004f)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1')
    m.write('text_bank',b'\1\0'); m.write('keyboard_segment',b'\0\x20')
    m.uc.mem_write(0x30000,b'\xa5'*16)
    accesses=[]
    m.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE,
                  lambda uc,access,address,size,value,_: accesses.append(address),
                  begin=0xa0000,end=0xbffff)
    m.run(AX=0x1412,BX=0,SI=0,CX=16,ES=0x3000,DI=0)
    assert m.get('AX')==1 and m.read('active')==b'\0'
    assert m.uc.mem_read(0x20101,1)==b'\xff'
    assert calls==([0] if failed_bank==0 else [0,1])
    if failed_bank==0:
        assert accesses==[] and m.uc.mem_read(0x30000,16)==b'\xa5'*16


def test_capture_during_render_requests_retry_without_touching_stack(vesa_driver):
    m=Driver(vesa_driver,lambda m: pytest.fail('must not enter BIOS'))
    m.write('busy',b'\1')
    before=m.uc.mem_read(0x10000+m.symbols['stack_bottom'],2050)
    m.run(AX=0x1412,BX=3,ES=0x3000,DI=0)
    assert m.get('AX')==2 and m.get('BX')==3
    assert m.uc.mem_read(0x10000+m.symbols['stack_bottom'],2050)==before


@pytest.mark.parametrize('previous',[3,0x101])
def test_initialization_bank_failure_restores_previous_mode(vesa_driver,previous):
    modes=[]
    def bios(m):
        ax=m.get('AX'); address=m.get('ES')*16+m.get('DI')
        m.put('AX',0x004f)
        if ax==0x4f00:
            info=bytearray(256); info[:4]=b'VESA'; struct.pack_into('<H',info,4,0x200)
            m.uc.mem_write(address,bytes(info))
        elif ax==0x4f01:
            info=bytearray(256)
            struct.pack_into('<HBBHHHHIHHHHBBBB',info,0,0x1b,7,0,64,64,0xa000,0,0,100,800,600,0x1008,4,4,1,3)
            info[29]=1; m.uc.mem_write(address,bytes(info))
        elif ax==0x1130: m.put('ES',0xc000); m.put('BP',0x100)
        elif ax==0x0f00: m.put('AX',0x5003)
        elif ax==0x4f03: m.put('BX',previous)
        elif ax==0x4f02: modes.append(m.get('BX'))
        elif ax==3: modes.append(3)
        elif ax==0x4f05: m.put('AX',0x014f)
        else: pytest.fail(f'unexpected BIOS call {ax:04x}')
    m=Driver(vesa_driver,bios)
    m.run('initialize')
    assert m.get('AX')==3 and modes==[0x102,previous]
    assert m.read('active')==b'\0'


@pytest.mark.parametrize('action',[0,1,2])
@pytest.mark.parametrize('status',[0x014f,0x024f,0x034f])
def test_state_size_failure_is_forwarded_without_buffer_access(vesa_driver,action,status):
    calls=[]
    def bios(m):
        calls.append((m.get('AX'),m.get('DX'))); m.put('AX',status)
    m=Driver(vesa_driver,bios); m.write('active',b'\1')
    m.uc.mem_write(0x30000,b'\xa5'*256)
    m.run(AX=0x4f04,BX=16,CX=7,DX=action,ES=0x3000)
    assert m.get('AX')==status and calls==[(0x4f04,0)]
    assert m.read('active')==b'\1' and m.uc.mem_read(0x30000,256)==b'\xa5'*256


@pytest.mark.parametrize('blocks,offset',[(1023,0),(1024,0),(1,0xff81),(1000,4096)])
def test_state_buffer_overflow_is_rejected_before_bios_save(vesa_driver,blocks,offset):
    calls=[]
    def bios(m):
        calls.append(m.get('DX')); m.put('AX',0x004f); m.put('BX',blocks)
    m=Driver(vesa_driver,bios)
    m.run(AX=0x4f04,BX=offset,CX=7,DX=1,ES=0x3000)
    assert m.get('AX')==0x014f and calls==[0]


def test_refresh_batches_banks_and_avoids_idle_pixel_writes(vesa_driver):
    banks=[]; writes=[]
    def bios(m):
        assert m.get('AX')==0x4f05
        banks.append(m.get('DX')); m.put('AX',0x004f)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1'); m.write('text_bank',b'\1\0')
    m.uc.mem_write(0xb8000,b' \x07'*2000)
    m.uc.hook_add(UC_HOOK_MEM_WRITE,
                  lambda uc,access,address,size,value,_: writes.append(size),
                  begin=0xa0000,end=0xaffff)
    m.run('refresh',limit=10000000)
    assert banks==[0,1] and sum(writes)==2000*18*4
    banks.clear(); writes.clear()
    m.run('refresh',limit=10000000)
    assert banks==[0,1] and writes==[]
    banks.clear(); writes.clear(); m.uc.mem_write(0xb8000,b'A')
    m.run('refresh',limit=10000000)
    assert banks==[0,1] and 0 < sum(writes) < 2000*18*4


def test_zero_length_capture_checks_availability_without_bank_switch(vesa_driver):
    m=Driver(vesa_driver,lambda m: pytest.fail('empty read must not enter BIOS'))
    m.write('active',b'\1'); m.write('banked_text',b'\1')
    m.run(AX=0x1412,BX=0,CX=0,SI=0,ES=0x3000,DI=0)
    assert m.get('AX')==0


@pytest.mark.parametrize('operation',[0x1400,0x1404,0x140f])
def test_prompt_and_wide_string_bank_once_per_operation(vesa_driver,operation):
    banks=[]
    def bios(m):
        assert m.get('AX')==0x4f05
        banks.append(m.get('DX')); m.put('AX',0x004f)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1'); m.write('text_bank',b'\1\0')
    m.uc.mem_write(0x30000,b'Long input method prompt\0')
    m.run(AX=operation,BX=0x1e,CX=0,DX=0x1900,ES=0x3000,SI=0,limit=1000000)
    assert banks==[0,1]
