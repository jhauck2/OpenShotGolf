extends Control

## Profile Screen
##
## Displays the selected player's profile information and statistics.

@onready var name_label = $Panel/MarginContainer/VBoxContainer/ProfileHeader/MarginContainer/HBoxContainer/ProfileInfo/NameSection/Name
@onready var status_label = $Panel/MarginContainer/VBoxContainer/ProfileHeader/MarginContainer/HBoxContainer/ProfileInfo/Status
@onready var stats_grid = $Panel/MarginContainer/VBoxContainer/ProfileHeader/MarginContainer/HBoxContainer/ProfileInfo/HBoxContainer/Stats
@onready var recent_rounds_container = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ProfileContent/MarginContainer/VBoxContainer/RecentRounds/MarginContainer/VBoxContainer
@onready var career_stats_grid = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ProfileContent/MarginContainer/VBoxContainer/CareerStats/MarginContainer/Grid
@onready var rename_modal = get_node("RenameModal")
@onready var delete_modal = get_node("DeleteConfirmModal")

const PlayerData = preload("res://Utils/Data/player_data.gd")
var current_player: PlayerData = null


func _ready() -> void:
	# Connect to EventBus signals
	EventBus.player_renamed.connect(_on_player_renamed)

	# Connect to modal confirmation signals
	var rename_confirm_btn = rename_modal.find_child("ConfirmBtn", true, false)
	if rename_confirm_btn:
		rename_confirm_btn.pressed.connect(_on_rename_confirmed)

	var delete_confirm_btn = delete_modal.find_child("ConfirmBtn2", true, false) # "DELETE" button
	if delete_confirm_btn:
		delete_confirm_btn.pressed.connect(_on_delete_confirmed)

	# Set current player
	current_player = GlobalSettings.current_player

	if current_player:
		_populate_player_data()
	else:
		push_warning("No player selected for profile screen")
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _populate_player_data() -> void:
	if not current_player:
		return

	name_label.text = current_player.name
	status_label.text = "Guest Player" if current_player.is_guest else "Registered Player"

	_update_header_stats()
	_load_recent_rounds()
	_load_career_stats()


func _update_header_stats() -> void:
	if not current_player:
		return
	
	# Clear any existing stats
	for child in stats_grid.get_children():
		child.queue_free()

	# Get stats from DB
	var player_stats = DatabaseManager.get_player_statistics(current_player.id)

	# Create and add stat items
	var handicap_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	handicap_item.title = "Handicap"
	handicap_item.value = current_player.get_handicap_string()
	stats_grid.add_child(handicap_item)

	var rounds_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	rounds_item.title = "Total Rounds"
	rounds_item.value = str(player_stats.get("total_rounds", 0))
	stats_grid.add_child(rounds_item)

	var avg_score_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	avg_score_item.title = "Avg Score"
	avg_score_item.value = "%.1f" % player_stats.get("avg_score", 0.0)
	stats_grid.add_child(avg_score_item)


func _load_recent_rounds() -> void:
	if not current_player:
		return

	# Clear any existing items
	for child in recent_rounds_container.get_children():
		child.queue_free()

	var recent_sessions = DatabaseManager.get_player_sessions(current_player.id, 5)

	if recent_sessions.is_empty():
		var label = Label.new()
		label.text = "No recent rounds played."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recent_rounds_container.add_child(label)
		return

	for session in recent_sessions:
		var session_item = preload("res://UI/Components/MenuHistoricItem/menu_historic_item.tscn").instantiate()
		session_item.title = session.get("mode", "Practice Session").capitalize()
		
		# Get shot count as score
		var shots = DatabaseManager.get_session_shots(session.id)
		session_item.value = str(shots.size())
		
		session_item.date = _format_date(session.get("started_at", ""))
		recent_rounds_container.add_child(session_item)


func _load_career_stats() -> void:
	if not current_player:
		return
		
	# Clear any existing stats
	for child in career_stats_grid.get_children():
		child.queue_free()

	var career_stats = DatabaseManager.get_player_career_stats(current_player.id)

	# Longest Drive
	var longest_drive_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	longest_drive_item.title = "Longest Drive"
	longest_drive_item.value = "%.1f yd" % career_stats.get("longest_drive", 0.0)
	career_stats_grid.add_child(longest_drive_item)

	# Best 9-Hole Score
	var best_score_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	best_score_item.title = "Best Target Score"
	best_score_item.value = str(career_stats.get("best_9_hole", 0))
	career_stats_grid.add_child(best_score_item)

	# GIR %
	var gir_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	gir_item.title = "Accuracy %"
	gir_item.value = "%.1f%%" % career_stats.get("gir_percentage", 0.0)
	career_stats_grid.add_child(gir_item)

	# Eagles
	var eagles_item = preload("res://UI/Components/MenuStatItem/menu_stat_item.tscn").instantiate()
	eagles_item.title = "Bullseyes"
	eagles_item.value = str(career_stats.get("eagles", 0))
	career_stats_grid.add_child(eagles_item)


func _format_date(date_string: String) -> String:
	if date_string.is_empty():
		return ""
	var parts = date_string.split("T")[0].split("-")
	if parts.size() >= 3:
		var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var month_idx = int(parts[1]) - 1
		if month_idx >= 0 and month_idx < 12:
			return "%s %s, %s" % [months[month_idx], parts[2], parts[0]]
	return date_string


#
# Signal Handlers
#

func _on_back_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_stats_btn_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/stats_screen.tscn")


func _on_edit_btn_pressed() -> void:
	# Populate and show rename modal
	var input = rename_modal.find_child("Input", true, false)
	if input:
		input.text = current_player.name
	rename_modal.show()


func _on_delete_btn_pressed() -> void:
	# Populate and show delete modal
	var label = delete_modal.find_child("Value", true, false)
	if label:
		label.text = "Player: %s" % current_player.name
	delete_modal.show()


func _on_rename_confirmed() -> void:
	var input = rename_modal.find_child("Input", true, false)
	if input and not input.text.is_empty():
		var new_name = input.text
		var success = DatabaseManager.update_player(current_player.id, {"name": new_name})
		if success:
			# Update local player object and emit signal
			current_player.name = new_name
			GlobalSettings.set_current_player(current_player) # Update global state
			EventBus.player_renamed.emit({"id": current_player.id, "name": current_player.name})
			rename_modal.hide()
			# The _on_player_renamed handler will refresh the UI
		else:
			push_error("Failed to rename player in database.")


func _on_delete_confirmed() -> void:
	var player_id_to_delete = current_player.id
	var success = DatabaseManager.delete_player(player_id_to_delete)
	delete_modal.hide()

	if success:
		EventBus.player_deleted.emit(player_id_to_delete)
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
	else:
		push_error("Failed to delete player from database.")


func _on_player_renamed(player_data: Dictionary) -> void:
	if current_player and player_data.get("id") == current_player.id:
		# Reload player data to get all fresh info
		var player_dict := DatabaseManager.get_player(current_player.id)
		if not player_dict.is_empty():
			current_player = PlayerData.from_dict(player_dict)
			GlobalSettings.set_current_player(current_player)
			_populate_player_data()
