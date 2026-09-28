"""Compact CGA geometry through production handlers on an emulated adapter."""
import os
import shutil
import subprocess

import pytest

from qa.spec.build import asm_includes, build_mixed
from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_memory import Arena, memory_build
from qa.spec.test_keymenu_dos import keymenu_build, run_menu_case
from qa.spec.test_msdos import msdos_image

pytestmark = pytest.mark.dos


@pytest.fixture(scope='module')
def cga_build(assembler, source_dir, tmp_path_factory):
    output = tmp_path_factory.mktemp('cga-mode-build')
    env = {key: value for key, value in os.environ.items() if key != 'JWASM'}
    for name in ('CGA', 'CGA11', 'CGA16'):
        result = subprocess.run([assembler, '-q', '-0', '-Zm', '-bin',
                                 *asm_includes(source_dir), '-Fo' + str(output / (name + '.COM')),
                                 str(source_dir / 'video' / (name + '.ASM'))],
                                env=env, capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
    for name in ('EGA', 'HGA'):
        build_mixed(source_dir / 'video' / (name + '.ASM'), output / (name + '.COM'),
                    source_dir, assembler)
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/cgamode.c',
                    str(output / 'CGAMODE.COM')], cwd=ROOT, check=True, capture_output=True)
    return output


@pytest.mark.parametrize('driver', ['CGA11', 'CGA16'])
def test_cga_fallback_preserve_and_boundary_cursor(cga_build, memory_build,
                                                 dosbox_binary, tmp_path, driver):
    for name in ('READ2', 'CKBD', 'MEMORY'):
        shutil.copy2(memory_build / (name + '.COM'), tmp_path)
    for name in (driver, 'CGAMODE'):
        shutil.copy2(cga_build / (name + '.COM'), tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    keyboard_config(tmp_path)
    files = run_dos(dosbox_binary, tmp_path,
                    ['MEMORY BEFORE.TXT', 'READ2', 'CKBD', driver, 'CGAMODE',
                     'MEMORY off', 'MEMORY AFTER.TXT'],
                    settings='\n[dosbox]\nmachine=cga\n[cpu]\ncputype=8086\n')
    assert files['CGAMODE.TXT'].read_text().splitlines() == [
        f'{mode:02X} 0' for mode in (0x12, 0x86, 4, 0x84, 5, 0x85, 6, 0x92)]
    before, after = (Arena(files[name + '.TXT']) for name in ('BEFORE', 'AFTER'))
    assert after.vectors == before.vectors
    assert (after.occupied(), after.occupied(True)) == (before.occupied(), before.occupied(True))


@pytest.mark.parametrize('driver,machine', [
    ('EGA', 'ega'), ('HGA', 'hercules'), ('CGA', 'cga'), ('CGA11', 'cga'), ('CGA16', 'cga'),
])
def test_legacy_physical_menu_cancel_exit_and_reload(cga_build, memory_build, keymenu_build,
                                                    msdos_image, dosbox_binary, tmp_path,
                                                    pytestconfig, driver, machine):
    binaries = tmp_path / 'binaries'
    binaries.mkdir()
    for name in ('READ5', 'CKBD', 'MEMORY'):
        shutil.copy2(memory_build / (name + '.COM'), binaries)
    shutil.copy2(cga_build / (driver + '.COM'), binaries)
    run_menu_case(dosbox_binary, msdos_image, binaries, keymenu_build, tmp_path,
                  pytestconfig, driver, True, 'bios', machine)
