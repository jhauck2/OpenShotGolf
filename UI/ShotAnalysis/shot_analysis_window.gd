extends Control

const FirestoreClient = preload("res://Utils/Cloud/firestore_client.gd")
const ShotAnalyticsEngineScript = preload("res://Utils/shot_analytics_engine.gd")
const AnalyticsVisualWidgetsScript = preload("res://UI/ShotAnalysis/analytics_visual_widgets.gd")

const GROUP_COLORS: Array[Color] = [
	Color(0.1, 0.85, 1.0),
	Color(1.0, 0.72, 0.12),
	Color(1.0, 0.3, 0.36),
	Color(0.4, 0.9, 0.42),
	Color(0.78, 0.45, 1.0),
	Color(1.0, 0.52, 0.2),
	Color(0.35, 0.95, 0.72),
	Color(0.95, 0.55, 0.72)
]

const STAT_CATEGORIES: Array[String] = [
	"Distance & Height",
	"Ball Speed",
	"Ball Flight",
	"Club & Face",
	"Spin",
	"Other"
]

var _records: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _next_record_id: int = 0
var _next_group_id: int = 0
var _active_group_id: int = -1
var _pending_custom_group_id: int = -1
var _spreadsheet: VBoxContainer
var _chart: Control
var _mode_selector: OptionButton
var _new_group_button: Button
var _upload_button: Button
var _upload_status: Label
var _averages: Dictionary = {}
var _stddevs: Dictionary = {}
var _coaching_container: VBoxContainer
var _group_counts: Dictionary = {}
var _group_selectors: Array[OptionButton] = []
var _data_keys: Array[String] = []


func _ready() -> void:
	_build_interface()
	var global_settings := get_node_or_null("/root/GlobalSettings")
	if global_settings != null:
		var range_settings: Variant = global_settings.get("range_settings")
		if range_settings != null:
			var range_units: Variant = range_settings.get("range_units")
			if range_units != null and range_units.has_signal("setting_changed"):
				range_units.setting_changed.connect(_on_range_units_changed)


func _on_range_units_changed(_value: Variant) -> void:
	_render_spreadsheet()
	_update_chart()


func initialize(shots: Array) -> void:
	for shot in shots:
		if shot is Dictionary:
			_add_record(shot, false)
	_refresh_data_keys()
	_render_spreadsheet()
	_update_chart()


func add_shot(shot: Dictionary) -> void:
	_add_record(shot, true)
	_refresh_data_keys()
	_render_spreadsheet()
	_update_chart()


func _add_record(shot: Dictionary, refresh: bool) -> void:
	var player := str(shot.get("player_name", shot.get("player", "Player")))
	var club := str(shot.get("club", "Club"))
	var group_id := -1
	if _pending_custom_group_id >= 0:
		group_id = _pending_custom_group_id
		_pending_custom_group_id = -1
		if _new_group_button != null and is_instance_valid(_new_group_button):
			_new_group_button.disabled = false
		_set_group_player_and_club(group_id, player, club)
	elif _active_group_id >= 0 and _group_matches(_active_group_id, player, club):
		group_id = _active_group_id
	else:
		for group_index in range(_groups.size() - 1, -1, -1):
			var group: Dictionary = _groups[group_index]
			if str(group.get("player", "")) == player and str(group.get("club", "")) == club:
				group_id = int(group["id"])
				break
	if group_id < 0:
		group_id = _create_group("%s - %s" % [player, club], player, club)
	_active_group_id = group_id
	_records.append({
		"id": _next_record_id,
		"group_id": group_id,
		"shot": shot.duplicate(true),
		"included": true
	})
	_next_record_id += 1
	if refresh and is_node_ready():
		_refresh_data_keys()
		_render_spreadsheet()
		_update_chart()


func _group_matches(group_id: int, player: String, club: String) -> bool:
	for group in _groups:
		if int(group["id"]) == group_id:
			return str(group.get("player", "")) == player and str(group.get("club", "")) == club
	return false


func _set_group_player_and_club(group_id: int, player: String, club: String) -> void:
	for group in _groups:
		if int(group["id"]) == group_id:
			group["player"] = player
			group["club"] = club
			return


