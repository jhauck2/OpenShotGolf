extends PanelContainer

## UI panel displaying target information and scoring

var target_name_label: Label
var target_distance_label: Label
var last_shot_label: Label
var session_score_label: Label
var stats_label: Label

var current_session_score: int = 0
var total_shots: int = 0


func _ready() -> void:
	_create_ui()
	_update_display()


func _create_ui() -> void:
	# Create the UI structure programmatically
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Target name label
	target_name_label = Label.new()
	target_name_label.name = "TargetName"
	target_name_label.text = "[TARGET] 150 Yard Target"
	target_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(target_name_label)

	# Target distance label
	target_distance_label = Label.new()
	target_distance_label.name = "TargetDistance"
	target_distance_label.text = "Distance: 150 yards"
	target_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(target_distance_label)

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Last shot label
	last_shot_label = Label.new()
	last_shot_label.name = "LastShot"
	last_shot_label.text = "Last Shot: ---"
	vbox.add_child(last_shot_label)

	# Session score label
	session_score_label = Label.new()
	session_score_label.name = "SessionScore"
	session_score_label.text = "Score: 0 pts (0 shots)"
	vbox.add_child(session_score_label)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Stats label
	stats_label = Label.new()
	stats_label.name = "Stats"
	stats_label.text = "Session Stats:\n  No shots yet"
	vbox.add_child(stats_label)

	# Set panel size
	custom_minimum_size = Vector2(300, 250)


## Update the active target display
func set_target_info(target_name: String, distance: float, lateral_offset: float = 0.0) -> void:
	target_name_label.text = "[TARGET] " + target_name
	var offset_text = ""
	if abs(lateral_offset) > 0.1:
		offset_text = " (%.0f yds %s)" % [abs(lateral_offset), "R" if lateral_offset > 0 else "L"]
	target_distance_label.text = "Distance: %.0f yards%s" % [distance, offset_text]
	_update_display()


## Update last shot information
func set_last_shot(zone: String, distance: float, score: int) -> void:
	var zone_color = _get_zone_color_text(zone)

	last_shot_label.text = "Last Shot: %s\n  %.1f yds | +%d pts" % [zone, distance, score]
	last_shot_label.add_theme_color_override("font_color", zone_color)

	current_session_score += score
	total_shots += 1

	_update_display()


## Update session statistics
func set_session_stats(stats: Dictionary) -> void:
	var bullseyes = stats.get("bullseyes", 0)
	var yellow = stats.get("yellow_hits", 0)
	var red = stats.get("red_hits", 0)
	var white = stats.get("white_hits", 0)
	var misses = stats.get("misses", 0)
	var best = stats.get("best_shot_distance", INF)

	var stats_text = "Session Stats:\n"
	stats_text += "  Bullseyes: %d\n" % bullseyes
	stats_text += "  Yellow: %d\n" % yellow
	stats_text += "  Red: %d\n" % red
	stats_text += "  White: %d\n" % white
	stats_text += "  Misses: %d\n" % misses

	if best != INF:
		stats_text += "  Best: %.1f yds" % best

	stats_label.text = stats_text

	_update_display()


## Reset session score
func reset_session() -> void:
	current_session_score = 0
	total_shots = 0
	last_shot_label.text = "Last Shot: ---"
	stats_label.text = "Session Stats:\n  No shots yet"
	_update_display()


func _update_display() -> void:
	if total_shots > 0:
		var avg_score = float(current_session_score) / float(total_shots)
		session_score_label.text = "Score: %d pts (%d shots, %.1f avg)" % [current_session_score, total_shots, avg_score]
	else:
		session_score_label.text = "Score: 0 pts (0 shots)"


func _get_zone_color_text(zone: String) -> Color:
	match zone:
		"Bullseye":
			return Color(0.22, 1.0, 0.2)  # Bright green
		"Yellow":
			return Color(1.0, 1.0, 0.2)  # Yellow
		"Red":
			return Color(1.0, 0.3, 0.2)  # Red
		"White":
			return Color(0.9, 0.9, 0.9)  # White
		_:
			return Color(0.5, 0.5, 0.5)  # Gray
