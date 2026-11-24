class_name FlagBuilder
extends RefCounted

## FlagBuilder
## Static factory and helper for creating and managing golf pin flags, flagpoles,
## and realistic wind-waving cloth flags across all courses and minigames.

const GOLF_FLAG_SCRIPT := "res://Courses/Range/golf_flag.gd"
const CUP_DEPTH := 0.108       # 4.25 in regulation hole cup depth (m)
const CUP_SOIL_DEPTH := 0.024  # ~1 in USGA turf/root-zone soil collar above white cup liner (m)
const CUP_LINER_HEIGHT := 0.084 # White cup sleeve height from -0.024m down to -0.108m


## Builds a standard regulation golf hole pin with pole, collider, realistic flag, and recessed 3D physical cup
static func build_flag_pin(
	pin: Node3D,
	pole_height: float = 3.0,
	flag_color: Color = Color(0.95, 0.12, 0.12),
	cup_radius: float = 0.054,
	quality: String = ""
) -> Node3D:
	if pin == null:
		pin = Node3D.new()
	pin.name = "FlagPin"
	pin.set_meta("cup_radius", cup_radius)

	var bottom_ext := (CUP_DEPTH - 0.002) if cup_radius > 0.0 else 0.0

	# 1. Flagpole (slender tournament fiberglass cylinder extending down into the bottom cup ferrule)
	var pole = pin.get_node_or_null("Pole") as MeshInstance3D
	if pole == null:
		pole = MeshInstance3D.new()
		pole.name = "Pole"
		pin.add_child(pole)
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.012
	pole_mesh.bottom_radius = 0.009 if cup_radius > 0.0 else 0.012
	pole_mesh.height = pole_height + bottom_ext
	pole.mesh = pole_mesh
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color.WHITE
	pole_mat.roughness = 0.25 # Clean glossy tournament finish
	pole.material_override = pole_mat
	pole.position = Vector3(0.0, (pole_height - bottom_ext) * 0.5, 0.0)

	# 2. Flagpole 3D collider (typical collision, disabled when putting)
	var flag_body = pin.get_node_or_null("FlagstickCollider") as StaticBody3D
	if flag_body == null:
		flag_body = StaticBody3D.new()
		flag_body.name = "FlagstickCollider"
		pin.add_child(flag_body)
	flag_body.set_meta("is_flagstick", true)
	flag_body.set_meta("is_obstacle", true)
	flag_body.collision_layer = 1
	flag_body.collision_mask = 0

	var col_shape = flag_body.get_node_or_null("CollisionShape") as CollisionShape3D
	if col_shape == null:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape"
		flag_body.add_child(col_shape)
	var cyl = CylinderShape3D.new()
	cyl.radius = 0.012
	cyl.height = pole_height
	col_shape.shape = cyl
	col_shape.position = Vector3(0.0, pole_height * 0.5, 0.0)

	# 3. Dynamic Golf Flag (MeshInstance3D with GolfFlag script)
	var flag = pin.get_node_or_null("Flag") as MeshInstance3D
	if flag == null:
		flag = MeshInstance3D.new()
		flag.name = "Flag"
		flag.set_meta("is_golf_flag", true)
		if ResourceLoader.exists(GOLF_FLAG_SCRIPT):
			flag.set_script(load(GOLF_FLAG_SCRIPT))
		pin.add_child(flag)
	elif flag.get_script() == null and ResourceLoader.exists(GOLF_FLAG_SCRIPT):
		flag.set_meta("is_golf_flag", true)
		flag.set_script(load(GOLF_FLAG_SCRIPT))
	flag.set_meta("is_golf_flag", true)

	flag.set("pole_height", pole_height)
	flag.set("flag_color", flag_color)
	flag.position = Vector3(0.0, pole_height - 0.22, 0.0)

	if not quality.is_empty() and flag.has_method("update_quality"):
		flag.update_quality(quality)

	# 4. Hardware Finial & Swivel Collars
	var is_low = (quality == "Low")
	var finial = pin.get_node_or_null("Finial") as MeshInstance3D
	if finial == null:
		finial = MeshInstance3D.new()
		finial.name = "Finial"
		var s_mesh = SphereMesh.new()
		s_mesh.radius = 0.020
		s_mesh.height = 0.040
		finial.mesh = s_mesh
		var finial_mat = StandardMaterial3D.new()
		finial_mat.albedo_color = Color(0.88, 0.74, 0.28) # Polished brass
		finial_mat.metallic = 0.90
		finial_mat.roughness = 0.22
		finial.material_override = finial_mat
		pin.add_child(finial)
	finial.position = Vector3(0.0, pole_height + 0.015, 0.0)
	finial.visible = not is_low

	var top_collar = pin.get_node_or_null("TopCollar") as MeshInstance3D
	if top_collar == null:
		top_collar = _create_collar("TopCollar")
		pin.add_child(top_collar)
	top_collar.position = Vector3(0.0, flag.position.y + (0.36 * 0.44), 0.0)
	top_collar.visible = not is_low

	var bot_collar = pin.get_node_or_null("BottomCollar") as MeshInstance3D
	if bot_collar == null:
		bot_collar = _create_collar("BottomCollar")
		pin.add_child(bot_collar)
	bot_collar.position = Vector3(0.0, flag.position.y - (0.36 * 0.44), 0.0)
	bot_collar.visible = not is_low

	# 5. Physical Recessed 3D Golf Hole Cup (if cup_radius > 0)
	if cup_radius > 0.0:
		build_hole_cup(pin, cup_radius)

		# 6. Night Golf Illuminated Cup Glow & Light
		var cup_glow = pin.get_node_or_null("NightCupGlow") as Node3D
		if cup_glow == null:
			cup_glow = Node3D.new()
			cup_glow.name = "NightCupGlow"
			pin.add_child(cup_glow)

			# Luminous neon blue cup ring
			var ring_mesh_inst = MeshInstance3D.new()
			ring_mesh_inst.name = "CupGlowRing"
			var torus = TorusMesh.new()
			torus.inner_radius = cup_radius - 0.004
			torus.outer_radius = cup_radius + 0.008
			torus.rings = 24
			torus.ring_segments = 12
			ring_mesh_inst.mesh = torus
			var ring_mat = StandardMaterial3D.new()
			ring_mat.albedo_color = Color(0.15, 0.82, 1.0)
			ring_mat.emission_enabled = true
			ring_mat.emission = Color(0.15, 0.85, 1.0)
			ring_mat.emission_energy_multiplier = 4.0
			ring_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			ring_mesh_inst.material_override = ring_mat
			ring_mesh_inst.position = Vector3(0.0, 0.004, 0.0)
			cup_glow.add_child(ring_mesh_inst)

			# Cup glow omni light illuminating the hole and green
			var cup_light = OmniLight3D.new()
			cup_light.name = "CupLight"
			cup_light.light_color = Color(0.15, 0.85, 1.0)
			cup_light.light_energy = 2.4
			cup_light.omni_range = 3.8
			cup_light.omni_attenuation = 1.3
			cup_light.shadow_enabled = false
			cup_light.position = Vector3(0.0, 0.18, 0.0)
			cup_glow.add_child(cup_light)

		cup_glow.visible = false

		if pin.is_inside_tree() and pin.get_parent() != null:
			sync_hole_cutout_to_terrain(pin.get_parent(), pin.global_position, cup_radius)

	return pin


