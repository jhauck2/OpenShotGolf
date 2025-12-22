extends Control

@onready var title_label: Label = %Title
@onready var value_label: Label = %Value

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_info(title: String, value: String) -> void:
	title_label.text = title
	value_label.text = value
