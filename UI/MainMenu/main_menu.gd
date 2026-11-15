extends Control
# TODO - add settings menu system on future PR. 
@onready var _settings_button: Button = $VerticalLayout/TopStrip/HBoxContainer/SettingsButton
@onready var _credits_button: Button = $VerticalLayout/TopStrip/HBoxContainer/CreditsButton
@onready var _exit_button: Button = $VerticalLayout/TopStrip/HBoxContainer/ExitButton
@onready var _courses_button: Button = $VerticalLayout/TilesRow/CoursesTile/CoursesTextBackdrop/CoursesButton
@onready var _multiplayer_button: Button = $VerticalLayout/TilesRow/MultiplayerTile/MultiplayerTextBackdrop/MultiplayerButton
@onready var _range_button: Button = $VerticalLayout/TilesRow/RangeTile/RangeTextBackdrop/RangeButton
@onready var _practice_button: Button = $VerticalLayout/TilesRow/PracticeTile/PracticeTextBackdrop/PracticeButton
@onready var _history_button: Button = $VerticalLayout/TilesRow/HistoryTile/HistoryTextBackdrop/HistoryButton
@onready var _leaderboards_button: Button = $VerticalLayout/TilesRow/LeaderboardsTile/LeaderboardsTextBackdrop/LeaderboardsButton
@onready var _players_button: Button = $VerticalLayout/TilesRow/PlayersTile/PlayersTextBackdrop/PlayersButton
@onready var _minigames_button: Button = $VerticalLayout/TilesRow/MiniGamesTile/MiniGamesTextBackdrop/MiniGamesButton
@onready var _version_label: Label = $VerticalLayout/BottomBarContainer/HBoxContainer/VersionLabel
@onready var _account_button: Button = $VerticalLayout/TopStrip/HBoxContainer/AccountButton
@onready var _discord_button: Button = $VerticalLayout/TopStrip/HBoxContainer/DiscordButton
@onready var _youtube_button: Button = $VerticalLayout/TopStrip/HBoxContainer/YouTubeButton
@onready var _community_button: Button = $VerticalLayout/TopStrip/HBoxContainer/CommunityButton
var _version_fall_back: String = "dev"
var _version_setting_path: String = "application/config/version"
var _version_text: String

static var _startup_lm_checked: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	if _credits_button != null:
		_credits_button.pressed.connect(_on_credits_pressed)
	if _account_button != null:
		_account_button.pressed.connect(_on_account_pressed)
	if _discord_button != null:
		_discord_button.pressed.connect(_on_discord_pressed)
	if _youtube_button != null:
		_youtube_button.pressed.connect(_on_youtube_pressed)
	if _community_button != null:
		_community_button.pressed.connect(_on_community_pressed)
	_range_button.pressed.connect(_on_range_pressed)
	_courses_button.pressed.connect(_on_courses_pressed)
	if _multiplayer_button != null:
		_multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	_practice_button.pressed.connect(_on_practice_pressed)
	_history_button.pressed.connect(_on_history_pressed)
	if _leaderboards_button != null:
		_leaderboards_button.pressed.connect(_on_leaderboards_pressed)
	_players_button.pressed.connect(_on_players_pressed)
	_minigames_button.pressed.connect(_on_minigames_pressed)
		
	_update_version_label()
	SceneManager.current_scene = self

	_check_startup_launch_monitor()

	if has_node("/root/OnlineMatchController"):
		var omc = get_node("/root/OnlineMatchController")
		if not omc.rejoin_dialog_requested.is_connected(_show_rejoin_match_dialog):
			omc.rejoin_dialog_requested.connect(_show_rejoin_match_dialog)
		call_deferred("_check_startup_rejoin")

	# Apply central theme styles to header and footer buttons
	ThemeManager.apply_nav_button_style(_settings_button, 6)
	if _credits_button != null:
		ThemeManager.apply_nav_button_style(_credits_button, 6)
	ThemeManager.apply_nav_button_style(_exit_button, 6)
	if _account_button != null:
		ThemeManager.apply_nav_button_style(_account_button, 6)
	if _discord_button != null:
		ThemeManager.apply_icon_button_style(_discord_button, 6, 12)
	if _youtube_button != null:
		ThemeManager.apply_icon_button_style(_youtube_button, 6, 12)
	if _community_button != null:
		ThemeManager.apply_icon_button_style(_community_button, 6, 12)

	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.has_signal("auth_state_changed") and not ca.auth_state_changed.is_connected(_on_cloud_auth_state_changed):
			ca.auth_state_changed.connect(_on_cloud_auth_state_changed)
	_update_account_button_status()

	# Apply central theme card styling to tiles
	var tiles_row = get_node_or_null("VerticalLayout/TilesRow")
	if tiles_row != null:
		_update_tiles_row_width()
		if not get_viewport().size_changed.is_connected(_update_tiles_row_width):
			get_viewport().size_changed.connect(_update_tiles_row_width)
		
		for tile in tiles_row.get_children():
			if tile is PanelContainer:
				tile.clip_contents = true
				ThemeManager.apply_card_panel_style(tile, false, 12, 0, 0, 0, 0)
				tile.mouse_entered.connect(func(): ThemeManager.apply_card_panel_style(tile, true, 12, 0, 0, 0, 0))
				tile.mouse_exited.connect(func(): ThemeManager.apply_card_panel_style(tile, false, 12, 0, 0, 0, 0))
				var tile_btn = tile.find_child("*Button*", true, false) as Button
				if tile_btn != null:
					var focus_border = StyleBoxFlat.new()
					focus_border.bg_color = Color(0, 0, 0, 0)
					focus_border.border_color = Color(0.35, 0.82, 1.0, 0.95)
					focus_border.border_width_left = 3
					focus_border.border_width_top = 3
					focus_border.border_width_right = 3
					focus_border.border_width_bottom = 3
					focus_border.corner_radius_top_left = 12
					focus_border.corner_radius_top_right = 12
					focus_border.corner_radius_bottom_right = 12
					focus_border.corner_radius_bottom_left = 12
					tile_btn.add_theme_stylebox_override("focus", focus_border)
					tile_btn.focus_entered.connect(func(): ThemeManager.apply_card_panel_style(tile, true, 12, 0, 0, 0, 0))
					tile_btn.focus_exited.connect(func(): ThemeManager.apply_card_panel_style(tile, false, 12, 0, 0, 0, 0))

	_setup_focus_navigation()
	call_deferred("_grab_initial_focus")


