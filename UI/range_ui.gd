extends MarginContainer

signal rec_button_pressed
signal set_session(dir: String, player_name: String)

signal hit_shot(data)
signal manage_players_requested
signal skip_flight_requested
signal stats_visibility_changed(is_visible: bool)
signal golfer_cam_modal_state_changed(is_open: bool)
signal golfer_cam_enabled_changed(is_enabled: bool)
signal putting_cam_enabled_changed(is_enabled: bool)
signal player_profile_changed(player_name: String)
signal shot_traces_toggled(enabled: bool)
signal stuck_ball_requested


var _avg_carry: Label
var _avg_speed: Label
var _avg_spin: Label
var _avg_offline: Label
var _avg_target_diff: Label
var _prev_shot_popup: Panel
var _session_pop_up: Control = null
var _prev_shot_data_label: Label
var _last_shot_data: Dictionary = {}
var _averages_panel: PanelContainer = null
var _profile_option: OptionButton = null
var _prev_shot_btn: Button = null
var _detached_window: Window = null
var _detached_modal: Control = null
var _right_panel: VBoxContainer = null
var _toggles_scroll: ScrollContainer = null
var _home_btn: Button = null
var _settings_btn: Button = null
var _exit_confirm_dialog: Control = null
var _hide_helpers_btn: Button = null
var _stats_btn: Button = null
var _shot_data_btn: Button = null
var _shot_data_window: Window = null
var _map_btn: Button = null
var _skip_btn: Button = null
var _imm_menu_btn: Button = null
var _imm_menu_container: VBoxContainer = null
var _train_menu_btn: Button = null
var _train_menu_container: VBoxContainer = null
var _visuals_menu_btn: Button = null
var _visuals_menu_container: VBoxContainer = null
var _free_cam_btn: Button = null
var _free_camera: Camera3D = null
var _graphics_toggle_btn: Button = null
signal free_camera_toggled(enabled: bool)
var _announcer_btn: Button = null
var _tension_btn: Button = null
var _screen_offset_ctrl: Control = null
var _dist_btn: Button = null
var _golfer_cam_btn: Button = null
var _putting_cam_btn: Button = null
var _shot_analysis_btn: Button = null
var _shot_traces_btn: Button = null
var _shot_traces_active: bool = true
var _rollout_btn: Button = null
var _track_averages_btn: Button = null
var _stuck_ball_btn: Button = null
var _avg_paused_indicator: Label = null
var _mishit_badge: Label = null
var _mishit_badge_timer: Timer = null
var _dispersion_overlay: Control = null
var _golfer_cam_panel: PanelContainer = null
var _camera_feed_rect: TextureRect = null
var _current_camera_feed_index: int = 0
var _camera_flip_btn: Button = null
var _camera_minimize_btn: Button = null
var _camera_restore_pill: Button = null
var _is_golfer_cam_enabled: bool = false
var _is_golfer_cam_minimized: bool = false
var _is_putting_cam_enabled: bool = false
var _is_putting_cam_minimized: bool = false
var _current_selected_club: String = ""
var _putting_overlay: Control = null
var _putting_state_machine: Node = null
var _putting_align_container: PanelContainer = null
var _putting_align_slider: HSlider = null
var _panel_footer_label: Label = null
var _camera_color_pick_btn: Button = null

const PuttingMJPEGReaderClass = preload("res://UI/PuttingCamera/mjpeg_stream_reader.gd")
var _putting_mjpeg_reader: Node = null

enum PuttingPickerMode { NONE, PICK_BALL, PICK_BACKGROUND }
var _putting_picker_mode: PuttingPickerMode = PuttingPickerMode.NONE
var _color_profile_inst: PuttingColorProfile = null
var _color_profile: PuttingColorProfile:
	get:
		if _color_profile_inst == null:
			var profile_script = load("res://UI/PuttingCamera/putting_color_profile.gd")
			if profile_script != null:
				_color_profile_inst = profile_script.new()
				_color_profile_inst.load_from_settings()
		return _color_profile_inst
	set(v):
		_color_profile_inst = v
var _last_putting_feed_image: Image = null

var putting_min_speed_mph: float:
	get:
		if is_inside_tree() and has_node("/root/GlobalSettings"):
			if GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("putting_min_speed_mph"):
				return float(GlobalSettings.range_settings.putting_min_speed_mph.value)
		return 1.5
	set(val):
		if is_inside_tree() and has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.putting_min_speed_mph.set_value(val)
			GlobalSettings.save_settings()
		if _putting_state_machine != null:
			_putting_state_machine.min_putt_speed_mph = val

var putting_max_speed_mph: float:
	get:
		if is_inside_tree() and has_node("/root/GlobalSettings"):
			if GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("putting_max_speed_mph"):
				return float(GlobalSettings.range_settings.putting_max_speed_mph.value)
		return 20.0
	set(val):
		if is_inside_tree() and has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.putting_max_speed_mph.set_value(val)
			GlobalSettings.save_settings()
		if _putting_state_machine != null:
			_putting_state_machine.max_putt_speed_mph = val

var putting_mishit_filter_enabled: bool:
	get:
		if is_inside_tree() and has_node("/root/GlobalSettings"):
			if GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("putting_mishit_filter_enabled"):
				return bool(GlobalSettings.range_settings.putting_mishit_filter_enabled.value)
		return true
	set(val):
		if is_inside_tree() and has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.putting_mishit_filter_enabled.set_value(val)
			GlobalSettings.save_settings()
		if _putting_state_machine != null:
			_putting_state_machine.mishit_filter_enabled = val

var _camera_rotate_btn: Button = null
var _camera_rotation_deg: int:
	get:
		if has_node("/root/GlobalSettings"):
			return int(GlobalSettings.range_settings.putting_camera_rotation.value)
		return 0
	set(val):
		if has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.putting_camera_rotation.set_value(val % 360)
			GlobalSettings.save_settings()
var _stats_were_visible_before_cam: bool = true
var _phone_cam_url: String:
	get:
		return GlobalSettings.range_settings.phone_cam_url.value
	set(val):
		GlobalSettings.range_settings.phone_cam_url.set_value(val)
var _use_phone_stream: bool:
	get:
		if has_node("/root/GlobalSettings"):
			return GlobalSettings.range_settings.use_phone_stream.value
		return false
	set(val):
		if has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.use_phone_stream.set_value(val)
			GlobalSettings.save_settings()
var _http_req: HTTPRequest = null
var _phone_cam_poll_timer: Timer = null
var _swing_frame_buffer: SwingFrameBuffer = null
var _saved_swing_frames: Array[Dictionary] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if has_node("OverlayLayer"):
		$OverlayLayer.layer = 100
	if has_node("SettingsLayer"):
		$SettingsLayer.layer = 105
	GlobalSettings.range_settings.shot_injector_enabled.setting_changed.connect(toggle_shot_injector)
	if has_node("/root/GlobalSettings") and "range_settings" in GlobalSettings and "shot_analysis_enabled" in GlobalSettings.range_settings:
		GlobalSettings.range_settings.shot_analysis_enabled.setting_changed.connect(func(_val = null):
			_update_prev_shot_analysis_visibility()
		)
	_setup_averages_ui()
	_setup_prev_shot_ui()
	_setup_golfer_camera_ui()
	_setup_profile_selector()

	var profile_script = load("res://UI/PuttingCamera/putting_color_profile.gd")
	if profile_script != null:
		_color_profile = profile_script.new()
		_color_profile.load_from_settings()
	
	var eb = _get_autoload("EventBus")
	if eb != null and eb.has_signal("club_selected"):
		if not eb.is_connected("club_selected", Callable(self, "_on_club_selected")):
			eb.connect("club_selected", Callable(self, "_on_club_selected"))
	
	if CameraServer.has_signal("camera_feed_added"):
		CameraServer.connect("camera_feed_added", func(_id):
			if (is_golfer_camera_enabled() or _is_putting_cam_enabled) and not _use_phone_stream:
				_update_camera_feed(true)
		)

	var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")
	if bridge != null:
		if bridge.has_signal("desktop_frame_received") and not bridge.desktop_frame_received.is_connected(_on_desktop_frame_received):
			bridge.desktop_frame_received.connect(_on_desktop_frame_received)
		if bridge.has_signal("desktop_cameras_updated") and not bridge.desktop_cameras_updated.is_connected(_on_desktop_cameras_updated):
			bridge.desktop_cameras_updated.connect(_on_desktop_cameras_updated)

	_session_pop_up = get_node_or_null("SessionPopUp")
	if _session_pop_up != null:
		if has_node("OverlayLayer"):
			_session_pop_up.reparent($OverlayLayer)
			_session_pop_up.z_index = 500
		_session_pop_up.cancelled.connect(_on_session_pop_up_cancelled)

	var range_settings = get_node_or_null("SettingsLayer/Container/RangeSettings")
	if range_settings != null:
		if range_settings.has_signal("manage_players_requested"):
			range_settings.manage_players_requested.connect(func():
				emit_signal("manage_players_requested")
			)
	
	var is_course_play = not is_driving_range()

	# Hide default SettingsButton from HBoxContainer
	var default_settings_btn = $HBoxContainer/SettingsButton
	if default_settings_btn != null:
		default_settings_btn.visible = false

	# Setup HBoxContainer mouse filters to prevent blocking settings clicks
	$HBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/PlayerName.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/PlayerName.add_theme_color_override("font_color", Color.WHITE)
	$HBoxContainer/PlayerName.add_theme_color_override("font_outline_color", Color.BLACK)
	$HBoxContainer/PlayerName.add_theme_constant_override("outline_size", 6)

	if not is_course_play:
		# Dynamically create Settings Button in the top-right corner, enlarged for touch
		var settings_btn = Button.new()
		settings_btn.name = "SettingsButton"
		settings_btn.text = ""
		settings_btn.tooltip_text = "Settings"
		settings_btn.icon = load("res://Utils/Settings/Gear.png")
		settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		settings_btn.custom_minimum_size = Vector2(64, 64)
		apply_circular_button_style(settings_btn, Color(0.15, 0.15, 0.15, 0.85))
		settings_btn.anchor_left = 1.0
		settings_btn.anchor_right = 1.0
		settings_btn.offset_left = -88
		settings_btn.offset_top = 20
		settings_btn.offset_right = -24
		settings_btn.offset_bottom = 84
		settings_btn.pressed.connect(_on_toggle_settings_requested)
		$OverlayLayer.add_child(settings_btn)
		_settings_btn = settings_btn

		# Home / Main Menu Button (Icon Only) - positioned between Settings and HideHelpers
		var home_btn = Button.new()
		home_btn.name = "HomeButton"
		home_btn.text = ""
		home_btn.tooltip_text = "Main Menu"
		if ResourceLoader.exists("res://assets/images/icons/home.svg"):
			home_btn.icon = load("res://assets/images/icons/home.svg")
		home_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		home_btn.custom_minimum_size = Vector2(64, 64)
		apply_circular_button_style(home_btn, Color(0.15, 0.15, 0.15, 0.85))
		home_btn.anchor_left = 1.0
		home_btn.anchor_right = 1.0
		home_btn.offset_left = -184
		home_btn.offset_top = 20
		home_btn.offset_right = -120
		home_btn.offset_bottom = 84
		home_btn.pressed.connect(_on_home_button_pressed)
		$OverlayLayer.add_child(home_btn)
		_home_btn = home_btn

		# Hide/Show Helpers Button (Icon Only) - positioned to the left of Home Button
		var hide_helpers_btn = Button.new()
		hide_helpers_btn.name = "HideHelpersButton"
		hide_helpers_btn.text = ""
		hide_helpers_btn.tooltip_text = "Toggle Helpers (Show/Hide)"
		if ResourceLoader.exists("res://assets/images/icons/helpers.svg"):
			hide_helpers_btn.icon = load("res://assets/images/icons/helpers.svg")
		hide_helpers_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hide_helpers_btn.custom_minimum_size = Vector2(64, 64)
		apply_circular_button_style(hide_helpers_btn, Color(0.15, 0.15, 0.15, 0.85))
		hide_helpers_btn.anchor_left = 1.0
		hide_helpers_btn.anchor_right = 1.0
		hide_helpers_btn.offset_left = -280
		hide_helpers_btn.offset_top = 20
		hide_helpers_btn.offset_right = -216
		hide_helpers_btn.offset_bottom = 84
		$OverlayLayer.add_child(hide_helpers_btn)
		_hide_helpers_btn = hide_helpers_btn

		# Dynamically create vertical RightPanel anchored to full screen height for scrolling - starts below ClubSelector
		var right_panel = VBoxContainer.new()
		right_panel.name = "RightPanel"
		right_panel.anchor_left = 1.0
		right_panel.anchor_right = 1.0
		right_panel.anchor_top = 0.0
		right_panel.anchor_bottom = 1.0
		right_panel.offset_left = -280
		right_panel.offset_top = 166
		right_panel.offset_right = -24
		right_panel.offset_bottom = -96
		right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		right_panel.add_theme_constant_override("separation", 12)
		$OverlayLayer.add_child(right_panel)
		_right_panel = right_panel

		# ScrollContainer so buttons are always reachable on short screens - hidden by default!
		var toggles_scroll = ScrollContainer.new()
		toggles_scroll.name = "TogglesScroll"
		toggles_scroll.visible = false
		toggles_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		toggles_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		toggles_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		toggles_scroll.follow_focus = true
		ThemeManager.apply_scroll_container_style(toggles_scroll, 28)
		_toggles_scroll = toggles_scroll
		
		var toggles_container = VBoxContainer.new()
		toggles_container.name = "TogglesContainer"
		toggles_container.add_theme_constant_override("separation", 12)
		toggles_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		toggles_container.custom_minimum_size = Vector2(256, 0)
		
		hide_helpers_btn.pressed.connect(func():
			toggles_scroll.visible = not toggles_scroll.visible
			if toggles_scroll.visible:
				apply_circular_button_style(hide_helpers_btn, Color(0.25, 0.45, 0.7, 0.9))
			else:
				apply_circular_button_style(hide_helpers_btn, Color(0.15, 0.15, 0.15, 0.85))
			_update_helpers_scroll_layout()
			call_deferred("_update_hud_focus_neighbors")
		)
		
		toggles_scroll.add_child(toggles_container)
		right_panel.add_child(toggles_scroll)

		var v_bar = toggles_scroll.get_v_scroll_bar()
		if v_bar != null:
			v_bar.visibility_changed.connect(func(): _update_helpers_scroll_layout.call_deferred())
		toggles_scroll.visibility_changed.connect(func(): _update_helpers_scroll_layout.call_deferred())
		toggles_scroll.resized.connect(func(): _update_helpers_scroll_layout.call_deferred())
		toggles_container.resized.connect(func(): _update_helpers_scroll_layout.call_deferred())

		# Distance Menu setup
		var distance_menu_script = load("res://UI/distance_menu.gd")
		var dist_menu = distance_menu_script.new()
		dist_menu.name = "DistanceMenu"
		dist_menu.visible = false
		dist_menu.inject_shot.connect(_on_shot_injector_inject)

		# Hit Menu (formerly Hit Distance) Button
		var dist_btn = Button.new()
		dist_btn.name = "HitDistanceButton"
		dist_btn.text = "🎯 Hit Menu"
		dist_btn.custom_minimum_size = Vector2(180, 56)
		dist_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		apply_material_button_style(dist_btn, Color(0.6, 0.2, 0.6, 0.85))
		dist_btn.pressed.connect(func():
			var menu = null
			if _right_panel != null:
				menu = _right_panel.get_node_or_null("TogglesScroll/TogglesContainer/DistanceMenu")
				if not menu:
					menu = _right_panel.get_node_or_null("TogglesContainer/DistanceMenu")
			if not menu:
				menu = get_node_or_null("DistanceMenu")
			if menu:
				if menu.visible:
					if menu.has_method("close"):
						menu.close()
					else:
						menu.visible = false
					var vp = get_viewport()
					if vp != null:
						vp.gui_release_focus()
				else:
					menu.visible = true
					var p = get_parent()
					if p and p.has_node("Player"):
						menu.current_ball_node = p.get_node("Player").get("ball")
					if p and "aim_target_pos" in p:
						menu.aim_target_node = p.get("aim_target_pos")
				_update_hit_distance_button_state()
				_update_helpers_scroll_layout.call_deferred()
		)
		dist_btn.set_meta("toggle_target", dist_menu)
		dist_menu.visibility_changed.connect(func():
			_update_hit_distance_button_state()
			_update_helpers_scroll_layout.call_deferred()
		)
		toggles_container.add_child(dist_btn)
		toggles_container.add_child(dist_menu)
		_dist_btn = dist_btn
		_update_hit_distance_button_visibility()

		# --- Immersion Menu Submenu ---
		var imm_menu_btn = Button.new()
		imm_menu_btn.name = "ImmersionMenuButton"
		imm_menu_btn.text = "🎭 Immersion Menu"
		imm_menu_btn.tooltip_text = "Toggle Immersion Settings (Suspense, Announcer, Putting Cam, Screen Offset)"
		imm_menu_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(imm_menu_btn, Color(0.35, 0.45, 0.6, 0.85))

		var imm_menu_container = VBoxContainer.new()
		imm_menu_container.name = "ImmersionMenuContainer"
		imm_menu_container.add_theme_constant_override("separation", 10)
		imm_menu_container.visible = false

		imm_menu_btn.pressed.connect(func():
			imm_menu_container.visible = not imm_menu_container.visible
			if imm_menu_container.visible:
				imm_menu_btn.text = "🎭 Immersion Menu: OPEN"
				apply_material_button_style(imm_menu_btn, Color(0.45, 0.55, 0.75, 0.9))
			else:
				imm_menu_btn.text = "🎭 Immersion Menu"
				apply_material_button_style(imm_menu_btn, Color(0.35, 0.45, 0.6, 0.85))
			_update_helpers_scroll_layout.call_deferred()
			call_deferred("_update_hud_focus_neighbors")
		)
		toggles_container.add_child(imm_menu_btn)
		toggles_container.add_child(imm_menu_container)
		_imm_menu_btn = imm_menu_btn
		_imm_menu_container = imm_menu_container

		# Suspense Heartbeat & Tunnel Vision Toggle Button
		var tension_btn = Button.new()
		tension_btn.name = "SuspenseToggleButton"
		var is_tension_on = GlobalSettings.range_settings.tension_effects_enabled.value if has_node("/root/GlobalSettings") else true
		tension_btn.text = "💓 Suspense: ON" if is_tension_on else "💓 Suspense: OFF"
		tension_btn.tooltip_text = "Toggle Suspense Heartbeat & Tunnel Vision in Course Play"
		tension_btn.custom_minimum_size = Vector2(180, 56)
		var initial_tension_color = Color(0.75, 0.2, 0.3, 0.85) if is_tension_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(tension_btn, initial_tension_color)
		tension_btn.pressed.connect(func():
			if has_node("/root/GlobalSettings"):
				var new_val = not GlobalSettings.range_settings.tension_effects_enabled.value
				GlobalSettings.range_settings.tension_effects_enabled.value = new_val
				GlobalSettings.save_settings()
				if not new_val and has_node("/root/TensionManager"):
					TensionManager.stop_tension()
				if new_val:
					tension_btn.text = "💓 Suspense: ON"
					apply_material_button_style(tension_btn, Color(0.75, 0.2, 0.3, 0.85))
				else:
					tension_btn.text = "💓 Suspense: OFF"
					apply_material_button_style(tension_btn, Color(0.5, 0.5, 0.5, 0.85))
		)
		imm_menu_container.add_child(tension_btn)
		_tension_btn = tension_btn

		# Announcer Mute/Unmute Toggle Button
		var announcer_btn = Button.new()
		announcer_btn.name = "AnnouncerToggleButton"
		var announcer_node = get_node_or_null("/root/AnnouncerEngine")
		var is_announcer_on = announcer_node.get("AnnouncerRange") if announcer_node != null else false
		announcer_btn.text = "🎙 Announcer: ON" if is_announcer_on else "🎙 Announcer: MUTED"
		announcer_btn.tooltip_text = "Toggle Announcer Commentary"
		announcer_btn.custom_minimum_size = Vector2(180, 56)
		var initial_ann_color = Color(0.2, 0.6, 0.3, 0.85) if is_announcer_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(announcer_btn, initial_ann_color)
		announcer_btn.pressed.connect(func():
			var a = get_node_or_null("/root/AnnouncerEngine")
			if a != null:
				var current_val = a.get("AnnouncerRange") as bool
				var new_val = not current_val
				a.set("AnnouncerRange", new_val)
				GlobalSettings.save_settings()
				if new_val:
					announcer_btn.text = "🎙 Announcer: ON"
					apply_material_button_style(announcer_btn, Color(0.2, 0.6, 0.3, 0.85))
					a.call("SpeakHecklesEnabled")
				else:
					announcer_btn.text = "🎙 Announcer: MUTED"
					apply_material_button_style(announcer_btn, Color(0.5, 0.5, 0.5, 0.85))
					a.call("SpeakHecklesDisabled")
		)
		imm_menu_container.add_child(announcer_btn)
		_announcer_btn = announcer_btn

		# Putting Camera Toggle Button
		var putting_cam_btn = Button.new()
		putting_cam_btn.name = "PuttingCamButton"
		putting_cam_btn.text = "🎯 Putting Cam: OFF"
		putting_cam_btn.tooltip_text = "Toggle Putting Camera (Ball tracking for putt speed & direction, Right-click for Setup)"
		putting_cam_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(putting_cam_btn, Color(0.35, 0.35, 0.35, 0.85))
		putting_cam_btn.pressed.connect(func():
			if not is_putting_camera_enabled():
				set_putting_camera_visible(true)
			elif is_putting_camera_minimized():
				restore_putting_camera()
			else:
				set_putting_camera_visible(false)
		)
		putting_cam_btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				open_camera_setup(true)
				get_viewport().set_input_as_handled()
		)
		imm_menu_container.add_child(putting_cam_btn)
		_putting_cam_btn = putting_cam_btn

		# Screen Offset Toggle & Slider
		var so_script = load("res://UI/ScreenOffset/screen_offset_control.gd")
		var so_ctrl = so_script.new()
		so_ctrl.name = "ScreenOffsetControl"
		so_ctrl.style_button = func(btn: Button, is_on: bool):
			var c = Color(0.2, 0.5, 0.75, 0.85) if is_on else Color(0.5, 0.5, 0.5, 0.85)
			apply_material_button_style(btn, c)
		imm_menu_container.add_child(so_ctrl)
		_screen_offset_ctrl = so_ctrl
		if so_ctrl.has_signal("offset_toggled"):
			so_ctrl.offset_toggled.connect(func(_on):
				_update_helpers_scroll_layout.call_deferred()
				call_deferred("_update_hud_focus_neighbors")
			)

		# --- Training Menu Submenu ---
		var train_menu_btn = Button.new()
		train_menu_btn.name = "TrainingMenuButton"
		train_menu_btn.text = "🎯 Training Menu"
		train_menu_btn.tooltip_text = "Toggle Training Tools (Golfer Cam, Shot Analysis, Track Averages, Rollout)"
		train_menu_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(train_menu_btn, Color(0.25, 0.5, 0.55, 0.85))

		var train_menu_container = VBoxContainer.new()
		train_menu_container.name = "TrainingMenuContainer"
		train_menu_container.add_theme_constant_override("separation", 10)
		train_menu_container.visible = false

		train_menu_btn.pressed.connect(func():
			train_menu_container.visible = not train_menu_container.visible
			if train_menu_container.visible:
				train_menu_btn.text = "🎯 Training Menu: OPEN"
				apply_material_button_style(train_menu_btn, Color(0.35, 0.6, 0.68, 0.9))
			else:
				train_menu_btn.text = "🎯 Training Menu"
				apply_material_button_style(train_menu_btn, Color(0.25, 0.5, 0.55, 0.85))
			_update_helpers_scroll_layout.call_deferred()
			call_deferred("_update_hud_focus_neighbors")
		)
		toggles_container.add_child(train_menu_btn)
		toggles_container.add_child(train_menu_container)
		_train_menu_btn = train_menu_btn
		_train_menu_container = train_menu_container

		# Golfer Cam Toggle Button
		var golfer_cam_btn = Button.new()
		golfer_cam_btn.name = "GolferCamButton"
		golfer_cam_btn.text = "📹 Golfer Cam: OFF"
		golfer_cam_btn.tooltip_text = "Toggle Golfer Camera (Right-click for Setup)"
		golfer_cam_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(golfer_cam_btn, Color(0.2, 0.45, 0.45, 0.85))
		golfer_cam_btn.pressed.connect(func():
			if not is_golfer_camera_enabled():
				set_golfer_camera_visible(true)
			elif is_golfer_camera_minimized():
				restore_golfer_camera()
			else:
				set_golfer_camera_visible(false)
		)
		golfer_cam_btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				open_camera_setup(false)
				get_viewport().set_input_as_handled()
		)
		train_menu_container.add_child(golfer_cam_btn)
		_golfer_cam_btn = golfer_cam_btn

		# Shot Analysis Toggle Button
		var shot_analysis_btn = Button.new()
		shot_analysis_btn.name = "ShotAnalysisButton"
		var is_analysis_on = is_shot_analysis_enabled()
		shot_analysis_btn.text = "📊 Shot Analysis: ON" if is_analysis_on else "📊 Shot Analysis: OFF"
		shot_analysis_btn.tooltip_text = "Toggle Shot Suggestions & Flaw Analysis"
		shot_analysis_btn.custom_minimum_size = Vector2(180, 56)
		var initial_analysis_color = Color(0.15, 0.55, 0.75, 0.85) if is_analysis_on else Color(0.25, 0.35, 0.45, 0.85)
		apply_material_button_style(shot_analysis_btn, initial_analysis_color)
		shot_analysis_btn.pressed.connect(func():
			var new_val = not is_shot_analysis_enabled()
			set_shot_analysis_enabled(new_val)
			if has_node("/root/GlobalSettings"):
				GlobalSettings.save_settings()
			if new_val:
				shot_analysis_btn.text = "📊 Shot Analysis: ON"
				apply_material_button_style(shot_analysis_btn, Color(0.15, 0.55, 0.75, 0.85))
			else:
				shot_analysis_btn.text = "📊 Shot Analysis: OFF"
				apply_material_button_style(shot_analysis_btn, Color(0.25, 0.35, 0.45, 0.85))
		)
		train_menu_container.add_child(shot_analysis_btn)
		_shot_analysis_btn = shot_analysis_btn

		# Shot Traces Overlay Toggle Button (HotKey: T)
		var shot_traces_btn = Button.new()
		shot_traces_btn.name = "ShotTracesButton"
		shot_traces_btn.text = "📈 Shot Traces: ON" if _shot_traces_active else "📈 Shot Traces: OFF"
		shot_traces_btn.tooltip_text = "Toggle Flight Arc Traces & Dispersion View for current club (Hotkey: T)"
		shot_traces_btn.custom_minimum_size = Vector2(180, 56)
		var initial_traces_color = Color(0.15, 0.65, 0.85, 0.85) if _shot_traces_active else Color(0.3, 0.35, 0.45, 0.85)
		apply_material_button_style(shot_traces_btn, initial_traces_color)
		shot_traces_btn.pressed.connect(func():
			toggle_shot_traces()
		)
		train_menu_container.add_child(shot_traces_btn)
		_shot_traces_btn = shot_traces_btn

		# Track Club Distances & Averages Toggle Button
		var track_averages_btn = Button.new()
		track_averages_btn.name = "TrackAveragesButton"
		var is_tracking_on = true
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null and mp_mgr.has_method("is_club_averages_tracking_enabled"):
			is_tracking_on = mp_mgr.is_club_averages_tracking_enabled()
		track_averages_btn.text = "📊 Track Averages: ON" if is_tracking_on else "📊 Track Averages: OFF"
		track_averages_btn.tooltip_text = "Toggle Club Distances & Shot Averages Tracking"
		track_averages_btn.custom_minimum_size = Vector2(180, 56)
		var initial_tracking_color = Color(0.18, 0.55, 0.65, 0.85) if is_tracking_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(track_averages_btn, initial_tracking_color)
		track_averages_btn.pressed.connect(func():
			var cur_state = true
			var mp = get_node_or_null("/root/MultiplayerManager")
			if mp != null and mp.has_method("is_club_averages_tracking_enabled"):
				cur_state = mp.is_club_averages_tracking_enabled()
			var new_state = not cur_state
			if mp != null and mp.has_method("set_club_averages_tracking_enabled"):
				mp.set_club_averages_tracking_enabled(new_state)
			elif has_node("/root/GlobalSettings") and GlobalSettings.range_settings != null and "track_club_averages" in GlobalSettings.range_settings:
				GlobalSettings.range_settings.track_club_averages.value = new_state
				GlobalSettings.save_settings()
			_update_track_averages_btn_state()
		)
		if mp_mgr != null and mp_mgr.has_signal("club_averages_tracking_toggled"):
			mp_mgr.club_averages_tracking_toggled.connect(func(_enabled): _update_track_averages_btn_state())
		train_menu_container.add_child(track_averages_btn)
		_track_averages_btn = track_averages_btn

		# Ball Rollout Toggle Button
		var rollout_btn = Button.new()
		rollout_btn.name = "RolloutToggleButton"
		var is_rollout_on = is_rollout_enabled()
		rollout_btn.text = "🔄 Rollout: ON" if is_rollout_on else "🔄 Rollout: OFF"
		rollout_btn.tooltip_text = "Toggle Ball Rollout & Bounce"
		rollout_btn.custom_minimum_size = Vector2(180, 56)
		var initial_rollout_color = Color(0.2, 0.6, 0.4, 0.85) if is_rollout_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(rollout_btn, initial_rollout_color)
		rollout_btn.pressed.connect(func():
			toggle_rollout()
		)
		train_menu_container.add_child(rollout_btn)
		_rollout_btn = rollout_btn

		# --- Visuals Menu Submenu ---
		var visuals_menu_btn = Button.new()
		visuals_menu_btn.name = "VisualsMenuButton"
		visuals_menu_btn.text = "👁️ Visuals Menu"
		visuals_menu_btn.tooltip_text = "Toggle Visual Settings (Free Camera, Graphics Quality, etc.)"
		visuals_menu_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(visuals_menu_btn, Color(0.4, 0.35, 0.65, 0.85))

		var visuals_menu_container = VBoxContainer.new()
		visuals_menu_container.name = "VisualsMenuContainer"
		visuals_menu_container.add_theme_constant_override("separation", 10)
		visuals_menu_container.visible = false

		visuals_menu_btn.pressed.connect(func():
			visuals_menu_container.visible = not visuals_menu_container.visible
			if visuals_menu_container.visible:
				visuals_menu_btn.text = "👁️ Visuals Menu: OPEN"
				apply_material_button_style(visuals_menu_btn, Color(0.5, 0.45, 0.75, 0.9))
			else:
				visuals_menu_btn.text = "👁️ Visuals Menu"
				apply_material_button_style(visuals_menu_btn, Color(0.4, 0.35, 0.65, 0.85))
			_update_helpers_scroll_layout.call_deferred()
			call_deferred("_update_hud_focus_neighbors")
		)
		toggles_container.add_child(visuals_menu_btn)
		toggles_container.add_child(visuals_menu_container)
		_visuals_menu_btn = visuals_menu_btn
		_visuals_menu_container = visuals_menu_container

		# Free Camera Toggle Button
		var free_cam_btn = Button.new()
		free_cam_btn.name = "FreeCameraButton"
		free_cam_btn.text = "🎥 Free Camera: OFF"
		free_cam_btn.tooltip_text = "Toggle Free Camera (Fly: WASD/Arrows, Up/Down: Space/Ctrl/E/Q/Wheel, or Click to Move)"
		free_cam_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(free_cam_btn, Color(0.35, 0.35, 0.35, 0.85))
		free_cam_btn.pressed.connect(func():
			toggle_free_camera()
		)
		visuals_menu_container.add_child(free_cam_btn)
		_free_cam_btn = free_cam_btn

		# Graphics Quality Toggle Button
		var graphics_toggle_btn = Button.new()
		graphics_toggle_btn.name = "GraphicsToggleButton"
		graphics_toggle_btn.custom_minimum_size = Vector2(180, 56)
		graphics_toggle_btn.pressed.connect(func():
			_cycle_graphics_quality(false)
		)
		graphics_toggle_btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_cycle_graphics_quality(true)
		)
		visuals_menu_container.add_child(graphics_toggle_btn)
		_graphics_toggle_btn = graphics_toggle_btn
		_update_graphics_toggle_btn_state()

		if has_node("/root/GlobalSettings"):
			var gs = get_node("/root/GlobalSettings")
			if gs.range_settings != null and not gs.range_settings.settings_changed.is_connected(_update_graphics_toggle_btn_state):
				gs.range_settings.settings_changed.connect(_update_graphics_toggle_btn_state)

		# Stuck Ball Button (Free drop 2 yards closer to nearest fairway)
		var stuck_ball_btn = Button.new()
		stuck_ball_btn.name = "StuckBallButton"
		stuck_ball_btn.text = "⛳ Stuck Ball Relief"
		stuck_ball_btn.tooltip_text = "Move ball 2 yards closer to nearest fairway without counting a stroke"
		stuck_ball_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(stuck_ball_btn, Color(0.75, 0.45, 0.15, 0.85))
		stuck_ball_btn.pressed.connect(_on_stuck_ball_button_pressed)
		toggles_container.add_child(stuck_ball_btn)
		_stuck_ball_btn = stuck_ball_btn


		# Position ClubSelector directly underneath SettingsButton and HideHelpersButton
		var club_sel = get_node_or_null("GridCanvas/ClubSelector")
		if club_sel != null:
			club_sel.reparent($OverlayLayer)
			club_sel.anchor_left = 1.0
			club_sel.anchor_right = 1.0
			club_sel.anchor_top = 0.0
			club_sel.anchor_bottom = 0.0
			club_sel.offset_left = -280
			club_sel.offset_top = 96
			club_sel.offset_right = -24
			club_sel.offset_bottom = 152
			club_sel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			club_sel.custom_minimum_size = Vector2(256, 56)
			club_sel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

		# Dedicated Stats Button (Icon Only) - Bottom-Left Corner
		var stats_btn = Button.new()
		stats_btn.name = "StatsButton"
		stats_btn.text = ""
		stats_btn.tooltip_text = "Toggle Stats (Show/Hide)"
		if ResourceLoader.exists("res://assets/images/icons/stats.svg"):
			stats_btn.icon = load("res://assets/images/icons/stats.svg")
		stats_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_btn.custom_minimum_size = Vector2(64, 64)
		apply_circular_button_style(stats_btn, Color(0.24, 0.46, 0.72, 0.85)) # Blue
		stats_btn.anchor_left = 0.0
		stats_btn.anchor_right = 0.0
		stats_btn.anchor_top = 1.0
		stats_btn.anchor_bottom = 1.0
		stats_btn.offset_left = 30
		stats_btn.offset_top = -88
		stats_btn.offset_right = 94
		stats_btn.offset_bottom = -24
		stats_btn.pressed.connect(func():
			toggle_stats_visibility()
		)
		$OverlayLayer.add_child(stats_btn)
		_stats_btn = stats_btn

		# Shot Data Analysis Window Button
		var shot_data_btn := Button.new()
		shot_data_btn.name = "ShotDataAnalysisButton"
		shot_data_btn.text = "📈"
		shot_data_btn.tooltip_text = "Open Shot Data Analysis"
		shot_data_btn.custom_minimum_size = Vector2(64, 64)
		shot_data_btn.add_theme_font_size_override("font_size", 24)
		apply_circular_button_style(shot_data_btn, Color(0.33, 0.3, 0.62, 0.9))
		shot_data_btn.anchor_left = 0.0
		shot_data_btn.anchor_right = 0.0
		shot_data_btn.anchor_top = 1.0
		shot_data_btn.anchor_bottom = 1.0
		shot_data_btn.offset_left = 102
		shot_data_btn.offset_top = -88
		shot_data_btn.offset_right = 166
		shot_data_btn.offset_bottom = -24
		shot_data_btn.pressed.connect(_toggle_shot_data_window)
		$OverlayLayer.add_child(shot_data_btn)
		_shot_data_btn = shot_data_btn
		_shot_data_btn.visible = is_driving_range()

		# Dedicated Map Toggle Button (Icon Only) - Bottom-Right Corner
		var map_btn = Button.new()
		map_btn.name = "MapButton"
		map_btn.text = ""
		map_btn.tooltip_text = "Toggle Map View"
		if ResourceLoader.exists("res://assets/images/icons/golf_course.svg"):
			map_btn.icon = load("res://assets/images/icons/golf_course.svg")
		map_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		map_btn.custom_minimum_size = Vector2(64, 64)
		apply_circular_button_style(map_btn, Color(0.18, 0.45, 0.25, 0.85)) # Forest green
		map_btn.anchor_left = 1.0
		map_btn.anchor_right = 1.0
		map_btn.anchor_top = 1.0
		map_btn.anchor_bottom = 1.0
		map_btn.offset_left = -94
		map_btn.offset_top = -88
		map_btn.offset_right = -30
		map_btn.offset_bottom = -24
		map_btn.pressed.connect(func():
			var p = get_parent()
			if p and p.has_method("_on_map_button_pressed"):
				p.call("_on_map_button_pressed")
		)
		$OverlayLayer.add_child(map_btn)
		_map_btn = map_btn
	else:
		$HBoxContainer.visible = false

	# Dynamically create Skip button in the top-middle of the screen
	_skip_btn = Button.new()
	_skip_btn.name = "SkipFlightButton"
	_skip_btn.text = "Skip"
	_skip_btn.custom_minimum_size = Vector2(160, 50)
	_skip_btn.visible = false
	apply_material_button_style(_skip_btn, Color(0.24, 0.46, 0.72, 0.85)) # Action blue
	
	# Position in the top middle of the screen
	_skip_btn.anchor_left = 0.5
	_skip_btn.anchor_right = 0.5
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	# Center it horizontally using offsets, place below the 20-60 y-range badge:
	_skip_btn.offset_left = -80
	_skip_btn.offset_right = 80
	_skip_btn.offset_top = 70
	_skip_btn.offset_bottom = 120
	_skip_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skip_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	_skip_btn.pressed.connect(func():
		emit_signal("skip_flight_requested")
	)
	$OverlayLayer.add_child(_skip_btn)

	if has_node("/root/KeybindingManager"):
		KeybindingManager.keybindings_changed.connect(_update_tooltips)
	_update_tooltips()

	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			var setting = gs.range_settings.debug_show_hit_distance
			if not setting.setting_changed.is_connected(_on_debug_hit_distance_setting_changed):
				setting.setting_changed.connect(_on_debug_hit_distance_setting_changed)

	_update_hit_distance_button_visibility()
	call_deferred("_update_hud_focus_neighbors")



