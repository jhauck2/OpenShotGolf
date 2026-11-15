extends Control

## Online Multiplayer Menu (res://UI/OnlineMultiplayer/multiplayer_menu.gd)
## Hosts, joins by 6-char code, browses public lobbies, verifies course fingerprint,
## downloads missing courses, and coordinates lobby readiness.
## Also hosts the full Tournament flow: host/join/browse/standings.
## See docs/multiplayer/07_ONLINE_LOBBY_HOST_JOIN.md.

const CourseFingerprintScript = preload("res://Utils/Cloud/course_fingerprint.gd")
const BudgetPausedBannerScript = preload("res://UI/Account/budget_paused_banner.gd")

# â”€â”€ TOP BAR & MODE SELECTOR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@onready var back_button: Button = %BackButton
@onready var user_status_label: Label = %UserStatusLabel
@onready var account_button: Button = %AccountButton
@onready var budget_banner: PanelContainer = %BudgetBanner

@onready var mode_selector_bar: HBoxContainer = %ModeSelectorBar
@onready var mode_matches_button: Button = %ModeMatchesButton
@onready var mode_tournaments_button: Button = %ModeTournamentsButton

# â”€â”€ MATCHES SECTION (existing) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@onready var tab_bar: HBoxContainer = %TabBar
@onready var tab_host_button: Button = %TabHostButton
@onready var tab_join_code_button: Button = %TabJoinCodeButton
@onready var tab_browser_button: Button = %TabBrowserButton

@onready var host_view: VBoxContainer = %HostView
@onready var course_dropdown: OptionButton = %CourseDropdown
@onready var length_option: OptionButton = %LengthOption
@onready var mode_option: OptionButton = %ModeOption
@onready var turn_order_option: OptionButton = %TurnOrderOption
@onready var wind_option: OptionButton = %WindOption
@onready var green_speed_option: OptionButton = %GreenSpeedOption
@onready var visibility_option: OptionButton = %VisibilityOption
@onready var gimme_mode_option: OptionButton = %GimmeModeOption
@onready var host_gimme_params_container: PanelContainer = %HostGimmeParamsContainer
@onready var host_gimme_1_check: CheckBox = %HostGimme1Check
@onready var host_gimme_1_dist: SpinBox = %HostGimme1Dist
@onready var host_gimme_2_check: CheckBox = %HostGimme2Check
@onready var host_gimme_2_dist: SpinBox = %HostGimme2Dist
@onready var host_gimme_3_check: CheckBox = %HostGimme3Check
@onready var host_gimme_3_dist: SpinBox = %HostGimme3Dist
@onready var host_golfer_dropdown: OptionButton = %HostGolferDropdown
@onready var host_golfer_tee: OptionButton = %HostGolferTee
@onready var host_create_button: Button = %HostCreateButton
@onready var host_status_label: Label = %HostStatusLabel

@onready var join_code_view: VBoxContainer = %JoinCodeView
@onready var join_code_input: LineEdit = %JoinCodeInput
@onready var paste_code_button: Button = %PasteCodeButton
@onready var join_golfer_dropdown: OptionButton = %JoinGolferDropdown
@onready var join_golfer_tee: OptionButton = %JoinGolferTee
@onready var join_code_submit_button: Button = %JoinCodeSubmitButton
@onready var join_status_label: Label = %JoinStatusLabel

@onready var browser_view: VBoxContainer = %BrowserView
@onready var refresh_browser_button: Button = %RefreshBrowserButton
@onready var browser_scroll: ScrollContainer = %BrowserScroll
@onready var browser_list: VBoxContainer = %BrowserList
@onready var no_lobbies_label: Label = %NoLobbiesLabel

@onready var lobby_room_view: VBoxContainer = %LobbyRoomView
@onready var room_code_label: Label = %RoomCodeLabel
@onready var copy_code_button: Button = %CopyCodeButton
@onready var room_details_label: Label = %RoomDetailsLabel
@onready var course_install_banner: PanelContainer = %CourseInstallBanner
@onready var course_install_label: Label = %CourseInstallLabel
@onready var download_course_button: Button = %DownloadCourseButton
@onready var golfers_container: VBoxContainer = %GolfersContainer
@onready var leave_lobby_button: Button = %LeaveLobbyButton
@onready var ready_toggle_button: Button = %ReadyToggleButton
@onready var start_match_button: Button = %StartMatchButton
@onready var confirm_leave_dialog: ConfirmationDialog = %ConfirmLeaveDialog

# â”€â”€ TOURNAMENTS SECTION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@onready var tournament_tab_bar: HBoxContainer = %TournamentTabBar
@onready var ttab_host_button: Button = %TTabHostButton
@onready var ttab_join_button: Button = %TTabJoinButton
@onready var ttab_public_button: Button = %TTabPublicButton
@onready var ttab_standings_button: Button = %TTabStandingsButton

# Tournament host view
@onready var tournament_host_view: VBoxContainer = %TournamentHostView
@onready var t_host_name_input: LineEdit = %THostNameInput
@onready var t_course_dropdown: OptionButton = %TCourseDropdown
@onready var t_length_option: OptionButton = %TLengthOption
@onready var t_mode_option: OptionButton = %TModeOption
@onready var t_wind_option: OptionButton = %TWindOption
@onready var t_green_speed_option: OptionButton = %TGreenSpeedOption
@onready var t_visibility_option: OptionButton = %TVisibilityOption
@onready var t_max_players_spinbox: SpinBox = %TMaxPlayersSpinBox
@onready var t_end_date_input: LineEdit = %TEndDateInput
@onready var t_gimme_mode_option: OptionButton = %TGimmeModeOption
@onready var t_host_gimme_params_container: PanelContainer = %THostGimmeParamsContainer
@onready var t_host_gimme_1_check: CheckBox = %THostGimme1Check
@onready var t_host_gimme_1_dist: SpinBox = %THostGimme1Dist
@onready var t_host_gimme_2_check: CheckBox = %THostGimme2Check
@onready var t_host_gimme_2_dist: SpinBox = %THostGimme2Dist
@onready var t_host_gimme_3_check: CheckBox = %THostGimme3Check
@onready var t_host_gimme_3_dist: SpinBox = %THostGimme3Dist
@onready var t_host_golfer_dropdown: OptionButton = %THostGolferDropdown
@onready var t_host_golfer_tee: OptionButton = %THostGolferTee
@onready var t_host_create_button: Button = %THostCreateButton
@onready var t_host_status_label: Label = %THostStatusLabel
@onready var t_host_success_panel: PanelContainer = %THostSuccessPanel
@onready var t_host_success_code_label: Label = %THostSuccessCodeLabel
@onready var t_host_copy_code_button: Button = %THostCopyCodeButton
@onready var t_host_success_end_date: Label = %THostSuccessEndDate

# Tournament join view
@onready var tournament_join_view: VBoxContainer = %TournamentJoinView
@onready var t_join_code_input: LineEdit = %TJoinCodeInput
@onready var t_join_paste_button: Button = %TJoinPasteButton
@onready var t_join_golfer_dropdown: OptionButton = %TJoinGolferDropdown
@onready var t_join_golfer_tee: OptionButton = %TJoinGolferTee
@onready var t_join_submit_button: Button = %TJoinSubmitButton
@onready var t_join_status_label: Label = %TJoinStatusLabel

# Tournament public view
@onready var tournament_public_view: VBoxContainer = %TournamentPublicView
@onready var t_public_refresh_button: Button = %TPublicRefreshButton
@onready var t_public_filter_time_option: OptionButton = %TPublicFilterTimeOption
@onready var t_public_filter_course_option: OptionButton = %TPublicFilterCourseOption
@onready var t_public_scroll: ScrollContainer = %TPublicScroll
@onready var t_public_list: VBoxContainer = %TPublicList
@onready var t_public_empty_label: Label = %TPublicEmptyLabel

# Tournament standings view
@onready var tournament_standings_view: VBoxContainer = %TournamentStandingsView
@onready var t_standings_filter_particip_option: OptionButton = %TStandingsFilterParticipOption
@onready var t_standings_filter_time_option: OptionButton = %TStandingsFilterTimeOption
@onready var t_standings_filter_course_option: OptionButton = %TStandingsFilterCourseOption
@onready var t_standings_refresh_button: Button = %TStandingsRefreshButton
@onready var t_standings_tournament_dropdown: OptionButton = %TStandingsTournamentDropdown
@onready var t_standings_meta: Label = %TStandingsMeta
@onready var t_standings_scroll: ScrollContainer = %TStandingsScroll
@onready var t_standings_list: VBoxContainer = %TStandingsList
@onready var t_standings_empty_label: Label = %TStandingsEmptyLabel

# â”€â”€ STATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
var _active_mode: String = "matches"   # "matches" | "tournaments"
var _active_tab: String = "host"       # "host" | "join_code" | "browser" | "room"
var _active_t_tab: String = "t_host"  # "t_host" | "t_join" | "t_public" | "t_standings"
var _available_courses: Array[Dictionary] = []
var _registered_players: Array[Dictionary] = []
var _missing_course_info: Dictionary = {}
var _is_downloading_course: bool = false
var _pending_spectate_match_id: String = ""
var _session_cache: Node = null

# Tournament state
var _t_available_courses: Array[Dictionary] = []  # same as _available_courses, re-used
var _standings_tournament_list: Array[Dictionary] = []
var _standings_selected_id: String = ""
var _t_last_created_code: String = ""


func _get_session() -> Node:
	if _session_cache != null and is_instance_valid(_session_cache):
		return _session_cache
	if has_node("/root/OnlineSession"):
		_session_cache = get_node("/root/OnlineSession")
		return _session_cache
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("OnlineSession"):
		_session_cache = loop.root.get_node("OnlineSession")
		return _session_cache
	return null


