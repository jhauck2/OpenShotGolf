extends Control

## Layout Manager - Handles switching between Custom, Detail, and Overview layouts
## Manages data flow to active layout and handles layout transitions

signal club_selected(club: String)
signal exit_pressed
signal toggle_overlay_pressed
signal rec_button_pressed
signal set_session(dir: String, player_name: String)
signal recording_state(value: bool)
signal session_set(user: String, dir: String)
signal camera_button_pressed
signal hit_shot(data: Dictionary)

enum LayoutType {
	CUSTOM,   # Original draggable UI
	DETAIL,   # Data-heavy TrackMan style
	OVERVIEW  # Immersive 3D-focused
}

var current_layout: LayoutType = LayoutType.CUSTOM
var custom_layout: Control = null
var detail_layout: Control = null
var overview_layout: Control = null

# Preload layouts
var CustomLayoutScene
var DetailLayoutScene
var OverviewLayoutScene

# Current ball data
var ball_data: Dictionary = {}

# Mode state (preserved across layout switches)
var current_mode_text: String = "FREE PRACTICE"
var current_target_text: String = ""
var main_camera_ref: Camera3D = null

# Shot history (preserved across layout switches)
var shot_history: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_init_custom_layout")


func _init_custom_layout() -> void:
	if CustomLayoutScene == null:
		CustomLayoutScene = preload("res://UI/Layouts/custom_layout.tscn")
	switch_to_layout(LayoutType.CUSTOM)


func switch_to_layout(layout_type: LayoutType) -> void:
	# Restore camera if switching away from Detail layout
	if current_layout == LayoutType.DETAIL:
		_restore_main_camera()

	current_layout = layout_type

	# Remove existing layouts
	_clear_layouts()

	# Load and add the requested layout
	match layout_type:
		LayoutType.CUSTOM:
			if CustomLayoutScene == null:
				CustomLayoutScene = preload("res://UI/Layouts/custom_layout.tscn")
			_load_custom_layout()
		LayoutType.DETAIL:
			if DetailLayoutScene == null:
				DetailLayoutScene = preload("res://UI/Layouts/detail_layout.tscn")
			_load_detail_layout()
		LayoutType.OVERVIEW:
			if OverviewLayoutScene == null:
				OverviewLayoutScene = preload("res://UI/Layouts/overview_layout.tscn")
			_load_overview_layout()

	# Restore mode state in new layout
	update_mode_display(current_mode_text, current_target_text)

	# Update layout button text to show next layout
	_update_layout_button_text()

	# Update with current data
	if not ball_data.is_empty():
		update_data(ball_data)


func _clear_layouts() -> void:
	if custom_layout:
		remove_child(custom_layout)
		custom_layout.queue_free()
		custom_layout = null

	if detail_layout:
		remove_child(detail_layout)
		detail_layout.queue_free()
		detail_layout = null

	if overview_layout:
		remove_child(overview_layout)
		overview_layout.queue_free()
		overview_layout = null


func _load_custom_layout() -> void:
	custom_layout = CustomLayoutScene.instantiate()
	custom_layout.name = "CustomLayout"
	add_child(custom_layout)

	# Set metadata for layout cycling
	custom_layout.set_meta("next_layout", "Detail")

	# Defer signal connections to ensure custom_layout is fully ready
	call_deferred("_connect_custom_layout_signals")



func _load_detail_layout() -> void:
	detail_layout = DetailLayoutScene.instantiate()
	detail_layout.name = "DetailLayout"
	add_child(detail_layout)

	# Set metadata for layout cycling
	detail_layout.set_meta("next_layout", "Overview")

	# Defer signal connections to ensure detail_layout is fully ready
	call_deferred("_connect_detail_layout_signals")



func _load_overview_layout() -> void:
	overview_layout = OverviewLayoutScene.instantiate()
	overview_layout.name = "OverviewLayout"
	add_child(overview_layout)

	# Set metadata for layout cycling
	overview_layout.set_meta("next_layout", "Custom")

	# Defer signal connections to ensure overview_layout is fully ready
	call_deferred("_connect_overview_layout_signals")



