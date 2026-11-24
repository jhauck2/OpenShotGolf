extends SceneTree

const CourseDetailEnhancer = preload("res://HighFidelity/Terrain/course_detail_enhancer.gd")
const HighFidelityBuilder = preload("res://HighFidelity/Core/high_fidelity_builder.gd")

var _tested := false


func _process(_delta: float) -> bool:
	if _tested:
		return false
	_tested = true

	print("\n=======================================================")
	print("STARTING TEST: Bunker & Cart Path Ground Conforming")
	print("=======================================================")

	var scene := _build_undulating_test_scene()
	root.add_child(scene)

	# 1. Exact barycentric _sample_height test on saddle & curved terrain cells
	var info: Dictionary = CourseDetailEnhancer._build_terrain_height_lookup(scene)
	assert(bool(info.get("is_regular_grid", false)), "Terrain lookup must detect regular grid")
	assert(bool(info.get("diag_ur_dl", false)), "UnifiedTerrain triangulation must set diag_ur_dl=true")

	var terrain_mi := scene.get_node("UnifiedTerrain") as MeshInstance3D
	var exact_mid := _exact_mesh_height_at(terrain_mi.mesh, 1.0, 1.0)
	var sampled_mid := CourseDetailEnhancer._sample_height(1.0, 1.0, info)
	assert(absf(sampled_mid - exact_mid) < 0.0001,
		"Barycentric _sample_height at saddle diagonal (1,1) must match exact triangle height (%f vs %f)" % [sampled_mid, exact_mid])

	for pt in [Vector2(0.4, 0.3), Vector2(1.7, 1.5), Vector2(-3.2, 2.8), Vector2(6.5, -4.1)]:
		var ex := _exact_mesh_height_at(terrain_mi.mesh, pt.x, pt.y)
		var sp := CourseDetailEnhancer._sample_height(pt.x, pt.y, info)
		assert(absf(sp - ex) < 0.0001,
			"Barycentric _sample_height at %s must match exact triangle height (%f vs %f)" % [str(pt), sp, ex])
	print("  PASS: Exact barycentric _sample_height matches UnifiedTerrain triangles within <0.0001m.")

	# 2. Enhance scene with persist_for_save=true and validate bunker + cart path geometry
	var stats: Dictionary = CourseDetailEnhancer.enhance_course_scene(scene, true)
	assert(int(stats.get("bunkers_built", 0)) == 1, "Must build exactly 1 recessed bunker")
	assert(bool(stats.get("cart_paths", false)), "Must build cart path")
	assert(bool(scene.get_meta("course_details_baked", false)), "persist_for_save=true must set course_details_baked=true")

	var bunkers_node := scene.get_node_or_null("HighFidelityBunkers")
	assert(bunkers_node != null, "HighFidelityBunkers must exist")
	var bunker_mi := bunkers_node.get_node_or_null("RecessedBunker_0") as MeshInstance3D
	assert(bunker_mi != null and bunker_mi.mesh != null, "RecessedBunker_0 mesh must exist")

	var raw_bunker_poly := _get_kidney_bunker_polygon()
	var sanitized_poly: PackedVector2Array = CourseDetailEnhancer._sanitize_and_smooth_bunker_polygon(raw_bunker_poly, 0.65)
	var b_arrays := bunker_mi.mesh.surface_get_arrays(0)
	var b_verts: PackedVector3Array = b_arrays[Mesh.ARRAY_VERTEX]
	var b_cols: PackedColorArray = b_arrays[Mesh.ARRAY_COLOR]
	assert(b_verts.size() > 0 and (b_verts.size() % 3) == 0, "Bunker mesh must contain triangles")

	var min_rim_dh := 999.0
	for i in range(b_verts.size()):
		var v := b_verts[i]
		var col := b_cols[i]
		var th := CourseDetailEnhancer._sample_height(v.x, v.z, info)
		var dh := v.y - th
		assert(dh >= 0.004 and dh <= 0.11,
			"Bunker vertex %d height offset %.4f must be within [+0.004, +0.110]" % [i, dh])
		var p2 := Vector2(v.x, v.z)
		if col.r > 0.7:
			assert(Geometry2D.is_point_in_polygon(p2, sanitized_poly),
				"Interior bunker vertex %s (col=%s) must remain strictly inside sanitized bunker polygon" % [str(p2), str(col)])
		elif col.b > 0.9:
			assert(not Geometry2D.is_point_in_polygon(p2, sanitized_poly),
				"Outer collar/crest vertex %s must remain outside sanitized bunker polygon" % str(p2))
			assert(col.a < 0.01, "Outer grass-side feather ring must be transparent (alpha=%.3f)" % col.a)
		elif col.g > 0.7:
			min_rim_dh = minf(min_rim_dh, dh)
			assert(dh <= 0.105, "Subtle cut-lip rim vertex height offset %.4f must not exceed 0.105m cap" % dh)
	assert(min_rim_dh <= 0.040, "Baseline cut-lip rim offset must be low-profile <= 0.040m (min=%.4f)" % min_rim_dh)

	# Verify exact boundary preservation (no Chaikin corner shrinkage away from raw polygon)
	var corner_dist := 999.0
	var raw_corner := Vector2(-10.0, -5.0)
	for sp in sanitized_poly:
		corner_dist = minf(corner_dist, sp.distance_to(raw_corner))
	assert(corner_dist < 0.01, "Sanitized bunker polygon must preserve raw corners without Chaikin shrinkage (dist=%.4f)" % corner_dist)

	for t in range(b_verts.size() / 3):
		var a := b_verts[t * 3]
		var b := b_verts[t * 3 + 1]
		var c := b_verts[t * 3 + 2]
		var n := (c - a).cross(b - a)
		assert(n.y >= 0.0, "Bunker triangle %d front face must point upward (normal.y=%.4f)" % [t, n.y])
		var e0 := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		var e1 := Vector2(b.x, b.z).distance_to(Vector2(c.x, c.z))
		var e2 := Vector2(c.x, c.z).distance_to(Vector2(a.x, a.z))
		assert(maxf(e0, maxf(e1, e2)) < 1.5,
			"Bunker triangle %d must not shoot an edge across the sand (max edge=%.3f)" % [t, maxf(e0, maxf(e1, e2))])
	print("  PASS: 4-ring kidney bunker preserves raw boundary, uses low-profile transparent-outer collar, zero protruding edges.")

	# 3. Validate 5-column cart path over undulating ridge
	var cart_mi := scene.get_node_or_null("CartPaths") as MeshInstance3D
	assert(cart_mi != null and cart_mi.mesh != null, "CartPaths MeshInstance3D must exist")
	var cp_arrays := cart_mi.mesh.surface_get_arrays(0)
	var cp_verts: PackedVector3Array = cp_arrays[Mesh.ARRAY_VERTEX]
	var cp_uvs: PackedVector2Array = cp_arrays[Mesh.ARRAY_TEX_UV]
	assert(cp_verts.size() >= 10 and (cp_verts.size() % 5) == 0,
		"Cart path must use 5-column cross sections (verts=%d)" % cp_verts.size())

	var min_shoulder_dh := 999.0
	for i in range(cp_verts.size()):
		var v := cp_verts[i]
		var th := CourseDetailEnhancer._sample_height(v.x, v.z, info)
		var dh := v.y - th
		assert(dh >= 0.014 and dh <= 0.15,
			"Cart path vertex %d (u=%.2f) offset %.4f must stay in [+0.014, +0.150]" % [i, cp_uvs[i].x, dh])
		if is_equal_approx(cp_uvs[i].x, 0.0) or is_equal_approx(cp_uvs[i].x, 1.0):
			assert(dh >= 0.021, "Outer shoulder must maintain >= 0.021m clearance (got %.4f)" % dh)
			min_shoulder_dh = minf(min_shoulder_dh, dh)
	assert(min_shoulder_dh <= 0.025, "Flat outer shoulder baseline should hug ~0.022m (min=%.4f)" % min_shoulder_dh)
	print("  PASS: 5-column cart path drapes cleanly [+0.021..+0.150m] over ridge without clipping.")

	# 4. Validate existing 2-column cartpath_* re-drape on force_rebuild=true
	var legacy_scene := _build_legacy_2col_cartpath_scene(terrain_mi.mesh)
	root.add_child(legacy_scene)
	CourseDetailEnhancer.enhance_course_scene(legacy_scene, true, {"force_rebuild": true})
	var legacy_cp := legacy_scene.get_node_or_null("cartpath_0") as MeshInstance3D
	assert(legacy_cp != null and legacy_cp.mesh != null, "Rebuilt cartpath_0 must exist")
	var l_verts: PackedVector3Array = legacy_cp.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert((l_verts.size() % 5) == 0 and l_verts.size() >= 10,
		"Legacy 2-col cartpath_0 must be upgraded to 5-column conforming strip on force_rebuild=true")
	for v in l_verts:
		var dh := v.y - CourseDetailEnhancer._sample_height(v.x, v.z, info)
		assert(dh >= 0.014 and dh <= 0.15, "Upgraded cartpath_0 vertex offset %.4f out of bounds" % dh)
	print("  PASS: Existing 2-column cartpath_0 upgraded to 5-column ground-conforming strip on force_rebuild.")

	# 5. Validate HighFidelityBuilder skips runtime resampling/rebuilding on baked scenes
	var bunker_mesh_id := bunker_mi.mesh.get_instance_id()
	var builder := HighFidelityBuilder.apply_high_fidelity(scene)
	if builder != null:
		assert(bunker_mi.mesh.get_instance_id() == bunker_mesh_id,
			"HighFidelityBuilder.setup must NOT rebuild baked RecessedBunker_0")
		builder.call("refresh", scene)
		assert(bunker_mi.mesh.get_instance_id() == bunker_mesh_id,
			"HighFidelityBuilder.refresh must NOT rebuild baked RecessedBunker_0")
		HighFidelityBuilder.remove_high_fidelity(scene)

	var empty_baked := Node3D.new()
	empty_baked.name = "BakedNoBunkersNoWater"
	empty_baked.set_meta("course_details_baked", true)
	empty_baked.set_meta("generate_3d_bunkers", false)
	empty_baked.set_meta("generate_water_long_grass", false)
	root.add_child(empty_baked)
	var b2 := HighFidelityBuilder.apply_high_fidelity(empty_baked)
	if b2 != null:
		assert(empty_baked.get_node_or_null("HighFidelityBunkers") == null,
			"Baked scene without bunkers must not be re-enhanced during setup")
		b2.call("refresh", empty_baked)
		assert(empty_baked.get_node_or_null("HighFidelityBunkers") == null,
			"Baked scene without bunkers must not be re-enhanced during refresh")
		HighFidelityBuilder.remove_high_fidelity(empty_baked)
	print("  PASS: HighFidelityBuilder skips runtime resampling/rebuilding on baked courses.")

	# 6. Validate legacy terrain delta-carving creates deep concave bunker bowl & stamps concave_bunkers_baked
	var carve_scene := _build_legacy_flat_bunker_scene()
	root.add_child(carve_scene)
	CourseDetailEnhancer.enhance_course_scene(carve_scene, true, {"force_rebuild": true})
	var carved_terrain := carve_scene.get_node("UnifiedTerrain") as MeshInstance3D
	assert(bool(carved_terrain.get_meta("concave_bunkers_baked", false)),
		"Delta-carving must stamp concave_bunkers_baked=true on UnifiedTerrain")
	var carved_info: Dictionary = CourseDetailEnhancer._build_terrain_height_lookup(carve_scene)
	var rim_y := CourseDetailEnhancer._sample_height(-8.0, 0.0, carved_info)
	var center_y_1 := CourseDetailEnhancer._sample_height(0.0, 0.0, carved_info)
	assert(rim_y - center_y_1 >= 0.95,
		"Carved concave bunker rim-to-center relief must be >= 0.95m (got rim=%.3f, center=%.3f)" % [rim_y, center_y_1])
	CourseDetailEnhancer.enhance_course_scene(carve_scene, true, {"force_rebuild": true})
	var carved_info_2: Dictionary = CourseDetailEnhancer._build_terrain_height_lookup(carve_scene)
	var center_y_2 := CourseDetailEnhancer._sample_height(0.0, 0.0, carved_info_2)
	assert(absf(center_y_2 - center_y_1) < 0.0001,
		"Repeated force_rebuild must not double-carve already-baked concave terrain (%.4f vs %.4f)" % [center_y_1, center_y_2])
	print("  PASS: Legacy bunker delta-carving produces %.2fm concave relief and prevents double-carving." % (rim_y - center_y_1))

	carve_scene.queue_free()
	empty_baked.queue_free()
	legacy_scene.queue_free()
	scene.queue_free()

	# 7. Validate legacy splat_map outer sand bleed cleanup & fairway restoration on upgrade
	var splat_scene := _build_legacy_bleed_splat_bunker_scene()
	root.add_child(splat_scene)
	CourseDetailEnhancer.enhance_course_scene(splat_scene, true, {"force_rebuild": true})
	var splat_terrain := splat_scene.get_node("UnifiedTerrain") as MeshInstance3D
	assert(bool(splat_terrain.get_meta("bunker_splat_v23_baked", false)),
		"Upgrading must stamp bunker_splat_v23_baked=true on UnifiedTerrain")
	var updated_mat := splat_terrain.mesh.surface_get_material(0) as ShaderMaterial
	var updated_splat := updated_mat.get_shader_parameter("splat_map") as Texture2D
	assert(updated_splat != null, "Updated splat_map texture must exist")
	var u_img := updated_splat.get_image()
	# (-9.0, 0.0) is 1.0m outside rx=8.0 bunker inside [-20..20] -> u=11/40=0.275, v=0.5
	var out_px := u_img.get_pixel(int(round(0.275 * 255.0)), int(round(0.5 * 255.0)))
	assert(out_px.b < 0.01 and out_px.g > 0.90,
		"Legacy 3m outer sand bleed at (-9,0) must be cleared (b=%.3f) and fairway restored (g=%.3f)" % [out_px.b, out_px.g])
	var in_px := u_img.get_pixel(128, 128)
	assert(in_px.b > 0.95 and in_px.r < 0.01 and in_px.g < 0.01,
		"Inside bunker at (0,0) must stay pure sand (rgb=%s)" % str(in_px))
	print("  PASS: Legacy splat_map 3m outer sand halo cleared and fairway weight restored cleanly.")

	# 8. Validate sharp convex ridge crest midpoint clearance (zero diagonal green slits)
	var ridge_scene := _build_sharp_ridge_cartpath_scene()
	root.add_child(ridge_scene)
	CourseDetailEnhancer.enhance_course_scene(ridge_scene, true, {"force_rebuild": true})
	var ridge_info: Dictionary = CourseDetailEnhancer._build_terrain_height_lookup(ridge_scene)
	var ridge_cp := ridge_scene.get_node("CartPaths") as MeshInstance3D
	var r_verts: PackedVector3Array = ridge_cp.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cols := 5
	var num_rows := r_verts.size() / cols
	for seg in range(num_rows - 1):
		var ra := seg * cols
		var rb := (seg + 1) * cols
		for c in range(cols - 1):
			for pair in [[ra + c, rb + c], [ra + c + 1, rb + c + 1], [ra + c, ra + c + 1], [ra + c, rb + c + 1], [ra + c + 1, rb + c]]:
				var va := r_verts[pair[0]]
				var vb := r_verts[pair[1]]
				var mid := (va + vb) * 0.5
				var clear := mid.y - CourseDetailEnhancer._sample_height(mid.x, mid.z, ridge_info)
				assert(clear >= 0.012,
					"Cart path midpoint across +/-50%% ridge at (%.2f, %.2f) clipped terrain (clear=%.4f)" % [mid.x, mid.z, clear])
	print("  PASS: Sharp +/-50%% convex ridge cart path maintains >= 0.012m clearance on every edge/diagonal midpoint.")

	# 9. Validate disconnected bridge-to-cartpath abutment stitching on upgrade
	var br_scene := _build_disconnected_bridge_scene()
	root.add_child(br_scene)
	CourseDetailEnhancer.enhance_course_scene(br_scene, true, {"force_rebuild": true})
	var stitched_cp := br_scene.get_node("cartpath_0") as MeshInstance3D
	var st_verts: PackedVector3Array = stitched_cp.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_x := -999.0
	for v in st_verts:
		max_x = maxf(max_x, v.x)
	assert(max_x >= -4.65,
		"Upgrade must stitch cartpath_0 across 1.4m shoreline gap into x=-5.0 bridge abutment + tuck (got max_x=%.2f)" % max_x)
	print("  PASS: Disconnected cartpath_0 stitched seamlessly across 1.4m gap and tucked under bridge abutment (max_x=%.2f)." % max_x)

	br_scene.queue_free()
	ridge_scene.queue_free()
	splat_scene.queue_free()

	print("\n=======================================================")
	print("ALL BUNKER & CART PATH GROUND CONFORMING TESTS PASSED!")
	print("=======================================================\n")
	quit(0)
	return false


