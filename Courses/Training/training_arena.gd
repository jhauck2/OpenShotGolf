extends Node3D

## Interactive 3D Training Arena.
## Renders the high-fidelity Driving Range with drill-specific 3D targets
## (corridors, bullseye rings, sky launch windows, curved shape gates, cluster pins)
## and delivers rhythm-game-inspired instant feedback, combo multipliers,
## precision gauge drift history, trend callouts, and S-D drill grading.

const Catalog = preload("res://Courses/Training/training_catalog.gd")
const ProgressStore = preload("res://Courses/Training/training_progress_store.gd")
const Recommender = preload("res://Courses/Training/training_recommendation_engine.gd")
const ShotEvaluator = preload("res://Courses/Training/training_shot_evaluator.gd")
const PlayerScene = preload("res://Player/player.tscn")
const FlagBuilder = preload("res://Courses/Range/flag_builder.gd")
const YARD_TO_M := 0.9144
const M_TO_YDS := 1.09361
const TARGET_ARROW_BASE_Y := 4.1
const TRAINING_MENU_SCENE := "res://UI/TrainingMenu/training_menu.tscn"
const MAIN_MENU_SCENE := "res://UI/MainMenu/main_menu.tscn"

var is_driving_range: bool = true

# Drill Session State
var _session_config: Dictionary = {}
var _drill: Dictionary = {}
var _player_name: String = "Player 1"
var _player_handedness: int = 0
var _difficulty: String = "standard"
var _active_club: String = "7i"
var _total_shots_target: int = 10
var _shot_results: Array[Dictionary] = []
var _bias_history: Array[float] = []
var _current_stage_target: Dictionary = {}
var _drill_completed: bool = false
var _session_token: int = 0
var _pending_shot_is_sim: bool = false
var _shot_in_progress: bool = false
var _shot_active: bool:
	get:
		return _shot_in_progress
var _progress_path_override: String = ProgressStore.DEFAULT_PROGRESS_PATH

# 3D Scene References
var player = null
var _drill_props_root: Node3D = null
var _shot_pins_root: Node3D = null
var _target_arrow_node: Node3D = null
var _target_aim_pos: Vector3 = Vector3(137.16, 0.0, 0.0)
var _last_camera_offset: Vector3 = Vector3.ZERO
var _camera_following: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Materials
var _green_mat: StandardMaterial3D = null
var _tee_turf_mat: StandardMaterial3D = null
var _wall_wood_mat: StandardMaterial3D = null

# Audio
var _sfx_ding_player: AudioStreamPlayer = null
var _sfx_applause_player: AudioStreamPlayer = null

# Arena Theme & Stadium Visual References
var _current_theme: String = "night"
var _stadium_infrastructure_root: Node3D = null
var _rotating_reticles: Array[Node3D] = []
var _pulsing_beacons: Array[MeshInstance3D] = []
var _theme_btn: Button = null

# HUD & UI References
var _hud_layer: CanvasLayer = null
var _hud_control: Control = null
var _settings_layer: CanvasLayer = null
var _grid_canvas: Control = null
var _club_selector: Control = null
var _stats_btn: Button = null
var _music_toggle_btn: Button = null

var _drill_title_lbl: Label = null
var _target_info_lbl: Label = null
var _shot_progress_lbl: Label = null
var _score_lbl: Label = null
var _combo_panel: PanelContainer = null
var _combo_lbl: Label = null
var _pace_grade_lbl: Label = null
var _timeline_hbox: HBoxContainer = null
var _timeline_badges: Array[PanelContainer] = []

var _coach_target_lbl: Label = null
var _coach_cue_lbl: Label = null
var _coach_club_lbl: Label = null
var _coach_legend_vbox: VBoxContainer = null

var _judgment_panel: PanelContainer = null
var _judgment_tier_lbl: Label = null
var _judgment_pts_lbl: Label = null
var _judgment_trend_lbl: Label = null
var _judgment_detail_lbl: Label = null
var _judgment_tween: Tween = null

var _gauge_control: PrecisionGaugeControl = null
var _gauge_left_lbl: Label = null
var _gauge_right_lbl: Label = null
var _gauge_status_lbl: Label = null

var _summary_panel: PanelContainer = null
var _raw_ball_data: Dictionary = {}
var _display_data: Dictionary = {}


# ─── INNER CLASS: RHYTHM PRECISION GAUGE ──────────────────────────────────────
class PrecisionGaugeControl extends Control:
	var target_bias: float = 0.0
	var display_bias: float = 0.0
	var has_shot: bool = false
	var ghost_biases: Array[float] = []
	var active_color: Color = Color(0.35, 0.90, 1.0)

	func set_shot_bias(bias: float, col: Color, ghosts: Array[float]) -> void:
		target_bias = clampf(bias, -1.0, 1.0)
		if not has_shot:
			display_bias = target_bias
		has_shot = true
		active_color = col
		ghost_biases = ghosts.duplicate()
		queue_redraw()

	func clear_gauge() -> void:
		target_bias = 0.0
		display_bias = 0.0
		has_shot = false
		ghost_biases.clear()
		active_color = Color(0.35, 0.90, 1.0)
		queue_redraw()

	func _process(delta: float) -> void:
		if has_shot and absf(display_bias - target_bias) > 0.002:
			display_bias = lerpf(display_bias, target_bias, clampf(delta * 14.0, 0.0, 1.0))
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 10.0 or h <= 10.0:
			return

		var bar_h := 20.0
		var bar_y := (h - bar_h) * 0.5
		var bar_rect := Rect2(0.0, bar_y, w, bar_h)

		# Outer dark frame
		draw_rect(bar_rect, Color(0.06, 0.09, 0.14, 0.95))

		# Symmetrical zone bands across [-1.0, +1.0] -> [0, w]
		var bands := [
			{"from": -1.00, "to": -0.72, "col": Color(0.85, 0.25, 0.25, 0.45)},
			{"from": -0.72, "to": -0.50, "col": Color(0.95, 0.65, 0.20, 0.45)},
			{"from": -0.50, "to": -0.32, "col": Color(0.22, 0.70, 0.95, 0.48)},
			{"from": -0.32, "to": -0.17, "col": Color(0.22, 0.88, 0.48, 0.58)},
			{"from": -0.17, "to": 0.17, "col": Color(1.00, 0.84, 0.22, 0.80)},
			{"from": 0.17, "to": 0.32, "col": Color(0.22, 0.88, 0.48, 0.58)},
			{"from": 0.32, "to": 0.50, "col": Color(0.22, 0.70, 0.95, 0.48)},
			{"from": 0.50, "to": 0.72, "col": Color(0.95, 0.65, 0.20, 0.45)},
			{"from": 0.72, "to": 1.00, "col": Color(0.85, 0.25, 0.25, 0.45)}
		]
		for b in bands:
			var x0 := (float(b["from"]) * 0.5 + 0.5) * w
			var x1 := (float(b["to"]) * 0.5 + 0.5) * w
			draw_rect(Rect2(x0, bar_y + 2.0, x1 - x0, bar_h - 4.0), b["col"])

		# Center sweet-spot tick
		var cx := w * 0.5
		draw_line(Vector2(cx, bar_y - 4.0), Vector2(cx, bar_y + bar_h + 4.0), Color(1.0, 0.96, 0.65, 0.95), 2.0)

		# Previous shot ghost markers (oldest -> newest)
		var g_count := ghost_biases.size()
		for i in range(g_count):
			var gb := clampf(ghost_biases[i], -1.0, 1.0)
			var gx := (gb * 0.5 + 0.5) * w
			var alpha := 0.25 + 0.20 * float(i)
			draw_circle(Vector2(gx, h * 0.5), 5.0, Color(0.85, 0.92, 1.0, alpha))
			draw_arc(Vector2(gx, h * 0.5), 5.0, 0.0, TAU, 16, Color(0.1, 0.15, 0.22, alpha), 1.5)

		# Current shot bright needle + diamond
		if has_shot:
			var nx := clampf((display_bias * 0.5 + 0.5) * w, 4.0, w - 4.0)
			draw_line(Vector2(nx, bar_y - 6.0), Vector2(nx, bar_y + bar_h + 6.0), Color.WHITE, 3.0)
			draw_circle(Vector2(nx, h * 0.5), 7.5, active_color)
			draw_arc(Vector2(nx, h * 0.5), 7.5, 0.0, TAU, 20, Color.WHITE, 2.0)


func get_height(_x: float, _z: float) -> float:
	return 0.0


func _ready() -> void:
	name = "TrainingArena"
	is_driving_range = true
	set_meta("is_driving_range", true)
	_rng.randomize()

	_load_session_config()
	_setup_audio_players()
	_init_materials()
	_setup_environment()
	_generate_ground_terrain()
	_spawn_driving_range_elements()
	_spawn_stadium_infrastructure()

	_drill_props_root = Node3D.new()
	_drill_props_root.name = "DrillProps"
	add_child(_drill_props_root)

	_shot_pins_root = Node3D.new()
	_shot_pins_root.name = "ShotClusterPins"
	add_child(_shot_pins_root)

	_setup_player()
	_optimize_scene_graphics()
	_setup_ui()
	_apply_arena_theme(_current_theme)
	_start_new_drill_session()
	_connect_launch_monitor()

	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if eb.has_signal("club_selected") and not eb.is_connected("club_selected", Callable(self, "_on_event_bus_club_selected")):
			eb.connect("club_selected", Callable(self, "_on_event_bus_club_selected"))


func _load_session_config() -> void:
	_session_config = Catalog.get_active_session()
	var drill_id := str(_session_config.get("drill_id", "fairway_finder"))
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		var s: String = arg.replace("\"", "").replace("'", "")
		if "drill=" in s:
			var parts := s.split("drill=")
			if parts.size() > 1:
				drill_id = parts[1].strip_edges()
	_drill = Catalog.get_drill(drill_id)
	_player_name = str(_session_config.get("player_name", "Player 1"))
	_difficulty = Catalog.normalize_difficulty(str(_session_config.get("difficulty", "standard")))
	if drill_id != str(_session_config.get("drill_id", "")):
		_active_club = str(_drill.get("recommended_club", "7i"))
	else:
		_active_club = str(_session_config.get("selected_club", _drill.get("recommended_club", "7i")))
	_total_shots_target = int(_drill.get("reps", 10))

	if is_inside_tree() and has_node("/root/MultiplayerManager"):
		var mp := get_node("/root/MultiplayerManager")
		if mp.has_method("get_player_handedness"):
			_player_handedness = int(mp.get_player_handedness(_player_name))


func configure_session_for_test(drill_id: String, player_name: String = "TestPlayer", difficulty: String = "standard", handedness: int = 0, progress_path: String = "") -> void:
	Catalog.set_active_session(drill_id, player_name, difficulty)
	_player_handedness = handedness
	if not progress_path.is_empty():
		_progress_path_override = progress_path
	_load_session_config()
	_player_handedness = handedness
	_start_new_drill_session()


func _setup_audio_players() -> void:
	_sfx_ding_player = AudioStreamPlayer.new()
	_sfx_ding_player.name = "JudgmentSfxPlayer"
	if ResourceLoader.exists("res://assets/audio/sfx/ready_ding.wav"):
		_sfx_ding_player.stream = load("res://assets/audio/sfx/ready_ding.wav")
	_sfx_ding_player.volume_db = -4.0
	add_child(_sfx_ding_player)

	_sfx_applause_player = AudioStreamPlayer.new()
	_sfx_applause_player.name = "ApplausePlayer"
	if ResourceLoader.exists("res://assets/audio/golf_clap.mp3"):
		_sfx_applause_player.stream = load("res://assets/audio/golf_clap.mp3")
	_sfx_applause_player.volume_db = 1.0
	add_child(_sfx_applause_player)


func _init_materials() -> void:
	_green_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		_green_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		_green_mat.albedo_color = Color(0.9, 1.0, 0.9)
		_green_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	else:
		_green_mat.albedo_color = Color(0.16, 0.65, 0.22)
	_green_mat.roughness = 0.88

	_tee_turf_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		_tee_turf_mat.albedo_texture = load("res://Courses/Environments/grass-green/albedo.png")
		_tee_turf_mat.albedo_color = Color(0.85, 1.0, 0.85)
		_tee_turf_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	else:
		_tee_turf_mat.albedo_color = Color(0.18, 0.70, 0.25)
	_tee_turf_mat.roughness = 0.85

	_wall_wood_mat = StandardMaterial3D.new()
	_wall_wood_mat.albedo_color = Color(0.25, 0.18, 0.12)
	_wall_wood_mat.roughness = 0.9


func _setup_environment() -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		camera.near = 0.05
		camera.far = 4000.0
		add_child(camera)
	if has_node("Sky3D") and $Sky3D is WorldEnvironment and $Sky3D.camera_attributes != null:
		camera.attributes = $Sky3D.camera_attributes
	if is_inside_tree() and has_node("/root/TensionManager"):
		get_node("/root/TensionManager").register_camera(camera, 55.0)
	if is_inside_tree() and has_node("/root/ScreenOffsetManager"):
		var som := get_node("/root/ScreenOffsetManager")
		som.register_camera(camera)
		som.on_ready_for_shot(0.0, true)
	_apply_arena_theme(_current_theme)


