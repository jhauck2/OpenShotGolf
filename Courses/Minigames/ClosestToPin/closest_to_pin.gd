extends Node3D

# Preloaded assets
var PlayerScene = preload("res://Player/player.tscn")
const FlagBuilder = preload("res://Courses/Range/flag_builder.gd")

# Minigame state variables
var player = null
var is_driving_range: bool = true

# Camera follow state
var last_camera_offset = Vector3.ZERO
var camera_following = false
var is_dragging = false

# Target state
var target_position: Vector3 = Vector3.ZERO  # World position of current target center
var target_distance_yards: int = 100  # Current target distance in yards
var target_angle_deg: float = 0.0  # Current target angle from tee (degrees)

# Scoring rings: 5 rings, each 3 yards wide
# Ring 0 (center): 0-3 yards = 5 points
# Ring 1: 3-6 yards = 4 points
# Ring 2: 6-9 yards = 3 points
# Ring 3: 9-12 yards = 2 points
# Ring 4: 12-15 yards = 1 point
# Outside 15 yards = 0 points
const RING_WIDTH_YARDS: float = 3.0
const RING_COUNT: int = 5
const RING_POINTS: Array[int] = [5, 4, 3, 2, 1]
const RING_WIDTH_METERS: float = 3.0 * 0.9144  # 3 yards in meters (2.7432m)

# 3-Shot Rotation Gameplay:
# Each player takes 3 consecutive shots at the target before rotating.
# Once all players have taken 3 shots at that target, the target moves to a new location!
const SHOTS_PER_TARGET: int = 3
var current_shot_in_turn: int = 1  # 1, 2, or 3

# Stats
var total_points: int = 0
var total_distance_from_center: float = 0.0  # Running total in yards
var total_shots: int = 0
var shot_in_progress: bool = false

# Random number generator
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# UI elements
var target_title_lbl: Label = null
var target_info_lbl = null
var shot_count_title_lbl: Label = null
var shot_count_lbl = null
var points_title_lbl: Label = null
var points_lbl = null
var avg_dist_title_lbl: Label = null
var avg_dist_lbl = null
var total_dist_title_lbl: Label = null
var total_dist_lbl = null
var banner_lbl = null
var music_toggle_btn = null
var stats_btn = null
var mode_toggle_btn: Button = null
var game_over_panel: PanelContainer = null
var grid_canvas = null
var hud_layer: CanvasLayer = null
var hud_control: Control = null
var _settings_layer: CanvasLayer = null
var raw_ball_data: Dictionary = {}
var display_data: Dictionary = {}
var sfx_applause_player: AudioStreamPlayer = null

# Target 3D nodes
var target_node: Node3D = null
var target_flag_node: Node3D = null
var target_arrow_node: Node3D = null
const TARGET_ARROW_BASE_Y: float = 4.1

# PvP Mode State
const MinigamePlayerModal = preload("res://Courses/Minigames/minigame_player_modal.gd")
var pvp_mode: bool = false
var active_player_index: int = 0
var players_list: Array[Dictionary] = []
var pvp_rounds: int = 5  # 5 rounds x 3 shots = 15 shots per player
var current_round: int = 1
var pvp_winner: int = -1
var players_btn: Button = null
var _player_modal_instance: CanvasLayer = null

const P1_COLOR = Color(0.2, 0.9, 1.0)  # Neon Cyan
const P2_COLOR = Color(1.0, 0.75, 0.25)  # Radiant Amber/Gold

# Materials
var green_mat: StandardMaterial3D
var fringe_mat: StandardMaterial3D
var tee_turf_mat: StandardMaterial3D
var wall_wood_mat: StandardMaterial3D
var ring_mats: Array[StandardMaterial3D] = []

func get_height(_x: float, _z: float) -> float:
	return 0.0

func get_active_player_name() -> String:
	if players_list.is_empty():
		return "Player 1"
	return str(players_list[active_player_index % players_list.size()].get("name", "Player %d" % (active_player_index + 1)))

func get_active_player_color() -> Color:
	if players_list.is_empty():
		return P1_COLOR
	return players_list[active_player_index % players_list.size()].get("color", P1_COLOR)

func get_player_color_at(idx: int) -> Color:
	if idx < players_list.size():
		return players_list[idx].get("color", MinigamePlayerModal.get_player_color(idx))
	return MinigamePlayerModal.get_player_color(idx)

# ========================================
# READY & INITIALIZATION
# ========================================

func _ready() -> void:
	name = "ClosestToPin"
	is_driving_range = true
	set_meta("is_driving_range", true)
	rng.randomize()
	_init_player_names()

	sfx_applause_player = AudioStreamPlayer.new()
	sfx_applause_player.name = "ApplausePlayer"
	if ResourceLoader.exists("res://assets/audio/golf_clap.mp3"):
		sfx_applause_player.stream = load("res://assets/audio/golf_clap.mp3")
	sfx_applause_player.volume_db = 3.0
	add_child(sfx_applause_player)

	# 1. Init Materials
	_init_materials()

	# 2. Environment Setup (Sky, Sun, Camera)
	_setup_environment()

	# 3. Driving Range Ground Mesh with PBR turf shader
	_generate_ground_terrain()

	# 4. Driving Range Visual Elements (Hitting bays, boundary walls, 50yd lines & numerals, trees, mountain backdrop)
	_spawn_driving_range_elements()

	# 5. Setup Player (instantiates ball and camera tracking)
	_setup_player()

	# 6. Apply Driving Range Graphics Quality (High Fidelity shaders, trees, shadows, Sky3D)
	if has_node("Sky3D"):
		MobilePerformance.optimize_sky3d($Sky3D)
	MobilePerformance.optimize_scene(self)
	var range_quality = GlobalSettings.get_graphics_quality() if GlobalSettings != null else "High"
	MobilePerformance.apply_graphics_quality(self, range_quality)
	_setup_atmospheric_fog()

	# 7. Generate random target (50-200 yards)
	_generate_new_target()

	# 8. Setup GUI HUD
	_setup_ui()

	# 9. Initial Camera & Aim setup (Ensures the camera is immediately framed looking at the target!)
	_reset_ball_position()

	_show_banner("🎯 Closest to Pin — Take 3 shots at the target! (Shot 1/3)")
	_auto_select_club_for_distance(target_distance_yards)

	# Connect Launch Monitor
	if has_node("/root/LaunchMonitorManager"):
		var launch_monitor = get_node("/root/LaunchMonitorManager")
		if not launch_monitor.hit_ball.is_connected(_on_launch_monitor_hit_ball):
			launch_monitor.hit_ball.connect(_on_launch_monitor_hit_ball)
		if launch_monitor.has_method("_update_hud_display"):
			launch_monitor.call("_update_hud_display")
		if launch_monitor.has_method("notify_ball_at_rest"):
			launch_monitor.call("notify_ball_at_rest")

	var tcp_server = get_node_or_null("TCPServer")
	if tcp_server == null:
		var tcp_script = load("res://addons/launch_monitors/common/tcp_server/TcpServer.cs")
		if tcp_script != null:
			tcp_server = tcp_script.new()
			tcp_server.name = "TCPServer"
			add_child(tcp_server)
	if tcp_server != null and tcp_server.has_signal("HitBall"):
		if not tcp_server.HitBall.is_connected(_on_launch_monitor_hit_ball):
			tcp_server.HitBall.connect(_on_launch_monitor_hit_ball)


func _init_player_names() -> void:
	if players_list.is_empty():
		players_list = MinigamePlayerModal.init_default_players(pvp_rounds)
	if players_list.size() < 2:
		var p2 = MinigamePlayerModal.create_player("Player 2", 1, pvp_rounds)
		players_list.append(p2)
	for p in players_list:
		p["points"] = 0
		p["total_distance"] = 0.0
		p["shots"] = 0
	_update_players_button_label()


func _toggle_pvp_mode() -> void:
	pvp_mode = not pvp_mode
	_hide_game_over_banner()
	if mode_toggle_btn != null:
		if pvp_mode:
			mode_toggle_btn.text = "⚔️ PvP Mode: ON"
			_apply_btn_style(mode_toggle_btn, Color(0.18, 0.45, 0.65), Color(0.25, 0.58, 0.82))
		else:
			mode_toggle_btn.text = "⚔️ PvP Mode: OFF"
			_apply_btn_style(mode_toggle_btn, Color(0.20, 0.25, 0.35), Color(0.28, 0.35, 0.48))
	if players_btn != null:
		players_btn.visible = pvp_mode
	_reset_game()


func _reset_game() -> void:
	_init_player_names()
	_hide_game_over_banner()
	shot_in_progress = false
	active_player_index = 0
	current_shot_in_turn = 1
	pvp_winner = -1
	current_round = 1
	total_points = 0
	total_distance_from_center = 0.0
	total_shots = 0

	for p in players_list:
		p["shots"] = 0
		p["points"] = 0
		p["total_distance"] = 0.0

	_generate_new_target()
	_reset_ball_position()
	_update_hud()
	_update_players_button_label()
	_show_banner("🎯 Closest to Pin — Take 3 shots at the target! (Shot 1/3)")


func _open_players_modal() -> void:
	if _player_modal_instance != null and is_instance_valid(_player_modal_instance):
		_player_modal_instance.queue_free()
		_player_modal_instance = null

	var modal = MinigamePlayerModal.new()
	modal.name = "MinigamePlayerModal"
	add_child(modal)
	_player_modal_instance = modal
	modal.open(players_list, 2, pvp_rounds, active_player_index)
	modal.players_changed.connect(func(new_players):
		players_list = new_players
		if active_player_index >= players_list.size():
			active_player_index = 0
		_update_players_button_label()
		_update_hud()
	)
	modal.reset_match_requested.connect(func():
		_reset_game()
	)
	modal.modal_closed.connect(func():
		_player_modal_instance = null
		_update_hud()
	)


