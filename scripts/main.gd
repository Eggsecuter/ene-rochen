extends Node3D

const PLAYER = preload("uid://dqalabolous7s")

@onready var spawn_point: Node3D = $SpawnPoint

var players: Array[CharacterBody3D]

func _ready() -> void:
	if multiplayer.is_server():
		_on_host_created()

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody3D:
		_initialize_player(node)

func _on_host_created() -> void:
	# spawn host
	_spawn_player(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(_spawn_player)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Spawned local host player; waiting for peers")

func _spawn_player(peer_id: int) -> void:
	print("Spawning player for peer %d" % peer_id)
	var player := PLAYER.instantiate() as CharacterBody3D
	player.name = str(peer_id)
	add_child(player)
	_initialize_player(player)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %d" % peer_id)

func _initialize_player(player: CharacterBody3D) -> void:
	# TODO different spawn points
	player.position = spawn_point.position
	players.append(player)
