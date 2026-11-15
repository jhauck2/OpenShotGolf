extends Control

@onready var player_list_vbox = VBoxContainer.new()
@onready var course_list = ItemList.new()
@onready var start_button = Button.new()
var preview_button = Button.new()
var delete_confirm_dialog: ConfirmationDialog

var available_courses: Array[Dictionary] = []
var players_to_add: Array[Dictionary] = []
var current_course_tees: Array[String] = ["Blue", "Red", "White", "Black", "Gold"]
var add_row_tee_opt: OptionButton = null
var player_tee_options: Array[OptionButton] = []

var selected_length: String = "Front 9, Back 9"
var front_9_selected: bool = true
var back_9_selected: bool = true
var extra_holes_selected: bool = false
var front_9_btn: Button
var back_9_btn: Button
var extra_holes_btn: Button

var active_course_tab: String = "Real" # "Real" or "Custom"
var real_tab_btn: Button
var custom_tab_btn: Button
var create_custom_btn: Button

var selected_game_mode: String = "Standard"
var mode_std_btn: Button
var mode_scramble_btn: Button
var mode_2v2_btn: Button
var mode_skins_btn: Button
var mode_closest_btn: Button
var mode_desc_lbl: Label
var team_assignments: Dictionary = {}

var selected_turn_order: String = "Stay Up"
var turn_stay_up_btn: Button
var turn_classic_btn: Button
var turn_full_hole_btn: Button
var turn_desc_lbl: Label

var quality_low_btn: Button
var quality_med_btn: Button
var quality_high_btn: Button
var quality_desc_lbl: Label

var wind_off_btn: Button
var wind_on_btn: Button