## Builds a recessed 3D physical golf hole cup (turf bevel, 1-inch root-zone soil collar,
## sunken white cylindrical cup liner sleeve, and recessed bottom drain plate & ferrule)
static func build_hole_cup(cup_parent: Node3D, cup_radius: float = 0.054) -> void:
	if cup_parent == null or cup_radius <= 0.0:
		return

	# A. Recessed Hollow White Cup Liner Sleeve (-0.024m down to -0.108m, open top)
	var cup_white = cup_parent.get_node_or_null("CupWhite") as MeshInstance3D
	if cup_white == null:
		cup_white = MeshInstance3D.new()
		cup_white.name = "CupWhite"
		cup_parent.add_child(cup_white)
	var white_mesh = CylinderMesh.new()
	white_mesh.top_radius = cup_radius
	white_mesh.bottom_radius = cup_radius
	white_mesh.height = CUP_LINER_HEIGHT
	white_mesh.radial_segments = 36
	white_mesh.rings = 1
	white_mesh.cap_top = false
	white_mesh.cap_bottom = false
	cup_white.mesh = white_mesh
	var white_mat = StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.92, 0.93, 0.95)
	white_mat.roughness = 0.45
	white_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cup_white.material_override = white_mat
	cup_white.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cup_white.position = Vector3(0.0, -CUP_SOIL_DEPTH - CUP_LINER_HEIGHT * 0.5, 0.0)

	# B. Recessed Dark Cup Bottom Drain Plate (at the bottom of the 10.8cm deep cup)
	var cup_dark = cup_parent.get_node_or_null("Cup") as MeshInstance3D
	if cup_dark == null:
		cup_dark = MeshInstance3D.new()
		cup_dark.name = "Cup"
		cup_parent.add_child(cup_dark)
	var inner_r := maxf(0.045, cup_radius - 0.004)
	var cup_mesh = CylinderMesh.new()
	cup_mesh.top_radius = inner_r
	cup_mesh.bottom_radius = inner_r
	cup_mesh.height = 0.004
	cup_mesh.radial_segments = 32
	cup_dark.mesh = cup_mesh
	var cup_mat = StandardMaterial3D.new()
	cup_mat.albedo_color = Color(0.08, 0.08, 0.09)
	cup_mat.roughness = 0.98
	cup_dark.material_override = cup_mat
	cup_dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cup_dark.position = Vector3(0.0, -CUP_DEPTH + 0.002, 0.0)

	# C. 3D Physical Cup Interior Wall, Soil Collar, Liner Ledge & Ferrule Socket
	var cup_interior = cup_parent.get_node_or_null("CupInterior") as MeshInstance3D
	if cup_interior == null:
		cup_interior = MeshInstance3D.new()
		cup_interior.name = "CupInterior"
		cup_parent.add_child(cup_interior)
	cup_interior.mesh = _create_recessed_cup_interior_mesh(cup_radius)
	var int_mat = StandardMaterial3D.new()
	int_mat.vertex_color_use_as_albedo = true
	int_mat.roughness = 0.80
	int_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cup_interior.material_override = int_mat
	cup_interior.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cup_interior.position = Vector3.ZERO


