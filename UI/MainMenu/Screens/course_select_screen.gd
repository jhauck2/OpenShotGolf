extends Control

const AVATAR_COLORS = [
	Color(0.20392157, 0.59607846, 0.85882354, 1),  # Blue
	Color(0.9019608, 0.49411765, 0.13333334, 1),   # Orange
	Color(0.4, 0.7, 0.4, 1),                        # Green
	Color(0.7, 0.4, 0.7, 1)                         # Purple
]

@onready var players_container = %PlayersContainer


func _ready() -> void:
	# Connect to GlobalSettings active players signal
	GlobalSettings.active_players_changed.connect(_on_active_players_changed)

	# Initial display
	_refresh_players_display()


func _on_active_players_changed(_players: Array) -> void:
	_refresh_players_display()


func _refresh_players_display() -> void:
	# Clear existing player rows
	for child in players_container.get_children():
		child.queue_free()

	# Wait a frame for queue_free to complete
	await get_tree().process_frame

	var active_players = GlobalSettings.get_active_players()

	if active_players.is_empty():
		# Show placeholder message
		var placeholder = Label.new()
		placeholder.text = "No players selected"
		placeholder.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71, 1))
		placeholder.add_theme_font_size_override("font_size", 12)
		players_container.add_child(placeholder)
	else:
		# Create player rows
		for i in range(active_players.size()):
			var player = active_players[i]
			_create_player_row(player, i)


func _create_player_row(player: PlayerData, index: int) -> void:
	var row = HBoxContainer.new()
	row.name = "Player%d" % (index + 1)
	#row.theme_override_constants/separation = 12

	# Avatar
	var avatar = PanelContainer.new()
	avatar.custom_minimum_size = Vector2(30, 30)
	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = AVATAR_COLORS[index % AVATAR_COLORS.size()]
	avatar_style.corner_radius_top_left = 50
	avatar_style.corner_radius_top_right = 50
	avatar_style.corner_radius_bottom_left = 50
	avatar_style.corner_radius_bottom_right = 50
	avatar.add_theme_stylebox_override("panel", avatar_style)

	var avatar_label = Label.new()
	avatar_label.text = "P%d" % (index + 1)
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_label.add_theme_color_override("font_color", Color.WHITE)
	avatar_label.add_theme_font_size_override("font_size", 10)
	avatar.add_child(avatar_label)
	row.add_child(avatar)

	# Name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = player.name if player.name.length() <= 12 else player.name.left(10) + "..."
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_label)

	players_container.add_child(row)


func _on_back_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
