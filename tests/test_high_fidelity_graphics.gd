extends SceneTree

## Test HighFidelity Graphics Pipeline, MultiMesh Foliage, 3D Course Detail, & Course Upgrader
## Validates:
## 1. All new & upgraded shaders compile and load cleanly
## 2. HighFidelityLighting calibrated outdoor lighting (AgX, SSAO, SSR, single-pass depth fog, SDFGI/SSIL/VolumetricFog disabled, incremental Sky)
## 3. ProceduralTreeGenerator spatial MultiMesh foliage chunking + consolidated Jolt collision + tree_records metadata
## 4. CourseDetailEnhancer recessed 3D bunker bowl/lip meshes, overhanging lip fescue, shoreline reeds, cart paths, and horizon skirt
## 5. HighFidelityGrass GPU MultiMesh 3D grass layers
## 6. HighFidelityBuilder lifecycle (apply and remove)
## 7. CourseGraphicsUpgrader in-place course.tscn + course.json v1 -> v2 upgrade

const HighFidelityLighting = preload("res://HighFidelity/Lighting/high_fidelity_lighting.gd")
const HighFidelityOverlay = preload("res://HighFidelity/Core/high_fidelity_overlay.gd")
const HighFidelityBuilder = preload("res://HighFidelity/Core/high_fidelity_builder.gd")
const ProceduralTreeGenerator = preload("res://HighFidelity/Foliage/procedural_tree_generator.gd")
const CourseDetailEnhancer = preload("res://HighFidelity/Terrain/course_detail_enhancer.gd")
const HighFidelityGrass = preload("res://HighFidelity/Foliage/high_fidelity_grass.gd")
const CourseGraphicsUpgrader = preload("res://Utils/CourseGraphicsUpgrader.gd")

var _tested := false

