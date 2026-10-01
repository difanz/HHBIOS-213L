"""EDID evidence, BIOS mode filtering and generated text geometry."""
import ctypes as C
import struct

import pytest

from qa.spec.test_setup import Machine, Choices, capable, setup_policy

pytestmark = pytest.mark.unit


def edid(width, height):
    data = bytearray(128)
    data[:8] = b'\x00\xff\xff\xff\xff\xff\xff\x00'
    data[18:20] = b'\x01\x03'
    data[24] = 2
    struct.pack_into('<H', data, 54, 14850)
    data[56:59] = bytes((width & 255, 160, (width >> 8) << 4))
    data[59:62] = bytes((height & 255, 30, (height >> 8) << 4))
    data[71] = 0x1e
    data[127] = -sum(data) & 255
    return data


def mode_info(width, height, *, bpp=4, pages=1):
    data = bytearray(256)
    pitch = ((width + 15) // 16 * 2) if bpp == 4 else width * 4
    struct.pack_into('<HBBHHHHIHHHHBBBB', data, 0, 0x9b, 7, 0, 64, 64,
                     0xa000, 0, 0, pitch, width, height, 0x1008,
                     4 if bpp == 4 else 1, bpp, 1, 3 if bpp == 4 else 6)
    data[29] = pages
    if bpp == 32:
        data[31:37] = bytes((8, 16, 8, 8, 8, 0))
    return data


def decode(lib, machine, data):
    lib.hh_edid(C.byref(machine), C.create_string_buffer(bytes(data)))


def add_mode(lib, machine, number, data):
    lib.hh_mode(C.byref(machine), number, C.create_string_buffer(bytes(data)))


@pytest.mark.parametrize('width,height', [(1280,720),(1280,800),(1366,768),(1920,1080),(1920,1200)])
def test_preferred_timing_uses_full_pixel_width(setup_policy, width, height):
    m = Machine()
    decode(setup_policy, m, edid(width, height))
    assert (m.edid_status, m.preferred_width, m.preferred_height) == (3, width, height)


@pytest.mark.parametrize('offset,value,status', [(0, 1, 1), (18, 2, 1), (19, 5, 1),
    (24, 0, 2), (71, 0x80, 2), (56, 0, 1)])
def test_unreliable_edid_never_claims_native_size(setup_policy, offset, value, status):
    data = edid(1280, 800)
    if offset == 56:
        data[58] &= 15
    data[offset] = value
    data[127] = -sum(data[:127]) & 255
    m = Machine(preferred_width=1920,preferred_height=1080)
    decode(setup_policy, m, data)
    assert (m.edid_status,m.preferred_width,m.preferred_height) == (status,0,0)


def test_checksum_and_empty_descriptor_are_not_resolution_evidence(setup_policy):
    m = Machine()
    data = edid(1920,1080); data[20] ^= 1
    decode(setup_policy,m,data)
    assert m.edid_status == 1 and not m.preferred_width
    data = edid(1920,1080); data[54:56] = b'\0\0'; data[127] = -sum(data[:127]) & 255
    decode(setup_policy,m,data)
    assert m.edid_status == 2 and not m.preferred_width


def test_catalog_separates_panel_bios_and_console_support(setup_policy):
    m,f = capable(); m.modes = 0
    decode(setup_policy,m,edid(1366,768))
    add_mode(setup_policy,m,0x201,mode_info(1366,768,bpp=32))
    assert m.preferred_bios == 1 and m.display_count == 0
    add_mode(setup_policy,m,0x220,mode_info(1920,1080))
    add_mode(setup_policy,m,0x221,mode_info(1366,768))
    add_mode(setup_policy,m,0x222,mode_info(1280,800))
    add_mode(setup_policy,m,0x221,mode_info(1366,768))
    assert [(x.number,x.width,x.height,x.rows) for x in m.display_modes[:m.display_count]] == [
        (0x222,1280,800,3),(0x221,1366,768,3),(0x220,1920,1080,7)]
    c = Choices(); setup_policy.hh_recommend(m,f,c)
    assert (c.video,c.mode) == (7,0x221)
    assert setup_policy.hh_validate(m,f,c) is None
    c.rows = 50
    assert b'cannot fit' in setup_policy.hh_validate(m,f,c)
    c.mode = 0x220
    assert setup_policy.hh_validate(m,f,c) is None
    out = C.create_string_buffer(4096)
    assert setup_policy.hh_batch(b'C:\\HHBIOS',c,out)
    assert b'.\\VESA.COM /M:220 /R:50\r\n' in out.value


@pytest.mark.parametrize('offset,value', [(0,0x9a),(16,170),(29,0),(24,1),(27,4),(8,1),(9,0xb0)])
def test_reject_incompatible_1366_mode(setup_policy,offset,value):
    m = Machine(vbe_version=0x200)
    data = mode_info(1366,768)
    data[offset] = value
    add_mode(setup_policy,m,0x321,data)
    assert m.display_count == 0


def test_bounded_mode_catalog_does_not_overrun(setup_policy):
    m = Machine(vbe_version=0x200)
    for number in range(0x200,0x405):
        add_mode(setup_policy,m,number,mode_info(1280,800))
    assert m.display_count == 512 and m.display_truncated == 1
    assert m.display_modes[511].number == 0x3ff
    assert m.bios_mode_count == 512


def test_complete_catalog_keeps_color_modes_and_rejection_reasons(setup_policy):
    m = Machine(vbe_version=0x200)
    add_mode(setup_policy, m, 0x242, mode_info(1920, 1080))
    add_mode(setup_policy, m, 0x243, mode_info(1920, 1080, bpp=32))
    add_mode(setup_policy, m, 0x106, mode_info(1280, 1024, pages=0))
    small = mode_info(640, 480)
    add_mode(setup_policy, m, 0x12f, small)
    text = mode_info(132, 50)
    struct.pack_into('<H', text, 0, 9)
    add_mode(setup_policy, m, 0x109, text)
    unavailable = mode_info(800, 600)
    unavailable[0] &= ~1
    add_mode(setup_policy, m, 0x200, unavailable)
    add_mode(setup_policy, m, 0x242, mode_info(1920, 1080))
    assert m.display_count == 1
    assert [(mode.number, mode.status) for mode in m.bios_modes[:m.bios_mode_count]] == [
        (0x109, 2), (0x12f, 4), (0x200, 1), (0x106, 5), (0x242, 0), (0x243, 3)]


def test_direct_color_linear_modes_are_listed(setup_policy):
    m = Machine(vbe_version=0x200)
    listed = mode_info(1024, 768, bpp=16)
    listed[16:18] = struct.pack('<H', 1024 * 2)
    listed[31:37] = bytes((5, 11, 6, 5, 5, 0))
    struct.pack_into('<I', listed, 40, 0xe0000000)
    add_mode(setup_policy, m, 0x117, listed)
    windowless = bytearray(listed)
    windowless[8:10] = b'\0\0'
    windowless[2] = 0
    add_mode(setup_policy, m, 0x118, windowless)
    odd = bytearray(listed)
    odd[25] = 24
    odd[16:18] = struct.pack('<H', 1024 * 3)
    add_mode(setup_policy, m, 0x119, odd)
    assert [(x.number, x.width, x.height, x.rows) for x in m.display_modes[:m.display_count]] == [
        (0x117, 1024, 768, 3), (0x118, 1024, 768, 1)]
    assert [(mode.number, mode.status) for mode in m.bios_modes[:m.bios_mode_count]] == [
        (0x117, 0), (0x118, 0), (0x119, 3)]


@pytest.mark.parametrize('video,rows', [(0,43),(4,50),(7,60),(3,51),(3,0xffff)])
def test_unsupported_text_layout_never_reaches_batch(setup_policy,video,rows):
    m,f = capable(); c = Choices(0,0,video,0,1,0x106,rows)
    assert setup_policy.hh_validate(m,f,c)
    assert not setup_policy.hh_batch(b'C:\\HHBIOS',c,C.create_string_buffer(4096))
