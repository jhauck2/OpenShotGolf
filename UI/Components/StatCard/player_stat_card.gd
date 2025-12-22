@tool
extends Button

@onready var title_label: Label = %Title
@onready var value_label: Label = %Value

func _ready() -> void:
	title_label.text = title
	value_label.text = value

# ---------------------------
# PUBLIC API (Inspector-safe)
# ---------------------------

@export var title: String:
	set(value):
		title = value
		if title_label:
			title_label.text = value
	get:
		return title

@export var value: String:
	set(incoming_value):
		value = incoming_value
		if value_label:
			value_label.text = incoming_value
	get:
		return value
