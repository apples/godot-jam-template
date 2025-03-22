extends Node
## An empty global variable bag with a togglable debug overlay that displays all variables.
##
## Designed to hold simple global variables.
## A bad pattern, but in a game jam, sometimes you just need to get it done.
##
## Displays a debug overlay when the user hits the F1 key.
## All variables are displayed automatically.

## Emitted when any variable changes.
signal changed(prop_name: StringName)

## Example variable.
var player_health: int = 0:
	set(v):
		if player_health == v: return
		player_health = v
		_notify_changed(&"player_health")


## Reset all variables to their default state.
func reset():
	for prop_name in _defaults:
		set(prop_name, _defaults[prop_name])

#region Plumbing
var _defaults: Dictionary[StringName, Variant] = {}

func _notify_changed(prop_name: StringName) -> void:
	changed.emit(prop_name)

func _init() -> void:
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_defaults[prop.name] = get(prop.name)
#endregion

#region Debug overlay
var _overlay
func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed:
		match event.physical_keycode:
			KEY_F1:
				if not _overlay:
					_overlay = load("res://autoload/globals/globals_overlay.tscn").instantiate()
					get_parent().add_child(_overlay)
				else:
					_overlay.visible = not _overlay.visible
#endregion
