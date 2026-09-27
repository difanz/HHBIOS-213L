"""Run the actual linked font loader/cache with observable XMS/EMS managers."""
import struct

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

from qa.spec.dos import ROOT
from qa.spec.pixels import native_rows
from qa.spec.test_vesa_api import vesa_driver

pytestmark=pytest.mark.unit


class FontMachine:
    def __init__(self,image,kind='xms',data=None,failure=None):
        raw,self.symbols=image
        self.uc=Uc(UC_ARCH_X86,UC_MODE_16); self.uc.mem_map(0,0x100000)
        self.uc.mem_write(0x10100,raw)
        self.buffer=(len(raw)+0x10f)&~15
        assert self.buffer+256<0xe000, 'Test buffer must fit below the test stack'
        self.kind,self.failure=kind,failure
        self.data=data if data is not None else (ROOT/'fonts/HH20.FNT').read_bytes()
        self.position=0; self.moves=0; self.closed=0; self.allocated=False
        self.payload=bytearray()
        self.write('resident_segment',struct.pack('<H',0x1000))
        self.uc.mem_write(0xf0000,b'\xcd\xf2\xcb')
        self.uc.mem_write(0xe000a,b'EMMXXXX0' if kind=='ems' else b'NO EMS!!')
        self.uc.hook_add(UC_HOOK_INTR,self.interrupt)

    def get(self,n): return self.uc.reg_read(getattr(reg,'UC_X86_REG_'+n))
    def put(self,n,v): self.uc.reg_write(getattr(reg,'UC_X86_REG_'+n),v)
    def write(self,n,v): self.uc.mem_write(0x10000+self.symbols[n],v)
    def word(self,n): return struct.unpack('<H',self.uc.mem_read(0x10000+self.symbols[n],2))[0]

    def interrupt(self,uc,number,_):
        ax=self.get('AX'); self.put('EFLAGS',self.get('EFLAGS') & ~1)
        if number==0x21:
            if ax==0x3d00:
                assert uc.mem_read(self.get('DS')*16+self.get('DX'),9)==b'HH20.FNT\0'
                self.put('AX',5)
            elif ax==0x3f00:
                assert self.get('BX')==5
                chunk=self.data[self.position:self.position+self.get('CX')]
                uc.mem_write(self.get('DS')*16+self.get('DX'),chunk)
                self.position+=len(chunk); self.put('AX',len(chunk))
            elif ax==0x3e00:
                assert self.get('BX')==5; self.closed+=1
            elif ax==0x3567: self.put('ES',0xe000); self.put('BX',0)
            else: pytest.fail(f'unexpected DOS {ax:04x}')
        elif number==0x2f:
            if ax==0x4300: self.put('AX',0x4380 if self.kind=='xms' else 0x4300)
            elif ax==0x4310: self.put('ES',0xf000); self.put('BX',0)
            else: pytest.fail(f'unexpected multiplex {ax:04x}')
        elif number==0xf2:
            if ax==0x0900:
                self.allocated=True; self.payload=bytearray(self.get('DX')*1024)
                self.put('DX',0x1234); self.put('AX',1)
            elif ax==0x0a00:
                assert self.get('DX')==0x1234; self.allocated=False; self.put('AX',1)
            elif ax==0x0b00:
                packet=bytes(uc.mem_read(self.get('DS')*16+self.get('SI'),16))
                size,source,so,destination,do=struct.unpack('<IHIHI',packet)
                assert not size % 2
                self.move(size,source,so,destination,do)
                self.put('AX',0 if self.failure=='move' else 1)
            else: pytest.fail(f'unexpected XMS {ax:04x}')
        elif number==0x67:
            if ax==0x4600: self.put('AX',0x40)
            elif ax==0x4300:
                self.allocated=True; self.payload=bytearray(self.get('BX')*16384)
                self.put('DX',0x1234); self.put('AX',0)
            elif ax==0x4500:
                assert self.get('DX')==0x1234; self.allocated=False; self.put('AX',0)
            elif ax==0x5700:
                packet=bytes(uc.mem_read(self.get('DS')*16+self.get('SI'),18))
                size,st,sh,so,sp,dt,dh,do,dp=struct.unpack('<IBHHHBHHH',packet)
                assert st in (0,1) and dt in (0,1) and st!=dt
                self.move(size,sh if st else 0,sp*16384+so if st else sp*65536+so,
                          dh if dt else 0,dp*16384+do if dt else dp*65536+do)
                self.put('AX',0x8000 if self.failure=='move' else 0)
            else: pytest.fail(f'unexpected EMS {ax:04x}')
        else: pytest.fail(f'unexpected interrupt {number:02x}')

    def move(self,size,source,so,destination,do):
        self.moves+=1
        assert (source,destination) in ((0x1234,0),(0,0x1234))
        if self.failure=='move': return
        if source:
            assert so+size<=len(self.payload)
            self.uc.mem_write((do >> 16)*16+(do & 65535),bytes(self.payload[so:so+size]))
        else:
            assert do+size<=len(self.payload)
            self.payload[do:do+size]=self.uc.mem_read((so >> 16)*16+(so & 65535),size)

    def call(self,name,*args):
        for n,v in dict(CS=0x1000,DS=0x1000,ES=0x7890,SS=0x1000,SP=0xe000,EFLAGS=0x202).items(): self.put(n,v)
        self.uc.mem_write(0x1e000,struct.pack('<'+'H'*(len(args)+1),0xff00,*args))
        self.uc.emu_start(0x10000+self.symbols[name],0x1ff00,count=3000000)
        assert self.get('IP')==0xff00 and self.get('SP')==0xe002
        assert self.get('DS')==self.get('SS')==0x1000
        return self.get('AX')


