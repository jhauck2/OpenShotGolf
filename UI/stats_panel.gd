extends PanelContainer

signal drag_started
signal drag_ended(panel)

var dragging := false
var drag_offset := Vector2.ZERO

# Stats to display
var total_shots := 0
var total_score := 0
var accuracy := 0.0
var bullseyes := 0
var yellow_hits := 0
var red_hits := 0
var white_hits := 0
var misses := 0
var best_shot := 0.0
var avg_distance := 0.0


func _ready() -> void:
	update_display()


func set_stats(stats: Dictionary) -> void:
	total_shots = stats.get("total_shots", 0)
	total_score = stats.get("total_score", 0)
	bullseyes = stats.get("bullseyes", 0)
	yellow_hits = stats.get("yellow_hits", 0)
	red_hits = stats.get("red_hits", 0)
	white_hits = stats.get("white_hits", 0)
	misses = stats.get("misses", 0)
	best_shot = stats.get("best_shot_distance", INF)
	avg_distance = stats.get("average_distance", 0.0)

	# Calculate accuracy
	if total_shots > 0:
		accuracy = float(bullseyes + yellow_hits + red_hits + white_hits) / total_shots * 100.0
	else:
		accuracy = 0.0

	update_display()


func update_display() -> void:
	if not has_node("MarginContainer/VBoxContainer/StatsLabel"):
		return

	var stats_label = $MarginContainer/VBoxContainer/StatsLabel

	if total_shots == 0:
		stats_label.text = "No shots yet"
	else:
		var best_text = "---"
		if best_shot != INF:
			best_text = "%.1f yds" % best_shot

		stats_label.text = "Shots: %d | Score: %d pts | Acc: %.0f%%\n\nBullseye: %d | Yellow: %d | Red: %d\nWhite: %d | Miss: %d\n\nBest: %s | Avg: %.1f yds" % [
			total_shots,
			total_score,
			accuracy,
			bullseyes,
			yellow_hits,
			red_hits,
			white_hits,
			misses,
			best_text,
			avg_distance
		]


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
