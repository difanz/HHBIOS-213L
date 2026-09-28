/* Exercise compact CGA mode fallback through the installed BIOS interface. */
#include <i86.h>
#include <stdio.h>
#include <string.h>

static void Video(union REGPACK* regs, unsigned ax) {
  regs->x.ax = ax;
  intr(0x10, regs);
}

static int CheckMode(unsigned mode) {
  union REGPACK regs;
  unsigned actual = mode & 0x7f;
  unsigned columns;
  if (actual > 6) actual = 6;
  columns = actual == 6 ? 80 : 40;
  memset(&regs, 0, sizeof(regs));
  Video(&regs, mode);
  Video(&regs, 0x0f00);
  if ((regs.h.al & 0x7f) != actual || regs.h.ah != columns) return 1;
  regs.x.bx = 0;
  regs.x.dx = columns - 1;
  Video(&regs, 0x0200);
  Video(&regs, 0x0300);
  if (regs.x.dx != columns - 1) return 2;
  regs.x.bx = 7;
  regs.x.cx = 1;
  Video(&regs, 0x0951);
  regs.x.bx = 0;
  Video(&regs, 0x0800);
  if (regs.h.al != 'Q') return 3;
  regs.x.bx = 0;
  Video(&regs, 0x1416);
  if (regs.x.ax != 0 || regs.x.bx != 0x4b48) return 4;
  return 0;
}

int main(void) {
  static const unsigned kModes[] = {0x12, 0x86, 4, 0x84, 5, 0x85, 6, 0x92};
  FILE* report = fopen("CGAMODE.TXT", "w");
  unsigned index;
  int result;
  if (report == NULL) return 1;
  for (index = 0; index < sizeof(kModes) / sizeof(kModes[0]); ++index) {
    result = CheckMode(kModes[index]);
    fprintf(report, "%02X %d\n", kModes[index], result);
    fflush(report);
    if (result) {
      fclose(report);
      return result;
    }
  }
  fclose(report);
  return 0;
}
