"""Deliberate production-assembly mutants. Surviving or invalid mutants fail.

Run from the repo root with the same Python/JWasm as the ordinary suite.
This is a small, reviewed fault model, not a percentage coverage claim.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
MUTANTS = [
    ('right-edge-read', 'FRM.INC', b'CMP\tDL,79', b'CMP\tDL,80', 'screen_edges'),
    ('wrong-single-vertical', 'ZJXP.INC', b'D_ZBF\t\tDB\t01000100B', b'D_ZBF\t\tDB\t10001000B', 'frame_stroke_properties'),
    ('skip-dirty-row', 'ZJXP.INC', b'CALL\tS_XRROW', b'NOP', 'partial_update'),
    ('allow-ff-dbcs', 'ZJXP.INC', b'CMP\tBYTE PTR DS:[SI],0FEH', b'CMP\tBYTE PTR DS:[SI],0FFH', 'invalid_dbcs'),
    ('backspace-two-columns', 'AH0E.INC', b'DEC\tDL', b'SUB\tDL,2', 'teletype_backspace'),
]


def main():
    base = ROOT / 'qa/out/mutations'
    base.mkdir(parents=True, exist_ok=True)
    results = []
    for name, file, old, new, selection in MUTANTS:
        directory = Path(tempfile.mkdtemp(prefix=name+'-', dir=base))
        source = directory / 'src'
        shutil.copytree(ROOT / 'src', source)
        path = source / file
        raw = path.read_bytes()
        assert old in raw, f'mutant no longer applies: {name}'
        path.write_bytes(raw.replace(old, new))
        result = subprocess.run([sys.executable, '-m', 'pytest', '-m', 'unit', '-k', selection,
                                 '--source-dir', str(source), '-q', '--tb=short',
                                 '--basetemp', str(directory / 'work'),
                                 '--junitxml', str(directory / 'results.xml')],
                                cwd=ROOT, capture_output=True, text=True)
        (directory / 'pytest.log').write_text(result.stdout + result.stderr)
        # pytest 1 alone also includes setup errors. Require actual test failures
        # and no errors, so a mutant that merely does not assemble is not killed.
        import xml.etree.ElementTree as ET
        report = directory / 'results.xml'
        suite = ET.parse(report).getroot().find('testsuite') if report.is_file() else None
        killed = (suite is not None and result.returncode == 1 and int(suite.get('failures', 0)) > 0
                  and int(suite.get('errors', 0)) == 0)
        results.append({'name': name, 'killed': killed, 'artifacts': str(directory)})
        print(('KILLED' if killed else 'SURVIVED/INVALID'), name, flush=True)
    (base / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    return 0 if all(result['killed'] for result in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
