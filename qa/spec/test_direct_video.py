"""Foreground B800 stores, with IRQs enabled and no explicit repaint calls."""
import functools
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, run_dos
from qa.spec.machine import put
from qa.spec.pixels import colored_rows, native_rows
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.dos


def scenarios(page):
    screen=bytearray(b' \x17'*2000); pairs={}; result=[]
    def chinese(row,col,text,attr=0x1e):
        encoded=text.encode('gb2312'); put(screen,row,col,encoded,attr)
        for i in range(0,len(encoded),2):
            code=int.from_bytes(encoded[i:i+2],'big')
            pairs[(row,col+i)]=(code,0); pairs[(row,col+i+1)]=(code,1)
    def keep(op,label): result.append((op,label,bytes(screen),dict(pairs)))
    put(screen,0,2,f'DIRECT B800 / IRQ refresh / page {page}'.encode(),0x1f)
    put(screen,1,2,b'No BIOS text output or forced redraw between writes.',0x1b)
    put(screen,2,10,b'AA',0x1e)
    chinese(4,5,'直接写显存')
    chinese(12,25,'中文')
    chinese(24,78,'字',0x4f)
    put(screen,23,79,b'\xd6',0x2e); put(screen,24,0,b'\xd0',0x3f)
    for color in range(16): put(screen,8,2+color*4,f'{color:X}'.encode(),color*16+15)
    keep(0,'word stores')
    screen[2*(2*80+10)]=0xd6
    keep(1,'lead byte only; orphan stays single')
    screen[2*(2*80+11)]=0xd0
    pairs[(2,10)]=(0xd6d0,0); pairs[(2,11)]=(0xd6d0,1)
    keep(1,'trail byte completes Chinese pair')
    screen[2*(2*80+10)+1]=0x3e; screen[2*(2*80+11)+1]=0x4f
    keep(2,'attribute bytes only; independent half colors')
    put(screen,6,4,b'REP MOVSW: application buffer to video memory',0x2f)
    chinese(18,40,'内存复制',0x2f)
    keep(3,'REP MOVSW full page')
    screen=bytearray(screen[160:]+b' \x17'*80)
    pairs={(row-1,col):glyph for (row,col),glyph in pairs.items() if row}
    chinese(24,68,'滚屏末行',0x1e)
    keep(4,'overlapping REP MOVSW scroll and bottom row')
    screen=bytearray(b' \x2e'*2000); pairs={}
    keep(5,'REP STOSW clears the visible page')
    return result