func _build_legacy_bleed_splat_bunker_scene() -> Node3D:
	var root_node := _build_legacy_flat_bunker_scene()
	var terrain := root_node.get_node("UnifiedTerrain") as MeshInstance3D
	var b_poly := (root_node.get_node("bunker_Static_0") as StaticBody3D).get_meta("boundary_polygon") as PackedVector2Array

	# Full fairway exclusion covering the entire [-20..20] terrain
	var fw_body := StaticBody3D.new()
	fw_body.name = "fairway_Static_0"
	fw_body.set_meta("surface_type", 0)
	fw_body.set_meta("boundary_polygon", PackedVector2Array([
		Vector2(-20.0, -20.0), Vector2(20.0, -20.0), Vector2(20.0, 20.0), Vector2(-20.0, 20.0)
	]))
	root_node.add_child(fw_body)
	fw_body.owner = root_node

	# Legacy 256x256 splat image with 3.0m outer sand halo
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for py in range(256):
		var wz := -20.0 + (float(py) / 255.0) * 40.0
		for px in range(256):
			var wx := -20.0 + (float(px) / 255.0) * 40.0
			var p2 := Vector2(wx, wz)
			var bw := 0.0
			if Geometry2D.is_point_in_polygon(p2, b_poly):
				bw = 1.0
			else:
				var d := CourseDetailEnhancer._edge_distance_to_polygon_2d(p2, b_poly)
				if d < 3.0:
					bw = CourseDetailEnhancer._quintic_smoothstep(1.0 - d / 3.0)
			var gw := 1.0 - bw
			img.set_pixel(px, py, Color(0.0, gw, bw, 0.0))

	var sm := ShaderMaterial.new()
	sm.shader = load("res://Courses/Environments/shaders/terrain_splat.gdshader") as Shader
	sm.set_shader_parameter("splat_map", ImageTexture.create_from_image(img))
	terrain.mesh.surface_set_material(0, sm)
	return root_node


