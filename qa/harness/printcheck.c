/* Check the installed printer interface without sending data to a printer. */
#include <i86.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  union REGPACK registers;
  unsigned result;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 0xffff;
  intr(0x17, &registers);
  printf("PRINTER=%04X\n", registers.x.ax);
  result = registers.x.ax == 0xded0 ? 0 : 1;
  if (result) {
    const unsigned char __far* screen = MK_FP(0xb800, 0);
    FILE* report = fopen("PRINTSCR.TXT", "wb");
    unsigned cell;
    if (report) {
      for (cell = 0; cell < 2000; ++cell) {
        fputc(screen[cell * 2], report);
        if (cell % 80 == 79) {
          fputc('\n', report);
        }
      }
      fclose(report);
    }
  }
  return result;
}
