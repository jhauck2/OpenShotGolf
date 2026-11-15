extends Node3D

const RainPhysics = preload("res://Utils/rain_physics.gd")

var track_points : bool = false
# TODO: move trail stuff into trail script
var trail_timer : float = 0.0
var trail_resolution : float = 0.033
var apex := 0.0
var carry := 0.0
var side_distance := 0.0
var shot_data: Dictionary = {}
var _last_starting_pos : Vector3 = Vector3.ZERO
var _last_aim_target_pos : Vector3 = Vector3.ZERO
var _last_aim_yaw_offset_deg : float = 0.0
var current_shot_reduction : float = 0.0
var last_shot_reduction : float = 0.0
var current_lie_type : String = "fairway"

var max_tracers : int = 10
var min_tracers : int = 0
var tracers : Array = []
var current_tracer : MeshInstance3D = null
var BallTrailScript = preload("res://Player/ball_trail.gd")
const GolfBallClass = preload("res://Player/ball.gd")
var current_profile_name : String = "Player 1"
var profile_tracers : Dictionary = {}

var ball : CharacterBody3D = null
var camera_target : Node3D = null

# Tree occlusion variables
var _cached_trees: Array[Node3D] = []
var _has_scanned_trees: bool = false
var _trees_restored_for_flight: bool = false
var _tree_occlusion_timer: float = 0.0
var _last_camera_pos: Vector3 = Vector3.INF
var _last_ball_pos: Vector3 = Vector3.INF
var _cached_selected_club: String = ""

signal good_data
signal bad_data
signal rest(data: Dictionary)
signal manual_hit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create new golf ball
	ball = GolfBallClass.new()
	ball.name = "GolfBall"
	add_child(ball)
	ball.rest.connect(_on_ball_rest)
	
	camera_target = Node3D.new()
	camera_target.name = "CameraTarget"
	add_child(camera_target)
	camera_target.global_position = ball.global_position
	
	trail_resolution = 0.10
	
	# Set initial value and connect to setting changes
	max_tracers = GlobalSettings.range_settings.shot_tracer_count.value
	GlobalSettings.range_settings.shot_tracer_count.setting_changed.connect(_on_tracer_count_changed)

	if has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if not mp_mgr.players.is_empty():
			var cur_p = mp_mgr.get_active_player()
			if not cur_p.is_empty() and not str(cur_p.get("name", "")).is_empty():
				current_profile_name = str(cur_p.get("name", ""))
		elif mp_mgr.has_method("get_default_range_profile_name"):
			var def_name = mp_mgr.get_default_range_profile_name()
			if not def_name.is_empty():
				current_profile_name = def_name
		if not mp_mgr.active_player_changed.is_connected(_on_active_player_changed):
			mp_mgr.active_player_changed.connect(_on_active_player_changed)
		if not mp_mgr.player_ball_graphic_changed.is_connected(_on_player_ball_graphic_changed):
			mp_mgr.player_ball_graphic_changed.connect(_on_player_ball_graphic_changed)

	_apply_profile_to_ball(current_profile_name)

	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected") and not eb.is_connected("club_selected", Callable(self, "_on_club_selected")):
			eb.connect("club_selected", Callable(self, "_on_club_selected"))

func set_profile(player_name: String) -> void:
	if player_name.is_empty():
		return
	if player_name != current_profile_name:
		# Hide tracers for previous profile
		var old_list: Array = profile_tracers.get(current_profile_name, [])
		for tracer in old_list:
			if is_instance_valid(tracer):
				tracer.visible = false

		current_profile_name = player_name

		# Show tracers for new profile
		if not profile_tracers.has(current_profile_name):
			profile_tracers[current_profile_name] = []
		var new_list: Array = profile_tracers[current_profile_name]
		for tracer in new_list:
			if is_instance_valid(tracer):
				tracer.visible = true

		tracers = new_list
		current_tracer = tracers.back() if not tracers.is_empty() else null

	_apply_profile_to_ball(current_profile_name)

