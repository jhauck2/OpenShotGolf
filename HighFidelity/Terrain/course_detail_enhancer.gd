extends RefCounted
class_name CourseDetailEnhancer

## CourseDetailEnhancer
## Builds high-resolution 3D course detail features for both newly generated courses,
## in-place upgraded courses (CourseGraphicsUpgrader), and HighFidelityBuilder:
## 1. Recessed 3D Bunker Lip & Sand Bowl Meshes (`HighFidelityBunkers`)
## 2. Overhanging 3D Bunker-Lip Fescue Grass (`BunkerLipGrassMultiMesh`)
## 3. Pond Shoreline Reeds (`ShorelineReedsMultiMesh`)
## 4. Outer Rolling Terrain Horizon Skirt (`HorizonSkirt`)

const ProceduralTreeGeneratorScript = preload("res://HighFidelity/Foliage/procedural_tree_generator.gd")
const HighFidelityGrassScript = preload("res://HighFidelity/Foliage/high_fidelity_grass.gd")


static func enhance_course_scene(scene_root: Node, persist_for_save: bool = false, options: Dictionary = {}) -> Dictionary:
	var result := {
		"bunkers_built": 0,
		"shoreline_reeds": 0,
		"horizon_skirt": false,
		"cart_paths": false,
		"thick_rough_grass": 0,
		"thick_rough_bushes": 0
	}
	if scene_root == null or MobilePerformance.is_driving_range_node(scene_root):
		return result

	var force_rebuild: bool = bool(options.get("force_rebuild", false))
	if force_rebuild:
		_strip_legacy_grass_nodes(scene_root)
	var height_map := _build_terrain_height_lookup(scene_root)
	if scene_root.has_meta("terrain_height_lookup"):
		scene_root.remove_meta("terrain_height_lookup")

	var gen_bunkers := true
	if options.has("generate_3d_bunkers"):
		gen_bunkers = bool(options["generate_3d_bunkers"])
	elif scene_root.has_meta("generate_3d_bunkers"):
		gen_bunkers = bool(scene_root.get_meta("generate_3d_bunkers"))
	elif FileAccess.file_exists("user://osm_download_settings.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://osm_download_settings.cfg") == OK:
			gen_bunkers = bool(cfg.get_value("course_generation", "generate_3d_bunkers", true))

	if gen_bunkers:
		result["bunkers_built"] = _build_recessed_3d_bunkers(scene_root, height_map, persist_for_save, force_rebuild)
	else:
		result["bunkers_built"] = 0

	var gen_reeds := true
	if options.has("generate_water_long_grass"):
		gen_reeds = bool(options["generate_water_long_grass"])
	elif scene_root.has_meta("generate_water_long_grass"):
		gen_reeds = bool(scene_root.get_meta("generate_water_long_grass"))
	elif FileAccess.file_exists("user://osm_download_settings.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://osm_download_settings.cfg") == OK:
			gen_reeds = bool(cfg.get_value("course_generation", "generate_water_long_grass", true))

	if gen_reeds:
		result["shoreline_reeds"] = _build_shoreline_reeds(scene_root, height_map, persist_for_save, force_rebuild)
	else:
		result["shoreline_reeds"] = 0

	result["horizon_skirt"] = _build_horizon_skirt(scene_root, height_map, persist_for_save)

	var gen_cart_paths := true
	if options.has("generate_cart_paths"):
		gen_cart_paths = bool(options["generate_cart_paths"])
	elif scene_root.has_meta("generate_cart_paths"):
		gen_cart_paths = bool(scene_root.get_meta("generate_cart_paths"))
	elif FileAccess.file_exists("user://osm_download_settings.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://osm_download_settings.cfg") == OK:
			gen_cart_paths = bool(cfg.get_value("course_generation", "generate_cart_paths", true))

	if gen_cart_paths:
		result["cart_paths"] = _build_cart_paths(scene_root, height_map, persist_for_save, force_rebuild)
	else:
		result["cart_paths"] = false

	result["thick_rough_grass"] = 0

	var gen_bushes := true
	if options.has("generate_bushes"):
		gen_bushes = bool(options["generate_bushes"])
	elif scene_root.has_meta("generate_bushes"):
		gen_bushes = bool(scene_root.get_meta("generate_bushes"))
	elif FileAccess.file_exists("user://osm_download_settings.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://osm_download_settings.cfg") == OK:
			gen_bushes = bool(cfg.get_value("course_generation", "generate_bushes", true))

	if gen_bushes:
		result["thick_rough_bushes"] = _build_thick_rough_bushes(scene_root, height_map, persist_for_save)
	else:
		result["thick_rough_bushes"] = 0

	ensure_deep_rough_map(scene_root)
	_upgrade_water_materials(scene_root)
	if persist_for_save:
		scene_root.set_meta("course_details_baked", true)
		scene_root.set_meta("course_details_version", 23)
	return result


static func _strip_legacy_grass_nodes(scene_root: Node) -> void:
	var to_remove: Array[Node] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == "MultiMeshFoliageContainer":
			continue
		for c in n.get_children():
			var cn := String(c.name)
			if cn == "BunkerLipGrassMultiMesh" or cn == "ShorelineReedsMultiMesh" \
					or cn == "HighFidelityBunkers" \
					or cn == "ThickRoughGrassMultiMesh" \
					or cn == "ThickRoughBushes" \
					or cn == "CartPaths" \
					or cn.begins_with("ThickRough_") \
					or cn.begins_with("BushChunk_") or cn.begins_with("Bush_") \
					or cn.begins_with("RockChunk_") or cn.begins_with("Rock_"):
				to_remove.append(c)
			else:
				stack.append(c)
	for r in to_remove:
		r.get_parent().remove_child(r)
		if r.is_inside_tree():
			r.queue_free()
		else:
			r.free()


static func _find_terrain_mesh_instance(scene_root: Node) -> MeshInstance3D:
	if scene_root == null:
		return null
	var terrain: MeshInstance3D = null
	for tname in ["UnifiedTerrain", "DynamicGround", "RoughGround", "Terrain", "TerrainMesh"]:
		terrain = scene_root.find_child(tname, true, false) as MeshInstance3D
		if terrain != null and terrain.mesh != null and terrain.mesh.get_surface_count() > 0:
			return terrain
	for child in scene_root.find_children("*", "MeshInstance3D", true, false):
		var cn := child.name.to_lower()
		if (cn.contains("terrain") or cn.contains("ground")) and not cn.contains("preview"):
			var mi := child as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				return mi
	return null


static func _build_terrain_height_lookup(scene_root: Node) -> Dictionary:
	var info := {
		"min_x": -300.0,
		"max_x": 300.0,
		"min_z": -300.0,
		"max_z": 300.0,
		"avg_edge_y": 0.0,
		"grid": {}
	}
	var terrain := _find_terrain_mesh_instance(scene_root)
	if terrain == null or terrain.mesh == null or terrain.mesh.get_surface_count() == 0:
		return info

	var aabb := terrain.mesh.get_aabb()
	var t_xform := terrain.global_transform if terrain.is_inside_tree() else terrain.transform
	var t_pos := t_xform.origin
	info["min_x"] = t_pos.x + aabb.position.x
	info["max_x"] = t_pos.x + aabb.position.x + aabb.size.x
	info["min_z"] = t_pos.z + aabb.position.z
	info["max_z"] = t_pos.z + aabb.position.z + aabb.size.z

	var arrays := terrain.mesh.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_VERTEX:
		return info
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return info

	var num_verts := verts.size()
	# Check if vertices form a regular row-major grid (as generated by OsmMapLoader or PlaneMesh)
	var z0 := verts[0].z
	var cols := 0
	for i in range(1, num_verts):
		if absf(verts[i].z - z0) > 0.001:
			cols = i
			break

	if cols >= 2 and (num_verts % cols) == 0:
		var rows := num_verts / cols
		var h_array := PackedFloat32Array()
		h_array.resize(num_verts)
		var min_vx := INF
		var max_vx := -INF
		var min_vz := INF
		var max_vz := -INF
		var edge_sum := 0.0
		var edge_cnt := 0

		for i in range(num_verts):
			var wv := t_xform * verts[i]
			h_array[i] = wv.y
			if wv.x < min_vx: min_vx = wv.x
			if wv.x > max_vx: max_vx = wv.x
			if wv.z < min_vz: min_vz = wv.z
			if wv.z > max_vz: max_vz = wv.z

			var r := i / cols
			var c := i % cols
			if r == 0 or r == rows - 1 or c == 0 or c == cols - 1:
				edge_sum += wv.y
				edge_cnt += 1

		var diag_ur_dl := true
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.size() >= 3:
				var i0 := indices[0]
				var i1 := indices[1]
				var i2 := indices[2]
				var has_0 := (i0 == 0 or i1 == 0 or i2 == 0)
				var has_diag := (i0 == cols + 1 or i1 == cols + 1 or i2 == cols + 1)
				if has_0 and has_diag:
					diag_ur_dl = false

		info["is_regular_grid"] = true
		info["diag_ur_dl"] = diag_ur_dl
		info["cols"] = cols
		info["rows"] = rows
		info["grid_min_x"] = min_vx
		info["grid_max_x"] = max_vx
		info["grid_min_z"] = min_vz
		info["grid_max_z"] = max_vz
		info["min_x"] = min_vx
		info["max_x"] = max_vx
		info["min_z"] = min_vz
		info["max_z"] = max_vz
		info["height_array"] = h_array
		if edge_cnt > 0:
			info["avg_edge_y"] = edge_sum / float(edge_cnt)
		return info

	var grid: Dictionary = {}
	var edge_sum := 0.0
	var edge_cnt := 0
	var cell := 2.0

	for v in verts:
		var wv := t_xform * v
		var vx := wv.x
		var vy := wv.y
		var vz := wv.z
		var gx := int(floor(vx / cell))
		var gz := int(floor(vz / cell))
		grid[Vector2i(gx, gz)] = vy
		if absf(vx - info["min_x"]) < 8.0 or absf(vx - info["max_x"]) < 8.0 or absf(vz - info["min_z"]) < 8.0 or absf(vz - info["max_z"]) < 8.0:
			edge_sum += vy
			edge_cnt += 1

	if edge_cnt > 0:
		info["avg_edge_y"] = edge_sum / float(edge_cnt)
	info["cell_size"] = cell
	info["grid"] = grid
	return info


static func _sample_height(wx: float, wz: float, info: Dictionary, fallback_y: float = 0.0) -> float:
	if info.get("is_regular_grid", false):
		var cols: int = info.get("cols", 0)
		var rows: int = info.get("rows", 0)
		var g_min_x: float = info.get("grid_min_x", 0.0)
		var g_max_x: float = info.get("grid_max_x", 1.0)
		var g_min_z: float = info.get("grid_min_z", 0.0)
		var g_max_z: float = info.get("grid_max_z", 1.0)
		var span_x := g_max_x - g_min_x
		var span_z := g_max_z - g_min_z
		if cols >= 2 and rows >= 2 and span_x > 0.001 and span_z > 0.001:
			var u := clampf((wx - g_min_x) / span_x, 0.0, 1.0) * float(cols - 1)
			var v := clampf((wz - g_min_z) / span_z, 0.0, 1.0) * float(rows - 1)
			var c0 := mini(int(floor(u)), cols - 2)
			var r0 := mini(int(floor(v)), rows - 2)
			var tc := u - float(c0)
			var tr := v - float(r0)
			var h_arr: PackedFloat32Array = info.get("height_array", PackedFloat32Array())
			if h_arr.size() == cols * rows:
				var h00 := h_arr[r0 * cols + c0]
				var h10 := h_arr[r0 * cols + c0 + 1]
				var h01 := h_arr[(r0 + 1) * cols + c0]
				var h11 := h_arr[(r0 + 1) * cols + c0 + 1]
				if bool(info.get("diag_ur_dl", true)):
					if tc + tr <= 1.0:
						return h00 + tc * (h10 - h00) + tr * (h01 - h00)
					return h11 + (1.0 - tc) * (h01 - h11) + (1.0 - tr) * (h10 - h11)
				if tc >= tr:
					return h00 + tc * (h10 - h00) + tr * (h11 - h10)
				return h00 + tr * (h01 - h00) + tc * (h11 - h01)

	var grid: Dictionary = info.get("grid", {})
	if grid.is_empty():
		return fallback_y
	var cell: float = float(info.get("cell_size", 4.0))
	var fx := wx / cell
	var fz := wz / cell
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	var tx := fx - float(ix)
	var tz := fz - float(iz)

	var k00 := Vector2i(ix, iz)
	var h00: float = grid.get(k00, NAN)
	if is_nan(h00):
		for r in range(1, 6):
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					var k := Vector2i(ix + dx, iz + dz)
					if grid.has(k):
						return float(grid[k])
		return fallback_y

	var h10: float = grid.get(Vector2i(ix + 1, iz), h00)
	var h01: float = grid.get(Vector2i(ix, iz + 1), h00)
	var h11: float = grid.get(Vector2i(ix + 1, iz + 1), h00)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


static func _sample_normal(wx: float, wz: float, info: Dictionary) -> Vector3:
	var eps := 0.5
	var center := _sample_height(wx, wz, info, 0.0)
	var h_l := _sample_height(wx - eps, wz, info, center)
	var h_r := _sample_height(wx + eps, wz, info, center)
	var h_d := _sample_height(wx, wz - eps, info, center)
	var h_u := _sample_height(wx, wz + eps, info, center)
	return Vector3(h_l - h_r, 2.0 * eps, h_d - h_u).normalized()


static func _build_recessed_3d_bunkers(scene_root: Node, height_info: Dictionary, persist_for_save: bool, force_rebuild: bool = false) -> int:
	var existing_bunkers = scene_root.get_node_or_null("HighFidelityBunkers")
	if existing_bunkers != null and not force_rebuild and existing_bunkers.get_child_count() > 0:
		return existing_bunkers.get_child_count()
	if existing_bunkers != null:
		if existing_bunkers.is_inside_tree():
			existing_bunkers.queue_free()
		else:
			existing_bunkers.free()

	var polygons: Array[PackedVector2Array] = []
	var base_heights: Array[float] = []

	for child in scene_root.find_children("*", "CollisionObject3D", true, false):
		var cname := child.name.to_lower()
		var is_bunker: bool = (cname.begins_with("bunker") or cname.contains("bunker") or bool(child.get_meta("is_sand", false)) or int(child.get_meta("surface_type", -1)) == 5) and not bool(child.get_meta("is_water", false)) and not cname.contains("terrain") and not cname.contains("rough")
		if is_bunker:
			# 1. Prefer explicit boundary polygon preserved in metadata (from course generator)
			if child.has_meta("boundary_polygon"):
				var poly_meta = child.get_meta("boundary_polygon")
				var boundary_pts := PackedVector2Array()
				if poly_meta is PackedVector2Array:
					boundary_pts = poly_meta
				elif poly_meta is Array:
					for p in poly_meta:
						if p is Vector2:
							boundary_pts.append(p)
				if boundary_pts.size() >= 3:
					var world_poly := PackedVector2Array()
					var child_xform: Transform3D = (child as Node3D).transform
					for pt in boundary_pts:
						var wp := child_xform * Vector3(pt.x, 0.0, pt.y)
						world_poly.append(Vector2(wp.x, wp.z))
					polygons.append(world_poly)
					base_heights.append((child as Node3D).position.y)
					continue

			# 2. Inspect collision shapes without convex hull distortion
			for sub in child.get_children():
				if sub is CollisionPolygon3D and (sub as CollisionPolygon3D).polygon.size() >= 3:
					var cp := sub as CollisionPolygon3D
					var world_poly := PackedVector2Array()
					for pt in cp.polygon:
						var wp := (child as Node3D).transform * (cp.transform * Vector3(pt.x, 0.0, pt.y))
						world_poly.append(Vector2(wp.x, wp.z))
					polygons.append(world_poly)
					base_heights.append((child as Node3D).position.y)
				elif sub is CollisionShape3D and (sub as CollisionShape3D).shape != null:
					var cs := sub as CollisionShape3D
					if cs.shape is ConcavePolygonShape3D:
						var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
						var boundary := _extract_boundary_polygon_from_faces(faces, (child as Node3D).transform * cs.transform)
						if boundary.size() >= 3:
							polygons.append(boundary)
							base_heights.append((child as Node3D).position.y)
						else:
							# Fallback if boundary extraction could not trace a valid loop
							var world_pts := PackedVector2Array()
							for f in faces:
								var wp := (child as Node3D).transform * (cs.transform * f)
								world_pts.append(Vector2(wp.x, wp.z))
							if world_pts.size() >= 3:
								var hull := Geometry2D.convex_hull(world_pts)
								if hull.size() > 3 and hull[hull.size() - 1].is_equal_approx(hull[0]):
									hull.remove_at(hull.size() - 1)
								if hull.size() >= 3:
									polygons.append(hull)
									base_heights.append((child as Node3D).position.y)
					elif cs.shape is ConvexPolygonShape3D:
						var points := (cs.shape as ConvexPolygonShape3D).points
						var world_pts := PackedVector2Array()
						for p in points:
							var wp := (child as Node3D).transform * (cs.transform * p)
							world_pts.append(Vector2(wp.x, wp.z))
						if world_pts.size() >= 3:
							var hull := Geometry2D.convex_hull(world_pts)
							if hull.size() > 3 and hull[hull.size() - 1].is_equal_approx(hull[0]):
								hull.remove_at(hull.size() - 1)
							if hull.size() >= 3:
								polygons.append(hull)
								base_heights.append((child as Node3D).position.y)

	var had_mapped_bunkers := not polygons.is_empty()
	if polygons.is_empty():
		# If the course scene has no bunker static bodies mapped, synthesize realistic greenside
		# sand traps around each green so greens are authentically defended.
		var green_bodies: Array = []
		for child in scene_root.find_children("*", "CollisionObject3D", true, false):
			var cname := child.name.to_lower()
			if (cname.begins_with("green") or int(child.get_meta("surface_type", -1)) == 4) and not cname.contains("terrain"):
				green_bodies.append(child)

		if not green_bodies.is_empty():
			var features: Dictionary = _extract_course_features(scene_root)
			var g_idx := 0
			for g_body in green_bodies:
				var g_node := g_body as Node3D
				var g_poly := PackedVector2Array()
				if g_body.has_meta("boundary_polygon"):
					var bp = g_body.get_meta("boundary_polygon")
					if bp is PackedVector2Array:
						g_poly = bp
					elif bp is Array:
						for p in bp:
							if p is Vector2:
								g_poly.append(p)

				if g_poly.size() < 3:
					for sub in g_body.get_children():
						if sub is CollisionPolygon3D and (sub as CollisionPolygon3D).polygon.size() >= 3:
							var cp := sub as CollisionPolygon3D
							for pt in cp.polygon:
								var wp := g_node.transform * (cp.transform * Vector3(pt.x, 0.0, pt.y))
								g_poly.append(Vector2(wp.x, wp.z))
							break
						elif sub is CollisionShape3D and (sub as CollisionShape3D).shape != null:
							var cs := sub as CollisionShape3D
							if cs.shape is ConcavePolygonShape3D:
								var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
								g_poly = _extract_boundary_polygon_from_faces(faces, g_node.transform * cs.transform)
								if g_poly.size() >= 3:
									break

				var g_center := Vector2.ZERO
				if g_poly.size() >= 3:
					for pt in g_poly:
						g_center += pt
					g_center /= float(g_poly.size())
				elif g_node.position != Vector3.ZERO:
					g_center = Vector2(g_node.position.x, g_node.position.z)
				else:
					continue

				var max_r := 0.0
				for pt in g_poly:
					var d: float = g_center.distance_to(pt)
					if d > max_r and d < 40.0:
						max_r = d
				var g_radius := max_r if max_r > 6.0 else 14.0
				var g_height := _sample_height(g_center.x, g_center.y, height_info, g_node.position.y)

				# Generate primary greenside bunker, searching for a clear angle away from hazards
				var base_angle1: float = float(g_idx) * 1.35 + 0.6
				var dist1: float = g_radius + 4.5
				var b1_placed := false
				for attempt in range(4):
					var angle1: float = base_angle1 + float(attempt) * 0.85
					var b1_center := Vector2(g_center.x + cos(angle1) * dist1, g_center.y + sin(angle1) * dist1)
					var b1_poly := _create_synthetic_bunker_polygon(b1_center, 13.0, 7.0, angle1 + 0.5, g_idx * 17 + attempt * 7)
					if b1_poly.size() >= 3 and _is_synthetic_bunker_clear(b1_poly, b1_center, g_poly, features, polygons):
						polygons.append(b1_poly)
						base_heights.append(g_height)
						b1_placed = true
						break

				# Secondary greenside bunker on ~65% of greens if space permits
				if b1_placed and (g_idx % 3) != 1:
					var base_angle2: float = base_angle1 + 2.1
					var dist2: float = g_radius + 5.0
					for attempt in range(4):
						var angle2: float = base_angle2 + float(attempt) * 0.85
						var b2_center := Vector2(g_center.x + cos(angle2) * dist2, g_center.y + sin(angle2) * dist2)
						var b2_poly := _create_synthetic_bunker_polygon(b2_center, 11.5, 6.5, angle2 - 0.4, g_idx * 31 + attempt * 11 + 7)
						if b2_poly.size() >= 3 and _is_synthetic_bunker_clear(b2_poly, b2_center, g_poly, features, polygons):
							polygons.append(b2_poly)
							base_heights.append(g_height)
							break
				g_idx += 1

	if polygons.is_empty():
		return 0

	if persist_for_save and force_rebuild:
		if _sculpt_concave_bunkers_into_terrain(scene_root, polygons, had_mapped_bunkers):
			var refreshed_info := _build_terrain_height_lookup(scene_root)
			height_info.clear()
			height_info.merge(refreshed_info, true)
		_refresh_bunker_splat_and_ao_maps(scene_root, polygons, height_info)

	var container := Node3D.new()
	container.name = "HighFidelityBunkers"
	scene_root.add_child(container)
	if persist_for_save:
		container.owner = scene_root

	var bunker_mat := _create_bunker_high_material()
	var built := 0
	for idx in range(polygons.size()):
		var poly := _sanitize_and_smooth_bunker_polygon(polygons[idx], 0.65)
		if poly.size() < 4:
			continue

		var mesh := _create_single_bunker_lip_and_bowl_mesh(poly, height_info, base_heights[idx])
		if mesh == null:
			continue
		mesh.surface_set_material(0, bunker_mat)

		var mi := MeshInstance3D.new()
		mi.name = "RecessedBunker_%d" % idx
		mi.mesh = mesh
		mi.set_meta("boundary_polygon", poly)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 420.0
		mi.visibility_range_end_margin = 30.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		container.add_child(mi)
		if persist_for_save:
			mi.owner = scene_root
		if not had_mapped_bunkers:
			var sb := StaticBody3D.new()
			sb.name = "bunker_Static_synthetic_%d" % idx
			sb.set_meta("surface_type", 5)
			sb.set_meta("is_sand", true)
			sb.set_meta("boundary_polygon", poly)
			sb.add_to_group("bunkers")
			scene_root.add_child(sb)
			if persist_for_save:
				sb.owner = scene_root
		built += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mmi.name = "BunkerLipGrassMultiMesh"
	# Sand traps should be clean hazards without grass shoots or weeds
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = 0
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(mmi)
	if persist_for_save:
		mmi.owner = scene_root

	return built



