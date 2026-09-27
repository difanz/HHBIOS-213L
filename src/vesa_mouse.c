/* The mouse driver owns hardware, mickeys, buttons and event timing. HHBIOS
 * owns text coordinates and the software text cursor. No B800 cursor writes. */
#include "vesa.h"

extern u32 CALL old33;
extern u16 CALL mouse_thunk_offset;
u32 CALL mouse_target;
u8 CALL mouse_native;
static u16 event_mask;
static u16 mouse_page;
static u16 screen_mask = 0xffff;
static u16 cursor_mask = 0x7700;
static u16 min_x;
static u16 min_y;
static u16 max_x = 639;
static u16 max_y = 199;
static u16 mouse_x;
static u16 mouse_y;
static u16 drawn_position = 0xffff;
static int visibility = -1;
static u8 present;
static u8 attached;
static u16 cursor_type;
static u16 cursor_first;
static u16 cursor_last;
static u16 excluded;
static u16 exclude_left;
static u16 exclude_top;
static u16 exclude_right;
static u16 exclude_bottom;

static u16 StackSegment(void);
#pragma aux StackSegment = "mov ax,ss" value[ax];
#define STACK(registers_ptr) \
  PTR(struct BiosRegisters, StackSegment(), (u16)(registers_ptr))
void CALL mouse_bios(struct BiosRegisters FAR* bios_registers);

/* Native mode-dependent operations must see the physical mode, including
 * nested BIOS queries. Suppress translated callbacks during this operation. */
static void CallMouseInPhysicalMode(struct BiosRegisters FAR* bios_registers) {
  u8 previous_mode = *PTR(u8, 0x40, 0x49);
  mouse_native = 1;
  *PTR(u8, 0x40, 0x49) = hardware_mode;
  mouse_bios(bios_registers);
  *PTR(u8, 0x40, 0x49) = previous_mode;
  mouse_native = 0;
}

