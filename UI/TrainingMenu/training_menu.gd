extends Control

## Interactive Training Academy Hub.
## Lets golfers pick an improvement goal ("What do you want to work on?")
## or click "Suggest a Drill for Me" to analyze their telemetry and prescribe
## the highest-impact drill with transparent evidence and personal bests.

const Catalog = preload("res://Courses/Training/training_catalog.gd")
const ProgressStore = preload("res://Courses/Training/training_progress_store.gd")
const Recommender = preload("res://Courses/Training/training_recommendation_engine.gd")
const MAIN_MENU_SCENE := "res://UI/MainMenu/main_menu.tscn"
const TRAINING_ARENA_SCENE := "res://Courses/Training/training_arena.tscn"

var _selected_player_name: String = "Player 1"
var _selected_category_id: String = "straighter_drives"
var _selected_drill_id: String = "fairway_finder"
var _selected_difficulty: String = "standard"
var _selected_club: String = "Dr"
var _is_suggested_mode: bool = false
var _last_recommendation: Dictionary = {}
var _active_diagnosis_reason: String = ""
var _active_diagnosis_evidence: Array = []

# UI References
var _back_btn: Button = null
var _player_dropdown: OptionButton = null
var _diff_buttons: Dictionary = {}
var _suggest_btn: Button = null
var _data_status_lbl: Label = null
var _category_cards: Dictionary = {}
var _category_buttons: Dictionary = {}
var _category_best_labels: Dictionary = {}

# Briefing Panel References
var _briefing_badge_lbl: Label = null
var _briefing_badge_panel: PanelContainer = null
var _drill_name_lbl: Label = null
var _drill_desc_lbl: Label = null
var _why_title_lbl: Label = null
var _why_body_lbl: Label = null
var _evidence_box: VBoxContainer = null
var _cue_lbl: Label = null
var _switcher_hbox: HBoxContainer = null
var _club_dropdown: OptionButton = null
var _club_lock_note_lbl: Label = null
var _meta_info_lbl: Label = null
var _personal_best_lbl: Label = null
var _start_drill_btn: Button = null


func _ready() -> void:
	name = "TrainingMenu"
	_resolve_initial_player()
	_build_ui()
	_refresh_player_data_status()
	_refresh_category_bests()
	select_category("straighter_drives")
	call_deferred("_grab_initial_focus")


func _resolve_initial_player() -> void:
	var mp := _get_multiplayer_manager()
	if mp != null:
		if not mp.players.is_empty():
			var ap: Dictionary = mp.get_active_player()
			var n := str(ap.get("name", "")).strip_edges()
			if not n.is_empty():
				_selected_player_name = n
				return
		if mp.has_method("get_default_range_profile_name"):
			var def_name := str(mp.get_default_range_profile_name()).strip_edges()
			if not def_name.is_empty():
				_selected_player_name = def_name


func _get_multiplayer_manager() -> Node:
	if is_inside_tree() and has_node("/root/MultiplayerManager"):
		return get_node("/root/MultiplayerManager")
	return null


