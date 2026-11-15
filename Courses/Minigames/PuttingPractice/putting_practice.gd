extends Node3D

# Preloaded assets
var PlayerScene = preload("res://Player/player.tscn")
const FlagBuilder = preload("res://Courses/Range/flag_builder.gd")

# Minigame state variables
var player = null
var selected_hole_index = 0
var last_putt_start_pos = Vector3.ZERO
var last_putt_target_hole = Vector3.ZERO
var show_green_grid: bool = false

# Stats counters
var stats_attempts = 0
var stats_within_10 = 0
var stats_within_5 = 0
var stats_made = 0
var stats_attempts_25_plus = 0

# Camera follow state
var last_camera_offset = Vector3.ZERO
var camera_following = false
var is_dragging = false

# Green grid sampling bounds: covering kidney bean green span (approx. 48m x 48m)
var green_min_x = -24.0
var green_max_x = 24.0
var green_min_z = -24.0
var green_max_z = 24.0

# Hole configurations (5, 10, 15, 20, 25, 30, 40, 50 feet from starting spot)
var hole_data = [
	{"dist_ft": 5, "angle_deg": -45.0, "desc": "Short Warmup"},
	{"dist_ft": 10, "angle_deg": 135.0, "desc": "Pressure Putt"},
	{"dist_ft": 15, "angle_deg": -120.0, "desc": "Mid-Short Break"},
	{"dist_ft": 20, "angle_deg": 30.0, "desc": "Mid Downhill"},
	{"dist_ft": 25, "angle_deg": -75.0, "desc": "Mid-Long Ridge"},
	{"dist_ft": 30, "angle_deg": 105.0, "desc": "Long Slope"},
	{"dist_ft": 40, "angle_deg": -105.0, "desc": "Lag Cross-Slope"},
	{"dist_ft": 50, "angle_deg": 50.0, "desc": "Long Distance Lag"},
]
var holes = []
var cup_radius: float = 0.054
var hole_buttons = []
var shot_counter: int = 0

# UI elements
var stat_columns: Array[Dictionary] = []
var attempts_val_lbl = null
var within_10_val_lbl = null
var within_5_val_lbl = null
var made_val_lbl = null
var dist_25_val_lbl = null
var banner_lbl = null
var grid_toggle_btn = null
var putting_cam_btn: Button = null
var putting_cam_widget = null
var music_toggle_btn = null
var stats_btn = null
var mode_toggle_btn: Button = null
var green_speed_btn: Button = null
var green_speed_popup: PanelContainer = null
var green_speed_slider: HSlider = null
var green_speed_val_lbl: Label = null
var game_over_panel: PanelContainer = null
var grid_canvas = null
var hud_layer: CanvasLayer = null
var hud_control: Control = null
var _settings_layer: CanvasLayer = null
var raw_ball_data: Dictionary = {}
var display_data: Dictionary = {}
var sfx_applause_player: AudioStreamPlayer = null
var user_aim_yaw_offset_deg: float = 0.0
var _was_aiming_putting: bool = false

# PvP Mode State
const MinigamePlayerModal = preload("res://Courses/Minigames/minigame_player_modal.gd")
var pvp_mode: bool = false
var active_player_index: int = 0
var players_list: Array[Dictionary] = []
var p1_name: String = "Player 1"
var p2_name: String = "Player 2"
var p1_completed: Array[bool] = [false, false, false, false, false, false, false, false]
var p2_completed: Array[bool] = [false, false, false, false, false, false, false, false]
var p1_shots: int = 0
var p2_shots: int = 0
var pvp_winner: int = -1 # -1: in play, >=0: winner index
var shot_in_progress: bool = false
var players_btn: Button = null
var _player_modal_instance: CanvasLayer = null

const P1_COLOR = Color(0.2, 0.9, 1.0) # Neon Cyan
const P2_COLOR = Color(1.0, 0.75, 0.25) # Radiant Amber/Gold

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

func _ready() -> void:
	name = "PuttingPractice"
	GlobalSettings.is_putting_minigame = true
	_init_player_names()
	
	sfx_applause_player = AudioStreamPlayer.new()
	sfx_applause_player.name = "ApplausePlayer"
	if ResourceLoader.exists("res://assets/audio/golf_clap.mp3"):
		sfx_applause_player.stream = load("res://assets/audio/golf_clap.mp3")
	sfx_applause_player.volume_db = 3.0
	add_child(sfx_applause_player)
	
	# 1. Environment Setup
	_setup_environment()


	# 2. Generate Kidney-Bean Green & Rough Terrain
	_generate_green_and_rough_terrain()
	_generate_green_grid_and_heatmap()
	
	# 3. Generate Surrounding Environment (Trees & Bushes)
	_generate_trees()
	var q = GlobalSettings.get_graphics_quality() if GlobalSettings != null else "High"
	MobilePerformance.apply_graphics_quality(self, q)
	
	# 4. Setup Player
	_setup_player()
	
	# 5. Setup Target Holes
	_setup_holes()
	
	# 6. Setup GUI
	_setup_ui()
	
	# Select first hole by default
	_select_hole(0)

	if has_node("/root/GlobalSettings") and GlobalSettings.range_settings.putting_camera_enabled.value:
		_setup_putting_camera()
		if putting_cam_widget != null:
			putting_cam_widget.set_camera_active(true)
		_update_putting_cam_button_label()
	
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected"):
			eb.club_selected.emit("Pt")
	
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
		players_list = MinigamePlayerModal.init_default_players(8)
	if players_list.size() < 2:
		var p2 = MinigamePlayerModal.create_player("Player 2", 1, 8)
		players_list.append(p2)
	p1_name = players_list[0].get("name", "Player 1")
	p2_name = players_list[1].get("name", "Player 2") if players_list.size() > 1 else "Player 2"
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
	pvp_winner = -1
	p1_shots = 0
	p2_shots = 0
	stats_attempts = 0
	stats_within_10 = 0
	stats_within_5 = 0
	stats_made = 0
	stats_attempts_25_plus = 0
	for p in players_list:
		p["shots"] = 0
		if not p.has("completed") or p["completed"].size() != 8:
			var c_arr: Array[bool] = []
			for k in range(8):
				c_arr.append(false)
			p["completed"] = c_arr
		else:
			for k in range(8):
				p["completed"][k] = false
	if players_list.size() > 0:
		p1_completed = players_list[0]["completed"]
	if players_list.size() > 1:
		p2_completed = players_list[1]["completed"]
	_select_hole(0, true)
	_update_hud()
	_update_hole_button_labels()
	_update_players_button_label()


func _get_next_uncompleted_hole(player_idx: int) -> int:
	if player_idx < 0 or player_idx >= players_list.size():
		return selected_hole_index
	var completed = players_list[player_idx].get("completed", [])
	for i in range(completed.size()):
		if not completed[i]:
			return i
	return selected_hole_index


func _open_players_modal() -> void:
	if _player_modal_instance != null and is_instance_valid(_player_modal_instance):
		_player_modal_instance.queue_free()
		_player_modal_instance = null
		
	var modal = MinigamePlayerModal.new()
	modal.name = "MinigamePlayerModal"
	add_child(modal)
	_player_modal_instance = modal
	modal.open(players_list, 2, 8, active_player_index)
	modal.players_changed.connect(func(new_players):
		players_list = new_players
		if active_player_index >= players_list.size():
			active_player_index = 0
		p1_name = players_list[0].get("name", "Player 1")
		p2_name = players_list[1].get("name", "Player 2") if players_list.size() > 1 else "Player 2"
		if players_list.size() > 0:
			p1_completed = players_list[0]["completed"]
		if players_list.size() > 1:
			p2_completed = players_list[1]["completed"]
		_update_players_button_label()
		_update_hole_button_labels()
		_update_flagpole_color()
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


func _update_flagpole_color() -> void:
	if not has_node("FlagPin"):
		return
	var pin = get_node("FlagPin")
	var flag = pin.get_node_or_null("Flag")
	var ring = pin.get_node_or_null("TargetRing")
	var active_col = get_active_player_color() if pvp_mode else Color(1.0, 0.1, 0.1)
	if flag != null:
		if flag.has_method("set_flag_color"):
			flag.set_flag_color(active_col)
		elif "flag_color" in flag:
			flag.set("flag_color", active_col)
		elif flag.material_override is StandardMaterial3D:
			flag.material_override.albedo_color = active_col
			flag.material_override.emission = active_col
	if ring and ring.material_override is StandardMaterial3D:
		var ring_col = get_active_player_color() if pvp_mode else Color(0.0, 0.8, 1.0)
		ring.material_override.albedo_color = Color(ring_col.r, ring_col.g, ring_col.b, 0.5)

# ----------------- ENVIRONMENT SETUP -----------------

func _setup_environment() -> void:
	var is_mobile := MobilePerformance.is_mobile()

	# Add DirectionalLight3D
	var sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-50)).rotated(Vector3.UP, deg_to_rad(45))
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	sun.directional_shadow_max_distance = 200.0
	if is_mobile:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_split_1 = 0.1
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_split_1 = 0.08
		sun.directional_shadow_split_2 = 0.20
		sun.directional_shadow_split_3 = 0.50
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	
	# WorldEnvironment with a procedural sky
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if is_mobile else Sky.RADIANCE_SIZE_256
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.55, 0.88)
	sky_mat.sky_horizon_color = Color(0.60, 0.78, 0.92)
	sky_mat.ground_bottom_color = Color(0.16, 0.28, 0.18)
	sky_mat.ground_horizon_color = Color(0.60, 0.78, 0.92)
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
		env.ssao_detail = 0.2
		env.ssao_horizon = 0.05
		env.ssao_ao_channel_affect = 0.5
	
	world_env.environment = env
	add_child(world_env)
	
	# Create Camera3D
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.cull_mask = camera.cull_mask & ~2
	camera.current = true
	add_child(camera)
	if has_node("/root/TensionManager"):
		TensionManager.register_camera(camera, 55.0)
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.register_camera(camera)
		ScreenOffsetManager.set_putter_active(true)
		ScreenOffsetManager.on_ready_for_shot(0.0, true)