func _build_sharp_ridge_cartpath_scene() -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "SharpRidgeCourse"
	var cols := 21
	var rows := 21
	var min_c := -20.0
	var step := 2.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in range(rows):
		for c in range(cols):
			var wx := min_c + float(c) * step
			var wz := min_c + float(r) * step
			# Sharp tent ridge peaking cleanly along wx = 0 with +/-50% slopes
			var wy := maxf(0.0, 3.0 - 0.50 * absf(wx))
			verts.append(Vector3(wx, wy, wz))
			norms.append(Vector3.UP)
	for r in range(rows - 1):
		for c in range(cols - 1):
			var r1 := r * cols
			var r2 := (r + 1) * cols
			indices.append(r1 + c); indices.append(r1 + c + 1); indices.append(r2 + c)
			indices.append(r1 + c + 1); indices.append(r2 + c + 1); indices.append(r2 + c)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var terrain := MeshInstance3D.new()
	terrain.name = "UnifiedTerrain"
	terrain.mesh = am
	root_node.add_child(terrain)
	terrain.owner = root_node

	root_node.set_meta("cart_path_polylines", [PackedVector2Array([Vector2(-10.0, -3.0), Vector2(10.0, 3.0)])])
	root_node.set_meta("generate_3d_bunkers", false)
	root_node.set_meta("generate_cart_paths", true)
	root_node.set_meta("generate_water_long_grass", false)
	root_node.set_meta("generate_bushes", false)
	return root_node