func _build_ui() -> void:
	# Background texture
	var bg_texture := TextureRect.new()
	bg_texture.name = "Background"
	if ResourceLoader.exists("res://assets/images/menu/cabo_openfairway_bnw.png"):
		bg_texture.texture = load("res://assets/images/menu/cabo_openfairway_bnw.png")
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_texture)

	var glass_overlay := ColorRect.new()
	glass_overlay.color = Color(0.04, 0.08, 0.12, 0.88)
	glass_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glass_overlay)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 28)
	root_margin.add_theme_constant_override("margin_right", 28)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(root_vbox)

	# ─── TOP HEADER BAR ───────────────────────────────────────────────────────
	var header_panel := PanelContainer.new()
	ThemeManager.apply_card_panel_style(header_panel, false, 12, 18, 12, 18, 12)
	root_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	header_panel.add_child(header_hbox)

	_back_btn = Button.new()
	_back_btn.name = "BackButton"
	_back_btn.text = "<- Main Menu"
	_back_btn.custom_minimum_size = Vector2(150, 44)
	_back_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_nav_button_style(_back_btn, 8)
	_back_btn.pressed.connect(_on_back_pressed)
	header_hbox.add_child(_back_btn)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "TRAINING ACADEMY"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Pick a focus area or let your shot data prescribe your best drill"
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	title_vbox.add_child(sub_lbl)

	# Player selector
	var player_box := HBoxContainer.new()
	player_box.add_theme_constant_override("separation", 8)
	header_hbox.add_child(player_box)

	var player_lbl := Label.new()
	player_lbl.text = "Golfer:"
	player_lbl.add_theme_font_size_override("font_size", 15)
	player_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	player_box.add_child(player_lbl)

	_player_dropdown = OptionButton.new()
	_player_dropdown.name = "PlayerDropdown"
	_player_dropdown.custom_minimum_size = Vector2(175, 42)
	_player_dropdown.add_theme_font_size_override("font_size", 15)
	_populate_player_dropdown()
	_player_dropdown.item_selected.connect(_on_player_selected)
	player_box.add_child(_player_dropdown)

	# Difficulty pills
	var diff_hbox := HBoxContainer.new()
	diff_hbox.add_theme_constant_override("separation", 6)
	header_hbox.add_child(diff_hbox)

	for diff_item in [
		{"id": "beginner", "label": "Beginner"},
		{"id": "standard", "label": "Standard"},
		{"id": "pro", "label": "Tour Pro"}
	]:
		var d_btn := Button.new()
		d_btn.name = "Diff_%s" % diff_item["id"]
		d_btn.text = diff_item["label"]
		d_btn.custom_minimum_size = Vector2(96, 42)
		d_btn.add_theme_font_size_override("font_size", 14)
		var d_id: String = diff_item["id"]
		d_btn.pressed.connect(func(): _set_difficulty(d_id))
		diff_hbox.add_child(d_btn)
		_diff_buttons[d_id] = d_btn
	_update_difficulty_buttons()

	# ─── RESPONSIVE SCROLLABLE BODY ──────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)
	TouchScrollHelper.attach_to(scroll)

	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 20)
	scroll.add_child(body_hbox)

	# ─── LEFT COLUMN (Suggest-a-Drill Hero + 4x2 Goal Cards) ──────────────────
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.45
	left_vbox.add_theme_constant_override("separation", 14)
	body_hbox.add_child(left_vbox)

	# Hero Suggest Card
	var hero_panel := PanelContainer.new()
	hero_panel.name = "SuggestHeroCard"
	var hero_style := StyleBoxFlat.new()
	hero_style.bg_color = Color(0.08, 0.22, 0.18, 0.92)
	hero_style.border_color = Color(0.35, 0.92, 0.60, 0.65)
	hero_style.set_border_width_all(2)
	hero_style.set_corner_radius_all(12)
	hero_style.content_margin_left = 18
	hero_style.content_margin_right = 18
	hero_style.content_margin_top = 14
	hero_style.content_margin_bottom = 14
	hero_panel.add_theme_stylebox_override("panel", hero_style)
	left_vbox.add_child(hero_panel)

	var hero_hbox := HBoxContainer.new()
	hero_hbox.add_theme_constant_override("separation", 16)
	hero_panel.add_child(hero_hbox)

	var hero_text_vbox := VBoxContainer.new()
	hero_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_text_vbox.add_theme_constant_override("separation", 4)
	hero_hbox.add_child(hero_text_vbox)

	var hero_title := Label.new()
	hero_title.text = "Not sure what to practice?"
	hero_title.add_theme_font_size_override("font_size", 20)
	hero_title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	hero_text_vbox.add_child(hero_title)

	_data_status_lbl = Label.new()
	_data_status_lbl.name = "DataStatusLabel"
	_data_status_lbl.text = "Analyzing player shot profile..."
	_data_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_data_status_lbl.add_theme_font_size_override("font_size", 14)
	_data_status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	hero_text_vbox.add_child(_data_status_lbl)

	_suggest_btn = Button.new()
	_suggest_btn.name = "SuggestDrillButton"
	_suggest_btn.text = "* SUGGEST A DRILL FOR ME"
	_suggest_btn.custom_minimum_size = Vector2(260, 54)
	_suggest_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_suggest_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_primary_button_style(_suggest_btn, 10)
	_suggest_btn.pressed.connect(trigger_suggest_drill)
	hero_hbox.add_child(_suggest_btn)

	# Section Header
	var grid_hdr := Label.new()
	grid_hdr.text = "WHAT DO YOU WANT TO WORK ON?"
	grid_hdr.add_theme_font_size_override("font_size", 17)
	grid_hdr.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	left_vbox.add_child(grid_hdr)

	# 4x2 Goal Grid
	var goal_grid := GridContainer.new()
	goal_grid.name = "GoalGrid"
	goal_grid.columns = 2
	goal_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_grid.add_theme_constant_override("h_separation", 12)
	goal_grid.add_theme_constant_override("v_separation", 12)
	left_vbox.add_child(goal_grid)

	for cat in Catalog.get_categories():
		var card := _create_category_card(cat)
		goal_grid.add_child(card)

	# ─── RIGHT COLUMN (Live Prescribed Drill Briefing Panel) ──────────────────
	var right_panel := PanelContainer.new()
	right_panel.name = "BriefingPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	ThemeManager.apply_card_panel_style(right_panel, false, 12, 20, 18, 20, 18)
	body_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_panel.add_child(right_vbox)

	# Badge pill
	_briefing_badge_panel = PanelContainer.new()
	_briefing_badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right_vbox.add_child(_briefing_badge_panel)

	_briefing_badge_lbl = Label.new()
	_briefing_badge_lbl.text = " PRESCRIBED DRILL"
	_briefing_badge_lbl.add_theme_font_size_override("font_size", 13)
	_briefing_badge_panel.add_child(_briefing_badge_lbl)

	# Drill Name & Description
	_drill_name_lbl = Label.new()
	_drill_name_lbl.name = "DrillNameLabel"
	_drill_name_lbl.text = "Drill Name"
	_drill_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_drill_name_lbl.add_theme_font_size_override("font_size", 26)
	_drill_name_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	right_vbox.add_child(_drill_name_lbl)

	_drill_desc_lbl = Label.new()
	_drill_desc_lbl.name = "DrillDescLabel"
	_drill_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_drill_desc_lbl.add_theme_font_size_override("font_size", 14)
	_drill_desc_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	right_vbox.add_child(_drill_desc_lbl)

	# Switcher tabs (category drills or suggested alternatives)
	var sw_label := Label.new()
	sw_label.text = "PRESCRIBED OPTIONS:"
	sw_label.add_theme_font_size_override("font_size", 12)
	sw_label.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	right_vbox.add_child(sw_label)

	_switcher_hbox = HBoxContainer.new()
	_switcher_hbox.name = "DrillSwitcher"
	_switcher_hbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(_switcher_hbox)

	# Diagnosis / Why This Helps Box
	var why_panel := PanelContainer.new()
	var why_style := StyleBoxFlat.new()
	why_style.bg_color = Color(0.06, 0.10, 0.16, 0.85)
	why_style.border_color = Color(0.24, 0.44, 0.65, 0.45)
	why_style.set_border_width_all(1)
	why_style.set_corner_radius_all(8)
	why_style.set_content_margin_all(12)
	why_panel.add_theme_stylebox_override("panel", why_style)
	right_vbox.add_child(why_panel)

	var why_vbox := VBoxContainer.new()
	why_vbox.add_theme_constant_override("separation", 6)
	why_panel.add_child(why_vbox)

	_why_title_lbl = Label.new()
	_why_title_lbl.text = "WHY THIS HELPS"
	_why_title_lbl.add_theme_font_size_override("font_size", 13)
	_why_title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	why_vbox.add_child(_why_title_lbl)

	_why_body_lbl = Label.new()
	_why_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_why_body_lbl.add_theme_font_size_override("font_size", 14)
	_why_body_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	why_vbox.add_child(_why_body_lbl)

	_evidence_box = VBoxContainer.new()
	_evidence_box.add_theme_constant_override("separation", 4)
	why_vbox.add_child(_evidence_box)

	# Pro Feel Cue Box
	var cue_panel := PanelContainer.new()
	var cue_style := StyleBoxFlat.new()
	cue_style.bg_color = Color(0.08, 0.16, 0.14, 0.85)
	cue_style.border_color = Color(0.25, 0.80, 0.50, 0.40)
	cue_style.set_border_width_all(1)
	cue_style.set_corner_radius_all(8)
	cue_style.set_content_margin_all(12)
	cue_panel.add_theme_stylebox_override("panel", cue_style)
	right_vbox.add_child(cue_panel)

	var cue_vbox := VBoxContainer.new()
	cue_vbox.add_theme_constant_override("separation", 4)
	cue_panel.add_child(cue_vbox)

	var cue_hdr := Label.new()
	cue_hdr.text = "PRO FEEL CUE"
	cue_hdr.add_theme_font_size_override("font_size", 12)
	cue_hdr.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
	cue_vbox.add_child(cue_hdr)

	_cue_lbl = Label.new()
	_cue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_cue_lbl.add_theme_font_size_override("font_size", 14)
	_cue_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	cue_vbox.add_child(_cue_lbl)

	# Club Selector + Meta Row
	var club_hbox := HBoxContainer.new()
	club_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(club_hbox)

	var club_lbl := Label.new()
	club_lbl.text = "Club:"
	club_lbl.add_theme_font_size_override("font_size", 15)
	club_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	club_hbox.add_child(club_lbl)

	_club_dropdown = OptionButton.new()
	_club_dropdown.name = "ClubDropdown"
	_club_dropdown.custom_minimum_size = Vector2(160, 40)
	_club_dropdown.add_theme_font_size_override("font_size", 14)
	_populate_club_dropdown()
	_club_dropdown.item_selected.connect(_on_club_selected)
	club_hbox.add_child(_club_dropdown)

	_club_lock_note_lbl = Label.new()
	_club_lock_note_lbl.text = ""
	_club_lock_note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_club_lock_note_lbl.add_theme_font_size_override("font_size", 12)
	_club_lock_note_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DIM)
	club_hbox.add_child(_club_lock_note_lbl)

	_meta_info_lbl = Label.new()
	_meta_info_lbl.add_theme_font_size_override("font_size", 14)
	_meta_info_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	right_vbox.add_child(_meta_info_lbl)

	_personal_best_lbl = Label.new()
	_personal_best_lbl.name = "PersonalBestLabel"
	_personal_best_lbl.add_theme_font_size_override("font_size", 14)
	_personal_best_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	right_vbox.add_child(_personal_best_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)

	_start_drill_btn = Button.new()
	_start_drill_btn.name = "StartDrillButton"
	_start_drill_btn.text = "> START DRILL"
	_start_drill_btn.custom_minimum_size = Vector2(0, 56)
	_start_drill_btn.add_theme_font_size_override("font_size", 20)
	ThemeManager.apply_primary_button_style(_start_drill_btn, 10)
	_start_drill_btn.pressed.connect(_on_start_drill_pressed)
	right_vbox.add_child(_start_drill_btn)