func _get_tournament_service() -> Node:
	return get_node_or_null("/root/TournamentService")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# â”€â”€ Matches mode signals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	back_button.pressed.connect(_on_back_pressed)
	account_button.pressed.connect(_on_account_pressed)
	mode_matches_button.pressed.connect(func(): _switch_mode("matches"))
	mode_tournaments_button.pressed.connect(func(): _switch_mode("tournaments"))
	tab_host_button.pressed.connect(func(): _switch_tab("host"))
	tab_join_code_button.pressed.connect(func(): _switch_tab("join_code"))
	tab_browser_button.pressed.connect(func(): _switch_tab("browser"))
	host_create_button.pressed.connect(_on_host_create_pressed)
	paste_code_button.pressed.connect(_on_paste_code_pressed)
	join_code_submit_button.pressed.connect(_on_join_code_submit_pressed)
	refresh_browser_button.pressed.connect(_on_refresh_browser_pressed)
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	download_course_button.pressed.connect(_on_download_course_pressed)
	ready_toggle_button.pressed.connect(_on_ready_toggle_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	leave_lobby_button.pressed.connect(_on_leave_lobby_pressed)
	confirm_leave_dialog.confirmed.connect(_confirm_leave_lobby)

	join_code_input.text_changed.connect(func(t: String):
		join_code_input.text = t.to_upper().strip_edges()
	)

	gimme_mode_option.item_selected.connect(func(idx):
		host_gimme_params_container.visible = (idx == 1)
		_update_controller_focus_navigation()
	)

	# â”€â”€ Tournament mode signals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	ttab_host_button.pressed.connect(func(): _switch_t_tab("t_host"))
	ttab_join_button.pressed.connect(func(): _switch_t_tab("t_join"))
	ttab_public_button.pressed.connect(func(): _switch_t_tab("t_public"))
	ttab_standings_button.pressed.connect(func(): _switch_t_tab("t_standings"))

	t_host_create_button.pressed.connect(_on_t_host_create_pressed)
	t_host_copy_code_button.pressed.connect(_on_t_copy_code_pressed)
	t_join_paste_button.pressed.connect(_on_t_join_paste_pressed)
	t_join_submit_button.pressed.connect(_on_t_join_submit_pressed)
	t_public_refresh_button.pressed.connect(_on_t_public_refresh_pressed)
	t_standings_refresh_button.pressed.connect(_on_t_standings_load_pressed)
	t_standings_tournament_dropdown.item_selected.connect(_on_t_standings_tournament_selected)
	t_standings_filter_particip_option.item_selected.connect(func(_i): _on_t_standings_load_pressed())
	t_standings_filter_time_option.item_selected.connect(func(_i): _on_t_standings_load_pressed())
	t_standings_filter_course_option.item_selected.connect(func(_i): _on_t_standings_load_pressed())
	t_public_filter_time_option.item_selected.connect(func(_i): _on_t_public_refresh_pressed())
	t_public_filter_course_option.item_selected.connect(func(_i): _on_t_public_refresh_pressed())

	t_join_code_input.text_changed.connect(func(t: String):
		t_join_code_input.text = t.to_upper().strip_edges()
	)

	t_gimme_mode_option.item_selected.connect(func(idx):
		t_host_gimme_params_container.visible = (idx == 1)
		_update_controller_focus_navigation()
	)

	# Connect OnlineSession signals
	var sess := _get_session()
	if sess != null:
		sess.lobby_updated.connect(_on_lobby_updated)
		sess.public_lobbies_loaded.connect(_on_public_lobbies_loaded)
		sess.lobby_error.connect(_on_lobby_error)
		sess.course_install_required.connect(_on_course_install_required)
		sess.match_started.connect(_on_match_started)
		sess.lobby_closed.connect(_on_lobby_closed)

	# Connect CloudAuth
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.has_signal("cloud_service_paused_changed"):
			ca.cloud_service_paused_changed.connect(_on_cloud_service_paused_changed)
		if ca.has_signal("auth_state_changed"):
			ca.auth_state_changed.connect(_on_cloud_auth_state_changed)

	_apply_styles()
	_populate_dropdowns()
	_update_user_status()
	_check_budget_pause()

	TouchScrollHelper.attach_to(browser_scroll)
	TouchScrollHelper.attach_to(t_public_scroll)
	TouchScrollHelper.attach_to(t_standings_scroll)

	if t_end_date_input != null and t_end_date_input.text.is_empty():
		var d = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 7 * 86400)
		t_end_date_input.text = "%04d-%02d-%02d %02d:00" % [d.year, d.month, d.day, d.hour]

	_switch_mode("matches")
	_switch_tab("host")
	_update_controller_focus_navigation()
	mode_matches_button.call_deferred("grab_focus")


func _apply_styles() -> void:
	ThemeManager.apply_nav_button_style(back_button, 6)
	ThemeManager.apply_nav_button_style(account_button, 6)
	ThemeManager.apply_primary_button_style(host_create_button, 8)
	ThemeManager.apply_primary_button_style(join_code_submit_button, 8)
	ThemeManager.apply_primary_button_style(start_match_button, 8)
	ThemeManager.apply_nav_button_style(paste_code_button, 6)
	ThemeManager.apply_nav_button_style(refresh_browser_button, 6)
	ThemeManager.apply_nav_button_style(copy_code_button, 6)
	ThemeManager.apply_secondary_button_style(ready_toggle_button, 8)
	ThemeManager.apply_danger_button_style(leave_lobby_button, 8)
	ThemeManager.apply_primary_button_style(download_course_button, 6)
	ThemeManager.apply_input_style(join_code_input)

	# Mode selector
	ThemeManager.apply_tab_button_style(mode_matches_button, true, 8)
	ThemeManager.apply_tab_button_style(mode_tournaments_button, false, 8)

	# Match tabs
	ThemeManager.apply_tab_button_style(tab_host_button, true, 6)
	ThemeManager.apply_tab_button_style(tab_join_code_button, false, 6)
	ThemeManager.apply_tab_button_style(tab_browser_button, false, 6)

	# Tournament tabs
	ThemeManager.apply_tab_button_style(ttab_host_button, true, 6)
	ThemeManager.apply_tab_button_style(ttab_join_button, false, 6)
	ThemeManager.apply_tab_button_style(ttab_public_button, false, 6)
	ThemeManager.apply_tab_button_style(ttab_standings_button, false, 6)

	# Tournament action buttons
	ThemeManager.apply_primary_button_style(t_host_create_button, 8)
	ThemeManager.apply_nav_button_style(t_host_copy_code_button, 6)
	ThemeManager.apply_nav_button_style(t_join_paste_button, 6)
	ThemeManager.apply_primary_button_style(t_join_submit_button, 8)
	ThemeManager.apply_nav_button_style(t_public_refresh_button, 6)
	ThemeManager.apply_primary_button_style(t_standings_refresh_button, 6)

	ThemeManager.apply_input_style(t_host_name_input)
	ThemeManager.apply_input_style(t_end_date_input)
	ThemeManager.apply_input_style(t_join_code_input)

	for opt in [
		course_dropdown, length_option, mode_option, turn_order_option,
		wind_option, green_speed_option, visibility_option, gimme_mode_option,
		host_golfer_dropdown, host_golfer_tee, join_golfer_dropdown, join_golfer_tee,
		t_course_dropdown, t_length_option, t_mode_option, t_wind_option,
		t_green_speed_option, t_visibility_option, t_gimme_mode_option,
		t_host_golfer_dropdown, t_host_golfer_tee,
		t_join_golfer_dropdown, t_join_golfer_tee,
		t_public_filter_time_option, t_public_filter_course_option,
		t_standings_filter_particip_option, t_standings_filter_time_option,
		t_standings_filter_course_option, t_standings_tournament_dropdown
	]:
		if opt != null:
			ThemeManager.apply_option_button_style(opt)

	if host_gimme_params_container != null:
		ThemeManager.apply_card_panel_style(host_gimme_params_container, false, 6, 12, 10, 12, 10)
	if t_host_gimme_params_container != null:
		ThemeManager.apply_card_panel_style(t_host_gimme_params_container, false, 6, 12, 10, 12, 10)


func _get_user_account_display_name(ca: Object) -> String:
	if ca == null:
		return ""
	var dname: String = str(ca.get_display_name()).strip_edges()
	if not dname.is_empty():
		return dname
	var email: String = str(ca.get_email()).strip_edges()
	if not email.is_empty():
		return email.split("@")[0]
	var uid: String = str(ca.get_uid()).strip_edges()
	if not uid.is_empty():
		return uid.substr(0, 8)
	return ""


func _update_user_status() -> void:
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.is_signed_in():
			var name_str := _get_user_account_display_name(ca)
			if name_str.is_empty():
				name_str = "Golfer"
			user_status_label.text = "Account: %s" % name_str
		elif ca.is_authenticated_any():
			var name_str := _get_user_account_display_name(ca)
			if name_str.is_empty():
				user_status_label.text = "Account: Anonymous"
			else:
				user_status_label.text = "Account: Anonymous (%s)" % name_str
		else:
			user_status_label.text = "Account: Not signed in"


func _on_cloud_auth_state_changed(_is_signed_in: bool, _user: Dictionary) -> void:
	_update_user_status()


func _on_account_pressed() -> void:
	if find_child("AccountModal", true, false) != null:
		return
	var modal_scene = load("res://UI/Account/account_modal.tscn")
	if modal_scene == null:
		return
	var modal = modal_scene.instantiate()
	modal.name = "AccountModal"
	if modal.has_signal("closed"):
		modal.closed.connect(func():
			_update_user_status()
			if account_button != null and is_instance_valid(account_button):
				account_button.call_deferred("grab_focus")
		)
	add_child(modal)


func _check_budget_pause() -> void:
	var paused := false
	if has_node("/root/CloudAuth"):
		paused = get_node("/root/CloudAuth").is_cloud_service_paused()

	host_create_button.disabled = paused
	join_code_submit_button.disabled = paused
	refresh_browser_button.disabled = paused
	t_host_create_button.disabled = paused
	t_join_submit_button.disabled = paused
	t_public_refresh_button.disabled = paused


func _on_cloud_service_paused_changed(is_paused: bool, _message: String) -> void:
	_check_budget_pause()
	var sess := _get_session()
	if is_paused and sess != null and sess.is_online_match:
		_show_status("Multiplayer service has been paused.", true)


# â”€â”€ MODE SWITCHING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _switch_mode(mode: String) -> void:
	_active_mode = mode
	var in_matches := (mode == "matches")
	ThemeManager.apply_tab_button_style(mode_matches_button, in_matches, 8)
	ThemeManager.apply_tab_button_style(mode_tournaments_button, not in_matches, 8)

	tab_bar.visible = in_matches and (_active_tab != "room")
	tournament_tab_bar.visible = not in_matches

	if in_matches:
		_switch_tab(_active_tab)
	else:
		_switch_t_tab(_active_t_tab)