func _update_tiles_row_width() -> void:
	var tiles_row = get_node_or_null("VerticalLayout/TilesRow")
	if tiles_row != null:
		var viewport_width = get_viewport().get_visible_rect().size.x
		var target_width = clamp(viewport_width * 0.75, 720.0, viewport_width * 0.95)
		tiles_row.custom_minimum_size.x = target_width


func _setup_focus_navigation() -> void:
	if _courses_button == null:
		return

	var set_neighbors = func(btn: Control, left: Control, right: Control, top: Control, bottom: Control):
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

	# Row 0: Courses, Multiplayer, Practice, Range
	var r0_c3 = _range_button
	var top_right = _account_button if _account_button != null else (_discord_button if _discord_button != null else _exit_button)

	set_neighbors.call(_courses_button, r0_c3, _multiplayer_button, _settings_button, _history_button)
	set_neighbors.call(_multiplayer_button, _courses_button, _practice_button, _credits_button, _leaderboards_button)
	set_neighbors.call(_practice_button, _multiplayer_button, _range_button, _exit_button, _players_button)
	set_neighbors.call(_range_button, _practice_button, _courses_button, top_right, _minigames_button)

	# Row 1: History, Leaderboards, Players, Mini Games
	set_neighbors.call(_history_button, _minigames_button, _leaderboards_button, _courses_button, _courses_button)
	set_neighbors.call(_leaderboards_button, _history_button, _players_button, _multiplayer_button, _multiplayer_button)
	set_neighbors.call(_players_button, _leaderboards_button, _minigames_button, _practice_button, _practice_button)
	set_neighbors.call(_minigames_button, _players_button, _history_button, _range_button, _range_button)

	# Top Bar
	var right_after_exit = _account_button if _account_button != null else (_discord_button if _discord_button != null else (_youtube_button if _youtube_button != null else (_community_button if _community_button != null else _settings_button)))
	var rightmost_top = _community_button if _community_button != null else (_youtube_button if _youtube_button != null else (_discord_button if _discord_button != null else _exit_button))
	set_neighbors.call(_settings_button, rightmost_top, _credits_button, _history_button, _courses_button)
	set_neighbors.call(_credits_button, _settings_button, _exit_button, _leaderboards_button, _multiplayer_button)
	set_neighbors.call(_exit_button, _credits_button, right_after_exit, _players_button, _practice_button)
	if _account_button != null:
		set_neighbors.call(_account_button, _exit_button, _discord_button if _discord_button else (_youtube_button if _youtube_button else (_community_button if _community_button else _settings_button)), _minigames_button, _range_button)
	if _discord_button != null:
		set_neighbors.call(_discord_button, _account_button if _account_button else _exit_button, _youtube_button if _youtube_button else (_community_button if _community_button else _settings_button), _minigames_button, _range_button)
	if _youtube_button != null:
		set_neighbors.call(_youtube_button, _discord_button if _discord_button else (_account_button if _account_button else _exit_button), _community_button if _community_button else _settings_button, _minigames_button, _range_button)
	if _community_button != null:
		set_neighbors.call(_community_button, _youtube_button if _youtube_button else (_discord_button if _discord_button else (_account_button if _account_button else _exit_button)), _settings_button, _minigames_button, _range_button)


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg.is_modal_active():
			return
	if _courses_button != null and is_instance_valid(_courses_button):
		_courses_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg.is_modal_active():
			return
	if event.is_action_pressed("ui_cancel"):
		if _exit_button != null and is_instance_valid(_exit_button):
			if get_viewport().gui_get_focus_owner() == _exit_button:
				_on_exit_pressed()
			else:
				_exit_button.grab_focus()
			get_viewport().set_input_as_handled()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_range_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/range.tscn")


