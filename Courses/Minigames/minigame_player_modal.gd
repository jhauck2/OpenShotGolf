extends CanvasLayer

signal players_changed(players: Array[Dictionary])
signal reset_match_requested
signal modal_closed

const PLAYER_COLORS: Array[Color] = [
	Color(0.20, 0.90, 1.00), # Neon Cyan (P1)
	Color(1.00, 0.75, 0.25), # Radiant Amber/Gold (P2)
	Color(0.25, 0.95, 0.45), # Emerald Lime (P3)
	Color(0.85, 0.35, 0.95), # Vivid Magenta/Purple (P4)
	Color(1.00, 0.35, 0.35), # Electric Coral/Red (P5)
	Color(1.00, 0.55, 0.15), # Vibrant Orange (P6)
	Color(0.35, 0.70, 1.00), # Sky Blue (P7)
	Color(1.00, 0.45, 0.75), # Hot Pink (P8)
]

var players: Array[Dictionary] = []
var min_players: int = 2
var max_players: int = 8
var total_targets: int = 8
var active_player_index: int = 0

var root_control: Control = null
var player_list_vbox: VBoxContainer = null
var registered_opt: OptionButton = null
var name_input: LineEdit = null
var add_btn: Button = null

static func get_player_color(index: int) -> Color:
	return PLAYER_COLORS[index % PLAYER_COLORS.size()]

static func create_player(p_name: String, p_index: int, target_count: int) -> Dictionary:
	var completed_arr: Array[bool] = []
	for i in range(target_count):
		completed_arr.append(false)
	return {
		"name": p_name,
		"color": get_player_color(p_index),
		"completed": completed_arr,
		"shots": 0
	}