func _connect_custom_layout_signals() -> void:
	"""Connect signals for custom layout (deferred to ensure _ready is complete)"""
	if not custom_layout:
		return

	if custom_layout.has_signal("layout_switch_requested"):
		if not custom_layout.layout_switch_requested.is_connected(_on_layout_switch_requested):
			custom_layout.layout_switch_requested.connect(_on_layout_switch_requested)

	if not custom_layout.club_selected.is_connected(_on_club_selected):
		custom_layout.club_selected.connect(_on_club_selected)
	if not custom_layout.toggle_overlay_pressed.is_connected(_on_toggle_overlay_pressed):
		custom_layout.toggle_overlay_pressed.connect(_on_toggle_overlay_pressed)
	if not custom_layout.rec_button_pressed.is_connected(_on_rec_button_pressed):
		custom_layout.rec_button_pressed.connect(_on_rec_button_pressed)
	if not custom_layout.set_session.is_connected(_on_set_session):
		custom_layout.set_session.connect(_on_set_session)
	if not custom_layout.camera_button_pressed.is_connected(_on_camera_button_pressed):
		custom_layout.camera_button_pressed.connect(_on_camera_button_pressed)
	if not custom_layout.exit_pressed.is_connected(_on_exit_pressed):
		custom_layout.exit_pressed.connect(_on_exit_pressed)
	if custom_layout.has_signal("hit_shot"):
		if not custom_layout.hit_shot.is_connected(_on_layout_manager_hit_shot):
			custom_layout.hit_shot.connect(_on_layout_manager_hit_shot)


func _connect_detail_layout_signals() -> void:
	"""Connect signals for detail layout (deferred to ensure _ready is complete)"""
	if not detail_layout:
		return

	if detail_layout.has_signal("layout_switch_requested"):
		if not detail_layout.layout_switch_requested.is_connected(_on_layout_switch_requested):
			detail_layout.layout_switch_requested.connect(_on_layout_switch_requested)

	if not detail_layout.club_selected.is_connected(_on_club_selected):
		detail_layout.club_selected.connect(_on_club_selected)
	if not detail_layout.exit_pressed.is_connected(_on_exit_pressed):
		detail_layout.exit_pressed.connect(_on_exit_pressed)
	if not detail_layout.camera_button_pressed.is_connected(_on_camera_button_pressed):
		detail_layout.camera_button_pressed.connect(_on_camera_button_pressed)
	if not detail_layout.rec_button_pressed.is_connected(_on_rec_button_pressed):
		detail_layout.rec_button_pressed.connect(_on_rec_button_pressed)

	# Pass persistent shot history to detail layout
	if detail_layout.has_method("set_shot_history"):
		detail_layout.set_shot_history(shot_history)

	# Setup camera rendering to SubViewport, deferred by one frame
	call_deferred("_setup_detail_viewport_camera")


func _connect_overview_layout_signals() -> void:
	"""Connect signals for overview layout (deferred to ensure _ready is complete)"""
	if not overview_layout:
		return

	if overview_layout.has_signal("layout_switch_requested"):
		if not overview_layout.layout_switch_requested.is_connected(_on_layout_switch_requested):
			overview_layout.layout_switch_requested.connect(_on_layout_switch_requested)

	if not overview_layout.club_selected.is_connected(_on_club_selected):
		overview_layout.club_selected.connect(_on_club_selected)
	if not overview_layout.exit_pressed.is_connected(_on_exit_pressed):
		overview_layout.exit_pressed.connect(_on_exit_pressed)
	if not overview_layout.camera_button_pressed.is_connected(_on_camera_button_pressed):
		overview_layout.camera_button_pressed.connect(_on_camera_button_pressed)
	if not overview_layout.rec_button_pressed.is_connected(_on_rec_button_pressed):
		overview_layout.rec_button_pressed.connect(_on_rec_button_pressed)


func update_data(data: Dictionary) -> void:
	ball_data = data

	# Forward data to active layout
	if custom_layout and current_layout == LayoutType.CUSTOM:
		custom_layout.update_data(data)
	elif detail_layout and current_layout == LayoutType.DETAIL:
		detail_layout.update_data(data)
	elif overview_layout and current_layout == LayoutType.OVERVIEW:
		overview_layout.update_data(data)


func _on_layout_switch_requested(layout_name: String) -> void:
	match layout_name:
		"Custom":
			switch_to_layout(LayoutType.CUSTOM)
		"Detail":
			switch_to_layout(LayoutType.DETAIL)
		"Overview":
			switch_to_layout(LayoutType.OVERVIEW)


func _on_club_selected(club: String) -> void:
	emit_signal("club_selected", club)


func _on_exit_pressed() -> void:
	emit_signal("exit_pressed")


func _on_toggle_overlay_pressed() -> void:
	emit_signal("toggle_overlay_pressed")


func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_set_session(dir: String, player_name: String) -> void:
	emit_signal("set_session", dir, player_name)


func forward_recording_state(value: bool) -> void:
	# Forward to custom layout if active
	if custom_layout and current_layout == LayoutType.CUSTOM:
		custom_layout._on_session_recorder_recording_state(value)


func forward_session_set(user: String, dir: String) -> void:
	# Forward to custom layout if active
	if custom_layout and current_layout == LayoutType.CUSTOM:
		custom_layout._on_session_recorder_set_session(user, dir)


func get_current_layout_name() -> String:
	match current_layout:
		LayoutType.CUSTOM:
			return "Custom"
		LayoutType.DETAIL:
			return "Detail"
		LayoutType.OVERVIEW:
			return "Overview"
		_:
			return "Unknown"


