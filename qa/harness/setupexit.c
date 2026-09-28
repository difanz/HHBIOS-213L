/* Observe SETUP's screen before COMMAND can print its next prompt. */
#include <dos.h>
#include <i86.h>
#include <process.h>
#include <stdio.h>
#include <string.h>

static unsigned char buffer[4096];

static int Capture(const char* filename) {
  union REGPACK registers;
  unsigned values[15];
  unsigned remaining, offset, count, plane;
  unsigned long pixels, position;
  FILE* output;
  memset(values, 0, sizeof(values));
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 0x0f00;
  intr(0x10, &registers);
  values[0] = registers.x.ax;
  values[1] = *(unsigned __far*)MK_FP(0x40, 0x4a);
  values[2] = *(unsigned char __far*)MK_FP(0x40, 0x84) + 1;
  if (values[2] < 25) values[2] = 25;
  values[3] = registers.x.bx >> 8;
  registers.x.ax = 0x0300;
  intr(0x10, &registers);
  values[4] = registers.x.dx;
  values[5] = registers.x.cx;
  registers.x.ax = 0x4a06;
  registers.x.si = 3;
  registers.x.bx = 0;
  intr(0x2f, &registers);
  values[6] = registers.x.bx == 0x4a06;
  if (values[6]) {
    registers.x.ax = 0x1411;
    intr(0x10, &registers);
    values[7] = registers.x.ax == 0x5356;
    if (values[7]) {
      unsigned __far* surface = MK_FP(registers.x.es, registers.x.di);
      values[8] = surface[0];
      values[9] = surface[1];
      values[10] = surface[2];
      values[14] = surface[6];
      registers.x.ax = 0x1415;
      intr(0x10, &registers);
      values[11] = registers.x.cx;
      values[12] = registers.x.dx;
      registers.x.ax = 0x1413;
      intr(0x10, &registers);
      values[13] = registers.x.di;
      registers.x.ax = 0x1500;
      intr(0x10, &registers);
    }
  }
  output = fopen(filename, "wb");
  if (output == NULL) return 1;
  if (fwrite(values, sizeof(values), 1, output) != 1) goto failed;
  remaining = values[1] * values[2] * 2;
  offset = *(unsigned __far*)MK_FP(0x40, 0x4e);
  while (remaining) {
    count = remaining < sizeof(buffer) ? remaining : sizeof(buffer);
    _fmemcpy(buffer, MK_FP((values[0] & 127) == 7 ? 0xb000 : 0xb800, offset), count);
    if (fwrite(buffer, 1, count, output) != count) goto failed;
    offset += count;
    remaining -= count;
  }
  if (values[7]) {
    pixels = (unsigned long)values[10] * values[9];
    for (plane = 0; plane < 4; ++plane) {
      for (position = 0; position < pixels; position += count) {
        count = pixels - position < sizeof(buffer) ?
                    (unsigned)(pixels - position) : sizeof(buffer);
        memset(&registers, 0, sizeof(registers));
        registers.x.ax = 0x1414;
        registers.x.bx = plane;
        registers.x.dx = position >> 16;
        registers.x.si = (unsigned)position;
        registers.x.cx = count;
        registers.x.es = FP_SEG(buffer);
        registers.x.di = FP_OFF(buffer);
        intr(0x10, &registers);
        if (registers.x.ax || fwrite(buffer, 1, count, output) != count) goto failed;
      }
    }
  }
  return fclose(output) != 0;
failed:
  fclose(output);
  return 1;
}

int main(int argc, char** argv) {
  int status;
  if (Capture("BEFORE.BIN")) return 1;
  status = spawnl(P_WAIT, "SETUP.EXE", "SETUP.EXE",
                  argc > 1 ? argv[1] : "/EN", NULL);
  if (status != 0) return 2;
  return Capture("AFTER.BIN");
}