func _create_group(label: String, player: String, club: String) -> int:
	var group_id := _next_group_id
	_next_group_id += 1
	_groups.append({
		"id": group_id,
		"label": label,
		"player": player,
		"club": club
	})
	return group_id


func _build_interface() -> void:
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 16)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_right", 16)
	margins.add_theme_constant_override("margin_bottom", 14)
	add_child(margins)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margins.add_child(root)

	var title := Label.new()
	title.text = "SHOT DATA ANALYSIS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var data_tab := VBoxContainer.new()
	data_tab.name = "Shots"
	data_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	data_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(data_tab)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	data_tab.add_child(toolbar)
	_new_group_button = Button.new()
	_new_group_button.text = "＋ New Group"
	_new_group_button.pressed.connect(_on_add_group_pressed)
	toolbar.add_child(_new_group_button)
	var help := Label.new()
	help.text = "Edit group names, move shots between groups, or uncheck shots to exclude them from averages."
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	toolbar.add_child(help)
	_upload_status = Label.new()
	_upload_status.custom_minimum_size.x = 170
	_upload_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upload_status.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	toolbar.add_child(_upload_status)
	_upload_button = Button.new()
	_upload_button.text = "Upload to Portal"
	_upload_button.tooltip_text = "Upload a copy of this analysis session to your signed-in player portal"
	_upload_button.pressed.connect(_upload_analysis_to_portal)
	toolbar.add_child(_upload_button)

	var horizontal_scroll := ScrollContainer.new()
	horizontal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	horizontal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	data_tab.add_child(horizontal_scroll)

	var vertical_scroll := ScrollContainer.new()
	vertical_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertical_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	horizontal_scroll.add_child(vertical_scroll)

	_spreadsheet = VBoxContainer.new()
	_spreadsheet.add_theme_constant_override("separation", 6)
	_spreadsheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertical_scroll.add_child(_spreadsheet)

	var chart_tab := VBoxContainer.new()
	chart_tab.name = "Flight & Dispersion"
	chart_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(chart_tab)
	var chart_toolbar := HBoxContainer.new()
	chart_tab.add_child(chart_toolbar)
	var chart_title := Label.new()
	chart_title.text = "Shot Flight & Landing Dispersion"
	chart_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_title.add_theme_font_size_override("font_size", 16)
	chart_toolbar.add_child(chart_title)
	_mode_selector = OptionButton.new()
	_mode_selector.add_item("Best shot")
	_mode_selector.add_item("Group average")
	_mode_selector.add_item("Best overall (distance + accuracy)")
	_mode_selector.item_selected.connect(func(_index: int):
		_update_chart()
	)
	chart_toolbar.add_child(_mode_selector)

	var chart_script = load("res://UI/ShotAnalysis/shot_analysis_charts.gd")
	_chart = Control.new()
	_chart.name = "ShotCharts"
	_chart.set_script(chart_script)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_tab.add_child(_chart)

	var coaching_tab := VBoxContainer.new()
	coaching_tab.name = "Coaching & D-Plane"
	coaching_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coaching_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(coaching_tab)

	var coach_scroll := ScrollContainer.new()
	coach_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coaching_tab.add_child(coach_scroll)

	_coaching_container = VBoxContainer.new()
	_coaching_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coaching_container.add_theme_constant_override("separation", 10)
	coach_scroll.add_child(_coaching_container)
	_update_coaching_tab()


