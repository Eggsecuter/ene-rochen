class_name Player
extends CharacterBody3D

const CIGARETTE = preload("uid://0hboglhvuudy")

@export var single_player := false
@export var speed := 6.0
@export var smoking_cooldown: float = 3.0

var cigarette: Cigarette
var _is_smoking := false
var smoking: bool = false:
	set(value):
		smoking = value
		_is_smoking = value
		_update_smoking_visual()
var _is_on_smoking_cooldown := false
var _smoking_timer: Timer

func _ready() -> void:
	_smoking_timer = Timer.new()
	_smoking_timer.one_shot = true
	_smoking_timer.timeout.connect(_end_smoking)
	add_child(_smoking_timer)
	_spawn_cigarette()

func is_authorized() -> bool:
	return single_player or is_multiplayer_authority()

func _process(_delta: float) -> void:
	if not is_authorized():
		return

	if Input.is_action_just_pressed("smoke"):
		_start_smoking()

func _start_smoking() -> void:
	if _is_smoking or _is_on_smoking_cooldown or not is_instance_valid(cigarette):
		return

	smoking = true
	_smoking_timer.start(2.0)


func _end_smoking() -> void:
	if not _is_smoking:
		return

	_smoking_timer.stop()
	smoking = false

	_is_on_smoking_cooldown = true
	_clear_smoking_cooldown_after_delay()

func _clear_smoking_cooldown_after_delay() -> void:
	await get_tree().create_timer(smoking_cooldown).timeout
	_is_on_smoking_cooldown = false

func _spawn_cigarette() -> void:
	if is_instance_valid(cigarette):
		return

	cigarette = CIGARETTE.instantiate() as Cigarette
	cigarette.position = Vector3(0.0, 0.35150063, -0.7516459)
	cigarette.hide()
	cigarette.emptied.connect(_on_cigarette_emptied.bind(cigarette))
	add_child(cigarette)
	_update_smoking_visual()

func _update_smoking_visual() -> void:
	if not is_instance_valid(cigarette):
		return
	cigarette.visible = _is_smoking
	if _is_smoking:
		cigarette.start_smoking()
	else:
		cigarette.stop_smoking()

func _on_cigarette_emptied(emptied_cigarette: Cigarette) -> void:
	if emptied_cigarette != cigarette:
		return

	if _is_smoking:
		_end_smoking()

	cigarette = null
	emptied_cigarette.queue_free()
	_spawn_cigarette()

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int(), true)

func _physics_process(delta: float) -> void:
	if not is_authorized():
		return
	if _is_smoking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
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
