class_name LeaderboardsMenu
extends Control

## Global Leaderboards Menu for Heckle Golf Simulator.
## Displays public rankings across 7 categories without requiring authentication,
## highlights signed-in player's row and friends, shows personal best strip,
## handles 10-minute caching, budget paused state, and 100% controller navigation.

const LeaderboardService = preload("res://Utils/Cloud/leaderboard_service.gd")
const BudgetPausedBanner = preload("res://UI/Account/budget_paused_banner.gd")
const TouchScrollHelper = preload("res://Utils/touch_scroll_helper.gd")

@onready var _back_button: Button = $VBoxContainer/HeaderBar/MarginContainer/HBoxContainer/BackButton
@onready var _refresh_button: Button = $VBoxContainer/HeaderBar/MarginContainer/HBoxContainer/RightHBox/RefreshButton
@onready var _account_button: Button = $VBoxContainer/HeaderBar/MarginContainer/HBoxContainer/RightHBox/AccountButton
@onready var _status_label: Label = $VBoxContainer/HeaderBar/MarginContainer/HBoxContainer/RightHBox/StatusLabel
@onready var _budget_banner: BudgetPausedBanner = $VBoxContainer/BudgetPausedBanner
@onready var _offline_banner: PanelContainer = $VBoxContainer/OfflineBanner
@onready var _tabs_container: HBoxContainer = $VBoxContainer/TabsBar/ScrollContainer/TabsContainer
@onready var _scroll_container: ScrollContainer = $VBoxContainer/TableArea/ScrollContainer
@onready var _rows_container: VBoxContainer = $VBoxContainer/TableArea/ScrollContainer/RowsContainer
@onready var _empty_label: Label = $VBoxContainer/TableArea/EmptyLabel
@onready var _loading_indicator: Label = $VBoxContainer/TableArea/LoadingLabel
@onready var _pb_strip: PanelContainer = $VBoxContainer/BottomStripContainer/PersonalBestStrip
@onready var _pb_stat_label: Label = $VBoxContainer/BottomStripContainer/PersonalBestStrip/MarginContainer/HBoxContainer/StatValueLabel
@onready var _pb_sync_label: Label = $VBoxContainer/BottomStripContainer/PersonalBestStrip/MarginContainer/HBoxContainer/SyncStatusLabel
@onready var _pb_player_label: Label = $VBoxContainer/BottomStripContainer/PersonalBestStrip/MarginContainer/HBoxContainer/PlayerNameLabel

var leaderboard_service: LeaderboardService = null
var active_category_id: String = "longest_drive"
var _active_tab_index: int = 0
var _tab_buttons: Array[Button] = []
var _row_buttons: Array[Button] = []
var _last_refresh_ticks: int = -999999
var _current_entries: Array = []
var _last_updated_time: int = 0


func _ready() -> void:
	if leaderboard_service == null:
		leaderboard_service = LeaderboardService.new()

	_setup_header_styles()
	_setup_table_scroll()
	_connect_signals()

	_render_category_tabs()
	_load_current_category(false)
	_update_personal_best_strip()

	if has_node("/root/CloudSync"):
		var cs = get_node("/root/CloudSync")
		if cs.has_method("sync_all_eligible_profiles"):
			cs.sync_all_eligible_profiles("leaderboard_open")

	call_deferred("_grab_initial_focus")


func _setup_header_styles() -> void:
	if _back_button != null:
		ThemeManager.apply_nav_button_style(_back_button, 6)
	if _refresh_button != null:
		ThemeManager.apply_nav_button_style(_refresh_button, 6)
	if _account_button != null:
		ThemeManager.apply_primary_button_style(_account_button, 6)

	if _offline_banner != null:
		_offline_banner.visible = false
		var off_style := StyleBoxFlat.new()
		off_style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
		off_style.border_color = Color(0.35, 0.82, 1.0, 0.6)
		off_style.set_border_width_all(1)
		off_style.set_corner_radius_all(6)
		off_style.content_margin_left = 16.0
		off_style.content_margin_top = 8.0
		off_style.content_margin_right = 16.0
		off_style.content_margin_bottom = 8.0
		_offline_banner.add_theme_stylebox_override("panel", off_style)

	if _pb_strip != null:
		var pb_style := StyleBoxFlat.new()
		pb_style.bg_color = Color(0.06, 0.10, 0.16, 0.95)
		pb_style.border_color = Color(0.24, 0.44, 0.65, 0.5)
		pb_style.set_border_width_all(1)
		pb_style.set_corner_radius_all(8)
		pb_style.content_margin_left = 18.0
		pb_style.content_margin_top = 10.0
		pb_style.content_margin_right = 18.0
		pb_style.content_margin_bottom = 10.0
		_pb_strip.add_theme_stylebox_override("panel", pb_style)


