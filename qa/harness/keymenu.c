/* Exercise the IRQ menu from DOS reads and BIOS-only foreground loops. */
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

static unsigned ReadKey(const char* mode) {
  union REGPACK regs;
  memset(&regs, 0, sizeof(regs));
  if (!strcmp(mode, "poll")) {
    do {
      regs.h.ah = 0x11;
      intr(0x16, &regs);
    } while (regs.x.flags & 0x40);
  }
  if (!strcmp(mode, "dos")) {
    regs.h.ah = 8;
    intr(0x21, &regs);
  } else {
    regs.h.ah = 0x10;
    intr(0x16, &regs);
  }
  return regs.h.al;
}

static unsigned g_step;
static unsigned g_last_key;

static int CheckMenu(const char* mode) {
  union REGPACK regs;
  if (!ReaderInstalled()) return 1;
  for (g_step = 0; g_step < 5; ++g_step) {
    if (hostrequest(0x7000 + g_step)) return 2;
    /* Only the host's final sentinel may reach the foreground program. */
    g_last_key = ReadKey(mode);
    if (g_last_key != '.') return 3;
    if (ReaderInstalled() != (g_step < 4)) return 4;
  }
  regs.h.ah = 0x0f;
  intr(0x10, &regs);
  /* BIOS may retain the mode-set "do not clear" flag in AL bit 7. */
  if ((regs.h.al & 0x7f) != 3 && (regs.h.al & 0x7f) != 7) return 5;
  puts("Keyboard menu completed; foreground program resumed.");
  return 0;
}

int main(int argc, char** argv) {
  int result = CheckMenu(argc > 1 ? argv[1] : "dos");
  FILE* report = fopen("KEYMENU.TXT", "w");
  if (report != NULL) {
    fprintf(report, "result=%d step=%u key=%02X\n", result, g_step, g_last_key);
    fclose(report);
  }
  return result;
}
