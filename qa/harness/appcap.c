/* Wait for fixture text, feed one key at a time and observe application state.
 * Store cursor rows and B800 + the top ten green-plane rows in resident RAM;
 * exit the application, then a normal DOS invocation writes that RAM to disk.
 * No DOS/file I/O or interrupt-vector changes in the timer callback.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <malloc.h>
#include <stdio.h>
#include <string.h>

static unsigned capture_seg, framebuffer, age, settle, finished;
static unsigned keys[64], key_count, step, records;
static unsigned exit_keys[8] = {0x2d00}, exit_count = 1, exit_step;
static unsigned release_alt;
static unsigned physical_keys, transmit, transmit_step;
static unsigned start_keys[8], start_count, start_step, start_length;
static char start_marker[64];
static unsigned char scratch[256];
extern void install_app_tick(void);

static int read_keys(const char *name, unsigned *buffer, unsigned limit, unsigned *count)
{
    FILE *file = fopen(name, "rb");
    unsigned bytes;
    int valid;
    if (!file) return 1;
    bytes = fread(buffer, 1, limit*2, file);
    valid = bytes && !(bytes & 1) && fgetc(file) == EOF && !ferror(file);
    fclose(file);
    if (valid) *count = bytes/2;
    return valid;
}

static int queue_key(unsigned key)
{
    unsigned __far *bda = MK_FP(0x40, 0);
    unsigned head = bda[0x1a/2], tail = bda[0x1c/2];
    unsigned next = tail+2;
    if (physical_keys) {
        if (transmit_step) return 0;
        transmit = key;
        transmit_step = 1;
        return 1;
    }
    if (next >= bda[0x82/2]) next = bda[0x80/2];
    if (next == head) return 0;
    if (key == 0x2100 || key == 0x2d00) {
        /* Match the modifier state associated with Alt-F / Alt-X. */
        *(unsigned char __far *)MK_FP(0x40, 0x17) |= 8;
        *(unsigned char __far *)MK_FP(0x40, 0x18) |= 2;
        release_alt = 1;
    }
    bda[tail/2] = key;
    bda[0x1c/2] = next;
    return 1;
}

static int visible(unsigned char __far *text, const char *marker, unsigned length)
{
    unsigned i, j;
    for (i = 0; i <= 2000-length; ++i) {
        for (j = 0; j < length && text[2*(i+j)] == marker[j]; ++j) { }
        if (j == length) return 1;
    }
    return 0;
}

static void record_step(void)
{
    unsigned cursor = *(unsigned __far *)MK_FP(0x40, 0x50);
    unsigned offset = 18416 + records*164;
    *(unsigned __far *)MK_FP(capture_seg, offset) = step ? keys[step-1] : 0;
    *(unsigned __far *)MK_FP(capture_seg, offset+2) = cursor;
    if ((cursor >> 8) < 25)
        _fmemcpy(MK_FP(capture_seg, offset+4), MK_FP(0xb800, (cursor >> 8)*160), 160);
    ++records;
    *(unsigned __far *)MK_FP(capture_seg, 8) = records;
}