static func _quintic_smoothstep(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * c * (c * (c * 6.0 - 15.0) + 10.0)


static func _sculpt_concave_bunkers_into_terrain(
	scene_root: Node,
	polygons: Array[PackedVector2Array],
	had_mapped_bunkers: bool = true
) -> bool:
	if scene_root == null or polygons.is_empty():
		return false
	var terrain := _find_terrain_mesh_instance(scene_root)
	if terrain == null or not (terrain.mesh is ArrayMesh) or terrain.mesh.get_surface_count() == 0:
		return false
	if bool(terrain.get_meta("concave_bunkers_baked", false)):
		return false

	var am := terrain.mesh as ArrayMesh
	var arrays := am.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_VERTEX:
		return false
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var num_verts := verts.size()
	if num_verts < 4:
		return false

	var z0 := verts[0].z
	var cols := 0
	for i in range(1, num_verts):
		if absf(verts[i].z - z0) > 0.001:
			cols = i
			break
	if cols < 2 or (num_verts % cols) != 0:
		return false
	var rows := num_verts / cols

	var norms := PackedVector3Array()
	if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == num_verts:
		norms = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	else:
		norms.resize(num_verts)
		norms.fill(Vector3.UP)

	var t_xform := terrain.global_transform if terrain.is_inside_tree() else terrain.transform
	var inv_xform := t_xform.affine_inverse()

	var bunker_aabbs: Array[Rect2] = []
	for poly in polygons:
		if poly.size() < 3:
			bunker_aabbs.append(Rect2())
			continue
		var min_p := poly[0]
		var max_p := poly[0]
		for pt in poly:
			min_p.x = minf(min_p.x, pt.x)
			min_p.y = minf(min_p.y, pt.y)
			max_p.x = maxf(max_p.x, pt.x)
			max_p.y = maxf(max_p.y, pt.y)
		bunker_aabbs.append(Rect2(min_p - Vector2(3.6, 3.6), (max_p - min_p) + Vector2(7.2, 7.2)))

	var features := _extract_course_features(scene_root)
	var green_tee_entries: Array = []
	green_tee_entries.append_array(features.get("greens", []))
	green_tee_entries.append_array(features.get("tees", []))

	var dirty_mask := PackedByteArray()
	dirty_mask.resize(num_verts)
	dirty_mask.fill(0)
	var any_modified := false

	for i in range(num_verts):
		var wv := t_xform * verts[i]
		var p2 := Vector2(wv.x, wv.z)

		var any_aabb := false
		for b_idx in range(polygons.size()):
			if polygons[b_idx].size() >= 3 and bunker_aabbs[b_idx].has_point(p2):
				any_aabb = true
				break
		if not any_aabb:
			continue

		var in_bunker := false
		var max_concave := 0.0
		var max_lip_factor := 0.0
		var old_dep := 0.0

		for b_idx in range(polygons.size()):
			var poly := polygons[b_idx]
			if poly.size() < 3 or not bunker_aabbs[b_idx].has_point(p2):
				continue
			var inside := Geometry2D.is_point_in_polygon(p2, poly)
			var dist := _edge_distance_to_polygon_2d(p2, poly)
			if inside:
				in_bunker = true
				var t := clampf(dist / 3.2, 0.0, 1.0)
				max_concave = maxf(max_concave, 1.0 - pow(1.0 - t, 2.2))
				if had_mapped_bunkers:
					var old_t := clampf(dist / 7.0, 0.0, 1.0)
					old_dep = maxf(old_dep, _quintic_smoothstep(old_t) * 1.0)
			elif dist < 3.5:
				max_lip_factor = maxf(max_lip_factor, 1.0 - _quintic_smoothstep(dist / 3.5))

		if not in_bunker and max_lip_factor <= 0.0:
			continue

		var gt_weight := 0.0
		for gt in green_tee_entries:
			var g_aabb: Rect2 = gt["aabb"]
			if not g_aabb.grow(6.0).has_point(p2):
				continue
			var g_poly: PackedVector2Array = gt["poly"]
			var g_in := Geometry2D.is_point_in_polygon(p2, g_poly)
			var g_dist := _edge_distance_to_polygon_2d(p2, g_poly)
			var sd := g_dist if g_in else -g_dist
			if sd >= 5.0:
				gt_weight = 1.0
				break
			elif sd > -6.0:
				gt_weight = maxf(gt_weight, _quintic_smoothstep((sd + 6.0) / 11.0))

		var lip_h := 0.28 * (1.0 - clampf(gt_weight, 0.0, 1.0))
		var new_offset := (lip_h - (lip_h + 1.05) * max_concave) if in_bunker else (lip_h * max_lip_factor)
		var old_offset := -old_dep
		var delta := new_offset - old_offset
		if absf(delta) > 1e-5:
			wv.y += delta
			verts[i] = inv_xform * wv
			any_modified = true
			var r := i / cols
			var c := i % cols
			dirty_mask[i] = 1
			if c > 0: dirty_mask[i - 1] = 1
			if c < cols - 1: dirty_mask[i + 1] = 1
			if r > 0: dirty_mask[i - cols] = 1
			if r < rows - 1: dirty_mask[i + cols] = 1

	if any_modified:
		for idx in range(num_verts):
			if dirty_mask[idx] == 0:
				continue
			var r := idx / cols
			var c := idx % cols
			var v_l := verts[r * cols + maxi(0, c - 1)]
			var v_r := verts[r * cols + mini(cols - 1, c + 1)]
			var v_d := verts[maxi(0, r - 1) * cols + c]
			var v_u := verts[mini(rows - 1, r + 1) * cols + c]
			var n := (v_u - v_d).cross(v_r - v_l)
			if n.length_squared() > 1e-8:
				norms[idx] = n.normalized()

		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		var old_mat := am.surface_get_material(0)
		var new_mesh := ArrayMesh.new()
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if old_mat != null:
			new_mesh.surface_set_material(0, old_mat)
		terrain.mesh = new_mesh

		var terrain_static := scene_root.find_child("TerrainStatic", true, false) as StaticBody3D
		if terrain_static != null:
			for sub in terrain_static.get_children():
				if sub is CollisionShape3D:
					var concave := ConcavePolygonShape3D.new()
					concave.set_faces(new_mesh.get_faces())
					(sub as CollisionShape3D).shape = concave
					break

	terrain.set_meta("concave_bunkers_baked", true)
	return any_modified


static func _refresh_bunker_splat_and_ao_maps(
	scene_root: Node,
	polygons: Array[PackedVector2Array],
	height_info: Dictionary
) -> bool:
	if scene_root == null or polygons.is_empty():
		return false
	var terrain := _find_terrain_mesh_instance(scene_root)
	if terrain == null or terrain.mesh == null or terrain.mesh.get_surface_count() == 0:
		return false
	if bool(terrain.get_meta("bunker_splat_v23_baked", false)):
		return false

	var mat: ShaderMaterial = terrain.material_override as ShaderMaterial
	var surf_mat: ShaderMaterial = terrain.mesh.surface_get_material(0) as ShaderMaterial
	if mat == null:
		mat = surf_mat
	if mat == null:
		terrain.set_meta("bunker_splat_v23_baked", true)
		return false

	var splat_tex: Texture2D = mat.get_shader_parameter("splat_map") as Texture2D
	if splat_tex == null and surf_mat != null and surf_mat != mat:
		splat_tex = surf_mat.get_shader_parameter("splat_map") as Texture2D
	if splat_tex == null and terrain.has_meta("orig_splat_map"):
		splat_tex = terrain.get_meta("orig_splat_map") as Texture2D
	if splat_tex == null:
		terrain.set_meta("bunker_splat_v23_baked", true)
		return false

	var src_img := splat_tex.get_image()
	if src_img == null or src_img.get_width() < 2 or src_img.get_height() < 2:
		terrain.set_meta("bunker_splat_v23_baked", true)
		return false
	var img := src_img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var min_x := float(height_info.get("min_x", -300.0))
	var max_x := float(height_info.get("max_x", 300.0))
	var min_z := float(height_info.get("min_z", -300.0))
	var max_z := float(height_info.get("max_z", 300.0))
	var span_x := max_x - min_x
	var span_z := max_z - min_z
	if span_x <= 0.001 or span_z <= 0.001:
		terrain.set_meta("bunker_splat_v23_baked", true)
		return false

	var w := img.get_width()
	var h := img.get_height()
	var denom_x := float(maxi(w - 1, 1))
	var denom_y := float(maxi(h - 1, 1))

	var bunker_aabbs: Array[Rect2] = []
	for poly in polygons:
		if poly.size() < 3:
			bunker_aabbs.append(Rect2())
			continue
		var min_p := poly[0]
		var max_p := poly[0]
		for pt in poly:
			min_p.x = minf(min_p.x, pt.x)
			min_p.y = minf(min_p.y, pt.y)
			max_p.x = maxf(max_p.x, pt.x)
			max_p.y = maxf(max_p.y, pt.y)
		bunker_aabbs.append(Rect2(min_p - Vector2(4.0, 4.0), (max_p - min_p) + Vector2(8.0, 8.0)))

	var dirty_pixels := PackedByteArray()
	dirty_pixels.resize(w * h)
	dirty_pixels.fill(0)
	for b_idx in range(polygons.size()):
		if polygons[b_idx].size() < 3:
			continue
		var r2: Rect2 = bunker_aabbs[b_idx]
		var px0 := clampi(int(floor(((r2.position.x - min_x) / span_x) * denom_x)), 0, w - 1)
		var px1 := clampi(int(ceil(((r2.end.x - min_x) / span_x) * denom_x)), 0, w - 1)
		var py0 := clampi(int(floor(((r2.position.y - min_z) / span_z) * denom_y)), 0, h - 1)
		var py1 := clampi(int(ceil(((r2.end.y - min_z) / span_z) * denom_y)), 0, h - 1)
		for py in range(py0, py1 + 1):
			var row_off := py * w
			for px in range(px0, px1 + 1):
				dirty_pixels[row_off + px] = 1

	var features := _extract_course_features(scene_root)
	var green_tee_entries: Array = []
	green_tee_entries.append_array(features.get("greens", []))
	green_tee_entries.append_array(features.get("tees", []))
	var fairway_entries: Array = features.get("fairways", [])
	const BLEND_RADIUS := 3.0
	var texel_m := maxf(span_x / denom_x, span_z / denom_y)
	var bunker_aa := clampf(texel_m * 0.85, 0.30, 0.75)

	var any_splat_changed := false
	for py in range(h):
		var row_off := py * w
		var wz := min_z + (float(py) / denom_y) * span_z
		for px in range(w):
			if dirty_pixels[row_off + px] == 0:
				continue
			var wx := min_x + (float(px) / denom_x) * span_x
			var p2 := Vector2(wx, wz)

			var b_target := 0.0
			for b_idx in range(polygons.size()):
				var b_poly := polygons[b_idx]
				if b_poly.size() < 3 or not bunker_aabbs[b_idx].has_point(p2):
					continue
				var inside := Geometry2D.is_point_in_polygon(p2, b_poly)
				var edist := _edge_distance_to_polygon_2d(p2, b_poly)
				if edist >= bunker_aa:
					if inside:
						b_target = 1.0
						break
				else:
					var sd := edist if inside else -edist
					b_target = maxf(b_target, clampf(0.5 + 0.5 * (sd / bunker_aa), 0.0, 1.0))

			var old_col := img.get_pixel(px, py)
			var bunker_occ := clampf((b_target - 0.42) / 0.58, 0.0, 1.0)
			if bunker_occ >= 1.0:
				if old_col.r > 0.005 or old_col.g > 0.005 or old_col.b < 0.995:
					img.set_pixel(px, py, Color(0.0, 0.0, 1.0, old_col.a))
					any_splat_changed = true
			elif b_target > 0.001 or old_col.b > 0.001:
				var green_w := 0.0
				for gt in green_tee_entries:
					var g_aabb: Rect2 = gt["aabb"]
					if not g_aabb.grow(BLEND_RADIUS).has_point(p2):
						continue
					var g_poly: PackedVector2Array = gt["poly"]
					if Geometry2D.is_point_in_polygon(p2, g_poly):
						green_w = 1.0
						break
					var g_dist := _edge_distance_to_polygon_2d(p2, g_poly)
					if g_dist < BLEND_RADIUS:
						green_w = maxf(green_w, _quintic_smoothstep(1.0 - (g_dist / BLEND_RADIUS)))

				var fairway_w := 0.0
				if green_w < 1.0:
					if not fairway_entries.is_empty():
						for fw in fairway_entries:
							var f_aabb: Rect2 = fw["aabb"]
							if not f_aabb.grow(BLEND_RADIUS).has_point(p2):
								continue
							var f_poly: PackedVector2Array = fw["poly"]
							if Geometry2D.is_point_in_polygon(p2, f_poly):
								fairway_w = 1.0
								break
							var f_dist := _edge_distance_to_polygon_2d(p2, f_poly)
							if f_dist < BLEND_RADIUS:
								fairway_w = maxf(fairway_w, _quintic_smoothstep(1.0 - (f_dist / BLEND_RADIUS)))
					elif old_col.g > 0.01:
						fairway_w = clampf(old_col.g / maxf(1.0 - old_col.b, 0.05), 0.0, 1.0)
					fairway_w = minf(fairway_w, 1.0 - green_w)

				if bunker_occ > 0.0:
					green_w *= (1.0 - bunker_occ)
					fairway_w *= (1.0 - bunker_occ)

				var new_col := Color(green_w, fairway_w, b_target, old_col.a)
				if absf(new_col.r - old_col.r) > 0.004 or absf(new_col.g - old_col.g) > 0.004 or absf(new_col.b - old_col.b) > 0.004:
					img.set_pixel(px, py, new_col)
					any_splat_changed = true

	if any_splat_changed:
		var new_splat := ImageTexture.create_from_image(img)
		mat.set_shader_parameter("splat_map", new_splat)
		if surf_mat != null and surf_mat != mat:
			surf_mat.set_shader_parameter("splat_map", new_splat)
		if terrain.has_meta("orig_splat_map"):
			terrain.set_meta("orig_splat_map", new_splat)

	var ao_tex: Texture2D = mat.get_shader_parameter("terrain_ao_map") as Texture2D
	if ao_tex == null and surf_mat != null and surf_mat != mat:
		ao_tex = surf_mat.get_shader_parameter("terrain_ao_map") as Texture2D
	if ao_tex != null:
		var src_ao := ao_tex.get_image()
		if src_ao != null and src_ao.get_width() >= 2 and src_ao.get_height() >= 2:
			var ao_img := src_ao.duplicate() as Image
			if ao_img.is_compressed():
				ao_img.decompress()
			var aw := ao_img.get_width()
			var ah := ao_img.get_height()
			var aden_x := float(maxi(aw - 1, 1))
			var aden_y := float(maxi(ah - 1, 1))
			var ao_dirty := PackedByteArray()
			ao_dirty.resize(aw * ah)
			ao_dirty.fill(0)
			for b_idx in range(polygons.size()):
				if polygons[b_idx].size() < 3:
					continue
				var r2: Rect2 = bunker_aabbs[b_idx]
				var px0 := clampi(int(floor(((r2.position.x - min_x) / span_x) * aden_x)), 0, aw - 1)
				var px1 := clampi(int(ceil(((r2.end.x - min_x) / span_x) * aden_x)), 0, aw - 1)
				var py0 := clampi(int(floor(((r2.position.y - min_z) / span_z) * aden_y)), 0, ah - 1)
				var py1 := clampi(int(ceil(((r2.end.y - min_z) / span_z) * aden_y)), 0, ah - 1)
				for py in range(py0, py1 + 1):
					var ro := py * aw
					for px in range(px0, px1 + 1):
						ao_dirty[ro + px] = 1
			var ring_dirs := PackedVector2Array()
			for k in range(12):
				var ang := float(k) * (PI / 6.0)
				ring_dirs.append(Vector2(cos(ang) * 6.0, sin(ang) * 6.0))
			for py in range(ah):
				var ro := py * aw
				var wz := min_z + (float(py) / aden_y) * span_z
				for px in range(aw):
					if ao_dirty[ro + px] == 0:
						continue
					var wx := min_x + (float(px) / aden_x) * span_x
					var hc := _sample_height(wx, wz, height_info, 0.0)
					var hsum := 0.0
					for d in ring_dirs:
						hsum += _sample_height(wx + d.x, wz + d.y, height_info, hc)
					var ao := clampf(1.0 + (hc - hsum / 12.0) * 0.45, 0.55, 1.0)
					ao_img.set_pixel(px, py, Color(ao, ao, ao, 1.0))
			var new_ao := ImageTexture.create_from_image(ao_img)
			mat.set_shader_parameter("terrain_ao_map", new_ao)
			if surf_mat != null and surf_mat != mat:
				surf_mat.set_shader_parameter("terrain_ao_map", new_ao)

	terrain.set_meta("bunker_splat_v23_baked", true)
	return any_splat_changed


static func _create_synthetic_bunker_polygon(center: Vector2, length: float, width: float, angle_rad: float, seed_val: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var num_pts := 12
	var half_len := length * 0.5
	var half_wid := width * 0.5
	var cos_a := cos(angle_rad)
	var sin_a := sin(angle_rad)

	for i in range(num_pts):
		var theta := float(i) * (TAU / float(num_pts))
		var r_w := half_wid * (1.0 + 0.18 * sin(theta * 2.0 + float(seed_val) * 0.5) + 0.12 * cos(theta + float(seed_val) * 0.3))
		var r_l := half_len * (1.0 + 0.10 * cos(theta * 3.0 + float(seed_val) * 0.7))
		var lx := r_l * cos(theta)
		var lz := r_w * sin(theta)
		var wx := center.x + (lx * cos_a - lz * sin_a)
		var wz := center.y + (lx * sin_a + lz * cos_a)
		pts.append(Vector2(wx, wz))
	return pts


static func _is_synthetic_bunker_clear(
	b_poly: PackedVector2Array,
	b_center: Vector2,
	g_poly: PackedVector2Array,
	features: Dictionary,
	existing_bunkers: Array[PackedVector2Array]
) -> bool:
	# 1. Must not intersect green interior
	if not g_poly.is_empty():
		if Geometry2D.is_point_in_polygon(b_center, g_poly):
			return false
		for pt in b_poly:
			if Geometry2D.is_point_in_polygon(pt, g_poly):
				return false

	# 2. Must not overlap water hazards (>= 3.5m clearance)
	for water in features.get("water", []):
		var w_poly: PackedVector2Array = water["poly"]
		var aabb: Rect2 = water["aabb"]
		if b_center.x >= aabb.position.x - 12.0 and b_center.x <= aabb.end.x + 12.0 and \
		   b_center.y >= aabb.position.y - 12.0 and b_center.y <= aabb.end.y + 12.0:
			if Geometry2D.is_point_in_polygon(b_center, w_poly):
				return false
			for pt in b_poly:
				if Geometry2D.is_point_in_polygon(pt, w_poly) or _distance_to_polygon_2d(pt, w_poly) < 3.5:
					return false

	# 3. Must not intersect cart paths (>= 2.5m clearance)
	for path in features.get("cart_paths", []):
		var p_pts: PackedVector2Array = path as PackedVector2Array
		for i in range(p_pts.size() - 1):
			if _distance_squared_to_segment_2d(b_center, p_pts[i], p_pts[i + 1]) < 3.0 * 3.0:
				return false
			for pt in b_poly:
				if _distance_squared_to_segment_2d(pt, p_pts[i], p_pts[i + 1]) < 2.5 * 2.5:
					return false

	# 4. Must not intersect concrete roads (>= 4.0m clearance)
	for road in features.get("roads", []):
		var r_pts: PackedVector2Array = road as PackedVector2Array
		for i in range(r_pts.size() - 1):
			if _distance_squared_to_segment_2d(b_center, r_pts[i], r_pts[i + 1]) < 4.0 * 4.0:
				return false

	# 5. Must not intersect buildings (>= 4.0m clearance)
	for bld in features.get("buildings", []):
		var aabb: Rect2 = bld["aabb"]
		if b_center.x >= aabb.position.x - 8.0 and b_center.x <= aabb.end.x + 8.0 and \
		   b_center.y >= aabb.position.y - 8.0 and b_center.y <= aabb.end.y + 8.0:
			if _distance_to_polygon_2d(b_center, bld["poly"]) < 4.0:
				return false

	# 6. Must not intersect tee boxes (>= 5.0m clearance)
	for t in features.get("tees", []):
		var aabb: Rect2 = t["aabb"]
		if b_center.x >= aabb.position.x - 10.0 and b_center.x <= aabb.end.x + 10.0 and \
		   b_center.y >= aabb.position.y - 10.0 and b_center.y <= aabb.end.y + 10.0:
			if _distance_to_polygon_2d(b_center, t["poly"]) < 5.0:
				return false

	# 7. Must not overlap other existing bunkers
	for eb in existing_bunkers:
		for pt in b_poly:
			if Geometry2D.is_point_in_polygon(pt, eb):
				return false

	return true


## Extracts the outer 2D boundary polygon from a ConcavePolygonShape3D face array in world space.
## In a triangulated 2D manifold mesh, interior edges are shared by 2 triangles,
## while boundary edges belong to exactly 1 triangle.
## Chaining these single-occurrence boundary edges produces the exact (potentially concave) polygon.
static func _extract_boundary_polygon_from_faces(faces: PackedVector3Array, xform: Transform3D) -> PackedVector2Array:
	if faces.size() < 3 or (faces.size() % 3) != 0:
		return PackedVector2Array()

	var edge_counts := {}
	var edge_directed := {}
	var snapped_to_world := {}

	var tri_count := faces.size() / 3
	for t in range(tri_count):
		var base := t * 3
		var v0 := xform * faces[base]
		var v1 := xform * faces[base + 1]
		var v2 := xform * faces[base + 2]

		var p0 := Vector2(v0.x, v0.z)
		var p1 := Vector2(v1.x, v1.z)
		var p2 := Vector2(v2.x, v2.z)

		var s0 := Vector2i(roundi(p0.x * 1000.0), roundi(p0.y * 1000.0))
		var s1 := Vector2i(roundi(p1.x * 1000.0), roundi(p1.y * 1000.0))
		var s2 := Vector2i(roundi(p2.x * 1000.0), roundi(p2.y * 1000.0))

		if s0 == s1 or s1 == s2 or s2 == s0:
			continue

		snapped_to_world[s0] = p0
		snapped_to_world[s1] = p1
		snapped_to_world[s2] = p2

		var tri_edges := [
			Vector4i(s0.x, s0.y, s1.x, s1.y),
			Vector4i(s1.x, s1.y, s2.x, s2.y),
			Vector4i(s2.x, s2.y, s0.x, s0.y)
		]

		for edge in tri_edges:
			var u := Vector2i(edge.x, edge.y)
			var v := Vector2i(edge.z, edge.w)
			var undirected_key: Vector4i
			if u.x < v.x or (u.x == v.x and u.y < v.y):
				undirected_key = Vector4i(u.x, u.y, v.x, v.y)
			else:
				undirected_key = Vector4i(v.x, v.y, u.x, u.y)

			edge_counts[undirected_key] = edge_counts.get(undirected_key, 0) + 1
			edge_directed[undirected_key] = edge

	var adj := {}
	for key in edge_counts:
		if edge_counts[key] == 1:
			var dir_edge: Vector4i = edge_directed[key]
			var from_pt := Vector2i(dir_edge.x, dir_edge.y)
			var to_pt := Vector2i(dir_edge.z, dir_edge.w)
			adj[from_pt] = to_pt

	if adj.is_empty():
		return PackedVector2Array()

	# Trace closed loops of boundary edges and select the primary outer loop
	var best_loop := PackedVector2Array()
	var best_area := 0.0
	var visited := {}

	for start_node in adj.keys():
		if visited.has(start_node):
			continue
		var loop := PackedVector2Array()
		var curr: Vector2i = start_node
		while not visited.has(curr) and adj.has(curr):
			visited[curr] = true
			if snapped_to_world.has(curr):
				loop.append(snapped_to_world[curr])
			var nxt: Vector2i = adj[curr]
			if nxt == start_node:
				break
			curr = nxt

		if loop.size() >= 3:
			# Remove near-zero distance consecutive duplicate points
			var cleaned := PackedVector2Array()
			for pt in loop:
				if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_squared_to(pt) > 0.0001:
					cleaned.append(pt)
			if cleaned.size() > 3 and cleaned[cleaned.size() - 1].distance_squared_to(cleaned[0]) < 0.0001:
				cleaned.remove_at(cleaned.size() - 1)

			# Remove redundant collinear vertices along straight edges
			if cleaned.size() > 3:
				var simplified := PackedVector2Array()
				var c_cnt := cleaned.size()
				for i in range(c_cnt):
					var prev_p: Vector2 = cleaned[(i - 1 + c_cnt) % c_cnt]
					var curr_p: Vector2 = cleaned[i]
					var next_p: Vector2 = cleaned[(i + 1) % c_cnt]
					var e1 := (curr_p - prev_p).normalized()
					var e2 := (next_p - curr_p).normalized()
					var cross := absf(e1.x * e2.y - e1.y * e2.x)
					var dot := e1.dot(e2)
					if cross < 0.001 and dot > 0.999:
						continue
					simplified.append(curr_p)
				if simplified.size() >= 3:
					cleaned = simplified

			if cleaned.size() >= 3:
				var loop_area := 0.0
				var c_size := cleaned.size()
				for i in range(c_size):
					var a: Vector2 = cleaned[i]
					var b: Vector2 = cleaned[(i + 1) % c_size]
					loop_area += (a.x * b.y - b.x * a.y)
				var abs_area := absf(loop_area)
				if abs_area > best_area:
					best_area = abs_area
					if loop_area < 0.0:
						cleaned.reverse()
					best_loop = cleaned

	return best_loop


static func _subdivide_and_orient_ccw(poly: PackedVector2Array, max_seg_len: float) -> PackedVector2Array:
	var n := poly.size()
	if n < 3:
		return poly
	# Compute signed area in XZ
	var area := 0.0
	for i in range(n):
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += (a.x * b.y - b.x * a.y)
	var ordered := poly.duplicate()
	if area < 0.0:
		ordered.reverse()

	var subdiv := PackedVector2Array()
	for i in range(ordered.size()):
		var p0 := ordered[i]
		var p1 := ordered[(i + 1) % ordered.size()]
		var d := p0.distance_to(p1)
		var steps := clampi(int(ceil(d / max_seg_len)), 1, 12)
		for s in range(steps):
			subdiv.append(p0.lerp(p1, float(s) / float(steps)))
	return subdiv


static func _sanitize_and_smooth_bunker_polygon(poly: PackedVector2Array, max_seg_len: float = 0.65) -> PackedVector2Array:
	if poly.size() < 3:
		return poly

	# 1. Orient CCW in XZ so inward normals (-dz, dx) point inside
	var ordered := _subdivide_and_orient_ccw(poly, 10000.0)

	# 2. Remove near-duplicate consecutive vertices (< 0.25m)
	var dedup := PackedVector2Array()
	for pt in ordered:
		if dedup.is_empty() or dedup[dedup.size() - 1].distance_squared_to(pt) >= 0.0625:
			dedup.append(pt)
	while dedup.size() > 3 and dedup[dedup.size() - 1].distance_squared_to(dedup[0]) < 0.0625:
		dedup.remove_at(dedup.size() - 1)
	if dedup.size() < 3:
		return ordered

	# 3. Remove hairpin spikes (e1.dot(e2) < -0.75) that fold edges across sand
	var unspiked := dedup
	for _pass in range(4):
		if unspiked.size() <= 4:
			break
		var next_poly := PackedVector2Array()
		var cnt := unspiked.size()
		var removed_any := false
		for i in range(cnt):
			var prev_p := unspiked[(i - 1 + cnt) % cnt]
			var curr_p := unspiked[i]
			var next_p := unspiked[(i + 1) % cnt]
			var v1 := curr_p - prev_p
			var v2 := next_p - curr_p
			if v1.length_squared() < 0.0001 or v2.length_squared() < 0.0001:
				removed_any = true
				continue
			if v1.normalized().dot(v2.normalized()) < -0.75:
				removed_any = true
				continue
			next_poly.append(curr_p)
		if next_poly.size() >= 3:
			unspiked = next_poly
		if not removed_any:
			break

	# 4. Preserve exact boundary vertices (no Chaikin corner-cutting) so RecessedBunker matches splat_map 1:1
	return _subdivide_and_orient_ccw(unspiked, max_seg_len)


static func _unfold_offset_ring(ring2d: PackedVector2Array, base_poly: PackedVector2Array) -> PackedVector2Array:
	var count := mini(ring2d.size(), base_poly.size())
	var out := ring2d.duplicate()
	for _pass in range(4):
		for i in range(count):
			var ni := (i + 1) % count
			var edge_ref := base_poly[ni] - base_poly[i]
			var edge_ring := out[ni] - out[i]
			if edge_ring.dot(edge_ref) <= 0.0:
				out[i] = out[i].lerp(base_poly[i], 0.60)
				out[ni] = out[ni].lerp(base_poly[ni], 0.60)
	return out


static func _push_point_side_of_poly(
	p: Vector2,
	dir: Vector2,
	dist_init: float,
	poly: PackedVector2Array,
	want_inside: bool,
	fallback_dist: float
) -> float:
	var d := dist_init
	var pt := p + dir * d
	if Geometry2D.is_point_in_polygon(pt, poly) == want_inside:
		return d
	for _h in range(4):
		d *= 0.5
		pt = p + dir * d
		if Geometry2D.is_point_in_polygon(pt, poly) == want_inside:
			return d
	return fallback_dist


static func _create_single_bunker_lip_and_bowl_mesh(
	poly: PackedVector2Array,
	height_info: Dictionary,
	fallback_y: float
) -> ArrayMesh:
	var count := poly.size()
	if count < 4:
		return null

	# Compute inward unit normals and local turning curvature at each vertex.
	# For any strictly CCW polygon in (X, Z), inward normal to (dx, dz) is (-dz, dx).
	var inward_dirs := PackedVector2Array()
	inward_dirs.resize(count)
	var cross_vals := PackedFloat32Array()
	cross_vals.resize(count)
	var dot_vals := PackedFloat32Array()
	dot_vals.resize(count)
	var min_adj_edges := PackedFloat32Array()
	min_adj_edges.resize(count)

	for i in range(count):
		var prev := poly[(i - 1 + count) % count]
		var curr := poly[i]
		var next := poly[(i + 1) % count]
		var v1 := curr - prev
		var v2 := next - curr
		var l1 := v1.length()
		var l2 := v2.length()
		var e1 := v1 / l1 if l1 > 0.0001 else Vector2(1.0, 0.0)
		var e2 := v2 / l2 if l2 > 0.0001 else e1
		var n1 := Vector2(-e1.y, e1.x)
		var n2 := Vector2(-e2.y, e2.x)
		var sum_n := n1 + n2
		inward_dirs[i] = sum_n.normalized() if sum_n.length_squared() > 0.0001 else n1
		cross_vals[i] = e1.x * e2.y - e1.y * e2.x
		dot_vals[i] = clampf(e1.dot(e2), -1.0, 1.0)
		min_adj_edges[i] = minf(l1, l2)

	# Calculate distance to opposite boundary along inward ray to strictly prevent
	# inward insets from crossing narrow tongues, fingers, or opposite shores
	var opp_dists := PackedFloat32Array()
	opp_dists.resize(count)
	for i in range(count):
		var p := poly[i]
		var r := inward_dirs[i]
		var min_opp := 999.0
		for j in range(count):
			if j == i or (j + 1) % count == i or (i + 1) % count == j:
				continue
			var a := poly[j]
			var b := poly[(j + 1) % count]
			var v1 := p - a
			var v2 := b - a
			var dot := v2.x * (-r.y) + v2.y * r.x
			if absf(dot) > 0.00001:
				var t := (v2.x * v1.y - v2.y * v1.x) / dot
				var u := (v1.x * (-r.y) + v1.y * r.x) / dot
				if t > 0.01 and u >= 0.0 and u <= 1.0:
					if t < min_opp:
						min_opp = t
		opp_dists[i] = min_opp

	var pts_out := PackedVector2Array()
	var pts_wall := PackedVector2Array()
	var pts_sand := PackedVector2Array()
	pts_out.resize(count)
	pts_wall.resize(count)
	pts_sand.resize(count)

	for i in range(count):
		var p := poly[i]
		var in_d := inward_dirs[i]
		var opp := opp_dists[i]
		var max_safe := minf(0.42, opp * 0.28) if opp < 900.0 else 0.42
		if cross_vals[i] > 0.05:
			var half_angle := 0.5 * acos(dot_vals[i])
			max_safe = minf(max_safe, 0.42 * min_adj_edges[i] / maxf(tan(half_angle), 0.1))

		var inset_sand := _push_point_side_of_poly(p, in_d, clampf(max_safe, 0.02, 0.42), poly, true, 0.02)

		var collar_out_target := clampf(minf(0.16, opp * 0.16), 0.05, 0.16)
		if cross_vals[i] < -0.05:
			var half_angle_out := 0.5 * acos(dot_vals[i])
			collar_out_target = minf(collar_out_target, maxf(0.02, 0.42 * min_adj_edges[i] / maxf(tan(half_angle_out), 0.1)))
		var collar_out := _push_point_side_of_poly(p, -in_d, collar_out_target, poly, false, 0.02)

		pts_out[i] = p - in_d * collar_out
		pts_sand[i] = p + in_d * inset_sand

	# Eliminate any self-crossing / folded offset edges, then derive intermediate wall ring strictly inside boundary
	pts_out = _unfold_offset_ring(pts_out, poly)
	pts_sand = _unfold_offset_ring(pts_sand, poly)
	for i in range(count):
		pts_wall[i] = poly[i].lerp(pts_sand[i], 0.35)

	var ring_outer := PackedVector3Array()
	var ring_rim := PackedVector3Array()
	var ring_wall_base := PackedVector3Array()
	var ring_sand_inner := PackedVector3Array()
	ring_outer.resize(count)
	ring_rim.resize(count)
	ring_wall_base.resize(count)
	ring_sand_inner.resize(count)

	for i in range(count):
		var p_out := pts_out[i]
		var p_rim := poly[i]
		var p_wall := pts_wall[i]
		var p_sand := pts_sand[i]

		var y_out := _sample_height(p_out.x, p_out.y, height_info, fallback_y) + 0.008
		var y_rim := _sample_height(p_rim.x, p_rim.y, height_info, fallback_y) + 0.032
		var y_wall := _sample_height(p_wall.x, p_wall.y, height_info, fallback_y) + 0.018
		var y_sand := _sample_height(p_sand.x, p_sand.y, height_info, fallback_y) + 0.008

		ring_outer[i] = Vector3(p_out.x, y_out, p_out.y)
		ring_rim[i] = Vector3(p_rim.x, y_rim, p_rim.y)
		ring_wall_base[i] = Vector3(p_wall.x, y_wall, p_wall.y)
		ring_sand_inner[i] = Vector3(p_sand.x, y_sand, p_sand.y)

	# 1-pass midpoint clearance lift on collar edges so subtle cut-lip never clips convex ridges
	var ring_max_off := [0.06, 0.10, 0.08, 0.06]
	var ring_lifts := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	for r_idx in range(4):
		var arr: PackedFloat32Array = ring_lifts[r_idx]
		arr.resize(count)
		arr.fill(0.0)
	var rings_snap := [ring_outer, ring_rim, ring_wall_base, ring_sand_inner]
	for i in range(count):
		var ni := (i + 1) % count
		for r_idx in range(4):
			var rg: PackedVector3Array = rings_snap[r_idx]
			var mid := (rg[i] + rg[ni]) * 0.5
			var deficit := (_sample_height(mid.x, mid.z, height_info, fallback_y) + 0.006) - mid.y
			if deficit > 0.0:
				var rl: PackedFloat32Array = ring_lifts[r_idx]
				if deficit > rl[i]: rl[i] = deficit
				if deficit > rl[ni]: rl[ni] = deficit
		for r_idx in range(3):
			var ra: PackedVector3Array = rings_snap[r_idx]
			var rb: PackedVector3Array = rings_snap[r_idx + 1]
			var mid := (ra[i] + rb[i]) * 0.5
			var deficit := (_sample_height(mid.x, mid.z, height_info, fallback_y) + 0.006) - mid.y
			if deficit > 0.0:
				var rla: PackedFloat32Array = ring_lifts[r_idx]
				var rlb: PackedFloat32Array = ring_lifts[r_idx + 1]
				if deficit > rla[i]: rla[i] = deficit
				if deficit > rlb[i]: rlb[i] = deficit
	for r_idx in range(4):
		var rg := (rings_snap[r_idx] as PackedVector3Array).duplicate()
		var rl: PackedFloat32Array = ring_lifts[r_idx]
		for i in range(count):
			if rl[i] > 0.0:
				var v := rg[i]
				var max_y := _sample_height(v.x, v.z, height_info, fallback_y) + float(ring_max_off[r_idx])
				v.y = minf(v.y + rl[i], max_y)
				rg[i] = v
		rings_snap[r_idx] = rg
	ring_outer = rings_snap[0]
	ring_rim = rings_snap[1]
	ring_wall_base = rings_snap[2]
	ring_sand_inner = rings_snap[3]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Color encoding: R = sand, G = undercut lip/soil, B = subtle turf cut edge, A = alpha
	var col_outer := Color(0.0, 0.0, 1.0, 0.0)
	var col_rim := Color(0.10, 0.72, 0.18, 0.72)
	var col_wall := Color(0.72, 0.28, 0.0, 0.65)
	var col_sand := Color(1.0, 0.0, 0.0, 0.0)

	for i in range(count):
		var ni := (i + 1) % count
		var mid_edge := (poly[i] + poly[ni]) * 0.5
		var terrain_n := _sample_normal(mid_edge.x, mid_edge.y, height_info)
		var mid_in := (inward_dirs[i] + inward_dirs[ni]).normalized()
		if mid_in.length_squared() < 0.0001:
			mid_in = inward_dirs[i]
		var rim_n := (terrain_n * 0.65 + Vector3(mid_in.x, 0.65, mid_in.y).normalized() * 0.35).normalized()
		var wall_n := (terrain_n * 0.45 + Vector3(mid_in.x, 0.45, mid_in.y).normalized() * 0.55).normalized()

		# Band 1: Feathered grass-to-lip cut edge hugging exact boundary
		_add_quad(st, ring_outer[i], ring_outer[ni], ring_rim[ni], ring_rim[i], col_outer, col_outer, col_rim, col_rim, rim_n)
		# Band 2: Subtle shadowed root/soil cut lip onto upper concave sand face
		_add_quad(st, ring_rim[i], ring_rim[ni], ring_wall_base[ni], ring_wall_base[i], col_rim, col_rim, col_wall, col_wall, wall_n)
		# Band 3: Soft transition apron feathering smoothly into UnifiedTerrain sand
		_add_quad(st, ring_wall_base[i], ring_wall_base[ni], ring_sand_inner[ni], ring_sand_inner[i], col_wall, col_wall, col_sand, col_sand, terrain_n)

	# The interior bunker sand floor and surrounding raised grass bank are rendered directly
	# by UnifiedTerrain with matched fairway/green/rough shading and concave bowl geometry.
	return st.commit()


static func _add_tri_upward(
	st: SurfaceTool,
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	c0: Color,
	c1: Color,
	c2: Color,
	n: Vector3
) -> void:
	# Godot 4 CW front-face normal for (v0, v1, v2) is (v2 - v0).cross(v1 - v0)
	var front_n := (v2 - v0).cross(v1 - v0)
	if front_n.length_squared() < 1e-10:
		return
	if front_n.y < 0.0:
		st.set_normal(n)
		st.set_color(c0)
		st.set_uv(Vector2(v0.x * 0.2, v0.z * 0.2))
		st.add_vertex(v0)
		st.set_normal(n)
		st.set_color(c2)
		st.set_uv(Vector2(v2.x * 0.2, v2.z * 0.2))
		st.add_vertex(v2)
		st.set_normal(n)
		st.set_color(c1)
		st.set_uv(Vector2(v1.x * 0.2, v1.z * 0.2))
		st.add_vertex(v1)
	else:
		st.set_normal(n)
		st.set_color(c0)
		st.set_uv(Vector2(v0.x * 0.2, v0.z * 0.2))
		st.add_vertex(v0)
		st.set_normal(n)
		st.set_color(c1)
		st.set_uv(Vector2(v1.x * 0.2, v1.z * 0.2))
		st.add_vertex(v1)
		st.set_normal(n)
		st.set_color(c2)
		st.set_uv(Vector2(v2.x * 0.2, v2.z * 0.2))
		st.add_vertex(v2)


static func _add_quad(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	ca: Color,
	cb: Color,
	cc: Color,
	cd: Color,
	n: Vector3
) -> void:
	_add_tri_upward(st, a, b, c, ca, cb, cc, n)
	_add_tri_upward(st, a, c, d, ca, cc, cd, n)


static func _create_bunker_high_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists("res://Courses/Environments/shaders/bunker_high.gdshader"):
		mat.shader = load("res://Courses/Environments/shaders/bunker_high.gdshader") as Shader
		if ResourceLoader.exists("res://Courses/Environments/sand-bunker/albedo.png"):
			mat.set_shader_parameter("tex_sand", load("res://Courses/Environments/sand-bunker/albedo.png"))
		if ResourceLoader.exists("res://Courses/Environments/sand-bunker/normal.png"):
			mat.set_shader_parameter("normal_sand", load("res://Courses/Environments/sand-bunker/normal.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/albedo.png"):
			mat.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/normal.png"):
			mat.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
	return mat


static func _get_water_surface_max_y(faces: PackedVector3Array, xform: Transform3D) -> float:
	var my := -99999.0
	for i in range(faces.size()):
		var vy := (xform * faces[i]).y
		if vy > my:
			my = vy
	return my if my > -90000.0 else xform.origin.y


static func _sample_water_surface_y(wx: float, wz: float, faces: PackedVector3Array, xform: Transform3D, fallback_y: float) -> float:
	if faces.is_empty():
		return fallback_y
	var best_d_sq := INF
	var best_y := fallback_y
	for i in range(faces.size()):
		var wv := xform * faces[i]
		var dx := wv.x - wx
		var dz := wv.z - wz
		var d_sq := dx * dx + dz * dz
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best_y = wv.y
			if d_sq < 0.04:
				break
	return best_y


static func _orient_polygon_with_3d_ccw(poly: PackedVector2Array, poly_3d: PackedVector3Array) -> Dictionary:
	var n := poly.size()
	if n < 3:
		return { "poly": poly, "poly_3d": poly_3d }
	var area := 0.0
	for i in range(n):
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += (a.x * b.y - b.x * a.y)
	if area < 0.0:
		var rev2 := poly.duplicate()
		rev2.reverse()
		var rev3 := poly_3d.duplicate()
		rev3.reverse()
		return { "poly": rev2, "poly_3d": rev3 }
	return { "poly": poly, "poly_3d": poly_3d }


static func _orient_polygon_ccw(poly: PackedVector2Array) -> PackedVector2Array:
	var n := poly.size()
	if n < 3:
		return poly
	var area := 0.0
	for i in range(n):
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += (a.x * b.y - b.x * a.y)
	if area < 0.0:
		var rev := poly.duplicate()
		rev.reverse()
		return rev
	return poly


static func _build_shoreline_reeds(scene_root: Node, height_info: Dictionary, persist_for_save: bool, force_rebuild: bool = false) -> int:
	# If shoreline reeds already exist on this scene and rebuild is not forced, retain existing
	var existing_reeds := scene_root.get_node_or_null("ShorelineReedsMultiMesh") as MultiMeshInstance3D
	if existing_reeds != null and not force_rebuild and existing_reeds.multimesh != null and existing_reeds.multimesh.instance_count > 0:
		return existing_reeds.multimesh.instance_count
	if existing_reeds != null:
		if existing_reeds.is_inside_tree():
			existing_reeds.queue_free()
		else:
			existing_reeds.free()

	var water_polygons: Array[PackedVector2Array] = []
	var water_boundaries_3d: Array[PackedVector3Array] = []
	var water_fallback_y: Array[float] = []

	# 1. Extract exact water polygons and accurate surface elevations from water StaticBody3D / CollisionObject3D nodes
	for child in scene_root.find_children("*", "CollisionObject3D", true, false):
		var cname := child.name.to_lower()
		var is_wat: bool = bool(child.get_meta("is_water", false)) or cname.begins_with("water") or cname.contains("water")
		if not is_wat:
			continue

		var child_xform: Transform3D = (child as Node3D).global_transform if (child as Node3D).is_inside_tree() else _get_relative_transform_to_root(child as Node3D, scene_root)
		var poly := PackedVector2Array()
		var poly_3d := PackedVector3Array()
		var poly_water_y := child_xform.origin.y
		var water_faces := PackedVector3Array()
		var faces_xform := child_xform

		# Find exact water surface Y from collision mesh faces
		var found_faces := false
		for sub in child.get_children():
			if sub is CollisionShape3D and (sub as CollisionShape3D).shape is ConcavePolygonShape3D:
				var faces := ((sub as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
				if not faces.is_empty():
					faces_xform = child_xform * (sub as CollisionShape3D).transform
					water_faces = faces
					poly_water_y = _get_water_surface_max_y(faces, faces_xform)
					found_faces = true
					break

		# Also check companion MeshInstance3D if collision shape didn't provide faces
		if not found_faces:
			var mi_name := child.name.replace("Static_", "")
			var mi := scene_root.find_child(mi_name, true, false) as MeshInstance3D
			if mi != null and mi.mesh != null:
				var mi_xform: Transform3D = mi.global_transform if mi.is_inside_tree() else _get_relative_transform_to_root(mi, scene_root)
				var faces := mi.mesh.get_faces()
				if not faces.is_empty():
					faces_xform = mi_xform
					water_faces = faces
					poly_water_y = _get_water_surface_max_y(faces, mi_xform)
					found_faces = true

		for meta_key in ["water_points", "boundary_polygon"]:
			if child.has_meta(meta_key):
				var p_meta = child.get_meta(meta_key)
				if p_meta is PackedVector2Array and (p_meta as PackedVector2Array).size() >= 3:
					for pt in (p_meta as PackedVector2Array):
						var wp := child_xform * Vector3(pt.x, 0.0, pt.y)
						var wy := _sample_water_surface_y(wp.x, wp.z, water_faces, faces_xform, poly_water_y) if found_faces else _sample_height(wp.x, wp.z, height_info, poly_water_y)
						poly.append(Vector2(wp.x, wp.z))
						poly_3d.append(Vector3(wp.x, wy, wp.z))
					break
				elif p_meta is Array and (p_meta as Array).size() >= 3:
					for pt in (p_meta as Array):
						if pt is Vector2:
							var wp := child_xform * Vector3((pt as Vector2).x, 0.0, (pt as Vector2).y)
							var wy := _sample_water_surface_y(wp.x, wp.z, water_faces, faces_xform, poly_water_y) if found_faces else _sample_height(wp.x, wp.z, height_info, poly_water_y)
							poly.append(Vector2(wp.x, wp.z))
							poly_3d.append(Vector3(wp.x, wy, wp.z))
					if poly.size() >= 3:
						break

		if poly.size() < 3:
			for sub in child.get_children():
				if sub is CollisionPolygon3D and (sub as CollisionPolygon3D).polygon.size() >= 3:
					var cp := sub as CollisionPolygon3D
					for pt in cp.polygon:
						var wp := child_xform * (cp.transform * Vector3(pt.x, 0.0, pt.y))
						var wy := _sample_water_surface_y(wp.x, wp.z, water_faces, faces_xform, poly_water_y) if found_faces else _sample_height(wp.x, wp.z, height_info, poly_water_y)
						poly.append(Vector2(wp.x, wp.z))
						poly_3d.append(Vector3(wp.x, wy, wp.z))
					break
				elif sub is CollisionShape3D and (sub as CollisionShape3D).shape is ConcavePolygonShape3D:
					var cs := sub as CollisionShape3D
					var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
					var boundary := _extract_boundary_polygon_from_faces(faces, child_xform * cs.transform)
					if boundary.size() >= 3:
						poly = boundary
						for bp in boundary:
							var wy := _sample_water_surface_y(bp.x, bp.y, faces, child_xform * cs.transform, poly_water_y)
							poly_3d.append(Vector3(bp.x, wy, bp.y))
						break

		if poly.size() >= 3:
			water_polygons.append(poly)
			water_boundaries_3d.append(poly_3d)
			water_fallback_y.append(poly_water_y)

	# 2. Fallback: Extract boundary polygons from any Water MeshInstance3D if no water StaticBody3D was found
	if water_polygons.is_empty():
		var search_roots: Array[Node] = [scene_root]
		for child in scene_root.get_children():
			if child is Node3D and child.name.begins_with("Hole"):
				search_roots.append(child)
		for sr in search_roots:
			for child in sr.get_children():
				if not (child is MeshInstance3D):
					continue
				if not child.name.to_lower().begins_with("water"):
					continue
				var mi := child as MeshInstance3D
				if mi.mesh == null or mi.mesh.get_surface_count() == 0:
					continue
				var mi_xform: Transform3D = mi.global_transform if mi.is_inside_tree() else _get_relative_transform_to_root(mi, scene_root)
				var faces := mi.mesh.get_faces()
				var boundary := _extract_boundary_polygon_from_faces(faces, mi_xform)
				var mi_water_y := _get_water_surface_max_y(faces, mi_xform)
				if boundary.size() >= 3:
					var boundary_3d := PackedVector3Array()
					for bp in boundary:
						var wy := _sample_water_surface_y(bp.x, bp.y, faces, mi_xform, mi_water_y)
						boundary_3d.append(Vector3(bp.x, wy, bp.y))
					water_polygons.append(boundary)
					water_boundaries_3d.append(boundary_3d)
					water_fallback_y.append(mi_water_y)
				else:
					var arrays := mi.mesh.surface_get_arrays(0)
					if arrays.size() > Mesh.ARRAY_VERTEX:
						var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						if verts.size() >= 3:
							var world_pts := PackedVector2Array()
							for v in verts:
								var wp := mi_xform * v
								world_pts.append(Vector2(wp.x, wp.z))
							var hull := Geometry2D.convex_hull(world_pts)
							if hull.size() > 3 and hull[hull.size() - 1].is_equal_approx(hull[0]):
								hull.remove_at(hull.size() - 1)
							if hull.size() >= 3:
								var hull_3d := PackedVector3Array()
								for hp in hull:
									var wy := _sample_water_surface_y(hp.x, hp.y, faces, mi_xform, mi_water_y)
									hull_3d.append(Vector3(hp.x, wy, hp.y))
								water_polygons.append(hull)
								water_boundaries_3d.append(hull_3d)
								water_fallback_y.append(mi_water_y)

	if water_polygons.is_empty():
		return 0

	# Extract cart paths and bridge geometry so shoreline reeds are strictly excluded from paths
	var path_segments: Array = []
	if scene_root.has_meta("cart_path_polylines"):
		var meta_lines = scene_root.get_meta("cart_path_polylines")
		if meta_lines is Array:
			for raw_line in meta_lines:
				if (raw_line is PackedVector2Array or raw_line is Array) and raw_line.size() >= 2:
					var pts := PackedVector2Array()
					for p in raw_line:
						if p is Vector2:
							pts.append(p)
						elif p is Vector3:
							pts.append(Vector2(p.x, p.z))
					for i in range(pts.size() - 1):
						var a: Vector2 = pts[i]
						var b: Vector2 = pts[i + 1]
						var r := 1.95 # Cart path half-width (~1.25m) + clearance (~0.70m)
						var min_x = minf(a.x, b.x) - r
						var max_x = maxf(a.x, b.x) + r
						var min_y = minf(a.y, b.y) - r
						var max_y = maxf(a.y, b.y) + r
						path_segments.append({
							"a": a,
							"b": b,
							"radius": r,
							"aabb": Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
						})

	# If polylines were not found, extract ribbon geometry from cartpath or bridge MeshInstance3D nodes
	if path_segments.is_empty():
		for child in scene_root.get_children():
			var cname := child.name.to_lower()
			if child is MeshInstance3D and (cname.begins_with("cartpath_") or cname == "cartpaths" or cname.begins_with("cartbridge_")):
				var mi := child as MeshInstance3D
				if mi.mesh is ArrayMesh and mi.mesh.get_surface_count() > 0:
					var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
					if arrays.size() > Mesh.ARRAY_VERTEX:
						var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						if verts.size() >= 4:
							for i in range(0, verts.size() - 3, 2):
								var p0 := Vector2((verts[i].x + verts[i + 1].x) * 0.5, (verts[i].z + verts[i + 1].z) * 0.5)
								var p1 := Vector2((verts[i + 2].x + verts[i + 3].x) * 0.5, (verts[i + 2].z + verts[i + 3].z) * 0.5)
								var hw := maxf(1.95, verts[i].distance_to(verts[i + 1]) * 0.5 + 0.65)
								var min_x = minf(p0.x, p1.x) - hw
								var max_x = maxf(p0.x, p1.x) + hw
								var min_y = minf(p0.y, p1.y) - hw
								var max_y = maxf(p0.y, p1.y) + hw
								path_segments.append({
									"a": p0,
									"b": p1,
									"radius": hw,
									"aabb": Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
								})

	# Build 2D spatial grid for fast O(1) path collision tests
	var path_grid_cell_size: float = 20.0
	var inv_path_cell: float = 1.0 / path_grid_cell_size
	var path_grid: Dictionary = {}
	for seg in path_segments:
		var aabb: Rect2 = seg["aabb"]
		var min_gx := int(floor(aabb.position.x * inv_path_cell))
		var max_gx := int(floor(aabb.end.x * inv_path_cell))
		var min_gy := int(floor(aabb.position.y * inv_path_cell))
		var max_gy := int(floor(aabb.end.y * inv_path_cell))
		for gy in range(min_gy, max_gy + 1):
			for gx in range(min_gx, max_gx + 1):
				var key := Vector2i(gx, gy)
				if not path_grid.has(key):
					path_grid[key] = [seg]
				else:
					path_grid[key].append(seg)

	var is_pt_on_path := func(pt: Vector2) -> bool:
		if path_grid.is_empty():
			return false
		var key := Vector2i(int(floor(pt.x * inv_path_cell)), int(floor(pt.y * inv_path_cell)))
		if not path_grid.has(key):
			return false
		var segs: Array = path_grid[key]
		for seg in segs:
			var aabb: Rect2 = seg["aabb"]
			if pt.x >= aabb.position.x and pt.x <= aabb.end.x and \
			   pt.y >= aabb.position.y and pt.y <= aabb.end.y:
				var a: Vector2 = seg["a"]
				var b: Vector2 = seg["b"]
				var closest := Geometry2D.get_closest_point_to_segment(pt, a, b)
				var r: float = seg["radius"]
				if pt.distance_squared_to(closest) <= r * r:
					return true
		return false

	var reed_xforms: Array[Transform3D] = []
	var reed_colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 777111

	# Place tall grass / marsh reeds continuously ALL the way around every water hazard
	# Staggered 3-tier dense wetland band (shoreline margin + mid bank + upper rough buffer)
	var min_step := 0.48
	var step_jitter := 0.20

	for p_idx in range(water_polygons.size()):
		var raw_poly := water_polygons[p_idx]
		var raw_poly_3d := water_boundaries_3d[p_idx] if p_idx < water_boundaries_3d.size() else PackedVector3Array()
		var oriented := _orient_polygon_with_3d_ccw(raw_poly, raw_poly_3d)
		var poly: PackedVector2Array = oriented["poly"]
		var poly_3d: PackedVector3Array = oriented["poly_3d"]
		var num_pts := poly.size()
		for i in range(num_pts):
			var p1 := poly[i]
			var p2 := poly[(i + 1) % num_pts]
			var p1_3d: Vector3 = poly_3d[i] if i < poly_3d.size() else Vector3(p1.x, water_fallback_y[p_idx], p1.y)
			var p2_3d: Vector3 = poly_3d[(i + 1) % num_pts] if ((i + 1) % num_pts) < poly_3d.size() else Vector3(p2.x, water_fallback_y[p_idx], p2.y)
			var seg_len := p1.distance_to(p2)
			if seg_len < 0.05:
				continue

			var dir := (p2 - p1) / seg_len
			# Outward normal (toward shore bank) is (dir.y, -dir.x) for CCW polygon
			var outward := Vector2(dir.y, -dir.x)
			var d := 0.0
			while d < seg_len:
				var t := d / seg_len
				var base_pt := p1.lerp(p2, t)
				var local_water_y := lerpf(p1_3d.y, p2_3d.y, t)

				# Multi-frequency spatial wave along shoreline so reed stands undulate naturally
				# between shorter marsh sedge stretches and taller cattail/reed stands
				var wave_macro := sin(base_pt.x * 0.11 + base_pt.y * 0.09) * 0.50 \
					+ sin(base_pt.x * 0.27 - base_pt.y * 0.23 + 1.7) * 0.30 \
					+ sin(base_pt.x * 0.63 + base_pt.y * 0.51 + 3.1) * 0.20
				var patch_h_mult := clampf(0.92 + wave_macro * 0.24, 0.64, 1.20)

				# Cluster 1: Shoreline margin (0.50m to 1.05m onto dry shore bank)
				var off1 := outward * rng.randf_range(0.50, 1.05)
				var pos1 := base_pt + off1
				if not is_pt_on_path.call(pos1):
					var wy1 := _sample_height(pos1.x, pos1.y, height_info, local_water_y)
					wy1 = maxf(wy1, local_water_y - 0.12)
					var rot_y1 := rng.randf_range(0.0, TAU)
					var s_xz1 := rng.randf_range(0.82, 1.18)
					var s_y1 := clampf(patch_h_mult * rng.randf_range(0.70, 1.18), 0.55, 1.30)
					reed_xforms.append(Transform3D(Basis(Vector3.UP, rot_y1).scaled(Vector3(s_xz1, s_y1, s_xz1)), Vector3(pos1.x, wy1, pos1.y)))
					reed_colors.append(Color(rng.randf_range(0.86, 1.06), rng.randf_range(0.90, 1.08), rng.randf_range(0.80, 1.02), rng.randf_range(0.05, 0.99)))

				# Cluster 2: Mid bank slope (1.20m to 2.15m up the bank slope)
				var off2 := outward * rng.randf_range(1.20, 2.15)
				var pos2 := base_pt + off2
				if not is_pt_on_path.call(pos2):
					var wy2 := _sample_height(pos2.x, pos2.y, height_info, local_water_y)
					wy2 = maxf(wy2, local_water_y - 0.12)
					var rot_y2 := rng.randf_range(0.0, TAU)
					var s_xz2 := rng.randf_range(0.78, 1.14)
					var s_y2 := clampf(patch_h_mult * rng.randf_range(0.62, 1.10), 0.50, 1.22)
					reed_xforms.append(Transform3D(Basis(Vector3.UP, rot_y2).scaled(Vector3(s_xz2, s_y2, s_xz2)), Vector3(pos2.x, wy2, pos2.y)))
					reed_colors.append(Color(rng.randf_range(0.84, 1.04), rng.randf_range(0.88, 1.06), rng.randf_range(0.78, 1.00), rng.randf_range(0.05, 0.99)))

				# Cluster 3: Upper bank wetland rough buffer (2.25m to 3.45m up the bank slope, tapering into rough)
				var off3 := outward * rng.randf_range(2.25, 3.45)
				var pos3 := base_pt + off3
				if not is_pt_on_path.call(pos3):
					var wy3 := _sample_height(pos3.x, pos3.y, height_info, local_water_y)
					wy3 = maxf(wy3, local_water_y - 0.12)
					var rot_y3 := rng.randf_range(0.0, TAU)
					var s_xz3 := rng.randf_range(0.75, 1.10)
					var s_y3 := clampf(patch_h_mult * rng.randf_range(0.52, 0.98), 0.44, 1.12)
					reed_xforms.append(Transform3D(Basis(Vector3.UP, rot_y3).scaled(Vector3(s_xz3, s_y3, s_xz3)), Vector3(pos3.x, wy3, pos3.y)))
					reed_colors.append(Color(rng.randf_range(0.82, 1.02), rng.randf_range(0.86, 1.04), rng.randf_range(0.76, 0.98), rng.randf_range(0.05, 0.99)))

				d += min_step + rng.randf() * step_jitter

	if reed_xforms.is_empty():
		return 0

	var reed_mesh := ProceduralTreeGeneratorScript.create_shoreline_reed_cluster_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = reed_mesh
	mm.instance_count = reed_xforms.size()

	var buf := PackedFloat32Array()
	buf.resize(reed_xforms.size() * 16)
	for i in range(reed_xforms.size()):
		var xf: Transform3D = reed_xforms[i]
		var col: Color = reed_colors[i]
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, col)
		var base_idx := i * 16
		buf[base_idx + 0] = xf.basis.x.x
		buf[base_idx + 1] = xf.basis.y.x
		buf[base_idx + 2] = xf.basis.z.x
		buf[base_idx + 3] = xf.origin.x
		buf[base_idx + 4] = xf.basis.x.y
		buf[base_idx + 5] = xf.basis.y.y
		buf[base_idx + 6] = xf.basis.z.y
		buf[base_idx + 7] = xf.origin.y
		buf[base_idx + 8] = xf.basis.x.z
		buf[base_idx + 9] = xf.basis.y.z
		buf[base_idx + 10] = xf.basis.z.z
		buf[base_idx + 11] = xf.origin.z
		buf[base_idx + 12] = col.r
		buf[base_idx + 13] = col.g
		buf[base_idx + 14] = col.b
		buf[base_idx + 15] = col.a
	mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mmi.name = "ShorelineReedsMultiMesh"
	mmi.set_meta("reeds_version", 3)
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 700.0
	mmi.visibility_range_end_margin = 60.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var is_low := false
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root != null:
		var gs = (main_loop as SceneTree).root.get_node_or_null("GlobalSettings")
		if gs != null and gs.has_method("get_graphics_quality"):
			is_low = (gs.get_graphics_quality() == "Low")
	mmi.visible = not is_low
	scene_root.add_child(mmi)
	if persist_for_save:
		mmi.owner = scene_root
	return reed_xforms.size()


static func _get_relative_transform_to_root(node: Node3D, root_node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var curr: Node = node
	while curr != null and curr != root_node:
		if curr is Node3D:
			t = (curr as Node3D).transform * t
		curr = curr.get_parent()
	return t


static func _build_horizon_skirt(scene_root: Node, height_info: Dictionary, persist_for_save: bool) -> bool:
	if scene_root.get_node_or_null("HorizonSkirt") != null:
		return false
	if scene_root.find_child("UnifiedTerrain", true, false) == null:
		return false

	var min_x: float = height_info.get("min_x", -300.0)
	var max_x: float = height_info.get("max_x", 300.0)
	var min_z: float = height_info.get("min_z", -300.0)
	var max_z: float = height_info.get("max_z", 300.0)
	var base_y: float = height_info.get("avg_edge_y", 0.0)

	var pad := 450.0
	var out_min_x := min_x - pad
	var out_max_x := max_x + pad
	var out_min_z := min_z - pad
	var out_max_z := max_z + pad

	# Build a low-poly rolling terrain ring surrounding the course rectangular boundary
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var steps := 16
	var inner_pts := _rect_perimeter_points(min_x + 4.0, max_x - 4.0, min_z + 4.0, max_z - 4.0, steps)
	var mid_pts := _rect_perimeter_points(min_x - 160.0, max_x + 160.0, min_z - 160.0, max_z + 160.0, steps)
	var outer_pts := _rect_perimeter_points(out_min_x, out_max_x, out_min_z, out_max_z, steps)

	var ring_cnt := inner_pts.size()
	for i in range(ring_cnt):
		var ni := (i + 1) % ring_cnt
		var p_in0 := inner_pts[i]
		var p_in1 := inner_pts[ni]
		var p_mid0 := mid_pts[i]
		var p_mid1 := mid_pts[ni]
		var p_out0 := outer_pts[i]
		var p_out1 := outer_pts[ni]

		var y_in0 := _sample_height(p_in0.x, p_in0.y, height_info, base_y) - 0.35
		var y_in1 := _sample_height(p_in1.x, p_in1.y, height_info, base_y) - 0.35
		var y_mid0 := base_y + sin(p_mid0.x * 0.012 + p_mid0.y * 0.015) * 4.5 + 1.5
		var y_mid1 := base_y + sin(p_mid1.x * 0.012 + p_mid1.y * 0.015) * 4.5 + 1.5
		var y_out0 := base_y + sin(p_out0.x * 0.008 - p_out0.y * 0.011) * 9.0 + 5.0
		var y_out1 := base_y + sin(p_out1.x * 0.008 - p_out1.y * 0.011) * 9.0 + 5.0

		var v_in0 := Vector3(p_in0.x, y_in0, p_in0.y)
		var v_in1 := Vector3(p_in1.x, y_in1, p_in1.y)
		var v_mid0 := Vector3(p_mid0.x, y_mid0, p_mid0.y)
		var v_mid1 := Vector3(p_mid1.x, y_mid1, p_mid1.y)
		var v_out0 := Vector3(p_out0.x, y_out0, p_out0.y)
		var v_out1 := Vector3(p_out1.x, y_out1, p_out1.y)

		_add_quad(st, v_in0, v_in1, v_mid1, v_mid0, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3.UP)
		_add_quad(st, v_mid0, v_mid1, v_out1, v_out0, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3.UP)

	var skirt_mesh := st.commit()
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(0.24, 0.36, 0.20)
	skirt_mat.roughness = 0.95
	skirt_mat.metallic_specular = 0.02
	if ResourceLoader.exists("res://Courses/Environments/grass-rough/albedo.png"):
		skirt_mat.albedo_texture = load("res://Courses/Environments/grass-rough/albedo.png") as Texture2D
		skirt_mat.albedo_color = Color(0.76, 0.92, 0.70)
		skirt_mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	skirt_mesh.surface_set_material(0, skirt_mat)

	var skirt_mi := MeshInstance3D.new()
	skirt_mi.name = "HorizonSkirt"
	skirt_mi.mesh = skirt_mesh
	skirt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(skirt_mi)
	if persist_for_save:
		skirt_mi.owner = scene_root
	return true


static func _rect_perimeter_points(min_x: float, max_x: float, min_z: float, max_z: float, steps_per_side: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in range(steps_per_side):
		var t := float(s) / float(steps_per_side)
		pts.append(Vector2(lerpf(min_x, max_x, t), min_z))
	for s in range(steps_per_side):
		var t := float(s) / float(steps_per_side)
		pts.append(Vector2(max_x, lerpf(min_z, max_z, t)))
	for s in range(steps_per_side):
		var t := float(s) / float(steps_per_side)
		pts.append(Vector2(lerpf(max_x, min_x, t), max_z))
	for s in range(steps_per_side):
		var t := float(s) / float(steps_per_side)
		pts.append(Vector2(min_x, lerpf(max_z, min_z, t)))
	return pts


static func _upgrade_water_materials(scene_root: Node) -> void:
	for child in scene_root.get_children():
		if child is MeshInstance3D and child.name.to_lower().begins_with("water"):
			var mi := child as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var mat := mi.mesh.surface_get_material(0)
				if mat is ShaderMaterial:
					var sm := mat as ShaderMaterial
					sm.set_shader_parameter("shallow_color", Color(0.12, 0.23, 0.18))
					sm.set_shader_parameter("deep_color", Color(0.03, 0.09, 0.11))
					sm.set_shader_parameter("foam_amount", 0.12)
					sm.set_shader_parameter("foam_color", Color(0.68, 0.74, 0.70))
					sm.set_shader_parameter("roughness", 0.04)
					sm.set_shader_parameter("height_scale", 0.025)


static func _build_5col_cart_path_mesh_from_runs(runs: Array, height_info: Dictionary, base_y: float) -> ArrayMesh:
	var col_us := [0.0, 0.25, 0.5, 0.75, 1.0]
	var col_offsets := [0.022, 0.030, 0.034, 0.030, 0.022]
	var cols := 5

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for run in runs:
		var left_pts: PackedVector2Array = run.get("left", PackedVector2Array())
		var right_pts: PackedVector2Array = run.get("right", PackedVector2Array())
		var row_count := mini(left_pts.size(), right_pts.size())
		if row_count < 2:
			continue

		var base_vert := verts.size()
		var cum_dist := 0.0
		var prev_mid := (left_pts[0] + right_pts[0]) * 0.5
		for r in range(row_count):
			var lp := left_pts[r]
			var rp := right_pts[r]
			var mid := (lp + rp) * 0.5
			if r > 0:
				cum_dist += prev_mid.distance_to(mid)
			prev_mid = mid
			var v_coord := cum_dist * 0.25
			for c in range(cols):
				var p2 := lp.lerp(rp, float(col_us[c]))
				var y := _sample_height(p2.x, p2.y, height_info, base_y) + float(col_offsets[c])
				verts.append(Vector3(p2.x, y, p2.y))
				normals.append(_sample_normal(p2.x, p2.y, height_info))
				uvs.append(Vector2(float(col_us[c]), v_coord))

		# 2-pass convex-crease midpoint clearance lift so sharp terrain ridges cannot cut slits across the cart path
		var run_vert_count := row_count * cols
		for _pass in range(2):
			var lifts := PackedFloat32Array()
			lifts.resize(run_vert_count)
			lifts.fill(0.0)
			for seg in range(row_count - 1):
				var ra := seg * cols
				var rb := (seg + 1) * cols
				for c in range(cols - 1):
					var i00 := ra + c
					var i10 := ra + c + 1
					var i01 := rb + c
					var i11 := rb + c + 1
					var pairs := [
						[i00, i01, 0.018 if c == 0 else 0.024],
						[i10, i11, 0.018 if c == cols - 2 else 0.024],
						[i00, i10, 0.022],
						[i01, i11, 0.022],
						[i00, i11, 0.024],
						[i10, i01, 0.024]
					]
					for pair in pairs:
						var ia: int = int(pair[0])
						var ib: int = int(pair[1])
						var min_clear: float = float(pair[2])
						var va := verts[base_vert + ia]
						var vb := verts[base_vert + ib]
						var mx := (va.x + vb.x) * 0.5
						var mz := (va.z + vb.z) * 0.5
						var my := (va.y + vb.y) * 0.5
						var deficit := (_sample_height(mx, mz, height_info, base_y) + min_clear) - my
						if deficit > 0.0:
							if deficit > lifts[ia]: lifts[ia] = deficit
							if deficit > lifts[ib]: lifts[ib] = deficit
			for vi in range(run_vert_count):
				if lifts[vi] > 0.0:
					var v := verts[base_vert + vi]
					v.y += lifts[vi]
					verts[base_vert + vi] = v

		# Determine winding so triangle front faces point +Y
		var a0 := Vector3(left_pts[0].x, 0.0, left_pts[0].y)
		var b0 := Vector3(right_pts[0].x, 0.0, right_pts[0].y)
		var c0 := Vector3(left_pts[1].x, 0.0, left_pts[1].y)
		var flip_winding := (b0 - a0).cross(c0 - a0).y < 0.0

		for seg in range(row_count - 1):
			var row_a := base_vert + seg * cols
			var row_b := base_vert + (seg + 1) * cols
			for c in range(cols - 1):
				if flip_winding:
					indices.append(row_a + c)
					indices.append(row_b + c)
					indices.append(row_a + c + 1)
					indices.append(row_a + c + 1)
					indices.append(row_b + c)
					indices.append(row_b + c + 1)
				else:
					indices.append(row_a + c)
					indices.append(row_a + c + 1)
					indices.append(row_b + c)
					indices.append(row_a + c + 1)
					indices.append(row_b + c + 1)
					indices.append(row_b + c)

	if verts.is_empty() or indices.is_empty():
		return null

	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = verts
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh_arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	return mesh


static func _update_cart_path_collision(cart_body: StaticBody3D, path_mesh: ArrayMesh) -> void:
	if cart_body == null or path_mesh == null:
		return
	var col_faces := path_mesh.get_faces()
	for fi in range(col_faces.size()):
		var fv := col_faces[fi]
		fv.y -= 0.010
		col_faces[fi] = fv
	for sub in cart_body.get_children():
		if sub is CollisionShape3D:
			var concave := ConcavePolygonShape3D.new()
			concave.backface_collision = true
			concave.set_faces(col_faces)
			(sub as CollisionShape3D).shape = concave
			break


static func _extract_runs_from_existing_cart_path(am: ArrayMesh) -> Array:
	var runs: Array = []
	if am == null or am.get_surface_count() == 0:
		return runs
	var arrays := am.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if verts.size() < 4:
		return runs

	var cols := 2
	if uvs != null and uvs.size() == verts.size() and verts.size() >= 5 and is_equal_approx(uvs[0].x, 0.0) and is_equal_approx(uvs[1].x, 0.25) and is_equal_approx(uvs[4].x, 1.0):
		cols = 5
	if (verts.size() % cols) != 0:
		return runs

	var num_rows := verts.size() / cols
	if num_rows < 2:
		return runs

	var connected := PackedByteArray()
	connected.resize(num_rows - 1)
	if indices != null and indices is PackedInt32Array and (indices as PackedInt32Array).size() >= 3:
		connected.fill(0)
		var idx_arr: PackedInt32Array = indices
		var tri_count := idx_arr.size() / 3
		for t in range(tri_count):
			var r0 := idx_arr[t * 3] / cols
			var r1 := idx_arr[t * 3 + 1] / cols
			var r2 := idx_arr[t * 3 + 2] / cols
			var min_r := mini(r0, mini(r1, r2))
			var max_r := maxi(r0, maxi(r1, r2))
			if max_r == min_r + 1 and min_r < connected.size():
				connected[min_r] = 1
	else:
		connected.fill(1)

	var r := 0
	while r < num_rows - 1:
		if connected[r] == 0:
			r += 1
			continue
		var run_start := r
		while r < num_rows - 1 and connected[r] == 1:
			r += 1
		var run_end := r

		var left_pts := PackedVector2Array()
		var right_pts := PackedVector2Array()
		var l_first := verts[run_start * cols]
		var r_first := verts[run_start * cols + cols - 1]
		left_pts.append(Vector2(l_first.x, l_first.z))
		right_pts.append(Vector2(r_first.x, r_first.z))

		for ri in range(run_start, run_end):
			var l0_3 := verts[ri * cols]
			var r0_3 := verts[ri * cols + cols - 1]
			var l1_3 := verts[(ri + 1) * cols]
			var r1_3 := verts[(ri + 1) * cols + cols - 1]
			var l0 := Vector2(l0_3.x, l0_3.z)
			var r0 := Vector2(r0_3.x, r0_3.z)
			var l1 := Vector2(l1_3.x, l1_3.z)
			var r1 := Vector2(r1_3.x, r1_3.z)
			var mid0 := (l0 + r0) * 0.5
			var mid1 := (l1 + r1) * 0.5
			var steps := maxi(1, int(ceil(mid0.distance_to(mid1) / 0.4)))
			for s in range(1, steps + 1):
				var t := float(s) / float(steps)
				left_pts.append(l0.lerp(l1, t))
				right_pts.append(r0.lerp(r1, t))

		runs.append({"left": left_pts, "right": right_pts})

	return runs


static func _extract_bridge_abutments(scene_root: Node) -> Array[Dictionary]:
	var abutments: Array[Dictionary] = []
	if scene_root == null:
		return abutments

	var bridge_meshes := {}
	var bridge_statics := {}
	for child in scene_root.get_children():
		var lname := child.name.to_lower()
		if child is MeshInstance3D and lname.begins_with("cartbridge_") and not lname.begins_with("cartbridge_static_"):
			bridge_meshes[lname.substr(11)] = child
		elif child is StaticBody3D and lname.begins_with("cartbridge_static_"):
			bridge_statics[lname.substr(18)] = child

	var processed_suffixes := {}
	for suffix in bridge_meshes.keys():
		processed_suffixes[suffix] = true
		var bmi: MeshInstance3D = bridge_meshes[suffix]
		if bmi.has_meta("bridge_start") and bmi.has_meta("bridge_end") and bmi.has_meta("bridge_start_dir") and bmi.has_meta("bridge_end_dir"):
			var hw := float(bmi.get_meta("bridge_half_width", 1.25))
			var s_c: Vector2 = bmi.get_meta("bridge_start")
			var s_d: Vector2 = (bmi.get_meta("bridge_start_dir") as Vector2).normalized()
			if s_d.length_squared() > 0.5:
				var s_perp := Vector2(-s_d.y, s_d.x)
				abutments.append({
					"left": s_c - s_perp * hw,
					"right": s_c + s_perp * hw,
					"center": s_c,
					"inward_dir": s_d
				})
			var e_c: Vector2 = bmi.get_meta("bridge_end")
			var e_d: Vector2 = (bmi.get_meta("bridge_end_dir") as Vector2).normalized()
			if e_d.length_squared() > 0.5:
				var e_perp := Vector2(-e_d.y, e_d.x)
				abutments.append({
					"left": e_c - e_perp * hw,
					"right": e_c + e_perp * hw,
					"center": e_c,
					"inward_dir": e_d
				})
			continue

		var sb: StaticBody3D = bridge_statics.get(suffix, null) as StaticBody3D
		if sb != null:
			_append_abutments_from_bridge_static(sb, abutments)

	for suffix in bridge_statics.keys():
		if processed_suffixes.has(suffix):
			continue
		var sb: StaticBody3D = bridge_statics[suffix] as StaticBody3D
		if sb != null:
			_append_abutments_from_bridge_static(sb, abutments)

	return abutments


static func _append_abutments_from_bridge_static(sb: StaticBody3D, abutments: Array[Dictionary]) -> void:
	for sub in sb.get_children():
		if sub is CollisionShape3D and (sub as CollisionShape3D).shape is ConcavePolygonShape3D:
			var faces := ((sub as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
			if faces.size() < 6 or (faces.size() % 6) != 0:
				break
			var xform := (sb as Node3D).transform * (sub as Node3D).transform
			# Start quad vertices from CreateCartPathBridge: [aL, bL, aR, aR, bL, bR]
			var s0 := xform * faces[0]
			var s1 := xform * faces[1]
			var s2 := xform * faces[2]
			var s5 := xform * faces[5]
			var s_l := Vector2(s0.x, s0.z)
			var s_r := Vector2(s2.x, s2.z)
			var s_center := (s_l + s_r) * 0.5
			var s_next := (Vector2(s1.x, s1.z) + Vector2(s5.x, s5.z)) * 0.5
			var s_vec := s_next - s_center
			if s_l.distance_to(s_r) > 0.2 and s_vec.length_squared() > 0.0001:
				abutments.append({
					"left": s_l,
					"right": s_r,
					"center": s_center,
					"inward_dir": s_vec.normalized()
				})

			# End quad vertices: [aL_prev, bL_end, aR_prev, aR_prev, bL_end, bR_end]
			var last := faces.size() - 6
			var e0 := xform * faces[last]
			var e1 := xform * faces[last + 1]
			var e2 := xform * faces[last + 2]
			var e5 := xform * faces[last + 5]
			var e_l := Vector2(e1.x, e1.z)
			var e_r := Vector2(e5.x, e5.z)
			var e_center := (e_l + e_r) * 0.5
			var e_prev := (Vector2(e0.x, e0.z) + Vector2(e2.x, e2.z)) * 0.5
			var e_vec := e_prev - e_center
			if e_l.distance_to(e_r) > 0.2 and e_vec.length_squared() > 0.0001:
				abutments.append({
					"left": e_l,
					"right": e_r,
					"center": e_center,
					"inward_dir": e_vec.normalized()
				})
			break


static func _extend_run_endpoint(
	run: Dictionary,
	is_end: bool,
	t_left_in: Vector2,
	t_right_in: Vector2,
	tuck_dir: Vector2 = Vector2.ZERO,
	tuck_dist: float = 0.0
) -> void:
	var left_pts: PackedVector2Array = run["left"]
	var right_pts: PackedVector2Array = run["right"]
	var n := mini(left_pts.size(), right_pts.size())
	if n < 2:
		return

	var end_idx := n - 1 if is_end else 0
	var end_l := left_pts[end_idx]
	var end_r := right_pts[end_idx]
	var t_left := t_left_in
	var t_right := t_right_in
	if (end_r - end_l).dot(t_right - t_left) < 0.0:
		var swap := t_left
		t_left = t_right
		t_right = swap

	var span_d := maxf(end_l.distance_to(t_left), end_r.distance_to(t_right))
	var steps := maxi(1, int(ceil(span_d / 0.4))) if span_d > 0.05 else 0

	if is_end:
		for s in range(1, steps + 1):
			var frac := float(s) / float(steps)
			left_pts.append(end_l.lerp(t_left, frac))
			right_pts.append(end_r.lerp(t_right, frac))
		if tuck_dist > 0.01 and tuck_dir.length_squared() > 0.5:
			left_pts.append(t_left + tuck_dir * tuck_dist)
			right_pts.append(t_right + tuck_dir * tuck_dist)
		run["left"] = left_pts
		run["right"] = right_pts
	else:
		var new_l := PackedVector2Array()
		var new_r := PackedVector2Array()
		if tuck_dist > 0.01 and tuck_dir.length_squared() > 0.5:
			new_l.append(t_left + tuck_dir * tuck_dist)
			new_r.append(t_right + tuck_dir * tuck_dist)
		if steps > 0:
			new_l.append(t_left)
			new_r.append(t_right)
			for s in range(1, steps):
				var frac := float(s) / float(steps)
				new_l.append(t_left.lerp(end_l, frac))
				new_r.append(t_right.lerp(end_r, frac))
		elif tuck_dist > 0.01 and tuck_dir.length_squared() > 0.5:
			new_l.append(t_left)
			new_r.append(t_right)
		new_l.append_array(left_pts)
		new_r.append_array(right_pts)
		run["left"] = new_l
		run["right"] = new_r


static func _connect_cart_path_runs_to_bridges_and_gaps(
	cp_entries: Array,
	abutments: Array[Dictionary],
	water_entries: Array
) -> void:
	if cp_entries.is_empty():
		return

	var connected_ends := {}

	# Phase 1: Connect nearby cart path run endpoints seamlessly into wooden bridge abutments
	for ab in abutments:
		var ab_center: Vector2 = ab["center"]
		var ab_inward: Vector2 = ab["inward_dir"]
		var best_dist := 6.0
		var best_match := {}

		for cp_idx in range(cp_entries.size()):
			var runs: Array = cp_entries[cp_idx]["runs"]
			for run_idx in range(runs.size()):
				var run: Dictionary = runs[run_idx]
				var lp: PackedVector2Array = run["left"]
				var rp: PackedVector2Array = run["right"]
				var n := mini(lp.size(), rp.size())
				if n < 2:
					continue
				for end_flag in range(2):
					var is_end := end_flag == 1
					var end_key := "%d:%d:%d" % [cp_idx, run_idx, end_flag]
					if connected_ends.has(end_key):
						continue
					var ei := n - 1 if is_end else 0
					var pi := n - 2 if is_end else 1
					var end_mid := (lp[ei] + rp[ei]) * 0.5
					var prev_mid := (lp[pi] + rp[pi]) * 0.5
					var dist := end_mid.distance_to(ab_center)
					if dist > best_dist:
						continue
					var along_inward := ab_inward.dot(end_mid - ab_center)
					if along_inward > 1.2:
						continue
					if dist >= 0.8:
						var app_vec := end_mid - prev_mid
						if app_vec.length_squared() > 0.0001:
							var to_br := (ab_center - end_mid) / dist
							if app_vec.normalized().dot(to_br) <= -0.25:
								continue
					best_dist = dist
					best_match = {
						"cp_idx": cp_idx,
						"run_idx": run_idx,
						"is_end": is_end,
						"key": end_key,
						"along_inward": along_inward,
						"dist": dist
					}

		if not best_match.is_empty():
			connected_ends[best_match["key"]] = true
			var run: Dictionary = cp_entries[best_match["cp_idx"]]["runs"][best_match["run_idx"]]
			var already_tucked: bool = float(best_match["along_inward"]) >= 0.25 and float(best_match["dist"]) < 0.8
			if not already_tucked:
				_extend_run_endpoint(
					run,
					bool(best_match["is_end"]),
					ab["left"],
					ab["right"],
					ab_inward,
					0.40
				)

	# Phase 2: Stitch small dry-land gaps (0.15m..3.5m) between aligned dangling run endpoints
	var candidates: Array[Dictionary] = []
	for cp_idx in range(cp_entries.size()):
		var runs: Array = cp_entries[cp_idx]["runs"]
		for run_idx in range(runs.size()):
			var run: Dictionary = runs[run_idx]
			var lp: PackedVector2Array = run["left"]
			var rp: PackedVector2Array = run["right"]
			var n := mini(lp.size(), rp.size())
			if n < 2:
				continue
			for end_flag in range(2):
				var end_key := "%d:%d:%d" % [cp_idx, run_idx, end_flag]
				if connected_ends.has(end_key):
					continue
				var ei := n - 1 if end_flag == 1 else 0
				var pi := n - 2 if end_flag == 1 else 1
				var end_mid := (lp[ei] + rp[ei]) * 0.5
				var prev_mid := (lp[pi] + rp[pi]) * 0.5
				var out_vec := end_mid - prev_mid
				if out_vec.length_squared() < 0.0001:
					continue
				candidates.append({
					"cp_idx": cp_idx,
					"run_idx": run_idx,
					"is_end": end_flag == 1,
					"key": end_key,
					"mid": end_mid,
					"dir": out_vec.normalized(),
					"left": lp[ei],
					"right": rp[ei]
				})

	for a in range(candidates.size()):
		var ca: Dictionary = candidates[a]
		if connected_ends.has(ca["key"]):
			continue
		var best_b := -1
		var best_d := 3.5
		for b in range(a + 1, candidates.size()):
			var cb: Dictionary = candidates[b]
			if connected_ends.has(cb["key"]):
				continue
			if ca["cp_idx"] == cb["cp_idx"] and ca["run_idx"] == cb["run_idx"]:
				continue
			var d := (ca["mid"] as Vector2).distance_to(cb["mid"] as Vector2)
			if d < 0.15 or d > best_d:
				continue
			var across := ((cb["mid"] as Vector2) - (ca["mid"] as Vector2)) / d
			if (ca["dir"] as Vector2).dot(across) <= 0.45 or (cb["dir"] as Vector2).dot(-across) <= 0.45:
				continue
			var gap_mid := ((ca["mid"] as Vector2) + (cb["mid"] as Vector2)) * 0.5
			var in_water := false
			for w_entry in water_entries:
				var w_aabb: Rect2 = w_entry["aabb"]
				if w_aabb.has_point(gap_mid) and Geometry2D.is_point_in_polygon(gap_mid, w_entry["poly"]):
					in_water = true
					break
			if in_water:
				continue
			best_d = d
			best_b = b

		if best_b >= 0:
			var cb: Dictionary = candidates[best_b]
			connected_ends[ca["key"]] = true
			connected_ends[cb["key"]] = true
			var run_a: Dictionary = cp_entries[ca["cp_idx"]]["runs"][ca["run_idx"]]
			_extend_run_endpoint(run_a, bool(ca["is_end"]), cb["left"], cb["right"])


static func _build_cart_paths(scene_root: Node, height_info: Dictionary, persist_for_save: bool, force_rebuild: bool = false) -> bool:
	var base_y := float(height_info.get("avg_edge_y", 0.0))

	# 1. If scene already has cartpath MeshInstances (e.g. from OsmMapLoader), upgrade shader & optionally re-drape
	var existing_cartpaths: Array[MeshInstance3D] = []
	for child in scene_root.get_children():
		if child is MeshInstance3D and child.name.to_lower().begins_with("cartpath_") and not child.name.to_lower().begins_with("cartpath_static_"):
			existing_cartpaths.append(child as MeshInstance3D)

	if not existing_cartpaths.is_empty():
		var shader_res: Shader = null
		if ResourceLoader.exists("res://Courses/Environments/shaders/cart_path.gdshader"):
			shader_res = load("res://Courses/Environments/shaders/cart_path.gdshader") as Shader

		var static_by_lower_name := {}
		if force_rebuild:
			for child in scene_root.get_children():
				if child is StaticBody3D and child.name.to_lower().begins_with("cartpath_static_"):
					static_by_lower_name[child.name.to_lower()] = child

			var cp_entries: Array = []
			for cp_mi in existing_cartpaths:
				var mat: Material = cp_mi.get_surface_override_material(0)
				if mat == null and cp_mi.mesh != null and cp_mi.mesh.get_surface_count() > 0:
					mat = cp_mi.mesh.surface_get_material(0)
				var sm: ShaderMaterial = mat as ShaderMaterial
				if sm == null or sm.shader != shader_res:
					if shader_res != null:
						sm = ShaderMaterial.new()
						sm.shader = shader_res
						cp_mi.set_surface_override_material(0, sm)
						if cp_mi.mesh != null:
							cp_mi.mesh.surface_set_material(0, sm)
				if cp_mi.mesh is ArrayMesh and (cp_mi.mesh as ArrayMesh).get_surface_count() > 0:
					var am := cp_mi.mesh as ArrayMesh
					var extracted_runs := _extract_runs_from_existing_cart_path(am)
					if not extracted_runs.is_empty():
						cp_entries.append({ "cp_mi": cp_mi, "sm": sm, "runs": extracted_runs })

			if not cp_entries.is_empty():
				var abutments := _extract_bridge_abutments(scene_root)
				var water_entries: Array = _extract_course_features(scene_root).get("water", [])
				_connect_cart_path_runs_to_bridges_and_gaps(cp_entries, abutments, water_entries)
				for entry in cp_entries:
					var cp_mi: MeshInstance3D = entry["cp_mi"]
					var sm: ShaderMaterial = entry["sm"]
					var redraped := _build_5col_cart_path_mesh_from_runs(entry["runs"], height_info, base_y)
					if redraped != null:
						if sm != null:
							redraped.surface_set_material(0, sm)
						cp_mi.mesh = redraped
						var suffix := cp_mi.name.substr(9).to_lower()
						var static_body: StaticBody3D = static_by_lower_name.get("cartpath_static_" + suffix, null) as StaticBody3D
						_update_cart_path_collision(static_body, redraped)
				return true

		for cp_mi in existing_cartpaths:
			var mat: Material = cp_mi.get_surface_override_material(0)
			if mat == null and cp_mi.mesh != null and cp_mi.mesh.get_surface_count() > 0:
				mat = cp_mi.mesh.surface_get_material(0)
			var sm: ShaderMaterial = mat as ShaderMaterial
			if sm == null or sm.shader != shader_res:
				if shader_res != null:
					sm = ShaderMaterial.new()
					sm.shader = shader_res
					cp_mi.set_surface_override_material(0, sm)
					if cp_mi.mesh != null:
						cp_mi.mesh.surface_set_material(0, sm)

			if cp_mi.mesh is ArrayMesh:
				var am := cp_mi.mesh as ArrayMesh
				if force_rebuild and am.get_surface_count() > 0:
					var extracted_runs := _extract_runs_from_existing_cart_path(am)
					var redraped := _build_5col_cart_path_mesh_from_runs(extracted_runs, height_info, base_y)
					if redraped != null:
						if sm != null:
							redraped.surface_set_material(0, sm)
						cp_mi.mesh = redraped
						var suffix := cp_mi.name.substr(9).to_lower()
						var static_body: StaticBody3D = static_by_lower_name.get("cartpath_static_" + suffix, null) as StaticBody3D
						_update_cart_path_collision(static_body, redraped)
						continue

				if am.get_surface_count() > 0:
					var arrays := am.surface_get_arrays(0)
					var uvs = arrays[Mesh.ARRAY_TEX_UV]
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var needs_uvs := false
					if uvs == null or uvs.is_empty():
						needs_uvs = true
					elif uvs.size() >= 2 and uvs[0] == Vector2.ZERO and uvs[1] == Vector2.ZERO:
						needs_uvs = true

					if needs_uvs and verts.size() >= 4:
						var new_uvs := PackedVector2Array()
						new_uvs.resize(verts.size())
						var cum_dist := 0.0
						for vi in range(0, verts.size() - 1, 2):
							if vi >= 2:
								cum_dist += verts[vi].distance_to(verts[vi - 2])
							var v_coord := cum_dist * 0.25
							new_uvs[vi] = Vector2(0.0, v_coord)
							new_uvs[vi + 1] = Vector2(1.0, v_coord)
						arrays[Mesh.ARRAY_TEX_UV] = new_uvs
						var new_mesh := ArrayMesh.new()
						new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
						if sm != null:
							new_mesh.surface_set_material(0, sm)
						cp_mi.mesh = new_mesh
		return true

	if scene_root.get_node_or_null("CartPaths") != null:
		return false

	var polylines: Array = []
	if scene_root.has_meta("cart_path_polylines"):
		var meta_lines = scene_root.get_meta("cart_path_polylines")
		if meta_lines is Array:
			polylines = meta_lines.duplicate()

	if polylines.is_empty():
		polylines = _synthesize_hole_cart_paths(scene_root)

	if polylines.is_empty():
		return false

	var half_width := 1.1
	var runs: Array = []

	for raw_line in polylines:
		if not (raw_line is PackedVector2Array or raw_line is Array) or raw_line.size() < 2:
			continue
		var pts := PackedVector2Array()
		for p in raw_line:
			if p is Vector2:
				pts.append(p)
			elif p is Vector3:
				pts.append(Vector2(p.x, p.z))
		if pts.size() < 2:
			continue

		# Subdivide long segments tightly (0.4m) so ribbon drapes smoothly over terrain undulations without floating
		var dense := PackedVector2Array()
		dense.append(pts[0])
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var dist := a.distance_to(b)
			var steps := maxi(1, int(ceil(dist / 0.4)))
			for s in range(1, steps + 1):
				dense.append(a.lerp(b, float(s) / float(steps)))

		var left_pts := PackedVector2Array()
		var right_pts := PackedVector2Array()
		for i in range(dense.size()):
			var cur := dense[i]
			var tangent := Vector2.ZERO
			if i == 0:
				tangent = (dense[1] - dense[0]).normalized()
			elif i == dense.size() - 1:
				tangent = (dense[i] - dense[i - 1]).normalized()
			else:
				tangent = (dense[i + 1] - dense[i - 1]).normalized()
			if tangent.length_squared() < 0.001:
				tangent = Vector2(1.0, 0.0)
			var perp := Vector2(-tangent.y, tangent.x)
			left_pts.append(cur - perp * half_width)
			right_pts.append(cur + perp * half_width)

		runs.append({"left": left_pts, "right": right_pts})

	var path_mesh := _build_5col_cart_path_mesh_from_runs(runs, height_info, base_y)
	if path_mesh == null:
		return false

	if ResourceLoader.exists("res://Courses/Environments/shaders/cart_path.gdshader"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://Courses/Environments/shaders/cart_path.gdshader") as Shader
		path_mesh.surface_set_material(0, mat)

	var path_mi := MeshInstance3D.new()
	path_mi.name = "CartPaths"
	path_mi.mesh = path_mesh
	path_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path_mi.visibility_range_end = 420.0
	path_mi.visibility_range_end_margin = 35.0
	path_mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	scene_root.add_child(path_mi)
	if persist_for_save:
		path_mi.owner = scene_root

	# Ensure physics collision exists and matches the draped cart path mesh
	var cart_body: StaticBody3D = scene_root.get_node_or_null("CartPath_Static") as StaticBody3D
	if cart_body == null:
		for child in scene_root.find_children("*", "StaticBody3D", true, false):
			if child.has_meta("is_cart_path") or child.name.to_lower().contains("cartpath"):
				cart_body = child as StaticBody3D
				break
	if cart_body == null:
		cart_body = StaticBody3D.new()
		cart_body.name = "CartPath_Static"
		cart_body.set_meta("surface_type", 6) # PhysicsEnums.SurfaceType.CART_PATH
		cart_body.set_meta("is_cart_path", true)
		var col_shape := CollisionShape3D.new()
		cart_body.add_child(col_shape)
		scene_root.add_child(cart_body)
		if persist_for_save:
			cart_body.owner = scene_root
			col_shape.owner = scene_root
		_update_cart_path_collision(cart_body, path_mesh)
	elif force_rebuild:
		_update_cart_path_collision(cart_body, path_mesh)

	return true


static func _synthesize_hole_cart_paths(scene_root: Node) -> Array:
	var result: Array = []
	for child in scene_root.get_children():
		if not child.name.begins_with("Hole_"):
			continue
		var tee := child.get_node_or_null("TeeSpawn") as Node3D
		if tee == null:
			tee = child.get_node_or_null("Tee") as Node3D
		var target := child.get_node_or_null("TargetPoint") as Node3D
		if target == null:
			target = child.get_node_or_null("Flag") as Node3D
		if tee == null or target == null:
			continue

		var p0 := Vector2(tee.position.x, tee.position.z)
		var p1 := Vector2(target.position.x, target.position.z)
		var delta := p1 - p0
		var dist := delta.length()
		if dist < 45.0:
			continue
		var dir := delta / dist
		var side := Vector2(-dir.y, dir.x)

		# Gently curved cart path running alongside the tee box and first 65m of the hole corridor
		var path_pts := PackedVector2Array()
		var offset_sign := 1.0 if (child.get_index() % 2 == 0) else -1.0
		path_pts.append(p0 - dir * 6.0 + side * (8.5 * offset_sign))
		path_pts.append(p0 + side * (7.5 * offset_sign))
		path_pts.append(p0 + dir * minf(dist * 0.25, 35.0) + side * (11.5 * offset_sign))
		path_pts.append(p0 + dir * minf(dist * 0.55, 75.0) + side * (14.0 * offset_sign))
		result.append(path_pts)
	return result


# ==============================================================================
# THICK ROUGH SYSTEM (High Graphics Mode)
# Thick 3D fescue grass clusters and sporadic bushes in the rough beyond the
# mapped manicured rough, creating authentic coastal dune / deep rough vegetation.
# ==============================================================================

static func _build_thick_rough_grass(scene_root: Node, _height_info: Dictionary, _persist_for_save: bool) -> int:
	# Long 3D grass patches are disabled in favor of the elevated deep rough terrain shader texture
	# wherever ball lie resistance is 25% or more.
	if scene_root != null:
		var existing := scene_root.get_node_or_null("ThickRoughGrassMultiMesh")
		if existing != null:
			scene_root.remove_child(existing)
			if existing.is_inside_tree():
				existing.queue_free()
			else:
				existing.free()
	return 0


static func ensure_deep_rough_map(scene_root: Node, terrain_node: MeshInstance3D = null) -> Texture2D:
	if scene_root == null:
		return null
	var terrain := terrain_node
	if terrain == null:
		for tname in ["UnifiedTerrain", "DynamicGround", "RoughGround", "Terrain", "TerrainMesh"]:
			terrain = scene_root.find_child(tname, true, false) as MeshInstance3D
			if terrain != null and terrain.mesh != null and terrain.mesh.get_surface_count() > 0:
				break
	if terrain == null or terrain.mesh == null or terrain.mesh.get_surface_count() == 0:
		return null

	var deep_tex: Texture2D = null
	if terrain.has_meta("deep_rough_map"):
		deep_tex = terrain.get_meta("deep_rough_map") as Texture2D
	if deep_tex == null:
		deep_tex = _build_deep_rough_map(scene_root, terrain)
		if deep_tex != null:
			terrain.set_meta("deep_rough_map", deep_tex)

	if deep_tex != null:
		var mats: Array[ShaderMaterial] = []
		if terrain.material_override is ShaderMaterial:
			mats.append(terrain.material_override as ShaderMaterial)
		if terrain.get_surface_override_material(0) is ShaderMaterial:
			mats.append(terrain.get_surface_override_material(0) as ShaderMaterial)
		if terrain.mesh.surface_get_material(0) is ShaderMaterial:
			mats.append(terrain.mesh.surface_get_material(0) as ShaderMaterial)
		var is_high_graphics := true
		if ResourceLoader.exists("res://Utils/mobile_performance.gd"):
			var mp = load("res://Utils/mobile_performance.gd")
			if mp != null and mp.is_mobile():
				is_high_graphics = false
		if is_high_graphics and Engine.get_main_loop() is SceneTree:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null and tree.root != null and tree.root.has_node("GlobalSettings"):
				var gs = tree.root.get_node("GlobalSettings")
				if gs != null and gs.has_method("get_graphics_quality"):
					is_high_graphics = (gs.get_graphics_quality() == "High")

		for m in mats:
			m.set_shader_parameter("deep_rough_map", deep_tex)
			m.set_shader_parameter("has_deep_rough_map", is_high_graphics)
	return deep_tex


static func _build_deep_rough_map(scene_root: Node, terrain: MeshInstance3D) -> ImageTexture:
	var aabb := terrain.mesh.get_aabb()
	var t_gx: float = terrain.global_position.x if terrain.is_inside_tree() else terrain.position.x
	var t_gz: float = terrain.global_position.z if terrain.is_inside_tree() else terrain.position.z
	var min_x: float = t_gx + aabb.position.x
	var max_x: float = t_gx + aabb.position.x + aabb.size.x
	var min_z: float = t_gz + aabb.position.z
	var max_z: float = t_gz + aabb.position.z + aabb.size.z
	var width: float = maxf(max_x - min_x, 1.0)
	var depth: float = maxf(max_z - min_z, 1.0)

	var tex_size: int = 256
	var total_cells: int = tex_size * tex_size
	var dist_grid := PackedFloat32Array()
	dist_grid.resize(total_cells)
	dist_grid.fill(99999.0)

	var tee_mask := PackedByteArray()
	tee_mask.resize(total_cells)
	tee_mask.fill(0)

	var inv_w: float = float(tex_size - 1) / width
	var inv_d: float = float(tex_size - 1) / depth
	var step_x: float = width / float(tex_size - 1)
	var step_z: float = depth / float(tex_size - 1)

	var seeded_any := false

	# 1. Fast Path: If splat_map is available on terrain, seed directly from G (fairway) and R (green) channels
	var splat_tex: Texture2D = null
	var base_m: Material = terrain.mesh.surface_get_material(0)
	if base_m == null:
		base_m = terrain.material_override
	if base_m is ShaderMaterial:
		splat_tex = (base_m as ShaderMaterial).get_shader_parameter("splat_map") as Texture2D
	if splat_tex == null and terrain.has_meta("orig_splat_map"):
		splat_tex = terrain.get_meta("orig_splat_map") as Texture2D
	if splat_tex != null:
		var simg := splat_tex.get_image()
		if simg != null:
			if simg.is_compressed():
				simg = simg.duplicate()
				simg.decompress()
			var sw := simg.get_width()
			var sh := simg.get_height()
			for gz_idx in range(tex_size):
				var sy := clampi(int(round(float(gz_idx) / float(tex_size - 1) * float(sh - 1))), 0, sh - 1)
				for gx_idx in range(tex_size):
					var sx := clampi(int(round(float(gx_idx) / float(tex_size - 1) * float(sw - 1))), 0, sw - 1)
					var c := simg.get_pixel(sx, sy)
					if c.r > 0.40 or c.g > 0.40:
						dist_grid[gz_idx * tex_size + gx_idx] = 0.0
						seeded_any = true

	# 2. Mark tee boxes into tee_mask AND seed fairway/green static collision bodies
	# (Seeding static bodies guarantees distance grid matches physical ball lie calculation)
	for child in scene_root.find_children("*", "CollisionObject3D", true, false):
		var cname := child.name.to_lower()
		var st: int = int(child.get_meta("surface_type", -1))
		var is_wat: bool = bool(child.get_meta("is_water", false)) or cname.begins_with("water") or cname.contains("water")
		var is_sand: bool = (bool(child.get_meta("is_sand", false)) or st == 5 or cname.begins_with("bunker") or cname.contains("bunker")) and not is_wat
		if is_wat or is_sand:
			continue

		var is_green: bool = cname.begins_with("green_static") or cname.contains("green") or st == 4
		var is_tee: bool = (cname.begins_with("tee_static") or cname.contains("tee")) and not is_green
		var is_fairway: bool = (cname.begins_with("fairway_static") or cname.contains("fairway") or (st == 0 and not is_tee)) and not is_green and not is_tee
		if not is_green and not is_fairway and not is_tee:
			continue

		var child_xform: Transform3D = child.global_transform if child.is_inside_tree() else (child as Node3D).transform
		var has_concave := false

		for sub in child.get_children():
			if sub is CollisionShape3D and (sub as CollisionShape3D).shape is ConcavePolygonShape3D:
				var cs := sub as CollisionShape3D
				var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
				var full_xform: Transform3D = child_xform * cs.transform
				var face_count := faces.size()
				if face_count >= 3:
					has_concave = true
					for i in range(0, face_count - 2, 3):
						var va := full_xform * faces[i]
						var vb := full_xform * faces[i + 1]
						var vc := full_xform * faces[i + 2]
						var a := Vector2(va.x, va.z)
						var b := Vector2(vb.x, vb.z)
						var c := Vector2(vc.x, vc.z)
						if is_tee:
							_mark_triangle_on_mask(tee_mask, tex_size, min_x, min_z, inv_w, inv_d, a, b, c, 1)
						else:
							_seed_triangle_on_dist_grid(dist_grid, tex_size, min_x, min_z, step_x, step_z, inv_w, inv_d, a, b, c)
							seeded_any = true

		if not has_concave:
			var poly := PackedVector2Array()
			if child.has_meta("boundary_polygon"):
				var p_meta = child.get_meta("boundary_polygon")
				if p_meta is PackedVector2Array:
					for pt in p_meta:
						var wp := child_xform * Vector3(pt.x, 0.0, pt.y)
						poly.append(Vector2(wp.x, wp.z))
			if poly.size() < 3:
				for sub in child.get_children():
					if sub is CollisionPolygon3D and (sub as CollisionPolygon3D).polygon.size() >= 3:
						var cp := sub as CollisionPolygon3D
						for pt in cp.polygon:
							var wp := child_xform * (cp.transform * Vector3(pt.x, 0.0, pt.y))
							poly.append(Vector2(wp.x, wp.z))
						break
			if poly.size() >= 3:
				var tri_indices := Geometry2D.triangulate_polygon(poly)
				for i in range(0, tri_indices.size() - 2, 3):
					var a := poly[tri_indices[i]]
					var b := poly[tri_indices[i + 1]]
					var c := poly[tri_indices[i + 2]]
					if is_tee:
						_mark_triangle_on_mask(tee_mask, tex_size, min_x, min_z, inv_w, inv_d, a, b, c, 1)
					else:
						_seed_triangle_on_dist_grid(dist_grid, tex_size, min_x, min_z, step_x, step_z, inv_w, inv_d, a, b, c)
						seeded_any = true

	# Also mark cart paths into tee_mask so elevated deep rough never overlaps paths
	var cart_paths: Array = []
	if scene_root.has_meta("cart_path_polylines"):
		cart_paths = scene_root.get_meta("cart_path_polylines")
	else:
		cart_paths = _synthesize_hole_cart_paths(scene_root)
	for path in cart_paths:
		var pts: PackedVector2Array = path as PackedVector2Array
		for i in range(pts.size() - 1):
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var seg_len := p0.distance_to(p1)
			var steps := maxi(1, int(ceil(seg_len / 1.5)))
			for s in range(steps + 1):
				var p := p0.lerp(p1, float(s) / float(steps))
				var gx := clampi(int(round((p.x - min_x) * inv_w)), 0, tex_size - 1)
				var gz := clampi(int(round((p.y - min_z) * inv_d)), 0, tex_size - 1)
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx := clampi(gx + dx, 0, tex_size - 1)
						var nz := clampi(gz + dz, 0, tex_size - 1)
						tee_mask[nz * tex_size + nx] = 1

	# 2. Fast 2-pass Chamfer 5-7-11 Euclidean Distance Transform in world meters
	if seeded_any:
		var d_diag := sqrt(step_x * step_x + step_z * step_z)
		var d_kx := sqrt((2.0 * step_x) * (2.0 * step_x) + step_z * step_z)
		var d_kz := sqrt(step_x * step_x + (2.0 * step_z) * (2.0 * step_z))

		# Forward pass (top-left to bottom-right)
		for gz in range(tex_size):
			var row_off := gz * tex_size
			for gx in range(tex_size):
				var best: float = dist_grid[row_off + gx]
				if best <= 0.0:
					continue
				if gx > 0:
					best = minf(best, dist_grid[row_off + gx - 1] + step_x)
				if gz > 0:
					var prev_row := (gz - 1) * tex_size
					best = minf(best, dist_grid[prev_row + gx] + step_z)
					if gx > 0:
						best = minf(best, dist_grid[prev_row + gx - 1] + d_diag)
					if gx + 1 < tex_size:
						best = minf(best, dist_grid[prev_row + gx + 1] + d_diag)
					if gx > 1:
						best = minf(best, dist_grid[prev_row + gx - 2] + d_kx)
					if gx + 2 < tex_size:
						best = minf(best, dist_grid[prev_row + gx + 2] + d_kx)
				if gz > 1:
					var prev2_row := (gz - 2) * tex_size
					if gx > 0:
						best = minf(best, dist_grid[prev2_row + gx - 1] + d_kz)
					if gx + 1 < tex_size:
						best = minf(best, dist_grid[prev2_row + gx + 1] + d_kz)
				dist_grid[row_off + gx] = best

		# Backward pass (bottom-right to top-left)
		for gz in range(tex_size - 1, -1, -1):
			var row_off := gz * tex_size
			for gx in range(tex_size - 1, -1, -1):
				var best: float = dist_grid[row_off + gx]
				if best <= 0.0:
					continue
				if gx + 1 < tex_size:
					best = minf(best, dist_grid[row_off + gx + 1] + step_x)
				if gz + 1 < tex_size:
					var next_row := (gz + 1) * tex_size
					best = minf(best, dist_grid[next_row + gx] + step_z)
					if gx + 1 < tex_size:
						best = minf(best, dist_grid[next_row + gx + 1] + d_diag)
					if gx > 0:
						best = minf(best, dist_grid[next_row + gx - 1] + d_diag)
					if gx + 2 < tex_size:
						best = minf(best, dist_grid[next_row + gx + 2] + d_kx)
					if gx > 1:
						best = minf(best, dist_grid[next_row + gx - 2] + d_kx)
				if gz + 2 < tex_size:
					var next2_row := (gz + 2) * tex_size
					if gx + 1 < tex_size:
						best = minf(best, dist_grid[next2_row + gx + 1] + d_kz)
					if gx > 0:
						best = minf(best, dist_grid[next2_row + gx - 1] + d_kz)
				dist_grid[row_off + gx] = best

	# 3. Encode >= 25% ball lie resistance mask:
	# In range.gd: reduction = 0.10 + 0.20 * clampf(d / 50.0, 0.0, 1.0)
	# reduction >= 0.25 occurs where d = min(d_fairway, d_green) >= 37.5 meters.
	var pixels := PackedByteArray()
	pixels.resize(total_cells)
	for idx in range(total_cells):
		if tee_mask[idx] != 0:
			pixels[idx] = 0
			continue
		var d: float = dist_grid[idx]
		var w: float = smoothstep(20.0, 37.5, d)
		pixels[idx] = int(clampf(round(w * 255.0), 0.0, 255.0))

	var img := Image.create_from_data(tex_size, tex_size, false, Image.FORMAT_L8, pixels)
	terrain.set_meta("deep_rough_image", img)
	if scene_root != null:
		scene_root.set_meta("deep_rough_image", img)
	return ImageTexture.create_from_image(img)


static func _seed_triangle_on_dist_grid(
	dist_grid: PackedFloat32Array,
	tex_size: int,
	min_x: float,
	min_z: float,
	step_x: float,
	step_z: float,
	inv_w: float,
	inv_d: float,
	a: Vector2,
	b: Vector2,
	c: Vector2
) -> void:
	var gax := (a.x - min_x) * inv_w
	var gaz := (a.y - min_z) * inv_d
	var gbx := (b.x - min_x) * inv_w
	var gbz := (b.y - min_z) * inv_d
	var gcx := (c.x - min_x) * inv_w
	var gcz := (c.y - min_z) * inv_d

	var x0 := clampi(int(floor(minf(gax, minf(gbx, gcx)))), 0, tex_size - 1)
	var x1 := clampi(int(ceil(maxf(gax, maxf(gbx, gcx)))), 0, tex_size - 1)
	var z0 := clampi(int(floor(minf(gaz, minf(gbz, gcz)))), 0, tex_size - 1)
	var z1 := clampi(int(ceil(maxf(gaz, maxf(gbz, gcz)))), 0, tex_size - 1)

	dist_grid[clampi(int(round(gaz)), 0, tex_size - 1) * tex_size + clampi(int(round(gax)), 0, tex_size - 1)] = 0.0
	dist_grid[clampi(int(round(gbz)), 0, tex_size - 1) * tex_size + clampi(int(round(gbx)), 0, tex_size - 1)] = 0.0
	dist_grid[clampi(int(round(gcz)), 0, tex_size - 1) * tex_size + clampi(int(round(gcx)), 0, tex_size - 1)] = 0.0

	for gz in range(z0, z1 + 1):
		var wz := min_z + float(gz) * step_z
		var row_off := gz * tex_size
		for gx in range(x0, x1 + 1):
			if dist_grid[row_off + gx] <= 0.0:
				continue
			var wx := min_x + float(gx) * step_x
			if Geometry2D.point_is_inside_triangle(Vector2(wx, wz), a, b, c):
				dist_grid[row_off + gx] = 0.0


static func _mark_triangle_on_mask(
	mask: PackedByteArray,
	tex_size: int,
	min_x: float,
	min_z: float,
	inv_w: float,
	inv_d: float,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	pad_cells: int
) -> void:
	var gax := (a.x - min_x) * inv_w
	var gaz := (a.y - min_z) * inv_d
	var gbx := (b.x - min_x) * inv_w
	var gbz := (b.y - min_z) * inv_d
	var gcx := (c.x - min_x) * inv_w
	var gcz := (c.y - min_z) * inv_d

	var x0 := clampi(int(floor(minf(gax, minf(gbx, gcx)))) - pad_cells, 0, tex_size - 1)
	var x1 := clampi(int(ceil(maxf(gax, maxf(gbx, gcx)))) + pad_cells, 0, tex_size - 1)
	var z0 := clampi(int(floor(minf(gaz, minf(gbz, gcz)))) - pad_cells, 0, tex_size - 1)
	var z1 := clampi(int(ceil(maxf(gaz, maxf(gbz, gcz)))) + pad_cells, 0, tex_size - 1)

	for gz in range(z0, z1 + 1):
		var row_off := gz * tex_size
		for gx in range(x0, x1 + 1):
			mask[row_off + gx] = 1


static func _build_thick_rough_bushes(scene_root: Node, height_info: Dictionary, persist_for_save: bool) -> int:
	if scene_root.get_node_or_null("ThickRoughBushes") != null:
		return 0

	var features := _extract_course_features(scene_root)
	var min_x: float = height_info.get("min_x", -300.0) + 10.0
	var max_x: float = height_info.get("max_x", 300.0) - 10.0
	var min_z: float = height_info.get("min_z", -300.0) + 10.0
	var max_z: float = height_info.get("max_z", 300.0) - 10.0

	var bush_mesh_paths := [
		"res://addons/shapespark-low-poly-exterior-plants/meshes/bush-01-mesh.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/meshes/bush-02-mesh.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/meshes/bush-03-mesh.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/meshes/bush-04-mesh.tscn",
		"res://addons/shapespark-low-poly-exterior-plants/meshes/bush-05-mesh.tscn"
	]

	var bush_meshes: Array[Mesh] = []
	for bp in bush_mesh_paths:
		if ResourceLoader.exists(bp):
			var pscn := load(bp) as PackedScene
			if pscn != null:
				var inst = pscn.instantiate()
				if inst != null:
					var mi: MeshInstance3D = null
					if inst is MeshInstance3D and inst.mesh != null:
						mi = inst
					else:
						for ch in inst.get_children():
							if ch is MeshInstance3D and ch.mesh != null:
								mi = ch
								break
					if mi != null and mi.mesh != null:
						bush_meshes.append(mi.mesh.duplicate())
					inst.free()

	if bush_meshes.is_empty():
		return 0

	var placed_bushes: Array[Vector2] = []
	var bush_type_xforms: Array[Array] = []
	for m in range(bush_meshes.size()):
		bush_type_xforms.append([])

	var rng := RandomNumberGenerator.new()
	rng.seed = 882244

	var tree_positions: Array = features.get("tree_positions", [])
	var min_bush_dist_sq := 1.5 * 1.5

	# Cluster bushes around trees (1 to 3 bushes per tree) in thick rough
	for tree_pos_val in tree_positions:
		var tp: Vector2 = tree_pos_val if tree_pos_val is Vector2 else Vector2(tree_pos_val[0], tree_pos_val[1])
		var num_bushes := rng.randi_range(1, 3)
		for _b in range(num_bushes):
			var dist := rng.randf_range(1.6, 3.5)
			var angle := rng.randf_range(0.0, TAU)
			var pt := tp + Vector2(cos(angle), sin(angle)) * dist

			if _is_point_in_thick_rough(pt, features, height_info, 12.0, 10.0) and not _is_point_between_tee_and_fairway(pt, features):
				var too_close := false
				for pb in placed_bushes:
					if pb.distance_squared_to(pt) < min_bush_dist_sq:
						too_close = true
						break
				if not too_close:
					placed_bushes.append(pt)
					var wy := _sample_height(pt.x, pt.y, height_info)
					var rot_y := rng.randf_range(0.0, TAU)
					var s := rng.randf_range(1.15, 2.25)
					var xf := Transform3D(Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s)), Vector3(pt.x, wy, pt.y))
					var type_idx := rng.randi() % bush_meshes.size()
					bush_type_xforms[type_idx].append(xf)

	var total_placed := placed_bushes.size()
	if total_placed == 0:
		return 0

	var container := Node3D.new()
	container.name = "ThickRoughBushes"
	var is_high_bushes := true
	if ResourceLoader.exists("res://Utils/mobile_performance.gd"):
		var mp = load("res://Utils/mobile_performance.gd")
		if mp != null and mp.is_mobile():
			is_high_bushes = false
	if is_high_bushes and Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null and tree.root.has_node("GlobalSettings"):
			var gs = tree.root.get_node("GlobalSettings")
			if gs != null and gs.has_method("get_graphics_quality"):
				is_high_bushes = (gs.get_graphics_quality() == "High")
	container.visible = is_high_bushes
	scene_root.add_child(container)
	if persist_for_save:
		container.owner = scene_root

	for t_idx in range(bush_meshes.size()):
		var xforms: Array = bush_type_xforms[t_idx]
		if xforms.is_empty():
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = false
		mm.mesh = bush_meshes[t_idx]
		mm.instance_count = xforms.size()

		var b_buf := PackedFloat32Array()
		b_buf.resize(xforms.size() * 12)
		for i in range(xforms.size()):
			var xf: Transform3D = xforms[i]
			var b_idx := i * 12
			b_buf[b_idx + 0] = xf.basis.x.x
			b_buf[b_idx + 1] = xf.basis.y.x
			b_buf[b_idx + 2] = xf.basis.z.x
			b_buf[b_idx + 3] = xf.origin.x
			b_buf[b_idx + 4] = xf.basis.x.y
			b_buf[b_idx + 5] = xf.basis.y.y
			b_buf[b_idx + 6] = xf.basis.y.z
			b_buf[b_idx + 7] = xf.origin.y
			b_buf[b_idx + 8] = xf.basis.x.z
			b_buf[b_idx + 9] = xf.basis.y.z
			b_buf[b_idx + 10] = xf.basis.z.z
			b_buf[b_idx + 11] = xf.origin.z
			mm.set_instance_transform(i, xf)
		mm.buffer = b_buf

		var mmi := MultiMeshInstance3D.new()
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mmi.name = "ThickRoughBushMesh_%d" % t_idx
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 260.0
		mmi.visibility_range_end_margin = 35.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		container.add_child(mmi)
		if persist_for_save:
			mmi.owner = scene_root

	return total_placed


static func _extract_course_features(scene_root: Node) -> Dictionary:
	var features := {
		"fairways": [],
		"greens": [],
		"tees": [],
		"bunkers": [],
		"water": [],
		"mapped_rough": [],
		"cart_paths": [],
		"roads": [],
		"buildings": [],
		"driving_ranges": [],
		"hole_lines": [],
		"hole_paths": [],
		"tree_positions": []
	}

	for child in scene_root.find_children("*", "CollisionObject3D", true, false):
		var cname := child.name.to_lower()
		if bool(child.get_meta("is_road", false)) or cname.begins_with("road_") or cname.begins_with("cartpath"):
			continue
		var poly := PackedVector2Array()

		if child.has_meta("boundary_polygon"):
			var p_meta = child.get_meta("boundary_polygon")
			if p_meta is PackedVector2Array:
				poly = p_meta
			elif p_meta is Array:
				for p in p_meta:
					if p is Vector2:
						poly.append(p)
			if poly.size() >= 3:
				var world_poly := PackedVector2Array()
				var child_xform: Transform3D = (child as Node3D).transform
				for pt in poly:
					var wp := child_xform * Vector3(pt.x, 0.0, pt.y)
					world_poly.append(Vector2(wp.x, wp.z))
				poly = world_poly

		if poly.size() < 3:
			for sub in child.get_children():
				if sub is CollisionPolygon3D and (sub as CollisionPolygon3D).polygon.size() >= 3:
					var cp := sub as CollisionPolygon3D
					var world_poly := PackedVector2Array()
					for pt in cp.polygon:
						var wp := (child as Node3D).transform * (cp.transform * Vector3(pt.x, 0.0, pt.y))
						world_poly.append(Vector2(wp.x, wp.z))
					poly = world_poly
					break
				elif sub is CollisionShape3D and (sub as CollisionShape3D).shape != null:
					var cs := sub as CollisionShape3D
					if cs.shape is ConcavePolygonShape3D:
						var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
						var boundary := _extract_boundary_polygon_from_faces(faces, (child as Node3D).transform * cs.transform)
						if boundary.size() >= 3:
							poly = boundary
							break

		if poly.size() >= 3:
			var min_p := poly[0]
			var max_p := poly[0]
			for p in poly:
				min_p.x = minf(min_p.x, p.x)
				min_p.y = minf(min_p.y, p.y)
				max_p.x = maxf(max_p.x, p.x)
				max_p.y = maxf(max_p.y, p.y)
			var aabb := Rect2(min_p, max_p - min_p)
			var entry := { "poly": poly, "aabb": aabb }

			var st: int = int(child.get_meta("surface_type", -1))
			var is_sand: bool = bool(child.get_meta("is_sand", false))
			var is_wat: bool = bool(child.get_meta("is_water", false))
			var is_bld: bool = bool(child.get_meta("is_building", false))

			if is_bld or cname.begins_with("clubhouse_") or cname.begins_with("building_") or cname.begins_with("house_"):
				features["buildings"].append(entry)
			elif is_wat or cname.begins_with("water") or cname.contains("water"):
				features["water"].append(entry)
			elif is_sand or st == 5 or cname.begins_with("bunker") or cname.contains("bunker"):
				features["bunkers"].append(entry)
			elif st == 4 or cname.begins_with("green") or cname.contains("green"):
				features["greens"].append(entry)
			elif cname.begins_with("tee") or cname.contains("teebox"):
				features["tees"].append(entry)
			elif st == 0 or cname.begins_with("fairway") or cname.contains("fairway"):
				features["fairways"].append(entry)
			elif cname.begins_with("rough_") or bool(child.get_meta("is_mapped_rough", false)):
				features["mapped_rough"].append(entry)

	# Water meshes
	for child in scene_root.get_children():
		if child is MeshInstance3D and child.name.to_lower().begins_with("water"):
			var mi := child as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var arrays := mi.mesh.surface_get_arrays(0)
				if arrays.size() > Mesh.ARRAY_VERTEX:
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					if verts.size() >= 3:
						var poly := PackedVector2Array()
						var min_p := Vector2(verts[0].x, verts[0].z)
						var max_p := min_p
						for v in verts:
							var p := Vector2(v.x, v.z)
							poly.append(p)
							min_p.x = minf(min_p.x, p.x)
							min_p.y = minf(min_p.y, p.y)
							max_p.x = maxf(max_p.x, p.x)
							max_p.y = maxf(max_p.y, p.y)
						features["water"].append({ "poly": poly, "aabb": Rect2(min_p, max_p - min_p) })

	# Cart paths
	if scene_root.has_meta("cart_path_polylines"):
		features["cart_paths"] = scene_root.get_meta("cart_path_polylines")
	else:
		features["cart_paths"] = _synthesize_hole_cart_paths(scene_root)

	# Concrete roads, buildings/yards, and driving ranges
	if scene_root.has_meta("road_polylines"):
		var r_meta = scene_root.get_meta("road_polylines")
		if r_meta is Array:
			features["roads"] = r_meta

	if scene_root.has_meta("building_polygons"):
		var b_meta = scene_root.get_meta("building_polygons")
		if b_meta is Array:
			for b_poly in b_meta:
				if b_poly is PackedVector2Array and b_poly.size() >= 3:
					var min_p: Vector2 = b_poly[0]
					var max_p: Vector2 = b_poly[0]
					for p in b_poly:
						min_p.x = minf(min_p.x, p.x)
						min_p.y = minf(min_p.y, p.y)
						max_p.x = maxf(max_p.x, p.x)
						max_p.y = maxf(max_p.y, p.y)
					features["buildings"].append({ "poly": b_poly, "aabb": Rect2(min_p, max_p - min_p) })

	if scene_root.has_meta("driving_range_polygons"):
		var dr_meta = scene_root.get_meta("driving_range_polygons")
		if dr_meta is Array:
			for dr_poly in dr_meta:
				if dr_poly is PackedVector2Array and dr_poly.size() >= 3:
					var min_p: Vector2 = dr_poly[0]
					var max_p: Vector2 = dr_poly[0]
					for p in dr_poly:
						min_p.x = minf(min_p.x, p.x)
						min_p.y = minf(min_p.y, p.y)
						max_p.x = maxf(max_p.x, p.x)
						max_p.y = maxf(max_p.y, p.y)
					features["driving_ranges"].append({ "poly": dr_poly, "aabb": Rect2(min_p, max_p - min_p) })

	# Hole lines and line-of-play paths
	if scene_root.has_meta("hole_paths"):
		var hpaths = scene_root.get_meta("hole_paths")
		if hpaths is Array:
			for p in hpaths:
				var pts: Array[Vector2] = []
				if p is PackedVector2Array:
					for pt in p: pts.append(pt)
				elif p is Array:
					for pt in p:
						if pt is Vector2: pts.append(pt)
						elif pt is Array and pt.size() >= 2: pts.append(Vector2(pt[0], pt[1]))
				if pts.size() >= 2:
					features["hole_paths"].append(pts)
					features["hole_lines"].append({ "p0": pts[0], "p1": pts[-1], "dist": pts[0].distance_to(pts[-1]) })

	# Also check course.json if present on course manager or adjacent to scene file
	if features["hole_paths"].is_empty():
		var json_path := ""
		if scene_root.is_inside_tree():
			var course_mgr := scene_root.get_node_or_null("/root/CourseManager")
			if course_mgr != null and course_mgr.has_method("get_current_config_path"):
				json_path = course_mgr.get_current_config_path()
		if json_path.is_empty() and scene_root.scene_file_path != "":
			json_path = scene_root.scene_file_path.get_base_dir() + "/course.json"
		if not json_path.is_empty() and FileAccess.file_exists(json_path):
			var f := FileAccess.open(json_path, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary and parsed.has("Hole Info"):
					var hole_info_dict: Dictionary = parsed["Hole Info"]
					for hk in hole_info_dict.keys():
						var hd = hole_info_dict[hk]
						if hd is Dictionary and hd.has("Hole Path"):
							var hp_arr = hd["Hole Path"]
							if hp_arr is Array and hp_arr.size() >= 2:
								var pts: Array[Vector2] = []
								for pt_val in hp_arr:
									if pt_val is Array and pt_val.size() >= 2:
										pts.append(Vector2(float(pt_val[0]), float(pt_val[1])))
								if pts.size() >= 2:
									features["hole_paths"].append(pts)
									features["hole_lines"].append({ "p0": pts[0], "p1": pts[-1], "dist": pts[0].distance_to(pts[-1]) })

	for child in scene_root.get_children():
		if child.name.begins_with("Hole_"):
			var tee := child.get_node_or_null("TeeSpawn") as Node3D
			if tee == null: tee = child.get_node_or_null("Tee") as Node3D
			var target := child.get_node_or_null("TargetPoint") as Node3D
			if target == null: target = child.get_node_or_null("Flag") as Node3D
			if tee != null and target != null:
				var p0 := Vector2(tee.position.x, tee.position.z)
				var p1 := Vector2(target.position.x, target.position.z)
				features["hole_lines"].append({ "p0": p0, "p1": p1, "dist": p0.distance_to(p1) })
				features["hole_paths"].append([p0, p1])

	# Tree positions
	var mm_container := scene_root.get_node_or_null("MultiMeshFoliageContainer")
	if mm_container != null and mm_container.has_meta("tree_records"):
		var records: Array = mm_container.get_meta("tree_records", [])
		for i in range(0, records.size(), 8):
			features["tree_positions"].append(Vector2(float(records[i]), float(records[i + 2])))
	else:
		for child in scene_root.find_children("Tree_*", "Node3D", true, false):
			features["tree_positions"].append(Vector2(child.position.x, child.position.z))

	return features


static func _is_point_in_thick_rough(pt: Vector2, features: Dictionary, height_info: Dictionary, fairway_buffer: float = 6.5, green_buffer: float = 7.5) -> bool:
	var min_x: float = height_info.get("min_x", -300.0)
	var max_x: float = height_info.get("max_x", 300.0)
	var min_z: float = height_info.get("min_z", -300.0)
	var max_z: float = height_info.get("max_z", 300.0)

	if pt.x < min_x + 4.0 or pt.x > max_x - 4.0 or pt.y < min_z + 4.0 or pt.y > max_z - 4.0:
		return false

	# Fairway buffer: must be outside fairway and beyond mapped fairway rough corridor
	for f in features.get("fairways", []):
		var aabb: Rect2 = f["aabb"]
		if pt.x >= aabb.position.x - fairway_buffer and pt.x <= aabb.end.x + fairway_buffer and \
		   pt.y >= aabb.position.y - fairway_buffer and pt.y <= aabb.end.y + fairway_buffer:
			if _distance_to_polygon_2d(pt, f["poly"]) < fairway_buffer:
				return false

	# Green buffer: must be outside green and beyond manicured green fringe/rough
	for g in features.get("greens", []):
		var aabb: Rect2 = g["aabb"]
		if pt.x >= aabb.position.x - green_buffer and pt.x <= aabb.end.x + green_buffer and \
		   pt.y >= aabb.position.y - green_buffer and pt.y <= aabb.end.y + green_buffer:
			if _distance_to_polygon_2d(pt, g["poly"]) < green_buffer:
				return false

	# Tee buffer
	var tee_buffer := 5.0
	for t in features.get("tees", []):
		var aabb: Rect2 = t["aabb"]
		if pt.x >= aabb.position.x - tee_buffer and pt.x <= aabb.end.x + tee_buffer and \
		   pt.y >= aabb.position.y - tee_buffer and pt.y <= aabb.end.y + tee_buffer:
			if _distance_to_polygon_2d(pt, t["poly"]) < tee_buffer:
				return false

	# Bunker buffer
	var bunker_buffer := 1.8
	for b in features.get("bunkers", []):
		var aabb: Rect2 = b["aabb"]
		if pt.x >= aabb.position.x - bunker_buffer and pt.x <= aabb.end.x + bunker_buffer and \
		   pt.y >= aabb.position.y - bunker_buffer and pt.y <= aabb.end.y + bunker_buffer:
			if _distance_to_polygon_2d(pt, b["poly"]) < bunker_buffer:
				return false

	# Water buffer
	var water_buffer := 2.0
	for w in features.get("water", []):
		var aabb: Rect2 = w["aabb"]
		if pt.x >= aabb.position.x - water_buffer and pt.x <= aabb.end.x + water_buffer and \
		   pt.y >= aabb.position.y - water_buffer and pt.y <= aabb.end.y + water_buffer:
			if _distance_to_polygon_2d(pt, w["poly"]) < water_buffer:
				return false

	# Explicit mapped rough exclusion: if explicit rough was mapped in OSM, thick rough is beyond it
	for mr in features.get("mapped_rough", []):
		var aabb: Rect2 = mr["aabb"]
		if pt.x >= aabb.position.x and pt.x <= aabb.end.x and pt.y >= aabb.position.y and pt.y <= aabb.end.y:
			if Geometry2D.is_point_in_polygon(pt, mr["poly"]):
				return false

	# Cart paths
	var path_buffer_sq := 2.5 * 2.5
	for path in features.get("cart_paths", []):
		var pts: PackedVector2Array = path as PackedVector2Array
		for i in range(pts.size() - 1):
			if _distance_squared_to_segment_2d(pt, pts[i], pts[i + 1]) < path_buffer_sq:
				return false

	# Concrete roads
	var road_buffer_sq := 6.5 * 6.5
	for r_path in features.get("roads", []):
		var r_pts: PackedVector2Array = r_path as PackedVector2Array
		for i in range(r_pts.size() - 1):
			if _distance_squared_to_segment_2d(pt, r_pts[i], r_pts[i + 1]) < road_buffer_sq:
				return false

	# Buildings, clubhouses, and house backyards/patios
	var bld_buffer := 3.0
	for bld in features.get("buildings", []):
		var aabb: Rect2 = bld["aabb"]
		if pt.x >= aabb.position.x - bld_buffer and pt.x <= aabb.end.x + bld_buffer and \
		   pt.y >= aabb.position.y - bld_buffer and pt.y <= aabb.end.y + bld_buffer:
			if _distance_to_polygon_2d(pt, bld["poly"]) < bld_buffer:
				return false

	# Driving ranges (keep as open grass, no thick rough bushes)
	var dr_buffer := 2.0
	for dr in features.get("driving_ranges", []):
		var aabb: Rect2 = dr["aabb"]
		if pt.x >= aabb.position.x - dr_buffer and pt.x <= aabb.end.x + dr_buffer and \
		   pt.y >= aabb.position.y - dr_buffer and pt.y <= aabb.end.y + dr_buffer:
			if _distance_to_polygon_2d(pt, dr["poly"]) < dr_buffer:
				return false

	# Fallback hole corridor check if no fairways were detected in scene
	if (features.get("fairways", []) as Array).is_empty():
		for hl in features.get("hole_lines", []):
			if _distance_squared_to_segment_2d(pt, hl["p0"], hl["p1"]) < (9.0 * 9.0):
				return false

	return true


static func _edge_distance_to_polygon_2d(pt: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 99999.0
	var min_d_sq := 99999999.0
	var n := poly.size()
	for i in range(n):
		var p1 := poly[i]
		var p2 := poly[(i + 1) % n]
		var d_sq := _distance_squared_to_segment_2d(pt, p1, p2)
		if d_sq < min_d_sq:
			min_d_sq = d_sq
	return sqrt(min_d_sq)


static func _distance_to_polygon_2d(pt: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 99999.0
	if Geometry2D.is_point_in_polygon(pt, poly):
		return 0.0
	return _edge_distance_to_polygon_2d(pt, poly)


static func _distance_squared_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.0001:
		return p.distance_squared_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_squared_to(proj)


static func _is_point_between_tee_and_fairway(pt: Vector2, features: Dictionary, corridor_half_width: float = 18.0, min_tee_front_dist: float = 35.0) -> bool:
	# Check against all hole lines / drive corridors
	for hl in features.get("hole_lines", []):
		var p0: Vector2 = hl.get("p0", Vector2.ZERO)
		var p1: Vector2 = hl.get("p1", Vector2.ZERO)
		if _is_point_in_drive_corridor(pt, p0, p1, corridor_half_width, min_tee_front_dist):
			return true

	# Also check hole paths segments starting from tee
	for path in features.get("hole_paths", []):
		if path is Array and path.size() >= 2:
			var p0: Vector2 = path[0] if path[0] is Vector2 else Vector2(path[0][0], path[0][1])
			var p1: Vector2 = path[1] if path[1] is Vector2 else Vector2(path[1][0], path[1][1])
			if _is_point_in_drive_corridor(pt, p0, p1, corridor_half_width, min_tee_front_dist):
				return true

	# Also check proximity to any tee polygon boundary with a buffer
	var tee_front_buffer := 15.0
	for t in features.get("tees", []):
		var aabb: Rect2 = t["aabb"]
		if pt.x >= aabb.position.x - tee_front_buffer and pt.x <= aabb.end.x + tee_front_buffer and \
		   pt.y >= aabb.position.y - tee_front_buffer and pt.y <= aabb.end.y + tee_front_buffer:
			if _distance_to_polygon_2d(pt, t["poly"]) < tee_front_buffer:
				return true

	return false


static func _is_point_in_drive_corridor(pt: Vector2, tee_pos: Vector2, fairway_target: Vector2, corridor_half_width: float = 18.0, min_tee_front_dist: float = 35.0) -> bool:
	var to_target := fairway_target - tee_pos
	var total_dist := to_target.length()
	if total_dist < 0.001:
		return false

	var drive_dir := to_target / total_dist
	var to_pt := pt - tee_pos
	var forward_proj := to_pt.dot(drive_dir)

	# If behind or at tee box, not in front flight corridor
	if forward_proj <= 0.0:
		return false

	# If beyond fairway target
	if forward_proj > total_dist:
		return false

	# Perpendicular distance to drive axis
	var perp_dist := absf(to_pt.x * drive_dir.y - to_pt.y * drive_dir.x)
	if perp_dist < corridor_half_width:
		return true

	# Direct obstruction in front cone of tee (< min_tee_front_dist, within ~70 deg forward cone)
	var pt_dist := to_pt.length()
	if pt_dist < min_tee_front_dist and pt_dist > 0.001:
		var cos_angle := forward_proj / pt_dist
		if cos_angle > 0.34:
			return true

	return false

