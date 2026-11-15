extends PanelContainer

signal toggle_settings_requested
signal close_settings_requested
signal manage_players_requested

var reset_spin_box : SpinBox = null
var temperature_spin_box : SpinBox = null
var altitude_spin_box : SpinBox = null
var surface_option : OptionButton = null
var ball_type_option : OptionButton = null
var tracer_count_spin_box : SpinBox = null
var square_enabled_button : CheckButton = null
var square_device_type_option : OptionButton = null
var square_device_option : OptionButton = null
var square_scan_button : Button = null
var square_connect_button : Button = null
var square_disconnect_button : Button = null
var square_ready_button : Button = null
var garmin_calibrate_button : Button = null
var square_status_label : Label = null
var square_battery_label : Label = null
var square_firmware_label : Label = null
var square_club_option : OptionButton = null
var square_handedness_option : OptionButton = null
var temperature_unit_label : Label = null
var altitude_unit_label : Label = null
var _stats_count_label : Label = null
var _stat_limit_modal : Control = null
var _stat_check_buttons : Dictionary = {}
var _stat_check_button_list : Array[CheckButton] = []
var _is_internal_stats_sync : bool = false
var _key_buttons_by_action : Dictionary = {}
var _joy_buttons_by_action : Dictionary = {}
var _rebind_modal : Control = null
var _rebind_conflict_modal : Control = null
var _rebind_action_name : String = ""
var _rebind_mode : String = "key"
var _controller_status_label : Label = null
var _last_applied_graphics_quality: String = ""
var _graphics_quality_changed: bool = false
var _wind_slider : HSlider = null
var _wind_slider_lbl : Label = null
var _fullscreen_check : CheckButton = null
var _units_label : Label = null

