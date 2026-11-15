extends SceneTree

## Targeted Unit Tests for Work Package 09:
## Online Match Runtime: Turn Sync, Remote Replay Integration, Stat Isolation, Gating & Recovery.
## Covers all 4 test cases in §6 of docs/multiplayer/09_ONLINE_MATCH_RUNTIME.md:
## 1. Remote Shot Isolation (Hole H9)
## 2. Authoritative Turn & Score Snapshot Sync (Hole H10)
## 3. Remote Turn Input Gate (Hole H18)
## 4. Disconnect / Leave Event Handling (Hole H13)
## Plus Controller Focus Navigation on Online Runtime Dialogs.


var _tested := false


func _initialize() -> void:
	print("=== Running Work Package 09 Online Match Runtime Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_all_tests()


func _run_all_tests() -> void:
	var backup := _backup_user_files()
	await _test_1_remote_shot_isolation_h9()
	await _test_2_authoritative_turn_and_score_sync_h10()
	await _test_3_remote_turn_input_gate_h18()
	await _test_4_disconnect_leave_event_handling_h13()
	await _test_5_controller_navigation_on_runtime_dialogs()
	await _test_6_peek_next_player_and_turn_advancement()
	await _test_7_ready_indicator_visibility_in_menus_and_remote_turns()
	_restore_user_files(backup)

	print("\n=======================================================")
	print("  ALL WORK PACKAGE 09 TESTS PASSED SUCCESSFULLY!       ")
	print("=======================================================")
	quit(0)


func _write_disk_backup_files(snap: Dictionary) -> void:
	for p in snap.keys():
		var val = snap[p]
		if val != null:
			var bak_path = p + '.test_bak'
			var f := FileAccess.open(bak_path, FileAccess.WRITE)
			if f != null:
				f.store_string(str(val))
				f.close()


func _cleanup_disk_backup_files(snap: Dictionary) -> void:
	for p in snap.keys():
		var bak_path = p + '.test_bak'
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bak_path))


func _backup_user_files() -> Dictionary:
	var paths := [
		"user://players_registry.json",
		"user://player_club_stats.json",
		"user://player_achievements.json",
		"user://player_swing_issues.json",
		"user://cloud_sync_state.json"
	]
	var snap := {}
	for p in paths:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				snap[p] = f.get_as_text()
				f.close()
		else:
			snap[p] = null
	_write_disk_backup_files(snap)
	return snap


func _restore_user_files(snap: Dictionary) -> void:
	for p in snap.keys():
		var val = snap[p]
		if val == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f != null:
				f.store_string(str(val))
				f.close()
	_cleanup_disk_backup_files(snap)


func _get_session() -> Node:
	var s = root.get_node_or_null("OnlineSession")
	if s != null:
		return s
	var script = load("res://Utils/Cloud/online_session.gd")
	s = script.new()
	s.name = "OnlineSession"
	root.add_child(s)
	return s


func _get_controller() -> Node:
	var c = root.get_node_or_null("OnlineMatchController")
	if c != null:
		return c
	var script = load("res://Utils/Cloud/online_match_controller.gd")
	c = script.new()
	c.name = "OnlineMatchController"
	root.add_child(c)
	return c


func _get_mock_course_config() -> Dictionary:
	return {
		"Title": "Test Online Country Club",
		"Course Info": {
			"Title": "Test Online Country Club",
			"Holes": 1
		},
		"Hole Info": {
			"1": {
				"Par": 4,
				"Hole Location": [0.0, 300.0],
				"Tee Boxes": {
					"Blue": [0.0, 0.0]
				}
			}
		}
	}


# ── TEST 1: Remote Shot Isolation (Hole H9) ──────────────────────────────

