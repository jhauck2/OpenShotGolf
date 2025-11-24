extends Control

## Custom Layout - Wraps the existing range_ui for layout switching
## This preserves the user's custom draggable panel layout

signal layout_switch_requested(layout_name: String)
signal club_selected(club: String)
signal exit_pressed
signal toggle_overlay_pressed
signal rec_button_pressed
signal set_session(dir: String, player_name: String)
signal camera_button_pressed
signal hit_shot(data: Dictionary)

var range_ui: Control = null


func _ready() -> void:
	_setup_range_ui()
	_setup_unified_header()


func _setup_range_ui() -> void:
	# The RangeUI node should already be added as a child in the scene
	if has_node("RangeUI"):
		range_ui = $RangeUI

		# Connect signals from the old RangeUI
		if range_ui.has_signal("club_selected"):
			range_ui.club_selected.connect(_on_range_ui_club_selected)
		if range_ui.has_signal("toggle_overlay_pressed"):
			range_ui.toggle_overlay_pressed.connect(_on_range_ui_toggle_overlay)
		if range_ui.has_signal("rec_button_pressed"):
			range_ui.rec_button_pressed.connect(_on_range_ui_rec_pressed)
		if range_ui.has_signal("set_session"):
			range_ui.set_session.connect(_on_range_ui_set_session)
		if range_ui.has_signal("hit_shot"):
			range_ui.hit_shot.connect(_on_range_ui_hit_shot)

	# Hide the original header bar (we use unified header instead)
	if range_ui and range_ui.has_node("HBoxContainer"):
		var hbox = range_ui.get_node("HBoxContainer")
		hbox.visible = false

	# Connect to the club selector from the tscn
	if has_node("ClubSelector"):
		var club_selector = $ClubSelector
		if club_selector.has_signal("club_selected"):
			club_selector.club_selected.connect(_on_club_selector_club_selected)


func _setup_unified_header() -> void:
	# Connect signals from unified header
	if has_node("UnifiedHeader"):
		var header = $UnifiedHeader
		if header.has_signal("layout_switch_pressed"):
			header.layout_switch_pressed.connect(_on_layout_switch_pressed)
		if header.has_signal("camera_pressed"):
			header.camera_pressed.connect(_on_camera_pressed)
		if header.has_signal("rec_button_pressed"):
			header.rec_button_pressed.connect(_on_rec_button_pressed)
		if header.has_signal("exit_pressed"):
			header.exit_pressed.connect(_on_exit_pressed)


func update_data(data: Dictionary) -> void:
	if range_ui:
		range_ui.set_data(data)


func _on_range_ui_club_selected(club: String) -> void:
	emit_signal("club_selected", club)


func _on_club_selector_club_selected(club: String) -> void:
	"""Handle club selection from the tscn-based club selector"""
	emit_signal("club_selected", club)


func _on_range_ui_toggle_overlay() -> void:
	emit_signal("toggle_overlay_pressed")


func _on_range_ui_rec_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_range_ui_set_session(dir: String, player_name: String) -> void:
	emit_signal("set_session", dir, player_name)


func _on_range_ui_hit_shot(data: Dictionary) -> void:
	emit_signal("hit_shot", data)


func _on_layout_switch_pressed() -> void:
	# Determine next layout to cycle to
	# This will be set by the layout_manager based on the current layout
	# For now, default to Detail if next_layout is not set
	var next_layout = "Detail"

	# If the layout manager has told us what to request, use that
	if has_meta("next_layout"):
		next_layout = get_meta("next_layout")

	print("Custom layout: Layout switch pressed - requesting ", next_layout, " layout")
	print("Custom layout: layout_switch_requested signal defined: ", has_signal("layout_switch_requested"))
	print("Custom layout: Emitting signal with next_layout=", next_layout)
	emit_signal("layout_switch_requested", next_layout)
	print("Custom layout: Signal emitted successfully")


func _on_camera_pressed() -> void:
	emit_signal("camera_button_pressed")
	
func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")

func _on_exit_pressed() -> void:
	emit_signal("exit_pressed")


# Methods to forward recording state changes
func _on_session_recorder_recording_state(value: bool) -> void:
	if range_ui and range_ui.has_method("_on_session_recorder_recording_state"):
		range_ui._on_session_recorder_recording_state(value)


func _on_session_recorder_set_session(user: String, dir: String) -> void:
	if range_ui and range_ui.has_method("_on_session_recorder_set_session"):
		range_ui._on_session_recorder_set_session(user, dir)
