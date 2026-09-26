#!/usr/bin/env python3
"""Publish retained SDL screenshots as a self-contained, offline HTML gallery."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import struct
import xml.etree.ElementTree as ET


APPS = {'tvedit': 'Turbo Vision / TVEDIT', 'borland': 'Borland C++ 3.1',
        'msedit': 'MS-DOS EDIT / QBASIC', 'edit2': 'MS-DOS Editor 2',
        'tc201': 'Turbo C 2.01', 'tc30': 'Turbo C++ 3.0', 'pct9': 'PC Tools 9'}
KEYS = {0x50: 'Down', 0x48: 'Up', 0x47: 'Home', 0x4f: 'End',
        0x4b: 'Left', 0x4d: 'Right', 0x53: 'Delete', 0x0e: 'Backspace',
        0x3c: 'F2', 0x3d: 'F3', 0x1c: 'Enter', 0x01: 'Escape',
        0x21: 'Alt-F', 0x2d: 'Alt-X', 0x22: 'G', 0x12: 'E'}
TITLES = {
    'test_vga_mixed_frames_and_real_hanzi': 'Mixed borders and Chinese; all four screen corners',
    'test_vga_incremental_repaint': 'Dirty byte: Chinese pair, changed lead, then ASCII trail',
    'test_full_width_grid_and_symbol_spacing': '80 columns, symbols and bottom row',
    'test_text_layout_boundaries': 'Tables, 16 colors, odd/even positions and orphan bytes',
    'test_vga_mode_change_without_text_change': 'Same bytes, four display policies',
    'test_resident_api_and_teletype_backspace': 'Cleared text viewport after BIOS API calls',
    'test_vesa_prompt_bitmap_wide_text_and_pixels': 'Prompt row, wide glyph clipping and bottom-right pixel',
    'test_native_font_storage_banks_and_cursor': 'Simplified / traditional / cursor XOR / restored',
    'test_tvedit_tabs_and_long_lines': 'Turbo Vision document: tabs and right-edge clipping',
    'test_native_text_geometry': 'Native BIOS text mode, without HHBIOS',
}


def read_json(path, default=None):
    return json.loads(path.read_text()) if path.is_file() else default


def older_cases(run):
    """Read pre-case.json bundles using pytest's retained temp-directory names."""
    counters, result = {}, {}
    for test in ET.parse(run / 'junit.xml').iter('testcase'):
        name = test.attrib['name']
        prefix = re.sub(r'[\W]', '_', name)[:30]
        index = counters.get(prefix, 0)
        counters[prefix] = index+1
        failure = test.find('failure')
        result[prefix+str(index)] = {
            'nodeid': test.attrib['classname'].replace('.', '/')+'.py::'+name,
            'outcome': 'failed' if failure is not None else (
                'skipped' if test.find('skipped') is not None else 'passed'),
            'failure': failure.text if failure is not None else None,
        }
    return result