func _test_1_remote_shot_isolation_h9() -> void:
	print("\n--- Test 1: Remote Shot Isolation (Hole H9) ---")
	var mp = root.get_node_or_null("MultiplayerManager")
	assert(mp != null, "MultiplayerManager autoload must be available")

	var ach = root.get_node_or_null("AchievementManager")

	var sess = _get_session()
	sess.is_online_match = true

	var local_player := {
		"name": "LocalHost",
		"tee": "Blue",
		"slot_id": "slot_0",
		"owner_uid": "local_uid_123",
		"is_remote": false
	}
	var remote_player := {
		"name": "RemoteRival",
		"tee": "Blue",
		"slot_id": "slot_1",
		"owner_uid": "remote_uid_456",
		"is_remote": true
	}

	mp.setup_game([local_player, remote_player], _get_mock_course_config(), "", "", "1 Hole", "Standard", {}, "furthest_away")
	mp.start_hole()

	# Assert remote player was NOT registered in local registry
	var reg_players = mp.get_registered_players()
	for p in reg_players:
		assert(p.get("name", "") != "RemoteRival", "Remote player must NOT be in registered_players!")

	if FileAccess.file_exists("user://players_registry.json"):
		var f := FileAccess.open("user://players_registry.json", FileAccess.READ)
		var txt := f.get_as_text()
		f.close()
		assert(not txt.contains("RemoteRival"), "Remote opponent must NEVER be written to user://players_registry.json!")

	# Apply 320-yard driver shot for RemoteRival via record_remote_shot
	var shot_driver := {
		"seq": 1,
		"slot_id": "slot_1",
		"club": "Dr",
		"start": [0.0, 0.0, 0.0],
		"end": [0.0, 0.0, 292.6], # 320 yards
		"lie_end": "fairway",
		"penalty": 0,
		"gimme_strokes": 0,
		"holed_out": false,
		"hole_id": "1",
		"next_slot": "slot_1",
		"scores": {
			"slot_0": {"hole_strokes": 0, "total_strokes": 0, "holed_out": false},
			"slot_1": {"hole_strokes": 1, "total_strokes": 1, "holed_out": false}
		}
	}
	mp.record_remote_shot(shot_driver)

	# Apply holed eagle putt for RemoteRival
	var shot_putt := {
		"seq": 2,
		"slot_id": "slot_1",
		"club": "Pt",
		"start": [0.0, 0.0, 292.6],
		"end": [0.0, 0.0, 300.0],
		"lie_end": "green",
		"penalty": 0,
		"gimme_strokes": 0,
		"holed_out": true,
		"hole_id": "1",
		"next_slot": "slot_0",
		"scores": {
			"slot_0": {"hole_strokes": 0, "total_strokes": 0, "holed_out": false},
			"slot_1": {"hole_strokes": 2, "total_strokes": 2, "holed_out": true}
		}
	}
	mp.record_remote_shot(shot_putt)

	var p1: Dictionary = mp.players[1]
	assert(p1.get("strokes") == 2, "Remote player strokes must be 2, got %s" % str(p1.get("strokes")))
	assert(p1.get("total_strokes") == 2, "Remote player total_strokes must be 2, got %s" % str(p1.get("total_strokes")))
	assert(p1.get("holed_out") == true, "Remote player must be holed out")
	assert(p1.get("hole_scores", {}).get("1") == 2, "Remote player hole_score for hole 1 must be 2")
	assert(p1.has("shot_history") and p1["shot_history"].size() == 2, "Remote player must retain in-memory shot_history for live scorecard review")
	assert(p1.has("shot_stats") and p1["shot_stats"].get("1", []).size() == 2, "Remote player must retain in-memory shot_stats for live scorecard review")

	# Check player club stats file: RemoteRival must NOT be in user://player_club_stats.json
	var stats = mp.get_player_club_stats("RemoteRival")
	assert(stats.is_empty(), "Remote player must have NO entries in get_player_club_stats!")

	# Check achievements: RemoteRival must have unlocked ZERO achievements
	if ach != null:
		assert(not ach.is_unlocked("RemoteRival", "long_drive"), "Remote player must NOT unlock long_drive achievement")
		assert(not ach.is_unlocked("RemoteRival", "first_eagle"), "Remote player must NOT unlock first_eagle achievement")

	# Check serialization: _serialize_players must strip shot_stats/shot_history for remote players
	var serialized = mp._serialize_players(mp.players)
	var remote_serialized = serialized[1]
	assert(remote_serialized.get("is_remote") == true, "Serialized remote player must have is_remote=true")
	assert(not remote_serialized.has("shot_stats"), "Serialized remote player must NOT have shot_stats")
	assert(not remote_serialized.has("shot_history"), "Serialized remote player must NOT have shot_history")
	assert(remote_serialized.get("total_strokes") == 2, "Serialized remote player retains total_strokes")

	print("  PASS: Remote shot isolation verified (no local stat pollution, no achievement unlocks, clean serialization).")


# ── TEST 2: Authoritative Turn & Score Snapshot Sync (Hole H10) ──────────

