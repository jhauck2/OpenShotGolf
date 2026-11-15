extends Node

# TensionManager: Manages heartbeat SFX, pulsing screen border vignette,
# early trajectory prediction suspense, and camera tension effects for close putts and chips.

signal tension_started(mode: String)
signal tension_stopped()

const PUTT_THRESHOLD_METERS := 9.144   # 30 feet in meters (zone where suspense heartbeat builds for putts)
const CHIP_THRESHOLD_METERS := 15.24   # 50 feet in meters (zone for chip/pitch rollouts)
const MIN_INITIAL_SHOT_DISTANCE_METERS := 6.096 # 20 feet in meters (20.0 * 0.3048) - suspense never triggers on shots starting under 20ft
const PUTT_MIN_SUSPENSE_DISTANCE_METERS := 6.096 # 20 feet in meters (alias)
const CHIP_MIN_SUSPENSE_DISTANCE_METERS := 6.096 # 20 feet in meters (alias)
const MAX_PROJECTED_LANDING_DISTANCE_METERS := 18.288 # 20 yards in meters (20.0 * 0.9144)
const PAST_HOLE_THRESHOLD_METERS := 0.3048         # 1 foot past the hole in meters (1.0 * 0.3048)
const CYCLE_DURATION := 0.80          # ~75 BPM double-thump heartbeat cycle
const AIRBORNE_CONE_HALF_ANGLE_DEG := 5.0  # Tight 5.0 degree half-angle (10.0 deg total) in flight
const CONE_HALF_ANGLE_DEG := 15.0           # Max angle clamp for ultra-close putting
const MIN_COS_THETA := 0.996194698          # cos(5 deg)
const CUP_RADIUS_METERS := 0.054       # 4.25 in / 2 (standard golf cup)
const CONTENDER_RADIUS_METERS := 3.0   # Contender window for airborne trajectory validation
const CONTENDER_RADIUS_PUTT_METERS := 0.50 # 0.5 meters (~1.6 feet) contender window for putts (tightened from 2.5m)
const MAX_HOLEABLE_SPEED_MPS := 3.2    # Max entry speed into cup
const SHORT_ROLL_MARGIN_METERS := 0.75 # ~2.5 feet close-call margin for near misses
const MIN_CONE_DURATION_BEFORE_ACTIVATION := 0.50 # seconds (500ms debounce in cone vision before playing suspense)
const MIN_SUSPENSE_PLAY_DURATION := 1.50          # seconds (minimum play duration before suspense can turn off)

enum SuspenseState {
	IDLE,    # Before shot launched
	READY,   # Shot launched & trajectory validated to enter cup; awaiting apex & cone criteria
	ACTIVE,  # Suspense active (heartbeat, vignette, cone tracking)
	SPENT    # Shot missed, completed, overshot, or broken offline; latched out for remainder of shot
}

var suspense_state: SuspenseState = SuspenseState.IDLE
var shot_validated: bool = false
var _cone_time_tracked: float = 0.0
var _suspense_play_timer: float = 0.0
var _deactivation_pending: bool = false
var _pending_lockout: bool = true

# Predicted trajectory data
var predicted_apex: Vector3 = Vector3.ZERO
var predicted_land_pos: Vector3 = Vector3.ZERO
var predicted_land_vel: Vector3 = Vector3.ZERO
var predicted_roll_path: Array[Vector3] = []
var predicted_holed_out: bool = false

var tension_active: bool = false
var current_mode: String = ""
var current_intensity: float = 0.0
var current_closeness: float = 0.0
var pulse_timer: float = 0.0
var current_pulse: float = 0.0

var _is_scheduled: bool = false
var _scheduled_mode: String = ""
var _closest_dist_reached: float = 9999.0
var _has_entered_suspense_zone: bool = false
var _shot_suspense_locked_out: bool = false
var _tree_hit_this_shot: bool = false
var _suspense_predicted_close: bool = false
var _predicted_ending_dist: float = 0.0

# 3D Debug Vision Cone Visualizer
var _cone_mesh_instance: MeshInstance3D = null
var _cone_immediate_mesh: ImmediateMesh = null
var _cone_material: StandardMaterial3D = null
var _last_ball_pos: Vector3 = Vector3.ZERO
var _last_ball_vel: Vector3 = Vector3.ZERO
var _last_target_pos: Vector3 = Vector3.ZERO
var _last_is_putt: bool = false
var _last_is_airborne: bool = false
var _last_cone_valid: bool = false

# Touchdown transition state for smooth airborne -> rollout cone sizing
var _was_airborne_this_shot: bool = false
var _touchdown_timer: float = 0.0
const TOUCHDOWN_TRANSITION_DURATION: float = 1.35 # seconds

# Visual nodes
var canvas_layer: CanvasLayer = null
var vignette_rect: ColorRect = null
var vignette_material: ShaderMaterial = null

# Audio player
var sfx_player: AudioStreamPlayer = null
var _heartbeat_stream: AudioStream = null

# Camera tracking
var target_camera: Camera3D = null
var base_camera_fov: float = 55.0

# Scene-level caching for is_course_play_active
var _cached_scene_ref: WeakRef = null
var _cached_is_course_play: bool = false
var _cached_practice_mode: bool = false
var _cached_players_empty: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_visuals()
	_setup_audio()
	_setup_debug_cone_visualizer()
	print("[TensionManager] Ready and initialized.")


func _setup_visuals() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TensionCanvasLayer"
	canvas_layer.layer = 20 # Render above 3D world and gameplay UI, below debug/dialogs
	add_child(canvas_layer)

	vignette_rect = ColorRect.new()
	vignette_rect.name = "HeartbeatVignetteRect"
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.anchor_left = 0.0
	vignette_rect.anchor_top = 0.0
	vignette_rect.anchor_right = 1.0
	vignette_rect.anchor_bottom = 1.0
	vignette_rect.offset_left = 0.0
	vignette_rect.offset_top = 0.0
	vignette_rect.offset_right = 0.0
	vignette_rect.offset_bottom = 0.0
	vignette_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vignette_rect.grow_vertical = Control.GROW_DIRECTION_BOTH

	var shader_path = "res://Courses/Environments/shaders/heartbeat_vignette.gdshader"
	var shader = load(shader_path) as Shader
	if shader != null:
		vignette_material = ShaderMaterial.new()
		vignette_material.shader = shader
		vignette_material.set_shader_parameter("intensity", 0.0)
		vignette_material.set_shader_parameter("pulse", 0.0)
		vignette_material.set_shader_parameter("closeness", 0.0)
		vignette_rect.material = vignette_material
	else:
		push_warning("[TensionManager] Could not load heartbeat_vignette.gdshader")

	vignette_rect.visible = false
	canvas_layer.add_child(vignette_rect)