# ----------------- PROCEDURAL TERRAIN -----------------

func get_height(x: float, z: float) -> float:
	var base_slope = 0.0
	var undulation = 0.025 * sin(x * 0.28) + 0.020 * sin(z * 0.22) + 0.010 * sin(x * 0.18 - z * 0.18)
	var dist_from_center = Vector2(x, z).length()
	var outer_mound = 0.0
	if dist_from_center > 21.0:
		var factor = (dist_from_center - 21.0) * 0.05
		outer_mound = sin(x * 0.15 + z * 0.15) * 0.15 * factor
		
	return base_slope + undulation + outer_mound

func clamp_camera_position(pos: Vector3, min_clearance: float = 0.35) -> Vector3:
	var terrain_h = get_height(pos.x, pos.z)
	if pos.y < terrain_h + min_clearance:
		pos.y = terrain_h + min_clearance
	return pos

func get_green_radius(angle: float) -> float:
	var r = 18.0
	# North-South elongation
	r += 3.5 * sin(angle - 0.1)
	# Dual lobe structure
	r -= 2.0 * cos(2.0 * (angle - 0.1))
	# Southeast bulge for 50 ft hole
	r += 2.5 * exp(- pow(angle - 0.87, 2) / 0.8)
	# West side kidney notch
	var notch_angle = angle - 2.8 if angle > 0 else angle + 2.8
	var notch = 3.5 * exp(- (notch_angle * notch_angle) / 0.6)
	r -= notch
	return r

func is_inside_green(x: float, z: float) -> bool:
	var rel = Vector2(x, z)
	var dist = rel.length()
	if dist < 0.001:
		return true
	return dist <= get_green_radius(rel.angle())

func _generate_green_and_rough_terrain() -> void:
	var st_green = SurfaceTool.new()
	st_green.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat_green = StandardMaterial3D.new()
	mat_green.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
	mat_green.roughness = 0.95
	mat_green.metallic_specular = 0.1
	st_green.set_material(mat_green)
	
	var st_rough = SurfaceTool.new()
	st_rough.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat_rough = StandardMaterial3D.new()
	mat_rough.albedo_texture = load("res://Courses/Environments/grass-rough/albedo.png")
	mat_rough.roughness = 0.95
	mat_rough.metallic_specular = 0.05
	st_rough.set_material(mat_rough)
	
	var min_grid = -24.0
	var max_grid = 24.0
	var subdiv = 120 # 0.4m grid resolution for ultra-smooth kidney bean boundary
	var step = (max_grid - min_grid) / float(subdiv)
	
	var add_poly = func(st: SurfaceTool, poly_pts: Array, uv_scale: float):
		if poly_pts.size() < 3:
			return
		var p0 = poly_pts[0]
		for i in range(1, poly_pts.size() - 1):
			var p1 = poly_pts[i]
			var p2 = poly_pts[i + 1]
			
			var v0 = Vector3(p0.x, get_height(p0.x, p0.y), p0.y)
			var v1 = Vector3(p1.x, get_height(p1.x, p1.y), p1.y)
			var v2 = Vector3(p2.x, get_height(p2.x, p2.y), p2.y)
			
			st.set_uv(Vector2(v0.x, v0.z) * uv_scale)
			st.add_vertex(v0)
			st.set_uv(Vector2(v1.x, v1.z) * uv_scale)
			st.add_vertex(v1)
			st.set_uv(Vector2(v2.x, v2.z) * uv_scale)
			st.add_vertex(v2)
			
	for iz in range(subdiv):
		for ix in range(subdiv):
			var x0 = min_grid + ix * step
			var x1 = x0 + step
			var z0 = min_grid + iz * step
			var z1 = z0 + step
			
			var corners = [
				Vector2(x0, z0),
				Vector2(x1, z0),
				Vector2(x1, z1),
				Vector2(x0, z1)
			]
			
			var val = []
			for c in corners:
				var dist = c.length()
				var r_bound = get_green_radius(c.angle()) if dist >= 0.001 else 15.0
				val.append(r_bound - dist)
				
			var g_pts = []
			var r_pts = []
			
			for i in range(4):
				var curr_c = corners[i]
				var curr_v = val[i]
				var next_i = (i + 1) % 4
				var next_c = corners[next_i]
				var next_v = val[next_i]
				
				if curr_v >= 0.0:
					g_pts.append(curr_c)
				else:
					r_pts.append(curr_c)
					
				if (curr_v > 0.0 and next_v < 0.0) or (curr_v < 0.0 and next_v > 0.0):
					var t = curr_v / (curr_v - next_v)
					var inter = curr_c.lerp(next_c, t)
					g_pts.append(inter)
					r_pts.append(inter)
					
			add_poly.call(st_green, g_pts, 0.3)
			add_poly.call(st_rough, r_pts, 0.25)
			
	# Surrounding outer rough terrain out to 90x90m (-45 to +45)
	var outer_sections = [
		{"min_x": -45.0, "max_x": 45.0, "min_z": -45.0, "max_z": min_grid, "div_x": 30, "div_z": 15},
		{"min_x": -45.0, "max_x": 45.0, "min_z": max_grid, "max_z": 45.0, "div_x": 30, "div_z": 15},
		{"min_x": -45.0, "max_x": min_grid, "min_z": min_grid, "max_z": max_grid, "div_x": 15, "div_z": 30},
		{"min_x": max_grid, "max_x": 45.0, "min_z": min_grid, "max_z": max_grid, "div_x": 15, "div_z": 30},
	]
	
	for sec in outer_sections:
		var cell_w = (sec["max_x"] - sec["min_x"]) / sec["div_x"]
		var cell_d = (sec["max_z"] - sec["min_z"]) / sec["div_z"]
		
		for z in range(sec["div_z"]):
			for x in range(sec["div_x"]):
				var x0 = sec["min_x"] + x * cell_w
				var x1 = x0 + cell_w
				var z0 = sec["min_z"] + z * cell_d
				var z1 = z0 + cell_d
				
				var p00 = Vector3(x0, get_height(x0, z0), z0)
				var p10 = Vector3(x1, get_height(x1, z0), z0)
				var p01 = Vector3(x0, get_height(x0, z1), z1)
				var p11 = Vector3(x1, get_height(x1, z1), z1)
				
				st_rough.set_uv(Vector2(x0, z0) * 0.25)
				st_rough.add_vertex(p00)
				st_rough.set_uv(Vector2(x1, z0) * 0.25)
				st_rough.add_vertex(p10)
				st_rough.set_uv(Vector2(x0, z1) * 0.25)
				st_rough.add_vertex(p01)
				
				st_rough.set_uv(Vector2(x1, z0) * 0.25)
				st_rough.add_vertex(p10)
				st_rough.set_uv(Vector2(x1, z1) * 0.25)
				st_rough.add_vertex(p11)
				st_rough.set_uv(Vector2(x0, z1) * 0.25)
				st_rough.add_vertex(p01)
				
	st_green.generate_normals()
	var mesh_green = st_green.commit()
	var mi_green = MeshInstance3D.new()
	mi_green.mesh = mesh_green
	mi_green.name = "PuttingGreenMesh"
	add_child(mi_green)
	
	var sb_green = StaticBody3D.new()
	sb_green.name = "PuttingGreen"
	sb_green.set_meta("surface_type", 4) # GREEN
	mi_green.add_child(sb_green)
	
	var cs_green = CollisionShape3D.new()
	cs_green.shape = mesh_green.create_trimesh_shape()
	sb_green.add_child(cs_green)
	
	st_rough.generate_normals()
	var mesh_rough = st_rough.commit()
	var mi_rough = MeshInstance3D.new()
	mi_rough.mesh = mesh_rough
	mi_rough.name = "PuttingRoughMesh"
	add_child(mi_rough)
	
	var sb_rough = StaticBody3D.new()
	sb_rough.name = "PuttingRough"
	sb_rough.set_meta("surface_type", 2) # ROUGH
	mi_rough.add_child(sb_rough)
	
	var cs_rough = CollisionShape3D.new()
	cs_rough.shape = mesh_rough.create_trimesh_shape()
	sb_rough.add_child(cs_rough)


