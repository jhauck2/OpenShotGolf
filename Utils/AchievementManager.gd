extends Node

signal achievement_unlocked(player_name: String, achievement: Dictionary)
signal longest_drive_recorded(player_name: String, distance_yds: float, prev_distance_yds: float)

const SAVE_PATH = "user://player_achievements.json"

var achievements_db: Dictionary = {
	"first_par": {
		"id": "first_par",
		"title": "First Par",
		"description": "Complete a hole at equal to par",
		"badge_path": "res://assets/images/achievements/badge_first_par.svg",
		"category": "Hole",
		"rarity": "Common"
	},
	"first_birdie": {
		"id": "first_birdie",
		"title": "First Birdie",
		"description": "Complete a hole at 1-under par",
		"badge_path": "res://assets/images/achievements/badge_first_birdie.svg",
		"category": "Hole",
		"rarity": "Common"
	},
	"first_eagle": {
		"id": "first_eagle",
		"title": "First Eagle",
		"description": "Complete a hole at 2-under par",
		"badge_path": "res://assets/images/achievements/badge_first_eagle.svg",
		"category": "Hole",
		"rarity": "Rare"
	},
	"first_albatross": {
		"id": "first_albatross",
		"title": "Double Eagle",
		"description": "Complete a hole at 3-under par",
		"badge_path": "res://assets/images/achievements/badge_first_albatross.svg",
		"category": "Hole",
		"rarity": "Legendary"
	},
	"hole_in_one": {
		"id": "hole_in_one",
		"title": "Ace Master",
		"description": "Make a hole-in-one on any hole!",
		"badge_path": "res://assets/images/achievements/badge_hole_in_one.svg",
		"category": "Hole",
		"rarity": "Legendary"
	},
	"broke_100_18": {
		"id": "broke_100_18",
		"title": "Century Breaker",
		"description": "Shoot under 100 in an 18-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_100.svg",
		"category": "18-Hole",
		"rarity": "Common"
	},
	"broke_90_18": {
		"id": "broke_90_18",
		"title": "Sub-90 Club",
		"description": "Shoot under 90 in an 18-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_90.svg",
		"category": "18-Hole",
		"rarity": "Rare"
	},
	"broke_80_18": {
		"id": "broke_80_18",
		"title": "Single Digit Pace",
		"description": "Shoot under 80 in an 18-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_80.svg",
		"category": "18-Hole",
		"rarity": "Epic"
	},
	"broke_70_18": {
		"id": "broke_70_18",
		"title": "Scratch Golfer",
		"description": "Shoot under 70 in an 18-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_70.svg",
		"category": "18-Hole",
		"rarity": "Epic"
	},
	"broke_60_18": {
		"id": "broke_60_18",
		"title": "Legendary 59",
		"description": "Shoot under 60 in an 18-hole round!",
		"badge_path": "res://assets/images/achievements/badge_broke_60.svg",
		"category": "18-Hole",
		"rarity": "Legendary"
	},
	"pity_150_18": {
		"id": "pity_150_18",
		"title": "The Scenic Route",
		"description": "Shoot 150 or more strokes in an 18-hole round",
		"badge_path": "res://assets/images/achievements/badge_pity_150_18.svg",
		"category": "18-Hole",
		"rarity": "Common"
	},
	"broke_50_9": {
		"id": "broke_50_9",
		"title": "Half-Course Hero",
		"description": "Shoot under 50 in a 9-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_50_9.svg",
		"category": "9-Hole",
		"rarity": "Common"
	},
	"broke_45_9": {
		"id": "broke_45_9",
		"title": "Front/Back Specialist",
		"description": "Shoot under 45 in a 9-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_45_9.svg",
		"category": "9-Hole",
		"rarity": "Rare"
	},
	"broke_40_9": {
		"id": "broke_40_9",
		"title": "Sharp Shooter",
		"description": "Shoot under 40 in a 9-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_40_9.svg",
		"category": "9-Hole",
		"rarity": "Epic"
	},
	"broke_35_9": {
		"id": "broke_35_9",
		"title": "Under Par Nine",
		"description": "Shoot under 35 in a 9-hole round",
		"badge_path": "res://assets/images/achievements/badge_broke_35_9.svg",
		"category": "9-Hole",
		"rarity": "Epic"
	},
	"broke_30_9": {
		"id": "broke_30_9",
		"title": "Unstoppable Nine",
		"description": "Shoot under 30 in a 9-hole round!",
		"badge_path": "res://assets/images/achievements/badge_broke_30_9.svg",
		"category": "9-Hole",
		"rarity": "Legendary"
	},
	"pity_80_9": {
		"id": "pity_80_9",
		"title": "Honest Golfer",
		"description": "Shoot 80 or more strokes on a 9-hole round, front 9, or back 9",
		"badge_path": "res://assets/images/achievements/badge_pity_80_9.svg",
		"category": "9-Hole",
		"rarity": "Common"
	},
	"win_1_round": {
		"id": "win_1_round",
		"title": "First Victory",
		"description": "Win your first round of golf",
		"badge_path": "res://assets/images/achievements/badge_win_1.svg",
		"category": "Wins",
		"rarity": "Common"
	},
	"win_5_rounds": {
		"id": "win_5_rounds",
		"title": "5-Time Champion",
		"description": "Win 5 total rounds of golf",
		"badge_path": "res://assets/images/achievements/badge_win_5.svg",
		"category": "Wins",
		"rarity": "Rare"
	},
	"win_10_rounds": {
		"id": "win_10_rounds",
		"title": "Decathlon Winner",
		"description": "Win 10 total rounds of golf",
		"badge_path": "res://assets/images/achievements/badge_win_10.svg",
		"category": "Wins",
		"rarity": "Epic"
	},
	"win_50_rounds": {
		"id": "win_50_rounds",
		"title": "Hall of Famer",
		"description": "Win 50 total rounds of golf!",
		"badge_path": "res://assets/images/achievements/badge_win_50.svg",
		"category": "Wins",
		"rarity": "Legendary"
	},
	"long_drive": {
		"id": "long_drive",
		"title": "Bomb Dropper",
		"description": "Hit a drive exceeding 300 yards",
		"badge_path": "res://assets/images/achievements/badge_long_drive.svg",
		"category": "Special",
		"rarity": "Rare"
	},
	"putt_20_ft": {
		"id": "putt_20_ft",
		"title": "Clutch Roller",
		"description": "Drain a putt from 20+ feet out",
		"badge_path": "res://assets/images/achievements/badge_putt_20.svg",
		"category": "Special",
		"rarity": "Common"
	},
	"long_putt": {
		"id": "long_putt",
		"title": "Downtown Drain",
		"description": "Drain a putt from 30+ feet out",
		"badge_path": "res://assets/images/achievements/badge_long_putt.svg",
		"category": "Special",
		"rarity": "Rare"
	},
	"putt_40_ft": {
		"id": "putt_40_ft",
		"title": "Cross-Green Sniper",
		"description": "Drain a putt from 40+ feet out",
		"badge_path": "res://assets/images/achievements/badge_putt_40.svg",
		"category": "Special",
		"rarity": "Epic"
	},
	"putt_50_ft": {
		"id": "putt_50_ft",
		"title": "Astronomical Roll",
		"description": "Drain a putt from 50+ feet out",
		"badge_path": "res://assets/images/achievements/badge_putt_50.svg",
		"category": "Special",
		"rarity": "Legendary"
	},
	"chip_in_50": {
		"id": "chip_in_50",
		"title": "Iron Sharpshooter",
		"description": "Hole out from 50+ yards away using an iron",
		"badge_path": "res://assets/images/achievements/badge_chip_in_50.svg",
		"category": "Special",
		"rarity": "Rare"
	},
	"chip_in_75": {
		"id": "chip_in_75",
		"title": "Iron Magician",
		"description": "Hole out from 75+ yards away using an iron",
		"badge_path": "res://assets/images/achievements/badge_chip_in_75.svg",
		"category": "Special",
		"rarity": "Epic"
	},
	"chip_in_100": {
		"id": "chip_in_100",
		"title": "Iron Maestro",
		"description": "Hole out from 100+ yards away using an iron",
		"badge_path": "res://assets/images/achievements/badge_chip_in_100.svg",
		"category": "Special",
		"rarity": "Legendary"
	},
	"sand_save": {
		"id": "sand_save",
		"title": "Beach Escape",
		"description": "Make par or better after hitting out of a sand bunker",
		"badge_path": "res://assets/images/achievements/badge_sand_save.svg",
		"category": "Special",
		"rarity": "Rare"
	},
	"all_heckles": {
		"id": "all_heckles",
		"title": "Glutton for Punishment",
		"description": "Hear all the heckle lines in Heckle Golf Sim",
		"badge_path": "res://assets/images/achievements/badge_heckle_master.svg",
		"category": "Special",
		"rarity": "Legendary"
	},
	"all_achievements": {
		"id": "all_achievements",
		"title": "Grand Slam Champion",
		"description": "Unlock all other achievements in Heckle Golf Sim!",
		"badge_path": "res://assets/images/achievements/badge_all_achievements.svg",
		"category": "Special",
		"rarity": "Legendary"
	}
}

