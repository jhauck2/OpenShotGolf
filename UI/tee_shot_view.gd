extends Control

const TeeShotFlightOverlayScript = preload("res://UI/tee_shot_overlay.gd")

signal split_started
signal split_closed
signal popout_changed(is_popped_out: bool)

const SIZE_TRANSITION_DURATION := 0.8
const FLIGHT_VIEW_RENDER_SHRINK := 2
const CAMERA_TRAIL_DISTANCE := 150.0
const CAMERA_BASE_HEIGHT := 70.0
const CAMERA_LOOK_DISTANCE := 140.0
const CAMERA_LOOK_HEIGHT := 18.0
const CAMERA_FIELD_OF_VIEW := 50.0
const TRACER_HEIGHT_OFFSET := 0.3
const MAIN_VIEW_FINAL_WIDTH_RATIO := 2.0 / 3.0
const DEFAULT_POPOUT_SIZE := Vector2i(480, 640)
const MIN_POPOUT_SIZE := Vector2i(280, 340)

var _viewport: SubViewport
var _aspect_container: AspectRatioContainer
var _viewport_container: SubViewportContainer
var _main_view_clip: Control
var _main_viewport_container: SubViewportContainer
var _main_viewport: SubViewport
var _main_view_camera: Camera3D
var _shot_panel: PanelContainer
var _layout: VBoxContainer
var _header_bar: HBoxContainer
var _title_label: Label
var _popout_button: Button
var _popout_window: Window = null
var _is_popped_out := false
var _shot_active := false
var _allow_detach_for_test := false
var _panel_style: StyleBoxFlat
var _main_camera: Camera3D
var _main_camera_cull_mask := 0
var _main_camera_render_suppressed := false
var _camera: Camera3D
var _flight_overlay: Control
var _map_size := Vector2.ZERO
var _map_position := Vector2.ZERO
var _split_mode := false
var _split_progress := 0.0
var _split_tween: Tween


static func is_detach_supported() -> bool:
	var os_name := OS.get_name().to_lower()
	if os_name == "ios" or os_name == "android":
		return false
	if OS.has_feature("mobile"):
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return false
	return true


func is_shot_active() -> bool:
	return _shot_active


func is_popped_out() -> bool:
	return _is_popped_out


func _can_detach() -> bool:
	return _allow_detach_for_test or is_detach_supported()


func _ready() -> void:
	name = "TeeShotView"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	_main_view_clip = Control.new()
	_main_view_clip.name = "MainViewClip"
	_main_view_clip.clip_contents = true
	_main_view_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main_view_clip)

	_main_viewport_container = SubViewportContainer.new()
	_main_viewport_container.name = "MainViewViewportContainer"
	_main_viewport_container.stretch = true
	_main_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_view_clip.add_child(_main_viewport_container)

	_main_viewport = SubViewport.new()
	_main_viewport.name = "MainViewViewport"
	_main_viewport.own_world_3d = false
	_main_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_main_viewport_container.add_child(_main_viewport)

	_main_view_camera = Camera3D.new()
	_main_view_camera.name = "MainViewCamera"
	_main_view_camera.current = true
	_main_viewport.add_child(_main_view_camera)

	_shot_panel = PanelContainer.new()
	_shot_panel.name = "ShotPanel"
	_shot_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_shot_panel.clip_contents = true
	add_child(_shot_panel)

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.035, 0.055, 0.045, 0.94)
	_panel_style.border_color = Color(0.82, 0.78, 0.56, 0.95)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(10)
	_panel_style.content_margin_left = 6.0
	_panel_style.content_margin_right = 6.0
	_panel_style.content_margin_top = 6.0
	_panel_style.content_margin_bottom = 6.0
	_shot_panel.add_theme_stylebox_override("panel", _panel_style)

	_layout = VBoxContainer.new()
	_layout.name = "Layout"
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 4)
	_shot_panel.add_child(_layout)

	_header_bar = HBoxContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_theme_constant_override("separation", 6)
	_layout.add_child(_header_bar)

	_title_label = Label.new()
	_title_label.text = "TEE SHOT  |  FLIGHT VIEW"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.78))
	_title_label.add_theme_constant_override("outline_size", 3)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_header_bar.add_child(_title_label)

	_popout_button = Button.new()
	_popout_button.name = "PopoutButton"
	_popout_button.text = "↗ Pop Out"
	_popout_button.tooltip_text = "Pop out Tee Shot View into a separate draggable window"
	_popout_button.focus_mode = Control.FOCUS_NONE
	_popout_button.custom_minimum_size = Vector2(88, 28)
	_popout_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_popout_button()
	_popout_button.pressed.connect(_on_popout_button_pressed)
	_popout_button.visible = _can_detach()
	_header_bar.add_child(_popout_button)

	_aspect_container = AspectRatioContainer.new()
	_aspect_container.name = "ShotAspectContainer"
	_aspect_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aspect_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aspect_container.ratio = 1.0
	_layout.add_child(_aspect_container)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "ShotViewportContainer"
	_viewport_container.custom_minimum_size = Vector2.ONE
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.stretch_shrink = FLIGHT_VIEW_RENDER_SHRINK
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.clip_contents = true
	_aspect_container.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.msaa_3d = SubViewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.name = "TeeShotCamera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = CAMERA_FIELD_OF_VIEW
	_camera.cull_mask = 1 << 0
	_viewport.add_child(_camera)
	_camera.make_current()

	_flight_overlay = TeeShotFlightOverlayScript.new()
	_flight_overlay.name = "TeeShotFlightOverlay"
	_flight_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight_overlay.clip_contents = true
	_flight_overlay.z_index = 10
	_viewport_container.add_child(_flight_overlay)


