/* Observe COMMAND's pending input across a physical HHBIOS menu unload. */
#include <conio.h>
#include <dos.h>
#include <errno.h>
#include <i86.h>
#include <process.h>
#include <stdio.h>
#include <string.h>

enum { kFrameBytes = 256 + 8000 };
static unsigned char g_frames[2][kFrameBytes];
static unsigned g_phase, g_stage, g_age, g_request, g_failed;
static union REGPACK g_regs;
extern void install_app_tick(void);

#pragma off(check_stack)
static int ReaderInstalled(void) {
  memset(&g_regs, 0, sizeof(g_regs));
  g_regs.x.ax = 0x4a06;
  g_regs.x.si = 3;
  intr(0x2f, &g_regs);
  return g_regs.x.bx == 0x4a06;
}

void app_poll(void) {
  unsigned __far* bda = MK_FP(0x40, 0);
  unsigned char __far* text;
  unsigned columns, rows, cursor, start, i;
  static const char prompt[] = "C:\\>";
  if (g_phase) {
    if (g_phase < 3 && (inp(0x3fd) & 0x20)) {
      outp(0x3f8, g_phase == 1 ? g_request & 255 : g_request >> 8);
      ++g_phase;
    } else if (g_phase == 3 && (inp(0x3fd) & 1)) {
      if (inp(0x3f8) == 0xa5) {
        g_phase = 0;
      }
    }
    return;
  }
  if (g_stage == 3) {
    return;
  }
  if (g_stage == 2 && ReaderInstalled()) {
    g_age = 0;
    return;
  }
  if (++g_age < 25) {
    return;
  }
  if (g_age > 18 * 90) {
    g_failed = 1;
    return;
  }
  columns = bda[0x4a / 2];
  rows = *(unsigned char __far*)MK_FP(0x40, 0x84) + 1;
  if (columns != 80 || rows > 50 || rows < 25) {
    return;
  }
  cursor = bda[0x50 / 2];
  text = MK_FP(0xb800, bda[0x4e / 2]);
  if (g_stage < 2) {
    if (!ReaderInstalled()) {
      return;
    }
    start = (cursor >> 8) * columns;
    for (i = 0; i < sizeof(prompt) - 1; ++i) {
      if (text[(start + i) * 2] != prompt[i]) {
        return;
      }
    }
    if (g_stage == 1 && (cursor & 255) != 13) {
      return;
    }
  } else if (ReaderInstalled()) {
    return;
  }
  if (bda[0x1a / 2] != bda[0x1c / 2]) {
    return;
  }
  if (g_stage) {
    _fmemcpy(g_frames[g_stage - 1], bda, 256);
    _fmemcpy(g_frames[g_stage - 1] + 256, text, columns * rows * 2);
  }
  g_request = 0x7100 + g_stage++;
  g_phase = 1;
  g_age = 0;
}
#pragma on(check_stack)

int main(void) {
  void(__interrupt __far * old_tick)(void) = _dos_getvect(0x1c);
  FILE* output;
  int status;
  outp(0x3fb, 0x80);
  outp(0x3f8, 12);
  outp(0x3f9, 0);
  outp(0x3fb, 3);
  outp(0x3fc, 0x0b);
  outp(0x3f9, 0);
  install_app_tick();
  status = spawnl(P_WAIT, "C:\\COMMAND.COM", "COMMAND.COM", "/C",
                  "C:\\LOAD.BAT", NULL);
  _dos_setvect(0x1c, old_tick);
  output = fopen("PROMPT.TXT", "w");
  if (output != NULL) {
    fprintf(output, "status=%d errno=%d stage=%u age=%u failed=%u\n", status,
            errno, g_stage, g_age, g_failed);
    fclose(output);
  }
  output = fopen("PROMPT.BIN", "wb");
  if (output == NULL) {
    return 1;
  }
  if (fwrite(g_frames, 1, sizeof(g_frames), output) != sizeof(g_frames)) {
    return 2;
  }
  if (fclose(output) != 0) {
    return 2;
  }
  return status || g_failed || g_stage != 3 ? 3 : 0;
}
