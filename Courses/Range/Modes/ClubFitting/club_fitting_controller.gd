extends BaseRangeController
class_name ClubFittingController

## Club Fitting Mode - track shots per club with detailed statistics.
## Features shot history tracking, statistics (avg, min, max, std dev, dispersion),
## configurable shots per club target, and database persistence.

const DEFAULT_SHOTS_PER_CLUB := 10

var club_stats := {}
var current_club := "Dr"
var current_swing_type := "Full Swing"
var shots_per_club := DEFAULT_SHOTS_PER_CLUB
var raw_ball_data := {}
var current_session_id := -1
var last_shot_id := -1
var session_started := false

var mode_indicator: Control
var mode_settings_container: Control
var shot_result_popup: Control

var display_data := {
	"Distance": "---",
	"Carry": "---",
	"Offline": "---",
	"Apex": "---",
	"VLA": 0.0,
	"HLA": 0.0,
	"Speed": "---",
	"BackSpin": "---",
	"SideSpin": "---",
	"TotalSpin": "---",
	"SpinAxis": "---",
	"CurrentClub": "Dr",
	"ShotCount": 0,
	"ShotsRemaining": 10,
	"AvgDistance": "---",
	"AvgCarry": "---",
	"MinDistance": "---",
	"MaxDistance": "---",
	"StdDev": "---",
	"Dispersion": "---"
}


# --- Lifecycle ---

func _mode_ready() -> void:
	_ensure_club_stats(current_club)

	if EventBus:
		EventBus.club_selected.connect(_on_club_selected)

	_setup_ui_components()
	_create_shot_result_popup()
	_show_settings_panel()
	_update_stats_display()
	_update_mode_indicator()


# --- Mode Implementation ---

func on_shot_received(data: Dictionary) -> void:
	raw_ball_data = data.duplicate()
	_update_ball_display()


func process_mode(_delta: float) -> void:
	if get_ball_state() != Enums.BallState.REST:
		_update_ball_display()


func on_ball_rest(_ball_data: Dictionary) -> void:
	if not session_started:
		return

	var shot_data := _build_shot_data(raw_ball_data)
	_ensure_club_stats(current_club)
	club_stats[current_club].add_shot(shot_data)

	last_shot_id = _save_shot(shot_data)

	_update_ball_display()
	_update_stats_display()
	_update_mode_indicator()

	var stats := club_stats[current_club] as ClubFittingStats
	if stats.get_shot_count() >= shots_per_club:
		_on_club_complete()

	_show_shot_result(get_ball_distance(), get_ball_carry(), shot_data.get("OfflineDistance", 0.0))


func on_manual_reset() -> void:
	_reset_display_data()
	update_ui(display_data)
	reset_ball()


# --- Signal Handlers ---

func _on_club_selected(club: String) -> void:
	current_club = club
	_ensure_club_stats(club)
	_update_stats_display()
	print("Club Fitting: Switched to %s" % club)


# --- Club Stats Management ---

func _ensure_club_stats(club: String) -> void:
	if not club_stats.has(club):
		var stats := ClubFittingStats.new()
		stats.club_code = club
		club_stats[club] = stats


func _build_shot_data(raw: Dictionary) -> Dictionary:
	return {
		"Speed": raw.get("Speed", 0.0),
		"SpinAxis": raw.get("SpinAxis", 0.0),
		"TotalSpin": raw.get("TotalSpin", 0.0),
		"BackSpin": raw.get("BackSpin", 0.0),
		"SideSpin": raw.get("SideSpin", 0.0),
		"HLA": raw.get("HLA", 0.0),
		"VLA": raw.get("VLA", 0.0),
		"CarryDistance": get_ball_carry(),
		"TotalDistance": get_ball_distance(),
		"Apex": get_ball_apex(),
		"OfflineDistance": get_ball_side_distance()
	}


func _on_club_complete() -> void:
	var stats := club_stats[current_club] as ClubFittingStats
	print("Club Fitting: %s complete! %d shots recorded." % [current_club, stats.get_shot_count()])
	print("  Avg Distance: %.1f | Std Dev: %.1f | Dispersion: %.1f" % [
		stats.get_average_distance(),
		stats.get_distance_std_dev(),
		stats.get_dispersion()
	])


# --- Database ---

func _start_session() -> void:
	var player_id := GlobalSettings.get_current_player_id()

	current_session_id = DatabaseManager.create_session(
		player_id,
		"club_fitting",
		GlobalSettings.range_settings.temperature.value,
		GlobalSettings.range_settings.altitude.value,
		GlobalSettings.range_settings.surface_type.value,
		GlobalSettings.range_settings.range_units.value
	)