func _create_category_card(cat: Dictionary) -> PanelContainer:
	var cat_id := str(cat["id"])
	var accent: Color = cat.get("accent", ThemeManager.COLOR_TEXT_ACCENT)

	var panel := PanelContainer.new()
	panel.name = "CategoryCard_%s" % cat_id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(230, 104)
	ThemeManager.apply_card_panel_style(panel, false, 10, 0, 0, 0, 0)

	var btn := Button.new()
	btn.name = "CategoryBtn_%s" % cat_id
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty_style := StyleBoxEmpty.new()
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	hover_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = Color(0.35, 0.82, 1.0, 0.95)
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("focus", focus_style)
	btn.pressed.connect(func(): select_category(cat_id))
	panel.add_child(btn)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var icon_lbl := Label.new()
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_lbl.text = str(cat["icon"])
	icon_lbl.add_theme_font_size_override("font_size", 22)
	top_row.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = str(cat["title"])
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	top_row.add_child(title_lbl)

	var best_lbl := Label.new()
	best_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best_lbl.text = ""
	best_lbl.add_theme_font_size_override("font_size", 12)
	best_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	top_row.add_child(best_lbl)

	var tag_lbl := Label.new()
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_lbl.text = str(cat["tagline"])
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	vbox.add_child(tag_lbl)

	_category_cards[cat_id] = panel
	_category_buttons[cat_id] = btn
	_category_best_labels[cat_id] = best_lbl
	return panel


