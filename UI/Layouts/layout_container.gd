extends Control

var layouts: Dictionary = {}  # name -> node reference
var current_layout: Control = null
var current_layout_name: String = ""

signal layout_changed(from: String, to: String)

func _ready() -> void:
	pass

func add_layout(layout_name: String, layout_node: Control) -> void:
	layouts[layout_name] = layout_node
	add_child(layout_node)
	layout_node.owner = self
	layout_node.visible = false

func switch_layout(layout_name: String) -> void:
	if not layout_name in layouts:
		push_error("Layout '%s' not found" % layout_name)
		return

	if current_layout:
		if current_layout.has_method("deactivate"):
			current_layout.deactivate()
		current_layout.visible = false

	var from = current_layout_name
	current_layout = layouts[layout_name]
	current_layout_name = layout_name
	current_layout.visible = true

	if current_layout.has_method("activate"):
		current_layout.activate()

	layout_changed.emit(from, layout_name)

func get_current_layout() -> Control:
	return current_layout

func update_data(data: Dictionary) -> void:
	if current_layout and current_layout.has_method("update_data"):
		current_layout.update_data(data)

func update_mode_display(mode: String) -> void:
	if current_layout and current_layout.has_method("update_mode_display"):
		current_layout.update_mode_display(mode)

func set_recording_state(is_recording: bool) -> void:
	if current_layout and current_layout.has_method("set_recording_state"):
		current_layout.set_recording_state(is_recording)