## Computes an orthonormal Basis whose +Y axis aligns with the given ground surface normal.
static func basis_from_surface_normal(surface_normal: Vector3) -> Basis:
	var n := surface_normal
	if n.length_squared() < 0.0001 or n.y < 0.5:
		return Basis.IDENTITY
	n = n.normalized()
	if n.distance_squared_to(Vector3.UP) < 0.00001:
		return Basis.IDENTITY
	var ref_x := Vector3.RIGHT
	if absf(n.dot(ref_x)) > 0.95:
		ref_x = Vector3.FORWARD
	var z_axis := ref_x.cross(n).normalized()
	var x_axis := n.cross(z_axis).normalized()
	return Basis(x_axis, n, z_axis).orthonormalized()


## Aligns the recessed hole cup meshes (CupInterior, CupWhite, Cup) to sit flush against
## sloped green terrain while keeping the flagstick pole & flag strictly vertical.
static func align_cup_to_normal(cup_parent: Node3D, surface_normal: Vector3) -> void:
	if cup_parent == null:
		return
	var b := basis_from_surface_normal(surface_normal)
	var up_dir := b.y
	var cup_interior := cup_parent.get_node_or_null("CupInterior") as Node3D
	if cup_interior != null:
		cup_interior.basis = b
		cup_interior.position = Vector3.ZERO
	var cup_white := cup_parent.get_node_or_null("CupWhite") as Node3D
	if cup_white != null:
		cup_white.basis = b
		cup_white.position = up_dir * (-CUP_SOIL_DEPTH - CUP_LINER_HEIGHT * 0.5)
	var cup_dark := cup_parent.get_node_or_null("Cup") as Node3D
	if cup_dark != null:
		cup_dark.basis = b
		cup_dark.position = up_dir * (-CUP_DEPTH + 0.002)