func _apply_arena_theme(theme_name: String) -> void:
	_current_theme = theme_name
	var sky := get_node_or_null("Sky3D")
	var tod = sky.get_node_or_null("TimeOfDay") if sky != null else null
	var sun = sky.get_node_or_null("SunLight") as DirectionalLight3D if sky != null else null
	var moon = sky.get_node_or_null("MoonLight") as DirectionalLight3D if sky != null else null
	var env := sky.environment as Environment if sky != null else null

	match theme_name:
		"sunset":
			if tod != null and tod.has_method("set_total_hours"):
				tod.set_total_hours(19.2)
			if sky != null and "current_time" in sky:
				sky.set("current_time", 19.2)
			if sun != null:
				sun.light_energy = 1.35
				sun.light_color = Color(1.0, 0.72, 0.42)
				sun.shadow_enabled = true
			if moon != null:
				moon.light_energy = 0.0
			if env != null:
				env.glow_enabled = true
				env.glow_intensity = 0.60
				env.glow_bloom = 0.12
				env.ambient_light_energy = 0.60
				env.ambient_light_color = Color(0.35, 0.22, 0.18)
		"day":
			if tod != null and tod.has_method("set_total_hours"):
				tod.set_total_hours(13.25)
			if sky != null and "current_time" in sky:
				sky.set("current_time", 13.25)
			if sun != null:
				sun.light_energy = 1.15
				sun.light_color = Color.WHITE
				sun.shadow_enabled = true
			if moon != null:
				moon.light_energy = 0.0
			if env != null:
				env.glow_enabled = true
				env.glow_intensity = 0.35
				env.glow_bloom = 0.05
				env.ambient_light_energy = 0.50
				env.ambient_light_color = Color(0.2, 0.2, 0.2)
		_:
			# "night" (Default - Electric Stadium Night)
			if tod != null and tod.has_method("set_total_hours"):
				tod.set_total_hours(0.0)
			if sky != null and "current_time" in sky:
				sky.set("current_time", 0.0)
			if sun != null:
				sun.light_energy = 0.0
				sun.shadow_enabled = false
			if moon != null:
				moon.light_energy = 0.65
				moon.light_color = Color(0.68, 0.84, 1.0)
				moon.shadow_enabled = true
			if env != null:
				env.glow_enabled = true
				env.glow_intensity = 0.85
				env.glow_bloom = 0.18
				env.ambient_light_energy = 0.32
				env.ambient_light_color = Color(0.12, 0.16, 0.28)

	var mountain = get_node_or_null("MountainBackdrop/MountainMesh") as MeshInstance3D
	if mountain != null and mountain.material_override is StandardMaterial3D:
		if theme_name == "night":
			mountain.material_override.albedo_color = Color(0.06, 0.08, 0.14)
		elif theme_name == "sunset":
			mountain.material_override.albedo_color = Color(0.70, 0.45, 0.35)
		else:
			mountain.material_override.albedo_color = Color.WHITE

	if _stadium_infrastructure_root != null and is_instance_valid(_stadium_infrastructure_root):
		var lights_active := (theme_name != "day")
		for sl in _stadium_infrastructure_root.find_children("*", "SpotLight3D", true, false):
			(sl as SpotLight3D).visible = lights_active


func _spawn_stadium_infrastructure() -> void:
	if _stadium_infrastructure_root != null and is_instance_valid(_stadium_infrastructure_root):
		_stadium_infrastructure_root.queue_free()

	_stadium_infrastructure_root = Node3D.new()
	_stadium_infrastructure_root.name = "StadiumInfrastructure"
	add_child(_stadium_infrastructure_root)

	var tower_coords: Array[Vector3] = [
		Vector3(12.0, 0.0, -50.0),
		Vector3(12.0, 0.0, 50.0),
		Vector3(90.0, 0.0, -50.0),
		Vector3(90.0, 0.0, 50.0),
		Vector3(180.0, 0.0, -50.0),
		Vector3(180.0, 0.0, 50.0)
	]

	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.14, 0.15, 0.18)
	mast_mat.metallic = 0.85
	mast_mat.roughness = 0.35

	var flood_mat := StandardMaterial3D.new()
	flood_mat.albedo_color = Color(1.0, 0.98, 0.90)
	flood_mat.emission_enabled = true
	flood_mat.emission = Color(1.0, 0.96, 0.88)
	flood_mat.emission_energy_multiplier = 4.8

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.05)
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for idx in range(tower_coords.size()):
		var coord := tower_coords[idx]
		var tower := Node3D.new()
		tower.name = "FloodlightTower_%d" % idx
		tower.position = coord
		_stadium_infrastructure_root.add_child(tower)

		var mast := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.30; cm.bottom_radius = 0.46; cm.height = 17.0
		mast.mesh = cm
		mast.material_override = mast_mat
		mast.position = Vector3(0.0, 8.5, 0.0)
		tower.add_child(mast)

		var crossbar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.35, 4.6)
		crossbar.mesh = bm
		crossbar.material_override = mast_mat
		crossbar.position = Vector3(0.0, 16.8, 0.0)
		tower.add_child(crossbar)

		var z_offsets: Array[float] = [-1.8, -1.1, -0.4, 0.4, 1.1, 1.8]
		for zo in z_offsets:
			var head := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.7, 0.55, 0.55)
			head.mesh = hm
			head.material_override = flood_mat
			var look_sign := 1.0 if coord.z < 0.0 else -1.0
			head.position = Vector3(0.0, 17.1, zo)
			head.rotation_degrees = Vector3(look_sign * 25.0, 0.0, 0.0)
			tower.add_child(head)

		var cone := MeshInstance3D.new()
		var cym := CylinderMesh.new()
		cym.top_radius = 0.4; cym.bottom_radius = 16.0; cym.height = 24.0
		cone.mesh = cym
		cone.material_override = cone_mat
		var cone_target_z := -coord.z * 0.4
		cone.position = Vector3(0.0, 7.5, (cone_target_z - coord.z) * 0.25)
		cone.rotation_degrees = Vector3(38.0 if coord.z < 0.0 else -38.0, 0.0, 0.0)
		tower.add_child(cone)

		var spot := SpotLight3D.new()
		spot.name = "TowerSpotLight"
		spot.position = Vector3(0.0, 17.0, 0.0)
		tower.add_child(spot)
		if spot.is_inside_tree():
			var spot_target := Vector3(coord.x + 30.0, 0.0, 0.0)
			spot.look_at(spot_target)
		else:
			spot.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
		spot.spot_range = 95.0
		spot.spot_angle = 48.0
		spot.light_energy = 3.6
		spot.light_color = Color(0.96, 0.98, 1.0)
		spot.shadow_enabled = (idx < 2)

	_spawn_perimeter_barrier()
	_spawn_cyber_bay_visuals()


func _spawn_perimeter_barrier() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.12, 0.13, 0.15)
	wall_mat.roughness = 0.65

	var ribbon_mat := StandardMaterial3D.new()
	ribbon_mat.albedo_color = Color(0.20, 0.85, 1.0)
	ribbon_mat.emission_enabled = true
	ribbon_mat.emission = Color(0.20, 0.85, 1.0)
	ribbon_mat.emission_energy_multiplier = 2.8

	for z_side in [-51.0, 51.0]:
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(350.0, 1.2, 0.3)
		wall.mesh = bm
		wall.material_override = wall_mat
		wall.position = Vector3(160.0, 0.6, z_side)
		_stadium_infrastructure_root.add_child(wall)

		var ribbon := MeshInstance3D.new()
		var rbm := BoxMesh.new()
		rbm.size = Vector3(350.0, 0.08, 0.34)
		ribbon.mesh = rbm
		ribbon.material_override = ribbon_mat
		ribbon.position = Vector3(160.0, 1.24, z_side)
		_stadium_infrastructure_root.add_child(ribbon)

		for x_b in [20.0, 60.0, 100.0, 140.0, 180.0, 220.0, 260.0, 300.0]:
			var banner := Label3D.new()
			banner.text = " HECKLE TRAINING ACADEMY | PRO PERFORMANCE"
			banner.font_size = 28
			banner.outline_size = 6
			banner.modulate = Color(0.35, 0.88, 1.0, 0.85)
			banner.position = Vector3(x_b, 0.65, z_side + (0.18 if z_side < 0.0 else -0.18))
			banner.rotation_degrees = Vector3(0.0, 90.0 if z_side < 0.0 else -90.0, 0.0)
			_stadium_infrastructure_root.add_child(banner)


func _spawn_cyber_bay_visuals() -> void:
	var bay_root := Node3D.new()
	bay_root.name = "CyberBayVisuals"
	_stadium_infrastructure_root.add_child(bay_root)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.25, 0.90, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.25, 0.90, 1.0)
	ring_mat.emission_energy_multiplier = 2.4
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var tee_ring := MeshInstance3D.new()
	tee_ring.mesh = _create_ring_mesh(0.28, 0.34, 32)
	tee_ring.material_override = ring_mat
	tee_ring.position = Vector3(0.0, 0.052, 0.0)
	bay_root.add_child(tee_ring)

	var tee_dot := MeshInstance3D.new()
	tee_dot.mesh = _create_disc_mesh(0.06, 16)
	tee_dot.material_override = ring_mat
	tee_dot.position = Vector3(0.0, 0.053, 0.0)
	bay_root.add_child(tee_dot)

	for a in [0.0, 90.0, 180.0, 270.0]:
		var tick := MeshInstance3D.new()
		var tbm := BoxMesh.new()
		tbm.size = Vector3(0.12, 0.005, 0.02)
		tick.mesh = tbm
		tick.material_override = ring_mat
		var rad := deg_to_rad(a)
		tick.position = Vector3(cos(rad) * 0.40, 0.053, sin(rad) * 0.40)
		tick.rotation_degrees.y = -a
		bay_root.add_child(tick)

	var kiosk_mat := StandardMaterial3D.new()
	kiosk_mat.albedo_color = Color(0.10, 0.11, 0.13)
	kiosk_mat.metallic = 0.85
	kiosk_mat.roughness = 0.25

	var kiosk_mast := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.22, 0.95, 0.22)
	kiosk_mast.mesh = km
	kiosk_mast.material_override = kiosk_mat
	kiosk_mast.position = Vector3(0.3, 0.48, 1.45)
	bay_root.add_child(kiosk_mast)

	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.35, 0.25, 0.04)
	screen.mesh = sm
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.15, 0.85, 1.0)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.85, 1.0)
	screen_mat.emission_energy_multiplier = 3.2
	screen.material_override = screen_mat
	screen.position = Vector3(0.3, 0.98, 1.45)
	screen.rotation_degrees = Vector3(-25.0, -20.0, 0.0)
	bay_root.add_child(screen)

	var kiosk_lbl := Label3D.new()
	kiosk_lbl.text = "ACADEMY AI\nONLINE"
	kiosk_lbl.font_size = 22
	kiosk_lbl.outline_size = 4
	kiosk_lbl.modulate = Color(0.3, 1.0, 0.9)
	kiosk_lbl.position = Vector3(0.3, 0.99, 1.42)
	kiosk_lbl.rotation_degrees = Vector3(-25.0, -20.0, 0.0)
	bay_root.add_child(kiosk_lbl)


func _get_gs() -> Node:
	return get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null


func _optimize_scene_graphics() -> void:
	if has_node("Sky3D"):
		MobilePerformance.optimize_sky3d($Sky3D)
	MobilePerformance.optimize_scene(self)
	var gs := _get_gs()
	var q_str: String = gs.get_graphics_quality() if gs != null and gs.has_method("get_graphics_quality") else "High"
	MobilePerformance.apply_graphics_quality(self, q_str)
	var skydome := get_node_or_null("Sky3D/Skydome")
	if skydome != null:
		skydome.fog_density = 0.00035
		skydome.fog_start = 380.0
		skydome.fog_end = 1400.0
		skydome.clouds_visible = true
		skydome.clouds_cumulus_visible = false


# ─── HIGH-FIDELITY DRIVING RANGE TERRAIN & DECORATIONS ────────────────────────
func _generate_ground_terrain() -> void:
	var min_x := -150.0
	var max_x := 490.0
	var min_z := -450.0
	var max_z := 450.0
	var subdiv_x := 140
	var subdiv_z := 120
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
			st.set_uv(Vector2(x0, z0) * 0.05)
			st.add_vertex(p00)
			st.set_uv(Vector2(x1, z0) * 0.05)
			st.add_vertex(p10)
			st.set_uv(Vector2(x0, z1) * 0.05)
			st.add_vertex(p01)
			st.set_uv(Vector2(x1, z0) * 0.05)
			st.add_vertex(p10)
			st.set_uv(Vector2(x1, z1) * 0.05)
			st.add_vertex(p11)
			st.set_uv(Vector2(x0, z1) * 0.05)
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
	static_body.set_meta("surface_type", 0)
	mesh_instance.add_child(static_body)

	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)


func _spawn_driving_range_elements() -> void:
	var bays_script = load("res://Courses/Range/driving_range_bays.gd")
	if bays_script != null:
		var bays_node = bays_script.create_bay_setup()
		bays_node.name = "DrivingRangeBaySetup"
		add_child(bays_node)
	_spawn_ground_distance_indicators()
	_spawn_range_trees()
	_spawn_mountain_backdrop()


func _spawn_ground_distance_indicators() -> void:
	var markings_root := Node3D.new()
	markings_root.name = "DrivingRangeMarkings"
	add_child(markings_root)

	var major_yardages: Array[float] = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0]
	var corridor_half_w := 26.0
	var max_dist_m := 350.0 * YARD_TO_M

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.98, 0.98, 1.0, 0.90)
	line_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.render_priority = 2

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(line_mat)

	_add_ground_quad(st, 0.0, max_dist_m, -corridor_half_w - 0.30, -corridor_half_w + 0.30, 0.02)
	_add_ground_quad(st, 0.0, max_dist_m, corridor_half_w - 0.30, corridor_half_w + 0.30, 0.02)

	var font_bold = load("res://addons/phantom_camera/fonts/Nunito-Black.ttf") if ResourceLoader.exists("res://addons/phantom_camera/fonts/Nunito-Black.ttf") else null
	var anamorphic_y := 2.4
	for yd in major_yardages:
		var x_line := yd * YARD_TO_M
		_add_ground_quad(st, x_line - 0.85, x_line + 0.85, -corridor_half_w, corridor_half_w, 0.021)
		var label := Label3D.new()
		label.text = str(int(yd))
		if font_bold != null:
			label.font = font_bold
		label.font_size = 256
		var dist_ratio := clampf((yd - 50.0) / 300.0, 0.0, 1.0)
		var base_h := 5.0 + dist_ratio * 15.0
		label.pixel_size = base_h / 240.0
		label.scale = Vector3(1.0, anamorphic_y, 1.0)
		label.modulate = Color(1.0, 1.0, 1.0, 0.92)
		label.outline_modulate = Color(0.04, 0.04, 0.06, 0.8)
		label.outline_size = 6
		label.shaded = false
		label.double_sided = false
		label.rotation_degrees = Vector3(-90.0, -90.0, 0.0)
		label.position = Vector3(x_line - 2.5 - (base_h * anamorphic_y * 0.5), 0.025, 0.0)
		markings_root.add_child(label)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "GroundMarkingsMesh"
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = line_mat
	markings_root.add_child(mesh_inst)


func _add_ground_quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	for v in [
		Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x0, y, z1),
		Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)
	]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