func _on_active_player_changed(player_dict: Dictionary) -> void:
	var p_name = str(player_dict.get("name", ""))
	if not p_name.is_empty():
		set_profile(p_name)

func _on_player_ball_graphic_changed(player_name: String, _ball_graphic: String) -> void:
	if player_name.to_lower() == current_profile_name.to_lower():
		_apply_profile_to_ball(current_profile_name)

func _apply_profile_to_ball(player_name: String) -> void:
	if ball == null or not is_instance_valid(ball) or not ball.has_method("apply_ball_graphic"):
		return
	var graphic_id = "single_line"
	var avatar_path = ""
	var p_color = Color(0.24, 0.46, 0.72)
	if has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		var reg = mp_mgr.get_registered_player(player_name)
		if reg.is_empty() and mp_mgr.has_method("get_player_by_name"):
			reg = mp_mgr.get_player_by_name(player_name)
		if mp_mgr.has_method("get_player_ball_graphic"):
			graphic_id = mp_mgr.get_player_ball_graphic(player_name)
		else:
			graphic_id = reg.get("ball_graphic", "single_line")
		avatar_path = mp_mgr.get_player_avatar(player_name) if mp_mgr.has_method("get_player_avatar") else reg.get("avatar", "")
		p_color = mp_mgr.get_player_color(reg) if mp_mgr.has_method("get_player_color") else p_color
	ball.apply_ball_graphic(graphic_id, avatar_path, player_name, p_color)

var _last_club_selected_time: float = -999.0

func _on_club_selected(club_name: String) -> void:
	_cached_selected_club = club_name
	_last_club_selected_time = Time.get_ticks_msec() / 1000.0

func _on_tracer_count_changed(value) -> void:
	max_tracers = value
	for p_name in profile_tracers:
		var p_tracers: Array = profile_tracers[p_name]
		while p_tracers.size() > max_tracers:
			var oldest = p_tracers.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
	tracers = profile_tracers.get(current_profile_name, [])
	current_tracer = tracers.back() if not tracers.is_empty() else null

func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null

func _get_selected_club() -> String:
	if _cached_selected_club != "":
		return _cached_selected_club
	if not is_inside_tree():
		return ""
	var current_scene = get_tree().current_scene
	if current_scene != null:
		var club_selector = current_scene.find_child("ClubSelector", true, false)
		if club_selector and club_selector.current_club:
			_cached_selected_club = club_selector.current_club.text
			return _cached_selected_club
	return ""

func _is_putting_on_green() -> bool:
	var is_on_green = false
	if ball != null:
		var b_lie = str(ball.lie_type).to_lower()
		var p_lie = str(current_lie_type).to_lower()
		is_on_green = (b_lie in ["green", "fringe"] or p_lie in ["green", "fringe"])
	
	var is_putting = false
	if is_on_green:
		var scene_name = ""
		if is_inside_tree():
			var current_scene = get_tree().current_scene
			if current_scene != null:
				scene_name = current_scene.name.to_lower()
		
		if scene_name.contains("putting"):
			is_putting = true
		else:
			var selected_club = _get_selected_club().strip_edges().to_lower()
			var is_putter = (selected_club in ["pt", "putt", "putter"] or selected_club.begins_with("putt"))
			if is_putter:
				is_putting = true
			elif shot_data != null:
				var club_val := str(shot_data.get("club", shot_data.get("Club", ""))).strip_edges().to_lower()
				if club_val in ["pt", "putt", "putter"] or club_val.begins_with("putt"):
					is_putting = true
	return is_on_green and is_putting

