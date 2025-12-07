class_name BagManager
extends RefCounted

## Bag Manager
##
## Manages a player's golf bag with 14-club limit enforcement.
## Handles adding, removing, and organizing clubs in the bag.

const MAX_CLUBS = 14
const ALL_CLUBS = [
	"Dr", "3w", "5w",
	"2H", "3H", "4H",
	"1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i",
	"Pw", "Gw", "Sw", "Lw"
]

const CLUB_NAMES = {
	"Dr": "Driver",
	"3w": "3 Wood",
	"5w": "5 Wood",
	"2H": "2 Hybrid",
	"3H": "3 Hybrid",
	"4H": "4 Hybrid",
	"1i": "1 Iron",
	"2i": "2 Iron",
	"3i": "3 Iron",
	"4i": "4 Iron",
	"5i": "5 Iron",
	"6i": "6 Iron",
	"7i": "7 Iron",
	"8i": "8 Iron",
	"9i": "9 Iron",
	"Pw": "Pitching Wedge",
	"Gw": "Gap Wedge",
	"Sw": "Sand Wedge",
	"Lw": "Lob Wedge"
}

signal bag_changed(clubs: Array)
signal validation_error(message: String)

var player_id: int = -1
var current_bag_id: int = -1
var clubs: Array = []  # Array of club codes


func load_player_bag(pid: int) -> void:
	player_id = pid

	var bags = DatabaseManager.get_player_bags(player_id)
	if bags.is_empty():
		# Create default bag in database
		_create_default_bag_db()
	else:
		# Load default or first bag
		for bag in bags:
			if bag.get("is_default", 0) == 1:
				_load_bag(bag.id)
				return
		_load_bag(bags[0].id)


func _create_default_bag_db() -> void:
	var default_clubs = ["Dr", "3w", "5w", "4H", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw"]
	current_bag_id = DatabaseManager.create_bag(player_id, "Default Bag", default_clubs)
	clubs = default_clubs
	emit_signal("bag_changed", clubs)


func _load_bag(bag_id: int) -> void:
	current_bag_id = bag_id
	clubs = DatabaseManager.get_bag_clubs(bag_id)
	emit_signal("bag_changed", clubs)


func add_club(club_code: String) -> bool:
	if clubs.size() >= MAX_CLUBS:
		emit_signal("validation_error", "Bag is full (14 clubs maximum)")
		return false

	if club_code in clubs:
		emit_signal("validation_error", "Club already in bag")
		return false

	if club_code not in ALL_CLUBS:
		emit_signal("validation_error", "Invalid club code: " + club_code)
		return false

	clubs.append(club_code)
	_save_bag()
	emit_signal("bag_changed", clubs)
	return true


func remove_club(club_code: String) -> bool:
	if club_code not in clubs:
		emit_signal("validation_error", "Club not in bag")
		return false

	clubs.erase(club_code)
	_save_bag()
	emit_signal("bag_changed", clubs)
	return true


func replace_club(old_club: String, new_club: String) -> bool:
	if old_club not in clubs:
		emit_signal("validation_error", "Club to replace not in bag")
		return false

	if new_club in clubs:
		emit_signal("validation_error", "New club already in bag")
		return false

	if new_club not in ALL_CLUBS:
		emit_signal("validation_error", "Invalid club code: " + new_club)
		return false

	var index = clubs.find(old_club)
	clubs[index] = new_club
	_save_bag()
	emit_signal("bag_changed", clubs)
	return true


func _save_bag() -> void:
	if current_bag_id > 0:
		DatabaseManager.update_bag(current_bag_id, clubs)


func get_clubs() -> Array:
	return clubs.duplicate()


func get_available_clubs() -> Array:
	var available: Array = []
	for club in ALL_CLUBS:
		if club not in clubs:
			available.append(club)
	return available


func get_club_count() -> int:
	return clubs.size()


func get_remaining_slots() -> int:
	return MAX_CLUBS - clubs.size()


func is_full() -> bool:
	return clubs.size() >= MAX_CLUBS


func has_club(club_code: String) -> bool:
	return club_code in clubs


static func get_club_name(club_code: String) -> String:
	return CLUB_NAMES.get(club_code, club_code)


func clear() -> void:
	clubs.clear()
	_save_bag()
	emit_signal("bag_changed", clubs)


func reset_to_default() -> void:
	clubs = ["Dr", "3w", "5w", "4H", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw"]
	_save_bag()
	emit_signal("bag_changed", clubs)