func _setup_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "HeartbeatAudioPlayer"
	sfx_player.bus = "Master"
	add_child(sfx_player)

	var ogg_path = "res://assets/audio/sfx/heartbeat.ogg"
	var wav_path = "res://assets/audio/sfx/heartbeat.wav"

	# Method 1: Load directly from file via AudioStreamOggVorbis
	if ClassDB.class_exists("AudioStreamOggVorbis") and FileAccess.file_exists(ogg_path):
		var ogg_stream = AudioStreamOggVorbis.load_from_file(ogg_path)
		if ogg_stream != null:
			ogg_stream.loop = true
			_heartbeat_stream = ogg_stream

	# Method 2: Fallback to ResourceLoader
	if _heartbeat_stream == null:
		if ResourceLoader.exists(ogg_path):
			_heartbeat_stream = load(ogg_path)
		elif ResourceLoader.exists(wav_path):
			_heartbeat_stream = load(wav_path)

	# Method 3: Procedural AudioStreamWAV fallback (guarantees punchy sound ALWAYS plays)
	if _heartbeat_stream == null:
		_heartbeat_stream = _create_procedural_heartbeat_wav()

	if _heartbeat_stream != null:
		sfx_player.stream = _heartbeat_stream
		sfx_player.finished.connect(func():
			if tension_active:
				sfx_player.play()
		)
		print("[TensionManager] Heartbeat audio initialized successfully.")

func _create_procedural_heartbeat_wav() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	var dur = 3.2
	var num_samples = int(dur * 22050)
	var stream_data = PackedByteArray()
	stream_data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / 22050.0
		var t_cycle = fmod(t, 0.8)
		var sample_val = 0.0
		
		# S1 at 0.0s (Audible thump + harmonic punch)
		if t_cycle < 0.22:
			var env = exp(-t_cycle * 16.0)
			var freq1 = 85.0 - 30.0 * (t_cycle / 0.22)
			var freq2 = 140.0 - 50.0 * (t_cycle / 0.22)
			sample_val += sin(TAU * freq1 * t_cycle) * env * 0.85
			sample_val += sin(TAU * freq2 * t_cycle) * env * 0.55
			sample_val += sin(TAU * 240.0 * t_cycle) * exp(-t_cycle * 35.0) * 0.30
		# S2 at 0.28s (Audible valve snap + body resonance)
		elif t_cycle >= 0.28 and t_cycle < 0.46:
			var dt2 = t_cycle - 0.28
			var env2 = exp(-dt2 * 20.0)
			var freq1 = 110.0 - 35.0 * (dt2 / 0.18)
			var freq2 = 180.0
			sample_val += (sin(TAU * freq1 * dt2) * env2 * 0.75 + sin(TAU * freq2 * dt2) * exp(-dt2 * 28.0) * 0.55 + sin(TAU * 310.0 * dt2) * exp(-dt2 * 40.0) * 0.28) * 0.90
			
		var saturated = tanh(sample_val * 1.5)
		var pcm16 = int(clamp(saturated, -1.0, 1.0) * 31500.0)
		stream_data.encode_s16(i * 2, pcm16)
		
	stream.data = stream_data
	return stream

func is_active() -> bool:
	return tension_active

var force_course_play_active_for_testing: bool = false

func is_course_play_active() -> bool:
	if force_course_play_active_for_testing:
		return true

	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null:
		return false

	# 1. Global Settings menu and driving range checks
	var gs = (tree.root.get_node_or_null("GlobalSettings") if tree.root != null else null)
	if gs != null:
		if gs.is_menu_screen():
			return false
		if gs.has_method("is_driving_range_scene") and gs.is_driving_range_scene():
			return false

	# 2. Active Scene checks
	var current_scene = tree.current_scene
	if current_scene == null and gs != null:
		if gs.has_method("get_active_scene"):
			current_scene = gs.get_active_scene()
		elif gs.has_method("_get_active_scene"):
			current_scene = gs._get_active_scene()
	if current_scene == null:
		return false

	# Exclude driving range by properties
	if "is_driving_range" in current_scene and bool(current_scene.get("is_driving_range")):
		return false
	if current_scene.has_meta("is_driving_range") and bool(current_scene.get_meta("is_driving_range")):
		return false

	var scene_name = str(current_scene.name).to_lower()
	var script: Script = current_scene.get_script()
	var script_path = str(script.resource_path).to_lower() if script != null else ""
	var scene_path = str(current_scene.scene_file_path).to_lower() if "scene_file_path" in current_scene else ""
	var full_id = (scene_name + " " + script_path + " " + scene_path).to_lower()

	# Exclude driving range by file/scene path (res://Courses/Range/range.tscn)
	var is_course_match = false
	if current_scene.has_node("CoursePlay") or full_id.contains("course_play") or full_id.contains("courseplaysetup") or full_id.contains("coursemanager") or full_id.contains("course_manager"):
		is_course_match = true
	var mp = tree.root.get_node_or_null("MultiplayerManager") if tree.root != null else null
	if mp != null and not mp.players.is_empty() and not mp.hole_ids.is_empty():
		is_course_match = true

	if not is_course_match:
		if full_id.contains("range/range.tscn") or scene_path.ends_with("range.tscn") or scene_name == "range":
			return false

	# Exclude menus and setup screens
	if full_id.contains("main_menu") or full_id.contains("mainmenu") \
		or full_id.contains("course_selector") or full_id.contains("courseselector") \
		or full_id.contains("course_play_setup") or full_id.contains("courseplaysetup") \
		or full_id.contains("minigames_menu") or full_id.contains("minigamesmenu") \
		or full_id.contains("players_menu") or full_id.contains("playersmenu") \
		or full_id.contains("analytics") or full_id.contains("history") \
		or full_id.contains("custom_course_creator") or full_id.contains("osm_download") \
		or full_id.contains("course_preview"):
		return false

	# Exclude training minigames that do not use the course cup
	if full_id.contains("loft_control") or full_id.contains("shape_practice"):
		return false

	# Allow course play and practice mode on course holes
	return true

# ---------------- VISION CONE CALCULATION ----------------

func get_vision_cone_half_angle(dist_to_hole: float, is_putt: bool, is_airborne: bool) -> float:
	if is_airborne:
		return deg_to_rad(AIRBORNE_CONE_HALF_ANGLE_DEG) # 5.0 degrees
	if is_putt:
		# Dynamic lateral corridor for putting:
		# Far away (e.g. 8m/26ft): corridor ~0.48m (~1.6 ft, angle ~3.4°), prevents false positives at start
		# Close up (e.g. 0.3m/1ft): corridor widens to cup lip (angle up to 15.0°)
		var corridor = clampf(0.08 + 0.05 * dist_to_hole, CUP_RADIUS_METERS * 1.5, 0.55)
		var angle = asin(clampf(corridor / maxf(dist_to_hole, 0.1), 0.01, sin(deg_to_rad(CONE_HALF_ANGLE_DEG))))
		return angle
	else:
		# On-ground chip rollout:
		var target_roll_corridor = clampf(0.18 + 0.08 * dist_to_hole, CUP_RADIUS_METERS * 2.0, 1.25)
		var base_roll_angle = asin(clampf(target_roll_corridor / maxf(dist_to_hole, 0.1), 0.01, sin(deg_to_rad(CONE_HALF_ANGLE_DEG))))

		# Smooth transition from in-flight 5° cone to rollout cone after touchdown
		if _touchdown_timer > 0.0:
			var t_norm = clampf(_touchdown_timer / TOUCHDOWN_TRANSITION_DURATION, 0.0, 1.0)
			var blend_factor = smoothstep(0.0, 1.0, t_norm)
			return lerpf(base_roll_angle, deg_to_rad(AIRBORNE_CONE_HALF_ANGLE_DEG), blend_factor)
		return base_roll_angle

