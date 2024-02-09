extends Node

signal load_progress(value: float)

var minimum_load_time: float = 1.0

var default_transition_scene: PackedScene = preload("res://autoload/scene_girl/default_scene_transition.tscn")
var default_loading_screen_scene: PackedScene = preload("res://autoload/scene_girl/default_loading_screen.tscn")

var _default_transition: AnimationPlayer = null
var _current_transition: AnimationPlayer = null
var _pending_change_scene_file: String = ""
var _loading_screen: Node = null
var _time_elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _process(delta: float) -> void:
	if _pending_change_scene_file == "":
		push_error("Scene load seemingly aborted early.")
		set_process(false)
		return
	
	var progress = []
	var status := ResourceLoader.load_threaded_get_status(_pending_change_scene_file, progress)
	
	# Fake load time
	_time_elapsed += delta
	if _time_elapsed < minimum_load_time:
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				progress[0] = min(progress[0], _time_elapsed / minimum_load_time)
			ResourceLoader.THREAD_LOAD_LOADED:
				progress[0] = _time_elapsed / minimum_load_time
				status = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	
	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Scene resource invalid.")
			_finish_change_scene(null)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			load_progress.emit(progress[0])
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Scene loading failed.")
			_finish_change_scene(null)
		ResourceLoader.THREAD_LOAD_LOADED:
			var next_scene = ResourceLoader.load_threaded_get(_pending_change_scene_file)
			_finish_change_scene(next_scene.instantiate())

func change_scene(scene_file: String) -> void:
	if _pending_change_scene_file:
		push_error("Cannot change scene while another is pending.")
		return
	
	_pending_change_scene_file = scene_file
	
	_current_transition = get_tree().current_scene.get_node_or_null("SceneTransition")
	
	if not _current_transition:
		_default_transition = default_transition_scene.instantiate()
		get_tree().root.add_child(_default_transition)
		_current_transition = _default_transition
	
	_current_transition.play("out")
	_current_transition.animation_finished.connect(_on_out_animation_finished)
	_current_transition.process_mode = Node.PROCESS_MODE_ALWAYS
	
	ResourceLoader.load_threaded_request(_pending_change_scene_file)
	
	get_tree().paused = true

func _on_out_animation_finished(anim_name: StringName) -> void:
	assert(anim_name == &"out")
	if anim_name != &"out":
		return
	
	if _current_transition:
		_current_transition.animation_finished.disconnect(_on_out_animation_finished)
	
	_current_transition = null
	_time_elapsed = 0.0
	set_process(true)
	
	if default_loading_screen_scene:
		_loading_screen = default_loading_screen_scene.instantiate()
		get_tree().root.add_child(_loading_screen)

func _finish_change_scene(next_scene: Node) -> void:
	get_tree().unload_current_scene()
	
	_pending_change_scene_file = ""
	set_process(false)
	
	if _loading_screen:
		_loading_screen.queue_free()
		_loading_screen = null
	
	_add_current_scene.call_deferred(next_scene)

func _add_current_scene(next_scene: Node) -> void:
	if not next_scene:
		get_tree().current_scene = null
		return
	
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	
	_current_transition = get_tree().current_scene.get_node_or_null("SceneTransition")
	
	if not _current_transition:
		if not _default_transition:
			_default_transition = default_transition_scene.instantiate()
			get_tree().root.add_child(_default_transition)
		_current_transition = _default_transition
	else:
		if _default_transition:
			_default_transition.queue_free()
			_default_transition = null
	
	_current_transition.play("in")
	_current_transition.animation_finished.connect(_on_in_animation_finished)
	_current_transition.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_in_animation_finished(anim_name: StringName) -> void:
	assert(anim_name == &"in")
	if anim_name != &"in":
		return
	
	if _default_transition:
		_default_transition.queue_free()
		_default_transition = null
	
	if _current_transition:
		_current_transition.animation_finished.disconnect(_on_in_animation_finished)
	
	_current_transition = null
	get_tree().paused = false