func _generate_trees() -> void:
	var tree_paths = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-3-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-4-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-3-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-4-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-3-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-4-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-birch-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-pine-1-staticbody.tscn",
	]
	
	var trees_folder = Node3D.new()
	trees_folder.name = "TreesFolder"
	add_child(trees_folder)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	
	var total_trees = 40
	var spawned = 0
	var attempts = 0
	
	while spawned < total_trees and attempts < 250:
		attempts += 1
		var angle = rng.randf_range(0.0, TAU)
		var min_tree_dist = max(get_green_radius(angle) + 2.0, 20.0)
		var dist = rng.randf_range(min_tree_dist, 44.0)
		
		var tx = cos(angle) * dist
		var tz = sin(angle) * dist
		var ty = get_height(tx, tz)
		
		var path_idx = rng.randi_range(0, tree_paths.size() - 1)
		var scene = load(tree_paths[path_idx])
		if scene:
			var tree_inst = scene.instantiate()
			tree_inst.name = "Tree_%d" % spawned
			tree_inst.position = Vector3(tx, ty - 0.15, tz)
			
			var s = rng.randf_range(2.2, 4.2)
			tree_inst.scale = Vector3(s, s, s)
			tree_inst.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)
			
			trees_folder.add_child(tree_inst)
			spawned += 1

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

# ----------------- SLOPE GRID & HEATMAP SYSTEM -----------------

func _generate_green_grid_and_heatmap() -> void:
	for n_name in ["GreenHeatmapMesh", "GreenGridMesh", "GreenDotsMesh"]:
		var node = get_node_or_null(n_name)
		if node:
			remove_child(node)
			node.queue_free()
			
	var spacing = 1.0 # 1 meter cell grid
	var ix_start = int(floor(green_min_x / spacing))
	var ix_end = int(ceil(green_max_x / spacing)) - 1
	var iz_start = int(floor(green_min_z / spacing))
	var iz_end = int(ceil(green_max_z / spacing)) - 1
	
	var min_y = 99999.0
	var max_y = -99999.0
	
	# Sample height range for heatmap normalization
	for iz in range(iz_start, iz_end + 1):
		for ix in range(ix_start, ix_end + 1):
			var gx = (ix + 0.5) * spacing
			var gz = (iz + 0.5) * spacing
			var hy = get_height(gx, gz)
			if hy < min_y: min_y = hy
			if hy > max_y: max_y = hy
			
	if max_y - min_y < 0.001:
		max_y = min_y + 1.0
		
	var st_heatmap = SurfaceTool.new()
	st_heatmap.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var st_grid = SurfaceTool.new()
	st_grid.begin(Mesh.PRIMITIVE_LINES)
	
	var heatmap_y_offset = 0.002
	var grid_y_offset = 0.004
	var dot_y_offset = 0.006
	
	var height_cache = {}
	var get_cached_height = func(gx: float, gz: float) -> float:
		var key = Vector2(gx, gz)
		if not height_cache.has(key):
			height_cache[key] = get_height(gx, gz)
		return height_cache[key]
		
	for iz in range(iz_start, iz_end + 1):
		for ix in range(ix_start, ix_end + 1):
			var x0 = ix * spacing
			var x1 = (ix + 1) * spacing
			var z0 = iz * spacing
			var z1 = (iz + 1) * spacing
			
			var center_x = (x0 + x1) * 0.5
			var center_z = (z0 + z1) * 0.5
			if not is_inside_green(center_x, center_z):
				continue
				
			var y00 = get_cached_height.call(x0, z0)
			var y10 = get_cached_height.call(x1, z0)
			var y11 = get_cached_height.call(x1, z1)
			var y01 = get_cached_height.call(x0, z1)
			
			var h00 = Vector3(x0, y00 + heatmap_y_offset, z0)
			var h10 = Vector3(x1, y10 + heatmap_y_offset, z0)
			var h11 = Vector3(x1, y11 + heatmap_y_offset, z1)
			var h01 = Vector3(x0, y01 + heatmap_y_offset, z1)
			
			var col00 = _get_heatmap_color(clamp((y00 - min_y) / (max_y - min_y), 0.0, 1.0))
			var col10 = _get_heatmap_color(clamp((y10 - min_y) / (max_y - min_y), 0.0, 1.0))
			var col11 = _get_heatmap_color(clamp((y11 - min_y) / (max_y - min_y), 0.0, 1.0))
			var col01 = _get_heatmap_color(clamp((y01 - min_y) / (max_y - min_y), 0.0, 1.0))
			
			# Heatmap Tri 1
			st_heatmap.set_color(col00)
			st_heatmap.add_vertex(h00)
			st_heatmap.set_color(col10)
			st_heatmap.add_vertex(h10)
			st_heatmap.set_color(col11)
			st_heatmap.add_vertex(h11)
			
			# Heatmap Tri 2
			st_heatmap.set_color(col00)
			st_heatmap.add_vertex(h00)
			st_heatmap.set_color(col11)
			st_heatmap.add_vertex(h11)
			st_heatmap.set_color(col01)
			st_heatmap.add_vertex(h01)
			
	# Collect edges for slope flow arrows and grid lines
	var h_edges = {}
	var v_edges = {}
	for iz in range(iz_start, iz_end + 1):
		for ix in range(ix_start, ix_end + 1):
			if is_inside_green((ix + 0.5) * spacing, (iz + 0.5) * spacing):
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
			
	var dots_data = []
	
	# Horizontal edges (slope arrows)
	for edge in h_edges.keys():
		var x0 = edge.x * spacing
		var z0 = edge.y * spacing
		var x1 = (edge.x + 1) * spacing
		var z1 = edge.y * spacing
		
		if not is_inside_green(x0, z0) or not is_inside_green(x1, z1):
			continue
		
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
				
	# Vertical edges (slope arrows)
	for edge in v_edges.keys():
		var x0 = edge.x * spacing
		var z0 = edge.y * spacing
		var x1 = edge.x * spacing
		var z1 = (edge.y + 1) * spacing
		
		if not is_inside_green(x0, z0) or not is_inside_green(x1, z1):
			continue
		
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
				
	# Commit Heatmap Mesh (hidden by default to match regular course play)
	var heatmap_mesh = st_heatmap.commit()
	var heatmap_mi = MeshInstance3D.new()
	heatmap_mi.name = "GreenHeatmapMesh"
	heatmap_mi.mesh = heatmap_mesh
	var mat_hm = StandardMaterial3D.new()
	mat_hm.vertex_color_use_as_albedo = true
	mat_hm.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_hm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat_hm.render_priority = 0
	heatmap_mi.material_override = mat_hm
	heatmap_mi.layers = 2
	heatmap_mi.visible = false
	add_child(heatmap_mi)
	
	# Commit Grid Mesh
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
	grid_mi.visible = show_green_grid
	add_child(grid_mi)
	
	# Commit Moving Slope Arrows MultiMesh
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
	
	vec4 world_offset = vec4(displacement * progress, 0.0);
	vec4 local_offset = inverse(MODEL_MATRIX) * world_offset;
	VERTEX += local_offset.xyz;
	
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
	dots_mi.visible = show_green_grid
	add_child(dots_mi)

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
	color.a = 0.45
	return color

func _toggle_green_grid() -> void:
	show_green_grid = not show_green_grid
	_update_green_grid_visibility()
	_update_grid_button_state()

