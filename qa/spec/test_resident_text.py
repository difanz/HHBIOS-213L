"""Standard VGA row selection while the resident Chinese driver owns pixels."""
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, run_dos
from qa.spec.test_direct_video import expected_planes
from qa.spec.test_dos_display import guest_build
from qa.spec.test_text_modes import textmode_build
from qa.spec.test_vesa import vesa_build

pytestmark=pytest.mark.dos


@pytest.mark.parametrize('storage',['xms','ems'])
def test_font_switch_preserves_all_text_pages(dosbox_binary,guest_build,tmp_path,storage):
    for p in guest_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    p=subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/rowguard.c',str(tmp_path/'ROWGUARD.COM')],
                     cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    files=run_dos(dosbox_binary,tmp_path,['READ5' if storage=='xms' else 'READ4','VESA','ROWGUARD'],timeout=90,
                  settings='\n[dosbox]\nmachine=svga_s3\n'+('\n[dos]\nxms=false\nems=true\n' if storage=='ems' else ''))
    raw=files['ROWGUARD.BIN'].read_bytes()
    assert len(raw)==48
    for n,(rows,height) in enumerate(((43,8),(50,8),(25,16),(28,14))):
        assert struct.unpack_from('<6H',raw,n*12)==(rows,height,0,height,rows-1,1)
    assert struct.unpack('<8H',files['ROWBACK.BIN'].read_bytes())==(0x004f,0x5003,25,16,4096,16,639,199)


@pytest.fixture(scope='session')
def mouseview_build(tmp_path_factory):
    out=tmp_path_factory.mktemp('mouseview')/'MOUSEVW.COM'
    p=subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/mouseview.c',str(out),
                      'qa/harness/mouseview.asm'],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    return out


