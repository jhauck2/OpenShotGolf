class_name TargetGreen
extends Node3D

## Represents a virtual target green with scoring zones
##
## Provides proximity-based scoring with color-coded rings.
## Emits signals when shots land near the target.

signal shot_landed_near_target(distance_to_target: float, score: int, zone: String)

## Target configuration
@export var target_distance: float = 150.0  # Distance from tee in yards
@export var target_name: String = "Target 1"
@export var is_active: bool = true
@export var lateral_offset: float = 0.0  # Left/right offset in yards

## Scoring zone radii (in yards)
@export_group("Scoring Zones")
@export var bullseye_radius: float = 5.0  # Green zone
@export var yellow_radius: float = 10.0   # Yellow zone
@export var red_radius: float = 15.0      # Red zone
@export var white_radius: float = 20.0    # White zone

## Scoring points
@export_group("Scoring")
@export var bullseye_points: int = 10
@export var yellow_points: int = 7
@export var red_points: int = 5
@export var white_points: int = 3
@export var outside_points: int = 0

## Visual elements
var flag_pole: Node3D
var ring_bullseye: MeshInstance3D
var ring_yellow: MeshInstance3D
var ring_red: MeshInstance3D
var ring_white: MeshInstance3D

## Materials for rings
var material_bullseye: StandardMaterial3D
var material_yellow: StandardMaterial3D
var material_red: StandardMaterial3D
var material_white: StandardMaterial3D
var material_flag: StandardMaterial3D


func _ready() -> void:
	_create_visuals()
	_position_target()


func _create_visuals() -> void:
	# Create materials
	material_bullseye = StandardMaterial3D.new()
	material_bullseye.albedo_color = Color(0.2, 0.8, 0.2, 0.6)  # Green, semi-transparent
	material_bullseye.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	material_yellow = StandardMaterial3D.new()
	material_yellow.albedo_color = Color(0.9, 0.9, 0.2, 0.5)  # Yellow, semi-transparent
	material_yellow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	material_red = StandardMaterial3D.new()
	material_red.albedo_color = Color(0.9, 0.2, 0.2, 0.4)  # Red, semi-transparent
	material_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	material_white = StandardMaterial3D.new()
	material_white.albedo_color = Color(0.9, 0.9, 0.9, 0.3)  # White, semi-transparent
	material_white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	material_flag = StandardMaterial3D.new()
	material_flag.albedo_color = Color(1.0, 0.0, 0.0)  # Red flag

	# Create scoring rings (largest to smallest for proper layering)
	ring_white = _create_ring(white_radius, material_white, 0.05)
	ring_red = _create_ring(red_radius, material_red, 0.06)
	ring_yellow = _create_ring(yellow_radius, material_yellow, 0.07)
	ring_bullseye = _create_ring(bullseye_radius, material_bullseye, 0.08)

	add_child(ring_white)
	add_child(ring_red)
	add_child(ring_yellow)
	add_child(ring_bullseye)

	# Create flag pole
	flag_pole = _create_flag_pole()
	add_child(flag_pole)


func _create_ring(radius_yards: float, material: Material, height: float) -> MeshInstance3D:
	var ring = MeshInstance3D.new()
	var mesh = CylinderMesh.new()

	# Convert yards to meters (1 yard = 0.9144 meters)
	var radius_meters = radius_yards * 0.9144

	mesh.top_radius = radius_meters
	mesh.bottom_radius = radius_meters
	mesh.height = 0.05  # Thin disk

	ring.mesh = mesh
	ring.material_override = material
	ring.position.y = height  # Slightly above ground to prevent z-fighting

	return ring


func _create_flag_pole() -> Node3D:
	var flag_container = Node3D.new()

	# Pole
	var pole = MeshInstance3D.new()
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.025  # 2.5cm
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 2.5  # 2.5 meters tall

	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.9, 0.9, 0.9)  # White pole

	pole.mesh = pole_mesh
	pole.material_override = pole_material
	pole.position.y = 1.25  # Half height to position base at ground

	# Flag
	var flag = MeshInstance3D.new()
	var flag_mesh = BoxMesh.new()
	flag_mesh.size = Vector3(0.5, 0.3, 0.02)  # 50cm x 30cm flag

	flag.mesh = flag_mesh
	flag.material_override = material_flag
	flag.position = Vector3(0.25, 2.2, 0)  # At top of pole

	flag_container.add_child(pole)
	flag_container.add_child(flag)

	return flag_container


