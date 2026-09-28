/* Record the public printing-font API without a printer or display driver. */
#include <i86.h>
#include <stdio.h>
#include <string.h>

typedef struct FontRequest {
  unsigned vector;
  unsigned ax;
  unsigned bx;
  unsigned dx;
} FontRequest;

typedef struct FontResult {
  unsigned ax;
  unsigned bx;
  unsigned cx;
  unsigned dx;
  unsigned es;
  unsigned di;
  unsigned ds;
  unsigned si;
  unsigned flags;
  unsigned length;
} FontResult;

static unsigned char bitmap[255 * 3];

static int RecordGlyph(FILE* output, const FontRequest* request) {
  union REGPACK registers;
  FontResult result;
  if (request->vector < 0x7b || request->vector > 0x7d) {
    return 3;
  }
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = request->ax;
  registers.x.bx = request->bx;
  registers.x.dx = request->dx;
  registers.x.es = 0x1234;
  registers.x.di = 0x5a5a;
  intr(request->vector, &registers);
  if (!registers.x.cx || registers.x.cx > 255) {
    return 4;
  }
  result.ax = registers.x.ax;
  result.bx = registers.x.bx;
  result.cx = registers.x.cx;
  result.dx = registers.x.dx;
  result.es = registers.x.es;
  result.di = registers.x.di;
  result.ds = registers.x.ds;
  result.si = registers.x.si;
  result.flags = registers.x.flags;
  result.length = result.cx * 3;
  _fmemcpy(bitmap, MK_FP(result.ds, result.si), result.length);
  if (fwrite(request, sizeof(*request), 1, output) != 1 ||
      fwrite(&result, sizeof(result), 1, output) != 1 ||
      fwrite(bitmap, 1, result.length, output) != result.length) {
    return 5;
  }
  return 0;
}

int main(void) {
  FILE* input = fopen("FONTREQ.BIN", "rb");
  FILE* output;
  FontRequest request;
  size_t length;
  int result = 0;
  if (!input) {
    return 1;
  }
  output = fopen("FONTRES.BIN", "wb");
  if (!output) {
    fclose(input);
    return 2;
  }
  if (fwrite("HHPRINT1", 1, 8, output) != 8) {
    result = 5;
  }
  while (!result && (length = fread(&request, 1, sizeof(request), input)) != 0) {
    if (length != sizeof(request)) {
      result = 6;
    } else {
      result = RecordGlyph(output, &request);
    }
  }
  if (ferror(input)) {
    result = 6;
  }
  fclose(input);
  if (fclose(output)) {
    result = 5;
  }
  return result;
}
