extends Node

signal lobby_members_changed

const MAIN_SCENE := "res://scenes/main.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const LOBBY_TYPE := Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS := 4

var peer: SteamMultiplayerPeer
var current_lobby_id: int = 0


func _ready() -> void:
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
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
		current_lobby_id = lobby_id
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		var error := peer.create_host()
		if error != OK:
			push_error("SteamMultiplayerPeer.create_host failed: %s (%d)" % [error_string(error), error])
			return
		
		multiplayer.multiplayer_peer = peer
		print("Steam multiplayer host listening; peer id=%d" % multiplayer.get_unique_id())
		lobby_members_changed.emit()
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		push_error("Steam lobby creation failed: %d" % connection)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("Steam lobby joined: lobby=%d response=%d" % [lobby_id, response])
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		current_lobby_id = lobby_id
		if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
			lobby_members_changed.emit()
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
		lobby_members_changed.emit()
		get_tree().change_scene_to_file(LOBBY_SCENE)
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

func _on_lobby_chat_update(_lobby_id: int, _changed_id: int, _making_change: int, _chat_state: int) -> void:
	lobby_members_changed.emit()

func get_lobby_members() -> Array[String]:
	var members: Array[String] = []
	if current_lobby_id == 0:
		return members

	for index in Steam.getNumLobbyMembers(current_lobby_id):
		var member_id: int = Steam.getLobbyMemberByIndex(current_lobby_id, index)
		var member_name: String = Steam.getFriendPersonaName(member_id)
		if member_name.is_empty():
			member_name = str(member_id)
		members.append(member_name)
	return members

func can_start_game() -> bool:
	if not multiplayer.is_server() or current_lobby_id == 0:
		return false
	return multiplayer.get_peers().size() + 1 >= Steam.getNumLobbyMembers(current_lobby_id)

func request_start_game() -> void:
	if can_start_game():
		start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func open_join_overlay() -> void:
	Steam.activateGameOverlay("friends")
