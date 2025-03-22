extends Node

@onready var percent_label: Label = %PercentLabel
@onready var bar: Control = %Bar

var _progress: float = 0.0

func _ready() -> void:
	SceneGirl.load_progress.connect(_on_scene_girl_load_progress)
	bar.draw.connect(_on_bar_draw)


func _on_scene_girl_load_progress(value: float) -> void:
	_progress = value
	percent_label.text = "%s%%" % roundi(value * 100.0)
	bar.queue_redraw()

func _on_bar_draw() -> void:
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * _progress, bar.size.y)), Color.WHITE, true)
