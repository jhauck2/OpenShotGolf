extends SceneTree

const AchievementManagerScript = preload("res://Utils/AchievementManager.gd")
const CloudSyncScript = preload("res://Utils/Cloud/cloud_sync.gd")
const LeaderboardsMenuScript = preload("res://UI/Leaderboards/leaderboards_menu.gd")
const LeaderboardService = preload("res://Utils/Cloud/leaderboard_service.gd")

const FirestoreClientClass = preload("res://Utils/Cloud/firestore_client.gd")

func _initialize() -> void:
	print("\n=======================================================")
	print("  Running Achievement & Leaderboard Tracking Tests")
	print("=======================================================\n")

	await test_achievement_manager_case_insensitivity()
	await test_cloud_sync_leaderboard_achievements_count()
	await test_leaderboard_menu_personal_best_achievements()

	print("\n=======================================================")
	print("  ALL ACHIEVEMENT & LEADERBOARD TRACKING TESTS PASSED! ")
	print("=======================================================\n")
	quit(0)

func test_achievement_manager_case_insensitivity() -> void:
	print("--- Test 1: AchievementManager Case-Insensitivity & Retrieval ---")
	var mgr = AchievementManagerScript.new()
	root.add_child(mgr)
	mgr._player_data = {}

	# Unlock under PascalCase
	var unlocked = mgr.unlock_achievement("GolferOne", "first_par")
	assert(unlocked, "first_par should unlock successfully")

	# Check with lowercase
	assert(mgr.is_unlocked("golferone", "first_par"), "is_unlocked must succeed case-insensitively")
	assert(mgr.is_unlocked("GOLFERONE", "first_par"), "is_unlocked must succeed for uppercase")
	assert(not mgr.is_unlocked("golferone", "first_birdie"), "unearned achievement must remain locked")

	var unl = mgr.get_unlocked_achievements("golferone")
	assert(unl.has("first_par"), "get_unlocked_achievements must find achievements case-insensitively")
	assert(unl.size() == 1, "Expected 1 unlocked achievement, got %d" % unl.size())

	mgr.queue_free()
	print("  PASS: AchievementManager case-insensitive storage and retrieval verified.")

func test_cloud_sync_leaderboard_achievements_count() -> void:
	print("\n--- Test 2: CloudSync Public Leaderboard Projection Achievements Count ---")
	var cs = CloudSyncScript.new()
	root.add_child(cs)

	# Case A: achievements dict is empty (as when syncing a clean cloud_prof without sync/stats doc),
	# but lifetime contains achievements_count = 8.
	# The projection MUST preserve 8 and not reset to 0!
	var lifetime_data = {"achievements_count": 8, "matches_played": 10, "wins": 3}
	var empty_ach = {}

	var dummy_client = DummyFirestoreClient.new()
	await cs._sync_public_leaderboard_profile(dummy_client, "test_uid_123", "Test Golfer", "", {}, true, lifetime_data, empty_ach)

	assert(dummy_client.saved_doc != null, "set_doc must have been called")
	var proj = dummy_client.saved_doc
	assert(proj.get("achievements_count") == 8, "Projection MUST retain lifetime.achievements_count (8), got: %s" % str(proj.get("achievements_count")))
	assert(proj.get("matches_played") == 10, "Projection matches_played must be 10")
	print("  PASS: Empty achievements dict does not zero out lifetime achievements_count in leaderboard projection.")

	# Case B: achievements dict has 12 items, lifetime only has 8
	var ach_12 = {"unlocked": {}}
	for i in range(12):
		ach_12["unlocked"]["ach_%d" % i] = 1000 + i

	dummy_client.saved_doc = null
	# Reset last_pushed_leaderboard to allow projection change
	cs.last_pushed_leaderboard.clear()
	await cs._sync_public_leaderboard_profile(dummy_client, "test_uid_123", "Test Golfer", "", {}, true, lifetime_data, ach_12)
	assert(dummy_client.saved_doc != null, "set_doc must have been called for Case B")
	var proj_b = dummy_client.saved_doc
	assert(proj_b.get("achievements_count") == 12, "Projection MUST take maxi between lifetime and achievements dict (12), got: %s" % str(proj_b.get("achievements_count")))
	print("  PASS: Leaderboard projection correctly updates to higher count (12) when unlocked dict is present.")

	cs.queue_free()

func test_leaderboard_menu_personal_best_achievements() -> void:
	print("\n--- Test 3: LeaderboardsMenu Personal Best for 'most_achievements' ---")
	var menu = LeaderboardsMenuScript.new()
	root.add_child(menu)

	# Player dict with cloud_lifetime_cache
	var p_cloud = {
		"name": "CloudGolfer",
		"cloud_lifetime_cache": {
			"achievements_count": 9
		}
	}

	var stat_str = menu._get_local_player_stat(p_cloud, "most_achievements")
	assert(stat_str == "9 unlocked" or stat_str == "9", "Personal best stat must format achievements count, got: '%s'" % stat_str)
	print("  PASS: Leaderboard menu personal record strip correctly displays achievements count ('%s')." % stat_str)
	menu.queue_free()


class DummyFirestoreClient extends FirestoreClientClass:
	var saved_doc = null
	func set_doc(path: String, data: Dictionary, update_mask: PackedStringArray = PackedStringArray(), current_document_exists: String = "", current_document_update_time: Variant = null) -> Dictionary:
		saved_doc = data.duplicate(true)
		return {"ok": true, "status": 200}
	func delete_doc(path: String, current_document_exists: String = "", current_document_update_time: Variant = null) -> Dictionary:
		return {"ok": true, "status": 200}