func _spawn_range_trees() -> void:
	var trees_root := Node3D.new()
	trees_root.name = "DrivingRangeTrees"
	add_child(trees_root)

	var tree_paths: Array[String] = [
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-02-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-03-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-birch-1-staticbody.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/bodies/tree-pine-1-staticbody.tscn"
	]
	var tree_scenes: Array[PackedScene] = []
	for p in tree_paths:
		if ResourceLoader.exists(p):
			var sc := load(p) as PackedScene
			if sc:
				tree_scenes.append(sc)
	if tree_scenes.is_empty():
		return

	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = 2027
	var idx := 0
	var x_pos := -25.0
	while x_pos <= 360.0:
		for z_side in [-70.0, 70.0]:
			var tree_inst := tree_scenes[tree_rng.randi() % tree_scenes.size()].instantiate() as StaticBody3D
			if tree_inst:
				tree_inst.name = "RangeTree_%d" % idx
				tree_inst.position = Vector3(x_pos + tree_rng.randf_range(-2.0, 2.0), 0.0, z_side + tree_rng.randf_range(-4.0, 4.0))
				tree_inst.rotation.y = tree_rng.randf_range(0.0, TAU)
				var s := tree_rng.randf_range(1.25, 1.85)
				tree_inst.scale = Vector3(s, s, s)
				trees_root.add_child(tree_inst)
				idx += 1
		x_pos += 11.0


func _spawn_mountain_backdrop() -> void:
	var tex = load("res://Courses/Environments/mountain_backdrop_seamless.png")
	if tex == null:
		return
	var mountain_root := Node3D.new()
	mountain_root.name = "MountainBackdrop"
	add_child(mountain_root)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	var center_x := 30.0
	var radius := 430.0
	var segments := 56
	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a0 := lerpf(deg_to_rad(-115.0), deg_to_rad(115.0), t0)
		var a1 := lerpf(deg_to_rad(-115.0), deg_to_rad(115.0), t1)
		var p_b0 := Vector3(center_x + radius * cos(a0), -4.0, radius * sin(a0))
		var p_t0 := Vector3(center_x + radius * cos(a0), 145.0, radius * sin(a0))
		var p_b1 := Vector3(center_x + radius * cos(a1), -4.0, radius * sin(a1))
		var p_t1 := Vector3(center_x + radius * cos(a1), 145.0, radius * sin(a1))
		var u0 := lerpf(-0.75, 1.75, t0)
		var u1 := lerpf(-0.75, 1.75, t1)

		st.set_uv(Vector2(u0, 1.0)); st.add_vertex(p_b0)
		st.set_uv(Vector2(u0, 0.0)); st.add_vertex(p_t0)
		st.set_uv(Vector2(u1, 0.0)); st.add_vertex(p_t1)
		st.set_uv(Vector2(u0, 1.0)); st.add_vertex(p_b0)
		st.set_uv(Vector2(u1, 0.0)); st.add_vertex(p_t1)
		st.set_uv(Vector2(u1, 1.0)); st.add_vertex(p_b1)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MountainMesh"
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mountain_root.add_child(mesh_inst)


# ─── PLAYER & DRILL SESSION LIFECYCLE ─────────────────────────────────────────
func _setup_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	player.set_process(false)
	player.rest.connect(_on_ball_rest)
	player.ball.spawn_position = player.global_position
	if player.has_method("set_profile"):
		player.set_profile(_player_name)
	player.ball.reset()


func _start_new_drill_session() -> void:
	_session_token += 1
	_shot_results.clear()
	_bias_history.clear()
	_drill_completed = false
	_shot_in_progress = false
	_pending_shot_is_sim = false

	if _shot_pins_root != null:
		for c in _shot_pins_root.get_children():
			c.queue_free()

	if _summary_panel != null and is_instance_valid(_summary_panel):
		_summary_panel.visible = false
	if _judgment_panel != null and is_instance_valid(_judgment_panel):
		_judgment_panel.visible = false
	if _gauge_control != null:
		_gauge_control.clear_gauge()
	if _gauge_status_lbl != null:
		_gauge_status_lbl.text = "Hit a shot (or press H) to start live feedback"

	_prepare_stage_for_shot(0)
	_build_timeline_badges()
	_reset_ball_position()
	_refresh_hud()


func _prepare_stage_for_shot(shot_idx: int) -> void:
	var visual_mode := str(_drill.get("visual_mode", "corridor"))
	var dists: Array = _drill.get("stage_distances_yds", [150])
	var stage_dist := float(dists[shot_idx % maxi(1, dists.size())])
	var stage_club := _active_club
	var thresholds: Dictionary = _drill.get("thresholds", {}).duplicate(true)
	var stage_mode := visual_mode
	var stage_label := ""
	var req_shape := "draw"
	var min_carry := float(_drill.get("min_carry_yds", 30.0))

	if visual_mode == "combine":
		var cfg := Catalog.get_combine_stage_config(shot_idx)
		stage_dist = float(cfg["distance_yds"])
		stage_club = str(cfg["club"])
		stage_mode = str(cfg["mode"])
		stage_label = str(cfg["stage_name"])
		thresholds = {
			"perfect": float(cfg["perfect"]),
			"great": float(cfg["great"]),
			"good": float(cfg["good"]),
			"ok": float(cfg["ok"])
		}
		_active_club = stage_club
	elif visual_mode == "dispersion_circle":
		stage_dist = _resolve_player_club_carry(_active_club)
		stage_label = "Target: %.0f yds (%s stock)" % [stage_dist, _active_club]
	elif visual_mode == "shape_gate":
		req_shape = "draw" if (shot_idx % 2 == 0) else "fade"
		stage_label = "%s Shape Target (%d yds)" % [req_shape.capitalize(), int(stage_dist)]
	elif visual_mode == "bullseye_random":
		stage_label = "Approach Pin: %d yds" % int(stage_dist)
		stage_club = _suggest_club_for_yds(int(stage_dist))
		_active_club = stage_club
	elif visual_mode == "bullseye_ladder":
		stage_label = "Wedge Station: %d yds" % int(stage_dist)
	elif visual_mode == "launch_window":
		var win := Catalog.get_optimal_vla_window(_active_club)
		stage_label = "Window %.0f deg-%.0f deg (%s)" % [win["min"], win["max"], _active_club]
		_current_stage_target = {
			"mode": stage_mode,
			"distance_yds": stage_dist,
			"club": _active_club,
			"thresholds": thresholds,
			"min_carry_yds": min_carry,
			"min_vla_deg": win["min"],
			"max_vla_deg": win["max"],
			"ideal_vla_deg": win["ideal"],
			"label": stage_label
		}
		_select_club_in_ui(_active_club)
		_rebuild_drill_props()
		return
	elif visual_mode == "compression_corridor":
		var ref_carry := _resolve_player_club_carry(_active_club)
		var exp_smash := Catalog.get_expected_smash(_active_club)
		stage_dist = ref_carry
		stage_label = "Target Smash %.2f (%s)" % [exp_smash, _active_club]
		_current_stage_target = {
			"mode": stage_mode,
			"distance_yds": stage_dist,
			"club": _active_club,
			"thresholds": thresholds,
			"target_carry_yds": ref_carry,
			"min_carry_yds": ref_carry * 0.5,
			"label": stage_label
		}
		_select_club_in_ui(_active_club)
		_rebuild_drill_props()
		return
	else:
		stage_label = "%s (%d yds)" % [str(_drill.get("name", "Corridor")), int(stage_dist)]

	_current_stage_target = {
		"mode": stage_mode,
		"distance_yds": stage_dist,
		"club": stage_club,
		"thresholds": thresholds,
		"min_carry_yds": min_carry,
		"shape": req_shape,
		"shape_offset_yds": 12.0,
		"label": stage_label
	}
	_select_club_in_ui(_active_club)
	_rebuild_drill_props()


func _resolve_player_club_carry(club_code: String) -> float:
	if is_inside_tree() and has_node("/root/MultiplayerManager"):
		var mp := get_node("/root/MultiplayerManager")
		if mp.has_method("get_player_club_average_distance_yards"):
			var avg_d := float(mp.get_player_club_average_distance_yards(_player_name, club_code))
			if avg_d > 30.0:
				return avg_d
	return Catalog.get_default_club_carry_yds(club_code)


func _suggest_club_for_yds(yds: int) -> String:
	if yds < 80: return "Sw"
	if yds < 105: return "Gw"
	if yds < 120: return "Pw"
	if yds < 135: return "9i"
	if yds < 150: return "8i"
	if yds < 165: return "7i"
	if yds < 180: return "6i"
	return "5i"


func _select_club_in_ui(club_code: String) -> void:
	if _club_selector != null and _club_selector.has_method("select_club_by_name"):
		_club_selector.call("select_club_by_name", club_code)
	if is_inside_tree() and has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if eb.has_signal("club_selected"):
			eb.emit_signal("club_selected", club_code)


func _on_event_bus_club_selected(club_name: String) -> void:
	if club_name.is_empty() or club_name == _active_club:
		return
	_active_club = club_name
	if str(_drill.get("visual_mode", "")) in ["launch_window", "compression_corridor", "dispersion_circle"] and not _shot_in_progress:
		_prepare_stage_for_shot(_shot_results.size())
		_refresh_hud()


