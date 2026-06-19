extends PanelContainer

signal toggle_settings_requested
signal close_settings_requested

var reset_spin_box : SpinBox = null
var temperature_spin_box : SpinBox = null
var altitude_spin_box : SpinBox = null
var surface_option : OptionButton = null
var tracer_count_spin_box : SpinBox = null
var ball_type_option : OptionButton = null
var square_enabled_button : CheckButton = null
var square_device_option : OptionButton = null
var square_scan_button : Button = null
var square_connect_button : Button = null
var square_disconnect_button : Button = null
var square_ready_button : Button = null
var square_status_label : Label = null
var square_battery_label : Label = null
var square_firmware_label : Label = null
var square_club_option : OptionButton = null
var square_handedness_option : OptionButton = null

const SQUARE_UI_LOG_PREFIX := "[SquareUI]"
const SQUARE_CLUBS := {
	"Driver": "0204",
	"Putter": "0107",
	"3 Wood": "0305",
	"5 Wood": "0505",
	"7 Wood": "0705",
	"4 Iron": "0406",
	"5 Iron": "0506",
	"6 Iron": "0606",
	"7 Iron": "0706",
	"8 Iron": "0806",
	"9 Iron": "0906",
	"PW": "0a06",
	"LW": "0b06",
	"SW": "0c06"
}


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


func _ready() -> void:
	reset_spin_box = $MarginContainer/VBoxContainer/BallResetTimer/ResetSpinBox
	temperature_spin_box = $MarginContainer/VBoxContainer/Temperature/TemperatureSpinBox
	altitude_spin_box = $MarginContainer/VBoxContainer/Altitude/AltitudeSpinBox
	surface_option = $MarginContainer/VBoxContainer/SurfaceType/SurfaceOption
	ball_type_option = $MarginContainer/VBoxContainer/BallType/BallTypeOption
	tracer_count_spin_box = $MarginContainer/VBoxContainer/TracerCount/TracerCountSpinBox

	_setup_spin_box(reset_spin_box, GlobalSettingsManager.range_settings.ball_reset_timer, 0.5)
	_setup_spin_box(temperature_spin_box, GlobalSettingsManager.range_settings.temperature, 1.0)
	_setup_spin_box(altitude_spin_box, GlobalSettingsManager.range_settings.altitude, 10.0)
	_setup_spin_box(tracer_count_spin_box, GlobalSettingsManager.range_settings.shot_tracer_count, 1.0)

	surface_option.clear()
	surface_option.add_item("Fairway", PhysicsEnums.SurfaceType.FAIRWAY)
	surface_option.add_item("Soft Fairway", PhysicsEnums.SurfaceType.FAIRWAY_SOFT)
	surface_option.add_item("Rough", PhysicsEnums.SurfaceType.ROUGH)
	surface_option.add_item("Firm", PhysicsEnums.SurfaceType.FIRM)
	var surface_id: int = GlobalSettingsManager.range_settings.surface_type.value
	var surface_index := surface_option.get_item_index(surface_id)
	if surface_index >= 0:
		surface_option.select(surface_index)

	if ball_type_option:
		ball_type_option.clear()
		ball_type_option.add_item("Standard", GolfBall.BallType.STANDARD)
		ball_type_option.add_item("Premium", GolfBall.BallType.PREMIUM)
		var ball_type_id: int = GlobalSettingsManager.range_settings.ball_type.value
		var ball_type_index := ball_type_option.get_item_index(ball_type_id)
		if ball_type_index >= 0:
			ball_type_option.select(ball_type_index)

	GlobalSettingsManager.range_settings.range_units.setting_changed.connect(update_units)

	$MarginContainer/VBoxContainer/Units/CheckButton.set_pressed_no_signal(
		GlobalSettingsManager.range_settings.range_units.value == PhysicsEnums.Units.METRIC
	)
	$MarginContainer/VBoxContainer/CameraFollow/CheckButton.set_pressed_no_signal(
		GlobalSettingsManager.range_settings.camera_follow_mode.value
	)
	$MarginContainer/VBoxContainer/AutoBallReset/CheckButton.set_pressed_no_signal(
		GlobalSettingsManager.range_settings.auto_ball_reset.value
	)
	$MarginContainer/VBoxContainer/ShotInjector/CheckButton.set_pressed_no_signal(
		GlobalSettingsManager.app_settings.test_shots_enabled.value
	)
	_setup_square_monitor_section()


