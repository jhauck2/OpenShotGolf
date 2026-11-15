class_name LaunchMonitorConnectModal
extends Control

const FsxCsvMonitorClass = preload("res://addons/launch_monitors/fsx/fsx_csv_monitor.gd")

signal closed
signal skipped
signal connected_and_continued

@onready var modal_panel: PanelContainer = $CenterContainer/ModalPanel
@onready var close_header_button: Button = %CloseHeaderButton
@onready var tab_container: TabContainer = %TabContainer
@onready var bluetooth_tab: ScrollContainer = %BluetoothTab
@onready var other_tab: ScrollContainer = %OtherTab
@onready var encrypted_bt_tab: ScrollContainer = %EncryptedBtTab
@onready var bushnell_tab: ScrollContainer = %BushnellTab

# Bluetooth controls
@onready var device_type_option: OptionButton = %DeviceTypeOption
@onready var device_option: OptionButton = %DeviceOption
@onready var scan_button: Button = %ScanButton
@onready var connect_button: Button = %ConnectButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var status_label: Label = %StatusLabel
@onready var battery_label: Label = %BatteryLabel
@onready var hint_label: Label = %HintLabel
@onready var device_card: PanelContainer = %DeviceCard
@onready var status_card: PanelContainer = %StatusCard

# Encrypted Bluetooth controls
@onready var encrypted_select_card: PanelContainer = %EncryptedSelectCard
@onready var encrypted_form_card: PanelContainer = %EncryptedFormCard
@onready var encrypted_model_option: OptionButton = %EncryptedModelOption
@onready var encrypted_device_option: OptionButton = %EncryptedDeviceOption
@onready var encrypted_form_title: Label = %EncryptedFormTitle
@onready var encrypted_code_hbox: HBoxContainer = %EncryptedCodeHBox
@onready var encrypted_code_label: Label = %EncryptedCodeLabel
@onready var encrypted_code_input: LineEdit = %EncryptedCodeInput
@onready var encrypted_instructions_text: RichTextLabel = %EncryptedInstructionsText
@onready var encrypted_scan_button: Button = %EncryptedScanButton
@onready var encrypted_connect_button: Button = %EncryptedConnectButton
@onready var encrypted_disconnect_button: Button = %EncryptedDisconnectButton

# Bushnell GC3 / FSX CSV controls
@onready var bushnell_config_card: PanelContainer = %BushnellConfigCard
@onready var bushnell_status_card: PanelContainer = %BushnellStatusCard
@onready var bushnell_instructions_card: PanelContainer = %BushnellInstructionsCard
@onready var bushnell_csv_path_input: LineEdit = %BushnellCsvPathInput
@onready var bushnell_browse_button: Button = %BushnellBrowseButton
@onready var bushnell_autodetect_button: Button = %BushnellAutoDetectButton
@onready var bushnell_polling_option: OptionButton = %BushnellPollingOption
@onready var bushnell_status_text: Label = %BushnellStatusText
@onready var bushnell_last_shot_text: Label = %BushnellLastShotText
@onready var bushnell_test_shot_button: Button = %BushnellTestShotButton
@onready var bushnell_instructions_text: RichTextLabel = %BushnellInstructionsText
@onready var bushnell_connect_button: Button = %BushnellConnectButton
@onready var bushnell_disconnect_button: Button = %BushnellDisconnectButton
@onready var bushnell_file_dialog: FileDialog = %BushnellFileDialog

# Other / GSPro controls
@onready var other_device_option: OptionButton = %OtherDeviceOption
@onready var other_selector_card: PanelContainer = %OtherSelectorCard
@onready var network_config_card: PanelContainer = %NetworkConfigCard
@onready var port_49152_button: Button = %Port49152Button
@onready var port_921_button: Button = %Port921Button
@onready var network_port_spin_box: SpinBox = %NetworkPortSpinBox
@onready var ip_all_button: Button = %IpAllButton
@onready var ip_local_button: Button = %IpLocalButton
@onready var network_ip_input: LineEdit = %NetworkIpInput
@onready var lan_ip_label: Label = %LanIpLabel
@onready var network_info_card: PanelContainer = %NetworkInfoCard
@onready var host_label: RichTextLabel = %HostLabel
@onready var port_label: RichTextLabel = %PortLabel
@onready var protocol_label: RichTextLabel = %ProtocolLabel
@onready var instructions_card: PanelContainer = %InstructionsCard
@onready var instructions_text: RichTextLabel = %InstructionsText

# Footer controls
@onready var remember_device_checkbox: CheckBox = %RememberDeviceCheckBox
@onready var skip_button: Button = %SkipButton
@onready var continue_button: Button = %ContinueButton

var _launch_monitor: Node = null

const OTHER_DEVICE_GUIDES = {
	"mlm2pro": {
		"name": "Rapsodo MLM2PRO (MLM2PRO-GSPro-Connector)",
		"bridge": "MLM2PRO-GSPro-Connector (Community Bridge)",
		"text": "[b]Bridge Software:[/b] [color=#64b5f6]MLM2PRO-GSPro-Connector[/color] (by Springbok)\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Power on your [b]MLM2PRO[/b] and connect it to your PC or mobile bridge app.\n2. In the MLM2PRO connector settings, configure the [b]GSPro Host / IP[/b] to [b]127.0.0.1[/b] (or your PC's LAN IP if running on phone) and [b]Port[/b] to [b]49152[/b].\n3. Click [b]Connect[/b] in the connector app.\n4. Start any [b]Course[/b], [b]Driving Range[/b], or [b]Minigame[/b] in Heckle Golf Simulator (the TCP server on port 49152 starts automatically).\n5. Hit shots! Ball speed, launch angles, total spin, and spin axis will stream directly into the simulation."
	},
	"garmin_r10": {
		"name": "Garmin Approach R10 (Garmin R10 OpenConnect)",
		"bridge": "Garmin R10 OpenConnect / E6 to GSPro Bridge",
		"text": "[b]Bridge Software:[/b] [color=#64b5f6]Garmin R10 OpenConnect / E6 Bridge[/color]\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Turn on your [b]Garmin Approach R10[/b] and pair it with the Garmin Golf app or PC bridge.\n2. In your bridge settings, set the target IP address to [b]127.0.0.1[/b] (or PC local IP) and port to [b]49152[/b].\n3. Make sure your PC and mobile device are on the same Wi-Fi network.\n4. Load into any Range or Course in Heckle Golf Simulator.\n5. Take a swing — radar metrics will trigger real-time ball flight and announcer commentary.\n\n[color=#81c784]💡 [b]Direct Bluetooth Tip:[/b] You can also connect directly via Bluetooth without any third-party bridge app on the [b]Bluetooth[/b] tab![/color]"
	},
	"flightscope": {
		"name": "FlightScope Mevo+ / X3 (GSPro Bridge)",
		"bridge": "FlightScope PC / Mobile Connector for GSPro",
		"text": "[b]Bridge Software:[/b] [color=#64b5f6]FlightScope GSPro Interface[/color]\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Connect your [b]Mevo+[/b] or [b]X3[/b] to your PC/tablet over Wi-Fi.\n2. In the FlightScope connector settings, set the GSPro destination IP to [b]127.0.0.1[/b] and port to [b]49152[/b].\n3. Open any Course or the Driving Range in Heckle Golf Simulator.\n4. Radar metrics will flow directly into OpenFairway physics with zero setup required."
	},
	"uneekor": {
		"name": "Uneekor (EYE XO / EYE XO2 / QED)",
		"bridge": "Uneekor Third-Party Connector (GSPro Mode)",
		"text": "[b]Bridge Software:[/b] [color=#64b5f6]Uneekor View / Ignite Connector[/color]\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Start the [b]Uneekor View[/b] software and enable Third-Party Connector / GSPro integration.\n2. Set the outbound destination socket to [b]127.0.0.1:49152[/b].\n3. Enter any Course or Range session in Heckle Golf Simulator.\n4. High-speed overhead optical camera data will trigger shots instantaneously."
	},
	"bushnell": {
		"name": "Bushnell Launch Pro / Foresight (GC3 / GCQuad)",
		"bridge": "Game Changer / GSPro Connect Tool",
		"text": "[b]Bridge Software:[/b] [color=#64b5f6]Game Changer / Foresight GSPro Connect[/color]\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Connect your [b]Bushnell Launch Pro[/b] or [b]Foresight GC3/GCQuad[/b] via USB, Ethernet, or Wi-Fi.\n2. In the connection tool, configure the forwarding socket to [b]127.0.0.1:49152[/b].\n3. Start your round or practice session in the simulator.\n4. Photometric ball data will be received and simulated in real time."
	},
	"pitrac": {
		"name": "PiTrac / Generic GSPro Open Connect v1",
		"bridge": "Any GSPro Open Connect v1 JSON TCP Client",
		"text": "[b]Bridge Software:[/b] [color=#64b5f6]PiTrac / Custom TCP Client[/color]\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Configure your client to connect to [b]127.0.0.1:49152[/b].\n2. Send standard JSON shot payloads:\n[code]{\"ShotDataOptions\": {\"ContainsBallData\": true}, \"BallData\": {\"Speed\": 150.0, \"SpinAxis\": 0.0, \"TotalSpin\": 2500.0, \"HLA\": 0.0, \"VLA\": 12.0}}[/code]\n3. The simulator receives the shot, simulates the flight, and replies with [code]{\"Code\": 200}[/code]."
	},
	"shot_injector": {
		"name": "Built-in Python Shot Injector (inject_shot.py)",
		"bridge": "inject_shot.py (in scripts/tools/)",
		"text": "[b]Utility:[/b] [color=#64b5f6]scripts/tools/inject_shot.py[/color]\n[b]Protocol:[/b] GSPro Open Connect v1 over TCP\n[b]Destination Host / Port:[/b] [color=#81c784]127.0.0.1 : 49152[/color]\n\n[b]Step-by-Step Instructions:[/b]\n1. Open Heckle Golf Simulator and go to [b]Range[/b] or start any [b]Course[/b].\n2. Open a terminal or command prompt in the HeckleGolfSim directory.\n3. Run: [code]python scripts/tools/inject_shot.py[/code]\n4. Pick a preset shot (Driver bomb, approach wedge, slice, hook, duff, putt) or type 9 for custom numbers.\n5. The shot will immediately launch in-game so you can test ball flight, camera angles, and announcer roasts without hardware!"
	}
}


