extends Control

## Stats & Analytics Screen
## Displays player statistics, club performance, and session history from the database.

# UI References
@onready var stats_grid: GridContainer = %StatsGrid
@onready var tab_container: TabContainer = %TabContainer
@onready var club_filter: OptionButton = %ClubFilter
@onready var date_filter: OptionButton = %DateFilter

# Stat card references (will be found dynamically)
var stat_cards: Dictionary = {}

# Current filter state
var current_player_id: int = -1
var current_date_range: int = 30  # days
var current_club_filter: String = "all"


func _ready() -> void:
	_setup_filters()
	_find_stat_cards()
	_load_player_stats()
	_load_club_performance()
	_load_recent_sessions()


func _setup_filters() -> void:
	# Setup date filter options
	if date_filter:
		date_filter.clear()
		date_filter.add_item("Last 7 Days", 7)
		date_filter.add_item("Last 30 Days", 30)
		date_filter.add_item("Last 90 Days", 90)
		date_filter.add_item("Last Year", 365)
		date_filter.add_item("All Time", -1)
		date_filter.select(1)  # Default to 30 days
		date_filter.item_selected.connect(_on_date_filter_changed)

	# Setup club filter options
	if club_filter:
		club_filter.clear()
		club_filter.add_item("All Clubs")
		club_filter.add_item("Driver")
		club_filter.add_item("Woods")
		club_filter.add_item("Irons")
		club_filter.add_item("Wedges")
		club_filter.item_selected.connect(_on_club_filter_changed)


func _find_stat_cards() -> void:
	# Find stat cards in the StatsGrid by looking for Value labels
	if not stats_grid:
		return

	for child in stats_grid.get_children():
		if child is PanelContainer:
			var value_label = child.find_child("Value", true, false)
			var title_label = child.find_child("Label", true, false)
			if value_label and title_label:
				stat_cards[title_label.text] = value_label


func _load_player_stats() -> void:
	current_player_id = GlobalSettings.get_current_player_id()
	if current_player_id <= 0:
		_show_empty_stats()
		return

	# Get player statistics from database
	var player_stats = DatabaseManager.get_player_statistics(current_player_id)
	var career_stats = DatabaseManager.get_player_career_stats(current_player_id)

	# Calculate total shots
	var total_shots = _get_total_shots()
	_update_stat_card("Total Shots", _format_number(total_shots))

	# Sessions count
	var sessions = player_stats.get("total_rounds", 0)
	_update_stat_card("Sessions", str(sessions))

	# Average score (from target practice)
	var avg_score = _get_average_target_score()
	_update_stat_card("Avg Score", str(int(avg_score)) if avg_score > 0 else "---")

	# Best score
	var best_score = career_stats.get("best_9_hole", 0)
	_update_stat_card("Best Score", str(best_score) if best_score > 0 else "---")

	# Favorite club
	var favorite_club = _get_favorite_club()
	_update_stat_card("Favorite Club", favorite_club if favorite_club else "---")

	# Total distance
	var total_distance = _get_total_distance()
	_update_stat_card("Total Distance", _format_distance(total_distance))


func _update_stat_card(title: String, value: String) -> void:
	if stat_cards.has(title):
		stat_cards[title].text = value


func _get_total_shots() -> int:
	if current_player_id <= 0:
		return 0

	var sessions = DatabaseManager.get_player_sessions(current_player_id, 1000)
	var total = 0
	for session in sessions:
		var shots = DatabaseManager.get_session_shots(session.id)
		total += shots.size()
	return total


func _get_average_target_score() -> float:
	if current_player_id <= 0:
		return 0.0

	DatabaseManager.db.query_with_bindings("""
		SELECT AVG(session_score) as avg_score
		FROM (
			SELECT s.session_id, SUM(ts.score) as session_score
			FROM shots s
			JOIN target_shots ts ON s.id = ts.shot_id
			JOIN sessions sess ON s.session_id = sess.id
			WHERE sess.player_id = ?
			GROUP BY s.session_id
		)
	""", [current_player_id])

	if DatabaseManager.db.query_result.size() > 0:
		var result = DatabaseManager.db.query_result[0].get("avg_score")
		if result != null:
			return result
	return 0.0


func _get_favorite_club() -> String:
	if current_player_id <= 0:
		return ""

	DatabaseManager.db.query_with_bindings("""
		SELECT club_code, COUNT(*) as count
		FROM shots s
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ?
		GROUP BY club_code
		ORDER BY count DESC
		LIMIT 1
	""", [current_player_id])

	if DatabaseManager.db.query_result.size() > 0:
		return DatabaseManager.db.query_result[0].get("club_code", "")
	return ""


