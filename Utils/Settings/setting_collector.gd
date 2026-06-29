class_name SettingCollector
extends RefCounted

signal settings_changed

var settings : Dictionary[String,Setting] = {}

func _init(sets : Dictionary[String, Setting] = {}) -> void:
	settings = sets
	
func init(sets : Dictionary[String, Setting] = {}) -> void:
	settings = sets

func reset_defaults() -> void:
	for name: String in settings.keys():
		settings[name].reset_default()
		
	emit_signal("settings_changed")
		
func set_value(setting_name : String, setting_value : Variant) -> void:
	settings[setting_name].set_value(setting_value)
	emit_signal("settings_changed")
	
func set_default(setting_name : String, setting_default : Variant) -> void:
	settings[setting_name].set_default(setting_default)
	emit_signal("settings_changed")
