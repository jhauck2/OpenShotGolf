class_name SettingsPanel
extends CanvasLayer

## Tabbed settings overlay. Hosts (Main Menu, Range, Courses) must:
##   - call set_main_menu_button_visible(false) when the panel is opened from
##     inside the Main Menu (the "MAIN MENU" button is meaningless there);
##   - connect main_menu_requested when the button IS visible — the panel only
##     emits the signal, it does not navigate scenes itself;
##   - optionally connect `closed` if the host needs to react to dismissal.
signal closed
signal main_menu_requested

enum SettingsTab { PLAYER, DISPLAY, GAME, LMONITORS, PANELS }

const FALLBACK_PLAYER_NAME := "JesseInCode"
const FALLBACK_RESOLUTION_PRESET := "1728x972"
const FEET_PER_CAMERA_DISTANCE_UNIT := 3.28084
const CAMERA_DISTANCE_MIN_UNITS := 1.0
const CAMERA_DISTANCE_MAX_UNITS := 8.0
const CAMERA_DISTANCE_MIN_FEET := CAMERA_DISTANCE_MIN_UNITS * FEET_PER_CAMERA_DISTANCE_UNIT
const CAMERA_DISTANCE_MAX_FEET := CAMERA_DISTANCE_MAX_UNITS * FEET_PER_CAMERA_DISTANCE_UNIT
const PANEL_WIDTH := 1040.0
const PANEL_HEIGHT := 580.0
const PANEL_SHADOW_PADDING_X := 17.0
const PANEL_SHADOW_PADDING_Y := 18.0
const LMONITOR_PROVIDER_SQUARE := AppSettings.LAUNCH_MONITOR_PROVIDER_SQUARE
const LMONITOR_PROVIDER_PITRAC := AppSettings.LAUNCH_MONITOR_PROVIDER_PITRAC

var _root_control: Control = null
var _panel_shadow: PanelContainer = null
var _panel: PanelContainer = null
var _tabs: TabContainer = null
var _player_tab_scroll: ScrollContainer = null
var _display_tab_scroll: ScrollContainer = null
var _game_tab_scroll: ScrollContainer = null
var _lmonitors_tab_scroll: ScrollContainer = null
var _player_name_input: LineEdit = null
var _range_default_club_card: PanelContainer = null
var _range_default_club_option: OptionButton = null
var _test_shots_check: CheckBox = null
var _resolution_option: OptionButton = null
var _fullscreen_check: CheckBox = null
var _camera_distance_slider: HSlider = null
var _camera_distance_value: SpinBox = null
var _camera_distance_helper: Label = null
var _camera_delay_slider: HSlider = null
var _camera_delay_value: SpinBox = null
var _camera_delay_helper: Label = null
var _tracer_history_card: PanelContainer = null
var _tracer_history_slider: HSlider = null
var _tracer_history_value: SpinBox = null
var _tracer_history_helper: Label = null
var _launch_monitor_enabled_check: CheckBox = null
var _launch_monitor_provider_card: PanelContainer = null
var _launch_monitor_provider_option: OptionButton = null
var _square_monitor_card: PanelContainer = null
var _square_device_option: OptionButton = null
var _square_scan_button: Button = null
var _square_connect_button: Button = null
var _square_disconnect_button: Button = null
var _square_club_option: OptionButton = null
var _square_handedness_option: OptionButton = null
var _pitrac_card: PanelContainer = null
var _tcp_port_value: SpinBox = null
var _shot_recording_check: CheckBox = null
var _shot_recording_path_input: LineEdit = null
var _shot_recording_browse_button: Button = null
var _shot_recording_helper: Label = null
var _shot_recording_file_dialog: FileDialog = null
var _main_menu_button: Button = null
var _save_button: Button = null
var _close_button: Button = null
var _panels_empty_label: Label = null
var _panel_toggle_checked_icon: Texture2D = null
var _panel_toggle_unchecked_icon: Texture2D = null

var _global_settings: GlobalSettings = null
var _app_settings: AppSettings = null
var _game_settings: GameSettings = null
var _shot_tracer_count_setting: Setting = null
var _is_syncing_controls := false
var _show_tracer_history_setting := true
var _show_range_default_club_setting := true


func _ready() -> void:
	_global_settings = GlobalSettingsManager
	if _global_settings != null:
		_app_settings = _global_settings.app_settings
		_game_settings = _global_settings.game_settings

	_build_ui()
	_create_panel_toggle_icons()
	_configure_controls()
	_connect_control_signals()
	_connect_setting_signals()
	_refresh_controls_from_settings()
	call_deferred("_sync_panel_shadow_to_panel")
	visible = false


func _exit_tree() -> void:
	_disconnect_setting_signals()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func show_panel(tab: int = SettingsTab.PLAYER) -> void:
	_warn_if_main_menu_signal_unwired()
	_refresh_controls_from_settings()
	_set_active_tab(tab)
	visible = true
	call_deferred("_sync_panel_shadow_to_panel")

	if tab == SettingsTab.PLAYER and _player_name_input != null:
		_player_name_input.grab_focus()


