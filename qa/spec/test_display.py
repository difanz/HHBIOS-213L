import pytest
import random
import unicodedata

from qa.spec.machine import FRAME_ALIASES, blank, put

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('text', ['中文', '屯', '览', '测试汉字', '喃後岐徵'])
@pytest.mark.parametrize('col', [0, 1, 8, 71])
def test_chinese(machine, text, col):
    raw = text.encode('gb2312')
    screen = blank()
    put(screen, 3, col, raw)
    machine.scan(screen)
    for i in range(0, len(raw), 2):
        code = int.from_bytes(raw[i:i+2], 'big')
        assert machine.cell(3, col+i) == ('hanzi-left', code, 7)
        assert machine.cell(3, col+i+1) == ('hanzi-right', code, 7)


@pytest.mark.parametrize('row', [0, 12, 24])
def test_streamed_chinese_keeps_bytes_from_previous_scan(machine,row):
    from qa.spec.machine import SCREEN
    raw='2.13L 汉字系统键盘模块 1999.11.17'.encode('gb2312')
    screen=blank()
    for col,byte in enumerate(raw):
        put(screen,row,col,bytes([byte]))
        machine.scan(screen)
        # A real console changes only the next byte, retaining any aliases
        # the preceding refresh wrote into guest video memory.
        screen=bytearray(machine.uc.mem_read(SCREEN,4000))
    for col in range(6,22,2):
        code=int.from_bytes(raw[col:col+2],'big')
        assert machine.cell(row,col)==('hanzi-left',code,7)


@pytest.mark.parametrize('frame', ['┌─┐│└─┘', '╔═╗║╚═╝', '╒═╕│╘═╛', '╓─╖║╙─╜'])
@pytest.mark.parametrize('row,col', [(0, 0), (0, 77), (22, 0), (22, 77), (5, 9)])
def test_small_boxes(machine, frame, row, col):
    top, middle, bottom = frame[:3], frame[3], frame[4:]
    screen = blank()
    for dr, line in enumerate([top, middle + ' ' + middle, bottom]):
        put(screen, row+dr, col, line.encode('cp437'))
    machine.scan(screen)
    for dr, line in enumerate([top, middle + ' ' + middle, bottom]):
        for dc, ch in enumerate(line.encode('cp437')):
            assert machine.cell(row+dr, col+dc) == ('char', ch, 7)


def test_chinese_touching_frame(machine):
    screen = blank()
    put(screen, 0, 0, '╔═════╗'.encode('cp437'))
    put(screen, 1, 0, b'\xba' + '中文'.encode('gb2312') + b' \xba')
    put(screen, 2, 0, '╚═════╝'.encode('cp437'))
    machine.scan(screen)
    assert machine.cell(1, 0) == ('char', 0xba, 7)
    assert machine.cell(1, 1) == ('hanzi-left', 0xd6d0, 7)
    assert machine.cell(1, 3) == ('hanzi-left', 0xcec4, 7)


@pytest.mark.parametrize('offset,replacement', [(0, 0xe1), (1, 0xac), (0, 32), (1, 32), (0, 65), (1, 65)])
def test_partial_update_preserves_guest_bytes_and_repaints(machine, offset, replacement):
    screen = blank()
    put(screen, 2, 4, b'\xe0\xab')
    machine.scan(screen)
    screen[2 * (2 * 80 + 4 + offset)] = replacement
    machine.scan(screen)
    if replacement > 0xa0:
        code = screen[2 * 164] << 8 | screen[2 * 165]
        assert machine.cell(2, 4) == ('hanzi-left', code, 7)
        assert machine.cell(2, 5) == ('hanzi-right', code, 7)
    else:
        for col in (4, 5):
            assert machine.cell(2, col) == ('char', screen[2 * (160+col)], 7)


@pytest.mark.parametrize('row,col', [(0, 0), (0, 79), (24, 0), (24, 79)])
@pytest.mark.parametrize('code', [0xb0, 0xb3, 0xc4, 0xcd, 0xdf, 0xff])
def test_screen_edges(machine, row, col, code):
    screen = blank()
    put(screen, row, col, bytes((code,)))
    machine.scan(screen)
    assert machine.cell(row, col) == ('char', code, 7)