## Generates the 3D physical cup interior mesh (turf lip bevel, cut soil collar,
## white cup liner shelf, AO-shaded inner sleeve wall, and bottom ferrule socket)
static func _create_recessed_cup_interior_mesh(cup_radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs := 36
	var r_outer_bevel := cup_radius + 0.008
	var r_lip := cup_radius
	var r_liner_inner := maxf(0.045, cup_radius - 0.003)
	var r_ferrule := 0.015

	var y_bevel_outer := 0.0006
	var y_lip_top := 0.0012
	var y_soil_top := -0.003
	var y_soil_bot := -CUP_SOIL_DEPTH
	var y_liner_mid := -CUP_SOIL_DEPTH - CUP_LINER_HEIGHT * 0.45
	var y_liner_bot := -CUP_DEPTH + 0.004
	var y_ferrule_top := -CUP_DEPTH + 0.022

	var col_turf_edge := Color(0.18, 0.48, 0.21)
	var col_thatch_lip := Color(0.36, 0.28, 0.18)
	var col_soil_top := Color(0.30, 0.22, 0.15)
	var col_soil_bot := Color(0.20, 0.14, 0.09)
	var col_liner_shelf := Color(0.95, 0.96, 0.98)
	var col_liner_top := Color(0.90, 0.91, 0.94)
	var col_liner_mid := Color(0.58, 0.60, 0.64)
	var col_liner_bot := Color(0.25, 0.27, 0.30)
	var col_ferrule := Color(0.18, 0.19, 0.22)

	for i in range(segs):
		var a0 := float(i) / float(segs) * TAU
		var a1 := float(i + 1) / float(segs) * TAU
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)

		var n_in0 := Vector3(-c0, 0.0, -s0)
		var n_in1 := Vector3(-c1, 0.0, -s1)
		var n_out0 := Vector3(c0, 0.0, s0)
		var n_out1 := Vector3(c1, 0.0, s1)

		# 1. Outer Turf Bevel Ring (r_outer_bevel -> r_lip)
		var v_b0 := Vector3(r_outer_bevel * c0, y_bevel_outer, r_outer_bevel * s0)
		var v_b1 := Vector3(r_outer_bevel * c1, y_bevel_outer, r_outer_bevel * s1)
		var v_l0 := Vector3(r_lip * c0, y_lip_top, r_lip * s0)
		var v_l1 := Vector3(r_lip * c1, y_lip_top, r_lip * s1)
		_add_cup_quad(st, v_b0, v_b1, v_l1, v_l0, col_turf_edge, col_thatch_lip, Vector3.UP, Vector3.UP)

		# 2. Upper Lip Roll-In (y_lip_top -> y_soil_top at r_lip)
		var v_st0 := Vector3(r_lip * c0, y_soil_top, r_lip * s0)
		var v_st1 := Vector3(r_lip * c1, y_soil_top, r_lip * s1)
		var n_lip0 := (n_in0 + Vector3.UP * 0.6).normalized()
		var n_lip1 := (n_in1 + Vector3.UP * 0.6).normalized()
		_add_cup_quad(st, v_l0, v_l1, v_st1, v_st0, col_thatch_lip, col_soil_top, n_lip0, n_lip1)

		# 3. Vertical Cut Root-Zone Soil Collar (y_soil_top -> y_soil_bot at r_lip)
		var v_sb0 := Vector3(r_lip * c0, y_soil_bot, r_lip * s0)
		var v_sb1 := Vector3(r_lip * c1, y_soil_bot, r_lip * s1)
		_add_cup_quad(st, v_st0, v_st1, v_sb1, v_sb0, col_soil_top, col_soil_bot, n_in0, n_in1)

		# 4. Recessed White Cup Liner Top Shelf at y_soil_bot (r_lip -> r_liner_inner)
		var v_lt0 := Vector3(r_liner_inner * c0, y_soil_bot, r_liner_inner * s0)
		var v_lt1 := Vector3(r_liner_inner * c1, y_soil_bot, r_liner_inner * s1)
		_add_cup_quad(st, v_sb0, v_sb1, v_lt1, v_lt0, col_liner_shelf, col_liner_shelf, Vector3.UP, Vector3.UP)

		# 5. Inner White Cup Liner Wall - Upper Half (y_soil_bot -> y_liner_mid)
		var v_lm0 := Vector3(r_liner_inner * c0, y_liner_mid, r_liner_inner * s0)
		var v_lm1 := Vector3(r_liner_inner * c1, y_liner_mid, r_liner_inner * s1)
		_add_cup_quad(st, v_lt0, v_lt1, v_lm1, v_lm0, col_liner_top, col_liner_mid, n_in0, n_in1)

		# 6. Inner White Cup Liner Wall - Lower Half with Deep Cup AO (y_liner_mid -> y_liner_bot)
		var v_lb0 := Vector3(r_liner_inner * c0, y_liner_bot, r_liner_inner * s0)
		var v_lb1 := Vector3(r_liner_inner * c1, y_liner_bot, r_liner_inner * s1)
		_add_cup_quad(st, v_lm0, v_lm1, v_lb1, v_lb0, col_liner_mid, col_liner_bot, n_in0, n_in1)

		# 7. Central Bottom Flagstick Ferrule Socket Wall
		var v_fb0 := Vector3(r_ferrule * c0, y_liner_bot, r_ferrule * s0)
		var v_fb1 := Vector3(r_ferrule * c1, y_liner_bot, r_ferrule * s1)
		var v_ft0 := Vector3(r_ferrule * c0, y_ferrule_top, r_ferrule * s0)
		var v_ft1 := Vector3(r_ferrule * c1, y_ferrule_top, r_ferrule * s1)
		_add_cup_quad(st, v_ft0, v_ft1, v_fb1, v_fb0, col_ferrule, col_ferrule, n_out0, n_out1)

	return st.commit()