func _ready() -> void:
	add_to_group("modals")
	if has_node("/root/UIFocusGuard"):
		get_node("/root/UIFocusGuard").push_lock(self)

	# Apply Design System
	if modal_panel != null:
		ThemeManager.apply_modal_style(modal_panel, 14)
	if device_card != null:
		ThemeManager.apply_card_panel_style(device_card, false, 10, 14, 14, 14, 14)
	if status_card != null:
		ThemeManager.apply_card_panel_style(status_card, false, 10, 14, 12, 14, 12)
	if other_selector_card != null:
		ThemeManager.apply_card_panel_style(other_selector_card, false, 10, 14, 14, 14, 14)
	if network_config_card != null:
		ThemeManager.apply_card_panel_style(network_config_card, false, 10, 14, 14, 14, 14)
	if instructions_card != null:
		ThemeManager.apply_card_panel_style(instructions_card, false, 10, 14, 14, 14, 14)
	if encrypted_select_card != null:
		ThemeManager.apply_card_panel_style(encrypted_select_card, false, 10, 14, 14, 14, 14)
	if encrypted_form_card != null:
		ThemeManager.apply_card_panel_style(encrypted_form_card, false, 10, 14, 14, 14, 14)
	if bushnell_config_card != null:
		ThemeManager.apply_card_panel_style(bushnell_config_card, false, 10, 14, 14, 14, 14)
	if bushnell_status_card != null:
		ThemeManager.apply_card_panel_style(bushnell_status_card, false, 10, 14, 14, 14, 14)
	if bushnell_instructions_card != null:
		ThemeManager.apply_card_panel_style(bushnell_instructions_card, false, 10, 14, 14, 14, 14)

	# Responsive modal sizing
	var viewport_size = get_viewport().get_visible_rect().size
	var target_width = clamp(viewport_size.x * 0.82, 620.0, 860.0)
	var target_height = clamp(viewport_size.y * 0.82, 440.0, 700.0)
	modal_panel.custom_minimum_size = Vector2(target_width, target_height)

	# Style TabContainer
	if tab_container != null:
		tab_container.clip_tabs = false
		var tab_bar = tab_container.get_tab_bar()
		if tab_bar != null:
			tab_bar.clip_tabs = false
		tab_container.add_theme_font_size_override("font_size", 15)
		tab_container.add_theme_constant_override("side_margin", 4)
		tab_container.add_theme_stylebox_override("tab_selected", _create_tab_style(ThemeManager.COLOR_PRIMARY_NORMAL, ThemeManager.COLOR_PRIMARY_NORMAL.lightened(0.2)))
		tab_container.add_theme_stylebox_override("tab_unselected", _create_tab_style(ThemeManager.COLOR_NAV_NORMAL, Color(1, 1, 1, 0.15)))
		tab_container.add_theme_stylebox_override("tab_hovered", _create_tab_style(ThemeManager.COLOR_NAV_HOVER, Color(1, 1, 1, 0.3)))
		tab_container.set_tab_title(0, "📶 Bluetooth")
		tab_container.set_tab_title(1, "🌐 Other (GSPro)")
		tab_container.set_tab_title(2, "🔐 Encrypted BT")
		tab_container.set_tab_title(3, "⛳ Bushnell (FSX)")
		tab_container.current_tab = _get_saved_tab()
		tab_container.tab_changed.connect(_on_tab_changed)

	# Apply touch scroll styling
	if bluetooth_tab != null:
		ThemeManager.apply_scroll_container_style(bluetooth_tab, 24)
	if other_tab != null:
		ThemeManager.apply_scroll_container_style(other_tab, 24)
	if encrypted_bt_tab != null:
		ThemeManager.apply_scroll_container_style(encrypted_bt_tab, 24)
	if bushnell_tab != null:
		ThemeManager.apply_scroll_container_style(bushnell_tab, 24)

	# Setup buttons styling
	ThemeManager.apply_nav_button_style(close_header_button, 6)
	ThemeManager.apply_secondary_button_style(scan_button, 8)
	ThemeManager.apply_primary_button_style(connect_button, 8)
	ThemeManager.apply_danger_button_style(disconnect_button, 8)
	ThemeManager.apply_secondary_button_style(skip_button, 8)
	ThemeManager.apply_primary_button_style(continue_button, 8)

	ThemeManager.apply_secondary_button_style(encrypted_scan_button, 8)
	ThemeManager.apply_primary_button_style(encrypted_connect_button, 8)
	ThemeManager.apply_danger_button_style(encrypted_disconnect_button, 8)

	ThemeManager.apply_secondary_button_style(bushnell_browse_button, 8)
	ThemeManager.apply_secondary_button_style(bushnell_autodetect_button, 8)
	ThemeManager.apply_secondary_button_style(bushnell_test_shot_button, 8)
	ThemeManager.apply_primary_button_style(bushnell_connect_button, 8)
	ThemeManager.apply_danger_button_style(bushnell_disconnect_button, 8)

	_setup_touch_option_button(device_type_option)
	_setup_touch_option_button(device_option)
	_setup_touch_option_button(other_device_option)
	_setup_touch_option_button(encrypted_model_option)
	_setup_touch_option_button(encrypted_device_option)
	_setup_touch_option_button(bushnell_polling_option)
	if encrypted_code_input != null:
		ThemeManager.apply_input_style(encrypted_code_input, 8)
	if bushnell_csv_path_input != null:
		ThemeManager.apply_input_style(bushnell_csv_path_input, 8)

	# Button signal connections
	close_header_button.pressed.connect(_on_skip_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	scan_button.pressed.connect(_on_scan_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	device_option.item_selected.connect(_on_device_option_selected)

	encrypted_scan_button.pressed.connect(_on_encrypted_scan_pressed)
	encrypted_connect_button.pressed.connect(_on_encrypted_connect_pressed)
	encrypted_disconnect_button.pressed.connect(_on_encrypted_disconnect_pressed)
	encrypted_device_option.item_selected.connect(_on_encrypted_device_option_selected)
	encrypted_model_option.item_selected.connect(_on_encrypted_model_selected)

	if bushnell_browse_button != null:
		bushnell_browse_button.pressed.connect(_on_bushnell_browse_pressed)
	if bushnell_autodetect_button != null:
		bushnell_autodetect_button.pressed.connect(_on_bushnell_autodetect_pressed)
	if bushnell_connect_button != null:
		bushnell_connect_button.pressed.connect(_on_bushnell_connect_pressed)
	if bushnell_disconnect_button != null:
		bushnell_disconnect_button.pressed.connect(_on_bushnell_disconnect_pressed)
	if bushnell_test_shot_button != null:
		bushnell_test_shot_button.pressed.connect(_on_bushnell_test_shot_pressed)
	if bushnell_file_dialog != null:
		bushnell_file_dialog.file_selected.connect(_on_bushnell_file_selected)

	# Setup dropdowns & network settings
	_setup_device_type_dropdown()
	_setup_other_devices_dropdown()
	_setup_encrypted_devices_dropdown()
	_setup_bushnell_tab()
	_setup_network_config()

	if has_node("/root/LaunchMonitorManager"):
		_launch_monitor = get_node("/root/LaunchMonitorManager")
		if not _launch_monitor.device_discovered.is_connected(_on_device_discovered):
			_launch_monitor.device_discovered.connect(_on_device_discovered)
		if not _launch_monitor.status_changed.is_connected(_on_status_changed):
			_launch_monitor.status_changed.connect(_on_status_changed)
		if not _launch_monitor.error_occurred.is_connected(_on_error_occurred):
			_launch_monitor.error_occurred.connect(_on_error_occurred)
		if not _launch_monitor.battery_changed.is_connected(_on_battery_changed):
			_launch_monitor.battery_changed.connect(_on_battery_changed)
		if not _launch_monitor.ready_changed.is_connected(_on_ready_changed):
			_launch_monitor.ready_changed.connect(_on_ready_changed)

	if remember_device_checkbox != null:
		ThemeManager.apply_checkbox_style(remember_device_checkbox)
		var is_remembered := false
		if _launch_monitor != null:
			is_remembered = bool(_launch_monitor.settings.get("remember_device", false))
		remember_device_checkbox.button_pressed = is_remembered
		remember_device_checkbox.toggled.connect(_on_remember_device_toggled)

	if hint_label != null:
		if OS.get_name() == "Android":
			hint_label.text = "💡 Android Tip: The Garmin R10 will NOT show up in phone Bluetooth settings. Do NOT pair it in Android settings. Disconnect PC / Garmin Golf app, hold R10 power button until LED flashes BLUE, and click Scan here in the app."
		else:
			hint_label.text = "💡 Power on your launch monitor before scanning. For Garmin Approach R10, hold the power button until the LED flashes blue. On Windows, pair the device in Windows Bluetooth settings first."

	_refresh_devices()
	_update_status_display()

	if _launch_monitor != null and (_launch_monitor.status == "Disconnected" or _launch_monitor.status.contains("No launch monitors found")):
		_launch_monitor.start_scan()
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if continue_button != null and continue_button.visible and not continue_button.disabled:
		continue_button.grab_focus()
	elif skip_button != null and skip_button.visible:
		skip_button.grab_focus()
	elif close_header_button != null and close_header_button.visible:
		close_header_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_skip_pressed()
		get_viewport().set_input_as_handled()
	elif tab_container != null and tab_container.get_tab_count() > 0:
		if event.is_action_pressed("tab_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_Q):
			var prev_idx = (tab_container.current_tab - 1 + tab_container.get_tab_count()) % tab_container.get_tab_count()
			tab_container.current_tab = prev_idx
			_on_tab_changed(prev_idx)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("tab_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			var next_idx = (tab_container.current_tab + 1) % tab_container.get_tab_count()
			tab_container.current_tab = next_idx
			_on_tab_changed(next_idx)
			get_viewport().set_input_as_handled()


func _create_tab_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _setup_touch_option_button(opt: OptionButton) -> void:
	if opt == null:
		return
	ThemeManager.apply_option_button_style(opt, 18, Vector2(220, 52))


func _setup_device_type_dropdown() -> void:
	if device_type_option == null:
		return
	device_type_option.clear()
	device_type_option.add_item("Auto-Detect (Recommended)", 0)
	device_type_option.set_item_metadata(0, "auto")
	device_type_option.add_item("Square Golf", 1)
	device_type_option.set_item_metadata(1, "square")
	device_type_option.add_item("Garmin Approach R10", 2)
	device_type_option.set_item_metadata(2, "garmin")

	var current_type := "auto"
	if _launch_monitor != null:
		current_type = str(_launch_monitor.settings.get("device_type", "auto"))

	match current_type:
		"square": device_type_option.select(1)
		"garmin": device_type_option.select(2)
		_: device_type_option.select(0)

	device_type_option.item_selected.connect(_on_device_type_selected)


func _on_device_type_selected(index: int) -> void:
	if device_type_option == null or _launch_monitor == null:
		return
	var selected_type := str(device_type_option.get_item_metadata(index))
	_launch_monitor.set_device_type(selected_type)
	_refresh_devices()
	if _launch_monitor.status == "Scanning" or _launch_monitor.status.contains("Searching"):
		_launch_monitor.stop_scan()
		_launch_monitor.start_scan()


func _get_saved_tab() -> int:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "launch_monitor_tab" in gs.range_settings:
			return clampi(int(gs.range_settings.launch_monitor_tab.value), 0, 3)
	return 0


func _on_tab_changed(tab_index: int) -> void:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "launch_monitor_tab" in gs.range_settings:
			gs.range_settings.launch_monitor_tab.set_value(tab_index)
			gs.save_settings()
	var vp = get_viewport()
	var cur = vp.gui_get_focus_owner() if vp != null else null
	if cur is TabBar:
		return
	var current_ctrl = tab_container.get_current_tab_control() if tab_container != null else null
	if current_ctrl != null and has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		ufg.call_deferred("_focus_first_control", current_ctrl)


func _setup_other_devices_dropdown() -> void:
	if other_device_option == null:
		return
	
	other_device_option.clear()
	var keys = ["mlm2pro", "garmin_r10", "flightscope", "uneekor", "bushnell", "pitrac", "shot_injector"]
	var saved_device := "mlm2pro"
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "gspro_selected_device" in gs.range_settings:
			saved_device = str(gs.range_settings.gspro_selected_device.value)

	var selected_idx := 0
	for i in range(keys.size()):
		var key = keys[i]
		var info = OTHER_DEVICE_GUIDES[key]
		other_device_option.add_item(info["name"], i)
		other_device_option.set_item_metadata(i, key)
		if key == saved_device:
			selected_idx = i

	other_device_option.item_selected.connect(_on_other_device_selected)
	other_device_option.select(selected_idx)
	_on_other_device_selected(selected_idx)


func _setup_network_config() -> void:
	if port_49152_button != null:
		ThemeManager.apply_secondary_button_style(port_49152_button, 6)
		port_49152_button.pressed.connect(func(): _set_configured_port(49152))
	if port_921_button != null:
		ThemeManager.apply_secondary_button_style(port_921_button, 6)
		port_921_button.pressed.connect(func(): _set_configured_port(921))
	if ip_all_button != null:
		ThemeManager.apply_secondary_button_style(ip_all_button, 6)
		ip_all_button.pressed.connect(func(): _set_configured_ip("0.0.0.0"))
	if ip_local_button != null:
		ThemeManager.apply_secondary_button_style(ip_local_button, 6)
		ip_local_button.pressed.connect(func(): _set_configured_ip("127.0.0.1"))
	if network_ip_input != null:
		ThemeManager.apply_input_style(network_ip_input, 6)
		network_ip_input.text = _get_configured_ip()
		network_ip_input.text_changed.connect(_on_ip_text_changed)
		network_ip_input.text_submitted.connect(func(new_text: String): _set_configured_ip(new_text))
		network_ip_input.focus_exited.connect(func(): _set_configured_ip(network_ip_input.text))
	if network_port_spin_box != null:
		network_port_spin_box.min_value = 1
		network_port_spin_box.max_value = 65535
		network_port_spin_box.step = 1
		network_port_spin_box.value = _get_configured_port()
		var le = network_port_spin_box.get_line_edit()
		if le != null:
			ThemeManager.apply_input_style(le, 6)
		network_port_spin_box.value_changed.connect(func(val: float): _set_configured_port(int(val)))
	
	_update_network_display()


func _on_ip_text_changed(new_text: String) -> void:
	var trimmed = new_text.strip_edges()
	if trimmed.is_empty():
		trimmed = "0.0.0.0"
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "tcp_server_ip" in gs.range_settings:
			gs.range_settings.tcp_server_ip.set_value(trimmed)
			gs.save_settings()
	_notify_active_tcp_server()
	if other_device_option != null and other_device_option.selected >= 0:
		var key = str(other_device_option.get_item_metadata(other_device_option.selected))
		if instructions_text != null:
			instructions_text.text = _format_guide_text(key)


func _update_network_display() -> void:
	var port = _get_configured_port()
	var ip = _get_configured_ip()
	var lan_ip = _get_local_ip()

	if host_label != null:
		var host_display = ip if ip != "0.0.0.0" and ip != "*" else "0.0.0.0 (All Interfaces)"
		host_label.text = "🖥️ [b]Host:[/b] %s" % host_display
	if port_label != null:
		port_label.text = "🔌 [b]Port:[/b] %d (TCP)" % port
	if lan_ip_label != null:
		lan_ip_label.text = "💡 Local Network IP: [b]%s[/b] (use this in connector apps on the same Wi-Fi)" % lan_ip

	if network_port_spin_box != null and int(network_port_spin_box.value) != port:
		network_port_spin_box.set_value_no_signal(port)
	if network_ip_input != null and network_ip_input.text != ip:
		network_ip_input.text = ip

	# Highlight preset buttons
	if port_49152_button != null:
		if port == 49152:
			ThemeManager.apply_primary_button_style(port_49152_button, 6)
		else:
			ThemeManager.apply_secondary_button_style(port_49152_button, 6)
	if port_921_button != null:
		if port == 921:
			ThemeManager.apply_primary_button_style(port_921_button, 6)
		else:
			ThemeManager.apply_secondary_button_style(port_921_button, 6)
	if ip_all_button != null:
		if ip == "0.0.0.0" or ip == "*":
			ThemeManager.apply_primary_button_style(ip_all_button, 6)
		else:
			ThemeManager.apply_secondary_button_style(ip_all_button, 6)
	if ip_local_button != null:
		if ip == "127.0.0.1":
			ThemeManager.apply_primary_button_style(ip_local_button, 6)
		else:
			ThemeManager.apply_secondary_button_style(ip_local_button, 6)

	if other_device_option != null and other_device_option.selected >= 0:
		var key = str(other_device_option.get_item_metadata(other_device_option.selected))
		if instructions_text != null:
			instructions_text.text = _format_guide_text(key)


func _format_guide_text(key: String) -> String:
	if not OTHER_DEVICE_GUIDES.has(key):
		return ""
	var text: String = OTHER_DEVICE_GUIDES[key]["text"]
	var port = _get_configured_port()
	var ip = _get_configured_ip()
	var lan_ip = _get_local_ip()
	var display_host = ip if ip != "0.0.0.0" and ip != "*" else "127.0.0.1"

	# Dynamically replace 49152 and 127.0.0.1 with user settings
	text = text.replace("127.0.0.1 : 49152", "%s : %d" % [display_host, port])
	text = text.replace("127.0.0.1:49152", "%s:%d" % [display_host, port])
	text = text.replace("port 49152", "port %d" % port)
	text = text.replace("Port[/b] to [b]49152[/b]", "Port[/b] to [b]%d[/b]" % port)
	text = text.replace("port to [b]49152[/b]", "port to [b]%d[/b]" % port)
	text = text.replace("port to [b]49152", "port to [b]%d" % port)
	if lan_ip != "127.0.0.1":
		text = text.replace("(or your PC's LAN IP if running on phone)", "(or your PC's LAN IP: [b]%s[/b])" % lan_ip)
		text = text.replace("(or PC local IP)", "(or PC local IP: [b]%s[/b])" % lan_ip)
	return text


func _get_configured_port() -> int:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "tcp_server_port" in gs.range_settings:
			return int(gs.range_settings.tcp_server_port.value)
	return 49152


func _get_configured_ip() -> String:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "tcp_server_ip" in gs.range_settings:
			return str(gs.range_settings.tcp_server_ip.value)
	return "0.0.0.0"


func _set_configured_port(new_port: int) -> void:
	new_port = clampi(new_port, 1, 65535)
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "tcp_server_port" in gs.range_settings:
			gs.range_settings.tcp_server_port.set_value(new_port)
			gs.save_settings()
	_notify_active_tcp_server()
	_update_network_display()


func _set_configured_ip(new_ip: String) -> void:
	new_ip = new_ip.strip_edges()
	if new_ip.is_empty():
		new_ip = "0.0.0.0"
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "tcp_server_ip" in gs.range_settings:
			gs.range_settings.tcp_server_ip.set_value(new_ip)
			gs.save_settings()
	_notify_active_tcp_server()
	_update_network_display()


func _save_network_preferences() -> void:
	if network_ip_input != null:
		var ip_val = network_ip_input.text.strip_edges()
		if ip_val.is_empty():
			ip_val = "0.0.0.0"
		if has_node("/root/GlobalSettings"):
			var gs = get_node("/root/GlobalSettings")
			if gs.get("range_settings") != null and "tcp_server_ip" in gs.range_settings:
				gs.range_settings.tcp_server_ip.set_value(ip_val)
	if network_port_spin_box != null:
		var port_val = clampi(int(network_port_spin_box.value), 1, 65535)
		if has_node("/root/GlobalSettings"):
			var gs = get_node("/root/GlobalSettings")
			if gs.get("range_settings") != null and "tcp_server_port" in gs.range_settings:
				gs.range_settings.tcp_server_port.set_value(port_val)
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		gs.save_settings()
	_notify_active_tcp_server()


func _notify_active_tcp_server() -> void:
	var root = get_tree().root
	var tcp_server = root.find_child("TCPServer", true, false)
	if tcp_server != null and tcp_server.has_method("Restart"):
		tcp_server.call("Restart", _get_configured_port(), _get_configured_ip())


func _get_local_ip() -> String:
	for address in IP.get_local_addresses():
		if not address.contains(":") and not address.begins_with("127.") and not address.begins_with("169.254."):
			return address
	return "127.0.0.1"


func _on_other_device_selected(index: int) -> void:
	if other_device_option == null or instructions_text == null:
		return
	var key = str(other_device_option.get_item_metadata(index))
	instructions_text.text = _format_guide_text(key)
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "gspro_selected_device" in gs.range_settings:
			gs.range_settings.gspro_selected_device.set_value(key)
			gs.save_settings()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if modal_panel != null and not modal_panel.get_global_rect().has_point(mouse_pos):
			_on_skip_pressed()


func _on_skip_pressed() -> void:
	if remember_device_checkbox != null and _launch_monitor != null:
		var is_remember := remember_device_checkbox.button_pressed
		_launch_monitor.settings["remember_device"] = is_remember
		if is_remember:
			_save_current_device_selection()
		else:
			_launch_monitor._save_settings()
	_save_network_preferences()
	skipped.emit()
	closed.emit()
	queue_free()


func _on_continue_pressed() -> void:
	if remember_device_checkbox != null and _launch_monitor != null:
		var is_remember := remember_device_checkbox.button_pressed
		_launch_monitor.settings["remember_device"] = is_remember
		if is_remember:
			_save_current_device_selection()
		else:
			_launch_monitor._save_settings()
	_save_network_preferences()
	connected_and_continued.emit()
	closed.emit()
	queue_free()


func _on_remember_device_toggled(toggled_on: bool) -> void:
	if _launch_monitor == null:
		return
	_launch_monitor.settings["remember_device"] = toggled_on
	if toggled_on:
		_save_current_device_selection()
	else:
		_launch_monitor._save_settings()


func _save_current_device_selection() -> void:
	if _launch_monitor == null:
		return
	if tab_container != null and tab_container.current_tab == 3:
		var path = bushnell_csv_path_input.text.strip_edges() if bushnell_csv_path_input != null else ""
		_launch_monitor.settings["device_id"] = "bushnell_fsx_csv"
		_launch_monitor.settings["device_name"] = "Bushnell GC3 (FSX)"
		_launch_monitor.settings["device_type"] = "bushnell_fsx"
		_launch_monitor.settings["fsx_csv_path"] = path
		_launch_monitor.settings["enabled"] = true
		_launch_monitor._save_settings()
		if has_node("/root/GlobalSettings"):
			var gs = get_node("/root/GlobalSettings")
			if gs.get("range_settings") != null and "fsx_csv_path" in gs.range_settings:
				gs.range_settings.fsx_csv_path.set_value(path)
				gs.save_settings()
		return
	if device_option != null and device_option.item_count > 0:
		var index := device_option.selected
		if index < 0:
			index = 0
		var dev_id := str(device_option.get_item_metadata(index))
		if dev_id != "":
			_launch_monitor.settings["device_id"] = dev_id
			if _launch_monitor.devices.has(dev_id):
				var dev = _launch_monitor.devices[dev_id]
				_launch_monitor.settings["device_name"] = str(dev.get("name", ""))
			elif str(_launch_monitor.settings.get("device_name", "")) == "":
				var dev_type := str(_launch_monitor.settings.get("device_type", "auto"))
				_launch_monitor.settings["device_name"] = "Square Golf" if dev_type != "garmin" else "Garmin Approach R10"
			_launch_monitor.settings["enabled"] = true
	_launch_monitor._save_settings()


func _on_scan_pressed() -> void:
	if _launch_monitor != null:
		if _launch_monitor.status == "Scanning":
			_launch_monitor.stop_scan()
			scan_button.text = "🔍 Scan"
			status_label.text = "Status: Disconnected"
			status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
			return
		_launch_monitor.start_scan()
		scan_button.text = "⏹ Stop Scan"
		status_label.text = "Status: Scanning for devices..."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))


func _on_connect_pressed() -> void:
	if _launch_monitor == null or device_option == null or device_option.item_count == 0:
		return
	var index = device_option.selected
	if index < 0:
		index = 0
	var device_id = str(device_option.get_item_metadata(index))
	if device_id == "":
		return
	var is_remember := remember_device_checkbox != null and remember_device_checkbox.button_pressed
	_launch_monitor.settings["remember_device"] = is_remember
	_launch_monitor.settings["device_id"] = device_id
	if _launch_monitor.devices.has(device_id):
		var dev = _launch_monitor.devices[device_id]
		_launch_monitor.settings["device_name"] = str(dev.get("name", ""))
	_launch_monitor.stop_scan()
	_launch_monitor.set_enabled(true)
	_launch_monitor.connect_to_device(device_id)
	status_label.text = "Status: Connecting..."
	status_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.95))


