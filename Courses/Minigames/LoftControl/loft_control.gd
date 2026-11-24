extends Node3D

# Preloaded assets
var PlayerScene = preload("res://Player/player.tscn")

# Minigame state
var player = null
var attempts_count: int = 0
var broken_count: int = 0
var shot_counter: int = 0
var shot_reset_token: int = 0
var last_shot_data: Dictionary = {}
var is_victory: bool = false
var viewing_wall_cam: bool = false
var shot_in_progress: bool = false

# Tic-Tac-Toe mode state
var tic_tac_toe_mode: bool = false
var board_marks: Array[String] = ["", "", "", "", "", "", "", "", ""]
var current_turn_symbol: String = "X"
var player_x_name: String = "Player 1"
var player_o_name: String = "Player 2"
var winner_symbol: String = ""
var is_draw: bool = false
var winning_line: Array[int] = []
var symbol_3d_nodes: Array = []

const WIN_COMBOS = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8], # Horizontal rows
	[0, 3, 6], [1, 4, 7], [2, 5, 8], # Vertical columns
	[0, 4, 8], [2, 4, 6]             # Diagonals
]

# Camera tracking
var camera: Camera3D = null
var last_camera_offset := Vector3(-6.0, 2.5, 0.0)
var camera_following: bool = false
var prev_ball_pos := Vector3.ZERO

# Wall constants (75 yards = 225 feet = 68.58 meters)
const WALL_DIST_X: float = 68.58
const GRID_ROWS: int = 3
const GRID_COLS: int = 3

# SQUARE Glass Panes: 8.5m x 8.5m each
const PANE_SIZE: float = 8.5
const PANE_DEPTH: float = 0.15

# Grid coordinates:
# Columns (Z axis): Left = -9.3m, Mid = 0.0m, Right = +9.3m (8.5m square each + 0.8m beam)
# Rows (Y axis): Top = 24.6m, Mid = 15.3m, Bot = 6.0m (8.5m square each + 0.8m beam)
const COL_Z_CENTERS = [-9.3, 0.0, 9.3]
const ROW_Y_CENTERS = [24.6, 15.3, 6.0]

const PANE_NAMES = [
	"Top Left",    "Top Middle",    "Top Right",
	"Middle Left", "Middle Middle", "Middle Right",
	"Bottom Left", "Bottom Middle", "Bottom Right"
]

const PANE_DESCS = [
	"High Loft · 75 FT",   "High Loft · 75 FT",   "High Loft · 75 FT",
	"Mid Trajectory · 45 FT", "Center Target · 45 FT", "Mid Trajectory · 45 FT",
	"Low Stinger · 18 FT", "Low Stinger · 18 FT", "Low Stinger · 18 FT"
]

const PANE_COLORS = [
	Color(0.25, 0.95, 1.0), Color(0.25, 0.95, 1.0), Color(0.25, 0.95, 1.0), # Top Row: Neon Cyan
	Color(1.0, 0.90, 0.25), Color(1.0, 0.90, 0.25), Color(1.0, 0.90, 0.25), # Mid Row: Golden Yellow
	Color(0.35, 1.0, 0.55), Color(0.35, 1.0, 0.55), Color(0.35, 1.0, 0.55)  # Bot Row: Bright Lime
]

# State per pane (0 to 8)
var panes_broken: Array[bool] = [false, false, false, false, false, false, false, false, false]
var pane_nodes: Array[Node3D] = []
var pane_mesh_instances: Array[MeshInstance3D] = []
var pane_areas: Array[Area3D] = []
var hud_matrix_buttons: Array[Button] = []

# Materials
var glass_mat_intact: StandardMaterial3D
var glass_mat_broken_rim: StandardMaterial3D
var frame_mat_steel: StandardMaterial3D
var frame_mat_concrete: StandardMaterial3D
var turf_mat: StandardMaterial3D
var fairway_mat: StandardMaterial3D
var x_symbol_mat: StandardMaterial3D
var o_symbol_mat: StandardMaterial3D
var win_symbol_mat: StandardMaterial3D

# UI References
var hud_layer: CanvasLayer = null
var hud_control: Control = null
var panes_cleared_lbl: Label = null
var attempts_lbl: Label = null
var accuracy_lbl: Label = null
var last_shot_lbl: Label = null
var stat_columns: Array[Dictionary] = []
var matrix_title_lbl: Label = null
var mode_toggle_btn: Button = null
var game_over_panel: PanelContainer = null
var music_toggle_btn: Button = null
var cam_toggle_btn: Button = null
var stats_btn: Button = null
var grid_canvas: Control = null
var _settings_layer: CanvasLayer = null
var raw_ball_data: Dictionary = {}
var display_data: Dictionary = {}

# Audio
var sfx_shatter_player: AudioStreamPlayer = null
var sfx_frame_player: AudioStreamPlayer = null
var sfx_applause_player: AudioStreamPlayer = null
var _shatter_stream: AudioStreamWAV = null


func _ready() -> void:
	name = "LoftControl"
	_init_player_names()
	
	# 1. Initialize Audio Streams
	_init_audio_streams()
	
	# 2. Initialize Materials
	_init_materials()
	
	# 3. Setup Environment (Sky, Light, Camera)
	_setup_environment()
	
	# 4. Setup Range Turf, Fairway, Distance Markers (25, 50, 75 yds)
	_setup_range_ground()
	
	# 5. Setup 75-Yard Target Wall & 3x3 SQUARE Glass Grid
	_setup_glass_wall_and_panes()
	
	# 6. Setup Player
	_setup_player()
	
	# 7. Setup UI & HUD
	_setup_ui()
	
	# Connect club selector
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected"):
			eb.club_selected.emit("Sw") # Default to Sand Wedge for 75 yards
	
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


# ==============================================================================
# AUDIO GENERATION & SETUP
# ==============================================================================

func _init_audio_streams() -> void:
	# Generate procedural crisp glass shatter WAV stream
	_shatter_stream = _create_procedural_glass_shatter_stream()
	
	sfx_shatter_player = AudioStreamPlayer.new()
	sfx_shatter_player.name = "GlassShatterPlayer"
	sfx_shatter_player.stream = _shatter_stream
	sfx_shatter_player.volume_db = 0.0
	add_child(sfx_shatter_player)
	
	sfx_frame_player = AudioStreamPlayer.new()
	sfx_frame_player.name = "FrameHitPlayer"
	if ResourceLoader.exists("res://assets/audio/sfx/tree_hit.ogg"):
		sfx_frame_player.stream = load("res://assets/audio/sfx/tree_hit.ogg")
	elif ResourceLoader.exists("res://assets/audio/sfx/ball_hit_tree.mp3"):
		sfx_frame_player.stream = load("res://assets/audio/sfx/ball_hit_tree.mp3")
	sfx_frame_player.volume_db = 2.0
	add_child(sfx_frame_player)
	
	sfx_applause_player = AudioStreamPlayer.new()
	sfx_applause_player.name = "ApplausePlayer"
	if ResourceLoader.exists("res://assets/audio/golf_clap.mp3"):
		sfx_applause_player.stream = load("res://assets/audio/golf_clap.mp3")
	sfx_applause_player.volume_db = 3.0
	add_child(sfx_applause_player)


func _create_procedural_glass_shatter_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.75 # seconds
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2) # 16-bit mono
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 98765
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		
		# 1. Initial sharp crack / shockwave (exponential fast burst)
		var crack = rng.randf_range(-1.0, 1.0) * exp(-t * 85.0) * 0.95
		
		# 2. Crystalline resonant frequencies of glass shards shattering
		var f1 = sin(TAU * 2650.0 * t) * exp(-t * 14.0)
		var f2 = sin(TAU * 3820.0 * t + 0.5) * exp(-t * 18.0)
		var f3 = sin(TAU * 5140.0 * t + 1.2) * exp(-t * 24.0)
		var f4 = sin(TAU * 7200.0 * t + 2.1) * exp(-t * 30.0)
		var f5 = sin(TAU * 1250.0 * t) * exp(-t * 8.0)
		var crystal_ring = (f1 * 0.28 + f2 * 0.22 + f3 * 0.18 + f4 * 0.14 + f5 * 0.25)
		
		# 3. Cascading shards tinkling and falling
		var shard_tinkle = 0.0
		if t > 0.03:
			var noise = rng.randf_range(-1.0, 1.0)
			shard_tinkle = noise * exp(-(t - 0.03) * 6.5) * sin(TAU * (3000.0 + 1500.0 * sin(t * 40.0)) * t) * 0.35
			
		var mixed = clampf(crack + crystal_ring + shard_tinkle, -1.0, 1.0)
		var sample_16 = int(mixed * 32767.0)
		
		# Little-endian 16-bit integer encoding
		byte_array.encode_s16(i * 2, sample_16)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream


# ==============================================================================
# MATERIALS SETUP
# ==============================================================================

func _init_materials() -> void:
	# Intact Glass: Glossy sky-reflective tinted blue glass
	glass_mat_intact = StandardMaterial3D.new()
	glass_mat_intact.albedo_color = Color(0.28, 0.56, 0.78, 0.44)
	glass_mat_intact.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat_intact.roughness = 0.04
	glass_mat_intact.metallic = 0.88
	glass_mat_intact.clearcoat_enabled = true
	glass_mat_intact.clearcoat = 1.0
	glass_mat_intact.clearcoat_roughness = 0.04
	glass_mat_intact.emission_enabled = true
	glass_mat_intact.emission = Color(0.12, 0.36, 0.55)
	glass_mat_intact.emission_energy_multiplier = 0.18
	glass_mat_intact.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Broken Glass Edge Rim: Glowing green fractured remnant frame
	glass_mat_broken_rim = StandardMaterial3D.new()
	glass_mat_broken_rim.albedo_color = Color(0.2, 0.85, 0.35, 0.65)
	glass_mat_broken_rim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat_broken_rim.roughness = 0.3
	glass_mat_broken_rim.emission_enabled = true
	glass_mat_broken_rim.emission = Color(0.2, 0.9, 0.4)
	glass_mat_broken_rim.emission_energy_multiplier = 0.6
	
	# Structural Steel Truss Frame: Dark gunmetal architectural steel
	frame_mat_steel = StandardMaterial3D.new()
	frame_mat_steel.albedo_color = Color(0.18, 0.21, 0.25)
	frame_mat_steel.metallic = 0.86
	frame_mat_steel.roughness = 0.32
	
	# Concrete / Heavy Steel Base Pads
	frame_mat_concrete = StandardMaterial3D.new()
	frame_mat_concrete.albedo_color = Color(0.24, 0.26, 0.29)
	frame_mat_concrete.metallic = 0.25
	frame_mat_concrete.roughness = 0.75
	
	# Tee box green turf (High-resolution PBR textures)
	turf_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/high/grass_green_albedo.png"):
		turf_mat.albedo_texture = load("res://Courses/Environments/high/grass_green_albedo.png")
		if ResourceLoader.exists("res://Courses/Environments/high/grass_green_normal.png"):
			turf_mat.normal_enabled = true
			turf_mat.normal_texture = load("res://Courses/Environments/high/grass_green_normal.png")
		if ResourceLoader.exists("res://Courses/Environments/high/grass_green_roughness.png"):
			turf_mat.roughness_texture = load("res://Courses/Environments/high/grass_green_roughness.png")
		turf_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	elif ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		turf_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		turf_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	else:
		turf_mat.albedo_color = Color(0.18, 0.65, 0.24)
	turf_mat.roughness = 0.88
	
	# Fairway grass
	fairway_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/grass-fairway/albedo.png"):
		fairway_mat.albedo_texture = load("res://Courses/Environments/grass-fairway/albedo.png")
		fairway_mat.uv1_scale = Vector3(0.08, 0.08, 0.08)
	else:
		fairway_mat.albedo_color = Color(0.22, 0.58, 0.26)
	fairway_mat.roughness = 0.92
	
	# Tic-Tac-Toe X Symbol: Luminous Electric Cyan
	x_symbol_mat = StandardMaterial3D.new()
	x_symbol_mat.albedo_color = Color(0.15, 0.85, 1.0, 0.95)
	x_symbol_mat.roughness = 0.15
	x_symbol_mat.metallic = 0.85
	x_symbol_mat.emission_enabled = true
	x_symbol_mat.emission = Color(0.15, 0.85, 1.0)
	x_symbol_mat.emission_energy_multiplier = 1.6
	
	# Tic-Tac-Toe O Symbol: Luminous Radiant Gold
	o_symbol_mat = StandardMaterial3D.new()
	o_symbol_mat.albedo_color = Color(1.0, 0.70, 0.15, 0.95)
	o_symbol_mat.roughness = 0.15
	o_symbol_mat.metallic = 0.85
	o_symbol_mat.emission_enabled = true
	o_symbol_mat.emission = Color(1.0, 0.70, 0.15)
	o_symbol_mat.emission_energy_multiplier = 1.6
	
	# Winning 3-in-a-row Highlight: Brilliant Neon Lime
	win_symbol_mat = StandardMaterial3D.new()
	win_symbol_mat.albedo_color = Color(0.25, 1.0, 0.45, 0.95)
	win_symbol_mat.roughness = 0.1
	win_symbol_mat.metallic = 0.6
	win_symbol_mat.emission_enabled = true
	win_symbol_mat.emission = Color(0.25, 1.0, 0.45)
	win_symbol_mat.emission_energy_multiplier = 2.8


func _init_player_names() -> void:
	player_x_name = "Player 1"
	player_o_name = "Player 2"
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.players.size() >= 2:
			player_x_name = mp.players[0].get("name", "Player 1")
			player_o_name = mp.players[1].get("name", "Player 2")
		elif mp.players.size() == 1:
			player_x_name = mp.players[0].get("name", "Player 1")
			player_o_name = "Player 2"


# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================

func _setup_environment() -> void:
	var sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-38)).rotated(Vector3.UP, deg_to_rad(38))
	sun.shadow_enabled = true
	sun.light_energy = 1.25
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
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.48, 0.82)
	sky_mat.sky_horizon_color = Color(0.55, 0.74, 0.90)
	sky_mat.ground_bottom_color = Color(0.16, 0.28, 0.18)
	sky_mat.ground_horizon_color = Color(0.55, 0.74, 0.90)
	sky_mat.sun_angle_max = 35.0
	sky.sky_material = sky_mat
	env.sky = sky
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.50
	env.ambient_light_sky_contribution = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.2
	env.ssao_power = 1.5
	env.ssao_detail = 0.2
	env.ssao_horizon = 0.06
	env.ssao_ao_channel_affect = 0.5
	
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.76, 0.85, 0.95)
	env.fog_density = 0.45
	env.fog_sky_affect = 0.15
	if "fog_depth_begin" in env:
		env.set("fog_depth_begin", 380.0)
	if "fog_depth_end" in env:
		env.set("fog_depth_end", 1500.0)
	if "fog_depth_curve" in env:
		env.set("fog_depth_curve", 1.6)
	
	world_env.environment = env
	add_child(world_env)
	
	# Main Camera
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.near = 0.05
	camera.far = 4000.0
	add_child(camera)
	if has_node("/root/TensionManager"):
		TensionManager.register_camera(camera, 55.0)
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.register_camera(camera)
		ScreenOffsetManager.on_ready_for_shot(0.0, true)
		
	_update_camera_to_tee()


func _update_camera_to_tee() -> void:
	if camera == null:
		return
	viewing_wall_cam = false
	var ball_pos = player.ball.global_position if player and player.ball else Vector3(0.0, 0.05, 0.0)
	camera.global_position = ball_pos + Vector3(-5.5, 2.4, 0.0)
	camera.look_at(Vector3(WALL_DIST_X, 15.0, 0.0))
	last_camera_offset = camera.global_position - ball_pos
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.set_suppressed(false)
		ScreenOffsetManager.on_ready_for_shot()


func _update_camera_to_wall_cam() -> void:
	if camera == null:
		return
	viewing_wall_cam = true
	camera.global_position = Vector3(WALL_DIST_X - 22.0, 15.0, -16.0)
	camera.look_at(Vector3(WALL_DIST_X, 15.0, 0.0))
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.set_suppressed(true)


func _toggle_camera_view() -> void:
	if viewing_wall_cam:
		_update_camera_to_tee()
		if cam_toggle_btn:
			cam_toggle_btn.text = "🎥 Wall Cam (C)"
	else:
		_update_camera_to_wall_cam()
		if cam_toggle_btn:
			cam_toggle_btn.text = "🏌️ Tee Cam (C)"


# ==============================================================================
# RANGE TERRAIN & DISTANCE MARKERS
# ==============================================================================

func _get_terrain_height(x: float, z: float) -> float:
	# Keep the central hitting corridor and tee box flat at y = 0.0
	var lat_dist = maxf(0.0, absf(z) - 26.0)
	var lat_blend = smoothstep(0.0, 48.0, lat_dist)
	var far_blend = smoothstep(135.0, 280.0, x)
	var back_blend = smoothstep(-16.0, -70.0, x)
	var hill_blend = maxf(lat_blend, maxf(far_blend, back_blend))
	if hill_blend <= 0.001:
		return 0.0
	var wave_1 = sin(x * 0.018 + 0.4) * cos(z * 0.022) * 3.2
	var wave_2 = sin(x * 0.041 - z * 0.031) * 1.6
	var far_ridge = smoothstep(170.0, 380.0, x) * (10.0 + sin(z * 0.017) * 5.0)
	var base_rise = 5.5 + wave_1 + wave_2 + far_ridge
	return maxf(0.0, base_rise) * hill_blend


