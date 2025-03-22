extends Panel

const OPTIONS_TAB = preload("res://scenes/options/options_tab.tscn")

static var RE_NON_NUMERIC = RegEx.create_from_string("[^0-9.-]")

var _save_queued: bool = false

@onready var tab_container: TabContainer = %TabContainer
@onready var bong_001: AudioStreamPlayer = $Bong001

func _ready() -> void:
	
	var tab: Control = null
	var tab_grid: GridContainer = null
	
	for setting in Settings.get_settings():
		if tab == null or tab.name != setting.section:
			tab = OPTIONS_TAB.instantiate()
			tab.name = setting.section
			tab_grid = tab.get_node("%Grid")
			tab_container.add_child(tab)
		
		var label = Label.new()
		label.text = String(setting.key).capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var control
		var control_size_flags_horizontal: int = Control.SIZE_EXPAND_FILL
		
		match setting.prop.type:
			TYPE_INT:
				match setting.prop.hint:
					PROPERTY_HINT_ENUM:
						control = OptionButton.new()
						var id = 0
						for hint in setting.prop.hint_string.split(","):
							var colon = hint.find(":")
							if colon != -1:
								id = int(hint.substr(colon + 1))
								hint = hint.substr(0, colon)
							control.add_item(hint, id)
							id += 1
						control.select(Settings.get(setting.prop.name))
						control.item_selected.connect(func (idx):
							Settings.set(setting.prop.name, control.get_selected_id())
							_setting_changed(setting.prop.name)
							_queue_save())
					PROPERTY_HINT_RANGE:
						var hints = setting.prop.hint_string.split(",")
						control = SpinBox.new()
						control.min_value = int(hints[0])
						control.max_value = int(hints[1])
						if hints.size() > 2:
							control.step = int(hints[2])
						for i in range(3, hints.size()):
							match hints[i]:
								"or_less": control.allow_lesser = true
								"or_greater": control.allow_greater = true
						control.value = Settings.get(setting.prop.name)
						control.value_changed.connect(func (value):
							Settings.set(setting.prop.name, int(value))
							_setting_changed(setting.prop.name)
							_queue_save())
					_:
						control = SpinBox.new()
						control.value = Settings.get(setting.prop.name)
						control.value_changed.connect(func (value):
							Settings.set(setting.prop.name, value)
							_setting_changed(setting.prop.name)
							_queue_save())
			TYPE_FLOAT:
				match setting.prop.hint:
					PROPERTY_HINT_RANGE:
						var hints = setting.prop.hint_string.split(",")
						control = HSlider.new()
						control.min_value = float(hints[0])
						control.max_value = float(hints[1])
						if hints.size() > 2:
							control.step = float(hints[2])
						for i in range(3, hints.size()):
							match hints[i]:
								"or_less": control.allow_lesser = true
								"or_greater": control.allow_greater = true
						control.value = Settings.get(setting.prop.name)
						control.value_changed.connect(func (value):
							Settings.set(setting.prop.name, value)
							_setting_changed(setting.prop.name)
							_queue_save())
					_:
						control = LineEdit.new()
						control.text = str(Settings.get(setting.prop.name))
						control.text_submitted.connect(func (text: String):
							control.text = RE_NON_NUMERIC.sub(text, "")
							Settings.set(setting.prop.name, control.text)
							_setting_changed(setting.prop.name)
							_queue_save())
			TYPE_STRING:
				match setting.prop.hint:
					PROPERTY_HINT_ENUM:
						control = OptionButton.new()
						var id = 0
						var idmap = {}
						for hint in setting.prop.hint_string.split(","):
							idmap[id] = hint
							control.add_item(hint, id)
							id += 1
						control.select(idmap.find_key(Settings.get(setting.prop.name)))
						control.item_selected.connect(func (idx):
							Settings.set(setting.prop.name, idmap[control.get_selected_id()])
							_setting_changed(setting.prop.name)
							_queue_save())
					_:
						control = LineEdit.new()
						control.text = Settings.get(setting.prop.name)
						control.text_submitted.connect(func (text: String):
							Settings.set(setting.prop.name, text)
							_setting_changed(setting.prop.name)
							_queue_save())
			TYPE_BOOL:
				control = CheckButton.new()
				control.button_pressed = Settings.get(setting.prop.name)
				control.toggled.connect(func (toggled_on: bool):
					Settings.set(setting.prop.name, toggled_on)
					_setting_changed(setting.prop.name)
					_queue_save())
				control_size_flags_horizontal = Control.SIZE_EXPAND
		
		tab_grid.add_child(label)
		
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		control.size_flags_horizontal = control_size_flags_horizontal
		tab_grid.add_child(control)

func _exit_tree() -> void:
	if _save_queued:
		Settings.save()

func _queue_save() -> void:
	if _save_queued: return
	_save_queued = true
	await get_tree().create_timer(0.1).timeout
	_save_queued = false
	Settings.save()

func _setting_changed(setting_name: StringName) -> void:
	match setting_name:
		&"audio_master_volume":
			bong_001.bus = "Master"
			bong_001.play()
		&"audio_music_volume":
			bong_001.bus = "Music"
			bong_001.play()
		&"audio_sfx_volume":
			bong_001.bus = "SFX"
			bong_001.play()