func create_new_tracer() -> MeshInstance3D:
	# Don't create tracer if max_tracers is 0
	if max_tracers == 0:
		current_tracer = null
		return null

	if _is_putting_on_green():
		current_tracer = null
		return null

	if not profile_tracers.has(current_profile_name):
		profile_tracers[current_profile_name] = []
	var p_tracers: Array = profile_tracers[current_profile_name]

	# Remove oldest tracer if we've hit the limit for this profile
	while p_tracers.size() >= max_tracers:
		var oldest = p_tracers.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Create new tracer
	var new_tracer = MeshInstance3D.new()
	new_tracer.set_script(BallTrailScript)
	add_child(new_tracer)

	p_tracers.append(new_tracer)
	tracers = p_tracers
	current_tracer = new_tracer
	return new_tracer


func clear_tracers(all_profiles: bool = false) -> void:
	if all_profiles:
		for p_name in profile_tracers:
			for tracer in profile_tracers[p_name]:
				if is_instance_valid(tracer):
					tracer.queue_free()
		profile_tracers.clear()
		tracers.clear()
		current_tracer = null
	else:
		var p_tracers: Array = profile_tracers.get(current_profile_name, [])
		for tracer in p_tracers:
			if is_instance_valid(tracer):
				tracer.queue_free()
		p_tracers.clear()
		tracers = p_tracers
		current_tracer = null

func _process(_delta: float) -> void:
	_handle_tree_occlusion()
	if _is_putting_on_green():
		if not tracers.is_empty():
			clear_tracers()

	if ball != null and is_instance_valid(ball):
		var target_pos = ball.get_interpolated_position() if ball.has_method("get_interpolated_position") else ball.global_position
		if camera_target != null and is_instance_valid(camera_target):
			camera_target.global_position = target_pos

	if track_points and ball != null and current_tracer != null and is_instance_valid(current_tracer):
		var ball_pos = to_local(ball.get_interpolated_position()) if ball.has_method("get_interpolated_position") else ball.position
		current_tracer.update_trail(ball_pos)

	if Input.is_action_just_pressed("hit"):
		manual_hit_shot()
	if Input.is_action_just_pressed("reset"):
		reset_ball(true)

func manual_hit_shot() -> void:
	if ball == null:
		return
	_last_starting_pos = ball.global_position
	var parent_scene = get_parent()
	if parent_scene != null and "aim_target_pos" in parent_scene:
		_last_aim_target_pos = parent_scene.aim_target_pos
	_last_aim_yaw_offset_deg = ball.aim_yaw_offset_deg if ball != null else 0.0
	track_points = false
	create_new_tracer()
	print("[player.gd] Hitting ball manually! ball.aim_yaw_offset_deg = ", ball.aim_yaw_offset_deg)
	ball.hit()
	if current_tracer != null:
		current_tracer.start_trail(ball.position)
	track_points = true
	trail_timer = 0.0
	emit_signal("manual_hit")
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")

func _on_hit_button_pressed() -> void:
	manual_hit_shot()


func _physics_process(_delta: float) -> void:
	if track_points and ball != null:
		var current_height = maxf(0.0, ball.global_position.y - ball.shot_start_pos_global.y)
		apex = maxf(apex, current_height)
		side_distance = ball.get_side_distance_meters()
		if ball.state == PhysicsEnums.BallState.FLIGHT:
			carry = ball.get_downrange_meters()

func get_camera_target() -> Node3D:
	if camera_target != null and is_instance_valid(camera_target):
		return camera_target
	return ball

func get_distance() -> float:
	# Returns the downrange distance in meters
	return ball.get_downrange_meters() if ball != null else 0.0
	
func get_side_distance() -> float:
	# Returns the lateral deviation (offline) in meters
	return ball.get_side_distance_meters() if ball != null else 0.0

func validate_data(data: Dictionary) -> bool:
	if data == null or data.is_empty():
		return false
	var speed: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	if speed <= 0.1:
		print("[player.gd] Shot ignored: ball speed is 0 or negligible (practice swing / ball didn't move).")
		return false
	var shot_type = data.get("ShotType", "")
	if str(shot_type).to_lower() == "practice":
		print("[player.gd] Shot ignored: practice swing detected.")
		return false
	return true