func _warn_if_main_menu_signal_unwired() -> void:
	if _main_menu_button == null or not _main_menu_button.visible:
		return
	if main_menu_requested.get_connections().is_empty():
		push_warning("SettingsPanel: MAIN MENU button is visible but main_menu_requested has no listeners; clicking it will do nothing.")


func hide_panel() -> void:
	if not visible:
		return

	visible = false
	closed.emit()


func set_main_menu_button_visible(is_visible: bool) -> void:
	if _main_menu_button != null:
		_main_menu_button.visible = is_visible


func set_tracer_history_setting_visible(is_visible: bool) -> void:
	_show_tracer_history_setting = is_visible
	_apply_tracer_history_visibility()


func set_range_default_club_setting_visible(is_visible: bool) -> void:
	_show_range_default_club_setting = is_visible
	_apply_range_default_club_visibility()


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "Root"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_control)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.48)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	_root_control.add_child(backdrop)

	_panel_shadow = PanelContainer.new()
	_panel_shadow.name = "PanelShadow"
	_panel_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_shadow.add_theme_stylebox_override("panel", SettingsPanelStyles.make_style_box(Color(0, 0, 0, 0.38), Color.TRANSPARENT, 0, 16))
	SettingsPanelStyles.set_centered_rect(_panel_shadow, PANEL_WIDTH + PANEL_SHADOW_PADDING_X * 2.0, PANEL_HEIGHT + PANEL_SHADOW_PADDING_Y * 2.0)
	_root_control.add_child(_panel_shadow)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", SettingsPanelStyles.make_style_box(Color(0.043, 0.180, 0.310, 0.95), Color(0.337, 0.698, 0.937, 0.42), 2, 14))
	SettingsPanelStyles.set_centered_rect(_panel, PANEL_WIDTH, PANEL_HEIGHT)
	_root_control.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	_build_header(content)
	_build_tabs(content)

	_shot_recording_file_dialog = FileDialog.new()
	_shot_recording_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_shot_recording_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_shot_recording_file_dialog.title = "Select Shot Recording Directory"
	add_child(_shot_recording_file_dialog)


func _build_header(parent: Container) -> void:
	var header := PanelContainer.new()
	header.name = "HeaderBanner"
	header.add_theme_stylebox_override("panel", SettingsPanelStyles.make_style_box(Color(0.063, 0.086, 0.125, 0.96), Color(0.337, 0.698, 0.937, 0.45), 1, 10, false))
	parent.add_child(header)

	var margin := MarginContainer.new()
	margin.name = "HeaderMargin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	header.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "HeaderRow"
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var title := Label.new()
	title.name = "Title"
	title.text = "SETTINGS"
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 34)
	row.add_child(title)

	var spacer := Control.new()
	spacer.name = "HeaderSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_main_menu_button = SettingsPanelStyles.make_button("MAIN MENU", false)
	_main_menu_button.name = "MainMenuButton"
	_main_menu_button.visible = false
	row.add_child(_main_menu_button)

	_save_button = SettingsPanelStyles.make_button("SAVE", true)
	_save_button.name = "SaveButton"
	row.add_child(_save_button)

	_close_button = SettingsPanelStyles.make_button("CLOSE", false)
	_close_button.name = "CloseButton"
	row.add_child(_close_button)


func _build_tabs(parent: Container) -> void:
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_stylebox_override("panel", SettingsPanelStyles.make_style_box(Color(0.020, 0.094, 0.161, 0.70), Color(1, 1, 1, 0.20), 1, 10))
	_tabs.add_theme_stylebox_override("tab_selected", SettingsPanelStyles.make_tab_style(Color(0.129, 0.529, 0.824, 0.95), 8, 0))
	_tabs.add_theme_stylebox_override("tab_unselected", SettingsPanelStyles.make_tab_style(Color(0.063, 0.086, 0.125, 0.90), 8, 0))
	_tabs.add_theme_stylebox_override("tab_hovered", SettingsPanelStyles.make_tab_style(Color(0.090, 0.141, 0.212, 0.95), 8, 0))
	_tabs.add_theme_color_override("font_selected_color", Color(0.96, 0.98, 1, 1))
	_tabs.add_theme_color_override("font_unselected_color", Color(0.82, 0.88, 0.94, 0.92))
	_tabs.add_theme_color_override("font_hovered_color", Color(0.96, 0.98, 1, 1))
	_tabs.add_theme_font_size_override("font_size", 20)
	parent.add_child(_tabs)

	_build_player_tab()
	_build_display_tab()
	_build_game_tab()
	_build_lmonitors_tab()
	_build_panels_tab()


