extends PanelContainer

## Displays the current range mode and controls

var mode_label: Label
var controls_label: Label


func _ready() -> void:
	_create_ui()
	_setup_background()
	_setup_gamestate_connection()


func _create_ui() -> void:
	custom_minimum_size = Vector2(250, 120)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "RANGE MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	mode_label = Label.new()
	mode_label.text = "[TARGET] Target Practice"
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(mode_label)

	controls_label = Label.new()
	controls_label.text = "1-5: Camera angles\nC: Cycle camera\n[ ]: Cycle targets\nM: Switch mode\nT: Toggle UI"
	controls_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(controls_label)

	custom_minimum_size = Vector2(280, 200)


## Update the mode display
func set_mode(mode_name: String, controls: String = "") -> void:
	if mode_label:
		mode_label.text = mode_name

	if controls and controls_label:
		controls_label.text = controls

func show_free_practice_mode() -> void:
	mode_label.text = "[FREE] Free Practice"
	controls_label.text = "1-5: Camera\nC: Cycle cam\nM: Mode\nT: UI"


## Set mode to target practice
func show_target_practice_mode() -> void:
	mode_label.text = "[TARGET] Target Practice"
	controls_label.text = "1-5: Camera\nC: Cycle cam\n[ ]: Targets\nArrows: Aim\nCtrl+R: Reset stats\nM: Mode\nT: UI"


func _setup_background() -> void:
	"""Set a solid background without transparency"""
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	panel_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	add_theme_stylebox_override("panel", panel_style)


func _setup_gamestate_connection() -> void:
	"""Connect to GameState signals to update mode display"""
	if GameState:
		GameState.mode_changed.connect(_on_gamestate_mode_changed)
		_on_gamestate_mode_changed(GameState.current_mode)


func _on_gamestate_mode_changed(new_mode: int) -> void:
	"""Update the mode display when GameState mode changes"""
	if new_mode == 0:
		show_free_practice_mode()
	elif new_mode == 1:
		show_target_practice_mode()
