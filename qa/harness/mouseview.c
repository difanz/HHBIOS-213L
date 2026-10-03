/* Actual host mouse events, native driver callback, and text-byte integrity. */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <stdio.h>
#include <string.h>
#include "hostshot.h"
unsigned mouse_count, mouse_log[32][4];
extern void mouse_event(void);
static unsigned code_segment(void);
#pragma aux code_segment = "mov ax,cs" value[ax];
static unsigned char before[32768];
int main(int argc, char** argv) {
  union REGPACK r, record[3];
  unsigned rows, cell, width, ox, oy, scale, x, y, i;
  volatile unsigned long __far* clock = MK_FP(0x40, 0x6c);
  unsigned long start;
  FILE* out;
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x1406;
  intr(0x10, &r);
  cell = r.x.cx >> 8;
  rows = *(unsigned char __far*)MK_FP(0x40, 0x84) + 1;
  r.x.ax = 0x1413;
  intr(0x10, &r);
  width = r.x.si;
  r.x.ax = 0x1415;
  intr(0x10, &r);
  if (r.x.ax != 0x5650) {
    return 1;
  }
  ox = r.x.bx;
  oy = r.x.cx;
  scale = r.x.dx;
  x = ox + 79 * width * scale - 1;
  y = oy + (rows - 1) * cell * scale - 1;
  out = fopen("MOUSE.JSN", "wb");
  if (!out) {
    return 2;
  }
  fprintf(out, "[{\"x\":%u,\"y\":%u}]\n", x, y);
  if (fclose(out)) {
    return 3;
  }
  _disable();
  _fmemcpy(before, MK_FP(0xb800, 0), 32768);
  _enable();
  memset(&r, 0, sizeof(r));
  intr(0x33, &r);
  if (r.x.ax != 0xffff) {
    return 4;
  }
  r.x.ax = 12;
  r.x.cx = 7;
  r.x.es = code_segment();
  r.x.dx = (unsigned)mouse_event;
  intr(0x33, &r);
  r.x.ax = 1;
  intr(0x33, &r);
  if (argc == 2 && !strcmp(argv[1], "hardware")) {
    r.x.ax = 10;
    r.x.bx = 1;
    r.x.cx = 6;
    r.x.dx = 7;
    intr(0x33, &r);
  } else if (argc == 2 && !strcmp(argv[1], "excluded")) {
    r.x.ax = 0x10;
    r.x.cx = 78 * 8;
    r.x.dx = (rows - 2) * 8;
    r.x.si = r.x.cx + 7;
    r.x.di = r.x.dx + 7;
    intr(0x33, &r);
  }
  if (hostrequest(0xfffe)) {
    return 5;
  }
  start = *clock;
  while ((unsigned long)(*clock - start) < 24) {}
  for (i = 0; i < 3; ++i) {
    memset(&r, 0, sizeof(r));
    r.x.ax = i ? 4 + i : 3;
    intr(0x33, &r);
    record[i] = r;
  }
  r.x.ax = 12;
  r.x.cx = 0;
  r.x.es = r.x.dx = 0;
  intr(0x33, &r);
  _disable();
  for (i = 0; i < 32768; ++i) {
    if (before[i] != *(unsigned char __far*)MK_FP(0xb800, i)) {
      break;
    }
  }
  _enable();
  out = fopen("MOUSELOG.BIN", "wb");
  if (!out) {
    return 6;
  }
  fwrite(&i, 2, 1, out);
  fwrite(record, 1, sizeof(record), out);
  fwrite(&mouse_count, 2, 1, out);
  fwrite(mouse_log, 8, mouse_count, out);
  return fclose(out) != 0;
}
