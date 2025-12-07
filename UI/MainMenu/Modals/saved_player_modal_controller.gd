extends Control

const PlayerData = preload("res://Utils/Data/player_data.gd")

## Saved Player Modal Controller
##
## Displays list of saved players from database and handles player selection.

signal player_selected(player_data: PlayerData)

@export var close_button_paths: Array[NodePath] = []

@onready var player_list = $ModalContent2/MarginContainer/VBoxContainer/ScrollContainer/PlayerList

var SelectPlayerCardScene = preload("res://UI/MainMenu/Components/select_player_card.tscn")


func _ready() -> void:
	# Connect close buttons
	for button_path in close_button_paths:
		var button = get_node(button_path)
		if button and button is Button:
			button.pressed.connect(_on_close_button_pressed)

	# Connect to EventBus to refresh list on changes
	EventBus.player_deleted.connect(_load_players)
	EventBus.player_renamed.connect(_on_player_renamed)

	# Load players when modal becomes visible
	visibility_changed.connect(_on_visibility_changed)


func _on_player_renamed(_player_data: Dictionary) -> void:
	_load_players()


func _on_visibility_changed() -> void:
	if visible:
		_load_players()


func _load_players() -> void:
	# Clear existing placeholder cards
	for child in player_list.get_children():
		child.queue_free()

	# Wait a frame for queue_free to complete
	await get_tree().process_frame

	var all_players = DatabaseManager.get_all_players(false)  # Exclude guests
	var active_player_ids = []
	for p in GlobalSettings.get_active_players():
		active_player_ids.append(p.id)

	if all_players.is_empty():
		# Show "No saved players" message
		var label = Label.new()
		label.text = "No saved players found.\nCreate a new player to get started."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71, 1))
		player_list.add_child(label)
		return

	# Create cards for each player
	for player_dict in all_players:
		var card = SelectPlayerCardScene.instantiate()
		player_list.add_child(card)

		var player_data = PlayerData.from_dict(player_dict)
		card.set_player_data(player_data)

		# Disable card if player is already active
		if player_data.id in active_player_ids:
			card.disabled = true
			# Optionally add a visual indicator for disabled state
			card.modulate = Color(0.5, 0.5, 0.5, 0.8)

		# Connect card pressed signal
		card.pressed.connect(_on_player_card_pressed.bind(player_data))


func _on_player_card_pressed(player_data: PlayerData) -> void:
	# This now adds to the session, not just sets current player
	var success = GlobalSettings.add_active_player(player_data)
	if success:
		emit_signal("player_selected", player_data)
	else:
		print("Could not add player to session: ", player_data.name)

	visible = false


func _on_close_button_pressed() -> void:
	visible = false