func _update_players_button_label() -> void:
	if players_btn != null and is_instance_valid(players_btn):
		players_btn.text = "👥 Players (%d)" % players_list.size()


# ========================================
# MATERIAL INITIALIZATION
# ========================================

func _init_materials() -> void:
	# Putting Green surface (for target green disc)
	green_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		green_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		green_mat.albedo_color = Color(0.9, 1.0, 0.9)
		green_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	else:
		green_mat.albedo_color = Color(0.16, 0.65, 0.22)
	green_mat.roughness = 0.88

	# Tee Turf
	tee_turf_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		tee_turf_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		tee_turf_mat.albedo_color = Color(0.85, 1.0, 0.85)
		tee_turf_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	else:
		tee_turf_mat.albedo_color = Color(0.18, 0.70, 0.25)
	tee_turf_mat.roughness = 0.85

	# Tee Wood Border
	wall_wood_mat = StandardMaterial3D.new()
	wall_wood_mat.albedo_color = Color(0.25, 0.18, 0.12)
	wall_wood_mat.roughness = 0.9

	# 5 Concentric Target Rings:
	# 0: Bullseye (0-3 yds) - Hot Red
	# 1: Ring 2 (3-6 yds) - Radiant Orange
	# 2: Ring 3 (6-9 yds) - Golden Yellow
	# 3: Ring 4 (9-12 yds) - Emerald Lime
	# 4: Ring 5 (12-15 yds) - Electric Cyan
	var ring_colors = [
		Color(1.0, 0.18, 0.18),  # Ring 0 (5pts): Red
		Color(1.0, 0.55, 0.10),  # Ring 1 (4pts): Orange
		Color(1.0, 0.85, 0.15),  # Ring 2 (3pts): Yellow
		Color(0.20, 0.90, 0.35), # Ring 3 (2pts): Green
		Color(0.15, 0.70, 1.00), # Ring 4 (1pt): Blue/Cyan
	]
	ring_mats.clear()
	for i in range(RING_COUNT):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(ring_colors[i].r, ring_colors[i].g, ring_colors[i].b, 0.65)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = ring_colors[i]
		mat.emission_energy_multiplier = 0.6
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_mats.append(mat)


# ========================================
# ENVIRONMENT & LIGHTING SETUP
# ========================================

func _setup_environment() -> void:
	var is_mobile := MobilePerformance.is_mobile()

	if not has_node("Sky3D"):
		var sun = DirectionalLight3D.new()
		sun.name = "SunLight"
		sun.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-52)).rotated(Vector3.UP, deg_to_rad(35))
		sun.shadow_enabled = true
		sun.light_energy = 1.2
		if is_mobile:
			sun.directional_shadow_max_distance = 200.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_blend_splits = true
			sun.directional_shadow_split_1 = 0.1
		else:
			sun.directional_shadow_max_distance = 500.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_blend_splits = true
			sun.directional_shadow_split_1 = 0.05
			sun.directional_shadow_split_2 = 0.15
			sun.directional_shadow_split_3 = 0.40
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 2.0
		add_child(sun)

		var world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"

		var env = Environment.new()
		env.background_mode = Environment.BG_SKY

		var sky = Sky.new()
		sky.process_mode = Sky.PROCESS_MODE_REALTIME
		sky.radiance_size = Sky.RADIANCE_SIZE_128 if is_mobile else Sky.RADIANCE_SIZE_256
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.22, 0.52, 0.86)
		sky_mat.sky_horizon_color = Color(0.58, 0.76, 0.92)
		sky_mat.ground_bottom_color = Color(0.15, 0.28, 0.20)
		sky_mat.ground_horizon_color = Color(0.58, 0.76, 0.92)
		sky_mat.sun_angle_max = 35.0
		sky.sky_material = sky_mat
		env.sky = sky

		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.50
		env.ambient_light_sky_contribution = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_white = 5.0
		env.tonemap_exposure = 1.0
		if is_mobile:
			env.ssao_enabled = false
		else:
			env.ssao_enabled = true
			env.ssao_radius = 2.0
			env.ssao_intensity = 1.2
			env.ssao_power = 1.5

		env.fog_enabled = true
		env.fog_light_color = Color(0.65, 0.78, 0.88)
		env.fog_density = 0.0018
		env.fog_sky_affect = 0.3

		world_env.environment = env
		add_child(world_env)

	# Main Gameplay Camera
	var camera = get_node_or_null("Camera3D")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		camera.near = 0.05
		camera.far = 4000.0
		add_child(camera)
	if has_node("Sky3D") and $Sky3D is WorldEnvironment and $Sky3D.camera_attributes != null:
		camera.attributes = $Sky3D.camera_attributes
	if has_node("/root/TensionManager"):
		TensionManager.register_camera(camera, 55.0)
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.register_camera(camera)
		ScreenOffsetManager.on_ready_for_shot(0.0, true)


func _setup_atmospheric_fog() -> void:
	var skydome = get_node_or_null("Sky3D/Skydome")
	if skydome == null:
		return
	skydome.fog_density = 0.0018
	skydome.fog_start = 140.0
	skydome.fog_end = 350.0
	skydome.clouds_visible = true
	skydome.clouds_cumulus_visible = false
	skydome.clouds_speed = 0.005
	skydome.clouds_cumulus_speed = 0.003


# ========================================
# DRIVING RANGE GROUND TERRAIN (Shader Mesh)
# ========================================

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

	var mat := ShaderMaterial.new()
	var shader = load("res://Courses/Environments/shaders/driving_range_turf.gdshader")
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("tex_fairway", load("res://Courses/Environments/grass-fairway/albedo.png"))
		mat.set_shader_parameter("normal_fairway", load("res://Courses/Environments/grass-fairway/normal.png"))
		mat.set_shader_parameter("ao_fairway", load("res://Courses/Environments/grass-fairway/ao.png"))
		mat.set_shader_parameter("roughness_fairway", load("res://Courses/Environments/grass-fairway/roughness.png"))

		mat.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
		mat.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
		mat.set_shader_parameter("ao_rough", load("res://Courses/Environments/grass-rough/ao.png"))
		mat.set_shader_parameter("roughness_rough", load("res://Courses/Environments/grass-rough/roughness.png"))

		mat.set_shader_parameter("corridor_half_width", 26.0)
		mat.set_shader_parameter("blend_margin", 0.85)
		mat.set_shader_parameter("tee_start_x", -12.0)
		mat.set_shader_parameter("tee_blend_x", 4.0)
		mat.set_shader_parameter("max_range_dist", 320.04)
		mat.set_shader_parameter("uv_scale_fairway", 0.12)
		mat.set_shader_parameter("uv_scale_rough", 0.08)
		mat.set_shader_parameter("normal_depth", 0.65)
		mat.set_shader_parameter("stripe_strength", 0.70)
	st.set_material(mat)

	for z in range(subdiv_z):
		for x in range(subdiv_x):
			var x0 := min_x + x * cell_w
			var x1 := x0 + cell_w
			var z0 := min_z + z * cell_d
			var z1 := z0 + cell_d

			var p00 := Vector3(x0, 0.0, z0)
			var p10 := Vector3(x1, 0.0, z0)
			var p01 := Vector3(x0, 0.0, z1)
			var p11 := Vector3(x1, 0.0, z1)

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
	static_body.set_meta("surface_type", 0)  # FAIRWAY
	mesh_instance.add_child(static_body)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)


# ========================================
# DRIVING RANGE GRAPHICS & DECORATIONS
# ========================================

func _spawn_driving_range_elements() -> void:
	_spawn_hitting_bays()
	_spawn_boundary_walls()
	_spawn_ground_distance_indicators()
	_spawn_range_trees()
	_spawn_mountain_backdrop()


func _spawn_hitting_bays() -> void:
	if has_node("DrivingRangeBaySetup"):
		$DrivingRangeBaySetup.queue_free()
	var bays_script = load("res://Courses/Range/driving_range_bays.gd")
	if bays_script != null:
		var bays_node = bays_script.create_bay_setup()
		bays_node.name = "DrivingRangeBaySetup"
		add_child(bays_node)
	else:
		_setup_tee_box()


func _spawn_boundary_walls() -> void:
	var far_wall_x := 415.0
	var side_wall_z := 125.0
	var back_wall_x := -80.0
	var wall_height := 1.5
	var wall_thickness := 0.2
	var wall_color := Color(0.15, 0.15, 0.15)

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