func set_minimap_rect(minimap_rect: Rect2) -> void:
	_map_size = minimap_rect.size
	_map_position = minimap_rect.position
	if _is_popped_out:
		return
	if not _split_mode:
		position = _map_position
		if not visible:
			size = _map_size
		_shot_panel.position = Vector2.ZERO
		_shot_panel.size = _map_size
	if _viewport != null:
		_aspect_container.ratio = _map_size.x / maxf(1.0, _map_size.y)


func set_main_camera(camera: Camera3D) -> void:
	if _main_camera == camera:
		return
	_restore_main_camera_rendering()
	_main_camera = camera
	_sync_main_camera()


func prepare_for_shot(start_pos: Vector3, current_pos: Vector3, target_pos: Vector3) -> void:
	show_shot(start_pos, current_pos, target_pos)
	var opening_tween := _split_tween
	if opening_tween != null:
		await opening_tween.finished


func show_shot(start_pos: Vector3, _current_pos: Vector3, target_pos: Vector3) -> void:
	_shot_active = true
	_stop_split_transition()
	_flight_overlay.call("clear_flight_path")
	_position_camera_for_shot(start_pos, _current_pos, target_pos)
	if _should_use_popout():
		pop_out(false)
		return
	_enter_split_mode(true)


func _enter_split_mode(animate: bool) -> void:
	_split_mode = true
	visible = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_split_progress = 0.0 if animate else 1.0
	_set_full_view_style(true)
	_main_view_clip.visible = true
	_main_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_update_split_layout()
	_viewport_container.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_shot_panel.visible = true
	_sync_main_camera()
	_suppress_main_camera_rendering()
	split_started.emit()
	if animate:
		_split_tween = create_tween()
		_split_tween.set_trans(Tween.TRANS_CUBIC)
		_split_tween.set_ease(Tween.EASE_IN_OUT)
		_split_tween.tween_method(_set_split_progress, 0.0, 1.0, SIZE_TRANSITION_DURATION)
		_split_tween.tween_callback(_finish_split_open)


func _position_camera_for_shot(start_pos: Vector3, _current_pos: Vector3, target_pos: Vector3) -> void:
	if _camera == null:
		return

	var shot_direction := target_pos - start_pos
	shot_direction.y = 0.0
	if shot_direction.length_squared() < 0.01:
		shot_direction = _current_pos - start_pos
		shot_direction.y = 0.0
	if shot_direction.length_squared() < 0.01:
		shot_direction = Vector3.FORWARD
	shot_direction = shot_direction.normalized()

	var camera_position := start_pos - shot_direction * CAMERA_TRAIL_DISTANCE + Vector3.UP * CAMERA_BASE_HEIGHT
	var look_target := start_pos + shot_direction * CAMERA_LOOK_DISTANCE + Vector3.UP * CAMERA_LOOK_HEIGHT

	_camera.global_position = camera_position
	_camera.look_at(look_target, Vector3.UP)


func _set_split_progress(progress: float) -> void:
	_split_progress = progress
	_update_split_layout()


