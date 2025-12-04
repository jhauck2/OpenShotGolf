class_name RangeSettings
extends SettingCollector

var range_units := Setting.new(Enums.Units.IMPERIAL)
var camera_follow_mode := Setting.new(false)
var shot_injector_enabled := Setting.new(false)
var auto_ball_reset := Setting.new(false)
var ball_reset_timer := Setting.new(7.0, 1.0, 15.0)
var temperature := Setting.new(77, -40, 120)
var altitude := Setting.new(0.0, -1000.0, 10000.0)
var drag_scale := Setting.new(1.0, 0.5, 1.5)
var surface_type := Setting.new(Enums.Surface.FIRM)

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
		"surface_type": surface_type
	}

func reset_defaults():
	range_units.value = Enums.Units.IMPERIAL
	camera_follow_mode.value = false
	shot_injector_enabled.value = false
	auto_ball_reset.value = false
	ball_reset_timer.value = 7.0
	temperature.value = 77
	altitude.value = 0.0
	drag_scale.value = 1.0
	surface_type.value = Enums.Surface.FIRM
