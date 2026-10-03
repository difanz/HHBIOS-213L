/* Run the real PRNT consumer against a captured BIOS printer connection. */
#include <dos.h>
#include <errno.h>
#include <i86.h>
#include <process.h>
#include <stdio.h>
#include <string.h>

unsigned char PrintBytes[8192];
unsigned PrintCount, PrintOverflow;
extern void install_print_capture(void);

static void PrintByte(unsigned value) {
  union REGPACK registers;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = value;
  intr(0x17, &registers);
}

int main(void) {
  void(__interrupt __far * original)(void) = _dos_getvect(0x17);
  static const char* filenames[] = {"PRN24.BIN", "PRN32.BIN", "PRN40.BIN"};
  static const char styles[] = {'A', 'u', 'U'};
  union REGPACK registers;
  unsigned i;
  FILE* output;
  int result = 0;
  install_print_capture();
  result = spawnl(P_WAIT, "PRNT.COM", "PRNT.COM", "5", NULL);
  printf("PRNT status=%d errno=%d\n", result, errno);
  /* DOS reports termination type 3 when the child stays resident. */
  if (result < 0 || (result & 255) != 0) {
    return 1;
  }
  result = 0;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 0xffff;
  intr(0x17, &registers);
  printf("PRNT signature=%04X\n", registers.x.ax);
  if (registers.x.ax != 0xded0) {
    return 2;
  }
  for (i = 0; i < 3; ++i) {
    PrintCount = 0;
    PrintByte(27);
    PrintByte('I');
    PrintByte(styles[i]);
    PrintByte(0xd6);
    PrintByte(0xd0);
    PrintByte('A');
    PrintByte(13);
    PrintByte(10);
    output = fopen(filenames[i], "wb");
    if (output == NULL) {
      result = 3;
      break;
    }
    if (fwrite(PrintBytes, 1, PrintCount, output) != PrintCount) {
      result = 3;
    }
    if (fclose(output) != 0) {
      result = 3;
    }
  }
  registers.x.ax = 0x4a06;
  registers.x.si = 0;
  intr(0x2f, &registers);
  _dos_setvect(0x17, original);
  return result || PrintOverflow ? 3 : 0;
}