# ─── DYNAMIC 3D DRILL PROPS ───────────────────────────────────────────────────
func _make_emissive_mat(color: Color, alpha: float = 0.65, emission_mult: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_mult
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _add_floating_label(parent: Node3D, text: String, pos: Vector3, font_size: int = 48, col: Color = Color.WHITE) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 12
	lbl.modulate = col
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.position = pos
	parent.add_child(lbl)


func _create_ring_mesh(inner_r: float, outer_r: float, segments: int = 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := (float(i) / segments) * TAU
		var a1 := (float(i + 1) / segments) * TAU
		var p_in0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var p_out0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var p_in1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var p_out1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		for v in [p_in0, p_out0, p_out1, p_in0, p_out1, p_in1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


func _create_disc_mesh(radius: float, segments: int = 36) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := (float(i) / segments) * TAU
		var a1 := (float(i + 1) / segments) * TAU
		for v in [Vector3.ZERO, Vector3(cos(a0) * radius, 0.0, sin(a0) * radius), Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


func _build_target_arrow_at(parent: Node3D, local_pos: Vector3) -> void:
	_target_arrow_node = Node3D.new()
	_target_arrow_node.name = "TargetArrow"
	_target_arrow_node.position = local_pos
	parent.add_child(_target_arrow_node)

	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(1.0, 0.85, 0.1)
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color(1.0, 0.75, 0.05)
	arrow_mat.emission_energy_multiplier = 1.2

	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.65; hm.bottom_radius = 0.0; hm.height = 1.2
	head.mesh = hm
	head.material_override = arrow_mat
	head.position = Vector3(0.0, 0.6, 0.0)
	_target_arrow_node.add_child(head)

	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.22; sm.bottom_radius = 0.22; sm.height = 1.4
	shaft.mesh = sm
	shaft.material_override = arrow_mat
	shaft.position = Vector3(0.0, 1.9, 0.0)
	_target_arrow_node.add_child(shaft)


func _build_flag_at(parent: Node3D, world_pos: Vector3, label_text: String, col: Color = Color(1.0, 0.2, 0.2)) -> void:
	var flag_node := Node3D.new()
	flag_node.position = world_pos + Vector3(0.0, 0.04, 0.0)
	parent.add_child(flag_node)
	var gs := _get_gs()
	var q_str: String = gs.get_graphics_quality() if gs != null and gs.has_method("get_graphics_quality") else "High"
	FlagBuilder.setup_target_flag(flag_node, 2.6, col, 0.55, 0.38, true, q_str)
	_add_floating_label(flag_node, label_text, Vector3(0.0, 3.25, 0.0), 52)


func _rebuild_drill_props() -> void:
	if _drill_props_root == null:
		return
	for c in _drill_props_root.get_children():
		c.queue_free()
	_target_arrow_node = null
	_rotating_reticles.clear()
	_pulsing_beacons.clear()

	var mode := str(_current_stage_target.get("mode", "corridor"))
	var dist_yds := float(_current_stage_target.get("distance_yds", 150.0))
	var dist_m := dist_yds * YARD_TO_M
	var diff_mult := Catalog.get_difficulty_multiplier(_difficulty)
	var th: Dictionary = _current_stage_target.get("thresholds", {})

	if mode == "bullseye_ladder":
		_target_aim_pos = Vector3(dist_m, 0.0, 0.0)
		var ladder_targets: Array[float] = [40.0, 60.0, 80.0, 100.0]
		for l_yd in ladder_targets:
			var is_active := is_equal_approx(l_yd, dist_yds)
			_spawn_bullseye_rings(Vector3(l_yd * YARD_TO_M, 0.0, 0.0), l_yd, th, diff_mult, "%d YDS" % int(l_yd), is_active)
	elif mode in ["bullseye", "bullseye_random", "dispersion_circle"]:
		_target_aim_pos = Vector3(dist_m, 0.0, 0.0)
		_spawn_bullseye_rings(_target_aim_pos, dist_yds, th, diff_mult, "", true)
	elif mode == "shape_gate":
		var hand_sign := -1.0 if _player_handedness == 1 else 1.0
		var req_shape := str(_current_stage_target.get("shape", "draw"))
		var desired_sign := (-1.0 if req_shape == "draw" else 1.0) * hand_sign
		var offset_m := float(_current_stage_target.get("shape_offset_yds", 12.0)) * YARD_TO_M * desired_sign
		_target_aim_pos = Vector3(dist_m, 0.0, 0.0)
		_spawn_shape_gate(22.0, req_shape, offset_m)
		_spawn_bullseye_rings(Vector3(dist_m, 0.0, offset_m), dist_yds, th, diff_mult, "%s TARGET" % req_shape.to_upper(), true)
	elif mode == "launch_window":
		_target_aim_pos = Vector3(dist_m, 0.0, 0.0)
		_spawn_corridor_lanes(8.0 * YARD_TO_M, 14.0 * YARD_TO_M, 22.0 * YARD_TO_M, false, false)
		_spawn_launch_window_frame(
			float(_current_stage_target.get("min_vla_deg", 16.0)),
			float(_current_stage_target.get("max_vla_deg", 22.0))
		)
	else:
		# Corridor modes (corridor, slice_corridor, hook_corridor, compression_corridor)
		_target_aim_pos = Vector3(dist_m, 0.0, 0.0)
		var p_m := maxf(3.0, float(th.get("perfect", 6.0)) * diff_mult * YARD_TO_M)
		var g_m := maxf(p_m + 2.0, float(th.get("great", 11.0)) * diff_mult * YARD_TO_M)
		var ok_m := maxf(g_m + 2.0, float(th.get("good", 17.0)) * diff_mult * YARD_TO_M)
		if mode == "compression_corridor":
			p_m = 6.0; g_m = 11.0; ok_m = 17.0
		_spawn_start_gate(18.0, 3.6, Color(0.20, 0.95, 0.65))
		_spawn_corridor_lanes(p_m, g_m, ok_m, mode == "slice_corridor", mode == "hook_corridor")
		_build_flag_at(_drill_props_root, Vector3(dist_m, 0.0, 0.0), " %d YDS" % int(dist_yds))


func _spawn_bullseye_rings(center_pos: Vector3, dist_yds: float, th: Dictionary, diff_mult: float, custom_lbl: String = "", is_active_target: bool = true) -> Node3D:
	var r_perf := float(th.get("perfect", 4.5)) * diff_mult * YARD_TO_M
	var r_great := float(th.get("great", 8.5)) * diff_mult * YARD_TO_M
	var r_good := float(th.get("good", 13.5)) * diff_mult * YARD_TO_M
	var r_ok := float(th.get("ok", 20.0)) * diff_mult * YARD_TO_M

	var holder := Node3D.new()
	holder.position = center_pos
	_drill_props_root.add_child(holder)

	var platform_height := 0.28
	var platform := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = r_ok + 0.8
	pm.bottom_radius = r_ok + 1.8
	pm.height = platform_height
	platform.mesh = pm
	var plat_mat := StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.10, 0.11, 0.13)
	plat_mat.roughness = 0.55
	platform.material_override = plat_mat
	platform.position = Vector3(0.0, platform_height * 0.5, 0.0)
	holder.add_child(platform)

	var green_disc := MeshInstance3D.new()
	green_disc.mesh = _create_disc_mesh(r_ok + 0.8, 48)
	green_disc.material_override = _green_mat
	green_disc.position = Vector3(0.0, platform_height + 0.005, 0.0)
	holder.add_child(green_disc)

	var body := StaticBody3D.new()
	body.set_meta("surface_type", 4) # GREEN
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r_ok + 0.8
	cyl.height = platform_height + 0.2
	cs.shape = cyl
	cs.position = Vector3(0.0, platform_height * 0.5, 0.0)
	body.add_child(cs)
	holder.add_child(body)

	var rim_mesh := MeshInstance3D.new()
	rim_mesh.mesh = _create_ring_mesh(r_ok + 0.7, r_ok + 0.88, 48)
	var rim_mat := _make_emissive_mat(Color(0.20, 0.85, 1.0), 0.95, 2.5)
	rim_mesh.material_override = rim_mat
	rim_mesh.position = Vector3(0.0, platform_height + 0.010, 0.0)
	holder.add_child(rim_mesh)

	var ring_defs := [
		{"in": r_good, "out": r_ok, "col": Color(0.68, 0.22, 1.0), "emiss": 2.2, "y": 0.012},
		{"in": r_great, "out": r_good, "col": Color(0.18, 0.85, 1.0), "emiss": 2.6, "y": 0.016},
		{"in": r_perf, "out": r_great, "col": Color(0.22, 1.0, 0.52), "emiss": 3.0, "y": 0.020}
	]
	for rd in ring_defs:
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = _create_ring_mesh(float(rd["in"]), float(rd["out"]), 48)
		r_inst.material_override = _make_emissive_mat(rd["col"], 0.85 if is_active_target else 0.40, rd["emiss"] if is_active_target else 1.0)
		r_inst.position = Vector3(0.0, platform_height + float(rd["y"]), 0.0)
		holder.add_child(r_inst)

	var center_disc := MeshInstance3D.new()
	center_disc.mesh = _create_disc_mesh(r_perf, 36)
	center_disc.material_override = _make_emissive_mat(Color(1.0, 0.88, 0.20), 0.95 if is_active_target else 0.50, 3.8 if is_active_target else 1.2)
	center_disc.position = Vector3(0.0, platform_height + 0.024, 0.0)
	holder.add_child(center_disc)

	var flag_col := Color(1.0, 0.25, 0.25) if is_active_target else Color(0.55, 0.55, 0.60)
	var lbl_txt := custom_lbl if not custom_lbl.is_empty() else (" %d YDS" % int(dist_yds))
	_build_flag_at(holder, Vector3(0.0, platform_height, 0.0), lbl_txt, flag_col)

	if is_active_target:
		var beacon := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.45; bm.bottom_radius = 0.55; bm.height = 48.0
		beacon.mesh = bm
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(1.0, 0.88, 0.25, 0.28)
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		b_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		b_mat.emission_enabled = true
		b_mat.emission = Color(1.0, 0.85, 0.20)
		b_mat.emission_energy_multiplier = 3.5
		b_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beacon.material_override = b_mat
		beacon.position = Vector3(0.0, platform_height + 24.0, 0.0)
		holder.add_child(beacon)
		_pulsing_beacons.append(beacon)

		var reticle := Node3D.new()
		reticle.name = "CyberReticle"
		reticle.position = Vector3(0.0, platform_height + 4.2, 0.0)
		holder.add_child(reticle)
		_rotating_reticles.append(reticle)

		var ret_ring := MeshInstance3D.new()
		ret_ring.mesh = _create_ring_mesh(1.6, 1.8, 32)
		ret_ring.material_override = _make_emissive_mat(Color(1.0, 0.88, 0.20), 0.90, 3.2)
		ret_ring.rotation_degrees.x = 90.0
		reticle.add_child(ret_ring)

		for rot in [0.0, 90.0]:
			var ch := MeshInstance3D.new()
			var cbm := BoxMesh.new()
			cbm.size = Vector3(0.08, 3.8, 0.02)
			ch.mesh = cbm
			ch.material_override = _make_emissive_mat(Color(1.0, 0.88, 0.20), 0.90, 3.2)
			ch.rotation_degrees.z = rot
			reticle.add_child(ch)

		var hud_lbl := Label3D.new()
		hud_lbl.text = " %d YDS | TARGET ZONE\nPERFECT: 1000 PTS  |  GREAT: 750 PTS" % int(dist_yds)
		hud_lbl.font_size = 38
		hud_lbl.outline_size = 10
		hud_lbl.outline_modulate = Color(0, 0, 0, 0.95)
		hud_lbl.modulate = Color(1.0, 0.92, 0.35)
		hud_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hud_lbl.position = Vector3(0.0, platform_height + 6.6, 0.0)
		holder.add_child(hud_lbl)

		_build_target_arrow_at(holder, Vector3(0.0, platform_height + TARGET_ARROW_BASE_Y, 0.0))

	return holder


func _spawn_start_gate(x_m: float, half_w_m: float, col: Color) -> void:
	var mat := _make_emissive_mat(col, 0.90, 3.2)
	for z_sign in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16; cm.bottom_radius = 0.20; cm.height = 4.8
		post.mesh = cm
		post.material_override = mat
		post.position = Vector3(x_m, 2.4, z_sign * half_w_m)
		_drill_props_root.add_child(post)

		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25; sm.height = 0.5
		cap.mesh = sm
		cap.material_override = _make_emissive_mat(col, 1.0, 4.5)
		cap.position = Vector3(x_m, 4.9, z_sign * half_w_m)
		_drill_props_root.add_child(cap)

	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, half_w_m * 2.0 + 0.4)
	bar.mesh = bm
	bar.material_override = mat
	bar.position = Vector3(x_m, 4.8, 0.0)
	_drill_props_root.add_child(bar)

	var gate_lbl := Label3D.new()
	gate_lbl.text = " LAUNCH CORRIDOR"
	gate_lbl.font_size = 36
	gate_lbl.outline_size = 8
	gate_lbl.modulate = col
	gate_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate_lbl.position = Vector3(x_m, 5.5, 0.0)
	_drill_props_root.add_child(gate_lbl)


func _spawn_corridor_lanes(perf_half_m: float, great_half_m: float, good_half_m: float, show_slice_wall: bool, show_hook_wall: bool) -> void:
	var length_m := 270.0
	var start_x := 18.0
	var mid_x := start_x + length_m * 0.5

	var perf_strip := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(length_m, 0.02, perf_half_m * 2.0)
	perf_strip.mesh = pm
	perf_strip.material_override = _make_emissive_mat(Color(0.20, 1.0, 0.55), 0.22, 1.2)
	perf_strip.position = Vector3(mid_x, 0.026, 0.0)
	_drill_props_root.add_child(perf_strip)

	for z_off in [-perf_half_m, perf_half_m]:
		var r1 := MeshInstance3D.new()
		var bm1 := BoxMesh.new()
		bm1.size = Vector3(length_m, 0.04, 0.24)
		r1.mesh = bm1
		r1.material_override = _make_emissive_mat(Color(1.0, 0.88, 0.25), 0.95, 3.2)
		r1.position = Vector3(mid_x, 0.038, z_off)
		_drill_props_root.add_child(r1)

	for z_off in [-great_half_m, great_half_m]:
		var r2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(length_m, 0.04, 0.20)
		r2.mesh = bm2
		r2.material_override = _make_emissive_mat(Color(0.20, 0.85, 1.0), 0.85, 2.8)
		r2.position = Vector3(mid_x, 0.034, z_off)
		_drill_props_root.add_child(r2)

	for z_off in [-good_half_m, good_half_m]:
		var r3 := MeshInstance3D.new()
		var bm3 := BoxMesh.new()
		bm3.size = Vector3(length_m, 0.03, 0.18)
		r3.mesh = bm3
		r3.material_override = _make_emissive_mat(Color(0.68, 0.25, 1.0), 0.70, 2.0)
		r3.position = Vector3(mid_x, 0.030, z_off)
		_drill_props_root.add_child(r3)

	var x_chev := start_x + 10.0
	while x_chev <= 280.0:
		var chev := Label3D.new()
		chev.text = ">>>"
		chev.font_size = 140
		chev.modulate = Color(0.25, 1.0, 0.65, 0.85)
		chev.rotation_degrees = Vector3(-90.0, -90.0, 0.0)
		chev.position = Vector3(x_chev, 0.032, 0.0)
		_drill_props_root.add_child(chev)
		x_chev += 18.0

	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.12, 0.14, 0.16)
	pylon_mat.metallic = 0.8
	var pylon_glow := _make_emissive_mat(Color(0.20, 0.88, 1.0), 0.95, 3.5)

	var x_pyl := start_x + 5.0
	while x_pyl <= 275.0:
		for z_p in [-great_half_m, great_half_m]:
			var pylon := Node3D.new()
			pylon.position = Vector3(x_pyl, 0.0, z_p)
			_drill_props_root.add_child(pylon)

			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.10; cm.bottom_radius = 0.14; cm.height = 2.2
			post.mesh = cm
			post.material_override = pylon_mat
			post.position = Vector3(0.0, 1.1, 0.0)
			pylon.add_child(post)

			var cap := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.15; sp.height = 0.3
			cap.mesh = sp
			cap.material_override = pylon_glow
			cap.position = Vector3(0.0, 2.25, 0.0)
			pylon.add_child(cap)

			var laser := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.02; lm.bottom_radius = 0.02; lm.height = 14.0
			laser.mesh = lm
			laser.material_override = pylon_glow
			laser.position = Vector3(0.0, 9.25, 0.0)
			pylon.add_child(laser)

		x_pyl += 25.0

	var arch_yardages: Array[float] = [100.0, 150.0, 200.0, 250.0, 300.0]
	var arch_mat := _make_emissive_mat(Color(0.22, 0.85, 1.0), 0.90, 3.0)
	for yd in arch_yardages:
		var x_arch := yd * YARD_TO_M
		var arch_node := Node3D.new()
		arch_node.position = Vector3(x_arch, 0.0, 0.0)
		_drill_props_root.add_child(arch_node)

		var arch_w := good_half_m * 2.0 + 4.0
		var arch_h := 7.0

		for z_sign in [-1.0, 1.0]:
			var p := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.12; p_mesh.bottom_radius = 0.16; p_mesh.height = arch_h
			p.mesh = p_mesh
			p.material_override = arch_mat
			p.position = Vector3(0.0, arch_h * 0.5, z_sign * (arch_w * 0.5))
			arch_node.add_child(p)

		var top_bar := MeshInstance3D.new()
		var tbm := BoxMesh.new()
		tbm.size = Vector3(0.20, 0.20, arch_w)
		top_bar.mesh = tbm
		top_bar.material_override = arch_mat
		top_bar.position = Vector3(0.0, arch_h, 0.0)
		arch_node.add_child(top_bar)

		var arch_lbl := Label3D.new()
		arch_lbl.text = "%d YARDS" % int(yd)
		arch_lbl.font_size = 46
		arch_lbl.outline_size = 12
		arch_lbl.outline_modulate = Color(0, 0, 0, 0.9)
		arch_lbl.modulate = Color(0.35, 1.0, 0.90)
		arch_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		arch_lbl.position = Vector3(0.0, arch_h + 1.2, 0.0)
		arch_node.add_child(arch_lbl)

	var hand_sign := -1.0 if _player_handedness == 1 else 1.0
	if show_slice_wall or show_hook_wall:
		var wall_sign := hand_sign if show_slice_wall else -hand_sign
		var wall_z := wall_sign * good_half_m
		var wall_h := 5.2

		var hazard_wall := MeshInstance3D.new()
		var hwm := BoxMesh.new()
		hwm.size = Vector3(length_m, wall_h, 0.15)
		hazard_wall.mesh = hwm
		hazard_wall.material_override = _make_emissive_mat(Color(1.0, 0.15, 0.15), 0.45, 2.5)
		hazard_wall.position = Vector3(mid_x, wall_h * 0.5, wall_z)
		_drill_props_root.add_child(hazard_wall)

		var top_warning := MeshInstance3D.new()
		var twm := BoxMesh.new()
		twm.size = Vector3(length_m, 0.25, 0.35)
		top_warning.mesh = twm
		top_warning.material_override = _make_emissive_mat(Color(1.0, 0.20, 0.20), 0.95, 3.8)
		top_warning.position = Vector3(mid_x, wall_h, wall_z)
		_drill_props_root.add_child(top_warning)

		var x_w := start_x + 15.0
		var warn_txt := "HAZARD: HAZARD DEFLECTOR - CURE SLICE / AVOID RIGHT" if show_slice_wall else "HAZARD: HAZARD DEFLECTOR - CURE HOOK / AVOID LEFT"
		while x_w <= 270.0:
			var w_beacon := MeshInstance3D.new()
			var wbm := CylinderMesh.new()
			wbm.top_radius = 0.12; wbm.bottom_radius = 0.12; wbm.height = 0.4
			w_beacon.mesh = wbm
			w_beacon.material_override = _make_emissive_mat(Color(1.0, 0.15, 0.15), 1.0, 4.5)
			w_beacon.position = Vector3(x_w, wall_h + 0.2, wall_z)
			_drill_props_root.add_child(w_beacon)

			var sign_lbl := Label3D.new()
			sign_lbl.text = warn_txt
			sign_lbl.font_size = 40
			sign_lbl.outline_size = 12
			sign_lbl.outline_modulate = Color(0, 0, 0, 0.95)
			sign_lbl.modulate = Color(1.0, 0.35, 0.35)
			sign_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sign_lbl.position = Vector3(x_w, wall_h + 1.5, wall_z)
			_drill_props_root.add_child(sign_lbl)

			x_w += 45.0


func _spawn_launch_window_frame(min_vla: float, max_vla: float) -> void:
	var dist_x := 32.0
	var y_low := maxf(1.4, dist_x * tan(deg_to_rad(min_vla)))
	var y_high := maxf(y_low + 2.0, dist_x * tan(deg_to_rad(max_vla)))
	var win_h := y_high - y_low
	var win_mid_y := (y_low + y_high) * 0.5
	var half_w := 6.0

	var frame_mat := _make_emissive_mat(Color(0.20, 0.95, 0.75), 0.95, 3.5)
	var pane_mat := _make_emissive_mat(Color(0.18, 0.90, 0.70), 0.25, 1.8)

	for z_sign in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.22; pm.bottom_radius = 0.26; pm.height = y_high + 1.5
		post.mesh = pm
		post.material_override = frame_mat
		post.position = Vector3(dist_x, (y_high + 1.5) * 0.5, z_sign * half_w)
		_drill_props_root.add_child(post)

		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35; sm.height = 0.7
		orb.mesh = sm
		orb.material_override = _make_emissive_mat(Color(0.4, 1.0, 0.85), 1.0, 4.5)
		orb.position = Vector3(dist_x, y_high + 1.5, z_sign * half_w)
		_drill_props_root.add_child(orb)

	for bar_y in [y_low, y_high]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 0.28, half_w * 2.0 + 0.4)
		bar.mesh = bm
		bar.material_override = frame_mat
		bar.position = Vector3(dist_x, bar_y, 0.0)
		_drill_props_root.add_child(bar)

	var pane := MeshInstance3D.new()
	var pane_m := BoxMesh.new()
	pane_m.size = Vector3(0.08, win_h, half_w * 2.0)
	pane.mesh = pane_m
	pane.material_override = pane_mat
	pane.position = Vector3(dist_x, win_mid_y, 0.0)
	_drill_props_root.add_child(pane)

	var max_lbl := Label3D.new()
	max_lbl.text = "^ MAX LAUNCH: %.1f deg" % max_vla
	max_lbl.font_size = 38
	max_lbl.outline_size = 10
	max_lbl.modulate = Color(1.0, 0.45, 0.45)
	max_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	max_lbl.position = Vector3(dist_x, y_high + 0.6, 0.0)
	_drill_props_root.add_child(max_lbl)

	var min_lbl := Label3D.new()
	min_lbl.text = "v MIN LAUNCH: %.1f deg" % min_vla
	min_lbl.font_size = 38
	min_lbl.outline_size = 10
	min_lbl.modulate = Color(0.45, 0.85, 1.0)
	min_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	min_lbl.position = Vector3(dist_x, y_low - 0.6, 0.0)
	_drill_props_root.add_child(min_lbl)

	var center_lbl := Label3D.new()
	center_lbl.text = "OPTIMAL LAUNCH PORTAL | 1000 PTS"
	center_lbl.font_size = 46
	center_lbl.outline_size = 12
	center_lbl.modulate = Color(0.35, 1.0, 0.85)
	center_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	center_lbl.position = Vector3(dist_x, y_high + 1.8, 0.0)
	_drill_props_root.add_child(center_lbl)

	var corners: Array[Vector3] = [
		Vector3(dist_x, y_low, -half_w),
		Vector3(dist_x, y_low, half_w),
		Vector3(dist_x, y_high, -half_w),
		Vector3(dist_x, y_high, half_w)
	]
	for corner in corners:
		var guide := MeshInstance3D.new()
		var glm := CylinderMesh.new()
		var dist_to_corner: float = corner.length()
		glm.top_radius = 0.015; glm.bottom_radius = 0.015; glm.height = dist_to_corner
		guide.mesh = glm
		guide.material_override = _make_emissive_mat(Color(0.20, 0.95, 0.75), 0.35, 1.5)
		guide.position = corner * 0.5
		_drill_props_root.add_child(guide)
		if guide.is_inside_tree():
			guide.look_at(corner)
			guide.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))


