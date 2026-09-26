"""Conventional memory, resident ownership and unload/reload on a real DOS arena."""
import os
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.dos


class Arena:
    def __init__(self, path):
        lines = path.read_text().splitlines()
        assert lines.pop(0) == 'HHMEM01'
        tag, *fields = lines.pop(0).split()
        assert tag == 'STATE' and len(fields) == 5
        self.psp, self.strategy, self.linked, self.xms, self.ems = (int(x, 16) for x in fields)
        self.vectors, self.blocks = {}, []
        for line in lines:
            tag, *fields = line.split()
            if tag == 'VECTOR':
                vector, segment, offset = (int(x, 16) for x in fields)
                self.vectors[vector] = (segment, offset)
            else:
                assert tag == 'MCB' and len(fields) == 5
                segment, kind, owner, size = (int(x, 16) for x in fields[:4])
                self.blocks.append((segment, kind, owner, size, bytes.fromhex(fields[4])))
        assert self.blocks[-1][1] == ord('Z')
        for a, b in zip(self.blocks, self.blocks[1:]):
            assert a[1] == ord('M') and a[0] + a[3] + 1 == b[0]

    def occupied(self, high=False):
        # The observer's PSP and environment are temporary. Include MCB
        # overhead; free adjacent blocks need not already have been coalesced.
        return sum((size+1)*16 for seg, _, owner, size, _ in self.blocks
                   if bool(seg >= 0xa000) == high and owner not in (0, self.psp))

    def resident(self, interrupt):
        segment, offset = self.vectors[interrupt]
        matches = [b for b in self.blocks if b[0]+1 == segment]
        assert len(matches) == 1, f'INT {interrupt:02x} outside allocated memory'
        block, = matches
        assert block[2] == segment, 'resident must own its relocated PSP'
        assert offset < block[3]*16, 'interrupt handler outside retained block'
        return segment


@pytest.fixture(scope='session')
def memory_build(guest_build, assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('memory-build')
    for path in guest_build.glob('*.COM'):
        shutil.copy2(path, out)
    env = {k: v for k, v in os.environ.items() if k != 'JWASM'}
    build = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/memory.c',
                            str(out / 'MEMORY.COM')], cwd=ROOT, env=env, capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    for reader in ('READ4', 'READ6'):
        build = subprocess.run([assembler, '-q', '-Zm', '-bin', f'-I{source_dir}',
                                f'-Fo{out}/{reader}.COM', str(source_dir / f'{reader}.ASM')],
                               env=env, capture_output=True)
        assert build.returncode == 0, build.stdout + build.stderr
    build = subprocess.run([assembler, '-q', '-Zm', '-bin',
                            f'-Fo{out}/NOXMS.COM', str(ROOT / 'qa/harness/noxms.asm')],
                           env=env, capture_output=True)
    assert build.returncode == 0, build.stdout + build.stderr
    return out


