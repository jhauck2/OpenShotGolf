extends Node

signal settings_changed

# Range Settings
var range_settings := RangeSettings.new()

# Player Settings
var player_name: String = "Player1"


func resett_defaults():
	range_settings.reset_defaults()
	emit_signal("settings_changed")