func _switch_tab(tab_name: String) -> void:
	_active_tab = tab_name

	if host_status_label != null:
		host_status_label.text = ""
	if join_status_label != null:
		join_status_label.text = ""

	ThemeManager.apply_tab_button_style(tab_host_button, tab_name == "host", 6)
	ThemeManager.apply_tab_button_style(tab_join_code_button, tab_name == "join_code", 6)
	ThemeManager.apply_tab_button_style(tab_browser_button, tab_name == "browser", 6)

	host_view.visible = (tab_name == "host")
	join_code_view.visible = (tab_name == "join_code")
	browser_view.visible = (tab_name == "browser")
	lobby_room_view.visible = (tab_name == "room")
	tab_bar.visible = (tab_name != "room")

	tournament_host_view.visible = false
	tournament_join_view.visible = false
	tournament_public_view.visible = false
	tournament_standings_view.visible = false

	if tab_name == "browser":
		_on_refresh_browser_pressed()

	_update_controller_focus_navigation()
func _switch_t_tab(t_tab: String) -> void:
	_active_t_tab = t_tab

	ThemeManager.apply_tab_button_style(ttab_host_button, t_tab == "t_host", 6)
	ThemeManager.apply_tab_button_style(ttab_join_button, t_tab == "t_join", 6)
	ThemeManager.apply_tab_button_style(ttab_public_button, t_tab == "t_public", 6)
	ThemeManager.apply_tab_button_style(ttab_standings_button, t_tab == "t_standings", 6)

	host_view.visible = false
	join_code_view.visible = false
	browser_view.visible = false
	lobby_room_view.visible = false

	tournament_host_view.visible = (t_tab == "t_host")
	tournament_join_view.visible = (t_tab == "t_join")
	tournament_public_view.visible = (t_tab == "t_public")
	tournament_standings_view.visible = (t_tab == "t_standings")

	if t_tab == "t_host":
		_populate_t_courses()
	elif t_tab == "t_public":
		_on_t_public_refresh_pressed()
	elif t_tab == "t_standings":
		_on_t_standings_load_pressed()

	_update_controller_focus_navigation()
func _populate_dropdowns() -> void:
	# Course lengths
	length_option.clear()
	for l in ["Full 18", "Front 9", "Back 9"]:
		length_option.add_item(l)

	# Allowed online game modes
	mode_option.clear()
	for m in ["Standard", "Skins", "Closest to Pin"]:
		mode_option.add_item(m)

	# Turn order
	turn_order_option.clear()
	for o in ["Stay Up", "Classic", "Full Hole"]:
		turn_order_option.add_item(o)

	# Wind options
	wind_option.clear()
	for w in ["Calm / Off", "Light (3-7 mph)", "Moderate (8-14 mph)", "Breezy (15-20 mph)", "Windy (20+ mph)"]:
		wind_option.add_item(w)
	wind_option.select(1)

	# Green speeds
	green_speed_option.clear()
	for s in ["Slow", "Normal", "Fast", "Tour"]:
		green_speed_option.add_item(s)
	green_speed_option.select(1)

	# Visibility
	visibility_option.clear()
	visibility_option.add_item("Public")
	visibility_option.add_item("Private")

	# Tees
	for tee_opt in [host_golfer_tee, join_golfer_tee]:
		tee_opt.clear()
		for t in ["Black", "Blue", "White", "Red", "Gold"]:
			tee_opt.add_item(t)
		tee_opt.select(1) # Blue

	# Tournament dropdowns
	t_length_option.clear()
	for l in ["Full 18", "Front 9", "Back 9"]:
		t_length_option.add_item(l)

	t_mode_option.clear()
	for m in ["Standard", "Skins", "Closest to Pin"]:
		t_mode_option.add_item(m)

	t_wind_option.clear()
	for w in ["Calm / Off", "Light (3-7 mph)", "Moderate (8-14 mph)", "Breezy (15-20 mph)", "Windy (20+ mph)"]:
		t_wind_option.add_item(w)
	t_wind_option.select(1)

	t_green_speed_option.clear()
	for s in ["Slow", "Normal", "Fast", "Tour"]:
		t_green_speed_option.add_item(s)
	t_green_speed_option.select(1)

	t_visibility_option.clear()
	t_visibility_option.add_item("Public")
	t_visibility_option.add_item("Private")

	for tee_opt in [t_host_golfer_tee, t_join_golfer_tee]:
		tee_opt.clear()
		for t in ["Black", "Blue", "White", "Red", "Gold"]:
			tee_opt.add_item(t)
		tee_opt.select(1)

	# Gimme mode dropdowns
	gimme_mode_option.clear()
	gimme_mode_option.add_item("Use Local Settings")
	gimme_mode_option.add_item("Force Host Settings")
	gimme_mode_option.select(0)
	host_gimme_params_container.visible = false

	t_gimme_mode_option.clear()
	t_gimme_mode_option.add_item("Use Local Settings")
	t_gimme_mode_option.add_item("Force Host Settings")
	t_gimme_mode_option.select(0)
	t_host_gimme_params_container.visible = false

	_init_host_gimme_values()

	# Filter time period options (shared pattern)
	var time_labels := ["All Time", "Today", "This Week", "This Month", "Last 90 Days"]
	var time_values := ["all", "today", "this_week", "this_month", "last_90_days"]

	t_public_filter_time_option.clear()
	for i in range(time_labels.size()):
		t_public_filter_time_option.add_item(time_labels[i])

	t_standings_filter_time_option.clear()
	for i in range(time_labels.size()):
		t_standings_filter_time_option.add_item(time_labels[i])

	# Participation filter
	t_standings_filter_particip_option.clear()
	t_standings_filter_particip_option.add_item("All Tournaments")
	t_standings_filter_particip_option.add_item("Tournaments I Joined")

	# Players
	_populate_players()
	# Courses (matches)
	_populate_courses()


func _init_host_gimme_values() -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null and gs.range_settings != null:
		var rs = gs.range_settings
		if rs.gimme_range_1_enabled != null:
			host_gimme_1_check.button_pressed = bool(rs.gimme_range_1_enabled.value)
			t_host_gimme_1_check.button_pressed = bool(rs.gimme_range_1_enabled.value)
		if rs.gimme_range_1_distance != null:
			host_gimme_1_dist.value = float(rs.gimme_range_1_distance.value)
			t_host_gimme_1_dist.value = float(rs.gimme_range_1_distance.value)
		if rs.gimme_range_2_enabled != null:
			host_gimme_2_check.button_pressed = bool(rs.gimme_range_2_enabled.value)
			t_host_gimme_2_check.button_pressed = bool(rs.gimme_range_2_enabled.value)
		if rs.gimme_range_2_distance != null:
			host_gimme_2_dist.value = float(rs.gimme_range_2_distance.value)
			t_host_gimme_2_dist.value = float(rs.gimme_range_2_distance.value)
		if rs.gimme_range_3_enabled != null:
			host_gimme_3_check.button_pressed = bool(rs.gimme_range_3_enabled.value)
			t_host_gimme_3_check.button_pressed = bool(rs.gimme_range_3_enabled.value)
		if rs.gimme_range_3_distance != null:
			host_gimme_3_dist.value = float(rs.gimme_range_3_distance.value)
			t_host_gimme_3_dist.value = float(rs.gimme_range_3_distance.value)


func _populate_players() -> void:
	host_golfer_dropdown.clear()
	join_golfer_dropdown.clear()
	t_host_golfer_dropdown.clear()
	t_join_golfer_dropdown.clear()

	_registered_players.clear()
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and mp_mgr.has_method("get_registered_players"):
		for p_entry in mp_mgr.get_registered_players():
			if p_entry is Dictionary:
				_registered_players.append(p_entry)

	if _registered_players.is_empty():
		_registered_players.append({
			"name": "Player 1",
			"preferred_tee": "Blue",
			"avatar": "",
			"handedness": 0,
			"ball_graphic": "single_line"
		})

	for p in _registered_players:
		var p_name: String = p.get("name", "Player")
		host_golfer_dropdown.add_item(p_name)
		join_golfer_dropdown.add_item(p_name)
		t_host_golfer_dropdown.add_item(p_name)
		t_join_golfer_dropdown.add_item(p_name)

	host_golfer_dropdown.select(0)
	join_golfer_dropdown.select(0)
	t_host_golfer_dropdown.select(0)
	t_join_golfer_dropdown.select(0)


func _populate_courses() -> void:
	course_dropdown.clear()
	_available_courses.clear()

	var search_dirs := [
		"user://courses",
		"res://Courses/UserCourses",
		"res://Courses/Cached"
	]

	for base_dir in search_dirs:
		if not DirAccess.dir_exists_absolute(base_dir):
			continue
		var subdirs := DirAccess.get_directories_at(base_dir)
		for s in subdirs:
			if s.begins_with("."):
				continue
			var cfg_path: String = base_dir.path_join(str(s)).path_join("course.json")
			if not FileAccess.file_exists(cfg_path):
				continue
			var inspected := CourseFingerprintScript.inspect_course_config(cfg_path)
			if inspected.get("ok", false):
				_available_courses.append(inspected)

	for i in range(_available_courses.size()):
		var c = _available_courses[i]
		var title: String = c.get("title", "Unknown")
		var is_custom: bool = c.get("is_custom", false)
		if is_custom:
			title += " (Custom - Local Only)"
		course_dropdown.add_item(title, i)
		if is_custom:
			course_dropdown.set_item_disabled(i, true)
			course_dropdown.set_item_tooltip(i, "Custom local courses cannot be hosted online yet.")

	# Mirror to tournament course dropdown
	_populate_t_courses()


func _populate_t_courses() -> void:
	_t_available_courses = _available_courses.duplicate()
	t_course_dropdown.clear()

	# Filter dropdowns for standings/public
	t_public_filter_course_option.clear()
	t_public_filter_course_option.add_item("All Courses")
	t_standings_filter_course_option.clear()
	t_standings_filter_course_option.add_item("All Courses")

	for i in range(_t_available_courses.size()):
		var c = _t_available_courses[i]
		var title: String = c.get("title", "Unknown")
		var is_custom: bool = c.get("is_custom", false)
		if is_custom:
			t_course_dropdown.add_item(title + " (Custom - Local Only)", i)
			t_course_dropdown.set_item_disabled(i, true)
		else:
			t_course_dropdown.add_item(title, i)
			t_public_filter_course_option.add_item(title)
			t_standings_filter_course_option.add_item(title)