static func _add_cup_quad(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	col_top: Color,
	col_bot: Color,
	n0: Vector3,
	n1: Vector3
) -> void:
	st.set_normal(n0)
	st.set_color(col_top)
	st.add_vertex(a)
	st.set_normal(n1)
	st.set_color(col_top)
	st.add_vertex(b)
	st.set_normal(n1)
	st.set_color(col_bot)
	st.add_vertex(c)

	st.set_normal(n0)
	st.set_color(col_top)
	st.add_vertex(a)
	st.set_normal(n1)
	st.set_color(col_bot)
	st.add_vertex(c)
	st.set_normal(n0)
	st.set_color(col_bot)
	st.add_vertex(d)


## Helper to create swivel collar on flagpole
static func _create_collar(node_name: String) -> MeshInstance3D:
	var collar = MeshInstance3D.new()
	collar.name = node_name
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.017
	cyl.bottom_radius = 0.017
	cyl.height = 0.018
	collar.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.78)
	mat.metallic = 0.92
	mat.roughness = 0.28
	collar.material_override = mat
	return collar


## Sets up a flag and pole on an existing node (e.g. for minigames and target pins)
static func setup_target_flag(
	parent_node: Node3D,
	pole_height: float = 2.6,
	flag_color: Color = Color(0.95, 0.12, 0.12),
	flag_width: float = 0.52,
	flag_height: float = 0.36,
	has_collider: bool = true,
	quality: String = ""
) -> MeshInstance3D:
	if parent_node == null:
		return null

	# Flagpole (extends down into recessed cup bottom when a hole cup is present)
	var has_cup = (parent_node.get_node_or_null("CupWhite") != null) or parent_node.has_meta("cup_radius")
	var pole_bottom_y = -(CUP_DEPTH - 0.002) if has_cup else 0.0
	var total_pole_height = pole_height - pole_bottom_y
	var pole = parent_node.get_node_or_null("Pole") as MeshInstance3D
	if pole == null:
		pole = MeshInstance3D.new()
		pole.name = "Pole"
		parent_node.add_child(pole)
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.015
	pole_mesh.bottom_radius = 0.015
	pole_mesh.height = total_pole_height
	pole.mesh = pole_mesh
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color.WHITE
	pole_mat.roughness = 0.25
	pole.material_override = pole_mat
	pole.position = Vector3(0.0, pole_bottom_y + total_pole_height * 0.5, 0.0)

	# Optional Collider
	if has_collider:
		var flag_body = parent_node.get_node_or_null("FlagstickCollider") as StaticBody3D
		if flag_body == null:
			flag_body = StaticBody3D.new()
			flag_body.name = "FlagstickCollider"
			flag_body.set_meta("is_flagstick", true)
			flag_body.set_meta("is_obstacle", true)
			flag_body.collision_layer = 1
			flag_body.collision_mask = 0
			var col_shape = CollisionShape3D.new()
			col_shape.name = "CollisionShape"
			var cyl = CylinderShape3D.new()
			cyl.radius = 0.018
			cyl.height = total_pole_height
			col_shape.shape = cyl
			col_shape.position = Vector3(0.0, pole_bottom_y + total_pole_height * 0.5, 0.0)
			flag_body.add_child(col_shape)
			parent_node.add_child(flag_body)

	# Flag
	var flag = parent_node.get_node_or_null("Flag") as MeshInstance3D
	if flag == null:
		flag = MeshInstance3D.new()
		flag.name = "Flag"
		flag.set_meta("is_golf_flag", true)
		if ResourceLoader.exists(GOLF_FLAG_SCRIPT):
			flag.set_script(load(GOLF_FLAG_SCRIPT))
		parent_node.add_child(flag)
	elif flag.get_script() == null and ResourceLoader.exists(GOLF_FLAG_SCRIPT):
		flag.set_meta("is_golf_flag", true)
		flag.set_script(load(GOLF_FLAG_SCRIPT))
	flag.set_meta("is_golf_flag", true)

	flag.set("pole_height", pole_height)
	flag.set("flag_width", flag_width)
	flag.set("flag_height", flag_height)
	flag.set("flag_color", flag_color)
	flag.position = Vector3(0.0, pole_height - (flag_height * 0.6), 0.0)

	if not quality.is_empty() and flag.has_method("update_quality"):
		flag.update_quality(quality)

	return flag


