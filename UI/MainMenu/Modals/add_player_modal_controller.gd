extends Control

@onready var saved_player_modal = get_parent().find_child("SavedPlayerModal", true, false)
@onready var guest_player_modal = get_parent().find_child("GuestPlayerModal", true, false)

func _ready() -> void:
	pass

func _on_saved_option_pressed() -> void:
	visible = false
	if saved_player_modal:
		saved_player_modal.visible = true

func _on_guest_option_pressed() -> void:
	visible = false
	if guest_player_modal:
		guest_player_modal.visible = true

func _on_close_pressed() -> void:
	visible = false

func show_modal() -> void:
	visible = true

func hide_modal() -> void:
	visible = false
