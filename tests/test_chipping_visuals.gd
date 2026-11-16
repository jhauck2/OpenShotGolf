extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== Running Chipping Practice Visuals & Environment Tests ===")

	var ChippingScript = load("res://Courses/Minigames/Chipping/chipping.gd")
	assert(ChippingScript != null, "chipping.gd must load")

	var chipping = Node3D.new()
	chipping.set_script(ChippingScript)
	chipping.set_process(false)
	chipping.set_physics_process(false)
	root.add_child(chipping)

	# 1. Sky3D or fallback WorldEnvironment
	var sky3d = chipping.get_node_or_null("Sky3D")
	var world_env = chipping.get_node_or_null("WorldEnvironment")
	assert(sky3d != null or world_env != null, "Sky3D or fallback WorldEnvironment must exist")
	print("Test 1 PASS: Sky/Environment initialized (%s)" % ("Sky3D" if sky3d != null else "WorldEnvironment"))

	# 2. Static Lakefront Backdrop
	var backdrop = chipping.get_node_or_null("LakeBackdrop")
	assert(backdrop != null, "LakeBackdrop must be spawned")
	var backdrop_mesh = backdrop.get_node_or_null("LakeBackdropMesh") as MeshInstance3D
	assert(backdrop_mesh != null and backdrop_mesh.mesh != null, "LakeBackdropMesh must exist with valid mesh")
	assert(backdrop_mesh.material_override is StandardMaterial3D, "LakeBackdropMesh must have StandardMaterial3D")
	var b_mat = backdrop_mesh.material_override as StandardMaterial3D
	assert(b_mat.albedo_texture != null, "LakeBackdropMesh must have albedo_texture loaded")
	print("Test 2 PASS: LakeBackdrop spawned with texture")

	# 3. Water Hazard & LakeBed
	var water = chipping.get_node_or_null("WaterPlane")
	assert(water != null and water.get_meta("is_water", false) == true, "WaterPlane must exist with is_water=true")
	var lakebed = water.get_node_or_null("LakeBed")
	assert(lakebed != null, "LakeBed must exist under WaterPlane")
	print("Test 3 PASS: WaterPlane and LakeBed verified")

	# 4. Natural Tee Box Peninsula
	var tee_box = chipping.get_node_or_null("TeeBox")
	assert(tee_box != null, "TeeBox must exist")
	assert(tee_box.get_node_or_null("TeeRockWall") != null, "TeeRockWall must exist")
	assert(tee_box.get_node_or_null("TeeRoughTurf") != null, "TeeRoughTurf must exist")
	assert(tee_box.get_node_or_null("TeeFairwayPatch") != null, "TeeFairwayPatch must exist")
	assert(tee_box.get_node_or_null("TeeMarker_L") != null, "TeeMarker_L must exist")
	assert(tee_box.get_node_or_null("TeeMarker_R") != null, "TeeMarker_R must exist")
	print("Test 4 PASS: Natural TeeBox peninsula verified")

	# 5. 7 Island Greens with Trees, Bushes, and TargetRing
	for i in range(7):
		var island = chipping.get_node_or_null("GreenIsland_%d" % i)
		assert(island != null, "GreenIsland_%d must exist" % i)
		var trees_folder = island.get_node_or_null("TreesFolder")
		assert(trees_folder != null, "TreesFolder must exist on GreenIsland_%d" % i)
		assert(trees_folder.get_node_or_null("IslandTree_0") != null, "IslandTree_0 must exist on GreenIsland_%d" % i)
		assert(trees_folder.get_node_or_null("IslandBush_0") != null, "IslandBush_0 must exist on GreenIsland_%d" % i)

	var first_island = chipping.get_node_or_null("GreenIsland_0")
	var target_ring = first_island.get_node_or_null("TargetRing") as MeshInstance3D
	assert(target_ring != null and target_ring.visible, "TargetRing must be visible on default selected island")
	print("Test 5 PASS: All 7 islands, trees, bushes, and TargetRing verified")

	print("ALL CHIPPING VISUAL TESTS PASSED")
	quit(0)