func _save_shot(shot_data: Dictionary) -> int:
	if current_session_id <= 0:
		return -1

	var db_shot_data := shot_data.duplicate()
	db_shot_data["club_code"] = current_club
	return DatabaseManager.create_shot(current_session_id, db_shot_data)


# --- Display Updates ---

func _update_ball_display() -> void:
	display_data = format_shot_display(raw_ball_data, true, display_data)
	update_ui(display_data)


func _update_stats_display() -> void:
	display_data["CurrentClub"] = current_club

	if club_stats.has(current_club):
		var stats := club_stats[current_club] as ClubFittingStats
		display_data["ShotCount"] = stats.get_shot_count()
		display_data["ShotsRemaining"] = max(0, shots_per_club - stats.get_shot_count())

		if stats.get_shot_count() > 0:
			display_data["AvgDistance"] = "%.1f" % stats.get_average_distance()
			display_data["AvgCarry"] = "%.1f" % stats.get_average_carry()
			display_data["MinDistance"] = "%.1f" % stats.get_min_distance()
			display_data["MaxDistance"] = "%.1f" % stats.get_max_distance()
			display_data["StdDev"] = "%.1f" % stats.get_distance_std_dev()
			display_data["Dispersion"] = "%.1f" % stats.get_dispersion()
		else:
			_clear_stats_display()
	else:
		display_data["ShotCount"] = 0
		display_data["ShotsRemaining"] = shots_per_club
		_clear_stats_display()

	update_ui(display_data)


func _clear_stats_display() -> void:
	display_data["AvgDistance"] = "---"
	display_data["AvgCarry"] = "---"
	display_data["MinDistance"] = "---"
	display_data["MaxDistance"] = "---"
	display_data["StdDev"] = "---"
	display_data["Dispersion"] = "---"


func _reset_display_data() -> void:
	raw_ball_data.clear()
	display_data["Distance"] = "---"
	display_data["Carry"] = "---"
	display_data["Offline"] = "---"
	display_data["Apex"] = "---"
	display_data["VLA"] = 0.0
	display_data["HLA"] = 0.0
	display_data["Speed"] = "---"
	display_data["BackSpin"] = "---"
	display_data["SideSpin"] = "---"
	display_data["TotalSpin"] = "---"
	display_data["SpinAxis"] = "---"
	_update_stats_display()


# --- Public API ---

func get_club_stats(club: String) -> Dictionary:
	if club_stats.has(club):
		return (club_stats[club] as ClubFittingStats).get_all_stats()
	return {}


func get_all_club_stats() -> Dictionary:
	var all_stats := {}
	for club in club_stats.keys():
		all_stats[club] = (club_stats[club] as ClubFittingStats).get_all_stats()
	return all_stats


func get_fitting_summary() -> Dictionary:
	var summary := {}
	for club in club_stats.keys():
		var stats := club_stats[club] as ClubFittingStats
		summary[club] = {
			"shots": stats.get_shot_count(),
			"avg_distance": stats.get_average_distance(),
			"avg_carry": stats.get_average_carry(),
			"std_dev": stats.get_distance_std_dev(),
			"dispersion": stats.get_dispersion()
		}
	return summary


func clear_club_stats(club: String) -> void:
	if club_stats.has(club):
		(club_stats[club] as ClubFittingStats).clear()
		_update_stats_display()


func clear_all_stats() -> void:
	for club in club_stats.keys():
		(club_stats[club] as ClubFittingStats).clear()
	_update_stats_display()


func set_shots_per_club(count: int) -> void:
	shots_per_club = max(1, count)
	_update_stats_display()


# --- UI Setup ---

func _create_shot_result_popup() -> void:
	var shot_modal_scene := preload("res://Courses/Range/Modes/ClubFitting/shot_modal.tscn")
	shot_result_popup = shot_modal_scene.instantiate()
	shot_result_popup.visible = false

	var discard_btn := shot_result_popup.find_child("DiscardBtn", true, false)
	if discard_btn:
		discard_btn.pressed.connect(_on_undo_shot)

	var accept_btn := shot_result_popup.find_child("AcceptBtn", true, false)
	if accept_btn:
		accept_btn.pressed.connect(_on_continue_shot)

	range_ui.add_child(shot_result_popup)


func _setup_ui_components() -> void:
	mode_indicator = %ModeIndicator
	mode_settings_container = %ModeSettingsContainer

	if mode_indicator:
		mode_indicator.pressed.connect(_on_mode_indicator_pressed)

	if mode_settings_container:
		_connect_settings_controls()


func _connect_settings_controls() -> void:
	if not mode_settings_container:
		return

	var close_btn := mode_settings_container.find_child("CloseBtn", true, false)
	if close_btn:
		close_btn.pressed.connect(_hide_settings_panel)

	var submit_btn := mode_settings_container.find_child("SubmitBtn", true, false)
	if submit_btn:
		submit_btn.pressed.connect(_on_settings_apply)

	_populate_club_selector()
	_populate_swing_type_selector()