func reset_ball(clear_trail: bool = false):
	ball.reset()
	if camera_target != null and is_instance_valid(camera_target):
		camera_target.global_position = ball.global_position
	if clear_trail or max_tracers == 0:
		clear_tracers()
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	reset_shot_data()
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_ball_at_rest")
		

func reset_shot_data() -> void:
	for key in shot_data.keys():
		shot_data[key] = 0.0

func _on_ball_rest() -> void:
	track_points = false
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_ball_at_rest")
	
	# If we are in a dynamic course play scene, save the ball's resting position as its new spawn_position!
	var parent_scene = get_parent()
	if parent_scene != null and parent_scene.has_method("get_height"):
		var current_hole_loc = parent_scene.get("current_hole_location")
		if current_hole_loc != null and not current_hole_loc.is_zero_approx():
			if not parent_scene.get("practice_mode_active"):
				var next_spawn_pos = ball.global_position
				if ball.get("holed_out_this_shot"):
					next_spawn_pos.y = parent_scene.get_height(next_spawn_pos.x, next_spawn_pos.z) + GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET
				ball.spawn_position = next_spawn_pos
				print("[player.gd] Dynamic course detected. Updated ball.spawn_position to: ", ball.spawn_position)

	shot_data["TotalDistance"] = ball.get_downrange_meters() if ball != null else 0.0  # Downrange distance in meters
	shot_data["CarryDistance"] = carry
	shot_data["Apex"] = apex
	shot_data["SideDistance"] = side_distance
	emit_signal("rest", shot_data)
	
	if current_tracer != null and is_instance_valid(current_tracer):
		current_tracer.finalize_trail()

	if max_tracers == 0:
		clear_tracers()


func get_ball_state():
	return ball.state


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	RainPhysics.apply_rain_shot_reduction(data)
	FoamBallBoost.apply_boost(data, ball.current_selected_club if ball != null else "")
	var success : bool = validate_data(data)
	if success:
		emit_signal("good_data")
	else:
		emit_signal("bad_data")
		return

	var target_dist := 0.0
	var parent_scene = get_parent()
	if parent_scene != null and "aim_target_pos" in parent_scene:
		target_dist = ball.global_position.distance_to(parent_scene.aim_target_pos)
		_last_aim_target_pos = parent_scene.aim_target_pos
	_last_aim_yaw_offset_deg = ball.aim_yaw_offset_deg if ball != null else 0.0

	_last_starting_pos = ball.global_position
	shot_data = data.duplicate()
	shot_data["TargetDistance"] = target_dist
	shot_data["shot_reduction"] = current_shot_reduction

	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var active_player = mp_mgr.get_active_player()
		active_player["last_shot_penalty"] = 0

	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("AnnounceLaunch", shot_data)

	track_points = false
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	create_new_tracer()
	print("[player.gd] Hitting ball from TCP! ball.aim_yaw_offset_deg = ", ball.aim_yaw_offset_deg)
	if has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").log_shot(data)
	ball.hit_from_data(data)
	if current_tracer != null:
		current_tracer.start_trail(ball.position)
	track_points = true
	trail_timer = 0.0
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")