const SQUARE_UI_LOG_PREFIX := "[SquareUI]"
const SQUARE_CLUBS := {
	"Driver": "0104",
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
	if spin_box == null:
		return
	spin_box.set_block_signals(true)
	spin_box.step = step
	if setting.min_value != null:
		spin_box.min_value = setting.min_value
	if setting.max_value != null:
		spin_box.max_value = setting.max_value
	spin_box.value = setting.value
	spin_box.set_block_signals(false)
	
	spin_box.custom_minimum_size = Vector2(110, 52)
	var line_edit = spin_box.get_line_edit()
	if line_edit != null:
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.add_theme_font_size_override("font_size", 19)
		ThemeManager.apply_input_style(line_edit, 8)
	
	if spin_box.value != setting.value:
		setting.set_value(spin_box.value)


func _enhance_spinbox_with_stepper(spin_box: SpinBox, step: float) -> void:
	if spin_box == null:
		return
	var parent = spin_box.get_parent()
	if parent == null:
		return
		
	var minus_btn = Button.new()
	minus_btn.name = spin_box.name + "_MinusBtn"
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(52, 52)
	minus_btn.add_theme_font_size_override("font_size", 22)
	ThemeManager.apply_nav_button_style(minus_btn, 8)
	minus_btn.pressed.connect(func():
		spin_box.value = clamp(spin_box.value - step, spin_box.min_value, spin_box.max_value)
	)
	
	var plus_btn = Button.new()
	plus_btn.name = spin_box.name + "_PlusBtn"
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(52, 52)
	plus_btn.add_theme_font_size_override("font_size", 22)
	ThemeManager.apply_nav_button_style(plus_btn, 8)
	plus_btn.pressed.connect(func():
		spin_box.value = clamp(spin_box.value + step, spin_box.min_value, spin_box.max_value)
	)
	
	var spin_index = spin_box.get_index()
	parent.add_child(minus_btn)
	parent.move_child(minus_btn, spin_index)
	
	parent.add_child(plus_btn)
	parent.move_child(plus_btn, spin_index + 2)


func _setup_touch_option_button(opt: OptionButton) -> void:
	if opt == null:
		return
	ThemeManager.apply_option_button_style(opt, 18, Vector2(220, 52))


func _create_tab_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 0
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _get_tab_scroll_margin_right(scroll: ScrollContainer = null) -> int:
	var is_mob: bool = MobilePerformance.is_mobile()
	var bar_w: float = 56.0 if is_mob else 28.0
	if scroll != null:
		var v_bar = scroll.get_v_scroll_bar()
		if v_bar != null and v_bar.custom_minimum_size.x > 0:
			bar_w = maxf(bar_w, v_bar.custom_minimum_size.x)
	var clearance: int = 20 if (is_mob or bar_w >= 50.0) else 16
	return int(bar_w + clearance)


func _apply_tab_scroll_style(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	ThemeManager.apply_scroll_container_style(scroll, 28)
	var right_margin: int = _get_tab_scroll_margin_right(scroll)
	for child in scroll.get_children():
		if child is MarginContainer:
			child.add_theme_constant_override("margin_right", right_margin)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ThemeManager.apply_modal_style(self, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	if GlobalSettings and GlobalSettings.range_settings and "graphics_quality" in GlobalSettings.range_settings:
		_last_applied_graphics_quality = str(GlobalSettings.range_settings.graphics_quality.value)
	close_settings_requested.connect(_on_close_settings_requested)
	tree_exiting.connect(_on_close_settings_requested)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_on_close_settings_requested()
		else:
			_on_settings_opened()
	)
	if is_visible_in_tree():
		_on_settings_opened()

	# Header Close Button Styling
	var header_close_btn = get_node_or_null("MarginContainer/VBoxContainer/HeaderHBox/HeaderCloseButton")
	if header_close_btn != null:
		header_close_btn.custom_minimum_size = Vector2(48, 48)
		header_close_btn.add_theme_font_size_override("font_size", 20)
		header_close_btn.focus_mode = Control.FOCUS_ALL
		ThemeManager.apply_nav_button_style(header_close_btn, 8)

	# Style TabContainer
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	if tab_container != null:
		tab_container.add_theme_font_size_override("font_size", 20)
		tab_container.add_theme_constant_override("side_margin", 16)
		tab_container.add_theme_stylebox_override("tab_selected", _create_tab_style(ThemeManager.COLOR_PRIMARY_NORMAL, ThemeManager.COLOR_PRIMARY_NORMAL.lightened(0.2)))
		tab_container.add_theme_stylebox_override("tab_unselected", _create_tab_style(ThemeManager.COLOR_NAV_NORMAL, Color(1, 1, 1, 0.15)))
		tab_container.add_theme_stylebox_override("tab_hovered", _create_tab_style(ThemeManager.COLOR_NAV_HOVER, Color(1, 1, 1, 0.3)))
		
		# Set clear, attractive tab labels
		tab_container.set_tab_title(0, "⛳ Gameplay")
		tab_container.set_tab_title(1, "📊 Stats")
		tab_container.set_tab_title(2, "📷 Camera")
		tab_container.set_tab_title(3, "📡 Launch Monitor")
		tab_container.set_tab_title(4, "🎙 Announcer")

	# Apply touch-friendly scrollbar styling, kinetic swipe scrolling, and clearance padding to all tabs
	for tab_name in ["Gameplay", "Stats", "Camera", "LaunchMonitor", "Announcer"]:
		var tab_scroll = get_node_or_null("MarginContainer/VBoxContainer/TabContainer/" + tab_name) as ScrollContainer
		if tab_scroll != null:
			_apply_tab_scroll_style(tab_scroll)

	reset_spin_box = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/BallResetTimer/ResetSpinBox
	temperature_spin_box = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/Temperature/TemperatureSpinBox
	altitude_spin_box = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/Altitude/AltitudeSpinBox
	surface_option = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/SurfaceType/SurfaceOption
	ball_type_option = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/BallType/BallTypeOption
	tracer_count_spin_box = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/TracerCount/TracerCountSpinBox
	temperature_unit_label = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/Temperature/Label2
	altitude_unit_label = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox/Altitude/Label2

	# Reset Timer Settings
	_setup_spin_box(reset_spin_box, GlobalSettings.range_settings.ball_reset_timer, 0.5)
	_enhance_spinbox_with_stepper(reset_spin_box, 0.5)

	# Temperature Settings
	_setup_spin_box(temperature_spin_box, GlobalSettings.range_settings.temperature, 1.0)
	_enhance_spinbox_with_stepper(temperature_spin_box, 1.0)

	# Altitude Settings
	_setup_spin_box(altitude_spin_box, GlobalSettings.range_settings.altitude, 10.0)
	_enhance_spinbox_with_stepper(altitude_spin_box, 10.0)

	# Tracer count
	_setup_spin_box(tracer_count_spin_box, GlobalSettings.range_settings.shot_tracer_count, 1.0)
	_enhance_spinbox_with_stepper(tracer_count_spin_box, 1.0)

	# Surface type options
	surface_option.clear()
	surface_option.add_item("Fairway", PhysicsEnums.SurfaceType.FAIRWAY)
	surface_option.add_item("Soft Fairway", PhysicsEnums.SurfaceType.FAIRWAY_SOFT)
	surface_option.add_item("Rough", PhysicsEnums.SurfaceType.ROUGH)
	surface_option.add_item("Firm", PhysicsEnums.SurfaceType.FIRM)
	var surface_id: int = GlobalSettings.range_settings.surface_type.value
	var surface_index := surface_option.get_item_index(surface_id)
	if surface_index >= 0:
		surface_option.select(surface_index)
	_setup_touch_option_button(surface_option)

	# Ball type options
	if ball_type_option != null:
		ball_type_option.clear()
		ball_type_option.add_item("Standard Ball", 0)
		ball_type_option.add_item("Tour Soft", 1)
		ball_type_option.add_item("Distance / Firm", 2)
		var ball_id: int = GlobalSettings.range_settings.ball_type.value
		if ball_id < ball_type_option.item_count:
			ball_type_option.select(ball_id)
		_setup_touch_option_button(ball_type_option)

	GlobalSettings.range_settings.range_units.setting_changed.connect(update_units)

	var gameplay_vbox = $MarginContainer/VBoxContainer/TabContainer/Gameplay/MarginContainer/GameplayVBox
	var camera_vbox = $MarginContainer/VBoxContainer/TabContainer/Camera/MarginContainer/CameraVBox
	var lm_vbox = $MarginContainer/VBoxContainer/TabContainer/LaunchMonitor/MarginContainer/LaunchMonitorVBox

	var units_row = gameplay_vbox.get_node_or_null("Units") as HBoxContainer
	var auto_reset_row = gameplay_vbox.get_node_or_null("AutoBallReset") as HBoxContainer
	var camera_follow_row = camera_vbox.get_node_or_null("CameraFollow") as HBoxContainer
	var shot_replay_follow_row = camera_vbox.get_node_or_null("ShotReplayFollow") as HBoxContainer
	var shot_injector_row = lm_vbox.get_node_or_null("ShotInjector") as HBoxContainer

	# Initialize toggle button states
	var units_check = _find_check_button(units_row)
	if units_check != null:
		units_check.set_pressed_no_signal(GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.METRIC)
	var camera_follow_check = _find_check_button(camera_follow_row)
	if camera_follow_check != null:
		camera_follow_check.set_pressed_no_signal(GlobalSettings.range_settings.camera_follow_mode.value)
	var shot_replay_follow_check = _find_check_button(shot_replay_follow_row)
	if shot_replay_follow_check != null:
		shot_replay_follow_check.set_pressed_no_signal(GlobalSettings.range_settings.shot_replay_follow.value)
	var auto_reset_check = _find_check_button(auto_reset_row)
	if auto_reset_check != null:
		auto_reset_check.set_pressed_no_signal(GlobalSettings.range_settings.auto_ball_reset.value)
	var shot_injector_check = _find_check_button(shot_injector_row)
	if shot_injector_check != null:
		shot_injector_check.set_pressed_no_signal(GlobalSettings.range_settings.shot_injector_enabled.value)

	_format_static_toggle_row(units_row, "Units (Metric)" if GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.METRIC else "Units (Imperial)")
	_units_label = units_row.get_node_or_null("Label") if units_row != null else null
	_format_static_toggle_row(auto_reset_row, "Auto Ball Reset")
	_format_static_toggle_row(camera_follow_row, "Camera Follow Mode")
	_format_static_toggle_row(shot_replay_follow_row, "Shot Replay Follow")
	_format_static_toggle_row(shot_injector_row, "Shot Injector")

	var cam_toggles = []
	if camera_follow_row != null:
		camera_follow_row.get_parent().remove_child(camera_follow_row)
		cam_toggles.append(camera_follow_row)
	if shot_replay_follow_row != null:
		shot_replay_follow_row.get_parent().remove_child(shot_replay_follow_row)
		cam_toggles.append(shot_replay_follow_row)
	if not cam_toggles.is_empty():
		var cam_top_grid = _create_toggle_grid(cam_toggles, 3)
		camera_vbox.add_child(cam_top_grid)
		camera_vbox.move_child(cam_top_grid, 0)

	if shot_injector_row != null:
		shot_injector_row.get_parent().remove_child(shot_injector_row)
		var lm_top_grid = _create_toggle_grid([shot_injector_row], 3)
		lm_vbox.add_child(lm_top_grid)
		lm_vbox.move_child(lm_top_grid, 0)

	_setup_displayed_stats_section()
	if GlobalSettings and GlobalSettings.range_settings and "displayed_stats" in GlobalSettings.range_settings:
		GlobalSettings.range_settings.displayed_stats.setting_changed.connect(func(_v):
			if _is_internal_stats_sync:
				return
			if _stat_check_buttons.is_empty():
				_setup_displayed_stats_section()
			else:
				_sync_displayed_stats_checkboxes()
		)
	_setup_square_monitor_section()
	_setup_tcp_monitor_section()
	_setup_hecklelinks_announcer_section()
	_setup_keybindings_section()
	_setup_developer_debugging_section()

	# Wind Simulation toggle in Gameplay tab
	var wind_toggle_row = _create_toggle_setting_row("Wind Simulation", "wind_enabled")

	if units_row != null:
		units_row.get_parent().remove_child(units_row)
	if auto_reset_row != null:
		auto_reset_row.get_parent().remove_child(auto_reset_row)
	var gameplay_top_toggles = _create_toggle_grid([units_row, auto_reset_row, wind_toggle_row], 3)
	gameplay_vbox.add_child(gameplay_top_toggles)
	gameplay_vbox.move_child(gameplay_top_toggles, 0)

	var wind_slider_container = VBoxContainer.new()
	wind_slider_container.name = "WindSliderContainer"
	wind_slider_container.add_theme_constant_override("separation", 6)
	wind_slider_container.visible = bool(GlobalSettings.range_settings.wind_enabled.value)

	var wind_slider_row = HBoxContainer.new()
	wind_slider_row.name = "WindSliderRow"
	wind_slider_row.custom_minimum_size = Vector2(0, 52)
	wind_slider_row.add_theme_constant_override("separation", 10)

	_wind_slider_lbl = Label.new()
	var init_spd: float = GlobalSettings.current_wind_speed_mph
	if init_spd <= 0.0:
		_wind_slider_lbl.text = "Wind Speed: 0 MPH (Calm)"
	else:
		_wind_slider_lbl.text = "Wind Speed: %d MPH" % int(init_spd)
	_wind_slider_lbl.add_theme_font_size_override("font_size", 19)
	_wind_slider_lbl.custom_minimum_size = Vector2(300, 0)
	_wind_slider_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wind_slider_row.add_child(_wind_slider_lbl)

	var wind_minus_btn = Button.new()
	wind_minus_btn.text = "－"
	wind_minus_btn.custom_minimum_size = Vector2(48, 48)
	wind_minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(wind_minus_btn, 8)
	wind_slider_row.add_child(wind_minus_btn)

	_wind_slider = HSlider.new()
	_wind_slider.name = "WindSpeedSlider"
	_wind_slider.min_value = 0.0
	_wind_slider.max_value = 35.0
	_wind_slider.step = 1.0
	_wind_slider.value = init_spd
	_wind_slider.custom_minimum_size = Vector2(180, 48)
	_wind_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wind_slider_row.add_child(_wind_slider)

	var wind_plus_btn = Button.new()
	wind_plus_btn.text = "＋"
	wind_plus_btn.custom_minimum_size = Vector2(48, 48)
	wind_plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(wind_plus_btn, 8)
	wind_slider_row.add_child(wind_plus_btn)

	wind_slider_container.add_child(wind_slider_row)

	_wind_slider.value_changed.connect(func(val: float):
		GlobalSettings.set_wind_speed_mph(val)
		if _wind_slider_lbl != null:
			if val <= 0.0:
				_wind_slider_lbl.text = "Wind Speed: 0 MPH (Calm)"
			else:
				_wind_slider_lbl.text = "Wind Speed: %d MPH" % int(val)
	)

	wind_minus_btn.pressed.connect(func():
		_wind_slider.value = clamp(_wind_slider.value - 1.0, _wind_slider.min_value, _wind_slider.max_value)
	)
	wind_plus_btn.pressed.connect(func():
		_wind_slider.value = clamp(_wind_slider.value + 1.0, _wind_slider.min_value, _wind_slider.max_value)
	)

	for child in wind_toggle_row.get_children():
		if child is CheckButton:
			child.toggled.connect(func(toggled_on: bool):
				wind_slider_container.visible = toggled_on
				if toggled_on:
					_sync_wind_slider()
			)
			break

	GlobalSettings.wind_changed.connect(func(_spd: float, _dir: float):
		_sync_wind_slider()
	)

	gameplay_vbox.add_child(wind_slider_container)
	gameplay_vbox.move_child(wind_slider_container, 1)

	# Group top gameplay numeric range items into a 2-column grid
	var ball_reset_row = gameplay_vbox.get_node_or_null("BallResetTimer") as HBoxContainer
	var temp_row = gameplay_vbox.get_node_or_null("Temperature") as HBoxContainer
	var alt_row = gameplay_vbox.get_node_or_null("Altitude") as HBoxContainer
	var tracer_row = gameplay_vbox.get_node_or_null("TracerCount") as HBoxContainer

	if ball_reset_row != null and temp_row != null and alt_row != null and tracer_row != null:
		var numeric_rows = [ball_reset_row, temp_row, alt_row, tracer_row]
		for r in numeric_rows:
			r.get_parent().remove_child(r)
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lbl = r.get_node_or_null("Label")
			if lbl != null:
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var ctrl = r.get_node_or_null("Control3")
			if ctrl != null:
				r.remove_child(ctrl)
				ctrl.queue_free()

		var gameplay_spin_grid = _create_range_grid(numeric_rows, 2)
		gameplay_vbox.add_child(gameplay_spin_grid)
		gameplay_vbox.move_child(gameplay_spin_grid, 2)

	# Foam Ball Boost Mode section in Gameplay tab
	var foam_sep = HSeparator.new()
	gameplay_vbox.add_child(foam_sep)
	
	var foam_title = Label.new()
	foam_title.text = "Foam Ball Boost Mode"
	foam_title.add_theme_font_size_override("font_size", 22)
	foam_title.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	gameplay_vbox.add_child(foam_title)

	var foam_desc = Label.new()
	foam_desc.text = "Compensates for the reduced launch velocity of foam practice balls by scaling ball speed from the launch monitor before calculating flight and stats."
	foam_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foam_desc.add_theme_font_size_override("font_size", 16)
	foam_desc.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	gameplay_vbox.add_child(foam_desc)

	var foam_toggle_row = _create_toggle_setting_row("Enable Foam Ball Boost", "foam_ball_boost_enabled")
	gameplay_vbox.add_child(_create_toggle_grid([foam_toggle_row], 3))
	
	var foam_slider_container = VBoxContainer.new()
	foam_slider_container.name = "FoamBoostSliderContainer"
	foam_slider_container.add_theme_constant_override("separation", 6)
	foam_slider_container.visible = bool(GlobalSettings.range_settings.foam_ball_boost_enabled.value)
	
	var boost_setting = GlobalSettings.range_settings.foam_ball_boost_percent
	var foam_slider_row = HBoxContainer.new()
	foam_slider_row.name = "FoamBoostSliderRow"
	foam_slider_row.custom_minimum_size = Vector2(0, 52)
	foam_slider_row.add_theme_constant_override("separation", 10)
	foam_slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var foam_slider_lbl = Label.new()
	foam_slider_lbl.text = "Boost Amount: %.0f%%" % boost_setting.value
	foam_slider_lbl.add_theme_font_size_override("font_size", 18)
	foam_slider_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foam_slider_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foam_slider_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foam_slider_lbl.tooltip_text = "Boost Amount"
	foam_slider_row.add_child(foam_slider_lbl)
	
	var minus_btn = Button.new()
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(48, 48)
	minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(minus_btn, 8)
	foam_slider_row.add_child(minus_btn)
	
	var slider = HSlider.new()
	slider.name = "HSlider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = boost_setting.value
	slider.custom_minimum_size = Vector2(140, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foam_slider_row.add_child(slider)
	
	var plus_btn = Button.new()
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(48, 48)
	plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(plus_btn, 8)
	foam_slider_row.add_child(plus_btn)
	
	var foam_grid = _create_range_grid([foam_slider_row], 2)
	foam_slider_container.add_child(foam_grid)
	
	# Breakdown preview label showing exact scaling for each club category
	var preview_lbl = Label.new()
	preview_lbl.add_theme_font_size_override("font_size", 16)
	preview_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	
	var update_preview = func(pct: float):
		var woods_pct = pct * 1.0
		var irons_pct = pct * 0.75
		var wedges_pct = pct * 0.50
		preview_lbl.text = "Scaling: Woods/Driver: +%.1f%% (100%%) | Hybrids/Irons: +%.1f%% (75%%) | Wedges: +%.1f%% (50%%) | Putter: +0%%" % [
			woods_pct, irons_pct, wedges_pct
		]
	
	update_preview.call(boost_setting.value)
	foam_slider_container.add_child(preview_lbl)
	
	slider.value_changed.connect(func(val: float):
		boost_setting.set_value(val)
		foam_slider_lbl.text = "Boost Amount: %.0f%%" % val
		update_preview.call(val)
	)
	
	minus_btn.pressed.connect(func():
		slider.value = clamp(slider.value - 1.0, slider.min_value, slider.max_value)
	)
	plus_btn.pressed.connect(func():
		slider.value = clamp(slider.value + 1.0, slider.min_value, slider.max_value)
	)
	
	for child in foam_toggle_row.get_children():
		if child is CheckButton:
			child.toggled.connect(func(toggled_on: bool):
				foam_slider_container.visible = toggled_on
			)
			break
	
	gameplay_vbox.add_child(foam_slider_container)

	# Shot Shape Sensitivity section in Gameplay tab
	var curve_sep = HSeparator.new()
	gameplay_vbox.add_child(curve_sep)

	var curve_title = Label.new()
	curve_title.text = "Shot Shape Sensitivity (Slice / Hook)"
	curve_title.add_theme_font_size_override("font_size", 22)
	curve_title.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	gameplay_vbox.add_child(curve_title)

	var curve_desc = Label.new()
	curve_desc.text = "Adjusts flight curvature produced by spin axis tilt (fades, slices, draws, hooks). 1.0x is calibrated to TrackMan/PGA Tour radar dispersion (~60 yards on a 20° driver slice)."
	curve_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	curve_desc.add_theme_font_size_override("font_size", 16)
	curve_desc.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	gameplay_vbox.add_child(curve_desc)

	var curve_slider_container = VBoxContainer.new()
	curve_slider_container.name = "ShotShapeSensitivityContainer"
	curve_slider_container.add_theme_constant_override("separation", 6)

	var curve_setting = GlobalSettings.range_settings.shot_curve_sensitivity
	var curve_slider_row = HBoxContainer.new()
	curve_slider_row.name = "ShotShapeSensitivityRow"
	curve_slider_row.custom_minimum_size = Vector2(0, 52)
	curve_slider_row.add_theme_constant_override("separation", 10)
	curve_slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var curve_slider_lbl = Label.new()
	curve_slider_lbl.text = "Curvature: %.2fx" % curve_setting.value
	curve_slider_lbl.add_theme_font_size_override("font_size", 18)
	curve_slider_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	curve_slider_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	curve_slider_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	curve_slider_lbl.tooltip_text = "Shot Shape Sensitivity"
	curve_slider_row.add_child(curve_slider_lbl)

	var curve_minus_btn = Button.new()
	curve_minus_btn.text = "－"
	curve_minus_btn.custom_minimum_size = Vector2(48, 48)
	curve_minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(curve_minus_btn, 8)
	curve_slider_row.add_child(curve_minus_btn)

	var curve_slider = HSlider.new()
	curve_slider.name = "ShotCurveSensitivitySlider"
	curve_slider.min_value = 0.5
	curve_slider.max_value = 2.0
	curve_slider.step = 0.05
	curve_slider.value = curve_setting.value
	curve_slider.custom_minimum_size = Vector2(140, 48)
	curve_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	curve_slider_row.add_child(curve_slider)

	var curve_plus_btn = Button.new()
	curve_plus_btn.text = "＋"
	curve_plus_btn.custom_minimum_size = Vector2(48, 48)
	curve_plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(curve_plus_btn, 8)
	curve_slider_row.add_child(curve_plus_btn)

	var curve_grid = _create_range_grid([curve_slider_row], 2)
	curve_slider_container.add_child(curve_grid)

	curve_slider.value_changed.connect(func(val: float):
		curve_setting.set_value(val)
		curve_slider_lbl.text = "Curvature: %.2fx" % val
	)

	curve_minus_btn.pressed.connect(func():
		curve_slider.value = clamp(curve_slider.value - 0.05, curve_slider.min_value, curve_slider.max_value)
	)
	curve_plus_btn.pressed.connect(func():
		curve_slider.value = clamp(curve_slider.value + 0.05, curve_slider.min_value, curve_slider.max_value)
	)

	gameplay_vbox.add_child(curve_slider_container)

	# Create and insert Gimme Range configuration settings rows in the Gameplay tab
	var gimme_sep = HSeparator.new()
	gameplay_vbox.add_child(gimme_sep)
	
	var gimme_label = Label.new()
	gimme_label.text = "Gimme Ranges"
	gimme_label.add_theme_font_size_override("font_size", 22)
	gimme_label.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	gameplay_vbox.add_child(gimme_label)
	
	var gimme_1_toggle = _create_toggle_setting_row("Gimme +1 Circle", "gimme_range_1_enabled")
	var gimme_2_toggle = _create_toggle_setting_row("Gimme +2 Circle", "gimme_range_2_enabled")
	var gimme_3_toggle = _create_toggle_setting_row("Gimme +3 Circle", "gimme_range_3_enabled")
	var gimme_toggles_grid = _create_toggle_grid([gimme_1_toggle, gimme_2_toggle, gimme_3_toggle], 3)
	gameplay_vbox.add_child(gimme_toggles_grid)
	
	var gimme_1_dist = _create_spinbox_setting_row("Gimme +1 Distance", "gimme_range_1_distance", 1.0, 100.0, 0.5, "ft")
	var gimme_2_dist = _create_spinbox_setting_row("Gimme +2 Distance", "gimme_range_2_distance", 1.0, 100.0, 0.5, "ft")
	var gimme_3_dist = _create_spinbox_setting_row("Gimme +3 Distance", "gimme_range_3_distance", 1.0, 100.0, 0.5, "ft")
	var gimme_dist_grid = _create_range_grid([gimme_1_dist, gimme_2_dist, gimme_3_dist], 2)
	gameplay_vbox.add_child(gimme_dist_grid)

	var turn_sep = HSeparator.new()
	gameplay_vbox.add_child(turn_sep)
	
	var turn_label = Label.new()
	turn_label.text = "Audio & Turn Settings"
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	gameplay_vbox.add_child(turn_label)
	
	var turn_order_row = _create_option_setting_row("Turn Order Mode", "turn_order_mode", ["Stay Up", "Classic", "Full Hole"])
	gameplay_vbox.add_child(turn_order_row)
	
	var custom_next_player_toggle = _create_toggle_setting_row("Repeat Shot <= 35% Dist", "custom_next_player")
	var golf_clap_toggle = _create_toggle_setting_row("Golf Clap Audio", "golf_clap_enabled")
	var ambient_sound_toggle = _create_toggle_setting_row("Ambient Nature Sounds", "ambient_sound_enabled")
	var menu_music_toggle = _create_toggle_setting_row("Menu Soundtrack", "menu_music_enabled")
	var minigame_music_toggle = _create_toggle_setting_row("Minigame Music Soundtrack", "minigame_music_enabled")
	var suspense_toggle = _create_toggle_setting_row("Course Play Suspense", "tension_effects_enabled")
	var shot_analysis_toggle = _create_toggle_setting_row("Shot Analysis Suggestions", "shot_analysis_enabled")
	var ball_rollout_toggle = _create_toggle_setting_row("Ball Rollout", "ball_rollout_enabled")
	var track_averages_toggle = _create_toggle_setting_row("Track Club Distances & Averages", "track_club_averages")

	var audio_toggles_grid = _create_toggle_grid([
		custom_next_player_toggle,
		golf_clap_toggle,
		ambient_sound_toggle,
		menu_music_toggle,
		minigame_music_toggle,
		suspense_toggle,
		shot_analysis_toggle,
		ball_rollout_toggle,
		track_averages_toggle
	], 3)
	gameplay_vbox.add_child(audio_toggles_grid)

	var gs_sep = HSeparator.new()
	gameplay_vbox.add_child(gs_sep)
	
	var green_speed_row = _create_slider_setting_row("Green Speed", "green_speed", 5.0, 16.0, 0.5)
	var green_speed_grid = _create_range_grid([green_speed_row], 2)
	gameplay_vbox.add_child(green_speed_grid)


	# Create and insert camera configuration settings rows in the Camera tab
	camera_vbox = $MarginContainer/VBoxContainer/TabContainer/Camera/MarginContainer/CameraVBox
	
	var height_row = _create_spinbox_setting_row("Camera Height", "camera_height", 0.5, 10.0, 0.1, "m")
	var dist_row = _create_spinbox_setting_row("Camera Distance", "camera_distance", 1.0, 30.0, 0.1, "m")
	var fov_row = _create_spinbox_setting_row("Camera FOV", "camera_fov", 1.0, 90.0, 0.1, "deg")
	var far_row = _create_spinbox_setting_row("Camera Far", "camera_far", 100.0, 1000.0, 1.0, "m")
	var ball_scale_row = _create_spinbox_setting_row("Ball Visual Size", "ball_visual_scale", 1.0, 2.5, 0.05, "x")
	
	var camera_range_grid = _create_range_grid([dist_row, height_row, fov_row, far_row, ball_scale_row], 2)
	camera_vbox.add_child(camera_range_grid)
	
	# Visual effects separator
	var fx_sep = HSeparator.new()
	camera_vbox.add_child(fx_sep)

	var fx_label = Label.new()
	fx_label.text = "Visual Effects"
	fx_label.add_theme_font_size_override("font_size", 22)
	fx_label.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	camera_vbox.add_child(fx_label)
	
	var graphics_options: Array[String] = (["Low", "Medium"] as Array[String]) if MobilePerformance.is_mobile() else (["Low", "Medium", "High"] as Array[String])
	if MobilePerformance.is_mobile() and GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("graphics_quality"):
		if str(GlobalSettings.range_settings.settings["graphics_quality"].value) == "High":
			GlobalSettings.range_settings.settings["graphics_quality"].set_value("Medium")
	var graphics_row = _create_option_setting_row("Graphics Quality", "graphics_quality", graphics_options)
	camera_vbox.add_child(graphics_row)
	
	var visual_toggles: Array[Control] = []
	if GlobalSettings != null and GlobalSettings.has_method("is_fullscreen_supported") and GlobalSettings.is_fullscreen_supported():
		var fs_row = _create_fullscreen_setting_row("Windowed Full Screen")
		visual_toggles.append(fs_row)
	
	# DOF toggle
	var dof_row = _create_toggle_setting_row("Depth of Field", "dof_enabled")
	visual_toggles.append(dof_row)
	
	# Vignette toggle
	var vig_row = _create_toggle_setting_row("Vignette", "vignette_enabled")
	visual_toggles.append(vig_row)
	
	var visual_toggles_grid = _create_toggle_grid(visual_toggles, 3)
	camera_vbox.add_child(visual_toggles_grid)
	
	# DOF blur amount and Vignette intensity
	var blur_row = _create_spinbox_setting_row("DOF Blur", "dof_blur_amount", 0.0, 0.3, 0.01, "")
	var vig_int_row = _create_spinbox_setting_row("Vignette Intensity", "vignette_intensity", 0.0, 3.0, 0.1, "")
	var vfx_range_grid = _create_range_grid([blur_row, vig_int_row], 2)
	camera_vbox.add_child(vfx_range_grid)

	# Add Close button dynamically to ButtonsHBox and style all buttons
	var buttons_hbox = get_node_or_null("MarginContainer/VBoxContainer/ButtonsHBox")
	if buttons_hbox != null:
		var reset_btn = buttons_hbox.get_node_or_null("ResetLayoutButton")
		if reset_btn != null:
			reset_btn.custom_minimum_size = Vector2(170, 54)
			reset_btn.add_theme_font_size_override("font_size", 18)
			ThemeManager.apply_secondary_button_style(reset_btn, 8)

		var exit_btn = buttons_hbox.get_node_or_null("ExitButton")
		if exit_btn != null:
			exit_btn.custom_minimum_size = Vector2(170, 54)
			exit_btn.add_theme_font_size_override("font_size", 18)
			ThemeManager.apply_danger_button_style(exit_btn, 8)

		if not MultiplayerManager.players.is_empty() and not MultiplayerManager.practice_mode_active:
			var players_btn = Button.new()
			players_btn.name = "PlayersButton"
			players_btn.text = "👥 Players"
			players_btn.custom_minimum_size = Vector2(170, 54)
			players_btn.add_theme_font_size_override("font_size", 18)
			ThemeManager.apply_primary_button_style(players_btn, 8)
			players_btn.pressed.connect(func():
				manage_players_requested.emit()
				request_close()
			)
			buttons_hbox.add_child(players_btn)

		var close_btn = Button.new()
		close_btn.name = "CloseButton"
		close_btn.text = "Close"
		close_btn.custom_minimum_size = Vector2(170, 54)
		close_btn.add_theme_font_size_override("font_size", 18)
		close_btn.focus_mode = Control.FOCUS_ALL
		ThemeManager.apply_primary_button_style(close_btn, 8)
		close_btn.pressed.connect(func(): request_close())
		buttons_hbox.add_child(close_btn)

	# Ensure all tabs (including dynamically added Keybindings and Developer tabs) have styled scrollbars and non-overlapping margins
	if tab_container != null:
		for child in tab_container.get_children():
			if child is ScrollContainer:
				_apply_tab_scroll_style(child)


func request_close() -> void:
	visible = false
	var curr: Node = get_parent() if is_inside_tree() else null
	while curr != null and is_instance_valid(curr):
		if curr is CanvasLayer or curr.name == "SettingsLayer" or curr.name.ends_with("Settings") or curr.name == "SettingsModalLayer":
			if "visible" in curr:
				curr.visible = false
		if not curr.is_inside_tree():
			break
		curr = curr.get_parent()
	var vp = get_viewport()
	if vp != null:
		vp.gui_release_focus()
	close_settings_requested.emit()
	_on_close_settings_requested()


func _on_close_settings_requested() -> void:
	if not is_inside_tree():
		return
	visible = false
	var curr: Node = get_parent() if is_inside_tree() else null
	while curr != null and is_instance_valid(curr):
		if curr is CanvasLayer or curr.name == "SettingsLayer" or curr.name.ends_with("Settings") or curr.name == "SettingsModalLayer":
			if "visible" in curr:
				curr.visible = false
		if not curr.is_inside_tree():
			break
		curr = curr.get_parent()
	var vp = get_viewport()
	if vp != null:
		vp.gui_release_focus()
	if GlobalSettings and GlobalSettings.range_settings and "graphics_quality" in GlobalSettings.range_settings:
		GlobalSettings.save_settings()
		var q = str(GlobalSettings.range_settings.graphics_quality.value)
		if _graphics_quality_changed or q != _last_applied_graphics_quality:
			_graphics_quality_changed = false
			_last_applied_graphics_quality = q
			print("[RangeSettings] Graphics quality setting changed to '%s'. Reloading graphics in scene tree with spinner..." % q)
			MobilePerformance.apply_graphics_quality_with_spinner(get_tree(), q)


var _last_opened_msec: int = 0

func _on_settings_opened() -> void:
	var now = Time.get_ticks_msec()
	if now - _last_opened_msec < 500:
		return
	_last_opened_msec = now
	_sync_wind_slider()
	_sync_fullscreen_toggle()
	_refresh_keybinding_buttons()
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("SpeakSettingsOpened")
	call_deferred("_focus_initial_control")


func _focus_initial_control() -> void:
	if not is_visible_in_tree():
		return
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	if tab_container != null and tab_container.is_visible_in_tree():
		var cur_tab = tab_container.get_current_tab_control()
		if cur_tab != null and KeybindingManager.focus_first_control(cur_tab):
			return
	var header_close = get_node_or_null("MarginContainer/VBoxContainer/HeaderHBox/HeaderCloseButton")
	if header_close != null and header_close.is_visible_in_tree():
		header_close.grab_focus()


func _sync_wind_slider() -> void:
	if _wind_slider != null and GlobalSettings != null:
		var spd: float = GlobalSettings.current_wind_speed_mph
		_wind_slider.set_value_no_signal(spd)
		if _wind_slider_lbl != null:
			if spd <= 0.0:
				_wind_slider_lbl.text = "Wind Speed: 0 MPH (Calm)"
			else:
				_wind_slider_lbl.text = "Wind Speed: %d MPH" % int(spd)


func _sync_fullscreen_toggle() -> void:
	if _fullscreen_check != null and is_instance_valid(_fullscreen_check) and GlobalSettings != null and GlobalSettings.has_method("is_fullscreen"):
		_fullscreen_check.set_pressed_no_signal(GlobalSettings.is_fullscreen())


func _on_header_close_button_pressed() -> void:
	request_close()


func _on_settings_button_pressed() -> void:
	toggle_settings_requested.emit()


func _on_background_clicked(event: InputEvent) -> void:
	# Close the menu when clicking on the background
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_close()


func _on_exit_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_reset_layout_button_pressed() -> void:
	GlobalSettings.range_settings.displayed_stats.set_value(StatDefinitions.DEFAULT_ENABLED_STAT_IDS.duplicate())
	GlobalSettings.save_settings()
	_setup_displayed_stats_section()
	var grid_canvas = get_node_or_null("../../../GridCanvas")
	if grid_canvas != null and grid_canvas.has_method("reset_layout"):
		grid_canvas.reset_layout()
	else:
		var dir = DirAccess.open("user://")
		if dir and dir.file_exists("layout.cfg"):
			dir.remove("layout.cfg")


func _on_units_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		GlobalSettings.range_settings.range_units.set_value(PhysicsEnums.Units.METRIC)
	else:
		GlobalSettings.range_settings.range_units.set_value(PhysicsEnums.Units.IMPERIAL)


func _on_camer_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.range_settings.camera_follow_mode.set_value(toggled_on)


func _on_shot_replay_follow_check_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.range_settings.shot_replay_follow.set_value(toggled_on)


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
	GlobalSettings.range_settings.ball_type.set_value(index)


func _setup_square_monitor_section() -> void:
	if not has_node("/root/LaunchMonitorManager"):
		_square_debug("LaunchMonitorManager singleton not found; Square section not created.")
		return

	var launch_monitor = get_node("/root/LaunchMonitorManager")
	_square_debug("Creating Square settings section. Initial status=%s" % str(launch_monitor.status))
	var root := $MarginContainer/VBoxContainer/TabContainer/LaunchMonitor/MarginContainer/LaunchMonitorVBox
	var section := VBoxContainer.new()
	section.name = "SquareMonitor"
	section.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Bluetooth Launch Monitor (Square Golf / Garmin Approach R10)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	section.add_child(title)

	square_enabled_button = CheckButton.new()
	square_enabled_button.custom_minimum_size = Vector2(72, 48)
	square_enabled_button.set_pressed_no_signal(bool(launch_monitor.settings.get("enabled", false)))
	square_enabled_button.toggled.connect(_on_square_enabled_toggled)
	var enabled_row := _create_toggle_widget("Enabled", square_enabled_button)

	var square_remember_button := CheckButton.new()
	square_remember_button.custom_minimum_size = Vector2(72, 48)
	square_remember_button.set_pressed_no_signal(bool(launch_monitor.settings.get("remember_device", false)))
	square_remember_button.toggled.connect(func(toggled_on: bool):
		launch_monitor.set_remember_device(toggled_on)
	)
	var remember_row := _create_toggle_widget("Remember Device (Auto-Connect on Startup)", square_remember_button)
	section.add_child(_create_toggle_grid([enabled_row, remember_row], 2))

	var type_row := HBoxContainer.new()
	type_row.custom_minimum_size = Vector2(0, 52)
	type_row.add_child(_make_label("Device Type"))
	square_device_type_option = OptionButton.new()
	square_device_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	square_device_type_option.add_item("Auto-Detect (Recommended)", 0)
	square_device_type_option.set_item_metadata(0, "auto")
	square_device_type_option.add_item("Square Golf", 1)
	square_device_type_option.set_item_metadata(1, "square")
	square_device_type_option.add_item("Garmin Approach R10", 2)
	square_device_type_option.set_item_metadata(2, "garmin")
	var saved_t := str(launch_monitor.settings.get("device_type", "auto"))
	match saved_t:
		"square": square_device_type_option.select(1)
		"garmin": square_device_type_option.select(2)
		_: square_device_type_option.select(0)
	square_device_type_option.item_selected.connect(func(idx: int):
		var val := str(square_device_type_option.get_item_metadata(idx))
		launch_monitor.set_device_type(val)
		_refresh_square_devices()
	)
	_setup_touch_option_button(square_device_type_option)
	type_row.add_child(square_device_type_option)
	section.add_child(type_row)

	var device_row := HBoxContainer.new()
	device_row.custom_minimum_size = Vector2(0, 52)
	device_row.add_child(_make_label("Device"))
	square_device_option = OptionButton.new()
	square_device_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_touch_option_button(square_device_option)
	square_device_option.item_selected.connect(_on_square_device_selected)
	device_row.add_child(square_device_option)
	section.add_child(device_row)

	var status_info_vbox := VBoxContainer.new()
	status_info_vbox.name = "SquareStatusInfo"
	status_info_vbox.add_theme_constant_override("separation", 6)

	square_status_label = Label.new()
	square_status_label.add_theme_font_size_override("font_size", 18)
	square_status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)

	square_battery_label = Label.new()
	square_battery_label.add_theme_font_size_override("font_size", 18)
	square_battery_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)

	square_firmware_label = Label.new()
	square_firmware_label.add_theme_font_size_override("font_size", 18)
	square_firmware_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)

	status_info_vbox.add_child(square_status_label)
	status_info_vbox.add_child(square_battery_label)
	status_info_vbox.add_child(square_firmware_label)
	section.add_child(status_info_vbox)

	var action_row := HBoxContainer.new()
	action_row.custom_minimum_size = Vector2(0, 52)
	action_row.add_theme_constant_override("separation", 12)
	
	square_scan_button = Button.new()
	square_scan_button.text = "Scan"
	square_scan_button.custom_minimum_size = Vector2(120, 52)
	square_scan_button.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_secondary_button_style(square_scan_button, 8)
	square_scan_button.pressed.connect(_on_square_scan_pressed)
	action_row.add_child(square_scan_button)
	
	square_connect_button = Button.new()
	square_connect_button.text = "Connect"
	square_connect_button.custom_minimum_size = Vector2(120, 52)
	square_connect_button.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_primary_button_style(square_connect_button, 8)
	square_connect_button.pressed.connect(_on_square_connect_pressed)
	action_row.add_child(square_connect_button)
	
	square_disconnect_button = Button.new()
	square_disconnect_button.text = "Disconnect"
	square_disconnect_button.custom_minimum_size = Vector2(120, 52)
	square_disconnect_button.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_danger_button_style(square_disconnect_button, 8)
	square_disconnect_button.pressed.connect(_on_square_disconnect_pressed)
	action_row.add_child(square_disconnect_button)
	
	square_ready_button = Button.new()
	square_ready_button.text = "Ready"
	square_ready_button.custom_minimum_size = Vector2(120, 52)
	square_ready_button.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_primary_button_style(square_ready_button, 8)
	square_ready_button.pressed.connect(_on_square_ready_pressed)
	action_row.add_child(square_ready_button)

	garmin_calibrate_button = Button.new()
	garmin_calibrate_button.text = "Calibrate Tilt"
	garmin_calibrate_button.custom_minimum_size = Vector2(140, 52)
	garmin_calibrate_button.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_secondary_button_style(garmin_calibrate_button, 8)
	garmin_calibrate_button.pressed.connect(func():
		launch_monitor.calibrate_garmin_tilt()
	)
	action_row.add_child(garmin_calibrate_button)
	
	section.add_child(action_row)

	var club_row := HBoxContainer.new()
	club_row.custom_minimum_size = Vector2(0, 52)
	club_row.add_child(_make_label("Club"))
	square_club_option = OptionButton.new()
	square_club_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for club_name in SQUARE_CLUBS.keys():
		var index := square_club_option.item_count
		square_club_option.add_item(club_name)
		square_club_option.set_item_metadata(index, SQUARE_CLUBS[club_name])
	var current_club := str(launch_monitor.settings.get("club_code", "0104"))
	_select_option_by_metadata(square_club_option, current_club)
	square_club_option.item_selected.connect(_on_square_club_selected)
	_setup_touch_option_button(square_club_option)
	club_row.add_child(square_club_option)
	section.add_child(club_row)

	var handedness_row := HBoxContainer.new()
	handedness_row.custom_minimum_size = Vector2(0, 52)
	handedness_row.add_child(_make_label("Handedness"))
	square_handedness_option = OptionButton.new()
	square_handedness_option.add_item("Right", 0)
	square_handedness_option.add_item("Left", 1)
	var handedness := int(launch_monitor.settings.get("handedness", 0))
	var hand_index := square_handedness_option.get_item_index(handedness)
	if hand_index >= 0:
		square_handedness_option.select(hand_index)
	square_handedness_option.item_selected.connect(_on_square_handedness_selected)
	_setup_touch_option_button(square_handedness_option)
	handedness_row.add_child(square_handedness_option)
	section.add_child(handedness_row)

	var sound_button := CheckButton.new()
	sound_button.custom_minimum_size = Vector2(72, 48)
	sound_button.set_pressed_no_signal(bool(launch_monitor.settings.get("ready_ding_enabled", true)))
	sound_button.toggled.connect(func(toggled_on: bool):
		launch_monitor.set_ready_ding_enabled(toggled_on)
	)
	var sound_row := _create_toggle_widget("Ready Sound", sound_button)

	var hud_button := CheckButton.new()
	hud_button.custom_minimum_size = Vector2(72, 48)
	hud_button.set_pressed_no_signal(bool(launch_monitor.settings.get("ready_indicator_enabled", true)))
	hud_button.toggled.connect(func(toggled_on: bool):
		launch_monitor.set_ready_indicator_enabled(toggled_on)
	)
	var hud_row := _create_toggle_widget("Ready Indicator", hud_button)

	var guide_button := CheckButton.new()
	guide_button.custom_minimum_size = Vector2(72, 48)
	guide_button.set_pressed_no_signal(bool(launch_monitor.settings.get("ball_placement_guide_enabled", true)))
	guide_button.toggled.connect(func(toggled_on: bool):
		if launch_monitor.has_method("set_ball_placement_guide_enabled"):
			launch_monitor.set_ball_placement_guide_enabled(toggled_on)
	)
	var guide_row := _create_toggle_widget("Placement Guide", guide_button)

	var lm_toggles_grid = _create_toggle_grid([sound_row, hud_row, guide_row], 3)
	section.add_child(lm_toggles_grid)

	root.add_child(section)

	if not launch_monitor.device_discovered.is_connected(_on_square_device_discovered):
		launch_monitor.device_discovered.connect(_on_square_device_discovered)
	if not launch_monitor.status_changed.is_connected(_on_square_status_changed):
		launch_monitor.status_changed.connect(_on_square_status_changed)
	if not launch_monitor.error_occurred.is_connected(_on_square_error_occurred):
		launch_monitor.error_occurred.connect(_on_square_error_occurred)
	if not launch_monitor.battery_changed.is_connected(_on_square_battery_changed):
		launch_monitor.battery_changed.connect(_on_square_battery_changed)
	if not launch_monitor.firmware_changed.is_connected(_on_square_firmware_changed):
		launch_monitor.firmware_changed.connect(_on_square_firmware_changed)
	if not launch_monitor.ready_changed.is_connected(_on_square_ready_changed):
		launch_monitor.ready_changed.connect(_on_square_ready_changed)
	if not launch_monitor.club_code_changed.is_connected(_on_square_club_code_changed):
		launch_monitor.club_code_changed.connect(_on_square_club_code_changed)

	_refresh_square_devices()
	_update_square_status_labels()