func get_effective_rolling_deceleration() -> float:
	var gs = get_node_or_null("/root/GlobalSettings") if is_inside_tree() else (Engine.get_main_loop().root.get_node_or_null("GlobalSettings") if Engine.get_main_loop() != null and Engine.get_main_loop() is SceneTree else null)
	var green_speed: float = 10.0
	if gs != null and gs.has_method("get_effective_green_speed"):
		green_speed = float(gs.get_effective_green_speed())
	var speed_mult := 10.0 / maxf(green_speed, 1.0)
	var green_rolling_friction := 0.056 * speed_mult
	return green_rolling_friction * 9.81

func get_projected_reach_distance(ball_pos: Vector3, ball_vel: Vector3, is_airborne: bool, target_pos: Vector3 = Vector3.ZERO) -> float:
	var flat_vel = Vector2(ball_vel.x, ball_vel.z)
	var flat_speed = flat_vel.length()
	if flat_speed < 0.03:
		return 0.0

	var decel = get_effective_rolling_deceleration()

	if is_airborne:
		var target_y = target_pos.y if not target_pos.is_zero_approx() else ball_pos.y
		var h = maxf(0.0, ball_pos.y - target_y)
		var g = 9.81
		var vy = ball_vel.y
		var disc = vy * vy + 2.0 * g * h
		var t_land = maxf(0.0, (vy + sqrt(maxf(0.0, disc))) / g)
		var flight_dist = flat_speed * t_land
		var land_flat_speed = flat_speed * 0.52
		var rollout_dist = (land_flat_speed * land_flat_speed) / (2.0 * decel)
		return flight_dist + rollout_dist + SHORT_ROLL_MARGIN_METERS
	else:
		var rollout_dist = (flat_speed * flat_speed) / (2.0 * decel)
		return rollout_dist + SHORT_ROLL_MARGIN_METERS

# ---------------- SUSPENSE ELIGIBILITY ----------------

func is_shot_eligible_for_suspense(start_pos: Vector3, target_pos: Vector3, _is_putt: bool = false, _is_sand: bool = false) -> bool:
	if not is_course_play_active() or _shot_suspense_locked_out or _tree_hit_this_shot:
		return false
	if target_pos.is_zero_approx():
		return false
	var dist_2d = Vector2(start_pos.x, start_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))
	if dist_2d < 0.05:
		return false
	# Suspense must never trigger on any shot starting less than 20 feet (6.096m) from the hole before being hit
	return (dist_2d + 0.01) >= MIN_INITIAL_SHOT_DISTANCE_METERS

# ---------------- TRAJECTORY PREDICTION ----------------