var _putting_cam_server_process_time: float = 0.0
const PUTTING_CAM_PROCESS_INTERVAL: float = 0.04

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_golfer_camera_enabled() or _is_putting_cam_enabled:
		if _camera_feed_rect != null and _camera_feed_rect.texture == null:
			if not _use_phone_stream and CameraServer.is_monitoring_feeds() and CameraServer.get_feed_count() > 0:
				_update_camera_feed(true)
		
		# Drive putting state machine when fed by CameraServer
		if _is_putting_cam_enabled and not _use_phone_stream and _putting_state_machine != null and _camera_feed_rect != null and _camera_feed_rect.texture != null:
			var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
			var bridge_active: bool = pose_bridge != null and pose_bridge.has_method("is_desktop_camera_active") and pose_bridge.is_desktop_camera_active()
			if not bridge_active:
				_putting_cam_server_process_time += delta
				if _putting_cam_server_process_time >= PUTTING_CAM_PROCESS_INTERVAL:
					_putting_cam_server_process_time = 0.0
					var img: Image = null
					var tex = _camera_feed_rect.texture
					if tex != null and tex.has_method("get_image"):
						img = tex.get_image()
						if img != null and not img.is_empty():
							if img.is_compressed():
								img.decompress()
							if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
								img.convert(Image.FORMAT_RGBA8)
					if (img == null or img.is_empty()) and is_inside_tree():
						var vp = get_viewport()
						if vp != null:
							var vp_tex = vp.get_texture()
							if vp_tex != null:
								var full_img = vp_tex.get_image()
								if full_img != null and not full_img.is_empty():
									if full_img.is_compressed():
										full_img.decompress()
									if full_img.get_format() != Image.FORMAT_RGBA8 and full_img.get_format() != Image.FORMAT_RGB8:
										full_img.convert(Image.FORMAT_RGBA8)
									var target_rect: Rect2 = _camera_feed_rect.get_global_rect()
									var vp_sz = vp.get_visible_rect().size
									if target_rect.size.x > 10 and target_rect.size.y > 10:
										var crop_x = clamp(int(target_rect.position.x), 0, int(vp_sz.x - 10))
										var crop_y = clamp(int(target_rect.position.y), 0, int(vp_sz.y - 10))
										var crop_w = clamp(int(target_rect.size.x), 10, int(vp_sz.x - crop_x))
										var crop_h = clamp(int(target_rect.size.y), 10, int(vp_sz.y - crop_y))
										if crop_w > 0 and crop_h > 0:
											img = full_img.get_region(Rect2i(crop_x, crop_y, crop_w, crop_h))
					if img != null and not img.is_empty():
						var active_img = img
						if _camera_rotation_deg != 0:
							active_img = img.duplicate()
							_apply_image_rotation(active_img, _camera_rotation_deg)
						_last_putting_feed_image = active_img
						_putting_state_machine.process_frame(active_img, Time.get_ticks_usec())