func _setup_tcp_monitor_section() -> void:
	var root := $MarginContainer/VBoxContainer/TabContainer/LaunchMonitor/MarginContainer/LaunchMonitorVBox
	
	var sep := HSeparator.new()
	root.add_child(sep)
	
	var section := VBoxContainer.new()
	section.name = "TcpMonitorSection"
	section.add_theme_constant_override("separation", 14)
	
	var title := Label.new()
	title.text = "GSPro / Network Launch Monitor (TCP)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	section.add_child(title)
	
	var desc := Label.new()
	desc.text = "Receives GSPro Open Connect v1 shot packets over TCP from external bridges (PiTrac, MLM2PRO, Garmin R10, FlightScope, Uneekor, Bushnell, inject_shot.py)."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	section.add_child(desc)
	
	# Current values
	var current_port: int = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
	var current_ip: String = str(GlobalSettings.range_settings.tcp_server_ip.value) if "tcp_server_ip" in GlobalSettings.range_settings else "0.0.0.0"
	
	# Status Label
	var tcp_status_lbl := Label.new()
	tcp_status_lbl.name = "TcpStatusLabel"
	tcp_status_lbl.add_theme_font_size_override("font_size", 17)
	tcp_status_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.55))
	
	var update_status_text = func():
		var p = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
		var ip = str(GlobalSettings.range_settings.tcp_server_ip.value) if "tcp_server_ip" in GlobalSettings.range_settings else "0.0.0.0"
		var host_str = ip if ip != "0.0.0.0" and ip != "*" else "all interfaces (0.0.0.0)"
		tcp_status_lbl.text = "🟢 Active Listener: %s on port %d" % [host_str, p]
	
	update_status_text.call()
	section.add_child(tcp_status_lbl)
	
	# Port Row
	var port_row := HBoxContainer.new()
	port_row.custom_minimum_size = Vector2(0, 52)
	port_row.add_theme_constant_override("separation", 10)
	port_row.add_child(_make_label("Port"))
	
	var btn_49152 := Button.new()
	btn_49152.text = "49152 (Default)"
	btn_49152.custom_minimum_size = Vector2(150, 48)
	btn_49152.add_theme_font_size_override("font_size", 16)
	port_row.add_child(btn_49152)
	
	var btn_921 := Button.new()
	btn_921.text = "921 (Legacy GSPro v1)"
	btn_921.custom_minimum_size = Vector2(190, 48)
	btn_921.add_theme_font_size_override("font_size", 16)
	port_row.add_child(btn_921)
	
	var port_spin := SpinBox.new()
	port_spin.min_value = 1
	port_spin.max_value = 65535
	port_spin.step = 1
	port_spin.value = current_port
	port_spin.custom_minimum_size = Vector2(130, 48)
	var spin_le = port_spin.get_line_edit()
	if spin_le != null:
		spin_le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		spin_le.add_theme_font_size_override("font_size", 18)
		ThemeManager.apply_input_style(spin_le, 8)
	port_row.add_child(port_spin)
	
	section.add_child(port_row)
	
	# Bind IP Row
	var ip_row := HBoxContainer.new()
	ip_row.custom_minimum_size = Vector2(0, 52)
	ip_row.add_theme_constant_override("separation", 10)
	ip_row.add_child(_make_label("Bind IP"))
	
	var btn_ip_all := Button.new()
	btn_ip_all.text = "0.0.0.0 (All)"
	btn_ip_all.custom_minimum_size = Vector2(150, 48)
	btn_ip_all.add_theme_font_size_override("font_size", 16)
	ip_row.add_child(btn_ip_all)
	
	var btn_ip_local := Button.new()
	btn_ip_local.text = "127.0.0.1 (Local)"
	btn_ip_local.custom_minimum_size = Vector2(160, 48)
	btn_ip_local.add_theme_font_size_override("font_size", 16)
	ip_row.add_child(btn_ip_local)
	
	var ip_input := LineEdit.new()
	ip_input.text = current_ip
	ip_input.placeholder_text = "0.0.0.0"
	ip_input.custom_minimum_size = Vector2(140, 48)
	ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_input.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_input_style(ip_input, 8)
	ip_row.add_child(ip_input)
	
	section.add_child(ip_row)
	
	# LAN IP hint
	var lan_lbl := Label.new()
	var lan_ip := "127.0.0.1"
	for addr in IP.get_local_addresses():
		if not addr.contains(":") and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			lan_ip = addr
			break
	lan_lbl.text = "💡 Local Network IP: %s (configure this destination in phone or tablet connector apps on Wi-Fi)" % lan_ip
	lan_lbl.add_theme_font_size_override("font_size", 14)
	lan_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	lan_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(lan_lbl)
	
	# Highlight helper
	var update_buttons_and_restart = func(new_port: int, new_ip: String):
		if "tcp_server_port" in GlobalSettings.range_settings:
			GlobalSettings.range_settings.tcp_server_port.set_value(new_port)
		if "tcp_server_ip" in GlobalSettings.range_settings:
			GlobalSettings.range_settings.tcp_server_ip.set_value(new_ip)
		GlobalSettings.save_settings()
		
		# Update UI
		if int(port_spin.value) != new_port:
			port_spin.set_value_no_signal(new_port)
		if ip_input.text != new_ip:
			ip_input.text = new_ip
			
		if new_port == 49152:
			ThemeManager.apply_primary_button_style(btn_49152, 8)
			ThemeManager.apply_secondary_button_style(btn_921, 8)
		elif new_port == 921:
			ThemeManager.apply_secondary_button_style(btn_49152, 8)
			ThemeManager.apply_primary_button_style(btn_921, 8)
		else:
			ThemeManager.apply_secondary_button_style(btn_49152, 8)
			ThemeManager.apply_secondary_button_style(btn_921, 8)
			
		if new_ip == "0.0.0.0" or new_ip == "*":
			ThemeManager.apply_primary_button_style(btn_ip_all, 8)
			ThemeManager.apply_secondary_button_style(btn_ip_local, 8)
		elif new_ip == "127.0.0.1":
			ThemeManager.apply_secondary_button_style(btn_ip_all, 8)
			ThemeManager.apply_primary_button_style(btn_ip_local, 8)
		else:
			ThemeManager.apply_secondary_button_style(btn_ip_all, 8)
			ThemeManager.apply_secondary_button_style(btn_ip_local, 8)
			
		update_status_text.call()
		
		# Restart any active TCPServer in scene
		var scene_tcp = get_tree().root.find_child("TCPServer", true, false)
		if scene_tcp != null and scene_tcp.has_method("Restart"):
			scene_tcp.call("Restart", new_port, new_ip)
	
	# Initial button highlight
	var init_p = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
	var init_ip = str(GlobalSettings.range_settings.tcp_server_ip.value) if "tcp_server_ip" in GlobalSettings.range_settings else "0.0.0.0"
	update_buttons_and_restart.call(init_p, init_ip)
	
	btn_49152.pressed.connect(func():
		var current_ip_val = str(GlobalSettings.range_settings.tcp_server_ip.value) if "tcp_server_ip" in GlobalSettings.range_settings else "0.0.0.0"
		update_buttons_and_restart.call(49152, current_ip_val)
	)
	btn_921.pressed.connect(func():
		var current_ip_val = str(GlobalSettings.range_settings.tcp_server_ip.value) if "tcp_server_ip" in GlobalSettings.range_settings else "0.0.0.0"
		update_buttons_and_restart.call(921, current_ip_val)
	)
	port_spin.value_changed.connect(func(v: float):
		var current_ip_val = str(GlobalSettings.range_settings.tcp_server_ip.value) if "tcp_server_ip" in GlobalSettings.range_settings else "0.0.0.0"
		update_buttons_and_restart.call(int(v), current_ip_val)
	)
	btn_ip_all.pressed.connect(func():
		var current_p_val = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
		update_buttons_and_restart.call(current_p_val, "0.0.0.0")
	)
	btn_ip_local.pressed.connect(func():
		var current_p_val = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
		update_buttons_and_restart.call(current_p_val, "127.0.0.1")
	)
	ip_input.text_changed.connect(func(txt: String):
		var current_p_val = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
		var trimmed = txt.strip_edges()
		if trimmed.is_empty():
			trimmed = "0.0.0.0"
		if "tcp_server_ip" in GlobalSettings.range_settings:
			GlobalSettings.range_settings.tcp_server_ip.set_value(trimmed)
		GlobalSettings.save_settings()
		update_status_text.call()
		var scene_tcp = get_tree().root.find_child("TCPServer", true, false)
		if scene_tcp != null and scene_tcp.has_method("Restart"):
			scene_tcp.call("Restart", current_p_val, trimmed)
	)
	ip_input.text_submitted.connect(func(txt: String):
		var current_p_val = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
		update_buttons_and_restart.call(current_p_val, txt.strip_edges() if not txt.strip_edges().is_empty() else "0.0.0.0")
	)
	ip_input.focus_exited.connect(func():
		var current_p_val = int(GlobalSettings.range_settings.tcp_server_port.value) if "tcp_server_port" in GlobalSettings.range_settings else 49152
		update_buttons_and_restart.call(current_p_val, ip_input.text.strip_edges() if not ip_input.text.strip_edges().is_empty() else "0.0.0.0")
	)
	
	root.add_child(section)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.custom_minimum_size = Vector2(140, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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


func _on_square_device_selected(index: int) -> void:
	if square_device_option == null or not has_node("/root/LaunchMonitorManager") or index < 0:
		return
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	var dev_id := str(square_device_option.get_item_metadata(index))
	if dev_id == "":
		return
	launch_monitor.settings["device_id"] = dev_id
	if launch_monitor.devices.has(dev_id):
		var dev = launch_monitor.devices[dev_id]
		launch_monitor.settings["device_name"] = str(dev.get("name", ""))
	launch_monitor._save_settings()
	_square_debug("Selected device_id=%s (%s)" % [dev_id, launch_monitor.settings.get("device_name", "")])


func _refresh_square_devices(preferred_device_id: String = "") -> void:
	if square_device_option == null or not has_node("/root/LaunchMonitorManager"):
		return
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	var selected_device := preferred_device_id
	if selected_device == "":
		selected_device = str(launch_monitor.settings.get("device_id", ""))
	var saved_name := str(launch_monitor.settings.get("device_name", ""))
	var saved_t := str(launch_monitor.settings.get("device_type", "auto"))
	if saved_name == "":
		saved_name = "Square Golf" if saved_t != "garmin" else "Garmin Approach R10"
	if selected_device != "" and not launch_monitor.devices.has(selected_device):
		launch_monitor.devices[selected_device] = {
			"name": saved_name,
			"rssi": 0,
			"type": saved_t if saved_t != "auto" else launch_monitor.detect_device_type(selected_device, saved_name),
			"is_discovered": false
		}

	var matching_keys: Array[String] = []
	for device_id in launch_monitor.devices.keys():
		var device = launch_monitor.devices[device_id]
		var dev_name: String = str(device.get("name", "Launch Monitor"))
		var dev_type: String = str(device.get("type", ""))
		if dev_type == "":
			dev_type = launch_monitor.detect_device_type(device_id, dev_name)

		if saved_t == "square" and dev_type != "square":
			continue
		if saved_t == "garmin" and dev_type != "garmin":
			continue
		matching_keys.append(device_id)

	# Sort matching keys: live discovered devices first (highest RSSI first), then offline devices
	matching_keys.sort_custom(func(a, b):
		var dev_a = launch_monitor.devices[a]
		var dev_b = launch_monitor.devices[b]
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

	var active_live_keys: Array[String] = []
	for k in matching_keys:
		if bool(launch_monitor.devices[k].get("is_discovered", false)):
			active_live_keys.append(k)

	if preferred_device_id != "" and matching_keys.has(preferred_device_id) and bool(launch_monitor.devices[preferred_device_id].get("is_discovered", false)):
		selected_device = preferred_device_id
	else:
		var current_is_live := matching_keys.has(selected_device) and bool(launch_monitor.devices[selected_device].get("is_discovered", false))
		if not current_is_live and not active_live_keys.is_empty():
			selected_device = active_live_keys[0]
		elif (selected_device == "" or not matching_keys.has(selected_device)) and matching_keys.size() > 0:
			selected_device = matching_keys[0]

	if selected_device != "":
		launch_monitor.settings["device_id"] = selected_device
		if launch_monitor.devices.has(selected_device):
			var dev = launch_monitor.devices[selected_device]
			launch_monitor.settings["device_name"] = str(dev.get("name", ""))
		launch_monitor._save_settings()

	# Avoid clearing dropdown if items are already identical (prevents closing popup while user interacts)
	var needs_rebuild := false
	if square_device_option.item_count != matching_keys.size():
		needs_rebuild = true
	else:
		for i in range(matching_keys.size()):
			if str(square_device_option.get_item_metadata(i)) != matching_keys[i]:
				needs_rebuild = true
				break

	if needs_rebuild:
		square_device_option.clear()
		for device_id in matching_keys:
			var device = launch_monitor.devices[device_id]
			var dev_name: String = str(device.get("name", "Launch Monitor"))
			var dev_type: String = str(device.get("type", ""))
			var is_live: bool = bool(device.get("is_discovered", false))
			if dev_type == "":
				dev_type = launch_monitor.detect_device_type(device_id, dev_name)

			var prefix := ""
			if saved_t == "auto":
				prefix = "[Garmin R10] " if dev_type == "garmin" else "[Square] "
			var live_suffix := " 📶" if is_live else " (Offline)"
			var label := prefix + dev_name + live_suffix
			var index := square_device_option.item_count
			square_device_option.add_item(label)
			square_device_option.set_item_metadata(index, device_id)

	for index in range(square_device_option.item_count):
		if str(square_device_option.get_item_metadata(index)) == selected_device:
			if square_device_option.selected != index:
				square_device_option.select(index)
			break


func _exit_tree() -> void:
	if has_node("/root/LaunchMonitorManager"):
		var launch_monitor = get_node("/root/LaunchMonitorManager")
		if launch_monitor.device_discovered.is_connected(_on_square_device_discovered):
			launch_monitor.device_discovered.disconnect(_on_square_device_discovered)
		if launch_monitor.status_changed.is_connected(_on_square_status_changed):
			launch_monitor.status_changed.disconnect(_on_square_status_changed)
		if launch_monitor.error_occurred.is_connected(_on_square_error_occurred):
			launch_monitor.error_occurred.disconnect(_on_square_error_occurred)
		if launch_monitor.battery_changed.is_connected(_on_square_battery_changed):
			launch_monitor.battery_changed.disconnect(_on_square_battery_changed)
		if launch_monitor.firmware_changed.is_connected(_on_square_firmware_changed):
			launch_monitor.firmware_changed.disconnect(_on_square_firmware_changed)
		if launch_monitor.ready_changed.is_connected(_on_square_ready_changed):
			launch_monitor.ready_changed.disconnect(_on_square_ready_changed)


func _update_square_status_labels() -> void:
	if not has_node("/root/LaunchMonitorManager") or square_status_label == null:
		return
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	var disp_status := str(launch_monitor.status)
	if launch_monitor.is_ready and (disp_status == "Connecting" or disp_status.begins_with("Found")):
		disp_status = "Connected"
	square_status_label.text = "Status: %s" % disp_status
	if square_scan_button != null:
		square_scan_button.text = "Stop Scan" if launch_monitor.status == "Scanning" else "Scan"
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
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	if launch_monitor.status == "Scanning":
		launch_monitor.stop_scan()
		if square_scan_button != null:
			square_scan_button.text = "Scan"
	else:
		launch_monitor.start_scan()
		if square_scan_button != null:
			square_scan_button.text = "Stop Scan"


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
	if square_enabled_button != null:
		square_enabled_button.set_pressed_no_signal(false)
	var launch_monitor = get_node("/root/LaunchMonitorManager")
	launch_monitor.set_enabled(false)
	launch_monitor.disconnect_device()


func _on_square_ready_pressed() -> void:
	_square_debug("Ready pressed")
	get_node("/root/LaunchMonitorManager").set_ready()


func _on_square_club_selected(index: int) -> void:
	var club_code := str(square_club_option.get_item_metadata(index))
	get_node("/root/LaunchMonitorManager").set_club_code(club_code)


func _on_square_club_code_changed(club_code: String) -> void:
	if square_club_option != null:
		_select_option_by_metadata(square_club_option, club_code)


func _on_square_handedness_selected(index: int) -> void:
	var handedness := square_handedness_option.get_item_id(index)
	get_node("/root/LaunchMonitorManager").set_handedness(handedness)


func _on_square_device_discovered(device_id: String, name: String, rssi: int) -> void:
	_square_debug("Device discovered event received for %s (rssi=%d)" % [device_id, rssi])
	var launch_monitor = get_node_or_null("/root/LaunchMonitorManager")
	var dev = launch_monitor.devices.get(device_id, {}) if launch_monitor != null else {}
	var is_live: bool = bool(dev.get("is_discovered", false)) or ((rssi <= -10 and rssi >= -120) or (rssi != 0 and rssi != -1))
	var pref_id := device_id if is_live else ""
	_refresh_square_devices(pref_id)
	if is_live and launch_monitor != null and (launch_monitor.status == "Scanning" or launch_monitor.status.contains("Searching")):
		var display_name := name if name != "" else "Launch Monitor"
		if square_status_label != null:
			square_status_label.text = "Status: Found %s! Ready to connect." % display_name
			square_status_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))


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

	if _units_label != null and is_instance_valid(_units_label):
		if value == PhysicsEnums.Units.IMPERIAL:
			_units_label.text = "Units (Imperial)"
		else:
			_units_label.text = "Units (Metric)"

	# Block spin box signals to prevent _on_*_value_changed from firing
	# during conversion, which would double-write the setting.
	temperature_spin_box.set_block_signals(true)
	altitude_spin_box.set_block_signals(true)

	if value == PhysicsEnums.Units.IMPERIAL:
		if temperature_unit_label != null:
			temperature_unit_label.text = "F"
		var temp_f = GlobalSettings.range_settings.temperature.value * 9.0 / 5.0 + 32.0
		temperature_spin_box.value = temp_f
		GlobalSettings.range_settings.temperature.set_value(temp_f)

		if altitude_unit_label != null:
			altitude_unit_label.text = "ft"
		var alt_ft = GlobalSettings.range_settings.altitude.value * m2ft
		altitude_spin_box.value = alt_ft
		GlobalSettings.range_settings.altitude.set_value(alt_ft)
	else:
		if temperature_unit_label != null:
			temperature_unit_label.text = "C"
		var temp_c = (GlobalSettings.range_settings.temperature.value - 32.0) * 5.0 / 9.0
		temperature_spin_box.value = temp_c
		GlobalSettings.range_settings.temperature.set_value(temp_c)

		if altitude_unit_label != null:
			altitude_unit_label.text = "m"
		var alt_m = GlobalSettings.range_settings.altitude.value / m2ft
		altitude_spin_box.value = alt_m
		GlobalSettings.range_settings.altitude.set_value(alt_m)

	temperature_spin_box.set_block_signals(false)
	altitude_spin_box.set_block_signals(false)