var _player_data: Dictionary = {}
var _popup_instance: Node = null
var _all_heckle_filepaths: Dictionary = {} # Set of String filepath -> true
var _total_heckles_count: int = 0
const HECKLE_PROMPTS_PATH = "res://assets/audio/heckler/heckle_prompts.json"
const PRAISE_CATEGORIES = ["under_par", "good_shot_fairway", "good_shot_green"]

func _ready() -> void:
	_player_data = _load_data()
	_load_heckle_definitions()
	call_deferred("_setup_popup_ui")
	call_deferred("_connect_announcer_engine")

func _connect_announcer_engine() -> void:
	if has_node("/root/AnnouncerEngine"):
		var announcer = get_node("/root/AnnouncerEngine")
		if announcer.has_signal("AudioLinePlayed") and not announcer.is_connected("AudioLinePlayed", _on_audio_line_played):
			announcer.connect("AudioLinePlayed", _on_audio_line_played)

func _load_heckle_definitions() -> void:
	_all_heckle_filepaths.clear()
	_total_heckles_count = 0
	if not FileAccess.file_exists(HECKLE_PROMPTS_PATH):
		return
	var file = FileAccess.open(HECKLE_PROMPTS_PATH, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var categories = json.data.get("categories", {})
		if typeof(categories) == TYPE_DICTIONARY:
			for cat_name in categories.keys():
				if cat_name in PRAISE_CATEGORIES:
					continue # Ignore praise categories
				var items = categories[cat_name]
				if typeof(items) == TYPE_ARRAY:
					for item in items:
						if typeof(item) == TYPE_DICTIONARY:
							var fp = item.get("filepath", "")
							if not fp.is_empty():
								_all_heckle_filepaths[fp] = true
	_total_heckles_count = _all_heckle_filepaths.size()

func _on_audio_line_played(category: String, filepath: String) -> void:
	record_heckle_line_heard("", filepath, category)

func _find_player_key(player_name: String) -> String:
	var clean = player_name.strip_edges()
	if clean.is_empty():
		return ""
	if _player_data.has(clean):
		return clean
	var lower = clean.to_lower()
	for k in _player_data.keys():
		if str(k).strip_edges().to_lower() == lower:
			return str(k)
	return ""

func _get_player_data(player_name: String) -> Dictionary:
	var key = _find_player_key(player_name)
	if not key.is_empty() and _player_data.has(key):
		var d = _player_data[key]
		if d is Dictionary:
			return d
	return {}

func record_heckle_line_heard(player_name: String, filepath: String, category: String = "") -> void:
	if filepath.is_empty():
		return
		
	# If category is praise, ignore
	if category in PRAISE_CATEGORIES:
		return
		
	# Ensure heckle definitions are loaded
	if _all_heckle_filepaths.is_empty():
		_load_heckle_definitions()
		
	# Check if this filepath is considered a heckle line
	if not _all_heckle_filepaths.is_empty() and not _all_heckle_filepaths.has(filepath):
		return

	# If player_name is not provided, use active player from MultiplayerManager
	if player_name.is_empty():
		if has_node("/root/MultiplayerManager"):
			var mp_mgr = get_node("/root/MultiplayerManager")
			if mp_mgr.has_method("get_active_player"):
				var active_p = mp_mgr.get_active_player()
				if typeof(active_p) == TYPE_DICTIONARY:
					player_name = active_p.get("name", "")

	if player_name.is_empty():
		player_name = "Player 1"

	var p_key = _find_player_key(player_name)
	if p_key.is_empty():
		p_key = player_name.strip_edges()
		_player_data[p_key] = {}

	var p_data = _player_data[p_key]
	if not p_data.has("heard_heckles") or typeof(p_data["heard_heckles"]) != TYPE_DICTIONARY:
		p_data["heard_heckles"] = {}

	if p_data["heard_heckles"].has(filepath):
		return # Already heard this line

	p_data["heard_heckles"][filepath] = Time.get_unix_time_from_system()
	_save_data()
	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", p_key)

	var heard_count = p_data["heard_heckles"].size()
	var total_target = _total_heckles_count if _total_heckles_count > 0 else 620
	if heard_count >= total_target:
		unlock_achievement(p_key, "all_heckles")

func get_heard_heckles_count(player_name: String) -> int:
	if player_name.is_empty():
		return 0
	var p_data = _get_player_data(player_name)
	var heard = p_data.get("heard_heckles", {})
	return heard.size() if typeof(heard) == TYPE_DICTIONARY else 0

func get_heard_heckles(player_name: String) -> Dictionary:
	if player_name.is_empty():
		player_name = "Player 1"
	var p_data = _get_player_data(player_name)
	var heard = p_data.get("heard_heckles", {})
	return heard if typeof(heard) == TYPE_DICTIONARY else {}

func is_heckle_heard(player_name: String, filepath: String) -> bool:
	if player_name.is_empty():
		player_name = "Player 1"
	var p_data = _get_player_data(player_name)
	var heard = p_data.get("heard_heckles", {})
	return typeof(heard) == TYPE_DICTIONARY and heard.has(filepath)

func get_total_heckles_count() -> int:
	if _total_heckles_count <= 0:
		_load_heckle_definitions()
	return _total_heckles_count if _total_heckles_count > 0 else 620

func _setup_popup_ui() -> void:
	if _popup_instance != null and is_instance_valid(_popup_instance):
		return
	var ach_popup_scene = load("res://UI/AchievementPopup/achievement_popup.tscn")
	if ach_popup_scene != null:
		_popup_instance = ach_popup_scene.instantiate()
		add_child(_popup_instance)

func is_showing_achievement() -> bool:
	if _popup_instance != null and is_instance_valid(_popup_instance):
		if _popup_instance.has_method("is_showing_achievement"):
			return bool(_popup_instance.call("is_showing_achievement"))
	return false

func _load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}