func _ready() -> void:
	# Build the setup screen dynamically
	name = "CoursePlaySetup"
	
	# Background Cabo Texture (matching history/practice screens)
	var bg_texture = TextureRect.new()
	bg_texture.name = "Background"
	bg_texture.texture = load("res://assets/images/menu/cabo_openfairway_bnw.png")
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
	bg_texture.anchor_left = 0.0
	bg_texture.anchor_right = 1.0
	bg_texture.anchor_top = 0.0
	bg_texture.anchor_bottom = 1.0
	bg_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bg_texture)
	
	# Dark semi-transparent color overlay for glassmorphism
	var glass_panel = ColorRect.new()
	glass_panel.color = Color(0.05, 0.08, 0.05, 0.82)
	glass_panel.anchor_left = 0.0
	glass_panel.anchor_right = 1.0
	glass_panel.anchor_top = 0.0
	glass_panel.anchor_bottom = 1.0
	add_child(glass_panel)
	
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 60)
	main_margin.add_theme_constant_override("margin_right", 60)
	main_margin.add_theme_constant_override("margin_top", 40)
	main_margin.add_theme_constant_override("margin_bottom", 40)
	main_margin.anchor_left = 0.0
	main_margin.anchor_right = 1.0
	main_margin.anchor_top = 0.0
	main_margin.anchor_bottom = 1.0
	add_child(main_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	main_margin.add_child(main_vbox)
	
	# Header with Title & Back Button
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "Course Play Setup"
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	header_hbox.add_child(title_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	var back_btn = Button.new()
	back_btn.text = "Main Menu"
	back_btn.icon = load("res://UI/MainMenu/images/menu.svg")
	back_btn.expand_icon = true
	back_btn.custom_minimum_size = Vector2(160, 48)
	back_btn.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_nav_button_style(back_btn)
	back_btn.pressed.connect(func(): SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn"))
	header_hbox.add_child(back_btn)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 50)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(main_hbox)
	
	# Left Column: Player Setup
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	left_vbox.add_theme_constant_override("separation", 20)
	main_hbox.add_child(left_vbox)
	
	var title = Label.new()
	title.text = "Player Setup (Multiplayer)"
	title.add_theme_font_size_override("font_size", 32)
	left_vbox.add_child(title)
	
	# Add player control row - enlarged for touch usability
	var add_row = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 10)
	
	var player_select_opt = OptionButton.new()
	ThemeManager.apply_option_button_style(player_select_opt, 22, Vector2(250, 56))
	add_row.add_child(player_select_opt)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Player Name"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.custom_minimum_size = Vector2(0, 56)
	name_input.add_theme_font_size_override("font_size", 24)
	ThemeManager.apply_input_style(name_input)
	add_row.add_child(name_input)
	
	# Helper to refresh the dropdown selection list
	var refresh_player_select = func():
		player_select_opt.clear()
		player_select_opt.add_item("New Player...", 0)
		var registered = MultiplayerManager.get_registered_players()
		for i in range(registered.size()):
			player_select_opt.add_item(registered[i].get("name", "Player"), i + 1)
		player_select_opt.selected = 0
		name_input.visible = true
	
	refresh_player_select.call()
	
	var tee_opt = OptionButton.new()
	add_row_tee_opt = tee_opt
	for t_idx in range(current_course_tees.size()):
		tee_opt.add_item(current_course_tees[t_idx], t_idx)
	ThemeManager.apply_option_button_style(tee_opt, 22, Vector2(160, 56))
	add_row.add_child(tee_opt)
	
	player_select_opt.item_selected.connect(func(index):
		if index == 0:
			name_input.visible = true
			name_input.call_deferred("grab_focus")
		else:
			name_input.visible = false
			var p_name = player_select_opt.get_item_text(index)
			var pref_tee = MultiplayerManager.get_player_preferred_tee(p_name)
			if not pref_tee.is_empty():
				for t_i in range(tee_opt.item_count):
					if tee_opt.get_item_text(t_i).to_lower() == pref_tee.to_lower():
						tee_opt.selected = t_i
						break
	)
	
	var add_btn = Button.new()
	add_btn.text = "Add Player"
	add_btn.custom_minimum_size = Vector2(180, 56)
	add_btn.add_theme_font_size_override("font_size", 24)
	ThemeManager.apply_primary_button_style(add_btn)
	add_btn.pressed.connect(func():
		var name_text = ""
		if player_select_opt.selected == 0:
			name_text = name_input.text.strip_edges()
			if name_text.is_empty():
				name_text = "Player " + str(players_to_add.size() + 1)
		else:
			name_text = player_select_opt.get_item_text(player_select_opt.selected)
			
		var tee_color = tee_opt.get_item_text(tee_opt.selected)
		_add_player_ui(name_text, tee_color)
		
		# Ensure registered persistently
		MultiplayerManager.register_player(name_text)
		
		name_input.clear()
		refresh_player_select.call()
	)
	add_row.add_child(add_btn)
	left_vbox.add_child(add_row)
	
	# Players list vbox container inside ScrollContainer
	var player_scroll = ScrollContainer.new()
	player_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_scroll.custom_minimum_size = Vector2(0, 140)
	ThemeManager.apply_scroll_container_style(player_scroll, 16)
	player_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_scroll.add_child(player_list_vbox)
	left_vbox.add_child(player_scroll)

	# Left Column Game Settings: Turn Order, Graphics Quality, Game Mode
	var turn_order_selector = _create_turn_order_selector()
	left_vbox.add_child(turn_order_selector)

	var quality_selector = _create_quality_selector()
	left_vbox.add_child(quality_selector)

	var game_mode_selector = _create_game_mode_selector()
	left_vbox.add_child(game_mode_selector)
	
	# Right Column: Course Select & Play
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	right_vbox.add_theme_constant_override("separation", 14)
	main_hbox.add_child(right_vbox)
	
	var course_title = Label.new()
	course_title.text = "Select Course"
	course_title.add_theme_font_size_override("font_size", 32)
	right_vbox.add_child(course_title)

	var tab_selector = _create_tab_selector()
	right_vbox.add_child(tab_selector)
	
	# Course list (expands to fill vertical room)
	course_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	course_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	course_list.custom_minimum_size = Vector2(0, 260)
	course_list.add_theme_font_size_override("font_size", 24)
	course_list.add_theme_constant_override("v_separation", 16)
	ThemeManager.apply_item_list_style(course_list)
	right_vbox.add_child(course_list)
	
	course_list.item_selected.connect(func(idx):
		_update_start_button()
		_update_course_length_options(idx)
	)
	course_list.item_activated.connect(func(_idx):
		if not start_button.disabled:
			_on_start_pressed()
	)
	_scan_available_courses()
	
	# Actions Row (placed directly below Course List)
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var download_btn = Button.new()
	download_btn.text = "Download Course"
	download_btn.custom_minimum_size = Vector2(0, 48)
	download_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	download_btn.add_theme_font_size_override("font_size", 19)
	download_btn.pressed.connect(func():
		var dialog_scene = load("res://Courses/OsmDownloadDialog/osm_download_dialog.tscn")
		if dialog_scene != null:
			var dialog = dialog_scene.instantiate()
			add_child(dialog)
			dialog.course_downloaded.connect(func(course_name):
				_scan_available_courses()
				_select_course_by_name(course_name)
			)
			dialog.tree_exited.connect(func():
				_scan_available_courses()
			)
	)
	action_row.add_child(download_btn)
	
	var delete_btn = Button.new()
	delete_btn.text = "Delete Course"
	delete_btn.custom_minimum_size = Vector2(0, 48)
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.add_theme_font_size_override("font_size", 19)
	delete_btn.pressed.connect(_on_delete_course_pressed)
	action_row.add_child(delete_btn)
	
	# Confirmation dialog for course deletion
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "Confirm Delete"
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete this course?"
	delete_confirm_dialog.min_size = Vector2(480, 180)
	ThemeManager.apply_dialog_style(delete_confirm_dialog)
	add_child(delete_confirm_dialog)
	
	preview_button.text = "Preview Course"
	preview_button.custom_minimum_size = Vector2(0, 48)
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_button.add_theme_font_size_override("font_size", 19)
	ThemeManager.apply_secondary_button_style(preview_button)
	preview_button.disabled = true
	preview_button.pressed.connect(_on_preview_pressed)
	action_row.add_child(preview_button)

	start_button.text = "Play Course"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.add_theme_font_size_override("font_size", 19)
	ThemeManager.apply_primary_button_style(start_button)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	action_row.add_child(start_button)
	right_vbox.add_child(action_row)

	# Connect focus neighbors between tabs, course_list, and action buttons
	if real_tab_btn != null and is_instance_valid(real_tab_btn):
		course_list.focus_neighbor_top = course_list.get_path_to(real_tab_btn)
		real_tab_btn.focus_neighbor_bottom = real_tab_btn.get_path_to(course_list)
	if custom_tab_btn != null and is_instance_valid(custom_tab_btn):
		custom_tab_btn.focus_neighbor_bottom = custom_tab_btn.get_path_to(course_list)
	if create_custom_btn != null and is_instance_valid(create_custom_btn):
		create_custom_btn.focus_neighbor_bottom = create_custom_btn.get_path_to(course_list)
	course_list.focus_neighbor_bottom = course_list.get_path_to(download_btn)
	download_btn.focus_neighbor_top = download_btn.get_path_to(course_list)
	delete_btn.focus_neighbor_top = delete_btn.get_path_to(course_list)
	preview_button.focus_neighbor_top = preview_button.get_path_to(course_list)
	# Right Column Settings: Hole Selection & Wind Simulation (Shared Row) and Green Speed
	var options_hbox = HBoxContainer.new()
	options_hbox.add_theme_constant_override("separation", 14)
	options_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var length_selector = _create_length_selector()
	length_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_hbox.add_child(length_selector)

	var wind_selector = _create_wind_selector()
	wind_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_hbox.add_child(wind_selector)

	right_vbox.add_child(options_hbox)

	var selected_items = course_list.get_selected_items()
	if not selected_items.is_empty():
		_update_course_length_options(selected_items[0])

	var green_speed_selector = _create_green_speed_selector()
	right_vbox.add_child(green_speed_selector)
	
	# Add default initial player (player with biggest play history, first in list, or 'Player 1' fallback)
	var default_player = MultiplayerManager.get_default_player_name()
	var def_tee = MultiplayerManager.get_player_preferred_tee(default_player)
	if def_tee.is_empty():
		def_tee = "Blue"
	_add_player_ui(default_player, def_tee)
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/KeybindingManager"):
		var km = get_node("/root/KeybindingManager")
		km.focus_first_control(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg.is_modal_active():
			return
	if event.is_action_pressed("ui_cancel"):
		for child in get_children():
			if (child is ConfirmationDialog or child is AcceptDialog) and child.visible:
				child.visible = false
				get_viewport().set_input_as_handled()
				return
			if child.is_visible_in_tree() and (child.name.contains("Dialog") or child.name.contains("Preview")):
				child.queue_free()
				get_viewport().set_input_as_handled()
				return
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
		get_viewport().set_input_as_handled()


func _add_player_ui(p_name: String, tee: String = "") -> void:
	var idx = players_to_add.size()
	var avatar_path = MultiplayerManager.get_player_avatar(p_name)
	var email = MultiplayerManager.get_player_email(p_name)
	var resolved_tee = tee
	if resolved_tee.is_empty():
		resolved_tee = MultiplayerManager.get_player_preferred_tee(p_name)
		if resolved_tee.is_empty():
			resolved_tee = "Blue"
	var hand = MultiplayerManager.get_player_handedness(p_name)
	var bg = MultiplayerManager.get_player_ball_graphic(p_name)
	var player_data = {"name": p_name, "tee": resolved_tee, "avatar": avatar_path, "email": email, "handedness": hand, "ball_graphic": bg}
	players_to_add.append(player_data)
	
	var row = HBoxContainer.new()
	row.name = "PlayerRow_" + str(idx)
	row.add_theme_constant_override("separation", 20)
	
	if not avatar_path.is_empty() and ResourceLoader.exists(avatar_path):
		var avatar_rect = TextureRect.new()
		avatar_rect.texture = load(avatar_path)
		avatar_rect.custom_minimum_size = Vector2(44, 44)
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(avatar_rect)
	else:
		var badge = PanelContainer.new()
		badge.custom_minimum_size = Vector2(40, 40)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var badge_style = StyleBoxFlat.new()
		var p_color = MultiplayerManager.player_colors[idx % MultiplayerManager.player_colors.size()]
		badge_style.bg_color = p_color
		badge_style.corner_radius_top_left = 20
		badge_style.corner_radius_top_right = 20
		badge_style.corner_radius_bottom_left = 20
		badge_style.corner_radius_bottom_right = 20
		badge.add_theme_stylebox_override("panel", badge_style)
		var badge_lbl = Label.new()
		badge_lbl.text = p_name.substr(0, 1).to_upper()
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 20)
		badge.add_child(badge_lbl)
		row.add_child(badge)

	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	name_vbox.add_theme_constant_override("separation", 2)

	var name_lbl = Label.new()
	name_lbl.text = p_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_vbox.add_child(name_lbl)

	var hand_sub_lbl = Label.new()
	hand_sub_lbl.text = "🏌️ " + ("Left-Handed" if hand == 1 else "Right-Handed")
	hand_sub_lbl.add_theme_font_size_override("font_size", 13)
	hand_sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75, 0.8))
	name_vbox.add_child(hand_sub_lbl)

	row.add_child(name_vbox)
	
	var player_tee_opt = OptionButton.new()
	player_tee_opt.set_meta("player_data", player_data)
	player_tee_options.append(player_tee_opt)
	for t_idx in range(current_course_tees.size()):
		player_tee_opt.add_item(current_course_tees[t_idx], t_idx)
	player_tee_opt.selected = 0
	for t_idx in range(player_tee_opt.item_count):
		if player_tee_opt.get_item_text(t_idx).to_lower() == resolved_tee.to_lower():
			player_tee_opt.selected = t_idx
			break
	ThemeManager.apply_option_button_style(player_tee_opt, 20, Vector2(160, 52))
	player_tee_opt.item_selected.connect(func(sel_idx):
		player_data["tee"] = player_tee_opt.get_item_text(sel_idx)
	)
	row.add_child(player_tee_opt)
	
	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.custom_minimum_size = Vector2(140, 56)
	remove_btn.add_theme_font_size_override("font_size", 24)
	ThemeManager.apply_danger_button_style(remove_btn)
	remove_btn.pressed.connect(func():
		players_to_add.erase(player_data)
		player_tee_options.erase(player_tee_opt)
		row.queue_free()
		_update_start_button()
	)
	row.add_child(remove_btn)
	
	player_list_vbox.add_child(row)
	_update_start_button()


