extends SceneTree

## Unit & Integration Test Suite for Training Academy Mode:
## 1. Catalog integrity (8 categories, 10 drills, multipliers, VLA/Smash/Combine benchmarks)
## 2. Recommendation engine (cold start, RH/LH slicer, hooker, smash, wedge, launch, two-way dispersion, S-grade dampening)
## 3. Rhythm-game shot evaluator (5 tiers, combo multipliers, trend callouts, RH/LH handedness, session S-D summary)
## 4. Progress store save/load/personal-best roundtrip & cleanup
## 5. Scene integration (Main Menu 3x3 grid + TrainingButton, TrainingMenu UI, TrainingArena 3D props & drill completion)

const Catalog = preload("res://Courses/Training/training_catalog.gd")
const ProgressStore = preload("res://Courses/Training/training_progress_store.gd")
const Recommender = preload("res://Courses/Training/training_recommendation_engine.gd")
const ShotEvaluator = preload("res://Courses/Training/training_shot_evaluator.gd")

const TEST_PROGRESS_PATH := "user://test_training_progress.json"

var _tested := false
var _tests_completed := 0


func _initialize() -> void:
	print("=== Running Training Academy Mode Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_all_tests()


func _cleanup_test_progress() -> void:
	if FileAccess.file_exists(TEST_PROGRESS_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("test_training_progress.json")


func _run_all_tests() -> void:
	_cleanup_test_progress()

	_test_1_catalog_integrity()
	_test_2_recommendation_engine()
	_test_3_shot_evaluator_and_trends()
	_test_4_progress_store()
	await _test_5_scene_and_ui_integration()

	_cleanup_test_progress()
	if _tests_completed != 5:
		push_error("Expected 5 completed test groups, got %d" % _tests_completed)
		quit(1)
		return
	print("\n=======================================================")
	print("   ALL TRAINING ACADEMY UNIT TESTS PASSED! ")
	print("=======================================================\n")
	quit(0)


# ── TEST 1: CATALOG INTEGRITY ─────────────────────────────────────────────────
func _test_1_catalog_integrity() -> void:
	print("\n--- Test 1: Catalog Integrity ---")
	var cats := Catalog.get_categories()
	assert(cats.size() == 8, "Expected 8 focus categories, got %d" % cats.size())

	var drills := Catalog.get_all_drills()
	assert(drills.size() == 10, "Expected 10 drills, got %d" % drills.size())

	var cat_ids := {}
	for c in cats:
		cat_ids[c["id"]] = true
		for d_id in c["drills"]:
			var d := Catalog.get_drill(d_id)
			assert(d.get("id", "") == d_id, "Category '%s' drill '%s' must resolve" % [c["id"], d_id])

	for d in drills:
		assert(cat_ids.has(d["category_id"]), "Drill '%s' category '%s' must be valid" % [d["id"], d["category_id"]])
		assert(int(d["reps"]) >= 8, "Drill '%s' must have at least 8 reps" % d["id"])

	var b_mult := Catalog.get_difficulty_multiplier("beginner")
	var s_mult := Catalog.get_difficulty_multiplier("standard")
	var p_mult := Catalog.get_difficulty_multiplier("pro")
	assert(b_mult > s_mult and s_mult > p_mult, "Difficulty multipliers must obey beginner > standard > pro")

	var dr_vla := Catalog.get_optimal_vla_window("Dr")
	var sw_vla := Catalog.get_optimal_vla_window("Sw")
	assert(float(sw_vla["ideal"]) > float(dr_vla["ideal"]), "Wedge ideal VLA must exceed Driver ideal VLA")

	assert(Catalog.get_expected_smash("Dr") > Catalog.get_expected_smash("7i"), "Driver expected smash > 7i")
	assert(Catalog.get_expected_smash("7i") > Catalog.get_expected_smash("Sw"), "7i expected smash > Sw")

	var st0 := Catalog.get_combine_stage_config(0)
	var st9 := Catalog.get_combine_stage_config(9)
	assert(st0["club"] == "Sw" and int(st0["distance_yds"]) == 60, "Combine stage 0 must be 60yd Sw")
	assert(st9["club"] == "Dr" and st9["mode"] == "corridor", "Combine stage 9 must be Driver corridor")
	print("  PASS: Catalog categories, drills, multipliers, and benchmarks verified.")
	_tests_completed += 1


# ── TEST 2: RECOMMENDATION ENGINE ─────────────────────────────────────────────
func _test_2_recommendation_engine() -> void:
	print("\n--- Test 2: Smart Recommendation Engine ---")
	var empty_issues := {"all_time": {}, "monthly": {}}

	# 1. Cold start (< 5 shots)
	var cold := Recommender.recommend_from_data({}, {}, empty_issues, {}, 0, "mid_handicap", {})
	assert(bool(cold["is_cold_start"]) == true, "Empty telemetry must trigger cold start")
	assert(cold["primary"]["drill_id"] == "skill_combine", "Cold start must recommend skill_combine")

	# 2. Right-handed slicer
	var rh_slice_shots := []
	for i in range(8):
		rh_slice_shots.append({"CarryDistance": 195.0, "SideDistance": 22.0, "FaceToPath": 5.5, "SpinAxis": 14.0})
	var rh_slice_avgs := {"Dr": {"shot_count": 8, "shots": rh_slice_shots, "avg_offline_m": 22.0, "has_smash_factor": false}}
	var rh_slice_issues := {"all_time": {"Slice / Open Face-to-Path": 4}, "monthly": {}}
	var rec_rh_slice := Recommender.recommend_from_data(rh_slice_avgs, {"Dr": rh_slice_shots}, rh_slice_issues, {}, 0, "mid_handicap", {})
	assert(not bool(rec_rh_slice["is_cold_start"]), "8 shots must not be cold start")
	assert(rec_rh_slice["primary"]["drill_id"] == "slice_cure", "RH slicer must be prescribed slice_cure, got %s" % rec_rh_slice["primary"]["drill_id"])
	assert(not rec_rh_slice["primary"]["evidence"].is_empty(), "Recommendation must include evidence")

	# 3. Left-handed slicer (handedness = 1, misses LEFT with negative FaceToPath)
	var lh_slice_shots := []
	for i in range(8):
		lh_slice_shots.append({"CarryDistance": 195.0, "SideDistance": -21.0, "FaceToPath": -5.2, "SpinAxis": -13.0})
	var lh_slice_avgs := {"Dr": {"shot_count": 8, "shots": lh_slice_shots, "avg_offline_m": 21.0, "has_smash_factor": false}}
	var rec_lh_slice := Recommender.recommend_from_data(lh_slice_avgs, {"Dr": lh_slice_shots}, empty_issues, {}, 1, "mid_handicap", {})
	assert(rec_lh_slice["primary"]["drill_id"] == "slice_cure", "LH slicer (left miss) must be prescribed slice_cure, got %s" % rec_lh_slice["primary"]["drill_id"])

	# 4. Right-handed hooker (misses LEFT with negative FTP)
	var rh_hook_shots := []
	for i in range(8):
		rh_hook_shots.append({"CarryDistance": 205.0, "SideDistance": -20.0, "FaceToPath": -5.0, "SpinAxis": -12.0})
	var rh_hook_avgs := {"Dr": {"shot_count": 8, "shots": rh_hook_shots, "avg_offline_m": 20.0, "has_smash_factor": false}}
	var rh_hook_issues := {"all_time": {"Hook / Closed Face-to-Path": 3}, "monthly": {}}
	var rec_hook := Recommender.recommend_from_data(rh_hook_avgs, {"Dr": rh_hook_shots}, rh_hook_issues, {}, 0, "mid_handicap", {})
	assert(rec_hook["primary"]["drill_id"] == "hook_tamer", "RH hooker must be prescribed hook_tamer, got %s" % rec_hook["primary"]["drill_id"])

	# 5. Low smash factor + off-center face impact
	var smash_shots := []
	for i in range(7):
		smash_shots.append({"CarryDistance": 120.0, "SideDistance": 2.0, "BallSpeed": 95.0, "ClubSpeed": 88.0, "SmashFactor": 1.08})
	var smash_avgs := {
		"7i": {
			"shot_count": 7,
			"shots": smash_shots,
			"avg_smash_factor": 1.08,
			"has_smash_factor": true,
			"has_impact_data": true,
			"impact_points": [{"h": 16.0, "v": -6.0}, {"h": 14.0, "v": 4.0}]
		}
	}
	var smash_issues := {"all_time": {"Low Smash Factor": 3}, "monthly": {}}
	var rec_smash := Recommender.recommend_from_data(smash_avgs, {"7i": smash_shots}, smash_issues, {}, 0, "mid_handicap", {})
	assert(rec_smash["primary"]["drill_id"] == "sweet_spot_strike", "Low smash must prescribe sweet_spot_strike, got %s" % rec_smash["primary"]["drill_id"])

	# 6. High wedge carry scatter / target diff
	var wedge_shots := [
		{"CarryDistance": 45.0, "SideDistance": 2.0, "TargetDistance": 75.0},
		{"CarryDistance": 98.0, "SideDistance": 3.0, "TargetDistance": 75.0},
		{"CarryDistance": 52.0, "SideDistance": -1.0, "TargetDistance": 75.0},
		{"CarryDistance": 95.0, "SideDistance": 2.0, "TargetDistance": 75.0},
		{"CarryDistance": 50.0, "SideDistance": 1.0, "TargetDistance": 75.0},
		{"CarryDistance": 96.0, "SideDistance": -2.0, "TargetDistance": 75.0}
	]
	var wedge_avgs := {"Sw": {"shot_count": 6, "shots": wedge_shots, "has_smash_factor": false}}
	var rec_wedge := Recommender.recommend_from_data(wedge_avgs, {"Sw": wedge_shots}, empty_issues, {}, 0, "mid_handicap", {})
	assert(rec_wedge["primary"]["drill_id"] == "wedge_clock", "High wedge scatter must prescribe wedge_clock, got %s" % rec_wedge["primary"]["drill_id"])

	# 7. Severe VLA deviation + launch swing issue
	var vla_shots := []
	for i in range(6):
		vla_shots.append({"CarryDistance": 135.0, "SideDistance": 1.0, "VLA": 9.5})
	var vla_avgs := {"7i": {"shot_count": 6, "shots": vla_shots, "has_smash_factor": false}}
	var vla_issues := {"all_time": {"Low Driver Launch": 2}, "monthly": {}}
	var rec_vla := Recommender.recommend_from_data(vla_avgs, {"7i": vla_shots}, vla_issues, {}, 0, "mid_handicap", {})
	assert(rec_vla["primary"]["drill_id"] == "launch_window", "Extreme low launch must prescribe launch_window, got %s" % rec_vla["primary"]["drill_id"])

	# 8. Wide two-way driver dispersion -> fairway_finder
	var twoway_shots := [
		{"CarryDistance": 210.0, "SideDistance": -18.0},
		{"CarryDistance": 212.0, "SideDistance": 19.0},
		{"CarryDistance": 208.0, "SideDistance": -17.0},
		{"CarryDistance": 215.0, "SideDistance": 18.0},
		{"CarryDistance": 205.0, "SideDistance": -16.0},
		{"CarryDistance": 210.0, "SideDistance": 17.0}
	]
	var twoway_avgs := {"Dr": {"shot_count": 6, "shots": twoway_shots, "has_smash_factor": false}}
	var rec_twoway := Recommender.recommend_from_data(twoway_avgs, {"Dr": twoway_shots}, empty_issues, {}, 0, "mid_handicap", {})
	assert(rec_twoway["primary"]["drill_id"] == "fairway_finder", "Two-way driver spray must prescribe fairway_finder, got %s" % rec_twoway["primary"]["drill_id"])

	# 9. S-grade mastery dampening
	var rec_mastered := Recommender.recommend_from_data(twoway_avgs, {"Dr": twoway_shots}, empty_issues, {}, 0, "mid_handicap", {"drills": {"fairway_finder": {"best_grade": "S"}}})
	assert(float(rec_mastered["primary"]["score"]) < float(rec_twoway["primary"]["score"]), "S-grade mastery must dampen score")
	print("  PASS: All recommendation scenarios verified accurately.")
	_tests_completed += 1


# ── TEST 3: SHOT EVALUATOR & TRENDS ───────────────────────────────────────────
func _test_3_shot_evaluator_and_trends() -> void:
	print("\n--- Test 3: Rhythm Shot Evaluator, Combos & Trends ---")
	var fw_drill := Catalog.get_drill("fairway_finder")
	var stage := {"mode": "corridor", "distance_yds": 240.0, "club": "Dr", "thresholds": fw_drill["thresholds"], "min_carry_yds": 140.0}
	var hist: Array = []

	# Shot 1: MISS (30 yds offline)
	var r1 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 230.0, "side_yds": 30.0}, stage, hist, "standard", 0)
	assert(r1["tier"] == ShotEvaluator.TIER_MISS, "30 yds offline must be MISS")
	assert(int(r1["streak_after"]) == 0, "MISS must keep streak at 0")
	hist.append(r1)

	# Shot 2: OK (20 yds offline) -> getting closer!
	var r2 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 230.0, "side_yds": 20.0}, stage, hist, "standard", 0)
	assert(r2["tier"] == ShotEvaluator.TIER_OK, "20 yds offline must be OK")
	assert(r2["trend_type"] in ["closer", "much_closer"], "30 -> 20 yds must show closer trend, got %s" % r2["trend_type"])
	hist.append(r2)

	# Shot 3: GOOD (14 yds offline) -> streak = 1
	var r3 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 235.0, "side_yds": 14.0}, stage, hist, "standard", 0)
	assert(r3["tier"] == ShotEvaluator.TIER_GOOD, "14 yds offline must be GOOD")
	assert(int(r3["streak_after"]) == 1, "GOOD must start streak = 1")
	hist.append(r3)

	# Shot 4: GREAT (8 yds offline) -> streak = 2 -> mult = 2
	var r4 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 238.0, "side_yds": 8.0}, stage, hist, "standard", 0)
	assert(r4["tier"] == ShotEvaluator.TIER_GREAT, "8 yds offline must be GREAT")
	assert(int(r4["streak_after"]) == 2 and int(r4["multiplier"]) == 2, "Streak 2 must give x2 multiplier")
	assert(int(r4["points_awarded"]) == 150, "GREAT x2 must award 150 pts")
	hist.append(r4)

	# Shot 5: PERFECT (2 yds offline) -> streak = 3
	var r5 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 240.0, "side_yds": 2.0}, stage, hist, "standard", 0)
	assert(r5["tier"] == ShotEvaluator.TIER_PERFECT, "2 yds offline must be PERFECT")
	hist.append(r5)

	# Shot 6: PERFECT again -> streak = 4 -> mult = 3, perfect_streak trend!
	var r6 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 242.0, "side_yds": 1.5}, stage, hist, "standard", 0)
	assert(r6["tier"] == ShotEvaluator.TIER_PERFECT)
	assert(int(r6["streak_after"]) == 4 and int(r6["multiplier"]) == 3, "Streak 4 must give x3 multiplier")
	assert(r6["trend_type"] == "perfect_streak", "Consecutive perfects must trigger perfect_streak")
	hist.append(r6)

	# Shot 7: OK (19 yds offline) -> holds streak at 4, reports further_away
	var r7 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 230.0, "side_yds": 19.0}, stage, hist, "standard", 0)
	assert(r7["tier"] == ShotEvaluator.TIER_OK)
	assert(int(r7["streak_after"]) == 4, "OK tier must preserve streak without resetting")
	assert(r7["trend_type"] in ["further_away", "drifting_worse"], "Jumping from 1.5 -> 19 yds must warn further away")
	hist.append(r7)

	# Shot 8: MISS again -> resets streak to 0 and flags drifting_worse
	var r8 := ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 225.0, "side_yds": 32.0}, stage, hist, "standard", 0)
	assert(r8["tier"] == ShotEvaluator.TIER_MISS and int(r8["streak_after"]) == 0, "MISS must reset streak to 0")
	assert(r8["trend_type"] == "drifting_worse", "Second consecutive worsening shot must trigger drifting_worse")

	# Handedness test for slice_cure & shape_gate
	var slice_drill := Catalog.get_drill("slice_cure")
	var slice_stage := {"mode": "slice_corridor", "distance_yds": 230.0, "thresholds": slice_drill["thresholds"], "min_carry_yds": 135.0}
	var rh_right := ShotEvaluator.evaluate_shot(slice_drill, {"carry_yds": 220.0, "side_yds": 15.0}, slice_stage, [], "standard", 0)
	var lh_right := ShotEvaluator.evaluate_shot(slice_drill, {"carry_yds": 220.0, "side_yds": 15.0}, slice_stage, [], "standard", 1)
	assert(float(rh_right["error_value"]) > float(lh_right["error_value"]), "Right miss must penalize RH slicer more than LH slicer")

	var shape_drill := Catalog.get_drill("shot_shaper")
	var draw_stage := {"mode": "shape_gate", "distance_yds": 145.0, "shape": "draw", "shape_offset_yds": 12.0, "thresholds": shape_drill["thresholds"]}
	var rh_draw_ok := ShotEvaluator.evaluate_shot(shape_drill, {"carry_yds": 145.0, "side_yds": -11.5, "spin_axis_deg": -8.0}, draw_stage, [], "standard", 0)
	var lh_draw_ok := ShotEvaluator.evaluate_shot(shape_drill, {"carry_yds": 145.0, "side_yds": 11.5, "spin_axis_deg": 8.0}, draw_stage, [], "standard", 1)
	assert(rh_draw_ok["tier"] == ShotEvaluator.TIER_PERFECT and lh_draw_ok["tier"] == ShotEvaluator.TIER_PERFECT, "RH draw (-Z) and LH draw (+Z) must both grade PERFECT")

	# Session summary grading
	var perf_shots: Array = []
	for i in range(10):
		perf_shots.append(ShotEvaluator.evaluate_shot(fw_drill, {"carry_yds": 240.0, "side_yds": 1.0}, stage, perf_shots, "standard", 0))
	var summary_s := ShotEvaluator.compute_session_summary(fw_drill, perf_shots)
	assert(summary_s["grade"] == "S" and int(summary_s["max_streak"]) == 10, "10 perfect shots must grade S with streak 10")
	print("  PASS: Evaluator tiers, multipliers, trends, handedness, and S-D grading verified.")
	_tests_completed += 1