func _save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_player_data, "\t"))

func get_all_achievements() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var order = [
		"first_par", "first_birdie", "first_eagle", "first_albatross", "hole_in_one",
		"broke_100_18", "broke_90_18", "broke_80_18", "broke_70_18", "broke_60_18", "pity_150_18",
		"broke_50_9", "broke_45_9", "broke_40_9", "broke_35_9", "broke_30_9", "pity_80_9",
		"win_1_round", "win_5_rounds", "win_10_rounds", "win_50_rounds",
		"long_drive", "putt_20_ft", "long_putt", "putt_40_ft", "putt_50_ft",
		"chip_in_50", "chip_in_75", "chip_in_100",
		"sand_save", "all_heckles", "all_achievements"
	]
	for id in order:
		if achievements_db.has(id):
			list.append(achievements_db[id])
	return list

func get_unlocked_achievements(player_name: String) -> Dictionary:
	if player_name.is_empty():
		return {}
	var p_data = _get_player_data(player_name)
	var unlocked: Dictionary = {}
	for k in p_data.keys():
		if k == "heard_heckles":
			continue
		if achievements_db.has(k):
			unlocked[k] = p_data[k]
	return unlocked

func is_unlocked(player_name: String, ach_id: String) -> bool:
	if player_name.is_empty() or not achievements_db.has(ach_id):
		return false
	var p_ach = _get_player_data(player_name)
	return p_ach.has(ach_id) and ach_id != "heard_heckles"

