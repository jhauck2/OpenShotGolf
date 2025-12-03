extends PanelContainer

@export var title: String = "TITLE":
	set(value):
		title = value
		if has_node("VBoxContainer/TitleLabel"):
			$VBoxContainer/TitleLabel.text = value.to_upper()

@export var value: String = "0.0":
	set(new_value):
		value = new_value
		if has_node("VBoxContainer/ValueLabel"):
			$VBoxContainer/ValueLabel.text = new_value

@export var unit: String = "unit":
	set(new_unit):
		unit = new_unit
		if has_node("VBoxContainer/UnitLabel"):
			$VBoxContainer/UnitLabel.text = new_unit

@export_enum("Red", "Green", "Blue") var color_category: String = "Red":
	set(new_color):
		color_category = new_color
		_update_background_color()

# Color definitions matching the spec
const COLOR_RED = Color(0.41, 0.09, 0.09)      # #681818
const COLOR_GREEN = Color(0.11, 0.37, 0.13)    # #1b5e20
const COLOR_BLUE = Color(0.05, 0.28, 0.63)     # #0d47a1


func _ready() -> void:
	_update_background_color()
	_update_labels()


func _update_background_color() -> void:
	var stylebox = StyleBoxFlat.new()

	match color_category:
		"Red":
			stylebox.bg_color = COLOR_RED
		"Green":
			stylebox.bg_color = COLOR_GREEN
		"Blue":
			stylebox.bg_color = COLOR_BLUE
		_:
			stylebox.bg_color = COLOR_RED

	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4

	add_theme_stylebox_override("panel", stylebox)


func _update_labels() -> void:
	if has_node("VBoxContainer/TitleLabel"):
		$VBoxContainer/TitleLabel.text = title.to_upper()
	if has_node("VBoxContainer/ValueLabel"):
		$VBoxContainer/ValueLabel.text = value
	if has_node("VBoxContainer/UnitLabel"):
		$VBoxContainer/UnitLabel.text = unit


func set_data(new_title: String, new_value: String, new_unit: String, new_color: String = "Red") -> void:
	title = new_title
	value = new_value
	unit = new_unit
	color_category = new_color
