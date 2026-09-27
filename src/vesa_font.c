/* HH Console 20: bounded glyph cache; XMS or EMS 4.0 owns the font payload.
 * File I/O and allocation occur only before display installation. */
#include "vesa.h"

#define FONT_SLOTS 8434U
#define FONT_MAP_BYTES (FONT_SLOTS*4UL)
#define FONT_RECORD 70U
#define RECORD_OFFSET(n) (((u32)(n) << 6) + ((u32)(n) << 2) + ((u32)(n) << 1))
#define FONT_CACHE 16U

u32 CALL font_entry;
u16 CALL font_kind, font_handle, font_kb, font_fault;
static u16 records, next_slot;
static u32 text_storage;
static u16 keys[FONT_CACHE], valid[FONT_CACHE];
static u8 cache[FONT_CACHE][FONT_RECORD];
extern u8 CALL text_transfer[8192];
void CALL font_service(u16 kind, struct registers *r);

#pragma pack(push, 1)
struct xmove { u32 size; u16 source; u32 from; u16 destination; u32 to; };
struct emove { u32 size; u8 source_type; u16 source, from, source_page;
              u8 destination_type; u16 destination, to, destination_page; };
#pragma pack(pop)

static void clear(void *p, u16 size)
{
    u8 *b=p;
    while (size--) *b++=0;
}

static int transfer(u32 offset, void *buffer, u16 size, u16 writing)
{
    struct registers r;
    struct xmove x;
    struct emove e;
    clear(&r,sizeof(r)); r.ds=resident_segment;
    if (font_kind==1) {
        x.size=size; x.source=writing ? 0 : font_handle;
        x.destination=writing ? font_handle : 0;
        x.from=writing ? ((u32)resident_segment << 16) | (u16)buffer : offset;
        x.to=writing ? offset : ((u32)resident_segment << 16) | (u16)buffer;
        r.ax=0x0b00; r.si=(u16)&x; font_service(3,&r);
        return r.ax==1;
    }
    if (font_kind!=2) return 0;
    clear(&e,sizeof(e)); e.size=size;
    if (writing) {
        e.from=(u16)buffer; e.source_page=resident_segment;
        e.destination_type=1; e.destination=font_handle;
        e.to=(u16)offset & 0x3fff; e.destination_page=(u16)(offset >> 14);
    } else {
        e.source_type=1; e.source=font_handle;
        e.from=(u16)offset & 0x3fff; e.source_page=(u16)(offset >> 14);
        e.to=(u16)buffer; e.destination_page=resident_segment;
    }
    r.ax=0x5700; r.si=(u16)&e; font_service(2,&r);
    return !(r.ax & 0xff00);
}

void CALL font_get(u16 code, u16 *out)
{
    u16 slot, i, id, y;
    u8 *p;
    clear(out,CELL_HEIGHT*4);
    if (code<256) slot=code;
    else {
        if ((code >> 8)<0xa1 || (code >> 8)>0xf7 ||
            (code & 255)<0xa1 || (code & 255)>0xfe) return;
        slot=256+((code >> 8)-0xa1)*94+(code & 255)-0xa1;
        if (!traditional) slot+=FONT_SLOTS;
    }
    for (i=0; i<FONT_CACHE; ++i)
        if (valid[i] && keys[i]==slot) break;
    if (i==FONT_CACHE) {
        i=next_slot; next_slot=(next_slot+1) % FONT_CACHE; valid[i]=0;
        if (!transfer((u32)slot*2,&id,2,0) || id>=records ||
            !transfer(FONT_MAP_BYTES+RECORD_OFFSET(id),cache[i],FONT_RECORD,0)) {
            font_fault=1;
            return;
        }
        keys[i]=slot; valid[i]=1;
    }
    p=cache[i];
    for (y=0; y<CELL_HEIGHT; ++y,p+=3) {
        out[y]=(((u16)p[0] << 8) | p[1]) & 0xffc0;
        out[y+CELL_HEIGHT]=((u16)p[1] << 10) | ((u16)p[2] << 2);
    }
}

/* HHBIOS's public 8x16 bitmap interface retains its original input format. */
void CALL font_bitmap(u8 *source, u16 *out)
{
    u16 x,y,bits;
    for (y=0; y<20; ++y) {
        bits=0;
        for (x=0; x<10; ++x)
            bits=(bits << 1) | ((source[y*16/20] >> (7-x*8/10)) & 1);
        out[y]=bits << 6;
    }
    for (; y<CELL_HEIGHT; ++y) out[y]=0;
}