static void ClearRegisters(struct BiosRegisters FAR* bios_registers) {
  u16 i;
  for (i = 0; i < sizeof(*bios_registers); ++i) {
    ((u8 FAR*)bios_registers)[i] = 0;
  }
}
static u16 ClampCoordinate(u16 value, u16 low, u16 high) {
  if ((short)value < (short)low) {
    return low;
  }
  return value > high ? high : value;
}
static u16 ToLogicalCoordinate(u16 value, u16 origin, u16 cell_pixels, u16 low,
                               u16 high) {
  u16 result = value <= origin ? 0 : (value - origin) * 8 / cell_pixels;
  return ClampCoordinate(result, low, high) & ~7U;
}
static void TranslateCoordinates(struct BiosRegisters FAR* bios_registers) {
  bios_registers->cx = ToLogicalCoordinate(
      bios_registers->cx, viewport_x, CELL_WIDTH * pixel_scale, min_x, max_x);
  bios_registers->dx =
      ToLogicalCoordinate(bios_registers->dx, viewport_y,
                          raster_height * pixel_scale, min_y, max_y);
}
static void SetPhysicalLimits(void) {
  struct BiosRegisters bios_registers;
  struct BiosRegisters FAR* registers_ptr = STACK(&bios_registers);
  /* Absolute-input drivers normalize against their configured maximum.
   * Keep that range equal to the whole physical surface; logical limits
   * are applied after translation, including margins and custom ranges. */
  ClearRegisters(registers_ptr);
  registers_ptr->ax = 7;
  registers_ptr->cx = 0;
  registers_ptr->dx = screen.width - 1;
  mouse_bios(registers_ptr);
  registers_ptr->ax = 8;
  registers_ptr->cx = 0;
  registers_ptr->dx = screen.height - 1;
  mouse_bios(registers_ptr);
}
static void InstallMouseCallback(void) {
  struct BiosRegisters bios_registers;
  struct BiosRegisters FAR* registers_ptr = STACK(&bios_registers);
  ClearRegisters(registers_ptr);
  registers_ptr->ax = 0x0c;
  registers_ptr->cx = 0x7f;
  registers_ptr->es = resident_segment;
  registers_ptr->dx = mouse_thunk_offset;
  mouse_bios(registers_ptr);
}
static void TransferMouseState(struct BiosRegisters FAR* bios_registers) {
  struct BiosRegisters size_request;
  struct BiosRegisters FAR* registers_ptr = STACK(&size_request);
  u8 FAR* record;
  u16 i;
  u16 driver_state_bytes;
  u16 function = bios_registers->ax;
  ClearRegisters(registers_ptr);
  registers_ptr->ax = 0x15;
  mouse_bios(registers_ptr);
  driver_state_bytes = registers_ptr->bx;
  if (!driver_state_bytes || driver_state_bytes > 65471U) {
    if (function == 0x15) {
      bios_registers->bx = 0;
    }
    return;
  }
  if (function == 0x15) {
    bios_registers->bx = driver_state_bytes + 64;
    return;
  }
  if (bios_registers->dx > 65535U - driver_state_bytes - 64) {
    return;
  }
  record = PTR(u8, bios_registers->es, bios_registers->dx + driver_state_bytes);
  if (function == 0x17 && (record[0] != 'H' || record[1] != 'M' ||
                           record[2] != 'M' || record[3] != 1)) {
    return;
  }
  mouse_bios(bios_registers);
  if (function == 0x16) {
    for (i = 0; i < 64; ++i) {
      record[i] = 0;
    }
    record[0] = 'H';
    record[1] = 'M';
    record[2] = 'M';
    record[3] = 1;
    *(u16 FAR*)(record + 4) = (u16)visibility;
    *(u16 FAR*)(record + 6) = event_mask;
    *(u32 FAR*)(record + 8) = mouse_target;
    *(u16 FAR*)(record + 12) = mouse_page;
    *(u16 FAR*)(record + 14) = screen_mask;
    *(u16 FAR*)(record + 16) = cursor_mask;
    *(u16 FAR*)(record + 18) = min_x;
    *(u16 FAR*)(record + 20) = max_x;
    *(u16 FAR*)(record + 22) = min_y;
    *(u16 FAR*)(record + 24) = max_y;
    *(u16 FAR*)(record + 26) = cursor_type;
    *(u16 FAR*)(record + 28) = cursor_first;
    *(u16 FAR*)(record + 30) = cursor_last;
    *(u16 FAR*)(record + 32) = excluded;
    *(u16 FAR*)(record + 34) = exclude_left;
    *(u16 FAR*)(record + 36) = exclude_top;
    *(u16 FAR*)(record + 38) = exclude_right;
    *(u16 FAR*)(record + 40) = exclude_bottom;
  } else {
    visibility = (short)*(u16 FAR*)(record + 4);
    event_mask = *(u16 FAR*)(record + 6);
    mouse_target = *(u32 FAR*)(record + 8);
    mouse_page = *(u16 FAR*)(record + 12);
    screen_mask = *(u16 FAR*)(record + 14);
    cursor_mask = *(u16 FAR*)(record + 16);
    min_x = ClampCoordinate(*(u16 FAR*)(record + 18), 0, 639);
    max_x = ClampCoordinate(*(u16 FAR*)(record + 20), min_x, 639);
    min_y = ClampCoordinate(*(u16 FAR*)(record + 22), 0, text_rows * 8 - 1);
    max_y = ClampCoordinate(*(u16 FAR*)(record + 24), min_y, text_rows * 8 - 1);
    cursor_type = *(u16 FAR*)(record + 26);
    cursor_first = *(u16 FAR*)(record + 28);
    cursor_last = *(u16 FAR*)(record + 30);
    excluded = *(u16 FAR*)(record + 32);
    exclude_left = *(u16 FAR*)(record + 34);
    exclude_top = *(u16 FAR*)(record + 36);
    exclude_right = *(u16 FAR*)(record + 38);
    exclude_bottom = *(u16 FAR*)(record + 40);
    SetPhysicalLimits();
    InstallMouseCallback();
  }
}
void CALL mouse_resume(void) {
  struct BiosRegisters bios_registers;
  struct BiosRegisters FAR* registers_ptr = STACK(&bios_registers);
  if (!old33) {
    return;
  }
  ClearRegisters(registers_ptr);
  registers_ptr->ax = 0x14;
  mouse_bios(registers_ptr);
  if (!attached) {
    event_mask = registers_ptr->cx;
    mouse_target = ((u32)registers_ptr->es << 16) | registers_ptr->dx;
  }
  ClearRegisters(registers_ptr);
  CallMouseInPhysicalMode(registers_ptr);
  present = registers_ptr->ax == 0xffff;
  if (!present) {
    return;
  }
  attached = 1;
  min_x = min_y = 0;
  max_x = 639;
  max_y = text_rows * 8 - 1;
  mouse_page = 0;
  drawn_position = 0xffff;
  SetPhysicalLimits();
  InstallMouseCallback();
}
void CALL mouse_suspend(void) {
  struct BiosRegisters bios_registers;
  struct BiosRegisters FAR* registers_ptr = STACK(&bios_registers);
  if (!attached || !present) {
    return;
  }
  ClearRegisters(registers_ptr);
  registers_ptr->ax = 0x0c;
  registers_ptr->cx = event_mask;
  registers_ptr->es = (u16)(mouse_target >> 16);
  registers_ptr->dx = (u16)mouse_target;
  mouse_bios(registers_ptr);
  if (visibility >= 0) {
    registers_ptr->ax = 1;
    CallMouseInPhysicalMode(registers_ptr);
  }
  attached = 0;
}