func _setup_table_scroll() -> void:
	if _scroll_container != null:
		_scroll_container.follow_focus = true
		ThemeManager.apply_scroll_container_style(_scroll_container)
		TouchScrollHelper.attach_to(_scroll_container)


func _connect_signals() -> void:
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _refresh_button != null and not _refresh_button.pressed.is_connected(_on_refresh_pressed):
		_refresh_button.pressed.connect(_on_refresh_pressed)
	if _account_button != null and not _account_button.pressed.is_connected(_on_account_pressed):
		_account_button.pressed.connect(_on_account_pressed)

	var auth := _get_cloud_auth()
	if auth != null and auth.has_signal("auth_state_changed"):
		if not auth.auth_state_changed.is_connected(_on_auth_state_changed):
			auth.auth_state_changed.connect(_on_auth_state_changed)


func _on_auth_state_changed(_is_signed_in: bool, _user: Dictionary) -> void:
	_update_personal_best_strip()
	_render_leaderboard_rows(_current_entries, false)
	_update_controller_focus_navigation()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg.is_modal_active():
			return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").change_scene("res://UI/MainMenu/main_menu.tscn")
	elif get_tree() != null:
		get_tree().change_scene_to_file("res://UI/MainMenu/main_menu.tscn")


func _on_refresh_pressed() -> void:
	var now_ticks: int = Time.get_ticks_msec()
	# 30 second throttle
	if _last_refresh_ticks > 0 and (now_ticks - _last_refresh_ticks) < 30000:
		var remaining_sec: int = int(ceil((30000 - (now_ticks - _last_refresh_ticks)) / 1000.0))
		_set_status_text("Please wait %ds to refresh" % remaining_sec)
		return

	_last_refresh_ticks = now_ticks
	if has_node("/root/CloudSync"):
		var cs = get_node("/root/CloudSync")
		if cs.has_method("sync_all_eligible_profiles"):
			cs.sync_all_eligible_profiles("leaderboard_refresh")
	_load_current_category(true)


func _on_account_pressed() -> void:
	var modal_scene = load("res://UI/Account/account_modal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		modal.name = "AccountModal"
		if modal.has_signal("closed"):
			modal.closed.connect(func():
				_update_personal_best_strip()
				_render_leaderboard_rows(_current_entries, false)
				_update_controller_focus_navigation()
			)
		add_child(modal)


func _render_category_tabs() -> void:
	if _tabs_container == null:
		return

	for child in _tabs_container.get_children():
		_tabs_container.remove_child(child)
		child.queue_free()

	_tab_buttons.clear()
	var cats := LeaderboardService.get_categories()

	for i in range(cats.size()):
		var cat_def: Dictionary = cats[i]
		var cat_id: String = cat_def.get("id", "")
		var btn := Button.new()
		btn.name = "Tab_%s" % cat_id
		btn.text = cat_def.get("title", cat_id)
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(140, 42)

		var idx := i
		btn.pressed.connect(func():
			_select_category_index(idx)
		)

		_tabs_container.add_child(btn)
		_tab_buttons.append(btn)

	_update_tab_styles()
	_update_controller_focus_navigation()


func _select_category_index(index: int) -> void:
	if index < 0 or index >= _tab_buttons.size():
		return
	_active_tab_index = index
	var cats := LeaderboardService.get_categories()
	if index < cats.size():
		active_category_id = cats[index].get("id", "")
	_update_tab_styles()
	_load_current_category(false)
	_update_personal_best_strip()


func _update_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		var btn := _tab_buttons[i]
		var is_active := (i == _active_tab_index)

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(20)
		style.content_margin_left = 18.0
		style.content_margin_right = 18.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0

		if is_active:
			style.bg_color = Color(0.12, 0.45, 0.70, 0.95)
			style.border_color = Color(0.40, 0.85, 1.0, 1.0)
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		else:
			style.bg_color = Color(0.08, 0.12, 0.18, 0.75)
			style.border_color = Color(0.24, 0.40, 0.55, 0.4)
			style.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.80, 0.85, 0.90, 0.85))

		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.40, 0.85, 1.0, 0.85)

		var focus_style := style.duplicate() as StyleBoxFlat
		focus_style.border_color = Color(0.95, 0.82, 0.25, 1.0)
		focus_style.set_border_width_all(2)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", focus_style)


