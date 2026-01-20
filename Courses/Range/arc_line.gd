@tool
extends MeshInstance3D
var label_left: Node3D
var label_right: Node3D

@export var distance := 100.0 :
	set(value):
		distance = value
		_update_arc()

@export var arc_angle := 180.0 :
	set(value):
		arc_angle = value
		_update_arc()

@export var thickness := 0.5 :
	set(value):
		thickness = value
		_update_arc()

@export var segments := 64 :
	set(value):
		segments = max(4, value)
		_update_arc()

@export var color := Color.WHITE :
	set(value):
		color = value
		_update_material()
		_update_labels()

@export_range(0.1, 1.0, 0.05)
var label_arc_ratio := 0.5 :
	set(value):
		label_arc_ratio = value
		_update_arc()

@export var label_text := "100" :
	set(value):
		label_text = value
		_update_arc()

@export var label_char_spacing := 0.1 :
	set(value):
		label_char_spacing = value
		_update_arc()

@export var label_offset := 3.0 :
	set(value):
		label_offset = value
		_update_arc()

@export var label_size := 500 :
	set(value):
		label_size = value
		_update_arc()

@export_range(-180.0, 180.0, 1.0)
var label_letter_angle_offset := 30 :
	set(value):
		label_letter_angle_offset = value
		_update_arc()


func _enter_tree():
	_setup_labels()

func _ready():
	_update_material()
	_update_arc()

func _update_arc():
	if not is_inside_tree():
		return

	mesh = _generate_arc_mesh()
	position.y = 0.05  # lift above grass
	_update_labels()


func _generate_arc_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_angle = deg_to_rad(arc_angle) * 0.5

	for i in range(segments):
		var t1 = float(i) / segments
		var t2 = float(i + 1) / segments

		var a1 = lerp(-half_angle, half_angle, t1)
		var a2 = lerp(-half_angle, half_angle, t2)

		var r_inner = distance - thickness
		var r_outer = distance + thickness

		var inner1 = Vector3(cos(a1) * r_inner, 0, sin(a1) * r_inner)
		var outer1 = Vector3(cos(a1) * r_outer, 0, sin(a1) * r_outer)
		var inner2 = Vector3(cos(a2) * r_inner, 0, sin(a2) * r_inner)
		var outer2 = Vector3(cos(a2) * r_outer, 0, sin(a2) * r_outer)

		st.add_vertex(inner1)
		st.add_vertex(outer1)
		st.add_vertex(outer2)

		st.add_vertex(inner1)
		st.add_vertex(outer2)
		st.add_vertex(inner2)

	st.generate_normals()
	return st.commit()

func _update_material():
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material_override = mat
	
func _update_labels():
	_setup_labels()
	if label_left == null or label_right == null:
		return

	var half_angle := deg_to_rad(arc_angle) * 0.5
	var label_angle := half_angle * label_arc_ratio

	_build_curved_label(label_left, -label_angle, -1.0, true)
	_build_curved_label(label_right, label_angle, 1, false)


func _place_label(label: Label3D, angle: float):
	if label == null:
		return

	# Position on arc
	label.position = Vector3(
		cos(angle) * distance,
		0.02,
		sin(angle) * distance
	)

	# Lay flat + rotate tangentially to arc
	label.rotation = Vector3(
		-PI / 2,        # flat on ground
		angle + PI / 2 + PI, # tangent direction
		0
	)

func _build_curved_label(container: Node3D, base_angle: float, side_sign: float, flip_180: bool = false):
	if container == null:
		return

	for c in container.get_children():
		c.queue_free()

	var char_count := label_text.length()
	if char_count == 0:
		return

	var half_span := (char_count - 1) * label_char_spacing * 0.5
	var label_radius := distance + label_offset
	var angle_offset := deg_to_rad(label_letter_angle_offset)

	for i in range(char_count):
		var label_char := label_text[i]
		
		var offset := (i * label_char_spacing) - half_span
		var char_angle := base_angle + offset

		var lbl := Label3D.new()
		lbl.text = label_char
		lbl.font_size = label_size
		lbl.modulate = color
		lbl.outline_modulate = color
		lbl.pixel_size = 0.01
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED

		lbl.position = Vector3(
			cos(char_angle) * label_radius,
			0.02,
			sin(char_angle) * label_radius
		)

		# 🔑 MIRRORED rotation
		lbl.rotation = Vector3(
			-PI / 2,
			char_angle + PI + angle_offset * side_sign,
			0
		)
		if flip_180:
			lbl.rotate_y(PI)


		container.add_child(lbl)
		if Engine.is_editor_hint() and is_inside_tree():
			var tree := get_tree()
			if tree:
				lbl.owner = tree.edited_scene_root

func _setup_labels():
	if label_left == null:
		label_left = _ensure_label_node("LabelLeft")

	if label_right == null:
		label_right = _ensure_label_node("LabelRight")


func _ensure_label_node(name: String) -> Node3D:
	var node := get_node_or_null(name)
	if node:
		return node

	var container := Node3D.new()
	container.name = name
	container.set_unique_name_in_owner(true)
	add_child(container)

	if Engine.is_editor_hint() and is_inside_tree():
		var tree := get_tree()
		if tree:
			container.owner = tree.edited_scene_root

	return container
