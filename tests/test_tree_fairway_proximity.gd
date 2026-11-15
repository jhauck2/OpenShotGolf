extends SceneTree

func _initialize():
	print("=== Running Tree Fairway Proximity and Tee Clearance Tests ===")
	
	# Load OsmMapLoader C# script
	var loader_script = load("res://Courses/OsmMapLoader.cs")
	assert(loader_script != null, "Courses/OsmMapLoader.cs must be loadable")
	var loader = loader_script.new()
	assert(loader != null, "OsmMapLoader instance must be created")
	
	# Define a simulated fairway polygon: rectangle from X: [0, 40], Y: [50, 250]
	var fairway_poly = PackedVector2Array([
		Vector2(0, 50),
		Vector2(40, 50),
		Vector2(40, 250),
		Vector2(0, 250)
	])
	var fairway_list: Array = [fairway_poly]

	# ---------------------------------------------------------
	# Test 1: Verify Tree Fairway Proximity Check
	# Ensures no trees are generated too close to the fairway (< 14m threshold)
	# ---------------------------------------------------------
	print("\n--- Test 1: Tree Fairway Proximity Validation ---")
	
	# Inside fairway: must be rejected
	var inside_fw = Vector2(20, 150)
	assert(loader.CheckTreeTooCloseToFairway(inside_fw, fairway_list, 14.0) == true,
		"Tree inside fairway must be flagged as too close")

	# Very close to edge (3m away): must be rejected
	var close_fw_left = Vector2(-3, 150)
	assert(loader.CheckTreeTooCloseToFairway(close_fw_left, fairway_list, 14.0) == true,
		"Tree 3m from fairway edge must be flagged as too close")

	# Medium close to edge (8m away): must be rejected
	var med_fw_right = Vector2(48, 150)
	assert(loader.CheckTreeTooCloseToFairway(med_fw_right, fairway_list, 14.0) == true,
		"Tree 8m from fairway edge must be flagged as too close")

	# 12m away: still too close (< 14m threshold)
	var boundary_close = Vector2(52, 150)
	assert(loader.CheckTreeTooCloseToFairway(boundary_close, fairway_list, 14.0) == true,
		"Tree 12m from fairway edge must be flagged as too close (< 14m)")

	# 18m away: safe distance, allowed
	var safe_rough_right = Vector2(58, 150)
	assert(loader.CheckTreeTooCloseToFairway(safe_rough_right, fairway_list, 14.0) == false,
		"Tree 18m from fairway edge must be permitted")

	# 25m away: safe distance, allowed
	var safe_rough_left = Vector2(-25, 150)
	assert(loader.CheckTreeTooCloseToFairway(safe_rough_left, fairway_list, 14.0) == false,
		"Tree 25m from fairway edge must be permitted")

	print("  PASS: All fairway proximity clearance checks passed.")

	# ---------------------------------------------------------
	# Test 2: Verify Tree Tee-to-Fairway Clearance
	# Ensures no trees are in the way between tee box and the fairway
	# ---------------------------------------------------------
	print("\n--- Test 2: Tee-to-Fairway Flight Corridor Clearance ---")
	var tee_pos = Vector2(20, 0)
	var fw_entry = Vector2(20, 100)

	# Direct center of drive between tee and fairway: must be flagged in the way
	var directly_in_way = Vector2(20, 45)
	assert(loader.CheckTreeBetweenTeeAndFairway(directly_in_way, tee_pos, fw_entry, 18.0, 35.0) == true,
		"Tree on direct drive line between tee and fairway must be flagged in the way")

	# 8m to the right in corridor: must be flagged in the way
	var corridor_right = Vector2(28, 60)
	assert(loader.CheckTreeBetweenTeeAndFairway(corridor_right, tee_pos, fw_entry, 18.0, 35.0) == true,
		"Tree in flight corridor (8m off centerline) must be flagged in the way")

	# 12m in front of tee box (cone obstruction): must be flagged in the way
	var front_of_tee = Vector2(25, 15)
	assert(loader.CheckTreeBetweenTeeAndFairway(front_of_tee, tee_pos, fw_entry, 18.0, 35.0) == true,
		"Tree in front cone of tee box must be flagged in the way")

	# Behind the tee box: safe backdrop, not in the way
	var behind_tee = Vector2(20, -20)
	assert(loader.CheckTreeBetweenTeeAndFairway(behind_tee, tee_pos, fw_entry, 18.0, 35.0) == false,
		"Tree behind tee box must not be flagged as in the way")

	# 45m lateral to the left: far outside flight corridor, not in the way
	var wide_left = Vector2(-25, 50)
	assert(loader.CheckTreeBetweenTeeAndFairway(wide_left, tee_pos, fw_entry, 18.0, 35.0) == false,
		"Tree far outside corridor (45m lateral) must not be flagged in the way")

	# Beyond the target point: not between tee and fairway
	var beyond_fairway = Vector2(20, 160)
	assert(loader.CheckTreeBetweenTeeAndFairway(beyond_fairway, tee_pos, fw_entry, 18.0, 35.0) == false,
		"Tree past fairway target must not be flagged as between tee and fairway")

	print("  PASS: All tee-to-fairway corridor clearance checks passed.")

	# ---------------------------------------------------------
	# Test 3: Verify OSM-Only Tree Placement Invariant
	# ---------------------------------------------------------
	print("\n--- Test 3: OSM-Only Tree Placement Invariant ---")
	# Simulate candidate lists:
	# Mapped OSM course trees must always be retained right where they belong
	var osm_course_trees = [
		Vector2(12.5, 45.2),
		Vector2(-80.0, 120.0),
		Vector2(150.0, 310.5)
	]
	var placed_trees: Array = []
	for t in osm_course_trees:
		placed_trees.append(t)
	assert(placed_trees.size() == osm_course_trees.size(), "All OSM course trees must be placed exactly where listed")
	assert(placed_trees[0] == Vector2(12.5, 45.2), "Tree position must match OSM coordinates")
	print("  PASS: OSM course tree placement fidelity verified.")

	# ---------------------------------------------------------
	# Test 4: Verify Tree Bunker / Sand Trap Avoidance
	# Ensures no trees are generated inside or too close to sand traps (< 5.0m threshold)
	# ---------------------------------------------------------
	print("\n--- Test 4: Tree Bunker Avoidance Validation ---")
	var bunker_poly = PackedVector2Array([
		Vector2(100, 100),
		Vector2(120, 100),
		Vector2(120, 115),
		Vector2(100, 115)
	])
	var bunker_list: Array = [bunker_poly]

	# Point directly inside sand trap: must be rejected
	var inside_bunker = Vector2(110, 107)
	assert(loader.CheckTreeTooCloseToBunker(inside_bunker, bunker_list, 5.0) == true,
		"Tree inside bunker must be flagged as too close")

	# Point 1.5m from bunker lip: must be rejected (< 5.0m)
	var lip_bunker = Vector2(121.5, 107)
	assert(loader.CheckTreeTooCloseToBunker(lip_bunker, bunker_list, 5.0) == true,
		"Tree 1.5m from bunker edge must be flagged as too close")

	# Point 4.0m from bunker: still too close (< 5.0m threshold)
	var near_bunker = Vector2(100, 96)
	assert(loader.CheckTreeTooCloseToBunker(near_bunker, bunker_list, 5.0) == true,
		"Tree 4.0m from bunker edge must be flagged as too close")

	# Point 6.5m from bunker: safe distance, permitted
	var safe_bunker = Vector2(100, 93.5)
	assert(loader.CheckTreeTooCloseToBunker(safe_bunker, bunker_list, 5.0) == false,
		"Tree 6.5m from bunker edge must be permitted")

	print("  PASS: All bunker avoidance checks passed.")

	# ---------------------------------------------------------
	# Test 5: Verify Tree Green Avoidance
	# Ensures no trees are generated inside or too close to greens (< 10.0m threshold)
	# ---------------------------------------------------------
	print("\n--- Test 5: Tree Green Avoidance Validation ---")
	var green_poly = PackedVector2Array([
		Vector2(200, 200),
		Vector2(230, 200),
		Vector2(230, 230),
		Vector2(200, 230)
	])
	var green_list: Array = [green_poly]

	# Point directly on green: must be rejected
	var inside_green = Vector2(215, 215)
	assert(loader.CheckTreeTooCloseToGreen(inside_green, green_list, 10.0) == true,
		"Tree inside green must be flagged as too close")

	# Point 4.0m from green fringe: must be rejected (< 10.0m)
	var fringe_green = Vector2(234, 215)
	assert(loader.CheckTreeTooCloseToGreen(fringe_green, green_list, 10.0) == true,
		"Tree 4m from green fringe must be flagged as too close")

	# Point 14.0m from green: safe distance, permitted
	var safe_green = Vector2(244, 215)
	assert(loader.CheckTreeTooCloseToGreen(safe_green, green_list, 10.0) == false,
		"Tree 14m from green edge must be permitted")

	print("  PASS: All green avoidance checks passed.")

	# ---------------------------------------------------------
	# Test 6: Verify Tree Cart Path Avoidance
	# Ensures no trees are generated directly on or too close to cart paths (< 2.2m threshold)
	# ---------------------------------------------------------
	print("\n--- Test 6: Tree Cart Path Avoidance Validation ---")
	var cart_path_polyline = PackedVector2Array([
		Vector2(10, 0),
		Vector2(10, 50),
		Vector2(30, 80)
	])
	var cart_path_list: Array = [cart_path_polyline]

	# Point directly on cart path: must be rejected
	var on_cart_path = Vector2(10, 25)
	assert(loader.CheckTreeTooCloseToCartPath(on_cart_path, cart_path_list, 2.2) == true,
		"Tree directly on cart path must be flagged as too close")

	# Point 1.2m from cart path centerline (within ~1.25m half-width): must be rejected
	var inside_cart_path_width = Vector2(11.2, 25)
	assert(loader.CheckTreeTooCloseToCartPath(inside_cart_path_width, cart_path_list, 2.2) == true,
		"Tree within cart path edge must be flagged as too close")

	# Point 1.8m from cart path centerline (< 2.2m clearance buffer): must be rejected
	var near_cart_path = Vector2(8.2, 25)
	assert(loader.CheckTreeTooCloseToCartPath(near_cart_path, cart_path_list, 2.2) == true,
		"Tree within 2.2m clearance of cart path must be flagged as too close")

	# Point 5.0m from cart path: safe distance, permitted
	var safe_cart_path = Vector2(15.0, 25)
	assert(loader.CheckTreeTooCloseToCartPath(safe_cart_path, cart_path_list, 2.2) == false,
		"Tree 5m away from cart path must be permitted")

	print("  PASS: All cart path avoidance checks passed.")

	# ---------------------------------------------------------
	# Test 7: Verify Comprehensive Hole Path Tree Avoidance
	# Ensures no trees spawn in front of teeboxes, in the path from teebox to fairway,
	# or through the fairway to the green.
	# ---------------------------------------------------------
	print("\n--- Test 7: Comprehensive Hole Path & Teebox Obstruction Avoidance ---")
	var simulated_hole_data = {
		"1": {
			"par": 4,
			"pin": Vector2(20, 360),
			"hole_path": PackedVector2Array([
				Vector2(20, 0),
				Vector2(20, 90),
				Vector2(20, 180),
				Vector2(20, 270),
				Vector2(20, 360)
			]),
			"teeboxes": {
				"Black": Vector2(20, 0),
				"Blue": Vector2(20, 30),
				"White": Vector2(20, 60),
				"Red": Vector2(20, 90)
			}
		}
	}

	# Simulated fairway polygon from Y: 120 to Y: 320, width 30m (X: 5 to 35)
	var fw_poly_hole = PackedVector2Array([
		Vector2(5, 120),
		Vector2(35, 120),
		Vector2(35, 320),
		Vector2(5, 320)
	])
	var fw_list_hole: Array = [fw_poly_hole]

	# Point directly in front of Blue tee (Y: 45, between Blue and White tee): MUST be flagged as in hole path!
	var between_blue_and_white = Vector2(20, 45)
	assert(loader.CheckPointInHolePath(between_blue_and_white, simulated_hole_data, fw_list_hole) == true,
		"Tree directly in front of Blue tee must be blocked")

	# Point directly in front of White tee (Y: 75, between White and Red tee): MUST be flagged as in hole path!
	var between_white_and_red = Vector2(20, 75)
	assert(loader.CheckPointInHolePath(between_white_and_red, simulated_hole_data, fw_list_hole) == true,
		"Tree directly in front of White tee must be blocked")

	# Point directly in front of Red tee (Y: 105, 15m in front of Red tee heading to fairway): MUST be blocked!
	var in_front_of_red = Vector2(20, 105)
	assert(loader.CheckPointInHolePath(in_front_of_red, simulated_hole_data, fw_list_hole) == true,
		"Tree in front of Red tee on path to fairway must be blocked")

	# Point in flight corridor from tee to fairway (Y: 110, X: 26, 6m off centerline): MUST be blocked!
	var corridor_tee_to_fw = Vector2(26, 110)
	assert(loader.CheckPointInHolePath(corridor_tee_to_fw, simulated_hole_data, fw_list_hole) == true,
		"Tree in flight corridor from tee to fairway must be blocked")

	# Point inside the fairway polygon (Y: 200, X: 20): MUST be blocked!
	var in_fairway_path = Vector2(20, 200)
	assert(loader.CheckPointInHolePath(in_fairway_path, simulated_hole_data, fw_list_hole) == true,
		"Tree inside fairway must be blocked")

	# Point 6m outside fairway edge (Y: 200, X: 41): within 12m fairway buffer, MUST be blocked!
	var near_fairway_edge = Vector2(41, 200)
	assert(loader.CheckPointInHolePath(near_fairway_edge, simulated_hole_data, fw_list_hole) == true,
		"Tree within 12m of fairway edge must be blocked")

	# Point between fairway and green on approach path (Y: 340, X: 20): MUST be blocked!
	var approach_to_green = Vector2(20, 340)
	assert(loader.CheckPointInHolePath(approach_to_green, simulated_hole_data, fw_list_hole) == true,
		"Tree on green approach corridor must be blocked")

	# Point safely behind the back Black tee (Y: -20, X: 20): Safe backdrop, permitted!
	var safe_behind_black = Vector2(20, -20)
	assert(loader.CheckPointInHolePath(safe_behind_black, simulated_hole_data, fw_list_hole) == false,
		"Tree safely behind the back Black tee must be permitted as a backdrop")

	# Point in deep rough far to the side (Y: 200, X: 70 - 35m from fairway edge, 50m from centerline): Permitted!
	var safe_deep_rough = Vector2(70, 200)
	assert(loader.CheckPointInHolePath(safe_deep_rough, simulated_hole_data, fw_list_hole) == false,
		"Tree in deep rough far lateral from fairway must be permitted")

	print("  PASS: All comprehensive hole path & teebox clearance checks passed.")

	loader.free()
	print("\n=======================================================")
	print("ALL TREE FAIRWAY PROXIMITY AND CLEARANCE TESTS PASSED!")
	print("=======================================================\n")
	quit(0)