func _load_current_category(force_refresh: bool = false) -> void:
	if leaderboard_service == null:
		return

	if _loading_indicator != null:
		_loading_indicator.visible = true
	if _empty_label != null:
		_empty_label.visible = false

	var result: Dictionary = await leaderboard_service.fetch_category(active_category_id, force_refresh)

	if _loading_indicator != null:
		_loading_indicator.visible = false

	var is_ok: bool = result.get("ok", false)
	var entries: Array = result.get("entries", [])
	var from_cache: bool = result.get("from_cache", false)
	var updated_at: int = int(result.get("updated_at", 0))
	_last_updated_time = updated_at

	_current_entries = entries

	if _offline_banner != null:
		var has_err := not str(result.get("error", "")).is_empty()
		_offline_banner.visible = from_cache and has_err

	_update_status_time_label(updated_at, from_cache)
	_render_leaderboard_rows(entries, from_cache)
	_update_controller_focus_navigation()


func _update_status_time_label(updated_at: int, from_cache: bool) -> void:
	if _status_label == null:
		return
	if updated_at <= 0:
		_status_label.text = ""
		return

	var now := int(Time.get_unix_time_from_system())
	var diff_sec: int = int(max(0, now - updated_at))
	var diff_min := int(diff_sec / 60)

	var text := ""
	if diff_min <= 0:
		text = "Updated just now"
	elif diff_min == 1:
		text = "Updated 1 min ago"
	else:
		text = "Updated %d min ago" % diff_min

	if from_cache:
		text += " (Cached)"
	_status_label.text = text


func _set_status_text(txt: String) -> void:
	if _status_label != null:
		_status_label.text = txt


func _render_leaderboard_rows(entries: Array, _from_cache: bool) -> void:
	if _rows_container == null:
		return

	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()

	_row_buttons.clear()

	if entries.is_empty():
		if _empty_label != null:
			_empty_label.visible = true
			_empty_label.text = "No scores posted yet in this category."
		return

	if _empty_label != null:
		_empty_label.visible = false

	var cat_def := LeaderboardService.get_category_def(active_category_id)
	var current_uid := ""
	var auth := _get_cloud_auth()
	if auth != null and auth.has_method("get_uid"):
		current_uid = auth.get_uid()

	for rank_idx in range(entries.size()):
		var entry: Dictionary = entries[rank_idx]
		var rank_num := rank_idx + 1
		var entry_uid: String = entry.get("uid", "")
		var is_you := (not current_uid.is_empty() and entry_uid == current_uid)

		var row_btn := _create_row_button(rank_num, entry, cat_def, is_you)
		_rows_container.add_child(row_btn)
		_row_buttons.append(row_btn)


