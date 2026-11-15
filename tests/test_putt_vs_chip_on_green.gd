extends SceneTree

# Test suite verifying that:
# 1. A hit is only considered as a putt when a putter is being used.
# 2. Chips on the green (using wedges, irons, etc.) never count as putts or unlock longest putt achievements.
# 3. Only true putter hits qualify for putt achievements (20+, 30+, 40+, 50+ feet) and record longest putts.

func _initialize() -> void:
	print("\n=======================================================")
	print("  Running Putt vs Chip On Green Verification Tests")
	print("=======================================================\n")
	
	test_ball_putt_determination_requires_putter()
	test_achievement_manager_rejects_chips_for_putt_achievements()
	test_multiplayer_manager_putt_tracking_requires_putter()
	
	print("\n=======================================================")
	print("  ALL PUTT VS CHIP TESTS PASSED SUCCESSFULLY! 🎉")
	print("=======================================================")
	quit(0)

func test_ball_putt_determination_requires_putter() -> void:
	print("--- Test 1: Ball Putt Determination Only Allows Putter ---")
	var BallScript = load("res://Player/ball.gd")
	assert(BallScript != null, "ball.gd must load")
	
	var ball = CharacterBody3D.new()
	ball.set_script(BallScript)
	root.add_child(ball)
	
	# Scenario A: Ball is on green, player uses Lob Wedge (Lw) with low VLA (e.g. 4.0 deg chip)
	ball.lie_type = "green"
	ball.current_selected_club = "Lw"
	var chip_payload = {
		"Speed": 20.0,
		"VLA": 4.0,
		"HLA": 0.0,
		"TotalSpin": 3000.0,
		"Club": "Lw"
	}
	ball.hit_from_data(chip_payload)
	assert(not ball.is_putt, "Lw chip on green with 4 deg VLA must NOT be considered a putt!")
	print("  PASS: Lob Wedge chip on green is NOT considered a putt.")
	
	# Scenario B: Ball is on green, player uses Sand Wedge (Sw) with ShotType="putt"
	ball.lie_type = "green"
	ball.current_selected_club = "Sw"
	var sw_payload = {
		"Speed": 15.0,
		"VLA": 3.0,
		"HLA": 0.0,
		"ShotType": "putt",
		"Club": "Sw"
	}
	ball.hit_from_data(sw_payload)
	assert(not ball.is_putt, "Sw with ShotType='putt' must NOT be considered a putt because putter is not used!")
	print("  PASS: Sand Wedge with ShotType='putt' is NOT a putt because putter is not used.")

	# Scenario C: Ball is on fringe, player uses 8-iron bump-and-run (8i)
	ball.lie_type = "fringe"
	ball.current_selected_club = "8i"
	var iron_payload = {
		"Speed": 22.0,
		"VLA": 5.0,
		"HLA": 0.0,
		"Club": "8i"
	}
	ball.hit_from_data(iron_payload)
	assert(not ball.is_putt, "8-iron bump-and-run on fringe must NOT be considered a putt!")
	print("  PASS: 8-iron bump-and-run is NOT a putt.")
	
	# Scenario D: Ball is on green, player uses Putter (Pt) with normal putting stroke
	ball.lie_type = "green"
	ball.current_selected_club = "Pt"
	var putt_payload = {
		"Speed": 10.0,
		"VLA": 1.5,
		"HLA": 0.0,
		"Club": "Pt"
	}
	ball.hit_from_data(putt_payload)
	assert(ball.is_putt, "Putter on green with normal stroke MUST be considered a putt!")
	print("  PASS: Putter on green is correctly identified as a putt.")

	# Scenario E: Ball is on green, player uses Putter (Pt) but hits an extreme pop/chip (> 14 deg VLA)
	ball.lie_type = "green"
	ball.current_selected_club = "Pt"
	var pop_payload = {
		"Speed": 20.0,
		"VLA": 18.0,
		"HLA": 0.0,
		"Club": "Pt"
	}
	ball.hit_from_data(pop_payload)
	assert(not ball.is_putt, "Putter shot with > 14 deg VLA must NOT be considered a putt!")
	print("  PASS: High-angle shot with putter is NOT treated as a ground putt.")

	ball.queue_free()