def test_no_change_does_not_redraw(machine):
    screen = blank()
    put(screen, 1, 4, '中文')
    machine.scan(screen)
    machine.scan(screen)
    assert machine.draws == []


@pytest.mark.parametrize('mode', [0, 1, 2, 3])
def test_ambiguous_bytes_obey_mode(machine, mode):
    screen = blank()
    put(screen, 1, 0, b'\xcd' * 40)
    machine.scan(screen, mode)
    for col in range(40):
        if mode == 1:
            assert machine.cell(1, col) == ('hanzi-left' if col % 2 == 0 else 'hanzi-right', 0xcdcd, 7)
        else:
            assert machine.cell(1, col) == ('char', 0xcd, 7)


def test_attribute_only_change_redraws_both_halves(machine):
    screen = blank()
    put(screen, 1, 0, '中文')
    machine.scan(screen)
    screen[163] = 0x1e
    machine.scan(screen)
    assert machine.cell(1, 0) == ('hanzi-left', 0xd6d0, 7)
    assert machine.cell(1, 1) == ('hanzi-right', 0xd6d0, 0x1e)


def test_neighbor_change_reclassifies_unchanged_bytes(machine):
    screen = blank()
    put(screen, 1, 0, b'\xc9\xcd')
    machine.scan(screen)
    assert machine.cell(1, 0) == ('hanzi-left', 0xc9cd, 7)
    put(screen, 2, 0, b'\xba')
    machine.scan(screen)
    assert machine.cell(1, 0) == ('char', 0xc9, 7)
    assert machine.cell(1, 1) == ('char', 0xcd, 7)
    put(screen, 2, 0, b' ')
    machine.scan(screen)
    assert machine.cell(1, 0) == ('hanzi-left', 0xc9cd, 7)


@pytest.mark.parametrize('col', [0, 1, 2, 78, 79])
def test_teletype_backspace_moves_one_cell_without_erasing(machine, col):
    import struct
    from qa.spec.machine import CODE, SCREEN
    screen = blank()
    put(screen, 1, 0, '中文')
    machine.scan(screen)
    machine.uc.mem_write(0x450, struct.pack('<H', 0x100 + col))
    machine.uc.mem_write(CODE + machine.symbols['pending'], b'\xe0')
    machine.call('teletype', AX=0x0e08, DS=0)
    assert bytes(machine.uc.mem_read(0x450, 2)) == struct.pack('<H', 0x100 + max(0, col-1))
    assert bytes(machine.uc.mem_read(SCREEN, 4000)) == bytes(screen)


def stroke_directions(code):
    # Independent semantic oracle: Unicode names, not the driver's bit table.
    name = unicodedata.name(bytes((code,)).decode('cp437')).removeprefix('BOX DRAWINGS ')
    default = 2 if name.startswith('DOUBLE ') else 1
    directions = {}
    for clause in name.split(' AND '):
        weight = 2 if 'DOUBLE' in clause else 1 if 'SINGLE' in clause or 'LIGHT' in clause else default
        for axis, sides in [('VERTICAL', ('UP', 'DOWN')), ('HORIZONTAL', ('LEFT', 'RIGHT')),
                            ('UP', ('UP',)), ('DOWN', ('DOWN',)), ('LEFT', ('LEFT',)), ('RIGHT', ('RIGHT',))]:
            if axis in clause.split():
                directions.update({side: weight for side in sides})
    return directions


@pytest.mark.parametrize('code', range(0xb3, 0xdb), ids=lambda code: f'cp437-{code:02x}')
def test_frame_stroke_properties(machine, code):
    expected = sum(weight << {'DOWN': 6, 'LEFT': 4, 'UP': 2, 'RIGHT': 0}[side]
                   for side, weight in stroke_directions(code).items())
    for value in (code, FRAME_ALIASES[code]):
        machine.call('stroke', BX=value)
        assert machine.read('EFLAGS') & 1 == 0, f'unrecognized frame byte {value:02x}'
        assert machine.read('DX') >> 8 == expected
        assert machine.read('BX') == value, 'property lookup changed BX'


@pytest.mark.parametrize('code', [code for code in range(0xb3, 0xdb) if code not in (0xb3, 0xba, 0xc4, 0xcd)],
                         ids=lambda code: f'cp437-{code:02x}')