func _update_start_button() -> void:
	var has_course = not course_list.get_selected_items().is_empty()
	start_button.disabled = players_to_add.is_empty() or not has_course
	if preview_button != null:
		preview_button.disabled = not has_course


func _on_preview_pressed() -> void:
	var selected_items = course_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	var selected_idx = selected_items[0]
	var course_data = course_list.get_item_metadata(selected_idx)
	var config_path = course_data.get("config_path", "")
	var scene_path = course_data.get("scene_path", "")
	
	var dialog_scene = load("res://UI/CoursePreviewDialog/course_preview_dialog.tscn")
	if dialog_scene != null:
		var dialog = dialog_scene.instantiate()
		add_child(dialog)
		dialog.setup(config_path, scene_path)


func _scan_available_courses() -> void:
	course_list.clear()
	available_courses.clear()
	
	var validated: Array[Dictionary] = []
	_scan_dir("user://courses", validated)
	
	for course in validated:
		var is_custom: bool = course.get("is_custom", false)
		if active_course_tab == "Real" and is_custom:
			continue
		elif active_course_tab == "Custom" and not is_custom:
			continue

		var item_idx = course_list.get_item_count()
		course_list.add_item(course["title"])
		course_list.set_item_metadata(item_idx, course)
		available_courses.append(course)

	if course_list.get_item_count() > 0:
		if course_list.get_selected_items().is_empty():
			course_list.select(0)
			_update_course_length_options(0)

	_update_start_button()