func _update_split_layout() -> void:
	if not _split_mode:
		return
	var screen_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen_size
	var main_view_width := lerpf(screen_size.x, screen_size.x * MAIN_VIEW_FINAL_WIDTH_RATIO, _split_progress)
	var tee_view_width := screen_size.x - main_view_width
	_main_view_clip.position = Vector2.ZERO
	_main_view_clip.size = Vector2(main_view_width, screen_size.y)
	_main_viewport.size = Vector2i(maxi(1, int(round(main_view_width))), maxi(1, int(round(screen_size.y))))
	_main_viewport_container.size = _main_view_clip.size
	_shot_panel.position = Vector2(main_view_width, 0.0)
	_shot_panel.size = Vector2(tee_view_width, screen_size.y)
	_aspect_container.ratio = maxf(0.01, tee_view_width / maxf(1.0, screen_size.y))


func _set_full_view_style(is_full_view: bool) -> void:
	if is_full_view:
		var full_view_style := StyleBoxFlat.new()
		full_view_style.bg_color = Color(0.035, 0.055, 0.045, 0.94)
		full_view_style.set_border_width_all(0)
		full_view_style.content_margin_left = 4.0
		full_view_style.content_margin_right = 4.0
		full_view_style.content_margin_top = 4.0
		full_view_style.content_margin_bottom = 0.0
		_shot_panel.add_theme_stylebox_override("panel", full_view_style)
		_header_bar.visible = _can_detach()
		_title_label.visible = _can_detach()
		_layout.add_theme_constant_override("separation", 4 if _can_detach() else 0)
	else:
		_shot_panel.add_theme_stylebox_override("panel", _panel_style)
		_header_bar.visible = true
		_title_label.visible = true
		_layout.add_theme_constant_override("separation", 4)
		if not _is_popped_out:
			_aspect_container.ratio = _map_size.x / maxf(1.0, _map_size.y)


func _suppress_main_camera_rendering() -> void:
	if _main_camera == null or not is_instance_valid(_main_camera) or _main_camera_render_suppressed:
		return
	_main_camera_cull_mask = _main_camera.cull_mask
	_main_camera_render_suppressed = true
	_main_camera.cull_mask = 0


func _sync_main_camera() -> void:
	if _main_camera == null or not is_instance_valid(_main_camera) or _main_view_camera == null:
		return
	_main_view_camera.global_transform = _main_camera.global_transform
	_main_view_camera.projection = _main_camera.projection
	_main_view_camera.fov = _main_camera.fov
	_main_view_camera.size = _main_camera.size
	_main_view_camera.near = _main_camera.near
	_main_view_camera.far = _main_camera.far
	_main_view_camera.frustum_offset = _main_camera.frustum_offset
	_main_view_camera.h_offset = _main_camera.h_offset
	_main_view_camera.v_offset = _main_camera.v_offset
	_main_view_camera.environment = _main_camera.environment
	_main_view_camera.attributes = _main_camera.attributes
	_main_view_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_main_view_camera.cull_mask = _main_camera_cull_mask if _main_camera_render_suppressed else _main_camera.cull_mask


func _restore_main_camera_rendering() -> void:
	if _main_camera_render_suppressed and _main_camera != null and is_instance_valid(_main_camera):
		_main_camera.cull_mask = _main_camera_cull_mask
	_main_camera_render_suppressed = false


func _process(_delta: float) -> void:
	if _split_mode:
		_sync_main_camera()
		_update_split_layout()


func _finish_split_open() -> void:
	_split_progress = 1.0
	_update_split_layout()
	_split_tween = null


func update_tracer(local_points: Array, player_transform: Transform3D, start_pos: Vector3, current_pos: Vector3) -> void:
	var points: Array[Vector3] = []
	for point in local_points:
		if point is Vector3:
			var global_point: Vector3 = player_transform * point
			points.append(global_point + Vector3.UP * TRACER_HEIGHT_OFFSET)
	if points.is_empty() or not points.front().is_equal_approx(start_pos + Vector3.UP * TRACER_HEIGHT_OFFSET):
		points.push_front(start_pos + Vector3.UP * TRACER_HEIGHT_OFFSET)
	if not points.back().is_equal_approx(current_pos + Vector3.UP * TRACER_HEIGHT_OFFSET):
		points.append(current_pos + Vector3.UP * TRACER_HEIGHT_OFFSET)

	_flight_overlay.call("set_flight_path", _camera, points, start_pos + Vector3.UP * TRACER_HEIGHT_OFFSET)


