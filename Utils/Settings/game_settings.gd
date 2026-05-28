class_name GameSettings
extends SettingCollector

var game_units: Setting = Setting.new(PhysicsEnums.Units.IMPERIAL)
var camera_follow_mode: Setting = Setting.new(false)
var auto_ball_reset: Setting = Setting.new(false)
var ball_reset_timer: Setting = Setting.new(3.0, 1.0, 15.0)
var temperature: Setting = Setting.new(75, -40, 120)
var altitude: Setting = Setting.new(0.0, -1000.0, 10000.0)
var drag_scale: Setting = Setting.new(1.0, 0.5, 1.5)
var lift_scale: Setting = Setting.new(1.0, 0.8, 2.0)
var surface_type: Setting = Setting.new(PhysicsEnums.SurfaceType.FAIRWAY)
var shot_tracer_count: Setting = Setting.new(2, 0, 5)


func _init() -> void:
	settings = {
		"game_units": game_units,
		"camera_follow_mode": camera_follow_mode,
		"auto_ball_reset": auto_ball_reset,
		"ball_reset_timer": ball_reset_timer,
		"temperature": temperature,
		"altitude": altitude,
		"drag_scale": drag_scale,
		"lift_scale": lift_scale,
		"surface_type": surface_type,
		"shot_tracer_count": shot_tracer_count
	}
