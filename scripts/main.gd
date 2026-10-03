extends Node3D

const PLAYER = preload("uid://dqalabolous7s")

@onready var spawn_point: Node3D = $SpawnPoint
@onready var host_button: Button = $CanvasLayer/Host

var players: Array[CharacterBody3D]

func _ready() -> void:
	Networking.host_created.connect(_on_host_created)

func _on_host_pressed() -> void:
	host_button.hide()
	Networking.host_lobby()

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody3D:
		_initialize_player(node)

func _on_host_created() -> void:
	# spawn host
	_spawn_player(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(_spawn_player)

func _spawn_player(peer_id: int) -> void:
	var player := PLAYER.instantiate() as CharacterBody3D
	player.name = str(peer_id)
	add_child(player)
	_initialize_player(player)

func _initialize_player(player: CharacterBody3D) -> void:
	# TODO different spawn points
	player.position = spawn_point.position
	players.append(player)
