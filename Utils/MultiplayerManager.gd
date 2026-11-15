extends Node

signal active_player_changed(player: Dictionary)
signal hole_completed(scores: Array)
signal game_over(scores: Array)
signal gimme_awarded(player: Dictionary, extra_strokes: int)
signal catch_up_mode_changed(is_active: bool, player_name: String, current_hole_num: int, target_hole_num: int)
signal player_bag_changed(player_name: String, bag: Array)
signal distance_queue_updated()
signal shot_recorded(player: Dictionary, shot_data: Dictionary)
signal club_averages_tracking_toggled(enabled: bool)
signal player_ball_graphic_changed(player_name: String, ball_graphic: String)
signal player_tee_changed(player_index: int, player_name: String, new_tee: String)

var last_gimme_strokes: int = 0

# Catch-up mode state
var is_in_catch_up: bool = false
var catch_up_player_name: String = ""
var catch_up_saved_group_hole_index: int = -1
var catch_up_saved_group_states: Dictionary = {}
var catch_up_saved_active_idx: int = -1

var players: Array[Dictionary] = []
var active_player_index: int = 0
var current_hole_index: int = 0
var hole_ids: Array = []
var hole_info: Dictionary = {}
var par_scores: Dictionary = {} # par per hole
var practice_mode_active: bool = false
var current_pin_position: Vector3 = Vector3.ZERO


func set_current_pin_position(pos: Vector3) -> void:
	current_pin_position = pos
var selected_course_length: String = "Full 18"
var game_mode: String = "Standard" # Standard, Scramble, 2v2 Scramble, Skins, Closest to Pin
var team_assignments: Dictionary = {} # Team name -> Array of player names
var turn_order_mode: String = "Stay Up" # Stay Up, Classic, Full Hole

# Game mode specific runtime state
var scramble_best_pos: Vector3 = Vector3.ZERO
var team_best_pos: Dictionary = {} # team_name -> Vector3
var skins_won: Dictionary = {} # player_name -> int
var carryover_skins: int = 0
var carryover_eligible_players: Array = [] # player names eligible for carryover
var hole_skins_results: Dictionary = {} # hole_id -> Dictionary
var hole_ctp_results: Dictionary = {} # hole_id -> Dictionary (winners, min_dist_yds, player_dists)

# History and Save State
var current_match_id: String = ""
var course_title: String = "Course"
var scene_path: String = ""
var config_path: String = ""
var current_club: String = "Dr"
var is_finished: bool = false
var unix_time: float = 0.0
var formatted_date: String = ""
var last_shot_player_index: int = -1
var last_shot_info: Dictionary = {}

func _ready() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").connect("club_selected", Callable(self, "_on_club_selected"))
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("_connect_multiplayer_signals"):
			lm._connect_multiplayer_signals()

func _on_club_selected(club_name: String) -> void:
	current_club = club_name

var player_colors: Array[Color] = [
	Color(0.24, 0.46, 0.72), # Blue
	Color(0.85, 0.35, 0.25), # Coral/Red
	Color(0.25, 0.65, 0.35), # Green
	Color(0.85, 0.65, 0.15), # Yellow/Gold
	Color(0.65, 0.25, 0.85), # Purple
	Color(0.15, 0.75, 0.75), # Cyan
	Color(0.85, 0.45, 0.75), # Pink
	Color(0.95, 0.55, 0.15)  # Orange
]

func get_player_color(player: Dictionary) -> Color:
	if player.has("color"):
		return player["color"]
	for i in range(players.size()):
		if players[i]["name"] == player.get("name", ""):
			return player_colors[i % player_colors.size()]
	return player_colors[0]

func _get_global_settings() -> Node:
	if is_inside_tree() and has_node("/root/GlobalSettings"):
		return get_node("/root/GlobalSettings")
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null and main_loop.root.has_node("GlobalSettings"):
		return main_loop.root.get_node("GlobalSettings")
	return null

func setup_game(player_configs: Array, config_data: Dictionary, p_scene_path: String = "", p_config_path: String = "", course_length: String = "Full 18", p_game_mode: String = "Standard", p_team_assignments: Dictionary = {}, p_turn_order_mode: String = "") -> void:
	game_mode = p_game_mode
	team_assignments = p_team_assignments.duplicate(true)
	var gs = _get_global_settings()
	if not p_turn_order_mode.is_empty():
		turn_order_mode = p_turn_order_mode
	elif gs != null and gs.range_settings != null and gs.range_settings.turn_order_mode != null:
		turn_order_mode = gs.range_settings.turn_order_mode.value
	else:
		turn_order_mode = "Stay Up"
	if turn_order_mode == "furthest_away":
		turn_order_mode = "Classic"
	skins_won.clear()
	carryover_skins = 0
	carryover_eligible_players.clear()
	hole_skins_results.clear()
	hole_ctp_results.clear()
	scramble_best_pos = Vector3.ZERO
	team_best_pos.clear()
	current_pin_position = Vector3.ZERO
	clear_last_shot()
	practice_mode_active = false

	var gs_wind = _get_global_settings()
	if gs_wind != null and gs_wind.has_method("start_round_wind"):
		gs_wind.start_round_wind(true)

	# Default 2v2 Scramble teams if not provided
	if game_mode == "2v2 Scramble" and team_assignments.is_empty():
		var t1 = []
		var t2 = []
		for i in range(player_configs.size()):
			var p_name = player_configs[i].get("name", "Player " + str(i + 1))
			if i < 2:
				t1.append(p_name)
			else:
				t2.append(p_name)
		team_assignments["Team 1"] = t1
		team_assignments["Team 2"] = t2

	players.clear()
	for i in range(player_configs.size()):
		var config = player_configs[i]
		var p_name = config.get("name", "Player")
		var p_team = config.get("team", "")
		if p_team.is_empty() and game_mode == "2v2 Scramble":
			for t_name in team_assignments.keys():
				if p_name in team_assignments[t_name]:
					p_team = t_name
					break
			if p_team.is_empty():
				p_team = "Team 1" if i < 2 else "Team 2"

		var reg = get_registered_player(p_name)
		var p_email = config.get("email", reg.get("email", ""))
		var p_avatar = config.get("avatar", reg.get("avatar", ""))
		var p_bag = config.get("bag", reg.get("bag", []))
		var p_skill = config.get("skill_level", reg.get("skill_level", "mid_handicap"))
		var p_handedness = int(config.get("handedness", reg.get("handedness", 0)))
		var p_ball_graphic = config.get("ball_graphic", reg.get("ball_graphic", "single_line"))

		var p_owner_uid: String = str(config.get("owner_uid", ""))
		var p_cloud_uid: String = str(config.get("cloud_uid", ""))
		var p_slot_id: String = str(config.get("slot_id", "slot_%d" % i))
		var my_uid: String = ""
		if has_node("/root/CloudAuth"):
			var ca = get_node("/root/CloudAuth")
			if ca != null and ca.has_method("get_uid"):
				my_uid = ca.get_uid()
		var p_is_remote: bool = bool(config.get("is_remote", (not p_owner_uid.is_empty() and not my_uid.is_empty() and p_owner_uid != my_uid)))

		var p := {
			"name": p_name,
			"tee": config.get("tee", "Blue"),
			"team": p_team,
			"email": p_email,
			"avatar": p_avatar,
			"ball_graphic": p_ball_graphic,
			"bag": p_bag,
			"skill_level": p_skill,
			"handedness": p_handedness,
			"slot_id": p_slot_id,
			"owner_uid": p_owner_uid,
			"cloud_uid": p_cloud_uid,
			"is_remote": p_is_remote,
			"strokes": 0,
			"total_strokes": 0,
			"last_hole_score": 0,
			"position": Vector3.ZERO,
			"holed_out": false,
			"shot_history": [],
			"hole_scores": {},
			"last_shot_penalty": 0,
			"active": true,
			"paused": false,
			"saved_paused_state": {},
			"shot_stats": {},
			"shot_reduction": 0.0,
			"lie_type": "teebox",
			"color": player_colors[i % player_colors.size()],
			"mulligan_history": {},
			"last_shot_tracer_points": [],
			"last_aim_target_pos": Vector3.ZERO,
			"last_aim_yaw_offset_deg": 0.0,
			"last_shot_distance_yards": -1.0,
			"last_shot_club": "",
			"last_shot_starting_lie": "",
			"last_starting_pos": Vector3.ZERO
		}
		players.append(p)
		if not p.get("is_remote", false):
			register_player(p_name, p_email, p_avatar, p_bag, config.get("tee", "Blue"), p_skill, p_handedness, p_ball_graphic)
		skins_won[p_name] = 0
		
	course_title = config_data.get("Title", "")
	if course_title.is_empty():
		var course_info_node = config_data.get("Course Info", {})
		course_title = course_info_node.get("Title", "Course")
		
	hole_info = config_data.get("Hole Info", {})
	var all_hole_ids = hole_info.keys()
	all_hole_ids.sort_custom(func(a, b):
		var num_a = get_hole_number_from_id(str(a))
		var num_b = get_hole_number_from_id(str(b))
		return num_a < num_b
	)
	
	selected_course_length = course_length
	hole_ids = filter_hole_ids_by_length(all_hole_ids, selected_course_length)
		
	current_hole_index = 0
	
	scene_path = p_scene_path
	config_path = p_config_path
	is_finished = false
	unix_time = Time.get_unix_time_from_system()
	formatted_date = Time.get_datetime_string_from_system(false, true)
	current_match_id = "match_" + str(int(unix_time)) + "_" + str(randi() % 1000)
	
	print("[MultiplayerManager] Game setup complete. Mode: %s, Players: %d, Holes: %d" % [game_mode, players.size(), hole_ids.size()])
	save_current_match()

func get_hole_number(idx: int) -> int:
	if hole_ids.is_empty():
		if selected_course_length == "Back 9":
			return idx + 10
		elif selected_course_length == "Extra Holes":
			return idx + 19
		return idx + 1
	var safe_idx = clamp(idx, 0, hole_ids.size() - 1)
	return get_hole_number_from_id(hole_ids[safe_idx], safe_idx)

func get_current_hole_number() -> int:
	return get_hole_number(current_hole_index)

func get_current_hole_id() -> String:
	if not hole_ids.is_empty() and current_hole_index >= 0 and current_hole_index < hole_ids.size():
		return str(hole_ids[current_hole_index])
	return ""

static func filter_hole_ids_by_length(all_hole_ids: Array, length_str: String) -> Array:
	var has_front_9 := false
	var has_back_9 := false
	var has_extra_holes := false

	if length_str == "Full 18":
		has_front_9 = true
		has_back_9 = true
	elif length_str == "Front 9":
		has_front_9 = true
	elif length_str == "Back 9":
		has_back_9 = true
	elif length_str == "Extra Holes":
		has_extra_holes = true
	else:
		has_front_9 = "Front 9" in length_str
		has_back_9 = "Back 9" in length_str
		has_extra_holes = "Extra Holes" in length_str

	# Check whether holes are explicitly numbered beyond 18
	var has_numbered_extra := false
	for h_id in all_hole_ids:
		if get_hole_number_from_id(str(h_id)) >= 19:
			has_numbered_extra = true
			break

	var front_list: Array = []
	var back_list: Array = []
	var extra_list: Array = []

	if has_numbered_extra:
		for i in range(all_hole_ids.size()):
			var h_id = all_hole_ids[i]
			var num = get_hole_number_from_id(str(h_id), i)
			if num <= 9:
				front_list.append(h_id)
			elif num <= 18:
				back_list.append(h_id)
			else:
				extra_list.append(h_id)
	else:
		for i in range(all_hole_ids.size()):
			var h_id = all_hole_ids[i]
			if i < 9:
				front_list.append(h_id)
			elif i < 18:
				back_list.append(h_id)
			else:
				extra_list.append(h_id)

	var result: Array = []
	if has_front_9:
		result.append_array(front_list)
	if has_back_9:
		result.append_array(back_list)
	if has_extra_holes:
		result.append_array(extra_list)

	if result.is_empty():
		result = all_hole_ids.duplicate()
	return result

static func get_hole_number_from_id(hole_id: String, fallback_idx: int = 0) -> int:
	if hole_id.is_empty():
		return fallback_idx + 1
	var clean = hole_id.replace("Hole", "").strip_edges()
	if clean.is_valid_int():
		return int(clean)
	var regex = RegEx.new()
	if regex.compile("\\d+") == OK:
		var m = regex.search(hole_id)
		if m:
			return int(m.get_string())
	return fallback_idx + 1

