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

signal stepped(height: float)

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var lungs: TextureProgressBar = %Lungs
@onready var cigarette_progress: TextureRect = %CigaretteProgress
@onready var stats_panel: StatsPanel = %StatsPanel
@onready var smoke_control: Control = %Smoke
@onready var photo_control: Control = %Photo
@onready var mouth: Node3D = $Mouth
@onready var smoke: GPUParticles3D = $Mouth/Smoke
@onready var camera: Camera3D = $Camera3D
@onready var phone: Phone = $Camera3D/Phone

@export var single_player := false
@export var speed := 6.0
@export var max_step_height := 0.35
@export var smoking_duration: float = 1.5
@export var smoking_cooldown: float = 2.0
@export var exhale_delay: float = 2.0
@export_range(0.0, 1.0) var photo_quality := 0.8

var cigarette: Cigarette
var _is_smoking := false
var smoking: bool = false:
	set(value):
		var was_smoking := smoking
		smoking = value
		_is_smoking = value
		_update_smoking_visual()
		# runs on every peer since smoking is replicated
		if was_smoking and not value:
			_exhale()
var _is_on_smoking_cooldown := false
var _smoking_timer: Timer
var _cooldown_timer: Timer
var _lungs_fill_at_cooldown := 0.0
var _cigarette_progress_texture: AtlasTexture
var smoked_cigarettes := 0:
	set(value):
		smoked_cigarettes = value
		if is_node_ready():
			stats_panel.cigarette_counter.count = value
# replicated so remote cigarettes burn down in step with the owner's
var cigarette_left: float:
	get:
		return cigarette.amount_left if is_instance_valid(cigarette) else 1.0
	set(value):
		if not is_authorized() and is_instance_valid(cigarette):
			cigarette.amount_left = value
# [time, position, yaw, pitch] of the owner, interpolated on remote peers
var net_state: Array = []:
	set(value):
		net_state = value
		if not is_authorized() and value.size() == 4:
			_snapshots.push(value[0], value[1], value[2], value[3])

var _snapshots := SnapshotBuffer.new()

# every photo this player took, on every peer
var photos: Array[Texture2D] = []
# replicated so other players see the phone being drawn
var taking_photo := false:
	set(value):
		taking_photo = value
		if is_node_ready():
			phone.drawn = value

func _ready() -> void:
	floor_snap_length = max_step_height
	canvas_layer.visible = is_authorized()
	phone.live_preview = is_authorized()
	phone.drawn = taking_photo
	# photos get the same retro post-processing as the player's view
	phone.lens_camera.compositor = camera.compositor
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
	stats_panel.cigarette_counter.count = smoked_cigarettes
	_spawn_cigarette()

func is_authorized() -> bool:
	return single_player or is_multiplayer_authority()

func _process(_delta: float) -> void:
	if not is_authorized():
		return

	if Input.is_action_just_pressed("smoke"):
		_start_smoking()
	if Input.is_action_just_pressed("photo"):
		_take_photo()

	_update_hud()

func _update_hud() -> void:
	# lungs fill with smoke while smoking and clear over the cooldown
	if _is_smoking:
		lungs.value = _get_smoking_lungs_fill()
	elif _is_on_smoking_cooldown:
		# hold the smoke for the exhale delay before the lungs start clearing
		lungs.value = _lungs_fill_at_cooldown * minf(_cooldown_timer.time_left / smoking_cooldown, 1.0)
	else:
		lungs.value = 0.0

	var can_smoke := not _is_smoking and not _is_on_smoking_cooldown and not taking_photo and is_instance_valid(cigarette)
	smoke_control.modulate = Color.WHITE if can_smoke else DISABLED_CONTROL_COLOR
	photo_control.modulate = Color.WHITE if _can_take_photo() else DISABLED_CONTROL_COLOR

	var amount_left := cigarette.amount_left if is_instance_valid(cigarette) else 1.0
	var stage := clampi(int((1.0 - amount_left) * CIGARETTE_STAGES.size()), 0, CIGARETTE_STAGES.size() - 1)
	_cigarette_progress_texture.atlas = CIGARETTE_STAGES[stage]

func _start_smoking() -> void:
	if _is_smoking or _is_on_smoking_cooldown or taking_photo or not is_instance_valid(cigarette):
		return

	smoking = true
	_smoking_timer.start(smoking_duration)

