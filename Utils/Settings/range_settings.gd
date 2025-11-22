class_name RangeSettings
extends SettingCollector

var range_units := Setting.new(Enums.Units.IMPERIAL)
var auto_ball_reset := Setting.new(true)
var ball_reset_timer := Setting.new(7.0, 1.0, 15.0)
var temperature := Setting.new(77, -40, 120)
var altitude := Setting.new(0.0, -1000.0, 10000.0)

func _init():
	settings = {
		"range_units": range_units,
		"auto_ball_reset": auto_ball_reset,
		"ball_reset_timer": ball_reset_timer,
		"temperature": temperature,
		"altitude": altitude
	}
