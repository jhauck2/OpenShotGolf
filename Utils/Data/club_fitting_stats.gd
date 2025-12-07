class_name ClubFittingStats
extends RefCounted

## Club Fitting Statistics Class
##
## Calculates and tracks statistics for shots with a specific club.
## Used by ClubFittingController to provide analysis.

var club_code: String = ""
var shots: Array[Dictionary] = []


## Add a shot to the statistics
func add_shot(data: Dictionary) -> void:
	shots.append(data)


## Get total shot count
func get_shot_count() -> int:
	return shots.size()


## Get average total distance
func get_average_distance() -> float:
	if shots.is_empty():
		return 0.0
	var total = 0.0
	for shot in shots:
		total += shot.get("TotalDistance", 0.0)
	return total / shots.size()


## Get average carry distance
func get_average_carry() -> float:
	if shots.is_empty():
		return 0.0
	var total = 0.0
	for shot in shots:
		total += shot.get("CarryDistance", 0.0)
	return total / shots.size()


## Get average ball speed
func get_average_speed() -> float:
	if shots.is_empty():
		return 0.0
	var total = 0.0
	for shot in shots:
		total += shot.get("Speed", 0.0)
	return total / shots.size()


## Get average apex height
func get_average_apex() -> float:
	if shots.is_empty():
		return 0.0
	var total = 0.0
	for shot in shots:
		total += shot.get("Apex", 0.0)
	return total / shots.size()


## Get standard deviation of total distance
func get_distance_std_dev() -> float:
	if shots.size() < 2:
		return 0.0
	var avg = get_average_distance()
	var sum_sq = 0.0
	for shot in shots:
		var diff = shot.get("TotalDistance", 0.0) - avg
		sum_sq += diff * diff
	return sqrt(sum_sq / shots.size())


## Get minimum total distance
func get_min_distance() -> float:
	if shots.is_empty():
		return 0.0
	var min_val = INF
	for shot in shots:
		min_val = min(min_val, shot.get("TotalDistance", 0.0))
	return min_val


## Get maximum total distance
func get_max_distance() -> float:
	if shots.is_empty():
		return 0.0
	var max_val = -INF
	for shot in shots:
		max_val = max(max_val, shot.get("TotalDistance", 0.0))
	return max_val


## Get distance range (max - min)
func get_distance_range() -> float:
	if shots.size() < 2:
		return 0.0
	return get_max_distance() - get_min_distance()


## Get dispersion (standard deviation of offline distance)
func get_dispersion() -> float:
	if shots.size() < 2:
		return 0.0
	var sum_sq = 0.0
	for shot in shots:
		var offline = shot.get("OfflineDistance", 0.0)
		sum_sq += offline * offline
	return sqrt(sum_sq / shots.size())


## Get average offline distance
func get_average_offline() -> float:
	if shots.is_empty():
		return 0.0
	var total = 0.0
	for shot in shots:
		total += shot.get("OfflineDistance", 0.0)
	return total / shots.size()


## Get average spin
func get_average_spin() -> float:
	if shots.is_empty():
		return 0.0
	var total = 0.0
	for shot in shots:
		total += shot.get("TotalSpin", 0.0)
	return total / shots.size()


## Get all statistics as a dictionary
func get_all_stats() -> Dictionary:
	return {
		"club_code": club_code,
		"shot_count": get_shot_count(),
		"avg_distance": get_average_distance(),
		"avg_carry": get_average_carry(),
		"avg_speed": get_average_speed(),
		"avg_apex": get_average_apex(),
		"min_distance": get_min_distance(),
		"max_distance": get_max_distance(),
		"distance_range": get_distance_range(),
		"std_dev": get_distance_std_dev(),
		"dispersion": get_dispersion(),
		"avg_offline": get_average_offline(),
		"avg_spin": get_average_spin()
	}


## Clear all shots
func clear() -> void:
	shots.clear()


## Remove the last shot (for undo functionality)
func remove_last_shot() -> bool:
	if shots.is_empty():
		return false
	shots.pop_back()
	return true


## Get the last N shots
func get_recent_shots(count: int) -> Array[Dictionary]:
	if shots.size() <= count:
		return shots.duplicate()
	return shots.slice(shots.size() - count)
