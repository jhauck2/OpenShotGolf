extends PanelContainer

# SwingReplayModal
# Nearly full-screen modal replaying the golfer's swing in slow motion in a loop
# with skeleton tracking lines and prioritized swing fix recommendations.

class_name SwingReplayModal

const ClubDeliveryVisuals = preload("res://UI/GolferCamera/club_delivery_visuals.gd")
const AnalyticsVisualWidgetsScript = preload("res://UI/ShotAnalysis/analytics_visual_widgets.gd")

signal closed()
signal detach_requested()
signal attach_requested()

# Detached Window State
var is_detached: bool = false

# Nodes
var _skeleton_overlay: GolferSkeletonOverlay = null
var _play_pause_btn: Button = null
var _speed_025_btn: Button = null
var _speed_05_btn: Button = null
var _speed_10_btn: Button = null
var _scrub_slider: HSlider = null
var _time_lbl: Label = null
var _rec_vbox: VBoxContainer = null
var _replay_feed_rect: TextureRect = null

# Playback State
var is_playing: bool = true
var replay_speed: float = 0.5 # Default 0.5x slow motion
var current_time: float = 0.0
var total_duration: float = 2.5 # 2.5 second swing loop

var shot_data: Dictionary = {}
var recommendations: Array[Dictionary] = []
var _recorded_frames: Array = []
var _is_suggestions_only: bool = false
var _checkpoint_progress: Dictionary = {
	"Address": 0.0,
	"Top (P4)": 0.35,
	"Impact (P7)": 0.65,
	"Finish": 1.0
}

# Deferred Background Analysis State
var _is_analysis_complete: bool = false
var _analysis_cancelled: bool = false
var _analysis_loading_panel: PanelContainer = null
var _analysis_progress_bar: ProgressBar = null
var _analysis_status_lbl: Label = null
var _analysis_sub_lbl: Label = null
var _skel_toggle_btn: Button = null

# Mobile layout state
var _mobile_tab_btn_video: Button = null
var _mobile_tab_btn_recs: Button = null
var _left_vbox: VBoxContainer = null
var _right_vbox: VBoxContainer = null
var _mobile_active_tab: int = 1 # 0: Video, 1: Fixes & Analysis


static func is_detach_supported() -> bool:
	var os_name = OS.get_name().to_lower()
	if os_name == "ios" or os_name == "android":
		return false
	if OS.has_feature("mobile"):
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return false
	return true


func _is_mobile_view() -> bool:
	if is_detached:
		return false
	var vp_size = get_viewport_rect().size
	return vp_size.x < 850 or vp_size.y > vp_size.x or OS.has_feature("mobile")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_recenter_modal()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if not UIFocusGuard.is_locked() or UIFocusGuard.current_lock_root() != self:
		UIFocusGuard.push_lock(self)
	var preferred_btn := find_child("ResumePracticeButton", true, false)
	if preferred_btn == null or not is_instance_valid(preferred_btn):
		preferred_btn = find_child("CloseDetachedButton", true, false)
	if preferred_btn != null and is_instance_valid(preferred_btn) and preferred_btn.is_visible_in_tree():
		preferred_btn.grab_focus()
		return
	if has_node("/root/KeybindingManager"):
		var km = get_node("/root/KeybindingManager")
		km.focus_first_control(self)


func _on_focus_lock_popped() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var detail_modal = get_node_or_null("DetailModal")
	if detail_modal != null and is_instance_valid(detail_modal):
		InAppVideoPlayer.stop_all_players()
		detail_modal.queue_free()
		return
	_on_close_button_pressed()


func _input(event: InputEvent) -> void:
	if _process_detail_modal_scroll(event):
		return
	_process_close_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if _process_detail_modal_scroll(event):
		return
	_process_close_input(event)


func _process_detail_modal_scroll(event: InputEvent) -> bool:
	var detail_modal = get_node_or_null("DetailModal")
	if detail_modal == null or not is_instance_valid(detail_modal) or not detail_modal.visible:
		return false
	var scroll: ScrollContainer = detail_modal.find_child("DetailScroll", true, false) as ScrollContainer
	if scroll == null or not is_instance_valid(scroll):
		return false

	# 1. Analog Right Stick scrolling
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		if abs(event.axis_value) >= 0.2:
			scroll.scroll_vertical += int(event.axis_value * 14.0)
			get_viewport().set_input_as_handled()
			return true

	# 2. Shoulder buttons for page scrolling (LB / RB)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			var page_h := int(max(scroll.size.y * 0.7, 100.0))
			scroll.scroll_vertical = max(0, scroll.scroll_vertical - page_h)
			get_viewport().set_input_as_handled()
			return true
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			var page_h := int(max(scroll.size.y * 0.7, 100.0))
			scroll.scroll_vertical += page_h
			get_viewport().set_input_as_handled()
			return true

	# 3. D-pad & Left Stick scrolling when scroll container is focused
	var vp := get_viewport()
	if vp != null and vp.gui_get_focus_owner() == scroll:
		var is_down: bool = event.is_action_pressed("ui_down") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_DOWN and event.pressed) or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value >= 0.5)
		var is_up: bool = event.is_action_pressed("ui_up") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed) or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value <= -0.5)

		var v_bar := scroll.get_v_scroll_bar()
		var max_v := v_bar.max_value - scroll.size.y if v_bar != null else 9999.0

		if is_down:
			if scroll.scroll_vertical < max_v - 15:
				scroll.scroll_vertical += 60
				get_viewport().set_input_as_handled()
				return true
			else:
				var footer_btn := detail_modal.find_child("FooterCloseButton", true, false) as Control
				if footer_btn != null and is_instance_valid(footer_btn) and footer_btn.is_visible_in_tree():
					footer_btn.grab_focus()
					get_viewport().set_input_as_handled()
					return true
		elif is_up:
			if scroll.scroll_vertical > 15:
				scroll.scroll_vertical = max(0, scroll.scroll_vertical - 60)
				get_viewport().set_input_as_handled()
				return true
			else:
				var close_btn := detail_modal.find_child("CloseButton", true, false) as Control
				if close_btn != null and is_instance_valid(close_btn) and close_btn.is_visible_in_tree():
					close_btn.grab_focus()
					get_viewport().set_input_as_handled()
					return true
	return false


func _process_close_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not event.is_pressed():
		return
	if event is InputEventKey and event.echo:
		return

	var is_cancel: bool = event.is_action_pressed("ui_cancel") or \
		event.is_action_pressed("prev_shot_analysis_toggle") or \
		event.is_action_pressed("shot_analysis_toggle") or \
		(event is InputEventKey and (event.keycode == KEY_ESCAPE or event.keycode == KEY_V or event.keycode == KEY_Y)) or \
		(event is InputEventJoypadButton and (event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_Y))

	if is_cancel:
		var vp = get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		var detail_modal = get_node_or_null("DetailModal")
		if detail_modal != null and is_instance_valid(detail_modal):
			InAppVideoPlayer.stop_all_players()
			detail_modal.queue_free()
			return
		_on_close_button_pressed()


func _on_viewport_resized() -> void:
	_recenter_modal()


func _recenter_modal() -> void:
	var vp_size = get_viewport_rect().size
	if is_detached:
		position = Vector2.ZERO
		size = vp_size
		custom_minimum_size = vp_size
		var win = get_window()
		if win != null and not win.size_changed.is_connected(_on_viewport_resized):
			win.size_changed.connect(_on_viewport_resized)
		return

	var is_mob = _is_mobile_view()
	var modal_w: float
	var modal_h: float
	if is_mob:
		modal_w = clamp(vp_size.x * 0.98, 320, 850)
		modal_h = clamp(vp_size.y * 0.97, 420, 1000)
	elif _is_suggestions_only:
		modal_w = clamp(vp_size.x * 0.65, 540, 920)
		modal_h = clamp(vp_size.y * 0.88, 500, 900)
	else:
		modal_w = clamp(vp_size.x * 0.92, 800, 1400)
		modal_h = clamp(vp_size.y * 0.90, 520, 920)
	
	size = Vector2(modal_w, modal_h)
	custom_minimum_size = size
	position = (vp_size - size) * 0.5


func setup_modal(data: Dictionary, frames: Array = [], suggestions_only: bool = false) -> void:
	shot_data = data.duplicate()
	_is_suggestions_only = suggestions_only
	_recorded_frames = [] if suggestions_only else frames.duplicate()
	if not _recorded_frames.is_empty():
		total_duration = max(1.0, _recorded_frames.size() * 0.066)
		var initial_phases = GolfSwingAnalyzer.detect_key_phases(_recorded_frames)
		if initial_phases.get("has_phases", false):
			_checkpoint_progress["Top (P4)"] = initial_phases.get("top_progress", 0.35)
			_checkpoint_progress["Impact (P7)"] = initial_phases.get("impact_progress", 0.65)
	_is_analysis_complete = suggestions_only
	_analysis_cancelled = false

	# PHASE 1: Immediate Launch Monitor analysis so user gets instant real suggestions
	recommendations = GolfSwingAnalyzer.analyze_launch_monitor(shot_data)

	_recenter_modal()
	_build_ui()
	if not _is_suggestions_only:
		_start_background_wireframe_analysis()
	else:
		_record_swing_recommendations()
	call_deferred("_grab_initial_focus")


func update_shot_data(data: Dictionary, frames: Array = [], suggestions_only: bool = false) -> void:
	_analysis_cancelled = true
	_close_active_video_players()
	shot_data = data.duplicate()
	_is_suggestions_only = suggestions_only
	_recorded_frames = [] if suggestions_only else frames.duplicate()
	current_time = 0.0
	is_playing = true
	if not _recorded_frames.is_empty():
		total_duration = max(1.0, _recorded_frames.size() * 0.066)
		var initial_phases = GolfSwingAnalyzer.detect_key_phases(_recorded_frames)
		if initial_phases.get("has_phases", false):
			_checkpoint_progress["Top (P4)"] = initial_phases.get("top_progress", 0.35)
			_checkpoint_progress["Impact (P7)"] = initial_phases.get("impact_progress", 0.65)
	_is_analysis_complete = suggestions_only
	_analysis_cancelled = false

	recommendations = GolfSwingAnalyzer.analyze_launch_monitor(shot_data)

	_recenter_modal()
	_build_ui()
	if not _is_suggestions_only:
		_start_background_wireframe_analysis()
	else:
		_record_swing_recommendations()
	call_deferred("_grab_initial_focus")