func _build_disconnected_bridge_scene() -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "DisconnectedBridgeCourse"
	var cols := 21
	var rows := 21
	var min_c := -20.0
	var step := 2.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in range(rows):
		for c in range(cols):
			verts.append(Vector3(min_c + float(c) * step, 0.0, min_c + float(r) * step))
			norms.append(Vector3.UP)
	for r in range(rows - 1):
		for c in range(cols - 1):
			var r1 := r * cols; var r2 := (r + 1) * cols
			indices.append(r1 + c); indices.append(r1 + c + 1); indices.append(r2 + c)
			indices.append(r1 + c + 1); indices.append(r2 + c + 1); indices.append(r2 + c)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var terrain := MeshInstance3D.new()
	terrain.name = "UnifiedTerrain"
	terrain.mesh = am
	root_node.add_child(terrain)
	terrain.owner = root_node

	# Legacy cartpath_0 stopping 1.4m short of bridge start abutment (x = -6.4 vs bridge x = -5.0)
	var cp_verts := PackedVector3Array([
		Vector3(-14.0, 0.02, -1.25), Vector3(-14.0, 0.02, 1.25),
		Vector3(-10.0, 0.02, -1.25), Vector3(-10.0, 0.02, 1.25),
		Vector3(-6.4, 0.02, -1.25), Vector3(-6.4, 0.02, 1.25),
	])
	var cp_uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2), Vector2(1, 2)
	])
	var cp_idx := PackedInt32Array([0, 2, 1, 1, 2, 3, 2, 4, 3, 3, 4, 5])
	var cp_arr := []; cp_arr.resize(Mesh.ARRAY_MAX)
	cp_arr[Mesh.ARRAY_VERTEX] = cp_verts; cp_arr[Mesh.ARRAY_TEX_UV] = cp_uvs; cp_arr[Mesh.ARRAY_INDEX] = cp_idx
	var cp_mesh := ArrayMesh.new()
	cp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cp_arr)
	var cp := MeshInstance3D.new()
	cp.name = "cartpath_0"
	cp.mesh = cp_mesh
	root_node.add_child(cp)
	cp.owner = root_node

	var cp_body := StaticBody3D.new()
	cp_body.name = "cartpath_Static_0"
	var cp_cs := CollisionShape3D.new()
	cp_body.add_child(cp_cs)
	root_node.add_child(cp_body)
	cp_body.owner = root_node
	cp_cs.owner = root_node

	# Legacy cartbridge_Static_0_1 matching OsmMapLoader ConcavePolygonShape3D [aL, bL, aR, aR, bL, bR]
	var b_sb := StaticBody3D.new()
	b_sb.name = "cartbridge_Static_0_1"
	var b_cs := CollisionShape3D.new()
	var col_shape := ConcavePolygonShape3D.new()
	var aL := Vector3(-5.0, 0.0, -1.25)
	var aR := Vector3(-5.0, 0.0, 1.25)
	var mL := Vector3(0.0, 0.5, -1.25)
	var mR := Vector3(0.0, 0.5, 1.25)
	var bL := Vector3(5.0, 0.0, -1.25)
	var bR := Vector3(5.0, 0.0, 1.25)
	col_shape.set_faces(PackedVector3Array([
		aL, mL, aR, aR, mL, mR,
		mL, bL, mR, mR, bL, bR
	]))
	b_cs.shape = col_shape
	b_sb.add_child(b_cs)
	root_node.add_child(b_sb)
	b_sb.owner = root_node
	b_cs.owner = root_node

	root_node.set_meta("generate_3d_bunkers", false)
	root_node.set_meta("generate_cart_paths", true)
	root_node.set_meta("generate_water_long_grass", false)
	root_node.set_meta("generate_bushes", false)
	return root_node


