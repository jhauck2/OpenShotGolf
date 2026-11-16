extends SceneTree

const BallTypePhysics = preload("res://Utils/ball_type_physics.gd")

const TEST_STD_PLAYER := "__TestBallTypeStd__"
const TEST_SOFT_PLAYER := "__TestBallTypeSoft__"
const TEST_DIST_PLAYER := "__TestBallTypeDist__"

var _signal_events: Array = []
var _failed: bool = false


func _on_ball_type_changed(p_name: String, b_type: String) -> void:
	_signal_events.append({"name": p_name, "ball_type": b_type})


func _approx(a: float, b: float, tol: float = 0.001) -> bool:
	return absf(a - b) <= tol


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		push_error("ASSERT FAILED: " + msg)


func _collect_label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node == null:
		return texts
	if node is Label:
		texts.append((node as Label).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).text)
	for child in node.get_children():
		texts.append_array(_collect_label_texts(child))
	return texts


func _cleanup_test_state(mp: Node, gs: Node, orig_registered: Array, orig_players: Array, orig_active_idx: int, orig_range_ball_type: int) -> void:
	if mp != null:
		for pname in [TEST_STD_PLAYER, TEST_SOFT_PLAYER, TEST_DIST_PLAYER]:
			if mp.has_method("delete_player_permanently"):
				mp.delete_player_permanently(pname)
		mp.save_registered_players(orig_registered)
		mp.players = orig_players.duplicate(true)
		mp.active_player_index = orig_active_idx
	if gs != null and "range_settings" in gs and gs.range_settings != null and "ball_type" in gs.range_settings:
		if gs.range_settings.ball_type.has_method("set_value"):
			gs.range_settings.ball_type.set_value(orig_range_ball_type)
		else:
			gs.range_settings.ball_type.value = orig_range_ball_type


