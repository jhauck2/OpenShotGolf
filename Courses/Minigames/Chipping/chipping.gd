extends Node3D

# Preloaded assets
var PlayerScene = preload("res://Player/player.tscn")
const FlagBuilder = preload("res://Courses/Range/flag_builder.gd")

# Minigame state variables
var player = null
var selected_island_index = 0 # Default target is 25 yards

# Camera follow state
var last_camera_offset = Vector3.ZERO
var camera_following = false
var is_dragging = false

# Stats structure: dictionary key is island index, val is dictionary with Attempts and Hits
var island_stats = {}
var total_greens_hit = 0

# Island configurations: 7 greens at 25, 50, 75, 100, 125, 150, 200 yards
var island_distances_yards = [25, 50, 75, 100, 125, 150, 200]

# Fan layout: angles from straight ahead (+X axis in degrees)
# Staggered left and right so all 7 targets have clear line-of-sight from the tee box
var island_angles_deg = [52.0, -52.0, 25.0, -18.0, 58.0, -56.0, 0.0]

var island_positions = [] # Computed world positions
var island_data = [] # Detailed procedural shape and layout data per island
var island_buttons = []

# UI elements
var target_title_lbl: Label = null
var target_info_lbl = null
var attempts_title_lbl: Label = null
var attempts_lbl = null
var hits_title_lbl: Label = null
var hits_lbl = null
var acc_title_lbl: Label = null
var accuracy_lbl = null
var tot_title_lbl: Label = null
var total_hits_lbl = null
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

# PvP Mode State
const MinigamePlayerModal = preload("res://Courses/Minigames/minigame_player_modal.gd")
var pvp_mode: bool = false
var active_player_index: int = 0
var players_list: Array[Dictionary] = []
var p1_name: String = "Player 1"
var p2_name: String = "Player 2"
var p1_completed: Array[bool] = [false, false, false, false, false, false, false]
var p2_completed: Array[bool] = [false, false, false, false, false, false, false]
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

# Materials
var green_mat: StandardMaterial3D
var fringe_mat: StandardMaterial3D
var sand_mat: StandardMaterial3D
var mulch_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var cap_mat: StandardMaterial3D
var dock_mat: StandardMaterial3D

func _ready() -> void:
	name = "ChippingPractice"
	_init_player_names()
	
	sfx_applause_player = AudioStreamPlayer.new()
	sfx_applause_player.name = "ApplausePlayer"
	if ResourceLoader.exists("res://assets/audio/golf_clap.mp3"):
		sfx_applause_player.stream = load("res://assets/audio/golf_clap.mp3")
	sfx_applause_player.volume_db = 3.0
	add_child(sfx_applause_player)
	
	# 1. Compute island world positions from distance (yards -> meters) + angle fan layout
	for i in range(island_distances_yards.size()):
		island_stats[i] = {"Attempts": 0, "Hits": 0}
		var dist_meters = island_distances_yards[i] * 0.9144 # yards to meters (1 yd = 0.9144 m)
		var angle_rad = deg_to_rad(island_angles_deg[i])
		var x = dist_meters * cos(angle_rad)
		var z = dist_meters * sin(angle_rad)
		island_positions.append(Vector3(x, 0.0, z))


	# 2. Init Materials
	_init_materials()
	
	# 3. Environment Setup
	_setup_environment()
	
	# 4. Setup Water Hazard Pool
	_setup_water_hazard()
	
	# 5. Setup Tee Box (player standing area)
	_setup_tee_box()
	
	# 6. Setup 7 Floating Golf Course Island Greens
	_setup_islands()
	
	# 7. Setup Player
	_setup_player()
	
	# 8. Setup GUI
	_setup_ui()
	
	# Select default target
	_select_target_island(selected_island_index)
	
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected"):
			eb.club_selected.emit("Sw")
	
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
		players_list = MinigamePlayerModal.init_default_players(7)
	if players_list.size() < 2:
		var p2 = MinigamePlayerModal.create_player("Player 2", 1, 7)
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
	for p in players_list:
		p["shots"] = 0
		if not p.has("completed") or p["completed"].size() != 7:
			var c_arr: Array[bool] = []
			for k in range(7):
				c_arr.append(false)
			p["completed"] = c_arr
		else:
			for k in range(7):
				p["completed"][k] = false
	if players_list.size() > 0:
		p1_completed = players_list[0]["completed"]
	if players_list.size() > 1:
		p2_completed = players_list[1]["completed"]
	for i in range(7):
		island_stats[i] = {"Attempts": 0, "Hits": 0}
	total_greens_hit = 0
	_select_target_island(0, true)
	_update_hud()
	_update_island_buttons()
	_update_players_button_label()
	_sync_launch_monitor_player()


func _get_next_uncompleted_island(player_idx: int) -> int:
	if player_idx < 0 or player_idx >= players_list.size():
		return selected_island_index
	var completed = players_list[player_idx].get("completed", [])
	for i in range(completed.size()):
		if not completed[i]:
			return i
	return selected_island_index


func _open_players_modal() -> void:
	if _player_modal_instance != null and is_instance_valid(_player_modal_instance):
		_player_modal_instance.queue_free()
		_player_modal_instance = null
		
	var modal = MinigamePlayerModal.new()
	modal.name = "MinigamePlayerModal"
	add_child(modal)
	_player_modal_instance = modal
	modal.open(players_list, 2, 7, active_player_index)
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
		_update_island_buttons()
		_update_target_ring_color()
		_update_hud()
		_sync_launch_monitor_player()
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


func _update_target_ring_color() -> void:
	for i in range(island_positions.size()):
		var island_node = get_node_or_null("GreenIsland_%d" % i)
		if island_node:
			var ring = island_node.get_node_or_null("TargetRing")
			if ring and ring.material_override is StandardMaterial3D:
				var ring_col = get_active_player_color() if pvp_mode else Color(0.0, 0.85, 1.0)
				ring.material_override.albedo_color = Color(ring_col.r, ring_col.g, ring_col.b, 0.7)
				ring.material_override.emission = ring_col

# ========================================
# MATERIAL INITIALIZATION
# ========================================

func _init_materials() -> void:
	# Putting Green surface (high-res PBR grass)
	green_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/high/grass_green_albedo.png"):
		green_mat.albedo_texture = load("res://Courses/Environments/high/grass_green_albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/high/grass_green_normal.png"):
			green_mat.normal_enabled = true
			green_mat.normal_texture = load("res://Courses/Environments/high/grass_green_normal.png")
		if ResourceLoader.exists("res://Courses/Environments/high/grass_green_roughness.png"):
			green_mat.roughness_texture = load("res://Courses/Environments/high/grass_green_roughness.png")
		green_mat.albedo_color = Color(0.92, 1.0, 0.92)
		green_mat.uv1_scale = Vector3(3.5, 3.5, 3.5)
	elif ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		green_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/grass-green/normal.png"):
			green_mat.normal_enabled = true
			green_mat.normal_texture = load("res://Courses/Environments/grass-green/normal.png")
		green_mat.albedo_color = Color(0.9, 1.0, 0.9)
		green_mat.uv1_scale = Vector3(3.5, 3.5, 3.5)
	else:
		green_mat.albedo_color = Color(0.16, 0.65, 0.22)
	green_mat.roughness = 0.86
	green_mat.metallic_specular = 0.14
	green_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	# Rough grass surround for tee peninsula & island platforms (high-res PBR)
	fringe_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/high/grass_rough_albedo.png"):
		fringe_mat.albedo_texture = load("res://Courses/Environments/high/grass_rough_albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/high/grass_rough_normal.png"):
			fringe_mat.normal_enabled = true
			fringe_mat.normal_texture = load("res://Courses/Environments/high/grass_rough_normal.png")
		if ResourceLoader.exists("res://Courses/Environments/high/grass_rough_roughness.png"):
			fringe_mat.roughness_texture = load("res://Courses/Environments/high/grass_rough_roughness.png")
		fringe_mat.uv1_scale = Vector3(3.0, 3.0, 3.0)
	elif ResourceLoader.exists("res://Courses/Environments/grass-rough/albedo.png"):
		fringe_mat.albedo_texture = load("res://Courses/Environments/grass-rough/albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/normal.png"):
			fringe_mat.normal_enabled = true
			fringe_mat.normal_texture = load("res://Courses/Environments/grass-rough/normal.png")
		fringe_mat.uv1_scale = Vector3(3.0, 3.0, 3.0)
	else:
		fringe_mat.albedo_color = Color(0.12, 0.42, 0.14)
	fringe_mat.roughness = 0.92
	fringe_mat.metallic_specular = 0.12
	fringe_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	# Sand trap / bunker
	sand_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/sand-bunker/albedo.png"):
		sand_mat.albedo_texture = load("res://Courses/Environments/sand-bunker/albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/sand-bunker/normal.png"):
			sand_mat.normal_enabled = true
			sand_mat.normal_texture = load("res://Courses/Environments/sand-bunker/normal.png")
		sand_mat.albedo_color = Color(1.0, 0.96, 0.82)
		sand_mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
	else:
		sand_mat.albedo_color = Color(0.94, 0.88, 0.70)
	sand_mat.roughness = 0.9
	sand_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	
	# Red mulch / flowerbed accent zones
	mulch_mat = StandardMaterial3D.new()
	mulch_mat.albedo_color = Color(0.38, 0.16, 0.11)
	mulch_mat.roughness = 0.95
	
	# Rugged rock pillar & retaining wall stone material
	wall_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_albedo.png"):
		wall_mat.albedo_texture = load("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_normal-ogl.png"):
			wall_mat.normal_enabled = true
			wall_mat.normal_texture = load("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_normal-ogl.png")
		if ResourceLoader.exists("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_roughness.png"):
			wall_mat.roughness_texture = load("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_roughness.png")
		if ResourceLoader.exists("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_ao.png"):
			wall_mat.ao_enabled = true
			wall_mat.ao_texture = load("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_ao.png")
		wall_mat.albedo_color = Color(0.88, 0.88, 0.90)
		wall_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
		wall_mat.uv1_triplanar = true
	elif ResourceLoader.exists("res://Courses/Environments/dry-rocky-ground-bl/dry-rocky-ground_albedo.png"):
		wall_mat.albedo_texture = load("res://Courses/Environments/dry-rocky-ground-bl/dry-rocky-ground_albedo.png")
		wall_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
		wall_mat.uv1_triplanar = true
	else:
		wall_mat.albedo_color = Color(0.32, 0.32, 0.35)
	wall_mat.roughness = 0.9
	
	# Dark rock cap trim
	cap_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_albedo.png"):
		cap_mat.albedo_texture = load("res://Courses/Environments/jagged-rocky-ground1-bl/jagged-rocky-ground_albedo.png")
		cap_mat.albedo_color = Color(0.65, 0.65, 0.68)
		cap_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		cap_mat.uv1_triplanar = true
	else:
		cap_mat.albedo_color = Color(0.22, 0.22, 0.25)
	cap_mat.roughness = 0.88
	
	# Wooden dock
	dock_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/tree-bark/albedo.png"):
		dock_mat.albedo_texture = load("res://Courses/Environments/tree-bark/albedo.png")
		dock_mat.albedo_color = Color(0.7, 0.6, 0.5)
		dock_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
	else:
		dock_mat.albedo_color = Color(0.42, 0.32, 0.21)
	dock_mat.roughness = 0.85