func set_data(data: Dictionary, is_final_rest: bool = false) -> void:
	if is_final_rest and _is_valid_shot_data(data):
		_last_shot_data = _prepare_modal_shot_data(data)
	var is_imperial: bool = GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL if has_node("/root/GlobalSettings") else true

	var has_shot: bool = _is_valid_shot_data(data)
	var grid = get_node_or_null("GridCanvas")
	if grid != null:
		for child in grid.get_children():
			if child.name == "ClubSelector" or child.name == "AddRemoveButton":
				continue
			var stat_id = child.name
			var stat_def = StatDefinitions.get_stat_by_id(stat_id)
			if stat_def.is_empty():
				continue

			if child.has_method("set_units"):
				var u_str: String = str(stat_def.get("units_imperial" if is_imperial else "units_metric", ""))
				child.call("set_units", u_str)

			var base_label: String = str(stat_def.get("short_label", stat_id))
			var is_computed: bool = false
			if has_shot:
				if data.has("_computed_stats") and data["_computed_stats"] is Array:
					is_computed = stat_id in data["_computed_stats"]
				else:
					is_computed = _is_stat_computed_from_dict(stat_id, data)

			var val = null
			if data.has(stat_id):
				val = data[stat_id]
			elif stat_id == "BallSpeed" and data.has("Speed"):
				val = data["Speed"]
			elif stat_id == "Speed" and data.has("BallSpeed"):
				val = data["BallSpeed"]
			else:
				var aliases = stat_def.get("aliases", [])
				for alias in aliases:
					if data.has(alias):
						val = data[alias]
						break

			if has_shot:
				var is_dynamic: bool = StatDefinitions.is_dynamic_stat(stat_id)
				if val == null:
					if not is_final_rest and "data" in child and str(child.data) != "---" and str(child.data) != "":
						continue
					if stat_id == "SmashFactor":
						var b_spd = _get_dict_metric_float(data, ["Speed", "BallSpeed"])
						var c_spd = _get_dict_metric_float(data, ["ClubSpeed"])
						if b_spd > 0.0 and c_spd > 0.0 and _has_valid_dict_metric(data, ["ClubSpeed"]):
							val = "%.2f" % (b_spd / c_spd)
							is_computed = true
						else:
							val = "N/A"
					elif stat_id == "FaceToPath":
						var has_fa = _has_valid_dict_metric(data, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
						var has_cp = _has_valid_dict_metric(data, ["ClubPath", "Path", "RawClubPath"])
						if has_fa and has_cp:
							var fa = _get_dict_angle_float(data, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
							var cp = _get_dict_angle_float(data, ["ClubPath", "Path", "RawClubPath"])
							var ftp = fa - cp
							if absf(ftp) < 0.1:
								val = "0.0 Sq"
							elif ftp > 0.0:
								val = "%.1f O" % ftp
							else:
								val = "%.1f C" % absf(ftp)
							is_computed = true
						else:
							val = "N/A"
					elif stat_id == "ClubSpeed":
						var b_spd = _get_dict_metric_float(data, ["Speed", "BallSpeed"])
						var sf = _get_dict_metric_float(data, ["SmashFactor"])
						if b_spd > 0.0 and sf > 0.05 and _has_valid_dict_metric(data, ["SmashFactor"]):
							var cs = b_spd / sf
							val = "%.1f" % cs if is_imperial else "%.1f" % (cs * 0.44704)
							is_computed = true
						else:
							val = "N/A"
					elif not is_dynamic:
						val = "N/A"
					elif is_final_rest:
						val = "---"
					else:
						continue
				else:
					var str_v = str(val).strip_edges()
					if str_v == "---" and not is_dynamic:
						val = "N/A"
					elif stat_id == "SmashFactor":
						if str_v in ["0", "0.0", "0.00", "---", "N/A"]:
							var b_spd = _get_dict_metric_float(data, ["Speed", "BallSpeed"])
							var c_spd = _get_dict_metric_float(data, ["ClubSpeed"])
							if b_spd > 0.0 and c_spd > 0.0 and _has_valid_dict_metric(data, ["ClubSpeed"]):
								val = "%.2f" % (b_spd / c_spd)
								is_computed = true
							else:
								val = "N/A"
						elif str_v.is_valid_float() and float(str_v) <= 0.05:
							val = "N/A"
					elif stat_id == "FaceToPath":
						if str_v in ["---", "N/A"]:
							var has_fa = _has_valid_dict_metric(data, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
							var has_cp = _has_valid_dict_metric(data, ["ClubPath", "Path", "RawClubPath"])
							if has_fa and has_cp:
								var fa = _get_dict_angle_float(data, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
								var cp = _get_dict_angle_float(data, ["ClubPath", "Path", "RawClubPath"])
								var ftp = fa - cp
								if absf(ftp) < 0.1:
									val = "0.0 Sq"
								elif ftp > 0.0:
									val = "%.1f O" % ftp
								else:
									val = "%.1f C" % absf(ftp)
								is_computed = true
							else:
								val = "N/A"
					elif stat_id == "AttackAngle" or stat_id == "AngleOfAttack":
						if str_v in ["0", "0.0", "+0.0", "-0.0", "---", "N/A"] or (str_v.is_valid_float() and absf(float(str_v)) < 0.001):
							val = "N/A"
					elif stat_id == "ClubSpeed":
						if str_v in ["0", "0.0", "---", "N/A"]:
							var b_spd = _get_dict_metric_float(data, ["Speed", "BallSpeed"])
							var sf = _get_dict_metric_float(data, ["SmashFactor"])
							if b_spd > 0.0 and sf > 0.05 and _has_valid_dict_metric(data, ["SmashFactor"]):
								var cs = b_spd / sf
								val = "%.1f" % cs if is_imperial else "%.1f" % (cs * 0.44704)
								is_computed = true
							else:
								val = "N/A"
						elif str_v.is_valid_float() and float(str_v) <= 0.01:
							val = "N/A"
					elif stat_id == "DynamicLoft":
						if str_v in ["0", "0.0", "---", "N/A"] or (str_v.is_valid_float() and float(str_v) <= 0.01):
							val = "N/A"
			else:
				if val == null:
					if is_final_rest:
						val = "---"
					else:
						continue

			if stat_id == "VLA" or stat_id == "HLA":
				val = _format_angle(val)
			elif stat_id == "ClubPath":
				val = _format_club_path(val)
			elif stat_id == "FaceToPath":
				val = _format_face_to_path(val)
			if child.has_method("set_data"):
				child.call("set_data", str(val))
			if child.has_method("set_label"):
				if has_shot and is_computed and str(val) != "N/A" and str(val) != "---":
					child.call("set_label", "* %s *" % base_label)
				else:
					child.call("set_label", base_label)

	if is_final_rest:
		var cam_active: bool = is_golfer_camera_enabled()
		var analysis_active: bool = is_shot_analysis_enabled()
		if cam_active or analysis_active:
			var is_suggestions_only: bool = not cam_active and analysis_active
			var recorded_frames: Array[Dictionary] = []
			if not is_suggestions_only:
				if not _saved_swing_frames.is_empty():
					recorded_frames = _saved_swing_frames.duplicate()
				elif _swing_frame_buffer != null:
					recorded_frames = _swing_frame_buffer.get_captured_frames()
			var modal_data = _prepare_modal_shot_data(data)
			var p_name = str(modal_data.get("player", ""))
			if p_name.is_empty():
				p_name = get_selected_player_name()
				modal_data["player"] = p_name

			# 1. Detached window active: update it
			if _detached_modal != null and is_instance_valid(_detached_modal) and _detached_modal.get("is_detached"):
				_detached_modal.update_shot_data(modal_data, recorded_frames, is_suggestions_only)
			# 2. Attached modal active in overlay: update it
			elif has_node("OverlayLayer/SwingReplayModal"):
				var attached_modal = get_node("OverlayLayer/SwingReplayModal")
				if is_instance_valid(attached_modal) and attached_modal.has_method("update_shot_data"):
					attached_modal.update_shot_data(modal_data, recorded_frames, is_suggestions_only)
			# 3. No modal actively open: evaluate launch monitor recommendations and record to player profile
			else:
				var recs = GolfSwingAnalyzer.analyze_launch_monitor(modal_data)
				if not recs.is_empty():
					var mp_mgr = get_node_or_null("/root/MultiplayerManager")
					if mp_mgr != null and mp_mgr.has_method("record_player_swing_issues"):
						mp_mgr.record_player_swing_issues(p_name, recs)
						modal_data["_recommendations_recorded"] = true
						_last_shot_data["_recommendations_recorded"] = true


func _exit_tree() -> void:
	_close_detached_window()


func on_ball_hit() -> void:
	if is_golfer_camera_enabled() and _swing_frame_buffer != null:
		_saved_swing_frames.clear()
		# Continue capturing for 1.2s to capture impact and follow-through, then save snapshot
		get_tree().create_timer(1.2).timeout.connect(func():
			if _swing_frame_buffer != null:
				_saved_swing_frames = _swing_frame_buffer.get_captured_frames()
				if _detached_modal != null and is_instance_valid(_detached_modal) and _detached_modal.get("is_detached"):
					if not _last_shot_data.is_empty():
						var cam_active: bool = is_golfer_camera_enabled()
						var analysis_active: bool = is_shot_analysis_enabled()
						var is_suggestions_only: bool = not cam_active and analysis_active
						var modal_data = _prepare_modal_shot_data(_last_shot_data)
						_detached_modal.update_shot_data(modal_data, _saved_swing_frames, is_suggestions_only)
		)


func _prepare_modal_shot_data(data: Dictionary) -> Dictionary:
	var modal_data: Dictionary = data.duplicate()
	var player_node = get_parent().get_node_or_null("Player") if get_parent() != null else null

	if not modal_data.has("player") or str(modal_data["player"]).is_empty():
		var p_name = ""
		if get_parent() != null and get_parent().has_method("_get_current_player_name"):
			p_name = get_parent()._get_current_player_name()
		if p_name.is_empty():
			p_name = get_selected_player_name()
		modal_data["player"] = p_name

	if not modal_data.has("Club") or str(modal_data["Club"]).is_empty():
		var club_sel = find_child("ClubSelector", true, false)
		if club_sel != null and "current_club" in club_sel and club_sel.current_club != null and not club_sel.current_club.text.is_empty():
			modal_data["Club"] = club_sel.current_club.text
		elif get_parent() != null and get_parent().has_method("_get_selected_club"):
			modal_data["Club"] = get_parent()._get_selected_club()
		elif get_parent() != null and get_parent().has_method("_get_current_club"):
			modal_data["Club"] = get_parent()._get_current_club()
		elif player_node != null:
			if player_node.get("ball") != null and "current_selected_club" in player_node.ball:
				modal_data["Club"] = player_node.ball.current_selected_club

	if not modal_data.has("is_tee") or not modal_data.has("lie_type"):
		if player_node != null and player_node.get("ball") != null and "lie_type" in player_node.ball:
			var ball_lie = str(player_node.ball.lie_type)
			if not modal_data.has("lie_type"):
				modal_data["lie_type"] = ball_lie
			if not modal_data.has("is_tee"):
				modal_data["is_tee"] = (ball_lie.to_lower() == "teebox")
		else:
			if not modal_data.has("is_tee"):
				modal_data["is_tee"] = (str(modal_data.get("lie_type", "")).to_lower() == "teebox")
			if not modal_data.has("lie_type"):
				modal_data["lie_type"] = "teebox" if modal_data.get("is_tee", false) else "fairway"

	if not modal_data.has("handedness"):
		var p_name = str(modal_data.get("player", ""))
		var hand = 0
		if not p_name.is_empty() and has_node("/root/MultiplayerManager"):
			hand = get_node("/root/MultiplayerManager").get_player_handedness(p_name)
		elif has_node("/root/LaunchMonitorManager"):
			hand = get_node("/root/LaunchMonitorManager").get_handedness()
		modal_data["handedness"] = hand
	if not modal_data.has("is_lefty"):
		modal_data["is_lefty"] = (int(modal_data.get("handedness", 0)) == 1)

	return modal_data


func _has_valid_dict_metric(dict: Dictionary, keys: Array) -> bool:
	for k in keys:
		if dict.has(k):
			var v = dict[k]
			if v != null:
				var s = str(v).strip_edges()
				if s != "" and s != "---" and s != "N/A" and s != "n/a":
					return true
	return false


func _get_dict_metric_str(dict: Dictionary, keys: Array, default_val: String = "---") -> String:
	for k in keys:
		if dict.has(k):
			var v = dict[k]
			if v != null:
				var s = str(v).strip_edges()
				if s != "" and s != "---" and s != "N/A" and s != "n/a":
					return s
	return default_val


func _get_dict_metric_float(dict: Dictionary, keys: Array, default_val: float = 0.0) -> float:
	var s = _get_dict_metric_str(dict, keys, "")
	if s == "" or not s.is_valid_float():
		return default_val
	return float(s)


func _is_valid_shot_data(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	var spd = _get_dict_metric_float(d, ["Speed", "BallSpeed", "speed", "ball_speed"])
	var dist = _get_dict_metric_float(d, ["Distance", "Carry", "TotalDistance", "CarryDistance", "distance", "carry", "total_distance", "carry_distance"])
	return spd > 0.0 or dist > 0.0


func _format_shot_details_text(data: Dictionary) -> String:
	var is_imperial: bool = GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL if has_node("/root/GlobalSettings") else true
	var dist_u := "yds" if is_imperial else "m"
	var spd_u := "mph" if is_imperial else "m/s"
	var h_u := "ft" if is_imperial else "m"
	
	var lines: Array[String] = []
	var club_str = str(data.get("Club", data.get("club", "---")))
	if club_str != "---" and not club_str.is_empty():
		lines.append("Club: %s" % club_str)
	var player_str = str(data.get("player", data.get("Player", "")))
	if not player_str.is_empty():
		lines.append("Player: %s" % player_str)
	
	var spd = str(data.get("Speed", data.get("BallSpeed", data.get("speed", "---"))))
	lines.append("Ball Speed: %s %s" % [spd, spd_u])
	
	var carry = str(data.get("Carry", data.get("CarryDistance", data.get("carry", "---"))))
	lines.append("Carry Distance: %s %s" % [carry, dist_u])
	
	var tot_dist = str(data.get("Distance", data.get("TotalDistance", data.get("distance", "---"))))
	lines.append("Total Distance: %s %s" % [tot_dist, dist_u])
	
	var apex_val = str(data.get("Apex", data.get("apex", "---")))
	lines.append("Apex: %s %s" % [apex_val, h_u])
	
	var off_val = str(data.get("Offline", data.get("SideDistance", data.get("offline", "---"))))
	lines.append("Offline: %s %s" % [off_val, dist_u])
	
	var vla = str(data.get("VLA", data.get("LaunchAngle", "---")))
	lines.append("Launch Angle (VLA): %s°" % vla)
	
	var hla = str(data.get("HLA", data.get("LaunchDirection", "---")))
	lines.append("Launch Direction (HLA): %s°" % hla)
	
	var b_spin = str(data.get("BackSpin", "---"))
	lines.append("Back Spin: %s rpm" % b_spin)
	
	var s_spin = str(data.get("SideSpin", "---"))
	lines.append("Side Spin: %s rpm" % s_spin)
	
	var t_spin = str(data.get("TotalSpin", "---"))
	lines.append("Total Spin: %s rpm" % t_spin)
	
	var s_axis = str(data.get("SpinAxis", "---"))
	lines.append("Spin Axis: %s°" % s_axis)
	
	if data.has("ClubSpeed") and str(data["ClubSpeed"]) != "---" and str(data["ClubSpeed"]) != "N/A":
		var cs_title = "* Club Speed *" if _is_stat_computed_from_dict("ClubSpeed", data) else "Club Speed"
		lines.append("%s: %s %s" % [cs_title, str(data["ClubSpeed"]), spd_u])
	if data.has("SmashFactor") and str(data["SmashFactor"]) != "---" and str(data["SmashFactor"]) != "N/A":
		var sf_title = "* Smash Factor *" if _is_stat_computed_from_dict("SmashFactor", data) else "Smash Factor"
		lines.append("%s: %s" % [sf_title, str(data["SmashFactor"])])
	if data.has("ClubPath") and str(data["ClubPath"]) != "---" and str(data["ClubPath"]) != "N/A":
		var cp_title = "* Club Path *" if _is_stat_computed_from_dict("ClubPath", data) else "Club Path"
		lines.append("%s: %s" % [cp_title, str(data["ClubPath"])])
	if data.has("FaceAngle") and str(data["FaceAngle"]) != "---" and str(data["FaceAngle"]) != "N/A":
		var fa_title = "* Face Angle *" if _is_stat_computed_from_dict("FaceAngle", data) else "Face Angle"
		lines.append("%s: %s" % [fa_title, str(data["FaceAngle"])])
	if data.has("FaceToPath") and str(data["FaceToPath"]) != "---" and str(data["FaceToPath"]) != "N/A":
		var ftp_title = "* Face to Path *" if _is_stat_computed_from_dict("FaceToPath", data) else "Face to Path"
		lines.append("%s: %s" % [ftp_title, str(data["FaceToPath"])])
	if (data.has("AttackAngle") or data.has("AngleOfAttack")):
		var aoa_val = str(data.get("AttackAngle", data.get("AngleOfAttack", "")))
		if aoa_val != "---" and aoa_val != "N/A" and aoa_val != "" and aoa_val != "0.0":
			lines.append("Attack Angle: %s°" % aoa_val)
	
	return "\n".join(lines)


func _ensure_last_shot_data() -> bool:
	if _is_valid_shot_data(_last_shot_data):
		return true
	var p = get_parent()
	if p != null:
		var history = null
		if "shot_history" in p:
			history = p.shot_history as Array
		elif p.has_meta("shot_history"):
			history = p.get_meta("shot_history") as Array
		elif p.get("shot_history") != null:
			history = p.get("shot_history") as Array
		if history != null and not history.is_empty():
			for i in range(history.size() - 1, -1, -1):
				var item = history[i] as Dictionary
				if _is_valid_shot_data(item):
					var p_node = p.get_node_or_null("Player")
					var units = GlobalSettings.range_settings.range_units.value if has_node("/root/GlobalSettings") else PhysicsEnums.Units.IMPERIAL
					var formatted = ShotFormatter.format_ball_display(item, p_node, units, true)
					_last_shot_data = _prepare_modal_shot_data(formatted)
					return true
	return false


func trigger_swing_replay_modal(data: Dictionary) -> void:
	var cam_active: bool = is_golfer_camera_enabled()
	var analysis_active: bool = is_shot_analysis_enabled()

	# Strictly ensure the ball is not currently mid-flight
	var p_node = get_parent().get_node_or_null("Player") if get_parent() != null else null
	if p_node != null and p_node.get("ball") != null:
		var ball = p_node.ball
		if "state" in ball and (ball.state == PhysicsEnums.BallState.FLIGHT or ball.state == PhysicsEnums.BallState.ROLLOUT):
			return

	# Only display after the ball flight happens and valid metrics are recorded
	if not _is_valid_shot_data(data):
		if _prev_shot_popup != null:
			if _prev_shot_data_label != null:
				_prev_shot_data_label.text = "No completed shot data recorded yet.\nTake a swing on the range or course to view your swing replay, club delivery visuals, and AI flaw analysis."
			_prev_shot_popup.visible = true
			UIFocusGuard.push_lock(_prev_shot_popup)
			var c_btn = _prev_shot_popup.find_child("CloseBtn", true, false)
			if c_btn != null and is_instance_valid(c_btn):
				c_btn.call_deferred("grab_focus")
			else:
				KeybindingManager.focus_first_control(_prev_shot_popup)
		return

	if not cam_active and not analysis_active:
		if _prev_shot_popup != null:
			if _prev_shot_data_label != null:
				_prev_shot_data_label.text = _format_shot_details_text(data)
			_prev_shot_popup.visible = true
			UIFocusGuard.push_lock(_prev_shot_popup)
			var c_btn = _prev_shot_popup.find_child("CloseBtn", true, false)
			if c_btn != null and is_instance_valid(c_btn):
				c_btn.call_deferred("grab_focus")
			else:
				KeybindingManager.focus_first_control(_prev_shot_popup)
		return

	# If detached window is already open, focus it and update shot data
	if _detached_window != null and is_instance_valid(_detached_window) and _detached_modal != null and is_instance_valid(_detached_modal):
		_detached_window.grab_focus()
		var is_suggestions_only: bool = not cam_active and analysis_active
		var recorded_frames: Array[Dictionary] = []
		if not is_suggestions_only:
			if not _saved_swing_frames.is_empty():
				recorded_frames = _saved_swing_frames.duplicate()
			elif _swing_frame_buffer != null:
				recorded_frames = _swing_frame_buffer.get_captured_frames()
		var modal_data = _prepare_modal_shot_data(data)
		_detached_modal.update_shot_data(modal_data, recorded_frames, is_suggestions_only)
		return

	# Do not overwrite if attached replay modal is already open
	var existing = $OverlayLayer.get_node_or_null("SwingReplayModal")
	if existing != null:
		return

	var modal_script = load("res://UI/GolferCamera/swing_replay_modal.gd")
	if modal_script != null:
		var modal = modal_script.new()
		modal.name = "SwingReplayModal"
		modal.detach_requested.connect(func(): _detach_swing_replay_modal(modal))
		modal.attach_requested.connect(func(): _attach_swing_replay_modal(modal))

		var recorded_frames: Array[Dictionary] = []
		var is_suggestions_only: bool = not cam_active and analysis_active
		if not is_suggestions_only:
			if not _saved_swing_frames.is_empty():
				recorded_frames = _saved_swing_frames.duplicate()
			elif _swing_frame_buffer != null:
				recorded_frames = _swing_frame_buffer.get_captured_frames()
		
		var modal_data = _prepare_modal_shot_data(data)
		var should_detach = false
		if has_node("/root/GlobalSettings") and GlobalSettings.range_settings.replay_window_detached.value and modal_script.is_detach_supported():
			should_detach = true

		if should_detach:
			modal.setup_modal(modal_data, recorded_frames, is_suggestions_only)
			_detach_swing_replay_modal(modal)
		else:
			var club_sel = find_child("ClubSelector", true, false)
			if club_sel != null and club_sel.has_method("close_grid"):
				club_sel.close_grid()
			modal.z_index = 500
			$OverlayLayer.add_child(modal)
			modal.setup_modal(modal_data, recorded_frames, is_suggestions_only)


func _detach_swing_replay_modal(modal: Control) -> void:
	var modal_script = load("res://UI/GolferCamera/swing_replay_modal.gd")
	if modal_script == null or not modal_script.is_detach_supported():
		return
	if _detached_window != null and is_instance_valid(_detached_window):
		return

	var p = modal.get_parent()
	if p != null:
		p.remove_child(modal)

	if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		get_tree().root.gui_embed_subwindows = false

	var win = Window.new()
	win.name = "DetachedSwingReplayWindow"
	win.title = "⛳ Heckle Golf Sim - Shot Analysis & Swing Replay"
	win.transient = false
	win.exclusive = false
	win.unresizable = false
	win.borderless = false
	win.always_on_top = false
	win.min_size = Vector2i(760, 520)

	var saved_w = int(GlobalSettings.range_settings.replay_window_width.value) if has_node("/root/GlobalSettings") else 1100
	var saved_h = int(GlobalSettings.range_settings.replay_window_height.value) if has_node("/root/GlobalSettings") else 750
	win.size = Vector2i(maxi(760, saved_w), maxi(520, saved_h))

	var saved_x = int(GlobalSettings.range_settings.replay_window_position_x.value) if has_node("/root/GlobalSettings") else -1
	var saved_y = int(GlobalSettings.range_settings.replay_window_position_y.value) if has_node("/root/GlobalSettings") else -1

	if saved_x >= 0 and saved_y >= 0:
		win.position = Vector2i(saved_x, saved_y)
	else:
		var screen_count = DisplayServer.get_screen_count()
		var cur_screen = DisplayServer.window_get_current_screen()
		var target_screen = 1 if (screen_count > 1 and cur_screen == 0) else (0 if screen_count > 1 else cur_screen)
		var s_rect = DisplayServer.screen_get_usable_rect(target_screen)
		var pos_x = s_rect.position.x + 40
		var pos_y = s_rect.position.y + 40
		win.position = Vector2i(pos_x, pos_y)

	win.close_requested.connect(func():
		_close_detached_window()
	)

	var save_win_rect = func():
		if win != null and is_instance_valid(win) and has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.replay_window_position_x.value = win.position.x
			GlobalSettings.range_settings.replay_window_position_y.value = win.position.y
			GlobalSettings.range_settings.replay_window_width.value = win.size.x
			GlobalSettings.range_settings.replay_window_height.value = win.size.y

	win.focus_exited.connect(save_win_rect)
	win.size_changed.connect(save_win_rect)
	win.size_changed.connect(func():
		if modal != null and is_instance_valid(modal):
			modal._recenter_modal()
	)

	modal.is_detached = true
	_detached_window = win
	_detached_modal = modal

	win.add_child(modal)
	get_tree().root.add_child(win)

	if has_node("/root/GlobalSettings"):
		GlobalSettings.range_settings.replay_window_detached.value = true

	# Emit closed signal so range simulation unblocks immediately without waiting for Next Shot
	modal.emit_signal("closed")

	modal._recenter_modal()
	modal._build_ui()
	modal._update_playback_frame()
	if not modal.get("_is_analysis_complete") and not modal.get("_is_suggestions_only"):
		modal._start_background_wireframe_analysis()
	win.show()
	win.grab_focus()


func _attach_swing_replay_modal(modal: Control) -> void:
	if _detached_window != null and is_instance_valid(_detached_window):
		if has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.replay_window_position_x.value = _detached_window.position.x
			GlobalSettings.range_settings.replay_window_position_y.value = _detached_window.position.y
			GlobalSettings.range_settings.replay_window_width.value = _detached_window.size.x
			GlobalSettings.range_settings.replay_window_height.value = _detached_window.size.y
			GlobalSettings.range_settings.replay_window_detached.value = false

		if modal.get_parent() == _detached_window:
			_detached_window.remove_child(modal)
		_detached_window.queue_free()
		_detached_window = null
		_update_subwindow_embedding()

	_detached_modal = null
	modal.is_detached = false
	modal.z_index = 500
	if not modal.is_inside_tree():
		var club_sel = find_child("ClubSelector", true, false)
		if club_sel != null and club_sel.has_method("close_grid"):
			club_sel.close_grid()
		$OverlayLayer.add_child(modal)

	modal._recenter_modal()
	modal._build_ui()
	modal._update_playback_frame()
	if not modal.get("_is_analysis_complete") and not modal.get("_is_suggestions_only"):
		modal._start_background_wireframe_analysis()


func _close_detached_window() -> void:
	if _detached_window != null and is_instance_valid(_detached_window):
		if has_node("/root/GlobalSettings"):
			GlobalSettings.range_settings.replay_window_position_x.value = _detached_window.position.x
			GlobalSettings.range_settings.replay_window_position_y.value = _detached_window.position.y
			GlobalSettings.range_settings.replay_window_width.value = _detached_window.size.x
			GlobalSettings.range_settings.replay_window_height.value = _detached_window.size.y
			GlobalSettings.range_settings.replay_window_detached.value = false

		if _detached_modal != null and is_instance_valid(_detached_modal):
			_detached_modal._close_active_video_players()
			_detached_modal.queue_free()
		_detached_window.queue_free()
		_detached_window = null
		_detached_modal = null
		_update_subwindow_embedding()


func _format_angle(value) -> String:
	# Accept both numeric values and placeholder strings (e.g., "---" after reset).
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return "%3.1f" % value
	return str(value)


func _format_club_path(value) -> String:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var f_val := float(value)
		if absf(f_val) < 0.1:
			return "0.0 Str"
		elif f_val > 0.0:
			return "%.1f I-O" % f_val
		else:
			return "%.1f O-I" % absf(f_val)
	var s: String = str(value).strip_edges()
	if s == "---" or s == "N/A" or s.is_empty():
		return s
	var s_lower := s.to_lower()
	if s_lower.ends_with("in-out") or s_lower.ends_with("in-to-out"):
		var num := s.split(" ")[0]
		return "%s I-O" % num
	elif s_lower.ends_with("out-in") or s_lower.ends_with("out-to-in"):
		var num := s.split(" ")[0]
		return "%s O-I" % num
	return s


func _format_face_to_path(value) -> String:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var f_val := float(value)
		if absf(f_val) < 0.1:
			return "0.0 Sq"
		elif f_val > 0.0:
			return "%.1f O" % f_val
		else:
			return "%.1f C" % absf(f_val)
	var s: String = str(value).strip_edges()
	if s == "---" or s == "N/A" or s.is_empty():
		return s
	return s


func _get_dict_angle_float(dict: Dictionary, keys: Array, default_val: float = 0.0) -> float:
	var s = _get_dict_metric_str(dict, keys, "")
	if s == "":
		return default_val
	var cleaned = s.replace("°", "").strip_edges()
	var upper = cleaned.to_upper()
	var is_neg := false
	if "O-I" in upper or "OUT-IN" in upper or upper.ends_with(" C") or upper.ends_with("C"):
		is_neg = true
	cleaned = cleaned.replace("I-O", "").replace("O-I", "").replace("In-Out", "").replace("Out-In", "").replace("Str", "").replace("O", "").replace("C", "").replace("Sq", "").strip_edges()
	if cleaned.is_valid_float():
		var val = float(cleaned)
		return -absf(val) if is_neg else val
	return default_val


func _is_stat_computed_from_dict(stat_id: String, d: Dictionary) -> bool:
	if d.has("_computed_stats") and d["_computed_stats"] is Array:
		return stat_id in d["_computed_stats"]

	if stat_id == "SmashFactor":
		var direct_smash: bool = d.has("SmashFactor") and str(d["SmashFactor"]) not in ["", "0", "0.0", "0.00", "---", "N/A"] and float(str(d["SmashFactor"])) > 0.05
		if not direct_smash:
			var b_spd = _get_dict_metric_float(d, ["Speed", "BallSpeed"])
			var c_spd = _get_dict_metric_float(d, ["ClubSpeed"])
			return b_spd > 0.0 and c_spd > 0.0 and _has_valid_dict_metric(d, ["ClubSpeed"])
		return false
	elif stat_id == "FaceToPath":
		var direct_ftp: bool = _has_valid_dict_metric(d, ["FaceToPath", "RawFaceToPath"])
		if not direct_ftp:
			var has_fa = _has_valid_dict_metric(d, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
			var has_cp = _has_valid_dict_metric(d, ["ClubPath", "Path", "RawClubPath"])
			return has_fa and has_cp
		return false
	elif stat_id == "ClubSpeed":
		var direct_cs: bool = d.has("ClubSpeed") and str(d["ClubSpeed"]) not in ["", "0", "0.0", "---", "N/A"] and float(str(d["ClubSpeed"])) > 0.01
		if not direct_cs:
			var b_spd = _get_dict_metric_float(d, ["Speed", "BallSpeed"])
			var sf = _get_dict_metric_float(d, ["SmashFactor"])
			return b_spd > 0.0 and sf > 0.05 and _has_valid_dict_metric(d, ["SmashFactor"])
		return false
	elif stat_id == "ClubPath":
		var direct_cp: bool = _has_valid_dict_metric(d, ["ClubPath", "Path", "RawClubPath"])
		if not direct_cp:
			var has_fa = _has_valid_dict_metric(d, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
			var has_ftp = _has_valid_dict_metric(d, ["FaceToPath", "RawFaceToPath"])
			return has_fa and has_ftp
		return false
	elif stat_id == "FaceAngle":
		var direct_fa: bool = _has_valid_dict_metric(d, ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"])
		if not direct_fa:
			var has_ftp = _has_valid_dict_metric(d, ["FaceToPath", "RawFaceToPath"])
			var has_cp = _has_valid_dict_metric(d, ["ClubPath", "Path", "RawClubPath"])
			return has_ftp and has_cp
		return false
	elif stat_id == "TotalSpin":
		var direct_ts: bool = d.has("TotalSpin") and float(str(d["TotalSpin"])) > 0.0
		if not direct_ts:
			return _has_valid_dict_metric(d, ["BackSpin", "SideSpin"])
		return false
	elif stat_id == "SpinAxis":
		var direct_sa: bool = _has_valid_dict_metric(d, ["SpinAxis"])
		if not direct_sa:
			return _has_valid_dict_metric(d, ["BackSpin"]) and _has_valid_dict_metric(d, ["SideSpin"])
		return false
	elif stat_id == "BackSpin":
		var direct_bs: bool = _has_valid_dict_metric(d, ["BackSpin"])
		if not direct_bs:
			return _has_valid_dict_metric(d, ["TotalSpin"]) and _has_valid_dict_metric(d, ["SpinAxis"])
		return false
	elif stat_id == "SideSpin":
		var direct_ss: bool = _has_valid_dict_metric(d, ["SideSpin"])
		if not direct_ss:
			return _has_valid_dict_metric(d, ["TotalSpin"]) and _has_valid_dict_metric(d, ["SpinAxis"])
		return false
		return false

	return false


func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_session_recorder_recording_state(value: bool) -> void:
	var rec_btn = get_node_or_null("HBoxContainer/RecButton")
	if value:
		if rec_btn != null:
			rec_btn.text = "🔴 REC: On"
			apply_material_button_style(rec_btn, Color(0.6, 0.15, 0.15, 0.85))
			rec_btn.tooltip_text = "Stop Recording Range Session"
		if _session_pop_up != null:
			_session_pop_up.open()
	else:
		if rec_btn != null:
			rec_btn.text = "REC: Off"
			apply_material_button_style(rec_btn, Color(0.2, 0.2, 0.2, 0.7))
			rec_btn.tooltip_text = "Start Recording Range Session"


static func _get_scaled_avatar_texture(avatar_path: String, target_size: Vector2i = Vector2i(28, 28)) -> Texture2D:
	var path_to_load = avatar_path
	if path_to_load.is_empty() or not ResourceLoader.exists(path_to_load):
		path_to_load = "res://assets/images/avatars/avatar_1.svg"
	
	if not ResourceLoader.exists(path_to_load):
		return null
		
	var raw_tex = load(path_to_load)
	if raw_tex == null:
		return null
	var img = raw_tex.get_image()
	if img == null:
		return raw_tex
	var scaled_img = img.duplicate()
	scaled_img.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(scaled_img)

func _setup_profile_selector() -> void:
	if not has_node("HBoxContainer"):
		return
	
	if has_node("HBoxContainer/PlayerName"):
		$HBoxContainer/PlayerName.visible = false
	
	_profile_option = OptionButton.new()
	_profile_option.name = "ProfileOptionButton"
	_profile_option.tooltip_text = "Select Active Player Profile"
	_profile_option.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_option.expand_icon = true
	_profile_option.add_theme_constant_override("icon_max_width", 28)
	ThemeManager.apply_option_button_style(_profile_option, 18, Vector2(190, 44))
	
	$HBoxContainer.add_child(_profile_option)
	$HBoxContainer.move_child(_profile_option, 0)
	
	_populate_profile_selector()
	_profile_option.item_selected.connect(_on_profile_option_selected)

func _populate_profile_selector(preferred_selection: String = "") -> void:
	if _profile_option == null or not is_instance_valid(_profile_option):
		return
	
	_profile_option.clear()
	
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	var registered = mp_mgr.get_registered_players() if mp_mgr != null else []
	
	if registered.is_empty():
		var def_icon = _get_scaled_avatar_texture("")
		if def_icon != null:
			_profile_option.add_icon_item(def_icon, "Player 1", 0)
		else:
			_profile_option.add_item("Player 1", 0)
	else:
		for i in range(registered.size()):
			var p = registered[i]
			var p_name = str(p.get("name", "Player " + str(i + 1)))
			var p_avatar = str(p.get("avatar", ""))
			var icon_tex = _get_scaled_avatar_texture(p_avatar)
			if icon_tex != null:
				_profile_option.add_icon_item(icon_tex, p_name, i)
			else:
				_profile_option.add_item(p_name, i)
	
	var target_name = preferred_selection
	if target_name.is_empty():
		target_name = mp_mgr.get_default_range_profile_name() if mp_mgr != null else "Player 1"
	
	var sel_idx = 0
	for i in range(_profile_option.item_count):
		if _profile_option.get_item_text(i).to_lower() == target_name.to_lower():
			sel_idx = i
			break
			
	_profile_option.selected = sel_idx
	var active_name = _profile_option.get_item_text(sel_idx)
	if has_node("HBoxContainer/PlayerName"):
		$HBoxContainer/PlayerName.text = active_name
	_update_club_selector_bag(active_name)

func _update_club_selector_bag(player_name: String) -> void:
	var club_sel = find_child("ClubSelector", true, false)
	if club_sel != null and club_sel.has_method("update_bag_for_player"):
		club_sel.update_bag_for_player(player_name)

func _refresh_profile_selector() -> void:
	if _profile_option == null or not is_instance_valid(_profile_option):
		return
	var current_sel = get_selected_player_name()
	_populate_profile_selector(current_sel)

func _on_profile_option_selected(_idx: int) -> void:
	var p_name = ""
	if _profile_option != null and is_instance_valid(_profile_option) and _idx >= 0 and _idx < _profile_option.item_count:
		_profile_option.selected = _idx
		p_name = _profile_option.get_item_text(_idx)
	else:
		p_name = get_selected_player_name()
	if has_node("HBoxContainer/PlayerName"):
		$HBoxContainer/PlayerName.text = p_name
	_update_club_selector_bag(p_name)
	emit_signal("player_profile_changed", p_name)

func get_selected_player_name() -> String:
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty() and not mp_mgr.hole_ids.is_empty():
		var active_p = mp_mgr.get_active_player()
		if not active_p.is_empty() and not str(active_p.get("name", "")).is_empty():
			return str(active_p.get("name", "Player 1"))
	if _profile_option != null and is_instance_valid(_profile_option) and _profile_option.selected >= 0 and _profile_option.selected < _profile_option.item_count:
		return _profile_option.get_item_text(_profile_option.selected)
	if has_node("HBoxContainer/PlayerName") and not $HBoxContainer/PlayerName.text.is_empty():
		return $HBoxContainer/PlayerName.text
	return "Player 1"

func set_selected_player_name(player_name: String) -> void:
	if _profile_option != null and is_instance_valid(_profile_option):
		for i in range(_profile_option.item_count):
			if _profile_option.get_item_text(i).to_lower() == player_name.to_lower():
				_profile_option.selected = i
				if has_node("HBoxContainer/PlayerName"):
					$HBoxContainer/PlayerName.text = _profile_option.get_item_text(i)
				_update_club_selector_bag(_profile_option.get_item_text(i))
				emit_signal("player_profile_changed", _profile_option.get_item_text(i))
				return
	if has_node("HBoxContainer/PlayerName"):
		$HBoxContainer/PlayerName.text = player_name
	_update_club_selector_bag(player_name)
	emit_signal("player_profile_changed", player_name)


func _on_session_pop_up_dir_selected(dir: String, player_name: String) -> void:
	set_selected_player_name(player_name)
	emit_signal("set_session", dir, player_name)
	pass # Replace with function body.


func _on_session_pop_up_cancelled() -> void:
	# If setup was cancelled, emit the signal to toggle recording state off
	emit_signal("rec_button_pressed")



func _on_session_recorder_set_session(user: String, dir: String) -> void:
	set_selected_player_name(user)
	if _session_pop_up != null:
		_session_pop_up.set_session_data(user, dir)


func _on_shot_injector_inject(data: Variant) -> void:
	emit_signal("hit_shot", data)

func toggle_shot_injector(value) -> void:
	$ShotInjector.visible = value


func _on_toggle_settings_requested() -> void:
	$SettingsLayer.visible = not $SettingsLayer.visible
	if $SettingsLayer.visible:
		var rs = get_node_or_null("SettingsLayer/Container/RangeSettings")
		if rs != null:
			rs.visible = true
			if rs.has_method("_on_settings_opened"):
				rs.call("_on_settings_opened")


func _on_close_settings_requested() -> void:
	$SettingsLayer.visible = false
	var rs = get_node_or_null("SettingsLayer/Container/RangeSettings")
	if rs != null:
		rs.visible = false
	_refresh_profile_selector()


func set_total_distance(text: String) -> void:
		$OverlayLayer/TotalDistanceOverlay.text = text
		$OverlayLayer/TotalDistanceOverlay.visible = true


func clear_total_distance() -> void:
		$OverlayLayer/TotalDistanceOverlay.visible = false
		$OverlayLayer/TotalDistanceOverlay.text = "Total Distance --"


func _setup_averages_ui() -> void:
	var averages_hbox = HBoxContainer.new()
	averages_hbox.name = "AveragesBar"
	averages_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	averages_hbox.add_theme_constant_override("separation", 20)
	
	_averages_panel = PanelContainer.new()
	_averages_panel.name = "AveragesPanel"
	_averages_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_averages_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_averages_panel.custom_minimum_size = Vector2(0, 52)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.15, 0.18, 0.85)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_averages_panel.add_theme_stylebox_override("panel", panel_style)
	
	_avg_carry = Label.new()
	_avg_carry.text = "Avg Carry: ---"
	_avg_carry.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg_carry.add_theme_font_size_override("font_size", 15)
	averages_hbox.add_child(_avg_carry)
	
	_avg_speed = Label.new()
	_avg_speed.text = "Avg Speed: ---"
	_avg_speed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg_speed.add_theme_font_size_override("font_size", 15)
	averages_hbox.add_child(_avg_speed)
	
	_avg_spin = Label.new()
	_avg_spin.text = "Avg Spin: ---"
	_avg_spin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg_spin.add_theme_font_size_override("font_size", 15)
	averages_hbox.add_child(_avg_spin)
	
	_avg_offline = Label.new()
	_avg_offline.text = "Avg Offline: ---"
	_avg_offline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg_offline.add_theme_font_size_override("font_size", 15)
	averages_hbox.add_child(_avg_offline)
	
	_avg_target_diff = Label.new()
	_avg_target_diff.text = "Avg +/- Target: ---"
	_avg_target_diff.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg_target_diff.add_theme_font_size_override("font_size", 15)
	averages_hbox.add_child(_avg_target_diff)

	_avg_paused_indicator = Label.new()
	_avg_paused_indicator.name = "AvgPausedIndicator"
	_avg_paused_indicator.text = "⏸ (Tracking Off)"
	_avg_paused_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg_paused_indicator.add_theme_font_size_override("font_size", 15)
	_avg_paused_indicator.modulate = Color(1.0, 0.75, 0.25, 0.95)
	var is_tr_on := true
	var mp_mgr_init = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr_init != null and mp_mgr_init.has_method("is_club_averages_tracking_enabled"):
		is_tr_on = mp_mgr_init.is_club_averages_tracking_enabled()
	_avg_paused_indicator.visible = not is_tr_on
	averages_hbox.add_child(_avg_paused_indicator)

	_mishit_badge = Label.new()
	_mishit_badge.name = "MishitBadge"
	_mishit_badge.text = "⚠️ Miss-hit Excluded"
	_mishit_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mishit_badge.add_theme_font_size_override("font_size", 14)
	_mishit_badge.modulate = Color(1.0, 0.45, 0.35, 0.95)
	_mishit_badge.visible = false
	averages_hbox.add_child(_mishit_badge)

	_mishit_badge_timer = Timer.new()
	_mishit_badge_timer.name = "MishitBadgeTimer"
	_mishit_badge_timer.one_shot = true
	_mishit_badge_timer.timeout.connect(func():
		if _mishit_badge != null:
			_mishit_badge.visible = false
	)
	add_child(_mishit_badge_timer)
	
	_averages_panel.add_child(averages_hbox)

	_prev_shot_btn = Button.new()
	_prev_shot_btn.name = "PrevShotAnalysisButton"
	_prev_shot_btn.text = "Previous Shot Analysis"
	_prev_shot_btn.custom_minimum_size = Vector2(210, 48)
	_prev_shot_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prev_shot_btn.add_theme_font_size_override("font_size", 15)
	apply_material_button_style(_prev_shot_btn, Color(0.25, 0.35, 0.45, 0.85))
	_prev_shot_btn.pressed.connect(_on_prev_shot_analysis_pressed)
	_prev_shot_btn.tooltip_text = "View analysis and recommendations for your previous shot"

	var bottom_bar = HBoxContainer.new()
	bottom_bar.name = "BottomBarContainer"
	bottom_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 16)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	bottom_bar.add_child(_averages_panel)
	bottom_bar.add_child(_prev_shot_btn)
	add_child(bottom_bar)

	_update_prev_shot_analysis_visibility()

func show_mishit_alert(msg: String = "⚠️ Miss-hit excluded from club averages") -> void:
	if _mishit_badge != null:
		_mishit_badge.text = msg
		_mishit_badge.visible = true
		if _mishit_badge_timer != null:
			_mishit_badge_timer.start(4.5)


func update_average_stats(avg_data: Dictionary) -> void:
	var u_label := "yds" if GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL else "m"
	var s_label := "mph" if GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL else "m/s"
	
	var carry = float(avg_data.get("Carry", 0.0))
	var speed = float(avg_data.get("Speed", 0.0))
	var spin = float(avg_data.get("Spin", 0.0))
	var offline = float(avg_data.get("Offline", 0.0))
	var target_diff = float(avg_data.get("TargetDiff", 0.0))
	
	if GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL:
		carry *= 1.09361
		offline *= 1.09361
		target_diff *= 1.09361
	else:
		speed *= 0.44704
	
	if _avg_carry != null:
		_avg_carry.text = "Avg Carry: %.1f %s" % [carry, u_label]
	if _avg_speed != null:
		_avg_speed.text = "Avg Speed: %.1f %s" % [speed, s_label]
	if _avg_spin != null:
		_avg_spin.text = "Avg Spin: %.0f rpm" % spin
	if _avg_offline != null:
		_avg_offline.text = "Avg Offline: %.1f %s" % [offline, u_label]
	
	if _avg_target_diff != null:
		var sign_char := "+" if target_diff >= 0.0 else ""
		_avg_target_diff.text = "Avg +/- Target: %s%.1f %s" % [sign_char, target_diff, u_label]


func reset_average_stats() -> void:
	if _avg_carry != null:
		_avg_carry.text = "Avg Carry: ---"
	if _avg_speed != null:
		_avg_speed.text = "Avg Speed: ---"
	if _avg_spin != null:
		_avg_spin.text = "Avg Spin: ---"
	if _avg_offline != null:
		_avg_offline.text = "Avg Offline: ---"
	if _avg_target_diff != null:
		_avg_target_diff.text = "Avg +/- Target: ---"


func _setup_prev_shot_ui() -> void:
	_prev_shot_popup = Panel.new()
	_prev_shot_popup.name = "PrevShotPopup"
	_prev_shot_popup.visible = false
	_prev_shot_popup.custom_minimum_size = Vector2(460, 420)
	_prev_shot_popup.anchor_left = 0.5
	_prev_shot_popup.anchor_right = 0.5
	_prev_shot_popup.anchor_top = 0.5
	_prev_shot_popup.anchor_bottom = 0.5
	_prev_shot_popup.offset_left = -230
	_prev_shot_popup.offset_right = 230
	_prev_shot_popup.offset_top = -210
	_prev_shot_popup.offset_bottom = 210
	_prev_shot_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prev_shot_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_prev_shot_popup.z_index = 500
	ThemeManager.apply_modal_style(_prev_shot_popup, 12)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	
	var title = Label.new()
	title.text = "📊 Previous Shot Details"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(scroll, 24)
	
	_prev_shot_data_label = Label.new()
	_prev_shot_data_label.text = "No shot data recorded."
	_prev_shot_data_label.add_theme_font_size_override("font_size", 16)
	_prev_shot_data_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	_prev_shot_data_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prev_shot_data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_prev_shot_data_label)
	vbox.add_child(scroll)
	
	var close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(140, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ThemeManager.apply_primary_button_style(close_btn, 8)
	close_btn.pressed.connect(func():
		_prev_shot_popup.visible = false
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == _prev_shot_popup:
			UIFocusGuard.pop_lock(true)
	)
	vbox.add_child(close_btn)
	
	_prev_shot_popup.set_meta("on_focus_lock_popped", func():
		_prev_shot_popup.visible = false
	)
	_prev_shot_popup.add_child(vbox)
	if has_node("OverlayLayer"):
		$OverlayLayer.add_child(_prev_shot_popup)
	else:
		add_child(_prev_shot_popup)


func _update_prev_shot_analysis_visibility() -> void:
	if _prev_shot_btn != null:
		var cam_active: bool = is_golfer_camera_enabled()
		var analysis_active: bool = is_shot_analysis_enabled()
		_prev_shot_btn.visible = cam_active or analysis_active
		call_deferred("_update_hud_focus_neighbors")


func _on_prev_shot_analysis_pressed() -> void:
	toggle_prev_shot_analysis()


func get_active_swing_replay_modal() -> Control:
	if _detached_modal != null and is_instance_valid(_detached_modal) and _detached_modal.is_inside_tree() and not _detached_modal.is_queued_for_deletion():
		return _detached_modal
	var m = $OverlayLayer.get_node_or_null("SwingReplayModal") if has_node("OverlayLayer") else null
	if m != null and is_instance_valid(m) and not m.is_queued_for_deletion():
		return m
	var found = find_child("SwingReplayModal", true, false)
	if found != null and is_instance_valid(found) and not found.is_queued_for_deletion():
		return found as Control
	if get_tree() != null and get_tree().root != null:
		found = get_tree().root.find_child("SwingReplayModal", true, false)
		if found != null and is_instance_valid(found) and not found.is_queued_for_deletion():
			return found as Control
	return null


func toggle_prev_shot_analysis() -> void:
	# 1. If attached SwingReplayModal is open, close it
	var modal = get_active_swing_replay_modal()
	if modal != null and is_instance_valid(modal) and modal.visible:
		if modal.has_method("_on_close_button_pressed"):
			modal.call("_on_close_button_pressed")
		else:
			modal.queue_free()
		return

	# 2. If detached window modal is open, close it
	if _detached_window != null and is_instance_valid(_detached_window):
		_close_detached_window()
		return

	# 3. If prev shot popup panel is visible, hide it
	if _prev_shot_popup != null and is_instance_valid(_prev_shot_popup) and _prev_shot_popup.visible:
		_prev_shot_popup.visible = false
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == _prev_shot_popup:
			UIFocusGuard.pop_lock(true)
		return

	# 4. Otherwise, open previous shot analysis
	if not _ensure_last_shot_data():
		if _prev_shot_popup != null:
			if _prev_shot_data_label != null:
				_prev_shot_data_label.text = "No completed shot data recorded yet.\nTake a swing on the range or course to view your swing replay, club delivery visuals, and AI flaw analysis."
			_prev_shot_popup.visible = true
			UIFocusGuard.push_lock(_prev_shot_popup)
			var c_btn = _prev_shot_popup.find_child("CloseBtn", true, false)
			if c_btn != null and is_instance_valid(c_btn):
				c_btn.call_deferred("grab_focus")
			else:
				KeybindingManager.focus_first_control(_prev_shot_popup)
		return
	
	trigger_swing_replay_modal(_last_shot_data)


func is_stats_visible() -> bool:
	var dist_panel = get_node_or_null("GridCanvas/Distance")
	return dist_panel.visible if dist_panel != null else true


func set_stats_visible(show_stats: bool) -> void:
	var grid = get_node_or_null("GridCanvas")
	if grid != null:
		for child in grid.get_children():
			if child.name != "ClubSelector":
				child.visible = show_stats
	if _averages_panel != null:
		_averages_panel.visible = show_stats
	if _stats_btn != null and is_instance_valid(_stats_btn):
		if show_stats:
			apply_circular_button_style(_stats_btn, Color(0.24, 0.46, 0.72, 0.85))
		else:
			apply_circular_button_style(_stats_btn, Color(0.15, 0.15, 0.15, 0.85))
	stats_visibility_changed.emit(show_stats)


func toggle_stats_visibility() -> void:
	set_stats_visible(not is_stats_visible())


func _toggle_shot_data_window() -> void:
	if _shot_data_window == null or not is_instance_valid(_shot_data_window):
		var window := Window.new()
		window.title = "Shot Data Analysis"
		window.size = Vector2i(1000, 720)
		window.min_size = Vector2i(720, 520)
		window.popup_window = false
		window.borderless = false
		window.unresizable = false
		window.mode = Window.MODE_WINDOWED
		window.transient = false
		window.exclusive = false
		window.always_on_top = false
		window.close_requested.connect(func():
			window.hide()
			_update_subwindow_embedding()
			_update_shot_data_button_style()
		)
		var content := Control.new()
		content.set_script(load("res://UI/ShotAnalysis/shot_analysis_window.gd"))
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		window.add_child(content)
		if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
			get_tree().root.gui_embed_subwindows = false
		window.position = _get_shot_analysis_window_position(window.size)
		get_tree().root.add_child(window)
		_shot_data_window = window
		tree_exiting.connect(_on_analysis_owner_tree_exiting.bind(window), CONNECT_ONE_SHOT)
		var range_node := get_parent()
		var history: Variant = range_node.get("shot_history") if range_node != null else []
		content.call("initialize", history if history is Array else [])
		window.show()
	else:
		if _shot_data_window.visible:
			_shot_data_window.hide()
		else:
			if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
				get_tree().root.gui_embed_subwindows = false
			_shot_data_window.show()
	_update_subwindow_embedding()
	_update_shot_data_button_style()


func record_analysis_shot(data: Dictionary) -> void:
	if _shot_data_window == null or not is_instance_valid(_shot_data_window):
		return
	if _shot_data_window.get_child_count() == 0:
		return
	var content := _shot_data_window.get_child(0)
	if content.has_method("add_shot"):
		content.call("add_shot", data)


func _on_analysis_owner_tree_exiting(window: Window) -> void:
	if is_instance_valid(window):
		window.hide()
		window.queue_free()
		_update_subwindow_embedding()


func _get_shot_analysis_window_position(window_size: Vector2i) -> Vector2i:
	var screen_count := DisplayServer.get_screen_count()
	var current_screen := DisplayServer.window_get_current_screen()
	var target_screen := current_screen
	if screen_count > 1:
		target_screen = (current_screen + 1) % screen_count
	var usable_rect := DisplayServer.screen_get_usable_rect(target_screen)
	if target_screen != current_screen:
		return usable_rect.position + (usable_rect.size - window_size) / 2
	return usable_rect.position + Vector2i(24, 48)


func _update_subwindow_embedding() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS) or get_tree() == null or get_tree().root == null:
		return
	var detached_replay_open := _detached_window != null and is_instance_valid(_detached_window)
	var analysis_window_open := _shot_data_window != null and is_instance_valid(_shot_data_window) and _shot_data_window.visible
	if detached_replay_open or analysis_window_open:
		get_tree().root.gui_embed_subwindows = false
	else:
		get_tree().root.gui_embed_subwindows = bool(ProjectSettings.get_setting("display/window/subwindows/embed_subwindows", true))


func _update_shot_data_button_style() -> void:
	if _shot_data_btn == null or not is_instance_valid(_shot_data_btn):
		return
	var is_open := _shot_data_window != null and is_instance_valid(_shot_data_window) and _shot_data_window.visible
	apply_circular_button_style(_shot_data_btn, Color(0.43, 0.4, 0.78, 0.95) if is_open else Color(0.33, 0.3, 0.62, 0.9))


func apply_material_button_style(btn: Button, bg_color: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = bg_color.lightened(0.2)
	style_normal.content_margin_left = 16
	style_normal.content_margin_right = 16
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)
	style_hover.border_color = Color(1, 1, 1, 0.3)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)
	style_pressed.border_color = Color(1, 1, 1, 0.2)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.4)
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.3)

	var style_focus = style_normal.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3

	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_stylebox_override("focus", style_focus)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	if not btn.has_theme_font_size_override("font_size"):
		btn.add_theme_font_size_override("font_size", 16)
	if btn.custom_minimum_size.y < 48:
		btn.custom_minimum_size.y = 48


func apply_circular_button_style(btn: Button, bg_color: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 28 # Half of 56 height
	style_normal.corner_radius_top_right = 28
	style_normal.corner_radius_bottom_left = 28
	style_normal.corner_radius_bottom_right = 28
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)

	var style_focus = style_normal.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3

	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_focus)


func _on_home_button_pressed() -> void:
	var is_practice = false
	if has_node("/root/MultiplayerManager") and get_node("/root/MultiplayerManager").practice_mode_active:
		is_practice = true
	var parent = get_parent()
	if parent != null and parent.get("practice_mode_active") == true:
		is_practice = true
	var has_players = has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty()

	if is_practice or has_players:
		_show_exit_confirm_dialog()
	else:
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _show_exit_confirm_dialog() -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("SpeakHomeButtonHeckle", {"game_mode": "range"})

	var club_sel = find_child("ClubSelector", true, false)
	if club_sel != null and club_sel.has_method("close_grid"):
		club_sel.close_grid()

	if _exit_confirm_dialog != null:
		_exit_confirm_dialog.visible = true
		var no_b = _exit_confirm_dialog.find_child("NoButton", true, false) as Button
		if no_b != null:
			no_b.call_deferred("grab_focus")
		return

	_exit_confirm_dialog = Control.new()
	_exit_confirm_dialog.name = "ExitConfirmDialog"
	_exit_confirm_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit_confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_exit_confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_exit_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_confirm_dialog.z_index = 500

	var exit_backdrop = ColorRect.new()
	exit_backdrop.name = "Backdrop"
	exit_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	exit_backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	exit_backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	exit_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	exit_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_exit_confirm_dialog.visible = false
	)
	_exit_confirm_dialog.add_child(exit_backdrop)

	var exit_panel = PanelContainer.new()
	exit_panel.name = "ExitDialogPanel"
	exit_panel.anchor_left = 0.5
	exit_panel.anchor_right = 0.5
	exit_panel.anchor_top = 0.5
	exit_panel.anchor_bottom = 0.5
	exit_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	exit_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	exit_panel.offset_left = -250
	exit_panel.offset_right = 250
	exit_panel.offset_top = -115
	exit_panel.offset_bottom = 115

	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	exit_style.border_width_left = 2
	exit_style.border_width_top = 2
	exit_style.border_width_right = 2
	exit_style.border_width_bottom = 2
	exit_style.border_color = Color(0.35, 0.35, 0.35, 0.8)
	exit_style.corner_radius_top_left = 12
	exit_style.corner_radius_top_right = 12
	exit_style.corner_radius_bottom_left = 12
	exit_style.corner_radius_bottom_right = 12
	exit_style.content_margin_left = 28
	exit_style.content_margin_top = 24
	exit_style.content_margin_right = 28
	exit_style.content_margin_bottom = 24
	exit_panel.add_theme_stylebox_override("panel", exit_style)

	var exit_content_vbox = VBoxContainer.new()
	exit_content_vbox.add_theme_constant_override("separation", 20)

	var exit_title_lbl = Label.new()
	exit_title_lbl.text = "Exit Match"
	exit_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_title_lbl.add_theme_font_size_override("font_size", 28)
	exit_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4, 1.0))
	exit_title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	exit_title_lbl.add_theme_constant_override("outline_size", 4)
	exit_content_vbox.add_child(exit_title_lbl)

	var exit_msg_lbl = Label.new()
	exit_msg_lbl.text = "Are you sure you want to stop the match and return to the home screen?"
	exit_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_msg_lbl.custom_minimum_size = Vector2(400, 0)
	exit_msg_lbl.add_theme_font_size_override("font_size", 20)
	exit_msg_lbl.add_theme_color_override("font_color", Color.WHITE)
	exit_msg_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	exit_msg_lbl.add_theme_constant_override("outline_size", 4)
	exit_content_vbox.add_child(exit_msg_lbl)

	var exit_btn_hbox = HBoxContainer.new()
	exit_btn_hbox.add_theme_constant_override("separation", 24)
	exit_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var exit_yes_btn = Button.new()
	exit_yes_btn.name = "YesButton"
	exit_yes_btn.text = "Yes"
	exit_yes_btn.custom_minimum_size = Vector2(140, 50)
	apply_material_button_style(exit_yes_btn, Color(0.65, 0.22, 0.22, 0.85))
	exit_yes_btn.pressed.connect(func():
		_exit_confirm_dialog.visible = false
		if has_node("/root/MultiplayerManager"):
			var mp = get_node("/root/MultiplayerManager")
			mp.players.clear()
			mp.practice_mode_active = false
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
	)
	exit_btn_hbox.add_child(exit_yes_btn)

	var exit_no_btn = Button.new()
	exit_no_btn.name = "NoButton"
	exit_no_btn.text = "No"
	exit_no_btn.custom_minimum_size = Vector2(140, 50)
	apply_material_button_style(exit_no_btn, Color(0.24, 0.46, 0.72, 0.85))
	exit_no_btn.pressed.connect(func():
		_exit_confirm_dialog.visible = false
	)
	exit_btn_hbox.add_child(exit_no_btn)

	exit_yes_btn.focus_neighbor_right = exit_yes_btn.get_path_to(exit_no_btn)
	exit_yes_btn.focus_neighbor_left = exit_yes_btn.get_path_to(exit_no_btn)
	exit_no_btn.focus_neighbor_left = exit_no_btn.get_path_to(exit_yes_btn)
	exit_no_btn.focus_neighbor_right = exit_no_btn.get_path_to(exit_yes_btn)

	exit_content_vbox.add_child(exit_btn_hbox)
	exit_panel.add_child(exit_content_vbox)
	_exit_confirm_dialog.add_child(exit_panel)
	$OverlayLayer.add_child(_exit_confirm_dialog)

	exit_no_btn.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	var cam_setup = _get_active_camera_setup_dialog()
	if cam_setup != null and is_instance_valid(cam_setup) and cam_setup.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			_close_camera_setup_dialog(cam_setup)
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
			return

	if _exit_confirm_dialog != null and is_instance_valid(_exit_confirm_dialog) and _exit_confirm_dialog.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			_exit_confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
		   event.is_action_pressed("aim_left") or event.is_action_pressed("aim_right"):
			var cur_f = get_viewport().gui_get_focus_owner()
			var no_btn = _exit_confirm_dialog.find_child("NoButton", true, false) as Button
			var yes_btn = _exit_confirm_dialog.find_child("YesButton", true, false) as Button
			if cur_f == yes_btn and no_btn != null:
				no_btn.grab_focus()
			elif yes_btn != null:
				yes_btn.grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
			var cur_f = get_viewport().gui_get_focus_owner()
			var yes_btn = _exit_confirm_dialog.find_child("YesButton", true, false) as Button
			var no_btn = _exit_confirm_dialog.find_child("NoButton", true, false) as Button
			if cur_f == yes_btn:
				yes_btn.emit_signal("pressed")
			elif no_btn != null:
				no_btn.emit_signal("pressed")
			else:
				_exit_confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
			return


