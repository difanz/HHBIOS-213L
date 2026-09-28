/* Observe public unload-range and font-vector state, without TSR offsets. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char** argv) {
  union REGPACK registers;
  FILE* output;
  unsigned vector, kind, segment, offset;
  if (argc != 2) return 1;
  if (!strcmp(argv[1], "fallback")) {
    /* Model a printer-owned default glyph handler without private offsets. */
    _dos_setvect(0x7c, _dos_getvect(0x17));
    _dos_setvect(0x7d, _dos_getvect(0x17));
    return 0;
  }
  if (!strncmp(argv[1], "off", 3)) {
    memset(&registers, 0, sizeof(registers));
    registers.x.ax = 0x4a06;
    registers.x.si = atoi(argv[1] + 3);
    intr(0x2f, &registers);
    return 0;
  }
  output = fopen(argv[1], "w");
  if (output == NULL) return 2;
  for (vector = 0x7a; vector <= 0x7f; ++vector) {
    void (__interrupt __far* handler)(void) = _dos_getvect(vector);
    segment = FP_SEG(handler);
    offset = FP_OFF(handler);
    for (kind = 0; kind <= 2; ++kind) {
      memset(&registers, 0, sizeof(registers));
      registers.x.ax = 0x4a06;
      registers.x.bx = segment;
      registers.x.cx = 0x1234;
      registers.x.bp = 0x5678;
      registers.x.es = 0x1357;
      registers.x.si = 4;
      registers.x.di = kind;
      intr(0x2f, &registers);
      if (registers.x.bx != segment || registers.x.cx != 0x1234 ||
          registers.x.bp != 0x5678 || registers.x.es != 0x1357 ||
          registers.x.ds != 0 || registers.x.si != 4 || registers.x.di != kind) {
        fclose(output);
        return 3;
      }
      fprintf(output, "%X %X %X %u %u %X\n", vector, segment, offset,
              kind, registers.x.ax, registers.x.dx);
    }
  }
  return fclose(output) == 0 ? 0 : 4;
}
