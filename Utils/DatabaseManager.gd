extends Node

## Database Manager - handles all SQLite database operations.
## Provides persistence for players, sessions, shots, bags, and statistics.
## Implemented as an autoload singleton for global access.

const DB_PATH := "user://openshot_golf.db"
const SCHEMA_VERSION := 2
const MAX_CLUBS := 14

const ALL_CLUBS := [
	"Dr", "3w", "5w", "2H", "3H", "4H", "1i", "2i", "3i", "4i",
	"5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw"
]

const DEFAULT_BAG_CLUBS := [
	"Dr", "3w", "5w", "4H", "5i", "6i", "7i",
	"8i", "9i", "Pw", "Gw", "Sw", "Lw"
]

const PREDEFINED_SWING_TYPES := [
	["Full Swing", "Standard full power swing"],
	["Three-Quarter", "75% power swing for control"],
	["Half Swing", "50% power punch shot"],
	["Punch", "Low trajectory punch shot"],
	["Fade", "Intentional left-to-right shape"],
	["Draw", "Intentional right-to-left shape"],
	["Chip", "Short game chip shot"],
	["Pitch", "Short game pitch shot"]
]

var db: SQLite

signal database_ready
signal player_created(player_id: int)


# --- Lifecycle ---

func _ready() -> void:
	_init_database()
	print(OS.get_data_dir())


func _exit_tree() -> void:
	if db:
		db.close_db()


# --- Initialization ---

func _init_database() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()

	_create_tables()
	_check_migration()
	_seed_predefined_data()

	emit_signal("database_ready")
	print("DatabaseManager: Database initialized at ", DB_PATH)


func _create_tables() -> void:
	_create_schema_table()
	_create_player_tables()
	_create_bag_tables()
	_create_swing_type_tables()
	_create_session_tables()
	_create_shot_tables()


func _create_schema_table() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS schema_info (
			version INTEGER PRIMARY KEY,
			applied_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	""")


func _create_player_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS players (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL UNIQUE,
			handicap REAL DEFAULT 0.0,
			preferred_units INTEGER DEFAULT 1,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			is_guest INTEGER DEFAULT 0
		)
	""")


func _create_bag_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS bags (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			player_id INTEGER NOT NULL,
			name TEXT NOT NULL,
			is_default INTEGER DEFAULT 0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS bag_clubs (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			bag_id INTEGER NOT NULL,
			club_code TEXT NOT NULL,
			slot_number INTEGER NOT NULL,
			FOREIGN KEY (bag_id) REFERENCES bags(id) ON DELETE CASCADE,
			UNIQUE(bag_id, slot_number)
		)
	""")


func _create_swing_type_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS swing_types (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			player_id INTEGER,
			description TEXT,
			is_predefined INTEGER DEFAULT 0,
			FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
		)
	""")

	db.query("""
		CREATE UNIQUE INDEX IF NOT EXISTS unique_predefined_swing_name
		ON swing_types (name)
		WHERE is_predefined = 1;
	""")

	db.query("""
		CREATE UNIQUE INDEX IF NOT EXISTS unique_custom_swing_name_per_player
		ON swing_types (name, player_id)
		WHERE is_predefined = 0;
	""")


func _create_session_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS sessions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			player_id INTEGER NOT NULL,
			mode TEXT NOT NULL,
			started_at TEXT DEFAULT CURRENT_TIMESTAMP,
			ended_at TEXT,
			temperature REAL,
			altitude REAL,
			surface_type INTEGER,
			units INTEGER,
			FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
		)
	""")


func _create_shot_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS shots (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			session_id INTEGER NOT NULL,
			shot_number INTEGER NOT NULL,
			club_code TEXT NOT NULL,
			swing_type_id INTEGER,
			speed REAL,
			spin_axis REAL,
			total_spin REAL,
			back_spin REAL,
			side_spin REAL,
			hla REAL,
			vla REAL,
			carry_distance REAL,
			total_distance REAL,
			apex REAL,
			offline_distance REAL,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
			FOREIGN KEY (swing_type_id) REFERENCES swing_types(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS target_shots (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			shot_id INTEGER NOT NULL,
			target_distance REAL NOT NULL,
			distance_to_target REAL,
			score INTEGER,
			zone TEXT,
			FOREIGN KEY (shot_id) REFERENCES shots(id) ON DELETE CASCADE
		)
	""")


func _check_migration() -> void:
	db.query("SELECT MAX(version) as version FROM schema_info")
	var current_version := 0

	if db.query_result.size() > 0 and db.query_result[0].get("version") != null:
		current_version = db.query_result[0]["version"]

	if current_version < SCHEMA_VERSION:
		db.query_with_bindings(
			"INSERT OR REPLACE INTO schema_info (version) VALUES (?)",
			[SCHEMA_VERSION]
		)
		print("DatabaseManager: Schema updated to version ", SCHEMA_VERSION)


