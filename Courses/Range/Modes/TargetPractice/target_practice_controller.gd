extends BaseRangeController
class_name TargetPracticeController

## Target Practice Mode (Placeholder)
##
## Future implementation:
## - Target distance selection/randomization
## - Scoring system (points based on proximity to target)
## - Shot counter (hit X balls)
## - Mode-specific settings (TargetPracticeSettings)
## - Target panel UI showing: target distance, current score, shots remaining


# ============================================================================
# ABSTRACT METHOD IMPLEMENTATIONS
# ============================================================================

func on_shot_received(data: Dictionary) -> void:
	push_warning("TargetPracticeController not yet implemented")


func process_mode(delta: float) -> void:
	push_warning("TargetPracticeController not yet implemented")


func on_ball_rest(ball_data: Dictionary) -> void:
	push_warning("TargetPracticeController not yet implemented")


func on_manual_reset() -> void:
	push_warning("TargetPracticeController not yet implemented")