func _create_announcer_toggle_row(label_text: String, prop_name: String, announcer: Node) -> HBoxContainer:
	var btn := CheckButton.new()
	btn.custom_minimum_size = Vector2(72, 48)
	btn.set_pressed_no_signal(bool(announcer.get(prop_name)))
	btn.toggled.connect(func(toggled_on: bool):
		announcer.set(prop_name, toggled_on)
		GlobalSettings.save_settings()
		if prop_name.begins_with("Heckle") or prop_name.begins_with("Announcer"):
			if toggled_on:
				announcer.call("SpeakHecklesEnabled")
			else:
				announcer.call("SpeakHecklesDisabled")
	)
	return _create_toggle_widget(label_text, btn)


func _setup_hecklelinks_announcer_section() -> void:
	if not has_node("/root/AnnouncerEngine"):
		return

	var announcer = get_node("/root/AnnouncerEngine")
	var root := $MarginContainer/VBoxContainer/TabContainer/Announcer/MarginContainer/AnnouncerVBox
	
	for child in root.get_children():
		child.queue_free()

	var section := VBoxContainer.new()
	section.name = "AnnouncerSettings"
	section.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "HeckleLinks Announcer Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	section.add_child(title)

	# --- 1. COURSE PLAY ---
	var course_lbl := Label.new()
	course_lbl.text = "Course Play"
	course_lbl.add_theme_font_size_override("font_size", 18)
	course_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	section.add_child(course_lbl)

	var cp_voice = _create_announcer_toggle_row("Announcer Voice", "AnnouncerCoursePlay", announcer)
	var cp_heckle = _create_announcer_toggle_row("Heckling", "HeckleCoursePlay", announcer)
	section.add_child(_create_toggle_grid([cp_voice, cp_heckle], 3))

	var sep1 := HSeparator.new()
	section.add_child(sep1)

	# --- 2. DRIVING RANGE ---
	var range_lbl := Label.new()
	range_lbl.text = "Driving Range"
	range_lbl.add_theme_font_size_override("font_size", 18)
	range_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	section.add_child(range_lbl)

	var rg_voice = _create_announcer_toggle_row("Announcer Voice", "AnnouncerRange", announcer)
	var rg_heckle = _create_announcer_toggle_row("Heckling", "HeckleRange", announcer)
	section.add_child(_create_toggle_grid([rg_voice, rg_heckle], 3))

	var sep2 := HSeparator.new()
	section.add_child(sep2)

	# --- 3. MINI GAMES ---
	var mg_lbl := Label.new()
	mg_lbl.text = "Mini Games (Putting & Chipping)"
	mg_lbl.add_theme_font_size_override("font_size", 18)
	mg_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	section.add_child(mg_lbl)

	var mg_voice = _create_announcer_toggle_row("Announcer Voice", "AnnouncerMiniGames", announcer)
	var mg_heckle = _create_announcer_toggle_row("Heckling", "HeckleMiniGames", announcer)
	section.add_child(_create_toggle_grid([mg_voice, mg_heckle], 3))

	var sep3 := HSeparator.new()
	section.add_child(sep3)

	# --- 4. VOICE OPTIONS ---
	var voice_header := Label.new()
	voice_header.text = "Voice & Commentary Options"
	voice_header.add_theme_font_size_override("font_size", 18)
	voice_header.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	section.add_child(voice_header)

	var praise_toggle = _create_announcer_toggle_row("Praise Commentary", "PraiseEnabled", announcer)
	section.add_child(_create_toggle_grid([praise_toggle], 3))

	var voice_row := HBoxContainer.new()
	voice_row.custom_minimum_size = Vector2(0, 52)
	var voice_lbl := Label.new()
	voice_lbl.text = "Voice Locale"
	voice_lbl.add_theme_font_size_override("font_size", 19)
	voice_lbl.custom_minimum_size = Vector2(200, 0)
	voice_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	voice_row.add_child(voice_lbl)
	
	var voice_opt := OptionButton.new()
	voice_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var voices = []
	if announcer.has_method("GetTtsVoices"):
		var voices_arr = announcer.call("GetTtsVoices")
		for i in range(voices_arr.size()):
			var v = voices_arr[i]
			var lang: String = v.get("language", "").to_lower()
			if lang.begins_with("en") or lang.contains("en"):
				voices.append(v)
		if voices.is_empty() and not voices_arr.is_empty():
			for i in range(voices_arr.size()):
				voices.append(voices_arr[i])
				
	if voices.is_empty():
		voices = [
			{"id": "en-US-default", "name": "US English (Default)", "language": "en_US"},
			{"id": "en-GB-default", "name": "British English", "language": "en_GB"},
			{"id": "en-US-southern", "name": "US Southern", "language": "en_US"}
		]
		
	var active_v = announcer.get("ActiveVoice")
	var active_index := 0
	for i in range(voices.size()):
		var v = voices[i]
		var v_id = v.get("id", "")
		var lang = v.get("language", "")
		var v_name = v.get("name", "")
		var label = _get_friendly_accent_name(lang) + " (" + v_name + ")"
		voice_opt.add_item(label)
		voice_opt.set_item_metadata(i, v_id)
		if v_id == active_v:
			active_index = i
			
	if voice_opt.item_count > 0:
		voice_opt.select(active_index)
		
	voice_opt.item_selected.connect(func(idx):
		var chosen_id = voice_opt.get_item_metadata(idx)
		announcer.set("ActiveVoice", chosen_id)
		GlobalSettings.save_settings()
	)
	_setup_touch_option_button(voice_opt)
	voice_row.add_child(voice_opt)
	section.add_child(voice_row)

	# Voice Pitch Slider Row with Touch Stepper
	var pitch_row := HBoxContainer.new()
	pitch_row.custom_minimum_size = Vector2(0, 52)
	pitch_row.add_theme_constant_override("separation", 10)
	pitch_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var pitch_label := Label.new()
	pitch_label.text = "Voice Pitch: %.1f" % announcer.get("Pitch")
	pitch_label.add_theme_font_size_override("font_size", 18)
	pitch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pitch_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pitch_label.tooltip_text = "Voice Pitch"
	pitch_row.add_child(pitch_label)
	
	var pitch_minus_btn := Button.new()
	pitch_minus_btn.text = "－"
	pitch_minus_btn.custom_minimum_size = Vector2(48, 48)
	pitch_minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(pitch_minus_btn, 8)
	pitch_row.add_child(pitch_minus_btn)
	
	var pitch_slider := HSlider.new()
	pitch_slider.min_value = 0.5
	pitch_slider.max_value = 2.0
	pitch_slider.step = 0.1
	pitch_slider.value = announcer.get("Pitch")
	pitch_slider.custom_minimum_size = Vector2(140, 48)
	pitch_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_slider.value_changed.connect(func(val):
		announcer.set("Pitch", val)
		pitch_label.text = "Voice Pitch: %.1f" % val
		GlobalSettings.save_settings()
	)
	pitch_row.add_child(pitch_slider)
	
	var pitch_plus_btn := Button.new()
	pitch_plus_btn.text = "＋"
	pitch_plus_btn.custom_minimum_size = Vector2(48, 48)
	pitch_plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(pitch_plus_btn, 8)
	pitch_row.add_child(pitch_plus_btn)
	
	pitch_minus_btn.pressed.connect(func():
		pitch_slider.value = clamp(pitch_slider.value - 0.1, pitch_slider.min_value, pitch_slider.max_value)
	)
	pitch_plus_btn.pressed.connect(func():
		pitch_slider.value = clamp(pitch_slider.value + 0.1, pitch_slider.min_value, pitch_slider.max_value)
	)

	# Voice Speed/Rate Slider Row with Touch Stepper
	var rate_row := HBoxContainer.new()
	rate_row.custom_minimum_size = Vector2(0, 52)
	rate_row.add_theme_constant_override("separation", 10)
	rate_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rate_label := Label.new()
	rate_label.text = "Voice Speed: %.1f" % announcer.get("Rate")
	rate_label.add_theme_font_size_override("font_size", 18)
	rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rate_label.tooltip_text = "Voice Speed"
	rate_row.add_child(rate_label)
	
	var rate_minus_btn := Button.new()
	rate_minus_btn.text = "－"
	rate_minus_btn.custom_minimum_size = Vector2(48, 48)
	rate_minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(rate_minus_btn, 8)
	rate_row.add_child(rate_minus_btn)
	
	var rate_slider := HSlider.new()
	rate_slider.min_value = 0.5
	rate_slider.max_value = 2.0
	rate_slider.step = 0.1
	rate_slider.value = announcer.get("Rate")
	rate_slider.custom_minimum_size = Vector2(140, 48)
	rate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_slider.value_changed.connect(func(val):
		announcer.set("Rate", val)
		rate_label.text = "Voice Speed: %.1f" % val
		GlobalSettings.save_settings()
	)
	rate_row.add_child(rate_slider)
	
	var rate_plus_btn := Button.new()
	rate_plus_btn.text = "＋"
	rate_plus_btn.custom_minimum_size = Vector2(48, 48)
	rate_plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(rate_plus_btn, 8)
	rate_row.add_child(rate_plus_btn)
	
	rate_minus_btn.pressed.connect(func():
		rate_slider.value = clamp(rate_slider.value - 0.1, rate_slider.min_value, rate_slider.max_value)
	)
	rate_plus_btn.pressed.connect(func():
		rate_slider.value = clamp(rate_slider.value + 0.1, rate_slider.min_value, rate_slider.max_value)
	)

	var announcer_voice_grid = _create_range_grid([pitch_row, rate_row], 2)
	section.add_child(announcer_voice_grid)

	root.add_child(section)


