extends BaseRangeController
class_name FreePracticeController

## Free Practice Mode
## Unlimited shots with full metrics display. Users can hit as many shots
## as they want and view all ball flight metrics.

var raw_ball_data: Dictionary = {}
var display_data: Dictionary = {
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


# ============================================================================
# ABSTRACT METHOD IMPLEMENTATIONS
# ============================================================================

func on_shot_received(data: Dictionary) -> void:
	raw_ball_data = data.duplicate()
	_update_ball_display()


func process_mode(_delta: float) -> void:
	# Refresh UI during flight/rollout so carry/apex update live
	if get_ball_state() != Enums.BallState.REST:
		_update_ball_display()


func on_ball_rest(_ball_data: Dictionary) -> void:
	# Show final shot numbers immediately on rest
	_update_ball_display()

	# Auto-reset if enabled
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


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_ball_display() -> void:
	# Show distance continuously (updates during flight/rollout, final at rest)
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
