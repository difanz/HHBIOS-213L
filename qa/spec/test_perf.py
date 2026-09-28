"""DOS timing evidence: elapsed guest ticks, not host scheduling or test mocks."""
import shutil
import subprocess
import os
import json
import pytest
from qa.spec.dos import ROOT, run_dos, run_process
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_font20 import sized_font
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_widescreen import HD_SETTINGS


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


@pytest.mark.dos
@pytest.mark.parametrize('mode', ['102', '106'])
def test_msdos_console_output_budget(dosbox_binary, guest_build, msdos_image, tmp_path, mode):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        copy_in(guest_build / name, '::HHBIOS/' + name)
    for path in (ROOT / 'fonts/large').glob('F????.FNT'):
        copy_in(path, '::HHBIOS/' + path.name)
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/perf.c',
                    str(tmp_path / 'PERF.COM')], cwd=ROOT, check=True, capture_output=True)
    copy_in(tmp_path / 'PERF.COM', '::HHBIOS/PERF.COM')
    commands = ['@ECHO OFF', 'CD \\HHBIOS', 'READ5', 'CKBD /E',
                f'VESA /M:{mode}', 'IF ERRORLEVEL 1 GOTO END', 'PERF',
                'IF ERRORLEVEL 1 GOTO END', 'ECHO complete>C:\\DONE.TXT',
                ':END', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = ('[sdl]\noutput=surface\n[dosbox]\nmachine=svga_s3\nmemsize=16\n'
              '[cpu]\ncore=normal\ncycles=30000\n[autoexec]\n'
              f'imgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n')
    (tmp_path / 'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')], tmp_path,
                180, dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('DONE.TXT').strip() == b'complete'
    counts = {key: int(value) for key, value in
              (line.split('=') for line in read('HHBIOS/PERF.TXT').decode().splitlines())}
    (tmp_path / 'timings.json').write_text(json.dumps(counts, indent=2) + '\n')
    print(mode, counts)
    budgets = dict(ASCII_32=4, CHINESE_16=6, DIRECT_2000=18,
                   SCROLL_4=5, DOS_256=22, KEY_POLL_100=2)
    for name, budget in budgets.items():
        assert counts[name] <= budget, counts


@pytest.mark.dos
@pytest.mark.parametrize('width,height,rows', [(800, 600, 25), (1024, 768, 25),
                                             (1280, 1024, 25),
                                             (1280, 1024, 50), (1920, 1080, 25),
                                             (1920, 1080, 50)])
def test_msdos_repeated_paint(dosbox_binary, guest_build, msdos_image, tmp_path,
                             width, height, rows):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM', 'SELECTMD.COM'):
        copy_in(guest_build / name, '::HHBIOS/' + name)
    for path in (ROOT / 'fonts/large').glob('F????.FNT'):
        copy_in(path, '::HHBIOS/' + path.name)
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/paintperf.c',
                    str(tmp_path / 'PAINT.COM')], cwd=ROOT, check=True, capture_output=True)
    copy_in(tmp_path / 'PAINT.COM', '::HHBIOS/PAINT.COM')
    commands = ['@ECHO OFF', 'CD \\HHBIOS', f'SELECTMD {width} {height}',
                'IF ERRORLEVEL 1 GOTO END', 'IF EXIST UNSUP.TXT GOTO END',
                'READ5', 'CKBD /E', 'CALL VMODE.BAT',
                'IF ERRORLEVEL 1 GOTO END', f'PAINT {rows}',
                'IF ERRORLEVEL 1 GOTO END', 'ECHO complete>C:\\DONE.TXT',
                ':END', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = ('[sdl]\noutput=surface\n[dosbox]\nmemsize=16\n'
              '[cpu]\ncore=normal\ncycles=30000\n' + HD_SETTINGS +
              '\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
              f'imgmount c "{image}" -ide 1m\nboot c:\n')
    (tmp_path / 'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')], tmp_path,
                180, dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('DONE.TXT').strip() == b'complete'
    counts = {key: int(value) for key, value in
              (line.split('=') for line in read('HHBIOS/PAINT.TXT').decode().splitlines())}
    (tmp_path / 'timings.json').write_text(json.dumps(counts, indent=2) + '\n')
    print((width, height, rows), counts)
    # Repainting eight complete pages, including every character/attribute;
    # these bounds catch cache thrashing as glyph size and text rows increase.
    budgets = {
        (800, 600, 25): (42, 36, 9),
        (1024, 768, 25): (46, 45, 12),
        (1280, 1024, 25): (42, 42, 14),
        (1280, 1024, 50): (58, 56, 19),
        (1920, 1080, 25): (72, 48, 18),
        (1920, 1080, 50): (64, 65, 21),
    }
    for name, budget in zip(('ASCII_8', 'CHINESE_8', 'SCROLL_16'),
                            budgets[width, height, rows]):
        assert counts[name] <= budget, counts


@pytest.mark.dos
@pytest.mark.parametrize('mode,rows', [('102', 25), ('104', 25), ('242', 25), ('242', 50)])
def test_msdos_status_page_budget(dosbox_binary, guest_build, msdos_image, tmp_path,
                                 mode, rows):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        copy_in(guest_build/name, '::HHBIOS/'+name)
    for path in (ROOT/'fonts/large').glob('F????.FNT'):
        copy_in(path, '::HHBIOS/'+path.name)
    keyboard_config(tmp_path)
    copy_in(tmp_path/'213L.INI', '::HHBIOS/213L.INI')
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/promptperf.c',
                    str(tmp_path/'PRMPERF.COM')], cwd=ROOT, check=True, capture_output=True)
    copy_in(tmp_path/'PRMPERF.COM', '::HHBIOS/PRMPERF.COM')
    commands = ['@ECHO OFF', 'CD \\HHBIOS', 'READ5', 'CKBD /E',
                f'VESA /M:{mode} /R:{rows}', 'IF ERRORLEVEL 1 GOTO END', 'PRMPERF',
                'IF ERRORLEVEL 1 GOTO END', 'ECHO complete>C:\\DONE.TXT',
                ':END', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands)+'\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = ('[sdl]\noutput=surface\n[dosbox]\nmemsize=16\n'
              '[cpu]\ncore=normal\ncycles=30000\n'+HD_SETTINGS+
              '\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
              f'imgmount c "{image}" -ide 1m\nboot c:\n')
    (tmp_path/'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path/'dosbox.conf')], tmp_path,
                180, dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('DONE.TXT').strip() == b'complete'
    counts = {key: int(value) for key, value in
              (line.split('=') for line in read('HHBIOS/PRMPERF.TXT').decode().splitlines())}
    (tmp_path/'timings.json').write_text(json.dumps(counts, indent=2)+'\n')
    print(mode, rows, counts)
    # Real Ctrl+F5 menu paging, status strings and the CKBD title/bitmap writer.
    # A per-byte repaint of the whole row exceeds these by a wide margin.
    for name, budget in dict(CONTROL_FLIPS_4=12, ASCII_PAGES_4=8, HANZI_PAGES_4=10,
                             CKBD_TITLE_8=12, UNCHANGED_64=2).items():
        assert counts[name] <= budget, counts