func predict_shot_outcome(start_pos: Vector3, launch_vel: Vector3, is_putt: bool, target_pos: Vector3, is_sand: bool = false) -> Dictionary:
	if not is_course_play_active() or _shot_suspense_locked_out or _tree_hit_this_shot:
		suspense_state = SuspenseState.SPENT
		shot_validated = false
		return {"will_enter_zone": false, "shot_validated": false, "min_dist": 999.0, "ending_dist": 999.0}
	if target_pos.is_zero_approx():
		suspense_state = SuspenseState.SPENT
		shot_validated = false
		return {"will_enter_zone": false, "shot_validated": false, "min_dist": 999.0, "ending_dist": 999.0}
	if not is_shot_eligible_for_suspense(start_pos, target_pos, is_putt, is_sand):
		suspense_state = SuspenseState.SPENT
		shot_validated = false
		return {"will_enter_zone": false, "shot_validated": false, "min_dist": 999.0, "ending_dist": 999.0, "mode": "putt" if is_putt else "chip"}

	var target_2d := Vector2(target_pos.x, target_pos.z)
	var mode := "putt" if is_putt else "chip"

	# Get environmental parameters
	var gs = get_node_or_null("/root/GlobalSettings") if is_inside_tree() else (Engine.get_main_loop().root.get_node_or_null("GlobalSettings") if Engine.get_main_loop() != null and Engine.get_main_loop() is SceneTree else null)
	var green_speed: float = 10.0
	if gs != null and gs.has_method("get_effective_green_speed"):
		green_speed = float(gs.get_effective_green_speed())
	var speed_mult := 10.0 / maxf(green_speed, 1.0)
	var green_rolling_friction := 0.056 * speed_mult

	# Query green slope normal around the target hole
	var green_normal := Vector3.UP
	var tree := get_tree()
	if tree != null and tree.root != null and tree.root.get_world_3d() != null:
		var space_state = tree.root.get_world_3d().direct_space_state
		if space_state != null:
			var query = PhysicsRayQueryParameters3D.create(
				target_pos + Vector3.UP * 1.5,
				target_pos + Vector3.DOWN * 2.5
			)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit = space_state.intersect_ray(query)
			if not hit.is_empty():
				var norm: Vector3 = hit.get("normal", Vector3.UP)
				if norm.y > 0.5:
					green_normal = norm.normalized()

	# Wind vector (if enabled)
	var wind_vec := Vector3.ZERO
	if gs != null and gs.has_method("is_wind_enabled") and gs.is_wind_enabled() and gs.has_method("get_wind_vector_mps"):
		wind_vec = gs.get_wind_vector_mps()

	var sim_pos := start_pos
	var sim_vel := launch_vel
	var min_dist_2d := 9999.0
	var dt := 0.025
	var holed_out := false
	var did_land := false
	var p_apex := start_pos
	var p_land := start_pos
	var v_land := Vector3.ZERO
	var roll_path: Array[Vector3] = []

	var gravity_slope_2d = Vector2(green_normal.x, green_normal.z) * (9.81 * green_normal.y * 0.5)

	if is_putt:
		sim_vel.y = 0.0
		p_apex = start_pos
		p_land = start_pos
		v_land = sim_vel
		roll_path.append(start_pos)

		for step in range(400):
			var current_2d = Vector2(sim_pos.x, sim_pos.z)
			var d = current_2d.distance_to(target_2d)
			if d < min_dist_2d:
				min_dist_2d = d

			var flat_speed = Vector2(sim_vel.x, sim_vel.z).length()

			# Enter cup check: enters cup radius at holeable speed
			if d <= CUP_RADIUS_METERS and flat_speed <= MAX_HOLEABLE_SPEED_MPS:
				holed_out = true
				min_dist_2d = 0.0
				roll_path.append(target_pos)
				break

			if flat_speed < 0.03:
				break

			var slope_scale = clampf(flat_speed / 0.6, 0.0, 1.0)
			var slope_accel = gravity_slope_2d * slope_scale
			var friction_accel = -Vector2(sim_vel.x, sim_vel.z).normalized() * (green_rolling_friction * 9.81)

			var vel_2d = Vector2(sim_vel.x, sim_vel.z) + (slope_accel + friction_accel) * dt
			if vel_2d.dot(Vector2(sim_vel.x, sim_vel.z)) < 0.0:
				break
			sim_vel.x = vel_2d.x
			sim_vel.z = vel_2d.y
			sim_pos += sim_vel * dt
			roll_path.append(sim_pos)
	else:
		var in_flight := true
		var total_dist_2d := Vector2(start_pos.x, start_pos.z).distance_to(target_2d)

		for step in range(400):
			var current_2d = Vector2(sim_pos.x, sim_pos.z)
			var d = current_2d.distance_to(target_2d)

			if in_flight:
				if sim_pos.y > p_apex.y:
					p_apex = sim_pos

				var dist_from_start = Vector2(sim_pos.x - start_pos.x, sim_pos.z - start_pos.z).length()
				var t_path = clampf(dist_from_start / maxf(total_dist_2d, 0.01), 0.0, 1.0)
				var local_ground_y = lerpf(start_pos.y, target_pos.y, t_path)

				var height_above_ground = maxf(0.0, sim_pos.y - local_ground_y)
				var wind_factor = smoothstep(0.0, 25.0, height_above_ground)
				var effective_wind = wind_vec * wind_factor
				var v_rel = sim_vel - effective_wind
				var v_rel_len = v_rel.length()

				# Aerodynamic drag deceleration
				var drag_force = -0.5 * 0.28 * 1.204 * 0.0014303 * v_rel_len * v_rel
				var accel = (drag_force / 0.04593) + Vector3(0.0, -9.81, 0.0)
				sim_vel += accel * dt
				sim_pos += sim_vel * dt

				if sim_vel.y <= 0.0 and sim_pos.y <= local_ground_y:
					sim_pos.y = local_ground_y
					in_flight = false
					did_land = true
					p_land = sim_pos
					# Damped turf bounce
					sim_vel.y = absf(sim_vel.y) * 0.20
					sim_vel.x *= 0.52
					sim_vel.z *= 0.52
					v_land = sim_vel
					roll_path.append(p_land)
			else:
				var flat_speed = Vector2(sim_vel.x, sim_vel.z).length()
				if d < min_dist_2d:
					min_dist_2d = d

				if d <= CUP_RADIUS_METERS and flat_speed <= MAX_HOLEABLE_SPEED_MPS:
					holed_out = true
					min_dist_2d = 0.0
					roll_path.append(target_pos)
					break

				if flat_speed < 0.03:
					break

				var slope_scale = clampf(flat_speed / 0.6, 0.0, 1.0)
				var slope_accel = gravity_slope_2d * slope_scale
				var friction_accel = -Vector2(sim_vel.x, sim_vel.z).normalized() * (green_rolling_friction * 9.81)

				var vel_2d = Vector2(sim_vel.x, sim_vel.z) + (slope_accel + friction_accel) * dt
				if vel_2d.dot(Vector2(sim_vel.x, sim_vel.z)) < 0.0:
					break
				sim_vel.x = vel_2d.x
				sim_vel.z = vel_2d.y
				sim_vel.y = 0.0
				sim_pos += sim_vel * dt
				roll_path.append(sim_pos)

	var ending_dist_2d = 0.0 if holed_out else Vector2(sim_pos.x, sim_pos.z).distance_to(target_2d)

	# --- TRAJECTORY VALIDATION (READY state evaluation) ---
	var is_contender := false
	var is_confirmed_miss := false
	if is_putt:
		var start_to_hole = (target_2d - Vector2(start_pos.x, start_pos.z)).normalized() if Vector2(start_pos.x, start_pos.z).distance_to(target_2d) > 0.001 else Vector2.ZERO
		var putt_launch_dir = Vector2(launch_vel.x, launch_vel.z).normalized()
		var forward_dot = putt_launch_dir.dot(start_to_hole)
		# Tighten putt validation: must be directed towards hole and stop within contender window
		if forward_dot > 0.85:
			is_contender = holed_out or (min_dist_2d <= CONTENDER_RADIUS_PUTT_METERS)
		if forward_dot <= 0.0 or (forward_dot < 0.75 and min_dist_2d > CONTENDER_RADIUS_PUTT_METERS) or (not holed_out and min_dist_2d > CONTENDER_RADIUS_PUTT_METERS):
			is_confirmed_miss = true
	else:
		# Airborne / chip shot:
		var start_to_hole = (target_2d - Vector2(start_pos.x, start_pos.z)).normalized() if Vector2(start_pos.x, start_pos.z).distance_to(target_2d) > 0.001 else Vector2.ZERO
		var chip_launch_dir = Vector2(launch_vel.x, launch_vel.z).normalized()
		var forward_dot = chip_launch_dir.dot(start_to_hole)
		var land_dist_to_hole = Vector2(p_land.x, p_land.z).distance_to(target_2d)

		if forward_dot < 0.2:
			is_confirmed_miss = true # Hit backwards or extreme shank
		else:
			var is_on_track = forward_dot >= 0.70
			# Power check: ball must have the power to land within reasonable distance of the hole (<= 20 yards)
			var has_landing_power = holed_out or (did_land and land_dist_to_hole <= MAX_PROJECTED_LANDING_DISTANCE_METERS)
			var finishes_near_hole = holed_out or (min_dist_2d <= CONTENDER_RADIUS_METERS) or (ending_dist_2d <= CHIP_THRESHOLD_METERS)

			if is_on_track and has_landing_power and finishes_near_hole:
				is_contender = true
			elif not has_landing_power and not holed_out and min_dist_2d > CHIP_THRESHOLD_METERS:
				is_confirmed_miss = true

	if is_confirmed_miss:
		suspense_state = SuspenseState.SPENT
		_shot_suspense_locked_out = true
		shot_validated = false
		predicted_holed_out = false
		print("[TensionManager] Trajectory Validation: MISS confirmed (hit offline or backwards). Transitioned directly to SPENT.")
		return {
			"will_enter_zone": false,
			"shot_validated": false,
			"ending_dist": ending_dist_2d,
			"min_dist": min_dist_2d,
			"mode": mode
		}
	elif not is_contender:
		# Not a clear pre-launch contender from toy physics, but keep in IDLE so live cone checks evaluate actual C# physics
		suspense_state = SuspenseState.IDLE
		shot_validated = false
		return {
			"will_enter_zone": false,
			"shot_validated": false,
			"ending_dist": ending_dist_2d,
			"min_dist": min_dist_2d,
			"mode": mode
		}

	# Validation SUCCESS: Shot is on target (enters cup or close contender zone)!
	shot_validated = true
	suspense_state = SuspenseState.READY
	predicted_apex = p_apex
	predicted_land_pos = p_land
	predicted_land_vel = v_land
	predicted_roll_path = roll_path
	predicted_holed_out = holed_out
	_suspense_predicted_close = true
	_predicted_ending_dist = ending_dist_2d

	var time_to_apex: float = 0.0
	var delay_to_apex: float = 0.25
	if not is_putt and launch_vel.y > 0.5:
		time_to_apex = launch_vel.y / 9.81
		delay_to_apex = time_to_apex + 0.15

	print("[TensionManager] Trajectory Validation: SUCCESS! Contender path (closest: %.2fm). State -> READY. P_apex: %s, P_land: %s" % [min_dist_2d, p_apex, p_land])
	return {
		"will_enter_zone": true,
		"shot_validated": true,
		"ending_dist": ending_dist_2d,
		"min_dist": min_dist_2d,
		"mode": mode,
		"time_to_apex": time_to_apex,
		"delay_to_apex": delay_to_apex,
		"p_apex": p_apex,
		"p_land": p_land
	}