func _create_row_button(rank: int, entry: Dictionary, cat_def: Dictionary, is_you: bool) -> Button:
	var btn := Button.new()
	btn.name = "Row_%d" % rank
	btn.custom_minimum_size = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL

	# Styling
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	if is_you:
		style.bg_color = Color(0.12, 0.28, 0.40, 0.95)
		style.border_color = Color(0.35, 0.85, 1.0, 0.95)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.06, 0.09, 0.14, 0.85) if (rank % 2 == 1) else Color(0.08, 0.12, 0.18, 0.85)
		style.border_color = Color(0.20, 0.32, 0.45, 0.3)
		style.set_border_width_all(1)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.40, 0.82, 1.0, 0.85)

	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.95, 0.82, 0.25, 1.0)
	focus_style.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", focus_style)

	# Content layout inside row button
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 14)
	btn.add_child(hbox)

	# 1. Rank Label
	var rank_lbl := Label.new()
	rank_lbl.custom_minimum_size = Vector2(70, 0)
	var rank_text := "#%d" % rank
	if rank == 1:
		rank_text = "#1 🥇"
	elif rank == 2:
		rank_text = "#2 🥈"
	elif rank == 3:
		rank_text = "#3 🥉"
	rank_lbl.text = rank_text
	rank_lbl.add_theme_font_size_override("font_size", 16)
	if rank <= 3:
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	else:
		rank_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	hbox.add_child(rank_lbl)

	# 2. Player Display Name + Badges
	var player_box := HBoxContainer.new()
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_box.add_theme_constant_override("separation", 10)
	hbox.add_child(player_box)

	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("display_name", "Golfer"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	player_box.add_child(name_lbl)

	if is_you:
		var you_badge := _create_badge("YOU", Color(0.15, 0.45, 0.75, 0.95), Color(0.40, 0.85, 1.0, 1.0))
		player_box.add_child(you_badge)

	var skill_level: String = entry.get("skill_level", "")
	if not skill_level.is_empty():
		var skill_title := _format_skill_badge(skill_level)
		if not skill_title.is_empty():
			var skill_badge := _create_badge(skill_title, Color(0.12, 0.16, 0.22, 0.8), Color(0.35, 0.50, 0.65, 0.8))
			player_box.add_child(skill_badge)

	# 3. Stat Value
	var stat_val_box := VBoxContainer.new()
	stat_val_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_val_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(stat_val_box)

	var val_lbl := Label.new()
	val_lbl.text = LeaderboardService.format_metric_value(cat_def, entry)
	val_lbl.add_theme_font_size_override("font_size", 17)
	val_lbl.add_theme_color_override("font_color", Color(0.40, 0.88, 1.0, 1.0) if is_you else Color(0.95, 0.95, 0.95, 1.0))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stat_val_box.add_child(val_lbl)

	return btn


func _create_badge(txt: String, bg_col: Color, border_col: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", border_col)
	badge.add_child(lbl)
	return badge


func _format_skill_badge(skill: String) -> String:
	match skill.to_lower():
		"scratch_or_better", "scratch":
			return "Scratch"
		"low_handicap", "low":
			return "Low HCP"
		"mid_handicap", "mid":
			return "Mid HCP"
		"high_handicap", "high":
			return "High HCP"
		"beginner":
			return "Beginner"
		_:
			return ""


func _update_personal_best_strip() -> void:
	if _pb_strip == null:
		return

	var primary_player := _get_local_primary_player()
	var player_name: String = primary_player.get("name", "Local Golfer")
	if _pb_player_label != null:
		_pb_player_label.text = "YOUR RECORD (%s):" % player_name

	var stat_str := _get_local_player_stat(primary_player, active_category_id)
	if _pb_stat_label != null:
		_pb_stat_label.text = stat_str

	if _pb_sync_label != null:
		var auth := _get_cloud_auth()
		var signed_in: bool = (auth != null and auth.has_method("is_signed_in") and auth.is_signed_in())
		if signed_in:
			_pb_sync_label.text = "✓ Synced to Leaderboard"
			_pb_sync_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45, 1.0))
		else:
			_pb_sync_label.text = "Sign in on the Players page or tap Account above to post your stats to global leaderboards"
			_pb_sync_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.40, 0.9))


func _get_local_primary_player() -> Dictionary:
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_method("get_registered_players"):
			var players = mp.get_registered_players()
			for p in players:
				if p.get("link_role", "") == "primary" or p.get("is_primary", false):
					return p
			if players.size() > 0:
				return players[0]
	return {}


