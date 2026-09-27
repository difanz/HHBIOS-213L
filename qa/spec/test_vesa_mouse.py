"""Execute production INT 33h on foreign stacks; substitute only the device driver."""
import struct

import pytest
from unicorn import UC_HOOK_MEM_WRITE

from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark=pytest.mark.unit


def mouse(vesa_driver,rows=50,width=10,height=20):
    state=dict(position=(0,0),callback=(0,0,0),calls=[])
    def bios(m):
        fn=m.get('AX'); state['calls'].append(fn)
        if fn in (0,0x21):
            assert m.read('mouse_native')==b'\1' and m.uc.mem_read(0x449,1)==b'\x6a'
            m.put('AX',0xffff); m.put('BX',3); state['position']=(0,0)
        elif fn in (7,8): state[fn]=(m.get('CX'),m.get('DX'))
        elif fn==4:
            state['position']=tuple(max(state[f][0],min(v,state[f][1]))&~7
                                    for f,v in ((7,m.get('CX')),(8,m.get('DX'))))
        elif fn in (3,5,6):
            m.put('BX',2); m.put('CX',state['position'][0]); m.put('DX',state['position'][1])
        elif fn in (12,20):
            old=state['callback']; state['callback']=(m.get('CX'),m.get('ES'),m.get('DX'))
            if fn==20:
                for name,v in zip(('CX','ES','DX'),old): m.put(name,v)
        elif fn==0x0f: state['ratio']=(m.get('CX'),m.get('DX'))
        elif fn==0x15: m.put('BX',32)
        elif fn==0x16: m.uc.mem_write(m.get('ES')*16+m.get('DX'),b'D'*32)
        elif fn==0x17: assert m.uc.mem_read(m.get('ES')*16+m.get('DX'),32)==b'D'*32
        else: pytest.fail(f'unexpected mouse function {fn:04x}')
    m=Driver(vesa_driver,bios)
    m.write('old33',struct.pack('<HH',0xf000,0x1000))
    for name,value in dict(viewport_x=0 if width==16 else 240,viewport_y=2,text_rows=rows,raster_height=height,
                           font_width=width,
                           page_count=4 if rows>25 else 8).items():
        m.write(name,struct.pack('<H',value))
    m.write('active',b'\1')
    m.write('screen',struct.pack('<HH',1280,1024))
    m.write('hardware_mode',b'\x6a'); m.uc.mem_write(0x449,b'\x03')
    m.run('mouse_resume')
    assert m.read('mouse_native')==b'\0' and m.uc.mem_read(0x449,1)==b'\x03'
    return m,state


@pytest.mark.parametrize('rows,width,height',[(25,10,20),(43,10,20),(50,10,20),(25,12,29),(25,16,39)])
def test_mouse_query_set_ranges_and_cell_quantization(vesa_driver,rows,width,height):
    m,state=mouse(vesa_driver,rows,width,height)
    for x,y in ((0,0),(13,21),(639,rows*8-1),(32767,32767)):
        m.run('int33_handler',AX=4,CX=x,DX=y,DS=0x3000,ES=0x4000)
        assert m.get('DS')==0x3000 and m.get('ES')==0x4000
        m.run('int33_handler',AX=3)
        assert (m.get('BX'),m.get('CX'),m.get('DX'))==(2,min(x,639)&~7,min(y,rows*8-1)&~7)
    m.run('int33_handler',AX=7,CX=80,DX=159)
    m.run('int33_handler',AX=8,CX=40,DX=79)
    for v,expected in ((0,(80,40)),(32767,(152,72))):
        m.run('int33_handler',AX=4,CX=v,DX=v)
        for fn in (3,5,6):
            m.run('int33_handler',AX=fn)
            assert (m.get('CX'),m.get('DX'))==expected


def test_mouse_visibility_does_not_show_the_native_graphics_cursor(vesa_driver):
    m,state=mouse(vesa_driver)
    before=list(state['calls'])
    for fn in (1,2,2,1,1,10): m.run('int33_handler',AX=fn,BX=0,CX=0xffff,DX=0x7700)
    assert state['calls']==before


def test_mouse_entry_preserves_upper_register_halves(vesa_driver):
    m,state=mouse(vesa_driver)
    initial={name: 0xb1230000+i*0x10000 for i,name in
             enumerate(('EAX','EBX','ECX','EDX','ESI','EDI','EBP'))}
    m.run('int33_handler',**initial,AX=3,DS=0x3000,ES=0x4000)
    for name,value in initial.items():
        assert m.get(name)>>16==value>>16,name
    assert m.get('BX')==2


