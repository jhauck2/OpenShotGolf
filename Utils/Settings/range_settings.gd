class_name RangeSettings
extends SettingCollector

var range_units := Setting.new(Enums.Units.IMPERIAL)
var camera_follow_mode := Setting.new(true)
var shot_injector_enabled := Setting.new(false)
var auto_ball_reset := Setting.new(false)
var ball_reset_timer := Setting.new(5.0, 1.0, 15.0)
var temperature := Setting.new(75, -40, 120)
var altitude := Setting.new(0.0, -1000.0, 10000.0)
var drag_scale := Setting.new(1.0, 0.5, 1.5)
var lift_scale := Setting.new(1.0, 0.8, 2.0)  # Reset to 1.0 - base Cl model now calibrated correctly
var surface_type := Setting.new(Enums.Surface.FAIRWAY)
var shot_tracer_count := Setting.new(1, 0, 4)

func _init():
	settings = {
		"range_units": range_units,
		"camera_follow_mode": camera_follow_mode,
		"shot_injector_enabled": shot_injector_enabled,
		"auto_ball_reset": auto_ball_reset,
		"ball_reset_timer": ball_reset_timer,
		"temperature": temperature,
		"altitude": altitude,
		"drag_scale": drag_scale,
		"lift_scale": lift_scale,
		"surface_type": surface_type,
		"shot_tracer_count": shot_tracer_count
	}