def expected_planes(shot,text,pairs,font):
    """Place known fixture glyphs; no invocation of the production classifier."""
    hzk=(ROOT/'fonts/HZK16').read_bytes()
    @functools.lru_cache(None)
    def bits(code,half,attr,plane):
        if shot.cell_width==10: glyph=native_rows(code,half)
        elif code>255:
            off=((code>>8)-0xa1)*94*32+((code&255)-0xa1)*32
            glyph=hzk[off+half:off+32:2]+b'\0\0'
        else:
            glyph=font[code*16:(code+1)*16]
            glyph+=glyph[-2:] if 0xb0<=code<=0xdf else b'\0\0'
        return colored_rows(glyph,shot.cell_width,shot.cell_height,attr,plane)
    planes=[bytearray(shot.pitch*shot.height) for _ in range(4)]
    for cell in range(len(text)//2):
        row,col=divmod(cell,80); code,half=pairs.get((row,col),(text[cell*2],0))
        x=shot.origin_x+col*shot.cell_width*shot.scale
        for p,out in enumerate(planes):
            for dy,value in enumerate(bits(code,half,text[cell*2+1],p)):
                for sy in range(shot.scale):
                    y=shot.origin_y+(row*shot.cell_height+dy)*shot.scale+sy
                    for dx in range(shot.cell_width):
                        if value & (1<<(shot.cell_width-1-dx)):
                            for sx in range(shot.scale):
                                px=x+dx*shot.scale+sx
                                out[y*shot.pitch+px//8] |= 128>>(px&7)
    return planes


@pytest.mark.parametrize(('display','page'),[
    ('VGA',0),('VGA',5),('VGA',7),('VESA',0),('VESA',7),
    ('VESA /M:104',7),('VESA /M:106',7),
    ('VESA 1920x1080',7),
])
def test_direct_b800_timer_refresh(dosbox_binary,guest_build,tmp_path,pytestconfig,request,display,page):
    for file in guest_build.glob('*.COM'): shutil.copy2(file,tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    frames=scenarios(page)
    (tmp_path/'INPUT.BIN').write_bytes(b''.join(bytes([op])+data for op,_,data,_ in frames))
    shots=pytestconfig.getoption('--screenshots')
    settings='\n[dosbox]\nmachine=svga_s3\n'; desktop=(1280,1024)
    commands=['SNAPSHOT font','READ5']
    if display=='VESA 1920x1080':
        config=pytestconfig.getoption('--vesa-research-config')
        if config is not None: settings+='\n'+config.read_text()
        desktop=(1920,1080)
        commands+=['SELECTMD 1920 1080','call VMODE.BAT',f'if not exist UNSUP.TXT SNAPSHOT direct {page}']
    else: commands+=[display,f'SNAPSHOT direct {page}']
    files=run_dos(dosbox_binary,tmp_path,commands,timeout=150,settings=settings,
                  physical_keys=shots,screenshots=shots,desktop_size=desktop)
    if 'UNSUP.TXT' in files:
        assert 'DIRECT.BIN' not in files and 'SNAP00.BIN' not in files
        pytest.skip('BIOS does not advertise a planar 1920x1080 mode')
    font=files['FONT.BIN'].read_bytes()
    framebuffer,=struct.unpack('<H',files['DIRECT.BIN'].read_bytes())
    # Legacy VGA can alias B800 to A800 in a 64 KiB plane. Its AE020
    # framebuffer then overlaps text pages 6/7. Keep the high-page failure
    # visible; a future fix must remove this strict expected failure.
    alias=display=='VGA' and framebuffer==0xae02
    if alias and page>=6:
        request.node.add_marker(pytest.mark.xfail(strict=True,raises=AssertionError,
            reason='legacy VGA AE020 framebuffer overlaps B800 pages 6/7'))
    screenshots=json.loads(files['SCREENSHOTS.JSON'].read_text()) if shots else []
    if shots: assert len(screenshots)==len(frames)
    memory=b''.join(b' \x07'*2000+struct.pack('<H',0x5a00+i)*48 for i in range(8))
    for n,(_,label,text,pairs) in enumerate(frames):
        shot=Snapshot.read(files[f'SNAP{n:02d}.BIN'])
        assert shot.text==text, label
        expected=memory[:page*4096]+text+memory[page*4096+4000:]
        protected=6*4096 if alias else 32768
        assert files[f'PAGE{n:02d}.BIN'].read_bytes()[:protected]==expected[:protected], (
            label,'other pages or guards changed')
        assert shot.planes==expected_planes(shot,text,pairs,font), (label,'timer did not render direct stores')
        if shots:
            ppm=tmp_path/f'frame{n:02d}.ppm'; shot.save_ppm(ppm)
            capture=screenshots[n]
            assert (capture['width'],capture['height'])==(shot.width,shot.height)
            actual=subprocess.check_output(['convert',str(tmp_path/capture['file']),'-depth','8','rgb:-'])
            rgb=ppm.read_bytes().split(b'\n',3)[3]
            quantized={80:85,84:85,168:170,248:255,252:255}
            dac=bytes(quantized.get(v,v) for v in range(256))
            assert actual.translate(dac)==rgb.translate(dac), (label,'actual window differs')
    (tmp_path/'direct.json').write_text(json.dumps(dict(
        display=display,page=page,grid=[80,25],policy=1,framebuffer_segment=hex(framebuffer),
        pixels=[shot.width,shot.height],viewport=[shot.origin_x,shot.origin_y],
        scale=shot.scale,raster_cell=[shot.cell_width,shot.cell_height],
        protected_text_bytes=protected,interrupts='enabled during all stores',
        refresh='timer only; no per-frame policy, BIOS text output or forced repaint',
        stages=[label for _,label,_,_ in frames]),indent=2)+'\n')