def test_every_corner_and_junction(machine, code):
    screen = blank()
    put(screen, 12, 40, bytes((code,)))
    for direction, weight in stroke_directions(code).items():
        dr, dc = {'UP': (-1, 0), 'DOWN': (1, 0), 'LEFT': (0, -1), 'RIGHT': (0, 1)}[direction]
        stroke = (0xb3 if weight == 1 else 0xba) if dr else (0xc4 if weight == 1 else 0xcd)
        put(screen, 12+dr, 40+dc, bytes((stroke,)))
    machine.scan(screen)
    assert machine.cell(12, 40) == ('char', code, 7)


@pytest.mark.parametrize('bad', [0xa0, 0xff])
@pytest.mark.parametrize('side', [0, 1])
def test_invalid_dbcs_byte_never_pairs(machine, bad, side):
    screen = blank()
    raw = bytearray(b'\xe0\xab')
    raw[side] = bad
    put(screen, 3, 1, raw)
    machine.scan(screen, mode=1)
    assert machine.cell(3, 1) == ('char', raw[0], 7)
    assert machine.cell(3, 2) == ('char', raw[1], 7)


def test_incremental_render_equals_fresh_render(display_binary):
    from qa.spec.machine import DisplayMachine
    rng = random.Random(213)
    machine = DisplayMachine(display_binary)
    screen = blank()
    for step in range(32):
        row, col = rng.choice([0, 1, 12, 23, 24]), rng.randrange(75)
        text = rng.choice([b'\xe0\xab', b'\xe1\xe1', b'\xc9\xcd\xbb', b'  A', b'\xba', b'\xff'])
        put(screen, row, col, text, rng.choice([7, 0x1e, 0x4f]))
        machine.scan(screen)
        fresh = DisplayMachine(display_binary)
        fresh.scan(screen)
        assert machine.pixels == fresh.pixels, f'incremental damage at deterministic step {step}'


def test_hanzi_disable_switch_preserves_legacy_api(machine):
    from qa.spec.machine import CODE
    screen = blank()
    put(screen, 1, 0, b'\xe0\xab')
    machine.uc.mem_write(CODE + machine.symbols['hanzi_switch'], b'\xeb')
    machine.scan(screen)
    assert machine.cell(1, 0) == ('char', 0xe0, 7)
    assert machine.cell(1, 1) == ('char', 0xab, 7)


@pytest.mark.parametrize('top', [True, False])
@pytest.mark.parametrize('arrow', [0x18, 0x1e])
def test_scrollbar_arrow_connects_short_frame_cap(machine, top, arrow):
    screen = blank()
    row = 1 if top else 23
    put(screen, row, 78, b'\xcd' + (b'\xbb' if top else b'\xbc'), 0x1f)
    put(screen, row+(1 if top else -1), 79, bytes([arrow if top else arrow+1]), 0x1a)
    machine.scan(screen)
    assert machine.cell(row, 78) == ('char', 0xcd, 0x1f)
    assert machine.cell(row, 79) == ('char', 0xbb if top else 0xbc, 0x1f)


@pytest.mark.parametrize('lead', range(0xf8, 0xff))
def test_lead_beyond_loaded_font_is_not_dereferenced(machine, lead):
    screen = blank()
    put(screen, 2, 4, bytes((lead, 0xa1)))
    machine.scan(screen, 1)
    assert machine.cell(2, 4) == ('char', lead, 7)
    assert machine.cell(2, 5) == ('char', 0xa1, 7)


def test_frame_colors_do_not_change_topology(machine):
    screen = blank()
    for row, line in enumerate(['┌─┬─┐', '│ │ │', '├─┼─┤', '│ │ │', '└─┴─┘']):
        for col, code in enumerate(line.encode('cp437')):
            put(screen, row, col, bytes((code,)), 1 + (row*5+col) % 15)
    machine.scan(screen)
    for row in range(5):
        for col in range(5):
            code, attr = screen[(row*80+col)*2:(row*80+col)*2+2]
            assert machine.cell(row, col) == ('char', code, attr)


