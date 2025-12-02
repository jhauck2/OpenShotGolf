extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var button = get_node("%CameraCheckButton")
	button.button_pressed = GlobalSettings.range_settings.camera_follow_mode.value
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(_on_setting_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.range_settings.camera_follow_mode.set_value(toggled_on)

func _on_setting_changed(value: bool) -> void:
	get_node("%CameraCheckButton").button_pressed = value
