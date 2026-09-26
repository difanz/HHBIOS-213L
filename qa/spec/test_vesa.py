"""Independent VESA.COM: actual 800x600 planar pixels and DOS interfaces."""
import shutil
import os
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
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
    assert 0 < abi[5] < 20*1024  # bounded resident data, no full framebuffer copy
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
    text=raw[28:4028]
    assert text==screen
    planes=[raw[4028+p*60000:4028+(p+1)*60000] for p in range(4)]
    font=(ROOT/'fonts/HZK16').read_bytes()
    for row,col,char,attr in [(2,10,'中',0x1e),(2,12,'文',0x1e),(24,78,'字',0xa5)]:
        hi,lo=char.encode('gb2312'); off=((hi-0xa1)*94+lo-0xa1)*32
        bits=font[off:off+32]
        for half in range(2):
            glyph=bits[half::2]+b'\0\0'
            for p in range(4):
                fg=255 if attr & (1 << p) else 0
                bg=255 if (attr >> 4) & (1 << p) else 0
                expected=bytes((b & fg) | ((b ^ 255) & bg) for b in glyph)
                actual=bytes(planes[p][(row*18+y)*100+col+half] for y in range(18))
                assert actual==expected, (row,col,half,p,actual.hex(),expected.hex())


@pytest.mark.parametrize('operation',['text','legacy','state','ports'])
def test_vesa_return_and_register_ownership(dosbox_binary,vesa_build,tmp_path,operation):
    from qa.spec.test_vbe import assert_chinese
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path); keyboard_config(tmp_path)
    screen=blank(); put(screen,2,10,'中文'.encode('gb2312'))
    (tmp_path/'INPUT.BIN').write_bytes(bytes([3])+bytes(screen))
    files=run_dos(dosbox_binary,tmp_path,['READ5','CKBD','VESA','VESATEST '+operation,'SNAPSHOT'],
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
            assert records[2][0]==0x004f and records[2][1] & 0x3fff==0x102
            assert records[3][0]==0x5003


def test_vesa_prompt_bitmap_wide_text_and_pixels(dosbox_binary,vesa_build,tmp_path):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    (tmp_path/'INPUT.BIN').write_bytes(bytes([3])+bytes(blank()))
    files=run_dos(dosbox_binary,tmp_path,['SNAPSHOT font','READ5','VESA','VESATEST drawing','VESATEST'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    data=files['DRAW.BIN'].read_bytes()
    assert struct.unpack_from('<5H',data)==(14,9,1,1,1)
    assert data[10:]==b'\xa5'*64
    raw=files['VESA00.BIN'].read_bytes()
    planes=[raw[4028+p*60000:4028+(p+1)*60000] for p in range(4)]
    def check(col,bits,attr):
        for p in range(4):
            fg=255 if attr & (1 << p) else 0
            bg=255 if (attr >> 4) & (1 << p) else 0
            expected=bytes((b & fg) | ((b ^ 255) & bg) for b in bits)
            assert bytes(planes[p][(456+y)*100+col] for y in range(18))==expected
    for col in range(4):
        check(col,bytes((i*3+7) & 255 for i in range(col*16,col*16+16))+b'\0\0',0x4b)
    font=files['FONT.BIN'].read_bytes(); hzk=(ROOT/'fonts/HZK16').read_bytes()
    off=((0xd6-0xa1)*94+0xd0-0xa1)*32
    glyphs=[font[65*16:66*16],hzk[off:off+32:2],hzk[off+1:off+32:2],font[90*16:91*16]]
    for i,glyph in enumerate(glyphs):
        wide=[sum(((v >> bit) & 1)*3 << (bit*2) for bit in range(8)) for v in glyph]+[0,0]
        check(70+i*2,bytes(v >> 8 for v in wide),0x2e)
        check(71+i*2,bytes(v & 255 for v in wide),0x2e)
        if i==0: check(79,bytes(v >> 8 for v in wide),0x2e)
    check(80,b'\0'*18,0)  # clipped wide glyph must not spill into the margin
    for p in range(4): assert planes[p][-1] & 1 == (9 >> p) & 1


def test_vesa_text_pages_and_offscreen_scrolling(dosbox_binary,vesa_build,tmp_path):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['READ5','VESA','VESATEST pages'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    raw=files['PAGES.BIN'].read_bytes()
    assert len(raw)==7216
    assert struct.unpack_from('<8H',raw,7200)==(7,0x1801,0x2e41,0x2e48,0x2e42,0x2e43,0,0x2e41)
    font=(ROOT/'fonts/HZK16').read_bytes(); off=((0xd6-0xa1)*94+0xd0-0xa1)*32
    for plane in range(4):
        fg=255 if 0xe & (1 << plane) else 0
        bg=255 if 1 & (1 << plane) else 0
        for half in range(2):
            bits=font[off+half:off+32:2]+b'\0\0'
            expected=bytes((b & fg) | ((b ^ 255) & bg) for b in bits)
            assert bytes(raw[plane*1800+y*100+20+half] for y in range(18))==expected


def test_vesa_one_image_aperture_or_clean_rejection(dosbox_binary,vesa_build,tmp_path):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(ROOT/'fonts/HZK16',tmp_path)
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
            glyph=font[off+half:off+32:2]+b'\0\0'
            fg=255 if 14 & (1 << plane) else 0
            bg=255 if 1 & (1 << plane) else 0
            expected=bytes((b & fg) | ((b ^ 255) & bg) for b in glyph)
            assert bytes(raw[4028+plane*60000+(24*18+y)*100+78+half] for y in range(18))==expected
