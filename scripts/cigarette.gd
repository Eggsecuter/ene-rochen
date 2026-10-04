class_name Cigarette
extends Node3D

signal emptied

@export_range(0.0, 1.0) var amount_left: float = 1.0:
	set(value):
		amount_left = clampf(value, 0.0, 1.0)
		if amount_left == 0.0 and not _empty_emitted:
			_empty_emitted = true
			emptied.emit()

@export_range(0.0, 1.0) var idle_consumption_per_second: float = 0.005
@export_range(0.0, 1.0) var inhale_consumption_per_second: float = 0.05

@onready var burnable: MeshInstance3D = $Burnable

var _is_smoking: bool = false
var _empty_emitted: bool = false

func _process(delta: float) -> void:
	if amount_left <= 0.0:
		return

	var consumption := idle_consumption_per_second
	if _is_smoking:
		consumption += inhale_consumption_per_second

	amount_left -= consumption * delta
	# update visual burn
	burnable.scale.y = amount_left
	burnable.position.z = -0.1 - (0.2 * amount_left)

func start_smoking() -> void:
	_is_smoking = true

func stop_smoking() -> void:
	_is_smoking = false
