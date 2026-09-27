/* Private, nonresident VGA output for Watcom UI. No HHBIOS interfaces. */
#ifndef HHBIOS_SRC_SETUP_SCREEN_H_
#define HHBIOS_SRC_SETUP_SCREEN_H_
void ConfigureScreen(int use_graphics);
void StopScreen();
int IsScreenActive();
const char* EncodeScreenText(const char* gb2312);
void PaintScreen();
#endif  // HHBIOS_SRC_SETUP_SCREEN_H_