# ── TEST 4: PROGRESS STORE ────────────────────────────────────────────────────
func _test_4_progress_store() -> void:
	print("\n--- Test 4: Progress Store Persistence ---")
	var res1 := ProgressStore.record_session("TestGolfer", "fairway_finder", {
		"total_score": 450,
		"avg_accuracy": 68.5,
		"grade": "B",
		"max_streak": 3
	}, "standard", TEST_PROGRESS_PATH)
	assert(bool(res1["is_new_best_score"]) and bool(res1["is_new_best_grade"]))

	var res2 := ProgressStore.record_session("TestGolfer", "fairway_finder", {
		"total_score": 1200,
		"avg_accuracy": 91.2,
		"grade": "S",
		"max_streak": 7
	}, "standard", TEST_PROGRESS_PATH)
	assert(bool(res2["is_new_best_score"]) and bool(res2["is_new_best_grade"]))

	var res3 := ProgressStore.record_session("TestGolfer", "fairway_finder", {
		"total_score": 300,
		"avg_accuracy": 50.0,
		"grade": "C",
		"max_streak": 1
	}, "standard", TEST_PROGRESS_PATH)
	assert(not bool(res3["is_new_best_score"]) and not bool(res3["is_new_best_grade"]))

	var best := ProgressStore.get_drill_best("TestGolfer", "fairway_finder", TEST_PROGRESS_PATH)
	assert(int(best["best_score"]) == 1200, "Best score must stay 1200")
	assert(best["best_grade"] == "S", "Best grade must stay S")
	assert(int(best["sessions_completed"]) == 3, "Sessions completed must equal 3")
	print("  PASS: Progress store roundtrip & personal best tracking verified.")
	_tests_completed += 1


