extends Node

const CONFIG_FILE = "user://settings.cfg"

@export_group("Audio", "audio_")

@export_range(0.0, 1.0, 0.1) var audio_master_volume: float = 0.5:
	set(v):
		v = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), v)
		audio_master_volume = v

@export_range(0.0, 1.0, 0.1) var audio_music_volume: float = 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), v)
		audio_music_volume = v

@export_range(0.0, 1.0, 0.1) var audio_sfx_volume: float = 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), v)
		audio_sfx_volume = v

@export_group("Video", "video_")

@export var video_fullscreen: bool = false:
	set(v):
		video_fullscreen = v
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if v else Window.MODE_WINDOWED


#region Plumbing

var _settings: Array[Dictionary]

func _init() -> void:
	var current_group: String = ""
	var current_group_prefix: String = ""
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			current_group = prop.name
			current_group_prefix = prop.hint_string
			continue
		if (prop.usage & PROPERTY_USAGE_STORAGE) and (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			var i = String(prop.name).find("_")
			var key: String = prop.name.trim_prefix(current_group_prefix)
			_settings.append({
				section = current_group,
				key = key,
				prop = prop,
				default = get(prop.name),
			})

func _ready() -> void:
	var conf: ConfigFile = null
	
	if FileAccess.file_exists(CONFIG_FILE):
		conf = ConfigFile.new()
		var err = conf.load(CONFIG_FILE)
		if err != OK:
			printerr("Failed to load %s: %s", CONFIG_FILE, error_string(err))
	
	if conf == null:
		return
	
	for setting in get_settings():
		if conf.has_section_key(setting.section, setting.key):
			set(setting.prop.name, cast(conf.get_value(setting.section, setting.key), setting.prop.type))

func get_settings() -> Array[Dictionary]:
	return _settings

func cast(value: Variant, type: Variant.Type) -> Variant:
	match type:
		TYPE_INT: return int(value)
		TYPE_FLOAT: return float(value)
		TYPE_STRING: return String(value)
		TYPE_BOOL: return bool(value)
		_: push_error("Unsupported"); return null

func save() -> void:
	var conf = ConfigFile.new()
	
	for setting in get_settings():
		conf.set_value(setting.section, setting.key, get(setting.prop.name))
	
	var err = conf.save(CONFIG_FILE)
	if err != OK:
		printerr("Failed to save %s: %s", CONFIG_FILE, error_string(err))

#endregion Plumbing