func _build_legacy_flat_bunker_scene() -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "LegacyFlatBunkerCourse"
	var cols := 21
	var rows := 21
	var min_c := -20.0
	var step := 2.0
	var b_poly := PackedVector2Array()
	for i in range(16):
		var ang := float(i) * TAU / 16.0
		b_poly.append(Vector2(cos(ang) * 8.0, sin(ang) * 5.5))

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in range(rows):
		for c in range(cols):
			var wx := min_c + float(c) * step
			var wz := min_c + float(r) * step
			var wy := 0.0
			var p2 := Vector2(wx, wz)
			if Geometry2D.is_point_in_polygon(p2, b_poly):
				var d := CourseDetailEnhancer._edge_distance_to_polygon_2d(p2, b_poly)
				wy = -CourseDetailEnhancer._quintic_smoothstep(clampf(d / 7.0, 0.0, 1.0)) * 1.0
			verts.append(Vector3(wx, wy, wz))
			norms.append(Vector3.UP)
	for r in range(rows - 1):
		for c in range(cols - 1):
			var r1 := r * cols
			var r2 := (r + 1) * cols
			indices.append(r1 + c)
			indices.append(r1 + c + 1)
			indices.append(r2 + c)
			indices.append(r1 + c + 1)
			indices.append(r2 + c + 1)
			indices.append(r2 + c)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var terrain := MeshInstance3D.new()
	terrain.name = "UnifiedTerrain"
	terrain.mesh = am
	root_node.add_child(terrain)
	terrain.owner = root_node

	var b_body := StaticBody3D.new()
	b_body.name = "bunker_Static_0"
	b_body.set_meta("surface_type", 5)
	b_body.set_meta("is_sand", true)
	b_body.set_meta("boundary_polygon", b_poly)
	root_node.add_child(b_body)
	b_body.owner = root_node

	root_node.set_meta("generate_3d_bunkers", true)
	root_node.set_meta("generate_cart_paths", false)
	root_node.set_meta("generate_water_long_grass", false)
	root_node.set_meta("generate_bushes", false)
	return root_node


