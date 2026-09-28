"""Printing readers return real 24-pin bands from HHFONT2 in XMS or EMS."""
import hashlib
import json
import os
import shutil
import struct
import subprocess

import pytest

from qa.spec.build import asm_includes, source_file
from qa.spec.dos import ROOT, run_dos, run_process
from qa.spec.test_memory import Arena
from qa.spec.test_msdos import copy_disk, msdos_image

pytestmark = pytest.mark.dos
SLOTS = 8434


@pytest.fixture(scope='session')
def print_build(assembler, source_dir, tmp_path_factory):
    output = tmp_path_factory.mktemp('print-readers')
    env = dict(os.environ, JWASM=assembler)
    for size in (24, 32, 40):
        subprocess.run(['bash', 'tools/build-print-reader.sh', str(size),
                        str(output / f'READ{size}.COM'), str(source_dir)],
                       cwd=ROOT, env=env, check=True, capture_output=True)
    for name in ('printfont', 'memory', 'printlife'):
        target = {'printfont': 'PRINTFNT', 'printlife': 'PRINTLIF', 'memory': 'MEMORY'}[name]
        subprocess.run(['bash', 'tools/build-watcom-com.sh', f'qa/harness/{name}.c',
                        str(output / f'{target}.COM')], cwd=ROOT, env=env,
                       check=True, capture_output=True)
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/printwire.c',
                    str(output / 'PRINTWIR.COM'), 'qa/harness/printwire.asm'],
                   cwd=ROOT, env=env, check=True, capture_output=True)
    for source, target in [('READ5.ASM', 'READ5'), ('READ2.ASM', 'READ2'), ('PRNT.ASM', 'PRNT')]:
        subprocess.run([assembler, '-q', '-Zm', '-bin', *asm_includes(source_dir),
                        f'-Fo{output}/{target}.COM', str(source_file(source_dir, source))],
                       check=True, capture_output=True)
    subprocess.run([assembler, '-q', '-Zm', '-bin', *asm_includes(source_dir),
                    f'-Fo{output}/OLD24.COM', str(ROOT / 'qa/fixtures/legacy/READ24.ASM')],
                   check=True, capture_output=True)
    subprocess.run([assembler, '-q', '-bin', f'-Fo{output}/FONTSENT.COM',
                    str(ROOT / 'qa/harness/fontsent.asm')], check=True, capture_output=True)
    return output