func _get_total_distance() -> float:
	if current_player_id <= 0:
		return 0.0

	DatabaseManager.db.query_with_bindings("""
		SELECT SUM(total_distance) as total
		FROM shots s
		JOIN sessions sess ON s.session_id = sess.id
		WHERE sess.player_id = ?
	""", [current_player_id])

	if DatabaseManager.db.query_result.size() > 0:
		var result = DatabaseManager.db.query_result[0].get("total")
		if result != null:
			return result
	return 0.0


func _load_club_performance() -> void:
	if current_player_id <= 0:
		return

	var club_tab = tab_container.get_node_or_null("Club Performance")
	if not club_tab:
		return

	# Clear existing rows except template
	for child in club_tab.get_children():
		if child.name != "HeaderRow":
			child.queue_free()

	# Get all club statistics
	var all_stats = DatabaseManager.get_all_club_statistics(current_player_id)

	for club_code in all_stats.keys():
		var stats = all_stats[club_code]
		if stats.get("shot_count", 0) > 0:
			var row = _create_club_row(club_code, stats)
			club_tab.add_child(row)


func _create_club_row(club_code: String, stats: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	# Club name
	var name_label = Label.new()
	name_label.text = club_code
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_label)

	# Shot count
	var shots_label = Label.new()
	shots_label.text = "%d shots" % stats.get("shot_count", 0)
	shots_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71))
	shots_label.add_theme_font_size_override("font_size", 12)
	row.add_child(shots_label)

	# Avg carry
	var carry_label = Label.new()
	carry_label.text = "%.0fy" % stats.get("avg_carry", 0)
	carry_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71))
	row.add_child(carry_label)

	# Avg total
	var total_label = Label.new()
	total_label.text = "%.0fy" % stats.get("avg_distance", 0)
	total_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71))
	row.add_child(total_label)

	return row


func _load_recent_sessions() -> void:
	if current_player_id <= 0:
		return

	var sessions_tab = tab_container.get_node_or_null("Sessions")
	if not sessions_tab:
		return

	# Clear existing rows
	for child in sessions_tab.get_children():
		child.queue_free()

	# Get recent sessions
	var sessions = DatabaseManager.get_player_sessions(current_player_id, 10)

	if sessions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No sessions yet. Start practicing!"
		empty_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71))
		sessions_tab.add_child(empty_label)
		return

	for session in sessions:
		var row = _create_session_row(session)
		sessions_tab.add_child(row)


func _create_session_row(session: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	# Info container
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Mode name
	var mode_label = Label.new()
	mode_label.text = _format_mode_name(session.get("mode", "unknown"))
	mode_label.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(mode_label)

	# Date
	var date_label = Label.new()
	date_label.text = _format_date(session.get("started_at", ""))
	date_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.71))
	date_label.add_theme_font_size_override("font_size", 12)
	info.add_child(date_label)

	row.add_child(info)

	# Shot count
	var shots = DatabaseManager.get_session_shots(session.id)
	var shots_label = Label.new()
	shots_label.text = "%d shots" % shots.size()
	shots_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(shots_label)

	# Score (for target practice)
	if session.get("mode") == "target_practice":
		var target_shots = DatabaseManager.get_session_target_shots(session.id)
		var total_score = 0
		for shot in target_shots:
			total_score += shot.get("score", 0)
		var score_label = Label.new()
		score_label.text = "%d pts" % total_score
		score_label.add_theme_color_override("font_color", Color(0.46, 0.8, 0.44))
		row.add_child(score_label)

	return row


func _format_mode_name(mode: String) -> String:
	match mode:
		"free_practice":
			return "Free Practice"
		"target_practice":
			return "Target Practice"
		"club_fitting":
			return "Club Fitting"
		_:
			return mode.capitalize()


func _format_date(date_str: String) -> String:
	if date_str.is_empty():
		return "Unknown"
	# Simple date formatting - just show first 10 chars (YYYY-MM-DD)
	if date_str.length() >= 10:
		return date_str.substr(0, 10)
	return date_str


func _format_number(num: int) -> String:
	if num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)


func _format_distance(distance: float) -> String:
	if distance >= 1000:
		return "%.0fK yd" % (distance / 1000.0)
	return "%.0f yd" % distance


func _show_empty_stats() -> void:
	_update_stat_card("Total Shots", "0")
	_update_stat_card("Sessions", "0")
	_update_stat_card("Avg Score", "---")
	_update_stat_card("Best Score", "---")
	_update_stat_card("Favorite Club", "---")
	_update_stat_card("Total Distance", "0 yd")


func _on_date_filter_changed(index: int) -> void:
	current_date_range = date_filter.get_item_id(index)
	_load_player_stats()
	_load_club_performance()
	_load_recent_sessions()


func _on_club_filter_changed(index: int) -> void:
	match index:
		0: current_club_filter = "all"
		1: current_club_filter = "driver"
		2: current_club_filter = "woods"
		3: current_club_filter = "irons"
		4: current_club_filter = "wedges"
	_load_club_performance()


func _on_back_btn_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/profile_screen.tscn")
