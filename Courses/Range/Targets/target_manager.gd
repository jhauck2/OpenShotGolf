class_name TargetManager
extends Node

## Target Manager - coordinates multiple target greens for target practice mode.
## Handles target creation, selection, scoring, and session statistics tracking.

const DEFAULT_TARGET_DISTANCES := [75, 100, 125, 150, 175, 200, 225, 250]
const DEFAULT_ACTIVE_INDEX := 3

signal target_selected(target: TargetGreen)
signal shot_scored(target_name: String, distance: float, score: int, zone: String)

var active_target: TargetGreen
var targets: Array[TargetGreen] = []
var targets_created := false

var session_stats := {
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


# --- Target Creation ---

func create_targets() -> void:
	if targets_created:
		return

	targets_created = true
	_create_default_targets()


func _create_default_targets() -> void:
	for i in range(DEFAULT_TARGET_DISTANCES.size()):
		var target := TargetGreen.new()
		target.target_distance = DEFAULT_TARGET_DISTANCES[i]
		target.target_name = str(DEFAULT_TARGET_DISTANCES[i]) + " Yard Target"
		target.is_active = false
		target.shot_landed_near_target.connect(_on_shot_landed_near_target)

		add_child(target)
		targets.append(target)
		target.set_target_visible(false)

	if targets.size() > DEFAULT_ACTIVE_INDEX:
		set_active_target(DEFAULT_ACTIVE_INDEX)


func add_custom_target(distance: float, custom_name := "") -> TargetGreen:
	var target := TargetGreen.new()
	target.target_distance = distance
	target.target_name = custom_name if custom_name != "" else str(distance) + " Yard Target"
	target.is_active = false
	target.shot_landed_near_target.connect(_on_shot_landed_near_target)

	add_child(target)
	targets.append(target)

	return target


func remove_target(target: TargetGreen) -> void:
	if target == active_target:
		active_target = null

	targets.erase(target)
	target.queue_free()


# --- Target Selection ---

func set_active_target(index: int) -> void:
	if index < 0 or index >= targets.size():
		return

	if active_target:
		active_target.is_active = false
		active_target.set_highlighted(false)
		active_target.set_target_visible(false)

	active_target = targets[index]
	active_target.is_active = true
	active_target.set_highlighted(true)
	active_target.set_target_visible(true)

	emit_signal("target_selected", active_target)


func set_active_target_by_distance(distance: float) -> void:
	var closest_index := 0
	var closest_diff: float = abs(targets[0].target_distance - distance)

	for i in range(1, targets.size()):
		var diff: float = abs(targets[i].target_distance - distance)
		if diff < closest_diff:
			closest_diff = diff
			closest_index = i

	set_active_target(closest_index)


func next_target() -> void:
	if active_target == null or targets.is_empty():
		return

	var current_index := targets.find(active_target)
	var next_index := (current_index + 1) % targets.size()
	set_active_target(next_index)


func previous_target() -> void:
	if active_target == null or targets.is_empty():
		return

	var current_index := targets.find(active_target)
	var prev_index := (current_index - 1 + targets.size()) % targets.size()
	set_active_target(prev_index)


# --- Shot Processing ---

func process_shot(ball_position: Vector3) -> Dictionary:
	if active_target == null:
		return {}

	var result := active_target.check_shot(ball_position)

	if not result.is_empty():
		_update_session_stats(result)
		emit_signal("shot_scored", active_target.target_name, result.distance, result.score, result.zone)

	return result


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

	if result.distance < session_stats.best_shot_distance:
		session_stats.best_shot_distance = result.distance

	var total_distance: float = session_stats.average_distance * (session_stats.total_shots - 1)
	total_distance += result.distance
	session_stats.average_distance = total_distance / session_stats.total_shots


# --- Signal Handlers ---

func _on_shot_landed_near_target(distance: float, score: int, zone: String) -> void:
	print("Shot landed in %s zone! Distance: %.1f yards, Score: %d" % [zone, distance, score])


# --- Statistics ---

func get_session_stats() -> Dictionary:
	return session_stats.duplicate()


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


# --- Aiming ---

func adjust_aim(yards: float) -> void:
	if active_target:
		active_target.lateral_offset += yards
		active_target._position_target()
		print("Aim adjusted: %.0f yards %s (total: %.0f)" % [
			abs(yards),
			"right" if yards > 0 else "left",
			active_target.lateral_offset
		])


func reset_aim() -> void:
	if active_target:
		active_target.lateral_offset = 0.0
		active_target._position_target()
		print("Aim reset to center")


# --- Display & Settings ---

func set_targets_visible(targets_visible: bool) -> void:
	for target in targets:
		target.set_target_visible(targets_visible)


func set_scoring_multiplier(multiplier: float) -> void:
	for target in targets:
		target.set_size_multiplier(multiplier)


# --- Getters ---

func get_active_target() -> TargetGreen:
	return active_target


func get_all_targets() -> Array[TargetGreen]:
	return targets


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
