extends Node

signal settings_changed

# Range Settings
var range_settings := RangeSettings.new()
const OPENFAIRWAY_LOG_LEVEL_INFO := 1


func _ready() -> void:
	PhysicsLogger.SetLevel(OPENFAIRWAY_LOG_LEVEL_INFO)


func resett_defaults():
	range_settings.reset_defaults()
	emit_signal("settings_changed")