def test_pending_lead_is_flushed_at_row_boundary(machine):
    screen = blank()
    put(screen, 0, 79, b'\xe0')
    put(screen, 1, 0, b'\xabA\xe1\xe1')
    machine.scan(screen, 1)
    assert machine.cell(0, 79) == ('char', 0xe0, 7)
    assert machine.cell(1, 0) == ('char', 0xab, 7)
    assert machine.cell(1, 2) == ('hanzi-left', 0xe1e1, 7)


def test_pending_lead_is_flushed_before_frame(machine):
    screen = blank()
    put(screen, 0, 1, '╔═╗'.encode('cp437'))
    put(screen, 1, 0, b'\xe0\xba \xba\xe1\xe1')
    put(screen, 2, 1, '╚═╝'.encode('cp437'))
    machine.scan(screen)
    assert machine.cell(1, 0) == ('char', 0xe0, 7)
    assert machine.cell(1, 1) == ('char', 0xba, 7)
    assert machine.cell(1, 3) == ('char', 0xba, 7)
    assert machine.cell(1, 4) == ('hanzi-left', 0xe1e1, 7)


@pytest.mark.parametrize('mode', [0, 1, 2, 3])
def test_short_upper_block_run_obeys_display_mode(machine, mode):
    screen = blank()
    put(screen, 3, 4, b'\xdf\xdf')
    machine.scan(screen, mode)
    if mode == 1:
        assert machine.cell(3, 4) == ('hanzi-left', 0xdfdf, 7)
        assert machine.cell(3, 5) == ('hanzi-right', 0xdfdf, 7)
    else:
        # Two upper blocks are a FoxPro UI pattern in modes 2/3; the public
        # table's A0h alias displays the original CP437 DFh glyph.
        for col in (4, 5):
            assert machine.cell(3, col) == ('char', 0xdf, 7)


def test_existing_frame_aliases_bound_chinese(machine):
    screen = blank()
    put(screen, 1, 0, b'\x15' + '中文'.encode('gb2312') + b'\x15')
    machine.scan(screen)
    assert machine.cell(1, 0) == ('char', 0xba, 7)
    assert machine.cell(1, 1) == ('hanzi-left', 0xd6d0, 7)
    assert machine.cell(1, 3) == ('hanzi-left', 0xcec4, 7)
    assert machine.cell(1, 5) == ('char', 0xba, 7)


def test_normalized_frame_does_not_redraw(machine):
    from qa.spec.machine import SCREEN
    screen = blank()
    for row, line in enumerate(['╔═╗', '║ ║', '╚═╝']):
        put(screen, row, 0, line.encode('cp437'))
    machine.scan(screen)
    machine.scan(machine.uc.mem_read(SCREEN, 4000))
    assert machine.draws == []


def test_adjacent_open_top_panes_use_connected_bottom_corners(machine):
    screen = blank()
    for row in range(6, 21):
        put(screen, row, 35, b'\xb3\xb3')
    put(screen, 21, 34, '─┘└─'.encode('cp437'))
    machine.scan(screen)
    for row in range(6, 21):
        for col in (35, 36):
            assert machine.cell(row, col) == ('char', 0xb3, 7)


@pytest.mark.parametrize('row,col', [(0, 0), (11, 5), (22, 64)])
@pytest.mark.parametrize('labels', [
    ('字库存放：', '程序驻留：', '显示驱动：'),
    ('卢', '程', ''),  # C2 above B3 also resembles a vertical connection.
])
def test_stacked_chinese_does_not_form_vertical_frames(machine, row, col, labels):
    from qa.spec.machine import SCREEN
    screen = blank()
    for index, label in enumerate(labels):
        put(screen, row + index, col, label, 0x1b + index)
    machine.scan(screen)
    assert bytes(machine.uc.mem_read(SCREEN, 4000)) == screen
    for index, label in enumerate(labels):
        raw = label.encode('gb2312')
        for position in range(0, len(raw), 2):
            code = int.from_bytes(raw[position:position + 2], 'big')
            assert machine.cell(row + index, col + position) == (
                'hanzi-left', code, 0x1b + index)
            assert machine.cell(row + index, col + position + 1) == (
                'hanzi-right', code, 0x1b + index)
    machine.scan(screen)
    assert not machine.draws


