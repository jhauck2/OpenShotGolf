extends BaseRangeController
class_name ClubFittingController

## Club Fitting Mode (Placeholder)
##
## Future implementation:
## - Shot history tracking (store all shots)
## - Club selection/display
## - Configurable shots per club (e.g., 10 balls)
## - Analysis display: basic statistics (avg, min, max, std dev)
## - Mode-specific settings (ClubFittingSettings)
## - Analysis panel UI showing: club, shot count, distance statistics


# ============================================================================
# ABSTRACT METHOD IMPLEMENTATIONS
# ============================================================================

func on_shot_received(data: Dictionary) -> void:
	push_warning("ClubFittingController not yet implemented")


func process_mode(delta: float) -> void:
	push_warning("ClubFittingController not yet implemented")


func on_ball_rest(ball_data: Dictionary) -> void:
	push_warning("ClubFittingController not yet implemented")


func on_manual_reset() -> void:
	push_warning("ClubFittingController not yet implemented")