## Helper to generate unique procedural kidney bean polygon shapes with rotation orientation
func _generate_kidney_bean_polygon(base_radius: float, notch: float, lobe: float, rot_deg: float, center_offset: Vector2 = Vector2.ZERO, num_pts: int = 48) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var rot_rad = deg_to_rad(rot_deg)
	var cos_r = cos(rot_rad)
	var sin_r = sin(rot_rad)
	
	for i in range(num_pts):
		var t = float(i) / float(num_pts) * TAU
		# Parametric kidney bean radius formula
		var r = base_radius * (1.0 - notch * cos(t)) * (1.0 + lobe * sin(2.0 * t))
		var x_raw = r * cos(t)
		var y_raw = r * sin(t)
		
		# Rotate to give each island a distinct orientation
		var rx = x_raw * cos_r - y_raw * sin_r
		var ry = x_raw * sin_r + y_raw * cos_r
		pts.append(center_offset + Vector2(rx, ry))
		
	return pts

# ========================================
# ENVIRONMENT SETUP
# ========================================

func _setup_environment() -> void:
	var is_mobile := MobilePerformance.is_mobile()

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.5
	env.tonemap_exposure = 1.02
	if is_mobile:
		env.ssao_enabled = false
	else:
		env.ssao_enabled = true
		env.ssao_radius = 2.0
		env.ssao_intensity = 1.1
		env.ssao_power = 1.5
		env.ssao_detail = 0.2
		env.ssao_horizon = 0.06
		env.ssao_ao_channel_affect = 0.5

	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.83, 0.93)
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.18

	if ResourceLoader.exists("res://addons/sky_3d/src/Sky3D.gd"):
		var Sky3DScript = load("res://addons/sky_3d/src/Sky3D.gd")
		if Sky3DScript != null:
			var sky3d = Sky3DScript.new()
			sky3d.name = "Sky3D"
			if sky3d.environment == null:
				var sky_mat := ShaderMaterial.new()
				sky_mat.shader = Sky3DScript.sky_shader
				var sky := Sky.new()
				sky.sky_material = sky_mat
				env.sky = sky
				sky3d.environment = env
			else:
				sky3d.environment.tonemap_mode = env.tonemap_mode
				sky3d.environment.tonemap_white = env.tonemap_white
				sky3d.environment.tonemap_exposure = env.tonemap_exposure
				sky3d.environment.ssao_enabled = env.ssao_enabled
				sky3d.environment.ssao_radius = env.ssao_radius
				sky3d.environment.ssao_intensity = env.ssao_intensity
				sky3d.environment.ssao_power = env.ssao_power
				sky3d.environment.ssao_detail = env.ssao_detail
				sky3d.environment.ssao_horizon = env.ssao_horizon
				sky3d.environment.ssao_ao_channel_affect = env.ssao_ao_channel_affect
				sky3d.environment.fog_enabled = env.fog_enabled
				sky3d.environment.fog_light_color = env.fog_light_color
				sky3d.environment.fog_density = env.fog_density
				sky3d.environment.fog_sky_affect = env.fog_sky_affect
			sky3d.enable_editor_time = false
			sky3d.enable_game_time = false
			sky3d.current_time = 13.25
			sky3d.sun_energy = 1.15
			sky3d.sky_contribution = 0.55
			sky3d.ambient_energy = 0.50
			add_child(sky3d)
			MobilePerformance.optimize_sky3d(sky3d)
			var sun = sky3d.get_node_or_null("SunLight") as DirectionalLight3D
			if sun != null:
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 200.0 if is_mobile else 400.0
				sun.shadow_bias = 0.025
				sun.shadow_normal_bias = 2.0
			var skydome = sky3d.get_node_or_null("Skydome")
			if skydome != null:
				skydome.clouds_visible = not is_mobile
				skydome.clouds_cumulus_visible = false
				skydome.clouds_speed = 0.005
		else:
			_setup_fallback_sky_and_sun(env, is_mobile)
	else:
		_setup_fallback_sky_and_sun(env, is_mobile)

	_spawn_lake_backdrop()

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	add_child(camera)
	if has_node("/root/TensionManager"):
		TensionManager.register_camera(camera, 55.0)
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.register_camera(camera)
		ScreenOffsetManager.on_ready_for_shot(0.0, true)

func _setup_fallback_sky_and_sun(env: Environment, is_mobile: bool) -> void:
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
		sun.directional_shadow_max_distance = 400.0
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
	world_env.environment = env
	add_child(world_env)

func _spawn_lake_backdrop() -> void:
	if has_node("LakeBackdrop"):
		$LakeBackdrop.queue_free()

	var tex_path := "res://Courses/Environments/chipping_lake_backdrop_seamless.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://Courses/Environments/mountain_backdrop_seamless.png"
	if not ResourceLoader.exists(tex_path):
		push_warning("[chipping.gd] Lake backdrop texture not found.")
		return

	var tex = load(tex_path)
	if tex == null:
		return

	var backdrop_root = Node3D.new()
	backdrop_root.name = "LakeBackdrop"
	add_child(backdrop_root)

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.84, 0.90, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	# Full 360-degree cylindrical panorama sitting low on the distant lake horizon
	var radius := 400.0
	var y_bottom := -0.8
	var y_top := 115.0
	var segments := 72
	var angle_start := -PI
	var angle_end := PI
	var angle_span := angle_end - angle_start
	# Center u=0.25 straight ahead (+X, angle=0) so the clubhouse & fairways face the player
	var u_start := -0.25
	var u_end := 0.75

	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a0 := angle_start + t0 * angle_span
		var a1 := angle_start + t1 * angle_span
		var x0 := radius * cos(a0)
		var z0 := radius * sin(a0)
		var x1 := radius * cos(a1)
		var z1 := radius * sin(a1)
		var u0 := lerpf(u_start, u_end, t0)
		var u1 := lerpf(u_start, u_end, t1)

		var p_b0 := Vector3(x0, y_bottom, z0)
		var p_t0 := Vector3(x0, y_top, z0)
		var p_b1 := Vector3(x1, y_bottom, z1)
		var p_t1 := Vector3(x1, y_top, z1)

		var n0 := Vector3(-x0, 0.0, -z0).normalized()
		var n1 := Vector3(-x1, 0.0, -z1).normalized()

		st.set_normal(n0)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(p_b0)
		st.set_normal(n0)
		st.set_uv(Vector2(u0, 0.0))
		st.add_vertex(p_t0)
		st.set_normal(n1)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(p_t1)

		st.set_normal(n0)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(p_b0)
		st.set_normal(n1)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(p_t1)
		st.set_normal(n1)
		st.set_uv(Vector2(u1, 1.0))
		st.add_vertex(p_b1)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "LakeBackdropMesh"
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop_root.add_child(mesh_inst)

# ========================================
# WATER HAZARD
# ========================================

func _make_water_noise_texture(seed_val: int, freq: float, as_normal: bool) -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_octaves = 3
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = as_normal
	if as_normal:
		tex.bump_strength = 4.0
	tex.noise = noise
	return tex

