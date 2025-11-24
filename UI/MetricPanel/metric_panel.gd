extends Control

## Reusable metric panel for Overview layout footer HUD
## Displays icon, values, and optional dynamic indicator

@export var main_icon: Texture2D:
	set(value):
		main_icon = value
		if has_node("MainIcon"):
			$MainIcon.texture = value

@export var dynamic_indicator: Texture2D:
	set(value):
		dynamic_indicator = value
		if has_node("DynamicIndicator"):
			$DynamicIndicator.texture = value
			$DynamicIndicator.visible = (value != null)

@export var main_value: String = "0":
	set(value):
		main_value = value
		if has_node("MainValueLabel"):
			$MainValueLabel.text = value

@export var secondary_value: String = "":
	set(value):
		secondary_value = value
		if has_node("SecondaryValueLabel"):
			$SecondaryValueLabel.text = value
			$SecondaryValueLabel.visible = (value != "")

@export var indicator_rotation: float = 0.0:
	set(value):
		indicator_rotation = value
		if has_node("DynamicIndicator"):
			$DynamicIndicator.rotation_degrees = value


func _ready() -> void:
	custom_minimum_size = Vector2(200, 100)
	_update_display()


func _update_display() -> void:
	if has_node("MainIcon") and main_icon:
		$MainIcon.texture = main_icon

	if has_node("DynamicIndicator"):
		if dynamic_indicator:
			$DynamicIndicator.texture = dynamic_indicator
			$DynamicIndicator.visible = true
			$DynamicIndicator.rotation_degrees = indicator_rotation
		else:
			$DynamicIndicator.visible = false

	if has_node("MainValueLabel"):
		$MainValueLabel.text = main_value

	if has_node("SecondaryValueLabel"):
		$SecondaryValueLabel.text = secondary_value
		$SecondaryValueLabel.visible = (secondary_value != "")


func set_metric_data(icon: Texture2D, main_val: String, secondary_val: String = "", indicator_tex: Texture2D = null, indicator_rot: float = 0.0) -> void:
	main_icon = icon
	main_value = main_val
	secondary_value = secondary_val
	dynamic_indicator = indicator_tex
	indicator_rotation = indicator_rot
