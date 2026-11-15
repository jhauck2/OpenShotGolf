extends Control

const TeeShotFlightOverlayScript = preload("res://UI/tee_shot_overlay.gd")

signal split_started
signal split_closed

const SIZE_TRANSITION_DURATION := 0.8
const FLIGHT_VIEW_RENDER_SHRINK := 2
const CAMERA_TRAIL_DISTANCE := 150.0
const CAMERA_BASE_HEIGHT := 70.0
const CAMERA_LOOK_DISTANCE := 140.0
const CAMERA_LOOK_HEIGHT := 18.0
const CAMERA_FIELD_OF_VIEW := 50.0
const TRACER_HEIGHT_OFFSET := 0.3

var _viewport: SubViewport
var _aspect_container: AspectRatioContainer
var _viewport_container: SubViewportContainer
var _shot_panel: PanelContainer
var _layout: VBoxContainer
var _title_label: Label
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


func _ready() -> void:
	name = "TeeShotView"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)

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

	_title_label = Label.new()
	_title_label.text = "TEE SHOT  |  FLIGHT VIEW"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.78))
	_title_label.add_theme_constant_override("outline_size", 3)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_layout.add_child(_title_label)

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


func prepare_for_shot(start_pos: Vector3, current_pos: Vector3, target_pos: Vector3) -> void:
	show_shot(start_pos, current_pos, target_pos)
	var opening_tween := _split_tween
	if opening_tween != null:
		await opening_tween.finished


func show_shot(start_pos: Vector3, _current_pos: Vector3, target_pos: Vector3) -> void:
	_stop_split_transition()
	_flight_overlay.call("clear_flight_path")
	_split_mode = false
	visible = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = _map_position
	size = _map_size
	_split_mode = true
	_split_progress = 0.0
	_set_full_view_style(true)
	_update_split_layout()
	_viewport_container.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_shot_panel.visible = true
	split_started.emit()
	_split_tween = create_tween()
	_split_tween.set_trans(Tween.TRANS_CUBIC)
	_split_tween.set_ease(Tween.EASE_IN_OUT)
	_split_tween.tween_method(_set_split_progress, 0.0, 1.0, SIZE_TRANSITION_DURATION)
	_split_tween.tween_callback(_finish_split_open)
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
	position = _map_position.lerp(Vector2.ZERO, _split_progress)
	size = _map_size.lerp(screen_size, _split_progress)
	_shot_panel.position = Vector2.ZERO
	_shot_panel.size = size
	_aspect_container.ratio = size.x / maxf(1.0, size.y)


func _set_full_view_style(is_full_view: bool) -> void:
	if is_full_view:
		var full_view_style := StyleBoxEmpty.new()
		_shot_panel.add_theme_stylebox_override("panel", full_view_style)
		_title_label.visible = false
		_layout.add_theme_constant_override("separation", 0)
	else:
		_shot_panel.add_theme_stylebox_override("panel", _panel_style)
		_title_label.visible = true
		_layout.add_theme_constant_override("separation", 4)
		_aspect_container.ratio = _map_size.x / maxf(1.0, _map_size.y)


func _suppress_main_camera_rendering() -> void:
	if _main_camera == null or not is_instance_valid(_main_camera) or _main_camera_render_suppressed:
		return
	_main_camera_cull_mask = _main_camera.cull_mask
	_main_camera_render_suppressed = true
	_main_camera.cull_mask = 0


func _restore_main_camera_rendering() -> void:
	if _main_camera_render_suppressed and _main_camera != null and is_instance_valid(_main_camera):
		_main_camera.cull_mask = _main_camera_cull_mask
	_main_camera_render_suppressed = false


func _process(_delta: float) -> void:
	if _split_mode:
		_update_split_layout()


func _finish_split_open() -> void:
	_split_progress = 1.0
	_update_split_layout()
	_suppress_main_camera_rendering()
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


func _exit_tree() -> void:
	_restore_main_camera_rendering()
