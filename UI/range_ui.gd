extends MarginContainer

signal rec_button_pressed
signal club_selected(club: String)
signal set_session(dir: String, player_name: String)
signal toggle_overlay_pressed

signal hit_shot(data)

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

	# Set points if it exists (target practice mode)
	if has_node("GridCanvas/Points"):
		$GridCanvas/Points.set_data(str(data.get("Points", "---")))


func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_session_recorder_recording_state(value: bool) -> void:
	# The REC button is now in the unified header
	# Check both the old path and the new unified header path
	var rec_button = null

	# Try old path first (for backward compatibility)
	if has_node("HBoxContainer/RecButton"):
		rec_button = $HBoxContainer/RecButton
	# Try new unified header path
	elif get_parent() and get_parent().has_node("UnifiedHeader") and get_parent().get_node("UnifiedHeader").has_node("rec_button"):
		rec_button = get_parent().get_node("UnifiedHeader").rec_button

	if rec_button:
		if value:
			var red = Color(1.0, 0.0, 0.0, 1.0)
			rec_button.text = "REC: On"
			rec_button.set("theme_override_colors/font_color", red)
			rec_button.tooltip_text = "Stop Recording Range Session"
			if has_node("SessionPopUp"):
				$SessionPopUp.open()
		else:
			var white = Color(1.0, 1.0, 1.0, 1.0)
			rec_button.text = "REC: Off"
			rec_button.set("theme_override_colors/font_color", white)
			rec_button.tooltip_text = "Start Recording Range Session"


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


func _on_exit_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_toggle_overlay_button_pressed() -> void:
	emit_signal("toggle_overlay_pressed")