# â”€â”€ HOST MATCH FLOW (existing) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_host_create_pressed() -> void:
	if _available_courses.is_empty():
		_show_status("No valid courses installed.", true)
		return

	var sel_course_idx := course_dropdown.get_selected_id()
	if sel_course_idx < 0 or sel_course_idx >= _available_courses.size():
		_show_status("Please select a course to host.", true)
		return

	var course_data = _available_courses[sel_course_idx]
	if course_data.get("is_custom", false):
		_show_status("Custom courses cannot be hosted online.", true)
		return

	var settings := {
		"course_length": length_option.get_item_text(length_option.selected),
		"game_mode": mode_option.get_item_text(mode_option.selected),
		"turn_order_mode": turn_order_option.get_item_text(turn_order_option.selected),
		"green_speed": green_speed_option.get_item_text(green_speed_option.selected),
		"pin_seed": randi()
	}

	var force_gimmes := (gimme_mode_option.selected == 1)
	settings["force_gimmes"] = force_gimmes
	if force_gimmes:
		settings["gimme_range_1_enabled"] = host_gimme_1_check.button_pressed
		settings["gimme_range_1_distance"] = float(host_gimme_1_dist.value)
		settings["gimme_range_2_enabled"] = host_gimme_2_check.button_pressed
		settings["gimme_range_2_distance"] = float(host_gimme_2_dist.value)
		settings["gimme_range_3_enabled"] = host_gimme_3_check.button_pressed
		settings["gimme_range_3_distance"] = float(host_gimme_3_dist.value)

	# Wind mapping
	var wind_idx := wind_option.selected
	var wind_speed := 0.0
	match wind_idx:
		1: wind_speed = 5.0
		2: wind_speed = 10.0
		3: wind_speed = 17.0
		4: wind_speed = 24.0
	settings["wind_speed_mph"] = wind_speed
	settings["wind_dir_rad"] = randf() * TAU

	var visibility := "public" if visibility_option.selected == 0 else "private"

	var local_golfers: Array[Dictionary] = [_get_selected_golfer(host_golfer_dropdown, host_golfer_tee)]

	host_create_button.disabled = true
	_show_status("Creating lobby...", false)

	var sess := _get_session()
	if sess == null:
		_show_status("Online session not initialized.", true)
		host_create_button.disabled = false
		return

	var res = await sess.create_lobby(
		course_data.get("config_path", ""),
		settings,
		visibility,
		local_golfers
	)

	host_create_button.disabled = false
	if res.get("ok", false):
		_switch_tab("room")
		_on_lobby_updated(sess.match_meta, sess.match_devices, sess.match_golfers)
	else:
		_show_status(res.get("error", "Failed to create lobby"), true)


func _get_selected_golfer(dropdown: OptionButton, tee_opt: OptionButton) -> Dictionary:
	var sel_idx := dropdown.selected
	var base_profile: Dictionary = _registered_players[sel_idx] if sel_idx < _registered_players.size() else {}
	var golfer := base_profile.duplicate()
	golfer["name"] = dropdown.get_item_text(sel_idx)
	golfer["tee"] = tee_opt.get_item_text(tee_opt.selected)
	return golfer


# â”€â”€ JOIN BY CODE FLOW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_paste_code_pressed() -> void:
	var clip := DisplayServer.clipboard_get().strip_edges().to_upper()
	if not clip.is_empty():
		join_code_input.text = clip.substr(0, 6)


func _on_join_code_submit_pressed() -> void:
	var code := join_code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		_show_status("Please enter a valid 6-character code.", true)
		return

	var local_golfers: Array[Dictionary] = [_get_selected_golfer(join_golfer_dropdown, join_golfer_tee)]

	join_code_submit_button.disabled = true
	_show_status("Joining match...", false)

	var sess := _get_session()
	if sess == null:
		_show_status("Online session not initialized.", true)
		join_code_submit_button.disabled = false
		return

	var res = await sess.join_by_code(code, local_golfers)
	join_code_submit_button.disabled = false

	if res.get("ok", false):
		_switch_tab("room")
		_on_lobby_updated(sess.match_meta, sess.match_devices, sess.match_golfers)
	else:
		_show_status(res.get("error", "Failed to join lobby."), true)


# â”€â”€ PUBLIC BROWSER FLOW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_refresh_browser_pressed() -> void:
	refresh_browser_button.disabled = true
	_clear_browser_list()
	no_lobbies_label.visible = true
	no_lobbies_label.text = "Fetching public matches..."

	var sess := _get_session()
	if sess != null:
		await sess.fetch_public_lobbies()
	refresh_browser_button.disabled = false


func _on_public_lobbies_loaded(lobbies: Array[Dictionary]) -> void:
	_clear_browser_list()
	if lobbies.is_empty():
		no_lobbies_label.visible = true
		no_lobbies_label.text = "No active public lobbies found. Host a match to invite other players!"
	else:
		no_lobbies_label.visible = false
		for lobby_item in lobbies:
			_add_browser_lobby_row(lobby_item)

	_update_controller_focus_navigation()


func _clear_browser_list() -> void:
	for c in browser_list.get_children():
		if c != no_lobbies_label:
			c.queue_free()


func _add_browser_lobby_row(lobby_data: Dictionary) -> void:
	var card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(card, false, 8, 12, 10, 12, 10)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var status: String = str(lobby_data.get("status", "lobby"))
	var is_in_progress: bool = (status == "in_progress" or status == "active")
	var status_tag: String = "[In Progress]" if is_in_progress else "[In Lobby]"

	var title_lbl := Label.new()
	title_lbl.text = "%s â€” %s (%s) %s" % [
		lobby_data.get("course_title", "Unknown Course"),
		lobby_data.get("course_length", "Full 18"),
		lobby_data.get("game_mode", "Standard"),
		status_tag
	]
	title_lbl.add_theme_font_size_override("font_size", 15)
	info_vbox.add_child(title_lbl)

	var host_lbl := Label.new()
	var player_cnt: int = int(lobby_data.get("player_count", 1))
	var max_p: int = int(lobby_data.get("max_players", 4))
	host_lbl.text = "Host: %s | Players: %d/%d" % [
		lobby_data.get("host_name", "Host"),
		player_cnt,
		max_p
	]
	host_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	host_lbl.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(host_lbl)

	var match_id: String = str(lobby_data.get("match_id", ""))

	if is_in_progress:
		var spectate_btn := Button.new()
		spectate_btn.name = "SpectateBtn"
		spectate_btn.text = "Spectate"
		spectate_btn.custom_minimum_size = Vector2(110, 38)
		ThemeManager.apply_primary_button_style(spectate_btn, 6)
		spectate_btn.pressed.connect(func(): _on_spectate_browser_match(match_id, lobby_data))
		hbox.add_child(spectate_btn)
	else:
		if player_cnt < max_p:
			var join_btn := Button.new()
			join_btn.name = "JoinBtn"
			join_btn.text = "Join"
			join_btn.custom_minimum_size = Vector2(90, 38)
			ThemeManager.apply_primary_button_style(join_btn, 6)
			join_btn.pressed.connect(func(): _on_join_browser_lobby(match_id))
			hbox.add_child(join_btn)

		var spectate_btn := Button.new()
		spectate_btn.name = "SpectateBtn"
		spectate_btn.text = "Spectate"
		spectate_btn.custom_minimum_size = Vector2(90, 38)
		ThemeManager.apply_secondary_button_style(spectate_btn, 6)
		spectate_btn.pressed.connect(func(): _on_spectate_browser_match(match_id, lobby_data))
		hbox.add_child(spectate_btn)

	browser_list.add_child(card)


func _on_join_browser_lobby(match_id: String) -> void:
	var local_golfers: Array[Dictionary] = [_get_selected_golfer(host_golfer_dropdown, host_golfer_tee)]
	_show_status("Joining public match...", false)

	var sess := _get_session()
	if sess == null:
		return

	var res = await sess.join_by_match_id(match_id, local_golfers)
	if res.get("ok", false):
		_switch_tab("room")
		_on_lobby_updated(sess.match_meta, sess.match_devices, sess.match_golfers)
	else:
		_show_status(res.get("error", "Failed to join match."), true)


func _on_spectate_browser_match(match_id: String, _lobby_data: Dictionary = {}) -> void:
	_show_status("Connecting to spectate match...", false)
	var sess := _get_session()
	if sess == null:
		return

	var res = await sess.spectate_match(match_id)
	if res.get("ok", false):
		_show_status("Spectating match!", false)
	elif res.get("need_course", false):
		_pending_spectate_match_id = match_id
		_show_status("Course download required to spectate.", false)
	else:
		_show_status(res.get("error", "Failed to spectate match."), true)


# â”€â”€ LOBBY ROOM VIEW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_lobby_updated(meta: Dictionary, devices: Dictionary, golfers: Dictionary) -> void:
	if _active_tab != "room":
		_switch_tab("room")
	if _active_mode != "matches":
		_switch_mode("matches")

	var sess := _get_session()
	var cur_code: String = sess.current_join_code if sess != null else ""
	room_code_label.text = cur_code if not cur_code.is_empty() else "â€”"

	var course: Dictionary = meta.get("course", {})
	var settings: Dictionary = meta.get("settings", {})
	var gimme_str: String = "Forced Host Gimmes" if bool(settings.get("force_gimmes", false)) else "Local Gimmes"
	room_details_label.text = "%s | %s | %s | %s" % [
		course.get("title", "Course"),
		settings.get("course_length", "Full 18"),
		settings.get("game_mode", "Standard"),
		gimme_str
	]

	var my_uid: String = sess._get_my_uid() if sess != null else ""
	var is_host: bool = sess.is_host if sess != null else false
	start_match_button.visible = is_host

	var all_ready := true
	for dev_id in devices.keys():
		var dev = devices[dev_id]
		if not bool(dev.get("course_ready", false)) or not bool(dev.get("ready", false)):
			all_ready = false
			break

	start_match_button.disabled = (golfers.size() < 2 or not all_ready)

	var my_dev = devices.get(my_uid, {})
	var is_my_device_ready: bool = bool(my_dev.get("ready", false))
	ready_toggle_button.text = "I'm Not Ready" if is_my_device_ready else "Ready Up!"

	_render_room_golfers(golfers, devices)
	_update_controller_focus_navigation()


