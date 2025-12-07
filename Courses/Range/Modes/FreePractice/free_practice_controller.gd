extends BaseRangeController
class_name FreePracticeController

## Free Practice Mode - unlimited shots with full metrics display.
## Players can hit as many shots as they want and view all ball flight metrics.
## Supports auto-reset functionality and live metric updates during flight.

var raw_ball_data := {}
var shot_count := 0
var current_club := "Dr"
var current_swing_type := "Full Swing"

var mode_indicator: Control

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
	"SpinAxis": "---"
}


# --- Lifecycle ---

func _mode_ready() -> void:
	_setup_ui_components()
	_update_mode_indicator()


# --- Mode Implementation ---

func on_shot_received(data: Dictionary) -> void:
	raw_ball_data = data.duplicate()
	_update_ball_display()


func process_mode(_delta: float) -> void:
	if get_ball_state() != Enums.BallState.REST:
		_update_ball_display()


func on_ball_rest(_ball_data: Dictionary) -> void:
	shot_count += 1
	_update_ball_display()
	_update_mode_indicator()

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


# --- Display Updates ---

func _update_ball_display() -> void:
	display_data = format_shot_display(raw_ball_data, true, display_data)
	update_ui(display_data)


func _reset_display_data() -> void:
	raw_ball_data.clear()
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
		"SpinAxis": "---"
	}


# --- UI Setup ---

func _setup_ui_components() -> void:
	mode_indicator = %ModeIndicator


func _update_mode_indicator() -> void:
	if not mode_indicator:
		return

	var dist_str: String = str(display_data.get("Distance", "---"))
	if dist_str != "---":
		dist_str = dist_str + "y"

	var carry_str: String = str(display_data.get("Carry", "---"))
	if carry_str != "---":
		carry_str = carry_str + "y"

	var items: Array[InfoItem] = [
		InfoItem.new().set_data("SHOTS", str(shot_count)),
		InfoItem.new().set_data("LAST", dist_str),
		InfoItem.new().set_data("CARRY", carry_str)
	]

	mode_indicator.set_info_items(items)
	mode_indicator.subtitle = "%s | %s" % [current_club, current_swing_type]
