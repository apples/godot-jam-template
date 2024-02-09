extends Node

const TEST_CAMERA_2D = "res://autoload/test_camera/test_camera_2d.tscn"
const TEST_CAMERA_3D = "res://autoload/test_camera/test_camera_3d.tscn"

func _ready():
	if OS.has_feature("standalone"):
		return
	
	await get_tree().process_frame
	
	if get_viewport().get_camera_3d() != null:
		return
	
	if get_viewport().get_camera_2d() != null:
		return
	
	var visual_instances := get_tree().root.find_children("*", "VisualInstance3D", true, false)
	
	if not visual_instances.is_empty():
		get_tree().root.add_child(load(TEST_CAMERA_3D).instantiate())
		
		return
	
	get_tree().root.add_child(load(TEST_CAMERA_2D).instantiate())
	