func _render_room_golfers(golfers: Dictionary, devices: Dictionary) -> void:
	for c in golfers_container.get_children():
		c.queue_free()

	var sorted_slots: Array = golfers.keys()
	sorted_slots.sort_custom(func(a, b):
		return int(golfers[a].get("order", 0)) < int(golfers[b].get("order", 0))
	)

	var sess := _get_session()
	var my_uid: String = sess._get_my_uid() if sess != null else ""
	var is_host: bool = sess.is_host if sess != null else false

	for slot_id in sorted_slots:
		var g = golfers[slot_id]
		var card := PanelContainer.new()
		ThemeManager.apply_card_panel_style(card, false, 8, 12, 8, 12, 8)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		card.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = "%s. %s (%s Tee)" % [
			str(int(g.get("order", 0)) + 1),
			g.get("name", "Player"),
			g.get("tee", "Blue")
		]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var owner_uid: String = g.get("owner_uid", "")
		var dev = devices.get(owner_uid, {})
		var dev_ready: bool = bool(dev.get("ready", false))
		var dev_course_ready: bool = bool(dev.get("course_ready", false))
		var dev_course_downloading: bool = bool(dev.get("course_downloading", false))
		if owner_uid == my_uid and _is_downloading_course:
			dev_course_downloading = true

		var status_lbl := Label.new()
		if not dev_course_ready:
			if dev_course_downloading:
				status_lbl.text = "Downloading Course..."
				status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WARNING)
			else:
				status_lbl.text = "Missing Course"
				status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DANGER)
		elif dev_ready:
			status_lbl.text = "Ready"
			status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
		else:
			status_lbl.text = "Not Ready"
			status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		hbox.add_child(status_lbl)

		if is_host and owner_uid != my_uid:
			var kick_btn := Button.new()
			kick_btn.text = "Kick"
			ThemeManager.apply_danger_button_style(kick_btn, 4)
			kick_btn.pressed.connect(func():
				if sess != null:
					sess.kick_device(owner_uid)
			)
			hbox.add_child(kick_btn)

		golfers_container.add_child(card)


func _on_course_install_required(course_info: Dictionary, _reason: String) -> void:
	_missing_course_info = course_info
	course_install_banner.visible = true
	var title: String = course_info.get("title", "Course")
	course_install_label.text = "Course Required: '%s' is not installed or has a different version." % title


func _on_download_course_pressed() -> void:
	if _is_downloading_course:
		return

	_is_downloading_course = true
	download_course_button.disabled = true
	course_install_label.text = "Downloading & Generating 3D Course Geometry..."

	var sess := _get_session()
	if sess != null and sess.has_method("set_local_course_downloading"):
		sess.set_local_course_downloading(true)
	elif _active_tab == "room":
		_render_room_golfers(sess.match_golfers if sess != null else {}, sess.match_devices if sess != null else {})

	var lat: float = float(_missing_course_info.get("lat", 0.0))
	var lon: float = float(_missing_course_info.get("lon", 0.0))
	var title: String = _missing_course_info.get("title", "")
	var is_cached: bool = bool(_missing_course_info.get("is_cached", false))
	var location: String = _missing_course_info.get("location", "")

	var loader_script = load("res://Courses/OsmMapLoader.cs")
	if loader_script != null:
		var loader = loader_script.new()
		add_child(loader)
		if loader.has_method("DownloadAndGenerateCourse"):
			loader.call("DownloadAndGenerateCourse", lat, lon, title, is_cached, location)
			var success = await loader.CourseGenerated
			loader.queue_free()

			if success:
				var found = CourseFingerprintScript.find_installed_course(_missing_course_info.get("key", ""), lat, lon, title)
				if not found.is_empty():
					if sess != null:
						sess.set_local_course_ready(true, found.get("scene_path", ""), found.get("config_path", ""))
					course_install_banner.visible = false
					_show_status("Course installed and ready!", false)
					if not _pending_spectate_match_id.is_empty():
						var target_spec_id := _pending_spectate_match_id
						_pending_spectate_match_id = ""
						_on_spectate_browser_match(target_spec_id)
				else:
					if sess != null and sess.has_method("set_local_course_downloading"):
						sess.set_local_course_downloading(false)
					course_install_label.text = "Installed course could not be verified."
			else:
				if sess != null and sess.has_method("set_local_course_downloading"):
					sess.set_local_course_downloading(false)
				course_install_label.text = "Course download failed. Please retry."
		else:
			if sess != null and sess.has_method("set_local_course_downloading"):
				sess.set_local_course_downloading(false)
			course_install_label.text = "DownloadAndGenerateCourse method not found."
	else:
		if sess != null and sess.has_method("set_local_course_downloading"):
			sess.set_local_course_downloading(false)
		course_install_label.text = "OsmMapLoader script not found."

	_is_downloading_course = false
	download_course_button.disabled = false


func _on_ready_toggle_pressed() -> void:
	var sess := _get_session()
	if sess != null:
		sess.set_local_device_ready(!sess.is_local_device_ready)


func _on_start_match_pressed() -> void:
	start_match_button.disabled = true
	var sess := _get_session()
	if sess == null:
		return
	var res = await sess.start_online_match()
	if not res.get("ok", false):
		start_match_button.disabled = false
		_show_status(res.get("error", "Failed to start match."), true)


func _on_copy_code_pressed() -> void:
	var sess := _get_session()
	var code: String = sess.current_join_code if sess != null else ""
	if not code.is_empty():
		DisplayServer.clipboard_set(code)
		copy_code_button.text = "Copied!"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(copy_code_button):
				copy_code_button.text = "Copy Code"
		)


func _on_leave_lobby_pressed() -> void:
	var sess := _get_session()
	if sess != null and sess.is_host and sess.match_meta.get("status", "") == "lobby":
		confirm_leave_dialog.popup_centered()
	else:
		_confirm_leave_lobby()


func _confirm_leave_lobby() -> void:
	var sess := _get_session()
	if sess != null:
		if sess.has_method("set_local_course_downloading"):
			sess.set_local_course_downloading(false)
		sess.leave_lobby()
	_is_downloading_course = false
	course_install_banner.visible = false
	_switch_tab("host")


func _on_lobby_closed(reason: String) -> void:
	course_install_banner.visible = false
	_is_downloading_course = false
	if _active_tab == "room":
		_switch_tab("host")
		_show_status("Lobby closed: %s" % reason, false)


func _on_match_started(match_id: String, _meta: Dictionary, _golfers: Array[Dictionary]) -> void:
	print("[OnlineMultiplayerMenu] Online match %s started! Transitioning to runtime..." % match_id)
	# Package 09 (OnlineMatchController) configures MultiplayerManager and loads course


func _on_lobby_error(code: String, message: String) -> void:
	_show_status("[%s] %s" % [code, message], true)


# â”€â”€ TOURNAMENT: HOST â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_t_host_create_pressed() -> void:
	if _t_available_courses.is_empty():
		_show_t_status("No valid courses installed.", true)
		return

	var sel_idx := t_course_dropdown.get_selected_id()
	if sel_idx < 0 or sel_idx >= _t_available_courses.size():
		_show_t_status("Please select a course.", true)
		return

	var course_data = _t_available_courses[sel_idx]
	if course_data.get("is_custom", false):
		_show_t_status("Custom courses cannot be used for tournaments.", true)
		return

	var end_str: String = t_end_date_input.text.strip_edges()
	if end_str.length() < 10:
		_show_t_status("Please enter a valid end date (YYYY-MM-DD HH:MM).", true)
		return

	var ts_svc := _get_tournament_service()
	if ts_svc == null:
		_show_t_status("Tournament service unavailable.", true)
		return

	var wind_speed := 0.0
	match t_wind_option.selected:
		1: wind_speed = 5.0
		2: wind_speed = 10.0
		3: wind_speed = 17.0
		4: wind_speed = 24.0

	var golfer_name: String = t_host_golfer_dropdown.get_item_text(t_host_golfer_dropdown.selected)
	var tee_str: String = t_host_golfer_tee.get_item_text(t_host_golfer_tee.selected)

	var tournament_name: String = t_host_name_input.text.strip_edges()
	if tournament_name.is_empty():
		tournament_name = "%s's Tournament" % golfer_name

	var settings := {
		"name": tournament_name,
		"course_key": course_data.get("key", course_data.get("title", "").to_lower().replace(" ", "_")),
		"course_title": course_data.get("title", ""),
		"course_length": t_length_option.get_item_text(t_length_option.selected),
		"game_mode": t_mode_option.get_item_text(t_mode_option.selected),
		"wind_speed_mph": wind_speed,
		"wind_dir_rad": randf() * TAU,
		"green_speed": t_green_speed_option.get_item_text(t_green_speed_option.selected),
		"pin_seed": randi(),
		"tee": tee_str,
		"visibility": "public" if t_visibility_option.selected == 0 else "private",
		"max_players": int(t_max_players_spinbox.value),
		"end_date_utc": end_str,
		"player_name": golfer_name
	}

	var t_force_gimmes := (t_gimme_mode_option.selected == 1)
	settings["force_gimmes"] = t_force_gimmes
	if t_force_gimmes:
		settings["gimme_range_1_enabled"] = t_host_gimme_1_check.button_pressed
		settings["gimme_range_1_distance"] = float(t_host_gimme_1_dist.value)
		settings["gimme_range_2_enabled"] = t_host_gimme_2_check.button_pressed
		settings["gimme_range_2_distance"] = float(t_host_gimme_2_dist.value)
		settings["gimme_range_3_enabled"] = t_host_gimme_3_check.button_pressed
		settings["gimme_range_3_distance"] = float(t_host_gimme_3_dist.value)

	t_host_create_button.disabled = true
	t_host_success_panel.visible = false
	_show_t_status("Creating tournament...", false)

	var res: Dictionary = await ts_svc.create_tournament(settings)
	t_host_create_button.disabled = false

	if res.get("ok", false):
		var code: String = res.get("join_code", "")
		var t_data: Dictionary = res.get("data", {})
		_t_last_created_code = code

		t_host_success_panel.visible = true
		t_host_success_code_label.text = "Join Code: %s" % code
		var end_unix: int = ts_svc.call("_parse_date_utc", end_str)
		t_host_success_end_date.text = "Ends: %s" % ts_svc.format_end_date(end_unix)
		_show_t_status("Tournament created successfully!", false)
	else:
		_show_t_status(res.get("error", "Failed to create tournament."), true)