## Recursively updates all flags in a scene hierarchy when graphics quality changes
static func apply_graphics_quality_to_flags(scene_root: Node, quality: String) -> void:
	if scene_root == null:
		return

	var is_low = (quality == "Low")
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.has_meta("is_golf_flag") or (n.get_script() != null and str(n.get_script().resource_path).ends_with("golf_flag.gd")):
			if n.has_method("update_quality"):
				n.update_quality(quality)
		var finial = n.get_node_or_null("Finial")
		if finial != null:
			finial.visible = not is_low
		var top_col = n.get_node_or_null("TopCollar")
		if top_col != null:
			top_col.visible = not is_low
		var bot_col = n.get_node_or_null("BottomCollar")
		if bot_col != null:
			bot_col.visible = not is_low

		for child in n.get_children():
			stack.push_back(child)


## Synchronizes the active hole cup circular cutout with any terrain ShaderMaterial in the scene
static func sync_hole_cutout_to_terrain(scene_root: Node, hole_pos: Vector3, cup_radius: float = 0.054) -> void:
	if scene_root == null:
		return

	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n.name == "UnifiedTerrain" or n.name.contains("Terrain")):
			n.set_meta("active_hole_pos", hole_pos)
			n.set_meta("active_hole_radius", cup_radius)
			var mats: Array[Material] = []
			if n.material_override != null:
				mats.append(n.material_override)
			if n.mesh != null and n.mesh.get_surface_count() > 0:
				var surf_override = n.get_surface_override_material(0)
				if surf_override != null and not mats.has(surf_override):
					mats.append(surf_override)
				var base_mat = n.mesh.surface_get_material(0)
				if base_mat != null and not mats.has(base_mat):
					mats.append(base_mat)
			for m in mats:
				if m is ShaderMaterial:
					m.set_shader_parameter("active_hole_pos", hole_pos)
					m.set_shader_parameter("active_hole_radius", cup_radius)
		for child in n.get_children():
			stack.push_back(child)


## Applies a multi-hole cutout shader material to a standalone PuttingGreenMesh (e.g. Putting Practice)
static func apply_green_hole_cutout_material(green_mesh_inst: MeshInstance3D, hole_positions: Array, cup_radius: float = 0.054) -> void:
	if green_mesh_inst == null:
		return

	var base_std: StandardMaterial3D = null
	if green_mesh_inst.material_override is StandardMaterial3D:
		base_std = green_mesh_inst.material_override as StandardMaterial3D
	elif green_mesh_inst.get_surface_override_material(0) is StandardMaterial3D:
		base_std = green_mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	elif green_mesh_inst.mesh != null and green_mesh_inst.mesh.get_surface_count() > 0:
		base_std = green_mesh_inst.mesh.surface_get_material(0) as StandardMaterial3D

	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_normal = false;
