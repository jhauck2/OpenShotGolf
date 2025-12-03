extends PanelContainer

var main_value: String = "0" :
	set(value):
		main_value = value
		_update_display()

var secondary_value: String = "" :
	set(value):
		secondary_value = value
		_update_display()

@export var indicator_rotation: float = 0.0

var main_label: Label
var secondary_label: Label

func _ready() -> void:
	main_label = get_node_or_null("VBoxContainer/MainValue")
	secondary_label = get_node_or_null("VBoxContainer/SecondaryValue")
	_update_display()

func _update_display() -> void:
	if main_label:
		main_label.text = main_value
	if secondary_label:
		secondary_label.text = secondary_value
		secondary_label.visible = secondary_value != ""

func set_main_value(value: String) -> void:
	self.main_value = value

func set_secondary_value(value: String) -> void:
	self.secondary_value = value