func _initialize() -> void:
	await process_frame
	print("=== Starting Ball Type Physics & Profile Test ===")

	var mp = root.get_node_or_null("MultiplayerManager")
	if mp == null:
		push_error("MultiplayerManager autoload must exist")
		quit(1)
		return
	var gs = root.get_node_or_null("GlobalSettings")

	var orig_registered: Array = mp.get_registered_players().duplicate(true)
	var orig_players: Array = mp.players.duplicate(true)
	var orig_active_idx: int = int(mp.active_player_index)
	var orig_range_ball_type: int = 0
	if gs != null and "range_settings" in gs and gs.range_settings != null and "ball_type" in gs.range_settings:
		orig_range_ball_type = int(gs.range_settings.ball_type.value)

	for pname in [TEST_STD_PLAYER, TEST_SOFT_PLAYER, TEST_DIST_PLAYER]:
		mp.delete_player_permanently(pname)

	# ---------------------------------------------------------
	# 1. BallTypePhysics normalization & multipliers
	# ---------------------------------------------------------
	_check(BallTypePhysics.normalize_ball_type("standard") == "standard", "normalize standard")
	_check(BallTypePhysics.normalize_ball_type("") == "standard", "normalize empty -> standard")
	_check(BallTypePhysics.normalize_ball_type(null) == "standard", "normalize null -> standard")
	_check(BallTypePhysics.normalize_ball_type("unknown_type") == "standard", "normalize unknown -> standard")
	_check(BallTypePhysics.normalize_ball_type(0) == "standard", "normalize 0 -> standard")
	_check(BallTypePhysics.normalize_ball_type("soft") == "soft", "normalize soft")
	_check(BallTypePhysics.normalize_ball_type("Tour Soft") == "soft", "normalize Tour Soft")
	_check(BallTypePhysics.normalize_ball_type(1) == "soft", "normalize 1 -> soft")
	_check(BallTypePhysics.normalize_ball_type("distance") == "distance", "normalize distance")
	_check(BallTypePhysics.normalize_ball_type("Distance / Firm") == "distance", "normalize Distance / Firm")
	_check(BallTypePhysics.normalize_ball_type(2) == "distance", "normalize 2 -> distance")

	_check(BallTypePhysics.id_to_index("standard") == 0, "id_to_index standard == 0")
	_check(BallTypePhysics.id_to_index("soft") == 1, "id_to_index soft == 1")
	_check(BallTypePhysics.id_to_index("distance") == 2, "id_to_index distance == 2")
	_check(BallTypePhysics.index_to_id(0) == "standard", "index_to_id 0 == standard")
	_check(BallTypePhysics.index_to_id(1) == "soft", "index_to_id 1 == soft")
	_check(BallTypePhysics.index_to_id(2) == "distance", "index_to_id 2 == distance")

	# Standard baseline must be exact 1.0 across every parameter
	_check(_approx(BallTypePhysics.get_speed_multiplier("standard"), 1.0), "std speed 1.0")
	_check(_approx(BallTypePhysics.get_spin_multiplier("standard"), 1.0), "std spin 1.0")
	_check(_approx(BallTypePhysics.get_rollout_factor("standard"), 1.0), "std rollout 1.0")
	_check(_approx(BallTypePhysics.get_friction_multiplier("standard"), 1.0), "std friction 1.0")
	_check(_approx(BallTypePhysics.get_bounce_retention_multiplier("standard"), 1.0), "std bounce 1.0")
	_check(_approx(BallTypePhysics.get_spinback_multiplier("standard"), 1.0), "std spinback 1.0")
	_check(_approx(BallTypePhysics.get_drag_scale_multiplier("standard"), 1.0), "std drag 1.0")
	_check(_approx(BallTypePhysics.get_lift_scale_multiplier("standard"), 1.0), "std lift 1.0")

	# Soft ball multipliers
	_check(_approx(BallTypePhysics.get_speed_multiplier("soft"), 0.98), "soft speed 0.98")
	_check(_approx(BallTypePhysics.get_spin_multiplier("soft"), 1.08), "soft spin 1.08")
	_check(_approx(BallTypePhysics.get_rollout_factor("soft"), 0.85), "soft rollout 0.85")
	_check(_approx(BallTypePhysics.get_friction_multiplier("soft"), 1.0 / 0.85), "soft friction 1/0.85")
	_check(_approx(BallTypePhysics.get_bounce_retention_multiplier("soft"), sqrt(0.85)), "soft bounce sqrt(0.85)")
	_check(_approx(BallTypePhysics.get_spinback_multiplier("soft"), 1.15), "soft spinback 1.15")
	_check(_approx(BallTypePhysics.get_drag_scale_multiplier("soft"), 1.015), "soft drag 1.015")
	_check(_approx(BallTypePhysics.get_lift_scale_multiplier("soft"), 1.01), "soft lift 1.01")

	# Distance ball multipliers
	_check(_approx(BallTypePhysics.get_speed_multiplier("distance"), 1.03), "dist speed 1.03")
	_check(_approx(BallTypePhysics.get_spin_multiplier("distance"), 0.90), "dist spin 0.90")
	_check(_approx(BallTypePhysics.get_rollout_factor("distance"), 1.18), "dist rollout 1.18")
	_check(_approx(BallTypePhysics.get_friction_multiplier("distance"), 1.0 / 1.18), "dist friction 1/1.18")
	_check(_approx(BallTypePhysics.get_bounce_retention_multiplier("distance"), sqrt(1.18)), "dist bounce sqrt(1.18)")
	_check(_approx(BallTypePhysics.get_spinback_multiplier("distance"), 0.85), "dist spinback 0.85")
	_check(_approx(BallTypePhysics.get_drag_scale_multiplier("distance"), 0.985), "dist drag 0.985")
	_check(_approx(BallTypePhysics.get_lift_scale_multiplier("distance"), 0.99), "dist lift 0.99")

	# Shot scaling + idempotency + standard no-op + putt immunity
	var shot_std := {"Speed": 120.0, "VLA": 16.5, "BackSpin": 6500.0, "SideSpin": 200.0, "TotalSpin": 6503.0, "ClubSpeed": 85.0}
	BallTypePhysics.apply_ball_type_to_shot_data(shot_std, "standard", "7 Iron")
	_check(not shot_std.has("_ball_type_applied"), "Standard ball must be a zero-op on shot dictionary")
	_check(_approx(shot_std["Speed"], 120.0), "std speed unchanged")
	_check(_approx(shot_std["BackSpin"], 6500.0), "std backspin unchanged")

	var shot_soft := {"Speed": 120.0, "VLA": 16.5, "BackSpin": 6500.0, "SideSpin": 200.0, "TotalSpin": 6503.0, "ClubSpeed": 85.0}
	BallTypePhysics.apply_ball_type_to_shot_data(shot_soft, "soft", "7 Iron")
	_check(shot_soft.get("_ball_type_applied", false) == true, "soft applied flag")
	_check(_approx(shot_soft["Speed"], 120.0 * 0.98), "soft speed scaled")
	_check(_approx(shot_soft["BackSpin"], 6500.0 * 1.08), "soft backspin scaled")
	_check(_approx(shot_soft["SideSpin"], 200.0 * 1.08), "soft sidespin scaled")
	_check(_approx(shot_soft["TotalSpin"], 6503.0 * 1.08), "soft totalspin scaled")
	BallTypePhysics.apply_ball_type_to_shot_data(shot_soft, "soft", "7 Iron")
	_check(_approx(shot_soft["Speed"], 120.0 * 0.98), "Shot scaling must be idempotent")
	_check(_approx(shot_soft["BackSpin"], 6500.0 * 1.08), "Spin scaling must be idempotent")

	var shot_dist := {"BallData": {"Speed": 150.0, "VLA": 11.5, "BackSpin": 2600.0, "TotalSpin": 2600.0}}
	BallTypePhysics.apply_ball_type_to_shot_data(shot_dist, "distance", "Driver")
	_check(_approx(shot_dist["BallData"]["Speed"], 150.0 * 1.03), "dist nested BallData Speed")
	_check(_approx(shot_dist["BallData"]["BackSpin"], 2600.0 * 0.90), "dist nested BallData BackSpin")
	_check(_approx(shot_dist["BallData"]["TotalSpin"], 2600.0 * 0.90), "dist nested BallData TotalSpin")

	var shot_putt := {"Speed": 10.0, "VLA": 2.0, "BackSpin": 100.0, "TotalSpin": 100.0}
	BallTypePhysics.apply_ball_type_to_shot_data(shot_putt, "distance", "Putter")
	_check(not shot_putt.has("_ball_type_applied"), "Putter shots must bypass ball type scaling")
	_check(_approx(shot_putt["Speed"], 10.0), "Putter speed unchanged")

	print("1. BallTypePhysics unit assertions done (failed=%s)" % str(_failed))

	# ---------------------------------------------------------
	# 2. MultiplayerManager persistence, update & setup_game
	# ---------------------------------------------------------
	_signal_events.clear()
	mp.player_ball_type_changed.connect(_on_ball_type_changed)

	mp.register_player(TEST_STD_PLAYER)
	_check(mp.get_player_ball_type(TEST_STD_PLAYER) == "standard", "New player without explicit ball_type must default to standard")

	mp.register_player(TEST_SOFT_PLAYER, "", "", [], "Blue", "mid_handicap", 0, "single_line", "soft")
	_check(mp.get_player_ball_type(TEST_SOFT_PLAYER) == "soft", "register_player preserves soft")
	_check(mp.get_player_ball_type_name(TEST_SOFT_PLAYER).contains("Soft"), "get_player_ball_type_name displays Soft")

	mp.register_player(TEST_DIST_PLAYER, "", "", [], "Blue", "mid_handicap", 0, "single_line", "distance")
	_check(mp.get_player_ball_type(TEST_DIST_PLAYER) == "distance", "register_player preserves distance")

	var changed_ok = mp.set_player_ball_type(TEST_STD_PLAYER, "distance")
	_check(changed_ok == true, "set_player_ball_type returns true")
	_check(mp.get_player_ball_type(TEST_STD_PLAYER) == "distance", "set_player_ball_type persists distance")
	_check(_signal_events.size() >= 1 and _signal_events.back()["name"] == TEST_STD_PLAYER and _signal_events.back()["ball_type"] == "distance", "player_ball_type_changed signal emitted")

	var upd_ok = mp.update_player_profile(TEST_STD_PLAYER, "", "", "Blue", "mid_handicap", 0, "single_line", "standard")
	_check(upd_ok == true, "update_player_profile returns true")
	_check(mp.get_player_ball_type(TEST_STD_PLAYER) == "standard", "update_player_profile reverts to standard")

	mp.setup_game([
		{"name": TEST_SOFT_PLAYER, "tee": "Blue"},
		{"name": TEST_DIST_PLAYER, "tee": "Blue"},
		{"name": TEST_STD_PLAYER, "tee": "Blue"}
	], {})
	_check(mp.players.size() == 3, "setup_game populated 3 players")
	if mp.players.size() == 3:
		_check(mp.players[0].get("ball_type", "") == "soft", "setup_game player 0 soft")
		_check(mp.players[1].get("ball_type", "") == "distance", "setup_game player 1 distance")
		_check(mp.players[2].get("ball_type", "") == "standard", "setup_game player 2 standard")

	mp.player_ball_type_changed.disconnect(_on_ball_type_changed)
	print("2. MultiplayerManager persistence & setup_game done (failed=%s)" % str(_failed))

	# ---------------------------------------------------------
	# 3. GolfBall, Player, & PhysicsAdapter integration
	# ---------------------------------------------------------
	# First ensure active player is TEST_STD_PLAYER so fresh Player defaults to "standard"
	mp.setup_game([{"name": TEST_STD_PLAYER, "tee": "Blue"}], {})
	if gs != null and "range_settings" in gs and gs.range_settings != null and "ball_type" in gs.range_settings:
		if gs.range_settings.ball_type.has_method("set_value"):
			gs.range_settings.ball_type.set_value(0)
		else:
			gs.range_settings.ball_type.value = 0

	var player_scene = load("res://Player/player.tscn")
	_check(player_scene != null, "res://Player/player.tscn must load")
	if player_scene != null:
		var player_node = player_scene.instantiate()
		root.add_child(player_node)
		await process_frame

		var ball = player_node.get("ball")
		_check(ball != null, "Player must have ball node")
		if ball != null:
			_check(ball.get_ball_type() == "standard", "Default GolfBall ball_type must be standard")
			_check(_approx(ball._ball_type_bounce_retention, 1.0), "Default bounce retention 1.0")
			_check(_approx(ball._ball_type_spinback_mult, 1.0), "Default spinback mult 1.0")

			ball.apply_ball_type("standard")
			var base_kinetic: float = float(ball._kinetic_friction)
			var base_rolling: float = float(ball._rolling_friction)
			var base_drag: float = float(ball._drag_scale)
			var base_lift: float = float(ball._lift_scale)
			var base_spinback: float = float(ball._spinback_response_scale)

			player_node.set_profile(TEST_SOFT_PLAYER)
			_check(ball.get_ball_type() == "soft", "set_profile applies soft to ball")
			_check(_approx(ball._kinetic_friction, base_kinetic / 0.85, 0.002), "Soft ball increases kinetic friction")
			_check(_approx(ball._rolling_friction, base_rolling / 0.85, 0.002), "Soft ball increases rolling friction")
			_check(_approx(ball._ball_type_bounce_retention, sqrt(0.85), 0.002), "Soft bounce retention sqrt(0.85)")
			_check(_approx(ball._ball_type_spinback_mult, 1.15, 0.002), "Soft spinback mult 1.15")
			_check(_approx(ball._spinback_response_scale, base_spinback * 1.15, 0.002), "Soft spinback response scale")
			_check(_approx(ball._drag_scale, base_drag * 1.015, 0.002), "Soft drag scale")
			_check(_approx(ball._lift_scale, base_lift * 1.01, 0.002), "Soft lift scale")
			if ball.params != null:
				_check(_approx(float(ball.params.KineticFriction), ball._kinetic_friction, 0.002), "params.KineticFriction synced for soft")
				_check(_approx(float(ball.params.RollingFriction), ball._rolling_friction, 0.002), "params.RollingFriction synced for soft")

			player_node.set_profile(TEST_DIST_PLAYER)
			_check(ball.get_ball_type() == "distance", "set_profile applies distance to ball")
			_check(_approx(ball._kinetic_friction, base_kinetic / 1.18, 0.002), "Distance ball decreases kinetic friction")
			_check(_approx(ball._rolling_friction, base_rolling / 1.18, 0.002), "Distance ball decreases rolling friction")
			_check(_approx(ball._ball_type_bounce_retention, sqrt(1.18), 0.002), "Distance bounce retention sqrt(1.18)")
			_check(_approx(ball._ball_type_spinback_mult, 0.85, 0.002), "Distance spinback mult 0.85")
			_check(_approx(ball._spinback_response_scale, base_spinback * 0.85, 0.002), "Distance spinback response scale")
			_check(_approx(ball._drag_scale, base_drag * 0.985, 0.002), "Distance drag scale")
			_check(_approx(ball._lift_scale, base_lift * 0.99, 0.002), "Distance lift scale")

			player_node.set_profile(TEST_STD_PLAYER)
			_check(ball.get_ball_type() == "standard", "Reverting to standard sets ball_type")
			_check(_approx(ball._kinetic_friction, base_kinetic, 0.002), "Standard restores exact kinetic friction")
			_check(_approx(ball._rolling_friction, base_rolling, 0.002), "Standard restores exact rolling friction")
			_check(_approx(ball._drag_scale, base_drag, 0.002), "Standard restores exact drag scale")
			_check(_approx(ball._lift_scale, base_lift, 0.002), "Standard restores exact lift scale")
			_check(_approx(ball._spinback_response_scale, base_spinback, 0.002), "Standard restores exact spinback scale")

		player_node.queue_free()
		await process_frame

		# Verify new Player automatically inherits active player's ball_type on _ready
		mp.setup_game([{"name": TEST_SOFT_PLAYER, "tee": "Blue"}], {})
		var soft_player_node = player_scene.instantiate()
		root.add_child(soft_player_node)
		await process_frame
		var soft_ball = soft_player_node.get("ball")
		_check(soft_ball != null and soft_ball.get_ball_type() == "soft", "Player._ready auto-applies active player's soft ball_type")
		soft_player_node.queue_free()
		await process_frame

	var adapter_script = load("res://addons/openfairway/physics/PhysicsAdapter.cs")
	if adapter_script != null:
		var adapter = adapter_script.new()
		var base_shot := {"Speed": 120.0, "VLA": 16.3, "HLA": 0.0, "BackSpin": 7000.0, "SideSpin": 0.0, "TotalSpin": 7000.0}
		var s_std := base_shot.duplicate(true)
		var s_soft := base_shot.duplicate(true)
		var s_dist := base_shot.duplicate(true)
		BallTypePhysics.apply_ball_type_to_shot_data(s_std, "standard", "7i")
		BallTypePhysics.apply_ball_type_to_shot_data(s_soft, "soft", "7i")
		BallTypePhysics.apply_ball_type_to_shot_data(s_dist, "distance", "7i")

		var res_std = adapter.SimulateShotFromJson(s_std, PhysicsEnums.SurfaceType.FAIRWAY, Vector3.UP)
		var res_soft = adapter.SimulateShotFromJson(s_soft, PhysicsEnums.SurfaceType.FAIRWAY, Vector3.UP)
		var res_dist = adapter.SimulateShotFromJson(s_dist, PhysicsEnums.SurfaceType.FAIRWAY, Vector3.UP)

		var carry_std := float(res_std.get("carry_yd", 0.0))
		var carry_soft := float(res_soft.get("carry_yd", 0.0))
		var carry_dist := float(res_dist.get("carry_yd", 0.0))
		var total_dist := float(res_dist.get("total_yd", 0.0))
		var total_std := float(res_std.get("total_yd", 0.0))
		print("  7i PhysicsAdapter carry/total (yd): Soft=%.1f/%.1f | Std=%.1f/%.1f | Dist=%.1f/%.1f" % [
			carry_soft, float(res_soft.get("total_yd", 0.0)), carry_std, total_std, carry_dist, total_dist
		])
		_check(carry_soft < carry_std, "Soft ball carry must be slightly shorter than standard")
		_check(carry_dist > carry_std, "Distance ball carry must exceed standard")
		_check(total_dist > total_std, "Distance ball total must exceed standard")

	print("3. GolfBall, Player, & PhysicsAdapter integration done (failed=%s)" % str(_failed))

	# ---------------------------------------------------------
	# 4. PlayersMenu UI (Create / Edit / Profile Overview)
	# ---------------------------------------------------------
	var players_menu_scene = load("res://UI/PlayersMenu/players_menu.tscn")
	_check(players_menu_scene != null, "players_menu.tscn must load")
	if players_menu_scene != null:
		var players_menu = players_menu_scene.instantiate()
		root.add_child(players_menu)
		await process_frame

		_check(players_menu.new_player_ball_type_opt != null, "Create profile ball type dropdown must exist")
		if players_menu.new_player_ball_type_opt != null:
			_check(players_menu.new_player_ball_type_opt.item_count == 3, "Ball type dropdown must have 3 options")
			_check(players_menu.new_player_ball_type_opt.selected == 0, "Default new player ball type selection must be Standard (index 0)")

		players_menu._open_edit_profile_dialog(TEST_SOFT_PLAYER)
		await process_frame
		_check(players_menu.edit_profile_ball_type_opt != null, "Edit profile ball type dropdown must exist")
		if players_menu.edit_profile_ball_type_opt != null:
			_check(players_menu.edit_profile_ball_type_opt.selected == 1, "Edit dialog must pre-select Soft Ball (index 1)")
		if players_menu.edit_profile_dialog != null:
			players_menu.edit_profile_dialog.hide()

		players_menu._render_player_profile(TEST_DIST_PLAYER)
		await process_frame
		var overview_texts := _collect_label_texts(players_menu.stats_panel)
		var found_ball_type_label := false
		var found_dist_value := false
		for t in overview_texts:
			if "Ball Type" in t:
				found_ball_type_label = true
			if "Distance" in t:
				found_dist_value = true
		_check(found_ball_type_label, "Profile overview must display 'Ball Type' label")
		_check(found_dist_value, "Profile overview must display 'Distance Ball' value")

		players_menu.queue_free()
		await process_frame

	print("4. PlayersMenu UI checks done (failed=%s)" % str(_failed))

	_cleanup_test_state(mp, gs, orig_registered, orig_players, orig_active_idx, orig_range_ball_type)
	if _failed:
		push_error("One or more ball type physics/profile assertions failed.")
		quit(1)
	else:
		print("ALL BALL TYPE PHYSICS & PROFILE TESTS PASSED!")
		quit(0)
