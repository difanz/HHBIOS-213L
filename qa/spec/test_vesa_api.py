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
    assert layout_library.vesa_console_layout(ctypes.byref(s),buf,0x200,0x321)==int((width,height,bpp)==(1024,768,4))


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
        near=entry not in ('int10_handler','int33_handler')
        context=dict(CS=0x1000,DS=0x1000,SS=0x1000 if near else 0x8000,
                     SP=0xe000,EFLAGS=0x202)
        context.update(registers)
        for name,value in context.items(): self.put(name,value)
        address=(self.get('SS')<<4)+self.get('SP')
        frame=struct.pack('<H',0xff00) if near else struct.pack('<HHH',0xff00,0x1000,0x202)
        self.uc.mem_write(address,frame)
        self.uc.emu_start(0x10000+self.symbols[entry],0x1ff00,count=limit)
        assert self.get('IP')==0xff00
        assert self.get('SP')==0xe000+len(frame)
        assert self.read('stack_bottom',2)==b'\x5a\xa5'


@pytest.mark.parametrize('banked,page',[(0,1),(0,255),(1,8),(1,255)])
@pytest.mark.parametrize('function',[0x0200,0x0300,0x0800,0x0941,0x0a41,0x1300])
def test_unavailable_text_pages_do_not_alias_valid_pages(vesa_driver,banked,page,function):
    m=Driver(vesa_driver,lambda m: pytest.fail('invalid page must not enter BIOS'))
    m.write('active',b'\1'); m.write('banked_text',bytes([banked]))
    bda=bytearray(256)
    for p in range(8): struct.pack_into('<H',bda,0x50+2*p,0x0103)
    m.uc.mem_write(0x400,bytes(bda))
    text=b''.join(bytes([65+p,7])*2048 for p in range(8))
    m.uc.mem_write(0xb8000,text); m.uc.mem_write(0x30000,b'AB')
    accesses=[]
    m.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE,
        lambda uc,access,address,size,value,_: accesses.append(address),
        begin=0xa0000,end=0xbffff)
    m.run(AX=function,BX=(page<<8)|0x1e,CX=2,DX=0x0304,ES=0x3000,BP=0)
    assert m.uc.mem_read(0x400,256)==bda
    assert m.uc.mem_read(0xb8000,32768)==text
    assert not accesses, 'an unavailable page must not alias an existing page'
    assert m.get('AX')==function and m.get('DX')==0x0304


@pytest.mark.parametrize('drawing',[False,True])
@pytest.mark.parametrize('col,role',[(3,1),(4,2),(5,0)])
@pytest.mark.parametrize('row,rows',[(4,25),(31,50),(42,43),(49,50)])
def test_keyboard_query_uses_live_text_or_banked_snapshot_without_c_reentry(vesa_driver,drawing,col,role,row,rows):
    banks=[]
    def bios(m):
        assert m.get('AX')==0x4f05
        banks.append(m.get('DX')); m.put('AX',0x004f)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1')
    m.write('text_rows',struct.pack('<H',rows)); m.write('last_row',bytes([rows-1]))
    m.write('text_cells',struct.pack('<H',rows*80))
    text=bytearray(b' \x07'*(80*rows)); text[(row*80+3)*2:(row*80+6)*2]=b'\xd6\x07\xd0\x07a\x07'
    m.uc.mem_write(0xb8000,bytes(text))
    if drawing:
        m.run('begin_draw')
        assert banks==[0]
        m.write('busy',b'\1')
        # While A000 is selected, reading B800 does not expose the text page.
        m.uc.mem_write(0xb8000,b'\xa5'*len(text))
    m.write('request',b'\xa5'*20)
    bottom,top=m.symbols['stack_bottom'],m.symbols['stack_top']
    stack=bytes(m.uc.mem_read(0x10000+bottom,top-bottom))
    initial=dict(AX=0x1410,BX=0,CX=0x5678,DX=row*256+col,
                 SI=0x1234,DI=0x3456,BP=0x4567,DS=0x3000,ES=0x4000)
    m.run(**initial)
    assert (m.get('AX'),m.get('BX'),m.get('CX'))==(role,0x4b48,0x1000+m.symbols['text_transfer']//16)
    for name in ('DX','SI','DI','BP','DS','ES'): assert m.get(name)==initial[name]
    assert m.read('request',20)==b'\xa5'*20
    assert m.read('busy')==bytes([drawing])
    assert m.get('SS')==0x8000 and m.get('EFLAGS')==0x202
    assert bytes(m.uc.mem_read(0x10000+bottom,top-bottom))==stack
    assert m.read('text_transfer',len(text))==bytes(text)
    assert banks==([0] if drawing else [])


@pytest.mark.parametrize('failure',[False,True])
def test_large_plane_capture_splits_banks_and_restores_text_mapping(vesa_driver,failure):
    banks=[]
    def bios(m):
        assert m.get('AX')==0x4f05
        bank=m.get('DX'); banks.append(bank)
        m.put('AX',0x014f if failure and bank==1 else 0x004f)
        m.uc.mem_write(0xa0000,bytes([0x30+bank])*65536)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('large_surface',b'\1'); m.write('banked_text',b'\1')
    m.write('text_bank',struct.pack('<H',6)); m.write('bank_step',struct.pack('<H',1))
    m.write('plane_bytes',struct.pack('<I',163840)); m.write('keyboard_segment',b'\0\x20')
    m.write('screen',struct.pack('<4H',1280,1024,160,0xa000))
    m.uc.mem_write(0x30000,b'\xa5'*32)
    m.run(AX=0x1414,BX=2,DX=0,SI=65530,ES=0x3000,DI=4,CX=16)
    assert banks==[0,1,6]
    expected=b'0'*6+(b'\xa5'*10 if failure else b'1'*10)
    assert m.uc.mem_read(0x30000,32)==b'\xa5'*4+expected+b'\xa5'*12
    assert m.get('AX')==int(failure)
    assert m.read('active')==bytes([not failure])
    if failure: assert m.uc.mem_read(0x20101,1)==b'\xff'


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
                  lambda uc,access,address,size,value,_: accesses.append((address,tuple(calls))),
                  begin=0xa0000,end=0xbffff)
    m.run(AX=0x1412,BX=0,SI=0,CX=16,ES=0x3000,DI=0)
    assert m.get('AX')==1 and m.read('active')==b'\0'
    assert m.uc.mem_read(0x20101,1)==b'\xff'
    assert calls==([0] if failed_bank==0 else [0,1])
    if failed_bank==0:
        # The pre-switch text snapshot is safe; no framebuffer access may
        # occur after the BIOS rejects the switch to graphics bank zero.
        assert accesses==[(address,()) for address in range(0xb8000,0xb8000+4000,2)]
        assert m.uc.mem_read(0x30000,16)==b'\xa5'*16


