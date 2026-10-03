extends Camera3D

@export_group("Mouse")
@export var mouse_sensitivity := 0.002

@export_group("Controller")
@export var joystick_sensitivity := 2.5 # radians per second-ish
@export var joystick_dead_zone := 0.15

@export_group("Rotation Boundaries")
@export var y_min := -90
@export var y_max := 90

signal on_turn(y_delta: float)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# mouse look
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_apply_look(-event.relative * mouse_sensitivity)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

# controller look
func _physics_process(delta: float) -> void:
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