func _build_ui() -> void:
	# Clear existing children if any
	for c in get_children():
		c.queue_free()
		
	var is_mob = _is_mobile_view()

	# Glassmorphic Modal Container Style
	var modal_style = StyleBoxFlat.new()
	modal_style.bg_color = Color(0.06, 0.08, 0.12, 0.98 if is_detached else 0.96) # Dark obsidian
	modal_style.corner_radius_top_left = 0 if is_detached else (14 if is_mob else 16)
	modal_style.corner_radius_top_right = 0 if is_detached else (14 if is_mob else 16)
	modal_style.corner_radius_bottom_left = 0 if is_detached else (14 if is_mob else 16)
	modal_style.corner_radius_bottom_right = 0 if is_detached else (14 if is_mob else 16)
	modal_style.border_width_left = 0 if is_detached else 2
	modal_style.border_width_top = 0 if is_detached else 2
	modal_style.border_width_right = 0 if is_detached else 2
	modal_style.border_width_bottom = 0 if is_detached else 2
	modal_style.border_color = Color(0.2, 0.6, 0.8, 0.8)
	modal_style.shadow_color = Color(0, 0, 0, 0.0 if is_detached else 0.6)
	modal_style.shadow_size = 0 if is_detached else (16 if is_mob else 20)
	modal_style.content_margin_left = 10 if is_mob else 16
	modal_style.content_margin_top = 10 if is_mob else 16
	modal_style.content_margin_right = 10 if is_mob else 16
	modal_style.content_margin_bottom = 10 if is_mob else 16
	add_theme_stylebox_override("panel", modal_style)

	if _is_suggestions_only:
		_build_suggestions_only_ui()
		return

	var is_match = false
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty() and not mp_mgr.practice_mode_active:
		is_match = true

	var outer_vbox: VBoxContainer = null
	if is_mob:
		outer_vbox = VBoxContainer.new()
		outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer_vbox.add_theme_constant_override("separation", 8)

		# Mobile Top Header Bar: Title + Touch-friendly Resume/Next button
		var top_bar = HBoxContainer.new()
		top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var m_title = Label.new()
		m_title.text = "🎯 SHOT ANALYSIS"
		m_title.add_theme_font_size_override("font_size", 18)
		m_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		top_bar.add_child(m_title)
		
		var m_spacer = Control.new()
		m_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_bar.add_child(m_spacer)
		
		var m_close_btn = Button.new()
		m_close_btn.name = "ResumePracticeButton"
		m_close_btn.text = "✖ NEXT" if is_match else "✖ RESUME"
		m_close_btn.custom_minimum_size = Vector2(110, 42)
		m_close_btn.add_theme_font_size_override("font_size", 15)
		_apply_btn_style(m_close_btn, Color(0.75, 0.2, 0.2))
		m_close_btn.pressed.connect(_on_close_button_pressed)
		top_bar.add_child(m_close_btn)
		outer_vbox.add_child(top_bar)

		# Mobile Tab Selector: [ 🎯 Fixes & Telemetry ] [ 📹 Video Replay ]
		var tab_bar = HBoxContainer.new()
		tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_bar.add_theme_constant_override("separation", 8)

		_mobile_tab_btn_recs = Button.new()
		_mobile_tab_btn_recs.text = "🎯 Fixes & Data (%d)" % recommendations.size()
		_mobile_tab_btn_recs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mobile_tab_btn_recs.custom_minimum_size = Vector2(0, 46)
		_mobile_tab_btn_recs.add_theme_font_size_override("font_size", 16)
		_mobile_tab_btn_recs.pressed.connect(func(): _show_mobile_tab(1))
		tab_bar.add_child(_mobile_tab_btn_recs)

		_mobile_tab_btn_video = Button.new()
		_mobile_tab_btn_video.text = "📹 Video Replay"
		_mobile_tab_btn_video.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mobile_tab_btn_video.custom_minimum_size = Vector2(0, 46)
		_mobile_tab_btn_video.add_theme_font_size_override("font_size", 16)
		_mobile_tab_btn_video.pressed.connect(func(): _show_mobile_tab(0))
		tab_bar.add_child(_mobile_tab_btn_video)

		outer_vbox.add_child(tab_bar)

	# =========================================================================
	# LEFT SIDE: SLOW-MOTION VIDEO & SKELETON REPLAY PLAYER
	# =========================================================================
	_left_vbox = VBoxContainer.new()
	_left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_vbox.size_flags_stretch_ratio = 1.2
	_left_vbox.add_theme_constant_override("separation", 8 if is_mob else 10)

	if not is_mob:
		var left_title = Label.new()
		left_title.text = "📹 SLOW-MOTION SWING REPLAY"
		left_title.add_theme_font_size_override("font_size", 18)
		left_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		_left_vbox.add_child(left_title)

	var video_panel = PanelContainer.new()
	video_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	video_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	video_panel.custom_minimum_size = Vector2(280, 220) if is_mob else Vector2(400, 360)

	var vid_style = StyleBoxFlat.new()
	vid_style.bg_color = Color(0.02, 0.03, 0.05, 1.0)
	vid_style.corner_radius_top_left = 10
	vid_style.corner_radius_top_right = 10
	vid_style.corner_radius_bottom_left = 10
	vid_style.corner_radius_bottom_right = 10
	vid_style.border_width_left = 1
	vid_style.border_width_top = 1
	vid_style.border_width_right = 1
	vid_style.border_width_bottom = 1
	vid_style.border_color = Color(0.15, 0.35, 0.5)
	video_panel.add_theme_stylebox_override("panel", vid_style)

	var feed_rect = TextureRect.new()
	feed_rect.name = "ReplayFeedRect"
	feed_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	feed_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_replay_feed_rect = feed_rect
	
	if _recorded_frames.is_empty():
		if OS.has_feature("mobile") and CameraServer.get_feed_count() > 0:
			var feed = CameraServer.get_feed(0)
			if feed != null and feed.feed_is_active:
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

void fragment() {
	vec2 uv = (feed_transform * vec3(UV, 1.0)).xy;
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

					feed_rect.material = mat
					feed_rect.texture = y_tex
				else:
					feed_rect.material = null
					var cam_tex = CameraTexture.new()
					cam_tex.camera_feed_id = feed.get_id()
					cam_tex.which_feed = CameraServer.FEED_RGBA_IMAGE
					cam_tex.camera_is_active = true
					feed_rect.texture = cam_tex
		else:
			var pose_bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else (get_node_or_null("/root/PoseDetectionBridge") if is_inside_tree() else null)
			if pose_bridge != null and pose_bridge.has_signal("desktop_frame_received"):
				pose_bridge.desktop_frame_received.connect(func(_img, tex, _landmarks):
					if _replay_feed_rect != null and _recorded_frames.is_empty():
						_replay_feed_rect.material = null
						_replay_feed_rect.texture = tex
				)

	video_panel.add_child(feed_rect)

	# Stick Skeleton Overlay & Human Pose Detection
	_skeleton_overlay = GolferSkeletonOverlay.new()
	_skeleton_overlay.name = "GolferSkeletonOverlay"
	_skeleton_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skeleton_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skeleton_overlay.is_replay_mode = not _recorded_frames.is_empty()
	_skeleton_overlay.show_skeleton = _is_analysis_complete
	video_panel.add_child(_skeleton_overlay)

	_left_vbox.add_child(video_panel)

	# Checkpoint Jump Buttons - Wrapped in HFlowContainer so buttons fit on narrow screens
	var check_flow = HFlowContainer.new()
	check_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_flow.add_theme_constant_override("h_separation", 6)
	check_flow.add_theme_constant_override("v_separation", 4)
	
	var check_lbl = Label.new()
	check_lbl.text = "Checkpoints:"
	check_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 14)
	check_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	check_flow.add_child(check_lbl)

	var check_points = [
		["Address", 0.0],
		["Top (P4)", 0.35],
		["Impact (P7)", 0.65],
		["Finish", 1.0]
	]
	for cp in check_points:
		var cp_btn = Button.new()
		cp_btn.text = cp[0]
		cp_btn.custom_minimum_size = Vector2(85, 36) if is_mob else Vector2(90, 32)
		cp_btn.add_theme_font_size_override("font_size", 13 if is_mob else 14)
		_apply_btn_style(cp_btn, Color(0.18, 0.25, 0.35))
		var cp_name: String = cp[0]
		var default_prog: float = cp[1]
		cp_btn.pressed.connect(func():
			_set_paused_state(true)
			var prog_val: float = _checkpoint_progress.get(cp_name, default_prog)
			current_time = prog_val * total_duration
			_update_playback_frame()
		)
		check_flow.add_child(cp_btn)
	_left_vbox.add_child(check_flow)

	# Controls Bar
	var ctrl_vbox = VBoxContainer.new()
	ctrl_vbox.add_theme_constant_override("separation", 6)

	var scrub_hbox = HBoxContainer.new()
	scrub_hbox.add_theme_constant_override("separation", 8)
	
	_scrub_slider = HSlider.new()
	_scrub_slider.min_value = 0.0
	_scrub_slider.max_value = total_duration
	_scrub_slider.step = 0.02
	_scrub_slider.value = 0.0
	_scrub_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub_slider.custom_minimum_size = Vector2(100, 48 if MobilePerformance.is_mobile() else 36)
	ThemeManager.apply_slider_style(_scrub_slider, 48 if MobilePerformance.is_mobile() else 36, 100)
	_scrub_slider.value_changed.connect(func(val):
		current_time = val
		_update_playback_frame()
	)
	scrub_hbox.add_child(_scrub_slider)

	_time_lbl = Label.new()
	_time_lbl.text = "0.0s / 2.5s"
	_time_lbl.custom_minimum_size = Vector2(80, 0)
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 14)
	_time_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	scrub_hbox.add_child(_time_lbl)
	ctrl_vbox.add_child(scrub_hbox)

	# Playback & speed controls wrapped in HFlowContainer for mobile
	var act_flow = HFlowContainer.new()
	act_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_flow.add_theme_constant_override("h_separation", 6)
	act_flow.add_theme_constant_override("v_separation", 6)

	_play_pause_btn = Button.new()
	_play_pause_btn.text = "⏸ PAUSE"
	_play_pause_btn.custom_minimum_size = Vector2(100, 40)
	_play_pause_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(_play_pause_btn, Color(0.2, 0.5, 0.4))
	_play_pause_btn.pressed.connect(func():
		_set_paused_state(is_playing)
	)
	act_flow.add_child(_play_pause_btn)

	var step_back = Button.new()
	step_back.text = "⏮ -1"
	step_back.custom_minimum_size = Vector2(75, 40)
	step_back.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(step_back, Color(0.2, 0.25, 0.35))
	step_back.pressed.connect(func():
		_set_paused_state(true)
		current_time = clamp(current_time - 0.05, 0.0, total_duration)
		_update_playback_frame()
	)
	act_flow.add_child(step_back)

	var step_fwd = Button.new()
	step_fwd.text = "+1 ⏭"
	step_fwd.custom_minimum_size = Vector2(75, 40)
	step_fwd.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(step_fwd, Color(0.2, 0.25, 0.35))
	step_fwd.pressed.connect(func():
		_set_paused_state(true)
		current_time = clamp(current_time + 0.05, 0.0, total_duration)
		_update_playback_frame()
	)
	act_flow.add_child(step_fwd)

	_speed_025_btn = Button.new()
	_speed_025_btn.text = "0.25x"
	_speed_025_btn.custom_minimum_size = Vector2(55, 40)
	_speed_025_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(_speed_025_btn, Color(0.2, 0.25, 0.35))
	_speed_025_btn.pressed.connect(func(): _set_replay_speed(0.25))
	act_flow.add_child(_speed_025_btn)

	_speed_05_btn = Button.new()
	_speed_05_btn.text = "0.5x"
	_speed_05_btn.custom_minimum_size = Vector2(55, 40)
	_speed_05_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(_speed_05_btn, Color(0.15, 0.5, 0.6))
	_speed_05_btn.pressed.connect(func(): _set_replay_speed(0.5))
	act_flow.add_child(_speed_05_btn)

	_speed_10_btn = Button.new()
	_speed_10_btn.text = "1.0x"
	_speed_10_btn.custom_minimum_size = Vector2(55, 40)
	_speed_10_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(_speed_10_btn, Color(0.2, 0.25, 0.35))
	_speed_10_btn.pressed.connect(func(): _set_replay_speed(1.0))
	act_flow.add_child(_speed_10_btn)

	_skel_toggle_btn = Button.new()
	_skel_toggle_btn.text = "🦴 Skeleton: PENDING" if not _is_analysis_complete else ("🦴 Skeleton: ON" if _skeleton_overlay.show_skeleton else "🦴 Skeleton: OFF")
	_skel_toggle_btn.disabled = not _is_analysis_complete
	_skel_toggle_btn.custom_minimum_size = Vector2(140, 40)
	_skel_toggle_btn.add_theme_font_size_override("font_size", 13)
	_apply_btn_style(_skel_toggle_btn, Color(0.25, 0.25, 0.3) if not _is_analysis_complete else (Color(0.15, 0.45, 0.45) if _skeleton_overlay.show_skeleton else Color(0.25, 0.25, 0.3)))
	_skel_toggle_btn.pressed.connect(func():
		if _skeleton_overlay != null and _is_analysis_complete:
			_skeleton_overlay.show_skeleton = not _skeleton_overlay.show_skeleton
			_skel_toggle_btn.text = "🦴 Skeleton: ON" if _skeleton_overlay.show_skeleton else "🦴 Skeleton: OFF"
			_apply_btn_style(_skel_toggle_btn, Color(0.15, 0.45, 0.45) if _skeleton_overlay.show_skeleton else Color(0.25, 0.25, 0.3))
			_update_playback_frame()
	)
	act_flow.add_child(_skel_toggle_btn)

	ctrl_vbox.add_child(act_flow)
	_left_vbox.add_child(ctrl_vbox)

	# =========================================================================
	# RIGHT SIDE: SWING ANALYSIS & PRIORITIZED RECOMMENDATIONS
	# =========================================================================
	_right_vbox = VBoxContainer.new()
	_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_vbox.size_flags_stretch_ratio = 1.0
	_right_vbox.add_theme_constant_override("separation", 8 if is_mob else 10)

	if not is_mob:
		var r_header = HBoxContainer.new()
		r_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_header.add_theme_constant_override("separation", 10)
		
		var r_title = Label.new()
		r_title.text = "🎯 RECOMMENDED FIXES (PRIORITIZED)"
		r_title.add_theme_font_size_override("font_size", 18)
		r_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		r_header.add_child(r_title)

		if is_detached:
			var badge = Label.new()
			badge.text = "🟢 DETACHED (ALWAYS OPEN)"
			badge.add_theme_font_size_override("font_size", 12)
			badge.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
			r_header.add_child(badge)

		var r_spacer = Control.new()
		r_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_header.add_child(r_spacer)

		if is_detached:
			var dock_btn = Button.new()
			dock_btn.name = "DockToGameButton"
			dock_btn.text = "↙ DOCK TO GAME"
			dock_btn.custom_minimum_size = Vector2(140, 42)
			dock_btn.add_theme_font_size_override("font_size", 14)
			dock_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_btn_style(dock_btn, Color(0.2, 0.45, 0.65))
			dock_btn.tooltip_text = "Attach this window back into the main game screen"
			dock_btn.pressed.connect(func(): emit_signal("attach_requested"))
			r_header.add_child(dock_btn)

			var close_btn = Button.new()
			close_btn.name = "CloseDetachedButton"
			close_btn.text = "✖ CLOSE"
			close_btn.custom_minimum_size = Vector2(100, 42)
			close_btn.add_theme_font_size_override("font_size", 14)
			close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_btn_style(close_btn, Color(0.75, 0.2, 0.2))
			close_btn.pressed.connect(_on_close_button_pressed)
			r_header.add_child(close_btn)
		else:
			if is_detach_supported():
				var popout_btn = Button.new()
				popout_btn.name = "PopoutWindowButton"
				popout_btn.text = "↗ POP OUT"
				popout_btn.custom_minimum_size = Vector2(120, 42)
				popout_btn.add_theme_font_size_override("font_size", 14)
				popout_btn.mouse_filter = Control.MOUSE_FILTER_STOP
				_apply_btn_style(popout_btn, Color(0.18, 0.45, 0.65))
				popout_btn.tooltip_text = "Detach window to move to a 2nd screen and keep open without needing to click Next Shot"
				popout_btn.pressed.connect(func(): emit_signal("detach_requested"))
				r_header.add_child(popout_btn)

			var close_btn = Button.new()
			close_btn.name = "ResumePracticeButton"
			close_btn.text = "✖ NEXT SHOT" if is_match else "✖ RESUME PRACTICE"
			close_btn.custom_minimum_size = Vector2(175, 42)
			close_btn.add_theme_font_size_override("font_size", 15)
			close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_btn_style(close_btn, Color(0.75, 0.2, 0.2))
			close_btn.pressed.connect(_on_close_button_pressed)
			r_header.add_child(close_btn)

		_right_vbox.add_child(r_header)

	# Shot Telemetry Bar (Mobile Responsive Chips)
	var telem_panel = _create_telemetry_panel()
	_right_vbox.add_child(telem_panel)

	# Dynamic Club Delivery & Impact Visuals (3 Side-by-Side Cards)
	var delivery_panel = ClubDeliveryVisuals.create_panel(shot_data, false)
	_right_vbox.add_child(delivery_panel)

	# Loading / Analysis Progress Panel (shown until background wireframe analysis completes)
	if not _is_analysis_complete:
		var load_panel = PanelContainer.new()
		load_panel.name = "AnalysisLoadingPanel"
		load_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var load_style = StyleBoxFlat.new()
		load_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
		load_style.corner_radius_top_left = 10
		load_style.corner_radius_top_right = 10
		load_style.corner_radius_bottom_left = 10
		load_style.corner_radius_bottom_right = 10
		load_style.border_width_left = 2
		load_style.border_width_top = 2
		load_style.border_width_right = 2
		load_style.border_width_bottom = 2
		load_style.border_color = Color(0.2, 0.6, 0.85, 0.8)
		load_style.content_margin_left = 12 if is_mob else 16
		load_style.content_margin_top = 10 if is_mob else 16
		load_style.content_margin_right = 12 if is_mob else 16
		load_style.content_margin_bottom = 10 if is_mob else 16
		load_panel.add_theme_stylebox_override("panel", load_style)

		var l_vbox = VBoxContainer.new()
		l_vbox.add_theme_constant_override("separation", 6 if is_mob else 10)

		var l_title = Label.new()
		l_title.text = "🦴 SKELETON WIREFRAME ANALYSIS IN PROGRESS"
		l_title.add_theme_font_size_override("font_size", 14 if is_mob else 15)
		l_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		l_vbox.add_child(l_title)

		_analysis_status_lbl = Label.new()
		_analysis_status_lbl.text = "Tracking body joint kinematics & rotation in background..."
		_analysis_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_analysis_status_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 14)
		_analysis_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.6))
		l_vbox.add_child(_analysis_status_lbl)

		_analysis_progress_bar = ProgressBar.new()
		_analysis_progress_bar.min_value = 0.0
		_analysis_progress_bar.max_value = 100.0
		_analysis_progress_bar.value = 0.0
		_analysis_progress_bar.custom_minimum_size = Vector2(0, 24)
		_analysis_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_analysis_progress_bar.show_percentage = true

		var bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.04, 0.06, 0.1, 1.0)
		bar_bg.corner_radius_top_left = 6
		bar_bg.corner_radius_top_right = 6
		bar_bg.corner_radius_bottom_left = 6
		bar_bg.corner_radius_bottom_right = 6
		_analysis_progress_bar.add_theme_stylebox_override("background", bar_bg)

		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.15, 0.65, 0.85, 1.0)
		bar_fill.corner_radius_top_left = 6
		bar_fill.corner_radius_top_right = 6
		bar_fill.corner_radius_bottom_left = 6
		bar_fill.corner_radius_bottom_right = 6
		_analysis_progress_bar.add_theme_stylebox_override("fill", bar_fill)
		l_vbox.add_child(_analysis_progress_bar)

		_analysis_sub_lbl = Label.new()
		_analysis_sub_lbl.text = "Launch monitor insights are shown below. Once full skeleton calculation completes, shoulder/hip squareness and rotation will be analyzed."
		_analysis_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_analysis_sub_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 13)
		_analysis_sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		l_vbox.add_child(_analysis_sub_lbl)

		load_panel.add_child(l_vbox)
		_analysis_loading_panel = load_panel
		_right_vbox.add_child(load_panel)

	# Scrollable Recommendation Cards Container
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ThemeManager.apply_scroll_container_style(scroll, 28)

	_rec_vbox = VBoxContainer.new()
	_rec_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rec_vbox.add_theme_constant_override("separation", 10 if is_mob else 12)

	if recommendations.is_empty():
		var empty_card = _create_empty_card()
		_rec_vbox.add_child(empty_card)
	else:
		for rec in recommendations:
			var card = _create_recommendation_card(rec)
			_rec_vbox.add_child(card)

	scroll.add_child(_rec_vbox)
	_right_vbox.add_child(scroll)

	if is_mob:
		outer_vbox.add_child(_left_vbox)
		outer_vbox.add_child(_right_vbox)
		add_child(outer_vbox)
		_show_mobile_tab(_mobile_active_tab)
	else:
		var main_hbox = HBoxContainer.new()
		main_hbox.add_theme_constant_override("separation", 16)
		main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_hbox.add_child(_left_vbox)
		main_hbox.add_child(_right_vbox)
		add_child(main_hbox)

	_update_playback_frame()


