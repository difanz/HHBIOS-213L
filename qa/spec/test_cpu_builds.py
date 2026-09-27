"""Install the actual CPU variants and reject them safely on older machines."""
import shutil

import pytest

from qa.spec.build import build_mixed, source_file
from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_memory import Arena, memory_build

pytestmark = pytest.mark.dos


@pytest.fixture(scope='module', params=['8086', '386', '586'])
def cpu_modules(request, assembler, source_dir, tmp_path_factory):
    output = tmp_path_factory.mktemp('cpu-'+request.param)
    for name in ('CKBD', 'VGA', 'EGA', 'HGA'):
        build_mixed(source_file(source_dir, name+'.ASM'), output/(name+'.COM'),
                    source_dir, assembler, request.param)
    return request.param, output


def prepare(directory, cpu_modules, memory_build):
    cpu, binaries = cpu_modules
    for name in ('READ2', 'MEMORY', 'SNAPSHOT'):
        shutil.copy2(memory_build/(name+'.COM'), directory)
    for name in ('CKBD', 'VGA', 'EGA', 'HGA'):
        shutil.copy2(binaries/(name+'.COM'), directory)
    shutil.copy2(ROOT/'fonts/HZK16', directory)
    keyboard_config(directory)
    return cpu


@pytest.mark.parametrize('driver,machine,identifier', [
    ('VGA', 'vgaonly', b'V\0'), ('EGA', 'ega', b'E\0'), ('HGA', 'hercules', b'H\0'),
])
def test_cpu_variant_installs_draws_and_unloads(cpu_modules, memory_build,
                                              dosbox_binary, tmp_path, driver, machine, identifier):
    cpu = prepare(tmp_path, cpu_modules, memory_build)
    native_cpu = {'8086': '8086', '386': '386', '586': 'pentium'}[cpu]
    files = run_dos(dosbox_binary, tmp_path,
                    ['MEMORY BEFORE.TXT', 'READ2', 'CKBD /E', driver,
                     'SNAPSHOT api', 'MEMORY LIVE.TXT', 'MEMORY off', 'MEMORY AFTER.TXT'],
                    settings=f'\n[dosbox]\nmachine={machine}\n[cpu]\ncputype={native_cpu}\n')
    before, live, after = (Arena(files[name+'.TXT']) for name in ('BEFORE', 'LIVE', 'AFTER'))
    assert live.vectors[0x10] != before.vectors[0x10]
    assert live.vectors[0x16] != before.vectors[0x16]
    assert files['API.BIN'].read_bytes()[8:10] == identifier
    assert after.vectors == before.vectors
    assert (after.occupied(), after.occupied(True), after.xms, after.ems) == (
        before.occupied(), before.occupied(True), before.xms, before.ems)


@pytest.mark.parametrize('native_cpu', ['8086', '286'])
def test_cpu_variant_rejects_older_cpu_without_hooks(cpu_modules, memory_build,
                                                  dosbox_binary, tmp_path, native_cpu):
    cpu = prepare(tmp_path, cpu_modules, memory_build)
    if cpu == '8086':
        pytest.skip('8086 build has no minimum-386 check')
    files = run_dos(dosbox_binary, tmp_path,
                    ['MEMORY BEFORE.TXT', ('CKBD > CKBD.LOG', 1),
                     ('VGA > VGA.LOG', 1), 'MEMORY AFTER.TXT'],
                    settings=f'\n[cpu]\ncputype={native_cpu}\n')
    for name in ('CKBD', 'VGA'):
        assert b'requires a 386' in files[name+'.LOG'].read_bytes()
    before, after = (Arena(files[name+'.TXT']) for name in ('BEFORE', 'AFTER'))
    assert before.vectors == after.vectors
    assert (before.occupied(), before.occupied(True)) == (after.occupied(), after.occupied(True))