/* Preserve the entire B800 aperture across a physical mode/bank probe. The
 * extra 32 KiB lives in the existing XMS/EMS allocation, not conventional RAM. */
u16 CALL font_text(u16 saving)
{
    u16 off,i;
    u8 FAR *text=PTR(u8,0xb800,0);
    for (off=0;off<32768;off+=4096) {
        if (saving) for (i=0;i<4096;++i) text_transfer[i]=text[off+i];
        if (!transfer(text_storage+off,text_transfer,4096,saving)) return 0;
        if (!saving) for (i=0;i<4096;++i) text[off+i]=text_transfer[i];
    }
    return 1;
}

#pragma code_seg("INIT_TEXT", "INIT")
void CALL font_close(void)
{
    struct registers r;
    clear(&r,sizeof(r)); r.dx=font_handle;
    if (font_kind) {
        r.ax=font_kind==1 ? 0x0a00 : 0x4500;
        font_service(font_kind==1 ? 3 : 2,&r);
    }
    font_kind=font_handle=0;
}

static int allocate(u16 kb)
{
    struct registers r;
    u8 FAR *name;
    u16 i;
    clear(&r,sizeof(r)); r.ax=0x4300; font_service(1,&r);
    if ((r.ax & 255)==0x80) {
        r.ax=0x4310; font_service(1,&r);
        font_entry=((u32)r.es << 16) | r.bx;
        r.ax=0x0900; r.dx=kb; font_service(3,&r);
        if (r.ax==1) { font_handle=r.dx; font_kind=1; return 1; }
    }
    /* Check the EMS device signature before invoking an arbitrary INT 67. */
    clear(&r,sizeof(r)); r.ax=0x3567; font_service(0,&r);
    name=PTR(u8,r.es,10);
    for (i=0; i<8; ++i) if (name[i]!="EMMXXXX0"[i]) return 0;
    r.ax=0x4600; font_service(2,&r);
    if ((r.ax & 0xff00) || (r.ax & 255)<0x40) return 0;
    r.ax=0x4300; r.bx=(kb+15)/16; font_service(2,&r);
    if (r.ax & 0xff00) return 0;
    font_handle=r.dx; font_kind=2; return 1;
}

u16 CALL font_open(void)
{
    struct registers r;
    u16 file, count, i, ok=0;
    u32 length, offset;
    clear(&r,sizeof(r)); r.ax=0x3d00; r.ds=resident_segment;
    r.dx=(u16)"HH20.FNT"; font_service(0,&r);
    if (r.flags & 1) return 0;
    file=r.ax;
    r.ax=0x3f00; r.bx=file; r.cx=32; r.dx=(u16)text_transfer;
    font_service(0,&r);
    if ((r.flags & 1) || r.ax!=32) goto done;
    for (i=0; i<8; ++i) if (text_transfer[i]!="HH20F01\n"[i]) goto done;
    if (*(u16 *)(text_transfer+8)!=CELL_WIDTH ||
        *(u16 *)(text_transfer+10)!=CELL_HEIGHT ||
        *(u16 *)(text_transfer+12)!=FONT_SLOTS) goto done;
    records=*(u16 *)(text_transfer+14); length=*(u32 *)(text_transfer+16);
    if (!records || records>FONT_SLOTS*2 ||
        length!=FONT_MAP_BYTES+RECORD_OFFSET(records)) goto done;
    font_kb=(u16)((length+1023) >> 10);
    text_storage=length;
    if (!allocate(font_kb+32)) goto done;
    for (offset=0; offset<length; offset+=count) {
        count=length-offset>4096 ? 4096 : (u16)(length-offset);
        r.ax=0x3f00; r.bx=file; r.cx=count; r.dx=(u16)text_transfer;
        font_service(0,&r);
        if ((r.flags & 1) || r.ax!=count || !transfer(offset,text_transfer,count,1)) goto done;
    }
    r.ax=0x3f00; r.bx=file; r.cx=1; r.dx=(u16)text_transfer;
    font_service(0,&r);
    ok=!(r.flags & 1) && !r.ax;
done:
    r.ax=0x3e00; r.bx=file; font_service(0,&r);
    if (!ok) font_close();
    return ok;
}
