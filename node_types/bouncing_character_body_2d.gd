class_name BouncingCharacterBody2D
extends CharacterBody2D

signal bounce(collision: KinematicCollision2D)

@export var max_bounces: int = 16

func move_and_bounce() -> void:
	var delta := get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
	var motion := velocity * delta
	var collision := move_and_collide(motion)
	var bounce_count := 0
	
	while collision:
		bounce_count += 1
		var normal := collision.get_normal()
		
		if normal:
			velocity = velocity.bounce(normal)
			motion = collision.get_remainder().bounce(normal)
		else:
			motion = collision.get_remainder()
		
		var stop = false
		
		bounce.emit(collision)
		
		if has_method(&"_collision"):
			call(&"_collision", collision.get_collider())
		if collision.get_collider().has_method(&"_collision"):
			collision.get_collider().call(&"_collision", self)
		
		if has_method(&"_on_bounce"):
			stop = call(&"_on_bounce", collision)
		
		if stop:
			break
		
		if bounce_count >= max_bounces:
			break
		
		collision = move_and_collide(motion)
		