func _build_player_tab() -> void:
	var player_content := SettingsPanelStyles.make_scroll_tab(_tabs, "Player")
	_player_tab_scroll = player_content.get_parent() as ScrollContainer

	var row := SettingsPanelStyles.make_row_card(player_content, "PlayerCard", "Player Name")
	_player_name_input = LineEdit.new()
	_player_name_input.name = "PlayerNameInput"
	_player_name_input.placeholder_text = "Enter player name"
	_player_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SettingsPanelStyles.apply_field_style(_player_name_input)
	row.add_child(_player_name_input)

	_range_default_club_card = SettingsPanelStyles.make_card(player_content, "RangeDefaultClubCard")
	row = SettingsPanelStyles.make_card_row(_range_default_club_card, "Default Club (Range)")
	_range_default_club_option = OptionButton.new()
	_range_default_club_option.name = "RangeDefaultClubOption"
	_range_default_club_option.custom_minimum_size = Vector2(220, 0)
	SettingsPanelStyles.apply_field_style(_range_default_club_option)
	row.add_child(_range_default_club_option)
	row.add_child(SettingsPanelStyles.make_spacer())

	row = SettingsPanelStyles.make_row_card(player_content, "PlayerTestShotsCard", "Enable Test Shots")
	_test_shots_check = CheckBox.new()
	_test_shots_check.name = "TestShotsCheck"
	_test_shots_check.text = "Enabled"
	SettingsPanelStyles.apply_check_style(_test_shots_check)
	row.add_child(_test_shots_check)
	row.add_child(SettingsPanelStyles.make_spacer())


func _build_display_tab() -> void:
	var display_content := SettingsPanelStyles.make_scroll_tab(_tabs, "Display")
	_display_tab_scroll = display_content.get_parent() as ScrollContainer

	var row := SettingsPanelStyles.make_row_card(display_content, "DisplayResolutionCard", "Window Size")
	_resolution_option = OptionButton.new()
	_resolution_option.name = "ResolutionOption"
	_resolution_option.custom_minimum_size = Vector2(340, 0)
	SettingsPanelStyles.apply_field_style(_resolution_option)
	row.add_child(_resolution_option)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.name = "FullscreenCheck"
	_fullscreen_check.text = "Fullscreen"
	SettingsPanelStyles.apply_check_style(_fullscreen_check)
	row.add_child(_fullscreen_check)


func _build_game_tab() -> void:
	var game_content := SettingsPanelStyles.make_scroll_tab(_tabs, "Game")
	_game_tab_scroll = game_content.get_parent() as ScrollContainer

	var card := SettingsPanelStyles.make_card(game_content, "CameraDistanceCard")
	var content := SettingsPanelStyles.make_card_content(card)
	content.add_child(SettingsPanelStyles.make_section_label("Camera Distance (ft)"))
	var row := SettingsPanelStyles.make_control_row()
	_camera_distance_slider = HSlider.new()
	_camera_distance_slider.name = "CameraDistanceSlider"
	_camera_distance_slider.custom_minimum_size = Vector2(460, 0)
	_camera_distance_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_camera_distance_slider)
	_camera_distance_value = SpinBox.new()
	_camera_distance_value.name = "CameraDistanceValue"
	_camera_distance_value.custom_minimum_size = Vector2(110, 0)
	_camera_distance_value.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_camera_distance_value)
	content.add_child(row)
	_camera_distance_helper = SettingsPanelStyles.make_helper_label("Distance from ball: 0 ft")
	content.add_child(_camera_distance_helper)

	card = SettingsPanelStyles.make_card(game_content, "CameraDelayCard")
	content = SettingsPanelStyles.make_card_content(card)
	content.add_child(SettingsPanelStyles.make_section_label("Camera Follow Delay (seconds)"))
	row = SettingsPanelStyles.make_control_row()
	_camera_delay_slider = HSlider.new()
	_camera_delay_slider.name = "CameraDelaySlider"
	_camera_delay_slider.custom_minimum_size = Vector2(460, 0)
	_camera_delay_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_camera_delay_slider)
	_camera_delay_value = SpinBox.new()
	_camera_delay_value.name = "CameraDelayValue"
	_camera_delay_value.custom_minimum_size = Vector2(110, 0)
	_camera_delay_value.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_camera_delay_value)
	content.add_child(row)
	_camera_delay_helper = SettingsPanelStyles.make_helper_label("Follow starts after 0.00 seconds")
	content.add_child(_camera_delay_helper)

	_tracer_history_card = SettingsPanelStyles.make_card(game_content, "TracerHistoryCard")
	content = SettingsPanelStyles.make_card_content(_tracer_history_card)
	content.add_child(SettingsPanelStyles.make_section_label("Tracer History Count"))
	row = SettingsPanelStyles.make_control_row()
	_tracer_history_slider = HSlider.new()
	_tracer_history_slider.name = "TracerHistorySlider"
	_tracer_history_slider.custom_minimum_size = Vector2(460, 0)
	_tracer_history_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tracer_history_slider)
	_tracer_history_value = SpinBox.new()
	_tracer_history_value.name = "TracerHistoryValue"
	_tracer_history_value.custom_minimum_size = Vector2(110, 0)
	_tracer_history_value.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_tracer_history_value)
	content.add_child(row)
	_tracer_history_helper = SettingsPanelStyles.make_helper_label("Retains the latest 2 tracers in Range.")
	content.add_child(_tracer_history_helper)

	card = SettingsPanelStyles.make_card(game_content, "ShotRecordingCard")
	content = SettingsPanelStyles.make_card_content(card)
	row = SettingsPanelStyles.make_labeled_row("Shot Recording")
	_shot_recording_check = CheckBox.new()
	_shot_recording_check.name = "ShotRecordingCheck"
	_shot_recording_check.text = "Enabled"
	SettingsPanelStyles.apply_check_style(_shot_recording_check)
	row.add_child(_shot_recording_check)
	row.add_child(SettingsPanelStyles.make_spacer())
	content.add_child(row)

	row = SettingsPanelStyles.make_labeled_row("Save Path")
	_shot_recording_path_input = LineEdit.new()
	_shot_recording_path_input.name = "ShotRecordingPathInput"
	_shot_recording_path_input.placeholder_text = "Select directory..."
	_shot_recording_path_input.editable = false
	_shot_recording_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SettingsPanelStyles.apply_field_style(_shot_recording_path_input)
	row.add_child(_shot_recording_path_input)
	_shot_recording_browse_button = SettingsPanelStyles.make_button("Browse", false)
	_shot_recording_browse_button.name = "ShotRecordingBrowseButton"
	row.add_child(_shot_recording_browse_button)
	content.add_child(row)
	_shot_recording_helper = SettingsPanelStyles.make_helper_label("Not recording")
	content.add_child(_shot_recording_helper)


