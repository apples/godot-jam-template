@tool
class_name MotionInterpolator3D
extends Node3D

enum MotionMode {
	PHYSICS_INTERPOLATION,
	SMOOTH_DAMP,
}

enum ProcessFunc {
	FRAME,
	PHYSICS,
}

@export var enabled: bool = true

@export var motion_mode: MotionMode = MotionMode.PHYSICS_INTERPOLATION:
	set(v):
		motion_mode = v
		notify_property_list_changed()
		update_configuration_warnings()

@export var keep_initial_offset: bool = true

@export_group("Smoothing", "smoothing")
@export_range(0.0, 1.0, 0.01) var smoothing_position: float = 0.5
@export_range(0.0, 1.0, 0.01) var smoothing_rotation: float = 0.5
@export_range(0.1, 100.0, 0.1) var smoothing_power_scale: float = 10.0

@export_group("")
@export var process_func: ProcessFunc = ProcessFunc.FRAME:
	set(v): process_func = v; update_configuration_warnings()


var _offset_transform: Transform3D

var _physics_interpolation_previous_xform: Transform3D
var _physics_interpolation_current_xform: Transform3D

var _smooth_damp_child_global_xform: Transform3D

func _ready():
	if process_priority == 0:
		process_priority = 1
	if process_physics_priority == 0:
		process_physics_priority = process_priority
	
	if Engine.is_editor_hint():
		return
	
	if get_child_count() != 1:
		push_error("MotionInterpolator3D: must have exactly 1 child.")
	
	if get_child_count() == 0:
		return
	
	var child := get_child(0) as Node3D
	
	if not child:
		push_error("MotionInterpolator3D: child must be a Node3D.")
		return
	
	if keep_initial_offset:
		_offset_transform = global_transform.inverse() * child.global_transform
	
	_physics_interpolation_current_xform = global_transform
	_physics_interpolation_previous_xform = _physics_interpolation_current_xform
	
	_smooth_damp_child_global_xform = child.global_transform

func _process(delta:float):
	if Engine.is_editor_hint():
		return
	
	if process_func == ProcessFunc.FRAME:
		_process_func(delta)

func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return
	
	if process_func == ProcessFunc.PHYSICS:
		_process_func(delta)
	
	if motion_mode == MotionMode.PHYSICS_INTERPOLATION:
		_update_physics_interpolation_transforms.call_deferred()

func _update_physics_interpolation_transforms() -> void:
	_physics_interpolation_previous_xform = _physics_interpolation_current_xform
	_physics_interpolation_current_xform = global_transform * _offset_transform

func _process_func(delta: float):
	if not enabled:
		return
	
	if get_child_count() != 1:
		return
	
	var child: Node3D = get_child(0) as Node3D
	
	if not child:
		return
	
	match motion_mode:
		MotionMode.SMOOTH_DAMP:
			var target_xform := global_transform * _offset_transform
			var position_t := 1.0 - pow(smoothing_position, delta * smoothing_power_scale)
			var rotation_t := 1.0 - pow(smoothing_rotation, delta * smoothing_power_scale)
			
			var result_origin := _smooth_damp_child_global_xform.origin.lerp(target_xform.origin, position_t)
			var result_basis := _smooth_damp_child_global_xform.basis.slerp(target_xform.basis, rotation_t)
			
			_smooth_damp_child_global_xform = Transform3D(result_basis, result_origin)
			child.global_transform = _smooth_damp_child_global_xform
		MotionMode.PHYSICS_INTERPOLATION:
			child.global_transform = _physics_interpolation_previous_xform.interpolate_with(_physics_interpolation_current_xform, Engine.get_physics_interpolation_fraction())

func _validate_property(property: Dictionary) -> void:
	if (property.name as String).begins_with("smoothing") and motion_mode != MotionMode.SMOOTH_DAMP:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func _get_configuration_warnings():
	var result := PackedStringArray()
	
	if get_child_count() != 1:
		result.append("Must have exactly 1 child.")
	
	if get_child_count() != 0 and not get_child(0) is Node3D:
		result.append("Child must be a Node3D.")
	
	if motion_mode == MotionMode.PHYSICS_INTERPOLATION and process_func == ProcessFunc.PHYSICS:
		result.append("Using PHYSICS_INTERPOLATION in the PHYSICS process_func won't have any effect. Use FRAME process_func instead.")
	
	return result

func teleport() -> void:
	_physics_interpolation_current_xform = global_transform * _offset_transform
	_physics_interpolation_previous_xform = _physics_interpolation_current_xform
	_smooth_damp_child_global_xform = _physics_interpolation_current_xform
	
	if get_child_count() != 1:
		return
	
	var child: Node3D = get_child(0) as Node3D
	
	if not child:
		return
	
	child.global_transform = _physics_interpolation_current_xform
