@tool
extends EditorPlugin

const REGION_NAME = "Cider State"
static var region_regex = RegEx.create_from_string("^\\s*#region\\s(.*)$")
static var endregion_regex = RegEx.create_from_string("^\\s*#endregion(\\s.*)?$")

enum {
	MENU_SETUP,
	MENU_ADD,
	MENU_GOTO,
}

var _plumbing_string: String
var _state_template_string: String

var _menu_button: MenuButton
var _menu_popup: PopupMenu
var _goto_popup: PopupMenu

var _add_dialog: ConfirmationDialog
var _add_dialog_line_edit: LineEdit
var _add_dialog_error_label: Label

var _current_script_info: Dictionary = {
	has_cider_state = false,
	region_start_line = -1,
	region_end_line = -1,
	states = {},
}

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	
	_plumbing_string = FileAccess.get_file_as_string("res://addons/cider_state/plumbing.txt")
	_state_template_string = FileAccess.get_file_as_string("res://addons/cider_state/state_template.txt")
	
	_menu_button = MenuButton.new()
	_menu_button.text = "Cider State"
	
	_menu_popup = _menu_button.get_popup()
	_menu_popup.add_item("Setup", MENU_SETUP)
	_menu_popup.add_item("Add", MENU_ADD)
	_goto_popup = PopupMenu.new()
	_menu_popup.add_submenu_node_item("Goto", _goto_popup, MENU_GOTO)
	
	var script_editor = get_editor_interface().get_script_editor()
	var script_menu = script_editor.get_child(0).get_child(0)
	var index = script_menu.find_child("*Control*", false, false).get_index()
	script_menu.add_child(_menu_button)
	script_menu.move_child(_menu_button, index)
	
	_menu_button.about_to_popup.connect(_on_menu_button_about_to_popup)
	_menu_popup.id_pressed.connect(_on_menu_popup_id_pressed)
	_goto_popup.index_pressed.connect(_on_goto_popup_index_pressed)
	
	_add_dialog = ConfirmationDialog.new()
	_add_dialog.title = "Enter New State Name..."
	_add_dialog_line_edit = LineEdit.new()
	_add_dialog_line_edit.placeholder_text = "State Name"
	_add_dialog_error_label = Label.new()
	_add_dialog_error_label.add_theme_color_override("font_color", Color.RED)
	var vbox = VBoxContainer.new()
	vbox.add_child(_add_dialog_line_edit)
	vbox.add_child(_add_dialog_error_label)
	_add_dialog.add_child(vbox)
	add_child(_add_dialog)
	
	_add_dialog.confirmed.connect(_on_add_dialog_confirmed)
	_add_dialog_line_edit.text_changed.connect(_on_add_dialog_line_edit_text_changed)
	_add_dialog_line_edit.text_submitted.connect(_on_add_dialog_line_edit_text_submitted)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		return
	
	_add_dialog.queue_free()
	_add_dialog = null
	_add_dialog_line_edit = null
	_add_dialog_error_label = null
	
	_menu_button.queue_free()
	_menu_button = null
	
	_state_template_string = ""
	_plumbing_string = ""

func _update_script_info() -> void:
	_current_script_info = {
		has_cider_state = false,
		region_start_line = -1,
		region_end_line = -1,
		states = {},
	}
	
	var script_editor = get_editor_interface().get_script_editor()
	var script = script_editor.get_current_script()
	
	if script is GDScript:
		var code_edit = script_editor.get_current_editor().get_base_editor() as CodeEdit
		
		var i = 0
		
		while i < code_edit.get_line_count():
			var line = code_edit.get_line(i)
			var m = region_regex.search(line)
			if m and m.get_string(1).strip_edges() == REGION_NAME:
				_current_script_info.has_cider_state = true
				_current_script_info.region_start_line = i
				i += 1
				break
			i += 1
		
		if not _current_script_info.has_cider_state:
			return
		
		while i < code_edit.get_line_count():
			var line = code_edit.get_line(i)
			var m: RegExMatch = endregion_regex.search(line)
			if m:
				_current_script_info.region_end_line = i
				break
			m = region_regex.search(line)
			if m:
				var state_name = m.get_string(1).strip_edges()
				if state_name == "":
					push_error("Script %s has invalid state region at line %s." %
						[script.resource_path, i + 1])
					break
				_current_script_info.states[state_name] = {
					state_name = state_name,
					start_line = i,
					end_line = -1,
				}
				while i < code_edit.get_line_count():
					line = code_edit.get_line(i)
					m = endregion_regex.search(line)
					if m:
						_current_script_info.states[state_name].end_line = i
						break
					i += 1
				if _current_script_info.states[state_name].end_line == -1:
					push_error("Script %s has unterminated state region (%s)." %
						[script.resource_path, state_name])
			i += 1
		
		if _current_script_info.region_end_line == -1:
			push_error("Script %s has unterminated Cider State region." % script.resource_path)

