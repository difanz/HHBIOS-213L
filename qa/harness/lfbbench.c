/* Time direct-color dirty refresh. PIT channel 0 is ~1.193182 MHz.
 * AX=1500h paints synchronously. AX=1418h reports linear bytes written. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static unsigned char screen[32];

static unsigned bios_ticks(void) {
  return *(unsigned __far*)MK_FP(0x40, 0x6c);
}

static void video(unsigned ax, unsigned bx, unsigned cx, unsigned dx) {
  union REGPACK r;

  memset(&r, 0, sizeof(r));
  r.x.ax = ax;
  r.x.bx = bx;
  r.x.cx = cx;
  r.x.dx = dx;
  intr(0x10, &r);
}

static unsigned long pit_now(void) {
  unsigned t1, t2, rem;
  unsigned lo, hi;

  do {
    _disable();
    t1 = bios_ticks();
    outp(0x43, 0x00);
    lo = inp(0x40);
    hi = inp(0x40);
    t2 = bios_ticks();
    _enable();
  } while (t1 != t2);
  rem = (hi << 8) | lo;
  return ((unsigned long)t1 << 16) + (rem ? 65536UL - rem : 0UL);
}

static unsigned long bytes_clear(void) {
  union REGPACK r;

  memset(&r, 0, sizeof(r));
  r.x.ax = 0x1418;
  r.x.cx = 1;
  intr(0x10, &r);
  return ((unsigned long)r.x.dx << 16) | r.x.ax;
}

static void fill_text(unsigned value) {
  unsigned __far* text = (unsigned __far*)MK_FP(0xb800, 0);
  unsigned i;

  for (i = 0; i < 80U * 25U; ++i) {
    text[i] = value;
  }
}

static void fill_hanzi(unsigned frame) {
  static const unsigned codes[] = {0xd6d0, 0xb9fa, 0xbaba, 0xd7d6,
                                   0xcfb5, 0xcdb3, 0xb2e2, 0xcad4};
  unsigned __far* text = (unsigned __far*)MK_FP(0xb800, 0);
  unsigned cell, code;

  for (cell = 0; cell < 80U * 25U; ++cell) {
    code = codes[(cell / 2 + frame) % 8];
    text[cell] = 0x1e00 | ((cell & 1) ? (code & 255) : (code >> 8));
  }
}

static void measure(FILE* out, const char* name, int kind) {
  unsigned long start, elapsed, written;
  unsigned ticks;

  bytes_clear();
  start = pit_now();
  ticks = bios_ticks();
  if (kind == 0) {
    fill_text(0x1f20);
    video(0x1500, 0, 0, 0);
  } else if (kind == 1) {
    unsigned __far* text = (unsigned __far*)MK_FP(0xb800, 0);
    text[2 * 80 + 10] = 0x1ed6;
    text[2 * 80 + 11] = 0x1ed0;
    text[2 * 80 + 12] = 0x1ece;
    text[2 * 80 + 13] = 0x1ec4;
    video(0x1500, 0, 0, 0);
  } else if (kind == 2) {
    unsigned __far* text = (unsigned __far*)MK_FP(0xb800, 0);
    unsigned col;

    for (col = 0; col < 80; ++col) {
      text[10 * 80 + col] = 0x1e00 | ('A' + (col % 26));
    }
    video(0x1500, 0, 0, 0);
  } else if (kind == 3) {
    video(0x0601, 0x0700, 0, (24 << 8) | 79);
  } else if (kind == 4) {
    fill_hanzi(1);
    video(0x1500, 0, 0, 0);
  } else {
    /* Idle: the timer hook may refresh, but it must not store pixels. */
    while ((unsigned)(bios_ticks() - ticks) < 8) {}
  }
  elapsed = pit_now() - start;
  ticks = (unsigned)(bios_ticks() - ticks);
  written = bytes_clear();
  fprintf(out, "%s counts=%lu ms=%lu ticks=%u bytes=%lu\n", name, elapsed,
          elapsed / 1193UL, ticks, written);
}

int main(void) {
  union REGPACK r;
  FILE* out;
  unsigned i, bpp, pitch, width, height, mode;

  memset(&r, 0, sizeof(r));
  r.x.ax = 0xff00;
  intr(0x10, &r);
  out = fopen("BENCH.TXT", "w");
  if (!out) {
    return 2;
  }
  if (r.x.ax != 0x56) {
    fprintf(out, "STATUS=absent\n");
    fclose(out);
    return 1;
  }
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x1411;
  intr(0x10, &r);
  if (r.x.ax != 0x5356 || r.x.cx < 28 || r.x.cx > sizeof(screen)) {
    fprintf(out, "STATUS=abi\n");
    fclose(out);
    return 1;
  }
  for (i = 0; i < r.x.cx; ++i) {
    screen[i] = *(unsigned char __far*)MK_FP(r.x.es, r.x.di + i);
  }
  if (screen[15] != 6) {
    fprintf(out, "STATUS=not-direct\n");
    fclose(out);
    return 1;
  }
  width = screen[0] | ((unsigned)screen[1] << 8);
  height = screen[2] | ((unsigned)screen[3] << 8);
  pitch = screen[4] | ((unsigned)screen[5] << 8);
  mode = screen[12] | ((unsigned)screen[13] << 8);
  bpp = screen[16];
  video(0x0100, 0, 0x2000, 0);
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x1415;
  intr(0x10, &r);
  {
    unsigned vx = r.x.bx, vy = r.x.cx, scale = r.x.dx ? r.x.dx : 1;
    unsigned fw, rh;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1413;
    intr(0x10, &r);
    fw = r.x.si;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1406;
    intr(0x10, &r);
    rh = r.x.cx >> 8;
    fprintf(
        out,
        "STATUS=ok MODE=%x W=%u H=%u BPP=%u PITCH=%u VX=%u VY=%u SCALE=%u FW=%u RH=%u\n",
        mode, width, height, bpp, pitch, vx, vy, scale, fw, rh);
  }
  fill_text(0x0720);
  video(0x1500, 0, 0, 0);
  bytes_clear();
  measure(out, "FULL_BLANK", 0);
  measure(out, "SPARSE4", 1);
  measure(out, "LINE80", 2);
  measure(out, "SCROLL1", 3);
  measure(out, "FULL_HANZI", 4);
  measure(out, "FULL_BLANK2", 0);
  measure(out, "FULL_HANZI2", 4);
  measure(out, "IDLE8", 5);
  return fclose(out) != 0;
}
