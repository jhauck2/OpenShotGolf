extends Control

const PlayerData = preload("res://Utils/Data/player_data.gd")

const AVATAR_COLORS = [
	Color(0.20392157, 0.59607846, 0.85882354, 1),  # Blue
	Color(0.9019608, 0.49411765, 0.13333334, 1),   # Orange
	Color(0.4, 0.7, 0.4, 1),                        # Green
	Color(0.7, 0.4, 0.7, 1)                         # Purple
]

@onready var players_container = $LobbyWidget/MarginContainer/VBoxContainer/PlayersContainer
@onready var add_player_btn = $LobbyWidget/MarginContainer/VBoxContainer/AddPlayerBtn
@onready var range_btn = $HBoxContainer/MarginContainer2/Sidebar/MarginContainer/VBoxContainer/VBoxContainer/RangeBtn
@onready var course_btn = $HBoxContainer/MarginContainer2/Sidebar/MarginContainer/VBoxContainer/VBoxContainer/CourseBtn


func _ready() -> void:
	SceneManager.current_scene = self

	# Connect to GlobalSettings active players signal
	GlobalSettings.active_players_changed.connect(_on_active_players_changed)

	# Connect modal signals
	if has_node("%GuestPlayerModal"):
		%GuestPlayerModal.guest_player_created.connect(_on_player_added)
		%GuestPlayerModal.saved_player_created.connect(_on_player_added)
	if has_node("%SavedPlayerModal"):
		%SavedPlayerModal.player_selected.connect(_on_player_added)

	# Initial display
	_refresh_players_display()
	_update_navigation_buttons()


func _on_active_players_changed(_players: Array) -> void:
	_refresh_players_display()
	_update_navigation_buttons()


func _on_player_added(player_data: PlayerData) -> void:
	GlobalSettings.add_active_player(player_data)


func _update_navigation_buttons() -> void:
	var has_players = GlobalSettings.get_active_player_count() > 0
	if range_btn:
		range_btn.disabled = not has_players
		range_btn.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND if has_players  else Input.CURSOR_FORBIDDEN
		range_btn.tooltip_text = "" if has_players else "Add at least one player to access the range"
	if course_btn:
		course_btn.disabled = not has_players
		course_btn.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND if has_players  else Input.CURSOR_FORBIDDEN
		course_btn.tooltip_text = "" if has_players else "Add at least one player to play courses"


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
		placeholder.text = "No players added"
		placeholder.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71, 1))
		placeholder.add_theme_font_size_override("font_size", 12)
		players_container.add_child(placeholder)
	else:
		# Create player rows
		for i in range(active_players.size()):
			var player = active_players[i]
			_create_player_row(player, i)

	# Update add button visibility
	add_player_btn.visible = GlobalSettings.can_add_player()


func _create_player_row(player: PlayerData, index: int) -> void:
	var row = HBoxContainer.new()
	row.name = "Player%d" % (index + 1)

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
	name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	row.add_child(spacer)

	# View Profile Button
	var view_btn = Button.new()
	view_btn.custom_minimum_size = Vector2(30, 30)
	view_btn.flat = false
	view_btn.theme_type_variation = "PrimaryButton"
	view_btn.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND
	view_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_btn.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71, 1))
	view_btn.add_theme_constant_override("icon_max_width", 16)
	view_btn.add_theme_font_size_override("font_size", 12)
	
	if player.is_guest:
		view_btn.disabled = true
		view_btn.mouse_default_cursor_shape = Input.CURSOR_FORBIDDEN
		view_btn.tooltip_text = "Cannot view profile of guest players"
	else:
		view_btn.tooltip_text = "View Profile"
		view_btn.pressed.connect(_on_view_player_profile.bind(player))
	
	# Load icon if available
	var visibility_icon = load("res://Resources/Icons/visibility.png")
	if visibility_icon:
		view_btn.icon = visibility_icon
	row.add_child(view_btn)

	# Delete Button
	var delete_btn = Button.new()
	delete_btn.custom_minimum_size = Vector2(30, 30)
	delete_btn.flat = true
	delete_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_btn.add_theme_color_override("font_color", Color(0.9059, 0.298, 0.2353, 1))
	delete_btn.add_theme_color_override("icon_normal_color", Color(0.88235295, 0.29411766, 0.23529412, 1))
	delete_btn.add_theme_color_override("icon_hover_color", Color(0.6180611, 0.188681, 0.14525244, 1))
	delete_btn.add_theme_constant_override("icon_max_width", 16)
	delete_btn.tooltip_text = "Remove from Session"
	delete_btn.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND
	var close_icon = load("res://Resources/Icons/close.png")
	if close_icon:
		delete_btn.icon = close_icon
	delete_btn.pressed.connect(_on_remove_player.bind(player.id))
	row.add_child(delete_btn)

	players_container.add_child(row)


func _on_view_player_profile(player: PlayerData) -> void:
	GlobalSettings.set_current_player(player)
	SceneManager.change_scene("res://UI/MainMenu/Screens/profile_screen.tscn")


func _on_remove_player(player_id: int) -> void:
	GlobalSettings.remove_active_player(player_id)


func _on_range_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/range_mode_screen.tscn")


func _on_courses_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/course_select_screen.tscn")


func _on_settings_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/settings_screen.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_view_profile_btn_pressed() -> void:
	# View first active player's profile, or open player selection
	if GlobalSettings.get_active_player_count() > 0:
		var player = GlobalSettings.get_active_player(0)
		GlobalSettings.set_current_player(player)
		SceneManager.change_scene("res://UI/MainMenu/Screens/profile_screen.tscn")
	else:
		%AddPlayerModal.visible = true


func _on_add_player_btn_pressed() -> void:
	%AddPlayerModal.visible = not %AddPlayerModal.visible
