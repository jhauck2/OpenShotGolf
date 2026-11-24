class_name TrainingProgressStore
extends RefCounted

## Persists player drill personal bests and recent training session summaries
## to user://training_progress.json (or a custom path during tests).

const DEFAULT_PROGRESS_PATH := "user://training_progress.json"
const MAX_RECENT_SESSIONS := 25
const GRADE_RANK := {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1}


static func load_all(path: String = DEFAULT_PROGRESS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"players": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"players": {}}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {"players": {}}
	var parser := JSON.new()
	if parser.parse(text) == OK and typeof(parser.data) == TYPE_DICTIONARY:
		var parsed: Dictionary = parser.data
		if not parsed.has("players") or typeof(parsed["players"]) != TYPE_DICTIONARY:
			parsed["players"] = {}
		return parsed
	return {"players": {}}


static func save_all(data: Dictionary, path: String = DEFAULT_PROGRESS_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func _find_player_key(players_dict: Dictionary, player_name: String) -> String:
	var target := player_name.strip_edges().to_lower()
	for k in players_dict.keys():
		if str(k).strip_edges().to_lower() == target:
			return str(k)
	return ""


static func get_player_progress(player_name: String, path: String = DEFAULT_PROGRESS_PATH) -> Dictionary:
	var all_data := load_all(path)
	var players_dict: Dictionary = all_data.get("players", {})
	var key := _find_player_key(players_dict, player_name)
	if key.is_empty():
		return {"drills": {}, "recent_sessions": []}
	var p_data: Dictionary = players_dict.get(key, {})
	if typeof(p_data) != TYPE_DICTIONARY:
		return {"drills": {}, "recent_sessions": []}
	return {
		"drills": p_data.get("drills", {}).duplicate(true) if typeof(p_data.get("drills", {})) == TYPE_DICTIONARY else {},
		"recent_sessions": p_data.get("recent_sessions", []).duplicate(true) if typeof(p_data.get("recent_sessions", [])) == TYPE_ARRAY else []
	}


static func get_drill_best(player_name: String, drill_id: String, path: String = DEFAULT_PROGRESS_PATH) -> Dictionary:
	var p_prog := get_player_progress(player_name, path)
	var drills: Dictionary = p_prog.get("drills", {})
	if drills.has(drill_id) and typeof(drills[drill_id]) == TYPE_DICTIONARY:
		return drills[drill_id].duplicate(true)
	return {}


static func _is_better_grade(new_grade: String, old_grade: String) -> bool:
	var n_rank := int(GRADE_RANK.get(new_grade, 0))
	var o_rank := int(GRADE_RANK.get(old_grade, 0))
	return n_rank > o_rank


static func record_session(
	player_name: String,
	drill_id: String,
	summary: Dictionary,
	difficulty: String = "standard",
	path: String = DEFAULT_PROGRESS_PATH
) -> Dictionary:
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player 1"

	var all_data := load_all(path)
	var players_dict: Dictionary = all_data.get("players", {})
	var existing_key := _find_player_key(players_dict, clean_name)
	var target_key := existing_key if not existing_key.is_empty() else clean_name

	if not players_dict.has(target_key) or typeof(players_dict[target_key]) != TYPE_DICTIONARY:
		players_dict[target_key] = {"drills": {}, "recent_sessions": []}

	var p_entry: Dictionary = players_dict[target_key]
	if not p_entry.has("drills") or typeof(p_entry["drills"]) != TYPE_DICTIONARY:
		p_entry["drills"] = {}
	if not p_entry.has("recent_sessions") or typeof(p_entry["recent_sessions"]) != TYPE_ARRAY:
		p_entry["recent_sessions"] = []

	var drills_dict: Dictionary = p_entry["drills"]
	var prev_best: Dictionary = drills_dict.get(drill_id, {}) if typeof(drills_dict.get(drill_id, {})) == TYPE_DICTIONARY else {}

	var score := int(summary.get("total_score", 0))
	var accuracy := float(summary.get("avg_accuracy", 0.0))
	var grade := str(summary.get("grade", "D"))
	var max_streak := int(summary.get("max_streak", 0))
	var now_unix := int(Time.get_unix_time_from_system())

	var prev_score := int(prev_best.get("best_score", -1))
	var prev_grade := str(prev_best.get("best_grade", ""))
	var is_new_best_score := prev_best.is_empty() or score > prev_score
	var is_new_best_grade := prev_best.is_empty() or _is_better_grade(grade, prev_grade)

	var updated_best := {
		"best_score": maxi(score, prev_score),
		"best_grade": grade if is_new_best_grade else prev_grade,
		"best_accuracy": maxf(accuracy, float(prev_best.get("best_accuracy", 0.0))),
		"best_streak": maxi(max_streak, int(prev_best.get("best_streak", 0))),
		"sessions_completed": int(prev_best.get("sessions_completed", 0)) + 1,
		"last_played_at": now_unix,
		"last_accuracy": accuracy,
		"last_grade": grade,
		"last_difficulty": difficulty
	}
	drills_dict[drill_id] = updated_best

	var recent_sessions: Array = p_entry["recent_sessions"]
	recent_sessions.push_front({
		"drill_id": drill_id,
		"score": score,
		"grade": grade,
		"accuracy": snappedf(accuracy, 0.1),
		"max_streak": max_streak,
		"difficulty": difficulty,
		"timestamp": now_unix
	})
	while recent_sessions.size() > MAX_RECENT_SESSIONS:
		recent_sessions.pop_back()

	all_data["players"] = players_dict
	save_all(all_data, path)

	return {
		"is_new_best_score": is_new_best_score,
		"is_new_best_grade": is_new_best_grade,
		"best": updated_best
	}
