extends PanelContainer

signal toggle_settings_requested
signal close_settings_requested

var reset_spin_box : SpinBox = null
var temperature_spin_box : SpinBox = null
var altitude_spin_box : SpinBox = null
var drag_spin_box : SpinBox = null
var surface_option : OptionButton = null
var tracer_count_spin_box : SpinBox = null


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
	drag_spin_box = $MarginContainer/VBoxContainer/DragScale/DragSpinBox
	surface_option = $MarginContainer/VBoxContainer/SurfaceType/SurfaceOption
	tracer_count_spin_box = $MarginContainer/VBoxContainer/TracerCount/TracerCountSpinBox

	# Reset Timer Settings
	_setup_spin_box(reset_spin_box, GlobalSettings.range_settings.ball_reset_timer, 0.5)

	# Temperature Settings
	_setup_spin_box(temperature_spin_box, GlobalSettings.range_settings.temperature, 1.0)

	# Altitude Settings
	_setup_spin_box(altitude_spin_box, GlobalSettings.range_settings.altitude, 10.0)

	# Drag scale
	_setup_spin_box(drag_spin_box, GlobalSettings.range_settings.drag_scale, 0.5)

	# Tracer count
	_setup_spin_box(tracer_count_spin_box, GlobalSettings.range_settings.shot_tracer_count, 1.0)

	# Surface type options
	surface_option.clear()
	surface_option.add_item("Fairway", Enums.Surface.FAIRWAY)
	surface_option.add_item("Rough", Enums.Surface.ROUGH)
	surface_option.add_item("Firm", Enums.Surface.FIRM)
	surface_option.select(GlobalSettings.range_settings.surface_type.value)

	GlobalSettings.range_settings.range_units.setting_changed.connect(update_units)


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


func _on_drag_spin_box_value_changed(value: float) -> void:
	GlobalSettings.range_settings.drag_scale.set_value(value)


func _on_surface_option_item_selected(index: int) -> void:
	var id: int = surface_option.get_item_id(index)
	GlobalSettings.range_settings.surface_type.set_value(id)


func _on_tracer_count_spin_box_value_changed(value: float) -> void:
	GlobalSettings.range_settings.shot_tracer_count.set_value(int(value))


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