func update_map_button_text(is_aerial: bool) -> void:
	var target_btn = _map_btn
	if target_btn == null and has_node("OverlayLayer/MapButton"):
		target_btn = $OverlayLayer/MapButton
	if target_btn != null:
		target_btn.text = ""
		if is_aerial:
			target_btn.tooltip_text = "Return to Player"
			apply_circular_button_style(target_btn, Color(0.2, 0.7, 0.35, 0.95))
		else:
			target_btn.tooltip_text = "Toggle Map View"
			apply_circular_button_style(target_btn, Color(0.18, 0.45, 0.25, 0.85))


func show_skip_button() -> void:
	if _skip_btn != null:
		_skip_btn.visible = true
		$OverlayLayer/TotalDistanceOverlay.visible = false


func hide_skip_button() -> void:
	if _skip_btn != null:
		_skip_btn.visible = false


func _setup_golfer_camera_ui() -> void:
	_golfer_cam_panel = PanelContainer.new()
	_golfer_cam_panel.name = "GolferCameraPanel"
	_golfer_cam_panel.visible = false
	_golfer_cam_panel.position = Vector2(30, 352)
	_golfer_cam_panel.custom_minimum_size = Vector2(380, 590)
	_golfer_cam_panel.size = Vector2(380, 590)
	_golfer_cam_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Glassmorphic card styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.5, 0.7, 0.8)
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 10
	_golfer_cam_panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header bar
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	
	var title = Label.new()
	title.name = "PanelTitleLabel"
	title.text = "📹 GOLFER CAM"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Setup, Rotate & Flip Camera Buttons
	var header_setup_btn = Button.new()
	header_setup_btn.name = "HeaderSetupButton"
	header_setup_btn.text = "⚙️ Setup"
	header_setup_btn.custom_minimum_size = Vector2(80, 48)
	apply_material_button_style(header_setup_btn, Color(0.2, 0.45, 0.65, 0.9))
	header_setup_btn.pressed.connect(func(): _toggle_camera_setup_dialog(_is_putting_cam_enabled))
	header.add_child(header_setup_btn)

	_camera_color_pick_btn = Button.new()
	_camera_color_pick_btn.name = "ColorPickButton"
	_camera_color_pick_btn.text = "🎨"
	_camera_color_pick_btn.tooltip_text = "Pick Ball or Mat/Background Color from Video Feed"
	_camera_color_pick_btn.custom_minimum_size = Vector2(52, 48)
	apply_material_button_style(_camera_color_pick_btn, Color(0.48, 0.28, 0.58, 0.9))
	_camera_color_pick_btn.pressed.connect(_open_color_picker_menu)
	_camera_color_pick_btn.visible = false
	header.add_child(_camera_color_pick_btn)

	_camera_rotate_btn = Button.new()
	_camera_rotate_btn.name = "RotateCameraButton"
	_camera_rotate_btn.custom_minimum_size = Vector2(74, 48)
	_update_camera_rotate_button_text()
	apply_material_button_style(_camera_rotate_btn, Color(0.2, 0.48, 0.4, 0.9))
	_camera_rotate_btn.pressed.connect(_on_rotate_camera_pressed)
	header.add_child(_camera_rotate_btn)

	_camera_flip_btn = Button.new()
	_camera_flip_btn.name = "FlipCameraButton"
	_camera_flip_btn.text = "🔄 Flip"
	_camera_flip_btn.custom_minimum_size = Vector2(74, 48)
	apply_material_button_style(_camera_flip_btn, Color(0.2, 0.4, 0.6, 0.9))
	_camera_flip_btn.pressed.connect(_on_flip_camera_pressed)
	header.add_child(_camera_flip_btn)
	
	var status_dot = Label.new()
	status_dot.text = "🔴 LIVE"
	status_dot.add_theme_font_size_override("font_size", 14)
	status_dot.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	header.add_child(status_dot)

	_camera_minimize_btn = Button.new()
	_camera_minimize_btn.name = "MinimizeCameraButton"
	_camera_minimize_btn.text = "🗕"
	_camera_minimize_btn.tooltip_text = "Minimize Camera (Keeps running in background)"
	_camera_minimize_btn.custom_minimum_size = Vector2(44, 48)
	apply_material_button_style(_camera_minimize_btn, Color(0.25, 0.35, 0.45, 0.9))
	_camera_minimize_btn.pressed.connect(minimize_camera)
	header.add_child(_camera_minimize_btn)
	
	main_vbox.add_child(header)

	# Feed Container (Viewport / Texture)
	var feed_container = PanelContainer.new()
	feed_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color(0.04, 0.05, 0.07, 0.95)
	inner_style.corner_radius_top_left = 8
	inner_style.corner_radius_top_right = 8
	inner_style.corner_radius_bottom_left = 8
	inner_style.corner_radius_bottom_right = 8
	feed_container.add_theme_stylebox_override("panel", inner_style)

	_camera_feed_rect = TextureRect.new()
	_camera_feed_rect.name = "CameraFeedRect"
	_camera_feed_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camera_feed_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_camera_feed_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_feed_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_camera_feed_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_camera_feed_rect.gui_input.connect(_on_feed_gui_input)
	feed_container.add_child(_camera_feed_rect)

	# Stick Skeleton & Golf Club Path Overlay
	if _swing_frame_buffer == null:
		_swing_frame_buffer = SwingFrameBuffer.new()
		_swing_frame_buffer.name = "SwingFrameBuffer"
		add_child(_swing_frame_buffer)

	var skel_overlay_script = load("res://UI/GolferCamera/golfer_skeleton_overlay.gd")
	if skel_overlay_script != null:
		var live_skel = skel_overlay_script.new()
		live_skel.name = "LiveGolferSkeletonOverlay"
		live_skel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		live_skel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		live_skel.frame_buffer = _swing_frame_buffer
		feed_container.add_child(live_skel)

	# Overlay UI for Disconnected Feed Status
	var overlay_vbox = VBoxContainer.new()
	overlay_vbox.name = "OverlayStatusVBox"
	overlay_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var feed_label = Label.new()
	feed_label.name = "FeedStatusLabel"
	feed_label.text = "GOLFER CAMERA FEED\n[ Click ⚙️ Setup to connect ]"
	feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feed_label.add_theme_font_size_override("font_size", 14)
	feed_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.85))
	overlay_vbox.add_child(feed_label)

	var setup_btn = Button.new()
	setup_btn.name = "SetupCameraButton"
	setup_btn.text = "⚙️ Connect Camera"
	setup_btn.custom_minimum_size = Vector2(160, 38)
	setup_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apply_material_button_style(setup_btn, Color(0.2, 0.45, 0.65, 0.9))
	setup_btn.pressed.connect(func(): _open_camera_setup_dialog(_is_putting_cam_enabled))
	overlay_vbox.add_child(setup_btn)

	feed_container.add_child(overlay_vbox)
	main_vbox.add_child(feed_container)

	# Putting Camera Track Line Alignment Controls (visible when putting cam is active)
	_putting_align_container = PanelContainer.new()
	_putting_align_container.name = "PuttingAlignContainer"
	_putting_align_container.visible = false
	var align_style = StyleBoxFlat.new()
	align_style.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	align_style.corner_radius_bottom_left = 6
	align_style.corner_radius_bottom_right = 6
	align_style.corner_radius_top_left = 6
	align_style.corner_radius_top_right = 6
	align_style.content_margin_left = 8
	align_style.content_margin_top = 4
	align_style.content_margin_right = 8
	align_style.content_margin_bottom = 4
	_putting_align_container.add_theme_stylebox_override("panel", align_style)

	var align_hbox = HBoxContainer.new()
	align_hbox.add_theme_constant_override("separation", 6)
	align_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var line_lbl = Label.new()
	var is_mob: bool = MobilePerformance.is_mobile()
	line_lbl.text = "🎯 Line:"
	line_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 12)
	line_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	align_hbox.add_child(line_lbl)

	var left_btn = Button.new()
	left_btn.text = "◀"
	left_btn.tooltip_text = "Move Ball Circle & Track Line Left"
	left_btn.custom_minimum_size = Vector2(42, 44) if is_mob else Vector2(30, 28)
	left_btn.add_theme_font_size_override("font_size", 18 if is_mob else 14)
	apply_material_button_style(left_btn, Color(0.2, 0.35, 0.45, 0.85))
	left_btn.pressed.connect(func():
		if _putting_overlay != null:
			_putting_overlay.set_circle_x(_putting_overlay.circle_center.x - 0.03, true)
	)
	align_hbox.add_child(left_btn)

	_putting_align_slider = HSlider.new()
	_putting_align_slider.name = "PuttingAlignSlider"
	_putting_align_slider.min_value = 0.15
	_putting_align_slider.max_value = 0.85
	_putting_align_slider.step = 0.01
	_putting_align_slider.value = 0.50
	_putting_align_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_putting_align_slider.custom_minimum_size = Vector2(70, 48 if is_mob else 36)
	_putting_align_slider.tooltip_text = "Move Track Line left or right (avoids camera stand obstruction)"
	ThemeManager.apply_slider_style(_putting_align_slider, 48 if is_mob else 36, 70)
	_putting_align_slider.value_changed.connect(func(val: float):
		if _putting_overlay != null:
			_putting_overlay.set_circle_x(val, true)
	)
	align_hbox.add_child(_putting_align_slider)

	var right_btn = Button.new()
	right_btn.text = "▶"
	right_btn.tooltip_text = "Move Ball Circle & Track Line Right"
	right_btn.custom_minimum_size = Vector2(42, 44) if is_mob else Vector2(30, 28)
	right_btn.add_theme_font_size_override("font_size", 18 if is_mob else 14)
	apply_material_button_style(right_btn, Color(0.2, 0.35, 0.45, 0.85))
	right_btn.pressed.connect(func():
		if _putting_overlay != null:
			_putting_overlay.set_circle_x(_putting_overlay.circle_center.x + 0.03, true)
	)
	align_hbox.add_child(right_btn)

	var center_btn = Button.new()
	center_btn.text = "Center"
	center_btn.tooltip_text = "Reset Track Line to Center (50%)"
	center_btn.custom_minimum_size = Vector2(60, 44) if is_mob else Vector2(50, 28)
	center_btn.add_theme_font_size_override("font_size", 13 if is_mob else 11)
	apply_material_button_style(center_btn, Color(0.25, 0.4, 0.35, 0.85))
	center_btn.pressed.connect(func():
		if _putting_overlay != null:
			_putting_overlay.reset_circle_x()
	)
	align_hbox.add_child(center_btn)

	_putting_align_container.add_child(align_hbox)
	main_vbox.add_child(_putting_align_container)

	# Footer info
	_panel_footer_label = Label.new()
	_panel_footer_label.name = "PanelFooterLabel"
	_panel_footer_label.text = "Position camera behind ball facing target line"
	_panel_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_footer_label.add_theme_font_size_override("font_size", 11)
	_panel_footer_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	main_vbox.add_child(_panel_footer_label)

	_golfer_cam_panel.add_child(main_vbox)
	$OverlayLayer.add_child(_golfer_cam_panel)

	# Floating restore pill (visible only when camera is minimized & recording)
	_camera_restore_pill = Button.new()
	_camera_restore_pill.name = "CameraRestorePill"
	_camera_restore_pill.text = "📹 Golfer Cam [REC] 🗖"
	_camera_restore_pill.tooltip_text = "Golfer Cam is recording in background. Click to expand preview."
	_camera_restore_pill.visible = false
	_camera_restore_pill.custom_minimum_size = Vector2(180, 42)
	_camera_restore_pill.anchor_left = 0.0
	_camera_restore_pill.anchor_right = 0.0
	_camera_restore_pill.anchor_top = 1.0
	_camera_restore_pill.anchor_bottom = 1.0
	_camera_restore_pill.offset_left = 30
	_camera_restore_pill.offset_top = -160
	_camera_restore_pill.offset_right = 210
	_camera_restore_pill.offset_bottom = -118
	_camera_restore_pill.add_theme_font_size_override("font_size", 13)
	
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.12, 0.45, 0.4, 0.9)
	pill_style.corner_radius_top_left = 10
	pill_style.corner_radius_top_right = 10
	pill_style.corner_radius_bottom_left = 10
	pill_style.corner_radius_bottom_right = 10
	pill_style.content_margin_left = 10
	pill_style.content_margin_right = 10
	pill_style.content_margin_top = 8
	pill_style.content_margin_bottom = 8
	pill_style.border_width_left = 1
	pill_style.border_width_top = 1
	pill_style.border_width_right = 1
	pill_style.border_width_bottom = 1
	pill_style.border_color = Color(0.2, 0.75, 0.65, 0.8)
	_camera_restore_pill.add_theme_stylebox_override("normal", pill_style)
	
	var pill_hover = pill_style.duplicate()
	pill_hover.bg_color = Color(0.16, 0.55, 0.48, 0.95)
	_camera_restore_pill.add_theme_stylebox_override("hover", pill_hover)
	
	var pill_pressed = pill_style.duplicate()
	pill_pressed.bg_color = Color(0.08, 0.35, 0.3, 0.95)
	_camera_restore_pill.add_theme_stylebox_override("pressed", pill_pressed)
	
	_camera_restore_pill.pressed.connect(restore_camera)
	$OverlayLayer.add_child(_camera_restore_pill)


