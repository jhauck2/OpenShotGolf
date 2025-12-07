extends BaseRangeController
class_name TargetPracticeController

## Target Practice Mode - aim at targets with proximity-based scoring.
## Features multiple target distances, scoring zones (Bullseye, Yellow, Red, White),
## session statistics tracking, and database persistence.

const TARGET_SIZE_MULTIPLIERS := {
	0: 1.0,
	1: 0.7,
	2: 0.5
}

var target_manager: TargetManager
var raw_ball_data := {}
var current_session_id := -1
var current_club := "Dr"
var session_started := false

var target_distance_yards := 150
var target_size := 0
var required_shots := -1
var max_attempts := -1
var auto_continue := true
var randomize_distance := false

var mode_indicator: Control
var mode_settings_container: Control

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
	"Points": "---",
	"Zone": "---",
	"TotalScore": 0,
	"ShotCount": 0
}


# --- Lifecycle ---

func _mode_ready() -> void:
	_setup_target_manager()

	if EventBus:
		EventBus.club_selected.connect(_on_club_selected)

	_setup_ui_components()
	_show_settings_panel()
	_update_target_info_display()
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

	var ball_pos: Vector3 = player.get_node("Ball").global_position
	var result := target_manager.process_shot(ball_pos)

	_save_shot(raw_ball_data, result)
	_update_ball_display()

	if not result.is_empty():
		display_data["Points"] = str(result.get("score", 0))
		display_data["Zone"] = result.get("zone", "---")
		var stats := target_manager.get_session_stats()
		display_data["TotalScore"] = stats.get("total_score", 0)
		display_data["ShotCount"] = stats.get("total_shots", 0)
	else:
		display_data["Points"] = "0"
		display_data["Zone"] = "Miss"

	update_ui(display_data)
	_update_mode_indicator()

	if required_shots > 0:
		var stats := target_manager.get_session_stats()
		if stats.get("total_shots", 0) >= required_shots:
			_on_session_complete()
			return

	if auto_continue and randomize_distance:
		_select_random_target()

	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(
			GlobalSettings.range_settings.ball_reset_timer.value
		).timeout
		_reset_display_data()
		update_ui(display_data)
		reset_ball()


func on_manual_reset() -> void:
	_reset_display_data()
	update_ui(display_data)
	reset_ball()


# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)

	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_BRACKETLEFT:
			target_manager.previous_target()
		KEY_BRACKETRIGHT:
			target_manager.next_target()
		KEY_LEFT:
			target_manager.adjust_aim(-5.0)
			_update_target_info_display()
		KEY_RIGHT:
			target_manager.adjust_aim(5.0)
			_update_target_info_display()
		KEY_DOWN:
			target_manager.reset_aim()
			_update_target_info_display()
		KEY_R:
			if event.ctrl_pressed:
				_reset_session_stats()


# --- Signal Handlers ---

func _on_shot_scored(target_name: String, distance: float, score: int, zone: String) -> void:
	print("Target Practice: %s - %s zone, %.1f yards, +%d pts" % [target_name, zone, distance, score])


func _on_target_selected(target: TargetGreen) -> void:
	_update_target_info_display()
	_update_mode_indicator()
	print("Target selected: %s at %.0f yards" % [target.target_name, target.target_distance])


func _on_club_selected(club: String) -> void:
	current_club = club


# --- Target Manager Setup ---

func _setup_target_manager() -> void:
	target_manager = TargetManager.new()
	target_manager.name = "TargetManager"
	add_child(target_manager)
	target_manager.create_targets()

	target_manager.shot_scored.connect(_on_shot_scored)
	target_manager.target_selected.connect(_on_target_selected)


# --- Database ---

func _start_session() -> void:
	var player_id := GlobalSettings.get_current_player_id()

	current_session_id = DatabaseManager.create_session(
		player_id,
		"target_practice",
		GlobalSettings.range_settings.temperature.value,
		GlobalSettings.range_settings.altitude.value,
		GlobalSettings.range_settings.surface_type.value,
		GlobalSettings.range_settings.range_units.value
	)