func schedule_apex_tension(mode: String, _delay_seconds: float = 0.25, ending_dist: float = 0.0) -> void:
	if not is_course_play_active() or _shot_suspense_locked_out or _tree_hit_this_shot:
		return
	cancel_scheduled_tension()
	_scheduled_mode = mode
	_predicted_ending_dist = ending_dist
	_closest_dist_reached = 9999.0
	_has_entered_suspense_zone = false
	# Note: Activation is evaluated dynamically by altitude and cone angle in check_ball_proximity.

func schedule_early_tension(mode: String, delay_seconds: float = 0.02, ending_dist: float = 0.0) -> void:
	schedule_apex_tension(mode, delay_seconds, ending_dist)

func cancel_scheduled_tension() -> void:
	_is_scheduled = false

func on_tree_hit() -> void:
	_tree_hit_this_shot = true
	_suspense_predicted_close = false
	shot_validated = false
	suspense_state = SuspenseState.SPENT
	_shot_suspense_locked_out = true
	_cone_time_tracked = 0.0
	_deactivation_pending = false
	cancel_scheduled_tension()
	stop_tension(true)

func reset_for_new_shot() -> void:
	cancel_scheduled_tension()
	suspense_state = SuspenseState.IDLE
	shot_validated = false
	predicted_apex = Vector3.ZERO
	predicted_land_pos = Vector3.ZERO
	predicted_land_vel = Vector3.ZERO
	predicted_roll_path.clear()
	predicted_holed_out = false
	_shot_suspense_locked_out = false
	_tree_hit_this_shot = false
	_suspense_predicted_close = false
	_predicted_ending_dist = 0.0
	_closest_dist_reached = 9999.0
	_has_entered_suspense_zone = false
	current_closeness = 0.0
	_was_airborne_this_shot = false
	_touchdown_timer = 0.0
	_cone_time_tracked = 0.0
	_suspense_play_timer = 0.0
	_deactivation_pending = false
	_pending_lockout = true
	if tension_active:
		tension_active = false
		emit_signal("tension_stopped")

# ---------------- LIVE PROXIMITY & CONE CHECK ----------------

