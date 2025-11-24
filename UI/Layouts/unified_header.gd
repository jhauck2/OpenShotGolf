extends HBoxContainer

## Unified Header - Shared header for all three layouts
## Contains player name, mode indicator, and common buttons

signal layout_switch_pressed
signal camera_pressed
signal rec_button_pressed
signal exit_pressed

@export var next_layout_text: String = "Detail >"
@export var show_rec_button: bool = true
@export var show_exit_button: bool = true

var player_label: Button = null
var lm_indicator: Control = null  # Launch Monitor connection indicator
var mode_label: Label = null
var target_label: Label = null
var mode_toggle_button: Button = null
var layout_button: Button = null
var rec_button: Button = null
var camera_button: Button = null
var exit_button: Button = null
var tcp_server_ref: Node = null  # Reference to TCP server for status checking
var prev_target_button: Button = null
var next_target_button: Button = null
var range_ref: Node = null  # Reference to Range node for target navigation
var help_button: Button = null  # Help button
var mode_indicator_overlay: Control = null  # Help overlay panel
var settings_button: Button = null  # Settings button
var range_settings_panel: Control = null  # Range settings panel


func _ready() -> void:
	# Setup theme
	add_theme_constant_override("separation", 10)

	# Create player badge
	player_label = Button.new()
	player_label.custom_minimum_size = Vector2(100, 40)
	player_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	player_label.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	player_label.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	player_label.add_theme_font_size_override("font_size", 20)
	player_label.text = "Player1"
	add_child(player_label)

	# Create Launch Monitor indicator (green/red dot)
	lm_indicator = Panel.new()
	lm_indicator.custom_minimum_size = Vector2(20, 20)
	lm_indicator.tooltip_text = "Launch Monitor Status"

	# Create a simple indicator panel
	var lm_stylebox = StyleBoxFlat.new()
	lm_stylebox.bg_color = Color.RED  # Start as disconnected
	lm_stylebox.corner_radius_top_left = 10
	lm_stylebox.corner_radius_top_right = 10
	lm_stylebox.corner_radius_bottom_left = 10
	lm_stylebox.corner_radius_bottom_right = 10
	lm_indicator.add_theme_stylebox_override("panel", lm_stylebox)

	add_child(lm_indicator)

	# Try to get reference to Range node and TCP server
	if get_tree().root.has_node("Range"):
		range_ref = get_tree().root.get_node("Range")
		if range_ref.has_node("TCPServer"):
			tcp_server_ref = range_ref.get_node("TCPServer")
	elif get_tree().root.has_node("Range/TCPServer"):
		tcp_server_ref = get_tree().root.get_node("Range/TCPServer")
		range_ref = get_tree().root.get_node("Range")

	# Create mode container (center)
	var mode_container = VBoxContainer.new()
	mode_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_container.add_theme_constant_override("separation", 0)
	add_child(mode_container)

	# Mode label
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 32)
	mode_label.text = "FREE PRACTICE"
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_container.add_child(mode_label)

	# Target label with arrow buttons (shown only in target mode)
	var target_hbox = HBoxContainer.new()
	target_hbox.add_theme_constant_override("separation", 6)
	target_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_container.add_child(target_hbox)

	prev_target_button = Button.new()
	prev_target_button.text = "<"
	prev_target_button.custom_minimum_size = Vector2(35, 28)
	prev_target_button.add_theme_font_size_override("font_size", 16)
	prev_target_button.theme = _create_arrow_button_theme()
	prev_target_button.tooltip_text = "Previous Target"
	prev_target_button.pressed.connect(_on_prev_target_pressed)
	target_hbox.add_child(prev_target_button)

	target_label = Label.new()
	target_label.add_theme_font_size_override("font_size", 20)
	target_label.text = ""
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_label.custom_minimum_size = Vector2(200, 28)
	target_hbox.add_child(target_label)

	next_target_button = Button.new()
	next_target_button.text = ">"
	next_target_button.custom_minimum_size = Vector2(35, 28)
	next_target_button.add_theme_font_size_override("font_size", 16)
	next_target_button.theme = _create_arrow_button_theme()
	next_target_button.tooltip_text = "Next Target"
	next_target_button.pressed.connect(_on_next_target_pressed)
	target_hbox.add_child(next_target_button)

	# Initially hide target controls
	target_hbox.visible = false

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# Settings group (right side buttons)
	var settings_group = HBoxContainer.new()
	settings_group.add_theme_constant_override("separation", 5)
	add_child(settings_group)

	# Mode toggle button
	mode_toggle_button = Button.new()
	mode_toggle_button.text = "Mode: FREE"
	mode_toggle_button.tooltip_text = "Toggle between Free Practice and Target Practice (M key)"
	mode_toggle_button.pressed.connect(_on_mode_toggle_pressed)
	settings_group.add_child(mode_toggle_button)

	# Layout switch button
	layout_button = Button.new()
	layout_button.text = next_layout_text
	layout_button.tooltip_text = "Switch between Custom, Detail, and Overview layouts"
	layout_button.pressed.connect(_on_layout_button_pressed)
	settings_group.add_child(layout_button)

	# REC button (optional)
	if show_rec_button:
		rec_button = Button.new()
		rec_button.text = "REC: Off"
		rec_button.tooltip_text = "Start Recording Range Session"
		rec_button.pressed.connect(_on_rec_pressed)
		settings_group.add_child(rec_button)

	# Settings button
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.tooltip_text = "Open Range Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	settings_group.add_child(settings_button)

	# Help button
	help_button = Button.new()
	help_button.text = "Help"
	help_button.tooltip_text = "Show controls and help"
	help_button.pressed.connect(_on_help_pressed)
	settings_group.add_child(help_button)

	# Camera button
	camera_button = Button.new()
	camera_button.text = "Camera >"
	camera_button.tooltip_text = "Cycle through camera views (1-5, C key)"
	camera_button.pressed.connect(_on_camera_pressed)
	settings_group.add_child(camera_button)

	# Exit button (optional)
	if show_exit_button:
		exit_button = Button.new()
		exit_button.text = "Exit"
		exit_button.tooltip_text = "Exit to main menu (Esc key)"
		exit_button.pressed.connect(_on_exit_pressed)
		settings_group.add_child(exit_button)

	# Connect to GameState signals for mode/target changes from other layouts
	if GameState:
		GameState.mode_changed.connect(_on_gamestate_mode_changed)
		GameState.target_changed.connect(_on_gamestate_target_changed)