func _build_lmonitors_tab() -> void:
	var lmonitors_content := SettingsPanelStyles.make_scroll_tab(_tabs, "LMonitor")
	_lmonitors_tab_scroll = lmonitors_content.get_parent() as ScrollContainer

	var row := SettingsPanelStyles.make_row_card(lmonitors_content, "LaunchMonitorEnabledCard", "Launch Monitor")
	_launch_monitor_enabled_check = CheckBox.new()
	_launch_monitor_enabled_check.name = "LaunchMonitorEnabledCheck"
	_launch_monitor_enabled_check.text = "Enabled"
	SettingsPanelStyles.apply_check_style(_launch_monitor_enabled_check)
	row.add_child(_launch_monitor_enabled_check)
	row.add_child(SettingsPanelStyles.make_spacer())

	_launch_monitor_provider_card = SettingsPanelStyles.make_card(lmonitors_content, "LaunchMonitorProviderCard")
	row = SettingsPanelStyles.make_card_row(_launch_monitor_provider_card, "Monitor")
	_launch_monitor_provider_option = OptionButton.new()
	_launch_monitor_provider_option.name = "LaunchMonitorProviderOption"
	_launch_monitor_provider_option.custom_minimum_size = Vector2(240, 0)
	SettingsPanelStyles.apply_field_style(_launch_monitor_provider_option)
	row.add_child(_launch_monitor_provider_option)
	row.add_child(SettingsPanelStyles.make_spacer())

	_square_monitor_card = SettingsPanelStyles.make_card(lmonitors_content, "SquareMonitorCard")
	var content := SettingsPanelStyles.make_card_content(_square_monitor_card)
	content.add_child(SettingsPanelStyles.make_section_label("Square"))

	row = SettingsPanelStyles.make_labeled_row("Device")
	_square_device_option = OptionButton.new()
	_square_device_option.name = "SquareDeviceOption"
	_square_device_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SettingsPanelStyles.apply_field_style(_square_device_option)
	row.add_child(_square_device_option)
	content.add_child(row)

	var action_row := SettingsPanelStyles.make_control_row()
	_square_scan_button = SettingsPanelStyles.make_button("Scan", false)
	_square_scan_button.name = "SquareScanButton"
	action_row.add_child(_square_scan_button)
	_square_connect_button = SettingsPanelStyles.make_button("Connect", true)
	_square_connect_button.name = "SquareConnectButton"
	action_row.add_child(_square_connect_button)
	_square_disconnect_button = SettingsPanelStyles.make_button("Disconnect", false)
	_square_disconnect_button.name = "SquareDisconnectButton"
	action_row.add_child(_square_disconnect_button)
	content.add_child(action_row)

	row = SettingsPanelStyles.make_labeled_row("Club")
	_square_club_option = OptionButton.new()
	_square_club_option.name = "SquareClubOption"
	_square_club_option.custom_minimum_size = Vector2(220, 0)
	SettingsPanelStyles.apply_field_style(_square_club_option)
	row.add_child(_square_club_option)
	row.add_child(SettingsPanelStyles.make_spacer())
	content.add_child(row)

	row = SettingsPanelStyles.make_labeled_row("Handedness")
	_square_handedness_option = OptionButton.new()
	_square_handedness_option.name = "SquareHandednessOption"
	_square_handedness_option.custom_minimum_size = Vector2(220, 0)
	SettingsPanelStyles.apply_field_style(_square_handedness_option)
	row.add_child(_square_handedness_option)
	row.add_child(SettingsPanelStyles.make_spacer())
	content.add_child(row)

	_pitrac_card = SettingsPanelStyles.make_card(lmonitors_content, "PiTracCard")
	content = SettingsPanelStyles.make_card_content(_pitrac_card)
	content.add_child(SettingsPanelStyles.make_section_label("PiTrac"))
	row = SettingsPanelStyles.make_labeled_row("TCP Port")
	_tcp_port_value = SpinBox.new()
	_tcp_port_value.name = "TcpPortValue"
	_tcp_port_value.custom_minimum_size = Vector2(180, 0)
	_tcp_port_value.alignment = HORIZONTAL_ALIGNMENT_CENTER
	SettingsPanelStyles.apply_field_style(_tcp_port_value)
	row.add_child(_tcp_port_value)
	row.add_child(SettingsPanelStyles.make_spacer())
	content.add_child(row)
	content.add_child(SettingsPanelStyles.make_helper_label("PiTrac TCP listening port."))