func _show_mobile_tab(tab_idx: int) -> void:
	_mobile_active_tab = tab_idx
	if _left_vbox != null:
		_left_vbox.visible = (tab_idx == 0)
	if _right_vbox != null:
		_right_vbox.visible = (tab_idx == 1)
	if _mobile_tab_btn_video != null and _mobile_tab_btn_recs != null:
		if tab_idx == 0:
			_apply_btn_style(_mobile_tab_btn_video, Color(0.2, 0.55, 0.8))
			_apply_btn_style(_mobile_tab_btn_recs, Color(0.12, 0.16, 0.22))
		else:
			_apply_btn_style(_mobile_tab_btn_video, Color(0.12, 0.16, 0.22))
			_apply_btn_style(_mobile_tab_btn_recs, Color(0.2, 0.55, 0.8))


func _build_suggestions_only_ui() -> void:
	var is_mob = _is_mobile_view()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10 if is_mob else 14)

	# Header with Title and Close Button
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title = Label.new()
	title.text = "🎯 RECOMMENDED FIXES"
	title.add_theme_font_size_override("font_size", 18 if is_mob else 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	header.add_child(title)

	if is_detached:
		var badge = Label.new()
		badge.text = "🟢 DETACHED (ALWAYS OPEN)"
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
		header.add_child(badge)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var is_match = false
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty() and not mp_mgr.practice_mode_active:
		is_match = true

	if is_detached:
		var dock_btn = Button.new()
		dock_btn.name = "DockToGameButton"
		dock_btn.text = "↙ DOCK TO GAME"
		dock_btn.custom_minimum_size = Vector2(140, 44)
		dock_btn.add_theme_font_size_override("font_size", 14)
		dock_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_btn_style(dock_btn, Color(0.2, 0.45, 0.65))
		dock_btn.tooltip_text = "Attach this window back into the main game screen"
		dock_btn.pressed.connect(func(): emit_signal("attach_requested"))
		header.add_child(dock_btn)

		var close_btn = Button.new()
		close_btn.name = "CloseDetachedButton"
		close_btn.text = "✖ CLOSE"
		close_btn.custom_minimum_size = Vector2(100, 44)
		close_btn.add_theme_font_size_override("font_size", 14)
		close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_btn_style(close_btn, Color(0.75, 0.2, 0.2))
		close_btn.pressed.connect(_on_close_button_pressed)
		header.add_child(close_btn)
	else:
		if is_detach_supported():
			var popout_btn = Button.new()
			popout_btn.name = "PopoutWindowButton"
			popout_btn.text = "↗ POP OUT"
			popout_btn.custom_minimum_size = Vector2(120, 44)
			popout_btn.add_theme_font_size_override("font_size", 14)
			popout_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_btn_style(popout_btn, Color(0.18, 0.45, 0.65))
			popout_btn.tooltip_text = "Detach window to move to a 2nd screen and keep open without needing to click Next Shot"
			popout_btn.pressed.connect(func(): emit_signal("detach_requested"))
			header.add_child(popout_btn)

		var close_btn = Button.new()
		close_btn.name = "ResumePracticeButton"
		close_btn.text = "✖ NEXT SHOT" if is_match else "✖ RESUME PRACTICE"
		close_btn.custom_minimum_size = Vector2(140 if is_mob else 180, 44)
		close_btn.add_theme_font_size_override("font_size", 15)
		close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_btn_style(close_btn, Color(0.75, 0.2, 0.2))
		close_btn.pressed.connect(_on_close_button_pressed)
		header.add_child(close_btn)

	vbox.add_child(header)

	# Shot Telemetry Bar (Mobile Responsive Chips)
	var telem_panel = _create_telemetry_panel()
	vbox.add_child(telem_panel)

	# Dynamic Club Delivery & Impact Visuals (3 Side-by-Side Cards)
	var delivery_panel = ClubDeliveryVisuals.create_panel(shot_data, false)
	vbox.add_child(delivery_panel)

	# Informational Note Banner for Video Shot Analysis
	var note_panel = PanelContainer.new()
	note_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var note_style = StyleBoxFlat.new()
	note_style.bg_color = Color(0.06, 0.12, 0.18, 0.95)
	note_style.corner_radius_top_left = 8
	note_style.corner_radius_top_right = 8
	note_style.corner_radius_bottom_left = 8
	note_style.corner_radius_bottom_right = 8
	note_style.border_width_left = 3
	note_style.border_width_top = 1
	note_style.border_width_right = 1
	note_style.border_width_bottom = 1
	note_style.border_color = Color(0.2, 0.65, 0.85, 0.85)
	note_style.content_margin_left = 12 if is_mob else 16
	note_style.content_margin_top = 10 if is_mob else 12
	note_style.content_margin_right = 12 if is_mob else 16
	note_style.content_margin_bottom = 10 if is_mob else 12
	note_panel.add_theme_stylebox_override("panel", note_style)

	var note_hbox = HBoxContainer.new()
	note_hbox.add_theme_constant_override("separation", 10)

	var note_icon = Label.new()
	note_icon.text = "📹"
	note_icon.add_theme_font_size_override("font_size", 22 if is_mob else 24)
	note_hbox.add_child(note_icon)

	var note_lbl = Label.new()
	note_lbl.text = "Golfer Cam is OFF. Enable it in the camera menu for slow-mo replay and AI skeleton tracking."
	note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 14)
	note_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	note_hbox.add_child(note_lbl)

	note_panel.add_child(note_hbox)
	vbox.add_child(note_panel)

	# Scrollable Recommendation Cards Container
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ThemeManager.apply_scroll_container_style(scroll, 28)

	_rec_vbox = VBoxContainer.new()
	_rec_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rec_vbox.add_theme_constant_override("separation", 12 if is_mob else 14)

	if recommendations.is_empty():
		var empty_card = _create_empty_card()
		_rec_vbox.add_child(empty_card)
	else:
		for rec in recommendations:
			var card = _create_recommendation_card(rec)
			_rec_vbox.add_child(card)

	scroll.add_child(_rec_vbox)
	vbox.add_child(scroll)

	add_child(vbox)