func _setup_water_hazard() -> void:
	var water = StaticBody3D.new()
	water.name = "WaterPlane"
	water.set_meta("is_water", true)
	add_child(water)

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(900.0, 0.2, 900.0)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, -0.6, 0.0)
	water.add_child(col_shape)

	# Underwater lakebed so depth-based water shader always has valid depth
	var bed_inst = MeshInstance3D.new()
	bed_inst.name = "LakeBed"
	var bed_mesh = QuadMesh.new()
	bed_mesh.size = Vector2(900.0, 900.0)
	bed_inst.mesh = bed_mesh
	var bed_mat = StandardMaterial3D.new()
	bed_mat.albedo_color = Color(0.04, 0.11, 0.16)
	bed_mat.roughness = 1.0
	bed_inst.material_override = bed_mat
	bed_inst.rotation = Vector3(-PI / 2, 0.0, 0.0)
	bed_inst.position = Vector3(0.0, -4.5, 0.0)
	bed_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.add_child(bed_inst)

	var mesh_inst = MeshInstance3D.new()
	var plane_mesh = QuadMesh.new()
	plane_mesh.size = Vector2(900.0, 900.0)
	plane_mesh.subdivide_width = 48
	plane_mesh.subdivide_depth = 48
	mesh_inst.mesh = plane_mesh

	var is_mobile := MobilePerformance.is_mobile()
	if not is_mobile and ResourceLoader.exists("res://Courses/Environments/shaders/water_shader.gdshader"):
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = load("res://Courses/Environments/shaders/water_shader.gdshader")
		shader_mat.set_shader_parameter("deep_color", Vector3(0.05, 0.16, 0.28))
		shader_mat.set_shader_parameter("shallow_color", Vector3(0.12, 0.28, 0.38))
		shader_mat.set_shader_parameter("foam_color", Vector3(0.72, 0.80, 0.85))
		shader_mat.set_shader_parameter("roughness", 0.04)
		shader_mat.set_shader_parameter("depth_fade_distance", 2.2)
		shader_mat.set_shader_parameter("absorbance", 2.6)
		shader_mat.set_shader_parameter("wave_scale", 10.0)
		shader_mat.set_shader_parameter("height_scale", 0.03)
		shader_mat.set_shader_parameter("wave_speed", 0.015)
		shader_mat.set_shader_parameter("wave_texture", _make_water_noise_texture(101, 0.04, false))
		shader_mat.set_shader_parameter("normal1", _make_water_noise_texture(202, 0.06, true))
		shader_mat.set_shader_parameter("normal2", _make_water_noise_texture(303, 0.08, true))
		mesh_inst.material_override = shader_mat
	elif ResourceLoader.exists("res://Courses/Environments/shaders/water_low.gdshader"):
		var low_mat = ShaderMaterial.new()
		low_mat.shader = load("res://Courses/Environments/shaders/water_low.gdshader")
		low_mat.set_shader_parameter("water_color", Color(0.10, 0.28, 0.40))
		low_mat.set_shader_parameter("water_deep_color", Color(0.04, 0.16, 0.28))
		low_mat.set_shader_parameter("foam_color", Color(0.20, 0.42, 0.54))
		low_mat.set_shader_parameter("roughness", 0.35)
		mesh_inst.material_override = low_mat
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.06, 0.22, 0.36, 0.90)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.06
		mat.metallic = 0.7
		mesh_inst.material_override = mat

	mesh_inst.rotation = Vector3(-PI / 2, 0.0, 0.0)
	mesh_inst.position = Vector3(0.0, -0.5, 0.0)
	water.add_child(mesh_inst)

# ========================================
# TEE BOX
# ========================================

func _setup_tee_box() -> void:
	var tee = StaticBody3D.new()
	tee.name = "TeeBox"
	tee.set_meta("surface_type", 3) # TEE
	add_child(tee)

	# Organic grassy peninsula centered behind the ball so the camera sits over lush turf
	var peninsula_poly := _generate_kidney_bean_polygon(6.2, 0.08, 0.05, 0.0, Vector2(-1.4, 0.0), 40)

	# Rock retaining edge & pillars into the lake
	var wall_mesh := _build_retaining_wall_mesh(peninsula_poly, 0.04, -1.6, wall_mat, cap_mat)
	if wall_mesh:
		var wall_inst = MeshInstance3D.new()
		wall_inst.name = "TeeRockWall"
		wall_inst.mesh = wall_mesh
		tee.add_child(wall_inst)
	_add_island_rock_pillars(tee, peninsula_poly, 0.04, -1.6)

	# Rough grass surround surface & collision
	var rough_mesh := _build_flat_polygon_mesh(peninsula_poly, 0.01, fringe_mat)
	if rough_mesh:
		var rough_inst = MeshInstance3D.new()
		rough_inst.name = "TeeRoughTurf"
		rough_inst.mesh = rough_mesh
		tee.add_child(rough_inst)

		var rough_col = CollisionShape3D.new()
		var rough_concave = ConcavePolygonShape3D.new()
		rough_concave.set_faces(_build_flat_poly_faces(peninsula_poly, 0.01))
		rough_col.shape = rough_concave
		tee.add_child(rough_col)

	# Clean fairway/teeing turf patch in the center around the ball (0, 0, 0)
	var tee_patch_poly := _create_ellipse_polygon(Vector2(-0.6, 0.0), 3.4, 2.5, 0.0, 28)
	var patch_mesh := _build_flat_polygon_mesh(tee_patch_poly, 0.025, green_mat)
	if patch_mesh:
		var patch_inst = MeshInstance3D.new()
		patch_inst.name = "TeeFairwayPatch"
		patch_inst.mesh = patch_mesh
		tee.add_child(patch_inst)

	# Two subtle wooden tee markers flanking the ball
	var marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0.82, 0.75, 0.62)
	marker_mat.roughness = 0.75
	for side_z in [-1.15, 1.15]:
		var marker = MeshInstance3D.new()
		marker.name = "TeeMarker_%s" % ("L" if side_z < 0 else "R")
		var m_mesh = CylinderMesh.new()
		m_mesh.top_radius = 0.07
		m_mesh.bottom_radius = 0.08
		m_mesh.height = 0.10
		marker.mesh = m_mesh
		marker.material_override = marker_mat
		marker.position = Vector3(0.25, 0.06, side_z)
		tee.add_child(marker)

# ========================================
# PROCEDURAL FLOATING GOLF ISLAND GENERATION
# ========================================

func _setup_islands() -> void:
	island_data.clear()
	
	for i in range(island_positions.size()):
		var pos = island_positions[i]
		var dist_yds = island_distances_yards[i]
		
		# Generate procedural 2D geometry layouts for this island
		var data = _generate_island_layout(i)
		island_data.append(data)
		
		# Build 3D island node with meshes, collision bodies, trees, dock, flag
		var island_node = _build_floating_island_node(i, pos, dist_yds, data)
		add_child(island_node)

