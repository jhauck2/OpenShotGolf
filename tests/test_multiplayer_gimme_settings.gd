extends SceneTree

## Unit test suite for Multiplayer Round Setup Gimme Settings (Match & Tournaments).
## Validates:
## 1. Online match hosting with forced gimmes applies in memory and suppresses disk saving.
## 2. Restoring online match settings resets all gimmes to player's personal settings.
## 3. Online match with local gimmes preserves player's personal settings without modification.
## 4. Tournament with forced gimmes applies and restores properly without overwriting personal settings.
## 5. UI controls in multiplayer_menu.tscn initialize and toggle correctly.

const OnlineSessionScript = preload("res://Utils/Cloud/online_session.gd")
const TournamentServiceScript = preload("res://Utils/Cloud/tournament_service.gd")

var _tested := false


func _initialize() -> void:
	print("=== Running Multiplayer Gimme Settings Unit Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_all_tests()


func _run_all_tests() -> void:
	await _test_1_online_match_forced_gimmes()
	await _test_2_online_match_local_gimmes()
	await _test_3_tournament_forced_gimmes()
	await _test_4_tournament_local_gimmes()
	await _test_5_ui_scene_components()

	print("\n=======================================================")
	print("   ALL MULTIPLAYER GIMME SETTINGS TESTS PASSED!        ")
	print("=======================================================\n")
	quit(0)


func _test_1_online_match_forced_gimmes() -> void:
	print("\n--- Test 1: Online Match Forced Gimmes Lifecycle ---")
	var gs = root.get_node_or_null("GlobalSettings")
	assert(gs != null, "GlobalSettings must exist")

	var rs = gs.range_settings
	# Establish baseline player personal settings
	rs.gimme_range_1_enabled.set_value(true)
	rs.gimme_range_1_distance.set_value(3.5)
	rs.gimme_range_2_enabled.set_value(false)
	rs.gimme_range_2_distance.set_value(8.0)
	rs.gimme_range_3_enabled.set_value(false)
	rs.gimme_range_3_distance.set_value(25.0)

	var sess = OnlineSessionScript.new()
	root.add_child(sess)

	sess.match_meta = {
		"settings": {
			"force_gimmes": true,
			"gimme_range_1_enabled": true,
			"gimme_range_1_distance": 5.5,
			"gimme_range_2_enabled": true,
			"gimme_range_2_distance": 12.0,
			"gimme_range_3_enabled": true,
			"gimme_range_3_distance": 32.0
		}
	}

	# Snapshot and apply
	sess.snapshot_and_apply_match_settings()

	# Assert forced settings are active in memory
	assert(rs.gimme_range_1_enabled.value == true, "Gimme 1 should be enabled")
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 5.5), "Gimme 1 distance should be forced 5.5")
	assert(rs.gimme_range_2_enabled.value == true, "Gimme 2 should be enabled")
	assert(is_equal_approx(rs.gimme_range_2_distance.value, 12.0), "Gimme 2 distance should be forced 12.0")
	assert(rs.gimme_range_3_enabled.value == true, "Gimme 3 should be enabled")
	assert(is_equal_approx(rs.gimme_range_3_distance.value, 32.0), "Gimme 3 distance should be forced 32.0")
	assert(gs.suppress_save == true, "Disk save should be suppressed while forced settings are active")

	# Restore settings
	sess.restore_local_settings()

	# Assert personal settings are completely restored
	assert(rs.gimme_range_1_enabled.value == true, "Gimme 1 should be restored to true")
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 3.5), "Gimme 1 distance should be restored to 3.5")
	assert(rs.gimme_range_2_enabled.value == false, "Gimme 2 should be restored to false")
	assert(is_equal_approx(rs.gimme_range_2_distance.value, 8.0), "Gimme 2 distance should be restored to 8.0")
	assert(rs.gimme_range_3_enabled.value == false, "Gimme 3 should be restored to false")
	assert(is_equal_approx(rs.gimme_range_3_distance.value, 25.0), "Gimme 3 distance should be restored to 25.0")
	assert(gs.suppress_save == false, "Disk save suppression should be released after restoring")

	sess.queue_free()
	print("Online match forced gimmes OK.")


func _test_2_online_match_local_gimmes() -> void:
	print("\n--- Test 2: Online Match Local Gimmes Preservation ---")
	var gs = root.get_node_or_null("GlobalSettings")
	var rs = gs.range_settings

	# Establish personal settings
	rs.gimme_range_1_enabled.set_value(true)
	rs.gimme_range_1_distance.set_value(4.0)
	rs.gimme_range_2_enabled.set_value(true)
	rs.gimme_range_2_distance.set_value(9.0)

	var sess = OnlineSessionScript.new()
	root.add_child(sess)

	sess.match_meta = {
		"settings": {
			"force_gimmes": false,
			"gimme_range_1_enabled": false,
			"gimme_range_1_distance": 99.0
		}
	}

	sess.snapshot_and_apply_match_settings()

	# Assert personal settings were NOT overwritten
	assert(rs.gimme_range_1_enabled.value == true, "Personal gimme 1 enabled should not be overwritten")
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 4.0), "Personal gimme 1 distance should not be overwritten")
	assert(rs.gimme_range_2_enabled.value == true, "Personal gimme 2 enabled should not be overwritten")
	assert(gs.suppress_save == false, "Save suppression should be false when not forcing gimmes")

	sess.restore_local_settings()
	assert(rs.gimme_range_1_enabled.value == true, "Personal gimme 1 remains true")
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 4.0), "Personal gimme 1 remains 4.0")

	sess.queue_free()
	print("Online match local gimmes preservation OK.")


