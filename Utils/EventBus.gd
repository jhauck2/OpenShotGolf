extends Node

@warning_ignore("unused_signal")
signal club_selected(club_name: String)

@warning_ignore("unused_signal")
signal camera_changed(camera_mode: int)

@warning_ignore("unused_signal")
signal layout_changed(layout_type: String)

@warning_ignore("unused_signal")
signal recording_toggled

@warning_ignore("unused_signal")
signal session_started(user: String, dir: String)

func register(node, event, callback):
# warning-ignore:return_value_discarded
	connect(event, node, callback)


func call_event(event_name):
	emit_signal(event_name)
