/* Private, nonresident VGA output for Turbo Vision. No HHBIOS interfaces. */
#ifndef HH_SETUP_SCREEN_H
#define HH_SETUP_SCREEN_H
int screen_start();
void screen_stop();
int screen_active();
const char *screen_text(const char *gb2312);
void screen_paint();
void screen_mouse(TEvent &event);
#endif