func _exit_tree() -> void:
	var units_setting := GlobalSettingsManager.range_settings.range_units
	if units_setting.setting_changed.is_connected(update_units):
		units_setting.setting_changed.disconnect(update_units)


func _on_settings_button_pressed() -> void:
	toggle_settings_requested.emit()


func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_settings_requested.emit()


func _on_exit_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_units_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		GlobalSettingsManager.range_settings.range_units.set_value(PhysicsEnums.Units.METRIC)
	else:
		GlobalSettingsManager.range_settings.range_units.set_value(PhysicsEnums.Units.IMPERIAL)


func _on_camer_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettingsManager.range_settings.camera_follow_mode.set_value(toggled_on)


func _on_auto_reset_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettingsManager.range_settings.auto_ball_reset.set_value(toggled_on)


func _on_injector_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettingsManager.app_settings.test_shots_enabled.set_value(toggled_on)


func _on_reset_spin_box_value_changed(value: float) -> void:
	GlobalSettingsManager.range_settings.ball_reset_timer.set_value(value)


func _on_temperature_spin_box_value_changed(value: float) -> void:
	GlobalSettingsManager.range_settings.temperature.set_value(value)


func _on_altitude_spin_box_value_changed(value: float) -> void:
	GlobalSettingsManager.range_settings.altitude.set_value(value)


func _on_drag_spin_box_value_changed(_value: float) -> void:
	pass


func _on_surface_option_item_selected(index: int) -> void:
	var id: int = surface_option.get_item_id(index)
	GlobalSettingsManager.range_settings.surface_type.set_value(id)


func _on_tracer_count_spin_box_value_changed(value: float) -> void:
	GlobalSettingsManager.range_settings.shot_tracer_count.set_value(int(value))


func _on_ball_type_option_item_selected(index: int) -> void:
	if ball_type_option == null:
		return
	var id: int = ball_type_option.get_item_id(index)
	GlobalSettingsManager.range_settings.ball_type.set_value(id)


