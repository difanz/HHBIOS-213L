"""Resolve production modules and include paths in source-tree copies."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def build_mixed(source, output, source_root, assembler, cpu='8086', common=()):
    result = subprocess.run(['bash', str(ROOT / 'tools/build-module.sh'),
                             str(source), str(output), str(source_root), cpu, *common],
                            capture_output=True, env=dict(os.environ, JWASM=assembler))
    assert result.returncode == 0, result.stdout + result.stderr
    return output.read_bytes()


def source_file(root, name):
    matches = list(root.rglob(name))
    assert len(matches) == 1, f'Expected one {name} in {root}, found {matches}'
    return matches[0]


def asm_includes(root):
    return [f'-I{path}' for path in [root, *sorted(p for p in root.rglob('*') if p.is_dir())]]
