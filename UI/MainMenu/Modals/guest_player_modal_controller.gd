extends Control

const PlayerData = preload("res://Utils/Data/player_data.gd")

## New Player Modal Controller
##
## Handles creating new players - either as guest (temporary) or saved (permanent).

signal guest_player_created(player_data: RefCounted)
signal saved_player_created(player_data: RefCounted)

@export var close_button_paths: Array[NodePath] = []

@onready var name_input = $ModalContent2/MarginContainer/VBoxContainer/InputGroup/Input
@onready var guest_btn = $ModalContent2/MarginContainer/VBoxContainer/ButtonContainer/GuestBtn
@onready var save_btn = $ModalContent2/MarginContainer/VBoxContainer/ButtonContainer/SaveBtn


func _ready() -> void:
	# Connect close buttons
	for button_path in close_button_paths:
		var button = get_node(button_path)
		if button and button is Button:
			button.pressed.connect(_on_close_button_pressed)

	# Connect action buttons
	if guest_btn:
		guest_btn.pressed.connect(_on_guest_pressed)
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)

	# Clear input when modal becomes visible
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible and name_input:
		name_input.text = ""
		name_input.grab_focus()


func _on_guest_pressed() -> void:
	_create_player(true)  # is_guest = true


func _on_save_pressed() -> void:
	_create_player(false)  # is_guest = false


func _create_player(is_guest: bool) -> void:
	if not name_input:
		return

	var player_name = name_input.text.strip_edges()

	if player_name.is_empty():
		_show_error("Please enter a player name")
		return

	# Check if name already exists
	var existing = DatabaseManager.get_player_by_name(player_name)
	if not existing.is_empty():
		_show_error("A player with this name already exists")
		return

	# Create player in database
	var player_id = DatabaseManager.create_player(player_name, is_guest)

	if player_id > 0:
		# Get the created player data
		var player_dict = DatabaseManager.get_player(player_id)
		var player_data = PlayerData.from_dict(player_dict)

		# Emit appropriate signal
		if is_guest:
			emit_signal("guest_player_created", player_data)
			print("Guest player created: ", player_name)
		else:
			emit_signal("saved_player_created", player_data)
			print("Saved player created: ", player_name)

		# Clear input and close modal
		name_input.text = ""
		visible = false
	else:
		_show_error("Failed to create player")


func _show_error(message: String) -> void:
	push_warning("New Player Error: ", message)

	# Flash the input field red briefly
	if name_input:
		name_input.add_theme_color_override("font_color", Color.RED)
		await get_tree().create_timer(0.5).timeout
		name_input.remove_theme_color_override("font_color")


func _on_close_button_pressed() -> void:
	visible = false


func show_modal() -> void:
	visible = true


func hide_modal() -> void:
	visible = false
