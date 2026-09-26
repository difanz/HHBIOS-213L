"""Native BIOS observations for the compatibility design, without HHBIOS.

Unsupported VBE text modes are observations, not successful mode tests.
This does not claim that VESA.COM can render Chinese in these grids yet.
"""
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def textmode_build(tmp_path_factory):
    out = tmp_path_factory.mktemp('textmode-build')/'TEXTMODE.COM'
    p = subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/textmode.c',str(out)],
                       cwd=ROOT,capture_output=True,text=True)
    assert p.returncode == 0, p.stdout+p.stderr
    return out


def test_native_vbe_mode_catalog(dosbox_binary,textmode_build,tmp_path,pytestconfig):
    shutil.copy2(textmode_build,tmp_path)
    config=pytestconfig.getoption('--vesa-research-config')
    settings='\n[dosbox]\nmachine=svga_s3\n'+ ('\n'+config.read_text() if config else '')
    files = run_dos(dosbox_binary,tmp_path,['TEXTMODE'],settings=settings)
    raw = files['VBELIST.BIN'].read_bytes()
    assert raw[:4] == b'VESA' and len(raw)>512 and (len(raw)-512)%260 == 0
    modes = []
    for pos in range(512,len(raw),260):
        mode,status = struct.unpack_from('<HH',raw,pos)
        info = raw[pos+4:pos+260]
        attr,pitch,x,y = (struct.unpack_from('<H',info,p)[0] for p in (0,16,18,20))
        modes.append(dict(mode=f'{mode:03x}',status=f'{status:04x}',attributes=attr,
                          kind='graphics' if attr&16 else 'text',x=x,y=y,
                          cell=list(info[22:24]),pitch=pitch,planes=info[24],bpp=info[25],
                          memory_model=info[27],window_kib=struct.unpack_from('<H',info,6)[0],
                          granularity_kib=struct.unpack_from('<H',info,4)[0]))
    (tmp_path/'modes.json').write_text(json.dumps(dict(
        version=f'{struct.unpack_from("<H",raw,4)[0]:04x}',
        memory_kib=struct.unpack_from('<H',raw,18)[0]*64,modes=modes),indent=2)+'\n')
    assert any(m['kind']=='graphics' and m['status']=='004f' for m in modes)


@pytest.mark.parametrize('mode,cols,rows', [
    ('25',80,25), ('43',80,43), ('50',80,50), ('108',80,60),
    ('109',132,25), ('10a',132,43), ('10b',132,50), ('10c',132,60),
])
def test_native_text_geometry(dosbox_binary,textmode_build,tmp_path,pytestconfig,mode,cols,rows):
    shutil.copy2(textmode_build,tmp_path)
    files = run_dos(dosbox_binary,tmp_path,['TEXTMODE '+mode],
                    physical_keys=pytestconfig.getoption('--screenshots'),
                    screenshots=pytestconfig.getoption('--screenshots'),
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    raw = files['TEXTMODE.BIN'].read_bytes()
    assert len(raw)==276 and raw[:8]==b'HHTEXT1\n'
    request,status,bios_ax,bios_bx,vbe_ax,vbe_bx = struct.unpack_from('<6H',raw,8)
    assert request == int(mode,16)
    if request>=0x100 and status!=0x004f:
        assert 'TEXT.BIN' not in files
        pytest.skip(f'Native BIOS rejects VBE {mode}h with AX={status:04x}; raw result retained')
    bda = raw[20:]
    assert bios_ax>>8 == struct.unpack_from('<H',bda,0x4a)[0] == cols
    assert bda[0x84]+1 == rows
    assert bios_bx>>8 == bda[0x62] == 0
    if request>=0x100:
        assert vbe_ax==0x004f and vbe_bx&0x3fff==request
    text = files['TEXT.BIN'].read_bytes()
    assert len(text)==cols*rows*2
    assert text[:2]==b'\xc9\x1e' and text[-2:]==b'\xbc\x1e'
    assert text[2*(cols-1):2*cols]==b'\xbb\x1e'
    assert text[-2*cols:2-2*cols]==b'\xc8\x1e'
    if pytestconfig.getoption('--screenshots'):
        shot, = json.loads(files['SCREENSHOTS.JSON'].read_text())
        # VGA may double short scanlines. Capture must include the entire grid.
        assert shot['width'] >= cols*8
        assert shot['height'] >= rows*struct.unpack_from('<H',bda,0x85)[0]


@pytest.mark.parametrize('mode', ['25','43','50','108','109','10a','10b','10c'])
def test_native_text_services(dosbox_binary,textmode_build,tmp_path,mode):
    """Retain native inconsistencies as observations; do not normalize them."""
    shutil.copy2(textmode_build,tmp_path)
    files=run_dos(dosbox_binary,tmp_path,['TEXTMODE '+mode+' audit'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    before=files['TEXTMODE.BIN'].read_bytes()
    if int(mode,16)>=0x100 and struct.unpack_from('<H',before,10)[0]!=0x004f:
        assert 'MOUSE.BIN' not in files and 'PAGES.BIN' not in files
        pytest.skip(f'Native BIOS rejects VBE {mode}h')
    mouse=files['MOUSE.BIN'].read_bytes(); assert len(mouse)==100
    regs=[struct.unpack_from('<10H',mouse,i*20) for i in range(5)]
    pages=files['PAGES.BIN'].read_bytes()
    cols,rows,stride,count=struct.unpack_from('<4H',pages)
    assert len(pages)==8+16*count and 0<count<=8
    assert (cols,rows,stride)==(struct.unpack_from('<H',before,20+0x4a)[0],
                               before[20+0x84]+1,struct.unpack_from('<H',before,20+0x4c)[0])
    records=[]
    for i in range(count):
        record=struct.unpack_from('<8H',pages,8+16*i)
        assert record[0]==i and record[4] in (0,1) and record[5]<=cols*rows
        records.append(dict(zip(('request','active','offset','stride','addressable',
                                 'overwritten_words','first','last'),record)))
    observation=dict(mode=mode,grid=[cols,rows],page_bytes=stride,pages=records,
        mouse_present=regs[0][0]==0xffff,
        mouse={name:list(r[2:4]) for name,r in zip(
            ('default_max','custom_max','custom_min','interior_13_21'),regs[1:])})
    (tmp_path/'services.json').write_text(json.dumps(observation,indent=2)+'\n')