func _on_disconnect_pressed() -> void:
	if _launch_monitor != null:
		_launch_monitor.set_enabled(false)
		_launch_monitor.disconnect_device()
		status_label.text = "Status: Disconnected"
		status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)


func _on_device_option_selected(index: int) -> void:
	if device_option == null or _launch_monitor == null or index < 0:
		return
	var dev_id := str(device_option.get_item_metadata(index))
	if dev_id == "":
		return
	_launch_monitor.settings["device_id"] = dev_id
	if _launch_monitor.devices.has(dev_id):
		var dev = _launch_monitor.devices[dev_id]
		_launch_monitor.settings["device_name"] = str(dev.get("name", ""))
	if remember_device_checkbox != null and remember_device_checkbox.button_pressed:
		_launch_monitor.settings["remember_device"] = true
		_launch_monitor.settings["enabled"] = true
	_launch_monitor._save_settings()


func _refresh_devices(preferred_device_id: String = "") -> void:
	if device_option == null or _launch_monitor == null:
		return

	var selected_device := preferred_device_id
	if selected_device == "":
		selected_device = str(_launch_monitor.settings.get("device_id", ""))
	var saved_name := str(_launch_monitor.settings.get("device_name", ""))
	var saved_type := str(_launch_monitor.settings.get("device_type", "auto"))
	if saved_name == "":
		saved_name = "Square Golf" if saved_type != "garmin" else "Garmin Approach R10"

	if selected_device != "" and not _launch_monitor.devices.has(selected_device):
		_launch_monitor.devices[selected_device] = {
			"name": saved_name,
			"rssi": 0,
			"type": saved_type if saved_type != "auto" else _launch_monitor.detect_device_type(selected_device, saved_name),
			"is_discovered": false
		}

	var filter_type := "auto"
	if device_type_option != null and device_type_option.selected >= 0:
		filter_type = str(device_type_option.get_item_metadata(device_type_option.selected))

	var matching_keys: Array = []
	for dev_id in _launch_monitor.devices.keys():
		var device = _launch_monitor.devices[dev_id]
		var dev_name: String = str(device.get("name", ""))
		var dev_type: String = str(device.get("type", ""))
		if dev_type == "":
			dev_type = _launch_monitor.detect_device_type(dev_id, dev_name)

		if filter_type == "square" and dev_type != "square":
			continue
		if filter_type == "garmin" and dev_type != "garmin":
			continue
		matching_keys.append(dev_id)

	if matching_keys.is_empty():
		device_option.clear()
		device_option.add_item("No devices found (Click Scan)", 0)
		device_option.set_item_metadata(0, "")
		connect_button.disabled = true
		return

	# Sort matching keys: live discovered devices first (highest RSSI first), then offline devices
	matching_keys.sort_custom(func(a, b):
		var dev_a = _launch_monitor.devices[a]
		var dev_b = _launch_monitor.devices[b]
		var live_a = bool(dev_a.get("is_discovered", false))
		var live_b = bool(dev_b.get("is_discovered", false))
		if live_a != live_b:
			return live_a
		var rssi_a = int(dev_a.get("rssi", 0))
		var rssi_b = int(dev_b.get("rssi", 0))
		var eff_a = rssi_a if (rssi_a <= -10 and rssi_a >= -120 and live_a) else -999
		var eff_b = rssi_b if (rssi_b <= -10 and rssi_b >= -120 and live_b) else -999
		return eff_a > eff_b
	)

	# Prioritize preferred device or actively discovered live devices
	var active_live_keys: Array = []
	for k in matching_keys:
		if bool(_launch_monitor.devices[k].get("is_discovered", false)):
			active_live_keys.append(k)

	if preferred_device_id != "" and matching_keys.has(preferred_device_id) and bool(_launch_monitor.devices[preferred_device_id].get("is_discovered", false)):
		selected_device = preferred_device_id
	else:
		var current_is_live := matching_keys.has(selected_device) and bool(_launch_monitor.devices[selected_device].get("is_discovered", false))
		if not current_is_live and not active_live_keys.is_empty():
			selected_device = str(active_live_keys[0])
		elif (selected_device == "" or not matching_keys.has(selected_device)) and matching_keys.size() > 0:
			selected_device = str(matching_keys[0])

	if selected_device != "":
		_launch_monitor.settings["device_id"] = selected_device
		if _launch_monitor.devices.has(selected_device):
			var dev = _launch_monitor.devices[selected_device]
			_launch_monitor.settings["device_name"] = str(dev.get("name", ""))
		if remember_device_checkbox != null and remember_device_checkbox.button_pressed:
			_launch_monitor.settings["remember_device"] = true
			_launch_monitor.settings["enabled"] = true
		_launch_monitor._save_settings()

	# Rebuild OptionButton items if count, ids, or labels (e.g. offline -> live) changed
	var already_matches := (device_option.item_count == matching_keys.size())
	if already_matches:
		for i in range(matching_keys.size()):
			var dev_id = str(matching_keys[i])
			var device = _launch_monitor.devices[dev_id]
			var dev_name: String = str(device.get("name", "Launch Monitor"))
			var dev_type: String = str(device.get("type", ""))
			var is_live: bool = bool(device.get("is_discovered", false))
			var prefix := ""
			if filter_type == "auto":
				prefix = "[Garmin R10] " if dev_type == "garmin" else "[Square] "
			var live_suffix := " 📶" if is_live else " (Offline)"
			var expected_label := prefix + dev_name + live_suffix
			if str(device_option.get_item_metadata(i)) != dev_id or device_option.get_item_text(i) != expected_label:
				already_matches = false
				break

	if not already_matches:
		device_option.clear()
		for dev_id in matching_keys:
			var device = _launch_monitor.devices[dev_id]
			var dev_name: String = str(device.get("name", "Launch Monitor"))
			var dev_type: String = str(device.get("type", ""))
			var is_live: bool = bool(device.get("is_discovered", false))
			var prefix := ""
			if filter_type == "auto":
				prefix = "[Garmin R10] " if dev_type == "garmin" else "[Square] "
			var live_suffix := " 📶" if is_live else " (Offline)"
			var label := prefix + dev_name + live_suffix
			var idx := device_option.item_count
			device_option.add_item(label, idx)
			device_option.set_item_metadata(idx, dev_id)

	var target_index := -1
	for i in range(device_option.item_count):
		if str(device_option.get_item_metadata(i)) == selected_device:
			target_index = i
			break

	if target_index < 0 and device_option.item_count > 0:
		target_index = 0
		selected_device = str(device_option.get_item_metadata(0))
		_launch_monitor.settings["device_id"] = selected_device
		if _launch_monitor.devices.has(selected_device):
			_launch_monitor.settings["device_name"] = str(_launch_monitor.devices[selected_device].get("name", ""))
		_launch_monitor._save_settings()

	if target_index >= 0:
		device_option.select(target_index)

	connect_button.disabled = (device_option.item_count == 0 or str(device_option.get_item_metadata(device_option.selected)) == "")