## Generate unique organic 2D shape profiles for each of the 7 islands
## Well-proportioned, generous green sizes with wide open water between all islands
func _generate_island_layout(idx: int) -> Dictionary:
	var outer_pts: PackedVector2Array = PackedVector2Array()
	var green_pts: PackedVector2Array = PackedVector2Array()
	var bunker_list: Array[PackedVector2Array] = []
	var mulch_list: Array[PackedVector2Array] = []
	var tree_positions: Array[Vector3] = []
	var tree_scale_mult: float = 1.0
	var dock_pos = Vector3.ZERO
	var dock_angle = 0.0
	var dock_scale: float = 1.0
	var pin_pos = Vector3.ZERO
	var green_bounding_radius = 3.5
	var outer_bounding_radius = 4.4
	
	match idx:
		0: # 25 YARDS - Green: 3.5m radius (~7.7 yds wide), Island Outer: 4.4m radius (~9.6 yds wide)
			green_bounding_radius = 3.5
			outer_bounding_radius = 4.4
			outer_pts = _generate_kidney_bean_polygon(4.4, 0.12, 0.06, 15.0)
			green_pts = _generate_kidney_bean_polygon(3.5, 0.12, 0.05, 15.0)
			
			# Mini Sand Trap on front approach side
			bunker_list.append(_create_ellipse_polygon(Vector2(1.6, 1.8), 1.1, 0.7, deg_to_rad(-25)))
			
			# Mini Red mulch bed on back side
			mulch_list.append(_create_ellipse_polygon(Vector2(0.0, -3.2), 2.6, 1.0, deg_to_rad(0)))
			
			tree_positions = [
				Vector3(-2.1, 0.05, -3.2),
				Vector3(2.0, 0.05, -3.3)
			]
			tree_scale_mult = 0.40
			dock_pos = Vector3(3.6, 0.0, -1.0)
			dock_angle = deg_to_rad(-45)
			dock_scale = 0.65
			pin_pos = Vector3(0.0, 0.05, -0.2)
			
		1: # 50 YARDS - Green: 4.8m radius (~10.5 yds wide), Island Outer: 5.8m radius (~12.7 yds wide)
			green_bounding_radius = 4.8
			outer_bounding_radius = 5.8
			outer_pts = _generate_kidney_bean_polygon(5.8, 0.14, 0.08, -30.0)
			green_pts = _generate_kidney_bean_polygon(4.8, 0.14, 0.06, -30.0)
			
			bunker_list.append(_create_ellipse_polygon(Vector2(-2.5, 2.5), 1.4, 0.9, deg_to_rad(20)))
			bunker_list.append(_create_ellipse_polygon(Vector2(2.4, 2.6), 1.3, 0.8, deg_to_rad(-35)))
			
			mulch_list.append(_create_ellipse_polygon(Vector2(0.0, -4.3), 3.6, 1.3, deg_to_rad(0)))
			
			tree_positions = [
				Vector3(-2.5, 0.08, -4.1),
				Vector3(0.0, 0.08, -4.7),
				Vector3(2.4, 0.08, -4.2)
			]
			tree_scale_mult = 0.52
			dock_pos = Vector3(-4.8, 0.0, -1.6)
			dock_angle = deg_to_rad(120)
			dock_scale = 0.78
			pin_pos = Vector3(0.1, 0.05, -0.2)
			
		2: # 75 YARDS - Green: 5.8m radius (~12.7 yds wide), Island Outer: 7.0m radius (~15.3 yds wide)
			green_bounding_radius = 5.8
			outer_bounding_radius = 7.0
			outer_pts = _generate_kidney_bean_polygon(7.0, 0.16, 0.10, 45.0)
			green_pts = _generate_kidney_bean_polygon(5.8, 0.16, 0.08, 45.0)
			
			bunker_list.append(_create_ellipse_polygon(Vector2(-3.1, 3.0), 1.8, 1.1, deg_to_rad(-20)))
			bunker_list.append(_create_ellipse_polygon(Vector2(2.9, 3.2), 1.9, 1.2, deg_to_rad(25)))
			
			mulch_list.append(_create_ellipse_polygon(Vector2(0.0, -5.2), 4.6, 1.6, deg_to_rad(0)))
			
			tree_positions = [
				Vector3(-3.3, 0.1, -4.9),
				Vector3(0.0, 0.1, -5.8),
				Vector3(3.1, 0.1, -5.2)
			]
			tree_scale_mult = 0.65
			dock_pos = Vector3(5.8, 0.0, -1.8)
			dock_angle = deg_to_rad(-60)
			dock_scale = 0.9
			pin_pos = Vector3(-0.1, 0.05, -0.3)
			
		3: # 100 YARDS - Green: 7.0m radius (~15.3 yds wide), Island Outer: 8.4m radius (~18.4 yds wide)
			green_bounding_radius = 7.0
			outer_bounding_radius = 8.4
			outer_pts = _generate_kidney_bean_polygon(8.4, 0.18, 0.11, -45.0)
			green_pts = _generate_kidney_bean_polygon(7.0, 0.18, 0.09, -45.0)
			
			bunker_list.append(_create_ellipse_polygon(Vector2(-3.7, 3.7), 2.2, 1.3, deg_to_rad(-15)))
			bunker_list.append(_create_ellipse_polygon(Vector2(3.4, 3.9), 2.3, 1.4, deg_to_rad(25)))
			
			mulch_list.append(_create_ellipse_polygon(Vector2(0.0, -6.3), 5.5, 1.9, deg_to_rad(0)))
			
			tree_positions = [
				Vector3(-4.3, 0.1, -5.9),
				Vector3(-1.5, 0.1, -7.0),
				Vector3(1.5, 0.1, -7.1),
				Vector3(4.2, 0.1, -6.1)
			]
			tree_scale_mult = 1.0
			dock_pos = Vector3(-6.8, 0.0, -2.4)
			dock_angle = deg_to_rad(120)
			dock_scale = 1.0
			pin_pos = Vector3(0.2, 0.05, -0.4)
			
		4: # 125 YARDS - Green: 8.2m radius (~17.9 yds wide), Island Outer: 9.8m radius (~21.4 yds wide)
			green_bounding_radius = 8.2
			outer_bounding_radius = 9.8
			outer_pts = _generate_kidney_bean_polygon(9.8, 0.20, 0.12, 60.0)
			green_pts = _generate_kidney_bean_polygon(8.2, 0.20, 0.10, 60.0)
			
			bunker_list.append(_create_ellipse_polygon(Vector2(-4.4, 4.3), 2.5, 1.5, deg_to_rad(-25)))
			bunker_list.append(_create_ellipse_polygon(Vector2(4.1, 4.6), 2.6, 1.6, deg_to_rad(30)))
			bunker_list.append(_create_ellipse_polygon(Vector2(-1.1, 5.9), 2.0, 1.2, deg_to_rad(10)))
			
			mulch_list.append(_create_ellipse_polygon(Vector2(-3.1, -7.0), 3.7, 1.8, deg_to_rad(-20)))
			mulch_list.append(_create_ellipse_polygon(Vector2(3.1, -7.0), 3.7, 1.8, deg_to_rad(20)))
			
			tree_positions = [
				Vector3(-5.5, 0.1, -6.6),
				Vector3(-2.8, 0.1, -8.1),
				Vector3(0.0, 0.1, -8.4),
				Vector3(2.8, 0.1, -8.1),
				Vector3(5.5, 0.1, -6.6)
			]
			tree_scale_mult = 1.1
			dock_pos = Vector3(7.8, 0.0, -2.2)
			dock_angle = deg_to_rad(75)
			dock_scale = 1.1
			pin_pos = Vector3(0.0, 0.05, -0.5)
			
		5: # 150 YARDS - Green: 9.6m radius (~21.0 yds wide), Island Outer: 11.4m radius (~24.9 yds wide)
			green_bounding_radius = 9.6
			outer_bounding_radius = 11.4
			outer_pts = _generate_kidney_bean_polygon(11.4, 0.22, 0.14, -60.0)
			green_pts = _generate_kidney_bean_polygon(9.6, 0.22, 0.12, -60.0)
			
			bunker_list.append(_create_ellipse_polygon(Vector2(-5.2, 5.1), 2.9, 1.7, deg_to_rad(-20)))
			bunker_list.append(_create_ellipse_polygon(Vector2(4.9, 5.4), 3.0, 1.8, deg_to_rad(25)))
			bunker_list.append(_create_ellipse_polygon(Vector2(0.0, 7.1), 2.4, 1.4, deg_to_rad(0)))
			
			mulch_list.append(_create_ellipse_polygon(Vector2(-3.9, -8.3), 4.3, 2.2, deg_to_rad(-20)))
			mulch_list.append(_create_ellipse_polygon(Vector2(3.9, -8.3), 4.3, 2.2, deg_to_rad(20)))
			
			tree_positions = [
				Vector3(-6.6, 0.1, -7.9),
				Vector3(-3.5, 0.1, -9.5),
				Vector3(0.0, 0.1, -9.8),
				Vector3(3.5, 0.1, -9.5),
				Vector3(6.6, 0.1, -7.9)
			]
			tree_scale_mult = 1.15
			dock_pos = Vector3(-9.2, 0.0, -2.9)
			dock_angle = deg_to_rad(105)
			dock_scale = 1.15
			pin_pos = Vector3(-0.2, 0.05, -0.8)
			
		6: # 200 YARDS - Green: 11.5m radius (~25.2 yds wide), Island Outer: 13.5m radius (~29.5 yds wide)
			green_bounding_radius = 11.5
			outer_bounding_radius = 13.5
			outer_pts = _generate_kidney_bean_polygon(13.5, 0.25, 0.15, 15.0)
			green_pts = _generate_kidney_bean_polygon(11.5, 0.25, 0.13, 15.0)
			
			bunker_list.append(_create_ellipse_polygon(Vector2(-6.2, 5.8), 3.6, 2.1, deg_to_rad(-20)))
			bunker_list.append(_create_ellipse_polygon(Vector2(3.6, 7.6), 3.7, 2.2, deg_to_rad(15)))
			bunker_list.append(_create_ellipse_polygon(Vector2(6.8, 5.3), 3.2, 1.9, deg_to_rad(65)))
			
			mulch_list.append(_create_ellipse_polygon(Vector2(0.0, -10.1), 7.9, 3.0, deg_to_rad(0)))
			
			tree_positions = [
				Vector3(-8.1, 0.1, -9.5),
				Vector3(-5.0, 0.1, -11.0),
				Vector3(-2.2, 0.1, -11.8),
				Vector3(0.9, 0.1, -12.0),
				Vector3(3.9, 0.1, -11.4),
				Vector3(6.6, 0.1, -10.6),
				Vector3(8.9, 0.1, -9.5)
			]
			tree_scale_mult = 1.25
			dock_pos = Vector3(0.0, 0.0, -12.2)
			dock_angle = deg_to_rad(0)
			dock_scale = 1.25
			pin_pos = Vector3(-0.3, 0.05, -1.0)

	return {
		"outer_pts": outer_pts,
		"green_pts": green_pts,
		"bunkers": bunker_list,
		"mulch": mulch_list,
		"trees": tree_positions,
		"tree_scale_mult": tree_scale_mult,
		"dock_pos": dock_pos,
		"dock_angle": dock_angle,
		"dock_scale": dock_scale,
		"pin_pos": pin_pos,
		"green_radius": green_bounding_radius,
		"outer_radius": outer_bounding_radius
	}

func _create_ellipse_polygon(center: Vector2, rx: float, ry: float, rot: float, pts_count: int = 24) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	var cos_r = cos(rot)
	var sin_r = sin(rot)
	for i in range(pts_count):
		var t = float(i) / float(pts_count) * TAU
		var ex = rx * cos(t)
		var ey = ry * sin(t)
		var rx_rot = ex * cos_r - ey * sin_r
		var ry_rot = ex * sin_r + ey * cos_r
		poly.append(center + Vector2(rx_rot, ry_rot))
	return poly

