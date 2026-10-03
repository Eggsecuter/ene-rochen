extends Node3D

const PLAYER = preload("uid://dqalabolous7s")

@onready var spawn_point: Node3D = $SpawnPoint

var players: Array[CharacterBody3D]

func _ready() -> void:
	if multiplayer.is_server():
		Networking.main_scene_ready.connect(_on_main_scene_ready)
		multiplayer.peer_connected.connect(_on_peer_connected)
	Networking.report_main_scene_ready()

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody3D:
		_initialize_player(node)

func _on_main_scene_ready(peer_ids: Array[int]) -> void:
	for peer_id in peer_ids:
		_spawn_player(peer_id)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("All players are ready; spawned the lobby members")

func _on_peer_connected(peer_id: int) -> void:
	_spawn_player(peer_id)

func _spawn_player(peer_id: int) -> void:
	if has_node(str(peer_id)):
		return
	print("Spawning player for peer %d" % peer_id)
	var player := PLAYER.instantiate() as CharacterBody3D
	player.name = str(peer_id)
	player.position = spawn_point.position + Vector3(players.size() * 2.5, 0, 0)
	add_child(player)
	_initialize_player(player)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %d" % peer_id)

func _initialize_player(player: CharacterBody3D) -> void:
	if not players.has(player):
		players.append(player)