func _update_status_display() -> void:
	if _launch_monitor == null or status_label == null:
		return

	var current_status: String = str(_launch_monitor.status)
	scan_button.text = "🔍 Scan"
	if encrypted_scan_button != null:
		encrypted_scan_button.text = "🔍 Scan"

	var is_dev_connected: bool = (current_status == "Connected" or current_status == "Ready" or current_status.to_lower().contains("detecting") or current_status.begins_with("Monitoring") or current_status.begins_with("Waiting") or bool(_launch_monitor.is_ready))
	if current_status.to_lower().contains("detecting"):
		status_label.text = "Status: %s" % current_status
		status_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
		continue_button.text = "Continue to Main Menu ➔"
	elif is_dev_connected:
		var display_state: String = current_status if (current_status != "Connecting" and not current_status.begins_with("Found")) else "Connected"
		status_label.text = "Status: Connected (%s)" % display_state
		status_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
		continue_button.text = "Continue to Main Menu ➔"
	elif current_status.contains("Scanning") or current_status.contains("Searching"):
		status_label.text = "Status: %s" % current_status
		status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
		scan_button.text = "🔄 Scanning..."
		if encrypted_scan_button != null:
			encrypted_scan_button.text = "🔄 Scanning..."
	elif current_status.contains("Connecting") or current_status.contains("Found"):
		status_label.text = "Status: %s" % current_status
		status_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.95))
	elif current_status == "Disconnected":
		status_label.text = "Status: Disconnected"
		status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		continue_button.text = "Continue to Main Menu"
	elif current_status.contains("No launch monitors found"):
		status_label.text = "Status: %s" % current_status
		status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
		continue_button.text = "Continue to Main Menu"
	else:
		status_label.text = "Status: %s" % current_status
		status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))

	if battery_label != null:
		if int(_launch_monitor.battery_level) >= 0:
			battery_label.text = "🔋 Battery: %d%%" % int(_launch_monitor.battery_level)
			battery_label.visible = true
		else:
			battery_label.text = ""
			battery_label.visible = false

	_update_bushnell_status()


