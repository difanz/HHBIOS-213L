/* Check the VGA status save area without relying on the driver's capture
 * API. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static unsigned char buffer[1024];

static unsigned char ReadRegister(unsigned port, unsigned index) {
  outp(port, index);
  return inp(port + 1);
}

static void Video(unsigned function, unsigned value) {
  union REGPACK registers;
  memset(&registers, 0, sizeof(registers));
  registers.w.ax = function;
  registers.w.cx = value;
  if (function == 0x0600) {
    registers.w.bx = 0x0700;
    registers.w.dx = 0x184f;
  }
  intr(function == 0x2900 ? 0x16 : 0x10, &registers);
}

static int Capture(FILE* output) {
  unsigned plane;
  unsigned long offset;
  for (plane = 0; plane < 4; ++plane) {
    for (offset = 0; offset < 65536UL; offset += sizeof(buffer)) {
      unsigned char index, map, read_plane;
      _disable();
      index = inp(0x3ce);
      map = ReadRegister(0x3ce, 6);
      read_plane = ReadRegister(0x3ce, 4);
      outpw(0x3ce, 0x0506); /* A000:0000, one complete 64 KiB plane. */
      outpw(0x3ce, (plane << 8) | 4);
      _fmemcpy(buffer, MK_FP(0xa000, (unsigned)offset), sizeof(buffer));
      outpw(0x3ce, (read_plane << 8) | 4);
      outpw(0x3ce, (map << 8) | 6);
      outp(0x3ce, index);
      _enable();
      if (fwrite(buffer, 1, sizeof(buffer), output) != sizeof(buffer)) {
        return 0;
      }
    }
  }
  return 1;
}

static void SeedStatus(unsigned start) {
  unsigned plane, offset;
  unsigned char sequencer_index, map_mask, graphics_index, saved[9];
  volatile unsigned char __far* pixels = MK_FP(0xa000, start);
  _disable();
  sequencer_index = inp(0x3c4);
  map_mask = ReadRegister(0x3c4, 2);
  graphics_index = inp(0x3ce);
  for (offset = 0; offset < 9; ++offset) {
    saved[offset] = ReadRegister(0x3ce, offset);
  }
  outpw(0x3ce, 0x0001);
  outpw(0x3ce, 0x0003);
  outpw(0x3ce, 0x0005);
  outpw(0x3ce, 0x0506);
  outpw(0x3ce, 0xff08);
  for (plane = 0; plane < 4; ++plane) {
    outpw(0x3c4, (0x100 << plane) | 2);
    for (offset = 0; offset < 30 * 80; ++offset) {
      pixels[offset] = (unsigned char)(offset * 53 + plane * 19 + 17);
    }
  }
  for (offset = 0; offset < 9; ++offset) {
    outpw(0x3ce, (saved[offset] << 8) | offset);
  }
  outp(0x3ce, graphics_index);
  outpw(0x3c4, (map_mask << 8) | 2);
  outp(0x3c4, sequencer_index);
  _enable();
}

int main(int argc, char** argv) {
  FILE* output = fopen("STATUSV.BIN", "wb");
  unsigned start;
  unsigned char index;
  if (!output) {
    return 1;
  }
  Video(0x0600, 0);
  Video(0x1500,
        0); /* Settle direct-text normalization before seeding pixels. */
  Video(0x0100, 0x2000); /* No timer-driven text cursor during capture. */
  Video(0x1404, 0);
  index = inp(0x3d4);
  start = (ReadRegister(0x3d4, 12) << 8) | ReadRegister(0x3d4, 13);
  outp(0x3d4, index);
  if (fwrite(&start, sizeof(start), 1, output) != 1) {
    return 2;
  }
  SeedStatus(start + 450U * 80U);
  if (!Capture(output)) {
    return 3;
  }
  Video(0x1400, 0);
  if (argc > 1 && strcmp(argv[1], "panels") == 0) {
    unsigned slot;
    for (slot = 0; slot < 8; ++slot) {
      union REGPACK registers;
      memset(&registers, 0, sizeof(registers));
      registers.w.ax = 0x1417;
      registers.w.dx = 0x0a00 | slot;
      registers.w.bx = 1 + (slot & 1);
      intr(0x10, &registers);
    }
  }
  if (!Capture(output)) {
    return 4;
  }
  Video(0x1400, 0);
  if (!Capture(output)) {
    return 5;
  }
  Video(0x1404, 0);
  if (!Capture(output)) {
    return 6;
  }
  Video(0x2900, 0);
  if (!Capture(output)) {
    return 7;
  }
  Video(0x2900, 0);
  if (!Capture(output)) {
    return 8;
  }
  return fclose(output) != 0;
}
