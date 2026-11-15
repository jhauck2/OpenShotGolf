extends Control

@onready var _course_list = $ContentPanel/ContentMargin/VBoxContainer/ScrollContainer/CourseList
var _play_button: Button
var _preview_button: Button

var active_tab: String = "Real" # "Real" or "Custom"
var real_tab_btn: Button
var custom_tab_btn: Button
var create_custom_btn: Button

var selected_length: String = "Front 9, Back 9"
var front_9_selected: bool = true
var back_9_selected: bool = true
var extra_holes_selected: bool = false
var front_9_btn: Button
var back_9_btn: Button
var extra_holes_btn: Button


func _ready() -> void:
	# Configure back button style and icon
	var main_menu_btn = get_node_or_null("ContentPanel/ContentMargin/VBoxContainer/HeaderHBox/MainMenuButton")
	if main_menu_btn != null:
		main_menu_btn.icon = load("res://UI/MainMenu/images/menu.svg")
		main_menu_btn.expand_icon = true
		ThemeManager.apply_nav_button_style(main_menu_btn)

	_course_list.item_selected.connect(_on_course_selected)
	ThemeManager.apply_item_list_style(_course_list)

	var vbox = $ContentPanel/ContentMargin/VBoxContainer
	if vbox != null:
		var tab_hbox = _create_tab_selector()
		vbox.add_child(tab_hbox)
		var scroll_node = vbox.get_node_or_null("ScrollContainer")
		if scroll_node != null:
			vbox.move_child(tab_hbox, scroll_node.get_index())
			if scroll_node is ScrollContainer:
				ThemeManager.apply_scroll_container_style(scroll_node)

	_switch_course_tab("Real")

	# Dynamic OSM Download UI
	if vbox != null:
		var download_panel = PanelContainer.new()
		download_panel.name = "OsmDownloadPanel"
		ThemeManager.apply_card_panel_style(download_panel, false, 8)
		
		var download_hbox = HBoxContainer.new()
		download_hbox.add_theme_constant_override("separation", 15)
		download_panel.add_child(download_hbox)
		
		var section_title = Label.new()
		section_title.text = "Want to play a new course? Search and download from OpenStreetMap:"
		section_title.add_theme_font_size_override("font_size", 18)
		section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		download_hbox.add_child(section_title)
		
		var dl_btn = Button.new()
		dl_btn.text = "Search & Download Course"
		dl_btn.custom_minimum_size = Vector2(280, 56)
		dl_btn.add_theme_font_size_override("font_size", 20)
		ThemeManager.apply_secondary_button_style(dl_btn)
		download_hbox.add_child(dl_btn)
		
		dl_btn.pressed.connect(func():
			var dialog_scene = load("res://Courses/OsmDownloadDialog/osm_download_dialog.tscn")
			if dialog_scene != null:
				var dialog = dialog_scene.instantiate()
				add_child(dialog)
				dialog.course_downloaded.connect(func(_course_name):
					_request_course_reload()
				)
				dialog.tree_exited.connect(func():
					_request_course_reload()
				)
		)
		
		var delete_btn = Button.new()
		delete_btn.text = "Delete Selected Course"
		delete_btn.custom_minimum_size = Vector2(240, 56)
		delete_btn.add_theme_font_size_override("font_size", 20)
		ThemeManager.apply_danger_button_style(delete_btn)
		download_hbox.add_child(delete_btn)
		delete_btn.pressed.connect(_on_delete_course_pressed)
		
		vbox.add_child(download_panel)
		vbox.move_child(download_panel, 0)

		# Combined options row for hole length (front/back/full) and wind simulation
		var options_hbox = HBoxContainer.new()
		options_hbox.add_theme_constant_override("separation", 16)
		options_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var length_selector = _create_length_selector()
		length_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_hbox.add_child(length_selector)

		var wind_selector = _create_wind_selector()
		wind_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_hbox.add_child(wind_selector)

		vbox.add_child(options_hbox)

		var green_speed_selector = _create_green_speed_selector()
		vbox.add_child(green_speed_selector)

		# Add Footer with Play Course button
		var footer_hbox = HBoxContainer.new()
		footer_hbox.alignment = BoxContainer.ALIGNMENT_END
		footer_hbox.add_theme_constant_override("separation", 20)
		
		_preview_button = Button.new()
		_preview_button.text = "Preview Course"
		_preview_button.custom_minimum_size = Vector2(240, 60)
		_preview_button.add_theme_font_size_override("font_size", 22)
		ThemeManager.apply_secondary_button_style(_preview_button)
		_preview_button.disabled = true
		_preview_button.pressed.connect(_on_preview_pressed)
		
		_play_button = Button.new()
		_play_button.text = "Play Course"
		_play_button.custom_minimum_size = Vector2(240, 60)
		_play_button.add_theme_font_size_override("font_size", 22)
		ThemeManager.apply_primary_button_style(_play_button)
		_play_button.disabled = true
		_play_button.pressed.connect(_on_play_pressed)
		
		footer_hbox.add_child(_preview_button)
		footer_hbox.add_child(_play_button)
		vbox.add_child(footer_hbox)

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
		if event is InputEventKey and (event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE):
			return
		for child in get_children():
			if (child is ConfirmationDialog or child is AcceptDialog) and child.visible:
				child.visible = false
				get_viewport().set_input_as_handled()
				return
			if child.is_visible_in_tree() and (child.name.contains("Dialog") or child.name.contains("Creator")):
				child.queue_free()
				get_viewport().set_input_as_handled()
				return
		_on_main_menu_button_pressed()
		get_viewport().set_input_as_handled()


