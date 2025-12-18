class_name RangeSettings
extends SettingCollector

var range_units := Setting.new(Enums.Units.IMPERIAL)
var camera_follow_mode := Setting.new(true)
var shot_injector_enabled := Setting.new(false)
var auto_ball_reset := Setting.new(false)
var ball_reset_timer := Setting.new(3.0, 1.0, 15.0)
var temperature := Setting.new(75, -40, 120)
var altitude := Setting.new(0.0, -1000.0, 10000.0)
var surface_type := Setting.new(Surface.SurfaceType.FAIRWAY)
var shot_tracer_count := Setting.new(1, 0, 4)
var ball_type := Setting.new(GolfBall.BallType.STANDARD)

func _init():
	settings = {
		"range_units": range_units,
		"camera_follow_mode": camera_follow_mode,
		"shot_injector_enabled": shot_injector_enabled,
		"auto_ball_reset": auto_ball_reset,
		"ball_reset_timer": ball_reset_timer,
		"temperature": temperature,
		"altitude": altitude,
		"surface_type": surface_type,
		"shot_tracer_count": shot_tracer_count,
		"ball_type": ball_type
	}