func _exit_tree() -> void:
	"""Clean up overlays when this header is removed (layout switch)"""
	_cleanup_help_overlay()
	_cleanup_settings_panel()


func _cleanup_help_overlay() -> void:
	"""Remove the help overlay if it exists"""
	if mode_indicator_overlay:
		mode_indicator_overlay.queue_free()
		mode_indicator_overlay = null


func _cleanup_settings_panel() -> void:
	"""Remove the settings panel if it exists"""
	if range_settings_panel:
		range_settings_panel.queue_free()
		range_settings_panel = null


func set_player_name(name: String) -> void:
	if player_label:
		player_label.text = name


func set_mode_text(mode: String) -> void:
	if mode_label:
		mode_label.text = mode


func set_target_text(target: String) -> void:
	if target_label:
		target_label.text = target


func set_next_layout_text(text: String) -> void:
	if layout_button:
		layout_button.text = text


func set_rec_button_text(text: String) -> void:
	if rec_button:
		rec_button.text = text


func _on_layout_button_pressed() -> void:
	print("Layout button pressed - emitting layout_switch_pressed signal")
	emit_signal("layout_switch_pressed")


func _on_rec_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_camera_pressed() -> void:
	emit_signal("camera_pressed")


func _on_exit_pressed() -> void:
	emit_signal("exit_pressed")


func _on_mode_toggle_pressed() -> void:
	"""Toggle mode when button pressed"""
	if GameState:
		GameState.toggle_mode()
		_update_mode_button()


func _process(_delta: float) -> void:
	# Update LM indicator status
	if lm_indicator and tcp_server_ref:
		var is_connected = tcp_server_ref.get("tcp_connected")
		var indicator_color = Color.GREEN if is_connected else Color.RED
		var stylebox = lm_indicator.get_theme_stylebox("panel")
		if stylebox:
			stylebox.bg_color = indicator_color
			lm_indicator.tooltip_text = "Launch Monitor: %s" % ("Connected" if is_connected else "Offline")

	# Update mode displays
	_update_mode_display()


func _update_mode_display() -> void:
	"""Update all mode-related displays based on GameState"""
	if not GameState:
		return

	# Update main mode label
	if mode_label:
		mode_label.text = GameState.get_mode_text()

	# Update mode toggle button
	if mode_toggle_button:
		var mode_text = "TARGET" if GameState.current_mode == 1 else "FREE"
		mode_toggle_button.text = "Mode: %s" % mode_text

	# Show/hide target controls based on mode
	var is_target_mode = GameState.current_mode == 1
	if prev_target_button:
		prev_target_button.get_parent().visible = is_target_mode

	# Update target label display
	if target_label and is_target_mode:
		# Only show target if we have valid data
		if GameState.current_target_distance > 0:
			target_label.text = "%.0f Yard Target" % GameState.current_target_distance
		else:
			target_label.text = "Select Target"


