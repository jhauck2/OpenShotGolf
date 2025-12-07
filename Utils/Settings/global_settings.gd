extends Node

signal settings_changed
signal player_changed(player: PlayerData)
signal active_players_changed(players: Array)

# Range Settings
var range_settings := RangeSettings.new()

var current_player: PlayerData = null

var active_players: Array = []  # Array of PlayerData
const MAX_ACTIVE_PLAYERS = 4


func _ready() -> void:
	EventBus.player_deleted.connect(_on_player_deleted)
	EventBus.player_renamed.connect(_on_player_renamed)


func _on_player_deleted(player_id: int) -> void:
	# If the deleted player is the one being viewed in a profile, clear it
	if current_player and current_player.id == player_id:
		clear_current_player()

	# Remove from the list of active players for the next session
	remove_active_player(player_id)


func _on_player_renamed(player_data: Dictionary) -> void:
	var player_id = player_data.get("id")

	# Update the player being viewed in a profile
	if current_player and current_player.id == player_id:
		current_player.name = player_data.get("name", current_player.name)
		emit_signal("player_changed", current_player)

	# Update player in the active list
	for player in active_players:
		if player.id == player_id:
			player.name = player_data.get("name", player.name)
			emit_signal("active_players_changed", active_players)
			break


func set_current_player(player: PlayerData) -> void:
	current_player = player
	emit_signal("player_changed", player)
	print("GlobalSettings: Current player set to ", player.name if player else "None")


func get_current_player_id() -> int:
	if current_player and current_player.get("id"):
		return current_player.id
	# If no current player, use first active player
	if active_players.size() > 0 and active_players[0].get("id"):
		return active_players[0].id
	return -1


func has_player() -> bool:
	return current_player != null or active_players.size() > 0


func get_current_player_name() -> String:
	if current_player and current_player.get("name"):
		return current_player.name
	if active_players.size() > 0 and active_players[0].get("name"):
		return active_players[0].name
	return "Guest"


func clear_current_player() -> void:
	current_player = null
	emit_signal("player_changed", null)


# ============================================================================
# ACTIVE SESSION PLAYERS
# ============================================================================

func add_active_player(player: PlayerData) -> bool:
	if active_players.size() >= MAX_ACTIVE_PLAYERS:
		push_warning("Cannot add more than %d players" % MAX_ACTIVE_PLAYERS)
		return false

	# Check if player already in session
	for p in active_players:
		if p.id == player.id:
			push_warning("Player already in session: %s" % player.name)
			return false

	active_players.append(player)
	emit_signal("active_players_changed", active_players)
	print("GlobalSettings: Added active player - %s" % player.name)
	return true


func remove_active_player(player_id: int) -> bool:
	for i in range(active_players.size()):
		if active_players[i].id == player_id:
			var removed = active_players[i]
			active_players.remove_at(i)
			emit_signal("active_players_changed", active_players)
			print("GlobalSettings: Removed active player - %s" % removed.name)
			return true
	return false


func get_active_players() -> Array:
	return active_players.duplicate()


func get_active_player_count() -> int:
	return active_players.size()


func can_add_player() -> bool:
	return active_players.size() < MAX_ACTIVE_PLAYERS


func clear_active_players() -> void:
	active_players.clear()
	emit_signal("active_players_changed", active_players)


func get_active_player(index: int) -> PlayerData:
	if index >= 0 and index < active_players.size():
		return active_players[index]
	return null


func reset_defaults() -> void:
	range_settings.reset_defaults()
	emit_signal("settings_changed")
