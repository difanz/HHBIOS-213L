"""DOS timing evidence: elapsed guest ticks, not host scheduling or test mocks."""
import shutil
import subprocess
import pytest
from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_font20 import sized_font


@pytest.mark.dos
@pytest.mark.parametrize('display',['VGA','VESA','VESA /M:104','VESA /M:106',
                                    'VESA /M:106 /F:LARGE.FNT'])
@pytest.mark.parametrize('core',['normal','auto'])
def test_console_output_budget(dosbox_binary,guest_build,tmp_path,display,core):
    for name in ('READ5','CKBD',display.split()[0]): shutil.copy2(guest_build/f'{name}.COM',tmp_path)
    for name in ('HZK16','HH20.FNT'):shutil.copy2(ROOT/'fonts'/name,tmp_path)
    keyboard_config(tmp_path)
    large = '/F:' in display
    if large:
        (tmp_path/'LARGE.FNT').write_bytes(sized_font(16,39))
    result=subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/perf.c',
                          str(tmp_path/'PERF.COM')],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stdout+result.stderr
    files=run_dos(dosbox_binary,tmp_path,['READ5','CKBD /E',display,'PERF'],timeout=180,
                  settings=f'\n[dosbox]\nmachine=svga_s3\n[cpu]\ncore={core}\ncycles=30000\n')
    counts=dict(line.split('=') for line in files['PERF.TXT'].read_text().splitlines())
    # Fixed guest instruction budget; never equate DOSBox cycles to CPU MHz.
    # Bounds allow timer phase variation, but reject a redraw of 80 glyphs
    # for each ASCII byte or a full font redraw for every line scrolled.
    budgets = dict(ASCII_32=3,CHINESE_16=4,DIRECT_2000=8,
                   SCROLL_4=3,DOS_256=15,KEY_POLL_100=2)
    if large:
        budgets.update(ASCII_32=4,CHINESE_16=6,DIRECT_2000=18,SCROLL_4=5,DOS_256=22)
    for name,budget in budgets.items():
        assert int(counts[name])<=budget,counts