func _create_tab_selector() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	real_tab_btn = Button.new()
	real_tab_btn.text = "Real Courses"
	real_tab_btn.custom_minimum_size = Vector2(160, 48)
	real_tab_btn.add_theme_font_size_override("font_size", 20)

	custom_tab_btn = Button.new()
	custom_tab_btn.text = "Custom Courses"
	custom_tab_btn.custom_minimum_size = Vector2(160, 48)
	custom_tab_btn.add_theme_font_size_override("font_size", 20)

	create_custom_btn = Button.new()
	create_custom_btn.text = "+ Create Custom Course"
	create_custom_btn.custom_minimum_size = Vector2(230, 48)
	create_custom_btn.add_theme_font_size_override("font_size", 20)

	real_tab_btn.pressed.connect(func(): _switch_course_tab("Real"))
	custom_tab_btn.pressed.connect(func(): _switch_course_tab("Custom"))
	create_custom_btn.pressed.connect(_on_create_custom_pressed)

	hbox.add_child(real_tab_btn)
	hbox.add_child(custom_tab_btn)
	hbox.add_child(create_custom_btn)

	_update_tab_button_styles()
	return hbox


func _switch_course_tab(tab: String) -> void:
	active_course_tab = tab
	_update_tab_button_styles()
	_scan_available_courses()


func _update_tab_button_styles() -> void:
	if real_tab_btn != null:
		_style_seg_button(real_tab_btn, "left", active_course_tab == "Real")
	if custom_tab_btn != null:
		_style_seg_button(custom_tab_btn, "right", active_course_tab == "Custom")
	if create_custom_btn != null:
		apply_button_style(create_custom_btn, Color(0.2, 0.55, 0.35))


func _on_create_custom_pressed() -> void:
	var dialog_scene = load("res://UI/CustomCourseCreator/custom_course_creator.tscn")
	if dialog_scene != null:
		var dialog = dialog_scene.instantiate()
		add_child(dialog)
		dialog.course_created.connect(func(_new_course):
			_switch_course_tab("Custom")
		)



func _scan_dir(dir_path: String, validated: Array[Dictionary]) -> void:
	var path_to_scan = dir_path
	if not DirAccess.dir_exists_absolute(path_to_scan):
		var global_dir = ProjectSettings.globalize_path(dir_path)
		if DirAccess.dir_exists_absolute(global_dir):
			path_to_scan = global_dir
		else:
			return
	var dir_names := DirAccess.get_directories_at(path_to_scan)
	if dir_names.is_empty() and path_to_scan == dir_path:
		var global_dir = ProjectSettings.globalize_path(dir_path)
		if DirAccess.dir_exists_absolute(global_dir):
			dir_names = DirAccess.get_directories_at(global_dir)
			if not dir_names.is_empty():
				path_to_scan = global_dir

	for dir_name in dir_names:
		if not dir_name.begins_with("."):
			var lower_name = dir_name.to_lower()
			if lower_name == "airways" or lower_name == "dragonfly" or lower_name == "dragon_fly":
				continue
			var result: Dictionary = CourseValidator.validate(path_to_scan, dir_name)
			if not result.is_empty():
				result["dir_name"] = dir_name
				validated.append(result)


func _select_course_by_name(target_name: String) -> void:
	if target_name.is_empty():
		return
	for i in range(course_list.get_item_count()):
		var item_text = course_list.get_item_text(i)
		var meta = course_list.get_item_metadata(i)
		var meta_title = meta.get("title", "") if typeof(meta) == TYPE_DICTIONARY else ""
		if item_text.nocasecmp_to(target_name) == 0 or meta_title.nocasecmp_to(target_name) == 0:
			course_list.select(i)
			course_list.ensure_current_is_visible()
			_update_course_length_options(i)
			_update_start_button()
			break


func _on_delete_course_pressed() -> void:
	var selected_items = course_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("[CoursePlaySetup] No course selected to delete.")
		return
	
	var selected_idx = selected_items[0]
	var course_data = course_list.get_item_metadata(selected_idx)
	var config_path: String = course_data.get("config_path", "")
	var course_dir: String = config_path.get_base_dir()
	
	# Only allow deleting user-downloaded courses, not built-in ones
	if not course_dir.begins_with("user://courses/"):
		push_warning("[CoursePlaySetup] Cannot delete built-in course: " + course_dir)
		return
	
	var course_title: String = course_data.get("title", course_dir)
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete the course '" + course_title + "'?\nThis cannot be undone."
	
	# Disconnect any previous confirmation to avoid stacking connections
	if delete_confirm_dialog.confirmed.is_connected(_confirm_delete_course):
		delete_confirm_dialog.confirmed.disconnect(_confirm_delete_course)
	delete_confirm_dialog.confirmed.connect(_confirm_delete_course.bind(course_dir, course_title))
	delete_confirm_dialog.popup_centered()