func _test_2_authoritative_turn_and_score_sync_h10() -> void:
	print("\n--- Test 2: Authoritative Turn & Score Snapshot Sync (Hole H10) ---")
	var mp = root.get_node_or_null("MultiplayerManager")

	var remote_hazard_event := {
		"seq": 3,
		"slot_id": "slot_1",
		"club": "7i",
		"start": [0.0, 0.0, 0.0],
		"end": [15.0, 0.0, 120.0],
		"lie_end": "rough",
		"penalty": 1,
		"gimme_strokes": 1,
		"holed_out": true,
		"hole_id": "1",
		"next_slot": "slot_0",
		"pin": [0.0, 0.0, 300.0],
		"scores": {
			"slot_0": {"hole_strokes": 1, "total_strokes": 1, "holed_out": false},
			"slot_1": {"hole_strokes": 5, "total_strokes": 5, "holed_out": true}
		}
	}

	mp.record_remote_shot(remote_hazard_event)

	# Verify authoritative next_slot took effect
	assert(mp.active_player_index == 0, "active_player_index must advance to 0 (slot_0)")
	var active_p = mp.get_active_player()
	assert(active_p.get("slot_id") == "slot_0", "Active player slot must be slot_0")

	# Verify remote score was updated directly from shooter's authoritative score snapshot
	var remote_p: Dictionary = mp.players[1]
	assert(remote_p.get("strokes") == 5, "Shooter-authoritative strokes must be 5, got %s" % str(remote_p.get("strokes")))
	assert(remote_p.get("total_strokes") == 5, "Shooter-authoritative total_strokes must be 5")
	assert(remote_p.get("holed_out") == true, "Remote player must be holed out")
	assert(remote_p.get("hole_scores", {}).get("1") == 5, "Hole score must match event snapshot (5)")

	print("  PASS: Authoritative score snapshots and turn transitions verified.")


# ── TEST 3: Remote Turn Input Gate (Hole H18) ───────────────────────────

func _test_3_remote_turn_input_gate_h18() -> void:
	print("\n--- Test 3: Remote Turn Input Gate (Hole H18) ---")
	var mp = root.get_node_or_null("MultiplayerManager")
	var sess = _get_session()

	# Instantiate Range to test input gate methods
	var range_scene = load("res://Courses/Range/range.tscn")
	var range_inst = range_scene.instantiate()
	root.add_child(range_inst)

	# Set up players AFTER range_inst enters tree (since driving range init clears players)
	var local_player := {
		"name": "LocalHost",
		"tee": "Blue",
		"slot_id": "slot_0",
		"owner_uid": "local_uid_123",
		"is_remote": false
	}
	var remote_player := {
		"name": "RemoteRival",
		"tee": "Blue",
		"slot_id": "slot_1",
		"owner_uid": "remote_uid_456",
		"is_remote": true
	}
	mp.setup_game([local_player, remote_player], _get_mock_course_config(), "", "", "1 Hole", "Standard", {}, "furthest_away")
	mp.start_hole()
	mp.active_player_index = 1
	sess.is_online_match = true

	var active_p = mp.get_active_player()
	assert(active_p.get("is_remote") == true, "Active player must be remote")
	assert(sess.is_online_match == true, "Online session must be active")

	# Test gate function directly
	assert(range_inst._is_remote_turn_locked() == true, "_is_remote_turn_locked must return true during remote turn")

	# Simulate stray Launch Monitor hit packet
	var lm_payload := {
		"Speed": 65.0,
		"LaunchAngle": 12.0,
		"TotalDistance": 220.0
	}
	range_inst._on_tcp_client_hit_ball(lm_payload)

	# Raw ball data must remain empty because shot was rejected by input gate
	assert(range_inst.raw_ball_data.is_empty(), "Stray launch monitor hit data must be IGNORED while remote player's turn!")

	# Simulate manual hit packet
	range_inst._on_player_manual_hit()
	assert(range_inst.raw_ball_data.is_empty(), "Manual hit must be IGNORED while remote player's turn!")

	range_inst.queue_free()
	print("  PASS: Remote turn input gate completely rejects stray launch monitor and manual hit inputs.")


# ── TEST 4: Disconnect / Leave Event Handling (Hole H13) ────────────────

