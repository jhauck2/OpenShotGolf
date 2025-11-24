class_name TargetManager
extends Node

## Manages multiple target greens on the range
##
## Handles target creation, selection, and scoring coordination.
## Tracks session statistics for target practice.

signal target_selected(target: TargetGreen)
signal shot_scored(target_name: String, distance: float, score: int, zone: String)

## Active target
var active_target: TargetGreen = null
var targets: Array[TargetGreen] = []
var targets_created: bool = false

## Session statistics
var session_stats: Dictionary = {
	"total_shots": 0,
	"total_score": 0,
	"bullseyes": 0,
	"yellow_hits": 0,
	"red_hits": 0,
	"white_hits": 0,
	"misses": 0,
	"best_shot_distance": INF,
	"average_distance": 0.0
}


func _ready() -> void:
	# Don't create targets automatically - let range.gd control this
	pass


## Create default target layout
func create_targets() -> void:
	if targets_created:
		return  # Already created

	targets_created = true
	_create_default_targets()


func _create_default_targets() -> void:
	var default_distances = [75, 100, 125, 150, 175, 200, 225, 250]

	for i in range(default_distances.size()):
		var target = TargetGreen.new()
		target.target_distance = default_distances[i]
		target.target_name = str(default_distances[i]) + " Yard Target"
		target.is_active = false  # Only active target will be highlighted
		target.shot_landed_near_target.connect(_on_shot_landed_near_target)

		add_child(target)
		targets.append(target)

		# Initially hide all targets
		target.set_target_visible(false)

	# Set 150 yard target as default active (will show only this one)
	if targets.size() > 3:
		set_active_target(3)


## Set the active target (the one being aimed at)
func set_active_target(index: int) -> void:
	if index < 0 or index >= targets.size():
		return

	# Deactivate previous target
	if active_target:
		active_target.is_active = false
		active_target.set_highlighted(false)
		active_target.set_target_visible(false)  # Hide previous target

	# Activate new target
	active_target = targets[index]
	active_target.is_active = true
	active_target.set_highlighted(true)
	active_target.set_target_visible(true)  # Show only active target

	emit_signal("target_selected", active_target)


## Set active target by distance
func set_active_target_by_distance(distance: float) -> void:
	var closest_index = 0
	var closest_diff = abs(targets[0].target_distance - distance)

	for i in range(1, targets.size()):
		var diff = abs(targets[i].target_distance - distance)
		if diff < closest_diff:
			closest_diff = diff
			closest_index = i

	set_active_target(closest_index)


## Get active target
func get_active_target() -> TargetGreen:
	return active_target


## Get all targets
func get_all_targets() -> Array[TargetGreen]:
	return targets


## Cycle to next target
func next_target() -> void:
	if active_target == null or targets.is_empty():
		return

	var current_index = targets.find(active_target)
	var next_index = (current_index + 1) % targets.size()
	set_active_target(next_index)


## Cycle to previous target
func previous_target() -> void:
	if active_target == null or targets.is_empty():
		return

	var current_index = targets.find(active_target)
	var prev_index = (current_index - 1 + targets.size()) % targets.size()
	set_active_target(prev_index)


## Process a shot and check against active target
func process_shot(ball_position: Vector3) -> Dictionary:
	if active_target == null:
		return {}

	var result = active_target.check_shot(ball_position)

	if not result.is_empty():
		_update_session_stats(result)
		emit_signal("shot_scored", active_target.target_name, result.distance, result.score, result.zone)

	return result


## Update session statistics
func _update_session_stats(result: Dictionary) -> void:
	session_stats.total_shots += 1
	session_stats.total_score += result.score

	match result.zone:
		"Bullseye":
			session_stats.bullseyes += 1
		"Yellow":
			session_stats.yellow_hits += 1
		"Red":
			session_stats.red_hits += 1
		"White":
			session_stats.white_hits += 1
		"Outside":
			session_stats.misses += 1

	# Track best shot
	if result.distance < session_stats.best_shot_distance:
		session_stats.best_shot_distance = result.distance

	# Calculate running average distance
	var total_distance = session_stats.average_distance * (session_stats.total_shots - 1)
	total_distance += result.distance
	session_stats.average_distance = total_distance / session_stats.total_shots


## Signal handler for target hits
func _on_shot_landed_near_target(distance: float, score: int, zone: String) -> void:
	print("Shot landed in %s zone! Distance: %.1f yards, Score: %d" % [zone, distance, score])


## Get session statistics
func get_session_stats() -> Dictionary:
	return session_stats.duplicate()


## Reset session statistics
func reset_session_stats() -> void:
	session_stats = {
		"total_shots": 0,
		"total_score": 0,
		"bullseyes": 0,
		"yellow_hits": 0,
		"red_hits": 0,
		"white_hits": 0,
		"misses": 0,
		"best_shot_distance": INF,
		"average_distance": 0.0
	}


## Show/hide all targets
func set_targets_visible(visible: bool) -> void:
	for target in targets:
		target.set_target_visible(visible)


## Add custom target at specific distance
func add_custom_target(distance: float, name: String = "") -> TargetGreen:
	var target = TargetGreen.new()
	target.target_distance = distance
	target.target_name = name if name != "" else str(distance) + " Yard Target"
	target.is_active = false
	target.shot_landed_near_target.connect(_on_shot_landed_near_target)

	add_child(target)
	targets.append(target)

	return target


## Remove a target
func remove_target(target: TargetGreen) -> void:
	if target == active_target:
		active_target = null

	targets.erase(target)
	target.queue_free()


## Get target info for UI display
func get_active_target_info() -> Dictionary:
	if active_target == null:
		return {}

	return {
		"name": active_target.target_name,
		"distance": active_target.target_distance,
		"lateral_offset": active_target.lateral_offset,
		"bullseye_radius": active_target.bullseye_radius,
		"max_score_radius": active_target.white_radius
	}


## Adjust lateral aim (left/right)
func adjust_aim(yards: float) -> void:
	if active_target:
		active_target.lateral_offset += yards
		active_target._position_target()
		print("Aim adjusted: %.0f yards %s (total: %.0f)" % [abs(yards), "right" if yards > 0 else "left", active_target.lateral_offset])


## Reset aim to center
func reset_aim() -> void:
	if active_target:
		active_target.lateral_offset = 0.0
		active_target._position_target()
		print("Aim reset to center")
