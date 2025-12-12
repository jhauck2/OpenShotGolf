extends MeshInstance3D

var points : Array = []
var color : Color = Color(0.6, 0.0, 0.0, 1.0)  # Darker red
var line_width : float = 0.08
var material : StandardMaterial3D = StandardMaterial3D.new()


func _ready():
	mesh = ArrayMesh.new()

	# Setup material with subtle glow
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.disable_receive_shadows = true
	material.no_depth_test = false

func _process(_delta):
	draw()

func setColor(a):
	color = a
	material.albedo_color = color
	material.emission = color

func draw():
	mesh.clear_surfaces()
	if points.size() >= 2:
		create_ribbon_mesh()

func create_ribbon_mesh():
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# Create ribbon vertices
	for i in range(points.size()):
		var point : Vector3 = points[i]

		# Get direction to camera for billboarding
		var to_camera : Vector3 = (camera.global_position - point).normalized()

		# Get forward direction along the path
		var forward : Vector3 = Vector3.ZERO
		if i < points.size() - 1:
			forward = (points[i + 1] - point).normalized()
		elif i > 0:
			forward = (point - points[i - 1]).normalized()
		else:
			forward = Vector3.FORWARD

		# Create perpendicular vector for ribbon width
		var right : Vector3 = to_camera.cross(forward).normalized()
		if right.length() < 0.01:
			right = Vector3.RIGHT

		# Fade out towards the end
		var alpha : float = 1.0
		var points_from_end : int = points.size() - 1 - i
		if points_from_end < 3:  # Fade out at the end
			alpha = float(points_from_end + 1) / 4.0

		# Create two vertices for this point (left and right of center)
		var half_width : float = line_width * 0.5
		vertices.append(point - right * half_width)
		vertices.append(point + right * half_width)

		var t := float(i) / float(points.size() - 1)
		uvs.append(Vector2(0, t))
		uvs.append(Vector2(1, t))

		var vertex_color := Color(color.r, color.g, color.b, alpha)
		colors.append(vertex_color)
		colors.append(vertex_color)

		# Create triangles connecting to previous segment
		if i > 0:
			var base := i * 2
			# First triangle
			indices.append(base)
			indices.append(base - 2)
			indices.append(base - 1)
			# Second triangle
			indices.append(base - 1)
			indices.append(base + 1)
			indices.append(base)

	# Create the mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)

func add_point(point: Vector3):
	#points.append(points[-1])
	points.append(point)

func clear_points():
	points = []
	mesh.clear_surfaces()
