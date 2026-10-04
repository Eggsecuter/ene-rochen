extends CharacterBody3D

const CIGARETTE = preload("uid://0hboglhvuudy")

@export var smoking_interval: float = 5.0

var cigarette: Cigarette

func _ready() -> void:
	_spawn_cigarette()
	_smoke_periodically()

func _spawn_cigarette() -> void:
	if is_instance_valid(cigarette):
		return

	cigarette = CIGARETTE.instantiate() as Cigarette
	cigarette.position = Vector3(0.0, 0.35, -0.6)
	cigarette.hide()
	cigarette.emptied.connect(_on_cigarette_emptied.bind(cigarette))
	add_child(cigarette)

func _on_cigarette_emptied(emptied_cigarette: Cigarette) -> void:
	if emptied_cigarette != cigarette:
		return

	cigarette = null
	emptied_cigarette.queue_free()
	_spawn_cigarette()

func _smoke_periodically() -> void:
	while true:
		await get_tree().create_timer(smoking_interval).timeout
		var smoking_cigarette := cigarette
		if not is_instance_valid(smoking_cigarette):
			continue

		smoking_cigarette.show()
		smoking_cigarette.start_smoking()
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(smoking_cigarette):
			smoking_cigarette.stop_smoking()
			smoking_cigarette.hide()