func _update_mode_button() -> void:
	"""Update mode toggle button text"""
	_update_mode_display()


func _on_gamestate_mode_changed(mode: int) -> void:
	"""Handle mode change from GameState"""
	_update_mode_display()


func _on_gamestate_target_changed(target_name: String, distance: float) -> void:
	"""Handle target change from GameState"""
	if target_label:
		if distance > 0:
			target_label.text = "%.0f Yard Target" % distance
		else:
			target_label.text = "Select Target"


func _on_prev_target_pressed() -> void:
	"""Handle previous target button press"""
	if range_ref and range_ref.has_method("select_previous_target"):
		range_ref.select_previous_target()


func _on_next_target_pressed() -> void:
	"""Handle next target button press"""
	if range_ref and range_ref.has_method("select_next_target"):
		range_ref.select_next_target()


func _on_settings_pressed() -> void:
	"""Show/hide settings panel"""
	if range_settings_panel:
		# Toggle visibility if already exists
		range_settings_panel.visible = not range_settings_panel.visible
	else:
		# Load and instantiate the range settings scene
		var RangeSettingsScene = load("res://UI/Settings/RangeSettings/range_settings.tscn")
		if RangeSettingsScene:
			range_settings_panel = RangeSettingsScene.instantiate()

			# Position it in the center of the screen
			range_settings_panel.anchor_left = 0.5
			range_settings_panel.anchor_top = 0.5
			range_settings_panel.anchor_right = 0.5
			range_settings_panel.anchor_bottom = 0.5
			range_settings_panel.offset_left = -190  # Half width (380/2)
			range_settings_panel.offset_top = -100   # Half height (200/2)

			# Add to root of scene tree to appear above everything
			get_tree().root.add_child(range_settings_panel)
		else:
			push_error("Could not load range_settings.tscn")


func _on_help_pressed() -> void:
	"""Show help overlay with controls"""
	if mode_indicator_overlay:
		# Toggle visibility if already exists
		mode_indicator_overlay.visible = not mode_indicator_overlay.visible
	else:
		# Create new mode indicator overlay as PanelContainer with script
		mode_indicator_overlay = PanelContainer.new()
		mode_indicator_overlay.name = "HelpOverlay"

		# Attach the mode_indicator script
		var ModeIndicatorScript = load("res://UI/ModeIndicator/mode_indicator.gd")
		if ModeIndicatorScript:
			mode_indicator_overlay.set_script(ModeIndicatorScript)

			# Position it centered on screen
			mode_indicator_overlay.anchor_left = 0.5
			mode_indicator_overlay.anchor_top = 0.5
			mode_indicator_overlay.anchor_right = 0.5
			mode_indicator_overlay.anchor_bottom = 0.5
			mode_indicator_overlay.offset_left = -140  # Half width (280/2)
			mode_indicator_overlay.offset_top = -100   # Half height (200/2)

			# Add to root of scene tree to appear above everything
			get_tree().root.add_child(mode_indicator_overlay)

			# Call _ready to initialize the UI
			await get_tree().process_frame
			if mode_indicator_overlay.has_method("_ready"):
				mode_indicator_overlay._ready()
		else:
			push_error("Could not load mode_indicator.gd")


func _create_arrow_button_theme() -> Theme:
	"""Create theme for arrow buttons (< >)"""
	var theme = Theme.new()

	# Normal style
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.4, 0.4, 0.4, 1.0)
	button_style.corner_radius_top_left = 6
	button_style.corner_radius_top_right = 6
	button_style.corner_radius_bottom_left = 6
	button_style.corner_radius_bottom_right = 6
	button_style.border_color = Color(1, 0.65, 0, 1)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	theme.set_stylebox("normal", "Button", button_style)

	# Hover style
	var button_hover_style = button_style.duplicate()
	button_hover_style.bg_color = Color(0.5, 0.5, 0.5, 1.0)
	theme.set_stylebox("hover", "Button", button_hover_style)

	# Pressed style
	var button_pressed_style = button_style.duplicate()
	button_pressed_style.bg_color = Color(1, 0.65, 0, 0.8)
	theme.set_stylebox("pressed", "Button", button_pressed_style)

	# Font colors
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)

	return theme