def font_fixture(size, seed=0):
    """More than 64 KiB, with asymmetric pixels at every byte/band boundary."""
    records = 601
    bitmaps = []
    for record in range(records):
        rows = []
        for y in range(size):
            bits = 0
            for x in range(size):
                if record and ((x * 7 + y * 11 + record * 3 + seed) % 19 < 7):
                    bits |= 1 << (size - 1 - x)
            rows.append(bits)
        bitmaps.append(rows)
    mapping = [(slot * 53) % records for slot in range(SLOTS)]
    payload = struct.pack('<' + 'H' * SLOTS, *mapping) * 2
    payload += b''.join(row.to_bytes(size // 8, 'big')
                        for rows in bitmaps for row in rows)
    header = struct.pack('<8s4HI12x', b'HHFONT2\n', size // 2, size,
                         SLOTS, records, len(payload))
    return header + payload, mapping, bitmaps


def slot_for(code):
    if code < 256:
        return code
    lead, trail = divmod(code, 256)
    if lead == 0xaa:
        return trail & 127
    if 0xa1 <= lead <= 0xf7 and 0xa1 <= trail <= 0xfe:
        return 256 + (lead - 0xa1) * 94 + trail - 0xa1
    return None


def pin_band(rows, width, size, band, attributes=0):
    """Pack a pixel grid in the printer's pin order: three bytes per column."""
    top = 0 if size == 24 else (1 - band) * 24
    result = bytearray(width * 3)
    if band > (0 if size == 24 else 1):
        return bytes(result)
    for x in range(width):
        for pin in range(24):
            y = top + pin
            if y >= size:
                continue
            ink = bool(rows[y] & (1 << (size - 1 - x)))
            if attributes & 2 and y == 0:
                ink = True
            if attributes & 4 and y == size - 1:
                ink = True
            if ink:
                result[3 * x + pin // 8] |= 128 >> (pin % 8)
    return bytes(result)


def parse_results(raw, requests, preserve=True):
    assert raw[:8] == b'HHPRINT1'
    offset = 8
    answers = []
    for request in requests:
        assert struct.unpack_from('<4H', raw, offset) == request
        values = struct.unpack_from('<10H', raw, offset + 8)
        offset += 28
        length = values[-1]
        assert length == values[2] * 3 and 0 < length <= 180
        assert values[4:6] == (0x1234, 0x5a5a), 'reader damaged caller ES:DI'
        if preserve:
            assert values[1] == request[2] and values[3] == request[3]
        answers.append((values, raw[offset:offset + length]))
        offset += length
    assert offset == len(raw)
    return answers


def prepare(directory, build):
    for path in build.glob('*.COM'):
        shutil.copy2(path, directory)
    shutil.copy2(ROOT / 'fonts/HZK16', directory)


def packed_rows(font, code):
    signature, width, height, slots, records, payload = struct.unpack_from('<8s4HI', font)
    assert signature == b'HHFONT2\n' and slots == SLOTS and len(font) == payload + 32
    record = struct.unpack_from('<H', font, 32 + slot_for(code) * 2)[0]
    assert record < records
    stride = (width * 2 + 7) // 8
    offset = 32 + SLOTS * 4 + record * ((stride * height + 1) & ~1)
    return [int.from_bytes(font[offset + y * stride:offset + (y + 1) * stride], 'big')
            for y in range(height)]


def pack_requests(directory, pack, sizes):
    requests, expected = [], []
    for size in sizes:
        path = pack / f'HH{size}.FNT'
        font = path.read_bytes()
        metadata = json.loads(path.with_suffix('.json').read_text())
        assert hashlib.sha256(font).hexdigest() == metadata['sha256']
        shutil.copy2(path, directory)
        for code in [0x41, 0xaac1, 0xa1a1, 0xb0a1, 0xd6d0, 0xf7fe, 0xd6d0]:
            rows = packed_rows(font, code)
            width = size // 2 if code < 256 or code >> 8 == 0xaa else size
            for band in ([0] if size == 24 else [1, 0]):
                requests.append((0x7b + (size - 24) // 8,
                                 {24: 0, 32: 0x8000, 40: 0xc000}[size], band << 8, code))
                expected.append(pin_band(rows, width, size, band))
    (directory / 'FONTREQ.BIN').write_bytes(b''.join(struct.pack('<4H', *r) for r in requests))
    return requests, expected


@pytest.mark.parametrize('size', [24, 32, 40])
def test_distributed_print_fonts(dosbox_binary, print_build, tmp_path, pytestconfig, size):
    prepare(tmp_path, print_build)
    pack = pytestconfig.getoption('--print-font-pack') or ROOT / 'fonts/large'
    requests, expected = pack_requests(tmp_path, pack, [size])
    files = run_dos(dosbox_binary, tmp_path, ['READ5', f'READ{size}', 'PRINTFNT', 'MEMORY off'])
    assert [glyph for _, glyph in parse_results(files['FONTRES.BIN'].read_bytes(), requests)] == expected


def test_three_readers_under_msdos(dosbox_binary, print_build, tmp_path, pytestconfig, msdos_image):
    """All three vectors coexist, using both actual HIMEM and EMM386 stores."""
    import re
    prepare(tmp_path, print_build)
    pack = pytestconfig.getoption('--print-font-pack') or ROOT / 'fonts/large'
    requests, expected = pack_requests(tmp_path, pack, [24, 32, 40])
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for path in list(tmp_path.glob('*.COM')) + list(tmp_path.glob('*.FNT')):
        copy_in(path, '::' + path.name)
    for name in ('FONTREQ.BIN', 'HZK16'):
        copy_in(tmp_path / name, '::' + name)
    startup, count = re.subn(rb'(?im)^CALL HHBIOS\.BAT', b'REM readers tested below',
                             read('AUTOEXEC.BAT'))
    assert count == 1
    commands = ['@ECHO OFF', 'CD \\', 'MEMORY BEFORE.TXT', 'READ5',
                'READ24 /X', 'READ32 /E', 'READ40 /X', 'PRINTFNT',
                'IF ERRORLEVEL 1 GOTO FAILED', 'MEMORY off', 'MEMORY AFTER.TXT',
                'ECHO complete>DONE.TXT', ':FAILED', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(startup + ('\r\n' + '\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = ('[sdl]\noutput=surface\n[dosbox]\nmachine=svga_s3\nmemsize=16\n'
              '[cpu]\ncycles=30000\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
              f'imgmount c "{image}" -ide 1m\nboot c:\n')
    (tmp_path / 'dosbox.conf').write_text(config)
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')], tmp_path, 90, env)
    assert read('DONE.TXT').strip() == b'complete'
    assert [glyph for _, glyph in parse_results(read('FONTRES.BIN'), requests)] == expected
    for name in ('BEFORE.TXT', 'AFTER.TXT'):
        read(name)
    before, after = (Arena(tmp_path / name) for name in ('BEFORE.TXT', 'AFTER.TXT'))
    assert (after.xms, after.ems, after.vectors) == (before.xms, before.ems, before.vectors)
    assert after.occupied() == before.occupied()
    assert after.occupied(True) == before.occupied(True)


@pytest.mark.parametrize('size', [24, 32, 40])
@pytest.mark.parametrize('memory', ['X', 'E'])
def test_print_bands_and_memory_release(dosbox_binary, print_build, tmp_path, size, memory):
    prepare(tmp_path, print_build)
    raw, mapping, bitmaps = font_fixture(size)
    (tmp_path / f'HH{size}.FNT').write_bytes(raw)
    requests = []
    # The extremes, byte boundaries and a long run of replacements catch
    # truncated offsets and accidental reuse of the last glyph's cache entry.
    codes = [0, 0x41, 0xaac1, 0xa1a1, 0xb0a1, 0xd6d0, 0xf7fe,
             0xa0a1, 0xa1a0, 0xa1ff, 0xf8a1]
    codes += [0xb0a1 + i for i in range(90)] + [0xd6d0, 0xb0a1, 0xd6d0]
    native = {24: 0x40, 32: 0x80, 40: 0xc0}[size]
    for code in codes:
        for band in ([0] if size == 24 else [1, 0, 2]):
            for attributes in (0, 6):
                requests.append((0x7b + (size - 24) // 8, native << 8,
                                 (band << 8) | attributes, code))
    (tmp_path / 'FONTREQ.BIN').write_bytes(b''.join(struct.pack('<4H', *r) for r in requests))
    commands = ['MEMORY BEFORE.TXT', 'READ5', f'READ{size} /{memory}',
                'MEMORY LIVE.TXT', 'PRINTFNT', 'MEMORY off', 'MEMORY AFTER.TXT']
    files = run_dos(dosbox_binary, tmp_path, commands, timeout=90,
                    settings='\n[dos]\nxms=true\nems=true\numb=true\n')
    answers = parse_results(files['FONTRES.BIN'].read_bytes(), requests)
    for request, (registers, result) in zip(requests, answers):
        _, _, bx, code = request
        width = size // 2 if code < 256 or code >> 8 == 0xaa else size
        slot = slot_for(code)
        glyph = bitmaps[mapping[slot]] if slot is not None else [0] * size
        expected = pin_band(glyph, width, size, bx >> 8, bx & 255)
        if slot is None:
            expected = bytes(width * 3)
        assert registers[2] == width
        assert result == expected, (size, memory, hex(code), hex(bx))
    before, live, after = (Arena(files[name + '.TXT']) for name in ('BEFORE', 'LIVE', 'AFTER'))
    assert (after.xms, after.ems, after.vectors) == (before.xms, before.ems, before.vectors)
    assert after.occupied() == before.occupied()
    assert after.occupied(True) == before.occupied(True)
    assert live.xms < before.xms
    if memory == 'E':
        assert live.ems < before.ems


def test_prnt_consumes_all_three_bitmap_sizes(dosbox_binary, print_build, tmp_path):
    prepare(tmp_path, print_build)
    expected = {}
    for size in (24, 32, 40):
        font, mapping, glyphs = font_fixture(size)
        (tmp_path / f'HH{size}.FNT').write_bytes(font)
        expected[size] = []
        for band in ([0] if size == 24 else [1, 0]):
            chinese = pin_band(glyphs[mapping[slot_for(0xd6d0)]], size, size, band)
            ascii = pin_band(glyphs[mapping[0x41]], size // 2, size, band)
            expected[size].append(chinese + ascii)
    files = run_dos(dosbox_binary, tmp_path,
                    ['READ5', 'READ24 /X', 'READ32 /E', 'READ40 /X', 'PRINTWIR > WIRE.LOG'], timeout=90)
    for size in (24, 32, 40):
        stream = files[f'PRN{size}.BIN'].read_bytes()
        # LQ1500's ESC * mode 39 carries three pin bytes for every column.
        # Parse packet lengths; matching a glyph somewhere in arbitrary output
        # would miss a wrong width, overread or stale extra bottom band.
        bands = []
        offset = 0
        while offset < len(stream):
            if stream[offset:offset + 3] == b'\x1b*\x27':
                columns = int.from_bytes(stream[offset + 3:offset + 5], 'little')
                payload = stream[offset + 5:offset + 5 + columns * 3]
                assert len(payload) == columns * 3
                bands.append(payload)
                offset += 5 + columns * 3
            else:
                offset += 1
        assert bands == expected[size], (size, [len(band) for band in bands])


def read_ranges(path):
    values = {}
    for line in path.read_text().splitlines():
        vector, segment, offset, kind, result, signature = (int(v, 16) for v in line.split())
        assert signature == 0x4a06 and result in (0, 1)
        values[vector, kind] = (segment, offset, result)
    assert len(values) == 18
    return values


def test_partial_printer_unload_and_reload(dosbox_binary, print_build, tmp_path):
    prepare(tmp_path, print_build)
    for size in (24, 32, 40):
        (tmp_path / f'HH{size}.FNT').write_bytes(font_fixture(size)[0])
    requests = [(0x7b, 0x4000, 0, 0xd6d0)]
    (tmp_path / 'FONTREQ.BIN').write_bytes(struct.pack('<4H', *requests[0]))
    commands = ['FONTSENT', 'MEMORY BEFORE.TXT', 'READ5', 'READ24 /X', 'PRNT 5',
                'READ32 /E', 'READ40 /X', 'PRINTLIF LIVE.TXT', 'PRINTLIF off2',
                'PRINTLIF fallback', 'PRINTLIF FONLY.TXT', 'READ32 /E', 'PRINTLIF off1',
                'PRINTLIF PONLY.TXT', 'PRNT 5', 'READ40 /X',
                'PRINTLIF RELOAD.TXT', 'PRINTLIF off1', 'PRINTLIF LAST.TXT',
                'PRINTFNT', 'MEMORY off', 'MEMORY AFTER.TXT']
    files = run_dos(dosbox_binary, tmp_path, commands, timeout=90,
                    settings='\n[dos]\nxms=true\nems=true\numb=true\n')
    live, fonts, printer, reload, last = (read_ranges(files[name + '.TXT'])
                                        for name in ('LIVE', 'FONLY', 'PONLY', 'RELOAD', 'LAST'))
    for state in (live, fonts, printer, reload, last):
        assert [state[0x7b, kind][2] for kind in range(3)] == [1, 0, 0]
        assert [state[0x7f, kind][2] for kind in range(3)] == [1, 0, 0]
        assert state[0x7e, 0] == live[0x7e, 0] and state[0x7e, 0][2] == 0
    for vector in (0x7c, 0x7d):
        assert [live[vector, kind][2] for kind in range(3)] == [1, 1, 1]
        assert [fonts[vector, kind][2] for kind in range(3)] == [1, 1, 0]
    for state in (printer, last):
        for vector in (0x7a, 0x7c, 0x7d):
            assert state[vector, 0][:2] == (0, 0)
    assert [reload[0x7d, kind][2] for kind in range(3)] == [1, 1, 1]
    _, mapping, bitmaps = font_fixture(24)
    expected = pin_band(bitmaps[mapping[slot_for(0xd6d0)]], 24, 24, 0)
    assert parse_results(files['FONTRES.BIN'].read_bytes(), requests)[0][1] == expected
    before, after = (Arena(files[name + '.TXT']) for name in ('BEFORE', 'AFTER'))
    assert (after.xms, after.ems, after.vectors) == (before.xms, before.ems, before.vectors)
    assert after.occupied() == before.occupied()
    assert after.occupied(True) == before.occupied(True)


@pytest.mark.parametrize('size', [24, 32, 40])
@pytest.mark.parametrize('fault,memory', [('header', 'X'), ('header', 'E'),
                                        ('truncated', 'X'), ('truncated', 'E'),
                                        ('no-xms', 'X')])
def test_failed_install_releases_all_faces(dosbox_binary, print_build, tmp_path, size, fault, memory):
    prepare(tmp_path, print_build)
    font = font_fixture(size)[0]
    (tmp_path / f'HH{size}.FNT').write_bytes(font)
    (tmp_path / 'BROKEN.FNT').write_bytes(b'X' + font[1:] if fault == 'header' else font[:-17])
    reader = 'READ2' if fault == 'no-xms' else 'READ5'
    option = '' if fault == 'no-xms' else ' /F1:BROKEN.FNT'
    commands = ['MEMORY BEFORE.TXT', reader, 'MEMORY READY.TXT', 'PRINTLIF READYV.TXT',
                (f'READ{size} /{memory}{option}', 1), 'MEMORY FAILED.TXT',
                'PRINTLIF FAILEDV.TXT', 'MEMORY off', 'MEMORY AFTER.TXT']
    settings = '\n[dos]\nxms=false\nems=false\numb=false\n' if fault == 'no-xms' else ''
    files = run_dos(dosbox_binary, tmp_path, commands, settings=settings)
    assert files['READYV.TXT'].read_bytes() == files['FAILEDV.TXT'].read_bytes()
    for first, last in [('BEFORE', 'AFTER'), ('READY', 'FAILED')]:
        before, after = (Arena(files[name + '.TXT']) for name in (first, last))
        assert (after.xms, after.ems, after.vectors) == (before.xms, before.ems, before.vectors)
        assert after.occupied() == before.occupied()
        assert after.occupied(True) == before.occupied(True)


def test_legacy_read24_geometry(dosbox_binary, print_build, tmp_path):
    """Compare real old and new interrupt handlers on identical source pixels."""
    prepare(tmp_path, print_build)
    modern, mapping, bitmaps = font_fixture(24)
    (tmp_path / 'HH24.FNT').write_bytes(modern)
    for start, end, filename in ((0xa1, 0xb0, 'HZK24T'), (0xb0, 0xf8, 'HZK24S')):
        data = bytearray()
        for lead in range(start, end):
            for trail in range(0xa1, 0xff):
                rows = bitmaps[mapping[slot_for(lead * 256 + trail)]]
                data += pin_band(rows, 24, 24, 0)
        (tmp_path / filename).write_bytes(data)
    requests = []
    for code in (0xa1a1, 0xa9a1, 0xb0a1, 0xd6d0, 0xf7fe):
        for format in (0x40, 0x10, 0x11, 0x12, 0x13):
            for band in (0, 1):
                for attributes in (0, 2, 4, 8, 16, 32, 64, 128):
                    requests.append((0x7b, format << 8, (band << 8) | attributes, code))
    (tmp_path / 'FONTREQ.BIN').write_bytes(b''.join(struct.pack('<4H', *r) for r in requests))
    files = run_dos(dosbox_binary, tmp_path,
                    ['READ5', 'OLD24 WS', 'PRINTFNT', 'COPY FONTRES.BIN OLD.BIN > NUL',
                     'MEMORY off', 'READ5', 'READ24 /X', 'PRINTFNT', 'MEMORY off'], timeout=90)
    old = parse_results(files['OLD.BIN'].read_bytes(), requests, preserve=False)
    new = parse_results(files['FONTRES.BIN'].read_bytes(), requests)
    for request, (previous, current) in zip(requests, zip(old, new)):
        assert current[0][2] == previous[0][2], request
        assert current[1] == previous[1], tuple(hex(v) for v in request)


@pytest.mark.parametrize('size', [24, 32, 40])
def test_linux_source_pixels(dosbox_binary, print_build, tmp_path, pytestconfig, size):
    pack = pytestconfig.getoption('--print-font-pack') or ROOT / 'fonts/large'
    source = pytestconfig.getoption('--print-cjk-font')
    if source is None:
        pytest.skip('Supply --print-cjk-font for the independent Linux source oracle')
    import freetype
    metadata = json.loads((pack / f'HH{size}.json').read_text())
    descriptor = next(item for item in metadata['inputs'] if item['file'] == source.name)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == descriptor['sha256']
    face = freetype.Face(str(source), index=descriptor['index'])
    face.set_pixel_sizes(0, descriptor['pixel_size'])
    prepare(tmp_path, print_build)
    shutil.copy2(pack / f'HH{size}.FNT', tmp_path)
    requests, expected = [], []
    for char in '中文汉永鼎鬻':
        code = int.from_bytes(char.encode('gb2312'), 'big')
        face.load_char(char, freetype.FT_LOAD_RENDER | freetype.FT_LOAD_MONOCHROME |
                       freetype.FT_LOAD_TARGET_MONO | freetype.FT_LOAD_NO_BITMAP)
        glyph = face.glyph
        bitmap = glyph.bitmap
        assert bitmap.pixel_mode == freetype.FT_PIXEL_MODE_MONO
        rows = [0] * size
        origin_x = glyph.bitmap_left + (size - round(glyph.advance.x / 64)) // 2
        origin_y = metadata['baseline'] - glyph.bitmap_top
        for y in range(bitmap.rows):
            for x in range(bitmap.width):
                if bitmap.buffer[y * bitmap.pitch + x // 8] & (128 >> (x % 8)):
                    assert 0 <= origin_x + x < size and 0 <= origin_y + y < size
                    rows[origin_y + y] |= 1 << (size - 1 - origin_x - x)
        for band in ([0] if size == 24 else [1, 0]):
            requests.append((0x7b + (size - 24) // 8,
                             {24: 0, 32: 0x8000, 40: 0xc000}[size], band << 8, code))
            expected.append(pin_band(rows, size, size, band))
    (tmp_path / 'FONTREQ.BIN').write_bytes(b''.join(struct.pack('<4H', *r) for r in requests))
    files = run_dos(dosbox_binary, tmp_path, ['READ5', f'READ{size}', 'PRINTFNT', 'MEMORY off'])
    answers = parse_results(files['FONTRES.BIN'].read_bytes(), requests)
    assert [result for _, result in answers] == expected