func _build_panels_tab() -> void:
	var panels := VBoxContainer.new()
	panels.name = "Panels"
	panels.add_theme_constant_override("separation", 10)
	_tabs.add_child(panels)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 8)
	panels.add_child(top_spacer)

	_panels_empty_label = Label.new()
	_panels_empty_label.name = "PanelsEmptyLabel"
	_panels_empty_label.text = "No HUD panels are available in this screen."
	_panels_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panels_empty_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 0.92))
	_panels_empty_label.add_theme_font_size_override("font_size", 16)
	panels.add_child(_panels_empty_label)


func _configure_controls() -> void:
	_populate_resolution_options()
	_populate_range_default_club_options()
	_populate_launch_monitor_provider_options()
	_populate_square_club_options()
	_populate_square_handedness_options()
	_refresh_square_devices()

	_camera_distance_slider.min_value = CAMERA_DISTANCE_MIN_FEET
	_camera_distance_slider.max_value = CAMERA_DISTANCE_MAX_FEET
	_camera_distance_slider.step = 0.1
	_camera_distance_value.min_value = CAMERA_DISTANCE_MIN_FEET
	_camera_distance_value.max_value = CAMERA_DISTANCE_MAX_FEET
	_camera_distance_value.step = 0.1

	_camera_delay_slider.min_value = 0.0
	_camera_delay_slider.max_value = 5.0
	_camera_delay_slider.step = 0.05
	_camera_delay_value.min_value = 0.0
	_camera_delay_value.max_value = 5.0
	_camera_delay_value.step = 0.05

	var tracer_min := 0
	var tracer_max := 5
	if _game_settings != null and _game_settings.shot_tracer_count != null:
		var setting: Setting = _game_settings.shot_tracer_count
		if setting.min_value != null:
			tracer_min = int(setting.min_value)
		if setting.max_value != null:
			tracer_max = int(setting.max_value)

	_tracer_history_slider.min_value = tracer_min
	_tracer_history_slider.max_value = tracer_max
	_tracer_history_slider.step = 1.0
	_tracer_history_value.min_value = tracer_min
	_tracer_history_value.max_value = tracer_max
	_tracer_history_value.step = 1.0

	_tcp_port_value.min_value = 1
	_tcp_port_value.max_value = 65535
	_tcp_port_value.step = 1

	_apply_panel_toggle_icons(_test_shots_check)
	_apply_panel_toggle_icons(_fullscreen_check)
	_apply_panel_toggle_icons(_launch_monitor_enabled_check)
	_apply_panel_toggle_icons(_shot_recording_check)
	_apply_tracer_history_visibility()
	_apply_range_default_club_visibility()
	_apply_launch_monitor_visibility()


