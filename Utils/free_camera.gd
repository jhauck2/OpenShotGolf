class_name FreeCamera
extends Camera3D

signal deactivated

# Movement and look settings
@export var move_speed: float = 30.0
@export var elevation_speed: float = 20.0
@export var turn_speed: float = 2.0
@export var mouse_sensitivity: float = 0.003
@export var joy_look_speed: float = 2.2
@export var boost_multiplier: float = 2.5
@export var min_height_above_ground: float = 1.2
@export var max_height: float = 250.0

var is_active: bool = false
var course_node: Node = null

# Internal rotation angles
var _yaw: float = 0.0
var _pitch: float = 0.0

# Previous camera to restore
var _previous_camera: Camera3D = null

# Click-to-move autopilot state
var _is_flying_to_target: bool = false
var _target_destination: Vector3 = Vector3.ZERO
var _target_arrival_distance: float = 1.5
var _waypoint_marker: Node3D = null

# Mouse drag state
var _is_mouse_left_down: bool = false
var _is_mouse_right_down: bool = false
var _is_mouse_middle_down: bool = false
var _mouse_press_pos: Vector2 = Vector2.ZERO
var _mouse_dragged: bool = false
const DRAG_THRESHOLD: float = 6.0

# On-screen HUD state
var _hud_canvas: CanvasLayer = null
var _ui_elev_up_pressed: bool = false
var _ui_elev_down_pressed: bool = false


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)


func activate(from_camera: Camera3D = null, course: Node = null) -> void:
	course_node = course
	is_active = true

	if from_camera == null:
		var vp := get_viewport()
		if vp != null:
			from_camera = vp.get_camera_3d()

	if from_camera != null and from_camera != self:
		_previous_camera = from_camera
		global_transform = from_camera.global_transform
		keep_aspect = from_camera.keep_aspect
		fov = from_camera.fov
		near = from_camera.near
		far = maxf(from_camera.far, 2500.0)
		cull_mask = from_camera.cull_mask
	
	# Extract initial yaw and pitch from basis
	var euler := global_transform.basis.get_euler()
	_pitch = euler.x
	_yaw = euler.y

	if has_node("/root/ScreenOffsetManager"):
		var som = get_node("/root/ScreenOffsetManager")
		som.call("set_suppressed", true)

	make_current()

	_is_flying_to_target = false
	if _waypoint_marker != null and is_instance_valid(_waypoint_marker):
		_waypoint_marker.visible = false

	_create_hud()

	set_process(true)
	set_process_unhandled_input(true)


func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	_is_flying_to_target = false

	if _waypoint_marker != null and is_instance_valid(_waypoint_marker):
		_waypoint_marker.visible = false

	if _hud_canvas != null and is_instance_valid(_hud_canvas):
		_hud_canvas.queue_free()
		_hud_canvas = null

	_ui_elev_up_pressed = false
	_ui_elev_down_pressed = false

	# Restore previous camera
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	elif course_node != null and course_node.has_node("Camera3D"):
		var c3d = course_node.get_node_or_null("Camera3D") as Camera3D
		if c3d != null:
			c3d.make_current()

	if has_node("/root/ScreenOffsetManager"):
		var som = get_node("/root/ScreenOffsetManager")
		som.call("set_suppressed", false)

	# Return player back to standard ball view
	if course_node != null:
		if course_node.has_method("reset_to_standard_ball_view"):
			course_node.call("reset_to_standard_ball_view")
		elif course_node.get_parent() != null and course_node.get_parent().has_method("reset_to_standard_ball_view"):
			course_node.get_parent().call("reset_to_standard_ball_view")

	set_process(false)
	set_process_unhandled_input(false)
	emit_signal("deactivated")


func _exit_tree() -> void:
	if _hud_canvas != null and is_instance_valid(_hud_canvas):
		_hud_canvas.queue_free()
		_hud_canvas = null