@pytest.mark.parametrize('function',[0x1412,0x1414])
def test_capture_during_render_requests_retry_without_touching_stack(vesa_driver,function):
    m=Driver(vesa_driver,lambda m: pytest.fail('must not enter BIOS'))
    m.write('busy',b'\1')
    before=m.uc.mem_read(0x10000+m.symbols['stack_bottom'],2050)
    m.run(AX=function,BX=3,ES=0x3000,DI=0)
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


@pytest.mark.parametrize('explicit',[False,True])
def test_explicit_mode_does_not_fall_back_to_bios_list(vesa_driver,explicit):
    queried=[]
    def bios(m):
        ax=m.get('AX'); address=m.get('ES')*16+m.get('DI')
        if ax==0x4f00:
            info=bytearray(256); info[:4]=b'VESA'
            struct.pack_into('<H',info,4,0x200)
            struct.pack_into('<HH',info,14,0,0x3000)
            m.uc.mem_write(address,bytes(info)); m.put('AX',0x004f)
        else:
            assert ax==0x4f01
            queried.append(m.get('CX')); m.put('AX',0x014f)
    m=Driver(vesa_driver,bios)
    m.write('mode_selected',bytes([explicit]))
    m.uc.mem_write(0x30000,struct.pack('<3H',0x104,0x106,0xffff))
    m.run('initialize')
    assert m.get('AX')==1 and m.read('active')==b'\0'
    assert queried==([0x102] if explicit else [0x102,0x104,0x106])


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
    m.run('refresh',limit=20000000)
    assert banks==[0,1] and sum(writes)==2000*23*4*2
    banks.clear(); writes.clear()
    m.run('refresh',limit=10000000)
    assert banks==[0,1] and writes==[]
    banks.clear(); writes.clear(); m.uc.mem_write(0xb8000,b'A')
    m.run('refresh',limit=10000000)
    assert banks==[0,1] and 0 < sum(writes) < 2000*23*4*2


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


@pytest.mark.parametrize('ax,bx,returned_bx,changes_layout', [
    (0x4f05,0,0,True), (0x4f05,0x100,0x100,False),
    (0x4f06,0,257,True), (0x4f06,1,100,False),
    (0x4f06,2,259,True), (0x4f06,3,4096,False),
    (0x4f07,0,0,True), (0x4f07,0x80,0x80,True),
    (0x4f07,1,1,False), (0x4f07,4,4,False),
    (0x4f07,2,2,True), (0x4f07,3,3,True),
    (0x4f07,0x82,0x82,True), (0x4f07,0x83,0x83,True),
    (0x4f07,5,5,True), (0x4f07,6,6,True),
])
@pytest.mark.parametrize('status',[0x004f,0x014f])
def test_vbe_layout_ownership_uses_input_subfunction(vesa_driver,ax,bx,returned_bx,changes_layout,status):
    calls=[]
    def bios(m):
        calls.append((m.get('AX'),m.get('BX')))
        assert calls==[(ax,bx)]
        assert m.get('ECX')==0x12340320 and m.get('EDX')==0x56780000
        m.put('AX',status); m.put('BX',returned_bx)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('keyboard_segment',b'\0\x20')
    m.uc.mem_write(0x20101,b'\x12')
    m.run(AX=ax,BX=bx,ECX=0x12340320,EDX=0x56780000)
    expected=not (status==0x004f and changes_layout)
    assert m.read('active')==bytes([expected])
    assert m.uc.mem_read(0x20101,1)==bytes([0x12 if expected else 0xff])
    assert (m.get('AX'),m.get('BX'))==(status,returned_bx)


