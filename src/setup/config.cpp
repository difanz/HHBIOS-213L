#include "setup.h"
#include <ctype.h>
#include <string.h>
#include <sys/stat.h>

const char * const file_names[FileCount] = {
    "READ5.COM", "READ4.COM", "READ2.COM", "CKBD.COM", "VGA.COM", "VESA.COM",
    "EGA.COM", "HGA.COM", "CGA.COM", "HZK16", "HH20.FNT", "PYMB", "SWMB", "DBMB", "WBX.COM"
};
const char * const font_names[FontCount] = {"XMS (READ5)", "EMS 4.0 (READ4)", "Conventional (READ2)"};
const char * const video_names[VideoCount] = {
    "VGA 640x480", "VESA 800x600", "VESA 1024x768", "VESA 1280x1024",
    "EGA 640x350", "Hercules (manual)", "CGA 640x200"
};
const char * const video_commands[VideoCount] = {
    "VGA.COM", "VESA.COM /M:102", "VESA.COM /M:104", "VESA.COM /M:106",
    "EGA.COM", "HGA.COM", "CGA.COM"
};

void scan_files(Files *f)
{
    unsigned i;
    struct stat st;
    memset(f, 0, sizeof(*f));
    for (i=0; i<FileCount; ++i)
        if (!stat(file_names[i], &st) && (st.st_mode & S_IFREG))
            f->size[i] = st.st_size;
    /* A truncated/incompatible VESA font must not be recommended. */
    if (f->size[FileFont20]) {
        unsigned char h[32];
        FILE *fp = fopen("HH20.FNT", "rb");
        int ok = fp && fread(h, 1, sizeof(h), fp)==sizeof(h);
        if (fp) fclose(fp);
        if (!ok || memcmp(h, "HH20F01\n", 8) || h[8]!=10 || h[9] ||
            h[10]!=23 || h[11] ||
            (unsigned long)h[16]+((unsigned long)h[17]<<8)+
            ((unsigned long)h[18]<<16)+((unsigned long)h[19]<<24)+32 != f->size[FileFont20])
            f->size[FileFont20] = 0;
    }
}

int safe_directory(const char *path)
{
    unsigned i, component=0;
    /* READ5's legacy executable-path buffer is 40 bytes including HZK16. */
    if (strlen(path)>32 || !isalpha((unsigned char)path[0]) ||
        path[1]!=':' || path[2]!='\\') return 0;
    for (i=3; path[i]; ++i) {
        unsigned char c=(unsigned char)path[i];
        if (c=='\\') { if (!component) return 0; component=0; }
        else {
            /* Conservative DOS 8.3 directory names; no COMMAND.COM expansion. */
            if (!(isalnum(c) || c=='_' || c=='-' || c=='~') || ++component>8) return 0;
        }
    }
    return i==3 || component!=0;
}

static int vesa_memory(const Machine *m, const Files *f, const Choices *c)
{
    /* VESA also retains 32 KiB of text pages and 4 KiB of downloaded font. */
    unsigned long kb=(f->size[FileFont20]-32+1023)/1024+36;
    unsigned xms=c->font==FontXms ? 256 : 0;
    unsigned ems=c->font==FontEms ? 16 : 0;
    /* VESA tries XMS, then EMS. Account for READ5/READ4 loaded beforehand.
     * Subtracting READ5 from the largest block is deliberately conservative:
     * query-only detection cannot promise the manager's allocation placement. */
    return (m->xms_largest>=kb+xms && m->xms_total>=kb+xms) ||
           (m->ems_version>=0x40 && m->ems_pages>=ems+(kb+15)/16);
}

