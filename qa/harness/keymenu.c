/* Keep a DOS console read active while the host operates CKBD's IRQ menu. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

#include "hostshot.h"

static int ReaderInstalled(void) {
  union REGPACK regs;
  memset(&regs, 0, sizeof(regs));
  regs.x.ax = 0x4a06;
  regs.x.si = 3;
  intr(0x2f, &regs);
  return regs.x.bx == 0x4a06;
}

int main(void) {
  union REGPACK regs;
  unsigned step;
  if (!ReaderInstalled()) return 1;
  for (step = 0; step < 5; ++step) {
    if (hostrequest(0x7000 + step)) return 2;
    memset(&regs, 0, sizeof(regs));
    regs.h.ah = 8;
    intr(0x21, &regs);
    /* Only the host's final sentinel may reach the foreground program. */
    if (regs.h.al != '.') return 3;
    if (ReaderInstalled() != (step < 4)) return 4;
  }
  regs.h.ah = 0x0f;
  intr(0x10, &regs);
  if (regs.h.al != 3) return 5;
  puts("Keyboard menu completed; foreground program resumed.");
  return 0;
}