func unlock_achievement(player_name: String, ach_id: String) -> bool:
	if player_name.is_empty() or not achievements_db.has(ach_id):
		return false
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		for p in mp.players:
			if str(p.get("name", "")).strip_edges().to_lower() == player_name.strip_edges().to_lower() and p.get("is_remote", false):
				return false
		
	var p_key = _find_player_key(player_name)
	if p_key.is_empty():
		p_key = player_name.strip_edges()
		_player_data[p_key] = {}
		
	if _player_data[p_key].has(ach_id):
		return false # Already unlocked
		
	var ach_def = achievements_db[ach_id]
	_player_data[p_key][ach_id] = {
		"unlocked_at": Time.get_unix_time_from_system()
	}
	_save_data()
	if has_node("/root/CloudSync"):
		get_node("/root/CloudSync").call("mark_profile_dirty", p_key)
	
	print("[AchievementManager] Unlocked '%s' (%s) for player '%s'!" % [ach_def.title, ach_id, p_key])
	emit_signal("achievement_unlocked", p_key, ach_def)
	
	if ach_id != "all_achievements":
		_check_all_achievements_unlocked(p_key)
		
	return true

func _check_all_achievements_unlocked(player_name: String) -> void:
	if player_name.is_empty() or is_unlocked(player_name, "all_achievements"):
		return
	var p_ach = _get_player_data(player_name)
	for aid in achievements_db.keys():
		if aid == "all_achievements":
			continue
		if not p_ach.has(aid):
			return
	unlock_achievement(player_name, "all_achievements")