func _get_kidney_bunker_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-10.0, -5.0),
		Vector2(-6.0, -7.5),
		Vector2(-1.5, -4.5),
		Vector2(-1.2, -4.3), # Near-duplicate point
		Vector2(2.0, -3.0),
		Vector2(6.5, -6.5),
		Vector2(10.0, -4.0),
		Vector2(10.5, 0.5),
		Vector2(7.0, 4.5),
		Vector2(2.0, 2.0),   # Sharp concave kidney waist
		Vector2(1.8, 3.2),   # Sharp pinch/spike
		Vector2(-3.0, 4.0),
		Vector2(-8.0, 3.5),
		Vector2(-11.0, -0.5)
	])


func _build_undulating_test_scene() -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "TestConformingCourse"

	# Build a 21x21 regular grid terrain [-20..20] with a sharp saddle cell at [0..2, 0..2]
	# plus an undulating ridge along X and slope in Z.
	var cols := 21
	var rows := 21
	var min_c := -20.0
	var step := 2.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()

	for r in range(rows):
		for c in range(cols):
			var wx := min_c + float(c) * step
			var wz := min_c + float(r) * step
			var wy := 0.12 * wx + 0.65 * sin(wx * 0.28) * cos(wz * 0.25) + 0.9 * exp(-pow((wx - 1.0) / 3.5, 2.0))
			# Force an explicit saddle in cell (c=10..11, r=10..11) -> [0..2, 0..2]
			if c == 10 and r == 10:
				wy = 0.0
			elif c == 11 and r == 10:
				wy = 2.0
			elif c == 10 and r == 11:
				wy = 2.0
			elif c == 11 and r == 11:
				wy = 0.0
			verts.append(Vector3(wx, wy, wz))
			norms.append(Vector3.UP)

	for r in range(rows - 1):
		for c in range(cols - 1):
			var r1 := r * cols
			var r2 := (r + 1) * cols
			indices.append(r1 + c)
			indices.append(r1 + c + 1)
			indices.append(r2 + c)
			indices.append(r1 + c + 1)
			indices.append(r2 + c + 1)
			indices.append(r2 + c)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var t_mesh := ArrayMesh.new()
	t_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var terrain := MeshInstance3D.new()
	terrain.name = "UnifiedTerrain"
	terrain.mesh = t_mesh
	root_node.add_child(terrain)
	terrain.owner = root_node

	# Bunker StaticBody3D with concave kidney polygon
	var bunker_body := StaticBody3D.new()
	bunker_body.name = "bunker_Static_0"
	bunker_body.set_meta("surface_type", 5)
	bunker_body.set_meta("is_sand", true)
	bunker_body.set_meta("boundary_polygon", _get_kidney_bunker_polygon())
	root_node.add_child(bunker_body)
	bunker_body.owner = root_node

	# Cart path polyline crossing the undulating ridge
	var path_pts := PackedVector2Array([
		Vector2(-16.0, 10.0),
		Vector2(-6.0, 11.5),
		Vector2(1.0, 10.0),
		Vector2(9.0, 8.5),
		Vector2(16.0, 11.0)
	])
	root_node.set_meta("cart_path_polylines", [path_pts])
	root_node.set_meta("generate_3d_bunkers", true)
	root_node.set_meta("generate_cart_paths", true)
	root_node.set_meta("generate_water_long_grass", false)
	root_node.set_meta("generate_bushes", false)
	return root_node


