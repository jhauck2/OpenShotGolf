extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== Testing LoftControl Environment & Target Wall ===")

	var script = load("res://Courses/Minigames/LoftControl/loft_control.gd")
	assert(script != null, "loft_control.gd must load cleanly")

	var instance = Node3D.new()
	instance.set_script(script)
	instance.set_process(false)
	instance.set_physics_process(false)
	root.add_child(instance)

	# 1. Verify terrain height profile (flat in central fairway, rolling hills outside)
	var center_h: float = instance.call("_get_terrain_height", 50.0, 0.0)
	assert(is_equal_approx(center_h, 0.0), "Central fairway must be flat at y=0, got %s" % center_h)

	var tee_h: float = instance.call("_get_terrain_height", 0.0, 0.0)
	assert(is_equal_approx(tee_h, 0.0), "Tee box must be flat at y=0, got %s" % tee_h)

	var side_hill_h: float = instance.call("_get_terrain_height", 60.0, 90.0)
	assert(side_hill_h > 0.5, "Lateral hills must rise above y=0, got %s" % side_hill_h)

	var far_hill_h: float = instance.call("_get_terrain_height", 300.0, 0.0)
	assert(far_hill_h > 1.0, "Far hillside must rise above y=0, got %s" % far_hill_h)
	print("  PASS: Terrain height profile verified.")

	# 2. Initialize materials and build ground + wall
	instance.call("_init_materials")
	instance.call("_setup_range_ground")
	instance.call("_setup_glass_wall_and_panes")

	assert(instance.get_node_or_null("RangeFairwayGround") != null, "RangeFairwayGround must exist")
	var ground_mesh_inst = instance.get_node("RangeFairwayGround") as MeshInstance3D
	var ground_mat = ground_mesh_inst.mesh.surface_get_material(0)
	assert(ground_mat is ShaderMaterial and ground_mat.shader.resource_path.ends_with("driving_range_turf_realistic.gdshader"), "RangeFairwayGround must use driving_range_turf_realistic.gdshader")
	assert(instance.get_node_or_null("RangeFairwayGround/RangeGroundBody") != null, "RangeGroundBody StaticBody3D must exist")
	assert(instance.get_node_or_null("TeeBox/TeeMatBorder") != null, "TeeMatBorder must exist")
	assert(instance.get_node_or_null("TeeBox/TeeMatTurf") != null, "TeeMatTurf must exist")
	assert(instance.get_node_or_null("TeeBox/TeeGrassCollar") != null, "TeeGrassCollar 3D grass blades must exist")
	assert(instance.get_node_or_null("MountainBackdrop/MountainMesh") != null, "MountainBackdrop must exist")
	assert(instance.get_node_or_null("RangeTrees") != null, "RangeTrees must exist")
	assert(instance.get_node_or_null("RangeTrees/MultiMeshFoliageContainer") != null, "RangeTrees must be upgraded to MultiMeshFoliageContainer")

	var wall = instance.get_node_or_null("LoftTargetWall")
	assert(wall != null, "LoftTargetWall must exist")
	var pane_nodes: Array = instance.get("pane_nodes")
	assert(pane_nodes.size() == 9, "LoftTargetWall must have 9 glass panes, got %d" % pane_nodes.size())

	# Verify all structural beams/pillars have valid BoxMesh (not BoxShape3D)
	for child in wall.get_children():
		if child is StaticBody3D:
			for sub in child.get_children():
				if sub is MeshInstance3D:
					assert(sub.mesh is BoxMesh, "Structural MeshInstance3D must use BoxMesh")
	print("  PASS: Range terrain, trees, mountain backdrop, tee box, and 3x3 target wall verified.")

	instance.queue_free()
	print("=== ALL LOFT CONTROL ENVIRONMENT TESTS PASSED ===")
	quit(0)