func is_iron_club(club_name: String) -> bool:
	var c = club_name.strip_edges().to_lower()
	if c.is_empty():
		return false
	if c in ["1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i"]:
		return true
	if c in ["1 iron", "2 iron", "3 iron", "4 iron", "5 iron", "6 iron", "7 iron", "8 iron", "9 iron"]:
		return true
	if c in ["1-iron", "2-iron", "3-iron", "4-iron", "5-iron", "6-iron", "7-iron", "8-iron", "9-iron"]:
		return true
	if c.ends_with("iron") or (c.length() == 2 and c.ends_with("i")):
		if not (c in ["dr", "driver", "1w", "3w", "5w", "7w", "pt", "putt", "putter", "pw", "gw", "sw", "lw", "aw", "pitching wedge", "sand wedge", "lob wedge", "gap wedge", "2h", "3h", "4h", "5h", "hybrid"]):
			return true
	return false

# --- Evaluation Helpers ---

func check_hole_achievements(player_name: String, hole_par: int, strokes: int, lies_in_hole: Array = [], putt_dist_yards: float = 0.0, holed_in_cup: bool = false, club_name: String = "", shot_dist_yards: float = 0.0) -> void:
	if player_name.is_empty() or strokes <= 0:
		return
		
	# Hole-in-One (must go into the actual cup, never from a gimme)
	if holed_in_cup and strokes == 1:
		unlock_achievement(player_name, "hole_in_one")
		
	var diff = strokes - hole_par
	if diff == 0:
		unlock_achievement(player_name, "first_par")
	elif diff == -1:
		# Birdie requires ball entering the actual cup, no gimmes
		if holed_in_cup:
			unlock_achievement(player_name, "first_birdie")
	elif diff == -2:
		# Eagle requires ball entering the actual cup, no gimmes
		if holed_in_cup:
			unlock_achievement(player_name, "first_eagle")
	elif diff <= -3:
		# Albatross / Double Eagle requires ball entering the actual cup, no gimmes
		if holed_in_cup:
			unlock_achievement(player_name, "first_albatross")
		
	# Putting milestones: 20+ ft, 30+ ft (Downtown Drain), 40+ ft, 50+ ft
	var c_lower = club_name.strip_edges().to_lower()
	var is_putter = c_lower in ["pt", "putt", "putter"] or c_lower.begins_with("putt")
	if holed_in_cup and is_putter and putt_dist_yards > 0.0:
		var putt_feet = putt_dist_yards * 3.0
		if putt_feet >= 20.0 or putt_dist_yards >= (20.0 / 3.0 - 0.01):
			unlock_achievement(player_name, "putt_20_ft")
		if putt_dist_yards >= 10.0 or putt_feet >= 30.0:
			unlock_achievement(player_name, "long_putt")
		if putt_feet >= 40.0 or putt_dist_yards >= (40.0 / 3.0 - 0.01):
			unlock_achievement(player_name, "putt_40_ft")
		if putt_feet >= 50.0 or putt_dist_yards >= (50.0 / 3.0 - 0.01):
			unlock_achievement(player_name, "putt_50_ft")

	# Iron chip-in / hole-out milestones: 50+ yds, 75+ yds, 100+ yds (only earnable when using an iron)
	var dist_for_chip = shot_dist_yards
	if dist_for_chip <= 0.0 and putt_dist_yards > 0.0:
		dist_for_chip = putt_dist_yards
	if holed_in_cup and is_iron_club(club_name):
		if dist_for_chip >= 50.0:
			unlock_achievement(player_name, "chip_in_50")
		if dist_for_chip >= 75.0:
			unlock_achievement(player_name, "chip_in_75")
		if dist_for_chip >= 100.0:
			unlock_achievement(player_name, "chip_in_100")
		
	# Sand save: Par or better after hitting out of a bunker
	if diff <= 0 and "bunker" in lies_in_hole:
		unlock_achievement(player_name, "sand_save")