func _update_green_grid_visibility() -> void:
	var heatmap_node = get_node_or_null("GreenHeatmapMesh")
	var grid_node = get_node_or_null("GreenGridMesh")
	var dots_node = get_node_or_null("GreenDotsMesh")
	
	if heatmap_node:
		heatmap_node.visible = show_green_grid
	if grid_node:
		grid_node.visible = show_green_grid
	if dots_node:
		dots_node.visible = show_green_grid

func _update_grid_button_state() -> void:
	if grid_toggle_btn:
		if show_green_grid:
			grid_toggle_btn.text = "📊 Grid: ON"
			_apply_btn_style(grid_toggle_btn, Color(0.18, 0.48, 0.28), Color(0.24, 0.60, 0.36))
		else:
			grid_toggle_btn.text = "📊 Grid: OFF"
			_apply_btn_style(grid_toggle_btn, Color(0.25, 0.25, 0.25), Color(0.35, 0.35, 0.35))


func _toggle_putting_camera() -> void:
	if putting_cam_widget == null:
		_setup_putting_camera()
	var new_active = not putting_cam_widget.is_camera_active()
	putting_cam_widget.set_camera_active(new_active)
	if has_node("/root/GlobalSettings"):
		GlobalSettings.range_settings.putting_camera_enabled.set_value(new_active)
		GlobalSettings.save_settings()
	_update_putting_cam_button_label()


func _update_putting_cam_button_label() -> void:
	if putting_cam_btn == null:
		return
	var is_act = putting_cam_widget != null and putting_cam_widget.is_camera_active()
	putting_cam_btn.text = "🎯 Putting Cam: ON" if is_act else "🎯 Putting Cam: OFF"
	if is_act:
		_apply_btn_style(putting_cam_btn, Color(0.14, 0.45, 0.65), Color(0.20, 0.58, 0.82))
	else:
		_apply_btn_style(putting_cam_btn, Color(0.20, 0.25, 0.35), Color(0.28, 0.35, 0.48))


func _setup_putting_camera() -> void:
	if putting_cam_widget != null:
		return
	var widget_script = load("res://UI/PuttingCamera/putting_camera_widget.gd")
	if widget_script != null:
		putting_cam_widget = widget_script.new()
		putting_cam_widget.name = "PuttingCameraWidget"
		hud_control.add_child(putting_cam_widget)
		if putting_cam_widget.has_method("set_panel_position"):
			putting_cam_widget.set_panel_position(Vector2(20, 20))
		if putting_cam_widget.has_method("set_panel_size"):
			putting_cam_widget.set_panel_size(Vector2(320, 325))
		putting_cam_widget.putt_detected.connect(_on_launch_monitor_hit_ball)

# ----------------- PLAYER SETUP -----------------

func _setup_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	var start_pos = Vector3(0.0, get_height(0.0, 0.0) + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET, 0.0)
	player.global_position = start_pos
	
	# Disable default process update
	player.set_process(false)
	
	# Connect to ball rest signal to handle scoring
	player.rest.connect(_on_ball_rest)
	
	# Initialize spawn position
	player.ball.spawn_position = start_pos
	player.ball.lie_type = "green"
	player.ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	player.set_profile(get_active_player_name())
	player.ball.reset()

# ----------------- TARGET HOLES -----------------

func _setup_holes() -> void:
	holes.clear()
	for i in range(hole_data.size()):
		var data = hole_data[i]
		var dist_m = data["dist_ft"] * 0.3048
		var rad = deg_to_rad(data["angle_deg"])
		var h_x = dist_m * cos(rad)
		var h_z = dist_m * sin(rad)
		var h_y = get_height(h_x, h_z)
		var hole_pos = Vector3(h_x, h_y, h_z)
		holes.append(hole_pos)
		
		# Spawn physical recessed 3D golf cup matching course play
		var cup_root = Node3D.new()
		cup_root.name = "CupMarker_%d" % i
		cup_root.position = hole_pos
		FlagBuilder.build_hole_cup(cup_root, cup_radius)
		add_child(cup_root)

	# Cut out circular openings in the putting green surface for all recessed cups
	var green_mesh_inst = get_node_or_null("PuttingGreenMesh") as MeshInstance3D
	if green_mesh_inst != null:
		FlagBuilder.apply_green_hole_cutout_material(green_mesh_inst, holes, cup_radius)

func _select_hole(index: int, reset_ball: bool = true) -> void:
	if index < 0 or index >= holes.size():
		return
	selected_hole_index = index
	user_aim_yaw_offset_deg = 0.0
		
	# Draw/Reposition flagpole
	_spawn_flagpole(holes[index])
	
	if reset_ball:
		_reset_ball_position()
	else:
		_update_aim_and_camera()
		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.on_ready_for_shot()
		_update_hole_button_labels()
	
	if pvp_mode:
		var cur_name = get_active_player_name()
		_show_banner("🎯 %s's Target: Hole %d (%d ft)" % [cur_name, index + 1, hole_data[index]["dist_ft"]])
	else:
		_show_banner("Target Hole %d (%d ft) Selected! Hit with Launch Monitor." % [index + 1, hole_data[index]["dist_ft"]])
	
	# Update active button visuals & distances
	_update_hole_button_labels()
	_update_hud()

func _update_hole_button_labels() -> void:
	for i in range(holes.size()):
		if i < hole_buttons.size():
			var dist_ft = hole_data[i]["dist_ft"]
			var is_selected = (i == selected_hole_index)
			if pvp_mode:
				var marks: Array[String] = []
				for p in players_list:
					var is_done = false
					if p.has("completed") and i < p["completed"].size():
						is_done = p["completed"][i]
					marks.append("✓" if is_done else "○")
				var prefix = "▶ " if is_selected else "  "
				var marks_str = "|".join(marks)
				hole_buttons[i].text = "%s%d ft [%s]" % [prefix, dist_ft, marks_str]
				if is_selected:
					var active_col = get_active_player_color()
					hole_buttons[i].add_theme_color_override("font_color", active_col)
					_apply_btn_style(hole_buttons[i], Color(0.18, 0.38, 0.55), Color(0.24, 0.48, 0.70))
				else:
					hole_buttons[i].remove_theme_color_override("font_color")
					_apply_btn_style(hole_buttons[i], Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))
			else:
				if is_selected:
					hole_buttons[i].text = "Hole %d (%d ft) ▶" % [i + 1, dist_ft]
					hole_buttons[i].add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
					_apply_btn_style(hole_buttons[i], Color(0.18, 0.38, 0.55), Color(0.24, 0.48, 0.70))
				else:
					hole_buttons[i].text = "Hole %d (%d ft)" % [i + 1, dist_ft]
					hole_buttons[i].remove_theme_color_override("font_color")
					_apply_btn_style(hole_buttons[i], Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))