var _hud_elements_suppressed: bool = false


func set_hud_elements_visible(is_vis: bool) -> void:
	_hud_elements_suppressed = not is_vis
	_update_restore_pill_visibility()
	if _golfer_cam_panel != null and is_instance_valid(_golfer_cam_panel):
		if not is_vis:
			_golfer_cam_panel.visible = false
		else:
			_golfer_cam_panel.visible = is_camera_modal_open()
	if _stats_btn != null and is_instance_valid(_stats_btn):
		_stats_btn.visible = is_vis
	if _shot_data_btn != null and is_instance_valid(_shot_data_btn):
		_shot_data_btn.visible = is_vis and is_driving_range()
	if _map_btn != null and is_instance_valid(_map_btn):
		_map_btn.visible = is_vis


func _update_restore_pill_visibility() -> void:
	if _camera_restore_pill != null and is_instance_valid(_camera_restore_pill):
		_camera_restore_pill.visible = (_is_golfer_cam_minimized or _is_putting_cam_minimized) and not _hud_elements_suppressed


func _get_autoload(autoload_name: String) -> Node:
	if is_inside_tree() and has_node("/root/" + autoload_name):
		return get_node("/root/" + autoload_name)
	var loop = Engine.get_main_loop() as SceneTree
	if loop != null and loop.root != null:
		return loop.root.get_node_or_null(autoload_name)
	return null


func _get_current_club() -> String:
	if not _current_selected_club.is_empty():
		return _current_selected_club
	var gs = _get_autoload("GlobalSettings")
	if gs != null and "current_selected_club" in gs and not str(gs.current_selected_club).is_empty():
		return str(gs.current_selected_club)
	return _current_selected_club


func set_current_club(club_name: String) -> void:
	_on_club_selected(club_name)


func _is_putter_selected() -> bool:
	var club = _get_current_club().strip_edges().to_lower()
	return club == "pt" or club.contains("putt")


func _should_camera_feed_be_active() -> bool:
	if is_golfer_camera_enabled():
		return true
	if _is_putting_cam_enabled:
		return not _is_putting_cam_minimized or _is_putter_selected()
	return false


func _sync_camera_feed_consumption() -> void:
	var should_be_active = _should_camera_feed_be_active()
	if _use_phone_stream:
		if should_be_active:
			if not _is_requesting_frame and not _phone_cam_url.is_empty():
				_request_next_phone_frame()
	else:
		var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
		if should_be_active:
			if bridge != null and bridge.has_method("resume_desktop_camera"):
				bridge.resume_desktop_camera()
			CameraServer.set_monitoring_feeds(true)
			var feeds = CameraServer.feeds()
			if _current_camera_feed_index >= 0 and _current_camera_feed_index < feeds.size():
				var feed = feeds[_current_camera_feed_index]
				if feed != null:
					feed.feed_is_active = true
		else:
			if bridge != null and bridge.has_method("pause_desktop_camera"):
				bridge.pause_desktop_camera()
			if CameraServer.is_monitoring_feeds():
				var feeds = CameraServer.feeds()
				for feed in feeds:
					if feed != null:
						feed.feed_is_active = false
			CameraServer.set_monitoring_feeds(false)


func _on_club_selected(club_name: String) -> void:
	_current_selected_club = club_name
	if not _is_putting_cam_enabled:
		return
	if _is_putter_selected():
		if _is_putting_cam_minimized:
			restore_putting_camera()
		_sync_camera_feed_consumption()
	else:
		if not _is_putting_cam_minimized:
			minimize_putting_camera()
		_sync_camera_feed_consumption()


func is_camera_modal_open() -> bool:
	var cam_active = (_is_golfer_cam_enabled and not _is_golfer_cam_minimized) or (_is_putting_cam_enabled and not _is_putting_cam_minimized)
	return cam_active and _golfer_cam_panel != null and _golfer_cam_panel.visible


func is_golfer_camera_modal_open() -> bool:
	return is_camera_modal_open()


func is_putting_camera_modal_open() -> bool:
	return is_camera_modal_open() and _is_putting_cam_enabled


func is_golfer_camera_enabled() -> bool:
	return _is_golfer_cam_enabled


func is_golfer_camera_minimized() -> bool:
	return _is_golfer_cam_minimized


func is_golfer_camera_visible() -> bool:
	return _golfer_cam_panel.visible if _golfer_cam_panel != null else false


func is_putting_camera_enabled() -> bool:
	return _is_putting_cam_enabled


func is_putting_camera_minimized() -> bool:
	return _is_putting_cam_minimized


func is_putting_camera_visible() -> bool:
	return _is_putting_cam_enabled and not _is_putting_cam_minimized and _golfer_cam_panel != null and _golfer_cam_panel.visible


func minimize_camera() -> void:
	_close_camera_setup_dialog()
	if _is_putting_cam_enabled:
		minimize_putting_camera()
	elif _is_golfer_cam_enabled:
		minimize_golfer_camera()


func restore_camera() -> void:
	if _is_putting_cam_enabled:
		restore_putting_camera()
	elif _is_golfer_cam_enabled:
		restore_golfer_camera()


func minimize_golfer_camera() -> void:
	if not _is_golfer_cam_enabled:
		return
	_close_camera_setup_dialog()
	_is_golfer_cam_minimized = true
	if _golfer_cam_panel != null:
		_golfer_cam_panel.visible = false
	if _camera_restore_pill != null and is_instance_valid(_camera_restore_pill):
		_camera_restore_pill.text = "📹 Golfer Cam [REC] 🗖"
		_camera_restore_pill.tooltip_text = "Golfer Cam is recording in background. Click to expand preview."
	_update_restore_pill_visibility()
	_update_golfer_cam_button_state()
	_update_button_shifts()
	golfer_cam_modal_state_changed.emit(false)


func restore_golfer_camera() -> void:
	if not _is_golfer_cam_enabled:
		set_golfer_camera_visible(true)
		return
	_is_golfer_cam_minimized = false
	if _golfer_cam_panel != null:
		_golfer_cam_panel.visible = not _hud_elements_suppressed
	_update_restore_pill_visibility()
	_update_golfer_cam_button_state()
	_update_button_shifts()
	golfer_cam_modal_state_changed.emit(true)


func minimize_putting_camera() -> void:
	if not _is_putting_cam_enabled:
		return
	_close_camera_setup_dialog()
	_is_putting_cam_minimized = true
	if _golfer_cam_panel != null:
		_golfer_cam_panel.visible = false
	if _camera_restore_pill != null and is_instance_valid(_camera_restore_pill):
		_camera_restore_pill.text = "🎯 Putting Cam [REC] 🗖"
		_camera_restore_pill.tooltip_text = "Putting Cam is tracking in background. Click to expand preview."
	_update_restore_pill_visibility()
	_update_putting_cam_button_state()
	_update_button_shifts()
	golfer_cam_modal_state_changed.emit(false)


func restore_putting_camera() -> void:
	if not _is_putting_cam_enabled:
		set_putting_camera_visible(true)
		return
	_is_putting_cam_minimized = false
	if _golfer_cam_panel != null:
		_golfer_cam_panel.visible = not _hud_elements_suppressed
	_update_restore_pill_visibility()
	_update_putting_cam_button_state()
	_update_button_shifts()
	golfer_cam_modal_state_changed.emit(true)


func _update_golfer_cam_button_state() -> void:
	if _golfer_cam_btn != null and is_instance_valid(_golfer_cam_btn):
		if not _is_golfer_cam_enabled:
			_golfer_cam_btn.text = "📹 Golfer Cam: OFF"
			apply_material_button_style(_golfer_cam_btn, Color(0.2, 0.45, 0.45, 0.85))
		elif _is_golfer_cam_minimized:
			_golfer_cam_btn.text = "📹 Golfer Cam: MIN [REC]"
			apply_material_button_style(_golfer_cam_btn, Color(0.2, 0.55, 0.7, 0.85))
		else:
			_golfer_cam_btn.text = "📹 Golfer Cam: ON"
			apply_material_button_style(_golfer_cam_btn, Color(0.15, 0.6, 0.5, 0.85))


func _update_putting_cam_button_state() -> void:
	if _putting_cam_btn != null and is_instance_valid(_putting_cam_btn):
		if not _is_putting_cam_enabled:
			_putting_cam_btn.text = "🎯 Putting Cam: OFF"
			apply_material_button_style(_putting_cam_btn, Color(0.35, 0.35, 0.35, 0.85))
		elif _is_putting_cam_minimized:
			_putting_cam_btn.text = "🎯 Putting Cam: MIN [REC]"
			apply_material_button_style(_putting_cam_btn, Color(0.2, 0.55, 0.5, 0.85))
		else:
			_putting_cam_btn.text = "🎯 Putting Cam: ON"
			apply_material_button_style(_putting_cam_btn, Color(0.15, 0.6, 0.3, 0.85))


func _update_button_shifts() -> void:
	var modal_open = is_camera_modal_open()
	if _stats_btn != null and is_instance_valid(_stats_btn):
		if modal_open:
			_stats_btn.offset_left = 495
			_stats_btn.offset_right = 559
		else:
			_stats_btn.offset_left = 30
			_stats_btn.offset_right = 94
	if _shot_data_btn != null and is_instance_valid(_shot_data_btn):
		var left_edge := 567 if modal_open else 102
		_shot_data_btn.offset_left = left_edge
		_shot_data_btn.offset_right = left_edge + 64

	var grid = get_node_or_null("GridCanvas")
	if grid != null:
		if grid.has_method("set_golfer_camera_active"):
			grid.call("set_golfer_camera_active", modal_open)
		else:
			grid.position.x = 350.0 if modal_open else 0.0


func set_golfer_camera_visible(enabled: bool) -> void:
	if enabled:
		# MUTUAL EXCLUSIVITY: Disable Putting Camera if it's active
		if is_putting_camera_enabled():
			set_putting_camera_visible(false)

		_is_golfer_cam_enabled = true
		_is_golfer_cam_minimized = false
		_stats_were_visible_before_cam = is_stats_visible()
		if is_stats_visible():
			set_stats_visible(false)
	else:
		_is_golfer_cam_enabled = false
		_is_golfer_cam_minimized = false
		_close_camera_setup_dialog()
		if _stats_were_visible_before_cam and not is_stats_visible():
			set_stats_visible(true)

	if _golfer_cam_panel != null:
		_golfer_cam_panel.visible = enabled and not _hud_elements_suppressed
		_update_camera_feed(enabled)
	
	_update_restore_pill_visibility()
	_update_golfer_cam_button_state()
	_update_button_shifts()
	golfer_cam_enabled_changed.emit(_is_golfer_cam_enabled)
	golfer_cam_modal_state_changed.emit(is_camera_modal_open())
	_update_prev_shot_analysis_visibility()


func set_putting_camera_visible(enabled: bool) -> void:
	if enabled:
		# MUTUAL EXCLUSIVITY: Disable Golfer Camera if it's active
		if is_golfer_camera_enabled():
			set_golfer_camera_visible(false)

		_is_putting_cam_enabled = true
		_stats_were_visible_before_cam = is_stats_visible()
		if is_stats_visible():
			set_stats_visible(false)

		var is_putt = _is_putter_selected()
		_is_putting_cam_minimized = not is_putt
		_show_putting_camera_overlay(true)
		_update_camera_feed(true)

		if not is_putt:
			minimize_putting_camera()
		else:
			if _golfer_cam_panel != null:
				_golfer_cam_panel.visible = not _hud_elements_suppressed
			_update_restore_pill_visibility()
			_update_putting_cam_button_state()
			_update_button_shifts()
			golfer_cam_modal_state_changed.emit(is_camera_modal_open())
		_sync_camera_feed_consumption()
	else:
		_is_putting_cam_enabled = false
		_is_putting_cam_minimized = false
		_close_camera_setup_dialog()
		_show_putting_camera_overlay(false)
		if _stats_were_visible_before_cam and not is_stats_visible():
			set_stats_visible(true)

		# Only stop camera feed if golfer cam is also off
		if not is_golfer_camera_enabled():
			_update_camera_feed(false)
		_sync_camera_feed_consumption()

		_update_restore_pill_visibility()
		_update_putting_cam_button_state()
		_update_button_shifts()
		golfer_cam_modal_state_changed.emit(false)

	putting_cam_enabled_changed.emit(_is_putting_cam_enabled)
	if is_inside_tree() and has_node("/root/GlobalSettings"):
		GlobalSettings.range_settings.putting_camera_enabled.set_value(_is_putting_cam_enabled)
		GlobalSettings.save_settings()


func _show_putting_camera_overlay(enabled: bool) -> void:
	if enabled:
		if _golfer_cam_panel != null and not _is_putting_cam_minimized:
			_golfer_cam_panel.visible = not _hud_elements_suppressed

		var skel = _golfer_cam_panel.find_child("LiveGolferSkeletonOverlay", true, false) if _golfer_cam_panel != null else null
		if skel != null:
			skel.visible = false

		if _putting_overlay == null:
			var overlay_script = load("res://UI/PuttingCamera/putting_camera_overlay.gd")
			if overlay_script != null:
				_putting_overlay = overlay_script.new()
				_putting_overlay.name = "PuttingCameraOverlay"
				_putting_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_putting_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
				_putting_overlay.gui_input.connect(_on_overlay_gui_input)

		if _golfer_cam_panel != null:
			var feed_rect = _golfer_cam_panel.find_child("CameraFeedRect", true, false)
			if feed_rect != null:
				var parent = feed_rect.get_parent()
				if _putting_overlay.get_parent() != parent:
					if _putting_overlay.get_parent() != null:
						_putting_overlay.get_parent().remove_child(_putting_overlay)
					parent.add_child(_putting_overlay)

		if _putting_overlay != null:
			_putting_overlay.visible = true

		if _color_profile == null:
			var profile_script = load("res://UI/PuttingCamera/putting_color_profile.gd")
			if profile_script != null:
				_color_profile = profile_script.new()
				_color_profile.load_from_settings()

		if _putting_state_machine == null:
			var sm_script = load("res://UI/PuttingCamera/putting_camera_state_machine.gd")
			if sm_script != null:
				_putting_state_machine = sm_script.new()
				_putting_state_machine.name = "PuttingCameraStateMachine"
				add_child(_putting_state_machine)
				_putting_state_machine.putt_detected.connect(_on_putt_detected)
				if _putting_state_machine.has_signal("putt_rejected"):
					_putting_state_machine.putt_rejected.connect(func(reason, spd):
						print("[RangeUI] Putting shot rejected (%s): %.1f mph" % [reason, spd])
					)

		if _putting_state_machine != null:
			_putting_state_machine.overlay = _putting_overlay
			if _putting_state_machine.detector != null and _color_profile != null:
				_putting_state_machine.detector.color_profile = _color_profile
			_putting_state_machine.reset()
			_apply_putting_camera_fps()
			_sync_overlay_color_swatches()

		if _camera_color_pick_btn != null:
			_camera_color_pick_btn.visible = true

		if _putting_align_container != null:
			_putting_align_container.visible = true
			if _putting_overlay != null and _putting_align_slider != null:
				_putting_align_slider.set_value_no_signal(_putting_overlay.circle_center.x)
				if _putting_overlay.has_signal("circle_position_changed") and not _putting_overlay.circle_position_changed.is_connected(_on_putting_circle_pos_changed):
					_putting_overlay.circle_position_changed.connect(_on_putting_circle_pos_changed)
		if _panel_footer_label != null:
			_panel_footer_label.text = "Drag circle/line or use slider to adjust for camera stand"

		if _golfer_cam_panel != null:
			var title_label = _golfer_cam_panel.find_child("PanelTitleLabel", true, false)
			if title_label is Label:
				title_label.text = "🎯 PUTTING CAM"
			if _camera_minimize_btn != null:
				_camera_minimize_btn.tooltip_text = "Minimize Putting Cam (Keeps tracking in background)"
	else:
		_close_camera_setup_dialog()
		if _camera_color_pick_btn != null:
			_camera_color_pick_btn.visible = false
		_putting_picker_mode = PuttingPickerMode.NONE
		if _putting_overlay != null:
			_putting_overlay.picker_active = false

		if _putting_align_container != null:
			_putting_align_container.visible = false
		if _panel_footer_label != null:
			_panel_footer_label.text = "Position camera behind ball facing target line"

		if _putting_overlay != null:
			_putting_overlay.visible = false
		if _putting_state_machine != null:
			_putting_state_machine.reset()

		var skel = _golfer_cam_panel.find_child("LiveGolferSkeletonOverlay", true, false) if _golfer_cam_panel != null else null
		if skel != null:
			skel.visible = true

		if _golfer_cam_panel != null:
			var title_label = _golfer_cam_panel.find_child("PanelTitleLabel", true, false)
			if title_label is Label:
				title_label.text = "📹 GOLFER CAM"
			if _camera_minimize_btn != null:
				_camera_minimize_btn.tooltip_text = "Minimize Golfer Cam (Keeps recording in background)"
			if not is_golfer_camera_enabled():
				_golfer_cam_panel.visible = false


func _on_putting_circle_pos_changed(new_pos: Vector2) -> void:
	if _putting_align_slider != null:
		_putting_align_slider.set_value_no_signal(new_pos.x)


func _apply_putting_camera_fps() -> void:
	if _putting_state_machine == null:
		return

	var has_gs = is_inside_tree() and has_node("/root/GlobalSettings")
	var fps_mode: String = GlobalSettings.range_settings.putting_camera_fps_mode.value if has_gs else "Auto"
	var fps: float = 30.0

	match fps_mode:
		"Auto":
			fps = _detect_camera_fps()
		"30":
			fps = 30.0
		"60":
			fps = 60.0
		"120":
			fps = 120.0
		"Custom":
			fps = float(GlobalSettings.range_settings.putting_camera_fps.value) if has_gs else 30.0
		_:
			fps = 30.0

	_putting_state_machine.set_fps(fps)
	print("[PuttingCam] Active FPS set to: %.1f (%s mode)" % [fps, fps_mode])


func _detect_camera_fps() -> float:
	var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
	if pose_bridge != null and "FRAME_INTERVAL" in pose_bridge:
		var interval: float = float(pose_bridge.FRAME_INTERVAL)
		if interval > 0.001:
			return 1.0 / interval

	var feeds = CameraServer.feeds()
	if feeds.size() > 0:
		return 30.0

	return 30.0


func _on_putt_detected(speed_mph: float, hla_deg: float) -> void:
	var putt_data: Dictionary = {
		"Speed": speed_mph,
		"BallSpeed": speed_mph,
		"VLA": 0.0,
		"HLA": hla_deg,
		"TotalSpin": 0.0,
		"SpinAxis": 0.0,
		"BackSpin": 0.0,
		"SideSpin": 0.0,
		"Club": "Pt",
		"ShotType": "putt",
		"Source": "PuttingCamera",
	}
	print("[PuttingCam] Dispatching putt: %s" % str(putt_data))
	emit_signal("hit_shot", putt_data)


func on_next_shot_started() -> void:
	if _putting_state_machine != null and _putting_state_machine.current_state == PuttingCameraStateMachine.State.EXECUTION:
		_putting_state_machine._transition_to(PuttingCameraStateMachine.State.IDLE)


func is_shot_analysis_enabled() -> bool:
	if has_node("/root/GlobalSettings"):
		return GlobalSettings.range_settings.shot_analysis_enabled.value
	return false


func set_shot_analysis_enabled(enabled: bool) -> void:
	if has_node("/root/GlobalSettings"):
		GlobalSettings.range_settings.shot_analysis_enabled.value = enabled
	var btn = find_child("ShotAnalysisButton", true, false)
	if btn is Button:
		btn.text = "📊 Shot Analysis: ON" if enabled else "📊 Shot Analysis: OFF"
		apply_material_button_style(btn, Color(0.15, 0.55, 0.75, 0.85) if enabled else Color(0.25, 0.35, 0.45, 0.85))
	_update_prev_shot_analysis_visibility()



func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if (is_golfer_camera_enabled() or _is_putting_cam_enabled) and not _use_phone_stream:
			var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")
			var is_desk_active = bridge != null and bridge.has_method("is_desktop_camera_active") and bridge.is_desktop_camera_active()
			if not is_desk_active:
				_update_camera_feed(true)


func _on_desktop_cameras_updated(cams: Array) -> void:
	if _use_phone_stream:
		_stop_local_camera_stream()
		return
	if (is_golfer_camera_enabled() or _is_putting_cam_enabled) and not _use_phone_stream:
		if _camera_feed_rect != null and _camera_feed_rect.texture == null and cams.size() > 0:
			var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")
			if bridge != null and bridge.has_method("select_desktop_camera"):
				var sel_idx = clamp(_current_camera_feed_index, 0, cams.size() - 1)
				_current_camera_feed_index = sel_idx
				if _camera_feed_rect != null:
					_camera_feed_rect.material = null
				bridge.select_desktop_camera(sel_idx)
				_update_status_overlay("", false)


func _update_camera_rotate_button_text() -> void:
	if _camera_rotate_btn != null and is_instance_valid(_camera_rotate_btn):
		_camera_rotate_btn.text = "🔁 %d°" % _camera_rotation_deg
		_camera_rotate_btn.tooltip_text = "Rotate Camera Feed 90° (Current: %d°). Align feed with putting roll direction." % _camera_rotation_deg


func _on_rotate_camera_pressed() -> void:
	_camera_rotation_deg = (_camera_rotation_deg + 90) % 360
	_update_camera_rotate_button_text()
	if _camera_feed_rect != null and _camera_feed_rect.material is ShaderMaterial:
		_camera_feed_rect.material.set_shader_parameter("manual_rotation_rad", deg_to_rad(float(_camera_rotation_deg)))
	if _putting_state_machine != null:
		_putting_state_machine.reset()
	print("[RangeUI] Camera rotation set to: %d°" % _camera_rotation_deg)


func _apply_image_rotation(img: Image, rotation_deg: int) -> Image:
	if img == null:
		return null
	match rotation_deg:
		90:
			img.rotate_90(CLOCKWISE)
		180:
			img.rotate_180()
		270:
			img.rotate_90(COUNTERCLOCKWISE)
		_:
			pass
	return img


func _start_putting_local_mjpeg_stream() -> void:
	if _putting_mjpeg_reader == null:
		_putting_mjpeg_reader = PuttingMJPEGReaderClass.new()
		_putting_mjpeg_reader.name = "PuttingMJPEGReader"
		add_child(_putting_mjpeg_reader)
		_putting_mjpeg_reader.frame_received.connect(_on_putting_mjpeg_frame_received)
		_putting_mjpeg_reader.connection_status_changed.connect(func(connected: bool, _msg: String):
			if connected:
				_update_status_overlay("", false)
		)
	var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
	var stream_url = put_service.get_stream_url() if put_service != null else "http://127.0.0.1:49155/video"
	_putting_mjpeg_reader.start_stream(stream_url)


func _on_putting_mjpeg_frame_received(img: Image, timestamp_usec: int) -> void:
	if not _is_putting_cam_enabled or img == null:
		return
	var active_img: Image = img
	if _camera_rotation_deg != 0:
		active_img = img.duplicate()
		_apply_image_rotation(active_img, _camera_rotation_deg)
	_last_putting_feed_image = active_img
	if _camera_feed_rect != null:
		_camera_feed_rect.material = null
		_camera_feed_rect.texture = ImageTexture.create_from_image(active_img)
	_update_status_overlay("", false)
	if _putting_state_machine != null:
		_putting_state_machine.process_frame(active_img, timestamp_usec)


func _on_desktop_frame_received(_img: Image, tex: Texture2D, _landmarks: Dictionary) -> void:
	if not _should_camera_feed_be_active():
		return

	var active_img: Image = _img
	var active_tex: Texture2D = tex
	if _camera_rotation_deg != 0 and _img != null:
		active_img = _img.duplicate()
		_apply_image_rotation(active_img, _camera_rotation_deg)
		active_tex = ImageTexture.create_from_image(active_img)

	if is_golfer_camera_enabled() and not _use_phone_stream:
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
			_camera_feed_rect.texture = active_tex
		_update_status_overlay("", false)

	# On Android, PoseDetectionBridge routes device cameras directly
	var is_and: bool = OS.has_feature("android") or OS.get_name() == "Android"
	if _is_putting_cam_enabled and not _use_phone_stream and is_and:
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
			_camera_feed_rect.texture = active_tex
		_update_status_overlay("", false)
		if active_img != null:
			_last_putting_feed_image = active_img
		if _putting_state_machine != null and active_img != null:
			var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
			var ts_usec: int = bridge.last_capture_timestamp_usec if (bridge != null and "last_capture_timestamp_usec" in bridge and bridge.last_capture_timestamp_usec > 0) else Time.get_ticks_usec()
			_putting_state_machine.process_frame(active_img, ts_usec)


func _stop_local_camera_stream() -> void:
	var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
	if put_service != null and put_service.has_method("stop_camera"):
		put_service.stop_camera()
	if _putting_mjpeg_reader != null and _putting_mjpeg_reader.has_method("stop_stream"):
		_putting_mjpeg_reader.stop_stream()
	var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
	if pose_bridge != null:
		if pose_bridge.has_method("stop_desktop_camera"):
			pose_bridge.stop_desktop_camera()
		if pose_bridge.has_method("stop_android_camera"):
			pose_bridge.stop_android_camera()
	if _camera_feed_rect != null:
		_camera_feed_rect.material = null
	if CameraServer.is_monitoring_feeds():
		for feed in CameraServer.feeds():
			if feed != null:
				feed.feed_is_active = false
		CameraServer.set_monitoring_feeds(false)


func _stop_phone_camera_stream() -> void:
	_is_requesting_frame = false
	if _http_req != null and _http_req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_req.cancel_request()
	if _phone_cam_poll_timer != null:
		_phone_cam_poll_timer.stop()


func _connect_local_camera(sel_idx: int) -> void:
	_stop_phone_camera_stream()
	_use_phone_stream = false
	_current_camera_feed_index = sel_idx
	var is_android: bool = OS.has_feature("android") or OS.get_name() == "Android"

	if _is_putting_cam_enabled and not is_android:
		var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
		var target_idx = sel_idx
		if target_idx < 0:
			target_idx = 0
		if put_service != null and "desktop_cameras" in put_service and put_service.desktop_cameras.size() > 0:
			target_idx = clamp(target_idx, 0, put_service.desktop_cameras.size() - 1)
		_current_camera_feed_index = target_idx
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
		if put_service != null and put_service.has_method("select_camera"):
			put_service.select_camera(target_idx)
		_start_putting_local_mjpeg_stream()
		_update_status_overlay("", false)
		return

	var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
	if not CameraServer.is_monitoring_feeds():
		CameraServer.set_monitoring_feeds(true)

	var feeds = CameraServer.feeds()
	if feeds.size() > 0:
		_activate_camera_feed_index(clamp(sel_idx, 0, feeds.size() - 1))
	elif is_android or (pose_bridge != null and "desktop_cameras" in pose_bridge and pose_bridge.desktop_cameras.size() > 0):
		var target_idx = sel_idx
		if target_idx < 0:
			target_idx = 0
		if pose_bridge != null and "desktop_cameras" in pose_bridge and pose_bridge.desktop_cameras.size() > 0:
			target_idx = clamp(target_idx, 0, pose_bridge.desktop_cameras.size() - 1)
		_current_camera_feed_index = target_idx
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
		if pose_bridge != null and pose_bridge.has_method("select_desktop_camera"):
			pose_bridge.select_desktop_camera(target_idx)
		_update_status_overlay("", false)
	else:
		_activate_camera_feed_index(sel_idx)


