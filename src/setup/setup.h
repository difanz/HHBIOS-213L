/* Setup policy is ordinary C++98/C89, independent of DOS and Turbo Vision. */
#ifndef HH_SETUP_H
#define HH_SETUP_H
#include <stdio.h>

enum { FontXms, FontEms, FontLow, FontCount };
enum { VideoVga, Video102, Video104, Video106, VideoEga, VideoHga, VideoCga, VideoCount };
enum { ImePinyin=1, ImeShouwei=2, ImeTelegraph=4, ImeWubi=8 };
enum { AdapterUnknown, AdapterMda, AdapterCga, AdapterEga, AdapterVga };
enum { FileRead5, FileRead4, FileRead2, FileCkbd, FileVga, FileVesa,
       FileEga, FileHga, FileCga, FileHzk, FileFont20, FilePy, FileSw,
       FileDb, FileWbx, FileCount };
enum { BatchSize=4096, IniSize=8192 };
struct Machine {
    unsigned dos_major, dos_minor, conventional_kb, free_kb, umb_kb, cpu;
    unsigned xms_version, xms_largest, xms_total;
    unsigned ems_version, ems_pages, ems_frame, dpmi, adapter;
    unsigned vbe_version, modes, loaded;
    unsigned alloc_strategy, umb_link;
};
struct Files { unsigned long size[FileCount]; };
struct Choices { unsigned font, low, video, ime, paired; };
extern const char * const file_names[FileCount];
extern const char * const font_names[FontCount];
extern const char * const video_names[VideoCount];
extern const char * const video_commands[VideoCount];
void probe_machine(Machine *m);
void scan_files(Files *f);
int safe_directory(const char *path);
void recommend(const Machine *m, const Files *f, Choices *c);
const char *validate(const Machine *m, const Files *f, const Choices *c);
int make_batch(const char *path, const Choices *c, char *out);
/* Preserve all original INI lines except the three IME switches. */
int make_ini(const char *original, const Choices *c, char *out);
const char *save_pair(const char *batch, const char *ini);
void report_machine(FILE *out, const Machine *m, const Files *f);
#endif
