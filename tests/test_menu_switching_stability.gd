extends SceneTree

## Regression tests for menu switching stability, SceneManager re-entrancy,
## UIFocusGuard teardown, orphan node/Viewport leaks, and autoload signal cleanup.

var _started := false
var _failed := false


func _initialize() -> void:
	print("=== Running Menu Switching Stability Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _started:
		return
	_started = true
	_run_tests()


func _assert_true(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		print("  FAIL: " + msg)
		_failed = true
	else:
		print("  PASS: " + msg)


func _run_tests() -> void:
	var sm = root.get_node_or_null("SceneManager")
	var ufg = root.get_node_or_null("UIFocusGuard")
	var gs = root.get_node_or_null("GlobalSettings")
	_assert_true(sm != null, "SceneManager autoload exists")
	_assert_true(ufg != null, "UIFocusGuard autoload exists")
	if sm == null or ufg == null:
		quit(1)
		return

	# 1. Warm up MainMenu and record baseline orphan count
	sm.change_scene("res://UI/MainMenu/main_menu.tscn")
	await sm.scene_changed
	await process_frame
	await process_frame
	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	# 2. Switch across menus including PlayersMenu (previously leaked +146 nodes & 10 Viewports per visit)
	var menus := [
		"res://UI/PlayersMenu/players_menu.tscn",
		"res://UI/HistoryMenu/history_menu.tscn",
		"res://UI/Leaderboards/leaderboards_menu.tscn",
		"res://UI/MiniGamesMenu/minigames_menu.tscn",
		"res://UI/TrainingMenu/training_menu.tscn",
		"res://UI/OnlineMultiplayer/multiplayer_menu.tscn",
		"res://Courses/CoursePlay/course_play_setup.tscn",
		"res://Courses/CourseSelector/course_selector.tscn",
		"res://UI/MainMenu/main_menu.tscn",
	]
	for round_idx in range(2):
		for path in menus:
			sm.change_scene(path)
			await sm.scene_changed
			await process_frame
	await process_frame
	await process_frame

	var after_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_assert_true(
		after_orphans <= baseline_orphans,
		"No orphan node leaks across 2 full menu cycles (baseline=%d, after=%d)" % [baseline_orphans, after_orphans]
	)

	# 3. Same-frame double change_scene coalescing
	sm.change_scene("res://UI/PlayersMenu/players_menu.tscn")
	sm.change_scene("res://UI/HistoryMenu/history_menu.tscn")
	await sm.scene_changed
	await process_frame
	await process_frame
	_assert_true(
		sm.current_scene != null and is_instance_valid(sm.current_scene) and sm.current_scene.name == "HistoryMenu",
		"Same-frame double change_scene coalesces cleanly to final target (HistoryMenu)"
	)
	_assert_true(
		current_scene == sm.current_scene,
		"SceneTree.current_scene stays synchronized with SceneManager.current_scene"
	)

	# 4. UIFocusGuard modal lock stack resets cleanly on scene change
	var dummy_lock := Control.new()
	sm.current_scene.add_child(dummy_lock)
	ufg.push_lock(dummy_lock)
	_assert_true(ufg.is_modal_active(), "UIFocusGuard lock active before scene change")
	sm.load_main_menu()
	await sm.scene_changed
	await process_frame
	_assert_true(not ufg.is_modal_active(), "UIFocusGuard lock stack cleared on scene change")

	# 5. MainMenu Settings modal guards against duplicates and cleans up GlobalSettings connections
	var mm = sm.current_scene
	if mm != null and is_instance_valid(mm) and mm.has_method("_on_settings_pressed") and gs != null:
		var wind_conns_before: int = gs.wind_changed.get_connections().size()
		mm._on_settings_pressed()
		mm._on_settings_pressed() # Rapid double-click should not spawn 2 modals
		await process_frame
		var settings_nodes := 0
		for child in mm.get_children():
			if child.name.begins_with("MainMenuSettings"):
				settings_nodes += 1
		_assert_true(settings_nodes == 1, "Rapid Settings clicks open only 1 MainMenuSettings modal")
		var settings_inst = mm.get_node_or_null("MainMenuSettings")
		if settings_inst != null:
			settings_inst.emit_signal("close_settings_requested")
		await process_frame
		await process_frame
		var wind_conns_after: int = gs.wind_changed.get_connections().size()
		_assert_true(
			wind_conns_after == wind_conns_before,
			"Closing Settings disconnects GlobalSettings.wind_changed cleanly (%d -> %d)" % [wind_conns_before, wind_conns_after]
		)

	if _failed:
		print("=== MENU SWITCHING STABILITY TESTS FAILED ===")
		quit(1)
	else:
		print("=== ALL MENU SWITCHING STABILITY TESTS PASSED ===")
		quit(0)