## Build complete 3D Floating Island Node
func _build_floating_island_node(idx: int, pos: Vector3, dist_yds: int, data: Dictionary) -> StaticBody3D:
	var island = StaticBody3D.new()
	island.name = "GreenIsland_%d" % idx
	island.set_meta("surface_type", 4) # Default surface GREEN
	island.position = pos
	
	# Rotate island slightly so main features face player
	var dir_to_tee = -pos.normalized()
	var rot_y = atan2(dir_to_tee.x, dir_to_tee.z)
	island.rotation.y = rot_y
	
	var outer_poly: PackedVector2Array = data["outer_pts"]
	var green_poly: PackedVector2Array = data["green_pts"]
	var bunkers: Array[PackedVector2Array] = data["bunkers"]
	var mulch_beds: Array[PackedVector2Array] = data["mulch"]
	var tree_positions: Array[Vector3] = data["trees"]
	var tree_scale_mult: float = data.get("tree_scale_mult", 1.0)
	var dock_scale: float = data.get("dock_scale", 1.0)
	
	# 1. Rock Retaining Wall, Bottom Cap Rim & Continuous Gapless Rock Pillars
	var wall_mesh = _build_retaining_wall_mesh(outer_poly, 0.04, -1.6, wall_mat, cap_mat)
	if wall_mesh:
		var wall_inst = MeshInstance3D.new()
		wall_inst.mesh = wall_mesh
		wall_inst.name = "RockRetainingWall"
		island.add_child(wall_inst)
		
	# Retaining wall physics collision shape
	var wall_col_shape = ConcavePolygonShape3D.new()
	wall_col_shape.set_faces(_build_wall_collision_faces(outer_poly, 0.04, -1.6))
	var wall_col = CollisionShape3D.new()
	wall_col.shape = wall_col_shape
	island.add_child(wall_col)
	
	# Dense rock pillars fully surrounding the island green with zero gaps
	_add_island_rock_pillars(island, outer_poly, 0.04, -1.6)
	
	# 2. Rough Grass Surround Platform Mesh & Physics
	var fringe_mesh = _build_flat_polygon_mesh(outer_poly, 0.01, fringe_mat)
	if fringe_mesh:
		var f_inst = MeshInstance3D.new()
		f_inst.mesh = fringe_mesh
		f_inst.name = "RoughSurroundTurf"
		island.add_child(f_inst)
		
		# Solid Rough Platform Collision across the entire island (from rock circle to green)
		var rough_body = StaticBody3D.new()
		rough_body.name = "RoughBody"
		rough_body.set_meta("surface_type", 2) # ROUGH
		
		var rough_concave = ConcavePolygonShape3D.new()
		rough_concave.set_faces(_build_flat_poly_faces(outer_poly, 0.01))
		var r_col = CollisionShape3D.new()
		r_col.shape = rough_concave
		rough_body.add_child(r_col)
		island.add_child(rough_body)
		
	# 3. Red Mulch / Flowerbed Accent Meshes
	for m_idx in range(mulch_beds.size()):
		var m_poly = mulch_beds[m_idx]
		var m_mesh = _build_flat_polygon_mesh(m_poly, 0.02, mulch_mat)
		if m_mesh:
			var m_inst = MeshInstance3D.new()
			m_inst.mesh = m_mesh
			m_inst.name = "RedMulchBed_%d" % m_idx
			island.add_child(m_inst)
			
	# 4. Putting Green Mesh & Main Green Collision Body
	var green_mesh = _build_flat_polygon_mesh(green_poly, 0.035, green_mat)
	if green_mesh:
		var g_inst = MeshInstance3D.new()
		g_inst.mesh = green_mesh
		g_inst.name = "PuttingGreenMesh"
		island.add_child(g_inst)
		
		# Main Green Collision Surface
		var green_body = StaticBody3D.new()
		green_body.name = "GreenBody"
		green_body.set_meta("surface_type", 4) # GREEN
		
		var green_concave = ConcavePolygonShape3D.new()
		green_concave.set_faces(_build_flat_poly_faces(green_poly, 0.035))
		var g_col = CollisionShape3D.new()
		g_col.shape = green_concave
		green_body.add_child(g_col)
		island.add_child(green_body)

	# 5. Sand Trap / Bunker Meshes & Bunker Bodies (rendered at y = 0.048 above green so fully visible)
	for b_idx in range(bunkers.size()):
		var b_poly = bunkers[b_idx]
		# Sand surface clearly visible on top of green/rough
		var b_mesh = _build_flat_polygon_mesh(b_poly, 0.048, sand_mat)
		if b_mesh:
			var b_inst = MeshInstance3D.new()
			b_inst.mesh = b_mesh
			b_inst.name = "SandTrapMesh_%d" % b_idx
			island.add_child(b_inst)
			
			var bunker_body = StaticBody3D.new()
			bunker_body.name = "SandTrapBody_%d" % b_idx
			bunker_body.set_meta("surface_type", 2) # BUNKER
			bunker_body.set_meta("is_sand", true)
			
			var b_concave = ConcavePolygonShape3D.new()
			b_concave.set_faces(_build_flat_poly_faces(b_poly, 0.048))
			var b_col = CollisionShape3D.new()
			b_col.shape = b_concave
			bunker_body.add_child(b_col)
			island.add_child(bunker_body)

	# 6. Evergreen / Pine Trees Placement
	_plant_trees_on_island(island, tree_positions, tree_scale_mult)
	
	# 7. Wooden Boat Landing Dock / Gangplank
	var dock_node = _build_boat_dock(data["dock_pos"], data["dock_angle"], dock_scale)
	island.add_child(dock_node)
	
	# 8. Flagpole & Distance Label
	var flag_colors = [
		Color(0.95, 0.22, 0.22),  # 25 YDS - Red
		Color(1.0, 0.55, 0.1),    # 50 YDS - Orange
		Color(0.95, 0.85, 0.15),  # 75 YDS - Yellow
		Color(0.2, 0.85, 0.3),    # 100 YDS - Green
		Color(0.1, 0.8, 0.9),     # 125 YDS - Cyan
		Color(0.2, 0.5, 1.0),     # 150 YDS - Blue
		Color(0.85, 0.3, 0.9),    # 200 YDS - Purple
	]
	
	var pin_pos = data["pin_pos"]
	var flag_node = Node3D.new()
	flag_node.name = "Flag_%d" % idx
	flag_node.position = pin_pos + Vector3(0.0, 0.04, 0.0)
	island.add_child(flag_node)
	
	var q_str = ""
	var gs = GlobalSettings if GlobalSettings != null else (get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null)
	if gs != null and gs.has_method("get_graphics_quality"):
		q_str = gs.get_graphics_quality()
	FlagBuilder.setup_target_flag(flag_node, 2.2, flag_colors[idx], 0.44, 0.30, false, q_str)
	
	var label_node = Label3D.new()
	label_node.text = "%d YDS" % dist_yds
	label_node.font_size = 46 if idx == 0 else 50
	label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_node.outline_size = 12
	label_node.modulate = Color.WHITE
	label_node.outline_modulate = Color(0, 0, 0, 0.9)
	label_node.position = Vector3(0.0, 2.8, 0.0)
	flag_node.add_child(label_node)
	return island

# ========================================
# PROCEDURAL MESH BUILDERS
# ========================================

func _build_flat_polygon_mesh(poly_2d: PackedVector2Array, y_pos: float, mat: Material) -> ArrayMesh:
	if poly_2d.size() < 3:
		return null
		
	var indices = Geometry2D.triangulate_polygon(poly_2d)
	if indices.size() == 0:
		return null
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	
	for idx in indices:
		var p = poly_2d[idx]
		st.set_uv(Vector2(p.x * 0.2, p.y * 0.2))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, y_pos, p.y))
		
	return st.commit()

func _build_flat_poly_faces(poly_2d: PackedVector2Array, y_pos: float) -> PackedVector3Array:
	var faces = PackedVector3Array()
	if poly_2d.size() < 3:
		return faces
		
	var indices = Geometry2D.triangulate_polygon(poly_2d)
	for idx in indices:
		var p = poly_2d[idx]
		faces.append(Vector3(p.x, y_pos, p.y))
	return faces

func _build_retaining_wall_mesh(outer_poly: PackedVector2Array, top_y: float, bot_y: float, wall_m: Material, cap_m: Material) -> ArrayMesh:
	if outer_poly.size() < 3:
		return null
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(wall_m)
	
	var n = outer_poly.size()
	var current_u = 0.0
	
	for i in range(n):
		var p0 = outer_poly[i]
		var p1 = outer_poly[(i + 1) % n]
		var seg_len = p0.distance_to(p1)
		var next_u = current_u + seg_len * 0.4
		
		# Taper bottom towards water
		var v_top0 = Vector3(p0.x, top_y, p0.y)
		var v_top1 = Vector3(p1.x, top_y, p1.y)
		var v_bot0 = Vector3(p0.x * 0.94, bot_y, p0.y * 0.94)
		var v_bot1 = Vector3(p1.x * 0.94, bot_y, p1.y * 0.94)
		
		st.set_uv(Vector2(current_u, 0.0))
		st.add_vertex(v_top0)
		st.set_uv(Vector2(next_u, 0.0))
		st.add_vertex(v_top1)
		st.set_uv(Vector2(current_u, 1.0))
		st.add_vertex(v_bot0)
		
		st.set_uv(Vector2(next_u, 0.0))
		st.add_vertex(v_top1)
		st.set_uv(Vector2(next_u, 1.0))
		st.add_vertex(v_bot1)
		st.set_uv(Vector2(current_u, 1.0))
		st.add_vertex(v_bot0)
		
		current_u = next_u
		
	# Bottom underside cap mesh (solid wood hull underneath)
	var bot_poly = PackedVector2Array()
	for i in range(n):
		bot_poly.append(outer_poly[i] * 0.94)
	var bot_indices = Geometry2D.triangulate_polygon(bot_poly)
	for i in range(0, bot_indices.size(), 3):
		if i + 2 < bot_indices.size():
			var pA = bot_poly[bot_indices[i]]
			var pB = bot_poly[bot_indices[i + 1]]
			var pC = bot_poly[bot_indices[i + 2]]
			st.set_uv(Vector2(pA.x * 0.2, pA.y * 0.2))
			st.add_vertex(Vector3(pA.x, bot_y, pA.y))
			st.set_uv(Vector2(pC.x * 0.2, pC.y * 0.2))
			st.add_vertex(Vector3(pC.x, bot_y, pC.y))
			st.set_uv(Vector2(pB.x * 0.2, pB.y * 0.2))
			st.add_vertex(Vector3(pB.x, bot_y, pB.y))

	st.generate_normals()
	var mesh = st.commit()
	
	# Add dark wood cap rim along perimeter top
	var st_cap = SurfaceTool.new()
	st_cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_cap.set_material(cap_m)
	
	for i in range(n):
		var p0 = outer_poly[i]
		var p1 = outer_poly[(i + 1) % n]
		
		var inner0 = p0 * 0.93
		var inner1 = p1 * 0.93
		
		var t0 = Vector3(p0.x, top_y + 0.02, p0.y)
		var t1 = Vector3(p1.x, top_y + 0.02, p1.y)
		var i0 = Vector3(inner0.x, top_y + 0.02, inner0.y)
		var i1 = Vector3(inner1.x, top_y + 0.02, inner1.y)
		
		st_cap.set_normal(Vector3.UP)
		st_cap.add_vertex(t0)
		st_cap.add_vertex(t1)
		st_cap.add_vertex(i0)
		
		st_cap.add_vertex(t1)
		st_cap.add_vertex(i1)
		st_cap.add_vertex(i0)
		
	st_cap.commit(mesh)
	return mesh

## Calculates total perimeter length of a 2D closed polygon
func _get_polygon_perimeter_length(poly: PackedVector2Array) -> float:
	var total = 0.0
	var n = poly.size()
	if n < 2:
		return 0.0
	for i in range(n):
		total += poly[i].distance_to(poly[(i + 1) % n])
	return total

## Continuously samples a point along the closed polygon perimeter at given distance
func _sample_polygon_perimeter(poly: PackedVector2Array, dist: float) -> Vector2:
	var n = poly.size()
	if n == 0:
		return Vector2.ZERO
	if n == 1:
		return poly[0]
	var total_len = _get_polygon_perimeter_length(poly)
	if total_len <= 0.0001:
		return poly[0]
		
	var d = fposmod(dist, total_len)
	var accum = 0.0
	for i in range(n):
		var p0 = poly[i]
		var p1 = poly[(i + 1) % n]
		var seg_len = p0.distance_to(p1)
		if seg_len > 0.00001:
			if accum + seg_len >= d:
				var t = clampf((d - accum) / seg_len, 0.0, 1.0)
				return p0.lerp(p1, t)
			accum += seg_len
	return poly[0]

