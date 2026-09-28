/* Exercise CKBD's control menu and the public status-row drawing interface. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static volatile unsigned long __far* ticks = MK_FP(0x40, 0x6c);

static void Video(unsigned operation, unsigned attribute, unsigned character) {
  union REGPACK registers;
  memset(&registers, 0, sizeof(registers));
  registers.w.ax = 0x1400 | operation;
  registers.w.bx = attribute;
  registers.w.dx = character;
  intr(0x10, &registers);
}

static void Page(unsigned page, int chinese) {
  unsigned item;
  Video(0, 0, 0);
  for (item = 0; item < 10; ++item) {
    Video(3, 0x1a, '0' + item);
    Video(3, 0x1e, '.');
    if (chinese) {
      Video(3, 0x1e, page & 1 ? 0xce : 0xd6);
      Video(3, 0x1e, page & 1 ? 0xc4 : 0xd0);
    } else {
      Video(3, 0x1e, 'A' + page);
      Video(3, 0x1e, 'a' + item);
    }
    Video(3, 0x1e, ' ');
  }
}

static void Result(FILE* output, const char* name, unsigned long start) {
  fprintf(output, "%s=%lu\n", name, (unsigned long)(*ticks - start));
  fflush(output);
}

static int QueueKey(unsigned key) {
  union REGPACK registers;
  memset(&registers, 0, sizeof(registers));
  registers.w.ax = 0x0500;
  registers.w.cx = key;
  intr(0x16, &registers);
  return (registers.w.ax & 255) == 0;
}

static int ControlMenu(void) {
  union REGPACK registers;
  unsigned page;
  /* The saved BIOS handler consumes these keys inside CKBD's real menu.
   * Leave a sentinel for the foreground reader after Escape. */
  for (page = 0; page < 4; ++page) {
    if (!QueueKey(page & 1 ? 0x4800 : 0x5000)) return 0;
  }
  if (!QueueKey(0x011b) || !QueueKey(0x342e)) return 0;
  memset(&registers, 0, sizeof(registers));
  registers.w.ax = 0x2162; /* CKBD: execute the Ctrl+F5 function. */
  intr(0x16, &registers);
  registers.w.ax = 0x1000;
  intr(0x16, &registers);
  return registers.w.ax == 0x342e;
}

int main(void) {
  FILE* output = fopen("PRMPERF.TXT", "w");
  unsigned page;
  unsigned long start;
  union REGPACK registers;
  if (!output) return 1;
  start = *ticks;
  if (!ControlMenu()) {
    fclose(output);
    return 2;
  }
  Result(output, "CONTROL_FLIPS_4", start);
  Video(5, 0x1e, 0);
  Page(0, 0);
  start = *ticks;
  for (page = 0; page < 4; ++page) Page(page, 0);
  Result(output, "ASCII_PAGES_4", start);
  Page(0, 1);
  start = *ticks;
  for (page = 0; page < 4; ++page) Page(page, 1);
  Result(output, "HANZI_PAGES_4", start);
  start = *ticks;
  for (page = 0; page < 8; ++page) {
    memset(&registers, 0, sizeof(registers));
    registers.w.ax = 0x2900; /* CKBD's own title and bitmap logo. */
    intr(0x16, &registers);
  }
  Result(output, "CKBD_TITLE_8", start);
  Video(0, 0, 0);
  Video(3, 0x1e, 'A');
  start = *ticks;
  for (page = 0; page < 64; ++page) {
    Video(2, 0, 0);
    Video(3, 0x1e, 'A');
  }
  Result(output, "UNCHANGED_64", start);
  return fclose(output) != 0;
}
