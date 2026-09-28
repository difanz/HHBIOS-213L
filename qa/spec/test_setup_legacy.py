"""Existing 213L configurations through the production DOS setup program."""
import shutil
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos
from qa.spec.test_setup import setup_guest


# The 32-byte CKBD file format, independently taken from the legacy menus:
# three display flag bytes, band, reserved, four colors, reserved, Shift,
# fourteen scan codes, two reserved bytes, Great Wall, phrases, PY/SW/DB.
LEGACY_VALUES = bytes.fromhex(
    '82 89 A9 37 13 1E 2F 30 4A 15 10 '
    '64 68 69 6A 6B 66 6D 6C 71 86 85 62 70 67 '
    '17 19 4E 35 4E 4E 4E')


def legacy_ini(values=LEGACY_VALUES):
    return b''.join(f'{value:02x}H\t; {index:02d} '.encode() +
                    '原配置'.encode('gb2312') + b'\r\n'
                    for index, value in enumerate(values)) + b'; tail\r\n\x1a'


def ini_values(data):
    return bytes(int(line[:2], 16) for line in data.splitlines()[:32])


@pytest.mark.dos
@pytest.mark.parametrize('current_directory', [False, True], ids=['exe-directory', 'working-directory'])
def test_setup_configuration_directory(dosbox_binary, setup_guest, current_directory):
    other = setup_guest/'OTHER'
    other.mkdir()
    for path in tuple(setup_guest.iterdir()):
        if path.is_file():
            shutil.copy2(path, other)
    root_ini = legacy_ini()
    other_values = bytearray(LEGACY_VALUES)
    other_values[28] = ord('8')
    other_ini = legacy_ini(other_values)
    (setup_guest/'213L.INI').write_bytes(root_ini)
    (other/'213L.INI').write_bytes(other_ini)
    option = ' /W' if current_directory else ''
    run_dos(dosbox_binary, setup_guest, [
        r'CD \OTHER', f'C:\\SETUP /AUTO /VIDEO:VGA{option}', 'CD \\'],
        settings='\n[dosbox]\nmachine=svga_s3\n')
    selected = other if current_directory else setup_guest
    untouched = setup_guest if current_directory else other
    assert (selected/'213L.INI').read_bytes() == (other_ini if current_directory else root_ini)
    assert (selected/'213L.BAK').read_bytes() == (other_ini if current_directory else root_ini)
    assert not (untouched/'HHBIOS.BAT').exists()
    assert not (untouched/'213L.BAK').exists()
    assert (untouched/'213L.INI').read_bytes() == (root_ini if current_directory else other_ini)
    assert ('CD \\OTHER' if current_directory else 'CD \\') in (selected/'HHBIOS.BAT').read_text().splitlines()


@pytest.mark.dos
@pytest.mark.parametrize('driver', ['VGA', 'VESA'])
def test_setup_saves_future_configuration_with_resident_driver(dosbox_binary, setup_guest, driver):
    original = legacy_ini()
    (setup_guest/'213L.INI').write_bytes(original)
    files = run_dos(dosbox_binary, setup_guest, [
        'READ5', 'CKBD /E', driver,
        'SETUP /REPORT > BEFORE.TXT',
        f'SETUP /AUTO /VIDEO:{"102" if driver == "VESA" else "VGA"} > SAVE.TXT',
        'SETUP /REPORT > AFTER.TXT'], settings='\n[dosbox]\nmachine=svga_s3\n')
    before = dict(line.split('=', 1) for line in files['BEFORE.TXT'].read_text().splitlines())
    after = dict(line.split('=', 1) for line in files['AFTER.TXT'].read_text().splitlines())
    assert before['HHBIOS_LOADED'] == after['HHBIOS_LOADED'] == '1'
    assert before == after, 'Saving must leave the active TSRs and memory manager state alone'
    assert files['213L.INI'].read_bytes() == original
    assert files['213L.BAK'].read_bytes() == original
    assert f'.\\{driver}.COM' in files['HHBIOS.BAT'].read_text()


@pytest.mark.dos
@pytest.mark.parametrize('reader', ['READ24', 'READ32', 'READ40', 'READSL'])
def test_missing_optional_font_preserves_existing_pair(dosbox_binary, setup_guest, reader):
    # The reader COM exists, but its font files do not. Import is not permission
    # to emit a batch which will fail only after installing the other TSRs.
    source = ROOT/'build'/f'{reader}.COM'
    assert source.is_file(), f'Build the {reader} reader before DOS tests'
    shutil.copy2(source, setup_guest)
    original = legacy_ini()
    access = 'W' if reader == 'READSL' else f'/F:HH{reader[4:]}.FNT'
    batch = f'@ECHO OFF\r\n{reader} {access}\r\n'.encode()
    (setup_guest/'213L.INI').write_bytes(original)
    (setup_guest/'HHBIOS.BAT').write_bytes(batch)
    files = run_dos(dosbox_binary, setup_guest,
                    [('SETUP /AUTO /VIDEO:VGA > ERROR.TXT', 1)])
    assert files['213L.INI'].read_bytes() == original
    assert files['HHBIOS.BAT'].read_bytes() == batch
    assert ('HZK' if reader == 'READSL' else 'HHFONT2') in files['ERROR.TXT'].read_text()
    assert not (setup_guest/'213L.BAK').exists()
    assert not (setup_guest/'HHBIOS.BAK').exists()


