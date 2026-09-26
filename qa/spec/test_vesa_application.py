"""Real TUI editors using the independent VBE display and keyboard contract."""
import pytest

from qa.spec.test_application import application_dir, exercise_editor
from qa.spec.test_dos_display import guest_build

pytestmark = pytest.mark.application


@pytest.mark.parametrize('editor', ['tvedit', 'borland', 'msedit', 'edit2', 'tc201', 'tc30', 'pct9'])
@pytest.mark.parametrize('scenario', ['movement', 'trail-delete', 'trail-backspace'])
def test_vesa_editor_edits(pytestconfig, dosbox_binary, application_dir, editor, scenario):
    exercise_editor(pytestconfig, dosbox_binary, application_dir, editor, True, scenario, display='VESA')