const char *validate(const Machine *m, const Files *f, const Choices *c)
{
    unsigned long conventional=64; /* keyboard, display, stacks and load margin */
    unsigned long tables=0;
    unsigned i;
    static const unsigned drivers[VideoCount] = {
        FileVga, FileVesa, FileVesa, FileVesa, FileEga, FileHga, FileCga
    };
    if (c->font>=FontCount || c->video>=VideoCount || c->low>1 || c->paired>1 || c->ime>15)
        return "Invalid configuration values.";
    if (m->dos_major<3) return "HHBIOS setup requires DOS 3.0 or later.";
    if (m->loaded) return "HHBIOS is already loaded. Configure from a clean DOS session.";
    if (!f->size[FileCkbd]) return "Missing CKBD.COM in the installation directory.";
    if (f->size[FileHzk]!=261696UL) return "HZK16 must contain exactly 261696 bytes (GB2312 16x16).";
    if (!f->size[c->font]) return "The selected READ*.COM is missing.";
    if (c->font==FontXms && (m->xms_largest<256 || m->xms_total<256))
        return "READ5 needs a free 256 KiB XMS block.";
    if (c->font==FontEms && (m->ems_version<0x40 || m->ems_pages<16 || !m->ems_frame))
        return "READ4 needs EMS 4.0, a page frame and 16 free pages.";
    if (!f->size[drivers[c->video]]) return "The selected display driver is missing.";
    if (c->video==VideoVga && m->adapter!=AdapterVga)
        return "VGA was not detected. Select the actual adapter.";
    if (c->video==VideoEga && m->adapter<AdapterEga)
        return "EGA/VGA was not detected.";
    if (c->video==VideoCga && m->adapter!=AdapterCga && m->adapter<AdapterEga)
        return "A CGA-compatible color adapter was not detected.";
    if (c->video==VideoHga && m->adapter!=AdapterMda)
        return "Hercules requires a monochrome adapter. Confirm the hardware manually.";
    if (c->video>=Video102 && c->video<=Video106) {
        if (!(m->modes & (1U<<(c->video-Video102))))
            return "BIOS does not report a compatible planar VBE mode.";
        if (!f->size[FileFont20]) return "Missing or invalid HH20.FNT for VESA.";
        if (!vesa_memory(m, f, c)) return "Insufficient XMS/EMS for both font stores. Choose VGA or another reader.";
    }
    for (i=0; i<3; ++i) if (c->ime & (1U<<i)) {
        if (!f->size[FilePy+i]) return "A selected input-method table (PYMB/SWMB/DBMB) is missing.";
        tables+=f->size[FilePy+i];
    }
    if (tables>45000UL) return "Selected input tables exceed CKBD's 64 KiB segment. Select fewer tables.";
    if ((c->ime & ImeWubi) && !f->size[FileWbx]) return "Wubi requires WBX.COM.";
    conventional+=(tables+1023)/1024;
    if (c->ime & ImeWubi) conventional+=48;
    if (c->font==FontLow) conventional+=256;
    /* Do not promise all modules fit in a fragmented UMB just because one exists. */
    if (m->free_kb<conventional) return "Not enough conventional memory for a conservative load estimate.";
    return 0;
}

void recommend(const Machine *m, const Files *f, Choices *c)
{
    unsigned v, r;
    static const unsigned preference[] = { Video102, VideoVga, VideoEga, VideoCga };
    memset(c, 0, sizeof(*c));
    c->paired=1;
    c->font=FontLow;
    c->video=VideoVga;
    /* Probe recommendations never infer Hercules from an MDA equipment bit. */
    /* Preserve conventional memory before choosing a larger framebuffer. */
    for (r=0; r<FontCount; ++r)
        for (v=0; v<sizeof(preference)/sizeof(preference[0]); ++v) {
            Choices trial=*c;
            trial.video=preference[v]; trial.font=r;
            if (!validate(m,f,&trial)) {
                *c=trial;
                if (f->size[FilePy]) {
                    trial.ime=ImePinyin;
                    if (!validate(m,f,&trial)) *c=trial;
                }
                return;
            }
        }
}

int make_batch(const char *path, const Choices *c, char *out)
{
    const char *low=c->low ? " /N" : "";
    char *p=out;
    if (!safe_directory(path) || c->font>=FontCount || c->video>=VideoCount) return 0;
    p+=sprintf(p, "@ECHO OFF\r\nREM HHBIOS startup - generated by SETUP.EXE\r\n"
        "REM Run once from a clean DOS session. Reboot to change TSRs.\r\n"
        "%c:\r\nCD %s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n", path[0],path+2);
    /* Explicit current-directory paths avoid accidentally loading a different
     * copy from PATH. The directory also supplies VESA's HH20.FNT. */
    p+=sprintf(p,".\\%s%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n"
        ".\\CKBD.COM /%c%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n"
        ".\\%s%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n",
        file_names[c->font], c->font==FontLow ? "" : low,
        c->paired ? 'E' : 'B', low, video_commands[c->video],low);
    /* WBX uses INT 27h, does not implement /N or internal UMB relocation. */
    if (c->ime & ImeWubi) p+=sprintf(p,".\\WBX.COM\r\n");
    sprintf(p,"GOTO HHEND\r\n:HHFAIL\r\n"
        "ECHO HHBIOS load failed. Check the message above; reboot before retrying.\r\n:HHEND\r\n@ECHO ON\r\n");
    return 1;
}

static const unsigned char defaults[32] = {
    2,1,5,0x39,0,0x1e,0x1a,0x4e,0x4a,0,2,
    0x64,0x68,0x69,0x6a,0x6b,0x66,0x6d,0x6c,0x71,0x86,0x85,0x62,0x70,0x67,0,0,
    0x4e,0x30,0x4e,0x4e,0x4e
};