func _upload_analysis_to_portal() -> void:
	var cloud_auth := get_node_or_null("/root/CloudAuth")
	if cloud_auth == null or not cloud_auth.has_method("is_signed_in") or not bool(cloud_auth.call("is_signed_in")):
		_set_upload_status("Sign in to your Heckle account to upload shot data.", true)
		return
	var uid := str(cloud_auth.call("get_uid"))
	if uid.is_empty():
		_set_upload_status("Could not identify the signed-in account.", true)
		return
	if _records.is_empty():
		_set_upload_status("There are no shots to upload yet.", true)
		return
	if _upload_button.disabled:
		return

	var timestamp := int(Time.get_unix_time_from_system())
	var session_id := "%d_%d" % [timestamp, randi()]
	var payload := {
		"schema_version": 1,
		"created_at": timestamp,
		"session_id": session_id,
		"display_units": "imperial" if _is_imperial_units() else "metric",
		"groups": _prepare_upload_value(_groups),
		"records": _prepare_upload_value(_records)
	}
	var firestore_client: Variant = cloud_auth.get("firestore")
	if firestore_client == null or not firestore_client.has_method("set_doc"):
		_set_upload_status("Cloud storage is unavailable. Please try again later.", true)
		return
	var serialized_fields := JSON.stringify({"fields": FirestoreClient.dict_to_firestore_fields(payload)})
	if serialized_fields.to_utf8_buffer().size() > 800000:
		_set_upload_status("This session is too large to upload as one analysis. Try a shorter session.", true)
		return

	_upload_button.disabled = true
	_upload_button.text = "Uploading..."
	_set_upload_status("", false)
	var result: Dictionary = await firestore_client.call(
		"set_doc",
		"profiles/%s/shot_analysis/%s" % [uid, session_id],
		payload,
		PackedStringArray(),
		"",
		false
	)
	if _upload_button == null or not is_instance_valid(_upload_button):
		return
	if result.get("ok", false):
		_set_upload_status("Uploaded. Find this session in your Player Portal.", false)
	else:
		_set_upload_status("Upload failed: %s" % str(result.get("error", "Unknown cloud error")), true)
	_upload_button.disabled = false
	_upload_button.text = "Upload to Portal"


func _prepare_upload_value(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var prepared: Dictionary = {}
		for key in value:
			prepared[str(key)] = _prepare_upload_value(value[key])
		return prepared
	if value is Array:
		var prepared_array: Array = []
		for item in value:
			prepared_array.append(_prepare_upload_value(item))
		return prepared_array
	if typeof(value) in [TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY]:
		var prepared_packed_array: Array = []
		for item in value:
			prepared_packed_array.append(_prepare_upload_value(item))
		return prepared_packed_array
	return value


func _set_upload_status(message: String, is_error: bool) -> void:
	if _upload_status == null or not is_instance_valid(_upload_status):
		return
	_upload_status.text = message
	_upload_status.add_theme_color_override(
		"font_color",
		Color(1.0, 0.55, 0.55) if is_error else Color(0.6, 0.85, 0.72)
	)


func _on_add_group_pressed() -> void:
	if _pending_custom_group_id >= 0:
		return
	var label := "Custom Group %d" % (_groups.size() + 1)
	_pending_custom_group_id = _create_group(label, "", "")
	_active_group_id = _pending_custom_group_id
	if _new_group_button != null and is_instance_valid(_new_group_button):
		_new_group_button.disabled = true
	_render_spreadsheet()
	_update_chart()


func _refresh_data_keys() -> void:
	var keys := {}
	var excluded_keys := [
		"aimdistance", "aimdistanceyards", "club", "player", "playername",
		"recordedinaverages", "shotreduction", "shotreductionm", "shottype",
		"targetdistance", "tracerpoints"
	]
	for record in _records:
		var shot: Dictionary = record["shot"]
		for key in shot.keys():
			var key_name := str(key)
			var normalized_key := key_name.to_lower().replace("_", "").replace(" ", "").replace("-", "")
			if excluded_keys.has(normalized_key):
				continue
			var display_key := _canonical_stat_key(key_name)
			keys[display_key] = true
	_data_keys.clear()
	for key in keys.keys():
		_data_keys.append(str(key))
	_data_keys.sort_custom(func(a: String, b: String) -> bool:
		var category_a := STAT_CATEGORIES.find(_stat_category(a))
		var category_b := STAT_CATEGORIES.find(_stat_category(b))
		if category_a == category_b:
			if _stat_category(a) == "Ball Flight":
				var is_descent_a := _is_descent_angle_key(a)
				var is_descent_b := _is_descent_angle_key(b)
				if is_descent_a != is_descent_b:
					return is_descent_a
			return _column_label(a) < _column_label(b)
		return category_a < category_b
	)


func _render_spreadsheet() -> void:
	_group_selectors.clear()
	for child in _spreadsheet.get_children():
		_spreadsheet.remove_child(child)
		child.queue_free()
	_averages.clear()
	_stddevs.clear()
	_group_counts.clear()
	if _data_keys.is_empty():
		if _groups.is_empty():
			var empty := Label.new()
			empty.text = "Take a shot on the range to start collecting launch monitor data."
			empty.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
			_spreadsheet.add_child(empty)
			return
	else:
		_spreadsheet.add_child(_make_column_header())
	for group in _groups:
		_render_group(group)


func _make_column_header() -> VBoxContainer:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 4)
	_add_cell(category_row, "", 54, true)
	_add_cell(category_row, "", 150, true)
	var last_category := ""
	var category_count := 0
	for key in _data_keys:
		var category := _stat_category(key)
		if category != last_category and category_count > 0:
			_add_cell(category_row, last_category, category_count * 112.0 + (category_count - 1) * 4.0, true)
			category_count = 0
		last_category = category
		category_count += 1
	if category_count > 0:
		_add_cell(category_row, last_category, category_count * 112.0 + (category_count - 1) * 4.0, true)
	header.add_child(category_row)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_add_cell(row, "USE", 54, true)
	_add_cell(row, "GROUP", 150, true)
	for key in _data_keys:
		_add_cell(row, _column_label(key), 112, true)
	header.add_child(row)
	return header


