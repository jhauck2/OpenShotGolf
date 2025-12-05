extends MarginContainer

signal rec_button_pressed
signal set_session(dir: String, player_name: String)

signal hit_shot(data)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSettings.range_settings.shot_injector_enabled.setting_changed.connect(toggle_shot_injector)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func set_data(data: Dictionary) -> void:
	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		$GridCanvas/Distance.set_data(data["Distance"])
		$GridCanvas/Carry.set_data(data["Carry"])
		$GridCanvas/Side.set_data(data["Offline"])
		$GridCanvas/Apex.set_data(data["Apex"])
		$GridCanvas/Speed.set_units("mph")
		$GridCanvas/Speed.set_data(str(data["Speed"]))
		$GridCanvas/BackSpin.set_units("rpm")
		$GridCanvas/BackSpin.set_data(str(data["BackSpin"]))
		$GridCanvas/SideSpin.set_units("rpm")
		$GridCanvas/SideSpin.set_data(str(data["SideSpin"]))
		$GridCanvas/TotalSpin.set_units("rpm")
		$GridCanvas/TotalSpin.set_data(str(data["TotalSpin"]))
		$GridCanvas/SpinAxis.set_units("deg")
		$GridCanvas/SpinAxis.set_data(str(data["SpinAxis"]))
		$GridCanvas/VLA.set_data("%3.1f" % data["VLA"])
		$GridCanvas/HLA.set_data("%3.1f" % data["HLA"])
	else:
		$GridCanvas/Distance.set_data(data["Distance"])
		$GridCanvas/Carry.set_data(data["Carry"])
		$GridCanvas/Side.set_data(data["Offline"])
		$GridCanvas/Apex.set_data(data["Apex"])
		$GridCanvas/Speed.set_units("m/s")
		$GridCanvas/Speed.set_data(str(data["Speed"]))
		$GridCanvas/BackSpin.set_units("rpm")
		$GridCanvas/BackSpin.set_data(str(data["BackSpin"]))
		$GridCanvas/SideSpin.set_units("rpm")
		$GridCanvas/SideSpin.set_data(str(data["SideSpin"]))
		$GridCanvas/TotalSpin.set_units("rpm")
		$GridCanvas/TotalSpin.set_data(str(data["TotalSpin"]))
		$GridCanvas/SpinAxis.set_units("deg")
		$GridCanvas/SpinAxis.set_data(str(data["SpinAxis"]))
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


func _on_session_pop_up_dir_selected(dir: String, player_name: String) -> void:
	$HBoxContainer/PlayerName.text = player_name
	emit_signal("set_session", dir, player_name)
	pass # Replace with function body.



func _on_session_recorder_set_session(user: String, dir: String) -> void:
	$HBoxContainer/PlayerName.text = user
	$SessionPopUp.set_session_data(user, dir)


func _on_shot_injector_inject(data: Variant) -> void:
	emit_signal("hit_shot", data)

func toggle_shot_injector(value) -> void:
	$ShotInjector.visible = value


func set_total_distance(text: String) -> void:
	if has_node("OverlayLayer/TotalDistanceOverlay"):
		$OverlayLayer/TotalDistanceOverlay.text = text
		$OverlayLayer/TotalDistanceOverlay.visible = true


func clear_total_distance() -> void:
	if has_node("OverlayLayer/TotalDistanceOverlay"):
		$OverlayLayer/TotalDistanceOverlay.visible = false
		$OverlayLayer/TotalDistanceOverlay.text = "Total Distance --"