func _setup_square_monitor_section() -> void:
	if not has_node("/root/LaunchMonitorManager"):
		_square_debug("LaunchMonitorManager singleton not found; Square section not created.")
		return

	var launch_monitor = get_node("/root/LaunchMonitorManager")
	_square_debug("Creating Square settings section. Initial status=%s" % str(launch_monitor.status))
	var root := $MarginContainer/VBoxContainer
	var section := VBoxContainer.new()
	section.name = "SquareMonitor"
	section.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Square"
	title.add_theme_font_size_override("font_size", 18)
	section.add_child(title)

	var enabled_row := HBoxContainer.new()
	enabled_row.add_child(_make_label("Enabled"))
	enabled_row.add_child(_make_spacer())
	square_enabled_button = CheckButton.new()
	square_enabled_button.set_pressed_no_signal(bool(GlobalSettingsManager.app_settings.launch_monitor_enabled.value))
	square_enabled_button.toggled.connect(_on_square_enabled_toggled)
	enabled_row.add_child(square_enabled_button)
	section.add_child(enabled_row)

	var device_row := HBoxContainer.new()
	device_row.add_child(_make_label("Device"))
	square_device_option = OptionButton.new()
	square_device_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_row.add_child(square_device_option)
	section.add_child(device_row)

	var action_row := HBoxContainer.new()
	square_scan_button = Button.new()
	square_scan_button.text = "Scan"
	square_scan_button.pressed.connect(_on_square_scan_pressed)
	action_row.add_child(square_scan_button)
	square_connect_button = Button.new()
	square_connect_button.text = "Connect"
	square_connect_button.pressed.connect(_on_square_connect_pressed)
	action_row.add_child(square_connect_button)
	square_disconnect_button = Button.new()
	square_disconnect_button.text = "Disconnect"
	square_disconnect_button.pressed.connect(_on_square_disconnect_pressed)
	action_row.add_child(square_disconnect_button)
	square_ready_button = Button.new()
	square_ready_button.text = "Ready"
	square_ready_button.pressed.connect(_on_square_ready_pressed)
	action_row.add_child(square_ready_button)
	section.add_child(action_row)

	var club_row := HBoxContainer.new()
	club_row.add_child(_make_label("Club"))
	square_club_option = OptionButton.new()
	square_club_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for club_name in SQUARE_CLUBS.keys():
		var index := square_club_option.item_count
		square_club_option.add_item(club_name)
		square_club_option.set_item_metadata(index, SQUARE_CLUBS[club_name])
	var current_club: String = launch_monitor.get_square_club_code()
	_select_option_by_metadata(square_club_option, current_club)
	square_club_option.item_selected.connect(_on_square_club_selected)
	club_row.add_child(square_club_option)
	section.add_child(club_row)

	var handedness_row := HBoxContainer.new()
	handedness_row.add_child(_make_label("Handedness"))
	square_handedness_option = OptionButton.new()
	square_handedness_option.add_item("Right", 0)
	square_handedness_option.add_item("Left", 1)
	var handedness: int = launch_monitor.get_square_handedness()
	var hand_index := square_handedness_option.get_item_index(handedness)
	if hand_index >= 0:
		square_handedness_option.select(hand_index)
	square_handedness_option.item_selected.connect(_on_square_handedness_selected)
	handedness_row.add_child(square_handedness_option)
	section.add_child(handedness_row)

	square_status_label = Label.new()
	square_battery_label = Label.new()
	square_firmware_label = Label.new()
	section.add_child(square_status_label)
	section.add_child(square_battery_label)
	section.add_child(square_firmware_label)

	var exit_button = root.get_node_or_null("ExitButton")
	root.add_child(section)
	if exit_button != null:
		root.move_child(section, exit_button.get_index())

	launch_monitor.device_discovered.connect(_on_square_device_discovered)
	launch_monitor.status_changed.connect(_on_square_status_changed)
	launch_monitor.error_occurred.connect(_on_square_error_occurred)
	launch_monitor.battery_changed.connect(_on_square_battery_changed)
	launch_monitor.firmware_changed.connect(_on_square_firmware_changed)
	launch_monitor.ready_changed.connect(_on_square_ready_changed)

	_refresh_square_devices()
	_update_square_status_labels()


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(90, 0)
	return label