uniform bool use_ao = false;
uniform bool use_roughness_tex = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.84;
uniform float normal_scale : hint_range(0.0, 2.0) = 0.65;
uniform int hole_count = 0;
uniform vec3 hole_positions[16];
uniform float hole_radius = 0.054;

varying vec3 v_world_pos;
varying vec3 v_cam_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cam_pos = INV_VIEW_MATRIX[3].xyz;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
				   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
			   mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
				   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float r2 = hole_radius * hole_radius;
	for (int i = 0; i < hole_count; i++) {
		vec2 d = v_world_pos.xz - hole_positions[i].xz;
		if (dot(d, d) < r2) {
			discard;
		}
	}
	vec2 scaled_uv = v_world_pos.xz * 0.50 * uv_scale;
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		col *= texture(albedo_texture, scaled_uv).rgb;
	}
	// Vibrant championship bentgrass green grading + cross-cut tournament mowing pattern
	col *= vec3(1.02, 1.24, 0.78);
	float macro_mottle = gnoise(v_world_pos.xz * 0.08) * 0.5 + 0.5;
	col *= mix(vec3(0.95, 0.96, 0.92), vec3(1.04, 1.05, 1.01), macro_mottle);
	vec2 mow_dir = normalize(vec2(0.707, 0.707));
	vec2 mow_perp = vec2(-mow_dir.y, mow_dir.x);
	float cut_a = sin(dot(v_world_pos.xz, mow_dir) * 4.2) * 0.5 + 0.5;
	float cut_b = sin(dot(v_world_pos.xz, mow_perp) * 4.2) * 0.5 + 0.5;
	float green_grid = cut_a * cut_b;
	col *= mix(0.93, 1.07, green_grid);
	vec3 view_dir = normalize(v_world_pos - v_cam_pos);
	float view_sheen = abs(dot(view_dir.xz, mow_dir));
	col *= (1.0 + (view_sheen - 0.5) * 0.14);

	ALBEDO = clamp(col, 0.0, 1.0);
	if (use_normal) {
		NORMAL_MAP = texture(normal_texture, scaled_uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	float r_val = roughness;
	if (use_roughness_tex) {
		r_val = clamp(roughness * (0.85 + 0.30 * texture(roughness_texture, scaled_uv).r), 0.5, 1.0);
	}
	ROUGHNESS = r_val;
	if (use_ao) {
		AO = mix(0.75, 1.0, texture(ao_texture, scaled_uv).r);
	}
	SPECULAR = 0.14;
}
"""
	var sm = ShaderMaterial.new()
	sm.shader = shader
	if base_std != null:
		sm.set_shader_parameter("albedo_color", base_std.albedo_color)
		sm.set_shader_parameter("roughness", base_std.roughness)
		sm.set_shader_parameter("uv_scale", Vector2(base_std.uv1_scale.x, base_std.uv1_scale.y))
		if base_std.albedo_texture != null:
			sm.set_shader_parameter("albedo_texture", base_std.albedo_texture)
			sm.set_shader_parameter("use_texture", true)
		if base_std.normal_texture != null:
			sm.set_shader_parameter("normal_texture", base_std.normal_texture)
			sm.set_shader_parameter("use_normal", true)
		if base_std.ao_texture != null:
			sm.set_shader_parameter("ao_texture", base_std.ao_texture)
			sm.set_shader_parameter("use_ao", true)
		if base_std.roughness_texture != null:
			sm.set_shader_parameter("roughness_texture", base_std.roughness_texture)
			sm.set_shader_parameter("use_roughness_tex", true)

	var packed_holes := PackedVector3Array()
	var count = mini(hole_positions.size(), 16)
	for i in range(16):
		if i < count and hole_positions[i] is Vector3:
			packed_holes.append(hole_positions[i])
		else:
			packed_holes.append(Vector3(0.0, -9999.0, 0.0))

	sm.set_shader_parameter("hole_count", count)
	sm.set_shader_parameter("hole_positions", packed_holes)
	sm.set_shader_parameter("hole_radius", cup_radius)
	green_mesh_inst.material_override = sm

