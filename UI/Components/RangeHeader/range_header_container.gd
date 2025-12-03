extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect header buttons to their respective functionality
	$RangeHeader.settings_pressed.connect(_on_settings_pressed)
	$RangeHeader.layout_switch_pressed.connect(_on_layout_pressed)
	$RangeHeader.camera_pressed.connect(_on_camera_pressed)
	$RangeHeader.rec_button_pressed.connect(_on_rec_button_pressed)
	$RangeHeader.exit_pressed.connect(_on_exit_button_pressed)

	# Connect session popup
	$SessionPopUp.dir_selected.connect(_on_session_popup_dir_selected)
	$SessionPopUp.session_cancelled.connect(_on_session_popup_cancelled)

	# Set player name from GlobalSettings
	$RangeHeader.set_player_name(GlobalSettings.player_name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_settings_pressed() -> void:
	$RangeSettings.visible = not $RangeSettings.visible

func _on_layout_pressed() -> void:
	EventBus.layout_changed.emit("next_layout")

func _on_camera_pressed() -> void:
	EventBus.camera_changed.emit(0)

func _on_rec_button_pressed() -> void:
	EventBus.recording_toggled.emit()

func _on_exit_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")

func _on_session_popup_dir_selected(dir: String, player_name: String) -> void:
	EventBus.session_started.emit(player_name, dir)

func _on_session_popup_cancelled() -> void:
	EventBus.recording_toggled.emit()

func open_session_popup(user: String, dir: String) -> void:
	$SessionPopUp.set_session_data(user, dir)
	$SessionPopUp.open()

func set_recording_state(is_recording: bool) -> void:
	$RangeHeader.set_recording_state(is_recording)

func set_player_name(player_name: String) -> void:
	$RangeHeader.set_player_name(player_name)