func _confirm_delete_course(course_dir: String, course_title: String) -> void:
	# Disconnect so it doesn't fire again for the next deletion
	if delete_confirm_dialog.confirmed.is_connected(_confirm_delete_course):
		delete_confirm_dialog.confirmed.disconnect(_confirm_delete_course)
	
	_delete_course_dir(course_dir)
	print("[CoursePlaySetup] Deleted course '" + course_title + "' at: " + course_dir)
	_scan_available_courses()


func _delete_course_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var files := DirAccess.get_files_at(dir_path)
	for f in files:
		DirAccess.remove_absolute(dir_path.path_join(f))
	var subdirs := DirAccess.get_directories_at(dir_path)
	for d in subdirs:
		_delete_course_dir(dir_path.path_join(d))
	DirAccess.remove_absolute(dir_path)


func _on_start_pressed() -> void:
	var selected_items = course_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	var selected_idx = selected_items[0]
	var course_data = course_list.get_item_metadata(selected_idx)
	
	var scene_path = course_data.get("scene_path", "")
	var config_path = course_data.get("config_path", "")
	
	# Load config so MultiplayerManager can initialize hole/tee details
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("[CoursePlaySetup] Failed to read course config JSON: " + config_path)
		return
		
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[CoursePlaySetup] Invalid course JSON: " + config_path)
		return
		
	# Setup MultiplayerManager
	if GlobalSettings != null:
		if GlobalSettings.range_settings != null and GlobalSettings.range_settings.turn_order_mode != null:
			GlobalSettings.range_settings.turn_order_mode.set_value(selected_turn_order)
		GlobalSettings.start_round_wind(true)
	get_node("/root/MultiplayerManager").setup_game(players_to_add, parsed, scene_path, config_path, selected_length, selected_game_mode, team_assignments, selected_turn_order)
	get_node("/root/MultiplayerManager").start_hole()
	
	# Ready launch monitor for course play
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("set_ready"):
			lm.call("set_ready")

	# Load course
	SceneManager.load_course(scene_path, config_path)


func _create_game_mode_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.15, 0.65)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.35, 0.4)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Game Mode:"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var seg_hbox = HBoxContainer.new()
	seg_hbox.add_theme_constant_override("separation", 0)
	hbox.add_child(seg_hbox)

	mode_std_btn = Button.new()
	mode_std_btn.text = "Standard"
	mode_std_btn.custom_minimum_size = Vector2(95, 44)
	mode_std_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(mode_std_btn)

	mode_scramble_btn = Button.new()
	mode_scramble_btn.text = "Scramble"
	mode_scramble_btn.custom_minimum_size = Vector2(95, 44)
	mode_scramble_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(mode_scramble_btn)

	mode_2v2_btn = Button.new()
	mode_2v2_btn.text = "2v2 Scramble"
	mode_2v2_btn.custom_minimum_size = Vector2(115, 44)
	mode_2v2_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(mode_2v2_btn)

	mode_skins_btn = Button.new()
	mode_skins_btn.text = "Skins"
	mode_skins_btn.custom_minimum_size = Vector2(75, 44)
	mode_skins_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(mode_skins_btn)

	mode_closest_btn = Button.new()
	mode_closest_btn.text = "Closest to Pin"
	mode_closest_btn.custom_minimum_size = Vector2(125, 44)
	mode_closest_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(mode_closest_btn)

	mode_desc_lbl = Label.new()
	mode_desc_lbl.add_theme_font_size_override("font_size", 14)
	mode_desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
	mode_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mode_desc_lbl)

	mode_std_btn.pressed.connect(func(): _select_game_mode("Standard"))
	mode_scramble_btn.pressed.connect(func(): _select_game_mode("Scramble"))
	mode_2v2_btn.pressed.connect(func(): _select_game_mode("2v2 Scramble"))
	mode_skins_btn.pressed.connect(func(): _select_game_mode("Skins"))
	mode_closest_btn.pressed.connect(func(): _select_game_mode("Closest to Pin"))

	_select_game_mode("Standard")
	return panel

func _select_game_mode(mode_name: String) -> void:
	selected_game_mode = mode_name
	_style_seg_button(mode_std_btn, "left", selected_game_mode == "Standard")
	_style_seg_button(mode_scramble_btn, "middle", selected_game_mode == "Scramble")
	_style_seg_button(mode_2v2_btn, "middle", selected_game_mode == "2v2 Scramble")
	_style_seg_button(mode_skins_btn, "middle", selected_game_mode == "Skins")
	_style_seg_button(mode_closest_btn, "right", selected_game_mode == "Closest to Pin")

	match selected_game_mode:
		"Standard":
			mode_desc_lbl.text = "Standard: Traditional stroke play. Everyone plays their own ball from tee to hole."
		"Scramble":
			mode_desc_lbl.text = "Scramble: Everyone hits the ball and then the closest to the hole is where everyone hits the next shot from."
		"2v2 Scramble":
			mode_desc_lbl.text = "2v2 Scramble: Group makes 2 teams (Team 1 vs Team 2). Scramble works off your teammate's shot."
		"Skins":
			mode_desc_lbl.text = "Skins: Each hole is worth 1 Skin for the lowest score. Ties carry over to the next hole!"
		"Closest to Pin":
			mode_desc_lbl.text = "Closest to Pin: Each player takes one shot per hole. Whoever is closest to the pin gets 1 point, and everyone else gets 0. Highest score at the end wins!"