func _populate_player_dropdown() -> void:
	_player_dropdown.clear()
	var names: Array[String] = []
	var reg := MultiplayerManager.get_registered_players()
	for p in reg:
		var p_name := str(p.get("name", "")).strip_edges()
		if not p_name.is_empty() and not names.has(p_name):
			names.append(p_name)
	if names.is_empty():
		names.append(_selected_player_name if not _selected_player_name.is_empty() else "Player 1")

	var sel_idx := 0
	for i in range(names.size()):
		_player_dropdown.add_item(names[i])
		if names[i].to_lower() == _selected_player_name.to_lower():
			sel_idx = i
	_player_dropdown.selected = sel_idx
	_selected_player_name = _player_dropdown.get_item_text(sel_idx)


func _populate_club_dropdown() -> void:
	_club_dropdown.clear()
	for c in MultiplayerManager.STANDARD_CLUBS:
		if c == "Pt":
			continue
		_club_dropdown.add_item(MultiplayerManager.get_club_display_name(c))
		_club_dropdown.set_item_metadata(_club_dropdown.item_count - 1, c)


func _select_club_in_dropdown(club_code: String) -> void:
	for i in range(_club_dropdown.item_count):
		if str(_club_dropdown.get_item_metadata(i)).to_lower() == club_code.to_lower():
			_club_dropdown.selected = i
			_selected_club = str(_club_dropdown.get_item_metadata(i))
			return
	if _club_dropdown.item_count > 0:
		_club_dropdown.selected = 0
		_selected_club = str(_club_dropdown.get_item_metadata(0))


