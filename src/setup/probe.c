#include <dos.h>
#include <stdlib.h>
#include <string.h>

#include "setup.h"
#include "vesa.h"

static union REGS bios_registers;
static struct SREGS segments;
static void CallInterrupt(unsigned number, unsigned ax) {
  bios_registers.x.ax = ax;
  int86x(number, &bios_registers, &bios_registers, &segments);
}

static unsigned DetectProcessor() {
  unsigned result;
  // clang-format off
  __asm {
    pushf
    pop dx
    mov ax,dx
    and ax,0fffh
    push ax
    popf
    pushf
    pop ax
    and ax,0f000h
    mov bx,86
    cmp ax,0f000h
    je cpu_done
    mov ax,dx
    or ax,7000h
    push ax
    popf
    pushf
    pop ax
    and ax,7000h
    mov bx,286
    jz cpu_done
    mov bx,386
  cpu_done:
    push dx
    popf
    mov result,bx
  }
  // clang-format on
  return result;
}

static unsigned AvailableMemoryAfterExit() {
  unsigned segment;
  unsigned block_paragraphs;
  unsigned owner;
  unsigned count = 0;
  unsigned long free_run = 0;
  unsigned long largest_run = 0;
  unsigned char far* mcb;
  CallInterrupt(0x21, 0x5200);
  segment = *(unsigned far*)MK_FP(segments.es, bios_registers.x.bx - 2);
  /* Only inspect conventional DOS MCBs. Treat this process and its heap /
   * environment as reclaimable. No allocation, coalescing or UMB linking. */
  while (segment >= 0x50 && segment < 0xa000 && ++count < 4096) {
    mcb = (unsigned char far*)MK_FP(segment, 0);
    if (mcb[0] != 'M' && mcb[0] != 'Z') {
      break;
    }
    owner = *(unsigned far*)(mcb + 1);
    block_paragraphs = *(unsigned far*)(mcb + 3);
    if ((unsigned long)segment + block_paragraphs + 1 > 0xa000UL) {
      break;
    }
    if (!owner || owner == _psp) {
      free_run += block_paragraphs + 1UL;
    } else {
      free_run = 0;
    }
    if (free_run > largest_run) {
      largest_run = free_run;
    }
    if (mcb[0] == 'Z') {
      break;
    }
    segment += block_paragraphs + 1;
  }
  return largest_run ? (unsigned)((largest_run - 1) / 64) : 0;
}

static void ProbeUmb(MachineCapabilities* machine) {
  if (machine->dos_major < 5) {
    return;
  }
  CallInterrupt(0x21, 0x5800);
  if (bios_registers.x.cflag) {
    return;
  }
  machine->alloc_strategy = bios_registers.x.ax;
  CallInterrupt(0x21, 0x5802);
  if (bios_registers.x.cflag) {
    return;
  }
  machine->umb_link = bios_registers.h.al;
  bios_registers.x.bx = 1;
  CallInterrupt(0x21, 0x5803);
  if (bios_registers.x.cflag) {
    return;
  }
  bios_registers.x.bx = 0x41;
  CallInterrupt(0x21, 0x5801); /* upper only, best fit */
  if (!bios_registers.x.cflag) {
    bios_registers.x.bx = 0xffff;
    CallInterrupt(0x21, 0x4800);
    if (bios_registers.x.cflag && bios_registers.x.ax == 8) {
      machine->umb_kb = bios_registers.x.bx / 64;
    } else if (!bios_registers.x.cflag) {
      segments.es = bios_registers.x.ax;
      CallInterrupt(0x21, 0x4900);
    }
  }
  bios_registers.x.bx = machine->alloc_strategy;
  CallInterrupt(0x21, 0x5801);
  bios_registers.x.bx = machine->umb_link;
  CallInterrupt(0x21, 0x5803);
}

static void ProbeExtendedMemory(MachineCapabilities* machine) {
  void(far * xms_entry)();
  unsigned version;
  unsigned largest;
  unsigned total;
  unsigned error;
  CallInterrupt(0x2f, 0x4300);
  if (bios_registers.h.al == 0x80) {
    CallInterrupt(0x2f, 0x4310);
    xms_entry = (void(far*)())MK_FP(segments.es, bios_registers.x.bx);
    // clang-format off
    __asm {
      xor ah,ah
      call dword ptr xms_entry
      mov version,ax
      mov ah,8
      call dword ptr xms_entry
      mov largest,ax
      mov total,dx
      xor bh,bh
      mov error,bx
    }
    // clang-format on
    machine->xms_version = version;
    if (!error) {
      machine->xms_largest = largest;
      machine->xms_total = total;
    }
  }
  CallInterrupt(0x21, 0x3567);
  if (_fmemcmp(MK_FP(segments.es, 10), "EMMXXXX0", 8)) {
    return;
  }
  CallInterrupt(0x67, 0x4000);
  if (bios_registers.h.ah) {
    return;
  }
  CallInterrupt(0x67, 0x4600);
  if (bios_registers.h.ah) {
    return;
  }
  machine->ems_version = bios_registers.h.al;
  CallInterrupt(0x67, 0x4200);
  if (!bios_registers.h.ah) {
    machine->ems_pages = bios_registers.x.bx;
  }
  CallInterrupt(0x67, 0x4100);
  if (!bios_registers.h.ah) {
    machine->ems_frame = bios_registers.x.bx;
  }
}

