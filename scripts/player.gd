class_name Player
extends CharacterBody3D

@export var single_player := false
@export var speed := 6.0

func is_authorized() -> bool:
	return single_player or is_multiplayer_authority()

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int(), true)

func _physics_process(delta: float) -> void:
	if not is_authorized():
		return
	
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

func _on_camera_3d_on_turn(y_delta: float) -> void:
	rotation.y += y_delta