func _render_group(group: Dictionary) -> void:
	var group_id := int(group["id"])
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.1, 0.13, 0.18, 0.94), _group_color(group_id)))
	_spreadsheet.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	panel.add_child(body)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	body.add_child(heading)
	var label_edit := LineEdit.new()
	label_edit.text = str(group.get("label", "Group"))
	label_edit.placeholder_text = "Group label"
	label_edit.custom_minimum_size.x = 280
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_edit.text_submitted.connect(func(value: String):
		_rename_group(group_id, value)
	)
	label_edit.focus_exited.connect(func():
		_rename_group(group_id, label_edit.text)
	)
	heading.add_child(label_edit)
	var count_label := Label.new()
	count_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	heading.add_child(count_label)
	_group_counts[group_id] = count_label
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.tooltip_text = "Delete this group and its shots from Shot Data Analysis only"
	delete_button.pressed.connect(_confirm_delete_group.bind(group_id))
	heading.add_child(delete_button)

	for record_index in range(_records.size()):
		var record: Dictionary = _records[record_index]
		if int(record["group_id"]) == group_id:
			body.add_child(_make_shot_row(record_index, group_id))

	var average_row := HBoxContainer.new()
	average_row.add_theme_constant_override("separation", 4)
	var average_title := Label.new()
	average_title.text = "AVERAGE"
	average_title.custom_minimum_size.x = 54
	average_title.add_theme_color_override("font_color", Color(0.6, 0.85, 0.72))
	body.add_child(average_row)
	average_row.add_child(average_title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 150
	average_row.add_child(spacer)
	for key in _data_keys:
		var cell := Label.new()
		cell.custom_minimum_size.x = 112
		cell.clip_text = true
		cell.add_theme_color_override("font_color", Color(0.66, 0.9, 0.75))
		average_row.add_child(cell)
	_averages[group_id] = average_row

	var stddev_row := HBoxContainer.new()
	stddev_row.add_theme_constant_override("separation", 4)
	var stddev_title := Label.new()
	stddev_title.text = "STD DEV"
	stddev_title.custom_minimum_size.x = 54
	stddev_title.add_theme_color_override("font_color", Color(0.55, 0.75, 0.92))
	body.add_child(stddev_row)
	stddev_row.add_child(stddev_title)
	var sd_spacer := Control.new()
	sd_spacer.custom_minimum_size.x = 150
	stddev_row.add_child(sd_spacer)
	for key in _data_keys:
		var sd_cell := Label.new()
		sd_cell.custom_minimum_size.x = 112
		sd_cell.clip_text = true
		sd_cell.add_theme_color_override("font_color", Color(0.64, 0.80, 0.96))
		stddev_row.add_child(sd_cell)
	_stddevs[group_id] = stddev_row

	_update_group_summary(group_id)


func _confirm_delete_group(group_id: int) -> void:
	var group_label := "this group"
	for group in _groups:
		if int(group["id"]) == group_id:
			group_label = str(group.get("label", group_label))
			break
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Shot Group"
	dialog.dialog_text = "Delete \"%s\" and its shots from Shot Data Analysis? Shots on the range will not be deleted." % group_label
	dialog.ok_button_text = "Delete Group"
	dialog.confirmed.connect(_delete_group.bind(group_id))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


func _delete_group(group_id: int) -> void:
	for index in range(_groups.size() - 1, -1, -1):
		if int(_groups[index]["id"]) == group_id:
			_groups.remove_at(index)
			break
	for index in range(_records.size() - 1, -1, -1):
		if int(_records[index]["group_id"]) == group_id:
			_records.remove_at(index)
	if _active_group_id == group_id:
		_active_group_id = -1
	if _pending_custom_group_id == group_id:
		_pending_custom_group_id = -1
		if _new_group_button != null and is_instance_valid(_new_group_button):
			_new_group_button.disabled = false
	_refresh_data_keys()
	_render_spreadsheet()
	_update_chart()


func _make_shot_row(record_index: int, group_id: int) -> HBoxContainer:
	var record: Dictionary = _records[record_index]
	var shot: Dictionary = record["shot"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var included := CheckBox.new()
	included.button_pressed = bool(record["included"])
	included.custom_minimum_size.x = 54
	included.tooltip_text = "Include this shot in group averages and best-shot analysis"
	var record_id := int(record["id"])
	included.toggled.connect(func(enabled: bool):
		_set_record_included(record_id, enabled)
	)
	row.add_child(included)

	var group_selector := OptionButton.new()
	group_selector.custom_minimum_size.x = 150
	group_selector.tooltip_text = "Move this shot to another group"
	for group in _groups:
		group_selector.add_item(str(group["label"]), int(group["id"]))
		if int(group["id"]) == group_id:
			group_selector.select(group_selector.item_count - 1)
	_group_selectors.append(group_selector)
	group_selector.item_selected.connect(func(index: int):
		var selected_group_id := group_selector.get_item_id(index)
		_move_record(record_id, selected_group_id)
	)
	row.add_child(group_selector)

	for key in _data_keys:
		var cell := Label.new()
		cell.text = _format_value(_display_stat_value(key, _get_stat_value(shot, key)))
		cell.custom_minimum_size.x = 112
		cell.clip_text = true
		cell.tooltip_text = "%s: %s" % [_column_label(key), _format_value(_display_stat_value(key, _get_stat_value(shot, key)))]
		cell.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
		row.add_child(cell)
	return row


func _add_cell(row: HBoxContainer, text: String, width: float, is_header: bool) -> void:
	var cell := Label.new()
	cell.text = text
	cell.custom_minimum_size.x = width
	cell.clip_text = true
	cell.add_theme_color_override("font_color", Color(0.72, 0.82, 0.96) if is_header else Color.WHITE)
	cell.add_theme_font_size_override("font_size", 11)
	row.add_child(cell)


func _rename_group(group_id: int, label: String) -> void:
	var clean_label := label.strip_edges()
	if clean_label.is_empty():
		return
	for group in _groups:
		if int(group["id"]) == group_id:
			group["label"] = clean_label
			break
	for selector in _group_selectors:
		if not is_instance_valid(selector):
			continue
		for index in range(selector.item_count):
			if selector.get_item_id(index) == group_id:
				selector.set_item_text(index, clean_label)
	_update_chart()


func _move_record(record_id: int, group_id: int) -> void:
	for record in _records:
		if int(record["id"]) == record_id:
			record["group_id"] = group_id
			break
	call_deferred("_render_spreadsheet")
	_update_chart()


func _set_record_included(record_id: int, included: bool) -> void:
	for record in _records:
		if int(record["id"]) == record_id:
			record["included"] = included
			_update_group_summary(int(record["group_id"]))
			break
	_update_chart()


func _update_group_summary(group_id: int) -> void:
	var total := 0
	var included_count := 0
	var sums := {}
	var counts := {}
	var vals := {}
	for key in _data_keys:
		sums[key] = 0.0
		counts[key] = 0
		vals[key] = []
	for record in _records:
		if int(record["group_id"]) != group_id:
			continue
		total += 1
		if not bool(record["included"]):
			continue
		included_count += 1
		var shot: Dictionary = record["shot"]
		for key in _data_keys:
			var value: Variant = _get_stat_value(shot, key)
			if value == null:
				continue
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				var dv: float = float(_display_stat_value(key, value))
				sums[key] += dv
				counts[key] += 1
				(vals[key] as Array).append(dv)
	var count_label: Label = _group_counts.get(group_id)
	if count_label != null:
		count_label.text = "%d of %d included" % [included_count, total]
	var average_row: HBoxContainer = _averages.get(group_id)
	var stddev_row: HBoxContainer = _stddevs.get(group_id)
	if average_row == null:
		return
	for index in range(_data_keys.size()):
		var cell := average_row.get_child(index + 2) as Label
		var key := _data_keys[index]
		var mean: float = (sums[key] / counts[key]) if counts[key] > 0 else 0.0
		cell.text = _format_value(mean) if counts[key] > 0 else "—"
		cell.tooltip_text = "Average %s from %d included shots" % [_column_label(key), counts[key]]
		if stddev_row != null and index + 2 < stddev_row.get_child_count():
			var sd_cell := stddev_row.get_child(index + 2) as Label
			if counts[key] >= 2:
				var sq: float = 0.0
				for v in vals[key]:
					sq += pow(float(v) - mean, 2.0)
				var sd: float = sqrt(sq / float(counts[key]))
				sd_cell.text = "±%s" % _format_value(sd)
				sd_cell.tooltip_text = "Std Dev (σ) of %s across %d shots" % [_column_label(key), counts[key]]
			else:
				sd_cell.text = "—"


func _update_chart() -> void:
	if _chart != null and _chart.has_method("set_analysis_data"):
		var mode_idx: int = _mode_selector.selected if _mode_selector != null else 0
		_chart.call("set_analysis_data", _records, _groups, mode_idx == 0, mode_idx)
	_update_coaching_tab()


func _update_coaching_tab() -> void:
	if _coaching_container == null:
		return
	for child in _coaching_container.get_children():
		_coaching_container.remove_child(child)
		child.queue_free()

	var included_shots: Array = []
	for record in _records:
		if not bool(record.get("included", true)):
			continue
		if _active_group_id >= 0 and int(record.get("group_id", -1)) != _active_group_id:
			continue
		var s: Dictionary = record.get("shot", {})
		if not s.is_empty():
			included_shots.append(s)
	if included_shots.is_empty():
		for record in _records:
			if bool(record.get("included", true)):
				var s2: Dictionary = record.get("shot", {})
				if not s2.is_empty():
					included_shots.append(s2)

	if included_shots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Take shots on the range (or include shots in a group) to view D-Plane flight shape matrix, Launch Optimizer, and Distance Loss diagnostics."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
		_coaching_container.add_child(empty_lbl)
		return

	var first_shot: Dictionary = included_shots[-1]
	var club_name: String = str(first_shot.get("Club", first_shot.get("club", "Driver")))
	var player_name: String = str(first_shot.get("Player", first_shot.get("player", "")))
	var skill_level: String = "mid_handicap"
	var is_lefty: bool = bool(first_shot.get("is_lefty", false))
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null:
		if mp_mgr.has_method("get_player_skill_level"):
			skill_level = str(mp_mgr.get_player_skill_level(player_name))
		if mp_mgr.has_method("get_player_handedness") and not first_shot.has("is_lefty"):
			is_lefty = int(mp_mgr.get_player_handedness(player_name)) == 1

	var analysis: Dictionary = ShotAnalyticsEngineScript.analyze_shot_group(included_shots, club_name, skill_level, is_lefty)
	if not bool(analysis.get("has_data", false)):
		return

	var focus: Dictionary = analysis.get("active_focus", {})
	var recent: Dictionary = analysis.get("recent", {})
	var loss: Dictionary = analysis.get("distance_loss", {})
	var aim: Dictionary = recent.get("aim_shift", {})
	var bf: Dictionary = recent.get("ball_flight", {})
	var attr: Dictionary = recent.get("miss_attribution", {})

	# 1. Active "One-Thing Focus" Hero Banner
	var hero := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.08, 0.13, 0.20, 0.96)
	h_style.border_width_left = 4
	h_style.border_color = Color(0.24, 0.85, 0.56, 0.95)
	h_style.content_margin_left = 14
	h_style.content_margin_right = 14
	h_style.content_margin_top = 10
	h_style.content_margin_bottom = 10
	hero.add_theme_stylebox_override("panel", h_style)
	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 4)
	var f_title := Label.new()
	f_title.text = "🎯 Active Focus: %s (Est. -%.1f strokes/rd)" % [str(focus.get("title", "Ball Flight Stability")), float(focus.get("estimated_strokes_saved", 0.5))]
	f_title.add_theme_font_size_override("font_size", 16)
	f_title.add_theme_color_override("font_color", Color(0.45, 0.96, 0.70))
	h_vbox.add_child(f_title)
	var f_why := Label.new()
	f_why.text = str(focus.get("why", ""))
	f_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f_why.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
	h_vbox.add_child(f_why)
	hero.add_child(h_vbox)
	_coaching_container.add_child(hero)

	# 2. Visual Charts Row: D-Plane Matrix + Launch Optimizer
	var charts_row := HBoxContainer.new()
	charts_row.add_theme_constant_override("separation", 12)
	charts_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d_plane: Control = AnalyticsVisualWidgetsScript.create_d_plane_matrix(
		bf.get("counts", {}),
		int(bf.get("total_classified", included_shots.size())),
		is_lefty,
		Vector2(280, 190)
	)
	charts_row.add_child(d_plane)
	var bench: Dictionary = GolfSwingAnalyzer.get_benchmark(club_name, GolfSwingAnalyzer.normalize_skill_level(skill_level))
	var launch_opt: Control = AnalyticsVisualWidgetsScript.create_launch_optimizer(analysis.get("normalized_shots", []), bench, Vector2(280, 190))
	charts_row.add_child(launch_opt)
	_coaching_container.add_child(charts_row)

	# 3. Distance Loss + Aim Shift + Miss Attribution Summary Cards
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var loss_lbl := Label.new()
	loss_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loss_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(loss.get("has_data", false)):
		loss_lbl.text = "📏 Potential Carry: %.1f yds (Leaking %.1f yds — Strike: %.1f · Launch/Spin: %.1f · Curve: %.1f)" % [
			float(loss.get("potential_carry_yds", 0.0)),
			float(loss.get("total_lost_yds", 0.0)),
			float(loss.get("smash_loss_yards", loss.get("smash_loss_yds", 0.0))),
			float(loss.get("launch_spin_loss_yds", 0.0)),
			float(loss.get("curve_loss_yds", 0.0))
		]
	else:
		loss_lbl.text = "📏 Distance Loss: Include club speed telemetry to unlock missing yards attribution."
	loss_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.58))
	cards_row.add_child(loss_lbl)

	var aim_lbl := Label.new()
	aim_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aim_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var shift_yds: float = float(aim.get("shift_yds", 0.0))
	var shift_dir: String = str(aim.get("shift_dir", ""))
	if not shift_dir.is_empty() and shift_yds >= 2.0:
		aim_lbl.text = "🧭 Aim Shift: Aim %.1f yds %s to raise corridor rate from %d%% to ~%d%%." % [shift_yds, shift_dir, int(recent.get("pct_in_corridor", 0)), int(aim.get("projected_pct_in_corridor", 0))]
	else:
		aim_lbl.text = "🧭 Aim & Miss Driver: %s (%d%% Stock Shape)" % [str(attr.get("miss_pattern", "Centered")), int(bf.get("pct_functional_stock", 0))]
	aim_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	cards_row.add_child(aim_lbl)

	_coaching_container.add_child(cards_row)


