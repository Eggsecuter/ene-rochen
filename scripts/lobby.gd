extends Control

@onready var member_list: VBoxContainer = $Panel/MemberList
@onready var status_label: Label = $Panel/Status
@onready var start_button: Button = $Panel/StartGame


func _ready() -> void:
	Networking.lobby_members_changed.connect(_refresh_members)
	start_button.visible = multiplayer.is_server()
	_refresh_members()
	_update_start_button()


func _process(_delta: float) -> void:
	_update_start_button()


func _refresh_members() -> void:
	for child in member_list.get_children():
		child.queue_free()

	for member_name in Networking.get_lobby_members():
		var member_label := Label.new()
		member_label.text = member_name
		member_list.add_child(member_label)

	if member_list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "Waiting for players..."
		member_list.add_child(empty_label)


func _update_start_button() -> void:
	if not multiplayer.is_server():
		return
	var ready_to_start: bool = Networking.can_start_game()
	start_button.disabled = not ready_to_start
	status_label.text = "Everyone is connected." if ready_to_start else "Waiting for players to connect..."


func _on_start_game_pressed() -> void:
	Networking.request_start_game()