func _process(_delta: float) -> bool:
	if _tested:
		return false
	_tested = true

	print("\n=======================================================")
	print("STARTING TEST: High Fidelity Graphics Overhaul & Upgrader")
	print("=======================================================")

	# 1. Test all shader resources compile and load cleanly
	var shader_paths := [
		"res://Courses/Environments/shaders/terrain_splat.gdshader",
		"res://Courses/Environments/shaders/terrain_splat_realistic.gdshader",
		"res://Courses/Environments/shaders/driving_range_turf_realistic.gdshader",
		"res://Courses/Environments/shaders/foliage_realistic.gdshader",
		"res://Courses/Environments/shaders/trees_shader.gdshader",
		"res://Courses/Environments/shaders/water_shader.gdshader",
		"res://Courses/Environments/shaders/grass_blades_high.gdshader",
		"res://Courses/Environments/shaders/bunker_high.gdshader",
		"res://Courses/Environments/shaders/cart_path.gdshader"
	]
	for sp in shader_paths:
		var sh := load(sp) as Shader
		assert(sh != null, "Shader must load cleanly: " + sp)
	print("  PASS: All 9 high-fidelity & optimized shaders loaded cleanly.")

	# 2. Build mock course scene with WorldEnvironment, DirectionalLight3D, Terrain, Trees, Bunker, Water, and Hole
	var mock_scene := _create_mock_v1_course_scene()
	root.add_child(mock_scene)

	var env_node := mock_scene.get_node("Sky3D") as WorldEnvironment
	var env := env_node.environment
	var dir_light := env_node.get_node("SunLight") as DirectionalLight3D

	# 3. Apply HighFidelityLighting and verify calibrated outdoor settings
	HighFidelityLighting.apply(mock_scene)
	assert(env.sdfgi_enabled == false, "SDFGI must be disabled for 60+ FPS outdoor performance")
	assert(env.ssil_enabled == false, "SSIL must be disabled for 60+ FPS outdoor performance")
	assert(env.volumetric_fog_enabled == false, "Volumetric fog must be disabled in favor of crisp single-pass depth fog")
	assert(env.ssao_enabled == true, "SSAO must be enabled on High graphics")
	assert(env.ssr_enabled == true, "SSR must be enabled on High graphics")
	assert(env.fog_enabled == true, "Atmospheric depth fog must be enabled on High graphics")
	assert(env.fog_mode == Environment.FOG_MODE_DEPTH, "Atmospheric fog must use FOG_MODE_DEPTH so playable distances stay crystal clear")
	assert(float(env.get("fog_depth_begin")) >= 350.0, "Depth fog must begin well past typical fairway/target distances (>= 350m)")
	assert(float(env.get("fog_depth_end")) >= 1200.0, "Depth fog must ramp gently to far horizon (>= 1200m)")
	assert(is_equal_approx(env.glow_bloom, 0.0), "Full-screen glow_bloom must be 0.0 to avoid overall image softness")
	assert(is_equal_approx(env.tonemap_white, 6.0), "AgX tonemap_white must be calibrated to 6.0")
	assert(env.sky.process_mode == Sky.PROCESS_MODE_INCREMENTAL, "Sky process_mode must be INCREMENTAL on High")
	assert(dir_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "4-split shadow cascades must be active")
	assert(is_equal_approx(dir_light.directional_shadow_split_1, 0.025), "Near shadow cascade split_1 must be tight (0.025)")
	print("  PASS: HighFidelityLighting applied calibrated AgX, SSAO, SSR, single-pass depth fog, and tight 4-split shadows.")

	# 4. Remove HighFidelityLighting and verify restoration
	HighFidelityLighting.remove(mock_scene)
	assert(env.ssao_enabled == false, "SSAO must be restored to original state on remove")
	assert(env.ssr_enabled == false, "SSR must be restored to original state on remove")
	print("  PASS: HighFidelityLighting cleanly restored environment on removal.")

	# 5. Test ProceduralTreeGenerator MultiMesh conversion + consolidated physics + metadata
	var conv_stats := ProceduralTreeGenerator.convert_scene_foliage_to_multimesh(mock_scene, true)
	assert(int(conv_stats["trees_converted"]) == 3, "All 3 mock trees must be converted into MultiMesh chunks")
	assert(int(conv_stats["chunks_created"]) >= 1, "At least 1 spatial MultiMesh chunk must be created")
	var mm_container := mock_scene.get_node_or_null("MultiMeshFoliageContainer")
	assert(mm_container != null, "MultiMeshFoliageContainer must exist on scene")
	assert(mm_container.has_meta("tree_records"), "MultiMeshFoliageContainer must store tree_records metadata")
	var records = mm_container.get_meta("tree_records")
	assert(records.size() == 24, "tree_records metadata must contain 24 floats (3 trees * 8 floats)")
	assert(mock_scene.has_node("ConsolidatedFoliageCollision"), "ConsolidatedFoliageCollision StaticBody3D must exist")
	var canopy_area := mock_scene.get_node_or_null("ConsolidatedCanopyArea")
	assert(canopy_area != null and canopy_area.is_in_group("tree_canopy"), "ConsolidatedCanopyArea must exist and be in tree_canopy group")
	print("  PASS: ProceduralTreeGenerator converted individual trees into spatial MultiMesh chunks & consolidated physics.")

	# 6. Test CourseDetailEnhancer (recessed 3D bunkers, overhanging lip grass, shoreline reeds, cart paths, horizon skirt)
	var detail_stats := CourseDetailEnhancer.enhance_course_scene(mock_scene, true)
	assert(int(detail_stats["bunkers_built"]) == 1, "1 recessed 3D bunker must be built")
	assert(mock_scene.has_node("HighFidelityBunkers"), "HighFidelityBunkers container must exist")
	assert(mock_scene.has_node("BunkerLipGrassMultiMesh") or (mock_scene.has_node("HighFidelityBunkers") and mock_scene.get_node("HighFidelityBunkers").has_node("BunkerLipGrassMultiMesh")), "BunkerLipGrassMultiMesh must exist")
	var bunker_grass_mmi = mock_scene.get_node_or_null("BunkerLipGrassMultiMesh") as MultiMeshInstance3D
	if bunker_grass_mmi != null and bunker_grass_mmi.multimesh != null:
		assert(bunker_grass_mmi.multimesh.instance_count == 0, "BunkerLipGrassMultiMesh instance_count must be 0 to keep sand traps free of grass weeds")
	assert(mock_scene.has_node("ShorelineReedsMultiMesh"), "ShorelineReedsMultiMesh must exist around water pond")
	var reeds_mmi := mock_scene.get_node("ShorelineReedsMultiMesh") as MultiMeshInstance3D
	assert(reeds_mmi.multimesh != null and reeds_mmi.multimesh.instance_count >= 50, "ShorelineReedsMultiMesh must continuously surround the entire water pond perimeter (>= 50 clumps for 60m perimeter)")
	assert(mock_scene.has_node("HorizonSkirt"), "HorizonSkirt outer terrain ring must exist")
	assert(mock_scene.has_node("CartPaths"), "CartPaths extruded ribbon mesh must exist")
	var cart_paths_node := mock_scene.get_node("CartPaths") as MeshInstance3D
	assert(cart_paths_node.mesh != null, "CartPaths mesh must not be null")
	var cp_mat := cart_paths_node.mesh.surface_get_material(0) as ShaderMaterial
	assert(cp_mat != null and cp_mat.shader != null, "CartPaths must have a ShaderMaterial with cart_path.gdshader")
	var cp_arrays := cart_paths_node.mesh.surface_get_arrays(0)
	var cp_verts: PackedVector3Array = cp_arrays[Mesh.ARRAY_VERTEX]
	assert(cp_verts.size() > 0, "CartPaths mesh must contain vertices")
	for v in cp_verts:
		assert(absf(v.y - 0.030) < 0.01, "Cart path vertex Y (%.4f) must conform snugly to terrain elevation at +0.030m and not float" % v.y)
	assert(not mock_scene.has_node("ThickRoughGrassMultiMesh"), "Long 3D grass patches (ThickRoughGrassMultiMesh) must not be spawned")
	assert(int(detail_stats["thick_rough_grass"]) == 0, "Thick rough 3D grass cluster count must be 0")
	assert(mock_scene.has_node("ThickRoughBushes"), "ThickRoughBushes container must exist in outer rough")
	assert(int(detail_stats["thick_rough_bushes"]) > 0, "Thick rough sporadic bushes must be generated")

	# Verify elevated deep_rough_map (>= 25% ball lie resistance, d >= 37.5m from fairway/green)
	var ut := mock_scene.get_node("UnifiedTerrain") as MeshInstance3D
	var ut_mat := ut.mesh.surface_get_material(0) as ShaderMaterial
	assert(ut_mat.get_shader_parameter("has_deep_rough_map") == true, "UnifiedTerrain must have has_deep_rough_map enabled")
	assert(ut_mat.get_shader_parameter("deep_rough_map") != null, "UnifiedTerrain must have deep_rough_map texture bound")
	var dr_img: Image = ut.get_meta("deep_rough_image") as Image
	assert(dr_img != null, "UnifiedTerrain must store deep_rough_image metadata")
	# Fairway is [-10..10] in X and [-10..10] in Z on a [-100..100] x [-100..100] terrain (256x256).
	# At world (25, 0) -> d = 15m from fairway (16% lie resistance < 25%) -> deep_rough_map must be 0.0
	var px_near := int(round((25.0 - (-100.0)) / 200.0 * 255.0))
	var pz_mid := int(round((0.0 - (-100.0)) / 200.0 * 255.0))
	assert(dr_img.get_pixel(px_near, pz_mid).r < 0.05, "Rough at 15m (16% lie resistance < 25%) must NOT have elevated deep rough texture")
	# At world (60, 0) -> d = 50m from fairway (30% lie resistance >= 25%) -> deep_rough_map must be 1.0
	var px_far := int(round((60.0 - (-100.0)) / 200.0 * 255.0))
	assert(dr_img.get_pixel(px_far, pz_mid).r > 0.95, "Rough at 50m (30% lie resistance >= 25%) MUST have elevated deep rough texture")

	# Verify terrain_splat_realistic.gdshader has no yellow discoloration and uses deep_rough_map
	var realistic_shader_code := FileAccess.get_file_as_string("res://Courses/Environments/shaders/terrain_splat_realistic.gdshader")
	assert(not realistic_shader_code.contains("golden_straw_tint"), "terrain_splat_realistic.gdshader must not contain golden_straw_tint yellow discoloration")
	assert(not realistic_shader_code.contains("dry_patch"), "terrain_splat_realistic.gdshader must not contain dry_patch yellow discoloration")
	assert(realistic_shader_code.contains("deep_rough_map"), "terrain_splat_realistic.gdshader must sample deep_rough_map for >=25% lie resistance")
	assert(not realistic_shader_code.contains("smoothstep(0.15, 0.65, rough_w)"), "terrain_splat_realistic.gdshader must not over-attenuate deep rough with high rough weight threshold")

	# Test concave bunker manifold extraction (ensures concave shapes are preserved and not flattened into convex hulls)
	var l_faces := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10),
		Vector3(0, 0, 0), Vector3(10, 0, 10), Vector3(0, 0, 10),
		Vector3(10, 0, 0), Vector3(20, 0, 0), Vector3(20, 0, 10),
		Vector3(10, 0, 0), Vector3(20, 0, 10), Vector3(10, 0, 10),
		Vector3(0, 0, 10), Vector3(10, 0, 10), Vector3(10, 0, 20),
		Vector3(0, 0, 10), Vector3(10, 0, 20), Vector3(0, 0, 20)
	])
	var concave_boundary: PackedVector2Array = CourseDetailEnhancer._extract_boundary_polygon_from_faces(l_faces, Transform3D.IDENTITY)
	assert(concave_boundary.size() == 6, "Concave L-shaped bunker must preserve all 6 vertices, got %d" % concave_boundary.size())
	var has_inner_corner := false
	for pt in concave_boundary:
		if pt.distance_squared_to(Vector2(10.0, 10.0)) < 0.01:
			has_inner_corner = true
			break
	assert(has_inner_corner, "Concave inner corner (10, 10) must be preserved and not bypassed by convex hull")

	# Verify CourseDetailEnhancer upgrades existing cartpath_* MeshInstances from OsmMapLoader
	var test_osm_scene := Node3D.new()
	var test_cp_mi := MeshInstance3D.new()
	test_cp_mi.name = "cartpath_0"
	var test_arr := []
	test_arr.resize(Mesh.ARRAY_MAX)
	test_arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, 5),
		Vector3(2, 0, 0), Vector3(2, 0, 5), Vector3(0, 0, 5)
	])
	test_arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	var test_mesh := ArrayMesh.new()
	test_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, test_arr)
	test_cp_mi.mesh = test_mesh
	test_osm_scene.add_child(test_cp_mi)
	var cp_upgraded := CourseDetailEnhancer._build_cart_paths(test_osm_scene, {}, false)
	assert(cp_upgraded == true, "_build_cart_paths must return true for existing cartpath MeshInstances")
	assert(test_osm_scene.has_node("cartpath_0"), "Existing cartpath_0 node must be preserved")
	var upgraded_mi := test_osm_scene.get_node("cartpath_0") as MeshInstance3D
	var upgraded_mat := upgraded_mi.get_surface_override_material(0) as ShaderMaterial
	assert(upgraded_mat != null and upgraded_mat.shader != null, "cartpath_0 must receive cart_path.gdshader")
	var upgraded_arrays := upgraded_mi.mesh.surface_get_arrays(0)
	var upgraded_uvs = upgraded_arrays[Mesh.ARRAY_TEX_UV]
	assert(upgraded_uvs != null and upgraded_uvs.size() == 6, "UVs must be auto-generated for cartpath without UVs")
	test_osm_scene.free()

	print("  PASS: CourseDetailEnhancer built recessed 3D bunkers, clean hazard lip, shoreline reeds, cart paths, and horizon skirt.")

	# 7. Test HighFidelityBuilder coordinator lifecycle (including HighFidelityGrass & HighFidelityOverlay)
	var builder := HighFidelityBuilder.apply_high_fidelity(mock_scene)
	if HighFidelityBuilder.is_supported():
		assert(builder != null, "HighFidelityBuilder must be instantiated on desktop")
		assert(mock_scene.has_node("HighFidelityBuilder"), "HighFidelityBuilder must be added as child")
		assert(env.ssao_enabled == true, "Builder must have applied HighFidelityLighting")
		var grass_node := builder.get_node_or_null("HighFidelityGrass")
		assert(grass_node != null, "HighFidelityGrass must be instantiated by HighFidelityBuilder")
		assert(grass_node.has_node("DeepRoughBladesMultiMesh"), "Real 3D deep rough blade field must exist for the >=25% lie resistance zone")
		var deep_mmi_check := grass_node.get_node("DeepRoughBladesMultiMesh") as MultiMeshInstance3D
		var deep_mm := deep_mmi_check.multimesh
		assert(deep_mm.instance_count >= 5000, "Deep rough blade field must have expanded 18m coverage (>= 5000 instances)")
		assert(deep_mmi_check.visible == true, "Rough grass must remain visible across rough areas without landing pop-in")
		# Verify cart path exclusion: grass must never spawn on or inside cart paths
		var cp_segs: Array = grass_node.get("_cart_path_segments")
		assert(cp_segs.size() > 0, "Cart path segments must be detected for grass exclusion")
		var cp_mid: Vector2 = (cp_segs[0]["a"] + cp_segs[0]["b"]) * 0.5
		assert(grass_node.call("_is_on_cart_path", cp_mid.x, cp_mid.y) == true, "Points inside cart path must be detected by _is_on_cart_path")
		assert(grass_node.call("_is_in_bunker_or_hazard", cp_mid.x, cp_mid.y) == true, "Points on cart path must be excluded by _is_in_bunker_or_hazard")

		# Verify bunker exclusion: grass must never activate when lie is sand or point is in bunker
		var dummy_p = mock_scene.get_node_or_null("Player")
		if dummy_p != null:
			dummy_p.set("current_lie_type", "sand")
			dummy_p.set("current_shot_reduction", 0.35)
			assert(grass_node.call("_is_anchor_in_deep_rough", Vector3(10, 0, 10)) == false, "Deep rough must never activate in sand traps")
			dummy_p.set("current_lie_type", "fairway")
			assert(grass_node.call("_is_anchor_in_deep_rough", Vector3(10, 0, 10)) == false, "Deep rough must never activate on fairway")
			dummy_p.set("current_lie_type", "rough")
			dummy_p.set("current_shot_reduction", 0.26)
			assert(grass_node.call("_is_anchor_in_deep_rough", Vector3(10, 0, 10)) == true, "Deep rough must activate in >= 25% rough")
			# Verify fallback to last_shot_reduction when current_shot_reduction was reset upon ball landing
			dummy_p.set("current_shot_reduction", 0.0)
			dummy_p.set("last_shot_reduction", 0.28)
			assert(grass_node.call("_is_anchor_in_deep_rough", Vector3(10, 0, 10)) == true, "Deep rough must activate from last_shot_reduction when current_shot_reduction was reset")
			# Verify distance check at world (60, 0) which is 50m from fairway (> 36m, 30% resistance >= 25%)
			dummy_p.set("last_shot_reduction", 0.0)
			assert(grass_node.call("_is_anchor_in_deep_rough", Vector3(60, 0, 0)) == true, "Deep rough must activate at 50m rough (30% resistance >= 25%)")

		# Verify ensure_deep_rough_map supports alternate terrain node names (e.g. TerrainMesh)
		var alt_scene := Node3D.new()
		var alt_terrain := MeshInstance3D.new()
		alt_terrain.name = "TerrainMesh"
		var alt_pm := PlaneMesh.new()
		alt_pm.size = Vector2(100.0, 100.0)
		var alt_am := ArrayMesh.new()
		alt_am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, alt_pm.get_mesh_arrays())
		alt_terrain.mesh = alt_am
		alt_scene.add_child(alt_terrain)
		var alt_tex := CourseDetailEnhancer.ensure_deep_rough_map(alt_scene)
		assert(alt_tex != null, "ensure_deep_rough_map must find terrain named TerrainMesh")
		alt_scene.free()

		var dense_clump: ArrayMesh = grass_node.call("_create_dense_deep_rough_mesh", 0.28, 0.028, 0.05)
		assert(dense_clump != null and dense_clump.get_surface_count() > 0, "Dense turf mesh must generate successfully")
		var arrays := dense_clump.surface_get_arrays(0)
		var vert_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		assert(vert_count >= 400, "Dense 3-tier turf clump must have at least 400 vertices for 100%% seamless ground coverage")

		# Verify calibrated deep rough material colors (natural lush turf matching Image 2, not pitch-black spikes)
		var deep_mmi_node := grass_node.get_node("DeepRoughBladesMultiMesh") as MultiMeshInstance3D
		assert(deep_mmi_node != null and deep_mmi_node.multimesh != null, "DeepRoughBladesMultiMesh must be created")
		var deep_mat: ShaderMaterial = deep_mmi_node.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		assert(deep_mat != null, "Deep rough mesh must have a valid ShaderMaterial")
		var root_c: Color = deep_mat.get_shader_parameter("root_color")
		var tip_c: Color = deep_mat.get_shader_parameter("tip_color")
		assert(root_c.g >= 0.20, "Root color must be lush deep green rather than pitch black")
		assert(tip_c.g >= 0.45, "Tip color must be vibrant natural green")

		if grass_node.has_node("AddressTurfMultiMesh"):
			assert(grass_node.has_node("RoughFescueMultiMesh"), "RoughFescueMultiMesh must exist when grass meshes are enabled")
		assert(grass_node.get("_deep_rough_generated") == true, "Deep rough blades must be generated up front during setup")
		assert(not mock_scene.has_node("ThickRoughGrassMultiMesh"), "Long 3D grass patches must not exist on high graphics")
		assert(mock_scene.get_node("ThickRoughBushes").visible == true, "Thick rough bushes must be visible on high graphics")
		print("  PASS: HighFidelityBuilder and HighFidelityGrass active and verified.")

		HighFidelityBuilder.remove_high_fidelity(mock_scene)
		assert(not mock_scene.has_node("HighFidelityBuilder"), "Builder must be removed on teardown")
		assert(mock_scene.get_node("ThickRoughBushes").visible == false, "Thick rough bushes must be hidden on low/medium graphics")

		# Verify thick rough exists and renders ONLY in High graphics setting
		MobilePerformance.apply_graphics_quality(mock_scene, "Medium")
		assert(not mock_scene.has_node("DeepRoughGrassMedium"), "Deep rough blades must not exist on Medium graphics")
		assert(mock_scene.get_node("ThickRoughBushes").visible == false, "Thick rough bushes must be hidden on Medium graphics")
		var ut_med := mock_scene.get_node("UnifiedTerrain") as MeshInstance3D
		var ut_med_mat := ut_med.mesh.surface_get_material(0) as ShaderMaterial
		assert(ut_med_mat.get_shader_parameter("has_deep_rough_map") == false, "Terrain has_deep_rough_map must be false on Medium graphics")

		MobilePerformance.apply_graphics_quality(mock_scene, "Low")
		assert(not mock_scene.has_node("DeepRoughGrassMedium"), "Deep rough blades must not exist on Low graphics")
		assert(mock_scene.get_node("ThickRoughBushes").visible == false, "Thick rough bushes must be hidden on Low graphics")

		print("  PASS: HighFidelityBuilder removed and thick rough confirmed exclusive to High graphics.")

	mock_scene.queue_free()

	# 8. Test CourseGraphicsUpgrader end-to-end on a temporary v1 course directory
	_test_course_graphics_upgrader()

	# 9. Verify realistic 16-sided trunk & volumetric multi-lobe canopy tree meshes + in-place MultiMesh upgrade
	for tree_mesh_path in [
		"res://addons/shapespark-low-poly-exterior-plants/meshes/tree-01-1-mesh.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/meshes/tree-02-1-mesh.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/meshes/tree-03-1-mesh.tscn"
	]:
		var tm_scene := load(tree_mesh_path) as PackedScene
		assert(tm_scene != null, "Tree mesh scene must load: " + tree_mesh_path)
		var tm_inst := tm_scene.instantiate() as MeshInstance3D
		assert(tm_inst != null and tm_inst.mesh is ArrayMesh, "Tree mesh must be an ArrayMesh")
		var am := tm_inst.mesh as ArrayMesh
		assert(am.get_surface_count() == 3, "Tree mesh must have 3 surfaces (Trunk, Branch-1, Branch-2)")
		assert(am.surface_get_name(0) == "Trunk", "Surface 0 must be named Trunk")
		assert(am.get_faces().size() >= 2600, "Realistic 16-sided trunk + multi-lobed canopy mesh must have >= 2600 face vertices, got %d" % am.get_faces().size())
		tm_inst.free()
	print("  PASS: Realistic 16-sided cylindrical trunk & dense multi-lobed canopy tree meshes verified.")

	print("=======================================================")
	print("ALL HIGH FIDELITY GRAPHICS & UPGRADER TESTS PASSED! 🎉")
	print("=======================================================")
	quit(0)
	return false


