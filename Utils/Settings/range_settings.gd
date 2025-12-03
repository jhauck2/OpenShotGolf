class_name RangeSettings
extends SettingCollector

var range_units := Setting.new(Enums.Units.IMPERIAL)
var camera_follow_mode := Setting.new(false)
var shot_injector_enabled := Setting.new(false)
var auto_ball_reset := Setting.new(false)
var ball_reset_timer := Setting.new(7.0, 1.0, 15.0)
var temperature := Setting.new(77, -40, 120)
var altitude := Setting.new(0.0, -1000.0, 10000.0)

func _init():
	settings = {
		"range_units": range_units,
		"camer_follow_mode": camera_follow_mode,
		"shot_injector_enabled": shot_injector_enabled,
		"auto_ball_reset": auto_ball_reset,
		"ball_reset_timer": ball_reset_timer,
		"temperature": temperature,
		"altitude": altitude
	}
