extends Camera3D

@export_group("Mouse")
@export var mouse_sensitivity := 0.002

@export_group("Controller")
@export var joystick_sensitivity := 2.5 # radians per second-ish
@export var joystick_dead_zone := 0.15

@export_group("Rotation Boundaries")
@export var y_min := -70
@export var y_max := 50

@onready var player: Player = $".."

signal on_turn(y_delta: float)

var _was_smoking := false
var _smoking_tween: Tween

func _ready() -> void:
	var is_local_player: bool = player.is_authorized()
	
	print(is_local_player)
	
	current = is_local_player
	set_process_input(is_local_player)
	set_process_unhandled_input(is_local_player)
	set_physics_process(is_local_player)
	set_process(is_local_player)
	
	if is_local_player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_was_smoking = player.smoking
	if _was_smoking:
		rotation.x = 0.0

func _process(_delta: float) -> void:
	if not player.is_authorized() or player.smoking == _was_smoking:
		return

	_was_smoking = player.smoking
	if not player.smoking:
		return

	if _smoking_tween and _smoking_tween.is_running():
		_smoking_tween.kill()
	_smoking_tween = create_tween()
	_smoking_tween.tween_property(self, "rotation:x", 0.0, 0.35)

# mouse look
func _input(event: InputEvent) -> void:
	if not player.is_authorized():
		return
	if not player.smoking and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_apply_look(-event.relative * mouse_sensitivity)

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not player.is_authorized() or player.smoking:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# controller look
func _physics_process(delta: float) -> void:
	if player.smoking:
		return
	var look_delta = Input.get_vector("look_left", "look_right", "look_up", "look_down")

	# dead zone (prevents drift)
	if look_delta.length() < joystick_dead_zone:
		return

	# re-normalize so dead zone doesn't slow the start too much
	look_delta = look_delta.normalized()

	# invert y for intuitive joystick look behaviour
	look_delta.y = -look_delta.y

	_apply_look(look_delta * joystick_sensitivity * delta)

func _apply_look(delta: Vector2):
	rotation.x += delta.y
	rotation.x = clamp(rotation.x, deg_to_rad(y_min), deg_to_rad(y_max))

	on_turn.emit(delta.x)
