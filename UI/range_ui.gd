extends MarginContainer

signal rec_button_pressed
signal club_selected(club: String)
signal set_session(dir: String, player_name: String)

signal hit_shot(data)
signal set_env(data)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func set_data(data: Dictionary) -> void:
	$GridCanvas/Distance.set_data(data["Distance"])
	$GridCanvas/Carry.set_data(data["Carry"])
	$GridCanvas/Offline.set_data(data["Offline"])
	$GridCanvas/Apex.set_data(data["Apex"])
	$GridCanvas/VLA.set_data("%3.1f" % data["VLA"])
	$GridCanvas/HLA.set_data("%3.1f" % data["HLA"])


func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_session_recorder_recording_state(value: bool) -> void:
	if value:
		var red = Color(1.0, 0.0, 0.0, 1.0)
		$HBoxContainer/RecButton.text = "REC: On"
		$HBoxContainer/RecButton.set("theme_override_colors/font_color", red)
		$HBoxContainer/RecButton.tooltip_text = "Stop Recording Range Session"
		$SessionPopUp.open()
	else:
		var white = Color(1.0, 1.0, 1.0, 1.0)
		$HBoxContainer/RecButton.text = "REC: Off"
		$HBoxContainer/RecButton.set("theme_override_colors/font_color", white)
		$HBoxContainer/RecButton.tooltip_text = "Start Recording Range Session"


func _on_club_selector_club_selected(club: String) -> void:
	emit_signal("club_selected", club)


func _on_session_pop_up_dir_selected(dir: String, player_name: String) -> void:
	$HBoxContainer/PlayerName.text = player_name
	emit_signal("set_session", dir, player_name)
	pass # Replace with function body.



func _on_session_recorder_set_session(user: String, dir: String) -> void:
	$HBoxContainer/PlayerName.text = user
	$SessionPopUp.set_session_data(user, dir)


func _on_shot_injector_inject(data: Variant) -> void:
	emit_signal("hit_shot", data)

func _on_environment_settings_inject_env(data: Variant) -> void:
	emit_signal("set_env", data)

func _on_exit_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