func _save_shot(shot_data: Dictionary, target_result: Dictionary) -> void:
	if current_session_id <= 0:
		return

	var db_shot_data := {
		"club_code": current_club,
		"Speed": shot_data.get("Speed", 0.0),
		"SpinAxis": shot_data.get("SpinAxis", 0.0),
		"TotalSpin": shot_data.get("TotalSpin", 0.0),
		"BackSpin": shot_data.get("BackSpin", 0.0),
		"SideSpin": shot_data.get("SideSpin", 0.0),
		"HLA": shot_data.get("HLA", 0.0),
		"VLA": shot_data.get("VLA", 0.0),
		"CarryDistance": get_ball_carry(),
		"TotalDistance": get_ball_distance(),
		"Apex": get_ball_apex(),
		"OfflineDistance": get_ball_side_distance()
	}

	var shot_id := DatabaseManager.create_shot(current_session_id, db_shot_data)

	if not target_result.is_empty() and target_manager.get_active_target():
		DatabaseManager.create_target_shot(
			shot_id,
			target_manager.get_active_target().target_distance,
			target_result.get("distance", 0.0),
			target_result.get("score", 0),
			target_result.get("zone", "Outside")
		)


# --- Display Updates ---

func _update_ball_display() -> void:
	display_data = format_shot_display(raw_ball_data, true, display_data)
	_update_target_info_display()
	update_ui(display_data)


func _update_target_info_display() -> void:
	var target := target_manager.get_active_target()
	if not target:
		return

	display_data["TargetName"] = target.target_name
	display_data["TargetDistance"] = target.target_distance

	if abs(target.lateral_offset) > 0.1:
		var direction := "R" if target.lateral_offset > 0 else "L"
		display_data["TargetOffset"] = "%.0f %s" % [abs(target.lateral_offset), direction]
	else:
		display_data["TargetOffset"] = "Center"


func _reset_display_data() -> void:
	raw_ball_data.clear()
	var stats := target_manager.get_session_stats()
	display_data = {
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
		"Points": "---",
		"Zone": "---",
		"TotalScore": stats.get("total_score", 0),
		"ShotCount": stats.get("total_shots", 0)
	}
	_update_target_info_display()


func _reset_session_stats() -> void:
	target_manager.reset_session_stats()
	display_data["TotalScore"] = 0
	display_data["ShotCount"] = 0
	display_data["Points"] = "---"
	display_data["Zone"] = "---"
	update_ui(display_data)
	print("Session stats reset")


# --- Public API ---

func get_session_stats() -> Dictionary:
	return target_manager.get_session_stats()


func get_active_target_info() -> Dictionary:
	return target_manager.get_active_target_info()


func select_next_target() -> void:
	target_manager.next_target()


func select_previous_target() -> void:
	target_manager.previous_target()


# --- UI Setup ---

func _setup_ui_components() -> void:
	var margin_container := get_node_or_null("MarginContainer")
	if margin_container:
		var vbox := margin_container.get_node_or_null("VBoxContainer")
		if vbox:
			mode_indicator = vbox.get_node_or_null("ModeIndicator")
			mode_settings_container = vbox.get_node_or_null("ModeSettingsContainer")

	if mode_indicator:
		mode_indicator.pressed.connect(_on_mode_indicator_pressed)

	if mode_settings_container:
		_connect_settings_controls()


func _connect_settings_controls() -> void:
	if not mode_settings_container:
		return

	var minus_btn := mode_settings_container.find_child("MinusBtn", true, false)
	var plus_btn := mode_settings_container.find_child("PlusBtn", true, false)
	if minus_btn:
		minus_btn.pressed.connect(_on_distance_minus)
	if plus_btn:
		plus_btn.pressed.connect(_on_distance_plus)

	var close_btn := mode_settings_container.find_child("CloseBtn", true, false)
	if close_btn:
		close_btn.pressed.connect(_hide_settings_panel)

	var submit_btn := mode_settings_container.find_child("SubmitBtn", true, false)
	if submit_btn:
		submit_btn.pressed.connect(_on_settings_apply)

	_update_distance_label()