func start_hole() -> void:
	if current_hole_index >= hole_ids.size():
		is_finished = true
		save_current_match()
		
		# Evaluate round achievements for all active players
		if has_node("/root/AchievementManager") and not practice_mode_active:
			var ach_mgr = get_node("/root/AchievementManager")
			if game_mode == "Closest to Pin":
				var max_pts = -1
				for p in players:
					if p.get("active", true):
						var pts = 0
						for h_id in hole_ids:
							if p["hole_scores"].get(h_id) != null:
								pts += int(p["hole_scores"][h_id])
						if pts > max_pts:
							max_pts = pts
				for p in players:
					if p.get("active", true):
						var p_name = p.get("name", "")
						var pts = 0
						var f9_strokes = 0
						var b9_strokes = 0
						for idx in range(hole_ids.size()):
							var h_id = hole_ids[idx]
							if p["hole_scores"].get(h_id) != null:
								var val = int(p["hole_scores"][h_id])
								pts += val
								if idx < 9:
									f9_strokes += val
								elif idx < 18:
									b9_strokes += val
						var is_winner = (pts == max_pts and max_pts > 0)
						var p_stats = calculate_player_stats(p_name)
						var total_wins = p_stats.get("wins", 0)
						ach_mgr.check_round_achievements(p_name, p["total_strokes"], hole_ids.size(), is_winner, total_wins, f9_strokes, b9_strokes)
			else:
				var min_strokes = 99999
				for p in players:
					if p.get("active", true) and p.get("total_strokes", 0) > 0:
						if p["total_strokes"] < min_strokes:
							min_strokes = p["total_strokes"]
				for p in players:
					if p.get("active", true) and p.get("total_strokes", 0) > 0:
						var p_name = p.get("name", "")
						var f9_strokes = 0
						var b9_strokes = 0
						for idx in range(hole_ids.size()):
							var h_id = hole_ids[idx]
							if p["hole_scores"].get(h_id) != null:
								var val = int(p["hole_scores"][h_id])
								if idx < 9:
									f9_strokes += val
								elif idx < 18:
									b9_strokes += val
						var is_winner = (p["total_strokes"] == min_strokes)
						var p_stats = calculate_player_stats(p_name)
						var total_wins = p_stats.get("wins", 0)
						ach_mgr.check_round_achievements(p_name, p["total_strokes"], hole_ids.size(), is_winner, total_wins, f9_strokes, b9_strokes)

		emit_signal("game_over", players)
		return
		
	var hole_id: String = hole_ids[current_hole_index]
	var current_hole = hole_info.get(hole_id, {})
	var tee_boxes = current_hole.get("Tee Boxes", {})
	
	current_club = "Dr"
	
	# Reset states for current hole
	for p in players:
		if p.get("paused", false):
			continue
		p["strokes"] = 0
		p["holed_out"] = not p.get("active", true)
		p["last_shot_penalty"] = 0
		p["shot_reduction"] = 0.0
		p["lie_type"] = "teebox"
		p["lies_in_hole"] = []
		p["last_putt_dist_yards"] = 0.0
		
		# Set player position to their chosen tee box
		var tee_color: String = p.get("tee", "Blue")
		var tee_pos = get_tee_position_from_boxes(tee_boxes, tee_color)
		var is_driver = true
		var offset_y = 0.059435
		p["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
		p["last_starting_pos"] = p["position"]
		p["shot_history"].clear()
		p["last_aim_target_pos"] = Vector3.ZERO
		p["last_aim_yaw_offset_deg"] = 0.0
		p["last_shot_distance_yards"] = -1.0
		p["last_shot_club"] = ""
		p["last_shot_starting_lie"] = ""

	scramble_best_pos = Vector3.ZERO
	team_best_pos.clear()
	current_pin_position = Vector3.ZERO
	clear_last_shot()

	# Determine honors (Tee-off order)
	if current_hole_index == 0:
		# First hole: Keep active unpaused players first, then inactive/paused players
		players.sort_custom(func(a, b):
			var a_avail = a.get("active", true) and not a.get("paused", false)
			var b_avail = b.get("active", true) and not b.get("paused", false)
			if a_avail != b_avail:
				return a_avail
			return false
		)
	else:
		# Honors: Lowest score on previous hole tees off first (highest in Closest to Pin). If tied, keep order. Inactive/paused players go to the bottom.
		players.sort_custom(func(a, b):
			var a_avail = a.get("active", true) and not a.get("paused", false)
			var b_avail = b.get("active", true) and not b.get("paused", false)
			if a_avail != b_avail:
				return a_avail
			if game_mode == "Closest to Pin":
				if a["last_hole_score"] != b["last_hole_score"]:
					return a["last_hole_score"] > b["last_hole_score"]
			else:
				if a["last_hole_score"] != b["last_hole_score"]:
					return a["last_hole_score"] < b["last_hole_score"]
			return false
		)
		
	# Find first active unpaused player
	active_player_index = 0
	for i in range(players.size()):
		if players[i].get("active", true) and not players[i].get("paused", false):
			active_player_index = i
			break

	# In Classic turn order mode, whichever player is furthest from the pin hits first
	var current_mode = turn_order_mode
	var gs = _get_global_settings()
	if current_mode.is_empty() and gs != null and gs.range_settings != null and gs.range_settings.turn_order_mode != null:
		current_mode = gs.range_settings.turn_order_mode.value
	if (current_mode == "Classic" or current_mode == "furthest_away") and game_mode not in ["Scramble", "2v2 Scramble", "Closest to Pin"]:
		var target_pin = _get_target_pin_position()
		var flat_pin = Vector3(target_pin.x, 0.0, target_pin.z)
		var max_dist := -1.0
		var furthest_idx = active_player_index
		for i in range(players.size()):
			var p = players[i]
			if p.get("active", true) and not p.get("paused", false):
				var flat_pos = Vector3(p["position"].x, 0.0, p["position"].z)
				var d = flat_pos.distance_to(flat_pin)
				if d > max_dist:
					max_dist = d
					furthest_idx = i
		active_player_index = furthest_idx
			
	emit_signal("active_player_changed", get_active_player())
	print("[MultiplayerManager] Starting Hole: %s. Active Player: %s" % [hole_id, get_active_player().get("name", "None")])
	emit_signal("distance_queue_updated")
	save_current_match()
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")

static func format_queue_player_name(full_name: String) -> String:
	var trimmed = full_name.strip_edges()
	var parts = trimmed.split(" ", false)
	if parts.size() >= 2:
		var first_initial = parts[0].substr(0, 1).to_upper() + "."
		var last_name = parts[parts.size() - 1]
		var combined = first_initial + " " + last_name
		if combined.length() > 14:
			return combined.substr(0, 13) + "…"
		return combined
	else:
		if trimmed.length() > 14:
			return trimmed.substr(0, 13) + "…"
		return trimmed

func _get_player_points(p: Dictionary) -> int:
	var pts := 0
	for h_id in hole_ids:
		pts += int(p.get("hole_scores", {}).get(h_id, 0))
	return pts

func _format_player_score_clean(p: Dictionary) -> String:
	if game_mode == "Skins":
		var p_skins = skins_won.get(p.get("name", ""), 0)
		return "%dS" % p_skins
	elif game_mode == "Closest to Pin":
		var pts = _get_player_points(p)
		return "%d" % pts
	else:
		var total_diff := 0
		var completed_any := false
		for idx in range(hole_ids.size()):
			var h_id = hole_ids[idx]
			if idx < current_hole_index or bool(p.get("holed_out", false)):
				var sc = p.get("hole_scores", {}).get(h_id)
				if sc != null and sc > 0:
					var par = int(hole_info.get(h_id, {}).get("Par", 4))
					total_diff += int(sc) - par
					completed_any = true
		if completed_any:
			if total_diff > 0:
				return "+" + str(total_diff)
			elif total_diff < 0:
				return str(total_diff)
			else:
				return "E"
		return "E"

func get_target_pin_position() -> Vector3:
	return _get_target_pin_position()

func get_distance_queue(custom_pin_pos: Variant = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if players.size() <= 1 or is_in_catch_up:
		return result
	
	var active_p = get_active_player()
	var active_name = active_p.get("name", "")
	
	var target_pin: Vector3
	if custom_pin_pos is Vector3 and not (custom_pin_pos as Vector3).is_zero_approx():
		target_pin = custom_pin_pos
	else:
		target_pin = _get_target_pin_position()
	var flat_pin := Vector3(target_pin.x, 0.0, target_pin.z)
	
	var eligible: Array[Dictionary] = []
	for p in players:
		if p.get("name", "") == active_name:
			continue
		if not p.get("active", true) or p.get("paused", false):
			continue
		
		var is_holed: bool = bool(p.get("holed_out", false))
		var p_name = p.get("name", "Player")
		var score_str := _format_player_score_clean(p)
		var dist_yds: int = 0
		var dist_str: String = "0 Yds"
		var club: String = "-"
		
		if not is_holed:
			var p_pos = p.get("position", Vector3.ZERO)
			var flat_pos := Vector3(p_pos.x, 0.0, p_pos.z)
			var dist_meters := flat_pos.distance_to(flat_pin)
			dist_yds = int(round(dist_meters * 1.09361))
			dist_str = "%d Yds" % int(dist_yds)
			var strokes = p.get("strokes", 0)
			var is_in_teebox = (strokes == 0)
			var lie_str = str(p.get("lie_type", "")).to_lower()
			var is_on_green = (lie_str == "green")
			var is_fringe = (lie_str == "fringe")
			club = get_suggested_club(p_name, dist_yds, is_in_teebox, is_on_green, is_fringe)
		
		eligible.append({
			"player": p,
			"name": p_name,
			"formatted_name": format_queue_player_name(p_name),
			"distance_yards": dist_yds,
			"distance_str": dist_str,
			"suggested_club": club,
			"score_str": score_str,
			"holed_out": is_holed
		})
	
	var mode = turn_order_mode
	var gs_mode = _get_global_settings()
	if mode.is_empty() and gs_mode != null and gs_mode.range_settings != null and gs_mode.range_settings.turn_order_mode != null:
		mode = gs_mode.range_settings.turn_order_mode.value

	if game_mode in ["Scramble", "2v2 Scramble"]:
		eligible.sort_custom(func(a, b):
			var a_holed = a["player"].get("holed_out", false)
			var b_holed = b["player"].get("holed_out", false)
			if a_holed != b_holed:
				return not a_holed
			if a_holed and b_holed:
				return players.find(a["player"]) < players.find(b["player"])
			var a_strokes = a["player"].get("strokes", 0)
			var b_strokes = b["player"].get("strokes", 0)
			if a_strokes != b_strokes:
				return a_strokes < b_strokes
			return a["distance_yards"] > b["distance_yards"]
		)
	elif mode == "Stay Up":
		eligible.sort_custom(func(a, b):
			var a_holed = a["player"].get("holed_out", false)
			var b_holed = b["player"].get("holed_out", false)
			if a_holed != b_holed:
				return not a_holed
			if a_holed and b_holed:
				return players.find(a["player"]) < players.find(b["player"])
			var a_tee = (a["player"].get("strokes", 0) == 0)
			var b_tee = (b["player"].get("strokes", 0) == 0)
			if a_tee != b_tee:
				return a_tee
			return a["distance_yards"] > b["distance_yards"]
		)
	elif mode == "Full Hole":
		eligible.sort_custom(func(a, b):
			var a_holed = a["player"].get("holed_out", false)
			var b_holed = b["player"].get("holed_out", false)
			if a_holed != b_holed:
				return not a_holed
			return players.find(a["player"]) < players.find(b["player"])
		)
	else:
		# Classic and default: furthest from pin hits next
		eligible.sort_custom(func(a, b):
			var a_holed = a["player"].get("holed_out", false)
			var b_holed = b["player"].get("holed_out", false)
			if a_holed != b_holed:
				return not a_holed
			if a_holed and b_holed:
				return players.find(a["player"]) < players.find(b["player"])
			return a["distance_yards"] > b["distance_yards"]
		)
	
	if eligible.size() > 3:
		eligible = eligible.slice(0, 3)
		
	return eligible

func get_active_player() -> Dictionary:
	if players.is_empty():
		return {}
	return players[active_player_index]

func get_last_shot_player() -> Dictionary:
	if last_shot_player_index >= 0 and last_shot_player_index < players.size():
		return players[last_shot_player_index]
	return {}

func is_active_player_holed_out() -> bool:
	if players.is_empty():
		return false
	var active_p = get_active_player()
	if active_p.is_empty():
		return false
	return bool(active_p.get("holed_out", false))

func is_current_hole_completed() -> bool:
	if players.is_empty():
		return false
	if is_in_catch_up:
		var cp = get_player_by_name(catch_up_player_name)
		if cp.is_empty():
			return true
		return bool(cp.get("holed_out", false))
	var active_ps = players.filter(func(p): return p.get("active", true) and not p.get("paused", false))
	if active_ps.is_empty():
		return true
	return active_ps.all(func(p): return bool(p.get("holed_out", false)))

func get_mulligan_target_player_index() -> int:
	# If a shot was recorded on the current hole, that player is the mulligan target
	if last_shot_player_index >= 0 and last_shot_player_index < players.size():
		var hole_id = hole_ids[current_hole_index] if not hole_ids.is_empty() else ""
		if not last_shot_info.is_empty():
			if last_shot_info.get("hole_id", "") == hole_id:
				return last_shot_player_index
		else:
			return last_shot_player_index
	return active_player_index

func clear_last_shot() -> void:
	last_shot_player_index = -1
	last_shot_info.clear()

func can_mulligan() -> bool:
	if players.is_empty():
		return false
	var hole_id = hole_ids[current_hole_index] if not hole_ids.is_empty() else ""
	# 1. If we have a recorded last shot on this hole
	if last_shot_player_index >= 0 and last_shot_player_index < players.size():
		if not last_shot_info.is_empty() and last_shot_info.get("hole_id", "") == hole_id:
			return true
	# 2. Check if target player or active player has matching mulligan history to restore
	var target_idx = get_mulligan_target_player_index()
	var target_p = players[target_idx] if target_idx >= 0 and target_idx < players.size() else get_active_player()
	if not target_p.is_empty():
		if target_p.has("mulligan_history") and typeof(target_p["mulligan_history"]) == TYPE_DICTIONARY:
			if target_p["mulligan_history"].has(hole_id) and not target_p["mulligan_history"][hole_id].is_empty():
				return true
		# 3. Allow if target player has taken at least 1 stroke on this hole
		if target_p.get("strokes", 0) > 0:
			return true
	return false

func record_shot(final_position: Vector3, raw_shot_data: Dictionary = {}) -> void:
	last_gimme_strokes = 0
	var active_player = get_active_player()
	var prev_lie = active_player.get("last_shot_starting_lie", active_player.get("lie_type", ""))
	var prev_reduction = float(raw_shot_data.get("shot_reduction", active_player.get("last_shot_reduction", active_player.get("shot_reduction", 0.0))))
	var holed_out_before = active_player.get("holed_out", false)

	var player_node = null
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		player_node = get_tree().root.find_child("Player", true, false)
	var start_pos: Vector3 = active_player.get("position", final_position)
	if player_node != null and player_node.get("_last_starting_pos") != null:
		var last_start = player_node.get("_last_starting_pos")
		if typeof(last_start) == TYPE_VECTOR3 and not (last_start as Vector3).is_zero_approx():
			start_pos = last_start

	active_player["last_starting_pos"] = start_pos

	var ground_dist_yds: float = Vector2(start_pos.x, start_pos.z).distance_to(Vector2(final_position.x, final_position.z)) * 1.09361
	var raw_total_yds: float = (raw_shot_data.get("TotalDistance", 0.0) as float) * 1.09361
	if is_nan(raw_total_yds) or raw_total_yds < 0.0:
		raw_total_yds = 0.0
	if is_nan(ground_dist_yds) or ground_dist_yds < 0.0:
		ground_dist_yds = 0.0
	var shot_dist_yds: float = max(raw_total_yds, ground_dist_yds)
	active_player["last_shot_distance_yards"] = shot_dist_yds
	active_player["last_shot_club"] = current_club
	active_player["last_shot_starting_lie"] = prev_lie
	print("[MultiplayerManager] Shot recorded for %s: dist = %.1f yds (raw: %.1f yds, ground: %.1f yds)" % [active_player.get("name", "Player"), shot_dist_yds, raw_total_yds, ground_dist_yds])

	active_player["strokes"] += 1
	active_player["total_strokes"] += 1
	active_player["position"] = final_position
	active_player["shot_history"].append(final_position)

	# Record the tracer points of the shot that just ended
	var tracer_pts = []
	var last_aim_target = Vector3.ZERO
	var last_aim_yaw = 0.0
	if player_node != null:
		var current_tracer = player_node.get("current_tracer")
		if is_instance_valid(current_tracer) and "points" in current_tracer:
			tracer_pts = current_tracer.points.duplicate()
		if player_node.get("_last_aim_target_pos") != null:
			last_aim_target = player_node.get("_last_aim_target_pos")
		if player_node.get("_last_aim_yaw_offset_deg") != null:
			last_aim_yaw = player_node.get("_last_aim_yaw_offset_deg")
	active_player["last_shot_tracer_points"] = tracer_pts
	active_player["last_aim_target_pos"] = last_aim_target
	active_player["last_aim_yaw_offset_deg"] = last_aim_yaw

	raw_shot_data["shot_reduction"] = prev_reduction
	if not raw_shot_data.has("TargetDistance") or float(raw_shot_data.get("TargetDistance", 0.0)) == 0.0:
		if last_aim_target != Vector3.ZERO and start_pos != Vector3.ZERO and not last_aim_target.is_equal_approx(start_pos):
			var aim_dist_m = start_pos.distance_to(last_aim_target)
			raw_shot_data["TargetDistance"] = aim_dist_m
			raw_shot_data["AimDistanceYards"] = aim_dist_m * 1.09361

	var stat_entry = {}
	var prev_longest_drive := -1.0
	var recorded := false

	if not hole_ids.is_empty():
		var hole_id: String = hole_ids[current_hole_index]
		active_player["hole_scores"][hole_id] = active_player["strokes"]
		
		# Record the shot stats for this hole
		if not active_player.has("shot_stats"):
			active_player["shot_stats"] = {}
		if not active_player["shot_stats"].has(hole_id):
			active_player["shot_stats"][hole_id] = []
			
		var carry_val = raw_shot_data.get("CarryDistance", 0.0) as float
		var total_val = raw_shot_data.get("TotalDistance", 0.0) as float
		var apex_val = raw_shot_data.get("Apex", 0.0) as float
		var side_val = raw_shot_data.get("SideDistance", 0.0) as float
		
		var back_spin = raw_shot_data.get("BackSpin", 0.0) as float
		var side_spin = raw_shot_data.get("SideSpin", 0.0) as float
		var total_spin = raw_shot_data.get("TotalSpin", 0.0) as float
		var spin_axis = raw_shot_data.get("SpinAxis", 0.0) as float
		
		if total_spin == 0.0 and (back_spin != 0.0 or side_spin != 0.0):
			total_spin = sqrt(back_spin * back_spin + side_spin * side_spin)
		if spin_axis == 0.0 and (back_spin != 0.0 or side_spin != 0.0):
			spin_axis = rad_to_deg(atan2(side_spin, back_spin))
		if total_spin != 0.0 and spin_axis != 0.0:
			if back_spin == 0.0:
				back_spin = total_spin * cos(deg_to_rad(spin_axis))
			if side_spin == 0.0:
				side_spin = total_spin * sin(deg_to_rad(spin_axis))
				
		var shot_num = active_player["strokes"]
		stat_entry = {
			"shot_num": shot_num,
			"start_pos": start_pos,
			"end_pos": final_position,
			"club": current_club,
			"speed_mph": raw_shot_data.get("BallSpeed", raw_shot_data.get("Speed", 0.0)) as float,
			"ball_speed_mph": raw_shot_data.get("BallSpeed", raw_shot_data.get("Speed", 0.0)) as float,
			"club_speed_mph": raw_shot_data.get("ClubSpeed", 0.0) as float,
			"smash_factor": raw_shot_data.get("SmashFactor", 0.0) as float,
			"vla_deg": raw_shot_data.get("VLA", 0.0) as float,
			"hla_deg": raw_shot_data.get("HLA", 0.0) as float,
			"back_spin_rpm": back_spin,
			"side_spin_rpm": side_spin,
			"total_spin_rpm": total_spin,
			"spin_axis_deg": spin_axis,
			"carry_yds": carry_val * 1.09361,
			"total_yds": total_val * 1.09361,
			"apex_ft": apex_val * 3.28084,
			"offline_yds": side_val * 1.09361
		}
		active_player["shot_stats"][hole_id].append(stat_entry)

		# Also record the shot globally
		var p_name = active_player.get("name", "")
		prev_longest_drive = -1.0
		var is_remote: bool = bool(active_player.get("is_remote", false))
		if not p_name.is_empty() and not is_remote:
			prev_longest_drive = get_player_longest_drive(p_name)
		recorded = false
		if not p_name.is_empty() and not current_club.is_empty() and not is_remote:
			recorded = record_global_shot(p_name, current_club, raw_shot_data)

	# Track lies and shot achievements
	if not active_player.has("lies_in_hole"):
		active_player["lies_in_hole"] = []
	active_player["lies_in_hole"].append(active_player.get("lie_type", ""))
	
	var shot_club = str(raw_shot_data.get("club", raw_shot_data.get("Club", current_club))).strip_edges()
	if shot_club.is_empty():
		shot_club = current_club
	var c_lower = shot_club.to_lower()
	var is_putter_club = (c_lower in ["pt", "putt", "putter"] or c_lower.begins_with("putt"))

	var ball_node = player_node.get("ball") if player_node != null else null
	var is_actual_putt = is_putter_club
	if ball_node != null and "is_putt" in ball_node:
		is_actual_putt = is_putter_club and bool(ball_node.is_putt)

	if is_actual_putt:
		active_player["last_putt_dist_yards"] = ground_dist_yds
	else:
		active_player["last_putt_dist_yards"] = 0.0

	if has_node("/root/AchievementManager") and not practice_mode_active and is_club_averages_tracking_enabled() and recorded and not active_player.get("is_remote", false):
		var total_yds = (raw_shot_data.get("TotalDistance", 0.0) as float) * 1.09361
		get_node("/root/AchievementManager").check_shot_achievements(active_player.get("name", ""), shot_club, total_yds, prev_longest_drive)

	emit_signal("shot_recorded", active_player, raw_shot_data)
	emit_signal("distance_queue_updated")

	# Check for holing out/clap triggers
	if not practice_mode_active:
		var current_hole = hole_info[hole_ids[current_hole_index]]
		var actual_pin = _get_target_pin_position()
		var target_pin = Vector3(actual_pin.x, final_position.y, actual_pin.z)
		var par = int(round(float(current_hole.get("Par", 4))))
		
		var dist_to_pin = final_position.distance_to(target_pin)
		
		# If ball holed out or stopped inside cup, player holed out.
		var ball_holed = false
		if ball_node != null:
			ball_holed = bool(ball_node.get("is_falling_in_hole")) or bool(ball_node.get("holed_out_this_shot"))
		if active_player.get("holed_out", false) or ball_holed or dist_to_pin <= 0.054:
			active_player["holed_out"] = true
			print("[MultiplayerManager] Player %s holed out! Score: %d" % [active_player["name"], active_player["strokes"]])
			var putt_dist = active_player.get("last_putt_dist_yards", 0.0)
			if is_actual_putt and putt_dist > 0.0 and not active_player.get("is_remote", false):
				var putt_ft = putt_dist * 3.0
				var p_src = raw_shot_data.get("src", "")
				if p_src == "":
					p_src = "lm" if (has_node("/root/LaunchMonitorManager") and get_node("/root/LaunchMonitorManager").get("status") == "Connected") else "manual"
				record_player_longest_putt(active_player.get("name", ""), putt_ft, p_src == "lm")
			if active_player["strokes"] <= par:
				var gs_clap = _get_global_settings()
				if gs_clap != null and gs_clap.has_method("play_golf_clap"):
					gs_clap.play_golf_clap()
			if has_node("/root/AnnouncerEngine"):
				get_node("/root/AnnouncerEngine").call("AnnounceHoleScore", active_player["name"], active_player["strokes"], par)
			if has_node("/root/AchievementManager") and not active_player.get("is_remote", false):
				var shot_dist = active_player.get("last_shot_distance_yards", 0.0)
				var pass_putt_dist = putt_dist if is_actual_putt else 0.0
				get_node("/root/AchievementManager").check_hole_achievements(active_player.get("name", ""), par, active_player["strokes"], active_player.get("lies_in_hole", []), pass_putt_dist, true, shot_club, shot_dist)
		else:
			# Play clap if drive lands in fairway, or ball lands on green in par-1 or less strokes
			var landed_in_fairway = (par >= 4 and active_player["strokes"] == 1 and active_player.get("lie_type", "") == "fairway")
			var landed_on_green = (prev_lie != "green" and active_player.get("lie_type", "") == "green" and active_player["strokes"] <= par - 1)
			if landed_in_fairway or landed_on_green:
				var gs_clap = _get_global_settings()
				if gs_clap != null and gs_clap.has_method("play_golf_clap"):
					gs_clap.play_golf_clap()

			# Check gimme ranges if enabled (strictly only if ball came to rest on the green, never on fringe or off-green)
			var active_gimmes = []
			var gs_gimme = _get_global_settings()
			var current_lie = str(active_player.get("lie_type", "")).to_lower()
			var dist_to_pin_feet = dist_to_pin * 3.28084 # meters to feet

			# Resolve course node with green geometry methods
			var course_node = null
			if player_node != null:
				var p_p = player_node.get_parent()
				if p_p != null:
					if p_p.has_method("get_distance_to_nearest_green") or p_p.has_method("get_distance_to_current_green"):
						course_node = p_p
					elif p_p.get_parent() != null and (p_p.get_parent().has_method("get_distance_to_nearest_green") or p_p.get_parent().has_method("get_distance_to_current_green")):
						course_node = p_p.get_parent()
			if course_node == null and is_inside_tree() and get_tree() != null:
				var curr_scene = get_tree().current_scene
				if curr_scene != null:
					if curr_scene.get("course_instance") != null and (curr_scene.get("course_instance").has_method("get_distance_to_nearest_green") or curr_scene.get("course_instance").has_method("get_distance_to_current_green")):
						course_node = curr_scene.get("course_instance")
					elif curr_scene.has_method("get_distance_to_nearest_green") or curr_scene.has_method("get_distance_to_current_green"):
						course_node = curr_scene
					else:
						var r_child = curr_scene.find_child("Range", true, false)
						if r_child != null and (r_child.has_method("get_distance_to_nearest_green") or r_child.has_method("get_distance_to_current_green")):
							course_node = r_child

			# Check if hole has configured green geometry
			var has_green_geo = false
			if course_node != null:
				if course_node.has_method("get_distance_to_current_green"):
					has_green_geo = (course_node.get_distance_to_current_green(target_pin) <= 0.05 or course_node.get_distance_to_current_green(final_position) <= 0.05)
				elif course_node.has_method("get_distance_to_nearest_green"):
					has_green_geo = (course_node.get_distance_to_nearest_green(target_pin) <= 0.05 or course_node.get_distance_to_nearest_green(final_position) <= 0.05)

			# Strict green eligibility: gimmes are strictly confined to the green
			var is_eligible_lie = false
			if has_green_geo:
				if current_lie == "green":
					is_eligible_lie = true
				elif course_node != null:
					if course_node.has_method("get_distance_to_current_green") and course_node.get_distance_to_current_green(final_position) <= 0.001:
						is_eligible_lie = true
					elif course_node.has_method("get_distance_to_nearest_green") and course_node.get_distance_to_nearest_green(final_position) <= 0.001:
						is_eligible_lie = true
			else:
				# Fallback only for driving range / courses with zero green geometry defined
				# Ball must NOT be in a hazard/sand/bunker
				if current_lie != "sand" and current_lie != "bunker" and current_lie != "water" and current_lie != "hazard":
					is_eligible_lie = (dist_to_pin <= 25.0)

			if is_eligible_lie and gs_gimme != null and gs_gimme.range_settings != null:
				if gs_gimme.range_settings.gimme_range_1_enabled.value:
					active_gimmes.append({
						"strokes": 1,
						"dist_feet": gs_gimme.range_settings.gimme_range_1_distance.value
					})
				if gs_gimme.range_settings.gimme_range_2_enabled.value:
					active_gimmes.append({
						"strokes": 2,
						"dist_feet": gs_gimme.range_settings.gimme_range_2_distance.value
					})
				if gs_gimme.range_settings.gimme_range_3_enabled.value:
					active_gimmes.append({
						"strokes": 3,
						"dist_feet": gs_gimme.range_settings.gimme_range_3_distance.value
					})
			
			active_gimmes.sort_custom(func(a, b): return a["dist_feet"] < b["dist_feet"])
			for gimme in active_gimmes:
				if dist_to_pin_feet <= gimme["dist_feet"]:
					var within_clamped_ring = true
					if course_node != null and course_node.has_method("is_point_within_gimme_ring"):
						within_clamped_ring = course_node.is_point_within_gimme_ring(final_position, actual_pin, gimme["dist_feet"] / 3.28084)
					if within_clamped_ring:
						_apply_gimme(active_player, gimme["strokes"], hole_ids[current_hole_index])
						break

	# Mode-specific shot handling (Scramble / 2v2 Scramble)
	if game_mode == "Scramble" and not hole_ids.is_empty():
		_handle_scramble_shot(active_player)
	elif game_mode == "2v2 Scramble" and not hole_ids.is_empty():
		_handle_2v2_scramble_shot(active_player)

	last_shot_player_index = active_player_index
	last_shot_info = {
		"player_index": active_player_index,
		"player_name": active_player.get("name", ""),
		"hole_index": current_hole_index,
		"hole_id": hole_ids[current_hole_index] if not hole_ids.is_empty() else "",
		"start_pos": start_pos,
		"end_pos": final_position,
		"club": current_club,
		"lie_type": prev_lie,
		"shot_reduction": prev_reduction,
		"last_shot_penalty": active_player.get("last_shot_penalty", 0),
		"aim_target_pos": last_aim_target,
		"aim_yaw_offset_deg": last_aim_yaw,
		"tracer_points": tracer_pts,
		"holed_out_after": active_player.get("holed_out", false),
		"holed_out_before": holed_out_before,
		"stat_entry": stat_entry,
		"raw_shot_data": raw_shot_data.duplicate()
	}
					
	save_current_match()

func _handle_scramble_shot(active_player: Dictionary) -> void:
	var active_ps = players.filter(func(p): return p.get("active", true))
	if active_ps.is_empty():
		return
		
	var hole_id = hole_ids[current_hole_index]
	var current_hole = hole_info.get(hole_id, {})
	var actual_pin = _get_target_pin_position()
	var target_pin = Vector3(actual_pin.x, 0.0, actual_pin.z)
	
	if active_player["holed_out"]:
		var group_score = active_player["strokes"]
		for p in active_ps:
			p["holed_out"] = true
			p["strokes"] = group_score
			p["hole_scores"][hole_id] = group_score
		print("[MultiplayerManager] Scramble group holed out! Score: %d" % group_score)
		return

	var current_stroke = active_player["strokes"]
	var all_took_stroke = active_ps.all(func(p): return p["strokes"] >= current_stroke or p["holed_out"])
	
	if all_took_stroke:
		var closest_pos = active_player["position"]
		var min_dist = 99999.0
		var best_p = active_player
		var best_p_name = active_player["name"]
		
		for p in active_ps:
			if not p["holed_out"] and p["strokes"] == current_stroke:
				var flat_pos = Vector3(p["position"].x, 0.0, p["position"].z)
				var dist = flat_pos.distance_to(target_pin)
				# Penalty strokes (e.g. water hazard) add 10000m so dry balls beat penalty balls
				if p.get("last_shot_penalty", 0) > 0:
					dist += 10000.0
				if dist < min_dist:
					min_dist = dist
					closest_pos = p["position"]
					best_p = p
					best_p_name = p["name"]
					
		scramble_best_pos = closest_pos
		var best_had_penalty = best_p.get("last_shot_penalty", 0) > 0
		var best_lie = best_p.get("lie_type", "fairway")
		for p in active_ps:
			if not p["holed_out"]:
				p["position"] = scramble_best_pos
				p["lie_type"] = best_lie
				p["last_shot_penalty"] = 0
				if best_had_penalty:
					p["strokes"] += 1
					p["total_strokes"] += 1
					if not hole_id.is_empty():
						p["hole_scores"][hole_id] = p["strokes"]
		print("[MultiplayerManager] Scramble best shot for stroke %d selected at %s (Player: %s, Penalty: %s)." % [current_stroke, str(scramble_best_pos), best_p_name, str(best_had_penalty)])

func _handle_2v2_scramble_shot(active_player: Dictionary) -> void:
	var team_name = active_player.get("team", "Team 1")
	var team_ps = players.filter(func(p): return p.get("active", true) and p.get("team", "") == team_name)
	if team_ps.is_empty():
		return
		
	var hole_id = hole_ids[current_hole_index]
	var current_hole = hole_info.get(hole_id, {})
	var actual_pin = _get_target_pin_position()
	var target_pin = Vector3(actual_pin.x, 0.0, actual_pin.z)
	
	if active_player["holed_out"]:
		var team_score = active_player["strokes"]
		for p in team_ps:
			p["holed_out"] = true
			p["strokes"] = team_score
			p["hole_scores"][hole_id] = team_score
		print("[MultiplayerManager] 2v2 Scramble %s holed out! Score: %d" % [team_name, team_score])
		return

	var current_stroke = active_player["strokes"]
	var all_team_took_stroke = team_ps.all(func(p): return p["strokes"] >= current_stroke or p["holed_out"])
	
	if all_team_took_stroke:
		var closest_pos = active_player["position"]
		var min_dist = 99999.0
		var best_p = active_player
		var best_p_name = active_player["name"]
		
		for p in team_ps:
			if not p["holed_out"] and p["strokes"] == current_stroke:
				var flat_pos = Vector3(p["position"].x, 0.0, p["position"].z)
				var dist = flat_pos.distance_to(target_pin)
				# Penalty strokes (e.g. water hazard) add 10000m so dry balls beat penalty balls
				if p.get("last_shot_penalty", 0) > 0:
					dist += 10000.0
				if dist < min_dist:
					min_dist = dist
					closest_pos = p["position"]
					best_p = p
					best_p_name = p["name"]
					
		team_best_pos[team_name] = closest_pos
		var best_had_penalty = best_p.get("last_shot_penalty", 0) > 0
		var best_lie = best_p.get("lie_type", "fairway")
		for p in team_ps:
			if not p["holed_out"]:
				p["position"] = closest_pos
				p["lie_type"] = best_lie
				p["last_shot_penalty"] = 0
				if best_had_penalty:
					p["strokes"] += 1
					p["total_strokes"] += 1
					if not hole_id.is_empty():
						p["hole_scores"][hole_id] = p["strokes"]
		print("[MultiplayerManager] 2v2 Scramble best shot for %s (stroke %d) selected at %s (Player: %s, Penalty: %s)." % [team_name, current_stroke, str(closest_pos), best_p_name, str(best_had_penalty)])

func select_next_player() -> void:
	if is_in_catch_up:
		_handle_catch_up_next()
		return

	if game_mode == "Closest to Pin":
		_select_next_player_ctp()
		emit_signal("distance_queue_updated")
		return

	var remaining_players = players.filter(func(p): return p.get("active", true) and not p.get("paused", false) and not p["holed_out"])
	
	if remaining_players.is_empty():
		# All active unpaused players have holed out. Hole complete!
		var hole_id = hole_ids[current_hole_index] if not hole_ids.is_empty() else ""
		for p in players:
			if p.get("active", true) and not p.get("paused", false):
				p["last_hole_score"] = p["strokes"]
				if not hole_id.is_empty():
					p["hole_scores"][hole_id] = p["strokes"]
			elif not p.get("active", true):
				p["last_hole_score"] = 0
				if not hole_id.is_empty():
					p["hole_scores"][hole_id] = null
		
		if game_mode == "Skins" and not hole_id.is_empty():
			_evaluate_skins_for_hole(hole_id)
		
		save_current_match()
		emit_signal("hole_completed", players)
		return
		
	# Scramble modes: all players on a team/group take their shot for the current stroke before advancing
	if game_mode in ["Scramble", "2v2 Scramble"]:
		var min_strokes = 9999
		for p in remaining_players:
			if p["strokes"] < min_strokes:
				min_strokes = p["strokes"]
		var min_stroke_players = remaining_players.filter(func(p): return p["strokes"] == min_strokes)
		if not min_stroke_players.is_empty():
			var next_player = min_stroke_players[0]
			active_player_index = players.find(next_player)
			emit_signal("active_player_changed", get_active_player())
			print("[MultiplayerManager] Scramble next player: %s" % get_active_player()["name"])
			emit_signal("distance_queue_updated")
			return

	var mode = turn_order_mode
	var gs_mode = _get_global_settings()
	if mode.is_empty() and gs_mode != null and gs_mode.range_settings != null and gs_mode.range_settings.turn_order_mode != null:
		mode = gs_mode.range_settings.turn_order_mode.value

	match mode:
		"Full Hole":
			_select_next_player_full_hole(remaining_players)
		"Classic", "furthest_away":
			_select_next_player_classic(remaining_players)
		_:
			_select_next_player_stay_up(remaining_players)

	emit_signal("distance_queue_updated")


func recalculate_turn_order() -> void:
	if players.is_empty():
		return

	if is_in_catch_up:
		emit_signal("distance_queue_updated")
		return

	var old_active_idx = active_player_index
	var target_active_idx = _determine_next_player_index()

	if target_active_idx >= 0 and target_active_idx < players.size() and target_active_idx != old_active_idx:
		active_player_index = target_active_idx
		emit_signal("active_player_changed", get_active_player())
		print("[MultiplayerManager] Turn order recalculated: active player is now %s" % get_active_player().get("name", "Player"))

	emit_signal("distance_queue_updated")


func _determine_next_player_index() -> int:
	var remaining_players = players.filter(func(p): return p.get("active", true) and not p.get("paused", false) and not p.get("holed_out", false))
	if remaining_players.is_empty():
		return active_player_index

	var cur_player = get_active_player()

	if game_mode == "Closest to Pin":
		if not cur_player.is_empty() and cur_player.get("strokes", 0) == 0 and cur_player.get("active", true) and not cur_player.get("paused", false):
			return active_player_index
		var unplayed = remaining_players.filter(func(p): return p.get("strokes", 0) == 0)
		if not unplayed.is_empty():
			return players.find(unplayed[0])
		return active_player_index

	if game_mode in ["Scramble", "2v2 Scramble"]:
		var min_strokes = 9999
		for p in remaining_players:
			if p.get("strokes", 0) < min_strokes:
				min_strokes = p.get("strokes", 0)
		if not cur_player.is_empty() and cur_player.get("strokes", 0) == min_strokes and cur_player.get("active", true) and not cur_player.get("paused", false) and not cur_player.get("holed_out", false):
			return active_player_index
		var min_stroke_players = remaining_players.filter(func(p): return p.get("strokes", 0) == min_strokes)
		if not min_stroke_players.is_empty():
			return players.find(min_stroke_players[0])
		return active_player_index

	var mode = turn_order_mode
	var gs_mode = _get_global_settings()
	if mode.is_empty() and gs_mode != null and gs_mode.range_settings != null and gs_mode.range_settings.turn_order_mode != null:
		mode = gs_mode.range_settings.turn_order_mode.value

	match mode:
		"Full Hole":
			if not cur_player.is_empty() and (cur_player in remaining_players):
				return active_player_index
			for p in players:
				if p in remaining_players:
					return players.find(p)
			return active_player_index

		"Classic", "furthest_away":
			var target_pin := _get_target_pin_position()
			var flat_pin := Vector3(target_pin.x, 0.0, target_pin.z)
			var furthest_player = null
			var max_dist := -1.0
			for p in remaining_players:
				var flat_pos := Vector3(p["position"].x, 0.0, p["position"].z)
				var dist = flat_pos.distance_to(flat_pin)
				if dist > max_dist:
					max_dist = dist
					furthest_player = p
			if furthest_player != null:
				return players.find(furthest_player)
			return active_player_index

		_: # "Stay Up" (default)
			# 1. Tee shots: All players tee off first
			var tee_players = remaining_players.filter(func(p): return p.get("strokes", 0) == 0)
			if not tee_players.is_empty():
				if not cur_player.is_empty() and (cur_player in tee_players):
					return active_player_index
				return players.find(tee_players[0])

			# 2. Furthest from hole hits
			var target_pin := _get_target_pin_position()
			var flat_pin := Vector3(target_pin.x, 0.0, target_pin.z)
			var furthest_player = null
			var max_dist := -1.0
			for p in remaining_players:
				var flat_pos := Vector3(p["position"].x, 0.0, p["position"].z)
				var dist = flat_pos.distance_to(flat_pin)
				if dist > max_dist:
					max_dist = dist
					furthest_player = p
			if furthest_player != null:
				return players.find(furthest_player)
			return active_player_index


func _get_target_pin_position() -> Vector3:
	if not current_pin_position.is_zero_approx():
		return current_pin_position
	if is_inside_tree() and get_tree() != null:
		var curr_scene = get_tree().current_scene
		if curr_scene != null:
			var c_inst = curr_scene.get("course_instance")
			if c_inst != null and c_inst.get("current_hole_location") is Vector3 and not c_inst.current_hole_location.is_zero_approx():
				return c_inst.current_hole_location
			if curr_scene.get("current_hole_location") is Vector3 and not curr_scene.current_hole_location.is_zero_approx():
				return curr_scene.current_hole_location
			var flag_pin = curr_scene.find_child("FlagPin", true, false)
			if flag_pin != null and flag_pin is Node3D and not flag_pin.global_position.is_zero_approx():
				return flag_pin.global_position
	var target_pin := Vector3.ZERO
	if not hole_ids.is_empty() and current_hole_index < hole_ids.size():
		var hole_id: String = hole_ids[current_hole_index]
		var current_hole = hole_info.get(hole_id, {})
		var hole_loc = current_hole.get("Hole Location", [0.0, 0.0])
		target_pin = Vector3(hole_loc[0], 0.0, hole_loc[1])
	return target_pin


func _select_next_player_stay_up(remaining_players: Array) -> void:
	# 1. Check if all players have taken their first shot (tee shot). All players tee off first.
	var tee_players = remaining_players.filter(func(p): return p.get("strokes", 0) == 0)
	if not tee_players.is_empty():
		var next_player = tee_players[0]
		active_player_index = players.find(next_player)
		emit_signal("active_player_changed", get_active_player())
		print("[MultiplayerManager] Next to tee off: %s" % get_active_player()["name"])
		return

	# 2. Exception: If the player who just hit had their shot go <= 35% of average distance for the selected club,
	# let them hit again rather than switching players (Stay Up).
	# Restrictions:
	# - Player never hits again off the teebox (tee shots / shots started on teebox do not stay up).
	# - Players only stay up when on the green if all remaining players are on the green.
	var just_hit_player = get_active_player()
	var custom_enabled = true
	var gs_cust = _get_global_settings()
	if gs_cust != null and gs_cust.range_settings != null and gs_cust.range_settings.custom_next_player != null:
		custom_enabled = gs_cust.range_settings.custom_next_player.value

	var shot_from_teebox: bool = (
		str(just_hit_player.get("last_shot_starting_lie", "")).to_lower() == "teebox"
		or (not last_shot_info.is_empty() and str(last_shot_info.get("lie_type", "")).to_lower() == "teebox")
		or just_hit_player.get("strokes", 0) <= 1
	)

	if custom_enabled and not just_hit_player.is_empty() and (just_hit_player in remaining_players) and just_hit_player.get("strokes", 0) > 0 and just_hit_player.get("last_shot_penalty", 0) == 0 and not shot_from_teebox:
		var last_dist: float = float(just_hit_player.get("last_shot_distance_yards", -1.0))
		var club_used: String = str(just_hit_player.get("last_shot_club", current_club))
		if club_used.is_empty():
			club_used = current_club
		if club_used.is_empty():
			club_used = "Dr"
		var p_name: String = str(just_hit_player.get("name", ""))
		var avg_dist: float = get_club_effective_distance(p_name, club_used)
		var threshold_dist: float = avg_dist * 0.35

		# Players should only stay up when they are on the green if all players are on the green
		var player_on_green: bool = str(just_hit_player.get("lie_type", "")).to_lower() == "green"
		var all_on_green: bool = true
		if player_on_green:
			for p in remaining_players:
				if str(p.get("lie_type", "")).to_lower() != "green":
					all_on_green = false
					break

		var can_stay_up_on_green: bool = not player_on_green or all_on_green

		if last_dist >= 0.0 and last_dist <= threshold_dist and can_stay_up_on_green:
			print("[MultiplayerManager] Player %s hit <= 35%% of avg club distance (%s: %.1f yds, threshold: %.1f yds, shot: %.1f yds, on_green: %s, all_on_green: %s). Allowing repeat hit!" % [just_hit_player.get("name", "Player"), club_used, avg_dist, threshold_dist, last_dist, str(player_on_green), str(all_on_green)])
			active_player_index = players.find(just_hit_player)
			emit_signal("active_player_changed", get_active_player())
			return

	# Furthest away from the hole hits
	var furthest_player := _get_furthest_player_from_pin(remaining_players)
	if not furthest_player.is_empty():
		active_player_index = players.find(furthest_player)
		emit_signal("active_player_changed", get_active_player())
		var flat_pos := Vector3(furthest_player["position"].x, 0.0, furthest_player["position"].z)
		var target_pin := _get_target_pin_position()
		var dist = flat_pos.distance_to(Vector3(target_pin.x, 0.0, target_pin.z))
		print("[MultiplayerManager] Next to play (furthest from hole: %.1f yds): %s" % [dist * 1.09361, get_active_player()["name"]])


func _get_furthest_player_from_pin(remaining_players: Array) -> Dictionary:
	var target_pin := _get_target_pin_position()
	var flat_pin := Vector3(target_pin.x, 0.0, target_pin.z)
	var furthest_player = null
	var max_dist := -1.0

	for p in remaining_players:
		var flat_pos := Vector3(p["position"].x, 0.0, p["position"].z)
		var dist = flat_pos.distance_to(flat_pin)
		if dist > max_dist:
			max_dist = dist
			furthest_player = p

	if furthest_player != null and furthest_player is Dictionary:
		return furthest_player
	return {}


func peek_next_player() -> Dictionary:
	if is_in_catch_up:
		var cp = get_player_by_name(catch_up_player_name)
		if not cp.is_empty():
			return cp
		return {}

	if game_mode == "Closest to Pin":
		var unplayed_players = players.filter(func(p): return p.get("active", true) and not p.get("paused", false) and p.get("strokes", 0) == 0)
		if not unplayed_players.is_empty():
			return unplayed_players[0]
		return {}

	var remaining_players = players.filter(func(p): return p.get("active", true) and not p.get("paused", false) and not p["holed_out"])
	if remaining_players.is_empty():
		return {}

	if game_mode in ["Scramble", "2v2 Scramble"]:
		var min_strokes = 9999
		for p in remaining_players:
			if p["strokes"] < min_strokes:
				min_strokes = p["strokes"]
		var min_stroke_players = remaining_players.filter(func(p): return p["strokes"] == min_strokes)
		if not min_stroke_players.is_empty():
			return min_stroke_players[0]

	var mode = turn_order_mode
	var gs_mode = _get_global_settings()
	if mode.is_empty() and gs_mode != null and gs_mode.range_settings != null and gs_mode.range_settings.turn_order_mode != null:
		mode = gs_mode.range_settings.turn_order_mode.value

	match mode:
		"Full Hole":
			var cur_player = get_active_player()
			if not cur_player.is_empty() and (cur_player in remaining_players):
				return cur_player
			return remaining_players[0]
		"Classic", "furthest_away":
			return _get_furthest_player_from_pin(remaining_players)
		_:
			# Stay Up:
			# 1. Tee shots: all players tee off first
			var tee_players = remaining_players.filter(func(p): return p.get("strokes", 0) == 0)
			if not tee_players.is_empty():
				return tee_players[0]

			# 2. Stay up check: hit <= 35% of avg club distance
			var just_hit_player = get_active_player()
			var custom_enabled = true
			if gs_mode != null and gs_mode.range_settings != null and gs_mode.range_settings.custom_next_player != null:
				custom_enabled = gs_mode.range_settings.custom_next_player.value

			var shot_from_teebox: bool = (
				str(just_hit_player.get("last_shot_starting_lie", "")).to_lower() == "teebox"
				or (not last_shot_info.is_empty() and str(last_shot_info.get("lie_type", "")).to_lower() == "teebox")
				or just_hit_player.get("strokes", 0) <= 1
			)

			if custom_enabled and not just_hit_player.is_empty() and (just_hit_player in remaining_players) and just_hit_player.get("strokes", 0) > 0 and just_hit_player.get("last_shot_penalty", 0) == 0 and not shot_from_teebox:
				var last_dist: float = float(just_hit_player.get("last_shot_distance_yards", -1.0))
				var club_used: String = str(just_hit_player.get("last_shot_club", current_club))
				if club_used.is_empty():
					club_used = current_club
				if club_used.is_empty():
					club_used = "Dr"
				var p_name: String = str(just_hit_player.get("name", ""))
				var avg_dist: float = get_club_effective_distance(p_name, club_used)
				var threshold_dist: float = avg_dist * 0.35

				var player_on_green: bool = str(just_hit_player.get("lie_type", "")).to_lower() == "green"
				var all_on_green: bool = true
				if player_on_green:
					for p in remaining_players:
						if str(p.get("lie_type", "")).to_lower() != "green":
							all_on_green = false
							break

				var can_stay_up_on_green: bool = not player_on_green or all_on_green
				if last_dist >= 0.0 and last_dist <= threshold_dist and can_stay_up_on_green:
					return just_hit_player

			return _get_furthest_player_from_pin(remaining_players)


func _select_next_player_classic(remaining_players: Array) -> void:
	# Classic: always whoever is furthest from the pin hits next
	var furthest_player := _get_furthest_player_from_pin(remaining_players)
	if not furthest_player.is_empty():
		active_player_index = players.find(furthest_player)
		emit_signal("active_player_changed", get_active_player())
		var flat_pos := Vector3(furthest_player["position"].x, 0.0, furthest_player["position"].z)
		var target_pin := _get_target_pin_position()
		var dist = flat_pos.distance_to(Vector3(target_pin.x, 0.0, target_pin.z))
		print("[MultiplayerManager] [Classic] Next to play (furthest from hole: %.1f yds): %s" % [dist * 1.09361, get_active_player()["name"]])


func _select_next_player_full_hole(remaining_players: Array) -> void:
	# Full Hole: let the player with honors play the full hole, then next player plays full hole, etc.
	var cur_player = get_active_player()
	# If the current player has not holed out, they continue playing
	if not cur_player.is_empty() and (cur_player in remaining_players):
		active_player_index = players.find(cur_player)
		emit_signal("active_player_changed", get_active_player())
		print("[MultiplayerManager] [Full Hole] Continuing with player: %s" % cur_player["name"])
		return

	# Otherwise, current player finished. Select next player in honors sequence who hasn't holed out
	for p in players:
		if p in remaining_players:
			active_player_index = players.find(p)
			emit_signal("active_player_changed", get_active_player())
			print("[MultiplayerManager] [Full Hole] Next player to play full hole: %s" % get_active_player()["name"])
			return

func _evaluate_skins_for_hole(hole_id: String) -> void:
	var active_ps = players.filter(func(p): return p.get("active", true))
	if active_ps.is_empty():
		return
		
	var min_strokes = 9999
	for p in active_ps:
		var s = p["strokes"]
		if s < min_strokes:
			min_strokes = s
			
	var low_players = active_ps.filter(func(p): return p["strokes"] == min_strokes)
	
	if low_players.size() == 1:
		var winner = low_players[0]
		var w_name = winner["name"]
		var skins_to_award = 1
		
		if carryover_skins > 0:
			if carryover_eligible_players.is_empty() or w_name in carryover_eligible_players:
				skins_to_award += carryover_skins
				carryover_skins = 0
				carryover_eligible_players.clear()
			else:
				var eligible_ps = active_ps.filter(func(p): return p["name"] in carryover_eligible_players)
				if not eligible_ps.is_empty():
					var elig_min = 9999
					for ep in eligible_ps:
						if ep["strokes"] < elig_min:
							elig_min = ep["strokes"]
					var elig_low = eligible_ps.filter(func(p): return p["strokes"] == elig_min)
					if elig_low.size() == 1:
						var c_winner = elig_low[0]["name"]
						skins_won[c_winner] = skins_won.get(c_winner, 0) + carryover_skins
						print("[Skins] %s won carryover pot of %d skins from prior tied hole!" % [c_winner, carryover_skins])
						carryover_skins = 0
						carryover_eligible_players.clear()
						
		skins_won[w_name] = skins_won.get(w_name, 0) + skins_to_award
		hole_skins_results[hole_id] = {
			"winner": w_name,
			"skins_awarded": skins_to_award,
			"carryover": carryover_skins
		}
		print("[Skins] Hole %s winner: %s (+%d skin(s))" % [hole_id, w_name, skins_to_award])
	else:
		carryover_skins += 1
		
		if not carryover_eligible_players.is_empty():
			var eligible_ps = active_ps.filter(func(p): return p["name"] in carryover_eligible_players)
			if not eligible_ps.is_empty():
				var elig_min = 9999
				for ep in eligible_ps:
					if ep["strokes"] < elig_min:
						elig_min = ep["strokes"]
				var elig_low = eligible_ps.filter(func(p): return p["strokes"] == elig_min)
				if elig_low.size() == 1:
					var c_winner = elig_low[0]["name"]
					var prev_pot = carryover_skins - 1
					if prev_pot > 0:
						skins_won[c_winner] = skins_won.get(c_winner, 0) + prev_pot
						print("[Skins] %s won prior carryover pot of %d skins!" % [c_winner, prev_pot])
						carryover_skins = 1
						
		carryover_eligible_players.clear()
		for lp in low_players:
			carryover_eligible_players.append(lp["name"])
			
		hole_skins_results[hole_id] = {
			"winner": "Tie",
			"skins_awarded": 0,
			"carryover": carryover_skins
		}
		print("[Skins] Hole %s tied. Carryover pot now: %d skin(s)" % [hole_id, carryover_skins])

func _select_next_player_ctp() -> void:
	var hole_id: String = hole_ids[current_hole_index] if not hole_ids.is_empty() else ""
	var unplayed_players = players.filter(func(p): return p.get("active", true) and not p.get("paused", false) and p.get("strokes", 0) == 0)
	
	if not unplayed_players.is_empty():
		for i in range(players.size()):
			if players[i].get("active", true) and not players[i].get("paused", false) and players[i].get("strokes", 0) == 0:
				active_player_index = i
				emit_signal("active_player_changed", get_active_player())
				print("[MultiplayerManager] Closest to Pin next player: %s" % get_active_player()["name"])
				return

	# All active players have taken their shot on this hole. Evaluate Closest to Pin!
	if not hole_id.is_empty():
		_evaluate_closest_to_pin_for_hole(hole_id)
	else:
		for p in players:
			p["holed_out"] = true

	save_current_match()
	emit_signal("hole_completed", players)

func _evaluate_closest_to_pin_for_hole(hole_id: String) -> void:
	var active_ps = players.filter(func(p): return p.get("active", true) and not p.get("paused", false))
	if active_ps.is_empty():
		return

	var current_hole = hole_info.get(hole_id, {})
	var actual_pin = _get_target_pin_position()
	var target_pin = Vector3(actual_pin.x, 0.0, actual_pin.z)

	var min_dist: float = INF
	var player_dists: Dictionary = {}

	for p in active_ps:
		var flat_pos = Vector3(p["position"].x, 0.0, p["position"].z)
		var dist = flat_pos.distance_to(target_pin)
		# Penalty strokes (e.g. water hazard) add 1000m so dry balls beat penalty balls
		if p.get("last_shot_penalty", 0) > 0:
			dist += 1000.0
		player_dists[p["name"]] = dist
		if dist < min_dist:
			min_dist = dist

	var winners: Array = []
	for p in active_ps:
		var d = player_dists.get(p["name"], INF)
		if abs(d - min_dist) < 0.005:
			winners.append(p)

	var winner_names: Array = []
	for w in winners:
		winner_names.append(w["name"])

	for p in players:
		if p.get("active", true) and not p.get("paused", false):
			p["holed_out"] = true
			if p in winners:
				p["last_hole_score"] = 1
				p["hole_scores"][hole_id] = 1
			else:
				p["last_hole_score"] = 0
				p["hole_scores"][hole_id] = 0
		elif not p.get("active", true):
			p["holed_out"] = true
			p["last_hole_score"] = 0
			p["hole_scores"][hole_id] = null

	var display_dist = (min_dist if min_dist < 1000.0 else min_dist - 1000.0) * 1.09361
	hole_ctp_results[hole_id] = {
		"winners": winner_names,
		"min_dist_yds": display_dist,
		"player_dists": player_dists
	}
	print("[Closest to Pin] Hole %s complete. Winner(s): %s (distance: %.2f yds)" % [hole_id, str(winner_names), display_dist])

func advance_hole() -> void:
	if is_in_catch_up:
		if current_hole_index + 1 < catch_up_saved_group_hole_index:
			advance_catch_up_hole()
		else:
			finish_catch_up_mode()
		return
		
	current_hole_index += 1
	start_hole()

func _apply_gimme(active_player, extra_strokes: int, hole_id: String) -> void:
	last_gimme_strokes = extra_strokes
	active_player["last_gimme_strokes"] = extra_strokes
	active_player["strokes"] += extra_strokes
	active_player["total_strokes"] += extra_strokes
	active_player["hole_scores"][hole_id] = active_player["strokes"]
	active_player["holed_out"] = true
	print("[MultiplayerManager] Player %s holed out via +%d stroke(s) gimme! Score: %d" % [active_player["name"], extra_strokes, active_player["strokes"]])
	emit_signal("gimme_awarded", active_player, extra_strokes)
	save_current_match()
	
	var par = 4
	if hole_info.has(hole_id):
		par = int(round(float(hole_info[hole_id].get("Par", 4))))
	if active_player["strokes"] <= par:
		var gs_clap = _get_global_settings()
		if gs_clap != null and gs_clap.has_method("play_golf_clap"):
			gs_clap.play_golf_clap()
		
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("AnnounceHoleScore", active_player["name"], active_player["strokes"], par)
		
	if has_node("/root/AchievementManager") and not practice_mode_active:
		var last_club = active_player.get("last_shot_club", "")
		# Birdie, eagle, hole-in-one, and putting achievements require sinking the ball into the cup; gimmes cannot earn them
		get_node("/root/AchievementManager").check_hole_achievements(active_player.get("name", ""), par, active_player["strokes"], active_player.get("lies_in_hole", []), 0.0, false, last_club)

func concede_hole() -> void:
	if practice_mode_active or players.is_empty():
		return
		
	var active_player = get_active_player()
	if active_player.is_empty() or active_player.get("holed_out", false):
		return
		
	var hole_idx = clamp(current_hole_index, 0, hole_ids.size() - 1) if not hole_ids.is_empty() else 0
	var hole_id = hole_ids[hole_idx] if not hole_ids.is_empty() else ""
	
	active_player["holed_out"] = true
	if not hole_id.is_empty():
		active_player["hole_scores"][hole_id] = active_player["strokes"]
	active_player["last_hole_score"] = active_player["strokes"]
	
	print("[MultiplayerManager] Player %s conceded/forfeited hole %s at %d strokes (counted as in)!" % [active_player.get("name", "Player"), hole_id, active_player["strokes"]])
	
	if game_mode == "Scramble" and not hole_id.is_empty():
		var active_ps = players.filter(func(p): return p.get("active", true))
		var group_score = active_player["strokes"]
		for p in active_ps:
			p["holed_out"] = true
			p["strokes"] = group_score
			p["hole_scores"][hole_id] = group_score
			p["last_hole_score"] = group_score
	elif game_mode == "2v2 Scramble" and not hole_id.is_empty():
		var team_name = active_player.get("team", "Team A")
		var team_ps = players.filter(func(p): return p.get("active", true) and p.get("team", "") == team_name)
		var team_score = active_player["strokes"]
		for p in team_ps:
			p["holed_out"] = true
			p["strokes"] = team_score
			p["hole_scores"][hole_id] = team_score
			p["last_hole_score"] = team_score
			
	save_current_match()
	
	var par = 4
	if not hole_id.is_empty() and hole_info.has(hole_id):
		par = int(round(float(hole_info[hole_id].get("Par", 4))))
	if has_node("/root/AnnouncerEngine"):
		var announcer = get_node("/root/AnnouncerEngine")
		if announcer.has_method("SpeakForfeitHeckle"):
			announcer.call("SpeakForfeitHeckle")
		elif announcer.has_method("AnnounceHoleScore"):
			announcer.call("AnnounceHoleScore", active_player["name"], active_player["strokes"], par)
			
	select_next_player()


func get_player_by_name(p_name: String) -> Dictionary:
	for p in players:
		if p.get("name", "") == p_name:
			return p
	return {}

func pause_player(idx: int) -> void:
	if idx < 0 or idx >= players.size():
		return
	var player = players[idx]
	if player.get("paused", false):
		return
		
	player["paused"] = true
	player["saved_paused_state"] = {
		"hole_index": current_hole_index,
		"position": player["position"],
		"strokes": player["strokes"],
		"total_strokes": player["total_strokes"],
		"shot_history": player["shot_history"].duplicate(),
		"lie_type": player.get("lie_type", "teebox"),
		"shot_reduction": player.get("shot_reduction", 0.0),
		"holed_out": player.get("holed_out", false),
		"last_aim_target_pos": player.get("last_aim_target_pos", Vector3.ZERO),
		"last_aim_yaw_offset_deg": player.get("last_aim_yaw_offset_deg", 0.0),
		"last_shot_distance_yards": player.get("last_shot_distance_yards", -1.0),
		"last_shot_club": player.get("last_shot_club", ""),
		"last_shot_starting_lie": player.get("last_shot_starting_lie", ""),
		"mulligan_history": player.get("mulligan_history", {}).duplicate(true)
	}
	print("[MultiplayerManager] Player %s paused their turn on hole index %d (strokes: %d)." % [player["name"], current_hole_index, player["strokes"]])
	
	if active_player_index == idx:
		select_next_player()
		
	save_current_match()

func resume_player(idx: int, mode: String = "auto") -> void:
	if idx < 0 or idx >= players.size():
		return
	var player = players[idx]
	if not player.get("paused", false):
		return
		
	var saved_state = player.get("saved_paused_state", {})
	var paused_hole_idx = saved_state.get("hole_index", current_hole_index)
	
	if paused_hole_idx == current_hole_index or mode == "same_hole":
		# Resumed on the same hole! Keep ball position and strokes intact
		player["paused"] = false
		player["saved_paused_state"].clear()
		print("[MultiplayerManager] Player %s resumed on same hole %d right where they left off." % [player["name"], get_current_hole_number()])
		
		# If current active player is holed out, inactive, or paused, switch to this player
		var cur = get_active_player()
		if cur.is_empty() or not cur.get("active", true) or cur.get("paused", false) or cur.get("holed_out", false):
			active_player_index = idx
			emit_signal("active_player_changed", get_active_player())
		else:
			select_next_player()
		recalculate_turn_order()
	elif mode == "current_hole":
		# Group has advanced; player chooses to skip missed holes with dashes
		player["paused"] = false
		for i in range(paused_hole_idx, current_hole_index):
			if i < hole_ids.size():
				player["hole_scores"][hole_ids[i]] = null
		player["saved_paused_state"].clear()
		
		# Set to current hole teebox
		player["strokes"] = 0
		player["holed_out"] = false
		player["shot_history"].clear()
		player["lie_type"] = "teebox"
		player["shot_reduction"] = 0.0
		player["last_shot_penalty"] = 0
		if current_hole_index < hole_ids.size():
			var hole_id: String = hole_ids[current_hole_index]
			var current_hole = hole_info.get(hole_id, {})
			var tee_boxes = current_hole.get("Tee Boxes", {})
			var tee_pos = get_tee_position_from_boxes(tee_boxes, player.get("tee", "Blue"))
			var is_driver = current_club.to_lower() in ["dr", "driver", "1w"]
			var offset_y = 0.059435 if is_driver else 0.021335
			player["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
			player["last_starting_pos"] = player["position"]
			
		print("[MultiplayerManager] Player %s skipped missed holes with dashes and joined Hole %d." % [player["name"], get_current_hole_number()])
		select_next_player()
		recalculate_turn_order()
	elif mode == "catch_up":
		# Group has advanced; player chooses to catch up solo from where they paused!
		player["paused"] = false
		start_catch_up_mode(player, paused_hole_idx, current_hole_index, true)
		
	save_current_match()

func start_catch_up_mode(player_dict: Dictionary, start_hole_idx: int, target_hole_idx: int, restore_saved_state: bool = false) -> void:
	if is_in_catch_up:
		print("[MultiplayerManager] Already in catch-up mode!")
		return
		
	var p_name = player_dict.get("name", "")
	var p_idx = players.find(player_dict)
	if p_idx == -1:
		return
		
	is_in_catch_up = true
	catch_up_player_name = p_name
	catch_up_saved_group_hole_index = target_hole_idx
	catch_up_saved_active_idx = active_player_index
	catch_up_saved_group_states.clear()
	
	# Save state of all other active players on target_hole_idx
	for p in players:
		if p["name"] != p_name:
			catch_up_saved_group_states[p["name"]] = {
				"position": p["position"],
				"strokes": p["strokes"],
				"total_strokes": p["total_strokes"],
				"last_hole_score": p.get("last_hole_score", 0),
				"holed_out": p.get("holed_out", false),
				"shot_history": p["shot_history"].duplicate(),
				"lie_type": p.get("lie_type", "teebox"),
				"shot_reduction": p.get("shot_reduction", 0.0),
				"last_shot_penalty": p.get("last_shot_penalty", 0),
				"last_aim_target_pos": p.get("last_aim_target_pos", Vector3.ZERO),
				"last_aim_yaw_offset_deg": p.get("last_aim_yaw_offset_deg", 0.0),
				"last_shot_distance_yards": p.get("last_shot_distance_yards", -1.0),
				"last_shot_club": p.get("last_shot_club", ""),
				"last_shot_starting_lie": p.get("last_shot_starting_lie", "")
			}
			
	# Move to start_hole_idx
	current_hole_index = start_hole_idx
	active_player_index = p_idx
	clear_last_shot()
	
	if restore_saved_state and player_dict.has("saved_paused_state") and not player_dict["saved_paused_state"].is_empty():
		var saved = player_dict["saved_paused_state"]
		player_dict["position"] = saved.get("position", player_dict["position"])
		player_dict["strokes"] = saved.get("strokes", 0)
		player_dict["shot_history"] = saved.get("shot_history", []).duplicate()
		player_dict["lie_type"] = saved.get("lie_type", "teebox")
		player_dict["shot_reduction"] = saved.get("shot_reduction", 0.0)
		player_dict["holed_out"] = saved.get("holed_out", false)
		player_dict["saved_paused_state"].clear()
	else:
		# Starting fresh at teebox of start_hole_idx
		player_dict["strokes"] = 0
		player_dict["holed_out"] = false
		player_dict["shot_history"].clear()
		player_dict["lie_type"] = "teebox"
		player_dict["shot_reduction"] = 0.0
		player_dict["last_shot_penalty"] = 0
		if current_hole_index < hole_ids.size():
			var hole_id: String = hole_ids[current_hole_index]
			var current_hole = hole_info.get(hole_id, {})
			var tee_boxes = current_hole.get("Tee Boxes", {})
			var tee_pos = get_tee_position_from_boxes(tee_boxes, player_dict.get("tee", "Blue"))
			var is_driver = current_club.to_lower() in ["dr", "driver", "1w"]
			var offset_y = 0.059435 if is_driver else 0.021335
			player_dict["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
			player_dict["last_starting_pos"] = player_dict["position"]
			
	var cur_h_num = get_current_hole_number()
	var grp_h_num = get_hole_number(catch_up_saved_group_hole_index)
	print("[MultiplayerManager] Catch-up mode started for %s: Hole %d -> Group Hole %d" % [p_name, cur_h_num, grp_h_num])
	emit_signal("catch_up_mode_changed", true, p_name, cur_h_num, grp_h_num)
	emit_signal("active_player_changed", get_active_player())
	save_current_match()

func _handle_catch_up_next() -> void:
	var cp = get_player_by_name(catch_up_player_name)
	if cp.is_empty():
		finish_catch_up_mode()
		return
		
	var cp_idx = players.find(cp)
	active_player_index = cp_idx
	
	if not cp.get("holed_out", false):
		# Catch-up player continues taking strokes on this hole!
		emit_signal("active_player_changed", get_active_player())
		return
		
	# Catch-up player has holed out on this hole!
	var hole_id = hole_ids[current_hole_index] if current_hole_index < hole_ids.size() else ""
	if not hole_id.is_empty():
		cp["last_hole_score"] = cp["strokes"]
		cp["hole_scores"][hole_id] = cp["strokes"]
		print("[MultiplayerManager] Catch-up: %s finished %s with %d strokes." % [catch_up_player_name, hole_id, cp["strokes"]])
		
	save_current_match()
	emit_signal("hole_completed", players)

func advance_catch_up_hole() -> void:
	current_hole_index += 1
	var cp = get_player_by_name(catch_up_player_name)
	if cp.is_empty():
		finish_catch_up_mode()
		return
		
	cp["strokes"] = 0
	cp["holed_out"] = false
	cp["shot_history"].clear()
	cp["lie_type"] = "teebox"
	cp["shot_reduction"] = 0.0
	cp["last_shot_penalty"] = 0
	current_club = "Dr"
	
	if current_hole_index < hole_ids.size():
		var hole_id: String = hole_ids[current_hole_index]
		var current_hole = hole_info.get(hole_id, {})
		var tee_boxes = current_hole.get("Tee Boxes", {})
		var tee_pos = get_tee_position_from_boxes(tee_boxes, cp.get("tee", "Blue"))
		var offset_y = 0.059435
		cp["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
		cp["last_starting_pos"] = cp["position"]
		
	active_player_index = players.find(cp)
	clear_last_shot()
	var cur_adv_num = get_current_hole_number()
	var grp_adv_num = get_hole_number(catch_up_saved_group_hole_index)
	print("[MultiplayerManager] Catch-up advancing: %s on Hole %d of %d" % [catch_up_player_name, cur_adv_num, grp_adv_num])
	emit_signal("catch_up_mode_changed", true, catch_up_player_name, cur_adv_num, grp_adv_num)
	emit_signal("active_player_changed", get_active_player())
	save_current_match()

func finish_catch_up_mode() -> void:
	if not is_in_catch_up:
		return
		
	var cp_name = catch_up_player_name
	var cp = get_player_by_name(cp_name)
	var target_idx = catch_up_saved_group_hole_index
	current_hole_index = target_idx
	
	# Restore other players' states on target_idx
	for p in players:
		if p["name"] != cp_name and catch_up_saved_group_states.has(p["name"]):
			var saved = catch_up_saved_group_states[p["name"]]
			p["position"] = saved["position"]
			p["strokes"] = saved["strokes"]
			p["total_strokes"] = saved["total_strokes"]
			p["last_hole_score"] = saved["last_hole_score"]
			p["holed_out"] = saved["holed_out"]
			p["shot_history"] = saved["shot_history"].duplicate()
			p["lie_type"] = saved["lie_type"]
			p["shot_reduction"] = saved["shot_reduction"]
			p["last_shot_penalty"] = saved["last_shot_penalty"]
			p["last_aim_target_pos"] = saved["last_aim_target_pos"]
			p["last_aim_yaw_offset_deg"] = saved["last_aim_yaw_offset_deg"]
			p["last_shot_distance_yards"] = saved["last_shot_distance_yards"]
			p["last_shot_club"] = saved.get("last_shot_club", "")
			p["last_shot_starting_lie"] = saved.get("last_shot_starting_lie", "")
			
	# Setup catch-up player on target_idx teebox
	if not cp.is_empty():
		cp["strokes"] = 0
		cp["holed_out"] = false
		cp["shot_history"].clear()
		cp["lie_type"] = "teebox"
		cp["shot_reduction"] = 0.0
		cp["last_shot_penalty"] = 0
		if current_hole_index < hole_ids.size():
			var hole_id: String = hole_ids[current_hole_index]
			var current_hole = hole_info.get(hole_id, {})
			var tee_boxes = current_hole.get("Tee Boxes", {})
			var tee_pos = get_tee_position_from_boxes(tee_boxes, cp.get("tee", "Blue"))
			var is_driver = true
			var offset_y = 0.059435
			cp["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
			cp["last_starting_pos"] = cp["position"]
			
	is_in_catch_up = false
	catch_up_player_name = ""
	catch_up_saved_group_hole_index = -1
	catch_up_saved_group_states.clear()
	
	var cur_rejoin_num = get_current_hole_number()
	print("[MultiplayerManager] Catch-up completed for %s! Group rejoined on Hole %d." % [cp_name, cur_rejoin_num])
	emit_signal("catch_up_mode_changed", false, cp_name, cur_rejoin_num, cur_rejoin_num)
	select_next_player()
	save_current_match()

func skip_catch_up() -> void:
	if not is_in_catch_up:
		return
	var cp = get_player_by_name(catch_up_player_name)
	if not cp.is_empty():
		for i in range(current_hole_index, catch_up_saved_group_hole_index):
			if i < hole_ids.size():
				cp["hole_scores"][hole_ids[i]] = null
	finish_catch_up_mode()

func add_new_player(player_name: String, tee_color: String) -> void:
	add_new_player_with_mode(player_name, tee_color, "current_hole")

func add_new_player_with_mode(player_name: String, tee_color: String, mode: String = "current_hole") -> void:
	var reg = get_registered_player(player_name)
	var p_email = reg.get("email", "")
	var p_avatar = reg.get("avatar", "")
	var p_handedness = int(reg.get("handedness", 0))

	var p := {
		"name": player_name,
		"tee": tee_color,
		"strokes": 0,
		"total_strokes": 0,
		"last_hole_score": 0,
		"position": Vector3.ZERO,
		"holed_out": false,
		"shot_history": [],
		"hole_scores": {},
		"last_shot_penalty": 0,
		"active": true,
		"paused": false,
		"saved_paused_state": {},
		"shot_stats": {},
		"shot_reduction": 0.0,
		"lie_type": "teebox",
		"email": p_email,
		"avatar": p_avatar,
		"handedness": p_handedness,
		"color": player_colors[players.size() % player_colors.size()],
		"mulligan_history": {},
		"last_shot_tracer_points": [],
		"last_aim_target_pos": Vector3.ZERO,
		"last_aim_yaw_offset_deg": 0.0,
		"last_shot_distance_yards": -1.0,
		"last_shot_club": "",
		"last_shot_starting_lie": "",
		"last_starting_pos": Vector3.ZERO
	}
	
	if mode == "catch_up" and current_hole_index > 0:
		players.append(p)
		register_player(player_name, p_email, p_avatar, [], "", "mid_handicap", p_handedness)
		print("[MultiplayerManager] Added player %s mid-game in catch-up mode." % player_name)
		start_catch_up_mode(p, 0, current_hole_index, false)
		recalculate_turn_order()
	else:
		# Mark all previous holes as "-" (null)
		for i in range(current_hole_index):
			var h_id = hole_ids[i]
			p["hole_scores"][h_id] = null
			
		# Setup position to current tee box if a hole is active
		if current_hole_index < hole_ids.size():
			var hole_id: String = hole_ids[current_hole_index]
			var current_hole = hole_info.get(hole_id, {})
			var tee_boxes = current_hole.get("Tee Boxes", {})
			var tee_pos = get_tee_position_from_boxes(tee_boxes, tee_color)
			var is_driver = current_club.to_lower() in ["dr", "driver", "1w"]
			var offset_y = 0.059435 if is_driver else 0.021335
			p["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
			p["last_starting_pos"] = p["position"]
			
		players.append(p)
		register_player(player_name, p_email, p_avatar, [], "", "mid_handicap", p_handedness)
		print("[MultiplayerManager] Added new player mid-game: %s on hole %d" % [player_name, get_current_hole_number()])
		save_current_match()
		recalculate_turn_order()

func toggle_player_active(idx: int, active: bool) -> void:
	if idx < 0 or idx >= players.size():
		return
		
	var player = players[idx]
	if player.get("active", true) == active:
		return
		
	player["active"] = active
	player["paused"] = false
	player["saved_paused_state"].clear()
	print("[MultiplayerManager] Player %s active status changed to %s" % [player["name"], active])
	
	if not active:
		# Mark current hole score as null
		if current_hole_index < hole_ids.size():
			var hole_id = hole_ids[current_hole_index]
			player["hole_scores"][hole_id] = null
		player["holed_out"] = true
		
		# If they were the active player, select next
		if active_player_index == idx:
			select_next_player()
		else:
			recalculate_turn_order()
	else:
		# Mark all completed holes as "-" (null) if they don't have a score
		for i in range(current_hole_index):
			var h_id = hole_ids[i]
			if not player["hole_scores"].has(h_id) or player["hole_scores"][h_id] == null:
				player["hole_scores"][h_id] = null
				
		player["holed_out"] = false
		player["strokes"] = 0
		player["last_shot_penalty"] = 0
		player["shot_history"].clear()
		player["last_aim_target_pos"] = Vector3.ZERO
		player["last_aim_yaw_offset_deg"] = 0.0
		
		# Set position to current tee box
		if current_hole_index < hole_ids.size():
			var hole_id: String = hole_ids[current_hole_index]
			var current_hole = hole_info.get(hole_id, {})
			var tee_boxes = current_hole.get("Tee Boxes", {})
			var tee_pos = get_tee_position_from_boxes(tee_boxes, player.get("tee", "Blue"))
			var is_driver = current_club.to_lower() in ["dr", "driver", "1w"]
			var offset_y = 0.059435 if is_driver else 0.021335
			player["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
			player["last_starting_pos"] = player["position"]
			
		# If current active player is empty/inactive, select this one
		var current_active = get_active_player()
		if current_active.is_empty() or not current_active.get("active", true):
			active_player_index = idx
			emit_signal("active_player_changed", get_active_player())
		recalculate_turn_order()
			
	save_current_match()

# --- Saving & Resuming Match State ---

func save_current_match() -> void:
	if current_match_id.is_empty():
		return
	if has_node("/root/OnlineSession"):
		var sess = get_node("/root/OnlineSession")
		if sess.is_online_match and bool(sess.get("is_spectator")):
			return
		
	var save_dir = "user://match_history"
	if not DirAccess.dir_exists_absolute(save_dir):
		var err = DirAccess.make_dir_recursive_absolute(save_dir)
		if err != OK:
			push_error("[MultiplayerManager] Failed to create match history directory")
			return
			
	var file_path = save_dir.path_join(current_match_id + ".json")
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		push_error("[MultiplayerManager] Failed to write save file: " + file_path)
		return
		
	var data = {
		"match_id": current_match_id,
		"course_title": course_title,
		"scene_path": scene_path,
		"config_path": config_path,
		"current_hole_index": current_hole_index,
		"active_player_index": active_player_index,
		"practice_mode_active": practice_mode_active,
		"is_finished": is_finished,
		"unix_time": unix_time,
		"formatted_date": formatted_date,
		"players": _serialize_players(players),
		"hole_pars": _get_hole_pars(),
		"selected_course_length": selected_course_length,
		"hole_ids": hole_ids.duplicate(),
		"game_mode": game_mode,
		"turn_order_mode": turn_order_mode,
		"team_assignments": team_assignments,
		"skins_won": skins_won,
		"carryover_skins": carryover_skins,
		"carryover_eligible_players": carryover_eligible_players,
		"hole_skins_results": hole_skins_results,
		"hole_ctp_results": hole_ctp_results
	}
	
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	print("[MultiplayerManager] Match saved successfully to: " + file_path)
	_enforce_history_limit()

func resume_match(match_data: Dictionary) -> void:
	current_match_id = match_data.get("match_id", "")
	course_title = match_data.get("course_title", "")
	scene_path = match_data.get("scene_path", "")
	config_path = match_data.get("config_path", "")
	current_hole_index = match_data.get("current_hole_index", 0)
	active_player_index = match_data.get("active_player_index", 0)
	practice_mode_active = match_data.get("practice_mode_active", false)
	is_finished = match_data.get("is_finished", false)
	unix_time = match_data.get("unix_time", 0.0)
	formatted_date = match_data.get("formatted_date", "")
	selected_course_length = match_data.get("selected_course_length", "Full 18")
	game_mode = match_data.get("game_mode", "Standard")
	var gs_tom = _get_global_settings()
	var def_tom = gs_tom.range_settings.turn_order_mode.value if (gs_tom != null and gs_tom.range_settings != null and gs_tom.range_settings.turn_order_mode != null) else "Stay Up"
	turn_order_mode = match_data.get("turn_order_mode", def_tom)
	team_assignments = match_data.get("team_assignments", {})
	skins_won = match_data.get("skins_won", {})
	carryover_skins = match_data.get("carryover_skins", 0)
	carryover_eligible_players = match_data.get("carryover_eligible_players", [])
	hole_skins_results = match_data.get("hole_skins_results", {})
	hole_ctp_results = match_data.get("hole_ctp_results", {})
	
	if match_data.has("hole_ids") and match_data["hole_ids"] is Array and not match_data["hole_ids"].is_empty():
		hole_ids = match_data["hole_ids"].duplicate()

	# Load config so we have hole info, par scores, etc.
	var config_file = FileAccess.open(config_path, FileAccess.READ)
	if config_file != null:
		var text = config_file.get_as_text()
		var json_parser = JSON.new()
		if text.strip_edges() != "" and json_parser.parse(text) == OK:
			var parsed = json_parser.data
			if typeof(parsed) == TYPE_DICTIONARY:
				hole_info = parsed.get("Hole Info", {})
				if hole_ids.is_empty():
					var all_hole_ids = hole_info.keys()
					all_hole_ids.sort_custom(func(a, b):
						var num_a = get_hole_number_from_id(str(a))
						var num_b = get_hole_number_from_id(str(b))
						return num_a < num_b
					)
					hole_ids = filter_hole_ids_by_length(all_hole_ids, selected_course_length)
			
	# Fallback if hole_info is empty but match_data has saved hole_pars
	if hole_info.is_empty() and match_data.has("hole_pars"):
		var saved_pars = match_data.get("hole_pars", {})
		if typeof(saved_pars) == TYPE_DICTIONARY and not saved_pars.is_empty():
			for h_id in saved_pars:
				hole_info[h_id] = { "Par": int(round(float(saved_pars[h_id]))) }
			if hole_ids.is_empty():
				var all_hole_ids = hole_info.keys()
				all_hole_ids.sort_custom(func(a, b):
					var num_a = get_hole_number_from_id(str(a))
					var num_b = get_hole_number_from_id(str(b))
					return num_a < num_b
				)
				hole_ids = all_hole_ids.duplicate()

	players = _deserialize_players(match_data.get("players", []))
	
	print("[MultiplayerManager] Resuming game on course: %s, hole: %d" % [course_title, current_hole_index])
	
	# Transition scene to course
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").load_course(scene_path, config_path)

func _serialize_players(players_array: Array[Dictionary]) -> Array:
	var serialized = []
	for p in players_array:
		if p.get("is_remote", false):
			serialized.append({
				"name": p.get("name", ""),
				"is_remote": true,
				"slot_id": p.get("slot_id", ""),
				"owner_uid": p.get("owner_uid", ""),
				"total_strokes": p.get("total_strokes", 0),
				"hole_scores": p.get("hole_scores", {}).duplicate(),
				"active": p.get("active", true)
			})
			continue

		var dup = p.duplicate(true)
		# Convert Vector3 position
		if dup.has("position") and typeof(dup["position"]) == TYPE_VECTOR3:
			var pos: Vector3 = dup["position"]
			dup["position"] = [pos.x, pos.y, pos.z]
		if dup.has("last_starting_pos") and typeof(dup["last_starting_pos"]) == TYPE_VECTOR3:
			var start_pos: Vector3 = dup["last_starting_pos"]
			dup["last_starting_pos"] = [start_pos.x, start_pos.y, start_pos.z]
		# Convert Vector3 in shot_history
		if dup.has("shot_history"):
			var history_serialized = []
			for pos in dup["shot_history"]:
				if typeof(pos) == TYPE_VECTOR3:
					history_serialized.append([pos.x, pos.y, pos.z])
				else:
					history_serialized.append(pos)
			dup["shot_history"] = history_serialized
		
		# Convert Vector3 in shot_stats positions
		if dup.has("shot_stats"):
			var stats = dup["shot_stats"]
			if typeof(stats) == TYPE_DICTIONARY:
				for hole_key in stats:
					var shots_list = stats[hole_key]
					if typeof(shots_list) == TYPE_ARRAY:
						for shot in shots_list:
							if typeof(shot) == TYPE_DICTIONARY:
								for position_key in ["position", "start_pos", "end_pos"]:
									if shot.has(position_key) and typeof(shot[position_key]) == TYPE_VECTOR3:
										var pos: Vector3 = shot[position_key]
										shot[position_key] = [pos.x, pos.y, pos.z]
			elif typeof(stats) == TYPE_ARRAY:
				for shot in stats:
					if typeof(shot) == TYPE_DICTIONARY:
						for position_key in ["position", "start_pos", "end_pos"]:
							if shot.has(position_key) and typeof(shot[position_key]) == TYPE_VECTOR3:
								var pos: Vector3 = shot[position_key]
								shot[position_key] = [pos.x, pos.y, pos.z]
						
		# Convert Vector3 in last_shot_tracer_points
		if dup.has("last_shot_tracer_points") and typeof(dup["last_shot_tracer_points"]) == TYPE_ARRAY:
			var pts_serialized = []
			for pt in dup["last_shot_tracer_points"]:
				if typeof(pt) == TYPE_VECTOR3:
					pts_serialized.append([pt.x, pt.y, pt.z])
				else:
					pts_serialized.append(pt)
			dup["last_shot_tracer_points"] = pts_serialized
			
		# Convert last_aim_target_pos
		if dup.has("last_aim_target_pos") and typeof(dup["last_aim_target_pos"]) == TYPE_VECTOR3:
			var pos: Vector3 = dup["last_aim_target_pos"]
			dup["last_aim_target_pos"] = [pos.x, pos.y, pos.z]
			
		# Convert Vector3 in mulligan_history
		if dup.has("mulligan_history") and typeof(dup["mulligan_history"]) == TYPE_DICTIONARY:
			var mulligan_hist_serialized = {}
			for hole_key in dup["mulligan_history"]:
				var shots_list = dup["mulligan_history"][hole_key]
				if typeof(shots_list) == TYPE_ARRAY:
					var serialized_list = []
					for entry in shots_list:
						if typeof(entry) == TYPE_DICTIONARY:
							var entry_dup = entry.duplicate(true)
							if entry_dup.has("start_pos") and typeof(entry_dup["start_pos"]) == TYPE_VECTOR3:
								var pos: Vector3 = entry_dup["start_pos"]
								entry_dup["start_pos"] = [pos.x, pos.y, pos.z]
							if entry_dup.has("end_pos") and typeof(entry_dup["end_pos"]) == TYPE_VECTOR3:
								var pos: Vector3 = entry_dup["end_pos"]
								entry_dup["end_pos"] = [pos.x, pos.y, pos.z]
							if entry_dup.has("aim_target_pos") and typeof(entry_dup["aim_target_pos"]) == TYPE_VECTOR3:
								var pos: Vector3 = entry_dup["aim_target_pos"]
								entry_dup["aim_target_pos"] = [pos.x, pos.y, pos.z]
							if entry_dup.has("tracer_points") and typeof(entry_dup["tracer_points"]) == TYPE_ARRAY:
								var pts_serialized = []
								for pt in entry_dup["tracer_points"]:
									if typeof(pt) == TYPE_VECTOR3:
										pts_serialized.append([pt.x, pt.y, pt.z])
									else:
										pts_serialized.append(pt)
								entry_dup["tracer_points"] = pts_serialized
							serialized_list.append(entry_dup)
					mulligan_hist_serialized[hole_key] = serialized_list
			dup["mulligan_history"] = mulligan_hist_serialized
					
		serialized.append(dup)
	return serialized

func _deserialize_players(serialized_array: Array) -> Array[Dictionary]:
	return deserialize_players(serialized_array)

func deserialize_players(serialized_array: Array) -> Array[Dictionary]:
	var deserialized: Array[Dictionary] = []
	for p in serialized_array:
		var dup: Dictionary = p.duplicate(true)
		# Convert position back to Vector3
		if dup.has("position") and typeof(dup["position"]) == TYPE_ARRAY:
			var arr = dup["position"]
			if arr.size() == 3:
				dup["position"] = Vector3(arr[0], arr[1], arr[2])
			else:
				dup["position"] = Vector3.ZERO
		if dup.has("last_starting_pos"):
			var start_pos = dup["last_starting_pos"]
			if typeof(start_pos) == TYPE_ARRAY and start_pos.size() == 3:
				dup["last_starting_pos"] = Vector3(start_pos[0], start_pos[1], start_pos[2])
			elif typeof(start_pos) != TYPE_VECTOR3:
				dup["last_starting_pos"] = dup.get("position", Vector3.ZERO)
		# Convert shot_history back to Vector3
		if dup.has("shot_history") and typeof(dup["shot_history"]) == TYPE_ARRAY:
			var history_deserialized = []
			for item in dup["shot_history"]:
				if typeof(item) == TYPE_ARRAY and item.size() == 3:
					history_deserialized.append(Vector3(item[0], item[1], item[2]))
				else:
					history_deserialized.append(item)
			dup["shot_history"] = history_deserialized
			
		# Convert shot_stats position back to Vector3
		if dup.has("shot_stats"):
			var stats = dup["shot_stats"]
			if typeof(stats) == TYPE_DICTIONARY:
				for hole_key in stats:
					var shots_list = stats[hole_key]
					if typeof(shots_list) == TYPE_ARRAY:
						for shot in shots_list:
							if typeof(shot) == TYPE_DICTIONARY:
								for position_key in ["position", "start_pos", "end_pos"]:
									if shot.has(position_key) and typeof(shot[position_key]) == TYPE_ARRAY:
										var arr = shot[position_key]
										if arr.size() == 3:
											shot[position_key] = Vector3(arr[0], arr[1], arr[2])
			elif typeof(stats) == TYPE_ARRAY:
				for shot in stats:
					if typeof(shot) == TYPE_DICTIONARY:
						for position_key in ["position", "start_pos", "end_pos"]:
							if shot.has(position_key) and typeof(shot[position_key]) == TYPE_ARRAY:
								var arr = shot[position_key]
								if arr.size() == 3:
									shot[position_key] = Vector3(arr[0], arr[1], arr[2])
							
		# Convert Vector3 in last_shot_tracer_points back
		if dup.has("last_shot_tracer_points") and typeof(dup["last_shot_tracer_points"]) == TYPE_ARRAY:
			var pts_deserialized = []
			for pt in dup["last_shot_tracer_points"]:
				if typeof(pt) == TYPE_ARRAY and pt.size() == 3:
					pts_deserialized.append(Vector3(pt[0], pt[1], pt[2]))
				else:
					pts_deserialized.append(pt)
			dup["last_shot_tracer_points"] = pts_deserialized
			
		# Convert last_aim_target_pos back
		if dup.has("last_aim_target_pos") and typeof(dup["last_aim_target_pos"]) == TYPE_ARRAY:
			var arr = dup["last_aim_target_pos"]
			if arr.size() == 3:
				dup["last_aim_target_pos"] = Vector3(arr[0], arr[1], arr[2])
			else:
				dup["last_aim_target_pos"] = Vector3.ZERO
				
		# Convert Vector3 in mulligan_history back
		if dup.has("mulligan_history") and typeof(dup["mulligan_history"]) == TYPE_DICTIONARY:
			var mulligan_hist_deserialized = {}
			for hole_key in dup["mulligan_history"]:
				var shots_list = dup["mulligan_history"][hole_key]
				if typeof(shots_list) == TYPE_ARRAY:
					var deserialized_list = []
					for entry in shots_list:
						if typeof(entry) == TYPE_DICTIONARY:
							var entry_dup = entry.duplicate(true)
							if entry_dup.has("start_pos") and typeof(entry_dup["start_pos"]) == TYPE_ARRAY:
								var arr = entry_dup["start_pos"]
								if arr.size() == 3:
									entry_dup["start_pos"] = Vector3(arr[0], arr[1], arr[2])
							if entry_dup.has("end_pos") and typeof(entry_dup["end_pos"]) == TYPE_ARRAY:
								var arr = entry_dup["end_pos"]
								if arr.size() == 3:
									entry_dup["end_pos"] = Vector3(arr[0], arr[1], arr[2])
							if entry_dup.has("aim_target_pos") and typeof(entry_dup["aim_target_pos"]) == TYPE_ARRAY:
								var arr = entry_dup["aim_target_pos"]
								if arr.size() == 3:
									entry_dup["aim_target_pos"] = Vector3(arr[0], arr[1], arr[2])
							if entry_dup.has("tracer_points") and typeof(entry_dup["tracer_points"]) == TYPE_ARRAY:
								var pts_deserialized = []
								for pt in entry_dup["tracer_points"]:
									if typeof(pt) == TYPE_ARRAY and pt.size() == 3:
										pts_deserialized.append(Vector3(pt[0], pt[1], pt[2]))
									else:
										pts_deserialized.append(pt)
								entry_dup["tracer_points"] = pts_deserialized
							deserialized_list.append(entry_dup)
					mulligan_hist_deserialized[hole_key] = deserialized_list
			dup["mulligan_history"] = mulligan_hist_deserialized
			
		dup["last_shot_distance_yards"] = float(dup.get("last_shot_distance_yards", -1.0))
		dup["last_shot_club"] = str(dup.get("last_shot_club", ""))
		dup["last_shot_starting_lie"] = str(dup.get("last_shot_starting_lie", ""))
		
		# Ensure strokes and hole_scores are integer types
		dup["strokes"] = int(round(float(dup.get("strokes", 0))))
		dup["total_strokes"] = int(round(float(dup.get("total_strokes", 0))))
		dup["last_hole_score"] = int(round(float(dup.get("last_hole_score", 0))))
		if dup.has("hole_scores") and typeof(dup["hole_scores"]) == TYPE_DICTIONARY:
			var clean_scores = {}
			for k in dup["hole_scores"]:
				var val = dup["hole_scores"][k]
				if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
					clean_scores[str(k)] = int(round(float(val)))
				elif typeof(val) == TYPE_STRING and val.is_valid_float():
					clean_scores[str(k)] = int(round(val.to_float()))
				else:
					clean_scores[str(k)] = val
			dup["hole_scores"] = clean_scores

		# Keep player bag, email, and avatar synchronized with the player's current registry profile
		var p_name = str(dup.get("name", ""))
		var reg = get_registered_player(p_name)
		if not reg.is_empty():
			if reg.has("bag") and typeof(reg["bag"]) == TYPE_ARRAY:
				dup["bag"] = reg["bag"].duplicate()
			if not reg.get("email", "").is_empty():
				dup["email"] = reg["email"]
			if not reg.get("avatar", "").is_empty():
				dup["avatar"] = reg["avatar"]
		elif not dup.has("bag") or typeof(dup["bag"]) != TYPE_ARRAY:
			dup["bag"] = []

		deserialized.append(dup)
	return deserialized

func _enforce_history_limit() -> void:
	var dir_path = "user://match_history"
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var matches_files = []
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path = dir_path.path_join(file_name)
			var f = FileAccess.open(full_path, FileAccess.READ)
			if f != null:
				var text = f.get_as_text()
				var json_parser = JSON.new()
				if text.strip_edges() != "" and json_parser.parse(text) == OK:
					var json = json_parser.data
					if typeof(json) == TYPE_DICTIONARY:
						var u_time = json.get("unix_time", 0.0)
						matches_files.append({
							"file_name": file_name,
							"unix_time": u_time,
							"full_path": full_path
						})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Sort matches by unix_time ascending (oldest first)
	matches_files.sort_custom(func(a, b): return a["unix_time"] < b["unix_time"])
	
	# If we have more than 10, delete the oldest
	while matches_files.size() > 10:
		var oldest = matches_files.pop_front()
		DirAccess.remove_absolute(oldest["full_path"])
		print("[MultiplayerManager] Removed oldest match history file: %s" % oldest["file_name"])


func _get_hole_pars() -> Dictionary:
	var pars = {}
	for h_id in hole_ids:
		var hole = hole_info.get(h_id, {})
		pars[h_id] = int(round(float(hole.get("Par", 4))))
	return pars


# --- Persistent Player Registry ---
const REGISTRY_PATH = "user://players_registry.json"

const AVAILABLE_AVATARS: Array[Dictionary] = [
	{"id": "avatar_1", "name": "The Classic", "path": "res://assets/images/avatars/avatar_1.svg"},
	{"id": "avatar_2", "name": "The Pro", "path": "res://assets/images/avatars/avatar_2.svg"},
	{"id": "avatar_3", "name": "Golden Bear", "path": "res://assets/images/avatars/avatar_3.svg"},
	{"id": "avatar_4", "name": "The Gator", "path": "res://assets/images/avatars/avatar_4.svg"},
	{"id": "avatar_5", "name": "Eagle Eye", "path": "res://assets/images/avatars/avatar_5.svg"},
	{"id": "avatar_6", "name": "The Tiger", "path": "res://assets/images/avatars/avatar_6.svg"},
	{"id": "avatar_7", "name": "Robo Golfer", "path": "res://assets/images/avatars/avatar_7.svg"},
	{"id": "avatar_8", "name": "Fox Caddie", "path": "res://assets/images/avatars/avatar_8.svg"},
	{"id": "avatar_9", "name": "Miami Flamingo", "path": "res://assets/images/avatars/avatar_9.svg"},
	{"id": "avatar_10", "name": "The Heckler", "path": "res://assets/images/avatars/avatar_10.svg"},
]

const AVAILABLE_BALL_GRAPHICS: Array[Dictionary] = [
	{"id": "single_line", "name": "Single Alignment Line", "desc": "Clean tour white ball with sharp alignment line and dual accents"},
	{"id": "triple_track", "name": "Triple Track", "desc": "Tour white with red & blue triple alignment track lines"},
	{"id": "arrow_track", "name": "Arrow Alignment Track", "desc": "High-contrast micro-dot directional chevrons pointing to the pin"},
	{"id": "player_icon", "name": "Match Player Icon", "desc": "Stamps your selected player avatar/icon on the ball"}
]

const PREFERRED_TEE_OPTIONS: Array[String] = ["Blue", "Red", "White", "Black", "Gold"]

static func get_tee_position_from_boxes(tee_boxes: Dictionary, tee_color: String) -> Array:
	if tee_boxes.has(tee_color):
		return tee_boxes[tee_color]
	for k in tee_boxes.keys():
		if str(k).to_lower() == tee_color.to_lower():
			return tee_boxes[k]
	if not tee_boxes.is_empty():
		return tee_boxes.values()[0]
	return [0.0, 0.0]

func get_course_tees() -> Array[String]:
	var tees: Array[String] = []
	for h in hole_info.values():
		if h is Dictionary and h.has("Tee Boxes"):
			for k in h["Tee Boxes"].keys():
				var k_str = str(k).strip_edges()
				if not k_str.is_empty() and not tees.has(k_str):
					tees.append(k_str)
	if tees.is_empty():
		tees = ["Blue", "Red", "White", "Black", "Gold"]
	return tees

func set_player_tee(idx: int, new_tee: String) -> void:
	if idx < 0 or idx >= players.size():
		return
	var player = players[idx]
	var clean_new_tee = new_tee.strip_edges()
	if clean_new_tee.is_empty():
		return
	player["tee"] = clean_new_tee
	
	# Update position if player is on the tee box (0 strokes taken on this hole)
	if player.get("strokes", 0) == 0:
		var target_hole_idx = current_hole_index
		if target_hole_idx < hole_ids.size():
			var hole_id: String = hole_ids[target_hole_idx]
			var current_hole = hole_info.get(hole_id, {})
			var tee_boxes = current_hole.get("Tee Boxes", {})
			var tee_pos = get_tee_position_from_boxes(tee_boxes, clean_new_tee)
			var is_driver = current_club.to_lower() in ["dr", "driver", "1w"]
			var offset_y = 0.059435 if is_driver else 0.021335
			player["position"] = Vector3(tee_pos[0], offset_y, tee_pos[1])
			player["last_starting_pos"] = player["position"]
			player["lie_type"] = "teebox"
	
	# Update registered player profile preference
	var p_name = player.get("name", "")
	if not p_name.is_empty():
		var registered = get_registered_players()
		for reg in registered:
			if reg.get("name", "") == p_name:
				reg["preferred_tee"] = clean_new_tee
				save_registered_players(registered)
				break
			
	save_current_match()
	player_tee_changed.emit(idx, p_name, clean_new_tee)

func set_player_tee_by_name(p_name: String, new_tee: String) -> void:
	for i in range(players.size()):
		if players[i].get("name", "") == p_name:
			set_player_tee(i, new_tee)
			return

static func generate_uuid_v4() -> String:
	var b := PackedByteArray()
	b.resize(16)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(16):
		b[i] = rng.randi() % 256
	# Version 4 (bits 4-7 of byte 6: 0100xxxx)
	b[6] = (b[6] & 0x0f) | 0x40
	# Variant 10xx (bits 6-7 of byte 8: 10xxxxxx)
	b[8] = (b[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3],
		b[4], b[5],
		b[6], b[7],
		b[8], b[9],
		b[10], b[11], b[12], b[13], b[14], b[15]
	]

static func get_registered_players() -> Array[Dictionary]:
	if not FileAccess.file_exists(REGISTRY_PATH):
		return []
	var file = FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return []
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err == OK and typeof(json.data) == TYPE_ARRAY:
		var result: Array[Dictionary] = []
		var modified := false
		var found_primary := false
		for item in json.data:
			if typeof(item) == TYPE_DICTIONARY:
				var entry: Dictionary = item
				if not entry.has("profile_id") or str(entry.get("profile_id", "")).strip_edges().is_empty():
					entry["profile_id"] = generate_uuid_v4()
					modified = true
				if not entry.has("cloud_uid"):
					entry["cloud_uid"] = ""
					modified = true
				if not entry.has("link_role"):
					entry["link_role"] = "none"
					modified = true
				elif str(entry.get("link_role")) == "primary":
					if found_primary:
						entry["link_role"] = "none"
						modified = true
					else:
						found_primary = true
				if not entry.has("last_synced_rev"):
					entry["last_synced_rev"] = 0
					modified = true
				if not entry.has("last_synced_at"):
					entry["last_synced_at"] = 0
					modified = true
				if not entry.has("cloud_lifetime_cache") or typeof(entry.get("cloud_lifetime_cache")) != TYPE_DICTIONARY:
					entry["cloud_lifetime_cache"] = {}
					modified = true
				result.append(entry)
		if DisplayServer.get_name() != "headless":
			if _recover_orphaned_stats_profiles(result):
				modified = true
		if modified:
			save_registered_players(result)
		return result
	return []

static func _recover_orphaned_stats_profiles(result: Array[Dictionary]) -> bool:
	var stats_file_path := "user://player_club_stats.json"
	if not FileAccess.file_exists(stats_file_path):
		return false
	var f := FileAccess.open(stats_file_path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false

	var existing_lower := {}
	for entry in result:
		var n: String = str(entry.get("name", "")).strip_edges().to_lower()
		if not n.is_empty():
			existing_lower[n] = true

	var ignored_names := {
		"practice player": true,
		"golfer 1": true,
		"golfer 2": true,
		"golfer 3": true,
		"golfer 4": true,
		"remoterival": true,
		"localhost": true,
		"host primary": true,
		"renamedgolfer1": true,
		"legacygolfer1": true,
		"legacygolfer2": true
	}

	var recovered_any := false
	for p_key in parsed.keys():
		var p_name := str(p_key).strip_edges()
		var p_lower := p_name.to_lower()
		if p_name.is_empty() or existing_lower.has(p_lower) or ignored_names.has(p_lower):
			continue
		if p_name.begins_with("__") and p_name.ends_with("__"):
			continue
		var clubs_dict = parsed[p_key]
		if not (clubs_dict is Dictionary):
			continue
		var total_shots := 0
		for c_key in clubs_dict.keys():
			var c_data = clubs_dict[c_key]
			if c_data is Dictionary:
				var hist = c_data.get("history", [])
				if hist is Array:
					total_shots += hist.size()
				else:
					total_shots += int(c_data.get("shots", 0))
		if total_shots <= 0:
			continue

		var bag: Array = ["Dr", "3W", "5W", "4H", "4i", "5i", "6i", "7i", "8i", "9i", "PW", "GW", "SW", "LW", "Pt"]
		result.append({
			"profile_id": generate_uuid_v4(),
			"name": p_name,
			"preferred_tee": "Blue",
			"avatar": "",
			"handedness": 0,
			"ball_graphic": "single_line",
			"bag": bag,
			"cloud_uid": "",
			"link_role": "none",
			"last_synced_rev": 0,
			"last_synced_at": 0,
			"cloud_lifetime_cache": {}
		})
		existing_lower[p_lower] = true
		recovered_any = true
	return recovered_any

static func save_registered_players(players_list: Array) -> void:
	var file = FileAccess.open(REGISTRY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(players_list, "\t"))
		file.close()

func get_primary_player_name() -> String:
	var registered = get_registered_players()
	for p in registered:
		if p.get("link_role", "") == "primary":
			return str(p.get("name", ""))
	return ""

func set_primary_player(player_name: String, cloud_uid: String = "") -> void:
	var registered = get_registered_players()
	var canonical_target = player_name.strip_edges().to_lower()
	for p in registered:
		var p_name = str(p.get("name", "")).strip_edges().to_lower()
		if not canonical_target.is_empty() and p_name == canonical_target:
			p["link_role"] = "primary"
			if not cloud_uid.is_empty():
				p["cloud_uid"] = cloud_uid
		else:
			if p.get("link_role", "") == "primary":
				p["link_role"] = "none"
	save_registered_players(registered)
	if has_node("/root/CloudSync"):
		var cs = get_node("/root/CloudSync")
		if not player_name.strip_edges().is_empty():
			if not cloud_uid.strip_edges().is_empty() and cs.has_method("enqueue_historical_local_matches_for_profile"):
				cs.call("enqueue_historical_local_matches_for_profile", player_name, cloud_uid)
			cs.call("mark_profile_dirty", player_name)
		if cs.has_signal("primary_profile_changed"):
			cs.emit_signal("primary_profile_changed", player_name)

func get_player_by_cloud_uid(cloud_uid: String) -> Dictionary:
	if cloud_uid.strip_edges().is_empty():
		return {}
	var registered = get_registered_players()
	for p in registered:
		if str(p.get("cloud_uid", "")).strip_edges() == cloud_uid.strip_edges():
			return p
	return {}

func rename_player_profile(old_name: String, new_name: String) -> bool:
	var clean_old = old_name.strip_edges()
	var clean_new = new_name.strip_edges()
	if clean_old.is_empty() or clean_new.is_empty():
		return false
	if clean_old.to_lower() == clean_new.to_lower():
		return true

	# 1. Update registry
	var registered = get_registered_players()
	var found := false
	for p in registered:
		var curr_name = str(p.get("name", "")).strip_edges()
		if curr_name.to_lower() == clean_new.to_lower() and curr_name.to_lower() != clean_old.to_lower():
			push_error("[MultiplayerManager] rename_player_profile failed: destination name already exists")
			return false
		if curr_name.to_lower() == clean_old.to_lower():
			p["name"] = clean_new
			found = true
	if not found:
		return false
	save_registered_players(registered)

	# 2. Update player_club_stats.json
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, clean_old)
	if not matching_key.is_empty() and stats.has(matching_key):
		stats[clean_new] = stats[matching_key]
		stats.erase(matching_key)
		save_global_club_stats(stats)

	# 3. Update player_achievements.json
	var ach_path = "user://player_achievements.json"
	if FileAccess.file_exists(ach_path):
		var af = FileAccess.open(ach_path, FileAccess.READ)
		if af != null:
			var txt = af.get_as_text()
			af.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				var m_ach_key = _find_matching_player_key_in_dict(parsed, clean_old)
				if not m_ach_key.is_empty():
					parsed[clean_new] = parsed[m_ach_key]
					parsed.erase(m_ach_key)
					var out_f = FileAccess.open(ach_path, FileAccess.WRITE)
					if out_f != null:
						out_f.store_string(JSON.stringify(parsed, "\t"))
						out_f.close()
	if has_node("/root/AchievementManager"):
		var ach_node = get_node("/root/AchievementManager")
		if "_player_data" in ach_node and ach_node.get("_player_data") is Dictionary:
			var pdata: Dictionary = ach_node.get("_player_data")
			if pdata.has(clean_old):
				pdata[clean_new] = pdata[clean_old]
				pdata.erase(clean_old)

	# 4. Update player_swing_issues.json
	var swing_path = "user://player_swing_issues.json"
	if FileAccess.file_exists(swing_path):
		var sf = FileAccess.open(swing_path, FileAccess.READ)
		if sf != null:
			var txt = sf.get_as_text()
			sf.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				var m_swing_key = _find_matching_player_key_in_dict(parsed, clean_old)
				if not m_swing_key.is_empty():
					parsed[clean_new] = parsed[m_swing_key]
					parsed.erase(m_swing_key)
					var out_sf = FileAccess.open(swing_path, FileAccess.WRITE)
					if out_sf != null:
						out_sf.store_string(JSON.stringify(parsed, "\t"))
						out_sf.close()

	# 5. Update match history files in user://match_history/
	var match_dir = "user://match_history"
	if DirAccess.dir_exists_absolute(match_dir):
		var dir = DirAccess.open(match_dir)
		if dir != null:
			dir.list_dir_begin()
			var fn = dir.get_next()
			while fn != "":
				if not dir.current_is_dir() and fn.ends_with(".json"):
					var m_file_path = match_dir.path_join(fn)
					var mf = FileAccess.open(m_file_path, FileAccess.READ)
					if mf != null:
						var m_txt = mf.get_as_text().strip_edges()
						mf.close()
						if not m_txt.is_empty():
							var m_json = JSON.parse_string(m_txt)
							if m_json is Dictionary:
								var modified_m := false
								if m_json.has("players") and m_json["players"] is Array:
									for p in m_json["players"]:
										if p is Dictionary and str(p.get("name", "")).to_lower() == clean_old.to_lower():
											p["name"] = clean_new
											modified_m = true
								for key in ["skins_won", "carryover_eligible_players", "team_assignments"]:
									if m_json.has(key) and m_json[key] is Dictionary:
										for k in m_json[key].keys():
											if str(k).to_lower() == clean_old.to_lower():
												m_json[key][clean_new] = m_json[key][k]
												m_json[key].erase(k)
												modified_m = true
								if modified_m:
									var out_mf = FileAccess.open(m_file_path, FileAccess.WRITE)
									if out_mf != null:
										out_mf.store_string(JSON.stringify(m_json, "\t"))
										out_mf.close()
				fn = dir.get_next()
			dir.list_dir_end()

	# 6. Update current in-memory active participants if playing
	for pl in players:
		if str(pl.get("name", "")).to_lower() == clean_old.to_lower():
			pl["name"] = clean_new

	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", clean_new)

	return true

func record_player_longest_putt(player_name: String, putt_ft: float, _is_lm: bool = true) -> void:
	if player_name.strip_edges().is_empty() or putt_ft <= 0.0:
		return
	if putt_ft > 180.0:
		putt_ft = 180.0
	for p in players:
		if p.get("name", "") == player_name and p.get("is_remote", false):
			return
	var canonical_name = get_canonical_player_name(player_name)
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, canonical_name)
	var target_key = matching_key if not matching_key.is_empty() else canonical_name
	if not stats.has(target_key):
		stats[target_key] = {}
	if not stats[target_key].has("_records") or typeof(stats[target_key]["_records"]) != TYPE_DICTIONARY:
		stats[target_key]["_records"] = {}
	var cur_longest = float(stats[target_key]["_records"].get("longest_putt_ft", 0.0))
	if putt_ft > cur_longest:
		stats[target_key]["_records"]["longest_putt_ft"] = putt_ft
		save_global_club_stats(stats)
		if has_node("/root/CloudSync"):
			get_node("/root/CloudSync").call("mark_profile_dirty", target_key)

func get_player_total_shots(player_name: String) -> int:
	var global_stats = load_global_club_stats()
	var shots_count = 0
	if global_stats.has(player_name) and typeof(global_stats[player_name]) == TYPE_DICTIONARY:
		for clb in global_stats[player_name]:
			if typeof(global_stats[player_name][clb]) == TYPE_ARRAY:
				shots_count += global_stats[player_name][clb].size()
	return shots_count

func get_default_range_profile_name() -> String:
	var registered = get_registered_players()
	if registered.is_empty():
		return "Player 1"
	
	var best_player = ""
	var max_hits = -1
	var global_stats = load_global_club_stats()
	
	for p in registered:
		var p_name = str(p.get("name", "")).strip_edges()
		if p_name.is_empty():
			continue
		
		var shots_count = 0
		if global_stats.has(p_name) and typeof(global_stats[p_name]) == TYPE_DICTIONARY:
			for clb in global_stats[p_name]:
				if typeof(global_stats[p_name][clb]) == TYPE_ARRAY:
					shots_count += global_stats[p_name][clb].size()
		
		if shots_count > max_hits:
			max_hits = shots_count
			best_player = p_name
			
	if best_player.is_empty():
		return registered[0].get("name", "Player 1")
		
	return best_player

func get_default_player_name() -> String:
	var registered = get_registered_players()
	if registered.is_empty():
		return "Player 1"
	
	var best_player = ""
	var max_history_score = -1
	var global_stats = load_global_club_stats()
	
	for p in registered:
		var p_name = str(p.get("name", "")).strip_edges()
		if p_name.is_empty():
			continue
		
		var stats = calculate_player_stats(p_name)
		var matches_count = int(stats.get("matches_played", 0))
		
		var shots_count = 0
		if global_stats.has(p_name) and typeof(global_stats[p_name]) == TYPE_DICTIONARY:
			for clb in global_stats[p_name]:
				if typeof(global_stats[p_name][clb]) == TYPE_ARRAY:
					shots_count += global_stats[p_name][clb].size()
		
		var score = (matches_count * 1000) + shots_count
		if score > max_history_score:
			max_history_score = score
			best_player = p_name
			
	if best_player.is_empty():
		return registered[0].get("name", "Player 1")
		
	return best_player

static func get_registered_player(player_name: String) -> Dictionary:
	var registered = get_registered_players()
	for p in registered:
		if p.get("name", "").to_lower() == player_name.to_lower():
			return p
	return {}

func update_player_profile(player_name: String, email: String, avatar: String, preferred_tee: String = "", skill_level: String = "mid_handicap", handedness: int = 0, ball_graphic: String = "single_line") -> bool:
	var registered = get_registered_players()
	for p in registered:
		if p.get("name", "").to_lower() == player_name.to_lower():
			p["email"] = email.strip_edges()
			p["avatar"] = avatar.strip_edges()
			p["preferred_tee"] = preferred_tee.strip_edges()
			p["skill_level"] = skill_level.strip_edges() if not skill_level.is_empty() else "mid_handicap"
			p["handedness"] = handedness
			p["ball_graphic"] = ball_graphic.strip_edges() if not ball_graphic.is_empty() else "single_line"
			save_registered_players(registered)
			# Update actively playing participants if this player is in match
			for pl in players:
				if pl.get("name", "").to_lower() == player_name.to_lower():
					pl["email"] = p["email"]
					pl["avatar"] = p["avatar"]
					pl["skill_level"] = p["skill_level"]
					pl["handedness"] = handedness
					pl["ball_graphic"] = p["ball_graphic"]
			var cur_p = get_active_player()
			if not cur_p.is_empty() and cur_p.get("name", "").to_lower() == player_name.to_lower():
				_sync_launch_monitor_for_player(cur_p)
			emit_signal("player_ball_graphic_changed", player_name, p["ball_graphic"])
			if has_node("/root/CloudSync"):
				get_node("/root/CloudSync").call("mark_profile_dirty", player_name)
			return true
	return false

func get_player_ball_graphic(player_name: String) -> String:
	var p = get_registered_player(player_name)
	if p.is_empty():
		p = get_player_by_name(player_name)
	var bg = p.get("ball_graphic", "single_line")
	if bg.is_empty() or bg == "osg_pro" or bg == "classic_white" or bg == "tour_yellow" or bg == "neon_orange":
		bg = "single_line"
	return bg

func get_player_skill_level(player_name: String) -> String:
	var p = get_registered_player(player_name)
	return p.get("skill_level", "mid_handicap")

func get_player_email(player_name: String) -> String:
	var p = get_registered_player(player_name)
	return p.get("email", "")

func get_player_avatar(player_name: String) -> String:
	var p = get_registered_player(player_name)
	if p.is_empty():
		p = get_player_by_name(player_name)
	return p.get("avatar", "")

func get_player_preferred_tee(player_name: String) -> String:
	var p = get_registered_player(player_name)
	return p.get("preferred_tee", "")

func get_player_handedness(player_name: String) -> int:
	var p = get_registered_player(player_name)
	return int(p.get("handedness", 0))

func get_player_handedness_name(player_name: String) -> String:
	return "Left" if get_player_handedness(player_name) == 1 else "Right"

func _get_launch_monitor_manager() -> Node:
	if is_inside_tree() and has_node("/root/LaunchMonitorManager"):
		return get_node("/root/LaunchMonitorManager")
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null and main_loop.root.has_node("LaunchMonitorManager"):
		return main_loop.root.get_node("LaunchMonitorManager")
	return null

func _sync_launch_monitor_for_player(player: Dictionary) -> void:
	if player.is_empty():
		return
	var lm = _get_launch_monitor_manager()
	if lm != null and lm.has_method("set_handedness"):
		var hand = int(player.get("handedness", 0))
		lm.set_handedness(hand)

func get_player_bag(player_name: String) -> Array:
	if player_name.is_empty():
		return []
	var reg = get_registered_player(player_name)
	if reg.has("bag") and typeof(reg["bag"]) == TYPE_ARRAY and not reg["bag"].is_empty():
		return reg["bag"]
	for p in players:
		if p.get("name", "").to_lower() == player_name.to_lower():
			var b = p.get("bag", [])
			if typeof(b) == TYPE_ARRAY and not b.is_empty():
				return b
	if reg.has("bag") and typeof(reg["bag"]) == TYPE_ARRAY:
		return reg["bag"]
	return []

func set_player_bag(player_name: String, bag: Array) -> bool:
	if player_name.is_empty():
		return false
	var registered = get_registered_players()
	var found = false
	var clean_bag: Array[String] = []
	for c in bag:
		var c_str = str(c).strip_edges()
		if not c_str.is_empty() and not clean_bag.has(c_str):
			clean_bag.append(c_str)
			
	for p in registered:
		if p.get("name", "").to_lower() == player_name.to_lower():
			p["bag"] = clean_bag
			save_registered_players(registered)
			found = true
			break
			
	for p in players:
		if p.get("name", "").to_lower() == player_name.to_lower():
			p["bag"] = clean_bag
			break
			
	emit_signal("player_bag_changed", player_name, clean_bag)
	if found and has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", player_name)
	return found

func register_player(player_name: String, email: String = "", avatar: String = "", bag: Array = [], preferred_tee: String = "", skill_level: String = "mid_handicap", handedness: int = 0, ball_graphic: String = "single_line") -> void:
	if player_name.is_empty():
		return
	var registered = get_registered_players()
	for p in registered:
		if p.get("name", "").to_lower() == player_name.to_lower():
			var changed = false
			if not email.is_empty() and p.get("email", "") != email:
				p["email"] = email.strip_edges()
				changed = true
			if not avatar.is_empty() and p.get("avatar", "") != avatar:
				p["avatar"] = avatar.strip_edges()
				changed = true
			if not bag.is_empty() and p.get("bag", []) != bag:
				p["bag"] = bag
				changed = true
			if not preferred_tee.is_empty() and p.get("preferred_tee", "") != preferred_tee:
				p["preferred_tee"] = preferred_tee.strip_edges()
				changed = true
			if not skill_level.is_empty() and p.get("skill_level", "") != skill_level:
				p["skill_level"] = skill_level.strip_edges()
				changed = true
			if p.get("handedness", 0) != handedness:
				p["handedness"] = handedness
				changed = true
			if not ball_graphic.is_empty() and p.get("ball_graphic", "single_line") != ball_graphic:
				p["ball_graphic"] = ball_graphic.strip_edges()
				changed = true
			if changed:
				save_registered_players(registered)
				if has_node("/root/CloudSync"):
					get_node("/root/CloudSync").call("mark_profile_dirty", player_name)
			return # Already exists
	
	var new_player = {
		"profile_id": generate_uuid_v4(),
		"name": player_name,
		"email": email.strip_edges(),
		"avatar": avatar.strip_edges(),
		"bag": bag,
		"preferred_tee": preferred_tee.strip_edges(),
		"skill_level": skill_level.strip_edges() if not skill_level.is_empty() else "mid_handicap",
		"handedness": handedness,
		"ball_graphic": ball_graphic.strip_edges() if not ball_graphic.is_empty() else "single_line",
		"created_at": Time.get_unix_time_from_system(),
		"cloud_uid": "",
		"link_role": "none",
		"last_synced_rev": 0,
		"last_synced_at": 0,
		"cloud_lifetime_cache": {}
	}
	registered.append(new_player)
	save_registered_players(registered)
	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", player_name)
	print("[MultiplayerManager] Registered new player: ", player_name)

func delete_player_permanently(player_name: String) -> void:
	# Remove from registry
	var registered = get_registered_players()
	var new_list = []
	for p in registered:
		if p.get("name", "").to_lower() != player_name.to_lower():
			new_list.append(p)
	save_registered_players(new_list)
	
	# Remove from club stats
	var stats = load_global_club_stats()
	if stats.has(player_name):
		stats.erase(player_name)
		save_global_club_stats(stats)
		
	clear_player_swing_issues(player_name)
	print("[MultiplayerManager] Permanently deleted player: ", player_name)

func clear_player_ball_history(player_name: String) -> void:
	# Clear entry from club stats and record tombstone
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, player_name)
	var target_key = matching_key if not matching_key.is_empty() else player_name
	if not stats.has(target_key):
		stats[target_key] = {}
	var tombstones = stats[target_key].get("_tombstones", {})
	if typeof(tombstones) != TYPE_DICTIONARY:
		tombstones = {}
	tombstones["cleared_all_at"] = int(Time.get_unix_time_from_system())
	stats[target_key] = {
		"_tombstones": tombstones,
		"_records": {}
	}
	save_global_club_stats(stats)
	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", target_key)
	print("[MultiplayerManager] Cleared ball history for player: ", target_key)


# --- Global Club Stats Persistence ---

var _cached_global_club_stats: Dictionary = {}

func load_global_club_stats(force_reload: bool = false) -> Dictionary:
	if not force_reload and not _cached_global_club_stats.is_empty():
		return _cached_global_club_stats
	var path = "user://player_club_stats.json"
	if not FileAccess.file_exists(path):
		_cached_global_club_stats = {}
		return _cached_global_club_stats
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_cached_global_club_stats = {}
		return _cached_global_club_stats
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			var stats: Dictionary = json.data
			var modified := false
			for p in stats.keys():
				if typeof(stats[p]) != TYPE_DICTIONARY:
					continue
				for clb in stats[p].keys():
					if typeof(stats[p][clb]) != TYPE_ARRAY:
						continue
					for entry in stats[p][clb]:
						if typeof(entry) == TYPE_DICTIONARY:
							if not entry.has("id") or str(entry.get("id", "")).strip_edges().is_empty():
								var json_str = JSON.stringify(entry)
								entry["id"] = json_str.sha1_text().substr(0, 12)
								modified = true
							if not entry.has("t"):
								entry["t"] = 0
								modified = true
							if entry.has("SideDistance"):
								var sd = absf(float(entry["SideDistance"]))
								var td = absf(float(entry.get("TotalDistance", entry.get("CarryDistance", 0.0))))
								# If SideDistance was poisoned by legacy world Z bug (> 100m or > TotalDistance * 1.2)
								if sd > 100.0 or (td > 15.0 and sd > td * 1.2):
									entry["SideDistance"] = 0.0
									modified = true
			if modified:
				save_global_club_stats(stats)
				print("[MultiplayerManager] Backfilled missing shot IDs/timestamps or repaired corrupted entries in player_club_stats.json")
			_cached_global_club_stats = stats
			return _cached_global_club_stats
	_cached_global_club_stats = {}
	return _cached_global_club_stats

func invalidate_global_club_stats_cache() -> void:
	_cached_global_club_stats.clear()

func save_global_club_stats(stats: Dictionary) -> void:
	_cached_global_club_stats = stats
	var path = "user://player_club_stats.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(stats, "\t"))
		file.close()

static func normalize_club_code(club_name: String) -> String:
	var c = club_name.strip_edges()
	var c_lower = c.to_lower()
	if c_lower in ["dr", "driver", "1w"]:
		return "Dr"
	if c_lower in ["pt", "putt", "putter"]:
		return "Pt"
	for std in STANDARD_CLUBS:
		if std.to_lower() == c_lower:
			return std
		if CLUB_FULL_NAMES.has(std) and CLUB_FULL_NAMES[std].to_lower() == c_lower:
			return std
	return c

func get_canonical_player_name(player_name: String) -> String:
	var trimmed = player_name.strip_edges()
	if trimmed.is_empty():
		return "Player 1"
	var registered = get_registered_players()
	for p in registered:
		if p.get("name", "").to_lower() == trimmed.to_lower():
			return str(p.get("name", trimmed))
		if p.get("name", "").replace(" ", "").to_lower() == trimmed.replace(" ", "").to_lower():
			return str(p.get("name", trimmed))
	if trimmed.to_lower() in ["player1", "player 1", "default"]:
		return "Player 1"
	return trimmed

func _find_matching_player_key_in_dict(dict: Dictionary, player_name: String) -> String:
	if dict.has(player_name):
		return player_name
	var canonical = get_canonical_player_name(player_name)
	if dict.has(canonical):
		return canonical
	var p_clean = player_name.replace(" ", "").to_lower()
	var c_clean = canonical.replace(" ", "").to_lower()
	for k in dict.keys():
		var k_str = str(k)
		var k_clean = k_str.replace(" ", "").to_lower()
		if k_clean == p_clean or k_clean == c_clean:
			return k_str
	return ""

func is_club_averages_tracking_enabled() -> bool:
	var gs = _get_global_settings()
	if gs != null and gs.range_settings != null:
		if "track_club_averages" in gs.range_settings:
			return bool(gs.range_settings.track_club_averages.value)
	return true

func set_club_averages_tracking_enabled(enabled: bool) -> void:
	var gs = _get_global_settings()
	if gs != null and gs.range_settings != null:
		if "track_club_averages" in gs.range_settings:
			gs.range_settings.track_club_averages.value = enabled
			gs.save_settings()
	emit_signal("club_averages_tracking_toggled", enabled)

func record_global_shot(player_name: String, club_name: String, raw_shot: Dictionary) -> bool:
	if not is_club_averages_tracking_enabled():
		print("[MultiplayerManager] Club distances and averages tracking is disabled. Skipping record_global_shot for %s (%s)." % [player_name, club_name])
		return false
	if player_name.is_empty() or club_name.is_empty():
		return false
	for p in players:
		if p.get("name", "") == player_name and p.get("is_remote", false):
			return false
	var canonical_name = get_canonical_player_name(player_name)
	var club_code = normalize_club_code(club_name)
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, canonical_name)
	var target_key = matching_key if not matching_key.is_empty() else canonical_name
	if not stats.has(target_key):
		stats[target_key] = {}
	if not stats[target_key].has(club_code):
		stats[target_key][club_code] = []
	if not stats[target_key].has("_records"):
		stats[target_key]["_records"] = {}

	# 1. Check aim distance to determine if this was a partial swing
	var aim_dist_yds := 0.0
	if raw_shot.has("AimDistanceYards") and float(raw_shot["AimDistanceYards"]) > 0.0:
		aim_dist_yds = float(raw_shot["AimDistanceYards"])
	elif raw_shot.has("aim_distance_yards") and float(raw_shot["aim_distance_yards"]) > 0.0:
		aim_dist_yds = float(raw_shot["aim_distance_yards"])
	elif raw_shot.has("TargetDistance") and float(raw_shot["TargetDistance"]) > 0.0:
		aim_dist_yds = float(raw_shot["TargetDistance"]) * 1.09361
	elif raw_shot.has("target_distance") and float(raw_shot["target_distance"]) > 0.0:
		aim_dist_yds = float(raw_shot["target_distance"]) * 1.09361

	if aim_dist_yds <= 0.0 and not players.is_empty():
		var ap = get_active_player()
		if get_canonical_player_name(ap.get("name", "")) == canonical_name:
			var aim_pos = ap.get("last_aim_target_pos", Vector3.ZERO)
			var start_pos = ap.get("last_starting_pos", ap.get("position", Vector3.ZERO))
			if aim_pos != Vector3.ZERO and start_pos != Vector3.ZERO and not aim_pos.is_equal_approx(start_pos):
				aim_dist_yds = start_pos.distance_to(aim_pos) * 1.09361

	if club_code != "Pt" and aim_dist_yds > 0.0:
		var avg_dist_yds = get_player_club_average_distance_yards(target_key, club_code)
		if aim_dist_yds < (avg_dist_yds - 10.0):
			print("[MultiplayerManager] Aiming distance (%.1f yds) is more than 10 yards less than %s average (%.1f yds). Assuming partial swing: skipping club distance/average tracking." % [
				aim_dist_yds, club_code, avg_dist_yds
			])
			return false

	# 2. Check lie resistance / distance reduction penalty
	var reduction: float = float(raw_shot.get("shot_reduction", raw_shot.get("lie_reduction", raw_shot.get("reduction", 0.0))))
	if reduction <= 0.0 and not players.is_empty():
		var ap = get_active_player()
		if get_canonical_player_name(ap.get("name", "")) == canonical_name:
			reduction = float(ap.get("last_shot_reduction", ap.get("shot_reduction", 0.0)))

	var lie_factor := 1.0
	if reduction > 0.0:
		lie_factor = 1.0 - clampf(reduction, 0.0, 0.95)

	var raw_total = float(raw_shot.get("TotalDistance", 0.0))
	var raw_carry = float(raw_shot.get("CarryDistance", 0.0))
	var raw_speed = float(raw_shot.get("BallSpeed", raw_shot.get("Speed", 0.0)))

	var stored_total = raw_total / lie_factor if lie_factor > 0.0 else raw_total
	var stored_carry = raw_carry / lie_factor if lie_factor > 0.0 else raw_carry
	var stored_speed = raw_speed / lie_factor if lie_factor > 0.0 else raw_speed

	if reduction > 0.0:
		print("[MultiplayerManager] Lie resistance adjusted for %s (%s): raw total %.1fyds (reduction %.0f%%) stored as unreduced distance %.1fyds." % [
			target_key, club_code, raw_total * 1.09361, reduction * 100.0, stored_total * 1.09361
		])
		raw_shot["unreduced_total_distance"] = stored_total
		raw_shot["unreduced_carry_distance"] = stored_carry

	var target_dist_m = float(raw_shot.get("TargetDistance", 0.0))
	if target_dist_m <= 0.0 and aim_dist_yds > 0.0:
		target_dist_m = aim_dist_yds / 1.09361

	var shot_id = "%08x%04x" % [int(Time.get_unix_time_from_system()), randi() & 0xffff]
	var shot_t = int(Time.get_unix_time_from_system())
	var shot_src: String = "manual"
	if raw_shot.has("src"):
		shot_src = str(raw_shot["src"])
	elif raw_shot.get("is_launch_monitor", false) or raw_shot.get("from_lm", false):
		shot_src = "lm"
	elif has_node("/root/LaunchMonitorManager") and get_node("/root/LaunchMonitorManager").get("status") == "Connected":
		shot_src = "lm"

	var raw_cs = float(raw_shot.get("ClubSpeed", raw_shot.get("club_speed", 0.0)))
	var raw_sf = float(raw_shot.get("SmashFactor", raw_shot.get("smash_factor", 0.0)))
	if raw_sf <= 0.0 and raw_cs > 0.0 and stored_speed > 0.0:
		raw_sf = stored_speed / raw_cs

	var entry = {
		"id": shot_id,
		"t": shot_t,
		"src": shot_src,
		"CarryDistance": stored_carry,
		"Speed": stored_speed,
		"BallSpeed": stored_speed,
		"ClubSpeed": raw_cs,
		"SmashFactor": raw_sf,
		"TotalSpin": float(raw_shot.get("TotalSpin", raw_shot.get("total_spin", 0.0))),
		"SideDistance": float(raw_shot.get("SideDistance", raw_shot.get("Offline", 0.0))),
		"TargetDistance": target_dist_m,
		"TotalDistance": stored_total,
		"shot_reduction": reduction,
		"raw_total_distance": raw_total,
		"raw_carry_distance": raw_carry
	}
	if aim_dist_yds > 0.0:
		entry["AimDistanceYards"] = aim_dist_yds

	# Spin components
	if raw_shot.has("BackSpin"):
		entry["BackSpin"] = float(raw_shot["BackSpin"])
	elif raw_shot.has("back_spin"):
		entry["BackSpin"] = float(raw_shot["back_spin"])

	if raw_shot.has("SideSpin"):
		entry["SideSpin"] = float(raw_shot["SideSpin"])
	elif raw_shot.has("side_spin"):
		entry["SideSpin"] = float(raw_shot["side_spin"])

	if raw_shot.has("SpinAxis"):
		entry["SpinAxis"] = float(raw_shot["SpinAxis"])
	elif raw_shot.has("spin_axis"):
		entry["SpinAxis"] = float(raw_shot["spin_axis"])

	# Launch Angles
	for vla_k in ["VLA", "VerticalLaunchAngle", "LaunchAngle", "vla"]:
		if raw_shot.has(vla_k) and str(raw_shot[vla_k]) not in ["", "---", "N/A"]:
			entry["VLA"] = float(raw_shot[vla_k])
			break

	for hla_k in ["HLA", "HorizontalLaunchAngle", "hla"]:
		if raw_shot.has(hla_k) and str(raw_shot[hla_k]) not in ["", "---", "N/A"]:
			entry["HLA"] = float(raw_shot[hla_k])
			break

	# Record club delivery telemetry if provided by launch monitor
	var has_fa := false
	var fa_num := 0.0
	for fa_k in ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"]:
		if raw_shot.has(fa_k) and str(raw_shot[fa_k]) not in ["", "---", "N/A"]:
			var fa_str = str(raw_shot[fa_k]).strip_edges()
			var clean_fa = fa_str.replace("O", "").replace("C", "").replace("Sq", "").strip_edges()
			if clean_fa.is_valid_float():
				fa_num = -absf(float(clean_fa)) if fa_str.to_upper().ends_with("C") else float(clean_fa)
				entry["FaceAngle"] = fa_num
				has_fa = true
				break

	var has_cp := false
	var cp_num := 0.0
	for cp_k in ["ClubPath", "Path", "RawClubPath"]:
		if raw_shot.has(cp_k) and str(raw_shot[cp_k]) not in ["", "---", "N/A"]:
			var cp_str = str(raw_shot[cp_k]).strip_edges()
			var clean_cp = cp_str.replace("I-O", "").replace("O-I", "").replace("In-Out", "").replace("Out-In", "").replace("Str", "").strip_edges()
			if clean_cp.is_valid_float():
				var is_oi = ("O-I" in cp_str.to_upper()) or ("OUT-IN" in cp_str.to_upper())
				cp_num = -absf(float(clean_cp)) if is_oi else float(clean_cp)
				entry["ClubPath"] = cp_num
				has_cp = true
				break

	var has_ftp := false
	for ftp_k in ["FaceToPath", "RawFaceToPath"]:
		if raw_shot.has(ftp_k) and str(raw_shot[ftp_k]) not in ["", "---", "N/A"]:
			var ftp_str = str(raw_shot[ftp_k]).strip_edges()
			var clean_ftp = ftp_str.replace("O", "").replace("C", "").replace("Sq", "").strip_edges()
			if clean_ftp.is_valid_float():
				var ftp_num = -absf(float(clean_ftp)) if ftp_str.to_upper().ends_with("C") else float(clean_ftp)
				entry["FaceToPath"] = ftp_num
				has_ftp = true
				break
	if not has_ftp and has_fa and has_cp:
		entry["FaceToPath"] = fa_num - cp_num

	for aoa_k in ["AttackAngle", "AngleOfAttack", "attack_angle", "aoa"]:
		if raw_shot.has(aoa_k) and str(raw_shot[aoa_k]) not in ["", "---", "N/A"]:
			var aoa_clean = str(raw_shot[aoa_k]).strip_edges().replace("+", "").replace("°", "")
			if aoa_clean.is_valid_float():
				entry["AttackAngle"] = float(aoa_clean)
				break

	for dl_k in ["DynamicLoft", "dynamic_loft"]:
		if raw_shot.has(dl_k) and str(raw_shot[dl_k]) not in ["", "---", "N/A"]:
			var dl_clean = str(raw_shot[dl_k]).strip_edges().replace("°", "")
			if dl_clean.is_valid_float():
				entry["DynamicLoft"] = float(dl_clean)
				break

	if raw_shot.has("HorizontalFaceImpact"):
		entry["HorizontalFaceImpact"] = float(raw_shot["HorizontalFaceImpact"])
	elif raw_shot.has("impact_offset_horizontal"):
		entry["HorizontalFaceImpact"] = float(raw_shot["impact_offset_horizontal"])

	if raw_shot.has("VerticalFaceImpact"):
		entry["VerticalFaceImpact"] = float(raw_shot["VerticalFaceImpact"])
	elif raw_shot.has("impact_offset_vertical"):
		entry["VerticalFaceImpact"] = float(raw_shot["impact_offset_vertical"])

	# Trajectory metrics
	for ap_k in ["Apex", "apex", "PeakHeight", "MaxHeight"]:
		if raw_shot.has(ap_k) and str(raw_shot[ap_k]) not in ["", "---", "N/A"]:
			var ap_clean = str(raw_shot[ap_k]).strip_edges().replace("m", "").replace("ft", "")
			if ap_clean.is_valid_float():
				entry["Apex"] = float(ap_clean)
				break
	if not entry.has("Apex") and raw_shot.has("apex_ft"):
		entry["Apex"] = float(raw_shot["apex_ft"]) / 3.28084

	for ht_k in ["HangTime", "hang_time", "flight_time"]:
		if raw_shot.has(ht_k) and str(raw_shot[ht_k]) not in ["", "---", "N/A"]:
			var ht_clean = str(raw_shot[ht_k]).strip_edges().replace("s", "")
			if ht_clean.is_valid_float():
				entry["HangTime"] = float(ht_clean)
				break

	for da_k in ["DescentAngle", "descent_angle", "landing_angle"]:
		if raw_shot.has(da_k) and str(raw_shot[da_k]) not in ["", "---", "N/A"]:
			var da_clean = str(raw_shot[da_k]).strip_edges().replace("°", "")
			if da_clean.is_valid_float():
				entry["DescentAngle"] = float(da_clean)
				break

	if raw_shot.has("Rollout") and str(raw_shot["Rollout"]) not in ["", "---", "N/A"]:
		entry["Rollout"] = float(raw_shot["Rollout"])
	elif stored_total > stored_carry and stored_carry > 0.0:
		entry["Rollout"] = stored_total - stored_carry

	# Preserve any additional scalar telemetry fields passed from launch monitor
	for k in raw_shot.keys():
		var k_str = str(k)
		if k_str in ["tracer_points", "ball_node", "tree", "player_node", "course_shot_data"]:
			continue
		if not entry.has(k_str) and (typeof(raw_shot[k]) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_STRING]):
			entry[k_str] = raw_shot[k]

	# Track longest drive personal record unconditionally, regardless of standard deviation outlier checks
	var shot_total_yds = float(entry.get("TotalDistance", entry.get("CarryDistance", 0.0))) * 1.09361
	if club_code == "Dr" and shot_total_yds > 0.0:
		if shot_src == "lm" or shot_src.is_empty():
			var current_longest = float(stats[target_key]["_records"].get("longest_drive", 0.0))
			if shot_total_yds > current_longest:
				stats[target_key]["_records"]["longest_drive"] = shot_total_yds
	elif club_code == "Pt":
		var was_holed = bool(entry.get("holed", raw_shot.get("holed", raw_shot.get("is_holed", false))))
		if was_holed:
			var shot_putt_ft = shot_total_yds * 3.0
			if shot_putt_ft > 0.0 and shot_putt_ft <= 180.0:
				var current_longest_putt = float(stats[target_key]["_records"].get("longest_putt_ft", 0.0))
				if shot_putt_ft > current_longest_putt:
					stats[target_key]["_records"]["longest_putt_ft"] = shot_putt_ft

	# Exclude outlier shots (extreme duffs or sensor glitches) from standard club averages
	if is_shot_outlier(stats[target_key][club_code], entry, club_code):
		var out_stats = calculate_shots_mean_and_std_dev(stats[target_key][club_code])
		var shot_d = get_shot_distance_m(entry)
		print("[MultiplayerManager] Excluded outlier shot for %s (%s): distance %.1fm (%.1fyds) is outside 2 std dev of existing mean %.1fm (std dev: %.1fm)" % [
			target_key, club_code, shot_d, shot_d * 1.09361, out_stats["mean"], out_stats["effective_std_dev"]
		])
		save_global_club_stats(stats)
		return false

	stats[target_key][club_code].append(entry)
	save_global_club_stats(stats)
	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", target_key)
	return true

func remove_last_global_shot(player_name: String, club_name: String) -> void:
	if player_name.is_empty() or club_name.is_empty():
		return
	var club_code = normalize_club_code(club_name)
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, player_name)
	if not matching_key.is_empty() and stats.has(matching_key) and stats[matching_key].has(club_code):
		if not stats[matching_key][club_code].is_empty():
			stats[matching_key][club_code].pop_back()
			save_global_club_stats(stats)

func clear_player_club_shot_data(player_name: String, club_name: String) -> void:
	if player_name.is_empty() or club_name.is_empty():
		return
	var club_code = normalize_club_code(club_name)
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, player_name)
	var target_key = matching_key if not matching_key.is_empty() else player_name
	if not stats.has(target_key):
		stats[target_key] = {}
	if stats.has(target_key):
		stats[target_key].erase(club_code)
		if club_code == "Dr" and stats[target_key].has("_records"):
			stats[target_key]["_records"].erase("longest_drive")
		if not stats[target_key].has("_tombstones") or typeof(stats[target_key]["_tombstones"]) != TYPE_DICTIONARY:
			stats[target_key]["_tombstones"] = {}
		if not stats[target_key]["_tombstones"].has("cleared_clubs") or typeof(stats[target_key]["_tombstones"]["cleared_clubs"]) != TYPE_DICTIONARY:
			stats[target_key]["_tombstones"]["cleared_clubs"] = {}
		stats[target_key]["_tombstones"]["cleared_clubs"][club_code] = int(Time.get_unix_time_from_system())
		save_global_club_stats(stats)
		if has_node("/root/CloudSync"):
			get_node("/root/CloudSync").call("mark_profile_dirty", target_key)
		print("[MultiplayerManager] Cleared shot data for player: %s, club: %s" % [target_key, club_code])

# --- Dynamic Club Suggestions & Outlier Filtering ---

const DEFAULT_CLUB_DISTANCES: Dictionary = {
	"Dr": 250.0,
	"3w": 225.0,
	"5w": 205.0,
	"2H": 200.0,
	"3H": 190.0,
	"4H": 180.0,
	"1i": 210.0,
	"2i": 200.0,
	"3i": 190.0,
	"4i": 180.0,
	"5i": 170.0,
	"6i": 160.0,
	"7i": 140.0,
	"8i": 130.0,
	"9i": 120.0,
	"Pw": 100.0,
	"Gw": 90.0,
	"Sw": 80.0,
	"Lw": 65.0,
	"Pt": 10.0
}

const DEFAULT_SUGGESTION_CLUBS: Array[String] = [
	"3w", "5w", "4i", "5i", "6i", "7i", "8i", "9i", "Pw", "Sw"
]

const MIN_SHOTS_FOR_AVERAGES: int = 10
const OUTLIER_STD_DEV_THRESHOLD: float = 2.0
const MIN_SHOTS_FOR_OUTLIER_CHECK: int = 5
const MIN_EFFECTIVE_STD_DEV_METERS: float = 15.0
const COLD_START_AUTO_REJECT_PERCENT: float = 0.65

static func get_shot_distance_m(shot_dict: Dictionary) -> float:
	var total_dist = float(shot_dict.get("TotalDistance", 0.0))
	var carry_dist = float(shot_dict.get("CarryDistance", 0.0))
	if total_dist > 0.0:
		return total_dist
	elif carry_dist > 0.0:
		return carry_dist
	return 0.0

static func calculate_shots_median_distance_m(shots: Array) -> float:
	var distances: Array[float] = []
	for s in shots:
		if typeof(s) == TYPE_DICTIONARY:
			var d = get_shot_distance_m(s)
			if d > 0.0:
				distances.append(d)
	if distances.is_empty():
		return 0.0
	distances.sort()
	var n = distances.size()
	if n % 2 == 1:
		return distances[n / 2]
	else:
		return (distances[(n / 2) - 1] + distances[n / 2]) * 0.5

static func calculate_shots_mean_and_std_dev(shots: Array) -> Dictionary:
	if shots.size() < MIN_SHOTS_FOR_OUTLIER_CHECK:
		return {"mean": 0.0, "std_dev": 0.0, "effective_std_dev": 0.0, "count": shots.size()}
	
	var distances: Array[float] = []
	var sum_dist := 0.0
	for s in shots:
		if typeof(s) == TYPE_DICTIONARY:
			var d = get_shot_distance_m(s)
			distances.append(d)
			sum_dist += d
			
	var count = distances.size()
	if count < MIN_SHOTS_FOR_OUTLIER_CHECK:
		return {"mean": 0.0, "std_dev": 0.0, "effective_std_dev": 0.0, "count": count}
		
	var mean = sum_dist / float(count)
	var sum_sq_diff := 0.0
	for d in distances:
		var diff = d - mean
		sum_sq_diff += diff * diff
		
	var std_dev = sqrt(sum_sq_diff / float(count))
	var effective_std = maxf(std_dev, MIN_EFFECTIVE_STD_DEV_METERS)
	return {
		"mean": mean,
		"std_dev": std_dev,
		"effective_std_dev": effective_std,
		"count": count
	}

static func calculate_shots_median_and_mad(shots: Array) -> Dictionary:
	var distances: Array[float] = []
	for s in shots:
		if typeof(s) == TYPE_DICTIONARY:
			var d = get_shot_distance_m(s)
			if d > 0.0:
				distances.append(d)
	var count = distances.size()
	if count < MIN_SHOTS_FOR_OUTLIER_CHECK:
		return {"median": 0.0, "mad": 0.0, "effective_std_dev": 0.0, "count": count}
	
	distances.sort()
	var median: float = distances[count / 2] if count % 2 == 1 else (distances[(count / 2) - 1] + distances[count / 2]) * 0.5
	var dev_list: Array[float] = []
	for d in distances:
		dev_list.append(absf(d - median))
	dev_list.sort()
	var mad: float = dev_list[count / 2] if count % 2 == 1 else (dev_list[(count / 2) - 1] + dev_list[count / 2]) * 0.5
	var effective_std = maxf(1.4826 * mad, MIN_EFFECTIVE_STD_DEV_METERS)
	return {
		"median": median,
		"mad": mad,
		"effective_std_dev": effective_std,
		"count": count
	}

static func filter_valid_club_shots(shots: Array, club_name: String) -> Array:
	if shots.is_empty():
		return []
	var club_code = normalize_club_code(club_name)
	if club_code == "Pt":
		return shots

	var benchmark_yds = float(DEFAULT_CLUB_DISTANCES.get(club_code, 100.0))
	var initial_valid: Array = []
	var initial_distances: Array[float] = []
	
	for s in shots:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if s.get("is_mishit", false) or s.get("excluded_from_averages", false):
			continue
		var d = get_shot_distance_m(s)
		if d > 0.0:
			initial_valid.append(s)
			initial_distances.append(d)

	if initial_valid.is_empty():
		return shots

	initial_distances.sort()
	var n = initial_distances.size()
	var med_m = initial_distances[n / 2] if n % 2 == 1 else (initial_distances[(n / 2) - 1] + initial_distances[n / 2]) * 0.5
	var med_yds = med_m * 1.09361
	if med_yds > 0.0:
		benchmark_yds = maxf(benchmark_yds * 0.70, med_yds)

	var min_allowed_yds = benchmark_yds * COLD_START_AUTO_REJECT_PERCENT
	var min_allowed_m = min_allowed_yds / 1.09361
	var max_allowed_yds = maxf(benchmark_yds * 1.75, 380.0)
	var max_allowed_m = max_allowed_yds / 1.09361

	var passed_shots: Array = []
	for s in initial_valid:
		var d = get_shot_distance_m(s)
		if d >= min_allowed_m and d <= max_allowed_m:
			passed_shots.append(s)

	if passed_shots.is_empty():
		return initial_valid

	if passed_shots.size() >= MIN_SHOTS_FOR_OUTLIER_CHECK:
		var mad_stats = calculate_shots_median_and_mad(passed_shots)
		var refined_shots: Array = []
		var med = mad_stats["median"]
		var threshold = OUTLIER_STD_DEV_THRESHOLD * mad_stats["effective_std_dev"]
		for s in passed_shots:
			var d = get_shot_distance_m(s)
			if absf(d - med) <= threshold:
				refined_shots.append(s)
		if not refined_shots.is_empty():
			return refined_shots

	return passed_shots

static func is_shot_outlier(existing_shots: Array, new_shot: Dictionary, club_name: String = "") -> bool:
	var new_d = get_shot_distance_m(new_shot)
	var new_d_yds = new_d * 1.09361

	# Rule 1: Benchmark Cold-Start / Miss-hit check (65% floor) when club is provided
	if not club_name.is_empty():
		var club_code = normalize_club_code(club_name)
		if club_code != "Pt":
			var benchmark_yds = float(DEFAULT_CLUB_DISTANCES.get(club_code, 100.0))
			if not existing_shots.is_empty():
				var ex_median_m = calculate_shots_median_distance_m(existing_shots)
				if ex_median_m > 0.0:
					var ex_median_yds = ex_median_m * 1.09361
					benchmark_yds = maxf(benchmark_yds * 0.70, ex_median_yds)
			
			var min_allowed_yds = benchmark_yds * COLD_START_AUTO_REJECT_PERCENT
			if new_d_yds < min_allowed_yds:
				return true
				
			var max_allowed_yds = maxf(benchmark_yds * 1.70, 380.0)
			if new_d_yds > max_allowed_yds:
				return true

	# Rule 2: Robust statistical check (Median + MAD) for sufficient samples
	if existing_shots.size() < MIN_SHOTS_FOR_OUTLIER_CHECK:
		return false
	var stats = calculate_shots_median_and_mad(existing_shots)
	if stats["count"] < MIN_SHOTS_FOR_OUTLIER_CHECK:
		return false
	var diff = absf(new_d - stats["median"])
	return diff > (OUTLIER_STD_DEV_THRESHOLD * stats["effective_std_dev"])

func get_player_club_average_distance_yards(player_name: String, club_name: String) -> float:
	var canonical_name = get_canonical_player_name(player_name)
	var club_code = normalize_club_code(club_name)
	var default_dist = float(DEFAULT_CLUB_DISTANCES.get(club_code, 100.0))
	if player_name.is_empty() or club_name.is_empty():
		return default_dist

	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, canonical_name)
	var target_key = matching_key if not matching_key.is_empty() else canonical_name
	if not stats.has(target_key):
		return default_dist

	var raw_shots: Array = []
	if stats[target_key].has(club_code):
		raw_shots = stats[target_key][club_code]
	elif stats[target_key].has(club_name):
		raw_shots = stats[target_key][club_name]

	var shots: Array = filter_valid_club_shots(raw_shots, club_code)
	var sum_dist := 0.0
	var count := 0
	for s in shots:
		if typeof(s) == TYPE_DICTIONARY:
			var d = get_shot_distance_m(s)
			if d > 0.0:
				sum_dist += d
				count += 1
	if count > 0:
		return (sum_dist / float(count)) * 1.09361
	return default_dist

func get_club_effective_distance(player_name: String, club_name: String) -> float:
	var club_code = normalize_club_code(club_name)
	var default_dist = float(DEFAULT_CLUB_DISTANCES.get(club_code, DEFAULT_CLUB_DISTANCES.get(club_name, 100.0)))
	if player_name.is_empty() or club_name.is_empty():
		return default_dist
		
	var player_stats = get_player_club_stats(player_name)
	var raw_shots: Array = player_stats.get(club_code, player_stats.get(club_name, []))
	var shots: Array = filter_valid_club_shots(raw_shots, club_code)
	if shots.size() < MIN_SHOTS_FOR_AVERAGES:
		return default_dist
		
	var sum_dist := 0.0
	var count := 0
	for s in shots:
		if typeof(s) == TYPE_DICTIONARY:
			var d = get_shot_distance_m(s)
			if d > 0.0:
				sum_dist += d
				count += 1
	if count >= MIN_SHOTS_FOR_AVERAGES:
		var avg_m = sum_dist / float(count)
		return avg_m * 1.09361
	return default_dist

func get_suggested_club(player_name: String, dist_yards: float, is_in_teebox: bool = false, is_on_green: bool = false, is_fringe: bool = false) -> String:
	var bag = get_player_bag(player_name)
	var has_custom_bag = not bag.is_empty()

	# Rule 1: Green & Fringe check - select putter when on green or on fringe near the green
	if is_on_green or (is_fringe and dist_yards <= 35.0):
		if not has_custom_bag or bag.has("Pt"):
			return "Pt"
		# If putter not in bag, pick shortest wedge/club in bag
		for short_c in ["Lw", "Sw", "Gw", "Pw"]:
			if bag.has(short_c):
				return short_c
		return bag.back() if not bag.is_empty() else "Pt"
	
	# Rule 2: Teebox driver check
	if is_in_teebox and dist_yards > 200.0:
		if not has_custom_bag or bag.has("Dr"):
			return "Dr"
		# If driver not in bag, pick longest available wood/club in bag
		for long_c in ["3w", "5w", "2H", "3H", "1i", "2i", "3i", "4i"]:
			if bag.has(long_c):
				return long_c
		return bag.front() if not bag.is_empty() else "Dr"
		
	# Rule 3: Select based on distance (never driver, never putter when off green)
	# Build candidate pool: start with default suggestion clubs
	var candidates: Array[String] = []
	for c in DEFAULT_SUGGESTION_CLUBS:
		if not candidates.has(c):
			candidates.append(c)
			
	# Also include any club the player has at least 10 shots with (e.g. 3H, 4H, Gw, Lw)
	if not player_name.is_empty():
		var player_stats = get_player_club_stats(player_name)
		for c in player_stats.keys():
			var c_str = str(c)
			if c_str == "Dr" or c_str == "Pt":
				continue
			var shots: Array = player_stats[c]
			if shots.size() >= MIN_SHOTS_FOR_AVERAGES and not candidates.has(c_str):
				candidates.append(c_str)

	# Filter candidate pool if custom bag is set
	if has_custom_bag:
		var filtered_candidates: Array[String] = []
		for c in candidates:
			if bag.has(c):
				filtered_candidates.append(c)
		# Ensure any bag clubs (excluding Dr and Pt unless those are the only ones) are available as candidates
		for c in bag:
			if c != "Dr" and c != "Pt" and not filtered_candidates.has(c):
				filtered_candidates.append(c)
		if filtered_candidates.is_empty():
			filtered_candidates = bag.duplicate()
		candidates = filtered_candidates
				
	# Find candidate whose effective distance is closest to dist_yards
	var best_club: String = candidates[0] if not candidates.is_empty() else "Sw"
	var best_diff: float = 999999.0
	var best_eff_dist: float = -1.0
	
	for club in candidates:
		var eff_dist = get_club_effective_distance(player_name, club)
		var diff = absf(eff_dist - dist_yards)
		if diff < best_diff or (is_equal_approx(diff, best_diff) and eff_dist > best_eff_dist):
			best_diff = diff
			best_club = club
			best_eff_dist = eff_dist
			
	return best_club

const STANDARD_CLUBS: Array[String] = [
	"Dr", "3w", "5w", "2H", "3H", "4H", "1i", "2i", "3i", "4i",
	"5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw", "Pt"
]

const CLUB_FULL_NAMES: Dictionary = {
	"Dr": "Driver",
	"3w": "3 Wood",
	"5w": "5 Wood",
	"2H": "2 Hybrid",
	"3H": "3 Hybrid",
	"4H": "4 Hybrid",
	"1i": "1 Iron",
	"2i": "2 Iron",
	"3i": "3 Iron",
	"4i": "4 Iron",
	"5i": "5 Iron",
	"6i": "6 Iron",
	"7i": "7 Iron",
	"8i": "8 Iron",
	"9i": "9 Iron",
	"Pw": "Pitching Wedge",
	"Gw": "Gap Wedge",
	"Sw": "Sand Wedge",
	"Lw": "Lob Wedge",
	"Pt": "Putter"
}

static func get_club_display_name(club_code: String) -> String:
	if CLUB_FULL_NAMES.has(club_code):
		return "%s (%s)" % [CLUB_FULL_NAMES[club_code], club_code]
	return club_code

func get_player_club_stats(player_name: String) -> Dictionary:
	var stats = load_global_club_stats()
	var matching_key = _find_matching_player_key_in_dict(stats, player_name)
	var p_stats = stats.get(matching_key, {}) if not matching_key.is_empty() else {}
	var result = {}
	if typeof(p_stats) == TYPE_DICTIONARY:
		for k in p_stats.keys():
			if not str(k).begins_with("_") and typeof(p_stats[k]) == TYPE_ARRAY:
				result[k] = p_stats[k]
	return result

func calculate_player_club_averages(player_name: String) -> Dictionary:
	var result = {}
	var player_club_stats = get_player_club_stats(player_name)
	
	var clubs_to_eval = STANDARD_CLUBS.duplicate()
	for c in player_club_stats.keys():
		if not clubs_to_eval.has(c):
			clubs_to_eval.append(c)
			
	for club in clubs_to_eval:
		var raw_shots: Array = player_club_stats.get(club, [])
		var shots: Array = filter_valid_club_shots(raw_shots, club)
		var shot_count = shots.size()
		var raw_shot_count = raw_shots.size()
		var mishits_excluded = max(0, raw_shot_count - shot_count)
		if shot_count == 0:
			var p_hand_empty = get_player_handedness(player_name)
			result[club] = {
				"club": club,
				"player": player_name,
				"handedness": p_hand_empty,
				"is_lefty": p_hand_empty == 1,
				"display_name": get_club_display_name(club),
				"shot_count": 0,
				"raw_shot_count": raw_shot_count,
				"mishits_excluded": mishits_excluded,
				"avg_carry_m": 0.0,
				"avg_total_m": 0.0,
				"avg_speed_mph": 0.0,
				"avg_spin_rpm": 0.0,
				"avg_offline_m": 0.0,
				"avg_target_diff_m": 0.0,
				"avg_face_angle": 0.0,
				"has_face_angle": false,
				"face_angle_count": 0,
				"avg_club_path": 0.0,
				"has_club_path": false,
				"club_path_count": 0,
				"avg_face_to_path": 0.0,
				"has_face_to_path": false,
				"face_to_path_count": 0,
				"avg_club_speed_mph": 0.0,
				"has_club_speed": false,
				"club_speed_count": 0,
				"avg_smash_factor": 0.0,
				"has_smash_factor": false,
				"smash_factor_count": 0,
				"avg_vla_deg": 0.0,
				"has_vla": false,
				"vla_count": 0,
				"avg_hla_deg": 0.0,
				"has_hla": false,
				"hla_count": 0,
				"avg_back_spin_rpm": 0.0,
				"has_back_spin": false,
				"back_spin_count": 0,
				"avg_side_spin_rpm": 0.0,
				"has_side_spin": false,
				"side_spin_count": 0,
				"avg_spin_axis_deg": 0.0,
				"has_spin_axis": false,
				"spin_axis_count": 0,
				"avg_attack_angle": 0.0,
				"has_attack_angle": false,
				"attack_angle_count": 0,
				"avg_dynamic_loft": 0.0,
				"has_dynamic_loft": false,
				"dynamic_loft_count": 0,
				"avg_apex_m": 0.0,
				"has_apex": false,
				"apex_count": 0,
				"avg_hang_time_s": 0.0,
				"has_hang_time": false,
				"hang_time_count": 0,
				"avg_descent_angle_deg": 0.0,
				"has_descent_angle": false,
				"descent_angle_count": 0,
				"avg_rollout_m": 0.0,
				"has_rollout": false,
				"rollout_count": 0,
				"impact_points": [],
				"has_impact_data": false,
				"has_data": false,
				"shots": []
			}
			continue
			
		var sum_carry := 0.0
		var sum_total := 0.0
		var sum_speed := 0.0
		var sum_spin := 0.0
		var sum_offline := 0.0
		var sum_target_diff := 0.0
		var valid_target_diff_count := 0
		var sum_face_angle := 0.0
		var valid_face_count := 0
		var sum_club_path := 0.0
		var valid_path_count := 0
		var sum_face_to_path := 0.0
		var valid_face_to_path_count := 0
		var sum_club_speed := 0.0
		var valid_club_speed_count := 0
		var sum_smash := 0.0
		var valid_smash_count := 0
		var sum_vla := 0.0
		var valid_vla_count := 0
		var sum_hla := 0.0
		var valid_hla_count := 0
		var sum_back_spin := 0.0
		var valid_back_spin_count := 0
		var sum_side_spin := 0.0
		var valid_side_spin_count := 0
		var sum_spin_axis := 0.0
		var valid_spin_axis_count := 0
		var sum_attack_angle := 0.0
		var valid_attack_angle_count := 0
		var sum_dynamic_loft := 0.0
		var valid_dynamic_loft_count := 0
		var sum_apex := 0.0
		var valid_apex_count := 0
		var sum_hang_time := 0.0
		var valid_hang_time_count := 0
		var sum_descent_angle := 0.0
		var valid_descent_angle_count := 0
		var sum_rollout := 0.0
		var valid_rollout_count := 0
		var impact_points: Array = []
		
		for shot in shots:
			var carry_dist = float(shot.get("CarryDistance", 0.0))
			var total_dist = float(shot.get("TotalDistance", 0.0))
			if total_dist <= 0.0:
				total_dist = carry_dist
			if carry_dist <= 0.0:
				carry_dist = total_dist
				
			sum_carry += carry_dist
			sum_total += total_dist
			sum_speed += float(shot.get("Speed", 0.0))
			sum_spin += float(shot.get("TotalSpin", 0.0))
			
			var s_dist = absf(float(shot.get("SideDistance", 0.0)))
			if s_dist > 100.0 or (total_dist > 15.0 and s_dist > total_dist * 1.2):
				s_dist = 0.0
			sum_offline += s_dist
			
			var target_dist = float(shot.get("TargetDistance", 0.0))
			if target_dist > 0.0:
				sum_target_diff += (total_dist - target_dist)
				valid_target_diff_count += 1

			# Club Delivery & Path
			var cur_fa_found := false
			var cur_fa := 0.0
			for fa_k in ["FaceAngle", "ClubFaceAngle", "FaceToTarget", "RawFaceAngle"]:
				if shot.has(fa_k) and str(shot[fa_k]) not in ["", "---", "N/A"]:
					var fa_clean = str(shot[fa_k]).replace("O", "").replace("C", "").replace("Sq", "").strip_edges()
					if fa_clean.is_valid_float():
						cur_fa = -absf(float(fa_clean)) if str(shot[fa_k]).to_upper().ends_with("C") else float(fa_clean)
						cur_fa_found = true
						break
			if cur_fa_found:
				sum_face_angle += cur_fa
				valid_face_count += 1

			var cur_cp_found := false
			var cur_cp := 0.0
			for cp_k in ["ClubPath", "Path", "RawClubPath"]:
				if shot.has(cp_k) and str(shot[cp_k]) not in ["", "---", "N/A"]:
					var cp_clean = str(shot[cp_k]).replace("I-O", "").replace("O-I", "").replace("In-Out", "").replace("Out-In", "").replace("Str", "").strip_edges()
					if cp_clean.is_valid_float():
						var is_oi = ("O-I" in str(shot[cp_k]).to_upper()) or ("OUT-IN" in str(shot[cp_k]).to_upper())
						cur_cp = -absf(float(cp_clean)) if is_oi else float(cp_clean)
						cur_cp_found = true
						break
			if cur_cp_found:
				sum_club_path += cur_cp
				valid_path_count += 1

			var cur_ftp_found := false
			var cur_ftp := 0.0
			for ftp_k in ["FaceToPath", "RawFaceToPath"]:
				if shot.has(ftp_k) and str(shot[ftp_k]) not in ["", "---", "N/A"]:
					var ftp_clean = str(shot[ftp_k]).replace("O", "").replace("C", "").replace("Sq", "").strip_edges()
					if ftp_clean.is_valid_float():
						cur_ftp = -absf(float(ftp_clean)) if str(shot[ftp_k]).to_upper().ends_with("C") else float(ftp_clean)
						cur_ftp_found = true
						break
			if not cur_ftp_found and cur_fa_found and cur_cp_found:
				cur_ftp = cur_fa - cur_cp
				cur_ftp_found = true
			if cur_ftp_found:
				sum_face_to_path += cur_ftp
				valid_face_to_path_count += 1

			# Clubhead speed & Smash Factor
			var cur_cs := 0.0
			for cs_k in ["ClubSpeed", "club_speed"]:
				if shot.has(cs_k) and float(shot[cs_k]) > 0.01:
					cur_cs = float(shot[cs_k])
					break
			if cur_cs > 0.0:
				sum_club_speed += cur_cs
				valid_club_speed_count += 1

			var cur_sf := 0.0
			for sf_k in ["SmashFactor", "smash_factor"]:
				if shot.has(sf_k) and float(shot[sf_k]) > 0.05:
					cur_sf = float(shot[sf_k])
					break
			if cur_sf <= 0.0 and cur_cs > 0.0 and float(shot.get("Speed", shot.get("BallSpeed", 0.0))) > 0.0:
				cur_sf = float(shot.get("Speed", shot.get("BallSpeed", 0.0))) / cur_cs
			if cur_sf > 0.05:
				sum_smash += cur_sf
				valid_smash_count += 1

			# Launch Angles
			for vla_k in ["VLA", "VerticalLaunchAngle", "LaunchAngle", "vla"]:
				if shot.has(vla_k) and str(shot[vla_k]) not in ["", "---", "N/A"]:
					var vla_clean = str(shot[vla_k]).strip_edges().replace("°", "")
					if vla_clean.is_valid_float():
						sum_vla += float(vla_clean)
						valid_vla_count += 1
						break

			for hla_k in ["HLA", "HorizontalLaunchAngle", "hla"]:
				if shot.has(hla_k) and str(shot[hla_k]) not in ["", "---", "N/A"]:
					var hla_clean = str(shot[hla_k]).strip_edges().replace("°", "")
					if hla_clean.is_valid_float():
						sum_hla += float(hla_clean)
						valid_hla_count += 1
						break

			# Spin breakdowns
			for bs_k in ["BackSpin", "back_spin", "backspin"]:
				if shot.has(bs_k) and str(shot[bs_k]) not in ["", "---", "N/A"]:
					var bs_clean = str(shot[bs_k]).strip_edges().replace("rpm", "")
					if bs_clean.is_valid_float() and float(bs_clean) > 0.0:
						sum_back_spin += float(bs_clean)
						valid_back_spin_count += 1
						break

			for ss_k in ["SideSpin", "side_spin", "sidespin"]:
				if shot.has(ss_k) and str(shot[ss_k]) not in ["", "---", "N/A"]:
					var ss_clean = str(shot[ss_k]).strip_edges().replace("rpm", "")
					if ss_clean.is_valid_float():
						sum_side_spin += float(ss_clean)
						valid_side_spin_count += 1
						break

			for sa_k in ["SpinAxis", "spin_axis"]:
				if shot.has(sa_k) and str(shot[sa_k]) not in ["", "---", "N/A"]:
					var sa_clean = str(shot[sa_k]).strip_edges().replace("°", "")
					if sa_clean.is_valid_float():
						sum_spin_axis += float(sa_clean)
						valid_spin_axis_count += 1
						break

			# Attack Angle & Dynamic Loft
			for aoa_k in ["AttackAngle", "AngleOfAttack", "attack_angle", "aoa"]:
				if shot.has(aoa_k) and str(shot[aoa_k]) not in ["", "---", "N/A"]:
					var aoa_clean = str(shot[aoa_k]).strip_edges().replace("+", "").replace("°", "")
					if aoa_clean.is_valid_float():
						sum_attack_angle += float(aoa_clean)
						valid_attack_angle_count += 1
						break

			for dl_k in ["DynamicLoft", "dynamic_loft"]:
				if shot.has(dl_k) and str(shot[dl_k]) not in ["", "---", "N/A"]:
					var dl_clean = str(shot[dl_k]).strip_edges().replace("°", "")
					if dl_clean.is_valid_float() and float(dl_clean) > 0.0:
						sum_dynamic_loft += float(dl_clean)
						valid_dynamic_loft_count += 1
						break

			# Flight / Trajectory
			var shot_apex_found := false
			for ap_k in ["Apex", "apex", "PeakHeight", "MaxHeight"]:
				if shot.has(ap_k) and str(shot[ap_k]) not in ["", "---", "N/A"]:
					var ap_clean = str(shot[ap_k]).strip_edges().replace("m", "").replace("ft", "")
					if ap_clean.is_valid_float() and float(ap_clean) > 0.0:
						sum_apex += float(ap_clean)
						valid_apex_count += 1
						shot_apex_found = true
						break
			if not shot_apex_found and shot.has("apex_ft") and float(shot["apex_ft"]) > 0.0:
				sum_apex += float(shot["apex_ft"]) / 3.28084
				valid_apex_count += 1

			for ht_k in ["HangTime", "hang_time", "flight_time"]:
				if shot.has(ht_k) and str(shot[ht_k]) not in ["", "---", "N/A"]:
					var ht_clean = str(shot[ht_k]).strip_edges().replace("s", "")
					if ht_clean.is_valid_float() and float(ht_clean) > 0.0:
						sum_hang_time += float(ht_clean)
						valid_hang_time_count += 1
						break

			for da_k in ["DescentAngle", "descent_angle", "landing_angle"]:
				if shot.has(da_k) and str(shot[da_k]) not in ["", "---", "N/A"]:
					var da_clean = str(shot[da_k]).strip_edges().replace("°", "")
					if da_clean.is_valid_float() and float(da_clean) > 0.0:
						sum_descent_angle += float(da_clean)
						valid_descent_angle_count += 1
						break

			var shot_ro_found := false
			for ro_k in ["Rollout", "rollout"]:
				if shot.has(ro_k) and str(shot[ro_k]) not in ["", "---", "N/A"]:
					var ro_clean = str(shot[ro_k]).strip_edges().replace("yd", "").replace("m", "")
					if ro_clean.is_valid_float() and float(ro_clean) >= 0.0:
						sum_rollout += float(ro_clean)
						valid_rollout_count += 1
						shot_ro_found = true
						break
			if not shot_ro_found and total_dist > carry_dist and carry_dist > 0.0:
				sum_rollout += (total_dist - carry_dist)
				valid_rollout_count += 1

			if shot.has("HorizontalFaceImpact") or shot.has("VerticalFaceImpact"):
				impact_points.append({
					"h": float(shot.get("HorizontalFaceImpact", 0.0)),
					"v": float(shot.get("VerticalFaceImpact", 0.0))
				})
				
		var cnt = float(shot_count)
		var p_hand = get_player_handedness(player_name)
		result[club] = {
			"club": club,
			"player": player_name,
			"handedness": p_hand,
			"is_lefty": p_hand == 1,
			"display_name": get_club_display_name(club),
			"shot_count": shot_count,
			"raw_shot_count": raw_shot_count,
			"mishits_excluded": mishits_excluded,
			"avg_carry_m": sum_carry / cnt,
			"avg_total_m": sum_total / cnt,
			"avg_speed_mph": sum_speed / cnt,
			"avg_spin_rpm": sum_spin / cnt,
			"avg_offline_m": sum_offline / cnt,
			"avg_target_diff_m": (sum_target_diff / valid_target_diff_count) if valid_target_diff_count > 0 else 0.0,
			"avg_face_angle": (sum_face_angle / valid_face_count) if valid_face_count > 0 else 0.0,
			"has_face_angle": valid_face_count > 0,
			"face_angle_count": valid_face_count,
			"avg_club_path": (sum_club_path / valid_path_count) if valid_path_count > 0 else 0.0,
			"has_club_path": valid_path_count > 0,
			"club_path_count": valid_path_count,
			"avg_face_to_path": (sum_face_to_path / valid_face_to_path_count) if valid_face_to_path_count > 0 else 0.0,
			"has_face_to_path": valid_face_to_path_count > 0,
			"face_to_path_count": valid_face_to_path_count,
			"avg_club_speed_mph": (sum_club_speed / valid_club_speed_count) if valid_club_speed_count > 0 else 0.0,
			"has_club_speed": valid_club_speed_count > 0,
			"club_speed_count": valid_club_speed_count,
			"avg_smash_factor": (sum_smash / valid_smash_count) if valid_smash_count > 0 else 0.0,
			"has_smash_factor": valid_smash_count > 0,
			"smash_factor_count": valid_smash_count,
			"avg_vla_deg": (sum_vla / valid_vla_count) if valid_vla_count > 0 else 0.0,
			"has_vla": valid_vla_count > 0,
			"vla_count": valid_vla_count,
			"avg_hla_deg": (sum_hla / valid_hla_count) if valid_hla_count > 0 else 0.0,
			"has_hla": valid_hla_count > 0,
			"hla_count": valid_hla_count,
			"avg_back_spin_rpm": (sum_back_spin / valid_back_spin_count) if valid_back_spin_count > 0 else 0.0,
			"has_back_spin": valid_back_spin_count > 0,
			"back_spin_count": valid_back_spin_count,
			"avg_side_spin_rpm": (sum_side_spin / valid_side_spin_count) if valid_side_spin_count > 0 else 0.0,
			"has_side_spin": valid_side_spin_count > 0,
			"side_spin_count": valid_side_spin_count,
			"avg_spin_axis_deg": (sum_spin_axis / valid_spin_axis_count) if valid_spin_axis_count > 0 else 0.0,
			"has_spin_axis": valid_spin_axis_count > 0,
			"spin_axis_count": valid_spin_axis_count,
			"avg_attack_angle": (sum_attack_angle / valid_attack_angle_count) if valid_attack_angle_count > 0 else 0.0,
			"has_attack_angle": valid_attack_angle_count > 0,
			"attack_angle_count": valid_attack_angle_count,
			"avg_dynamic_loft": (sum_dynamic_loft / valid_dynamic_loft_count) if valid_dynamic_loft_count > 0 else 0.0,
			"has_dynamic_loft": valid_dynamic_loft_count > 0,
			"dynamic_loft_count": valid_dynamic_loft_count,
			"avg_apex_m": (sum_apex / valid_apex_count) if valid_apex_count > 0 else 0.0,
			"has_apex": valid_apex_count > 0,
			"apex_count": valid_apex_count,
			"avg_hang_time_s": (sum_hang_time / valid_hang_time_count) if valid_hang_time_count > 0 else 0.0,
			"has_hang_time": valid_hang_time_count > 0,
			"hang_time_count": valid_hang_time_count,
			"avg_descent_angle_deg": (sum_descent_angle / valid_descent_angle_count) if valid_descent_angle_count > 0 else 0.0,
			"has_descent_angle": valid_descent_angle_count > 0,
			"descent_angle_count": valid_descent_angle_count,
			"avg_rollout_m": (sum_rollout / valid_rollout_count) if valid_rollout_count > 0 else 0.0,
			"has_rollout": valid_rollout_count > 0,
			"rollout_count": valid_rollout_count,
			"impact_points": impact_points,
			"has_impact_data": not impact_points.is_empty(),
			"has_data": true,
			"shots": shots
		}
		
	return result

func format_player_club_stats_summary(player_name: String) -> String:
	var avgs = calculate_player_club_averages(player_name)
	var has_any := false
	for clb in avgs:
		if avgs[clb]["has_data"]:
			has_any = true
			break
	if not has_any:
		return "No club shot history recorded yet.\n"
		
	var out = "PLAYER CLUB STATISTICS (HISTORICAL AVERAGES):\n"
	out += "========================================================================================\n"
	out += "%-16s | %-6s | %-12s | %-12s | %-10s | %-9s | %-12s\n" % ["Club", "Shots", "Avg Total", "Avg Carry", "Avg Speed", "Avg Spin", "Avg Offline"]
	out += "----------------------------------------------------------------------------------------\n"
	
	for clb in avgs:
		var c_data = avgs[clb]
		if not c_data["has_data"]:
			continue
		var total_yds = c_data["avg_total_m"] * 1.09361
		var carry_yds = c_data["avg_carry_m"] * 1.09361
		var offline_yds = c_data["avg_offline_m"] * 1.09361
		out += "%-16s | %-6d | %-9.1f yds | %-9.1f yds | %-6.1f mph | %-5.0f rpm | %-9.1f yds\n" % [
			c_data["display_name"],
			c_data["shot_count"],
			total_yds,
			carry_yds,
			c_data["avg_speed_mph"],
			c_data["avg_spin_rpm"],
			offline_yds
		]
	out += "========================================================================================\n\n"
	return out

func calculate_player_stats(player_name: String) -> Dictionary:
	var stats = {
		"matches_played": 0,
		"wins": 0,
		"losses": 0,
		"ties": 0,
		"single_player_completed": 0,
		"avg_to_par": 0.0,
		"avg_to_par_valid": false,
		"best_courses": {},
		"longest_drive": 0.0,
		"longest_putt_ft": 0.0
	}
	
	var dir_path = "user://match_history"
	if DirAccess.dir_exists_absolute(dir_path):
		var dir = DirAccess.open(dir_path)
		if dir != null:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			var total_diff_sum = 0.0
			var par_diff_matches_count = 0
			
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					var full_path = dir_path.path_join(file_name)
					var f = FileAccess.open(full_path, FileAccess.READ)
					if f != null:
						var json_text = f.get_as_text()
						var json_parser = JSON.new()
						if json_text.strip_edges() != "" and json_parser.parse(json_text) == OK:
							var json = json_parser.data
							if typeof(json) == TYPE_DICTIONARY and json.get("is_finished", false):
								var is_practice = json.get("practice_mode_active", false)
								if not is_practice:
									var players_list = json.get("players", [])
									var target_player = null
									var active_players = []
									for p in players_list:
										if typeof(p) == TYPE_DICTIONARY and p.get("active", true):
											active_players.append(p)
											if not p.get("is_remote", false) and p.get("name", "").to_lower() == player_name.to_lower():
												target_player = p
												
									if target_player != null:
										stats["matches_played"] += 1
										if active_players.size() > 1:
											var match_mode = json.get("game_mode", "Standard")
											if match_mode == "Closest to Pin":
												var max_pts = -1
												var max_players = []
												for p in active_players:
													var pts = 0
													var h_scores = p.get("hole_scores", {})
													for h_id in h_scores:
														if h_scores[h_id] != null:
															pts += int(h_scores[h_id])
													if pts > max_pts:
														max_pts = pts
														max_players = [p]
													elif pts == max_pts:
														max_players.append(p)
														
												var my_pts = 0
												var my_scores = target_player.get("hole_scores", {})
												for h_id in my_scores:
													if my_scores[h_id] != null:
														my_pts += int(my_scores[h_id])
														
												if my_pts == max_pts and max_pts > 0:
													if max_players.size() == 1:
														stats["wins"] += 1
													else:
														stats["ties"] += 1
												else:
													stats["losses"] += 1
											else:
												var min_score = 99999
												var min_players = []
												for p in active_players:
													var score = int(p.get("total_strokes", 0))
													if score < min_score:
														min_score = score
														min_players = [p]
													elif score == min_score:
														min_players.append(p)
														
												var my_score = int(target_player.get("total_strokes", 0))
												if my_score == min_score:
													if min_players.size() == 1:
														stats["wins"] += 1
													else:
														stats["ties"] += 1
												else:
													stats["losses"] += 1
										else:
											stats["single_player_completed"] += 1
											
										var hole_pars = json.get("hole_pars", {})
										if typeof(hole_pars) != TYPE_DICTIONARY or hole_pars.is_empty():
											hole_pars = {}
											var config_p = json.get("config_path", "")
											if not config_p.is_empty() and FileAccess.file_exists(config_p):
												var cfg_file = FileAccess.open(config_p, FileAccess.READ)
												if cfg_file != null:
													var cfg_json = JSON.parse_string(cfg_file.get_as_text())
													if typeof(cfg_json) == TYPE_DICTIONARY:
														var h_info = cfg_json.get("Hole Info", {})
														for h_id in h_info:
															hole_pars[h_id] = int(round(float(h_info[h_id].get("Par", 4))))
															
										var player_strokes = 0
										var par_sum = 0
										var hole_scores = target_player.get("hole_scores", {})
										if typeof(hole_scores) == TYPE_DICTIONARY:
											for h_id in hole_scores:
												var score = hole_scores[h_id]
												if score != null:
													player_strokes += int(score)
													par_sum += int(hole_pars.get(h_id, 4))
													
										# Check match history shot stats for driver shots
										var p_shot_stats = target_player.get("shot_stats", {})
										if typeof(p_shot_stats) == TYPE_DICTIONARY:
											for h_id in p_shot_stats:
												var h_shots = p_shot_stats[h_id]
												if typeof(h_shots) == TYPE_ARRAY:
													for s_entry in h_shots:
														if typeof(s_entry) == TYPE_DICTIONARY:
															var s_club = str(s_entry.get("club", "")).to_lower()
															if s_club in ["dr", "driver", "1w"] or s_club.begins_with("dr"):
																var dist = float(s_entry.get("total_yds", 0.0))
																if dist > stats["longest_drive"]:
																	stats["longest_drive"] = dist

										if par_sum > 0:
											var diff = player_strokes - par_sum
											total_diff_sum += diff
											par_diff_matches_count += 1
											
											var course_t = json.get("course_title", "Course")
											var diff_sign = "+" if diff > 0 else ""
											var diff_str = "%s%d" % [diff_sign, diff] if diff != 0 else "E"
											
											if not stats["best_courses"].has(course_t) or diff < stats["best_courses"][course_t]["diff"] or (diff == stats["best_courses"][course_t]["diff"] and hole_scores.size() > int(stats["best_courses"][course_t].get("holes", 0))):
												stats["best_courses"][course_t] = {
													"diff": diff,
													"str": "%s (%d holes)" % [diff_str, hole_scores.size()],
													"strokes": player_strokes,
													"holes": hole_scores.size()
												}
						
				file_name = dir.get_next()
			dir.list_dir_end()
			
			if par_diff_matches_count > 0:
				stats["avg_to_par"] = total_diff_sum / par_diff_matches_count
				stats["avg_to_par_valid"] = true
				
	var global_stats = load_global_club_stats()
	var matching_player_key = _find_matching_player_key_in_dict(global_stats, player_name)
	var player_club_stats = global_stats.get(matching_player_key, {}) if not matching_player_key.is_empty() else {}
	var max_drive := float(stats.get("longest_drive", 0.0))
	var max_putt := float(stats.get("longest_putt_ft", 0.0))
	if typeof(player_club_stats) == TYPE_DICTIONARY:
		var records = player_club_stats.get("_records", {})
		if typeof(records) == TYPE_DICTIONARY:
			var rec_ld = float(records.get("longest_drive", 0.0))
			if rec_ld > max_drive:
				max_drive = rec_ld
			var rec_lp = float(records.get("longest_putt_ft", 0.0))
			if rec_lp > max_putt:
				max_putt = rec_lp
		for clb in player_club_stats.keys():
			if str(clb).begins_with("_"):
				continue
			var clb_lower = str(clb).to_lower()
			if clb_lower in ["dr", "driver", "1w"] or str(clb).begins_with("Dr"):
				var shots = player_club_stats[clb]
				if typeof(shots) == TYPE_ARRAY:
					for shot in shots:
						if typeof(shot) == TYPE_DICTIONARY:
							var dist = float(shot.get("TotalDistance", shot.get("CarryDistance", 0.0))) * 1.09361
							if dist > max_drive:
								max_drive = dist
	stats["longest_drive"] = max_drive
	stats["longest_putt_ft"] = max_putt

	var registered = get_registered_players()
	var reg_player = null
	for p in registered:
		if str(p.get("name", "")).to_lower() == player_name.to_lower():
			reg_player = p
			break
	if reg_player != null and reg_player.has("cloud_lifetime_cache") and typeof(reg_player["cloud_lifetime_cache"]) == TYPE_DICTIONARY:
		var clc: Dictionary = reg_player["cloud_lifetime_cache"]
		if not clc.is_empty():
			stats["matches_played"] = maxi(int(stats.get("matches_played", 0)), int(clc.get("matches_played", 0)))
			stats["wins"] = maxi(int(stats.get("wins", 0)), int(clc.get("wins", 0)))
			stats["losses"] = maxi(int(stats.get("losses", 0)), int(clc.get("losses", 0)))
			stats["ties"] = maxi(int(stats.get("ties", 0)), int(clc.get("ties", 0)))
			stats["single_player_completed"] = maxi(int(stats.get("single_player_completed", 0)), int(clc.get("single_player_completed", 0)))
			stats["longest_drive"] = maxf(float(stats.get("longest_drive", 0.0)), float(clc.get("longest_drive_yds", clc.get("longest_drive", 0.0))))
			stats["longest_putt_ft"] = maxf(float(stats.get("longest_putt_ft", 0.0)), float(clc.get("longest_putt_ft", 0.0)))

			var clc_courses = clc.get("best_courses", {})
			if typeof(clc_courses) == TYPE_DICTIONARY:
				for course_t in clc_courses:
					var c_data = clc_courses[course_t]
					if typeof(c_data) == TYPE_DICTIONARY:
						var c_diff = int(c_data.get("diff", 999))
						if not stats["best_courses"].has(course_t) or c_diff < int(stats["best_courses"][course_t].get("diff", 999)):
							stats["best_courses"][course_t] = c_data

	return stats

func get_player_longest_drive(player_name: String) -> float:
	var stats = calculate_player_stats(player_name)
	return float(stats.get("longest_drive", 0.0))

func get_player_longest_putt(player_name: String) -> float:
	var stats = calculate_player_stats(player_name)
	return float(stats.get("longest_putt_ft", 0.0))



# --- Video Swing Analysis Recommendation Tracking ---

const SWING_ISSUES_PATH = "user://player_swing_issues.json"
const MONTH_NAMES = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

static func get_month_display_name(month_key: String) -> String:
	var parts = month_key.split("-")
	if parts.size() == 2:
		var m_idx = int(parts[1])
		if m_idx >= 1 and m_idx <= 12:
			return "%s %s" % [MONTH_NAMES[m_idx], parts[0]]
	return month_key

func load_player_swing_issues() -> Dictionary:
	if not FileAccess.file_exists(SWING_ISSUES_PATH):
		return {}
	var file = FileAccess.open(SWING_ISSUES_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}

func save_player_swing_issues(data: Dictionary) -> void:
	var file = FileAccess.open(SWING_ISSUES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func record_player_swing_issues(player_name: String, recommendations: Array) -> void:
	if player_name.is_empty() or recommendations.is_empty():
		return
	for p in players:
		if p.get("name", "") == player_name and p.get("is_remote", false):
			return
	
	var canonical_name = get_canonical_player_name(player_name)
	var date_dict = Time.get_date_dict_from_system()
	var current_month = "%04d-%02d" % [date_dict.year, date_dict.month]
	
	var all_data = load_player_swing_issues()
	var matching_key = _find_matching_player_key_in_dict(all_data, canonical_name)
	var target_key = matching_key if not matching_key.is_empty() else canonical_name
	if not all_data.has(target_key):
		all_data[target_key] = {
			"all_time": {},
			"monthly": {}
		}
	
	var p_data = all_data[target_key]
	if not p_data.has("all_time") or typeof(p_data["all_time"]) != TYPE_DICTIONARY:
		p_data["all_time"] = {}
	if not p_data.has("monthly") or typeof(p_data["monthly"]) != TYPE_DICTIONARY:
		p_data["monthly"] = {}
	if not p_data["monthly"].has(current_month) or typeof(p_data["monthly"][current_month]) != TYPE_DICTIONARY:
		p_data["monthly"][current_month] = {}

	var recorded_any := false
	for rec in recommendations:
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var severity = str(rec.get("severity", ""))
		# Skip LOW severity (pro-grade maintenance notes)
		if severity == "LOW":
			continue
			
		var issue = str(rec.get("issue_type", rec.get("category", "General Flaw")))
		
		var cur_at = int(p_data["all_time"].get(issue, 0))
		p_data["all_time"][issue] = cur_at + 1
		
		var cur_mo = int(p_data["monthly"][current_month].get(issue, 0))
		p_data["monthly"][current_month][issue] = cur_mo + 1
		p_data["updated_at"] = int(Time.get_unix_time_from_system())
		recorded_any = true
		
	if recorded_any:
		save_player_swing_issues(all_data)
		if has_node("/root/CloudSync"):
			get_node("/root/CloudSync").call("mark_profile_dirty", target_key)
		print("[MultiplayerManager] Recorded swing recommendations for %s (%s)" % [target_key, current_month])

func get_player_swing_issues(player_name: String) -> Dictionary:
	var all_data = load_player_swing_issues()
	var matching_key = _find_matching_player_key_in_dict(all_data, player_name)
	if not matching_key.is_empty() and all_data.has(matching_key):
		return all_data[matching_key]
	return { "all_time": {}, "monthly": {} }

func clear_player_swing_issues(player_name: String) -> void:
	var all_data = load_player_swing_issues()
	var matching_key = _find_matching_player_key_in_dict(all_data, player_name)
	var target_key = matching_key if not matching_key.is_empty() else player_name
	all_data[target_key] = {
		"_cleared_at": int(Time.get_unix_time_from_system()),
		"all_time": {},
		"monthly": {}
	}
	save_player_swing_issues(all_data)
	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", target_key)
	print("[MultiplayerManager] Cleared swing issues for player: ", target_key)

func format_player_swing_issues_summary(player_name: String) -> String:
	var p_issues = get_player_swing_issues(player_name)
	var all_time: Dictionary = p_issues.get("all_time", {})
	var monthly: Dictionary = p_issues.get("monthly", {})
	
	if all_time.is_empty():
		return "VIDEO SWING ANALYSIS & RECOMMENDATION TOTALS:\nNo video swing recommendations recorded yet.\n"
		
	var date_dict = Time.get_date_dict_from_system()
	var current_month_key = "%04d-%02d" % [date_dict.year, date_dict.month]
	var current_month_name = get_month_display_name(current_month_key)
	
	var out = "VIDEO SWING ANALYSIS & RECOMMENDATION TOTALS:\n"
	out += "=============================================\n"
	
	var cur_month_issues: Dictionary = monthly.get(current_month_key, {})
	out += "This Month (%s):\n" % current_month_name
	if cur_month_issues.is_empty():
		out += "  (No swing recommendations recorded this month)\n"
	else:
		for issue_name in cur_month_issues:
			out += "  • %s: %d\n" % [issue_name, int(cur_month_issues[issue_name])]
			
	out += "\nAll-Time Running Totals:\n"
	for issue_name in all_time:
		out += "  • %s: %d\n" % [issue_name, int(all_time[issue_name])]
		
	return out + "\n"


static func _vec3_from_array(val: Variant) -> Vector3:
	if val is Vector3:
		return val
	if val is Array and val.size() >= 3:
		return Vector3(float(val[0]), float(val[1]), float(val[2]))
	return Vector3.ZERO


func record_remote_shot(event: Dictionary) -> void:
	var target_p: Dictionary = {}
	var slot_id: String = str(event.get("slot_id", ""))
	if not slot_id.is_empty():
		for p in players:
			if p.get("slot_id", "") == slot_id:
				target_p = p
				break
	if target_p.is_empty():
		target_p = get_active_player()
	if target_p.is_empty():
		return

	var start_pos := _vec3_from_array(event.get("start", target_p.get("position", Vector3.ZERO)))
	var final_position := _vec3_from_array(event.get("end", start_pos))

	target_p["last_starting_pos"] = start_pos
	target_p["position"] = final_position
	target_p["last_shot_club"] = str(event.get("club", "Dr"))
	target_p["lie_type"] = str(event.get("lie_end", "fairway"))
	target_p["last_shot_penalty"] = int(event.get("penalty", 0))

	var hole_idx: int = clampi(current_hole_index, 0, maxi(0, hole_ids.size() - 1)) if not hole_ids.is_empty() else 0
	var hole_id := str(event.get("hole_id", hole_ids[hole_idx] if not hole_ids.is_empty() else ""))
	var cur_hole_id: String = hole_ids[current_hole_index] if (current_hole_index >= 0 and current_hole_index < hole_ids.size()) else ""
	if not hole_id.is_empty() and hole_id != cur_hole_id:
		var target_h_idx := hole_ids.find(hole_id)
		if target_h_idx != -1 and target_h_idx != current_hole_index:
			current_hole_index = target_h_idx
			start_hole()

	var scores_map = event.get("scores", {})
	if scores_map is Dictionary and scores_map.has(slot_id):
		var slot_score: Dictionary = scores_map[slot_id]
		target_p["strokes"] = int(slot_score.get("hole_strokes", target_p.get("strokes", 0)))
		target_p["total_strokes"] = int(slot_score.get("total_strokes", target_p.get("total_strokes", 0)))
		target_p["holed_out"] = bool(slot_score.get("holed_out", target_p.get("holed_out", false)))
	else:
		if event.has("strokes"):
			target_p["strokes"] = int(event["strokes"])
		elif event.has("penalty"):
			target_p["strokes"] = int(target_p.get("strokes", 0)) + 1 + int(event.get("penalty", 0))
		else:
			target_p["strokes"] = int(target_p.get("strokes", 0)) + 1
		if event.has("total_strokes"):
			target_p["total_strokes"] = int(event["total_strokes"])
		else:
			target_p["total_strokes"] = int(target_p.get("total_strokes", 0)) + 1 + int(event.get("penalty", 0))
		if event.has("holed_out"):
			target_p["holed_out"] = bool(event["holed_out"])

	if not target_p.has("hole_scores") or not (target_p["hole_scores"] is Dictionary):
		target_p["hole_scores"] = {}
	if not hole_id.is_empty():
		target_p["hole_scores"][hole_id] = target_p["strokes"]

	# Snap pin position if included and differs by > 0.05m, guarding against cross-client map origin offsets (> 40.0m)
	if event.has("pin"):
		var pin_vec := _vec3_from_array(event["pin"])
		if not pin_vec.is_zero_approx():
			var cur_pin := _get_target_pin_position()
			if not cur_pin.is_zero_approx():
				var offset_x := cur_pin.x - pin_vec.x
				var offset_z := cur_pin.z - pin_vec.z
				# If unnormalized remote event arrived with large coordinate shift, align positions to local pin
				if (absf(offset_x) >= 2.0 or absf(offset_z) >= 2.0) and not bool(event.get("_normalized", false)):
					start_pos.x += offset_x
					start_pos.z += offset_z
					final_position.x += offset_x
					final_position.z += offset_z
					target_p["last_starting_pos"] = start_pos
					target_p["position"] = final_position
			if cur_pin.distance_to(pin_vec) > 0.05 and cur_pin.distance_to(pin_vec) <= 40.0:
				set_current_pin_position(pin_vec)

	# Update in-memory shot_history and shot_stats so remote players' shot paths
	# and distances appear on the scorecard review just like local players.
	if not target_p.has("shot_history") or not (target_p["shot_history"] is Array):
		target_p["shot_history"] = []
	target_p["shot_history"].append(final_position)

	if not hole_id.is_empty():
		if not target_p.has("shot_stats") or not (target_p["shot_stats"] is Dictionary):
			target_p["shot_stats"] = {}
		if not target_p["shot_stats"].has(hole_id) or not (target_p["shot_stats"][hole_id] is Array):
			target_p["shot_stats"][hole_id] = []

		var stat_entry: Dictionary = {}
		if event.has("shot_stat") and event["shot_stat"] is Dictionary and not (event["shot_stat"] as Dictionary).is_empty():
			stat_entry = (event["shot_stat"] as Dictionary).duplicate(true)
			stat_entry["start_pos"] = start_pos
			stat_entry["end_pos"] = final_position
			if not stat_entry.has("shot_num"):
				stat_entry["shot_num"] = target_p.get("strokes", 1)
		else:
			var shot_dist_yds: float = Vector2(start_pos.x, start_pos.z).distance_to(Vector2(final_position.x, final_position.z)) * 1.09361
			stat_entry = {
				"shot_num": target_p.get("strokes", 1),
				"start_pos": start_pos,
				"end_pos": final_position,
				"club": str(event.get("club", target_p.get("last_shot_club", "Dr"))),
				"speed_mph": 0.0,
				"ball_speed_mph": 0.0,
				"club_speed_mph": 0.0,
				"smash_factor": 0.0,
				"vla_deg": 0.0,
				"hla_deg": 0.0,
				"back_spin_rpm": 0.0,
				"side_spin_rpm": 0.0,
				"total_spin_rpm": 0.0,
				"spin_axis_deg": 0.0,
				"carry_yds": shot_dist_yds,
				"total_yds": shot_dist_yds,
				"apex_ft": 0.0,
				"offline_yds": 0.0
			}
		target_p["shot_stats"][hole_id].append(stat_entry)

	var gimme_strokes := int(event.get("gimme_strokes", 0))
	if gimme_strokes > 0 or bool(event.get("holed_out", false)):
		target_p["holed_out"] = true
		if gimme_strokes > 0:
			last_gimme_strokes = gimme_strokes
			target_p["last_gimme_strokes"] = gimme_strokes
			emit_signal("gimme_awarded", target_p, gimme_strokes)

	emit_signal("shot_recorded", target_p, {})
	emit_signal("distance_queue_updated")

	if bool(event.get("hole_complete", false)):
		for p in players:
			if p.get("active", true) and not p.get("paused", false):
				p["last_hole_score"] = p["strokes"]
				if not hole_id.is_empty():
					p["hole_scores"][hole_id] = p["strokes"]
			elif not p.get("active", true):
				p["last_hole_score"] = 0
				if not hole_id.is_empty():
					p["hole_scores"][hole_id] = null

		if game_mode == "Skins" and not hole_id.is_empty():
			_evaluate_skins_for_hole(hole_id)

		save_current_match()
		emit_signal("hole_completed", players)
	else:
		var next_slot := str(event.get("next_slot", ""))
		if not next_slot.is_empty():
			for idx in range(players.size()):
				if players[idx].get("slot_id", "") == next_slot:
					active_player_index = idx
					break
		emit_signal("active_player_changed", get_active_player())
