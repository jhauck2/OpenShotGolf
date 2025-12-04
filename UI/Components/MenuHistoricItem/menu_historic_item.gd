extends Node

var _title := "TITLE"
var _value := "0"
var _date := ""

@onready var title_label = %Title
@onready var value_label = %Value
@onready var date_label = %Date


@export var title: String = "TITLE":
	set(value):
		_title = value
		if is_inside_tree():
			title_label.text = value.to_upper()
	get:
		return _title


@export var value: String = "0":
	set(new_value):
		_value = new_value
		if is_inside_tree():
			value_label.text = new_value
	get:
		return _value
		
@export var date: String = "":
	set(new_value):
		_date = new_value
		if is_inside_tree():
			date_label.text = new_value
	get:
		return _value


func _ready() -> void:
	_update_labels()


func _update_labels() -> void:
	title_label.text = _title.to_upper()
	date_label.text = _date
	value_label.text = _value