func _seed_predefined_data() -> void:
	db.query("SELECT id FROM swing_types WHERE is_predefined = 1 LIMIT 1")
	if db.query_result.size() > 0:
		return

	for swing in PREDEFINED_SWING_TYPES:
		db.query_with_bindings(
			"INSERT INTO swing_types (name, description, is_predefined) VALUES (?, ?, 1)",
			[swing[0], swing[1]]
		)


# --- Players ---

func create_player(player_name: String, is_guest := false) -> int:
	db.query_with_bindings(
		"INSERT INTO players (name, is_guest) VALUES (?, ?)",
		[player_name, 1 if is_guest else 0]
	)
	var player_id := db.last_insert_rowid

	_create_default_bag(player_id)

	emit_signal("player_created", player_id)
	return player_id


func get_player(player_id: int) -> Dictionary:
	db.query_with_bindings("SELECT * FROM players WHERE id = ?", [player_id])
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}


func get_player_by_name(player_name: String) -> Dictionary:
	db.query_with_bindings("SELECT * FROM players WHERE name = ?", [player_name])
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}


func get_all_players(include_guests := true) -> Array:
	if include_guests:
		db.query("SELECT * FROM players ORDER BY name")
	else:
		db.query("SELECT * FROM players WHERE is_guest = 0 ORDER BY name")
	return db.query_result


func update_player(player_id: int, data: Dictionary) -> bool:
	var sets: Array[String] = []
	var values: Array = []

	if data.has("name"):
		sets.append("name = ?")
		values.append(data["name"])
	if data.has("handicap"):
		sets.append("handicap = ?")
		values.append(data["handicap"])
	if data.has("preferred_units"):
		sets.append("preferred_units = ?")
		values.append(data["preferred_units"])

	if sets.is_empty():
		return false

	values.append(player_id)
	var query := "UPDATE players SET " + ", ".join(sets) + " WHERE id = ?"
	db.query_with_bindings(query, values)
	return true


func delete_player(player_id: int) -> bool:
	db.query_with_bindings("DELETE FROM players WHERE id = ?", [player_id])
	return true


# --- Bags ---

func create_bag(player_id: int, bag_name: String, clubs: Array) -> int:
	if clubs.size() > MAX_CLUBS:
		push_error("Cannot create bag with more than 14 clubs")
		return -1

	db.query_with_bindings(
		"INSERT INTO bags (player_id, name) VALUES (?, ?)",
		[player_id, bag_name]
	)
	var bag_id := db.last_insert_rowid

	for i in range(clubs.size()):
		db.query_with_bindings(
			"INSERT INTO bag_clubs (bag_id, club_code, slot_number) VALUES (?, ?, ?)",
			[bag_id, clubs[i], i + 1]
		)

	return bag_id


func get_player_bags(player_id: int) -> Array:
	db.query_with_bindings(
		"SELECT * FROM bags WHERE player_id = ? ORDER BY is_default DESC, name",
		[player_id]
	)
	return db.query_result


func get_bag_clubs(bag_id: int) -> Array:
	db.query_with_bindings(
		"SELECT club_code FROM bag_clubs WHERE bag_id = ? ORDER BY slot_number",
		[bag_id]
	)
	var clubs: Array = []
	for row in db.query_result:
		clubs.append(row["club_code"])
	return clubs


func update_bag(bag_id: int, clubs: Array) -> bool:
	if clubs.size() > MAX_CLUBS:
		push_error("Cannot update bag with more than 14 clubs")
		return false

	db.query_with_bindings("DELETE FROM bag_clubs WHERE bag_id = ?", [bag_id])

	for i in range(clubs.size()):
		db.query_with_bindings(
			"INSERT INTO bag_clubs (bag_id, club_code, slot_number) VALUES (?, ?, ?)",
			[bag_id, clubs[i], i + 1]
		)

	return true


func delete_bag(bag_id: int) -> bool:
	db.query_with_bindings("DELETE FROM bags WHERE id = ?", [bag_id])
	return true


func _create_default_bag(player_id: int) -> int:
	db.query_with_bindings(
		"INSERT INTO bags (player_id, name, is_default) VALUES (?, 'Default Bag', 1)",
		[player_id]
	)
	var bag_id := db.last_insert_rowid

	for i in range(DEFAULT_BAG_CLUBS.size()):
		db.query_with_bindings(
			"INSERT INTO bag_clubs (bag_id, club_code, slot_number) VALUES (?, ?, ?)",
			[bag_id, DEFAULT_BAG_CLUBS[i], i + 1]
		)

	return bag_id