func _setup_range_ground() -> void:
	# 1. Sculpted Rolling Range Terrain (Always High Quality realistic turf shader)
	var min_x := -120.0
	var max_x := 460.0
	var min_z := -360.0
	var max_z := 360.0
	var subdiv_x := 160
	var subdiv_z := 120
	var cell_w := (max_x - min_x) / subdiv_x
	var cell_d := (max_z - min_z) / subdiv_z

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ground_mat: Material = fairway_mat
	var shader = load("res://Courses/Environments/shaders/driving_range_turf_realistic.gdshader")
	if shader == null:
		shader = load("res://Courses/Environments/shaders/driving_range_turf.gdshader")
	var fw_albedo := "res://Courses/Environments/high/grass_fairway_albedo.png" if ResourceLoader.exists("res://Courses/Environments/high/grass_fairway_albedo.png") else "res://Courses/Environments/grass-fairway/albedo.png"
	var fw_normal := "res://Courses/Environments/high/grass_fairway_normal.png" if ResourceLoader.exists("res://Courses/Environments/high/grass_fairway_normal.png") else "res://Courses/Environments/grass-fairway/normal.png"
	var fw_rough := "res://Courses/Environments/high/grass_fairway_roughness.png" if ResourceLoader.exists("res://Courses/Environments/high/grass_fairway_roughness.png") else "res://Courses/Environments/grass-fairway/roughness.png"
	var rg_albedo := "res://Courses/Environments/high/grass_rough_albedo.png" if ResourceLoader.exists("res://Courses/Environments/high/grass_rough_albedo.png") else "res://Courses/Environments/grass-rough/albedo.png"
	var rg_normal := "res://Courses/Environments/high/grass_rough_normal.png" if ResourceLoader.exists("res://Courses/Environments/high/grass_rough_normal.png") else "res://Courses/Environments/grass-rough/normal.png"
	var rg_rough := "res://Courses/Environments/high/grass_rough_roughness.png" if ResourceLoader.exists("res://Courses/Environments/high/grass_rough_roughness.png") else "res://Courses/Environments/grass-rough/roughness.png"
	if shader != null and ResourceLoader.exists(fw_albedo) and ResourceLoader.exists(rg_albedo):
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("tex_fairway", load(fw_albedo))
		if ResourceLoader.exists(fw_normal):
			sm.set_shader_parameter("normal_fairway", load(fw_normal))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/ao.png"):
			sm.set_shader_parameter("ao_fairway", load("res://Courses/Environments/grass-fairway/ao.png"))
		if ResourceLoader.exists(fw_rough):
			sm.set_shader_parameter("roughness_fairway", load(fw_rough))
		sm.set_shader_parameter("tex_rough", load(rg_albedo))
		if ResourceLoader.exists(rg_normal):
			sm.set_shader_parameter("normal_rough", load(rg_normal))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/ao.png"):
			sm.set_shader_parameter("ao_rough", load("res://Courses/Environments/grass-rough/ao.png"))
		if ResourceLoader.exists(rg_rough):
			sm.set_shader_parameter("roughness_rough", load(rg_rough))
		sm.set_shader_parameter("corridor_half_width", 24.0)
		sm.set_shader_parameter("blend_margin", 2.5)
		sm.set_shader_parameter("tee_start_x", -10.0)
		sm.set_shader_parameter("tee_blend_x", 4.0)
		sm.set_shader_parameter("max_range_dist", 260.0)
		sm.set_shader_parameter("uv_scale_fairway", 0.40)
		sm.set_shader_parameter("uv_scale_rough", 0.34)
		sm.set_shader_parameter("normal_depth", 0.85)
		sm.set_shader_parameter("stripe_strength", 0.65)
		ground_mat = sm
	st.set_material(ground_mat)

	for zi in range(subdiv_z):
		for xi in range(subdiv_x):
			var x0 := min_x + xi * cell_w
			var x1 := x0 + cell_w
			var z0 := min_z + zi * cell_d
			var z1 := z0 + cell_d

			var p00 := Vector3(x0, _get_terrain_height(x0, z0), z0)
			var p10 := Vector3(x1, _get_terrain_height(x1, z0), z0)
			var p01 := Vector3(x0, _get_terrain_height(x0, z1), z1)
			var p11 := Vector3(x1, _get_terrain_height(x1, z1), z1)

			var uv00 := Vector2(x0, z0) * 0.05
			var uv10 := Vector2(x1, z0) * 0.05
			var uv01 := Vector2(x0, z1) * 0.05
			var uv11 := Vector2(x1, z1) * 0.05

			st.set_uv(uv00)
			st.add_vertex(p00)
			st.set_uv(uv10)
			st.add_vertex(p10)
			st.set_uv(uv01)
			st.add_vertex(p01)

			st.set_uv(uv10)
			st.add_vertex(p10)
			st.set_uv(uv11)
			st.add_vertex(p11)
			st.set_uv(uv01)
			st.add_vertex(p01)

	st.generate_normals()
	st.generate_tangents()

	var terrain_mesh := st.commit()
	var ground_mesh_inst := MeshInstance3D.new()
	ground_mesh_inst.name = "RangeFairwayGround"
	ground_mesh_inst.mesh = terrain_mesh
	ground_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_mesh_inst)

	var ground := StaticBody3D.new()
	ground.name = "RangeGroundBody"
	ground.set_meta("surface_type", 1) # FAIRWAY
	ground_mesh_inst.add_child(ground)

	var ground_col := CollisionShape3D.new()
	ground_col.shape = terrain_mesh.create_trimesh_shape()
	ground.add_child(ground_col)

	# 2. Tee Box Hitting Mat & Frame
	var tee := StaticBody3D.new()
	tee.name = "TeeBox"
	tee.set_meta("surface_type", 3) # TEE
	add_child(tee)

	var tee_col := CollisionShape3D.new()
	var tee_box_shape := BoxShape3D.new()
	tee_box_shape.size = Vector3(6.0, 0.2, 6.0)
	tee_col.shape = tee_box_shape
	tee_col.position = Vector3(0.0, -0.1, 0.0)
	tee.add_child(tee_col)

	var tee_border_inst := MeshInstance3D.new()
	tee_border_inst.name = "TeeMatBorder"
	var tee_border_mesh := BoxMesh.new()
	tee_border_mesh.size = Vector3(6.5, 0.16, 6.5)
	tee_border_inst.mesh = tee_border_mesh
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.11, 0.15, 0.12)
	border_mat.roughness = 0.92
	tee_border_inst.material_override = border_mat
	tee_border_inst.position = Vector3(0.0, -0.09, 0.0)
	tee.add_child(tee_border_inst)

	var tee_mesh_inst := MeshInstance3D.new()
	tee_mesh_inst.name = "TeeMatTurf"
	var tee_mesh := BoxMesh.new()
	tee_mesh.size = Vector3(6.0, 0.2, 6.0)
	tee_mesh_inst.mesh = tee_mesh
	tee_mesh_inst.material_override = turf_mat
	tee_mesh_inst.position = Vector3(0.0, -0.095, 0.0)
	tee.add_child(tee_mesh_inst)

	for marker_z in [-1.8, 1.8]:
		var tm := MeshInstance3D.new()
		var tm_mesh := CylinderMesh.new()
		tm_mesh.top_radius = 0.09
		tm_mesh.bottom_radius = 0.11
		tm_mesh.height = 0.14
		tm.mesh = tm_mesh
		var tm_mat := StandardMaterial3D.new()
		tm_mat.albedo_color = Color(0.92, 0.94, 0.96)
		tm_mat.roughness = 0.4
		tm.material_override = tm_mat
		tm.position = Vector3(-0.4, 0.06, marker_z)
		tee.add_child(tm)

	# 3. Clean Fairway Distance Stripe Lines (25, 50, 75, 100, 125 Yards)
	var distances_yards = [25, 50, 75, 100, 125]
	for yard in distances_yards:
		var dist_m = yard * 0.9144
		_create_yardage_stripe(dist_m)

	# 4. High-Quality Volumetric 3D Trees & Distant Mountain Horizon
	_spawn_range_trees()
	_spawn_mountain_backdrop()
	MobilePerformance.apply_graphics_quality(self, "High")