func check_shot_achievements(player_name: String, club_name: String, total_yards: float, prev_longest_drive: float = -1.0) -> void:
	if player_name.is_empty():
		return
	var is_driver = (club_name.begins_with("Dr") or club_name.to_lower() in ["driver", "1w", "dr"])
	if total_yards >= 300.0 and is_driver:
		unlock_achievement(player_name, "long_drive")
		
	# Check longest drive personal record
	if is_driver and total_yards > 0.0:
		var prev_best = prev_longest_drive
		if prev_best < 0.0 and has_node("/root/MultiplayerManager"):
			var mp_mgr = get_node("/root/MultiplayerManager")
			if mp_mgr.has_method("get_player_longest_drive"):
				prev_best = mp_mgr.get_player_longest_drive(player_name)
			elif mp_mgr.has_method("calculate_player_stats"):
				var stats = mp_mgr.calculate_player_stats(player_name)
				prev_best = float(stats.get("longest_drive", 0.0))
		
		# If the new shot surpasses previous best (or is a valid qualifying drive >= 150 yds if no previous record)
		if total_yards > prev_best and (prev_best > 0.0 or total_yards >= 150.0):
			emit_signal("longest_drive_recorded", player_name, total_yards, prev_best)

func check_round_achievements(player_name: String, total_strokes: int, hole_count: int, is_winner: bool, total_wins: int, front_9_strokes: int = 0, back_9_strokes: int = 0) -> void:
	if player_name.is_empty() or total_strokes <= 0:
		return
		
	# 18-hole milestones
	if hole_count >= 18:
		if total_strokes < 100:
			unlock_achievement(player_name, "broke_100_18")
		if total_strokes < 90:
			unlock_achievement(player_name, "broke_90_18")
		if total_strokes < 80:
			unlock_achievement(player_name, "broke_80_18")
		if total_strokes < 70:
			unlock_achievement(player_name, "broke_70_18")
		if total_strokes < 60:
			unlock_achievement(player_name, "broke_60_18")
		if total_strokes >= 150:
			unlock_achievement(player_name, "pity_150_18")
			
	# 9-hole milestones
	if hole_count >= 9 and hole_count < 18:
		if total_strokes < 50:
			unlock_achievement(player_name, "broke_50_9")
		if total_strokes < 45:
			unlock_achievement(player_name, "broke_45_9")
		if total_strokes < 40:
			unlock_achievement(player_name, "broke_40_9")
		if total_strokes < 35:
			unlock_achievement(player_name, "broke_35_9")
		if total_strokes < 30:
			unlock_achievement(player_name, "broke_30_9")
		if total_strokes >= 80:
			unlock_achievement(player_name, "pity_80_9")
			
	# Front 9 / Back 9 specific check (whether 9 holes or 18 holes)
	if front_9_strokes >= 80 or back_9_strokes >= 80:
		unlock_achievement(player_name, "pity_80_9")

	# Win milestones
	if is_winner:
		unlock_achievement(player_name, "win_1_round")
		if total_wins >= 5:
			unlock_achievement(player_name, "win_5_rounds")
		if total_wins >= 10:
			unlock_achievement(player_name, "win_10_rounds")
		if total_wins >= 50:
			unlock_achievement(player_name, "win_50_rounds")