# ── TEST 5: SCENE & UI INTEGRATION ────────────────────────────────────────────
func _test_5_scene_and_ui_integration() -> void:
	print("\n--- Test 5: Main Menu, TrainingMenu & TrainingArena Integration ---")

	# 1. Main Menu 2x4 grid, TrainingButton hidden from menu, and valid 4-way focus neighbors
	var main_menu_scene := load("res://UI/MainMenu/main_menu.tscn") as PackedScene
	assert(main_menu_scene != null, "main_menu.tscn must load")
	var main_menu := main_menu_scene.instantiate()
	root.add_child(main_menu)
	await process_frame

	var training_btn := main_menu.get_node_or_null("VerticalLayout/TilesRow/TrainingTile/TrainingTextBackdrop/TrainingButton") as Button
	assert(training_btn == null, "TrainingButton must be removed from MainMenu")
	var tiles_row := main_menu.get_node_or_null("VerticalLayout/TilesRow") as GridContainer
	assert(tiles_row != null and tiles_row.columns == 4, "TilesRow must be a 4-column (2x4) grid")

	for tile in tiles_row.get_children():
		var btn := tile.find_child("*Button*", true, false) as Button
		assert(btn != null, "Every tile must contain a Button")
		assert(not btn.focus_neighbor_left.is_empty() and main_menu.get_node_or_null(btn.focus_neighbor_left) is Control)
		assert(not btn.focus_neighbor_right.is_empty() and main_menu.get_node_or_null(btn.focus_neighbor_right) is Control)
		assert(not btn.focus_neighbor_top.is_empty() and main_menu.get_node_or_null(btn.focus_neighbor_top) is Control)
		assert(not btn.focus_neighbor_bottom.is_empty() and main_menu.get_node_or_null(btn.focus_neighbor_bottom) is Control)

	if root.has_node("SceneManager"):
		var sm := root.get_node("SceneManager")
		if sm.current_scene == main_menu:
			sm.current_scene = null
	main_menu.queue_free()
	await process_frame

	# 2. TrainingMenu scene
	var tm_scene := load("res://UI/TrainingMenu/training_menu.tscn") as PackedScene
	assert(tm_scene != null, "training_menu.tscn must load")
	var tm := tm_scene.instantiate()
	root.add_child(tm)
	await process_frame

	var goal_grid := tm.find_child("GoalGrid", true, false)
	assert(goal_grid != null and goal_grid.get_child_count() == 8, "TrainingMenu must display 8 goal cards")
	tm.select_category("fix_slice")
	assert(tm.get_selected_drill_id() == "slice_cure", "Selecting fix_slice must prescribe slice_cure")
	tm.trigger_suggest_drill()
	assert(not tm.get_selected_drill_id().is_empty(), "Suggest drill must populate a drill")

	tm.queue_free()
	await process_frame

	# 3. TrainingArena scene across key visual modes + full 10-shot drill completion
	var arena_scene := load("res://Courses/Training/training_arena.tscn") as PackedScene
	assert(arena_scene != null, "training_arena.tscn must load")
	Catalog.set_active_session("fairway_finder", "TestGolfer", "standard")
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await process_frame

	for mode_drill in ["wedge_clock", "approach_bullseye", "launch_window", "shot_shaper", "skill_combine", "fairway_finder"]:
		arena.configure_session_for_test(mode_drill, "TestGolfer", "standard", 0, TEST_PROGRESS_PATH)
		await process_frame
		var props := arena.get_node_or_null("DrillProps")
		assert(props != null and props.get_child_count() > 0, "Drill '%s' must spawn 3D props" % mode_drill)

	# Complete a full 10-shot drill cleanly via submit_shot_for_test
	for i in range(10):
		var res: Dictionary = arena.submit_shot_for_test({"carry_yds": 240.0, "side_yds": 2.0})
		assert(res.get("tier", "") == ShotEvaluator.TIER_PERFECT, "Shot %d must evaluate PERFECT" % i)

	await process_frame
	var summary_modal := arena.find_child("DrillSummaryModal", true, false)
	assert(summary_modal != null and summary_modal.visible, "Summary modal must appear after drill completion")

	arena.queue_free()
	await process_frame
	print("  PASS: MainMenu, TrainingMenu, and TrainingArena integration verified.")
	_tests_completed += 1
