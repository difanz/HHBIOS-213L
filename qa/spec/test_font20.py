"""Run the actual linked font loader/cache with observable XMS/EMS managers."""
import random
import struct

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_CODE
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
        assert self.buffer+520<0xf000, 'Test buffer must fit below the test stack'
        self.kind,self.failure=kind,failure
        self.data=data if data is not None else (ROOT/'fonts/HH20.FNT').read_bytes()
        self.position=0; self.moves=0; self.closed=0; self.allocated=False
        self.payload=bytearray()
        self.write('resident_segment',struct.pack('<H',0x1000))
        self.write('font_selected', b'\1')
        self.write('banked_text_allowed', b'\1')
        self.write('screen', struct.pack('<HH', 4096, 2160))
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
                self.position=0
                self.put('AX',5)
            elif ax==0x4202:
                assert self.get('BX')==5 and self.get('CX')==self.get('DX')==0
                self.position=len(self.data)
                self.put('DX',self.position>>16); self.put('AX',self.position&65535)
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
        for n,v in dict(CS=0x1000,DS=0x1000,ES=0x7890,SS=0x1000,SP=0xfe00,EFLAGS=0x202).items(): self.put(n,v)
        self.uc.mem_write(0x1fe00,struct.pack('<'+'H'*(len(args)+1),0xff00,*args))
        self.uc.emu_start(0x10000+self.symbols[name],0x1ff00,count=3000000)
        assert self.get('IP')==0xff00 and self.get('SP')==0xfe02
        assert self.get('DS')==self.get('SS')==0x1000
        return self.get('AX')


def sized_font(width, height):
    """Small format fixture: blank, asymmetric ASCII A and Chinese 中."""
    stride = (2 * width + 7) // 8
    record_size = (stride * height + 1) & ~1
    maps = [0] * (8434 * 2)
    slot = 256 + (0xd6 - 0xa1) * 94 + 0xd0 - 0xa1
    for bank in (0, 8434):
        maps[bank + 65] = 1
        maps[bank + slot] = 2
    records = [bytes(record_size)]
    for columns in (width, 2 * width):
        rows = [sum(1 << (stride * 8 - 1 - x) for x in range(columns)
                    if (x * 3 + y * 5) % 11 < 4)
                for y in range(height)]
        records.append(b''.join(row.to_bytes(stride, 'big') for row in rows).ljust(record_size, b'\0'))
    payload = struct.pack(f'<{len(maps)}H', *maps) + b''.join(records)
    return struct.pack('<8s4HI12x', b'HHFONT2\n', width, height, 8434, 3, len(payload)) + payload


class CatalogMachine(FontMachine):
    def __init__(self, image, limit=None):
        super().__init__(image)
        self.files = {'HH20.FNT': self.data, **{
            f'F{width:02}{height:02}.FNT': sized_font(width, height)
            for width, height in ((16, 39), (16, 23), (16, 20))}}
        self.write('font_selected', b'\0')
        self.write('screen', struct.pack('<HH', 1280, 1024))
        self.dta = (0x5678, 0x80)
        self.limit = limit
        self.requests = []

    def interrupt(self, uc, number, context):
        ax = self.get('AX')
        self.put('EFLAGS', self.get('EFLAGS') & ~1)
        if number == 0x21:
            if ax == 0x3d00:
                address = self.get('DS') * 16 + self.get('DX')
                name = bytes(uc.mem_read(address, 64)).split(b'\0')[0].decode()
                self.data = self.files[name]
                self.position = 0
                self.put('AX', 5)
                return
            if ax == 0x2f00:
                self.put('ES', self.dta[0]); self.put('BX', self.dta[1])
                return
            if ax == 0x1a00:
                self.dta = (self.get('DS'), self.get('DX'))
                return
            if ax in (0x4e00, 0x4f00):
                if ax == 0x4e00:
                    self.matches = iter(name for name in self.files if name.startswith('F'))
                name = next(self.matches, None)
                if name is None:
                    self.put('AX', 18); self.put('EFLAGS', self.get('EFLAGS') | 1)
                else:
                    uc.mem_write(self.dta[0] * 16 + self.dta[1] + 30,
                                 name.encode() + b'\0')
                return
        if number == 0xf2 and ax == 0x0900:
            self.requests.append(self.get('DX'))
            if self.limit is not None and self.get('DX') > self.limit:
                self.put('AX', 0); self.put('BX', 0xa0)
                return
        super().interrupt(uc, number, context)