## Adds dense, seamless rock pillars fully surrounding the island perimeter with zero gaps
func _add_island_rock_pillars(island: Node3D, outer_poly: PackedVector2Array, top_y: float, bot_y: float) -> void:
	var pillars_folder = Node3D.new()
	pillars_folder.name = "RockPillars"
	island.add_child(pillars_folder)
	
	var total_len = _get_polygon_perimeter_length(outer_poly)
	if total_len <= 0.001:
		return
		
	var pillar_radius = 0.32
	var target_spacing = 0.38 # Overlapping placement (0.64m diameter vs 0.38m spacing) ensures 0 gaps
	var count = int(ceil(total_len / target_spacing))
	if count < 3:
		count = 3
	var actual_spacing = total_len / float(count)
	
	var pillar_height = (top_y - bot_y)
	var center_y = (top_y + bot_y) * 0.5
	
	var pillar_mesh = CylinderMesh.new()
	pillar_mesh.top_radius = pillar_radius
	pillar_mesh.bottom_radius = pillar_radius * 1.05
	pillar_mesh.height = pillar_height
	pillar_mesh.radial_segments = 14
	pillar_mesh.rings = 2
	
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = count
	multimesh.mesh = pillar_mesh
	
	var rng = RandomNumberGenerator.new()
	rng.seed = island.name.hash() + 42
	
	for i in range(count):
		var dist_along = float(i) * actual_spacing
		var pt2d = _sample_polygon_perimeter(outer_poly, dist_along)
		
		# Slight organic height and scale variation for realistic basalt stone look
		var height_var = rng.randf_range(0.97, 1.03)
		var scale_var = rng.randf_range(0.98, 1.04)
		var rot_y = rng.randf_range(0.0, TAU)
		
		var t = Transform3D()
		t = t.scaled(Vector3(scale_var, height_var, scale_var))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = Vector3(pt2d.x * 0.98, center_y, pt2d.y * 0.98)
		
		multimesh.set_instance_transform(i, t)
		
	var mm_inst = MultiMeshInstance3D.new()
	mm_inst.name = "RockPillarsMultiMesh"
	mm_inst.multimesh = multimesh
	mm_inst.material_override = wall_mat
	pillars_folder.add_child(mm_inst)

func _build_wall_collision_faces(outer_poly: PackedVector2Array, top_y: float, bot_y: float) -> PackedVector3Array:
	var faces = PackedVector3Array()
	var n = outer_poly.size()
	for i in range(n):
		var p0 = outer_poly[i]
		var p1 = outer_poly[(i + 1) % n]
		var v_top0 = Vector3(p0.x, top_y, p0.y)
		var v_top1 = Vector3(p1.x, top_y, p1.y)
		var v_bot0 = Vector3(p0.x * 0.94, bot_y, p0.y * 0.94)
		var v_bot1 = Vector3(p1.x * 0.94, bot_y, p1.y * 0.94)
		
		faces.append(v_top0)
		faces.append(v_top1)
		faces.append(v_bot0)
		faces.append(v_top1)
		faces.append(v_bot1)
		faces.append(v_bot0)
	return faces

## Plant evergreen pine trees & shrubs on island edge / mulch
func _plant_trees_on_island(island: Node3D, tree_positions: Array[Vector3], scale_multiplier: float = 1.0) -> void:
	var standard_tree_paths = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-birch-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-pine-1-staticbody.tscn",
	]
	var willow_paths = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-willow-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-willow-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-willow-3-staticbody.tscn",
	]
	
	var trees_folder = Node3D.new()
	trees_folder.name = "TreesFolder"
	island.add_child(trees_folder)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = island.name.hash()
	
	var max_willows = 2 if (tree_positions.size() >= 4 and rng.randf() < 0.20) else 1
	var willow_count = 0
	
	for t_idx in range(tree_positions.size()):
		var t_pos = tree_positions[t_idx]
		var is_willow = (willow_count < max_willows and rng.randf() < 0.15)
		if is_willow:
			willow_count += 1
		var pool = willow_paths if is_willow else standard_tree_paths
		var path = pool[rng.randi() % pool.size()]
		if ResourceLoader.exists(path):
			var scene = load(path)
			if scene:
				var t_inst = scene.instantiate()
				t_inst.name = "IslandTree_%d" % t_idx
				t_inst.position = Vector3(t_pos.x, t_pos.y - 0.15, t_pos.z)
				var scale_val = rng.randf_range(1.1, 1.55) * scale_multiplier
				t_inst.scale = Vector3(scale_val, scale_val, scale_val)
				t_inst.rotation.y = rng.randf_range(0.0, TAU)
				trees_folder.add_child(t_inst)

	# Add low-poly flowering/foliage bushes along the back mulch border
	var bush_paths = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/bush-01-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/bush-02-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/bush-03-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/bush-04-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/bush-05-staticbody.tscn",
	]
	for t_idx in range(tree_positions.size()):
		var t_pos = tree_positions[t_idx]
		var bush_path = bush_paths[rng.randi() % bush_paths.size()]
		if ResourceLoader.exists(bush_path):
			var b_scene = load(bush_path)
			if b_scene:
				var b_inst = b_scene.instantiate()
				b_inst.name = "IslandBush_%d" % t_idx
				b_inst.position = Vector3(t_pos.x * 0.85, t_pos.y - 0.05, t_pos.z + 0.55)
				var b_scale = rng.randf_range(0.45, 0.75) * scale_multiplier
				b_inst.scale = Vector3(b_scale, b_scale, b_scale)
				b_inst.rotation.y = rng.randf_range(0.0, TAU)
				trees_folder.add_child(b_inst)

## Construct wooden boat landing dock structure
func _build_boat_dock(dock_pos: Vector3, dock_angle: float, dock_scale: float = 1.0) -> Node3D:
	var dock_node = Node3D.new()
	dock_node.name = "BoatLandingDock"
	dock_node.position = dock_pos
	dock_node.rotation.y = dock_angle
	dock_node.scale = Vector3(dock_scale, dock_scale, dock_scale)
	
	# Dock main deck platform
	var deck = MeshInstance3D.new()
	var deck_mesh = BoxMesh.new()
	deck_mesh.size = Vector3(2.5, 0.15, 4.0)
	deck.mesh = deck_mesh
	deck.material_override = dock_mat
	deck.position = Vector3(0.0, -0.05, 0.0)
	dock_node.add_child(deck)
	
	# Wooden dock pilings (4 vertical logs)
	var piling_offsets = [
		Vector3(-1.1, -0.4, -1.8),
		Vector3(1.1, -0.4, -1.8),
		Vector3(-1.1, -0.4, 1.8),
		Vector3(1.1, -0.4, 1.8)
	]
	for p_idx in range(piling_offsets.size()):
		var piling = MeshInstance3D.new()
		var p_mesh = CylinderMesh.new()
		p_mesh.top_radius = 0.08
		p_mesh.bottom_radius = 0.08
		p_mesh.height = 1.0
		piling.mesh = p_mesh
		piling.material_override = wall_mat
		piling.position = piling_offsets[p_idx]
		dock_node.add_child(piling)
		
	# Gangway gangplank leading from dock to island edge
	var gangway = MeshInstance3D.new()
	var g_mesh = BoxMesh.new()
	g_mesh.size = Vector3(1.2, 0.1, 2.0)
	gangway.mesh = g_mesh
	gangway.material_override = dock_mat
	gangway.position = Vector3(0.0, 0.02, 2.8)
	gangway.rotation.x = deg_to_rad(-8)
	dock_node.add_child(gangway)
	
	# Solid physics collision for boat landing dock
	var dock_body = StaticBody3D.new()
	dock_body.name = "DockBody"
	dock_body.set_meta("surface_type", 3) # FIRM
	var dock_col = CollisionShape3D.new()
	var d_box = BoxShape3D.new()
	d_box.size = Vector3(2.5, 0.25, 4.0)
	dock_col.shape = d_box
	dock_col.position = Vector3(0.0, -0.05, 0.0)
	dock_body.add_child(dock_col)
	dock_node.add_child(dock_body)
	
	return dock_node

# ========================================
# TARGET SELECTION & RING
# ========================================

func _select_target_island(index: int, reset_ball: bool = true) -> void:
	selected_island_index = index
		
	for i in range(island_positions.size()):
		var island_node = get_node_or_null("GreenIsland_%d" % i)
		if island_node:
			var old_ring = island_node.get_node_or_null("TargetRing")
			if old_ring:
				old_ring.queue_free()
				
			if i == index:
				var ring_radius = island_data[i]["green_radius"]
				var ring = MeshInstance3D.new()
				ring.name = "TargetRing"
				var ring_mesh = TorusMesh.new()
				ring_mesh.inner_radius = ring_radius + 0.05
				ring_mesh.outer_radius = ring_radius + 0.18
				ring_mesh.rings = 48
				ring_mesh.ring_segments = 8
				ring.mesh = ring_mesh

				var ring_col = get_active_player_color() if pvp_mode else Color(0.25, 0.85, 1.0)
				var ring_mat = StandardMaterial3D.new()
				ring_mat.albedo_color = Color(ring_col.r, ring_col.g, ring_col.b, 0.45)
				ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ring_mat.emission_enabled = true
				ring_mat.emission = ring_col
				ring_mat.emission_energy_multiplier = 0.45
				ring.material_override = ring_mat
				ring.position = Vector3(0.0, 0.045, 0.0)
				island_node.add_child(ring)
				
	var dist_yards = island_distances_yards[index]
	_update_island_buttons()
	if reset_ball:
		_reset_ball_position()
	else:
		_update_aim_and_camera()
		if has_node("/root/ScreenOffsetManager"):
			ScreenOffsetManager.on_ready_for_shot()
	_update_hud()
	
	if pvp_mode:
		var cur_name = get_active_player_name()
		_show_banner("🎯 %s's Target: %d Yards" % [cur_name, dist_yards])
	else:
		_show_banner("Target: %d Yards — Hit chip on Launch Monitor onto the green!" % dist_yards)


