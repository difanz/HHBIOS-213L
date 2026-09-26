#!/usr/bin/env python3
"""Run an explicitly selected test layer and retain a unique evidence bundle."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def record_tool(manifest, name, path):
    if path and Path(path).is_file():
        path = Path(path).resolve()
        manifest[name] = {'path': str(path),
                          'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('layer', choices=['unit', 'dos', 'application', 'all'], nargs='?', default='unit')
    parser.add_argument('--source-dir', type=Path, default=ROOT / 'src')
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'qa/out/runs')
    options, extra = parser.parse_known_args()
    runs = options.output_dir.resolve()
    runs.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    out = Path(tempfile.mkdtemp(prefix=stamp+'-', dir=runs))
    packages = {}
    for name in ('pytest', 'unicorn'):
        try:
            packages[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            print(f'Missing {name}; install qa/requirements.txt in the selected Python environment', file=sys.stderr)
            return 2
    options.source_dir = options.source_dir.resolve()
    # Source archives need no Git installation; file hashes identify the input.
    commit = None
    if (ROOT / '.git').exists() and shutil.which('git'):
        result = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT,
                                capture_output=True, text=True)
        if result.returncode == 0:
            commit = result.stdout.strip()
    manifest = {'python': sys.version, 'packages': packages, 'layer': options.layer,
                'source_dir': str(options.source_dir),
                'commit': commit,
                'files': {str(Path(label) / p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for label, folder in [('src', options.source_dir), ('fonts', ROOT / 'fonts'),
                                                ('qa/harness', ROOT / 'qa/harness'), ('qa/spec', ROOT / 'qa/spec')]
                          for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts}}
    for name in ('conftest.py', 'pytest.ini', 'qa/run.py', 'qa/mutate.py',
                 'qa/requirements.txt', 'qa/dosbox.conf', 'tools/build-watcom-com.sh'):
        manifest['files'][name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    assembler = shutil.which(os.environ.get('JWASM', 'jwasm'))
    if assembler is None and 'JWASM' not in os.environ:
        assembler = ROOT / 'qa/.cache/JWasm/build/GccUnixR/jwasm'
    record_tool(manifest, 'JWASM', assembler)
    # Match build-watcom-com.sh: configured prefix, then the caller's PATH.
    watcom_path = os.environ.get('PATH', '')
    if os.environ.get('WATCOM'):
        prefix = Path(os.environ['WATCOM'])
        watcom_path = os.pathsep.join([str(prefix / 'binl64'), str(prefix / 'binl'), watcom_path])
    for name in ('wcl', 'wcc', 'wcl386', 'wcc386', 'wlink', 'wasm'):
        record_tool(manifest, name, shutil.which(name, path=watcom_path))
    args = [sys.executable, '-m', 'pytest', '-q', '--tb=short',
            '--junitxml', str(out / 'junit.xml'), '--basetemp', str(out / 'work'),
            '--source-dir', str(options.source_dir)]
    if options.layer != 'all':
        args += ['-m', options.layer]
    args += extra
    manifest['command'] = args
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Evidence: {out}', flush=True)
    with (out / 'pytest.log').open('w') as log:
        with subprocess.Popen(args, cwd=ROOT, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True) as child:
            for line in child.stdout:
                print(line, end='', flush=True)
                log.write(line)
            return child.wait()


if __name__ == '__main__':
    raise SystemExit(main())
