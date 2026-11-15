class_name Player
extends CharacterBody3D

const CIGARETTE = preload("uid://0hboglhvuudy")
const CIGARETTE_STAGES: Array[Texture2D] = [
	preload("uid://dg8vr427p20n6"),
	preload("uid://6j2s7pbxeah6"),
	preload("uid://14p71p6tst8m"),
	preload("uid://cfmwxlyvqren6"),
	preload("uid://tjdoumwpmfxk"),
]
const DISABLED_CONTROL_COLOR := Color(0.4, 0.4, 0.4, 0.6)

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var lungs: TextureProgressBar = %Lungs
@onready var cigarette_progress: TextureRect = %CigaretteProgress
@onready var stats_panel: StatsPanel = %StatsPanel
@onready var smoke_control: Control = %Smoke

@export var single_player := false
@export var speed := 6.0
@export var smoking_duration: float = 2.0
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
var _cooldown_timer: Timer
var _lungs_fill_at_cooldown := 0.0
var _cigarette_progress_texture: AtlasTexture
var smoked_cigarettes := 0

func _ready() -> void:
	canvas_layer.visible = is_authorized()
	stats_panel.set_process_input(is_authorized())
	_smoking_timer = Timer.new()
	_smoking_timer.one_shot = true
	_smoking_timer.timeout.connect(_end_smoking)
	add_child(_smoking_timer)
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(func(): _is_on_smoking_cooldown = false)
	add_child(_cooldown_timer)
	_cigarette_progress_texture = AtlasTexture.new()
	_cigarette_progress_texture.region = CigaretteCounter.CIGARETTE_REGION
	cigarette_progress.texture = _cigarette_progress_texture
	_spawn_cigarette()

func is_authorized() -> bool:
	return single_player or is_multiplayer_authority()

func _process(_delta: float) -> void:
	if not is_authorized():
		return

	if Input.is_action_just_pressed("smoke"):
		_start_smoking()

	_update_hud()

func _update_hud() -> void:
	# lungs fill with smoke while smoking and clear over the cooldown
	if _is_smoking:
		lungs.value = _get_smoking_lungs_fill()
	elif _is_on_smoking_cooldown:
		lungs.value = _lungs_fill_at_cooldown * _cooldown_timer.time_left / smoking_cooldown
	else:
		lungs.value = 0.0

	var can_smoke := not _is_smoking and not _is_on_smoking_cooldown and is_instance_valid(cigarette)
	smoke_control.modulate = Color.WHITE if can_smoke else DISABLED_CONTROL_COLOR

	var amount_left := cigarette.amount_left if is_instance_valid(cigarette) else 1.0
	var stage := clampi(int((1.0 - amount_left) * CIGARETTE_STAGES.size()), 0, CIGARETTE_STAGES.size() - 1)
	_cigarette_progress_texture.atlas = CIGARETTE_STAGES[stage]

func _start_smoking() -> void:
	if _is_smoking or _is_on_smoking_cooldown or not is_instance_valid(cigarette):
		return

	smoking = true
	_smoking_timer.start(smoking_duration)

func _get_smoking_lungs_fill() -> float:
	return 1.0 - _smoking_timer.time_left / smoking_duration


func _end_smoking() -> void:
	if not _is_smoking:
		return

	# smoking can end early when the cigarette burns out
	_lungs_fill_at_cooldown = _get_smoking_lungs_fill() if not _smoking_timer.is_stopped() else 1.0
	_smoking_timer.stop()
	smoking = false

	_is_on_smoking_cooldown = true
	_cooldown_timer.start(smoking_cooldown)

func _spawn_cigarette() -> void:
	if is_instance_valid(cigarette):
		return

	cigarette = CIGARETTE.instantiate() as Cigarette
	cigarette.position = Vector3(0.0, 1.5, -0.5)
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
	smoked_cigarettes += 1
	stats_panel.cigarette_counter.count = smoked_cigarettes
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