func _on_main_menu_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_course_list_item_activated(index: int) -> void:
	var metadata = _course_list.get_item_metadata(index) if index >= 0 and index < _course_list.get_item_count() else {}
	if bool(metadata.get("is_corrupted", false)):
		var alert := AcceptDialog.new()
		alert.title = "Corrupted Course Scene"
		alert.dialog_text = "The course \"%s\" has a corrupted or unreadable scene file.\n\nPlease click 'Delete Course' to delete it, then redownload it fresh from the Course Catalog." % metadata.get("title", "this course")
		alert.min_size = Vector2(460, 180)
		ThemeManager.apply_dialog_style(alert)
		alert.confirmed.connect(func(): alert.queue_free())
		add_child(alert)
		alert.popup_centered()
		return

	var scene_path: String = _course_list.get_scene_path_for_index(index)
	var config_path: String = _course_list.get_config_path_for_index(index)

	if scene_path.is_empty():
		printerr("[CourseSelector] Play requested with an empty scene scene_path.")
		return

	if GlobalSettings.practice_mode_primed:
		# Setup a single practice player in MultiplayerManager so it uses normal course play hud and flow
		var players_to_add = [
			{
				"name": "Practice Player",
				"tee": "Blue"
			}
		]
		
		# Load the course config first so MultiplayerManager has the hole info
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file != null:
			var json_text = file.get_as_text()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var config_dict = json.data
				var mp_mgr = get_node_or_null("/root/MultiplayerManager")
				if mp_mgr != null:
					mp_mgr.setup_game(players_to_add, config_dict, scene_path, config_path, selected_length)
					mp_mgr.practice_mode_active = true
					mp_mgr.start_hole()
					print("[PracticeMode] MultiplayerManager primed with single practice player")

	if GlobalSettings != null:
		GlobalSettings.start_round_wind(true)

	SceneManager.load_course(scene_path, config_path)


func _request_course_reload() -> void:
	_course_list.reload_courses("user://courses")
	_update_play_button()


