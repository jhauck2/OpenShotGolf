extends Control

## List of button node paths that should close the modal
@export var close_button_paths: Array[NodePath] = []

func _ready() -> void:
	for button_path in close_button_paths:
		var button = get_node(button_path)
		if button and button is Button:
			button.pressed.connect(_on_close_button_pressed)

func _on_close_button_pressed() -> void:
	visible = false

func show_modal() -> void:
	visible = true

func hide_modal() -> void:
	visible = false
