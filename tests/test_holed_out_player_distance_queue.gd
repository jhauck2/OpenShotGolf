extends SceneTree

# Targeted Unit Test for Holed-Out Player Retention in Top-Left Next Player Queue

func _initialize() -> void:
	print("===================================================================")
	print("  RUNNING HOLED-OUT PLAYER DISTANCE QUEUE TESTS                    ")
	print("===================================================================")
	process_frame.connect(_run_tests)

func _run_tests() -> void:
	process_frame.disconnect(_run_tests)
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

	var pin_pos = Vector3(0.0, 0.0, 300.0)
	mp_mgr.hole_ids = ["hole_0", "hole_1"]
	mp_mgr.hole_info = {
		"hole_0": {"Par": 4, "Name": "Hole 0"},
		"hole_1": {"Par": 4, "Name": "Hole 1", "Hole Location": [0.0, 300.0]}
	}
	mp_mgr.current_hole_index = 1
	mp_mgr.game_mode = "Standard"
	mp_mgr.turn_order_mode = "Classic"

	# 4-player match
	var players: Array[Dictionary] = [
		{
			"name": "Alice",
			"position": Vector3(0, 0, 100), # 200m to pin = ~219 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 4},
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Bob",
			"position": Vector3(0, 0, 150), # 150m to pin = ~164 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 5},
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Charlie",
			"position": Vector3(0, 0, 220), # 80m to pin = ~87 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 4},
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		},
		{
			"name": "Diana",
			"position": Vector3(0, 0, 280), # 20m to pin = ~22 yds
			"strokes": 1,
			"total_strokes": 1,
			"hole_scores": {"hole_0": 3},
			"lie_type": "fairway",
			"active": true,
			"paused": false,
			"holed_out": false
		}
	]
	mp_mgr.players = players
	mp_mgr.active_player_index = 0 # Alice is active

	print("\n--- TEST 1: Initial Distance Queue with All 3 Other Players Active ---")
	var q1 = mp_mgr.get_distance_queue(pin_pos)
	assert(q1.size() == 3, "Queue should contain all 3 other players, got: %d" % q1.size())
	assert(q1[0]["name"] == "Bob", "Bob must be first in queue (furthest)")
	assert(q1[1]["name"] == "Charlie", "Charlie must be second")
	assert(q1[2]["name"] == "Diana", "Diana must be third")
	print("  PASS: Initial distance queue order verified.")

	print("\n--- TEST 2: Bob Holes Out -> Remains in Queue with 0 Yds & '-' Club ---")
	mp_mgr.players[1]["holed_out"] = true
	var q2 = mp_mgr.get_distance_queue(pin_pos)
	assert(q2.size() == 3, "Queue must still retain 3 players after Bob holes out, got: %d" % q2.size())
	assert(q2[0]["name"] == "Charlie", "Charlie (still playing) must now be first")
	assert(q2[1]["name"] == "Diana", "Diana (still playing) must be second")
	assert(q2[2]["name"] == "Bob", "Holed-out Bob must remain in queue at the end")
	assert(q2[2]["distance_yards"] == 0, "Bob distance_yards must be 0")
	assert(q2[2]["distance_str"] == "0 Yds", "Bob distance_str must be '0 Yds', got: %s" % q2[2]["distance_str"])
	assert(q2[2]["suggested_club"] == "-", "Bob suggested_club must be '-'")
	assert(q2[2]["holed_out"] == true, "Bob holed_out flag must be true")
	print("  PASS: Holed-out player remains visible in queue with 0 Yds and '-' club.")

	print("\n--- TEST 3: Charlie Also Holes Out -> Both Holed-Out Players Remain in Queue ---")
	mp_mgr.players[2]["holed_out"] = true
	var q3 = mp_mgr.get_distance_queue(pin_pos)
	assert(q3.size() == 3, "Queue must still contain 3 players, got: %d" % q3.size())
	assert(q3[0]["name"] == "Diana", "Diana (only remaining active player) must be first")
	assert(q3[1]["name"] == "Bob", "Bob remains in queue")
	assert(q3[2]["name"] == "Charlie", "Charlie remains in queue")
	assert(q3[1]["distance_str"] == "0 Yds", "Bob shows 0 Yds")
	assert(q3[2]["distance_str"] == "0 Yds", "Charlie shows 0 Yds")
	print("  PASS: Multiple holed-out players stay in queue under active player.")

	print("\n--- TEST 4: CoursePlay Top-Left HUD Row Rendering for Holed-Out Players ---")
	var cp_script = load("res://Courses/CoursePlay/course_play.gd")
	var cp = Node3D.new()
	cp.set_script(cp_script)
	root_node.add_child(cp)
	await process_frame

	cp._update_top_hud(mp_mgr.players[0])
	await process_frame

	assert(cp.hud_distance_queue_panel.visible == true, "Distance queue panel must remain visible")
	assert(cp.hud_distance_queue_vbox.get_child_count() == 3, "Queue VBox must have 3 rows")

	# Row 0: Diana (active)
	var row0 = cp.hud_distance_queue_vbox.get_child(0) as HBoxContainer
	var r0_dist = row0.get_child(2) as Label
	assert(r0_dist.text.ends_with("Yds") and r0_dist.text != "0 Yds", "Diana has active distance")

	# Row 1: Bob (holed out)
	var row1 = cp.hud_distance_queue_vbox.get_child(1) as HBoxContainer
	var r1_name = row1.get_child(0) as Label
	var r1_dist = row1.get_child(2) as Label
	var r1_club = row1.get_child(3) as Label
	assert(r1_name.text == "Bob", "Row 1 must be Bob")
	assert(r1_dist.text == "0 Yds", "Row 1 distance must be '0 Yds', got: %s" % r1_dist.text)
	assert(r1_club.text == "-", "Row 1 club must be '-', got: %s" % r1_club.text)

	# Row 2: Charlie (holed out)
	var row2 = cp.hud_distance_queue_vbox.get_child(2) as HBoxContainer
	var r2_dist = row2.get_child(2) as Label
	var r2_club = row2.get_child(3) as Label
	assert(r2_dist.text == "0 Yds", "Row 2 distance must be '0 Yds'")
	assert(r2_club.text == "-", "Row 2 club must be '-'")

	cp.queue_free()
	await process_frame

	print("  PASS: Top-left HUD correctly displays holed-out players with '0 Yds' and '-'.")

	print("\n===================================================================")
	print("  ALL HOLED-OUT PLAYER DISTANCE QUEUE TESTS PASSED! 🎉             ")
	print("===================================================================\n")
	quit(0)