static void ProbeVideo(MachineCapabilities* machine) {
  static unsigned char controller[512];
  static unsigned char info[256];
  static unsigned char edid[128];
  unsigned i, number;
  unsigned long address;
  CallInterrupt(0x11, 0);
  machine->adapter =
      (bios_registers.x.ax & 0x30) == 0x30 ? kAdapterMda : kAdapterCga;
  bios_registers.x.bx = 0;
  CallInterrupt(0x10, 0x1a00);
  if (bios_registers.h.al == 0x1a &&
      (bios_registers.h.bl == 7 || bios_registers.h.bl == 8)) {
    machine->adapter = kAdapterVga;
  } else {
    bios_registers.x.bx = 0x10;
    CallInterrupt(0x10, 0x1200);
    if (bios_registers.h.bl != 0x10) {
      machine->adapter = kAdapterEga;
    }
  }
  if (machine->adapter != kAdapterVga) {
    return;
  }
  memset(controller, 0, sizeof(controller));
  memcpy(controller, "VBE2", 4);
  segments.es = FP_SEG(controller);
  bios_registers.x.di = FP_OFF(controller);
  CallInterrupt(0x10, 0x4f00);
  if (bios_registers.x.ax != 0x4f || memcmp(controller, "VESA", 4)) {
    return;
  }
  machine->vbe_version = *(unsigned*)(controller + 4);
  address = (unsigned long)*(unsigned*)(controller + 16) * 16 +
            *(unsigned*)(controller + 14);
  memset(edid, 0, sizeof(edid));
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.x.bx = 1;
  segments.es = FP_SEG(edid);
  bios_registers.x.di = FP_OFF(edid);
  CallInterrupt(0x10, 0x4f15); /* primary controller, EDID base block */
  if (bios_registers.x.ax == 0x004f) {
    DecodePreferredTiming(machine, edid);
  }
  /* Normalize every far address; a BIOS list can cross a segment boundary. */
  for (i = 0; address && address <= 0xffffeUL && i < 512; ++i, address += 2) {
    number = *(unsigned far*)MK_FP((unsigned)(address >> 4),
                                   (unsigned)(address & 15));
    if (number == 0xffff) {
      break;
    }
    if (number < 0x100 || number > 0x3fff) {
      continue;
    }
    memset(info, 0, sizeof(info));
    memset(&bios_registers, 0, sizeof(bios_registers));
    segments.es = FP_SEG(info);
    bios_registers.x.di = FP_OFF(info);
    bios_registers.x.cx = number;
    CallInterrupt(0x10, 0x4f01);
    if (bios_registers.x.ax == 0x4f) {
      if (controller[10] & 2) {
        info[0] |= 0x20; /* Controller-wide non-VGA restriction. */
      }
      AddDisplayMode(machine, number, info);
    }
  }
  if (i == 512 || address > 0xffffeUL) {
    machine->display_truncated = 1;
  }
}

int SwitchTextRows(unsigned rows) {
  unsigned char far* bda = (unsigned char far*)MK_FP(0x40, 0);
  unsigned previous_rows = bda[0x84] + 1;
  unsigned previous_height = *(unsigned far*)(bda + 0x85);
  unsigned previous_scan = bda[0x89] & 0x10 ? 2 : bda[0x89] & 0x80 ? 0 : 1;
  if (!TextRowsMask(rows) || bda[0x49] > 3 ||
      *(unsigned far*)(bda + 0x4a) != 80) {
    return 0;
  }
  CallInterrupt(0x10, 0x1411);
  if (bios_registers.x.ax != 0x5356) {
    return 0;
  }
  bios_registers.x.bx = 0x30;
  CallInterrupt(0x10, rows == 43 ? 0x1201 : 0x1202);
  bios_registers.x.bx = 0;
  CallInterrupt(0x10, rows == 25 ? 0x1114 : 0x1112);
  if (bda[0x84] + 1 == rows &&
      *(unsigned far*)(bda + 0x85) == (rows == 25 ? 16 : 8)) {
    return 1;
  }
  /* Rejected geometry must not leave a changed scan-line selection. */
  bios_registers.x.bx = 0x30;
  CallInterrupt(0x10, 0x1200 | previous_scan);
  if (bda[0x84] + 1 != previous_rows) {
    bios_registers.x.bx = 0;
    CallInterrupt(0x10, previous_height == 8    ? 0x1112
                        : previous_height == 14 ? 0x1111
                                                : 0x1114);
  }
  return 0;
}

void ProbeMachine(MachineCapabilities* machine) {
  memset(machine, 0, sizeof(*machine));
  memset(&bios_registers, 0, sizeof(bios_registers));
  segread(&segments);
  machine->cpu = DetectProcessor();
  CallInterrupt(0x21, 0x3000);
  machine->dos_major = bios_registers.h.al;
  machine->dos_minor = bios_registers.h.ah;
  CallInterrupt(0x12, 0);
  machine->conventional_kb = bios_registers.x.ax;
  if (machine->dos_major >= 3) {
    machine->free_kb = AvailableMemoryAfterExit();
  }
  ProbeUmb(machine);
  ProbeExtendedMemory(machine);
  ProbeVideo(machine);
  CallInterrupt(0x2f, 0x1687);
  machine->dpmi = bios_registers.x.ax == 0;
  bios_registers.x.bx = 0;
  bios_registers.x.si = 3;
  CallInterrupt(0x2f, 0x4a06);
  machine->loaded = bios_registers.x.bx == 0x4a06;
}
