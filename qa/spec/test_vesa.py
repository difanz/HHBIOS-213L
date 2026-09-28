"""Independent VESA.COM: actual 800x600 planar pixels and DOS interfaces."""
import shutil
import os
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos, plane_bits
from qa.spec.pixels import colored_rows, native_rows
from qa.spec.machine import blank, put
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def vesa_build(assembler, source_dir, guest_build, tmp_path_factory):
    out = tmp_path_factory.mktemp('vesa-build')
    for p in guest_build.glob('*.COM'):
        shutil.copy2(p, out)
    p = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/vesatest.c', str(out/'VESATEST.COM')],
                       cwd=ROOT, capture_output=True, text=True)
    assert p.returncode == 0, p.stdout+p.stderr
    p=subprocess.run([assembler,'-q','-0','-bin','-Fo'+str(out/'VESACAPS.COM'),
                      str(ROOT/'qa/harness/vesacaps.asm')],
                     env={k:v for k,v in os.environ.items() if k!='JWASM'},capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    return out


@pytest.mark.parametrize('adapter',['vesa_oldvbe','vesa_nolfb','svga_s3'])
@pytest.mark.parametrize('residency',['',' /N'],ids=['automatic-UMB','conventional'])
def test_vesa_chinese_pixels(dosbox_binary, vesa_build, tmp_path, adapter, residency):
    for p in vesa_build.glob('*.COM'):
        shutil.copy2(p, tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16', tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT', tmp_path)
    keyboard_config(tmp_path)
    screen=blank()
    put(screen, 2, 10, '中文'.encode('gb2312'), 0x1e)
    put(screen, 24, 78, '字'.encode('gb2312'), 0xa5)
    (tmp_path/'INPUT.BIN').write_bytes(bytes([3])+bytes(screen))
    files=run_dos(dosbox_binary, tmp_path, ['SNAPSHOT font', 'VESATEST info', 'READ5', 'CKBD', 'VESA'+residency+' > VESA.LOG', 'VESATEST resident', 'VESATEST'], timeout=40,
                  settings=f'\n[dosbox]\nmachine={adapter}\n')
    resident=files['RESIDENT.BIN'].read_bytes()
    abi=struct.unpack_from('<10H',resident)
    assert abi[:3]==(0x5356,1,28) and abi[4]==1
    assert 0 < abi[5] < 56*1024  # bounded cache and font catalog; payloads stay in XMS/EMS
    assert (abi[8]<0xa000)==bool(residency)
    owner,paragraphs=struct.unpack_from('<HH',resident,49)
    assert owner==abi[8] and paragraphs==(abi[5]+15)//16
    assert struct.unpack_from('<3H',resident,20)==(800,600,100)
    raw=files['VESA00.BIN'].read_bytes()
    assert raw[:8] == b'HHVESA1\n'
    # REGPACK: AX BX CX DX BP SI DI DS ES FLAGS (20 bytes in 16-bit Watcom).
    assert len(raw)==8+20+4000+240000
    regs=struct.unpack_from('<10H',raw,8)
    assert regs[5:7] == (799,599), regs
    assert regs[2]==0x171a
    text=raw[28:4028]
    assert text==screen
    planes=[raw[4028+p*60000:4028+(p+1)*60000] for p in range(4)]
    font=(ROOT/'fonts/HZK16').read_bytes()
    for row,col,char,attr in [(2,10,'中',0x1e),(2,12,'文',0x1e),(24,78,'字',0xa5)]:
        hi,lo=char.encode('gb2312'); off=((hi-0xa1)*94+lo-0xa1)*32
        bits=font[off:off+32]
        for half in range(2):
            glyph=native_rows(hi*256+lo,half)
            for p in range(4):
                expected=colored_rows(glyph,10,23,attr,p)
                actual=plane_bits(planes[p],100,(col+half)*10,row*23,10,23)
                assert actual==expected, (row,col,half,p,actual,expected)
    # Observe the whole viewport, including cells the fixture did not change.
    # A text-bank alias can draw every sampled glyph correctly yet leave a
    # stripe of B800 character/attribute bytes elsewhere in the framebuffer.
    for row in range(25):
        for col in range(80):
            if screen[2*(row*80+col)]==32:
                for plane in planes:
                    assert plane_bits(plane,100,col*10,row*23,10,23)==(0,)*23, (row,col)
    # The status frame uses the two spare lines; all 23 glyph rows remain.
    for p, plane in enumerate(planes):
        for col, code in ((0, 0xd3a2), (2, 0xcec4)):
            for half in (0, 1):
                expected=colored_rows(native_rows(code,half),10,23,0x70,p)
                assert plane_bits(plane,100,(col+half)*10,576,10,23)==expected
        assert plane[57500:57600] == b'\xff' * 100
        assert plane[59900:60000] == bytes([255 if p == 3 else 0]) * 100


@pytest.mark.parametrize('cpu',['8086','286'])
def test_vesa_rejects_old_cpu_before_entering_386_code(dosbox_binary,vesa_build,tmp_path,cpu):
    shutil.copy2(vesa_build/'VESA.COM',tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['VESA /? > HELP.TXT',('VESA > CPU.TXT',1)],
                  settings=f'\n[dosbox]\nmachine=svga_s3\n[cpu]\ncore=normal\ncputype={cpu}\n')
    assert 'VESA [/N]' in files['HELP.TXT'].read_text()
    assert 'requires a 386' in files['CPU.TXT'].read_text()


@pytest.mark.parametrize('operation',['text','legacy','state','ports'])
@pytest.mark.parametrize('mode',[0x102,0x104,0x106],ids=['800','1024','1280'])
def test_vesa_return_and_register_ownership(dosbox_binary,vesa_build,tmp_path,operation,mode):
    from qa.spec.test_vbe import assert_chinese
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path); keyboard_config(tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT',tmp_path)
    screen=blank(); put(screen,2,10,'中文'.encode('gb2312'))
    (tmp_path/'INPUT.BIN').write_bytes(bytes([3])+bytes(screen))
    files=run_dos(dosbox_binary,tmp_path,['READ5','CKBD',f'VESA /M:{mode:x}','VESATEST '+operation,'SNAPSHOT'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    assert_chinese(files)
    if operation=='ports':
        data=files['PORTS.BIN'].read_bytes(); assert data[:11]==data[11:]
    else:
        raw=files['RETURN.BIN'].read_bytes()
        records=[struct.unpack_from('<10H',raw,i*20) for i in range(4)]
        if operation=='state':
            if records[0][0]==0x004f:
                size=records[0][1]*64
                assert all(r[0]==0x004f for r in records)
                assert raw[80:96]==raw[-16:]==b'\xa5'*16
                assert raw[96+size-64:96+size-60]==b'HHV\1'
            else:
                assert records[0][0]==0x014f and len(raw)==80
        else:
            assert records[0][0]==0x004f
            if operation=='text': assert records[1][0]==0x004f
            assert records[2][0]==0x004f and records[2][1] & 0x3fff==mode
            assert records[3][0]==0x5003


@pytest.mark.parametrize('ax,bx',[(0x4f05,0x100),(0x4f06,1),(0x4f06,3),(0x4f07,1)])
def test_vesa_readonly_vbe_queries_keep_console(dosbox_binary,vesa_build,tmp_path,ax,bx):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT',tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['READ5','VESA',f'VESATEST query {ax:x} {bx:x}'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    raw=files['QUERY.BIN'].read_bytes(); assert len(raw)==60
    before,result,after=[struct.unpack_from('<10H',raw,i*20) for i in range(3)]
    assert before[0]==0, 'Console must be available before querying the BIOS'
    assert after[0]==0, 'Read-only VBE query disabled the Chinese renderer'
    if result[0]!=0x004f: pytest.skip(f'BIOS does not support query {ax:04x}/{bx:04x}')


def test_vesa_prompt_bitmap_wide_text_and_pixels(dosbox_binary,vesa_build,tmp_path,pytestconfig):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT',tmp_path)
    (tmp_path/'INPUT.BIN').write_bytes(bytes([3])+bytes(blank()))
    files=run_dos(dosbox_binary,tmp_path,['SNAPSHOT font','READ5','VESA','VESATEST drawing','VESATEST'],
                  physical_keys=pytestconfig.getoption('--screenshots'),
                  screenshots=pytestconfig.getoption('--screenshots'),
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    data=files['DRAW.BIN'].read_bytes()
    assert struct.unpack_from('<5H',data)==(14,9,1,1,1)
    assert data[10:]==b'\xa5'*64
    raw=files['VESA00.BIN'].read_bytes()
    planes=[raw[4028+p*60000:4028+(p+1)*60000] for p in range(4)]
    def check(col,bits,attr,width=10,clip=False):
        for p in range(4):
            expected=colored_rows(bits,width,23,attr,p)
            if clip: expected=tuple(row >> (width-10) for row in expected)
            assert plane_bits(planes[p],100,col*10,576,10 if clip else width,23)==expected
    for col in range(4):
        check(col,bytes((i*3+7) & 255 for i in range(col*16,col*16+16))+b'\0\0',0x4b)
    glyphs=[native_rows(65),native_rows(0xd6d0),native_rows(0xd6d0,1),native_rows(90)]
    for i,glyph in enumerate(glyphs):
        # Column 79 is subsequently overwritten by the clipped A.
        check(70+i*2,glyph,0x2e,20,clip=i==3)
        if i==0: check(79,glyph,0x2e,20,clip=True)
    for p in range(4):
        assert planes[p][57500:57600] == b'\xff' * 100
        assert planes[p][59900:59999] == bytes([255 if p == 3 else 0]) * 99
    for p in range(4): assert planes[p][-1] & 1 == (9 >> p) & 1


def test_vesa_text_pages_and_offscreen_scrolling(dosbox_binary,vesa_build,tmp_path):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT',tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['READ5','VESA','VESATEST pages'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    raw=files['PAGES.BIN'].read_bytes()
    assert len(raw)==9264
    assert struct.unpack_from('<8H',raw,9200)==(7,0x1801,0x2e41,0x2e48,0x2e42,0x2e43,0,0x2e41)
    first=tuple(0x2e41+p for p in range(8))
    assert struct.unpack_from('<8H',raw,9216)==first
    assert struct.unpack_from('<8H',raw,9232)==first
    after=list(first); after[3]=0x2e20  # offscreen page 3 scrolled up
    assert struct.unpack_from('<8H',raw,9248)==tuple(after)
    font=(ROOT/'fonts/HZK16').read_bytes(); off=((0xd6-0xa1)*94+0xd0-0xa1)*32
    for plane in range(4):
        for half in range(2):
            bits=native_rows(0xd6d0,half)
            expected=colored_rows(bits,10,23,0x1e,plane)
            assert plane_bits(raw[plane*2300:(plane+1)*2300],100,(20+half)*10,0,10,23)==expected


@pytest.mark.parametrize('mode,plane_bytes', [('102',60000),('104',98304),('106',163840)])
def test_scroll_pixels_match_complete_redraw(dosbox_binary,vesa_build,tmp_path,mode,plane_bytes):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    keyboard_config(tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['READ5','CKBD /E',f'VESA /M:{mode}','VESATEST scroll'],
                  settings='\n[dosbox]\nmachine=svga_s3\n',timeout=120)
    raw=files['SCROLL.BIN'].read_bytes()
    operations=[(False,1,0,24,0,79),(True,3,0,24,0,79),
                (False,2,3,20,0,79),(True,1,3,20,0,79),
                (False,1,3,20,5,74),(False,25,0,24,0,79)]
    capture_size=4000+4*plane_bytes
    size=4000+2*capture_size
    assert len(raw)==len(operations)*size
    for step,(down,count,top,bottom,left,right) in enumerate(operations):
        record=raw[step*size:(step+1)*size]
        before=struct.unpack_from('<2000H',record)
        expected=list(before)
        for row in range(top,bottom+1):
            source=row-count if down else row+count
            for col in range(left,right+1):
                expected[row*80+col]=before[source*80+col] if top<=source<=bottom else 0x1e20
        assert struct.unpack_from('<2000H',record,4000)==tuple(expected),step
        # Every pixel, including bank edges, margins and the IME strip.
        assert record[4000:4000+capture_size]==record[4000+capture_size:],step


def test_ckbd_help_keeps_streamed_hanzi(dosbox_binary,vesa_build,tmp_path,pytestconfig):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    keyboard_config(tmp_path)
    shot=pytestconfig.getoption('--screenshots')
    files=run_dos(dosbox_binary,tmp_path,['READ5','CKBD /E','VESA','CKBD /?','VESATEST screen'],
                  settings='\n[dosbox]\nmachine=svga_s3\n',physical_keys=shot,screenshots=shot)
    raw=files['SCREEN.BIN'].read_bytes()
    text=raw[:4000];chars=text[::2]
    title='汉字系统键盘模块'.encode('gb2312')
    assert chars.count(title)==1
    start=chars.index(title)
    for i in range(0,len(title),2):
        code=int.from_bytes(title[i:i+2],'big')
        for half in (0,1):
            cell=start+i+half;row,col=divmod(cell,80)
            for p in range(4):
                plane=raw[4000+p*60000:4000+(p+1)*60000]
                assert plane_bits(plane,100,col*10,row*23,10,23)==colored_rows(
                    native_rows(code,half),10,23,text[cell*2+1],p)


def test_vesa_one_image_aperture_or_clean_rejection(dosbox_binary,vesa_build,tmp_path):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT',tmp_path)
    screen=blank(); put(screen,24,78,'中'.encode('gb2312'),0x1e)
    (tmp_path/'INPUT.BIN').write_bytes(bytes([3])+bytes(screen))
    files=run_dos(dosbox_binary,tmp_path,['READ5','VESACAPS',('VESA > VESA.LOG',(0,1)),
                  'VESATEST fallback'],settings='\n[dosbox]\nmachine=svga_s3\n')
    info=files['FALLBACK.BIN'].read_bytes(); assert len(info)==40
    regs=struct.unpack_from('<10H',info)
    if regs[0]!=0x5356:
        # A strict 64 KiB aperture cannot expose B800 without a spare bank.
        assert b'VESA needs' in files['VESA.LOG'].read_bytes()
        assert struct.unpack_from('<H',info,20)[0]==0x5003
        assert 'VESA00.BIN' not in files
        return
    assert regs[4]==0
    raw=files['VESA00.BIN'].read_bytes(); assert raw[28:4028]==screen
    font=(ROOT/'fonts/HZK16').read_bytes(); off=((0xd6-0xa1)*94+0xd0-0xa1)*32
    for plane in range(4):
        for half in range(2):
            glyph=native_rows(0xd6d0,half)
            expected=colored_rows(glyph,10,23,0x1e,plane)
            data=raw[4028+plane*60000:4028+(plane+1)*60000]
            assert plane_bits(data,100,(78+half)*10,24*23,10,23)==expected


@pytest.mark.parametrize('storage',['xms','ems'])
def test_native_font_storage_banks_and_cursor(dosbox_binary,vesa_build,tmp_path,storage,pytestconfig):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    shutil.copy2(ROOT/'fonts/HH20.FNT',tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['READ2','VESA','VESATEST fonts'],
                  physical_keys=pytestconfig.getoption('--screenshots'),
                  screenshots=pytestconfig.getoption('--screenshots'),
                  settings='\n[dosbox]\nmachine=svga_s3\n[dos]\nxms='+('true' if storage=='xms' else 'false')+'\nems=true\n')
    raw=files['FONT20.BIN'].read_bytes()
    assert len(raw)==20+4*4*2300
    regs=struct.unpack_from('<10H',raw)
    payload = len((ROOT/'fonts/HH20.FNT').read_bytes())-32
    assert (regs[0],regs[1],regs[2],regs[3],regs[5],regs[6]) == (
        0x4632, 1 if storage=='xms' else 2, (payload+1023)//1024, 0, 10, 23)
    frames=[raw[20+i*9200:20+(i+1)*9200] for i in range(4)]
    for traditional in (False,True):
        frame=frames[int(traditional)]
        for p in range(4):
            for half in range(2):
                expected=colored_rows(native_rows(0xbaba,half,traditional),10,23,0x1e,p)
                assert plane_bits(frame[p*2300:(p+1)*2300],100,(78+half)*10,0,10,23)==expected
    assert frames[3]==frames[1], 'two cursor XORs must restore every framebuffer bit'
    for p in range(4):
        for y in range(23):
            for x in range(800):
                byte=p*2300+y*100+x//8
                changed=(frames[2][byte]^frames[1][byte]) >> (7-x%8) & 1
                assert changed==int(x>=790 and y<20), (p,x,y)