func _update_island_buttons() -> void:
	for i in range(island_buttons.size()):
		var is_selected = (i == selected_island_index)
		var prefix = "▶ " if is_selected else "  "
		if pvp_mode:
			var marks: Array[String] = []
			for p in players_list:
				var is_done = false
				if p.has("completed") and i < p["completed"].size():
					is_done = p["completed"][i]
				marks.append("✓" if is_done else "○")
			var marks_str = "|".join(marks)
			island_buttons[i].text = "%s%d YDS [%s]" % [prefix, island_distances_yards[i], marks_str]
			if is_selected:
				var active_col = get_active_player_color()
				island_buttons[i].add_theme_color_override("font_color", active_col)
				_apply_btn_style(island_buttons[i], Color(0.18, 0.38, 0.55), Color(0.24, 0.48, 0.70))
			else:
				island_buttons[i].remove_theme_color_override("font_color")
				_apply_btn_style(island_buttons[i], Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))
		else:
			if is_selected:
				island_buttons[i].text = "▶ %d YDS" % island_distances_yards[i]
				island_buttons[i].add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
				_apply_btn_style(island_buttons[i], Color(0.18, 0.38, 0.55), Color(0.24, 0.48, 0.70))
			else:
				island_buttons[i].text = "  %d YDS" % island_distances_yards[i]
				island_buttons[i].remove_theme_color_override("font_color")
				_apply_btn_style(island_buttons[i], Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))

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
	player.global_position = Vector3(0.0, 0.05, 0.0)
	player.ball.spawn_position = player.global_position
	if player.has_method("set_profile"):
		player.set_profile(get_active_player_name())
	player.ball.reset()
	player.reset_ball()
	_update_aim_and_camera()
	_update_island_buttons()
	_update_hud()
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_ready_for_shot()
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()

func _update_aim_and_camera() -> void:
	var target_island_pos = island_positions[selected_island_index]
	var ball_pos = player.ball.global_position
	
	var diff = target_island_pos - ball_pos
	var angle_rad = atan2(diff.z, diff.x)
	
	player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)
	
	var back_dir = Vector3(-cos(angle_rad), 0.0, -sin(angle_rad)).normalized()
	var cam_pos = ball_pos + back_dir * 4.0 + Vector3.UP * 2.0
	
	$Camera3D.global_position = cam_pos
	$Camera3D.look_at(ball_pos + back_dir * -15.0 + Vector3.UP * 1.0)
	
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
					for i in range(island_positions.size()):
						var d = clicked_point.distance_to(island_positions[i])
						if d < min_dist:
							min_dist = d
							closest_idx = i
					if min_dist <= island_data[closest_idx]["outer_radius"] + 2.0:
						_select_target_island(closest_idx, true)
					
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if pvp_mode:
				_reset_game()
			else:
				_reset_ball_position()
		elif event.keycode == KEY_H or event.keycode == KEY_SPACE:
			if player and player.ball and player.ball.state == PhysicsEnums.BallState.REST:
				var dist_yds = island_distances_yards[selected_island_index]
				var dist_m = dist_yds * 0.9144
				var sim_speed_mph = sqrt(dist_m * 9.8 / sin(deg_to_rad(64.0))) * 2.23694 * 1.02
				var test_data = {
					"Speed": sim_speed_mph,
					"VLA": 32.0,
					"HLA": 0.0,
					"SpinAxis": 0.0,
					"TotalSpin": 4500.0,
					"BackSpin": 4500.0,
					"SideSpin": 0.0,
					"ShotType": "chip",
					"club": "Sw"
				}
				_on_launch_monitor_hit_ball(test_data)

func _on_launch_monitor_hit_ball(data: Dictionary) -> void:
	if player == null or player.ball == null:
		return
	if player.ball.state != PhysicsEnums.BallState.REST:
		return # Ignore if shot in progress

	var speed_val: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var shot_type = str(data.get("ShotType", "")).to_lower()
	if speed_val <= 0.1 or shot_type == "practice":
		print("[Chipping] Practice swing or 0 ball speed ignored.")
		return

	FoamBallBoost.apply_boost(data)
	PowerCalibration.apply_calibration(data)

	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")

	shot_in_progress = true
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_shot_started()
	if pvp_mode and not players_list.is_empty():
		var cur_p = players_list[active_player_index % players_list.size()]
		cur_p["shots"] = cur_p.get("shots", 0) + 1
		p1_shots = players_list[0].get("shots", 0) if players_list.size() > 0 else 0
		p2_shots = players_list[1].get("shots", 0) if players_list.size() > 1 else 0

	# Connect to the player's launch monitor shot handler
	player._on_tcp_client_hit_ball(data)

	raw_ball_data = data.duplicate()
	_update_stats_display(false)
	_update_hud()

	# Show the banner
	var speed_mph = data.get("Speed", 0.0)
	var vla = data.get("VLA", 0.0)
	if pvp_mode:
		var cur_name = get_active_player_name()
		_show_banner("%s Chipped! Speed: %.1f mph | Loft: %.1f°" % [cur_name, speed_mph, vla])
	else:
		_show_banner("Chipped (Launch Monitor)! Speed: %.1f mph | Loft: %.1f°" % [speed_mph, vla])

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
			$Camera3D.global_position = $Camera3D.global_position.lerp(target_cam_pos, delta * 8.0)
			$Camera3D.look_at(ball_pos + Vector3.UP * 0.1)
		else:
			if camera_following:
				camera_following = false
				if has_node("/root/TensionManager"):
					TensionManager.stop_tension()
				_update_aim_and_camera()
				if has_node("/root/ScreenOffsetManager"):
					ScreenOffsetManager.on_ready_for_shot()

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
	var target_island_pos = island_positions[selected_island_index]
	var target_data = island_data[selected_island_index]
	
	var dist_to_target = Vector2(final_pos.x, final_pos.z).distance_to(Vector2(target_island_pos.x, target_island_pos.z))
	var target_dist_yds = island_distances_yards[selected_island_index]

	if pvp_mode:
		var cur_player = players_list[active_player_index % players_list.size()]
		var cur_completed = cur_player.get("completed", [])
		var cur_name = cur_player.get("name", "Player %d" % (active_player_index + 1))
		
		if player.ball.is_in_water:
			_show_banner("💦 SPLASH! %s landed in the water hazard." % cur_name)
		elif dist_to_target <= target_data["green_radius"]:
			if selected_island_index < cur_completed.size():
				cur_completed[selected_island_index] = true
			var count = cur_completed.count(true)
			if sfx_applause_player:
				sfx_applause_player.play()
			GlobalSettings.play_golf_clap()
			_show_banner("🍎 GREEN HIT! %s nailed %d YDS! (%d/7)" % [cur_name, target_dist_yds, count])
			if count >= 7:
				pvp_winner = active_player_index
				_trigger_victory(cur_name)
				_update_hud()
				_update_island_buttons()
				return
		else:
			var landed_on_other = -1
			for i in range(island_positions.size()):
				if i == selected_island_index:
					continue
				var d = Vector2(final_pos.x, final_pos.z).distance_to(Vector2(island_positions[i].x, island_positions[i].z))
				if d <= island_data[i]["green_radius"]:
					landed_on_other = i
					break
			if landed_on_other >= 0:
				if landed_on_other < cur_completed.size() and not cur_completed[landed_on_other]:
					cur_completed[landed_on_other] = true
					var count = cur_completed.count(true)
					if sfx_applause_player:
						sfx_applause_player.play()
					GlobalSettings.play_golf_clap()
					_show_banner("🎯 BONUS HIT! %s landed on %d YDS! (%d/7)" % [cur_name, island_distances_yards[landed_on_other], count])
					if count >= 7:
						pvp_winner = active_player_index
						_trigger_victory(cur_name)
						_update_hud()
						_update_island_buttons()
						return
				else:
					_show_banner("%s landed on %d YDS green (already hit)!" % [cur_name, island_distances_yards[landed_on_other]])
			else:
				_show_banner("%s missed target green. Distance: %.1f yards" % [cur_name, dist_to_target * 1.09361])
	else:
		island_stats[selected_island_index]["Attempts"] += 1
		if player.ball.is_in_water:
			_show_banner("💦 SPLASH! Landed in the water hazard.")
		elif dist_to_target <= target_data["green_radius"]:
			island_stats[selected_island_index]["Hits"] += 1
			total_greens_hit += 1
			if sfx_applause_player:
				sfx_applause_player.play()
			GlobalSettings.play_golf_clap()
			_show_banner("🍎 GREEN HIT! Outstanding chip! (%d total greens hit)" % total_greens_hit)
		else:
			var landed_on_other = false
			for i in range(island_positions.size()):
				if i == selected_island_index:
					continue
				var d = Vector2(final_pos.x, final_pos.z).distance_to(Vector2(island_positions[i].x, island_positions[i].z))
				if d <= island_data[i]["green_radius"]:
					landed_on_other = true
					_show_banner("Landed on the %d YDS green — but you were aiming for %d YDS!" % [island_distances_yards[i], island_distances_yards[selected_island_index]])
					break
			if not landed_on_other:
				_show_banner("Missed target green. Distance to center: %.1f yards" % (dist_to_target * 1.09361))
		
	_update_hud()
	_update_island_buttons()
	
	var reset_delay = maxf(0.5, GlobalSettings.range_settings.ball_reset_timer.value)
	await get_tree().create_timer(reset_delay).timeout
	if pvp_mode and pvp_winner == -1:
		if shot_in_progress:
			shot_in_progress = false
			active_player_index = (active_player_index + 1) % players_list.size()
			var next_target = _get_next_uncompleted_island(active_player_index)
			_select_target_island(next_target, false)
			var next_name = get_active_player_name()
			_show_banner("🎯 %s's Turn! Target: %d YDS" % [next_name, island_distances_yards[next_target]])
			_sync_launch_monitor_player()
	_reset_ball_position()

func _sync_launch_monitor_player() -> void:
	if not pvp_mode or players_list.is_empty():
		return
	var cur_name = get_active_player_name()
	if player != null and player.has_method("set_profile"):
		player.set_profile(cur_name)
	if has_node("/root/LaunchMonitorManager") and has_node("/root/MultiplayerManager"):
		var hand = MultiplayerManager.get_player_handedness(cur_name)
		get_node("/root/LaunchMonitorManager").set_handedness(hand)