func _test_3_tournament_forced_gimmes() -> void:
	print("\n--- Test 3: Tournament Forced Gimmes Lifecycle ---")
	var gs = root.get_node_or_null("GlobalSettings")
	var rs = gs.range_settings

	rs.gimme_range_1_enabled.set_value(true)
	rs.gimme_range_1_distance.set_value(4.0)
	rs.gimme_range_2_enabled.set_value(false)
	rs.gimme_range_3_enabled.set_value(false)

	var svc = TournamentServiceScript.new()
	root.add_child(svc)

	var t_doc := {
		"tournament_id": "T_TEST_123",
		"force_gimmes": true,
		"gimme_range_1_enabled": true,
		"gimme_range_1_distance": 6.0,
		"gimme_range_2_enabled": true,
		"gimme_range_2_distance": 14.0,
		"gimme_range_3_enabled": false,
		"gimme_range_3_distance": 30.0
	}

	svc.apply_tournament_settings(t_doc)

	assert(rs.gimme_range_1_enabled.value == true, "Tournament gimme 1 should be enabled")
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 6.0), "Tournament gimme 1 distance should be 6.0")
	assert(rs.gimme_range_2_enabled.value == true, "Tournament gimme 2 should be enabled")
	assert(is_equal_approx(rs.gimme_range_2_distance.value, 14.0), "Tournament gimme 2 distance should be 14.0")
	assert(gs.suppress_save == true, "Save should be suppressed during forced tournament round")

	svc.restore_tournament_settings()

	assert(rs.gimme_range_1_enabled.value == true, "Gimme 1 restored")
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 4.0), "Gimme 1 distance restored to 4.0")
	assert(rs.gimme_range_2_enabled.value == false, "Gimme 2 restored to false")
	assert(gs.suppress_save == false, "Save suppression released")

	svc.queue_free()
	print("Tournament forced gimmes OK.")


func _test_4_tournament_local_gimmes() -> void:
	print("\n--- Test 4: Tournament Local Gimmes Lifecycle ---")
	var gs = root.get_node_or_null("GlobalSettings")
	var rs = gs.range_settings

	rs.gimme_range_1_distance.set_value(4.25)
	rs.gimme_range_2_enabled.set_value(false)

	var svc = TournamentServiceScript.new()
	root.add_child(svc)

	var t_doc := {
		"tournament_id": "T_TEST_LOCAL",
		"force_gimmes": false,
		"gimme_range_1_enabled": false,
		"gimme_range_1_distance": 10.0
	}

	svc.apply_tournament_settings(t_doc)

	assert(is_equal_approx(rs.gimme_range_1_distance.value, 4.25), "Personal gimme distance should not change")
	assert(svc.is_tournament_settings_applied() == false, "No settings should be applied when force_gimmes is false")
	assert(gs.suppress_save == false, "Save suppression should be false")

	svc.restore_tournament_settings()
	assert(is_equal_approx(rs.gimme_range_1_distance.value, 4.25), "Personal gimme distance remains 4.25")

	svc.queue_free()
	print("Tournament local gimmes OK.")


func _test_5_ui_scene_components() -> void:
	print("\n--- Test 5: Multiplayer Menu Gimme UI Initialization & Toggles ---")
	var scene = load("res://UI/OnlineMultiplayer/multiplayer_menu.tscn")
	assert(scene != null, "multiplayer_menu.tscn should load")

	var instance = scene.instantiate()
	root.add_child(instance)

	# Verify Match host gimme controls
	assert(instance.gimme_mode_option != null, "GimmeModeOption must exist")
	assert(instance.gimme_mode_option.item_count == 2, "GimmeModeOption must have 2 options")
	assert(instance.gimme_mode_option.selected == 0, "Default selection must be 0 (Use Local Settings)")
	assert(instance.host_gimme_params_container.visible == false, "Host gimme params container should be hidden initially")

	# Simulate selecting "Force Host Settings"
	instance.gimme_mode_option.select(1)
	instance.gimme_mode_option.item_selected.emit(1)
	assert(instance.host_gimme_params_container.visible == true, "Host gimme params container should become visible")

	# Verify Tournament host gimme controls
	assert(instance.t_gimme_mode_option != null, "TGimmeModeOption must exist")
	assert(instance.t_gimme_mode_option.item_count == 2, "TGimmeModeOption must have 2 options")
	assert(instance.t_gimme_mode_option.selected == 0, "Default selection must be 0 (Use Local Settings)")
	assert(instance.t_host_gimme_params_container.visible == false, "THost gimme params container should be hidden initially")

	# Simulate selecting "Force Host Settings" for tournaments
	instance.t_gimme_mode_option.select(1)
	instance.t_gimme_mode_option.item_selected.emit(1)
	assert(instance.t_host_gimme_params_container.visible == true, "THost gimme params container should become visible")

	instance.queue_free()
	print("Multiplayer Menu Gimme UI OK.")