func _spawn_shape_gate(start_gate_x: float, req_shape: String, offset_m: float) -> void:
	_spawn_start_gate(start_gate_x, 4.2, Color(0.35, 0.85, 1.0))
	var gates_def: Array[Dictionary] = [
		{"x": 35.0, "y": 9.0, "z": offset_m * 0.35, "r": 5.0, "col": Color(0.20, 0.85, 1.0), "name": "ENTRY GATE"},
		{"x": 85.0, "y": 17.0, "z": offset_m * 0.90, "r": 6.5, "col": Color(0.25, 1.0, 0.55), "name": "APEX GATE"}
	]

	for gd in gates_def:
		var ring_holder := Node3D.new()
		ring_holder.position = Vector3(gd["x"], gd["y"], gd["z"])
		_drill_props_root.add_child(ring_holder)

		var ring := MeshInstance3D.new()
		ring.mesh = _create_ring_mesh(float(gd["r"]) - 0.25, float(gd["r"]), 36)
		ring.material_override = _make_emissive_mat(gd["col"], 0.95, 3.5)
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring_holder.add_child(ring)

		var lbl := Label3D.new()
		lbl.text = "%s (%s)" % [gd["name"], req_shape.to_upper()]
		lbl.font_size = 40
		lbl.outline_size = 10
		lbl.modulate = gd["col"]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0.0, float(gd["r"]) + 1.2, 0.0)
		ring_holder.add_child(lbl)


func _spawn_cluster_pin(world_pos: Vector3, tier_col: Color) -> void:
	if _shot_pins_root == null:
		return
	var pin := Node3D.new()
	pin.position = Vector3(world_pos.x, 0.0, world_pos.z)
	_shot_pins_root.add_child(pin)

	var dot := MeshInstance3D.new()
	dot.mesh = _create_disc_mesh(0.55, 18)
	dot.material_override = _make_emissive_mat(tier_col, 0.85, 1.0)
	dot.position = Vector3(0.0, 0.05, 0.0)
	pin.add_child(dot)

	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.04; sm.bottom_radius = 0.04; sm.height = 1.4
	stem.mesh = sm
	stem.material_override = _make_emissive_mat(tier_col, 0.90, 1.1)
	stem.position = Vector3(0.0, 0.7, 0.0)
	pin.add_child(stem)


func _reset_ball_position() -> void:
	if is_inside_tree() and has_node("/root/TensionManager"):
		get_node("/root/TensionManager").stop_tension()
	_shot_in_progress = false
	if player != null and player.ball != null:
		player.global_position = Vector3(0.0, 0.05, 0.0)
		player.ball.spawn_position = player.global_position
		if player.has_method("set_profile"):
			player.set_profile(_player_name)
		player.ball.reset()
		player.reset_ball()
	_update_aim_and_camera()
	if is_inside_tree() and has_node("/root/ScreenOffsetManager"):
		get_node("/root/ScreenOffsetManager").on_ready_for_shot()
	if is_inside_tree() and has_node("/root/LaunchMonitorManager"):
		var lm := get_node("/root/LaunchMonitorManager")
		if lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()


func _update_aim_and_camera() -> void:
	if player == null or player.ball == null:
		return
	var ball_pos: Vector3 = player.ball.global_position
	var diff := _target_aim_pos - ball_pos
	var angle_rad := atan2(diff.z, diff.x)
	player.ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)

	var back_dir := Vector3(-cos(angle_rad), 0.0, -sin(angle_rad)).normalized()
	var cam_pos := ball_pos + back_dir * 4.2 + Vector3.UP * 2.2
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		cam.global_position = cam_pos
		var look_dir := (_target_aim_pos - ball_pos).normalized()
		cam.look_at(ball_pos + look_dir * 16.0 + Vector3.UP * 1.1)
	_last_camera_offset = cam_pos - ball_pos


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if _target_arrow_node != null and is_instance_valid(_target_arrow_node):
		_target_arrow_node.position.y = TARGET_ARROW_BASE_Y + sin(t * 2.8) * 0.25

	for ret in _rotating_reticles:
		if ret != null and is_instance_valid(ret):
			ret.rotation.y = t * 1.8

	for b in _pulsing_beacons:
		if b != null and is_instance_valid(b) and b.material_override is StandardMaterial3D:
			(b.material_override as StandardMaterial3D).emission_energy_multiplier = 3.5 + sin(t * 4.0) * 0.8


func _physics_process(delta: float) -> void:
	if player != null and player.ball != null:
		var ball_state = player.ball.state
		if ball_state == PhysicsEnums.BallState.FLIGHT or ball_state == PhysicsEnums.BallState.ROLLOUT:
			_camera_following = true
			var ball_pos: Vector3 = player.ball.global_position
			var cam := get_node_or_null("Camera3D") as Camera3D
			if cam != null:
				cam.global_position = cam.global_position.lerp(ball_pos + _last_camera_offset, delta * 8.0)
				cam.look_at(ball_pos + Vector3.UP * 0.1)
		elif _camera_following:
			_camera_following = false
			if is_inside_tree() and has_node("/root/TensionManager"):
				get_node("/root/TensionManager").stop_tension()
			_update_aim_and_camera()
			if is_inside_tree() and has_node("/root/ScreenOffsetManager"):
				get_node("/root/ScreenOffsetManager").on_ready_for_shot()


# ─── LAUNCH MONITOR & SIM SHOT INPUT ──────────────────────────────────────────
func _connect_launch_monitor() -> void:
	if is_inside_tree() and has_node("/root/LaunchMonitorManager"):
		var lm := get_node("/root/LaunchMonitorManager")
		if not lm.hit_ball.is_connected(_on_launch_monitor_hit_ball):
			lm.hit_ball.connect(_on_launch_monitor_hit_ball)
		if lm.has_method("_update_hud_display"):
			lm.call("_update_hud_display")
		if lm.has_method("notify_ball_at_rest"):
			lm.call("notify_ball_at_rest")

	var tcp_server := get_node_or_null("TCPServer")
	if tcp_server == null and ResourceLoader.exists("res://addons/launch_monitors/common/tcp_server/TcpServer.cs"):
		var tcp_script = load("res://addons/launch_monitors/common/tcp_server/TcpServer.cs")
		if tcp_script != null:
			tcp_server = tcp_script.new()
			tcp_server.name = "TCPServer"
			add_child(tcp_server)
	if tcp_server != null and tcp_server.has_signal("HitBall") and not tcp_server.HitBall.is_connected(_on_launch_monitor_hit_ball):
		tcp_server.HitBall.connect(_on_launch_monitor_hit_ball)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_settings()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start_new_drill_session()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H or event.keycode == KEY_SPACE:
			if not _drill_completed:
				_fire_simulated_shot()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			SceneManager.change_scene(TRAINING_MENU_SCENE)
			get_viewport().set_input_as_handled()


func _fire_simulated_shot() -> void:
	if _drill_completed or _shot_in_progress:
		return
	if player == null or player.ball == null or player.ball.state != PhysicsEnums.BallState.REST:
		return

	var target_yds := float(_current_stage_target.get("distance_yds", 150.0))
	var mode := str(_current_stage_target.get("mode", "corridor"))
	var dist_m := maxf(20.0, (target_yds + _rng.randf_range(-8.0, 8.0)) * YARD_TO_M)
	var vla := float(Catalog.get_optimal_vla_window(_active_club).get("ideal", 19.0)) + _rng.randf_range(-3.0, 3.0)
	var hla := _rng.randf_range(-3.5, 3.5)
	var spin_axis := _rng.randf_range(-8.0, 8.0)

	if mode == "shape_gate":
		var hand_sign := -1.0 if _player_handedness == 1 else 1.0
		var req := str(_current_stage_target.get("shape", "draw"))
		var sign := (-1.0 if req == "draw" else 1.0) * hand_sign
		hla = -sign * _rng.randf_range(1.0, 3.0)
		spin_axis = sign * _rng.randf_range(6.0, 14.0)
	elif mode == "launch_window":
		vla += _rng.randf_range(-3.2, 3.2)

	var speed_mph := sqrt(dist_m * 9.8 / maxf(0.15, sin(deg_to_rad(clampf(vla * 1.9, 20.0, 65.0))))) * 2.23694 * 1.04
	var club_speed_mph := speed_mph / maxf(1.05, Catalog.get_expected_smash(_active_club) - _rng.randf_range(-0.02, 0.08))
	var test_data := {
		"Speed": speed_mph,
		"BallSpeed": speed_mph,
		"ClubSpeed": club_speed_mph,
		"VLA": vla,
		"HLA": hla,
		"SpinAxis": spin_axis,
		"TotalSpin": 3400.0 if _active_club == "Dr" else 6200.0,
		"BackSpin": 3300.0 if _active_club == "Dr" else 6000.0,
		"SideSpin": 0.0,
		"ShotType": "full",
		"club": _active_club
	}
	_pending_shot_is_sim = true
	_launch_ball_with_data(test_data)


func _on_launch_monitor_hit_ball(data: Dictionary) -> void:
	_pending_shot_is_sim = false
	_launch_ball_with_data(data)


func _launch_ball_with_data(data: Dictionary) -> void:
	if _drill_completed or player == null or player.ball == null:
		return
	if player.ball.state != PhysicsEnums.BallState.REST:
		return

	var speed_val := float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var shot_type := str(data.get("ShotType", "")).to_lower()
	if speed_val <= 0.1 or shot_type == "practice":
		return

	if is_inside_tree() and has_node("/root/TensionManager"):
		get_node("/root/TensionManager").stop_tension()
	if is_inside_tree() and has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")

	_shot_in_progress = true
	if is_inside_tree() and has_node("/root/ScreenOffsetManager"):
		get_node("/root/ScreenOffsetManager").on_shot_started()

	# player._on_tcp_client_hit_ball applies RainPhysics, BallTypePhysics, FoamBallBoost, PowerCalibration internally
	player._on_tcp_client_hit_ball(data)
	_raw_ball_data = data.duplicate()
	_update_stats_display(false)


