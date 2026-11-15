class_name StatsPanel
extends Control

@export var blur_strength := 3.0
@export var slide_duration := 0.3

@onready var backdrop: ColorRect = %Backdrop
@onready var panel: PanelContainer = %Panel
@onready var cigarette_counter: CigaretteCounter = %CigaretteCounter

var is_open := false
var _shown_x: float
var _tween: Tween

func _ready() -> void:
	_shown_x = panel.offset_left
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("stats"):
		toggle()
	elif is_open and event.is_action_pressed("close"):
		close()
	else:
		return

	# keep the camera from also handling close (it releases the mouse)
	get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	if not visible:
		panel.position.x = -panel.size.x
		show()
	_animate(_shown_x, blur_strength, Tween.EASE_OUT)

func close() -> void:
	is_open = false
	_animate(-panel.size.x, 0.0, Tween.EASE_IN)
	_tween.chain().tween_callback(hide)

func _animate(panel_x: float, blur: float, ease_type: Tween.EaseType) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	_tween.tween_property(panel, "position:x", panel_x, slide_duration)
	_tween.tween_property(backdrop.material, "shader_parameter/blur", blur, slide_duration)