func _create_length_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.15, 0.65)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.35, 0.4)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Select Holes:"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	# Segmented buttons container
	var seg_hbox = HBoxContainer.new()
	seg_hbox.add_theme_constant_override("separation", 0)
	seg_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(seg_hbox)

	front_9_btn = Button.new()
	front_9_btn.text = "Front 9"
	front_9_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_9_btn.custom_minimum_size = Vector2(75, 42)
	front_9_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(front_9_btn)

	back_9_btn = Button.new()
	back_9_btn.text = "Back 9"
	back_9_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_9_btn.custom_minimum_size = Vector2(75, 42)
	back_9_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(back_9_btn)

	extra_holes_btn = Button.new()
	extra_holes_btn.text = "Extra Holes"
	extra_holes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extra_holes_btn.custom_minimum_size = Vector2(75, 42)
	extra_holes_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(extra_holes_btn)

	# Style buttons and setup connections
	front_9_btn.pressed.connect(func(): _toggle_length("Front 9"))
	back_9_btn.pressed.connect(func(): _toggle_length("Back 9"))
	extra_holes_btn.pressed.connect(func(): _toggle_length("Extra Holes"))

	_update_length_button_styles()
	return panel


func _create_turn_order_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.15, 0.65)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.35, 0.4)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Turn Order:"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var seg_hbox = HBoxContainer.new()
	seg_hbox.add_theme_constant_override("separation", 0)
	hbox.add_child(seg_hbox)

	turn_stay_up_btn = Button.new()
	turn_stay_up_btn.text = "Stay Up"
	turn_stay_up_btn.custom_minimum_size = Vector2(95, 44)
	turn_stay_up_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(turn_stay_up_btn)

	turn_classic_btn = Button.new()
	turn_classic_btn.text = "Classic"
	turn_classic_btn.custom_minimum_size = Vector2(95, 44)
	turn_classic_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(turn_classic_btn)

	turn_full_hole_btn = Button.new()
	turn_full_hole_btn.text = "Full Hole"
	turn_full_hole_btn.custom_minimum_size = Vector2(100, 44)
	turn_full_hole_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(turn_full_hole_btn)

	turn_desc_lbl = Label.new()
	turn_desc_lbl.add_theme_font_size_override("font_size", 14)
	turn_desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
	turn_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(turn_desc_lbl)

	turn_stay_up_btn.pressed.connect(func(): _select_turn_order("Stay Up"))
	turn_classic_btn.pressed.connect(func(): _select_turn_order("Classic"))
	turn_full_hole_btn.pressed.connect(func(): _select_turn_order("Full Hole"))

	var initial_mode = "Stay Up"
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.turn_order_mode != null:
		initial_mode = GlobalSettings.range_settings.turn_order_mode.value
	_select_turn_order(initial_mode)
	return panel


func _select_turn_order(mode_name: String) -> void:
	selected_turn_order = mode_name
	_style_seg_button(turn_stay_up_btn, "left", selected_turn_order == "Stay Up")
	_style_seg_button(turn_classic_btn, "middle", selected_turn_order == "Classic")
	_style_seg_button(turn_full_hole_btn, "right", selected_turn_order == "Full Hole")

	match selected_turn_order:
		"Stay Up":
			turn_desc_lbl.text = "Stay Up (Default): All players tee off first (never repeat hit off teebox). The furthest player hits next and stays up to hit again if still furthest or <= 35% of club average (only on green if all on green)."
		"Classic":
			turn_desc_lbl.text = "Classic: Whichever player is currently furthest from the pin always hits next."
		"Full Hole":
			turn_desc_lbl.text = "Full Hole: The player with honors plays their entire hole from tee to cup, followed by the next player."


func _create_quality_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.15, 0.65)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.35, 0.4)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Graphics Quality:"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var seg_hbox = HBoxContainer.new()
	seg_hbox.add_theme_constant_override("separation", 0)
	hbox.add_child(seg_hbox)

	quality_low_btn = Button.new()
	quality_low_btn.text = "Low (Fast)"
	quality_low_btn.custom_minimum_size = Vector2(105, 44)
	quality_low_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(quality_low_btn)

	quality_med_btn = Button.new()
	quality_med_btn.text = "Medium (PBR)"
	quality_med_btn.custom_minimum_size = Vector2(115, 44)
	quality_med_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(quality_med_btn)

	quality_high_btn = Button.new()
	quality_high_btn.text = "High (Realistic)"
	quality_high_btn.custom_minimum_size = Vector2(125, 44)
	quality_high_btn.add_theme_font_size_override("font_size", 16)
	if MobilePerformance.is_mobile():
		quality_high_btn.visible = false
	else:
		seg_hbox.add_child(quality_high_btn)

	quality_desc_lbl = Label.new()
	quality_desc_lbl.add_theme_font_size_override("font_size", 14)
	quality_desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
	quality_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(quality_desc_lbl)

	quality_low_btn.pressed.connect(func(): _select_quality("Low"))
	quality_med_btn.pressed.connect(func(): _select_quality("Medium"))
	quality_high_btn.pressed.connect(func(): _select_quality("High"))

	var current_q = "Low"
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("graphics_quality"):
		current_q = GlobalSettings.range_settings.settings["graphics_quality"].value
	if MobilePerformance.is_mobile() and current_q == "High":
		current_q = "Medium"
	_select_quality(current_q)
	return panel