@pytest.mark.parametrize('operation', ['bank','stride','display-start','state'])
@pytest.mark.parametrize('status',[0x004f,0x014f])
def test_cursor_removed_before_external_layout_change_and_restored_on_failure(vesa_driver,operation,status):
    events=[]
    def bios(m):
        ax=m.get('AX')
        if ax==0x4f05 and operation=='bank' and m.get('DX')==7:
            events.append(('external',ax)); m.put('AX',status)
        elif ax==0x4f05:
            events.append(('bank',m.get('DX'))); m.put('AX',0x004f)
        elif ax==0x4f04 and m.get('DX')==0:
            events.append(('size',0)); m.put('BX',1); m.put('AX',0x004f)
        else:
            events.append(('external',ax)); m.put('AX',status)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1'); m.write('text_bank',b'\1\0')
    # Draw the software cursor through the public BIOS interface first.
    m.run(AX=0x0100,CX=0x0d0e)
    assert events==[('bank',0),('bank',1)]
    events.clear()
    ax,bx,cx,dx={
        'bank':(0x4f05,0,0,7), 'stride':(0x4f06,2,128,0),
        'display-start':(0x4f07,0,0,8), 'state':(0x4f04,0,8,2),
    }[operation]
    m.run(AX=ax,BX=bx,CX=cx,DX=dx,ES=0x3000)
    expected=([('size',0)] if operation=='state' else [])
    expected += [('bank',0),('bank',1),('external',ax)]
    if status!=0x004f: expected += [('bank',0),('bank',1)]
    assert events==expected
    assert m.get('AX')==status
    assert m.read('active')==bytes([status!=0x004f])


@pytest.mark.parametrize('mask',[1,2,4,8,9,15])
@pytest.mark.parametrize('status',[0x004f,0x014f])
def test_state_restore_of_external_registers_releases_display(vesa_driver,mask,status):
    calls=[]
    def bios(m):
        calls.append(m.get('DX'))
        assert m.get('AX')==0x4f04 and m.get('CX')==mask
        if m.get('DX')==0: m.put('BX',1); m.put('AX',0x004f)
        else: m.put('AX',status)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('keyboard_segment',b'\0\x20')
    m.uc.mem_write(0x20101,b'\x12')
    # A state saved while HHBIOS did not own the display has no private tag.
    m.uc.mem_write(0x30000,b'\xa5'*128)
    m.run(AX=0x4f04,BX=0,CX=mask,DX=2,ES=0x3000)
    assert calls==[0,2] and m.get('AX')==status
    expected=not (status==0x004f and mask&9)
    assert m.read('active')==bytes([expected])
    assert m.uc.mem_read(0x20101,1)==bytes([0x12 if expected else 0xff])
    assert m.uc.mem_read(0x30000,128)==b'\xa5'*128


@pytest.mark.parametrize('ax,bx,dx',[(0x4f02,0x1ff,0),(0x4f06,2,0),
                                  (0x4f04,0,1),(0x4f04,0,2)])
@pytest.mark.parametrize('status',[0x004f,0x014f])
def test_cursor_bank_failure_keeps_renderer_and_keyboard_disabled(vesa_driver,ax,bx,dx,status):
    fail_bank=False
    def bios(m):
        nonlocal fail_bank
        if m.get('AX')==0x4f05:
            m.put('AX',0x014f if fail_bank else 0x004f); fail_bank=False
        elif m.get('AX')==0x4f04 and m.get('DX')==0:
            m.put('BX',1); m.put('AX',0x004f)
        else: m.put('AX',status)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1'); m.write('text_bank',b'\1\0')
    m.write('keyboard_segment',b'\0\x20')
    m.run(AX=0x0100,CX=0x0d0e)
    fail_bank=True
    m.run(AX=ax,BX=bx,CX=9,DX=dx,ES=0x3000)
    assert m.get('AX')==status and m.read('active')==b'\0'
    assert m.uc.mem_read(0x20101,1)==b'\xff'


def test_cursor_redraw_bank_failure_after_bios_failure_disables_keyboard(vesa_driver):
    banks=0
    def bios(m):
        nonlocal banks
        if m.get('AX')==0x4f05:
            banks+=1; m.put('AX',0x014f if banks==3 else 0x004f)
        else: m.put('AX',0x014f)
    m=Driver(vesa_driver,bios)
    m.write('active',b'\1'); m.write('banked_text',b'\1'); m.write('text_bank',b'\1\0')
    m.write('keyboard_segment',b'\0\x20')
    m.run(AX=0x0100,CX=0x0d0e)
    banks=0
    m.run(AX=0x4f06,BX=2,CX=128)
    assert banks==3 and m.get('AX')==0x014f
    assert m.read('active')==b'\0' and m.uc.mem_read(0x20101,1)==b'\xff'