func _create_yardage_stripe(dist_x: float) -> void:
	var marker_node = Node3D.new()
	marker_node.name = "Stripe_%.1fm" % dist_x
	marker_node.position = Vector3(dist_x, 0.0, 0.0)
	add_child(marker_node)

	var line_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(0.24, 46.0)
	line_mesh.mesh = plane
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.96, 0.97, 0.98, 0.55)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.render_priority = 2
	line_mesh.material_override = line_mat
	line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_mesh.position = Vector3(0.0, 0.015, 0.0)
	marker_node.add_child(line_mesh)


func _spawn_range_trees() -> void:
	var trees_root = Node3D.new()
	trees_root.name = "RangeTrees"
	add_child(trees_root)

	var tree_paths: Array[String] = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-2-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-2-staticbody.tscn",
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

	var rng := RandomNumberGenerator.new()
	rng.seed = 4075
	var step_x := 11.0
	var tree_idx := 0

	# Left and right hillside tree belts
	for side: float in [-1.0, 1.0]:
		var cx := -15.0
		while cx <= 255.0:
			var z_inner: float = side * rng.randf_range(38.0, 52.0)
			var z_outer: float = side * rng.randf_range(58.0, 88.0)
			for tz in [z_inner, z_outer]:
				var tx := cx + rng.randf_range(-4.0, 4.0)
				var ty := _get_terrain_height(tx, tz) - 0.15
				var inst := tree_scenes[rng.randi() % tree_scenes.size()].instantiate() as Node3D
				if inst:
					inst.name = "Tree_%d" % tree_idx
					inst.position = Vector3(tx, ty, tz)
					inst.rotation.y = rng.randf_range(0.0, TAU)
					var s := rng.randf_range(1.25, 2.15)
					inst.scale = Vector3(s, s, s)
					trees_root.add_child(inst)
					tree_idx += 1
			cx += step_x

	# Far hillside treeline behind the target wall
	var step_z := 11.0
	var cz := -120.0
	while cz <= 120.0:
		var tx := rng.randf_range(185.0, 265.0)
		var tz := cz + rng.randf_range(-3.5, 3.5)
		var ty := _get_terrain_height(tx, tz) - 0.15
		var inst := tree_scenes[rng.randi() % tree_scenes.size()].instantiate() as Node3D
		if inst:
			inst.name = "RangeTree_%d" % tree_idx
			inst.position = Vector3(tx, ty, tz)
			inst.rotation.y = rng.randf_range(0.0, TAU)
			var s := rng.randf_range(1.4, 2.35)
			inst.scale = Vector3(s, s, s)
			trees_root.add_child(inst)
			tree_idx += 1
		cz += step_z

	# Convert trees into spatial-chunked MultiMeshInstance3D and upgrade to HighFidelity volumetric 3D trees
	if ResourceLoader.exists("res://HighFidelity/Foliage/procedural_tree_generator.gd"):
		var ptg = load("res://HighFidelity/Foliage/procedural_tree_generator.gd")
		if ptg != null:
			ptg.convert_scene_foliage_to_multimesh(trees_root, false)
			var mm_container = trees_root.get_node_or_null("MultiMeshFoliageContainer")
			if mm_container != null:
				ptg.upgrade_existing_multimesh_trees(mm_container)


func _spawn_mountain_backdrop() -> void:
	var tex_path := "res://Courses/Environments/mountain_backdrop_seamless.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex = load(tex_path)
	if tex == null:
		return

	var mountain_root = Node3D.new()
	mountain_root.name = "MountainBackdrop"
	add_child(mountain_root)

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.88, 0.93, 0.98)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	var center_x := 30.0
	var radius := 420.0
	var y_bottom := -6.0
	var y_top := 135.0
	var segments := 72
	var angle_start := deg_to_rad(-130.0)
	var angle_end := deg_to_rad(130.0)
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
	mesh_inst.name = "MountainMesh"
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mountain_root.add_child(mesh_inst)


# ==============================================================================
# 75-YARD WALL & 3x3 CLEAN SQUARE GLASS GRID GENERATION (NO 3D TEXT)
# ==============================================================================

func _setup_glass_wall_and_panes() -> void:
	var wall_root = Node3D.new()
	wall_root.name = "LoftTargetWall"
	wall_root.position = Vector3(WALL_DIST_X, 0.0, 0.0)
	add_child(wall_root)
	
	pane_nodes.clear()
	pane_mesh_instances.clear()
	pane_areas.clear()
	symbol_3d_nodes.clear()
	for i in range(9):
		symbol_3d_nodes.append(null)
	
	# 1. Outer Structural Steel Columns & Header Beams (dark gunmetal architectural frame)
	for cz in [-14.2, 14.2]:
		var outer_col = _create_steel_beam(Vector3(0.0, 15.0, cz), Vector3(1.3, 30.0, 1.3))
		wall_root.add_child(outer_col)
		# Flanged front/back steel plates for I-beam depth
		var flange = _create_steel_beam(Vector3(0.0, 15.0, cz), Vector3(1.65, 30.0, 0.45))
		wall_root.add_child(flange)

	# Top & Bottom Structural Steel Header Beams
	var bot_beam = _create_steel_beam(Vector3(0.0, 0.9, 0.0), Vector3(1.3, 1.3, 29.7))
	wall_root.add_child(bot_beam)

	var top_beam = _create_steel_beam(Vector3(0.0, 29.5, 0.0), Vector3(1.5, 1.4, 30.2))
	wall_root.add_child(top_beam)
	
	# 2. Steel Divider Mullions between 3x3 square cells (Solid bounce StaticBody3D)
	# Vertical mullions (at Z = -4.65m and Z = +4.65m)
	for vz in [-4.65, 4.65]:
		var v_mullion = _create_steel_beam(Vector3(0.0, 15.0, vz), Vector3(0.85, 28.4, 0.75))
		wall_root.add_child(v_mullion)
		
	# Horizontal mullions (between rows at Y = 10.65m and Y = 19.95m)
	for hy in [10.65, 19.95]:
		var h_mullion = _create_steel_beam(Vector3(0.0, hy, 0.0), Vector3(0.85, 0.75, 28.4))
		wall_root.add_child(h_mullion)
		
	# 3. Structural Base Anchor Feet, Gussets & Rear Diagonal Support Struts
	for z_col in [-14.2, -4.65, 4.65, 14.2]:
		# Ground anchor footplate extending forward and backward
		var foot_pad = _create_concrete_pillar(Vector3(0.4, 0.18, z_col), Vector3(3.8, 0.36, 1.85))
		wall_root.add_child(foot_pad)
		# Front & rear angled gusset brackets
		var front_gusset = _create_steel_beam(Vector3(-0.9, 0.85, z_col), Vector3(0.95, 1.1, 0.45))
		wall_root.add_child(front_gusset)
		var rear_gusset = _create_steel_beam(Vector3(1.1, 0.85, z_col), Vector3(1.1, 1.1, 0.45))
		wall_root.add_child(rear_gusset)
		# Angled rear steel brace from y=8.5 down to ground anchor at x=6.0
		var rear_strut = _create_steel_beam(Vector3(3.2, 4.4, z_col), Vector3(0.35, 10.2, 0.35))
		rear_strut.rotation.z = deg_to_rad(34.0)
		wall_root.add_child(rear_strut)
		var rear_anchor = _create_concrete_pillar(Vector3(5.8, 0.18, z_col), Vector3(1.6, 0.36, 1.4))
		wall_root.add_child(rear_anchor)
		
	# 4. Generate 9 Clean SQUARE Glass Panes in 3x3 Grid
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx = row * GRID_COLS + col
			var py = ROW_Y_CENTERS[row]
			var pz = COL_Z_CENTERS[col]
			
			var pane_node = _create_glass_pane_node(idx, py, pz)
			wall_root.add_child(pane_node)
			pane_nodes.append(pane_node)