func _get_friendly_accent_name(lang: String) -> String:
	var clean_lang = lang.to_lower().replace("-", "_")
	if clean_lang.begins_with("en_us"):
		return "US Accent"
	elif clean_lang.begins_with("en_gb"):
		return "British Accent"
	elif clean_lang.begins_with("en_au"):
		return "Australian Accent"
	elif clean_lang.begins_with("en_in"):
		return "Indian Accent"
	elif clean_lang.begins_with("en_ca"):
		return "Canadian Accent"
	elif clean_lang.begins_with("en_ie"):
		return "Irish Accent"
	elif clean_lang.begins_with("en_za"):
		return "South African Accent"
	elif clean_lang.begins_with("en_nz"):
		return "New Zealand Accent"
	elif clean_lang.begins_with("en"):
		return "English Accent"
	else:
		return lang.to_upper() + " Accent"


func _create_range_grid(items: Array, columns: int = 2) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	for item in items:
		if item is Control:
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(item)
	var remainder = items.size() % columns
	if remainder > 0:
		for i in range(columns - remainder):
			var dummy := Control.new()
			dummy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(dummy)
	return grid


func _create_spinbox_setting_row(label_text: String, setting_name: String, min_val: float, max_val: float, step: float, suffix: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = label_text.replace(" ", "")
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label_text
	row.add_child(label)
	
	var setting = GlobalSettings.range_settings.settings[setting_name]
	
	# Minus Button
	var minus_btn = Button.new()
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(48, 48)
	minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(minus_btn, 8)
	row.add_child(minus_btn)
	
	var spinbox = SpinBox.new()
	spinbox.custom_minimum_size = Vector2(100, 48)
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step
	spinbox.value = setting.value
	
	var line_edit = spinbox.get_line_edit()
	if line_edit != null:
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.add_theme_font_size_override("font_size", 18)
		ThemeManager.apply_input_style(line_edit, 8)
		
	spinbox.value_changed.connect(func(val):
		setting.set_value(val)
	)
	row.add_child(spinbox)
	
	# Plus Button
	var plus_btn = Button.new()
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(48, 48)
	plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(plus_btn, 8)
	row.add_child(plus_btn)
	
	minus_btn.pressed.connect(func():
		spinbox.value = clamp(spinbox.value - step, spinbox.min_value, spinbox.max_value)
	)
	plus_btn.pressed.connect(func():
		spinbox.value = clamp(spinbox.value + step, spinbox.min_value, spinbox.max_value)
	)
	
	if suffix != "":
		var label2 = Label.new()
		label2.text = suffix
		label2.add_theme_font_size_override("font_size", 18)
		label2.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		label2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label2)
	
	return row


func _find_check_button(node: Node) -> CheckButton:
	if node == null:
		return null
	if node is CheckButton:
		return node
	for child in node.get_children():
		var found = _find_check_button(child)
		if found != null:
			return found
	return null


func _format_static_toggle_row(row: HBoxContainer, label_text: String) -> HBoxContainer:
	if row == null:
		return null
	var label: Label = null
	var check: CheckButton = null
	var to_remove: Array[Node] = []
	for child in row.get_children():
		if child is Label and label == null:
			label = child
		elif child is CheckButton and check == null:
			check = child
		else:
			to_remove.append(child)
	for child in to_remove:
		row.remove_child(child)
		child.queue_free()
	if label != null:
		label.text = label_text
		label.add_theme_font_size_override("font_size", 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = label_text
	if check != null:
		check.custom_minimum_size = Vector2(72, 48)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if label != null and check.get_index() < label.get_index():
			row.move_child(check, label.get_index())
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	return row


func _create_toggle_widget(label_text: String, check_btn: CheckButton) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.name = label_text.replace(" ", "")
	item.custom_minimum_size = Vector2(0, 52)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 10)
	
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label_text
	item.add_child(label)
	
	check_btn.custom_minimum_size = Vector2(72, 48)
	check_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(check_btn)
	
	return item


func _create_toggle_grid(items: Array, columns: int = 3) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	for item in items:
		if item is Control:
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(item)
	var remainder = items.size() % columns
	if remainder > 0:
		for i in range(columns - remainder):
			var dummy := Control.new()
			dummy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(dummy)
	return grid


func _create_toggle_setting_row(label_text: String, setting_name: String) -> HBoxContainer:
	var check = CheckButton.new()
	check.custom_minimum_size = Vector2(72, 48)
	var setting = GlobalSettings.range_settings.settings[setting_name]
	check.set_pressed_no_signal(setting.value)
	check.toggled.connect(func(on):
		setting.set_value(on)
	)
	return _create_toggle_widget(label_text, check)


func _create_fullscreen_setting_row(label_text: String) -> HBoxContainer:
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.custom_minimum_size = Vector2(72, 48)
	_fullscreen_check.focus_mode = Control.FOCUS_ALL
	_fullscreen_check.set_pressed_no_signal(GlobalSettings.is_fullscreen())
	_fullscreen_check.toggled.connect(func(on: bool):
		GlobalSettings.set_fullscreen(on)
	)
	if GlobalSettings.has_signal("fullscreen_changed"):
		GlobalSettings.fullscreen_changed.connect(func(is_fs: bool):
			if is_instance_valid(_fullscreen_check):
				_fullscreen_check.set_pressed_no_signal(is_fs)
		)
	return _create_toggle_widget(label_text, _fullscreen_check)


func _create_option_setting_row(label_text: String, setting_name: String, options: Array[String]) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = label_text.replace(" ", "")
	row.custom_minimum_size = Vector2(0, 52)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 19)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var opt = OptionButton.new()
	for i in range(options.size()):
		opt.add_item(options[i], i)
	_setup_touch_option_button(opt)

	var setting: Setting = GlobalSettings.range_settings.settings.get(setting_name, null)
	var active_val = ""
	if setting_name == "turn_order_mode" and has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if "turn_order_mode" in mp_mgr and not str(mp_mgr.turn_order_mode).is_empty():
			active_val = str(mp_mgr.turn_order_mode)
	if active_val.is_empty() and setting != null:
		active_val = str(setting.value)

	for i in range(options.size()):
		if options[i] == active_val:
			opt.selected = i
			break

	opt.focus_mode = Control.FOCUS_ALL
	opt.item_selected.connect(func(index: int):
		var val = options[index]
		if setting != null:
			setting.set_value(val)
		if setting_name == "turn_order_mode" and has_node("/root/MultiplayerManager"):
			var mp_mgr = get_node("/root/MultiplayerManager")
			mp_mgr.turn_order_mode = val
			if mp_mgr.has_method("save_current_match"):
				mp_mgr.save_current_match()
		elif setting_name == "graphics_quality":
			_graphics_quality_changed = true
			if GlobalSettings:
				GlobalSettings.save_settings()
	)
	row.add_child(opt)

	return row