func _create_telemetry_panel() -> PanelContainer:
	var telem_panel = PanelContainer.new()
	telem_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_mob = _is_mobile_view()
	var telem_style = StyleBoxFlat.new()
	telem_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	telem_style.corner_radius_top_left = 8
	telem_style.corner_radius_top_right = 8
	telem_style.corner_radius_bottom_left = 8
	telem_style.corner_radius_bottom_right = 8
	telem_style.border_width_left = 1
	telem_style.border_width_top = 1
	telem_style.border_width_right = 1
	telem_style.border_width_bottom = 1
	telem_style.border_color = Color(0.18, 0.32, 0.45, 0.8)
	telem_style.content_margin_left = 10 if is_mob else 12
	telem_style.content_margin_top = 8 if is_mob else 10
	telem_style.content_margin_right = 10 if is_mob else 12
	telem_style.content_margin_bottom = 8 if is_mob else 10
	telem_panel.add_theme_stylebox_override("panel", telem_style)

	var flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8 if is_mob else 10)
	flow.add_theme_constant_override("v_separation", 8)

	var raw_club = shot_data.get("Club", shot_data.get("club", "Driver"))
	var club_name = GolfSwingAnalyzer.get_club_display_name(str(raw_club))
	var is_tee = bool(shot_data.get("is_tee", false))
	var lie_str = "Tee" if is_tee else "Fairway"
	if shot_data.has("lie_type") and str(shot_data["lie_type"]) != "":
		var lt = str(shot_data["lie_type"]).to_lower()
		if lt == "rough":
			lie_str = "Rough"
		elif lt == "sand" or lt == "bunker":
			lie_str = "Bunker"
		elif lt == "tee":
			lie_str = "Tee"

	var dist_val = float(shot_data.get("Carry", shot_data.get("CarryDistance", shot_data.get("TotalDistance", 220))))
	var speed_val = float(shot_data.get("Speed", shot_data.get("BallSpeed", 140.0)))
	var axis_val = float(shot_data.get("SpinAxis", 0.0))
	var vla_val = float(shot_data.get("VLA", 14.2))
	var smash_val = shot_data.get("SmashFactor", "")
	var aoa_val = shot_data.get("AttackAngle", shot_data.get("AngleOfAttack", ""))

	# Club & Lie Badge
	flow.add_child(_create_stat_card("CLUB & LIE", "%s (%s)" % [club_name, lie_str], Color(0.4, 0.85, 1.0)))
	# Carry
	flow.add_child(_create_stat_card("CARRY", "%.0f yds" % dist_val, Color(0.35, 0.95, 0.6)))
	# Ball Speed
	flow.add_child(_create_stat_card("BALL SPEED", "%.1f mph" % speed_val, Color(1.0, 0.85, 0.3)))
	# Spin Axis
	var axis_col = Color(0.4, 0.9, 1.0) if abs(axis_val) <= 4.0 else (Color(1.0, 0.7, 0.3) if abs(axis_val) <= 9.0 else Color(1.0, 0.4, 0.4))
	flow.add_child(_create_stat_card("SPIN AXIS", "%+.1f°" % axis_val, axis_col))
	# VLA (Launch Angle)
	flow.add_child(_create_stat_card("LAUNCH (VLA)", "%.1f°" % vla_val, Color(0.85, 0.75, 1.0)))
	# Smash Factor
	if str(smash_val) != "" and str(smash_val) != "---" and str(smash_val) != "N/A":
		var sf = float(smash_val)
		if sf > 0.05:
			var sf_col = Color(0.35, 0.95, 0.6) if sf >= 1.45 else (Color(1.0, 0.8, 0.3) if sf >= 1.35 else Color(1.0, 0.4, 0.4))
			var is_comp: bool = (shot_data.has("_computed_stats") and "SmashFactor" in shot_data["_computed_stats"])
			var smash_title = "* SMASH *" if is_comp else "SMASH"
			flow.add_child(_create_stat_card(smash_title, str(smash_val), sf_col))
	# AoA
	if str(aoa_val) != "" and str(aoa_val) != "---" and str(aoa_val) != "N/A":
		var aoa_num = float(str(aoa_val).replace("+", "").replace("°", ""))
		if abs(aoa_num) >= 0.1:
			flow.add_child(_create_stat_card("AOA", "%s°" % str(aoa_val), Color(0.7, 0.85, 1.0)))

	telem_panel.add_child(flow)
	return telem_panel


func _create_stat_card(title: String, val: String, val_color: Color = Color.WHITE) -> PanelContainer:
	var card = PanelContainer.new()
	var is_mob = _is_mobile_view()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.07, 0.11, 0.92)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.2, 0.35, 0.5, 0.8)
	card_style.content_margin_left = 10 if is_mob else 12
	card_style.content_margin_top = 6 if is_mob else 8
	card_style.content_margin_right = 10 if is_mob else 12
	card_style.content_margin_bottom = 6 if is_mob else 8
	card.add_theme_stylebox_override("panel", card_style)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)

	var t_lbl = Label.new()
	t_lbl.text = title.to_upper()
	t_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 12)
	t_lbl.add_theme_color_override("font_color", Color(0.7, 0.82, 0.92))
	vb.add_child(t_lbl)

	var v_lbl = Label.new()
	v_lbl.text = val
	v_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 17)
	v_lbl.add_theme_color_override("font_color", val_color)
	vb.add_child(v_lbl)

	card.add_child(vb)
	return card


func _create_empty_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_mob = _is_mobile_view()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.14, 0.1, 0.95)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 3
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.2, 0.8, 0.4, 0.8)
	card_style.content_margin_left = 16
	card_style.content_margin_top = 14
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = "⛳ Solid Strike! No Major Swing Flaws Detected"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16 if is_mob else 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "All launch monitor metrics (Smash Factor, Spin Axis, Launch Window) were within optimal benchmark ranges. Keep grooving this swing pattern!"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13 if is_mob else 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	vbox.add_child(desc)

	card.add_child(vbox)
	return card


func _process(delta: float) -> void:
	if _is_suggestions_only:
		return
	if is_playing:
		current_time += delta * replay_speed
		if current_time >= total_duration:
			current_time = 0.0
		_update_playback_frame()

func _set_paused_state(paused: bool) -> void:
	is_playing = not paused
	if _skeleton_overlay != null:
		_skeleton_overlay.is_paused = paused
	if _play_pause_btn != null:
		_play_pause_btn.text = "▶ PLAY" if paused else "⏸ PAUSE"
		_apply_btn_style(_play_pause_btn, Color(0.15, 0.45, 0.6) if paused else Color(0.2, 0.5, 0.4))

func _update_playback_frame() -> void:
	if _scrub_slider != null:
		_scrub_slider.set_value_no_signal(current_time)
	if _time_lbl != null:
		_time_lbl.text = "%.2fs / %.1fs" % [current_time, total_duration]

	if not _recorded_frames.is_empty():
		var frame_idx: int = clamp(int((current_time / total_duration) * (_recorded_frames.size() - 1)), 0, _recorded_frames.size() - 1)
		var frame_data: Dictionary = _recorded_frames[frame_idx]
		
		var tex: Texture2D = frame_data.get("texture")
		if tex == null:
			var img: Image = frame_data.get("image")
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				frame_data["texture"] = tex
		
		if tex != null and _replay_feed_rect != null:
			_replay_feed_rect.material = null
			_replay_feed_rect.texture = tex
			
		var lms: Dictionary = frame_data.get("landmarks", {})
		if _skeleton_overlay != null:
			if _is_analysis_complete and _skeleton_overlay.show_skeleton and not lms.is_empty():
				_skeleton_overlay._on_pose_detected(lms)
			else:
				_skeleton_overlay._on_pose_lost()
	elif _skeleton_overlay != null:
		var prog = current_time / total_duration
		_skeleton_overlay.set_frame_progress(prog)

func _set_replay_speed(spd: float) -> void:
	replay_speed = spd
	_apply_btn_style(_speed_025_btn, Color(0.15, 0.5, 0.6) if spd == 0.25 else Color(0.2, 0.25, 0.35))
	_apply_btn_style(_speed_05_btn, Color(0.15, 0.5, 0.6) if spd == 0.5 else Color(0.2, 0.25, 0.35))
	_apply_btn_style(_speed_10_btn, Color(0.15, 0.5, 0.6) if spd == 1.0 else Color(0.2, 0.25, 0.35))

func _get_combined_telemetry() -> Dictionary:
	if _recorded_frames.is_empty():
		return _skeleton_overlay.get_measured_telemetry() if _skeleton_overlay != null else {}

	var max_turn: float = 0.0
	var min_spine: float = 90.0
	var max_ext: float = 0.0
	var max_sway: float = 0.0
	var base_width: float = 0.0
	var base_hip_y: float = 0.0
	var base_hip_x: float = 0.0
	var valid_count: int = 0

	for frame_data in _recorded_frames:
		var lms: Dictionary = frame_data.get("landmarks", {})
		if not (lms.has("left_shoulder") and lms.has("right_shoulder") and lms.has("left_hip") and lms.has("right_hip")):
			continue

		var ls_pos = Vector2(float(lms["left_shoulder"].get("x", 0)), float(lms["left_shoulder"].get("y", 0)))
		var rs_pos = Vector2(float(lms["right_shoulder"].get("x", 0)), float(lms["right_shoulder"].get("y", 0)))
		var lh_pos = Vector2(float(lms["left_hip"].get("x", 0)), float(lms["left_hip"].get("y", 0)))
		var rh_pos = Vector2(float(lms["right_hip"].get("x", 0)), float(lms["right_hip"].get("y", 0)))

		var s_mid = (ls_pos + rs_pos) * 0.5
		var h_mid = (lh_pos + rh_pos) * 0.5
		var width = ls_pos.distance_to(rs_pos)
		var torso = s_mid.distance_to(h_mid)

		if valid_count == 0:
			base_width = width
			base_hip_y = h_mid.y
			base_hip_x = h_mid.x

		valid_count += 1

		# Spine angle
		var spine_vec = s_mid - h_mid
		var spine_angle = rad_to_deg(atan2(abs(spine_vec.x), -spine_vec.y))
		min_spine = min(min_spine, spine_angle)

		# Shoulder turn
		if base_width > 0.001:
			var w_ratio = clamp(width / base_width, 0.0, 1.0)
			var turn = rad_to_deg(acos(w_ratio))
			max_turn = max(max_turn, turn)

		# Early extension & sway
		if torso > 0.01:
			var ext = ((base_hip_y - h_mid.y) / torso) * 10.0
			max_ext = max(max_ext, ext)
			var sway = ((h_mid.x - base_hip_x) / torso) * 10.0
			max_sway = max(max_sway, abs(sway))

	if valid_count < 3:
		return _skeleton_overlay.get_measured_telemetry() if _skeleton_overlay != null else {}

	return {
		"spine_angle": min_spine,
		"shoulder_turn": max_turn,
		"early_extension": max_ext,
		"hip_sway": max_sway,
		"has_valid_telemetry": true
	}