void CALL mouse_dispatch(struct BiosRegisters FAR* bios_registers) {
  u16 function = bios_registers->ax;
  u16 mask;
  u32 target;
  if (!old33) {
    if (!function || function == 0x21) {
      bios_registers->ax = 0;
    }
    return;
  }
  if (!active || !attached) {
    mouse_bios(bios_registers);
    return;
  }
  switch (function) {
    case 0:
    case 0x21:
      CallMouseInPhysicalMode(bios_registers);
      present = bios_registers->ax == 0xffff;
      visibility = -1;
      event_mask = 0;
      mouse_target = 0;
      min_x = min_y = mouse_page = 0;
      max_x = 639;
      max_y = text_rows * 8 - 1;
      screen_mask = 0xffff;
      cursor_mask = 0x7700;
      cursor_type = excluded = 0;
      if (present) {
        SetPhysicalLimits();
        InstallMouseCallback();
      }
      break;
    case 1:
      if (visibility < 0) {
        ++visibility;
      }
      excluded = 0;
      break;
    case 2:
      if (visibility > -32767) {
        --visibility;
      }
      break;
    case 3:
    case 5:
    case 6:
      mouse_bios(bios_registers);
      TranslateCoordinates(bios_registers);
      break;
    case 4: {
      u16 x = bios_registers->cx;
      u16 y = bios_registers->dx;
      /* Native text drivers may quantize physical positions to eight
       * pixels. The last pixel inside the requested cell survives that
       * quantization without falling into the preceding logical cell. */
      bios_registers->cx = viewport_x +
                           ((ClampCoordinate(x, min_x, max_x) & ~7U) + 8) *
                               CELL_WIDTH * pixel_scale / 8 -
                           1;
      bios_registers->dx = viewport_y +
                           ((ClampCoordinate(y, min_y, max_y) & ~7U) + 8) *
                               raster_height * pixel_scale / 8 -
                           1;
      mouse_bios(bios_registers);
      bios_registers->cx = x;
      bios_registers->dx = y;
      break;
    }
    case 7:
      min_x = ClampCoordinate(bios_registers->cx, 0, 639);
      max_x = ClampCoordinate(bios_registers->dx, min_x, 639);
      SetPhysicalLimits();
      break;
    case 8:
      min_y = ClampCoordinate(bios_registers->cx, 0, text_rows * 8 - 1);
      max_y = ClampCoordinate(bios_registers->dx, min_y, text_rows * 8 - 1);
      SetPhysicalLimits();
      break;
    case 10:
      if (bios_registers->bx <= 1) {
        cursor_type = bios_registers->bx;
        if (!bios_registers->bx) {
          screen_mask = bios_registers->cx;
          cursor_mask = bios_registers->dx;
        } else {
          cursor_first = bios_registers->cx;
          cursor_last = bios_registers->dx;
        }
      }
      break;
    case 12:
    case 20:
      mask = event_mask;
      target = mouse_target;
      event_mask = bios_registers->cx;
      mouse_target = ((u32)bios_registers->es << 16) | bios_registers->dx;
      if (function == 20) {
        bios_registers->cx = mask;
        bios_registers->es = (u16)(target >> 16);
        bios_registers->dx = (u16)target;
      }
      break;
    case 0x15:
    case 0x16:
    case 0x17:
      TransferMouseState(bios_registers);
      break;
    case 0x10:
      excluded = 1;
      exclude_left = bios_registers->cx;
      exclude_top = bios_registers->dx;
      exclude_right = bios_registers->si;
      exclude_bottom = bios_registers->di;
      break;
    case 0x1d:
      if (bios_registers->bx < page_count) {
        mouse_page = bios_registers->bx;
      }
      break;
    case 0x1e:
      bios_registers->bx = mouse_page;
      break;
    case 0x26:
      bios_registers->bx = 0;
      bios_registers->cx = 639;
      bios_registers->dx = text_rows * 8 - 1;
      break;
    default:
      mouse_bios(bios_registers);
      break;
  }
}

