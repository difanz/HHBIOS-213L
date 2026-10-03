/* Observe Ctrl+F7 through physical IRQ1, including native BIOS ownership. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

#include "hostshot.h"

static int RecordMode(FILE* output, unsigned step) {
  union REGPACK regs;
  unsigned record[7];
  unsigned char __far* keyboard;
  memset(&regs, 0, sizeof(regs));
  regs.x.ax = 0x2f00;
  intr(0x16, &regs);
  if (!regs.x.bp) {
    return 1;
  }
  keyboard = MK_FP(regs.x.bp, 0x100);
  record[0] = step;
  record[1] = keyboard[1];
  record[2] = keyboard[2];
  memset(&regs, 0, sizeof(regs));
  regs.x.ax = 0x0f00;
  intr(0x10, &regs);
  record[3] = regs.h.al;
  memset(&regs, 0, sizeof(regs));
  regs.x.ax = 0x4f03;
  intr(0x10, &regs);
  if (regs.x.ax != 0x004f) {
    return 2;
  }
  record[4] = regs.x.bx & 0x3fff;
  memset(&regs, 0, sizeof(regs));
  regs.x.ax = 0x1412; /* Empty capture reports whether scanout is owned. */
  intr(0x10, &regs);
  record[5] = regs.x.ax;
  record[6] = *(unsigned char __far*)MK_FP(0x40, 0x84) + 1;
  return fwrite(record, sizeof(record), 1, output) != 1;
}

int main(void) {
  union REGPACK regs;
  unsigned step;
  FILE* output = fopen("VESAKEY.BIN", "wb");
  if (!output) {
    return 1;
  }
  if (RecordMode(output, 0)) {
    return 2;
  }
  for (step = 1; step <= 4; ++step) {
    if (hostrequest(0x7200 + step)) {
      return 3;
    }
    memset(&regs, 0, sizeof(regs));
    intr(0x16, &regs);
    if (regs.h.al != '\r') {
      return 4;
    }
    if (RecordMode(output, step)) {
      return 5;
    }
  }
  /* The public policy switch must also work after a native interval. */
  memset(&regs, 0, sizeof(regs));
  regs.x.ax = 0x180b;
  intr(0x10, &regs);
  regs.x.ax = 3;
  intr(0x10, &regs);
  if (RecordMode(output, 5)) {
    return 6;
  }
  return fclose(output) != 0;
}
