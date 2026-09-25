/*
 * KEYSOCK: DOS TSR. Poll COM1 (DOSBox-X nullmodem) from INT 1Ch and
 * push scan/ASCII pairs into the BIOS keyboard buffer.
 * This is not IRQ1 / port 60h injection.
 *
 * The tick stub lives in keysock.asm. A tiny-model COM cannot keep a
 * segment relocation, so the vector is installed from CS there.
 */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdlib.h>

#define COM 0x3F8

static unsigned char half;
static unsigned char have_half;

static void stuff_key(unsigned char scan, unsigned char ascii)
{
    unsigned short head;
    unsigned short tail;
    unsigned short start;
    unsigned short end;
    unsigned short next;

    head = *(unsigned short __far *)MK_FP(0x40, 0x1A);
    tail = *(unsigned short __far *)MK_FP(0x40, 0x1C);
    start = *(unsigned short __far *)MK_FP(0x40, 0x80);
    end = *(unsigned short __far *)MK_FP(0x40, 0x82);
    if (start == 0 || end == 0) {
        start = 0x1E;
        end = 0x3E;
    }
    next = (unsigned short)(tail + 2);
    if (next >= end) {
        next = start;
    }
    if (next == head) {
        return;
    }
    *(unsigned short __far *)MK_FP(0x40, tail) =
        (unsigned short)(((unsigned short)scan << 8) | ascii);
    *(unsigned short __far *)MK_FP(0x40, 0x1C) = next;
}

/* Called from keysock.asm with DS = CS. */
void do_poll(void)
{
    unsigned int spins;

    for (spins = 0; spins < 16; spins++) {
        if ((inp(COM + 5) & 0x01) == 0) {
            break;
        }
        if (!have_half) {
            half = (unsigned char)inp(COM);
            have_half = 1;
        } else {
            stuff_key(half, (unsigned char)inp(COM));
            have_half = 0;
        }
    }
}

extern void install_tick(void);

static void uart_init(void)
{
    outp(COM + 3, 0x80);
    outp(COM + 0, 12); /* 9600 at the usual 1.8432 MHz clock */
    outp(COM + 1, 0x00);
    outp(COM + 3, 0x03); /* 8N1 */
    outp(COM + 4, 0x0B); /* DTR, RTS, OUT2 */
    outp(COM + 1, 0x00);
    outp(COM + 2, 0x07);
}

int main(void)
{
    unsigned off;
    unsigned paras;

    uart_init();
    install_tick();
    /* Paragraphs from the PSP. sbrk(0) is the end of resident code and data. */
    off = FP_OFF(sbrk(0));
    paras = (off + 15) / 16 + 16;
    _dos_keep(0, paras);
    return 0;
}