func _column_label(key: String) -> String:
	var labels := {
		"Speed": "Ball Speed",
		"BallSpeed": "Ball Speed",
		"ClubSpeed": "Club Speed",
		"CarryDistance": "Carry",
		"TotalDistance": "Distance",
		"SideDistance": "Offline",
		"TotalSpin": "Spin",
		"BackSpin": "Back Spin",
		"SideSpin": "Side Spin",
		"SpinAxis": "Spin Axis",
		"Apex": "Apex",
		"LaunchAngle": "Launch Angle",
		"VLA": "VLA",
		"HLA": "HLA",
		"DescentAngle": "Descent Angle",
		"HangTime": "Hang Time"
	}
	var label := str(labels.get(key, key.replace("_", " ").capitalize()))
	var unit := _stat_unit(key)
	return "%s (%s)" % [label, unit] if not unit.is_empty() else label


func _canonical_stat_key(key: String) -> String:
	var normalized_key := key.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	if normalized_key in ["speed", "ballspeed"]:
		return "BallSpeed"
	if _is_descent_angle_key(key):
		return "DescentAngle"
	return key


func _is_descent_angle_key(key: String) -> bool:
	var normalized_key := key.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	return normalized_key in ["descentangle", "landingangle"]


func _get_stat_value(shot: Dictionary, key: String) -> Variant:
	if key == "BallSpeed":
		for shot_key in shot.keys():
			if str(shot_key).to_lower().replace("_", "").replace(" ", "").replace("-", "") == "ballspeed" and shot[shot_key] != null:
				return shot[shot_key]
		for shot_key in shot.keys():
			if str(shot_key).to_lower().replace("_", "").replace(" ", "").replace("-", "") == "speed" and shot[shot_key] != null:
				return shot[shot_key]
		return null
	if key == "DescentAngle":
		for shot_key in shot.keys():
			if str(shot_key).to_lower().replace("_", "").replace(" ", "").replace("-", "") in ["descentangle", "landingangle"] and shot[shot_key] != null:
				return shot[shot_key]
		return null
	return shot.get(key)


