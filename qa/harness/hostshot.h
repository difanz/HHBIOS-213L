/* Optional host-window capture, using the same COM1 handshake as appcap.
 * No guest keyboard event: FFFFh asks the host to capture and acknowledge.
 * Without SCREEN.KEY this is inert. A missing host fails within five seconds.
 */
static int hostrequest(unsigned request)
{
    FILE *flag = fopen("SCREEN.KEY", "rb");
    volatile unsigned long __far *clock = MK_FP(0x40, 0x6c);
    unsigned long start;
    unsigned i;
    if (!flag) return 0;
    fclose(flag);
    outp(0x3fb, 0x80);
    outp(0x3f8, 12); outp(0x3f9, 0);
    outp(0x3fb, 3); outp(0x3fc, 0x0b); outp(0x3f9, 0);
    start = *clock;
    for (i = 0; i < 2; ++i) {
        while (!(inp(0x3fd) & 0x20))
            if ((unsigned long)(*clock-start) >= 91) return 1;
        outp(0x3f8, i ? request>>8 : request&255);
    }
    while (!(inp(0x3fd) & 1))
        if ((unsigned long)(*clock-start) >= 91) return 1;
    return inp(0x3f8) != 0xa5;
}
static int hostshot(void) { return hostrequest(0xffff); }
