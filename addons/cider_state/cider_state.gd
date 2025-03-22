class_name CiderState
extends Node

const HINT = PROPERTY_HINT_MAX + 34867
const USAGE = PROPERTY_USAGE_SCRIPT_VARIABLE

static var _script_states: Dictionary[StringName, Dictionary] = {}

static func create(parent: Node) -> CiderState:
	var script = parent.get_script() as GDScript
	assert(script)
	
	var script_path: String = script.resource_path
	
	if script_path not in _script_states:
		var script_states: Dictionary = {}
		for prop in script.get_script_property_list():
			if prop.hint != HINT:
				continue
			var state_name: String = prop.hint_string
			script_states[state_name] = {
				process = _opt_func(parent, "_%s_process" % state_name),
				physics_process = _opt_func(parent, "_%s_physics_process" % state_name),
				enter = _opt_func(parent, "_%s_enter" % state_name),
				exit = _opt_func(parent, "_%s_exit" % state_name),
				draw = _opt_func(parent, "_%s_draw" % state_name),
			}
			if script_states[state_name].values().count(Callable()) == 4:
				push_warning("State %s in %s has no state functions!" % [state_name, script_path])
				breakpoint
		_script_states[script_path] = script_states
	
	var cider_state = CiderState.new()
	cider_state.name = "CiderState"
	cider_state.states = _script_states[script_path]
	parent.add_child(cider_state, false, Node.INTERNAL_MODE_FRONT)
	
	return cider_state

static func _opt_func(obj: Object, method: StringName) -> StringName:
	return method if obj.has_method(method) else StringName()

var states: Dictionary

var current_state: StringName:
	set(v):
		if current_state and states[current_state].exit:
			get_parent().call(states[current_state].exit)
		if v and v not in states:
			push_error("Unknown state: ", v)
			breakpoint
			current_state = StringName()
			return
		current_state = v
		if current_state and states[current_state].enter:
			get_parent().call(states[current_state].enter)

func _ready() -> void:
	var parent = get_parent()
	if parent is CanvasItem:
		for state in states.values():
			if state.draw != "":
				parent.draw.connect(_on_parent_draw)
				break

func _process(delta: float) -> void:
	if current_state and states[current_state].process:
		get_parent().call(states[current_state].process, delta)

func _physics_process(delta: float) -> void:
	if current_state and states[current_state].physics_process:
		get_parent().call(states[current_state].physics_process, delta)

func _on_parent_draw() -> void:
	if current_state and states[current_state].draw:
		get_parent().call(states[current_state].draw)

func goto(state_name: StringName) -> void:
	current_state = state_name