func _spawn_flagpole(pos: Vector3) -> void:
	if has_node("FlagPin"):
		get_node("FlagPin").queue_free()
		
	var pin = Node3D.new()
	pin.name = "FlagPin"
	pin.set_meta("cup_radius", cup_radius)
	add_child(pin)
	pin.global_position = pos
	
	var flag_col = get_active_player_color() if pvp_mode else Color(1.0, 0.1, 0.1)
	var q_str = ""
	var gs = GlobalSettings if GlobalSettings != null else (get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null)
	if gs != null and gs.has_method("get_graphics_quality"):
		q_str = gs.get_graphics_quality()
	FlagBuilder.setup_target_flag(pin, 2.0, flag_col, 0.42, 0.30, false, q_str)
	
	# Glow/Selection Ring (hollow ring around cup so the open hole cup is unobstructed)
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = cup_radius + 0.015
	ring_mesh.outer_radius = 0.5
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.scale = Vector3(1.0, 0.01, 1.0)
	ring.name = "TargetRing"
	
	var ring_col = get_active_player_color() if pvp_mode else Color(0.0, 0.8, 1.0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(ring_col.r, ring_col.g, ring_col.b, 0.5)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	ring.position = Vector3(0.0, 0.0005, 0.0)
	pin.add_child(ring)

# ----------------- BALL TELEPORTATION & DYNAMIC AIMING -----------------

func _reset_ball_position() -> void:
	var start_pos = Vector3(0.0, get_height(0.0, 0.0) + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET, 0.0)
	_teleport_ball(start_pos)

func _teleport_ball(pos: Vector3) -> void:
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	pos.y = get_height(pos.x, pos.z) + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET
	player.global_position = pos
	player.ball.spawn_position = pos
	player.set_profile(get_active_player_name())
	player.ball.reset()
	
	last_putt_start_pos = pos
	if selected_hole_index >= 0 and selected_hole_index < holes.size():
		last_putt_target_hole = holes[selected_hole_index]
	
	# Clear tracers
	player.reset_ball()
	
	# Recompute camera and orientation
	_update_aim_and_camera()
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_ready_for_shot()
	_update_hole_button_labels()

	if putting_cam_widget != null:
		putting_cam_widget.on_next_shot_started()
	
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null:
			if lm.has_method("notify_ball_at_rest"):
				lm.notify_ball_at_rest()
			if lm.has_method("_update_hud_display"):
				lm.call("_update_hud_display")

func _update_aim_and_camera(is_aiming: bool = false) -> void:
	if selected_hole_index < 0 or selected_hole_index >= holes.size():
		return
		
	var target_hole = holes[selected_hole_index]
	var ball_pos = player.ball.global_position
	
	var diff = target_hole - ball_pos
	var base_angle_rad = atan2(diff.z, diff.x)
	var final_angle_rad = base_angle_rad - deg_to_rad(user_aim_yaw_offset_deg)
	
	# Apply aim yaw offset to player ball
	player.ball.aim_yaw_offset_deg = rad_to_deg(-final_angle_rad)
	
	# Position camera behind the ball closer to ball and ground so slope is easy to read
	var back_dir = Vector3(-cos(final_angle_rad), 0.0, -sin(final_angle_rad)).normalized()
	var cam_pos = ball_pos + back_dir * 1.35 + Vector3.UP * 0.8
	if not is_aiming:
		cam_pos = clamp_camera_position(cam_pos, 0.35)
	
	var dist = ball_pos.distance_to(target_hole)
	var look_dist = clamp(dist * 0.4, 2.0, 6.0)
	if dist < 2.0:
		look_dist = dist
	var forward_dir = Vector3(cos(final_angle_rad), 0.0, sin(final_angle_rad)).normalized()
	var target_look = ball_pos + forward_dir * look_dist
	
	$Camera3D.global_position = cam_pos
	$Camera3D.look_at(target_look)
	
	# Store relative camera offset for smooth flight following
	last_camera_offset = cam_pos - ball_pos

# ----------------- INPUT & HIT SIMULATION -----------------

func _process(delta: float) -> void:
	if player and player.ball and player.ball.state == PhysicsEnums.BallState.REST:
		if _settings_layer != null and is_instance_valid(_settings_layer) and _settings_layer.visible:
			return
		var turn_input := 0.0
		if Input.is_action_pressed("aim_left") or Input.is_key_pressed(KEY_LEFT):
			turn_input -= 1.0
		if Input.is_action_pressed("aim_right") or Input.is_key_pressed(KEY_RIGHT):
			turn_input += 1.0
		if turn_input != 0.0:
			_was_aiming_putting = true
			user_aim_yaw_offset_deg += turn_input * 15.0 * delta
			_update_aim_and_camera(true)
		elif _was_aiming_putting:
			_was_aiming_putting = false
			_update_aim_and_camera(false)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_settings()
			get_viewport().set_input_as_handled()
		return

	# Fine aim adjustments when ball is at rest (arrow keys, D-pad, aim_left/aim_right)
	if player and player.ball and player.ball.state == PhysicsEnums.BallState.REST:
		if event.is_action_pressed("aim_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_LEFT) or \
		   event.is_action_pressed("aim_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_RIGHT):
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var camera = $Camera3D
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
					for i in range(holes.size()):
						var d = clicked_point.distance_to(holes[i])
						if d < min_dist:
							min_dist = d
							closest_idx = i
							
					# Selection within 4 meters of any hole
					if closest_idx >= 0 and min_dist <= 4.0:
						_select_hole(closest_idx, true)
						
	# Keyboard R (reset), G (grid), H/Space (test hit)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if pvp_mode:
				_reset_game()
			else:
				_reset_ball_position()
		elif event.keycode == KEY_G:
			_toggle_green_grid()
		elif event.keycode == KEY_H or event.keycode == KEY_SPACE:
			if player and player.ball and player.ball.state == PhysicsEnums.BallState.REST:
				var target_dist_ft = hole_data[selected_hole_index]["dist_ft"]
				var cur_speed = GlobalSettings.get_effective_green_speed()
				var speed_factor = 1.0634 * pow(10.0 / cur_speed, 0.35)
				var sim_speed = sqrt(target_dist_ft) * speed_factor
				var test_data = {
					"Speed": sim_speed,
					"VLA": 0.0,
					"HLA": 0.0,
					"SpinAxis": 0.0,
					"TotalSpin": 0.0,
					"BackSpin": 0.0,
					"SideSpin": 0.0,
					"ShotType": "putt",
					"club": "Pt"
				}
				_on_launch_monitor_hit_ball(test_data)

func _on_launch_monitor_hit_ball(data: Dictionary) -> void:
	if player == null or player.ball == null:
		return
	if player.ball.state != PhysicsEnums.BallState.REST:
		return # Ignore if putt in progress

	var speed_val: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var shot_type = str(data.get("ShotType", "")).to_lower()
	if speed_val <= 0.1 or shot_type == "practice":
		print("[Putting] Practice swing or 0 ball speed ignored.")
		return

	FoamBallBoost.apply_boost(data, "Pt")

	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")

	shot_counter += 1
	shot_in_progress = true
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_shot_started()
	if pvp_mode and not players_list.is_empty():
		var cur_p = players_list[active_player_index % players_list.size()]
		cur_p["shots"] = cur_p.get("shots", 0) + 1
		p1_shots = players_list[0].get("shots", 0) if players_list.size() > 0 else 0
		p2_shots = players_list[1].get("shots", 0) if players_list.size() > 1 else 0

	last_putt_start_pos = player.ball.global_position
	if selected_hole_index >= 0 and selected_hole_index < holes.size():
		last_putt_target_hole = holes[selected_hole_index]

	# Connect to the player's launch monitor shot handler
	player._on_tcp_client_hit_ball(data)

	raw_ball_data = data.duplicate()
	_update_stats_display(false)
	_update_hud()

	# Show the banner
	var speed_mph = data.get("Speed", 0.0)
	if pvp_mode:
		var cur_name = get_active_player_name()
		_show_banner("%s Putt Hit! Speed: %.1f mph" % [cur_name, speed_mph])
	else:
		_show_banner("Putt Hit (Launch Monitor)! Speed: %.1f mph" % speed_mph)

# ----------------- DYNAMIC CUP-ENTRY & CAMERA FOLLOW -----------------

func _physics_process(delta: float) -> void:
	# Camera Smooth Follow
	if player and player.ball:
		var ball_state = player.ball.state
		if ball_state == PhysicsEnums.BallState.FLIGHT or ball_state == PhysicsEnums.BallState.ROLLOUT:
			camera_following = true
			var ball_pos = player.ball.global_position
			# Safety boundary check: keep ball on generated terrain
			if Vector2(ball_pos.x, ball_pos.z).length() > 42.0:
				player.ball.velocity = Vector3.ZERO
				player.ball._enter_rest_state()
				return

			var target_cam_pos = clamp_camera_position(ball_pos + last_camera_offset, 0.35)
			var cur_cam_pos = $Camera3D.global_position
			var new_cam_pos = cur_cam_pos.lerp(target_cam_pos, delta * 8.0)
			$Camera3D.global_position = clamp_camera_position(new_cam_pos, 0.35)
			# Follow the ball while maintaining view of target/ball
			var look_target = ball_pos + Vector3.UP * 0.15
			if not $Camera3D.global_position.is_equal_approx(look_target):
				$Camera3D.look_at(look_target)
		else:
			if camera_following:
				camera_following = false
				if has_node("/root/TensionManager"):
					TensionManager.stop_tension()
				if not (player.ball.holed_out_this_shot or player.ball.is_falling_in_hole):
					_update_aim_and_camera()
				_update_hole_button_labels()
				if has_node("/root/ScreenOffsetManager"):
					ScreenOffsetManager.on_ready_for_shot()

func _on_ball_rest(_shot_data: Dictionary) -> void:
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()
	if putting_cam_widget != null:
		putting_cam_widget.on_next_shot_started()
	raw_ball_data = _shot_data.duplicate()
	_update_stats_display(true)
	var final_pos = player.ball.global_position
	var target_hole = last_putt_target_hole
	
	var start_dist_feet = last_putt_start_pos.distance_to(target_hole) * 3.28084
	var end_dist_feet = final_pos.distance_to(target_hole) * 3.28084
	var end_dist_meters = final_pos.distance_to(target_hole)
	var end_dist_meters_2d = Vector2(final_pos.x, final_pos.z).distance_to(Vector2(target_hole.x, target_hole.z))
	
	# Made into hole check (cup lip / 2D radius <= cup_radius or cup drop)
	var made = false
	var ball_holed = false
	if player.ball != null:
		ball_holed = bool(player.ball.get("is_falling_in_hole")) or bool(player.ball.get("holed_out_this_shot"))
	if ball_holed or end_dist_meters <= cup_radius or end_dist_meters_2d <= cup_radius:
		made = true

	if made:
		var holed_player_name = get_active_player_name()
		var holed_dist_ft = float(hole_data[selected_hole_index]["dist_ft"]) if selected_hole_index >= 0 and selected_hole_index < hole_data.size() else start_dist_feet
		if not holed_player_name.is_empty():
			var mp = get_node_or_null("/root/MultiplayerManager")
			if mp != null and mp.has_method("record_player_longest_putt"):
				mp.record_player_longest_putt(holed_player_name, holed_dist_ft)

	if pvp_mode:
		var cur_player = players_list[active_player_index % players_list.size()]
		var cur_completed = cur_player.get("completed", [])
		var cur_name = cur_player.get("name", "Player %d" % (active_player_index + 1))
		var target_dist_ft = hole_data[selected_hole_index]["dist_ft"]
		
		if made:
			if selected_hole_index < cur_completed.size():
				cur_completed[selected_hole_index] = true
			var count = cur_completed.count(true)
			if sfx_applause_player:
				sfx_applause_player.play()
			GlobalSettings.play_golf_clap()
			_show_banner("⛳ HOLED OUT! %s drained the %d ft putt! (%d/8)" % [cur_name, target_dist_ft, count])
			if count >= 8:
				pvp_winner = active_player_index
				_trigger_victory(cur_name)
				_update_hud()
				_update_hole_button_labels()
				return
		else:
			_show_banner("%s ended %.1f ft from cup (Target: %d ft)" % [cur_name, end_dist_feet, target_dist_ft])
	else:
		# 1. Attempts
		stats_attempts += 1
		
		# 2. 25+ Foot Putt
		if start_dist_feet >= 24.5:
			stats_attempts_25_plus += 1
			
		# 3. Made into hole
		if made:
			stats_made += 1
			if sfx_applause_player:
				sfx_applause_player.play()
			GlobalSettings.play_golf_clap()
			_show_banner("HOLED OUT! AMAZING PUTT! (%.0f ft)" % start_dist_feet)
		else:
			_show_banner("Ended %.1f ft from cup (Target: %.0f ft)" % [end_dist_feet, start_dist_feet])
			
		# 4. Within 5 feet
		if end_dist_feet <= 5.0 or made:
			stats_within_5 += 1
			
		# 5. Within 10 feet
		if end_dist_feet <= 10.0 or made:
			stats_within_10 += 1
		
	# Update Stats Labels & Button Labels
	_update_hud()
	_update_hole_button_labels()
	
	# Reset player back to starting spot after hitting (or alternate turn in PvP)
	var current_shot_id = shot_counter
	var reset_delay = maxf(0.5, GlobalSettings.range_settings.ball_reset_timer.value)
	await get_tree().create_timer(reset_delay).timeout
	if is_inside_tree() and player != null and player.ball != null:
		if shot_counter == current_shot_id and player.ball.state == PhysicsEnums.BallState.REST:
			if pvp_mode and pvp_winner == -1:
				if shot_in_progress:
					shot_in_progress = false
					active_player_index = (active_player_index + 1) % players_list.size()
					var next_hole = _get_next_uncompleted_hole(active_player_index)
					_select_hole(next_hole, false)
					var next_name = get_active_player_name()
					_show_banner("🎯 %s's Turn! Target: Hole %d (%d ft)" % [next_name, next_hole + 1, hole_data[next_hole]["dist_ft"]])
			_reset_ball_position()

# ----------------- GUI SETUP -----------------

func _setup_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1
	add_child(hud_layer)
	
	# Main HUD Control Node
	hud_control = Control.new()
	hud_control.name = "Control"
	hud_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_control.anchor_right = 1.0
	hud_control.anchor_bottom = 1.0
	hud_control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_control.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_control)
	
	# --- TOP SCOREBOARD PANEL ---
	var score_panel = PanelContainer.new()
	score_panel.custom_minimum_size = Vector2(800, 90)
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.anchor_top = 0.0
	score_panel.anchor_bottom = 0.0
	score_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	score_panel.offset_left = -400
	score_panel.offset_right = 400
	score_panel.offset_top = 20
	score_panel.offset_bottom = 110
	hud_control.add_child(score_panel)
	
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
	score_panel.add_theme_stylebox_override("panel", glass_style)
	
	var score_margin = MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 20)
	score_margin.add_theme_constant_override("margin_right", 20)
	score_panel.add_child(score_margin)
	
	var score_hbox = HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_margin.add_child(score_hbox)
	
	attempts_val_lbl = _create_stat_column(score_hbox, "ATTEMPTS")
	dist_25_val_lbl = _create_stat_column(score_hbox, "25+ FT PUTTS")
	within_10_val_lbl = _create_stat_column(score_hbox, "WITHIN 10 FT")
	within_5_val_lbl = _create_stat_column(score_hbox, "WITHIN 5 FT")
	made_val_lbl = _create_stat_column(score_hbox, "MADE PUTTS")
	
	# --- TARGET SELECTION PANEL (RIGHT SIDE) ---
	var target_panel = PanelContainer.new()
	target_panel.custom_minimum_size = Vector2(230, 470)
	target_panel.anchor_left = 1.0
	target_panel.anchor_right = 1.0
	target_panel.anchor_top = 0.5
	target_panel.anchor_bottom = 0.5
	target_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	target_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	target_panel.offset_left = -250
	target_panel.offset_right = -20
	target_panel.offset_top = -235
	target_panel.offset_bottom = 235
	hud_control.add_child(target_panel)
	target_panel.add_theme_stylebox_override("panel", glass_style)

	# --- SHOT STATS GRID CANVAS (LEFT SIDE) ---
	var grid_canvas_script = load("res://UI/grid_canvas.gd")
	if grid_canvas_script != null:
		grid_canvas = Control.new()
		grid_canvas.name = "GridCanvas"
		grid_canvas.set_script(grid_canvas_script)
		grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_control.add_child(grid_canvas)

	# --- STATS TOGGLE BUTTON (BOTTOM-LEFT CORNER) ---
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
	
	var target_margin = MarginContainer.new()
	target_margin.add_theme_constant_override("margin_left", 12)
	target_margin.add_theme_constant_override("margin_right", 12)
	target_margin.add_theme_constant_override("margin_top", 12)
	target_margin.add_theme_constant_override("margin_bottom", 12)
	target_panel.add_child(target_margin)
	
	var target_vbox = VBoxContainer.new()
	target_vbox.add_theme_constant_override("separation", 6)
	target_margin.add_child(target_vbox)
	
	var t_title = Label.new()
	t_title.text = "SELECT HOLE"
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_title.add_theme_font_size_override("font_size", 16)
	t_title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	target_vbox.add_child(t_title)
	
	# Create 8 hole buttons
	hole_buttons.clear()
	for i in range(holes.size()):
		var btn = Button.new()
		btn.text = "Hole %d (%d ft)" % [i + 1, hole_data[i]["dist_ft"]]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 16)
		_apply_btn_style(btn, Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))
		btn.pressed.connect(func(idx=i): _select_hole(idx))
		target_vbox.add_child(btn)
		hole_buttons.append(btn)
		
	# --- BANNER TEXT (Center-ish screen) ---
	banner_lbl = Label.new()
	banner_lbl.text = "Select a target hole (5-50 ft) | Hit putt on Launch Monitor | R: Reset | G: Grid"
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.anchor_left = 0.5
	banner_lbl.anchor_right = 0.5
	banner_lbl.anchor_top = 0.25
	banner_lbl.anchor_bottom = 0.25
	banner_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_lbl.add_theme_font_size_override("font_size", 20)
	banner_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	banner_lbl.add_theme_constant_override("outline_size", 4)
	banner_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_control.add_child(banner_lbl)
	
	# --- BOTTOM CONTROLS PANEL ---
	var ctrl_panel = PanelContainer.new()
	ctrl_panel.custom_minimum_size = Vector2(1180, 76)
	ctrl_panel.anchor_left = 0.5
	ctrl_panel.anchor_right = 0.5
	ctrl_panel.anchor_top = 1.0
	ctrl_panel.anchor_bottom = 1.0
	ctrl_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ctrl_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctrl_panel.offset_left = -590
	ctrl_panel.offset_right = 590
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
	
	# Mode Toggle Button (Standard vs PvP)
	mode_toggle_btn = Button.new()
	mode_toggle_btn.text = "⚔️ PvP Mode: OFF"
	mode_toggle_btn.custom_minimum_size = Vector2(165, 52)
	mode_toggle_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(mode_toggle_btn, Color(0.20, 0.25, 0.35), Color(0.28, 0.35, 0.48))
	mode_toggle_btn.pressed.connect(_toggle_pvp_mode)
	ctrl_hbox.add_child(mode_toggle_btn)

	# Players Manage Button
	players_btn = Button.new()
	players_btn.text = "👥 Players (%d)" % players_list.size()
	players_btn.custom_minimum_size = Vector2(145, 52)
	players_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(players_btn, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	players_btn.pressed.connect(_open_players_modal)
	players_btn.visible = pvp_mode
	ctrl_hbox.add_child(players_btn)
	
	# 1. Slope Grid Toggle Button
	grid_toggle_btn = Button.new()
	grid_toggle_btn.name = "GridToggleButton"
	grid_toggle_btn.text = "📊 Grid: OFF"
	grid_toggle_btn.custom_minimum_size = Vector2(130, 52)
	grid_toggle_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(grid_toggle_btn, Color(0.25, 0.25, 0.25), Color(0.35, 0.35, 0.35))
	grid_toggle_btn.pressed.connect(_toggle_green_grid)
	ctrl_hbox.add_child(grid_toggle_btn)

	# Putting Camera Toggle Button
	putting_cam_btn = Button.new()
	putting_cam_btn.name = "PuttingCamButton"
	putting_cam_btn.custom_minimum_size = Vector2(175, 52)
	putting_cam_btn.add_theme_font_size_override("font_size", 15)
	_update_putting_cam_button_label()
	putting_cam_btn.pressed.connect(_toggle_putting_camera)
	ctrl_hbox.add_child(putting_cam_btn)
	
	# 2. Reset Button
	var reset_btn = Button.new()
	reset_btn.text = "RESET (R)"
	reset_btn.custom_minimum_size = Vector2(110, 52)
	reset_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(reset_btn, Color(0.48, 0.28, 0.18), Color(0.32, 0.18, 0.12))
	reset_btn.pressed.connect(func():
		if pvp_mode:
			_reset_game()
		else:
			_reset_ball_position()
	)
	ctrl_hbox.add_child(reset_btn)

	# 3. Green Speed Button
	green_speed_btn = Button.new()
	green_speed_btn.name = "GreenSpeedButton"
	green_speed_btn.custom_minimum_size = Vector2(150, 52)
	green_speed_btn.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(green_speed_btn, Color(0.18, 0.35, 0.25), Color(0.24, 0.48, 0.35))
	_update_green_speed_button_label()
	green_speed_btn.pressed.connect(_toggle_green_speed_popup)
	ctrl_hbox.add_child(green_speed_btn)

	# 4. Music Toggle Button
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
	
	# 5. Settings Button
	var settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = ""
	settings_btn.icon = load("res://Utils/Settings/Gear.png")
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn.custom_minimum_size = Vector2(52, 52)
	_apply_btn_style(settings_btn, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	settings_btn.pressed.connect(_on_settings_pressed)
	ctrl_hbox.add_child(settings_btn)

	# 6. Exit Button
	var exit_btn = Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(96, 52)
	exit_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(exit_btn, Color(0.36, 0.16, 0.16), Color(0.24, 0.12, 0.12))
	exit_btn.pressed.connect(func(): SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn"))
	ctrl_hbox.add_child(exit_btn)
	
	# Update initial states
	_update_hud()
	_update_grid_button_state()
	_update_music_button_state()
	_update_green_speed_button_label()
	GlobalSettings.range_settings.minigame_music_enabled.setting_changed.connect(func(_val): _update_music_button_state())
	GlobalSettings.range_settings.green_speed.setting_changed.connect(func(val):
		_update_green_speed_button_label()
		if green_speed_val_lbl != null and is_instance_valid(green_speed_val_lbl):
			green_speed_val_lbl.text = "%.1f" % val
		if green_speed_slider != null and is_instance_valid(green_speed_slider):
			if not is_equal_approx(green_speed_slider.value, val):
				green_speed_slider.value = val
	)

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

func _create_stat_column(parent: HBoxContainer, title: String) -> Label:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(col)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	col.add_child(title_lbl)
	
	var val_lbl = Label.new()
	val_lbl.text = "0"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 28)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	val_lbl.add_theme_constant_override("outline_size", 2)
	val_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	col.add_child(val_lbl)
	
	stat_columns.append({"title": title_lbl, "val": val_lbl})
	return val_lbl

func _update_hud() -> void:
	if stat_columns.size() >= 5:
		if pvp_mode and not players_list.is_empty():
			var cur_p = players_list[active_player_index % players_list.size()]
			var cur_name = cur_p.get("name", "Player %d" % (active_player_index + 1))
			var cur_col = get_active_player_color()
			
			# Column 0: Current Turn
			stat_columns[0]["title"].text = "CURRENT TURN"
			if pvp_winner != -1:
				var win_name = players_list[pvp_winner]["name"] if pvp_winner < players_list.size() else cur_name
				stat_columns[0]["val"].text = "🏆 %s WINS!" % win_name
				stat_columns[0]["val"].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			else:
				stat_columns[0]["val"].text = "%s (P%d)" % [cur_name, active_player_index + 1]
				stat_columns[0]["val"].add_theme_color_override("font_color", cur_col)
				
			# Column 1: Putts Made
			stat_columns[1]["title"].text = "PUTTS MADE"
			if players_list.size() == 2:
				var c0 = players_list[0]["completed"].count(true) if players_list[0].has("completed") else 0
				var c1 = players_list[1]["completed"].count(true) if players_list[1].has("completed") else 0
				stat_columns[1]["val"].text = "P1: %d/8 | P2: %d/8" % [c0, c1]
			elif players_list.size() == 3:
				var c0 = players_list[0]["completed"].count(true) if players_list[0].has("completed") else 0
				var c1 = players_list[1]["completed"].count(true) if players_list[1].has("completed") else 0
				var c2 = players_list[2]["completed"].count(true) if players_list[2].has("completed") else 0
				stat_columns[1]["val"].text = "P1:%d P2:%d P3:%d (/8)" % [c0, c1, c2]
			else:
				var c_cur = cur_p["completed"].count(true) if cur_p.has("completed") else 0
				var max_c = 0
				for p in players_list:
					var pc = p["completed"].count(true) if p.has("completed") else 0
					if pc > max_c:
						max_c = pc
				stat_columns[1]["val"].text = "P%d: %d/8 (Leader: %d)" % [active_player_index + 1, c_cur, max_c]
			stat_columns[1]["val"].add_theme_color_override("font_color", Color.WHITE)
			
			# Column 2: Match Status / Leaderboard
			stat_columns[2]["title"].text = "MATCH STATUS"
			if pvp_winner != -1:
				stat_columns[2]["val"].text = "GAME OVER"
				stat_columns[2]["val"].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			else:
				var max_c = -1
				var leader_idx = -1
				var second_c = -1
				var is_tie = false
				for i in range(players_list.size()):
					var c = players_list[i]["completed"].count(true) if players_list[i].has("completed") else 0
					if c > max_c:
						second_c = max_c
						max_c = c
						leader_idx = i
						is_tie = false
					elif c == max_c:
						is_tie = true
				if max_c == 0 or is_tie:
					stat_columns[2]["val"].text = "TIED (%d/8)" % max_c
					stat_columns[2]["val"].add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WARNING)
				else:
					var lead_diff = max_c - second_c
					stat_columns[2]["val"].text = "P%d +%d" % [leader_idx + 1, lead_diff]
					stat_columns[2]["val"].add_theme_color_override("font_color", get_player_color_at(leader_idx))
					
			# Column 3: Total Shots
			stat_columns[3]["title"].text = "SHOTS (P%d)" % (active_player_index + 1)
			stat_columns[3]["val"].text = "%d" % cur_p.get("shots", 0)
			stat_columns[3]["val"].add_theme_color_override("font_color", Color.WHITE)
			
			# Column 4: Target Distance
			stat_columns[4]["title"].text = "TARGET DIST"
			stat_columns[4]["val"].text = "%d FT" % hole_data[selected_hole_index]["dist_ft"]
			stat_columns[4]["val"].add_theme_color_override("font_color", cur_col)
		else:
			stat_columns[0]["title"].text = "ATTEMPTS"
			stat_columns[0]["val"].text = str(stats_attempts)
			stat_columns[0]["val"].add_theme_color_override("font_color", Color.WHITE)
			
			stat_columns[1]["title"].text = "25+ FT PUTTS"
			stat_columns[1]["val"].text = str(stats_attempts_25_plus)
			stat_columns[1]["val"].add_theme_color_override("font_color", Color.WHITE)
			
			stat_columns[2]["title"].text = "WITHIN 10 FT"
			stat_columns[2]["val"].text = str(stats_within_10)
			stat_columns[2]["val"].add_theme_color_override("font_color", Color.WHITE)
			
			stat_columns[3]["title"].text = "WITHIN 5 FT"
			stat_columns[3]["val"].text = str(stats_within_5)
			stat_columns[3]["val"].add_theme_color_override("font_color", Color.WHITE)
			
			stat_columns[4]["title"].text = "MADE PUTTS"
			stat_columns[4]["val"].text = str(stats_made)
			stat_columns[4]["val"].add_theme_color_override("font_color", Color.WHITE)
	else:
		if attempts_val_lbl:
			attempts_val_lbl.text = str(stats_attempts)
		if dist_25_val_lbl:
			dist_25_val_lbl.text = str(stats_attempts_25_plus)
		if within_10_val_lbl:
			within_10_val_lbl.text = str(stats_within_10)
		if within_5_val_lbl:
			within_5_val_lbl.text = str(stats_within_5)
		if made_val_lbl:
			made_val_lbl.text = str(stats_made)

func _trigger_victory(winner_name: String) -> void:
	if sfx_applause_player:
		sfx_applause_player.play()
	GlobalSettings.play_golf_clap()
	var win_color = get_active_player_color()
	_show_game_over_banner(
		"🎉 %s WINS!" % winner_name.to_upper(),
		"First golfer to drain a putt at all 8 distances!",
		win_color
	)

func _show_game_over_banner(title: String, subtitle: String, theme_color: Color) -> void:
	_hide_game_over_banner()
		
	game_over_panel = PanelContainer.new()
	game_over_panel.name = "GameOverBanner"
	game_over_panel.custom_minimum_size = Vector2(640, 260)
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -320
	game_over_panel.offset_right = 320
	game_over_panel.offset_top = -130
	game_over_panel.offset_bottom = 130
	
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
		var c_count = p["completed"].count(true) if p.has("completed") else 0
		var s_count = p.get("shots", 0)
		stat_lines.append("P%d %s: %d/8 putts (%d shots)" % [i + 1, p.get("name", "Player %d" % (i + 1)), c_count, s_count])
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
	elif btn.get_theme_font_size("font_size") < 15:
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

func _update_green_speed_button_label() -> void:
	if green_speed_btn != null and is_instance_valid(green_speed_btn):
		var spd = GlobalSettings.range_settings.green_speed.value
		green_speed_btn.text = "🟢 Speed: %.1f" % spd

func _toggle_green_speed_popup() -> void:
	if green_speed_popup != null and is_instance_valid(green_speed_popup):
		green_speed_popup.queue_free()
		green_speed_popup = null
		return

	green_speed_popup = PanelContainer.new()
	green_speed_popup.name = "GreenSpeedPopup"
	green_speed_popup.custom_minimum_size = Vector2(340, 180)
	green_speed_popup.anchor_left = 0.5
	green_speed_popup.anchor_right = 0.5
	green_speed_popup.anchor_top = 1.0
	green_speed_popup.anchor_bottom = 1.0
	green_speed_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	green_speed_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Position centered horizontally directly above the bottom control panel
	green_speed_popup.offset_left = -170
	green_speed_popup.offset_right = 170
	green_speed_popup.offset_top = -290
	green_speed_popup.offset_bottom = -102
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.14, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.55, 0.40, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	green_speed_popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	green_speed_popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Header HBox: Title and Close button
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)
	
	var title = Label.new()
	title.text = "GREEN SPEED (STIMP)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.55))
	top_hbox.add_child(title)
	
	var is_mob: bool = MobilePerformance.is_mobile()

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40) if is_mob else Vector2(28, 28)
	close_btn.flat = true
	close_btn.pressed.connect(func():
		if green_speed_popup != null and is_instance_valid(green_speed_popup):
			green_speed_popup.queue_free()
			green_speed_popup = null
	)
	top_hbox.add_child(close_btn)
	
	# Slider Row: Slider and numeric readout
	var cur_val = GlobalSettings.range_settings.green_speed.value
	var slider_hbox = HBoxContainer.new()
	slider_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(slider_hbox)
	
	green_speed_slider = HSlider.new()
	green_speed_slider.min_value = 5.0
	green_speed_slider.max_value = 16.0
	green_speed_slider.step = 0.5
	green_speed_slider.value = cur_val
	green_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	green_speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	green_speed_slider.custom_minimum_size = Vector2(120, 48 if is_mob else 36)
	ThemeManager.apply_slider_style(green_speed_slider, 48 if is_mob else 36, 120)
	slider_hbox.add_child(green_speed_slider)
	
	green_speed_val_lbl = Label.new()
	green_speed_val_lbl.text = "%.1f" % cur_val
	green_speed_val_lbl.custom_minimum_size = Vector2(45, 0)
	green_speed_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	green_speed_val_lbl.add_theme_font_size_override("font_size", 16)
	slider_hbox.add_child(green_speed_val_lbl)
	
	green_speed_slider.value_changed.connect(func(v: float):
		GlobalSettings.range_settings.green_speed.set_value(v)
		if green_speed_val_lbl != null and is_instance_valid(green_speed_val_lbl):
			green_speed_val_lbl.text = "%.1f" % v
		_update_green_speed_button_label()
	)
	
	# Preset buttons row
	var presets_hbox = HBoxContainer.new()
	presets_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	presets_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(presets_hbox)
	
	var presets = [
		{"label": "5.0 Slow", "val": 5.0},
		{"label": "10.0 Std", "val": 10.0},
		{"label": "12.0 Fast", "val": 12.0},
		{"label": "15.0 Tour", "val": 15.0},
	]
	for p in presets:
		var p_btn = Button.new()
		p_btn.text = p["label"]
		p_btn.custom_minimum_size = Vector2(72, 44) if is_mob else Vector2(68, 34)
		p_btn.add_theme_font_size_override("font_size", 14 if is_mob else 12)
		_apply_btn_style(p_btn, Color(0.14, 0.22, 0.28), Color(0.20, 0.32, 0.40))
		var v_val: float = p["val"]
		p_btn.pressed.connect(func():
			GlobalSettings.range_settings.green_speed.set_value(v_val)
			if green_speed_slider != null and is_instance_valid(green_speed_slider):
				green_speed_slider.value = v_val
			if green_speed_val_lbl != null and is_instance_valid(green_speed_val_lbl):
				green_speed_val_lbl.text = "%.1f" % v_val
			_update_green_speed_button_label()
		)
		presets_hbox.add_child(p_btn)
		
	var hint_lbl = Label.new()
	hint_lbl.text = "Standard green speed is 10.0"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.7))
	vbox.add_child(hint_lbl)
	
	hud_control.add_child(green_speed_popup)

