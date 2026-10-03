extends Node

const MAIN_SCENE := "res://scenes/main.tscn"
const LOBBY_TYPE := Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS := 4

var peer: SteamMultiplayerPeer


func _ready() -> void:
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func host_lobby() -> void:
	Steam.createLobby(LOBBY_TYPE, MAX_MEMBERS)

func _on_lobby_created(connection: int, lobby_id: int) -> void:
	print("Steam lobby created: result=%d lobby=%d" % [connection, lobby_id])
	if connection == Steam.RESULT_OK:
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		var error := peer.create_host()
		if error != OK:
			push_error("SteamMultiplayerPeer.create_host failed: %s (%d)" % [error_string(error), error])
			return
		
		multiplayer.multiplayer_peer = peer
		print("Steam multiplayer host listening; peer id=%d" % multiplayer.get_unique_id())
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		push_error("Steam lobby creation failed: %d" % connection)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("Steam lobby joined: lobby=%d response=%d" % [lobby_id, response])
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
			return
		
		var host_id: int = Steam.getLobbyOwner(lobby_id)
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		var error := peer.create_client(host_id)
		if error != OK:
			push_error("SteamMultiplayerPeer.create_client(%d) failed: %s (%d)" % [host_id, error_string(error), error])
			return
		
		multiplayer.multiplayer_peer = peer
		print("Steam multiplayer client connecting to host Steam ID %d" % host_id)
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		push_error("Failed to join Steam lobby %d: response=%d" % [lobby_id, response])

func _on_connected_to_server() -> void:
	print("Godot multiplayer connected to server; peer id=%d" % multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	push_error("Godot multiplayer connection to the Steam host failed")

func _on_server_disconnected() -> void:
	push_warning("Disconnected from the Steam multiplayer host")

func _on_join_requested(lobby_id: int, _steam_id: int) -> void:
	Steam.joinLobby(lobby_id)

func open_join_overlay() -> void:
	Steam.activateGameOverlay("friends")
