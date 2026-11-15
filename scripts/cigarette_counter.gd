class_name CigaretteCounter
extends HFlowContainer

# visible part of the 512x512 zigi textures
const CIGARETTE_REGION := Rect2(228, 128, 56, 248)
const PACK_SIZE := 5

@export var stroke_height := 64.0
@export var stroke_spacing := 14.0
@export var cross_angle := 55.0

var count := 0:
	set(value):
		count = value
		_rebuild()

var _stroke_texture: AtlasTexture

func _ready() -> void:
	_stroke_texture = AtlasTexture.new()
	_stroke_texture.atlas = preload("uid://dg8vr427p20n6")
	_stroke_texture.region = CIGARETTE_REGION
	_rebuild()

func _rebuild() -> void:
	if not is_node_ready():
		return

	for child in get_children():
		child.queue_free()

	var remaining := count
	while remaining > 0:
		add_child(_create_pack(mini(remaining, PACK_SIZE)))
		remaining -= PACK_SIZE

func _create_pack(strokes: int) -> Control:
	var stroke_size := Vector2(stroke_height * CIGARETTE_REGION.size.x / CIGARETTE_REGION.size.y, stroke_height)
	var pack := Control.new()
	pack.custom_minimum_size = Vector2(stroke_spacing * (PACK_SIZE - 2) + stroke_size.x, stroke_height)

	# first four strokes stand upright next to each other
	for i in mini(strokes, PACK_SIZE - 1):
		var stroke := _create_stroke(stroke_size)
		stroke.position = Vector2(i * stroke_spacing, 0)
		pack.add_child(stroke)

	# fifth stroke crosses the other four diagonally
	if strokes == PACK_SIZE:
		var cross_size := Vector2(stroke_size.x, stroke_height * 1.25)
		var cross := _create_stroke(cross_size)
		cross.position = (pack.custom_minimum_size - cross_size) / 2
		cross.pivot_offset = cross_size / 2
		cross.rotation = deg_to_rad(cross_angle)
		pack.add_child(cross)

	return pack

func _create_stroke(stroke_size: Vector2) -> TextureRect:
	var stroke := TextureRect.new()
	stroke.texture = _stroke_texture
	stroke.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stroke.stretch_mode = TextureRect.STRETCH_SCALE
	stroke.size = stroke_size
	return stroke