func update_ball_position(current_pos: Vector3) -> void:
	_flight_overlay.call("set_ball_position", current_pos + Vector3.UP * TRACER_HEIGHT_OFFSET)


func hide_shot(immediate: bool = false) -> void:
	_shot_active = false
	if _is_popped_out:
		_save_popout_window_rect()
		if immediate:
			_close_popout_window_only()
		return
	if not visible:
		return
	if not _split_mode:
		visible = false
		return
	_stop_split_transition()
	_restore_main_camera_rendering()
	if immediate:
		_finish_split_close()
		return
	_split_tween = create_tween()
	_split_tween.set_trans(Tween.TRANS_CUBIC)
	_split_tween.set_ease(Tween.EASE_IN_OUT)
	_split_tween.tween_method(_set_split_progress, _split_progress, 0.0, SIZE_TRANSITION_DURATION)
	_split_tween.tween_callback(_finish_split_close)


func _finish_split_close() -> void:
	_split_tween = null
	_split_mode = false
	_restore_main_camera_rendering()
	_main_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_main_view_clip.visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_flight_overlay.call("clear_flight_path")
	position = _map_position
	size = _map_size
	_set_full_view_style(false)
	_shot_panel.position = Vector2.ZERO
	_shot_panel.size = _map_size
	_shot_panel.visible = true
	visible = false
	split_closed.emit()


func _stop_split_transition() -> void:
	if _split_tween != null and _split_tween.is_running():
		_split_tween.kill()
	_split_tween = null


func pop_out(persist_setting: bool = true) -> void:
	if not _can_detach():
		return
	var host_viewport := get_viewport()
	var host_world_3d: World3D = host_viewport.find_world_3d() if host_viewport != null else null
	if _split_mode:
		_stop_split_transition()
		_split_mode = false
		_restore_main_camera_rendering()
		_main_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_main_view_clip.visible = false
		visible = false
		split_closed.emit()
	else:
		visible = false

	_ensure_popout_window()
	if _popout_window == null or not is_instance_valid(_popout_window):
		return

	if _shot_panel.get_parent() != _popout_window:
		var old_parent := _shot_panel.get_parent()
		if old_parent != null:
			old_parent.remove_child(_shot_panel)
		_popout_window.add_child(_shot_panel)

	_shot_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot_panel.visible = true
	_is_popped_out = true
	_set_full_view_style(false)
	_update_popout_aspect_ratio()

	if host_world_3d != null:
		_viewport.world_3d = host_world_3d
	_viewport_container.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if _popout_button != null:
		_popout_button.text = "↙ Dock"
		_popout_button.tooltip_text = "Dock Tee Shot View back into the main window"
		_popout_button.visible = true

	if persist_setting:
		_set_detached_setting(true)

	_popout_window.show()
	popout_changed.emit(true)


func dock_window(persist_setting: bool = true) -> void:
	_save_popout_window_rect()
	if persist_setting:
		_set_detached_setting(false)

	_close_popout_window_only()

	if _shot_active:
		_enter_split_mode(false)
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_flight_overlay.call("clear_flight_path")
		position = _map_position
		size = _map_size
		_shot_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_shot_panel.position = Vector2.ZERO
		_shot_panel.size = _map_size
		_set_full_view_style(false)
		_shot_panel.visible = true
		visible = false
	popout_changed.emit(false)


func _close_popout_window_only() -> void:
	if _shot_panel != null and is_instance_valid(_shot_panel) and _shot_panel.get_parent() != self:
		var old_parent := _shot_panel.get_parent()
		if old_parent != null:
			old_parent.remove_child(_shot_panel)
		add_child(_shot_panel)

	if _viewport != null and is_instance_valid(_viewport):
		_viewport.world_3d = null
		if not _shot_active:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	if _popout_window != null and is_instance_valid(_popout_window):
		_popout_window.queue_free()
	_popout_window = null
	_is_popped_out = false
	_restore_subwindow_embedding()

	if _popout_button != null and is_instance_valid(_popout_button):
		_popout_button.text = "↗ Pop Out"
		_popout_button.tooltip_text = "Pop out Tee Shot View into a separate draggable window"
		_popout_button.visible = _can_detach()


