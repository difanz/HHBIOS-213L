/* Font/scanline transitions must preserve every byte of all B800 pages. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  union REGPACK r;
  unsigned __far* text = MK_FP(0xb800, 0);
  unsigned i, n, rows[4] = {43, 50, 25, 28}, heights[4] = {8, 8, 16, 14},
                 data[4][6], back[8];
  FILE* out;
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x180c;
  r.x.bx = 0x0100;
  intr(0x10, &r);
  for (i = 0; i < 16384; ++i) {
    text[i] = 0x1741 + i % 26;
  }
  for (n = 0; n < 4; ++n) {
    if (n < 2) {
      r.x.ax = n ? 0x1202 : 0x1201;
      r.x.bx = 0x30;
      intr(0x10, &r);
    }
    r.x.ax = n < 2 ? 0x1112 : n == 2 ? 0x1114 : 0x1111;
    r.x.bx = 0;
    intr(0x10, &r);
    data[n][0] = *(unsigned char __far*)MK_FP(0x40, 0x84) + 1;
    data[n][1] = *(unsigned __far*)MK_FP(0x40, 0x85);
    data[n][2] = 0;
    for (i = 0; i < 16384; ++i) {
      if (text[i] != 0x1741 + i % 26) {
        ++data[n][2];
      }
    }
    r.x.ax = 0x1130;
    r.x.bx = 0x0600;
    intr(0x10, &r);
    data[n][3] = r.x.cx;
    data[n][4] = r.x.dx & 255;
    data[n][5] = (data[n][0] == rows[n] && data[n][1] == heights[n]);
  }
  out = fopen("ROWGUARD.BIN", "wb");
  if (!out) {
    return 1;
  }
  if (fwrite(data, 1, sizeof(data), out) != sizeof(data)) {
    fclose(out);
    return 2;
  }
  if (fclose(out)) {
    return 2;
  }
  r.x.ax = 0x4f02;
  r.x.bx = 3;
  intr(0x10, &r);
  back[0] = r.x.ax;
  r.x.ax = 0x0f00;
  intr(0x10, &r);
  back[1] = r.x.ax;
  back[2] = *(unsigned char __far*)MK_FP(0x40, 0x84) + 1;
  back[3] = *(unsigned __far*)MK_FP(0x40, 0x85);
  back[4] = *(unsigned __far*)MK_FP(0x40, 0x4c);
  r.x.ax = 0x1130;
  r.x.bx = 0x0600;
  intr(0x10, &r);
  back[5] = r.x.cx;
  r.x.ax = 0x26;
  intr(0x33, &r);
  back[6] = r.x.cx;
  back[7] = r.x.dx;
  out = fopen("ROWBACK.BIN", "wb");
  if (!out) {
    return 1;
  }
  if (fwrite(back, 1, sizeof(back), out) != sizeof(back)) {
    fclose(out);
    return 2;
  }
  return fclose(out) != 0;
}
