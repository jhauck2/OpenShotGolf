extends PanelContainer

signal toggle_settings_requested
signal close_settings_requested

var reset_spin_box : SpinBox = null
var temperature_spin_box : SpinBox = null
var altitude_spin_box : SpinBox = null
var surface_option : OptionButton = null
var tracer_count_spin_box : SpinBox = null
var ball_type_option : OptionButton = null


func _setup_spin_box(spin_box: SpinBox, setting: Setting, step: float) -> void:
	spin_box.set_block_signals(true)
	spin_box.step = step
	if setting.min_value != null:
		spin_box.min_value = setting.min_value
	if setting.max_value != null:
		spin_box.max_value = setting.max_value
	spin_box.value = setting.value
	spin_box.set_block_signals(false)
	
	if spin_box.value != setting.value:
		setting.set_value(spin_box.value)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	reset_spin_box = $MarginContainer/VBoxContainer/BallResetTimer/ResetSpinBox
	temperature_spin_box = $MarginContainer/VBoxContainer/Temperature/TemperatureSpinBox
	altitude_spin_box = $MarginContainer/VBoxContainer/Altitude/AltitudeSpinBox
	surface_option = $MarginContainer/VBoxContainer/SurfaceType/SurfaceOption
	ball_type_option = $MarginContainer/VBoxContainer/BallType/BallTypeOption
	tracer_count_spin_box = $MarginContainer/VBoxContainer/TracerCount/TracerCountSpinBox

	# Reset Timer Settings
	_setup_spin_box(reset_spin_box, GlobalSettings.range_settings.ball_reset_timer, 0.5)

	# Temperature Settings
	_setup_spin_box(temperature_spin_box, GlobalSettings.range_settings.temperature, 1.0)

	# Altitude Settings
	_setup_spin_box(altitude_spin_box, GlobalSettings.range_settings.altitude, 10.0)

	# Drag scale
	# Tracer count
	_setup_spin_box(tracer_count_spin_box, GlobalSettings.range_settings.shot_tracer_count, 1.0)

	# Surface type options
	surface_option.clear()
	surface_option.add_item("Fairway", Surface.SurfaceType.FAIRWAY)
	surface_option.add_item("Soft Fairway", Surface.SurfaceType.FAIRWAY_SOFT)
	surface_option.add_item("Rough", Surface.SurfaceType.ROUGH)
	surface_option.add_item("Firm", Surface.SurfaceType.FIRM)
	var surface_id: int = GlobalSettings.range_settings.surface_type.value
	var surface_index := surface_option.get_item_index(surface_id)
	if surface_index >= 0:
		surface_option.select(surface_index)

	# Ball type options
	if ball_type_option:
		ball_type_option.clear()
		ball_type_option.add_item("Standard", GolfBall.BallType.STANDARD)
		ball_type_option.add_item("Premium", GolfBall.BallType.PREMIUM)
		var ball_type_id: int = GlobalSettings.range_settings.ball_type.value
		var ball_type_index := ball_type_option.get_item_index(ball_type_id)
		if ball_type_index >= 0:
			ball_type_option.select(ball_type_index)

	GlobalSettings.range_settings.range_units.setting_changed.connect(update_units)

	# Initialize toggle button states
	$MarginContainer/VBoxContainer/Units/CheckButton.set_pressed_no_signal(
		GlobalSettings.range_settings.range_units.value == Enums.Units.METRIC
	)
	$MarginContainer/VBoxContainer/CameraFollow/CheckButton.set_pressed_no_signal(
		GlobalSettings.range_settings.camera_follow_mode.value
	)
	$MarginContainer/VBoxContainer/AutoBallReset/CheckButton.set_pressed_no_signal(
		GlobalSettings.range_settings.auto_ball_reset.value
	)
	$MarginContainer/VBoxContainer/ShotInjector/CheckButton.set_pressed_no_signal(
		GlobalSettings.range_settings.shot_injector_enabled.value
	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_settings_button_pressed() -> void:
	toggle_settings_requested.emit()


func _on_background_clicked(event: InputEvent) -> void:
	# Close the menu when clicking on the background
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_settings_requested.emit()


func _on_exit_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_units_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		GlobalSettings.range_settings.range_units.set_value(Enums.Units.METRIC)
	else:
		GlobalSettings.range_settings.range_units.set_value(Enums.Units.IMPERIAL)


func _on_camer_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.range_settings.camera_follow_mode.set_value(toggled_on)


func _on_auto_reset_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.range_settings.auto_ball_reset.set_value(toggled_on)


func _on_injector_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.range_settings.shot_injector_enabled.set_value(toggled_on)

func _on_reset_spin_box_value_changed(value: float) -> void:
	GlobalSettings.range_settings.ball_reset_timer.set_value(value)


func _on_temperature_spin_box_value_changed(value: float) -> void:
	GlobalSettings.range_settings.temperature.set_value(value)


func _on_altitude_spin_box_value_changed(value: float) -> void:
	GlobalSettings.range_settings.altitude.set_value(value)


func _on_drag_spin_box_value_changed(_value: float) -> void:
	pass


func _on_surface_option_item_selected(index: int) -> void:
	var id: int = surface_option.get_item_id(index)
	GlobalSettings.range_settings.surface_type.set_value(id)


func _on_tracer_count_spin_box_value_changed(value: float) -> void:
	GlobalSettings.range_settings.shot_tracer_count.set_value(int(value))


func _on_ball_type_option_item_selected(index: int) -> void:
	if ball_type_option == null: #If you remove, ball selection stops working in settings. Look at debug shot. 
		return
	var id: int = ball_type_option.get_item_id(index)
	GlobalSettings.range_settings.ball_type.set_value(id)


func update_units(value) -> void:
	const m2ft = 3.28084
	
	if value == Enums.Units.IMPERIAL:
		$MarginContainer/VBoxContainer/Temperature/Label2.text = "F"
		temperature_spin_box.value = GlobalSettings.range_settings.temperature.value*9/5 + 32
		GlobalSettings.range_settings.temperature.set_value(temperature_spin_box.value)
		
		$MarginContainer/VBoxContainer/Altitude/Label2.text = "ft"
		altitude_spin_box.value = GlobalSettings.range_settings.altitude.value*m2ft
		GlobalSettings.range_settings.altitude.set_value(altitude_spin_box.value)
	else:
		$MarginContainer/VBoxContainer/Temperature/Label2.text = "C"
		temperature_spin_box.value = (GlobalSettings.range_settings.temperature.value - 32) * 5/9
		GlobalSettings.range_settings.temperature.set_value(temperature_spin_box.value)
		
		$MarginContainer/VBoxContainer/Altitude/Label2.text = "m"
		altitude_spin_box.value = GlobalSettings.range_settings.altitude.value/m2ft
		GlobalSettings.range_settings.altitude.set_value(altitude_spin_box.value)