func _start_background_wireframe_analysis() -> void:
	if not is_inside_tree():
		await ready

	if _recorded_frames.is_empty():
		await get_tree().create_timer(0.4).timeout
		if not _analysis_cancelled and is_inside_tree():
			_on_analysis_finished()
		return

	# Sample wireframe keyframes every 250ms (0.25 seconds) = 4 per second
	var sample_interval: float = 0.25
	var num_frames: int = _recorded_frames.size()

	var sample_times: Array[float] = []
	var t: float = 0.0
	while t <= total_duration:
		sample_times.append(t)
		t += sample_interval
	if sample_times.is_empty() or abs(sample_times.back() - total_duration) > 0.05:
		sample_times.append(total_duration)

	var keyframe_indices: Array[int] = []
	for st in sample_times:
		var idx: int = clamp(int(round((st / total_duration) * (num_frames - 1))), 0, num_frames - 1)
		if not idx in keyframe_indices:
			keyframe_indices.append(idx)
	keyframe_indices.sort()

	var total_keyframes: int = keyframe_indices.size()
	var bridge = Engine.get_singleton("PoseDetectionBridge") if Engine.has_singleton("PoseDetectionBridge") else get_node_or_null("/root/PoseDetectionBridge")

	for i in range(total_keyframes):
		if _analysis_cancelled or not is_inside_tree():
			return

		var k_idx: int = keyframe_indices[i]
		var frame_data: Dictionary = _recorded_frames[k_idx]
		var img: Image = frame_data.get("image")

		# Update progress UI
		var pct: float = (float(i) / float(max(1, total_keyframes))) * 100.0
		if _analysis_progress_bar != null and is_instance_valid(_analysis_progress_bar):
			_analysis_progress_bar.value = pct
		if _analysis_status_lbl != null and is_instance_valid(_analysis_status_lbl):
			_analysis_status_lbl.text = "Analyzing skeleton kinematics... (%d of %d wireframes)" % [i + 1, total_keyframes]

		var landmarks: Dictionary = {}
		if bridge != null and bridge.has_method("detect_pose_for_image_async") and img != null and not img.is_empty():
			landmarks = await bridge.detect_pose_for_image_async(img)

		if _analysis_cancelled or not is_inside_tree():
			return

		frame_data["landmarks"] = landmarks
		frame_data["is_keyframe"] = true

		# Yield one frame so rendering loop and video playback stay buttery smooth
		if get_tree() == null:
			return
		await get_tree().process_frame

	if _analysis_cancelled or not is_inside_tree():
		return

	if _analysis_progress_bar != null and is_instance_valid(_analysis_progress_bar):
		_analysis_progress_bar.value = 100.0
	if _analysis_status_lbl != null and is_instance_valid(_analysis_status_lbl):
		_analysis_status_lbl.text = "Analysis complete! Correlating skeleton kinematics with ball flight..."

	# Smoothly interpolate intermediate frames between keyframes
	_interpolate_landmarks_between_keyframes(keyframe_indices)

	# Finalize analysis and switch replay loop to include wireframe skeleton & recommendations
	_on_analysis_finished()


func _interpolate_landmarks_between_keyframes(keyframe_indices: Array[int]) -> void:
	if keyframe_indices.is_empty() or _recorded_frames.is_empty():
		return

	var total_frames: int = _recorded_frames.size()

	# Propagate first keyframe to any preceding frames
	var first_k = keyframe_indices[0]
	var first_lms: Dictionary = _recorded_frames[first_k].get("landmarks", {})
	for f in range(0, first_k):
		_recorded_frames[f]["landmarks"] = first_lms.duplicate(true)

	# Interpolate between consecutive keyframes
	for i in range(keyframe_indices.size() - 1):
		var idx_a = keyframe_indices[i]
		var idx_b = keyframe_indices[i + 1]
		var lms_a: Dictionary = _recorded_frames[idx_a].get("landmarks", {})
		var lms_b: Dictionary = _recorded_frames[idx_b].get("landmarks", {})
		var span: int = idx_b - idx_a
		if span <= 1:
			continue

		for k in range(idx_a + 1, idx_b):
			var ratio: float = float(k - idx_a) / float(span)
			var interp_lms: Dictionary = {}

			var all_keys: Array = []
			for key in lms_a.keys():
				if not key in all_keys:
					all_keys.append(key)
			for key in lms_b.keys():
				if not key in all_keys:
					all_keys.append(key)

			for key in all_keys:
				var has_a = lms_a.has(key)
				var has_b = lms_b.has(key)
				if has_a and has_b:
					var a_x = float(lms_a[key].get("x", 0.0))
					var a_y = float(lms_a[key].get("y", 0.0))
					var a_z = float(lms_a[key].get("z", 0.0))
					var a_vis = float(lms_a[key].get("visibility", 1.0))
					var b_x = float(lms_b[key].get("x", 0.0))
					var b_y = float(lms_b[key].get("y", 0.0))
					var b_z = float(lms_b[key].get("z", 0.0))
					var b_vis = float(lms_b[key].get("visibility", 1.0))
					var mean_vis = lerp(a_vis, b_vis, ratio)
					interp_lms[key] = {
						"x": lerp(a_x, b_x, ratio),
						"y": lerp(a_y, b_y, ratio),
						"z": lerp(a_z, b_z, ratio),
						"visibility": mean_vis,
						"visible": mean_vis >= 0.25
					}
				elif has_a and ratio < 0.5:
					interp_lms[key] = lms_a[key].duplicate(true)
				elif has_b and ratio >= 0.5:
					interp_lms[key] = lms_b[key].duplicate(true)

			_recorded_frames[k]["landmarks"] = interp_lms

	# Propagate last keyframe to any succeeding frames
	var last_k = keyframe_indices.back()
	var last_lms: Dictionary = _recorded_frames[last_k].get("landmarks", {})
	for f in range(last_k + 1, total_frames):
		_recorded_frames[f]["landmarks"] = last_lms.duplicate(true)


func _on_analysis_finished() -> void:
	_is_analysis_complete = true

	# Remove loading progress panel
	if _analysis_loading_panel != null and is_instance_valid(_analysis_loading_panel):
		_analysis_loading_panel.queue_free()
		_analysis_loading_panel = null

	# Enable skeleton overlay
	if _skeleton_overlay != null:
		_skeleton_overlay.show_skeleton = true

	# Update skeleton toggle button
	if _skel_toggle_btn != null and is_instance_valid(_skel_toggle_btn):
		_skel_toggle_btn.disabled = false
		_skel_toggle_btn.text = "🦴 Skeleton: ON"
		_apply_btn_style(_skel_toggle_btn, Color(0.15, 0.45, 0.45))

	# Compute deep skeleton sequence analysis across all frames
	var fallback_telemetry := _get_combined_telemetry()
	var skeleton_analysis: Dictionary = GolfSwingAnalyzer.analyze_skeleton_sequence(_recorded_frames, fallback_telemetry)
	if skeleton_analysis.has("top_frame_progress"):
		_checkpoint_progress["Top (P4)"] = skeleton_analysis["top_frame_progress"]
	if skeleton_analysis.has("impact_frame_progress"):
		_checkpoint_progress["Impact (P7)"] = skeleton_analysis["impact_frame_progress"]
	recommendations = GolfSwingAnalyzer.analyze_shot_unified(shot_data, skeleton_analysis)
	_refresh_recommendation_cards()
	_record_swing_recommendations()

	# Immediately update display with wireframe skeleton
	_update_playback_frame()


func _record_swing_recommendations() -> void:
	if recommendations.is_empty():
		return
	if shot_data.get("_recommendations_recorded", false) and _is_suggestions_only:
		return
	var player_name = str(shot_data.get("player", shot_data.get("Player", "")))
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if player_name.is_empty() and mp_mgr != null and mp_mgr.has_method("get_active_player"):
		var active_player = mp_mgr.get_active_player()
		if not active_player.is_empty():
			player_name = str(active_player.get("name", ""))
	if player_name.is_empty():
		var r_ui = get_tree().root.find_child("RangeUI", true, false)
		if r_ui != null and r_ui.has_method("get_selected_player_name"):
			player_name = r_ui.get_selected_player_name()
	if player_name.is_empty():
		player_name = "Player 1"
	if mp_mgr != null and mp_mgr.has_method("record_player_swing_issues"):
		var club_name: String = str(shot_data.get("Club", shot_data.get("club", "")))
		mp_mgr.record_player_swing_issues(player_name, recommendations, club_name)
		shot_data["_recommendations_recorded"] = true


func _refresh_recommendation_cards() -> void:
	if _rec_vbox == null:
		return
	for c in _rec_vbox.get_children():
		c.queue_free()
	if recommendations.is_empty():
		var empty_card = _create_empty_card()
		_rec_vbox.add_child(empty_card)
	else:
		for rec in recommendations:
			var card = _create_recommendation_card(rec)
			_rec_vbox.add_child(card)
	if _mobile_tab_btn_recs != null and is_instance_valid(_mobile_tab_btn_recs):
		_mobile_tab_btn_recs.text = "🎯 Fixes & Data (%d)" % recommendations.size()


func _on_close_button_pressed() -> void:
	_analysis_cancelled = true
	_close_active_video_players()
	visible = false
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == self:
		UIFocusGuard.pop_lock(true)
	emit_signal("closed")
	queue_free()


func _exit_tree() -> void:
	_close_active_video_players()
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == self:
		UIFocusGuard.pop_lock(false)


func _close_active_video_players() -> void:
	InAppVideoPlayer.stop_all_players()
	var detail_modal = get_node_or_null("DetailModal")
	if detail_modal != null and is_instance_valid(detail_modal):
		detail_modal.queue_free()

func _create_recommendation_card(rec: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_mob = _is_mobile_view()

	var severity: String = str(rec.get("severity", "MEDIUM"))
	var priority_num: int = int(rec.get("priority", 1))
	
	var border_col = Color(1.0, 0.3, 0.3, 0.9) if severity == "CRITICAL" else (Color(1.0, 0.6, 0.2, 0.8) if severity == "HIGH" else Color(0.2, 0.7, 0.9, 0.8))
	var bg_col = Color(0.12, 0.08, 0.1, 0.95) if severity == "CRITICAL" else Color(0.08, 0.11, 0.16, 0.95)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = bg_col
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 3
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = border_col
	card_style.content_margin_left = 10 if is_mob else 12
	card_style.content_margin_top = 8 if is_mob else 10
	card_style.content_margin_right = 10 if is_mob else 12
	card_style.content_margin_bottom = 8 if is_mob else 10
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var head_hbox = HBoxContainer.new()
	head_hbox.add_theme_constant_override("separation", 8)
	
	var badge_lbl = Label.new()
	badge_lbl.text = " #%d [%s PRIORITY] " % [priority_num, severity]
	badge_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 15)
	badge_lbl.add_theme_color_override("font_color", border_col)
	head_hbox.add_child(badge_lbl)

	var cat_lbl = Label.new()
	cat_lbl.text = "• " + str(rec.get("category", "SWING MECHANICS"))
	cat_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 15)
	cat_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	head_hbox.add_child(cat_lbl)
	vbox.add_child(head_hbox)

	var title_lbl = Label.new()
	title_lbl.text = str(rec.get("title", "Swing Flaw"))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 20 if is_mob else 21)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_lbl)

	# ── Action Button Row (Progressive Disclosure - Combined Data Comparison) ──
	var btn_flow = HFlowContainer.new()
	btn_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_flow.add_theme_constant_override("h_separation", 10 if is_mob else 12)
	btn_flow.add_theme_constant_override("v_separation", 10 if is_mob else 10)

	var btn_defs: Array[Dictionary] = [
		{"label": "📊 DATA COMPARISON", "color": Color(0.16, 0.48, 0.58), "modal": "data_comparison"},
		{"label": "🔍 EXPLAIN ISSUE", "color": Color(0.32, 0.38, 0.56), "modal": "explain"},
		{"label": "🏋️ DRILLS TO FIX", "color": Color(0.44, 0.32, 0.58), "modal": "drills"},
		{"label": "▶ VIDEO LINK", "color": Color(0.64, 0.24, 0.24), "modal": "video"}
	]

	for def in btn_defs:
		var btn = Button.new()
		btn.text = def["label"]
		# Large touch targets for phone screens and projector readability
		btn.custom_minimum_size = Vector2(165 if is_mob else 170, 52 if is_mob else 46)
		btn.add_theme_font_size_override("font_size", 16 if is_mob else 15)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_btn_style(btn, def["color"])
		btn.pressed.connect(_on_detail_button_pressed.bind(rec, def["modal"]))
		btn_flow.add_child(btn)

	vbox.add_child(btn_flow)

	card.add_child(vbox)
	return card


# =============================================================================
# DETAIL MODAL POPUP SYSTEM (PROGRESSIVE DISCLOSURE)
# =============================================================================