void app_poll(void)
{
    unsigned old4, old5, y;
    unsigned char __far *text = MK_FP(0xb800, 0);
    unsigned __far *bda = MK_FP(0x40, 0);
    if (transmit_step) {
        if (transmit_step < 3 && (inp(0x3fd) & 0x20)) {
            outp(0x3f8, transmit_step == 1 ? transmit & 255 : transmit >> 8);
            ++transmit_step;
        } else if (transmit_step == 3 && (inp(0x3fd) & 1)) {
            if (inp(0x3f8) == 0xa5) transmit_step = 0;
        }
        return;
    }
    if (release_alt) {
        *(unsigned char __far *)MK_FP(0x40, 0x17) &= ~8;
        *(unsigned char __far *)MK_FP(0x40, 0x18) &= ~2;
        release_alt = 0;
    }
    if (finished) {
        if (settle) { --settle; return; }
        if (finished == 1 && bda[0x1a/2] == bda[0x1c/2] && queue_key(exit_keys[exit_step])) {
            if (++exit_step == exit_count) finished = 2;
            settle = 24;
        }
        return;
    }
    ++age;
    if (age >= 18*30) {
        *(unsigned char __far *)MK_FP(capture_seg, 0) = 2;
        finished = 1;
        return;
    }
    if (start_count) {
        if (!settle) {
            if (visible(text, start_marker, start_length)) settle = 1;
        } else if (++settle == 25) {
            if (bda[0x1a/2] != bda[0x1c/2]) { --settle; return; }
            queue_key(start_keys[start_step++]);
            settle = 1;
            if (start_step == start_count) { start_count = 0; settle = 0; }
        }
        return;
    }
    if (!settle) {
        if (visible(text, "HHBIOS-QA", 9)) settle = 1;
    } else if (++settle == 25) {
        _disable();
        if (key_count) {
            /* Observe the previous action before offering the next one. */
            if (bda[0x1a/2] != bda[0x1c/2]) { --settle; return; }
            record_step();
            if (step < key_count) {
                queue_key(keys[step++]);
                settle = step == key_count ? 1 : 21;
                return;
            }
        }
        _fmemcpy(MK_FP(capture_seg, 16), text, 4000);
        outp(0x3ce, 4); old4 = inp(0x3cf);
        outp(0x3ce, 5); old5 = inp(0x3cf);
        outpw(0x3ce, 5);
        outpw(0x3ce, 0x0104); /* green plane: white text on blue background */
        for (y = 0; y < 180; ++y)
            _fmemcpy(MK_FP(capture_seg, 4016+y*80), MK_FP(framebuffer, y*80), 80);
        outpw(0x3ce, 4 | (old4 << 8));
        outpw(0x3ce, 5 | (old5 << 8));
        *(unsigned char __far *)MK_FP(capture_seg, 0) = 1;
        settle = 0;
        finished = 1;
    }
}

int main(int argc, char **argv)
{
    FILE *file;
    union REGPACK r;
    unsigned i, size;
    if (argc != 2) return 1;
    if (strcmp(argv[1], "dump") == 0) {
        file = fopen("CAPSEG.BIN", "rb");
        if (!file || fread(&capture_seg, 2, 1, file) != 1) return 2;
        fclose(file);
        if (*(unsigned char __far *)MK_FP(capture_seg, 0) != 1) return 3;
        file = fopen("APP.BIN", "wb");
        if (!file) return 4;
        for (i = 0; i < 18416; i += size) {
            size = 18416-i < 256 ? 18416-i : 256;
            _fmemcpy(scratch, MK_FP(capture_seg, i), size);
            if (fwrite(scratch, 1, size, file) != size) return 5;
        }
        if (fclose(file)) return 10;
        records = *(unsigned __far *)MK_FP(capture_seg, 8);
        if (records) {
            if (records > 65) return 11;
            file = fopen("KEYLOG.BIN", "wb");
            if (!file) return 12;
            for (i = 0; i < records; ++i) {
                _fmemcpy(scratch, MK_FP(capture_seg, 18416+i*164), 164);
                if (fwrite(scratch, 164, 1, file) != 1) return 13;
            }
            if (fclose(file)) return 14;
        }
        return 0;
    }
    if (strcmp(argv[1], "install") != 0) return 6;
    file = fopen("IRQ.KEY", "rb");
    if (file) {
        fclose(file);
        physical_keys = 1;
        outp(0x3fb, 0x80);
        outp(0x3f8, 12); outp(0x3f9, 0);
        outp(0x3fb, 3); outp(0x3fc, 0x0b); outp(0x3f9, 0);
    }
    if (!read_keys("EXITKEYS.BIN", exit_keys, 8, &exit_count)) return 16;
    if (!read_keys("KEYS.BIN", keys, 64, &key_count)) return 15;
    if (!read_keys("STARTKEY.BIN", start_keys, 8, &start_count)) return 17;
    if (start_count) {
        file = fopen("START.TXT", "rb");
        if (!file) return 18;
        start_length = fread(start_marker, 1, sizeof(start_marker), file);
        if (!start_length || fgetc(file) != EOF || ferror(file)) return 18;
        fclose(file);
    }
    if (_dos_allocmem(0x800, &capture_seg)) return 7;
    _fmemset(MK_FP(capture_seg, 0), 0, 16);
    _fmemcpy(MK_FP(capture_seg, 1), "HHAPP1", 6);
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1406;
    intr(0x10, &r);
    framebuffer = r.x.bp;
    if (framebuffer < 0xa000 || framebuffer > 0xb000) return 8;
    file = fopen("CAPSEG.BIN", "wb");
    if (!file || fwrite(&capture_seg, 2, 1, file) != 1) return 9;
    if (fclose(file)) return 10;
    install_app_tick();
    _dos_keep(0, (FP_OFF(sbrk(0)) + 15) / 16 + 16);
    return 0;
}
