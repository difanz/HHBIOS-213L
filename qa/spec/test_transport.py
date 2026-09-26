"""Test the evidence transport's failure modes, not its happy-path spelling."""
import sys
import subprocess

import pytest

from qa.spec.dos import Snapshot, PLANE, run_process, run_dos

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('payload', [b'', b'HHSNAP2\n', b'HHSNAP1\n' + b'\0'*4000,
                                     b'HHSNAP1\n' + b'\0'*(4028+4*PLANE)])
def test_reject_corrupt_snapshots(tmp_path, payload):
    path = tmp_path / 'bad.bin'
    path.write_bytes(payload)
    with pytest.raises(AssertionError):
        Snapshot.read(path)


def test_emulator_nonzero_is_not_a_pass(tmp_path):
    with pytest.raises(AssertionError, match='exited 7'):
        run_process([sys.executable, '-c', 'raise SystemExit(7)'], tmp_path, 5)


def test_emulator_hang_is_bounded(tmp_path):
    with pytest.raises(subprocess.TimeoutExpired):
        run_process([sys.executable, '-c', 'import time; time.sleep(60)'], tmp_path, 0.1)


def test_stale_completion_cannot_pass_a_new_guest(tmp_path):
    (tmp_path / 'done.txt').write_text('complete\n')
    with pytest.raises(AssertionError, match='stale guest results'):
        run_dos('must-not-launch', tmp_path, ['MISSING.COM'])