func _process(delta: float) -> void:
	if not is_active:
		return

	# Speed modifier (Shift on keyboard, or Left Stick / RB on gamepad)
	var speed_mult := 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed_mult = boost_multiplier

	# Joypad check for speed boost
	for joy_id in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_LEFT_STICK) or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_RIGHT_SHOULDER):
			speed_mult = boost_multiplier
			break

	var move_input := Vector3.ZERO
	var turn_input := 0.0
	var pitch_input := 0.0

	# 1. Arrow Keys & Keyboard Input
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		move_input.z += 1.0 # Forward
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		move_input.z -= 1.0 # Backward

	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0 # Strafe left
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0 # Strafe right

	# Arrow Left / Right: turn camera left/right (or strafe if Shift held)
	if Input.is_key_pressed(KEY_LEFT):
		if Input.is_key_pressed(KEY_SHIFT):
			move_input.x -= 1.0
		else:
			turn_input += 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		if Input.is_key_pressed(KEY_SHIFT):
			move_input.x += 1.0
		else:
			turn_input -= 1.0

	# Vertical ascend / descend
	# Ascend keys: Space, E, R, PageUp, Keypad 9, Keypad +
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_PAGEUP) or Input.is_key_pressed(KEY_KP_9) or Input.is_key_pressed(KEY_KP_ADD):
		move_input.y += 1.0
	# Descend keys: Ctrl, Q, C, F, PageDown, Keypad 3, Keypad -
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_PAGEDOWN) or Input.is_key_pressed(KEY_KP_3) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		move_input.y -= 1.0

	# Arrow keys with Shift: Shift + Up (Ascend), Shift + Down (Descend)
	if Input.is_key_pressed(KEY_SHIFT):
		if Input.is_key_pressed(KEY_UP):
			move_input.y += 1.0
			move_input.z -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
			move_input.y -= 1.0
			move_input.z += 1.0

	# On-Screen UI elevation buttons
	if _ui_elev_up_pressed:
		move_input.y += 1.0
	if _ui_elev_down_pressed:
		move_input.y -= 1.0

	# Keyboard pitch: Home / End or Alt + Up / Down
	if Input.is_key_pressed(KEY_HOME):
		pitch_input += 1.0
	if Input.is_key_pressed(KEY_END):
		pitch_input -= 1.0
	if Input.is_key_pressed(KEY_ALT):
		if Input.is_key_pressed(KEY_UP):
			pitch_input += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			pitch_input -= 1.0

	# 2. Gamepad / Analog Stick Input
	for joy_id in Input.get_connected_joypads():
		# Left Analog Stick: Move & Strafe
		var lx := Input.get_joy_axis(joy_id, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(joy_id, JOY_AXIS_LEFT_Y)
		if absf(lx) > 0.15:
			move_input.x += lx
		if absf(ly) > 0.15:
			move_input.z -= ly # Gamepad stick up is negative Y

		# Right Analog Stick: Rotate (Yaw & Pitch)
		var rx := Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_Y)
		if absf(rx) > 0.15:
			turn_input -= rx * joy_look_speed
		if absf(ry) > 0.15:
			pitch_input -= ry * joy_look_speed

		# Triggers & D-Pad: Elevation
		var rt := Input.get_joy_axis(joy_id, JOY_AXIS_TRIGGER_RIGHT)
		var lt := Input.get_joy_axis(joy_id, JOY_AXIS_TRIGGER_LEFT)
		if rt > 0.2:
			move_input.y += rt
		if lt > 0.2:
			move_input.y -= lt

		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_UP):
			move_input.y += 1.0
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_DOWN):
			move_input.y -= 1.0

	var has_manual_input := move_input.length_squared() > 0.001 or absf(turn_input) > 0.001 or absf(pitch_input) > 0.001

	# If player provides manual input, cancel click-to-move autopilot
	if has_manual_input and _is_flying_to_target:
		_is_flying_to_target = false
		if _waypoint_marker != null and is_instance_valid(_waypoint_marker):
			_waypoint_marker.visible = false

	# Apply rotation
	if absf(turn_input) > 0.001 or absf(pitch_input) > 0.001:
		_yaw += turn_input * turn_speed * delta
		_pitch += pitch_input * turn_speed * delta
		_pitch = clampf(_pitch, -deg_to_rad(85.0), deg_to_rad(85.0))
		_apply_rotation()

	# Apply manual movement
	if move_input.length_squared() > 0.001:
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		var up := Vector3.UP

		var delta_pos := (right * move_input.x + forward * move_input.z) * (move_speed * speed_mult * delta)
		delta_pos += up * (move_input.y * elevation_speed * speed_mult * delta)
		global_position += delta_pos

	# Autopilot click-to-move interpolation
	if _is_flying_to_target:
		var to_target := _target_destination - global_position
		var dist := to_target.length()
		if dist <= _target_arrival_distance:
			_is_flying_to_target = false
			if _waypoint_marker != null and is_instance_valid(_waypoint_marker):
				_waypoint_marker.visible = false
		else:
			var fly_speed := clampf(dist * 2.5, 8.0, 45.0)
			var step := to_target.normalized() * (fly_speed * delta)
			if step.length() >= dist:
				global_position = _target_destination
				_is_flying_to_target = false
				if _waypoint_marker != null and is_instance_valid(_waypoint_marker):
					_waypoint_marker.visible = false
			else:
				global_position += step

	# Ground height clamping to avoid clipping underground
	_clamp_to_terrain()


