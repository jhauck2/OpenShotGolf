extends Node

@warning_ignore("unused_signal")
signal club_selected(club_name: String)
@warning_ignore("unused_signal")
signal player_renamed(player_data: Dictionary)
@warning_ignore("unused_signal")
signal player_deleted(player_id: int)

func register(node, event, callback):
# warning-ignore:return_value_discarded
	connect(event, node, callback)


func call_event(event_name):
	emit_signal(event_name)