func _spawn_ground_distance_indicators() -> void:
	var markings_root = Node3D.new()
	markings_root.name = "DrivingRangeMarkings"
	add_child(markings_root)

	var major_yardages: Array[float] = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0]
	var corridor_half_w: float = 26.0
	var max_dist_m: float = 350.0 * 0.9144

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

	# 1. Left and right corridor sideline boundary lines
	var seg_len: float = 10.0
	var current_x: float = 0.0
	while current_x < max_dist_m:
		var next_x = minf(current_x + seg_len, max_dist_m)
		var fade_alpha = clamp(remap(next_x, 280.0, max_dist_m, 1.0, 0.60), 0.0, 1.0)
		var seg_col = Color(1.0, 1.0, 1.0, fade_alpha)
		_add_ground_quad(st, current_x, next_x, -corridor_half_w - 0.32, -corridor_half_w + 0.32, 0.02, seg_col)
		_add_ground_quad(st, current_x, next_x, corridor_half_w - 0.32, corridor_half_w + 0.32, 0.02, seg_col)
		current_x = next_x

	# 2. 50-yard major lines and numerals
	var major_zones: Array[Dictionary] = []
	var anamorphic_stretch_y: float = 2.4
	for yd in major_yardages:
		var x_line = yd * 0.9144
		var dist_ratio = clamp((yd - 50.0) / 300.0, 0.0, 1.0)
		var line_thick = 1.60 + dist_ratio * 0.80
		var base_letter_h = 5.0 + dist_ratio * 15.0
		var effective_h = base_letter_h * anamorphic_stretch_y
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

	for zone in major_zones:
		var x_line = zone.x_line
		var half_t = zone.line_thick * 0.5
		var alpha_50yd = clamp(remap(zone.yd, 250.0, 350.0, 1.0, 0.75), 0.5, 1.0)
		var col_50yd = Color(1.0, 1.0, 1.0, alpha_50yd)
		_add_ground_quad(st, x_line - half_t, x_line + half_t, -corridor_half_w, corridor_half_w, 0.021, col_50yd)

	# 3. 10-yard sideline ticks
	var tick_10yd_len: float = 6.0
	for yd in range(10, 201, 10):
		if int(yd) % 50 == 0:
			continue
		var x_pos = yd * 0.9144
		var tick_thick = 0.55
		var alpha_10yd = clamp(remap(yd, 120.0, 200.0, 0.90, 0.0), 0.0, 0.90)
		if alpha_10yd <= 0.01:
			continue
		var col_10yd = Color(1.0, 1.0, 1.0, alpha_10yd)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, -corridor_half_w, -corridor_half_w + tick_10yd_len, 0.02, col_10yd)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, corridor_half_w - tick_10yd_len, corridor_half_w, 0.02, col_10yd)

	# 4. 1-yard approach ticks (1 to 50 yards)
	var tick_1yd_len: float = 2.2
	for yd in range(1, 51):
		if yd % 10 == 0:
			continue
		var x_pos = yd * 0.9144
		var tick_thick = 0.30
		var alpha_1yd = clamp(remap(yd, 28.0, 50.0, 0.85, 0.0), 0.0, 0.85)
		if alpha_1yd <= 0.01:
			continue
		var col_1yd = Color(1.0, 1.0, 1.0, alpha_1yd)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, -corridor_half_w, -corridor_half_w + tick_1yd_len, 0.019, col_1yd)
		_add_ground_quad(st, x_pos - tick_thick * 0.5, x_pos + tick_thick * 0.5, corridor_half_w - tick_1yd_len, corridor_half_w, 0.019, col_1yd)

	var mesh = st.commit()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "GroundMarkingsMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = line_mat
	markings_root.add_child(mesh_inst)

	# 5. Giant 3D ground distance numerals
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
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		label.render_priority = 3
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.rotation_degrees = Vector3(-90.0, -90.0, 0.0)
		label.position = Vector3(zone.label_x, 0.025, 0.0)
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


func _spawn_range_trees() -> void:
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
		return

	var tree_rng = RandomNumberGenerator.new()
	tree_rng.seed = 2026

	var tree_data: Array[Dictionary] = []
	var add_tree = func(pos: Vector3, tier: int = 1):
		var roll := tree_rng.randf()
		var p_base := 0.15
		var p_huge := 0.30 if tier <= 2 else 0.35
		var s: float
		if roll < p_base:
			s = tree_rng.randf_range(0.95, 1.15)
		elif roll < p_huge:
			s = tree_rng.randf_range(1.95, 2.25)
		else:
			s = tree_rng.randf_range(1.40, 1.65)
		tree_data.append({"pos": pos, "scale": s})

	var left_base_z := -71.72
	var right_base_z := 71.72
	var far_base_x := 365.76
	var back_base_x := -32.0

	# 1. Left sideline tree belt
	var curr_x := -35.0
	while curr_x <= 365.0:
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(-2.0, 2.0), 0.0, left_base_z + tree_rng.randf_range(-3.0, 3.0)), 1)
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(1.5, 4.5), 0.0, left_base_z - 8.0 + tree_rng.randf_range(-3.0, 3.0)), 2)
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(-1.0, 3.5), 0.0, left_base_z - 17.0 + tree_rng.randf_range(-3.5, 3.5)), 3)
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(2.0, 5.5), 0.0, left_base_z - 26.5 + tree_rng.randf_range(-4.0, 4.0)), 4)
		if tree_rng.randf() < 0.40:
			add_tree.call(Vector3(curr_x + tree_rng.randf_range(-2.0, 4.0), 0.0, left_base_z - 35.0 + tree_rng.randf_range(-4.0, 4.0)), 4)
		curr_x += tree_rng.randf_range(6.0, 9.0)

	# 2. Right sideline tree belt
	curr_x = -35.0
	while curr_x <= 365.0:
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(-2.0, 2.0), 0.0, right_base_z + tree_rng.randf_range(-3.0, 3.0)), 1)
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(1.5, 4.5), 0.0, right_base_z + 8.0 + tree_rng.randf_range(-3.0, 3.0)), 2)
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(-1.0, 3.5), 0.0, right_base_z + 17.0 + tree_rng.randf_range(-3.5, 3.5)), 3)
		add_tree.call(Vector3(curr_x + tree_rng.randf_range(2.0, 5.5), 0.0, right_base_z + 26.5 + tree_rng.randf_range(-4.0, 4.0)), 4)
		if tree_rng.randf() < 0.40:
			add_tree.call(Vector3(curr_x + tree_rng.randf_range(-2.0, 4.0), 0.0, right_base_z + 35.0 + tree_rng.randf_range(-4.0, 4.0)), 4)
		curr_x += tree_rng.randf_range(6.0, 9.0)

	# 3. Far end tree belt
	var curr_z := -72.0
	while curr_z <= 72.0:
		add_tree.call(Vector3(far_base_x + tree_rng.randf_range(-3.0, 3.0), 0.0, curr_z + tree_rng.randf_range(-2.0, 2.0)), 1)
		add_tree.call(Vector3(far_base_x + 9.0 + tree_rng.randf_range(-3.0, 3.0), 0.0, curr_z + tree_rng.randf_range(1.5, 4.5)), 2)
		add_tree.call(Vector3(far_base_x + 18.5 + tree_rng.randf_range(-3.5, 3.5), 0.0, curr_z + tree_rng.randf_range(-1.0, 3.5)), 3)
		add_tree.call(Vector3(far_base_x + 28.0 + tree_rng.randf_range(-4.0, 4.0), 0.0, curr_z + tree_rng.randf_range(2.0, 5.5)), 4)
		if tree_rng.randf() < 0.40:
			add_tree.call(Vector3(far_base_x + 36.5 + tree_rng.randf_range(-4.0, 4.0), 0.0, curr_z + tree_rng.randf_range(-2.0, 4.0)), 4)
		curr_z += tree_rng.randf_range(6.0, 9.0)

	# 4. Behind the tee belt
	curr_z = -72.0
	while curr_z <= 72.0:
		add_tree.call(Vector3(back_base_x + tree_rng.randf_range(-2.5, 2.5), 0.0, curr_z + tree_rng.randf_range(-2.0, 2.0)), 1)
		add_tree.call(Vector3(back_base_x - 8.5 + tree_rng.randf_range(-3.0, 3.0), 0.0, curr_z + tree_rng.randf_range(1.5, 4.5)), 2)
		add_tree.call(Vector3(back_base_x - 17.5 + tree_rng.randf_range(-3.5, 3.5), 0.0, curr_z + tree_rng.randf_range(-1.0, 3.5)), 3)
		add_tree.call(Vector3(back_base_x - 26.5 + tree_rng.randf_range(-4.0, 4.0), 0.0, curr_z + tree_rng.randf_range(2.0, 5.5)), 4)
		if tree_rng.randf() < 0.40:
			add_tree.call(Vector3(back_base_x - 34.5 + tree_rng.randf_range(-4.0, 4.0), 0.0, curr_z + tree_rng.randf_range(-2.0, 4.0)), 4)
		curr_z += tree_rng.randf_range(6.5, 9.5)

	# 5. Corners
	var corners = [
		{"xmin": 360.0, "xmax": 402.0, "zmin": -106.0, "zmax": -68.0},
		{"xmin": 360.0, "xmax": 402.0, "zmin": 68.0, "zmax": 106.0},
		{"xmin": -66.0, "xmax": -28.0, "zmin": -106.0, "zmax": -68.0},
		{"xmin": -66.0, "xmax": -28.0, "zmin": 68.0, "zmax": 106.0},
	]
	for c in corners:
		for k in range(12):
			var cx = tree_rng.randf_range(c.xmin, c.xmax)
			var cz = tree_rng.randf_range(c.zmin, c.zmax)
			add_tree.call(Vector3(cx, 0.0, cz), 3)

	for i in range(tree_data.size()):
		var data = tree_data[i]
		var pos: Vector3 = data["pos"]
		var scene_idx = tree_rng.randi() % tree_scenes.size()
		var tree_inst = tree_scenes[scene_idx].instantiate() as StaticBody3D
		if tree_inst == null:
			continue
		tree_inst.name = "RangeTree_%d" % i
		tree_inst.position = Vector3(pos.x, 0.0, pos.z)
		tree_inst.rotation.y = tree_rng.randf_range(0.0, TAU)
		var s: float = data["scale"]
		tree_inst.scale = Vector3(s, s, s)
		trees_root.add_child(tree_inst)