@pytest.mark.parametrize('xms,umb,low,policy,hide_xms', [
    (True, True, False, False, False),
    (False, True, False, False, False),
    (True, False, False, False, False),
    (False, False, False, False, False),
    (True, True, True, False, False),
    (True, True, False, True, False),
    (False, True, False, False, True),
])
def test_resident_memory_lifecycle(dosbox_binary, memory_build, tmp_path, xms, umb, low, policy, hide_xms):
    for path in memory_build.glob('*.COM'):
        shutil.copy2(path, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    keyboard_config(tmp_path)
    suffix = ' /N' if low else ''
    reader = 'READ5' if xms else 'READ4'
    commands = ['MEMORY policy'] if policy else []
    if hide_xms:
        commands += ['NOXMS']
    commands += ['MEMORY BEFORE.TXT']
    for cycle in range(2):
        commands += [reader+suffix, 'VGA'+suffix, 'CKBD'+suffix,
                     f'MEMORY LIVE{cycle}.TXT', 'SNAPSHOT api',
                     f'copy API.BIN API{cycle}.BIN', f'MEMORY KEEP{cycle}.TXT',
                     'MEMORY off', f'MEMORY FREE{cycle}.TXT']
    files = run_dos(dosbox_binary, tmp_path, commands, settings=(
        f'\n[dos]\nxms={str(xms or hide_xms).lower()}\numb={str(umb).lower()}\nems=true\n'))
    before = Arena(files['BEFORE.TXT'])
    # Some DOSBox versions make UMB availability depend on the XMS option.
    high_available = any(seg >= 0xa000 and owner == 0 for seg, _, owner, _, _ in before.blocks)
    if hide_xms:
        assert high_available and before.xms == 0
    for cycle in range(2):
        live = Arena(files[f'LIVE{cycle}.TXT'])
        keep = Arena(files[f'KEEP{cycle}.TXT'])
        freed = Arena(files[f'FREE{cycle}.TXT'])
        for current in (live, keep):
            for vector in (8, 9, 0x10, 0x16, 0x28, 0x2f, 0x7f):
                segment = current.resident(vector)
                assert bool(segment >= 0xa000) == (high_available and not low)
            assert (current.strategy, current.linked) == (before.strategy, before.linked)
            assert current.occupied() == live.occupied()
            assert current.occupied(True) == live.occupied(True)
        if high_available and not low:
            assert live.occupied() == before.occupied(), 'unnecessary conventional residency'
        else:
            assert live.occupied() > before.occupied()
        assert live.xms == before.xms - (256 if xms else 0)
        if not xms:
            assert live.ems == before.ems - 16
        assert (freed.strategy, freed.linked, freed.xms) == (before.strategy, before.linked, before.xms)
        assert freed.ems == before.ems
        assert freed.vectors == before.vectors, 'unload did not restore all hooks'
        assert freed.occupied() == before.occupied(), 'conventional memory leak'
        assert freed.occupied(True) == before.occupied(True), 'UMB leak'
        api = files[f'API{cycle}.BIN'].read_bytes()
        assert len(api) == 8052 and api[:8] == b'HHAPI01\n'
        assert struct.unpack_from('<H', api, 8)[0] == 0x56
        offset = ((0xd6-0xa1)*94 + 0xd0-0xa1)*32
        assert api[8020:] == (ROOT / 'fonts/HZK16').read_bytes()[offset:offset+32]


@pytest.mark.parametrize('reader', ['READ4', 'READ5', 'READ6'])
@pytest.mark.parametrize('selection', ['', 'J', 'F', 'JJ', 'FF', 'JF', 'FJ'])
def test_font_storage_is_shared_only_for_the_same_font(dosbox_binary, memory_build,
                                                      tmp_path, reader, selection):
    for path in memory_build.glob('*.COM'):
        shutil.copy2(path, tmp_path)
    font = (ROOT / 'fonts/HZK16').read_bytes()
    (tmp_path / 'HZK16').write_bytes(font)
    # A deliberately distinct traditional fixture catches handle aliasing.
    traditional = bytes(b ^ 0xff for b in font)
    (tmp_path / 'HZK16F').write_bytes(traditional)
    files = run_dos(dosbox_binary, tmp_path, ['MEMORY BEFORE.TXT', reader+' '+selection,
                    'MEMORY LIVE.TXT', 'MEMORY glyphs', 'MEMORY off', 'MEMORY FREE.TXT'],
                    settings='\n[dos]\nxms=false\nems=false\n' if reader == 'READ6' else '')
    before, live, freed = (Arena(files[name+'.TXT']) for name in ('BEFORE', 'LIVE', 'FREE'))
    distinct = len(set(selection or 'J'))
    # The selected API measures storage. EMS and XMS can share a physical pool.
    if reader == 'READ5':
        assert before.xms - live.xms == 256*distinct
    elif reader == 'READ4':
        assert before.ems - live.ems == 16*distinct
    assert (freed.xms, freed.ems) == (before.xms, before.ems)
    offset = ((0xd6-0xa1)*94 + 0xd0-0xa1)*32
    j = font[offset:offset+32]
    f = traditional[offset:offset+32]
    expected = f+j if distinct == 2 else (f if selection.startswith('F') else j)*2
    assert files['GLYPHS.BIN'].read_bytes() == expected


def test_conventional_font_retains_exact_tail_and_no_environment(dosbox_binary, memory_build, tmp_path):
    footprints = []
    for extra in (0, 16):
        directory = tmp_path / str(extra)
        directory.mkdir()
        for path in memory_build.glob('*.COM'):
            shutil.copy2(path, directory)
        font = (ROOT / 'fonts/HZK16').read_bytes() + bytes(extra)
        (directory / 'HZK16').write_bytes(font)
        files = run_dos(dosbox_binary, directory, ['MEMORY BEFORE.TXT', 'READ2',
                        'MEMORY LIVE.TXT', 'MEMORY glyphs', 'MEMORY off', 'MEMORY FREE.TXT'])
        before, live, freed = (Arena(files[name+'.TXT']) for name in ('BEFORE', 'LIVE', 'FREE'))
        psp = live.resident(0x7f)
        assert len([b for b in live.blocks if b[2] == psp]) == 1, 'environment still resident'
        footprints.append(live.occupied() - before.occupied())
        assert freed.occupied() == before.occupied()
        offset = ((0xd6-0xa1)*94 + 0xd0-0xa1)*32
        assert files['GLYPHS.BIN'].read_bytes() == font[offset:offset+32]*2
    assert footprints[1] - footprints[0] == 16, 'font tail rounded to a whole read buffer'