u16 CALL mouse_event(struct BiosRegisters FAR* bios_registers) {
  if (mouse_native) {
    return 0;
  }
  if (active && attached) {
    TranslateCoordinates(bios_registers);
  }
  return mouse_target && (bios_registers->ax & event_mask);
}

u16 CALL mouse_erase(void) {
  if (drawn_position != 0xffff) {
    u16 i = (drawn_position >> 8) * 80 + (drawn_position & 255);
    shadow[i] = ~*PTR(u16, 0xb800, active_page * page_bytes + i * 2);
    drawn_position = 0xffff;
    return 1;
  }
  return 0;
}
void CALL mouse_poll(void) {
  struct BiosRegisters bios_registers;
  struct BiosRegisters FAR* registers_ptr = STACK(&bios_registers);
  if (!present || !attached) {
    return;
  }
  ClearRegisters(registers_ptr);
  registers_ptr->ax = 3;
  mouse_bios(registers_ptr);
  TranslateCoordinates(registers_ptr);
  mouse_x = registers_ptr->cx / 8;
  mouse_y = registers_ptr->dx / 8;
}
u16 CALL mouse_covers(u16 pos) {
  return present && attached && visibility >= 0 && mouse_page == active_page &&
         !(excluded && (short)(mouse_x * 8 + 7) >= (short)exclude_left &&
           (short)(mouse_x * 8) <= (short)exclude_right &&
           (short)(mouse_y * 8 + 7) >= (short)exclude_top &&
           (short)(mouse_y * 8) <= (short)exclude_bottom) &&
         pos == ((mouse_y << 8) | mouse_x);
}
void CALL mouse_paint(void) {
  /* Only the serialized renderer calls this; callbacks never draw. */
  static struct BiosRegisters bios_registers;
  static u16 bits[CELL_HEIGHT * 2];
  u16 value;
  u16 changed;
  u16 code;
  u16 half = 0;
  u16 i;
  u16 FAR* text;
  if (!active || !mouse_covers((mouse_y << 8) | mouse_x) ||
      mouse_y >= text_rows || mouse_x >= 80) {
    return;
  }
  bios_registers.dx = (mouse_y << 8) | mouse_x;
  boundary(&bios_registers);
  text = PTR(u16, 0xb800, active_page * page_bytes);
  i = mouse_y * 80 + mouse_x;
  value = text[i];
  changed = cursor_type ? value : (value & screen_mask) ^ cursor_mask;
  code = changed & 255;
  if ((changed & 255) == (value & 255)) {
    if (bios_registers.ax == 1 && mouse_x < 79) {
      code = ((value & 255) << 8) | (text[i + 1] & 255);
    } else if (bios_registers.ax == 2 && mouse_x) {
      code = ((text[i - 1] & 255) << 8) | (value & 255);
      half = 1;
    }
  }
  font_get(code, bits);
  if (cursor_type) {
    for (i = 0; i < GLYPH_HEIGHT; ++i) {
      u16 line = i * logical_height / GLYPH_HEIGHT;
      if (line >= cursor_first && line <= cursor_last) {
        bits[half * CELL_HEIGHT + i] = 0xffc0;
      }
    }
  }
  draw_half(bits + half * CELL_HEIGHT, changed >> 8, (mouse_y << 8) | mouse_x);
  drawn_position = (mouse_y << 8) | mouse_x;
}
