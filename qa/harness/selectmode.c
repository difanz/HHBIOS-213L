/* Discover a planar mode by physical geometry; never assume vendor numbers. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned char controller[512], info[256];
static unsigned word(const unsigned char* p) {
  return p[0] | ((unsigned)p[1] << 8);
}
int main(int argc, char** argv) {
  union REGPACK r;
  unsigned w, h, n, mode = 0xffff;
  unsigned long list;
  FILE* out;
  if (argc != 3) {
    return 1;
  }
  w = atoi(argv[1]);
  h = atoi(argv[2]);
  memset(&r, 0, sizeof(r));
  memcpy(controller, "VBE2", 4);
  r.x.ax = 0x4f00;
  r.x.es = FP_SEG(controller);
  r.x.di = FP_OFF(controller);
  intr(0x10, &r);
  if (r.x.ax == 0x004f && !memcmp(controller, "VESA", 4)) {
    list = (unsigned long)word(controller + 16) * 16 + word(controller + 14);
    for (n = 0; n < 512 && list <= 0xffffeUL; ++n, list += 2) {
      mode =
          *(unsigned __far*)MK_FP((unsigned)(list >> 4), (unsigned)(list & 15));
      if (mode == 0xffff) {
        break;
      }
      memset(info, 0, sizeof(info));
      memset(&r, 0, sizeof(r));
      r.x.ax = 0x4f01;
      r.x.cx = mode;
      r.x.es = FP_SEG(info);
      r.x.di = FP_OFF(info);
      intr(0x10, &r);
      if (r.x.ax == 0x004f && (word(info) & 0x79) == 0x19 &&
          word(info + 18) == w && word(info + 20) == h && info[25] == 4 &&
          info[27] == 3) {
        break;
      }
      mode = 0xffff;
    }
  }
  out = fopen("VMODE.BAT", "wb");
  if (!out) {
    return 2;
  }
  if (mode == 0xffff) {
    fprintf(out, "@echo off\r\necho unavailable>UNSUP.TXT\r\n");
  } else {
    fprintf(out, "@echo off\r\nVESA /M:%x\r\n", mode);
  }
  if (fclose(out)) {
    return 3;
  }
  out = fopen("MODESEL.BIN", "wb");
  if (!out) {
    return 2;
  }
  if (fwrite(&mode, 2, 1, out) != 1 ||
      fwrite(info, 1, sizeof(info), out) != sizeof(info)) {
    fclose(out);
    return 3;
  }
  return fclose(out) != 0;
}