@pytest.mark.parametrize('lines', [('┌─┬─┐', '│ │ │', '└─┴─┘'),
                                   ('╔═╤═╗', '║ │ ║', '╚═╧═╝'),
                                   ('╓─┬─╖', '║ │ ║', '╙─┴─╜')])
def test_vertical_junctions_keep_stacked_chinese_in_neighboring_pane(machine, lines):
    screen = blank()
    for row, line in enumerate(lines, 5):
        put(screen, row, 2, line.encode('cp437'), 0x2e)
    put(screen, 5, 10, '程序驻留', 0x1b)
    put(screen, 6, 10, '显示驱动', 0x1b)
    machine.scan(screen)
    for row, line in enumerate(lines, 5):
        for column, character in enumerate(line.encode('cp437'), 2):
            assert machine.cell(row, column) == ('char', character, 0x2e)
    assert machine.cell(5, 10) == ('hanzi-left', 0xb3cc, 0x1b)
    assert machine.cell(6, 10) == ('hanzi-left', 0xcfd4, 0x1b)


@pytest.mark.parametrize('parent', [b'[-]', b'[+]', b'   '])
def test_directory_branch_requires_a_parent_node(machine, parent):
    screen = blank()
    put(screen, 6, 2, parent)
    put(screen, 7, 3, b'\xc0\xc4[ ] CHILD')
    machine.scan(screen)
    if parent == b'   ':
        assert machine.cell(7, 3) == ('hanzi-left', 0xc0c4, 7)
    else:
        assert machine.cell(7, 3) == ('char', 0xc0, 7)
        assert machine.cell(7, 4) == ('char', 0xc4, 7)


@pytest.mark.parametrize('column', [1, 3, 75])
@pytest.mark.parametrize('parent', [b'[-]', b'[+]', b'   '])
def test_directory_siblings_and_last_branch(machine, column, parent):
    screen = blank()
    put(screen, 0, column-1, parent)
    for row in range(1, 25):
        branch = 0xc0 if row == 24 else 0xc3
        put(screen, row, column, bytes([branch, 0xc4])+b'[ ]')
    machine.scan(screen)
    for row in range(1, 25):
        branch = 0xc0 if row == 24 else 0xc3
        # A connected set of siblings remains a tree when scrolling hides
        # its parent above the viewport.
        assert machine.cell(row, column) == ('char', branch, 7)
        assert machine.cell(row, column+1) == ('char', 0xc4, 7)


@pytest.mark.parametrize('row,column', [(0, 0), (4, 8), (21, 75)])
@pytest.mark.parametrize('gap', [False, True])
def test_clipped_directory_siblings(machine, row, column, gap):
    from qa.spec.machine import SCREEN
    screen = blank()
    put(screen, row, column, b'\xc3\xc4[ ]')
    if gap:
        put(screen, row+1, column, b'\xb3')
    last = row+1+gap
    put(screen, last, column, b'\xc0\xc4[ ]')
    put(screen, 24, 20, '媚[ ] 滥[ ] 中文')
    # The keyboard boundary API can run before the renderer converts frames.
    machine.uc.mem_write(SCREEN, bytes(screen))
    for r in (row, last):
        for c in (column, column+1):
            machine.call('keypos', DX=(r << 8)+c)
            assert machine.read('AX') == 0
    assert bytes(machine.uc.mem_read(SCREEN, 4000)) == screen
    machine.scan(screen)
    for r, code in ((row, 0xc3), (last, 0xc0)):
        assert machine.cell(r, column) == ('char', code, 7)
        assert machine.cell(r, column+1) == ('char', 0xc4, 7)
    assert machine.cell(24, 20) == ('hanzi-left', 0xc3c4, 7)
    assert machine.cell(24, 26) == ('hanzi-left', 0xc0c4, 7)


@pytest.mark.parametrize('marker', ['+', '-'])
@pytest.mark.parametrize('column', [0, 8, 75])
def test_pctools_child_under_parent_bracket(machine, marker, column):
    screen = blank()
    put(screen, 5, column, f'[{marker}]')
    put(screen, 6, column, b'\xc0\xc4[ ]')
    machine.scan(screen)
    assert machine.cell(6, column) == ('char', 0xc0, 7)
    assert machine.cell(6, column+1) == ('char', 0xc4, 7)