func _create_glass_pane_node(idx: int, py: float, pz: float) -> Node3D:
	var pane_root = Node3D.new()
	pane_root.name = "GlassPane_%d" % idx
	pane_root.position = Vector3(0.0, py, pz)
	
	# Clean SQUARE Glass Visual Mesh (PANE_SIZE x PANE_SIZE)
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "GlassMesh"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(PANE_DEPTH, PANE_SIZE - 0.2, PANE_SIZE - 0.2)
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = glass_mat_intact
	pane_root.add_child(mesh_inst)
	pane_mesh_instances.append(mesh_inst)
	
	# Crisp Dark Inner Window Gasket Frame (4 perimeter strips, leaving glass face clear)
	var trim_half := (PANE_SIZE - 0.25) * 0.5
	var trim_thick := 0.24
	var trim_depth := PANE_DEPTH + 0.14
	var trim_specs = [
		[Vector3(0.0, trim_half, 0.0), Vector3(trim_depth, trim_thick, PANE_SIZE)],
		[Vector3(0.0, -trim_half, 0.0), Vector3(trim_depth, trim_thick, PANE_SIZE)],
		[Vector3(0.0, 0.0, -trim_half), Vector3(trim_depth, PANE_SIZE, trim_thick)],
		[Vector3(0.0, 0.0, trim_half), Vector3(trim_depth, PANE_SIZE, trim_thick)],
	]
	for spec in trim_specs:
		var trim_inst := MeshInstance3D.new()
		var trim_mesh := BoxMesh.new()
		trim_mesh.size = spec[1]
		trim_inst.mesh = trim_mesh
		trim_inst.position = spec[0]
		trim_inst.material_override = frame_mat_steel
		pane_root.add_child(trim_inst)
	
	# Area3D Trigger Volume sized inside the cell bounds
	var area = Area3D.new()
	area.name = "PaneArea_%d" % idx
	area.set_meta("pane_index", idx)
	area.monitoring = true
	area.monitorable = true
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.5, PANE_SIZE - 0.4, PANE_SIZE - 0.4)
	col_shape.shape = box_shape
	area.add_child(col_shape)
	
	area.body_entered.connect(_on_pane_body_entered.bind(idx))
	
	pane_root.add_child(area)
	pane_areas.append(area)
	
	return pane_root


func _spawn_3d_symbol(idx: int, symbol: String) -> void:
	if idx < 0 or idx >= pane_nodes.size() or pane_nodes[idx] == null:
		return
		
	# Clear previous symbol instance at this index if present
	if idx < symbol_3d_nodes.size() and symbol_3d_nodes[idx] != null and is_instance_valid(symbol_3d_nodes[idx]):
		symbol_3d_nodes[idx].queue_free()
		symbol_3d_nodes[idx] = null
		
	var pane_root = pane_nodes[idx]
	var symbol_node = Node3D.new()
	symbol_node.name = "Symbol3D_%d_%s" % [idx, symbol]
	symbol_node.position = Vector3(-0.08, 0.0, 0.0) # Position slightly in front of pane toward tee
	
	if symbol == "X":
		var bar1 = MeshInstance3D.new()
		bar1.name = "X_Bar1"
		var box1 = BoxMesh.new()
		box1.size = Vector3(0.35, 7.2, 0.85)
		bar1.mesh = box1
		bar1.material_override = x_symbol_mat
		bar1.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(45))
		symbol_node.add_child(bar1)
		
		var bar2 = MeshInstance3D.new()
		bar2.name = "X_Bar2"
		var box2 = BoxMesh.new()
		box2.size = Vector3(0.35, 7.2, 0.85)
		bar2.mesh = box2
		bar2.material_override = x_symbol_mat
		bar2.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-45))
		symbol_node.add_child(bar2)
	elif symbol == "O":
		var ring = MeshInstance3D.new()
		ring.name = "O_Ring"
		var torus = TorusMesh.new()
		torus.inner_radius = 2.2
		torus.outer_radius = 3.2
		torus.rings = 36
		torus.ring_segments = 12
		ring.mesh = torus
		ring.material_override = o_symbol_mat
		# Torus default orientation is in X-Z plane; rotate 90 degrees around Z axis so its normal points along X towards tee
		ring.transform.basis = Basis(Vector3(0, 0, 1), deg_to_rad(90))
		symbol_node.add_child(ring)
		
	pane_root.add_child(symbol_node)
	if idx < symbol_3d_nodes.size():
		symbol_3d_nodes[idx] = symbol_node


func _highlight_winning_symbols() -> void:
	for idx in winning_line:
		if idx >= 0 and idx < symbol_3d_nodes.size() and symbol_3d_nodes[idx] != null:
			for child in symbol_3d_nodes[idx].get_children():
				if child is MeshInstance3D:
					child.material_override = win_symbol_mat


func _check_tic_tac_toe_game_over() -> bool:
	for combo in WIN_COMBOS:
		var s0 = board_marks[combo[0]]
		if s0 != "" and s0 == board_marks[combo[1]] and s0 == board_marks[combo[2]]:
			winner_symbol = s0
			winning_line = combo.duplicate()
			_highlight_winning_symbols()
			_trigger_victory()
			var win_player_name = player_x_name if winner_symbol == "X" else player_o_name
			_show_game_over_banner(
				"🎉 %s (%s) WINS!" % [win_player_name.to_upper(), winner_symbol],
				"3 In A Row! Magnificent loft control!",
				Color(0.2, 0.95, 0.4)
			)
			return true
			
	# Check for Draw / Cat's game
	if not board_marks.has(""):
		is_draw = true
		_show_game_over_banner(
			"🤝 CAT'S GAME - DRAW!",
			"All 9 glass panes claimed without 3 in a row.",
			Color(1.0, 0.75, 0.2)
		)
		return true
		
	return false