func _on_club_selected(idx: int) -> void:
	_selected_club = str(_club_dropdown.get_item_metadata(idx))


func _on_player_selected(idx: int) -> void:
	_selected_player_name = _player_dropdown.get_item_text(idx)
	_refresh_player_data_status()
	_refresh_category_bests()
	if _is_suggested_mode:
		trigger_suggest_drill()
	else:
		_refresh_briefing_panel()


func _set_difficulty(diff_id: String) -> void:
	_selected_difficulty = Catalog.normalize_difficulty(diff_id)
	_update_difficulty_buttons()
	_refresh_briefing_panel()


func _update_difficulty_buttons() -> void:
	for d_id in _diff_buttons.keys():
		ThemeManager.apply_tab_button_style(_diff_buttons[d_id], d_id == _selected_difficulty, 8)


func _refresh_player_data_status() -> void:
	var rec := Recommender.recommend_for_player(_selected_player_name)
	var total_shots := int(rec.get("total_shots_analyzed", 0))
	var clubs_cnt := int(rec.get("clubs_analyzed", 0))
	if total_shots < 5:
		_data_status_lbl.text = "%s: %d recorded shots found - click Suggest to take your Baseline Skill Combine!" % [_selected_player_name, total_shots]
	else:
		_data_status_lbl.text = "%s: Ready to analyze %d shots across %d clubs + swing telemetry." % [_selected_player_name, total_shots, clubs_cnt]


func _refresh_category_bests() -> void:
	var prog := ProgressStore.get_player_progress(_selected_player_name)
	var drills_prog: Dictionary = prog.get("drills", {})
	for cat in Catalog.get_categories():
		var cat_id := str(cat["id"])
		var lbl := _category_best_labels.get(cat_id) as Label
		if lbl == null:
			continue
		var primary_drill_id := str(cat.get("drills", ["fairway_finder"])[0])
		if drills_prog.has(primary_drill_id):
			var b: Dictionary = drills_prog[primary_drill_id]
			lbl.text = "Best %s (%.0f%%)" % [str(b.get("best_grade", "")), float(b.get("best_accuracy", 0.0))]
		else:
			lbl.text = ""


