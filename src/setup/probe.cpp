#include "setup.h"
#include <dos.h>
#include <string.h>
#include "vesa.h"

static union REGS r;
static struct SREGS s;
static void interrupt_call(unsigned number, unsigned ax)
{
    r.x.ax=ax;
    int86x(number,&r,&r,&s);
}

static unsigned processor()
{
    unsigned result;
    asm pushf
    asm pop dx
    asm mov ax,dx
    asm and ax,0fffh
    asm push ax
    asm popf
    asm pushf
    asm pop ax
    asm and ax,0f000h
    asm mov bx,86
    asm cmp ax,0f000h
    asm je cpu_done
    asm mov ax,dx
    asm or ax,7000h
    asm push ax
    asm popf
    asm pushf
    asm pop ax
    asm and ax,7000h
    asm mov bx,286
    asm jz cpu_done
    asm mov bx,386
cpu_done:
    asm push dx
    asm popf
    asm mov result,bx
    return result;
}

static unsigned after_exit()
{
    unsigned segment, n, owner, count=0;
    unsigned long run=0, largest=0;
    unsigned char far *mcb;
    interrupt_call(0x21,0x5200);
    segment=*(unsigned far *)MK_FP(s.es,r.x.bx-2);
    /* Only inspect conventional DOS MCBs. Treat this process and its heap /
     * environment as reclaimable. No allocation, coalescing or UMB linking. */
    while (segment>=0x50 && segment<0xa000 && ++count<4096) {
        mcb=(unsigned char far *)MK_FP(segment,0);
        if (mcb[0]!='M' && mcb[0]!='Z') break;
        owner=*(unsigned far *)(mcb+1);
        n=*(unsigned far *)(mcb+3);
        if ((unsigned long)segment+n+1>0xa000UL) break;
        if (!owner || owner==_psp) run+=n+1UL;
        else run=0;
        if (run>largest) largest=run;
        if (mcb[0]=='Z') break;
        segment+=n+1;
    }
    return largest ? (unsigned)((largest-1)/64) : 0;
}

static void umb(Machine *m)
{
    if (m->dos_major<5) return;
    interrupt_call(0x21,0x5800);
    if (r.x.cflag) return;
    m->alloc_strategy=r.x.ax;
    interrupt_call(0x21,0x5802);
    if (r.x.cflag) return;
    m->umb_link=r.h.al;
    r.x.bx=1; interrupt_call(0x21,0x5803);
    if (r.x.cflag) return;
    r.x.bx=0x41; interrupt_call(0x21,0x5801); /* upper only, best fit */
    if (!r.x.cflag) {
        r.x.bx=0xffff; interrupt_call(0x21,0x4800);
        if (r.x.cflag && r.x.ax==8) m->umb_kb=r.x.bx/64;
        else if (!r.x.cflag) { s.es=r.x.ax; interrupt_call(0x21,0x4900); }
    }
    r.x.bx=m->alloc_strategy; interrupt_call(0x21,0x5801);
    r.x.bx=m->umb_link; interrupt_call(0x21,0x5803);
}

static void extended(Machine *m)
{
    void (far *entry)();
    unsigned version, largest, total, error;
    interrupt_call(0x2f,0x4300);
    if (r.h.al==0x80) {
        interrupt_call(0x2f,0x4310);
        entry=(void (far *)())MK_FP(s.es,r.x.bx);
        asm xor ah,ah
        asm call dword ptr entry
        asm mov version,ax
        asm mov ah,8
        asm call dword ptr entry
        asm mov largest,ax
        asm mov total,dx
        asm xor bh,bh
        asm mov error,bx
        m->xms_version=version;
        if (!error) { m->xms_largest=largest; m->xms_total=total; }
    }
    interrupt_call(0x21,0x3567);
    if (_fmemcmp(MK_FP(s.es,10),"EMMXXXX0",8)) return;
    interrupt_call(0x67,0x4000);
    if (r.h.ah) return;
    interrupt_call(0x67,0x4600);
    if (r.h.ah) return;
    m->ems_version=r.h.al;
    interrupt_call(0x67,0x4200);
    if (!r.h.ah) m->ems_pages=r.x.bx;
    interrupt_call(0x67,0x4100);
    if (!r.h.ah) m->ems_frame=r.x.bx;
}

static void video(Machine *m)
{
    static unsigned char controller[512], info[256];
    unsigned modes[3]={0x102,0x104,0x106}, i, j;
    unsigned far *list;
    struct surface layout;
    interrupt_call(0x11,0);
    m->adapter=(r.x.ax & 0x30)==0x30 ? AdapterMda : AdapterCga;
    r.x.bx=0; interrupt_call(0x10,0x1a00);
    if (r.h.al==0x1a && (r.h.bl==7 || r.h.bl==8)) m->adapter=AdapterVga;
    else {
        r.x.bx=0x10; interrupt_call(0x10,0x1200);
        if (r.h.bl!=0x10) m->adapter=AdapterEga;
    }
    if (m->adapter!=AdapterVga) return;
    memset(controller,0,sizeof(controller));
    memcpy(controller,"VBE2",4);
    s.es=FP_SEG(controller); r.x.di=FP_OFF(controller);
    interrupt_call(0x10,0x4f00);
    if (r.x.ax!=0x4f || memcmp(controller,"VESA",4) || (controller[10] & 2)) return;
    m->vbe_version=*(unsigned *)(controller+4);
    list=*(unsigned far **)(controller+14);
    if (!list) return;
    for (i=0; i<512 && FP_OFF(list)<=65533U; ++i,++list) {
        if (*list==0xffff) break;
        for (j=0; j<3; ++j) if (*list==modes[j]) {
            memset(info,0,sizeof(info));
            s.es=FP_SEG(info); r.x.di=FP_OFF(info); r.x.cx=modes[j];
            interrupt_call(0x10,0x4f01);
            if (r.x.ax==0x4f && vesa_console_layout(&layout,info,m->vbe_version,modes[j]) &&
                (j==0 || (m->vbe_version>=0x102 && info[29]))) m->modes|=1U<<j;
        }
    }
}

void probe_machine(Machine *m)
{
    memset(m,0,sizeof(*m)); memset(&r,0,sizeof(r)); segread(&s);
    m->cpu=processor();
    interrupt_call(0x21,0x3000); m->dos_major=r.h.al; m->dos_minor=r.h.ah;
    interrupt_call(0x12,0); m->conventional_kb=r.x.ax;
    if (m->dos_major>=3) m->free_kb=after_exit();
    umb(m); extended(m); video(m);
    interrupt_call(0x2f,0x1687); m->dpmi=r.x.ax==0;
    r.x.bx=0; r.x.si=3; interrupt_call(0x2f,0x4a06); m->loaded=r.x.bx==0x4a06;
}