func _spawn_mountain_backdrop() -> void:
	var tex = load("res://Courses/Environments/mountain_backdrop_seamless.png")
	if tex == null:
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

	var center_x := 30.0
	var radius := 430.0
	var y_bottom := -4.0
	var y_top := 145.0
	var segments := 72
	var angle_start := deg_to_rad(-115.0)
	var angle_end := deg_to_rad(115.0)
	var angle_span := angle_end - angle_start

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
	mountain_root.add_child(mesh_inst)


# ========================================
# TEE BOX
# ========================================

func _setup_tee_box() -> void:
	var tee = StaticBody3D.new()
	tee.name = "TeeBox"
	tee.set_meta("surface_type", 3)  # TEE
	add_child(tee)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(6.0, 0.4, 6.0)
	col.shape = box
	col.position = Vector3(0.0, -0.2, 0.0)
	tee.add_child(col)

	var base_mesh_inst = MeshInstance3D.new()
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(6.4, 0.38, 6.4)
	base_mesh_inst.mesh = base_mesh
	base_mesh_inst.material_override = wall_wood_mat
	base_mesh_inst.position = Vector3(0.0, -0.2, 0.0)
	tee.add_child(base_mesh_inst)

	var turf_inst = MeshInstance3D.new()
	var turf_mesh = BoxMesh.new()
	turf_mesh.size = Vector3(6.0, 0.04, 6.0)
	turf_inst.mesh = turf_mesh
	turf_inst.material_override = tee_turf_mat
	turf_inst.position = Vector3(0.0, 0.02, 0.0)
	tee.add_child(turf_inst)

	# Tee markers (White Spheres)
	for side_z in [-1.5, 1.5]:
		var marker = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.08
		sphere_mesh.height = 0.16
		marker.mesh = sphere_mesh
		var marker_mat = StandardMaterial3D.new()
		marker_mat.albedo_color = Color.WHITE
		marker.material_override = marker_mat
		marker.position = Vector3(0.0, 0.1, side_z)
		tee.add_child(marker)


# ========================================
# TARGET GENERATION & SCORING RINGS
# ========================================

func _generate_new_target() -> void:
	if target_node != null and is_instance_valid(target_node):
		target_node.queue_free()
		target_node = null
	target_flag_node = null
	target_arrow_node = null

	# Random distance 50 to 200 yards
	target_distance_yards = rng.randi_range(50, 200)

	# Lateral offset placed within the fairway corridor (-14 to +14 yards)
	var lateral_yards = rng.randf_range(-14.0, 14.0)

	var x = target_distance_yards * 0.9144
	var z = lateral_yards * 0.9144
	target_position = Vector3(x, 0.0, z)

	# Compute exact line-of-sight yardage from tee
	target_distance_yards = int(round(target_position.length() * 1.09361))

	_build_target_rings()
	_auto_select_club_for_distance(target_distance_yards)


func _build_target_rings() -> void:
	target_node = Node3D.new()
	target_node.name = "TargetRings"
	target_node.position = target_position
	add_child(target_node)

	# Underlying green turf disc with green surface physics (15.5 yards radius)
	var green_disc_radius_m = (RING_COUNT * RING_WIDTH_YARDS + 0.5) * 0.9144
	var green_disc_mesh = _create_disc_mesh(green_disc_radius_m, 48)
	if green_disc_mesh:
		var green_disc_inst = MeshInstance3D.new()
		green_disc_inst.name = "TargetGreenTurf"
		green_disc_inst.mesh = green_disc_mesh
		green_disc_inst.material_override = green_mat
		green_disc_inst.position = Vector3(0.0, 0.024, 0.0)
		target_node.add_child(green_disc_inst)

		var green_body = StaticBody3D.new()
		green_body.name = "TargetGreenBody"
		green_body.set_meta("surface_type", 4)  # GREEN
		var col_shape = CollisionShape3D.new()
		var cyl_shape = CylinderShape3D.new()
		cyl_shape.radius = green_disc_radius_m
		cyl_shape.height = 0.2
		col_shape.shape = cyl_shape
		col_shape.position = Vector3(0.0, -0.1, 0.0)
		green_body.add_child(col_shape)
		target_node.add_child(green_body)

	# Build concentric rings from outside (Ring 4) in to Ring 0 (Bullseye)
	for i in range(RING_COUNT - 1, -1, -1):
		var outer_radius_m = (i + 1) * RING_WIDTH_METERS
		var inner_radius_m = i * RING_WIDTH_METERS

		var ring_mesh = _create_ring_mesh(inner_radius_m, outer_radius_m)
		if ring_mesh:
			var ring_inst = MeshInstance3D.new()
			ring_inst.name = "Ring_%d" % i
			ring_inst.mesh = ring_mesh
			ring_inst.material_override = ring_mats[i]
			ring_inst.position = Vector3(0.0, 0.030 + (RING_COUNT - i) * 0.003, 0.0)
			target_node.add_child(ring_inst)

	# Center Bullseye Disc (Ring 0, 0 to 3 yards radius)
	var center_mesh = _create_disc_mesh(RING_WIDTH_METERS, 36)
	if center_mesh:
		var center_inst = MeshInstance3D.new()
		center_inst.name = "CenterBullseye"
		center_inst.mesh = center_mesh
		var center_mat = StandardMaterial3D.new()
		center_mat.albedo_color = Color(1.0, 0.18, 0.18, 0.85)
		center_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		center_mat.emission_enabled = true
		center_mat.emission = Color(1.0, 0.20, 0.20)
		center_mat.emission_energy_multiplier = 0.8
		center_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		center_inst.material_override = center_mat
		center_inst.position = Vector3(0.0, 0.048, 0.0)
		target_node.add_child(center_inst)

	# Flagpole at target center
	_build_target_flag()

	# Overhead downward-pointing arrow above the bullseye center
	_build_target_arrow()

	# Ring Point value labels
	_add_ring_point_labels()


func _create_ring_mesh(inner_r: float, outer_r: float, segments: int = 64) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segments):
		var t0 = float(i) / float(segments) * TAU
		var t1 = float(i + 1) / float(segments) * TAU

		var outer0 = Vector3(outer_r * cos(t0), 0.0, outer_r * sin(t0))
		var outer1 = Vector3(outer_r * cos(t1), 0.0, outer_r * sin(t1))
		var inner0 = Vector3(inner_r * cos(t0), 0.0, inner_r * sin(t0))
		var inner1 = Vector3(inner_r * cos(t1), 0.0, inner_r * sin(t1))

		st.set_normal(Vector3.UP)
		st.add_vertex(outer0)
		st.set_normal(Vector3.UP)
		st.add_vertex(outer1)
		st.set_normal(Vector3.UP)
		st.add_vertex(inner0)

		st.set_normal(Vector3.UP)
		st.add_vertex(outer1)
		st.set_normal(Vector3.UP)
		st.add_vertex(inner1)
		st.set_normal(Vector3.UP)
		st.add_vertex(inner0)

	return st.commit()


func _create_disc_mesh(radius: float, segments: int = 32) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segments):
		var t0 = float(i) / float(segments) * TAU
		var t1 = float(i + 1) / float(segments) * TAU

		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(radius * cos(t0), 0.0, radius * sin(t0)))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(radius * cos(t1), 0.0, radius * sin(t1)))

	return st.commit()


func _build_target_flag() -> void:
	target_flag_node = Node3D.new()
	target_flag_node.name = "TargetFlag"
	target_flag_node.position = Vector3(0.0, 0.04, 0.0)
	target_node.add_child(target_flag_node)

	var col = get_active_player_color() if pvp_mode else Color(1.0, 0.20, 0.20)
	var q_str = ""
	var gs = GlobalSettings if GlobalSettings != null else (get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null)
	if gs != null and gs.has_method("get_graphics_quality"):
		q_str = gs.get_graphics_quality()
	FlagBuilder.setup_target_flag(target_flag_node, 2.6, col, 0.55, 0.38, true, q_str)

	# Distance label
	var label = Label3D.new()
	label.name = "TargetDistLabel"
	label.text = "🎯 %d YDS" % target_distance_yards
	label.font_size = 54
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 14
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.position = Vector3(0.0, 3.25, 0.0)
	target_flag_node.add_child(label)


func _build_target_arrow() -> void:
	target_arrow_node = Node3D.new()
	target_arrow_node.name = "TargetArrow"
	target_arrow_node.position = Vector3(0.0, TARGET_ARROW_BASE_Y, 0.0)
	target_node.add_child(target_arrow_node)

	var arrow_mat = StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(1.0, 0.85, 0.1)
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color(1.0, 0.75, 0.05)
	arrow_mat.emission_energy_multiplier = 1.2
	arrow_mat.roughness = 0.25

	# Downward-pointing cone head (tip at local y = 0.0)
	var head_mesh = CylinderMesh.new()
	head_mesh.top_radius = 0.65
	head_mesh.bottom_radius = 0.0
	head_mesh.height = 1.2
	head_mesh.radial_segments = 24
	var head_inst = MeshInstance3D.new()
	head_inst.name = "ArrowHead"
	head_inst.mesh = head_mesh
	head_inst.material_override = arrow_mat
	head_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_inst.position = Vector3(0.0, 0.6, 0.0)
	target_arrow_node.add_child(head_inst)

	# Vertical shaft above the arrowhead
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.24
	shaft_mesh.bottom_radius = 0.24
	shaft_mesh.height = 1.5
	shaft_mesh.radial_segments = 20
	var shaft_inst = MeshInstance3D.new()
	shaft_inst.name = "ArrowShaft"
	shaft_inst.mesh = shaft_mesh
	shaft_inst.material_override = arrow_mat
	shaft_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft_inst.position = Vector3(0.0, 1.95, 0.0)
	target_arrow_node.add_child(shaft_inst)


