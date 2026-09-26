import os
import json
from pathlib import Path
import shutil
import subprocess

import pytest

from qa.spec.machine import DisplayMachine

ROOT = Path(__file__).resolve().parent


def pytest_addoption(parser):
    parser.addoption('--source-dir', type=Path, default=ROOT / 'src',
                     help='Assemble this source tree (baseline/mutation comparisons).')
    parser.addoption('--dosbox', default=os.environ.get('DOSBOX') or os.environ.get('DOSBOX_X', 'dosbox'),
                     help='DOSBox executable name or path; defaults to DOSBOX or dosbox on PATH.')
    parser.addoption('--tvedit', type=Path,
                     default=Path(os.environ.get('TVEDIT_ARCHIVE', ROOT / 'qa/.cache/tvision/tvedit-dos.zip')),
                     help='Path to the tvedit regression fixture archive.')


@pytest.fixture(scope='session')
def dosbox_binary(pytestconfig):
    name = pytestconfig.getoption('--dosbox')
    path = shutil.which(name)
    assert path, f'DOSBox not found: {name}; set DOSBOX or --dosbox to its executable'
    return Path(path).resolve()


@pytest.fixture(scope='session')
def assembler():
    name = os.environ.get('JWASM', 'jwasm')
    path = shutil.which(name)
    cached = ROOT / 'qa/.cache/JWasm/build/GccUnixR/jwasm'
    if path is None and 'JWASM' not in os.environ and cached.is_file():
        path = str(cached)
    if path is None:
        pytest.fail(f'JWasm not found: {name}; see the pinned assembler setup in README.md', pytrace=False)
    return path


@pytest.fixture(scope='session')
def source_dir(pytestconfig):
    return pytestconfig.getoption('--source-dir').resolve()


@pytest.fixture(scope='session')
def display_binary(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('assembly') / 'display.com'
    result = subprocess.run([assembler, '-q', '-Zm', '-bin', f'-I{source_dir}',
                    f'-Fo{out}', str(ROOT / 'qa/harness/display.asm')],
                   capture_output=True,
                   env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    log = result.stdout + result.stderr
    (out.parent / 'assembler.log').write_bytes(log)
    assert result.returncode == 0 and b'Error A' not in log, log.decode('utf-8', errors='backslashreplace')
    return out.read_bytes()


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    report = (yield).get_result()
    if report.when == 'call':
        item.test_failed = report.failed


@pytest.fixture
def machine(display_binary, request, tmp_path):
    machine = DisplayMachine(display_binary)
    yield machine
    if getattr(request.node, 'test_failed', False):
        from qa.spec.machine import CODE, SCREEN
        (tmp_path / 'input.bin').write_bytes(getattr(machine, 'input', b''))
        (tmp_path / 'b800.bin').write_bytes(machine.uc.mem_read(SCREEN, 4000))
        (tmp_path / 'shadow.bin').write_bytes(machine.uc.mem_read(CODE + machine.symbols['shadow'], 4000))
        (tmp_path / 'machine.json').write_text(json.dumps({
            'registers': {name: machine.read(name) for name in ('CS', 'DS', 'ES', 'SS', 'IP', 'SP', 'AX', 'BX', 'CX', 'DX', 'SI', 'DI')},
            'draws': machine.draws, 'writes': machine.writes, 'rendered_cells': machine.pixels,
        }, indent=2) + '\n')
