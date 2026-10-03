/* Observe the real IME row across VGA geometry and VBE ownership changes. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static unsigned char buffer[1024], state[4096], bits[64];
static union REGPACK r;

static void video(unsigned ax, unsigned bx, unsigned cx, unsigned dx) {
  memset(&r, 0, sizeof(r));
  r.x.ax = ax;
  r.x.bx = bx;
  r.x.cx = cx;
  r.x.dx = dx;
  intr(0x10, &r);
}

static int capture(FILE* out) {
  unsigned meta[8], p, n, size;
  unsigned long offset;
  volatile unsigned long __far* clock = MK_FP(0x40, 0x6c);
  unsigned long start = *clock;
  while ((unsigned long)(*clock - start) < 3) {}
  video(0x1411, 0, 0, 0);
  if (r.x.ax != 0x5356) {
    return 0;
  }
  _fmemcpy(meta, MK_FP(r.x.es, r.x.di), 6); /* width, height, pitch */
  video(0x1406, 0, 0, 0);
  meta[3] = r.x.bx >> 8;
  meta[4] = r.x.cx >> 8;
  video(0x1415, 0, 0, 0);
  meta[5] = r.x.bx;
  meta[6] = r.x.cx;
  meta[7] = r.x.dx;
  if (fwrite(meta, 1, sizeof(meta), out) != sizeof(meta)) {
    return 0;
  }
  size = meta[2] * meta[4] * meta[7];
  offset = (unsigned long)(meta[6] + meta[3] * meta[4] * meta[7]) * meta[2];
  if (meta[6] + (meta[3] + 1) * meta[4] * meta[7] + 2 <= meta[1]) {
    offset += meta[2]; /* The frame occupies the spare scanlines. */
  }
  for (p = 0; p < 4; ++p) {
    for (n = 0; n < size;) {
      unsigned count = size - n > sizeof(buffer) ? sizeof(buffer) : size - n;
      unsigned long at = offset + n;
      memset(&r, 0, sizeof(r));
      r.x.ax = 0x1414;
      r.x.bx = p;
      r.x.dx = (unsigned)(at >> 16);
      r.x.si = (unsigned)at;
      r.x.cx = count;
      r.x.es = FP_SEG(buffer);
      r.x.di = FP_OFF(buffer);
      intr(0x10, &r);
      if (r.x.ax || fwrite(buffer, 1, count, out) != count) {
        return 0;
      }
      n += count;
    }
  }
  return 1;
}

int main(void) {
  FILE* out = fopen("PROMPT.BIN", "wb");
  unsigned i, size;
  if (!out || !capture(out)) {
    return 1; /* Driver installation, no AH=29h. */
  }
  video(0x1400, 0, 0, 0);
  video(0x1403, 0x2e, 0, 'A');
  video(0x1403, 0x2e, 0, 0xd6);
  video(0x1403, 0x2e, 0, 0xd0);
  for (i = 0; i < 64; ++i) {
    bits[i] = (unsigned char)(i * 7 + 3);
  }
  video(0x1402, 0, 0, 70);
  video(0x1401, 0x3f, 10, 'Z');
  /* A normal bitmap and a clipped overlapping bitmap at the right edge. */
  for (i = 0; i < 2; ++i) {
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x140a;
    r.x.bx = 0x4b;
    r.x.dx = i ? 78 : 76;
    r.x.bp = FP_SEG(bits);
    r.x.si = FP_OFF(bits);
    intr(0x10, &r);
  }
  memset(bits, 0, sizeof(bits)); /* Caller memory may be reused immediately. */
  video(0x1402, 0, 0, 79);
  video(0x1403, 0x2e, 0, 'B');
  video(0x1402, 0, 0, 3);
  video(0x1403, 0x2e, 0, 'C');
  if (!capture(out)) {
    return 2;
  }
  video(0x1202, 0x30, 0, 0);
  video(0x1112, 0, 0, 0);
  if (!capture(out)) {
    return 3;
  }
  video(0x1201, 0x30, 0, 0);
  video(0x1112, 0, 0, 0);
  if (!capture(out)) {
    return 4;
  }
  video(0x4f04, 0, 15, 0);
  size = r.x.bx * 64;
  if (r.x.ax != 0x004f || !size || size > sizeof(state)) {
    return 5;
  }
  r.x.ax = 0x4f04;
  r.x.cx = 15;
  r.x.dx = 1;
  r.x.es = FP_SEG(state);
  r.x.bx = FP_OFF(state);
  intr(0x10, &r);
  if (r.x.ax != 0x004f) {
    return 6;
  }
  video(0x4f02, 0x101, 0, 0);
  if (r.x.ax != 0x004f) {
    return 7;
  }
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x4f04;
  r.x.cx = 15;
  r.x.dx = 2;
  r.x.es = FP_SEG(state);
  r.x.bx = FP_OFF(state);
  intr(0x10, &r);
  if (r.x.ax != 0x004f || !capture(out)) {
    return 8;
  }
  video(0x4f02, 0x101, 0, 0);
  video(3, 0, 0, 0);
  if (!capture(out)) {
    return 9;
  }
  video(0x1404, 0, 0, 0);
  video(0x1500, 0, 0, 0);
  if (!capture(out)) {
    return 10;
  }
  video(3, 0, 0, 0);
  if (!capture(out)) {
    return 11;
  }
  return fclose(out) != 0;
}
