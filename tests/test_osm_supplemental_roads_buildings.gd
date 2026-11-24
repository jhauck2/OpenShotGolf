extends SceneTree

func _initialize() -> void:
	print("=== Running OSM Supplemental Roads & Buildings Tests ===")

	var loader_script = load("res://Courses/OsmMapLoader.cs")
	assert(loader_script != null, "Courses/OsmMapLoader.cs must be loadable")
	var loader = loader_script.new()
	assert(loader != null, "OsmMapLoader instance must be created")

	# 1. HasSupplementalRoadsAndBuildings must NOT false-positive on cart paths, footways, or golf=clubhouse
	var cartpath_only_json := '{"elements":[{"type":"way","id":1,"tags":{"golf":"cartpath","highway":"path"}},{"type":"way","id":2,"tags":{"highway":"path"}},{"type":"way","id":3,"tags":{"highway":"footway"}},{"type":"way","id":4,"tags":{"golf":"clubhouse","building":"yes"}}]}'
	assert(loader.CheckHasSupplementalRoadsAndBuildings(cartpath_only_json) == false, "Cart paths, footways, and golf=clubhouse alone must NOT satisfy supplemental roads/buildings check")

	var with_road_json := '{"elements":[{"type":"way","id":1,"tags":{"highway":"residential"}}]}'
	assert(loader.CheckHasSupplementalRoadsAndBuildings(with_road_json) == true, "Non-golf residential road must satisfy supplemental roads/buildings check")

	var with_house_json := '{"elements":[{"type":"way","id":2,"tags":{"building":"house"}}]}'
	assert(loader.CheckHasSupplementalRoadsAndBuildings(with_house_json) == true, "Non-golf house building must satisfy supplemental roads/buildings check")

	var with_marker_json := '{"supplemented_roads_buildings":true,"elements":[]}'
	assert(loader.CheckHasSupplementalRoadsAndBuildings(with_marker_json) == true, "Explicit supplemented_roads_buildings flag must satisfy check")
	print("  [PASS] HasSupplementalRoadsAndBuildings detection")

	# 2. ComputeSupplementalQueryBBox must cover the entire golf course + padding even when catalog lat/lon is off-center
	# Modeled after Westridge Golf Course (Neenah, WI) where catalog lat/lon is ~1.47km east of westernmost hole
	var offcenter_course_json := '{"elements":[{"type":"node","id":1,"lat":44.18534,"lon":-88.55440},{"type":"node","id":2,"lat":44.19956,"lon":-88.53399},{"type":"way","id":10,"nodes":[1,2],"tags":{"golf":"hole"}}]}'
	var bbox: Dictionary = loader.ComputeSupplementalQueryBBoxForTest(offcenter_course_json, 44.1881933, -88.5364259)
	assert(float(bbox["south"]) < 44.18534, "Supplemental bbox south must include southernmost hole plus padding")
	assert(float(bbox["north"]) > 44.19956, "Supplemental bbox north must include northernmost hole plus padding")
	assert(float(bbox["west"]) < -88.55440, "Supplemental bbox west must include westernmost hole (1.47km off-center) plus padding")
	assert(float(bbox["east"]) > -88.53399, "Supplemental bbox east must include easternmost hole plus padding")

	# 3. Fallback bbox when no nodes are present
	var fallback_bbox: Dictionary = loader.ComputeSupplementalQueryBBoxForTest('{"elements":[]}', 33.196774, -96.746347)
	assert(float(fallback_bbox["south"]) < 33.196774 and float(fallback_bbox["north"]) > 33.196774, "Fallback bbox must bracket fallback lat")
	assert(float(fallback_bbox["west"]) < -96.746347 and float(fallback_bbox["east"]) > -96.746347, "Fallback bbox must bracket fallback lon")
	print("  [PASS] ComputeSupplementalQueryBBox coverage")

	loader.free()
	print("=== ALL OSM SUPPLEMENTAL ROADS & BUILDINGS TESTS PASSED ===")
	quit(0)
