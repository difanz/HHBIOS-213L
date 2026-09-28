"""Keep the runnable DOS distribution's configuration editor unambiguous."""
import os
import shutil
import subprocess

import pytest

from qa.spec.dos import ROOT

pytestmark = pytest.mark.unit


def staging_shell(command, **environment):
    result = subprocess.run(['bash', '-euc', 'source "$root/qa/msdos.sh"\n' + command],
                            env=dict(os.environ, root=str(ROOT), **environment),
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr


@pytest.mark.parametrize('reused', [False, True])
def test_archived_distribution_stages_without_retired_editor(tmp_path, reused):
    if not shutil.which('7z'):
        pytest.skip('Original DOS self-extractors require 7z')
    distribution = tmp_path/'distribution'
    if reused:
        distribution.mkdir()
        (distribution/'LSETUP.COM').write_bytes(b'previous build')
        (distribution/'LOCAL.DAT').write_bytes(b'local fixture')
    staging_shell('stage_distribution', dist=str(distribution), cache=str(tmp_path/'cache'))
    assert not (distribution/'LSETUP.COM').exists()
    for name in ('213L.EXE', '213L.INI', 'HZK16', 'HZK16F', 'PR.EXE', 'READ24.COM', 'READSL.COM'):
        assert (distribution/name).stat().st_size > 0
    if reused:
        assert (distribution/'LOCAL.DAT').read_bytes() == b'local fixture'


@pytest.mark.parametrize('reused', [False, True])
def test_fat_disk_update_removes_only_retired_editor(tmp_path, reused):
    for tool in ('mformat', 'mmd', 'mcopy', 'mtype', 'mdir', 'mdel'):
        if not shutil.which(tool):
            pytest.skip('FAT staging checks require mtools')
    image = tmp_path/'disk.img'
    subprocess.run(['mformat', '-C', '-f', '1440', '-i', str(image), '::'], check=True)
    subprocess.run(['mmd', '-i', str(image), '::HHBIOS'], check=True)
    for name in ('SETUP.EXE', '213L.INI') + (('LSETUP.COM',) if reused else ()):
        file = tmp_path/name
        file.write_bytes(name.encode())
        subprocess.run(['mcopy', '-i', str(image), str(file), '::HHBIOS/'], check=True)
    staging_shell('remove_guest_lsetup', volume=str(image))
    names = subprocess.check_output(['mdir', '-b', '-i', str(image), '::HHBIOS']).decode()
    assert 'LSETUP.COM' not in names
    for name in ('SETUP.EXE', '213L.INI'):
        assert subprocess.check_output(['mtype', '-i', str(image), '::HHBIOS/'+name]) == name.encode()