func _create_slider_setting_row(label_prefix: String, setting_name: String, min_val: float, max_val: float, step: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = label_prefix.replace(" ", "")
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var setting = GlobalSettings.range_settings.settings[setting_name]
	
	var label := Label.new()
	label.text = "%s: %.1f" % [label_prefix, setting.value]
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label_prefix
	row.add_child(label)
	
	var minus_btn := Button.new()
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(48, 48)
	minus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(minus_btn, 8)
	row.add_child(minus_btn)
	
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = setting.value
	slider.custom_minimum_size = Vector2(140, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val):
		setting.set_value(val)
		label.text = "%s: %.1f" % [label_prefix, val]
	)
	row.add_child(slider)
	
	var plus_btn := Button.new()
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(48, 48)
	plus_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_nav_button_style(plus_btn, 8)
	row.add_child(plus_btn)
	
	minus_btn.pressed.connect(func():
		slider.value = clamp(slider.value - step, slider.min_value, slider.max_value)
	)
	plus_btn.pressed.connect(func():
		slider.value = clamp(slider.value + step, slider.min_value, slider.max_value)
	)
	
	return row


func _setup_displayed_stats_section() -> void:
	var root := get_node_or_null("MarginContainer/VBoxContainer/TabContainer/Stats/MarginContainer/StatsVBox")
	if root == null:
		return

	_stat_check_buttons.clear()
	_stat_check_button_list.clear()

	for child in root.get_children():
		child.queue_free()

	# --- Header & Instruction Card ---
	var header_card := PanelContainer.new()
	header_card.name = "StatsHeaderCard"
	ThemeManager.apply_card_panel_style(header_card, true, 10, 16, 14, 16, 14)
	
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	
	var header_top_hbox := HBoxContainer.new()
	var header_title := Label.new()
	header_title.text = "🎯 On-Screen Displayed Statistics"
	header_title.add_theme_font_size_override("font_size", 20)
	header_title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_top_hbox.add_child(header_title)
	
	_stats_count_label = Label.new()
	_stats_count_label.add_theme_font_size_override("font_size", 18)
	header_top_hbox.add_child(_stats_count_label)
	header_vbox.add_child(header_top_hbox)
	
	var header_desc := Label.new()
	header_desc.text = "Select up to %d metrics to display in on-screen tiles during play. You can drag and drop tiles on the range to customize your layout. Only %d stats can be enabled at a time." % [StatDefinitions.MAX_DISPLAYED_STATS, StatDefinitions.MAX_DISPLAYED_STATS]
	header_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_desc.add_theme_font_size_override("font_size", 16)
	header_desc.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	header_vbox.add_child(header_desc)
	
	header_card.add_child(header_vbox)
	root.add_child(header_card)

	_update_stats_count_label()

	# --- Categorized Stat Cards ---
	var categories = ["Ball Flight", "Club Delivery", "Trajectory"]
	var grid_rows: Array[Array] = []
	var cur_row: Array[CheckButton] = []

	for cat in categories:
		var cat_label := Label.new()
		cat_label.text = cat.to_upper() + " METRICS"
		cat_label.add_theme_font_size_override("font_size", 18)
		cat_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		root.add_child(cat_label)

		var cards: Array[Control] = []
		for stat in StatDefinitions.STATS:
			if stat.get("category", "") != cat:
				continue
			var card = _create_stat_card_row(stat)
			cards.append(card)

		var grid = _create_toggle_grid(cards, 3)
		root.add_child(grid)

		var cat_sep := HSeparator.new()
		root.add_child(cat_sep)

	# Group all check buttons into rows of 3 for full 2D grid navigation
	for i in range(_stat_check_button_list.size()):
		cur_row.append(_stat_check_button_list[i])
		if cur_row.size() == 3:
			grid_rows.append(cur_row)
			cur_row = []
	if not cur_row.is_empty():
		grid_rows.append(cur_row)

	_wire_stats_grid_focus(grid_rows)


func _wire_stats_grid_focus(grid_rows: Array[Array]) -> void:
	if grid_rows.is_empty():
		return

	var header_close = get_node_or_null("MarginContainer/VBoxContainer/HeaderHBox/HeaderCloseButton")
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	var reset_layout_btn = get_node_or_null("MarginContainer/VBoxContainer/ButtonsHBox/ResetLayoutButton")
	var exit_btn = get_node_or_null("MarginContainer/VBoxContainer/ButtonsHBox/ExitButton")
	var close_btn = get_node_or_null("MarginContainer/VBoxContainer/ButtonsHBox/CloseButton")

	for r in range(grid_rows.size()):
		var row: Array = grid_rows[r]
		for c in range(row.size()):
			var btn: CheckButton = row[c] as CheckButton
			if btn == null or not is_instance_valid(btn):
				continue

			# Left / Right navigation within row (prevent horizontal focus bleeding)
			if c > 0:
				btn.focus_neighbor_left = btn.get_path_to(row[c - 1])
			else:
				btn.focus_neighbor_left = btn.get_path_to(btn)

			if c < row.size() - 1:
				btn.focus_neighbor_right = btn.get_path_to(row[c + 1])
			else:
				btn.focus_neighbor_right = btn.get_path_to(btn)

			# Down navigation
			if r < grid_rows.size() - 1:
				var next_row: Array = grid_rows[r + 1]
				var target_c = clampi(c, 0, next_row.size() - 1)
				btn.focus_neighbor_bottom = btn.get_path_to(next_row[target_c])
			else:
				if reset_layout_btn != null and is_instance_valid(reset_layout_btn):
					btn.focus_neighbor_bottom = btn.get_path_to(reset_layout_btn)

			# Up navigation
			if r > 0:
				var prev_row: Array = grid_rows[r - 1]
				var target_c = clampi(c, 0, prev_row.size() - 1)
				btn.focus_neighbor_top = btn.get_path_to(prev_row[target_c])
			else:
				# Top row of stats selection window (r == 0)
				# Connect gui_input so if scrolled down (scroll_vertical > 0),
				# pressing UP pulls up the slider to the top first instead of jumping to top menu items!
				if not btn.gui_input.is_connected(_on_top_stat_button_gui_input):
					btn.gui_input.connect(_on_top_stat_button_gui_input)
				if header_close != null and is_instance_valid(header_close):
					btn.focus_neighbor_top = btn.get_path_to(header_close)
				elif tab_container != null and is_instance_valid(tab_container):
					btn.focus_neighbor_top = btn.get_path_to(tab_container)

	# Wire bottom buttons back up to last row of stats
	var last_row: Array = grid_rows.back()
	if not last_row.is_empty():
		if reset_layout_btn != null and is_instance_valid(reset_layout_btn):
			reset_layout_btn.focus_neighbor_top = reset_layout_btn.get_path_to(last_row[0])
		if exit_btn != null and is_instance_valid(exit_btn):
			var mid_c = clampi(1, 0, last_row.size() - 1)
			exit_btn.focus_neighbor_top = exit_btn.get_path_to(last_row[mid_c])
		if close_btn != null and is_instance_valid(close_btn):
			var right_c = last_row.size() - 1
			close_btn.focus_neighbor_top = close_btn.get_path_to(last_row[right_c])


func _on_top_stat_button_gui_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_up") or (ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_DPAD_UP and ev.pressed) or (ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_LEFT_Y and ev.axis_value <= -0.5):
		var stats_scroll = get_node_or_null("MarginContainer/VBoxContainer/TabContainer/Stats") as ScrollContainer
		if stats_scroll != null and stats_scroll.scroll_vertical > 0:
			stats_scroll.scroll_vertical = 0
			get_viewport().set_input_as_handled()


func _sync_displayed_stats_checkboxes() -> void:
	if not (GlobalSettings and GlobalSettings.range_settings and "displayed_stats" in GlobalSettings.range_settings):
		return
	var active_stats: Array = GlobalSettings.range_settings.displayed_stats.value
	for s_id in _stat_check_buttons:
		var cb: CheckButton = _stat_check_buttons[s_id]
		if is_instance_valid(cb):
			cb.set_pressed_no_signal(active_stats.has(s_id))
	_update_stats_count_label()


func _update_stats_count_label() -> void:
	if _stats_count_label == null:
		return
	var active_count: int = GlobalSettings.range_settings.displayed_stats.value.size()
	var max_count := StatDefinitions.MAX_DISPLAYED_STATS
	_stats_count_label.text = "Active: %d / %d (Max %d)" % [active_count, max_count, max_count]
	if active_count >= max_count:
		_stats_count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	else:
		_stats_count_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))


func _create_stat_card_row(stat: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_card_panel_style(card, false, 8, 16, 12, 16, 12)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 4)
	
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	
	var title_lbl := Label.new()
	title_lbl.text = str(stat.get("name", ""))
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	title_hbox.add_child(title_lbl)
	
	var u_str = str(stat.get("units_imperial", ""))
	var short_badge := Label.new()
	short_badge.text = "[Tile: %s | %s]" % [str(stat.get("short_label", "")), u_str]
	short_badge.add_theme_font_size_override("font_size", 14)
	short_badge.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DIM)
	title_hbox.add_child(short_badge)
	
	text_vbox.add_child(title_hbox)
	
	var desc_lbl := Label.new()
	desc_lbl.text = str(stat.get("description", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	text_vbox.add_child(desc_lbl)
	
	hbox.add_child(text_vbox)
	
	var check_btn := CheckButton.new()
	check_btn.custom_minimum_size = Vector2(72, 48)
	check_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stat_id := str(stat.get("id", ""))
	var active_stats: Array = GlobalSettings.range_settings.displayed_stats.value
	check_btn.set_pressed_no_signal(active_stats.has(stat_id))
	
	check_btn.toggled.connect(func(toggled_on: bool):
		_on_stat_toggled(stat_id, toggled_on, check_btn)
	)
	
	_stat_check_buttons[stat_id] = check_btn
	_stat_check_button_list.append(check_btn)

	hbox.add_child(check_btn)
	card.add_child(hbox)
	return card


func _on_stat_toggled(stat_id: String, toggled_on: bool, btn: CheckButton) -> void:
	var active_stats: Array = GlobalSettings.range_settings.displayed_stats.value.duplicate()
	if toggled_on:
		if active_stats.size() >= StatDefinitions.MAX_DISPLAYED_STATS:
			# Max limit reached! Revert toggle and display modal warning prompt
			btn.set_pressed_no_signal(false)
			_show_stat_limit_popup()
			return
		if not active_stats.has(stat_id):
			active_stats.append(stat_id)
	else:
		active_stats.erase(stat_id)
		
	_is_internal_stats_sync = true
	GlobalSettings.range_settings.displayed_stats.set_value(active_stats)
	GlobalSettings.save_settings()
	_is_internal_stats_sync = false
	_update_stats_count_label()


func _show_stat_limit_popup() -> void:
	if _stat_limit_modal != null and is_instance_valid(_stat_limit_modal):
		_stat_limit_modal.queue_free()
		_stat_limit_modal = null
		
	var overlay := ColorRect.new()
	overlay.name = "StatLimitOverlay"
	overlay.color = Color(0, 0, 0, 0.70)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var modal := PanelContainer.new()
	modal.custom_minimum_size = Vector2(520, 270)
	ThemeManager.apply_modal_style(modal, 14)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var title := Label.new()
	title.text = "⚠️ Maximum Display Limit Reached"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var msg := Label.new()
	msg.text = "You can display a maximum of %d stats on screen at a time.\n\nPlease disable one of your currently enabled stats before enabling this one to keep it at %d total displayed stats." % [StatDefinitions.MAX_DISPLAYED_STATS, StatDefinitions.MAX_DISPLAYED_STATS]
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 17)
	msg.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	vbox.add_child(msg)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	var ok_btn := Button.new()
	ok_btn.text = "Got It"
	ok_btn.custom_minimum_size = Vector2(160, 52)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ThemeManager.apply_primary_button_style(ok_btn, 8)
	ok_btn.pressed.connect(func():
		overlay.queue_free()
		_stat_limit_modal = null
	)
	vbox.add_child(ok_btn)
	
	modal.add_child(vbox)
	overlay.add_child(modal)
	
	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -260
	modal.offset_top = -135
	modal.offset_right = 260
	modal.offset_bottom = 135
	
	add_child(overlay)
	_stat_limit_modal = overlay


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# If Key/Joy Listening Modal active, intercept in _input before GUI consumes it
	if _rebind_modal != null and is_instance_valid(_rebind_modal):
		if _rebind_mode == "joy":
			if (event is InputEventJoypadButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadMotion and ((event as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT or (event as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT) and (event as InputEventJoypadMotion).axis_value > 0.5):
				_handle_rebind_joy_event(event, _rebind_action_name, _rebind_modal)
				get_viewport().set_input_as_handled()
				return
		else:
			if event is InputEventKey and event.pressed and not event.echo:
				_handle_rebind_key_event(event, _rebind_action_name, _rebind_modal)
				get_viewport().set_input_as_handled()
				return


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# 1. Conflict Confirmation Modal active
	if _rebind_conflict_modal != null and is_instance_valid(_rebind_conflict_modal):
		if event.is_action_pressed("ui_cancel"):
			_rebind_conflict_modal.queue_free()
			_rebind_conflict_modal = null
			get_viewport().set_input_as_handled()
			return
		return

	# If Rebind Modal active, handled by _input
	if _rebind_modal != null and is_instance_valid(_rebind_modal):
		return

	# 2. Dismiss Stat Limit Modal if active
	if _stat_limit_modal != null and is_instance_valid(_stat_limit_modal):
		if event.is_action_pressed("ui_cancel"):
			_stat_limit_modal.queue_free()
			_stat_limit_modal = null
			get_viewport().set_input_as_handled()
			return

	# 3. Close Settings via B button, Escape, or Settings toggle action
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("settings"):
		request_close()
		get_viewport().set_input_as_handled()
		return

	# 4. Tab cycling with LB / RB (Joypad shoulders) when in settings
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer") as TabContainer
	if tab_container != null and tab_container.is_visible_in_tree():
		if event is InputEventJoypadButton and event.pressed:
			var btn_idx = (event as InputEventJoypadButton).button_index
			if btn_idx == JOY_BUTTON_LEFT_SHOULDER:
				var prev_tab = (tab_container.current_tab - 1 + tab_container.get_tab_count()) % tab_container.get_tab_count()
				tab_container.current_tab = prev_tab
				call_deferred("_focus_first_in_current_tab")
				get_viewport().set_input_as_handled()
				return
			elif btn_idx == JOY_BUTTON_RIGHT_SHOULDER:
				var next_tab = (tab_container.current_tab + 1) % tab_container.get_tab_count()
				tab_container.current_tab = next_tab
				call_deferred("_focus_first_in_current_tab")
				get_viewport().set_input_as_handled()
				return

		# 5. Controller Right Stick vertical scrolling for scrollable tabs
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
			if abs(event.axis_value) >= 0.2:
				var cur_scroll = tab_container.get_current_tab_control() as ScrollContainer
				if cur_scroll != null:
					cur_scroll.scroll_vertical += int(event.axis_value * 18.0)
					get_viewport().set_input_as_handled()
					return

		# 6. Analog Triggers (LT / RT) for list page scrolling
		if event is InputEventJoypadMotion:
			var motion_ev = event as InputEventJoypadMotion
			if motion_ev.axis == JOY_AXIS_TRIGGER_LEFT and motion_ev.axis_value > 0.6:
				var cur_scroll = tab_container.get_current_tab_control() as ScrollContainer
				if cur_scroll != null:
					var page_h := int(max(cur_scroll.size.y * 0.7, 120.0))
					cur_scroll.scroll_vertical = max(0, cur_scroll.scroll_vertical - page_h)
					get_viewport().set_input_as_handled()
					return
			elif motion_ev.axis == JOY_AXIS_TRIGGER_RIGHT and motion_ev.axis_value > 0.6:
				var cur_scroll = tab_container.get_current_tab_control() as ScrollContainer
				if cur_scroll != null:
					var page_h := int(max(cur_scroll.size.y * 0.7, 120.0))
					cur_scroll.scroll_vertical += page_h
					get_viewport().set_input_as_handled()
					return


func _focus_first_in_current_tab() -> void:
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer") as TabContainer
	if tab_container == null:
		return
	var cur_tab = tab_container.get_current_tab_control()
	if cur_tab != null:
		KeybindingManager.focus_first_control(cur_tab)


func _setup_keybindings_section() -> void:
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	if tab_container == null:
		return

	var scroll: ScrollContainer = tab_container.get_node_or_null("Keybindings")
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "Keybindings"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		tab_container.add_child(scroll)
		var t_idx = scroll.get_index()
		tab_container.set_tab_title(t_idx, "Keybindings")

	for c in scroll.get_children():
		c.queue_free()

	ThemeManager.apply_scroll_container_style(scroll, 28)

	_key_buttons_by_action.clear()
	_joy_buttons_by_action.clear()

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", _get_tab_scroll_margin_right(scroll))
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)

	var root = VBoxContainer.new()
	root.name = "KeybindingsVBox"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- Header & Description Card ---
	var header_card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(header_card, true, 10, 16, 14, 16, 14)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 10)

	var header_top_hbox := HBoxContainer.new()
	var header_title := Label.new()
	header_title.text = "🎮 Controls & Keybindings"
	header_title.add_theme_font_size_override("font_size", 20)
	header_title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_top_hbox.add_child(header_title)

	var reset_key_btn := Button.new()
	reset_key_btn.text = "⌨ Reset Keys"
	reset_key_btn.custom_minimum_size = Vector2(130, 42)
	ThemeManager.apply_secondary_button_style(reset_key_btn, 8)
	reset_key_btn.pressed.connect(func():
		if has_node("/root/KeybindingManager"):
			KeybindingManager.reset_keys_to_defaults()
			_refresh_keybinding_buttons()
	)
	header_top_hbox.add_child(reset_key_btn)

	var reset_joy_btn := Button.new()
	reset_joy_btn.text = "🎮 Reset Controller"
	reset_joy_btn.custom_minimum_size = Vector2(150, 42)
	ThemeManager.apply_secondary_button_style(reset_joy_btn, 8)
	reset_joy_btn.pressed.connect(func():
		if has_node("/root/KeybindingManager"):
			KeybindingManager.reset_joy_to_defaults()
			_refresh_keybinding_buttons()
	)
	header_top_hbox.add_child(reset_joy_btn)

	var reset_all_btn := Button.new()
	reset_all_btn.text = "↺ Reset All"
	reset_all_btn.custom_minimum_size = Vector2(120, 42)
	ThemeManager.apply_secondary_button_style(reset_all_btn, 8)
	reset_all_btn.pressed.connect(func():
		if has_node("/root/KeybindingManager"):
			KeybindingManager.reset_to_defaults()
			_refresh_keybinding_buttons()
	)
	header_top_hbox.add_child(reset_all_btn)
	header_vbox.add_child(header_top_hbox)

	# Controller Live Status Banner
	var status_panel := PanelContainer.new()
	ThemeManager.apply_card_panel_style(status_panel, false, 6, 12, 8, 12, 8)
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 10)
	
	_controller_status_label = Label.new()
	_controller_status_label.add_theme_font_size_override("font_size", 16)
	_controller_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_controller_status_label()
	status_hbox.add_child(_controller_status_label)
	status_panel.add_child(status_hbox)
	header_vbox.add_child(status_panel)

	# Connect signal for live controller plug/unplug updates
	if has_node("/root/KeybindingManager"):
		var km_node = get_node("/root/KeybindingManager")
		if not km_node.controller_connection_changed.is_connected(_update_controller_status_label):
			km_node.controller_connection_changed.connect(_update_controller_status_label)

	var header_desc := Label.new()
	header_desc.text = "Customize your PC keyboard shortcuts and Bluetooth / Xbox / gamepad controller buttons. Click any button to rebind it. Both keyboard and controller can be used simultaneously."
	header_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_desc.add_theme_font_size_override("font_size", 15)
	header_desc.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	header_vbox.add_child(header_desc)

	header_card.add_child(header_vbox)
	root.add_child(header_card)

	# --- Categorized Action Cards ---
	if not has_node("/root/KeybindingManager"):
		return
	var km = get_node("/root/KeybindingManager")
	var categories = km.get_categories()

	for cat in categories:
		var cat_actions = km.get_actions_in_category(cat)
		if cat_actions.is_empty():
			continue

		var cat_label := Label.new()
		cat_label.text = cat.to_upper()
		cat_label.add_theme_font_size_override("font_size", 18)
		cat_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		root.add_child(cat_label)

		var card := PanelContainer.new()
		ThemeManager.apply_card_panel_style(card, false, 8, 16, 12, 16, 12)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 10)
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		for i in range(cat_actions.size()):
			var act_name = cat_actions[i]
			var act_label = km.get_action_label(act_name)
			var row = _create_keybinding_row(act_name, act_label)
			card_vbox.add_child(row)
			if i < cat_actions.size() - 1:
				var row_sep = HSeparator.new()
				row_sep.modulate.a = 0.25
				card_vbox.add_child(row_sep)

		card.add_child(card_vbox)
		root.add_child(card)

		var cat_sep := HSeparator.new()
		root.add_child(cat_sep)