func _highlight_selected_category() -> void:
	for cat in Catalog.get_categories():
		var cat_id := str(cat["id"])
		var panel := _category_cards.get(cat_id) as PanelContainer
		if panel == null:
			continue
		var is_sel := (cat_id == _selected_category_id)
		var accent: Color = cat.get("accent", ThemeManager.COLOR_TEXT_ACCENT)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.92) if is_sel else ThemeManager.COLOR_GLASS_PANEL
		style.border_color = accent if is_sel else ThemeManager.COLOR_GLASS_BORDER
		style.set_border_width_all(2 if is_sel else 1)
		style.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", style)


func select_category(category_id: String) -> void:
	_is_suggested_mode = false
	_active_diagnosis_reason = ""
	_active_diagnosis_evidence.clear()
	_selected_category_id = category_id
	var drills := Catalog.get_drills_for_category(category_id)
	_selected_drill_id = str(drills[0].get("id", "fairway_finder"))
	var drill := Catalog.get_drill(_selected_drill_id)
	_selected_club = str(drill.get("recommended_club", "7i"))
	_highlight_selected_category()
	_refresh_briefing_panel()


func select_drill(drill_id: String, override_club: String = "") -> void:
	var drill := Catalog.get_drill(drill_id)
	_selected_drill_id = str(drill.get("id", "fairway_finder"))
	_selected_category_id = str(drill.get("category_id", _selected_category_id))
	_selected_club = override_club if not override_club.is_empty() else str(drill.get("recommended_club", "7i"))
	_highlight_selected_category()
	_refresh_briefing_panel()


func trigger_suggest_drill() -> void:
	_is_suggested_mode = true
	_last_recommendation = Recommender.recommend_for_player(_selected_player_name)
	var primary: Dictionary = _last_recommendation.get("primary", {})
	_selected_drill_id = str(primary.get("drill_id", "skill_combine"))
	var drill := Catalog.get_drill(_selected_drill_id)
	_selected_category_id = str(drill.get("category_id", "full_assessment"))
	_selected_club = str(primary.get("recommended_club", drill.get("recommended_club", "7i")))
	_selected_difficulty = Catalog.normalize_difficulty(str(_last_recommendation.get("suggested_difficulty", _selected_difficulty)))
	_active_diagnosis_reason = str(primary.get("reason", ""))
	_active_diagnosis_evidence = primary.get("evidence", []).duplicate()
	_update_difficulty_buttons()
	_highlight_selected_category()
	_refresh_briefing_panel()


func get_selected_drill_id() -> String:
	return _selected_drill_id