func check_ball_proximity(
	ball_pos: Vector3,
	target_pos: Vector3,
	is_putt: bool,
	shot_start_pos: Vector3 = Vector3(INF, INF, INF),
	_is_sand: bool = false,
	is_airborne: bool = false,
	ball_vel: Vector3 = Vector3.ZERO,
	hit_tree: bool = false,
	delta: float = -1.0
) -> bool:
	var dt: float = delta
	if dt <= 0.0:
		dt = get_physics_process_delta_time()
		if dt <= 0.0:
			dt = 1.0 / 60.0

	# Never trigger or continue after hitting a tree
	if _tree_hit_this_shot or hit_tree:
		_tree_hit_this_shot = true
		suspense_state = SuspenseState.SPENT
		_shot_suspense_locked_out = true
		_last_cone_valid = false
		_cone_time_tracked = 0.0
		cancel_scheduled_tension()
		if tension_active:
			stop_tension(true, true)
		return false

	# Cache last observed parameters for 3D visualizer
	_last_ball_pos = ball_pos
	_last_ball_vel = ball_vel
	_last_target_pos = target_pos
	_last_is_putt = is_putt
	_last_is_airborne = is_airborne
	if is_airborne:
		_was_airborne_this_shot = true
		_touchdown_timer = TOUCHDOWN_TRANSITION_DURATION

	# Strict SPENT Latch: Suspense must never turn on more than once per shot
	if suspense_state == SuspenseState.SPENT or _shot_suspense_locked_out:
		_last_cone_valid = false
		_cone_time_tracked = 0.0
		return false

	if not is_course_play_active() or target_pos.is_zero_approx():
		_last_cone_valid = false
		_cone_time_tracked = 0.0
		return false

	var ball_pos_2d = Vector2(ball_pos.x, ball_pos.z)
	var hole_pos_2d = Vector2(target_pos.x, target_pos.z)
	var dist_2d = ball_pos_2d.distance_to(hole_pos_2d)
	var threshold = PUTT_THRESHOLD_METERS if is_putt else CHIP_THRESHOLD_METERS

	# ========================================================
	# STATE: IDLE / READY -> ACTIVE (Predictive Activation)
	# ========================================================
	if suspense_state == SuspenseState.READY or suspense_state == SuspenseState.IDLE:
		# Verify initial distance eligibility (never trigger for shots starting < 20 feet from hole)
		var start_p = shot_start_pos if shot_start_pos.x != INF else ball_pos
		if not is_shot_eligible_for_suspense(start_p, target_pos, is_putt, _is_sand):
			suspense_state = SuspenseState.SPENT
			_shot_suspense_locked_out = true
			_last_cone_valid = false
			_cone_time_tracked = 0.0
			return false

		# In READY state, trajectory validation must have passed
		if suspense_state == SuspenseState.READY and not shot_validated:
			suspense_state = SuspenseState.SPENT
			_shot_suspense_locked_out = true
			_last_cone_valid = false
			_cone_time_tracked = 0.0
			return false

		# Airborne power check: ensure predicted landing was within reasonable distance of the hole
		if is_airborne and predicted_land_pos != Vector3.ZERO:
			var pred_land_dist = Vector2(predicted_land_pos.x, predicted_land_pos.z).distance_to(hole_pos_2d)
			if pred_land_dist > MAX_PROJECTED_LANDING_DISTANCE_METERS and not predicted_holed_out and _predicted_ending_dist > CONTENDER_RADIUS_METERS:
				suspense_state = SuspenseState.SPENT
				_shot_suspense_locked_out = true
				_last_cone_valid = false
				_cone_time_tracked = 0.0
				return false

		# 2. Altitude Trigger: Ball must have passed predicted apex (Ball_Current_Altitude < P_apex.y and v_ball.y < 0)
		if is_airborne:
			if ball_vel.y >= 0.0:
				_last_cone_valid = false
				_cone_time_tracked = 0.0
				return false # Ascending
			if predicted_apex != Vector3.ZERO and ball_pos.y >= predicted_apex.y:
				_last_cone_valid = false
				_cone_time_tracked = 0.0
				return false # Still at or above apex height

		# 3. Angle Check (Critical): Cone projected forward along path of travel must encompass hole
		var cone_valid := false
		var flat_vel = Vector2(ball_vel.x, ball_vel.z)
		var flat_speed = flat_vel.length()

		if flat_speed >= 0.05:
			var cur_to_hole = (hole_pos_2d - ball_pos_2d).normalized() if dist_2d > 0.001 else Vector2.ZERO
			var travel_dir_2d = flat_vel / flat_speed
			var cos_theta_cur = travel_dir_2d.dot(cur_to_hole)
			var half_angle = get_vision_cone_half_angle(dist_2d, is_putt, is_airborne)
			var min_cos = cos(half_angle)

			# Distance Reach Check: Ball must have sufficient speed to reach the hole / close proximity
			var projected_reach = get_projected_reach_distance(ball_pos, ball_vel, is_airborne, target_pos)
			var is_reachable = (projected_reach >= dist_2d)

			if is_airborne:
				var h = maxf(0.0, ball_pos.y - target_pos.y)
				var g = 9.81
				var vy = ball_vel.y
				var disc = vy * vy + 2.0 * g * h
				var t_land = maxf(0.0, (vy + sqrt(maxf(0.0, disc))) / g)
				var dynamic_land_2d = ball_pos_2d + flat_vel * t_land
				var dist_land = dynamic_land_2d.distance_to(hole_pos_2d)

				# Airborne shot triggers when descending, travel direction within tight cone,
				# speed reaches target, and projected landing within realistic proximity window (<= 20 yards)
				var max_land_proximity = clampf(dist_2d * 0.45 + 1.5, 3.0, 8.0)
				if cos_theta_cur >= min_cos and is_reachable and dist_land <= MAX_PROJECTED_LANDING_DISTANCE_METERS and (dist_land <= max_land_proximity or dist_land <= CUP_RADIUS_METERS):
					cone_valid = true
			else:
				# Putting / on-ground rollout:
				# Inside threshold or READY, travel direction inside tightened cone, and speed reaches hole
				if (dist_2d <= threshold or suspense_state == SuspenseState.READY) and is_reachable:
					cone_valid = (cos_theta_cur >= min_cos)

		_last_cone_valid = cone_valid

		if cone_valid:
			_cone_time_tracked += dt
			if _cone_time_tracked >= MIN_CONE_DURATION_BEFORE_ACTIVATION:
				suspense_state = SuspenseState.ACTIVE
				_closest_dist_reached = dist_2d
				_suspense_play_timer = 0.0
				_deactivation_pending = false
				var closeness = clampf(1.0 - (dist_2d / maxf(threshold, 0.001)), 0.35, 1.0)
				start_tension("putt" if is_putt else "chip", closeness)
				print("[TensionManager] READY -> ACTIVE! Vision cone encompass validated for >= 500ms (accum: %.3fs). Mode: %s, Closeness: %.2f" % [
					_cone_time_tracked, "putt" if is_putt else "chip", closeness
				])
				return true
			else:
				return false
		else:
			_cone_time_tracked = 0.0
			return false

	# ========================================================
	# STATE: ACTIVE (Ongoing Angle Loss & Deactivation Checks)
	# ========================================================
	if suspense_state == SuspenseState.ACTIVE:
		if _deactivation_pending:
			_last_cone_valid = false
			return false

		# 1. Rest / Sunk Check:
		var speed = ball_vel.length()
		if not is_airborne and speed < 0.05:
			print("[TensionManager] ACTIVE -> SPENT: Ball stopped at rest.")
			_last_cone_valid = false
			stop_tension(true)
			return false

		if dist_2d <= CUP_RADIUS_METERS:
			print("[TensionManager] ACTIVE -> SPENT: Ball reached/sunk in cup!")
			_last_cone_valid = false
			stop_tension(true)
			return false

		var cur_to_hole = (hole_pos_2d - ball_pos_2d).normalized() if dist_2d > 0.001 else Vector2.ZERO
		var flat_vel = Vector2(ball_vel.x, ball_vel.z)
		var flat_speed = flat_vel.length()
		var travel_dir_2d = flat_vel / flat_speed if flat_speed > 0.05 else Vector2.ZERO
		var vel_dot_hole = travel_dir_2d.dot(cur_to_hole) if travel_dir_2d != Vector2.ZERO else 0.0

		# 2. Coming up short check: Ball speed has dropped such that it will clearly end short of the hole
		var projected_reach = get_projected_reach_distance(ball_pos, ball_vel, is_airborne, target_pos)
		if not is_airborne and dist_2d > projected_reach:
			print("[TensionManager] ACTIVE -> SPENT: Ball clearly coming up short! Reach: %.2fm < Dist: %.2fm" % [projected_reach, dist_2d])
			_last_cone_valid = false
			stop_tension(true)
			return false

		# 3. Overshoot Check: Ball rolls past the hole
		if not is_airborne and dist_2d > (_closest_dist_reached + 0.05) and vel_dot_hole <= 0.0:
			print("[TensionManager] ACTIVE -> SPENT: Overshoot detected (moving away from hole). Dist: %.2fm" % dist_2d)
			_last_cone_valid = false
			stop_tension(true)
			return false

		var start_pos_2d = Vector2(shot_start_pos.x, shot_start_pos.z) if shot_start_pos.x != INF else Vector2.ZERO
		if shot_start_pos.x != INF:
			var shot_vec = hole_pos_2d - start_pos_2d
			if shot_vec.length_squared() > 0.01:
				var shot_dir = shot_vec.normalized()
				var hole_to_ball = ball_pos_2d - hole_pos_2d
				var along_shot = hole_to_ball.dot(shot_dir)
				if along_shot > PAST_HOLE_THRESHOLD_METERS:
					print("[TensionManager] ACTIVE -> SPENT: Ball physically > 1ft past hole.")
					_last_cone_valid = false
					stop_tension(true)
					return false

		# 4. Hole Exits Cone (Angle Loss Check):
		var half_angle = get_vision_cone_half_angle(dist_2d, is_putt, is_airborne)
		var min_cos = cos(half_angle)

		if is_airborne:
			var cos_theta_cur = vel_dot_hole
			if cos_theta_cur < min_cos:
				print("[TensionManager] ACTIVE -> SPENT: Airborne hole exited cone! cos_theta: %.3f < min_cos: %.3f" % [cos_theta_cur, min_cos])
				_last_cone_valid = false
				stop_tension(true)
				return false
		else:
			if vel_dot_hole < min_cos:
				print("[TensionManager] ACTIVE -> SPENT: Hole exited cone! cos_theta: %.3f < min_cos: %.3f (Broke offline)." % [vel_dot_hole, min_cos])
				_last_cone_valid = false
				stop_tension(true)
				return false

		_last_cone_valid = true

		# Track closest distance and update heartbeat closeness
		_closest_dist_reached = minf(_closest_dist_reached, dist_2d)
		var closeness = clampf(1.0 - (dist_2d / maxf(threshold, 0.001)), 0.35, 1.0)
		current_closeness = maxf(current_closeness, closeness)
		if vignette_material != null:
			vignette_material.set_shader_parameter("closeness", closeness)
		return true

	_last_cone_valid = false
	return false

# ----------------- ACTIVATION / DEACTIVATION -----------------

func start_tension(mode: String = "putt", initial_closeness: float = 0.40) -> void:
	if _shot_suspense_locked_out or _tree_hit_this_shot or suspense_state == SuspenseState.SPENT:
		return
	if not is_course_play_active():
		return
	cancel_scheduled_tension()
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null and not gs.range_settings.tension_effects_enabled.value:
		return
	current_mode = mode
	current_closeness = initial_closeness
	if not tension_active:
		tension_active = true
		_suspense_play_timer = 0.0
		_deactivation_pending = false
		pulse_timer = 0.0
		current_intensity = 1.0
		if sfx_player != null and _heartbeat_stream != null:
			sfx_player.volume_db = 4.0 # Loud, punchy, clearly audible baseline
			sfx_player.pitch_scale = 1.0
			sfx_player.play()
		emit_signal("tension_started", mode)