func _on_detail_button_pressed(rec: Dictionary, modal_type: String) -> void:
	var existing = get_node_or_null("DetailModal")
	if existing != null:
		InAppVideoPlayer.stop_all_players()
		existing.queue_free()

	var modal = _create_detail_modal(rec, modal_type)
	add_child(modal)
	UIFocusGuard.push_lock(modal)
	_setup_detail_modal_focus_navigation(modal)
	call_deferred("_setup_detail_modal_focus_navigation", modal)

	var primary_focus: Control = null
	if modal_type == "video":
		primary_focus = modal.find_child("BrowserBtn", true, false) as Control
		if primary_focus == null:
			primary_focus = modal.find_child("MobWatchBtn", true, false) as Control
		if primary_focus == null:
			primary_focus = modal.find_child("VideoPlaceholderFrame", true, false) as Control
	if primary_focus == null:
		primary_focus = modal.find_child("CloseButton", true, false) as Control
	if primary_focus == null:
		primary_focus = modal.find_child("FooterCloseButton", true, false) as Control
	if primary_focus != null and is_instance_valid(primary_focus):
		primary_focus.call_deferred("grab_focus")
	else:
		KeybindingManager.focus_first_control(modal)


func _setup_detail_modal_focus_navigation(modal: Control) -> void:
	if modal == null or not is_instance_valid(modal):
		return
	var close_btn: Button = modal.find_child("CloseButton", true, false) as Button
	var footer_btn: Button = modal.find_child("FooterCloseButton", true, false) as Button
	var scroll: ScrollContainer = modal.find_child("DetailScroll", true, false) as ScrollContainer
	var v_frame: Control = modal.find_child("VideoPlaceholderFrame", true, false) as Control

	var body_buttons: Array[Control] = []
	if scroll != null:
		_collect_detail_focusable_controls(scroll, body_buttons)

	if v_frame != null and v_frame.is_visible_in_tree() and v_frame.focus_mode != Control.FOCUS_NONE:
		if close_btn != null:
			close_btn.focus_neighbor_bottom = close_btn.get_path_to(v_frame)
			v_frame.focus_neighbor_top = v_frame.get_path_to(close_btn)
		if not body_buttons.is_empty():
			v_frame.focus_neighbor_bottom = v_frame.get_path_to(body_buttons[0])
			for i in range(body_buttons.size()):
				var b = body_buttons[i]
				var prev_b = body_buttons[(i - 1 + body_buttons.size()) % body_buttons.size()]
				var next_b = body_buttons[(i + 1) % body_buttons.size()]
				b.focus_neighbor_left = b.get_path_to(prev_b)
				b.focus_neighbor_right = b.get_path_to(next_b)
				b.focus_neighbor_top = b.get_path_to(v_frame)
				if footer_btn != null:
					b.focus_neighbor_bottom = b.get_path_to(footer_btn)
			if footer_btn != null:
				footer_btn.focus_neighbor_top = footer_btn.get_path_to(body_buttons[0])
				if close_btn != null:
					footer_btn.focus_neighbor_bottom = footer_btn.get_path_to(close_btn)
					close_btn.focus_neighbor_top = close_btn.get_path_to(footer_btn)
		else:
			if footer_btn != null:
				v_frame.focus_neighbor_bottom = v_frame.get_path_to(footer_btn)
				footer_btn.focus_neighbor_top = footer_btn.get_path_to(v_frame)
				if close_btn != null:
					footer_btn.focus_neighbor_bottom = footer_btn.get_path_to(close_btn)
					close_btn.focus_neighbor_top = close_btn.get_path_to(footer_btn)
	elif not body_buttons.is_empty():
		for i in range(body_buttons.size()):
			var b = body_buttons[i]
			var prev_b = body_buttons[(i - 1 + body_buttons.size()) % body_buttons.size()]
			var next_b = body_buttons[(i + 1) % body_buttons.size()]
			b.focus_neighbor_left = b.get_path_to(prev_b)
			b.focus_neighbor_right = b.get_path_to(next_b)
			if close_btn != null:
				b.focus_neighbor_top = b.get_path_to(close_btn)
			if footer_btn != null:
				b.focus_neighbor_bottom = b.get_path_to(footer_btn)

		if close_btn != null:
			close_btn.focus_neighbor_bottom = close_btn.get_path_to(body_buttons[0])
			if footer_btn != null:
				close_btn.focus_neighbor_top = close_btn.get_path_to(footer_btn)
				close_btn.focus_neighbor_left = close_btn.get_path_to(footer_btn)
				close_btn.focus_neighbor_right = close_btn.get_path_to(body_buttons[0])

		if footer_btn != null:
			footer_btn.focus_neighbor_top = footer_btn.get_path_to(body_buttons[0])
			if close_btn != null:
				footer_btn.focus_neighbor_bottom = footer_btn.get_path_to(close_btn)
				footer_btn.focus_neighbor_left = footer_btn.get_path_to(close_btn)
				footer_btn.focus_neighbor_right = footer_btn.get_path_to(body_buttons[0])
	else:
		if scroll != null:
			scroll.focus_mode = Control.FOCUS_ALL
			if close_btn != null:
				scroll.focus_neighbor_top = scroll.get_path_to(close_btn)
				close_btn.focus_neighbor_bottom = close_btn.get_path_to(scroll)
				if footer_btn != null:
					close_btn.focus_neighbor_top = close_btn.get_path_to(footer_btn)
					close_btn.focus_neighbor_left = close_btn.get_path_to(footer_btn)
					close_btn.focus_neighbor_right = close_btn.get_path_to(scroll)
			if footer_btn != null:
				scroll.focus_neighbor_bottom = scroll.get_path_to(footer_btn)
				footer_btn.focus_neighbor_top = footer_btn.get_path_to(scroll)
				if close_btn != null:
					footer_btn.focus_neighbor_bottom = footer_btn.get_path_to(close_btn)
					footer_btn.focus_neighbor_left = footer_btn.get_path_to(close_btn)
					footer_btn.focus_neighbor_right = footer_btn.get_path_to(scroll)
		elif close_btn != null and footer_btn != null:
			close_btn.focus_neighbor_bottom = close_btn.get_path_to(footer_btn)
			close_btn.focus_neighbor_top = close_btn.get_path_to(footer_btn)
			footer_btn.focus_neighbor_top = footer_btn.get_path_to(close_btn)
			footer_btn.focus_neighbor_bottom = footer_btn.get_path_to(close_btn)


func _collect_detail_focusable_controls(node: Node, out_list: Array[Control]) -> void:
	if node is Control:
		var c = node as Control
		if c.visible and c.focus_mode != Control.FOCUS_NONE:
			if c is Button or c is BaseButton:
				out_list.append(c)
	for ch in node.get_children():
		_collect_detail_focusable_controls(ch, out_list)


func _create_detail_modal(rec: Dictionary, modal_type: String) -> Control:
	var is_mob = _is_mobile_view()
	var vp_size = get_viewport_rect().size

	var root = Control.new()
	root.name = "DetailModal"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 50

	var dismiss_modal = func():
		InAppVideoPlayer.stop_all_players()
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == root:
			UIFocusGuard.pop_lock(true)
		root.queue_free()

	root.set_meta("on_focus_lock_popped", dismiss_modal)

	root.tree_exiting.connect(func():
		InAppVideoPlayer.stop_all_players()
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == root:
			UIFocusGuard.pop_lock(true)
	)

	# Semi-transparent backdrop dimmer (click to dismiss)
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.70)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			dismiss_modal.call()
	)
	root.add_child(dimmer)

	# Centered modal panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var is_video = (modal_type == "video")
	var panel = PanelContainer.new()
	# Generous sizing for mobile and large screens / projectors
	var panel_w = clamp(vp_size.x * 0.94, 320, 840) if is_mob else (clamp(vp_size.x * 0.72, 720, 920) if is_video else clamp(vp_size.x * 0.62, 460, 880))
	var panel_h = clamp(vp_size.y * 0.90, 360, 820) if is_mob else (clamp(vp_size.y * 0.88, 580, 780) if is_video else clamp(vp_size.y * 0.68, 300, 680))
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	ThemeManager.apply_modal_style(panel, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18 if is_mob else 22)
	margin.add_theme_constant_override("margin_right", 18 if is_mob else 22)
	margin.add_theme_constant_override("margin_top", 16 if is_mob else 20)
	margin.add_theme_constant_override("margin_bottom", 16 if is_mob else 20)
	panel.add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(outer_vbox)

	# ── Header ──
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_lbl = Label.new()
	title_lbl.text = _get_detail_modal_title(modal_type)
	title_lbl.add_theme_font_size_override("font_size", 21 if is_mob else 23)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "✖"
	close_btn.custom_minimum_size = Vector2(50 if is_mob else 46, 50 if is_mob else 46)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_btn_style(close_btn, Color(0.70, 0.22, 0.22))
	close_btn.pressed.connect(dismiss_modal)
	header.add_child(close_btn)

	outer_vbox.add_child(header)

	# Issue subtitle banner
	var issue_title = str(rec.get("title", ""))
	if issue_title != "":
		var sub_lbl = Label.new()
		sub_lbl.text = "Issue: " + issue_title
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 17)
		sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 0.98))
		outer_vbox.add_child(sub_lbl)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	outer_vbox.add_child(sep)

	# ── Scrollable Body ──
	var scroll = ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if is_video and not is_mob:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ThemeManager.apply_scroll_container_style(scroll, 28)

	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 14 if is_mob else 14)

	_populate_detail_content(content_vbox, rec, modal_type, is_mob)

	scroll.add_child(content_vbox)
	outer_vbox.add_child(scroll)

	# ── Footer Button for Quick Mobile / Remote Dismissal ──
	var footer_btn = Button.new()
	footer_btn.name = "FooterCloseButton"
	footer_btn.text = "Close"
	footer_btn.custom_minimum_size = Vector2(160, 50 if is_mob else 44)
	footer_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer_btn.add_theme_font_size_override("font_size", 16 if is_mob else 16)
	footer_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_btn_style(footer_btn, Color(0.25, 0.32, 0.42))
	footer_btn.pressed.connect(dismiss_modal)
	outer_vbox.add_child(footer_btn)

	return root


func _get_detail_modal_title(modal_type: String) -> String:
	match modal_type:
		"data_comparison":
			return "📊 YOUR DATA VS PRO BENCHMARK"
		"explain":
			return "🔍 ISSUE EXPLANATION"
		"drills":
			return "🏋️ DRILLS TO FIX"
		"video":
			return "▶ VIDEO & VISUAL GUIDE"
		_:
			return "DETAILS"


func _populate_detail_content(container: VBoxContainer, rec: Dictionary, modal_type: String, is_mob: bool) -> void:
	match modal_type:
		"data_comparison":
			_build_data_comparison_content(container, rec, is_mob)
		"explain":
			_build_explain_content(container, rec, is_mob)
		"drills":
			_build_drills_content(container, rec, is_mob)
		"video":
			_build_video_content(container, rec, is_mob)


