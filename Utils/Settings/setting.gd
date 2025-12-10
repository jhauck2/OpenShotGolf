class_name Setting
extends RefCounted

signal setting_changed(val)

var value : Variant
var default : Variant
var min_value : Variant = null
var max_value : Variant = null

func _init(def: Variant, minimum: Variant = null, maximum: Variant = null):
	min_value = minimum
	max_value = maximum
	value = def
	default = def
	
func reset_default():
	value = default
	emit_signal("setting_changed", value)

func set_value(val: Variant):
	var new_value: Variant = val
	if min_value != null and new_value < min_value:
		new_value = min_value
	elif max_value != null and new_value > max_value:
		new_value = max_value
	value = new_value
		
	emit_signal("setting_changed", value)
	
func set_default(def: Variant):
	default = def
	emit_signal("setting_changed", value)
	
