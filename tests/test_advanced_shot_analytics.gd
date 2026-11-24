extends SceneTree

const ShotAnalyticsEngineScript = preload("res://Utils/shot_analytics_engine.gd")
const GolfSwingAnalyzerScript = preload("res://UI/GolferCamera/golf_swing_analyzer.gd")
const AnalyticsVisualWidgetsScript = preload("res://UI/ShotAnalysis/analytics_visual_widgets.gd")
const PracticeDrillHudScript = preload("res://UI/ShotAnalysis/practice_drill_hud.gd")
const ShotAnalysisWindowScript = preload("res://UI/ShotAnalysis/shot_analysis_window.gd")
const StatsMergerScript = preload("res://Utils/Cloud/stats_merger.gd")

var _failed: int = 0
var _tested: bool = false


func _initialize() -> void:
	print("=== Running Advanced Shot Analytics & Coaching GDScript Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	await _run_all()
	if _failed > 0:
		push_error("FAILED %d assertions in test_advanced_shot_analytics.gd" % _failed)
		quit(1)
	else:
		print("=======================================================")
		print("ALL ADVANCED SHOT ANALYTICS & COACHING TESTS PASSED!")
		print("=======================================================")
		quit(0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed += 1
		push_error("ASSERT FAIL: %s" % msg)


func _run_all() -> void:
	await _test_1_shot_analytics_engine()
	await _test_2_golf_swing_analyzer()
	await _test_3_visual_widgets()
	await _test_4_shot_analysis_window_and_charts()
	await _test_5_practice_drill_hud()
	await _test_6_stats_merger_and_goal_persistence()


func _test_1_shot_analytics_engine() -> void:
	print("\n--- Test 1: ShotAnalyticsEngine ---")
	_check(ShotAnalyticsEngineScript.get_target_corridor_yards("Driver", 250.0) == 15.0, "Driver corridor must be 15 yds")
	_check(ShotAnalyticsEngineScript.get_target_corridor_yards("7i", 160.0) == 8.0, "7i corridor must be 8 yds")
	_check(ShotAnalyticsEngineScript.get_target_corridor_yards("Pw", 120.0) == 6.0, "PW corridor must be 6 yds")

	var rh_pd: Dictionary = ShotAnalyticsEngineScript.classify_ball_flight(2.0, 4.0, -2.0, false)
	_check(str(rh_pd["shape"]) == "Push-Draw", "RH Push-Draw shape match")
	_check(str(rh_pd["start_dir"]) == "Right" and str(rh_pd["curve_dir"]) == "Left", "RH Push-Draw physical dirs")
	_check(bool(rh_pd["is_functional_stock"]) == true, "RH Push-Draw must be functional stock")

	var lh_pd: Dictionary = ShotAnalyticsEngineScript.classify_ball_flight(2.0, 4.0, -2.0, true)
	_check(str(lh_pd["start_dir"]) == "Left" and str(lh_pd["curve_dir"]) == "Right", "LH Push-Draw physical dirs inverted")
	_check(bool(lh_pd["is_functional_stock"]) == true, "LH Push-Draw must be functional stock")

	var pull_hook: Dictionary = ShotAnalyticsEngineScript.classify_ball_flight(-4.5, 0.5, -5.0, false)
	_check(str(pull_hook["shape"]) == "Pull-Hook" and bool(pull_hook["is_functional_stock"]) == false, "Pull-Hook is not functional stock")

	var ell_pts: Array[Vector2] = [Vector2(240, -6), Vector2(250, 0), Vector2(260, 6), Vector2(248, -2), Vector2(252, 2)]
	var ell: Dictionary = ShotAnalyticsEngineScript.compute_covariance_ellipse(ell_pts)
	_check(bool(ell["valid"]) == true and float(ell["area_yd2"]) > 0.0 and float(ell["rx80"]) > float(ell["ry80"]), "Covariance ellipse valid & oriented")

	var raw_shots: Array = []
	for i in range(8):
		raw_shots.append({
			"Club": "Driver",
			"t": 1760000000 + i * 30,
			"CarryDistance": 175.0,
			"TotalDistance": 190.0,
			"SideDistance": 14.0 if i % 2 == 0 else 10.0,
			"ClubSpeed": 100.0,
			"BallSpeed": 128.0,
			"SmashFactor": 1.28,
			"FaceAngle": 3.5,
			"ClubPath": -1.0,
			"FaceToPath": 4.5,
			"TotalSpin": 3500.0,
			"SpinAxis": 9.5,
			"VLA": 12.0,
			"HLA": 2.5
		})
	var grp: Dictionary = ShotAnalyticsEngineScript.analyze_shot_group(raw_shots, "Driver", "beginner", false)
	_check(bool(grp["has_data"]) == true, "analyze_shot_group must return has_data")
	_check(str(grp["skill_level"]) == "high_handicap", "beginner skill normalized to high_handicap")
	var focus: Dictionary = grp.get("active_focus", {})
	_check(focus.has("milestones") and (focus["milestones"] as Array).size() == 3, "Active Focus must contain 3 milestones")
	var dist_loss: Dictionary = grp.get("distance_loss", {})
	_check(bool(dist_loss.get("has_data", false)) and float(dist_loss.get("total_lost_yds", 0.0)) > 5.0, "Missing yards loss breakdown > 5 yds")

	var bag_avgs: Dictionary = {
		"Dr": {"display_name": "Driver", "shot_count": 10, "avg_carry_m": 230.0, "avg_total_m": 250.0},
		"3w": {"display_name": "3 Wood", "shot_count": 6, "avg_carry_m": 226.0, "avg_total_m": 240.0},
		"7i": {"display_name": "7 Iron", "shot_count": 12, "avg_carry_m": 150.0, "avg_total_m": 158.0}
	}
	var gaps: Array[Dictionary] = ShotAnalyticsEngineScript.analyze_bag_gapping(bag_avgs)
	_check(gaps.size() == 3, "Bag gapping should include 3 clubs")
	_check(str(gaps[1]["status"]) == "overlap" and str(gaps[2]["status"]) == "large_gap", "Bag gapping must flag overlap (<8y) and large_gap (>18y)")

	var eval_gate: Dictionary = ShotAnalyticsEngineScript.evaluate_drill_shot("start_line_gate", {"Club": "7i", "HLA": 1.2}, "7i", "mid_handicap")
	_check(bool(eval_gate["passed"]) == true, "Start-Line Gate passes 1.2 deg HLA")
	var eval_feel: Dictionary = ShotAnalyticsEngineScript.evaluate_drill_shot("differential_feel", {"Club": "7i", "FaceToPath": -2.0}, "7i", "mid_handicap", false, {"rep_index": 0})
	_check(bool(eval_feel["passed"]) == true, "Differential Feel rep 0 requires Draw and accepts -2.0 FTP")
	var eval_wedge: Dictionary = ShotAnalyticsEngineScript.evaluate_drill_shot("wedge_ladder", {"Club": "Sw", "CarryDistance": 55.0}, "Sw", "mid_handicap", false, {"target_yards": 60.0})
	_check(bool(eval_wedge["passed"]) == true, "Wedge ladder accepts 55m (~60.1 yds) for 60 yd target")
	print("  PASS: ShotAnalyticsEngine verified.")


func _test_2_golf_swing_analyzer() -> void:
	print("\n--- Test 2: GolfSwingAnalyzer Upgrades ---")
	_check(GolfSwingAnalyzerScript.normalize_skill_level("beginner") == "high_handicap", "normalize_skill_level beginner")
	_check(GolfSwingAnalyzerScript.normalize_skill_level("low_handicap") == "scratch", "normalize_skill_level low_handicap")
	_check(GolfSwingAnalyzerScript._classify_club("9i") == "mid_iron", "9i must classify as mid_iron")
	_check(GolfSwingAnalyzerScript._classify_club("9-iron") == "mid_iron", "9-iron must classify as mid_iron")

	# Lefty Slice: Negative Face-to-Path & Negative Spin Axis = open face slice left
	var lefty_slice: Array[Dictionary] = GolfSwingAnalyzerScript.analyze_launch_monitor({
		"Club": "Driver", "is_lefty": true, "FaceAngle": -5.0, "ClubPath": 1.0,
		"FaceToPath": -6.0, "SpinAxis": -12.0, "SmashFactor": 1.44, "VLA": 12.5, "TotalSpin": 2400.0
	})
	_check(lefty_slice.size() >= 1 and str(lefty_slice[0]["issue_type"]) == "Slice / Open Face-to-Path", "Lefty negative FTP/SpinAxis must trigger Slice")
	_check("left" in str(lefty_slice[0]["launch_effect"]).to_lower(), "Lefty slice launch effect must describe curving left")
	_check(lefty_slice[0].has("drill_stages") and (lefty_slice[0]["drill_stages"] as Array).size() == 3, "Rec must include 3 drill_stages")
	_check(not str(lefty_slice[0].get("monitor_proof", "")).is_empty(), "Rec must include monitor_proof")

	# Functional stock flight guard
	var stock_recs: Array[Dictionary] = GolfSwingAnalyzerScript.analyze_launch_monitor({
		"Club": "Driver", "HLA": 2.2, "FaceAngle": 2.0, "ClubPath": 3.8, "FaceToPath": -1.8,
		"SpinAxis": -4.2, "Offline": 1.5, "SmashFactor": 1.46, "VLA": 12.5, "TotalSpin": 2350.0, "Carry": 245.0
	})
	_check(stock_recs.size() == 1 and str(stock_recs[0]["issue_type"]) == "Pure Ball Strike", "Functional stock Push-Draw should not be flagged as flaw")

	# Gear effect attribution + Low Face Spin
	var toe_recs: Array[Dictionary] = GolfSwingAnalyzerScript.analyze_launch_monitor({
		"Club": "Driver", "FaceAngle": 0.4, "ClubPath": 0.2, "FaceToPath": 0.2,
		"SpinAxis": -7.2, "hi": 12.5, "vi": -10.0, "TotalSpin": 3500.0, "SmashFactor": 1.41, "VLA": 12.0
	})
	var found_toe: bool = false
	var found_low_face: bool = false
	for r in toe_recs:
		if str(r.get("issue_type", "")) == "Toe Gear-Effect Hook":
			found_toe = true
		if str(r.get("issue_type", "")) == "Low-Face Driver Spin Spike":
			found_low_face = true
	_check(found_toe, "Toe strike >= 10mm with neutral FTP must trigger Toe Gear-Effect Hook")
	_check(found_low_face, "Low-face strike <= -8mm with >3000 RPM must trigger Low-Face Driver Spin Spike")

	# Spin loft & Descent angle on 7i
	var iron_recs: Array[Dictionary] = GolfSwingAnalyzerScript.analyze_launch_monitor({
		"Club": "7i", "DynamicLoft": 41.0, "AttackAngle": -2.0, "DescentAngle": 33.0,
		"SmashFactor": 1.32, "VLA": 24.0, "TotalSpin": 6200.0, "SpinAxis": 0.0
	})
	var found_sl: bool = false
	var found_da: bool = false
	for r in iron_recs:
		if str(r.get("issue_type", "")) == "High Spin Loft / Flipping":
			found_sl = true
		if str(r.get("issue_type", "")) == "Low Descent Angle / Won't Hold Green":
			found_da = true
	_check(found_sl, "7i spin loft 43 deg must trigger High Spin Loft / Flipping")
	_check(found_da, "7i descent 33 deg must trigger Low Descent Angle / Won't Hold Green")

	# Skeleton sequence: Lefty swap + Rushed tempo + DTL gating
	var frames: Array[Dictionary] = []
	for f_idx in range(14):
		var wrist_y: float = 0.72 - float(f_idx) * 0.06 if f_idx <= 5 else (0.42 + float(f_idx - 5) * 0.075 if f_idx <= 9 else 0.72 - float(f_idx - 9) * 0.06)
		var landmarks: Dictionary = {
			"nose": {"x": 0.50, "y": 0.25 if f_idx < 8 else 0.36},
			"left_shoulder": {"x": 0.42, "y": 0.40},
			"right_shoulder": {"x": 0.58, "y": 0.40},
			"left_hip": {"x": 0.44, "y": 0.65},
			"right_hip": {"x": 0.56, "y": 0.65},
			"left_wrist": {"x": 0.40, "y": wrist_y},
			"right_wrist": {"x": 0.60, "y": wrist_y},
			"right_elbow": {"x": 0.60, "y": 0.52}
		}
		if f_idx >= 8 and f_idx <= 10:
			# Bent right elbow (< 152 deg) simulates lefty lead arm chicken wing around impact
			landmarks["right_elbow"] = {"x": 0.72, "y": 0.48}
			landmarks["right_wrist"] = {"x": 0.55, "y": 0.48} if f_idx != 9 else {"x": 0.55, "y": wrist_y}
		frames.append({"landmarks": landmarks})
	var skel: Dictionary = GolfSwingAnalyzerScript.analyze_skeleton_sequence(frames, {}, true)
	_check(bool(skel["has_valid_data"]) == true, "Synthetic skeleton sequence must parse")
	_check(str(skel.get("camera_view", "")) == "face_on", "Wide shoulder span must classify camera_view as face_on")
	_check(bool(skel.get("impact_chicken_wing", false)) == true, "Lefty right-elbow bend < 152 deg must flag impact_chicken_wing")

	# Unified tempo check & 3-stage info lookup
	skel["frame_count"] = 16
	skel["swing_tempo_ratio"] = 1.4
	var uni_recs: Array[Dictionary] = GolfSwingAnalyzerScript.analyze_shot_unified({"Club": "Driver", "SpinAxis": 1.0, "SmashFactor": 1.46}, skel)
	var found_tempo: bool = false
	for r in uni_recs:
		if str(r.get("issue_type", "")) == "Rushed Downswing Tempo":
			found_tempo = true
	_check(found_tempo, "Tempo ratio 1.4 must trigger Rushed Downswing Tempo")

	var info: Dictionary = GolfSwingAnalyzerScript.get_issue_info("toe_gear_hook")
	_check(info.has("drill_stages") and (info["drill_stages"] as Array).size() == 3, "get_issue_info must attach 3-stage progression")
	print("  PASS: GolfSwingAnalyzer upgrades verified.")


func _test_3_visual_widgets() -> void:
	print("\n--- Test 3: AnalyticsVisualWidgets Headless Safety ---")
	var box := VBoxContainer.new()
	box.size = Vector2(500, 400)
	root.add_child(box)

	var bg: Control = AnalyticsVisualWidgetsScript.create_bullet_gauge("Smash Factor", 1.43, 1.42, 1.48, 1.25, 1.52, "")
	var dp: Control = AnalyticsVisualWidgetsScript.create_d_plane_matrix({"Push-Draw": 5, "Straight": 3}, 8, false)
	var gap: Control = AnalyticsVisualWidgetsScript.create_bag_gapping_chart([
		{"club": "Dr", "display_name": "Driver", "carry_yds": 245.0, "total_yds": 265.0, "gap_yds": 0.0, "status": "anchor"},
		{"club": "7i", "display_name": "7 Iron", "carry_yds": 155.0, "total_yds": 162.0, "gap_yds": 90.0, "status": "large_gap"}
	])
	var lo: Control = AnalyticsVisualWidgetsScript.create_launch_optimizer([{"vla": 13.0, "total_spin": 2400.0}], {"vla_min": 11.0, "vla_max": 15.0, "spin_min": 2000.0, "spin_max": 2800.0})
	var sp: Control = AnalyticsVisualWidgetsScript.create_trend_sparkline([12.0, 9.5, 8.0, 6.2], "Offline Trend", "yd", 0.0, 12.0)

	for w in [bg, dp, gap, lo, sp]:
		box.add_child(w)
		w.queue_redraw()
	await process_frame
	_check(box.get_child_count() == 5, "All 5 visual widgets mounted and redrawn without error")
	box.queue_free()
	print("  PASS: AnalyticsVisualWidgets headless drawing verified.")


func _test_4_shot_analysis_window_and_charts() -> void:
	print("\n--- Test 4: ShotAnalysisWindow & ShotAnalysisCharts ---")
	var analysis: Control = ShotAnalysisWindowScript.new()
	root.add_child(analysis)
	await process_frame

	var shots: Array = [
		{"player_name": "Player A", "club": "Driver", "CarryDistance": 200.0, "TotalDistance": 215.0, "SideDistance": 5.0, "Apex": 25.0, "BallSpeed": 145.0, "ClubSpeed": 100.0, "TotalSpin": 2600.0, "DescentAngle": 41.0, "VLA": 12.0, "HLA": 1.0, "FaceAngle": 2.0, "ClubPath": 3.5},
		{"player_name": "Player A", "club": "Driver", "CarryDistance": 220.0, "TotalDistance": 238.0, "SideDistance": 2.0, "Apex": 28.0, "BallSpeed": 150.0, "ClubSpeed": 102.0, "TotalSpin": 2400.0, "DescentAngle": 40.0, "VLA": 13.0, "HLA": 0.5, "FaceAngle": 1.5, "ClubPath": 3.0},
		{"player_name": "Player B", "club": "7i", "CarryDistance": 145.0, "TotalDistance": 152.0, "SideDistance": -4.0, "Apex": 26.0, "BallSpeed": 112.0, "ClubSpeed": 85.0, "TotalSpin": 6400.0, "DescentAngle": 46.0, "VLA": 17.0, "HLA": -1.0}
	]
	analysis.call("initialize", shots)
	await process_frame

	var averages: Dictionary = analysis.get("_averages")
	var stddevs: Dictionary = analysis.get("_stddevs")
	var keys: Array = analysis.get("_data_keys")
	_check(averages.has(0) and stddevs.has(0), "Group 0 must have both Average and StdDev rows")
	var sd_carry: Label = (stddevs[0] as HBoxContainer).get_child(keys.find("CarryDistance") + 2) as Label
	_check(sd_carry.text.begins_with("±"), "Std Dev row cell must display ± value (got %s)" % sd_carry.text)

	var mode_selector: OptionButton = analysis.get("_mode_selector")
	_check(mode_selector.item_count == 3, "Mode selector must have 3 modes (Best, Avg, Best Overall)")
	mode_selector.select(2)
	analysis.call("_update_chart")
	var chart: Control = analysis.get("_chart")
	var best_overall: Dictionary = chart.call("_representative_shot", 0)
	_check(float(best_overall.get("CarryDistance", 0.0)) == 220.0, "Best overall picks higher carry & tighter offline shot")

	var edge_pts: Array[Vector2] = [Vector2(96.0, 96.0), Vector2(100.0, 100.0)]
	var clipped: Vector2 = chart.call("_bounded_ellipse_radii", edge_pts, Rect2(Vector2.ZERO, Vector2(100, 100)))
	_check(clipped.x <= 0.0 and clipped.y <= 0.0, "_bounded_ellipse_radii backward compatibility preserved")

	var coaching_container: VBoxContainer = analysis.get("_coaching_container")
	_check(coaching_container != null and coaching_container.get_child_count() >= 2, "Coaching & D-Plane tab populated with analysis widgets")

	var gs := root.get_node_or_null("GlobalSettings")
	if gs != null and gs.get("range_settings") != null and gs.range_settings.get("range_units") != null:
		gs.range_settings.range_units.set_value(PhysicsEnums.Units.METRIC)
		await process_frame
		averages = analysis.get("_averages")
		keys = analysis.get("_data_keys")
		var avg_carry_m: Label = (averages[0] as HBoxContainer).get_child(keys.find("CarryDistance") + 2) as Label
		_check(avg_carry_m.text == "210.00", "Metric unit toggle converts average Carry cleanly")
		gs.range_settings.range_units.set_value(PhysicsEnums.Units.IMPERIAL)

	analysis.queue_free()
	print("  PASS: ShotAnalysisWindow & ShotAnalysisCharts verified.")


func _test_5_practice_drill_hud() -> void:
	print("\n--- Test 5: PracticeDrillHud 10-Ball Rep Tracker ---")
	var hud: PanelContainer = PracticeDrillHudScript.new()
	root.add_child(hud)
	await process_frame

	hud.call("select_drill", "start_line_gate")
	for i in range(10):
		var hla: float = 0.8 if i < 8 else 4.5
		hud.call("evaluate_shot", {"Club": "7i", "HLA": hla})

	var reps: Array = hud.get("_rep_results")
	var streak: int = int(hud.get("_streak"))
	var stats_lbl: Label = hud.get("_stats_lbl")
	_check(reps.size() == 10, "PracticeDrillHud records 10 reps in block")
	_check(streak == 0 and "80%" in stats_lbl.text, "PracticeDrillHud computes 80% pass rate cleanly")

	hud.call("reset_block")
	_check((hud.get("_rep_results") as Array).is_empty(), "reset_block clears rep dots cleanly")
	hud.queue_free()
	print("  PASS: PracticeDrillHud verified.")


func _test_6_stats_merger_and_goal_persistence() -> void:
	print("\n--- Test 6: StatsMerger swing_issues_meta & coaching_goal ---")
	var local_d: Dictionary = {
		"updated_at": 1000,
		"swing_issues": {"2026-11": {"Low Smash Factor": 3}},
		"swing_issues_meta": {"2026-11": {"analyzed_shots": 12, "by_club": {"driver": 8}}},
		"swing_issues_updated_at": 1000,
		"coaching_goal": {"title": "Old Goal", "updated_at": 1000}
	}
	var cloud_d: Dictionary = {
		"updated_at": 2000,
		"swing_issues": {"2026-11": {"Low Smash Factor": 5}},
		"swing_issues_meta": {"2026-11": {"analyzed_shots": 18, "by_club": {"driver": 10, "7i": 8}}},
		"swing_issues_updated_at": 2000,
		"coaching_goal": {"title": "New Cloud Goal", "updated_at": 2000}
	}
	var merged: Dictionary = StatsMergerScript.merge_profile_stats(local_d, cloud_d)
	var meta: Dictionary = merged.get("swing_issues_meta", {})
	_check(int(meta["2026-11"]["analyzed_shots"]) == 18, "swing_issues_meta picks max analyzed_shots across devices")
	_check(int(meta["2026-11"]["by_club"]["7i"]) == 8, "swing_issues_meta merges by_club counts")
	_check(str(merged["coaching_goal"]["title"]) == "New Cloud Goal", "coaching_goal picks newer updated_at")

	# Tombstone respect when swing_issues cleared at 2500
	cloud_d["tombstones"] = {"cleared_swing_issues_at": 2500}
	var purged: Dictionary = StatsMergerScript.merge_profile_stats(local_d, cloud_d)
	_check((purged.get("swing_issues_meta", {}) as Dictionary).is_empty(), "Cleared tombstone must purge older swing_issues_meta too")

	# MultiplayerManager normalization + goal + meta smoke test (with cleanup)
	var mp := root.get_node_or_null("MultiplayerManager")
	if mp != null:
		var tmp_name: String = "__TestAnalyticsGolfer__"
		mp.call("set_player_coaching_goal", tmp_name, {
			"issue_key": "low_smash", "title": "Raise Smash", "metric_key": "smash",
			"direction": "higher", "target_value": 1.40,
			"milestones": [{"step": 1, "target_val": 1.38}, {"step": 2, "target_val": 1.40}]
		})
		var goal_eval: Dictionary = mp.call("record_coaching_goal_shot", tmp_name, {"Club": "Driver", "SmashFactor": 1.42})
		_check(bool(goal_eval.get("passed", false)) == true, "record_coaching_goal_shot evaluates active goal")
		var saved_g: Dictionary = mp.call("get_player_coaching_goal", tmp_name)
		_check(int(saved_g.get("total_reps", 0)) == 1 and int(saved_g.get("passed_reps", 0)) == 1, "Coaching goal persists rep/pass counts")

		mp.call("record_player_swing_issues", tmp_name, [{"severity": "LOW", "issue_type": "Pure Ball Strike"}], "Driver")
		var sw_meta: Dictionary = mp.call("get_player_swing_issues_meta", tmp_name)
		_check(not sw_meta.is_empty(), "record_player_swing_issues tracks monthly_meta even for LOW severity pure shots")

		# Cleanup test artifacts in user:// JSONs
		var all_goals: Dictionary = mp.call("load_player_coaching_goals")
		all_goals.erase(tmp_name)
		mp.call("save_player_coaching_goals", all_goals)
		var all_sw: Dictionary = mp.call("load_player_swing_issues")
		all_sw.erase(tmp_name)
		mp.call("save_player_swing_issues", all_sw)

	print("  PASS: StatsMerger & persistence verified.")
