extends Node
## Global GameState - Persists mode, target, and session data across layout switches
## This is an autoload singleton that maintains state throughout the game session
## Access via: GameState.method_name() or GameState.property_name

# Mode enumeration
enum RangeMode {
	FREE_PRACTICE = 0,
	TARGET_PRACTICE = 1
}

# ===== MODE & TARGET STATE =====
var current_mode: int = 0  # 0 = FREE_PRACTICE, 1 = TARGET_PRACTICE
var current_target_name: String = ""
var current_target_distance: float = 0.0
var current_target_index: int = 0

# ===== CLUB SELECTION =====
var current_club: String = "Dr"
var available_clubs: Array[String] = ["Dr", "3w", "5w", "2H", "4H", "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw"]

# ===== SHOT HISTORY =====
var shot_history: Array[Dictionary] = []
var max_history_size: int = 20  # Keep last 20 shots

# ===== SESSION STATISTICS =====
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

# ===== CURRENT SHOT DATA =====
var current_shot_data: Dictionary = {
	"Distance": "---",
	"Carry": "---",
	"Offline": "---",
	"Apex": "---",
	"VLA": 0.0,
	"HLA": 0.0,
	"Points": "---"
}

# ===== SIGNALS =====
signal mode_changed(new_mode: int)
signal target_changed(target_name: String, distance: float)
signal club_selected(club: String)
signal shot_recorded(shot_data: Dictionary)
signal shot_data_updated(data: Dictionary)
signal session_reset

func _ready() -> void:
	""""""


func set_mode(mode: int) -> void:
	"""Change the current mode"""
	if current_mode != mode:
		current_mode = mode
		emit_signal("mode_changed", mode)


func toggle_mode() -> void:
	"""Toggle between FREE_PRACTICE and TARGET_PRACTICE"""
	var new_mode = 1 if current_mode == 0 else 0  # 0 = FREE_PRACTICE, 1 = TARGET_PRACTICE
	set_mode(new_mode)


func set_target(target_name: String, distance: float, index: int = 0) -> void:
	"""Update current target info"""
	current_target_name = target_name
	current_target_distance = distance
	current_target_index = index
	emit_signal("target_changed", target_name, distance)


func update_session_stats(stats: Dictionary) -> void:
	"""Update session statistics from target manager"""
	session_stats = stats.duplicate()


func record_shot(shot_data: Dictionary) -> void:
	"""Record a shot in the session"""
	emit_signal("shot_recorded", shot_data)

func get_mode_text() -> String:
	"""Get human-readable mode text"""
	return "TARGET PRACTICE" if current_mode == 1 else "FREE PRACTICE"  # 1 = TARGET_PRACTICE


func get_target_text() -> String:
	"""Get target display text"""
	if current_mode == 0:  # FREE_PRACTICE
		return ""
	return "%s - %.0f yards" % [current_target_name, current_target_distance]


func get_total_points() -> int:
	"""Get total session points"""
	return session_stats.get("total_score", 0)


# ===== CLUB MANAGEMENT =====

func set_club(club: String) -> void:
	"""Set the current club"""
	if club in available_clubs:
		current_club = club
		emit_signal("club_selected", club)
	else:
		push_warning("Invalid club: %s" % club)


func next_club() -> void:
	"""Cycle to next club"""
	var current_index = available_clubs.find(current_club)
	var next_index = (current_index + 1) % available_clubs.size()
	set_club(available_clubs[next_index])


func previous_club() -> void:
	"""Cycle to previous club"""
	var current_index = available_clubs.find(current_club)
	var prev_index = (current_index - 1 + available_clubs.size()) % available_clubs.size()
	set_club(available_clubs[prev_index])


# ===== SHOT DATA MANAGEMENT =====

func update_shot_data(data: Dictionary) -> void:
	"""Update current shot data (called every frame during flight)"""
	current_shot_data = current_shot_data.duplicate()
	current_shot_data.merge(data)
	emit_signal("shot_data_updated", current_shot_data)


func clear_shot_data() -> void:
	"""Clear shot data between shots"""
	current_shot_data = {
		"Distance": "---",
		"Carry": "---",
		"Offline": "---",
		"Apex": "---",
		"VLA": 0.0,
		"HLA": 0.0,
		"Points": "---"
	}


# ===== SHOT HISTORY MANAGEMENT =====

func add_to_history(shot_entry: Dictionary) -> void:
	"""Add shot to history"""
	shot_history.push_front(shot_entry)

	# Keep only max_history_size entries
	if shot_history.size() > max_history_size:
		shot_history.resize(max_history_size)

	emit_signal("shot_recorded", shot_entry)


func clear_history() -> void:
	"""Clear all shot history"""
	shot_history.clear()


func get_last_shot() -> Dictionary:
	"""Get the most recent shot from history"""
	if shot_history.is_empty():
		return {}
	return shot_history[0]


func get_shot_history() -> Array[Dictionary]:
	"""Get all shot history"""
	return shot_history.duplicate()


# ===== SESSION MANAGEMENT =====

func reset_session() -> void:
	"""Reset all session statistics"""
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
	clear_history()
	emit_signal("session_reset")