func _show_settings_panel() -> void:
	if mode_settings_container:
		mode_settings_container.visible = true


func _hide_settings_panel() -> void:
	if mode_settings_container:
		mode_settings_container.visible = false


func _on_mode_indicator_pressed() -> void:
	if mode_settings_container:
		mode_settings_container.visible = not mode_settings_container.visible


func _on_distance_minus() -> void:
	target_distance_yards = max(50, target_distance_yards - 25)
	_update_distance_label()


func _on_distance_plus() -> void:
	target_distance_yards = min(300, target_distance_yards + 25)
	_update_distance_label()


func _update_distance_label() -> void:
	if not mode_settings_container:
		return
	var yard_label := mode_settings_container.find_child("YardLabel", true, false)
	if yard_label:
		yard_label.text = "%dy" % target_distance_yards


func _on_settings_apply() -> void:
	if not mode_settings_container:
		return

	var size_select := mode_settings_container.find_child("SizeSelect", true, false) as OptionButton
	if size_select:
		target_size = size_select.selected

	var shots_select := mode_settings_container.find_child("ShotsSelect", true, false) as OptionButton
	if shots_select:
		var shots_options := [3, 5, 10, -1]
		required_shots = shots_options[shots_select.selected]

	var attempts_select := mode_settings_container.find_child("AttemptsSelect", true, false) as OptionButton
	if attempts_select:
		var attempts_options := [3, 5, 10, -1]
		max_attempts = attempts_options[attempts_select.selected]

	var continue_toggle := mode_settings_container.find_child("ContinueToggle2", true, false) as CheckButton
	if continue_toggle:
		auto_continue = continue_toggle.button_pressed

	var random_toggle := mode_settings_container.find_child("RandomToggle", true, false) as CheckButton
	if random_toggle:
		randomize_distance = random_toggle.button_pressed

	if target_manager:
		var multiplier: float = TARGET_SIZE_MULTIPLIERS.get(target_size, 1.0)
		target_manager.set_scoring_multiplier(multiplier)

	_select_target_at_distance(target_distance_yards)
	_start_session()
	session_started = true
	_hide_settings_panel()
	_update_mode_indicator()


func _update_mode_indicator() -> void:
	if not mode_indicator:
		return

	var target := target_manager.get_active_target()
	var stats := target_manager.get_session_stats()

	var target_str := "---"
	if target:
		target_str = "%.0fy" % target.target_distance

	var shot_count: int = stats.get("total_shots", 0)
	var shots_str := str(shot_count)
	if required_shots > 0:
		shots_str = "%d/%d" % [shot_count, required_shots]

	var items: Array[InfoItem] = [
		InfoItem.new().set_data("TARGET", target_str),
		InfoItem.new().set_data("SHOTS", shots_str),
		InfoItem.new().set_data("SCORE", str(stats.get("total_score", 0)))
	]

	mode_indicator.set_info_items(items)

	var size_names := ["Large", "Medium", "Pro"]
	var size_str: String = size_names[target_size] if target_size < size_names.size() else "Large"
	var shots_str_subtitle := "Unlimited" if required_shots < 0 else str(required_shots)
	mode_indicator.subtitle = "Pin: %dy | %s | %s shots" % [target_distance_yards, size_str, shots_str_subtitle]


func _select_target_at_distance(distance_yards: int) -> void:
	if not target_manager:
		return

	var targets := target_manager.get_all_targets()
	var best_index := 0
	var best_diff: float = 9999

	for i in range(targets.size()):
		var diff: float = abs(targets[i].target_distance - distance_yards)
		if diff < best_diff:
			best_diff = diff
			best_index = i

	target_manager.set_active_target(best_index)


func _select_random_target() -> void:
	if not target_manager:
		return

	var targets := target_manager.get_all_targets()
	if targets.size() > 0:
		var random_index := randi() % targets.size()
		target_manager.set_active_target(random_index)


func _on_session_complete() -> void:
	var stats := target_manager.get_session_stats()
	print("Session Complete! Total Score: %d from %d shots" % [
		stats.get("total_score", 0),
		stats.get("total_shots", 0)
	])
