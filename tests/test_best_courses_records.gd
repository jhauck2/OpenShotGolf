extends SceneTree

const StatsMerger = preload("res://Utils/Cloud/stats_merger.gd")

var _tested := false

func _initialize() -> void:
	print("=== Running Targeted Test: Best Course Records ===")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_tests()

func _run_tests() -> void:
	test_stats_merger_best_courses()
	print("\n=======================================================")
	print("  TEST BEST COURSES RECORDS PASSED SUCCESSFULLY!       ")
	print("=======================================================\n")
	quit(0)

func test_stats_merger_best_courses() -> void:
	print("--- Testing StatsMerger best_courses merge ---")

	var local_data = {
		"clubs": {},
		"records": {},
		"tombstones": {},
		"achievements": {},
		"swing_issues": {},
		"best_courses": {
			"Pebble Beach": {
				"diff": -2,
				"str": "-2 (18 holes)",
				"strokes": 70,
				"holes": 18
			},
			"St Andrews": {
				"diff": 1,
				"str": "+1 (9 holes)",
				"strokes": 37,
				"holes": 9
			}
		}
	}

	var cloud_data = {
		"clubs": {},
		"records": {},
		"tombstones": {},
		"achievements": {},
		"swing_issues": {},
		"best_courses": {
			"Pebble Beach": {
				"diff": -1,
				"str": "-1 (18 holes)",
				"strokes": 71,
				"holes": 18
			},
			"St Andrews": {
				"diff": 1,
				"str": "+1 (18 holes)",
				"strokes": 73,
				"holes": 18
			},
			"Augusta National": {
				"diff": 0,
				"str": "E (18 holes)",
				"strokes": 72,
				"holes": 18
			}
		}
	}

	var merged = StatsMerger.merge_profile_stats(local_data, cloud_data)
	var bc = merged.get("best_courses", {})

	assert(bc.has("Pebble Beach"), "Expected Pebble Beach in best_courses")
	assert(bc["Pebble Beach"]["diff"] == -2, "Expected -2 to beat -1 for Pebble Beach")
	assert(bc["Pebble Beach"]["strokes"] == 70, "Expected strokes to be 70 for Pebble Beach")
	assert(bc["Pebble Beach"]["holes"] == 18, "Expected holes to be 18 for Pebble Beach")

	assert(bc.has("St Andrews"), "Expected St Andrews in best_courses")
	assert(bc["St Andrews"]["diff"] == 1, "Expected diff to be 1 for St Andrews")
	assert(bc["St Andrews"]["holes"] == 18, "Expected 18-hole tiebreaker to win over 9-hole for St Andrews")
	assert(bc["St Andrews"]["strokes"] == 73, "Expected 18-hole strokes for St Andrews")

	assert(bc.has("Augusta National"), "Expected Augusta National in best_courses")
	assert(bc["Augusta National"]["diff"] == 0, "Expected Augusta National diff to be 0")
	assert(bc["Augusta National"]["strokes"] == 72, "Expected Augusta National strokes to be 72")

	print("✓ StatsMerger best_courses merge tests passed successfully.")