func _create_concrete_pillar(pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.set_meta("surface_type", 2) # Solid bounce
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	sb.add_child(col)
	
	var mi = MeshInstance3D.new()
	var mesh_box = BoxMesh.new()
	mesh_box.size = size
	mi.mesh = mesh_box
	mi.material_override = frame_mat_concrete
	sb.add_child(mi)
	return sb


func _create_steel_beam(pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.set_meta("surface_type", 2) # Solid bounce
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	sb.add_child(col)
	
	var mi = MeshInstance3D.new()
	var mesh_box = BoxMesh.new()
	mesh_box.size = size
	mi.mesh = mesh_box
	mi.material_override = frame_mat_steel
	sb.add_child(mi)
	return sb


# ==============================================================================
# PLAYER SETUP
# ==============================================================================

func _setup_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	var start_pos = Vector3(0.0, 0.05, 0.0)
	player.global_position = start_pos
	
	player.set_process(false)
	player.rest.connect(_on_ball_rest)
	
	player.ball.spawn_position = start_pos
	if player.has_method("set_profile"):
		var active_prof = (player_x_name if current_turn_symbol == "X" else player_o_name) if tic_tac_toe_mode else (MultiplayerManager.get_default_range_profile_name() if has_node("/root/MultiplayerManager") and MultiplayerManager.has_method("get_default_range_profile_name") else "")
		if not active_prof.is_empty():
			player.set_profile(active_prof)
	player.ball.reset()
	prev_ball_pos = start_pos


# ==============================================================================
# INPUT & HIT SIMULATION
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_settings()
			get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_reset_game()
		elif event.keycode == KEY_C:
			_toggle_camera_view()


func _on_launch_monitor_hit_ball(data: Dictionary) -> void:
	if player == null or player.ball == null:
		return
	if player.ball.state != PhysicsEnums.BallState.REST:
		return
		
	var speed_val: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var shot_type = str(data.get("ShotType", "")).to_lower()
	if speed_val <= 0.1 or shot_type == "practice":
		print("[LoftControl] Practice swing or 0 ball speed ignored.")
		return

	FoamBallBoost.apply_boost(data)
	PowerCalibration.apply_calibration(data)

	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")
		
	shot_counter += 1
	attempts_count += 1
	shot_reset_token += 1
	shot_in_progress = true
	var this_shot = shot_reset_token
	if has_node("/root/ScreenOffsetManager"):
		ScreenOffsetManager.on_shot_started()
	prev_ball_pos = player.ball.global_position
	
	# If currently on wall cam, switch back to tee follow cam on shot hit
	if viewing_wall_cam:
		_update_camera_to_tee()
		
	player._on_tcp_client_hit_ball(data)
	raw_ball_data = data.duplicate()
	_update_stats_display(false)
	_update_hud()
	
	# Maximum safety timeout: automatically resets ball to tee after 5.0 seconds if not already reset
	_schedule_auto_reset(this_shot, 5.0)


func _schedule_auto_reset(shot_id: int, delay_sec: float) -> void:
	await get_tree().create_timer(delay_sec).timeout
	if is_inside_tree() and shot_reset_token == shot_id:
		_reset_ball_only()


# ==============================================================================
# PHYSICS PROCESS & CONTINUOUS WALL INTERSECTION TRACKING
# ==============================================================================

func _physics_process(delta: float) -> void:
	if player == null or player.ball == null:
		return
		
	var ball = player.ball
	var ball_state = ball.state
	var curr_pos = ball.global_position
	
	# Smooth Camera Follow
	if ball_state == PhysicsEnums.BallState.FLIGHT or ball_state == PhysicsEnums.BallState.ROLLOUT:
		camera_following = true
		
		# If within 25m of the 75-yard wall, frame both ball and target wall
		var target_cam_pos: Vector3
		if curr_pos.x > (WALL_DIST_X - 25.0):
			# Wide suspense angle framing wall and impact
			target_cam_pos = Vector3(curr_pos.x - 7.0, max(curr_pos.y + 2.5, 4.5), curr_pos.z * 0.5)
			camera.global_position = camera.global_position.lerp(target_cam_pos, delta * 6.0)
			camera.look_at(Vector3(WALL_DIST_X, 15.0, 0.0))
		else:
			target_cam_pos = curr_pos + last_camera_offset
			camera.global_position = camera.global_position.lerp(target_cam_pos, delta * 8.0)
			camera.look_at(curr_pos + Vector3(10.0, 0.0, 0.0))
			
		# CONTINUOUS COLLISION DETECTION AT X = 68.58m (75 YARDS)
		# Checks if line segment between previous ball position and current ball position intersects the wall plane
		if (prev_ball_pos.x < WALL_DIST_X and curr_pos.x >= (WALL_DIST_X - 1.0)) or (prev_ball_pos.x <= (WALL_DIST_X + 1.0) and curr_pos.x >= (WALL_DIST_X - 1.0) and absf(curr_pos.x - WALL_DIST_X) < 2.0):
			_check_wall_intersection(prev_ball_pos, curr_pos, ball.velocity)
			
	else:
		if camera_following:
			camera_following = false
			if not viewing_wall_cam:
				_update_camera_to_tee()
				
	prev_ball_pos = curr_pos


func _on_pane_body_entered(body: Node3D, pane_idx: int) -> void:
	if player == null or player.ball == null:
		return
		
	# ONLY the player's golf ball can break the glass!
	var is_ball = (body == player.ball or body == player or (body is CharacterBody3D and body.name.to_lower().contains("ball")))
	if not is_ball:
		return
		
	if not panes_broken[pane_idx]:
		var impact_pos = player.ball.global_position
		impact_pos.x = WALL_DIST_X
		var vel = player.ball.velocity
		_shatter_pane(pane_idx, impact_pos, vel)


func _check_wall_intersection(p0: Vector3, p1: Vector3, vel: Vector3) -> void:
	var dx = p1.x - p0.x
	var impact_y: float
	var impact_z: float
	
	if absf(dx) > 0.0001:
		var t = clampf((WALL_DIST_X - p0.x) / dx, 0.0, 1.0)
		impact_y = lerp(p0.y, p1.y, t)
		impact_z = lerp(p0.z, p1.z, t)
	else:
		impact_y = p1.y
		impact_z = p1.z
		
	var impact_pos = Vector3(WALL_DIST_X, impact_y, impact_z)
	
	# Determine if impact hits any of the 3x3 square panes
	var hit_pane_idx = -1
	var half_size = PANE_SIZE / 2.0
	
	for row in range(GRID_ROWS):
		var r_center_y = ROW_Y_CENTERS[row]
		if impact_y >= (r_center_y - half_size) and impact_y <= (r_center_y + half_size):
			for col in range(GRID_COLS):
				var c_center_z = COL_Z_CENTERS[col]
				if impact_z >= (c_center_z - half_size) and impact_z <= (c_center_z + half_size):
					hit_pane_idx = row * GRID_COLS + col
					break
			if hit_pane_idx != -1:
				break
				
	last_shot_data = {
		"Apex": player.apex if "apex" in player else impact_y,
		"LaunchAngle": impact_y,
		"TargetHit": PANE_NAMES[hit_pane_idx] if hit_pane_idx != -1 else "Frame / Miss",
		"ImpactPos": impact_pos
	}
	
	if hit_pane_idx != -1:
		if not panes_broken[hit_pane_idx]:
			# SHATTER UNBROKEN GLASS PANE!
			_shatter_pane(hit_pane_idx, impact_pos, vel)
		else:
			# Ball hit an already broken pane - reset after 2.0s so turn alternates
			var this_shot = shot_reset_token
			_schedule_auto_reset(this_shot, 2.0)
	else:
		# Check if hit solid outer frame or missed completely
		if impact_y >= 0.0 and impact_y <= 31.0 and absf(impact_z) <= 15.0:
			_on_frame_hit(impact_pos)


# ==============================================================================
# GLASS SHATTERING & IMPACT MECHANICS
# ==============================================================================

func _shatter_pane(idx: int, impact_pos: Vector3, vel: Vector3) -> void:
	if panes_broken[idx]:
		return
		
	panes_broken[idx] = true
	broken_count += 1
	
	# 1. Play shattering sound
	if sfx_shatter_player:
		sfx_shatter_player.pitch_scale = randf_range(0.96, 1.05)
		sfx_shatter_player.play()
		
	# 2. Hide intact glass visual mesh
	if idx < pane_mesh_instances.size() and pane_mesh_instances[idx] != null:
		pane_mesh_instances[idx].visible = false
		
	# 3. Spawn 3D exploding glass shard debris
	_spawn_glass_shards(impact_pos, vel)
	
	# 4. In Tic-Tac-Toe mode, place symbol & check win/draw
	if tic_tac_toe_mode:
		board_marks[idx] = current_turn_symbol
		_spawn_3d_symbol(idx, current_turn_symbol)
		_check_tic_tac_toe_game_over()
	else:
		# 5. Check Victory Condition in Standard Mode (All 9 Panes Broken!)
		if broken_count >= 9:
			_trigger_victory()
			
	# 6. Update HUD Matrix & Scoreboard
	_update_hud()
		
	# Automatically reset ball to tee box after 2.0 seconds
	var this_shot = shot_reset_token
	_schedule_auto_reset(this_shot, 2.0)


func _spawn_glass_shards(impact_pos: Vector3, incoming_vel: Vector3) -> void:
	var shards_root = Node3D.new()
	shards_root.name = "GlassShardsBurst"
	shards_root.position = impact_pos
	add_child(shards_root)
	
	var shard_count = 32
	var shard_meshes: Array[MeshInstance3D] = []
	var shard_velocities: Array[Vector3] = []
	var shard_rot_speeds: Array[Vector3] = []
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var fwd_dir = incoming_vel.normalized() if incoming_vel.length() > 1.0 else Vector3(1.0, 0.0, 0.0)
	
	for i in range(shard_count):
		var sm = MeshInstance3D.new()
		var prism = PrismMesh.new()
		var s_w = rng.randf_range(0.3, 0.7)
		var s_h = rng.randf_range(0.3, 0.8)
		prism.size = Vector3(s_w, s_h, 0.05)
		sm.mesh = prism
		
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.75)
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.roughness = 0.1
		s_mat.metallic = 0.8
		s_mat.emission_enabled = true
		s_mat.emission = Color(0.2, 0.6, 0.9)
		s_mat.emission_energy_multiplier = 0.5
		sm.material_override = s_mat
		
		# Offset slightly from impact center
		sm.position = Vector3(
			rng.randf_range(-0.1, 0.1),
			rng.randf_range(-1.2, 1.2),
			rng.randf_range(-1.2, 1.2)
		)
		shards_root.add_child(sm)
		shard_meshes.append(sm)
		
		# Velocity: forward push + outward burst
		var burst_dir = (fwd_dir * 0.7 + Vector3(rng.randf_range(-0.3, 0.8), rng.randf_range(-0.5, 0.8), rng.randf_range(-1.0, 1.0))).normalized()
		var speed = rng.randf_range(8.0, 22.0)
		shard_velocities.append(burst_dir * speed)
		shard_rot_speeds.append(Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)))
		
	# Cleanup shards after animation
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(shards_root):
			shards_root.queue_free()
	)


func _on_frame_hit(impact_pos: Vector3) -> void:
	if sfx_frame_player:
		sfx_frame_player.pitch_scale = randf_range(0.9, 1.1)
		sfx_frame_player.play()
	
	# Automatically reset ball to tee box after 2.0 seconds
	var this_shot = shot_reset_token
	_schedule_auto_reset(this_shot, 2.0)


func _trigger_victory() -> void:
	is_victory = true
	if sfx_applause_player:
		sfx_applause_player.play()
	if GlobalSettings:
		GlobalSettings.play_golf_clap()


func _on_ball_rest(_data: Dictionary) -> void:
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()
	raw_ball_data = _data.duplicate()
	_update_stats_display(true)
	_update_hud()
	
	# Auto reset ball to tee box after 1.8 seconds
	var this_shot = shot_reset_token
	await get_tree().create_timer(1.8).timeout
	if is_inside_tree() and shot_reset_token == this_shot:
		_reset_ball_only()


# ==============================================================================
# RESET MECHANICS
# ==============================================================================