func _on_t_copy_code_pressed() -> void:
	if not _t_last_created_code.is_empty():
		DisplayServer.clipboard_set(_t_last_created_code)
		t_host_copy_code_button.text = "Copied!"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(t_host_copy_code_button):
				t_host_copy_code_button.text = "Copy Code"
		)


# â”€â”€ TOURNAMENT: JOIN â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_t_join_paste_pressed() -> void:
	var clip := DisplayServer.clipboard_get().strip_edges().to_upper()
	if not clip.is_empty():
		t_join_code_input.text = clip.substr(0, 6)


func _on_t_join_submit_pressed() -> void:
	var code := t_join_code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		_show_t_status("Please enter a valid 6-character tournament code.", true)
		return

	var ts_svc := _get_tournament_service()
	if ts_svc == null:
		_show_t_status("Tournament service unavailable.", true)
		return

	var player_name: String = t_join_golfer_dropdown.get_item_text(t_join_golfer_dropdown.selected)
	var tee_str: String = t_join_golfer_tee.get_item_text(t_join_golfer_tee.selected)

	t_join_submit_button.disabled = true
	_show_t_status("Joining tournament...", false)

	var res: Dictionary = await ts_svc.join_tournament(code, player_name, tee_str)
	t_join_submit_button.disabled = false

	if res.get("ok", false):
		var t_data: Dictionary = res.get("data", {})
		var end_str: String = t_data.get("end_date_utc", "")
		var end_unix: int = ts_svc.call("_parse_date_utc", end_str)
		var end_formatted: String = ts_svc.format_end_date(end_unix)
		_show_t_status(
			"Joined! Course: %s (%s) â€” Ends %s" % [
				t_data.get("course_title", ""),
				t_data.get("course_length", ""),
				end_formatted
			],
			false
		)
	else:
		_show_t_status(res.get("error", "Failed to join tournament."), true)


# â”€â”€ TOURNAMENT: PUBLIC BROWSER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_t_public_refresh_pressed() -> void:
	t_public_refresh_button.disabled = true
	_clear_t_public_list()
	t_public_empty_label.visible = true
	t_public_empty_label.text = "Fetching public tournaments..."

	var ts_svc := _get_tournament_service()
	if ts_svc == null:
		t_public_empty_label.text = "Tournament service unavailable."
		t_public_refresh_button.disabled = false
		return

	var filters := {
		"time_frame": _time_filter_value(t_public_filter_time_option.selected),
		"course_key": _course_filter_key(t_public_filter_course_option)
	}

	var res: Dictionary = await ts_svc.fetch_public_tournaments(filters)
	t_public_refresh_button.disabled = false

	if not res.get("ok", false):
		t_public_empty_label.visible = true
		t_public_empty_label.text = _format_tournament_error(res.get("error", "Failed to load tournaments."))
		return

	var docs: Array = res.get("documents", [])
	_clear_t_public_list()
	if docs.is_empty():
		t_public_empty_label.visible = true
		t_public_empty_label.text = "No public tournaments found. Try different filters or host one!"
	else:
		t_public_empty_label.visible = false
		for t_doc in docs:
			_add_t_public_row(t_doc)


func _clear_t_public_list() -> void:
	for c in t_public_list.get_children():
		if c != t_public_empty_label:
			c.queue_free()


func _add_t_public_row(t_doc: Dictionary) -> void:
	var ts_svc := _get_tournament_service()
	var card := PanelContainer.new()
	ThemeManager.apply_card_panel_style(card, false, 8, 12, 10, 12, 10)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	vbox.add_child(hrow)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(info_vbox)

	var is_ended: bool = ts_svc != null and ts_svc.is_tournament_ended(t_doc)
	var status_str: String = "[Ended]" if is_ended else "[Open]"

	var title_lbl := Label.new()
	title_lbl.text = "%s â€” %s %s" % [
		t_doc.get("name", "Tournament"),
		t_doc.get("course_title", "Unknown Course"),
		status_str
	]
	title_lbl.add_theme_font_size_override("font_size", 15)
	if is_ended:
		title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	info_vbox.add_child(title_lbl)

	var details_lbl := Label.new()
	var player_cnt: int = int(t_doc.get("player_count", 0))
	var max_p: int = int(t_doc.get("max_players", 20))
	var end_unix: int = 0
	if ts_svc != null:
		end_unix = ts_svc.call("_parse_date_utc", t_doc.get("end_date_utc", ""))
	var end_str: String = ts_svc.format_end_date(end_unix) if ts_svc != null else t_doc.get("end_date_utc", "")

	details_lbl.text = "Host: %s | %s | %s | Players: %d/%d | Ends: %s" % [
		t_doc.get("host_name", "Host"),
		t_doc.get("course_length", "Full 18"),
		t_doc.get("game_mode", "Standard"),
		player_cnt, max_p, end_str
	]
	details_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
	details_lbl.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(details_lbl)

	# Action buttons
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 6)
	hrow.add_child(btn_vbox)

	var is_joined: bool = ts_svc != null and ts_svc.is_joined(t_doc.get("tournament_id", ""))
	if is_joined:
		var joined_lbl := Label.new()
		joined_lbl.text = "âœ“ Joined"
		joined_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
		joined_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_vbox.add_child(joined_lbl)
	elif not is_ended and player_cnt < max_p:
		var join_btn := Button.new()
		join_btn.text = "Join"
		join_btn.custom_minimum_size = Vector2(100, 36)
		ThemeManager.apply_primary_button_style(join_btn, 6)
		var t_id: String = t_doc.get("tournament_id", "")
		var join_code: String = t_doc.get("join_code", "")
		join_btn.pressed.connect(func(): _on_t_quick_join(join_code, t_doc))
		btn_vbox.add_child(join_btn)
	elif is_ended or player_cnt >= max_p:
		var full_lbl := Label.new()
		full_lbl.text = "Full" if player_cnt >= max_p else "Ended"
		full_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		full_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_vbox.add_child(full_lbl)

	var standings_btn := Button.new()
	standings_btn.text = "Standings"
	standings_btn.custom_minimum_size = Vector2(100, 36)
	ThemeManager.apply_secondary_button_style(standings_btn, 6)
	var t_id_for_standings: String = t_doc.get("tournament_id", "")
	standings_btn.pressed.connect(func(): _open_standings_for(t_id_for_standings, t_doc))
	btn_vbox.add_child(standings_btn)

	t_public_list.add_child(card)


func _on_t_quick_join(join_code: String, t_doc: Dictionary) -> void:
	if join_code.is_empty():
		return
	var ts_svc := _get_tournament_service()
	if ts_svc == null:
		return
	var player_name: String = t_host_golfer_dropdown.get_item_text(t_host_golfer_dropdown.selected)
	var tee_str: String = t_host_golfer_tee.get_item_text(t_host_golfer_tee.selected)

	var res: Dictionary = await ts_svc.join_tournament(join_code, player_name, tee_str)
	if res.get("ok", false):
		_on_t_public_refresh_pressed()
	else:
		t_public_empty_label.visible = true
		t_public_empty_label.text = _format_tournament_error(res.get("error", "Failed to join."))


func _open_standings_for(tournament_id: String, _t_doc: Dictionary) -> void:
	_switch_t_tab("t_standings")
	_standings_selected_id = tournament_id
	_load_standings_for_id(tournament_id)


# â”€â”€ TOURNAMENT: STANDINGS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_t_standings_load_pressed() -> void:
	t_standings_refresh_button.disabled = true
	_clear_standings_list()
	t_standings_meta.text = "Loading tournaments..."
	t_standings_tournament_dropdown.clear()
	_standings_tournament_list.clear()

	var ts_svc := _get_tournament_service()
	if ts_svc == null:
		t_standings_meta.text = "Tournament service unavailable."
		t_standings_refresh_button.disabled = false
		return

	var particip_idx: int = t_standings_filter_particip_option.selected
	var time_filter: String = _time_filter_value(t_standings_filter_time_option.selected)
	var course_key: String = _course_filter_key(t_standings_filter_course_option)

	var docs: Array = []

	if particip_idx == 1:
		# My tournaments only
		var res: Dictionary = await ts_svc.fetch_my_tournaments()
		docs = res.get("documents", [])
	else:
		# All public + my private
		var pub_filters := {"time_frame": time_filter}
		if not course_key.is_empty():
			pub_filters["course_key"] = course_key
		var res: Dictionary = await ts_svc.fetch_public_tournaments(pub_filters)
		docs = res.get("documents", [])

		# Also merge in any private tournaments I've joined
		var my_res: Dictionary = await ts_svc.fetch_my_tournaments()
		for my_t in my_res.get("documents", []):
			if my_t.get("visibility", "public") == "private":
				var already: bool = false
				for d in docs:
					if d.get("tournament_id", "") == my_t.get("tournament_id", ""):
						already = true
						break
				if not already:
					docs.append(my_t)

	# Apply course filter post-fetch for my_tournaments path
	if not course_key.is_empty():
		docs = docs.filter(func(d): return d.get("course_key", "") == course_key)

	# Apply time filter post-fetch
	if time_filter != "all":
		var cutoff: float = ts_svc.call("_time_frame_cutoff", time_filter)
		docs = docs.filter(func(d): return int(d.get("created_at", 0)) >= int(cutoff))

	t_standings_refresh_button.disabled = false

	if docs.is_empty():
		t_standings_meta.text = "No tournaments found. Try different filters."
		return

	_standings_tournament_list = docs
	t_standings_tournament_dropdown.clear()
	for t_doc in docs:
		var ended: bool = ts_svc.is_tournament_ended(t_doc)
		var label: String = "%s â€” %s [%s]" % [
			t_doc.get("name", "Tournament"),
			t_doc.get("course_title", ""),
			"Ended" if ended else "Open"
		]
		t_standings_tournament_dropdown.add_item(label)

	t_standings_meta.text = "%d tournament(s) found. Select one to view standings." % docs.size()

	# If we navigated here from a specific tournament, auto-select it
	if not _standings_selected_id.is_empty():
		for i in range(_standings_tournament_list.size()):
			if _standings_tournament_list[i].get("tournament_id", "") == _standings_selected_id:
				t_standings_tournament_dropdown.select(i)
				_load_standings_for_id(_standings_selected_id)
				break
		_standings_selected_id = ""


