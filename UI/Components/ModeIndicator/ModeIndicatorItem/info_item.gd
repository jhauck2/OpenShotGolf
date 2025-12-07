extends Resource
class_name InfoItem

@export var title: String = ""
@export var value: String = ""

func set_data(t: String, v: String) -> InfoItem:
	title = t
	value = v
	return self