func _on_delete_course_pressed() -> void:
	var selected = _course_list.get_selected_items()
	if selected.is_empty():
		return
	
	var metadata = _course_list.get_item_metadata(selected[0])
	var config_path: String = metadata.get("config_path", "")
	
	if config_path.is_empty():
		return
	
	# Only allow deleting user-downloaded courses, not built-in ones
	if not config_path.begins_with("user://"):
		return
	
	var course_dir = config_path.get_base_dir()
	var course_title = metadata.get("title", course_dir.get_file())
	
	# Show confirmation dialog
	var confirm = ConfirmationDialog.new()
	confirm.title = "Delete Course"
	confirm.dialog_text = "Delete course \"%s\"?\n\nThis will permanently remove all files in:\n%s" % [course_title, course_dir]
	confirm.min_size = Vector2(480, 200)
	ThemeManager.apply_dialog_style(confirm)
	confirm.confirmed.connect(func():
		_delete_course_dir(course_dir, course_title)
		_request_course_reload()
		confirm.queue_free()
	)
	confirm.canceled.connect(func():
		confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()


func _delete_course_dir(dir_path: String, course_title: String = "") -> void:
	CourseValidator._delete_dir_recursive(dir_path)
	print("[CourseSelector] Deleted course directory: %s" % dir_path)

	# Clean up any corresponding geometry cache in user://cached_geometry
	_delete_user_cached_geometry(dir_path.get_file(), course_title)


func _delete_user_cached_geometry(folder_name: String, course_title: String = "") -> void:
	var user_cache_dir = "user://cached_geometry"
	if not DirAccess.dir_exists_absolute(user_cache_dir):
		return

	var candidates: Array[String] = [
		folder_name,
		folder_name.to_lower(),
		_slugify_name(folder_name),
	]
	if not course_title.is_empty():
		candidates.append(course_title.to_lower().replace(" ", "_"))
		candidates.append(_slugify_name(course_title))

	for cand in candidates:
		if cand.is_empty():
			continue
		for ext in [".json.gz", ".json"]:
			var file_path = user_cache_dir.path_join(cand + ext)
			if FileAccess.file_exists(file_path):
				DirAccess.remove_absolute(file_path)
				print("[CourseSelector] Cleaned up cached geometry file: %s" % file_path)


static func _slugify_name(text: String) -> String:
	var res = ""
	var prev_sep = false
	for ch in text.to_lower():
		if (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9'):
			res += ch
			prev_sep = false
		elif ch in [' ', '_', '-', '(', ')', '.']:
			if not prev_sep and not res.is_empty():
				res += "_"
				prev_sep = true
	return res.strip_edges().trim_prefix("_").trim_suffix("_")


func _on_course_selected(index: int) -> void:
	_update_play_button()
	_update_course_length_options(index)


func _update_play_button() -> void:
	var has_selection = not _course_list.get_selected_items().is_empty()
	if _play_button != null:
		_play_button.disabled = not has_selection
	if _preview_button != null:
		_preview_button.disabled = not has_selection


func _on_play_pressed() -> void:
	var selected = _course_list.get_selected_items()
	if not selected.is_empty():
		_on_course_list_item_activated(selected[0])


func _on_preview_pressed() -> void:
	var selected = _course_list.get_selected_items()
	if selected.is_empty():
		return
		
	var idx = selected[0]
	var metadata = _course_list.get_item_metadata(idx)
	var config_path: String = metadata.get("config_path", "")
	var scene_path: String = metadata.get("scene_path", "")
	
	var dialog_scene = load("res://UI/CoursePreviewDialog/course_preview_dialog.tscn")
	if dialog_scene != null:
		var dialog = dialog_scene.instantiate()
		add_child(dialog)
		dialog.setup(config_path, scene_path)


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


func _create_length_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.2, 0.4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.4, 0.5, 0.3)
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
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Select Holes:"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	# Segmented buttons container
	var seg_hbox = HBoxContainer.new()
	seg_hbox.add_theme_constant_override("separation", 0) # Segments touch
	hbox.add_child(seg_hbox)

	front_9_btn = Button.new()
	front_9_btn.text = "Front 9"
	front_9_btn.custom_minimum_size = Vector2(150, 48)
	front_9_btn.add_theme_font_size_override("font_size", 20)
	seg_hbox.add_child(front_9_btn)

	back_9_btn = Button.new()
	back_9_btn.text = "Back 9"
	back_9_btn.custom_minimum_size = Vector2(150, 48)
	back_9_btn.add_theme_font_size_override("font_size", 20)
	seg_hbox.add_child(back_9_btn)

	extra_holes_btn = Button.new()
	extra_holes_btn.text = "Extra Holes"
	extra_holes_btn.custom_minimum_size = Vector2(150, 48)
	extra_holes_btn.add_theme_font_size_override("font_size", 20)
	seg_hbox.add_child(extra_holes_btn)

	# Style buttons and setup connections
	front_9_btn.pressed.connect(func(): _toggle_length("Front 9"))
	back_9_btn.pressed.connect(func(): _toggle_length("Back 9"))
	extra_holes_btn.pressed.connect(func(): _toggle_length("Extra Holes"))

	_update_length_button_styles()
	return panel


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
	var course_data = _course_list.get_item_metadata(idx)
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


func _create_green_speed_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.2, 0.4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.4, 0.5, 0.3)
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
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 5.0
	slider.max_value = 16.0
	slider.step = 0.5
	slider.value = GlobalSettings.range_settings.green_speed.value
	slider.custom_minimum_size = Vector2(110, 36 if MobilePerformance.is_mobile() else 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ThemeManager.apply_slider_style(slider, 36 if MobilePerformance.is_mobile() else 24, 110)
	hbox.add_child(slider)

	var val_lbl = Label.new()
	val_lbl.text = "%.1f" % slider.value
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.custom_minimum_size = Vector2(36, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(val_lbl)

	hbox.add_child(VSeparator.new())
	var pin_check = CheckBox.new()
	pin_check.text = "Random Pin"
	pin_check.add_theme_font_size_override("font_size", 18)
	pin_check.button_pressed = bool(GlobalSettings.range_settings.random_pin_enabled.value)
	pin_check.toggled.connect(func(on):
		GlobalSettings.range_settings.random_pin_enabled.set_value(on)
		GlobalSettings.save_settings()
	)
	hbox.add_child(pin_check)

	slider.value_changed.connect(func(val):
		GlobalSettings.range_settings.green_speed.set_value(val)
		val_lbl.text = "%.1f" % val
	)

	GlobalSettings.range_settings.green_speed.setting_changed.connect(func(val):
		if slider != null and is_instance_valid(slider) and not is_equal_approx(slider.value, val):
			slider.value = val
		if val_lbl != null and is_instance_valid(val_lbl):
			val_lbl.text = "%.1f" % val
	)

	return panel


func _create_wind_selector() -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.2, 0.4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.4, 0.5, 0.3)
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
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Wind Simulation:"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var check = CheckButton.new()
	check.custom_minimum_size = Vector2(72, 48)
	if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("wind_enabled"):
		check.set_pressed_no_signal(bool(GlobalSettings.range_settings.wind_enabled.value))
	check.toggled.connect(func(enabled: bool):
		if GlobalSettings != null and GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("wind_enabled"):
			GlobalSettings.range_settings.wind_enabled.set_value(enabled)
			GlobalSettings.save_settings()
	)
	hbox.add_child(check)

	return panel


func _create_tab_selector() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	real_tab_btn = Button.new()
	real_tab_btn.text = "Real Courses"
	real_tab_btn.custom_minimum_size = Vector2(180, 44)
	real_tab_btn.add_theme_font_size_override("font_size", 20)

	custom_tab_btn = Button.new()
	custom_tab_btn.text = "Custom Courses"
	custom_tab_btn.custom_minimum_size = Vector2(180, 44)
	custom_tab_btn.add_theme_font_size_override("font_size", 20)

	create_custom_btn = Button.new()
	create_custom_btn.text = "+ Create Custom Course"
	create_custom_btn.custom_minimum_size = Vector2(240, 44)
	create_custom_btn.add_theme_font_size_override("font_size", 20)

	real_tab_btn.pressed.connect(func(): _switch_course_tab("Real"))
	custom_tab_btn.pressed.connect(func(): _switch_course_tab("Custom"))
	create_custom_btn.pressed.connect(_on_create_custom_pressed)

	hbox.add_child(real_tab_btn)
	hbox.add_child(custom_tab_btn)
	hbox.add_child(create_custom_btn)

	return hbox


func _switch_course_tab(tab: String) -> void:
	active_tab = tab
	_update_tab_button_styles()
	if _course_list != null:
		_course_list.set_filter_mode(active_tab)
		_update_play_button()


func _update_tab_button_styles() -> void:
	if real_tab_btn != null:
		_style_seg_button(real_tab_btn, "left", active_tab == "Real")
	if custom_tab_btn != null:
		_style_seg_button(custom_tab_btn, "right", active_tab == "Custom")
	if create_custom_btn != null:
		apply_button_style(create_custom_btn, Color(0.2, 0.55, 0.35))


func _on_create_custom_pressed() -> void:
	var dialog_scene = load("res://UI/CustomCourseCreator/custom_course_creator.tscn")
	if dialog_scene != null:
		var dialog = dialog_scene.instantiate()
		add_child(dialog)
		dialog.course_created.connect(func(_new_course):
			_switch_course_tab("Custom")
			_request_course_reload()
		)
