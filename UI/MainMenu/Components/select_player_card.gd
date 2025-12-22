extends Button

const PlayerData = preload("res://Utils/Data/player_data.gd")


func set_player_data(player_data: PlayerData) -> void:
	if not player_data:
		return

	%PlayerName.text = player_data.name.capitalize()
	%Info.text = "HCP: %s" % player_data.get_handicap_string()