@pytest.mark.parametrize('limit', [None, 80])
def test_catalog_preserves_dta_and_trims_only_optional_sizes(vesa_driver, limit):
    machine = CatalogMachine(vesa_driver, limit)
    assert machine.call('font_open') == 1
    assert machine.dta == (0x5678, 0x80)
    assert (machine.word('font_width'), machine.word('font_height')) == (16, 39)
    assert machine.allocated
    if limit is None:
        assert len(machine.requests) == 1
        assert machine.call('font_choose', 1280, 1024, 50, 1)
        assert machine.word('font_height') == 20
        assert machine.call('font_choose', 1280, 1024, 25, 1)
        assert machine.word('font_height') == 39
    else:
        assert len(machine.requests) == 4
        assert machine.requests == sorted(machine.requests, reverse=True)
        assert not machine.call('font_choose', 1280, 1024, 50, 0)
    machine.call('font_close')
    assert not machine.allocated


@pytest.mark.parametrize('kind', ['xms', 'ems'])
@pytest.mark.parametrize('width,height', [(8, 16), (9, 23), (10, 20), (12, 29), (16, 39), (23, 63), (24, 64)])
def test_variable_font_cache_and_half_boundaries(vesa_driver, kind, width, height):
    m = FontMachine(vesa_driver, kind, sized_font(width, height))
    assert m.call('font_open') == 1 and m.closed == 2
    assert (m.word('font_width'), m.word('font_height')) == (width, height)
    for code in (32, 65, 0xd6d0):
        m.uc.mem_write(0x10000 + m.buffer, b'\xa5' * 516)
        m.call('font_get_large', code, m.buffer + 2)
        result = bytes(m.uc.mem_read(0x10000 + m.buffer, 516))
        assert result[:2] == result[-2:] == b'\xa5\xa5'
        expected = []
        for half in range(2):
            for y in range(64):
                expected.append(sum(1 << (31 - x) for x in range(width)
                    if y < height and code != 32 and (half == 0 or code >= 256)
                    and ((x + half * width) * 3 + y * 5) % 11 < 4))
        assert struct.unpack('<128I', result[2:-2]) == tuple(expected)
        moves = m.moves
        m.call('font_get_large', code, m.buffer + 2)
        assert m.moves == moves


@pytest.mark.parametrize('offset,value', [(8, 7), (8, 25), (10, 15), (10, 65), (20, 1), (14, 0), (16, 0)])
def test_invalid_variable_font_is_rejected_before_allocation(vesa_driver, offset, value):
    data = bytearray(sized_font(12, 29))
    struct.pack_into('<H', data, offset, value)
    m = FontMachine(vesa_driver, data=bytes(data))
    assert m.call('font_open') == 0 and m.closed == 1 and not m.allocated


