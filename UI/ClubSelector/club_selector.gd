extends PanelContainer

var clubs := ["Dr", "3w", "5w", "2H", "4H", "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw"]
var club_index := 0
var club_buttons: Array[Button] = []
var is_expanded := false
var club_button: Button = null
var grid_container: GridContainer = null
var title_label: Label = null

signal club_selected(club: String)

func _ready() -> void:
	# Setup panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_color = Color(1, 0.65, 0, 1)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	add_theme_stylebox_override("panel", panel_style)

	# Get references to UI elements
	title_label = $MarginContainer/VBoxContainer/Title
	grid_container = $MarginContainer/VBoxContainer/GridContainer

	# Create the main club display button
	_create_club_display_button()

	# Create club buttons in grid
	_create_club_buttons()

	# Initially collapse the grid
	_toggle_grid_visibility()

	# Emit initial selection
	_on_club_button_pressed(0)


func _create_club_display_button() -> void:
	"""Create the main button that displays current club and toggles grid"""
	club_button = Button.new()
	club_button.text = clubs[0]
	club_button.custom_minimum_size = Vector2(100, 60)
	club_button.theme = _create_display_button_theme()
	club_button.pressed.connect(_on_club_display_pressed)

	# Insert after title
	$MarginContainer/VBoxContainer.add_child(club_button)
	$MarginContainer/VBoxContainer.move_child(club_button, 1)


func _create_club_buttons() -> void:
	for i in range(clubs.size()):
		var club_name = clubs[i]

		# Create button
		var button = Button.new()
		button.text = club_name
		button.custom_minimum_size = Vector2(60, 60)
		button.theme = _create_club_button_theme()
		button.pressed.connect(_on_club_button_pressed.bindv([i]))

		grid_container.add_child(button)
		club_buttons.append(button)


func _create_club_button_theme() -> Theme:
	var theme = Theme.new()

	# Button styling
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.4, 0.4, 0.4, 1.0)
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button_style.border_color = Color(1, 0.65, 0, 1)
	button_style.border_width_left = 3
	button_style.border_width_right = 3
	button_style.border_width_top = 3
	button_style.border_width_bottom = 3
	theme.set_stylebox("normal", "Button", button_style)

	# Hover style
	var button_hover_style = button_style.duplicate()
	button_hover_style.bg_color = Color(0.5, 0.5, 0.5, 1.0)
	theme.set_stylebox("hover", "Button", button_hover_style)

	# Pressed style (selected)
	var button_pressed_style = button_style.duplicate()
	button_pressed_style.bg_color = Color(1, 0.65, 0, 0.8)
	theme.set_stylebox("pressed", "Button", button_pressed_style)

	# Font
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_font_size("font_size", "Button", 14)

	return theme


func _create_display_button_theme() -> Theme:
	"""Theme for the main club display button"""
	var theme = Theme.new()

	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(1, 0.65, 0, 0.8)  # Orange background
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button_style.border_color = Color.WHITE
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	theme.set_stylebox("normal", "Button", button_style)

	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(1, 0.75, 0.1, 0.9)
	theme.set_stylebox("hover", "Button", hover_style)

	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_font_size("font_size", "Button", 20)

	return theme


func _toggle_grid_visibility() -> void:
	"""Toggle between showing just the current club or the full grid"""
	is_expanded = not is_expanded
	grid_container.visible = is_expanded

	if is_expanded:
		custom_minimum_size = Vector2(0, 0)  # Let it expand
	else:
		custom_minimum_size = Vector2(120, 80)  # Compact size


func _on_club_display_pressed() -> void:
	"""Toggle grid when display button is clicked"""
	_toggle_grid_visibility()


func _on_club_button_pressed(index: int) -> void:
	club_index = index

	# Update display button
	if club_button:
		club_button.text = clubs[club_index]

	# Update button styles
	for i in range(club_buttons.size()):
		var button = club_buttons[i]
		if i == club_index:
			# Selected - highlight with orange
			button.self_modulate = Color.WHITE
			button.add_theme_color_override("font_color", Color.WHITE)
		else:
			# Not selected - normal gray
			button.self_modulate = Color(0.8, 0.8, 0.8, 1.0)
			button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))

	# Collapse grid after selection
	if is_expanded:
		_toggle_grid_visibility()

	emit_signal("club_selected", clubs[club_index])
