extends PanelContainer
## Improved Mode Display Panel with target info and navigation arrows
## Shows current mode, total points, and target selection with arrow buttons

var mode_label: Label = null
var target_label: Label = null
var prev_target_button: Button = null
var next_target_button: Button = null
var target_distance_label: Label = null

signal target_previous_pressed
signal target_next_pressed

func _ready() -> void:
	# Setup panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_color = Color(1, 0.65, 0, 0.6)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	add_theme_stylebox_override("panel", panel_style)

	# Create margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	# Create main VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Mode line: "Current mode: {mode} {points}"
	var mode_hbox = HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(mode_hbox)

	var mode_title = Label.new()
	mode_title.text = "Mode: "
	mode_title.add_theme_font_size_override("font_size", 14)
	mode_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	mode_hbox.add_child(mode_title)

	mode_label = Label.new()
	mode_label.text = "FREE PRACTICE"
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	mode_hbox.add_child(mode_label)

	# Points display (only in target mode)
	target_label = Label.new()
	target_label.text = " | Points: 0"
	target_label.add_theme_font_size_override("font_size", 14)
	target_label.add_theme_color_override("font_color", Color(1, 0.65, 0, 1.0))
	mode_hbox.add_child(target_label)

	# Target selection line (only in target mode)
	var target_hbox = HBoxContainer.new()
	target_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(target_hbox)

	prev_target_button = Button.new()
	prev_target_button.text = "<"
	prev_target_button.custom_minimum_size = Vector2(35, 28)
	prev_target_button.add_theme_font_size_override("font_size", 16)
	prev_target_button.pressed.connect(_on_prev_target)
	target_hbox.add_child(prev_target_button)

	target_distance_label = Label.new()
	target_distance_label.text = "Select Target"
	target_distance_label.add_theme_font_size_override("font_size", 14)
	target_distance_label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	target_distance_label.custom_minimum_size = Vector2(150, 28)
	target_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_hbox.add_child(target_distance_label)

	next_target_button = Button.new()
	next_target_button.text = ">"
	next_target_button.custom_minimum_size = Vector2(35, 28)
	next_target_button.add_theme_font_size_override("font_size", 16)
	next_target_button.pressed.connect(_on_next_target)
	target_hbox.add_child(next_target_button)

	# Initially hide target controls
	target_hbox.visible = false
	target_label.visible = false

	# Connect to GameState signals
	if GameState:
		GameState.mode_changed.connect(_on_game_state_mode_changed)
		GameState.target_changed.connect(_on_game_state_target_changed)

	# Initial update
	_update_display()


func _update_display() -> void:
	"""Update the display based on current GameState"""
	if not GameState:
		return

	if mode_label:
		mode_label.text = GameState.get_mode_text()

	var is_target_mode = GameState.current_mode == 1  # TARGET_PRACTICE

	if target_label:
		if is_target_mode:
			target_label.visible = true
			target_label.text = " | Points: %d" % GameState.get_total_points()
		else:
			target_label.visible = false

	# Show/hide target selection controls
	if prev_target_button:
		prev_target_button.get_parent().visible = is_target_mode

	if target_distance_label:
		if is_target_mode:
			target_distance_label.text = "%s - %.0f yd" % [GameState.current_target_name, GameState.current_target_distance]


func _on_game_state_mode_changed(_mode: int) -> void:
	"""Update display when mode changes"""
	_update_display()


func _on_game_state_target_changed(target_name: String, distance: float) -> void:
	"""Update target display when target changes"""
	if target_distance_label:
		target_distance_label.text = "%s - %.0f yd" % [target_name, distance]


func _on_prev_target() -> void:
	"""Previous target button pressed"""
	emit_signal("target_previous_pressed")


func _on_next_target() -> void:
	"""Next target button pressed"""
	emit_signal("target_next_pressed")


func update_points(points: int) -> void:
	"""Update the total points display"""
	if target_label and GameState.current_mode == 1:  # TARGET_PRACTICE
		target_label.text = " | Points: %d" % points
