extends Node

signal settings_changed

# Range Settings
var range_settings := RangeSettings.new()
const OPENFAIRWAY_LOG_LEVEL_INFO := 2

class Version:
	const major: int = 0
	const minor: int = 1
	const patch: int = 3
	
var version : Version

func _ready() -> void:
	pass


func resett_defaults() -> void:
	range_settings.reset_defaults()
	emit_signal("settings_changed")

func get_version_string() -> String:
	return str(version.major)+"."+str(version.minor)+"."+str(version.patch)