func _create_mock_v1_course_scene() -> Node3D:
	var scene := Node3D.new()
	scene.name = "MockCourseV1"

	var env_node := WorldEnvironment.new()
	env_node.name = "Sky3D"
	var env := Environment.new()
	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.ssao_enabled = false
	env.ssr_enabled = false
	env_node.environment = env
	scene.add_child(env_node)
	env_node.owner = scene

	var dir_light := DirectionalLight3D.new()
	dir_light.name = "SunLight"
	env_node.add_child(dir_light)
	dir_light.owner = scene

	# UnifiedTerrain
	var terrain := MeshInstance3D.new()
	terrain.name = "UnifiedTerrain"
	var pmesh := PlaneMesh.new()
	pmesh.size = Vector2(200.0, 200.0)
	pmesh.subdivide_width = 10
	pmesh.subdivide_depth = 10
	var amesh := ArrayMesh.new()
	amesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pmesh.get_mesh_arrays())
	var tmat := ShaderMaterial.new()
	tmat.shader = load("res://Courses/Environments/shaders/terrain_splat.gdshader") as Shader
	amesh.surface_set_material(0, tmat)
	terrain.mesh = amesh
	scene.add_child(terrain)
	terrain.owner = scene

	# Hole_1 with TeeSpawn and TargetPoint
	var hole1 := Node3D.new()
	hole1.name = "Hole_1"
	scene.add_child(hole1)
	hole1.owner = scene

	var tee := Node3D.new()
	tee.name = "TeeSpawn"
	tee.position = Vector3(-40.0, 0.0, 0.0)
	hole1.add_child(tee)
	tee.owner = scene

	var target := Node3D.new()
	target.name = "TargetPoint"
	target.position = Vector3(60.0, 0.0, 0.0)
	hole1.add_child(target)
	target.owner = scene

	# Fairway StaticBody3D [-10..10] x [-10..10]
	var fw_body := StaticBody3D.new()
	fw_body.name = "fairway_Static_1"
	fw_body.set_meta("surface_type", 0)
	var fw_col := CollisionShape3D.new()
	var fw_shape := ConcavePolygonShape3D.new()
	fw_shape.set_faces(PackedVector3Array([
		Vector3(-10.0, 0.0, -10.0), Vector3(10.0, 0.0, -10.0), Vector3(10.0, 0.0, 10.0),
		Vector3(-10.0, 0.0, -10.0), Vector3(10.0, 0.0, 10.0), Vector3(-10.0, 0.0, 10.0)
	]))
	fw_col.shape = fw_shape
	fw_body.add_child(fw_col)
	scene.add_child(fw_body)
	fw_body.owner = scene
	fw_col.owner = scene

	# Bunker StaticBody3D with ConcavePolygonShape3D
	var bunker_body := StaticBody3D.new()
	bunker_body.name = "Bunker_1"
	bunker_body.set_meta("is_sand", true)
	bunker_body.set_meta("surface_type", 2)
	var b_col := CollisionShape3D.new()
	var b_shape := ConcavePolygonShape3D.new()
	b_shape.set_faces(PackedVector3Array([
		Vector3(10.0, 0.0, -5.0), Vector3(18.0, 0.0, -5.0), Vector3(18.0, 0.0, 5.0),
		Vector3(10.0, 0.0, -5.0), Vector3(18.0, 0.0, 5.0), Vector3(10.0, 0.0, 5.0)
	]))
	b_col.shape = b_shape
	bunker_body.add_child(b_col)
	scene.add_child(bunker_body)
	bunker_body.owner = scene
	b_col.owner = scene

	# Water pond MeshInstance3D
	var water_mi := MeshInstance3D.new()
	water_mi.name = "Water_1"
	var w_arr_mesh := ArrayMesh.new()
	var w_st := SurfaceTool.new()
	w_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	w_st.set_normal(Vector3.UP)
	w_st.add_vertex(Vector3(-25.0, -0.2, 15.0))
	w_st.add_vertex(Vector3(-10.0, -0.2, 15.0))
	w_st.add_vertex(Vector3(-10.0, -0.2, 30.0))
	w_st.add_vertex(Vector3(-25.0, -0.2, 15.0))
	w_st.add_vertex(Vector3(-10.0, -0.2, 30.0))
	w_st.add_vertex(Vector3(-25.0, -0.2, 30.0))
	w_st.commit(w_arr_mesh)
	var w_mat := ShaderMaterial.new()
	w_mat.shader = load("res://Courses/Environments/shaders/water_shader.gdshader") as Shader
	w_arr_mesh.surface_set_material(0, w_mat)
	water_mi.mesh = w_arr_mesh
	scene.add_child(water_mi)
	water_mi.owner = scene

	# 3 Mock Tree nodes
	var tree_scene := load("res://addons/shapespark-low-poly-exterior-plants/bodies/tree-01-1-staticbody.tscn") as PackedScene
	if tree_scene != null:
		for i in range(3):
			var t := tree_scene.instantiate() as Node3D
			t.name = "Tree_%d" % i
			t.position = Vector3(-15.0 + float(i) * 12.0, 0.0, -20.0)
			scene.add_child(t)
			t.owner = scene

	return scene