func _display_stat_value(key: String, value: Variant) -> Variant:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return value
	var normalized_key := key.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	var numeric_value := float(value)
	if normalized_key in ["carrydistance", "totaldistance", "distance", "carry", "sidedistance", "offline", "rollout"]:
		return numeric_value * 1.09361 if _is_imperial_units() else numeric_value
	if normalized_key in ["apex", "height", "peakheight"]:
		return numeric_value * 3.28084 if _is_imperial_units() else numeric_value
	if normalized_key in ["ballspeed", "speed", "clubspeed"]:
		return numeric_value if _is_imperial_units() else numeric_value * 0.44704
	return value


func _stat_unit(key: String) -> String:
	var normalized_key := key.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	if normalized_key in ["carrydistance", "totaldistance", "distance", "carry", "sidedistance", "offline", "rollout"]:
		return "yd" if _is_imperial_units() else "m"
	if normalized_key in ["apex", "height", "peakheight"]:
		return "ft" if _is_imperial_units() else "m"
	if normalized_key in ["ballspeed", "speed", "clubspeed"]:
		return "mph" if _is_imperial_units() else "m/s"
	return ""


func _is_imperial_units() -> bool:
	var global_settings := get_node_or_null("/root/GlobalSettings")
	if global_settings == null:
		return true
	var range_settings: Variant = global_settings.get("range_settings")
	if range_settings == null:
		return true
	var range_units: Variant = range_settings.get("range_units")
	if range_units == null:
		return true
	return int(range_units.get("value")) == PhysicsEnums.Units.IMPERIAL