func _select_quality(q_name: String) -> void:
	if MobilePerformance.is_mobile() and q_name == "High":
		q_name = "Medium"

	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("graphics_quality"):
		GlobalSettings.range_settings.settings["graphics_quality"].set_value(q_name)
		GlobalSettings.save_settings()

	_style_seg_button(quality_low_btn, "left", q_name == "Low")
	if MobilePerformance.is_mobile():
		_style_seg_button(quality_med_btn, "right", q_name == "Medium")
	else:
		_style_seg_button(quality_med_btn, "middle", q_name == "Medium")
		_style_seg_button(quality_high_btn, "right", q_name == "High")

	if q_name == "Low":
		quality_desc_lbl.text = "Low (Fast): Stylized stippled turf with clear high-contrast slope shading. Optimized for mobile and lower-end hardware."
	elif q_name == "Medium":
		quality_desc_lbl.text = "Medium (PBR): Balanced 27-texture PBR terrain splatting, standard foliage, and 4-split cascaded shadows."
	else:
		quality_desc_lbl.text = "High (Realistic): Photorealistic turf with micro-blade detail, organic bunker transitions, natural color variegation, 3D translucent trees, and atmospheric lighting."


func _create_wind_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.15, 0.65)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.35, 0.4)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Wind:"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var seg_hbox = HBoxContainer.new()
	seg_hbox.add_theme_constant_override("separation", 0)
	seg_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(seg_hbox)

	wind_off_btn = Button.new()
	wind_off_btn.text = "Disabled"
	wind_off_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wind_off_btn.custom_minimum_size = Vector2(75, 42)
	wind_off_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(wind_off_btn)

	wind_on_btn = Button.new()
	wind_on_btn.text = "Enabled"
	wind_on_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wind_on_btn.custom_minimum_size = Vector2(75, 42)
	wind_on_btn.add_theme_font_size_override("font_size", 16)
	seg_hbox.add_child(wind_on_btn)

	wind_off_btn.pressed.connect(func(): _select_wind(false))
	wind_on_btn.pressed.connect(func(): _select_wind(true))

	var current_wind = false
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("wind_enabled"):
		current_wind = bool(GlobalSettings.range_settings.wind_enabled.value)
	_select_wind(current_wind)
	return panel


func _create_green_speed_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.15, 0.65)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.35, 0.4)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 3
	panel_style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Green Speed:"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 5.0
	slider.max_value = 16.0
	slider.step = 0.5
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("green_speed"):
		slider.value = GlobalSettings.range_settings.green_speed.value
	else:
		slider.value = 10.0
	slider.custom_minimum_size = Vector2(110, 36 if MobilePerformance.is_mobile() else 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ThemeManager.apply_slider_style(slider, 36 if MobilePerformance.is_mobile() else 24, 110)
	hbox.add_child(slider)

	var val_lbl = Label.new()
	val_lbl.text = "%.1f" % slider.value
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.custom_minimum_size = Vector2(36, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(val_lbl)

	slider.value_changed.connect(func(val):
		if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("green_speed"):
			GlobalSettings.range_settings.green_speed.set_value(val)
		val_lbl.text = "%.1f" % val
	)

	hbox.add_child(VSeparator.new())
	var pin_check = CheckBox.new()
	pin_check.text = "Random Pin"
	pin_check.add_theme_font_size_override("font_size", 16)
	pin_check.button_pressed = true
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("random_pin_enabled"):
		pin_check.button_pressed = bool(GlobalSettings.range_settings.random_pin_enabled.value)
	pin_check.toggled.connect(func(on):
		if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("random_pin_enabled"):
			GlobalSettings.range_settings.random_pin_enabled.set_value(on)
			GlobalSettings.save_settings()
	)
	hbox.add_child(pin_check)

	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("green_speed"):
		GlobalSettings.range_settings.green_speed.setting_changed.connect(func(val):
			if slider != null and is_instance_valid(slider) and not is_equal_approx(slider.value, val):
				slider.value = val
			if val_lbl != null and is_instance_valid(val_lbl):
				val_lbl.text = "%.1f" % val
		)

	return panel


func _select_wind(enabled: bool) -> void:
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("wind_enabled"):
		GlobalSettings.range_settings.wind_enabled.set_value(enabled)
		GlobalSettings.save_settings()

	if wind_off_btn != null and wind_on_btn != null:
		_style_seg_button(wind_off_btn, "left", not enabled)
		_style_seg_button(wind_on_btn, "right", enabled)


func _style_seg_button(btn: Button, position: String, active: bool) -> void:
	var style = StyleBoxFlat.new()
	if btn.disabled:
		style.bg_color = Color(0.08, 0.08, 0.08, 0.3)
		style.border_color = Color(0.15, 0.15, 0.15, 0.2)
	elif active:
		style.bg_color = Color(0.18, 0.45, 0.35, 0.95) # active green
		style.border_color = Color(0.35, 0.8, 0.6, 0.8)
	else:
		style.bg_color = Color(0.1, 0.12, 0.16, 0.6)
		style.border_color = Color(0.2, 0.25, 0.3, 0.5)
	
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1

	if position == "left":
		style.corner_radius_top_left = 8
		style.corner_radius_bottom_left = 8
	elif position == "right":
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style.duplicate() if active else _get_hover_style(style))
	btn.add_theme_stylebox_override("pressed", style)
	
	if btn.disabled:
		btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.35))
	elif active:
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))


func _get_hover_style(base_style: StyleBoxFlat) -> StyleBoxFlat:
	var hover = base_style.duplicate()
	hover.bg_color = base_style.bg_color.lightened(0.12)
	hover.border_color = base_style.border_color.lightened(0.12)
	return hover


