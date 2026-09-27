"""Real TUI editors using the independent VBE display and keyboard contract."""
import pytest

from qa.spec.test_application import application_dir, exercise_editor
from qa.spec.test_dos_display import guest_build
from qa.spec.test_text_modes import textmode_build
import shutil

pytestmark = pytest.mark.application


@pytest.mark.parametrize('editor', ['tvedit', 'borland', 'msedit', 'edit2', 'tc201', 'tc30', 'pct9'])
@pytest.mark.parametrize('scenario', ['movement', 'trail-delete', 'trail-backspace'])
def test_vesa_editor_edits(pytestconfig, dosbox_binary, application_dir, editor, scenario):
    exercise_editor(pytestconfig, dosbox_binary, application_dir, editor, True, scenario, display='VESA')


@pytest.mark.parametrize('editor',['tvedit','edit2','tc201','tc30'])
@pytest.mark.parametrize('scenario',['movement','trail-delete','trail-backspace'])
def test_high_resolution_editor_edits(pytestconfig,dosbox_binary,application_dir,editor,scenario):
    exercise_editor(pytestconfig,dosbox_binary,application_dir,editor,True,scenario,
                    display='VESA /M:104',display_size=(1024,768))


@pytest.mark.parametrize('editor',['tvedit','edit2'])
@pytest.mark.parametrize('scenario',['trail-delete','trail-backspace'])
def test_50_row_editor_deletes_below_row_25(pytestconfig,dosbox_binary,application_dir,textmode_build,editor,scenario):
    shutil.copy2(textmode_build,application_dir)
    exercise_editor(pytestconfig,dosbox_binary,application_dir,editor,True,scenario,
                    display='VESA /M:106',display_size=(1280,1024),
                    text_setup=['TEXTMODE 50 select'],leading_rows=28)