const ENCRYPTED_MODELS = {
	"rainmaker": {
		"name": "Blue Tees Rainmaker",
		"requires_code": true,
		"code_label": "Rainmaker PIN:",
		"code_placeholder": "Enter PIN from Rainmaker screen",
		"instructions": "[b]Blue Tees Rainmaker Connection Steps:[/b]\n1. Power on your [b]Blue Tees Rainmaker[/b].\n2. Use the physical remote to select [b]Session[/b] on the unit.\n3. Click [b]Scan[/b] below to find your Rainmaker device over Bluetooth.\n4. Check the Rainmaker's full-color display for the generated [b]PIN code[/b].\n5. Enter the PIN into the box above and click [b]Connect[/b] to complete the session handshake."
	},
	"rapsodo": {
		"name": "Rapsodo MLM2PRO (Direct Encrypted BLE)",
		"requires_code": true,
		"code_label": "Pairing Code:",
		"code_placeholder": "Enter device pairing code",
		"instructions": "[b]Rapsodo MLM2PRO Direct BLE Steps:[/b]\n1. Turn on your [b]MLM2PRO[/b] and place it in pairing mode.\n2. Click [b]Scan[/b] to locate the device.\n3. Enter the dynamic session code / PIN into the field above.\n4. Click [b]Connect[/b] to authorize the encrypted Bluetooth stream."
	}
}