func test_achievement_manager_rejects_chips_for_putt_achievements() -> void:
	print("\n--- Test 2: AchievementManager Rejects Chips For Longest Putt Achievements ---")
	var ach_mgr = load("res://Utils/AchievementManager.gd").new()
	root.add_child(ach_mgr)
	var player = "ChipPuttTester"
	ach_mgr._player_data[player] = {}

	# Scenario A: Holing out from 45 feet (15.0 yds) on the green with Lob Wedge (Lw)
	ach_mgr.check_hole_achievements(player, 4, 2, ["green"], 15.0, true, "Lw", 15.0)
	assert(not ach_mgr.is_unlocked(player, "putt_20_ft"), "Lw chip must NOT unlock putt_20_ft")
	assert(not ach_mgr.is_unlocked(player, "long_putt"), "Lw chip must NOT unlock long_putt (30+ ft)")
	assert(not ach_mgr.is_unlocked(player, "putt_40_ft"), "Lw chip must NOT unlock putt_40_ft")
	assert(not ach_mgr.is_unlocked(player, "putt_50_ft"), "Lw chip must NOT unlock putt_50_ft")
	print("  PASS: 45ft Lob Wedge chip did not unlock any putting achievements.")

	# Scenario B: Holing out from 55 feet (18.33 yds) on the green with Sand Wedge (Sw)
	ach_mgr.check_hole_achievements(player, 4, 2, ["green"], 18.34, true, "Sw", 18.34)
	assert(not ach_mgr.is_unlocked(player, "putt_50_ft"), "Sw chip must NOT unlock putt_50_ft")
	print("  PASS: 55ft Sand Wedge chip did not unlock putt_50_ft.")

	# Scenario C: Holing out from 55 feet with a Putter (Pt)
	ach_mgr.check_hole_achievements(player, 4, 2, ["green"], 18.34, true, "Pt", 18.34)
	assert(ach_mgr.is_unlocked(player, "putt_20_ft"), "55ft putt MUST unlock putt_20_ft")
	assert(ach_mgr.is_unlocked(player, "long_putt"), "55ft putt MUST unlock long_putt")
	assert(ach_mgr.is_unlocked(player, "putt_40_ft"), "55ft putt MUST unlock putt_40_ft")
	assert(ach_mgr.is_unlocked(player, "putt_50_ft"), "55ft putt MUST unlock putt_50_ft")
	print("  PASS: 55ft holed putt with Putter correctly unlocked all putting achievements.")

	ach_mgr.queue_free()

func test_multiplayer_manager_putt_tracking_requires_putter() -> void:
	print("\n--- Test 3: MultiplayerManager Putt Distance Tracking Requires Putter ---")
	var mp = load("res://Utils/MultiplayerManager.gd").new()
	root.add_child(mp)
	var p_name = "MMChipTester"
	var p_dict: Dictionary = {"name": p_name, "tee": "Blue", "is_remote": false}
	var course_cfg = {
		"Title": "Test Club",
		"Course Info": {"Title": "Test Club", "Holes": 1},
		"Hole Info": {
			"1": {
				"Par": 4,
				"Hole Location": [0.0, 50.0],
				"Tee Boxes": {"Blue": [0.0, 0.0]}
			}
		}
	}
	mp.setup_game([p_dict], course_cfg, "", "", "1 Hole", "Standard", {}, "Stay Up")
	mp.start_hole()

	# When club is Lw, record_shot must set last_putt_dist_yards to 0.0
	mp.current_club = "Lw"
	var chip_shot_data = {"club": "Lw", "TotalDistance": 10.0}
	mp.record_shot(Vector3(0, 0, 10), chip_shot_data)
	assert(mp.players[0]["last_putt_dist_yards"] == 0.0, "Lw chip must have last_putt_dist_yards = 0.0")
	print("  PASS: Lw shot recorded 0.0 for last_putt_dist_yards.")

	# When club is Pt, record_shot sets last_putt_dist_yards > 0.0
	mp.current_club = "Pt"
	var putt_shot_data = {"club": "Pt", "TotalDistance": 5.0}
	mp.record_shot(Vector3(0, 0, 15), putt_shot_data)
	assert(mp.players[0]["last_putt_dist_yards"] > 0.0, "Pt shot must track last_putt_dist_yards")
	print("  PASS: Pt shot successfully tracks last_putt_dist_yards.")

	mp.queue_free()