func _build_legacy_2col_cartpath_scene(t_mesh: Mesh) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "LegacyCartPathCourse"
	var terrain := MeshInstance3D.new()
	terrain.name = "UnifiedTerrain"
	terrain.mesh = t_mesh
	root_node.add_child(terrain)
	terrain.owner = root_node

	# Build a 2-column coarse cartpath_0 mesh matching legacy OsmMapLoader output
	var verts := PackedVector3Array([
		Vector3(-12.0, 0.0, 11.25), Vector3(-12.0, 0.0, 8.75),
		Vector3(0.0, 0.0, 11.25), Vector3(0.0, 0.0, 8.75),
		Vector3(12.0, 0.0, 11.25), Vector3(12.0, 0.0, 8.75),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(0.0, 3.0), Vector2(1.0, 3.0),
		Vector2(0.0, 6.0), Vector2(1.0, 6.0),
	])
	var indices := PackedInt32Array([0, 2, 1, 1, 2, 3, 2, 4, 3, 3, 4, 5])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var cp := MeshInstance3D.new()
	cp.name = "cartpath_0"
	cp.mesh = am
	root_node.add_child(cp)
	cp.owner = root_node

	var cp_body := StaticBody3D.new()
	cp_body.name = "cartpath_Static_0"
	cp_body.set_meta("is_cart_path", true)
	var cs := CollisionShape3D.new()
	cp_body.add_child(cs)
	root_node.add_child(cp_body)
	cp_body.owner = root_node
	cs.owner = root_node

	root_node.set_meta("generate_3d_bunkers", false)
	root_node.set_meta("generate_cart_paths", true)
	root_node.set_meta("generate_water_long_grass", false)
	root_node.set_meta("generate_bushes", false)
	return root_node


func _exact_mesh_height_at(mesh: Mesh, wx: float, wz: float) -> float:
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		var p2 := Vector2(wx, wz)
		var v0 := b2 - a2
		var v1 := c2 - a2
		var v2 := p2 - a2
		var d00 := v0.dot(v0)
		var d01 := v0.dot(v1)
		var d11 := v1.dot(v1)
		var d20 := v2.dot(v0)
		var d21 := v2.dot(v1)
		var denom := d00 * d11 - d01 * d01
		if absf(denom) < 1e-8:
			continue
		var v := (d11 * d20 - d01 * d21) / denom
		var w := (d00 * d21 - d01 * d20) / denom
		var u := 1.0 - v - w
		if u >= -0.0001 and v >= -0.0001 and w >= -0.0001:
			return u * a.y + v * b.y + w * c.y
	return NAN