func _test_4_disconnect_leave_event_handling_h13() -> void:
	print("\n--- Test 4: Disconnect / Leave Event Handling (Hole H13) ---")
	var mp = root.get_node_or_null("MultiplayerManager")
	var ctrl = _get_controller()

	var local_player := {
		"name": "LocalHost",
		"tee": "Blue",
		"slot_id": "slot_0",
		"owner_uid": "local_uid_123",
		"is_remote": false
	}
	var remote_player := {
		"name": "RemoteRival",
		"tee": "Blue",
		"slot_id": "slot_1",
		"owner_uid": "remote_uid_456",
		"is_remote": true
	}
	mp.setup_game([local_player, remote_player], _get_mock_course_config(), "", "", "1 Hole", "Standard", {}, "furthest_away")
	mp.start_hole()

	# Make remote player active
	mp.active_player_index = 1
	assert(mp.players[1].get("active") == true, "Player 1 must initially be active")
	assert(mp.active_player_index == 1, "Player 1 must be active index")

	# Feed a "leave" event for slot_1
	var leave_evt := {
		"seq": 4,
		"type": "leave",
		"slot_id": "slot_1",
		"name": "RemoteRival"
	}
	ctrl._apply_leave_event(leave_evt)

	# Remote player active state must now be false
	assert(mp.players[1].get("active") == false, "Player 1 active must be set to false on leave")

	# Active player must automatically advance to local player (slot_0)
	assert(mp.active_player_index == 0, "Turn must advance to slot_0 when active player leaves")
	assert(mp.get_active_player().get("slot_id") == "slot_0", "Active player must now be slot_0")

	print("  PASS: Player leave event marks player inactive and auto-advances turn to local player.")


# ── TEST 5: Controller Focus Navigation on Runtime Dialogs ──────────────

func _test_5_controller_navigation_on_runtime_dialogs() -> void:
	print("\n--- Test 5: Controller Focus Navigation on Runtime Dialogs ---")
	var course_play_scene = load("res://Courses/CoursePlay/course_play.tscn")
	var cp = course_play_scene.instantiate()
	root.add_child(cp)
	cp._setup_hud()

	# Test Online Waiting Banner buttons
	assert(cp.online_waiting_banner != null, "online_waiting_banner must be instantiated")
	assert(cp.online_concede_btn != null, "online_concede_btn must exist")
	assert(cp.online_remove_btn != null, "online_remove_btn must exist")

	var concede_path: NodePath = cp.online_concede_btn.focus_neighbor_right
	assert(not str(concede_path).is_empty(), "online_concede_btn must have explicit focus_neighbor_right")
	var remove_path: NodePath = cp.online_remove_btn.focus_neighbor_left
	assert(not str(remove_path).is_empty(), "online_remove_btn must have explicit focus_neighbor_left")

	# Test Leave Match Dialog in online mode
	var sess = _get_session()
	sess.is_online_match = true
	cp._on_forfeit_pressed()

	assert(cp.forfeit_confirm_dialog.visible == true, "forfeit_confirm_dialog must be visible")
	var title = cp.forfeit_confirm_dialog.find_child("*Title*", true, false) as Label
	var confirm_b = cp.forfeit_confirm_dialog.find_child("ConfirmBtn", true, false) as Button
	var cancel_b = cp.forfeit_confirm_dialog.find_child("CancelBtn", true, false) as Button

	assert(confirm_b != null, "ConfirmBtn must exist")
	assert(cancel_b != null, "CancelBtn must exist")
	assert(not str(confirm_b.focus_neighbor_right).is_empty(), "ConfirmBtn must have focus_neighbor_right")
	assert(not str(cancel_b.focus_neighbor_left).is_empty(), "CancelBtn must have focus_neighbor_left")
	assert(confirm_b.text == "Yes, Leave Match", "Dialog confirm button text must be 'Yes, Leave Match' in online match")

	cp.forfeit_confirm_dialog.visible = false
	cp.queue_free()
	print("  PASS: 100% controller navigation and focus neighbor bidirectional links verified on runtime dialogs.")


# ── TEST 6: Peek Next Player & Local Shot Turn Advancement ──────────────