func _update_controller_status_label(_connected: bool = false, _name: String = "") -> void:
	if _controller_status_label == null or not is_instance_valid(_controller_status_label):
		return
	if not has_node("/root/KeybindingManager"):
		return
	var km = get_node("/root/KeybindingManager")
	if km.is_controller_connected():
		var c_name = km.get_connected_controller_name()
		_controller_status_label.text = "🎮 Controller Connected: %s (Ready)" % c_name
		_controller_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	else:
		_controller_status_label.text = "🎮 No controller detected (Connect an Xbox, PlayStation, or Bluetooth gamepad)"
		_controller_status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)


func _create_keybinding_row(action_name: String, action_label: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.custom_minimum_size = Vector2(0, 48)
	hbox.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = action_label
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_lbl)

	var km = get_node_or_null("/root/KeybindingManager")

	# Keyboard button
	var key_btn := Button.new()
	key_btn.name = "KeyBtn_" + action_name
	var current_key_str = km.get_action_key_name(action_name) if km != null else ""
	key_btn.text = "⌨ " + current_key_str
	key_btn.custom_minimum_size = Vector2(150, 44)
	key_btn.add_theme_font_size_override("font_size", 15)
	ThemeManager.apply_secondary_button_style(key_btn, 8)
	key_btn.pressed.connect(func():
		_open_rebind_modal(action_name, action_label, false)
	)
	hbox.add_child(key_btn)
	_key_buttons_by_action[action_name] = key_btn

	# Controller button
	var joy_btn := Button.new()
	joy_btn.name = "JoyBtn_" + action_name
	var current_joy_str = km.get_action_joy_button_name(action_name) if km != null else ""
	joy_btn.text = "🎮 " + current_joy_str
	joy_btn.custom_minimum_size = Vector2(175, 44)
	joy_btn.add_theme_font_size_override("font_size", 15)
	ThemeManager.apply_secondary_button_style(joy_btn, 8)
	joy_btn.pressed.connect(func():
		_open_rebind_modal(action_name, action_label, true)
	)
	hbox.add_child(joy_btn)
	_joy_buttons_by_action[action_name] = joy_btn

	return hbox


func _refresh_keybinding_buttons() -> void:
	if not has_node("/root/KeybindingManager"):
		return
	var km = get_node("/root/KeybindingManager")
	for act_name in _key_buttons_by_action.keys():
		var btn = _key_buttons_by_action[act_name] as Button
		if btn != null and is_instance_valid(btn):
			var k_name = km.get_action_key_name(act_name)
			btn.text = "⌨ " + k_name
	for act_name in _joy_buttons_by_action.keys():
		var btn = _joy_buttons_by_action[act_name] as Button
		if btn != null and is_instance_valid(btn):
			var j_name = km.get_action_joy_button_name(act_name)
			btn.text = "🎮 " + j_name
	_update_controller_status_label()