func _position_target() -> void:
	# Position target at specified distance from origin (tee box at 0,0,0)
	# Convert yards to meters
	var distance_meters = target_distance * 0.9144
	var offset_meters = lateral_offset * 0.9144
	position = Vector3(distance_meters, 0, offset_meters)


## Calculate distance from a point to target center (in yards)
func calculate_distance_to_target(point: Vector3) -> float:
	var target_center = global_position
	target_center.y = 0  # Only measure horizontal distance

	var point_2d = point
	point_2d.y = 0

	var distance_meters = target_center.distance_to(point_2d)
	var distance_yards = distance_meters / 0.9144

	return distance_yards


## Calculate score based on distance to target
func calculate_score(distance_to_target: float) -> Dictionary:
	var score = 0
	var zone = "Outside"

	if distance_to_target <= bullseye_radius:
		score = bullseye_points
		zone = "Bullseye"
	elif distance_to_target <= yellow_radius:
		score = yellow_points
		zone = "Yellow"
	elif distance_to_target <= red_radius:
		score = red_points
		zone = "Red"
	elif distance_to_target <= white_radius:
		score = white_points
		zone = "White"
	else:
		score = outside_points
		zone = "Outside"

	return {
		"score": score,
		"zone": zone,
		"distance": distance_to_target
	}


## Called when a ball lands - checks if near this target
func check_shot(ball_position: Vector3) -> Dictionary:
	if not is_active:
		return {}

	var distance = calculate_distance_to_target(ball_position)
	var result = calculate_score(distance)

	if result.score > 0:
		emit_signal("shot_landed_near_target", distance, result.score, result.zone)

	return result


## Toggle target visibility
func set_target_visible(target_visible: bool) -> void:
	if ring_white:
		ring_white.visible = target_visible
	if ring_red:
		ring_red.visible = target_visible
	if ring_yellow:
		ring_yellow.visible = target_visible
	if ring_bullseye:
		ring_bullseye.visible = target_visible
	if flag_pole:
		flag_pole.visible = target_visible


## Highlight target (make it more opaque when selected)
func set_highlighted(highlighted: bool) -> void:
	if highlighted:
		material_bullseye.albedo_color.a = 0.8
		material_yellow.albedo_color.a = 0.7
		material_red.albedo_color.a = 0.6
		material_white.albedo_color.a = 0.5
	else:
		material_bullseye.albedo_color.a = 0.6
		material_yellow.albedo_color.a = 0.5
		material_red.albedo_color.a = 0.4
		material_white.albedo_color.a = 0.3


## Base radii for size scaling
var _base_bullseye_radius: float = 5.0
var _base_yellow_radius: float = 10.0
var _base_red_radius: float = 15.0
var _base_white_radius: float = 20.0
var _base_radii_stored: bool = false


## Set size multiplier for difficulty
## 1.0 = normal, 0.5 = half size (harder), 1.5 = larger (easier)
func set_size_multiplier(multiplier: float) -> void:
	# Store base radii on first call
	if not _base_radii_stored:
		_base_bullseye_radius = bullseye_radius
		_base_yellow_radius = yellow_radius
		_base_red_radius = red_radius
		_base_white_radius = white_radius
		_base_radii_stored = true

	# Apply multiplier to radii
	bullseye_radius = _base_bullseye_radius * multiplier
	yellow_radius = _base_yellow_radius * multiplier
	red_radius = _base_red_radius * multiplier
	white_radius = _base_white_radius * multiplier

	# Update visual ring sizes
	_update_ring_size(ring_bullseye, bullseye_radius)
	_update_ring_size(ring_yellow, yellow_radius)
	_update_ring_size(ring_red, red_radius)
	_update_ring_size(ring_white, white_radius)


func _update_ring_size(ring: MeshInstance3D, radius_yards: float) -> void:
	if ring and ring.mesh is CylinderMesh:
		var mesh = ring.mesh as CylinderMesh
		var radius_meters = radius_yards * 0.9144
		mesh.top_radius = radius_meters
		mesh.bottom_radius = radius_meters