func add_shot_to_history(shot_data: Dictionary) -> void:
	# Store shot in layout_manager for persistence across layout switches
	shot_history.push_front(shot_data)  # Add to front (newest first)
	if shot_history.size() > 10:  # Keep last 10 shots
		shot_history.resize(10)

	# Forward shot to detail layout if it exists
	if detail_layout:
		detail_layout.add_shot_to_history(shot_data)


func _on_camera_button_pressed() -> void:
	emit_signal("camera_button_pressed")


func update_mode_display(mode_text: String, target_text: String = "") -> void:
	# Save mode state so it persists across layout switches
	current_mode_text = mode_text
	current_target_text = target_text

	# Update unified header in all layouts
	if custom_layout and custom_layout.has_node("UnifiedHeader"):
		custom_layout.get_node("UnifiedHeader").set_mode_text(mode_text)
		custom_layout.get_node("UnifiedHeader").set_target_text(target_text)

	if detail_layout and detail_layout.has_node("TopBar"):
		detail_layout.get_node("TopBar").set_mode_text(mode_text)
		detail_layout.get_node("TopBar").set_target_text(target_text)

	if overview_layout and overview_layout.has_node("TopBar"):
		overview_layout.get_node("TopBar").set_mode_text(mode_text)
		overview_layout.get_node("TopBar").set_target_text(target_text)


func _update_layout_button_text() -> void:
	"""Update the layout cycle button text based on current layout"""
	var next_layout_text = ""
	match current_layout:
		LayoutType.CUSTOM:
			next_layout_text = "Detail >"
		LayoutType.DETAIL:
			next_layout_text = "Overview >"
		LayoutType.OVERVIEW:
			next_layout_text = "Custom >"

	# Update button text in currently active layout
	if custom_layout and custom_layout.has_node("UnifiedHeader"):
		custom_layout.get_node("UnifiedHeader").set_next_layout_text(next_layout_text)

	if detail_layout and detail_layout.has_node("TopBar"):
		detail_layout.get_node("TopBar").set_next_layout_text(next_layout_text)

	if overview_layout and overview_layout.has_node("TopBar"):
		overview_layout.get_node("TopBar").set_next_layout_text(next_layout_text)


func _setup_detail_viewport_camera() -> void:
	"""Configure the main camera to render to Detail layout's SubViewport"""
	if not detail_layout:
		return

	# Get the camera from the parent Range scene by traversing up the tree
	# The hierarchy is: Range -> LayoutManager
	var range_node = get_parent()

	# Traverse up to find the actual Range node if needed
	while range_node and range_node.name != "Range" and range_node.get_parent():
		range_node = range_node.get_parent()

	if range_node and range_node.has_node("CameraController"):
		var controller = range_node.get_node("CameraController")

		# Assume controller has a method to get the active camera.
		# This is a common pattern for camera managers.
		if controller.has_method("get_active_camera"):
			var camera = controller.get_active_camera()

			if camera and camera is Camera3D:
				if detail_layout.has_method("setup_viewport_camera"):
					# Store ref, disable for main view, and pass to detail layout
					main_camera_ref = camera
					main_camera_ref.current = false
					detail_layout.setup_viewport_camera(camera)
		else:
			# As a fallback, iterate through children to find the first Camera3D
			var found_camera: Camera3D = null
			for child in controller.get_children():
				if child is Camera3D:
					found_camera = child
					break

			if found_camera:
				if detail_layout.has_method("setup_viewport_camera"):
					# Store ref, disable for main view, and pass to detail layout
					main_camera_ref = found_camera
					main_camera_ref.current = false
					detail_layout.setup_viewport_camera(found_camera)


func on_active_camera_changed(new_camera: Camera3D) -> void:
	if current_layout == LayoutType.DETAIL:
		# When camera cycles, the new one becomes current. Disable it for the main view.
		new_camera.current = false
		# The old `main_camera_ref` is no longer the active one.
		# Update our reference to the new one so it can be restored later.
		main_camera_ref = new_camera

		if detail_layout and detail_layout.has_method("update_main_camera_reference"):
			detail_layout.update_main_camera_reference(new_camera)


func _restore_main_camera() -> void:
	"""Clean up the duplicate camera from Detail layout and restore the main camera"""
	# Re-enable the main camera that was active
	if main_camera_ref:
		main_camera_ref.current = true
		main_camera_ref = null

	if detail_layout and detail_layout.has_method("cleanup_viewport_camera"):
		detail_layout.cleanup_viewport_camera()


func _on_layout_manager_hit_shot(data: Dictionary) -> void:
	"""Forward hit_shot signal from custom_layout"""
	emit_signal("hit_shot", data)