func _refresh_briefing_panel() -> void:
	var drill := Catalog.get_drill(_selected_drill_id)
	_drill_name_lbl.text = str(drill.get("name", ""))
	_drill_desc_lbl.text = str(drill.get("short_desc", ""))
	_cue_lbl.text = str(drill.get("coaching_cue", ""))

	# Badge styling
	var badge_style := StyleBoxFlat.new()
	badge_style.set_corner_radius_all(6)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	if _is_suggested_mode:
		badge_style.bg_color = Color(0.28, 0.22, 0.06, 0.95)
		badge_style.border_color = ThemeManager.COLOR_TEXT_GOLD
		_briefing_badge_lbl.text = "* PERSONALIZED RECOMMENDATION"
		_briefing_badge_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	else:
		badge_style.bg_color = Color(0.08, 0.20, 0.30, 0.95)
		badge_style.border_color = ThemeManager.COLOR_TEXT_ACCENT
		_briefing_badge_lbl.text = " PRESCRIBED DRILL"
		_briefing_badge_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	badge_style.set_border_width_all(1)
	_briefing_badge_panel.add_theme_stylebox_override("panel", badge_style)

	# Switcher tabs
	for child in _switcher_hbox.get_children():
		child.queue_free()

	if _is_suggested_mode and not _last_recommendation.is_empty():
		var opt_list: Array[Dictionary] = []
		var prim: Dictionary = _last_recommendation.get("primary", {})
		if not prim.is_empty():
			opt_list.append(prim)
		for alt in _last_recommendation.get("alternatives", []):
			opt_list.append(alt)
		for i in range(opt_list.size()):
			var rec_item: Dictionary = opt_list[i]
			var d_id := str(rec_item.get("drill_id", ""))
			var d_info := Catalog.get_drill(d_id)
			var prefix := "#1 Top Pick: " if i == 0 else "#%d Alt: " % (i + 1)
			var tab := Button.new()
			tab.text = prefix + str(d_info.get("name", d_id))
			tab.custom_minimum_size = Vector2(0, 36)
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.add_theme_font_size_override("font_size", 12)
			ThemeManager.apply_tab_button_style(tab, d_id == _selected_drill_id, 6)
			var captured_rec := rec_item
			tab.pressed.connect(func():
				_active_diagnosis_reason = str(captured_rec.get("reason", ""))
				_active_diagnosis_evidence = captured_rec.get("evidence", []).duplicate()
				select_drill(str(captured_rec.get("drill_id", "")), str(captured_rec.get("recommended_club", "")))
			)
			_switcher_hbox.add_child(tab)
	else:
		var cat_drills := Catalog.get_drills_for_category(_selected_category_id)
		for i in range(cat_drills.size()):
			var cd: Dictionary = cat_drills[i]
			var d_id := str(cd.get("id", ""))
			var tab := Button.new()
			tab.text = ("Primary: " if i == 0 else "Alt: ") + str(cd.get("name", d_id))
			tab.custom_minimum_size = Vector2(0, 36)
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.add_theme_font_size_override("font_size", 13)
			ThemeManager.apply_tab_button_style(tab, d_id == _selected_drill_id, 6)
			tab.pressed.connect(func(): select_drill(d_id))
			_switcher_hbox.add_child(tab)

	# Diagnosis / Evidence Box
	for child in _evidence_box.get_children():
		child.queue_free()

	if _is_suggested_mode and not _active_diagnosis_reason.is_empty():
		_why_title_lbl.text = "WHY THIS DRILL WAS PRESCRIBED"
		_why_body_lbl.text = _active_diagnosis_reason
		for ev in _active_diagnosis_evidence:
			var ev_lbl := Label.new()
			ev_lbl.text = "| " + str(ev)
			ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			ev_lbl.add_theme_font_size_override("font_size", 13)
			ev_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
			_evidence_box.add_child(ev_lbl)
	else:
		_why_title_lbl.text = "WHY THIS HELPS"
		_why_body_lbl.text = str(drill.get("why_it_helps", ""))

	# Club selector
	_select_club_in_dropdown(_selected_club)
	var is_combine := str(drill.get("visual_mode", "")) == "combine"
	_club_dropdown.disabled = is_combine
	_club_lock_note_lbl.text = "Auto-rotates clubs per station" if is_combine else "Editable before or during drill"

	# Meta info + personal best
	var reps := int(drill.get("reps", 10))
	var diff_name := Catalog.get_difficulty_display_name(_selected_difficulty)
	_meta_info_lbl.text = "Format: %d Shots  |  Difficulty: %s  |  Live Combo & Trend Tracking" % [reps, diff_name]

	var best := ProgressStore.get_drill_best(_selected_player_name, _selected_drill_id)
	if best.is_empty():
		_personal_best_lbl.text = "Personal Best (%s): Not yet attempted - set your first mark!" % _selected_player_name
	else:
		_personal_best_lbl.text = "Personal Best (%s): Grade %s | %d pts | %.0f%% Acc | %dx Best Streak (%d sessions)" % [
			_selected_player_name,
			str(best.get("best_grade", "D")),
			int(best.get("best_score", 0)),
			float(best.get("best_accuracy", 0.0)),
			int(best.get("best_streak", 0)),
			int(best.get("sessions_completed", 0))
		]


func _on_start_drill_pressed() -> void:
	Catalog.set_active_session(
		_selected_drill_id,
		_selected_player_name,
		_selected_difficulty,
		_selected_club,
		_active_diagnosis_reason,
		_is_suggested_mode,
		_active_diagnosis_evidence
	)
	SceneManager.change_scene(TRAINING_ARENA_SCENE)


func _on_back_pressed() -> void:
	SceneManager.change_scene(MAIN_MENU_SCENE)


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if _suggest_btn != null and is_instance_valid(_suggest_btn):
		_suggest_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/UIFocusGuard") and get_node("/root/UIFocusGuard").is_modal_active():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