@pytest.mark.parametrize('kind',['xms','ems'])
def test_font_load_cache_and_traditional_bank(vesa_driver,kind):
    m=FontMachine(vesa_driver,kind)
    assert m.call('font_open')==1 and m.closed==1
    assert m.word('font_kind')==({'xms':1,'ems':2}[kind])
    assert m.payload[:len(m.data)-32]==m.data[32:]
    for traditional in (False,True):
        m.write('traditional',bytes([not traditional]))
        for code in (32,65,0xba,0xc9,0xa6a1,0xa6c1,0xbaba,0xd6d0,0xcec4,0xd7d6):
            for repeated in range(2):
                before=m.moves
                m.uc.mem_write(0x10000+m.buffer,b'\xa5'*96)
                m.call('font_get',code,m.buffer+2)
                out=bytes(m.uc.mem_read(0x10000+m.buffer,96))
                assert out[:2]==out[-2:]==b'\xa5\xa5'
                expected=native_rows(code,traditional=traditional)+native_rows(code,1,traditional)
                assert struct.unpack('<46H',out[2:-2])==tuple(v << 6 for v in expected)
                if repeated: assert m.moves==before
    assert m.word('font_fault')==0
    m.call('font_close'); assert not m.allocated


@pytest.mark.parametrize('kind',['xms','ems'])
@pytest.mark.parametrize('corruption',['signature','geometry','truncated','trailing','move'])
def test_font_failed_install_closes_file_and_releases_storage(vesa_driver,kind,corruption):
    raw=bytearray((ROOT/'fonts/HH20.FNT').read_bytes())
    if corruption=='signature': raw[0]=0
    elif corruption=='geometry': raw[8]=8
    elif corruption=='truncated': raw=raw[:-2]
    elif corruption=='trailing': raw+=b'junk'
    m=FontMachine(vesa_driver,kind,bytes(raw),failure=corruption)
    assert m.call('font_open')==0 and m.closed==1
    assert not m.allocated and m.word('font_kind')==0


@pytest.mark.parametrize('kind',['xms','ems'])
def test_runtime_font_failure_is_not_cached(vesa_driver,kind):
    m=FontMachine(vesa_driver,kind); assert m.call('font_open')==1
    m.failure='move'; m.call('font_get',65,m.buffer)
    assert m.word('font_fault')==1 and m.uc.mem_read(0x10000+m.buffer,92)==bytes(92)
    m.failure=None; before=m.moves; m.call('font_get',65,m.buffer)
    assert m.moves==before+2
    assert struct.unpack('<23H',m.uc.mem_read(0x10000+m.buffer,46))==tuple(v << 6 for v in native_rows(65))


@pytest.mark.parametrize('kind',['xms','ems'])
def test_downloaded_glyph_updates_without_invalidating_unrelated_cells(vesa_driver,kind):
    m=FontMachine(vesa_driver,kind); assert m.call('font_open')==1
    # Replace only the hardware observation boundary; execute the real cache,
    # change detection, external-memory transfers and bitmap raster preparation.
    m.uc.mem_write(0x10000+m.symbols['font_snapshot'],b'\xb8\x01\x00\xc3')
    rom=bytes((i*13+i//16)&255 for i in range(4096))
    m.uc.mem_write(0x30000,rom); m.write('font_segment',struct.pack('<H',0x3000))
    m.write('font_offset',b'\0\0'); m.write('text_cells',struct.pack('<H',2000))
    bitmap=bytearray(rom); code=0xb9
    bitmap[code*16:code*16+16]=bytes([0x81]*16)
    address=0x10000+m.symbols['text_transfer']+4096
    m.uc.mem_write(address,bytes(bitmap)); m.call('font_sync')
    flags=bytes(m.uc.mem_read(0x10000+m.symbols['font_custom'],256))
    assert [i for i,f in enumerate(flags) if f&1]==[code]
    m.call('font_get',code,m.buffer)
    expected=sum(((0x81>>(7-x*8//10))&1)<<(15-x) for x in range(10))
    assert struct.unpack('<46H',m.uc.mem_read(0x10000+m.buffer,92))==(expected,)*23+(0,)*23
    moves=m.moves
    m.uc.mem_write(address,bytes(bitmap)); m.call('font_sync'); m.call('font_get',code,m.buffer)
    assert m.moves==moves+1, 'Unchanged glyph must reuse its decoded cache entry'
    screen=bytes([code,7,65,7])*1000
    m.write('shadow',screen)
    bitmap[code*16:code*16+16]=bytes([0xff]*16)
    m.uc.mem_write(address,bytes(bitmap)); m.call('font_sync')
    shadow=bytes(m.uc.mem_read(0x10000+m.symbols['shadow'],4000))
    assert shadow[2::4]==screen[2::4] and shadow[3::4]==screen[3::4]
    assert shadow[1::4]==bytes([0xf8])*1000
    m.call('font_get',code,m.buffer)
    assert struct.unpack('<23H',m.uc.mem_read(0x10000+m.buffer,46))==(0xffc0,)*23
    m.uc.mem_write(address,rom); m.call('font_sync'); m.call('font_get',code,m.buffer)
    assert struct.unpack('<23H',m.uc.mem_read(0x10000+m.buffer,46))==tuple(v<<6 for v in native_rows(code))