# --- Swing Types ---

func get_swing_types(player_id := -1) -> Array:
	if player_id > 0:
		db.query_with_bindings(
			"SELECT * FROM swing_types WHERE is_predefined = 1 OR player_id = ? ORDER BY is_predefined DESC, name",
			[player_id]
		)
	else:
		db.query("SELECT * FROM swing_types WHERE is_predefined = 1 ORDER BY name")
	return db.query_result


func create_custom_swing_type(player_id: int, swing_name: String, description := "") -> int:
	db.query_with_bindings(
		"INSERT INTO swing_types (name, player_id, description, is_predefined) VALUES (?, ?, ?, 0)",
		[swing_name, player_id, description]
	)
	return db.last_insert_rowid


func delete_swing_type(swing_type_id: int) -> bool:
	db.query_with_bindings(
		"DELETE FROM swing_types WHERE id = ? AND is_predefined = 0",
		[swing_type_id]
	)
	return true


# --- Sessions ---

func create_session(
	player_id: int,
	mode: String,
	temperature := 0.0,
	altitude := 0.0,
	surface_type := 0,
	units := 1
) -> int:
	db.query_with_bindings(
		"INSERT INTO sessions (player_id, mode, temperature, altitude, surface_type, units) VALUES (?, ?, ?, ?, ?, ?)",
		[player_id, mode, temperature, altitude, surface_type, units]
	)
	return db.last_insert_rowid


func end_session(session_id: int) -> void:
	db.query_with_bindings(
		"UPDATE sessions SET ended_at = datetime('now') WHERE id = ?",
		[session_id]
	)


func get_session(session_id: int) -> Dictionary:
	db.query_with_bindings("SELECT * FROM sessions WHERE id = ?", [session_id])
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}


func get_player_sessions(player_id: int, limit := 50) -> Array:
	db.query_with_bindings(
		"SELECT * FROM sessions WHERE player_id = ? ORDER BY started_at DESC LIMIT ?",
		[player_id, limit]
	)
	return db.query_result


# --- Shots ---

func create_shot(session_id: int, data: Dictionary) -> int:
	db.query_with_bindings(
		"SELECT COALESCE(MAX(shot_number), 0) + 1 as next_num FROM shots WHERE session_id = ?",
		[session_id]
	)
	var shot_number: int = db.query_result[0]["next_num"]

	db.query_with_bindings("""
		INSERT INTO shots (session_id, shot_number, club_code, swing_type_id, speed, spin_axis,
			total_spin, back_spin, side_spin, hla, vla, carry_distance, total_distance, apex, offline_distance)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	""", [
		session_id,
		shot_number,
		data.get("club_code", "Dr"),
		data.get("swing_type_id", null),
		data.get("Speed", 0.0),
		data.get("SpinAxis", 0.0),
		data.get("TotalSpin", 0.0),
		data.get("BackSpin", 0.0),
		data.get("SideSpin", 0.0),
		data.get("HLA", 0.0),
		data.get("VLA", 0.0),
		data.get("CarryDistance", 0.0),
		data.get("TotalDistance", 0.0),
		data.get("Apex", 0.0),
		data.get("OfflineDistance", 0.0)
	])

	return db.last_insert_rowid


func create_target_shot(
	shot_id: int,
	target_distance: float,
	distance_to_target: float,
	score: int,
	zone: String
) -> int:
	db.query_with_bindings(
		"INSERT INTO target_shots (shot_id, target_distance, distance_to_target, score, zone) VALUES (?, ?, ?, ?, ?)",
		[shot_id, target_distance, distance_to_target, score, zone]
	)
	return db.last_insert_rowid


func get_session_shots(session_id: int) -> Array:
	db.query_with_bindings(
		"SELECT * FROM shots WHERE session_id = ? ORDER BY shot_number",
		[session_id]
	)
	return db.query_result


func get_session_target_shots(session_id: int) -> Array:
	db.query_with_bindings("""
		SELECT s.*, ts.target_distance, ts.distance_to_target, ts.score, ts.zone
		FROM shots s
		LEFT JOIN target_shots ts ON s.id = ts.shot_id
		WHERE s.session_id = ?
		ORDER BY s.shot_number
	""", [session_id])
	return db.query_result


func get_last_shot(session_id: int) -> Dictionary:
	db.query_with_bindings("""
		SELECT * FROM shots
		WHERE session_id = ?
		ORDER BY shot_number DESC
		LIMIT 1
	""", [session_id])
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}