int make_ini(const char *original, const Choices *c, char *out)
{
    unsigned i;
    char *p=out;
    const char *line=original, *end;
    for (i=0; i<32; ++i) {
        unsigned value=defaults[i];
        unsigned length=0;
        if (original && *original) {
            end=strchr(line,'\n');
            if (!end || end-line<2 || !isxdigit((unsigned char)line[0]) ||
                !isxdigit((unsigned char)line[1])) return 0;
            length=(unsigned)(end-line+1);
            if ((unsigned)(p-out)+length+256>=IniSize) return 0;
        }
        if (i>=29) value=c->ime & (1U<<(i-29)) ? 'Y' : 'N';
        if (length) {
            memcpy(p,line,length);
            if (i>=29) { char hex[3]; sprintf(hex,"%02X",value); memcpy(p,hex,2); }
            p+=length; line+=length;
        } else p+=sprintf(p,"%02X\r\n",value);
    }
    /* Preserve trailing comments and DOS EOF if supplied. */
    if (original && *original) {
        if (strlen(line)+(unsigned)(p-out)>=IniSize) return 0;
        strcpy(p,line);
    } else *p=0;
    return 1;
}

static int exists(const char *name)
{
    struct stat st;
    return !stat(name,&st);
}
static int regular_or_absent(const char *name)
{
    struct stat st;
    return stat(name,&st) || (st.st_mode & S_IFMT)==S_IFREG;
}
static int write_file(const char *name, const char *data)
{
    FILE *fp=fopen(name,"wb");
    int ok;
    if (!fp) return 0;
    ok=fwrite(data,1,strlen(data),fp)==strlen(data);
    if (fclose(fp)) ok=0;
    return ok;
}

const char *save_pair(const char *batch, const char *ini)
{
    int bat=exists("HHBIOS.BAT"), oldini=exists("213L.INI");
    int movedbat=0, movedini=0, newbat=0;
    if (!regular_or_absent("HHBIOS.BAT") || !regular_or_absent("213L.INI"))
        return "HHBIOS.BAT and 213L.INI must be ordinary files, not directories/devices.";
    if (exists("HHBAT.$$$") || exists("HHINI.$$$"))
        return "Temporary HHBAT.$$$/HHINI.$$$ already exist. Inspect them before retrying.";
    if ((bat && exists("HHBIOS.BAK")) || (oldini && exists("213L.BAK")))
        return "A .BAK backup already exists. Move it aside before saving again.";
    if (!write_file("HHBAT.$$$",batch) || !write_file("HHINI.$$$",ini)) goto fail;
    if (bat) { if (rename("HHBIOS.BAT","HHBIOS.BAK")) goto fail; movedbat=1; }
    if (oldini) { if (rename("213L.INI","213L.BAK")) goto fail; movedini=1; }
    if (rename("HHBAT.$$$","HHBIOS.BAT")) goto fail;
    newbat=1;
    if (rename("HHINI.$$$","213L.INI")) goto fail;
    return 0;
fail:
    if (newbat) remove("HHBIOS.BAT");
    if (movedbat) rename("HHBIOS.BAK","HHBIOS.BAT");
    if (movedini) rename("213L.BAK","213L.INI");
    remove("HHBAT.$$$"); remove("HHINI.$$$");
    return "Could not save both files. Check write access/free space and any .BAK files.";
}

void report_machine(FILE *out, const Machine *m, const Files *f)
{
    unsigned i;
    fprintf(out,"DOS=%u.%u\nCONVENTIONAL_KB=%u\nAFTER_EXIT_KB=%u\nUMB_KB=%u\nCPU=%u\n"
        "XMS_VERSION=%u\nXMS_LARGEST_KB=%u\nXMS_TOTAL_KB=%u\n"
        "EMS_VERSION=%u\nEMS_PAGES=%u\nEMS_FRAME=%u\nDPMI=%u\nADAPTER=%u\n"
        "VBE_VERSION=%u\nVBE_MODES=%u\nHHBIOS_LOADED=%u\nALLOC_STRATEGY=%u\nUMB_LINK=%u\n",
        m->dos_major,m->dos_minor,m->conventional_kb,m->free_kb,m->umb_kb,m->cpu,
        m->xms_version,m->xms_largest,m->xms_total,m->ems_version,m->ems_pages,
        m->ems_frame,m->dpmi,m->adapter,m->vbe_version,m->modes,m->loaded,
        m->alloc_strategy,m->umb_link);
    for (i=0; i<FileCount; ++i) fprintf(out,"%s=%lu\n",file_names[i],f->size[i]);
}