func _can_take_photo() -> bool:
	return not taking_photo and not _is_smoking and not _is_on_smoking_cooldown

# draws the phone, takes a photo of the current view and puts the phone away again
func _take_photo() -> void:
	if not _can_take_photo():
		return

	taking_photo = true
	await get_tree().create_timer(phone.draw_duration).timeout
	var image := await phone.capture()
	if not single_player:
		_receive_photo.rpc(image.save_webp_to_buffer(true, photo_quality))
	_add_photo(image)
	await get_tree().create_timer(phone.hold_duration).timeout
	taking_photo = false

# photos are sent compressed, a raw 640x360 image would be ~700kb
@rpc("authority", "call_remote", "reliable")
func _receive_photo(data: PackedByteArray) -> void:
	var image := Image.new()
	if image.load_webp_from_buffer(data) != OK:
		push_warning("Received an invalid photo from %s" % name)
		return
	_add_photo(image)

func _add_photo(image: Image) -> void:
	image.generate_mipmaps()
	var photo := ImageTexture.create_from_image(image)
	photos.append(photo)
	phone.show_photo(photo)
	stats_panel.add_photo(photo)

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
	_cooldown_timer.start(exhale_delay + smoking_cooldown)

# exhale while the lungs clear, after holding the smoke for the exhale delay
func _exhale() -> void:
	await get_tree().create_timer(exhale_delay).timeout
	smoke.emitting = true
	await get_tree().create_timer(smoking_cooldown).timeout
	smoke.emitting = false

func _spawn_cigarette() -> void:
	if is_instance_valid(cigarette):
		return

	cigarette = CIGARETTE.instantiate() as Cigarette
	cigarette.position = mouth.position
	cigarette.hide()
	cigarette.emptied.connect(_on_cigarette_emptied.bind(cigarette))
	cigarette.burning = is_authorized()
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
	# remote cigarettes follow the replicated amount, the owner decides when one is finished
	if emptied_cigarette != cigarette or not is_authorized():
		return

	if _is_smoking:
		_end_smoking()

	cigarette = null
	emptied_cigarette.queue_free()
	smoked_cigarettes += 1
	_spawn_cigarette()

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int(), true)

func _physics_process(delta: float) -> void:
	if is_authorized():
		_move(delta)
		net_state = [Time.get_ticks_usec() / 1_000_000.0, global_position, rotation.y, camera.rotation.x]
	else:
		_apply_remote_state()

# applied in the physics tick so physics interpolation smooths it between ticks
func _apply_remote_state() -> void:
	var state := _snapshots.sample()
	if not state:
		return
	global_position = state.position
	rotation.y = state.yaw
	camera.rotation.x = state.pitch

func _move(delta: float) -> void:
	if _is_smoking or _is_on_smoking_cooldown:
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
	
	_try_step_up(delta)
	move_and_slide()

# lifts the player onto a step if the horizontal motion is blocked by a ledge low enough to walk onto
func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return

	var horizontal_motion := Vector3(velocity.x, 0, velocity.z) * delta
	if horizontal_motion.is_zero_approx():
		return

	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()

	# only step when blocked by something wall-like at the current height
	params.from = global_transform
	params.motion = horizontal_motion
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return
	if result.get_collision_normal().angle_to(up_direction) <= floor_max_angle:
		return

	# raise by the step height (or less if there is a ceiling)
	var test_transform := global_transform
	params.from = test_transform
	params.motion = up_direction * max_step_height
	PhysicsServer3D.body_test_motion(get_rid(), params, result)
	test_transform.origin += result.get_travel()

	# move forward at the raised height, a wall here means the ledge is too high
	params.from = test_transform
	params.motion = horizontal_motion
	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return
	test_transform.origin += horizontal_motion

	# drop back down onto the step
	params.from = test_transform
	params.motion = -up_direction * max_step_height
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return
	if result.get_collision_normal().angle_to(up_direction) > floor_max_angle:
		return

	var step_height := (test_transform.origin + result.get_travel() - global_position).dot(up_direction)
	if step_height <= 0.0:
		return

	global_position += up_direction * step_height
	velocity.y = 0.0
	stepped.emit(step_height)

func _on_camera_3d_on_turn(y_delta: float) -> void:
	rotation.y += y_delta
