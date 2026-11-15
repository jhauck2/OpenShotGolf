extends Node3D

const TeeboxMarkerBuilder = preload("res://Courses/Range/teebox_marker_builder.gd")
const FlagBuilder = preload("res://Courses/Range/flag_builder.gd")
const AimDistanceIndicator = preload("res://UI/aim_distance_indicator.gd")
const WeatherLightingController = preload("res://Courses/Range/weather_lighting_controller.gd")
const RainPhysics = preload("res://Utils/rain_physics.gd")

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var display_data: Dictionary = {
	"Distance": "---",
	"Carry": "---",
	"Offline": "---",
	"Apex": "---",
	"VLA": "---",
	"HLA": "---",
	"Speed": "---",
	"BallSpeed": "---",
	"ClubSpeed": "---",
	"SmashFactor": "---",
	"BackSpin": "---",
	"SideSpin": "---",
	"TotalSpin": "---",
	"SpinAxis": "---"
}
var raw_ball_data: Dictionary = {}
var last_display: Dictionary = {}
var is_aerial_view: bool = false
var _free_camera: Camera3D = null
var is_driving_range: bool = false
var _elevation_width: int = 0
var _elevation_height: int = 0
var _elevation_left_lon: float = 0.0
var _elevation_right_lon: float = 0.0
var _elevation_top_lat: float = 0.0
var _elevation_bottom_lat: float = 0.0
var _elevation_ref_lat: float = 0.0
var _elevation_ref_lon: float = 0.0
var _elevation_meters_per_lat: float = 111320.0
var _elevation_meters_per_lon: float = 111320.0
var _elevation_offset: float = 0.0
var _elevation_data: PackedFloat32Array = PackedFloat32Array()
var _has_elevation_map: bool = false
var _height_raycast: RayCast3D = null
var aerial_zoom: float = 300.0
var _last_was_on_green: bool = false
var _default_non_green_aerial_zoom: float = 300.0
var _teebox_aerial_zoom: float = 300.0
var _last_zoom_zone: int = -1
var aim_target_pos: Vector3 = Vector3(150.0, 0.0, 0.0) # Default target down the range
var _last_aim_target_pos: Vector3 = Vector3.ZERO
var _last_aim_yaw_offset_deg: float = 0.0
var _aim_is_manual: bool = false
var aim_line: MeshInstance3D = null
var _last_aim_line_start: Vector3 = Vector3.INF
var _last_aim_line_end: Vector3 = Vector3.INF
var current_aim_distance_yards: float = 0.0
var current_aim_elevation_diff_m: float = -9999.0

# Performance and throttling state
var _live_stats_timer: float = 0.0
var _green_grid_timer: float = 0.0
var _zoom_zone_dirty: bool = true
var _cached_surface_nodes_initialized: bool = false
var _cached_green_bodies: Array[Dictionary] = []
var _cached_tee_bodies: Array[Dictionary] = []
var _cached_fairway_bodies: Array[Dictionary] = []
var _cached_current_green_pin: Vector3 = Vector3.ZERO
var _cached_current_green_entry: Dictionary = {}

# Dynamic Course Play active hole variables
var show_green_grid: bool = false:
	set(val):
		if show_green_grid != val:
			show_green_grid = val
			_update_green_grid_visibility()
			if has_node("MapCanvas/AerialZoomVBox/GridToggleButton"):
				var btn = $MapCanvas/AerialZoomVBox/GridToggleButton
				var btn_color = Color(0.2, 0.6, 0.3, 0.85) if show_green_grid else Color(0.15, 0.15, 0.15, 0.85)
				apply_circular_button_style(btn, btn_color)
var current_hole_location: Vector3 = Vector3.ZERO:
	set(val):
		if current_hole_location != val:
			current_hole_location = val
			call_deferred("_generate_green_grid_and_heatmap")
			var mp_mgr: Node = null
			if is_inside_tree() and has_node("/root/MultiplayerManager"):
				mp_mgr = get_node("/root/MultiplayerManager")
			else:
				var ml = Engine.get_main_loop()
				if ml is SceneTree and ml.root != null:
					if ml.root.has_node("MultiplayerManager"):
						mp_mgr = ml.root.get_node("MultiplayerManager")
					else:
						mp_mgr = ml.root.find_child("MultiplayerManager", true, false)
			if mp_mgr != null:
				mp_mgr.current_pin_position = val
var cup_radius: float = 0.054
var current_hole_id: String = ""
var current_hole_name: String = "Hole 1"
var current_hole_par: int = 4
var current_hole_tee_dist_yards: int = 0
var shot_count: int = 0

# Map dragging state variables
var is_dragging_map: bool = false
var map_drag_start_pos: Vector2 = Vector2.ZERO
var total_map_drag_dist: float = 0.0
var aerial_cam_user_offset: Vector3 = Vector3.ZERO
var is_mouse_down_on_map: bool = false
var _touch_points: Dictionary = {}
var _last_pinch_distance: float = -1.0
# Continuous screen-half aiming state variables
var is_screen_aiming: bool = false
var screen_aim_direction: float = 0.0
var screen_aim_speed_deg: float = 17.5
var _was_keyboard_aiming: bool = false
var _was_screen_aiming: bool = false
var _continuous_aim_angle_rad: float = 0.0
var _continuous_aim_angle_init: bool = false
var _last_aim_dist_yards: int = -1
var _aim_distance_indicator: AimDistanceIndicator = null
var _weather_lighting_controller: WeatherLightingController = null

func is_actively_aiming() -> bool:
	return _was_keyboard_aiming or _was_screen_aiming or is_screen_aiming or (_aim_distance_indicator != null and _aim_distance_indicator.is_indicator_active())


func get_weather_lighting_controller() -> WeatherLightingController:
	return _weather_lighting_controller

var course_data_dict: Dictionary = {}
var _shot_active: bool = false
var is_sky_view_active: bool = false
var _last_travel_yaw: float = 0.0
var _user_custom_club: String = ""
var _is_updating_auto_club: bool = false
var _skip_requested := false
var _putt_close_view_triggered: bool = false
var _chip_close_view_triggered: bool = false
# Chipping minigame state variables
var chipping_island_positions: Array[Vector3] = []
var chipping_stats := {}
var selected_chipping_target_idx := 1 # Default 100 feet
var chipping_hud: CanvasLayer = null
var chipping_target_lbl: Label = null
var chipping_attempts_lbl: Label = null
var chipping_hits_lbl: Label = null
var chipping_accuracy_lbl: Label = null
var chipping_banner_lbl: Label = null
var chipping_buttons: Array[Button] = []
var chipping_islands: Array[StaticBody3D] = []
var chipping_distances = [50, 100, 150, 200, 250, 300] # in feet
var chipping_lateral_offsets = [-15, 20, -25, 30, -35, 25] # in feet, staggered left/right



# Visual effects references
var vignette_layer: CanvasLayer = null
var vignette_rect: ColorRect = null
var camera_attributes: CameraAttributesPractical = null


func get_height(x: float, z: float) -> float:
	if is_driving_range:
		return 0.0
		
	if _height_raycast != null:
		_height_raycast.global_position = Vector3(x, 1000.0, z)
		_height_raycast.target_position = Vector3(0.0, -2000.0, 0.0)
		var max_passes = 8
		var hit_y: Variant = null
		while max_passes > 0:
			max_passes -= 1
			_height_raycast.force_raycast_update()
			if not _height_raycast.is_colliding():
				break
			var collider = _height_raycast.get_collider()
			if collider:
				if collider.get_meta("is_obstacle", false) == true:
					_height_raycast.add_exception(collider)
					continue
				if collider.has_meta("surface_type") or collider.name.contains("Terrain") or collider.name.contains("Rough") or collider.name.contains("green") or collider.name.contains("fairway") or collider.name.contains("tee") or collider.name.contains("bunker"):
					hit_y = _height_raycast.get_collision_point().y
					break
			# Non-terrain collider (e.g. ball, tree branch, player prop): exclude and raycast through it
			_height_raycast.add_exception(collider)
		_height_raycast.clear_exceptions()
		if hit_y != null:
			return hit_y
	elif is_inside_tree() and get_world_3d() != null and get_world_3d().direct_space_state != null:
		var space_state = get_world_3d().direct_space_state
		var ray_origin = Vector3(x, 1000.0, z)
		var ray_end = Vector3(x, -2000.0, z)
		var exclude_rids: Array[RID] = []
		var max_passes = 8
		while max_passes > 0:
			max_passes -= 1
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1, exclude_rids)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit = space_state.intersect_ray(query)
			if hit.is_empty():
				break
			var collider = hit.get("collider")
			if collider:
				if collider.get_meta("is_obstacle", false) == true:
					if collider is CollisionObject3D:
						exclude_rids.append(collider.get_rid())
					continue
				if collider.has_meta("surface_type") or collider.name.contains("Terrain") or collider.name.contains("Rough") or collider.name.contains("green") or collider.name.contains("fairway") or collider.name.contains("tee") or collider.name.contains("bunker"):
					return hit["position"].y
			if collider and collider is CollisionObject3D:
				exclude_rids.append(collider.get_rid())
			else:
				break
				
	if _has_elevation_map:
		return sample_elevation(x, z)
		
	# Gradual, natural golf course topography with broad wavelengths (800m - 1500m)
	# producing gentle ~1% grades with at most 1 gradual rise or fall across an entire hole.
	var h = sin(x * 0.0042 + z * 0.0031) * cos(z * 0.0051 - x * 0.0036) * 1.2 + sin(x * 0.0078 - z * 0.0062) * 0.5
	return h


func _load_elevation_map() -> void:
	var scene_dir = scene_file_path.get_base_dir()
	var path = scene_dir.path_join("elevation.dat")
	if not FileAccess.file_exists(path):
		print("[range.gd] Elevation map not found at: ", path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[range.gd] Failed to open elevation map: ", path)
		return
		
	var version = file.get_32()
	if version != 2:
		print("[range.gd] Unsupported elevation map version: ", version)
		return
		
	_elevation_width = file.get_32()
	_elevation_height = file.get_32()
	_elevation_left_lon = file.get_double()
	_elevation_right_lon = file.get_double()
	_elevation_top_lat = file.get_double()
	_elevation_bottom_lat = file.get_double()
	_elevation_ref_lat = file.get_double()
	_elevation_ref_lon = file.get_double()
	_elevation_meters_per_lat = file.get_double()
	_elevation_meters_per_lon = file.get_double()
	_elevation_offset = file.get_float()
	
	var num_elements = _elevation_width * _elevation_height
	_elevation_data.resize(num_elements)
	var min_val: float = INF
	var max_val: float = -INF
	for i in range(num_elements):
		var v = file.get_float()
		_elevation_data[i] = v
		if v < min_val:
			min_val = v
		if v > max_val:
			max_val = v
		
	# Check if elevation data is completely flat (e.g. failed/deprecated tiles or unpopulated)
	if abs(max_val - min_val) < 0.5:
		print("[range.gd] Elevation map is completely flat (range: %0.2fm). Falling back to procedural elevation." % (max_val - min_val))
		_has_elevation_map = false
		return

	_has_elevation_map = true
	print("[range.gd] Loaded elevation map: %dx%d (range: %0.2fm)" % [_elevation_width, _elevation_height, max_val - min_val])


func sample_elevation(x: float, z: float) -> float:
	var lon = _elevation_ref_lon + x / _elevation_meters_per_lon
	var lat = _elevation_ref_lat - z / _elevation_meters_per_lat
	
	var u = (lon - _elevation_left_lon) / (_elevation_right_lon - _elevation_left_lon)
	
	var y_val = log(tan(lat * PI / 360.0 + PI / 4.0))
	var y_top = log(tan(_elevation_top_lat * PI / 360.0 + PI / 4.0))
	var y_bottom = log(tan(_elevation_bottom_lat * PI / 360.0 + PI / 4.0))
	var v = (y_val - y_top) / (y_bottom - y_top)
	
	u = clamp(u, 0.0, 1.0)
	v = clamp(v, 0.0, 1.0)
	
	var w = _elevation_width
	var h = _elevation_height
	
	var sample_x = u * (w - 1)
	var sample_y = v * (h - 1)
	
	var x0 = clamp(floor(sample_x), 0, w - 1)
	var x1 = clamp(x0 + 1, 0, w - 1)
	var y0 = clamp(floor(sample_y), 0, h - 1)
	var y1 = clamp(y0 + 1, 0, h - 1)
	
	var tx = sample_x - x0
	var ty = sample_y - y0
	
	var h00 = _elevation_data[y0 * w + x0]
	var h10 = _elevation_data[y0 * w + x1]
	var h01 = _elevation_data[y1 * w + x0]
	var h11 = _elevation_data[y1 * w + x1]
	
	var h0 = h00 * (1.0 - tx) + h10 * tx
	var h1 = h01 * (1.0 - tx) + h11 * tx
	var raw_h = h0 * (1.0 - ty) + h1 * ty
	
	return raw_h - _elevation_offset


func _generate_ground_terrain() -> void:
	var min_x := -150.0   # Covers under mountain backdrop behind tee
	var max_x := 490.0    # Covers under mountain backdrop down range
	var min_z := -450.0   # Covers lateral mountain boundary
	var max_z := 450.0
	var subdiv_x := 180
	var subdiv_z := 150
	
	var cell_w := (max_x - min_x) / subdiv_x
	var cell_d := (max_z - min_z) / subdiv_z
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat: Material = null
	var shader = load("res://Courses/Environments/shaders/driving_range_turf.gdshader")
	if shader:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("tex_fairway", load("res://Courses/Environments/grass-fairway/albedo.png"))
		sm.set_shader_parameter("normal_fairway", load("res://Courses/Environments/grass-fairway/normal.png"))
		sm.set_shader_parameter("ao_fairway", load("res://Courses/Environments/grass-fairway/ao.png"))
		sm.set_shader_parameter("roughness_fairway", load("res://Courses/Environments/grass-fairway/roughness.png"))
		
		sm.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
		sm.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
		sm.set_shader_parameter("ao_rough", load("res://Courses/Environments/grass-rough/ao.png"))
		sm.set_shader_parameter("roughness_rough", load("res://Courses/Environments/grass-rough/roughness.png"))
		
		sm.set_shader_parameter("corridor_half_width", 26.0)
		sm.set_shader_parameter("blend_margin", 0.85)
		sm.set_shader_parameter("tee_start_x", -12.0)
		sm.set_shader_parameter("tee_blend_x", 4.0)
		sm.set_shader_parameter("max_range_dist", 320.04)
		sm.set_shader_parameter("uv_scale_fairway", 0.12)
		sm.set_shader_parameter("uv_scale_rough", 0.08)
		sm.set_shader_parameter("normal_depth", 0.65)
		sm.set_shader_parameter("stripe_strength", 0.70)
		mat = sm
	else:
		var std_mat := StandardMaterial3D.new()
		std_mat.albedo_color = Color(0.24, 0.54, 0.20)
		std_mat.roughness = 0.95
		mat = std_mat
	st.set_material(mat)
	
	for z in range(subdiv_z):
		for x in range(subdiv_x):
			var x0 := min_x + x * cell_w
			var x1 := x0 + cell_w
			var z0 := min_z + z * cell_d
			var z1 := z0 + cell_d
			
			var p00 := Vector3(x0, get_height(x0, z0), z0)
			var p10 := Vector3(x1, get_height(x1, z0), z0)
			var p01 := Vector3(x0, get_height(x0, z1), z1)
			var p11 := Vector3(x1, get_height(x1, z1), z1)
			
			var uv00 := Vector2(x0, z0) * 0.05
			var uv10 := Vector2(x1, z0) * 0.05
			var uv01 := Vector2(x0, z1) * 0.05
			var uv11 := Vector2(x1, z1) * 0.05
			
			# Triangle 1
			st.set_uv(uv00)
			st.add_vertex(p00)
			st.set_uv(uv10)
			st.add_vertex(p10)
			st.set_uv(uv01)
			st.add_vertex(p01)
			
			# Triangle 2
			st.set_uv(uv10)
			st.add_vertex(p10)
			st.set_uv(uv11)
			st.add_vertex(p11)
			st.set_uv(uv01)
			st.add_vertex(p01)
			
	st.generate_normals()
	st.generate_tangents()
	
	var mesh := st.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "DynamicGround"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	
	var static_body := StaticBody3D.new()
	static_body.name = "StaticBody3D"
	mesh_instance.add_child(static_body)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)


func _enter_tree() -> void:
	var p_path = scene_file_path.to_lower()
	is_driving_range = (p_path.ends_with("range/range.tscn") or p_path.ends_with("range.tscn") or p_path.ends_with("range.scn") or (name.to_lower() == "range" and not p_path.contains("course")))
	set_meta("is_driving_range", is_driving_range)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var p_path = scene_file_path.to_lower()
	is_driving_range = (p_path.ends_with("range/range.tscn") or p_path.ends_with("range.tscn") or p_path.ends_with("range.scn") or (name.to_lower() == "range" and not p_path.contains("course")))
	set_meta("is_driving_range", is_driving_range)
	if is_driving_range:
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null:
			mp_mgr.players.clear()
		_generate_ground_terrain()
	else:
		_load_elevation_map()
		_height_raycast = RayCast3D.new()
		_height_raycast.collision_mask = 1 # Terrain collision layer
		_height_raycast.collide_with_areas = false
		_height_raycast.collide_with_bodies = true
		_height_raycast.enabled = false
		add_child(_height_raycast)
	# Initialize Camera3DResource on PhantomCamera3D for dynamic fov/far changes
	if has_node("PhantomCamera3D"):
		var pcam = $PhantomCamera3D
		if pcam.camera_3d_resource == null:
			var res_script = load("res://addons/phantom_camera/scripts/resources/camera_3d_resource.gd")
			if res_script:
				pcam.camera_3d_resource = res_script.new()

	if has_node("Camera3D"):
		$Camera3D.reset_physics_interpolation()
	if has_node("PhantomCamera3D"):
		$PhantomCamera3D.reset_physics_interpolation()

	var pcam_host = find_child("PhantomCameraHost", true, false)
	if pcam_host != null and "interpolation_mode" in pcam_host:
		pcam_host.interpolation_mode = 1 # InterpolationMode.IDLE to smoothly track physics via Godot 4 interpolation

	_init_cached_surface_bodies()

	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(set_camera_follow_mode)
	set_camera_follow_mode(GlobalSettings.range_settings.camera_follow_mode.value)
	if GlobalSettings.range_settings.settings.has("shot_replay_follow"):
		GlobalSettings.range_settings.shot_replay_follow.setting_changed.connect(_on_shot_replay_follow_changed)
	GlobalSettings.range_settings.camera_height.setting_changed.connect(update_camera_offset)
	GlobalSettings.range_settings.camera_distance.setting_changed.connect(update_camera_offset)
	GlobalSettings.range_settings.camera_fov.setting_changed.connect(update_camera_fov)
	GlobalSettings.range_settings.camera_far.setting_changed.connect(update_camera_far)
	update_camera_offset()
	update_camera_fov(GlobalSettings.range_settings.camera_fov.value)
	update_camera_far(GlobalSettings.range_settings.camera_far.value)
	if has_node("/root/ScreenOffsetManager") and has_node("PhantomCamera3D"):
		ScreenOffsetManager.register_camera($PhantomCamera3D)
		ScreenOffsetManager.on_ready_for_shot(0.0, true)
	
	# Disconnect Player's direct connection to RangeUI's hit_shot signal to control execution order
	if has_node("RangeUI") and has_node("Player"):
		if $RangeUI.is_connected("hit_shot", Callable($Player, "_on_range_ui_hit_shot")):
			$RangeUI.disconnect("hit_shot", Callable($Player, "_on_range_ui_hit_shot"))
			
	if has_node("RangeUI"):
		if not $RangeUI.is_connected("hit_shot", Callable(self, "_on_range_ui_hit_shot")):
			$RangeUI.connect("hit_shot", Callable(self, "_on_range_ui_hit_shot"))
		if not $RangeUI.skip_flight_requested.is_connected(_on_skip_flight_requested):
			$RangeUI.skip_flight_requested.connect(_on_skip_flight_requested)
		if $RangeUI.has_signal("player_profile_changed") and not $RangeUI.player_profile_changed.is_connected(_on_player_profile_changed):
			$RangeUI.player_profile_changed.connect(_on_player_profile_changed)
		if $RangeUI.has_signal("shot_traces_toggled") and not $RangeUI.shot_traces_toggled.is_connected(_on_shot_traces_toggled):
			$RangeUI.shot_traces_toggled.connect(_on_shot_traces_toggled)
		if $RangeUI.has_signal("stuck_ball_requested") and not $RangeUI.stuck_ball_requested.is_connected(_on_stuck_ball_requested):
			$RangeUI.stuck_ball_requested.connect(_on_stuck_ball_requested)
		var init_player = $RangeUI.get_selected_player_name() if $RangeUI.has_method("get_selected_player_name") else "Player 1"
		if has_node("SessionRecorder"):
			$SessionRecorder.username = init_player
		if has_node("Player") and $Player.has_method("set_profile"):
			$Player.set_profile(init_player)
		var mp_mgr_init = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr_init != null and has_node("/root/LaunchMonitorManager"):
			var lm_init = get_node("/root/LaunchMonitorManager")
			if lm_init != null and lm_init.has_method("set_handedness"):
				lm_init.set_handedness(mp_mgr_init.get_player_handedness(init_player))

	if is_driving_range:
		_setup_shot_trace_overlay()
		if has_node("RangeUI") and $RangeUI.has_method("is_shot_traces_active") and $RangeUI.is_shot_traces_active():
			_on_shot_traces_toggled(true)
			
	# Visual effects setup
	if has_node("Sky3D"):
		MobilePerformance.optimize_sky3d($Sky3D)
	MobilePerformance.optimize_scene(self)
	var range_quality = GlobalSettings.get_graphics_quality() if GlobalSettings != null else "High"
	MobilePerformance.apply_graphics_quality(self, range_quality)
	setup_depth_of_field()
	setup_vignette()
	setup_atmospheric_fog()
	GlobalSettings.range_settings.dof_enabled.setting_changed.connect(update_dof_enabled)
	GlobalSettings.range_settings.dof_blur_amount.setting_changed.connect(update_dof_blur_amount)
	GlobalSettings.range_settings.vignette_enabled.setting_changed.connect(update_vignette_enabled)
	GlobalSettings.range_settings.vignette_intensity.setting_changed.connect(update_vignette_intensity)
	
	GlobalSettings.range_settings.gimme_range_1_enabled.setting_changed.connect(func(_val): update_gimme_circles())
	GlobalSettings.range_settings.gimme_range_1_distance.setting_changed.connect(func(_val): update_gimme_circles())
	GlobalSettings.range_settings.gimme_range_2_enabled.setting_changed.connect(func(_val): update_gimme_circles())
	GlobalSettings.range_settings.gimme_range_2_distance.setting_changed.connect(func(_val): update_gimme_circles())
	GlobalSettings.range_settings.gimme_range_3_enabled.setting_changed.connect(func(_val): update_gimme_circles())
	GlobalSettings.range_settings.gimme_range_3_distance.setting_changed.connect(func(_val): update_gimme_circles())
	if GlobalSettings.range_settings.settings.has("wind_enabled"):
		GlobalSettings.range_settings.wind_enabled.setting_changed.connect(func(_val): _update_aim_distance_label_text())
	if GlobalSettings.has_signal("wind_changed"):
		GlobalSettings.wind_changed.connect(func(_spd, _dir): _update_aim_distance_label_text())
	GlobalSettings.start_round_wind(false)
	if has_node("/root/LaunchMonitorManager"):
		var launch_monitor = get_node("/root/LaunchMonitorManager")
		if not launch_monitor.hit_ball.is_connected(_on_launch_monitor_hit_ball):
			launch_monitor.hit_ball.connect(_on_launch_monitor_hit_ball)
		if launch_monitor.has_method("set_ready") and not launch_monitor.get("is_ready"):
			launch_monitor.call("set_ready")
	var is_practice_mode_primed: bool = GlobalSettings.practice_mode_primed
	var is_multiplayer_game = has_node("/root/MultiplayerManager") and get_node("/root/MultiplayerManager").players.size() > 1
	if is_practice_mode_primed and not is_multiplayer_game:
		practice_mode_active = true
		GlobalSettings.practice_mode_primed = false
	else:
		practice_mode_active = false
		GlobalSettings.practice_mode_primed = false
	if has_node("Camera3D"):
		$Camera3D.cull_mask = $Camera3D.cull_mask & ~2
	if has_node("PhantomCamera3D"):
		$PhantomCamera3D.cull_mask = $PhantomCamera3D.cull_mask & ~2
	if has_node("AerialCamera"):
		$AerialCamera.cull_mask = (1 << 0) | (1 << 1)

	if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
		var play_script = load("res://Courses/CoursePlay/course_play.gd")
		var play_controller = Node3D.new()
		play_controller.set_script(play_script)
		play_controller.name = "MultiplayerController"
		add_child(play_controller)

	# Create Aerial Camera dynamically if it doesn't exist
	if not has_node("AerialCamera"):
		var aerial_cam = Camera3D.new()
		aerial_cam.name = "AerialCamera"
		aerial_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		aerial_cam.size = aerial_zoom
		aerial_cam.position = Vector3(0, 150, 0)
		aerial_cam.rotation = Vector3(-PI/2, 0, 0) # Look straight down
		aerial_cam.cull_mask = (1 << 0) | (1 << 1)
		add_child(aerial_cam)

	# Create Aim Marker flag/mesh dynamically
	var marker = MeshInstance3D.new()
	marker.name = "AimMarker"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 15.0
	marker.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2) # Neon Red
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.render_priority = 2
	marker.material_override = mat
	marker.layers = 2
	add_child(marker)
	marker.global_position = aim_target_pos
	marker.visible = false # Visible only in map view / minimap

	# Create Player Marker dynamically (Glowing green cylinder)
	var p_marker = MeshInstance3D.new()
	p_marker.name = "PlayerMarker"
	var p_cyl = CylinderMesh.new()
	p_cyl.top_radius = 0.4
	p_cyl.bottom_radius = 0.4
	p_cyl.height = 12.0
	p_marker.mesh = p_cyl
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.1, 1.0, 0.1) # Neon Green
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.1, 1.0, 0.1)
	p_mat.render_priority = 2
	p_marker.material_override = p_mat
	p_marker.layers = 2
	
	# Add static 2D billboard golf ball sprite to player marker for map/aerial view
	var p_sprite = Sprite3D.new()
	p_sprite.name = "MapBallSprite"
	p_sprite.layers = 2
	p_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	p_sprite.no_depth_test = true
	p_sprite.render_priority = 3
	p_sprite.double_sided = true
	p_sprite.pixel_size = 0.04
	p_sprite.position = Vector3(0, 6.0, 0)
	if ResourceLoader.exists("res://assets/images/icons/golf_ball_icon.svg"):
		p_sprite.texture = load("res://assets/images/icons/golf_ball_icon.svg")
	p_marker.add_child(p_sprite)

	add_child(p_marker)
	p_marker.global_position = Vector3.ZERO
	p_marker.visible = false # Visible only in map view / minimap

	# Create Hole Outline Line dynamically
	var outline_inst = MeshInstance3D.new()
	outline_inst.name = "HoleOutline"
	var outline_imm = ImmediateMesh.new()
	outline_inst.mesh = outline_imm
	var outline_mat = StandardMaterial3D.new()
	outline_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5) # Semi-transparent light red
	outline_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_mat.no_depth_test = true
	outline_mat.render_priority = 2
	outline_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_inst.material_override = outline_mat
	outline_inst.layers = 2
	add_child(outline_inst)
	outline_inst.visible = false

	# Create Minimap Hole Outline Line dynamically (thicker for minimap viewport)
	var minimap_outline_inst = MeshInstance3D.new()
	minimap_outline_inst.name = "MinimapHoleOutline"
	var minimap_outline_imm = ImmediateMesh.new()
	minimap_outline_inst.mesh = minimap_outline_imm
	var minimap_outline_mat = StandardMaterial3D.new()
	minimap_outline_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5) # Semi-transparent light red
	minimap_outline_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	minimap_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	minimap_outline_mat.no_depth_test = true
	minimap_outline_mat.render_priority = 2
	minimap_outline_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	minimap_outline_inst.material_override = minimap_outline_mat
	minimap_outline_inst.layers = 2
	add_child(minimap_outline_inst)
	minimap_outline_inst.visible = false

	# Create Map Canvas Layer to prevent container stretching
	var canvas = CanvasLayer.new()
	canvas.name = "MapCanvas"
	canvas.visible = true
	add_child(canvas)

	# Initialize AimDistanceIndicator (3D reticle + floating distance card with guideline)
	_aim_distance_indicator = AimDistanceIndicator.new()
	_aim_distance_indicator.initialize(self)
	add_child(_aim_distance_indicator)

	# HBoxContainer for zoom buttons in Aerial View (placed top middle below the distance label)
	var zoom_vbox = HBoxContainer.new()
	zoom_vbox.name = "AerialZoomVBox"
	zoom_vbox.visible = is_aerial_view
	zoom_vbox.anchor_left = 0.5
	zoom_vbox.anchor_right = 0.5
	zoom_vbox.anchor_top = 0.0
	zoom_vbox.anchor_bottom = 0.0
	zoom_vbox.offset_left = -115
	zoom_vbox.offset_top = 152
	zoom_vbox.offset_right = 115
	zoom_vbox.offset_bottom = 212
	zoom_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zoom_vbox.grow_vertical = Control.GROW_DIRECTION_END
	zoom_vbox.add_theme_constant_override("separation", 12)
	canvas.add_child(zoom_vbox)

	var zoom_in_btn = Button.new()
	zoom_in_btn.name = "ZoomInButton"
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(56, 56)
	apply_circular_button_style(zoom_in_btn, Color(0.15, 0.15, 0.15, 0.85))
	zoom_in_btn.pressed.connect(func():
		aerial_zoom = clamp(aerial_zoom - 25.0, 50.0, 500.0)
		if _last_zoom_zone == 0:
			_teebox_aerial_zoom = aerial_zoom
			_default_non_green_aerial_zoom = aerial_zoom
	)
	zoom_vbox.add_child(zoom_in_btn)

	var zoom_out_btn = Button.new()
	zoom_out_btn.name = "ZoomOutButton"
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(56, 56)
	apply_circular_button_style(zoom_out_btn, Color(0.15, 0.15, 0.15, 0.85))
	zoom_out_btn.pressed.connect(func():
		aerial_zoom = clamp(aerial_zoom + 25.0, 50.0, 500.0)
		if _last_zoom_zone == 0:
			_teebox_aerial_zoom = aerial_zoom
			_default_non_green_aerial_zoom = aerial_zoom
	)
	zoom_vbox.add_child(zoom_out_btn)

	var grid_toggle_btn = Button.new()
	grid_toggle_btn.name = "GridToggleButton"
	grid_toggle_btn.text = "📊"
	grid_toggle_btn.tooltip_text = "Toggle Slope Grid & Heatmap"
	grid_toggle_btn.custom_minimum_size = Vector2(56, 56)
	var btn_color = Color(0.2, 0.6, 0.3, 0.85) if show_green_grid else Color(0.15, 0.15, 0.15, 0.85)
	apply_circular_button_style(grid_toggle_btn, btn_color)
	grid_toggle_btn.pressed.connect(func():
		show_green_grid = not show_green_grid
	)
	zoom_vbox.add_child(grid_toggle_btn)

	# Create Aim Distance Badge background Panel
	var badge = Panel.new()
	badge.name = "AimDistanceBadge"
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.08, 0.08, 0.8) # Premium dark translucent
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.3, 0.3, 0.3, 0.8)
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	badge.add_theme_stylebox_override("panel", badge_style)
	
	badge.anchor_left = 0.5
	badge.anchor_right = 0.5
	badge.offset_left = -260
	badge.offset_top = 18
	badge.offset_right = 260
	badge.offset_bottom = 76
	canvas.add_child(badge)

	# Create AimDistanceLabel (path remains MapCanvas/AimDistanceLabel!)
	var aim_lbl = RichTextLabel.new()
	aim_lbl.name = "AimDistanceLabel"
	aim_lbl.bbcode_enabled = true
	aim_lbl.scroll_active = false
	aim_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	aim_lbl.text = "[center]🎯 Aim: --- | ⛰️ Elevation: 0 Feet | 🟢 Fairway[/center]"
	aim_lbl.add_theme_font_size_override("normal_font_size", 16)
	aim_lbl.add_theme_font_size_override("bold_font_size", 20)
	var bold_var = FontVariation.new()
	bold_var.base_font = aim_lbl.get_theme_font("font")
	bold_var.variation_embolden = 1.8
	aim_lbl.add_theme_font_override("bold_font", bold_var)
	aim_lbl.add_theme_color_override("default_color", Color(0.96, 0.98, 1.0))
	aim_lbl.add_theme_constant_override("outline_size", 4)
	aim_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	aim_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aim_lbl.anchor_left = 0.5
	aim_lbl.anchor_right = 0.5
	aim_lbl.offset_left = -260
	aim_lbl.offset_top = 18
	aim_lbl.offset_right = 260
	aim_lbl.offset_bottom = 46
	aim_lbl.visible = true
	canvas.add_child(aim_lbl)

	# Create Weather & Lighting Controller (Moon/Sun slider and Sun/Rain toggle)
	_weather_lighting_controller = WeatherLightingController.new()
	_weather_lighting_controller.name = "WeatherLightingController"
	add_child(_weather_lighting_controller)
	_weather_lighting_controller.initialize(self, canvas)

	# Create labels inside MapCanvas
	var hole_lbl = Label.new()
	hole_lbl.name = "HoleInfoLabel"
	hole_lbl.visible = is_aerial_view
	hole_lbl.text = "Hole 1 | Par 4 | --- Yards"
	hole_lbl.add_theme_font_size_override("font_size", 20)
	hole_lbl.add_theme_color_override("font_color", Color.WHITE)
	# Position at top center, below the weather/aim badge
	hole_lbl.anchor_left = 0.5
	hole_lbl.anchor_right = 0.5
	hole_lbl.offset_left = -200
	hole_lbl.offset_top = 84
	hole_lbl.offset_bottom = 120
	hole_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(hole_lbl)

	# Hide duplicate HoleInfoLabel if in course play mode
	var is_course_play = false
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if not mp.players.is_empty():
			is_course_play = true
	if is_course_play:
		hole_lbl.visible = false

	# Create Aim Line dynamically for drawing aiming direction
	aim_line = MeshInstance3D.new()
	aim_line.name = "AimLine"
	var imm = ImmediateMesh.new()
	aim_line.mesh = imm
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 0.2, 0.2) # Neon Red
	line_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	line_mat.render_priority = 2
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aim_line.material_override = line_mat
	aim_line.layers = 2
	add_child(aim_line)
	aim_line.visible = false

	# Load course.json to position the player at the Tee Box of Hole 1 (if in practice mode)
	var course_json_path = ""
	var course_mgr = get_node_or_null("/root/CourseManager")
	if course_mgr != null and course_mgr.has_method("get_current_config_path"):
		course_json_path = course_mgr.get_current_config_path()
	if course_json_path.is_empty():
		course_json_path = scene_file_path.get_base_dir() + "/course.json"

	if FileAccess.file_exists(course_json_path):
		var file = FileAccess.open(course_json_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				course_data_dict = json.data
				if practice_mode_active:
					if GlobalSettings.is_chipping_minigame:
						var hole_info_data = course_data_dict.get("Hole Info", {})
						var hole_keys = hole_info_data.keys()
						hole_keys.sort()
						var target_idx = hole_keys.find("Hole 17")
						if target_idx != -1:
							load_practice_hole(target_idx)
						else:
							load_practice_hole(0)
						set_practice_mode(true)
						_setup_chipping_minigame()
					else:
						load_practice_hole(0)
						set_practice_mode(true)
				else:
					var hole_info_data = course_data_dict.get("Hole Info", {})
					var hole_keys = hole_info_data.keys()
					hole_keys.sort()
					if not hole_keys.is_empty():
						var start_hole_id = hole_keys[0]
						var mp_mgr = get_node_or_null("/root/MultiplayerManager")
						if mp_mgr != null and not mp_mgr.players.is_empty() and mp_mgr.current_hole_index < mp_mgr.hole_ids.size():
							start_hole_id = mp_mgr.hole_ids[mp_mgr.current_hole_index]
						
						var first_hole = hole_info_data.get(start_hole_id, hole_info_data[hole_keys[0]])
						var tee_boxes = first_hole.get("Tee Boxes", {})
						var player_tee = "Blue"
						if mp_mgr != null and not mp_mgr.players.is_empty():
							var ap = mp_mgr.get_active_player()
							if not ap.is_empty() and not str(ap.get("tee", "")).is_empty():
								player_tee = ap.get("tee")

						var tee_pos = null
						if tee_boxes.has(player_tee):
							tee_pos = tee_boxes[player_tee]
						else:
							for k in tee_boxes.keys():
								if str(k).to_lower() == player_tee.to_lower():
									tee_pos = tee_boxes[k]
									break
						if tee_pos == null:
							if tee_boxes.has("Blue"):
								tee_pos = tee_boxes["Blue"]
							elif not tee_boxes.is_empty():
								tee_pos = tee_boxes.values()[0]
						if tee_pos != null:
							var spawn_pos = Vector3(tee_pos[0], get_height(tee_pos[0], tee_pos[1]) + 0.059435, tee_pos[1])
							practice_start_pos = spawn_pos
							var hole_loc = first_hole.get("Hole Location")
							var par = first_hole.get("Par", 4)
							var hole_name = first_hole.get("Name", start_hole_id)
							current_hole_id = start_hole_id
							current_hole_name = hole_name
							current_hole_par = par
							if hole_loc != null:
								current_hole_location = get_hole_location_for(hole_loc)
								aim_target_pos = current_hole_location
							
							var is_mp = mp_mgr != null and not mp_mgr.players.is_empty()
							if is_mp:
								# Multiplayer controller (course_play.gd) handles positioning, cameras, and HUD.
								# We only need to ensure the flag pin is spawned.
								if hole_loc != null:
									_spawn_flag_pin()
									update_teebox_markers(player_tee)
							else:
								if has_node("Player") and $Player.ball != null:
									$Player.ball.spawn_position = spawn_pos
									$Player.ball.reset()
								
								if hole_loc != null:
									var dist_to_pin_yards = int(spawn_pos.distance_to(current_hole_location) * 1.09361)
									current_hole_tee_dist_yards = dist_to_pin_yards
									hole_lbl.text = "%s | Par %d | %d Yards | Ball: %d Yards to Pin" % [hole_name, par, dist_to_pin_yards, dist_to_pin_yards]
									update_auto_club()
									apply_default_aim()
									_spawn_flag_pin()
									update_teebox_markers(player_tee)
								
							print("[CoursePlay] Player positioned at %s Tee: " % start_hole_id, spawn_pos, " | Aiming at green: ", aim_target_pos)

	# Programmatically connect dynamic course play signals
	var player_node = get_node_or_null("Player")
	var range_ui = get_node_or_null("RangeUI")
	
	var session_rec = get_node_or_null("SessionRecorder")
	if session_rec == null:
		var rec_script = load("res://SessionRecorder/session_recorder.gd")
		if rec_script != null:
			session_rec = Node.new()
			session_rec.set_script(rec_script)
			session_rec.name = "SessionRecorder"
			add_child(session_rec)
			print("[range.gd] Dynamically created missing SessionRecorder node!")

	var tcp_server = get_node_or_null("TCPServer")
	var old_tcp_server = get_node_or_null("TcpServer")
	if old_tcp_server != null:
		if tcp_server == null:
			tcp_server = old_tcp_server
			tcp_server.name = "TCPServer"
			print("[range.gd] Renamed lowercase TcpServer to TCPServer for compatibility")
		else:
			old_tcp_server.free()
			print("[range.gd] Freed duplicate lowercase TcpServer node to prevent port conflicts!")

	if tcp_server == null:
		var tcp_script = load("res://addons/launch_monitors/common/tcp_server/TcpServer.cs")
		if tcp_script != null:
			tcp_server = tcp_script.new()
			tcp_server.name = "TCPServer"
			add_child(tcp_server)
			print("[range.gd] Dynamically created missing TCPServer node!")
	
	if player_node != null:
		var self_rest_callable = Callable(self, "_on_golf_ball_rest")
		if not player_node.is_connected("rest", self_rest_callable):
			player_node.connect("rest", self_rest_callable)
		if session_rec != null:
			var rec_rest_callable = Callable(session_rec, "_on_golf_ball_rest")
			if not player_node.is_connected("rest", rec_rest_callable):
				player_node.connect("rest", rec_rest_callable)
		var self_hit_callable = Callable(self, "_on_player_manual_hit")
		if player_node.has_signal("manual_hit") and not player_node.is_connected("manual_hit", self_hit_callable):
			player_node.connect("manual_hit", self_hit_callable)
				
	if range_ui != null and session_rec != null:
		if range_ui.has_signal("rec_button_pressed"):
			var toggle_rec_callable = Callable(session_rec, "toggle_recording")
			if not range_ui.is_connected("rec_button_pressed", toggle_rec_callable):
				range_ui.connect("rec_button_pressed", toggle_rec_callable)
		if range_ui.has_signal("set_session"):
			var set_sess_callable = Callable(session_rec, "_on_range_ui_set_session")
			if not range_ui.is_connected("set_session", set_sess_callable):
				range_ui.connect("set_session", set_sess_callable)
			
		if session_rec.has_signal("recording_state"):
			var rec_state_callable = Callable(range_ui, "_on_session_recorder_recording_state")
			if not session_rec.is_connected("recording_state", rec_state_callable):
				session_rec.connect("recording_state", rec_state_callable)
		if session_rec.has_signal("set_session"):
			var ui_set_sess_callable = Callable(range_ui, "_on_session_recorder_set_session")
			if not session_rec.is_connected("set_session", ui_set_sess_callable):
				session_rec.connect("set_session", ui_set_sess_callable)

	# Connect TCPServer signals dynamically for dynamic course play shot injection
	if tcp_server != null:
		if tcp_server.has_signal("HitBall"):
			var hit_ball_callable = Callable(self, "_on_tcp_client_hit_ball")
			if not tcp_server.is_connected("HitBall", hit_ball_callable):
				tcp_server.connect("HitBall", hit_ball_callable)
			
			# Player's connection is bypassed and handled sequentially in _on_tcp_client_hit_ball
			pass
				
		if player_node != null:
			if player_node.has_signal("bad_data"):
				var bad_callable = Callable(tcp_server, "_on_player_bad_data")
				if not player_node.is_connected("bad_data", bad_callable):
					player_node.connect("bad_data", bad_callable)
			if player_node.has_signal("good_data"):
				var good_callable = Callable(tcp_server, "_on_golf_ball_good_data")
				if not player_node.is_connected("good_data", good_callable):
					player_node.connect("good_data", good_callable)
	update_auto_club()
	update_hole_outline()
	if is_driving_range:
		call_deferred("_spawn_driving_range_elements")

	# Player-club stats setup
	if has_node("/root/EventBus"):
		if not get_node("/root/EventBus").is_connected("club_selected", Callable(self, "_on_club_selected")):
			get_node("/root/EventBus").connect("club_selected", Callable(self, "_on_club_selected"))
			
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null:
		if not mp_mgr.active_player_changed.is_connected(Callable(self, "_on_active_player_changed")):
			mp_mgr.active_player_changed.connect(Callable(self, "_on_active_player_changed"))
		if not mp_mgr.hole_completed.is_connected(Callable(self, "_on_hole_completed")):
			mp_mgr.hole_completed.connect(Callable(self, "_on_hole_completed"))
			
	if range_ui != null and range_ui.has_signal("set_session"):
		if not range_ui.is_connected("set_session", Callable(self, "_on_player_changed")):
			range_ui.connect("set_session", Callable(self, "_on_player_changed"))
			
	_update_averages()
	update_current_lie_and_reduction()


var practice_mode_active: bool = false
var practice_start_pos: Vector3 = Vector3(0.0, 0.02, 0.0)
var current_practice_hole_index: int = 0
var place_ball_mode: bool = false


func is_any_dialog_open() -> bool:
	# Check UIFocusGuard: dropdown or manual lock active
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		if guard.is_dropdown_open() or guard.is_locked():
			return true
	# Check if any UI control currently has focus that is actively editing or inside a dialog
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and is_instance_valid(focused) and focused.is_visible_in_tree():
			if focused is LineEdit or focused is TextEdit:
				return true
			if focused is Range or (focused is Control and (focused.get_parent() != null and is_instance_valid(focused.get_parent()) and focused.get_parent() is SpinBox or focused is SpinBox)):
				return true
			if _weather_lighting_controller != null and is_instance_valid(_weather_lighting_controller):
				if focused == _weather_lighting_controller.weather_toggle_btn or focused == _weather_lighting_controller.time_slider:
					return true
			if _is_control_in_dialog(focused):
				return true
	if has_node("RangeUI"):
		var r_ui = $RangeUI
		if r_ui.has_node("SettingsLayer") and r_ui.get_node("SettingsLayer").visible:
			return true
		var dist_m = r_ui.find_child("DistanceMenu", true, false)
		if dist_m != null and is_instance_valid(dist_m) and dist_m.visible:
			return true
		if r_ui.has_method("get_active_swing_replay_modal"):
			var modal = r_ui.get_active_swing_replay_modal()
			if modal != null and is_instance_valid(modal) and modal.visible:
				return true
		var modal = r_ui.get_node_or_null("OverlayLayer/SwingReplayModal")
		if modal != null and is_instance_valid(modal) and modal.visible:
			return true
		if r_ui.get("_detached_window") != null and is_instance_valid(r_ui.get("_detached_window")) and r_ui.get("_detached_window").visible:
			return true
		if r_ui.get("_prev_shot_popup") != null and is_instance_valid(r_ui.get("_prev_shot_popup")) and r_ui.get("_prev_shot_popup").visible:
			return true
		if r_ui.get("_exit_confirm_dialog") != null and is_instance_valid(r_ui.get("_exit_confirm_dialog")) and r_ui.get("_exit_confirm_dialog").visible:
			return true
		var cam_dlg = r_ui.find_child("CameraSetupDialog", true, false)
		if cam_dlg != null and is_instance_valid(cam_dlg) and cam_dlg.visible:
			return true
	var cp = get_node_or_null("MultiplayerController")
	if cp != null and cp.has_method("is_any_dialog_open") and cp.call("is_any_dialog_open"):
		return true
	return false


func _is_control_in_dialog(ctrl: Control) -> bool:
	if ctrl == null or not is_instance_valid(ctrl):
		return false
	var cur: Node = ctrl
	var tree := get_tree()
	var root := tree.root if tree != null else null
	while cur != null and is_instance_valid(cur) and cur != self and cur != root:
		if cur is Popup or cur is AcceptDialog or cur is ConfirmationDialog or cur is Window:
			return true
		var c_name := str(cur.name).to_lower()
		if c_name.contains("modal") or c_name.contains("dialog") or c_name.contains("popup") \
			or c_name == "distancemenu" or c_name == "settingslayer" or c_name == "settingsmodallayer" \
			or c_name == "scorecardpanel" or c_name == "manageplayerspanel":
			return true
		if not cur.is_inside_tree():
			break
		cur = cur.get_parent()
	return false


func _unhandled_input(event: InputEvent) -> void:
	# 1. Close active review screens / popups on Escape or Cancel (B / Circle)
	var is_escape = (event is InputEventKey and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE) or \
		event.is_action_pressed("ui_cancel") or \
		(event is InputEventJoypadButton and event.is_pressed() and event.button_index == JOY_BUTTON_B and is_any_dialog_open())

	if is_escape:
		if is_aerial_view:
			_on_map_button_pressed()
			get_viewport().set_input_as_handled()
			return
		if has_node("RangeUI"):
			var r_ui = $RangeUI
			var dist_m = r_ui.find_child("DistanceMenu", true, false)
			if dist_m != null and is_instance_valid(dist_m) and dist_m.visible:
				dist_m.visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			var modal = r_ui.get_active_swing_replay_modal() if r_ui.has_method("get_active_swing_replay_modal") else r_ui.get_node_or_null("OverlayLayer/SwingReplayModal")
			if modal != null and is_instance_valid(modal) and modal.visible:
				r_ui.toggle_prev_shot_analysis()
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			if r_ui.has_node("SettingsLayer") and r_ui.get_node("SettingsLayer").visible:
				r_ui.get_node("SettingsLayer").visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			if r_ui.get("_prev_shot_popup") != null and is_instance_valid(r_ui.get("_prev_shot_popup")) and r_ui.get("_prev_shot_popup").visible:
				r_ui.get("_prev_shot_popup").visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			if r_ui.get("_detached_window") != null and is_instance_valid(r_ui.get("_detached_window")):
				r_ui.call("_close_detached_window")
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
		var vp := get_viewport()
		if vp != null and vp.gui_get_focus_owner() != null and not _is_control_in_dialog(vp.gui_get_focus_owner()):
			vp.gui_release_focus()
			get_viewport().set_input_as_handled()
			return

	# 2. Previous Shot Analysis Menu Toggle (Xbox Y / PS Triangle / V key)
	if event.is_action_pressed("prev_shot_analysis_toggle") or \
		(event is InputEventJoypadButton and event.is_pressed() and event.button_index == JOY_BUTTON_Y):
		if has_node("RangeUI"):
			$RangeUI.toggle_prev_shot_analysis()
		get_viewport().set_input_as_handled()
		return

	# 3. Block gameplay shortcuts if any modal/dialog is actively open
	if is_any_dialog_open():
		return

	# If any UI control has focus and ui_accept was pressed, do not process global shortcuts
	var vp_focus = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if vp_focus != null and event.is_action_pressed("ui_accept"):
		return

	# In practice mode + aerial view + place_ball_mode: Joypad A / ui_accept places the ball at aim target
	if is_aerial_view and practice_mode_active and place_ball_mode:
		var is_btn_focused = (vp_focus != null and (vp_focus is Button or vp_focus is BaseButton))
		if not is_btn_focused:
			var is_teleport_trigger = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.is_pressed()) or \
				event.is_action_pressed("ui_accept")
			if is_teleport_trigger:
				_perform_practice_teleport_pos(aim_target_pos)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("reset"):
		_reset_display_data()
		$RangeUI.set_data(display_data)
		if has_node("RangeUI") and $RangeUI.has_method("on_next_shot_started"):
			$RangeUI.on_next_shot_started()

	# Keyboard shortcuts & controller button/trigger bindings
	if ((event is InputEventKey and not event.echo) or event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_pressed():
		if event.is_action_pressed("aerial_aim"):
			_on_map_button_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("home"):
			if has_node("RangeUI"):
				$RangeUI.call("_on_home_button_pressed")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("settings"):
			if has_node("RangeUI"):
				$RangeUI.call("_on_toggle_settings_requested")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("mulligan"):
			var course_play_node = get_node_or_null("MultiplayerController")
			if course_play_node != null and course_play_node.has_method("_on_mulligan_pressed"):
				course_play_node.call("_on_mulligan_pressed")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("reset_shot"):
			_reset_display_data()
			$RangeUI.set_data(display_data)
			if has_node("RangeUI") and $RangeUI.has_method("on_next_shot_started"):
				$RangeUI.on_next_shot_started()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("green_grid"):
			show_green_grid = not show_green_grid
			var course_play_node = get_node_or_null("MultiplayerController")
			if course_play_node != null and "grid_btn" in course_play_node:
				var g_btn = course_play_node.grid_btn
				if g_btn != null and is_instance_valid(g_btn):
					var col = Color(0.2, 0.65, 0.35, 0.95) if show_green_grid else Color(0.15, 0.15, 0.15, 0.85)
					course_play_node.call("apply_circular_button_style", g_btn, col)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("toggle_stats"):
			if has_node("RangeUI"):
				$RangeUI.toggle_stats_visibility()
				var course_play_node = get_node_or_null("MultiplayerController")
				if course_play_node != null and "stats_btn" in course_play_node:
					var s_btn = course_play_node.stats_btn
					if s_btn != null and is_instance_valid(s_btn):
						var is_vis = $RangeUI.is_stats_visible()
						var col = Color(0.24, 0.46, 0.72, 0.85) if is_vis else Color(0.15, 0.15, 0.15, 0.85)
						course_play_node.call("apply_circular_button_style", s_btn, col)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("next_club"):
			_cycle_club(true)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("prev_club"):
			_cycle_club(false)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("skip_flight"):
			if has_node("RangeUI"):
				$RangeUI.emit_signal("skip_flight_requested")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("free_cam_toggle"):
			toggle_free_camera()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("hit_shot"):
			if is_free_camera_active():
				get_viewport().set_input_as_handled()
				return
			if has_node("Player"):
				var p = get_node("Player")
				if p.has_method("manual_hit_shot"):
					p.manual_hit_shot()
				elif p.has_method("_on_hit_button_pressed"):
					p._on_hit_button_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("toggle_helpers"):
			if has_node("RangeUI") and $RangeUI.get("_hide_helpers_btn") != null:
				var h_btn = $RangeUI.get("_hide_helpers_btn") as Button
				if h_btn != null and is_instance_valid(h_btn):
					h_btn.emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("announcer_toggle"):
			_toggle_announcer_mute()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("suspense_toggle"):
			_toggle_suspense()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("golfer_cam_toggle"):
			if has_node("RangeUI"):
				var r_ui = $RangeUI
				if not r_ui.is_golfer_camera_enabled():
					r_ui.set_golfer_camera_visible(true)
				elif r_ui.is_golfer_camera_minimized():
					r_ui.restore_golfer_camera()
				else:
					r_ui.set_golfer_camera_visible(false)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("putting_cam_toggle"):
			if has_node("RangeUI"):
				var r_ui = $RangeUI
				if not r_ui.is_putting_camera_enabled():
					r_ui.set_putting_camera_visible(true)
				elif r_ui.is_putting_camera_minimized():
					r_ui.restore_putting_camera()
				else:
					r_ui.set_putting_camera_visible(false)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("shot_analysis_toggle"):
			if has_node("RangeUI"):
				var r_ui = $RangeUI
				var modal = r_ui.get_active_swing_replay_modal() if r_ui.has_method("get_active_swing_replay_modal") else r_ui.get_node_or_null("OverlayLayer/SwingReplayModal")
				if modal != null and is_instance_valid(modal) and modal.visible:
					r_ui.toggle_prev_shot_analysis()
				else:
					var new_v = not $RangeUI.is_shot_analysis_enabled()
					$RangeUI.set_shot_analysis_enabled(new_v)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("prev_shot_analysis_toggle") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y):
			if has_node("RangeUI"):
				$RangeUI.toggle_prev_shot_analysis()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("distance_menu_toggle"):
			_toggle_distance_menu()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("shot_traces_toggle"):
			_toggle_shot_traces()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("rollout_toggle"):
			if has_node("RangeUI") and $RangeUI.has_method("toggle_rollout"):
				$RangeUI.toggle_rollout()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("aim_left") or event.is_action_pressed("aim_right") or \
			 event.is_action_pressed("aim_forward") or event.is_action_pressed("aim_backward"):
			var vp := get_viewport()
			if vp != null and vp.gui_get_focus_owner() != null:
				var foc = vp.gui_get_focus_owner()
				if _is_control_in_dialog(foc) or foc is LineEdit or foc is TextEdit or foc is Range:
					return
				if _weather_lighting_controller != null and is_instance_valid(_weather_lighting_controller):
					if foc == _weather_lighting_controller.weather_toggle_btn or foc == _weather_lighting_controller.time_slider:
						return
				vp.gui_release_focus()
			get_viewport().set_input_as_handled()
			return
		else:
			var handled_stat = _check_stat_toggle_input(event)
			if handled_stat:
				get_viewport().set_input_as_handled()
				return

	# Multi-touch tracking for screen touches and drags
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_last_pinch_distance = -1.0

	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position

	# Handle native OS magnify gestures (touchpads / Android gestures)
	if event is InputEventMagnifyGesture and is_aerial_view:
		var factor: float = event.factor
		if factor > 0.0:
			aerial_zoom = clamp(aerial_zoom / factor, 50.0, 500.0)
			if _last_zoom_zone == 0:
				_teebox_aerial_zoom = aerial_zoom
				_default_non_green_aerial_zoom = aerial_zoom
			get_viewport().set_input_as_handled()
			return

	# Handle 2-finger pinch zoom in aerial view
	if is_aerial_view and _touch_points.size() >= 2:
		var touch_indices = _touch_points.keys()
		var p0: Vector2 = _touch_points[touch_indices[0]]
		var p1: Vector2 = _touch_points[touch_indices[1]]
		var current_dist: float = p0.distance_to(p1)

		if _last_pinch_distance > 0.0:
			var dist_delta: float = current_dist - _last_pinch_distance
			var pinch_sensitivity: float = 0.5
			aerial_zoom = clamp(aerial_zoom - dist_delta * pinch_sensitivity, 50.0, 500.0)
			if _last_zoom_zone == 0:
				_teebox_aerial_zoom = aerial_zoom
				_default_non_green_aerial_zoom = aerial_zoom

		_last_pinch_distance = current_dist
		is_mouse_down_on_map = false
		is_dragging_map = false
		get_viewport().set_input_as_handled()
		return

	# Handle mouse wheel zoom in aerial view
	if event is InputEventMouseButton and is_aerial_view and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			aerial_zoom = clamp(aerial_zoom - 25.0, 50.0, 500.0)
			if _last_zoom_zone == 0:
				_teebox_aerial_zoom = aerial_zoom
				_default_non_green_aerial_zoom = aerial_zoom
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			aerial_zoom = clamp(aerial_zoom + 25.0, 50.0, 500.0)
			if _last_zoom_zone == 0:
				_teebox_aerial_zoom = aerial_zoom
				_default_non_green_aerial_zoom = aerial_zoom
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		if is_free_camera_active():
			return
		if event.pressed:
			if GlobalSettings.is_chipping_minigame and event.button_index == MOUSE_BUTTON_LEFT:
				var camera = get_viewport().get_camera_3d()
				if camera != null:
					var ray_start = camera.project_ray_origin(event.position)
					var ray_dir = camera.project_ray_normal(event.position)
					var ray_end = ray_start + ray_dir * 1000.0
					var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
					var hit = get_world_3d().direct_space_state.intersect_ray(query)
					if not hit.is_empty():
						var clicked_point = hit["position"]
						var closest_idx = -1
						var min_dist = 9999.0
						for i in range(chipping_island_positions.size()):
							var d = clicked_point.distance_to(chipping_island_positions[i])
							if d < min_dist:
								min_dist = d
								closest_idx = i
						if min_dist <= 8.0:
							_select_chipping_target(closest_idx)
							get_viewport().set_input_as_handled()
							return

			if is_aerial_view:
				is_mouse_down_on_map = true
				is_dragging_map = false
				map_drag_start_pos = event.position
				total_map_drag_dist = 0.0
				get_viewport().set_input_as_handled()
			else:
				var ball_at_rest = true
				if $Player and $Player.ball:
					ball_at_rest = ($Player.get_ball_state() == PhysicsEnums.BallState.REST) and not _shot_active
				if ball_at_rest:
					var vp_width = get_viewport().get_visible_rect().size.x
					if event.position.x >= vp_width * 0.5:
						screen_aim_direction = 1.0 # Right half: rotate right
					else:
						screen_aim_direction = -1.0 # Left half: rotate left
					is_screen_aiming = true
		else:
			if is_aerial_view:
				if is_mouse_down_on_map:
					is_mouse_down_on_map = false
					var was_dragging = is_dragging_map
					is_dragging_map = false
					get_viewport().set_input_as_handled()
					if not was_dragging:
						if practice_mode_active and place_ball_mode and event.button_index == MOUSE_BUTTON_LEFT:
							_perform_practice_teleport(event.position)
						else:
							_perform_map_click_aim(event.position)
			else:
				is_screen_aiming = false
				screen_aim_direction = 0.0

	elif event is InputEventMouseMotion:
		if is_aerial_view and is_mouse_down_on_map:
			var drag_dist = event.relative.length()
			total_map_drag_dist += drag_dist
			if total_map_drag_dist > 5.0 or is_dragging_map:
				is_dragging_map = true
				if has_node("AerialCamera") and $Player and $Player.ball:
					var scale_factor = $AerialCamera.size / get_viewport().get_visible_rect().size.y
					var tx = -event.relative.x * scale_factor
					var ty = event.relative.y * scale_factor
					
					# Get the camera orientation vectors dynamically to match current rotation
					var ball_pos = $Player.ball.global_position
					var hole_pos = current_hole_location
					if hole_pos.is_zero_approx():
						hole_pos = Vector3(250.0, ball_pos.y, 0.0)
					var dir_3d = (hole_pos - ball_pos)
					dir_3d.y = 0
					if dir_3d.is_zero_approx():
						dir_3d = Vector3(0, 0, -1)
					else:
						dir_3d = dir_3d.normalized()
					
					var right_vec = dir_3d.cross(Vector3.UP).normalized()
					var up_vec = dir_3d
					
					aerial_cam_user_offset += right_vec * tx + up_vec * ty
				get_viewport().set_input_as_handled()
		elif is_screen_aiming and not is_aerial_view:
			var vp_width = get_viewport().get_visible_rect().size.x
			if event.position.x >= vp_width * 0.5:
				screen_aim_direction = 1.0
			else:
				screen_aim_direction = -1.0


func set_aim_target(target_pos: Vector3, update_club: bool = true) -> void:
	_aim_is_manual = true
	aim_target_pos = target_pos
	aim_target_pos.y = get_height(target_pos.x, target_pos.z)
	update_dof_focus()
	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos
	
	if has_node("Player") and $Player.ball != null:
		var ball_pos = $Player.ball.global_position
		var diff = aim_target_pos - ball_pos
		var angle_rad = atan2(diff.z, diff.x)
		$Player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)
		
		if has_node("MapCanvas/AimDistanceLabel"):
			var dist_yards = int(ball_pos.distance_to(aim_target_pos) * 1.09361)
			set_aim_distance(dist_yards)
			
		if update_club:
			update_auto_club(true)
			
		var cam_pos = get_address_camera_position(ball_pos, -angle_rad)
		var target_look = get_camera_target_look(aim_target_pos, ball_pos)
		if has_node("PhantomCamera3D"):
			$PhantomCamera3D.follow_mode = PhantomCamera3D.FollowMode.NONE
			$PhantomCamera3D.look_at_mode = PhantomCamera3D.LookAtMode.NONE
			$PhantomCamera3D.global_position = cam_pos
			$PhantomCamera3D.look_at(target_look)
			if $PhantomCamera3D.camera_3d_resource != null:
				$PhantomCamera3D.camera_3d_resource.fov = GlobalSettings.range_settings.camera_fov.value
		if has_node("Camera3D"):
			$Camera3D.global_position = cam_pos
			$Camera3D.look_at(target_look)
			$Camera3D.fov = GlobalSettings.range_settings.camera_fov.value

		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.on_ready_for_shot()


func _perform_map_click_aim(mouse_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if camera != null:
		var ray_start = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		var ray_end = ray_start + ray_dir * 1000.0
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if $Player and $Player.ball:
			query.exclude = [$Player.ball.get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var clicked_point = hit["position"]
			set_aim_target(clicked_point, true)
			print("[Aim] Aim target set to: ", clicked_point, " | Yaw offset: ", $Player.ball.aim_yaw_offset_deg)


func _perform_practice_teleport_pos(clicked_point: Vector3) -> void:
	var target_pos = clicked_point
	target_pos.y = get_height(target_pos.x, target_pos.z) + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET
	practice_start_pos = target_pos
	if $Player and $Player.ball:
		$Player.ball.spawn_position = target_pos
		$Player.ball.global_position = target_pos
		$Player.ball.reset()
	print("[PracticeMode] Ball spawned at: ", target_pos)
	
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var active_player = mp_mgr.get_active_player()
		if not active_player.is_empty():
			active_player["position"] = target_pos
	
	_user_custom_club = ""
	update_current_lie_and_reduction()
	
	# Automatically aim at the pin/fairway and position the camera behind the ball
	if not current_hole_location.is_zero_approx():
		_update_hole_info_label(true)
		update_auto_club()
		apply_default_aim()


func _perform_practice_teleport(mouse_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if camera != null:
		var ray_start = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		var ray_end = ray_start + ray_dir * 1000.0
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if $Player and $Player.ball:
			query.exclude = [$Player.ball.get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_perform_practice_teleport_pos(hit["position"])


func _process_screen_aiming(delta: float) -> void:
	if not ($Player and $Player.ball):
		return
	if screen_aim_direction == 0.0:
		if _was_screen_aiming:
			_was_screen_aiming = false
			if _aim_distance_indicator != null:
				_aim_distance_indicator.notify_aiming_stopped()
			_continuous_aim_angle_init = false
			aim_target_pos.y = get_height(aim_target_pos.x, aim_target_pos.z)
			if has_node("AimMarker"):
				$AimMarker.global_position = aim_target_pos
			update_auto_club(false)
			update_dof_focus()
			if not is_aerial_view and has_node("Player") and $Player.ball != null:
				var ball_pos = $Player.ball.global_position
				var diff = aim_target_pos - ball_pos
				var current_angle = atan2(diff.z, diff.x)
				var is_on_green_view = is_putting_view()
				var cam_pos = get_address_camera_position(ball_pos, -current_angle, is_on_green_view, false)
				var target_look = get_camera_target_look(aim_target_pos, ball_pos, is_on_green_view)
				if has_node("PhantomCamera3D"):
					$PhantomCamera3D.global_position = cam_pos
					$PhantomCamera3D.look_at(target_look)
					if has_node("Camera3D"):
						$Camera3D.global_transform = $PhantomCamera3D.global_transform
				elif has_node("Camera3D"):
					$Camera3D.global_position = cam_pos
					$Camera3D.look_at(target_look)
		return

	_was_screen_aiming = true
	if _aim_distance_indicator != null:
		_aim_distance_indicator.notify_aiming()

	var ball_pos = $Player.ball.global_position
	var diff = aim_target_pos - ball_pos
	var dist_xz = Vector2(diff.x, diff.z).length()
	if dist_xz < 0.5:
		if not current_hole_location.is_zero_approx() and ball_pos.distance_to(current_hole_location) > 0.5:
			var hole_diff = current_hole_location - ball_pos
			dist_xz = Vector2(hole_diff.x, hole_diff.z).length()
		else:
			dist_xz = 50.0

	if not _continuous_aim_angle_init:
		_continuous_aim_angle_rad = atan2(diff.z, diff.x)
		_continuous_aim_angle_init = true

	var d_angle = deg_to_rad(screen_aim_speed_deg) * delta * screen_aim_direction
	_continuous_aim_angle_rad += d_angle
	var new_angle = _continuous_aim_angle_rad

	var new_diff_x = cos(new_angle) * dist_xz
	var new_diff_z = sin(new_angle) * dist_xz

	aim_target_pos.x = ball_pos.x + new_diff_x
	aim_target_pos.z = ball_pos.z + new_diff_z
	_aim_is_manual = true

	$Player.ball.aim_yaw_offset_deg = rad_to_deg(-new_angle)

	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos

	if not is_aerial_view:
		var is_on_green_view = is_putting_view()
		var cam_pos = get_address_camera_position(ball_pos, -new_angle, is_on_green_view, true)
		var target_look = get_camera_target_look(aim_target_pos, ball_pos, is_on_green_view)
		if has_node("PhantomCamera3D"):
			$PhantomCamera3D.global_position = cam_pos
			$PhantomCamera3D.look_at(target_look)
			if has_node("Camera3D"):
				$Camera3D.global_transform = $PhantomCamera3D.global_transform
		elif has_node("Camera3D"):
			$Camera3D.global_position = cam_pos
			$Camera3D.look_at(target_look)


func _process_keyboard_aiming(delta: float) -> void:
	if not has_node("Player") or $Player.ball == null or _shot_active:
		return
	if is_any_dialog_open() or is_free_camera_active():
		return

	var turn_input: float = 0.0
	if Input.is_action_pressed("aim_left") or Input.is_key_pressed(KEY_LEFT):
		turn_input -= 1.0
	if Input.is_action_pressed("aim_right") or Input.is_key_pressed(KEY_RIGHT):
		turn_input += 1.0

	var dist_input: float = 0.0
	if Input.is_action_pressed("aim_forward") or Input.is_key_pressed(KEY_UP):
		dist_input += 1.0
	if Input.is_action_pressed("aim_backward") or Input.is_key_pressed(KEY_DOWN):
		dist_input -= 1.0

	for joy_id in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_LEFT):
			turn_input -= 1.0
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_RIGHT):
			turn_input += 1.0
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_UP):
			dist_input += 1.0
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_DOWN):
			dist_input -= 1.0

	if turn_input == 0.0 and dist_input == 0.0:
		if _was_keyboard_aiming:
			_was_keyboard_aiming = false
			if _aim_distance_indicator != null:
				_aim_distance_indicator.notify_aiming_stopped()
			_continuous_aim_angle_init = false
			aim_target_pos.y = get_height(aim_target_pos.x, aim_target_pos.z)
			if has_node("AimMarker"):
				$AimMarker.global_position = aim_target_pos
			var ball_pos = $Player.ball.global_position if (has_node("Player") and $Player.ball != null) else Vector3.ZERO
			var dist_yards = int(ball_pos.distance_to(aim_target_pos) * 1.09361)
			if has_node("MapCanvas/AimDistanceLabel"):
				set_aim_distance(dist_yards)
			update_auto_club(false)
			update_dof_focus()
			if not is_aerial_view and has_node("Player") and $Player.ball != null:
				var diff = aim_target_pos - ball_pos
				var current_angle = atan2(diff.z, diff.x)
				var is_on_green_view = is_putting_view()
				var cam_pos = get_address_camera_position(ball_pos, -current_angle, is_on_green_view, false)
				var target_look = get_camera_target_look(aim_target_pos, ball_pos, is_on_green_view)
				if has_node("PhantomCamera3D"):
					$PhantomCamera3D.global_position = cam_pos
					$PhantomCamera3D.look_at(target_look)
					if has_node("Camera3D"):
						$Camera3D.global_transform = $PhantomCamera3D.global_transform
				elif has_node("Camera3D"):
					$Camera3D.global_position = cam_pos
					$Camera3D.look_at(target_look)
		return

	_was_keyboard_aiming = true
	if _aim_distance_indicator != null:
		_aim_distance_indicator.notify_aiming()

	var vp := get_viewport()
	if vp != null and vp.gui_get_focus_owner() != null:
		var foc = vp.gui_get_focus_owner()
		if _is_control_in_dialog(foc) or foc is LineEdit or foc is TextEdit or foc is Range:
			return
		if _weather_lighting_controller != null and is_instance_valid(_weather_lighting_controller):
			if foc == _weather_lighting_controller.weather_toggle_btn or foc == _weather_lighting_controller.time_slider:
				return
		vp.gui_release_focus()

	var ball_pos = $Player.ball.global_position
	var diff = aim_target_pos - ball_pos
	var dist_xz = Vector2(diff.x, diff.z).length()
	if dist_xz < 0.5:
		if not current_hole_location.is_zero_approx() and ball_pos.distance_to(current_hole_location) > 0.5:
			var hole_diff = current_hole_location - ball_pos
			dist_xz = Vector2(hole_diff.x, hole_diff.z).length()
		else:
			dist_xz = 50.0

	if not _continuous_aim_angle_init:
		_continuous_aim_angle_rad = atan2(diff.z, diff.x)
		_continuous_aim_angle_init = true

	if turn_input != 0.0:
		var d_angle = deg_to_rad(screen_aim_speed_deg) * delta * turn_input
		_continuous_aim_angle_rad += d_angle

	if dist_input != 0.0:
		var d_dist = 40.0 * delta * dist_input
		dist_xz = clamp(dist_xz + d_dist, 5.0, 650.0)

	var current_angle = _continuous_aim_angle_rad
	var new_diff_x = cos(current_angle) * dist_xz
	var new_diff_z = sin(current_angle) * dist_xz

	aim_target_pos.x = ball_pos.x + new_diff_x
	aim_target_pos.z = ball_pos.z + new_diff_z
	if dist_input != 0.0:
		aim_target_pos.y = get_height(aim_target_pos.x, aim_target_pos.z)
	_aim_is_manual = true

	$Player.ball.aim_yaw_offset_deg = rad_to_deg(-current_angle)

	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos

	var dist_yards = int(ball_pos.distance_to(aim_target_pos) * 1.09361)
	if dist_input != 0.0 and dist_yards != _last_aim_dist_yards:
		_last_aim_dist_yards = dist_yards
		if has_node("MapCanvas/AimDistanceLabel"):
			set_aim_distance(dist_yards)
		update_auto_club(false)
		update_dof_focus()

	if not is_aerial_view:
		var is_on_green_view = is_putting_view()
		var cam_pos = get_address_camera_position(ball_pos, -current_angle, is_on_green_view, true)
		var target_look = get_camera_target_look(aim_target_pos, ball_pos, is_on_green_view)
		if has_node("PhantomCamera3D"):
			$PhantomCamera3D.global_position = cam_pos
			$PhantomCamera3D.look_at(target_look)
			if has_node("Camera3D"):
				$Camera3D.global_transform = $PhantomCamera3D.global_transform
		elif has_node("Camera3D"):
			$Camera3D.global_position = cam_pos
			$Camera3D.look_at(target_look)


func _apply_aim_step(turn_deg: float, dist_m: float) -> void:
	if not ($Player and $Player.ball) or _shot_active:
		return
	var ball_pos = $Player.ball.global_position
	var diff = aim_target_pos - ball_pos
	var dist_xz = Vector2(diff.x, diff.z).length()
	if dist_xz < 0.5:
		dist_xz = 50.0

	var current_angle = atan2(diff.z, diff.x)
	if turn_deg != 0.0:
		current_angle += deg_to_rad(turn_deg)
	if dist_m != 0.0:
		dist_xz = clamp(dist_xz + dist_m, 5.0, 650.0)

	var new_diff_x = cos(current_angle) * dist_xz
	var new_diff_z = sin(current_angle) * dist_xz

	aim_target_pos = ball_pos + Vector3(new_diff_x, 0.0, new_diff_z)
	aim_target_pos.y = get_height(aim_target_pos.x, aim_target_pos.z)
	_aim_is_manual = true

	$Player.ball.aim_yaw_offset_deg = rad_to_deg(-current_angle)

	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos

	var dist_yards = int(ball_pos.distance_to(aim_target_pos) * 1.09361)
	if has_node("MapCanvas/AimDistanceLabel"):
		set_aim_distance(dist_yards)

	update_auto_club(false)
	update_dof_focus()

	if not is_aerial_view:
		var is_on_green_view = is_putting_view()
		var cam_pos = get_address_camera_position(ball_pos, -current_angle, is_on_green_view, true)
		var target_look = get_camera_target_look(aim_target_pos, ball_pos, is_on_green_view)
		if has_node("PhantomCamera3D"):
			$PhantomCamera3D.global_position = cam_pos
			$PhantomCamera3D.look_at(target_look)
			if has_node("Camera3D"):
				$Camera3D.global_transform = $PhantomCamera3D.global_transform
		elif has_node("Camera3D"):
			$Camera3D.global_position = cam_pos
			$Camera3D.look_at(target_look)


var _last_club_cycle_time: float = 0.0
const CLUB_CYCLE_MIN_COOLDOWN: float = 0.12

func _cycle_club(longer: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if (now - _last_club_cycle_time) < CLUB_CYCLE_MIN_COOLDOWN:
		return
	_last_club_cycle_time = now
	var club_sel = get_club_selector()
	if club_sel != null and is_instance_valid(club_sel):
		if longer:
			club_sel.call("select_next_club")
		else:
			club_sel.call("select_prev_club")


func _check_stat_toggle_input(event: InputEvent) -> bool:
	for stat in StatDefinitions.STATS:
		var stat_id = str(stat.get("id", ""))
		var act = "stat_toggle_" + stat_id
		if event.is_action_pressed(act):
			KeybindingManager.toggle_stat(stat_id)
			return true
	return false


func _toggle_announcer_mute() -> void:
	var a = get_node_or_null("/root/AnnouncerEngine")
	if a != null:
		var cur = a.get("AnnouncerRange") as bool
		var new_val = not cur
		a.set("AnnouncerRange", new_val)
		GlobalSettings.save_settings()
		if has_node("RangeUI"):
			$RangeUI.call("update_announcer_button_state")
		if new_val:
			a.call("SpeakHecklesEnabled")
		else:
			a.call("SpeakHecklesDisabled")


func _toggle_suspense() -> void:
	if has_node("/root/GlobalSettings"):
		var cur = GlobalSettings.range_settings.tension_effects_enabled.value
		GlobalSettings.range_settings.tension_effects_enabled.value = not cur
		GlobalSettings.save_settings()
		if cur and has_node("/root/TensionManager"):
			TensionManager.stop_tension()
		if has_node("RangeUI"):
			$RangeUI.call("update_suspense_button_state")


func _toggle_distance_menu() -> void:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			if not bool(gs.range_settings.debug_show_hit_distance.value):
				return
	if has_node("RangeUI"):
		$RangeUI.call("toggle_distance_menu")


func _toggle_shot_traces() -> void:
	if not is_driving_range:
		return
	if has_node("RangeUI"):
		$RangeUI.call("toggle_shot_traces")


func _is_remote_turn_locked() -> bool:
	if has_node("/root/OnlineSession"):
		var sess = get_node("/root/OnlineSession")
		if sess.is_online_match:
			if bool(sess.get("is_spectator")):
				return true
			if has_node("/root/MultiplayerManager"):
				var mp = get_node("/root/MultiplayerManager")
				var active_p = mp.get_active_player()
				if active_p.get("is_remote", false):
					return true
			if sess.has_method("is_replaying_remote_turn") and sess.is_replaying_remote_turn():
				return true
	return false


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	if _is_remote_turn_locked():
		print("[Range] Remote turn or replay in progress — ignoring hit.")
		return
	var speed: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var shot_type = str(data.get("ShotType", "")).to_lower()
	if speed <= 0.1 or shot_type == "practice":
		print("[Range] Practice swing or 0 ball speed ignored.")
		return
	RainPhysics.apply_rain_shot_reduction(data)
	FoamBallBoost.apply_boost(data)
	if has_node("Player"):
		$Player._on_tcp_client_hit_ball(data)
		
	raw_ball_data = data.duplicate()
	_update_ball_display(false)
	_on_shot_initiated()

	# Re-enable camera follow if the setting is on
	if GlobalSettings.range_settings.camera_follow_mode.value:
		call_deferred("set_camera_follow_mode", true)


func _on_launch_monitor_hit_ball(data: Dictionary) -> void:
	_on_tcp_client_hit_ball(data)


func _process(delta: float) -> void:
	# Live stats update during ball flight and rollout (~10 Hz on mobile, ~20 Hz on desktop)
	if has_node("Player") and $Player.ball != null and ($Player.get_ball_state() != PhysicsEnums.BallState.REST or _shot_active):
		_live_stats_timer += delta
		var stats_interval = 0.10 if MobilePerformance.is_mobile() else 0.05
		if _live_stats_timer >= stats_interval:
			_live_stats_timer = 0.0
			_update_ball_display(false)

	# Throttled green grid visibility check
	if show_green_grid:
		_green_grid_timer += delta
		if _green_grid_timer >= 0.2:
			_green_grid_timer = 0.0
			_update_green_grid_visibility()
	else:
		var grid_node = get_node_or_null("GreenGridMesh")
		if grid_node != null and grid_node.visible:
			_update_green_grid_visibility()

	# Continuous screen aiming when holding mouse on left/right half of screen in normal view
	if is_screen_aiming and not is_aerial_view and not _shot_active:
		_process_screen_aiming(delta)

	# Continuous keyboard aiming using arrow keys
	if not _shot_active:
		_process_keyboard_aiming(delta)
	
	# Check for shot zoom zone transition (Tee box vs Midway vs Green) only when dirty
	var ball_at_rest = not _shot_active
	if has_node("Player") and $Player.ball != null:
		ball_at_rest = ball_at_rest and ($Player.get_ball_state() == PhysicsEnums.BallState.REST)
	if ball_at_rest and _zoom_zone_dirty:
		_zoom_zone_dirty = false
		var current_zone = get_current_zoom_zone()
		if current_zone != _last_zoom_zone:
			aerial_zoom = get_zoom_for_zone(current_zone)
			if has_node("AerialCamera"):
				$AerialCamera.size = aerial_zoom
			_last_zoom_zone = current_zone
			_last_was_on_green = (current_zone == 2)

	# Putt & Chip camera suspense zoom & heartbeat tension (Course Play only)
	if has_node("/root/TensionManager") and TensionManager.is_course_play_active():
		if has_node("Player") and ($Player.get_ball_state() != PhysicsEnums.BallState.REST or _shot_active) and $Player.ball != null:
			var ball_node = $Player.ball
			var target_pos = current_hole_location
			
			if not target_pos.is_zero_approx():
				var is_sand = ball_node.is_in_sand or (ball_node.get("shot_was_in_sand") == true) or (ball_node.lie_type == "sand")
				var start_p = ball_node.spawn_position
				if ball_node.get("shot_start_pos_global") != null and not (ball_node.shot_start_pos_global as Vector3).is_zero_approx():
					start_p = ball_node.shot_start_pos_global
				elif ball_node.get("shot_start_pos") != null and not (ball_node.shot_start_pos as Vector3).is_zero_approx():
					start_p = ball_node.shot_start_pos
				
				if TensionManager.is_shot_eligible_for_suspense(start_p, target_pos, ball_node.is_putt, is_sand):
					var ball_pos_2d = Vector2(ball_node.global_position.x, ball_node.global_position.z)
					var hole_pos_2d = Vector2(target_pos.x, target_pos.z)
					var dist_to_target = ball_pos_2d.distance_to(hole_pos_2d)
					
					if not ball_node.is_putt:
						_chip_close_view_triggered = TensionManager.is_active()
						if (_chip_close_view_triggered or TensionManager.is_active()) and has_node("PhantomCamera3D") and $PhantomCamera3D.follow_mode == PhantomCamera3D.FollowMode.SIMPLE:
							var target_offset = Vector3(-6.0, 1.4, 0).rotated(Vector3.UP, _last_travel_yaw)
							$PhantomCamera3D.follow_offset = $PhantomCamera3D.follow_offset.lerp(target_offset, delta * 4.0)
		
	# Dynamic ground clearance clamping during follow mode (especially on putts and undulating greens)
	if has_node("PhantomCamera3D") and $PhantomCamera3D.follow_mode == PhantomCamera3D.FollowMode.SIMPLE:
		var ball_node = $Player.ball if has_node("Player") else null
		if ball_node != null:
			var is_putting = ball_node.is_putt or is_putting_view()
			if is_putting:
				var ball_p = ball_node.global_position
				var cur_offset = $PhantomCamera3D.follow_offset
				var cand_cam_x = ball_p.x + cur_offset.x
				var cand_cam_z = ball_p.z + cur_offset.z
				var ground_h = get_height(cand_cam_x, cand_cam_z)
				var min_clearance = 0.35
				var needed_y_offset = (ground_h + min_clearance) - ball_p.y
				var base_y = 0.6
				var target_offset_y = maxf(base_y, needed_y_offset)
				if absf($PhantomCamera3D.follow_offset.y - target_offset_y) > 0.01:
					$PhantomCamera3D.follow_offset.y = lerpf($PhantomCamera3D.follow_offset.y, target_offset_y, delta * 10.0)

	if _shot_active and not has_node("PhantomCamera3D") and has_node("Camera3D") and $Camera3D.current:
		var clamped_cam = clamp_camera_position($Camera3D.global_position, 0.35)
		if $Camera3D.global_position.y < clamped_cam.y:
			$Camera3D.global_position.y = clamped_cam.y

	if GlobalSettings.range_settings.dof_enabled.value:
		update_dof_focus()
		
	# Keep aerial camera centered, zoomed, and oriented between player and hole
	if is_aerial_view and has_node("AerialCamera") and $Player and $Player.ball:
		var ball_pos = $Player.ball.global_position
		var hole_pos = current_hole_location
		if hole_pos.is_zero_approx():
			hole_pos = Vector3(250.0, ball_pos.y, 0.0)
		var dir_3d = (hole_pos - ball_pos)
		dir_3d.y = 0
		if dir_3d.is_zero_approx():
			dir_3d = Vector3(0, 0, -1)
		else:
			dir_3d = dir_3d.normalized()
		
		$AerialCamera.size = aerial_zoom
		
		# Orientation: local up (Y column of basis) points from ball to hole, local -Z points straight down
		var right_vec = dir_3d.cross(Vector3.UP).normalized()
		var up_vec = dir_3d
		var back_vec = Vector3.UP
		$AerialCamera.global_transform.basis = Basis(right_vec, up_vec, back_vec)
		
		# Position: offset towards the hole by 0.35 * aerial_zoom so ball is on the south side
		var base_pos = ball_pos + dir_3d * (0.35 * aerial_zoom)
		$AerialCamera.global_position = Vector3(base_pos.x, 150.0, base_pos.z) + aerial_cam_user_offset

	# Draw/update the aim line connecting the player's ball to the aim marker
	if aim_line and $Player and $Player.ball:
		var has_minimap = not MultiplayerManager.players.is_empty()
		ball_at_rest = $Player.get_ball_state() == PhysicsEnums.BallState.REST
		var should_show_aim_line = is_aerial_view or (has_minimap and ball_at_rest)
		var imm: ImmediateMesh = aim_line.mesh
		# Draw the line when the map is active or when the minimap is active and ball is at rest
		if should_show_aim_line:
			var start_pt = $Player.ball.global_position + Vector3(0, 0.2, 0)
			var end_pt = aim_target_pos + Vector3(0, 0.2, 0)
			if not aim_line.visible or not start_pt.is_equal_approx(_last_aim_line_start) or not end_pt.is_equal_approx(_last_aim_line_end):
				_last_aim_line_start = start_pt
				_last_aim_line_end = end_pt
				aim_line.visible = true
				imm.clear_surfaces()
				imm.surface_begin(Mesh.PRIMITIVE_LINES)
				imm.surface_add_vertex(start_pt)
				imm.surface_add_vertex(end_pt)
				imm.surface_end()
		elif aim_line.visible:
			aim_line.visible = false
			imm.clear_surfaces()
			_last_aim_line_start = Vector3.INF
			_last_aim_line_end = Vector3.INF

	# Update player marker position and aim distance display dynamically
	if has_node("PlayerMarker") and $Player and $Player.ball:
		$PlayerMarker.global_position = $Player.ball.global_position
		
		var has_minimap = not MultiplayerManager.players.is_empty() or (has_node("/root/TensionManager") and TensionManager.is_course_play_active())
		$PlayerMarker.visible = is_aerial_view or has_minimap
		if has_node("AimMarker"):
			$AimMarker.visible = is_aerial_view or has_minimap
		if has_node("PinMarker"):
			$PinMarker.visible = is_aerial_view or has_minimap
		
		# Update distance to target only when at rest or in aerial view (and not during active aiming)
		ball_at_rest = $Player.get_ball_state() == PhysicsEnums.BallState.REST
		if (is_aerial_view or ball_at_rest) and not _was_keyboard_aiming and not _was_screen_aiming:
			var dist_to_target = $Player.ball.global_position.distance_to(aim_target_pos) * 1.09361
			if abs(current_aim_distance_yards - dist_to_target) >= 0.5:
				if has_node("MapCanvas/AimDistanceLabel"):
					set_aim_distance(round(dist_to_target))


var shot_history: Array[Dictionary] = []
var _shot_sequence_id: int = 0
var _shot_transition_active: bool = false
var _shot_trace_overlay: Node3D = null

func is_shot_transition_active() -> bool:
	return _shot_transition_active

func cancel_pending_shot_transition() -> void:
	_shot_sequence_id += 1
	_shot_transition_active = false

func _on_golf_ball_rest(_ball_data) -> void:
	_shot_sequence_id += 1
	var this_shot_seq = _shot_sequence_id
	_shot_active = false
	_shot_transition_active = true
	_zoom_zone_dirty = true
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_ball_at_rest")
	is_screen_aiming = false
	screen_aim_direction = 0.0
	_putt_close_view_triggered = false
	_chip_close_view_triggered = false
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	raw_ball_data = _ball_data.duplicate()
	_update_ball_display(true)
	
	# Add valid shots to history to compute average stats
	if raw_ball_data.get("Speed", 0.0) > 0.0:
		if GlobalSettings.is_chipping_minigame:
			var final_pos = $Player.ball.global_position
			var target_pos = chipping_island_positions[selected_chipping_target_idx]
			var dist_to_target = Vector2(final_pos.x, final_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))
			
			var is_hit = false
			if not $Player.ball.is_in_water and dist_to_target <= 3.81:
				is_hit = true
				chipping_stats[selected_chipping_target_idx]["Hits"] += 1
				GlobalSettings.play_golf_clap()
				_show_chipping_banner("GREEN HIT! Fantastic shot!")
			else:
				if $Player.ball.is_in_water:
					_show_chipping_banner("SPLASH! Landed in the water hazard.")
				else:
					_show_chipping_banner("Missed target. Distance: %.1f ft" % (dist_to_target * 3.28084))
					
			chipping_stats[selected_chipping_target_idx]["Attempts"] += 1
			_update_chipping_hud()
		
		var p_name = _get_current_player_name()
		var club_name = _get_current_club()
		raw_ball_data["player"] = p_name
		raw_ball_data["player_name"] = p_name
		raw_ball_data["club"] = club_name

		# Ensure downrange TotalDistance, CarryDistance, and lateral SideDistance are properly captured
		if has_node("Player"):
			var p_node = get_node("Player")
			if not raw_ball_data.has("TotalDistance") or float(raw_ball_data.get("TotalDistance", 0.0)) == 0.0:
				if p_node.has_method("get_distance"):
					raw_ball_data["TotalDistance"] = p_node.get_distance()
			if not raw_ball_data.has("CarryDistance") or float(raw_ball_data.get("CarryDistance", 0.0)) == 0.0:
				if "carry" in p_node and float(p_node.carry) > 0.0:
					raw_ball_data["CarryDistance"] = p_node.carry
				elif raw_ball_data.has("TotalDistance"):
					raw_ball_data["CarryDistance"] = raw_ball_data["TotalDistance"]
			if not raw_ball_data.has("SideDistance") or float(raw_ball_data.get("SideDistance", 0.0)) == 0.0:
				if p_node.has_method("get_side_distance"):
					raw_ball_data["SideDistance"] = p_node.get_side_distance()

			if not raw_ball_data.has("Apex") or float(raw_ball_data.get("Apex", 0.0)) == 0.0:
				if "apex" in p_node and float(p_node.apex) > 0.0:
					raw_ball_data["Apex"] = p_node.apex

			if not raw_ball_data.has("HangTime") or float(raw_ball_data.get("HangTime", 0.0)) == 0.0:
				if p_node.ball != null and "flight_time" in p_node.ball and float(p_node.ball.flight_time) > 0.0:
					raw_ball_data["HangTime"] = p_node.ball.flight_time

			if not raw_ball_data.has("shot_reduction") or float(raw_ball_data.get("shot_reduction", 0.0)) == 0.0:
				var red = p_node.get("last_shot_reduction")
				if red != null and float(red) > 0.0:
					raw_ball_data["shot_reduction"] = float(red)
			if current_aim_distance_yards > 0.0:
				raw_ball_data["AimDistanceYards"] = current_aim_distance_yards
				if not raw_ball_data.has("TargetDistance") or float(raw_ball_data.get("TargetDistance", 0.0)) == 0.0:
					raw_ball_data["TargetDistance"] = current_aim_distance_yards / 1.09361

			# Capture flight tracer points from the Player's current_tracer
			var tracer = p_node.get("current_tracer")
			if tracer != null and is_instance_valid(tracer) and "points" in tracer and not tracer.points.is_empty():
				raw_ball_data["tracer_points"] = tracer.points.duplicate()
				# If SideDistance was 0 (or not reported by sensor/injector), extract lateral offset from tracer endpoint
				if float(raw_ball_data.get("SideDistance", 0.0)) == 0.0 and tracer.points.size() >= 2:
					var p_start: Vector3 = tracer.points[0]
					var p_end: Vector3 = tracer.points[-1]
					var p_delta = p_end - p_start
					if p_node.ball != null and p_node.ball.has_method("get_target_right"):
						var right_vec: Vector3 = p_node.ball.get_target_right()
						raw_ball_data["SideDistance"] = p_delta.dot(right_vec)
					else:
						raw_ball_data["SideDistance"] = p_delta.z

		var mp_mgr_lie = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr_lie != null and not mp_mgr_lie.players.is_empty():
			var active_p = mp_mgr_lie.get_active_player()
			if not raw_ball_data.has("shot_reduction") or float(raw_ball_data.get("shot_reduction", 0.0)) == 0.0:
				var red = active_p.get("last_shot_reduction", active_p.get("shot_reduction", 0.0))
				if float(red) > 0.0:
					raw_ball_data["shot_reduction"] = float(red)

		shot_history.append(raw_ball_data.duplicate())

		# Notify shot trace overlay and dispersion map if active
		_notify_shot_trace_overlay(raw_ball_data)
		
		# Only defer to MultiplayerManager.record_shot if in an active multiplayer course match with hole ids
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		var is_course_match = mp_mgr != null and not mp_mgr.players.is_empty() and not mp_mgr.hole_ids.is_empty() and not is_driving_range and not practice_mode_active
		if not is_course_match:
			var prev_longest_drive = -1.0
			if mp_mgr != null and not p_name.is_empty():
				prev_longest_drive = mp_mgr.get_player_longest_drive(p_name)
			var recorded = _record_global_shot(p_name, club_name, raw_ball_data)
			raw_ball_data["recorded_in_averages"] = recorded
			if not recorded and has_node("RangeUI"):
				$RangeUI.call("show_mishit_alert", "⚠️ Miss-hit excluded from club averages")
			if has_node("/root/AchievementManager") and not practice_mode_active and recorded:
				var total_yds = (raw_ball_data.get("TotalDistance", 0.0) as float) * 1.09361
				get_node("/root/AchievementManager").check_shot_achievements(p_name, club_name, total_yds, prev_longest_drive)
		if has_node("RangeUI") and $RangeUI.has_method("record_analysis_shot"):
			$RangeUI.call("record_analysis_shot", raw_ball_data)
		_update_averages()

	# Announce shot
	var is_dynamic_course = not current_hole_location.is_zero_approx()
	var ball_pos: Vector3 = $Player.ball.global_position

	var ball = $Player.ball
	var landed_in_water = ball.is_in_water
	var landed_in_sand = ball.is_in_sand

	if ball.is_in_water:
		print("[range.gd] Ball landed in water hazard!")
		var recovery_pos: Vector3 = ball_pos
		var return_to_teebox: bool = ball.shot_was_from_teebox and not ball.shot_hit_other_ground

		if return_to_teebox:
			print("[range.gd] Water hazard directly from teebox without hitting other ground. Re-teeing from tee box!")
			if not ball.shot_start_pos_global.is_zero_approx():
				recovery_pos = ball.shot_start_pos_global
			elif $Player != null and not $Player._last_starting_pos.is_zero_approx():
				recovery_pos = $Player._last_starting_pos
			elif not practice_start_pos.is_zero_approx():
				recovery_pos = practice_start_pos

			ball.lie_type = "teebox"
			ball.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
			if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
				var mp_mgr = get_node("/root/MultiplayerManager")
				var active_player = mp_mgr.get_active_player()
				if active_player != null:
					active_player["lie_type"] = "teebox"
					active_player["position"] = recovery_pos
					active_player["last_starting_pos"] = recovery_pos
		else:
			# 1. Find closest point on water polygon boundary
			var found_drop_point = false
			var water_col = ball.water_collider
			var poly_points = []
			if water_col != null:
				if water_col.has_meta("water_points"):
					poly_points = water_col.get_meta("water_points")
				elif water_col.get_parent() != null and water_col.get_parent().has_meta("water_points"):
					poly_points = water_col.get_parent().get_meta("water_points")

			if poly_points.size() > 0:
				var ball_pos_2d = Vector2(ball_pos.x, ball_pos.z)
				var closest_pt_2d = get_closest_point_on_polygon(ball_pos_2d, poly_points)
				var away_dir = (closest_pt_2d - ball_pos_2d).normalized()
				if away_dir.is_zero_approx():
					if not ball.shot_start_pos_global.is_zero_approx():
						var start_2d = Vector2(ball.shot_start_pos_global.x, ball.shot_start_pos_global.z)
						away_dir = (start_2d - closest_pt_2d).normalized()
					if away_dir.is_zero_approx():
						var pin_pos_2d = Vector2(current_hole_location.x, current_hole_location.z)
						away_dir = (closest_pt_2d - pin_pos_2d).normalized()
					if away_dir.is_zero_approx():
						away_dir = Vector2.UP

				# Standard golf penalty relief: 2 club lengths (~2.5 meters / ~8.2 feet) away from hazard boundary
				var drop_dist = 2.5
				var rec_pos_2d = closest_pt_2d + away_dir * drop_dist

				# Ensure relief point is outside water polygon
				var packed_poly = PackedVector2Array(poly_points)
				if Geometry2D.is_point_in_polygon(rec_pos_2d, packed_poly):
					# Try reversing away_dir if initial vector pushed inward
					var alt_pos = closest_pt_2d - away_dir * drop_dist
					if not Geometry2D.is_point_in_polygon(alt_pos, packed_poly):
						rec_pos_2d = alt_pos
					elif not ball.shot_start_pos_global.is_zero_approx():
						var start_dir = (Vector2(ball.shot_start_pos_global.x, ball.shot_start_pos_global.z) - closest_pt_2d).normalized()
						var start_pos = closest_pt_2d + start_dir * drop_dist
						if not Geometry2D.is_point_in_polygon(start_pos, packed_poly):
							rec_pos_2d = start_pos

				var h = get_height(rec_pos_2d.x, rec_pos_2d.y)
				recovery_pos = Vector3(rec_pos_2d.x, h + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET, rec_pos_2d.y)
				found_drop_point = true
			if not found_drop_point:
				if not ball.shot_start_pos_global.is_zero_approx():
					recovery_pos = ball.shot_start_pos_global
				elif $Player != null and not $Player._last_starting_pos.is_zero_approx():
					recovery_pos = $Player._last_starting_pos
				elif not practice_start_pos.is_zero_approx():
					recovery_pos = practice_start_pos
			
			ball.lie_type = "rough"
			ball.set_surface(PhysicsEnums.SurfaceType.ROUGH)
			if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
				var mp_mgr = get_node("/root/MultiplayerManager")
				var active_player = mp_mgr.get_active_player()
				if active_player != null:
					active_player["lie_type"] = "rough"
					active_player["position"] = recovery_pos
					active_player["last_starting_pos"] = recovery_pos
		
		# 2. Update ball position and spawn position
		ball.global_position = recovery_pos
		if ball.has_method("ensure_tree_clearance"):
			ball.ensure_tree_clearance()
			recovery_pos = ball.global_position
		if ball.has_method("ensure_rock_clearance"):
			ball.ensure_rock_clearance()
			recovery_pos = ball.global_position
		if not practice_mode_active:
			ball.spawn_position = recovery_pos
		ball_pos = recovery_pos
		
		# 3. Add penalty stroke to active player
		if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
			var mp_mgr = get_node("/root/MultiplayerManager")
			var active_player = mp_mgr.get_active_player()
			if not mp_mgr.game_mode in ["Scramble", "2v2 Scramble"]:
				active_player["strokes"] += 1
				active_player["total_strokes"] += 1
				print("[range.gd] Water hazard penalty applied: +1 stroke to %s" % active_player["name"])
			else:
				print("[range.gd] Scramble water hazard: marked penalty on shot, team stroke deferred")
			active_player["last_shot_penalty"] = 1
		else:
			shot_count += 1
			print("[range.gd] Water hazard penalty applied: +1 shot count (now %d)" % shot_count)
	else:
		if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
			var mp_mgr = get_node("/root/MultiplayerManager")
			var active_player = mp_mgr.get_active_player()
			if active_player != null:
				active_player["last_shot_penalty"] = 0

	if is_dynamic_course and not practice_mode_active:
		var next_spawn_pos = ball_pos
		if ball != null and ball.get("holed_out_this_shot"):
			next_spawn_pos.y = get_height(ball_pos.x, ball_pos.z) + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET
		$Player.ball.spawn_position = next_spawn_pos

	update_current_lie_and_reduction()

	if has_node("/root/AnnouncerEngine") and not raw_ball_data.is_empty():
		var announcer = get_node("/root/AnnouncerEngine")
		var pin_dist := 999.0
		var target_pin = current_hole_location if is_dynamic_course else Vector3(150.0, ball_pos.y, 0.0)
		pin_dist = ball_pos.distance_to(target_pin) * 1.09361 # yards
		var hit_tree: bool = ball.hit_tree_this_shot if "hit_tree_this_shot" in ball else false
		announcer.call("EvaluateShot", raw_ball_data, $Player.ball.surface_type, pin_dist, landed_in_sand, landed_in_water, hit_tree)

	# Record multiplayer shot
	if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
		var mp_mgr = get_node("/root/MultiplayerManager")
		var pre_shot_active_p: Dictionary = mp_mgr.get_active_player()
		var pre_start_pos: Vector3 = pre_shot_active_p.get("position", Vector3.ZERO)
		var is_local_online_turn: bool = false
		if has_node("/root/OnlineSession") and get_node("/root/OnlineSession").is_online_match:
			if not pre_shot_active_p.get("is_remote", false):
				is_local_online_turn = true

		mp_mgr.record_shot(ball_pos, raw_ball_data)

		if is_local_online_turn and has_node("/root/OnlineMatchController"):
			var omc = get_node("/root/OnlineMatchController")
			var hitter: Dictionary = pre_shot_active_p
			var shot_start: Vector3 = pre_start_pos
			if has_node("Player") and $Player.ball != null and not ($Player.ball.shot_start_pos_global as Vector3).is_zero_approx():
				shot_start = $Player.ball.shot_start_pos_global
			elif shot_start.is_zero_approx() and hitter.has("last_starting_pos") and hitter["last_starting_pos"] is Vector3:
				shot_start = hitter["last_starting_pos"]
			var club_str: String = str(hitter.get("last_shot_club", _get_current_club()))
			var lie_str: String = str(hitter.get("lie_type", "fairway"))
			var pen: int = int(hitter.get("last_shot_penalty", 0))
			var gimme_strk: int = int(mp_mgr.last_gimme_strokes)
			var holed: bool = bool(hitter.get("holed_out", false))
			var pin: Vector3 = current_hole_location
			if pin.is_zero_approx() and mp_mgr.has_method("get_target_pin_position"):
				pin = mp_mgr.get_target_pin_position()
			if pin.is_zero_approx() and _cached_current_green_pin != Vector3.ZERO:
				pin = _cached_current_green_pin
			omc.publish_local_shot(shot_start, ball_pos, club_str, lie_str, pen, gimme_strk, holed, pin)

	if is_dynamic_course:
		if practice_mode_active:
			var saved_club = _get_current_club()
			var saved_target = aim_target_pos
			var saved_yaw = _last_aim_yaw_offset_deg
			
			if not _skip_requested:
				var reset_delay = GlobalSettings.range_settings.ball_reset_timer.value
				if reset_delay > 0.0:
					await get_tree().create_timer(reset_delay).timeout
				if this_shot_seq != _shot_sequence_id:
					_shot_transition_active = false
					return
			
			var active_modal = get_tree().root.find_child("SwingReplayModal", true, false)
			if active_modal != null and is_instance_valid(active_modal) and active_modal.is_inside_tree() and not active_modal.get("is_detached"):
				await active_modal.closed
				if this_shot_seq != _shot_sequence_id:
					_shot_transition_active = false
					return
			
			if GlobalSettings.range_settings.auto_ball_reset.value:
				_reset_display_data()
				if has_node("RangeUI"):
					$RangeUI.set_data(display_data)
			
			# Ensure ball position and spawn position are restored to practice_start_pos
			$Player.ball.spawn_position = practice_start_pos
			$Player.ball.global_position = practice_start_pos
			
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				var active_player = mp_mgr.get_active_player()
				if not active_player.is_empty():
					active_player["position"] = practice_start_pos
					active_player["last_aim_target_pos"] = saved_target
					active_player["last_aim_yaw_offset_deg"] = saved_yaw
			
			aim_target_pos = saved_target
			if has_node("AimMarker"):
				$AimMarker.global_position = aim_target_pos
			
			if GlobalSettings.range_settings.camera_follow_mode.value:
				$Player.ball.aim_yaw_offset_deg = saved_yaw
				await reset_camera_to_start()
			else:
				$Player.reset_ball()
				$Player.ball.aim_yaw_offset_deg = saved_yaw
			
			# Recalculate lie for the practice starting position
			update_current_lie_and_reduction()
			
			# Restore aim yaw, aim distance and camera look
			$Player.ball.aim_yaw_offset_deg = saved_yaw
			if has_node("MapCanvas/AimDistanceLabel"):
				set_aim_distance(int(practice_start_pos.distance_to(aim_target_pos) * 1.09361))
				
			var yaw_rad = deg_to_rad(saved_yaw)
			var cam_pos = get_address_camera_position(practice_start_pos, yaw_rad)
			var target_look = get_camera_target_look(aim_target_pos, practice_start_pos)
			if has_node("PhantomCamera3D"):
				$PhantomCamera3D.global_position = cam_pos
				$PhantomCamera3D.look_at(target_look)
			if has_node("Camera3D"):
				$Camera3D.global_position = cam_pos
				$Camera3D.look_at(target_look)
				
			# Retain the exact club used on the previous shot
			_user_custom_club = saved_club
			var club_sel = get_club_selector()
			if club_sel != null and club_sel.has_method("select_club_by_name"):
				_is_updating_auto_club = true
				club_sel.select_club_by_name(saved_club)
				_is_updating_auto_club = false
			
			_update_hole_info_label(true)
			if has_node("RangeUI"):
				$RangeUI.hide_skip_button()
				if $RangeUI.has_method("on_next_shot_started"):
					$RangeUI.on_next_shot_started()
			_skip_requested = false
			_shot_transition_active = false
			return
		else:
			# Wait for the ball reset delay so the player can watch the ball finish rolling
			if not _skip_requested:
				var reset_delay = GlobalSettings.range_settings.ball_reset_timer.value
				if reset_delay > 0.0:
					await get_tree().create_timer(reset_delay).timeout
				if this_shot_seq != _shot_sequence_id:
					_shot_transition_active = false
					return
			
			# Reset ball physics state and clear tracers
			$Player.reset_ball()
			
			var active_modal = get_tree().root.find_child("SwingReplayModal", true, false)
			if active_modal != null and is_instance_valid(active_modal) and active_modal.is_inside_tree() and not active_modal.get("is_detached"):
				await active_modal.closed
				if this_shot_seq != _shot_sequence_id:
					_shot_transition_active = false
					return

			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				if mp_mgr.last_gimme_strokes > 0:
					var gimme_extra_wait = maxf(0.0, 1.2 - GlobalSettings.range_settings.ball_reset_timer.value)
					if gimme_extra_wait > 0.0:
						await get_tree().create_timer(gimme_extra_wait).timeout
						if this_shot_seq != _shot_sequence_id:
							_shot_transition_active = false
							return
					mp_mgr.last_gimme_strokes = 0
				
				if has_node("RangeUI"):
					$RangeUI.hide_skip_button()
					if $RangeUI.has_method("on_next_shot_started"):
						$RangeUI.on_next_shot_started()
				_skip_requested = false
				
				mp_mgr.select_next_player()
				_shot_transition_active = false
				return

			# Update labels (single player fallback)
			_update_hole_info_label(true)
			
			# Automatically reset player's aim target to default aim (hole if reachable, else fairway center)
			set_camera_follow_mode(false)
			_user_custom_club = ""
			update_auto_club()
			apply_default_aim()
			
			print("[CoursePlay] Ball at rest. Spawn position updated. Ready for next shot.")
			
			if has_node("RangeUI"):
				$RangeUI.hide_skip_button()
				if $RangeUI.has_method("on_next_shot_started"):
					$RangeUI.on_next_shot_started()
			_skip_requested = false
			_shot_transition_active = false
			return


	# Return camera/ball to starting position for driving range
	var saved_club = _get_current_club()
	var saved_target = aim_target_pos
	var saved_yaw = _last_aim_yaw_offset_deg if _last_aim_yaw_offset_deg != 0.0 else ($Player.ball.aim_yaw_offset_deg if ($Player and $Player.ball) else 0.0)
	var saved_aim_is_manual = _aim_is_manual

	if not _skip_requested:
		var reset_delay = GlobalSettings.range_settings.ball_reset_timer.value
		if reset_delay > 0.0:
			await get_tree().create_timer(reset_delay).timeout
		if this_shot_seq != _shot_sequence_id:
			_shot_transition_active = false
			return
	
	var active_range_modal = get_tree().root.find_child("SwingReplayModal", true, false)
	if active_range_modal != null and is_instance_valid(active_range_modal) and active_range_modal.is_inside_tree() and not active_range_modal.get("is_detached"):
		await active_range_modal.closed
		if this_shot_seq != _shot_sequence_id:
			_shot_transition_active = false
			return
	
	if GlobalSettings.range_settings.auto_ball_reset.value:
		_reset_display_data()
		$RangeUI.set_data(display_data)
		
	aim_target_pos = saved_target
	_aim_is_manual = saved_aim_is_manual
	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos

	if GlobalSettings.range_settings.camera_follow_mode.value:
		$Player.ball.aim_yaw_offset_deg = saved_yaw
		await reset_camera_to_start()
	else:
		$Player.reset_ball()
		$Player.ball.aim_yaw_offset_deg = saved_yaw
		update_camera_offset()
		
	# Retain the exact club used on the previous shot
	_user_custom_club = saved_club
	var club_sel = get_club_selector()
	if club_sel != null and club_sel.has_method("select_club_by_name"):
		_is_updating_auto_club = true
		club_sel.select_club_by_name(saved_club)
		_is_updating_auto_club = false

	# Restore aim distance label
	if has_node("MapCanvas/AimDistanceLabel"):
		set_aim_distance(int($Player.ball.global_position.distance_to(aim_target_pos) * 1.09361))

	if has_node("RangeUI"):
		$RangeUI.hide_skip_button()
		if $RangeUI.has_method("on_next_shot_started"):
			$RangeUI.on_next_shot_started()
	_skip_requested = false
	_shot_transition_active = false
	return


func _update_averages(target_club: String = "") -> void:
	var p_name = _get_current_player_name()
	var club_name = target_club if not target_club.is_empty() else _get_current_club()
	var mp = get_node_or_null("/root/MultiplayerManager")
	var canonical_name = mp.get_canonical_player_name(p_name) if mp != null and mp.has_method("get_canonical_player_name") else p_name
	var club_code = mp.normalize_club_code(club_name) if mp != null and mp.has_method("normalize_club_code") else club_name
	
	var global_stats = _load_global_stats()
	var raw_shots = []
	var target_p_key = p_name
	if mp != null and mp.has_method("_find_matching_player_key_in_dict"):
		var match_key = mp._find_matching_player_key_in_dict(global_stats, canonical_name)
		if not match_key.is_empty():
			target_p_key = match_key
	if global_stats.has(target_p_key):
		if global_stats[target_p_key].has(club_code):
			raw_shots = global_stats[target_p_key][club_code]
		elif global_stats[target_p_key].has(club_name):
			raw_shots = global_stats[target_p_key][club_name]
		
	var shots = mp.filter_valid_club_shots(raw_shots, club_code) if (mp != null and mp.has_method("filter_valid_club_shots")) else raw_shots
	if shots.is_empty():
		if has_node("RangeUI"):
			var r_ui = get_node("RangeUI")
			if r_ui != null and r_ui.has_method("reset_average_stats"):
				r_ui.call("reset_average_stats")
		return
		
	var sum_carry := 0.0
	var sum_speed := 0.0
	var sum_spin := 0.0
	var sum_offline := 0.0
	var sum_target_diff := 0.0
	var valid_target_diff_count := 0
	
	for shot in shots:
		sum_carry += float(shot.get("CarryDistance", 0.0))
		sum_speed += float(shot.get("Speed", 0.0))
		sum_spin += float(shot.get("TotalSpin", 0.0))
		var s_dist = absf(float(shot.get("SideDistance", 0.0)))
		var t_dist = absf(float(shot.get("TotalDistance", shot.get("CarryDistance", 0.0))))
		if s_dist > 100.0 or (t_dist > 15.0 and s_dist > t_dist * 1.2):
			s_dist = 0.0
		sum_offline += s_dist
		
		var target_dist = float(shot.get("TargetDistance", 0.0))
		var total_dist = float(shot.get("TotalDistance", 0.0))
		if target_dist > 0.0:
			sum_target_diff += (total_dist - target_dist)
			valid_target_diff_count += 1
			
	var count = shots.size()
	var avg_data = {
		"Carry": sum_carry / count,
		"Speed": sum_speed / count,
		"Spin": sum_spin / count,
		"Offline": sum_offline / count,
		"TargetDiff": sum_target_diff / valid_target_diff_count if valid_target_diff_count > 0 else 0.0
	}
	
	if has_node("RangeUI"):
		var r_ui = get_node("RangeUI")
		if r_ui != null and r_ui.has_method("update_average_stats"):
			r_ui.call("update_average_stats", avg_data)

	# No auto reset: leave final numbers visible

func _on_shot_replay_follow_changed(value: bool) -> void:
	var sess = get_node_or_null("/root/OnlineSession")
	var is_replay_active = sess != null and sess.has_method("is_replaying_remote_turn") and sess.is_replaying_remote_turn()
	if is_replay_active:
		set_camera_follow_mode(value)


func set_camera_follow_mode(value) -> void:
	var camera = get_node_or_null("PhantomCamera3D")
	if camera == null:
		return

	var is_replay_active := false
	if has_node("/root/OnlineSession"):
		var sess = get_node("/root/OnlineSession")
		if sess != null and sess.has_method("is_replaying_remote_turn"):
			is_replay_active = sess.is_replaying_remote_turn()

	var should_follow: bool = bool(value)
	if is_replay_active:
		if has_node("/root/GlobalSettings"):
			var gs = get_node("/root/GlobalSettings")
			if gs.range_settings != null and gs.range_settings.settings.has("shot_replay_follow"):
				should_follow = bool(gs.range_settings.shot_replay_follow.value)

	if should_follow and has_node("Player") and $Player.ball != null and (_shot_active or is_replay_active):
		camera.follow_mode = PhantomCamera3D.FollowMode.SIMPLE
		var player = $Player
		var target_node = player.get_camera_target() if player.has_method("get_camera_target") else player.ball
		camera.follow_target = target_node
		
		# Ensure PhantomCameraHost runs in IDLE mode (_process) to follow the interpolated target smoothly
		var pcam_host = get_node_or_null("Camera3D/PhantomCameraHost")
		if pcam_host != null:
			pcam_host.interpolation_mode = 1  # InterpolationMode.IDLE
		var cam_3d = get_node_or_null("Camera3D")
		if cam_3d != null:
			cam_3d.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

		# Keep camera follow aligned with the player's aim angle down the fairway/range
		# Using aim_yaw_offset_deg prevents the follow camera from jumping sideways/off-center due to HLA
		var yaw_rad = deg_to_rad(player.ball.aim_yaw_offset_deg)
		_last_travel_yaw = yaw_rad
		
		# Rigid follow locked to physics ball (Godot built-in 3D physics interpolation handles camera and ball in unison)
		camera.follow_damping = false
		
		# Check if putting to determine camera configuration
		var is_putting = player.ball.is_putt or is_putting_view()
		if is_putting:
			update_camera_fov(GlobalSettings.range_settings.camera_fov.value)
			_putt_close_view_triggered = false
			# Follow behind the ball at current address putting offset without zooming out
			var local_offset = Vector3(-1.35, 0.8, 0.0).rotated(Vector3.UP, yaw_rad)
			camera.follow_offset = local_offset
			# Retain current camera angle down the putting line instead of looking down at the ball
			camera.look_at_mode = PhantomCamera3D.LookAtMode.NONE
			camera.look_at_target = null
			camera.look_at_offset = Vector3.ZERO
			camera.look_at_damping = false
		else:
			_putt_close_view_triggered = false
			# Standard FOV for ball flight view (follows user's camera FOV setting)
			update_camera_fov(GlobalSettings.range_settings.camera_fov.value)
			
			# Follow behind the ball looking basically straight at it while framing the course ahead
			var cam_dist = 10.0
			var cam_height = 1.4
			var local_offset = Vector3(-cam_dist, cam_height, 0).rotated(Vector3.UP, yaw_rad)
			camera.follow_offset = local_offset
		
			# Rotate camera to look directly at the ball with slight elevation for better course framing
			camera.look_at_mode = PhantomCamera3D.LookAtMode.SIMPLE
			camera.look_at_target = target_node
			camera.look_at_offset = Vector3(0.0, 0.25, 0.0)
			camera.look_at_damping = false
	else:
		_putt_close_view_triggered = false
		_chip_close_view_triggered = false
		if has_node("/root/TensionManager"):
			TensionManager.stop_tension()
		camera.follow_mode = PhantomCamera3D.FollowMode.NONE
		camera.look_at_mode = PhantomCamera3D.LookAtMode.NONE
		camera.look_at_offset = Vector3.ZERO
		camera.look_at_damping = false
		update_camera_fov(GlobalSettings.range_settings.camera_fov.value)

func reset_camera_to_start() -> void:
	_shot_active = false
	_putt_close_view_triggered = false
	_chip_close_view_triggered = false
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	var camera = $PhantomCamera3D

	# Disable follow mode and restore default view settings/FOV
	set_camera_follow_mode(false)

	# Calculate offset behind the ball in the direction we are aiming
	var saved_yaw = $Player.ball.aim_yaw_offset_deg
	var yaw_rad = deg_to_rad(saved_yaw)
	var start_pos = get_address_camera_position($Player.ball.spawn_position, yaw_rad)
	var target_look = get_camera_target_look(aim_target_pos, $Player.ball.spawn_position)

	if _skip_requested:
		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.on_ready_for_shot(0.0, true)
		camera.global_position = start_pos
		camera.look_at_from_position(start_pos, target_look)
		if has_node("Camera3D"):
			$Camera3D.global_position = start_pos
			$Camera3D.look_at(target_look)
	else:
		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.on_ready_for_shot(1.5)
		# Tween camera back to starting position
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "global_position", start_pos, 1.5)

		# Rotate camera to face the aim target
		camera.look_at_from_position(start_pos, target_look)
		if has_node("Camera3D"):
			$Camera3D.global_position = start_pos
			$Camera3D.look_at(target_look)

		await tween.finished

	# Reset ball to starting position
	var player = $Player
	if player != null:
		player.reset_ball()
		player.ball.aim_yaw_offset_deg = saved_yaw


func on_remote_shot_replay_started(shot_event: Dictionary) -> void:
	var start_raw = shot_event.get("start", shot_event.get("start_pos", Vector3.ZERO))
	var end_raw = shot_event.get("end", shot_event.get("end_pos", Vector3.ZERO))
	var start_pos := Vector3.ZERO
	if start_raw is Vector3:
		start_pos = start_raw
	elif (start_raw is Array or start_raw is PackedFloat32Array or start_raw is PackedFloat64Array) and start_raw.size() >= 3:
		start_pos = Vector3(float(start_raw[0]), float(start_raw[1]), float(start_raw[2]))
	var end_pos := Vector3.ZERO
	if end_raw is Vector3:
		end_pos = end_raw
	elif (end_raw is Array or end_raw is PackedFloat32Array or end_raw is PackedFloat64Array) and end_raw.size() >= 3:
		end_pos = Vector3(float(end_raw[0]), float(end_raw[1]), float(end_raw[2]))

	var club := str(shot_event.get("club", "Dr"))
	var c_lower := club.strip_edges().to_lower()
	var is_putt := (c_lower in ["pt", "putt", "putter"] or c_lower.begins_with("putt"))

	_shot_active = true
	_skip_requested = false

	if has_node("Player") and $Player.ball != null:
		var diff := end_pos - start_pos
		var angle_rad := 0.0
		if Vector2(diff.x, diff.z).length() > 0.01:
			angle_rad = atan2(diff.z, diff.x)
			$Player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)
		$Player.ball.is_putt = is_putt
		$Player.ball.spawn_position = start_pos
		$Player.ball.global_position = start_pos
		if "prev_physics_pos" in $Player.ball:
			$Player.ball.prev_physics_pos = start_pos
		if "curr_physics_pos" in $Player.ball:
			$Player.ball.curr_physics_pos = start_pos

		var cam_pos := get_address_camera_position(start_pos, -angle_rad)
		var target_look := get_camera_target_look(end_pos, start_pos)
		if has_node("PhantomCamera3D"):
			$PhantomCamera3D.global_position = cam_pos
			$PhantomCamera3D.look_at(target_look)
		if has_node("Camera3D"):
			$Camera3D.global_position = cam_pos
			$Camera3D.look_at(target_look)

	var should_follow: bool = false
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("shot_replay_follow"):
			should_follow = bool(gs.range_settings.shot_replay_follow.value)
	set_camera_follow_mode(should_follow)


func on_remote_shot_replay_finished(shot_event: Dictionary) -> void:
	_shot_active = false
	set_camera_follow_mode(false)
	if has_node("Player") and $Player.ball != null:
		var end_raw = shot_event.get("end", shot_event.get("end_pos", Vector3.ZERO))
		var end_pos := Vector3.ZERO
		if end_raw is Vector3:
			end_pos = end_raw
		elif (end_raw is Array or end_raw is PackedFloat32Array or end_raw is PackedFloat64Array) and end_raw.size() >= 3:
			end_pos = Vector3(float(end_raw[0]), float(end_raw[1]), float(end_raw[2]))
		$Player.ball.spawn_position = end_pos
		$Player.ball.global_position = end_pos
		$Player.reset_ball()


func _on_skip_flight_requested() -> void:
	_skip_requested = true
	if has_node("Player"):
		$Player.skip_to_rest()



func _on_range_ui_hit_shot(data: Dictionary) -> void:
	if _is_remote_turn_locked():
		print("[Range] Remote turn or replay in progress — ignoring range UI shot.")
		return
	if has_node("Player"):
		$Player._on_range_ui_hit_shot(data)
		
	# For local injected shots, prime the display immediately with the static payload data.
	raw_ball_data = data.duplicate()
	_update_ball_display(false)
	_on_shot_initiated()

	# Re-enable camera follow if the setting is on
	if GlobalSettings.range_settings.camera_follow_mode.value:
		call_deferred("set_camera_follow_mode", true)


func _on_player_manual_hit() -> void:
	if _is_remote_turn_locked():
		print("[Range] Remote turn or replay in progress — ignoring manual hit.")
		return
	if has_node("Player"):
		raw_ball_data = $Player.shot_data.duplicate()
	_update_ball_display(false)
	_on_shot_initiated()
	# Re-enable camera follow if the setting is on
	if GlobalSettings.range_settings.camera_follow_mode.value:
		call_deferred("set_camera_follow_mode", true)



func _reset_display_data() -> void:
	raw_ball_data.clear()
	last_display.clear()
	display_data["Distance"] = "---"
	display_data["Carry"] = "---"
	display_data["Offline"] = "---"
	display_data["Apex"] = "---"
	display_data["VLA"] = "---"
	display_data["HLA"] = "---"
	display_data["Speed"] = "---"
	display_data["BallSpeed"] = "---"
	display_data["ClubSpeed"] = "---"
	display_data["SmashFactor"] = "---"
	display_data["BackSpin"] = "---"
	display_data["SideSpin"] = "---"
	display_data["TotalSpin"] = "---"
	display_data["SpinAxis"] = "---"


func _update_ball_display(is_final_rest: bool = true) -> void:
	var player = $Player
	display_data = ShotFormatter.format_ball_display(raw_ball_data, player, GlobalSettings.range_settings.range_units.value, is_final_rest, display_data)
	last_display = display_data.duplicate()
	$RangeUI.set_data(display_data, is_final_rest)


func set_practice_mode(enabled: bool) -> void:
	practice_mode_active = enabled
	practice_start_pos = $Player.ball.position


func _on_range_ui_reset_practice_clicked() -> void:
	$Player.ball.spawn_position = practice_start_pos
	$Player.ball.global_position = practice_start_pos
	$Player.ball.reset()
	reset_zoom_to_default()
	update_current_lie_and_reduction()
	_update_hole_info_label(true)
	if has_node("RangeUI") and $RangeUI.has_method("on_next_shot_started"):
		$RangeUI.on_next_shot_started()


func load_practice_hole(idx: int) -> void:
	if course_data_dict.is_empty():
		return
	var hole_info_data = course_data_dict.get("Hole Info", {})
	var hole_keys = hole_info_data.keys()
	hole_keys.sort()
	if hole_keys.is_empty():
		return
	
	# Clamp or wrap index
	if idx < 0:
		idx = hole_keys.size() - 1
	elif idx >= hole_keys.size():
		idx = 0
	current_practice_hole_index = idx
	
	var hole_key = hole_keys[idx]
	var hole_data = hole_info_data[hole_key]
	
	var tee_boxes = hole_data.get("Tee Boxes", {})
	var player_tee = "Blue"
	var mp_mgr_ref = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr_ref != null and not mp_mgr_ref.players.is_empty():
		var ap = mp_mgr_ref.get_active_player()
		if not ap.is_empty() and not str(ap.get("tee", "")).is_empty():
			player_tee = ap.get("tee")

	var tee_pos = null
	if tee_boxes.has(player_tee):
		tee_pos = tee_boxes[player_tee]
	else:
		for k in tee_boxes.keys():
			if str(k).to_lower() == player_tee.to_lower():
				tee_pos = tee_boxes[k]
				break
	if tee_pos == null:
		if tee_boxes.has("Blue"):
			tee_pos = tee_boxes["Blue"]
		elif not tee_boxes.is_empty():
			tee_pos = tee_boxes.values()[0]
			
	if tee_pos != null:
		var spawn_pos = Vector3(tee_pos[0], get_height(tee_pos[0], tee_pos[1]) + 0.059435, tee_pos[1])
		practice_start_pos = spawn_pos
		if has_node("Player") and $Player.ball != null:
			$Player.ball.spawn_position = spawn_pos
			$Player.ball.global_position = spawn_pos
			$Player.reset_ball()
			
		var hole_loc = hole_data.get("Hole Location")
		var par = hole_data.get("Par", 4)
		var hole_name = hole_data.get("Name", hole_key)
		
		current_hole_id = hole_key
		current_hole_name = hole_name
		current_hole_par = par
		shot_count = 0
		_user_custom_club = ""
		_aim_is_manual = false
		reset_zoom_to_default()
		update_current_lie_and_reduction()
		
		if hole_loc != null:
			current_hole_location = get_hole_location_for(hole_loc)
			
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				mp_mgr.current_hole_index = idx
				var active_player = mp_mgr.get_active_player()
				if not active_player.is_empty():
					active_player["position"] = spawn_pos
					active_player["strokes"] = 0
					active_player["shot_history"].clear()
					mp_mgr.emit_signal("active_player_changed", active_player)

			current_hole_tee_dist_yards = int(spawn_pos.distance_to(current_hole_location) * 1.09361)
			_update_hole_info_label(true)
			update_auto_club()
			apply_default_aim()
			_spawn_flag_pin()
			update_hole_outline()
			update_teebox_markers(player_tee)
			
		print("[PracticeMode] Loaded hole ", idx, " (", hole_name, ")")


func next_practice_hole() -> void:
	if GlobalSettings.is_chipping_minigame:
		return
	load_practice_hole(current_practice_hole_index + 1)


func prev_practice_hole() -> void:
	if GlobalSettings.is_chipping_minigame:
		return
	load_practice_hole(current_practice_hole_index - 1)


func is_free_camera_active() -> bool:
	return _free_camera != null and is_instance_valid(_free_camera) and _free_camera.is_active


func toggle_free_camera() -> void:
	set_free_camera_mode(not is_free_camera_active())


func set_free_camera_mode(enabled: bool) -> void:
	if enabled:
		if is_aerial_view:
			_on_map_button_pressed()
		if _free_camera == null or not is_instance_valid(_free_camera):
			var free_cam_script = load("res://Utils/free_camera.gd")
			_free_camera = free_cam_script.new()
			_free_camera.name = "FreeCamera3D"
			add_child(_free_camera)
			if not _free_camera.deactivated.is_connected(_on_free_camera_deactivated):
				_free_camera.deactivated.connect(_on_free_camera_deactivated)
		var cur_cam = get_viewport().get_camera_3d() if get_viewport() != null else null
		_free_camera.activate(cur_cam, self)
	else:
		if _free_camera != null and is_instance_valid(_free_camera):
			_free_camera.deactivate()
		reset_to_standard_ball_view()
	if has_node("RangeUI") and $RangeUI.has_method("set_free_camera_btn_state"):
		$RangeUI.set_free_camera_btn_state(enabled)


func _on_free_camera_deactivated() -> void:
	reset_to_standard_ball_view()
	if has_node("RangeUI") and $RangeUI.has_method("set_free_camera_btn_state"):
		$RangeUI.set_free_camera_btn_state(false)


func reset_to_standard_ball_view() -> void:
	if not has_node("Player") or $Player.ball == null:
		return
	var ball = $Player.ball
	var ball_pos: Vector3 = ball.global_position
	if ball_pos.is_zero_approx() and "spawn_position" in ball and not (ball.spawn_position as Vector3).is_zero_approx():
		ball_pos = ball.spawn_position

	var is_on_green: bool = false
	if has_method("is_ball_on_green"):
		is_on_green = bool(call("is_ball_on_green"))

	var aim_target: Vector3 = aim_target_pos if ("aim_target_pos" in self and not aim_target_pos.is_zero_approx()) else (ball_pos + Vector3.RIGHT * 50.0)
	var diff: Vector3 = aim_target - ball_pos
	var angle_rad: float = atan2(diff.z, diff.x)
	if absf(diff.x) < 0.001 and absf(diff.z) < 0.001:
		angle_rad = -deg_to_rad(ball.aim_yaw_offset_deg) if "aim_yaw_offset_deg" in ball else 0.0

	var cam_pos: Vector3 = get_address_camera_position(ball_pos, -angle_rad, is_on_green, false)
	var target_look: Vector3 = get_camera_target_look(aim_target, ball_pos, is_on_green)

	var fov_val: float = 75.0
	if has_node("/root/GlobalSettings") and GlobalSettings.range_settings != null and "camera_fov" in GlobalSettings.range_settings:
		fov_val = GlobalSettings.range_settings.camera_fov.value

	if has_node("PhantomCamera3D"):
		var pcam = $PhantomCamera3D
		pcam.follow_mode = PhantomCamera3D.FollowMode.NONE
		pcam.look_at_mode = PhantomCamera3D.LookAtMode.NONE
		pcam.global_position = cam_pos
		pcam.look_at(target_look)
		if pcam.camera_3d_resource != null:
			pcam.camera_3d_resource.fov = fov_val

	if has_node("Camera3D"):
		var cam3d = $Camera3D
		cam3d.global_position = cam_pos
		cam3d.look_at(target_look)
		cam3d.fov = fov_val
		cam3d.make_current()

	if has_node("/root/ScreenOffsetManager"):
		var som = get_node("/root/ScreenOffsetManager")
		var cam_to_register = get_node_or_null("PhantomCamera3D")
		if cam_to_register == null:
			cam_to_register = get_node_or_null("Camera3D")
		if cam_to_register != null:
			som.call("register_camera", cam_to_register)
		som.call("set_putter_active", is_on_green)
		som.call("on_ready_for_shot", 0.0, true)


func set_free_camera_active(val: bool) -> void:
	set_free_camera_mode(val)


func _on_map_button_pressed() -> void:
	if not is_aerial_view and is_free_camera_active():
		set_free_camera_mode(false)
	is_aerial_view = !is_aerial_view
	is_screen_aiming = false
	screen_aim_direction = 0.0
	_touch_points.clear()
	_last_pinch_distance = -1.0
	is_mouse_down_on_map = false
	is_dragging_map = false
	
	if has_node("MapCanvas"):
		$MapCanvas.visible = true
		if $MapCanvas.has_node("AerialZoomVBox"):
			$MapCanvas/AerialZoomVBox.visible = is_aerial_view
		if $MapCanvas.has_node("HoleInfoLabel"):
			var is_course_play = false
			if has_node("/root/MultiplayerManager"):
				var mp = get_node("/root/MultiplayerManager")
				if not mp.players.is_empty():
					is_course_play = true
			$MapCanvas/HoleInfoLabel.visible = is_aerial_view and not is_course_play
	
	# Update map button text and practice UI visibility in children and current scene
	for child in get_children():
		if child.has_method("update_map_button_text"):
			child.call("update_map_button_text", is_aerial_view)
		if child.has_method("update_practice_ui_visibility"):
			child.call("update_practice_ui_visibility", is_aerial_view)
			
	var current_scene = get_tree().current_scene
	if current_scene != null:
		for child in current_scene.get_children():
			if child.has_method("update_map_button_text"):
				child.call("update_map_button_text", is_aerial_view)
			if child.has_method("update_practice_ui_visibility"):
				child.call("update_practice_ui_visibility", is_aerial_view)
		
	# Toggle markers and distance label visibility
	var has_minimap = not MultiplayerManager.players.is_empty() or (has_node("/root/TensionManager") and TensionManager.is_course_play_active())
	if has_node("PlayerMarker"):
		$PlayerMarker.visible = is_aerial_view or has_minimap
	if has_node("AimMarker"):
		$AimMarker.visible = is_aerial_view or has_minimap
	if aim_line != null:
		var ball_at_rest = $Player and $Player.get_ball_state() == PhysicsEnums.BallState.REST
		aim_line.visible = is_aerial_view or (has_minimap and ball_at_rest)
	if has_node("MapCanvas/AimDistanceLabel"):
		$MapCanvas/AimDistanceLabel.visible = true
	if has_node("PinMarker"):
		$PinMarker.visible = is_aerial_view or has_minimap

	if is_aerial_view:
		# Reset camera user drag offset
		aerial_cam_user_offset = Vector3.ZERO
		var current_zone = get_current_zoom_zone()
		aerial_zoom = get_zoom_for_zone(current_zone)
		_last_zoom_zone = current_zone
		_last_was_on_green = (current_zone == 2)
		
		# Position aerial camera high above the ball and align it immediately
		if has_node("AerialCamera") and $Player and $Player.ball:
			var ball_pos = $Player.ball.global_position
			var hole_pos = current_hole_location
			if hole_pos.is_zero_approx():
				hole_pos = Vector3(250.0, ball_pos.y, 0.0)
			var dir_3d = (hole_pos - ball_pos)
			dir_3d.y = 0
			if dir_3d.is_zero_approx():
				dir_3d = Vector3(0, 0, -1)
			else:
				dir_3d = dir_3d.normalized()
			
			$AerialCamera.size = aerial_zoom
			
			# Orientation
			var right_vec = dir_3d.cross(Vector3.UP).normalized()
			var up_vec = dir_3d
			var back_vec = Vector3.UP
			$AerialCamera.global_transform.basis = Basis(right_vec, up_vec, back_vec)
			
			# Position
			var base_pos = ball_pos + dir_3d * (0.35 * aerial_zoom)
			$AerialCamera.global_position = Vector3(base_pos.x, 150.0, base_pos.z)
			$AerialCamera.make_current()
			
		update_hole_outline()
		call_deferred("_update_aerial_focus_neighbors")
		call_deferred("_focus_initial_aerial_control")
		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.set_suppressed(true)
		print("[Map] Switched to Aerial View")
	else:
		# Switch back to the main camera
		if has_node("Camera3D"):
			$Camera3D.make_current()
		update_hole_outline()
		update_camera_offset()
		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.set_suppressed(false)
		var map_btn = find_child("MapButton", true, false) as Control
		if map_btn == null and get_tree() != null and get_tree().current_scene != null:
			map_btn = get_tree().current_scene.find_child("MapButton", true, false) as Control
		if map_btn != null and is_instance_valid(map_btn) and map_btn.is_visible_in_tree():
			map_btn.call_deferred("grab_focus")
		print("[Map] Switched to Player View")


func _update_aerial_focus_neighbors() -> void:
	if not has_node("MapCanvas/AerialZoomVBox"):
		return
	var zoom_vbox = $MapCanvas/AerialZoomVBox
	var z_in = zoom_vbox.get_node_or_null("ZoomInButton") as Button
	var z_out = zoom_vbox.get_node_or_null("ZoomOutButton") as Button
	var g_btn = zoom_vbox.get_node_or_null("GridToggleButton") as Button
	if z_in == null or z_out == null or g_btn == null:
		return

	z_in.focus_neighbor_bottom = z_in.get_path_to(z_out)
	z_out.focus_neighbor_top = z_out.get_path_to(z_in)
	z_out.focus_neighbor_bottom = z_out.get_path_to(g_btn)
	g_btn.focus_neighbor_top = g_btn.get_path_to(z_out)

	var target_right: Control = null
	var target_candidates = ["PlaceBallButton", "PrevHoleButton", "NextHoleButton", "MapButton", "HideHelpersButton", "SettingsButton"]
	for cand in target_candidates:
		var found = find_child(cand, true, false) as Control
		if found == null:
			var cur_sc = get_tree().current_scene if get_tree() != null else null
			if cur_sc != null:
				found = cur_sc.find_child(cand, true, false) as Control
		if found != null and is_instance_valid(found) and found.is_visible_in_tree():
			target_right = found
			break

	if target_right != null:
		z_in.focus_neighbor_right = z_in.get_path_to(target_right)
		z_out.focus_neighbor_right = z_out.get_path_to(target_right)
		g_btn.focus_neighbor_right = g_btn.get_path_to(target_right)
		if target_right is Button:
			target_right.focus_neighbor_left = target_right.get_path_to(z_in)


func _focus_initial_aerial_control() -> void:
	if not is_aerial_view:
		return
	var place_btn = find_child("PlaceBallButton", true, false) as Control
	if place_btn == null and get_tree() != null and get_tree().current_scene != null:
		place_btn = get_tree().current_scene.find_child("PlaceBallButton", true, false) as Control
	if place_btn != null and is_instance_valid(place_btn) and place_btn.is_visible_in_tree():
		place_btn.grab_focus()
		return

	var map_btn = find_child("MapButton", true, false) as Control
	if map_btn == null and get_tree() != null and get_tree().current_scene != null:
		map_btn = get_tree().current_scene.find_child("MapButton", true, false) as Control
	if map_btn != null and is_instance_valid(map_btn) and map_btn.is_visible_in_tree():
		map_btn.grab_focus()
		return

	if has_node("MapCanvas/AerialZoomVBox/ZoomInButton"):
		$MapCanvas/AerialZoomVBox/ZoomInButton.grab_focus()


func _spawn_flag_pin() -> void:
	if current_hole_location.is_zero_approx():
		return
		
	if has_node("PinMarker"):
		var old_pm = get_node("PinMarker")
		remove_child(old_pm)
		old_pm.queue_free()
	if has_node("FlagPin"):
		var old_fp = get_node("FlagPin")
		remove_child(old_fp)
		old_fp.queue_free()
		
	# Create Pin Marker for aerial map view (glowing orange/yellow cylinder)
	var pin_marker = MeshInstance3D.new()
	pin_marker.name = "PinMarker"
	var pin_cyl = CylinderMesh.new()
	pin_cyl.top_radius = 0.4
	pin_cyl.bottom_radius = 0.4
	pin_cyl.height = 12.0
	pin_marker.mesh = pin_cyl
	var pin_mat = StandardMaterial3D.new()
	pin_mat.albedo_color = Color(1.0, 0.6, 0.1) # Neon Orange
	pin_mat.emission_enabled = true
	pin_mat.emission = Color(1.0, 0.6, 0.1)
	pin_mat.render_priority = 2
	pin_marker.material_override = pin_mat
	pin_marker.layers = 2
	
	# Add static 2D billboard golf flag sprite to pin marker for map/aerial view
	var pin_sprite = Sprite3D.new()
	pin_sprite.name = "MapFlagSprite"
	pin_sprite.layers = 2
	pin_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pin_sprite.no_depth_test = true
	pin_sprite.render_priority = 3
	pin_sprite.double_sided = true
	pin_sprite.pixel_size = 0.04
	pin_sprite.position = Vector3(0, 6.0, 0)
	if ResourceLoader.exists("res://assets/images/icons/golf_pin_flag.svg"):
		pin_sprite.texture = load("res://assets/images/icons/golf_pin_flag.svg")
	pin_marker.add_child(pin_sprite)

	add_child(pin_marker)
	pin_marker.global_position = current_hole_location
	var has_minimap = not MultiplayerManager.players.is_empty() or (has_node("/root/TensionManager") and TensionManager.is_course_play_active())
	pin_marker.visible = is_aerial_view or has_minimap
	
	# Create 3D flag pin at hole location (visible in 3D game view)
	var pin = Node3D.new()
	pin.name = "FlagPin"
	add_child(pin)
	pin.global_position = current_hole_location
	
	var q_str = ""
	var gs = GlobalSettings if GlobalSettings != null else (get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null)
	if gs != null and gs.has_method("get_graphics_quality"):
		q_str = gs.get_graphics_quality()
	FlagBuilder.build_flag_pin(pin, 3.0, Color(0.95, 0.12, 0.12), cup_radius, q_str)
	FlagBuilder.sync_hole_cutout_to_terrain(self, current_hole_location, cup_radius)
	
	print("[CoursePlay] FlagPin and PinMarker spawned at: ", current_hole_location)
	update_gimme_circles()
	update_flagstick_collision(is_default_club_putter())


func update_flagstick_collision(is_putt: bool) -> void:
	if has_node("FlagPin/FlagstickCollider/CollisionShape"):
		var col = get_node("FlagPin/FlagstickCollider/CollisionShape") as CollisionShape3D
		if col != null:
			col.disabled = is_putt


func update_teebox_markers(active_tee_color: String = "") -> void:
	if is_driving_range:
		return
		
	var hole_data: Dictionary = {}
	if not current_hole_id.is_empty():
		if course_data_dict.has("Hole Info") and course_data_dict["Hole Info"].has(current_hole_id):
			hole_data = course_data_dict["Hole Info"][current_hole_id]
		elif has_node("/root/MultiplayerManager"):
			var mp = get_node("/root/MultiplayerManager")
			if mp.hole_info.has(current_hole_id):
				hole_data = mp.hole_info[current_hole_id]

	if hole_data.is_empty() and course_data_dict.has("Hole Info") and not course_data_dict["Hole Info"].is_empty():
		var h_keys = course_data_dict["Hole Info"].keys()
		h_keys.sort()
		var h_idx = clamp(current_practice_hole_index, 0, h_keys.size() - 1)
		hole_data = course_data_dict["Hole Info"][h_keys[h_idx]]

	if active_tee_color.is_empty():
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null and not mp_mgr.players.is_empty():
			var ap = mp_mgr.get_active_player()
			if not ap.is_empty():
				active_tee_color = ap.get("tee", "Blue")
		else:
			active_tee_color = "Blue"

	var target = aim_target_pos if not aim_target_pos.is_zero_approx() else current_hole_location
	var height_cb = Callable(self, "get_height")
	TeeboxMarkerBuilder.update_course_teebox_markers(self, hole_data, active_tee_color, target, height_cb)


func _on_shot_initiated() -> void:
	_skip_requested = false
	_shot_active = true
	_shot_transition_active = false
	_zoom_zone_dirty = true
	if _aim_distance_indicator != null:
		_aim_distance_indicator.dismiss_immediate()
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_shot_started()
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")
	is_screen_aiming = false
	screen_aim_direction = 0.0
	_last_aim_target_pos = aim_target_pos
	_last_aim_yaw_offset_deg = $Player.ball.aim_yaw_offset_deg if ($Player and $Player.ball) else 0.0
	_putt_close_view_triggered = false
	_chip_close_view_triggered = false
	var is_putt_shot := false
	if has_node("Player") and $Player.ball != null:
		is_putt_shot = bool($Player.ball.is_putt)
	else:
		is_putt_shot = is_default_club_putter()
	update_flagstick_collision(is_putt_shot)
	if has_node("/root/TensionManager"):
		if TensionManager.suspense_state == TensionManager.SuspenseState.IDLE or TensionManager.suspense_state == TensionManager.SuspenseState.SPENT:
			TensionManager.reset_for_new_shot()

	if has_node("RangeUI"):
		$RangeUI.show_skip_button()
		if $RangeUI.has_method("on_ball_hit"):
			$RangeUI.on_ball_hit()

	# Early Trajectory Prediction for Suspense (if not already predicted by ball.gd)
	if has_node("/root/TensionManager") and TensionManager.is_course_play_active() and not current_hole_location.is_zero_approx() and not is_driving_range and has_node("Player") and $Player.ball != null:
		var ball_node = $Player.ball
		if TensionManager.suspense_state == TensionManager.SuspenseState.IDLE:
			var is_putt = ball_node.is_putt
			var is_sand = ball_node.is_in_sand or (ball_node.get("shot_was_in_sand") == true) or (ball_node.lie_type == "sand")
			var start_p = ball_node.global_position
			if TensionManager.is_shot_eligible_for_suspense(start_p, current_hole_location, is_putt, is_sand):
				var prediction = TensionManager.predict_shot_outcome(start_p, ball_node.velocity, is_putt, current_hole_location, is_sand)
				if prediction.get("will_enter_zone", false):
					var ending_dist = prediction.get("ending_dist", prediction.get("min_dist", 0.0))
					var delay_to_apex = prediction.get("delay_to_apex", 0.25)
					print("[TensionManager] Early suspense predicted for shot! Mode: %s, Delay to apex: %.2fs, Ending Dist: %.2fm. Scheduling heartbeat." % [
						prediction.get("mode", "putt"), delay_to_apex, ending_dist
					])
					TensionManager.schedule_apex_tension(prediction.get("mode", "putt"), delay_to_apex, ending_dist)

	if current_hole_location.is_zero_approx():
		return
	shot_count += 1
	print("[CoursePlay] Shot initiated. Count: ", shot_count)
	_update_hole_info_label(false)


func _update_hole_info_label(ball_is_at_rest: bool) -> void:
	if current_hole_location.is_zero_approx():
		return
	if not has_node("MapCanvas/HoleInfoLabel"):
		return
		
	var on_green = is_ball_on_green()
	if not on_green and has_node("Player") and $Player.ball != null:
		var ball_lie = str($Player.ball.get("lie_type")).to_lower()
		var p_lie = str($Player.get("current_lie_type")).to_lower()
		if ball_lie == "green" or p_lie == "green":
			on_green = true
	if not on_green and has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if not mp.players.is_empty():
			var ap = mp.get_active_player()
			if ap.get("lie_type", "").to_lower() == "green":
				on_green = true

	var dist_m = 0.0
	if ball_is_at_rest:
		dist_m = $Player.ball.global_position.distance_to(current_hole_location)
	else:
		dist_m = $Player.ball.spawn_position.distance_to(current_hole_location)
		
	if on_green:
		var dist_feet = int(round(dist_m * 3.28084))
		$MapCanvas/HoleInfoLabel.text = "%s | Par %d | %d Yards | Shots: %d | Ball: %d Feet to Pin" % [
			current_hole_name, current_hole_par, current_hole_tee_dist_yards, shot_count, dist_feet
		]
	else:
		var dist_yards = int(dist_m * 1.09361)
		$MapCanvas/HoleInfoLabel.text = "%s | Par %d | %d Yards | Shots: %d | Ball: %d Yards to Pin" % [
			current_hole_name, current_hole_par, current_hole_tee_dist_yards, shot_count, dist_yards
		]
	update_auto_club()


func update_hole_outline() -> void:
	if not has_node("HoleOutline") or not has_node("MinimapHoleOutline"):
		return
		
	var outline_node = $HoleOutline
	var minimap_outline_node = $MinimapHoleOutline
	var imm: ImmediateMesh = outline_node.mesh
	var m_imm: ImmediateMesh = minimap_outline_node.mesh
	imm.clear_surfaces()
	m_imm.clear_surfaces()
	
	var has_minimap = not MultiplayerManager.players.is_empty() or (has_node("/root/TensionManager") and TensionManager.is_course_play_active())
	
	# Determine visibilities
	outline_node.visible = is_aerial_view
	minimap_outline_node.visible = not is_aerial_view and has_minimap
	
	if not (outline_node.visible or minimap_outline_node.visible):
		return
		
	# Determine the path
	var path_pts: Array[Vector3] = []
	
	# Get the current hole info from config (if loaded)
	var has_path := false
	var active_hole = get_active_hole_config()
	if not active_hole.is_empty():
		var path_arr = active_hole.get("Hole Path")
		if path_arr != null and path_arr.size() > 0:
			has_path = true
			for pt in path_arr:
				path_pts.append(Vector3(pt[0], get_height(pt[0], pt[1]), pt[1]))
				
	# Fallback if no path is configured
	if not has_path:
		# Use player's starting/ball spawn position and current_hole_location
		var start_pt = $Player.ball.spawn_position if ($Player and $Player.ball) else Vector3.ZERO
		var tee_pos = start_pt
		if not active_hole.is_empty():
			var tee_boxes = active_hole.get("Tee Boxes", {})
			var active_player = null
			if has_node("/root/MultiplayerManager") and not get_node("/root/MultiplayerManager").players.is_empty():
				active_player = MultiplayerManager.get_active_player()
				
			var tee_color = active_player.get("tee", "Blue") if active_player != null else "Blue"
			var tee_coord = tee_boxes.get(tee_color)
			if tee_coord != null:
				tee_pos = Vector3(tee_coord[0], get_height(tee_coord[0], tee_coord[1]), tee_coord[1])
				
		path_pts.append(tee_pos)
		var hole_pos = current_hole_location
		if hole_pos.is_zero_approx():
			hole_pos = Vector3(450.0, tee_pos.y, 0.0)
		path_pts.append(hole_pos)
		
	# Generate geometry for outline (regular thickness for map view)
	var outer_vertices = get_path_buffer_polygon(path_pts, 25.0)
	var inner_vertices = get_path_buffer_polygon(path_pts, 23.5)
	
	if outer_vertices.size() > 1 and inner_vertices.size() == outer_vertices.size():
		imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(outer_vertices.size() - 1):
			var o1 = outer_vertices[j]
			var i1 = inner_vertices[j]
			var o2 = outer_vertices[j+1]
			var i2 = inner_vertices[j+1]
			
			# Triangle 1
			imm.surface_add_vertex(o1)
			imm.surface_add_vertex(i1)
			imm.surface_add_vertex(o2)
			
			# Triangle 2
			imm.surface_add_vertex(i1)
			imm.surface_add_vertex(i2)
			imm.surface_add_vertex(o2)
		imm.surface_end()
		
	# Generate geometry for minimap outline (thicker)
	var m_outer_vertices = get_path_buffer_polygon(path_pts, 27.5)
	var m_inner_vertices = get_path_buffer_polygon(path_pts, 22.5)
	
	if m_outer_vertices.size() > 1 and m_inner_vertices.size() == m_outer_vertices.size():
		m_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(m_outer_vertices.size() - 1):
			var o1 = m_outer_vertices[j]
			var i1 = m_inner_vertices[j]
			var o2 = m_outer_vertices[j+1]
			var i2 = m_inner_vertices[j+1]
			
			# Triangle 1
			m_imm.surface_add_vertex(o1)
			m_imm.surface_add_vertex(i1)
			m_imm.surface_add_vertex(o2)
			
			# Triangle 2
			m_imm.surface_add_vertex(i1)
			m_imm.surface_add_vertex(i2)
			m_imm.surface_add_vertex(o2)
		m_imm.surface_end()


func get_path_buffer_polygon(path_list: Array, radius: float) -> Array[Vector3]:
	if path_list.size() < 2:
		return []
		
	var left_side: Array[Vector3] = []
	var right_side: Array[Vector3] = []
	
	for i in range(path_list.size()):
		var pt = path_list[i]
		var p_xz = Vector2(pt.x, pt.z)
		
		# Compute direction vector at this point
		var dir := Vector2.ZERO
		if i == 0:
			var next_xz = Vector2(path_list[i+1].x, path_list[i+1].z)
			dir = (next_xz - p_xz).normalized()
		elif i == path_list.size() - 1:
			var prev_xz = Vector2(path_list[i-1].x, path_list[i-1].z)
			dir = (p_xz - prev_xz).normalized()
		else:
			var prev_xz = Vector2(path_list[i-1].x, path_list[i-1].z)
			var next_xz = Vector2(path_list[i+1].x, path_list[i+1].z)
			var dir1 = (p_xz - prev_xz).normalized()
			var dir2 = (next_xz - p_xz).normalized()
			dir = (dir1 + dir2).normalized()
			
		# Normal vector (rotate dir by 90 degrees counter-clockwise)
		var normal = Vector2(-dir.y, dir.x)
		
		# Generate left and right offset points
		var left_xz = p_xz + normal * radius
		var right_xz = p_xz - normal * radius
		
		# Get height
		var left_y = get_height(left_xz.x, left_xz.y) + 0.3
		var right_y = get_height(right_xz.x, right_xz.y) + 0.3
		
		left_side.append(Vector3(left_xz.x, left_y, left_xz.y))
		right_side.append(Vector3(right_xz.x, right_y, right_xz.y))
		
	# Combine into a single closed loop polygon
	var loop: Array[Vector3] = []
	loop.append_array(left_side)
	
	# Reverse right_side so the loop goes back smoothly
	right_side.reverse()
	loop.append_array(right_side)
	
	# Close the loop
	loop.append(left_side[0])
	
	return loop


func get_all_holes_config() -> Dictionary:
	var mp_mgr = get_node_or_null("/root/MultiplayerManager") if is_inside_tree() else null
	if mp_mgr != null and not mp_mgr.hole_info.is_empty():
		return mp_mgr.hole_info
	if not course_data_dict.is_empty() and course_data_dict.has("Hole Info"):
		return course_data_dict["Hole Info"]
	return {}


func get_active_hole_config() -> Dictionary:
	var all_holes = get_all_holes_config()
	if all_holes.is_empty():
		return {}

	# 1. Authoritative: Match by explicit current_hole_id if valid
	if current_hole_id != "" and all_holes.has(current_hole_id):
		return all_holes[current_hole_id]

	# 2. Authoritative for Match Play: Match by MultiplayerManager current hole ID
	var mp_mgr = get_node_or_null("/root/MultiplayerManager") if is_inside_tree() else null
	if mp_mgr != null and not mp_mgr.players.is_empty() and not mp_mgr.hole_ids.is_empty():
		var hole_idx = clamp(mp_mgr.current_hole_index, 0, mp_mgr.hole_ids.size() - 1)
		var hole_id = mp_mgr.hole_ids[hole_idx]
		if all_holes.has(hole_id):
			return all_holes[hole_id]

	# 3. Match by current_hole_location proximity (most reliable across practice/driving range)
	if not current_hole_location.is_zero_approx():
		var cur_2d = Vector2(current_hole_location.x, current_hole_location.z)
		var best_key = ""
		var best_dist := 10.0 # within 10 meters of pin
		for k in all_holes.keys():
			var h = all_holes[k]
			var h_loc = h.get("Hole Location")
			if h_loc != null and typeof(h_loc) == TYPE_ARRAY and h_loc.size() >= 2:
				var pin_2d = Vector2(float(h_loc[0]), float(h_loc[1]))
				var d = cur_2d.distance_to(pin_2d)
				if d < best_dist:
					best_dist = d
					best_key = k
		if best_key != "":
			return all_holes[best_key]

	# 4. Match by current_hole_name
	if current_hole_name != "":
		if all_holes.has(current_hole_name):
			return all_holes[current_hole_name]
		for k in all_holes.keys():
			if all_holes[k].get("Name", "") == current_hole_name:
				return all_holes[k]

	# 5. Match by current_practice_hole_index
	var hole_keys = all_holes.keys()
	hole_keys.sort()
	if current_practice_hole_index >= 0 and current_practice_hole_index < hole_keys.size():
		return all_holes[hole_keys[current_practice_hole_index]]

	return all_holes[hole_keys[0]]


func toggle_sky_view() -> void:
	is_sky_view_active = !is_sky_view_active
	update_camera_offset()
	if is_sky_view_active:
		update_camera_fov(30.0)
	else:
		update_camera_fov(GlobalSettings.range_settings.camera_fov.value)


func clear_surface_distance_caches() -> void:
	_cached_on_green_ball_pos = Vector3.INF
	_cached_on_fringe_ball_pos = Vector3.INF
	_cached_wrong_green_pos = Vector3.INF
	_cached_wrong_green_pin = Vector3.INF
	_cached_dist_nearest_green_pos = Vector3.INF
	_cached_dist_current_green_pos = Vector3.INF
	_cached_dist_current_green_pin = Vector3.INF
	_cached_dist_any_green_pos = Vector3.INF
	_cached_dist_fairway_pos = Vector3.INF
	_cached_dist_teebox_pos = Vector3.INF
	_cached_default_aim_ball_pos = Vector3.INF
	_cached_default_aim_targets.clear()

var _cached_on_green_ball_pos: Vector3 = Vector3.INF
var _cached_on_green_result: bool = false

func is_ball_on_green() -> bool:
	if not has_node("Player") or $Player.ball == null:
		return false
	var ball = $Player.ball
	var ball_pos: Vector3 = ball.global_position
	if ball_pos.is_equal_approx(_cached_on_green_ball_pos):
		return _cached_on_green_result
	_cached_on_green_ball_pos = ball_pos
	_cached_on_green_result = _calc_is_ball_on_green(ball)
	return _cached_on_green_result

func _calc_is_ball_on_green(ball: Node) -> bool:
	if is_ball_on_wrong_green():
		return false
	var lie = str(ball.get("lie_type")).to_lower()
	var p_lie = str($Player.get("current_lie_type")).to_lower()
	
	# If explicitly on teebox or in sand, definitely not on green
	if lie == "teebox" or p_lie == "teebox" or lie == "sand" or p_lie == "sand" or ball.is_in_sand:
		return false
		
	# Geometric check is ground truth if course mesh is present
	if has_method("get_distance_to_current_green"):
		var d_green = get_distance_to_current_green(ball.global_position)
		if d_green <= 0.001:
			return true
			
	if lie == "green" or p_lie == "green":
		return true
		
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if not mp.players.is_empty():
			var ap = mp.get_active_player()
			if ap.get("lie_type", "").to_lower() == "green":
				return true

	if has_method("get_distance_to_nearest_green"):
		var d_green = get_distance_to_nearest_green(ball.global_position)
		if d_green <= 0.001:
			return true
	return false


var _cached_on_fringe_ball_pos: Vector3 = Vector3.INF
var _cached_on_fringe_result: bool = false

func is_ball_on_fringe() -> bool:
	if not has_node("Player") or $Player.ball == null:
		return false
	var ball = $Player.ball
	var ball_pos: Vector3 = ball.global_position
	if ball_pos.is_equal_approx(_cached_on_fringe_ball_pos):
		return _cached_on_fringe_result
	_cached_on_fringe_ball_pos = ball_pos
	_cached_on_fringe_result = _calc_is_ball_on_fringe(ball)
	return _cached_on_fringe_result

func _calc_is_ball_on_fringe(ball: Node) -> bool:
	if is_ball_on_wrong_green():
		return false
	var lie = str(ball.get("lie_type")).to_lower()
	var p_lie = str($Player.get("current_lie_type")).to_lower()
	if lie == "teebox" or p_lie == "teebox" or lie == "sand" or p_lie == "sand" or ball.is_in_sand:
		return false
	if has_method("get_distance_to_current_green"):
		var d_green: float = get_distance_to_current_green(ball.global_position)
		if d_green > 0.001 and d_green <= 2.5:
			return true
	if lie == "fringe" or p_lie == "fringe":
		return true
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if not mp.players.is_empty():
			var ap = mp.get_active_player()
			if ap.get("lie_type", "").to_lower() == "fringe":
				return true
	if has_method("get_distance_to_nearest_green"):
		var d_green: float = get_distance_to_nearest_green(ball.global_position)
		return (d_green > 0.001 and d_green <= 2.5)
	return false


func is_putting_view(override_val: Variant = null) -> bool:
	if override_val != null:
		return bool(override_val)
	var club = _get_current_club().strip_edges().to_lower()
	return club in ["pt", "putt", "putter"] or club.begins_with("putt")


func get_camera_target_look(target_pos: Vector3, origin_pos: Vector3, is_on_green: Variant = null) -> Vector3:
	var is_putting = is_putting_view(is_on_green)
	var aim_dir = Vector3(target_pos.x - origin_pos.x, 0.0, target_pos.z - origin_pos.z).normalized() if not target_pos.is_zero_approx() else Vector3.ZERO
	if aim_dir.is_zero_approx():
		aim_dir = Vector3.RIGHT
		if has_node("Player") and $Player.ball != null:
			var yaw_rad = deg_to_rad($Player.ball.aim_yaw_offset_deg)
			aim_dir = Vector3.RIGHT.rotated(Vector3.UP, yaw_rad)

	if is_putting:
		return origin_pos + aim_dir * 3.5

	return origin_pos + aim_dir * 50.0 + Vector3.UP * 1.0


func get_camera_local_offset(override_is_on_green: Variant = null) -> Vector3:
	var is_on_green = is_putting_view(override_is_on_green)
		
	if is_on_green:
		return Vector3(-1.35, 0.8, 0)
		
	var cam_dist = 50.0 if is_sky_view_active else GlobalSettings.range_settings.camera_distance.value
	var cam_height = 15.0 if is_sky_view_active else GlobalSettings.range_settings.camera_height.value
	if not is_sky_view_active and (is_equal_approx(cam_dist, 15.0) or cam_dist > 8.0):
		cam_dist = 3.6
	if not is_sky_view_active and (is_equal_approx(cam_height, 2.4) or cam_height > 2.0):
		cam_height = 1.35
	return Vector3(-cam_dist, cam_height, 0)


func is_ball_in_sand(pos: Variant = null) -> bool:
	if has_node("Player") and $Player.ball != null:
		var b = $Player.ball
		if b.is_in_sand or (b.get("shot_was_in_sand") == true) or str(b.get("lie_type")).to_lower() in ["sand", "bunker"]:
			return true
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if not mp.players.is_empty():
			var ap = mp.get_active_player()
			if str(ap.get("lie_type", "")).to_lower() in ["sand", "bunker"]:
				return true
	if pos != null and _height_raycast != null:
		_height_raycast.global_position = Vector3(pos.x, 1000.0, pos.z)
		_height_raycast.target_position = Vector3(0.0, -2000.0, 0.0)
		_height_raycast.force_raycast_update()
		if _height_raycast.is_colliding():
			var collider = _height_raycast.get_collider()
			if collider:
				var cname = collider.name.to_lower()
				if (collider.has_meta("is_sand") and bool(collider.get_meta("is_sand"))) or \
					cname.contains("bunker") or cname.contains("sand") or \
					(collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.BUNKER):
					return true
	return false


func get_address_camera_position(ball_pos: Vector3, rot_y: float, override_is_on_green: Variant = null, is_aiming: bool = false) -> Vector3:
	var is_on_green = is_putting_view(override_is_on_green)
	
	if is_on_green:
		var green_offset = Vector3(-1.35, 0.8, 0.0).rotated(Vector3.UP, rot_y)
		if is_aiming:
			return ball_pos + green_offset
		return clamp_camera_position(ball_pos + green_offset)
		
	if is_sky_view_active:
		var sky_offset = Vector3(-50.0, 15.0, 0.0).rotated(Vector3.UP, rot_y)
		if is_aiming:
			return ball_pos + sky_offset
		return clamp_camera_position(ball_pos + sky_offset)
	
	var default_dist = GlobalSettings.range_settings.camera_distance.value
	var default_height = GlobalSettings.range_settings.camera_height.value
	if is_equal_approx(default_dist, 15.0) or default_dist > 8.0:
		default_dist = 3.6
	if is_equal_approx(default_height, 2.4) or default_height > 2.0:
		default_height = 1.35
	var back_dir = Vector3(-1.0, 0.0, 0.0).rotated(Vector3.UP, rot_y)
	
	var default_cam_pos = ball_pos + back_dir * default_dist + Vector3.UP * default_height
	
	# If on flat driving range or actively aiming, use smooth default (prevents raycast spikes and distance popping)
	if is_driving_range or is_aiming:
		return default_cam_pos

	var clamped_default = clamp_camera_position(default_cam_pos)

	var is_sand = is_ball_in_sand(ball_pos)
	var terrain_at_default = get_height(clamped_default.x, clamped_default.z)
	var elev_diff = terrain_at_default - ball_pos.y

	# Check terrain line-of-sight obstruction between ball and default camera
	var is_occluded = false
	var ray_start = ball_pos + Vector3.UP * 0.15
	for i in range(1, 12):
		var t = float(i) / 12.0
		var pt = ray_start.lerp(clamped_default, t)
		var h = get_height(pt.x, pt.z)
		if h > pt.y + 0.04:
			is_occluded = true
			break

	if not is_occluded and is_inside_tree():
		var world3d = get_world_3d()
		if world3d != null and world3d.direct_space_state != null:
			var query = PhysicsRayQueryParameters3D.create(ray_start, clamped_default, 1)
			var hit = world3d.direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				is_occluded = true

	# Evaluate if ball is in a deep sandtrap or at the bottom of a steep hill
	var is_deep_sand = is_sand and (elev_diff > 0.35 or is_occluded)
	var is_bottom_of_hill = elev_diff > 1.1 or is_occluded

	# Standard camera for all normal scenarios
	if not is_deep_sand and not is_bottom_of_hill:
		return clamped_default

	# Dynamic camera: zoom in / move closer to the ball so the player is grounded near the ball
	# rather than perched atop the hill/lip, keeping the ball in clear unobstructed view.
	var candidate_distances = [4.2, 3.8, 3.5, 3.2, 2.9, 2.6, 2.3]
	var best_pos = clamped_default
	var found_clear_candidate = false

	for dist in candidate_distances:
		var target_height = clamp(dist * 0.38, 1.1, 1.65)
		var cand_pos = ball_pos + back_dir * dist + Vector3.UP * target_height
		var clamped_cand = clamp_camera_position(cand_pos, 0.35)

		# Ground elevation rise under camera at this distance
		var ground_rise = get_height(clamped_cand.x, clamped_cand.z) - ball_pos.y
		if ground_rise > 0.65:
			# Too far up the hill/lip face, keep searching closer to the ball
			continue

		var cand_occluded = false
		for s in range(1, 6):
			var st = float(s) / 6.0
			var spt = ray_start.lerp(clamped_cand, st)
			if get_height(spt.x, spt.z) > spt.y + 0.04:
				cand_occluded = true
				break

		if not cand_occluded and is_inside_tree():
			var world3d = get_world_3d()
			if world3d != null and world3d.direct_space_state != null:
				var q = PhysicsRayQueryParameters3D.create(ray_start, clamped_cand, 1)
				var h = world3d.direct_space_state.intersect_ray(q)
				if not h.is_empty():
					cand_occluded = true

		if not cand_occluded:
			best_pos = clamped_cand
			found_clear_candidate = true
			break

	if not found_clear_candidate:
		var fallback_pos = ball_pos + back_dir * 2.3 + Vector3.UP * 1.15
		best_pos = clamp_camera_position(fallback_pos, 0.35)

	return best_pos


func update_camera_offset(_val = null) -> void:
	var offset = get_camera_local_offset()
	if has_node("PhantomCamera3D"):
		$PhantomCamera3D.follow_offset = offset
		
	# If ball is available and we are not in follow mode, position manually
	if has_node("Player") and $Player.ball != null:
		if has_node("PhantomCamera3D") and $PhantomCamera3D.follow_mode == PhantomCamera3D.FollowMode.NONE:
			var yaw_rad = deg_to_rad($Player.ball.aim_yaw_offset_deg)
			var cam_pos = get_address_camera_position($Player.ball.global_position, yaw_rad, null, is_actively_aiming())
			$PhantomCamera3D.global_position = cam_pos
			var target_look = get_camera_target_look(aim_target_pos, $Player.ball.global_position)
			$PhantomCamera3D.look_at(target_look)
			if has_node("Camera3D"):
				$Camera3D.global_position = cam_pos
				$Camera3D.look_at(target_look)
			if has_node("/root/ScreenOffsetManager"):
				ScreenOffsetManager.on_ready_for_shot()


func update_camera_fov(value: float) -> void:
	var fov_val = 30.0 if is_sky_view_active else value
	if has_node("PhantomCamera3D") and $PhantomCamera3D.camera_3d_resource != null:
		$PhantomCamera3D.camera_3d_resource.fov = fov_val
	if has_node("Camera3D"):
		$Camera3D.fov = fov_val


func update_camera_far(value: float) -> void:
	if MobilePerformance.is_mobile():
		value = minf(value, 600.0)
	if has_node("PhantomCamera3D") and $PhantomCamera3D.camera_3d_resource != null:
		$PhantomCamera3D.camera_3d_resource.far = value
	if has_node("Camera3D"):
		$Camera3D.far = value


# ============================================================
# Visual Effects: Depth of Field, Vignette, Atmospheric Fog
# ============================================================

func setup_depth_of_field() -> void:
	# Get the CameraAttributesPractical from the WorldEnvironment (Sky3D)
	var sky3d = get_node_or_null("Sky3D")
	if sky3d and sky3d is WorldEnvironment:
		camera_attributes = sky3d.camera_attributes as CameraAttributesPractical
	if camera_attributes == null:
		# Fallback: create one and assign it
		camera_attributes = CameraAttributesPractical.new()
		if sky3d and sky3d is WorldEnvironment:
			sky3d.camera_attributes = camera_attributes
	
	if has_node("Camera3D"):
		$Camera3D.attributes = camera_attributes
	
	var dof_on = GlobalSettings.range_settings.dof_enabled.value
	var blur_amt = GlobalSettings.range_settings.dof_blur_amount.value
	
	camera_attributes.dof_blur_far_enabled = dof_on
	camera_attributes.dof_blur_far_distance = 150.0
	camera_attributes.dof_blur_far_transition = 100.0
	camera_attributes.dof_blur_amount = blur_amt
	update_dof_focus()
	print("[VisualFX] DOF initialized: enabled=%s, blur=%.3f" % [str(dof_on), blur_amt])


func update_dof_focus() -> void:
	if camera_attributes == null:
		return
	if not GlobalSettings.range_settings.dof_enabled.value:
		return
	
	var focus_dist: float = 150.0
	var ball_pos = Vector3.ZERO
	var spawn_pos = Vector3.ZERO
	var ball_node = null
	
	if has_node("Player") and $Player.ball != null:
		ball_node = $Player.ball
		ball_pos = ball_node.global_position
		spawn_pos = ball_node.spawn_position
		
	# If the ball has moved away from its spawn position (e.g. hit or in flight),
	# we focus the camera on the ball. Otherwise, focus on the aim target.
	var is_ball_active = ball_node != null and ball_pos.distance_to(spawn_pos) > 0.1
	
	if is_ball_active:
		if has_node("Camera3D"):
			focus_dist = $Camera3D.global_position.distance_to(ball_pos)
		else:
			focus_dist = ball_pos.distance_to(aim_target_pos)
	else:
		focus_dist = ball_pos.distance_to(aim_target_pos)
		
	# Clamp to reasonable range
	focus_dist = clamp(focus_dist, 10.0, 500.0)
	camera_attributes.dof_blur_far_distance = focus_dist
	# Transition scales with distance — farther targets get softer transitions
	camera_attributes.dof_blur_far_transition = focus_dist * 0.6


func update_dof_enabled(value) -> void:
	if camera_attributes == null:
		return
	camera_attributes.dof_blur_far_enabled = value
	if value:
		update_dof_focus()


func update_dof_blur_amount(value) -> void:
	if camera_attributes == null:
		return
	camera_attributes.dof_blur_amount = value


func setup_vignette() -> void:
	var vignette_on = GlobalSettings.range_settings.vignette_enabled.value
	var vignette_str = GlobalSettings.range_settings.vignette_intensity.value
	
	# Create a CanvasLayer for the full-screen vignette overlay
	vignette_layer = CanvasLayer.new()
	vignette_layer.name = "VignetteLayer"
	vignette_layer.layer = -1  # Above game, below UI
	add_child(vignette_layer)
	
	# Create full-screen ColorRect
	vignette_rect = ColorRect.new()
	vignette_rect.name = "VignetteRect"
	vignette_rect.anchors_preset = Control.PRESET_FULL_RECT
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load and apply the vignette shader
	var shader = load("res://Courses/Environments/shaders/vignette.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", vignette_str)
		mat.set_shader_parameter("radius", 0.35)
		mat.set_shader_parameter("softness", 0.45)
		mat.set_shader_parameter("contrast", 2.0)
		mat.set_shader_parameter("horizontal_weight", 1.6)
		mat.set_shader_parameter("vertical_weight", 0.85)
		mat.set_shader_parameter("edge_desaturation", 0.3)
		vignette_rect.material = mat
		print("[VisualFX] Vignette shader loaded: enabled=%s, intensity=%.2f" % [str(vignette_on), vignette_str])
	else:
		print("[VisualFX] WARNING: Could not load vignette shader")
	
	vignette_layer.add_child(vignette_rect)
	vignette_layer.visible = vignette_on


func update_vignette_enabled(value) -> void:
	if vignette_layer:
		vignette_layer.visible = value


func update_vignette_intensity(value) -> void:
	if vignette_rect and vignette_rect.material:
		vignette_rect.material.set_shader_parameter("intensity", value)


func setup_atmospheric_fog() -> void:
	# Tune the Sky3D atmospheric fog for golf-appropriate distances
	var skydome = get_node_or_null("Sky3D/Skydome")
	if skydome == null:
		print("[VisualFX] No Skydome found, skipping fog tuning")
		return
	if is_driving_range:
		# Smooth realistic atmospheric depth haze for driving range to eliminate distant horizon and boundary wall jitter
		skydome.fog_density = 0.0018
		skydome.fog_start = 140.0
		skydome.fog_end = 350.0
		skydome.clouds_visible = true
		skydome.clouds_cumulus_visible = false
		skydome.clouds_speed = 0.005
		skydome.clouds_cumulus_speed = 0.003
		print("[VisualFX] Driving range atmospheric depth haze configured")
	elif MobilePerformance.is_mobile():
		# Clear fog and clouds for mobile devices for maximum performance
		skydome.fog_density = 0.0
		skydome.clouds_visible = false
		skydome.clouds_cumulus_visible = false
		print("[VisualFX] Fog and clouds disabled for mobile platform")
	else:
		# Restore original sky settings for dynamic courses on desktop
		skydome.fog_density = 0.001
		skydome.fog_end = 600.0
		skydome.fog_start = 0.0
		skydome.clouds_visible = true
		skydome.clouds_cumulus_visible = true
		skydome.clouds_speed = 0.005
		skydome.clouds_cumulus_speed = 0.003


func clamp_camera_position(pos: Vector3, min_clearance: float = 0.35) -> Vector3:
	var terrain_h = get_height(pos.x, pos.z)
	if pos.y < terrain_h + min_clearance:
		pos.y = terrain_h + min_clearance
	return pos


var _cached_circle_textures := {}

func _get_circle_texture(color: Color) -> ImageTexture:
	var color_key = color.to_html()
	if _cached_circle_textures.has(color_key):
		return _cached_circle_textures[color_key]
		
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	var outer_radius := size / 2.0 - 4.0
	var inner_radius := size / 2.0 - 16.0 # thickness of the circle line
	
	for y in range(size):
		for x in range(size):
			var dx := x - center
			var dy := y - center
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= outer_radius and dist >= inner_radius:
				var alpha := 1.0
				if dist > outer_radius - 2.0:
					alpha = (outer_radius - dist) / 2.0
				elif dist < inner_radius + 2.0:
					alpha = (dist - inner_radius) / 2.0
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	var tex := ImageTexture.create_from_image(img)
	_cached_circle_textures[color_key] = tex
	return tex


func _add_green_edge_to_map(edge_map: Dictionary, p1: Vector2, p2: Vector2) -> void:
	var k1 := Vector2i(roundi(p1.x * 1000.0), roundi(p1.y * 1000.0))
	var k2 := Vector2i(roundi(p2.x * 1000.0), roundi(p2.y * 1000.0))
	if k1 == k2:
		return
	var key: String
	if k1.x < k2.x or (k1.x == k2.x and k1.y < k2.y):
		key = "%d,%d_%d,%d" % [k1.x, k1.y, k2.x, k2.y]
	else:
		key = "%d,%d_%d,%d" % [k2.x, k2.y, k1.x, k1.y]
		
	if edge_map.has(key):
		edge_map[key]["count"] += 1
	else:
		edge_map[key] = { "count": 1, "a": p1, "b": p2 }


func _get_green_entry(pin_pos: Vector3) -> Dictionary:
	_init_cached_surface_bodies()
	if _cached_green_bodies.is_empty():
		_cached_surface_nodes_initialized = false
		_init_cached_surface_bodies()
		
	var pin_2d := Vector2(pin_pos.x, pin_pos.z)
	var target_entry = null
	var min_dist := INF
	
	for entry in _cached_green_bodies:
		var d = pin_2d.distance_to(entry.center_2d)
		if d - entry.radius > 60.0:
			continue
			
		var trans: Transform3D = entry.transform
		var inside_tri = false
		for shape_faces in entry.shapes:
			for i in range(0, shape_faces.size(), 3):
				if i + 2 < shape_faces.size():
					var a_3d = trans * shape_faces[i]
					var b_3d = trans * shape_faces[i+1]
					var c_3d = trans * shape_faces[i+2]
					var a := Vector2(a_3d.x, a_3d.z)
					var b := Vector2(b_3d.x, b_3d.z)
					var c := Vector2(c_3d.x, c_3d.z)
					if _is_point_in_triangle_2d(pin_2d, a, b, c):
						inside_tri = true
						break
			if inside_tri:
				break
				
		if inside_tri:
			target_entry = entry
			min_dist = 0.0
			break
		elif d < min_dist:
			min_dist = d
			target_entry = entry

	# Fallback search if not found in cached bodies
	if target_entry == null or min_dist > 60.0:
		var all_greens = _find_green_nodes(self)
		for node in all_greens:
			if node is StaticBody3D:
				var dist = node.global_position.distance_to(pin_pos)
				if dist < min_dist:
					min_dist = dist
					var shapes_data: Array = []
					var trans: Transform3D = node.global_transform
					for child in node.find_children("*", "CollisionShape3D"):
						if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
							shapes_data.append(child.shape.data)
					if not shapes_data.is_empty():
						target_entry = {
							"body": node,
							"transform": trans,
							"shapes": shapes_data,
							"center_2d": Vector2(node.global_position.x, node.global_position.z),
							"radius": 50.0
						}

	return target_entry if target_entry != null else {}


func _get_green_boundary_segments(pin_pos: Vector3) -> Array:
	var target_entry = _get_green_entry(pin_pos)
	if target_entry.is_empty():
		return []

	# Check for CylinderShape3D (island greens)
	if target_entry.has("body") and target_entry.body != null:
		for child in target_entry.body.find_children("*", "CollisionShape3D"):
			if child is CollisionShape3D and child.shape is CylinderShape3D:
				var cyl_radius: float = child.shape.radius
				var center = Vector2(target_entry.body.global_position.x, target_entry.body.global_position.z)
				var cyl_segments: Array = []
				var steps = 48
				for s in range(steps):
					var a1 = s * TAU / steps
					var a2 = (s + 1) * TAU / steps
					var p1 = center + Vector2(cos(a1), sin(a1)) * cyl_radius
					var p2 = center + Vector2(cos(a2), sin(a2)) * cyl_radius
					cyl_segments.append([p1, p2])
				return cyl_segments

	if not target_entry.has("shapes") or target_entry.shapes.is_empty():
		return []

	var edge_map := {}
	var trans: Transform3D = target_entry.transform
	for shape_faces in target_entry.shapes:
		for i in range(0, shape_faces.size(), 3):
			if i + 2 < shape_faces.size():
				var a_3d = trans * shape_faces[i]
				var b_3d = trans * shape_faces[i+1]
				var c_3d = trans * shape_faces[i+2]
				var a := Vector2(a_3d.x, a_3d.z)
				var b := Vector2(b_3d.x, b_3d.z)
				var c := Vector2(c_3d.x, c_3d.z)
				_add_green_edge_to_map(edge_map, a, b)
				_add_green_edge_to_map(edge_map, b, c)
				_add_green_edge_to_map(edge_map, c, a)

	var boundary_segments: Array = []
	for key in edge_map:
		if edge_map[key]["count"] == 1:
			boundary_segments.append([edge_map[key]["a"], edge_map[key]["b"]])
			
	return boundary_segments


func _get_green_edge_distance(pin_2d: Vector2, u: Vector2, boundary_segments: Array) -> float:
	if boundary_segments.is_empty():
		return INF
	var min_t := INF
	for seg in boundary_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var v := b - a
		var d := a - pin_2d
		var denom := u.x * v.y - u.y * v.x
		if absf(denom) > 0.00001:
			var t := (d.x * v.y - d.y * v.x) / denom
			var s := (d.x * u.y - d.y * u.x) / denom
			if t > 0.02 and s >= -0.01 and s <= 1.01:
				if t < min_t:
					min_t = t
	return min_t


const RANDOM_PIN_MIN_EDGE_METERS := 1.524 # 5 feet


## Returns the hole location for the given course-data location, randomized on the
## green (never closer than 5 feet from the edge) when the setting is enabled.
func get_hole_location_for(hole_loc: Array) -> Vector3:
	var base := Vector3(hole_loc[0], get_height(hole_loc[0], hole_loc[1]), hole_loc[1])
	if GlobalSettings == null or GlobalSettings.range_settings == null:
		return base
	if not GlobalSettings.range_settings.settings.has("random_pin_enabled") or not bool(GlobalSettings.range_settings.random_pin_enabled.value):
		return base
	var segments: Array = _get_green_boundary_segments(base)
	var triangles: Array = _get_green_triangles(base)
	if triangles.is_empty():
		return base
	var min_pt := Vector2(INF, INF)
	var max_pt := Vector2(-INF, -INF)
	if not segments.is_empty():
		for seg in segments:
			for p in seg:
				min_pt.x = minf(min_pt.x, p.x)
				min_pt.y = minf(min_pt.y, p.y)
				max_pt.x = maxf(max_pt.x, p.x)
				max_pt.y = maxf(max_pt.y, p.y)
	else:
		for tri in triangles:
			for p in tri:
				min_pt.x = minf(min_pt.x, p.x)
				min_pt.y = minf(min_pt.y, p.y)
				max_pt.x = maxf(max_pt.x, p.x)
				max_pt.y = maxf(max_pt.y, p.y)

	var best_cand: Vector2 = Vector2.ZERO
	var best_edge: float = -INF

	var pin_rng: RandomNumberGenerator = null
	if has_node("/root/OnlineSession") and get_node("/root/OnlineSession").is_online_match:
		var sess = get_node("/root/OnlineSession")
		var pin_seed = sess.match_meta.get("settings", {}).get("pin_seed", 0)
		var h_id = hole_loc[0] if hole_loc.size() > 0 else 0
		if has_node("/root/MultiplayerManager"):
			var mp = get_node("/root/MultiplayerManager")
			h_id = mp.get_current_hole_id()
		pin_rng = RandomNumberGenerator.new()
		pin_rng.seed = hash(str(pin_seed) + "_" + str(h_id))

	for _attempt in range(500):
		var rx = pin_rng.randf_range(min_pt.x, max_pt.x) if pin_rng != null else randf_range(min_pt.x, max_pt.x)
		var ry = pin_rng.randf_range(min_pt.y, max_pt.y) if pin_rng != null else randf_range(min_pt.y, max_pt.y)
		var cand := Vector2(rx, ry)
		var inside := false
		for tri in triangles:
			if _is_point_in_triangle_2d(cand, tri[0], tri[1], tri[2]):
				inside = true
				break
		if not inside:
			continue
		var min_edge := INF
		if not segments.is_empty():
			for seg in segments:
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(cand, seg[0], seg[1])
				min_edge = minf(min_edge, cand.distance_to(closest))
		else:
			min_edge = RANDOM_PIN_MIN_EDGE_METERS

		if min_edge > best_edge:
			best_edge = min_edge
			best_cand = cand

		if min_edge >= RANDOM_PIN_MIN_EDGE_METERS:
			return Vector3(cand.x, get_height(cand.x, cand.y), cand.y)

	if best_edge > 0.5:
		return Vector3(best_cand.x, get_height(best_cand.x, best_cand.y), best_cand.y)

	return base


func _create_gimme_ring_mesh(pin_pos: Vector3, dist_meters: float, line_width: float, y_offset: float, boundary_segments: Array, height_cache: Dictionary = {}) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var steps = 120
	var pin_2d = Vector2(pin_pos.x, pin_pos.z)
	
	var inner_verts: Array[Vector3] = []
	var outer_verts: Array[Vector3] = []
	inner_verts.resize(steps)
	outer_verts.resize(steps)
	
	var min_r = cup_radius + 0.04
	
	var sample_height = func(wx: float, wz: float) -> float:
		var cache_key = Vector2i(roundi(wx * 100.0), roundi(wz * 100.0))
		if height_cache.has(cache_key):
			return height_cache[cache_key]
		var gh = get_height(wx, wz)
		height_cache[cache_key] = gh
		return gh
	
	for i in range(steps):
		var angle = i * TAU / steps
		var u = Vector2(cos(angle), sin(angle))
		
		var edge_dist = _get_green_edge_distance(pin_2d, u, boundary_segments)
		var max_allowed = edge_dist if edge_dist < INF else INF
		
		# Clamp radius so it strictly conforms to the green boundary and never extends beyond the green
		var r_outer = minf(dist_meters, max_allowed)
		r_outer = maxf(r_outer, min_r + line_width)
		var r_inner = maxf(r_outer - line_width, min_r)
		
		# Sample height at outer, mid, and inner radii to ensure the ring follows sloping terrain
		var world_x_mid = pin_pos.x + ((r_outer + r_inner) * 0.5) * u.x
		var world_z_mid = pin_pos.z + ((r_outer + r_inner) * 0.5) * u.y
		var world_x_out = pin_pos.x + r_outer * u.x
		var world_z_out = pin_pos.z + r_outer * u.y
		var world_x_in = pin_pos.x + r_inner * u.x
		var world_z_in = pin_pos.z + r_inner * u.y
		
		var ground_h_out = sample_height.call(world_x_out, world_z_out)
		var ground_h_in = sample_height.call(world_x_in, world_z_in)
		var ground_h_mid = sample_height.call(world_x_mid, world_z_mid)
		# Ensure convex terrain between inner and outer ring doesn't cause clipping
		var mid_rise = ground_h_mid - maxf(ground_h_out, ground_h_in)
		if mid_rise > 0.0:
			ground_h_out += mid_rise
			ground_h_in += mid_rise
			
		var local_y_out = (ground_h_out + y_offset) - pin_pos.y
		var local_y_in = (ground_h_in + y_offset) - pin_pos.y
		
		outer_verts[i] = Vector3(r_outer * u.x, local_y_out, r_outer * u.y)
		inner_verts[i] = Vector3(r_inner * u.x, local_y_in, r_inner * u.y)
		
	for i in range(steps):
		var next_i = (i + 1) % steps
		var v_in_1 = inner_verts[i]
		var v_out_1 = outer_verts[i]
		var v_in_2 = inner_verts[next_i]
		var v_out_2 = outer_verts[next_i]
		
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v_in_1)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(v_out_1)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v_out_2)
		
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v_in_1)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v_out_2)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(v_in_2)
		
	st.generate_normals()
	return st.commit()


func _create_gimme_ring_material(color: Color, render_priority: int) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = render_priority
	return mat


func is_point_within_gimme_ring(test_pos: Vector3, pin_pos: Vector3, dist_meters: float) -> bool:
	var test_2d := Vector2(test_pos.x, test_pos.z)
	var pin_2d := Vector2(pin_pos.x, pin_pos.z)
	var d := test_2d.distance_to(pin_2d)
	if d > dist_meters:
		return false
	var boundary_segments: Array = _get_green_boundary_segments(pin_pos)
	if boundary_segments.is_empty():
		return true
	if d <= 0.05:
		return true
	var u := (test_2d - pin_2d) / d
	var edge_dist := _get_green_edge_distance(pin_2d, u, boundary_segments)
	if edge_dist < INF and d > (edge_dist + 0.05):
		return false
	return true


func update_gimme_circles() -> void:
	# Find FlagPin node
	var pin = get_node_or_null("FlagPin")
	if pin == null:
		return
		
	var pin_pos = pin.global_position
	if pin_pos.is_zero_approx() and not current_hole_location.is_zero_approx():
		pin_pos = current_hole_location
		
	var boundary_segments = _get_green_boundary_segments(pin_pos)
	var height_cache := {}
	
	# Gimme +1 Stroke Circle (Cyan)
	var enabled_1 = GlobalSettings.range_settings.gimme_range_1_enabled.value
	var dist_1_feet = GlobalSettings.range_settings.gimme_range_1_distance.value
	var dist_1_meters = dist_1_feet * 0.3048
	var mesh_1 = pin.get_node_or_null("GimmeCircle1")
	if mesh_1 != null and not (mesh_1 is MeshInstance3D):
		mesh_1.queue_free()
		mesh_1 = null
		
	if enabled_1:
		var ring_mesh_1 = _create_gimme_ring_mesh(pin_pos, dist_1_meters, 0.08, 0.004, boundary_segments, height_cache)
		if mesh_1 == null:
			mesh_1 = MeshInstance3D.new()
			mesh_1.name = "GimmeCircle1"
			mesh_1.material_override = _create_gimme_ring_material(Color(0.0, 0.85, 1.0, 0.85), 2)
			mesh_1.mesh = ring_mesh_1
			mesh_1.position = Vector3.ZERO
			mesh_1.rotation = Vector3.ZERO
			mesh_1.scale = Vector3.ONE
			pin.add_child(mesh_1)
		else:
			mesh_1.mesh = ring_mesh_1
			mesh_1.material_override = _create_gimme_ring_material(Color(0.0, 0.85, 1.0, 0.85), 2)
			mesh_1.visible = true
	else:
		if mesh_1 != null:
			mesh_1.visible = false
			
	# Gimme +2 Strokes Circle (Orange-Yellow)
	var enabled_2 = GlobalSettings.range_settings.gimme_range_2_enabled.value
	var dist_2_feet = GlobalSettings.range_settings.gimme_range_2_distance.value
	var dist_2_meters = dist_2_feet * 0.3048
	var mesh_2 = pin.get_node_or_null("GimmeCircle2")
	if mesh_2 != null and not (mesh_2 is MeshInstance3D):
		mesh_2.queue_free()
		mesh_2 = null
		
	if enabled_2:
		var ring_mesh_2 = _create_gimme_ring_mesh(pin_pos, dist_2_meters, 0.08, 0.005, boundary_segments, height_cache)
		if mesh_2 == null:
			mesh_2 = MeshInstance3D.new()
			mesh_2.name = "GimmeCircle2"
			mesh_2.material_override = _create_gimme_ring_material(Color(1.0, 0.85, 0.0, 0.85), 3)
			mesh_2.mesh = ring_mesh_2
			mesh_2.position = Vector3.ZERO
			mesh_2.rotation = Vector3.ZERO
			mesh_2.scale = Vector3.ONE
			pin.add_child(mesh_2)
		else:
			mesh_2.mesh = ring_mesh_2
			mesh_2.material_override = _create_gimme_ring_material(Color(1.0, 0.85, 0.0, 0.85), 3)
			mesh_2.visible = true
	else:
		if mesh_2 != null:
			mesh_2.visible = false

	# Gimme +3 Strokes Circle (Coral / Red)
	var enabled_3 = GlobalSettings.range_settings.gimme_range_3_enabled.value
	var dist_3_feet = GlobalSettings.range_settings.gimme_range_3_distance.value
	var dist_3_meters = dist_3_feet * 0.3048
	var mesh_3 = pin.get_node_or_null("GimmeCircle3")
	if mesh_3 != null and not (mesh_3 is MeshInstance3D):
		mesh_3.queue_free()
		mesh_3 = null
		
	if enabled_3:
		var ring_mesh_3 = _create_gimme_ring_mesh(pin_pos, dist_3_meters, 0.08, 0.006, boundary_segments, height_cache)
		if mesh_3 == null:
			mesh_3 = MeshInstance3D.new()
			mesh_3.name = "GimmeCircle3"
			mesh_3.material_override = _create_gimme_ring_material(Color(1.0, 0.35, 0.35, 0.85), 4)
			mesh_3.mesh = ring_mesh_3
			mesh_3.position = Vector3.ZERO
			mesh_3.rotation = Vector3.ZERO
			mesh_3.scale = Vector3.ONE
			pin.add_child(mesh_3)
		else:
			mesh_3.mesh = ring_mesh_3
			mesh_3.material_override = _create_gimme_ring_material(Color(1.0, 0.35, 0.35, 0.85), 4)
			mesh_3.visible = true
	else:
		if mesh_3 != null:
			mesh_3.visible = false


func get_closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab = b - a
	var ap = p - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq < 0.00001:
		return a
	var t = ap.dot(ab) / ab_len_sq
	t = clamp(t, 0.0, 1.0)
	return a + t * ab

func get_closest_point_on_polygon(p: Vector2, poly) -> Vector2:
	var closest_pt := Vector2.ZERO
	var min_dist_sq := INF
	var n = poly.size()
	if n == 0:
		return p
	for i in range(n):
		var a = poly[i]
		var b = poly[(i + 1) % n]
		var seg_pt = get_closest_point_on_segment(p, a, b)
		var dist_sq = p.distance_squared_to(seg_pt)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_pt = seg_pt
	return closest_pt


func get_club_selector() -> Node:
	return _find_node_by_name(self, "ClubSelector")


func _find_node_by_name(root: Node, name_to_find: String) -> Node:
	if root.name == name_to_find:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, name_to_find)
		if found:
			return found
	return null


func get_default_club() -> String:
	if is_driving_range:
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null:
			var p_name = _get_current_player_name()
			var bag = mp_mgr.get_player_bag(p_name)
			if not bag.is_empty():
				if bag.has("Dr"):
					return "Dr"
				return bag[0]
		return "Dr"
	if current_hole_location.is_zero_approx() and (aim_target_pos == null or aim_target_pos.is_zero_approx()):
		return "Dr"
	if not has_node("Player") or $Player.ball == null:
		return "Dr"
		
	var ball_pos = $Player.ball.global_position
	# If aiming has been manually adjusted, use distance to aim_target_pos.
	# Otherwise, choose club based on actual distance to the hole!
	var dist_m = ball_pos.distance_to(aim_target_pos) if _aim_is_manual else ball_pos.distance_to(current_hole_location)
	var dist_yards = int(dist_m * 1.09361)
	
	# Determine if ball is on the green
	var is_on_green = is_ball_on_green()
	if not is_on_green and not is_ball_on_wrong_green():
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null and not mp_mgr.players.is_empty():
			var active_p = mp_mgr.get_active_player()
			if not active_p.is_empty() and active_p.get("lie_type") == "green":
				is_on_green = true
	
	# Determine if we are in the teebox
	var is_in_teebox = false
	if not is_on_green and not practice_mode_active and not is_ball_on_wrong_green():
		is_in_teebox = ($Player.ball.get("lie_type") == "teebox" or $Player.get("current_lie_type") == "teebox")
		if not is_in_teebox:
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				var active_p = mp_mgr.get_active_player()
				if not active_p.is_empty():
					is_in_teebox = (active_p.get("strokes", 0) == 0)
			else:
				is_in_teebox = (shot_count == 0)
	
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	var p_name = _get_current_player_name()
	var is_fringe = is_ball_on_fringe()
	if is_ball_on_wrong_green():
		is_on_green = false
		is_fringe = false
	if mp_mgr != null and mp_mgr.has_method("get_suggested_club"):
		return mp_mgr.get_suggested_club(p_name, float(dist_yards), is_in_teebox, is_on_green, is_fringe)
	else:
		# Fallback if MultiplayerManager is unavailable
		if is_on_green or (is_fringe and dist_yards <= 35):
			return "Pt"
		elif is_in_teebox and dist_yards > 200:
			return "Dr"
		elif dist_yards >= 225:
			return "3w"
		elif dist_yards >= 210:
			return "5w"
		elif dist_yards >= 195:
			return "4i"
		elif dist_yards >= 180:
			return "5i"
		elif dist_yards >= 160:
			return "6i"
		elif dist_yards >= 140:
			return "7i"
		elif dist_yards >= 130:
			return "8i"
		elif dist_yards >= 120:
			return "9i"
		elif dist_yards >= 100:
			return "Pw"
		else:
			return "Sw"


func is_default_club_putter() -> bool:
	if is_ball_on_wrong_green():
		return false
	return get_default_club().to_lower() in ["pt", "putt", "putter"]


func update_auto_club(force_auto: bool = false) -> String:
	if _shot_active:
		return ""
	if current_hole_location.is_zero_approx() and (aim_target_pos == null or aim_target_pos.is_zero_approx()):
		return ""
	if not has_node("Player") or $Player.ball == null:
		return ""
		
	var selected_club = ""
	
	if _user_custom_club != "" and not force_auto:
		selected_club = _user_custom_club
	else:
		selected_club = get_default_club()

	# Auto-toggle green slope grid when putter is the default selected club (green or fringe)
	var is_pt = (selected_club.to_lower() in ["pt", "putt", "putter"])
	if _user_custom_club == "" or force_auto:
		show_green_grid = is_pt
	update_flagstick_collision(is_pt)

	# Find ClubSelector UI node and select club
	var club_sel = get_club_selector()
	if club_sel != null and club_sel.has_method("select_club_by_name"):
		_is_updating_auto_club = true
		club_sel.select_club_by_name(selected_club)
		_is_updating_auto_club = false

	# If aim has not been manually customized, set default aim for the selected club
	if not _aim_is_manual:
		apply_default_aim(selected_club)

	return selected_club


func _spawn_driving_range_elements() -> void:
	# Clean up any legacy or previously spawned indicator nodes
	if has_node("CenterLine"):
		$CenterLine.visible = false
		$CenterLine.queue_free()
	if has_node("YardMarkers"):
		$YardMarkers.queue_free()
	if has_node("RangeCenterTargetLine"):
		$RangeCenterTargetLine.queue_free()
	if has_node("DrivingRangeMarkings"):
		$DrivingRangeMarkings.queue_free()
	if has_node("DrivingRangeTrees"):
		$DrivingRangeTrees.queue_free()
	if has_node("MountainBackdrop"):
		$MountainBackdrop.queue_free()
	if has_node("DrivingRangeBaySetup"):
		$DrivingRangeBaySetup.queue_free()
	if has_node("ThickRoughBushes"):
		$ThickRoughBushes.queue_free()

	_spawn_hitting_bays()
	_spawn_boundary_walls()
	_spawn_ground_distance_indicators()
	_spawn_range_trees()
	_spawn_mountain_backdrop()
	if has_node("DrivingRangeTrees"):
		var q = GlobalSettings.get_graphics_quality() if GlobalSettings != null else "High"
		MobilePerformance.apply_graphics_quality($DrivingRangeTrees, q)



func _spawn_hitting_bays() -> void:
	if has_node("DrivingRangeBaySetup"):
		$DrivingRangeBaySetup.queue_free()
	var bays_script = load("res://Courses/Range/driving_range_bays.gd")
	if bays_script != null:
		var bays_node = bays_script.create_bay_setup()
		bays_node.name = "DrivingRangeBaySetup"
		add_child(bays_node)


func _spawn_ground_distance_indicators() -> void:
	var markings_root = Node3D.new()
	markings_root.name = "DrivingRangeMarkings"
	add_child(markings_root)

	var major_yardages: Array[float] = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0]
	var corridor_half_w: float = 26.0 # ~57 yards corridor width (52 meters across, matching fairway boundary)
	var max_dist_m: float = 350.0 * 0.9144 # Capped at 350 yards (320.04 meters)

	var line_mat: Material = null
	var shader = load("res://Courses/Environments/shaders/ground_markings.gdshader")
	if shader:
		var sm = ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("line_color", Color(0.98, 0.98, 1.0, 0.95))
		sm.set_shader_parameter("far_fade_start", 260.0)
		sm.set_shader_parameter("far_fade_end", 340.0)
		sm.render_priority = 2
		line_mat = sm
	else:
		var std_mat = StandardMaterial3D.new()
		std_mat.albedo_color = Color(0.98, 0.98, 1.0, 0.95)
		std_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		std_mat.render_priority = 2
		line_mat = std_mat

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(line_mat)

	# 1. Left and right corridor sideline boundary lines in smooth segmented quads to eliminate z-fighting and float precision jitter
	var seg_len: float = 10.0
	var current_x: float = 0.0
	while current_x < max_dist_m:
		var next_x = minf(current_x + seg_len, max_dist_m)
		var fade_alpha = clamp(remap(next_x, 280.0, max_dist_m, 1.0, 0.60), 0.0, 1.0)
		var seg_col = Color(1.0, 1.0, 1.0, fade_alpha)
		
		# Left sideline (-corridor_half_w)
		_add_ground_quad(st, current_x, next_x, -corridor_half_w - 0.32, -corridor_half_w + 0.32, 0.0005, seg_col)
		# Right sideline (+corridor_half_w)
		_add_ground_quad(st, current_x, next_x, corridor_half_w - 0.32, corridor_half_w + 0.32, 0.0005, seg_col)
		current_x = next_x

	# Precalculate 50-yard zones for line thickness and numbers
	var major_zones: Array[Dictionary] = []
	var anamorphic_stretch_y: float = 2.4 # Stretches text along flight direction to cancel perspective foreshortening
	for yd in major_yardages:
		var x_line = yd * 0.9144
		var dist_ratio = clamp((yd - 50.0) / 300.0, 0.0, 1.0)
		var line_thick = 1.60 + dist_ratio * 0.80 # 1.6m to 2.4m thick prominent line
		var base_letter_h = 5.0 + dist_ratio * 15.0 # Unstretched height
		var effective_h = base_letter_h * anamorphic_stretch_y # Physical length along ground
		var gap = 1.5 + dist_ratio * 1.5
		var label_x = (x_line - line_thick * 0.5) - gap - (effective_h * 0.5)
		major_zones.append({
			"yd": yd,
			"x_line": x_line,
			"line_thick": line_thick,
			"base_h": base_letter_h,
			"effective_h": effective_h,
			"label_x": label_x
		})

	# 2. 50-yard full lines across the corridor (thick and prominent, connecting left and right sidelines)
	for zone in major_zones:
		var x_line = zone.x_line
		var half_t = zone.line_thick * 0.5
		var alpha_50yd = clamp(remap(zone.yd, 250.0, 350.0, 1.0, 0.75), 0.5, 1.0)
		var col_50yd = Color(1.0, 1.0, 1.0, alpha_50yd)
		_add_ground_quad(st, x_line - half_t, x_line + half_t, -corridor_half_w, corridor_half_w, 0.0006, col_50yd)

	# 3. 10-yard ticks on left and right sidelines, smoothly fading out between 120 and 200 yards
	var tick_10yd_len: float = 6.0 # 6.0 meters inward
	for yd in range(10, 201, 10):
		if int(yd) % 50 == 0:
			continue
		var x_pos = yd * 0.9144
		var tick_thick = 0.55 # Thick tick line
		var alpha_10yd = clamp(remap(yd, 120.0, 200.0, 0.90, 0.0), 0.0, 0.90)
		if alpha_10yd <= 0.01:
			continue
		var col_10yd = Color(1.0, 1.0, 1.0, alpha_10yd)
		# Left sideline tick extending right (+Z)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, -corridor_half_w, -corridor_half_w + tick_10yd_len, 0.0005, col_10yd)
		# Right sideline tick extending left (-Z)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, corridor_half_w - tick_10yd_len, corridor_half_w, 0.0005, col_10yd)

	# 4. 1-yard ticks in approach zone (1 to 50 yards only), smoothly fading between 30 and 50 yards to prevent distant moire aliasing
	var tick_1yd_len: float = 2.2 # 2.2 meters inward
	for yd in range(1, 51):
		if yd % 10 == 0:
			continue
		var x_pos = yd * 0.9144
		var tick_thick = 0.30
		var alpha_1yd = clamp(remap(yd, 28.0, 50.0, 0.85, 0.0), 0.0, 0.85)
		if alpha_1yd <= 0.01:
			continue
		var col_1yd = Color(1.0, 1.0, 1.0, alpha_1yd)
		# Left sideline tick extending right (+Z)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, -corridor_half_w, -corridor_half_w + tick_1yd_len, 0.0004, col_1yd)
		# Right sideline tick extending left (-Z)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, corridor_half_w - tick_1yd_len, corridor_half_w, 0.0004, col_1yd)

	# Commit line mesh into a single high-performance draw call
	var mesh = st.commit()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "GroundMarkingsMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = line_mat
	mesh_inst.layers = 3 # Visible in player 3D camera and aerial map view
	markings_root.add_child(mesh_inst)

	# 5. 50-yard ground distance numbers in the middle (centered down the fairway along Z = 0)
	var font_bold = null
	if ResourceLoader.exists("res://addons/phantom_camera/fonts/Nunito-Black.ttf"):
		font_bold = load("res://addons/phantom_camera/fonts/Nunito-Black.ttf")

	for zone in major_zones:
		var label = Label3D.new()
		label.name = "GroundDist_%d" % int(zone.yd)
		label.text = str(int(zone.yd))
		if font_bold != null:
			label.font = font_bold
		label.font_size = 256
		label.pixel_size = zone.base_h / 240.0
		label.scale = Vector3(1.0, anamorphic_stretch_y, 1.0)
		label.modulate = Color(1.0, 1.0, 1.0)
		label.outline_modulate = Color(0.04, 0.04, 0.06, 0.8)
		label.outline_size = 6
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
		label.render_priority = 3
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Flat on the ground in the middle, oriented facing the golfer looking down +X
		label.rotation_degrees = Vector3(-90.0, -90.0, 0.0)
		label.position = Vector3(zone.label_x, 0.0008, 0.0)
		label.layers = 3
		markings_root.add_child(label)


func _add_ground_quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float, color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	var n = Vector3.UP
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(Vector3(x0, y, z0))
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(Vector3(x1, y, z0))
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(Vector3(x0, y, z1))

	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(Vector3(x1, y, z0))
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(Vector3(x1, y, z1))
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(Vector3(x0, y, z1))


func _spawn_boundary_walls() -> void:
	var far_wall_x := 415.0 # Behind the back trees (365m-406m) and in front of mountain backdrop (430m)
	var side_wall_z := 125.0 # Behind the side trees (72m-110m)
	var back_wall_x := -80.0 # Behind the tee trees (-32m to -70m)
	var wall_height := 1.5
	var wall_thickness := 0.2
	var wall_color := Color(0.15, 0.15, 0.15) # Premium dark gray

	# Left wall (at z = -side_wall_z)
	_spawn_wall(Vector3(back_wall_x, 0, -side_wall_z), Vector3(far_wall_x, 0, -side_wall_z), wall_height, wall_thickness, wall_color)
	# Right wall (at z = side_wall_z)
	_spawn_wall(Vector3(back_wall_x, 0, side_wall_z), Vector3(far_wall_x, 0, side_wall_z), wall_height, wall_thickness, wall_color)
	# Far wall (at x = far_wall_x)
	_spawn_wall(Vector3(far_wall_x, 0, -side_wall_z), Vector3(far_wall_x, 0, side_wall_z), wall_height, wall_thickness, wall_color)
	# Back wall (at x = back_wall_x)
	_spawn_wall(Vector3(back_wall_x, 0, -side_wall_z), Vector3(back_wall_x, 0, side_wall_z), wall_height, wall_thickness, wall_color)


func _spawn_wall(start: Vector3, end: Vector3, height: float, thickness: float, color: Color) -> void:
	var wall = MeshInstance3D.new()
	var box = BoxMesh.new()
	var dist = start.distance_to(end)
	var dir = (end - start).normalized()
	box.size = Vector3(thickness, height, dist)
	wall.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	wall.material_override = mat

	add_child(wall)
	wall.global_position = (start + end) / 2.0 + Vector3(0, height / 2.0, 0)

	var angle = atan2(dir.x, dir.z)
	wall.rotation.y = angle

	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	wall.add_child(static_body)


func _spawn_range_trees() -> void:
	if has_node("DrivingRangeTrees"):
		$DrivingRangeTrees.queue_free()

	var trees_root = Node3D.new()
	trees_root.name = "DrivingRangeTrees"
	add_child(trees_root)

	var tree_paths: Array[String] = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-autumn-gold-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-autumn-gold-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-autumn-red-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-birch-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-pine-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-willow-2-staticbody.tscn",
	]

	var tree_scenes: Array[PackedScene] = []
	for p in tree_paths:
		if ResourceLoader.exists(p):
			var sc = load(p) as PackedScene
			if sc:
				tree_scenes.append(sc)

	if tree_scenes.is_empty():
		push_warning("[range.gd] No tree scenes found to spawn.")
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = 2026 # Deterministic natural layout across sessions

	# Helper array to hold positions and scale values
	var tree_data: Array[Dictionary] = []

	# Scale distribution per user request:
	# - Most trees (~70%): about 1.5x the base size (1.40 - 1.65)
	# - A few huge ones (~15%): 2x the current size (1.95 - 2.25)
	# - A few (~15%): same size as currently (0.95 - 1.15)
	var add_tree = func(pos: Vector3, tier: int = 1):
		var roll := rng.randf()
		var p_base := 0.15
		var p_huge := 0.30 if tier <= 2 else 0.35
		var s: float
		if roll < p_base:
			s = rng.randf_range(0.95, 1.15)
		elif roll < p_huge:
			s = rng.randf_range(1.95, 2.25)
		else:
			s = rng.randf_range(1.40, 1.65)
		tree_data.append({"pos": pos, "scale": s})

	# White sideline corridor boundary is at +/-26.0m.
	# 50 yards off the white lines is 45.72m -> baseline Z = +/-71.72m.
	# Far end boundary markings end at 350 yards (320.04m) -> baseline X = 365.76m.
	var left_base_z := -71.72
	var right_base_z := 71.72
	var far_base_x := 365.76
	var back_base_x := -32.0

	# 1. Left sideline tree belt (X from -35m to 365m, 4 dense depth tiers + canopy fillers)
	var curr_x := -35.0
	while curr_x <= 365.0:
		# Tier 1 (front edge along baseline)
		add_tree.call(Vector3(curr_x + rng.randf_range(-2.0, 2.0), 0.0, left_base_z + rng.randf_range(-3.0, 3.0)), 1)
		# Tier 2 (mid-front row, interleaved)
		add_tree.call(Vector3(curr_x + rng.randf_range(1.5, 4.5), 0.0, left_base_z - 8.0 + rng.randf_range(-3.0, 3.0)), 2)
		# Tier 3 (mid-back row)
		add_tree.call(Vector3(curr_x + rng.randf_range(-1.0, 3.5), 0.0, left_base_z - 17.0 + rng.randf_range(-3.5, 3.5)), 3)
		# Tier 4 (deep forest row)
		add_tree.call(Vector3(curr_x + rng.randf_range(2.0, 5.5), 0.0, left_base_z - 26.5 + rng.randf_range(-4.0, 4.0)), 4)
		# Occasional deep cluster filler
		if rng.randf() < 0.40:
			add_tree.call(Vector3(curr_x + rng.randf_range(-2.0, 4.0), 0.0, left_base_z - 35.0 + rng.randf_range(-4.0, 4.0)), 4)
		curr_x += rng.randf_range(6.0, 9.0)

	# 2. Right sideline tree belt (X from -35m to 365m, 4 dense depth tiers + canopy fillers)
	curr_x = -35.0
	while curr_x <= 365.0:
		# Tier 1 (front edge along baseline)
		add_tree.call(Vector3(curr_x + rng.randf_range(-2.0, 2.0), 0.0, right_base_z + rng.randf_range(-3.0, 3.0)), 1)
		# Tier 2 (mid-front row)
		add_tree.call(Vector3(curr_x + rng.randf_range(1.5, 4.5), 0.0, right_base_z + 8.0 + rng.randf_range(-3.0, 3.0)), 2)
		# Tier 3 (mid-back row)
		add_tree.call(Vector3(curr_x + rng.randf_range(-1.0, 3.5), 0.0, right_base_z + 17.0 + rng.randf_range(-3.5, 3.5)), 3)
		# Tier 4 (deep forest row)
		add_tree.call(Vector3(curr_x + rng.randf_range(2.0, 5.5), 0.0, right_base_z + 26.5 + rng.randf_range(-4.0, 4.0)), 4)
		# Occasional deep cluster filler
		if rng.randf() < 0.40:
			add_tree.call(Vector3(curr_x + rng.randf_range(-2.0, 4.0), 0.0, right_base_z + 35.0 + rng.randf_range(-4.0, 4.0)), 4)
		curr_x += rng.randf_range(6.0, 9.0)

	# 3. Far end tree belt (Z from -72m to 72m across 365m line, 4 dense tiers + fillers)
	var curr_z := -72.0
	while curr_z <= 72.0:
		# Tier 1 (front row)
		add_tree.call(Vector3(far_base_x + rng.randf_range(-3.0, 3.0), 0.0, curr_z + rng.randf_range(-2.0, 2.0)), 1)
		# Tier 2 (mid-front row)
		add_tree.call(Vector3(far_base_x + 9.0 + rng.randf_range(-3.0, 3.0), 0.0, curr_z + rng.randf_range(1.5, 4.5)), 2)
		# Tier 3 (mid-back row)
		add_tree.call(Vector3(far_base_x + 18.5 + rng.randf_range(-3.5, 3.5), 0.0, curr_z + rng.randf_range(-1.0, 3.5)), 3)
		# Tier 4 (deep row)
		add_tree.call(Vector3(far_base_x + 28.0 + rng.randf_range(-4.0, 4.0), 0.0, curr_z + rng.randf_range(2.0, 5.5)), 4)
		# Occasional deep filler
		if rng.randf() < 0.40:
			add_tree.call(Vector3(far_base_x + 36.5 + rng.randf_range(-4.0, 4.0), 0.0, curr_z + rng.randf_range(-2.0, 4.0)), 4)
		curr_z += rng.randf_range(6.0, 9.0)

	# 4. Behind the tee belt (Z from -72m to 72m enclosing the back of the driving range)
	curr_z = -72.0
	while curr_z <= 72.0:
		# Tier 1 (front row behind tee line)
		add_tree.call(Vector3(back_base_x + rng.randf_range(-2.5, 2.5), 0.0, curr_z + rng.randf_range(-2.0, 2.0)), 1)
		# Tier 2 (mid-front row)
		add_tree.call(Vector3(back_base_x - 8.5 + rng.randf_range(-3.0, 3.0), 0.0, curr_z + rng.randf_range(1.5, 4.5)), 2)
		# Tier 3 (mid-back row)
		add_tree.call(Vector3(back_base_x - 17.5 + rng.randf_range(-3.5, 3.5), 0.0, curr_z + rng.randf_range(-1.0, 3.5)), 3)
		# Tier 4 (deep row)
		add_tree.call(Vector3(back_base_x - 26.5 + rng.randf_range(-4.0, 4.0), 0.0, curr_z + rng.randf_range(2.0, 5.5)), 4)
		# Occasional deep filler
		if rng.randf() < 0.40:
			add_tree.call(Vector3(back_base_x - 34.5 + rng.randf_range(-4.0, 4.0), 0.0, curr_z + rng.randf_range(-2.0, 4.0)), 4)
		curr_z += rng.randf_range(6.5, 9.5)

	# 5. Corner infill clusters (ensuring rich, dense wrapping where sideline and end belts meet)
	var corners = [
		{"xmin": 360.0, "xmax": 402.0, "zmin": -106.0, "zmax": -68.0}, # Far left
		{"xmin": 360.0, "xmax": 402.0, "zmin": 68.0, "zmax": 106.0},   # Far right
		{"xmin": -66.0, "xmax": -28.0, "zmin": -106.0, "zmax": -68.0}, # Near left
		{"xmin": -66.0, "xmax": -28.0, "zmin": 68.0, "zmax": 106.0},   # Near right
	]
	for c in corners:
		for k in range(12):
			var cx = rng.randf_range(c.xmin, c.xmax)
			var cz = rng.randf_range(c.zmin, c.zmax)
			add_tree.call(Vector3(cx, 0.0, cz), 3)

	# Instantiate trees
	for i in range(tree_data.size()):
		var data = tree_data[i]
		var pos: Vector3 = data["pos"]
		var scene_idx = rng.randi() % tree_scenes.size()
		var tree_inst = tree_scenes[scene_idx].instantiate() as StaticBody3D
		if tree_inst == null:
			continue
		tree_inst.name = "RangeTree_%d" % i
		tree_inst.position = Vector3(pos.x, get_height(pos.x, pos.z), pos.z)
		tree_inst.rotation.y = rng.randf_range(0.0, TAU)
		var s: float = data["scale"]
		tree_inst.scale = Vector3(s, s, s)
		trees_root.add_child(tree_inst)

	print("[DrivingRange] Spawned %d trees densely surrounding driving range (mixed sizes: ~70%% 1.5x, ~15%% 2x, ~15%% 1x)." % tree_data.size())


func _spawn_mountain_backdrop() -> void:
	if has_node("MountainBackdrop"):
		$MountainBackdrop.queue_free()

	var tex = load("res://Courses/Environments/mountain_backdrop_seamless.png")
	if tex == null:
		push_warning("[range.gd] Mountain backdrop texture not found.")
		return

	var mountain_root = Node3D.new()
	mountain_root.name = "MountainBackdrop"
	add_child(mountain_root)

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	# Cylindrical panorama arc in the far background past the driving range trees
	var center_x := 30.0
	var radius := 430.0
	var y_bottom := -4.0
	var y_top := 145.0
	var segments := 72
	var angle_start := deg_to_rad(-115.0)
	var angle_end := deg_to_rad(115.0)
	var angle_span := angle_end - angle_start

	# Center the highest mountain peaks directly down the fairway (+X, angle = 0.0)
	var u_start := -0.75
	var u_end := 1.75

	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a0 := angle_start + t0 * angle_span
		var a1 := angle_start + t1 * angle_span
		var x0 := center_x + radius * cos(a0)
		var z0 := radius * sin(a0)
		var x1 := center_x + radius * cos(a1)
		var z1 := radius * sin(a1)
		var u0 := lerpf(u_start, u_end, t0)
		var u1 := lerpf(u_start, u_end, t1)

		var p_b0 := Vector3(x0, y_bottom, z0)
		var p_t0 := Vector3(x0, y_top, z0)
		var p_b1 := Vector3(x1, y_bottom, z1)
		var p_t1 := Vector3(x1, y_top, z1)

		var n0 := Vector3(center_x - x0, 0.0, -z0).normalized()
		var n1 := Vector3(center_x - x1, 0.0, -z1).normalized()

		# Triangle 1
		st.set_normal(n0)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(p_b0)

		st.set_normal(n0)
		st.set_uv(Vector2(u0, 0.0))
		st.add_vertex(p_t0)

		st.set_normal(n1)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(p_t1)

		# Triangle 2
		st.set_normal(n0)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(p_b0)

		st.set_normal(n1)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(p_t1)

		st.set_normal(n1)
		st.set_uv(Vector2(u1, 1.0))
		st.add_vertex(p_b1)

	var mesh = st.commit()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MountainMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_inst.layers = 1
	mountain_root.add_child(mesh_inst)

	if _weather_lighting_controller != null and is_instance_valid(_weather_lighting_controller):
		_weather_lighting_controller.update_backdrop_lighting()

	print("[DrivingRange] Spawned seamless 2D mountain backdrop (radius=%.1fm, height=%.1fm)." % [radius, y_top - y_bottom])


func _on_player_profile_changed(player_name: String) -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")
	var session_rec = get_node_or_null("SessionRecorder")
	if session_rec != null and not player_name.is_empty():
		session_rec.username = player_name
	_update_averages()

	# Update Player 3D tracers to match newly selected profile
	if has_node("Player") and $Player.has_method("set_profile"):
		$Player.set_profile(player_name)

	# Update launch monitor handedness for current profile if LM manager exists
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not player_name.is_empty() and has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("set_handedness"):
			var hand = mp_mgr.get_player_handedness(player_name)
			lm.set_handedness(hand)

	# Update Shot Traces overlay & dispersion for newly selected profile
	var club = _get_current_club()
	if is_driving_range and _shot_trace_overlay != null and _shot_trace_overlay.is_active():
		_shot_trace_overlay.on_player_changed(shot_history, player_name, club)
	if is_driving_range and has_node("RangeUI") and _shot_trace_overlay != null and _shot_trace_overlay.is_active():
		var club_shots = _get_shots_for_club(club, player_name)
		$RangeUI.show_dispersion(club_shots, club)


func _get_current_player_name() -> String:
	if not is_driving_range:
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null and not mp_mgr.players.is_empty() and not mp_mgr.hole_ids.is_empty():
			var active_player = mp_mgr.get_active_player()
			if not active_player.is_empty() and not str(active_player.get("name", "")).is_empty():
				return str(active_player.get("name", "Player 1"))
	if has_node("RangeUI"):
		var r_ui = get_node("RangeUI")
		if r_ui.has_method("get_selected_player_name"):
			var sel_name = r_ui.get_selected_player_name()
			if not sel_name.is_empty():
				return sel_name
	if has_node("RangeUI/HBoxContainer/PlayerName"):
		var pn = $RangeUI/HBoxContainer/PlayerName.text
		if not pn.is_empty():
			return pn
	var session_rec = get_node_or_null("SessionRecorder")
	if session_rec != null and not session_rec.username.is_empty() and session_rec.username != "Player1":
		return session_rec.username
	return "Player 1"


func _get_current_club() -> String:
	if not _user_custom_club.is_empty():
		return _user_custom_club
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.current_club.is_empty():
		return mp_mgr.current_club
	var club_sel = get_club_selector()
	if club_sel != null and "current_club" in club_sel and club_sel.current_club != null and not club_sel.current_club.text.is_empty():
		return club_sel.current_club.text
	var session_rec = get_node_or_null("SessionRecorder")
	if session_rec != null and not session_rec.current_club.is_empty():
		return session_rec.current_club
	if has_node("Player") and $Player.ball != null and not $Player.ball.current_selected_club.is_empty():
		return $Player.ball.current_selected_club
	return "Dr"


func _on_club_selected(club_name: String) -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")
	_update_averages(club_name)
	var is_pt = (club_name.to_lower() in ["pt", "putt", "putter"])
	update_flagstick_collision(is_pt)
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.set_putter_active(is_pt)
	if not _is_updating_auto_club:
		_user_custom_club = club_name
	if has_node("Player") and $Player.ball != null and $Player.ball.has_method("_on_club_selected"):
		$Player.ball._on_club_selected(club_name)
	if is_driving_range and has_node("Player") and $Player.has_method("clear_tracers"):
		$Player.clear_tracers()
	if not _shot_active and not is_aerial_view:
		if not _is_updating_auto_club and not _aim_is_manual and not current_hole_location.is_zero_approx():
			apply_default_aim(club_name)
		else:
			update_camera_offset()

	# Update shot traces & dispersion overlay if active
	if is_driving_range and _shot_trace_overlay != null and _shot_trace_overlay.is_active():
		var cur_player = _get_current_player_name()
		_shot_trace_overlay.on_club_changed(shot_history, club_name, cur_player)
		if has_node("RangeUI"):
			var club_shots = _get_shots_for_club(club_name, cur_player)
			$RangeUI.show_dispersion(club_shots, club_name)


func _on_active_player_changed(_player: Dictionary) -> void:
	var p_name = str(_player.get("name", ""))
	if not p_name.is_empty() and has_node("Player") and $Player.has_method("set_profile"):
		$Player.set_profile(p_name)

	# If MultiplayerController (course_play.gd) is present, it handles ball positioning, resetting, lie detection, aim angle, and camera setup.
	var is_course_play = has_node("MultiplayerController") or get_node_or_null("MultiplayerController") != null or (get_parent() != null and get_parent().name == "CoursePlay")
	if is_course_play:
		_aim_is_manual = false
		if not practice_mode_active:
			_user_custom_club = ""
		_update_averages()
		return

	_aim_is_manual = false
	if not practice_mode_active:
		_user_custom_club = ""
	var is_tee = (_player.get("strokes", 0) == 0)
	if is_tee:
		reset_zoom_to_default()
	_update_averages()
	update_auto_club(is_tee)

	if has_node("Player") and $Player.ball != null and not _player.is_empty():
		var p_pos = _player.get("position", Vector3.ZERO)
		if typeof(p_pos) == TYPE_VECTOR3 and not (p_pos as Vector3).is_zero_approx():
			$Player.ball.spawn_position = p_pos
			$Player.ball.lie_type = _player.get("lie_type", "teebox" if is_tee else "fairway")
			$Player.reset_ball()
			if $Player.get("_last_starting_pos") != null:
				$Player._last_starting_pos = p_pos
			update_current_lie_and_reduction()

			apply_default_aim()


func _on_player_changed(_dir: String, _player_name: String) -> void:
	if not practice_mode_active:
		_user_custom_club = ""
	_update_averages()
	update_auto_club(true)


func _load_global_stats() -> Dictionary:
	return get_node("/root/MultiplayerManager").load_global_club_stats()


func _save_global_stats(stats: Dictionary) -> void:
	get_node("/root/MultiplayerManager").save_global_club_stats(stats)


func _record_global_shot(player_name: String, club_name: String, raw_shot: Dictionary) -> bool:
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and mp.has_method("record_global_shot"):
		return mp.record_global_shot(player_name, club_name, raw_shot)
	return false


func _remove_last_global_shot(player_name: String, club_name: String) -> void:
	get_node("/root/MultiplayerManager").remove_last_global_shot(player_name, club_name)


func remove_last_shot() -> void:
	if not shot_history.is_empty():
		var last_shot = shot_history.pop_back()
		var p_name = last_shot.get("player", "")
		var club_name = last_shot.get("club", "")
		if not p_name.is_empty() and not club_name.is_empty():
			if last_shot.get("recorded_in_averages", true):
				_remove_last_global_shot(p_name, club_name)
		_update_averages()
		if is_driving_range and _shot_trace_overlay != null and _shot_trace_overlay.is_active():
			var cur_p = _get_current_player_name()
			var cur_c = _get_current_club()
			_shot_trace_overlay.on_player_changed(shot_history, cur_p, cur_c)
			if has_node("RangeUI"):
				var club_shots = _get_shots_for_club(cur_c, cur_p)
				$RangeUI.show_dispersion(club_shots, cur_c)


func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq == 0.0:
		return ap.length()
	var t := clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var projection := a + t * ab
	return p.distance_to(projection)


func _is_point_in_triangle_2d(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var sign_ab = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var sign_bc = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var sign_ca = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	
	var has_neg = (sign_ab < 0) or (sign_bc < 0) or (sign_ca < 0)
	var has_pos = (sign_ab > 0) or (sign_bc > 0) or (sign_ca > 0)
	
	return not (has_neg and has_pos)


func _distance_to_triangle_2d(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	if _is_point_in_triangle_2d(p, a, b, c):
		return 0.0
	var d1 = _distance_to_segment_2d(p, a, b)
	var d2 = _distance_to_segment_2d(p, b, c)
	var d3 = _distance_to_segment_2d(p, c, a)
	return minf(d1, minf(d2, d3))


func _find_nodes_by_prefix(node: Node, prefix: String) -> Array:
	var result := []
	if node.name.begins_with(prefix):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes_by_prefix(child, prefix))
	return result


func _find_green_nodes(node: Node) -> Array:
	var result := []
	var n_lower = node.name.to_lower()
	if n_lower.begins_with("green_static") or (n_lower.contains("green") and node is StaticBody3D) or (node.has_meta("surface_type") and int(node.get_meta("surface_type")) == 4):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_green_nodes(child))
	return result


func _init_cached_surface_bodies(force: bool = false) -> void:
	if _cached_surface_nodes_initialized and not force:
		return
	_cached_surface_nodes_initialized = true
	_cached_green_bodies.clear()
	_cached_tee_bodies.clear()
	_cached_fairway_bodies.clear()
	
	var all_static_bodies: Array = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is StaticBody3D:
			all_static_bodies.append(n)
		for child in n.get_children():
			stack.append(child)
			
	for body in all_static_bodies:
		var n_lower: String = body.name.to_lower()
		var is_green = n_lower.begins_with("green_static") or n_lower.contains("green") or (body.has_meta("surface_type") and int(body.get_meta("surface_type")) == 4)
		var is_tee = n_lower.begins_with("tee_static") or n_lower.contains("tee")
		var is_fairway = n_lower.begins_with("fairway_static") or n_lower.contains("fairway")
		
		if not is_green and not is_tee and not is_fairway:
			continue
			
		var shapes_data: Array = []
		var triangles_2d: Array = []
		var min_x := 999999.0
		var max_x := -999999.0
		var min_z := 999999.0
		var max_z := -999999.0
		var trans: Transform3D = body.global_transform if body.is_inside_tree() else body.transform
		
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
				var shape_faces = child.shape.data
				if child.transform != Transform3D.IDENTITY:
					var transformed_faces = PackedVector3Array()
					transformed_faces.resize(shape_faces.size())
					for fi in range(shape_faces.size()):
						transformed_faces[fi] = child.transform * shape_faces[fi]
					shape_faces = transformed_faces
				shapes_data.append(shape_faces)
				for i in range(0, shape_faces.size(), 3):
					if i + 2 < shape_faces.size():
						var a_3d = trans * shape_faces[i]
						var b_3d = trans * shape_faces[i+1]
						var c_3d = trans * shape_faces[i+2]
						min_x = minf(min_x, minf(a_3d.x, minf(b_3d.x, c_3d.x)))
						max_x = maxf(max_x, maxf(a_3d.x, maxf(b_3d.x, c_3d.x)))
						min_z = minf(min_z, minf(a_3d.z, minf(b_3d.z, c_3d.z)))
						max_z = maxf(max_z, maxf(a_3d.z, maxf(b_3d.z, c_3d.z)))
						if is_fairway:
							var a2 = Vector2(a_3d.x, a_3d.z)
							var b2 = Vector2(b_3d.x, b_3d.z)
							var c2 = Vector2(c_3d.x, c_3d.z)
							var t_min_x = minf(a2.x, minf(b2.x, c2.x))
							var t_max_x = maxf(a2.x, maxf(b2.x, c2.x))
							var t_min_y = minf(a2.y, minf(b2.y, c2.y))
							var t_max_y = maxf(a2.y, maxf(b2.y, c2.y))
							triangles_2d.append({
								"a": a2,
								"b": b2,
								"c": c2,
								"rect": Rect2(t_min_x, t_min_y, t_max_x - t_min_x, t_max_y - t_min_y)
							})
			elif child is CollisionShape3D and child.shape is CylinderShape3D:
				var cyl_radius: float = child.shape.radius
				var center_pos: Vector3 = trans * child.position
				min_x = minf(min_x, center_pos.x - cyl_radius)
				max_x = maxf(max_x, center_pos.x + cyl_radius)
				min_z = minf(min_z, center_pos.z - cyl_radius)
				max_z = maxf(max_z, center_pos.z + cyl_radius)
				shapes_data.append(PackedVector3Array())
					
		if shapes_data.is_empty():
			continue
			
		var center_2d = Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
		var half_extent = Vector2((max_x - min_x) * 0.5, (max_z - min_z) * 0.5)
		var radius = half_extent.length()
		
		var entry = {
			"body": body,
			"transform": trans,
			"shapes": shapes_data,
			"triangles_2d": triangles_2d,
			"center_2d": center_2d,
			"radius": radius
		}
		if is_green:
			_cached_green_bodies.append(entry)
		if is_tee:
			_cached_tee_bodies.append(entry)
		if is_fairway:
			_cached_fairway_bodies.append(entry)


var _cached_dist_fairway_pos: Vector3 = Vector3.INF
var _cached_dist_fairway_res: float = 9999.0

func get_distance_to_nearest_fairway(pos: Vector3) -> float:
	if pos.is_equal_approx(_cached_dist_fairway_pos):
		return _cached_dist_fairway_res
	_cached_dist_fairway_pos = pos
	_cached_dist_fairway_res = _calc_distance_to_nearest_fairway(pos)
	return _cached_dist_fairway_res

func _calc_distance_to_nearest_fairway(pos: Vector3) -> float:
	_init_cached_surface_bodies()
	if _cached_fairway_bodies.is_empty():
		return 9999.0
	var pos_2d := Vector2(pos.x, pos.z)
	var min_dist := 9999.0
	for entry in _cached_fairway_bodies:
		var dist_to_center = pos_2d.distance_to(entry.center_2d)
		if dist_to_center - entry.radius >= min_dist:
			continue # Bounding circle early-out
			
		var trans: Transform3D = entry.transform
		for faces in entry.shapes:
			for i in range(0, faces.size(), 3):
				if i + 2 < faces.size():
					var a_3d = trans * faces[i]
					var b_3d = trans * faces[i+1]
					var c_3d = trans * faces[i+2]
					var a = Vector2(a_3d.x, a_3d.z)
					var b = Vector2(b_3d.x, b_3d.z)
					var c = Vector2(c_3d.x, c_3d.z)
					var dist = _distance_to_triangle_2d(pos_2d, a, b, c)
					if dist < min_dist:
						min_dist = dist
						if min_dist <= 0.001:
							return 0.0
	return min_dist


func is_point_in_fairway(pos_2d: Vector2) -> bool:
	_init_cached_surface_bodies()
	if _cached_fairway_bodies.is_empty():
		return false
	for entry in _cached_fairway_bodies:
		var dist_to_center = pos_2d.distance_to(entry.center_2d)
		if dist_to_center > entry.radius + 0.5:
			continue # Bounding circle early-out
			
		var tris: Array = entry.get("triangles_2d", [])
		if not tris.is_empty():
			for tri in tris:
				var rect: Rect2 = tri.rect
				if not rect.grow(0.5).has_point(pos_2d):
					continue
				if Geometry2D.point_is_inside_triangle(pos_2d, tri.a, tri.b, tri.c):
					return true
				if _distance_to_triangle_2d(pos_2d, tri.a, tri.b, tri.c) <= 0.5:
					return true
		else:
			var trans: Transform3D = entry.transform
			for faces in entry.shapes:
				for i in range(0, faces.size(), 3):
					if i + 2 < faces.size():
						var a_3d = trans * faces[i]
						var b_3d = trans * faces[i+1]
						var c_3d = trans * faces[i+2]
						var a = Vector2(a_3d.x, a_3d.z)
						var b = Vector2(b_3d.x, b_3d.z)
						var c = Vector2(c_3d.x, c_3d.z)
						if Geometry2D.point_is_inside_triangle(pos_2d, a, b, c):
							return true
						if _distance_to_triangle_2d(pos_2d, a, b, c) <= 0.5:
							return true
	return false


func _project_point_on_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var ap := p - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq == 0.0:
		return a
	var t := clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	return a + t * ab


func get_closest_point_on_nearest_fairway(pos: Vector3) -> Vector3:
	_init_cached_surface_bodies()
	var pos_2d := Vector2(pos.x, pos.z)
	var min_dist := INF
	var best_pt_2d := pos_2d
	var found_fairway := false

	if not _cached_fairway_bodies.is_empty():
		for entry in _cached_fairway_bodies:
			var dist_to_center = pos_2d.distance_to(entry.center_2d)
			if dist_to_center - entry.radius >= min_dist:
				continue # Bounding circle early-out

			var trans: Transform3D = entry.transform
			for faces in entry.shapes:
				for i in range(0, faces.size(), 3):
					if i + 2 < faces.size():
						var a_3d = trans * faces[i]
						var b_3d = trans * faces[i + 1]
						var c_3d = trans * faces[i + 2]
						var a = Vector2(a_3d.x, a_3d.z)
						var b = Vector2(b_3d.x, b_3d.z)
						var c = Vector2(c_3d.x, c_3d.z)

						if _is_point_in_triangle_2d(pos_2d, a, b, c):
							min_dist = 0.0
							best_pt_2d = pos_2d
							found_fairway = true
							break

						var proj_ab = _project_point_on_segment_2d(pos_2d, a, b)
						var d_ab = pos_2d.distance_to(proj_ab)
						if d_ab < min_dist:
							min_dist = d_ab
							best_pt_2d = proj_ab
							found_fairway = true

						var proj_bc = _project_point_on_segment_2d(pos_2d, b, c)
						var d_bc = pos_2d.distance_to(proj_bc)
						if d_bc < min_dist:
							min_dist = d_bc
							best_pt_2d = proj_bc
							found_fairway = true

						var proj_ca = _project_point_on_segment_2d(pos_2d, c, a)
						var d_ca = pos_2d.distance_to(proj_ca)
						if d_ca < min_dist:
							min_dist = d_ca
							best_pt_2d = proj_ca
							found_fairway = true
				if min_dist <= 0.001:
					break

	if not found_fairway:
		if is_driving_range:
			# Driving range fairway corridor centered at Z = 0, half_width = 26.0m, X >= -12.0
			var fx = maxf(pos.x, -12.0)
			var fz = clampf(pos.z, -26.0, 26.0)
			best_pt_2d = Vector2(fx, fz)
			found_fairway = true
		else:
			# Check hole path / centerline corridor
			var active_hole = get_active_hole_config() if has_method("get_active_hole_config") else {}
			var path_arr = active_hole.get("Hole Path", active_hole.get("HolePath", []))
			if typeof(path_arr) == TYPE_ARRAY and path_arr.size() >= 2:
				var poly: Array[Vector2] = []
				for pt in path_arr:
					poly.append(Vector2(float(pt[0]), float(pt[1])))
				var proj_res = _project_point_on_polyline(pos_2d, poly)
				best_pt_2d = proj_res.get("closest_point", pos_2d)
				found_fairway = true
			elif not current_hole_location.is_zero_approx():
				var pin_2d = Vector2(current_hole_location.x, current_hole_location.z)
				var tee_2d = Vector2.ZERO
				var tee_boxes = active_hole.get("Tee Boxes", {})
				if typeof(tee_boxes) == TYPE_DICTIONARY and not tee_boxes.is_empty():
					var def_key = "Blue" if "Blue" in tee_boxes else tee_boxes.keys()[0]
					var t_arr = tee_boxes[def_key]
					tee_2d = Vector2(float(t_arr[0]), float(t_arr[1]))
				elif has_node("Player") and $Player.get("ball") != null and not ($Player.ball.spawn_position as Vector3).is_zero_approx():
					tee_2d = Vector2($Player.ball.spawn_position.x, $Player.ball.spawn_position.z)

				if not tee_2d.is_zero_approx():
					best_pt_2d = _project_point_on_segment_2d(pos_2d, tee_2d, pin_2d)
				else:
					best_pt_2d = pin_2d
				found_fairway = true

	var ground_y = get_height(best_pt_2d.x, best_pt_2d.y)
	return Vector3(best_pt_2d.x, ground_y, best_pt_2d.y)


func _on_stuck_ball_requested() -> void:
	move_stuck_ball()


func move_stuck_ball(distance_yards: float = 2.0) -> bool:
	var player_node = get_node_or_null("Player")
	if player_node == null:
		return false
	var ball = player_node.get("ball")
	if ball == null:
		return false
	if "state" in ball and (ball.state == PhysicsEnums.BallState.FLIGHT or ball.state == PhysicsEnums.BallState.ROLLOUT):
		print("[range.gd] Cannot move stuck ball while ball is in motion.")
		return false

	var ball_pos: Vector3 = ball.global_position
	var ball_2d := Vector2(ball_pos.x, ball_pos.z)
	var fairway_pos: Vector3 = get_closest_point_on_nearest_fairway(ball_pos)
	var fairway_2d := Vector2(fairway_pos.x, fairway_pos.z)

	var move_dist_m: float = distance_yards * 0.9144 # 2 yards = 1.8288m
	var to_fairway := fairway_2d - ball_2d
	var dist_to_fairway := to_fairway.length()
	var new_pos_2d := ball_2d

	if dist_to_fairway > 0.001:
		var dir := to_fairway.normalized()
		new_pos_2d = ball_2d + dir * move_dist_m
	else:
		# Ball is already on fairway; move 2 yards towards aim target or hole
		var target_2d := Vector2.ZERO
		if not current_hole_location.is_zero_approx():
			target_2d = Vector2(current_hole_location.x, current_hole_location.z)
		elif aim_target_pos != null and not aim_target_pos.is_zero_approx():
			target_2d = Vector2(aim_target_pos.x, aim_target_pos.z)

		var dir := (target_2d - ball_2d).normalized() if not target_2d.is_zero_approx() and target_2d != ball_2d else Vector2(1.0, 0.0)
		new_pos_2d = ball_2d + dir * move_dist_m

	var ground_y := get_height(new_pos_2d.x, new_pos_2d.y)
	var new_pos := Vector3(new_pos_2d.x, ground_y + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET, new_pos_2d.y)

	ball.global_position = new_pos
	ball.spawn_position = new_pos
	if ball.has_method("ensure_tree_clearance"):
		ball.ensure_tree_clearance()
	if ball.has_method("ensure_rock_clearance"):
		ball.ensure_rock_clearance()
	new_pos = ball.global_position
	ball.spawn_position = new_pos
	ball.reset()
	if ball.has_method("_update_surface_from_underneath"):
		ball._update_surface_from_underneath()

	if practice_mode_active:
		practice_start_pos = new_pos

	# Update active player without incrementing strokes
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var active_player = mp_mgr.get_active_player()
		if not active_player.is_empty():
			active_player["position"] = new_pos
			active_player["last_starting_pos"] = new_pos
			active_player["lie_type"] = ball.lie_type

	if player_node != null:
		player_node.current_lie_type = ball.lie_type
		if player_node.get("_last_starting_pos") != null:
			player_node._last_starting_pos = new_pos
		if player_node.camera_target != null:
			player_node.camera_target.global_position = new_pos

	if has_node("PlayerMarker"):
		$PlayerMarker.global_position = new_pos

	update_current_lie_and_reduction()
	update_auto_club(true)

	if not current_hole_location.is_zero_approx():
		_update_hole_info_label(true)
		apply_default_aim()

	if has_node("MultiplayerController"):
		var mp_ctrl = get_node("MultiplayerController")
		if mp_ctrl != null and mp_ctrl.has_method("_update_distance_queue"):
			mp_ctrl.call("_update_distance_queue")

	if mp_mgr != null and mp_mgr.has_method("save_current_match"):
		mp_mgr.save_current_match()

	print("[range.gd] Stuck ball moved 2 yards closer to nearest fairway: %s -> %s (Strokes: %s)" % [
		ball_pos, new_pos,
		str(mp_mgr.get_active_player().get("strokes", 0)) if mp_mgr != null and not mp_mgr.players.is_empty() else "N/A"
	])
	return true


func _project_point_on_polyline(pt: Vector2, polyline: Array[Vector2]) -> Dictionary:
	if polyline.is_empty():
		return {"closest_point": pt, "progress": 0.0}
	if polyline.size() == 1:
		return {"closest_point": polyline[0], "progress": 0.0}
		
	var best_pt = polyline[0]
	var best_dist_sq = INF
	var best_progress = 0.0
	var current_accum = 0.0
	
	for i in range(polyline.size() - 1):
		var p1 = polyline[i]
		var p2 = polyline[i + 1]
		var seg = p2 - p1
		var seg_len = seg.length()
		if seg_len < 0.001:
			continue
		var t = clampf((pt - p1).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
		var proj = p1 + seg * t
		var d_sq = pt.distance_squared_to(proj)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_pt = proj
			best_progress = current_accum + seg_len * t
		current_accum += seg_len
		
	return {"closest_point": best_pt, "progress": best_progress}


func _get_point_on_polyline(polyline: Array[Vector2], target_dist: float) -> Vector2:
	if polyline.is_empty():
		return Vector2.ZERO
	if polyline.size() == 1 or target_dist <= 0.0:
		return polyline[0]
		
	var current_dist = 0.0
	for i in range(polyline.size() - 1):
		var p1 = polyline[i]
		var p2 = polyline[i + 1]
		var seg_len = p1.distance_to(p2)
		if current_dist + seg_len >= target_dist:
			var t = (target_dist - current_dist) / maxf(seg_len, 0.001)
			return p1.lerp(p2, clampf(t, 0.0, 1.0))
		current_dist += seg_len
		
	return polyline.back()


func _get_club_effective_distance_yards(club_name: String) -> float:
	var p_name = _get_current_player_name() if is_inside_tree() else ""
	var mp_mgr = get_node_or_null("/root/MultiplayerManager") if is_inside_tree() else null
	if mp_mgr != null and mp_mgr.has_method("get_club_effective_distance"):
		return float(mp_mgr.get_club_effective_distance(p_name, club_name))
	var default_dist = 140.0
	match club_name.to_lower():
		"dr", "driver", "1w": default_dist = 250.0
		"2w": default_dist = 235.0
		"3w": default_dist = 225.0
		"4w": default_dist = 215.0
		"5w": default_dist = 205.0
		"7w": default_dist = 190.0
		"2h": default_dist = 210.0
		"3h": default_dist = 200.0
		"4h": default_dist = 190.0
		"5h": default_dist = 180.0
		"1i": default_dist = 220.0
		"2i": default_dist = 210.0
		"3i": default_dist = 200.0
		"4i": default_dist = 190.0
		"5i": default_dist = 175.0
		"6i": default_dist = 160.0
		"7i": default_dist = 140.0
		"8i": default_dist = 130.0
		"9i": default_dist = 115.0
		"pw": default_dist = 100.0
		"gw", "aw": default_dist = 90.0
		"sw": default_dist = 80.0
		"lw": default_dist = 65.0
		"pt": default_dist = 10.0
	if mp_mgr != null and "DEFAULT_CLUB_DISTANCES" in mp_mgr:
		default_dist = float(mp_mgr.DEFAULT_CLUB_DISTANCES.get(club_name, default_dist))
	return default_dist


func _dist_to_segment_2d(pt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var l_sq = ab.length_squared()
	if l_sq < 0.0001:
		return pt.distance_to(a)
	var t = clampf((pt - a).dot(ab) / l_sq, 0.0, 1.0)
	var proj = a + ab * t
	return pt.distance_to(proj)


func _get_distance_to_hole_corridor(pt_2d: Vector2, h_data: Dictionary, ball_2d: Vector2 = Vector2.ZERO, hole_2d: Vector2 = Vector2.ZERO) -> float:
	var path_arr = h_data.get("Hole Path", h_data.get("HolePath", []))
	if typeof(path_arr) == TYPE_ARRAY and path_arr.size() >= 2:
		var min_d := INF
		for i in range(path_arr.size() - 1):
			var a = Vector2(float(path_arr[i][0]), float(path_arr[i][1]))
			var b = Vector2(float(path_arr[i+1][0]), float(path_arr[i+1][1]))
			var d = _dist_to_segment_2d(pt_2d, a, b)
			if d < min_d:
				min_d = d
		return min_d

	var pin_2d := Vector2.ZERO
	var h_loc = h_data.get("Hole Location")
	if h_loc != null and typeof(h_loc) == TYPE_ARRAY and h_loc.size() >= 2:
		pin_2d = Vector2(float(h_loc[0]), float(h_loc[1]))
	elif not hole_2d.is_zero_approx():
		pin_2d = hole_2d

	var tee_2d := Vector2.ZERO
	var tee_boxes = h_data.get("Tee Boxes", {})
	if typeof(tee_boxes) == TYPE_DICTIONARY and not tee_boxes.is_empty():
		var def_key = "Blue" if "Blue" in tee_boxes else tee_boxes.keys()[0]
		var t_arr = tee_boxes[def_key]
		tee_2d = Vector2(float(t_arr[0]), float(t_arr[1]))
	elif not ball_2d.is_zero_approx():
		tee_2d = ball_2d

	if not pin_2d.is_zero_approx() and not tee_2d.is_zero_approx():
		return _dist_to_segment_2d(pt_2d, tee_2d, pin_2d)
	elif not pin_2d.is_zero_approx():
		return pt_2d.distance_to(pin_2d)

	return INF


func _is_point_in_current_hole_corridor(pt_2d: Vector2, active_hole: Dictionary, all_holes: Dictionary, ball_2d: Vector2, hole_2d: Vector2) -> bool:
	var dist_cur = _get_distance_to_hole_corridor(pt_2d, active_hole, ball_2d, hole_2d)
	# Fairway corridor on any normal golf hole is within 45m of the hole path/centerline
	if dist_cur > 45.0:
		return false

	# If safely within the main fairway corridor (<= 18m), avoid scanning other holes
	if dist_cur <= 18.0:
		return true

	# If multiple holes exist, verify the candidate point is closer to the current hole than other holes
	if all_holes.size() > 1:
		for k in all_holes.keys():
			var other_h = all_holes[k]
			if other_h == active_hole:
				continue
			var dist_other = _get_distance_to_hole_corridor(pt_2d, other_h)
			# If closer to another hole's corridor (with a 5m buffer), it belongs to that other hole
			if dist_other < (dist_cur - 5.0):
				return false

	return true


func _find_fairway_midpoint_at_radius(ball_2d: Vector2, ref_dir: Vector2, radius_m: float, active_hole: Dictionary = {}, all_holes: Dictionary = {}, hole_2d: Vector2 = Vector2.ZERO) -> Vector2:
	_init_cached_surface_bodies()
	if _cached_fairway_bodies.is_empty():
		return Vector2.ZERO

	if active_hole.is_empty():
		active_hole = get_active_hole_config()
	if all_holes.is_empty():
		all_holes = get_all_holes_config()
	if hole_2d.is_zero_approx() and not current_hole_location.is_zero_approx():
		hole_2d = Vector2(current_hole_location.x, current_hole_location.z)

	var scan_max_deg := 35.0
	var step_deg := 2.5
	var inside_intervals: Array[Dictionary] = []
	var cur_start := -999.0
	var cur_end := -999.0

	var d = -scan_max_deg
	while d <= scan_max_deg + 0.01:
		var sample_dir = ref_dir.rotated(deg_to_rad(d))
		var pt_2d = ball_2d + sample_dir * radius_m
		var inside = is_point_in_fairway(pt_2d)
		if inside and not active_hole.is_empty():
			if not _is_point_in_current_hole_corridor(pt_2d, active_hole, all_holes, ball_2d, hole_2d):
				inside = false

		if inside:
			if cur_start < -900.0:
				cur_start = d
			cur_end = d
		else:
			if cur_start > -900.0:
				inside_intervals.append({"start": cur_start, "end": cur_end})
				cur_start = -999.0
				cur_end = -999.0
		d += step_deg

	if cur_start > -900.0:
		inside_intervals.append({"start": cur_start, "end": cur_end})

	if inside_intervals.is_empty():
		return Vector2.ZERO

	# Find the fairway interval whose center is closest to 0° (the reference line)
	var best_interval = inside_intervals[0]
	var best_center_dist = absf((best_interval["start"] + best_interval["end"]) * 0.5)
	for i in range(1, inside_intervals.size()):
		var interval = inside_intervals[i]
		var c_dist = absf((interval["start"] + interval["end"]) * 0.5)
		if c_dist < best_center_dist:
			best_center_dist = c_dist
			best_interval = interval

	var mid_deg = (best_interval["start"] + best_interval["end"]) * 0.5
	var final_dir = ref_dir.rotated(deg_to_rad(mid_deg))
	return ball_2d + final_dir * radius_m


var _cached_default_aim_ball_pos: Vector3 = Vector3.INF
var _cached_default_aim_targets: Dictionary = {}

func get_default_aim_target(ball_pos: Vector3, club_name: String = "") -> Vector3:
	if current_hole_location.is_zero_approx():
		return aim_target_pos

	# Putting practice, or ball is on green
	if is_ball_on_green():
		return current_hole_location

	# Resolve active club
	var active_club = club_name
	if active_club.is_empty():
		active_club = _get_current_club()
	if active_club.is_empty():
		var club_sel = get_club_selector()
		if club_sel != null and club_sel.has_method("get_current_club_name"):
			active_club = club_sel.get_current_club_name()

	if not ball_pos.is_equal_approx(_cached_default_aim_ball_pos):
		_cached_default_aim_ball_pos = ball_pos
		_cached_default_aim_targets.clear()
	elif _cached_default_aim_targets.has(active_club):
		return _cached_default_aim_targets[active_club]

	var target = _calc_default_aim_target(ball_pos, active_club)
	_cached_default_aim_targets[active_club] = target
	return target


func _calc_default_aim_target(ball_pos: Vector3, active_club: String) -> Vector3:
	var hole_dist_m = ball_pos.distance_to(current_hole_location)
	var hole_dist_yards = hole_dist_m * 1.09361

	# If still empty, determine what club would be suggested for the hole distance
	if active_club.is_empty():
		var is_in_teebox = false
		if has_node("Player") and $Player.ball != null:
			is_in_teebox = ($Player.ball.get("lie_type") == "teebox" or $Player.get("current_lie_type") == "teebox" or shot_count == 0)
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		var p_name = _get_current_player_name()
		if mp_mgr != null and mp_mgr.has_method("get_suggested_club"):
			active_club = mp_mgr.get_suggested_club(p_name, hole_dist_yards, is_in_teebox, false, is_ball_on_fringe())
		else:
			active_club = "Dr" if is_in_teebox and hole_dist_yards > 200 else "7i"

	var club_dist_yards = _get_club_effective_distance_yards(active_club)

	# Rule 1: If the selected club can reach or exceed the hole distance, aim directly at the hole
	if club_dist_yards >= (hole_dist_yards - 0.5):
		return current_hole_location

	# Rule 2: If the ball is within approach range of the green (or using a wedge / short approach club),
	# always maintain direct aim toward the green/pin rather than scanning for a fairway corridor off-axis.
	var is_wedge = active_club.to_lower() in ["pw", "gw", "aw", "sw", "lw", "pt"]
	var is_approach_range = hole_dist_yards <= 140.0
	if is_approach_range or (is_wedge and hole_dist_yards <= 220.0):
		return current_hole_location

	# Rule 3: Otherwise, aim at the middle of the current hole's fairway at the distance the selected club can go
	var target_dist_m = club_dist_yards / 1.09361
	if target_dist_m >= hole_dist_m:
		return current_hole_location

	var ball_2d = Vector2(ball_pos.x, ball_pos.z)
	var hole_2d = Vector2(current_hole_location.x, current_hole_location.z)
	var to_hole_dir = (hole_2d - ball_2d).normalized()
	if to_hole_dir.is_zero_approx():
		to_hole_dir = Vector2.RIGHT

	# Check for Hole Path corridor
	var active_hole = get_active_hole_config()
	var all_holes = get_all_holes_config()
	var path_arr = active_hole.get("Hole Path", active_hole.get("HolePath", []))
	var path_pts: Array[Vector2] = []
	var path_target_2d = Vector2.ZERO
	var has_path := false
	if typeof(path_arr) == TYPE_ARRAY and path_arr.size() >= 2:
		for pt in path_arr:
			path_pts.append(Vector2(float(pt[0]), float(pt[1])))
		var proj_info = _project_point_on_polyline(ball_2d, path_pts)
		path_target_2d = _get_point_on_polyline(path_pts, proj_info["progress"] + target_dist_m)
		has_path = true

	var ref_dir = to_hole_dir
	if has_path:
		var dir_along_path = (path_target_2d - ball_2d).normalized()
		if not dir_along_path.is_zero_approx() and dir_along_path.dot(to_hole_dir) > 0.2:
			ref_dir = dir_along_path

	# Scan fairway collision mesh around ref_dir to find fairway middle at radius target_dist_m
	var scan_fairway_mid = _find_fairway_midpoint_at_radius(ball_2d, ref_dir, target_dist_m, active_hole, all_holes, hole_2d)
	if scan_fairway_mid != Vector2.ZERO:
		var fairway_dir = (scan_fairway_mid - ball_2d).normalized()
		if fairway_dir.dot(to_hole_dir) > 0.2:
			return Vector3(scan_fairway_mid.x, get_height(scan_fairway_mid.x, scan_fairway_mid.y), scan_fairway_mid.y)

	# Fallback 1: Hole Path point
	if has_path and not path_target_2d.is_zero_approx():
		var fallback_dir = (path_target_2d - ball_2d).normalized()
		if not fallback_dir.is_zero_approx() and fallback_dir.dot(to_hole_dir) > 0.2:
			var fallback_2d = ball_2d + fallback_dir * target_dist_m
			return Vector3(fallback_2d.x, get_height(fallback_2d.x, fallback_2d.y), fallback_2d.y)

	# Fallback 2: Straight toward hole at target_dist_m
	var direct_2d = ball_2d + to_hole_dir * target_dist_m
	return Vector3(direct_2d.x, get_height(direct_2d.x, direct_2d.y), direct_2d.y)


func apply_default_aim(club_name: String = "") -> Vector3:
	if not has_node("Player") or $Player.ball == null:
		return aim_target_pos
	if current_hole_location.is_zero_approx():
		return aim_target_pos

	var ball_pos = $Player.ball.global_position
	var target_pos = get_default_aim_target(ball_pos, club_name)

	# Safety check: ensure default aim never points backward away from the hole
	var hole_diff: Vector3 = current_hole_location - ball_pos
	var to_hole_2d: Vector2 = Vector2(hole_diff.x, hole_diff.z).normalized()
	var target_diff: Vector3 = target_pos - ball_pos
	var to_target_2d: Vector2 = Vector2(target_diff.x, target_diff.z).normalized()
	if to_target_2d.dot(to_hole_2d) < 0.1:
		var safe_dist_m: float = target_diff.length()
		if safe_dist_m < 5.0 or safe_dist_m > hole_diff.length():
			safe_dist_m = minf(hole_diff.length(), 150.0)
		var safe_target_2d: Vector2 = Vector2(ball_pos.x, ball_pos.z) + to_hole_2d * safe_dist_m
		target_pos = Vector3(safe_target_2d.x, get_height(safe_target_2d.x, safe_target_2d.y), safe_target_2d.y)

	aim_target_pos = target_pos
	update_dof_focus()
	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos

	var diff = aim_target_pos - ball_pos
	var angle_rad = atan2(diff.z, diff.x)
	$Player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)

	var dist_m = ball_pos.distance_to(aim_target_pos)
	var dist_yards = int(dist_m * 1.09361)
	set_aim_distance(dist_yards)

	var yaw_rad = -angle_rad
	var cam_pos = get_address_camera_position(ball_pos, yaw_rad, null, is_actively_aiming())
	var target_look = get_camera_target_look(aim_target_pos, ball_pos)

	if has_node("PhantomCamera3D"):
		$PhantomCamera3D.follow_mode = PhantomCamera3D.FollowMode.NONE
		$PhantomCamera3D.look_at_mode = PhantomCamera3D.LookAtMode.NONE
		$PhantomCamera3D.global_position = cam_pos
		$PhantomCamera3D.look_at(target_look)
		if $PhantomCamera3D.camera_3d_resource != null:
			$PhantomCamera3D.camera_3d_resource.fov = GlobalSettings.range_settings.camera_fov.value
	if has_node("Camera3D"):
		$Camera3D.global_position = cam_pos
		$Camera3D.look_at(target_look)
		$Camera3D.fov = GlobalSettings.range_settings.camera_fov.value

	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_ready_for_shot()

	_aim_is_manual = false
	return aim_target_pos


var _cached_dist_nearest_green_pos: Vector3 = Vector3.INF
var _cached_dist_nearest_green_res: float = 9999.0

func get_distance_to_nearest_green(pos: Vector3) -> float:
	if pos.is_equal_approx(_cached_dist_nearest_green_pos):
		return _cached_dist_nearest_green_res
	_cached_dist_nearest_green_pos = pos
	_cached_dist_nearest_green_res = _calc_distance_to_nearest_green(pos)
	return _cached_dist_nearest_green_res

func _calc_distance_to_nearest_green(pos: Vector3) -> float:
	_init_cached_surface_bodies()
	if _cached_green_bodies.is_empty():
		return 9999.0
	var pos_2d := Vector2(pos.x, pos.z)
	
	# Fast early-out if current hole pin is defined and ball is far away
	if not current_hole_location.is_zero_approx():
		var dist_to_pin = pos.distance_to(current_hole_location)
		if dist_to_pin > 60.0:
			return dist_to_pin - 25.0
			
	var min_dist := 9999.0
	for entry in _cached_green_bodies:
		var dist_to_center = pos_2d.distance_to(entry.center_2d)
		if dist_to_center - entry.radius >= min_dist:
			continue # Bounding circle early-out
			
		var trans: Transform3D = entry.transform
		for faces in entry.shapes:
			for i in range(0, faces.size(), 3):
				if i + 2 < faces.size():
					var a_3d = trans * faces[i]
					var b_3d = trans * faces[i+1]
					var c_3d = trans * faces[i+2]
					var a = Vector2(a_3d.x, a_3d.z)
					var b = Vector2(b_3d.x, b_3d.z)
					var c = Vector2(c_3d.x, c_3d.z)
					var dist = _distance_to_triangle_2d(pos_2d, a, b, c)
					if dist < min_dist:
						min_dist = dist
						if min_dist <= 0.001:
							return 0.0
	return min_dist


func get_current_green_entry() -> Dictionary:
	_init_cached_surface_bodies()
	if _cached_green_bodies.is_empty():
		return {}
	var pin_pos = current_hole_location
	if pin_pos.is_zero_approx():
		pin_pos = aim_target_pos
	if pin_pos.is_zero_approx():
		return {}
	if pin_pos == _cached_current_green_pin and not _cached_current_green_entry.is_empty():
		return _cached_current_green_entry
		
	var pin_2d = Vector2(pin_pos.x, pin_pos.z)
	var best_entry: Dictionary = {}
	var min_dist: float = 999999.0
	
	for entry in _cached_green_bodies:
		var dist_to_center: float = pin_2d.distance_to(entry.center_2d)
		var d: float = maxf(0.0, dist_to_center - entry.radius)
		if d < min_dist:
			var trans: Transform3D = entry.transform
			var actual_min: float = 999999.0
			for faces in entry.shapes:
				for i in range(0, faces.size(), 3):
					if i + 2 < faces.size():
						var a_3d = trans * faces[i]
						var b_3d = trans * faces[i+1]
						var c_3d = trans * faces[i+2]
						var a = Vector2(a_3d.x, a_3d.z)
						var b = Vector2(b_3d.x, b_3d.z)
						var c = Vector2(c_3d.x, c_3d.z)
						var tri_d = _distance_to_triangle_2d(pin_2d, a, b, c)
						if tri_d < actual_min:
							actual_min = tri_d
							if actual_min <= 0.001:
								break
				if actual_min <= 0.001:
					break
			if actual_min < min_dist:
				min_dist = actual_min
				best_entry = entry
				if min_dist <= 0.001:
					break
					
	_cached_current_green_pin = pin_pos
	_cached_current_green_entry = best_entry
	return best_entry


var _cached_dist_current_green_pos: Vector3 = Vector3.INF
var _cached_dist_current_green_pin: Vector3 = Vector3.INF
var _cached_dist_current_green_res: float = 9999.0

func get_distance_to_current_green(pos: Vector3) -> float:
	var pin = current_hole_location
	if pos.is_equal_approx(_cached_dist_current_green_pos) and pin.is_equal_approx(_cached_dist_current_green_pin):
		return _cached_dist_current_green_res
	_cached_dist_current_green_pos = pos
	_cached_dist_current_green_pin = pin
	_cached_dist_current_green_res = _calc_distance_to_current_green(pos)
	return _cached_dist_current_green_res

func _calc_distance_to_current_green(pos: Vector3) -> float:
	var entry = get_current_green_entry()
	if entry.is_empty():
		if not current_hole_location.is_zero_approx():
			var dist_pin = pos.distance_to(current_hole_location)
			return maxf(0.0, dist_pin - 15.0)
		return 9999.0
		
	var pos_2d := Vector2(pos.x, pos.z)
	var dist_to_center = pos_2d.distance_to(entry.center_2d)
	if dist_to_center - entry.radius > 50.0:
		return dist_to_center - entry.radius
		
	var trans: Transform3D = entry.transform
	var min_dist := 9999.0
	for faces in entry.shapes:
		for i in range(0, faces.size(), 3):
			if i + 2 < faces.size():
				var a_3d = trans * faces[i]
				var b_3d = trans * faces[i+1]
				var c_3d = trans * faces[i+2]
				var a = Vector2(a_3d.x, a_3d.z)
				var b = Vector2(b_3d.x, b_3d.z)
				var c = Vector2(c_3d.x, c_3d.z)
				var dist = _distance_to_triangle_2d(pos_2d, a, b, c)
				if dist < min_dist:
					min_dist = dist
					if min_dist <= 0.001:
						return 0.0
	return min_dist


var _cached_dist_any_green_pos: Vector3 = Vector3.INF
var _cached_dist_any_green_res: float = 9999.0

func get_distance_to_any_green(pos: Vector3) -> float:
	if pos.is_equal_approx(_cached_dist_any_green_pos):
		return _cached_dist_any_green_res
	_cached_dist_any_green_pos = pos
	_cached_dist_any_green_res = _calc_distance_to_any_green(pos)
	return _cached_dist_any_green_res

func _calc_distance_to_any_green(pos: Vector3) -> float:
	_init_cached_surface_bodies()
	if _cached_green_bodies.is_empty():
		return 9999.0
	var pos_2d := Vector2(pos.x, pos.z)
	var min_dist := 9999.0
	for entry in _cached_green_bodies:
		var dist_to_center = pos_2d.distance_to(entry.center_2d)
		if dist_to_center - entry.radius >= min_dist:
			continue
			
		var trans: Transform3D = entry.transform
		for faces in entry.shapes:
			for i in range(0, faces.size(), 3):
				if i + 2 < faces.size():
					var a_3d = trans * faces[i]
					var b_3d = trans * faces[i+1]
					var c_3d = trans * faces[i+2]
					var a = Vector2(a_3d.x, a_3d.z)
					var b = Vector2(b_3d.x, b_3d.z)
					var c = Vector2(c_3d.x, c_3d.z)
					var dist = _distance_to_triangle_2d(pos_2d, a, b, c)
					if dist < min_dist:
						min_dist = dist
						if min_dist <= 0.001:
							return 0.0
	return min_dist


var _cached_wrong_green_pos: Vector3 = Vector3.INF
var _cached_wrong_green_pin: Vector3 = Vector3.INF
var _cached_wrong_green_result: bool = false

func is_ball_on_wrong_green(override_pos: Vector3 = Vector3.ZERO) -> bool:
	if is_driving_range:
		return false
	var pin_pos = current_hole_location
	if pin_pos.is_zero_approx():
		pin_pos = aim_target_pos
	if pin_pos.is_zero_approx():
		return false
		
	var pos = override_pos
	if pos.is_zero_approx():
		if has_node("Player") and $Player.ball != null:
			pos = $Player.ball.global_position
		else:
			return false

	if pos.is_equal_approx(_cached_wrong_green_pos) and pin_pos.is_equal_approx(_cached_wrong_green_pin):
		return _cached_wrong_green_result

	_cached_wrong_green_pos = pos
	_cached_wrong_green_pin = pin_pos
	_cached_wrong_green_result = _calc_is_ball_on_wrong_green(pos, pin_pos)
	return _cached_wrong_green_result

func _calc_is_ball_on_wrong_green(pos: Vector3, pin_pos: Vector3) -> bool:
	var d_curr = get_distance_to_current_green(pos)
	if d_curr <= 2.5:
		return false
		
	var d_any = get_distance_to_any_green(pos)
	if d_any <= 2.5:
		return true
		
	if has_node("Player") and $Player.ball != null:
		var ball = $Player.ball
		if ball.global_position.distance_to(pos) <= 1.0:
			var l = str(ball.get("lie_type")).to_lower()
			if l == "green" or l == "fringe":
				return true
			if ball.has_method("get_surface") and int(ball.get_surface()) == PhysicsEnums.SurfaceType.GREEN:
				return true
				
	var mp_mgr = get_node_or_null("/root/MultiplayerManager") if is_inside_tree() else null
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var ap = mp_mgr.get_active_player()
		var l = str(ap.get("lie_type", "")).to_lower()
		if (l == "green" or l == "fringe") and pos.distance_to(pin_pos) > 40.0:
			return true
			
	return false


var _cached_dist_teebox_pos: Vector3 = Vector3.INF
var _cached_dist_teebox_res: float = 9999.0

func get_distance_to_nearest_teebox(pos: Vector3) -> float:
	if pos.is_equal_approx(_cached_dist_teebox_pos):
		return _cached_dist_teebox_res
	_cached_dist_teebox_pos = pos
	_cached_dist_teebox_res = _calc_distance_to_nearest_teebox(pos)
	return _cached_dist_teebox_res

func _calc_distance_to_nearest_teebox(pos: Vector3) -> float:
	_init_cached_surface_bodies()
	if _cached_tee_bodies.is_empty():
		return 9999.0
	var pos_2d := Vector2(pos.x, pos.z)
	var min_dist := 9999.0
	for entry in _cached_tee_bodies:
		var dist_to_center = pos_2d.distance_to(entry.center_2d)
		if dist_to_center - entry.radius >= min_dist:
			continue # Bounding circle early-out
			
		var trans: Transform3D = entry.transform
		for faces in entry.shapes:
			for i in range(0, faces.size(), 3):
				if i + 2 < faces.size():
					var a_3d = trans * faces[i]
					var b_3d = trans * faces[i+1]
					var c_3d = trans * faces[i+2]
					var a = Vector2(a_3d.x, a_3d.z)
					var b = Vector2(b_3d.x, b_3d.z)
					var c = Vector2(c_3d.x, c_3d.z)
					var dist = _distance_to_triangle_2d(pos_2d, a, b, c)
					if dist < min_dist:
						min_dist = dist
						if min_dist <= 0.001:
							return 0.0
	return min_dist


func update_current_lie_and_reduction() -> void:
	var ball_node = $Player.ball if has_node("Player") else null
	if ball_node == null:
		return
		
	# Force update of ball's surface detection at its current position
	ball_node._update_surface_from_underneath()
	
	var lie_type = ball_node.get("lie_type")
	if lie_type == null:
		lie_type = "fairway"
	var reduction = 0.0
	
	if is_driving_range:
		lie_type = "teebox"
		reduction = 0.0
		ball_node.lie_type = "teebox"
		ball_node.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
	else:
		if is_ball_on_wrong_green():
			lie_type = "fairway"
			reduction = 0.0
			ball_node.lie_type = "fairway"
			ball_node.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		else:
			# Geometric check fallbacks to ensure absolute accuracy for teeboxes, fairways and greens
			if lie_type != "green" and lie_type != "sand":
				# Check if we are actually on a green (strictly inside green triangles)
				if get_distance_to_nearest_green(ball_node.global_position) <= 0.001:
					lie_type = "green"
					ball_node.lie_type = "green"
					ball_node.set_surface(PhysicsEnums.SurfaceType.GREEN)
				# Check if we are on the fringe / collar bordering the green (within 2.5 meters of green edge)
				elif get_distance_to_nearest_green(ball_node.global_position) <= 2.5:
					lie_type = "fringe"
					ball_node.lie_type = "fringe"
					ball_node.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
				# Check if we are on a tee box (first shot on hole only, or practice mode)
				var tee_allowed: bool = practice_mode_active
				if not tee_allowed:
					var mp_mgr_tee = get_node_or_null("/root/MultiplayerManager")
					if mp_mgr_tee != null and not mp_mgr_tee.players.is_empty():
						var ap_tee = mp_mgr_tee.get_active_player()
						tee_allowed = (ap_tee != null and int(ap_tee.get("strokes", 0)) == 0)
					else:
						tee_allowed = (shot_count == 0)

				if tee_allowed or ball_node.lie_type == "teebox" or get_distance_to_nearest_teebox(ball_node.global_position) <= 2.5 or (practice_start_pos != Vector3.ZERO and ball_node.global_position.distance_to(practice_start_pos) < 2.5):
					if tee_allowed:
						lie_type = "teebox"
						ball_node.lie_type = "teebox"
						ball_node.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
					else:
						# Subsequent shots landing or resting in a tee box are treated as fairway turf, never teed up
						lie_type = "fairway"
						ball_node.lie_type = "fairway"
						ball_node.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
				# Check if we are actually on a fairway (strictly inside fairway triangles)
				elif get_distance_to_nearest_fairway(ball_node.global_position) <= 0.001:
					lie_type = "fairway"
					ball_node.lie_type = "fairway"
					ball_node.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)

		if lie_type == "green" or lie_type == "fairway" or lie_type == "fringe":
			reduction = 0.0
		elif lie_type == "teebox":
			reduction = 0.0
		elif lie_type == "rough":
			var d_fairway = get_distance_to_nearest_fairway(ball_node.global_position)
			var d_green = get_distance_to_nearest_green(ball_node.global_position)
			var d = minf(d_fairway, d_green)
			# rough penalty is 10-30% based on how far away from fairway/green (up to 50 meters)
			reduction = 0.10 + 0.20 * clampf(d / 50.0, 0.0, 1.0)
		elif lie_type == "sand":
			# sand penalty is 20-40% based on relative apex height (up to 30 meters)
			var shot_height = max(0.0, $Player.apex - $Player._last_starting_pos.y)
			reduction = 0.20 + 0.20 * clampf(shot_height / 30.0, 0.0, 1.0)

	# Update ball tee elevation and tee peg visibility
	if ball_node != null and ball_node.has_method("_update_tee_elevation"):
		ball_node._update_tee_elevation()
			
	# Save it
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var active_player = mp_mgr.get_active_player()
		active_player["lie_type"] = lie_type
		active_player["shot_reduction"] = reduction
		print("[range.gd] Multiplayer Active. Storing lie penalty for player %s: %s (%.1f%%)" % [active_player["name"], lie_type, reduction * 100.0])
	else:
		print("[range.gd] Single Player Active. Storing lie penalty: %s (%.1f%%)" % [lie_type, reduction * 100.0])

	if has_node("Player"):
		$Player.current_shot_reduction = reduction
		$Player.current_lie_type = lie_type
		
	# Update UI
	_update_aim_distance_label_text()
		
	# If in course play, update HUD
	var mp_ctrl = get_node_or_null("MultiplayerController")
	var parent = get_parent()
	var active_p = mp_mgr.get_active_player() if (mp_mgr != null and not mp_mgr.players.is_empty()) else {}
	if not active_p.is_empty():
		if mp_ctrl != null and mp_ctrl.has_method("_update_top_hud"):
			mp_ctrl.call("_update_top_hud", active_p)
		elif parent != null and parent.has_method("_update_top_hud"):
			parent.call("_update_top_hud", active_p)
		elif parent != null and parent.has_method("_on_active_player_changed"):
			parent.call("_on_active_player_changed", active_p)


func get_aim_elevation_difference() -> float:
	var ball_node = $Player.ball if has_node("Player") else null
	var ball_y := 0.0
	if ball_node != null:
		ball_y = ball_node.global_position.y
	elif practice_start_pos != Vector3.ZERO:
		ball_y = practice_start_pos.y
	else:
		return 0.0

	var target_y := aim_target_pos.y
	if is_zero_approx(target_y) and (abs(aim_target_pos.x) > 0.001 or abs(aim_target_pos.z) > 0.001):
		if not _was_keyboard_aiming and not _was_screen_aiming:
			target_y = get_height(aim_target_pos.x, aim_target_pos.z)

	return target_y - ball_y


func set_aim_distance(dist_yards: float) -> void:
	var elev_diff = get_aim_elevation_difference()
	if abs(current_aim_distance_yards - dist_yards) < 0.05 and abs(current_aim_elevation_diff_m - elev_diff) < 0.1:
		return
	current_aim_distance_yards = dist_yards
	current_aim_elevation_diff_m = elev_diff
	_update_aim_distance_label_text()


func _update_aim_distance_label_text() -> void:
	if not has_node("MapCanvas/AimDistanceLabel"):
		return
		
	var label = $MapCanvas/AimDistanceLabel

	# Determine if ball is on green / putting
	var on_green = is_ball_on_green()
	if not on_green and has_node("Player") and $Player.ball != null:
		var ball_lie = str($Player.ball.get("lie_type")).to_lower()
		var p_lie = str($Player.get("current_lie_type")).to_lower()
		if ball_lie == "green" or p_lie == "green":
			on_green = true
	if not on_green and has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if not mp.players.is_empty():
			var ap = mp.get_active_player()
			if ap.get("lie_type", "").to_lower() == "green":
				on_green = true

	var dist_m = 0.0
	var has_valid_dist = false
	if has_node("Player") and $Player.ball != null and not aim_target_pos.is_zero_approx():
		dist_m = $Player.ball.global_position.distance_to(aim_target_pos)
		has_valid_dist = true

	var is_imperial := true
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null and gs.range_settings.get("range_units") != null:
			is_imperial = (gs.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL)

	var base_text := ""
	if on_green:
		var dist_ft = int(round(dist_m * 3.28084)) if has_valid_dist else int(round(current_aim_distance_yards * 3.0))
		base_text = "🎯 Aim %d Feet" % dist_ft
	else:
		if is_imperial:
			var dist_yds = int(round(dist_m * 1.09361)) if has_valid_dist else int(round(current_aim_distance_yards))
			base_text = "🎯 Aim %d Yards" % dist_yds
		else:
			var dist_meters = int(round(dist_m)) if has_valid_dist else int(round(current_aim_distance_yards * 0.9144))
			base_text = "🎯 Aim %d Meters" % dist_meters
	
	var elev_diff_m = current_aim_elevation_diff_m
	
	var elev_text := ""
	if is_imperial:
		var elev_ft = elev_diff_m * 3.28084
		var elev_int = int(round(elev_ft))
		if elev_int == 0:
			elev_text = "⛰️ Elevation 0 Feet"
		elif elev_int > 0:
			elev_text = "⛰️ Elevation ▲ %d Feet" % elev_int
		else:
			elev_text = "⛰️ Elevation ▼ %d Feet" % abs(elev_int)
	else:
		var elev_m_rounded = snappedf(elev_diff_m, 0.1)
		if abs(elev_m_rounded) < 0.05:
			elev_text = "⛰️ Elevation 0.0 Meters"
		elif elev_m_rounded > 0.0:
			elev_text = "⛰️ Elevation ▲ %.1f Meters" % elev_m_rounded
		else:
			elev_text = "⛰️ Elevation ▼ %.1f Meters" % abs(elev_m_rounded)

	# Get the active player's reduction/lie or single player's
	var reduction = 0.0
	var lie_type = "fairway"
	
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var active_player = mp_mgr.get_active_player()
		reduction = active_player.get("shot_reduction", 0.0)
		lie_type = active_player.get("lie_type", "fairway")
	else:
		if has_node("Player"):
			reduction = $Player.current_shot_reduction
			lie_type = $Player.current_lie_type
			
	var emoji := "🟢"
	var name_str := "Fairway"
	match lie_type:
		"green":
			emoji = "⛳"
			name_str = "Green"
		"fringe":
			emoji = "🌱"
			name_str = "Fringe"
		"fairway":
			emoji = "🟢"
			name_str = "Fairway"
		"teebox":
			emoji = "🏌️"
			name_str = "Tee Box"
		"rough":
			emoji = "🌿"
			name_str = "Rough"
		"sand":
			emoji = "🏖️"
			name_str = "Sand"
			
	var lie_text := ""
	if reduction > 0.0:
		lie_text = "%s %s (-%d%%)" % [emoji, name_str, int(reduction * 100.0)]
	else:
		lie_text = "%s %s (0%%)" % [emoji, name_str]

	var wind_text := ""
	var plain_wind_text := ""
	var is_wind := false
	var gs = null
	if is_inside_tree() and get_tree().root.has_node("GlobalSettings"):
		gs = get_tree().root.get_node("GlobalSettings")
	elif GlobalSettings != null:
		gs = GlobalSettings

	if gs != null and gs.is_wind_enabled():
		is_wind = true
		var ball_pos := Vector3.ZERO
		if has_node("Player") and $Player.ball != null:
			ball_pos = $Player.ball.global_position if $Player.ball.is_inside_tree() else $Player.ball.position
		elif has_node("Player"):
			ball_pos = $Player.global_position if $Player.is_inside_tree() else $Player.position
		var fallback_fwd := Vector3.RIGHT
		if has_node("Player") and $Player.ball != null and $Player.ball.has_method("get_target_dir"):
			fallback_fwd = $Player.ball.get_target_dir()
		var wind_info: Dictionary = gs.get_relative_wind_arrow_and_angle(ball_pos, aim_target_pos, fallback_fwd)
		var arrow_symbol: String = wind_info.get("arrow", "↑")
		var spd_val: int = int(round(wind_info.get("speed_mph", 0.0)))
		
		if label is RichTextLabel or label.get("bbcode_enabled") == true:
			wind_text = "💨 [b][outline_size=2][outline_color=#f5faff]%s[/outline_color][/outline_size][/b] Wind %d MPH" % [arrow_symbol, spd_val]
		else:
			wind_text = "💨 %s Wind %d MPH" % [arrow_symbol, spd_val]
		plain_wind_text = "💨 %s Wind %d MPH" % [arrow_symbol, spd_val]

	var plain_full_text := ""
	if is_wind and not wind_text.is_empty():
		label.text = "[center]%s | %s | %s | %s[/center]" % [base_text, elev_text, lie_text, wind_text] if (label is RichTextLabel or label.get("bbcode_enabled") == true) else "%s | %s | %s | %s" % [base_text, elev_text, lie_text, wind_text]
		plain_full_text = "%s | %s | %s | %s" % [base_text, elev_text, lie_text, plain_wind_text]
	else:
		label.text = "[center]%s | %s | %s[/center]" % [base_text, elev_text, lie_text] if (label is RichTextLabel or label.get("bbcode_enabled") == true) else "%s | %s | %s" % [base_text, elev_text, lie_text]
		plain_full_text = "%s | %s | %s" % [base_text, elev_text, lie_text]

	var font: Font = label.get_theme_font("font")
	var font_sz: int = label.get_theme_font_size("normal_font_size") if label is RichTextLabel else label.get_theme_font_size("font_size")
	if font_sz <= 0:
		font_sz = 18
	var text_w: float = 0.0
	if font != null:
		text_w = font.get_string_size(plain_full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
	if text_w <= 0.0:
		text_w = label.get_minimum_size().x
	if text_w <= 0.0:
		text_w = plain_full_text.length() * 9.5

	var half_w: float = ceil((text_w / 2.0) + 18.0)
	half_w = maxf(half_w, 240.0)
	label.offset_left = -half_w
	label.offset_right = half_w
	if has_node("MapCanvas/AimDistanceBadge"):
		$MapCanvas/AimDistanceBadge.offset_left = -half_w
		$MapCanvas/AimDistanceBadge.offset_right = half_w
	if _weather_lighting_controller != null and is_instance_valid(_weather_lighting_controller):
		_weather_lighting_controller.update_bar_width(half_w)


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
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3
	style_focus.border_color = Color(0.2, 0.8, 1.0, 0.95)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_focus)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 24)


func get_current_green_vertices() -> PackedVector3Array:
	var pin_pos = current_hole_location
	if pin_pos.is_zero_approx():
		pin_pos = aim_target_pos
	if pin_pos.is_zero_approx():
		return PackedVector3Array()
		
	var tris_3d = _get_green_triangles_3d(pin_pos)
	var global_verts = PackedVector3Array()
	for tri in tris_3d:
		global_verts.append(tri[0])
		global_verts.append(tri[1])
		global_verts.append(tri[2])
	return global_verts


func is_ball_in_teebox() -> bool:
	if has_node("Player") and $Player.ball != null:
		var ball = $Player.ball
		var lie = str(ball.get("lie_type")).to_lower()
		var p_lie = str($Player.get("current_lie_type")).to_lower()
		if lie == "teebox" or p_lie == "teebox":
			return true
		if is_driving_range:
			var dist_to_spawn = ball.global_position.distance_to(ball.spawn_position)
			if dist_to_spawn < 1.5:
				return true
		if has_method("get_distance_to_nearest_teebox"):
			var d_tee = get_distance_to_nearest_teebox(ball.global_position)
			if d_tee <= 0.001:
				return true
		if not practice_mode_active:
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				var active_p = mp_mgr.get_active_player()
				if not active_p.is_empty() and active_p.get("strokes", 0) == 0:
					return true
			elif "shot_count" in self and shot_count == 0:
				return true
	return false


func is_ball_close_to_green() -> bool:
	if is_ball_on_green() or is_ball_on_fringe():
		return true
	if has_node("Player") and $Player.ball != null:
		var ball = $Player.ball
		var lie = str(ball.get("lie_type")).to_lower()
		var p_lie = str($Player.get("current_lie_type")).to_lower()
		if lie == "green" or p_lie == "green" or lie == "fringe" or p_lie == "fringe":
			return true
		var target_pos = current_hole_location
		if target_pos.is_zero_approx() and aim_target_pos != null:
			target_pos = aim_target_pos
		if not target_pos.is_zero_approx():
			var dist_to_hole = ball.global_position.distance_to(target_pos)
			if dist_to_hole <= 45.0: # ~50 yards
				return true
			if dist_to_hole > 75.0:
				return false
		if has_method("get_distance_to_nearest_green"):
			var d_green = get_distance_to_nearest_green(ball.global_position)
			if d_green <= 30.0:
				return true
	return false


func get_current_zoom_zone() -> int:
	if is_ball_in_teebox():
		return 0 # TEE_BOX
	elif is_ball_close_to_green():
		return 2 # GREEN
	else:
		return 1 # MIDWAY


func get_zoom_for_zone(zone: int) -> float:
	var green_zoom = get_green_zoom_size()
	var tee_zoom = _teebox_aerial_zoom
	match zone:
		0: # TEE_BOX
			return tee_zoom
		1: # MIDWAY (half way between tee box zoom and green zoom)
			return (tee_zoom + green_zoom) * 0.5
		2: # GREEN
			return green_zoom
		_:
			return tee_zoom


func get_green_zoom_size() -> float:
	return 50.0


func reset_zoom_to_default() -> void:
	aerial_zoom = 300.0
	_teebox_aerial_zoom = 300.0
	_default_non_green_aerial_zoom = 300.0
	_last_zoom_zone = -1
	_last_was_on_green = false
	aerial_cam_user_offset = Vector3.ZERO
	if has_node("AerialCamera"):
		$AerialCamera.size = aerial_zoom
	show_green_grid = false


func _on_hole_completed(_scores: Array = []) -> void:
	reset_zoom_to_default()
	_user_custom_club = ""


# ==========================================
# GREEN SLOPE GRID & ELEVATION HEATMAP LOGIC
# ==========================================

func _get_green_triangles_3d(pin_pos: Vector3) -> Array:
	_init_cached_surface_bodies()
	if _cached_green_bodies.is_empty():
		_cached_surface_nodes_initialized = false
		_init_cached_surface_bodies()
		
	var pin_2d := Vector2(pin_pos.x, pin_pos.z)
	var primary_entry = null
	var min_dist := INF
	
	for entry in _cached_green_bodies:
		var d = pin_2d.distance_to(entry.center_2d)
		if d - entry.radius > 60.0:
			continue
			
		var trans: Transform3D = entry.transform
		var inside_tri = false
		for shape_faces in entry.shapes:
			for i in range(0, shape_faces.size(), 3):
				if i + 2 < shape_faces.size():
					var a_3d: Vector3 = trans * shape_faces[i]
					var b_3d: Vector3 = trans * shape_faces[i+1]
					var c_3d: Vector3 = trans * shape_faces[i+2]
					var a := Vector2(a_3d.x, a_3d.z)
					var b := Vector2(b_3d.x, b_3d.z)
					var c := Vector2(c_3d.x, c_3d.z)
					if _is_point_in_triangle_2d(pin_2d, a, b, c):
						inside_tri = true
						break
			if inside_tri:
				break
				
		if inside_tri:
			primary_entry = entry
			min_dist = 0.0
			break
		elif d < min_dist:
			min_dist = d
			primary_entry = entry

	var matching_entries: Array = []
	if primary_entry != null:
		matching_entries.append(primary_entry)
		for entry in _cached_green_bodies:
			if entry == primary_entry:
				continue
			var d = pin_2d.distance_to(entry.center_2d)
			var dist_to_primary = entry.center_2d.distance_to(primary_entry.center_2d)
			# Aggregate any green parts that belong to this green (within 45m of pin or contiguous with primary entry)
			if d <= 45.0 or (d - entry.radius) <= 25.0 or dist_to_primary <= (primary_entry.radius + entry.radius + 5.0):
				matching_entries.append(entry)
	elif not _cached_green_bodies.is_empty():
		for entry in _cached_green_bodies:
			var d = pin_2d.distance_to(entry.center_2d)
			if d <= 45.0 or (d - entry.radius) <= 25.0:
				matching_entries.append(entry)

	var triangles: Array = []
	for entry in matching_entries:
		# Check for CylinderShape3D (island greens)
		if entry.has("body") and entry.body != null:
			for child in entry.body.find_children("*", "CollisionShape3D"):
				if child is CollisionShape3D and child.shape is CylinderShape3D:
					var cyl_radius: float = child.shape.radius
					var center_3d: Vector3 = entry.body.global_position
					var steps = 48
					for s in range(steps):
						var a1 = s * TAU / steps
						var a2 = (s + 1) * TAU / steps
						var p1 = center_3d + Vector3(cos(a1) * cyl_radius, 0.0, sin(a1) * cyl_radius)
						var p2 = center_3d + Vector3(cos(a2) * cyl_radius, 0.0, sin(a2) * cyl_radius)
						triangles.append([center_3d, p1, p2])

		if entry.has("shapes") and not entry.shapes.is_empty():
			var trans: Transform3D = entry.transform
			for shape_faces in entry.shapes:
				for i in range(0, shape_faces.size(), 3):
					if i + 2 < shape_faces.size():
						var a_3d: Vector3 = trans * shape_faces[i]
						var b_3d: Vector3 = trans * shape_faces[i+1]
						var c_3d: Vector3 = trans * shape_faces[i+2]
						triangles.append([a_3d, b_3d, c_3d])

	if not triangles.is_empty():
		return triangles

	# Fallback search across scene tree for all green bodies within proximity of pin
	var all_greens = _find_green_nodes(self)
	for node in all_greens:
		if node is StaticBody3D:
			var dist = node.global_position.distance_to(pin_pos)
			if dist <= 50.0:
				for child in node.get_children():
					if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
						var verts = child.shape.data
						for i in range(0, verts.size(), 3):
							if i + 2 < verts.size():
								var v0: Vector3 = node.global_transform * verts[i]
								var v1: Vector3 = node.global_transform * verts[i+1]
								var v2: Vector3 = node.global_transform * verts[i+2]
								triangles.append([v0, v1, v2])
					elif child is MeshInstance3D and child.mesh != null:
						var faces = child.mesh.get_faces()
						for i in range(0, faces.size(), 3):
							if i + 2 < faces.size():
								var v0: Vector3 = node.global_transform * child.transform * faces[i]
								var v1: Vector3 = node.global_transform * child.transform * faces[i+1]
								var v2: Vector3 = node.global_transform * child.transform * faces[i+2]
								triangles.append([v0, v1, v2])
	return triangles


func _get_green_triangles(pin_pos: Vector3) -> Array:
	var tris_3d = _get_green_triangles_3d(pin_pos)
	var triangles = []
	for tri in tris_3d:
		triangles.append([
			Vector2(tri[0].x, tri[0].z),
			Vector2(tri[1].x, tri[1].z),
			Vector2(tri[2].x, tri[2].z)
		])
	return triangles


func _is_point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	
	const EPS = 0.001
	var has_neg = (d1 < -EPS) or (d2 < -EPS) or (d3 < -EPS)
	var has_pos = (d1 > EPS) or (d2 > EPS) or (d3 > EPS)
	
	return not (has_neg and has_pos)


func _get_heatmap_color(t: float) -> Color:
	var color: Color
	if t < 0.25:
		color = Color.BLUE.lerp(Color.CYAN, t / 0.25)
	elif t < 0.5:
		color = Color.CYAN.lerp(Color.GREEN, (t - 0.25) / 0.25)
	elif t < 0.75:
		color = Color.GREEN.lerp(Color.YELLOW, (t - 0.5) / 0.25)
	else:
		color = Color.YELLOW.lerp(Color.RED, (t - 0.75) / 0.25)
	color.a = 0.55
	return color


func _create_arrow_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_w = 0.028
	var half_l = 0.036
	var h = 0.001
	
	var t_tip = Vector3(0.0, h, half_l)
	var t_left = Vector3(-half_w, h, -half_l)
	var t_right = Vector3(half_w, h, -half_l)
	
	var b_tip = Vector3(0.0, -h, half_l)
	var b_left = Vector3(-half_w, -h, -half_l)
	var b_right = Vector3(half_w, -h, -half_l)
	
	# Top face
	st.add_vertex(t_tip)
	st.add_vertex(t_left)
	st.add_vertex(t_right)
	
	# Bottom face
	st.add_vertex(b_tip)
	st.add_vertex(b_right)
	st.add_vertex(b_left)
	
	# Left side
	st.add_vertex(t_tip)
	st.add_vertex(b_tip)
	st.add_vertex(b_left)
	st.add_vertex(t_tip)
	st.add_vertex(b_left)
	st.add_vertex(t_left)
	
	# Right side
	st.add_vertex(t_tip)
	st.add_vertex(t_right)
	st.add_vertex(b_right)
	st.add_vertex(t_tip)
	st.add_vertex(b_right)
	st.add_vertex(b_tip)
	
	# Back side
	st.add_vertex(t_left)
	st.add_vertex(b_left)
	st.add_vertex(b_right)
	st.add_vertex(t_left)
	st.add_vertex(b_right)
	st.add_vertex(t_right)
	
	st.generate_normals()
	return st.commit()


func _get_arrow_color(_slope_len: float) -> Color:
	return Color.WHITE


func _is_player_near_green() -> bool:
	return is_ball_close_to_green()


func _update_green_grid_visibility() -> void:
	var heatmap_node = get_node_or_null("GreenHeatmapMesh")
	var grid_node = get_node_or_null("GreenGridMesh")
	var dots_node = get_node_or_null("GreenDotsMesh")
	
	if heatmap_node == null:
		return
		
	if not show_green_grid:
		heatmap_node.visible = false
		if grid_node: grid_node.visible = false
		if dots_node: dots_node.visible = false
		return
		
	# GreenHeatmapMesh is assigned to visual layer 2.
	# The 3D player camera has layer 2 culled (cull_mask & ~2), so the 3D ground camera
	# never renders the heatmap. AerialCamera and MinimapCamera include layer 2,
	# so they render the heatmap.
	heatmap_node.visible = true
	
	# GreenGridMesh and GreenDotsMesh are assigned to visual layer 3 (bit 4).
	# They are only visible in ground putting view, NEVER in aerial or minimap view.
	var is_near = _is_player_near_green()
	var ground_putting_active = is_near and not is_aerial_view
	if grid_node:
		grid_node.layers = 4
		grid_node.visible = ground_putting_active
	if dots_node:
		dots_node.layers = 4
		dots_node.visible = ground_putting_active



func _generate_green_grid_and_heatmap() -> void:
	for name in ["GreenHeatmapMesh", "GreenGridMesh", "GreenDotsMesh"]:
		var node = get_node_or_null(name)
		if node:
			remove_child(node)
			node.queue_free()
			
	var pin_pos = current_hole_location
	if pin_pos.is_zero_approx():
		pin_pos = aim_target_pos
	if pin_pos.is_zero_approx():
		return
		
	var tris_3d = _get_green_triangles_3d(pin_pos)
	if tris_3d.is_empty():
		return
		
	var triangles = []
	for tri in tris_3d:
		triangles.append([
			Vector2(tri[0].x, tri[0].z),
			Vector2(tri[1].x, tri[1].z),
			Vector2(tri[2].x, tri[2].z)
		])
		
	var min_y = 999999.0
	var max_y = -999999.0
	for tri in tris_3d:
		for v in tri:
			if v.y < min_y: min_y = v.y
			if v.y > max_y: max_y = v.y
	var verts = get_current_green_vertices()
	for v in verts:
		if v.y < min_y: min_y = v.y
		if v.y > max_y: max_y = v.y
		
	if max_y - min_y < 0.001:
		max_y = min_y + 1.0
		
	var heatmap_y_offset = 0.005
	var grid_y_offset = 0.008
	var dot_y_offset = 0.010
	
	# Height cache for optimization
	var height_cache = {}
	var get_cached_height = func(gx: float, gz: float) -> float:
		var key = Vector2(gx, gz)
		if not height_cache.has(key):
			height_cache[key] = get_height(gx, gz)
		return height_cache[key]

	# --- 1. GENERATE SMOOTH GREEN HEATMAP MESH ---
	# Subdivide green geometry so the elevation heatmap perfectly conforms to the true
	# green boundary and surface curvature without gaps, holes, or jagged block steps.
	var final_heatmap_tris: Array = []
	var tri_queue: Array = []
	for tri in tris_3d:
		tri_queue.append({"tri": tri, "depth": 0})
		
	var max_edge_len: float = 0.75 # Subdivide edges > 0.75m for ultra-smooth slope gradient
	var max_depth: int = 5
	
	while not tri_queue.is_empty():
		var item = tri_queue.pop_back()
		var tri = item.tri
		var depth: int = item.depth
		
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		
		var d_ab: float = a.distance_squared_to(b)
		var d_bc: float = b.distance_squared_to(c)
		var d_ca: float = c.distance_squared_to(a)
		var max_d_sq: float = maxf(d_ab, maxf(d_bc, d_ca))
		
		if max_d_sq > (max_edge_len * max_edge_len) and depth < max_depth:
			if d_ab >= d_bc and d_ab >= d_ca:
				var mid = (a + b) * 0.5
				tri_queue.append({"tri": [a, mid, c], "depth": depth + 1})
				tri_queue.append({"tri": [mid, b, c], "depth": depth + 1})
			elif d_bc >= d_ab and d_bc >= d_ca:
				var mid = (b + c) * 0.5
				tri_queue.append({"tri": [a, b, mid], "depth": depth + 1})
				tri_queue.append({"tri": [a, mid, c], "depth": depth + 1})
			else:
				var mid = (c + a) * 0.5
				tri_queue.append({"tri": [a, b, mid], "depth": depth + 1})
				tri_queue.append({"tri": [mid, b, c], "depth": depth + 1})
		else:
			final_heatmap_tris.append([a, b, c])
			
	var st_heatmap = SurfaceTool.new()
	st_heatmap.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for tri in final_heatmap_tris:
		var v0: Vector3 = tri[0]
		var v1: Vector3 = tri[1]
		var v2: Vector3 = tri[2]
		
		var col0 = _get_heatmap_color(clamp((v0.y - min_y) / (max_y - min_y), 0.0, 1.0))
		var col1 = _get_heatmap_color(clamp((v1.y - min_y) / (max_y - min_y), 0.0, 1.0))
		var col2 = _get_heatmap_color(clamp((v2.y - min_y) / (max_y - min_y), 0.0, 1.0))
		
		var h0 = Vector3(v0.x, maxf(v0.y, get_cached_height.call(v0.x, v0.z)) + heatmap_y_offset, v0.z)
		var h1 = Vector3(v1.x, maxf(v1.y, get_cached_height.call(v1.x, v1.z)) + heatmap_y_offset, v1.z)
		var h2 = Vector3(v2.x, maxf(v2.y, get_cached_height.call(v2.x, v2.z)) + heatmap_y_offset, v2.z)
		
		st_heatmap.set_color(col0)
		st_heatmap.add_vertex(h0)
		st_heatmap.set_color(col1)
		st_heatmap.add_vertex(h1)
		st_heatmap.set_color(col2)
		st_heatmap.add_vertex(h2)
		
	var heatmap_mesh = st_heatmap.commit()
	var heatmap_mi = MeshInstance3D.new()
	heatmap_mi.name = "GreenHeatmapMesh"
	heatmap_mi.mesh = heatmap_mesh
	var mat_hm = StandardMaterial3D.new()
	mat_hm.vertex_color_use_as_albedo = true
	mat_hm.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_hm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat_hm.no_depth_test = true
	mat_hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_hm.render_priority = 1
	heatmap_mi.material_override = mat_hm
	heatmap_mi.layers = 2
	heatmap_mi.visible = false
	add_child(heatmap_mi)

	# --- 2. GENERATE PUTTING SLOPE GRID & MOVING ARROWS ---
	var spacing = 1.0
	var active_cells = {}
	
	for tri in triangles:
		var tx_min = min(tri[0].x, min(tri[1].x, tri[2].x))
		var tx_max = max(tri[0].x, max(tri[1].x, tri[2].x))
		var tz_min = min(tri[0].y, min(tri[1].y, tri[2].y))
		var tz_max = max(tri[0].y, max(tri[1].y, tri[2].y))
		
		var ix_start = int(floor(tx_min / spacing))
		var ix_end = int(ceil(tx_max / spacing))
		var iz_start = int(floor(tz_min / spacing))
		var iz_end = int(ceil(tz_max / spacing))
		
		for ix in range(ix_start, ix_end + 1):
			for iz in range(iz_start, iz_end + 1):
				var cell_center = Vector2((ix + 0.5) * spacing, (iz + 0.5) * spacing)
				if _is_point_in_triangle(cell_center, tri[0], tri[1], tri[2]):
					active_cells[Vector2i(ix, iz)] = true
				elif not active_cells.has(Vector2i(ix, iz)):
					var c_min_x = ix * spacing
					var c_max_x = (ix + 1) * spacing
					var c_min_z = iz * spacing
					var c_max_z = (iz + 1) * spacing
					for v in tri:
						if v.x >= c_min_x and v.x <= c_max_x and v.y >= c_min_z and v.y <= c_max_z:
							active_cells[Vector2i(ix, iz)] = true
							break

	# Fill any isolated 1-cell gaps inside active_cells to keep the grid contiguous
	var cells_to_fill = []
	for cell in active_cells.keys():
		for n in [Vector2i(cell.x + 1, cell.y), Vector2i(cell.x - 1, cell.y), Vector2i(cell.x, cell.y + 1), Vector2i(cell.x, cell.y - 1)]:
			if not active_cells.has(n) and not cells_to_fill.has(n):
				var count = 0
				if active_cells.has(Vector2i(n.x + 1, n.y)): count += 1
				if active_cells.has(Vector2i(n.x - 1, n.y)): count += 1
				if active_cells.has(Vector2i(n.x, n.y + 1)): count += 1
				if active_cells.has(Vector2i(n.x, n.y - 1)): count += 1
				if count >= 3:
					cells_to_fill.append(n)
	for c in cells_to_fill:
		active_cells[c] = true

	if active_cells.is_empty():
		return

	var st_grid = SurfaceTool.new()
	st_grid.begin(Mesh.PRIMITIVE_LINES)
		
	# Collect unique horizontal and vertical edges to generate slope flow arrows
	var h_edges = {}
	var v_edges = {}
	for cell in active_cells.keys():
		var ix = cell.x
		var iz = cell.y
		h_edges[Vector2i(ix, iz)] = true
		h_edges[Vector2i(ix, iz + 1)] = true
		v_edges[Vector2i(ix, iz)] = true
		v_edges[Vector2i(ix + 1, iz)] = true

	# Subdivide grid lines so they tightly conform to green terrain curvature instead of floating
	var edge_subdiv = 4
	for edge in h_edges.keys():
		var x_start = edge.x * spacing
		var z_val = edge.y * spacing
		var prev_pt = Vector3(x_start, get_cached_height.call(x_start, z_val) + grid_y_offset, z_val)
		for s in range(1, edge_subdiv + 1):
			var cur_x = x_start + (float(s) / float(edge_subdiv)) * spacing
			var cur_pt = Vector3(cur_x, get_cached_height.call(cur_x, z_val) + grid_y_offset, z_val)
			st_grid.add_vertex(prev_pt)
			st_grid.add_vertex(cur_pt)
			prev_pt = cur_pt

	for edge in v_edges.keys():
		var x_val = edge.x * spacing
		var z_start = edge.y * spacing
		var prev_pt = Vector3(x_val, get_cached_height.call(x_val, z_start) + grid_y_offset, z_start)
		for s in range(1, edge_subdiv + 1):
			var cur_z = z_start + (float(s) / float(edge_subdiv)) * spacing
			var cur_pt = Vector3(x_val, get_cached_height.call(x_val, cur_z) + grid_y_offset, cur_z)
			st_grid.add_vertex(prev_pt)
			st_grid.add_vertex(cur_pt)
			prev_pt = cur_pt
		
	var dots_data = [] # Array of dictionaries: {start: Vector3, displacement: Vector3, slope: float}
	
	# Horizontal edges
	for edge in h_edges.keys():
		var x0 = edge.x * spacing
		var z0 = edge.y * spacing
		var x1 = (edge.x + 1) * spacing
		var z1 = edge.y * spacing
		
		var y0 = get_cached_height.call(x0, z0)
		var y1 = get_cached_height.call(x1, z1)
		
		var slope = abs(y0 - y1)
		if slope > 0.0005:
			var start_pos: Vector3
			var end_pos: Vector3
			if y0 > y1:
				start_pos = Vector3(x0, y0 + dot_y_offset, z0)
				end_pos = Vector3(x1, y1 + dot_y_offset, z1)
			else:
				start_pos = Vector3(x1, y1 + dot_y_offset, z1)
				end_pos = Vector3(x0, y0 + dot_y_offset, z0)
				
			var dots_per_segment = 2
			for j in range(dots_per_segment):
				dots_data.append({
					"start": start_pos,
					"displacement": end_pos - start_pos,
					"slope": slope,
					"phase_offset": float(j) / float(dots_per_segment)
				})
			
	# Vertical edges
	for edge in v_edges.keys():
		var x0 = edge.x * spacing
		var z0 = edge.y * spacing
		var x1 = edge.x * spacing
		var z1 = (edge.y + 1) * spacing
		
		var y0 = get_cached_height.call(x0, z0)
		var y1 = get_cached_height.call(x1, z1)
		
		var slope = abs(y0 - y1)
		if slope > 0.0005:
			var start_pos: Vector3
			var end_pos: Vector3
			if y0 > y1:
				start_pos = Vector3(x0, y0 + dot_y_offset, z0)
				end_pos = Vector3(x1, y1 + dot_y_offset, z1)
			else:
				start_pos = Vector3(x1, y1 + dot_y_offset, z1)
				end_pos = Vector3(x0, y0 + dot_y_offset, z0)
				
			var dots_per_segment = 2
			for j in range(dots_per_segment):
				dots_data.append({
					"start": start_pos,
					"displacement": end_pos - start_pos,
					"slope": slope,
					"phase_offset": float(j) / float(dots_per_segment)
				})
			
	var grid_mesh = st_grid.commit()
	
	var grid_mi = MeshInstance3D.new()
	grid_mi.name = "GreenGridMesh"
	grid_mi.mesh = grid_mesh
	var mat_g = StandardMaterial3D.new()
	mat_g.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	mat_g.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_g.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat_g.render_priority = 1
	grid_mi.material_override = mat_g
	grid_mi.layers = 4
	grid_mi.visible = false
	add_child(grid_mi)
	
	# Instantiate MultiMesh for moving slope arrows
	var dots_mi = MultiMeshInstance3D.new()
	dots_mi.name = "GreenDotsMesh"
	
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.instance_count = dots_data.size()
	multimesh.mesh = _create_arrow_mesh()
	
	for i in range(dots_data.size()):
		var data = dots_data[i]
		var disp = data.displacement
		var fwd = disp.normalized()
		var up = Vector3.UP
		if abs(fwd.dot(up)) > 0.95:
			up = Vector3.FORWARD
		var right = up.cross(fwd).normalized()
		up = fwd.cross(right).normalized()
		var basis = Basis(right, up, fwd)
		var tx = Transform3D(basis, data.start)
		multimesh.set_instance_transform(i, tx)
		
		var custom = Color(disp.x, disp.y, disp.z, data.slope)
		multimesh.set_instance_custom_data(i, custom)
		multimesh.set_instance_color(i, Color(data.phase_offset, 0.0, 0.0, 1.0))
		
	dots_mi.multimesh = multimesh
	
	# Create custom spatial shader for arrows
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float time_scale = 1.0;

varying vec4 v_color;

void vertex() {
	vec3 displacement = INSTANCE_CUSTOM.xyz;
	float slope_val = INSTANCE_CUSTOM.w;
	
	float phase_offset = COLOR.r;
	float segment_phase = float(INSTANCE_ID / 2) * 0.25;
	
	// Speed scales with slope gradient to represent acceleration/speed added to the ball in that direction
	// Nearly flat areas hardly move at all, while steep sections move faster up to a capped maximum
	float move_speed = clamp(slope_val * 11.0, 0.0, 0.75);
	float progress = fract(TIME * move_speed * time_scale + phase_offset + segment_phase);
	
	// Translate vertex in world space along the displacement vector (using transpose for orthonormal model matrix)
	vec3 world_offset = displacement * progress;
	vec3 local_offset = transpose(mat3(MODEL_MATRIX)) * world_offset;
	VERTEX += local_offset;
	
	// Smooth fade-in / fade-out along the segment
	float fade = sin(progress * 3.14159265);
	
	// White arrows with smooth segment edge fading
	v_color = vec4(vec3(1.0), fade * 0.95);
}

void fragment() {
	ALBEDO = v_color.rgb;
	ALPHA = v_color.a;
}
"""
	
	var mat_dots = ShaderMaterial.new()
	mat_dots.shader = shader
	mat_dots.render_priority = 2
	dots_mi.material_override = mat_dots
	dots_mi.layers = 4
	dots_mi.visible = false
	add_child(dots_mi)
	
	_update_green_grid_visibility()


func _exit_tree() -> void:
	if has_node("/root/ScreenOffsetManager"):
		if has_node("PhantomCamera3D"):
			ScreenOffsetManager.unregister_camera($PhantomCamera3D)
		ScreenOffsetManager.set_putter_active(false)
	if GlobalSettings.is_chipping_minigame:
		GlobalSettings.is_chipping_minigame = false


func _setup_chipping_minigame() -> void:
	chipping_stats = {}
	chipping_island_positions = []
	chipping_islands = []
	for i in range(chipping_distances.size()):
		chipping_stats[i] = {"Attempts": 0, "Hits": 0}
		
	var hole_info_data = course_data_dict.get("Hole Info", {})
	var hole_data = hole_info_data.get("Hole 17", {})
	if hole_data.is_empty():
		push_error("[Chipping] Hole 17 info not found in course data!")
		return
		
	var tee_coord = hole_data.get("Tee Boxes", {}).get("Blue", [52.162712, 31.829489])
	var pin_coord = hole_data.get("Hole Location", [73.96878, 131.19373])
	
	var tee_pos = Vector3(tee_coord[0], get_height(tee_coord[0], tee_coord[1]), tee_coord[1])
	var pin_pos = Vector3(pin_coord[0], get_height(pin_coord[0], pin_coord[1]), pin_coord[1])
	
	var dir = (pin_pos - tee_pos)
	var dir_norm = dir.normalized()
	var perp = Vector3(-dir_norm.z, 0, dir_norm.x).normalized()
	var green_radius = 3.81
	
	for i in range(chipping_distances.size()):
		var dist_meters = chipping_distances[i] * 0.3048
		var lat_offset_meters = chipping_lateral_offsets[i] * 0.3048
		
		var base_pos = tee_pos + dir_norm * dist_meters
		var island_pos = base_pos + perp * lat_offset_meters
		
		var terrain_h = get_height(island_pos.x, island_pos.z)
		island_pos.y = terrain_h + 0.25
		chipping_island_positions.append(island_pos)
		
		var island = StaticBody3D.new()
		island.name = "ChippingGreenIsland_%d" % i
		island.set_meta("surface_type", 4)
		add_child(island)
		island.global_position = island_pos
		chipping_islands.append(island)
		
		var col_shape = CollisionShape3D.new()
		var cyl_shape = CylinderShape3D.new()
		cyl_shape.radius = green_radius
		cyl_shape.height = 1.0
		col_shape.shape = cyl_shape
		island.add_child(col_shape)
		
		var base_mesh_inst = MeshInstance3D.new()
		var base_mesh = CylinderMesh.new()
		base_mesh.top_radius = green_radius + 0.1
		base_mesh.bottom_radius = green_radius + 0.1
		base_mesh.height = 1.0
		base_mesh_inst.mesh = base_mesh
		
		var base_mat = StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.35, 0.25, 0.15)
		base_mat.roughness = 0.9
		base_mesh_inst.material_override = base_mat
		base_mesh_inst.position = Vector3(0.0, -0.4, 0.0)
		island.add_child(base_mesh_inst)
		
		var turf_mesh_inst = MeshInstance3D.new()
		var turf_mesh = CylinderMesh.new()
		turf_mesh.top_radius = green_radius
		turf_mesh.bottom_radius = green_radius
		turf_mesh.height = 0.08
		turf_mesh_inst.mesh = turf_mesh
		
		var turf_mat = StandardMaterial3D.new()
		turf_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		turf_mat.roughness = 0.95
		turf_mesh_inst.material_override = turf_mat
		turf_mesh_inst.position = Vector3(0.0, 0.1, 0.0)
		island.add_child(turf_mesh_inst)
		
		var flag_node = Node3D.new()
		flag_node.name = "Flag_%d" % i
		island.add_child(flag_node)
		flag_node.position = Vector3(0.0, 0.1, 0.0)
		
		var q_str = ""
		var gs = GlobalSettings if GlobalSettings != null else (get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null)
		if gs != null and gs.has_method("get_graphics_quality"):
			q_str = gs.get_graphics_quality()
		FlagBuilder.setup_target_flag(flag_node, 1.8, Color(0.85, 0.65, 0.0), 0.38, 0.26, false, q_str)
		
		var label_node = Label3D.new()
		label_node.text = "%d FT" % chipping_distances[i]
		label_node.font_size = 36
		label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_node.outline_size = 8
		label_node.modulate = Color.WHITE
		label_node.position = Vector3(0.0, 2.2, 0.0)
		flag_node.add_child(label_node)
		
	_select_chipping_target(selected_chipping_target_idx)
	_setup_chipping_hud_ui()


func _select_chipping_target(index: int) -> void:
	selected_chipping_target_idx = index
	for i in range(chipping_islands.size()):
		var island_node = chipping_islands[i]
		if island_node:
			var old_ring = island_node.get_node_or_null("TargetRing")
			if old_ring:
				old_ring.queue_free()
				
			if i == index:
				var ring = MeshInstance3D.new()
				ring.name = "TargetRing"
				var ring_mesh = CylinderMesh.new()
				ring_mesh.top_radius = 3.81
				ring_mesh.bottom_radius = 3.81
				ring_mesh.height = 0.01
				ring.mesh = ring_mesh
				
				var ring_mat = StandardMaterial3D.new()
				ring_mat.albedo_color = Color(0.0, 0.8, 1.0, 0.6)
				ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ring.material_override = ring_mat
				ring.position = Vector3(0.0, 0.15, 0.0)
				island_node.add_child(ring)
				
	var target_pos = chipping_island_positions[index]
	aim_target_pos = target_pos
	if has_node("AimMarker"):
		$AimMarker.global_position = aim_target_pos
		
	if has_node("Player") and $Player.ball != null:
		var diff = aim_target_pos - $Player.ball.spawn_position
		var angle_rad = atan2(diff.z, diff.x)
		$Player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)
		
		var yaw_rad = -angle_rad
		var cam_pos = get_address_camera_position($Player.ball.spawn_position, yaw_rad, false)
		var target_look = get_camera_target_look(aim_target_pos, $Player.ball.spawn_position, false)
		if has_node("PhantomCamera3D"):
			$PhantomCamera3D.global_position = cam_pos
			$PhantomCamera3D.look_at(target_look)
		if has_node("Camera3D"):
			$Camera3D.global_position = cam_pos
			$Camera3D.look_at(target_look)
			
	_update_chipping_hud()
	_show_chipping_banner("Target Island: %d Feet Selected" % chipping_distances[index])


func _setup_chipping_hud_ui() -> void:
	if chipping_hud != null:
		chipping_hud.queue_free()
		chipping_hud = null
		
	chipping_hud = CanvasLayer.new()
	chipping_hud.name = "ChippingHUDLayer"
	chipping_hud.layer = 20
	add_child(chipping_hud)
	
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	chipping_hud.add_child(control)
	
	var glass_style = StyleBoxFlat.new()
	glass_style.bg_color = Color(0.04, 0.08, 0.12, 0.85)
	glass_style.border_width_left = 2
	glass_style.border_width_top = 2
	glass_style.border_width_right = 2
	glass_style.border_width_bottom = 2
	glass_style.border_color = Color(0.24, 0.46, 0.72, 0.5)
	glass_style.corner_radius_top_left = 10
	glass_style.corner_radius_top_right = 10
	glass_style.corner_radius_bottom_right = 10
	glass_style.corner_radius_bottom_left = 10
	
	var score_panel = PanelContainer.new()
	score_panel.custom_minimum_size = Vector2(700, 90)
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.anchor_top = 0.0
	score_panel.anchor_bottom = 0.0
	score_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	score_panel.offset_left = -350
	score_panel.offset_right = 350
	score_panel.offset_top = 20
	score_panel.offset_bottom = 110
	control.add_child(score_panel)
	score_panel.add_theme_stylebox_override("panel", glass_style)
	
	var score_margin = MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 20)
	score_margin.add_theme_constant_override("margin_right", 20)
	score_panel.add_child(score_margin)
	
	var score_hbox = HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_margin.add_child(score_hbox)
	
	var target_col = VBoxContainer.new()
	target_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(target_col)
	var t_lbl = Label.new()
	t_lbl.text = "ACTIVE TARGET"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	target_col.add_child(t_lbl)
	chipping_target_lbl = Label.new()
	chipping_target_lbl.text = "100 FT"
	chipping_target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipping_target_lbl.add_theme_font_size_override("font_size", 28)
	chipping_target_lbl.add_theme_color_override("font_color", Color.WHITE)
	target_col.add_child(chipping_target_lbl)
	
	var attempts_col = VBoxContainer.new()
	attempts_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attempts_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(attempts_col)
	var att_lbl = Label.new()
	att_lbl.text = "ATTEMPTS"
	att_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	att_lbl.add_theme_font_size_override("font_size", 14)
	att_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	attempts_col.add_child(att_lbl)
	chipping_attempts_lbl = Label.new()
	chipping_attempts_lbl.text = "0"
	chipping_attempts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipping_attempts_lbl.add_theme_font_size_override("font_size", 28)
	chipping_attempts_lbl.add_theme_color_override("font_color", Color.WHITE)
	attempts_col.add_child(chipping_attempts_lbl)
	
	var hits_col = VBoxContainer.new()
	hits_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hits_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(hits_col)
	var h_lbl = Label.new()
	h_lbl.text = "HITS"
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_lbl.add_theme_font_size_override("font_size", 14)
	h_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	hits_col.add_child(h_lbl)
	chipping_hits_lbl = Label.new()
	chipping_hits_lbl.text = "0"
	chipping_hits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipping_hits_lbl.add_theme_font_size_override("font_size", 28)
	chipping_hits_lbl.add_theme_color_override("font_color", Color.WHITE)
	hits_col.add_child(chipping_hits_lbl)
	
	var acc_col = VBoxContainer.new()
	acc_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(acc_col)
	var ac_lbl = Label.new()
	ac_lbl.text = "ACCURACY"
	ac_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ac_lbl.add_theme_font_size_override("font_size", 14)
	ac_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	acc_col.add_child(ac_lbl)
	chipping_accuracy_lbl = Label.new()
	chipping_accuracy_lbl.text = "0%"
	chipping_accuracy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipping_accuracy_lbl.add_theme_font_size_override("font_size", 28)
	chipping_accuracy_lbl.add_theme_color_override("font_color", Color.WHITE)
	acc_col.add_child(chipping_accuracy_lbl)
	
	var target_panel = PanelContainer.new()
	target_panel.custom_minimum_size = Vector2(220, 400)
	target_panel.anchor_left = 0.0
	target_panel.anchor_top = 0.5
	target_panel.anchor_bottom = 0.5
	target_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	target_panel.offset_left = 20
	target_panel.offset_top = -200
	target_panel.offset_bottom = 200
	control.add_child(target_panel)
	target_panel.add_theme_stylebox_override("panel", glass_style)
	
	var target_margin = MarginContainer.new()
	target_margin.add_theme_constant_override("margin_left", 12)
	target_margin.add_theme_constant_override("margin_right", 12)
	target_margin.add_theme_constant_override("margin_top", 12)
	target_margin.add_theme_constant_override("margin_bottom", 12)
	target_panel.add_child(target_margin)
	
	var target_vbox = VBoxContainer.new()
	target_vbox.add_theme_constant_override("separation", 10)
	target_margin.add_child(target_vbox)
	
	var t_title = Label.new()
	t_title.text = "CHOOSE TARGET"
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_title.add_theme_font_size_override("font_size", 16)
	t_title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	target_vbox.add_child(t_title)
	
	chipping_buttons.clear()
	for i in range(chipping_distances.size()):
		var btn = Button.new()
		btn.text = "Target: %d FT" % chipping_distances[i]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 16)
		_apply_chipping_btn_style(btn, Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))
		btn.pressed.connect(func(idx=i): _select_chipping_target(idx))
		target_vbox.add_child(btn)
		chipping_buttons.append(btn)
		
	var exit_btn = Button.new()
	exit_btn.text = "Exit Minigame"
	exit_btn.custom_minimum_size = Vector2(0, 50)
	exit_btn.add_theme_font_size_override("font_size", 16)
	_apply_chipping_btn_style(exit_btn, Color(0.36, 0.16, 0.16), Color(0.5, 0.2, 0.2))
	exit_btn.pressed.connect(func():
		GlobalSettings.is_chipping_minigame = false
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		if mp_mgr != null:
			mp_mgr.players.clear()
			mp_mgr.practice_mode_active = false
		SceneManager.change_scene("res://UI/MiniGamesMenu/minigames_menu.tscn")
	)
	target_vbox.add_child(exit_btn)
	
	chipping_banner_lbl = Label.new()
	chipping_banner_lbl.text = "Aim and hit towards the target island green!"
	chipping_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipping_banner_lbl.anchor_left = 0.5
	chipping_banner_lbl.anchor_right = 0.5
	chipping_banner_lbl.anchor_top = 0.25
	chipping_banner_lbl.anchor_bottom = 0.25
	chipping_banner_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chipping_banner_lbl.add_theme_font_size_override("font_size", 20)
	chipping_banner_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	chipping_banner_lbl.add_theme_constant_override("outline_size", 5)
	chipping_banner_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	control.add_child(chipping_banner_lbl)
	
	_update_chipping_hud()


func _apply_chipping_btn_style(btn: Button, norm_color: Color, hov_color: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = norm_color
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(1, 1, 1, 0.15)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = hov_color
	style_hover.corner_radius_top_left = 6
	style_hover.corner_radius_top_right = 6
	style_hover.corner_radius_bottom_right = 6
	style_hover.corner_radius_bottom_left = 6
	style_hover.border_width_left = 1
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 1
	style_hover.border_color = Color(1, 1, 1, 0.3)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_normal)
	btn.add_theme_color_override("font_color", Color.WHITE)
	if btn.custom_minimum_size.y < 48:
		btn.custom_minimum_size.y = 48
	if not btn.has_theme_font_size_override("font_size"):
		btn.add_theme_font_size_override("font_size", 16)


func _update_chipping_hud() -> void:
	if not chipping_stats.has(selected_chipping_target_idx):
		return
	var stats = chipping_stats[selected_chipping_target_idx]
	var att = stats["Attempts"]
	var hits = stats["Hits"]
	var acc = 0
	if att > 0:
		acc = int((float(hits) / float(att)) * 100.0)
		
	if chipping_target_lbl:
		chipping_target_lbl.text = "%d FT" % chipping_distances[selected_chipping_target_idx]
	if chipping_attempts_lbl:
		chipping_attempts_lbl.text = str(att)
	if chipping_hits_lbl:
		chipping_hits_lbl.text = str(hits)
	if chipping_accuracy_lbl:
		chipping_accuracy_lbl.text = "%d%%" % acc
		
	for i in range(chipping_buttons.size()):
		if i == selected_chipping_target_idx:
			chipping_buttons[i].add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
		else:
			chipping_buttons[i].remove_theme_color_override("font_color")


func _show_chipping_banner(text: String) -> void:
	if chipping_banner_lbl:
		chipping_banner_lbl.text = text


# ------------------------------------------------------------------------------
# Shot Trace & Dispersion Overlay System
# ------------------------------------------------------------------------------

func _setup_shot_trace_overlay() -> void:
	if _shot_trace_overlay != null:
		return
	var overlay_script = load("res://UI/shot_trace_overlay.gd")
	if overlay_script != null:
		_shot_trace_overlay = Node3D.new()
		_shot_trace_overlay.set_script(overlay_script)
		_shot_trace_overlay.name = "ShotTraceOverlay"
		add_child(_shot_trace_overlay)
		if _shot_trace_overlay.has_method("set_current_player"):
			_shot_trace_overlay.set_current_player(_get_current_player_name())


func _on_shot_traces_toggled(enabled: bool) -> void:
	if not is_driving_range:
		if _shot_trace_overlay != null:
			_shot_trace_overlay.deactivate()
		if has_node("RangeUI"):
			$RangeUI.hide_dispersion()
		return

	if _shot_trace_overlay == null:
		_setup_shot_trace_overlay()

	var club = _get_current_club()
	var player_name = _get_current_player_name()
	if enabled:
		if _shot_trace_overlay != null:
			_shot_trace_overlay.activate(shot_history, club, player_name)
		if has_node("RangeUI"):
			var club_shots = _get_shots_for_club(club, player_name)
			$RangeUI.show_dispersion(club_shots, club)
	else:
		if _shot_trace_overlay != null:
			_shot_trace_overlay.deactivate()
		if has_node("RangeUI"):
			$RangeUI.hide_dispersion()


func _notify_shot_trace_overlay(shot_data: Dictionary) -> void:
	if not is_driving_range:
		return
	if _shot_trace_overlay == null:
		return
	if not _shot_trace_overlay.is_active():
		return

	_shot_trace_overlay.on_new_shot(shot_data)
	if has_node("RangeUI"):
		var club = _get_current_club()
		var player_name = _get_current_player_name()
		var club_shots = _get_shots_for_club(club, player_name)
		$RangeUI.show_dispersion(club_shots, club)


func _get_shots_for_club(club_name: String, player_name: String = "") -> Array[Dictionary]:
	if player_name.is_empty():
		player_name = _get_current_player_name()
	var result: Array[Dictionary] = []
	for shot in shot_history:
		var s_player = str(shot.get("player", shot.get("player_name", "")))
		if not player_name.is_empty() and not s_player.is_empty() and s_player.to_lower().strip_edges() != player_name.to_lower().strip_edges():
			continue
		var s_club = str(shot.get("club", ""))
		if s_club.to_lower().strip_edges() == club_name.to_lower().strip_edges():
			result.append(shot)
	return result