func _on_t_standings_tournament_selected(idx: int) -> void:
	if idx < 0 or idx >= _standings_tournament_list.size():
		return
	var t_doc: Dictionary = _standings_tournament_list[idx]
	_load_standings_for_id(t_doc.get("tournament_id", ""))


func _load_standings_for_id(tournament_id: String) -> void:
	if tournament_id.is_empty():
		return

	_clear_standings_list()
	t_standings_meta.text = "Loading standings..."

	var ts_svc := _get_tournament_service()
	if ts_svc == null:
		return

	var res: Dictionary = await ts_svc.fetch_standings(tournament_id)
	if not res.get("ok", false):
		t_standings_meta.text = "Failed to load standings: %s" % _format_tournament_error(res.get("error", ""))
		return

	var entries: Array = res.get("documents", [])
	var meta: Dictionary = res.get("meta", {})
	var t_name: String = meta.get("name", "Tournament")
	var ended: bool = ts_svc.is_tournament_ended(meta)
	var end_unix: int = ts_svc.call("_parse_date_utc", meta.get("end_date_utc", ""))
	var end_formatted: String = ts_svc.format_end_date(end_unix)

	var status_str: String = "ENDED â€” Winners Locked" if ended else "OPEN â€” Ends %s" % end_formatted
	t_standings_meta.text = "%s | %s (%s) | %s" % [
		t_name,
		meta.get("course_title", ""),
		meta.get("course_length", ""),
		status_str
	]

	if entries.is_empty():
		t_standings_empty_label.visible = true
		t_standings_empty_label.text = "No entries yet. Be the first to submit a score!"
		return

	t_standings_empty_label.visible = false
	_render_standings_table(entries, meta)


func _clear_standings_list() -> void:
	for c in t_standings_list.get_children():
		if c != t_standings_empty_label:
			c.queue_free()


func _render_standings_table(entries: Array, meta: Dictionary) -> void:
	var my_uid: String = ""
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.has_method("get_uid"):
			my_uid = str(ca.get_uid())

	var expected_holes: int = 18
	var length: String = meta.get("course_length", "Full 18")
	if length in ["Front 9", "Back 9"]:
		expected_holes = 9

	# Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	t_standings_list.add_child(header_hbox)

	for col_text in ["#", "Player", "Tee", "Holes", "Total", "To Par", "Status"]:
		var lbl := Label.new()
		lbl.text = col_text
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		match col_text:
			"#":
				lbl.custom_minimum_size = Vector2(32, 0)
			"Player":
				lbl.custom_minimum_size = Vector2(160, 0)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			"Tee", "Status":
				lbl.custom_minimum_size = Vector2(80, 0)
			_:
				lbl.custom_minimum_size = Vector2(64, 0)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_hbox.add_child(lbl)

	# Separator
	var sep := HSeparator.new()
	t_standings_list.add_child(sep)

	# Entry rows
	for rank_idx in range(entries.size()):
		var entry: Dictionary = entries[rank_idx]
		var e_status: String = entry.get("status", "pending")
		var is_mine: bool = (entry.get("uid", "") == my_uid)

		var row_panel := PanelContainer.new()
		if is_mine:
			ThemeManager.apply_card_panel_style(row_panel, true, 4, 10, 4, 10, 4)
		else:
			ThemeManager.apply_card_panel_style(row_panel, false, 4, 10, 4, 10, 4)
		t_standings_list.add_child(row_panel)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		row_panel.add_child(row_hbox)

		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(32, 0)
		rank_lbl.add_theme_font_size_override("font_size", 14)
		if e_status == "submitted":
			rank_lbl.text = "#%d" % (rank_idx + 1)
		else:
			rank_lbl.text = "â€”"
		row_hbox.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(160, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = entry.get("player_name", "Player")
		if is_mine:
			name_lbl.text += " (You)"
			name_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row_hbox.add_child(name_lbl)

		var tee_lbl := Label.new()
		tee_lbl.custom_minimum_size = Vector2(80, 0)
		tee_lbl.text = entry.get("tee", "Blue")
		tee_lbl.add_theme_font_size_override("font_size", 13)
		row_hbox.add_child(tee_lbl)

		var holes_done: int = int(entry.get("holes_completed", 0))
		var holes_lbl := Label.new()
		holes_lbl.custom_minimum_size = Vector2(64, 0)
		holes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holes_lbl.text = "%d/%d" % [holes_done, expected_holes]
		holes_lbl.add_theme_font_size_override("font_size", 13)
		row_hbox.add_child(holes_lbl)

		var total_lbl := Label.new()
		total_lbl.custom_minimum_size = Vector2(64, 0)
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var total: int = int(entry.get("total_strokes", 0))
		total_lbl.text = str(total) if total > 0 else "â€”"
		total_lbl.add_theme_font_size_override("font_size", 14)
		row_hbox.add_child(total_lbl)

		var to_par_lbl := Label.new()
		to_par_lbl.custom_minimum_size = Vector2(64, 0)
		to_par_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		to_par_lbl.add_theme_font_size_override("font_size", 14)
		if e_status in ["submitted", "in_progress"]:
			var tp: int = int(entry.get("to_par", 0))
			if tp < 0:
				to_par_lbl.text = str(tp)
				to_par_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
			elif tp == 0:
				to_par_lbl.text = "E"
			else:
				to_par_lbl.text = "+%d" % tp
				to_par_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DANGER)
		else:
			to_par_lbl.text = "â€”"
		row_hbox.add_child(to_par_lbl)

		var status_lbl := Label.new()
		status_lbl.custom_minimum_size = Vector2(80, 0)
		status_lbl.add_theme_font_size_override("font_size", 12)
		match e_status:
			"submitted":
				status_lbl.text = "âœ“ Final"
				status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SUCCESS)
			"in_progress":
				status_lbl.text = "Playing..."
				status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WARNING)
			_:
				status_lbl.text = "Pending"
				status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_MUTED)
		row_hbox.add_child(status_lbl)


# â”€â”€ FILTER HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _time_filter_value(idx: int) -> String:
	match idx:
		1: return "today"
		2: return "this_week"
		3: return "this_month"
		4: return "last_90_days"
		_: return "all"


func _course_filter_key(option: OptionButton) -> String:
	var sel_idx: int = option.selected
	# Index 0 is "All Courses", indices 1+ map to _available_courses
	if sel_idx <= 0:
		return ""
	var course_idx: int = sel_idx - 1
	if course_idx < _available_courses.size():
		return _available_courses[course_idx].get("key", "")
	return ""


# â”€â”€ STATUS DISPLAY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _show_status(msg: String, is_error: bool) -> void:
	var color := ThemeManager.COLOR_TEXT_DANGER if is_error else ThemeManager.COLOR_TEXT_SUCCESS
	if _active_tab == "host":
		if host_status_label != null:
			host_status_label.text = msg
			host_status_label.add_theme_color_override("font_color", color)
	elif _active_tab == "join_code":
		if join_status_label != null:
			join_status_label.text = msg
			join_status_label.add_theme_color_override("font_color", color)
	elif _active_tab == "browser":
		if no_lobbies_label != null and is_error:
			no_lobbies_label.visible = true
			no_lobbies_label.text = msg
	else:
		if host_status_label != null:
			host_status_label.text = msg
			host_status_label.add_theme_color_override("font_color", color)


func _format_tournament_error(raw_err: String) -> String:
	var msg := raw_err.strip_edges()
	if msg.is_empty():
		return "Failed to load tournament data."
	if msg.contains("PERMISSION_DENIED") or msg.contains("Missing or insufficient permissions") or msg.begins_with("HTTP 403"):
		return "Permission denied. Please check your cloud sign-in status."
	if msg.begins_with("HTTP "):
		var colon_idx := msg.find(":")
		if colon_idx != -1:
			var body := msg.substr(colon_idx + 1).strip_edges()
			var parsed = JSON.parse_string(body)
			var err_obj = null
			if parsed is Dictionary and parsed.has("error"):
				err_obj = parsed["error"]
			elif parsed is Array and not parsed.is_empty() and parsed[0] is Dictionary and parsed[0].has("error"):
				err_obj = parsed[0]["error"]
			if err_obj is Dictionary:
				return str(err_obj.get("message", msg))
			elif err_obj != null:
				return str(err_obj)
	return msg


func _show_t_status(msg: String, is_error: bool) -> void:
	if is_error:
		msg = _format_tournament_error(msg)
	var color := ThemeManager.COLOR_TEXT_DANGER if is_error else ThemeManager.COLOR_TEXT_SUCCESS
	match _active_t_tab:
		"t_host":
			if t_host_status_label != null:
				t_host_status_label.text = msg
				t_host_status_label.add_theme_color_override("font_color", color)
		"t_join":
			if t_join_status_label != null:
				t_join_status_label.text = msg
				t_join_status_label.add_theme_color_override("font_color", color)
		"t_public":
			if t_public_empty_label != null:
				t_public_empty_label.visible = true
				t_public_empty_label.text = msg
				t_public_empty_label.add_theme_color_override("font_color", color)


func _on_back_pressed() -> void:
	var sess := _get_session()
	if sess != null and sess.is_online_match:
		_on_leave_lobby_pressed()
	else:
		var sm = get_node_or_null("/root/SceneManager")
		if sm != null and sm.has_method("load_main_menu"):
			sm.load_main_menu()
		else:
			get_tree().change_scene_to_file("res://UI/MainMenu/main_menu.tscn")


# â”€â”€ CONTROLLER FOCUS & KEYBOARD INTERCEPTION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _input(event: InputEvent) -> void:
	if join_code_input.has_focus() and (event is InputEventJoypadButton) and event.pressed and event.button_index == JOY_BUTTON_A:
		if has_node("/root/VirtualKeyboardManager"):
			get_node("/root/VirtualKeyboardManager").open_for(join_code_input, true)
			get_viewport().set_input_as_handled()
	if t_join_code_input.has_focus() and (event is InputEventJoypadButton) and event.pressed and event.button_index == JOY_BUTTON_A:
		if has_node("/root/VirtualKeyboardManager"):
			get_node("/root/VirtualKeyboardManager").open_for(t_join_code_input, true)
			get_viewport().set_input_as_handled()
	if t_end_date_input.has_focus() and (event is InputEventJoypadButton) and event.pressed and event.button_index == JOY_BUTTON_A:
		if has_node("/root/VirtualKeyboardManager"):
			get_node("/root/VirtualKeyboardManager").open_for(t_end_date_input, false)
			get_viewport().set_input_as_handled()
	if t_host_name_input.has_focus() and (event is InputEventJoypadButton) and event.pressed and event.button_index == JOY_BUTTON_A:
		if has_node("/root/VirtualKeyboardManager"):
			get_node("/root/VirtualKeyboardManager").open_for(t_host_name_input, false)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _active_tab == "room":
			_on_leave_lobby_pressed()
		else:
			_on_back_pressed()
		get_viewport().set_input_as_handled()


