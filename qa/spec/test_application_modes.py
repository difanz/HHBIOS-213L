"""Observe which existing text modes applications retain or replace at entry."""
import json
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, digest, run_dos
from qa.spec.test_application import install_tvedit
from qa.spec.test_text_modes import textmode_build

pytestmark = pytest.mark.application


@pytest.fixture(scope='session')
def gridcap_build(tmp_path_factory):
    out = tmp_path_factory.mktemp('gridcap-build')/'GRIDCAP.COM'
    p = subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/gridcap.c',str(out),
                        'qa/harness/appcap.asm'],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0, p.stdout+p.stderr
    return out


@pytest.fixture(scope='session')
def native_text_modes(dosbox_binary,textmode_build,tmp_path_factory):
    directory=tmp_path_factory.mktemp('native-mode-catalog')
    shutil.copy2(textmode_build,directory)
    files=run_dos(dosbox_binary,directory,['TEXTMODE'],settings='\n[dosbox]\nmachine=svga_s3\n')
    raw=files['VBELIST.BIN'].read_bytes()
    assert raw[:4]==b'VESA' and len(raw)>=512 and (len(raw)-512)%260==0
    result=set()
    for pos in range(512,len(raw),260):
        mode,status,attributes=struct.unpack_from('<3H',raw,pos)
        if status==0x004f and attributes&17==1:
            result.add(mode)
    return result


@pytest.mark.parametrize('mode', ['50','108','109','10a','10b','10c'])
@pytest.mark.parametrize('editor', ['tvedit','edit2','tc201'])
def test_application_native_grid(pytestconfig,dosbox_binary,textmode_build,gridcap_build,
                                 native_text_modes,tmp_path,mode,editor):
    if not pytestconfig.getoption('--screenshots'):
        pytest.skip('Native grid observations use --screenshots and physical exit keys')
    if int(mode,16)>=0x100 and int(mode,16) not in native_text_modes:
        pytest.skip(f'Native BIOS does not advertise VBE text mode {mode}h')
    for file in (textmode_build,gridcap_build): shutil.copy2(file,tmp_path)
    exits = [0x2d00]
    if editor=='tvedit':
        install_tvedit(pytestconfig,tmp_path); command='TVEDIT.EXE'
    elif editor=='edit2':
        path = pytestconfig.getoption('--msedit2')
        if path is None: pytest.skip('Set --msedit2 to observe MS-DOS Editor 2.x')
        assert path.is_file(), path
        shutil.copy2(path,tmp_path/'EDIT.COM'); command='EDIT.COM'; exits=[0x2100,0x2d78]
    else:
        path = pytestconfig.getoption('--dos-apps')
        if path is None: pytest.skip('Set --dos-apps to observe Turbo C 2.01')
        path = path/'tc201'/'TC.EXE'; assert path.is_file(), path
        shutil.copy2(path,tmp_path/'TC.EXE'); command='TC.EXE'
    original = b'HHBIOS-GRID native text compatibility\r\n'+b'0123456789'*20+b'\r\n'
    (tmp_path/'VIEW.TXT').write_bytes(original)
    (tmp_path/'EXITKEYS.BIN').write_bytes(struct.pack('<'+'H'*len(exits),*exits))
    (tmp_path/'application.json').write_text(json.dumps(dict(editor=editor,command=command,
        files={command:digest(tmp_path/command)}),indent=2)+'\n')
    # The setter records the requested mode before the application can change it.
    # An advertised mode must actually set successfully for this observation.
    files = run_dos(dosbox_binary,tmp_path,['TEXTMODE '+mode,'GRIDCAP '+command+' VIEW.TXT'],
                    timeout=65,physical_keys=True,screenshots=True,
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    before=files['TEXTMODE.BIN'].read_bytes()
    assert int(mode,16)<0x100 or struct.unpack_from('<H',before,10)[0]==0x004f, (
        'Native BIOS advertised the requested mode but failed to select it')
    raw=files['GRID.BIN'].read_bytes()
    cols=struct.unpack_from('<H',raw,0x4a)[0]; rows=raw[0x84]+1
    assert len(raw)==256+cols*rows*2
    assert b'HHBIOS-GRID' in raw[256::2]
    assert files['VIEW.TXT'].read_bytes()==original
    observed=dict(editor=editor,requested_mode=mode,
                  before=[struct.unpack_from('<H',before,20+0x4a)[0],before[20+0x84]+1],
                  during=[cols,rows],bios_mode=raw[0x49],
                  page_bytes=struct.unpack_from('<H',raw,0x4c)[0],
                  font_height=struct.unpack_from('<H',raw,0x85)[0])
    (tmp_path/'grid.json').write_text(json.dumps(observed,indent=2)+'\n')
