extends SceneTree

## Targeted Unit Test: Foliage Tier Classification & Dynamic Graphics Quality Scaling
## Validates:
## 1. Golf hole corridor extraction from hole_paths metadata and Hole* containers
## 2. classify_trees_into_tiers balances Low / Medium / High tiers evenly across all golf holes
## 3. Framing trees and authentic OSM/willow trees are prioritized into Low tier
## 4. MultiMeshInstance3D chunk creation sets tier_low_count, tier_med_count, tier_high_count
## 5. ConsolidatedFoliageCollision trunk shapes receive matching foliage_tier metadata
## 6. BushChunk_* chunks configure 0 bushes on Low, 50% on Medium, and 100% on High
## 7. MobilePerformance.apply_graphics_quality dynamically adds/removes visible trees, bushes, and colliders on Low/Medium/High

const ProceduralTreeGenerator = preload("res://HighFidelity/Foliage/procedural_tree_generator.gd")
const MobilePerformance = preload("res://Utils/mobile_performance.gd")

var _tested := false

func _process(_delta: float) -> bool:
	if _tested:
		return false
	_tested = true

	print("\n=======================================================")
	print("STARTING TEST: Foliage Tier Classification & Quality Scaling")
	print("=======================================================")

	# 1. Test Hole Corridor Extraction
	print("\n--- Test 1: Hole Corridor Extraction ---")
	var mock_scene := Node3D.new()
	mock_scene.name = "MockCourse"
	root.add_child(mock_scene)

	var hole1_path := PackedVector2Array([Vector2(0, 0), Vector2(0, 100), Vector2(0, 200)])
	var hole2_path := PackedVector2Array([Vector2(150, 0), Vector2(150, 120), Vector2(150, 250)])
	mock_scene.set_meta("hole_paths", [hole1_path, hole2_path])

	var corridors := ProceduralTreeGenerator.extract_course_hole_corridors(mock_scene)
	assert(corridors.size() == 2, "Must extract 2 hole corridors from metadata")
	print("  PASS: Successfully extracted hole corridors.")

	# 2. Test Distance to Corridor
	print("\n--- Test 2: Distance to Corridor ---")
	var test_pt := Vector2(10, 50)
	var d := ProceduralTreeGenerator.get_distance_to_corridor(test_pt, hole1_path)
	assert(abs(d - 10.0) < 0.001, "Distance to straight segment along x=0 at x=10 should be 10")
	print("  PASS: Distance to corridor calculation is exact.")

	# 3. Test Balanced Tier Classification Across Holes
	print("\n--- Test 3: Balanced Tier Classification Across Holes ---")
	# Create 20 trees for Hole 1 (x around 0..30) and 20 trees for Hole 2 (x around 130..170)
	var tree_items: Array = []
	for i in range(20):
		# Distance to hole 1 varies from 5m to 40m
		var dist_x := 5.0 + float(i) * 1.8
		tree_items.append({
			"pos": Vector3(dist_x, 0, float(i) * 10),
			"near_water": (i == 0), # First tree is near water (e.g. willow)
			"is_authentic": (i == 1) # Second tree is authentic OSM
		})
	for i in range(20):
		# Distance to hole 2 varies from 4m to 42m
		var dist_x := 150.0 + 4.0 + float(i) * 1.9
		tree_items.append({
			"pos": Vector3(dist_x, 0, float(i) * 12),
			"near_water": false,
			"is_authentic": false
		})

	ProceduralTreeGenerator.classify_trees_into_tiers(tree_items, corridors)

	var h1_low := 0
	var h1_med := 0
	var h1_high := 0
	for i in range(20):
		var t: int = tree_items[i]["tier"]
		if t == 0: h1_low += 1
		elif t == 1: h1_med += 1
		else: h1_high += 1

	var h2_low := 0
	var h2_med := 0
	var h2_high := 0
	for i in range(20, 40):
		var t: int = tree_items[i]["tier"]
		if t == 0: h2_low += 1
		elif t == 1: h2_med += 1
		else: h2_high += 1

	# Both holes should have ~35% Low (7), ~35% Med (7), ~30% High (6)
	assert(h1_low == 7, "Hole 1 must have 7 Low tier trees")
	assert(h1_med == 7, "Hole 1 must have 7 Medium tier trees")
	assert(h1_high == 6, "Hole 1 must have 6 High tier trees")
	assert(h2_low == 7, "Hole 2 must have 7 Low tier trees")
	assert(h2_med == 7, "Hole 2 must have 7 Medium tier trees")
	assert(h2_high == 6, "Hole 2 must have 6 High tier trees")

	# Willow & authentic trees must be classified as Low (tier 0)
	assert(tree_items[0]["tier"] == 0, "Water/willow tree must be Low tier (0)")
	assert(tree_items[1]["tier"] == 0, "Authentic OSM tree must be Low tier (0)")
	print("  PASS: Classification is evenly distributed across both holes (7 Low, 7 Medium, 6 High per hole) with authentic/willow prioritized.")

	# 4. Test MultiMesh Foliage Conversion and Chunk Metadata
	print("\n--- Test 4: MultiMesh Foliage Conversion with Tier Counts ---")
	var course_scene := Node3D.new()
	course_scene.name = "TestCourseFoliage"
	root.add_child(course_scene)
	course_scene.set_meta("hole_paths", [hole1_path, hole2_path])

	var sphere_mesh := SphereMesh.new()
	for i in range(30):
		var t := StaticBody3D.new()
		t.name = "Tree_%d" % i
		t.position = Vector3(float(i % 10) * 15.0, 0, float(i / 10) * 20.0)
		var mi := MeshInstance3D.new()
		mi.mesh = sphere_mesh
		t.add_child(mi)
		course_scene.add_child(t)

	for i in range(12):
		var b := Node3D.new()
		b.name = "Bush_%d" % i
		b.position = Vector3(float(i) * 8.0, 0, 15.0)
		var bmi := MeshInstance3D.new()
		bmi.mesh = sphere_mesh
		b.add_child(bmi)
		course_scene.add_child(b)

	var stats := ProceduralTreeGenerator.convert_scene_foliage_to_multimesh(course_scene, false)
	assert(stats["trees_converted"] == 30, "Must convert 30 trees")
	assert(stats["bushes_converted"] == 12, "Must convert 12 bushes")

	var mm_container := course_scene.get_node("MultiMeshFoliageContainer")
	assert(mm_container != null, "MultiMeshFoliageContainer must exist")

	var tree_chunks: Array[MultiMeshInstance3D] = []
	var bush_chunks: Array[MultiMeshInstance3D] = []
	for child in mm_container.get_children():
		if child is MultiMeshInstance3D:
			if child.name.begins_with("Tree"):
				tree_chunks.append(child as MultiMeshInstance3D)
			elif child.name.begins_with("Bush"):
				bush_chunks.append(child as MultiMeshInstance3D)

	assert(not tree_chunks.is_empty(), "Must create tree chunk(s)")
	assert(not bush_chunks.is_empty(), "Must create bush chunk(s)")

	var total_tree_low := 0
	var total_tree_med := 0
	var total_tree_high := 0
	for tc in tree_chunks:
		assert(tc.has_meta("tier_low_count"), "TreeChunk must have tier_low_count")
		assert(tc.has_meta("tier_med_count"), "TreeChunk must have tier_med_count")
		assert(tc.has_meta("tier_high_count"), "TreeChunk must have tier_high_count")
		total_tree_low += int(tc.get_meta("tier_low_count"))
		total_tree_med += int(tc.get_meta("tier_med_count"))
		total_tree_high += int(tc.get_meta("tier_high_count"))

	assert(total_tree_high == 30, "Total trees across all chunks must equal 30")
	assert(total_tree_low > 0 and total_tree_low < total_tree_high, "Low count must be partial subset of total trees")
	assert(total_tree_med >= total_tree_low and total_tree_med <= total_tree_high, "Med count must be between Low and High")

	for bc in bush_chunks:
		assert(bc.get_meta("tier_low_count") == 0, "Bushes must be 0 on Low tier")
		assert(bc.get_meta("tier_med_count") > 0, "Bushes must have positive count on Medium tier")

	# Check ConsolidatedFoliageCollision shapes
	var static_col := course_scene.get_node("ConsolidatedFoliageCollision") as StaticBody3D
	assert(static_col != null, "ConsolidatedFoliageCollision must exist")
	var col_shapes := static_col.get_children()
	assert(col_shapes.size() == 30, "Must create 30 trunk colliders")
	for cs in col_shapes:
		assert(cs.has_meta("foliage_tier"), "Trunk collision shape must have foliage_tier meta")
	print("  PASS: MultiMesh chunks and trunk colliders generated with tier counts & metadata.")

	# 5. Test Dynamic Graphics Quality Scaling (Low / Medium / High)
	print("\n--- Test 5: Dynamic Graphics Quality Scaling ---")

	# Test LOW
	MobilePerformance.apply_graphics_quality(course_scene, "Low")
	for tc in tree_chunks:
		var low_c: int = tc.get_meta("tier_low_count")
		assert(tc.multimesh.visible_instance_count == low_c, "TreeChunk visible_instance_count on Low must equal tier_low_count")
	for bc in bush_chunks:
		assert(bc.visible == false or bc.multimesh.visible_instance_count == 0, "BushChunk must be hidden/0 on Low")
	var disabled_low_count := 0
	for cs in static_col.get_children():
		if cs is CollisionShape3D and cs.disabled:
			disabled_low_count += 1
	assert(disabled_low_count > 0, "Higher-tier trunk colliders must be disabled on Low")

	# Test MEDIUM
	MobilePerformance.apply_graphics_quality(course_scene, "Medium")
	for tc in tree_chunks:
		var med_c: int = tc.get_meta("tier_med_count")
		assert(tc.multimesh.visible_instance_count == med_c, "TreeChunk visible_instance_count on Medium must equal tier_med_count")
	for bc in bush_chunks:
		assert(bc.visible == true, "BushChunk must be visible on Medium")
		assert(bc.multimesh.visible_instance_count > 0, "BushChunk must render subset on Medium")
	var disabled_med_count := 0
	for cs in static_col.get_children():
		if cs is CollisionShape3D and cs.disabled:
			disabled_med_count += 1
	assert(disabled_med_count < disabled_low_count, "Fewer trunk colliders disabled on Medium than Low")

	# Test HIGH
	MobilePerformance.apply_graphics_quality(course_scene, "High")
	for tc in tree_chunks:
		assert(tc.multimesh.visible_instance_count == -1, "TreeChunk visible_instance_count on High must be -1 (all rendered)")
	for bc in bush_chunks:
		assert(bc.visible == true, "BushChunk must be visible on High")
		assert(bc.multimesh.visible_instance_count == -1, "BushChunk visible_instance_count on High must be -1 (all rendered)")
	var disabled_high_count := 0
	for cs in static_col.get_children():
		if cs is CollisionShape3D and cs.disabled:
			disabled_high_count += 1
	assert(disabled_high_count == 0, "No trunk colliders should be disabled on High")

	print("  PASS: Dynamic graphics quality switching seamlessly adds/removes trees, bushes, and colliders on Low/Medium/High.")

	# Test 6: Applying quality from parent root (simulating in-game Visuals Menu toggle) must also disable nested trunk & canopy colliders
	print("\n--- Test 6: Parent Root Quality Scaling ---")
	MobilePerformance.apply_graphics_quality(root, "Low")
	var root_disabled_trunk := 0
	for cs in static_col.get_children():
		if cs is CollisionShape3D and cs.disabled:
			root_disabled_trunk += 1
	assert(root_disabled_trunk == disabled_low_count, "Applying Low from /root must disable higher-tier trunk colliders")
	var canopy_area := course_scene.get_node_or_null("ConsolidatedCanopyArea")
	assert(canopy_area != null, "ConsolidatedCanopyArea must exist")
	var root_disabled_canopy := 0
	for cs in canopy_area.get_children():
		if cs is CollisionShape3D and cs.disabled:
			root_disabled_canopy += 1
	assert(root_disabled_canopy == disabled_low_count, "Applying Low from /root must disable higher-tier canopy colliders")
	print("  PASS: Parent root quality scaling properly disables nested trunk & canopy colliders.")

	# Cleanup
	mock_scene.free()
	course_scene.free()

	print("\n=======================================================")
	print("ALL FOLIAGE TIER CLASSIFICATION TESTS PASSED SUCCESSFULLY!")
	print("=======================================================\n")
	quit(0)
	return false