func _reset_game() -> void:
	is_victory = false
	broken_count = 0
	attempts_count = 0
	shot_in_progress = false
	winner_symbol = ""
	is_draw = false
	winning_line.clear()
	current_turn_symbol = "X"
	_hide_game_over_banner()
	_init_player_names()
	_sync_launch_monitor_player()
	
	# Clear 3D symbols
	for i in range(symbol_3d_nodes.size()):
		if symbol_3d_nodes[i] != null and is_instance_valid(symbol_3d_nodes[i]):
			symbol_3d_nodes[i].queue_free()
			symbol_3d_nodes[i] = null
			
	for i in range(panes_broken.size()):
		panes_broken[i] = false
		board_marks[i] = ""
		
		# Restore visual glass mesh
		if i < pane_mesh_instances.size() and pane_mesh_instances[i] != null:
			pane_mesh_instances[i].visible = true
			
	_reset_ball_only()
	_update_hud()


func _reset_ball_only() -> void:
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
		
	if shot_in_progress:
		shot_in_progress = false
		if tic_tac_toe_mode and winner_symbol.is_empty() and not is_draw:
			current_turn_symbol = "O" if current_turn_symbol == "X" else "X"
			_sync_launch_monitor_player()
			
	if player and player.ball:
		var start_pos = Vector3(0.0, 0.05, 0.0)
		player.global_position = start_pos
		player.ball.spawn_position = start_pos
		if player.has_method("set_profile"):
			var active_prof = (player_x_name if current_turn_symbol == "X" else player_o_name) if tic_tac_toe_mode else (MultiplayerManager.get_default_range_profile_name() if has_node("/root/MultiplayerManager") and MultiplayerManager.has_method("get_default_range_profile_name") else "")
			if not active_prof.is_empty():
				player.set_profile(active_prof)
		player.ball.reset()
		player.reset_ball()
		player.ball.aim_yaw_offset_deg = 0.0
		prev_ball_pos = start_pos
		if not viewing_wall_cam:
			_update_camera_to_tee()

	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()
			
	_update_hud()


func _toggle_tic_tac_toe_mode() -> void:
	tic_tac_toe_mode = not tic_tac_toe_mode
	_hide_game_over_banner()
	if mode_toggle_btn != null:
		if tic_tac_toe_mode:
			mode_toggle_btn.text = "❌⭕ Tic-Tac-Toe: ON"
			_apply_btn_style(mode_toggle_btn, Color(0.18, 0.45, 0.65), Color(0.25, 0.58, 0.82))
		else:
			mode_toggle_btn.text = "❌⭕ Tic-Tac-Toe: OFF"
			_apply_btn_style(mode_toggle_btn, Color(0.20, 0.25, 0.35), Color(0.28, 0.35, 0.48))
	_reset_game()


func _show_game_over_banner(title: String, subtitle: String, theme_color: Color) -> void:
	if game_over_panel != null and is_instance_valid(game_over_panel):
		game_over_panel.queue_free()
		
	game_over_panel = PanelContainer.new()
	game_over_panel.name = "GameOverBanner"
	game_over_panel.custom_minimum_size = Vector2(580, 210)
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -290
	game_over_panel.offset_right = 290
	game_over_panel.offset_top = -105
	game_over_panel.offset_bottom = 105
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.12, 0.94)
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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	game_over_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 26)
	t_lbl.add_theme_color_override("font_color", theme_color)
	vbox.add_child(t_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(sub_lbl)
	
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


# ==============================================================================
# UI & HUD CREATION
# ==============================================================================

func _setup_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "LoftHUDLayer"
	hud_layer.layer = 1
	add_child(hud_layer)
	
	hud_control = Control.new()
	hud_control.name = "HUDControl"
	hud_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_control.anchor_right = 1.0
	hud_control.anchor_bottom = 1.0
	hud_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_control)
	
	# Shared Glass Style for HUD Cards
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
	
	# --- 1. TOP SCOREBOARD PANEL ---
	var score_panel = PanelContainer.new()
	score_panel.custom_minimum_size = Vector2(860, 90)
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.anchor_top = 0.0
	score_panel.offset_left = -430
	score_panel.offset_right = 430
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
	
	stat_columns.clear()
	panes_cleared_lbl = _create_stat_column(score_hbox, "PANES CLEARED", "0 / 9")
	panes_cleared_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	
	attempts_lbl = _create_stat_column(score_hbox, "TOTAL ATTEMPTS", "0")
	accuracy_lbl = _create_stat_column(score_hbox, "ACCURACY", "0.0%")
	last_shot_lbl = _create_stat_column(score_hbox, "LAST TARGET", "None")
	
	# --- 2. 3x3 LIVE MATRIX HUD CARD (RIGHT SIDE) ---
	var matrix_panel = PanelContainer.new()
	matrix_panel.custom_minimum_size = Vector2(250, 290)
	matrix_panel.anchor_left = 1.0
	matrix_panel.anchor_right = 1.0
	matrix_panel.anchor_top = 0.5
	matrix_panel.anchor_bottom = 0.5
	matrix_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	matrix_panel.offset_left = -274
	matrix_panel.offset_right = -24
	matrix_panel.offset_top = -145
	matrix_panel.offset_bottom = 145
	hud_control.add_child(matrix_panel)
	matrix_panel.add_theme_stylebox_override("panel", glass_style)

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
	stats_btn.custom_minimum_size = Vector2(56, 56)
	_apply_circular_button_style(stats_btn, Color(0.24, 0.46, 0.72, 0.85))
	stats_btn.anchor_left = 0.0
	stats_btn.anchor_right = 0.0
	stats_btn.anchor_top = 1.0
	stats_btn.anchor_bottom = 1.0
	stats_btn.offset_left = 30
	stats_btn.offset_top = -80
	stats_btn.offset_right = 86
	stats_btn.offset_bottom = -24
	stats_btn.pressed.connect(func():
		_toggle_stats_visibility()
	)
	hud_control.add_child(stats_btn)
	
	var matrix_margin = MarginContainer.new()
	matrix_margin.add_theme_constant_override("margin_left", 14)
	matrix_margin.add_theme_constant_override("margin_right", 14)
	matrix_margin.add_theme_constant_override("margin_top", 14)
	matrix_margin.add_theme_constant_override("margin_bottom", 14)
	matrix_panel.add_child(matrix_margin)
	
	var matrix_vbox = VBoxContainer.new()
	matrix_vbox.add_theme_constant_override("separation", 8)
	matrix_margin.add_child(matrix_vbox)
	
	matrix_title_lbl = Label.new()
	matrix_title_lbl.text = "3x3 GLASS TARGETS"
	matrix_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	matrix_title_lbl.add_theme_font_size_override("font_size", 16)
	matrix_title_lbl.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	matrix_vbox.add_child(matrix_title_lbl)
	
	# GridContainer with 3 columns for 9 buttons
	var grid_cont = GridContainer.new()
	grid_cont.columns = 3
	grid_cont.add_theme_constant_override("h_separation", 6)
	grid_cont.add_theme_constant_override("v_separation", 6)
	matrix_vbox.add_child(grid_cont)
	
	hud_matrix_buttons.clear()
	var short_names = ["1 TL", "2 TM", "3 TR", "4 ML", "5 MM", "6 MR", "7 BL", "8 BM", "9 BR"]
	for i in range(9):
		var btn = Button.new()
		btn.text = short_names[i]
		btn.custom_minimum_size = Vector2(78, 68)
		btn.add_theme_font_size_override("font_size", 16)
		_apply_matrix_btn_style(btn, i)
		btn.tooltip_text = "[%d] %s (%s)" % [i + 1, PANE_NAMES[i], PANE_DESCS[i]]
		grid_cont.add_child(btn)
		hud_matrix_buttons.append(btn)
		
	# --- 3. BOTTOM CONTROLS PANEL ---
	var ctrl_panel = PanelContainer.new()
	ctrl_panel.custom_minimum_size = Vector2(780, 76)
	ctrl_panel.anchor_left = 0.5
	ctrl_panel.anchor_right = 0.5
	ctrl_panel.anchor_top = 1.0
	ctrl_panel.anchor_bottom = 1.0
	ctrl_panel.offset_left = -390
	ctrl_panel.offset_right = 390
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
	
	# 1. Mode Toggle Button (Standard vs Tic-Tac-Toe)
	mode_toggle_btn = Button.new()
	mode_toggle_btn.text = "❌⭕ Tic-Tac-Toe: OFF"
	mode_toggle_btn.custom_minimum_size = Vector2(190, 52)
	mode_toggle_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(mode_toggle_btn, Color(0.20, 0.25, 0.35), Color(0.28, 0.35, 0.48))
	mode_toggle_btn.pressed.connect(_toggle_tic_tac_toe_mode)
	ctrl_hbox.add_child(mode_toggle_btn)
	
	# 2. Reset Button
	var reset_btn = Button.new()
	reset_btn.text = "🔄 RESET (R)"
	reset_btn.custom_minimum_size = Vector2(140, 52)
	reset_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(reset_btn, Color(0.55, 0.22, 0.15), Color(0.70, 0.30, 0.20))
	reset_btn.pressed.connect(_reset_game)
	ctrl_hbox.add_child(reset_btn)
	
	# 3. Camera Toggle Button
	cam_toggle_btn = Button.new()
	cam_toggle_btn.text = "🎥 Wall Cam (C)"
	cam_toggle_btn.custom_minimum_size = Vector2(145, 52)
	cam_toggle_btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(cam_toggle_btn, Color(0.18, 0.34, 0.50), Color(0.24, 0.44, 0.65))
	cam_toggle_btn.pressed.connect(_toggle_camera_view)
	ctrl_hbox.add_child(cam_toggle_btn)
	
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
	_apply_btn_style(exit_btn, Color(0.36, 0.16, 0.16), Color(0.48, 0.20, 0.20))
	exit_btn.pressed.connect(func(): SceneManager.change_scene("res://UI/MiniGamesMenu/minigames_menu.tscn"))
	ctrl_hbox.add_child(exit_btn)
	
	_update_hud()
	_update_music_button_state()
	GlobalSettings.range_settings.minigame_music_enabled.setting_changed.connect(func(_val): _update_music_button_state())


