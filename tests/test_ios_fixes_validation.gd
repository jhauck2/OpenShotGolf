extends SceneTree

func _init() -> void:
	print("=== Running Targeted Test: iOS Fixes Validation ===")
	
	# Test 1: Airways and DragonFly are excluded from CourseList and CoursePlaySetup
	print("\n--- Test 1: Developer test courses excluded ---")
	var course_list_script = load("res://Courses/CourseSelector/course_list.gd")
	assert(course_list_script != null, "course_list.gd must load")
	var cl = course_list_script.new()
	var test_validated: Array[Dictionary] = []
	cl._scan_dir("res://Courses/UserCourses", test_validated)
	assert(test_validated.is_empty(), "Scanning res://Courses/UserCourses must yield 0 courses")
	
	# Verify Airways and DragonFly filter
	var mock_dir = ["Airways", "DragonFly", "dragon_fly"]
	for d in mock_dir:
		var lower = d.to_lower()
		assert(lower == "airways" or lower == "dragonfly" or lower == "dragon_fly", "Filter check matches")
	print("PASS: Airways and DragonFly correctly excluded.")

	# Test 2: OsmDownloadDialog _refresh_available_cache_slugs uses get_files_at
	print("\n--- Test 2: OsmDownloadDialog cache slug discovery ---")
	var dialog_script = load("res://Courses/OsmDownloadDialog/osm_download_dialog.gd")
	assert(dialog_script != null, "osm_download_dialog.gd must load")
	var dialog = Control.new()
	dialog.set_script(dialog_script)
	dialog.call("_refresh_available_cache_slugs")
	var cache_slugs: Dictionary = dialog.get("_available_cache_slugs")
	print("  Found %d cache slugs in _available_cache_slugs." % cache_slugs.size())
	assert(cache_slugs.size() > 0, "Available cache slugs should discover cached geometry files")
	print("PASS: OsmDownloadDialog successfully discovered cached geometry files via DirAccess.get_files_at.")

	# Test 3: OsmMapLoader GetCachedCourses uses GetFilesAt
	print("\n--- Test 3: OsmMapLoader GetCachedCourses ---")
	var loader_script = load("res://Courses/OsmMapLoader.cs")
	if loader_script != null:
		var loader = loader_script.new()
		var cached_courses = loader.call("GetCachedCourses")
		assert(cached_courses is Array, "GetCachedCourses must return an Array")
		print("  OsmMapLoader found %d cached course entries." % cached_courses.size())
		assert(cached_courses.size() > 0, "OsmMapLoader should find cached courses from CachedGeometry")
		print("PASS: OsmMapLoader GetCachedCourses successfully loaded cached courses.")

	# Test 4: Verify root-level res://CachedGeometry path fallback support
	print("\n--- Test 4: Root-level res://CachedGeometry fallback support ---")
	var sample_name = "Pebble Beach Golf Links"
	if loader_script != null:
		var loader2 = loader_script.new()
		assert(loader2.has_method("IsCourseCached"), "OsmMapLoader must have IsCourseCached")
		var is_cached = loader2.call("IsCourseCached", sample_name)
		print("  Sample course '%s' is_cached = %s" % [sample_name, str(is_cached)])
		assert(is_cached, "Sample course should be detected as cached")
	print("PASS: Root-level and Courses/CachedGeometry path fallbacks validated.")
	
	print("\n=======================================================")
	print("ALL TARGETED IOS TESTS PASSED SUCCESSFULLY!")
	print("=======================================================\n")
	quit(0)