func _update_camera_feed(active: bool) -> void:
	var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)

	if not active:
		_stop_local_camera_stream()
		_stop_phone_camera_stream()
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
			_camera_feed_rect.texture = null
		_update_status_overlay("GOLFER CAMERA FEED\n[ Click ⚙️ Setup to connect ]", true)
		return

	# If WiFi phone stream is selected, stop all local/device cameras immediately
	if _use_phone_stream:
		_stop_local_camera_stream()
		if not _phone_cam_url.is_empty():
			_start_phone_camera_stream(_phone_cam_url)
		else:
			if _camera_feed_rect != null:
				_camera_feed_rect.material = null
				_camera_feed_rect.texture = null
			_update_status_overlay("NO PHONE STREAM URL\n[ Click ⚙️ Connect Camera for Phone WiFi Stream ]", true)
		return

	# Stop any phone stream polling before starting local camera
	_stop_phone_camera_stream()

	# If putting camera is already actively streaming via local MJPEG, maintain it
	if _is_putting_cam_enabled and not _use_phone_stream and _putting_mjpeg_reader != null and _putting_mjpeg_reader.has_method("is_active") and _putting_mjpeg_reader.is_active():
		_update_status_overlay("", false)
		return

	# If desktop camera is already actively streaming, maintain it without restarting
	if not _is_putting_cam_enabled and pose_bridge != null and pose_bridge.has_method("is_desktop_camera_active") and pose_bridge.is_desktop_camera_active():
		_update_status_overlay("", false)
		return

	var is_android: bool = OS.has_feature("android") or OS.get_name() == "Android"

	# Request permission on mobile OS if needed
	if is_android or OS.has_feature("ios"):
		var permissions: Variant = OS.call("get_granted_permissions") if OS.has_method("get_granted_permissions") else []
		var has_cam_perm: bool = false
		if permissions is PackedStringArray or permissions is Array:
			has_cam_perm = "android.permission.CAMERA" in permissions
		if not has_cam_perm:
			if OS.has_method("request_permission"):
				OS.call("request_permission", "android.permission.CAMERA")
			elif OS.has_method("request_permissions"):
				OS.call("request_permissions")
			_update_status_overlay("CAMERA PERMISSION REQUIRED\n[ Please grant camera permission when prompted ]", true)
			if _camera_feed_rect != null:
				_camera_feed_rect.material = null
				_camera_feed_rect.texture = null
			# Re-check after user grants permission (multi-stage)
			var retry_timer1 = get_tree().create_timer(1.2)
			retry_timer1.timeout.connect(func():
				if is_golfer_camera_enabled() or _is_putting_cam_enabled:
					_update_camera_feed(true)
			)
			var retry_timer2 = get_tree().create_timer(3.0)
			retry_timer2.timeout.connect(func():
				if is_golfer_camera_enabled() or _is_putting_cam_enabled:
					var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
					if bridge == null or not bridge.has_method("is_desktop_camera_active") or not bridge.is_desktop_camera_active():
						_update_camera_feed(true)
			)
			return

	if not CameraServer.is_monitoring_feeds():
		CameraServer.set_monitoring_feeds(true)

	var feeds = CameraServer.feeds()
	var count = feeds.size()

	var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
	var desk_cams: Array = []
	if _is_putting_cam_enabled and not is_android:
		desk_cams = put_service.desktop_cameras if (put_service != null and "desktop_cameras" in put_service) else []
	elif pose_bridge != null and "desktop_cameras" in pose_bridge:
		desk_cams = pose_bridge.desktop_cameras

	if count > 0:
		var selected_index = _current_camera_feed_index
		if selected_index < 0 or selected_index >= count:
			selected_index = _find_default_camera_index(feeds)
			_current_camera_feed_index = selected_index
		_activate_camera_feed_index(selected_index)
	elif desk_cams.size() > 0 or is_android:
		var sel_idx = _current_camera_feed_index
		if sel_idx < 0:
			sel_idx = 0
		if desk_cams.size() > 0:
			sel_idx = clamp(sel_idx, 0, desk_cams.size() - 1)
		_current_camera_feed_index = sel_idx
		_activate_camera_feed_index(sel_idx)
	else:
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
			_camera_feed_rect.texture = null
		_update_status_overlay("SEARCHING FOR CAMERAS...\n[ Click ⚙️ Connect Camera for setup ]", true)
		if _is_putting_cam_enabled and not is_android and put_service != null and put_service.has_method("fetch_cameras"):
			put_service.fetch_cameras()
		elif pose_bridge != null and pose_bridge.has_method("fetch_desktop_cameras"):
			pose_bridge.fetch_desktop_cameras()
		# Schedule asynchronous re-scan
		if get_tree() != null:
			get_tree().create_timer(0.6).timeout.connect(func():
				if (is_golfer_camera_enabled() or _is_putting_cam_enabled) and not _use_phone_stream:
					if not CameraServer.is_monitoring_feeds():
						CameraServer.set_monitoring_feeds(true)
					var rescan_feeds = CameraServer.feeds()
					var rescan_desk: Array = []
					if _is_putting_cam_enabled and not is_android:
						rescan_desk = put_service.desktop_cameras if (put_service != null and "desktop_cameras" in put_service) else []
					elif pose_bridge != null and "desktop_cameras" in pose_bridge:
						rescan_desk = pose_bridge.desktop_cameras
					if rescan_feeds.size() > 0:
						var sel_idx = _find_default_camera_index(rescan_feeds) if _current_camera_feed_index < 0 or _current_camera_feed_index >= rescan_feeds.size() else _current_camera_feed_index
						_current_camera_feed_index = sel_idx
						_activate_camera_feed_index(sel_idx)
					elif rescan_desk.size() > 0 or is_android:
						var sel_idx = clamp(_current_camera_feed_index, 0, max(0, rescan_desk.size() - 1))
						_current_camera_feed_index = sel_idx
						_activate_camera_feed_index(sel_idx)
					elif _phone_cam_url.is_empty():
						_update_status_overlay("NO LOCAL CAMERA DETECTED\n[ Click ⚙️ Connect Camera for Phone WiFi Stream ]", true)
			)


func _update_status_overlay(msg: String, is_visible: bool) -> void:
	if _golfer_cam_panel == null:
		return
	var status_vbox = _golfer_cam_panel.find_child("OverlayStatusVBox", true, false)
	if status_vbox != null:
		status_vbox.visible = is_visible
	var label = _golfer_cam_panel.find_child("FeedStatusLabel", true, false)
	if label is Label and not msg.is_empty():
		label.text = msg


func _find_default_camera_index(feeds: Array = []) -> int:
	if feeds.is_empty():
		feeds = CameraServer.feeds()
	for i in range(feeds.size()):
		var feed = feeds[i]
		if feed != null and feed.get_position() == CameraFeed.FEED_BACK:
			return i
	return 0


func _activate_camera_feed_index(index: int) -> void:
	var feeds = CameraServer.feeds()
	var is_android: bool = OS.has_feature("android") or OS.get_name() == "Android"
	if index < 0 or index >= feeds.size():
		var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
		var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")
		
		if _is_putting_cam_enabled and not is_android and put_service != null:
			var target_idx = max(index, 0)
			if "desktop_cameras" in put_service and put_service.desktop_cameras.size() > 0:
				target_idx = clamp(index, 0, put_service.desktop_cameras.size() - 1)
			_current_camera_feed_index = target_idx
			if _camera_feed_rect != null:
				_camera_feed_rect.material = null
			if put_service.has_method("select_camera"):
				put_service.select_camera(target_idx)
			_start_putting_local_mjpeg_stream()
			_update_status_overlay("", false)
			return
		
		if is_android or (pose_bridge != null and "desktop_cameras" in pose_bridge and index >= 0 and index < pose_bridge.desktop_cameras.size()):
			var target_idx = max(index, 0)
			if pose_bridge != null and "desktop_cameras" in pose_bridge and pose_bridge.desktop_cameras.size() > 0:
				target_idx = clamp(target_idx, 0, pose_bridge.desktop_cameras.size() - 1)
			_current_camera_feed_index = target_idx
			if _camera_feed_rect != null:
				_camera_feed_rect.material = null
			if pose_bridge != null and pose_bridge.has_method("select_desktop_camera"):
				pose_bridge.select_desktop_camera(target_idx)
			_update_status_overlay("", false)
			return
		
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
			_camera_feed_rect.texture = null
		_update_status_overlay("NO LOCAL WEBCAM DETECTED\n[ Click ⚙️ Connect Camera for Phone WiFi Stream ]", true)
		return
	
	var feed = feeds[index]
	if feed != null:
		feed.feed_is_active = true
		var data_type = feed.get_datatype()
		if data_type == CameraFeed.FEED_YCBCR or data_type == CameraFeed.FEED_YCBCR_SEP:
			var y_tex = CameraTexture.new()
			y_tex.camera_feed_id = feed.get_id()
			y_tex.which_feed = CameraServer.FEED_Y_IMAGE
			y_tex.camera_is_active = true

			var cbcr_tex = CameraTexture.new()
			cbcr_tex.camera_feed_id = feed.get_id()
			cbcr_tex.which_feed = CameraServer.FEED_CBCR_IMAGE
			cbcr_tex.camera_is_active = true

			var shader = Shader.new()
			shader.code = """
shader_type canvas_item;

uniform sampler2D y_tex : hint_default_black;
uniform sampler2D cbcr_tex : hint_default_black;
uniform mat3 feed_transform;
uniform float manual_rotation_rad : default_value(0.0);

void fragment() {
	vec2 center = vec2(0.5);
	vec2 uv_rot = UV - center;
	float c = cos(manual_rotation_rad);
	float s = sin(manual_rotation_rad);
	uv_rot = vec2(c * uv_rot.x - s * uv_rot.y, s * uv_rot.x + c * uv_rot.y) + center;

	vec2 uv = (feed_transform * vec3(uv_rot, 1.0)).xy;
	float y = texture(y_tex, uv).r;
	vec2 cbcr = texture(cbcr_tex, uv).rg;

	float cb = cbcr.r - 0.5;
	float cr = cbcr.g - 0.5;

	float r = y + 1.402 * cr;
	float g = y - 0.344136 * cb - 0.714136 * cr;
	float b = y + 1.772 * cb;

	COLOR = vec4(clamp(vec3(r, g, b), 0.0, 1.0), 1.0);
}
"""
			var mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("y_tex", y_tex)
			mat.set_shader_parameter("cbcr_tex", cbcr_tex)
			mat.set_shader_parameter("feed_transform", feed.get_transform())
			mat.set_shader_parameter("manual_rotation_rad", deg_to_rad(float(_camera_rotation_deg)))

			if _camera_feed_rect != null:
				_camera_feed_rect.material = mat
				_camera_feed_rect.texture = y_tex
		else:
			if _camera_feed_rect != null:
				_camera_feed_rect.material = null
				var cam_tex = CameraTexture.new()
				cam_tex.camera_feed_id = feed.get_id()
				cam_tex.which_feed = CameraServer.FEED_RGBA_IMAGE
				cam_tex.camera_is_active = true
				_camera_feed_rect.texture = cam_tex
		
		_update_status_overlay("", false)


func _on_flip_camera_pressed() -> void:
	if _use_phone_stream:
		_stop_phone_camera_stream()
		_use_phone_stream = false
	
	var is_android: bool = OS.has_feature("android") or OS.get_name() == "Android"
	var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")
	var desk_cams: Array = pose_bridge.desktop_cameras if (pose_bridge != null and "desktop_cameras" in pose_bridge) else []
	var feeds = CameraServer.feeds()
	var total_count = max(feeds.size(), desk_cams.size())
	if is_android and total_count < 2:
		total_count = 2

	if total_count > 1:
		_current_camera_feed_index = (_current_camera_feed_index + 1) % total_count
		_connect_local_camera(_current_camera_feed_index)
	elif total_count == 1:
		_connect_local_camera(0)
	else:
		_open_camera_setup_dialog(_is_putting_cam_enabled)


func open_camera_setup(is_putting: bool = false) -> void:
	_open_camera_setup_dialog(is_putting)


func _sync_overlay_color_swatches() -> void:
	if _putting_overlay == null or _color_profile == null:
		return

	_putting_overlay.ball_color_configured = _color_profile.ball_configured
	if _color_profile.ball_configured:
		_putting_overlay.ball_color_swatch = Color.from_hsv(_color_profile.ball_hsv.x / 360.0, _color_profile.ball_hsv.y, _color_profile.ball_hsv.z)

	_putting_overlay.bg_color_configured = _color_profile.bg_configured
	if _color_profile.bg_configured:
		_putting_overlay.bg_color_swatch = Color.from_hsv(_color_profile.bg_hsv.x / 360.0, _color_profile.bg_hsv.y, _color_profile.bg_hsv.z)


func _update_color_profile() -> void:
	if _color_profile != null:
		_color_profile.load_from_settings()
		if _putting_state_machine != null and _putting_state_machine.detector != null:
			_putting_state_machine.detector.color_profile = _color_profile
			_putting_state_machine.reset()
	_sync_overlay_color_swatches()


func _open_color_picker_menu() -> void:
	if not is_putting_camera_enabled():
		set_putting_camera_visible(true)
	elif is_putting_camera_minimized():
		restore_putting_camera()

	var existing = $OverlayLayer.get_node_or_null("ColorPickerMenu")
	if existing != null and is_instance_valid(existing):
		if not existing.is_queued_for_deletion():
			$OverlayLayer.remove_child(existing)
			existing.queue_free()
		return

	var menu = PopupMenu.new()
	menu.name = "ColorPickerMenu"
	menu.add_item("🏐 Pick Ball Color (Click Ball on Feed)", 0)
	menu.add_item("🟩 Pick Mat/Background Color (Click Mat)", 1)
	menu.add_separator()
	menu.add_item("🔄 Reset to Auto-Detect (Default)", 2)
	menu.id_pressed.connect(func(id: int):
		match id:
			0:
				_putting_picker_mode = PuttingPickerMode.PICK_BALL
				if _putting_overlay != null:
					_putting_overlay.picker_active = true
				_show_picker_instructions("👉 CLICK ON THE BALL in the video feed below")
			1:
				_putting_picker_mode = PuttingPickerMode.PICK_BACKGROUND
				if _putting_overlay != null:
					_putting_overlay.picker_active = true
				_show_picker_instructions("👉 CLICK ON THE MAT/BACKGROUND in the video feed below")
			2:
				if _color_profile != null:
					_color_profile.ball_configured = false
					_color_profile.bg_configured = false
					_color_profile.save_to_settings()
				_update_color_profile()
				_show_picker_instructions("Reset to auto-detect ball mode")
		menu.queue_free()
	)
	$OverlayLayer.add_child(menu)
	ThemeManager.style_popup_menu(menu, 18 if MobilePerformance.is_mobile() else 15)
	menu.popup_centered()


func _show_picker_instructions(msg: String) -> void:
	_update_status_overlay(msg, true)
	get_tree().create_timer(3.5).timeout.connect(func():
		if _putting_picker_mode == PuttingPickerMode.NONE:
			_update_status_overlay("", false)
	)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if _putting_picker_mode != PuttingPickerMode.NONE:
		_on_feed_gui_input(event)


func _on_feed_gui_input(event: InputEvent) -> void:
	if _putting_picker_mode == PuttingPickerMode.NONE:
		return

	if event is InputEventMouseMotion and _putting_overlay != null:
		_putting_overlay.picker_cursor_pos = event.position
		return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var img_to_sample = _last_putting_feed_image
	if img_to_sample == null and _camera_feed_rect != null and _camera_feed_rect.texture != null:
		img_to_sample = _camera_feed_rect.texture.get_image()

	if img_to_sample == null or _camera_feed_rect == null:
		_putting_picker_mode = PuttingPickerMode.NONE
		if _putting_overlay != null:
			_putting_overlay.picker_active = false
		return

	var feed_sz = _camera_feed_rect.size
	var img_w = img_to_sample.get_width()
	var img_h = img_to_sample.get_height()
	if feed_sz.x <= 1.0 or feed_sz.y <= 1.0 or img_w < 2 or img_h < 2:
		return

	# Account for STRETCH_KEEP_ASPECT_COVERED
	var scale_x = float(img_w) / feed_sz.x
	var scale_y = float(img_h) / feed_sz.y
	var scale_factor = minf(scale_x, scale_y)

	var visible_w = feed_sz.x * scale_factor
	var visible_h = feed_sz.y * scale_factor
	var offset_x = (float(img_w) - visible_w) * 0.5
	var offset_y = (float(img_h) - visible_h) * 0.5

	var click_pos = event.position
	var img_x = int(offset_x + click_pos.x * scale_factor)
	var img_y = int(offset_y + click_pos.y * scale_factor)

	img_x = clampi(img_x, 0, img_w - 1)
	img_y = clampi(img_y, 0, img_h - 1)

	# Sample 7x7 patch around click point
	var h_list: Array[float] = []
	var s_list: Array[float] = []
	var v_list: Array[float] = []

	var patch_r: int = 3
	for py in range(maxi(0, img_y - patch_r), mini(img_h, img_y + patch_r + 1)):
		for px in range(maxi(0, img_x - patch_r), mini(img_w, img_x + patch_r + 1)):
			var c: Color = img_to_sample.get_pixel(px, py)
			var hsv: Vector3 = PuttingBallDetector._rgb_to_hsv(c)
			h_list.append(hsv.x)
			s_list.append(hsv.y)
			v_list.append(hsv.z)

	if h_list.size() > 0 and _color_profile != null:
		h_list.sort()
		s_list.sort()
		v_list.sort()
		var mid: int = h_list.size() / 2
		var sampled_hsv = Vector3(h_list[mid], s_list[mid], v_list[mid])

		match _putting_picker_mode:
			PuttingPickerMode.PICK_BALL:
				_color_profile.ball_hsv = sampled_hsv
				_color_profile.ball_configured = true
				_show_picker_instructions("✅ Ball Color Set (H: %.0f°, S: %.2f, V: %.2f)" % [sampled_hsv.x, sampled_hsv.y, sampled_hsv.z])
			PuttingPickerMode.PICK_BACKGROUND:
				_color_profile.bg_hsv = sampled_hsv
				_color_profile.bg_configured = true
				_show_picker_instructions("✅ Mat Color Set (H: %.0f°, S: %.2f, V: %.2f)" % [sampled_hsv.x, sampled_hsv.y, sampled_hsv.z])

		_color_profile.save_to_settings()
		_update_color_profile()

	_putting_picker_mode = PuttingPickerMode.NONE
	if _putting_overlay != null:
		_putting_overlay.picker_active = false


func _get_active_camera_setup_dialog() -> Control:
	if has_node("OverlayLayer"):
		for child in $OverlayLayer.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				if child.name == "CameraSetupDialog" or child.name.begins_with("CameraSetupDialog") or child.is_in_group("camera_setup_dialog"):
					return child as Control
	var tree = get_tree() if is_inside_tree() else null
	if tree != null:
		for node in tree.get_nodes_in_group("camera_setup_dialog"):
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				return node as Control
	return null


func _close_camera_setup_dialog(dialog: Control = null) -> void:
	if dialog != null and is_instance_valid(dialog) and not dialog.is_queued_for_deletion():
		if dialog.get_parent() != null:
			dialog.get_parent().remove_child(dialog)
		dialog.queue_free()
	if has_node("OverlayLayer"):
		for child in $OverlayLayer.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				if child.name == "CameraSetupDialog" or child.name.begins_with("CameraSetupDialog") or child.is_in_group("camera_setup_dialog"):
					$OverlayLayer.remove_child(child)
					child.queue_free()
	var tree = get_tree() if is_inside_tree() else null
	if tree != null:
		for node in tree.get_nodes_in_group("camera_setup_dialog"):
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				if node.get_parent() != null:
					node.get_parent().remove_child(node)
				node.queue_free()


func _toggle_camera_setup_dialog(for_putting: Variant = null) -> void:
	var is_putting: bool = _is_putting_cam_enabled if for_putting == null else bool(for_putting)
	var existing = _get_active_camera_setup_dialog()
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		var existing_mode = existing.get_meta("is_putting", null)
		if existing_mode == null or existing_mode == is_putting:
			_close_camera_setup_dialog(existing)
			return
		_close_camera_setup_dialog(existing)
	_open_camera_setup_dialog(is_putting)


