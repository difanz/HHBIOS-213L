/* Physical mouse trace: both signs on both axes, through INT 33h. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

#include "hostshot.h"

static union REGPACK mouse_registers;
static void CallMouse(unsigned function, unsigned x, unsigned y) {
  memset(&mouse_registers, 0, sizeof(mouse_registers));
  mouse_registers.x.ax = function;
  mouse_registers.x.cx = x;
  mouse_registers.x.dx = y;
  intr(0x33, &mouse_registers);
}
int main(void) {
  FILE* trace_file;
  unsigned step;
  unsigned long start;
  volatile unsigned long __far* ticks = MK_FP(0x40, 0x6c);
  CallMouse(0, 0, 0);
  if (mouse_registers.x.ax != 0xffff) {
    return 1;
  }
  CallMouse(1, 0, 0);
  if (hostrequest(0xfffe)) {
    return 2; /* Establish host input before centering. */
  }
  CallMouse(4, 320, 96);
  CallMouse(11, 0, 0);
  trace_file = fopen("MOUSEDIR.TXT", "w");
  if (!trace_file) {
    return 3;
  }
  for (step = 0; step <= 8; ++step) {
    if (step && hostrequest(0xfffe)) {
      return 4;
    }
    start = *ticks;
    while ((unsigned long)(*ticks - start) < 4) {}
    CallMouse(3, 0, 0);
    fprintf(trace_file, "%u %u %u ", step, mouse_registers.x.cx,
            mouse_registers.x.dx);
    CallMouse(11, 0, 0);
    fprintf(trace_file, "%d %d\n", (short)mouse_registers.x.cx,
            (short)mouse_registers.x.dx);
  }
  CallMouse(2, 0, 0);
  return fclose(trace_file) != 0;
}