func stop_tension(lockout: bool = true, force: bool = false) -> void:
	if not force and tension_active and _suspense_play_timer < MIN_SUSPENSE_PLAY_DURATION:
		_deactivation_pending = true
		_pending_lockout = lockout
		print("[TensionManager] Deactivation requested, holding active for minimum %.2fs play duration (played: %.2fs)" % [
			MIN_SUSPENSE_PLAY_DURATION, _suspense_play_timer
		])
		return

	_deactivation_pending = false
	cancel_scheduled_tension()
	if lockout:
		_shot_suspense_locked_out = true
		suspense_state = SuspenseState.SPENT
	_closest_dist_reached = 9999.0
	_has_entered_suspense_zone = false
	current_closeness = 0.0
	if tension_active:
		tension_active = false
		emit_signal("tension_stopped")

func advance_simulation(dt: float) -> void:
	if tension_active:
		_suspense_play_timer += dt
		if _deactivation_pending and _suspense_play_timer >= MIN_SUSPENSE_PLAY_DURATION:
			print("[TensionManager] Minimum play duration (%.2fs >= %.2fs) reached; executing pending deactivation." % [
				_suspense_play_timer, MIN_SUSPENSE_PLAY_DURATION
			])
			stop_tension(_pending_lockout, true)

func register_camera(cam: Camera3D, base_fov: float = 55.0) -> void:
	target_camera = cam
	base_camera_fov = base_fov

# ---------------- PROCESS & VISUAL/AUDIO PULSE ----------------

func _process(delta: float) -> void:
	if _touchdown_timer > 0.0 and not _last_is_airborne:
		_touchdown_timer = maxf(0.0, _touchdown_timer - delta)

	advance_simulation(delta)

	if tension_active:
		pulse_timer += delta
		var t_in_cycle = fmod(pulse_timer, CYCLE_DURATION)

		if t_in_cycle < 0.22:
			var p1 = sin(PI * (t_in_cycle / 0.22))
			current_pulse = p1 * p1 * 1.0
		elif t_in_cycle >= 0.28 and t_in_cycle < 0.44:
			var p2 = sin(PI * ((t_in_cycle - 0.28) / 0.16))
			current_pulse = p2 * p2 * 0.75
		else:
			current_pulse = 0.0

		current_intensity = lerp(current_intensity, 1.45, delta * 4.0)

		# Scale heartbeat audio volume louder and louder as ball gets closer (+4 dB up to +11 dB!)
		if sfx_player != null:
			if not sfx_player.playing and _heartbeat_stream != null:
				sfx_player.play()
			var target_vol = lerpf(4.0, 11.0, current_closeness)
			sfx_player.volume_db = lerp(sfx_player.volume_db, target_vol, delta * 5.0)
			sfx_player.pitch_scale = lerp(sfx_player.pitch_scale, lerpf(1.0, 1.08, current_closeness), delta * 4.0)
	else:
		current_pulse = lerp(current_pulse, 0.0, delta * 6.0)
		current_intensity = lerp(current_intensity, 0.0, delta * 5.0)

		if sfx_player != null and sfx_player.playing:
			sfx_player.volume_db = lerp(sfx_player.volume_db, -40.0, delta * 6.0)
			if current_intensity < 0.01 and sfx_player.volume_db <= -35.0:
				sfx_player.stop()

	# Update 4-corner tunnel vision vignette
	if vignette_rect != null:
		var should_show_vignette = tension_active or current_intensity > 0.001
		if vignette_rect.visible != should_show_vignette:
			vignette_rect.visible = should_show_vignette
		if should_show_vignette and vignette_material != null:
			vignette_material.set_shader_parameter("intensity", current_intensity)
			vignette_material.set_shader_parameter("pulse", current_pulse)
			vignette_material.set_shader_parameter("closeness", current_closeness)

	var cam: Camera3D = target_camera
	if cam == null or not is_instance_valid(cam):
		var vp = get_viewport()
		if vp != null:
			var vp_cam = vp.get_camera_3d()
			if vp_cam != null and vp_cam.name != "MinimapCamera" and vp_cam.name != "AerialCamera":
				cam = vp_cam

	if cam != null and is_instance_valid(cam):
		var target_fov = base_camera_fov
		if current_intensity > 0.001:
			var fov_offset = -5.0 * (current_intensity / 1.45) * (0.85 + current_pulse * 0.25)
			target_fov = base_camera_fov + fov_offset
		cam.fov = lerp(cam.fov, target_fov, delta * 6.0)

	_update_debug_cone_visualizer()

func get_tension_intensity() -> float:
	return current_intensity

func get_tension_pulse() -> float:
	return current_pulse


# ---------------- 3D DEBUG VISION CONE VISUALIZER ----------------

func _setup_debug_cone_visualizer() -> void:
	if _cone_immediate_mesh != null and _cone_mesh_instance != null and is_instance_valid(_cone_mesh_instance):
		return
	_cone_immediate_mesh = ImmediateMesh.new()
	_cone_mesh_instance = MeshInstance3D.new()
	_cone_mesh_instance.name = "SuspenseConeVisualizer"
	_cone_mesh_instance.mesh = _cone_immediate_mesh
	_cone_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_cone_material = StandardMaterial3D.new()
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_material.vertex_color_use_as_albedo = true
	_cone_mesh_instance.material_override = _cone_material


