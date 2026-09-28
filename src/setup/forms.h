/* Dialog storage is owned by the caller until RunForm returns. */
#ifndef HHBIOS_SRC_SETUP_FORMS_H_
#define HHBIOS_SRC_SETUP_FORMS_H_

#include "setup.h"
#include "stdui.h"
#include "uidialog.h"

enum {
  kCmdProbe = EV_FIRST_UNUSED,
  kCmdMemory,
  kCmdVideo,
  kCmdInput,
  kCmdPreview,
  kCmdLanguage,
  kCmdKeyboard,
  kCmdDisplayOptions,
  kCmdModules,
  kCmdBindings,
  kCmdChange,
  kCmdColors,
  kCmdAccept,
  kCmdCancel,
  kCmdExit
};

typedef struct Form {
  VFIELD fields[64];
  a_hot_spot buttons[12];
  a_radio radios[16];
  a_check checks[16];
  unsigned field_count;
  unsigned button_count;
  unsigned radio_count;
  unsigned check_count;
  unsigned text_used;
  char text[4096];
  void (*changed)(a_dialog* dialog, void* data);
  void* change_data;
} Form;

const char* LocalizedText(const char* en, const char* zh);
void AddField(Form* form, unsigned row, unsigned col, unsigned height,
              unsigned width, a_field_type type, void* data);
void AddParagraph(Form* form, unsigned row, unsigned col, unsigned width,
                  const char* text);
void AddButton(Form* form, unsigned row, unsigned col, unsigned width,
               const char* label, ui_event event, int default_button);
void AddRadio(Form* form, unsigned row, const char* label,
              a_radio_group* group, unsigned value);
void AddCheck(Form* form, unsigned row, const char* label, int checked);
void AddDialogButtons(Form* form, unsigned row);
ui_event RunForm(Form* form, const char* title, unsigned rows, unsigned cols,
                 int home);
void ShowMessage(const char* text);
void ShowKeyboardOptions(IniSettings* settings);
void ShowDisplayOptions(IniSettings* settings);
void ShowModuleOptions(SetupChoices* choices);
void ShowVideoOptions(const MachineCapabilities* machine,
                      const InstallationFiles* files, SetupChoices* choices);

#endif  // HHBIOS_SRC_SETUP_FORMS_H_
