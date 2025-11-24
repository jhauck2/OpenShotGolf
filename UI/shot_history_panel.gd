extends PanelContainer

signal drag_started
signal drag_ended(panel)

var dragging := false
var drag_offset := Vector2.ZERO

# Shot history data
var shot_history: Array[Dictionary] = []
var max_shots: int = 10  # Keep last 10 shots
var is_target_mode: bool = true


func _ready() -> void:
	# Connect to GameState shot history signal
	if GameState:
		GameState.shot_recorded.connect(_on_game_state_shot_recorded)

	_update_display()


func set_mode(target_mode: bool) -> void:
	is_target_mode = target_mode
	_update_display()


func add_shot(shot_data: Dictionary) -> void:
	# Add to beginning of array
	shot_history.push_front(shot_data)

	# Keep only last max_shots
	if shot_history.size() > max_shots:
		shot_history.resize(max_shots)

	_update_display()


func clear_history() -> void:
	shot_history.clear()
	_update_display()


func _update_display() -> void:
	if not has_node("MarginContainer/ScrollContainer/VBoxContainer/HistoryList"):
		return

	var list_label = $MarginContainer/ScrollContainer/VBoxContainer/HistoryList

	if shot_history.is_empty():
		list_label.text = "No shots yet"
		return

	var text = ""
	var shot_num = shot_history.size()

	for shot in shot_history:
		if is_target_mode:
			# Target Practice: # | Club | Carry/Total | Points
			var club = shot.get("Club", "---")
			var carry = shot.get("Carry", "---")
			var distance = shot.get("Distance", "---")
			var points = shot.get("Points", "0")
			text += "#%d | %s | %s/%s yd | %s pts\n" % [shot_num, club, carry, distance, points]
		else:
			# Free Practice: # | Club | Carry | Total | Roll | Offline
			var club = shot.get("Club", "---")
			var carry = shot.get("Carry", "---")
			var distance = shot.get("Distance", "---")
			var roll = shot.get("Roll", "---")
			var offline = shot.get("Offline", "---")
			text += "#%d | %s | C:%s | T:%s | R:%s | %s\n" % [shot_num, club, carry, distance, roll, offline]

		shot_num -= 1

	list_label.text = text.strip_edges()


func _gui_input(event):
	if event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				emit_signal("drag_started")
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
			else:
				emit_signal("drag_ended", self)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset


func _on_game_state_shot_recorded(shot_data: Dictionary) -> void:
	"""Handle shots recorded from GameState"""
	add_shot(shot_data)