func _on_range_ui_hit_shot(data: Variant) -> void:
	if data is Dictionary:
		RainPhysics.apply_rain_shot_reduction(data)
		FoamBallBoost.apply_boost(data, ball.current_selected_club if ball != null else "")
	var target_dist := 0.0
	var parent_scene = get_parent()
	if parent_scene != null and "aim_target_pos" in parent_scene:
		target_dist = ball.global_position.distance_to(parent_scene.aim_target_pos)
		_last_aim_target_pos = parent_scene.aim_target_pos
	_last_aim_yaw_offset_deg = ball.aim_yaw_offset_deg if ball != null else 0.0

	_last_starting_pos = ball.global_position
	shot_data = data.duplicate()
	shot_data["TargetDistance"] = target_dist
	shot_data["shot_reduction"] = current_shot_reduction
	print("Local shot injection payload: ", JSON.stringify(shot_data))
	if has_node("/root/DebugLogger") and shot_data is Dictionary:
		get_node("/root/DebugLogger").log_shot(shot_data)

	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var active_player = mp_mgr.get_active_player()
		active_player["last_shot_penalty"] = 0

	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("AnnounceLaunch", shot_data)

	track_points = false
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	create_new_tracer()
	ball.hit_from_data(data)
	if current_tracer != null:
		current_tracer.start_trail(ball.position)
	track_points = true
	trail_timer = 0.0
	if has_node("/root/LaunchMonitorManager"):
		get_node("/root/LaunchMonitorManager").call("notify_shot_started")
	

func _on_range_ui_set_env(data: Variant) -> void:
	ball.call_deferred("set_env", data)


func mulligan() -> void:
	reset_shot_data()
	ball.spawn_position = _last_starting_pos
	ball.reset()
	if camera_target != null and is_instance_valid(camera_target):
		camera_target.global_position = ball.global_position
	clear_tracers()
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	track_points = false
	
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("SpeakMulliganHeckle")


func skip_to_rest() -> void:
	if ball == null or ball.state == PhysicsEnums.BallState.REST:
		return
	
	# Set skipping flag on ball to suppress audio
	ball.set("_skipping_flight", true)
	
	# Simulate steps
	var step_delta = 1.0 / 60.0
	var max_ticks = 5000
	var tick = 0
	while ball.state != PhysicsEnums.BallState.REST and tick < max_ticks:
		# Run ball physics step
		ball._physics_process(step_delta)
		
		# Run player tracking step
		if track_points:
			var current_height = maxf(0.0, ball.global_position.y - ball.shot_start_pos_global.y)
			apex = maxf(apex, current_height)
			side_distance = ball.get_side_distance_meters()
			if ball.state == PhysicsEnums.BallState.FLIGHT:
				carry = ball.get_downrange_meters()
			if current_tracer != null and is_instance_valid(current_tracer):
				current_tracer.update_trail(ball.position)
		
		tick += 1
		
	# Ensure the last point is finalized on the tracer
	if current_tracer != null and is_instance_valid(current_tracer):
		current_tracer.update_trail(ball.position)
		current_tracer.finalize_trail()
		
	# Reset skipping flag
	ball.set("_skipping_flight", false)


func _exit_tree() -> void:
	_restore_all_trees_visibility()

func _is_tree_node(node: Node) -> bool:
	if not node is Node3D:
		return false
	var name_lower = node.name.to_lower()
	if name_lower.contains("tree") and not name_lower.contains("treesfolder"):
		return true
	if node.scene_file_path != "" and node.scene_file_path.to_lower().contains("tree"):
		return true
	return false

func _update_cached_trees() -> void:
	_cached_trees.clear()
	var course_scene = get_parent()
	if course_scene == null and is_inside_tree():
		course_scene = get_tree().current_scene
	if course_scene == null:
		return

	# Range scene has no trees
	if course_scene.name == "Range" or (course_scene.scene_file_path != "" and course_scene.scene_file_path.ends_with("range.tscn")):
		return

	# Fast search: Check for TreesFolder first
	var trees_folder = course_scene.find_child("TreesFolder", true, false)
	if trees_folder != null:
		for child in trees_folder.get_children():
			if child is Node3D:
				_cached_trees.append(child)
	else:
		_find_trees_recursive(course_scene, _cached_trees, 0, 4)

	if not _cached_trees.is_empty():
		print("[player.gd] Cached %d trees for camera obstruction check." % _cached_trees.size())