@pytest.mark.parametrize('rows',[25,43,50])
def test_resident_vga_rows_and_mouse(dosbox_binary,guest_build,textmode_build,tmp_path,pytestconfig,rows):
    for p in guest_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    shutil.copy2(textmode_build,tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    text=bytearray(b' \x17'*(80*rows)); pairs={}
    for row,col in ((0,0),(0,78),(rows-1,0),(rows-1,78),(rows-2,37)):
        text[(row*80+col)*2:(row*80+col)*2+4]=b'\xd6\x1e\xd0\x4f'
        pairs[row,col]=(0xd6d0,0); pairs[row,col+1]=(0xd6d0,1)
    (tmp_path/'INPUT.BIN').write_bytes(b'\1'+text)
    shots=pytestconfig.getoption('--screenshots')
    files=run_dos(dosbox_binary,tmp_path,['SNAPSHOT font','READ5','VESA',f'TEXTMODE {rows} audit','SNAPSHOT'],
        settings='\n[dosbox]\nmachine=svga_s3\n',timeout=90,physical_keys=shots,screenshots=shots)
    raw=files['TEXTMODE.BIN'].read_bytes(); bda=raw[20:]
    assert bda[0x84]+1==rows and struct.unpack_from('<H',bda,0x4a)[0]==80
    assert struct.unpack_from('<H',bda,0x85)[0]==(16 if rows==25 else 8)
    stride=4096 if rows==25 else 8192
    assert struct.unpack_from('<H',bda,0x4c)[0]==stride
    pages=files['PAGES.BIN'].read_bytes()
    assert struct.unpack_from('<4H',pages)==(80,rows,stride,32768//stride)
    for p in range(32768//stride):
        record=struct.unpack_from('<8H',pages,8+p*16)
        assert record[:6]==(p,p,p*stride,stride,1,0)
    mouse=files['MOUSE.BIN'].read_bytes()
    values=[struct.unpack_from('<10H',mouse,i*20) for i in range(5)]
    assert values[0][0]==0xffff
    assert [v[2:4] for v in values[1:]]==[(632,(rows-1)*8)]*2+[(0,0),(8,16)]
    shot=Snapshot.read(files['SNAP00.BIN'])
    assert (shot.columns,shot.rows)==(80,rows) and shot.text==text
    assert shot.planes==expected_planes(shot,text,pairs,files['FONT.BIN'].read_bytes())
    if shots:
        from subprocess import check_output
        captures=json.loads(files['SCREENSHOTS.JSON'].read_text())
        capture=captures[-1]
        shot.save_ppm(tmp_path/'expected.ppm')
        actual=check_output(['convert',str(tmp_path/capture['file']),'-depth','8','rgb:-'])
        expected=(tmp_path/'expected.ppm').read_bytes().split(b'\n',3)[3]
        quantized={80:85,84:85,168:170,248:255,252:255}
        dac=bytes(quantized.get(v,v) for v in range(256))
        assert actual.translate(dac)==expected.translate(dac)


@pytest.mark.parametrize('rows,style',[(25,'software'),(50,'software'),(50,'hardware'),(50,'excluded')])
def test_physical_mouse_callback_and_cursor(dosbox_binary,vesa_build,textmode_build,mouseview_build,tmp_path,rows,style):
    for p in vesa_build.glob('*.COM'): shutil.copy2(p,tmp_path)
    for p in (textmode_build,mouseview_build): shutil.copy2(p,tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    text=bytearray(b' \x17'*(80*rows)); pairs={}
    row,col=rows-2,78
    text[(row*80+col)*2:(row*80+col)*2+4]=b'\xd6\x1e\xd0\x4f'
    pairs[row,col]=(0xd6d0,0); pairs[row,col+1]=(0xd6d0,1)
    (tmp_path/'INPUT.BIN').write_bytes(b'\1'+text)
    files=run_dos(dosbox_binary,tmp_path,['SNAPSHOT font','READ5','VESA',f'TEXTMODE {rows}',
                      'VESATEST stateall','SNAPSHOT',f'MOUSEVW {style}','SNAPSHOT'],timeout=100,physical_keys=True,screenshots=True,
                      settings='\n[dosbox]\nmachine=svga_s3\n[sdl]\nautolock=false\n')
    state=files['RETURN.BIN'].read_bytes()
    assert all(struct.unpack_from('<H',state,n*20)[0]==0x004f for n in range(4))
    assert struct.unpack('<6H',files['STATEPAL.BIN'].read_bytes())[3:]==(7,15,23)
    raw=files['MOUSELOG.BIN'].read_bytes()
    assert struct.unpack_from('<H',raw)[0]==32768,'native cursor or callback changed text memory'
    for n in range(3):
        regs=struct.unpack_from('<10H',raw,2+n*20)
        assert regs[2:4]==(col*8,row*8),(n,regs)
    count,=struct.unpack_from('<H',raw,62)
    records=[struct.unpack_from('<4H',raw,64+n*8) for n in range(count)]
    assert any(r[0]&2 for r in records) and any(r[0]&4 for r in records),records
    assert all(r[2:]==(col*8,row*8) for r in records if r[0]&6),records
    shot=Snapshot.read(files['SNAP00.BIN']); assert shot.text==text and shot.rows==rows
    if style=='software': text[(row*80+col)*2+1]^=0x77
    expected=expected_planes(shot,text,pairs,files['FONT.BIN'].read_bytes())
    if style=='hardware':
        # Logical scanlines 6..7 of the 8-line BIOS cursor cover the bottom
        # quarter of the 20-pixel glyph; use the original foreground color.
        for p,plane in enumerate(expected):
            for y in range(shot.origin_y+row*shot.cell_height+15,
                           shot.origin_y+row*shot.cell_height+20):
                for x in range(shot.origin_x+col*10,shot.origin_x+(col+1)*10):
                    i=y*shot.pitch+x//8; bit=128>>(x&7)
                    plane[i]=(plane[i]&~bit)|(bit if 0x0e&(1<<p) else 0)
    assert shot.planes==expected
    captures=json.loads(files['SCREENSHOTS.JSON'].read_text())
    capture=captures[-1]
    assert (capture['width'],capture['height'])==(shot.width,shot.height)
    shot.save_ppm(tmp_path/'mouse.ppm')
    actual=subprocess.check_output(['convert',str(tmp_path/capture['file']),'-depth','8','rgb:-'])
    rgb=(tmp_path/'mouse.ppm').read_bytes().split(b'\n',3)[3]
    quantized={80:85,84:85,168:170,248:255,252:255}
    dac=bytes(quantized.get(v,v) for v in range(256))
    assert actual.translate(dac)==rgb.translate(dac),'mouse scanout differs from its graphics planes'
