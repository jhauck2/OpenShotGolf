class_name LandingMarker
extends Node3D

## Visual marker showing where the ball landed
##
## Creates a visual indicator at the ball's final resting position
## with optional distance-to-target information.

## Marker configuration
@export var marker_color: Color = Color(1.0, 0.8, 0.0, 0.8)  # Yellow/gold
@export var marker_radius: float = 1.0  # meters (increased for better visibility)
@export var show_distance_label: bool = true
@export var marker_lifetime: float = 0.0  # 0 = permanent, >0 = fade after seconds

## Visual elements
var marker_mesh: MeshInstance3D
var distance_label: Label3D
var lifetime_timer: Timer


func _ready() -> void:
	_create_marker()
	if show_distance_label:
		_create_distance_label()

	if marker_lifetime > 0:
		_setup_lifetime_timer()


func _create_marker() -> void:
	marker_mesh = MeshInstance3D.new()

	var cylinder = CylinderMesh.new()
	cylinder.top_radius = marker_radius
	cylinder.bottom_radius = marker_radius
	cylinder.height = 0.02

	var material = StandardMaterial3D.new()
	material.albedo_color = marker_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	marker_mesh.mesh = cylinder
	marker_mesh.material_override = material
	marker_mesh.position.y = 0.01

	add_child(marker_mesh)


func _create_distance_label() -> void:
	distance_label = Label3D.new()
	distance_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	distance_label.position.y = 0.5
	distance_label.pixel_size = 0.005
	distance_label.font_size = 48

	distance_label.outline_size = 3
	distance_label.outline_modulate = Color.BLACK
	distance_label.modulate = Color.BLACK

	add_child(distance_label)


func _setup_lifetime_timer() -> void:
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = marker_lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(lifetime_timer)
	lifetime_timer.start()


func _on_lifetime_expired() -> void:
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(marker_mesh.material_override, "albedo_color:a", 0.0, 1.0)
	if distance_label:
		tween.parallel().tween_property(distance_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)


## Set the marker position and optional distance text
func set_marker_data(position_3d: Vector3, distance_to_target: float = -1.0, carry_distance: float = -1.0) -> void:
	global_position = position_3d
	global_position.y = 0.01  # Ensure on ground level

	if distance_label and show_distance_label:
		var text = ""

		if carry_distance > 0:
			text += "Carry: %d yds\n" % int(carry_distance)

		if distance_to_target >= 0:
			text += "To Target: %.1f yds" % distance_to_target

		distance_label.text = text.strip_edges()


## Update marker color (useful for color-coding by accuracy)
func set_marker_color(color: Color) -> void:
	marker_color = color
	if marker_mesh and marker_mesh.material_override:
		marker_mesh.material_override.albedo_color = color


## Get color based on scoring zone
static func get_zone_color(zone: String) -> Color:
	match zone:
		"Bullseye":
			return Color(0.2, 1.0, 0.2, 0.9)  # Bright green
		"Yellow":
			return Color(1.0, 1.0, 0.2, 0.8)  # Yellow
		"Red":
			return Color(1.0, 0.3, 0.2, 0.7)  # Red
		"White":
			return Color(0.9, 0.9, 0.9, 0.6)  # White
		_:
			return Color(0.5, 0.5, 0.5, 0.5)  # Gray for outside