func _on_ball_rest(shot_data: Dictionary) -> void:
	if _drill_completed:
		return
	if is_inside_tree() and has_node("/root/TensionManager"):
		get_node("/root/TensionManager").stop_tension()
	if is_inside_tree() and has_node("/root/LaunchMonitorManager"):
		var lm := get_node("/root/LaunchMonitorManager")
		if lm.has_method("notify_ball_at_rest"):
			lm.notify_ball_at_rest()

	_raw_ball_data = shot_data.duplicate()
	_update_stats_display(true)

	# Record ONLY real (non-simulated) shots into player global club averages
	if not _pending_shot_is_sim and is_inside_tree() and has_node("/root/MultiplayerManager"):
		var mp := get_node("/root/MultiplayerManager")
		if mp.has_method("record_global_shot"):
			var rec_payload := shot_data.duplicate()
			var stage_dist_yds := float(_current_stage_target.get("distance_yds", 0.0))
			if stage_dist_yds > 0.0 and str(_current_stage_target.get("mode", "")) in ["bullseye", "bullseye_ladder", "bullseye_random", "shape_gate"]:
				rec_payload["TargetDistance"] = stage_dist_yds * YARD_TO_M
			mp.record_global_shot(_player_name, _active_club, rec_payload)

	var ball_pos: Vector3 = player.ball.global_position
	var metrics := _build_shot_metrics_from_rest(shot_data, ball_pos)
	_process_evaluated_shot(metrics, ball_pos, true)


func _build_shot_metrics_from_rest(shot_data: Dictionary, ball_pos: Vector3) -> Dictionary:
	var carry_m := float(shot_data.get("CarryDistance", 0.0))
	var total_m := float(shot_data.get("TotalDistance", carry_m))
	var side_m := float(shot_data.get("SideDistance", 0.0))
	var carry_yds := carry_m * M_TO_YDS
	var total_yds := total_m * M_TO_YDS
	var side_yds := side_m * M_TO_YDS

	var target_x_m := float(_current_stage_target.get("distance_yds", 150.0)) * YARD_TO_M
	var target_z_m := 0.0
	var dist_to_target_yds := Vector2(ball_pos.x, ball_pos.z).distance_to(Vector2(target_x_m, target_z_m)) * M_TO_YDS

	var metrics := {
		"carry_yds": carry_yds,
		"total_yds": total_yds,
		"side_yds": side_yds,
		"vla_deg": float(shot_data.get("VLA", 18.0)),
		"ball_speed_mph": float(shot_data.get("BallSpeed", shot_data.get("Speed", 0.0))),
		"club_speed_mph": float(shot_data.get("ClubSpeed", shot_data.get("club_speed", 0.0))),
		"smash_factor": float(shot_data.get("SmashFactor", shot_data.get("smash_factor", 0.0))),
		"face_to_path_deg": shot_data.get("FaceToPath", null),
		"spin_axis_deg": shot_data.get("SpinAxis", null)
	}
	if str(_current_stage_target.get("mode", "")) in ["bullseye", "bullseye_ladder", "bullseye_random", "dispersion_circle"]:
		metrics["dist_to_target_yds"] = dist_to_target_yds
	return metrics


func submit_shot_for_test(shot_metrics: Dictionary) -> Dictionary:
	var world_pos := Vector3(
		float(shot_metrics.get("carry_yds", 150.0)) * YARD_TO_M,
		0.0,
		float(shot_metrics.get("side_yds", 0.0)) * YARD_TO_M
	)
	return _process_evaluated_shot(shot_metrics, world_pos, false)