func _on_courses_pressed() -> void:
	SceneManager.change_scene("res://Courses/CoursePlay/course_play_setup.tscn")


func _on_multiplayer_pressed() -> void:
	const MP_SCENE := "res://UI/OnlineMultiplayer/multiplayer_menu.tscn"
	if ResourceLoader.exists(MP_SCENE):
		SceneManager.change_scene(MP_SCENE)
	else:
		push_warning("[MainMenu] Online Multiplayer scene not installed yet.")
		_show_toast_message("Online Multiplayer is coming soon in an upcoming release!")


func _on_leaderboards_pressed() -> void:
	SceneManager.change_scene("res://UI/Leaderboards/leaderboards_menu.tscn")


func _show_toast_message(msg: String) -> void:
	var existing = get_node_or_null("ToastNotice")
	if existing != null:
		existing.queue_free()
	var toast = PanelContainer.new()
	toast.name = "ToastNotice"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style.border_color = Color(0.35, 0.82, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20.0
	style.content_margin_top = 12.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 12.0
	toast.add_theme_stylebox_override("panel", style)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_bottom = -80
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	toast.add_child(lbl)
	add_child(toast)
	var tw = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)


func _on_practice_pressed() -> void:
	GlobalSettings.practice_mode_primed = true
	SceneManager.change_scene("res://Courses/CourseSelector/course_selector.tscn")


func _update_version_label():
	_version_text = _version_fall_back
	if (ProjectSettings.has_setting(_version_setting_path)):
		var _configured_version = str(ProjectSettings.get_setting(_version_setting_path)).strip_edges()
		_version_text = _configured_version;

	_version_label.text = "Version %s" % _version_text
	
func _on_settings_pressed() -> void:
	var settings_scene = load("res://UI/Settings/RangeSettings/range_settings.tscn")
	if settings_scene != null:
		var inst = settings_scene.instantiate()
		inst.name = "MainMenuSettings"
		inst.set_anchors_preset(Control.PRESET_FULL_RECT)
		inst.grow_horizontal = Control.GROW_DIRECTION_BOTH
		inst.grow_vertical = Control.GROW_DIRECTION_BOTH
		inst.close_settings_requested.connect(func():
			inst.visible = false
			inst.queue_free()
		)
		add_child(inst)


func _on_credits_pressed() -> void:
	var credits_scene = load("res://UI/CreditsModal/credits_modal.tscn")
	if credits_scene != null:
		var inst = credits_scene.instantiate()
		inst.name = "MainMenuCredits"
		add_child(inst)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_discord_pressed() -> void:
	OS.shell_open("https://discord.gg/gjaNhkQwJ")


func _on_youtube_pressed() -> void:
	OS.shell_open("https://www.youtube.com/@hecklegolfsimulator")


func _on_community_pressed() -> void:
	OS.shell_open("https://heckle-golf-sim.firebaseapp.com/")


func _on_history_pressed() -> void:
	SceneManager.change_scene("res://UI/HistoryMenu/history_menu.tscn")


func _on_players_pressed() -> void:
	SceneManager.change_scene("res://UI/PlayersMenu/players_menu.tscn")


func _on_minigames_pressed() -> void:
	SceneManager.change_scene("res://UI/MiniGamesMenu/minigames_menu.tscn")


func _check_startup_launch_monitor() -> void:
	if _startup_lm_checked:
		return
	_startup_lm_checked = true

	var is_connected := false
	var should_auto_connect := false
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		var status = str(lm.status)
		if status == "Connected" or status == "Ready" or lm.is_ready:
			is_connected = true
		should_auto_connect = bool(lm.settings.get("remember_device", false)) and bool(lm.settings.get("enabled", true)) and str(lm.settings.get("device_id", "")).strip_edges() != ""

	if not is_connected and not should_auto_connect:
		call_deferred("_show_launch_monitor_connect_modal")


