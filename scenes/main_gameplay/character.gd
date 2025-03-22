extends BouncingCharacterBody2D

const SPEED = 300.0

func _ready() -> void:
	velocity = Vector2.ONE * SPEED
	goto("normal")

func _physics_process(delta: float) -> void:
	move_and_bounce()

# Called when move_and_bounce() collides with something.
# Return true to stop further motion processing.
func _on_bounce(collision: KinematicCollision2D) -> bool:
	return false

# Called when colliding with something for any reason.
func _collision(other: PhysicsBody2D) -> void:
	match _cider_state.current_state:
		&"normal":
			if randi_range(0, 3) == 0:
				goto("crazy")
		&"crazy":
			goto("normal")
	Globals.player_health -= 1


#region Cider State
@onready var _cider_state = CiderState.create(self)
func goto(state_name: StringName) -> void: _cider_state.goto(state_name)


#region Normal
@export_custom(CiderState.HINT, "normal", CiderState.USAGE) var statedef_normal

func _normal_process(delta: float) -> void:
	queue_redraw()

func _normal_draw() -> void:
	pass

#endregion Normal


#region Crazy
@export_custom(CiderState.HINT, "crazy", CiderState.USAGE) var statedef_crazy

func _crazy_process(delta: float) -> void:
	queue_redraw()

func _crazy_draw() -> void:
	var points = PackedVector2Array()
	for i in 50:
		points.append(Vector2(randf_range(-32, 32), randf_range(-32, 32)))
	draw_polyline(points, Color.RED, 2.0, false)

#endregion Crazy

#endregion Cider State