func _update_debug_cone_visualizer() -> void:
	var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	var gs = (tree.root.get_node_or_null("GlobalSettings") if (tree != null and tree.root != null) else null)
	if gs == null and is_inside_tree():
		gs = get_node_or_null("/root/GlobalSettings")

	var enabled = false
	if gs != null and gs.range_settings != null and "debug_show_suspense_cone" in gs.range_settings and gs.range_settings.debug_show_suspense_cone != null:
		enabled = bool(gs.range_settings.debug_show_suspense_cone.value)

	if not enabled:
		if _cone_immediate_mesh != null and _cone_immediate_mesh.get_surface_count() > 0:
			_cone_immediate_mesh.clear_surfaces()
		if _cone_mesh_instance != null and is_instance_valid(_cone_mesh_instance):
			_cone_mesh_instance.visible = false
		return

	if tree == null:
		return

	if _cone_mesh_instance == null or not is_instance_valid(_cone_mesh_instance):
		_setup_debug_cone_visualizer()

	var current_scene = tree.current_scene
	if current_scene == null and gs != null and gs.has_method("get_active_scene"):
		current_scene = gs.get_active_scene()
	if current_scene == null and tree.root != null:
		current_scene = tree.root

	if current_scene != null and is_instance_valid(_cone_mesh_instance) and _cone_mesh_instance.get_parent() != current_scene:
		if _cone_mesh_instance.get_parent() != null and is_instance_valid(_cone_mesh_instance.get_parent()):
			_cone_mesh_instance.get_parent().remove_child(_cone_mesh_instance)
		current_scene.add_child(_cone_mesh_instance)

	if _cone_mesh_instance != null and is_instance_valid(_cone_mesh_instance):
		_cone_mesh_instance.visible = true

	# Find active ball in tree
	var ball: Node3D = null
	if tree.has_group("golf_ball"):
		ball = tree.get_first_node_in_group("golf_ball") as Node3D
	if ball == null and current_scene.has_node("Player"):
		var p = current_scene.get_node("Player")
		if "ball" in p and p.ball != null:
			ball = p.ball
	if ball == null:
		ball = current_scene.find_child("ball", true, false) as Node3D

	var ball_pos = _last_ball_pos
	var ball_vel = _last_ball_vel
	var target_pos = _last_target_pos
	var is_putt = _last_is_putt
	var is_airborne = _last_is_airborne

	if ball != null and is_instance_valid(ball):
		ball_pos = ball.global_position
		if "velocity" in ball:
			ball_vel = ball.velocity
		if "is_putt" in ball:
			is_putt = bool(ball.is_putt)
		if "state" in ball:
			is_airborne = (ball.state == PhysicsEnums.BallState.FLIGHT)
		if target_pos.is_zero_approx() and ball.has_method("_get_active_hole_position"):
			target_pos = ball._get_active_hole_position(ball_pos)

	if target_pos.is_zero_approx() and "current_hole_location" in current_scene:
		target_pos = current_scene.current_hole_location

	if is_airborne:
		_was_airborne_this_shot = true
		_touchdown_timer = TOUCHDOWN_TRANSITION_DURATION

	if ball_pos.is_zero_approx() and target_pos.is_zero_approx() and ball == null:
		if _cone_immediate_mesh != null and _cone_immediate_mesh.get_surface_count() > 0:
			_cone_immediate_mesh.clear_surfaces()
		return

	var dist_to_hole = Vector2(ball_pos.x, ball_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))
	var half_angle = get_vision_cone_half_angle(dist_to_hole, is_putt, is_airborne)

	# Forward direction of cone (faces 3D trajectory in air, ground travel direction when rolling):
	var forward := Vector3.ZERO
	if ball_vel.length() >= 0.05:
		if is_airborne:
			forward = ball_vel.normalized()
		else:
			var flat_vel = Vector3(ball_vel.x, 0.0, ball_vel.z)
			forward = flat_vel.normalized() if flat_vel.length() >= 0.01 else ball_vel.normalized()
	elif not target_pos.is_zero_approx():
		forward = Vector3(target_pos.x - ball_pos.x, 0.0, target_pos.z - ball_pos.z).normalized()
	else:
		forward = -Vector3.FORWARD

	var projected_reach = get_projected_reach_distance(ball_pos, ball_vel, is_airborne, target_pos)

	# Dynamic cone length based on ball speed / projected reach:
	var cone_length: float
	if ball_vel.length() >= 0.05:
		cone_length = clampf(projected_reach, 0.6, 35.0)
	elif not target_pos.is_zero_approx():
		cone_length = clampf(dist_to_hole if dist_to_hole > 1.0 else 5.0, 2.0, 8.0)
	else:
		cone_length = 5.0

	var is_in_cone := _last_cone_valid
	if suspense_state != SuspenseState.SPENT and not target_pos.is_zero_approx():
		var to_hole_2d = Vector2(target_pos.x - ball_pos.x, target_pos.z - ball_pos.z).normalized()
		var fwd_2d = Vector2(forward.x, forward.z).normalized()
		if fwd_2d.length_squared() > 0.01:
			var dot = fwd_2d.dot(to_hole_2d)
			var in_angle = (dot >= cos(half_angle))
			var in_reach = (projected_reach >= dist_to_hole) or ball_vel.length() < 0.05
			var in_geom = in_angle and in_reach
			is_in_cone = _last_cone_valid or in_geom

	_draw_3d_vision_cone(ball_pos, forward, target_pos, half_angle, cone_length, is_in_cone)


func _draw_3d_vision_cone(origin: Vector3, forward: Vector3, target_pos: Vector3, half_angle: float, cone_len: float, is_in_cone: bool) -> void:
	if _cone_immediate_mesh == null:
		return
	_cone_immediate_mesh.clear_surfaces()

	var base_radius = cone_len * tan(half_angle)

	var up = Vector3.UP
	if absf(forward.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var right = forward.cross(up).normalized()
	var actual_up = right.cross(forward).normalized()
	var base_center = origin + forward * cone_len

	var segments := 24
	var circle_pts: Array[Vector3] = []
	for i in range(segments):
		var theta = (float(i) / float(segments)) * TAU
		var pt = base_center + right * (cos(theta) * base_radius) + actual_up * (sin(theta) * base_radius)
		circle_pts.append(pt)

	# Determine colors based on status
	var line_color: Color
	var fill_color: Color
	if tension_active:
		line_color = Color(0.2, 1.0, 0.4, 0.95) # Pulsing active green
		fill_color = Color(0.1, 0.9, 0.3, 0.22)
	elif is_in_cone:
		line_color = Color(0.1, 0.85, 1.0, 0.90) # On-target cyan
		fill_color = Color(0.05, 0.75, 0.95, 0.16)
	else:
		line_color = Color(1.0, 0.25, 0.15, 0.85) # Offline / outside red
		fill_color = Color(0.95, 0.2, 0.1, 0.12)

	# 1. Translucent cone surface
	_cone_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var next_i = (i + 1) % segments
		_cone_immediate_mesh.surface_set_color(fill_color)
		_cone_immediate_mesh.surface_add_vertex(origin)
		_cone_immediate_mesh.surface_set_color(fill_color)
		_cone_immediate_mesh.surface_add_vertex(circle_pts[i])
		_cone_immediate_mesh.surface_set_color(fill_color)
		_cone_immediate_mesh.surface_add_vertex(circle_pts[next_i])
	_cone_immediate_mesh.surface_end()

	# 2. Wireframe outline lines
	_cone_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Circle perimeter
	for i in range(segments):
		var next_i = (i + 1) % segments
		_cone_immediate_mesh.surface_set_color(line_color)
		_cone_immediate_mesh.surface_add_vertex(circle_pts[i])
		_cone_immediate_mesh.surface_set_color(line_color)
		_cone_immediate_mesh.surface_add_vertex(circle_pts[next_i])

	# 8 boundary rays from apex to perimeter
	for k in range(8):
		var idx = k * (segments / 8)
		_cone_immediate_mesh.surface_set_color(line_color)
		_cone_immediate_mesh.surface_add_vertex(origin)
		_cone_immediate_mesh.surface_set_color(line_color)
		_cone_immediate_mesh.surface_add_vertex(circle_pts[idx])

	# Center axis ray
	_cone_immediate_mesh.surface_set_color(line_color)
	_cone_immediate_mesh.surface_add_vertex(origin)
	_cone_immediate_mesh.surface_set_color(line_color)
	_cone_immediate_mesh.surface_add_vertex(base_center)

	# Line connecting ball to hole (if target exists)
	if not target_pos.is_zero_approx():
		var target_color = Color(1.0, 0.9, 0.2, 0.75) if is_in_cone else Color(1.0, 0.4, 0.4, 0.5)
		_cone_immediate_mesh.surface_set_color(target_color)
		_cone_immediate_mesh.surface_add_vertex(origin)
		_cone_immediate_mesh.surface_set_color(target_color)
		_cone_immediate_mesh.surface_add_vertex(target_pos)

	_cone_immediate_mesh.surface_end()
