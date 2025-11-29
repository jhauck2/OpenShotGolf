extends PanelContainer

var clubs := ["Dr", "3w", "5w", "2H", "3H", "4H", "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw"]
var current_club: Button = null
var club_button: Button = null
var grid_container: GridContainer = null

# Theme colors
const BUTTON_BG_NORMAL = Color(0.4, 0.4, 0.4, 1.0)
const BUTTON_BG_HOVER = Color(0.5, 0.5, 0.5, 1.0)
const BUTTON_BG_PRESSED = Color(1, 0.65, 0, 0.8)
const BUTTON_BORDER = Color(1, 0.65, 0, 1)
const DISPLAY_BG_NORMAL = Color(1, 0.65, 0, 0.8)
const DISPLAY_BG_HOVER = Color(1, 0.75, 0.1, 0.9)
const DISPLAY_BORDER = Color.WHITE
const BUTTON_UNSELECTED = Color(0.8, 0.8, 0.8, 1.0)
const BUTTON_UNSELECTED_FONT = Color(0.9, 0.9, 0.9, 1.0)

func _ready() -> void:
	grid_container = $MarginContainer/VBoxContainer/GridContainer
	_create_club_display_button()
	_create_club_buttons()
	current_club = grid_container.get_child(0)
	_on_club_button_pressed(current_club)


func _input(event: InputEvent) -> void:
	if not grid_container.visible:
		return
	var global_mouse_pos = get_global_mouse_position()
	var selector_rect = get_global_rect()
	var is_over_selector = selector_rect.has_point(global_mouse_pos)

	if event is InputEventMouseButton:
		if not is_over_selector:
			if event.pressed:
				_toggle_grid_visibility()
			get_tree().root.set_input_as_handled()
	elif event is InputEventMouseMotion:
		if not is_over_selector:
			get_tree().root.set_input_as_handled()


func _create_club_display_button() -> void:
	club_button = Button.new()
	club_button.text = clubs[0]
	club_button.custom_minimum_size = Vector2(100, 60)
	club_button.theme = _create_display_button_theme()
	club_button.pressed.connect(_on_display_button_pressed)

	$MarginContainer/VBoxContainer.add_child(club_button)
	$MarginContainer/VBoxContainer.move_child(club_button, 1)


func _create_club_buttons() -> void:
	var button_theme = _create_club_button_theme()
	for i in range(clubs.size()):
		var button = Button.new()
		button.text = clubs[i]
		button.custom_minimum_size = Vector2(60, 60)
		button.theme = button_theme
		button.pressed.connect(_on_club_button_pressed.bindv([button]))
		grid_container.add_child(button)


func _create_club_button_theme() -> Theme:
	var button_theme = Theme.new()
	button_theme.set_font_size("font_size", "Button", 14)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = BUTTON_BG_NORMAL
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.border_color = BUTTON_BORDER
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	button_theme.set_stylebox("normal", "Button", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = BUTTON_BG_HOVER
	button_theme.set_stylebox("hover", "Button", hover_style)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = BUTTON_BG_PRESSED
	button_theme.set_stylebox("pressed", "Button", pressed_style)

	return button_theme


func _create_display_button_theme() -> Theme:
	var display_theme = Theme.new()
	display_theme.set_font_size("font_size", "Button", 20)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = DISPLAY_BG_NORMAL
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.border_color = DISPLAY_BORDER
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	display_theme.set_stylebox("normal", "Button", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = DISPLAY_BG_HOVER
	display_theme.set_stylebox("hover", "Button", hover_style)

	return display_theme


func _toggle_grid_visibility() -> void:
	grid_container.visible = not grid_container.visible


func _on_display_button_pressed() -> void:
	_toggle_grid_visibility()


func _on_club_button_pressed(button: Button) -> void:
	# Deselect the old button
	if current_club:
		current_club.self_modulate = BUTTON_UNSELECTED
		current_club.add_theme_color_override("font_color", BUTTON_UNSELECTED_FONT)

	# Update the display button
	club_button.text = button.text

	# Select the new button
	current_club = button
	current_club.self_modulate = Color.WHITE
	current_club.add_theme_color_override("font_color", Color.WHITE)

	_toggle_grid_visibility()

	EventBus.emit_signal("club_selected", current_club.text)