func _update_controller_focus_navigation() -> void:
	if not is_inside_tree():
		return
	# Mode bar
	back_button.focus_neighbor_right = mode_matches_button.get_path()
	mode_matches_button.focus_neighbor_left = back_button.get_path()
	mode_matches_button.focus_neighbor_right = mode_tournaments_button.get_path()
	mode_tournaments_button.focus_neighbor_left = mode_matches_button.get_path()
	mode_tournaments_button.focus_neighbor_right = account_button.get_path()
	account_button.focus_neighbor_left = mode_tournaments_button.get_path()

	if _active_mode == "matches":
		mode_matches_button.focus_neighbor_bottom = tab_host_button.get_path()
		tab_host_button.focus_neighbor_top = mode_matches_button.get_path()
		tab_host_button.focus_neighbor_right = tab_join_code_button.get_path()
		tab_join_code_button.focus_neighbor_left = tab_host_button.get_path()
		tab_join_code_button.focus_neighbor_right = tab_browser_button.get_path()
		tab_browser_button.focus_neighbor_left = tab_join_code_button.get_path()

		if _active_tab == "host":
			tab_host_button.focus_neighbor_bottom = course_dropdown.get_path()
			course_dropdown.focus_neighbor_top = tab_host_button.get_path()
			course_dropdown.focus_neighbor_bottom = length_option.get_path()
			length_option.focus_neighbor_top = course_dropdown.get_path()
			length_option.focus_neighbor_bottom = mode_option.get_path()
			mode_option.focus_neighbor_top = length_option.get_path()
			mode_option.focus_neighbor_bottom = turn_order_option.get_path()
			turn_order_option.focus_neighbor_top = mode_option.get_path()
			turn_order_option.focus_neighbor_bottom = wind_option.get_path()
			wind_option.focus_neighbor_top = turn_order_option.get_path()
			wind_option.focus_neighbor_bottom = green_speed_option.get_path()
			green_speed_option.focus_neighbor_top = wind_option.get_path()
			green_speed_option.focus_neighbor_bottom = visibility_option.get_path()
			visibility_option.focus_neighbor_top = green_speed_option.get_path()
			visibility_option.focus_neighbor_bottom = gimme_mode_option.get_path()
			gimme_mode_option.focus_neighbor_top = visibility_option.get_path()
			gimme_mode_option.focus_neighbor_bottom = host_golfer_dropdown.get_path()
			host_golfer_dropdown.focus_neighbor_top = gimme_mode_option.get_path()
			host_golfer_dropdown.focus_neighbor_right = host_golfer_tee.get_path()
			host_golfer_tee.focus_neighbor_left = host_golfer_dropdown.get_path()
			host_golfer_dropdown.focus_neighbor_bottom = host_create_button.get_path()
			host_golfer_tee.focus_neighbor_bottom = host_create_button.get_path()
			host_create_button.focus_neighbor_top = host_golfer_dropdown.get_path()

		elif _active_tab == "join_code":
			tab_join_code_button.focus_neighbor_bottom = join_code_input.get_path()
			join_code_input.focus_neighbor_top = tab_join_code_button.get_path()
			join_code_input.focus_neighbor_right = paste_code_button.get_path()
			paste_code_button.focus_neighbor_left = join_code_input.get_path()
			join_code_input.focus_neighbor_bottom = join_golfer_dropdown.get_path()
			paste_code_button.focus_neighbor_bottom = join_golfer_dropdown.get_path()
			join_golfer_dropdown.focus_neighbor_top = join_code_input.get_path()
			join_golfer_dropdown.focus_neighbor_right = join_golfer_tee.get_path()
			join_golfer_tee.focus_neighbor_left = join_golfer_dropdown.get_path()
			join_golfer_dropdown.focus_neighbor_bottom = join_code_submit_button.get_path()
			join_golfer_tee.focus_neighbor_bottom = join_code_submit_button.get_path()
			join_code_submit_button.focus_neighbor_top = join_golfer_dropdown.get_path()

		elif _active_tab == "browser":
			tab_browser_button.focus_neighbor_bottom = refresh_browser_button.get_path()
			refresh_browser_button.focus_neighbor_top = tab_browser_button.get_path()
			var first_btn: Button = null
			for card in browser_list.get_children():
				if card is PanelContainer:
					for c in card.find_children("*", "Button", true, false):
						if c is Button and c.is_visible_in_tree():
							first_btn = c
							break
				if first_btn != null:
					break
			if first_btn != null:
				refresh_browser_button.focus_neighbor_bottom = first_btn.get_path()
				first_btn.focus_neighbor_top = refresh_browser_button.get_path()

		elif _active_tab == "room":
			copy_code_button.focus_neighbor_top = back_button.get_path()
			copy_code_button.focus_neighbor_bottom = ready_toggle_button.get_path()
			if course_install_banner.visible:
				copy_code_button.focus_neighbor_bottom = download_course_button.get_path()
				download_course_button.focus_neighbor_top = copy_code_button.get_path()
				download_course_button.focus_neighbor_bottom = ready_toggle_button.get_path()
			leave_lobby_button.focus_neighbor_right = ready_toggle_button.get_path()
			ready_toggle_button.focus_neighbor_left = leave_lobby_button.get_path()
			ready_toggle_button.focus_neighbor_right = start_match_button.get_path()
			start_match_button.focus_neighbor_left = ready_toggle_button.get_path()

	elif _active_mode == "tournaments":
		mode_tournaments_button.focus_neighbor_bottom = ttab_host_button.get_path()
		ttab_host_button.focus_neighbor_top = mode_tournaments_button.get_path()
		ttab_host_button.focus_neighbor_right = ttab_join_button.get_path()
		ttab_join_button.focus_neighbor_left = ttab_host_button.get_path()
		ttab_join_button.focus_neighbor_right = ttab_public_button.get_path()
		ttab_public_button.focus_neighbor_left = ttab_join_button.get_path()
		ttab_public_button.focus_neighbor_right = ttab_standings_button.get_path()
		ttab_standings_button.focus_neighbor_left = ttab_public_button.get_path()

		if _active_t_tab == "t_host":
			ttab_host_button.focus_neighbor_bottom = t_course_dropdown.get_path()
			t_course_dropdown.focus_neighbor_top = ttab_host_button.get_path()
			t_course_dropdown.focus_neighbor_bottom = t_host_name_input.get_path()
			t_host_name_input.focus_neighbor_top = t_course_dropdown.get_path()
			t_host_name_input.focus_neighbor_bottom = t_length_option.get_path()
			t_length_option.focus_neighbor_top = t_host_name_input.get_path()
			t_length_option.focus_neighbor_bottom = t_mode_option.get_path()
			t_mode_option.focus_neighbor_top = t_length_option.get_path()
			t_mode_option.focus_neighbor_bottom = t_wind_option.get_path()
			t_wind_option.focus_neighbor_top = t_mode_option.get_path()
			t_wind_option.focus_neighbor_bottom = t_green_speed_option.get_path()
			t_green_speed_option.focus_neighbor_top = t_wind_option.get_path()
			t_green_speed_option.focus_neighbor_bottom = t_visibility_option.get_path()
			t_visibility_option.focus_neighbor_top = t_green_speed_option.get_path()
			t_visibility_option.focus_neighbor_bottom = t_max_players_spinbox.get_line_edit().get_path()
			t_max_players_spinbox.get_line_edit().focus_neighbor_top = t_visibility_option.get_path()
			t_max_players_spinbox.get_line_edit().focus_neighbor_bottom = t_end_date_input.get_path()
			t_end_date_input.focus_neighbor_top = t_max_players_spinbox.get_line_edit().get_path()
			t_end_date_input.focus_neighbor_bottom = t_gimme_mode_option.get_path()
			t_gimme_mode_option.focus_neighbor_top = t_end_date_input.get_path()
			t_gimme_mode_option.focus_neighbor_bottom = t_host_golfer_dropdown.get_path()
			t_host_golfer_dropdown.focus_neighbor_top = t_gimme_mode_option.get_path()
			t_host_golfer_dropdown.focus_neighbor_right = t_host_golfer_tee.get_path()
			t_host_golfer_tee.focus_neighbor_left = t_host_golfer_dropdown.get_path()
			t_host_golfer_dropdown.focus_neighbor_bottom = t_host_create_button.get_path()
			t_host_golfer_tee.focus_neighbor_bottom = t_host_create_button.get_path()
			t_host_create_button.focus_neighbor_top = t_host_golfer_dropdown.get_path()
		elif _active_t_tab == "t_join":
			ttab_join_button.focus_neighbor_bottom = t_join_code_input.get_path()
			t_join_code_input.focus_neighbor_top = ttab_join_button.get_path()
			t_join_code_input.focus_neighbor_right = t_join_paste_button.get_path()
			t_join_paste_button.focus_neighbor_left = t_join_code_input.get_path()
			t_join_code_input.focus_neighbor_bottom = t_join_golfer_dropdown.get_path()
			t_join_golfer_dropdown.focus_neighbor_top = t_join_code_input.get_path()
			t_join_golfer_dropdown.focus_neighbor_right = t_join_golfer_tee.get_path()
			t_join_golfer_tee.focus_neighbor_left = t_join_golfer_dropdown.get_path()
			t_join_golfer_dropdown.focus_neighbor_bottom = t_join_submit_button.get_path()
			t_join_golfer_tee.focus_neighbor_bottom = t_join_submit_button.get_path()
			t_join_submit_button.focus_neighbor_top = t_join_golfer_dropdown.get_path()
		elif _active_t_tab == "t_public":
			ttab_public_button.focus_neighbor_bottom = t_public_refresh_button.get_path()
			t_public_refresh_button.focus_neighbor_top = ttab_public_button.get_path()
		elif _active_t_tab == "t_standings":
			ttab_standings_button.focus_neighbor_bottom = t_standings_refresh_button.get_path()
			t_standings_refresh_button.focus_neighbor_top = ttab_standings_button.get_path()