def test_mouse_callback_swap_and_translation(vesa_driver):
    m,state=mouse(vesa_driver)
    thunk=state['callback']
    m.run('int33_handler',AX=12,CX=3,ES=0x6000,DX=0x1234)
    m.run('int33_handler',AX=20,CX=7,ES=0x7000,DX=0x4567)
    assert (m.get('CX'),m.get('ES'),m.get('DX'))==(3,0x6000,0x1234)
    assert state['callback']==thunk
    packet=struct.pack('<10H',3,1,1039,1021,0x123,0x456,0x789,0x3000,0x4000,0x202)
    m.uc.mem_write(0x75000,packet)
    m.uc.mem_write(0x1e002,struct.pack('<HH',0x5000,0x7000))
    m.run('mouse_event')
    assert m.get('AX')==1
    result=struct.unpack('<10H',m.uc.mem_read(0x75000,20))
    assert result==(3,1,632,392,0x123,0x456,0x789,0x3000,0x4000,0x202)


def test_mouse_state_roundtrip_keeps_private_callback_and_ranges(vesa_driver):
    m,state=mouse(vesa_driver)
    m.run('int33_handler',AX=12,CX=3,ES=0x6000,DX=0x1234)
    m.run('int33_handler',AX=7,CX=80,DX=159)
    m.run('int33_handler',AX=0x15)
    assert m.get('BX')==96
    m.uc.mem_write(0x40000,b'\xa5'*128)
    m.run('int33_handler',AX=0x16,ES=0x4000,DX=16)
    assert m.uc.mem_read(0x40000,16)==m.uc.mem_read(0x40070,16)==b'\xa5'*16
    m.run('int33_handler',AX=0)
    m.run('int33_handler',AX=0x17,ES=0x4000,DX=16)
    m.run('int33_handler',AX=20,CX=0,ES=0,DX=0)
    assert (m.get('CX'),m.get('ES'),m.get('DX'))==(3,0x6000,0x1234)
    m.run('int33_handler',AX=4,CX=32767,DX=0)
    m.run('int33_handler',AX=3)
    assert m.get('CX')==152


def test_mickey_ratio_is_forwarded_without_using_state_storage(vesa_driver):
    m,state=mouse(vesa_driver)
    m.run('int33_handler',AX=0x0f,CX=8,DX=16)
    assert state['ratio']==(8,16)


def test_mouse_exclusion_and_show_use_logical_cells(vesa_driver):
    m,state=mouse(vesa_driver)
    m.run('int33_handler',AX=4,CX=624,DX=384)
    m.run('mouse_poll')
    m.run('int33_handler',AX=1)
    def visible():
        m.uc.mem_write(0x1e002,struct.pack('<H',48*256+78))
        m.run('mouse_covers')
        return m.get('AX')
    assert visible()
    m.run('int33_handler',AX=0x10,CX=624,DX=384,SI=631,DI=391)
    assert not visible()
    m.run('int33_handler',AX=1)
    assert visible()
    m.run('int33_handler',AX=2)
    assert not visible()


def test_stationary_mouse_and_caret_do_not_redraw_on_idle_ticks(vesa_driver):
    m, state = mouse(vesa_driver, rows=25)
    m.write('viewport_x', b'\0\0')
    m.write('viewport_y', b'\0\0')
    m.write('raster_height', struct.pack('<H', 23))
    m.run(AX=0x140d, BX=0x0100)
    m.run(AX=0x140b, BX=0)
    m.uc.mem_write(0xb8000, b' \x07'*2000)
    m.uc.mem_write(0x450, struct.pack('<H', 2))
    m.run('int33_handler', AX=1)
    m.run('tick', limit=20000000)
    writes = []
    m.uc.hook_add(UC_HOOK_MEM_WRITE,
        lambda uc, access, address, size, value, _: writes.append((address, size)),
        begin=0xa0000, end=0xaffff)
    for _ in range(8):
        m.run('tick', limit=20000000)
    assert not writes
    # Moving onto the caret, changing its masks, and changing B800 underneath
    # it must each repaint once; the following idle tick must settle again.
    for operation in ('move', 'shape', 'text', 'hide'):
        if operation == 'move':
            state['position'] = (20, 0)
        elif operation == 'shape':
            m.run('int33_handler', AX=10, BX=0, CX=0xffff, DX=0x3300)
        elif operation == 'text':
            m.uc.mem_write(0xb8004, b'A\x1f')
        else:
            m.run('int33_handler', AX=2)
        m.run('tick', limit=20000000)
        assert writes, operation
        writes.clear()
        m.run('tick', limit=20000000)
        assert not writes, operation