func _setup_encrypted_devices_dropdown() -> void:
	if encrypted_model_option == null:
		return
	encrypted_model_option.clear()
	var keys = ["rainmaker", "rapsodo"]
	for i in range(keys.size()):
		var k = keys[i]
		encrypted_model_option.add_item(ENCRYPTED_MODELS[k]["name"], i)
		encrypted_model_option.set_item_metadata(i, k)
	
	encrypted_model_option.select(0)
	_on_encrypted_model_selected(0)
	_refresh_encrypted_devices()


func _on_encrypted_model_selected(index: int) -> void:
	if encrypted_model_option == null or index < 0:
		return
	var key = str(encrypted_model_option.get_item_metadata(index))
	var model_info = ENCRYPTED_MODELS.get(key, {})
	if model_info.is_empty():
		return
	
	if encrypted_form_title != null:
		encrypted_form_title.text = "🔐 %s Pairing" % model_info["name"]
	if encrypted_code_label != null:
		encrypted_code_label.text = model_info.get("code_label", "Pairing Code:")
	if encrypted_code_input != null:
		encrypted_code_input.placeholder_text = model_info.get("code_placeholder", "")
		if _launch_monitor != null and key == "rainmaker":
			encrypted_code_input.text = str(_launch_monitor.settings.get("pairing_code", ""))
	if encrypted_instructions_text != null:
		encrypted_instructions_text.text = model_info.get("instructions", "")
	
	_refresh_encrypted_devices()