func _create_stat_column(parent: HBoxContainer, title: String, default_val: String) -> Label:
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
	val_lbl.text = default_val
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 24)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	val_lbl.add_theme_constant_override("outline_size", 2)
	val_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	col.add_child(val_lbl)
	stat_columns.append({"title_lbl": title_lbl, "val_lbl": val_lbl})
	return val_lbl


func _update_hud() -> void:
	if stat_columns.size() >= 4:
		if tic_tac_toe_mode:
			# Column 0: Current Turn
			stat_columns[0]["title_lbl"].text = "CURRENT TURN"
			if winner_symbol != "":
				var win_name = player_x_name if winner_symbol == "X" else player_o_name
				stat_columns[0]["val_lbl"].text = "🏆 %s (%s)" % [win_name, winner_symbol]
				stat_columns[0]["val_lbl"].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			elif is_draw:
				stat_columns[0]["val_lbl"].text = "DRAW"
				stat_columns[0]["val_lbl"].add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
			elif current_turn_symbol == "X":
				stat_columns[0]["val_lbl"].text = "%s (X)" % player_x_name
				stat_columns[0]["val_lbl"].add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
			else:
				stat_columns[0]["val_lbl"].text = "%s (O)" % player_o_name
				stat_columns[0]["val_lbl"].add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
				
			# Column 1: Game Status
			stat_columns[1]["title_lbl"].text = "GAME STATUS"
			if winner_symbol != "":
				stat_columns[1]["val_lbl"].text = "%s WON!" % winner_symbol
				stat_columns[1]["val_lbl"].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			elif is_draw:
				stat_columns[1]["val_lbl"].text = "CAT'S GAME"
				stat_columns[1]["val_lbl"].add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
			else:
				stat_columns[1]["val_lbl"].text = "IN PLAY"
				stat_columns[1]["val_lbl"].add_theme_color_override("font_color", Color.WHITE)
				
			# Column 2: Board Score
			stat_columns[2]["title_lbl"].text = "GRID MARKS"
			var x_cnt = board_marks.count("X")
			var o_cnt = board_marks.count("O")
			stat_columns[2]["val_lbl"].text = "X: %d  |  O: %d" % [x_cnt, o_cnt]
			stat_columns[2]["val_lbl"].add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			
			# Column 3: Attempts
			stat_columns[3]["title_lbl"].text = "TOTAL SHOTS"
			stat_columns[3]["val_lbl"].text = str(attempts_count)
			stat_columns[3]["val_lbl"].add_theme_color_override("font_color", Color.WHITE)
		else:
			stat_columns[0]["title_lbl"].text = "PANES CLEARED"
			stat_columns[0]["val_lbl"].text = "%d / 9" % broken_count
			stat_columns[0]["val_lbl"].add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
			
			stat_columns[1]["title_lbl"].text = "TOTAL ATTEMPTS"
			stat_columns[1]["val_lbl"].text = str(attempts_count)
			stat_columns[1]["val_lbl"].add_theme_color_override("font_color", Color.WHITE)
			
			stat_columns[2]["title_lbl"].text = "ACCURACY"
			var acc = (float(broken_count) / float(attempts_count) * 100.0) if attempts_count > 0 else 0.0
			stat_columns[2]["val_lbl"].text = "%.1f%%" % acc
			stat_columns[2]["val_lbl"].add_theme_color_override("font_color", Color.WHITE)
			
			stat_columns[3]["title_lbl"].text = "LAST TARGET"
			stat_columns[3]["val_lbl"].text = str(last_shot_data.get("TargetHit", "None")) if not last_shot_data.is_empty() else "None"
			stat_columns[3]["val_lbl"].add_theme_color_override("font_color", Color.WHITE)
			
	if matrix_title_lbl:
		if tic_tac_toe_mode:
			matrix_title_lbl.text = "❌⭕ TIC-TAC-TOE"
			matrix_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			matrix_title_lbl.text = "3x3 GLASS TARGETS"
			matrix_title_lbl.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
		
	# Update 3x3 Matrix Buttons
	for i in range(hud_matrix_buttons.size()):
		_apply_matrix_btn_style(hud_matrix_buttons[i], i)


func _apply_matrix_btn_style(btn: Button, idx: int) -> void:
	var is_broken = panes_broken[idx] if idx < panes_broken.size() else false
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	if tic_tac_toe_mode:
		var mark = board_marks[idx] if idx < board_marks.size() else ""
		if winning_line.has(idx):
			# Winning line highlight!
			style.bg_color = Color(0.15, 0.55, 0.25, 0.95)
			style.border_color = Color(0.35, 1.0, 0.55)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
			btn.text = "★ " + mark + " ★"
		elif mark == "X":
			style.bg_color = Color(0.08, 0.25, 0.42, 0.92)
			style.border_color = Color(0.20, 0.85, 1.0)
			btn.add_theme_color_override("font_color", Color(0.30, 0.90, 1.0))
			btn.text = "X"
		elif mark == "O":
			style.bg_color = Color(0.38, 0.22, 0.08, 0.92)
			style.border_color = Color(1.0, 0.75, 0.20)
			btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
			btn.text = "O"
		else:
			style.bg_color = Color(0.10, 0.22, 0.35, 0.85)
			style.border_color = Color(0.25, 0.65, 0.95, 0.6)
			btn.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
			var short_names = ["1 TL", "2 TM", "3 TR", "4 ML", "5 MM", "6 MR", "7 BL", "8 BM", "9 BR"]
			if idx >= 0 and idx < short_names.size():
				btn.text = short_names[idx]
	else:
		if is_broken:
			style.bg_color = Color(0.12, 0.45, 0.22, 0.9)
			style.border_color = Color(0.3, 0.9, 0.45)
			btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
			btn.text = "💥"
		else:
			style.bg_color = Color(0.10, 0.22, 0.35, 0.85)
			style.border_color = Color(0.25, 0.65, 0.95, 0.6)
			btn.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
			var short_names = ["1 TL", "2 TM", "3 TR", "4 ML", "5 MM", "6 MR", "7 BL", "8 BM", "9 BR"]
			if idx >= 0 and idx < short_names.size():
				btn.text = short_names[idx]
			
	var style_focus = style.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style_focus)


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
	style_normal.border_color = Color(1, 1, 1, 0.2)
	
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
	style_hover.border_color = Color(1, 1, 1, 0.4)
	
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
	style_normal.corner_radius_top_left = 28
	style_normal.corner_radius_top_right = 28
	style_normal.corner_radius_bottom_left = 28
	style_normal.corner_radius_bottom_right = 28
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
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_layer.add_child(backdrop)

	var margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 36)
	margin_container.add_theme_constant_override("margin_right", 36)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
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
	if has_node("/root/ScreenOffsetManager") and camera != null and is_instance_valid(camera):
		ScreenOffsetManager.unregister_camera(camera)


func _sync_launch_monitor_player() -> void:
	if not tic_tac_toe_mode:
		return
	var cur_name = player_x_name if current_turn_symbol == "X" else player_o_name
	if player != null and player.has_method("set_profile"):
		player.set_profile(cur_name)
	if has_node("/root/LaunchMonitorManager") and has_node("/root/MultiplayerManager"):
		var hand = MultiplayerManager.get_player_handedness(cur_name)
		get_node("/root/LaunchMonitorManager").set_handedness(hand)