func _open_camera_setup_dialog(for_putting: Variant = null) -> void:
	var is_putting: bool = _is_putting_cam_enabled if for_putting == null else bool(for_putting)
	var existing = _get_active_camera_setup_dialog()
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		var existing_mode = existing.get_meta("is_putting", null)
		if existing_mode == null or existing_mode == is_putting:
			existing.visible = true
			if existing.has_method("move_to_front"):
				existing.move_to_front()
			return
		_close_camera_setup_dialog(existing)

	_close_camera_setup_dialog()

	CameraServer.set_monitoring_feeds(true)
	var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")
	if pose_bridge != null and pose_bridge.has_method("fetch_desktop_cameras"):
		pose_bridge.fetch_desktop_cameras()

	var is_mob: bool = MobilePerformance.is_mobile()

	var popup = PanelContainer.new()
	popup.name = "CameraSetupDialog"
	popup.add_to_group("camera_setup_dialog")
	popup.set_meta("is_putting", is_putting)
	popup.tree_exited.connect(func():
		if _use_phone_stream:
			_stop_local_camera_stream()
	)
	popup.z_index = 100

	var vp_size = get_viewport().get_visible_rect().size if is_inside_tree() and get_viewport() != null else Vector2(1728, 972)
	var max_w: float = minf(540.0, vp_size.x * 0.95)
	var default_h: float = 680.0 if is_putting else 540.0
	var dialog_h: float = minf(default_h, vp_size.y * 0.88)
	popup.custom_minimum_size = Vector2(max_w, dialog_h)
	popup.size = Vector2(max_w, dialog_h)
	popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -max_w * 0.5
	popup.offset_top = -dialog_h * 0.5
	popup.offset_right = max_w * 0.5
	popup.offset_bottom = dialog_h * 0.5

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.96)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.6, 0.8, 0.9)
	style.content_margin_left = 20
	style.content_margin_top = 20
	style.content_margin_right = 20
	style.content_margin_bottom = 20
	popup.add_theme_stylebox_override("panel", style)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header_hbox = HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header_spacer_left = Control.new()
	header_spacer_left.custom_minimum_size = Vector2(36, 0)
	header_hbox.add_child(header_spacer_left)

	var title = Label.new()
	title.text = "🎯 Putting Camera Setup" if is_putting else "📷 Golfer Camera Setup"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	header_hbox.add_child(title)

	var header_close_btn = Button.new()
	header_close_btn.name = "HeaderCloseButton"
	header_close_btn.text = "✕"
	header_close_btn.tooltip_text = "Close Setup"
	header_close_btn.custom_minimum_size = Vector2(36, 36)
	apply_material_button_style(header_close_btn, Color(0.4, 0.4, 0.4, 0.8))
	header_close_btn.pressed.connect(func(): _close_camera_setup_dialog(popup))
	header_hbox.add_child(header_close_btn)

	outer_vbox.add_child(header_hbox)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ThemeManager.apply_scroll_container_style(scroll, 24)
	outer_vbox.add_child(scroll)

	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll_pad_right = 64 if is_mob else 36
	scroll_margin.add_theme_constant_override("margin_right", scroll_pad_right)
	scroll_margin.add_theme_constant_override("margin_left", 6)
	scroll_margin.add_theme_constant_override("margin_top", 4)
	scroll_margin.add_theme_constant_override("margin_bottom", 6)
	scroll.add_child(scroll_margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll_margin.add_child(vbox)

	# Section 1: System / Built-in Webcams
	var webcams_label = Label.new()
	webcams_label.text = "1. Local / Built-in Webcams (Scanning...):"
	webcams_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(webcams_label)

	var cam_option = OptionButton.new()
	cam_option.name = "CameraFeedOptionButton"
	cam_option.custom_minimum_size = Vector2(0, 36)
	cam_option.add_item("Scanning for webcams...", 0)
	cam_option.disabled = true
	vbox.add_child(cam_option)

	var is_android: bool = OS.has_feature("android") or OS.get_name() == "Android"
	var prev_detected_count: int = -1

	var populate_feeds = func():
		if not is_instance_valid(popup) or not is_instance_valid(webcams_label) or not is_instance_valid(cam_option):
			return
		if not CameraServer.is_monitoring_feeds():
			CameraServer.set_monitoring_feeds(true)
		var feeds = CameraServer.feeds()
		var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
		var desk_cams: Array = []
		if is_putting and not is_android:
			desk_cams = put_service.desktop_cameras if (put_service != null and "desktop_cameras" in put_service) else []
		elif pose_bridge != null and "desktop_cameras" in pose_bridge:
			desk_cams = pose_bridge.desktop_cameras
		var total_count = max(feeds.size(), desk_cams.size())
		if is_android and total_count < 2 and desk_cams.is_empty() and feeds.is_empty():
			total_count = 2
		
		# Prevent wiping and rebuilding OptionButton if count hasn't changed
		if total_count == prev_detected_count and cam_option.item_count > 0:
			return
		prev_detected_count = total_count

		webcams_label.text = "1. Local / Built-in Webcams (%d detected):" % total_count
		cam_option.clear()
		
		if feeds.size() > 0:
			cam_option.disabled = false
			for i in range(feeds.size()):
				var feed = feeds[i]
				var feed_name = "Camera %d" % i
				if feed != null:
					var pos_name = ""
					match feed.get_position():
						CameraFeed.FEED_BACK: pos_name = " (Back)"
						CameraFeed.FEED_FRONT: pos_name = " (Front)"
						_: pos_name = ""
					if not feed.get_name().is_empty():
						feed_name = feed.get_name() + pos_name
					else:
						feed_name = "Camera %d%s" % [i, pos_name]
				cam_option.add_item(feed_name, i)
			cam_option.select(clamp(_current_camera_feed_index, 0, feeds.size() - 1))
		elif desk_cams.size() > 0:
			cam_option.disabled = false
			for i in range(desk_cams.size()):
				var cam_info = desk_cams[i]
				var c_name: String = cam_info.get("name", "System Camera %d" % i)
				cam_option.add_item(c_name, i)
			cam_option.select(clamp(_current_camera_feed_index, 0, desk_cams.size() - 1))
		elif is_android:
			cam_option.disabled = false
			cam_option.add_item("Camera 0 (Back Camera)", 0)
			cam_option.add_item("Camera 1 (Front Camera)", 1)
			for i in range(2, total_count):
				cam_option.add_item("Camera %d (Device)" % i, i)
			cam_option.select(clamp(_current_camera_feed_index, 0, cam_option.item_count - 1))
		else:
			var err_hint: String = ""
			if pose_bridge != null and "last_error_message" in pose_bridge and not str(pose_bridge.last_error_message).is_empty():
				err_hint = " — " + str(pose_bridge.last_error_message)
			cam_option.add_item("No local webcams detected" + err_hint, 0)
			cam_option.disabled = true

	# Populate immediately and schedule polling scans
	populate_feeds.call()

	# Connect item_selected so clicking a camera in the dropdown switches to it immediately!
	cam_option.item_selected.connect(func(idx: int):
		_current_camera_feed_index = idx
		_connect_local_camera(idx)
	)

	var on_cameras_updated = func(_cams):
		if is_instance_valid(popup) and is_instance_valid(webcams_label):
			populate_feeds.call()

	if is_putting and not is_android:
		var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
		if put_service != null and put_service.has_signal("cameras_updated"):
			put_service.cameras_updated.connect(on_cameras_updated)
			popup.tree_exited.connect(func():
				if is_instance_valid(put_service) and put_service.is_connected("cameras_updated", on_cameras_updated):
					put_service.cameras_updated.disconnect(on_cameras_updated)
			)
	elif pose_bridge != null and pose_bridge.has_signal("desktop_cameras_updated"):
		pose_bridge.desktop_cameras_updated.connect(on_cameras_updated)
		popup.tree_exited.connect(func():
			if is_instance_valid(pose_bridge) and pose_bridge.is_connected("desktop_cameras_updated", on_cameras_updated):
				pose_bridge.desktop_cameras_updated.disconnect(on_cameras_updated)
		)

	var scan_timer = Timer.new()
	scan_timer.name = "WebcamScanTimer"
	scan_timer.wait_time = 2.0
	scan_timer.autostart = true
	popup.add_child(scan_timer)
	scan_timer.timeout.connect(func():
		if is_instance_valid(popup) and is_instance_valid(webcams_label):
			populate_feeds.call()
	)

	var cam_btn_hbox = HBoxContainer.new()
	cam_btn_hbox.add_theme_constant_override("separation", 8)

	var connect_local_btn = Button.new()
	connect_local_btn.text = "📹 Connect Selected Local Camera"
	connect_local_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_local_btn.custom_minimum_size = Vector2(0, 36)
	apply_material_button_style(connect_local_btn, Color(0.24, 0.46, 0.72, 0.9))
	connect_local_btn.pressed.connect(func():
		var sel_idx = cam_option.get_selected_id() if is_instance_valid(cam_option) else _current_camera_feed_index
		if sel_idx < 0:
			sel_idx = 0
		popup.queue_free()
		_connect_local_camera(sel_idx)
	)
	cam_btn_hbox.add_child(connect_local_btn)

	var rescan_btn = Button.new()
	rescan_btn.text = "🔄 Rescan"
	rescan_btn.custom_minimum_size = Vector2(80, 36)
	apply_material_button_style(rescan_btn, Color(0.3, 0.35, 0.45, 0.9))
	rescan_btn.pressed.connect(func():
		if not is_instance_valid(popup) or not is_instance_valid(webcams_label):
			return
		CameraServer.set_monitoring_feeds(true)
		if is_putting and not is_android:
			var put_service = Engine.get_singleton("PuttingCameraService") if Engine.has_singleton("PuttingCameraService") else (get_node_or_null("/root/PuttingCameraService") if is_inside_tree() else null)
			if put_service != null and put_service.has_method("fetch_cameras"):
				put_service.fetch_cameras()
		elif pose_bridge != null and pose_bridge.has_method("fetch_desktop_cameras"):
			pose_bridge.fetch_desktop_cameras()
		populate_feeds.call()
	)
	cam_btn_hbox.add_child(rescan_btn)
	vbox.add_child(cam_btn_hbox)

	var msg_label = Label.new()
	msg_label.name = "WebcamStatusMsg"
	msg_label.text = ""
	msg_label.add_theme_font_size_override("font_size", 11)
	msg_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	vbox.add_child(msg_label)

	# Section 2: Wireless Phone IP Stream
	var phone_label = Label.new()
	phone_label.text = "2. Phone Camera via WiFi / IP Stream (DroidCam / IP Webcam):"
	phone_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(phone_label)

	var ip_input = LineEdit.new()
	ip_input.name = "PhoneCameraIpInput"
	ip_input.placeholder_text = "e.g. 192.168.1.100:8080 or 192.168.1.100:4747"
	ip_input.text = _phone_cam_url
	ip_input.custom_minimum_size = Vector2(0, 48)
	ip_input.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_input_style(ip_input)
	ip_input.gui_input.connect(func(ev: InputEvent):
		if has_node("/root/VirtualKeyboardManager"):
			var vkm = get_node("/root/VirtualKeyboardManager")
			if vkm.is_controller_mode_active():
				if (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_A) or ev.is_action_pressed("ui_accept"):
					vkm.open_for(ip_input, true)
					get_viewport().set_input_as_handled()
	)
	var connect_phone_btn = Button.new()

	ip_input.text_submitted.connect(func(_t):
		if is_instance_valid(connect_phone_btn):
			connect_phone_btn.grab_focus()
	)
	vbox.add_child(ip_input)

	connect_phone_btn.text = "📡 Connect Phone Stream"
	connect_phone_btn.custom_minimum_size = Vector2(0, 36)
	apply_material_button_style(connect_phone_btn, Color(0.2, 0.6, 0.4, 0.9))
	connect_phone_btn.pressed.connect(func():
		var url_to_connect = ip_input.text if is_instance_valid(ip_input) else _phone_cam_url
		popup.queue_free()
		_stop_local_camera_stream()
		_use_phone_stream = true
		_start_phone_camera_stream(url_to_connect)
	)
	vbox.add_child(connect_phone_btn)

	if not is_putting:
		# On Android, show local MediaPipe AI status badge if native plugin is detected
		if Engine.has_singleton("MediaPipePosePlugin"):
			var ai_status_label = Label.new()
			ai_status_label.text = "⚡ On-Device MediaPipe AI Active (100% Mobile GPU Accelerated)"
			ai_status_label.add_theme_font_size_override("font_size", 12)
			ai_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
			ai_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(ai_status_label)

		# Section 3: Camera Orientation Rotation
		var rot_sep = HSeparator.new()
		rot_sep.add_theme_constant_override("separation", 8)
		vbox.add_child(rot_sep)

		var rot_label = Label.new()
		rot_label.text = "3. Camera Orientation Rotation:"
		rot_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(rot_label)

		var rot_hbox = HBoxContainer.new()
		rot_hbox.add_theme_constant_override("separation", 8)
		for deg in [0, 90, 180, 270]:
			var r_btn = Button.new()
			r_btn.text = "%d°" % deg
			r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_btn.custom_minimum_size = Vector2(0, 34)
			apply_material_button_style(r_btn, Color(0.22, 0.45, 0.55, 0.9) if _camera_rotation_deg == deg else Color(0.2, 0.25, 0.32, 0.8))
			r_btn.pressed.connect(func(d=deg):
				_camera_rotation_deg = d
				_update_camera_rotate_button_text()
				popup.queue_free()
			)
			rot_hbox.add_child(r_btn)
		vbox.add_child(rot_hbox)
	else:
		# Section 3: Putting Camera Framerate
		var fps_sep = HSeparator.new()
		fps_sep.add_theme_constant_override("separation", 8)
		vbox.add_child(fps_sep)

		var fps_label = Label.new()
		fps_label.text = "3. Putting Camera Framerate:"
		fps_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(fps_label)

		var fps_hbox = HBoxContainer.new()
		fps_hbox.add_theme_constant_override("separation", 8)

		var fps_option = OptionButton.new()
		fps_option.name = "FPSOptionButton"
		fps_option.custom_minimum_size = Vector2(140, 36)
		fps_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fps_option.add_item("Auto-Detect", 0)
		fps_option.add_item("30 FPS", 1)
		fps_option.add_item("60 FPS", 2)
		fps_option.add_item("120 FPS", 3)
		fps_option.add_item("Custom", 4)

		var current_mode: String = GlobalSettings.range_settings.putting_camera_fps_mode.value if has_node("/root/GlobalSettings") else "Auto"
		match current_mode:
			"Auto": fps_option.select(0)
			"30": fps_option.select(1)
			"60": fps_option.select(2)
			"120": fps_option.select(3)
			"Custom": fps_option.select(4)

		var custom_fps_spin = SpinBox.new()
		custom_fps_spin.name = "CustomFPSSpinBox"
		custom_fps_spin.min_value = 15
		custom_fps_spin.max_value = 240
		custom_fps_spin.step = 1
		custom_fps_spin.value = float(GlobalSettings.range_settings.putting_camera_fps.value) if has_node("/root/GlobalSettings") else 30
		custom_fps_spin.custom_minimum_size = Vector2(80, 36)
		custom_fps_spin.visible = (current_mode == "Custom")
		custom_fps_spin.suffix = " Hz"

		fps_option.item_selected.connect(func(idx: int):
			var modes = ["Auto", "30", "60", "120", "Custom"]
			var mode = modes[idx] if idx < modes.size() else "Auto"
			if has_node("/root/GlobalSettings"):
				GlobalSettings.range_settings.putting_camera_fps_mode.set_value(mode)
				GlobalSettings.save_settings()
			custom_fps_spin.visible = (mode == "Custom")
			_apply_putting_camera_fps()
		)

		custom_fps_spin.value_changed.connect(func(val: float):
			if has_node("/root/GlobalSettings"):
				GlobalSettings.range_settings.putting_camera_fps.set_value(int(val))
				GlobalSettings.save_settings()
			_apply_putting_camera_fps()
		)

		fps_hbox.add_child(fps_option)
		fps_hbox.add_child(custom_fps_spin)
		vbox.add_child(fps_hbox)

		var fps_note = Label.new()
		fps_note.text = "⚠️ Wi-Fi cams may drop frames. Lock FPS manually for consistent putt speed readings."
		fps_note.add_theme_font_size_override("font_size", 11)
		fps_note.add_theme_color_override("font_color", Color(0.8, 0.65, 0.3))
		fps_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(fps_note)

		# Section 4: Camera Orientation Rotation
		var rot_sep = HSeparator.new()
		rot_sep.add_theme_constant_override("separation", 8)
		vbox.add_child(rot_sep)

		var rot_label = Label.new()
		rot_label.text = "4. Camera Orientation Rotation:"
		rot_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(rot_label)

		var rot_hbox = HBoxContainer.new()
		rot_hbox.add_theme_constant_override("separation", 8)
		for deg in [0, 90, 180, 270]:
			var r_btn = Button.new()
			r_btn.text = "%d°" % deg
			r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_btn.custom_minimum_size = Vector2(0, 34)
			apply_material_button_style(r_btn, Color(0.22, 0.45, 0.55, 0.9) if _camera_rotation_deg == deg else Color(0.2, 0.25, 0.32, 0.8))
			r_btn.pressed.connect(func(d=deg):
				_camera_rotation_deg = d
				_update_camera_rotate_button_text()
				if _putting_state_machine != null:
					_putting_state_machine.reset()
				popup.queue_free()
			)
			rot_hbox.add_child(r_btn)
		vbox.add_child(rot_hbox)

		# Section 5: Ball & Background Color Detection
		var color_sep = HSeparator.new()
		color_sep.add_theme_constant_override("separation", 8)
		vbox.add_child(color_sep)

		var color_lbl = Label.new()
		color_lbl.text = "5. Ball & Background Color Detection:"
		color_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(color_lbl)

		var color_info = Label.new()
		if _color_profile != null and _color_profile.ball_configured:
			color_info.text = "Ball: H=%.0f° S=%.0f%% V=%.0f%%" % [
				_color_profile.ball_hsv.x,
				_color_profile.ball_hsv.y * 100.0,
				_color_profile.ball_hsv.z * 100.0
			]
		else:
			color_info.text = "Ball: Auto-detect (white ball default)"
		color_info.add_theme_font_size_override("font_size", 12)
		color_info.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
		vbox.add_child(color_info)

		var pick_ball_btn = Button.new()
		pick_ball_btn.text = "🏐 Click to Pick Ball Color from Feed"
		pick_ball_btn.custom_minimum_size = Vector2(0, 36)
		apply_material_button_style(pick_ball_btn, Color(0.45, 0.28, 0.55, 0.9))
		pick_ball_btn.pressed.connect(func():
			_putting_picker_mode = PuttingPickerMode.PICK_BALL
			if _putting_overlay != null:
				_putting_overlay.picker_active = true
			_show_picker_instructions("👉 CLICK ON THE BALL in the video feed below")
			popup.queue_free()
		)
		vbox.add_child(pick_ball_btn)

		var pick_bg_btn = Button.new()
		pick_bg_btn.text = "🟩 Click to Pick Mat/Background Color"
		pick_bg_btn.custom_minimum_size = Vector2(0, 36)
		apply_material_button_style(pick_bg_btn, Color(0.20, 0.45, 0.30, 0.9))
		pick_bg_btn.pressed.connect(func():
			_putting_picker_mode = PuttingPickerMode.PICK_BACKGROUND
			if _putting_overlay != null:
				_putting_overlay.picker_active = true
			_show_picker_instructions("👉 CLICK ON THE MAT/BACKGROUND in the video feed below")
			popup.queue_free()
		)
		vbox.add_child(pick_bg_btn)

		var reset_color_btn = Button.new()
		reset_color_btn.text = "🔄 Reset to Auto-Detect Colors"
		reset_color_btn.custom_minimum_size = Vector2(0, 32)
		apply_material_button_style(reset_color_btn, Color(0.30, 0.35, 0.40, 0.8))
		reset_color_btn.pressed.connect(func():
			if _color_profile != null:
				_color_profile.ball_configured = false
				_color_profile.bg_configured = false
				_color_profile.save_to_settings()
			_update_color_profile()
			popup.queue_free()
		)
		vbox.add_child(reset_color_btn)

		# Tolerance Slider
		var tol_card = VBoxContainer.new()
		tol_card.add_theme_constant_override("separation", 4)

		var tol_header = HBoxContainer.new()
		var tol_label = Label.new()
		tol_label.text = "Color Tolerance:"
		tol_label.add_theme_font_size_override("font_size", 13)
		tol_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		tol_header.add_child(tol_label)

		var tol_spacer = Control.new()
		tol_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tol_header.add_child(tol_spacer)

		var tol_val_lbl = Label.new()
		tol_val_lbl.text = "%.0f°" % (_color_profile.ball_hue_tolerance if _color_profile != null else 30.0)
		tol_val_lbl.add_theme_font_size_override("font_size", 13)
		tol_val_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
		tol_header.add_child(tol_val_lbl)
		tol_card.add_child(tol_header)

		var tol_slider = HSlider.new()
		tol_slider.min_value = 10.0
		tol_slider.max_value = 90.0
		tol_slider.step = 5.0
		tol_slider.value = _color_profile.ball_hue_tolerance if _color_profile != null else 30.0
		tol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tol_slider.custom_minimum_size = Vector2(0, 38)
		ThemeManager.apply_slider_style(tol_slider, 38)
		tol_slider.value_changed.connect(func(v: float):
			tol_val_lbl.text = "%.0f°" % v
			if _color_profile != null:
				_color_profile.ball_hue_tolerance = v
				_color_profile.save_to_settings()
				_update_color_profile()
		)
		tol_card.add_child(tol_slider)
		vbox.add_child(tol_card)

		# Section 6: Speed Validation & Outlier / Mishit Filtering
		var spd_sep = HSeparator.new()
		spd_sep.add_theme_constant_override("separation", 8)
		vbox.add_child(spd_sep)

		var speed_filter_lbl = Label.new()
		speed_filter_lbl.text = "6. Speed Validation & Mishit Filtering:"
		speed_filter_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(speed_filter_lbl)

		var mishit_check = CheckButton.new()
		mishit_check.text = "Auto-Reject Mishits & Tracking Glitches"
		mishit_check.button_pressed = putting_mishit_filter_enabled
		mishit_check.custom_minimum_size = Vector2(0, 36)
		mishit_check.add_theme_font_size_override("font_size", 13)
		mishit_check.toggled.connect(func(val: bool):
			putting_mishit_filter_enabled = val
		)
		vbox.add_child(mishit_check)

		# Min Speed Slider (Mishits)
		var min_spd_card = VBoxContainer.new()
		min_spd_card.add_theme_constant_override("separation", 4)

		var min_spd_hdr = HBoxContainer.new()
		var min_spd_lbl = Label.new()
		min_spd_lbl.text = "Min Speed (Mishit Cutoff):"
		min_spd_lbl.add_theme_font_size_override("font_size", 13)
		min_spd_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		min_spd_hdr.add_child(min_spd_lbl)

		var min_spd_spacer = Control.new()
		min_spd_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		min_spd_hdr.add_child(min_spd_spacer)

		var min_spd_val_lbl = Label.new()
		min_spd_val_lbl.text = "%.1f mph" % putting_min_speed_mph
		min_spd_val_lbl.add_theme_font_size_override("font_size", 13)
		min_spd_val_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
		min_spd_hdr.add_child(min_spd_val_lbl)
		min_spd_card.add_child(min_spd_hdr)

		var min_spd_slider = HSlider.new()
		min_spd_slider.min_value = 0.5
		min_spd_slider.max_value = 4.0
		min_spd_slider.step = 0.1
		min_spd_slider.value = putting_min_speed_mph
		min_spd_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		min_spd_slider.custom_minimum_size = Vector2(0, 38)
		ThemeManager.apply_slider_style(min_spd_slider, 38)
		min_spd_slider.value_changed.connect(func(v: float):
			min_spd_val_lbl.text = "%.1f mph" % v
			putting_min_speed_mph = v
		)
		min_spd_card.add_child(min_spd_slider)

		var min_spd_hint = Label.new()
		min_spd_hint.text = "Accidental taps and practice waggles under this speed are ignored."
		min_spd_hint.add_theme_font_size_override("font_size", 11)
		min_spd_hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		min_spd_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		min_spd_card.add_child(min_spd_hint)
		vbox.add_child(min_spd_card)

		# Max Speed Slider (Tracking Glitches)
		var max_spd_card = VBoxContainer.new()
		max_spd_card.add_theme_constant_override("separation", 4)

		var max_spd_hdr = HBoxContainer.new()
		var max_spd_lbl = Label.new()
		max_spd_lbl.text = "Max Speed (Glitch Cutoff):"
		max_spd_lbl.add_theme_font_size_override("font_size", 13)
		max_spd_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		max_spd_hdr.add_child(max_spd_lbl)

		var max_spd_spacer = Control.new()
		max_spd_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		max_spd_hdr.add_child(max_spd_spacer)

		var max_spd_val_lbl = Label.new()
		max_spd_val_lbl.text = "%.1f mph" % putting_max_speed_mph
		max_spd_val_lbl.add_theme_font_size_override("font_size", 13)
		max_spd_val_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
		max_spd_hdr.add_child(max_spd_val_lbl)
		max_spd_card.add_child(max_spd_hdr)

		var max_spd_slider = HSlider.new()
		max_spd_slider.min_value = 10.0
		max_spd_slider.max_value = 30.0
		max_spd_slider.step = 0.5
		max_spd_slider.value = putting_max_speed_mph
		max_spd_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		max_spd_slider.custom_minimum_size = Vector2(0, 38)
		ThemeManager.apply_slider_style(max_spd_slider, 38)
		max_spd_slider.value_changed.connect(func(v: float):
			max_spd_val_lbl.text = "%.1f mph" % v
			putting_max_speed_mph = v
		)
		max_spd_card.add_child(max_spd_slider)

		var max_spd_hint = Label.new()
		max_spd_hint.text = "Speeds exceeding this are ignored as tracking glitches/anomalies."
		max_spd_hint.add_theme_font_size_override("font_size", 11)
		max_spd_hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		max_spd_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		max_spd_card.add_child(max_spd_hint)
		vbox.add_child(max_spd_card)

	var close_btn = Button.new()
	close_btn.text = "Close Setup"
	close_btn.custom_minimum_size = Vector2(0, 36)
	apply_material_button_style(close_btn, Color(0.4, 0.4, 0.4, 0.8))
	close_btn.pressed.connect(func(): _close_camera_setup_dialog(popup))
	outer_vbox.add_child(close_btn)

	popup.add_child(outer_vbox)
	$OverlayLayer.add_child(popup)

	# Focus neighbors & controller auto-focus
	if is_instance_valid(connect_local_btn) and is_instance_valid(ip_input):
		connect_local_btn.focus_neighbor_bottom = ip_input.get_path()
		ip_input.focus_neighbor_top = connect_local_btn.get_path()
	if is_instance_valid(ip_input) and is_instance_valid(connect_phone_btn):
		ip_input.focus_neighbor_bottom = connect_phone_btn.get_path()
		connect_phone_btn.focus_neighbor_top = ip_input.get_path()

	if has_node("/root/VirtualKeyboardManager"):
		var vkm = get_node("/root/VirtualKeyboardManager")
		if vkm.is_controller_mode_active():
			var local_feeds = CameraServer.feeds()
			if local_feeds.is_empty():
				ip_input.call_deferred("grab_focus")
			elif is_instance_valid(cam_option):
				cam_option.call_deferred("grab_focus")


var _phone_stream_failed_count: int = 0
var _is_requesting_frame: bool = false
var _alt_endpoint_idx: int = 0
var _stream_established: bool = false

func _start_phone_camera_stream(url_str: String) -> void:
	_stop_local_camera_stream()
	_phone_cam_url = _normalize_phone_url(url_str)
	if _phone_cam_url.is_empty():
		_update_status_overlay("INVALID PHONE STREAM URL\n[ Enter IP e.g. 192.168.1.100:8080 ]", true)
		return

	_alt_endpoint_idx = 0
	_stream_established = false
	_phone_stream_failed_count = 0

	# Notify PoseDetectionBridge of host IP for remote MediaPipe AI tracking
	var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_tree().root.get_node_or_null("PoseDetectionBridge")
	if bridge != null and bridge.has_method("set_remote_server_ip"):
		var host_ip = _phone_cam_url.trim_prefix("http://").trim_prefix("https://").trim_prefix("http:/").trim_prefix("https:/").split(":")[0].split("/")[0]
		if not host_ip.is_empty():
			bridge.set_remote_server_ip(host_ip)

	# Reset texture and material so uninitialized/broken textures are removed
	if _camera_feed_rect != null:
		_camera_feed_rect.material = null
		if not (_camera_feed_rect.texture is ImageTexture):
			_camera_feed_rect.texture = null

	_update_status_overlay("CONNECTING TO PHONE STREAM...\n" + _phone_cam_url, true)

	if _http_req == null:
		_http_req = HTTPRequest.new()
		_http_req.name = "PhoneCameraHTTPRequest"
		_http_req.timeout = 3.0
		_http_req.request_completed.connect(_on_phone_cam_frame_received)
		add_child(_http_req)

	_is_requesting_frame = false
	_request_next_phone_frame()


func _normalize_phone_url(raw_url: String) -> String:
	var trimmed = raw_url.strip_edges()
	if trimmed.is_empty():
		return ""
	
	var scheme = "http://"
	if trimmed.begins_with("https://") or trimmed.begins_with("https:/"):
		scheme = "https://"
	
	# Strip any existing scheme prefix (http://, http:/, http:, https://, https:/, https:)
	var cleaned = trimmed
	if cleaned.begins_with("https://"):
		cleaned = cleaned.substr(8)
	elif cleaned.begins_with("https:/"):
		cleaned = cleaned.substr(7)
	elif cleaned.begins_with("https:"):
		cleaned = cleaned.substr(6)
	elif cleaned.begins_with("http://"):
		cleaned = cleaned.substr(7)
	elif cleaned.begins_with("http:/"):
		cleaned = cleaned.substr(6)
	elif cleaned.begins_with("http:"):
		cleaned = cleaned.substr(5)
	
	while cleaned.begins_with("/"):
		cleaned = cleaned.substr(1)
	
	if cleaned.is_empty():
		return ""
	
	# Replace continuous stream endpoints (/video, /mjpeg, /mjpegfeed) with single-frame snapshot endpoints
	# because HTTPRequest waits for EOF before emitting request_completed
	if cleaned.ends_with("/video") or cleaned.ends_with("/mjpeg") or cleaned.ends_with("/mjpegfeed"):
		if cleaned.contains(":4747"):
			cleaned = cleaned.get_base_dir() + "/cam/1/frame.jpg"
		else:
			cleaned = cleaned.get_base_dir() + "/shot.jpg"
	
	var final_url = scheme + cleaned
	
	var has_extension = final_url.ends_with(".jpg") or final_url.ends_with(".jpeg") or final_url.ends_with(".png")
	var has_known_path = final_url.contains("/shot.jpg") or final_url.contains("/oneshot.jpg") or final_url.contains("/cam/1/") or final_url.contains("/photo.jpg") or final_url.contains("/snapshot")
	
	if not has_extension and not has_known_path:
		if final_url.contains(":4747"):
			if not final_url.ends_with("/"):
				final_url += "/"
			final_url += "cam/1/frame.jpg"
		else:
			if not final_url.ends_with("/"):
				final_url += "/"
			final_url += "shot.jpg"
			
	return final_url


func _request_next_phone_frame() -> void:
	if not _should_camera_feed_be_active() or _phone_cam_url.is_empty() or _http_req == null or _is_requesting_frame:
		return

	_is_requesting_frame = true
	var headers = PackedStringArray([
		"User-Agent: HeckleGolfSim/1.0",
		"Accept: image/jpeg, image/*, */*",
		"Connection: keep-alive"
	])
	var err = _http_req.request(_phone_cam_url, headers)
	if err != OK:
		_is_requesting_frame = false
		_handle_phone_stream_error(-1, 0, "HTTP Request dispatch error: %d" % err)


func _on_phone_cam_frame_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_requesting_frame = false

	var success = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and body.size() > 0)
	if success:
		var img = Image.new()
		var err = img.load_jpg_from_buffer(body)
		if err != OK:
			err = img.load_png_from_buffer(body)
		if err == OK:
			_phone_stream_failed_count = 0
			_stream_established = true
			if _camera_rotation_deg != 0:
				_apply_image_rotation(img, _camera_rotation_deg)
			var tex = ImageTexture.create_from_image(img)
			if _camera_feed_rect != null:
				_camera_feed_rect.texture = tex
			_update_status_overlay("", false)
			if _is_putting_cam_enabled:
				_last_putting_feed_image = img
				if _putting_state_machine != null:
					_putting_state_machine.process_frame(img, Time.get_ticks_usec())
		else:
			_try_fallback_endpoint_or_error(result, response_code, "Invalid image encoding received")
	else:
		_try_fallback_endpoint_or_error(result, response_code, "")

	if _should_camera_feed_be_active() and not _phone_cam_url.is_empty():
		var delay = 0.005 if _phone_stream_failed_count == 0 else clamp(0.4 * _phone_stream_failed_count, 0.4, 2.0)
		get_tree().create_timer(delay).timeout.connect(_request_next_phone_frame)


func _try_fallback_endpoint_or_error(result: int, response_code: int, custom_msg: String) -> void:
	# If stream was already established, DO NOT mutate URL to alternate endpoints on transient WiFi hiccups!
	if _stream_established:
		_handle_phone_stream_error(result, response_code, custom_msg)
		return

	# Try alternative snapshot endpoints ONLY during initial connection setup
	var alt_paths = ["/shot.jpg", "/cam/1/frame.jpg", "/oneshot.jpg", "/photo.jpg", "/jpeg"]
	if _alt_endpoint_idx < alt_paths.size() - 1:
		_alt_endpoint_idx += 1
		var current_path = alt_paths[_alt_endpoint_idx]
		var base = _phone_cam_url.get_base_dir()
		if not base.begins_with("http://") and not base.begins_with("https://"):
			base = "http://" + base.trim_prefix("http:/").trim_prefix("http:")
		_phone_cam_url = base + current_path
		return

	_handle_phone_stream_error(result, response_code, custom_msg)


func _handle_phone_stream_error(result: int, response_code: int, custom_msg: String) -> void:
	_phone_stream_failed_count += 1
	var err_detail := ""

	if not custom_msg.is_empty():
		err_detail = custom_msg
	elif result == HTTPRequest.RESULT_CANT_CONNECT:
		err_detail = "Cannot connect to " + _phone_cam_url + "\nVerify phone IP in app & check phone & laptop are on same WiFi network"
	elif result == HTTPRequest.RESULT_TIMEOUT:
		err_detail = "Connection timed out connecting to " + _phone_cam_url
	elif response_code == 404:
		err_detail = "404 Not Found at " + _phone_cam_url + "\nCheck stream path/port in phone camera app (IP Webcam: 8080, DroidCam: 4747)"
	elif response_code > 0:
		err_detail = "HTTP Error %d from phone camera stream" % response_code
	else:
		err_detail = "Failed to connect to phone stream (Result: %d)" % result

	var max_allowed_failures = 10 if _stream_established else 2
	if _phone_stream_failed_count >= max_allowed_failures:
		if _camera_feed_rect != null:
			_camera_feed_rect.material = null
			if not (_camera_feed_rect.texture is ImageTexture):
				_camera_feed_rect.texture = null
		_update_status_overlay("📡 PHONE STREAM DISCONNECTED\n" + err_detail + "\n[ Click ⚙️ Setup to reconfigure ]", true)


func _update_tooltips() -> void:
	if not has_node("/root/KeybindingManager"):
		return
	var km = get_node("/root/KeybindingManager")
	if _stats_btn != null and is_instance_valid(_stats_btn):
		_stats_btn.tooltip_text = "Toggle Stats (Show/Hide) [%s]" % km.get_action_summary_str("toggle_stats")
	if _map_btn != null and is_instance_valid(_map_btn):
		_map_btn.tooltip_text = "Toggle Map View [%s]" % km.get_action_summary_str("aerial_aim")
	if _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
		_hide_helpers_btn.tooltip_text = "Toggle Helpers (Show/Hide) [%s]" % km.get_action_summary_str("toggle_helpers")
	if _skip_btn != null and is_instance_valid(_skip_btn):
		_skip_btn.tooltip_text = "Skip Flight [%s]" % km.get_action_summary_str("skip_flight")
	if _announcer_btn != null and is_instance_valid(_announcer_btn):
		_announcer_btn.tooltip_text = "Toggle Announcer Commentary [%s]" % km.get_action_summary_str("announcer_toggle")
	if _tension_btn != null and is_instance_valid(_tension_btn):
		_tension_btn.tooltip_text = "Toggle Suspense Heartbeat & Tunnel Vision [%s]" % km.get_action_summary_str("suspense_toggle")
	if _golfer_cam_btn != null and is_instance_valid(_golfer_cam_btn):
		_golfer_cam_btn.tooltip_text = "Toggle Golfer Camera [%s]" % km.get_action_summary_str("golfer_cam_toggle")
	if _putting_cam_btn != null and is_instance_valid(_putting_cam_btn):
		_putting_cam_btn.tooltip_text = "Toggle Putting Camera [%s]" % km.get_action_summary_str("putting_cam_toggle")
	if _shot_analysis_btn != null and is_instance_valid(_shot_analysis_btn):
		_shot_analysis_btn.tooltip_text = "Toggle Shot Suggestions & Flaw Analysis [%s]" % km.get_action_summary_str("shot_analysis_toggle")
	if _prev_shot_btn != null and is_instance_valid(_prev_shot_btn):
		_prev_shot_btn.tooltip_text = "View analysis and recommendations for your previous shot [%s]" % km.get_action_summary_str("prev_shot_analysis_toggle")
	if _dist_btn != null and is_instance_valid(_dist_btn):
		_dist_btn.tooltip_text = "Hit Menu [%s]" % km.get_action_summary_str("distance_menu_toggle")
	if _shot_traces_btn != null and is_instance_valid(_shot_traces_btn):
		_shot_traces_btn.tooltip_text = "Toggle Flight Arc Traces & Dispersion View for current club [%s]" % km.get_action_summary_str("shot_traces_toggle")
	if _rollout_btn != null and is_instance_valid(_rollout_btn):
		_rollout_btn.tooltip_text = "Toggle Ball Rollout & Bounce [%s]" % km.get_action_summary_str("rollout_toggle")
	if _stuck_ball_btn != null and is_instance_valid(_stuck_ball_btn):
		_stuck_ball_btn.tooltip_text = "Move ball 2 yards closer to nearest fairway without counting a stroke"


