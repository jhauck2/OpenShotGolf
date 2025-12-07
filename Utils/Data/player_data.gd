extends RefCounted
class_name PlayerData

## Player Data Class
##
## Represents a player's profile data.
## Used for passing player information between components.

var id: int = -1
var name: String = ""
var handicap: float = -1
var preferred_units: int = 1  # Enums.Units.IMPERIAL
var is_guest: bool = false
var created_at: String = ""
var current_bag_id: int = -1


## Create PlayerData from dictionary (database row)
static func from_dict(data: Dictionary) -> PlayerData:
	var player = PlayerData.new()
	player.id = data.get("id", -1)
	player.name = data.get("name", "")
	player.handicap = data.get("handicap", -1)
	player.preferred_units = data.get("preferred_units", 1)
	player.is_guest = data.get("is_guest", 0) == 1
	player.created_at = data.get("created_at", "")
	return player


## Convert to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"handicap": handicap,
		"preferred_units": preferred_units,
		"is_guest": is_guest,
		"created_at": created_at
	}


## Get display name with guest indicator
func get_display_name() -> String:
	if is_guest:
		return name + " (Guest)"
	return name


## Get formatted handicap string
func get_handicap_string() -> String:
	if handicap == 0.0:
		return "Scratch"
	elif handicap < 0:
		return "Unset"
	elif handicap > 0:
		return "+%.1f" % handicap
	else:
		return "%.1f" % handicap
		
## Get player nick for avatar
func get_nick_string() -> String:
	var parts = name.strip_edges().split(" ", false)
	if parts.size() >= 2:
		return (parts[0][0] + parts[1][0]).to_upper()
	else:
		var w = parts[0]
		return (w.substr(0, 2)).to_upper()
