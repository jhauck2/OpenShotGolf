extends Control

signal club_selected(club: String)
signal rec_button_pressed
signal exit_pressed

var range_ref: Node3D

func _ready() -> void:
	pass

func activate() -> void:
	visible = true

func deactivate() -> void:
	visible = false

func _connect_to_range_systems() -> void:
	pass

func update_data(_data: Dictionary) -> void:
	pass

func update_mode_display(_mode: String) -> void:
	pass

func set_recording_state(_is_recording: bool) -> void:
	pass

func set_range(range_node: Node3D) -> void:
	range_ref = range_node