func _refresh_encrypted_devices(preferred_id: String = "") -> void:
	if encrypted_device_option == null or _launch_monitor == null or encrypted_model_option == null:
		return
	
	encrypted_device_option.clear()
	var model_key = str(encrypted_model_option.get_item_metadata(encrypted_model_option.selected))
	var selected_device := preferred_id
	if selected_device == "":
		selected_device = str(_launch_monitor.settings.get("device_id", ""))
	
	var count := 0
	for dev_id in _launch_monitor.devices:
		var dev = _launch_monitor.devices[dev_id]
		var dev_name: String = str(dev.get("name", ""))
		var dev_type: String = str(dev.get("type", ""))
		var is_live: bool = bool(dev.get("is_discovered", false))

		var match_model := false
		if model_key == "rainmaker":
			match_model = (dev_type == "rainmaker" or (_launch_monitor != null and _launch_monitor.is_rainmaker_device_name(dev_name)))
		else:
			match_model = dev_name.to_lower().contains(model_key)

		if match_model:
			var live_suffix := " 📶" if is_live else " (Offline)"
			var label := "%s (%s)%s" % [dev_name, dev_id, live_suffix]
			encrypted_device_option.add_item(label, count)
			encrypted_device_option.set_item_metadata(count, dev_id)
			count += 1

	if encrypted_device_option.item_count == 0:
		encrypted_device_option.add_item("No %s devices discovered (Click Scan)" % ENCRYPTED_MODELS[model_key]["name"], 0)
		encrypted_device_option.set_item_metadata(0, "")
		encrypted_connect_button.disabled = true
	else:
		encrypted_connect_button.disabled = false
		var target_idx := 0
		for i in range(encrypted_device_option.item_count):
			if str(encrypted_device_option.get_item_metadata(i)) == selected_device:
				target_idx = i
				break
		encrypted_device_option.select(target_idx)


func _on_encrypted_device_option_selected(index: int) -> void:
	if encrypted_device_option == null or index < 0 or _launch_monitor == null:
		return
	var dev_id = str(encrypted_device_option.get_item_metadata(index))
	if dev_id != "":
		_launch_monitor.settings["device_id"] = dev_id
		if _launch_monitor.devices.has(dev_id):
			_launch_monitor.settings["device_name"] = str(_launch_monitor.devices[dev_id].get("name", ""))
		_launch_monitor._save_settings()


func _on_encrypted_scan_pressed() -> void:
	if _launch_monitor == null or encrypted_model_option == null:
		return
	var model_key = str(encrypted_model_option.get_item_metadata(encrypted_model_option.selected))
	if _launch_monitor.status == "Scanning":
		_launch_monitor.stop_scan()
		encrypted_scan_button.text = "🔍 Scan"
		status_label.text = "Status: Disconnected"
		status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		return
	
	_launch_monitor.set_device_type(model_key)
	_launch_monitor.start_scan()
	encrypted_scan_button.text = "⏹ Stop Scan"
	status_label.text = "Status: Scanning for %s..." % ENCRYPTED_MODELS[model_key]["name"]
	status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))


func _on_encrypted_connect_pressed() -> void:
	if _launch_monitor == null or encrypted_device_option == null or encrypted_device_option.item_count == 0:
		return
	var idx = encrypted_device_option.selected
	if idx < 0:
		idx = 0
	var device_id = str(encrypted_device_option.get_item_metadata(idx))
	if device_id == "":
		return
	
	var pairing_code := ""
	if encrypted_code_input != null:
		pairing_code = encrypted_code_input.text.strip_edges()
	
	var model_key = str(encrypted_model_option.get_item_metadata(encrypted_model_option.selected))
	_launch_monitor.set_device_type(model_key)
	_launch_monitor.settings["pairing_code"] = pairing_code
	_launch_monitor.settings["device_id"] = device_id
	if _launch_monitor.devices.has(device_id):
		_launch_monitor.settings["device_name"] = str(_launch_monitor.devices[device_id].get("name", ""))
	
	var is_remember := remember_device_checkbox != null and remember_device_checkbox.button_pressed
	_launch_monitor.settings["remember_device"] = is_remember
	_launch_monitor.stop_scan()
	_launch_monitor.set_enabled(true)
	_launch_monitor.connect_to_device(device_id, false, pairing_code)
	status_label.text = "Status: Connecting to %s..." % _launch_monitor.settings.get("device_name", "Device")
	status_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.95))


func _on_encrypted_disconnect_pressed() -> void:
	if _launch_monitor != null:
		_launch_monitor.set_enabled(false)
		_launch_monitor.disconnect_device()
		status_label.text = "Status: Disconnected"
		status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)


func _on_device_discovered(device_id: String, name: String, _rssi: int) -> void:
	var dev = _launch_monitor.devices.get(device_id, {}) if _launch_monitor != null else {}
	var is_live: bool = bool(dev.get("is_discovered", false)) or ((_rssi <= -10 and _rssi >= -120) or (_rssi != 0 and _rssi != -1))
	var pref_id := device_id if is_live else ""
	_refresh_devices(pref_id)
	_refresh_encrypted_devices(pref_id)
	if is_live and _launch_monitor != null and (_launch_monitor.status == "Scanning" or _launch_monitor.status.contains("Searching")):
		var display_name := name if name != "" else "Launch Monitor"
		status_label.text = "Status: Found %s! Ready to connect." % display_name
		status_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))


func _on_status_changed(_status: String) -> void:
	_update_status_display()


func _on_error_occurred(message: String) -> void:
	if status_label != null:
		status_label.text = "Status: %s" % message
		status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))


func _on_battery_changed(_level: int) -> void:
	_update_status_display()


func _on_ready_changed(_is_ready: bool) -> void:
	_update_status_display()


func _exit_tree() -> void:
	if has_node("/root/UIFocusGuard"):
		get_node("/root/UIFocusGuard").pop_lock(self)
	_save_network_preferences()
	if _launch_monitor != null:
		if _launch_monitor.device_discovered.is_connected(_on_device_discovered):
			_launch_monitor.device_discovered.disconnect(_on_device_discovered)
		if _launch_monitor.status_changed.is_connected(_on_status_changed):
			_launch_monitor.status_changed.disconnect(_on_status_changed)
		if _launch_monitor.error_occurred.is_connected(_on_error_occurred):
			_launch_monitor.error_occurred.disconnect(_on_error_occurred)
		if _launch_monitor.battery_changed.is_connected(_on_battery_changed):
			_launch_monitor.battery_changed.disconnect(_on_battery_changed)
		if _launch_monitor.ready_changed.is_connected(_on_ready_changed):
			_launch_monitor.ready_changed.disconnect(_on_ready_changed)
		if _launch_monitor.has_method("get_fsx_csv_monitor"):
			var fsx = _launch_monitor.get_fsx_csv_monitor()
			if fsx != null and fsx.has_signal("new_shot_logged") and fsx.new_shot_logged.is_connected(_on_bushnell_new_shot_logged):
				fsx.new_shot_logged.disconnect(_on_bushnell_new_shot_logged)