func _ensure_popout_window() -> void:
	if _popout_window != null and is_instance_valid(_popout_window):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return

	if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		tree.root.gui_embed_subwindows = false

	var win := Window.new()
	win.name = "TeeShotPopoutWindow"
	win.title = "⛳ Heckle Golf Sim - Tee Shot Flight View"
	win.transient = false
	win.exclusive = false
	win.unresizable = false
	win.borderless = false
	win.always_on_top = false
	win.min_size = MIN_POPOUT_SIZE

	var gs := _get_global_settings()
	var saved_w := int(gs.range_settings.tee_shot_window_width.value) if gs != null else DEFAULT_POPOUT_SIZE.x
	var saved_h := int(gs.range_settings.tee_shot_window_height.value) if gs != null else DEFAULT_POPOUT_SIZE.y
	win.size = Vector2i(maxi(MIN_POPOUT_SIZE.x, saved_w), maxi(MIN_POPOUT_SIZE.y, saved_h))

	var saved_x := int(gs.range_settings.tee_shot_window_position_x.value) if gs != null else -1
	var saved_y := int(gs.range_settings.tee_shot_window_position_y.value) if gs != null else -1
	if saved_x >= 0 and saved_y >= 0:
		win.position = Vector2i(saved_x, saved_y)
	else:
		var screen_count := DisplayServer.get_screen_count()
		var cur_screen := DisplayServer.window_get_current_screen()
		var target_screen := 1 if (screen_count > 1 and cur_screen == 0) else (0 if screen_count > 1 else cur_screen)
		var s_rect := DisplayServer.screen_get_usable_rect(target_screen)
		win.position = Vector2i(s_rect.position.x + maxi(40, s_rect.size.x - win.size.x - 40), s_rect.position.y + 60)

	win.close_requested.connect(func(): dock_window(true))
	win.focus_exited.connect(_save_popout_window_rect)
	win.size_changed.connect(_on_popout_window_resized)

	_popout_window = win
	tree.root.add_child(win)


func _on_popout_window_resized() -> void:
	_save_popout_window_rect()
	_update_popout_aspect_ratio()


func _update_popout_aspect_ratio() -> void:
	if not _is_popped_out or _popout_window == null or not is_instance_valid(_popout_window) or _aspect_container == null:
		return
	var win_size := Vector2(_popout_window.size)
	var header_h := _header_bar.size.y if _header_bar != null else 32.0
	var avail_h := maxf(1.0, win_size.y - header_h - 16.0)
	_aspect_container.ratio = maxf(0.1, win_size.x / avail_h)


func _on_popout_button_pressed() -> void:
	if _is_popped_out:
		dock_window(true)
	else:
		pop_out(true)


func _should_use_popout() -> bool:
	if _is_popped_out:
		return true
	if not _can_detach():
		return false
	var gs := _get_global_settings()
	if gs == null:
		return false
	return bool(gs.range_settings.tee_shot_view_detached.value)


func _get_global_settings() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GlobalSettings")


func _set_detached_setting(detached: bool) -> void:
	var gs := _get_global_settings()
	if gs == null:
		return
	gs.range_settings.tee_shot_view_detached.set_value(detached)
	if gs.has_method("save_settings"):
		gs.save_settings()


func _save_popout_window_rect() -> void:
	if _popout_window == null or not is_instance_valid(_popout_window):
		return
	var gs := _get_global_settings()
	if gs == null:
		return
	gs.range_settings.tee_shot_window_position_x.value = _popout_window.position.x
	gs.range_settings.tee_shot_window_position_y.value = _popout_window.position.y
	gs.range_settings.tee_shot_window_width.value = _popout_window.size.x
	gs.range_settings.tee_shot_window_height.value = _popout_window.size.y
	if gs.has_method("save_settings"):
		gs.save_settings()


func _restore_subwindow_embedding() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.gui_embed_subwindows = bool(ProjectSettings.get_setting("display/window/subwindows/embed_subwindows", true))


func _style_popout_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.42, 0.62, 0.95)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 3.0
	normal.content_margin_bottom = 3.0

	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.52, 0.74, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.34, 0.50, 1.0)

	_popout_button.add_theme_stylebox_override("normal", normal)
	_popout_button.add_theme_stylebox_override("hover", hover)
	_popout_button.add_theme_stylebox_override("pressed", pressed)
	_popout_button.add_theme_font_size_override("font_size", 12)
	_popout_button.add_theme_color_override("font_color", Color.WHITE)


func _exit_tree() -> void:
	_restore_main_camera_rendering()
	_save_popout_window_rect()
	if _popout_window != null and is_instance_valid(_popout_window):
		_popout_window.queue_free()
		_popout_window = null
	_restore_subwindow_embedding()