func _on_settings_pressed() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		return

	if green_speed_popup != null and is_instance_valid(green_speed_popup):
		green_speed_popup.queue_free()
		green_speed_popup = null

	var settings_scene = load("res://UI/Settings/RangeSettings/range_settings.tscn")
	if settings_scene == null:
		return

	# Hide gameplay HUD visuals (score tracker, target hole buttons, banner, controls)
	if hud_layer != null and is_instance_valid(hud_layer):
		hud_layer.visible = false

	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsLayer"
	_settings_layer.layer = 105
	add_child(_settings_layer)

	# Full-screen dimmed backdrop that blocks clicks from leaking through
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

	# Restore gameplay HUD visuals
	if hud_layer != null and is_instance_valid(hud_layer):
		hud_layer.visible = true
	_update_green_speed_button_label()

	if has_node("/root/LaunchMonitorManager"):
		var launch_monitor = get_node("/root/LaunchMonitorManager")
		if launch_monitor != null and launch_monitor.has_method("_update_hud_display"):
			launch_monitor.call("_update_hud_display")


func _exit_tree() -> void:
	GlobalSettings.is_putting_minigame = false
	if has_node("/root/ScreenOffsetManager"):
		if has_node("Camera3D"):
			ScreenOffsetManager.unregister_camera($Camera3D)
		ScreenOffsetManager.set_putter_active(false)