@pytest.mark.parametrize('width,height', [(12, 29), (16, 39), (24, 64)])
def test_variable_font_downloaded_bitmap_fills_cell(vesa_driver, width, height):
    m = FontMachine(vesa_driver, data=sized_font(width, height))
    assert m.call('font_open') == 1
    code = 65
    bitmap = bytes((y * 13 + 0x81) & 255 for y in range(16))
    offset = len(m.data) - 32 + 32768 + code * 16
    m.payload[offset:offset + 16] = bitmap
    m.uc.mem_write(0x10000 + m.symbols['font_custom'] + code, b'\1')
    m.call('font_get_large', code, m.buffer)
    result = struct.unpack('<128I', m.uc.mem_read(0x10000 + m.buffer, 512))
    expected = [sum(1 << (31 - x) for x in range(width)
                    if bitmap[y * 16 // height] & (128 >> (x * 8 // width)))
                for y in range(height)]
    assert result == tuple(expected + [0] * (128 - height))


@pytest.mark.parametrize('kind',['xms','ems'])
def test_font_load_cache_and_traditional_bank(vesa_driver,kind):
    m=FontMachine(vesa_driver,kind)
    assert m.call('font_open')==1 and m.closed==2
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
    assert m.call('font_open')==0 and m.closed==(2 if corruption=='move' else 1)
    assert not m.allocated and m.word('font_kind')==0


@pytest.mark.parametrize('kind',['xms','ems'])
def test_runtime_font_failure_is_not_cached(vesa_driver,kind):
    m=FontMachine(vesa_driver,kind); assert m.call('font_open')==1
    m.failure='move'; m.call('font_get',65,m.buffer)
    assert m.word('font_fault')==1 and m.uc.mem_read(0x10000+m.buffer,92)==bytes(92)
    m.failure=None; before=m.moves; m.call('font_get',65,m.buffer)
    assert m.moves==before+2
    assert struct.unpack('<23H',m.uc.mem_read(0x10000+m.buffer,46))==tuple(v << 6 for v in native_rows(65))


@pytest.mark.parametrize('kind', ['xms', 'ems'])
def test_alphabet_fits_cache_and_batches_record_map_reads(vesa_driver, kind):
    m = FontMachine(vesa_driver, kind)
    assert m.call('font_open') == 1
    before = m.moves
    for code in range(65, 91):
        m.call('font_get', code, m.buffer)
        assert struct.unpack('<23H', m.uc.mem_read(0x10000+m.buffer, 46)) == tuple(
            v << 6 for v in native_rows(code))
    assert m.moves-before == 27  # one map page and 26 glyphs
    before = m.moves
    for _ in range(3):
        for code in range(65, 91):
            m.call('font_get', code, m.buffer)
    assert m.moves == before


@pytest.mark.parametrize('kind', ['xms', 'ems'])
@pytest.mark.parametrize('filename,count', [('F1639.FNT', 26), ('F2441.FNT', 8)])
def test_large_native_working_set_reuses_cached_pixels(vesa_driver, kind, filename, count):
    data = (ROOT / 'fonts/large' / filename).read_bytes()
    width, height = struct.unpack_from('<HH', data, 8)
    stride = (width * 2 + 7) // 8
    record_bytes = (stride * height + 1) & ~1
    m = FontMachine(vesa_driver, kind, data)
    assert m.call('font_open') == 1
    snapshot = bytes((i * 17 + 3) & 255 for i in range(8192))
    m.write('text_transfer', snapshot)
    before = m.moves
    for cycle in range(3):
        for code in range(65, 65 + count):
            m.call('font_get_large', code, m.buffer)
            record = struct.unpack_from('<H', data, 32 + code * 2)[0]
            pixels = data[32 + 33736 + record * record_bytes:]
            expected = []
            for half in range(2):
                for y in range(64):
                    bits = 0
                    if y < height:
                        row = int.from_bytes(pixels[y * stride:(y + 1) * stride], 'big')
                        for x in range(width):
                            bits |= ((row >> (stride * 8 - 1 - x - half * width)) & 1) << (31 - x)
                    expected.append(bits)
            assert struct.unpack('<128I', m.uc.mem_read(0x10000 + m.buffer, 512)) == tuple(expected)
        assert m.moves - before == count + 1, 'A warmed working set must not fetch glyphs again'
        assert bytes(m.uc.mem_read(0x10000 + m.symbols['text_transfer'], 8192)) == snapshot


def test_oversized_alphabet_does_not_repack_every_cache_miss(vesa_driver):
    m = FontMachine(vesa_driver, data=(ROOT / 'fonts/large/F2441.FNT').read_bytes())
    assert m.call('font_open') == 1
    instructions = [0]

    def count_instruction(*unused):
        instructions[0] += 1

    m.uc.hook_add(UC_HOOK_CODE, count_instruction)
    for code in range(65, 91):
        m.call('font_get_large', code, m.buffer)
    instructions[0] = 0
    for code in range(65, 91):
        m.call('font_get_large', code, m.buffer)
    # The measured repacking regression exceeded 140,000 instructions here.
    # Leave room for compiler variation while bounding work on cache misses.
    assert 10000 < instructions[0] < 100000


@pytest.mark.parametrize('kind', ['xms', 'ems'])
@pytest.mark.parametrize('width,height', [(9, 23), (24, 64)])
def test_dense_glyph_cache_wrap_keeps_every_pixel(vesa_driver, kind, width, height):
    stride = (width * 2 + 7) // 8
    record_bytes = (stride * height + 1) & ~1
    random_bytes = random.Random(213)
    records = [bytes(random_bytes.randrange(256) for _ in range(record_bytes))
               for _ in range(61)]
    mapping = [slot % len(records) for slot in range(8434)] * 2
    payload = struct.pack('<16868H', *mapping) + b''.join(records)
    data = struct.pack('<8s4HI12x', b'HHFONT2\n', width, height, 8434,
                       len(records), len(payload)) + payload
    m = FontMachine(vesa_driver, kind, data)
    assert m.call('font_open') == 1
    # Dense records select raw storage. Repeated arena wraps interleave them
    # with downloaded 16-byte glyphs; their unequal sizes must not alias.
    custom_code = 200
    custom = bytes([0x81, 0x42, 0x24, 0x18] * 4)
    offset = len(payload) + 32768 + custom_code * 16
    m.payload[offset:offset + 16] = custom
    m.uc.mem_write(0x10000 + m.symbols['font_custom'] + custom_code, b'\1')
    for code in list(range(61)) + list(range(60, -1, -1)):
        m.call('font_get_large', code, m.buffer)
        pixels = records[code]
        expected = []
        for half in range(2):
            for y in range(64):
                bits = 0
                if y < height:
                    row = int.from_bytes(pixels[y * stride:(y + 1) * stride], 'big')
                    bits = ((row >> (stride * 8 - (half + 1) * width)) &
                            ((1 << width) - 1)) << (32 - width)
                expected.append(bits)
        assert struct.unpack('<128I', m.uc.mem_read(0x10000 + m.buffer, 512)) == tuple(expected)
        m.call('font_get_large', custom_code, m.buffer)
        expected_custom = [sum(1 << (31 - x) for x in range(width)
                           if custom[y * 16 // height] & (128 >> (x * 8 // width)))
                           for y in range(height)]
        assert struct.unpack('<128I', m.uc.mem_read(0x10000 + m.buffer, 512)) == tuple(
            expected_custom + [0] * (128 - height))


def test_font_row_switch_discards_compact_cache(vesa_driver):
    m = CatalogMachine(vesa_driver)
    assert m.call('font_open') == 1
    for rows, height in ((25, 39), (50, 20), (43, 23), (25, 39)):
        assert m.call('font_choose', 1280, 1024, rows, 1)
        assert m.word('font_height') == height
        for code in (65, 0xd6d0, 65):
            m.call('font_get_large', code, m.buffer)
            expected = [sum(1 << (31 - x) for x in range(16)
                            if y < height and (half == 0 or code >= 256) and
                            ((x + half * 16) * 3 + y * 5) % 11 < 4)
                        for half in range(2) for y in range(64)]
            assert struct.unpack('<128I', m.uc.mem_read(0x10000 + m.buffer, 512)) == tuple(expected)


@pytest.mark.parametrize('kind', ['xms', 'ems'])
def test_record_map_tail_and_failed_replacement(vesa_driver, kind):
    m = FontMachine(vesa_driver, kind)
    assert m.call('font_open') == 1
    for code in (0xf7fe, 65, 0xf7fd):
        m.call('font_get', code, m.buffer)
        expected = native_rows(code)+native_rows(code, 1)
        assert struct.unpack('<46H', m.uc.mem_read(0x10000+m.buffer, 92)) == tuple(
            v << 6 for v in expected)
    m.failure = 'move'
    m.call('font_get', 32, m.buffer)
    assert m.uc.mem_read(0x10000+m.buffer, 92) == bytes(92)
    m.failure = None
    m.call('font_get', 32, m.buffer)
    m.call('font_get', 0xf7fc, m.buffer)
    expected = native_rows(0xf7fc)+native_rows(0xf7fc, 1)
    assert struct.unpack('<46H', m.uc.mem_read(0x10000+m.buffer, 92)) == tuple(
        v << 6 for v in expected)


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