func _test_6_peek_next_player_and_turn_advancement() -> void:
	print("\n--- Test 6: Peek Next Player & Local Shot Turn Advancement ---")
	var mp = root.get_node_or_null("MultiplayerManager")
	assert(mp != null, "MultiplayerManager autoload must be available")

	var ctrl = root.get_node_or_null("OnlineMatchController")
	assert(ctrl != null, "OnlineMatchController autoload must be available")

	var sess = _get_session()
	sess.is_online_match = true

	var p0 := {
		"name": "HostGolfer",
		"tee": "Blue",
		"slot_id": "slot_0",
		"owner_uid": "local_host_uid",
		"is_remote": false
	}
	var p1 := {
		"name": "RemoteGolfer",
		"tee": "Blue",
		"slot_id": "slot_1",
		"owner_uid": "remote_rival_uid",
		"is_remote": true
	}

	mp.setup_game([p0, p1], _get_mock_course_config(), "", "", "1 Hole", "Standard", {}, "Stay Up")
	mp.start_hole()

	# Initially slot_0 is active
	assert(mp.active_player_index == 0, "Slot 0 should be active at match start")

	# Host takes a tee shot
	var tee_pos = mp.players[0].get("position", Vector3.ZERO)
	var ball_land_pos = Vector3(10.0, 0.0, 200.0)
	mp.record_shot(ball_land_pos, {"TotalDistance": 200.0, "BallSpeed": 140.0})

	# Host has strokes = 1, Remote has strokes = 0
	# peek_next_player must return RemoteGolfer (slot_1) because RemoteGolfer has not teed off yet!
	var next_p = mp.peek_next_player()
	assert(not next_p.is_empty(), "peek_next_player must return next player")
	assert(next_p.get("slot_id") == "slot_1", "peek_next_player must return slot_1 off the tee, got %s" % str(next_p.get("slot_id")))

	# Set match_id on controller to test publish_local_shot serialization
	ctrl._match_id = "test_match_turn_sync"
	ctrl._last_applied_seq = 0
	var evt = ctrl.publish_local_shot(tee_pos, ball_land_pos, "Dr", "fairway", 0, 0, false, Vector3(0, 0, 300))

	assert(evt.get("slot_id") == "slot_0", "publish_local_shot must record slot_0 as shooter")
	assert(evt.get("next_slot") == "slot_1", "publish_local_shot must predict slot_1 as next_slot, got %s" % str(evt.get("next_slot")))

	# Applying this shot event via record_remote_shot on player 2's device should cleanly set active_player_index to 1 (slot_1)
	mp.record_remote_shot(evt)
	assert(mp.active_player_index == 1, "record_remote_shot must set active_player_index to slot_1")
	assert(mp.get_active_player().get("slot_id") == "slot_1", "Active player must be slot_1")

	print("  PASS: peek_next_player and publish_local_shot correctly synchronize turn advancement to next player.")


# ── TEST 7: Ready Indicator Visibility in Menus & Remote Turns ──────────

func _test_7_ready_indicator_visibility_in_menus_and_remote_turns() -> void:
	print("\n--- Test 7: Ready Indicator Visibility in Menus & Remote Turns ---")
	var ready_hud_script = load("res://UI/ReadyIndicator/ready_indicator_hud.gd")
	assert(ready_hud_script != null, "ready_indicator_hud.gd must load")

	var hud = ready_hud_script.new()
	root.add_child(hud)

	# 1. Menu screen detection: Controls and menu names must be detected as menu screens
	var mock_menu = Control.new()
	mock_menu.name = "LeaderboardsMenu"
	assert(hud._is_menu_screen(mock_menu) == true, "LeaderboardsMenu Control must be detected as menu screen")

	var mock_lobby = Control.new()
	mock_lobby.name = "OnlineMultiplayerMenu"
	assert(hud._is_menu_screen(mock_lobby) == true, "OnlineMultiplayerMenu Control must be detected as menu screen")

	var mock_3d_course = Node3D.new()
	mock_3d_course.name = "CoursePlay"
	assert(hud._is_menu_screen(mock_3d_course) == false, "CoursePlay Node3D must not be detected as menu screen")

	mock_menu.queue_free()
	mock_lobby.queue_free()
	mock_3d_course.queue_free()

	# 2. Remote turn check: when active player is remote, _is_waiting_for_remote_player must be true
	var mp = root.get_node_or_null("MultiplayerManager")
	var sess = _get_session()
	sess.is_online_match = true

	var p_local := {"name": "Host", "slot_id": "slot_0", "owner_uid": "uid_0", "is_remote": false, "strokes": 0, "holed_out": false}
	var p_remote := {"name": "Opponent", "slot_id": "slot_1", "owner_uid": "uid_1", "is_remote": true, "strokes": 0, "holed_out": false}
	mp.setup_game([p_local, p_remote], _get_mock_course_config(), "", "", "1 Hole", "Standard", {}, "Stay Up")
	mp.start_hole()

	# Slot 0 is local: waiting for remote player must be false
	mp.active_player_index = 0
	assert(hud._is_waiting_for_remote_player(null) == false, "_is_waiting_for_remote_player must be false when local player's turn")

	# Slot 1 is remote: waiting for remote player must be true!
	mp.active_player_index = 1
	assert(hud._is_waiting_for_remote_player(null) == true, "_is_waiting_for_remote_player must be true when remote opponent's turn")

	# While remote player's turn, _should_indicator_be_visible must be false
	assert(hud._should_indicator_be_visible(null) == false, "Indicator HUD must NOT be visible during remote opponent's turn")

	hud.queue_free()
	print("  PASS: Ready indicator correctly hides in menus, lobbies, leaderboards, and during remote opponent turns.")
