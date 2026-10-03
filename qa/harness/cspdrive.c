/* Run the real editor with BIOS menu keys and redirected DOS line input. */
#include <dos.h>
#include <errno.h>
#include <i86.h>
#include <process.h>
#include <stdio.h>
#include <string.h>

static unsigned char snapshot[8192];

static int Capture(const char* filename, int expected_compact) {
  union REGPACK registers;
  unsigned capacity;
  unsigned dictionary_segment;
  unsigned char __far* resident;
  FILE* output;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 0x2e00;
  registers.x.bx = 0x4b48;
  intr(0x16, &registers);
  if (registers.x.ax != 0x4b48 || registers.x.cx > sizeof(snapshot)) {
    return 1;
  }
  capacity = registers.x.cx;
  registers.x.ax = 0x2e01;
  registers.x.es = FP_SEG(snapshot);
  registers.x.di = FP_OFF(snapshot);
  intr(0x16, &registers);
  if (registers.x.ax != 0x4b48) {
    return 2;
  }
  /* Observe the documented legacy dictionary address to ensure this case
   * really exercises the compact XMS layout rather than its RAM fallback. */
  registers.x.ax = 0x2f00;
  intr(0x16, &registers);
  dictionary_segment =
      *(unsigned __far*)MK_FP(registers.x.bp, registers.x.di + 18);
  resident = MK_FP(dictionary_segment, 16);
  if ((resident[0] != snapshot[16] || resident[1] != snapshot[17]) !=
      expected_compact) {
    return 3;
  }
  output = fopen(filename, "wb");
  if (output == NULL) {
    return 4;
  }
  if (fwrite(snapshot, 1, capacity, output) != capacity) {
    fclose(output);
    return 5;
  }
  return fclose(output) != 0;
}

static int Run(int argc, char** argv) {
  static const unsigned keys[] = {0x0231, 0x0332, 0x0b30};
  union REGPACK registers;
  unsigned i;
  int status;
  int compact = argc > 1 && strcmp(argv[1], "xms") == 0;
  status = Capture("BEFORE.BIN", compact);
  if (status) {
    return 10 + status;
  }
  if (freopen("CSP.IN", "rb", stdin) == NULL) {
    return 20;
  }
  if (freopen("CSP.LOG", "wb", stdout) == NULL) {
    return 20;
  }
  for (i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
    memset(&registers, 0, sizeof(registers));
    registers.x.ax = 0x0500;
    registers.x.cx = keys[i];
    intr(0x16, &registers);
    if (registers.h.al) {
      return 21;
    }
  }
  status = spawnl(P_WAIT, "CSP.COM", "CSP.COM", NULL);
  fprintf(stdout, "Child status %d, errno %d\n", status, errno);
  fflush(stdout);
  if (status != 0) {
    return 22;
  }
  status = Capture("AFTER.BIN", compact);
  return status ? 30 + status : 0;
}

int main(int argc, char** argv) {
  int status = Run(argc, argv);
  FILE* output = fopen("CSPDRV.TXT", "w");
  if (output == NULL) {
    return 40;
  }
  fprintf(output, "%d\n", status);
  fclose(output);
  return status;
}