func _build_data_comparison_content(container: VBoxContainer, rec: Dictionary, is_mob: bool) -> void:
	if rec.has("comparison_table") and not (rec["comparison_table"] as Array).is_empty():
		# ── Skill Baseline Header ──
		var base_panel = PanelContainer.new()
		base_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var base_style = StyleBoxFlat.new()
		base_style.bg_color = Color(0.06, 0.12, 0.18, 0.95)
		base_style.corner_radius_top_left = 8
		base_style.corner_radius_top_right = 8
		base_style.corner_radius_bottom_left = 8
		base_style.corner_radius_bottom_right = 8
		base_style.border_width_left = 3
		base_style.border_color = Color(0.25, 0.65, 0.95, 0.9)
		base_style.content_margin_left = 14
		base_style.content_margin_top = 10
		base_style.content_margin_right = 14
		base_style.content_margin_bottom = 10
		base_panel.add_theme_stylebox_override("panel", base_style)

		var base_hbox = HBoxContainer.new()
		base_hbox.add_theme_constant_override("separation", 10)

		var base_icon = Label.new()
		base_icon.text = "🎯"
		base_icon.add_theme_font_size_override("font_size", 20 if is_mob else 22)
		base_hbox.add_child(base_icon)

		var base_vbox = VBoxContainer.new()
		base_vbox.add_theme_constant_override("separation", 2)
		base_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var base_title = Label.new()
		base_title.text = "SKILL BASELINE: " + str(rec.get("skill_level_display", "Mid Handicap (10–19 HCP)")).to_upper()
		base_title.add_theme_font_size_override("font_size", 14 if is_mob else 15)
		base_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
		base_vbox.add_child(base_title)

		var base_note = Label.new()
		base_note.text = "Benchmarks dynamically calibrated to your player profile handicap tier."
		base_note.add_theme_font_size_override("font_size", 12 if is_mob else 13)
		base_note.add_theme_color_override("font_color", Color(0.70, 0.85, 0.98))
		base_vbox.add_child(base_note)

		base_hbox.add_child(base_vbox)
		base_panel.add_child(base_hbox)
		container.add_child(base_panel)

		# ── Multi-Row Ballistic Scorecard Table ──
		var table_panel = PanelContainer.new()
		table_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var table_style = StyleBoxFlat.new()
		table_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
		table_style.corner_radius_top_left = 8
		table_style.corner_radius_top_right = 8
		table_style.corner_radius_bottom_left = 8
		table_style.corner_radius_bottom_right = 8
		table_style.border_width_left = 1
		table_style.border_width_top = 1
		table_style.border_width_right = 1
		table_style.border_width_bottom = 1
		table_style.border_color = Color(0.18, 0.28, 0.40, 0.8)
		table_style.content_margin_left = 12 if is_mob else 16
		table_style.content_margin_top = 12 if is_mob else 14
		table_style.content_margin_right = 12 if is_mob else 16
		table_style.content_margin_bottom = 12 if is_mob else 14
		table_panel.add_theme_stylebox_override("panel", table_style)

		var table_vbox = VBoxContainer.new()
		table_vbox.add_theme_constant_override("separation", 8)

		var header_row = HBoxContainer.new()
		header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_theme_constant_override("separation", 8)

		var h_metric = Label.new()
		h_metric.text = "METRIC"
		h_metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_metric.add_theme_font_size_override("font_size", 12 if is_mob else 13)
		h_metric.add_theme_color_override("font_color", Color(0.65, 0.78, 0.90))
		header_row.add_child(h_metric)

		var h_your = Label.new()
		h_your.text = "YOUR SHOT"
		h_your.custom_minimum_size = Vector2(90 if is_mob else 120, 0)
		h_your.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_your.add_theme_font_size_override("font_size", 12 if is_mob else 13)
		h_your.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
		header_row.add_child(h_your)

		var h_target = Label.new()
		h_target.text = "TARGET WINDOW"
		h_target.custom_minimum_size = Vector2(120 if is_mob else 150, 0)
		h_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_target.add_theme_font_size_override("font_size", 12 if is_mob else 13)
		h_target.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
		header_row.add_child(h_target)

		var h_status = Label.new()
		h_status.text = "STATUS"
		h_status.custom_minimum_size = Vector2(85 if is_mob else 110, 0)
		h_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_status.add_theme_font_size_override("font_size", 12 if is_mob else 13)
		h_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
		header_row.add_child(h_status)

		table_vbox.add_child(header_row)

		var h_sep = HSeparator.new()
		h_sep.add_theme_constant_override("separation", 4)
		table_vbox.add_child(h_sep)

		var comp_table = rec["comparison_table"] as Array
		for row_data in comp_table:
			var r_row = HBoxContainer.new()
			r_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_row.add_theme_constant_override("separation", 8)

			var m_lbl = Label.new()
			m_lbl.text = str(row_data.get("metric", ""))
			m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 15)
			m_lbl.add_theme_color_override("font_color", Color.WHITE)
			r_row.add_child(m_lbl)

			var y_lbl = Label.new()
			y_lbl.text = str(row_data.get("player", "---"))
			y_lbl.custom_minimum_size = Vector2(90 if is_mob else 120, 0)
			y_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			y_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 15)
			y_lbl.add_theme_color_override("font_color", Color.WHITE)
			r_row.add_child(y_lbl)

			var t_lbl = Label.new()
			t_lbl.text = str(row_data.get("target", "---"))
			t_lbl.custom_minimum_size = Vector2(120 if is_mob else 150, 0)
			t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			t_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 14)
			t_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70))
			r_row.add_child(t_lbl)

			var s_badge = _create_status_pill(str(row_data.get("status", "GOOD")), is_mob)
			s_badge.custom_minimum_size = Vector2(85 if is_mob else 110, 24)
			r_row.add_child(s_badge)

			table_vbox.add_child(r_row)

			if row_data.has("player_num") and row_data.has("target_min") and row_data.has("target_max"):
				var gauge = AnalyticsVisualWidgetsScript.create_bullet_gauge(
					"",
					float(row_data["player_num"]),
					float(row_data["target_min"]),
					float(row_data["target_max"]),
					float(row_data.get("scale_min", float(row_data["target_min"]) - 5.0)),
					float(row_data.get("scale_max", float(row_data["target_max"]) + 5.0)),
					str(row_data.get("unit", "")),
					Vector2(180, 14),
					false
				)
				table_vbox.add_child(gauge)

		table_panel.add_child(table_vbox)
		container.add_child(table_panel)

	else:
		# Fallback to 2-card comparison
		var comp_flow = HFlowContainer.new()
		comp_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		comp_flow.add_theme_constant_override("h_separation", 14)
		comp_flow.add_theme_constant_override("v_separation", 14)

		# 🔴 Your Shot Card
		var your_panel = PanelContainer.new()
		your_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		your_panel.custom_minimum_size = Vector2(260, 0)
		var your_style = StyleBoxFlat.new()
		your_style.bg_color = Color(0.12, 0.06, 0.08, 0.95)
		your_style.corner_radius_top_left = 8
		your_style.corner_radius_top_right = 8
		your_style.corner_radius_bottom_left = 8
		your_style.corner_radius_bottom_right = 8
		your_style.border_width_left = 4
		your_style.border_color = Color(1.0, 0.40, 0.40, 0.95)
		your_style.content_margin_left = 16
		your_style.content_margin_top = 14
		your_style.content_margin_right = 16
		your_style.content_margin_bottom = 14
		your_panel.add_theme_stylebox_override("panel", your_style)

		var your_vbox = VBoxContainer.new()
		your_vbox.add_theme_constant_override("separation", 8)

		var your_title = Label.new()
		your_title.text = "🔴 YOUR SHOT"
		your_title.add_theme_font_size_override("font_size", 18 if is_mob else 18)
		your_title.add_theme_color_override("font_color", Color(1.0, 0.70, 0.70))
		your_vbox.add_child(your_title)

		var player_val = str(rec.get("player_val", "---"))
		var parts = player_val.split("|")
		for part in parts:
			var part_str = part.strip_edges()
			if part_str == "" or part_str == "---" or part_str == "N/A":
				continue
			# Filter out dummy/unretrieved AoA
			if ("aoa" in part_str.to_lower() or "attack" in part_str.to_lower()) and ("0.0" in part_str or "n/a" in part_str.to_lower() or "---" in part_str):
				continue
			# Filter out dummy/unretrieved Smash
			if "smash" in part_str.to_lower() and ("0.0" in part_str or "n/a" in part_str.to_lower() or "---" in part_str):
				continue
			# Filter out dummy Path
			if "path: 0.0" in part_str.to_lower() and not (shot_data.has("ClubPath") or shot_data.has("Path") or shot_data.has("RawClubPath")):
				continue
			var val_lbl = Label.new()
			val_lbl.text = "• " + part_str
			val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			val_lbl.add_theme_font_size_override("font_size", 17 if is_mob else 18)
			val_lbl.add_theme_color_override("font_color", Color.WHITE)
			your_vbox.add_child(val_lbl)

		your_panel.add_child(your_vbox)
		comp_flow.add_child(your_panel)

		# 🟢 Benchmark Card
		var pro_panel = PanelContainer.new()
		pro_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pro_panel.custom_minimum_size = Vector2(260, 0)
		var pro_style = StyleBoxFlat.new()
		pro_style.bg_color = Color(0.04, 0.11, 0.07, 0.95)
		pro_style.corner_radius_top_left = 8
		pro_style.corner_radius_top_right = 8
		pro_style.corner_radius_bottom_left = 8
		pro_style.corner_radius_bottom_right = 8
		pro_style.border_width_left = 4
		pro_style.border_color = Color(0.35, 0.90, 0.55, 0.95)
		pro_style.content_margin_left = 16
		pro_style.content_margin_top = 14
		pro_style.content_margin_right = 16
		pro_style.content_margin_bottom = 14
		pro_panel.add_theme_stylebox_override("panel", pro_style)

		var pro_vbox = VBoxContainer.new()
		pro_vbox.add_theme_constant_override("separation", 8)

		var pro_title = Label.new()
		pro_title.text = "🟢 TARGET BENCHMARK"
		pro_title.add_theme_font_size_override("font_size", 18 if is_mob else 18)
		pro_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70))
		pro_vbox.add_child(pro_title)

		var bench_lbl = Label.new()
		var bench_text = str(rec.get("benchmark_val", "---"))
		var has_aoa_in_shot = (shot_data.has("AttackAngle") or shot_data.has("AngleOfAttack")) and abs(float(str(shot_data.get("AttackAngle", shot_data.get("AngleOfAttack", 0.0))).replace("+", "").replace("°", ""))) >= 0.1
		if not has_aoa_in_shot and "AoA" in bench_text:
			bench_text = bench_text.replace("| -1.0° to -3.0° AoA", "").replace("| +2.0° to +5.0° AoA", "").strip_edges()
		bench_lbl.text = bench_text
		bench_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bench_lbl.add_theme_font_size_override("font_size", 17 if is_mob else 18)
		bench_lbl.add_theme_color_override("font_color", Color.WHITE)
		pro_vbox.add_child(bench_lbl)

		pro_panel.add_child(pro_vbox)
		comp_flow.add_child(pro_panel)
		container.add_child(comp_flow)

	# ── Launch Impact / Consequence ──
	var launch_effect = str(rec.get("launch_effect", ""))
	if launch_effect != "":
		var effect_panel = PanelContainer.new()
		var eff_style = StyleBoxFlat.new()
		eff_style.bg_color = Color(0.08, 0.09, 0.13, 0.95)
		eff_style.corner_radius_top_left = 8
		eff_style.corner_radius_top_right = 8
		eff_style.corner_radius_bottom_left = 8
		eff_style.corner_radius_bottom_right = 8
		eff_style.border_width_left = 3
		eff_style.border_color = Color(1.0, 0.85, 0.40, 0.9)
		eff_style.content_margin_left = 16
		eff_style.content_margin_top = 12
		eff_style.content_margin_right = 16
		eff_style.content_margin_bottom = 12
		effect_panel.add_theme_stylebox_override("panel", eff_style)

		var eff_vbox = VBoxContainer.new()
		eff_vbox.add_theme_constant_override("separation", 6)

		var eff_head = Label.new()
		eff_head.text = "⚡ Launch Consequence & Dispersion"
		eff_head.add_theme_font_size_override("font_size", 17 if is_mob else 17)
		eff_head.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
		eff_vbox.add_child(eff_head)

		var eff_lbl = Label.new()
		eff_lbl.text = launch_effect
		eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 16)
		eff_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
		eff_vbox.add_child(eff_lbl)

		effect_panel.add_child(eff_vbox)
		container.add_child(effect_panel)

	var loss_info: Dictionary = rec.get("distance_loss_breakdown", {}) if typeof(rec.get("distance_loss_breakdown", null)) == TYPE_DICTIONARY else {}
	if not loss_info.is_empty() and float(loss_info.get("total_lost_yards", 0.0)) >= 3.0:
		var loss_panel = PanelContainer.new()
		var loss_style = StyleBoxFlat.new()
		loss_style.bg_color = Color(0.11, 0.08, 0.07, 0.95)
		loss_style.corner_radius_top_left = 8
		loss_style.corner_radius_top_right = 8
		loss_style.corner_radius_bottom_left = 8
		loss_style.corner_radius_bottom_right = 8
		loss_style.border_width_left = 3
		loss_style.border_color = Color(0.98, 0.52, 0.30, 0.9)
		loss_style.content_margin_left = 14
		loss_style.content_margin_top = 8
		loss_style.content_margin_right = 14
		loss_style.content_margin_bottom = 8
		loss_panel.add_theme_stylebox_override("panel", loss_style)

		var l_lbl = Label.new()
		l_lbl.text = "📏 Missing Yards Breakdown: " + str(loss_info.get("summary", ""))
		l_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l_lbl.add_theme_font_size_override("font_size", 14)
		l_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.56))
		loss_panel.add_child(l_lbl)
		container.add_child(loss_panel)


