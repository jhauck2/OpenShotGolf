class_name PracticeDrillHud
extends PanelContainer

const ShotAnalyticsEngineScript = preload("res://Utils/shot_analytics_engine.gd")

signal closed()
signal milestone_advanced(new_step: int)

const DRILL_OPTIONS: Array = [
	{"id": "active_focus", "label": "Active Focus Goal"},
	{"id": "start_line_gate", "label": "Start-Line Gate (±2° HLA)"},
	{"id": "curve_control", "label": "Stock Curve Control (±2.5° FTP)"},
	{"id": "center_compression", "label": "Center-Strike Compression"},
	{"id": "differential_feel", "label": "Differential Feel (3 Draw / 3 Fade / 4 Str)"},
	{"id": "wedge_ladder", "label": "Wedge Target Ladder (60 yds)"}
]

var _player_name: String = ""
var _drill_id: String = "start_line_gate"
var _rep_results: Array = []
var _streak: int = 0

var _drill_selector: OptionButton = null
var _target_lbl: Label = null
var _dots_hbox: HBoxContainer = null
var _dot_panels: Array[Panel] = []
var _stats_lbl: Label = null
var _feedback_lbl: Label = null
var _advance_btn: Button = null


func _ready() -> void:
	name = "PracticeDrillHud"
	visible = false
	custom_minimum_size = Vector2(340, 210)
	_build_ui()


func _build_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.92)
	panel_style.border_color = Color(0.24, 0.78, 0.56, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "🎯 Range Practice Drill"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72))
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 26)
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	header.add_child(close_btn)

	# Drill selector
	_drill_selector = OptionButton.new()
	_drill_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(DRILL_OPTIONS.size()):
		var opt: Dictionary = DRILL_OPTIONS[i]
		_drill_selector.add_item(str(opt["label"]), i)
		_drill_selector.set_item_metadata(i, str(opt["id"]))
	_drill_selector.select(1)
	_drill_selector.item_selected.connect(func(idx: int):
		var meta: String = str(_drill_selector.get_item_metadata(idx))
		select_drill(meta)
	)
	vbox.add_child(_drill_selector)

	_target_lbl = Label.new()
	_target_lbl.text = "Target: ±2.0° Start Line"
	_target_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_lbl.add_theme_font_size_override("font_size", 12)
	_target_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.96))
	vbox.add_child(_target_lbl)

	# 10-Ball Rep Indicator Strip
	_dots_hbox = HBoxContainer.new()
	_dots_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_dots_hbox)
	_dot_panels.clear()
	for i in range(10):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 14)
		dot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dots_hbox.add_child(dot)
		_dot_panels.append(dot)

	_stats_lbl = Label.new()
	_stats_lbl.text = "Reps: 0/10 · Streak: 0 · Pass: 0%"
	_stats_lbl.add_theme_font_size_override("font_size", 12)
	_stats_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45))
	vbox.add_child(_stats_lbl)

	_feedback_lbl = Label.new()
	_feedback_lbl.text = "Hit a ball to evaluate your first rep."
	_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_lbl.add_theme_font_size_override("font_size", 12)
	_feedback_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
	vbox.add_child(_feedback_lbl)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vbox.add_child(footer)

	var reset_btn := Button.new()
	reset_btn.text = "Reset 10-Ball Block"
	reset_btn.pressed.connect(reset_block)
	footer.add_child(reset_btn)

	_advance_btn = Button.new()
	_advance_btn.text = "Advance Milestone"
	_advance_btn.visible = false
	_advance_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advance_btn.pressed.connect(_on_advance_milestone_pressed)
	footer.add_child(_advance_btn)

	_refresh_ui()


func set_player(player_name: String) -> void:
	_player_name = player_name.strip_edges()
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and mp.has_method("get_player_coaching_goal") and not _player_name.is_empty():
		var goal: Dictionary = mp.call("get_player_coaching_goal", _player_name)
		if not goal.is_empty() and _drill_selector != null:
			_drill_id = "active_focus"
			_drill_selector.select(0)
	_refresh_ui()


func select_drill(drill_id: String) -> void:
	_drill_id = drill_id
	if _drill_selector != null:
		for i in range(_drill_selector.item_count):
			if str(_drill_selector.get_item_metadata(i)) == drill_id:
				_drill_selector.select(i)
				break
	reset_block()


func reset_block() -> void:
	_rep_results.clear()
	_streak = 0
	if _feedback_lbl != null:
		_feedback_lbl.text = "Ready for 10-ball block (%s)." % _drill_id.replace("_", " ").capitalize()
	if _advance_btn != null:
		_advance_btn.visible = false
	_refresh_ui()


