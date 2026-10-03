extends Control


func _on_host_pressed() -> void:
	$Buttons/Host.disabled = true
	$Buttons/Join.disabled = true
	Networking.host_lobby()


func _on_join_pressed() -> void:
	Networking.open_join_overlay()