func _get_selected_length_string() -> String:
	var parts: Array[String] = []
	if front_9_selected:
		parts.append("Front 9")
	if back_9_selected and not back_9_btn.disabled:
		parts.append("Back 9")
	if extra_holes_selected and not extra_holes_btn.disabled:
		parts.append("Extra Holes")
	if parts.is_empty():
		parts.append("Front 9")
	return ", ".join(parts)


func _update_length_button_styles() -> void:
	selected_length = _get_selected_length_string()
	if front_9_btn != null and is_instance_valid(front_9_btn):
		_style_seg_button(front_9_btn, "left", front_9_selected)
	if back_9_btn != null and is_instance_valid(back_9_btn):
		_style_seg_button(back_9_btn, "middle", back_9_selected and not back_9_btn.disabled)
	if extra_holes_btn != null and is_instance_valid(extra_holes_btn):
		_style_seg_button(extra_holes_btn, "right", extra_holes_selected and not extra_holes_btn.disabled)


func _toggle_length(segment: String) -> void:
	if segment == "Front 9":
		if front_9_selected:
			var can_deselect = (back_9_selected and not back_9_btn.disabled) or (extra_holes_selected and not extra_holes_btn.disabled)
			if can_deselect:
				front_9_selected = false
		else:
			front_9_selected = true
	elif segment == "Back 9":
		if back_9_btn.disabled:
			return
		if back_9_selected:
			var can_deselect = front_9_selected or (extra_holes_selected and not extra_holes_btn.disabled)
			if can_deselect:
				back_9_selected = false
		else:
			back_9_selected = true
	elif segment == "Extra Holes":
		if extra_holes_btn.disabled:
			return
		if extra_holes_selected:
			var can_deselect = front_9_selected or (back_9_selected and not back_9_btn.disabled)
			if can_deselect:
				extra_holes_selected = false
		else:
			extra_holes_selected = true

	_update_length_button_styles()


func _update_course_length_options(idx: int) -> void:
	if back_9_btn == null or not is_instance_valid(back_9_btn):
		return
	if extra_holes_btn == null or not is_instance_valid(extra_holes_btn):
		return
	var course_data = course_list.get_item_metadata(idx)
	if course_data == null:
		return
	var config_path: String = course_data.get("config_path", "")
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			var holes = parsed.get("Hole Info", {})
			var num_holes = holes.keys().size()
			var has_extra = false
			var max_hole_num = 0
			for h_id in holes.keys():
				var h_num = MultiplayerManager.get_hole_number_from_id(str(h_id))
				if h_num > max_hole_num:
					max_hole_num = h_num
				if h_num >= 19:
					has_extra = true
			if num_holes > 18 or max_hole_num >= 19:
				has_extra = true

			if num_holes < 10 and max_hole_num < 10:
				back_9_btn.disabled = true
				back_9_selected = false
				extra_holes_btn.disabled = true
				extra_holes_selected = false
				front_9_selected = true
			elif num_holes < 18 and max_hole_num < 18 and not has_extra:
				back_9_btn.disabled = false
				extra_holes_btn.disabled = true
				extra_holes_selected = false
				front_9_selected = true
				back_9_selected = false
			else:
				# Course has at least 18 holes (or has extra holes)
				back_9_btn.disabled = false
				front_9_selected = true
				back_9_selected = true
				extra_holes_selected = false
				extra_holes_btn.disabled = not has_extra

			_update_length_button_styles()

			var course_info = parsed.get("Course Info", {})
			var tees_raw = course_info.get("Tee Colors", [])
			var detected_tees: Array[String] = []
			if tees_raw is Array:
				for tc in tees_raw:
					var tc_str = str(tc).strip_edges()
					if not tc_str.is_empty() and not detected_tees.has(tc_str):
						detected_tees.append(tc_str)
			if detected_tees.is_empty():
				for h in holes.values():
					if h is Dictionary and h.has("Tee Boxes"):
						for k in h["Tee Boxes"].keys():
							var k_str = str(k).strip_edges()
							if not k_str.is_empty() and not detected_tees.has(k_str):
								detected_tees.append(k_str)
			if not detected_tees.is_empty():
				current_course_tees = detected_tees
			else:
				current_course_tees = ["Blue", "Red", "White", "Black", "Gold"]
			_refresh_tee_dropdowns()


func _refresh_tee_dropdowns() -> void:
	if add_row_tee_opt != null and is_instance_valid(add_row_tee_opt):
		var prev_sel = add_row_tee_opt.get_item_text(add_row_tee_opt.selected) if add_row_tee_opt.selected >= 0 else ""
		add_row_tee_opt.clear()
		for i in range(current_course_tees.size()):
			add_row_tee_opt.add_item(current_course_tees[i], i)
		var found = false
		for i in range(add_row_tee_opt.item_count):
			if add_row_tee_opt.get_item_text(i).to_lower() == prev_sel.to_lower():
				add_row_tee_opt.selected = i
				found = true
				break
		if not found:
			add_row_tee_opt.selected = 0

	for opt in player_tee_options:
		if opt != null and is_instance_valid(opt):
			var prev_sel = opt.get_item_text(opt.selected) if opt.selected >= 0 else ""
			opt.clear()
			for i in range(current_course_tees.size()):
				opt.add_item(current_course_tees[i], i)
			var found = false
			for i in range(opt.item_count):
				if opt.get_item_text(i).to_lower() == prev_sel.to_lower():
					opt.selected = i
					found = true
					break
			if not found:
				opt.selected = 0
			if opt.has_meta("player_data"):
				var pd = opt.get_meta("player_data")
				pd["tee"] = opt.get_item_text(opt.selected)


func apply_button_style(btn: Button, bg_color: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.12)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.12)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_font_size_override("font_size", 14)
