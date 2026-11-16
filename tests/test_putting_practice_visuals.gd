extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== Running Putting Practice Visuals & Hole Flag/Ring Tests ===")

	var PuttingPracticeScript = load("res://Courses/Minigames/PuttingPractice/putting_practice.gd")
	assert(PuttingPracticeScript != null, "putting_practice.gd must load")

	var practice = Node3D.new()
	practice.set_script(PuttingPracticeScript)
	practice.set_process(false)
	practice.set_physics_process(false)
	root.add_child(practice)

	# 1. Sky3D or WorldEnvironment
	var sky3d = practice.get_node_or_null("Sky3D")
	var world_env = practice.get_node_or_null("WorldEnvironment")
	assert(sky3d != null or world_env != null, "Sky3D or fallback WorldEnvironment must exist")
	print("Test 1 PASS: Sky/Environment initialized (%s)" % ("Sky3D" if sky3d != null else "WorldEnvironment"))

	# 2. Mountain Backdrop
	var backdrop = practice.get_node_or_null("MountainBackdrop")
	assert(backdrop != null, "MountainBackdrop must be spawned")
	var mountain_mesh = backdrop.get_node_or_null("MountainMesh") as MeshInstance3D
	assert(mountain_mesh != null and mountain_mesh.mesh != null, "MountainMesh must exist with valid mesh")
	print("Test 2 PASS: MountainBackdrop spawned")

	# 3. High-Fidelity MultiMesh Trees
	var trees_folder = practice.get_node_or_null("TreesFolder")
	assert(trees_folder != null, "TreesFolder must exist")
	var mm_container = trees_folder.get_node_or_null("MultiMeshFoliageContainer")
	assert(mm_container != null, "TreesFolder must be converted to MultiMeshFoliageContainer")
	print("Test 3 PASS: Trees converted to MultiMeshFoliageContainer")

	# 4. Green & Rough PBR ShaderMaterials
	var green_mesh = practice.get_node_or_null("PuttingGreenMesh") as MeshInstance3D
	assert(green_mesh != null and green_mesh.material_override is ShaderMaterial, "PuttingGreenMesh must use ShaderMaterial")
	var green_sm = green_mesh.material_override as ShaderMaterial
	assert(int(green_sm.get_shader_parameter("hole_count")) == 8, "PuttingGreenMesh must cut out all 8 holes")
	var rough_mesh = practice.get_node_or_null("PuttingRoughMesh") as MeshInstance3D
	assert(rough_mesh != null and rough_mesh.mesh != null, "PuttingRoughMesh must exist")
	print("Test 4 PASS: PuttingGreenMesh and PuttingRoughMesh materials verified")

	# 5. Hole Flags (all except selected) & Blue TargetRing (only on selected)
	assert(practice.hole_flags.size() == 8, "Must have 8 hole flags")
	assert(practice.target_ring != null and is_instance_valid(practice.target_ring), "TargetRing must exist")
	assert(practice.selected_hole_index == 0, "Default selected hole must be 0")
	assert(not practice.hole_flags[0].visible, "Selected hole 0 flag must be hidden")
	for i in range(1, 8):
		assert(practice.hole_flags[i].visible, "Non-selected hole %d flag must be visible" % i)
	assert(practice.target_ring.visible, "TargetRing must be visible")
	assert(practice.target_ring.global_position.distance_to(practice.holes[0]) < 0.01, "TargetRing must be at hole 0")

	practice._select_hole(4, false)
	assert(practice.selected_hole_index == 4, "Selected hole must update to 4")
	assert(not practice.hole_flags[4].visible, "Selected hole 4 flag must be hidden")
	assert(practice.hole_flags[0].visible, "Previously selected hole 0 flag must now be visible")
	assert(practice.target_ring.global_position.distance_to(practice.holes[4]) < 0.01, "TargetRing must move to hole 4")
	print("Test 5 PASS: Flags shown on all holes except target; TargetRing shown only on target")

	practice.queue_free()
	print("=== ALL PUTTING PRACTICE VISUALS TESTS PASSED ===")
	quit(0)