func _find_trees_recursive(node: Node, out_list: Array[Node3D], depth: int = 0, max_depth: int = 4) -> void:
	if depth > max_depth:
		return
	if _is_tree_node(node):
		out_list.append(node)
	for child in node.get_children():
		_find_trees_recursive(child, out_list, depth + 1, max_depth)

func _restore_all_trees_visibility() -> void:
	for tree in _cached_trees:
		if is_instance_valid(tree):
			tree.visible = true

func _handle_tree_occlusion() -> void:
	if MobilePerformance.is_mobile():
		return

	if ball == null or not is_instance_valid(ball):
		return

	# Strictly ignore tree occlusion while ball is in motion/flight
	if ball.state != PhysicsEnums.BallState.REST:
		if not _trees_restored_for_flight:
			_restore_all_trees_visibility()
			_trees_restored_for_flight = true
		return

	_trees_restored_for_flight = false

	# Skip heavy occlusion re-evaluations while player is actively aiming the camera or just switched clubs
	var time_now = Time.get_ticks_msec() / 1000.0
	if (time_now - _last_club_selected_time) < 0.5:
		return
	if Input.is_action_pressed("aim_left") or Input.is_action_pressed("aim_right") or \
	   Input.is_action_pressed("aim_forward") or Input.is_action_pressed("aim_backward"):
		return
	var parent_scene = get_parent()
	if parent_scene != null:
		if parent_scene.has_method("is_actively_aiming") and parent_scene.call("is_actively_aiming"):
			return
		if "_was_keyboard_aiming" in parent_scene and parent_scene._was_keyboard_aiming:
			return
		if "is_screen_aiming" in parent_scene and parent_scene.is_screen_aiming:
			return

	# Scan tree cache ONCE upon first rest/ready, never rescan in a loop
	if not _has_scanned_trees:
		_has_scanned_trees = true
		_update_cached_trees()

	# If this scene has no trees (e.g. driving range or bare course), skip completely
	if _cached_trees.is_empty():
		return

	var camera = get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(camera) or camera.name == "MinimapCamera":
		_restore_all_trees_visibility()
		return

	var camera_pos = camera.global_position
	var ball_pos = ball.global_position

	# Only recheck occlusion if camera or ball moved or at low frequency (1 Hz)
	var pos_changed = camera_pos.distance_squared_to(_last_camera_pos) > 0.05 or ball_pos.distance_squared_to(_last_ball_pos) > 0.05
	if not pos_changed and (time_now - _tree_occlusion_timer) < 1.0:
		return

	_tree_occlusion_timer = time_now
	_last_camera_pos = camera_pos
	_last_ball_pos = ball_pos

	var A = Vector2(camera_pos.x, camera_pos.z)
	var B = Vector2(ball_pos.x, ball_pos.z)
	var AB = B - A
	var AB_len_sq = AB.length_squared()

	# Clean up invalid nodes in the cache without lambda allocation
	for i in range(_cached_trees.size() - 1, -1, -1):
		var tr = _cached_trees[i]
		if not is_instance_valid(tr) or not tr.is_inside_tree():
			_cached_trees.remove_at(i)

	for tree in _cached_trees:
		if not is_instance_valid(tree) or not tree.is_inside_tree():
			continue
		var is_blocking = false
		if AB_len_sq > 0.0001:
			var P = Vector2(tree.global_position.x, tree.global_position.z)
			var AP = P - A
			var t = AP.dot(AB) / AB_len_sq
			# Only hide if the tree's base is between camera and ball (projection factor between 0.0 and 1.0)
			if t >= 0.0 and t <= 1.0:
				var proj = A + AB * t
				var dist = P.distance_to(proj)
				
				# Threshold is based on tree scale. Default radius 1.8 * scale, we add a bit of buffer
				var tree_scale = tree.scale.y
				var threshold = 2.0 * tree_scale
				if dist < threshold:
					is_blocking = true

		if is_blocking:
			if tree.visible:
				tree.visible = false
		else:
			if not tree.visible:
				tree.visible = true