func delete_shot(shot_id: int) -> bool:
	db.query_with_bindings("DELETE FROM shots WHERE id = ?", [shot_id])
	return true


# --- Club Statistics ---

func get_club_statistics(player_id: int, club_code: String) -> Dictionary:
	db.query_with_bindings("""
		SELECT
			COUNT(*) as shot_count,
			AVG(total_distance) as avg_distance,
			AVG(carry_distance) as avg_carry,
			MIN(total_distance) as min_distance,
			MAX(total_distance) as max_distance,
			AVG(offline_distance) as avg_offline,
			AVG(apex) as avg_apex
		FROM shots s
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ? AND s.club_code = ?
	""", [player_id, club_code])

	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}


func get_all_club_statistics(player_id: int) -> Dictionary:
	var stats := {}
	for club in ALL_CLUBS:
		var club_stats := get_club_statistics(player_id, club)
		if club_stats.get("shot_count", 0) > 0:
			stats[club] = club_stats
	return stats


func get_recent_club_shots(player_id: int, club_code: String, limit := 20) -> Array:
	db.query_with_bindings("""
		SELECT s.*
		FROM shots s
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ? AND s.club_code = ?
		ORDER BY s.created_at DESC
		LIMIT ?
	""", [player_id, club_code, limit])
	return db.query_result


# --- Player Statistics ---

func get_player_statistics(player_id: int) -> Dictionary:
	db.query_with_bindings("""
		SELECT COUNT(*) as total_rounds
		FROM sessions
		WHERE player_id = ?
	""", [player_id])

	var total_rounds := 0
	if db.query_result.size() > 0:
		total_rounds = db.query_result[0].get("total_rounds", 0)

	db.query_with_bindings("""
		SELECT AVG(shot_count) as avg_score
		FROM (
			SELECT session_id, COUNT(*) as shot_count
			FROM shots s
			JOIN sessions sess ON s.session_id = sess.id
			WHERE sess.player_id = ?
			GROUP BY session_id
		)
	""", [player_id])

	var avg_score := 0.0
	if db.query_result.size() > 0 and db.query_result[0].get("avg_score") != null:
		avg_score = db.query_result[0]["avg_score"]

	return {
		"total_rounds": total_rounds,
		"avg_score": avg_score
	}


func get_player_career_stats(player_id: int) -> Dictionary:
	var longest_drive := _get_longest_drive(player_id)
	var best_9_hole := _get_best_target_score(player_id)
	var gir_percentage := _get_accuracy_percentage(player_id)
	var eagles := _get_bullseye_count(player_id)

	return {
		"longest_drive": longest_drive,
		"best_9_hole": best_9_hole,
		"gir_percentage": gir_percentage,
		"eagles": eagles
	}


func _get_longest_drive(player_id: int) -> float:
	db.query_with_bindings("""
		SELECT MAX(total_distance) as longest_drive
		FROM shots s
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ? AND s.club_code = 'Dr'
	""", [player_id])

	if db.query_result.size() > 0 and db.query_result[0].get("longest_drive") != null:
		return db.query_result[0]["longest_drive"]
	return 0.0


func _get_best_target_score(player_id: int) -> int:
	db.query_with_bindings("""
		SELECT MAX(session_score) as best_score
		FROM (
			SELECT s.session_id, SUM(ts.score) as session_score
			FROM shots s
			JOIN target_shots ts ON s.id = ts.shot_id
			JOIN sessions sess ON s.session_id = sess.id
			WHERE sess.player_id = ?
			GROUP BY s.session_id
		)
	""", [player_id])

	if db.query_result.size() > 0 and db.query_result[0].get("best_score") != null:
		return db.query_result[0]["best_score"]
	return 0


func _get_accuracy_percentage(player_id: int) -> float:
	db.query_with_bindings("""
		SELECT
			COUNT(*) as total_shots,
			SUM(CASE WHEN ts.distance_to_target <= 20 THEN 1 ELSE 0 END) as accurate_shots
		FROM shots s
		JOIN target_shots ts ON s.id = ts.shot_id
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ?
	""", [player_id])

	if db.query_result.size() > 0:
		var total: int = db.query_result[0].get("total_shots", 0)
		var accurate: int = db.query_result[0].get("accurate_shots", 0)
		if total > 0:
			return (float(accurate) / float(total)) * 100.0
	return 0.0


func _get_bullseye_count(player_id: int) -> int:
	db.query_with_bindings("""
		SELECT COUNT(*) as eagles
		FROM shots s
		JOIN target_shots ts ON s.id = ts.shot_id
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ? AND ts.zone = 'Bullseye'
	""", [player_id])

	if db.query_result.size() > 0:
		return db.query_result[0].get("eagles", 0)
	return 0