func _stat_category(key: String) -> String:
	var normalized_key := key.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	if normalized_key in ["carrydistance", "totaldistance", "distance", "carry", "apex", "height", "peakheight", "hangtime"]:
		return "Distance & Height"
	if normalized_key in ["speed", "ballspeed", "clubspeed", "smashfactor"]:
		return "Ball Speed"
	if normalized_key in ["launchangle", "vla", "hla", "sidedistance", "offline", "direction", "shotdirection", "descentangle", "landingangle"]:
		return "Ball Flight"
	if normalized_key in ["clubpath", "faceangle", "facetopath", "attackangle", "dynamicloft", "clubfaceangle", "facetotarget"]:
		return "Club & Face"
	if normalized_key in ["totalspin", "backspin", "sidespin", "spinaxis", "spinrate"]:
		return "Spin"
	return "Other"


func _format_value(value: Variant) -> String:
	if typeof(value) == TYPE_NIL:
		return "—"
	if typeof(value) == TYPE_FLOAT:
		return "%.2f" % float(value)
	if typeof(value) == TYPE_INT:
		return str(value)
	if value is Vector3:
		return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
	if value is Vector2:
		return "(%.2f, %.2f)" % [value.x, value.y]
	if value is Array:
		return str(value)
	if value is Dictionary:
		return str(value)
	return str(value)


func _group_color(group_id: int) -> Color:
	for index in range(_groups.size()):
		if int(_groups[index]["id"]) == group_id:
			return GROUP_COLORS[index % GROUP_COLORS.size()]
	return Color.WHITE


func _panel_style(background: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(accent.r, accent.g, accent.b, 0.75)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style
