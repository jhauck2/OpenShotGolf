class_name Setting
extends RefCounted

signal setting_changed

var value : Variant
var default : Variant
var _min : Variant = null
var _max : Variant = null

func _init(def: Variant, minimum: Variant = null, maximum: Variant = null):
	_min = minimum
	_max = maximum
	value = def
	default = def
	
func reset_default():
	value = default
	emit_signal("setting_changed")

func set_value(val: Variant):
	if _min and value < _min:
		value = _min
	elif _max and value > _max:
		value = _max
	else:
		value = val
		
	emit_signal("setting_changed")
	
func set_default(def: Variant):
	default = def
	emit_signal("setting_changed")
	
