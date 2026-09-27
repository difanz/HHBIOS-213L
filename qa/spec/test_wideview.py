"""Banked framebuffer experiments; these do not install a text-mode driver."""
import itertools
import hashlib
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
from qa.spec.pixels import native_rows
from qa.spec.test_vesa_api import Surface
from qa.spec.test_vbe import vbe_binary

pytestmark = pytest.mark.dos
PALETTE = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),
           (170,85,0),(170,170,170),(85,85,85),(85,85,255),(85,255,85),
           (85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]


@pytest.fixture(scope='session')
def wideview_build(tmp_path_factory):
    out=tmp_path_factory.mktemp('wideview-build')/'WIDEVIEW.COM'
    p=subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/wideview.c',str(out)],
                     cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0, p.stdout+p.stderr
    return out


def fixture(directory,width,height,cols,rows,scale,bpp):
    """Explicit glyph/attribute cells, not a replacement mixed-text classifier."""
    font=bytearray(8192); glyphs={}; cells=[(32,0x17)]*(cols*(rows+1))
    def place(row,col,text,attr=0x1f):
        for ch in text:
            try: codes=[ch.encode('cp437')[0]]
            except UnicodeEncodeError:
                if ch not in glyphs:
                    first=256+2*len(glyphs); assert first+1<512
                    code=int.from_bytes(ch.encode('gb2312'),'big')
                    left=native_rows(code); right=native_rows(code,1)
                    for y in range(16):
                        bits=((left[y+2]<<10)|right[y+2])>>2
                        font[first*16+y]=bits>>8; font[(first+1)*16+y]=bits&255
                    glyphs[ch]=first
                codes=[glyphs[ch],glyphs[ch]+1]
            if col+len(codes)>cols: break
            for code in codes: cells[row*cols+col]=(code,attr); col+=1
    for row in range(rows):
        place(row,0,'║'); place(row,cols-1,'║')
    place(0,0,'╔'+'═'*(cols-2)+'╗'); place(rows-1,0,'╚'+'═'*(cols-2)+'╝')
    place(0,2,f' HHBIOS VBE EXPERIMENT / {cols}x{rows} / {scale}x ',0x1e)
    place(2,3,f'{width}x{height} / {bpp} bpp / banked real mode',0x1e)
    place(3,3,'中文原生点阵 / English / 宽屏与可变行列研究')
    place(4,3,'Rendering experiment only; no virtual text BIOS installed.',0x1b)
    for row in (6,10,14): place(row,2,'╠'+'═'*(cols-6)+'╣',0x1b)
    place(7,4,'项目 / Item'); place(7,cols//2,'内容 / Value')
    place(9,4,'显示字格'); place(9,cols//2,f'{cols} columns x {rows} rows')
    place(11,4,'中文与西文混排'); place(11,cols//2,'保留笔画，按整数倍放大')
    place(13,4,'字体及颜色'); place(13,cols//2,'简体中文 ABC 0123456789')
    for color in range(16): place(16,2+color*4,f'{color:X}中',color<<4|15)
    for row in range(19,rows-2):
        place(row,3,f'{row+1:02d}  中文文档  ABC 0123456789  '+' '.join(f'{c:03d}' for c in range(40,cols,8)),0x17)
    place(rows-2,3,'最后一行 / last content row',0x1e)
    place(rows-2,cols-3,'字',0x4f)
    place(rows,0,' INPUT / 输入提示行 - 不占用应用文本行 '.ljust(cols),0x70)
    packed=b''.join(struct.pack('<HH',*cell) for cell in cells)
    (directory/'WIDE.IN').write_bytes(b'HHWIDE1\n'+struct.pack('<6H',width,height,cols,rows,scale,bpp)+font+packed)
    return cells


def expected_indices(font,cells,width,height,cols,rows,scale):
    # Construct independent glyph rows, then place them in a centered viewport.
    ox=(width-cols*8*scale)//2; oy=(height-(rows+1)*16*scale)//2
    image=bytearray(width*height)
    for row in range(rows+1):
        for sy in range(16):
            parts=[]
            for code,attr in cells[row*cols:(row+1)*cols]:
                bits=font[code*16+sy]
                parts.extend(bytes([attr&15 if bits&(128>>x) else attr>>4])*scale for x in range(8))
            line=b''.join(parts)
            for dy in range(scale):
                start=(oy+(row*16+sy)*scale+dy)*width+ox
                image[start:start+len(line)]=line
    return image,ox,oy


def color_words(surface,bpp):
    masks=[(surface.red_size,surface.red_pos),(surface.green_size,surface.green_pos),
           (surface.blue_size,surface.blue_pos)]
    return [sum(((c*((1<<bits)-1)+127)//255)<<shift for c,(bits,shift) in zip(rgb,masks))
            for rgb in PALETTE]


def assert_frame(raw,indices,surface,bpp):
    width,height,pitch=surface.width,surface.height,surface.pitch
    if bpp==4:
        assert len(raw)==pitch*height*4
        for plane in range(4):
            expected=bytearray(pitch*height)
            for pos,color in enumerate(indices):
                if color&(1<<plane):
                    y,x=divmod(pos,width); expected[y*pitch+x//8]|=128>>(x%8)
            assert raw[plane*pitch*height:(plane+1)*pitch*height]==expected, plane
    else:
        words=[bytes([c]) for c in range(16)] if bpp==8 else [v.to_bytes(bpp//8,'little') for v in color_words(surface,bpp)]
        expected=b''.join(b''.join(words[c] for c in indices[y*width:(y+1)*width])+
                          bytes(pitch-width*(bpp//8)) for y in range(height))
        assert raw==expected


def assert_scanout(directory,indices,surface,bpp):
    shot,=json.loads((directory/'screenshots.json').read_text())
    assert (shot['width'],shot['height'])==(surface.width,surface.height)
    actual=subprocess.check_output(['convert',str(directory/shot['file']),'-depth','8','rgb:-'])
    # Admit exact bit-depth expansions, not arbitrary per-channel error bars.
    palette={}
    for color,rgb in enumerate(PALETTE):
        sizes=(6,6,6) if bpp<=8 else (surface.red_size,surface.green_size,surface.blue_size)
        channels=[]
        for value,bits in zip(rgb,sizes):
            q=value//4 if bpp<=8 else (value*((1<<bits)-1)+127)//255
            maximum=(1<<bits)-1
            channels.append({q<<(8-bits),q*255//maximum,(q*255+maximum//2)//maximum,
                             (q<<(8-bits))|(q>>(2*bits-8))})
        for variant in itertools.product(*channels):
            assert variant not in palette or palette[variant]==color
            palette[variant]=color
    observed=bytes(palette.get(tuple(actual[i:i+3]),255) for i in range(0,len(actual),3))
    assert observed==indices, 'Actual SDL scanout differs from the requested glyphs/attributes'


@pytest.mark.parametrize('config', [
    (4096,1080,256,25,1,4),    # AH=0F/cursor column contract cannot express 256
    (1920,1440,240,80,1,4),    # pixels fit; the visible B800 image exceeds 32 KiB
    (1280,720,132,50,1,4),     # text plus prompt exceeds the pixel viewport
    (1920,1080,80,25,0,4),     # invalid scale must not become divide-by-zero
])
def test_wide_invalid_geometry_is_not_an_unsupported_mode(dosbox_binary,wideview_build,tmp_path,config):
    shutil.copy2(wideview_build,tmp_path)
    (tmp_path/'WIDE.IN').write_bytes(b'HHWIDE1\n'+struct.pack('<6H',*config)+bytes(8192))
    files=run_dos(dosbox_binary,tmp_path,[('WIDEVIEW',1)],settings='\n[dosbox]\nmachine=svga_s3\n')
    assert files['STATUS.BIN'].read_bytes()==b'\1\0'
    assert 'FRAME.BIN' not in files and 'FONT16.BIN' not in files and 'RESULT.BIN' not in files


@pytest.mark.parametrize('render_error',[False,True])
@pytest.mark.parametrize('previous',[0x101,0x4101])
def test_wide_restores_previous_vbe_mode(dosbox_binary,wideview_build,vbe_binary,tmp_path,render_error,previous):
    shutil.copy2(wideview_build,tmp_path); shutil.copy2(vbe_binary,tmp_path)
    fixture(tmp_path,800,600,80,25,1,8)
    if render_error:
        # Invalid glyph discovered after changing the video mode.
        with (tmp_path/'WIDE.IN').open('r+b') as f:
            f.seek(20+8192); f.write(struct.pack('<H',512))
    files=run_dos(dosbox_binary,tmp_path,[f'VBE set {previous:x}','VBE current 0',
                  'copy CURRENT.BIN BEFORE.BIN',('WIDEVIEW',int(render_error)),
                  'VBE current 0'],settings='\n[dosbox]\nmachine=svga_s3\n')
    assert files['STATUS.BIN'].read_bytes()==struct.pack('<H',int(render_error))
    status,mode=struct.unpack_from('<HH',files['CURRENT.BIN'].read_bytes())
    old_status,old_mode=struct.unpack_from('<HH',files['BEFORE.BIN'].read_bytes())
    assert old_status==status==0x004f and old_mode&0x3fff==previous&0x3fff
    assert mode&0x7fff==old_mode&0x7fff


@pytest.mark.parametrize('width,height,cols,rows,scale,bpp', [
    (800,600,80,25,1,8),
    (1024,768,80,43,1,4), (1280,1024,132,60,1,4), (1280,800,132,43,1,4),
    (1920,1080,80,25,2,4), (1920,1080,132,60,1,4),
    (1920,1080,160,50,1,8), (1920,1080,240,66,1,16),
    (1920,1080,132,50,1,32), (1920,1200,132,60,1,16),
])
def test_banked_wide_framebuffer(dosbox_binary,wideview_build,tmp_path,pytestconfig,
                                 width,height,cols,rows,scale,bpp):
    shutil.copy2(wideview_build,tmp_path)
    cells=fixture(tmp_path,width,height,cols,rows,scale,bpp)
    config=pytestconfig.getoption('--vesa-research-config')
    settings='\n[dosbox]\nmachine=svga_s3\n'
    if config is not None: settings+='\n'+config.read_text()
    settings+='\n[cpu]\ncycles=200000\n'
    shots=pytestconfig.getoption('--screenshots')
    files=run_dos(dosbox_binary,tmp_path,[('WIDEVIEW',(0,77))],timeout=150,settings=settings,
                  physical_keys=shots,screenshots=shots,desktop_size=(max(width,1280),max(height,1024)))
    status,=struct.unpack('<H',files['STATUS.BIN'].read_bytes())
    if status==77:
        # A capability rejection must not be confused with a failed renderer.
        assert 'FRAME.BIN' not in files and 'FONT16.BIN' not in files
        pytest.skip(f'No supported advertised {width}x{height}x{bpp} banked mode')
    assert status==0, f'Guest renderer failed with status {status}; see {tmp_path}'
    raw=files['RESULT.BIN'].read_bytes(); assert len(raw)==62 and raw[:8]==b'HHWIDE1\n'
    s=Surface.from_buffer_copy(raw[8:36]); assert (s.width,s.height,s.bpp)==(width,height,bpp)
    indices,ox,oy=expected_indices(files['FONT16.BIN'].read_bytes(),cells,width,height,cols,rows,scale)
    assert struct.unpack_from('<5H',raw,36)==(cols,rows,scale,ox,oy)
    assert_frame(files['FRAME.BIN'].read_bytes(),indices,s,bpp)
    switches,reads,splits,ticks=struct.unpack_from('<4I',raw,46)
    if s.window_kb%s.granularity_kb==0:
        windows=(s.pitch*height+s.window_kb*1024-1)//(s.window_kb*1024)
        assert switches==windows*(4 if bpp==4 else 1)
    assert switches>1 and reads>1
    if s.window_kb*1024%s.pitch: assert splits>0
    if shots: assert_scanout(tmp_path,indices,s,bpp)
    (tmp_path/'wide.json').write_text(json.dumps(dict(
        role='foreground framebuffer experiment; no text BIOS or application compatibility',
        pixels=[width,height],grid=[cols,rows],scale=scale,bpp=bpp,viewport_origin=[ox,oy],
        vbe_mode=f'{s.mode:03x}',pitch=s.pitch,window_kib=s.window_kb,granularity_kib=s.granularity_kb,
        write_bank_calls=switches,read_bank_calls=reads,split_scanlines=splits,render_bios_ticks=ticks,
        font_sha256=hashlib.sha256(files['FONT16.BIN'].read_bytes()).hexdigest()),indent=2)+'\n')