# ========================================
# GUI SETUP
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
	
	# Scoreboard
	var score_panel = PanelContainer.new()
	score_panel.custom_minimum_size = Vector2(780, 90)
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.anchor_top = 0.0
	score_panel.anchor_bottom = 0.0
	score_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	score_panel.offset_left = -390
	score_panel.offset_right = 390
	score_panel.offset_top = 20
	score_panel.offset_bottom = 110
	hud_control.add_child(score_panel)
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
	t_lbl.text = "TARGET"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	target_col.add_child(t_lbl)
	target_title_lbl = t_lbl
	target_info_lbl = Label.new()
	target_info_lbl.text = "%d YDS" % island_distances_yards[selected_island_index]
	target_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_info_lbl.add_theme_font_size_override("font_size", 28)
	target_info_lbl.add_theme_color_override("font_color", Color.WHITE)
	target_col.add_child(target_info_lbl)
	
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
	attempts_title_lbl = att_lbl
	attempts_lbl = Label.new()
	attempts_lbl.text = "0"
	attempts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attempts_lbl.add_theme_font_size_override("font_size", 28)
	attempts_lbl.add_theme_color_override("font_color", Color.WHITE)
	attempts_col.add_child(attempts_lbl)
	
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
	hits_title_lbl = h_lbl
	hits_lbl = Label.new()
	hits_lbl.text = "0"
	hits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hits_lbl.add_theme_font_size_override("font_size", 28)
	hits_lbl.add_theme_color_override("font_color", Color.WHITE)
	hits_col.add_child(hits_lbl)
	
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
	acc_title_lbl = ac_lbl
	accuracy_lbl = Label.new()
	accuracy_lbl.text = "0%"
	accuracy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	accuracy_lbl.add_theme_font_size_override("font_size", 28)
	accuracy_lbl.add_theme_color_override("font_color", Color.WHITE)
	acc_col.add_child(accuracy_lbl)
	
	var total_col = VBoxContainer.new()
	total_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_child(total_col)
	var tot_lbl = Label.new()
	tot_lbl.text = "TOTAL GREENS"
	tot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tot_lbl.add_theme_font_size_override("font_size", 14)
	tot_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	total_col.add_child(tot_lbl)
	tot_title_lbl = tot_lbl
	total_hits_lbl = Label.new()
	total_hits_lbl.text = "0"
	total_hits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_hits_lbl.add_theme_font_size_override("font_size", 28)
	total_hits_lbl.add_theme_color_override("font_color", Color.WHITE)
	total_col.add_child(total_hits_lbl)
	
	# Target Selection Panel (Right Side)
	var target_panel = PanelContainer.new()
	target_panel.custom_minimum_size = Vector2(200, 360)
	target_panel.anchor_left = 1.0
	target_panel.anchor_right = 1.0
	target_panel.anchor_top = 0.5
	target_panel.anchor_bottom = 0.5
	target_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	target_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	target_panel.offset_left = -220
	target_panel.offset_right = -20
	target_panel.offset_top = -180
	target_panel.offset_bottom = 180
	hud_control.add_child(target_panel)
	target_panel.add_theme_stylebox_override("panel", glass_style)

	# Shot Stats Grid Canvas (Left Side, matches Range/Course/Practice)
	var grid_canvas_script = load("res://UI/grid_canvas.gd")
	if grid_canvas_script != null:
		grid_canvas = Control.new()
		grid_canvas.name = "GridCanvas"
		grid_canvas.set_script(grid_canvas_script)
		grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_control.add_child(grid_canvas)

	# Dedicated Stats Toggle Button - Bottom-Left Corner
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
	target_vbox.add_theme_constant_override("separation", 8)
	target_margin.add_child(target_vbox)
	
	var t_title = Label.new()
	t_title.text = "🌲 CHOOSE TARGET"
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_title.add_theme_font_size_override("font_size", 16)
	t_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	target_vbox.add_child(t_title)
	
	island_buttons.clear()
	for i in range(island_distances_yards.size()):
		var btn = Button.new()
		btn.text = "  %d YDS" % island_distances_yards[i]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 15)
		_apply_btn_style(btn, Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42))
		btn.pressed.connect(func(idx = i): _select_target_island(idx, true))
		target_vbox.add_child(btn)
		island_buttons.append(btn)
	
	# Banner
	banner_lbl = Label.new()
	banner_lbl.text = "Select a target floating green and hit on Launch Monitor!"
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
	
	# Controls Panel
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

	# Music Toggle Button
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
	
	var settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = ""
	settings_btn.icon = load("res://Utils/Settings/Gear.png")
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn.custom_minimum_size = Vector2(52, 52)
	_apply_btn_style(settings_btn, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	settings_btn.pressed.connect(_on_settings_pressed)
	ctrl_hbox.add_child(settings_btn)

	var exit_btn = Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(96, 52)
	exit_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(exit_btn, Color(0.36, 0.16, 0.16), Color(0.24, 0.12, 0.12))
	exit_btn.pressed.connect(func(): SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn"))
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
# UI HELPERS
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

func _update_hud() -> void:
	if selected_island_index < 0:
		return
	var stats = island_stats[selected_island_index]
	var att = stats["Attempts"]
	var hits = stats["Hits"]
	var acc = 0
	if att > 0:
		acc = int((float(hits) / float(att)) * 100.0)
		
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
				
		if attempts_title_lbl:
			attempts_title_lbl.text = "ISLANDS HIT"
		if attempts_lbl:
			if players_list.size() == 2:
				var c0 = players_list[0]["completed"].count(true) if players_list[0].has("completed") else 0
				var c1 = players_list[1]["completed"].count(true) if players_list[1].has("completed") else 0
				attempts_lbl.text = "P1: %d/7 | P2: %d/7" % [c0, c1]
			elif players_list.size() == 3:
				var c0 = players_list[0]["completed"].count(true) if players_list[0].has("completed") else 0
				var c1 = players_list[1]["completed"].count(true) if players_list[1].has("completed") else 0
				var c2 = players_list[2]["completed"].count(true) if players_list[2].has("completed") else 0
				attempts_lbl.text = "P1:%d P2:%d P3:%d (/7)" % [c0, c1, c2]
			else:
				var c_cur = cur_p["completed"].count(true) if cur_p.has("completed") else 0
				var max_c = 0
				for p in players_list:
					var pc = p["completed"].count(true) if p.has("completed") else 0
					if pc > max_c:
						max_c = pc
				attempts_lbl.text = "P%d: %d/7 (Leader: %d)" % [active_player_index + 1, c_cur, max_c]
			attempts_lbl.add_theme_color_override("font_color", Color.WHITE)
			
		if hits_title_lbl:
			hits_title_lbl.text = "MATCH STATUS"
		if hits_lbl:
			if pvp_winner != -1:
				hits_lbl.text = "GAME OVER"
				hits_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
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
					hits_lbl.text = "TIED (%d/7)" % max_c
					hits_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WARNING)
				else:
					var lead_diff = max_c - second_c
					hits_lbl.text = "P%d +%d" % [leader_idx + 1, lead_diff]
					hits_lbl.add_theme_color_override("font_color", get_player_color_at(leader_idx))
				
		if acc_title_lbl:
			acc_title_lbl.text = "TOTAL SHOTS"
		if accuracy_lbl:
			accuracy_lbl.text = "P%d: %d shots" % [active_player_index + 1, cur_p.get("shots", 0)]
			accuracy_lbl.add_theme_color_override("font_color", Color.WHITE)
			
		if tot_title_lbl:
			tot_title_lbl.text = "TARGET YARDS"
		if total_hits_lbl:
			total_hits_lbl.text = "%d YDS" % island_distances_yards[selected_island_index]
			total_hits_lbl.add_theme_color_override("font_color", cur_col)
	else:
		if target_title_lbl:
			target_title_lbl.text = "TARGET"
		if target_info_lbl:
			target_info_lbl.text = "%d YDS" % island_distances_yards[selected_island_index]
			target_info_lbl.add_theme_color_override("font_color", Color.WHITE)
		if attempts_title_lbl:
			attempts_title_lbl.text = "ATTEMPTS"
		if attempts_lbl:
			attempts_lbl.text = str(att)
			attempts_lbl.add_theme_color_override("font_color", Color.WHITE)
		if hits_title_lbl:
			hits_title_lbl.text = "HITS"
		if hits_lbl:
			hits_lbl.text = str(hits)
			hits_lbl.add_theme_color_override("font_color", Color.WHITE)
		if acc_title_lbl:
			acc_title_lbl.text = "ACCURACY"
		if accuracy_lbl:
			accuracy_lbl.text = "%d%%" % acc
			accuracy_lbl.add_theme_color_override("font_color", Color.WHITE)
		if tot_title_lbl:
			tot_title_lbl.text = "TOTAL GREENS"
		if total_hits_lbl:
			total_hits_lbl.text = str(total_greens_hit)
			total_hits_lbl.add_theme_color_override("font_color", Color.WHITE)

func _trigger_victory(winner_name: String) -> void:
	if sfx_applause_player:
		sfx_applause_player.play()
	GlobalSettings.play_golf_clap()
	var win_color = get_active_player_color()
	_show_game_over_banner(
		"🎉 %s WINS!" % winner_name.to_upper(),
		"First golfer to conquer all 7 floating island greens!",
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
		stat_lines.append("P%d %s: %d/7 islands (%d shots)" % [i + 1, p.get("name", "Player %d" % (i + 1)), c_count, s_count])
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

	# Hide gameplay HUD visuals (scoreboard, target panel, banner, controls)
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

	if has_node("/root/LaunchMonitorManager"):
		var launch_monitor = get_node("/root/LaunchMonitorManager")
		if launch_monitor != null and launch_monitor.has_method("_update_hud_display"):
			launch_monitor.call("_update_hud_display")


func _exit_tree() -> void:
	if has_node("/root/ScreenOffsetManager") and has_node("Camera3D"):
		ScreenOffsetManager.unregister_camera($Camera3D)