func _process(_delta: float) -> void:
	if target_arrow_node != null and is_instance_valid(target_arrow_node):
		var t := Time.get_ticks_msec() * 0.001
		target_arrow_node.position.y = TARGET_ARROW_BASE_Y + sin(t * 2.8) * 0.25


func _add_ring_point_labels() -> void:
	for i in range(RING_COUNT):
		var ring_center_m = (i + 0.5) * RING_WIDTH_METERS
		var label = Label3D.new()
		label.name = "RingLabel_%d" % i
		label.text = "%d pt" % RING_POINTS[i]
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 8
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0, 0, 0, 0.8)
		label.position = Vector3(ring_center_m, 0.35, 0.0)
		target_node.add_child(label)


func _auto_select_club_for_distance(yds: int) -> void:
	var club = "7i"
	if yds < 75:
		club = "Lw"
	elif yds < 95:
		club = "Sw"
	elif yds < 115:
		club = "Gw"
	elif yds < 135:
		club = "Pw"
	elif yds < 150:
		club = "9i"
	elif yds < 165:
		club = "8i"
	elif yds < 180:
		club = "7i"
	elif yds < 195:
		club = "6i"
	else:
		club = "5i"

	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected"):
			eb.club_selected.emit(club)


# ========================================
# SCORING CALCULATION
# ========================================

func _calculate_score(ball_pos: Vector3) -> Dictionary:
	var dist_2d = Vector2(ball_pos.x, ball_pos.z).distance_to(Vector2(target_position.x, target_position.z))
	var dist_yards = dist_2d * 1.09361  # meters to yards

	var points = 0
	var ring_index = -1  # -1 means outside all rings

	for i in range(RING_COUNT):
		var ring_outer_yards = (i + 1) * RING_WIDTH_YARDS
		if dist_yards <= ring_outer_yards:
			points = RING_POINTS[i]
			ring_index = i
			break

	return {
		"points": points,
		"ring_index": ring_index,
		"distance_yards": dist_yards,
		"distance_meters": dist_2d
	}


# ========================================
# PLAYER & AIMING
# ========================================

func _setup_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)

	player.set_process(false)
	player.rest.connect(_on_ball_rest)

	player.ball.spawn_position = player.global_position
	if player.has_method("set_profile"):
		player.set_profile(get_active_player_name())
	player.ball.reset()


func _reset_ball_position() -> void:
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	shot_in_progress = false
	if player != null and player.ball != null:
		player.global_position = Vector3(0.0, 0.05, 0.0)
		player.ball.spawn_position = player.global_position
		if player.has_method("set_profile"):
			player.set_profile(get_active_player_name())
		player.ball.reset()
		player.reset_ball()
	_update_aim_and_camera()
	_update_hud()
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_ready_for_shot()
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()


func _update_aim_and_camera() -> void:
	if player == null or player.ball == null:
		return
	var ball_pos = player.ball.global_position

	var diff = target_position - ball_pos
	var angle_rad = atan2(diff.z, diff.x)

	player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)

	var back_dir = Vector3(-cos(angle_rad), 0.0, -sin(angle_rad)).normalized()
	var cam_pos = ball_pos + back_dir * 4.2 + Vector3.UP * 2.2

	var cam = get_node_or_null("Camera3D")
	if cam != null:
		cam.global_position = cam_pos
		var look_target = ball_pos + (target_position - ball_pos).normalized() * 15.0 + Vector3.UP * 1.0
		cam.look_at(look_target)

	last_camera_offset = cam_pos - ball_pos


# ========================================
# INPUT & HIT SIMULATION
# ========================================

func _unhandled_input(event: InputEvent) -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_settings()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if pvp_mode:
				_reset_game()
			else:
				total_points = 0
				total_distance_from_center = 0.0
				total_shots = 0
				current_shot_in_turn = 1
				_generate_new_target()
				_reset_ball_position()
		elif event.keycode == KEY_H or event.keycode == KEY_SPACE:
			if player and player.ball and player.ball.state == PhysicsEnums.BallState.REST:
				var dist_m = target_distance_yards * 0.9144
				var sim_speed_mph = sqrt(dist_m * 9.8 / sin(deg_to_rad(45.0))) * 2.23694 * 1.02
				var test_data = {
					"Speed": sim_speed_mph,
					"VLA": 22.0,
					"HLA": 0.0,
					"SpinAxis": 0.0,
					"TotalSpin": 3200.0,
					"BackSpin": 3200.0,
					"SideSpin": 0.0,
					"ShotType": "full",
					"club": "7i"
				}
				_on_launch_monitor_hit_ball(test_data)


func _on_launch_monitor_hit_ball(data: Dictionary) -> void:
	if player == null or player.ball == null:
		return
	if player.ball.state != PhysicsEnums.BallState.REST:
		return

	var speed_val: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var shot_type = str(data.get("ShotType", "")).to_lower()
	if speed_val <= 0.1 or shot_type == "practice":
		return

	FoamBallBoost.apply_boost(data)
	PowerCalibration.apply_calibration(data)

	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")

	shot_in_progress = true
	total_shots += 1
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_shot_started()

	if pvp_mode and not players_list.is_empty():
		var cur_p = players_list[active_player_index % players_list.size()]
		cur_p["shots"] = cur_p.get("shots", 0) + 1

	player._on_tcp_client_hit_ball(data)

	raw_ball_data = data.duplicate()
	_update_stats_display(false)
	_update_hud()

	var speed_mph = data.get("Speed", 0.0)
	var vla = data.get("VLA", 0.0)
	if pvp_mode:
		var cur_name = get_active_player_name()
		_show_banner("%s Shot #%d! Speed: %.1f mph | Loft: %.1f°" % [cur_name, current_shot_in_turn, speed_mph, vla])
	else:
		_show_banner("Shot #%d Fired! Speed: %.1f mph | Loft: %.1f°" % [current_shot_in_turn, speed_mph, vla])


# ========================================
# CAMERA FOLLOW & REST DETECTION
# ========================================

func _physics_process(delta: float) -> void:
	if player and player.ball:
		var ball_state = player.ball.state
		if ball_state == PhysicsEnums.BallState.FLIGHT or ball_state == PhysicsEnums.BallState.ROLLOUT:
			camera_following = true
			var ball_pos = player.ball.global_position
			var target_cam_pos = ball_pos + last_camera_offset
			var cam = get_node_or_null("Camera3D")
			if cam != null:
				cam.global_position = cam.global_position.lerp(target_cam_pos, delta * 8.0)
				cam.look_at(ball_pos + Vector3.UP * 0.1)
		else:
			if camera_following:
				camera_following = false
				if has_node("/root/TensionManager"):
					TensionManager.stop_tension()
				_update_aim_and_camera()
				if has_node("/root/ScreenOffsetManager"):
					ScreenOffsetManager.on_ready_for_shot()


# ========================================
# GAMEPLAY LOOP (3 SHOTS PER PLAYER AT TARGET)
# ========================================

func _on_ball_rest(_shot_data: Dictionary) -> void:
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()

	raw_ball_data = _shot_data.duplicate()
	_update_stats_display(true)

	var final_pos = player.ball.global_position
	var score_result = _calculate_score(final_pos)
	var points = score_result["points"]
	var dist_yards = score_result["distance_yards"]
	var ring_index = score_result["ring_index"]

	total_distance_from_center += dist_yards

	var ring_names = ["BULLSEYE (5 pts)", "RING 2 (4 pts)", "RING 3 (3 pts)", "RING 4 (2 pts)", "RING 5 (1 pt)"]

	if pvp_mode and not players_list.is_empty():
		var cur_p = players_list[active_player_index % players_list.size()]
		var cur_name = cur_p.get("name", "Player %d" % (active_player_index + 1))
		cur_p["points"] = cur_p.get("points", 0) + points
		cur_p["total_distance"] = cur_p.get("total_distance", 0.0) + dist_yards

		if points > 0:
			if sfx_applause_player:
				sfx_applause_player.play()
			GlobalSettings.play_golf_clap()
			_show_banner("🎯 %s scored %d pts on %s! (%.1f yds away) — Shot %d of %d" % [
				cur_name, points, ring_names[ring_index], dist_yards, current_shot_in_turn, SHOTS_PER_TARGET
			])
		else:
			_show_banner("❌ %s missed all rings (%.1f yds away) — Shot %d of %d" % [
				cur_name, dist_yards, current_shot_in_turn, SHOTS_PER_TARGET
			])
	else:
		total_points += points
		if points > 0:
			if sfx_applause_player:
				sfx_applause_player.play()
			GlobalSettings.play_golf_clap()
			_show_banner("🎯 %s! +%d pts (%.1f yds away) — Shot %d of %d" % [
				ring_names[ring_index], points, dist_yards, current_shot_in_turn, SHOTS_PER_TARGET
			])
		else:
			_show_banner("❌ Missed scoring rings (%.1f yds away) — Shot %d of %d" % [
				dist_yards, current_shot_in_turn, SHOTS_PER_TARGET
			])

	_update_hud()

	var reset_delay = maxf(1.0, GlobalSettings.range_settings.ball_reset_timer.value)
	await get_tree().create_timer(reset_delay).timeout

	# ----------------------------------------------------
	# 3-SHOT ROTATION LOGIC:
	# Each player takes 3 shots at the target.
	# Once all players have taken 3 shots at that target,
	# the target moves to a new location!
	# ----------------------------------------------------
	current_shot_in_turn += 1

	if current_shot_in_turn <= SHOTS_PER_TARGET:
		# Same player takes their next shot at the SAME target
		_reset_ball_position()
		var p_name = get_active_player_name() if pvp_mode else "Golfer"
		_show_banner("🎯 %s: Shot %d of %d (Target: %d YDS)" % [p_name, current_shot_in_turn, SHOTS_PER_TARGET, target_distance_yards])
	else:
		# Player finished their 3 shots at this target!
		current_shot_in_turn = 1

		if pvp_mode and pvp_winner == -1:
			active_player_index += 1
			if active_player_index >= players_list.size():
				# All players in the match have completed their 3 shots at this target!
				active_player_index = 0
				current_round += 1

				if current_round > pvp_rounds:
					_determine_pvp_winner()
					_update_hud()
					return

				# Move target to a new random location for the new round!
				_generate_new_target()
				_reset_ball_position()
				_show_banner("🎯 Round %d/%d! New Target: %d YDS — %s's Turn (Shot 1/3)" % [
					current_round, pvp_rounds, target_distance_yards, get_active_player_name()
				])
			else:
				# Next player's turn at the SAME target!
				_reset_ball_position()
				_show_banner("🎯 %s's Turn! Target: %d YDS (Shot 1/3)" % [get_active_player_name(), target_distance_yards])
		else:
			# Single-player mode: took 3 shots at this target -> move target to a new spot!
			_generate_new_target()
			_reset_ball_position()
			_show_banner("🎯 Target Moved! New Target: %d YDS (Shot 1/3)" % target_distance_yards)