func _connect_control_signals() -> void:
	_root_control.resized.connect(_on_panel_layout_changed)
	_panel.resized.connect(_on_panel_layout_changed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_player_name_input.text_submitted.connect(_on_player_name_text_submitted)
	_player_name_input.focus_exited.connect(_on_player_name_focus_exited)
	_range_default_club_option.item_selected.connect(_on_range_default_club_selected)
	_test_shots_check.toggled.connect(_on_test_shots_toggled)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_camera_distance_slider.value_changed.connect(_on_camera_distance_slider_changed)
	_camera_distance_value.value_changed.connect(_on_camera_distance_value_changed)
	_camera_delay_slider.value_changed.connect(_on_camera_delay_slider_changed)
	_camera_delay_value.value_changed.connect(_on_camera_delay_value_changed)
	_tracer_history_slider.value_changed.connect(_on_tracer_history_slider_changed)
	_tracer_history_value.value_changed.connect(_on_tracer_history_value_changed)
	_launch_monitor_enabled_check.toggled.connect(_on_launch_monitor_enabled_toggled)
	_launch_monitor_provider_option.item_selected.connect(_on_launch_monitor_provider_selected)
	_square_scan_button.pressed.connect(_on_square_scan_pressed)
	_square_connect_button.pressed.connect(_on_square_connect_pressed)
	_square_disconnect_button.pressed.connect(_on_square_disconnect_pressed)
	_square_club_option.item_selected.connect(_on_square_club_selected)
	_square_handedness_option.item_selected.connect(_on_square_handedness_selected)
	_tcp_port_value.value_changed.connect(_on_tcp_port_value_changed)
	_shot_recording_check.toggled.connect(_on_shot_recording_toggled)
	_shot_recording_browse_button.pressed.connect(_on_shot_recording_browse_pressed)
	_shot_recording_file_dialog.dir_selected.connect(_on_shot_recording_dir_selected)


func _connect_setting_signals() -> void:
	var callback := Callable(self, "_on_any_setting_changed")
	if _app_settings != null:
		for setting: Setting in _app_settings.settings.values():
			if not setting.setting_changed.is_connected(callback):
				setting.setting_changed.connect(callback)

	if _game_settings != null:
		_shot_tracer_count_setting = _game_settings.shot_tracer_count
		if _shot_tracer_count_setting != null and not _shot_tracer_count_setting.setting_changed.is_connected(callback):
			_shot_tracer_count_setting.setting_changed.connect(callback)

	var launch_monitor = _get_launch_monitor_manager()
	if launch_monitor != null:
		var device_callback := Callable(self, "_on_square_device_discovered")
		if not launch_monitor.device_discovered.is_connected(device_callback):
			launch_monitor.device_discovered.connect(device_callback)


func _disconnect_setting_signals() -> void:
	var callback := Callable(self, "_on_any_setting_changed")
	if _app_settings != null:
		for setting: Setting in _app_settings.settings.values():
			if setting.setting_changed.is_connected(callback):
				setting.setting_changed.disconnect(callback)

	if _shot_tracer_count_setting != null and _shot_tracer_count_setting.setting_changed.is_connected(callback):
		_shot_tracer_count_setting.setting_changed.disconnect(callback)

	var launch_monitor = _get_launch_monitor_manager()
	if launch_monitor != null:
		var device_callback := Callable(self, "_on_square_device_discovered")
		if launch_monitor.device_discovered.is_connected(device_callback):
			launch_monitor.device_discovered.disconnect(device_callback)


func _refresh_controls_from_settings() -> void:
	_is_syncing_controls = true

	if _app_settings != null:
		_player_name_input.text = _sanitize_player_name(str(_app_settings.player_name.value))
		_test_shots_check.set_pressed_no_signal(bool(_app_settings.test_shots_enabled.value))

		var preset := str(_app_settings.display_resolution_preset.value).strip_edges()
		if preset == "":
			preset = FALLBACK_RESOLUTION_PRESET
		_select_or_add_resolution_preset(preset)
		_fullscreen_check.set_pressed_no_signal(bool(_app_settings.display_fullscreen.value))

		var camera_distance_units := float(_app_settings.camera_orbit_distance.value)
		var camera_distance_feet := _units_to_feet(camera_distance_units)
		_camera_distance_slider.set_value_no_signal(camera_distance_feet)
		_camera_distance_value.set_value_no_signal(camera_distance_feet)
		_camera_distance_helper.text = "Distance from ball: %d ft" % int(round(camera_distance_feet))

		var camera_delay := float(_app_settings.camera_follow_delay_seconds.value)
		_camera_delay_slider.set_value_no_signal(camera_delay)
		_camera_delay_value.set_value_no_signal(camera_delay)
		_camera_delay_helper.text = "Follow starts after %.2f seconds" % camera_delay

		_launch_monitor_enabled_check.set_pressed_no_signal(bool(_app_settings.launch_monitor_enabled.value))
		_select_option_by_metadata(_launch_monitor_provider_option, _get_selected_launch_monitor_provider())
		_tcp_port_value.set_value_no_signal(int(_app_settings.tcp_port.value))
		_shot_recording_check.set_pressed_no_signal(bool(_app_settings.shot_recording_enabled.value))
		_shot_recording_path_input.text = str(_app_settings.shot_recording_path.value)
		_update_shot_recording_helper()

		var default_club := RangeClubCatalog.normalize_label(str(_app_settings.range_default_club.value))
		_select_range_default_club(default_club)

	if _shot_tracer_count_setting != null:
		var tracer_count := int(round(float(_shot_tracer_count_setting.value)))
		_tracer_history_slider.set_value_no_signal(tracer_count)
		_tracer_history_value.set_value_no_signal(tracer_count)
		_update_tracer_history_helper(tracer_count)

	_refresh_square_controls()
	_apply_tracer_history_visibility()
	_apply_range_default_club_visibility()
	_apply_launch_monitor_visibility()
	_is_syncing_controls = false


func _populate_resolution_options() -> void:
	_resolution_option.clear()
	for preset: String in AppSettingsDisplayService.PRESETS:
		_resolution_option.add_item(preset)


func _populate_range_default_club_options() -> void:
	_range_default_club_option.clear()
	for label: String in RangeClubCatalog.LABELS:
		_range_default_club_option.add_item(label)


func _populate_launch_monitor_provider_options() -> void:
	_launch_monitor_provider_option.clear()
	_add_option_with_metadata(_launch_monitor_provider_option, LMONITOR_PROVIDER_SQUARE, LMONITOR_PROVIDER_SQUARE)
	_add_option_with_metadata(_launch_monitor_provider_option, LMONITOR_PROVIDER_PITRAC, LMONITOR_PROVIDER_PITRAC)


func _populate_square_club_options() -> void:
	_square_club_option.clear()
	for club_name: String in SquareClubCatalog.labels():
		_add_option_with_metadata(_square_club_option, club_name, SquareClubCatalog.code_for(club_name))


func _populate_square_handedness_options() -> void:
	_square_handedness_option.clear()
	_square_handedness_option.add_item("Right", 0)
	_square_handedness_option.add_item("Left", 1)


func _add_option_with_metadata(option: OptionButton, label: String, metadata: Variant) -> void:
	var index := option.item_count
	option.add_item(label)
	option.set_item_metadata(index, metadata)


func _select_or_add_resolution_preset(preset: String) -> void:
	var selected_index := -1
	for index in range(_resolution_option.item_count):
		if _resolution_option.get_item_text(index) == preset:
			selected_index = index
			break

	if selected_index < 0:
		_resolution_option.add_item(preset)
		selected_index = _resolution_option.item_count - 1

	_resolution_option.select(selected_index)


func _select_range_default_club(club_label: String) -> void:
	var selected_index := 0
	for index in range(_range_default_club_option.item_count):
		if _range_default_club_option.get_item_text(index) == club_label:
			selected_index = index
			break

	_range_default_club_option.select(selected_index)


func _select_option_by_metadata(option: OptionButton, metadata: Variant) -> void:
	if option == null:
		return

	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == str(metadata):
			option.select(index)
			return

	if option.item_count > 0:
		option.select(0)


func _select_option_by_item_id(option: OptionButton, item_id: int) -> void:
	if option == null:
		return

	var index := option.get_item_index(item_id)
	if index >= 0:
		option.select(index)
	elif option.item_count > 0:
		option.select(0)


func _on_any_setting_changed(_value: Variant) -> void:
	if not visible:
		return
	_refresh_controls_from_settings()


func _on_save_pressed() -> void:
	if _global_settings != null:
		_global_settings.save_app_settings()
	hide_panel()


func _on_main_menu_pressed() -> void:
	if _global_settings != null:
		_global_settings.save_app_settings()
	main_menu_requested.emit()
	hide_panel()


func _on_close_pressed() -> void:
	hide_panel()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()


func _on_panel_layout_changed() -> void:
	_sync_panel_shadow_to_panel()


func _on_player_name_text_submitted(text: String) -> void:
	_commit_player_name(text)


func _on_player_name_focus_exited() -> void:
	_commit_player_name(_player_name_input.text)


func _commit_player_name(input: String) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.player_name.set_value(_sanitize_player_name(input))


func _on_range_default_club_selected(index: int) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	var safe_index: int = int(clamp(index, 0, _range_default_club_option.item_count - 1))
	var club := RangeClubCatalog.normalize_label(_range_default_club_option.get_item_text(safe_index))
	_app_settings.range_default_club.set_value(club)


func _on_test_shots_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.test_shots_enabled.set_value(enabled)


func _on_resolution_selected(index: int) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.display_resolution_preset.set_value(_resolution_option.get_item_text(index))


func _on_fullscreen_toggled(is_pressed: bool) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.display_fullscreen.set_value(is_pressed)


func _on_camera_distance_slider_changed(value: float) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.camera_orbit_distance.set_value(_feet_to_units(value))


func _on_camera_distance_value_changed(value: float) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.camera_orbit_distance.set_value(_feet_to_units(value))


func _on_camera_delay_slider_changed(value: float) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.camera_follow_delay_seconds.set_value(value)


func _on_camera_delay_value_changed(value: float) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.camera_follow_delay_seconds.set_value(value)


func _on_tracer_history_slider_changed(value: float) -> void:
	if _is_syncing_controls or _shot_tracer_count_setting == null:
		return

	_shot_tracer_count_setting.set_value(int(round(value)))


func _on_tracer_history_value_changed(value: float) -> void:
	if _is_syncing_controls or _shot_tracer_count_setting == null:
		return

	_shot_tracer_count_setting.set_value(int(round(value)))


func _on_launch_monitor_enabled_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.launch_monitor_enabled.set_value(enabled)


func _on_launch_monitor_provider_selected(index: int) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.launch_monitor_provider.set_value(str(_launch_monitor_provider_option.get_item_metadata(index)))


func _on_square_scan_pressed() -> void:
	var launch_monitor = _get_launch_monitor_manager()
	if launch_monitor == null:
		return

	launch_monitor.start_scan()


func _on_square_connect_pressed() -> void:
	var launch_monitor = _get_launch_monitor_manager()
	if launch_monitor == null or _square_device_option == null or _square_device_option.item_count == 0:
		return

	var selected_index := int(clamp(_square_device_option.selected, 0, _square_device_option.item_count - 1))
	var device_id := str(_square_device_option.get_item_metadata(selected_index))
	if device_id == "":
		return

	launch_monitor.connect_to_device(device_id)


func _on_square_disconnect_pressed() -> void:
	var launch_monitor = _get_launch_monitor_manager()
	if launch_monitor != null:
		launch_monitor.disconnect_device()


func _on_square_club_selected(index: int) -> void:
	var launch_monitor = _get_launch_monitor_manager()
	if _is_syncing_controls or launch_monitor == null:
		return

	launch_monitor.set_club_code(str(_square_club_option.get_item_metadata(index)))


func _on_square_handedness_selected(index: int) -> void:
	var launch_monitor = _get_launch_monitor_manager()
	if _is_syncing_controls or launch_monitor == null:
		return

	launch_monitor.set_handedness(_square_handedness_option.get_item_id(index))


func _on_square_device_discovered(_device_id: String, _name: String, _rssi: int) -> void:
	_refresh_square_devices()


func _on_tcp_port_value_changed(value: float) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.tcp_port.set_value(int(round(value)))


func _on_shot_recording_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.shot_recording_enabled.set_value(enabled)


func _on_shot_recording_browse_pressed() -> void:
	if _shot_recording_file_dialog != null:
		_shot_recording_file_dialog.popup()


func _on_shot_recording_dir_selected(dir: String) -> void:
	if _is_syncing_controls or _app_settings == null:
		return

	_app_settings.shot_recording_path.set_value(dir)


func _update_shot_recording_helper() -> void:
	_shot_recording_helper.text = "Not recording"


func _update_tracer_history_helper(tracer_count: int) -> void:
	if tracer_count <= 0:
		_tracer_history_helper.text = "No tracer history retained."
	elif tracer_count == 1:
		_tracer_history_helper.text = "Retains the latest tracer in Range."
	else:
		_tracer_history_helper.text = "Retains the latest %d tracers in Range." % tracer_count


func _refresh_square_controls() -> void:
	if _square_device_option == null:
		return

	var launch_monitor := _get_launch_monitor_manager()
	if launch_monitor == null:
		_square_device_option.clear()
		return

	_select_option_by_metadata(_square_club_option, launch_monitor.get_square_club_code())
	_select_option_by_item_id(_square_handedness_option, launch_monitor.get_square_handedness())
	_refresh_square_devices()


func _refresh_square_devices() -> void:
	if _square_device_option == null:
		return

	_square_device_option.clear()
	var launch_monitor := _get_launch_monitor_manager()
	if launch_monitor == null:
		return

	var selected_device := launch_monitor.get_selected_device_id()
	for device_id in launch_monitor.devices.keys():
		var device = launch_monitor.devices[device_id]
		var label := str(device.get("name", "Square"))
		if int(device.get("rssi", 0)) != 0:
			label = "%s (%d)" % [label, int(device.get("rssi", 0))]
		var index := _square_device_option.item_count
		_square_device_option.add_item(label)
		_square_device_option.set_item_metadata(index, device_id)
		if str(device_id) == selected_device:
			_square_device_option.select(index)


func _apply_launch_monitor_visibility() -> void:
	var enabled := _app_settings != null and bool(_app_settings.launch_monitor_enabled.value)
	var provider := _get_selected_launch_monitor_provider()

	if _launch_monitor_provider_card != null:
		_launch_monitor_provider_card.visible = enabled
	if _square_monitor_card != null:
		_square_monitor_card.visible = enabled and provider == LMONITOR_PROVIDER_SQUARE
	if _pitrac_card != null:
		_pitrac_card.visible = enabled and provider == LMONITOR_PROVIDER_PITRAC

	call_deferred("_sync_panel_shadow_to_panel")


func _get_selected_launch_monitor_provider() -> String:
	if _app_settings == null:
		return LMONITOR_PROVIDER_PITRAC

	return AppSettings.normalize_provider(str(_app_settings.launch_monitor_provider.value))


func _get_launch_monitor_manager() -> LaunchMonitorManagerAutoload:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("LaunchMonitorManager") as LaunchMonitorManagerAutoload


func _set_active_tab(tab: int) -> void:
	if _tabs == null or _tabs.get_tab_count() == 0:
		return

	var tab_index: int = int(clamp(tab, 0, _tabs.get_tab_count() - 1))
	_tabs.current_tab = tab_index
	_reset_tab_scroll(tab_index)


func _reset_tab_scroll(tab: int) -> void:
	var scroll: ScrollContainer = null
	match tab:
		SettingsTab.PLAYER:
			scroll = _player_tab_scroll
		SettingsTab.DISPLAY:
			scroll = _display_tab_scroll
		SettingsTab.GAME:
			scroll = _game_tab_scroll
		SettingsTab.LMONITORS:
			scroll = _lmonitors_tab_scroll

	if scroll == null:
		return

	scroll.scroll_vertical = 0
	scroll.scroll_horizontal = 0


func _apply_tracer_history_visibility() -> void:
	if _tracer_history_card != null:
		_tracer_history_card.visible = _show_tracer_history_setting
	call_deferred("_sync_panel_shadow_to_panel")


func _apply_range_default_club_visibility() -> void:
	if _range_default_club_card != null:
		_range_default_club_card.visible = _show_range_default_club_setting
	call_deferred("_sync_panel_shadow_to_panel")


func _sanitize_player_name(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "":
		trimmed = FALLBACK_PLAYER_NAME

	if trimmed.length() > 24:
		return trimmed.substr(0, 24)

	return trimmed


func _units_to_feet(units: float) -> float:
	return units * FEET_PER_CAMERA_DISTANCE_UNIT


func _feet_to_units(feet: float) -> float:
	return feet / FEET_PER_CAMERA_DISTANCE_UNIT


func _sync_panel_shadow_to_panel() -> void:
	if _panel == null or _panel_shadow == null:
		return

	_panel_shadow.position = _panel.position - Vector2(PANEL_SHADOW_PADDING_X, PANEL_SHADOW_PADDING_Y)
	_panel_shadow.size = _panel.size + Vector2(PANEL_SHADOW_PADDING_X * 2.0, PANEL_SHADOW_PADDING_Y * 2.0)


func _create_panel_toggle_icons() -> void:
	_panel_toggle_checked_icon = SettingsPanelStyles.build_panel_toggle_icon(true)
	_panel_toggle_unchecked_icon = SettingsPanelStyles.build_panel_toggle_icon(false)


func _apply_panel_toggle_icons(toggle: CheckBox) -> void:
	SettingsPanelStyles.apply_panel_toggle_icons(toggle, _panel_toggle_checked_icon, _panel_toggle_unchecked_icon)