func _open_rebind_modal(action_name: String, action_label: String, is_joy: bool) -> void:
	if _rebind_modal != null and is_instance_valid(_rebind_modal):
		_rebind_modal.queue_free()
		_rebind_modal = null

	_rebind_action_name = action_name
	_rebind_mode = "joy" if is_joy else "key"

	var vp = get_viewport()
	if vp != null:
		vp.gui_release_focus()

	var overlay := ColorRect.new()
	overlay.name = "RebindOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var modal := PanelContainer.new()
	ThemeManager.apply_modal_style(modal, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl := Label.new()
	title_lbl.text = "🎮 Rebind Controller Button" if is_joy else "⌨ Rebind Keyboard Key"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	vbox.add_child(title_lbl)

	var target_lbl := Label.new()
	var dev_prompt = "Press any button on your controller to assign to:\n\"%s\"" if is_joy else "Press any key on your keyboard to assign to:\n\"%s\""
	target_lbl.text = dev_prompt % action_label
	target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_lbl.add_theme_font_size_override("font_size", 18)
	target_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	vbox.add_child(target_lbl)

	var listening_lbl := Label.new()
	listening_lbl.text = "● LISTENING FOR CONTROLLER BUTTON PRESS..." if is_joy else "● LISTENING FOR KEY PRESS..."
	listening_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	listening_lbl.add_theme_font_size_override("font_size", 18)
	listening_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	vbox.add_child(listening_lbl)

	var note_lbl := Label.new()
	note_lbl.text = "Press ESC to cancel  •  Press Backspace to unbind"
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_lbl.add_theme_font_size_override("font_size", 14)
	note_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	vbox.add_child(note_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 14)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var unbind_btn := Button.new()
	unbind_btn.name = "UnbindButton"
	unbind_btn.text = "Clear / Unbind"
	unbind_btn.focus_mode = Control.FOCUS_NONE
	unbind_btn.custom_minimum_size = Vector2(140, 44)
	ThemeManager.apply_secondary_button_style(unbind_btn, 8)
	unbind_btn.pressed.connect(func():
		if has_node("/root/KeybindingManager"):
			var km = get_node("/root/KeybindingManager")
			if is_joy:
				km.rebind_joy_button(action_name, -1)
			else:
				km.rebind_key(action_name, KEY_NONE)
			_refresh_keybinding_buttons()
		overlay.queue_free()
		_rebind_modal = null
		_rebind_action_name = ""
	)
	btn_hbox.add_child(unbind_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Cancel"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.custom_minimum_size = Vector2(130, 44)
	ThemeManager.apply_secondary_button_style(cancel_btn, 8)
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
		_rebind_modal = null
		_rebind_action_name = ""
	)
	btn_hbox.add_child(cancel_btn)

	vbox.add_child(btn_hbox)
	modal.add_child(vbox)
	overlay.add_child(modal)

	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -270
	modal.offset_top = -145
	modal.offset_right = 270
	modal.offset_bottom = 145

	add_child(overlay)
	_rebind_modal = overlay


func _handle_rebind_key_event(event: InputEventKey, action_name: String, overlay: Control) -> void:
	if event.keycode == KEY_ESCAPE:
		overlay.queue_free()
		_rebind_modal = null
		_rebind_action_name = ""
		return

	if event.keycode == KEY_BACKSPACE:
		if has_node("/root/KeybindingManager"):
			var km = get_node("/root/KeybindingManager")
			km.rebind_key(action_name, KEY_NONE)
			_refresh_keybinding_buttons()
		overlay.queue_free()
		_rebind_modal = null
		_rebind_action_name = ""
		return

	var chosen_key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if chosen_key == KEY_NONE or chosen_key == 0:
		return

	if has_node("/root/KeybindingManager"):
		var km = get_node("/root/KeybindingManager")
		var conflict_action = km.get_conflict_key_action(chosen_key, action_name)
		if not conflict_action.is_empty():
			var action_label = km.get_action_label(action_name)
			var conflict_label = km.get_action_label(conflict_action)
			_open_rebind_conflict_dialog(action_name, action_label, chosen_key, false, conflict_action, conflict_label, overlay)
			return

		km.rebind_key(action_name, chosen_key)
		_refresh_keybinding_buttons()

	overlay.queue_free()
	_rebind_modal = null
	_rebind_action_name = ""


func _handle_rebind_joy_event(event: InputEvent, action_name: String, overlay: Control) -> void:
	if event is InputEventKey:
		var key_ev = event as InputEventKey
		if key_ev.keycode == KEY_ESCAPE:
			overlay.queue_free()
			_rebind_modal = null
			_rebind_action_name = ""
			return
		if key_ev.keycode == KEY_BACKSPACE:
			if has_node("/root/KeybindingManager"):
				var km = get_node("/root/KeybindingManager")
				km.rebind_joy_button(action_name, -1)
				_refresh_keybinding_buttons()
			overlay.queue_free()
			_rebind_modal = null
			_rebind_action_name = ""
			return

	var chosen_joy_btn: int = -1
	if event is InputEventJoypadButton and event.pressed:
		chosen_joy_btn = (event as InputEventJoypadButton).button_index
	elif event is InputEventJoypadMotion:
		var motion_ev = event as InputEventJoypadMotion
		if motion_ev.axis == JOY_AXIS_TRIGGER_LEFT and motion_ev.axis_value > 0.5:
			chosen_joy_btn = KeybindingManager.JOY_TRIGGER_LEFT
		elif motion_ev.axis == JOY_AXIS_TRIGGER_RIGHT and motion_ev.axis_value > 0.5:
			chosen_joy_btn = KeybindingManager.JOY_TRIGGER_RIGHT

	if chosen_joy_btn >= 0:
		if has_node("/root/KeybindingManager"):
			var km = get_node("/root/KeybindingManager")
			var conflict_action = km.get_conflict_joy_action(chosen_joy_btn, action_name)
			if not conflict_action.is_empty():
				var action_label = km.get_action_label(action_name)
				var conflict_label = km.get_action_label(conflict_action)
				_open_rebind_conflict_dialog(action_name, action_label, chosen_joy_btn, true, conflict_action, conflict_label, overlay)
				return

			km.rebind_joy_button(action_name, chosen_joy_btn)
			_refresh_keybinding_buttons()

		overlay.queue_free()
		_rebind_modal = null
		_rebind_action_name = ""


func _open_rebind_conflict_dialog(action_name: String, action_label: String, new_code: Variant, is_joy: bool, conflict_action: String, conflict_label: String, rebind_overlay: Control) -> void:
	if _rebind_conflict_modal != null and is_instance_valid(_rebind_conflict_modal):
		_rebind_conflict_modal.queue_free()
		_rebind_conflict_modal = null

	var overlay := ColorRect.new()
	overlay.name = "RebindConflictOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var modal := PanelContainer.new()
	ThemeManager.apply_modal_style(modal, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl := Label.new()
	title_lbl.text = "⚠️ Binding Conflict"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WARNING)
	vbox.add_child(title_lbl)

	var input_name = KeybindingManager.get_joy_button_display_name(int(new_code)) if is_joy else KeybindingManager.get_key_display_name(new_code as Key)

	var msg_lbl := Label.new()
	msg_lbl.text = "%s \"%s\" is already bound to:\n\"%s\"\n\nDo you want to reassign it to \"%s\" and unbind it from \"%s\"?" % [
		"Controller button" if is_joy else "Key",
		input_name,
		conflict_label,
		action_label,
		conflict_label
	]
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	vbox.add_child(msg_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmReassignButton"
	confirm_btn.text = "✓ Reassign"
	confirm_btn.custom_minimum_size = Vector2(140, 44)
	ThemeManager.apply_primary_button_style(confirm_btn, 8)
	confirm_btn.pressed.connect(func():
		if has_node("/root/KeybindingManager"):
			var km = get_node("/root/KeybindingManager")
			if is_joy:
				km.rebind_joy_button(conflict_action, -1)
				km.rebind_joy_button(action_name, int(new_code))
			else:
				km.rebind_key(conflict_action, KEY_NONE)
				km.rebind_key(action_name, new_code as Key)
			_refresh_keybinding_buttons()
		overlay.queue_free()
		_rebind_conflict_modal = null
		if rebind_overlay != null and is_instance_valid(rebind_overlay):
			rebind_overlay.queue_free()
		_rebind_modal = null
		_rebind_action_name = ""
	)
	btn_hbox.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelReassignButton"
	cancel_btn.text = "✕ Cancel"
	cancel_btn.custom_minimum_size = Vector2(130, 44)
	ThemeManager.apply_secondary_button_style(cancel_btn, 8)
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
		_rebind_conflict_modal = null
	)
	btn_hbox.add_child(cancel_btn)

	vbox.add_child(btn_hbox)
	modal.add_child(vbox)
	overlay.add_child(modal)

	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -290
	modal.offset_top = -140
	modal.offset_right = 290
	modal.offset_bottom = 140

	add_child(overlay)
	_rebind_conflict_modal = overlay
	confirm_btn.grab_focus()


func _setup_developer_debugging_section() -> void:
	var tab_container = get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	if tab_container == null:
		return

	var scroll: ScrollContainer = tab_container.get_node_or_null("DeveloperDebug")
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "DeveloperDebug"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		tab_container.add_child(scroll)
		var t_idx = scroll.get_index()
		tab_container.set_tab_title(t_idx, "🛠 Developer")

	for c in scroll.get_children():
		c.queue_free()

	ThemeManager.apply_scroll_container_style(scroll, 28)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", _get_tab_scroll_margin_right(scroll))
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)

	var root = VBoxContainer.new()
	root.name = "DevDebugVBox"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- Header & Description Card ---
	var header_card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(header_card, true, 10, 16, 14, 16, 14)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 8)

	var header_title := Label.new()
	header_title.text = "🛠 Developer Debugging"
	header_title.add_theme_font_size_override("font_size", 20)
	header_title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	header_vbox.add_child(header_title)

	var header_desc := Label.new()
	header_desc.text = "Tools and live 3D visualizers for diagnosing physics, trajectory predictions, and suspense triggers."
	header_desc.add_theme_font_size_override("font_size", 16)
	header_desc.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	header_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_vbox.add_child(header_desc)

	header_card.add_child(header_vbox)
	root.add_child(header_card)

	# --- Visualizers Section Card ---
	var viz_card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(viz_card, false, 8, 16, 14, 16, 14)
	var viz_vbox := VBoxContainer.new()
	viz_vbox.add_theme_constant_override("separation", 12)

	var viz_sec_title := Label.new()
	viz_sec_title.text = "Suspense & Trajectory Visualizers"
	viz_sec_title.add_theme_font_size_override("font_size", 18)
	viz_sec_title.add_theme_color_override("font_color", ThemeManager.COLOR_PRIMARY_NORMAL)
	viz_vbox.add_child(viz_sec_title)

	# Toggle row for cone of vision
	var cone_toggle_row = _create_toggle_setting_row("Show Suspense Vision Cone", "debug_show_suspense_cone")
	viz_vbox.add_child(cone_toggle_row)

	var cone_hint := Label.new()
	cone_hint.text = "Displays a real-time 3D cone of vision projecting from the ball in the world. Green/Cyan indicates the hole is within the suspense vision cone; Red/Orange indicates the hole is outside the cone."
	cone_hint.add_theme_font_size_override("font_size", 14)
	cone_hint.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	cone_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	viz_vbox.add_child(cone_hint)

	var hit_dist_sep := HSeparator.new()
	hit_dist_sep.modulate.a = 0.3
	viz_vbox.add_child(hit_dist_sep)

	# Toggle row for hit distance button & keybind
	var hit_dist_toggle_row = _create_toggle_setting_row("Show Hit Distance Menu", "debug_show_hit_distance")
	viz_vbox.add_child(hit_dist_toggle_row)

	var hit_dist_hint := Label.new()
	hit_dist_hint.text = "Enables the 'Hit Distance' button in helper menus and activates its shortcut keybind for testing and manual shot simulation."
	hit_dist_hint.add_theme_font_size_override("font_size", 14)
	hit_dist_hint.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	hit_dist_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	viz_vbox.add_child(hit_dist_hint)

	viz_card.add_child(viz_vbox)
	root.add_child(viz_card)

	# --- Diagnostic Logging Section Card ---
	var log_card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(log_card, false, 8, 16, 14, 16, 14)
	var log_vbox := VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 12)

	var log_sec_title := Label.new()
	log_sec_title.text = "Diagnostic Logging"
	log_sec_title.add_theme_font_size_override("font_size", 18)
	log_sec_title.add_theme_color_override("font_color", ThemeManager.COLOR_PRIMARY_NORMAL)
	log_vbox.add_child(log_sec_title)

	var log_toggle_row = _create_toggle_setting_row("Enable Debug Logging", "debug_logging_enabled")
	log_vbox.add_child(log_toggle_row)

	var log_hint := Label.new()
	log_hint.text = "When enabled, captures application version, hardware & OS analysis, file integrity checks, Bluetooth launch monitor telemetry, shot metrics, and engine errors to a diagnostic log file."
	log_hint.add_theme_font_size_override("font_size", 14)
	log_hint.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	log_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_vbox.add_child(log_hint)

	var log_sep := HSeparator.new()
	log_vbox.add_child(log_sep)

	var path_header := Label.new()
	path_header.text = "Debug Log File Path"
	path_header.add_theme_font_size_override("font_size", 16)
	path_header.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	log_vbox.add_child(path_header)

	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)

	var path_input := LineEdit.new()
	var current_path := ""
	if GlobalSettings.range_settings.settings.has("debug_log_path"):
		current_path = str(GlobalSettings.range_settings.debug_log_path.value)
	if current_path.is_empty():
		current_path = "user://debug.log"
	path_input.text = current_path
	path_input.placeholder_text = "user://debug.log"
	path_input.custom_minimum_size = Vector2(280, 44)
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_input_style(path_input, 8)
	path_row.add_child(path_input)

	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.custom_minimum_size = Vector2(100, 44)
	ThemeManager.apply_secondary_button_style(browse_btn, 8)
	path_row.add_child(browse_btn)

	var reset_path_btn := Button.new()
	reset_path_btn.text = "Default"
	reset_path_btn.tooltip_text = "Reset path to user://debug.log"
	reset_path_btn.custom_minimum_size = Vector2(80, 44)
	ThemeManager.apply_secondary_button_style(reset_path_btn, 8)
	path_row.add_child(reset_path_btn)

	log_vbox.add_child(path_row)

	var is_mobile_platform := MobilePerformance.is_mobile() or OS.get_name() in ["iOS", "Android"]

	# Action Buttons Row
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)

	var copy_path_btn := Button.new()
	copy_path_btn.text = "📋 Copy Path"
	copy_path_btn.custom_minimum_size = Vector2(120, 38)
	ThemeManager.apply_secondary_button_style(copy_path_btn, 8)
	actions_row.add_child(copy_path_btn)

	var copy_log_content_btn := Button.new()
	copy_log_content_btn.text = "📋 Copy Full Log"
	copy_log_content_btn.tooltip_text = "Copies full diagnostics and engine logs directly to your clipboard"
	copy_log_content_btn.custom_minimum_size = Vector2(150, 38)
	ThemeManager.apply_secondary_button_style(copy_log_content_btn, 8)
	actions_row.add_child(copy_log_content_btn)

	var open_folder_btn := Button.new()
	open_folder_btn.text = "📁 Open Folder"
	open_folder_btn.custom_minimum_size = Vector2(130, 38)
	ThemeManager.apply_secondary_button_style(open_folder_btn, 8)
	if not is_mobile_platform:
		actions_row.add_child(open_folder_btn)

	var flush_btn := Button.new()
	flush_btn.text = "⚡ Write Diagnostics Now"
	flush_btn.tooltip_text = "Immediately write environment diagnostics and file integrity scan into the log file"
	flush_btn.custom_minimum_size = Vector2(190, 38)
	ThemeManager.apply_secondary_button_style(flush_btn, 8)
	actions_row.add_child(flush_btn)

	log_vbox.add_child(actions_row)

	# Resolved System Path Info Label
	var resolved_path_label := Label.new()
	var global_path: String = ProjectSettings.globalize_path(current_path)
	resolved_path_label.text = "System path: %s" % global_path
	resolved_path_label.add_theme_font_size_override("font_size", 13)
	resolved_path_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	resolved_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_vbox.add_child(resolved_path_label)

	if is_mobile_platform:
		var mobile_log_hint := Label.new()
		mobile_log_hint.text = "Tip: Tap 'Copy Full Log' above to copy all logs to your clipboard, or browse logs in the iOS Files app under 'On My iPhone / iPad' -> 'Heckle Golf Simulator'."
		mobile_log_hint.add_theme_font_size_override("font_size", 13)
		mobile_log_hint.add_theme_color_override("font_color", ThemeManager.COLOR_PRIMARY_NORMAL)
		mobile_log_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_vbox.add_child(mobile_log_hint)

	# Status Label
	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	log_vbox.add_child(status_label)

	var update_status = func():
		if not is_instance_valid(status_label):
			return
		var is_enabled := false
		if GlobalSettings.range_settings.settings.has("debug_logging_enabled"):
			is_enabled = bool(GlobalSettings.range_settings.debug_logging_enabled.value)
		if is_enabled:
			var bytes_cnt := 0
			var lines_cnt := 0
			if has_node("/root/DebugLogger"):
				var dl = get_node("/root/DebugLogger")
				bytes_cnt = dl.get_bytes_written()
				lines_cnt = dl.get_session_log_count()
			status_label.text = "● Logging Active (%d bytes written, %d events recorded)" % [bytes_cnt, lines_cnt]
			status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
		else:
			status_label.text = "○ Logging Inactive (Toggle above to activate diagnostic recording)"
			status_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)

	update_status.call()

	# Connect input handlers
	path_input.text_changed.connect(func(new_text: String):
		var clean := new_text.strip_edges()
		if clean.is_empty():
			clean = "user://debug.log"
		GlobalSettings.range_settings.debug_log_path.set_value(clean)
		resolved_path_label.text = "System path: %s" % ProjectSettings.globalize_path(clean)
	)

	reset_path_btn.pressed.connect(func():
		path_input.text = "user://debug.log"
		GlobalSettings.range_settings.debug_log_path.set_value("user://debug.log")
		resolved_path_label.text = "System path: %s" % ProjectSettings.globalize_path("user://debug.log")
	)

	copy_path_btn.pressed.connect(func():
		var target := path_input.text.strip_edges()
		if target.is_empty():
			target = "user://debug.log"
		DisplayServer.clipboard_set(ProjectSettings.globalize_path(target))
		copy_path_btn.text = "✓ Copied!"
		var t := get_tree().create_timer(1.5)
		t.timeout.connect(func():
			if is_instance_valid(copy_path_btn):
				copy_path_btn.text = "📋 Copy Path"
		)
	)

	copy_log_content_btn.pressed.connect(func():
		var log_text := ""
		if has_node("/root/DebugLogger"):
			var dl = get_node("/root/DebugLogger")
			log_text = dl.get_all_logs_text()
		if log_text.strip_edges().is_empty():
			log_text = "[No logs recorded yet]"
		DisplayServer.clipboard_set(log_text)
		copy_log_content_btn.text = "✓ Copied Log!"
		var t := get_tree().create_timer(1.5)
		t.timeout.connect(func():
			if is_instance_valid(copy_log_content_btn):
				copy_log_content_btn.text = "📋 Copy Full Log"
		)
	)

	if not is_mobile_platform:
		open_folder_btn.pressed.connect(func():
			var target := path_input.text.strip_edges()
			if target.is_empty():
				target = "user://debug.log"
			var full := ProjectSettings.globalize_path(target)
			var folder := full.get_base_dir()
			if not DirAccess.dir_exists_absolute(folder):
				DirAccess.make_dir_recursive_absolute(folder)
			OS.shell_open(folder)
		)

	flush_btn.pressed.connect(func():
		if has_node("/root/DebugLogger"):
			var dl = get_node("/root/DebugLogger")
			dl.refresh_logger()
			dl.log_info("Manual diagnostics report requested from settings UI.")
			update_status.call()
			flush_btn.text = "✓ Written!"
			var t := get_tree().create_timer(1.5)
			t.timeout.connect(func():
				if is_instance_valid(flush_btn):
					flush_btn.text = "⚡ Write Diagnostics Now"
			)
	)

	# FileDialog for Browse button - only created on supported desktop platforms
	# Note: use_native_dialog crashes on iOS and mobile platforms where native dialog hooks are not implemented.
	if is_mobile_platform:
		browse_btn.visible = false
	else:
		var file_dialog := FileDialog.new()
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		var supports_native: bool = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG) if OS.get_name() not in ["iOS", "Android"] else false
		file_dialog.use_native_dialog = supports_native
		file_dialog.filters = PackedStringArray(["*.log ; Log Files", "*.txt ; Text Files", "* ; All Files"])
		file_dialog.current_file = "debug.log"
		file_dialog.file_selected.connect(func(selected_path: String):
			path_input.text = selected_path
			GlobalSettings.range_settings.debug_log_path.set_value(selected_path)
			resolved_path_label.text = "System path: %s" % ProjectSettings.globalize_path(selected_path)
		)
		add_child(file_dialog)

		browse_btn.pressed.connect(func():
			file_dialog.popup_centered(Vector2i(700, 500))
		)

	if has_node("/root/DebugLogger"):
		var dl = get_node("/root/DebugLogger")
		var on_state_changed = func(_enabled, _p):
			if is_instance_valid(status_label):
				update_status.call()
		var on_entry_written = func(_entry):
			if is_instance_valid(status_label):
				update_status.call()
		dl.logging_state_changed.connect(on_state_changed)
		dl.log_written.connect(on_entry_written)
		tree_exited.connect(func():
			if is_instance_valid(dl):
				if dl.logging_state_changed.is_connected(on_state_changed):
					dl.logging_state_changed.disconnect(on_state_changed)
				if dl.log_written.is_connected(on_entry_written):
					dl.log_written.disconnect(on_entry_written)
		)

	log_card.add_child(log_vbox)
	root.add_child(log_card)

	# --- OSM Course Download Limits Card ---
	var osm_card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(osm_card, false, 8, 16, 14, 16, 14)
	var osm_vbox := VBoxContainer.new()
	osm_vbox.add_theme_constant_override("separation", 12)

	var osm_sec_title := Label.new()
	osm_sec_title.text = "OpenStreetMap Course Downloads"
	osm_sec_title.add_theme_font_size_override("font_size", 18)
	osm_sec_title.add_theme_color_override("font_color", ThemeManager.COLOR_PRIMARY_NORMAL)
	osm_vbox.add_child(osm_sec_title)

	var bypass_row := _create_osm_bypass_setting_row()
	osm_vbox.add_child(bypass_row)

	var bypass_hint := Label.new()
	bypass_hint.text = "Bypasses the 1 course per day rate limit for direct OpenStreetMap downloads. Requires entering developer verification passcode to unlock."
	bypass_hint.add_theme_font_size_override("font_size", 14)
	bypass_hint.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	bypass_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	osm_vbox.add_child(bypass_hint)

	osm_card.add_child(osm_vbox)
	root.add_child(osm_card)


func _create_osm_bypass_setting_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = "Bypass 1 Course Per Day Limit"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(status_lbl)

	var toggle_btn := CheckButton.new()
	toggle_btn.focus_mode = Control.FOCUS_ALL
	row.add_child(toggle_btn)

	var is_bypassed := false
	if GlobalSettings.range_settings.settings.has("debug_bypass_osm_limit"):
		is_bypassed = bool(GlobalSettings.range_settings.debug_bypass_osm_limit.value)
	toggle_btn.set_pressed_no_signal(is_bypassed)

	var update_status = func(active: bool):
		if active:
			status_lbl.text = "Unlocked (Unlimited)"
			status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
		else:
			status_lbl.text = "Enforced (1 / Day)"
			status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)

	update_status.call(is_bypassed)

	toggle_btn.pressed.connect(func():
		var wants_enabled := toggle_btn.button_pressed
		if not wants_enabled:
			GlobalSettings.range_settings.debug_bypass_osm_limit.set_value(false)
			update_status.call(false)
		else:
			toggle_btn.set_pressed_no_signal(false)
			_show_developer_passcode_modal(func(success: bool):
				if success:
					GlobalSettings.range_settings.debug_bypass_osm_limit.set_value(true)
					toggle_btn.set_pressed_no_signal(true)
					update_status.call(true)
				else:
					toggle_btn.set_pressed_no_signal(false)
					update_status.call(false)
			)
	)

	return row


func _show_developer_passcode_modal(callback: Callable) -> void:
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100

	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.70)
	overlay.add_child(dimmer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 240)
	ThemeManager.apply_modal_style(card, 12)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title = Label.new()
	title.text = "Developer Passcode Required"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ThemeManager.COLOR_PRIMARY_NORMAL)
	vbox.add_child(title)

	var msg = Label.new()
	msg.text = "Enter developer passcode to bypass the 1 course per day OpenStreetMap download limit:"
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var code_input = LineEdit.new()
	code_input.placeholder_text = "Enter passcode..."
	code_input.secret = true
	code_input.custom_minimum_size = Vector2(0, 44)
	code_input.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_input_style(code_input, 8)
	vbox.add_child(code_input)

	var err_label = Label.new()
	err_label.text = ""
	err_label.add_theme_font_size_override("font_size", 13)
	err_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	vbox.add_child(err_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 42)
	ThemeManager.apply_secondary_button_style(cancel_btn, 8)
	btn_row.add_child(cancel_btn)

	var unlock_btn = Button.new()
	unlock_btn.text = "Unlock"
	unlock_btn.custom_minimum_size = Vector2(110, 42)
	ThemeManager.apply_primary_button_style(unlock_btn, 8)
	btn_row.add_child(unlock_btn)

	vbox.add_child(btn_row)

	add_child(overlay)
	code_input.call_deferred("grab_focus")

	var close_modal = func(success: bool):
		overlay.queue_free()
		if callback.is_valid():
			callback.call(success)

	cancel_btn.pressed.connect(func(): close_modal.call(false))
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_modal.call(false)
	)

	var submit_code = func():
		var entered: String = code_input.text.strip_edges()
		var expected: String = _get_developer_bypass_code()
		if entered == expected:
			close_modal.call(true)
		else:
			err_label.text = "Incorrect passcode. Please try again."
			code_input.text = ""
			code_input.grab_focus()

	unlock_btn.pressed.connect(submit_code)
	code_input.text_submitted.connect(func(_t): submit_code.call())


static func _get_developer_bypass_code() -> String:
	var code_file = "res://dev_bypass_code.txt"
	if FileAccess.file_exists(code_file):
		var f = FileAccess.open(code_file, FileAccess.ModeFlags.READ)
		if f != null:
			var code = f.get_as_text().strip_edges()
			if not code.is_empty():
				return code
	return "gimli88lol"
