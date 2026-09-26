"""Resident font services while other DOS clients own EMS/extended memory."""
import os
import json
import shutil
import subprocess
from pathlib import Path

import pytest

from qa.spec.dos import ROOT, digest, run_dos
from qa.spec.test_dos_display import guest_build
from qa.spec.test_memory import Arena, memory_build
from qa.spec.test_application import keyboard_config

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def real_client(tmp_path_factory):
    out = tmp_path_factory.mktemp('real-client') / 'CLIENT.COM'
    p = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/memclient.c', str(out)],
                       cwd=ROOT, capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    return out


@pytest.fixture(scope='session', params=['dos4g', 'dos32a', 'causeway', 'pmodew'])
def protected_client(request, tmp_path_factory):
    system = request.param
    env = dict(os.environ)
    prefix = Path(env['WATCOM']) if env.get('WATCOM') else None
    if prefix:
        env['PATH'] = os.pathsep.join(str(prefix / p) for p in ('binl64', 'binl', 'binw')) + os.pathsep + env['PATH']
        env.setdefault('INCLUDE', str(prefix / 'h'))
    compiler = shutil.which('wcl386', path=env['PATH'])
    assert compiler, '32-bit extender tests require Open Watcom wcl386 (PATH or WATCOM)'
    out = tmp_path_factory.mktemp('client-'+system)
    p = subprocess.run([compiler, '-y', '-q', '-bt=dos', '-l='+system, '-fe=CLIENT.EXE',
                        str(ROOT / 'qa/harness/memclient.c')], cwd=out, env=env,
                       capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    if system == 'dos4g':
        runtime = next((Path(p) / 'dos4gw.exe' for p in env['PATH'].split(os.pathsep)
                        if (Path(p) / 'dos4gw.exe').is_file()), None)
        assert runtime and runtime.is_file(), 'DOS/4GW tests need WATCOM/binw/dos4gw.exe'
        shutil.copy2(runtime, out / 'DOS4GW.EXE')
    return out


@pytest.fixture(scope='session', params=['cwsdpmi', 'hdpmi32'])
def dpmi_client(request, pytestconfig, tmp_path_factory):
    name = request.param
    host = pytestconfig.getoption('--'+name)
    if host is None:
        pytest.skip('configure --'+name+' to test this external DPMI host')
    host = host.resolve()
    assert host.is_file(), host
    cc = shutil.which(pytestconfig.getoption('--djgpp-cc'))
    assert cc, 'external DPMI host tests require --djgpp-cc or DJGPP_CC'
    out = tmp_path_factory.mktemp('client-'+name)
    p = subprocess.run([cc, '-O2', '-Wall', '-o', str(out / 'CLIENT.EXE'),
                        str(ROOT / 'qa/harness/memclient.c')], capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    shutil.copy2(host, out / (name.upper()+'.EXE'))
    return name, out


def prepare(directory, memory_build, client_build):
    for file in (*memory_build.glob('*.COM'), *client_build.glob('*.EXE')):
        shutil.copy2(file, directory)
    font = (ROOT / 'fonts/HZK16').read_bytes()
    (directory / 'HZK16').write_bytes(font)
    (directory / 'HZK16F').write_bytes(bytes(b ^ 255 for b in font))
    keyboard_config(directory)
    (directory / 'client.json').write_text(json.dumps({
        p.name: digest(p) for p in directory.glob('*.EXE')}, indent=2)+'\n')


def assert_reclaimed(before, freed):
    assert (freed.xms, freed.ems, freed.occupied(), freed.occupied(True), freed.vectors) == (
            before.xms, before.ems, before.occupied(), before.occupied(True), before.vectors)


def assert_client(files, reader, protected=False):
    report = files['CLIENT.TXT'].read_text()
    assert 'FAIL' not in report
    assert f'ALLOCATED {2*1024*1024 if protected else 16384}\n' in report
    assert 'MEMORY_BAD 0\n' in report
    assert int(next(line.split()[1] for line in report.splitlines() if line.startswith('TICKS '))) >= 32
    if protected:
        assert report.startswith('DPMI ')
    assert files['PAGES.BIN'].read_bytes() == b''.join(bytes([0x31+i])*128 for i in range(4))*2
    if reader:
        font = (ROOT / 'fonts/HZK16').read_bytes()
        expected = b''
        for pass_ in range(64):
            for hi, lo in ((0xd6, 0xd0), (0xb9, 0xfa), (0xc4, 0xe3)):
                offset = ((hi-0xa1)*94 + lo-0xa1)*32
                glyph = font[offset:offset+32]
                expected += glyph if pass_ & 1 else bytes(b ^ 255 for b in glyph)
        assert files['CLIENT.BIN'].read_bytes() == expected


@pytest.mark.parametrize('reader', [None, 'READ4', 'READ5'])
def test_real_client_ems_mapping(dosbox_binary, memory_build, real_client, tmp_path, reader):
    for file in memory_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(real_client, tmp_path)
    font = (ROOT / 'fonts/HZK16').read_bytes()
    (tmp_path / 'HZK16').write_bytes(font)
    (tmp_path / 'HZK16F').write_bytes(bytes(b ^ 255 for b in font))
    commands = ['MEMORY BEFORE.TXT']
    if reader:
        commands += [reader+' JF']
    commands += ['CLIENT ems'+(' bare' if reader is None else '')+' > CLIENT.LOG']
    if reader:
        commands += ['MEMORY off']
    files = run_dos(dosbox_binary, tmp_path, commands+['MEMORY FREE.TXT'])
    assert_client(files, reader)
    before, freed = (Arena(files[n+'.TXT']) for n in ('BEFORE', 'FREE'))
    assert (freed.xms, freed.ems, freed.occupied(), freed.occupied(True)) == (
            before.xms, before.ems, before.occupied(), before.occupied(True))


def test_ems_install_preserves_mapping(dosbox_binary, memory_build, real_client, tmp_path):
    prepare(tmp_path, memory_build, tmp_path)
    shutil.copy2(real_client, tmp_path)
    files = run_dos(dosbox_binary, tmp_path, ['MEMORY BEFORE.TXT', 'CLIENT mapped',
                    'READ4 JF', 'CLIENT inherited', 'MEMORY off', 'MEMORY FREE.TXT'])
    assert_client(files, 'READ4')
    assert_reclaimed(*(Arena(files[n+'.TXT']) for n in ('BEFORE', 'FREE')))


@pytest.mark.parametrize('reader', [None, 'READ4', 'READ5'])
def test_protected_client(dosbox_binary, memory_build, real_client, protected_client, tmp_path, reader):
    prepare(tmp_path, memory_build, protected_client)
    shutil.copy2(real_client, tmp_path / 'RESERVE.COM')
    commands = ['MEMORY BEFORE.TXT']
    if reader:
        commands += [reader+' JF', 'VGA', 'CKBD']
    # Some extenders reserve the remaining pool at startup. Allocate the
    # competing EMS client's handle before handing control to the extender.
    commands += ['RESERVE reserve', 'CLIENT ems'+(' bare' if reader is None else '')+' > CLIENT.LOG']
    if reader:
        commands += ['MEMORY off']
    files = run_dos(dosbox_binary, tmp_path, commands+['MEMORY FREE.TXT'])
    assert_client(files, reader, protected=True)
    before, freed = (Arena(files[n+'.TXT']) for n in ('BEFORE', 'FREE'))
    assert_reclaimed(before, freed)


@pytest.mark.parametrize('reader', [None, 'READ4', 'READ5'])
def test_external_dpmi_host(dosbox_binary, memory_build, real_client, dpmi_client, tmp_path, reader):
    name, client = dpmi_client
    prepare(tmp_path, memory_build, client)
    shutil.copy2(real_client, tmp_path / 'RESERVE.COM')
    host = name.upper()
    commands = ['MEMORY START.TXT', (host+(' -p' if name == 'cwsdpmi' else ' -r')+' > HOST.LOG',
                                    0 if name == 'cwsdpmi' else (0, 2)),
                'RESERVE reserve', 'CLIENT ems bare > WARM.LOG', 'MEMORY BEFORE.TXT']
    if reader:
        commands += [reader+' JF', 'VGA', 'CKBD']
    commands += ['RESERVE reserve', 'CLIENT ems'+(' bare' if reader is None else '')+' > CLIENT.LOG']
    if reader:
        commands += ['MEMORY off']
    commands += ['MEMORY FREE.TXT', host+' -u', 'MEMORY END.TXT']
    files = run_dos(dosbox_binary, tmp_path, commands)
    assert_client(files, reader, protected=True)
    start, before, freed, end = (Arena(files[n+'.TXT']) for n in ('START', 'BEFORE', 'FREE', 'END'))
    assert_reclaimed(before, freed)
    assert_reclaimed(start, end)


@pytest.mark.parametrize('xms,ems', [(True, False), (False, True)])
def test_raw_reader_rejects_managed_memory(dosbox_binary, memory_build, tmp_path, xms, ems):
    for file in memory_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    files = run_dos(dosbox_binary, tmp_path, ['MEMORY BEFORE.TXT',
                    ('READ6 > READER.LOG', 1), 'MEMORY FREE.TXT'], settings=(
        f'\n[dos]\nxms={str(xms).lower()}\nems={str(ems).lower()}\n'))
    assert b'REQUIRES UNMANAGED MEMORY' in files['READER.LOG'].read_bytes()
    assert_reclaimed(*(Arena(files[n+'.TXT']) for n in ('BEFORE', 'FREE')))


def test_raw_reader_rejects_dpmi_host(dosbox_binary, memory_build, dpmi_client, tmp_path):
    name, client = dpmi_client
    prepare(tmp_path, memory_build, client)
    host = name.upper()
    files = run_dos(dosbox_binary, tmp_path, [host+(' -p' if name == 'cwsdpmi' else ' -r'),
                    'MEMORY BEFORE.TXT', ('READ6 > READER.LOG', 1), 'MEMORY FREE.TXT', host+' -u'],
                    settings='\n[dos]\nxms=false\nems=false\n')
    assert b'REQUIRES UNMANAGED MEMORY' in files['READER.LOG'].read_bytes()
    assert_reclaimed(*(Arena(files[n+'.TXT']) for n in ('BEFORE', 'FREE')))
