/* Paint the idle status row, then open the system menu for the host.
 * The timer stuffs the BIOS keyboard buffer so each frame can be captured
 * without a host keystroke. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

#include "hostshot.h"

static volatile unsigned g_ticks;
static volatile unsigned g_phase;
static volatile unsigned g_request;
static volatile unsigned g_stage;
static volatile unsigned g_armed;

extern void install_app_tick(void);

static void PushKey(unsigned key) {
  unsigned __far* bda = MK_FP(0x40, 0);
  unsigned head = bda[0x1a / 2];
  unsigned tail = bda[0x1c / 2];
  unsigned start = bda[0x80 / 2];
  unsigned end = bda[0x82 / 2];
  unsigned next;
  if (start == 0 || end == 0) {
    start = 0x1e;
    end = 0x3e;
  }
  next = tail + 2;
  if (next >= end) {
    next = start;
  }
  if (next == head) {
    return;
  }
  *(unsigned __far*)MK_FP(0x40, tail) = key;
  bda[0x1c / 2] = next;
}

#pragma off(check_stack)
void app_poll(void) {
  if (!g_armed) {
    return;
  }
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
  if (g_stage == 0) {
    if (++g_ticks < 18) {
      return;
    }
    g_request = 0x7201;
    g_phase = 1;
    g_stage = 1;
    g_ticks = 0;
    return;
  }
  if (g_stage == 1) {
    if (g_ticks == 0) {
      PushKey(0x4d00);
    }
    if (++g_ticks < 18) {
      return;
    }
    g_request = 0x7202;
    g_phase = 1;
    g_stage = 2;
    g_ticks = 0;
    return;
  }
  if (g_stage == 2) {
    if (g_ticks == 0) {
      PushKey(0x4d00);
      PushKey(0x4d00);
      PushKey(0x1c0d);
    }
    if (++g_ticks < 27) {
      return;
    }
    g_request = 0x7203;
    g_phase = 1;
    g_stage = 3;
    g_ticks = 0;
    return;
  }
  if (g_stage == 3) {
    PushKey(0x316e);
    g_stage = 4;
  }
}

static unsigned ReadKey(void) {
  union REGPACK regs;
  memset(&regs, 0, sizeof(regs));
  regs.w.ax = 0x1000;
  intr(0x16, &regs);
  return regs.w.ax;
}

static void CallKeyboard(unsigned ax) {
  union REGPACK regs;
  memset(&regs, 0, sizeof(regs));
  regs.w.ax = ax;
  intr(0x16, &regs);
}

int main(void) {
  CallKeyboard(0x2900);
  if (hostrequest(0x7100)) {
    return 1;
  }
  {
    void(__interrupt __far* old_tick)(void) = _dos_getvect(0x1c);
    install_app_tick();
    g_armed = 1;
    CallKeyboard(0x2162);
    g_armed = 0;
    _dos_setvect(0x1c, old_tick);
  }
  PushKey(0x342e);
  return ReadKey() == 0x342e ? 0 : 2;
}