func _create_status_pill(status_text: String, is_mob: bool) -> PanelContainer:
	var pill = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	var fg_col = Color.WHITE
	var display_txt = status_text
	match status_text.to_upper():
		"OPTIMAL":
			style.bg_color = Color(0.12, 0.35, 0.18, 0.95)
			style.border_color = Color(0.3, 0.85, 0.45, 0.9)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			fg_col = Color(0.4, 0.95, 0.6)
			display_txt = "🟢 OPTIMAL"
		"GOOD":
			style.bg_color = Color(0.10, 0.25, 0.38, 0.95)
			style.border_color = Color(0.3, 0.70, 0.95, 0.9)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			fg_col = Color(0.45, 0.85, 1.0)
			display_txt = "🔵 GOOD"
		"SUB-OPTIMAL":
			style.bg_color = Color(0.35, 0.26, 0.08, 0.95)
			style.border_color = Color(0.95, 0.75, 0.25, 0.9)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			fg_col = Color(1.0, 0.85, 0.4)
			display_txt = "🟡 SUB-OPT"
		"CRITICAL":
			style.bg_color = Color(0.38, 0.10, 0.12, 0.95)
			style.border_color = Color(0.95, 0.35, 0.35, 0.9)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			fg_col = Color(1.0, 0.5, 0.5)
			display_txt = "🔴 CRITICAL"
		_:
			style.bg_color = Color(0.15, 0.18, 0.22, 0.95)
			fg_col = Color(0.7, 0.75, 0.8)
			display_txt = status_text

	style.content_margin_left = 6
	style.content_margin_top = 2
	style.content_margin_right = 6
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = display_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11 if is_mob else 12)
	lbl.add_theme_color_override("font_color", fg_col)
	pill.add_child(lbl)
	return pill


func _build_explain_content(container: VBoxContainer, rec: Dictionary, is_mob: bool) -> void:
	if rec.has("four_tier_diagnosis") and not (rec["four_tier_diagnosis"] as Dictionary).is_empty():
		var diag: Dictionary = rec["four_tier_diagnosis"]

		# Tier 1: Observation
		var obs_text = str(diag.get("observation", ""))
		if not obs_text.is_empty():
			container.add_child(_create_explain_card("🔬 1. WHAT THE DATA SHOWS (Observation)", obs_text, Color(0.35, 0.85, 1.0), is_mob))

		# Tier 2: Launch Impact
		var imp_text = str(diag.get("impact", ""))
		if not imp_text.is_empty():
			container.add_child(_create_explain_card("⚡ 2. LAUNCH FLIGHT IMPACT (Impact & Lost Distance)", imp_text, Color(1.0, 0.85, 0.40), is_mob))

		# Tier 3: Root Cause & Biomechanics
		var cause_text = str(diag.get("cause", ""))
		if not cause_text.is_empty():
			container.add_child(_create_explain_card("🦴 3. ROOT CAUSE & BIOMECHANICS (Underlying Fault)", cause_text, Color(1.0, 0.45, 0.45), is_mob))

		# Tier 4: Corrective Prescription
		var fix_text = str(diag.get("prescription", ""))
		if not fix_text.is_empty():
			container.add_child(_create_explain_card("💡 4. CORRECTIVE PRESCRIPTION (Actionable Fix)", fix_text, Color(0.35, 1.0, 0.65), is_mob))
	else:
		var cam_flaw = str(rec.get("camera_flaw", ""))
		if cam_flaw != "":
			container.add_child(_create_explain_card("🦴 Biomechanics & Camera Observation", cam_flaw, Color(0.35, 0.85, 1.0), is_mob))

		var launch_effect = str(rec.get("launch_effect", ""))
		if launch_effect != "":
			container.add_child(_create_explain_card("⚡ Launch Symptom", launch_effect, Color(1.0, 0.85, 0.40), is_mob))

		var fix_instruction = str(rec.get("fix_instruction", ""))
		if fix_instruction != "":
			container.add_child(_create_explain_card("💡 How to Correct It", fix_instruction, Color(0.35, 1.0, 0.65), is_mob))


func _create_explain_card(header_title: String, text_content: String, border_col: Color, is_mob: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.13, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 4
	style.border_color = border_col
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	var head = Label.new()
	head.text = header_title
	head.add_theme_font_size_override("font_size", 17 if is_mob else 18)
	head.add_theme_color_override("font_color", border_col)
	vb.add_child(head)

	var lbl = Label.new()
	lbl.text = text_content
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15 if is_mob else 16)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	vb.add_child(lbl)

	panel.add_child(vb)
	return panel


func _build_drills_content(container: VBoxContainer, rec: Dictionary, is_mob: bool) -> void:
	var drill_str = str(rec.get("drill", ""))
	if drill_str != "":
		var drill_panel = PanelContainer.new()
		var drill_style = StyleBoxFlat.new()
		drill_style.bg_color = Color(0.10, 0.06, 0.17, 0.95)
		drill_style.corner_radius_top_left = 8
		drill_style.corner_radius_top_right = 8
		drill_style.corner_radius_bottom_left = 8
		drill_style.corner_radius_bottom_right = 8
		drill_style.border_width_left = 4
		drill_style.border_color = Color(0.80, 0.55, 1.0, 0.95)
		drill_style.content_margin_left = 16
		drill_style.content_margin_top = 14
		drill_style.content_margin_right = 16
		drill_style.content_margin_bottom = 14
		drill_panel.add_theme_stylebox_override("panel", drill_style)

		var d_vbox = VBoxContainer.new()
		d_vbox.add_theme_constant_override("separation", 8)

		var header_lbl = Label.new()
		header_lbl.text = "🏋️ Recommended Practice Drill"
		header_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 18)
		header_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
		d_vbox.add_child(header_lbl)

		var drill_lbl = Label.new()
		drill_lbl.text = drill_str
		drill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		drill_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 16)
		drill_lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 1.0))
		d_vbox.add_child(drill_lbl)

		drill_panel.add_child(d_vbox)
		container.add_child(drill_panel)
	else:
		var no_drill = Label.new()
		no_drill.text = "Focus on repeating clean baseline swing tempo."
		no_drill.add_theme_font_size_override("font_size", 16)
		no_drill.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		container.add_child(no_drill)

	var fix_instruction = str(rec.get("fix_instruction", ""))
	if fix_instruction != "":
		var cue_panel = PanelContainer.new()
		var cue_style = StyleBoxFlat.new()
		cue_style.bg_color = Color(0.05, 0.10, 0.08, 0.95)
		cue_style.corner_radius_top_left = 8
		cue_style.corner_radius_top_right = 8
		cue_style.corner_radius_bottom_left = 8
		cue_style.corner_radius_bottom_right = 8
		cue_style.border_width_left = 3
		cue_style.border_color = Color(0.35, 0.90, 0.60, 0.85)
		cue_style.content_margin_left = 16
		cue_style.content_margin_top = 10
		cue_style.content_margin_right = 16
		cue_style.content_margin_bottom = 10
		cue_panel.add_theme_stylebox_override("panel", cue_style)

		var cue_vbox = VBoxContainer.new()
		cue_vbox.add_theme_constant_override("separation", 4)

		var cue_head = Label.new()
		cue_head.text = "💡 Key Swing Cue"
		cue_head.add_theme_font_size_override("font_size", 17 if is_mob else 17)
		cue_head.add_theme_color_override("font_color", Color(0.40, 1.0, 0.68))
		cue_vbox.add_child(cue_head)

		var fix_lbl = Label.new()
		fix_lbl.text = fix_instruction
		fix_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fix_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 15)
		fix_lbl.add_theme_color_override("font_color", Color(0.85, 0.96, 0.88))
		cue_vbox.add_child(fix_lbl)

		cue_panel.add_child(cue_vbox)
		container.add_child(cue_panel)

	# ── 3-Stage Progressive Drill Plan & Proof ──
	var stages: Array = rec.get("drill_stages", []) if typeof(rec.get("drill_stages", null)) == TYPE_ARRAY else []
	if not stages.is_empty():
		var prog_panel = PanelContainer.new()
		var prog_style = StyleBoxFlat.new()
		prog_style.bg_color = Color(0.06, 0.09, 0.14, 0.95)
		prog_style.corner_radius_top_left = 8
		prog_style.corner_radius_top_right = 8
		prog_style.corner_radius_bottom_left = 8
		prog_style.corner_radius_bottom_right = 8
		prog_style.border_width_left = 3
		prog_style.border_color = Color(0.32, 0.72, 0.98, 0.85)
		prog_style.content_margin_left = 14
		prog_style.content_margin_top = 10
		prog_style.content_margin_right = 14
		prog_style.content_margin_bottom = 10
		prog_panel.add_theme_stylebox_override("panel", prog_style)

		var p_vbox = VBoxContainer.new()
		p_vbox.add_theme_constant_override("separation", 6)

		var p_head = Label.new()
		p_head.text = "🪜 3-Stage Progression Ladder"
		p_head.add_theme_font_size_override("font_size", 16)
		p_head.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		p_vbox.add_child(p_head)

		for st in stages:
			if st is Dictionary:
				var s_lbl = Label.new()
				s_lbl.text = "Stage %s — %s: %s (%s)" % [str(st.get("stage", "")), str(st.get("name", "")), str(st.get("constraint", "")), str(st.get("reps", ""))]
				s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				s_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 14)
				s_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
				p_vbox.add_child(s_lbl)

		var proof_txt: String = str(rec.get("monitor_proof", ""))
		if not proof_txt.is_empty():
			var pr_lbl = Label.new()
			pr_lbl.text = "📈 Launch Monitor Proof: " + proof_txt
			pr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pr_lbl.add_theme_font_size_override("font_size", 13)
			pr_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.70))
			p_vbox.add_child(pr_lbl)

		var watch_txt: String = str(rec.get("watch_out_for", ""))
		if not watch_txt.is_empty():
			var wt_lbl = Label.new()
			wt_lbl.text = "⚠️ Avoid Over-Correction: " + watch_txt
			wt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wt_lbl.add_theme_font_size_override("font_size", 13)
			wt_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
			p_vbox.add_child(wt_lbl)

		var grad_txt: String = str(rec.get("graduation_target", ""))
		if not grad_txt.is_empty():
			var gr_lbl = Label.new()
			gr_lbl.text = "✅ Graduation Goal: " + grad_txt
			gr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			gr_lbl.add_theme_font_size_override("font_size", 13)
			gr_lbl.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
			p_vbox.add_child(gr_lbl)

		prog_panel.add_child(p_vbox)
		container.add_child(prog_panel)


func _build_video_content(container: VBoxContainer, rec: Dictionary, is_mob: bool) -> void:
	var video_url = str(rec.get("video_url", ""))
	if video_url != "":
		var player = InAppVideoPlayer.new()
		player.setup(
			video_url,
			str(rec.get("video_title", "HackMotion Video Drill Tutorial")),
			str(rec.get("drill", "")),
			str(rec.get("benchmark_val", rec.get("category", ""))),
			is_mob
		)
		container.add_child(player)
	else:
		var note_panel = PanelContainer.new()
		var note_style = StyleBoxFlat.new()
		note_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
		note_style.corner_radius_top_left = 8
		note_style.corner_radius_top_right = 8
		note_style.corner_radius_bottom_left = 8
		note_style.corner_radius_bottom_right = 8
		note_style.border_width_left = 4
		note_style.border_color = Color(0.8, 0.35, 0.35, 0.85)
		note_style.content_margin_left = 16
		note_style.content_margin_top = 14
		note_style.content_margin_right = 16
		note_style.content_margin_bottom = 14
		note_panel.add_theme_stylebox_override("panel", note_style)

		var note_vbox = VBoxContainer.new()
		note_vbox.add_theme_constant_override("separation", 8)

		var note_head = Label.new()
		note_head.text = "📹 Video Guide"
		note_head.add_theme_font_size_override("font_size", 18 if is_mob else 18)
		note_head.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
		note_vbox.add_child(note_head)

		var note_msg = Label.new()
		note_msg.text = "Video lessons for this specific flaw will be linked in an upcoming update."
		note_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_msg.add_theme_font_size_override("font_size", 16)
		note_msg.add_theme_color_override("font_color", Color.WHITE)
		note_vbox.add_child(note_msg)

		var tip_msg = Label.new()
		tip_msg.text = "Tip: If Golfer Camera is active, use the left video pane to review your slow-motion swing replay and skeleton wireframe at address and impact."
		tip_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_msg.add_theme_font_size_override("font_size", 14)
		tip_msg.add_theme_color_override("font_color", Color(0.70, 0.85, 0.95))
		note_vbox.add_child(tip_msg)

		note_panel.add_child(note_vbox)
		container.add_child(note_panel)

func _apply_btn_style(btn: Button, bg_col: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6

	var hover_style = style.duplicate()
	hover_style.bg_color = bg_col.lightened(0.15)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = bg_col.darkened(0.15)

	var focus_style = style.duplicate()
	focus_style.border_width_left = 3
	focus_style.border_width_top = 3
	focus_style.border_width_right = 3
	focus_style.border_width_bottom = 3
	focus_style.border_color = Color(0.35, 0.82, 1.0, 0.95)

	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", focus_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
