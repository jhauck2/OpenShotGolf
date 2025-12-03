extends HBoxContainer

signal layout_switch_pressed
signal camera_pressed
signal rec_button_pressed
signal exit_pressed
signal settings_pressed

func _ready() -> void:
	%LayoutButton.pressed.connect(_on_layout_button_pressed)
	%CameraButton.pressed.connect(_on_camera_button_pressed)
	%RecButton.pressed.connect(_on_rec_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%ExitButton.pressed.connect(_on_exit_button_pressed)

func _on_layout_button_pressed() -> void:
	EventBus.layout_changed.emit("next_layout")

func _on_camera_button_pressed() -> void:
	camera_pressed.emit()
	EventBus.camera_changed.emit(0)

func _on_rec_button_pressed() -> void:
	rec_button_pressed.emit()

func _on_settings_button_pressed() -> void:
	settings_pressed.emit()

func _on_exit_button_pressed() -> void:
	exit_pressed.emit()
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")

func set_recording_state(is_recording: bool) -> void:
		if is_recording:
			%RecButton.text = "REC: On"
			%RecButton.add_theme_color_override("font_color", Color.RED)
		else:
			%RecButton.text = "REC: Off"
			%RecButton.remove_theme_color_override("font_color")

func set_player_name(player_name: String) -> void:
	%PlayerName.text = player_name