func _spawn_hit_reaction(ball_pos: Vector3, result: Dictionary) -> void:
	var tier := str(result.get("tier", "MISS"))
	var col: Color = result.get("tier_color", Color.WHITE)
	var points: int = int(result.get("points_awarded", 0))
	var streak: int = int(result.get("streak_after", 0))

	# 1. Ground Energy Shockwave Ring
	var shockwave := MeshInstance3D.new()
	shockwave.mesh = _create_ring_mesh(0.8, 1.4, 40)
	var sw_mat := StandardMaterial3D.new()
	sw_mat.albedo_color = Color(col.r, col.g, col.b, 0.95)
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	sw_mat.emission_enabled = true
	sw_mat.emission = col
	sw_mat.emission_energy_multiplier = 3.8
	sw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shockwave.material_override = sw_mat
	shockwave.position = Vector3(ball_pos.x, 0.045, ball_pos.z)
	add_child(shockwave)

	var sw_tw := create_tween()
	sw_tw.set_parallel(true)
	sw_tw.tween_property(shockwave, "scale", Vector3(10.0, 1.0, 10.0), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sw_tw.tween_property(sw_mat, "albedo_color:a", 0.0, 0.65)
	sw_tw.chain().tween_callback(shockwave.queue_free)

	# 2. Vertical Light Flare Pillar
	var pillar := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.35; pm.bottom_radius = 0.45; pm.height = 42.0
	pillar.mesh = pm
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.emission_enabled = true
	p_mat.emission = col
	p_mat.emission_energy_multiplier = 4.2
	p_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = p_mat
	pillar.position = Vector3(ball_pos.x, 21.0, ball_pos.z)
	add_child(pillar)

	var p_tw := create_tween()
	p_tw.set_parallel(true)
	p_tw.tween_property(pillar, "scale:x", 0.05, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p_tw.tween_property(pillar, "scale:z", 0.05, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p_tw.tween_property(p_mat, "albedo_color:a", 0.0, 0.95)
	p_tw.chain().tween_callback(pillar.queue_free)

	# 3. Particle Sparks Burst (CPUParticles3D)
	if tier in ["PERFECT", "GREAT", "GOOD"]:
		var particles := CPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.lifetime = 1.3
		particles.amount = 70 if tier == "PERFECT" else 40
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 0.35
		particles.direction = Vector3(0.0, 1.0, 0.0)
		particles.spread = 55.0
		particles.initial_velocity_min = 6.0
		particles.initial_velocity_max = 14.0
		particles.gravity = Vector3(0.0, -11.0, 0.0)
		var part_mesh := SphereMesh.new()
		part_mesh.radius = 0.08; part_mesh.height = 0.16
		particles.mesh = part_mesh
		var part_mat := StandardMaterial3D.new()
		part_mat.albedo_color = col
		part_mat.emission_enabled = true
		part_mat.emission = col
		part_mat.emission_energy_multiplier = 4.0
		part_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		particles.material_override = part_mat
		particles.position = Vector3(ball_pos.x, 0.3, ball_pos.z)
		add_child(particles)

		get_tree().create_timer(1.8).timeout.connect(func():
			if particles != null and is_instance_valid(particles):
				particles.queue_free()
		)

	# 4. 3D Floating World-Space Judgment Banner
	var stamp3d := Label3D.new()
	var stamp_txt := "* %s! +%d *" % [tier, points] if tier in ["PERFECT", "GREAT"] else "%s (+%d)" % [tier, points]
	if streak >= 2:
		stamp_txt += " (x%d)" % ShotEvaluator.get_combo_multiplier(streak)
	stamp3d.text = stamp_txt
	stamp3d.font_size = 54
	stamp3d.outline_size = 14
	stamp3d.outline_modulate = Color(0, 0, 0, 0.95)
	stamp3d.modulate = col
	stamp3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stamp3d.position = Vector3(ball_pos.x, 1.2, ball_pos.z)
	add_child(stamp3d)

	var s_tw := create_tween()
	s_tw.set_parallel(true)
	s_tw.tween_property(stamp3d, "position:y", ball_pos.y + 4.2, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	s_tw.tween_property(stamp3d, "scale", Vector3(1.3, 1.3, 1.3), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	s_tw.chain().tween_interval(0.8)
	s_tw.chain().tween_property(stamp3d, "modulate:a", 0.0, 0.5)
	s_tw.chain().tween_callback(stamp3d.queue_free)


func _process_evaluated_shot(shot_metrics: Dictionary, ball_pos: Vector3, use_reset_timer: bool) -> Dictionary:
	if _drill_completed:
		return {}
	var result := ShotEvaluator.evaluate_shot(
		_drill,
		shot_metrics,
		_current_stage_target,
		_shot_results,
		_difficulty,
		_player_handedness
	)
	_shot_results.append(result)

	if str(_current_stage_target.get("mode", "")) == "dispersion_circle":
		_spawn_cluster_pin(ball_pos, result["tier_color"])

	_spawn_hit_reaction(ball_pos, result)

	_update_gauge_with_result(result)
	_show_judgment_feedback(result)
	_update_timeline_badge(_shot_results.size() - 1, result)
	_refresh_hud()

	if _shot_results.size() >= _total_shots_target:
		_finish_drill_session(use_reset_timer)
		return result

	if use_reset_timer:
		var token := _session_token
		var gs := _get_gs()
		var reset_delay := 1.8
		if gs != null and "range_settings" in gs and gs.range_settings != null and "ball_reset_timer" in gs.range_settings:
			reset_delay = maxf(1.3, float(gs.range_settings.ball_reset_timer.value))
		_advance_to_next_shot_delayed(reset_delay, token)
	else:
		_prepare_stage_for_shot(_shot_results.size())
		_refresh_hud()

	return result


func _advance_to_next_shot_delayed(delay_s: float, token: int) -> void:
	await get_tree().create_timer(delay_s).timeout
	if not is_inside_tree() or token != _session_token or _drill_completed:
		return
	_prepare_stage_for_shot(_shot_results.size())
	_reset_ball_position()
	_refresh_hud()


func _finish_drill_session(delayed_modal: bool) -> void:
	_drill_completed = true
	var summary := ShotEvaluator.compute_session_summary(_drill, _shot_results)
	var save_res := ProgressStore.record_session(
		_player_name,
		str(_drill.get("id", "fairway_finder")),
		summary,
		_difficulty,
		_progress_path_override
	)
	if delayed_modal:
		var token := _session_token
		await get_tree().create_timer(1.7).timeout
		if not is_inside_tree() or token != _session_token:
			return
	_show_summary_modal(summary, save_res)


# ─── RHYTHM FEEDBACK & HUD ────────────────────────────────────────────────────
func _update_gauge_with_result(result: Dictionary) -> void:
	if _gauge_control == null:
		return
	var ghosts: Array[float] = []
	var start_idx := maxi(0, _bias_history.size() - 3)
	for i in range(start_idx, _bias_history.size()):
		ghosts.append(_bias_history[i])
	var bias := float(result.get("signed_bias", 0.0))
	_gauge_control.set_shot_bias(bias, result["tier_color"], ghosts)
	_bias_history.append(bias)
	if _gauge_status_lbl != null:
		_gauge_status_lbl.text = "%s  |  %s" % [str(result["primary_metric_text"]), str(result["trend_text"])]
		_gauge_status_lbl.add_theme_color_override("font_color", result["trend_color"])


func _show_judgment_feedback(result: Dictionary) -> void:
	if _judgment_panel == null:
		return
	var col: Color = result["tier_color"]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.14, 0.94)
	style.border_color = col
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	_judgment_panel.add_theme_stylebox_override("panel", style)

	_judgment_tier_lbl.text = str(result["tier_label"])
	_judgment_tier_lbl.add_theme_color_override("font_color", col)

	var mult := int(result["multiplier"])
	var pts := int(result["points_awarded"])
	_judgment_pts_lbl.text = "+%d PTS%s" % [pts, "  (%dx COMBO!)" % mult if mult > 1 else ""]
	_judgment_pts_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD if pts > 0 else ThemeManager.COLOR_TEXT_MUTED)

	_judgment_trend_lbl.text = str(result["trend_text"])
	_judgment_trend_lbl.add_theme_color_override("font_color", result["trend_color"])

	_judgment_detail_lbl.text = "%s\n%s" % [str(result["primary_metric_text"]), str(result["coaching_detail"])]

	_judgment_panel.visible = true
	_judgment_panel.modulate.a = 1.0
	_judgment_panel.pivot_offset = _judgment_panel.size * 0.5
	_judgment_panel.scale = Vector2(0.55, 0.55)

	if _judgment_tween != null and _judgment_tween.is_valid():
		_judgment_tween.kill()
	_judgment_tween = create_tween()
	_judgment_tween.tween_property(_judgment_panel, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_judgment_tween.tween_property(_judgment_panel, "scale", Vector2(1.0, 1.0), 0.10)
	_judgment_tween.tween_interval(2.0)
	_judgment_tween.tween_property(_judgment_panel, "modulate:a", 0.0, 0.45)
	_judgment_tween.tween_callback(func():
		if _judgment_panel != null and is_instance_valid(_judgment_panel):
			_judgment_panel.visible = false
	)

	# Audio feedback
	if int(result["streak_after"]) >= 2 and _combo_panel != null and is_instance_valid(_combo_panel):
		_combo_panel.pivot_offset = _combo_panel.size * 0.5
		_combo_panel.scale = Vector2(1.18, 1.18)
		var combo_tw := create_tween()
		combo_tw.tween_property(_combo_panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _sfx_ding_player != null and _sfx_ding_player.stream != null:
		_sfx_ding_player.pitch_scale = float(result.get("audio_pitch", 1.0))
		_sfx_ding_player.play()
	if str(result["tier"]) == ShotEvaluator.TIER_PERFECT or int(result["streak_after"]) >= 4:
		if _sfx_applause_player != null and _sfx_applause_player.stream != null:
			_sfx_applause_player.play()
		var gs := _get_gs()
		if gs != null and gs.has_method("play_golf_clap"):
			gs.play_golf_clap()


func _refresh_hud() -> void:
	if _drill_title_lbl == null:
		return
	_drill_title_lbl.text = str(_drill.get("name", "Training Drill"))
	_target_info_lbl.text = _format_stage_target_text()

	var current_idx := mini(_shot_results.size() + 1, _total_shots_target)
	_shot_progress_lbl.text = "%d / %d" % [current_idx, _total_shots_target]

	var summary := ShotEvaluator.compute_session_summary(_drill, _shot_results)
	_score_lbl.text = str(int(summary["total_score"]))
	_pace_grade_lbl.text = "--" if _shot_results.is_empty() else str(summary["grade"])

	var streak := 0
	if not _shot_results.is_empty():
		streak = int(_shot_results[_shot_results.size() - 1].get("streak_after", 0))
	var mult := ShotEvaluator.get_combo_multiplier(streak)
	_combo_lbl.text = " %dx COMBO | x%d" % [streak, mult] if streak >= 2 else "%dx COMBO | x%d" % [streak, mult]
	_combo_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD if streak >= 4 else (ThemeManager.COLOR_TEXT_SUCCESS if streak >= 2 else ThemeManager.COLOR_TEXT_MUTED))

	if _coach_target_lbl != null:
		_coach_target_lbl.text = str(_current_stage_target.get("label", ""))
	if _coach_cue_lbl != null:
		_coach_cue_lbl.text = str(_drill.get("coaching_cue", ""))
	if _coach_club_lbl != null:
		_coach_club_lbl.text = "Active Club: %s  |  Mode: %s" % [_active_club, Catalog.get_difficulty_display_name(_difficulty)]
	_update_coach_legend()
	if _gauge_left_lbl != null:
		var left_lbl := str(_drill.get("gauge_left_label", "LEFT"))
		var right_lbl := str(_drill.get("gauge_right_label", "RIGHT"))
		if _player_handedness == 1 and left_lbl == "HOOK" and right_lbl == "SLICE":
			left_lbl = "SLICE"
			right_lbl = "HOOK"
		elif str(_current_stage_target.get("mode", "")) == "corridor":
			left_lbl = "LEFT"
			right_lbl = "RIGHT"
		_gauge_left_lbl.text = "<- %s" % left_lbl
		_gauge_right_lbl.text = "%s ->" % right_lbl


func _update_coach_legend() -> void:
	if _coach_legend_vbox == null:
		return
	for child in _coach_legend_vbox.get_children():
		child.queue_free()

	var diff_mult := Catalog.get_difficulty_multiplier(_difficulty)
	var th: Dictionary = _current_stage_target.get("thresholds", _drill.get("thresholds", {}))
	var mode := str(_current_stage_target.get("mode", "corridor"))

	var rows: Array[Dictionary] = []
	if mode == "launch_window":
		var min_v := float(_current_stage_target.get("min_vla_deg", 16.0))
		var max_v := float(_current_stage_target.get("max_vla_deg", 22.0))
		rows = [
			{"t": "* PERFECT: Inside %.0f deg-%.0f deg" % [min_v, max_v], "c": Color(1.0, 0.85, 0.25)},
			{"t": "NICE SHOT: +/-%.1f deg" % (float(th.get("great", 3.0)) * diff_mult), "c": Color(0.30, 0.96, 0.55)},
			{"t": "GOOD: +/-%.1f deg" % (float(th.get("good", 4.8)) * diff_mult), "c": Color(0.35, 0.84, 1.0)}
		]
	elif mode == "compression_corridor":
		var exp_s := Catalog.get_expected_smash(_active_club)
		rows = [
			{"t": "* PERFECT: >= %.2f Smash" % (exp_s - float(th.get("perfect", 0.03)) * diff_mult), "c": Color(1.0, 0.85, 0.25)},
			{"t": "NICE SHOT: >= %.2f Smash" % (exp_s - float(th.get("great", 0.06)) * diff_mult), "c": Color(0.30, 0.96, 0.55)},
			{"t": "GOOD: >= %.2f Smash" % (exp_s - float(th.get("good", 0.10)) * diff_mult), "c": Color(0.35, 0.84, 1.0)}
		]
	else:
		var gs := _get_gs()
		var is_imperial := true
		if gs != null and "range_settings" in gs and gs.range_settings != null and "range_units" in gs.range_settings:
			is_imperial = (gs.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL)
		var unit_mult := 1.0 if is_imperial else YARD_TO_M
		var unit_str := "yds" if is_imperial else "m"
		rows = [
			{"t": "* PERFECT: <= %.1f %s" % [float(th.get("perfect", 5.0)) * diff_mult * unit_mult, unit_str], "c": Color(1.0, 0.85, 0.25)},
			{"t": "NICE SHOT: <= %.1f %s" % [float(th.get("great", 10.0)) * diff_mult * unit_mult, unit_str], "c": Color(0.30, 0.96, 0.55)},
			{"t": "GOOD: <= %.1f %s" % [float(th.get("good", 16.0)) * diff_mult * unit_mult, unit_str], "c": Color(0.35, 0.84, 1.0)}
		]

	for r in rows:
		var l_lbl := Label.new()
		l_lbl.text = str(r["t"])
		l_lbl.add_theme_font_size_override("font_size", 12)
		l_lbl.add_theme_color_override("font_color", r["c"])
		_coach_legend_vbox.add_child(l_lbl)


func _format_stage_target_text() -> String:
	var mode := str(_current_stage_target.get("mode", "corridor"))
	var dist_yds := float(_current_stage_target.get("distance_yds", 150.0))
	var gs := _get_gs()
	var is_imperial := true
	if gs != null and "range_settings" in gs and gs.range_settings != null and "range_units" in gs.range_settings:
		is_imperial = (gs.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL)

	if mode == "launch_window":
		return "WINDOW %.0f deg-%.0f deg" % [float(_current_stage_target.get("min_vla_deg", 16.0)), float(_current_stage_target.get("max_vla_deg", 22.0))]
	if mode == "compression_corridor":
		return "SMASH %.2f+" % Catalog.get_expected_smash(_active_club)
	if is_imperial:
		return "%d YDS" % int(round(dist_yds))
	return "%d M" % int(round(dist_yds * YARD_TO_M))


# ─── BUILD HUD & CONTROLS ─────────────────────────────────────────────────────
func _setup_ui() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	_hud_layer.layer = 1
	add_child(_hud_layer)

	_hud_control = Control.new()
	_hud_control.name = "HUDControl"
	_hud_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_control)

	# 1. Top Scoreboard + Shot Timeline
	var top_vbox := VBoxContainer.new()
	top_vbox.anchor_left = 0.5; top_vbox.anchor_right = 0.5
	top_vbox.anchor_top = 0.0; top_vbox.anchor_bottom = 0.0
	top_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_vbox.offset_left = -470; top_vbox.offset_right = 470
	top_vbox.offset_top = 14
	top_vbox.add_theme_constant_override("separation", 6)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_control.add_child(top_vbox)

	var score_panel := PanelContainer.new()
	score_panel.name = "ScoreboardPanel"
	score_panel.custom_minimum_size = Vector2(940, 82)
	ThemeManager.apply_card_panel_style(score_panel, false, 10, 18, 8, 18, 8)
	top_vbox.add_child(score_panel)

	var score_hbox := HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 12)
	score_panel.add_child(score_hbox)

	var drill_col := _make_stat_col("DRILL", "Training Drill", ThemeManager.COLOR_TEXT_ACCENT, 18)
	_drill_title_lbl = drill_col["val"]
	drill_col["box"].size_flags_stretch_ratio = 1.5
	score_hbox.add_child(drill_col["box"])

	var tgt_col := _make_stat_col("TARGET", "150 YDS", Color(1.0, 0.45, 0.45), 24)
	_target_info_lbl = tgt_col["val"]
	score_hbox.add_child(tgt_col["box"])

	var shot_col := _make_stat_col("SHOT", "1 / 10", ThemeManager.COLOR_TEXT_ACCENT, 24)
	_shot_progress_lbl = shot_col["val"]
	score_hbox.add_child(shot_col["box"])

	var pts_col := _make_stat_col("SCORE", "0", ThemeManager.COLOR_TEXT_GOLD, 24)
	_score_lbl = pts_col["val"]
	score_hbox.add_child(pts_col["box"])

	_combo_panel = PanelContainer.new()
	_combo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_card_panel_style(_combo_panel, false, 8, 8, 4, 8, 4)
	score_hbox.add_child(_combo_panel)
	var combo_v := VBoxContainer.new()
	combo_v.alignment = BoxContainer.ALIGNMENT_CENTER
	_combo_panel.add_child(combo_v)
	var combo_hdr := Label.new()
	combo_hdr.text = "COMBO"
	combo_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_hdr.add_theme_font_size_override("font_size", 11)
	combo_hdr.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	combo_v.add_child(combo_hdr)
	_combo_lbl = Label.new()
	_combo_lbl.text = "0x COMBO | x1"
	_combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_lbl.add_theme_font_size_override("font_size", 18)
	combo_v.add_child(_combo_lbl)

	var grade_col := _make_stat_col("PACE", "--", ThemeManager.COLOR_TEXT_SUCCESS, 26)
	_pace_grade_lbl = grade_col["val"]
	score_hbox.add_child(grade_col["box"])

	_timeline_hbox = HBoxContainer.new()
	_timeline_hbox.name = "ShotTimeline"
	_timeline_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_timeline_hbox.add_theme_constant_override("separation", 6)
	top_vbox.add_child(_timeline_hbox)

	# 2. Left Side: GridCanvas + ClubSelector + Stats Toggle
	var gc_script = load("res://UI/grid_canvas.gd")
	if gc_script != null:
		_grid_canvas = Control.new()
		_grid_canvas.name = "GridCanvas"
		_grid_canvas.set_script(gc_script)
		_grid_canvas.position = Vector2(20, 0)
		_grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_control.add_child(_grid_canvas)

	if ResourceLoader.exists("res://UI/ClubSelector/club_selector.tscn"):
		var cs_scene := load("res://UI/ClubSelector/club_selector.tscn") as PackedScene
		if cs_scene != null:
			_club_selector = cs_scene.instantiate()
			_club_selector.name = "ClubSelector"
			_club_selector.position = Vector2(20, 128)
			_hud_control.add_child(_club_selector)

	_stats_btn = Button.new()
	_stats_btn.name = "StatsButton"
	if ResourceLoader.exists("res://assets/images/icons/stats.svg"):
		_stats_btn.icon = load("res://assets/images/icons/stats.svg")
	_stats_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_btn.custom_minimum_size = Vector2(58, 58)
	_stats_btn.anchor_left = 0.0; _stats_btn.anchor_right = 0.0
	_stats_btn.anchor_top = 1.0; _stats_btn.anchor_bottom = 1.0
	_stats_btn.offset_left = 24; _stats_btn.offset_right = 82
	_stats_btn.offset_top = -82; _stats_btn.offset_bottom = -24
	ThemeManager.apply_nav_button_style(_stats_btn, 28)
	_stats_btn.pressed.connect(_toggle_stats_visibility)
	_hud_control.add_child(_stats_btn)

	# 3. Right Side: Compact Coach Card
	var coach_panel := PanelContainer.new()
	coach_panel.name = "CoachCard"
	coach_panel.custom_minimum_size = Vector2(270, 0)
	coach_panel.anchor_left = 1.0; coach_panel.anchor_right = 1.0
	coach_panel.anchor_top = 0.5; coach_panel.anchor_bottom = 0.5
	coach_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	coach_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	coach_panel.offset_left = -290; coach_panel.offset_right = -20
	coach_panel.offset_top = -150; coach_panel.offset_bottom = 130
	ThemeManager.apply_card_panel_style(coach_panel, false, 10, 14, 12, 14, 12)
	_hud_control.add_child(coach_panel)

	var coach_vbox := VBoxContainer.new()
	coach_vbox.add_theme_constant_override("separation", 8)
	coach_panel.add_child(coach_vbox)

	var coach_hdr := Label.new()
	coach_hdr.text = "COACH BRIEFING"
	coach_hdr.add_theme_font_size_override("font_size", 13)
	coach_hdr.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	coach_vbox.add_child(coach_hdr)

	_coach_target_lbl = Label.new()
	_coach_target_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_coach_target_lbl.add_theme_font_size_override("font_size", 15)
	_coach_target_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	coach_vbox.add_child(_coach_target_lbl)

	_coach_club_lbl = Label.new()
	_coach_club_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_coach_club_lbl.add_theme_font_size_override("font_size", 12)
	_coach_club_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	coach_vbox.add_child(_coach_club_lbl)

	coach_vbox.add_child(HSeparator.new())

	_coach_cue_lbl = Label.new()
	_coach_cue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_coach_cue_lbl.add_theme_font_size_override("font_size", 13)
	_coach_cue_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	coach_vbox.add_child(_coach_cue_lbl)

	_coach_legend_vbox = VBoxContainer.new()
	_coach_legend_vbox.add_theme_constant_override("separation", 3)
	coach_vbox.add_child(_coach_legend_vbox)
	for row_def in [
		{"t": "* PERFECT", "c": Color(1.0, 0.85, 0.25)},
		{"t": "NICE SHOT", "c": Color(0.30, 0.96, 0.55)},
		{"t": "GOOD / CLOSE", "c": Color(0.35, 0.84, 1.0)}
	]:
		var l_lbl := Label.new()
		l_lbl.text = row_def["t"]
		l_lbl.add_theme_font_size_override("font_size", 12)
		l_lbl.add_theme_color_override("font_color", row_def["c"])
		_coach_legend_vbox.add_child(l_lbl)

	# 4. Center-Screen Animated Judgment Stamp
	_judgment_panel = PanelContainer.new()
	_judgment_panel.name = "JudgmentStamp"
	_judgment_panel.visible = false
	_judgment_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_judgment_panel.custom_minimum_size = Vector2(520, 0)
	_judgment_panel.anchor_left = 0.5; _judgment_panel.anchor_right = 0.5
	_judgment_panel.anchor_top = 0.20; _judgment_panel.anchor_bottom = 0.20
	_judgment_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_control.add_child(_judgment_panel)

	var j_vbox := VBoxContainer.new()
	j_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	j_vbox.add_theme_constant_override("separation", 5)
	_judgment_panel.add_child(j_vbox)

	_judgment_tier_lbl = Label.new()
	_judgment_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_tier_lbl.add_theme_font_size_override("font_size", 34)
	j_vbox.add_child(_judgment_tier_lbl)

	_judgment_pts_lbl = Label.new()
	_judgment_pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_pts_lbl.add_theme_font_size_override("font_size", 18)
	j_vbox.add_child(_judgment_pts_lbl)

	_judgment_trend_lbl = Label.new()
	_judgment_trend_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_trend_lbl.add_theme_font_size_override("font_size", 17)
	j_vbox.add_child(_judgment_trend_lbl)

	_judgment_detail_lbl = Label.new()
	_judgment_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_judgment_detail_lbl.add_theme_font_size_override("font_size", 14)
	_judgment_detail_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	j_vbox.add_child(_judgment_detail_lbl)

	# 5. Rhythm Precision Gauge Panel (above bottom controls)
	var gauge_panel := PanelContainer.new()
	gauge_panel.name = "PrecisionGaugePanel"
	gauge_panel.custom_minimum_size = Vector2(560, 74)
	gauge_panel.anchor_left = 0.5; gauge_panel.anchor_right = 0.5
	gauge_panel.anchor_top = 1.0; gauge_panel.anchor_bottom = 1.0
	gauge_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gauge_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gauge_panel.offset_left = -280; gauge_panel.offset_right = 280
	gauge_panel.offset_top = -170; gauge_panel.offset_bottom = -94
	ThemeManager.apply_card_panel_style(gauge_panel, false, 10, 14, 6, 14, 6)
	_hud_control.add_child(gauge_panel)

	var gauge_vbox := VBoxContainer.new()
	gauge_vbox.add_theme_constant_override("separation", 3)
	gauge_panel.add_child(gauge_vbox)

	_gauge_status_lbl = Label.new()
	_gauge_status_lbl.text = "Hit a shot (or press H) to start live feedback"
	_gauge_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gauge_status_lbl.add_theme_font_size_override("font_size", 13)
	_gauge_status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	gauge_vbox.add_child(_gauge_status_lbl)

	var gauge_row := HBoxContainer.new()
	gauge_row.add_theme_constant_override("separation", 10)
	gauge_vbox.add_child(gauge_row)

	_gauge_left_lbl = Label.new()
	_gauge_left_lbl.custom_minimum_size = Vector2(72, 0)
	_gauge_left_lbl.add_theme_font_size_override("font_size", 12)
	_gauge_left_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	gauge_row.add_child(_gauge_left_lbl)

	_gauge_control = PrecisionGaugeControl.new()
	_gauge_control.custom_minimum_size = Vector2(360, 28)
	_gauge_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauge_row.add_child(_gauge_control)

	_gauge_right_lbl = Label.new()
	_gauge_right_lbl.custom_minimum_size = Vector2(72, 0)
	_gauge_right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gauge_right_lbl.add_theme_font_size_override("font_size", 12)
	_gauge_right_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	gauge_row.add_child(_gauge_right_lbl)

	# 6. Bottom Control Strip
	var ctrl_panel := PanelContainer.new()
	ctrl_panel.name = "ControlsPanel"
	ctrl_panel.custom_minimum_size = Vector2(740, 68)
	ctrl_panel.anchor_left = 0.5; ctrl_panel.anchor_right = 0.5
	ctrl_panel.anchor_top = 1.0; ctrl_panel.anchor_bottom = 1.0
	ctrl_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ctrl_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctrl_panel.offset_left = -370; ctrl_panel.offset_right = 370
	ctrl_panel.offset_top = -84; ctrl_panel.offset_bottom = -16
	ThemeManager.apply_card_panel_style(ctrl_panel, false, 10, 14, 8, 14, 8)
	_hud_control.add_child(ctrl_panel)

	var ctrl_hbox := HBoxContainer.new()
	ctrl_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_hbox.add_theme_constant_override("separation", 10)
	ctrl_panel.add_child(ctrl_hbox)

	var sim_btn := Button.new()
	sim_btn.name = "SimShotButton"
	sim_btn.text = "SIM SHOT (H)"
	sim_btn.custom_minimum_size = Vector2(138, 46)
	ThemeManager.apply_primary_button_style(sim_btn, 8)
	sim_btn.pressed.connect(_fire_simulated_shot)
	ctrl_hbox.add_child(sim_btn)

	var retry_btn := Button.new()
	retry_btn.text = "RETRY (R)"
	retry_btn.custom_minimum_size = Vector2(110, 46)
	ThemeManager.apply_secondary_button_style(retry_btn, 8)
	retry_btn.pressed.connect(_start_new_drill_session)
	ctrl_hbox.add_child(retry_btn)

	var change_btn := Button.new()
	change_btn.text = "CHANGE DRILL"
	change_btn.custom_minimum_size = Vector2(142, 46)
	ThemeManager.apply_nav_button_style(change_btn, 8)
	change_btn.pressed.connect(func(): SceneManager.change_scene(TRAINING_MENU_SCENE))
	ctrl_hbox.add_child(change_btn)

	_theme_btn = Button.new()
	_theme_btn.name = "ThemeButton"
	_theme_btn.text = " NIGHT"
	_theme_btn.custom_minimum_size = Vector2(105, 46)
	ThemeManager.apply_nav_button_style(_theme_btn, 8)
	_theme_btn.pressed.connect(_on_cycle_theme_pressed)
	ctrl_hbox.add_child(_theme_btn)

	_music_toggle_btn = Button.new()
	_music_toggle_btn.custom_minimum_size = Vector2(48, 46)
	_music_toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_music_toggle_btn.expand_icon = true
	_music_toggle_btn.pressed.connect(_toggle_music)
	ctrl_hbox.add_child(_music_toggle_btn)
	_update_music_button_state()

	var settings_btn := Button.new()
	settings_btn.custom_minimum_size = Vector2(48, 46)
	if ResourceLoader.exists("res://Utils/Settings/Gear.png"):
		settings_btn.icon = load("res://Utils/Settings/Gear.png")
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_nav_button_style(settings_btn, 8)
	settings_btn.pressed.connect(_on_settings_pressed)
	ctrl_hbox.add_child(settings_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(124, 46)
	ThemeManager.apply_danger_button_style(menu_btn, 8)
	menu_btn.pressed.connect(func(): SceneManager.change_scene(MAIN_MENU_SCENE))
	ctrl_hbox.add_child(menu_btn)


func _make_stat_col(title_text: String, val_text: String, val_col: Color, val_size: int) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	box.add_child(t)
	var v := Label.new()
	v.text = val_text
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", val_size)
	v.add_theme_color_override("font_color", val_col)
	box.add_child(v)
	return {"box": box, "val": v}


func _build_timeline_badges() -> void:
	for c in _timeline_hbox.get_children():
		c.queue_free()
	_timeline_badges.clear()
	for i in range(_total_shots_target):
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(36, 26)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.10, 0.14, 0.20, 0.85)
		st.border_color = Color(0.28, 0.42, 0.58, 0.5)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		badge.add_theme_stylebox_override("panel", st)
		var lbl := Label.new()
		lbl.name = "Icon"
		lbl.text = str(i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DIM)
		badge.add_child(lbl)
		_timeline_hbox.add_child(badge)
		_timeline_badges.append(badge)


func _update_timeline_badge(idx: int, result: Dictionary) -> void:
	if idx < 0 or idx >= _timeline_badges.size():
		return
	var badge := _timeline_badges[idx]
	var col: Color = result["tier_color"]
	var st := StyleBoxFlat.new()
	st.bg_color = Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.95)
	st.border_color = col
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", st)
	var lbl := badge.get_node_or_null("Icon") as Label
	if lbl != null:
		var sym := "*"
		match str(result["tier"]):
			ShotEvaluator.TIER_GREAT: sym = "OK"
			ShotEvaluator.TIER_GOOD: sym = "|"
			ShotEvaluator.TIER_OK: sym = "~"
			ShotEvaluator.TIER_MISS: sym = "X"
		lbl.text = sym
		lbl.add_theme_color_override("font_color", col)


func _show_summary_modal(summary: Dictionary, save_res: Dictionary) -> void:
	if _summary_panel != null and is_instance_valid(_summary_panel):
		_summary_panel.queue_free()

	_summary_panel = PanelContainer.new()
	_summary_panel.name = "DrillSummaryModal"
	_summary_panel.custom_minimum_size = Vector2(560, 0)
	_summary_panel.anchor_left = 0.5; _summary_panel.anchor_right = 0.5
	_summary_panel.anchor_top = 0.5; _summary_panel.anchor_bottom = 0.5
	_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ThemeManager.apply_card_panel_style(_summary_panel, true, 14, 24, 22, 24, 22)
	_hud_control.add_child(_summary_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_summary_panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "DRILL COMPLETE - %s" % str(_drill.get("name", ""))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	vbox.add_child(hdr)

	var grade := str(summary.get("grade", "D"))
	var grade_lbl := Label.new()
	grade_lbl.text = "GRADE: %s" % grade
	grade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_lbl.add_theme_font_size_override("font_size", 46)
	grade_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD if grade in ["S", "A"] else ThemeManager.COLOR_TEXT_WHITE)
	vbox.add_child(grade_lbl)

	if bool(save_res.get("is_new_best_score", false)) or bool(save_res.get("is_new_best_grade", false)):
		var pb_lbl := Label.new()
		pb_lbl.text = "[NEW RECORD] NEW PERSONAL BEST!"
		pb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pb_lbl.add_theme_font_size_override("font_size", 16)
		pb_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
		vbox.add_child(pb_lbl)

	var metrics_lbl := Label.new()
	metrics_lbl.text = "Score: %d pts   |   Accuracy: %.1f%%   |   Best Streak: %dx" % [
		int(summary.get("total_score", 0)),
		float(summary.get("avg_accuracy", 0.0)),
		int(summary.get("max_streak", 0))
	]
	metrics_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metrics_lbl.add_theme_font_size_override("font_size", 16)
	metrics_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	vbox.add_child(metrics_lbl)

	var tc: Dictionary = summary.get("tier_counts", {})
	var breakdown_lbl := Label.new()
	breakdown_lbl.text = "* Perfect: %d  |  Nice: %d  |  Good: %d  |  Close: %d  |  Off: %d" % [
		int(tc.get(ShotEvaluator.TIER_PERFECT, 0)),
		int(tc.get(ShotEvaluator.TIER_GREAT, 0)),
		int(tc.get(ShotEvaluator.TIER_GOOD, 0)),
		int(tc.get(ShotEvaluator.TIER_OK, 0)),
		int(tc.get(ShotEvaluator.TIER_MISS, 0))
	]
	breakdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakdown_lbl.add_theme_font_size_override("font_size", 14)
	breakdown_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	vbox.add_child(breakdown_lbl)

	var trend_lbl := Label.new()
	trend_lbl.text = str(summary.get("trend_summary", ""))
	trend_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trend_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	trend_lbl.add_theme_font_size_override("font_size", 14)
	trend_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
	vbox.add_child(trend_lbl)

	var tip_lbl := Label.new()
	tip_lbl.text = "Coach Next Step: %s" % str(summary.get("next_step_tip", ""))
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_lbl.add_theme_font_size_override("font_size", 13)
	tip_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	vbox.add_child(tip_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var replay_btn := Button.new()
	replay_btn.text = "> PLAY AGAIN"
	replay_btn.custom_minimum_size = Vector2(150, 46)
	ThemeManager.apply_primary_button_style(replay_btn, 8)
	replay_btn.pressed.connect(_start_new_drill_session)
	btn_row.add_child(replay_btn)

	var next_btn := Button.new()
	next_btn.text = "* NEXT SUGGESTED"
	next_btn.custom_minimum_size = Vector2(175, 46)
	ThemeManager.apply_secondary_button_style(next_btn, 8)
	next_btn.pressed.connect(_launch_next_suggested_drill)
	btn_row.add_child(next_btn)

	var hub_btn := Button.new()
	hub_btn.text = "<- TRAINING HUB"
	hub_btn.custom_minimum_size = Vector2(155, 46)
	ThemeManager.apply_nav_button_style(hub_btn, 8)
	hub_btn.pressed.connect(func(): SceneManager.change_scene(TRAINING_MENU_SCENE))
	btn_row.add_child(hub_btn)


func _launch_next_suggested_drill() -> void:
	var rec := Recommender.recommend_for_player(_player_name, _progress_path_override)
	var prim: Dictionary = rec.get("primary", {})
	Catalog.set_active_session(
		str(prim.get("drill_id", "fairway_finder")),
		_player_name,
		str(rec.get("suggested_difficulty", _difficulty)),
		str(prim.get("recommended_club", "7i")),
		str(prim.get("reason", "")),
		true,
		prim.get("evidence", [])
	)
	_load_session_config()
	_start_new_drill_session()


# ─── STATS / SETTINGS / MUSIC HELPERS ─────────────────────────────────────────
func _toggle_stats_visibility() -> void:
	if _grid_canvas == null:
		return
	var dist_panel := _grid_canvas.get_node_or_null("Distance")
	var currently_vis: bool = dist_panel.visible if dist_panel != null else _grid_canvas.visible
	for child in _grid_canvas.get_children():
		if child.name != "ClubSelector":
			child.visible = not currently_vis


func _update_stats_display(is_final_rest: bool = true) -> void:
	if _grid_canvas == null or player == null:
		return
	var gs := _get_gs()
	var units: int = gs.range_settings.range_units.value if gs != null else PhysicsEnums.Units.IMPERIAL
	_display_data = ShotFormatter.format_ball_display(_raw_ball_data, player, units, is_final_rest, _display_data)
	var is_imperial := (units == PhysicsEnums.Units.IMPERIAL)

	for child in _grid_canvas.get_children():
		if child.name == "ClubSelector":
			continue
		var stat_def := StatDefinitions.get_stat_by_id(child.name)
		if stat_def.is_empty():
			continue
		if child.has_method("set_units"):
			child.call("set_units", str(stat_def.get("units_imperial" if is_imperial else "units_metric", "")))
		var val := str(_display_data.get(child.name, "---"))
		if (child.name == "VLA" or child.name == "HLA") and val != "---":
			val = "%.1f deg" % float(val)
		if child.has_method("set_data"):
			child.call("set_data", val)


func _toggle_music() -> void:
	var gs := _get_gs()
	if gs == null:
		return
	var cur := bool(gs.range_settings.minigame_music_enabled.value)
	gs.range_settings.minigame_music_enabled.set_value(not cur)
	_update_music_button_state()


func _update_music_button_state() -> void:
	if _music_toggle_btn == null:
		return
	var gs := _get_gs()
	var is_enabled := bool(gs.range_settings.minigame_music_enabled.value) if gs != null else true
	if is_enabled:
		if ResourceLoader.exists("res://assets/images/menu/music_on.svg"):
			_music_toggle_btn.icon = load("res://assets/images/menu/music_on.svg")
		ThemeManager.apply_secondary_button_style(_music_toggle_btn, 8)
	else:
		if ResourceLoader.exists("res://assets/images/menu/music_off.svg"):
			_music_toggle_btn.icon = load("res://assets/images/menu/music_off.svg")
		ThemeManager.apply_danger_button_style(_music_toggle_btn, 8)


func _on_cycle_theme_pressed() -> void:
	match _current_theme:
		"night":
			_apply_arena_theme("sunset")
			if _theme_btn != null:
				_theme_btn.text = " SUNSET"
		"sunset":
			_apply_arena_theme("day")
			if _theme_btn != null:
				_theme_btn.text = " DAY"
		_:
			_apply_arena_theme("night")
			if _theme_btn != null:
				_theme_btn.text = " NIGHT"


func _on_settings_pressed() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		return
	var settings_scene := load("res://UI/Settings/RangeSettings/range_settings.tscn") as PackedScene
	if settings_scene == null:
		return
	if _hud_layer != null:
		_hud_layer.visible = false
	_settings_layer = CanvasLayer.new()
	_settings_layer.layer = 105
	add_child(_settings_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.07, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_settings_layer.add_child(margin)

	var inst := settings_scene.instantiate()
	inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(inst)
	inst.close_settings_requested.connect(_close_settings)
	if inst.has_signal("manage_players_requested"):
		inst.manage_players_requested.connect(func():
			_close_settings()
			SceneManager.change_scene("res://UI/PlayersMenu/players_menu.tscn")
		)


func _close_settings() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		_settings_layer.queue_free()
		_settings_layer = null
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.visible = true


func _exit_tree() -> void:
	_session_token += 1
	if is_inside_tree() and has_node("/root/ScreenOffsetManager") and has_node("Camera3D"):
		get_node("/root/ScreenOffsetManager").unregister_camera($Camera3D)