func update_announcer_button_state() -> void:
	if _announcer_btn == null or not is_instance_valid(_announcer_btn):
		return
	var a = get_node_or_null("/root/AnnouncerEngine")
	var is_announcer_on = a.get("AnnouncerRange") if a != null else false
	if is_announcer_on:
		_announcer_btn.text = "🎙 Announcer: ON"
		apply_material_button_style(_announcer_btn, Color(0.2, 0.6, 0.3, 0.85))
	else:
		_announcer_btn.text = "🎙 Announcer: MUTED"
		apply_material_button_style(_announcer_btn, Color(0.5, 0.5, 0.5, 0.85))


func update_suspense_button_state() -> void:
	if _tension_btn == null or not is_instance_valid(_tension_btn):
		return
	var is_tension_on = GlobalSettings.range_settings.tension_effects_enabled.value if has_node("/root/GlobalSettings") else true
	if is_tension_on:
		_tension_btn.text = "💓 Suspense: ON"
		apply_material_button_style(_tension_btn, Color(0.75, 0.2, 0.3, 0.85))
	else:
		_tension_btn.text = "💓 Suspense: OFF"
		apply_material_button_style(_tension_btn, Color(0.5, 0.5, 0.5, 0.85))


func is_rollout_enabled() -> bool:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and gs.range_settings.get("ball_rollout_enabled") != null:
			return bool(gs.range_settings.ball_rollout_enabled.value)
	return true


func set_rollout_enabled(enabled: bool) -> void:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and gs.range_settings.get("ball_rollout_enabled") != null:
			gs.range_settings.ball_rollout_enabled.value = enabled
			gs.save_settings()
	update_rollout_button_state()


func toggle_rollout() -> void:
	var new_val = not is_rollout_enabled()
	set_rollout_enabled(new_val)


func update_rollout_button_state() -> void:
	if _rollout_btn == null or not is_instance_valid(_rollout_btn):
		return
	var is_rollout_on = is_rollout_enabled()
	if is_rollout_on:
		_rollout_btn.text = "🔄 Rollout: ON"
		apply_material_button_style(_rollout_btn, Color(0.2, 0.6, 0.4, 0.85))
	else:
		_rollout_btn.text = "🔄 Rollout: OFF"
		apply_material_button_style(_rollout_btn, Color(0.5, 0.5, 0.5, 0.85))


func _update_track_averages_btn_state() -> void:
	var is_on := true
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and mp.has_method("is_club_averages_tracking_enabled"):
		is_on = mp.is_club_averages_tracking_enabled()
	elif has_node("/root/GlobalSettings") and GlobalSettings.range_settings != null and "track_club_averages" in GlobalSettings.range_settings:
		is_on = bool(GlobalSettings.range_settings.track_club_averages.value)
	if _track_averages_btn != null and is_instance_valid(_track_averages_btn):
		_track_averages_btn.text = "📊 Track Averages: ON" if is_on else "📊 Track Averages: OFF"
		var c = Color(0.18, 0.55, 0.65, 0.85) if is_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(_track_averages_btn, c)
	if _avg_paused_indicator != null and is_instance_valid(_avg_paused_indicator):
		_avg_paused_indicator.visible = not is_on


func toggle_free_camera() -> void:
	set_free_camera_mode(not is_free_camera_active())


func is_free_camera_active() -> bool:
	if _free_camera != null and is_instance_valid(_free_camera):
		return _free_camera.is_active
	var p = get_parent()
	if p != null and p.has_method("is_free_camera_active"):
		return p.call("is_free_camera_active")
	return false


func set_free_camera_mode(enabled: bool) -> void:
	var p = get_parent()
	if p != null and p.has_method("set_free_camera_mode"):
		p.call("set_free_camera_mode", enabled)
	else:
		if enabled:
			if _free_camera == null or not is_instance_valid(_free_camera):
				var free_cam_script = load("res://Utils/free_camera.gd")
				_free_camera = free_cam_script.new()
				_free_camera.name = "FreeCamera3D"
				if p != null:
					p.add_child(_free_camera)
				else:
					add_child(_free_camera)
				if not _free_camera.deactivated.is_connected(_on_free_camera_deactivated):
					_free_camera.deactivated.connect(_on_free_camera_deactivated)
			var cur_cam = get_viewport().get_camera_3d() if get_viewport() != null else null
			_free_camera.activate(cur_cam, p)
		else:
			if _free_camera != null and is_instance_valid(_free_camera):
				_free_camera.deactivate()
			if p != null and p.has_method("reset_to_standard_ball_view"):
				p.call("reset_to_standard_ball_view")
	set_free_camera_btn_state(enabled)
	emit_signal("free_camera_toggled", enabled)


func _on_free_camera_deactivated() -> void:
	var p = get_parent()
	if p != null and p.has_method("reset_to_standard_ball_view"):
		p.call("reset_to_standard_ball_view")
	set_free_camera_btn_state(false)
	emit_signal("free_camera_toggled", false)


func set_free_camera_btn_state(enabled: bool) -> void:
	if _free_cam_btn != null and is_instance_valid(_free_cam_btn):
		if enabled:
			_free_cam_btn.text = "🎥 Free Camera: ON"
			apply_material_button_style(_free_cam_btn, Color(0.2, 0.6, 0.75, 0.9))
		else:
			_free_cam_btn.text = "🎥 Free Camera: OFF"
			apply_material_button_style(_free_cam_btn, Color(0.35, 0.35, 0.35, 0.85))


func _get_current_graphics_quality() -> String:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null:
		if gs.has_method("get_graphics_quality"):
			return gs.get_graphics_quality()
		elif gs.range_settings != null and gs.range_settings.settings.has("graphics_quality"):
			return str(gs.range_settings.settings["graphics_quality"].value)
	return MobilePerformance.get_default_graphics_quality()


func _cycle_graphics_quality(reverse: bool = false) -> void:
	var current_q = _get_current_graphics_quality()
	var is_mob = MobilePerformance.is_mobile()
	var qualities = ["Low", "Medium"] if is_mob else ["Low", "Medium", "High"]
	var idx = qualities.find(current_q)
	if idx == -1:
		idx = 0
	
	if reverse:
		idx = (idx - 1 + qualities.size()) % qualities.size()
	else:
		idx = (idx + 1) % qualities.size()
	
	var next_q = qualities[idx]
	_apply_selected_graphics_quality(next_q)


func _apply_selected_graphics_quality(next_q: String) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null and gs.range_settings != null and gs.range_settings.settings.has("graphics_quality"):
		gs.range_settings.settings["graphics_quality"].set_value(next_q)
		gs.save_settings()
	
	_update_graphics_toggle_btn_state()
	
	var tree = get_tree()
	if tree != null and tree.root != null:
		MobilePerformance.apply_graphics_quality_with_spinner(tree, next_q)
	elif get_node_or_null("/root") != null:
		MobilePerformance.apply_graphics_quality(get_node("/root"), next_q)


func _update_graphics_toggle_btn_state() -> void:
	if _graphics_toggle_btn == null or not is_instance_valid(_graphics_toggle_btn):
		return
	var current_q = _get_current_graphics_quality()
	if MobilePerformance.is_mobile() and current_q == "High":
		current_q = "Medium"
	
	_graphics_toggle_btn.text = "🎨 Graphics: %s" % current_q
	match current_q:
		"Low":
			_graphics_toggle_btn.tooltip_text = "Graphics Quality: Low (Fast Stylized) - Click to cycle"
			apply_material_button_style(_graphics_toggle_btn, Color(0.48, 0.48, 0.52, 0.85))
		"Medium":
			_graphics_toggle_btn.tooltip_text = "Graphics Quality: Medium (Balanced PBR) - Click to cycle"
			apply_material_button_style(_graphics_toggle_btn, Color(0.22, 0.48, 0.68, 0.85))
		"High", _:
			_graphics_toggle_btn.tooltip_text = "Graphics Quality: High (Photorealistic) - Click to cycle"
			apply_material_button_style(_graphics_toggle_btn, Color(0.18, 0.58, 0.38, 0.85))


func cycle_graphics_quality(reverse: bool = false) -> void:
	_cycle_graphics_quality(reverse)


func set_graphics_quality(quality: String) -> void:
	_apply_selected_graphics_quality(quality)


func update_graphics_toggle_btn_state() -> void:
	_update_graphics_toggle_btn_state()


func _on_stuck_ball_button_pressed() -> void:
	stuck_ball_requested.emit()
	if get_signal_connection_list("stuck_ball_requested").is_empty():
		var course = get_parent()
		if course != null and course.has_method("move_stuck_ball"):
			course.call("move_stuck_ball")
		elif course != null and course.has_node("MultiplayerController"):
			var mc = course.get_node("MultiplayerController")
			if mc != null and mc.has_method("move_stuck_ball"):
				mc.call("move_stuck_ball")


func get_stuck_ball_button() -> Button:
	return _stuck_ball_btn


func is_driving_range() -> bool:
	var parent = get_parent()
	if parent != null:
		var parent_path = parent.scene_file_path.to_lower() if "scene_file_path" in parent else ""
		if parent_path.ends_with("range/range.tscn") or parent_path.ends_with("range.tscn") or parent_path.ends_with("range.scn"):
			return true
		if "is_driving_range" in parent and bool(parent.is_driving_range):
			return true
		var parent_name = parent.name.to_lower()
		if parent_name == "range" and not parent_path.contains("course"):
			return true
	return false


func _on_debug_hit_distance_setting_changed(_val) -> void:
	_update_hit_distance_button_visibility()


func _update_hit_distance_button_state() -> void:
	if _dist_btn == null or not is_instance_valid(_dist_btn):
		return
	var menu = null
	if _right_panel != null:
		menu = _right_panel.get_node_or_null("TogglesScroll/TogglesContainer/DistanceMenu")
		if not menu:
			menu = _right_panel.get_node_or_null("TogglesContainer/DistanceMenu")
	if not menu:
		menu = get_node_or_null("DistanceMenu")
	var is_open = menu != null and is_instance_valid(menu) and menu.visible
	if is_open:
		_dist_btn.text = "🎯 Hit Menu: OPEN"
		apply_material_button_style(_dist_btn, Color(0.75, 0.25, 0.75, 0.9))
	else:
		_dist_btn.text = "🎯 Hit Menu"
		apply_material_button_style(_dist_btn, Color(0.6, 0.2, 0.6, 0.85))


func _update_hit_distance_button_visibility() -> void:
	if _dist_btn == null or not is_instance_valid(_dist_btn):
		return
	var enabled := false
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			enabled = bool(gs.range_settings.debug_show_hit_distance.value)
	_dist_btn.visible = enabled
	var menu = null
	if _right_panel != null:
		menu = _right_panel.get_node_or_null("TogglesScroll/TogglesContainer/DistanceMenu")
		if not menu:
			menu = _right_panel.get_node_or_null("TogglesContainer/DistanceMenu")
	if not menu:
		menu = get_node_or_null("DistanceMenu")
	if not enabled and menu != null and menu.visible:
		menu.visible = false
	_update_hit_distance_button_state()
	_update_helpers_scroll_layout.call_deferred()
	call_deferred("_update_hud_focus_neighbors")


func toggle_distance_menu() -> void:
	var enabled := false
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			enabled = bool(gs.range_settings.debug_show_hit_distance.value)
	if not enabled:
		return
	if _dist_btn != null and is_instance_valid(_dist_btn):
		_dist_btn.emit_signal("pressed")


func toggle_shot_traces() -> void:
	_shot_traces_active = not _shot_traces_active
	if _shot_traces_btn != null and is_instance_valid(_shot_traces_btn):
		if _shot_traces_active:
			_shot_traces_btn.text = "📈 Shot Traces: ON"
			apply_material_button_style(_shot_traces_btn, Color(0.15, 0.65, 0.85, 0.85))
		else:
			_shot_traces_btn.text = "📈 Shot Traces: OFF"
			apply_material_button_style(_shot_traces_btn, Color(0.3, 0.35, 0.45, 0.85))

	shot_traces_toggled.emit(_shot_traces_active)
	if (not _shot_traces_active or not is_driving_range()) and _dispersion_overlay != null:
		_dispersion_overlay.visible = false


func is_shot_traces_active() -> bool:
	return _shot_traces_active


func show_dispersion(shots: Array[Dictionary], club_name: String) -> void:
	if not _shot_traces_active or not is_driving_range():
		if _dispersion_overlay != null:
			_dispersion_overlay.visible = false
		return
	if _dispersion_overlay == null:
		var overlay_script = load("res://UI/dispersion_overlay.gd")
		_dispersion_overlay = Control.new()
		_dispersion_overlay.set_script(overlay_script)
		_dispersion_overlay.name = "DispersionOverlay"
		_dispersion_overlay.anchor_left = 0.0
		_dispersion_overlay.anchor_right = 0.0
		_dispersion_overlay.anchor_top = 0.0
		_dispersion_overlay.anchor_bottom = 0.0
		# Place on the left where the minimap sits in course play: below Player Profile (y=90) and above stats (y=360)
		_dispersion_overlay.offset_left = 20.0
		_dispersion_overlay.offset_top = 90.0
		_dispersion_overlay.offset_right = 236.0
		_dispersion_overlay.offset_bottom = 326.0
		$OverlayLayer.add_child(_dispersion_overlay)

	_dispersion_overlay.visible = true
	_dispersion_overlay.update_data(shots, club_name)


func hide_dispersion() -> void:
	if _dispersion_overlay != null:
		_dispersion_overlay.visible = false


func _update_hud_focus_neighbors() -> void:
	var add_remove_btn: Control = get_node_or_null("GridCanvas/AddRemoveButton")
	var club_sel = get_node_or_null("OverlayLayer/ClubSelector")
	var club_btn: Control = null
	if club_sel != null and "club_button" in club_sel:
		club_btn = club_sel.club_button

	var toggles_scroll_node = _right_panel.get_node_or_null("TogglesScroll") if _right_panel != null else null
	var helpers_open = (toggles_scroll_node != null and is_instance_valid(toggles_scroll_node) and toggles_scroll_node.visible)

	# Locate weather & lighting controls if instantiated
	var weather_slider: Control = null
	var weather_btn: Control = null
	var parent_range = get_parent()
	if parent_range != null and is_instance_valid(parent_range) and parent_range.has_method("get_weather_lighting_controller"):
		var w_ctrl = parent_range.get_weather_lighting_controller()
		if w_ctrl != null and is_instance_valid(w_ctrl):
			if "time_slider" in w_ctrl and w_ctrl.time_slider != null and is_instance_valid(w_ctrl.time_slider) and w_ctrl.time_slider.is_visible_in_tree():
				weather_slider = w_ctrl.time_slider
			if "weather_toggle_btn" in w_ctrl and w_ctrl.weather_toggle_btn != null and is_instance_valid(w_ctrl.weather_toggle_btn) and w_ctrl.weather_toggle_btn.is_visible_in_tree():
				weather_btn = w_ctrl.weather_toggle_btn
	if weather_slider == null and get_tree() != null and get_tree().root != null:
		var found_s = get_tree().root.find_child("TimeOfDaySlider", true, false)
		if found_s != null and is_instance_valid(found_s) and found_s.is_visible_in_tree():
			weather_slider = found_s as Control
	if weather_btn == null and get_tree() != null and get_tree().root != null:
		var found_b = get_tree().root.find_child("WeatherToggleButton", true, false)
		if found_b != null and is_instance_valid(found_b) and found_b.is_visible_in_tree():
			weather_btn = found_b as Control

	# 1. Stats button (Bottom-Left)
	if _stats_btn != null and is_instance_valid(_stats_btn):
		if add_remove_btn != null and is_instance_valid(add_remove_btn) and add_remove_btn.visible:
			_stats_btn.focus_neighbor_top = _stats_btn.get_path_to(add_remove_btn)
		elif _profile_option != null and is_instance_valid(_profile_option) and _profile_option.visible:
			_stats_btn.focus_neighbor_top = _stats_btn.get_path_to(_profile_option)
		if _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			_stats_btn.focus_neighbor_right = _stats_btn.get_path_to(_shot_data_btn) if _shot_data_btn != null and is_instance_valid(_shot_data_btn) and _shot_data_btn.visible else _stats_btn.get_path_to(_prev_shot_btn)
		elif _map_btn != null and is_instance_valid(_map_btn):
			_stats_btn.focus_neighbor_right = _stats_btn.get_path_to(_shot_data_btn) if _shot_data_btn != null and is_instance_valid(_shot_data_btn) and _shot_data_btn.visible else _stats_btn.get_path_to(_map_btn)
		if _map_btn != null and is_instance_valid(_map_btn):
			_stats_btn.focus_neighbor_left = _stats_btn.get_path_to(_map_btn)

	if _shot_data_btn != null and is_instance_valid(_shot_data_btn) and _shot_data_btn.visible:
		if _stats_btn != null and is_instance_valid(_stats_btn):
			_shot_data_btn.focus_neighbor_left = _shot_data_btn.get_path_to(_stats_btn)
		if _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			_shot_data_btn.focus_neighbor_right = _shot_data_btn.get_path_to(_prev_shot_btn)
		elif _map_btn != null and is_instance_valid(_map_btn):
			_shot_data_btn.focus_neighbor_right = _shot_data_btn.get_path_to(_map_btn)

	# 2. Previous Shot button (Bottom-Center)
	if _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
		if _shot_data_btn != null and is_instance_valid(_shot_data_btn) and _shot_data_btn.visible:
			_prev_shot_btn.focus_neighbor_left = _prev_shot_btn.get_path_to(_shot_data_btn)
		elif _stats_btn != null and is_instance_valid(_stats_btn):
			_prev_shot_btn.focus_neighbor_left = _prev_shot_btn.get_path_to(_stats_btn)
		if _map_btn != null and is_instance_valid(_map_btn):
			_prev_shot_btn.focus_neighbor_right = _prev_shot_btn.get_path_to(_map_btn)
		if weather_slider != null:
			_prev_shot_btn.focus_neighbor_top = _prev_shot_btn.get_path_to(weather_slider)
		elif weather_btn != null:
			_prev_shot_btn.focus_neighbor_top = _prev_shot_btn.get_path_to(weather_btn)
		elif _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
			_prev_shot_btn.focus_neighbor_top = _prev_shot_btn.get_path_to(_hide_helpers_btn)

	# 3. Add/Remove button (Left middle)
	if add_remove_btn != null and is_instance_valid(add_remove_btn) and add_remove_btn.visible:
		if _stats_btn != null and is_instance_valid(_stats_btn):
			add_remove_btn.focus_neighbor_bottom = add_remove_btn.get_path_to(_stats_btn)
		if _profile_option != null and is_instance_valid(_profile_option) and _profile_option.visible:
			add_remove_btn.focus_neighbor_top = add_remove_btn.get_path_to(_profile_option)
		if _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(_prev_shot_btn)
		elif weather_slider != null:
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(weather_slider)
		elif _map_btn != null and is_instance_valid(_map_btn):
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(_map_btn)

	# 4. Profile Option (Top-Left)
	if _profile_option != null and is_instance_valid(_profile_option) and _profile_option.visible:
		if add_remove_btn != null and is_instance_valid(add_remove_btn) and add_remove_btn.visible:
			_profile_option.focus_neighbor_bottom = _profile_option.get_path_to(add_remove_btn)
		elif _stats_btn != null and is_instance_valid(_stats_btn):
			_profile_option.focus_neighbor_bottom = _profile_option.get_path_to(_stats_btn)
		if weather_slider != null:
			_profile_option.focus_neighbor_right = _profile_option.get_path_to(weather_slider)
		elif weather_btn != null:
			_profile_option.focus_neighbor_right = _profile_option.get_path_to(weather_btn)
		elif _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
			_profile_option.focus_neighbor_right = _profile_option.get_path_to(_hide_helpers_btn)
		if _settings_btn != null and is_instance_valid(_settings_btn):
			_profile_option.focus_neighbor_left = _profile_option.get_path_to(_settings_btn)

	# 4b. Weather & Lighting Controls (Top-Center)
	if weather_slider != null:
		if _profile_option != null and is_instance_valid(_profile_option) and _profile_option.visible:
			weather_slider.focus_neighbor_left = weather_slider.get_path_to(_profile_option)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn) and add_remove_btn.visible:
			weather_slider.focus_neighbor_left = weather_slider.get_path_to(add_remove_btn)
		elif _stats_btn != null and is_instance_valid(_stats_btn):
			weather_slider.focus_neighbor_left = weather_slider.get_path_to(_stats_btn)

		if weather_btn != null:
			weather_slider.focus_neighbor_right = weather_slider.get_path_to(weather_btn)
		elif _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
			weather_slider.focus_neighbor_right = weather_slider.get_path_to(_hide_helpers_btn)

		if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			weather_slider.focus_neighbor_bottom = weather_slider.get_path_to(club_btn)
		elif _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			weather_slider.focus_neighbor_bottom = weather_slider.get_path_to(_prev_shot_btn)
		elif _map_btn != null and is_instance_valid(_map_btn):
			weather_slider.focus_neighbor_bottom = weather_slider.get_path_to(_map_btn)

	if weather_btn != null:
		if weather_slider != null:
			weather_btn.focus_neighbor_left = weather_btn.get_path_to(weather_slider)
		elif _profile_option != null and is_instance_valid(_profile_option) and _profile_option.visible:
			weather_btn.focus_neighbor_left = weather_btn.get_path_to(_profile_option)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn) and add_remove_btn.visible:
			weather_btn.focus_neighbor_left = weather_btn.get_path_to(add_remove_btn)

		if _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
			weather_btn.focus_neighbor_right = weather_btn.get_path_to(_hide_helpers_btn)
		elif _home_btn != null and is_instance_valid(_home_btn):
			weather_btn.focus_neighbor_right = weather_btn.get_path_to(_home_btn)

		if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			weather_btn.focus_neighbor_bottom = weather_btn.get_path_to(club_btn)
		elif _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			weather_btn.focus_neighbor_bottom = weather_btn.get_path_to(_prev_shot_btn)
		elif _map_btn != null and is_instance_valid(_map_btn):
			weather_btn.focus_neighbor_bottom = weather_btn.get_path_to(_map_btn)

	# 5. Map button (Bottom-Right)
	if _map_btn != null and is_instance_valid(_map_btn):
		if _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			_map_btn.focus_neighbor_left = _map_btn.get_path_to(_prev_shot_btn)
		elif _stats_btn != null and is_instance_valid(_stats_btn):
			_map_btn.focus_neighbor_left = _map_btn.get_path_to(_stats_btn)
		if _stats_btn != null and is_instance_valid(_stats_btn):
			_map_btn.focus_neighbor_right = _map_btn.get_path_to(_stats_btn)
		if _settings_btn != null and is_instance_valid(_settings_btn):
			_map_btn.focus_neighbor_top = _map_btn.get_path_to(_settings_btn)

	# 6. Settings button (Top-Right)
	if _settings_btn != null and is_instance_valid(_settings_btn):
		if _home_btn != null and is_instance_valid(_home_btn):
			_settings_btn.focus_neighbor_left = _settings_btn.get_path_to(_home_btn)
		if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			_settings_btn.focus_neighbor_bottom = _settings_btn.get_path_to(club_btn)
		elif _map_btn != null and is_instance_valid(_map_btn):
			_settings_btn.focus_neighbor_bottom = _settings_btn.get_path_to(_map_btn)

	# 7. Home button (Top-Right)
	if _home_btn != null and is_instance_valid(_home_btn):
		if _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
			_home_btn.focus_neighbor_left = _home_btn.get_path_to(_hide_helpers_btn)
		if _settings_btn != null and is_instance_valid(_settings_btn):
			_home_btn.focus_neighbor_right = _home_btn.get_path_to(_settings_btn)
		if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			_home_btn.focus_neighbor_bottom = _home_btn.get_path_to(club_btn)
		elif _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
			_home_btn.focus_neighbor_bottom = _home_btn.get_path_to(_prev_shot_btn)
		elif _map_btn != null and is_instance_valid(_map_btn):
			_home_btn.focus_neighbor_bottom = _home_btn.get_path_to(_map_btn)

	# 8. Hide Helpers button (Top-Right)
	if _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
		if weather_btn != null:
			_hide_helpers_btn.focus_neighbor_left = _hide_helpers_btn.get_path_to(weather_btn)
		elif weather_slider != null:
			_hide_helpers_btn.focus_neighbor_left = _hide_helpers_btn.get_path_to(weather_slider)
		elif _profile_option != null and is_instance_valid(_profile_option) and _profile_option.visible:
			_hide_helpers_btn.focus_neighbor_left = _hide_helpers_btn.get_path_to(_profile_option)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn) and add_remove_btn.visible:
			_hide_helpers_btn.focus_neighbor_left = _hide_helpers_btn.get_path_to(add_remove_btn)
		if _home_btn != null and is_instance_valid(_home_btn):
			_hide_helpers_btn.focus_neighbor_right = _hide_helpers_btn.get_path_to(_home_btn)
		
		var first_helper: Control = _imm_menu_btn if (_imm_menu_btn != null and is_instance_valid(_imm_menu_btn) and _imm_menu_btn.visible) else _announcer_btn
		if helpers_open and first_helper != null and is_instance_valid(first_helper):
			_hide_helpers_btn.focus_neighbor_bottom = _hide_helpers_btn.get_path_to(first_helper)
		elif club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			_hide_helpers_btn.focus_neighbor_bottom = _hide_helpers_btn.get_path_to(club_btn)

	# 9. Club selector button
	if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
		if _home_btn != null and is_instance_valid(_home_btn):
			club_btn.focus_neighbor_top = club_btn.get_path_to(_home_btn)
		elif _settings_btn != null and is_instance_valid(_settings_btn):
			club_btn.focus_neighbor_top = club_btn.get_path_to(_settings_btn)
		var first_helper_c: Control = _imm_menu_btn if (_imm_menu_btn != null and is_instance_valid(_imm_menu_btn) and _imm_menu_btn.visible) else _announcer_btn
		if helpers_open and first_helper_c != null and is_instance_valid(first_helper_c):
			club_btn.focus_neighbor_bottom = club_btn.get_path_to(first_helper_c)
		elif _map_btn != null and is_instance_valid(_map_btn):
			club_btn.focus_neighbor_bottom = club_btn.get_path_to(_map_btn)

	# 10. Wire helper vertical list if open
	if helpers_open and toggles_scroll_node != null:
		var helper_controls: Array[Control] = []
		var container = toggles_scroll_node.get_node_or_null("TogglesContainer")
		if container != null:
			for ch in container.get_children():
				if ch is Button and ch.visible:
					helper_controls.append(ch)
				elif ch is ScreenOffsetControl and ch.visible:
					for foc in ch.get_focusables():
						helper_controls.append(foc)
				elif ch is VBoxContainer and ch.visible:
					for sub_ch in ch.get_children():
						if sub_ch is Button and sub_ch.visible:
							helper_controls.append(sub_ch)
						elif sub_ch is ScreenOffsetControl and sub_ch.visible:
							for foc in sub_ch.get_focusables():
								helper_controls.append(foc)
		for i in range(helper_controls.size()):
			var h_ctrl = helper_controls[i]
			if i == 0:
				if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
					h_ctrl.focus_neighbor_top = h_ctrl.get_path_to(club_btn)
				elif _hide_helpers_btn != null and is_instance_valid(_hide_helpers_btn):
					h_ctrl.focus_neighbor_top = h_ctrl.get_path_to(_hide_helpers_btn)
			else:
				h_ctrl.focus_neighbor_top = h_ctrl.get_path_to(helper_controls[i - 1])
			if i < helper_controls.size() - 1:
				h_ctrl.focus_neighbor_bottom = h_ctrl.get_path_to(helper_controls[i + 1])
			else:
				if _map_btn != null and is_instance_valid(_map_btn):
					h_ctrl.focus_neighbor_bottom = h_ctrl.get_path_to(_map_btn)
				elif _prev_shot_btn != null and is_instance_valid(_prev_shot_btn) and _prev_shot_btn.visible:
					h_ctrl.focus_neighbor_bottom = h_ctrl.get_path_to(_prev_shot_btn)


func _update_helpers_scroll_layout() -> void:
	if _right_panel == null:
		return
	if _toggles_scroll == null:
		_toggles_scroll = _right_panel.get_node_or_null("TogglesScroll")
	if _toggles_scroll == null:
		return
	var v_bar = _toggles_scroll.get_v_scroll_bar()
	var is_bar_visible = v_bar != null and v_bar.visible and _toggles_scroll.visible
	var scroll_w = int(v_bar.size.x) if (v_bar != null and is_bar_visible) else 0
	if scroll_w <= 0 and is_bar_visible and v_bar != null:
		scroll_w = int(v_bar.custom_minimum_size.x)
	var shift = (scroll_w + 6) if scroll_w > 0 else 0

	var dist_menu = _toggles_scroll.find_child("DistanceMenu", true, false)
	var is_dist_menu_visible = dist_menu != null and is_instance_valid(dist_menu) and dist_menu.visible and _toggles_scroll.visible
	var dist_shift = 0
	if is_dist_menu_visible:
		var is_mob = MobilePerformance.is_mobile()
		dist_shift = 220 if is_mob else 160

	_right_panel.offset_left = -280 - shift - dist_shift