func evaluate_shot(shot_data: Dictionary) -> Dictionary:
	if shot_data.is_empty():
		return {}
	if _rep_results.size() >= 10:
		_rep_results.clear()

	var p_name: String = str(shot_data.get("player", shot_data.get("Player", _player_name)))
	var club_name: String = str(shot_data.get("Club", shot_data.get("club", "Driver")))
	var skill_level: String = "mid_handicap"
	var is_lefty: bool = bool(shot_data.get("is_lefty", false))
	var target_cfg: Dictionary = {"rep_index": _rep_results.size()}

	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null:
		if mp.has_method("get_player_skill_level") and not p_name.is_empty():
			skill_level = str(mp.call("get_player_skill_level", p_name))
		if mp.has_method("get_player_handedness") and not p_name.is_empty() and not shot_data.has("is_lefty"):
			is_lefty = int(mp.call("get_player_handedness", p_name)) == 1
		if _drill_id == "active_focus" and mp.has_method("get_player_coaching_goal") and not p_name.is_empty():
			var goal: Dictionary = mp.call("get_player_coaching_goal", p_name)
			if not goal.is_empty():
				var ms: Array = goal.get("milestones", []) if goal.get("milestones", null) is Array else []
				var step_idx: int = clampi(int(goal.get("active_milestone", 1)) - 1, 0, maxi(0, ms.size() - 1))
				target_cfg["metric_key"] = str(goal.get("metric_key", "absOffline"))
				target_cfg["direction"] = str(goal.get("direction", "lower"))
				target_cfg["unit"] = str(goal.get("unit", ""))
				target_cfg["target_val"] = float(goal.get("target_value", 12.0))
				if step_idx < ms.size() and ms[step_idx] is Dictionary:
					target_cfg["target_val"] = float((ms[step_idx] as Dictionary).get("target_val", target_cfg["target_val"]))

	var eval_res: Dictionary = ShotAnalyticsEngineScript.evaluate_drill_shot(_drill_id, shot_data, club_name, skill_level, is_lefty, target_cfg)
	var passed: bool = bool(eval_res.get("passed", false))
	_rep_results.append(passed)
	if passed:
		_streak += 1
	else:
		_streak = 0

	if _feedback_lbl != null:
		var prefix: String = "✅ PASS" if passed else "❌ MISS"
		_feedback_lbl.text = "%s (%s vs %s) — %s" % [prefix, str(eval_res.get("measured_text", "---")), str(eval_res.get("target_text", "---")), str(eval_res.get("feedback", ""))]
		_feedback_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.68) if passed else Color(1.0, 0.60, 0.55))

	if _target_lbl != null:
		_target_lbl.text = "Target: %s" % str(eval_res.get("target_text", "---"))

	_refresh_ui()
	return eval_res


func _refresh_ui() -> void:
	if _dot_panels.is_empty():
		return
	var pass_cnt: int = 0
	for i in range(10):
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		if i < _rep_results.size():
			var ok: bool = bool(_rep_results[i])
			if ok:
				pass_cnt += 1
				style.bg_color = Color(0.18, 0.82, 0.48, 0.95)
			else:
				style.bg_color = Color(0.90, 0.28, 0.28, 0.92)
		else:
			style.bg_color = Color(0.20, 0.25, 0.34, 0.75)
		_dot_panels[i].add_theme_stylebox_override("panel", style)

	var pct: int = int(round((float(pass_cnt) / float(maxi(1, _rep_results.size()))) * 100.0)) if not _rep_results.is_empty() else 0
	if _stats_lbl != null:
		_stats_lbl.text = "Reps: %d/10 · Streak: %d · Pass: %d%%" % [_rep_results.size(), _streak, pct]
	if _advance_btn != null:
		_advance_btn.visible = (_drill_id == "active_focus" and _rep_results.size() >= 10 and pass_cnt >= 7)


func _on_advance_milestone_pressed() -> void:
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and not _player_name.is_empty() and mp.has_method("get_player_coaching_goal"):
		var goal: Dictionary = mp.call("get_player_coaching_goal", _player_name)
		if not goal.is_empty():
			var ms: Array = goal.get("milestones", []) if goal.get("milestones", null) is Array else []
			var next_step: int = mini(maxi(1, ms.size()), int(goal.get("active_milestone", 1)) + 1)
			goal["active_milestone"] = next_step
			mp.call("set_player_coaching_goal", _player_name, goal)
			milestone_advanced.emit(next_step)
	reset_block()
