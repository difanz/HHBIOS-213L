/* Private, nonresident VGA output for Turbo Vision. No HHBIOS interfaces. */
#ifndef HHBIOS_SRC_SETUP_SCREEN_H_
#define HHBIOS_SRC_SETUP_SCREEN_H_
class TEvent;
int StartScreen();
void StopScreen();
int IsScreenActive();
const char* EncodeScreenText(const char* gb2312);
void PaintScreen();
void ReadScreenMouse(TEvent& event);
#endif  // HHBIOS_SRC_SETUP_SCREEN_H_