func _populate_club_selector() -> void:
	var club_select := mode_settings_container.find_child("ClubSelect", true, false) as OptionButton
	if not club_select:
		return

	club_select.clear()
	for club in DatabaseManager.ALL_CLUBS:
		club_select.add_item(club)

	var default_index := DatabaseManager.ALL_CLUBS.find(current_club)
	if default_index >= 0:
		club_select.select(default_index)


func _populate_swing_type_selector() -> void:
	var swing_select := mode_settings_container.find_child("SwingSelect", true, false) as OptionButton
	if not swing_select:
		return

	swing_select.clear()
	var swing_types := DatabaseManager.get_swing_types()
	for swing_type in swing_types:
		swing_select.add_item(swing_type.get("name", "Unknown"))


func _show_settings_panel() -> void:
	if mode_settings_container:
		mode_settings_container.visible = true


func _hide_settings_panel() -> void:
	if mode_settings_container:
		mode_settings_container.visible = false


func _on_mode_indicator_pressed() -> void:
	if mode_settings_container:
		mode_settings_container.visible = not mode_settings_container.visible


func _on_settings_apply() -> void:
	if not mode_settings_container:
		return

	var club_select := mode_settings_container.find_child("ClubSelect", true, false) as OptionButton
	if club_select and club_select.selected >= 0:
		current_club = DatabaseManager.ALL_CLUBS[club_select.selected]
		_ensure_club_stats(current_club)

	var swing_select := mode_settings_container.find_child("SwingSelect", true, false) as OptionButton
	if swing_select and swing_select.selected >= 0:
		current_swing_type = swing_select.get_item_text(swing_select.selected)

	var size_select := mode_settings_container.find_child("SizeSelect", true, false) as OptionButton
	if size_select:
		var size_options := [3, 5, 10]
		if size_select.selected >= 0 and size_select.selected < size_options.size():
			shots_per_club = size_options[size_select.selected]

	_start_session()
	session_started = true
	_hide_settings_panel()
	_update_mode_indicator()


func _update_mode_indicator() -> void:
	if not mode_indicator:
		return

	var stats := club_stats.get(current_club) as ClubFittingStats
	var shot_count := stats.get_shot_count() if stats else 0

	var avg_str := "---"
	if stats and shot_count > 0:
		avg_str = "%.0fy" % stats.get_average_distance()

	var items: Array[InfoItem] = [
		InfoItem.new().set_data("CLUB", current_club),
		InfoItem.new().set_data("SHOTS", "%d/%d" % [shot_count, shots_per_club]),
		InfoItem.new().set_data("AVG", avg_str)
	]

	mode_indicator.set_info_items(items)
	mode_indicator.subtitle = "%s | %s" % [current_club, current_swing_type]


# --- Popup Handlers ---

func _show_shot_result(distance: float, carry: float, offline_distance: float) -> void:
	if not shot_result_popup:
		return

	var stats := club_stats.get(current_club) as ClubFittingStats
	var shot_count := stats.get_shot_count() if stats else 0

	var popup_title := shot_result_popup.find_child("PopupTitle", true, false)
	if popup_title:
		popup_title.text = "Shot #%d captured" % shot_count

	var club_name := shot_result_popup.find_child("ClubName", true, false)
	if club_name:
		club_name.text = current_club

	var value1 := shot_result_popup.find_child("Value1", true, false)
	if value1:
		value1.text = "%.0f" % carry

	var value2 := shot_result_popup.find_child("Value2", true, false)
	if value2:
		value2.text = "%.0f" % distance

	var value3 := shot_result_popup.find_child("Value3", true, false)
	if value3:
		value3.text = "%.0f" % abs(offline_distance)

	var value3_footer := shot_result_popup.find_child("VBoxContainer3", true, false).find_child("Footer", true, false)
	if value3_footer:
		if offline_distance > 0:
			value3_footer.text = "Slice"
		elif offline_distance < 0:
			value3_footer.text = "Hook"
		else:
			value3_footer.text = ""

	shot_result_popup.visible = true


func _on_undo_shot() -> void:
	if last_shot_id > 0:
		DatabaseManager.delete_shot(last_shot_id)

		if club_stats.has(current_club):
			var stats := club_stats[current_club] as ClubFittingStats
			stats.remove_last_shot()

		last_shot_id = -1

	shot_result_popup.visible = false
	_update_stats_display()
	_update_mode_indicator()
	reset_ball()


func _on_continue_shot() -> void:
	shot_result_popup.visible = false
	_update_mode_indicator()

	if GlobalSettings.range_settings.auto_ball_reset.value:
		reset_ball()