static func init_default_players(target_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var mp_players = []
	var tree = Engine.get_main_loop()
	if tree is SceneTree and tree.root != null and tree.root.has_node("MultiplayerManager"):
		var mp = tree.root.get_node("MultiplayerManager")
		if mp != null and not mp.players.is_empty():
			mp_players = mp.players
	
	if mp_players.size() >= 2:
		for i in range(mp_players.size()):
			var p_name = mp_players[i].get("name", "Player %d" % (i + 1))
			result.append(create_player(p_name, i, target_count))
	elif mp_players.size() == 1:
		var p1 = mp_players[0].get("name", "Player 1")
		result.append(create_player(p1, 0, target_count))
		result.append(create_player("Player 2", 1, target_count))
	else:
		var p1 = "Player 1"
		if tree is SceneTree and tree.root != null and tree.root.has_node("MultiplayerManager"):
			var mp = tree.root.get_node("MultiplayerManager")
			if mp != null and mp.has_method("get_default_player_name"):
				p1 = mp.get_default_player_name()
		result.append(create_player(p1, 0, target_count))
		result.append(create_player("Player 2", 1, target_count))
	
	return result

func _ready() -> void:
	layer = 120
	_build_ui()

func open(p_players: Array[Dictionary], p_min_players: int = 2, p_total_targets: int = 8, p_active_idx: int = 0) -> void:
	players = p_players
	min_players = p_min_players
	total_targets = p_total_targets
	active_player_index = p_active_idx
	
	visible = true
	_refresh_players_list()
	_refresh_registered_dropdown()
	if name_input != null:
		name_input.clear()

func close_modal() -> void:
	visible = false
	emit_signal("modal_closed")
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_modal()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "RootControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	
	# Dimmed glass backdrop
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.05, 0.08, 0.78)
	root_control.add_child(backdrop)
	
	# Modal Dialog Panel
	var modal_panel = PanelContainer.new()
	modal_panel.name = "ModalPanel"
	modal_panel.custom_minimum_size = Vector2(620, 560)
	modal_panel.anchor_left = 0.5
	modal_panel.anchor_right = 0.5
	modal_panel.anchor_top = 0.5
	modal_panel.anchor_bottom = 0.5
	modal_panel.offset_left = -310
	modal_panel.offset_right = 310
	modal_panel.offset_top = -280
	modal_panel.offset_bottom = 280
	ThemeManager.apply_modal_style(modal_panel, 14)
	root_control.add_child(modal_panel)
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	modal_panel.add_child(margin_container)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	margin_container.add_child(main_vbox)
	
	# Header Row: Title & Close Button
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header_hbox)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "👥 MULTIPLAYER GOLFERS"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	title_vbox.add_child(title_lbl)
	
	var subtitle_lbl = Label.new()
	subtitle_lbl.text = "Add or remove golfers for turn-based competition"
	subtitle_lbl.add_theme_font_size_override("font_size", 13)
	subtitle_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	title_vbox.add_child(subtitle_lbl)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_nav_button_style(close_btn, 8)
	close_btn.pressed.connect(close_modal)
	header_hbox.add_child(close_btn)
	
	# Current Players Scroll List
	var list_lbl = Label.new()
	list_lbl.text = "ROSTER IN MATCH:"
	list_lbl.add_theme_font_size_override("font_size", 14)
	list_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	main_vbox.add_child(list_lbl)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	ThemeManager.apply_scroll_container_style(scroll, 10)
	main_vbox.add_child(scroll)
	
	player_list_vbox = VBoxContainer.new()
	player_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(player_list_vbox)
	
	# Add Player Section
	var add_section_panel = PanelContainer.new()
	ThemeManager.apply_data_panel_style(add_section_panel)
	main_vbox.add_child(add_section_panel)
	
	var add_margin = MarginContainer.new()
	add_margin.add_theme_constant_override("margin_left", 12)
	add_margin.add_theme_constant_override("margin_right", 12)
	add_margin.add_theme_constant_override("margin_top", 10)
	add_margin.add_theme_constant_override("margin_bottom", 10)
	add_section_panel.add_child(add_margin)
	
	var add_vbox = VBoxContainer.new()
	add_vbox.add_theme_constant_override("separation", 8)
	add_margin.add_child(add_vbox)
	
	var add_title = Label.new()
	add_title.text = "ADD GOLFER TO MATCH:"
	add_title.add_theme_font_size_override("font_size", 13)
	add_title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT)
	add_vbox.add_child(add_title)
	
	var add_controls_hbox = HBoxContainer.new()
	add_controls_hbox.add_theme_constant_override("separation", 10)
	add_vbox.add_child(add_controls_hbox)
	
	registered_opt = OptionButton.new()
	registered_opt.custom_minimum_size = Vector2(210, 46)
	registered_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	registered_opt.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_option_button_style(registered_opt, 14, Vector2(210, 46))
	registered_opt.item_selected.connect(_on_registered_opt_selected)
	add_controls_hbox.add_child(registered_opt)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Custom Name..."
	name_input.custom_minimum_size = Vector2(160, 46)
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_input_style(name_input, 6)
	name_input.text_submitted.connect(func(_t): _add_player_pressed())
	add_controls_hbox.add_child(name_input)
	
	add_btn = Button.new()
	add_btn.text = "➕ Add Golfer"
	add_btn.custom_minimum_size = Vector2(130, 46)
	add_btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_primary_button_style(add_btn, 6)
	add_btn.pressed.connect(_add_player_pressed)
	add_controls_hbox.add_child(add_btn)
	
	# Footer Buttons
	var footer_hbox = HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer_hbox)
	
	var reset_scores_btn = Button.new()
	reset_scores_btn.text = "🔄 Restart Match"
	reset_scores_btn.custom_minimum_size = Vector2(140, 46)
	reset_scores_btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_secondary_button_style(reset_scores_btn, 6)
	reset_scores_btn.pressed.connect(func():
		emit_signal("reset_match_requested")
		close_modal()
	)
	footer_hbox.add_child(reset_scores_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)
	
	var done_btn = Button.new()
	done_btn.text = "Done"
	done_btn.custom_minimum_size = Vector2(140, 46)
	done_btn.add_theme_font_size_override("font_size", 15)
	ThemeManager.apply_primary_button_style(done_btn, 6)
	done_btn.pressed.connect(close_modal)
	footer_hbox.add_child(done_btn)