@pytest.fixture(scope='module')
def printer_probe(tmp_path_factory):
    output = tmp_path_factory.mktemp('printer-probe')/'PRCHECK.COM'
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh',
                             'qa/harness/printcheck.c', str(output)], cwd=ROOT,
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    return output


@pytest.mark.dos
@pytest.mark.parametrize('printer', ['PRNT', 'PRTH'])
def test_imported_printer_batch_installs_real_driver(dosbox_binary, setup_guest,
                                                    printer_probe, printer):
    shutil.copy2(printer_probe, setup_guest)
    shutil.copy2(ROOT/'build'/f'{printer}.COM', setup_guest)
    lines = 'PRNT 5 /2 /N\r\n'
    if printer == 'PRTH':
        backend = ROOT/'build/distribution/PR.EXE'
        if not backend.exists():
            pytest.skip('PRTH requires PR.EXE from the original distribution')
        shutil.copy2(backend, setup_guest)
        shutil.copy2(backend.with_name('PRTA.TAB'), setup_guest)
        lines = 'PR 10\r\nPRTH /N\r\n'
    original = ('@ECHO OFF\r\nREM user startup\r\n' + lines).encode()
    (setup_guest/'213L.BAT').write_bytes(original)
    (setup_guest/'213L.INI').write_bytes(legacy_ini())
    files = run_dos(dosbox_binary, setup_guest, [
        'SETUP /AUTO /VIDEO:VGA /LOW > SAVE.TXT', 'CALL HHBIOS.BAT > LOAD.TXT',
        'PRCHECK > PRINTER.TXT'])
    assert 'PRINTER=DED0' in files['PRINTER.TXT'].read_text()
    assert files['213L.BAT'].read_bytes() == original
    batch = files['HHBIOS.BAT'].read_text()
    if printer == 'PRTH':
        assert batch.index('.\\PR.EXE 10') < batch.index('.\\PRTH.COM /N')
    else:
        assert '.\\PRNT.COM 5' in batch and '/2' in batch


@pytest.mark.dos
def test_missing_printer_table_preserves_existing_pair(dosbox_binary, setup_guest):
    backend = ROOT/'build/distribution/PR.EXE'
    if not backend.exists():
        pytest.skip('PRTH requires PR.EXE from the original distribution')
    shutil.copy2(backend, setup_guest)
    shutil.copy2(ROOT/'build/PRTH.COM', setup_guest)
    original = legacy_ini()
    batch = b'PR 10\r\nPRTH /N\r\n'
    (setup_guest/'213L.INI').write_bytes(original)
    (setup_guest/'HHBIOS.BAT').write_bytes(batch)
    files = run_dos(dosbox_binary, setup_guest,
                    [('SETUP /AUTO /VIDEO:VGA > ERROR.TXT', 1)])
    assert 'PRTA.TAB' in files['ERROR.TXT'].read_text()
    assert files['213L.INI'].read_bytes() == original
    assert files['HHBIOS.BAT'].read_bytes() == batch
    assert not (setup_guest/'213L.BAK').exists()
    assert not (setup_guest/'HHBIOS.BAK').exists()


@pytest.mark.dos
def test_root_startup_import_keeps_original_file(dosbox_binary, setup_guest):
    install = setup_guest/'HHBIOS'
    install.mkdir()
    for file in tuple(setup_guest.iterdir()):
        if file.is_file():
            shutil.copy2(file, install)
    shutil.copy2(ROOT/'build/PRNT.COM', install)
    original = b'@ECHO OFF\r\nREM custom root startup\r\nPRNT 5 /2\r\n'
    (setup_guest/'213L.BAT').write_bytes(original)
    run_dos(dosbox_binary, setup_guest, [r'HHBIOS\SETUP /AUTO /VIDEO:VGA', 'CD \\'])
    assert (setup_guest/'213L.BAT').read_bytes() == original
    assert not (setup_guest/'HHBIOS.BAT').exists()
    batch = (install/'HHBIOS.BAT').read_text()
    assert '.\\PRNT.COM 5' in batch and '/2' in batch


@pytest.mark.dos
@pytest.mark.parametrize('size,accepted', [(8191, True), (8192, False)])
def test_ini_file_size_boundary_preserves_data(dosbox_binary, setup_guest, size, accepted):
    records = legacy_ini().removesuffix(b'\x1a')
    original = records + b';' + b'x' * (size - len(records) - 4) + b'\r\n\x1a'
    assert len(original) == size
    (setup_guest/'213L.INI').write_bytes(original)
    run_dos(dosbox_binary, setup_guest,
            [('SETUP /AUTO /VIDEO:VGA > SAVE.TXT', 0 if accepted else 1)])
    assert (setup_guest/'213L.INI').read_bytes() == original
    assert (setup_guest/'HHBIOS.BAT').exists() == accepted
    if accepted:
        assert (setup_guest/'213L.BAK').read_bytes() == original
    else:
        assert not (setup_guest/'213L.BAK').exists()