func _get_local_player_stat(player: Dictionary, category_id: String) -> String:
	var cat_def := LeaderboardService.get_category_def(category_id)
	if cat_def.is_empty():
		return "--"

	var player_name: String = player.get("name", "")
	var stat_val: Variant = null

	if category_id == "longest_drive" and has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_method("get_player_longest_drive"):
			stat_val = mp.get_player_longest_drive(player_name)
	elif category_id == "longest_putt" and has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_method("get_player_longest_putt"):
			stat_val = mp.get_player_longest_putt(player_name)
	elif category_id == "most_achievements":
		if has_node("/root/AchievementManager"):
			var ach_mgr = get_node("/root/AchievementManager")
			if ach_mgr.has_method("get_unlocked_achievements"):
				var unl = ach_mgr.get_unlocked_achievements(player_name)
				if unl is Dictionary and unl.size() > 0:
					stat_val = unl.size()

	if stat_val == null or float(stat_val) <= 0.0:
		var lifetime = player.get("lifetime", {})
		if lifetime.is_empty():
			lifetime = player.get("cloud_lifetime_cache", {})
		stat_val = lifetime.get(cat_def.get("field", ""), null)

	if stat_val != null:
		var dummy_doc := {cat_def.get("field", ""): stat_val}
		if cat_def.has("secondary_field"):
			var lt_dict = player.get("lifetime", player.get("cloud_lifetime_cache", {}))
			dummy_doc[cat_def["secondary_field"]] = lt_dict.get(cat_def["secondary_field"], 0)
		return LeaderboardService.format_metric_value(cat_def, dummy_doc)

	return "--"


func _update_controller_focus_navigation() -> void:
	if _back_button == null:
		return

	# Helper to link
	var set_btn_neighbors = func(btn: Control, left: Control, right: Control, top: Control, bottom: Control):
		if btn == null:
			return
		if left != null:
			btn.focus_neighbor_left = left.get_path()
		if right != null:
			btn.focus_neighbor_right = right.get_path()
		if top != null:
			btn.focus_neighbor_top = top.get_path()
		if bottom != null:
			btn.focus_neighbor_bottom = bottom.get_path()

	var first_tab: Control = _tab_buttons[0] if _tab_buttons.size() > 0 else null
	var active_tab: Control = _tab_buttons[_active_tab_index] if (_active_tab_index < _tab_buttons.size()) else first_tab
	var last_tab: Control = _tab_buttons[_tab_buttons.size() - 1] if _tab_buttons.size() > 0 else null

	# Header bar connections
	set_btn_neighbors.call(_back_button, _account_button, _refresh_button, active_tab, active_tab)
	set_btn_neighbors.call(_refresh_button, _back_button, _account_button, active_tab, active_tab)
	set_btn_neighbors.call(_account_button, _refresh_button, _back_button, active_tab, active_tab)

	# Category Tabs
	var first_row: Control = _row_buttons[0] if _row_buttons.size() > 0 else null

	for i in range(_tab_buttons.size()):
		var tab := _tab_buttons[i]
		var left_neighbor := _tab_buttons[(i - 1 + _tab_buttons.size()) % _tab_buttons.size()]
		var right_neighbor := _tab_buttons[(i + 1) % _tab_buttons.size()]
		var top_neighbor := _back_button if (i < 3) else (_refresh_button if (i < 5) else _account_button)
		var bottom_neighbor := first_row if (first_row != null) else _account_button

		set_btn_neighbors.call(tab, left_neighbor, right_neighbor, top_neighbor, bottom_neighbor)

	# Leaderboard Rows
	for j in range(_row_buttons.size()):
		var row := _row_buttons[j]
		var top_neighbor := active_tab if (j == 0) else _row_buttons[j - 1]
		var bottom_neighbor := active_tab if (j == _row_buttons.size() - 1) else _row_buttons[j + 1]
		var left_neighbor := _tab_buttons[max(0, _active_tab_index - 1)] if _tab_buttons.size() > 0 else null
		var right_neighbor := _tab_buttons[min(_tab_buttons.size() - 1, _active_tab_index + 1)] if _tab_buttons.size() > 0 else null

		set_btn_neighbors.call(row, left_neighbor, right_neighbor, top_neighbor, bottom_neighbor)


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg.is_modal_active():
			return
	if _tab_buttons.size() > _active_tab_index and is_instance_valid(_tab_buttons[_active_tab_index]):
		_tab_buttons[_active_tab_index].grab_focus()
	elif _back_button != null and is_instance_valid(_back_button):
		_back_button.grab_focus()


func _get_cloud_auth() -> Node:
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("CloudAuth")
	return null