func _determine_pvp_winner() -> void:
	var max_points = -1
	var winner_idx = -1
	var is_tie = false

	for i in range(players_list.size()):
		var p_points = players_list[i].get("points", 0)
		if p_points > max_points:
			max_points = p_points
			winner_idx = i
			is_tie = false
		elif p_points == max_points:
			is_tie = true

	# Tiebreaker: lowest total distance from pin
	if is_tie:
		var min_dist = INF
		for i in range(players_list.size()):
			var p_points = players_list[i].get("points", 0)
			if p_points == max_points:
				var p_dist = players_list[i].get("total_distance", INF)
				if p_dist < min_dist:
					min_dist = p_dist
					winner_idx = i

	pvp_winner = winner_idx
	var winner_name = players_list[winner_idx].get("name", "Player %d" % (winner_idx + 1))
	_trigger_victory(winner_name)


# ========================================
# GUI HUD SETUP
# ========================================

func _setup_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1
	add_child(hud_layer)

	hud_control = Control.new()
	hud_control.name = "Control"
	hud_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_control.anchor_right = 1.0
	hud_control.anchor_bottom = 1.0
	hud_control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_control.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_control)

	var glass_style = StyleBoxFlat.new()
	glass_style.bg_color = Color(0.04, 0.08, 0.12, 0.88)
	glass_style.border_width_left = 2
	glass_style.border_width_top = 2
	glass_style.border_width_right = 2
	glass_style.border_width_bottom = 2
	glass_style.border_color = Color(0.24, 0.46, 0.72, 0.5)
	glass_style.corner_radius_top_left = 10
	glass_style.corner_radius_top_right = 10
	glass_style.corner_radius_bottom_right = 10
	glass_style.corner_radius_bottom_left = 10

	# Top Scoreboard Panel
	var score_panel = PanelContainer.new()
	score_panel.custom_minimum_size = Vector2(880, 90)
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.anchor_top = 0.0
	score_panel.anchor_bottom = 0.0
	score_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	score_panel.offset_left = -440
	score_panel.offset_right = 440
	score_panel.offset_top = 18
	score_panel.offset_bottom = 108
	hud_control.add_child(score_panel)
	score_panel.add_theme_stylebox_override("panel", glass_style)

	var score_margin = MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 20)
	score_margin.add_theme_constant_override("margin_right", 20)
	score_panel.add_child(score_margin)

	var score_hbox = HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_margin.add_child(score_hbox)

	# Column 1: Target Distance
	var target_col = VBoxContainer.new()
	target_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(target_col)
	var t_lbl = Label.new()
	t_lbl.text = "TARGET"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 13)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	target_col.add_child(t_lbl)
	target_title_lbl = t_lbl
	target_info_lbl = Label.new()
	target_info_lbl.text = "%d YDS" % target_distance_yards
	target_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_info_lbl.add_theme_font_size_override("font_size", 28)
	target_info_lbl.add_theme_color_override("font_color", Color.WHITE)
	target_col.add_child(target_info_lbl)

	# Column 2: Shot of 3 / Round
	var shot_col = VBoxContainer.new()
	shot_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shot_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(shot_col)
	var sc_lbl = Label.new()
	sc_lbl.text = "SHOT"
	sc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc_lbl.add_theme_font_size_override("font_size", 13)
	sc_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	shot_col.add_child(sc_lbl)
	shot_count_title_lbl = sc_lbl
	shot_count_lbl = Label.new()
	shot_count_lbl.text = "1 of 3"
	shot_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shot_count_lbl.add_theme_font_size_override("font_size", 28)
	shot_count_lbl.add_theme_color_override("font_color", Color.WHITE)
	shot_col.add_child(shot_count_lbl)

	# Column 3: Points
	var points_col = VBoxContainer.new()
	points_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(points_col)
	var p_lbl = Label.new()
	p_lbl.text = "POINTS"
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.add_theme_font_size_override("font_size", 13)
	p_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	points_col.add_child(p_lbl)
	points_title_lbl = p_lbl
	points_lbl = Label.new()
	points_lbl.text = "0"
	points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_lbl.add_theme_font_size_override("font_size", 28)
	points_lbl.add_theme_color_override("font_color", Color.WHITE)
	points_col.add_child(points_lbl)

	# Column 4: Running Total Distance away from center
	var total_col = VBoxContainer.new()
	total_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(total_col)
	var td_lbl = Label.new()
	td_lbl.text = "RUNNING DIST"
	td_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	td_lbl.add_theme_font_size_override("font_size", 13)
	td_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	total_col.add_child(td_lbl)
	total_dist_title_lbl = td_lbl
	total_dist_lbl = Label.new()
	total_dist_lbl.text = "0.0 yds"
	total_dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_dist_lbl.add_theme_font_size_override("font_size", 28)
	total_dist_lbl.add_theme_color_override("font_color", Color.WHITE)
	total_col.add_child(total_dist_lbl)

	# Column 5: Average Distance
	var avg_col = VBoxContainer.new()
	avg_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avg_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(avg_col)
	var a_lbl = Label.new()
	a_lbl.text = "AVG DIST"
	a_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a_lbl.add_theme_font_size_override("font_size", 13)
	a_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	avg_col.add_child(a_lbl)
	avg_dist_title_lbl = a_lbl
	avg_dist_lbl = Label.new()
	avg_dist_lbl.text = "---"
	avg_dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avg_dist_lbl.add_theme_font_size_override("font_size", 28)
	avg_dist_lbl.add_theme_color_override("font_color", Color.WHITE)
	avg_col.add_child(avg_dist_lbl)

	# GridCanvas (Left side, standard shot stats overlay)
	var grid_canvas_script = load("res://UI/grid_canvas.gd")
	if grid_canvas_script != null:
		grid_canvas = Control.new()
		grid_canvas.name = "GridCanvas"
		grid_canvas.set_script(grid_canvas_script)
		grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_control.add_child(grid_canvas)

	# Stats Toggle Button - Bottom-Left Corner
	stats_btn = Button.new()
	stats_btn.name = "StatsButton"
	stats_btn.text = ""
	stats_btn.tooltip_text = "Toggle Stats (Show/Hide)"
	if ResourceLoader.exists("res://assets/images/icons/stats.svg"):
		stats_btn.icon = load("res://assets/images/icons/stats.svg")
	stats_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_btn.custom_minimum_size = Vector2(64, 64)
	_apply_circular_button_style(stats_btn, Color(0.24, 0.46, 0.72, 0.85))
	stats_btn.anchor_left = 0.0
	stats_btn.anchor_right = 0.0
	stats_btn.anchor_top = 1.0
	stats_btn.anchor_bottom = 1.0
	stats_btn.offset_left = 30
	stats_btn.offset_top = -88
	stats_btn.offset_right = 94
	stats_btn.offset_bottom = -24
	stats_btn.pressed.connect(func():
		_toggle_stats_visibility()
	)
	hud_control.add_child(stats_btn)

	# Scoring Legend Panel (Right Side)
	var legend_panel = PanelContainer.new()
	legend_panel.custom_minimum_size = Vector2(210, 290)
	legend_panel.anchor_left = 1.0
	legend_panel.anchor_right = 1.0
	legend_panel.anchor_top = 0.5
	legend_panel.anchor_bottom = 0.5
	legend_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	legend_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	legend_panel.offset_left = -230
	legend_panel.offset_right = -20
	legend_panel.offset_top = -145
	legend_panel.offset_bottom = 145
	hud_control.add_child(legend_panel)
	legend_panel.add_theme_stylebox_override("panel", glass_style)

	var legend_margin = MarginContainer.new()
	legend_margin.add_theme_constant_override("margin_left", 14)
	legend_margin.add_theme_constant_override("margin_right", 14)
	legend_margin.add_theme_constant_override("margin_top", 12)
	legend_margin.add_theme_constant_override("margin_bottom", 12)
	legend_panel.add_child(legend_margin)

	var legend_vbox = VBoxContainer.new()
	legend_vbox.add_theme_constant_override("separation", 6)
	legend_margin.add_child(legend_vbox)

	var legend_title = Label.new()
	legend_title.text = "🎯 TARGET RINGS"
	legend_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_title.add_theme_font_size_override("font_size", 15)
	legend_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	legend_vbox.add_child(legend_title)

	var ring_colors = [
		Color(1.0, 0.18, 0.18),
		Color(1.0, 0.55, 0.10),
		Color(1.0, 0.85, 0.15),
		Color(0.20, 0.90, 0.35),
		Color(0.15, 0.70, 1.00),
	]
	for i in range(RING_COUNT):
		var ring_hbox = HBoxContainer.new()
		ring_hbox.add_theme_constant_override("separation", 8)
		legend_vbox.add_child(ring_hbox)

		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(18, 18)
		color_rect.color = ring_colors[i]
		ring_hbox.add_child(color_rect)

		var ring_lbl = Label.new()
		ring_lbl.text = "%d-%d yds = %d pts" % [i * 3, (i + 1) * 3, RING_POINTS[i]]
		ring_lbl.add_theme_font_size_override("font_size", 13)
		ring_lbl.add_theme_color_override("font_color", Color.WHITE)
		ring_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ring_hbox.add_child(ring_lbl)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	legend_vbox.add_child(sep)

	var rule_lbl = Label.new()
	rule_lbl.text = "3 shots per player\nbefore target moves"
	rule_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	rule_lbl.add_theme_font_size_override("font_size", 12)
	rule_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	legend_vbox.add_child(rule_lbl)

	# Banner
	banner_lbl = Label.new()
	banner_lbl.text = "🎯 Closest to Pin — Take 3 shots at the target! (Shot 1/3)"
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.anchor_left = 0.5
	banner_lbl.anchor_right = 0.5
	banner_lbl.anchor_top = 0.22
	banner_lbl.anchor_bottom = 0.22
	banner_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_lbl.add_theme_font_size_override("font_size", 22)
	banner_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	banner_lbl.add_theme_constant_override("outline_size", 4)
	banner_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_control.add_child(banner_lbl)

	# Bottom Controls Panel
	var ctrl_panel = PanelContainer.new()
	ctrl_panel.custom_minimum_size = Vector2(760, 76)
	ctrl_panel.anchor_left = 0.5
	ctrl_panel.anchor_right = 0.5
	ctrl_panel.anchor_top = 1.0
	ctrl_panel.anchor_bottom = 1.0
	ctrl_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ctrl_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctrl_panel.offset_left = -380
	ctrl_panel.offset_right = 380
	ctrl_panel.offset_top = -94
	ctrl_panel.offset_bottom = -18
	hud_control.add_child(ctrl_panel)
	ctrl_panel.add_theme_stylebox_override("panel", glass_style)

	var ctrl_margin = MarginContainer.new()
	ctrl_margin.add_theme_constant_override("margin_left", 16)
	ctrl_margin.add_theme_constant_override("margin_right", 16)
	ctrl_panel.add_child(ctrl_margin)

	var ctrl_hbox = HBoxContainer.new()
	ctrl_hbox.add_theme_constant_override("separation", 14)
	ctrl_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_margin.add_child(ctrl_hbox)

	mode_toggle_btn = Button.new()
	mode_toggle_btn.text = "⚔️ PvP Mode: OFF"
	mode_toggle_btn.custom_minimum_size = Vector2(165, 52)
	mode_toggle_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(mode_toggle_btn, Color(0.20, 0.25, 0.35), Color(0.28, 0.35, 0.48))
	mode_toggle_btn.pressed.connect(_toggle_pvp_mode)
	ctrl_hbox.add_child(mode_toggle_btn)

	players_btn = Button.new()
	players_btn.text = "👥 Players (%d)" % players_list.size()
	players_btn.custom_minimum_size = Vector2(145, 52)
	players_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(players_btn, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	players_btn.pressed.connect(_open_players_modal)
	players_btn.visible = pvp_mode
	ctrl_hbox.add_child(players_btn)

	var reset_btn = Button.new()
	reset_btn.text = "RESET (R)"
	reset_btn.custom_minimum_size = Vector2(110, 52)
	reset_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(reset_btn, Color(0.48, 0.28, 0.18), Color(0.32, 0.18, 0.12))
	reset_btn.pressed.connect(func():
		if pvp_mode:
			_reset_game()
		else:
			total_points = 0
			total_distance_from_center = 0.0
			total_shots = 0
			current_shot_in_turn = 1
			_generate_new_target()
			_reset_ball_position()
			_show_banner("🎯 Reset! New Target: %d YDS (Shot 1/3)" % target_distance_yards)
	)
	ctrl_hbox.add_child(reset_btn)

	music_toggle_btn = Button.new()
	music_toggle_btn.name = "MusicToggleButton"
	music_toggle_btn.text = ""
	music_toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_toggle_btn.expand_icon = true
	music_toggle_btn.custom_minimum_size = Vector2(52, 52)
	music_toggle_btn.pressed.connect(_toggle_music)
	ctrl_hbox.add_child(music_toggle_btn)

	# Screen Offset Launcher
	var so_ctrl_class = load("res://UI/ScreenOffset/screen_offset_control.gd")
	if so_ctrl_class != null and so_ctrl_class.has_method("create_minigame_launcher"):
		so_ctrl_class.call("create_minigame_launcher", self, ctrl_hbox, Callable(self, "_apply_btn_style"))

	var settings_btn_ctrl = Button.new()
	settings_btn_ctrl.name = "SettingsButton"
	settings_btn_ctrl.text = ""
	settings_btn_ctrl.icon = load("res://Utils/Settings/Gear.png")
	settings_btn_ctrl.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn_ctrl.custom_minimum_size = Vector2(52, 52)
	_apply_btn_style(settings_btn_ctrl, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	settings_btn_ctrl.pressed.connect(_on_settings_pressed)
	ctrl_hbox.add_child(settings_btn_ctrl)

	var exit_btn = Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(96, 52)
	exit_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(exit_btn, Color(0.36, 0.16, 0.16), Color(0.24, 0.12, 0.12))
	exit_btn.pressed.connect(func(): SceneManager.change_scene("res://UI/MiniGamesMenu/minigames_menu.tscn"))
	ctrl_hbox.add_child(exit_btn)

	_update_hud()
	_update_music_button_state()
	GlobalSettings.range_settings.minigame_music_enabled.setting_changed.connect(func(_val): _update_music_button_state())


func _toggle_music() -> void:
	var current = GlobalSettings.range_settings.minigame_music_enabled.value
	GlobalSettings.range_settings.minigame_music_enabled.set_value(not current)
	_update_music_button_state()


func _update_music_button_state() -> void:
	if music_toggle_btn == null:
		return
	var is_enabled: bool = GlobalSettings.range_settings.minigame_music_enabled.value
	if is_enabled:
		if ResourceLoader.exists("res://assets/images/menu/music_on.svg"):
			music_toggle_btn.icon = load("res://assets/images/menu/music_on.svg")
		music_toggle_btn.tooltip_text = "Music: Playing (Click to mute)"
		_apply_btn_style(music_toggle_btn, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	else:
		if ResourceLoader.exists("res://assets/images/menu/music_off.svg"):
			music_toggle_btn.icon = load("res://assets/images/menu/music_off.svg")
		music_toggle_btn.tooltip_text = "Music: Muted (Click to play)"
		_apply_btn_style(music_toggle_btn, Color(0.35, 0.18, 0.18), Color(0.45, 0.25, 0.25))


# ========================================
# UI HELPERS & STATS
# ========================================

func _apply_btn_style(btn: Button, norm_color: Color, hov_color: Color) -> void:
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

	var style_focus = style_hover.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_focus)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	if btn.custom_minimum_size.y < 48:
		btn.custom_minimum_size.y = 48
	if not btn.has_theme_font_size_override("font_size"):
		btn.add_theme_font_size_override("font_size", 16)


func _apply_circular_button_style(btn: Button, bg_color: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 32
	style_normal.corner_radius_top_right = 32
	style_normal.corner_radius_bottom_left = 32
	style_normal.corner_radius_bottom_right = 32
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = bg_color.lightened(0.25)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)
	style_hover.border_color = Color(1.0, 1.0, 1.0, 0.5)

	var style_focus = style_hover.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_focus)


func is_stats_visible() -> bool:
	if grid_canvas == null:
		return true
	var dist_panel = grid_canvas.get_node_or_null("Distance")
	return dist_panel.visible if dist_panel != null else grid_canvas.visible


func _toggle_stats_visibility() -> void:
	var show_stats = not is_stats_visible()
	if grid_canvas != null:
		for child in grid_canvas.get_children():
			if child.name != "ClubSelector":
				child.visible = show_stats
	if stats_btn != null:
		if show_stats:
			_apply_circular_button_style(stats_btn, Color(0.24, 0.46, 0.72, 0.85))
		else:
			_apply_circular_button_style(stats_btn, Color(0.15, 0.15, 0.15, 0.85))


func _update_stats_display(is_final_rest: bool = true) -> void:
	if grid_canvas == null or player == null:
		return
	var units = GlobalSettings.range_settings.range_units.value if has_node("/root/GlobalSettings") else PhysicsEnums.Units.IMPERIAL
	display_data = ShotFormatter.format_ball_display(raw_ball_data, player, units, is_final_rest, display_data)
	var is_imperial: bool = (units == PhysicsEnums.Units.IMPERIAL)

	for child in grid_canvas.get_children():
		if child.name == "ClubSelector":
			continue
		var stat_id = child.name
		var stat_def = StatDefinitions.get_stat_by_id(stat_id)
		if stat_def.is_empty():
			continue
		var u_str: String = str(stat_def.get("units_imperial" if is_imperial else "units_metric", ""))
		if child.has_method("set_units"):
			child.call("set_units", u_str)
		var val = display_data.get(stat_id, "---")
		if stat_id == "VLA" or stat_id == "HLA":
			if val != "---":
				var float_val = float(val)
				val = "%.1f°" % float_val
		if child.has_method("set_data"):
			child.call("set_data", str(val))


func _update_hud() -> void:
	if pvp_mode and not players_list.is_empty():
		var cur_p = players_list[active_player_index % players_list.size()]
		var cur_name = cur_p.get("name", "Player %d" % (active_player_index + 1))
		var cur_col = get_active_player_color()

		if target_title_lbl:
			target_title_lbl.text = "CURRENT TURN"
		if target_info_lbl:
			if pvp_winner != -1:
				var win_name = players_list[pvp_winner]["name"] if pvp_winner < players_list.size() else cur_name
				target_info_lbl.text = "🏆 %s WINS!" % win_name
				target_info_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			else:
				target_info_lbl.text = "%s (P%d)" % [cur_name, active_player_index + 1]
				target_info_lbl.add_theme_color_override("font_color", cur_col)

		if shot_count_title_lbl:
			shot_count_title_lbl.text = "SHOT & ROUND"
		if shot_count_lbl:
			shot_count_lbl.text = "Shot %d/3 · R%d/%d" % [current_shot_in_turn, current_round, pvp_rounds]
			shot_count_lbl.add_theme_font_size_override("font_size", 22)

		if points_title_lbl:
			points_title_lbl.text = "MATCH SCORES"
		if points_lbl:
			var scores_text: Array[String] = []
			for i in range(players_list.size()):
				var p = players_list[i]
				scores_text.append("P%d: %d" % [i + 1, p.get("points", 0)])
			points_lbl.text = " | ".join(scores_text)
			points_lbl.add_theme_color_override("font_color", Color.WHITE)
			if players_list.size() > 3:
				points_lbl.add_theme_font_size_override("font_size", 16)
			else:
				points_lbl.add_theme_font_size_override("font_size", 24)

		if total_dist_title_lbl:
			total_dist_title_lbl.text = "RUNNING DIST"
		if total_dist_lbl:
			total_dist_lbl.text = "%.1f yds" % cur_p.get("total_distance", 0.0)
			total_dist_lbl.add_theme_color_override("font_color", cur_col)

		if avg_dist_title_lbl:
			avg_dist_title_lbl.text = "AVG DIST"
		if avg_dist_lbl:
			var p_shots = cur_p.get("shots", 0)
			var p_dist = cur_p.get("total_distance", 0.0)
			if p_shots > 0:
				avg_dist_lbl.text = "%.1f yds" % (p_dist / float(p_shots))
			else:
				avg_dist_lbl.text = "---"
	else:
		if target_title_lbl:
			target_title_lbl.text = "TARGET"
		if target_info_lbl:
			target_info_lbl.text = "%d YDS" % target_distance_yards
			target_info_lbl.add_theme_color_override("font_color", Color.WHITE)

		if shot_count_title_lbl:
			shot_count_title_lbl.text = "SHOT"
		if shot_count_lbl:
			shot_count_lbl.text = "%d of %d" % [current_shot_in_turn, SHOTS_PER_TARGET]
			shot_count_lbl.add_theme_font_size_override("font_size", 28)

		if points_title_lbl:
			points_title_lbl.text = "POINTS"
		if points_lbl:
			points_lbl.text = str(total_points)
			points_lbl.add_theme_font_size_override("font_size", 28)
			points_lbl.add_theme_color_override("font_color", Color.WHITE)

		if total_dist_title_lbl:
			total_dist_title_lbl.text = "RUNNING DIST"
		if total_dist_lbl:
			total_dist_lbl.text = "%.1f yds" % total_distance_from_center
			total_dist_lbl.add_theme_color_override("font_color", Color.WHITE)

		if avg_dist_title_lbl:
			avg_dist_title_lbl.text = "AVG DIST"
		if avg_dist_lbl:
			if total_shots > 0:
				avg_dist_lbl.text = "%.1f yds" % (total_distance_from_center / float(total_shots))
			else:
				avg_dist_lbl.text = "---"
			avg_dist_lbl.add_theme_color_override("font_color", Color.WHITE)


func _trigger_victory(winner_name: String) -> void:
	if sfx_applause_player:
		sfx_applause_player.play()
	GlobalSettings.play_golf_clap()
	var win_color = get_active_player_color()
	_show_game_over_banner(
		"🎉 %s WINS!" % winner_name.to_upper(),
		"Highest score after %d rounds of Closest to Pin!" % pvp_rounds,
		win_color
	)


func _show_game_over_banner(title: String, subtitle: String, theme_color: Color) -> void:
	_hide_game_over_banner()

	game_over_panel = PanelContainer.new()
	game_over_panel.name = "GameOverBanner"
	game_over_panel.custom_minimum_size = Vector2(660, 320)
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -330
	game_over_panel.offset_right = 330
	game_over_panel.offset_top = -160
	game_over_panel.offset_bottom = 160

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.12, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = theme_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	game_over_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	game_over_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 28)
	t_lbl.add_theme_color_override("font_color", theme_color)
	vbox.add_child(t_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(sub_lbl)

	var stat_lines: Array[String] = []
	for i in range(players_list.size()):
		var p = players_list[i]
		var p_points = p.get("points", 0)
		var p_shots = p.get("shots", 0)
		var p_dist = p.get("total_distance", 0.0)
		var p_avg = (p_dist / float(p_shots)) if p_shots > 0 else 0.0
		stat_lines.append("P%d %s: %d pts | Avg: %.1f yds | %d shots" % [
			i + 1, p.get("name", "Player %d" % (i + 1)), p_points, p_avg, p_shots
		])
	var stats_lbl = Label.new()
	stats_lbl.text = "\n".join(stat_lines)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(stats_lbl)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	var play_again_btn = Button.new()
	play_again_btn.text = "🔄 Play Again (R)"
	play_again_btn.custom_minimum_size = Vector2(160, 46)
	play_again_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(play_again_btn, Color(0.18, 0.44, 0.30), Color(0.24, 0.58, 0.40))
	play_again_btn.pressed.connect(func():
		_hide_game_over_banner()
		_reset_game()
	)
	btn_hbox.add_child(play_again_btn)

	var close_btn = Button.new()
	close_btn.text = "Dismiss"
	close_btn.custom_minimum_size = Vector2(110, 46)
	close_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(close_btn, Color(0.24, 0.30, 0.40), Color(0.32, 0.40, 0.52))
	close_btn.pressed.connect(_hide_game_over_banner)
	btn_hbox.add_child(close_btn)

	if hud_control != null:
		hud_control.add_child(game_over_panel)


func _hide_game_over_banner() -> void:
	if game_over_panel != null and is_instance_valid(game_over_panel):
		game_over_panel.queue_free()
		game_over_panel = null


func _show_banner(text: String) -> void:
	if banner_lbl:
		banner_lbl.text = text


func _on_settings_pressed() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		return

	var settings_scene = load("res://UI/Settings/RangeSettings/range_settings.tscn")
	if settings_scene == null:
		return

	if hud_layer != null and is_instance_valid(hud_layer):
		hud_layer.visible = false

	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsLayer"
	_settings_layer.layer = 105
	add_child(_settings_layer)

	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.04, 0.07, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_layer.add_child(backdrop)

	var margin_container = MarginContainer.new()
	margin_container.name = "MarginContainer"
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.anchor_right = 1.0
	margin_container.anchor_bottom = 1.0
	margin_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	margin_container.add_theme_constant_override("margin_left", 36)
	margin_container.add_theme_constant_override("margin_right", 36)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_layer.add_child(margin_container)

	var inst = settings_scene.instantiate()
	inst.name = "MinigameSettings"
	inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(inst)

	inst.close_settings_requested.connect(_close_settings)
	if inst.has_signal("manage_players_requested"):
		inst.manage_players_requested.connect(func():
			_close_settings()
			SceneManager.change_scene("res://UI/PlayersMenu/players_menu.tscn")
		)


func _close_settings() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		_settings_layer.visible = false
		_settings_layer.queue_free()
		_settings_layer = null

	if hud_layer != null and is_instance_valid(hud_layer):
		hud_layer.visible = true

	if has_node("/root/LaunchMonitorManager"):
		var launch_monitor = get_node("/root/LaunchMonitorManager")
		if launch_monitor != null and launch_monitor.has_method("_update_hud_display"):
			launch_monitor.call("_update_hud_display")


func _exit_tree() -> void:
	if has_node("/root/ScreenOffsetManager") and has_node("Camera3D"):
		ScreenOffsetManager.unregister_camera($Camera3D)