func _clamp_to_terrain() -> void:
	if course_node != null and course_node.has_method("get_height"):
		var terrain_y: float = course_node.call("get_height", global_position.x, global_position.z)
		var min_y := terrain_y + min_height_above_ground
		if global_position.y < min_y:
			global_position.y = min_y
	if global_position.y > max_height:
		global_position.y = max_height


func _apply_rotation() -> void:
	var b := Basis()
	b = b.rotated(Vector3.UP, _yaw)
	b = b.rotated(b.x, _pitch)
	global_transform.basis = b.orthonormalized()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Quick exit: Escape or Joypad B button exits free camera
	if (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE) or \
	   (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		deactivate()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if not event.pressed:
			_ui_elev_up_pressed = false
			_ui_elev_down_pressed = false

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_left_down = true
				_mouse_press_pos = event.position
				_mouse_dragged = false
			else:
				_is_mouse_left_down = false
				if not _mouse_dragged:
					# Click to Move
					perform_click_to_move(event.position)
					get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_right_down = event.pressed
			if event.pressed:
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_mouse_middle_down = event.pressed
			if event.pressed:
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if event.shift_pressed:
				move_speed = clampf(move_speed * 1.15, 5.0, 150.0)
			else:
				global_position.y += 3.0 * (boost_multiplier if event.is_command_or_control_autoremap() else 1.0)
				_clamp_to_terrain()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if event.shift_pressed:
				move_speed = clampf(move_speed * 0.85, 5.0, 150.0)
			else:
				global_position.y -= 3.0 * (boost_multiplier if event.is_command_or_control_autoremap() else 1.0)
				_clamp_to_terrain()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _is_mouse_middle_down or (_is_mouse_right_down and event.shift_pressed):
			# Vertical mouse drag raises or lowers altitude
			var delta_y = -event.relative.y * 0.10 * (boost_multiplier if event.shift_pressed else 1.0)
			global_position.y += delta_y
			_clamp_to_terrain()
			get_viewport().set_input_as_handled()
		elif _is_mouse_right_down:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clampf(_pitch, -deg_to_rad(85.0), deg_to_rad(85.0))
			_apply_rotation()
			get_viewport().set_input_as_handled()
		elif _is_mouse_left_down:
			if event.position.distance_to(_mouse_press_pos) > DRAG_THRESHOLD:
				_mouse_dragged = true
				_yaw -= event.relative.x * mouse_sensitivity
				_pitch -= event.relative.y * mouse_sensitivity
				_pitch = clampf(_pitch, -deg_to_rad(85.0), deg_to_rad(85.0))
				_apply_rotation()
				get_viewport().set_input_as_handled()


func perform_click_to_move(screen_pos: Vector2) -> void:
	var ray_start := project_ray_origin(screen_pos)
	var ray_dir := project_ray_normal(screen_pos)
	var ray_length := 3000.0
	var ray_end := ray_start + ray_dir * ray_length

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 0xFFFFFFFF
	var hit := space_state.intersect_ray(query)

	var hit_pos := Vector3.ZERO
	var hit_found := false

	if not hit.is_empty():
		hit_pos = hit["position"]
		hit_found = true
	elif course_node != null and course_node.has_method("get_height"):
		var ground_y: float = course_node.call("get_height", ray_start.x, ray_start.z)
		if "aim_target_pos" in course_node and course_node.aim_target_pos != null:
			ground_y = (course_node.aim_target_pos as Vector3).y

		if ray_dir.y < -0.01:
			var t := (ground_y - ray_start.y) / ray_dir.y
			if t > 0.0 and t < ray_length:
				var p := ray_start + ray_dir * t
				p.y = course_node.call("get_height", p.x, p.z)
				hit_pos = p
				hit_found = true
		
		if not hit_found:
			# If looking level or towards horizon, pick a point forward along ray
			var forward_dist := 80.0
			var p := ray_start + ray_dir * forward_dist
			p.y = course_node.call("get_height", p.x, p.z)
			hit_pos = p
			hit_found = true
	else:
		# Fallback if no height query available: fly forward 50m
		hit_pos = ray_start + ray_dir * 50.0
		hit_found = true

	if hit_found:
		var forward := -global_transform.basis.z
		var dest_elevation := 9.0
		_target_destination = hit_pos + Vector3(0, dest_elevation, 0) - forward.normalized() * 6.0
		if course_node != null and course_node.has_method("get_height"):
			var min_y: float = course_node.call("get_height", _target_destination.x, _target_destination.z) + min_height_above_ground
			if _target_destination.y < min_y:
				_target_destination.y = min_y
		_is_flying_to_target = true
		_show_waypoint(hit_pos)


func _show_waypoint(pos: Vector3) -> void:
	if _waypoint_marker == null or not is_instance_valid(_waypoint_marker):
		_waypoint_marker = _create_waypoint_marker()
		var parent_node = get_parent()
		if parent_node != null:
			parent_node.add_child(_waypoint_marker)
		else:
			add_child(_waypoint_marker)

	_waypoint_marker.global_position = pos + Vector3(0, 0.15, 0)
	_waypoint_marker.visible = true


func _create_waypoint_marker() -> Node3D:
	var marker_root := Node3D.new()
	marker_root.name = "FreeCameraWaypoint"

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "RingMesh"

	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.1
	torus.rings = 24
	torus.ring_segments = 12

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.mesh = torus
	mesh_inst.material_override = mat

	marker_root.add_child(mesh_inst)
	return marker_root


func _create_hud() -> void:
	if _hud_canvas != null and is_instance_valid(_hud_canvas):
		return

	_hud_canvas = CanvasLayer.new()
	_hud_canvas.name = "FreeCameraHUDLayer"
	_hud_canvas.layer = 75

	var root_ctrl := Control.new()
	root_ctrl.name = "FreeCameraOverlay"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_canvas.add_child(root_ctrl)

	var panel := PanelContainer.new()
	panel.name = "FreeCamPanel"
	panel.custom_minimum_size = Vector2(250, 110)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.20, 0.90)
	style.border_color = Color(0.28, 0.45, 0.60, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -285.0
	panel.offset_right = -15.0
	panel.offset_top = -140.0
	panel.offset_bottom = -15.0
	root_ctrl.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Row 1: Header + Return to Ball View
	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎥 Free Camera"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var ball_view_btn := Button.new()
	ball_view_btn.name = "ReturnBallViewButton"
	ball_view_btn.text = "⛳ Ball View"
	ball_view_btn.tooltip_text = "Return to Standard Ball View (Esc / B)"
	ball_view_btn.custom_minimum_size = Vector2(95, 30)
	_apply_hud_button_style(ball_view_btn, Color(0.18, 0.52, 0.65, 0.95), Color(0.24, 0.64, 0.80, 1.0))
	ball_view_btn.pressed.connect(func():
		deactivate()
	)
	header_hbox.add_child(ball_view_btn)

	# Row 2: Elevation Buttons
	var elev_hbox := HBoxContainer.new()
	elev_hbox.add_theme_constant_override("separation", 8)
	elev_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(elev_hbox)

	var elev_lbl := Label.new()
	elev_lbl.text = "Altitude:"
	elev_lbl.add_theme_font_size_override("font_size", 12)
	elev_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
	elev_hbox.add_child(elev_lbl)

	var up_btn := Button.new()
	up_btn.name = "ElevateUpButton"
	up_btn.text = "▲ Up"
	up_btn.tooltip_text = "Ascend / Fly Up (Space / E / R / Wheel Up / Shift+Up)"
	up_btn.custom_minimum_size = Vector2(65, 32)
	_apply_hud_button_style(up_btn, Color(0.22, 0.35, 0.48, 0.9), Color(0.30, 0.48, 0.65, 1.0))
	up_btn.button_down.connect(func(): _ui_elev_up_pressed = true)
	up_btn.button_up.connect(func(): _ui_elev_up_pressed = false)
	elev_hbox.add_child(up_btn)

	var down_btn := Button.new()
	down_btn.name = "ElevateDownButton"
	down_btn.text = "▼ Down"
	down_btn.tooltip_text = "Descend / Fly Down (Ctrl / Q / C / F / Wheel Down / Shift+Down)"
	down_btn.custom_minimum_size = Vector2(65, 32)
	_apply_hud_button_style(down_btn, Color(0.22, 0.35, 0.48, 0.9), Color(0.30, 0.48, 0.65, 1.0))
	down_btn.button_down.connect(func(): _ui_elev_down_pressed = true)
	down_btn.button_up.connect(func(): _ui_elev_down_pressed = false)
	elev_hbox.add_child(down_btn)

	# Row 3: Shortcut tips
	var hint_lbl := Label.new()
	hint_lbl.text = "Wheel/Space/Ctrl • WASD/Arrows"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.80, 0.85))
	vbox.add_child(hint_lbl)

	add_child(_hud_canvas)


func _apply_hud_button_style(btn: Button, base_color: Color, hover_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 12)
