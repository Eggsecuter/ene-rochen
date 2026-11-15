class_name Phone
extends Node3D

@export var draw_duration := 0.2
@export var hold_duration := 0.6
# pose relative to the held pose while the phone is put away below the view
@export var hidden_offset := Vector3(0.0, -0.25, 0.05)
@export var hidden_rotation := Vector3(-1.0, 0.0, 0.0)

@onready var viewport: SubViewport = $Viewport
@onready var lens_camera: Camera3D = $Viewport/Camera3D
@onready var lens: Marker3D = $Lens
@onready var screen: MeshInstance3D = $Screen

# only the local player renders the phone camera, remote phones show a dark screen
var live_preview := false:
	set(value):
		live_preview = value
		if is_node_ready():
			_update_screen()

var drawn := false:
	set(value):
		drawn = value
		if is_node_ready():
			_animate()

var _held_position: Vector3
var _held_rotation: Vector3
var _screen_material: StandardMaterial3D
var _tween: Tween
# shown on the screen until the phone is put away
var _photo: Texture2D

func _ready() -> void:
	_held_position = position
	_held_rotation = rotation
	# every phone shows its own camera
	_screen_material = screen.material_override.duplicate()
	screen.material_override = _screen_material

	visible = drawn
	position = _held_position if drawn else _held_position + hidden_offset
	rotation = _held_rotation if drawn else _held_rotation + hidden_rotation
	reset_physics_interpolation()
	_update_screen()

func _process(_delta: float) -> void:
	if viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return

	# the camera lives in the sub viewport, so it has to follow the lens manually
	lens_camera.global_transform = lens.get_global_transform_interpolated()

# returns the current view of the phone camera
func capture() -> Image:
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

# freezes a photo on the screen until the phone is put away
func show_photo(photo: Texture2D) -> void:
	_photo = photo
	_update_screen()

func _animate() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	if drawn:
		show()
		_update_screen()

	var target_position := _held_position if drawn else _held_position + hidden_offset
	var target_rotation := _held_rotation if drawn else _held_rotation + hidden_rotation
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if drawn else Tween.EASE_IN)
	_tween.tween_property(self, "position", target_position, draw_duration)
	_tween.tween_property(self, "rotation", target_rotation, draw_duration)

	if not drawn:
		_tween.chain().tween_callback(func():
			_photo = null
			hide()
			_update_screen())

func _update_screen() -> void:
	# a frozen photo doesn't need the camera anymore
	var rendering := live_preview and visible and _photo == null
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if rendering else SubViewport.UPDATE_DISABLED

	var texture: Texture2D = _photo
	if not texture and live_preview:
		texture = viewport.get_texture()
	_screen_material.albedo_texture = texture
	_screen_material.albedo_color = Color.WHITE if texture else Color.BLACK
