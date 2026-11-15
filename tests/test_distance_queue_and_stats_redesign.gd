extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("===================================================================")
	print("  RUNNING STATS PANEL REDESIGN & DISTANCE QUEUE TESTS             ")
	print("===================================================================")

	# ---------------------------------------------------------
	# PART 1: STATS PANEL REDESIGN (3-COLUMN BY 5-ROW GRID)
	# ---------------------------------------------------------
	print("\n--- TEST 1: Stats Panel 3x5 Grid Layout ---")
	var grid_canvas_script = load("res://UI/grid_canvas.gd")
	assert(grid_canvas_script != null, "grid_canvas.gd must load")

	# Row 0 (indices 0, 1, 2)
	var pos0 = grid_canvas_script.get_slot_position(0)
	var pos1 = grid_canvas_script.get_slot_position(1)
	var pos2 = grid_canvas_script.get_slot_position(2)
	assert(pos0 == Vector2(0.0, 485.0), "Slot 0 must be at (0, 485), got: %s" % str(pos0))
	assert(pos1 == Vector2(106.0, 485.0), "Slot 1 must be at (106, 485), got: %s" % str(pos1))
	assert(pos2 == Vector2(212.0, 485.0), "Slot 2 must be at (212, 485), got: %s" % str(pos2))

	# Row 1 (indices 3, 4, 5)
	var pos3 = grid_canvas_script.get_slot_position(3)
	var pos4 = grid_canvas_script.get_slot_position(4)
	var pos5 = grid_canvas_script.get_slot_position(5)
	assert(pos3 == Vector2(0.0, 555.0), "Slot 3 must be at (0, 555), got: %s" % str(pos3))
	assert(pos4 == Vector2(106.0, 555.0), "Slot 4 must be at (106, 555), got: %s" % str(pos4))
	assert(pos5 == Vector2(212.0, 555.0), "Slot 5 must be at (212, 555), got: %s" % str(pos5))

	# Row 3 (indices 9, 10, 11) - Completing the 12-metric 3x4 block
	var pos11 = grid_canvas_script.get_slot_position(11)
	assert(pos11 == Vector2(212.0, 695.0), "Slot 11 must be at (212, 695), got: %s" % str(pos11))

	# Row 4 (indices 12, 13, 14) - Up to 14 metrics + Add/Remove button
	var pos12 = grid_canvas_script.get_slot_position(12)
	var pos14 = grid_canvas_script.get_slot_position(14)
	assert(pos12 == Vector2(0.0, 765.0), "Slot 12 must be at (0, 765), got: %s" % str(pos12))
	assert(pos14 == Vector2(212.0, 765.0), "Slot 14 must be at (212, 765), got: %s" % str(pos14))

	assert(StatDefinitions.MAX_DISPLAYED_STATS == 14, "MAX_DISPLAYED_STATS must be 14 for 3x5 grid with Add/Remove button")
	print("  PASS: 3-column by 5-row grid layout math and MAX_DISPLAYED_STATS verified.")

	# ---------------------------------------------------------
	# PART 2: MULTI-PLAYER DISTANCE QUEUE DATA & SORTING
	# ---------------------------------------------------------
	print("\n--- TEST 2: Multi-Player Distance Queue Sorting & Formatting ---")
	var root_node = root
	var mp_mgr = root_node.get_node_or_null("/root/MultiplayerManager")
	if mp_mgr == null:
		var mp_script = load("res://Utils/MultiplayerManager.gd")
		mp_mgr = mp_script.new()
		mp_mgr.name = "MultiplayerManager"
		root_node.add_child(mp_mgr)

	var gs = root_node.get_node_or_null("/root/GlobalSettings")
	if gs == null:
		var gs_script = load("res://Utils/Settings/global_settings.gd")
		gs = gs_script.new()
		gs.name = "GlobalSettings"
		root_node.add_child(gs)

	# Setup a 5-player match with a pin at Vector3(0, 0, 350)
	var pin_pos = Vector3(0.0, 0.0, 350.0)
	mp_mgr.hole_ids = ["hole_0", "hole_1"]
	mp_mgr.hole_info = {
		"hole_0": {"Par": 4, "Name": "Hole 0"},
		"hole_1": {"Par": 4, "Name": "Hole 1", "Hole Location": [0.0, 350.0]}
	}
	mp_mgr.current_hole_index = 1
	mp_mgr.game_mode = "Standard"

	var test_players: Array[Dictionary] = [
		{
			"name": "Practice Player",
			"position": Vector3(0, 0, 0),
			"strokes": 0,
			"total_strokes": 0,
			"hole_scores": {},
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Marcus Vance",
			"position": Vector3(0, 0, 100), # 250m to pin = ~273 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 5}, # +1 relative to par 4
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Tyler Johnson",
			"position": Vector3(0, 0, 180), # 170m to pin = ~186 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 4}, # E
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Alex Kim",
			"position": Vector3(0, 0, 250), # 100m to pin = ~109 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 3}, # -1
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "David Miller",
			"position": Vector3(0, 0, 300), # 50m to pin = ~55 yds (closest, should be excluded by 3-player slice)
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 4},
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		}
	]
	mp_mgr.players = test_players
	mp_mgr.active_player_index = 0 # "Practice Player" is active

	# Test name formatting helper
	assert(mp_mgr.format_queue_player_name("Marcus Vance") == "M. Vance", "Marcus Vance should format to M. Vance")
	assert(mp_mgr.format_queue_player_name("Tyler Johnson") == "T. Johnson", "Tyler Johnson should format to T. Johnson")
	assert(mp_mgr.format_queue_player_name("A. Kim") == "A. Kim", "A. Kim should stay A. Kim")

	var queue = mp_mgr.get_distance_queue(pin_pos)
	assert(queue.size() == 3, "Queue must be capped at 3 players, got: %d" % queue.size())

	# Active player excluded
	for item in queue:
		assert(item["name"] != "Practice Player", "Active player must be excluded from distance queue")

	# Order must be furthest to closest (descending distance)
	assert(queue[0]["name"] == "Marcus Vance", "First player in queue must be Marcus Vance (furthest), got: %s" % queue[0]["name"])
	assert(queue[0]["formatted_name"] == "M. Vance", "Formatted name must be M. Vance")
	assert(queue[0]["score_str"] == "+1", "Score must be +1, got: %s" % queue[0]["score_str"])
	assert(queue[0]["distance_yards"] > queue[1]["distance_yards"], "Queue must sort descending by distance")

	assert(queue[1]["name"] == "Tyler Johnson", "Second player in queue must be Tyler Johnson, got: %s" % queue[1]["name"])
	assert(queue[1]["formatted_name"] == "T. Johnson", "Formatted name must be T. Johnson")
	assert(queue[1]["score_str"] == "E", "Score must be E, got: %s" % queue[1]["score_str"])

	assert(queue[2]["name"] == "Alex Kim", "Third player in queue must be Alex Kim, got: %s" % queue[2]["name"])
	assert(queue[2]["formatted_name"] == "A. Kim", "Formatted name must be A. Kim")
	assert(queue[2]["score_str"] == "-1", "Score must be -1, got: %s" % queue[2]["score_str"])

	# Check club suggestion populated
	for item in queue:
		assert(not item["suggested_club"].is_empty(), "Suggested club must not be empty for %s" % item["name"])
	
	# Test holed-out player remains in queue with 0 distance and "-" club
	test_players[1]["holed_out"] = true
	var queue_with_holed = mp_mgr.get_distance_queue(pin_pos)
	assert(queue_with_holed.size() == 3, "Queue must still retain 3 players with holed-out player, got: %d" % queue_with_holed.size())
	assert(queue_with_holed[0]["name"] == "Tyler Johnson", "Active players must sort before holed out players")
	assert(queue_with_holed[1]["name"] == "Alex Kim", "Active players must sort before holed out players")
	assert(queue_with_holed[2]["name"] == "David Miller", "Active David Miller (55 yds) takes priority over holed-out Marcus")

	# When another player holes out so fewer than 3 active remain, holed-out players appear
	test_players[4]["holed_out"] = true
	var queue_with_two_holed = mp_mgr.get_distance_queue(pin_pos)
	assert(queue_with_two_holed.size() == 3, "Queue must still retain 3 players")
	assert(queue_with_two_holed[0]["name"] == "Tyler Johnson", "Active player 1")
	assert(queue_with_two_holed[1]["name"] == "Alex Kim", "Active player 2")
	assert(queue_with_two_holed[2]["name"] == "Marcus Vance", "Holed-out player must remain in queue after active players")
	assert(queue_with_two_holed[2]["distance_yards"] == 0, "Holed-out player must have 0 distance yards")
	assert(queue_with_two_holed[2]["distance_str"] == "0 Yds", "Holed-out player must display '0 Yds', got: %s" % queue_with_two_holed[2]["distance_str"])
	assert(queue_with_two_holed[2]["suggested_club"] == "-", "Holed-out player suggested club must be '-'")
	assert(queue_with_two_holed[2]["holed_out"] == true, "holed_out flag must be true")
	test_players[1]["holed_out"] = false
	test_players[4]["holed_out"] = false
	
	print("  PASS: Distance queue filtering, descending sorting, 3-player slice, and holed-out retention verified.")

	# ---------------------------------------------------------
	# PART 3: TOP-LEFT HUD WIDGET IN COURSE PLAY & TURN TRANSITION
	# ---------------------------------------------------------
	print("\n--- TEST 3: CoursePlay TopLeftHUDWidget Distance Queue Injection ---")
	var cp_script = load("res://Courses/CoursePlay/course_play.gd")
	assert(cp_script != null, "course_play.gd must load")

	var cp = Node3D.new()
	cp.set_script(cp_script)
	root_node.add_child(cp)
	await process_frame

	assert(cp.hud_distance_queue_panel != null, "hud_distance_queue_panel must exist in CoursePlay")
	assert(cp.hud_distance_queue_vbox != null, "hud_distance_queue_vbox must exist in CoursePlay")

	# Update HUD with active player
	cp._update_top_hud(mp_mgr.players[0])
	await process_frame

	assert(cp.hud_distance_queue_panel.visible == true, "Distance queue panel must be visible with multiplayer queue")
	assert(cp.hud_distance_queue_vbox.get_child_count() == 3, "Distance queue VBox must have 3 child rows, got: %d" % cp.hud_distance_queue_vbox.get_child_count())

	# Inspect first row
	var row0 = cp.hud_distance_queue_vbox.get_child(0) as HBoxContainer
	assert(row0 != null, "Row 0 must be an HBoxContainer")
	var name_lbl = row0.get_child(0) as Label
	var score_lbl = row0.get_child(1) as Label
	var dist_lbl = row0.get_child(2) as Label
	var club_lbl = row0.get_child(3) as Label

	assert(name_lbl.text == "M. Vance", "Row 0 name should be M. Vance, got: %s" % name_lbl.text)
	assert(score_lbl.text == "+1", "Row 0 score should be +1, got: %s" % score_lbl.text)
	assert(dist_lbl.text.ends_with("Yds"), "Row 0 distance should end with 'Yds', got: %s" % dist_lbl.text)
	assert(not club_lbl.text.is_empty(), "Row 0 club should not be empty, got: %s" % club_lbl.text)

	# Test single player / solo mode: queue panel should automatically hide
	var solo_player: Array[Dictionary] = [mp_mgr.players[0]]
	mp_mgr.players = solo_player
	cp._update_top_hud(mp_mgr.players[0])
	await process_frame
	assert(cp.hud_distance_queue_panel.visible == false, "Distance queue panel must be hidden for solo players")
	var solo_top_y = cp._get_normal_minimap_top_y()
	var solo_h = cp._get_normal_minimap_height()
	assert(solo_top_y == 142.0, "Solo minimap top Y must be 142.0, got: %f" % solo_top_y)
	assert(solo_top_y + solo_h <= 485.0, "Solo minimap bottom must not overlap stats grid (485.0), was: %f" % (solo_top_y + solo_h))

	# Re-test multiplayer with 3 players in queue
	mp_mgr.players = test_players
	cp._update_top_hud(mp_mgr.players[0])
	await process_frame
	await process_frame
	assert(cp.hud_distance_queue_panel.visible == true, "Distance queue panel must be visible for multiple players")
	var multi_top_y = cp._get_normal_minimap_top_y()
	var multi_h = cp._get_normal_minimap_height()
	assert(multi_top_y > solo_top_y, "Multiplayer minimap top Y must be pushed down to fit queue, got: %f" % multi_top_y)
	assert(multi_top_y + multi_h <= 485.0, "Multiplayer minimap bottom must not overlap stats grid (485.0), was: %f" % (multi_top_y + multi_h))
	assert(multi_top_y + multi_h == 478.0, "Minimap bottom must dynamically anchor at 478.0, was: %f" % (multi_top_y + multi_h))
	print("  PASS: CoursePlay unified HUD widget, row generation, minimap position & dynamic height verified.")

	# ---------------------------------------------------------
	# PART 4: TURN HAND-OFF & DYNAMIC QUEUE SHIFT
	# ---------------------------------------------------------
	print("\n--- TEST 4: Turn Hand-off & Dynamic Queue Promotion ---")
	# Reset 4 players: Practice Player, M. Vance, T. Johnson, A. Kim
	var four_players: Array[Dictionary] = [
		{
			"name": "Practice Player",
			"position": Vector3(0, 0, 0),
			"strokes": 0,
			"total_strokes": 0,
			"hole_scores": {},
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Marcus Vance",
			"position": Vector3(0, 0, 100),
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {},
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Tyler Johnson",
			"position": Vector3(0, 0, 180),
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {},
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Alex Kim",
			"position": Vector3(0, 0, 250),
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {},
			"active": true,
			"paused": false,
			"holed_out": false
		}
	]
	mp_mgr.players = four_players
	mp_mgr.turn_order_mode = "Classic"
	mp_mgr.active_player_index = 0
	cp._update_top_hud(mp_mgr.players[0])
	await process_frame

	# Simulate active player finishes stroke: hits to 200m (position 0, 0, 200 -> 150m from pin)
	mp_mgr.players[0]["position"] = Vector3(0, 0, 200)
	mp_mgr.players[0]["strokes"] = 1
	# Now distances to pin (0, 0, 350):
	# - Marcus Vance: at 100 -> 250m (furthest!)
	# - Practice Player: at 200 -> 150m
	# - Tyler Johnson: at 180 -> 170m
	# - Alex Kim: at 250 -> 100m
	# Hand off turn to Marcus Vance (furthest player)
	var rem_players = mp_mgr.players.filter(func(p): return p.get("active", true) and not p.get("paused", false) and not p["holed_out"])
	mp_mgr._select_next_player_classic(rem_players)
	assert(mp_mgr.get_active_player()["name"] == "Marcus Vance", "Marcus Vance must be promoted to active player, got: %s" % mp_mgr.get_active_player()["name"])

	# Now update HUD for Marcus Vance: Practice Player should now appear in the queue!
	cp._update_top_hud(mp_mgr.get_active_player())
	await process_frame

	var shifted_queue = mp_mgr.get_distance_queue(pin_pos)
	assert(shifted_queue.size() == 3, "Shifted queue must have 3 players")
	assert(shifted_queue[0]["name"] == "Tyler Johnson", "Next in queue must now be Tyler Johnson (170m from pin), got: %s" % shifted_queue[0]["name"])
	assert(shifted_queue[1]["name"] == "Practice Player", "Practice Player must now be in queue (150m from pin), got: %s" % shifted_queue[1]["name"])
	assert(shifted_queue[2]["name"] == "Alex Kim", "Alex Kim must be last in queue (100m from pin), got: %s" % shifted_queue[2]["name"])
	print("  PASS: Turn hand-off promotes furthest player and dynamically shifts queue.")

	# Cleanup
	cp.queue_free()
	await process_frame

	print("\n===================================================================")
	print("  ALL STATS REDESIGN & DISTANCE QUEUE TESTS PASSED! 🎉             ")
	print("===================================================================\n")
	quit(0)