func _on_menu_button_about_to_popup() -> void:
	_update_script_info()
	
	var has_cider = _current_script_info.has_cider_state
	_menu_popup.set_item_disabled(_menu_popup.get_item_index(MENU_SETUP), has_cider)
	_menu_popup.set_item_disabled(_menu_popup.get_item_index(MENU_ADD), not has_cider)
	_menu_popup.set_item_disabled(_menu_popup.get_item_index(MENU_GOTO), not has_cider)
	
	_goto_popup.clear()
	
	if not has_cider:
		return
	
	for state_name in _current_script_info.states:
		var state = _current_script_info.states[state_name]
		_goto_popup.add_item("%s (%s)" % [state_name, state.start_line + 1])
		_goto_popup.set_item_metadata(_goto_popup.item_count - 1, state)


func _on_menu_popup_id_pressed(id: int) -> void:
	match id:
		MENU_SETUP: _do_setup()
		MENU_ADD: _do_add()

func _do_setup() -> void:
	var script_editor = get_editor_interface().get_script_editor()
	var code_edit: CodeEdit = script_editor.get_current_editor().get_base_editor() as CodeEdit
	assert(code_edit)
	
	var last_line = code_edit.get_line_count() - 1
	code_edit.insert_text(_plumbing_string, last_line, code_edit.get_line(last_line).length())
	code_edit.remove_secondary_carets()
	code_edit.set_caret_line(last_line + 1)
	code_edit.set_caret_column(0)

func _do_add() -> void:
	_add_dialog_line_edit.text = ""
	_add_dialog_error_label.text = ""
	_add_dialog.get_ok_button().disabled = true
	_add_dialog.popup_centered()
	_add_dialog_line_edit.grab_focus()

func _on_add_dialog_confirmed() -> void:
	var state_name = _add_dialog_line_edit.text.strip_edges()
	var func_name = state_name.to_snake_case()
	
	var script_editor = get_editor_interface().get_script_editor()
	var code_edit = script_editor.get_current_editor().get_base_editor() as CodeEdit
	assert(code_edit)
	
	var impl_string = _state_template_string.format({
		state_name = state_name,
		func_name = func_name,
	})
	
	code_edit.insert_text(impl_string, _current_script_info.region_end_line, 0)
	code_edit.remove_secondary_carets()
	code_edit.set_caret_line(_current_script_info.region_end_line + 1)
	code_edit.set_caret_column(0)

func _on_add_dialog_line_edit_text_changed(new_text: String) -> void:
	var state_name = _add_dialog_line_edit.text.strip_edges()
	var func_name = state_name.to_snake_case()
	_add_dialog.get_ok_button().disabled = func_name == ""
	_add_dialog_error_label.text = ""
	if state_name in _current_script_info.states:
		_add_dialog.get_ok_button().disabled = true
		_add_dialog_error_label.text = "State already exists"

func _on_add_dialog_line_edit_text_submitted(new_text: String) -> void:
	var func_name = new_text.strip_edges().to_snake_case()
	if func_name != "":
		_add_dialog.hide()
		_on_add_dialog_confirmed()

func _on_goto_popup_index_pressed(index: int) -> void:
	var meta = _goto_popup.get_item_metadata(index)
	var script_editor = get_editor_interface().get_script_editor()
	var code_edit = script_editor.get_current_editor().get_base_editor() as CodeEdit
	code_edit.remove_secondary_carets()
	code_edit.set_caret_line(meta.start_line, false, true)
	code_edit.set_caret_column(0, true)