func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _select_option_by_metadata(option: OptionButton, metadata: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == metadata:
			option.select(index)
			return


func _refresh_square_devices() -> void:
	if square_device_option == null or not has_node("/root/LaunchMonitorManager"):
		return
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	var selected_device: String = launch_monitor.get_selected_device_id()
	square_device_option.clear()
	for device_id in launch_monitor.devices.keys():
		var device = launch_monitor.devices[device_id]
		var label := str(device.get("name", "Square"))
		var index := square_device_option.item_count
		square_device_option.add_item(label)
		square_device_option.set_item_metadata(index, device_id)
		if device_id == selected_device:
			square_device_option.select(index)


func _update_square_status_labels() -> void:
	if not has_node("/root/LaunchMonitorManager") or square_status_label == null:
		return
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	square_status_label.text = "Status: %s" % launch_monitor.status
	if int(launch_monitor.battery_level) >= 0:
		square_battery_label.text = "Battery: %d%%" % int(launch_monitor.battery_level)
	else:
		square_battery_label.text = "Battery: --"
	if str(launch_monitor.firmware) != "":
		square_firmware_label.text = "Firmware: %s" % str(launch_monitor.firmware)
	else:
		square_firmware_label.text = "Firmware: --"


func _on_square_enabled_toggled(toggled_on: bool) -> void:
	_square_debug("Enabled toggled: %s" % str(toggled_on))
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	launch_monitor.set_enabled(toggled_on)
	if not toggled_on:
		launch_monitor.disconnect_device()


func _on_square_scan_pressed() -> void:
	_square_debug("Scan pressed")
	get_node("/root/LaunchMonitorManager").start_scan()


func _on_square_connect_pressed() -> void:
	if square_device_option == null or square_device_option.item_count == 0:
		_square_debug("Connect pressed with no selectable device.")
		return
	var index := square_device_option.selected
	var device_id := str(square_device_option.get_item_metadata(index))
	_square_debug("Connect pressed for device_id=%s" % device_id)
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	launch_monitor.set_enabled(true)
	square_enabled_button.set_pressed_no_signal(true)
	launch_monitor.connect_to_device(device_id)


func _on_square_disconnect_pressed() -> void:
	_square_debug("Disconnect pressed")
	get_node("/root/LaunchMonitorManager").disconnect_device()


func _on_square_ready_pressed() -> void:
	_square_debug("Ready pressed")
	get_node("/root/LaunchMonitorManager").set_ready()


func _on_square_club_selected(index: int) -> void:
	var club_code := str(square_club_option.get_item_metadata(index))
	get_node("/root/LaunchMonitorManager").set_club_code(club_code)


func _on_square_handedness_selected(index: int) -> void:
	var handedness := square_handedness_option.get_item_id(index)
	get_node("/root/LaunchMonitorManager").set_handedness(handedness)


func _on_square_device_discovered(_device_id: String, _name: String, _rssi: int) -> void:
	_square_debug("Device discovered event received")
	_refresh_square_devices()


func _on_square_status_changed(status: String) -> void:
	_square_debug("Status changed: %s" % status)
	_update_square_status_labels()


func _on_square_error_occurred(message: String) -> void:
	_square_debug("Error occurred: %s" % message)
	if square_status_label != null:
		square_status_label.text = "Status: %s" % message


func _on_square_battery_changed(_level: int) -> void:
	_update_square_status_labels()


func _on_square_firmware_changed(_firmware: String) -> void:
	_update_square_status_labels()


func _on_square_ready_changed(_is_ready: bool) -> void:
	_update_square_status_labels()


func _square_debug(message: String) -> void:
	print("%s %s" % [SQUARE_UI_LOG_PREFIX, message])


func update_units(value) -> void:
	const m2ft = 3.28084

	temperature_spin_box.set_block_signals(true)
	altitude_spin_box.set_block_signals(true)

	if value == PhysicsEnums.Units.IMPERIAL:
		$MarginContainer/VBoxContainer/Temperature/Label2.text = "F"
		var temp_f = GlobalSettingsManager.range_settings.temperature.value * 9.0 / 5.0 + 32.0
		temperature_spin_box.value = temp_f
		GlobalSettingsManager.range_settings.temperature.set_value(temp_f)

		$MarginContainer/VBoxContainer/Altitude/Label2.text = "ft"
		var alt_ft = GlobalSettingsManager.range_settings.altitude.value * m2ft
		altitude_spin_box.value = alt_ft
		GlobalSettingsManager.range_settings.altitude.set_value(alt_ft)
	else:
		$MarginContainer/VBoxContainer/Temperature/Label2.text = "C"
		var temp_c = (GlobalSettingsManager.range_settings.temperature.value - 32.0) * 5.0 / 9.0
		temperature_spin_box.value = temp_c
		GlobalSettingsManager.range_settings.temperature.set_value(temp_c)

		$MarginContainer/VBoxContainer/Altitude/Label2.text = "m"
		var alt_m = GlobalSettingsManager.range_settings.altitude.value / m2ft
		altitude_spin_box.value = alt_m
		GlobalSettingsManager.range_settings.altitude.set_value(alt_m)

	temperature_spin_box.set_block_signals(false)
	altitude_spin_box.set_block_signals(false)
