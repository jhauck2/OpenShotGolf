extends "res://UI/Layouts/base_layout.gd"

var range_ui: Control

func _connect_to_range_systems() -> void:
	if not range_ui or not range_ref:
		return

	var golf_ball = range_ref.get_node_or_null("GolfBall")
	if golf_ball:
		range_ui.hit_shot.connect(golf_ball._on_range_ui_hit_shot)

	var session_recorder = range_ref.get_node_or_null("SessionRecorder")
	if session_recorder:
		range_ui.rec_button_pressed.connect(session_recorder.toggle_recording)
		range_ui.set_session.connect(session_recorder._on_range_ui_set_session)

		session_recorder.recording_state.connect(range_ui._on_session_recorder_recording_state)
		session_recorder.set_session.connect(range_ui._on_session_recorder_set_session)

func _ready() -> void:
	range_ui = get_node_or_null("RangeUI")
	if range_ui:
		EventBus.club_selected.connect(_on_club_selected)
		range_ui.rec_button_pressed.connect(rec_button_pressed.emit)
		range_ui.hit_shot.connect(_on_hit_shot)
		range_ui.set_session.connect(_on_set_session)

	_connect_to_range_systems()

func activate() -> void:
	visible = true

func deactivate() -> void:
	visible = false

func update_data(data: Dictionary) -> void:
	if range_ui and range_ui.has_method("set_data"):
		range_ui.set_data(data)

func update_mode_display(_mode: String) -> void:
	pass

func set_recording_state(is_recording: bool) -> void:
	pass

func _on_club_selected(club: String) -> void:
	club_selected.emit(club)

func _on_hit_shot(data: Dictionary) -> void:
	pass

func _on_set_session(dir: String, player_name: String) -> void:
	pass