@pytest.mark.parametrize('top,bottom,gap', [(0xc0, 0xc0, 0), (0xc0, 0xc3, 0),
                                         (0xc0, 0xc0, 1), (0xc3, 0xc0, 1)])
def test_directory_branches_need_an_unbroken_connection(machine, top, bottom, gap):
    screen = blank()
    put(screen, 3, 8, bytes([top, 0xc4])+b'[ ]')
    # A terminal branch cannot lead down; a blank row breaks a valid stem.
    put(screen, 4+gap, 8, bytes([bottom, 0xc4])+b'[ ]')
    machine.scan(screen)
    assert machine.cell(3, 8) == ('hanzi-left', top*256+0xc4, 7)
    assert machine.cell(4+gap, 8) == ('hanzi-left', bottom*256+0xc4, 7)


@pytest.mark.parametrize('arrow', [0x18, 0x1e])
def test_qbasic_short_scrollbar_cap(machine, arrow):
    screen = blank()
    put(screen, 1, 75, b'\xb4\x18\xc3\xc4\xbf', 0x1f)
    put(screen, 2, 79, bytes([arrow]), 0x17)
    machine.scan(screen)
    for column, code in enumerate(b'\xc3\xc4\xbf', 77):
        assert machine.cell(1, column) == ('char', code, 0x1f)


@pytest.mark.parametrize('row,column', [(0, 0), (5, 21), (20, 72)])
@pytest.mark.parametrize('cap', ['top', 'bottom'])
def test_half_block_panel_keeps_separator_and_chinese(machine, row, column, cap):
    from qa.spec.machine import SCREEN
    screen = blank()
    top = b'\xdf'*6 if cap == 'top' else b' title'
    bottom = b'\xdc'*6 if cap == 'bottom' else b' label'
    lines = [b'\xde'+top+b'\xdd', b'\xde\xfa\xfa\xfa\xfa\xfa\xfa\xdd',
             b'\xde'+'中文'.encode('gb2312')+b'  \xdd', b'\xde'+bottom+b'\xdd']
    for i, line in enumerate(lines):
        put(screen, row+i, column, line, 0x70+i)
    machine.uc.mem_write(SCREEN, bytes(screen))
    # Query before aliases exist, as the whole-Hanzi keyboard filter does.
    for c in (column, column+1, column+7):
        machine.call('keypos', DX=((row+1) << 8)+c)
        assert machine.read('AX') == 0
    machine.scan(screen)
    for c, code in enumerate(lines[1]):
        assert machine.cell(row+1, column+c) == ('char', code, 0x71)
    assert machine.cell(row+2, column+1) == ('hanzi-left', 0xd6d0, 0x72)
    assert machine.cell(row+2, column+3) == ('hanzi-left', 0xcec4, 0x72)
    actual = bytearray(machine.uc.mem_read(SCREEN, 4000))
    for r in (row+1, row+2):
        assert actual[2*(r*80+column)] == 0xde
        assert actual[2*(r*80+column+7)] == 0xdd
    machine.scan(actual)
    assert not machine.draws, 'Unchanged bevels must not repaint'


@pytest.mark.parametrize('row,column', [(0, 0), (5, 21), (22, 68)])
def test_repeated_half_block_bytes_in_chinese_are_not_a_panel(machine, row, column):
    screen = blank()
    for i, line in enumerate(('搡 中文 甍', '薨 中文 萃', '弈 中文 菽')):
        put(screen, row+i, column, line)
    machine.scan(screen)
    for i, line in enumerate(('搡 中文 甍', '薨 中文 萃', '弈 中文 菽')):
        raw = line.encode('gb2312')
        for c in (0, 3, 5, 8):
            assert machine.cell(row+i, column+c) == ('hanzi-left', int.from_bytes(raw[c:c+2], 'big'), 7)


@pytest.mark.parametrize('mode', [1, 2])
def test_connected_corners_do_not_override_explicit_modes(machine, mode):
    screen = blank()
    put(screen, 1, 0, b'\xc9\xcd')
    put(screen, 2, 0, b'\xba')
    machine.scan(screen, mode)
    assert machine.cell(1, 0) == ('hanzi-left', 0xc9cd, 7)