func _test_course_graphics_upgrader() -> void:
	var test_base := "user://test_upgrader_courses"
	var course_dir := test_base.path_join("mock_v1_course")
	DirAccess.make_dir_recursive_absolute(course_dir)

	var scene_path := course_dir.path_join("course.tscn")
	var config_path := course_dir.path_join("course.json")

	var v1_scene := _create_mock_v1_course_scene()
	var packed := PackedScene.new()
	packed.pack(v1_scene)
	v1_scene.free()
	ResourceSaver.save(packed, scene_path)

	var v1_json := {
		"scene_path": "course.tscn",
		"Title": "Mock V1 Course"
	}
	var jf := FileAccess.open(config_path, FileAccess.WRITE)
	jf.store_string(JSON.stringify(v1_json, "\t"))
	jf.close()

	var pending := CourseGraphicsUpgrader.get_courses_needing_upgrade(test_base)
	assert(pending.size() == 1, "CourseGraphicsUpgrader must detect 1 v1 course needing upgrade")

	var ok := CourseGraphicsUpgrader.upgrade_single_course(pending[0])
	assert(ok == true, "CourseGraphicsUpgrader.upgrade_single_course must succeed")

	var pending_after := CourseGraphicsUpgrader.get_courses_needing_upgrade(test_base)
	assert(pending_after.is_empty(), "Upgraded course must have graphics_version=2 and no longer be pending")

	# Verify upgraded course.tscn has MultiMeshFoliageContainer and HighFidelityBunkers
	var upgraded_packed := ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert(upgraded_packed != null, "Upgraded course.tscn must load cleanly")
	var upgraded_inst := upgraded_packed.instantiate()
	assert(upgraded_inst.has_node("MultiMeshFoliageContainer"), "Upgraded course.tscn must contain MultiMeshFoliageContainer")
	assert(upgraded_inst.has_node("HighFidelityBunkers"), "Upgraded course.tscn must contain HighFidelityBunkers")
	var sky3d := upgraded_inst.get_node_or_null("Sky3D") as WorldEnvironment
	assert(sky3d.environment.sky.process_mode == Sky.PROCESS_MODE_REALTIME, "Upgraded course.tscn Sky must use PROCESS_MODE_REALTIME")
	var skydome := sky3d.get_node_or_null("Skydome")
	if skydome != null and "clouds_speed" in skydome:
		assert(is_equal_approx(skydome.get("clouds_speed"), 0.005), "Skydome clouds_speed must be 0.005 for gradual drift")
	upgraded_inst.free()

	# Clean up temporary test folder
	DirAccess.remove_absolute(scene_path)
	DirAccess.remove_absolute(config_path)
	DirAccess.remove_absolute(course_dir)
	DirAccess.remove_absolute(test_base)
	print("  PASS: CourseGraphicsUpgrader detected v1 course, upgraded it in-place to v2, and stamped graphics_version=2.")
