"""Font-pixel expectations from source bitmaps, independent of ASM lookup tables."""
import functools
import struct
from qa.spec.dos import ROOT


@functools.lru_cache(maxsize=1)
def font20():
    return (ROOT/'fonts/HH20.FNT').read_bytes()


def native_rows(code, half=0, traditional=False):
    """Decode the distributed font, without the driver's cache/unpacking code."""
    data=font20()
    _,width,height,slots,count,size=struct.unpack_from('<8s4HI',data)
    assert (width,height,slots)==(10,23,8434) and len(data)==32+size
    slot=code if code<256 else 256+((code >> 8)-0xa1)*94+(code & 255)-0xa1
    if traditional and code>=256: slot+=slots
    index=struct.unpack_from('<H',data,32+slot*2)[0]
    assert index<count
    offset=32+slots*4+index*70
    return tuple((int.from_bytes(data[offset+y*3:offset+y*3+3],'big') >> (14-half*10)) & 1023
                 for y in range(height))


def glyph_rows(source, width=8, height=18):
    if len(source)==23:
        assert height in (20,23)
        return tuple(sum(((r >> (9-x*10//width)) & 1) << (width-1-x) for x in range(width)) for r in source[:height])
    assert len(source)==18 and width>0
    body=16 if height==18 else 20
    result=[]
    for y in range(height):
        sy=y*16//body if y<body else 16+(y-body)*2//(height-body)
        result.append(sum(((source[sy] >> (7-x*8//width)) & 1) << (width-1-x)
                          for x in range(width)))
    return tuple(result)


def colored_rows(source,width,height,attribute,plane):
    mask=(1 << width)-1
    fg=mask if attribute & (1 << plane) else 0
    bg=mask if (attribute >> 4) & (1 << plane) else 0
    return tuple((row & fg) | ((row ^ mask) & bg) for row in glyph_rows(source,width,height))
