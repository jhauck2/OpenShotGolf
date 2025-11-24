extends Node3D
## Yard Marker Manager - Scales yardage markers based on distance for better visibility
## Markers appear larger further away to maintain visibility across the range

class_name YardMarkerManager

# Marker data: distance in yards, position X
var markers = [
	{"distance": 50, "pos_x": 45.72, "node_name": "50Yards"},
	{"distance": 100, "pos_x": 91.4, "node_name": "100Yards"},
	# {"distance": 150, "pos_x": 137.16, "node_name": "150Yards"},
	{"distance": 200, "pos_x": 182.88, "node_name": "200"},
	{"distance": 300, "pos_x": 228.6, "node_name": "300"},
]

# Scaling configuration
var base_pixel_size: float = 0.04  # Base size for 50 yard marker
var scaling_factor: float = 0.015  # How much to increase size per 50 yards (increased for visibility)

func _ready() -> void:
	_apply_dynamic_scaling()


func _apply_dynamic_scaling() -> void:
	"""Apply distance-based scaling to all yardage markers"""
	for marker_data in markers:
		var marker_node = get_node_or_null(marker_data.node_name)
		if not marker_node:
			push_warning("Yard marker node not found: %s" % marker_data.node_name)
			continue

		# Calculate pixel size based on distance
		# Formula: base_size + (distance_factor * scaling_factor)
		# This makes markers progressively larger as they get further away
		var distance_factor = (marker_data.distance - 50.0) / 50.0  # Normalize from 0 to 4 for 50-250 yards
		var new_pixel_size = base_pixel_size + (distance_factor * scaling_factor)

		marker_node.pixel_size = new_pixel_size



func get_marker_size(distance_yards: float) -> float:
	"""Calculate appropriate size for a marker at given distance"""
	var distance_factor = (distance_yards - 50.0) / 50.0
	return base_pixel_size + (distance_factor * scaling_factor)


func set_scaling_factor(new_factor: float) -> void:
	"""Update the scaling factor and reapply to all markers"""
	scaling_factor = new_factor
	_apply_dynamic_scaling()