func _show_launch_monitor_connect_modal() -> void:
	var modal_scene = load("res://UI/LaunchMonitorConnectModal/launch_monitor_connect_modal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		modal.name = "StartupLaunchMonitorModal"
		add_child(modal)


var _rejoin_dialog: PanelContainer = null


func _check_startup_rejoin() -> void:
	if has_node("/root/OnlineMatchController"):
		get_node("/root/OnlineMatchController").check_and_prompt_rejoin()


func _show_rejoin_match_dialog(match_id: String, course_title: String) -> void:
	if _rejoin_dialog != null and is_instance_valid(_rejoin_dialog):
		_rejoin_dialog.queue_free()

	_rejoin_dialog = PanelContainer.new()
	_rejoin_dialog.name = "RejoinMatchDialog"
	_rejoin_dialog.z_index = 500
	_rejoin_dialog.anchor_left = 0.5
	_rejoin_dialog.anchor_right = 0.5
	_rejoin_dialog.anchor_top = 0.5
	_rejoin_dialog.anchor_bottom = 0.5
	_rejoin_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_rejoin_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_rejoin_dialog.offset_left = -260
	_rejoin_dialog.offset_right = 260
	_rejoin_dialog.offset_top = -120
	_rejoin_dialog.offset_bottom = 120

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.16, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.65, 0.85, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 12
	_rejoin_dialog.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var title_lbl := Label.new()
	title_lbl.text = "Rejoin Online Match? ⛳"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = "Rejoin your online match in progress on\n%s?" % course_title
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(msg_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)

	var rejoin_btn := Button.new()
	rejoin_btn.name = "RejoinBtn"
	rejoin_btn.text = "Rejoin Match"
	rejoin_btn.custom_minimum_size = Vector2(150, 44)
	ThemeManager.apply_primary_button_style(rejoin_btn, 8)
	rejoin_btn.pressed.connect(func():
		_dismiss_rejoin_dialog()
		if has_node("/root/OnlineMatchController"):
			get_node("/root/OnlineMatchController").rejoin_active_match(match_id)
	)
	btn_hbox.add_child(rejoin_btn)

	var abandon_btn := Button.new()
	abandon_btn.name = "AbandonBtn"
	abandon_btn.text = "Abandon"
	abandon_btn.custom_minimum_size = Vector2(130, 44)
	ThemeManager.apply_secondary_button_style(abandon_btn, 8)
	abandon_btn.pressed.connect(func():
		_dismiss_rejoin_dialog()
		if has_node("/root/OnlineMatchController"):
			get_node("/root/OnlineMatchController").clear_active_match_file()
	)
	btn_hbox.add_child(abandon_btn)

	rejoin_btn.focus_neighbor_right = rejoin_btn.get_path_to(abandon_btn)
	rejoin_btn.focus_neighbor_left = rejoin_btn.get_path_to(abandon_btn)
	abandon_btn.focus_neighbor_left = abandon_btn.get_path_to(rejoin_btn)
	abandon_btn.focus_neighbor_right = abandon_btn.get_path_to(rejoin_btn)

	vbox.add_child(btn_hbox)
	_rejoin_dialog.add_child(vbox)
	add_child(_rejoin_dialog)

	if has_node("/root/UIFocusGuard"):
		get_node("/root/UIFocusGuard").push_lock(_rejoin_dialog)
	rejoin_btn.call_deferred("grab_focus")


func _dismiss_rejoin_dialog() -> void:
	if _rejoin_dialog != null and is_instance_valid(_rejoin_dialog):
		if has_node("/root/UIFocusGuard"):
			var ufg = get_node("/root/UIFocusGuard")
			if ufg.is_locked() and ufg.current_lock_root() == _rejoin_dialog:
				ufg.pop_lock(false)
		_rejoin_dialog.queue_free()
		_rejoin_dialog = null


func _on_cloud_auth_state_changed(_is_signed_in: bool, _user: Dictionary) -> void:
	_update_account_button_status()


func _update_account_button_status() -> void:
	if _account_button == null or not is_instance_valid(_account_button):
		return
	var ca = get_node_or_null("/root/CloudAuth")
	if ca != null and ca.is_signed_in():
		var dname: String = ca.get_display_name()
		var email: String = ca.get_email()
		if dname.is_empty():
			dname = email.split("@")[0] if not email.is_empty() else "Golfer"
		_account_button.text = "👤 %s" % dname
		_account_button.tooltip_text = "Signed in as %s (%s) — Click to manage account" % [dname, email]
		_account_button.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65, 1.0))
	else:
		_account_button.text = "☁ Sign In"
		_account_button.tooltip_text = "Sign in to sync player profiles and play online"
		_account_button.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))


func _on_account_pressed() -> void:
	if find_child("AccountModal", true, false) != null:
		return
	var modal_scene = load("res://UI/Account/account_modal.tscn")
	if modal_scene == null:
		return
	var modal = modal_scene.instantiate()
	modal.name = "AccountModal"
	add_child(modal)
	if modal.has_signal("modal_closed"):
		modal.modal_closed.connect(func():
			_update_account_button_status()
			if _account_button != null and is_instance_valid(_account_button):
				_account_button.call_deferred("grab_focus")
		)