def words(path):
    raw = path.read_bytes() if path.is_file() else b''
    return list(struct.unpack(f'<{len(raw)//2}H', raw))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', type=Path, nargs='+', help='Evidence directories from qa/run.py --screenshots')
    parser.add_argument('--output', type=Path, required=True, help='New gallery directory; never overwrite old evidence')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    sections, navigation, manifest = [], [], []
    for run_number, run in enumerate(args.runs, 1):
        fallback = older_cases(run)
        run_dest = args.output / f'run-{run_number:02d}'
        run_dest.mkdir()
        for name in ('manifest.json', 'junit.xml', 'pytest.log'):
            shutil.copy2(run / name, run_dest / name)
        for directory in sorted((run / 'work').iterdir()):
            if directory.is_symlink() or not (directory / 'screenshots.json').is_file():
                continue
            shots = read_json(directory / 'screenshots.json')
            if not shots:
                continue
            case = read_json(directory / 'case.json', fallback.get(directory.name))
            if case is None:
                raise ValueError(f'No test outcome for {directory}')
            case_id = f'case-{len(manifest)+1:03d}'
            dest = args.output / case_id
            dest.mkdir()
            title = case['nodeid'].split('::')[-1]
            base, _, parameters = title.partition('[')
            parameters = parameters.rstrip(']')
            app = read_json(directory / 'application.json', {})
            grid = read_json(directory / 'grid.json')
            if base in TITLES:
                title = TITLES[base]+' / '+parameters
            elif app:
                title = APPS.get(app['editor'], app['editor'])+' / '+parameters
            else:
                title = base+' / '+parameters
            initial = len(words(directory / 'STARTKEY.BIN'))
            keys = words(directory / 'KEYS.BIN')
            records = (directory / 'KEYLOG.BIN').read_bytes() if (directory / 'KEYLOG.BIN').is_file() else b''
            links, figures, images = [], [], []
            for name in ('APP.BIN', 'KEYLOG.BIN', 'INPUT.BIN', 'FONT20.BIN', 'DRAW.BIN',
                         'VIEW.TXT', 'SAVED.TXT', 'application.json', 'emulator.json',
                         'TEXTMODE.BIN', 'TEXT.BIN', 'GRID.BIN', 'grid.json',
                         'physical-keys.json', 'screenshots.json', 'provenance.json', 'dosbox.conf'):
                if (directory / name).is_file():
                    shutil.copy2(directory / name, dest / name)
                    links.append(f'<a href="{case_id}/{name}">{name}</a>')
            for index, shot in enumerate(shots):
                source = directory / shot['file']
                name = f'{index:03d}.png'
                shutil.copy2(source, dest / name)
                if shot['before_key'] == 0xffff:
                    caption = f'Frame {index}'
                    if base == 'test_native_font_storage_banks_and_cursor':
                        caption = ['Simplified', 'Traditional', 'Last cell XOR', 'Second XOR restores'][index]
                    elif base == 'test_vga_mode_change_without_text_change':
                        caption = ['Mode 1: Chinese', 'Mode 3: frames', 'Mode 1: Chinese', 'Mode 0: Western'][index]
                elif index < initial:
                    caption = f'Startup {index+1}'
                elif index == initial:
                    caption = 'Initial document'
                elif index <= initial+len(keys):
                    caption = 'After '+KEYS.get(keys[index-initial-1] >> 8, 'key')
                else:
                    caption = 'Exit menu'
                record = index-initial
                if records and 0 <= record < len(records)//164:
                    cursor, = struct.unpack_from('<H', records, record*164+2)
                    caption += f' · BIOS cursor ({cursor >> 8}, {cursor & 255}), zero based'
                caption += f' · {shot["width"]}×{shot["height"]}'
                if grid:
                    caption = ('Native mode before application' if index==0 else
                               'Application running' if index==1 else 'Before exit key') + caption[caption.index(' · '):]
                url = f'{case_id}/{name}'
                figures.append(f'<figure><a href="{url}"><img loading="lazy" src="{url}" '
                               f'alt="{html.escape(caption, quote=True)}"></a>'
                               f'<figcaption>{html.escape(caption)}</figcaption></figure>')
                images.append(dict(shot, file=url, caption=caption,
                                   sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
            cover = min(1 if grid else initial, len(figures)-1)
            emulator = read_json(directory / 'emulator.json', {})
            metadata = dict(case, title=title, run=run.name, directory=directory.name,
                            emulator=emulator, images=images, native_grid=grid,
                            drivers={name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
                                     for name in ('VGA.COM', 'VESA.COM', 'CKBD.COM')
                                     if (directory / name).is_file()})
            (dest / 'case.json').write_text(json.dumps(metadata, indent=2)+'\n')
            manifest.append(metadata)
            escaped = html.escape(title)
            navigation.append(f'<li><a href="#{case_id}">{escaped}</a> · {case["outcome"]}</li>')
            failure = ('<details open><summary>Assertion failure — retained evidence</summary><pre>'
                       +html.escape(case['failure'])+'</pre></details>') if case['failure'] else ''
            geometry = (f'<p>Native BIOS observation, without HHBIOS: '
                        f'{grid["before"][0]}×{grid["before"][1]} before launch → '
                        f'{grid["during"][0]}×{grid["during"][1]} while running.</p>') if grid else ''
            rest = ''.join(figure for index, figure in enumerate(figures) if index != cover)
            sections.append(f'<section id="{case_id}"><h2>{escaped}</h2>'
                            f'<p>Assertions: <strong>{case["outcome"]}</strong> · '
                            f'{html.escape(Path(emulator.get("path", "unknown")).name)} · '
                            f'<a href="run-{run_number:02d}/manifest.json">Source/tool hashes</a> · '
                            f'<a href="{case_id}/case.json">Case metadata</a></p>{failure}{geometry}'
                            +figures[cover]+(f'<details><summary>All {len(figures)} frames, in order</summary>'
                                            f'<div class="frames">{"".join(figures)}</div></details>' if rest else '')
                            +f'<details><summary>Raw observations</summary><p>{" · ".join(links)}</p></details></section>')
    if not manifest:
        raise ValueError('No screenshots found in the selected evidence bundles')
    count = sum(len(case['images']) for case in manifest)
    page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HHBIOS — DOS display screenshots</title><style>
body{font:16px/1.5 system-ui,sans-serif;margin:32px auto;padding:0 24px;max-width:1680px;background:#f5f4ef;color:#202428}
h1{font-size:32px}h2{font-size:23px}a{color:#174d83}section{border-top:1px solid #aaa;padding:24px 0;scroll-margin-top:12px}
figure{margin:16px 0;max-width:800px}img{display:block;max-width:100%;height:auto;image-rendering:pixelated}
figcaption{font-size:14px;margin-top:8px}summary{cursor:pointer;padding:10px 0}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#fce8df;padding:16px}
.frames{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,640px),1fr));gap:24px}nav{columns:2}p{max-width:1000px}
@media(max-width:700px){nav{columns:1}body{padding:0 12px}}
</style><h1>HHBIOS · DOS display screenshots</h1>
<p>Actual SDL window pixels, captured after the guest requests its next action.
No screenshot hotkeys, redraws or replacement glyphs. Click an image for the original PNG.
The HHBIOS console is 80×25 cells: VGA 640×480, VESA 800×600.
Cases labeled native BIOS run without HHBIOS and study existing text modes;
they do not demonstrate Chinese rendering in larger grids.</p>
<p>“Passed” describes the test assertions, not every visual detail. Framebuffer checks,
saved file bytes and cursor observations accompany the pictures. Capturing pauses key
delivery; these runs are not latency measurements. Failures are retained.</p>
'''
    page += f'<p>{len(manifest)} cases · {count} original PNGs</p><nav><ol>'
    page += ''.join(navigation)+'</ol></nav>'+''.join(sections)+'</html>\n'
    (args.output / 'index.html').write_text(page)
    (args.output / 'gallery.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'{args.output / "index.html"}: {len(manifest)} cases, {count} screenshots')


if __name__ == '__main__':
    main()