func _setup_bushnell_tab() -> void:
	if bushnell_polling_option != null:
		bushnell_polling_option.clear()
		bushnell_polling_option.add_item("Fast (100 ms)", 0)
		bushnell_polling_option.set_item_metadata(0, 0.10)
		bushnell_polling_option.add_item("Standard (250 ms)", 1)
		bushnell_polling_option.set_item_metadata(1, 0.25)
		bushnell_polling_option.add_item("Battery Saver (500 ms)", 2)
		bushnell_polling_option.set_item_metadata(2, 0.50)
		bushnell_polling_option.select(1)
		bushnell_polling_option.item_selected.connect(_on_bushnell_polling_selected)

	var saved_path := ""
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "fsx_csv_path" in gs.range_settings:
			saved_path = str(gs.range_settings.fsx_csv_path.value)
	if saved_path == "" and _launch_monitor != null:
		saved_path = str(_launch_monitor.settings.get("fsx_csv_path", ""))
	if saved_path == "":
		var defaults = FsxCsvMonitorClass.find_default_fsx_csv_paths()
		if not defaults.is_empty():
			saved_path = defaults[0]

	if bushnell_csv_path_input != null:
		bushnell_csv_path_input.text = saved_path
		bushnell_csv_path_input.text_changed.connect(_on_bushnell_path_changed)

	if bushnell_instructions_text != null:
		bushnell_instructions_text.text = "[b]How to configure FSX Play / 2020 for Bushnell GC3:[/b]\n" + \
			"1. Power on your [b]Bushnell GC3[/b] / Launch Pro and launch [b]FSX Play[/b] or [b]FSX 2020[/b].\n" + \
			"2. In FSX Settings, enable [b]Write Shots CSV[/b] to automatically export shots to disk.\n" + \
			"3. Confirm the export path points to your [b]shots.csv[/b] or [b]LastShot.csv[/b] file above.\n" + \
			"4. Click [b]Start Monitoring[/b] below.\n" + \
			"5. Hit a shot on your launch monitor! Shot data will stream directly into Heckle Golf Simulator with full physics and announcer commentary."

	if _launch_monitor != null and _launch_monitor.has_method("get_fsx_csv_monitor"):
		var fsx = _launch_monitor.get_fsx_csv_monitor()
		if fsx != null and fsx.has_signal("new_shot_logged"):
			if not fsx.new_shot_logged.is_connected(_on_bushnell_new_shot_logged):
				fsx.new_shot_logged.connect(_on_bushnell_new_shot_logged)

	_update_bushnell_status()


func _on_bushnell_browse_pressed() -> void:
	if bushnell_file_dialog != null:
		if bushnell_csv_path_input != null and bushnell_csv_path_input.text != "":
			bushnell_file_dialog.current_path = bushnell_csv_path_input.text
		bushnell_file_dialog.popup_centered_ratio(0.7)


func _on_bushnell_file_selected(path: String) -> void:
	if bushnell_csv_path_input != null:
		bushnell_csv_path_input.text = path
	_save_bushnell_path(path)
	_update_bushnell_status()


func _on_bushnell_autodetect_pressed() -> void:
	var candidates = FsxCsvMonitorClass.find_default_fsx_csv_paths()
	if not candidates.is_empty():
		var found_path = candidates[0]
		if bushnell_csv_path_input != null:
			bushnell_csv_path_input.text = found_path
		_save_bushnell_path(found_path)
		if bushnell_status_text != null:
			if FileAccess.file_exists(found_path):
				bushnell_status_text.text = "Status: File located! Click Start Monitoring."
				bushnell_status_text.add_theme_color_override("font_color", Color(0.4, 0.85, 0.55))
			else:
				bushnell_status_text.text = "Status: Default path set (file will be created on first FSX shot)"
				bushnell_status_text.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	else:
		if bushnell_status_text != null:
			bushnell_status_text.text = "Status: No default FSX CSV found. Please browse manually."
			bushnell_status_text.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))


func _on_bushnell_path_changed(new_path: String) -> void:
	_save_bushnell_path(new_path)
	_update_bushnell_status()


func _save_bushnell_path(path: String) -> void:
	var trimmed = path.strip_edges()
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and "fsx_csv_path" in gs.range_settings:
			gs.range_settings.fsx_csv_path.set_value(trimmed)
			gs.save_settings()
	if _launch_monitor != null:
		_launch_monitor.settings["fsx_csv_path"] = trimmed
		_launch_monitor._save_settings()


func _on_bushnell_polling_selected(index: int) -> void:
	if bushnell_polling_option == null or _launch_monitor == null:
		return
	var rate: float = float(bushnell_polling_option.get_item_metadata(index))
	_launch_monitor.settings["fsx_poll_interval"] = rate
	_launch_monitor._save_settings()
	var fsx = _launch_monitor.get_fsx_csv_monitor()
	if fsx != null and fsx.has_method("set_poll_interval"):
		fsx.call("set_poll_interval", rate)


func _on_bushnell_connect_pressed() -> void:
	if _launch_monitor == null:
		return
	var path := ""
	if bushnell_csv_path_input != null:
		path = bushnell_csv_path_input.text.strip_edges()
	_save_bushnell_path(path)
	_launch_monitor.start_fsx_csv_monitoring(path)
	_update_status_display()
	_update_bushnell_status()


func _on_bushnell_disconnect_pressed() -> void:
	if _launch_monitor == null:
		return
	_launch_monitor.stop_fsx_csv_monitoring()
	_update_status_display()
	_update_bushnell_status()


func _on_bushnell_test_shot_pressed() -> void:
	if _launch_monitor != null and _launch_monitor.has_method("get_fsx_csv_monitor"):
		var fsx = _launch_monitor.get_fsx_csv_monitor()
		if fsx != null and fsx.has_method("simulate_test_shot"):
			fsx.call("simulate_test_shot")


func _on_bushnell_new_shot_logged(summary: String) -> void:
	if bushnell_last_shot_text != null:
		bushnell_last_shot_text.text = summary


func _update_bushnell_status() -> void:
	if _launch_monitor == null or bushnell_status_text == null:
		return
	var is_fsx_active = (_launch_monitor._active_driver == "bushnell_fsx")
	if is_fsx_active:
		var fsx = _launch_monitor.get_fsx_csv_monitor()
		var sub_status = str(fsx.status) if fsx != null else "Active"
		bushnell_status_text.text = "Status: %s" % sub_status
		bushnell_status_text.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
		if bushnell_connect_button != null:
			bushnell_connect_button.text = "🔄 Monitoring Active"
			bushnell_connect_button.disabled = true
		if bushnell_disconnect_button != null:
			bushnell_disconnect_button.disabled = false
	else:
		var target_path = bushnell_csv_path_input.text.strip_edges() if bushnell_csv_path_input != null else ""
		if target_path != "" and FileAccess.file_exists(target_path):
			bushnell_status_text.text = "Status: File ready (%s). Click Start Monitoring." % target_path.get_file()
			bushnell_status_text.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		else:
			bushnell_status_text.text = "Status: Disconnected"
			bushnell_status_text.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		if bushnell_connect_button != null:
			bushnell_connect_button.text = "🔗 Start Monitoring"
			bushnell_connect_button.disabled = false
		if bushnell_disconnect_button != null:
			bushnell_disconnect_button.disabled = true