func _refresh_players_list() -> void:
	if player_list_vbox == null:
		return
	
	for child in player_list_vbox.get_children():
		child.queue_free()
		
	for i in range(players.size()):
		var p = players[i]
		var p_name = str(p.get("name", "Player %d" % (i + 1)))
		var p_color = p.get("color", get_player_color(i))
		var completed_count = 0
		if p.has("completed") and p["completed"] is Array:
			completed_count = p["completed"].count(true)
		var shots_count = int(p.get("shots", 0))
		
		var row_panel = PanelContainer.new()
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.08, 0.12, 0.18, 0.85)
		row_style.border_width_left = 3
		row_style.border_color = p_color
		row_style.corner_radius_top_left = 6
		row_style.corner_radius_bottom_left = 6
		row_style.corner_radius_top_right = 6
		row_style.corner_radius_bottom_right = 6
		row_panel.add_theme_stylebox_override("panel", row_style)
		player_list_vbox.add_child(row_panel)
		
		var row_margin = MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 12)
		row_margin.add_theme_constant_override("margin_right", 12)
		row_margin.add_theme_constant_override("margin_top", 8)
		row_margin.add_theme_constant_override("margin_bottom", 8)
		row_panel.add_child(row_margin)
		
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 12)
		row_margin.add_child(row_hbox)
		
		# Player Pill / Badge
		var badge = Label.new()
		badge.text = " P%d " % (i + 1)
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color.BLACK)
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = p_color
		badge_style.corner_radius_top_left = 4
		badge_style.corner_radius_bottom_left = 4
		badge_style.corner_radius_top_right = 4
		badge_style.corner_radius_bottom_right = 4
		badge.add_theme_stylebox_override("normal", badge_style)
		row_hbox.add_child(badge)
		
		# Player Name
		var name_lbl = Label.new()
		name_lbl.text = p_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
		row_hbox.add_child(name_lbl)
		
		# Active Turn Indicator
		if i == active_player_index:
			var turn_badge = Label.new()
			turn_badge.text = "🎯 Current Turn"
			turn_badge.add_theme_font_size_override("font_size", 12)
			turn_badge.add_theme_color_override("font_color", p_color)
			row_hbox.add_child(turn_badge)
		
		# Progress Indicator
		var progress_lbl = Label.new()
		progress_lbl.text = "%d/%d completed (%d shots)" % [completed_count, total_targets, shots_count]
		progress_lbl.add_theme_font_size_override("font_size", 13)
		progress_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		row_hbox.add_child(progress_lbl)
		
		# Delete Button
		var del_btn = Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(36, 36)
		del_btn.add_theme_font_size_override("font_size", 14)
		if players.size() <= min_players:
			del_btn.disabled = true
			del_btn.tooltip_text = "Minimum %d players required" % min_players
			ThemeManager.apply_nav_button_style(del_btn, 6)
		else:
			ThemeManager.apply_danger_button_style(del_btn, 6)
			del_btn.pressed.connect(func(remove_idx = i):
				_remove_player(remove_idx)
			)
		row_hbox.add_child(del_btn)
	
	if add_btn != null:
		add_btn.disabled = (players.size() >= max_players)
		if players.size() >= max_players:
			add_btn.tooltip_text = "Maximum %d players reached" % max_players
		else:
			add_btn.tooltip_text = ""

func _refresh_registered_dropdown() -> void:
	if registered_opt == null:
		return
	
	registered_opt.clear()
	registered_opt.add_item("➕ Custom Name...", 0)
	
	var registered = []
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_method("get_registered_players"):
			registered = mp.get_registered_players()
	
	var existing_names = []
	for p in players:
		existing_names.append(str(p.get("name", "")).to_lower())
	
	var item_idx = 1
	for reg in registered:
		var reg_name = str(reg.get("name", ""))
		if not reg_name.is_empty() and not existing_names.has(reg_name.to_lower()):
			registered_opt.add_item(reg_name, item_idx)
			item_idx += 1
			
	registered_opt.selected = 0
	if name_input != null:
		name_input.visible = true

func _on_registered_opt_selected(index: int) -> void:
	if index == 0:
		name_input.visible = true
		name_input.call_deferred("grab_focus")
	else:
		name_input.visible = false

func _add_player_pressed() -> void:
	if players.size() >= max_players:
		return
		
	var chosen_name = ""
	if registered_opt.selected > 0:
		chosen_name = registered_opt.get_item_text(registered_opt.selected)
	else:
		chosen_name = name_input.text.strip_edges()
	
	if chosen_name.is_empty():
		chosen_name = "Player %d" % (players.size() + 1)
	
	# Handle duplicate names by appending a number
	var existing_names = []
	for p in players:
		existing_names.append(str(p.get("name", "")).to_lower())
	if existing_names.has(chosen_name.to_lower()):
		var suffix = 2
		var test_name = "%s (%d)" % [chosen_name, suffix]
		while existing_names.has(test_name.to_lower()):
			suffix += 1
			test_name = "%s (%d)" % [chosen_name, suffix]
		chosen_name = test_name
	
	var new_player = create_player(chosen_name, players.size(), total_targets)
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_method("get_player_handedness"):
			new_player["handedness"] = mp.get_player_handedness(chosen_name)
		if mp.has_method("get_player_ball_type"):
			new_player["ball_type"] = mp.get_player_ball_type(chosen_name)
	players.append(new_player)
	
	# Ensure registered persistently in MultiplayerManager
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_method("register_player"):
			mp.register_player(chosen_name)
			
	name_input.clear()
	_refresh_players_list()
	_refresh_registered_dropdown()
	emit_signal("players_changed", players)

func _remove_player(idx: int) -> void:
	if players.size() <= min_players or idx < 0 or idx >= players.size():
		return
		
	players.remove_at(idx)
	# Re-assign colors based on new indices
	for i in range(players.size()):
		players[i]["color"] = get_player_color(i)
		
	if active_player_index >= players.size():
		active_player_index = 0
		
	_refresh_players_list()
	_refresh_registered_dropdown()
	emit_signal("players_changed", players)
