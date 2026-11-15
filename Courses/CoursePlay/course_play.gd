extends Node3D

var hud_player_name_lbl: Label = null
var hud_player_badge: PanelContainer = null
var hud_player_badge_lbl: Label = null
var hud_player_avatar_rect: TextureRect = null
var hud_overall_score_lbl: Label = null
var hud_hole_num_lbl: Label = null
var hud_shots_rtl: RichTextLabel = null
var _minimap_group: HBoxContainer = null
var _distance_tracker_panel: Container = null
var _back_lbl: Label = null
var _hole_lbl: Label = null
var _front_lbl: Label = null
var _distance_unit_lbl: Label = null
var hud_player_name_panel: PanelContainer = null
var hud_overall_score_panel: PanelContainer = null
var hud_distance_queue_panel: PanelContainer = null
var hud_distance_queue_vbox: VBoxContainer = null
var _hole_num_style: StyleBoxFlat = null
var _shots_style: StyleBoxFlat = null
var hud_top_left_widget: VBoxContainer = null

var _last_hud_strokes: int = -1
var _last_hud_player_name: String = ""
var _last_hud_hole_index: int = -1
var _last_course_hole_id: String = ""

const ScorecardBadge = preload("res://UI/scorecard_badge.gd")
const HoleShotPathDiagram = preload("res://UI/hole_shot_path_diagram.gd")
const TeeShotView = preload("res://UI/tee_shot_view.gd")

var hud_scorecard: Panel = Panel.new()
var scorecard_grid: GridContainer = GridContainer.new()
var _scorecard_content: VBoxContainer = null
var _hole_shot_summary: VBoxContainer = null
var _scorecard_action_btn: Button = null
var _scorecard_countdown_container: HBoxContainer = null
var _scorecard_countdown_lbl: Label = null
var _scorecard_pause_btn: Button = null
var _scorecard_countdown_time_left: float = 0.0
var _scorecard_countdown_active: bool = false
var _scorecard_countdown_paused: bool = false
var _scorecard_view_tab: String = "All"
var _scorecard_selected_hole_index: int = -1
var _last_scorecard_action_type: String = "toggle"
var _scorecard_add_player_section: PanelContainer = null
var _scorecard_settings_mode: bool = false
var _scorecard_settings_btn: Button = null
var _tee_icon_cache: Dictionary = {}
var hud_manage_players: Panel = Panel.new()
var hud_overview: Panel = Panel.new()
const MINIMAP_NORMAL_SIZE: Vector2 = Vector2(284, 333)
const MINIMAP_ENLARGED_SIZE: Vector2 = Vector2(500, 500)
const MINIMAP_PANEL_PADDING: Vector2 = Vector2(4, 4)

var _minimap_camera: Camera3D = null
var _minimap_viewport: SubViewport = null
var _minimap_panel: PanelContainer = null
var _minimap_container: SubViewportContainer = null
var _minimap_hint_label: Label = null
var _minimap_tween: Tween = null
var _is_minimap_enlarged: bool = false
var minimap_zoom: float = 300.0
var _last_was_on_green: bool = false
var _default_non_green_minimap_zoom: float = 300.0
var _teebox_minimap_zoom: float = 300.0
var _last_zoom_zone: int = -1
var _minimap_zoom_dirty: bool = true
var _prev_ball_moving: bool = false
var _minimap_flag_icon: TextureRect = null
var _minimap_ball_icon: TextureRect = null

var _cached_green_verts: PackedVector3Array = PackedVector3Array()
var _cached_green_hole_index: int = -1

var _overlay_node: Control = null
var _player_map_markers: Dictionary = {}
var _cached_player_textures: Dictionary = {}

var range_ui: Control = null
var _tee_shot_view: Control = null
var _tee_shot_canvas: CanvasLayer = null
var _tee_shot_flight_active: bool = false
var _tee_shot_tracer_update_elapsed: float = 0.0
const TEE_SHOT_TRACER_UPDATE_INTERVAL := 0.05
var _hud_visible_before_tee_shot: bool = true
var top_bar: HBoxContainer = null
var right_panel: VBoxContainer = null
var toggles_scroll: ScrollContainer = null
var toggles_container: VBoxContainer = null
var settings_btn: Button = null
var home_btn: Button = null
var hide_helpers_btn: Button = null
var stats_btn: Button = null
var grid_btn: Button = null
var map_btn: Button = null
var mulligan_btn: Button = null
var forfeit_btn: Button = null
var imm_menu_btn: Button = null
var imm_menu_container: VBoxContainer = null
var train_menu_btn: Button = null
var train_menu_container: VBoxContainer = null
var visuals_menu_btn: Button = null
var visuals_menu_container: VBoxContainer = null
var free_cam_btn: Button = null
var graphics_toggle_btn: Button = null
var _free_camera: Camera3D = null
var golfer_cam_btn: Button = null
var putting_cam_btn: Button = null
var announcer_btn: Button = null
var tension_btn: Button = null
var dist_btn: Button = null
var rollout_btn: Button = null
var track_averages_btn: Button = null
var stuck_ball_btn: Button = null
var _screen_offset_ctrl: Control = null
var club_selector_node: Control = null

var course_instance: Node = null
var active_ball: Node = null
var mulligan_confirm_dialog: PanelContainer = null
var _mulligan_is_selection_mode: bool = false
var _mulligan_new_shot_btn: Button = null
var _mulligan_confirm_btn: Button = null
var _mulligan_cancel_btn: Button = null
var _mulligan_option_buttons: Array[Button] = []
var _mulligan_matching_entries: Array = []
var _mulligan_selected_idx: int = -1
var _mulligan_scroll: ScrollContainer = null
var forfeit_confirm_dialog: PanelContainer = null
var exit_confirm_dialog: Control = null
var add_player_prompt_dialog: PanelContainer = null
var resume_player_prompt_dialog: PanelContainer = null
var catch_up_banner: PanelContainer = null
var catch_up_lbl: Label = null
var catch_up_skip_btn: Button = null
var online_waiting_banner: PanelContainer = null
var online_waiting_lbl: Label = null
var online_afk_warning_lbl: Label = null
var online_afk_btn_box: HBoxContainer = null
var online_concede_btn: Button = null
var online_remove_btn: Button = null
var _hud_elements_visible: bool = true

var _was_helpers_visible_before_aerial: bool = false
var _is_aerial_active_practice: bool = false

var gimme_banner: PanelContainer = null
var gimme_title_lbl: Label = null
var gimme_sub_lbl: Label = null
var _gimme_tween: Tween = null
var is_player_turn_ready: bool = true
var _last_loaded_hole_id: String = ""
var _last_loaded_hole_index: int = -1

var hole_intro_card: PanelContainer = null
var _hole_card_header_lbl: Label = null
var _hole_card_hole_lbl: Label = null
var _hole_card_par_lbl: Label = null
var _hole_card_dist_lbl: Label = null
var _hole_card_tween: Tween = null
var _last_hole_card_hole_index: int = -999
var _last_hole_card_hole_id: String = ""

func is_gimme_banner_active() -> bool:
	return gimme_banner != null and is_instance_valid(gimme_banner) and gimme_banner.visible and gimme_banner.modulate.a > 0.05

func _ready() -> void:
	_last_loaded_hole_id = ""
	_last_loaded_hole_index = -1
	_last_hole_card_hole_index = -999
	_last_hole_card_hole_id = ""
	MultiplayerManager.active_player_changed.connect(_on_active_player_changed)
	if not MultiplayerManager.player_ball_graphic_changed.is_connected(_on_course_ball_graphic_changed):
		MultiplayerManager.player_ball_graphic_changed.connect(_on_course_ball_graphic_changed)
	if not MultiplayerManager.player_tee_changed.is_connected(_on_player_tee_changed):
		MultiplayerManager.player_tee_changed.connect(_on_player_tee_changed)
	MultiplayerManager.hole_completed.connect(_on_hole_completed)
	MultiplayerManager.game_over.connect(_on_game_over)
	MultiplayerManager.gimme_awarded.connect(_on_gimme_awarded)
	MultiplayerManager.distance_queue_updated.connect(_update_distance_queue)
	MultiplayerManager.shot_recorded.connect(func(_p, _s):
		_update_distance_queue()
		_dismiss_hole_intro_card_early()
	)
	MultiplayerManager.catch_up_mode_changed.connect(func(_active, _name, _c, _t):
		_update_catch_up_hud()
	)
	if has_node("/root/KeybindingManager"):
		KeybindingManager.keybindings_changed.connect(_update_hud_tooltips)
	
	if has_node("/root/OnlineMatchController"):
		var omc = get_node("/root/OnlineMatchController")
		if not omc.waiting_banner_status_changed.is_connected(_on_online_waiting_banner_status_changed):
			omc.waiting_banner_status_changed.connect(_on_online_waiting_banner_status_changed)
	
	if course_instance == null:
		if get_parent() != null and get_parent() != get_tree().get_root() and get_parent().name != "CourseManager":
			course_instance = get_parent()
		else:
			var current_scene = get_tree().current_scene
			if current_scene != null and current_scene.name == "CourseManager":
				var course_nodes = current_scene.get_children()
				if not course_nodes.is_empty():
					course_instance = course_nodes[0]
			
	if course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			active_ball = player_node.get("ball")
			var init_p = MultiplayerManager.get_active_player()
			if player_node.has_method("set_profile") and not init_p.is_empty():
				player_node.set_profile(str(init_p.get("name", "")))

	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			var setting = gs.range_settings.debug_show_hit_distance
			if not setting.setting_changed.is_connected(_on_debug_hit_distance_setting_changed):
				setting.setting_changed.connect(_on_debug_hit_distance_setting_changed)

	_setup_hud()

	# Start first player's turn
	_on_active_player_changed(MultiplayerManager.get_active_player())
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and lm.has_method("set_ready"):
			lm.call("set_ready")


func _setup_hud() -> void:
	range_ui = null
	if course_instance != null:
		range_ui = course_instance.get_node_or_null("RangeUI")
		if range_ui != null:
			var r_top_bar = range_ui.get_node_or_null("HBoxContainer")
			if r_top_bar != null:
				r_top_bar.visible = false
			if range_ui.has_signal("manage_players_requested") and not range_ui.manage_players_requested.is_connected(_on_manage_players_toggle_pressed):
				range_ui.manage_players_requested.connect(_on_manage_players_toggle_pressed)
			if range_ui.has_signal("golfer_cam_modal_state_changed") and not range_ui.golfer_cam_modal_state_changed.is_connected(_on_golfer_cam_modal_state_changed):
				range_ui.golfer_cam_modal_state_changed.connect(_on_golfer_cam_modal_state_changed)
			if range_ui.has_signal("stats_visibility_changed") and not range_ui.stats_visibility_changed.is_connected(_on_stats_visibility_changed):
				range_ui.stats_visibility_changed.connect(_on_stats_visibility_changed)
			if range_ui.has_signal("golfer_cam_enabled_changed") and not range_ui.golfer_cam_enabled_changed.is_connected(_on_golfer_cam_enabled_changed):
				range_ui.golfer_cam_enabled_changed.connect(_on_golfer_cam_enabled_changed)
			if range_ui.has_signal("putting_cam_enabled_changed") and not range_ui.putting_cam_enabled_changed.is_connected(_on_putting_cam_enabled_changed):
				range_ui.putting_cam_enabled_changed.connect(_on_putting_cam_enabled_changed)

	var canvas = CanvasLayer.new()
	canvas.layer = 15 # Render on top of VignetteLayer (layer 10)
	add_child(canvas)
	
	_overlay_node = MultiplayerBallOverlay.new(self)
	canvas.add_child(_overlay_node)

	_tee_shot_canvas = CanvasLayer.new()
	_tee_shot_canvas.name = "TeeShotViewLayer"
	_tee_shot_canvas.layer = 110
	add_child(_tee_shot_canvas)

	_tee_shot_view = TeeShotView.new()
	_tee_shot_canvas.add_child(_tee_shot_view)
	_tee_shot_view.connect("split_started", Callable(self, "_on_tee_shot_split_started"))
	_tee_shot_view.connect("split_closed", Callable(self, "_on_tee_shot_split_closed"))
	
	mulligan_confirm_dialog = PanelContainer.new()
	mulligan_confirm_dialog.name = "MulliganConfirmDialog"
	mulligan_confirm_dialog.visible = false
	mulligan_confirm_dialog.z_index = 500
	
	mulligan_confirm_dialog.anchor_left = 0.5
	mulligan_confirm_dialog.anchor_right = 0.5
	mulligan_confirm_dialog.anchor_top = 0.5
	mulligan_confirm_dialog.anchor_bottom = 0.5
	mulligan_confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mulligan_confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	mulligan_confirm_dialog.offset_left = -280
	mulligan_confirm_dialog.offset_right = 280
	mulligan_confirm_dialog.offset_top = -135
	mulligan_confirm_dialog.offset_bottom = 135
	
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	dialog_style.border_width_left = 2
	dialog_style.border_width_top = 2
	dialog_style.border_width_right = 2
	dialog_style.border_width_bottom = 2
	dialog_style.border_color = Color(0.25, 0.25, 0.25, 0.8)
	dialog_style.corner_radius_top_left = 12
	dialog_style.corner_radius_top_right = 12
	dialog_style.corner_radius_bottom_left = 12
	dialog_style.corner_radius_bottom_right = 12
	dialog_style.content_margin_left = 28
	dialog_style.content_margin_top = 24
	dialog_style.content_margin_right = 28
	dialog_style.content_margin_bottom = 24
	dialog_style.shadow_color = Color(0, 0, 0, 0.7)
	dialog_style.shadow_size = 10
	mulligan_confirm_dialog.add_theme_stylebox_override("panel", dialog_style)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 20)
	
	var title_lbl = Label.new()
	title_lbl.text = "Confirm Mulligan"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.46, 0.72, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 4)
	content_vbox.add_child(title_lbl)
	
	var msg_lbl = Label.new()
	msg_lbl.text = "Are you sure you want to take a mulligan?\nThis will undo your last shot."
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_font_size_override("font_size", 20)
	msg_lbl.add_theme_color_override("font_color", Color.WHITE)
	msg_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_lbl.add_theme_constant_override("outline_size", 4)
	content_vbox.add_child(msg_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 24)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Yes, Undo"
	confirm_btn.custom_minimum_size = Vector2(170, 52)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	apply_material_button_style(confirm_btn, Color(0.24, 0.46, 0.72, 0.85))
	confirm_btn.pressed.connect(func():
		mulligan_confirm_dialog.visible = false
		_on_mulligan_confirmed()
	)
	btn_hbox.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(170, 52)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	apply_material_button_style(cancel_btn, Color(0.56, 0.22, 0.22, 0.85))
	cancel_btn.pressed.connect(func():
		mulligan_confirm_dialog.visible = false
	)
	confirm_btn.name = "ConfirmBtn"
	cancel_btn.name = "CancelBtn"
	btn_hbox.add_child(cancel_btn)
	confirm_btn.focus_neighbor_right = confirm_btn.get_path_to(cancel_btn)
	confirm_btn.focus_neighbor_left = confirm_btn.get_path_to(cancel_btn)
	cancel_btn.focus_neighbor_left = cancel_btn.get_path_to(confirm_btn)
	cancel_btn.focus_neighbor_right = cancel_btn.get_path_to(confirm_btn)
	
	content_vbox.add_child(btn_hbox)
	mulligan_confirm_dialog.add_child(content_vbox)
	canvas.add_child(mulligan_confirm_dialog)

	# Forfeit Confirm Dialog (Concede Hole when at 10+ strokes)
	forfeit_confirm_dialog = PanelContainer.new()
	forfeit_confirm_dialog.name = "ForfeitConfirmDialog"
	forfeit_confirm_dialog.visible = false
	forfeit_confirm_dialog.z_index = 500
	forfeit_confirm_dialog.anchor_left = 0.5
	forfeit_confirm_dialog.anchor_right = 0.5
	forfeit_confirm_dialog.anchor_top = 0.5
	forfeit_confirm_dialog.anchor_bottom = 0.5
	forfeit_confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	forfeit_confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	forfeit_confirm_dialog.offset_left = -220
	forfeit_confirm_dialog.offset_right = 220
	forfeit_confirm_dialog.offset_top = -100
	forfeit_confirm_dialog.offset_bottom = 100

	var forfeit_dialog_style = StyleBoxFlat.new()
	forfeit_dialog_style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	forfeit_dialog_style.border_width_left = 2
	forfeit_dialog_style.border_width_top = 2
	forfeit_dialog_style.border_width_right = 2
	forfeit_dialog_style.border_width_bottom = 2
	forfeit_dialog_style.border_color = Color(0.65, 0.25, 0.25, 0.8)
	forfeit_dialog_style.corner_radius_top_left = 12
	forfeit_dialog_style.corner_radius_top_right = 12
	forfeit_dialog_style.corner_radius_bottom_left = 12
	forfeit_dialog_style.corner_radius_bottom_right = 12
	forfeit_dialog_style.content_margin_left = 24
	forfeit_dialog_style.content_margin_right = 24
	forfeit_dialog_style.content_margin_top = 20
	forfeit_dialog_style.content_margin_bottom = 20
	forfeit_dialog_style.shadow_color = Color(0, 0, 0, 0.7)
	forfeit_dialog_style.shadow_size = 10
	forfeit_confirm_dialog.add_theme_stylebox_override("panel", forfeit_dialog_style)
	canvas.add_child(forfeit_confirm_dialog)

	# Exit Match Confirm Dialog (Prompt when Home button is pressed)
	exit_confirm_dialog = Control.new()
	exit_confirm_dialog.name = "ExitConfirmDialog"
	exit_confirm_dialog.visible = false
	exit_confirm_dialog.z_index = 500
	exit_confirm_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	exit_confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	exit_confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	exit_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	var exit_backdrop = ColorRect.new()
	exit_backdrop.name = "Backdrop"
	exit_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	exit_backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	exit_backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	exit_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	exit_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			exit_confirm_dialog.visible = false
	)
	exit_confirm_dialog.add_child(exit_backdrop)

	var exit_panel = PanelContainer.new()
	exit_panel.name = "ExitDialogPanel"
	exit_panel.anchor_left = 0.5
	exit_panel.anchor_right = 0.5
	exit_panel.anchor_top = 0.5
	exit_panel.anchor_bottom = 0.5
	exit_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	exit_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	exit_panel.offset_left = -250
	exit_panel.offset_right = 250
	exit_panel.offset_top = -115
	exit_panel.offset_bottom = 115

	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	exit_style.border_width_left = 2
	exit_style.border_width_top = 2
	exit_style.border_width_right = 2
	exit_style.border_width_bottom = 2
	exit_style.border_color = Color(0.35, 0.35, 0.35, 0.8)
	exit_style.corner_radius_top_left = 12
	exit_style.corner_radius_top_right = 12
	exit_style.corner_radius_bottom_left = 12
	exit_style.corner_radius_bottom_right = 12
	exit_style.content_margin_left = 28
	exit_style.content_margin_top = 24
	exit_style.content_margin_right = 28
	exit_style.content_margin_bottom = 24
	exit_panel.add_theme_stylebox_override("panel", exit_style)

	var exit_content_vbox = VBoxContainer.new()
	exit_content_vbox.add_theme_constant_override("separation", 20)

	var exit_title_lbl = Label.new()
	exit_title_lbl.text = "Exit Match"
	exit_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_title_lbl.add_theme_font_size_override("font_size", 28)
	exit_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4, 1.0))
	exit_title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	exit_title_lbl.add_theme_constant_override("outline_size", 4)
	exit_content_vbox.add_child(exit_title_lbl)

	var exit_msg_lbl = Label.new()
	exit_msg_lbl.text = "Are you sure you want to stop the match and return to the home screen?"
	exit_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_msg_lbl.custom_minimum_size = Vector2(400, 0)
	exit_msg_lbl.add_theme_font_size_override("font_size", 20)
	exit_msg_lbl.add_theme_color_override("font_color", Color.WHITE)
	exit_msg_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	exit_msg_lbl.add_theme_constant_override("outline_size", 4)
	exit_content_vbox.add_child(exit_msg_lbl)

	var exit_btn_hbox = HBoxContainer.new()
	exit_btn_hbox.add_theme_constant_override("separation", 24)
	exit_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var exit_yes_btn = Button.new()
	exit_yes_btn.name = "YesButton"
	exit_yes_btn.text = "Yes"
	exit_yes_btn.custom_minimum_size = Vector2(140, 50)
	apply_material_button_style(exit_yes_btn, Color(0.65, 0.22, 0.22, 0.85))
	exit_yes_btn.pressed.connect(func():
		exit_confirm_dialog.visible = false
		if not MultiplayerManager.practice_mode_active and not MultiplayerManager.players.is_empty():
			MultiplayerManager.save_current_match()
			var cloud_sync = get_node_or_null("/root/CloudSync")
			if cloud_sync != null and cloud_sync.has_method("queue_completed_match"):
				var match_dict = {
					"match_id": MultiplayerManager.current_match_id,
					"course_title": MultiplayerManager.course_title,
					"game_mode": MultiplayerManager.game_mode,
					"practice_mode_active": MultiplayerManager.practice_mode_active,
					"is_finished": false,
					"players": MultiplayerManager.players,
					"winners": [],
					"hole_pars": MultiplayerManager.call("_get_hole_pars") if MultiplayerManager.has_method("_get_hole_pars") else {},
					"hole_ids": MultiplayerManager.hole_ids
				}
				cloud_sync.queue_completed_match(match_dict)
		MultiplayerManager.players.clear()
		MultiplayerManager.practice_mode_active = false
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
	)
	exit_btn_hbox.add_child(exit_yes_btn)

	var exit_no_btn = Button.new()
	exit_no_btn.name = "NoButton"
	exit_no_btn.text = "No"
	exit_no_btn.custom_minimum_size = Vector2(140, 50)
	apply_material_button_style(exit_no_btn, Color(0.24, 0.46, 0.72, 0.85))
	exit_no_btn.pressed.connect(func():
		exit_confirm_dialog.visible = false
	)
	exit_btn_hbox.add_child(exit_no_btn)
	exit_yes_btn.focus_neighbor_right = exit_yes_btn.get_path_to(exit_no_btn)
	exit_yes_btn.focus_neighbor_left = exit_yes_btn.get_path_to(exit_no_btn)
	exit_no_btn.focus_neighbor_left = exit_no_btn.get_path_to(exit_yes_btn)
	exit_no_btn.focus_neighbor_right = exit_no_btn.get_path_to(exit_yes_btn)

	exit_content_vbox.add_child(exit_btn_hbox)
	exit_panel.add_child(exit_content_vbox)
	exit_confirm_dialog.add_child(exit_panel)
	canvas.add_child(exit_confirm_dialog)
	
	# Gimme Awarded Banner
	gimme_banner = PanelContainer.new()
	gimme_banner.name = "GimmeBanner"
	gimme_banner.visible = false
	gimme_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gimme_banner.anchor_left = 0.5
	gimme_banner.anchor_right = 0.5
	gimme_banner.anchor_top = 0.18
	gimme_banner.anchor_bottom = 0.18
	gimme_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gimme_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	gimme_banner.custom_minimum_size = Vector2(380, 110)
	
	var gimme_style = StyleBoxFlat.new()
	gimme_style.bg_color = Color(0.08, 0.14, 0.10, 0.92) # Rich deep emerald/slate background
	gimme_style.border_width_left = 3
	gimme_style.border_width_top = 3
	gimme_style.border_width_right = 3
	gimme_style.border_width_bottom = 3
	gimme_style.border_color = Color(1.0, 0.85, 0.38, 0.95) # Radiant gold border
	gimme_style.corner_radius_top_left = 16
	gimme_style.corner_radius_top_right = 16
	gimme_style.corner_radius_bottom_right = 16
	gimme_style.corner_radius_bottom_left = 16
	gimme_style.content_margin_left = 32
	gimme_style.content_margin_right = 32
	gimme_style.content_margin_top = 16
	gimme_style.content_margin_bottom = 16
	gimme_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	gimme_style.shadow_size = 12
	gimme_banner.add_theme_stylebox_override("panel", gimme_style)
	
	var g_vbox = VBoxContainer.new()
	g_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	g_vbox.add_theme_constant_override("separation", 2)
	gimme_banner.add_child(g_vbox)
	
	gimme_title_lbl = Label.new()
	gimme_title_lbl.name = "GimmeTitleLabel"
	gimme_title_lbl.text = "GIMME +1"
	gimme_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gimme_title_lbl.add_theme_font_size_override("font_size", 34)
	gimme_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	gimme_title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	gimme_title_lbl.add_theme_constant_override("outline_size", 6)
	g_vbox.add_child(gimme_title_lbl)
	
	gimme_sub_lbl = Label.new()
	gimme_sub_lbl.name = "GimmeSubLabel"
	gimme_sub_lbl.text = "Player Holed Out"
	gimme_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gimme_sub_lbl.add_theme_font_size_override("font_size", 18)
	gimme_sub_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	gimme_sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	gimme_sub_lbl.add_theme_constant_override("outline_size", 4)
	g_vbox.add_child(gimme_sub_lbl)
	
	canvas.add_child(gimme_banner)
	
	# Hole Intro Slide-In Card (Positioned in middle of screen on top of all HUD elements)
	hole_intro_card = PanelContainer.new()
	hole_intro_card.name = "HoleIntroCard"
	hole_intro_card.visible = false
	hole_intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole_intro_card.anchor_left = 0.5
	hole_intro_card.anchor_right = 0.5
	hole_intro_card.anchor_top = 0.38
	hole_intro_card.anchor_bottom = 0.38
	hole_intro_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hole_intro_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	hole_intro_card.custom_minimum_size = Vector2(420, 115)
	hole_intro_card.z_index = 50 # Render in front of helper buttons and panels
	hole_intro_card.offset_left = -1620.0
	hole_intro_card.offset_right = -1200.0
	hole_intro_card.offset_top = -58.0
	hole_intro_card.offset_bottom = 58.0
	hole_intro_card.modulate = Color(1, 1, 1, 0)
	
	var hic_style = StyleBoxFlat.new()
	hic_style.bg_color = Color(0.06, 0.08, 0.12, 0.92) # Deep obsidian slate glass
	hic_style.border_width_left = 4
	hic_style.border_width_top = 1
	hic_style.border_width_right = 1
	hic_style.border_width_bottom = 1
	hic_style.border_color = Color(1.0, 0.76, 0.22, 0.95) # Amber gold left accent
	hic_style.corner_radius_top_left = 12
	hic_style.corner_radius_top_right = 12
	hic_style.corner_radius_bottom_right = 12
	hic_style.corner_radius_bottom_left = 12
	hic_style.content_margin_left = 22
	hic_style.content_margin_right = 22
	hic_style.content_margin_top = 10
	hic_style.content_margin_bottom = 10
	hic_style.shadow_color = Color(0, 0, 0, 0.65)
	hic_style.shadow_size = 14
	hic_style.shadow_offset = Vector2(0, 4)
	hole_intro_card.add_theme_stylebox_override("panel", hic_style)
	
	var hic_vbox = VBoxContainer.new()
	hic_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hic_vbox.add_theme_constant_override("separation", 4)
	hole_intro_card.add_child(hic_vbox)
	
	_hole_card_header_lbl = Label.new()
	_hole_card_header_lbl.name = "HoleCardHeaderLabel"
	_hole_card_header_lbl.text = ""
	_hole_card_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hole_card_header_lbl.add_theme_font_size_override("font_size", 12)
	_hole_card_header_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	_hole_card_header_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_hole_card_header_lbl.add_theme_constant_override("outline_size", 2)
	_hole_card_header_lbl.visible = false
	hic_vbox.add_child(_hole_card_header_lbl)
	
	var hic_cols_hbox = HBoxContainer.new()
	hic_cols_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_cols_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hic_cols_hbox.add_theme_constant_override("separation", 18)
	hic_vbox.add_child(hic_cols_hbox)
	
	# Column 1: Hole
	var hic_hole_col = VBoxContainer.new()
	hic_hole_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_hole_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hic_hole_col.add_theme_constant_override("separation", 0)
	var hic_hole_title = Label.new()
	hic_hole_title.text = "HOLE"
	hic_hole_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hic_hole_title.add_theme_font_size_override("font_size", 12)
	hic_hole_title.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	hic_hole_title.add_theme_color_override("font_outline_color", Color.BLACK)
	hic_hole_title.add_theme_constant_override("outline_size", 2)
	hic_hole_col.add_child(hic_hole_title)
	
	_hole_card_hole_lbl = Label.new()
	_hole_card_hole_lbl.name = "HoleCardHoleNumLabel"
	_hole_card_hole_lbl.text = "1"
	_hole_card_hole_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hole_card_hole_lbl.add_theme_font_size_override("font_size", 34)
	_hole_card_hole_lbl.add_theme_color_override("font_color", Color.WHITE)
	_hole_card_hole_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_hole_card_hole_lbl.add_theme_constant_override("outline_size", 4)
	hic_hole_col.add_child(_hole_card_hole_lbl)
	hic_cols_hbox.add_child(hic_hole_col)
	
	# Separator 1
	var hic_sep1 = ColorRect.new()
	hic_sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_sep1.custom_minimum_size = Vector2(1, 40)
	hic_sep1.color = Color(1, 1, 1, 0.15)
	hic_sep1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hic_cols_hbox.add_child(hic_sep1)
	
	# Column 2: Par
	var hic_par_col = VBoxContainer.new()
	hic_par_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_par_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hic_par_col.add_theme_constant_override("separation", 0)
	var hic_par_title = Label.new()
	hic_par_title.text = "PAR"
	hic_par_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hic_par_title.add_theme_font_size_override("font_size", 12)
	hic_par_title.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	hic_par_title.add_theme_color_override("font_outline_color", Color.BLACK)
	hic_par_title.add_theme_constant_override("outline_size", 2)
	hic_par_col.add_child(hic_par_title)
	
	_hole_card_par_lbl = Label.new()
	_hole_card_par_lbl.name = "HoleCardParLabel"
	_hole_card_par_lbl.text = "4"
	_hole_card_par_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hole_card_par_lbl.add_theme_font_size_override("font_size", 34)
	_hole_card_par_lbl.add_theme_color_override("font_color", Color.WHITE)
	_hole_card_par_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_hole_card_par_lbl.add_theme_constant_override("outline_size", 4)
	hic_par_col.add_child(_hole_card_par_lbl)
	hic_cols_hbox.add_child(hic_par_col)
	
	# Separator 2
	var hic_sep2 = ColorRect.new()
	hic_sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_sep2.custom_minimum_size = Vector2(1, 40)
	hic_sep2.color = Color(1, 1, 1, 0.15)
	hic_sep2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hic_cols_hbox.add_child(hic_sep2)
	
	# Column 3: Distance
	var hic_dist_col = VBoxContainer.new()
	hic_dist_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_dist_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hic_dist_col.add_theme_constant_override("separation", 0)
	var hic_dist_title = Label.new()
	hic_dist_title.text = "DISTANCE"
	hic_dist_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hic_dist_title.add_theme_font_size_override("font_size", 12)
	hic_dist_title.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	hic_dist_title.add_theme_color_override("font_outline_color", Color.BLACK)
	hic_dist_title.add_theme_constant_override("outline_size", 2)
	hic_dist_col.add_child(hic_dist_title)
	
	var hic_dist_val_hbox = HBoxContainer.new()
	hic_dist_val_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hic_dist_val_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hic_dist_val_hbox.add_theme_constant_override("separation", 4)
	
	_hole_card_dist_lbl = Label.new()
	_hole_card_dist_lbl.name = "HoleCardDistLabel"
	_hole_card_dist_lbl.text = "---"
	_hole_card_dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hole_card_dist_lbl.add_theme_font_size_override("font_size", 34)
	_hole_card_dist_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35)) # Amber gold
	_hole_card_dist_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_hole_card_dist_lbl.add_theme_constant_override("outline_size", 4)
	hic_dist_val_hbox.add_child(_hole_card_dist_lbl)
	
	var hic_dist_unit = Label.new()
	hic_dist_unit.text = "YDS"
	hic_dist_unit.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hic_dist_unit.add_theme_font_size_override("font_size", 13)
	hic_dist_unit.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	hic_dist_unit.add_theme_color_override("font_outline_color", Color.BLACK)
	hic_dist_unit.add_theme_constant_override("outline_size", 2)
	hic_dist_val_hbox.add_child(hic_dist_unit)
	
	hic_dist_col.add_child(hic_dist_val_hbox)
	hic_cols_hbox.add_child(hic_dist_col)
	
	canvas.add_child(hole_intro_card)
	
	# Catch-Up HUD Banner (Bottom Center above stats bar)
	catch_up_banner = PanelContainer.new()
	catch_up_banner.name = "CatchUpBanner"
	catch_up_banner.visible = false
	catch_up_banner.anchor_left = 0.5
	catch_up_banner.anchor_right = 0.5
	catch_up_banner.anchor_top = 1.0
	catch_up_banner.anchor_bottom = 1.0
	catch_up_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	catch_up_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	catch_up_banner.offset_left = -300
	catch_up_banner.offset_right = 300
	catch_up_banner.offset_top = -148
	catch_up_banner.offset_bottom = -94
	
	var cu_style = StyleBoxFlat.new()
	cu_style.bg_color = Color(0.08, 0.12, 0.20, 0.95)
	cu_style.border_width_left = 2
	cu_style.border_width_top = 2
	cu_style.border_width_right = 2
	cu_style.border_width_bottom = 2
	cu_style.border_color = Color(0.35, 0.75, 1.0, 0.95)
	cu_style.corner_radius_top_left = 12
	cu_style.corner_radius_top_right = 12
	cu_style.corner_radius_bottom_right = 12
	cu_style.corner_radius_bottom_left = 12
	cu_style.content_margin_left = 16
	cu_style.content_margin_right = 16
	cu_style.content_margin_top = 8
	cu_style.content_margin_bottom = 8
	cu_style.shadow_color = Color(0, 0, 0, 0.6)
	cu_style.shadow_size = 8
	catch_up_banner.add_theme_stylebox_override("panel", cu_style)
	
	var cu_hbox = HBoxContainer.new()
	cu_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cu_hbox.add_theme_constant_override("separation", 16)
	catch_up_banner.add_child(cu_hbox)
	
	catch_up_lbl = Label.new()
	catch_up_lbl.name = "CatchUpLabel"
	catch_up_lbl.text = "⛳ Solo Catch-Up in Progress"
	catch_up_lbl.add_theme_font_size_override("font_size", 16)
	catch_up_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	catch_up_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cu_hbox.add_child(catch_up_lbl)
	
	catch_up_skip_btn = Button.new()
	catch_up_skip_btn.name = "CatchUpSkipBtn"
	catch_up_skip_btn.text = "⏩ Skip to Group"
	catch_up_skip_btn.custom_minimum_size = Vector2(145, 36)
	apply_material_button_style(catch_up_skip_btn, Color(0.68, 0.25, 0.25, 0.9))
	catch_up_skip_btn.pressed.connect(func():
		MultiplayerManager.skip_catch_up()
		_update_catch_up_hud()
	)
	cu_hbox.add_child(catch_up_skip_btn)
	canvas.add_child(catch_up_banner)

	# Online Waiting HUD Banner
	online_waiting_banner = PanelContainer.new()
	online_waiting_banner.name = "OnlineWaitingBanner"
	online_waiting_banner.visible = false
	online_waiting_banner.z_index = 450
	online_waiting_banner.anchor_left = 0.5
	online_waiting_banner.anchor_right = 0.5
	online_waiting_banner.anchor_top = 0.12
	online_waiting_banner.anchor_bottom = 0.12
	online_waiting_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	online_waiting_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	online_waiting_banner.custom_minimum_size = Vector2(460, 64)

	var ow_style = StyleBoxFlat.new()
	ow_style.bg_color = Color(0.08, 0.12, 0.16, 0.94)
	ow_style.border_width_left = 2
	ow_style.border_width_top = 2
	ow_style.border_width_right = 2
	ow_style.border_width_bottom = 2
	ow_style.border_color = Color(0.2, 0.6, 0.85, 0.9)
	ow_style.corner_radius_top_left = 12
	ow_style.corner_radius_top_right = 12
	ow_style.corner_radius_bottom_left = 12
	ow_style.corner_radius_bottom_right = 12
	ow_style.content_margin_left = 20
	ow_style.content_margin_right = 20
	ow_style.content_margin_top = 10
	ow_style.content_margin_bottom = 10
	ow_style.shadow_color = Color(0, 0, 0, 0.7)
	ow_style.shadow_size = 8
	online_waiting_banner.add_theme_stylebox_override("panel", ow_style)

	var ow_vbox = VBoxContainer.new()
	ow_vbox.name = "WaitingVBox"
	ow_vbox.add_theme_constant_override("separation", 8)

	online_waiting_lbl = Label.new()
	online_waiting_lbl.name = "WaitingLabel"
	online_waiting_lbl.text = "Waiting for Opponent to hit…"
	online_waiting_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_waiting_lbl.add_theme_font_size_override("font_size", 18)
	online_waiting_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	ow_vbox.add_child(online_waiting_lbl)

	online_afk_warning_lbl = Label.new()
	online_afk_warning_lbl.name = "AfkWarningLabel"
	online_afk_warning_lbl.text = "⚠️ Player appears disconnected"
	online_afk_warning_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_afk_warning_lbl.add_theme_font_size_override("font_size", 14)
	online_afk_warning_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	online_afk_warning_lbl.visible = false
	ow_vbox.add_child(online_afk_warning_lbl)

	online_afk_btn_box = HBoxContainer.new()
	online_afk_btn_box.name = "AfkButtonBox"
	online_afk_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	online_afk_btn_box.add_theme_constant_override("separation", 16)
	online_afk_btn_box.visible = false

	online_concede_btn = Button.new()
	online_concede_btn.name = "ConcedePlayerBtn"
	online_concede_btn.text = "Concede Hole for Player"
	online_concede_btn.custom_minimum_size = Vector2(170, 38)
	apply_material_button_style(online_concede_btn, Color(0.85, 0.55, 0.15, 0.9))
	online_concede_btn.pressed.connect(func():
		if has_node("/root/OnlineMatchController"):
			get_node("/root/OnlineMatchController").concede_active_player()
	)
	online_afk_btn_box.add_child(online_concede_btn)

	online_remove_btn = Button.new()
	online_remove_btn.name = "RemovePlayerBtn"
	online_remove_btn.text = "Remove Player from Match"
	online_remove_btn.custom_minimum_size = Vector2(180, 38)
	apply_material_button_style(online_remove_btn, Color(0.75, 0.22, 0.22, 0.9))
	online_remove_btn.pressed.connect(func():
		if has_node("/root/OnlineMatchController"):
			get_node("/root/OnlineMatchController").remove_active_player()
	)
	online_afk_btn_box.add_child(online_remove_btn)

	online_concede_btn.focus_neighbor_right = online_concede_btn.get_path_to(online_remove_btn)
	online_concede_btn.focus_neighbor_left = online_concede_btn.get_path_to(online_remove_btn)
	online_remove_btn.focus_neighbor_left = online_remove_btn.get_path_to(online_concede_btn)
	online_remove_btn.focus_neighbor_right = online_remove_btn.get_path_to(online_concede_btn)

	ow_vbox.add_child(online_afk_btn_box)
	online_waiting_banner.add_child(ow_vbox)
	canvas.add_child(online_waiting_banner)

	# Add Player Mid-Game Prompt Dialog
	add_player_prompt_dialog = PanelContainer.new()
	add_player_prompt_dialog.name = "AddPlayerPromptDialog"
	add_player_prompt_dialog.visible = false
	add_player_prompt_dialog.z_index = 500
	add_player_prompt_dialog.anchor_left = 0.5
	add_player_prompt_dialog.anchor_right = 0.5
	add_player_prompt_dialog.anchor_top = 0.5
	add_player_prompt_dialog.anchor_bottom = 0.5
	add_player_prompt_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_player_prompt_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_player_prompt_dialog.offset_left = -290
	add_player_prompt_dialog.offset_right = 290
	add_player_prompt_dialog.offset_top = -140
	add_player_prompt_dialog.offset_bottom = 140
	
	var ap_style = StyleBoxFlat.new()
	ap_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	ap_style.border_width_left = 2
	ap_style.border_width_top = 2
	ap_style.border_width_right = 2
	ap_style.border_width_bottom = 2
	ap_style.border_color = Color(0.24, 0.46, 0.72, 0.9)
	ap_style.corner_radius_top_left = 16
	ap_style.corner_radius_top_right = 16
	ap_style.corner_radius_bottom_left = 16
	ap_style.corner_radius_bottom_right = 16
	ap_style.content_margin_left = 24
	ap_style.content_margin_right = 24
	ap_style.content_margin_top = 20
	ap_style.content_margin_bottom = 20
	ap_style.shadow_color = Color(0, 0, 0, 0.75)
	ap_style.shadow_size = 14
	add_player_prompt_dialog.add_theme_stylebox_override("panel", ap_style)
	canvas.add_child(add_player_prompt_dialog)

	# Resume Player Prompt Dialog
	resume_player_prompt_dialog = PanelContainer.new()
	resume_player_prompt_dialog.name = "ResumePlayerPromptDialog"
	resume_player_prompt_dialog.visible = false
	resume_player_prompt_dialog.z_index = 500
	resume_player_prompt_dialog.anchor_left = 0.5
	resume_player_prompt_dialog.anchor_right = 0.5
	resume_player_prompt_dialog.anchor_top = 0.5
	resume_player_prompt_dialog.anchor_bottom = 0.5
	resume_player_prompt_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	resume_player_prompt_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	resume_player_prompt_dialog.offset_left = -290
	resume_player_prompt_dialog.offset_right = 290
	resume_player_prompt_dialog.offset_top = -140
	resume_player_prompt_dialog.offset_bottom = 140
	
	var rp_style = ap_style.duplicate()
	rp_style.border_color = Color(1.0, 0.82, 0.35, 0.9)
	resume_player_prompt_dialog.add_theme_stylebox_override("panel", rp_style)
	canvas.add_child(resume_player_prompt_dialog)
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 90) # Leave room for settings button
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(margin)
	
	top_bar = HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(top_bar)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.08, 0.8) # Transparent gray matching data/stats panels
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.25, 0.25, 0.25, 0.8) # Sleek border matching stats panel
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_bottom = 6.0
	
	# --- Top-Left Unified HUD Widget Construction ---
	var hud_widget = VBoxContainer.new()
	hud_widget.name = "TopLeftHUDWidget"
	hud_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_widget.custom_minimum_size = Vector2(380, 80)
	hud_widget.add_theme_constant_override("separation", 0)
	hud_top_left_widget = hud_widget
	top_bar.add_child(hud_widget)
	hud_widget.resized.connect(func(): _update_minimap_position.call_deferred())
	
	# Row 1: Player Name (Left) | Overall Score (Right)
	var row1 = HBoxContainer.new()
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override("separation", 0)
	hud_widget.add_child(row1)
	
	# Player Name Panel
	var player_name_panel = PanelContainer.new()
	hud_player_name_panel = player_name_panel
	player_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_name_style = StyleBoxFlat.new()
	p_name_style.bg_color = Color(0.36, 0.39, 0.44) # Slate gray (#5c6470)
	p_name_style.corner_radius_top_left = 12
	p_name_style.corner_radius_top_right = 0
	p_name_style.corner_radius_bottom_right = 0
	p_name_style.corner_radius_bottom_left = 0
	p_name_style.border_width_bottom = 1
	p_name_style.border_color = Color(0.25, 0.27, 0.31)
	p_name_style.content_margin_left = 16.0
	p_name_style.content_margin_top = 8.0
	p_name_style.content_margin_right = 16.0
	p_name_style.content_margin_bottom = 8.0
	player_name_panel.add_theme_stylebox_override("panel", p_name_style)
	
	var p_hbox = HBoxContainer.new()
	p_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_hbox.add_theme_constant_override("separation", 10)
	p_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_panel.add_child(p_hbox)
	
	hud_player_badge = PanelContainer.new()
	hud_player_badge.custom_minimum_size = Vector2(26, 26)
	hud_player_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.5, 0.5, 0.5)
	badge_style.corner_radius_top_left = 13
	badge_style.corner_radius_top_right = 13
	badge_style.corner_radius_bottom_left = 13
	badge_style.corner_radius_bottom_right = 13
	badge_style.content_margin_left = 4
	badge_style.content_margin_right = 4
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	hud_player_badge.add_theme_stylebox_override("panel", badge_style)
	p_hbox.add_child(hud_player_badge)
	
	hud_player_avatar_rect = TextureRect.new()
	hud_player_avatar_rect.custom_minimum_size = Vector2(26, 26)
	hud_player_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud_player_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud_player_avatar_rect.visible = false
	hud_player_badge.add_child(hud_player_avatar_rect)
	
	hud_player_badge_lbl = Label.new()
	hud_player_badge_lbl.text = "P"
	hud_player_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_player_badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_player_badge_lbl.add_theme_font_size_override("font_size", 13)
	hud_player_badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	hud_player_badge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_player_badge_lbl.add_theme_constant_override("outline_size", 3)
	hud_player_badge.add_child(hud_player_badge_lbl)
	
	hud_player_name_lbl = Label.new()
	hud_player_name_lbl.name = "PlayerNameLabel"
	hud_player_name_lbl.text = "Sterling Kohel"
	hud_player_name_lbl.add_theme_font_size_override("font_size", 24)
	hud_player_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	hud_player_name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_player_name_lbl.add_theme_constant_override("outline_size", 4)
	p_hbox.add_child(hud_player_name_lbl)
	row1.add_child(player_name_panel)
	
	# Overall Score Panel
	var overall_score_panel = PanelContainer.new()
	hud_overall_score_panel = overall_score_panel
	overall_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overall_score_panel.custom_minimum_size = Vector2(90, 0)
	var o_score_style = StyleBoxFlat.new()
	o_score_style.bg_color = Color(0.1, 0.1, 0.1) # Black (#1a1a1a)
	o_score_style.corner_radius_top_left = 0
	o_score_style.corner_radius_top_right = 12
	o_score_style.corner_radius_bottom_right = 0
	o_score_style.corner_radius_bottom_left = 0
	o_score_style.border_width_bottom = 1
	o_score_style.border_color = Color(0.06, 0.06, 0.06)
	o_score_style.content_margin_left = 12.0
	o_score_style.content_margin_top = 8.0
	o_score_style.content_margin_right = 12.0
	o_score_style.content_margin_bottom = 8.0
	overall_score_panel.add_theme_stylebox_override("panel", o_score_style)
	
	hud_overall_score_lbl = Label.new()
	hud_overall_score_lbl.name = "OverallScoreLabel"
	hud_overall_score_lbl.text = "+11"
	hud_overall_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_overall_score_lbl.add_theme_font_size_override("font_size", 26)
	hud_overall_score_lbl.add_theme_color_override("font_color", Color.WHITE)
	hud_overall_score_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_overall_score_lbl.add_theme_constant_override("outline_size", 4)
	overall_score_panel.add_child(hud_overall_score_lbl)
	row1.add_child(overall_score_panel)
	
	# Row 2: Hole Number (Left) | Shots & Par Tracker (Right)
	var row2 = HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_theme_constant_override("separation", 0)
	hud_widget.add_child(row2)
	
	# Hole Number Panel
	var hole_num_panel = PanelContainer.new()
	hole_num_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole_num_panel.custom_minimum_size = Vector2(70, 0) # Narrow white box
	var h_num_style = StyleBoxFlat.new()
	h_num_style.bg_color = Color.WHITE
	h_num_style.corner_radius_top_left = 0
	h_num_style.corner_radius_top_right = 0
	h_num_style.corner_radius_bottom_right = 0
	h_num_style.corner_radius_bottom_left = 12
	h_num_style.content_margin_left = 12.0
	h_num_style.content_margin_top = 6.0
	h_num_style.content_margin_right = 12.0
	h_num_style.content_margin_bottom = 6.0
	_hole_num_style = h_num_style
	hole_num_panel.add_theme_stylebox_override("panel", h_num_style)
	
	hud_hole_num_lbl = Label.new()
	hud_hole_num_lbl.name = "HoleNumLabel"
	hud_hole_num_lbl.text = "8"
	hud_hole_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hole_num_lbl.add_theme_font_size_override("font_size", 26)
	hud_hole_num_lbl.add_theme_color_override("font_color", Color.BLACK) # Black text
	hole_num_panel.add_child(hud_hole_num_lbl)
	row2.add_child(hole_num_panel)
	
	# Shots Panel
	var shots_panel = PanelContainer.new()
	shots_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shots_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shots_style = StyleBoxFlat.new()
	shots_style.bg_color = Color(0.18, 0.20, 0.23) # Dark slate-gray (#2d323b)
	shots_style.corner_radius_top_left = 0
	shots_style.corner_radius_top_right = 0
	shots_style.corner_radius_bottom_right = 12
	shots_style.corner_radius_bottom_left = 0
	shots_style.content_margin_left = 16.0
	shots_style.content_margin_top = 8.0
	shots_style.content_margin_right = 16.0
	shots_style.content_margin_bottom = 8.0
	_shots_style = shots_style
	shots_panel.add_theme_stylebox_override("panel", shots_style)
	
	hud_shots_rtl = RichTextLabel.new()
	hud_shots_rtl.name = "ShotsRichTextLabel"
	hud_shots_rtl.bbcode_enabled = true
	hud_shots_rtl.scroll_active = false
	hud_shots_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud_shots_rtl.custom_minimum_size = Vector2(0, 36)
	hud_shots_rtl.add_theme_font_size_override("normal_font_size", 22)
	hud_shots_rtl.add_theme_font_size_override("bold_font_size", 22)
	hud_shots_rtl.add_theme_font_size_override("bold_italics_font_size", 22)
	hud_shots_rtl.add_theme_font_size_override("italics_font_size", 22)
	hud_shots_rtl.add_theme_color_override("default_color", Color.WHITE)
	shots_panel.add_child(hud_shots_rtl)
	row2.add_child(shots_panel)

	# Row 3: Multi-Player Distance Queue Component
	hud_distance_queue_panel = PanelContainer.new()
	hud_distance_queue_panel.name = "DistanceQueuePanel"
	hud_distance_queue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_distance_queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_distance_queue_panel.visible = false

	var dq_style = StyleBoxFlat.new()
	dq_style.bg_color = Color(0.08, 0.08, 0.08, 0.7) # Translucent background
	dq_style.border_width_left = 1
	dq_style.border_width_right = 1
	dq_style.border_width_bottom = 1
	dq_style.border_color = Color(0.25, 0.27, 0.31, 0.6) # Muted border
	dq_style.corner_radius_bottom_left = 12
	dq_style.corner_radius_bottom_right = 12
	dq_style.content_margin_left = 14.0
	dq_style.content_margin_top = 4.0
	dq_style.content_margin_right = 14.0
	dq_style.content_margin_bottom = 6.0
	hud_distance_queue_panel.add_theme_stylebox_override("panel", dq_style)

	hud_distance_queue_vbox = VBoxContainer.new()
	hud_distance_queue_vbox.name = "DistanceQueueVBox"
	hud_distance_queue_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_distance_queue_vbox.add_theme_constant_override("separation", 3)
	hud_distance_queue_panel.add_child(hud_distance_queue_vbox)

	hud_widget.add_child(hud_distance_queue_panel)

	# Settings Button (Icon Only) - Top-Right Corner, enlarged for touch
	settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = ""
	settings_btn.tooltip_text = "Settings"
	settings_btn.icon = load("res://Utils/Settings/Gear.png")
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn.custom_minimum_size = Vector2(64, 64)
	apply_circular_button_style(settings_btn, Color(0.15, 0.15, 0.15, 0.85))
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.offset_left = -88
	settings_btn.offset_top = 20
	settings_btn.offset_right = -24
	settings_btn.offset_bottom = 84
	settings_btn.pressed.connect(func():
		if range_ui != null:
			range_ui.call("_on_toggle_settings_requested")
	)
	canvas.add_child(settings_btn)

	# Home / Main Menu Button (Icon Only) - positioned between Settings and HideHelpers
	home_btn = Button.new()
	home_btn.name = "HomeButton"
	home_btn.text = ""
	home_btn.tooltip_text = "Main Menu"
	if ResourceLoader.exists("res://assets/images/icons/home.svg"):
		home_btn.icon = load("res://assets/images/icons/home.svg")
	home_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_btn.custom_minimum_size = Vector2(64, 64)
	apply_circular_button_style(home_btn, Color(0.15, 0.15, 0.15, 0.85))
	home_btn.anchor_left = 1.0
	home_btn.anchor_right = 1.0
	home_btn.offset_left = -184
	home_btn.offset_top = 20
	home_btn.offset_right = -120
	home_btn.offset_bottom = 84
	home_btn.pressed.connect(func():
		if MultiplayerManager.is_finished:
			SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
		elif exit_confirm_dialog != null:
			if forfeit_confirm_dialog != null:
				forfeit_confirm_dialog.visible = false
			if mulligan_confirm_dialog != null:
				mulligan_confirm_dialog.visible = false
			exit_confirm_dialog.visible = true
			var no_b = exit_confirm_dialog.find_child("NoButton", true, false) as Button
			if no_b != null:
				no_b.call_deferred("grab_focus")
			if has_node("/root/AnnouncerEngine"):
				var cur_score_rel := 0
				if MultiplayerManager != null:
					var p = MultiplayerManager.get_active_player()
					if p != null:
						for h_id in MultiplayerManager.hole_ids:
							var sc = p.get("hole_scores", {}).get(h_id)
							if sc != null and sc > 0:
								var par_val = int(MultiplayerManager.hole_info.get(h_id, {}).get("Par", 4))
								cur_score_rel += (int(sc) - par_val)
				var cur_h_idx = clamp(MultiplayerManager.current_hole_index, 0, max(0, MultiplayerManager.hole_ids.size() - 1)) if MultiplayerManager != null else 0
				var ctx = {
					"game_mode": "course_play",
					"hole_number": cur_h_idx + 1,
					"hole_range": "front_nine" if cur_h_idx < 9 else "back_nine",
					"score_relative_to_par": cur_score_rel,
					"total_score_relative_to_par": cur_score_rel,
					"score_status": "over_par" if cur_score_rel > 0 else ("under_par" if cur_score_rel < 0 else "even_par"),
					"overall_score": "over_par" if cur_score_rel > 0 else ("under_par" if cur_score_rel < 0 else "even_par")
				}
				get_node("/root/AnnouncerEngine").call("SpeakHomeButtonHeckle", ctx)
	)
	canvas.add_child(home_btn)

	# Hide/Show Helpers Button (Icon Only) - positioned to the left of Home Button
	hide_helpers_btn = Button.new()
	hide_helpers_btn.name = "HideHelpersButton"
	hide_helpers_btn.text = ""
	hide_helpers_btn.tooltip_text = "Toggle Helpers (Show/Hide)"
	if ResourceLoader.exists("res://assets/images/icons/helpers.svg"):
		hide_helpers_btn.icon = load("res://assets/images/icons/helpers.svg")
	hide_helpers_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_helpers_btn.custom_minimum_size = Vector2(64, 64)
	apply_circular_button_style(hide_helpers_btn, Color(0.15, 0.15, 0.15, 0.85))
	hide_helpers_btn.anchor_left = 1.0
	hide_helpers_btn.anchor_right = 1.0
	hide_helpers_btn.offset_left = -280
	hide_helpers_btn.offset_top = 20
	hide_helpers_btn.offset_right = -216
	hide_helpers_btn.offset_bottom = 84
	canvas.add_child(hide_helpers_btn)

	# RightPanel vertical stack - starts below ClubSelector
	right_panel = VBoxContainer.new()
	right_panel.name = "RightPanel"
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -280
	right_panel.offset_top = 166
	right_panel.offset_right = -24
	right_panel.offset_bottom = -96
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.add_theme_constant_override("separation", 12)
	canvas.add_child(right_panel)

	# ScrollContainer keeps buttons visible on short screens - hidden by default!
	toggles_scroll = ScrollContainer.new()
	toggles_scroll.name = "TogglesScroll"
	toggles_scroll.visible = false
	toggles_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	toggles_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	toggles_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	toggles_scroll.follow_focus = true
	ThemeManager.apply_scroll_container_style(toggles_scroll, 28)
	
	toggles_container = VBoxContainer.new()
	toggles_container.name = "TogglesContainer"
	toggles_container.add_theme_constant_override("separation", 12)
	toggles_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toggles_container.custom_minimum_size = Vector2(256, 0)
	
	hide_helpers_btn.pressed.connect(func():
		var new_vis = not toggles_scroll.visible
		_set_helpers_visible(new_vis)
	)
	
	toggles_scroll.add_child(toggles_container)
	right_panel.add_child(toggles_scroll)

	var v_bar = toggles_scroll.get_v_scroll_bar()
	if v_bar != null:
		v_bar.visibility_changed.connect(func(): _update_helpers_scroll_layout.call_deferred())
	toggles_scroll.visibility_changed.connect(func(): _update_helpers_scroll_layout.call_deferred())
	toggles_scroll.resized.connect(func(): _update_helpers_scroll_layout.call_deferred())
	toggles_container.resized.connect(func(): _update_helpers_scroll_layout.call_deferred())

	# Distance Menu setup
	var distance_menu_script = load("res://UI/distance_menu.gd")
	var dist_menu = distance_menu_script.new()
	dist_menu.name = "DistanceMenu"
	dist_menu.visible = false
	dist_menu.inject_shot.connect(func(data):
		if course_instance != null and course_instance.has_method("_on_range_ui_hit_shot"):
			course_instance.call("_on_range_ui_hit_shot", data)
	)
	
	# Hit Menu (formerly Hit Distance) Button
	dist_btn = Button.new()
	dist_btn.name = "HitDistanceButton"
	dist_btn.text = "🎯 Hit Menu"
	dist_btn.custom_minimum_size = Vector2(180, 56)
	dist_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	apply_material_button_style(dist_btn, Color(0.6, 0.2, 0.6, 0.85))
	dist_btn.pressed.connect(func():
		if dist_menu:
			if dist_menu.visible:
				if dist_menu.has_method("close"):
					dist_menu.close()
				else:
					dist_menu.visible = false
				var vp = get_viewport()
				if vp != null:
					vp.gui_release_focus()
			else:
				dist_menu.visible = true
				dist_menu.current_ball_node = active_ball
				if course_instance != null and "aim_target_pos" in course_instance:
					dist_menu.aim_target_node = course_instance.get("aim_target_pos")
			_update_hit_distance_button_state()
			_update_helpers_scroll_layout.call_deferred()
	)
	dist_btn.set_meta("toggle_target", dist_menu)
	dist_menu.visibility_changed.connect(func():
		_update_hit_distance_button_state()
		_update_helpers_scroll_layout.call_deferred()
	)
	toggles_container.add_child(dist_btn)
	toggles_container.add_child(dist_menu)
	_update_hit_distance_button_visibility()

	# --- Immersion Menu Submenu ---
	imm_menu_btn = Button.new()
	imm_menu_btn.name = "ImmersionMenuButton"
	imm_menu_btn.text = "🎭 Immersion Menu"
	imm_menu_btn.tooltip_text = "Toggle Immersion Settings (Suspense, Announcer, Putting Cam, Screen Offset)"
	imm_menu_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(imm_menu_btn, Color(0.35, 0.45, 0.6, 0.85))

	imm_menu_container = VBoxContainer.new()
	imm_menu_container.name = "ImmersionMenuContainer"
	imm_menu_container.add_theme_constant_override("separation", 10)
	imm_menu_container.visible = false

	imm_menu_btn.pressed.connect(func():
		imm_menu_container.visible = not imm_menu_container.visible
		if imm_menu_container.visible:
			imm_menu_btn.text = "🎭 Immersion Menu: OPEN"
			apply_material_button_style(imm_menu_btn, Color(0.45, 0.55, 0.75, 0.9))
		else:
			imm_menu_btn.text = "🎭 Immersion Menu"
			apply_material_button_style(imm_menu_btn, Color(0.35, 0.45, 0.6, 0.85))
		_update_helpers_scroll_layout.call_deferred()
		call_deferred("_update_hud_focus_neighbors")
	)
	toggles_container.add_child(imm_menu_btn)
	toggles_container.add_child(imm_menu_container)

	# Suspense Heartbeat & Tunnel Vision Toggle Button
	tension_btn = Button.new()
	tension_btn.name = "SuspenseToggleButton"
	var is_tension_on = GlobalSettings.range_settings.tension_effects_enabled.value if has_node("/root/GlobalSettings") else true
	tension_btn.text = "💓 Suspense: ON" if is_tension_on else "💓 Suspense: OFF"
	tension_btn.tooltip_text = "Toggle Suspense Heartbeat & Tunnel Vision in Course Play"
	tension_btn.custom_minimum_size = Vector2(180, 56)
	var initial_tension_color = Color(0.75, 0.2, 0.3, 0.85) if is_tension_on else Color(0.5, 0.5, 0.5, 0.85)
	apply_material_button_style(tension_btn, initial_tension_color)
	tension_btn.pressed.connect(func():
		if has_node("/root/GlobalSettings"):
			var new_val = not GlobalSettings.range_settings.tension_effects_enabled.value
			GlobalSettings.range_settings.tension_effects_enabled.value = new_val
			GlobalSettings.save_settings()
			if not new_val and has_node("/root/TensionManager"):
				TensionManager.stop_tension(true, true)
			if new_val:
				tension_btn.text = "💓 Suspense: ON"
				apply_material_button_style(tension_btn, Color(0.75, 0.2, 0.3, 0.85))
			else:
				tension_btn.text = "💓 Suspense: OFF"
				apply_material_button_style(tension_btn, Color(0.5, 0.5, 0.5, 0.85))
	)
	imm_menu_container.add_child(tension_btn)

	# Announcer Mute/Unmute Toggle Button
	announcer_btn = Button.new()
	announcer_btn.name = "AnnouncerToggleButton"
	var announcer_node = get_node_or_null("/root/AnnouncerEngine")
	var is_announcer_on = announcer_node.get("AnnouncerCoursePlay") if announcer_node != null else true
	announcer_btn.text = "🎙 Announcer: ON" if is_announcer_on else "🎙 Announcer: MUTED"
	announcer_btn.tooltip_text = "Toggle Announcer Commentary"
	announcer_btn.custom_minimum_size = Vector2(180, 56)
	var initial_ann_color = Color(0.2, 0.6, 0.3, 0.85) if is_announcer_on else Color(0.5, 0.5, 0.5, 0.85)
	apply_material_button_style(announcer_btn, initial_ann_color)
	announcer_btn.pressed.connect(func():
		var a = get_node_or_null("/root/AnnouncerEngine")
		if a != null:
			var current_val = a.get("AnnouncerCoursePlay") as bool
			var new_val = not current_val
			a.set("AnnouncerCoursePlay", new_val)
			GlobalSettings.save_settings()
			if new_val:
				announcer_btn.text = "🎙 Announcer: ON"
				apply_material_button_style(announcer_btn, Color(0.2, 0.6, 0.3, 0.85))
				a.call("SpeakHecklesEnabled")
			else:
				announcer_btn.text = "🎙 Announcer: MUTED"
				apply_material_button_style(announcer_btn, Color(0.5, 0.5, 0.5, 0.85))
				a.call("SpeakHecklesDisabled")
	)
	imm_menu_container.add_child(announcer_btn)

	# Putting Cam Toggle Button
	putting_cam_btn = Button.new()
	putting_cam_btn.name = "PuttingCamButton"
	putting_cam_btn.text = "🎯 Putting Cam: OFF"
	putting_cam_btn.tooltip_text = "Toggle Putting Camera (Right-click for Setup)"
	putting_cam_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(putting_cam_btn, Color(0.35, 0.35, 0.35, 0.85))
	putting_cam_btn.pressed.connect(func():
		if range_ui != null and range_ui.has_method("is_putting_camera_enabled"):
			var enabled = range_ui.call("is_putting_camera_enabled")
			var minimized = range_ui.call("is_putting_camera_minimized") if range_ui.has_method("is_putting_camera_minimized") else false
			if not enabled:
				range_ui.call("set_putting_camera_visible", true)
			elif minimized:
				if range_ui.has_method("restore_putting_camera"):
					range_ui.call("restore_putting_camera")
				else:
					range_ui.call("set_putting_camera_visible", true)
			else:
				range_ui.call("set_putting_camera_visible", false)
		_update_course_putting_cam_btn_state()
	)
	putting_cam_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			if range_ui != null and range_ui.has_method("open_camera_setup"):
				range_ui.call("open_camera_setup", true)
				get_viewport().set_input_as_handled()
	)
	imm_menu_container.add_child(putting_cam_btn)
	_update_course_putting_cam_btn_state()

	# Screen Offset Toggle & Dual Sliders (General & Putter)
	var so_script = load("res://UI/ScreenOffset/screen_offset_control.gd")
	var so_ctrl = so_script.new()
	so_ctrl.name = "ScreenOffsetControl"
	so_ctrl.is_course_play = true
	so_ctrl.show_putter_slider = true
	so_ctrl.style_button = func(btn: Button, is_on: bool):
		var c = Color(0.2, 0.5, 0.75, 0.85) if is_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(btn, c)
	imm_menu_container.add_child(so_ctrl)
	_screen_offset_ctrl = so_ctrl
	if so_ctrl.has_signal("offset_toggled"):
		so_ctrl.offset_toggled.connect(func(_on):
			_update_helpers_scroll_layout.call_deferred()
			call_deferred("_update_hud_focus_neighbors")
		)

	# --- Training Menu Submenu ---
	train_menu_btn = Button.new()
	train_menu_btn.name = "TrainingMenuButton"
	train_menu_btn.text = "🎯 Training Menu"
	train_menu_btn.tooltip_text = "Toggle Training Tools (Golfer Cam, Shot Analysis, Track Averages, Rollout)"
	train_menu_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(train_menu_btn, Color(0.25, 0.5, 0.55, 0.85))

	train_menu_container = VBoxContainer.new()
	train_menu_container.name = "TrainingMenuContainer"
	train_menu_container.add_theme_constant_override("separation", 10)
	train_menu_container.visible = false

	train_menu_btn.pressed.connect(func():
		train_menu_container.visible = not train_menu_container.visible
		if train_menu_container.visible:
			train_menu_btn.text = "🎯 Training Menu: OPEN"
			apply_material_button_style(train_menu_btn, Color(0.35, 0.6, 0.68, 0.9))
		else:
			train_menu_btn.text = "🎯 Training Menu"
			apply_material_button_style(train_menu_btn, Color(0.25, 0.5, 0.55, 0.85))
		_update_helpers_scroll_layout.call_deferred()
		call_deferred("_update_hud_focus_neighbors")
	)
	toggles_container.add_child(train_menu_btn)
	toggles_container.add_child(train_menu_container)

	# Golfer Cam Toggle Button
	golfer_cam_btn = Button.new()
	golfer_cam_btn.name = "GolferCamButton"
	golfer_cam_btn.text = "📹 Golfer Cam: OFF"
	golfer_cam_btn.tooltip_text = "Toggle Golfer Camera (Right-click for Setup)"
	golfer_cam_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(golfer_cam_btn, Color(0.2, 0.45, 0.45, 0.85))
	golfer_cam_btn.pressed.connect(func():
		if range_ui != null:
			var enabled = range_ui.call("is_golfer_camera_enabled") if range_ui.has_method("is_golfer_camera_enabled") else false
			var minimized = range_ui.call("is_golfer_camera_minimized") if range_ui.has_method("is_golfer_camera_minimized") else false
			if not enabled:
				range_ui.call("set_golfer_camera_visible", true)
			elif minimized:
				if range_ui.has_method("restore_golfer_camera"):
					range_ui.call("restore_golfer_camera")
				else:
					range_ui.call("set_golfer_camera_visible", true)
			else:
				range_ui.call("set_golfer_camera_visible", false)
			_update_course_golfer_cam_btn_state()
	)
	golfer_cam_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			if range_ui != null and range_ui.has_method("open_camera_setup"):
				range_ui.call("open_camera_setup", false)
				get_viewport().set_input_as_handled()
	)
	train_menu_container.add_child(golfer_cam_btn)
	_update_course_golfer_cam_btn_state()

	# Shot Analysis Toggle Button
	var shot_analysis_btn = Button.new()
	shot_analysis_btn.name = "ShotAnalysisButton"
	var is_shot_analysis_on = GlobalSettings.range_settings.shot_analysis_enabled.value if has_node("/root/GlobalSettings") else false
	shot_analysis_btn.text = "📊 Shot Analysis: ON" if is_shot_analysis_on else "📊 Shot Analysis: OFF"
	shot_analysis_btn.tooltip_text = "Toggle Shot Suggestions & Flaw Analysis"
	shot_analysis_btn.custom_minimum_size = Vector2(180, 56)
	var initial_analysis_color = Color(0.15, 0.55, 0.75, 0.85) if is_shot_analysis_on else Color(0.25, 0.35, 0.45, 0.85)
	apply_material_button_style(shot_analysis_btn, initial_analysis_color)
	shot_analysis_btn.pressed.connect(func():
		if has_node("/root/GlobalSettings"):
			var new_val = not GlobalSettings.range_settings.shot_analysis_enabled.value
			GlobalSettings.range_settings.shot_analysis_enabled.value = new_val
			GlobalSettings.save_settings()
			if range_ui != null and range_ui.has_method("set_shot_analysis_enabled"):
				range_ui.call("set_shot_analysis_enabled", new_val)
			if new_val:
				shot_analysis_btn.text = "📊 Shot Analysis: ON"
				apply_material_button_style(shot_analysis_btn, Color(0.15, 0.55, 0.75, 0.85))
			else:
				shot_analysis_btn.text = "📊 Shot Analysis: OFF"
				apply_material_button_style(shot_analysis_btn, Color(0.25, 0.35, 0.45, 0.85))
	)
	train_menu_container.add_child(shot_analysis_btn)

	# Track Club Distances & Averages Toggle Button
	track_averages_btn = Button.new()
	track_averages_btn.name = "TrackAveragesButton"
	var is_tracking_on = true
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and mp_mgr.has_method("is_club_averages_tracking_enabled"):
		is_tracking_on = mp_mgr.is_club_averages_tracking_enabled()
	track_averages_btn.text = "📊 Track Averages: ON" if is_tracking_on else "📊 Track Averages: OFF"
	track_averages_btn.tooltip_text = "Toggle Club Distances & Shot Averages Tracking"
	track_averages_btn.custom_minimum_size = Vector2(180, 56)
	var initial_tracking_color = Color(0.18, 0.55, 0.65, 0.85) if is_tracking_on else Color(0.5, 0.5, 0.5, 0.85)
	apply_material_button_style(track_averages_btn, initial_tracking_color)
	track_averages_btn.pressed.connect(func():
		var cur_state = true
		var mp = get_node_or_null("/root/MultiplayerManager")
		if mp != null and mp.has_method("is_club_averages_tracking_enabled"):
			cur_state = mp.is_club_averages_tracking_enabled()
		var new_state = not cur_state
		if mp != null and mp.has_method("set_club_averages_tracking_enabled"):
			mp.set_club_averages_tracking_enabled(new_state)
		elif has_node("/root/GlobalSettings") and GlobalSettings.range_settings != null and "track_club_averages" in GlobalSettings.range_settings:
			GlobalSettings.range_settings.track_club_averages.value = new_state
			GlobalSettings.save_settings()
		_update_track_averages_btn_state()
	)
	if mp_mgr != null and mp_mgr.has_signal("club_averages_tracking_toggled"):
		mp_mgr.club_averages_tracking_toggled.connect(func(_enabled): _update_track_averages_btn_state())
	train_menu_container.add_child(track_averages_btn)

	# Ball Rollout Toggle Button
	rollout_btn = Button.new()
	rollout_btn.name = "RolloutToggleButton"
	var is_rollout_on = GlobalSettings.range_settings.ball_rollout_enabled.value if has_node("/root/GlobalSettings") else true
	rollout_btn.text = "🔄 Rollout: ON" if is_rollout_on else "🔄 Rollout: OFF"
	rollout_btn.tooltip_text = "Toggle Ball Rollout & Bounce"
	rollout_btn.custom_minimum_size = Vector2(180, 56)
	var initial_rollout_color = Color(0.2, 0.6, 0.4, 0.85) if is_rollout_on else Color(0.5, 0.5, 0.5, 0.85)
	apply_material_button_style(rollout_btn, initial_rollout_color)
	rollout_btn.pressed.connect(func():
		if has_node("/root/GlobalSettings"):
			var new_val = not GlobalSettings.range_settings.ball_rollout_enabled.value
			GlobalSettings.range_settings.ball_rollout_enabled.value = new_val
			GlobalSettings.save_settings()
			if range_ui != null and range_ui.has_method("set_rollout_enabled"):
				range_ui.call("set_rollout_enabled", new_val)
			if new_val:
				rollout_btn.text = "🔄 Rollout: ON"
				apply_material_button_style(rollout_btn, Color(0.2, 0.6, 0.4, 0.85))
			else:
				rollout_btn.text = "🔄 Rollout: OFF"
				apply_material_button_style(rollout_btn, Color(0.5, 0.5, 0.5, 0.85))
	)
	train_menu_container.add_child(rollout_btn)

	# --- Visuals Menu Submenu ---
	visuals_menu_btn = Button.new()
	visuals_menu_btn.name = "VisualsMenuButton"
	visuals_menu_btn.text = "👁️ Visuals Menu"
	visuals_menu_btn.tooltip_text = "Toggle Visual Settings (Free Camera, Graphics Quality, etc.)"
	visuals_menu_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(visuals_menu_btn, Color(0.4, 0.35, 0.65, 0.85))

	visuals_menu_container = VBoxContainer.new()
	visuals_menu_container.name = "VisualsMenuContainer"
	visuals_menu_container.add_theme_constant_override("separation", 10)
	visuals_menu_container.visible = false

	visuals_menu_btn.pressed.connect(func():
		visuals_menu_container.visible = not visuals_menu_container.visible
		if visuals_menu_container.visible:
			visuals_menu_btn.text = "👁️ Visuals Menu: OPEN"
			apply_material_button_style(visuals_menu_btn, Color(0.5, 0.45, 0.75, 0.9))
		else:
			visuals_menu_btn.text = "👁️ Visuals Menu"
			apply_material_button_style(visuals_menu_btn, Color(0.4, 0.35, 0.65, 0.85))
		_update_helpers_scroll_layout.call_deferred()
		call_deferred("_update_hud_focus_neighbors")
	)
	toggles_container.add_child(visuals_menu_btn)
	toggles_container.add_child(visuals_menu_container)

	# Free Camera Toggle Button
	free_cam_btn = Button.new()
	free_cam_btn.name = "FreeCameraButton"
	free_cam_btn.text = "🎥 Free Camera: OFF"
	free_cam_btn.tooltip_text = "Toggle Free Camera (Fly: WASD/Arrows, Up/Down: Space/Ctrl/E/Q/Wheel, or Click to Move)"
	free_cam_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(free_cam_btn, Color(0.35, 0.35, 0.35, 0.85))
	free_cam_btn.pressed.connect(func():
		toggle_free_camera()
	)
	visuals_menu_container.add_child(free_cam_btn)

	# Graphics Quality Toggle Button
	graphics_toggle_btn = Button.new()
	graphics_toggle_btn.name = "GraphicsToggleButton"
	graphics_toggle_btn.custom_minimum_size = Vector2(180, 56)
	graphics_toggle_btn.pressed.connect(func():
		_cycle_graphics_quality(false)
	)
	graphics_toggle_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle_graphics_quality(true)
	)
	visuals_menu_container.add_child(graphics_toggle_btn)
	_update_graphics_toggle_btn_state()

	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and not gs.range_settings.settings_changed.is_connected(_update_graphics_toggle_btn_state):
			gs.range_settings.settings_changed.connect(_update_graphics_toggle_btn_state)

	# Stuck Ball Relief Button
	var s_btn = Button.new()
	s_btn.name = "StuckBallButton"
	s_btn.text = "⛳ Stuck Ball Relief"
	s_btn.tooltip_text = "Move ball 2 yards closer to nearest fairway without counting a stroke"
	s_btn.custom_minimum_size = Vector2(180, 56)
	apply_material_button_style(s_btn, Color(0.75, 0.45, 0.15, 0.85))
	s_btn.pressed.connect(func():
		move_stuck_ball(2.0)
	)
	toggles_container.add_child(s_btn)
	stuck_ball_btn = s_btn


	var is_match_play = not MultiplayerManager.players.is_empty() and not MultiplayerManager.practice_mode_active

	if is_match_play:
		# Scorecard Toggle Button
		var scorecard_btn = Button.new()
		scorecard_btn.name = "ScorecardToggleButton"
		scorecard_btn.text = "📋 Scorecard"
		scorecard_btn.custom_minimum_size = Vector2(180, 56)
		apply_material_button_style(scorecard_btn, Color(0.72, 0.56, 0.24, 0.85)) # Gold color
		scorecard_btn.pressed.connect(_on_scorecard_toggle_pressed)
		toggles_container.add_child(scorecard_btn)

	# If in practice mode, create practice buttons (initially hidden, shown only in map view)
	if MultiplayerManager.practice_mode_active and not GlobalSettings.is_chipping_minigame:
		var place_btn = Button.new()
		place_btn.name = "PlaceBallButton"
		place_btn.text = "📍 Place Ball: OFF"
		place_btn.custom_minimum_size = Vector2(210, 64)
		place_btn.add_theme_font_size_override("font_size", 20)
		apply_material_button_style(place_btn, Color(0.5, 0.5, 0.5, 0.85)) # Gray by default
		place_btn.pressed.connect(func():
			if course_instance != null:
				var current_mode = course_instance.get("place_ball_mode")
				var new_mode = not current_mode
				course_instance.set("place_ball_mode", new_mode)
				if new_mode:
					place_btn.text = "📍 Place Ball: ON"
					apply_material_button_style(place_btn, Color(0.2, 0.6, 0.3, 0.85)) # Green when ON
				else:
					place_btn.text = "📍 Place Ball: OFF"
					apply_material_button_style(place_btn, Color(0.5, 0.5, 0.5, 0.85))
		)
		place_btn.visible = false # Hidden initially
		toggles_container.add_child(place_btn)
		
		var prev_btn = Button.new()
		prev_btn.name = "PrevHoleButton"
		prev_btn.text = "❮ Previous Hole"
		prev_btn.custom_minimum_size = Vector2(210, 64)
		prev_btn.add_theme_font_size_override("font_size", 20)
		apply_material_button_style(prev_btn, Color(0.4, 0.4, 0.4, 0.85))
		prev_btn.pressed.connect(func():
			if course_instance != null and course_instance.has_method("prev_practice_hole"):
				course_instance.call("prev_practice_hole")
		)
		prev_btn.visible = false
		toggles_container.add_child(prev_btn)
		
		var next_btn = Button.new()
		next_btn.name = "NextHoleButton"
		next_btn.text = "❯ Next Hole"
		next_btn.custom_minimum_size = Vector2(210, 64)
		next_btn.add_theme_font_size_override("font_size", 20)
		apply_material_button_style(next_btn, Color(0.4, 0.4, 0.4, 0.85))
		next_btn.pressed.connect(func():
			if course_instance != null and course_instance.has_method("next_practice_hole"):
				course_instance.call("next_practice_hole")
		)
		next_btn.visible = false
		toggles_container.add_child(next_btn)
		
		# Move them to the top of toggles_container so they are ordered nicely
		var top_idx = imm_menu_btn.get_index() if imm_menu_btn != null and is_instance_valid(imm_menu_btn) else 0
		toggles_container.move_child(place_btn, top_idx)
		toggles_container.move_child(prev_btn, top_idx + 1)
		toggles_container.move_child(next_btn, top_idx + 2)
	
	# Reparent ClubSelector to canvas directly underneath SettingsButton and HideHelpersButton
	if range_ui != null:
		var club_sel = range_ui.get_node_or_null("GridCanvas/ClubSelector")
		if club_sel == null:
			club_sel = range_ui.get_node_or_null("OverlayLayer/ClubSelector")
			if club_sel == null:
				club_sel = range_ui.get_node_or_null("RightPanel/TogglesScroll/TogglesContainer/ClubSelector")
				if club_sel == null:
					club_sel = range_ui.get_node_or_null("RightPanel/TogglesContainer/ClubSelector")
					if club_sel == null:
						club_sel = range_ui.get_node_or_null("RightPanel/ClubSelector")
		if club_sel != null:
			club_sel.reparent(canvas)
			club_sel.anchor_left = 1.0
			club_sel.anchor_right = 1.0
			club_sel.anchor_top = 0.0
			club_sel.anchor_bottom = 0.0
			club_sel.offset_left = -280
			club_sel.offset_top = 96
			club_sel.offset_right = -24
			club_sel.offset_bottom = 152
			club_sel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			club_sel.custom_minimum_size = Vector2(256, 56)
			club_sel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			club_selector_node = club_sel

	# Stats Button (Icon Only) - Bottom-Left Corner
	stats_btn = Button.new()
	stats_btn.name = "StatsButton"
	stats_btn.text = ""
	stats_btn.tooltip_text = "Toggle Stats (Show/Hide)"
	stats_btn.expand_icon = true
	if ResourceLoader.exists("res://assets/images/icons/stats.svg"):
		stats_btn.icon = load("res://assets/images/icons/stats.svg")
	stats_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_btn.custom_minimum_size = Vector2(80, 80)
	apply_circular_button_style(stats_btn, Color(0.24, 0.46, 0.72, 0.85)) # Blue
	stats_btn.anchor_left = 0.0
	stats_btn.anchor_right = 0.0
	stats_btn.anchor_top = 1.0
	stats_btn.anchor_bottom = 1.0
	stats_btn.offset_left = 30
	stats_btn.offset_top = -104
	stats_btn.offset_right = 110
	stats_btn.offset_bottom = -24
	stats_btn.pressed.connect(func():
		if range_ui != null:
			range_ui.call("toggle_stats_visibility")
	)
	canvas.add_child(stats_btn)

	# Slope Grid Toggle Button (Icon Only) - Bottom-Left, right of Stats button
	grid_btn = Button.new()
	grid_btn.name = "GreenGridToggleButton"
	grid_btn.text = ""
	grid_btn.tooltip_text = "Toggle Slope Grid (Show/Hide)"
	grid_btn.expand_icon = true
	if ResourceLoader.exists("res://assets/images/icons/slope_grid.svg"):
		grid_btn.icon = load("res://assets/images/icons/slope_grid.svg")
	grid_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_btn.custom_minimum_size = Vector2(80, 80)
	apply_circular_button_style(grid_btn, Color(0.15, 0.15, 0.15, 0.85)) # Gray (off) by default
	grid_btn.anchor_left = 0.0
	grid_btn.anchor_right = 0.0
	grid_btn.anchor_top = 1.0
	grid_btn.anchor_bottom = 1.0
	grid_btn.offset_left = 130   # 110 (stats right) + 20px gap
	grid_btn.offset_top = -104
	grid_btn.offset_right = 210 # 130 + 80 button width
	grid_btn.offset_bottom = -24
	grid_btn.pressed.connect(func():
		if course_instance != null and course_instance.get("show_green_grid") != null:
			var current_grid = course_instance.get("show_green_grid") as bool
			course_instance.set("show_green_grid", not current_grid)
	)
	canvas.add_child(grid_btn)

	if range_ui != null:
		var modal_open = range_ui.call("is_golfer_camera_modal_open") if range_ui.has_method("is_golfer_camera_modal_open") else false
		_on_golfer_cam_modal_state_changed(modal_open)
		var stats_vis = range_ui.call("is_stats_visible") if range_ui.has_method("is_stats_visible") else true
		_on_stats_visibility_changed(stats_vis)

	# Map Toggle Button (Icon Only) - Bottom-Right Corner
	map_btn = Button.new()
	map_btn.name = "MapButton"
	map_btn.text = ""
	map_btn.tooltip_text = "Toggle Map View"
	map_btn.expand_icon = true
	if ResourceLoader.exists("res://assets/images/icons/golf_course.svg"):
		map_btn.icon = load("res://assets/images/icons/golf_course.svg")
	map_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_btn.custom_minimum_size = Vector2(80, 80)
	apply_circular_button_style(map_btn, Color(0.18, 0.45, 0.25, 0.85)) # Forest green
	map_btn.anchor_left = 1.0
	map_btn.anchor_right = 1.0
	map_btn.anchor_top = 1.0
	map_btn.anchor_bottom = 1.0
	map_btn.offset_left = -110
	map_btn.offset_top = -104
	map_btn.offset_right = -30
	map_btn.offset_bottom = -24
	map_btn.pressed.connect(func():
		if course_instance and course_instance.has_method("_on_map_button_pressed"):
			course_instance.call("_on_map_button_pressed")
	)
	canvas.add_child(map_btn)

	# Mulligan Button (Icon Only) - Bottom-Right next to Map button
	mulligan_btn = Button.new()
	mulligan_btn.name = "MulliganButton"
	mulligan_btn.text = ""
	mulligan_btn.tooltip_text = "Mulligan (Undo Shot)"
	mulligan_btn.expand_icon = true
	if ResourceLoader.exists("res://assets/images/icons/mulligan.svg"):
		mulligan_btn.icon = load("res://assets/images/icons/mulligan.svg")
	mulligan_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mulligan_btn.custom_minimum_size = Vector2(80, 80)
	apply_circular_button_style(mulligan_btn, Color(0.24, 0.46, 0.72, 0.85))
	mulligan_btn.anchor_left = 1.0
	mulligan_btn.anchor_right = 1.0
	mulligan_btn.anchor_top = 1.0
	mulligan_btn.anchor_bottom = 1.0
	mulligan_btn.offset_left = -210  # -130 - 80 button width
	mulligan_btn.offset_top = -104
	mulligan_btn.offset_right = -130 # -110 (map left) - 20px gap
	mulligan_btn.offset_bottom = -24
	mulligan_btn.pressed.connect(_on_mulligan_pressed)
	mulligan_btn.visible = is_match_play and not _is_online_match()
	canvas.add_child(mulligan_btn)

	# Forfeit / White Flag Button (Icon Only) - Bottom-Right next to Mulligan button
	forfeit_btn = Button.new()
	forfeit_btn.name = "ForfeitButton"
	forfeit_btn.text = ""
	forfeit_btn.tooltip_text = "Leave Spectating" if _is_spectating() else ("Leave Online Match" if _is_online_match() else "White Flag (Concede Hole)")
	forfeit_btn.expand_icon = true
	if ResourceLoader.exists("res://assets/images/icons/white_flag.svg"):
		var icon_tex = load("res://assets/images/icons/white_flag.svg")
		if icon_tex != null:
			forfeit_btn.icon = icon_tex
	if forfeit_btn.icon == null:
		forfeit_btn.text = "🏳"
		forfeit_btn.add_theme_font_size_override("font_size", 34)
	forfeit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forfeit_btn.custom_minimum_size = Vector2(80, 80)
	apply_circular_button_style(forfeit_btn, Color(0.68, 0.22, 0.22, 0.88))
	forfeit_btn.anchor_left = 1.0
	forfeit_btn.anchor_right = 1.0
	forfeit_btn.anchor_top = 1.0
	forfeit_btn.anchor_bottom = 1.0
	forfeit_btn.offset_left = -310  # -230 - 80 button width
	forfeit_btn.offset_top = -104
	forfeit_btn.offset_right = -230 # -210 (mulligan left) - 20px gap
	forfeit_btn.offset_bottom = -24
	forfeit_btn.pressed.connect(_on_forfeit_pressed)
	forfeit_btn.visible = false
	canvas.add_child(forfeit_btn)
	
	# --- Minimap Viewport Construction ---
	# HBoxContainer grouping minimap and distance tracker side by side
	_minimap_group = HBoxContainer.new()
	_minimap_group.name = "MinimapGroup"
	_minimap_group.position = Vector2(30, _get_normal_minimap_top_y())
	_minimap_group.add_theme_constant_override("separation", 8)
	_minimap_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_minimap_group)
	
	var minimap_panel = PanelContainer.new()
	minimap_panel.name = "MinimapPanel"
	var sc_style = StyleBoxFlat.new()
	sc_style.bg_color = Color(0.08, 0.08, 0.08, 0.7)
	sc_style.border_width_left = 2
	sc_style.border_width_top = 2
	sc_style.border_width_right = 2
	sc_style.border_width_bottom = 2
	sc_style.border_color = Color(0.8, 0.8, 0.8, 0.8)
	sc_style.corner_radius_top_left = 12
	sc_style.corner_radius_top_right = 12
	sc_style.corner_radius_bottom_left = 12
	sc_style.corner_radius_bottom_right = 12
	minimap_panel.add_theme_stylebox_override("panel", sc_style)
	minimap_panel.custom_minimum_size = Vector2(288, 337)
	minimap_panel.size = Vector2(288, 337)
	_minimap_group.add_child(minimap_panel)
	
	# --- Distance Tracker Panel ---
	_distance_tracker_panel = PanelContainer.new()
	_distance_tracker_panel.name = "DistanceTrackerPanel"
	var dt_style = StyleBoxFlat.new()
	dt_style.bg_color = Color(0.08, 0.08, 0.08, 0.7)
	dt_style.border_width_left = 2
	dt_style.border_width_top = 2
	dt_style.border_width_right = 2
	dt_style.border_width_bottom = 2
	dt_style.border_color = Color(0.8, 0.8, 0.8, 0.8)
	dt_style.corner_radius_top_left = 12
	dt_style.corner_radius_top_right = 12
	dt_style.corner_radius_bottom_left = 12
	dt_style.corner_radius_bottom_right = 12
	dt_style.content_margin_left = 12
	dt_style.content_margin_right = 12
	dt_style.content_margin_top = 10
	dt_style.content_margin_bottom = 10
	_distance_tracker_panel.add_theme_stylebox_override("panel", dt_style)
	_distance_tracker_panel.custom_minimum_size = Vector2(84, 0)
	_distance_tracker_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_minimap_group.add_child(_distance_tracker_panel)
	
	var dt_vbox = VBoxContainer.new()
	dt_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	dt_vbox.add_theme_constant_override("separation", 6) # stack vertically
	_distance_tracker_panel.add_child(dt_vbox)
	
	var back_green_label = Label.new()
	back_green_label.name = "BackGreenLabel"
	back_green_label.text = "---"
	back_green_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_green_label.add_theme_font_size_override("font_size", 22)
	back_green_label.add_theme_color_override("font_color", Color.WHITE)
	back_green_label.add_theme_color_override("font_outline_color", Color.BLACK)
	back_green_label.add_theme_constant_override("outline_size", 4)
	_back_lbl = back_green_label
	dt_vbox.add_child(back_green_label)
	
	var mid_hbox = HBoxContainer.new()
	mid_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_hbox.add_theme_constant_override("separation", 4)
	dt_vbox.add_child(mid_hbox)
	
	var flag_label = Label.new()
	flag_label.text = "⚑"
	flag_label.add_theme_font_size_override("font_size", 24)
	flag_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.22)) # Golden amber flag
	flag_label.add_theme_color_override("font_outline_color", Color.BLACK)
	flag_label.add_theme_constant_override("outline_size", 4)
	mid_hbox.add_child(flag_label)
	
	var hole_label = Label.new()
	hole_label.name = "HoleLabel"
	hole_label.text = "---"
	hole_label.add_theme_font_size_override("font_size", 26)
	hole_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.22)) # Golden amber / Accent
	hole_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hole_label.add_theme_constant_override("outline_size", 4)
	_hole_lbl = hole_label
	mid_hbox.add_child(hole_label)
	
	var front_green_label = Label.new()
	front_green_label.name = "FrontGreenLabel"
	front_green_label.text = "---"
	front_green_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	front_green_label.add_theme_font_size_override("font_size", 22)
	front_green_label.add_theme_color_override("font_color", Color.WHITE)
	front_green_label.add_theme_color_override("font_outline_color", Color.BLACK)
	front_green_label.add_theme_constant_override("outline_size", 4)
	_front_lbl = front_green_label
	dt_vbox.add_child(front_green_label)

	var unit_label = Label.new()
	unit_label.name = "UnitLabel"
	unit_label.text = "YDS"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unit_label.add_theme_font_size_override("font_size", 13)
	unit_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	unit_label.add_theme_color_override("font_outline_color", Color.BLACK)
	unit_label.add_theme_constant_override("outline_size", 3)
	_distance_unit_lbl = unit_label
	dt_vbox.add_child(unit_label)
	
	var minimap_container = SubViewportContainer.new()
	minimap_container.custom_minimum_size = Vector2(284, 333)
	minimap_container.size = Vector2(284, 333)
	minimap_container.stretch = true
	minimap_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_minimap_container = minimap_container
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(284, 333)
	viewport.own_world_3d = false
	viewport.transparent_bg = false
	
	var minimap_camera = Camera3D.new()
	minimap_camera.name = "MinimapCamera"
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = minimap_zoom
	minimap_camera.position = Vector3(0, 150, 0)
	minimap_camera.rotation = Vector3(-PI/2, 0, 0) # Look straight down
	# Strictly isolate minimap camera to Layer 1 (terrain/course) + Layer 2 (green slope heatmap)
	minimap_camera.cull_mask = (1 << 0) | (1 << 1)
	
	viewport.add_child(minimap_camera)
	minimap_container.add_child(viewport)
	minimap_panel.add_child(minimap_container)
	
	# Make the camera current inside the SubViewport
	minimap_camera.make_current()
	
	_minimap_camera = minimap_camera
	_minimap_viewport = viewport
	_minimap_panel = minimap_panel
	
	# Add Zoom buttons and interactive overlay to Minimap Panel
	var zoom_overlay = Control.new()
	zoom_overlay.name = "ZoomOverlay"
	zoom_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	zoom_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	zoom_overlay.clip_contents = true
	minimap_panel.add_child(zoom_overlay)

	# Flag Marker on Minimap Overlay (shows at hole location on green heatmap)
	var flag_icon = TextureRect.new()
	flag_icon.name = "MinimapFlagMarker"
	flag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag_icon.custom_minimum_size = Vector2(32, 36)
	flag_icon.size = Vector2(32, 36)
	flag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag_icon.texture = _get_minimap_flag_texture()
	flag_icon.visible = false
	zoom_overlay.add_child(flag_icon)
	_minimap_flag_icon = flag_icon

	# Ball Marker on Minimap Overlay (shows at player's ball location on green heatmap)
	var ball_icon = TextureRect.new()
	ball_icon.name = "MinimapBallMarker"
	ball_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_icon.custom_minimum_size = Vector2(24, 24)
	ball_icon.size = Vector2(24, 24)
	ball_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball_icon.texture = _get_minimap_ball_texture()
	ball_icon.visible = false
	zoom_overlay.add_child(ball_icon)
	_minimap_ball_icon = ball_icon

	# Desktop Click-to-Aim hint label
	var hint_label = Label.new()
	hint_label.name = "MinimapAimHint"
	hint_label.text = "🎯 Click to Aim"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.95))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 3)
	hint_label.anchor_left = 0.0
	hint_label.anchor_right = 1.0
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = 0
	hint_label.offset_right = 0
	hint_label.offset_top = -28
	hint_label.offset_bottom = -6
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.modulate.a = 0.0
	zoom_overlay.add_child(hint_label)
	_minimap_hint_label = hint_label

	var zoom_vbox = VBoxContainer.new()
	zoom_vbox.name = "ZoomVBox"
	zoom_vbox.anchor_left = 1.0
	zoom_vbox.anchor_right = 1.0
	zoom_vbox.anchor_top = 0.0
	zoom_vbox.anchor_bottom = 0.0
	zoom_vbox.offset_left = -48
	zoom_vbox.offset_top = 8
	zoom_vbox.offset_right = -8
	zoom_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom_vbox.add_theme_constant_override("separation", 6)
	zoom_overlay.add_child(zoom_vbox)

	var zoom_in_btn = Button.new()
	zoom_in_btn.name = "ZoomInButton"
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(40, 40)
	apply_zoom_button_style(zoom_in_btn, Color(0.15, 0.15, 0.15, 0.85))
	zoom_in_btn.pressed.connect(func():
		minimap_zoom = clamp(minimap_zoom - 25.0, 50.0, 500.0)
		if _last_zoom_zone == 0:
			_teebox_minimap_zoom = minimap_zoom
			_default_non_green_minimap_zoom = minimap_zoom
		_update_minimap()
	)
	zoom_vbox.add_child(zoom_in_btn)

	var zoom_out_btn = Button.new()
	zoom_out_btn.name = "ZoomOutButton"
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(40, 40)
	apply_zoom_button_style(zoom_out_btn, Color(0.15, 0.15, 0.15, 0.85))
	zoom_out_btn.pressed.connect(func():
		minimap_zoom = clamp(minimap_zoom + 25.0, 50.0, 500.0)
		if _last_zoom_zone == 0:
			_teebox_minimap_zoom = minimap_zoom
			_default_non_green_minimap_zoom = minimap_zoom
		_update_minimap()
	)
	zoom_vbox.add_child(zoom_out_btn)

	# Connect hover and click-to-aim events on desktop
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_panel.mouse_entered.connect(_on_minimap_mouse_entered)
	minimap_panel.mouse_exited.connect(_on_minimap_mouse_exited)
	minimap_container.mouse_entered.connect(_on_minimap_mouse_entered)
	minimap_container.mouse_exited.connect(_on_minimap_mouse_exited)
	minimap_container.gui_input.connect(_on_minimap_gui_input)
	zoom_overlay.gui_input.connect(_on_minimap_gui_input)
	
	_update_minimap_position()
	
	# Scorecard Panel
	if hud_scorecard == null:
		hud_scorecard = Panel.new()
	if scorecard_grid == null:
		scorecard_grid = GridContainer.new()
	hud_scorecard.name = "ScorecardPanel"
	hud_scorecard.visible = false
	hud_scorecard.anchor_left = 0.02
	hud_scorecard.anchor_right = 0.98
	hud_scorecard.anchor_top = 0.03
	hud_scorecard.anchor_bottom = 0.97
	hud_scorecard.offset_left = 0
	hud_scorecard.offset_right = 0
	hud_scorecard.offset_top = 0
	hud_scorecard.offset_bottom = 0
	hud_scorecard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_scorecard.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.09, 0.14, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.72, 0.56, 0.24, 0.85) # Gold border
	card_style.corner_radius_top_left = 16
	card_style.corner_radius_top_right = 16
	card_style.corner_radius_bottom_left = 16
	card_style.corner_radius_bottom_right = 16
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	hud_scorecard.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 14)
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	hud_scorecard.add_child(vbox)
	
	var sc_title = Label.new()
	sc_title.name = "TitleLabel"
	sc_title.text = "Scorecard"
	sc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc_title.add_theme_font_size_override("font_size", 30)
	sc_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	sc_title.add_theme_color_override("font_outline_color", Color.BLACK)
	sc_title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(sc_title)
	
	# Scorecard Settings Cog Button (Top Right)
	_scorecard_settings_btn = Button.new()
	_scorecard_settings_btn.name = "ScorecardSettingsBtn"
	_scorecard_settings_btn.text = "⚙️"
	_scorecard_settings_btn.tooltip_text = "Toggle Player Settings"
	_scorecard_settings_btn.custom_minimum_size = Vector2(48, 48)
	_scorecard_settings_btn.anchor_left = 1.0
	_scorecard_settings_btn.anchor_right = 1.0
	_scorecard_settings_btn.anchor_top = 0.0
	_scorecard_settings_btn.anchor_bottom = 0.0
	_scorecard_settings_btn.offset_left = -68
	_scorecard_settings_btn.offset_top = 16
	_scorecard_settings_btn.offset_right = -20
	_scorecard_settings_btn.offset_bottom = 64
	_scorecard_settings_btn.focus_mode = Control.FOCUS_ALL
	_scorecard_settings_btn.add_theme_font_size_override("font_size", 20)
	_update_scorecard_settings_button_style()
	_scorecard_settings_btn.pressed.connect(_on_scorecard_settings_toggled)
	hud_scorecard.add_child(_scorecard_settings_btn)
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScorecardScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	ThemeManager.apply_scroll_container_style(scroll, 28)
	vbox.add_child(scroll)
	
	scorecard_grid.name = "ScorecardGrid"
	scorecard_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorecard_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scorecard_grid.add_theme_constant_override("h_separation", 2)
	scorecard_grid.add_theme_constant_override("v_separation", 2)
	_scorecard_content = VBoxContainer.new()
	_scorecard_content.name = "ScorecardContent"
	_scorecard_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scorecard_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_scorecard_content)
	if scorecard_grid.get_parent() == null:
		_scorecard_content.add_child(scorecard_grid)

	# Add Player section within scorecard
	_scorecard_add_player_section = PanelContainer.new()
	_scorecard_add_player_section.name = "ScorecardAddPlayerSection"
	_scorecard_add_player_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scorecard_add_player_section.visible = false
	
	var sc_add_style = StyleBoxFlat.new()
	sc_add_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	sc_add_style.border_width_left = 1
	sc_add_style.border_width_top = 1
	sc_add_style.border_width_right = 1
	sc_add_style.border_width_bottom = 1
	sc_add_style.border_color = Color(0.25, 0.55, 0.35, 0.7) # Green-ish accent
	sc_add_style.corner_radius_top_left = 8
	sc_add_style.corner_radius_top_right = 8
	sc_add_style.corner_radius_bottom_left = 8
	sc_add_style.corner_radius_bottom_right = 8
	sc_add_style.content_margin_left = 14
	sc_add_style.content_margin_right = 14
	sc_add_style.content_margin_top = 8
	sc_add_style.content_margin_bottom = 8
	_scorecard_add_player_section.add_theme_stylebox_override("panel", sc_add_style)
	
	var sc_add_row = HBoxContainer.new()
	sc_add_row.name = "AddRow"
	sc_add_row.add_theme_constant_override("separation", 10)
	sc_add_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scorecard_add_player_section.add_child(sc_add_row)
	
	var sc_add_title = Label.new()
	sc_add_title.name = "TitleLabel"
	sc_add_title.text = "➕ Add Player:"
	sc_add_title.add_theme_font_size_override("font_size", 14)
	sc_add_title.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	sc_add_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sc_add_row.add_child(sc_add_title)
	
	var sc_player_select_opt = OptionButton.new()
	sc_player_select_opt.name = "PlayerSelectOpt"
	sc_player_select_opt.custom_minimum_size = Vector2(170, 36)
	sc_player_select_opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sc_player_select_opt.focus_mode = Control.FOCUS_ALL
	var sc_sel_popup = sc_player_select_opt.get_popup()
	if sc_sel_popup != null:
		ThemeManager.style_popup_menu(sc_sel_popup, 14)
	sc_add_row.add_child(sc_player_select_opt)
	
	var sc_name_input = LineEdit.new()
	sc_name_input.name = "NameInput"
	sc_name_input.placeholder_text = "Golfer Name"
	sc_name_input.custom_minimum_size = Vector2(160, 36)
	sc_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_name_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sc_name_input.focus_mode = Control.FOCUS_ALL
	sc_add_row.add_child(sc_name_input)
	
	var sc_tee_opt = OptionButton.new()
	sc_tee_opt.name = "TeeOpt"
	sc_tee_opt.custom_minimum_size = Vector2(115, 36)
	sc_tee_opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sc_tee_opt.focus_mode = Control.FOCUS_ALL
	var sc_tee_popup = sc_tee_opt.get_popup()
	if sc_tee_popup != null:
		ThemeManager.style_popup_menu(sc_tee_popup, 14)
	sc_add_row.add_child(sc_tee_opt)
	
	var sc_add_btn = Button.new()
	sc_add_btn.name = "AddBtn"
	sc_add_btn.text = "Add Player"
	sc_add_btn.custom_minimum_size = Vector2(120, 36)
	sc_add_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sc_add_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(sc_add_btn, Color(0.24, 0.46, 0.72, 0.85))
	sc_add_row.add_child(sc_add_btn)
	
	sc_player_select_opt.item_selected.connect(func(index):
		if index == 0:
			sc_name_input.visible = true
			sc_name_input.call_deferred("grab_focus")
		else:
			sc_name_input.visible = false
			var p_name = sc_player_select_opt.get_item_text(index)
			var pref_tee = MultiplayerManager.get_player_preferred_tee(p_name)
			if not pref_tee.is_empty():
				for t_i in range(sc_tee_opt.item_count):
					if sc_tee_opt.get_item_text(t_i).to_lower() == pref_tee.to_lower():
						sc_tee_opt.selected = t_i
						break
		_update_scorecard_focus_neighbors()
	)
	
	sc_add_btn.pressed.connect(func():
		if _scorecard_countdown_active and not _scorecard_countdown_paused:
			_on_scorecard_pause_toggled()
		var p_name = ""
		if sc_player_select_opt.selected == 0:
			p_name = sc_name_input.text.strip_edges()
			if p_name.is_empty():
				p_name = "Player " + str(MultiplayerManager.players.size() + 1)
		else:
			p_name = sc_player_select_opt.get_item_text(sc_player_select_opt.selected)
			
		var tee_color = sc_tee_opt.get_item_text(sc_tee_opt.selected) if sc_tee_opt.selected >= 0 and sc_tee_opt.item_count > 0 else "Blue"
		sc_name_input.clear()
		
		if MultiplayerManager.current_hole_index > 0:
			_show_add_player_dialog(p_name, tee_color)
		else:
			MultiplayerManager.add_new_player_with_mode(p_name, tee_color, "current_hole")
			_refresh_scorecard_add_player_section()
			_populate_scorecard(_last_scorecard_action_type, "PlayerSelectOpt")
			_update_distance_queue()
	)
	
	_scorecard_content.add_child(_scorecard_add_player_section)
	
	_hole_shot_summary = VBoxContainer.new()
	_hole_shot_summary.name = "HoleShotSummary"
	_hole_shot_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hole_shot_summary.add_theme_constant_override("separation", 8)
	_hole_shot_summary.visible = false
	_scorecard_content.add_child(_hole_shot_summary)
	
	var actions_row = HBoxContainer.new()
	actions_row.name = "ScorecardActionsRow"
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 18)
	actions_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(actions_row)

	var action_btn = Button.new()
	action_btn.name = "ScorecardActionBtn"
	action_btn.text = "Next Hole"
	action_btn.custom_minimum_size = Vector2(180, 56)
	action_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apply_material_button_style(action_btn, Color(0.24, 0.46, 0.72, 0.85))
	actions_row.add_child(action_btn)
	_scorecard_action_btn = action_btn

	_scorecard_countdown_container = HBoxContainer.new()
	_scorecard_countdown_container.name = "ScorecardCountdownContainer"
	_scorecard_countdown_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_scorecard_countdown_container.add_theme_constant_override("separation", 12)
	_scorecard_countdown_container.visible = false
	actions_row.add_child(_scorecard_countdown_container)

	_scorecard_countdown_lbl = Label.new()
	_scorecard_countdown_lbl.name = "ScorecardCountdownLabel"
	_scorecard_countdown_lbl.text = "Next hole in 5s..."
	_scorecard_countdown_lbl.custom_minimum_size = Vector2(180, 0)
	_scorecard_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scorecard_countdown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scorecard_countdown_lbl.add_theme_font_size_override("font_size", 20)
	_scorecard_countdown_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 1.0))
	_scorecard_countdown_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_scorecard_countdown_lbl.add_theme_constant_override("outline_size", 3)
	_scorecard_countdown_container.add_child(_scorecard_countdown_lbl)

	_scorecard_pause_btn = Button.new()
	_scorecard_pause_btn.name = "ScorecardPauseBtn"
	_scorecard_pause_btn.text = "⏸ Pause"
	_scorecard_pause_btn.custom_minimum_size = Vector2(130, 56)
	apply_material_button_style(_scorecard_pause_btn, Color(0.35, 0.38, 0.45, 0.85))
	_scorecard_pause_btn.pressed.connect(_on_scorecard_pause_toggled)
	_scorecard_countdown_container.add_child(_scorecard_pause_btn)
	
	if hud_scorecard.get_parent() == null:
		margin.add_child(hud_scorecard)


	# Manage Players Panel
	if hud_manage_players == null:
		hud_manage_players = Panel.new()
	hud_manage_players.name = "ManagePlayersPanel"
	hud_manage_players.visible = false
	hud_manage_players.z_index = 500
	hud_manage_players.anchor_left = 0.5
	hud_manage_players.anchor_right = 0.5
	hud_manage_players.anchor_top = 0.5
	hud_manage_players.anchor_bottom = 0.5
	hud_manage_players.offset_left = -370
	hud_manage_players.offset_right = 370
	hud_manage_players.offset_top = -260
	hud_manage_players.offset_bottom = 260
	
	var manage_style = StyleBoxFlat.new()
	manage_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	manage_style.border_width_left = 2
	manage_style.border_width_top = 2
	manage_style.border_width_right = 2
	manage_style.border_width_bottom = 2
	manage_style.border_color = Color(0.25, 0.55, 0.35, 0.8) # Green border
	manage_style.corner_radius_top_left = 16
	manage_style.corner_radius_top_right = 16
	manage_style.corner_radius_bottom_left = 16
	manage_style.corner_radius_bottom_right = 16
	manage_style.content_margin_left = 24
	manage_style.content_margin_right = 24
	manage_style.content_margin_top = 20
	manage_style.content_margin_bottom = 20
	hud_manage_players.add_theme_stylebox_override("panel", manage_style)
	
	var m_vbox = VBoxContainer.new()
	m_vbox.name = "VBoxContainer"
	m_vbox.add_theme_constant_override("separation", 15)
	m_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_manage_players.add_child(m_vbox)
	
	var m_title = Label.new()
	m_title.text = "Manage Players"
	m_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_title.add_theme_font_size_override("font_size", 24)
	m_vbox.add_child(m_title)
	
	# ScrollContainer for player list
	var m_scroll = ScrollContainer.new()
	m_scroll.name = "ScrollContainer"
	m_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ThemeManager.apply_scroll_container_style(m_scroll, 28)
	m_vbox.add_child(m_scroll)
	
	var m_list = VBoxContainer.new()
	m_list.name = "PlayerList"
	m_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_scroll.add_child(m_list)
	
	# Add New Player Section
	var add_section = VBoxContainer.new()
	add_section.name = "AddSection"
	add_section.add_theme_constant_override("separation", 8)
	m_vbox.add_child(add_section)
	
	var add_title = Label.new()
	add_title.text = "Add New Player"
	add_title.add_theme_font_size_override("font_size", 14)
	add_section.add_child(add_title)
	
	var add_row = HBoxContainer.new()
	add_row.name = "AddRow"
	add_row.add_theme_constant_override("separation", 10)
	add_section.add_child(add_row)
	
	var m_player_select_opt = OptionButton.new()
	m_player_select_opt.name = "PlayerSelectOpt"
	m_player_select_opt.custom_minimum_size = Vector2(160, 0)
	add_row.add_child(m_player_select_opt)
	
	var m_name_input = LineEdit.new()
	m_name_input.name = "NameInput"
	m_name_input.placeholder_text = "Player Name"
	m_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(m_name_input)
	
	var m_tee_opt = OptionButton.new()
	m_tee_opt.name = "TeeOpt"
	var course_tees: Array = []
	for h in MultiplayerManager.hole_info.values():
		if h is Dictionary and h.has("Tee Boxes"):
			for k in h["Tee Boxes"].keys():
				if not course_tees.has(str(k)):
					course_tees.append(str(k))
	if course_tees.is_empty():
		course_tees = ["Blue", "Red", "White", "Black", "Gold"]
	for t_idx in range(course_tees.size()):
		m_tee_opt.add_item(course_tees[t_idx], t_idx)
	add_row.add_child(m_tee_opt)

	m_player_select_opt.item_selected.connect(func(index):
		if index == 0:
			m_name_input.visible = true
			m_name_input.call_deferred("grab_focus")
		else:
			m_name_input.visible = false
			var p_name = m_player_select_opt.get_item_text(index)
			var pref_tee = MultiplayerManager.get_player_preferred_tee(p_name)
			if not pref_tee.is_empty():
				for t_i in range(m_tee_opt.item_count):
					if m_tee_opt.get_item_text(t_i).to_lower() == pref_tee.to_lower():
						m_tee_opt.selected = t_i
						break
		_update_manage_players_focus_neighbors()
	)
	
	var m_add_btn = Button.new()
	m_add_btn.name = "AddBtn"
	m_add_btn.text = "Add Player"
	m_add_btn.custom_minimum_size = Vector2(130, 48)
	apply_material_button_style(m_add_btn, Color(0.24, 0.46, 0.72, 0.85))
	add_row.add_child(m_add_btn)
	
	m_add_btn.pressed.connect(func():
		var name_input = hud_manage_players.get_node("VBoxContainer/AddSection/AddRow/NameInput") as LineEdit
		var tee_opt = hud_manage_players.get_node("VBoxContainer/AddSection/AddRow/TeeOpt") as OptionButton
		var select_opt = hud_manage_players.get_node("VBoxContainer/AddSection/AddRow/PlayerSelectOpt") as OptionButton
		
		var p_name = ""
		if select_opt.selected == 0:
			p_name = name_input.text.strip_edges()
			if p_name.is_empty():
				p_name = "Player " + str(MultiplayerManager.players.size() + 1)
		else:
			p_name = select_opt.get_item_text(select_opt.selected)
			
		var tee_color = tee_opt.get_item_text(tee_opt.selected)
		name_input.clear()
		
		if MultiplayerManager.current_hole_index > 0:
			_show_add_player_dialog(p_name, tee_color)
		else:
			MultiplayerManager.add_new_player_with_mode(p_name, tee_color, "current_hole")
			_refresh_manage_players_dropdown()
			_populate_manage_players()
			_populate_scorecard("toggle")
			_update_distance_queue()
			select_opt.call_deferred("grab_focus")
	)
	
	# Close button
	var m_close_btn = Button.new()
	m_close_btn.name = "CloseBtn"
	m_close_btn.text = "Close"
	m_close_btn.custom_minimum_size = Vector2(160, 48)
	m_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apply_material_button_style(m_close_btn, Color(0.56, 0.22, 0.22, 0.85))
	m_vbox.add_child(m_close_btn)
	
	m_close_btn.pressed.connect(func():
		_close_manage_players_panel()
	)
	
	if hud_manage_players.get_parent() == null:
		margin.add_child(hud_manage_players)

	# Overview Panel (Game Over)
	if hud_overview == null:
		hud_overview = Panel.new()
	hud_overview.name = "HUDOverview"
	hud_overview.visible = false
	hud_overview.anchor_left = 0.03
	hud_overview.anchor_right = 0.97
	hud_overview.anchor_top = 0.04
	hud_overview.anchor_bottom = 0.96
	hud_overview.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_overview.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud_overview.offset_left = 0
	hud_overview.offset_right = 0
	hud_overview.offset_top = 0
	hud_overview.offset_bottom = 0
	
	var overview_style = StyleBoxFlat.new()
	overview_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	overview_style.border_width_left = 3
	overview_style.border_width_top = 3
	overview_style.border_width_right = 3
	overview_style.border_width_bottom = 3
	overview_style.border_color = Color(0.24, 0.46, 0.72, 0.85) # Sleek blue border
	overview_style.corner_radius_top_left = 16
	overview_style.corner_radius_top_right = 16
	overview_style.corner_radius_bottom_left = 16
	overview_style.corner_radius_bottom_right = 16
	overview_style.content_margin_left = 30
	overview_style.content_margin_right = 30
	overview_style.content_margin_top = 24
	overview_style.content_margin_bottom = 24
	hud_overview.add_theme_stylebox_override("panel", overview_style)
	if hud_overview.get_parent() == null:
		margin.add_child(hud_overview)
	_update_hud_tooltips()
	call_deferred("_update_hud_focus_neighbors")


func _update_hud_focus_neighbors() -> void:
	var add_remove_btn: Control = null
	var prev_shot_btn: Control = null
	if range_ui != null and is_instance_valid(range_ui):
		add_remove_btn = range_ui.get_node_or_null("GridCanvas/AddRemoveButton")
		prev_shot_btn = range_ui.get_node_or_null("BottomBarContainer/PrevShotAnalysisButton")
		if prev_shot_btn == null and "_prev_shot_btn" in range_ui:
			prev_shot_btn = range_ui.get("_prev_shot_btn")

	# Locate weather & lighting controls if instantiated
	var weather_slider: Control = null
	var weather_btn: Control = null
	if course_instance != null and is_instance_valid(course_instance) and course_instance.has_method("get_weather_lighting_controller"):
		var w_ctrl = course_instance.get_weather_lighting_controller()
		if w_ctrl != null and is_instance_valid(w_ctrl):
			if "time_slider" in w_ctrl and w_ctrl.time_slider != null and is_instance_valid(w_ctrl.time_slider) and w_ctrl.time_slider.is_visible_in_tree():
				weather_slider = w_ctrl.time_slider
			if "weather_toggle_btn" in w_ctrl and w_ctrl.weather_toggle_btn != null and is_instance_valid(w_ctrl.weather_toggle_btn) and w_ctrl.weather_toggle_btn.is_visible_in_tree():
				weather_btn = w_ctrl.weather_toggle_btn
	if weather_slider == null and get_tree() != null and get_tree().root != null:
		var found_s = get_tree().root.find_child("TimeOfDaySlider", true, false)
		if found_s != null and is_instance_valid(found_s) and found_s.is_visible_in_tree():
			weather_slider = found_s as Control
	if weather_btn == null and get_tree() != null and get_tree().root != null:
		var found_b = get_tree().root.find_child("WeatherToggleButton", true, false)
		if found_b != null and is_instance_valid(found_b) and found_b.is_visible_in_tree():
			weather_btn = found_b as Control

	var active_hide_helpers: Control = hide_helpers_btn
	if (active_hide_helpers == null or not is_instance_valid(active_hide_helpers)) and range_ui != null and is_instance_valid(range_ui):
		active_hide_helpers = range_ui.get_node_or_null("OverlayLayer/HideHelpersButton")
		if active_hide_helpers == null:
			active_hide_helpers = range_ui.find_child("HideHelpersButton", true, false)

	var active_home: Control = home_btn
	if (active_home == null or not is_instance_valid(active_home)) and range_ui != null and is_instance_valid(range_ui):
		active_home = range_ui.get_node_or_null("OverlayLayer/HomeButton")
		if active_home == null:
			active_home = range_ui.find_child("HomeButton", true, false)

	var active_settings: Control = settings_btn
	if (active_settings == null or not is_instance_valid(active_settings)) and range_ui != null and is_instance_valid(range_ui):
		active_settings = range_ui.get_node_or_null("OverlayLayer/SettingsButton")
		if active_settings == null:
			active_settings = range_ui.find_child("SettingsButton", true, false)

	var club_btn: Control = null
	if club_selector_node != null and is_instance_valid(club_selector_node) and "club_button" in club_selector_node:
		club_btn = club_selector_node.club_button
	elif range_ui != null and is_instance_valid(range_ui):
		var club_sel = range_ui.get_node_or_null("OverlayLayer/ClubSelector")
		if club_sel == null:
			club_sel = range_ui.find_child("ClubSelector", true, false)
		if club_sel != null and "club_button" in club_sel:
			club_btn = club_sel.club_button

	# Stats button (Bottom-Left)
	if stats_btn != null and is_instance_valid(stats_btn):
		if add_remove_btn != null and is_instance_valid(add_remove_btn):
			stats_btn.focus_neighbor_top = stats_btn.get_path_to(add_remove_btn)
		if grid_btn != null and is_instance_valid(grid_btn):
			stats_btn.focus_neighbor_right = stats_btn.get_path_to(grid_btn)
		if map_btn != null and is_instance_valid(map_btn):
			stats_btn.focus_neighbor_left = stats_btn.get_path_to(map_btn)

	# Slope Grid button (Bottom-Left next to stats)
	if grid_btn != null and is_instance_valid(grid_btn):
		if stats_btn != null and is_instance_valid(stats_btn):
			grid_btn.focus_neighbor_left = grid_btn.get_path_to(stats_btn)
		if prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			grid_btn.focus_neighbor_right = grid_btn.get_path_to(prev_shot_btn)
		elif map_btn != null and is_instance_valid(map_btn):
			grid_btn.focus_neighbor_right = grid_btn.get_path_to(map_btn)
		if add_remove_btn != null and is_instance_valid(add_remove_btn):
			grid_btn.focus_neighbor_top = grid_btn.get_path_to(add_remove_btn)

	# Previous Shot button (Bottom-Center in RangeUI)
	if prev_shot_btn != null and is_instance_valid(prev_shot_btn):
		if grid_btn != null and is_instance_valid(grid_btn):
			prev_shot_btn.focus_neighbor_left = prev_shot_btn.get_path_to(grid_btn)
		elif stats_btn != null and is_instance_valid(stats_btn):
			prev_shot_btn.focus_neighbor_left = prev_shot_btn.get_path_to(stats_btn)
		
		var right_target: Control = null
		if forfeit_btn != null and is_instance_valid(forfeit_btn) and forfeit_btn.visible:
			right_target = forfeit_btn
		elif mulligan_btn != null and is_instance_valid(mulligan_btn) and mulligan_btn.visible:
			right_target = mulligan_btn
		elif map_btn != null and is_instance_valid(map_btn):
			right_target = map_btn
		if right_target != null:
			prev_shot_btn.focus_neighbor_right = prev_shot_btn.get_path_to(right_target)
		
		if weather_slider != null:
			prev_shot_btn.focus_neighbor_top = prev_shot_btn.get_path_to(weather_slider)
		elif weather_btn != null:
			prev_shot_btn.focus_neighbor_top = prev_shot_btn.get_path_to(weather_btn)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn):
			prev_shot_btn.focus_neighbor_top = prev_shot_btn.get_path_to(add_remove_btn)
		elif active_hide_helpers != null and is_instance_valid(active_hide_helpers):
			prev_shot_btn.focus_neighbor_top = prev_shot_btn.get_path_to(active_hide_helpers)

	# Add/Remove button (Left middle in RangeUI)
	if add_remove_btn != null and is_instance_valid(add_remove_btn):
		if stats_btn != null and is_instance_valid(stats_btn):
			add_remove_btn.focus_neighbor_bottom = add_remove_btn.get_path_to(stats_btn)
		elif grid_btn != null and is_instance_valid(grid_btn):
			add_remove_btn.focus_neighbor_bottom = add_remove_btn.get_path_to(grid_btn)
		if weather_slider != null:
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(weather_slider)
			add_remove_btn.focus_neighbor_top = add_remove_btn.get_path_to(weather_slider)
		elif weather_btn != null:
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(weather_btn)
			add_remove_btn.focus_neighbor_top = add_remove_btn.get_path_to(weather_btn)
		elif prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(prev_shot_btn)
		elif map_btn != null and is_instance_valid(map_btn):
			add_remove_btn.focus_neighbor_right = add_remove_btn.get_path_to(map_btn)
		if weather_slider == null and weather_btn == null:
			if active_hide_helpers != null and is_instance_valid(active_hide_helpers):
				add_remove_btn.focus_neighbor_top = add_remove_btn.get_path_to(active_hide_helpers)

	# Weather & Lighting Controls (Top-Center)
	if weather_slider != null:
		if add_remove_btn != null and is_instance_valid(add_remove_btn):
			weather_slider.focus_neighbor_left = weather_slider.get_path_to(add_remove_btn)
			weather_slider.focus_neighbor_top = weather_slider.get_path_to(add_remove_btn)
		elif stats_btn != null and is_instance_valid(stats_btn):
			weather_slider.focus_neighbor_left = weather_slider.get_path_to(stats_btn)

		if weather_btn != null:
			weather_slider.focus_neighbor_right = weather_slider.get_path_to(weather_btn)
		elif active_hide_helpers != null and is_instance_valid(active_hide_helpers):
			weather_slider.focus_neighbor_right = weather_slider.get_path_to(active_hide_helpers)

		if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			weather_slider.focus_neighbor_bottom = weather_slider.get_path_to(club_btn)
		elif prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			weather_slider.focus_neighbor_bottom = weather_slider.get_path_to(prev_shot_btn)
		elif map_btn != null and is_instance_valid(map_btn):
			weather_slider.focus_neighbor_bottom = weather_slider.get_path_to(map_btn)

	if weather_btn != null:
		if weather_slider != null:
			weather_btn.focus_neighbor_left = weather_btn.get_path_to(weather_slider)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn):
			weather_btn.focus_neighbor_left = weather_btn.get_path_to(add_remove_btn)

		if active_hide_helpers != null and is_instance_valid(active_hide_helpers):
			weather_btn.focus_neighbor_right = weather_btn.get_path_to(active_hide_helpers)
		elif active_home != null and is_instance_valid(active_home):
			weather_btn.focus_neighbor_right = weather_btn.get_path_to(active_home)

		if club_btn != null and is_instance_valid(club_btn) and club_btn.visible:
			weather_btn.focus_neighbor_bottom = weather_btn.get_path_to(club_btn)
		elif prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			weather_btn.focus_neighbor_bottom = weather_btn.get_path_to(prev_shot_btn)
		elif map_btn != null and is_instance_valid(map_btn):
			weather_btn.focus_neighbor_bottom = weather_btn.get_path_to(map_btn)

	# Forfeit button (Bottom-Right)
	if forfeit_btn != null and is_instance_valid(forfeit_btn) and forfeit_btn.visible:
		if prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			forfeit_btn.focus_neighbor_left = forfeit_btn.get_path_to(prev_shot_btn)
		elif grid_btn != null and is_instance_valid(grid_btn):
			forfeit_btn.focus_neighbor_left = forfeit_btn.get_path_to(grid_btn)
		var f_right: Control = mulligan_btn if (mulligan_btn != null and is_instance_valid(mulligan_btn) and mulligan_btn.visible) else map_btn
		if f_right != null and is_instance_valid(f_right):
			forfeit_btn.focus_neighbor_right = forfeit_btn.get_path_to(f_right)
		if active_hide_helpers != null and is_instance_valid(active_hide_helpers):
			forfeit_btn.focus_neighbor_top = forfeit_btn.get_path_to(active_hide_helpers)

	# Mulligan button (Bottom-Right)
	if mulligan_btn != null and is_instance_valid(mulligan_btn) and mulligan_btn.visible:
		var m_left: Control = forfeit_btn if (forfeit_btn != null and is_instance_valid(forfeit_btn) and forfeit_btn.visible) else prev_shot_btn
		if m_left != null and is_instance_valid(m_left):
			mulligan_btn.focus_neighbor_left = mulligan_btn.get_path_to(m_left)
		if map_btn != null and is_instance_valid(map_btn):
			mulligan_btn.focus_neighbor_right = mulligan_btn.get_path_to(map_btn)
		if active_hide_helpers != null and is_instance_valid(active_hide_helpers):
			mulligan_btn.focus_neighbor_top = mulligan_btn.get_path_to(active_hide_helpers)

	# Map button (Bottom-Right)
	if map_btn != null and is_instance_valid(map_btn):
		var map_left: Control = null
		if mulligan_btn != null and is_instance_valid(mulligan_btn) and mulligan_btn.visible:
			map_left = mulligan_btn
		elif forfeit_btn != null and is_instance_valid(forfeit_btn) and forfeit_btn.visible:
			map_left = forfeit_btn
		elif prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			map_left = prev_shot_btn
		if map_left != null:
			map_btn.focus_neighbor_left = map_btn.get_path_to(map_left)
		if stats_btn != null and is_instance_valid(stats_btn):
			map_btn.focus_neighbor_right = map_btn.get_path_to(stats_btn) # wrap-around
		if active_settings != null and is_instance_valid(active_settings):
			map_btn.focus_neighbor_top = map_btn.get_path_to(active_settings)

	# Settings button (Top-Right)
	if active_settings != null and is_instance_valid(active_settings):
		if active_home != null and is_instance_valid(active_home):
			active_settings.focus_neighbor_left = active_settings.get_path_to(active_home)
		if map_btn != null and is_instance_valid(map_btn):
			active_settings.focus_neighbor_bottom = active_settings.get_path_to(map_btn)

	# Home button (Top-Right)
	if active_home != null and is_instance_valid(active_home):
		if active_hide_helpers != null and is_instance_valid(active_hide_helpers):
			active_home.focus_neighbor_left = active_home.get_path_to(active_hide_helpers)
		if active_settings != null and is_instance_valid(active_settings):
			active_home.focus_neighbor_right = active_home.get_path_to(active_settings)
		if prev_shot_btn != null and is_instance_valid(prev_shot_btn):
			active_home.focus_neighbor_bottom = active_home.get_path_to(prev_shot_btn)
		elif map_btn != null and is_instance_valid(map_btn):
			active_home.focus_neighbor_bottom = active_home.get_path_to(map_btn)

	# Hide Helpers button (Top-Right)
	if active_hide_helpers != null and is_instance_valid(active_hide_helpers):
		if weather_btn != null:
			active_hide_helpers.focus_neighbor_left = active_hide_helpers.get_path_to(weather_btn)
		elif weather_slider != null:
			active_hide_helpers.focus_neighbor_left = active_hide_helpers.get_path_to(weather_slider)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn):
			active_hide_helpers.focus_neighbor_left = active_hide_helpers.get_path_to(add_remove_btn)
		if active_home != null and is_instance_valid(active_home):
			active_hide_helpers.focus_neighbor_right = active_hide_helpers.get_path_to(active_home)
		
		var helpers_open = (toggles_scroll != null and is_instance_valid(toggles_scroll) and toggles_scroll.visible)
		var first_helper: Control = imm_menu_btn if (imm_menu_btn != null and is_instance_valid(imm_menu_btn) and imm_menu_btn.visible) else announcer_btn
		if helpers_open and first_helper != null and is_instance_valid(first_helper):
			active_hide_helpers.focus_neighbor_bottom = active_hide_helpers.get_path_to(first_helper)
		elif add_remove_btn != null and is_instance_valid(add_remove_btn):
			active_hide_helpers.focus_neighbor_bottom = active_hide_helpers.get_path_to(add_remove_btn)

	# Wire helper vertical list if open
	if toggles_scroll != null and is_instance_valid(toggles_scroll) and toggles_scroll.visible:
		var helper_controls: Array[Control] = []
		var container = toggles_scroll.get_node_or_null("TogglesContainer")
		if container != null:
			for ch in container.get_children():
				if ch is Button and ch.visible:
					helper_controls.append(ch)
				elif ch is ScreenOffsetControl and ch.visible:
					for foc in ch.get_focusables():
						helper_controls.append(foc)
				elif ch is VBoxContainer and ch.visible:
					for sub_ch in ch.get_children():
						if sub_ch is Button and sub_ch.visible:
							helper_controls.append(sub_ch)
						elif sub_ch is ScreenOffsetControl and sub_ch.visible:
							for foc in sub_ch.get_focusables():
								helper_controls.append(foc)
		for i in range(helper_controls.size()):
			var h_ctrl = helper_controls[i]
			if i == 0 and hide_helpers_btn != null and is_instance_valid(hide_helpers_btn):
				h_ctrl.focus_neighbor_top = h_ctrl.get_path_to(hide_helpers_btn)
			elif i > 0:
				h_ctrl.focus_neighbor_top = h_ctrl.get_path_to(helper_controls[i - 1])
			if i < helper_controls.size() - 1:
				h_ctrl.focus_neighbor_bottom = h_ctrl.get_path_to(helper_controls[i + 1])
			else:
				if map_btn != null and is_instance_valid(map_btn):
					h_ctrl.focus_neighbor_bottom = h_ctrl.get_path_to(map_btn)
				elif prev_shot_btn != null and is_instance_valid(prev_shot_btn):
					h_ctrl.focus_neighbor_bottom = h_ctrl.get_path_to(prev_shot_btn)


func is_any_dialog_open() -> bool:
	# Check UIFocusGuard: dropdown or manual lock active
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		if guard.is_dropdown_open() or guard.is_locked():
			return true
	# Check if any UI control currently has focus that is actively editing or inside a dialog
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and is_instance_valid(focused) and focused.is_visible_in_tree():
			if focused is LineEdit or focused is TextEdit:
				return true
			if focused is Range or (focused is Control and (focused.get_parent() is SpinBox or focused is SpinBox)):
				return true
			var w_ctrl = course_instance.get_weather_lighting_controller() if (course_instance != null and is_instance_valid(course_instance) and course_instance.has_method("get_weather_lighting_controller")) else null
			if w_ctrl != null and is_instance_valid(w_ctrl):
				if focused == w_ctrl.weather_toggle_btn or focused == w_ctrl.time_slider:
					return true
			if _is_control_in_dialog(focused):
				return true
	if range_ui != null:
		var dist_m = range_ui.find_child("DistanceMenu", true, false)
		if dist_m != null and is_instance_valid(dist_m) and dist_m.visible:
			return true
		if range_ui.has_method("get_active_swing_replay_modal"):
			var modal = range_ui.call("get_active_swing_replay_modal")
			if modal != null and is_instance_valid(modal) and modal.visible:
				return true
		var replay_modal = range_ui.get_node_or_null("OverlayLayer/SwingReplayModal")
		if replay_modal != null and is_instance_valid(replay_modal) and replay_modal.visible:
			return true
	if mulligan_confirm_dialog != null and is_instance_valid(mulligan_confirm_dialog) and mulligan_confirm_dialog.visible:
		return true
	if forfeit_confirm_dialog != null and is_instance_valid(forfeit_confirm_dialog) and forfeit_confirm_dialog.visible:
		return true
	if exit_confirm_dialog != null and is_instance_valid(exit_confirm_dialog) and exit_confirm_dialog.visible:
		return true
	if add_player_prompt_dialog != null and is_instance_valid(add_player_prompt_dialog) and add_player_prompt_dialog.visible:
		return true
	if resume_player_prompt_dialog != null and is_instance_valid(resume_player_prompt_dialog) and resume_player_prompt_dialog.visible:
		return true
	if hud_scorecard != null and is_instance_valid(hud_scorecard) and hud_scorecard.visible:
		return true
	if hud_manage_players != null and is_instance_valid(hud_manage_players) and hud_manage_players.visible:
		return true
	if hud_overview != null and is_instance_valid(hud_overview) and hud_overview.visible:
		return true
	return false


func _is_control_in_dialog(ctrl: Control) -> bool:
	var cur: Node = ctrl
	while cur != null and cur != self and cur != get_tree().root:
		if cur is Popup or cur is AcceptDialog or cur is ConfirmationDialog or cur is Window:
			return true
		var c_name := str(cur.name).to_lower()
		if c_name.contains("modal") or c_name.contains("dialog") or c_name.contains("popup") \
			or c_name == "distancemenu" or c_name == "settingslayer" or c_name == "settingsmodallayer" \
			or c_name == "scorecardpanel" or c_name == "manageplayerspanel":
			return true
		cur = cur.get_parent()
	return false


func _style_mulligan_option_button(btn: Button, bg_color: Color, is_selected: bool) -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12

	if is_selected:
		style.bg_color = bg_color.lightened(0.18)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.84, 0.25, 1.0)
		style.shadow_color = Color(1.0, 0.84, 0.25, 0.4)
		style.shadow_size = 5
	else:
		style.bg_color = bg_color
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(1.0, 1.0, 1.0, 0.2)

	var style_hover = style.duplicate()
	style_hover.bg_color = bg_color.lightened(0.25)

	var style_pressed = style.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)


func _update_mulligan_selection_highlight() -> void:
	if not _mulligan_is_selection_mode:
		return
	for i in range(_mulligan_option_buttons.size()):
		var btn = _mulligan_option_buttons[i]
		if btn == null or not is_instance_valid(btn):
			continue
		var is_selected = (i == _mulligan_selected_idx)
		var base_col = Color(0.24, 0.62, 0.36, 0.85) if i == 0 else Color(0.24, 0.46, 0.72, 0.85)
		_style_mulligan_option_button(btn, base_col, is_selected)
		if is_selected and _mulligan_scroll != null and is_instance_valid(_mulligan_scroll):
			_mulligan_scroll.ensure_control_visible(btn)


func _handle_mulligan_dialog_input(event: InputEvent) -> bool:
	if mulligan_confirm_dialog == null or not mulligan_confirm_dialog.visible:
		return false

	var is_cancel = (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B) or event.is_action_pressed("ui_cancel")
	var is_enter = (event is InputEventKey and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A) or event.is_action_pressed("ui_accept")

	if is_cancel:
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
			UIFocusGuard.pop_lock(false)
		mulligan_confirm_dialog.visible = false
		return true

	if not _mulligan_is_selection_mode:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("aim_left"):
			if _mulligan_confirm_btn != null and is_instance_valid(_mulligan_confirm_btn):
				_mulligan_confirm_btn.grab_focus()
			return true
		if event.is_action_pressed("ui_right") or event.is_action_pressed("aim_right"):
			if _mulligan_cancel_btn != null and is_instance_valid(_mulligan_cancel_btn):
				_mulligan_cancel_btn.grab_focus()
			return true
		if event.is_action_pressed("mulligan") or is_enter:
			var cur_focus = get_viewport().gui_get_focus_owner()
			if cur_focus == _mulligan_cancel_btn:
				if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
					UIFocusGuard.pop_lock(false)
				mulligan_confirm_dialog.visible = false
				return true
			else:
				if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
					UIFocusGuard.pop_lock(false)
				mulligan_confirm_dialog.visible = false
				_on_mulligan_confirmed()
				return true
	else:
		if event.is_action_pressed("mulligan"):
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
				UIFocusGuard.pop_lock(false)
			mulligan_confirm_dialog.visible = false
			_on_mulligan_confirmed()
			return true
		elif (event is InputEventKey and (event as InputEventKey).keycode == KEY_DOWN) or event.is_action_pressed("aim_backward"):
			if not _mulligan_option_buttons.is_empty():
				_mulligan_selected_idx = mini(_mulligan_selected_idx + 1, _mulligan_option_buttons.size() - 1)
				_update_mulligan_selection_highlight()
			return true
		elif (event is InputEventKey and (event as InputEventKey).keycode == KEY_UP) or event.is_action_pressed("aim_forward"):
			if not _mulligan_option_buttons.is_empty():
				_mulligan_selected_idx = maxi(_mulligan_selected_idx - 1, 0)
				_update_mulligan_selection_highlight()
			return true
		elif is_enter:
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
				UIFocusGuard.pop_lock(false)
			mulligan_confirm_dialog.visible = false
			if _mulligan_selected_idx == 0:
				_on_mulligan_confirmed()
			elif _mulligan_selected_idx - 1 >= 0 and _mulligan_selected_idx - 1 < _mulligan_matching_entries.size():
				_on_previous_mulligan_selected(_mulligan_matching_entries[_mulligan_selected_idx - 1])
			return true

	return true


func _handle_scorecard_input(event: InputEvent) -> bool:
	if not (hud_scorecard != null and is_instance_valid(hud_scorecard) and hud_scorecard.visible):
		return false

	var is_escape = (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE) or event.is_action_pressed("ui_cancel")
	if is_escape:
		if _last_scorecard_action_type == "toggle":
			if has_node("/root/UIFocusGuard"):
				var guard = get_node("/root/UIFocusGuard")
				if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
					guard.pop_lock(hud_scorecard, false)
			_stop_scorecard_countdown()
			hud_scorecard.visible = false
			_scorecard_selected_hole_index = -1
			_scorecard_settings_mode = false
			_update_scorecard_settings_button_style()
			_set_other_elements_visible(true)
			get_viewport().gui_release_focus()
			var sc_btn = toggles_container.find_child("ScorecardToggleButton", true, false) as Control if toggles_container != null else null
			if sc_btn != null and is_instance_valid(sc_btn) and sc_btn.is_visible_in_tree():
				sc_btn.call_deferred("grab_focus")
			return true
		elif _last_scorecard_action_type == "hole_completed":
			if has_node("/root/UIFocusGuard"):
				var guard = get_node("/root/UIFocusGuard")
				if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
					guard.pop_lock(hud_scorecard, false)
			_stop_scorecard_countdown()
			_scorecard_selected_hole_index = -1
			_on_scorecard_advance()
			return true
		elif _last_scorecard_action_type == "game_over":
			if has_node("/root/UIFocusGuard"):
				var guard = get_node("/root/UIFocusGuard")
				if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
					guard.pop_lock(hud_scorecard, false)
			_stop_scorecard_countdown()
			_scorecard_selected_hole_index = -1
			SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
			return true

	var num_holes = MultiplayerManager.hole_ids.size()
	var cur_f = get_viewport().gui_get_focus_owner()
	var is_typing = (cur_f is LineEdit or cur_f is TextEdit)

	# Bumper hole cycling (LB / RB)
	var is_lb = (InputMap.has_action("suspense_toggle") and event.is_action_pressed("suspense_toggle")) or \
		(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER and event.pressed)
	var is_rb = (InputMap.has_action("announcer_toggle") and event.is_action_pressed("announcer_toggle")) or \
		(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER and event.pressed)

	if not is_typing:
		if is_lb and num_holes > 0:
			var cur = _scorecard_selected_hole_index
			if cur < 0:
				cur = MultiplayerManager.current_hole_index
			var prev_idx = clampi(cur - 1, 0, num_holes - 1)
			_select_scorecard_hole(prev_idx)
			return true

		if is_rb and num_holes > 0:
			var cur = _scorecard_selected_hole_index
			if cur < 0:
				cur = MultiplayerManager.current_hole_index
			var next_idx = clampi(cur + 1, 0, num_holes - 1)
			_select_scorecard_hole(next_idx)
			return true

		# Trigger tab cycling (LT / RT for 18-hole courses)
		if num_holes > 9:
			var is_lt = (InputMap.has_action("prev_club") and event.is_action_pressed("prev_club")) or \
				(event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value >= 0.5)
			var is_rt = (InputMap.has_action("next_club") and event.is_action_pressed("next_club")) or \
				(event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT and event.axis_value >= 0.5)
			if is_lt or is_rt:
				var tabs = ["All", "Front 9", "Back 9"]
				var cur_tab_idx = tabs.find(_scorecard_view_tab)
				if cur_tab_idx == -1:
					cur_tab_idx = 0
				var next_tab_idx = (cur_tab_idx + (1 if is_rt else -1) + tabs.size()) % tabs.size()
				_scorecard_view_tab = tabs[next_tab_idx]
				_populate_scorecard(_last_scorecard_action_type)
				_focus_selected_hole_button()
				return true

	# Directional stick or D-pad when focus is outside the scorecard
	var is_dir = event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
		event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
		event.is_action_pressed("aim_left") or event.is_action_pressed("aim_right") or \
		event.is_action_pressed("aim_forward") or event.is_action_pressed("aim_backward")
	if is_dir:
		var cur_focus = get_viewport().gui_get_focus_owner()
		if cur_focus == null or not hud_scorecard.is_ancestor_of(cur_focus):
			if _scorecard_settings_mode:
				var sel_opt = _scorecard_add_player_section.get_node_or_null("AddRow/PlayerSelectOpt") as Control if _scorecard_add_player_section != null else null
				if sel_opt != null and is_instance_valid(sel_opt) and sel_opt.is_visible_in_tree():
					sel_opt.grab_focus()
				elif _scorecard_settings_btn != null and is_instance_valid(_scorecard_settings_btn) and _scorecard_settings_btn.is_visible_in_tree():
					_scorecard_settings_btn.grab_focus()
				else:
					_focus_selected_hole_button()
			else:
				_focus_selected_hole_button()
			return true

	# Accept / Enter when focus is outside the scorecard
	var is_enter = (event is InputEventKey and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) or \
		(event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A and event.pressed) or \
		event.is_action_pressed("ui_accept")
	if is_enter:
		var cur_focus = get_viewport().gui_get_focus_owner()
		if cur_focus == null or not hud_scorecard.is_ancestor_of(cur_focus):
			if _scorecard_settings_mode:
				var sel_opt = _scorecard_add_player_section.get_node_or_null("AddRow/PlayerSelectOpt") as Control if _scorecard_add_player_section != null else null
				if sel_opt != null and is_instance_valid(sel_opt) and sel_opt.is_visible_in_tree():
					sel_opt.grab_focus()
				elif _scorecard_settings_btn != null and is_instance_valid(_scorecard_settings_btn) and _scorecard_settings_btn.is_visible_in_tree():
					_scorecard_settings_btn.grab_focus()
				else:
					_focus_selected_hole_button()
			else:
				_focus_selected_hole_button()
			return true

	return true


func _unhandled_input(event: InputEvent) -> void:
	if ((event is InputEventKey and not event.echo) or event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_pressed():
		var is_escape = (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE) or event.is_action_pressed("ui_cancel")
		var is_enter = (event is InputEventKey and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A)

		if mulligan_confirm_dialog != null and is_instance_valid(mulligan_confirm_dialog) and mulligan_confirm_dialog.visible:
			_handle_mulligan_dialog_input(event)
			get_viewport().set_input_as_handled()
			return
		if forfeit_confirm_dialog != null and is_instance_valid(forfeit_confirm_dialog) and forfeit_confirm_dialog.visible:
			if is_escape:
				forfeit_confirm_dialog.visible = false
			elif event.is_action_pressed("concede_hole") or is_enter:
				forfeit_confirm_dialog.visible = false
				_on_forfeit_confirmed()
			get_viewport().set_input_as_handled()
			return
		if exit_confirm_dialog != null and is_instance_valid(exit_confirm_dialog) and exit_confirm_dialog.visible:
			var yes_btn = exit_confirm_dialog.find_child("YesButton", true, false) as Button
			var no_btn = exit_confirm_dialog.find_child("NoButton", true, false) as Button
			if is_escape or event.is_action_pressed("ui_cancel"):
				exit_confirm_dialog.visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			if is_enter or event.is_action_pressed("ui_accept"):
				var cur_focus = get_viewport().gui_get_focus_owner()
				if cur_focus == yes_btn:
					yes_btn.emit_signal("pressed")
				elif no_btn != null:
					no_btn.emit_signal("pressed")
				else:
					exit_confirm_dialog.visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
			   event.is_action_pressed("aim_left") or event.is_action_pressed("aim_right"):
				var cur_focus = get_viewport().gui_get_focus_owner()
				if cur_focus == yes_btn and no_btn != null:
					no_btn.grab_focus()
				elif yes_btn != null:
					yes_btn.grab_focus()
				get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
			return
		if add_player_prompt_dialog != null and is_instance_valid(add_player_prompt_dialog) and add_player_prompt_dialog.visible:
			var join_btn = add_player_prompt_dialog.find_child("JoinCurrentButton", true, false) as Button
			var play_btn = add_player_prompt_dialog.find_child("PlayMissedButton", true, false) as Button
			var cancel_btn = add_player_prompt_dialog.find_child("CancelButton", true, false) as Button
			var dialog_btns: Array[Button] = []
			for b in [join_btn, play_btn, cancel_btn]:
				if b != null and is_instance_valid(b) and b.visible and not b.disabled:
					dialog_btns.append(b)
			if is_escape or event.is_action_pressed("ui_cancel"):
				_dismiss_add_player_dialog()
				get_viewport().set_input_as_handled()
				return
			if is_enter or event.is_action_pressed("ui_accept"):
				var cur_focus = get_viewport().gui_get_focus_owner()
				if cur_focus != null and cur_focus in dialog_btns:
					(cur_focus as Button).emit_signal("pressed")
				elif not dialog_btns.is_empty():
					dialog_btns[0].emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_forward") or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value <= -0.5):
				_navigate_dialog_buttons(dialog_btns, -1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_down") or event.is_action_pressed("aim_backward") or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value >= 0.5):
				_navigate_dialog_buttons(dialog_btns, 1)
				get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
			return
		if resume_player_prompt_dialog != null and is_instance_valid(resume_player_prompt_dialog) and resume_player_prompt_dialog.visible:
			var catch_btn = resume_player_prompt_dialog.find_child("CatchUpButton", true, false) as Button
			var skip_btn = resume_player_prompt_dialog.find_child("SkipButton", true, false) as Button
			var cancel_btn = resume_player_prompt_dialog.find_child("CancelButton", true, false) as Button
			var dialog_btns: Array[Button] = []
			for b in [catch_btn, skip_btn, cancel_btn]:
				if b != null and is_instance_valid(b) and b.visible and not b.disabled:
					dialog_btns.append(b)
			if is_escape or event.is_action_pressed("ui_cancel"):
				_dismiss_resume_player_dialog()
				get_viewport().set_input_as_handled()
				return
			if is_enter or event.is_action_pressed("ui_accept"):
				var cur_focus = get_viewport().gui_get_focus_owner()
				if cur_focus != null and cur_focus in dialog_btns:
					(cur_focus as Button).emit_signal("pressed")
				elif not dialog_btns.is_empty():
					dialog_btns[0].emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_forward") or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value <= -0.5):
				_navigate_dialog_buttons(dialog_btns, -1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_down") or event.is_action_pressed("aim_backward") or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value >= 0.5):
				_navigate_dialog_buttons(dialog_btns, 1)
				get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
			return
		if hud_manage_players != null and is_instance_valid(hud_manage_players) and hud_manage_players.visible:
			if is_escape or event.is_action_pressed("ui_cancel"):
				_close_manage_players_panel()
				get_viewport().set_input_as_handled()
				return
			var cur_focus = get_viewport().gui_get_focus_owner()
			if cur_focus == null or not hud_manage_players.is_ancestor_of(cur_focus):
				var select_opt = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/PlayerSelectOpt") as Control
				if select_opt != null and select_opt.is_visible_in_tree():
					select_opt.grab_focus()
			get_viewport().set_input_as_handled()
			return
		if hud_scorecard != null and is_instance_valid(hud_scorecard) and hud_scorecard.visible:
			if _handle_scorecard_input(event):
				get_viewport().set_input_as_handled()
				return
		if is_escape:
			var dist_m = toggles_container.get_node_or_null("DistanceMenu") if toggles_container != null else null
			if dist_m == null and range_ui != null:
				dist_m = range_ui.find_child("DistanceMenu", true, false)
			if dist_m != null and is_instance_valid(dist_m) and dist_m.visible:
				dist_m.visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			var replay_modal = range_ui.call("get_active_swing_replay_modal") if range_ui.has_method("get_active_swing_replay_modal") else range_ui.get_node_or_null("OverlayLayer/SwingReplayModal")
			if replay_modal != null and is_instance_valid(replay_modal) and replay_modal.visible:
				range_ui.call("toggle_prev_shot_analysis")
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return
			if range_ui.has_node("SettingsLayer") and range_ui.get_node("SettingsLayer").visible:
				range_ui.get_node("SettingsLayer").visible = false
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
				return

		if event.is_action_pressed("mulligan"):
			if mulligan_btn != null and is_instance_valid(mulligan_btn) and mulligan_btn.visible and not mulligan_btn.disabled:
				_on_mulligan_pressed()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("home"):
			if exit_confirm_dialog != null and is_instance_valid(exit_confirm_dialog):
				exit_confirm_dialog.visible = true
				var no_b = exit_confirm_dialog.find_child("NoButton", true, false) as Button
				if no_b != null:
					no_b.call_deferred("grab_focus")
			elif range_ui != null and range_ui.has_method("_on_home_button_pressed"):
				range_ui.call("_on_home_button_pressed")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("settings"):
			if range_ui != null and range_ui.has_method("_on_toggle_settings_requested"):
				range_ui.call("_on_toggle_settings_requested")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("green_grid"):
			if grid_btn != null and is_instance_valid(grid_btn) and grid_btn.visible and not grid_btn.disabled:
				grid_btn.emit_signal("pressed")
			elif course_instance != null and course_instance.get("show_green_grid") != null:
				var current_grid = course_instance.get("show_green_grid") as bool
				course_instance.set("show_green_grid", not current_grid)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("toggle_stats"):
			if stats_btn != null and is_instance_valid(stats_btn) and stats_btn.visible and not stats_btn.disabled:
				stats_btn.emit_signal("pressed")
			elif range_ui != null:
				range_ui.call("toggle_stats_visibility")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("shot_analysis_toggle"):
			if range_ui != null:
				var new_v = not range_ui.call("is_shot_analysis_enabled")
				range_ui.call("set_shot_analysis_enabled", new_v)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("free_cam_toggle"):
			toggle_free_camera()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("hit_shot"):
			if is_free_camera_active():
				get_viewport().set_input_as_handled()
				return
			if course_instance != null:
				var p = course_instance.get_node_or_null("Player")
				if p != null:
					if p.has_method("manual_hit_shot"):
						p.manual_hit_shot()
					elif p.has_method("_on_hit_button_pressed"):
						p._on_hit_button_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("reset_shot"):
			if course_instance != null and course_instance.has_method("reset_ball"):
				course_instance.call("reset_ball")
			elif active_ball != null and is_instance_valid(active_ball) and active_ball.has_method("reset"):
				active_ball.call("reset")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("concede_hole"):
			if forfeit_btn != null and is_instance_valid(forfeit_btn) and forfeit_btn.visible and not forfeit_btn.disabled:
				_on_forfeit_pressed()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("skip_flight"):
			if catch_up_banner != null and is_instance_valid(catch_up_banner) and catch_up_banner.visible:
				if catch_up_skip_btn != null and is_instance_valid(catch_up_skip_btn) and catch_up_skip_btn.visible:
					catch_up_skip_btn.emit_signal("pressed")
					get_viewport().set_input_as_handled()
					return
		elif event.is_action_pressed("golfer_cam_toggle"):
			if range_ui != null:
				var enabled = range_ui.call("is_golfer_camera_enabled") if range_ui.has_method("is_golfer_camera_enabled") else false
				var minimized = range_ui.call("is_golfer_camera_minimized") if range_ui.has_method("is_golfer_camera_minimized") else false
				if not enabled:
					range_ui.call("set_golfer_camera_visible", true)
				elif minimized:
					if range_ui.has_method("restore_golfer_camera"):
						range_ui.call("restore_golfer_camera")
					else:
						range_ui.call("set_golfer_camera_visible", true)
				else:
					range_ui.call("set_golfer_camera_visible", false)
				_update_course_golfer_cam_btn_state()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("putting_cam_toggle"):
			if range_ui != null and range_ui.has_method("is_putting_camera_enabled"):
				var enabled = range_ui.call("is_putting_camera_enabled")
				var minimized = range_ui.call("is_putting_camera_minimized") if range_ui.has_method("is_putting_camera_minimized") else false
				if not enabled:
					range_ui.call("set_putting_camera_visible", true)
				elif minimized:
					if range_ui.has_method("restore_putting_camera"):
						range_ui.call("restore_putting_camera")
					else:
						range_ui.call("set_putting_camera_visible", true)
				else:
					range_ui.call("set_putting_camera_visible", false)
			_update_course_putting_cam_btn_state()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("next_club"):
			_cycle_club(true)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("prev_club"):
			_cycle_club(false)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("announcer_toggle"):
			if announcer_btn != null and is_instance_valid(announcer_btn) and announcer_btn.visible and not announcer_btn.disabled:
				announcer_btn.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("suspense_toggle"):
			if tension_btn != null and is_instance_valid(tension_btn) and tension_btn.visible and not tension_btn.disabled:
				tension_btn.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("prev_shot_analysis_toggle") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y):
			if range_ui != null and range_ui.has_method("toggle_prev_shot_analysis"):
				range_ui.call("toggle_prev_shot_analysis")
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("aerial_aim"):
			if map_btn != null and is_instance_valid(map_btn) and map_btn.visible and not map_btn.disabled:
				map_btn.emit_signal("pressed")
			elif course_instance != null and course_instance.has_method("_on_map_button_pressed"):
				course_instance.call("_on_map_button_pressed")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("toggle_helpers"):
			if hide_helpers_btn != null and is_instance_valid(hide_helpers_btn) and hide_helpers_btn.visible and not hide_helpers_btn.disabled:
				hide_helpers_btn.emit_signal("pressed")
			elif range_ui != null and range_ui.has_method("toggle_helpers"):
				range_ui.call("toggle_helpers")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("distance_menu_toggle"):
			var is_dist_enabled := false
			if has_node("/root/GlobalSettings"):
				var gs = get_node("/root/GlobalSettings")
				if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
					is_dist_enabled = bool(gs.range_settings.debug_show_hit_distance.value)
			if is_dist_enabled:
				var dist_b = dist_btn if (dist_btn != null and is_instance_valid(dist_btn)) else (toggles_container.get_node_or_null("HitDistanceButton") as Button if toggles_container != null else null)
				if dist_b != null and is_instance_valid(dist_b) and dist_b.visible and not dist_b.disabled:
					dist_b.emit_signal("pressed")
				elif range_ui != null and range_ui.has_method("toggle_distance_menu"):
					range_ui.call("toggle_distance_menu")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("shot_traces_toggle"):
			if range_ui != null and range_ui.has_method("toggle_shot_traces"):
				range_ui.call("toggle_shot_traces")
			elif course_instance != null and course_instance.has_method("_toggle_shot_traces"):
				course_instance.call("_toggle_shot_traces")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("rollout_toggle"):
			if rollout_btn != null and is_instance_valid(rollout_btn):
				rollout_btn.emit_signal("pressed")
			elif range_ui != null and range_ui.has_method("toggle_rollout"):
				range_ui.call("toggle_rollout")
			get_viewport().set_input_as_handled()
			return
		elif _check_stat_toggle_input(event):
			get_viewport().set_input_as_handled()
			return


func _check_stat_toggle_input(event: InputEvent) -> bool:
	for stat in StatDefinitions.STATS:
		var stat_id = str(stat.get("id", ""))
		var act = "stat_toggle_" + stat_id
		if event.is_action_pressed(act):
			if has_node("/root/KeybindingManager"):
				KeybindingManager.toggle_stat(stat_id)
				return true
	return false


var _last_club_cycle_time: float = 0.0
const CLUB_CYCLE_MIN_COOLDOWN: float = 0.12

func _cycle_club(longer: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if (now - _last_club_cycle_time) < CLUB_CYCLE_MIN_COOLDOWN:
		return
	_last_club_cycle_time = now
	var club_sel = club_selector_node
	if club_sel == null and course_instance != null and course_instance.has_method("get_club_selector"):
		club_sel = course_instance.call("get_club_selector")
	if club_sel == null:
		var current_scene = get_tree().current_scene
		if current_scene != null:
			club_sel = current_scene.find_child("ClubSelector", true, false)
	if club_sel != null and is_instance_valid(club_sel):
		if longer:
			club_sel.call("select_next_club")
		else:
			club_sel.call("select_prev_club")


func _update_hud_tooltips() -> void:
	if not has_node("/root/KeybindingManager"):
		return
	var km = get_node("/root/KeybindingManager")
	if stats_btn != null and is_instance_valid(stats_btn):
		stats_btn.tooltip_text = "Toggle Stats (Show/Hide) [%s]" % km.get_action_summary_str("toggle_stats")
	if grid_btn != null and is_instance_valid(grid_btn):
		grid_btn.tooltip_text = "Toggle Slope Grid (Show/Hide) [%s]" % km.get_action_summary_str("green_grid")
	if golfer_cam_btn != null and is_instance_valid(golfer_cam_btn):
		golfer_cam_btn.tooltip_text = "Toggle Golfer Camera [%s] (Right-click for Setup)" % km.get_action_summary_str("golfer_cam_toggle")
	if putting_cam_btn != null and is_instance_valid(putting_cam_btn):
		putting_cam_btn.tooltip_text = "Toggle Putting Camera [%s] (Right-click for Setup)" % km.get_action_summary_str("putting_cam_toggle")
	if map_btn != null and is_instance_valid(map_btn):
		var is_aerial = course_instance.get("is_aerial_view") as bool if course_instance != null and course_instance.get("is_aerial_view") != null else false
		if is_aerial:
			map_btn.tooltip_text = "Return to Player [%s]" % km.get_action_summary_str("aerial_aim")
		else:
			map_btn.tooltip_text = "Toggle Map View [%s]" % km.get_action_summary_str("aerial_aim")
	if mulligan_btn != null and is_instance_valid(mulligan_btn):
		mulligan_btn.tooltip_text = "Mulligan (Undo Shot) [%s]" % km.get_action_summary_str("mulligan")
	if forfeit_btn != null and is_instance_valid(forfeit_btn):
		forfeit_btn.tooltip_text = "White Flag (Concede Hole) [%s]" % km.get_action_summary_str("concede_hole")
	if hide_helpers_btn != null and is_instance_valid(hide_helpers_btn):
		hide_helpers_btn.tooltip_text = "Toggle Helpers (Show/Hide) [%s]" % km.get_action_summary_str("toggle_helpers")
	if announcer_btn != null and is_instance_valid(announcer_btn):
		announcer_btn.tooltip_text = "Toggle Announcer Commentary [%s]" % km.get_action_summary_str("announcer_toggle")
	if tension_btn != null and is_instance_valid(tension_btn):
		tension_btn.tooltip_text = "Toggle Suspense Heartbeat & Tunnel Vision [%s]" % km.get_action_summary_str("suspense_toggle")
	if dist_btn != null and is_instance_valid(dist_btn):
		dist_btn.tooltip_text = "Hit Menu [%s]" % km.get_action_summary_str("distance_menu_toggle")
	if rollout_btn != null and is_instance_valid(rollout_btn):
		rollout_btn.tooltip_text = "Toggle Ball Rollout & Bounce [%s]" % km.get_action_summary_str("rollout_toggle")
	if free_cam_btn != null and is_instance_valid(free_cam_btn):
		var km_bind = km.get_action_summary_str("free_cam_toggle")
		if km_bind.is_empty():
			free_cam_btn.tooltip_text = "Toggle Free Camera (Fly using Analog Stick, Arrow Keys, or Click to Move)"
		else:
			free_cam_btn.tooltip_text = "Toggle Free Camera [%s] (Fly using Analog Stick, Arrow Keys, or Click to Move)" % km_bind
	if graphics_toggle_btn != null and is_instance_valid(graphics_toggle_btn):
		var cur_q = _get_current_graphics_quality()
		graphics_toggle_btn.tooltip_text = "Graphics Quality: %s (Click to cycle Low/Medium/High)" % cur_q
	if stuck_ball_btn != null and is_instance_valid(stuck_ball_btn):
		stuck_ball_btn.tooltip_text = "Move ball 2 yards closer to nearest fairway without counting a stroke"
	if club_selector_node != null and is_instance_valid(club_selector_node):
		var club_btn = club_selector_node.get("club_button") as Button
		if club_btn != null and is_instance_valid(club_btn):
			club_btn.tooltip_text = "Select Club [Prev: %s, Next: %s]" % [km.get_action_summary_str("prev_club"), km.get_action_summary_str("next_club")]


func _on_golfer_cam_modal_state_changed(is_open: bool) -> void:
	if stats_btn != null and is_instance_valid(stats_btn):
		if is_open:
			stats_btn.offset_left = 495
			stats_btn.offset_right = 575
		else:
			stats_btn.offset_left = 30
			stats_btn.offset_right = 110
	if grid_btn != null and is_instance_valid(grid_btn):
		if is_open:
			grid_btn.offset_left = 595
			grid_btn.offset_right = 675
		else:
			grid_btn.offset_left = 130
			grid_btn.offset_right = 210


func _on_stats_visibility_changed(is_vis: bool) -> void:
	if stats_btn != null and is_instance_valid(stats_btn):
		if is_vis:
			apply_circular_button_style(stats_btn, Color(0.24, 0.46, 0.72, 0.85))
		else:
			apply_circular_button_style(stats_btn, Color(0.15, 0.15, 0.15, 0.85))


func _on_golfer_cam_enabled_changed(_is_enabled: bool) -> void:
	_update_course_golfer_cam_btn_state()
	_update_course_putting_cam_btn_state()


func _on_putting_cam_enabled_changed(_is_enabled: bool) -> void:
	_update_course_putting_cam_btn_state()
	_update_course_golfer_cam_btn_state()


func _update_course_golfer_cam_btn_state() -> void:
	if golfer_cam_btn == null or not is_instance_valid(golfer_cam_btn):
		return
	if range_ui != null:
		var enabled = range_ui.call("is_golfer_camera_enabled") if range_ui.has_method("is_golfer_camera_enabled") else false
		var minimized = range_ui.call("is_golfer_camera_minimized") if range_ui.has_method("is_golfer_camera_minimized") else false
		if not enabled:
			golfer_cam_btn.text = "📹 Golfer Cam: OFF"
			apply_material_button_style(golfer_cam_btn, Color(0.2, 0.45, 0.45, 0.85))
		elif minimized:
			golfer_cam_btn.text = "📹 Golfer Cam: MIN [REC]"
			apply_material_button_style(golfer_cam_btn, Color(0.2, 0.55, 0.7, 0.85))
		else:
			golfer_cam_btn.text = "📹 Golfer Cam: ON"
			apply_material_button_style(golfer_cam_btn, Color(0.15, 0.6, 0.5, 0.85))


func _update_course_putting_cam_btn_state() -> void:
	if putting_cam_btn == null or not is_instance_valid(putting_cam_btn):
		return
	if range_ui != null:
		var enabled = range_ui.call("is_putting_camera_enabled") if range_ui.has_method("is_putting_camera_enabled") else false
		var minimized = range_ui.call("is_putting_camera_minimized") if range_ui.has_method("is_putting_camera_minimized") else false
		if not enabled:
			putting_cam_btn.text = "🎯 Putting Cam: OFF"
			apply_material_button_style(putting_cam_btn, Color(0.35, 0.35, 0.35, 0.85))
		elif minimized:
			putting_cam_btn.text = "🎯 Putting Cam: MIN [REC]"
			apply_material_button_style(putting_cam_btn, Color(0.2, 0.55, 0.5, 0.85))
		else:
			putting_cam_btn.text = "🎯 Putting Cam: ON"
			apply_material_button_style(putting_cam_btn, Color(0.15, 0.6, 0.3, 0.85))


func _update_track_averages_btn_state() -> void:
	var is_on := true
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and mp.has_method("is_club_averages_tracking_enabled"):
		is_on = mp.is_club_averages_tracking_enabled()
	elif has_node("/root/GlobalSettings") and GlobalSettings.range_settings != null and "track_club_averages" in GlobalSettings.range_settings:
		is_on = bool(GlobalSettings.range_settings.track_club_averages.value)
	if track_averages_btn != null and is_instance_valid(track_averages_btn):
		track_averages_btn.text = "📊 Track Averages: ON" if is_on else "📊 Track Averages: OFF"
		var c = Color(0.18, 0.55, 0.65, 0.85) if is_on else Color(0.5, 0.5, 0.5, 0.85)
		apply_material_button_style(track_averages_btn, c)


func toggle_free_camera() -> void:
	set_free_camera_mode(not is_free_camera_active())


func is_free_camera_active() -> bool:
	return _free_camera != null and is_instance_valid(_free_camera) and _free_camera.is_active


func set_free_camera_mode(enabled: bool) -> void:
	if enabled:
		if course_instance != null and "is_aerial_view" in course_instance and course_instance.is_aerial_view:
			if course_instance.has_method("toggle_aerial_view"):
				course_instance.toggle_aerial_view()
		if _free_camera == null or not is_instance_valid(_free_camera):
			var free_cam_script = load("res://Utils/free_camera.gd")
			_free_camera = free_cam_script.new()
			_free_camera.name = "FreeCamera3D"
			add_child(_free_camera)
			if not _free_camera.deactivated.is_connected(_on_free_camera_deactivated):
				_free_camera.deactivated.connect(_on_free_camera_deactivated)
		var cur_cam = get_viewport().get_camera_3d() if get_viewport() != null else null
		_free_camera.activate(cur_cam, course_instance)
	else:
		if _free_camera != null and is_instance_valid(_free_camera):
			_free_camera.deactivate()
		reset_to_standard_ball_view()
	_update_free_cam_btn_state()
	if range_ui != null and range_ui.has_method("set_free_camera_btn_state"):
		range_ui.call("set_free_camera_btn_state", enabled)
	if course_instance != null and course_instance.has_method("set_free_camera_active"):
		course_instance.call("set_free_camera_active", enabled)


func _on_free_camera_deactivated() -> void:
	_update_free_cam_btn_state()
	reset_to_standard_ball_view()
	if range_ui != null and range_ui.has_method("set_free_camera_btn_state"):
		range_ui.call("set_free_camera_btn_state", false)
	if course_instance != null and course_instance.has_method("set_free_camera_active"):
		course_instance.call("set_free_camera_active", false)


func reset_to_standard_ball_view() -> void:
	if course_instance == null:
		return
	var player_node = course_instance.get_node_or_null("Player")
	var ball = active_ball
	if ball == null and player_node != null:
		ball = player_node.get("ball")
	if ball == null:
		if course_instance.has_method("reset_to_standard_ball_view"):
			course_instance.call("reset_to_standard_ball_view")
		return

	var ball_pos: Vector3 = ball.global_position
	if ball_pos.is_zero_approx() and "spawn_position" in ball and not (ball.spawn_position as Vector3).is_zero_approx():
		ball_pos = ball.spawn_position

	var is_putting = is_default_club_putter() or is_player_on_green() or is_player_on_fringe()
	var target_aim = course_instance.get("aim_target_pos")
	if is_putting and course_instance.get("current_hole_location") != null:
		target_aim = course_instance.get("current_hole_location")
	elif target_aim == null or (target_aim is Vector3 and target_aim.is_zero_approx()):
		if course_instance.get("current_hole_location") != null and not (course_instance.current_hole_location as Vector3).is_zero_approx():
			target_aim = course_instance.current_hole_location
		else:
			var aim_yaw: float = ball.get("aim_yaw_offset_deg") if "aim_yaw_offset_deg" in ball else 0.0
			target_aim = ball_pos + Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(aim_yaw)) * 50.0

	var diff: Vector3 = target_aim - ball_pos
	if course_instance.get("current_hole_location") != null and not (course_instance.current_hole_location as Vector3).is_zero_approx():
		var to_hole: Vector3 = (course_instance.current_hole_location as Vector3) - ball_pos
		if Vector2(diff.x, diff.z).normalized().dot(Vector2(to_hole.x, to_hole.z).normalized()) < 0.0:
			diff = to_hole
			target_aim = course_instance.current_hole_location

	var angle_rad = atan2(diff.z, diff.x)
	var camera = course_instance.get_node_or_null("PhantomCamera3D")
	var cam_pos: Vector3
	if course_instance.has_method("get_address_camera_position"):
		cam_pos = course_instance.call("get_address_camera_position", ball_pos, -angle_rad, is_putting)
	else:
		var cam_dist = 3.6
		var cam_height = 1.35
		var gs = get_node_or_null("/root/GlobalSettings")
		if gs != null and gs.range_settings != null:
			if "camera_distance" in gs.range_settings:
				cam_dist = gs.range_settings.camera_distance.value
			if "camera_height" in gs.range_settings:
				cam_height = gs.range_settings.camera_height.value
		var local_offset = Vector3(-1.35, 0.8, 0) if is_putting else Vector3(-cam_dist, cam_height, 0)
		if course_instance.has_method("get_camera_local_offset"):
			local_offset = course_instance.call("get_camera_local_offset", is_putting)
		var rotated_offset = local_offset.rotated(Vector3.UP, -angle_rad)
		cam_pos = ball_pos + rotated_offset

	if course_instance.has_method("clamp_camera_position"):
		cam_pos = course_instance.call("clamp_camera_position", cam_pos)
	elif course_instance.has_method("get_height"):
		var min_y = course_instance.call("get_height", cam_pos.x, cam_pos.z) + 0.35
		if cam_pos.y < min_y:
			cam_pos.y = min_y

	var target_look: Vector3
	if course_instance.has_method("get_camera_target_look"):
		target_look = course_instance.call("get_camera_target_look", target_aim, ball_pos, is_putting)
	elif is_putting:
		var dist = ball_pos.distance_to(target_aim)
		var look_dist = clamp(dist * 0.4, 2.0, 6.0)
		if dist < 2.0:
			look_dist = dist
		var fraction = clamp(look_dist / max(dist, 0.001), 0.0, 1.0)
		target_look = ball_pos.lerp(target_aim, fraction)
	else:
		var dist = ball_pos.distance_to(target_aim) if not target_aim.is_zero_approx() else 50.0
		var aim_dir = (target_aim - ball_pos).normalized() if not target_aim.is_zero_approx() else Vector3.ZERO
		if aim_dir.is_zero_approx():
			var yaw: float = ball.get("aim_yaw_offset_deg") if "aim_yaw_offset_deg" in ball else 0.0
			aim_dir = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(yaw))
		var look_dist = clampf(dist, 10.0, 50.0)
		var t = clampf(look_dist / maxf(dist, 0.001), 0.0, 1.0)
		var base_look_pos = ball_pos.lerp(target_aim, t) if not target_aim.is_zero_approx() else (ball_pos + aim_dir * 50.0)
		target_look = base_look_pos + Vector3.UP * 1.0

	var fov_val := 75.0
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null and gs.range_settings != null and "camera_fov" in gs.range_settings:
		fov_val = gs.range_settings.camera_fov.value

	if camera != null:
		camera.follow_mode = PhantomCamera3D.FollowMode.NONE
		camera.look_at_mode = PhantomCamera3D.LookAtMode.NONE
		camera.global_position = cam_pos
		camera.look_at(target_look)
		if camera.camera_3d_resource != null:
			camera.camera_3d_resource.fov = fov_val

	var cam3d = course_instance.get_node_or_null("Camera3D")
	if cam3d != null:
		cam3d.global_position = cam_pos
		cam3d.look_at(target_look)
		cam3d.fov = fov_val
		cam3d.make_current()

	if has_node("/root/ScreenOffsetManager"):
		var som = get_node("/root/ScreenOffsetManager")
		var cam_to_register = camera if camera != null else cam3d
		if cam_to_register != null:
			som.call("register_camera", cam_to_register)
		som.call("set_putter_active", is_putting)
		som.call("on_ready_for_shot", 0.0, true)


func _update_free_cam_btn_state() -> void:
	if free_cam_btn != null and is_instance_valid(free_cam_btn):
		var active = is_free_camera_active()
		if active:
			free_cam_btn.text = "🎥 Free Camera: ON"
			apply_material_button_style(free_cam_btn, Color(0.2, 0.6, 0.75, 0.9))
		else:
			free_cam_btn.text = "🎥 Free Camera: OFF"
			apply_material_button_style(free_cam_btn, Color(0.35, 0.35, 0.35, 0.85))


func _get_current_graphics_quality() -> String:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null:
		if gs.has_method("get_graphics_quality"):
			return gs.get_graphics_quality()
		elif gs.range_settings != null and gs.range_settings.settings.has("graphics_quality"):
			return str(gs.range_settings.settings["graphics_quality"].value)
	return MobilePerformance.get_default_graphics_quality()


func _cycle_graphics_quality(reverse: bool = false) -> void:
	var current_q = _get_current_graphics_quality()
	var is_mob = MobilePerformance.is_mobile()
	var qualities = ["Low", "Medium"] if is_mob else ["Low", "Medium", "High"]
	var idx = qualities.find(current_q)
	if idx == -1:
		idx = 0
	
	if reverse:
		idx = (idx - 1 + qualities.size()) % qualities.size()
	else:
		idx = (idx + 1) % qualities.size()
	
	var next_q = qualities[idx]
	_apply_selected_graphics_quality(next_q)


func _apply_selected_graphics_quality(next_q: String) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs != null and gs.range_settings != null and gs.range_settings.settings.has("graphics_quality"):
		gs.range_settings.settings["graphics_quality"].set_value(next_q)
		gs.save_settings()
	
	_update_graphics_toggle_btn_state()
	if range_ui != null and range_ui.has_method("update_graphics_toggle_btn_state"):
		range_ui.call("update_graphics_toggle_btn_state")
	
	var tree = get_tree()
	if tree != null and tree.root != null:
		MobilePerformance.apply_graphics_quality_with_spinner(tree, next_q)
	elif get_node_or_null("/root") != null:
		MobilePerformance.apply_graphics_quality(get_node("/root"), next_q)


func _update_graphics_toggle_btn_state() -> void:
	if graphics_toggle_btn == null or not is_instance_valid(graphics_toggle_btn):
		return
	var current_q = _get_current_graphics_quality()
	if MobilePerformance.is_mobile() and current_q == "High":
		current_q = "Medium"
	
	graphics_toggle_btn.text = "🎨 Graphics: %s" % current_q
	match current_q:
		"Low":
			graphics_toggle_btn.tooltip_text = "Graphics Quality: Low (Fast Stylized) - Click to cycle"
			apply_material_button_style(graphics_toggle_btn, Color(0.48, 0.48, 0.52, 0.85))
		"Medium":
			graphics_toggle_btn.tooltip_text = "Graphics Quality: Medium (Balanced PBR) - Click to cycle"
			apply_material_button_style(graphics_toggle_btn, Color(0.22, 0.48, 0.68, 0.85))
		"High", _:
			graphics_toggle_btn.tooltip_text = "Graphics Quality: High (Photorealistic) - Click to cycle"
			apply_material_button_style(graphics_toggle_btn, Color(0.18, 0.58, 0.38, 0.85))


func cycle_graphics_quality(reverse: bool = false) -> void:
	_cycle_graphics_quality(reverse)


func set_graphics_quality(quality: String) -> void:
	_apply_selected_graphics_quality(quality)


func update_graphics_toggle_btn_state() -> void:
	_update_graphics_toggle_btn_state()


func _on_debug_hit_distance_setting_changed(_val) -> void:
	_update_hit_distance_button_visibility()


func _update_hit_distance_button_state() -> void:
	if dist_btn == null or not is_instance_valid(dist_btn):
		return
	var menu = toggles_container.get_node_or_null("DistanceMenu") if toggles_container != null else null
	var is_open = menu != null and is_instance_valid(menu) and menu.visible
	if is_open:
		dist_btn.text = "🎯 Hit Menu: OPEN"
		apply_material_button_style(dist_btn, Color(0.75, 0.25, 0.75, 0.9))
	else:
		dist_btn.text = "🎯 Hit Menu"
		apply_material_button_style(dist_btn, Color(0.6, 0.2, 0.6, 0.85))


func _update_hit_distance_button_visibility() -> void:
	if dist_btn == null or not is_instance_valid(dist_btn):
		return
	var enabled := false
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			enabled = bool(gs.range_settings.debug_show_hit_distance.value)
	dist_btn.visible = enabled
	var menu = toggles_container.get_node_or_null("DistanceMenu") if toggles_container != null else null
	if not enabled and menu != null and menu.visible:
		menu.visible = false
	_update_hit_distance_button_state()
	_update_helpers_scroll_layout.call_deferred()
	call_deferred("_update_hud_focus_neighbors")


func toggle_distance_menu() -> void:
	var enabled := false
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.range_settings != null and gs.range_settings.settings.has("debug_show_hit_distance"):
			enabled = bool(gs.range_settings.debug_show_hit_distance.value)
	if not enabled:
		return
	if dist_btn != null and is_instance_valid(dist_btn):
		dist_btn.emit_signal("pressed")


func _get_current_green_vertices() -> PackedVector3Array:
	if course_instance != null and course_instance.has_method("get_current_green_vertices"):
		return course_instance.get_current_green_vertices()
	var pin_pos = course_instance.get("current_hole_location") if course_instance != null else null
	if GlobalSettings.is_chipping_minigame and course_instance != null and course_instance.get("aim_target_pos") != null:
		pin_pos = course_instance.get("aim_target_pos")
	if pin_pos == null and course_instance != null:
		pin_pos = course_instance.get("aim_target_pos")
	if pin_pos == null or course_instance == null:
		return PackedVector3Array()
		
	# Find the green static body closest to the pin
	var closest_green: StaticBody3D = null
	var min_dist_to_pin = 999999.0
	
	var stack = [course_instance]
	while not stack.is_empty():
		var node = stack.pop_back()
		var n_lower: String = node.name.to_lower()
		var is_green_node: bool = (node is StaticBody3D) and (
			n_lower.begins_with("green_static") or n_lower.contains("green") or (node.has_meta("surface_type") and int(node.get_meta("surface_type")) == 4)
		)
		if is_green_node:
			var centroid = Vector3.ZERO
			var vertex_count = 0
			for child in node.get_children():
				if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
					var verts = child.shape.data
					if verts.size() > 0:
						for v in verts:
							centroid += node.global_transform * v
						vertex_count += verts.size()
			if vertex_count > 0:
				centroid /= vertex_count
				var dist = centroid.distance_to(pin_pos)
				if dist < min_dist_to_pin:
					min_dist_to_pin = dist
					closest_green = node
			else:
				var dist = node.global_position.distance_to(pin_pos)
				if dist < min_dist_to_pin:
					min_dist_to_pin = dist
					closest_green = node
		
		for child in node.get_children():
			stack.append(child)
			
	if closest_green == null:
		return PackedVector3Array()
		
	# Gather all global vertices from the closest green
	var global_verts = PackedVector3Array()
	for child in closest_green.get_children():
		if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
			var verts = child.shape.data
			for v in verts:
				global_verts.append(closest_green.global_transform * v)
				
	return global_verts


func _get_cached_green_vertices() -> PackedVector3Array:
	var hole_idx = MultiplayerManager.current_hole_index
	if hole_idx != _cached_green_hole_index or _cached_green_verts.is_empty():
		_cached_green_verts = _get_current_green_vertices()
		_cached_green_hole_index = hole_idx
	return _cached_green_verts


func _update_top_hud(player: Dictionary) -> void:
	if hud_player_name_lbl == null or MultiplayerManager.hole_ids.is_empty():
		return
		
	# 1. Update player name and active player badge
	var mode = MultiplayerManager.game_mode
	var name_text = player.get("name", "Player")
	if mode == "Scramble":
		name_text += " (Scramble)"
	elif mode == "2v2 Scramble":
		var team = player.get("team", "")
		if not team.is_empty():
			name_text += " (%s)" % team
		else:
			name_text += " (2v2)"
	elif mode == "Skins":
		var p_skins = MultiplayerManager.skins_won.get(player.get("name", ""), 0)
		name_text += " (%d Skins)" % p_skins
	elif mode == "Closest to Pin":
		var p_pts = _get_player_points(player)
		name_text += " (%d pts)" % p_pts

	if _is_spectating():
		hud_player_name_lbl.text = "👁️ %s" % name_text
	else:
		hud_player_name_lbl.text = name_text
	if hud_player_badge != null and hud_player_badge_lbl != null:
		var p_name = player.get("name", "Player")
		var avatar_path = player.get("avatar", "")
		if avatar_path.is_empty():
			avatar_path = MultiplayerManager.get_player_avatar(p_name)
		
		var has_avatar = not avatar_path.is_empty() and ResourceLoader.exists(avatar_path)
		if has_avatar and hud_player_avatar_rect != null:
			hud_player_avatar_rect.texture = load(avatar_path)
			hud_player_avatar_rect.visible = true
			hud_player_badge_lbl.visible = false
			var clear_style = StyleBoxEmpty.new()
			hud_player_badge.add_theme_stylebox_override("panel", clear_style)
		else:
			if hud_player_avatar_rect != null:
				hud_player_avatar_rect.visible = false
			hud_player_badge_lbl.visible = true
			var p_color = MultiplayerManager.get_player_color(player)
			var new_style = StyleBoxFlat.new()
			new_style.bg_color = p_color
			new_style.corner_radius_top_left = 13
			new_style.corner_radius_top_right = 13
			new_style.corner_radius_bottom_left = 13
			new_style.corner_radius_bottom_right = 13
			new_style.content_margin_left = 4
			new_style.content_margin_right = 4
			new_style.content_margin_top = 2
			new_style.content_margin_bottom = 2
			hud_player_badge.add_theme_stylebox_override("panel", new_style)
			hud_player_badge_lbl.text = p_name.substr(0, 1).to_upper()
	
	# 2. Update overall score relative to par, Skins count, or Closest to Pin points
	var overall_score_str = "E"
	if mode == "Skins":
		var p_skins = MultiplayerManager.skins_won.get(player.get("name", ""), 0)
		overall_score_str = "%d S" % p_skins
		if MultiplayerManager.carryover_skins > 0:
			overall_score_str += " (C%d)" % MultiplayerManager.carryover_skins
	elif mode == "Closest to Pin":
		var p_pts = _get_player_points(player)
		overall_score_str = "%d pts" % p_pts
	else:
		var total_diff: int = 0
		var completed_any = false
		for idx in range(MultiplayerManager.hole_ids.size()):
			var h_id = MultiplayerManager.hole_ids[idx]
			if idx < MultiplayerManager.current_hole_index or bool(player.get("holed_out", false)):
				var score = player.get("hole_scores", {}).get(h_id)
				if score != null and score > 0:
					var par = int(MultiplayerManager.hole_info.get(h_id, {}).get("Par", 4))
					total_diff += int(score) - par
					completed_any = true
		if completed_any:
			if total_diff > 0:
				overall_score_str = "+" + str(total_diff)
			elif total_diff < 0:
				overall_score_str = str(total_diff)
		else:
			overall_score_str = "E"
	hud_overall_score_lbl.text = overall_score_str
	
	# 3. Update hole number
	var hole_idx = clamp(MultiplayerManager.current_hole_index, 0, max(0, MultiplayerManager.hole_ids.size() - 1))
	var hole_num = MultiplayerManager.get_hole_number(hole_idx)
	hud_hole_num_lbl.text = str(hole_num)
	
	# 4. Update shots and current hole par diff
	if MultiplayerManager.hole_ids.is_empty():
		return
	var hole_id = MultiplayerManager.hole_ids[hole_idx]
	var active_hole = MultiplayerManager.hole_info.get(hole_id, {})
	var hole_par = int(round(float(active_hole.get("Par", 4))))
	var strokes = player.get("strokes", 0)
	var current_shot = strokes + 1
	
	# Build shots list BBCode
	var shot_bbcodes = []
	if mode == "Closest to Pin":
		if strokes == 0:
			shot_bbcodes.append("[u][b]Shot 1 of 1[/b][/u]")
		else:
			shot_bbcodes.append("[color=#55ff55]Shot Taken[/color]")
	else:
		for i in range(1, hole_par + 1):
			if i == current_shot:
				shot_bbcodes.append("[u][b]%d[/b][/u]" % i)
			else:
				shot_bbcodes.append("[color=#8c939d]%d[/color]" % i)
	var shots_str = "   ".join(shot_bbcodes)
	
	# Current hole par tracker (strokes - par)
	var hole_diff = strokes - hole_par
	var diff_str = ""
	if mode == "Closest to Pin":
		diff_str = "[color=#f0c040]Closest to Pin[/color]"
	elif hole_diff > 0:
		diff_str = "[color=#ff5555]+%d[/color]" % hole_diff
	elif hole_diff < 0:
		diff_str = "[color=#55ff55]%d[/color]" % hole_diff
	else:
		diff_str = "[color=#ffffff]E[/color]"
		
	hud_shots_rtl.text = "%s     ( %s )" % [shots_str, diff_str]
	_update_distance_queue()


func _update_distance_queue() -> void:
	if hud_distance_queue_panel == null or hud_distance_queue_vbox == null:
		return
	
	for child in hud_distance_queue_vbox.get_children():
		child.queue_free()
	
	var pin_pos = null
	if course_instance != null:
		pin_pos = course_instance.get("current_hole_location")
		if pin_pos == null or (pin_pos is Vector3 and pin_pos.is_zero_approx()):
			pin_pos = course_instance.get("aim_target_pos")
	
	var queue_items: Array[Dictionary] = MultiplayerManager.get_distance_queue(pin_pos)
	
	if queue_items.is_empty():
		hud_distance_queue_panel.visible = false
		if _hole_num_style != null:
			_hole_num_style.corner_radius_bottom_left = 12
		if _shots_style != null:
			_shots_style.corner_radius_bottom_right = 12
		_update_minimap_position()
		_update_minimap_position.call_deferred()
		return
	
	hud_distance_queue_panel.visible = true
	if _hole_num_style != null:
		_hole_num_style.corner_radius_bottom_left = 0
	if _shots_style != null:
		_shots_style.corner_radius_bottom_right = 0
	
	for item in queue_items:
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size = Vector2(0, 22)
		row.add_theme_constant_override("separation", 8)
		
		# 1. Player Name
		var name_lbl = Label.new()
		name_lbl.text = item.get("formatted_name", item.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.92))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_lbl)
		
		# 2. Score
		var score_lbl = Label.new()
		score_lbl.text = item.get("score_str", "E")
		score_lbl.add_theme_font_size_override("font_size", 12)
		score_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		score_lbl.custom_minimum_size = Vector2(40, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(score_lbl)
		
		# 3. Distance Away
		var dist_lbl = Label.new()
		dist_lbl.text = item.get("distance_str", "")
		dist_lbl.add_theme_font_size_override("font_size", 12)
		dist_lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.92))
		dist_lbl.custom_minimum_size = Vector2(75, 0)
		dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dist_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(dist_lbl)
		
		# 4. Suggested Club
		var club_lbl = Label.new()
		club_lbl.text = item.get("suggested_club", "")
		club_lbl.add_theme_font_size_override("font_size", 12)
		var is_holed: bool = bool(item.get("holed_out", false))
		var club_color: Color = Color(0.75, 0.78, 0.82) if is_holed else Color(0.65, 0.82, 0.95)
		club_lbl.add_theme_color_override("font_color", club_color)
		club_lbl.custom_minimum_size = Vector2(45, 0)
		club_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		club_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(club_lbl)
		
		hud_distance_queue_vbox.add_child(row)
	
	_update_minimap_position()
	_update_minimap_position.call_deferred()


func _get_normal_minimap_top_y() -> float:
	var base_top = 30.0
	var base_card_h = 104.0 # Base height of Row 1 + Row 2
	var gap = 8.0
	if hud_distance_queue_panel != null and hud_distance_queue_panel.visible and hud_distance_queue_vbox != null:
		var row_count = hud_distance_queue_vbox.get_child_count()
		if row_count > 0:
			var queue_h = 10.0 + float(row_count) * 22.0 + float(max(0, row_count - 1)) * 3.0
			return base_top + base_card_h + queue_h + gap
	if hud_top_left_widget != null and is_instance_valid(hud_top_left_widget):
		var min_h = hud_top_left_widget.get_combined_minimum_size().y
		if min_h > 0.0:
			return base_top + min_h + gap
		elif hud_top_left_widget.size.y > 0.0:
			return base_top + hud_top_left_widget.size.y + gap
	return base_top + base_card_h + gap

func _get_normal_minimap_height() -> float:
	var target_bottom = 478.0
	return max(120.0, target_bottom - _get_normal_minimap_top_y())

func _get_normal_minimap_panel_size() -> Vector2:
	return Vector2(288.0, _get_normal_minimap_height())

func _get_normal_minimap_container_size() -> Vector2:
	return Vector2(284.0, _get_normal_minimap_height() - 4.0)

func _update_minimap_position() -> void:
	if _minimap_group == null or _minimap_panel == null or _distance_tracker_panel == null:
		return
	if _is_minimap_enlarged:
		return

	var top_y = _get_normal_minimap_top_y()
	var group_h = _get_normal_minimap_height()

	_minimap_group.position = Vector2(30.0, top_y)
	_minimap_group.custom_minimum_size = Vector2(0.0, group_h)
	_minimap_group.size = Vector2(_minimap_group.size.x, group_h)

	var panel_size = Vector2(288.0, group_h)
	var container_size = Vector2(284.0, group_h - 4.0)

	_minimap_panel.custom_minimum_size = panel_size
	_minimap_panel.size = panel_size

	if _minimap_container != null:
		_minimap_container.custom_minimum_size = container_size
		_minimap_container.size = container_size
		if not _minimap_container.stretch and _minimap_viewport != null:
			_minimap_viewport.size = Vector2i(284, int(container_size.y))
	elif _minimap_viewport != null:
		_minimap_viewport.size = Vector2i(284, int(container_size.y))

	_distance_tracker_panel.custom_minimum_size = Vector2(84.0, 0.0)



func _on_course_ball_graphic_changed(player_name: String, _ball_graphic: String) -> void:
	var cur_p = MultiplayerManager.get_active_player()
	if not cur_p.is_empty() and cur_p.get("name", "").to_lower() == player_name.to_lower():
		var player_node = course_instance.get_node_or_null("Player") if course_instance != null else null
		if player_node != null and player_node.has_method("set_profile"):
			player_node.set_profile(player_name)
		elif active_ball != null and active_ball.has_method("apply_ball_graphic"):
			var bg = MultiplayerManager.get_player_ball_graphic(player_name)
			var av = MultiplayerManager.get_player_avatar(player_name)
			var col = MultiplayerManager.get_player_color(cur_p)
			active_ball.apply_ball_graphic(bg, av, player_name, col)

func _get_tee_icon(tee_name: String, size: int = 14) -> ImageTexture:
	var key = "%s_%d" % [tee_name.strip_edges().to_lower(), size]
	if _tee_icon_cache.has(key):
		return _tee_icon_cache[key]
		
	var col = TeeboxMarkerBuilder.get_tee_color(tee_name)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size * 0.5, size * 0.5)
	var r = (size * 0.5) - 1.0
	for y in range(size):
		for x in range(size):
			var d = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= r - 1.0:
				img.set_pixel(x, y, col)
			elif d <= r:
				var border_col = Color(0.15, 0.15, 0.15, 0.9) if col.get_luminance() > 0.5 else Color(0.85, 0.85, 0.85, 0.8)
				img.set_pixel(x, y, border_col)
			elif d <= r + 0.75:
				var alpha = clamp(1.0 - (d - r), 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, alpha * 0.4))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex = ImageTexture.create_from_image(img)
	_tee_icon_cache[key] = tex
	return tex

func _on_player_tee_changed(_p_idx: int, p_name: String, new_tee: String) -> void:
	var active_p = MultiplayerManager.get_active_player()
	if not active_p.is_empty() and active_p.get("name", "").to_lower() == p_name.to_lower():
		if active_p.get("strokes", 0) == 0:
			if course_instance != null and course_instance.has_method("get_height"):
				var is_driver = MultiplayerManager.current_club.to_lower() in ["dr", "driver", "1w"]
				var offset_y = 0.059435 if is_driver else (GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET)
				active_p["position"].y = course_instance.get_height(active_p["position"].x, active_p["position"].z) + offset_y
				active_p["last_starting_pos"] = active_p["position"]
			if active_ball != null:
				active_ball.spawn_position = active_p["position"]
				active_ball.global_position = active_p["position"]
				active_ball.reset()
			var player_node_ref = course_instance.get_node_or_null("Player") if course_instance != null else null
			if player_node_ref != null and player_node_ref.get("_last_starting_pos") != null:
				player_node_ref._last_starting_pos = active_p["position"]
			if course_instance != null:
				if "current_hole_tee_dist_yards" in course_instance and course_instance.get("current_hole_location") != null:
					course_instance.current_hole_tee_dist_yards = int(active_p["position"].distance_to(course_instance.current_hole_location) * 1.09361)
				if course_instance.has_method("update_teebox_markers"):
					course_instance.call("update_teebox_markers", new_tee)
				course_instance.call("_update_hole_info_label", false)
				reset_zoom_to_default()
		_update_top_hud(active_p)
	_update_distance_queue()

func _on_active_player_changed(player: Dictionary) -> void:
	if player.is_empty():
		return

	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")

	var player_node_ref = course_instance.get_node_or_null("Player") if course_instance != null else null
	var p_name = str(player.get("name", ""))
	if player_node_ref != null and player_node_ref.has_method("set_profile") and not p_name.is_empty():
		player_node_ref.set_profile(p_name)
	elif active_ball != null and active_ball.has_method("apply_ball_graphic") and not p_name.is_empty():
		var bg = MultiplayerManager.get_player_ball_graphic(p_name) if MultiplayerManager != null and MultiplayerManager.has_method("get_player_ball_graphic") else player.get("ball_graphic", "single_line")
		var av = MultiplayerManager.get_player_avatar(p_name) if MultiplayerManager != null and MultiplayerManager.has_method("get_player_avatar") else player.get("avatar", "")
		var col = MultiplayerManager.get_player_color(player) if MultiplayerManager != null and MultiplayerManager.has_method("get_player_color") else player.get("color", Color(0.24, 0.46, 0.72))
		active_ball.apply_ball_graphic(bg, av, p_name, col)

	if MultiplayerManager.hole_ids.is_empty():
		return
		
	_clear_map_markers()
		
	var hole_idx = clamp(MultiplayerManager.current_hole_index, 0, MultiplayerManager.hole_ids.size() - 1)
	var hole_id = MultiplayerManager.hole_ids[hole_idx]
	var active_hole = MultiplayerManager.hole_info.get(hole_id, {})
	_update_top_hud(player)

	if range_ui != null:
		var club_sel = range_ui.find_child("ClubSelector", true, false)
		if club_sel != null and club_sel.has_method("update_bag_for_player"):
			club_sel.update_bag_for_player(player.get("name", ""))

	
	var is_new_hole: bool = false
	if course_instance != null:
		if "_aim_is_manual" in course_instance:
			course_instance.set("_aim_is_manual", false)
		var hole_name = active_hole.get("Name", hole_id)
		is_new_hole = (_last_loaded_hole_id != hole_id) or (_last_loaded_hole_index != hole_idx) or (course_instance.get("current_hole_location") != null and course_instance.current_hole_location.is_zero_approx())
		
		if is_new_hole:
			_last_loaded_hole_id = hole_id
			_last_loaded_hole_index = hole_idx
			if "current_hole_id" in course_instance:
				course_instance.current_hole_id = hole_id
			course_instance.current_hole_name = hole_name
			course_instance.current_hole_par = int(round(float(active_hole.get("Par", 4))))
			var hole_loc = active_hole.get("Hole Location")
			if hole_loc != null:
				if course_instance.has_method("get_hole_location_for"):
					course_instance.current_hole_location = course_instance.get_hole_location_for(hole_loc)
				else:
					course_instance.current_hole_location = Vector3(hole_loc[0], course_instance.get_height(hole_loc[0], hole_loc[1]), hole_loc[1])
				MultiplayerManager.current_pin_position = course_instance.current_hole_location
				course_instance.aim_target_pos = Vector3.ZERO
				
				if course_instance.has_node("PinMarker"):
					course_instance.get_node("PinMarker").global_position = course_instance.current_hole_location
					course_instance.get_node("PinMarker").visible = true
				
				var flag_pin = course_instance.get_node_or_null("FlagPin")
				if flag_pin != null and not flag_pin.is_queued_for_deletion():
					flag_pin.global_position = course_instance.current_hole_location
					var active_cup_r = float(course_instance.cup_radius) if "cup_radius" in course_instance else 0.054
					FlagBuilder.sync_hole_cutout_to_terrain(course_instance, course_instance.current_hole_location, active_cup_r)
					if course_instance.has_method("update_gimme_circles"):
						course_instance.update_gimme_circles()
				elif course_instance.has_method("_spawn_flag_pin"):
					course_instance.call("_spawn_flag_pin")
		else:
			if "current_hole_id" in course_instance and str(course_instance.current_hole_id).is_empty():
				course_instance.current_hole_id = hole_id
			course_instance.current_hole_name = hole_name
			course_instance.current_hole_par = int(round(float(active_hole.get("Par", 4))))
				
		# Update tee-off distance
		if player.get("strokes", 0) == 0 and course_instance != null and course_instance.has_method("get_height"):
			var is_driver = MultiplayerManager.current_club.to_lower() in ["dr", "driver", "1w"]
			var offset_y = 0.059435 if is_driver else (GolfBall.GROUND_CENTER_HEIGHT + GolfBall.GROUND_SNAP_OFFSET)
			player["position"].y = course_instance.get_height(player["position"].x, player["position"].z) + offset_y
		var spawn_pos = player["position"]
		course_instance.current_hole_tee_dist_yards = int(spawn_pos.distance_to(course_instance.current_hole_location) * 1.09361)
		
		# Reset camera user offset when moving to a new hole or if starting hole
		if player["strokes"] == 0:
			course_instance.aerial_cam_user_offset = Vector3.ZERO
			reset_zoom_to_default()
		else:
			_last_zoom_zone = -1

	if player_node_ref == null and course_instance != null:
		player_node_ref = course_instance.get_node_or_null("Player")
	if active_ball != null:
		var is_practice = course_instance != null and course_instance.get("practice_mode_active")
		var is_multiplayer = MultiplayerManager.players.size() > 1
		var should_initialize = true
		if is_practice and not is_multiplayer and player.get("strokes", 0) > 0:
			should_initialize = false
			
		if should_initialize:
			var initial_lie = player.get("lie_type", "teebox" if player.get("strokes", 0) == 0 else "fairway")
			active_ball.spawn_position = player["position"]
			active_ball.lie_type = initial_lie
			if player_node_ref != null:
				player_node_ref.current_lie_type = initial_lie
				if player_node_ref.get("_last_starting_pos") != null:
					var player_start_pos = player.get("position", Vector3.ZERO)
					if typeof(player_start_pos) == TYPE_VECTOR3:
						player_node_ref._last_starting_pos = player_start_pos
			active_ball.reset()
			
			# Recalculate lie immediately after teleporting/resetting
			if course_instance != null and course_instance.has_method("update_current_lie_and_reduction"):
				course_instance.call("update_current_lie_and_reduction")
			if player_node_ref != null:
				player_node_ref.current_lie_type = active_ball.lie_type

	if course_instance != null:
		# Update labels and outline with the ball now properly positioned at the hole/tee
		course_instance.call("_update_hole_info_label", player["strokes"] > 0)
		if is_new_hole:
			course_instance.call("update_hole_outline")
		if course_instance.has_method("update_teebox_markers"):
			course_instance.call("update_teebox_markers", player.get("tee", "Blue"))

	if active_ball != null:
		var is_practice = course_instance != null and course_instance.get("practice_mode_active")
		var is_multiplayer = MultiplayerManager.players.size() > 1
		var should_initialize = true
		if is_practice and not is_multiplayer and player.get("strokes", 0) > 0:
			should_initialize = false

		if should_initialize:
			if course_instance != null and course_instance.has_method("update_auto_club"):
				course_instance.call("update_auto_club", true)
			
			# Move camera target to focus on the active ball
			var camera = course_instance.get_node_or_null("PhantomCamera3D") if course_instance != null else null
			if camera != null:
				var cam_target = player_node_ref.get_camera_target() if player_node_ref != null and player_node_ref.has_method("get_camera_target") else active_ball
				camera.follow_target = cam_target
				var pcam_host = course_instance.get_node_or_null("Camera3D/PhantomCameraHost")
				if pcam_host != null:
					pcam_host.interpolation_mode = 1  # InterpolationMode.IDLE
				var cam_3d = course_instance.get_node_or_null("Camera3D")
				if cam_3d != null:
					cam_3d.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
				
			# Automatically set default aim and position/rotate the camera behind the ball
			if course_instance != null:
				var is_putting = is_default_club_putter() or is_player_on_green() or is_player_on_fringe()
				var target_aim = course_instance.get("aim_target_pos")
				if is_putting and course_instance.get("current_hole_location") != null:
					target_aim = course_instance.get("current_hole_location")
				elif GlobalSettings.is_chipping_minigame and target_aim != null and not target_aim.is_zero_approx():
					pass
				elif course_instance.has_method("apply_default_aim"):
					var sel_club = MultiplayerManager.current_club if "current_club" in MultiplayerManager else ""
					target_aim = course_instance.call("apply_default_aim", sel_club)
				else:
					target_aim = course_instance.get("current_hole_location")
				if GlobalSettings.is_chipping_minigame and course_instance.get("aim_target_pos") != null:
					target_aim = course_instance.get("aim_target_pos")
				if target_aim != null and not target_aim.is_zero_approx():
					var ball_pos = active_ball.global_position
					var diff = target_aim - ball_pos
					if course_instance.get("current_hole_location") != null and not (course_instance.current_hole_location as Vector3).is_zero_approx():
						var to_hole: Vector3 = (course_instance.current_hole_location as Vector3) - ball_pos
						if Vector2(diff.x, diff.z).normalized().dot(Vector2(to_hole.x, to_hole.z).normalized()) < 0.0:
							diff = to_hole
							target_aim = course_instance.current_hole_location
					var angle_rad = atan2(diff.z, diff.x)
					active_ball.aim_yaw_offset_deg = rad_to_deg(-angle_rad)
					course_instance.aim_target_pos = target_aim
					if course_instance.has_node("AimMarker"):
						course_instance.get_node("AimMarker").global_position = target_aim
					if course_instance.has_method("set_aim_distance"):
						course_instance.call("set_aim_distance", int(ball_pos.distance_to(target_aim) * 1.09361))
					
					# Position the camera behind the ball facing the target aim
					if camera != null:
						camera.follow_mode = PhantomCamera3D.FollowMode.NONE
						camera.look_at_mode = PhantomCamera3D.LookAtMode.NONE
						var cam_pos: Vector3
						if course_instance != null and course_instance.has_method("get_address_camera_position"):
							cam_pos = course_instance.call("get_address_camera_position", ball_pos, -angle_rad, is_putting)
						else:
							var cam_dist = GlobalSettings.range_settings.camera_distance.value
							var cam_height = GlobalSettings.range_settings.camera_height.value
							var local_offset = Vector3(-1.35, 0.8, 0) if is_putting else Vector3(-cam_dist, cam_height, 0)
							if course_instance != null and course_instance.has_method("get_camera_local_offset"):
								local_offset = course_instance.call("get_camera_local_offset", is_putting)
							var rotated_offset = local_offset.rotated(Vector3.UP, -angle_rad)
							cam_pos = ball_pos + rotated_offset
						if course_instance != null and course_instance.has_method("clamp_camera_position"):
							cam_pos = course_instance.call("clamp_camera_position", cam_pos)
						elif course_instance != null and course_instance.has_method("get_height"):
							var min_y = course_instance.call("get_height", cam_pos.x, cam_pos.z) + 0.35
							if cam_pos.y < min_y:
								cam_pos.y = min_y
						camera.global_position = cam_pos
						
						var target_look: Vector3
						if course_instance.has_method("get_camera_target_look"):
							target_look = course_instance.call("get_camera_target_look", target_aim, ball_pos, is_putting)
						elif is_putting:
							var dist = ball_pos.distance_to(target_aim)
							var look_dist = clamp(dist * 0.4, 2.0, 6.0)
							if dist < 2.0:
								look_dist = dist
							var fraction = clamp(look_dist / max(dist, 0.001), 0.0, 1.0)
							target_look = ball_pos.lerp(target_aim, fraction)
						else:
							var dist = ball_pos.distance_to(target_aim) if not target_aim.is_zero_approx() else 50.0
							var aim_dir = (target_aim - ball_pos).normalized() if not target_aim.is_zero_approx() else Vector3.ZERO
							if aim_dir.is_zero_approx():
								aim_dir = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(active_ball.aim_yaw_offset_deg))
							var look_dist = clampf(dist, 10.0, 50.0)
							var t = clampf(look_dist / maxf(dist, 0.001), 0.0, 1.0)
							var base_look_pos = ball_pos.lerp(target_aim, t) if not target_aim.is_zero_approx() else (ball_pos + aim_dir * 50.0)
							target_look = base_look_pos + Vector3.UP * 1.0
						camera.look_at(target_look)
						if camera.camera_3d_resource != null:
							camera.camera_3d_resource.fov = GlobalSettings.range_settings.camera_fov.value
						
						var cam3d = course_instance.get_node_or_null("Camera3D")
						if cam3d != null:
							cam3d.global_position = cam_pos
							cam3d.look_at(target_look)
							cam3d.fov = GlobalSettings.range_settings.camera_fov.value
			
		# Clear tracer trails so the player has a clean view for their next shot
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			player_node.call("reset_shot_data")
			player_node.call("clear_tracers")

		if course_instance != null and course_instance.has_method("update_auto_club"):
			course_instance.call("update_auto_club", true)

		# Evaluate if the active player's default club is putter (e.g. on green or on fringe within putting distance)
		var is_default_putter = is_default_club_putter()

		if has_node("/root/ScreenOffsetManager") and course_instance != null:
			var som = get_node("/root/ScreenOffsetManager")
			var cam_to_register = course_instance.get_node_or_null("PhantomCamera3D")
			if cam_to_register == null:
				cam_to_register = course_instance.get_node_or_null("Camera3D")
			if cam_to_register != null:
				som.call("register_camera", cam_to_register)
			som.call("set_putter_active", is_default_putter)
			som.call("on_ready_for_shot")

		# Synchronize green grid view strictly for the active player
		if course_instance != null and "show_green_grid" in course_instance:
			course_instance.show_green_grid = is_default_putter
			_update_grid_button_state(is_default_putter)

		# Recalculate zoom zone and minimap zoom for the newly active player
		_minimap_zoom_dirty = true
		var new_zone = get_current_zoom_zone()
		var target_zoom = get_zoom_for_zone(new_zone)
		minimap_zoom = target_zoom
		_last_zoom_zone = new_zone
		_last_was_on_green = is_default_putter
		if _minimap_camera != null:
			_minimap_camera.size = minimap_zoom
		if course_instance != null and "aerial_zoom" in course_instance:
			course_instance.aerial_zoom = target_zoom
			var aerial_cam = course_instance.get_node_or_null("AerialCamera")
			if aerial_cam != null:
				aerial_cam.size = target_zoom

		_update_minimap()

	if not player.get("holed_out", false):
		is_player_turn_ready = true
		if has_node("/root/LaunchMonitorManager"):
			var lm = get_node("/root/LaunchMonitorManager")
			if lm != null and lm.has_method("set_ready") and not lm.get("is_ready"):
				lm.call("set_ready")

	# Trigger hole intro card slide-in once per hole at hole start
	var is_hole_start = (_last_hole_card_hole_index != hole_idx or _last_hole_card_hole_id != hole_id)
	if is_hole_start and not MultiplayerManager.hole_ids.is_empty():
		_last_hole_card_hole_index = hole_idx
		_last_hole_card_hole_id = hole_id
		var dist = _get_distance_to_hole_for_player(player, hole_id)
		var hole_name = active_hole.get("Name", "")
		var course_name = ""
		if course_instance != null and "course_name" in course_instance and not str(course_instance.course_name).is_empty():
			course_name = str(course_instance.course_name)
		var hole_num = MultiplayerManager.get_hole_number(hole_idx)
		var hole_par = int(round(float(active_hole.get("Par", 4))))
		_show_hole_intro_card(hole_num, hole_par, dist, course_name, hole_name)


func _get_distance_to_hole_for_player(p: Dictionary, hole_id: String) -> int:
	if course_instance != null and "current_hole_tee_dist_yards" in course_instance and course_instance.current_hole_tee_dist_yards > 0:
		return int(course_instance.current_hole_tee_dist_yards)
	if course_instance != null and course_instance.get("current_hole_location") != null and not course_instance.current_hole_location.is_zero_approx() and p.has("position"):
		var p_pos = Vector3(p["position"].x, 0.0, p["position"].z)
		var h_pos = Vector3(course_instance.current_hole_location.x, 0.0, course_instance.current_hole_location.z)
		var d = int(round(p_pos.distance_to(h_pos) * 1.09361))
		if d > 0:
			return d
	var tee_col = p.get("tee", "Blue")
	var hole_dist = _get_hole_distance(hole_id, tee_col)
	if hole_dist > 0:
		return hole_dist
	return 0


func _show_hole_intro_card(hole_num: int, par: int, dist: int, course_title: String = "", hole_name: String = "") -> void:
	if hole_intro_card == null:
		return
	
	if _hole_card_hole_lbl != null:
		_hole_card_hole_lbl.text = str(hole_num)
	if _hole_card_par_lbl != null:
		_hole_card_par_lbl.text = str(par)
	if _hole_card_dist_lbl != null:
		_hole_card_dist_lbl.text = str(dist) if dist > 0 else "---"
		
	if _hole_card_header_lbl != null:
		var header_text = ""
		var clean_hole_name = hole_name.strip_edges()
		var clean_course_name = course_title.strip_edges()
		var is_generic_hole_name = clean_hole_name.is_empty() or clean_hole_name.to_lower() == ("hole %d" % hole_num).to_lower() or clean_hole_name.to_lower() == ("hole%d" % hole_num).to_lower()
		
		if not clean_course_name.is_empty() and not is_generic_hole_name:
			header_text = "%s  •  %s" % [clean_course_name, clean_hole_name]
		elif not clean_course_name.is_empty():
			header_text = clean_course_name
		elif not is_generic_hole_name:
			header_text = clean_hole_name
			
		if not header_text.is_empty():
			_hole_card_header_lbl.text = header_text.to_upper()
			_hole_card_header_lbl.visible = true
		else:
			_hole_card_header_lbl.visible = false

	if _hole_card_tween != null and _hole_card_tween.is_valid():
		_hole_card_tween.kill()

	var vp_w = 1920.0
	if hole_intro_card.get_viewport() != null:
		var vp_rect = hole_intro_card.get_viewport_rect()
		if vp_rect.size.x > 100.0:
			vp_w = vp_rect.size.x

	var half_card_w = 210.0
	var offscreen_left_offset = -(vp_w * 0.5) - 350.0
	var offscreen_right_offset = (vp_w * 0.5) + 350.0

	var entrance_left = offscreen_left_offset - half_card_w
	var entrance_right = offscreen_left_offset + half_card_w
	var exit_left = offscreen_right_offset - half_card_w
	var exit_right = offscreen_right_offset + half_card_w
	var onscreen_left = -half_card_w
	var onscreen_right = half_card_w

	hole_intro_card.visible = true
	hole_intro_card.modulate = Color(1, 1, 1, 0)
	hole_intro_card.offset_left = entrance_left
	hole_intro_card.offset_right = entrance_right

	_hole_card_tween = create_tween()
	# Optional initial settle delay
	_hole_card_tween.tween_interval(0.35)

	# Phase 1: Slide in from the LEFT into the middle of the screen (1.5 seconds)
	_hole_card_tween.tween_property(hole_intro_card, "offset_left", onscreen_left, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hole_card_tween.parallel().tween_property(hole_intro_card, "offset_right", onscreen_right, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hole_card_tween.parallel().tween_property(hole_intro_card, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 2: Dwell in the middle of the screen for 2.5 seconds so the player can comfortably read it
	_hole_card_tween.tween_interval(2.5)

	# Phase 3: Slide out to the RIGHT (1.5 seconds)
	_hole_card_tween.tween_property(hole_intro_card, "offset_left", exit_left, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_hole_card_tween.parallel().tween_property(hole_intro_card, "offset_right", exit_right, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_hole_card_tween.parallel().tween_property(hole_intro_card, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Hide upon completion
	_hole_card_tween.tween_callback(func():
		if is_instance_valid(hole_intro_card):
			hole_intro_card.visible = false
		if has_node("/root/AnnouncerEngine"):
			get_node("/root/AnnouncerEngine").call("ResetIdleTimer")
	)


func _dismiss_hole_intro_card_early() -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")
	if hole_intro_card == null or not hole_intro_card.visible:
		return
	if _hole_card_tween != null and _hole_card_tween.is_valid():
		_hole_card_tween.kill()

	var vp_w = 1920.0
	if hole_intro_card.get_viewport() != null:
		var vp_rect = hole_intro_card.get_viewport_rect()
		if vp_rect.size.x > 100.0:
			vp_w = vp_rect.size.x
	var half_card_w = 210.0
	var offscreen_right_offset = (vp_w * 0.5) + 350.0
	var exit_left = offscreen_right_offset - half_card_w
	var exit_right = offscreen_right_offset + half_card_w

	_hole_card_tween = create_tween()
	_hole_card_tween.set_parallel(true)
	_hole_card_tween.tween_property(hole_intro_card, "offset_left", exit_left, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_hole_card_tween.tween_property(hole_intro_card, "offset_right", exit_right, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_hole_card_tween.tween_property(hole_intro_card, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hole_card_tween.chain().tween_callback(func():
		if is_instance_valid(hole_intro_card):
			hole_intro_card.visible = false
	)




func _on_mulligan_pressed() -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("SpeakMulliganHeckle")
	if forfeit_confirm_dialog != null:
		forfeit_confirm_dialog.visible = false
	if mulligan_confirm_dialog == null:
		return
		
	# Clear existing children of the dialog
	for child in mulligan_confirm_dialog.get_children():
		mulligan_confirm_dialog.remove_child(child)
		child.queue_free()
		
	# Build the dialog content dynamically
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 18)
	
	var target_idx = MultiplayerManager.get_mulligan_target_player_index()
	if target_idx < 0 or target_idx >= MultiplayerManager.players.size():
		return
	var target_player = MultiplayerManager.players[target_idx]
	if target_player.is_empty():
		return
		
	var player_node = course_instance.get_node_or_null("Player") if course_instance != null else null
	var last_start_pos = Vector3.ZERO
	if not MultiplayerManager.last_shot_info.is_empty() and MultiplayerManager.last_shot_info.has("start_pos"):
		last_start_pos = MultiplayerManager.last_shot_info["start_pos"]
	elif target_player.has("last_starting_pos") and typeof(target_player["last_starting_pos"]) == TYPE_VECTOR3 and not target_player["last_starting_pos"].is_zero_approx():
		last_start_pos = target_player["last_starting_pos"]
	elif player_node != null and player_node.get("_last_starting_pos") != null:
		last_start_pos = player_node.get("_last_starting_pos")
		
	var hole_idx = clamp(MultiplayerManager.current_hole_index, 0, MultiplayerManager.hole_ids.size() - 1) if not MultiplayerManager.hole_ids.is_empty() else 0
	var hole_id = MultiplayerManager.hole_ids[hole_idx] if not MultiplayerManager.hole_ids.is_empty() else "Hole 1"
	
	var matching_mulligans = []
	if target_player.has("mulligan_history") and typeof(target_player["mulligan_history"]) == TYPE_DICTIONARY:
		if target_player["mulligan_history"].has(hole_id) and typeof(target_player["mulligan_history"][hole_id]) == TYPE_ARRAY:
			for entry in target_player["mulligan_history"][hole_id]:
				if entry.has("start_pos") and typeof(entry["start_pos"]) == TYPE_VECTOR3:
					# Match starting positions within 0.5 meters
					if entry["start_pos"].distance_to(last_start_pos) < 0.5:
						matching_mulligans.append(entry)
						
	var is_multi = MultiplayerManager.players.size() > 1
	var p_name = target_player.get("name", "Player")

	# Setup title
	var title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.46, 0.72, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 4)
	content_vbox.add_child(title_lbl)
	
	var msg_lbl = Label.new()
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_font_size_override("font_size", 18)
	msg_lbl.add_theme_color_override("font_color", Color.WHITE)
	msg_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_lbl.add_theme_constant_override("outline_size", 4)
	content_vbox.add_child(msg_lbl)
	
	if matching_mulligans.is_empty():
		# Standard confirmation flow
		_mulligan_is_selection_mode = false
		_mulligan_confirm_btn = null
		_mulligan_cancel_btn = null
		_mulligan_new_shot_btn = null
		_mulligan_option_buttons.clear()
		_mulligan_matching_entries.clear()
		_mulligan_scroll = null
		_mulligan_selected_idx = 0

		title_lbl.text = "Confirm Mulligan" if not is_multi else "Confirm Mulligan: %s" % p_name
		msg_lbl.text = "Are you sure you want to take a mulligan?\nThis will undo your last shot." if not is_multi else "Are you sure you want to take a mulligan for %s?\nThis will undo their last shot." % p_name
		
		var btn_hbox = HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 24)
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var confirm_btn = Button.new()
		confirm_btn.name = "ConfirmBtn"
		confirm_btn.text = "Yes, Undo"
		confirm_btn.custom_minimum_size = Vector2(170, 52)
		confirm_btn.add_theme_font_size_override("font_size", 18)
		apply_material_button_style(confirm_btn, Color(0.24, 0.46, 0.72, 0.85))
		confirm_btn.pressed.connect(func():
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
				UIFocusGuard.pop_lock(false)
			mulligan_confirm_dialog.visible = false
			_on_mulligan_confirmed()
		)
		btn_hbox.add_child(confirm_btn)
		_mulligan_confirm_btn = confirm_btn
		
		var cancel_btn = Button.new()
		cancel_btn.name = "CancelBtn"
		cancel_btn.text = "Cancel"
		cancel_btn.custom_minimum_size = Vector2(170, 52)
		cancel_btn.add_theme_font_size_override("font_size", 18)
		apply_material_button_style(cancel_btn, Color(0.56, 0.22, 0.22, 0.85))
		cancel_btn.pressed.connect(func():
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == mulligan_confirm_dialog:
				UIFocusGuard.pop_lock(false)
			mulligan_confirm_dialog.visible = false
		)
		btn_hbox.add_child(cancel_btn)
		_mulligan_cancel_btn = cancel_btn
		confirm_btn.focus_neighbor_right = confirm_btn.get_path_to(cancel_btn)
		cancel_btn.focus_neighbor_left = cancel_btn.get_path_to(confirm_btn)
		content_vbox.add_child(btn_hbox)
		
		mulligan_confirm_dialog.offset_left = -280
		mulligan_confirm_dialog.offset_right = 280
		mulligan_confirm_dialog.offset_top = -135
		mulligan_confirm_dialog.offset_bottom = 135
	else:
		# Selection flow
		_mulligan_is_selection_mode = true
		_mulligan_option_buttons.clear()
		_mulligan_matching_entries = matching_mulligans
		_mulligan_selected_idx = 0
		_mulligan_confirm_btn = null

		title_lbl.text = "Mulligan Selection" if not is_multi else "Mulligan Selection: %s" % p_name
		msg_lbl.text = "Select an option for your mulligan from this spot:" if not is_multi else "Select an option for %s's mulligan from this spot:" % p_name
		
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(500, 300)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		ThemeManager.apply_scroll_container_style(scroll, 24)
		content_vbox.add_child(scroll)
		_mulligan_scroll = scroll
		
		var scroll_margin = MarginContainer.new()
		scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_margin.add_theme_constant_override("margin_right", 24)
		scroll_margin.add_theme_constant_override("margin_left", 4)
		scroll_margin.add_theme_constant_override("margin_top", 4)
		scroll_margin.add_theme_constant_override("margin_bottom", 4)
		scroll.add_child(scroll_margin)
		
		var list_vbox = VBoxContainer.new()
		list_vbox.add_theme_constant_override("separation", 10)
		list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_margin.add_child(list_vbox)
		
		var new_mulligan_btn = Button.new()
		new_mulligan_btn.text = "Take Another Mulligan (New Shot)"
		new_mulligan_btn.custom_minimum_size = Vector2(0, 52)
		new_mulligan_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_mulligan_btn.add_theme_font_size_override("font_size", 18)
		new_mulligan_btn.pressed.connect(func():
			mulligan_confirm_dialog.visible = false
			_on_mulligan_confirmed()
		)
		new_mulligan_btn.mouse_entered.connect(func():
			_mulligan_selected_idx = 0
			_update_mulligan_selection_highlight()
		)
		list_vbox.add_child(new_mulligan_btn)
		_mulligan_new_shot_btn = new_mulligan_btn
		_mulligan_option_buttons.append(new_mulligan_btn)
		
		var sep_lbl = Label.new()
		sep_lbl.text = "--- Keep a Previous Shot ---"
		sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep_lbl.add_theme_font_size_override("font_size", 15)
		sep_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		list_vbox.add_child(sep_lbl)
		
		for i in range(matching_mulligans.size()):
			var entry = matching_mulligans[i]
			var stats = entry.get("shot_stats", {})
			var club = entry.get("club", "Dr")
			var dist = stats.get("total_yds", 0.0)
			var lie = entry.get("lie_type", "fairway")
			
			var btn_text = "Restore Shot %d: %s | %.0f yds (%s)" % [i + 1, club, dist, lie.capitalize()]
			var opt_btn = Button.new()
			opt_btn.text = btn_text
			opt_btn.custom_minimum_size = Vector2(0, 48)
			opt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt_btn.add_theme_font_size_override("font_size", 17)
			opt_btn.pressed.connect(func():
				mulligan_confirm_dialog.visible = false
				_on_previous_mulligan_selected(entry)
			)
			var cur_idx = i + 1
			opt_btn.mouse_entered.connect(func():
				_mulligan_selected_idx = cur_idx
				_update_mulligan_selection_highlight()
			)
			list_vbox.add_child(opt_btn)
			_mulligan_option_buttons.append(opt_btn)
			
		var cancel_btn = Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.custom_minimum_size = Vector2(0, 48)
		cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel_btn.add_theme_font_size_override("font_size", 17)
		apply_material_button_style(cancel_btn, Color(0.56, 0.22, 0.22, 0.85))
		cancel_btn.pressed.connect(func():
			mulligan_confirm_dialog.visible = false
		)
		list_vbox.add_child(cancel_btn)
		_mulligan_cancel_btn = cancel_btn
		
		mulligan_confirm_dialog.offset_left = -290
		mulligan_confirm_dialog.offset_right = 290
		mulligan_confirm_dialog.offset_top = -250
		mulligan_confirm_dialog.offset_bottom = 250

		_update_mulligan_selection_highlight()
		
	mulligan_confirm_dialog.add_child(content_vbox)
	mulligan_confirm_dialog.visible = true
	UIFocusGuard.push_lock(mulligan_confirm_dialog)
	if _mulligan_is_selection_mode:
		var m_cancel = mulligan_confirm_dialog.find_child("CancelBtn", true, false) as Button
		if m_cancel != null:
			m_cancel.call_deferred("grab_focus")
	else:
		if _mulligan_confirm_btn != null:
			_mulligan_confirm_btn.call_deferred("grab_focus")


func _on_mulligan_confirmed() -> void:
	if course_instance != null and course_instance.has_method("cancel_pending_shot_transition"):
		course_instance.call("cancel_pending_shot_transition")

	var player_node = course_instance.get_node_or_null("Player")
	if player_node != null:
		var target_idx = MultiplayerManager.get_mulligan_target_player_index()
		if target_idx < 0 or target_idx >= MultiplayerManager.players.size():
			return
		var target_player = MultiplayerManager.players[target_idx]
		if target_player.is_empty():
			return

		var hole_idx = clamp(MultiplayerManager.current_hole_index, 0, MultiplayerManager.hole_ids.size() - 1) if not MultiplayerManager.hole_ids.is_empty() else 0
		var hole_id = MultiplayerManager.hole_ids[hole_idx] if not MultiplayerManager.hole_ids.is_empty() else "Hole 1"
		
		# Determine starting pos and details of the shot being undone
		var last_start_pos = Vector3.ZERO
		var current_ball_pos = target_player.get("position", Vector3.ZERO)
		var last_aim_target = Vector3.ZERO
		var last_aim_yaw = 0.0
		var shot_club = MultiplayerManager.current_club
		var shot_lie = target_player.get("lie_type", "fairway")
		var shot_reduction = target_player.get("shot_reduction", 0.0)
		var shot_penalty = target_player.get("last_shot_penalty", 0)
		var tracer_pts = []
		var current_stats = {}

		if not MultiplayerManager.last_shot_info.is_empty() and MultiplayerManager.last_shot_info.get("player_index", -1) == target_idx:
			var info = MultiplayerManager.last_shot_info
			last_start_pos = info.get("start_pos", Vector3.ZERO)
			current_ball_pos = info.get("end_pos", current_ball_pos)
			last_aim_target = info.get("aim_target_pos", Vector3.ZERO)
			last_aim_yaw = info.get("aim_yaw_offset_deg", 0.0)
			shot_club = info.get("club", shot_club)
			shot_lie = info.get("lie_type", shot_lie)
			shot_reduction = info.get("shot_reduction", shot_reduction)
			shot_penalty = info.get("last_shot_penalty", shot_penalty)
			tracer_pts = info.get("tracer_points", [])
			current_stats = info.get("stat_entry", {})
		else:
			if target_player.has("last_starting_pos") and typeof(target_player["last_starting_pos"]) == TYPE_VECTOR3 and not target_player["last_starting_pos"].is_zero_approx():
				last_start_pos = target_player["last_starting_pos"]
			elif player_node.get("_last_starting_pos") != null:
				last_start_pos = player_node.get("_last_starting_pos")
			last_aim_target = target_player.get("last_aim_target_pos", Vector3.ZERO)
			last_aim_yaw = target_player.get("last_aim_yaw_offset_deg", 0.0)
			if target_player.has("shot_stats") and typeof(target_player["shot_stats"]) == TYPE_DICTIONARY and target_player["shot_stats"].has(hole_id) and not target_player["shot_stats"][hole_id].is_empty():
				current_stats = target_player["shot_stats"][hole_id].back()
			var tracers_list = player_node.get("tracers")
			if tracers_list != null and not tracers_list.is_empty():
				var last_t = tracers_list.back()
				if is_instance_valid(last_t) and "points" in last_t:
					tracer_pts = last_t.points.duplicate()
			
		var course_shot_data = {}
		if course_instance != null and "shot_history" in course_instance and not course_instance.shot_history.is_empty():
			course_shot_data = course_instance.shot_history.back()
			
		var shot_entry = {
			"start_pos": last_start_pos,
			"end_pos": current_ball_pos,
			"club": shot_club,
			"lie_type": shot_lie,
			"shot_reduction": shot_reduction,
			"last_shot_penalty": shot_penalty,
			"shot_stats": current_stats,
			"course_shot_data": course_shot_data,
			"tracer_points": tracer_pts,
			"aim_target_pos": last_aim_target,
			"aim_yaw_offset_deg": last_aim_yaw
		}
		
		if not target_player.has("mulligan_history") or typeof(target_player["mulligan_history"]) != TYPE_DICTIONARY:
			target_player["mulligan_history"] = {}
		if not target_player["mulligan_history"].has(hole_id):
			target_player["mulligan_history"][hole_id] = []
		target_player["mulligan_history"][hole_id].append(shot_entry)
		
		# Reset detailed tracer points for target shot since we just mulliganed it
		target_player["last_shot_tracer_points"] = []
		
		player_node.call("mulligan")
		player_node.set("_last_starting_pos", last_start_pos)
		
		if range_ui != null and range_ui.has_method("on_next_shot_started"):
			range_ui.call("on_next_shot_started")
		if course_instance.has_method("remove_last_shot"):
			course_instance.call("remove_last_shot")
		
		# Update target player data in MultiplayerManager
		target_player["position"] = last_start_pos
		var penalty = shot_penalty
		var strokes_to_remove = 1 + penalty
		target_player["strokes"] = max(0, target_player["strokes"] - strokes_to_remove)
		target_player["total_strokes"] = max(0, target_player["total_strokes"] - strokes_to_remove)
		target_player["last_shot_penalty"] = 0
		target_player["last_shot_distance_yards"] = -1.0
		target_player["holed_out"] = false
		if not target_player["shot_history"].is_empty():
			target_player["shot_history"].pop_back()
			
		if not MultiplayerManager.hole_ids.is_empty():
			target_player["hole_scores"][hole_id] = target_player["strokes"]
			if target_player.has("shot_stats"):
				if typeof(target_player["shot_stats"]) == TYPE_DICTIONARY:
					if target_player["shot_stats"].has(hole_id) and not target_player["shot_stats"][hole_id].is_empty():
						target_player["shot_stats"][hole_id].pop_back()
				elif typeof(target_player["shot_stats"]) == TYPE_ARRAY and not target_player["shot_stats"].is_empty():
					target_player["shot_stats"].pop_back()
			
		# Clear last shot tracking now that it has been mulliganed
		MultiplayerManager.clear_last_shot()

		# Revert active player turn to target player so they can take their redo
		MultiplayerManager.active_player_index = target_idx
		MultiplayerManager.emit_signal("active_player_changed", target_player)

		if course_instance != null and course_instance.has_method("update_current_lie_and_reduction"):
			course_instance.call("update_current_lie_and_reduction")
			
		# Retain previous shot's aim target and camera look
		if last_aim_target != null and last_aim_target != Vector3.ZERO:
			if course_instance != null and course_instance.has_method("set_aim_target"):
				course_instance.call("set_aim_target", last_aim_target, true)
			if player_node != null:
				player_node.set("_last_aim_target_pos", last_aim_target)
				player_node.set("_last_aim_yaw_offset_deg", last_aim_yaw)
			target_player["last_aim_target_pos"] = last_aim_target
			target_player["last_aim_yaw_offset_deg"] = last_aim_yaw
			
		MultiplayerManager.save_current_match()


func _on_previous_mulligan_selected(prev_shot: Dictionary) -> void:
	if course_instance != null and course_instance.has_method("cancel_pending_shot_transition"):
		course_instance.call("cancel_pending_shot_transition")

	var player_node = course_instance.get_node_or_null("Player")
	if player_node != null:
		var target_idx = MultiplayerManager.get_mulligan_target_player_index()
		if target_idx < 0 or target_idx >= MultiplayerManager.players.size():
			return
		var target_player = MultiplayerManager.players[target_idx]
		if target_player.is_empty():
			return
		var hole_idx = clamp(MultiplayerManager.current_hole_index, 0, MultiplayerManager.hole_ids.size() - 1) if not MultiplayerManager.hole_ids.is_empty() else 0
		var hole_id = MultiplayerManager.hole_ids[hole_idx] if not MultiplayerManager.hole_ids.is_empty() else "Hole 1"
		
		# 1. Capture current shot and put it in mulligan history
		var last_start_pos = player_node.get("_last_starting_pos")
		var current_ball_pos = target_player.get("position", Vector3.ZERO)
		var last_aim_target = player_node.get("_last_aim_target_pos")
		if last_aim_target == null or last_aim_target == Vector3.ZERO:
			if target_player.has("last_aim_target_pos") and typeof(target_player["last_aim_target_pos"]) == TYPE_VECTOR3:
				last_aim_target = target_player["last_aim_target_pos"]
			elif course_instance != null and "aim_target_pos" in course_instance:
				last_aim_target = course_instance.aim_target_pos
		var last_aim_yaw = player_node.get("_last_aim_yaw_offset_deg")
		if last_aim_yaw == null:
			last_aim_yaw = target_player.get("last_aim_yaw_offset_deg", 0.0)
			
		var current_stats = {}
		if target_player.has("shot_stats") and typeof(target_player["shot_stats"]) == TYPE_DICTIONARY and target_player["shot_stats"].has(hole_id) and not target_player["shot_stats"][hole_id].is_empty():
			current_stats = target_player["shot_stats"][hole_id].back()
			
		var course_shot_data = {}
		if course_instance != null and "shot_history" in course_instance and not course_instance.shot_history.is_empty():
			course_shot_data = course_instance.shot_history.back()
			
		var tracer_pts = []
		var tracers_list = player_node.get("tracers")
		if tracers_list != null and not tracers_list.is_empty():
			var last_t = tracers_list.back()
			if is_instance_valid(last_t) and "points" in last_t:
				tracer_pts = last_t.points.duplicate()
				
		var current_shot_entry = {
			"start_pos": last_start_pos,
			"end_pos": current_ball_pos,
			"club": current_stats.get("club", MultiplayerManager.current_club),
			"lie_type": target_player.get("lie_type", "fairway"),
			"shot_reduction": target_player.get("shot_reduction", 0.0),
			"last_shot_penalty": target_player.get("last_shot_penalty", 0),
			"shot_stats": current_stats,
			"course_shot_data": course_shot_data,
			"tracer_points": tracer_pts,
			"aim_target_pos": last_aim_target,
			"aim_yaw_offset_deg": last_aim_yaw
		}
		
		if not target_player.has("mulligan_history") or typeof(target_player["mulligan_history"]) != TYPE_DICTIONARY:
			target_player["mulligan_history"] = {}
		if not target_player["mulligan_history"].has(hole_id):
			target_player["mulligan_history"][hole_id] = []
		target_player["mulligan_history"][hole_id].append(current_shot_entry)
		
		# Remove the selected previous shot from mulligan history
		var hist_list = target_player["mulligan_history"][hole_id]
		hist_list.erase(prev_shot)
		
		# 2. Undo current shot
		player_node.call("mulligan")
		if course_instance.has_method("remove_last_shot"):
			course_instance.call("remove_last_shot")
			
		var penalty = target_player.get("last_shot_penalty", 0)
		var strokes_to_remove = 1 + penalty
		target_player["strokes"] = max(0, target_player["strokes"] - strokes_to_remove)
		target_player["total_strokes"] = max(0, target_player["total_strokes"] - strokes_to_remove)
		target_player["last_shot_penalty"] = 0
		if not target_player["shot_history"].is_empty():
			target_player["shot_history"].pop_back()
		if target_player.has("shot_stats") and typeof(target_player["shot_stats"]) == TYPE_DICTIONARY:
			if target_player["shot_stats"].has(hole_id) and not target_player["shot_stats"][hole_id].is_empty():
				target_player["shot_stats"][hole_id].pop_back()
		
		# 3. Apply the selected previous shot
		var prev_penalty = prev_shot.get("last_shot_penalty", 0)
		var strokes_to_add = 1 + prev_penalty
		target_player["strokes"] += strokes_to_add
		target_player["total_strokes"] += strokes_to_add
		target_player["last_shot_penalty"] = prev_penalty
		target_player["last_shot_distance_yards"] = -1.0
		
		target_player["position"] = prev_shot["end_pos"]
		target_player["shot_history"].append(prev_shot["end_pos"])
		
		if not target_player.has("shot_stats"):
			target_player["shot_stats"] = {}
		if not target_player["shot_stats"].has(hole_id):
			target_player["shot_stats"][hole_id] = []
		target_player["shot_stats"][hole_id].append(prev_shot["shot_stats"])
		
		target_player["lie_type"] = prev_shot.get("lie_type", "fairway")
		target_player["shot_reduction"] = prev_shot.get("shot_reduction", 0.0)
		
		# Restore detailed tracer points
		target_player["last_shot_tracer_points"] = prev_shot.get("tracer_points", []).duplicate()
		
		if not MultiplayerManager.hole_ids.is_empty():
			target_player["hole_scores"][hole_id] = target_player["strokes"]
			
		# Teleport player and ball
		player_node.set("_last_starting_pos", prev_shot["start_pos"])
		var ball = player_node.get("ball")
		if ball != null:
			ball.global_position = prev_shot["end_pos"]
			ball.spawn_position = prev_shot["end_pos"]
			ball.reset()
			
		# Re-add to course_instance's shot_history
		if course_instance != null and "shot_history" in course_instance:
			course_instance.shot_history.append(prev_shot["course_shot_data"])
			var p_name = prev_shot["course_shot_data"].get("player", "")
			var club_name = prev_shot["course_shot_data"].get("club", "")
			if not p_name.is_empty() and not club_name.is_empty():
				if course_instance.has_method("_record_global_shot"):
					course_instance.call("_record_global_shot", p_name, club_name, prev_shot["course_shot_data"])
			if course_instance.has_method("_update_averages"):
				course_instance.call("_update_averages")
				
		MultiplayerManager.clear_last_shot()
		MultiplayerManager.active_player_index = target_idx
		MultiplayerManager.emit_signal("active_player_changed", target_player)
		MultiplayerManager.save_current_match()


func _on_forfeit_pressed() -> void:
	if mulligan_confirm_dialog != null:
		mulligan_confirm_dialog.visible = false
	if exit_confirm_dialog != null:
		exit_confirm_dialog.visible = false
	if forfeit_confirm_dialog == null:
		return
		
	# Clear existing children of the dialog
	for child in forfeit_confirm_dialog.get_children():
		forfeit_confirm_dialog.remove_child(child)
		child.queue_free()
		
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 16)
	
	var active_p = MultiplayerManager.get_active_player()
	if active_p.is_empty():
		return
		
	var p_name = active_p.get("name", "Player")
	var strokes = active_p.get("strokes", 0)
	var is_multi = MultiplayerManager.players.size() > 1
	
	var title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.35, 0.35, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 4)
	content_vbox.add_child(title_lbl)
	
	var msg_lbl = Label.new()
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.add_theme_color_override("font_color", Color.WHITE)
	msg_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_lbl.add_theme_constant_override("outline_size", 4)
	content_vbox.add_child(msg_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 24)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var confirm_btn = Button.new()
	confirm_btn.custom_minimum_size = Vector2(160, 45)
	apply_material_button_style(confirm_btn, Color(0.68, 0.22, 0.22, 0.85))

	if _is_online_match():
		if _is_spectating():
			title_lbl.text = "Leave Spectating 🚪"
			msg_lbl.text = "Are you sure you want to stop spectating this match?"
			confirm_btn.text = "Yes, Leave Spectating"
		else:
			title_lbl.text = "Leave Online Match 🚪"
			msg_lbl.text = "Are you sure you want to leave this online match?\nYour remaining holes will be forfeited."
			confirm_btn.text = "Yes, Leave Match"
		confirm_btn.pressed.connect(func():
			forfeit_confirm_dialog.visible = false
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == forfeit_confirm_dialog:
				UIFocusGuard.pop_lock(false)
			if has_node("/root/OnlineMatchController"):
				get_node("/root/OnlineMatchController").leave_online_match()
			else:
				_on_forfeit_confirmed()
		)
	else:
		title_lbl.text = "Concede Hole? 🏳️" if not is_multi else "Concede Hole: %s 🏳️" % p_name
		if not is_multi:
			msg_lbl.text = "Count this hole as in at %d strokes?\nYou will not need to hit on this hole anymore." % strokes
		else:
			msg_lbl.text = "Count this hole as in for %s at %d strokes?\nThey will not need to hit on this hole anymore." % [p_name, strokes]
		confirm_btn.text = "Yes, Concede Hole"
		confirm_btn.pressed.connect(func():
			forfeit_confirm_dialog.visible = false
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == forfeit_confirm_dialog:
				UIFocusGuard.pop_lock(false)
			_on_forfeit_confirmed()
		)
	btn_hbox.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.name = "CancelBtn"
	cancel_btn.custom_minimum_size = Vector2(140, 45)
	apply_material_button_style(cancel_btn, Color(0.35, 0.35, 0.38, 0.85))
	cancel_btn.pressed.connect(func():
		forfeit_confirm_dialog.visible = false
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == forfeit_confirm_dialog:
			UIFocusGuard.pop_lock(false)
	)
	confirm_btn.name = "ConfirmBtn"

	btn_hbox.add_child(cancel_btn)
	content_vbox.add_child(btn_hbox)
	forfeit_confirm_dialog.add_child(content_vbox)

	confirm_btn.focus_neighbor_right = confirm_btn.get_path_to(cancel_btn)
	confirm_btn.focus_neighbor_left = confirm_btn.get_path_to(cancel_btn)
	cancel_btn.focus_neighbor_left = cancel_btn.get_path_to(confirm_btn)
	cancel_btn.focus_neighbor_right = cancel_btn.get_path_to(confirm_btn)
	forfeit_confirm_dialog.visible = true
	UIFocusGuard.push_lock(forfeit_confirm_dialog)
	cancel_btn.call_deferred("grab_focus")


func _on_forfeit_confirmed() -> void:
	if course_instance != null and course_instance.has_method("cancel_pending_shot_transition"):
		course_instance.call("cancel_pending_shot_transition")
	MultiplayerManager.concede_hole()


func _is_online_match() -> bool:
	if has_node("/root/OnlineSession"):
		return bool(get_node("/root/OnlineSession").is_online_match)
	return false


func _is_spectating() -> bool:
	if has_node("/root/OnlineSession"):
		var sess = get_node("/root/OnlineSession")
		return bool(sess.is_online_match) and bool(sess.get("is_spectator"))
	return false


func _on_online_waiting_banner_status_changed(is_waiting: bool, player_name: String, is_afk: bool) -> void:
	if online_waiting_banner == null or not is_instance_valid(online_waiting_banner):
		return
	online_waiting_banner.visible = is_waiting
	if not is_waiting:
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == online_waiting_banner:
			UIFocusGuard.pop_lock(false)
		return

	if online_waiting_lbl != null:
		var sess = get_node_or_null("/root/OnlineSession")
		var is_replaying: bool = sess != null and sess.has_method("is_replaying_remote_turn") and sess.is_replaying_remote_turn()
		if _is_spectating():
			online_waiting_lbl.text = "Spectating: %s's Turn" % player_name
		elif is_replaying:
			online_waiting_lbl.text = "Replaying %s's Shot…" % player_name
		else:
			online_waiting_lbl.text = "Waiting for %s to hit…" % player_name

	var show_afk: bool = is_afk and not _is_spectating()
	if online_afk_warning_lbl != null:
		online_afk_warning_lbl.visible = show_afk
	if online_afk_btn_box != null:
		online_afk_btn_box.visible = show_afk

	if show_afk:
		if not UIFocusGuard.is_locked() or UIFocusGuard.current_lock_root() != online_waiting_banner:
			UIFocusGuard.push_lock(online_waiting_banner)
		if online_concede_btn != null and is_instance_valid(online_concede_btn):
			online_concede_btn.call_deferred("grab_focus")
	else:
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == online_waiting_banner:
			UIFocusGuard.pop_lock(false)


func _on_gimme_awarded(player: Dictionary, extra_strokes: int) -> void:
	is_player_turn_ready = false
	if gimme_banner == null or gimme_title_lbl == null:
		return
		
	var p_name = player.get("name", "Player")
	gimme_title_lbl.text = "GIMME +%d" % extra_strokes
	if gimme_sub_lbl != null:
		var hole_idx = clamp(MultiplayerManager.current_hole_index, 0, max(0, MultiplayerManager.hole_ids.size() - 1))
		var hole_id = MultiplayerManager.hole_ids[hole_idx] if not MultiplayerManager.hole_ids.is_empty() else ""
		var current_hole = MultiplayerManager.hole_info.get(hole_id, {})
		var par = int(round(float(current_hole.get("Par", 4))))
		var strokes = player.get("strokes", 0)
		var hole_diff = strokes - par
		var diff_text = "E"
		if hole_diff > 0:
			diff_text = "+%d" % hole_diff
		elif hole_diff < 0:
			diff_text = "%d" % hole_diff
		gimme_sub_lbl.text = "%s  •  Hole Score: %d (%s)" % [p_name, strokes, diff_text]
		
	if _gimme_tween != null and _gimme_tween.is_valid():
		_gimme_tween.kill()
		
	gimme_banner.visible = true
	gimme_banner.modulate = Color(1, 1, 1, 0)
	gimme_banner.pivot_offset = gimme_banner.size / 2.0
	gimme_banner.scale = Vector2(0.85, 0.85)
	
	_gimme_tween = create_tween()
	_gimme_tween.set_parallel(true)
	_gimme_tween.tween_property(gimme_banner, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gimme_tween.tween_property(gimme_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Stay for 2 seconds, then smoothly fade out
	_gimme_tween.chain().tween_interval(2.0)
	_gimme_tween.chain().tween_property(gimme_banner, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_gimme_tween.tween_callback(func():
		if is_instance_valid(gimme_banner):
			gimme_banner.visible = false
	)


func _on_hole_completed(scores: Array) -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")
	is_player_turn_ready = false
	reset_zoom_to_default()
	_scorecard_selected_hole_index = MultiplayerManager.current_hole_index
	_populate_scorecard("hole_completed")
	hud_scorecard.visible = true
	_set_other_elements_visible(false)
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		guard.push_lock(hud_scorecard)
	_focus_selected_hole_button()


func _on_game_over(scores: Array) -> void:
	if has_node("/root/AnnouncerEngine"):
		get_node("/root/AnnouncerEngine").call("ResetIdleTimer")
	is_player_turn_ready = false
	reset_zoom_to_default()
	MultiplayerManager.is_finished = true
	MultiplayerManager.save_current_match()
	_populate_overview()
	hud_overview.visible = true
	_set_other_elements_visible(false)
	GlobalSettings.play_golf_clap()


func _update_tee_shot_view(ball: Node, ball_is_moving: bool, ball_state_changed: bool, delta: float) -> void:
	if _tee_shot_view == null or ball == null:
		return
	var tee_shot_view_enabled: bool = bool(GlobalSettings.range_settings.tee_shot_view_enabled.value)
	if not tee_shot_view_enabled:
		ball.set("tee_shot_view", null)
		if _tee_shot_flight_active:
			_tee_shot_view.hide_shot(true)
			_tee_shot_flight_active = false
			_tee_shot_tracer_update_elapsed = 0.0
		return
	ball.set("tee_shot_view", _tee_shot_view)
	var main_camera := course_instance.get_node_or_null("Camera3D") as Camera3D if course_instance != null else null
	_tee_shot_view.call("set_main_camera", main_camera)
	if _minimap_panel != null and is_instance_valid(_minimap_panel):
		_tee_shot_view.set_minimap_rect(_minimap_panel.get_global_rect())

	if not ball_is_moving:
		if _tee_shot_flight_active:
			_tee_shot_view.hide_shot()
			_tee_shot_flight_active = false
			_tee_shot_tracer_update_elapsed = 0.0
		return

	if not bool(ball.get("shot_was_from_teebox")):
		if _tee_shot_flight_active:
			_tee_shot_view.hide_shot()
			_tee_shot_flight_active = false
			_tee_shot_tracer_update_elapsed = 0.0
		return

	_tee_shot_flight_active = true
	var start_pos: Vector3 = ball.get("shot_start_pos_global")
	var current_pos: Vector3 = ball.get_interpolated_position() if ball.has_method("get_interpolated_position") else ball.global_position
	var target_pos := Vector3.ZERO
	if course_instance != null:
		var target_value: Variant = course_instance.get("current_hole_location")
		if not target_value is Vector3 or target_value.is_zero_approx():
			target_value = course_instance.get("aim_target_pos")
		if target_value is Vector3:
			target_pos = target_value

	if ball_is_moving:
		if not _tee_shot_view.visible:
			_tee_shot_view.show_shot(start_pos, current_pos, target_pos)
			_tee_shot_tracer_update_elapsed = TEE_SHOT_TRACER_UPDATE_INTERVAL
		_tee_shot_view.update_ball_position(current_pos)
		_tee_shot_tracer_update_elapsed += delta
		if _tee_shot_tracer_update_elapsed >= TEE_SHOT_TRACER_UPDATE_INTERVAL:
			_tee_shot_tracer_update_elapsed = 0.0
			var player_node := course_instance.get_node_or_null("Player") as Node3D if course_instance != null else null
			var current_tracer: Node = player_node.get("current_tracer") if player_node != null else null
			var tracer_points: Array = current_tracer.get("points") if current_tracer != null and is_instance_valid(current_tracer) else []
			var player_transform := player_node.global_transform if player_node != null else Transform3D.IDENTITY
			_tee_shot_view.update_tracer(tracer_points, player_transform, start_pos, current_pos)


func _on_tee_shot_split_started() -> void:
	_hud_visible_before_tee_shot = _hud_elements_visible
	_set_other_elements_visible(false)


func _on_tee_shot_split_closed() -> void:
	if _hud_visible_before_tee_shot:
		_set_other_elements_visible(true)


func _process(_delta: float) -> void:
	# Scorecard countdown handling
	if _scorecard_countdown_active and hud_scorecard.visible:
		if not _scorecard_countdown_paused:
			_scorecard_countdown_time_left -= _delta
			if _scorecard_countdown_time_left <= 0.0:
				_scorecard_countdown_time_left = 0.0
				_on_scorecard_advance()
			else:
				_update_scorecard_countdown_display()
	elif _scorecard_countdown_active and not hud_scorecard.visible:
		_stop_scorecard_countdown()

	var ball = active_ball
	if ball == null and course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
			active_ball = ball

	var ball_is_moving: bool = (ball != null and ball.state != PhysicsEnums.BallState.REST)
	var ball_state_changed: bool = ball_is_moving != _prev_ball_moving
	if ball_state_changed:
		_prev_ball_moving = ball_is_moving
		_minimap_zoom_dirty = true
		if has_node("/root/ScreenOffsetManager"):
			var som = get_node("/root/ScreenOffsetManager")
			if ball_is_moving:
				som.call("on_shot_started")
			else:
				som.call("set_putter_active", is_default_club_putter())
				som.call("on_ready_for_shot")

	_update_tee_shot_view(ball, ball_is_moving, ball_state_changed, _delta)

	if mulligan_btn != null and mulligan_btn.visible:
		if _is_online_match():
			mulligan_btn.visible = false
		else:
			var can_mull = MultiplayerManager.can_mulligan() and not ball_is_moving and not hud_scorecard.visible and not hud_overview.visible
			mulligan_btn.disabled = not can_mull

	if forfeit_btn != null:
		var is_match_play = not MultiplayerManager.players.is_empty() and not MultiplayerManager.practice_mode_active
		var active_p = MultiplayerManager.get_active_player()
		var p_strokes = active_p.get("strokes", 0) if not active_p.is_empty() else 0
		var p_holed = active_p.get("holed_out", false) if not active_p.is_empty() else true
		var should_show_forfeit = _hud_elements_visible and (_is_spectating() or (is_match_play and (p_strokes >= 10 or _is_online_match()) and not p_holed))
		forfeit_btn.visible = should_show_forfeit
		if should_show_forfeit:
			forfeit_btn.disabled = ball_is_moving or hud_scorecard.visible or hud_overview.visible or (hud_manage_players != null and hud_manage_players.visible)

	if ball_is_moving:
		if forfeit_confirm_dialog != null and forfeit_confirm_dialog.visible:
			forfeit_confirm_dialog.visible = false

	if course_instance != null and course_instance.get("show_green_grid") != null:
		_update_grid_button_state(course_instance.get("show_green_grid") as bool)
		
	# Ensure enlarged minimap collapses on desktop if mouse moves away or state changes
	if _is_minimap_enlarged and _is_desktop():
		if ball_is_moving or hud_scorecard.visible or hud_overview.visible or (hud_manage_players != null and hud_manage_players.visible):
			_set_minimap_enlarged(false)
		elif _minimap_panel != null and _minimap_panel.is_visible_in_tree():
			var m_pos = _minimap_panel.get_global_mouse_position()
			if not _minimap_panel.get_global_rect().has_point(m_pos):
				_set_minimap_enlarged(false)
		else:
			_set_minimap_enlarged(false)

	_update_minimap()
	
	# Update top HUD if data changed (safety fallback for practice mode/penalties)
	var active_player = MultiplayerManager.get_active_player()
	if not active_player.is_empty():
		var strokes = active_player.get("strokes", 0)
		var name_str = active_player.get("name", "")
		var hole_idx = MultiplayerManager.current_hole_index
		if strokes != _last_hud_strokes or name_str != _last_hud_player_name or hole_idx != _last_hud_hole_index:
			_last_hud_strokes = strokes
			_last_hud_player_name = name_str
			_last_hud_hole_index = hole_idx
			_update_top_hud(active_player)
			
	# Manage 2D overlays and 3D map markers for multiplayer ball tracking
	if _overlay_node != null:
		if not ball_is_moving or Engine.get_process_frames() % 3 == 0:
			_overlay_node.queue_redraw()
		
	if not ball_is_moving and MultiplayerManager.players.size() > 1 and not MultiplayerManager.is_finished:
		var show_markers = true
		if hud_scorecard.visible or hud_manage_players.visible:
			show_markers = false
			
		for i in range(MultiplayerManager.players.size()):
			var p = MultiplayerManager.players[i]
			var is_marker_valid = show_markers and not p.get("holed_out", false) and p.get("active", true)
			
			var ball_pos = Vector3.ZERO
			if i == MultiplayerManager.active_player_index and active_ball != null:
				ball_pos = active_ball.global_position
			else:
				ball_pos = p.get("position", Vector3.ZERO)
				
			if is_marker_valid and not ball_pos.is_zero_approx():
				var marker = _player_map_markers.get(i)
				if marker == null or not is_instance_valid(marker):
					var letter = p["name"].substr(0, 1).to_upper()
					var color = MultiplayerManager.get_player_color(p)
					marker = _create_player_map_marker(p, letter, color)
					add_child(marker)
					_player_map_markers[i] = marker
				marker.global_position = ball_pos
				marker.visible = true
			else:
				var marker = _player_map_markers.get(i)
				if marker != null and is_instance_valid(marker):
					marker.visible = false
	elif not ball_is_moving:
		_clear_map_markers()


func is_player_in_teebox() -> bool:
	if course_instance != null and course_instance.has_method("is_ball_in_teebox"):
		return course_instance.call("is_ball_in_teebox")
	var ball = active_ball
	if ball == null and course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
	if ball != null:
		var lie_str = str(ball.get("lie_type")).to_lower()
		if lie_str == "teebox":
			return true
	if has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if not mp_mgr.players.is_empty():
			var ap = mp_mgr.get_active_player()
			if ap.get("lie_type", "").to_lower() == "teebox":
				return true
			if ap.get("strokes", 0) == 0:
				return true
	return false


func move_stuck_ball(distance_yards: float = 2.0) -> bool:
	if course_instance != null and course_instance.has_method("move_stuck_ball"):
		var res = course_instance.call("move_stuck_ball", distance_yards)
		_update_distance_queue()
		return bool(res)
	return false


var _cached_cp_wrong_green_pos: Vector3 = Vector3.INF
var _cached_cp_wrong_green_res: bool = false

func is_player_on_wrong_green() -> bool:
	var ball = active_ball
	if ball == null and course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
	var ball_pos = ball.global_position if ball != null else Vector3.ZERO
	if ball_pos.is_equal_approx(_cached_cp_wrong_green_pos):
		return _cached_cp_wrong_green_res
	_cached_cp_wrong_green_pos = ball_pos
	_cached_cp_wrong_green_res = _calc_is_player_on_wrong_green(ball, ball_pos)
	return _cached_cp_wrong_green_res

func _calc_is_player_on_wrong_green(ball: Node, ball_pos: Vector3) -> bool:
	if course_instance != null and course_instance.has_method("is_ball_on_wrong_green"):
		return bool(course_instance.call("is_ball_on_wrong_green", ball_pos))
	if ball != null and course_instance != null:
		var pin_pos = course_instance.get("current_hole_location")
		if pin_pos != null and not pin_pos.is_zero_approx():
			var l = str(ball.get("lie_type")).to_lower()
			if (l == "green" or l == "fringe") and ball_pos.distance_to(pin_pos) > 55.0:
				return true
	return false


var _cached_cp_on_green_pos: Vector3 = Vector3.INF
var _cached_cp_on_green_res: bool = false

func is_player_on_green() -> bool:
	var ball = active_ball
	if ball == null and course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
	var ball_pos = ball.global_position if ball != null else Vector3.ZERO
	if ball_pos.is_equal_approx(_cached_cp_on_green_pos):
		return _cached_cp_on_green_res
	_cached_cp_on_green_pos = ball_pos
	_cached_cp_on_green_res = _calc_is_player_on_green(ball)
	return _cached_cp_on_green_res

func _calc_is_player_on_green(ball: Node) -> bool:
	if is_player_on_wrong_green():
		return false
	if ball != null:
		var lie_str = str(ball.get("lie_type")).to_lower()
		if lie_str == "green":
			return true
	if course_instance != null and course_instance.has_method("is_ball_on_green"):
		if bool(course_instance.call("is_ball_on_green")):
			return true
	if has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if not mp_mgr.players.is_empty():
			var ap = mp_mgr.get_active_player()
			if ap.get("lie_type", "").to_lower() == "green":
				return true
	return false


var _cached_cp_on_fringe_pos: Vector3 = Vector3.INF
var _cached_cp_on_fringe_res: bool = false

func is_player_on_fringe() -> bool:
	var ball = active_ball
	if ball == null and course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
	var ball_pos = ball.global_position if ball != null else Vector3.ZERO
	if ball_pos.is_equal_approx(_cached_cp_on_fringe_pos):
		return _cached_cp_on_fringe_res
	_cached_cp_on_fringe_pos = ball_pos
	_cached_cp_on_fringe_res = _calc_is_player_on_fringe(ball)
	return _cached_cp_on_fringe_res

func _calc_is_player_on_fringe(ball: Node) -> bool:
	if is_player_on_wrong_green():
		return false
	if ball != null:
		var lie_str = str(ball.get("lie_type")).to_lower()
		if lie_str == "fringe":
			return true
	if course_instance != null and course_instance.has_method("is_ball_on_fringe"):
		if bool(course_instance.call("is_ball_on_fringe")):
			return true
	if has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if not mp_mgr.players.is_empty():
			var ap = mp_mgr.get_active_player()
			if ap.get("lie_type", "").to_lower() == "fringe":
				return true
	return false


var _cached_cp_def_putt_pos: Vector3 = Vector3.INF
var _cached_cp_def_putt_club: String = ""
var _cached_cp_def_putt_res: bool = false

func is_default_club_putter() -> bool:
	var ball = active_ball
	var ball_pos = ball.global_position if ball != null else Vector3.ZERO
	var current_c = ""
	if course_instance != null and course_instance.has_method("_get_current_club"):
		current_c = str(course_instance.call("_get_current_club")).to_lower()
	if ball_pos.is_equal_approx(_cached_cp_def_putt_pos) and current_c == _cached_cp_def_putt_club:
		return _cached_cp_def_putt_res
	_cached_cp_def_putt_pos = ball_pos
	_cached_cp_def_putt_club = current_c
	_cached_cp_def_putt_res = _calc_is_default_club_putter(current_c)
	return _cached_cp_def_putt_res

func _calc_is_default_club_putter(current_c: String) -> bool:
	if is_player_on_wrong_green():
		return false
	if not current_c.is_empty():
		return current_c in ["pt", "putt", "putter"] or current_c.begins_with("putt")
	if course_instance != null and course_instance.has_method("is_default_club_putter"):
		return bool(course_instance.call("is_default_club_putter"))
	if course_instance != null and course_instance.has_method("get_default_club"):
		var def_c = str(course_instance.call("get_default_club")).to_lower()
		return def_c in ["pt", "putt", "putter"] or def_c.begins_with("putt")
	if is_player_on_green():
		return true
	if is_player_on_fringe():
		var ball = active_ball
		if ball != null and course_instance != null:
			var pin_pos = course_instance.get("current_hole_location")
			if pin_pos != null and not pin_pos.is_zero_approx():
				var dist_yards = ball.global_position.distance_to(pin_pos) * 1.09361
				return dist_yards <= 35.0
		return true
	return false


func is_player_close_to_green() -> bool:
	if is_player_on_wrong_green():
		var ball = active_ball
		if ball != null and course_instance != null:
			var pin_pos = course_instance.get("current_hole_location")
			if pin_pos != null and not pin_pos.is_zero_approx():
				return ball.global_position.distance_to(pin_pos) <= 45.0
		return false
	if is_player_on_green() or is_player_on_fringe():
		return true
	if course_instance != null and course_instance.has_method("is_ball_close_to_green"):
		return course_instance.call("is_ball_close_to_green")
	var ball = active_ball
	if ball == null and course_instance != null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
	if ball != null:
		var lie_str = str(ball.get("lie_type")).to_lower()
		if lie_str == "green" or lie_str == "fringe":
			return true
		if course_instance != null:
			var pin_pos = course_instance.get("current_hole_location")
			if pin_pos != null and not pin_pos.is_zero_approx():
				if ball.global_position.distance_to(pin_pos) <= 45.0:
					return true
	if has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if not mp_mgr.players.is_empty():
			var ap = mp_mgr.get_active_player()
			var a_lie = ap.get("lie_type", "").to_lower()
			if a_lie == "green" or a_lie == "fringe":
				return true
	return false


func get_current_zoom_zone() -> int:
	if is_player_in_teebox():
		return 0 # TEE_BOX
	elif is_player_close_to_green():
		return 2 # GREEN
	else:
		return 1 # MIDWAY


func get_zoom_for_zone(zone: int) -> float:
	var green_zoom = 50.0
	if course_instance != null and course_instance.has_method("get_green_zoom_size"):
		green_zoom = course_instance.get_green_zoom_size()
	var tee_zoom = _teebox_minimap_zoom
	match zone:
		0: # TEE_BOX
			return tee_zoom
		1: # MIDWAY (half way between tee box zoom and green zoom)
			return (tee_zoom + green_zoom) * 0.5
		2: # GREEN
			return green_zoom
		_:
			return tee_zoom


func reset_zoom_to_default() -> void:
	minimap_zoom = 300.0
	_teebox_minimap_zoom = 300.0
	_default_non_green_minimap_zoom = 300.0
	_last_zoom_zone = -1
	_last_was_on_green = false
	_minimap_zoom_dirty = true
	if _minimap_camera != null:
		_minimap_camera.size = minimap_zoom
	if course_instance != null:
		if course_instance.has_method("reset_zoom_to_default"):
			course_instance.reset_zoom_to_default()
		else:
			if "aerial_zoom" in course_instance:
				course_instance.aerial_zoom = 300.0
			if "_default_non_green_aerial_zoom" in course_instance:
				course_instance._default_non_green_aerial_zoom = 300.0
			if "_last_was_on_green" in course_instance:
				course_instance._last_was_on_green = false
			if "_last_zoom_zone" in course_instance:
				course_instance._last_zoom_zone = -1
			if "show_green_grid" in course_instance:
				course_instance.show_green_grid = false
			var aerial_cam = course_instance.get_node_or_null("AerialCamera")
			if aerial_cam != null:
				aerial_cam.size = 300.0


func _update_minimap() -> void:
	if _minimap_camera == null or course_instance == null or _minimap_panel == null:
		return
		
	if _minimap_camera.cull_mask != ((1 << 0) | (1 << 1)):
		_minimap_camera.cull_mask = (1 << 0) | (1 << 1)
		
	# Check if scorecard or players HUD is open
	if hud_scorecard.visible or hud_manage_players.visible or hud_overview.visible:
		if _minimap_group != null:
			_minimap_group.visible = false
		if _minimap_viewport != null and _minimap_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_minimap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _minimap_flag_icon != null:
			_minimap_flag_icon.visible = false
		if _minimap_ball_icon != null:
			_minimap_ball_icon.visible = false
		return
		
	# Check if the course is in full-screen aerial view
	var is_aerial = course_instance.get("is_aerial_view") as bool if course_instance.get("is_aerial_view") != null else false
	
	# The box shouldn't show at all when the full-screen aerial view is active
	if _minimap_group != null:
		_minimap_group.visible = not is_aerial
		
	var ball = active_ball
	if ball == null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
			
	if ball == null:
		if _minimap_flag_icon != null:
			_minimap_flag_icon.visible = false
		if _minimap_ball_icon != null:
			_minimap_ball_icon.visible = false
		return

	# Pause minimap SubViewport rendering and calculations during active ball flight to prevent double 3D rendering pass
	if ball.state != PhysicsEnums.BallState.REST:
		if _minimap_viewport != null and _minimap_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_minimap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _minimap_flag_icon != null:
			_minimap_flag_icon.visible = false
		if _minimap_ball_icon != null:
			_minimap_ball_icon.visible = false
		return

	if _minimap_viewport != null and _minimap_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		
	# Check for shot zoom zone transition (Tee box vs Midway vs Green) only when dirty
	if _minimap_zoom_dirty:
		_minimap_zoom_dirty = false
		var current_zone = get_current_zoom_zone()
		if current_zone != _last_zoom_zone:
			var target_zoom = get_zoom_for_zone(current_zone)
			minimap_zoom = target_zoom
			if course_instance != null and "aerial_zoom" in course_instance:
				course_instance.aerial_zoom = target_zoom
				var aerial_cam = course_instance.get_node_or_null("AerialCamera")
				if aerial_cam != null:
					aerial_cam.size = target_zoom
			
			# Auto-toggle green slope grid when putter is the default selected club (green or fringe)
			var should_show_grid = is_default_club_putter()
			if course_instance != null and course_instance.get("show_green_grid") != null:
				course_instance.set("show_green_grid", should_show_grid)
				_update_grid_button_state(should_show_grid)
				
			_last_zoom_zone = current_zone
			_last_was_on_green = should_show_grid
	
	if is_aerial:
		if _minimap_flag_icon != null:
			_minimap_flag_icon.visible = false
		if _minimap_ball_icon != null:
			_minimap_ball_icon.visible = false
		return # No need to calculate minimap camera position or distance tracker if hidden
		
	var ball_pos = ball.global_position
	var pin_pos = course_instance.get("current_hole_location")
	if GlobalSettings.is_chipping_minigame and course_instance.get("aim_target_pos") != null:
		pin_pos = course_instance.get("aim_target_pos")
	if pin_pos == null:
		pin_pos = course_instance.get("aim_target_pos")
		
	var yaw_rad = 0.0
	var aim_yaw = ball.get("aim_yaw_offset_deg")
	if aim_yaw != null:
		yaw_rad = deg_to_rad(-aim_yaw)
	elif pin_pos != null:
		var diff = pin_pos - ball_pos
		yaw_rad = atan2(diff.z, diff.x)
	else:
		yaw_rad = -PI/2
		
	var dir_3d = Vector3(cos(yaw_rad), 0, sin(yaw_rad)).normalized()
	var dist = 150.0
	if pin_pos != null:
		dist = ball_pos.distance_to(pin_pos)
		
	_minimap_camera.size = minimap_zoom
	
	# Orientation - aligns camera exactly to face the player's aiming direction
	var right_vec = dir_3d.cross(Vector3.UP).normalized()
	var up_vec = dir_3d
	var back_vec = Vector3.UP
	_minimap_camera.transform.basis = Basis(right_vec, up_vec, back_vec)
	
	# Position - exact base position alignment as full aerial view
	var base_pos = ball_pos + dir_3d * (0.35 * minimap_zoom)
	_minimap_camera.position = Vector3(base_pos.x, 150.0, base_pos.z)

	# --- Update Flag and Ball Icons on Minimap (when on green and putting / heatmap active) ---
	_update_minimap_flag_marker(pin_pos, _last_zoom_zone, ball)
	_update_minimap_ball_marker(ball_pos, _last_zoom_zone, ball)

	# --- Update Distance Tracker Panel ---
	_update_distance_tracker_panel(ball_pos, pin_pos, dir_3d)


var _last_tracker_ball_pos: Vector3 = Vector3.INF
var _last_tracker_pin_pos: Vector3 = Vector3.INF
var _last_tracker_hole_idx: int = -1

func _update_distance_tracker_panel(ball_pos: Vector3, pin_pos: Variant, dir_3d: Vector3) -> void:
	if _distance_tracker_panel == null or _back_lbl == null or _hole_lbl == null or _front_lbl == null:
		return
	if pin_pos == null or not (pin_pos is Vector3):
		_back_lbl.text = "---"
		_hole_lbl.text = "---"
		_front_lbl.text = "---"
		if _distance_unit_lbl != null:
			_distance_unit_lbl.text = ""
		return

	var hole_idx = MultiplayerManager.current_hole_index
	if ball_pos.is_equal_approx(_last_tracker_ball_pos) and (pin_pos as Vector3).is_equal_approx(_last_tracker_pin_pos) and hole_idx == _last_tracker_hole_idx:
		return

	_last_tracker_ball_pos = ball_pos
	_last_tracker_pin_pos = pin_pos
	_last_tracker_hole_idx = hole_idx

	var ball_pos_2d = Vector2(ball_pos.x, ball_pos.z)
	var pin_pos_2d = Vector2((pin_pos as Vector3).x, (pin_pos as Vector3).z)
	
	# Get direction from ball to pin on XZ plane
	var pin_dir_2d = (pin_pos_2d - ball_pos_2d).normalized()
	if pin_dir_2d.length_squared() < 0.001:
		pin_dir_2d = Vector2(dir_3d.x, dir_3d.z).normalized()
	
	# Get green vertices
	var global_verts = _get_cached_green_vertices()
	if global_verts.is_empty():
		# Fallback: create a circle of 24 points around pin_pos with a 15-yard (13.7m) radius
		var radius = 13.7
		for i in range(24):
			var angle = i * PI * 2.0 / 24.0
			global_verts.append(pin_pos + Vector3(cos(angle) * radius, 0, sin(angle) * radius))
			
	var min_proj_dist = 999999.0
	var max_proj_dist = -999999.0
	
	for v in global_verts:
		var v_2d = Vector2(v.x, v.z)
		var proj = (v_2d - ball_pos_2d).dot(pin_dir_2d)
		if proj < min_proj_dist:
			min_proj_dist = proj
		if proj > max_proj_dist:
			max_proj_dist = proj
			
	# Distance to hole
	var dist_hole = ball_pos.distance_to(pin_pos)
	
	# Check if putting / on the green or fringe
	var is_putting = (not is_player_on_wrong_green()) and (is_default_club_putter() or is_player_on_green() or is_player_on_fringe())

	if is_putting:
		# Display as feet when putting on the green or fringe
		var dist_back_ft = int(round(max_proj_dist * 3.28084))
		var dist_hole_ft = int(round(dist_hole * 3.28084))
		var dist_front_ft = int(round(min_proj_dist * 3.28084))
		
		if dist_front_ft < 0:
			dist_front_ft = 0
			
		_back_lbl.text = str(dist_back_ft)
		_hole_lbl.text = str(dist_hole_ft)
		_front_lbl.text = str(dist_front_ft)
		if _distance_unit_lbl != null:
			_distance_unit_lbl.text = "FT"
	else:
		# Display as yards when off the green
		var dist_back_yds = int(max_proj_dist * 1.09361)
		var dist_hole_yds = int(dist_hole * 1.09361)
		var dist_front_yds = int(min_proj_dist * 1.09361)
		
		# Clamp front distance to be at least 0
		if dist_front_yds < 0:
			dist_front_yds = 0
			
		_back_lbl.text = str(dist_back_yds)
		_hole_lbl.text = str(dist_hole_yds)
		_front_lbl.text = str(dist_front_yds)
		if _distance_unit_lbl != null:
			_distance_unit_lbl.text = "YDS"


const MINIMAP_FLAG_SVG: String = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 36" width="32" height="36">
  <!-- Hole / Cup base ellipse on green surface -->
  <ellipse cx="8" cy="32" rx="5.5" ry="2.5" fill="#111111" stroke="#FFFFFF" stroke-width="1.5"/>
  <!-- Flagpole black outline -->
  <line x1="8" y1="3" x2="8" y2="32" stroke="#000000" stroke-width="3" stroke-linecap="round"/>
  <!-- Flagpole silver/white body -->
  <line x1="8" y1="3" x2="8" y2="32" stroke="#EEEEEE" stroke-width="1.8" stroke-linecap="round"/>
  <!-- Gold finial ball on top -->
  <circle cx="8" cy="3" r="2.2" fill="#FFCA28" stroke="#000000" stroke-width="1"/>
  <!-- Flag black outer border for high contrast -->
  <polygon points="8,3.5 28.5,10.5 8,17.5" fill="#000000"/>
  <!-- Flag white inner border for contrast against red/dark heatmap zones -->
  <polygon points="8,4.5 26.5,10.5 8,16.5" fill="#FFFFFF"/>
  <!-- Vibrant solid red golf flag -->
  <polygon points="8.5,5.8 24.5,10.5 8.5,15.2" fill="#D32F2F"/>
</svg>"""

func _get_minimap_flag_texture() -> Texture2D:
	if ResourceLoader.exists("res://assets/images/icons/golf_pin_flag.svg"):
		var tex = load("res://assets/images/icons/golf_pin_flag.svg")
		if tex != null:
			return tex
	var img = Image.new()
	var err = img.load_svg_from_file("res://assets/images/icons/golf_pin_flag.svg", 2.0)
	if err == OK:
		return ImageTexture.create_from_image(img)
	err = img.load_svg_from_string(MINIMAP_FLAG_SVG, 2.0)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null

func _update_minimap_flag_marker(pin_pos: Variant, _current_zone: int, _ball: Node) -> void:
	if _minimap_flag_icon == null or _minimap_camera == null:
		return
		
	if pin_pos == null or (pin_pos is Vector3 and pin_pos.is_zero_approx()):
		_minimap_flag_icon.visible = false
		return

	# Check if pin position is behind the camera
	if _minimap_camera.is_position_behind(pin_pos):
		_minimap_flag_icon.visible = false
		return
		
	var screen_pos = _minimap_camera.unproject_position(pin_pos)
	var vp_w = float(_minimap_viewport.size.x) if _minimap_viewport != null else 180.0
	var vp_h = float(_minimap_viewport.size.y) if _minimap_viewport != null else 180.0
	if screen_pos.x >= -16 and screen_pos.x <= vp_w + 16 and screen_pos.y >= -16 and screen_pos.y <= vp_h + 16:
		# Anchor at cup ellipse center (8, 32) so cup is on pin location and flag flies above it
		_minimap_flag_icon.position = screen_pos - Vector2(8, 32)
		_minimap_flag_icon.visible = true
	else:
		_minimap_flag_icon.visible = false


const MINIMAP_BALL_SVG: String = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <!-- Soft drop shadow -->
  <circle cx="12" cy="12.5" r="11" fill="#000000" opacity="0.45"/>
  <!-- High contrast dark outer rim -->
  <circle cx="12" cy="12" r="10.5" fill="#FFFFFF" stroke="#111111" stroke-width="1.4"/>
  <!-- 3D shaded golf ball surface -->
  <circle cx="12" cy="12" r="9.5" fill="#F8FAFC"/>
  <!-- Shadow crescent on bottom-right -->
  <path d="M 12 2.5 A 9.5 9.5 0 0 1 21.5 12 A 9.5 9.5 0 0 1 12 21.5 A 9.5 9.5 0 0 0 12 2.5" fill="#B0BEC5" opacity="0.4"/>
  <!-- Soft specular highlight on top-left -->
  <circle cx="9" cy="8.5" r="4.5" fill="#FFFFFF" opacity="0.85"/>
  <!-- Dimple pattern -->
  <g fill="#90A4AE" opacity="0.75">
	<circle cx="12" cy="12" r="1.1"/>
	<circle cx="8.5" cy="11" r="0.95"/>
	<circle cx="15.5" cy="11" r="0.95"/>
	<circle cx="10.5" cy="7.8" r="0.9"/>
	<circle cx="13.5" cy="7.8" r="0.9"/>
	<circle cx="10.5" cy="15.2" r="0.9"/>
	<circle cx="13.5" cy="15.2" r="0.9"/>
	<circle cx="6.5" cy="12" r="0.85"/>
	<circle cx="17.5" cy="12" r="0.85"/>
	<circle cx="12" cy="5.8" r="0.85"/>
	<circle cx="12" cy="17.8" r="0.85"/>
	<circle cx="7.8" cy="8" r="0.8"/>
	<circle cx="16.2" cy="8" r="0.8"/>
	<circle cx="7.8" cy="15" r="0.8"/>
	<circle cx="16.2" cy="15" r="0.8"/>
  </g>
</svg>"""

func _get_minimap_ball_texture() -> Texture2D:
	if ResourceLoader.exists("res://assets/images/icons/golf_ball_icon.svg"):
		var tex = load("res://assets/images/icons/golf_ball_icon.svg")
		if tex != null:
			return tex
	var img = Image.new()
	var err = img.load_svg_from_file("res://assets/images/icons/golf_ball_icon.svg", 2.0)
	if err == OK:
		return ImageTexture.create_from_image(img)
	err = img.load_svg_from_string(MINIMAP_BALL_SVG, 2.0)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null

func _update_minimap_ball_marker(ball_pos: Vector3, current_zone: int, ball: Node) -> void:
	if _minimap_ball_icon == null or _minimap_camera == null:
		return
		
	if ball == null or ball_pos.is_zero_approx():
		_minimap_ball_icon.visible = false
		return
		
	# Check if player is on the green, fringe, or putting (or green heatmap is active)
	var on_wrong_green = is_player_on_wrong_green()
	var is_on_green_or_putting = (not on_wrong_green) and ((current_zone == 2) or is_default_club_putter() or is_player_on_green() or is_player_on_fringe())
	if not is_on_green_or_putting and not on_wrong_green and course_instance != null and course_instance.has_method("is_ball_on_green"):
		is_on_green_or_putting = bool(course_instance.call("is_ball_on_green"))
	if not is_on_green_or_putting and not on_wrong_green and ball != null:
		var lie_str = str(ball.get("lie_type")).to_lower()
		if lie_str == "green" or ball.get("is_putt") == true:
			is_on_green_or_putting = true
	if not is_on_green_or_putting and not on_wrong_green and has_node("/root/MultiplayerManager"):
		var mp_mgr = get_node("/root/MultiplayerManager")
		if not mp_mgr.players.is_empty():
			var ap = mp_mgr.get_active_player()
			if ap.get("lie_type", "").to_lower() == "green":
				is_on_green_or_putting = true
				
	# If green heatmap is actively shown, treat as green/putting view
	if not is_on_green_or_putting and course_instance != null and course_instance.get("show_green_grid") == true:
		is_on_green_or_putting = true

	# Show on green/putting, or in single player / practice mode so ball position is always clearly visible on minimap
	var should_show_ball = is_on_green_or_putting or (MultiplayerManager.players.size() <= 1)
	if not should_show_ball:
		_minimap_ball_icon.visible = false
		return

	# Check if ball position is behind the camera
	if _minimap_camera.is_position_behind(ball_pos):
		_minimap_ball_icon.visible = false
		return
		
	var screen_pos = _minimap_camera.unproject_position(ball_pos)
	var vp_w = float(_minimap_viewport.size.x) if _minimap_viewport != null else 180.0
	var vp_h = float(_minimap_viewport.size.y) if _minimap_viewport != null else 180.0
	if screen_pos.x >= -12 and screen_pos.x <= vp_w + 12 and screen_pos.y >= -12 and screen_pos.y <= vp_h + 12:
		# Anchor at center (12, 12) for 24x24 icon so ball icon is centered at ball position
		_minimap_ball_icon.position = screen_pos - Vector2(12, 12)
		_minimap_ball_icon.visible = true
	else:
		_minimap_ball_icon.visible = false


func _is_desktop() -> bool:
	if MobilePerformance.is_mobile():
		return false
	if DisplayServer.is_touchscreen_available() and not (OS.has_feature("pc") or OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux")):
		return false
	return true


func _set_minimap_enlarged(enlarged: bool) -> void:
	if not _is_desktop():
		return
	if _minimap_panel == null or _minimap_container == null:
		return
	if _is_minimap_enlarged == enlarged:
		return
	_is_minimap_enlarged = enlarged

	if _minimap_tween != null and _minimap_tween.is_valid():
		_minimap_tween.kill()

	var target_container_size = MINIMAP_ENLARGED_SIZE if enlarged else _get_normal_minimap_container_size()
	var target_panel_size = target_container_size + MINIMAP_PANEL_PADDING
	var duration = 0.22 if enlarged else 0.18

	if enlarged:
		_minimap_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if _minimap_panel != null:
			_minimap_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_minimap_container.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if _minimap_panel != null:
			_minimap_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW

	_minimap_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_minimap_tween.tween_property(_minimap_panel, "custom_minimum_size", target_panel_size, duration)
	_minimap_tween.tween_property(_minimap_panel, "size", target_panel_size, duration)
	_minimap_tween.tween_property(_minimap_container, "custom_minimum_size", target_container_size, duration)
	_minimap_tween.tween_property(_minimap_container, "size", target_container_size, duration)
	if _minimap_viewport != null:
		_minimap_tween.tween_property(_minimap_viewport, "size", target_container_size, duration)
	if _minimap_hint_label != null:
		var target_alpha = 1.0 if enlarged else 0.0
		_minimap_tween.tween_property(_minimap_hint_label, "modulate:a", target_alpha, duration)
	_minimap_tween.chain().tween_callback(_update_minimap)


func _on_minimap_mouse_entered() -> void:
	if not _is_desktop():
		return
	# Don't enlarge if overlays, modals or full aerial view are active
	if hud_scorecard.visible or hud_manage_players.visible or hud_overview.visible:
		return
	if course_instance != null and course_instance.get("is_aerial_view") == true:
		return
	_set_minimap_enlarged(true)


func _on_minimap_mouse_exited() -> void:
	if not _is_desktop():
		return
	if _minimap_panel != null and _minimap_panel.is_visible_in_tree():
		var m_pos = _minimap_panel.get_global_mouse_position()
		if _minimap_panel.get_global_rect().has_point(m_pos):
			return # Still inside the panel (e.g. over child controls)
	_set_minimap_enlarged(false)


func _on_minimap_gui_input(event: InputEvent) -> void:
	if _minimap_camera == null or course_instance == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_minimap_aim_at_screen_pos(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			minimap_zoom = clamp(minimap_zoom - 25.0, 50.0, 500.0)
			if _last_zoom_zone == 0:
				_teebox_minimap_zoom = minimap_zoom
				_default_non_green_minimap_zoom = minimap_zoom
			_update_minimap()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			minimap_zoom = clamp(minimap_zoom + 25.0, 50.0, 500.0)
			if _last_zoom_zone == 0:
				_teebox_minimap_zoom = minimap_zoom
				_default_non_green_minimap_zoom = minimap_zoom
			_update_minimap()


func _handle_minimap_aim_at_screen_pos(click_pos: Vector2) -> void:
	if _minimap_camera == null or course_instance == null or _minimap_viewport == null:
		return

	var ball = active_ball
	if ball == null:
		var player_node = course_instance.get_node_or_null("Player")
		if player_node != null:
			ball = player_node.get("ball")
	if ball == null:
		return
	if ball.get("state") != PhysicsEnums.BallState.REST:
		return

	var c_size = _minimap_container.size if _minimap_container != null else Vector2(180, 180)
	var vp_size = Vector2(_minimap_viewport.size)
	var norm_x = clampf(click_pos.x / maxf(c_size.x, 1.0), 0.0, 1.0)
	var norm_y = clampf(click_pos.y / maxf(c_size.y, 1.0), 0.0, 1.0)
	var vp_click = Vector2(norm_x * vp_size.x, norm_y * vp_size.y)

	var ray_start = _minimap_camera.project_ray_origin(vp_click)
	var ray_dir = _minimap_camera.project_ray_normal(vp_click)
	var ray_end = ray_start + ray_dir * 1000.0

	var space_state = course_instance.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if ball != null:
		query.exclude = [ball.get_rid()]
	var hit = space_state.intersect_ray(query)

	var target_pos: Vector3
	if not hit.is_empty():
		target_pos = hit["position"]
	else:
		var ground_h = 0.0
		if course_instance.has_method("get_height"):
			ground_h = course_instance.call("get_height", ray_start.x, ray_start.z)
		target_pos = Vector3(ray_start.x, ground_h, ray_start.z)

	if course_instance.has_method("get_height"):
		target_pos.y = course_instance.call("get_height", target_pos.x, target_pos.z)

	var ball_pos = ball.global_position
	var diff_2d = Vector2(target_pos.x - ball_pos.x, target_pos.z - ball_pos.z)
	if diff_2d.length() < 1.5:
		return

	aim_at_world_position(target_pos)


func aim_at_world_position(target_pos: Vector3) -> void:
	if course_instance == null:
		return
	var player_node = course_instance.get_node_or_null("Player")
	var ball = active_ball
	if ball == null and player_node != null:
		ball = player_node.get("ball")
	if ball == null:
		return
	if ball.get("state") != PhysicsEnums.BallState.REST:
		return

	var ball_pos = ball.global_position
	var diff = target_pos - ball_pos
	var angle_rad = atan2(diff.z, diff.x)
	var aim_yaw = rad_to_deg(-angle_rad)

	# Update course_instance aim target if method exists
	if course_instance.has_method("set_aim_target"):
		course_instance.call("set_aim_target", target_pos, true)
	else:
		if "_aim_is_manual" in course_instance:
			course_instance.set("_aim_is_manual", true)
		course_instance.set("aim_target_pos", target_pos)
		ball.set("aim_yaw_offset_deg", aim_yaw)
		if course_instance.has_node("AimMarker"):
			var marker = course_instance.get_node("AimMarker")
			marker.global_position = target_pos
			marker.visible = true
		if course_instance.has_method("set_aim_distance"):
			course_instance.call("set_aim_distance", int(ball_pos.distance_to(target_pos) * 1.09361))

	# Keep course_instance and ball yaw in sync
	ball.set("aim_yaw_offset_deg", aim_yaw)
	course_instance.set("aim_target_pos", target_pos)

	# Position the address camera behind the ball facing the new aim target
	var camera = course_instance.get_node_or_null("PhantomCamera3D")
	if camera != null:
		camera.follow_mode = PhantomCamera3D.FollowMode.NONE
		camera.look_at_mode = PhantomCamera3D.LookAtMode.NONE
		var is_on_green = false
		var lie = str(ball.get("lie_type")).to_lower()
		is_on_green = (lie == "green")
		if not is_on_green and course_instance.has_method("is_ball_on_green"):
			is_on_green = bool(course_instance.call("is_ball_on_green"))

		var cam_pos: Vector3
		if course_instance.has_method("get_address_camera_position"):
			cam_pos = course_instance.call("get_address_camera_position", ball_pos, -angle_rad, is_on_green)
		else:
			var cam_dist = GlobalSettings.range_settings.camera_distance.value
			var cam_height = GlobalSettings.range_settings.camera_height.value
			var local_offset = Vector3(-1.35, 0.8, 0) if is_on_green else Vector3(-cam_dist, cam_height, 0)
			if course_instance.has_method("get_camera_local_offset"):
				local_offset = course_instance.call("get_camera_local_offset", is_on_green)
			var rotated_offset = local_offset.rotated(Vector3.UP, -angle_rad)
			cam_pos = ball_pos + rotated_offset
		if course_instance.has_method("clamp_camera_position"):
			cam_pos = course_instance.call("clamp_camera_position", cam_pos)
		elif course_instance.has_method("get_height"):
			var min_y = course_instance.call("get_height", cam_pos.x, cam_pos.z) + 0.35
			if cam_pos.y < min_y:
				cam_pos.y = min_y
		camera.global_position = cam_pos

		var target_look: Vector3
		if course_instance.has_method("get_camera_target_look"):
			target_look = course_instance.call("get_camera_target_look", target_pos, ball_pos, is_on_green)
		elif is_on_green:
			var dist = ball_pos.distance_to(target_pos)
			var look_dist = clamp(dist * 0.4, 2.0, 6.0)
			if dist < 2.0:
				look_dist = dist
			var fraction = clamp(look_dist / max(dist, 0.001), 0.0, 1.0)
			target_look = ball_pos.lerp(target_pos, fraction)
		else:
			var dist = ball_pos.distance_to(target_pos) if not target_pos.is_zero_approx() else 50.0
			var aim_dir = (target_pos - ball_pos).normalized() if not target_pos.is_zero_approx() else Vector3.ZERO
			if aim_dir.is_zero_approx():
				aim_dir = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(aim_yaw))
			var look_dist = clampf(dist, 10.0, 50.0)
			var t = clampf(look_dist / maxf(dist, 0.001), 0.0, 1.0)
			var base_look_pos = ball_pos.lerp(target_pos, t) if not target_pos.is_zero_approx() else (ball_pos + aim_dir * 50.0)
			target_look = base_look_pos + Vector3.UP * 1.0
		camera.look_at(target_look)
		if camera.camera_3d_resource != null:
			camera.camera_3d_resource.fov = GlobalSettings.range_settings.camera_fov.value

		var cam3d = course_instance.get_node_or_null("Camera3D")
		if cam3d != null:
			cam3d.global_position = cam_pos
			cam3d.look_at(target_look)
			cam3d.fov = GlobalSettings.range_settings.camera_fov.value

		if has_node("/root/ScreenOffsetManager"):
			var som = get_node("/root/ScreenOffsetManager")
			var cam_to_register = camera if camera != null else cam3d
			if cam_to_register != null:
				som.call("register_camera", cam_to_register)
			som.call("set_putter_active", is_default_club_putter())
			som.call("on_ready_for_shot")

	if player_node != null:
		player_node.set("_last_aim_target_pos", target_pos)
		player_node.set("_last_aim_yaw_offset_deg", aim_yaw)

	if has_node("/root/MultiplayerManager") and not MultiplayerManager.players.is_empty():
		var ap = MultiplayerManager.get_active_player()
		if not ap.is_empty():
			ap["last_aim_target_pos"] = target_pos
			ap["last_aim_yaw_offset_deg"] = aim_yaw

	var dist_yds = int(ball_pos.distance_to(target_pos) * 1.09361)
	if _minimap_hint_label != null:
		_minimap_hint_label.text = "🎯 Aim: %d YDS" % dist_yds

	_update_minimap()


func apply_material_button_style(btn: Button, bg_color: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 20 # Pill style
	style_normal.corner_radius_top_right = 20
	style_normal.corner_radius_bottom_left = 20
	style_normal.corner_radius_bottom_right = 20
	style_normal.content_margin_left = 18
	style_normal.content_margin_right = 18
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)

	var style_focus = style_normal.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_stylebox_override("focus", style_focus)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	if not btn.has_theme_font_size_override("font_size"):
		btn.add_theme_font_size_override("font_size", 16)
	if btn.custom_minimum_size.y < 48:
		btn.custom_minimum_size.y = 48


func apply_circular_button_style(btn: Button, bg_color: Color):
	var radius = int(btn.custom_minimum_size.y / 2.0) if btn.custom_minimum_size.y > 0 else 32
	var margin = int(btn.custom_minimum_size.y * 0.18) if btn.custom_minimum_size.y > 0 else 10
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = radius
	style_normal.corner_radius_top_right = radius
	style_normal.corner_radius_bottom_left = radius
	style_normal.corner_radius_bottom_right = radius
	style_normal.content_margin_left = margin
	style_normal.content_margin_right = margin
	style_normal.content_margin_top = margin
	style_normal.content_margin_bottom = margin

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.4)

	var style_circ_focus = style_normal.duplicate()
	style_circ_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_circ_focus.border_width_left = 3
	style_circ_focus.border_width_top = 3
	style_circ_focus.border_width_right = 3
	style_circ_focus.border_width_bottom = 3

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_stylebox_override("focus", style_circ_focus)


func update_map_button_text(is_aerial: bool) -> void:
	var target_btn = map_btn
	if target_btn == null:
		for child in get_children():
			if child is CanvasLayer:
				target_btn = child.get_node_or_null("MapButton")
				if target_btn != null:
					break
				
	if target_btn != null:
		target_btn.text = ""
		var key_str = KeybindingManager.get_action_summary_str("aerial_aim") if has_node("/root/KeybindingManager") else "A"
		if is_aerial:
			target_btn.tooltip_text = "Return to Player [%s]" % key_str
			apply_circular_button_style(target_btn, Color(0.2, 0.7, 0.35, 0.95))
		else:
			target_btn.tooltip_text = "Toggle Map View [%s]" % key_str
			apply_circular_button_style(target_btn, Color(0.18, 0.45, 0.25, 0.85))


func _update_helpers_scroll_layout() -> void:
	if right_panel == null:
		return
	if toggles_scroll == null:
		toggles_scroll = right_panel.get_node_or_null("TogglesScroll")
	if toggles_scroll == null:
		return
	var v_bar = toggles_scroll.get_v_scroll_bar()
	var is_bar_visible = v_bar != null and v_bar.visible and toggles_scroll.visible
	var scroll_w = int(v_bar.size.x) if (v_bar != null and is_bar_visible) else 0
	if scroll_w <= 0 and is_bar_visible and v_bar != null:
		scroll_w = int(v_bar.custom_minimum_size.x)
	var shift = (scroll_w + 6) if scroll_w > 0 else 0

	var dist_menu = toggles_scroll.find_child("DistanceMenu", true, false)
	var is_dist_menu_visible = dist_menu != null and is_instance_valid(dist_menu) and dist_menu.visible and toggles_scroll.visible
	var dist_shift = 0
	if is_dist_menu_visible:
		var is_mob = MobilePerformance.is_mobile()
		dist_shift = 220 if is_mob else 160

	right_panel.offset_left = -280 - shift - dist_shift


func _set_helpers_visible(is_vis: bool) -> void:
	if toggles_scroll == null and right_panel != null:
		toggles_scroll = right_panel.get_node_or_null("TogglesScroll")
	if toggles_scroll != null:
		toggles_scroll.visible = is_vis
	if hide_helpers_btn != null:
		if is_vis:
			apply_circular_button_style(hide_helpers_btn, Color(0.25, 0.45, 0.7, 0.9))
		else:
			apply_circular_button_style(hide_helpers_btn, Color(0.15, 0.15, 0.15, 0.85))
	_update_hud_focus_neighbors()
	_update_helpers_scroll_layout()


func update_practice_ui_visibility(is_aerial: bool) -> void:
	for child in get_children():
		if child is CanvasLayer:
			var panel = child.get_node_or_null("RightPanel")
			if panel != null:
				var place_btn = panel.get_node_or_null("TogglesScroll/TogglesContainer/PlaceBallButton")
				var prev_btn = panel.get_node_or_null("TogglesScroll/TogglesContainer/PrevHoleButton")
				var next_btn = panel.get_node_or_null("TogglesScroll/TogglesContainer/NextHoleButton")
				if place_btn == null:
					place_btn = panel.get_node_or_null("TogglesContainer/PlaceBallButton")
					prev_btn = panel.get_node_or_null("TogglesContainer/PrevHoleButton")
					next_btn = panel.get_node_or_null("TogglesContainer/NextHoleButton")
				if place_btn == null:
					place_btn = panel.get_node_or_null("PlaceBallButton")
					prev_btn = panel.get_node_or_null("PrevHoleButton")
					next_btn = panel.get_node_or_null("NextHoleButton")
				if place_btn != null:
					place_btn.visible = is_aerial
				if prev_btn != null:
					prev_btn.visible = is_aerial
				if next_btn != null:
					next_btn.visible = is_aerial

	if MultiplayerManager.practice_mode_active and not GlobalSettings.is_chipping_minigame:
		if is_aerial:
			if not _is_aerial_active_practice:
				_was_helpers_visible_before_aerial = toggles_scroll.visible if toggles_scroll != null else false
				_is_aerial_active_practice = true
			_set_helpers_visible(true)
		else:
			if _is_aerial_active_practice:
				_set_helpers_visible(_was_helpers_visible_before_aerial)
				_is_aerial_active_practice = false


func _on_scorecard_toggle_pressed() -> void:
	if hud_manage_players.visible:
		_close_manage_players_panel()
	if hud_overview.visible:
		hud_overview.visible = false
	if hud_scorecard.visible:
		if has_node("/root/UIFocusGuard"):
			var guard = get_node("/root/UIFocusGuard")
			if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
				guard.pop_lock(hud_scorecard, false)
		_stop_scorecard_countdown()
		hud_scorecard.visible = false
		_scorecard_selected_hole_index = -1
		_scorecard_settings_mode = false
		_update_scorecard_settings_button_style()
		_set_other_elements_visible(true)
	else:
		if _scorecard_selected_hole_index < 0:
			_scorecard_selected_hole_index = MultiplayerManager.current_hole_index
		hud_scorecard.visible = true
		_populate_scorecard("toggle")
		_set_other_elements_visible(false)
		if has_node("/root/UIFocusGuard"):
			var guard = get_node("/root/UIFocusGuard")
			guard.push_lock(hud_scorecard)
		_focus_selected_hole_button()


func _get_hole_distance(hole_id: String, tee_color: String) -> int:
	var hole = MultiplayerManager.hole_info.get(hole_id, {})
	var tee_boxes = hole.get("Tee Boxes", {})
	var tee_pos = MultiplayerManager.get_tee_position_from_boxes(tee_boxes, tee_color)
	var hole_loc = hole.get("Hole Location", [0.0, 0.0])
	if tee_pos != null and tee_pos.size() >= 2 and hole_loc != null and hole_loc.size() >= 2:
		var t_vec = Vector2(tee_pos[0], tee_pos[1])
		var h_vec = Vector2(hole_loc[0], hole_loc[1])
		return int(t_vec.distance_to(h_vec) * 1.09361)
	return 0


func _get_hole_shot_positions(player: Dictionary, hole_id: String, tee_boxes: Dictionary, world_to_course: Transform3D) -> Array[Vector3]:
	var shot_stats: Array = []
	var player_stats = player.get("shot_stats", {})
	if typeof(player_stats) == TYPE_DICTIONARY and player_stats.has(hole_id) and typeof(player_stats[hole_id]) == TYPE_ARRAY:
		shot_stats = player_stats[hole_id]

	var fallback_positions: Array[Vector3] = []
	var tee_position: Array = MultiplayerManager.get_tee_position_from_boxes(tee_boxes, player.get("tee", "Blue"))
	if tee_position.size() >= 2:
		fallback_positions.append(Vector3(float(tee_position[0]), 0.0, float(tee_position[1])))
	var is_current_hole = (MultiplayerManager.current_hole_index < MultiplayerManager.hole_ids.size() and MultiplayerManager.hole_ids[MultiplayerManager.current_hole_index] == hole_id)
	if is_current_hole:
		var shot_history = player.get("shot_history", [])
		if typeof(shot_history) == TYPE_ARRAY:
			for end_position in shot_history:
				if typeof(end_position) == TYPE_VECTOR3:
					fallback_positions.append(world_to_course * end_position)
	return HoleShotPathDiagram.get_positions_from_shot_stats(shot_stats, fallback_positions, world_to_course)


func _populate_hole_shot_summary(action_type: String) -> void:
	if _hole_shot_summary == null:
		return
	for child in _hole_shot_summary.get_children():
		_hole_shot_summary.remove_child(child)
		child.queue_free()
	_hole_shot_summary.visible = (action_type == "hole_completed" or action_type == "toggle")
	if not _hole_shot_summary.visible or MultiplayerManager.hole_ids.is_empty():
		return

	var hole_index = _scorecard_selected_hole_index
	if hole_index < 0 or hole_index >= MultiplayerManager.hole_ids.size():
		hole_index = MultiplayerManager.current_hole_index
	if hole_index < 0 or hole_index >= MultiplayerManager.hole_ids.size():
		return
	var hole_id: String = MultiplayerManager.hole_ids[hole_index]
	var active_hole_num = MultiplayerManager.get_hole_number_from_id(hole_id, hole_index)

	var player_order: Array[Dictionary] = []
	for player_index in range(MultiplayerManager.players.size()):
		var player: Dictionary = MultiplayerManager.players[player_index]
		var hole_scores: Dictionary = player.get("hole_scores", {})
		var score = hole_scores.get(hole_id)
		if score == null and player.get("active", true) and hole_index == MultiplayerManager.current_hole_index:
			score = player.get("strokes", 0)
		var previous_hole_id = MultiplayerManager.hole_ids[hole_index - 1] if hole_index > 0 else ""
		var previous_score = hole_scores.get(previous_hole_id) if not previous_hole_id.is_empty() else null
		player_order.append({
			"player": player,
			"score": int(round(float(score))) if score != null else 2147483647,
			"previous_score": int(round(float(previous_score))) if previous_score != null else 2147483647,
			"player_index": player_index
		})
	player_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] < b["score"]
		if a["previous_score"] != b["previous_score"]:
			return a["previous_score"] < b["previous_score"]
		return a["player_index"] < b["player_index"]
	)

	var current_hole: Dictionary = MultiplayerManager.hole_info.get(hole_id, {})
	var tee_boxes: Dictionary = current_hole.get("Tee Boxes", {})
	var hole_location: Array = current_hole.get("Hole Location", [0.0, 0.0])
	var green_position := Vector3.ZERO
	if hole_location.size() >= 2:
		green_position = Vector3(float(hole_location[0]), 0.0, float(hole_location[1]))
	var course_manager = get_node_or_null("/root/CourseManager") if is_inside_tree() else null
	var config_path: String = course_manager.call("get_current_config_path") if course_manager != null and course_manager.has_method("get_current_config_path") else ""
	var satellite_path = config_path.get_base_dir().path_join("satellite.png") if not config_path.is_empty() else ""
	var satellite_image: Image = null
	var satellite_texture: Texture2D = null
	if not satellite_path.is_empty() and FileAccess.file_exists(satellite_path):
		satellite_image = Image.load_from_file(satellite_path)
		if satellite_image.is_empty():
			push_warning("[CoursePlay] Could not load satellite image for shot summary: %s" % satellite_path)
		else:
			satellite_texture = ImageTexture.create_from_image(satellite_image)
	var course_info_value = course_manager.get("course_info") if course_manager != null else {}
	var course_info: Dictionary = course_info_value if typeof(course_info_value) == TYPE_DICTIONARY else {}
	var satellite_bounds: Array = []
	var bounds_version := int(course_info.get("Satellite Image Bounds Version", 0))
	if bounds_version == 5:
		var saved_satellite_bounds = course_info.get("Satellite Image Bounds", [])
		if typeof(saved_satellite_bounds) == TYPE_ARRAY:
			satellite_bounds = saved_satellite_bounds
	var cart_paths: Array[PackedVector2Array] = []
	var saved_cart_paths = course_info.get("Cart Paths", [])
	if typeof(saved_cart_paths) == TYPE_ARRAY:
		for saved_path in saved_cart_paths:
			if typeof(saved_path) != TYPE_ARRAY:
				continue
			var cart_path := PackedVector2Array()
			for saved_point in saved_path:
				if typeof(saved_point) == TYPE_ARRAY and saved_point.size() >= 2:
					cart_path.append(Vector2(float(saved_point[0]), float(saved_point[1])))
			if cart_path.size() >= 2:
				cart_paths.append(cart_path)

	# Section Header for Shot Review
	var header_box = VBoxContainer.new()
	header_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_theme_constant_override("separation", 2)
	_hole_shot_summary.add_child(header_box)
	
	var title_lbl = Label.new()
	title_lbl.name = "HoleShotTitleLabel"
	var hole_par = int(round(float(current_hole.get("Par", 4))))
	title_lbl.text = "Hole %s Shot Review (Par %d)" % [active_hole_num, hole_par]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 3)
	header_box.add_child(title_lbl)
	
	var hint_lbl = Label.new()
	hint_lbl.name = "HoleShotHintLabel"
	var has_controller := false
	if is_inside_tree() and has_node("/root/KeybindingManager"):
		var km = get_node("/root/KeybindingManager")
		if km.has_method("is_controller_connected"):
			has_controller = km.is_controller_connected()
	elif Input.get_connected_joypads().size() > 0:
		has_controller = true
	if has_controller:
		hint_lbl.text = "Select any hole number above or use LB / RB to review shot history"
	else:
		hint_lbl.text = "Select any hole number above to view shot history"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.68, 0.74, 0.84))
	header_box.add_child(hint_lbl)

	# Centering wrapper for cards
	var cards_wrapper = HBoxContainer.new()
	cards_wrapper.name = "HoleShotCardsWrapper"
	cards_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hole_shot_summary.add_child(cards_wrapper)

	var player_cards = GridContainer.new()
	player_cards.name = "HoleShotPlayerCards"
	player_cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	player_cards.add_theme_constant_override("h_separation", 16)
	player_cards.add_theme_constant_override("v_separation", 16)
	cards_wrapper.add_child(player_cards)

	var vp = get_viewport()
	var vp_size = vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)
	var cards_available_width = maxf(vp_size.x * 0.90 - 64.0, 320.0)
	var max_cols = mini(player_order.size(), maxi(1, int(floor((cards_available_width + 16.0) / 240.0))))
	player_cards.columns = max_cols
	
	var num_card_rows = int(ceil(float(player_order.size()) / float(max_cols)))

	# Dynamically calculate available vertical budget so the scorecard NEVER spawns or needs a scrollbar
	var modal_h = vp_size.y * 0.94
	var vbox_total_h = modal_h - 32.0 # 16px margins top & bottom in hud_scorecard
	var has_filter_tabs = (MultiplayerManager.hole_ids.size() > 9)
	# Fixed VBox elements: Title (44px), filter tabs if >9 holes (46px), actions row (54px), separations (28-42px) & buffer (16px)
	var vbox_overhead = (184.0 if has_filter_tabs else 126.0) + 16.0
	var scroll_avail_h = maxf(vbox_total_h - vbox_overhead, 180.0)

	# Content overhead in ScorecardContent: Grid rows (40px per row), add-player bar if visible, separations, summary header
	var num_players_in_grid = MultiplayerManager.players.size()
	var grid_h = float(3 + num_players_in_grid) * 40.0
	var add_player_h = 68.0 if (_scorecard_add_player_section != null and _scorecard_add_player_section.visible) else 0.0
	var content_separations = 16.0 + (16.0 if add_player_h > 0.0 else 0.0)
	var summary_header_h = 48.0 + 8.0 # Header labels + summary separation
	var non_cards_scroll_h = grid_h + add_player_h + content_separations + summary_header_h

	# Player card overhead: vertical gaps between rows + card padding & labels (~58px per row)
	var card_row_gaps = float(maxi(0, num_card_rows - 1)) * 16.0
	var card_overhead_total = float(num_card_rows) * 58.0

	var avail_for_diagrams = maxf(scroll_avail_h - non_cards_scroll_h - card_row_gaps - card_overhead_total, 120.0)
	var max_allowed_image_height = maxf(avail_for_diagrams / float(num_card_rows), 120.0)

	var max_width_per_col = (cards_available_width - float(max_cols - 1) * 16.0) / float(max_cols)
	var card_width = clampf(max_width_per_col, 200.0, 480.0)
	var max_image_width = card_width - 24.0

	# Scale image height proportionally to fit within available vertical budget
	var image_height = clampf(max_allowed_image_height, 120.0, 460.0)
	var desired_image_width = image_height / 1.15
	var image_width: float = 0.0
	if desired_image_width > max_image_width:
		image_width = max_image_width
		image_height = minf(image_height, image_width * 1.15)
	else:
		image_width = desired_image_width
		card_width = image_width + 24.0

	var hole_tee_positions: Array[Vector3] = []
	for tee_value in tee_boxes.values():
		if typeof(tee_value) == TYPE_ARRAY and tee_value.size() >= 2:
			hole_tee_positions.append(Vector3(float(tee_value[0]), 0.0, float(tee_value[1])))
	var world_to_course := Transform3D.IDENTITY
	if course_instance is Node3D:
		world_to_course = (course_instance as Node3D).global_transform.affine_inverse()
	var shared_shot_positions: Array[Vector3] = []
	for player_entry in player_order:
		shared_shot_positions.append_array(_get_hole_shot_positions(player_entry["player"], hole_id, tee_boxes, world_to_course))
	for rank in range(player_order.size()):
		var player: Dictionary = player_order[rank]["player"]
		var positions := _get_hole_shot_positions(player, hole_id, tee_boxes, world_to_course)

		var shot_distances: Array[int] = []
		for shot_index in range(maxi(0, positions.size() - 1)):
			var start_position = positions[shot_index]
			var end_position = positions[shot_index + 1]
			var distance_yards = Vector2(start_position.x, start_position.z).distance_to(Vector2(end_position.x, end_position.z)) * 1.09361
			shot_distances.append(int(round(distance_yards)))

		var player_card = PanelContainer.new()
		player_card.custom_minimum_size = Vector2(card_width, 0)
		player_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.corner_radius_top_left = 16
		card_style.corner_radius_top_right = 16
		card_style.corner_radius_bottom_left = 16
		card_style.corner_radius_bottom_right = 16
		var player_color := Color(0.35, 0.65, 0.9)
		var color_value = player.get("color")
		if typeof(color_value) == TYPE_COLOR:
			player_color = color_value
		var is_hole_winner = player_order[rank]["score"] == player_order[0]["score"] and player_order[rank]["score"] < 2147483647
		card_style.border_color = Color(0.72, 0.56, 0.24, 0.85) if is_hole_winner else player_color
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 10
		card_style.content_margin_bottom = 12
		player_card.add_theme_stylebox_override("panel", card_style)
		var player_row = VBoxContainer.new()
		player_row.add_theme_constant_override("separation", 6)
		player_card.add_child(player_row)

		var score_label = Label.new()
		var has_score = (player_order[rank]["score"] != 2147483647)
		var score_text = "%d strokes" % player_order[rank]["score"] if has_score else "No score"
		if not has_score and shot_distances.is_empty():
			score_label.text = "%d. %s — Not played" % [rank + 1, player.get("name", "Player")]
		else:
			score_label.text = "%d. %s — %s · %d shots" % [rank + 1, player.get("name", "Player"), score_text, shot_distances.size()]
		score_label.add_theme_font_size_override("font_size", 17)
		score_label.add_theme_color_override("font_color", Color.WHITE)
		player_row.add_child(score_label)

		if shot_distances.is_empty():
			var no_shots_panel = PanelContainer.new()
			no_shots_panel.custom_minimum_size = Vector2(image_width, minf(160.0, image_height))
			var no_shots_style = StyleBoxFlat.new()
			no_shots_style.bg_color = Color(0.06, 0.08, 0.12, 0.6)
			no_shots_style.border_width_left = 1
			no_shots_style.border_width_top = 1
			no_shots_style.border_width_right = 1
			no_shots_style.border_width_bottom = 1
			no_shots_style.border_color = Color(0.25, 0.3, 0.4, 0.4)
			no_shots_style.corner_radius_top_left = 12
			no_shots_style.corner_radius_top_right = 12
			no_shots_style.corner_radius_bottom_left = 12
			no_shots_style.corner_radius_bottom_right = 12
			no_shots_panel.add_theme_stylebox_override("panel", no_shots_style)
			
			var no_shots_label = Label.new()
			if not has_score:
				no_shots_label.text = "Hole %s has not been played" % active_hole_num
			else:
				no_shots_label.text = "No shots recorded for Hole %s" % active_hole_num
			no_shots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			no_shots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			no_shots_label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
			no_shots_label.add_theme_font_size_override("font_size", 14)
			no_shots_panel.add_child(no_shots_label)
			player_row.add_child(no_shots_panel)
		else:
			var diagram_frame = PanelContainer.new()
			diagram_frame.name = "DiagramFrame"
			diagram_frame.clip_contents = true
			var frame_style = StyleBoxFlat.new()
			frame_style.bg_color = Color(0.04, 0.07, 0.10, 0.95)
			frame_style.border_width_left = 1
			frame_style.border_width_top = 1
			frame_style.border_width_right = 1
			frame_style.border_width_bottom = 1
			frame_style.border_color = Color(0.35, 0.45, 0.60, 0.5)
			frame_style.corner_radius_top_left = 12
			frame_style.corner_radius_top_right = 12
			frame_style.corner_radius_bottom_left = 12
			frame_style.corner_radius_bottom_right = 12
			diagram_frame.add_theme_stylebox_override("panel", frame_style)

			var shot_path = HoleShotPathDiagram.new()
			shot_path.name = "HoleShotPathDiagram"
			shot_path.custom_minimum_size = Vector2(image_width, image_height)
			shot_path.set_shot_path(
				positions,
				shot_distances,
				green_position,
				satellite_texture,
				satellite_bounds,
				hole_tee_positions,
				shared_shot_positions,
				cart_paths
			)
			diagram_frame.add_child(shot_path)
			player_row.add_child(diagram_frame)
		player_cards.add_child(player_card)


func _refresh_scorecard_add_player_section() -> void:
	if _scorecard_add_player_section == null or not is_instance_valid(_scorecard_add_player_section):
		return
	_scorecard_add_player_section.visible = _scorecard_settings_mode and not _is_online_match()
	if not _scorecard_settings_mode or _is_online_match():
		return
	var select_opt = _scorecard_add_player_section.get_node_or_null("AddRow/PlayerSelectOpt") as OptionButton
	var name_input = _scorecard_add_player_section.get_node_or_null("AddRow/NameInput") as LineEdit
	var tee_opt = _scorecard_add_player_section.get_node_or_null("AddRow/TeeOpt") as OptionButton
	if select_opt == null or name_input == null or tee_opt == null:
		return
		
	select_opt.clear()
	select_opt.add_item("New Golfer...", 0)
	
	var active_names = []
	for p in MultiplayerManager.players:
		active_names.append(p.get("name", "").to_lower())
		
	var saved_golfers = MultiplayerManager.get_registered_players()
	var s_idx = 1
	for g in saved_golfers:
		var g_name = g.get("name", "")
		if not g_name.is_empty() and not active_names.has(g_name.to_lower()):
			select_opt.add_item(g_name, s_idx)
			s_idx += 1
			
	select_opt.selected = 0
	name_input.visible = true
	
	var prev_tee = tee_opt.get_item_text(tee_opt.selected) if tee_opt.selected >= 0 and tee_opt.item_count > 0 else ""
	tee_opt.clear()
	var course_tees = MultiplayerManager.get_course_tees()
	if course_tees.is_empty():
		course_tees = ["Blue", "Red", "White", "Black", "Gold"]
	var selected_tee_idx = 0
	for t_idx in range(course_tees.size()):
		var t_name = course_tees[t_idx]
		var t_icon = _get_tee_icon(t_name, 14)
		tee_opt.add_icon_item(t_icon, t_name, t_idx)
		if not prev_tee.is_empty() and t_name.to_lower() == prev_tee.to_lower():
			selected_tee_idx = t_idx
	if tee_opt.item_count > 0:
		tee_opt.selected = selected_tee_idx

	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		if guard.has_method("hook_option_button"):
			guard.hook_option_button(select_opt)
			guard.hook_option_button(tee_opt)


func _update_scorecard_settings_button_style() -> void:
	if _scorecard_settings_btn == null or not is_instance_valid(_scorecard_settings_btn):
		return
	if _scorecard_settings_mode:
		apply_circular_button_style(_scorecard_settings_btn, Color(0.24, 0.46, 0.72, 0.95))
		_scorecard_settings_btn.tooltip_text = "Hide Player Settings"
	else:
		apply_circular_button_style(_scorecard_settings_btn, Color(0.12, 0.16, 0.24, 0.85))
		_scorecard_settings_btn.tooltip_text = "Show Player Settings (Pause, Remove, Add Players, Change Tees)"


func _on_scorecard_settings_toggled() -> void:
	if _scorecard_countdown_active and not _scorecard_countdown_paused:
		_on_scorecard_pause_toggled()
	_scorecard_settings_mode = not _scorecard_settings_mode
	_update_scorecard_settings_button_style()
	_populate_scorecard(_last_scorecard_action_type)
	if _scorecard_settings_mode:
		if _scorecard_settings_btn != null and is_instance_valid(_scorecard_settings_btn):
			_scorecard_settings_btn.call_deferred("grab_focus")
	else:
		_focus_selected_hole_button()


func _select_scorecard_hole(hole_idx: int) -> void:
	var num_holes = MultiplayerManager.hole_ids.size()
	if num_holes == 0:
		return
	hole_idx = clampi(hole_idx, 0, num_holes - 1)
	if _scorecard_countdown_active and not _scorecard_countdown_paused:
		_on_scorecard_pause_toggled()
	_scorecard_selected_hole_index = hole_idx
	if num_holes > 9:
		if _scorecard_view_tab == "Front 9" and hole_idx >= 9:
			_scorecard_view_tab = "Back 9"
		elif _scorecard_view_tab == "Back 9" and hole_idx < 9:
			_scorecard_view_tab = "Front 9"
	_populate_scorecard(_last_scorecard_action_type)
	_focus_selected_hole_button()


func _focus_selected_hole_button() -> void:
	if not is_instance_valid(scorecard_grid) or not is_inside_tree():
		return
	var target_btn = scorecard_grid.find_child("HoleBtn_%d" % _scorecard_selected_hole_index, true, false) as Button
	if target_btn != null and target_btn.is_inside_tree() and target_btn.is_visible_in_tree():
		target_btn.call_deferred("grab_focus")
	elif scorecard_grid.get_child_count() > 0:
		for child in scorecard_grid.get_children():
			if child is Button and child.name.begins_with("HoleBtn_") and child.is_inside_tree() and child.is_visible_in_tree():
				child.call_deferred("grab_focus")
				break


func _populate_scorecard(action_type: String, focus_target_name: String = "") -> void:
	_last_scorecard_action_type = action_type
	_refresh_scorecard_add_player_section()
	_populate_hole_shot_summary(action_type)
	
	# Clear previous cells
	for child in scorecard_grid.get_children():
		scorecard_grid.remove_child(child)
		child.queue_free()
		
	var num_holes = MultiplayerManager.hole_ids.size()
	if num_holes == 0:
		return

	# Handle Filter Tabs Bar for 18-hole courses
	var vbox = hud_scorecard.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox != null:
		var filter_tabs = vbox.get_node_or_null("FilterTabs") as HBoxContainer
		if num_holes > 9:
			if filter_tabs == null:
				filter_tabs = HBoxContainer.new()
				filter_tabs.name = "FilterTabs"
				filter_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
				filter_tabs.add_theme_constant_override("separation", 12)
				var scroll_node = vbox.get_node_or_null("ScorecardScroll")
				var idx = scroll_node.get_index() if scroll_node != null else 1
				vbox.add_child(filter_tabs)
				vbox.move_child(filter_tabs, idx)
			
			# Re-populate filter buttons
			for child in filter_tabs.get_children():
				child.queue_free()
				
			var tab_options = ["All", "Front 9", "Back 9"]
			var tab_buttons: Array[Button] = []
			for tab_name in tab_options:
				var tab_btn = Button.new()
				tab_btn.name = "TabBtn_%s" % tab_name.replace(" ", "")
				tab_btn.text = tab_name
				tab_btn.custom_minimum_size = Vector2(110, 42)
				var is_selected = (_scorecard_view_tab == tab_name)
				var btn_bg = Color(0.24, 0.46, 0.72, 0.95) if is_selected else Color(0.12, 0.16, 0.24, 0.75)
				apply_material_button_style(tab_btn, btn_bg)
				tab_btn.focus_mode = Control.FOCUS_ALL
				if is_selected:
					tab_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
				tab_btn.pressed.connect(func():
					_scorecard_view_tab = tab_name
					_populate_scorecard(_last_scorecard_action_type)
					_focus_selected_hole_button()
				)
				filter_tabs.add_child(tab_btn)
				tab_buttons.append(tab_btn)
			
			for t_i in range(tab_buttons.size()):
				if is_inside_tree() and tab_buttons[t_i].is_inside_tree():
					if t_i > 0 and tab_buttons[t_i - 1].is_inside_tree():
						tab_buttons[t_i].focus_neighbor_left = tab_buttons[t_i - 1].get_path()
					if t_i < tab_buttons.size() - 1 and tab_buttons[t_i + 1].is_inside_tree():
						tab_buttons[t_i].focus_neighbor_right = tab_buttons[t_i + 1].get_path()
		elif filter_tabs != null:
			filter_tabs.visible = false
		
	# Determine active tee color for distance row
	var active_player = MultiplayerManager.get_active_player()
	var tee_color = active_player.get("tee", "Blue") if not active_player.is_empty() else "Blue"
	
	# Split into Front 9 and Back 9
	var front_holes = []
	var back_holes = []
	for i in range(num_holes):
		var hole_id = MultiplayerManager.hole_ids[i]
		if i < 9:
			front_holes.append(hole_id)
		else:
			back_holes.append(hole_id)
			
	# Columns configuration based on selected view tab
	var columns = ["Player"]
	var column_hole_indices: Array[int] = [-1]
	var render_front = (_scorecard_view_tab == "All" or _scorecard_view_tab == "Front 9")
	var render_back = (num_holes > 9 and (_scorecard_view_tab == "All" or _scorecard_view_tab == "Back 9"))
	
	if render_front:
		for i in range(front_holes.size()):
			columns.append(str(MultiplayerManager.get_hole_number_from_id(front_holes[i], i)))
			column_hole_indices.append(i)
		if num_holes > 9 and _scorecard_view_tab == "All":
			columns.append("OUT")
			column_hole_indices.append(-1)
		elif _scorecard_view_tab == "Front 9":
			columns.append("OUT")
			column_hole_indices.append(-1)
			
	if render_back:
		for i in range(back_holes.size()):
			columns.append(str(MultiplayerManager.get_hole_number_from_id(back_holes[i], 9 + i)))
			column_hole_indices.append(9 + i)
		columns.append("IN")
		column_hole_indices.append(-1)
		
	if _scorecard_view_tab == "All":
		columns.append("TOT")
		column_hole_indices.append(-1)
		
	scorecard_grid.columns = columns.size()
	
	var header_bg = Color(0.10, 0.14, 0.22, 0.96)
	if _scorecard_selected_hole_index < 0 or _scorecard_selected_hole_index >= num_holes:
		_scorecard_selected_hole_index = MultiplayerManager.current_hole_index
	if _scorecard_selected_hole_index < 0 or _scorecard_selected_hole_index >= num_holes:
		_scorecard_selected_hole_index = 0
		
	var active_hole_id = MultiplayerManager.hole_ids[_scorecard_selected_hole_index] if _scorecard_selected_hole_index < num_holes else ""
	var active_hole_num = MultiplayerManager.get_hole_number_from_id(active_hole_id, _scorecard_selected_hole_index)
	
	# Helper for cell creation with crisp, compact styling
	var add_cell = func(text: String, bg: Color, is_header: bool = false, fg: Color = Color.WHITE, font_size: int = 16, is_active: bool = false, min_width: float = 48.0):
		var cell = PanelContainer.new()
		cell.custom_minimum_size = Vector2(min_width, 38)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_FILL
		
		var style = StyleBoxFlat.new()
		if is_active:
			style.bg_color = bg.lerp(Color(0.20, 0.42, 0.68, 0.95), 0.35)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.35, 0.72, 1.0, 0.85) # Crisp blue accent border for current active hole
		else:
			style.bg_color = bg
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.35, 0.45, 0.35)
			
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		cell.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", fg)
		label.add_theme_font_size_override("font_size", font_size)
		if is_header or is_active:
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
		cell.add_child(label)
		scorecard_grid.add_child(cell)

	# Helper for score cells with golfer lingo badges (circles for under par, squares for over par)
	var add_score_cell = func(text: String, par: int, bg: Color, is_active: bool = false, is_ctp: bool = false, font_size: int = 17):
		var cell = PanelContainer.new()
		cell.custom_minimum_size = Vector2(48, 38)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_FILL
		
		var style = StyleBoxFlat.new()
		if is_active:
			style.bg_color = bg.lerp(Color(0.20, 0.42, 0.68, 0.95), 0.35)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.35, 0.72, 1.0, 0.85)
		else:
			style.bg_color = bg
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.35, 0.45, 0.35)
			
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		cell.add_theme_stylebox_override("panel", style)
		
		var widget = ScorecardBadge.create_score_widget(text, par, is_ctp, font_size)
		cell.add_child(widget)
		scorecard_grid.add_child(cell)

	var player_col_width = 240.0 if not _scorecard_settings_mode else 400.0
	
	# --- 1. HEADER ROW ---
	var hole_buttons: Array[Button] = []
	for c_idx in range(columns.size()):
		var col = columns[c_idx]
		var h_idx = column_hole_indices[c_idx]
		var is_hole_col = (h_idx >= 0)
		var is_act = (is_hole_col and h_idx == _scorecard_selected_hole_index)
		
		if is_hole_col:
			var btn = Button.new()
			btn.name = "HoleBtn_%d" % h_idx
			btn.custom_minimum_size = Vector2(48, 38)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_FILL
			btn.text = col
			btn.focus_mode = Control.FOCUS_ALL
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.add_theme_font_size_override("font_size", 16)
			btn.tooltip_text = "View Hole %s shot history" % col
			
			var style_norm = StyleBoxFlat.new()
			if is_act:
				style_norm.bg_color = header_bg.lerp(Color(0.20, 0.42, 0.68, 0.95), 0.35)
				style_norm.border_width_left = 1
				style_norm.border_width_top = 1
				style_norm.border_width_right = 1
				style_norm.border_width_bottom = 1
				style_norm.border_color = Color(0.35, 0.72, 1.0, 0.85)
			else:
				style_norm.bg_color = header_bg
				style_norm.border_width_right = 1
				style_norm.border_width_bottom = 1
				style_norm.border_color = Color(0.3, 0.35, 0.45, 0.35)
			style_norm.content_margin_left = 6
			style_norm.content_margin_right = 6
			style_norm.content_margin_top = 4
			style_norm.content_margin_bottom = 4
			
			var style_hover = style_norm.duplicate()
			style_hover.bg_color = header_bg.lerp(Color(0.25, 0.50, 0.80, 0.95), 0.5)
			style_hover.border_color = Color(0.50, 0.82, 1.0, 1.0)
			
			var style_pressed = style_hover.duplicate()
			style_pressed.bg_color = header_bg.lerp(Color(0.15, 0.35, 0.60, 0.95), 0.6)

			var style_focus = style_hover.duplicate()
			style_focus.border_color = Color(1.0, 0.85, 0.38, 1.0)
			style_focus.border_width_left = 3
			style_focus.border_width_top = 3
			style_focus.border_width_right = 3
			style_focus.border_width_bottom = 3
			
			btn.add_theme_stylebox_override("normal", style_norm)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_pressed)
			btn.add_theme_stylebox_override("focus", style_focus)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_outline_color", Color.BLACK)
			btn.add_theme_constant_override("outline_size", 3)
			
			var target_hole_idx = h_idx
			btn.pressed.connect(func():
				_select_scorecard_hole(target_hole_idx)
			)
			scorecard_grid.add_child(btn)
			hole_buttons.append(btn)
		else:
			add_cell.call(col, header_bg, true, Color.WHITE, 16, is_act, player_col_width if col == "Player" else 48.0)
		
	# --- 2. DISTANCE ROW ---
	var dist_bg = Color(0.13, 0.18, 0.28, 0.88)
	add_cell.call("Yds (%s)" % tee_color, dist_bg, false, Color(0.8, 0.8, 0.8), 15, false, player_col_width)
	
	var front_dist_sum = 0
	for i in range(front_holes.size()):
		var hole_id = front_holes[i]
		var dist = _get_hole_distance(hole_id, tee_color)
		front_dist_sum += dist
		if render_front:
			var is_act = (MultiplayerManager.get_hole_number_from_id(hole_id, i) == active_hole_num)
			add_cell.call(str(dist), dist_bg, false, Color(0.85, 0.85, 0.85), 15, is_act)
			
	if render_front and (num_holes > 9 or _scorecard_view_tab == "Front 9"):
		add_cell.call(str(front_dist_sum), dist_bg, false, Color(1.0, 0.85, 0.38), 15)
		
	var back_dist_sum = 0
	if num_holes > 9:
		for i in range(back_holes.size()):
			var hole_id = back_holes[i]
			var dist = _get_hole_distance(hole_id, tee_color)
			back_dist_sum += dist
			if render_back:
				var is_act = (MultiplayerManager.get_hole_number_from_id(hole_id, 9 + i) == active_hole_num)
				add_cell.call(str(dist), dist_bg, false, Color(0.85, 0.85, 0.85), 15, is_act)
				
		if render_back:
			add_cell.call(str(back_dist_sum), dist_bg, false, Color(1.0, 0.85, 0.38), 15)
			
	if _scorecard_view_tab == "All":
		var total_dist = front_dist_sum + (back_dist_sum if num_holes > 9 else 0)
		add_cell.call(str(total_dist), dist_bg, false, Color(1.0, 0.85, 0.38), 15)

	# --- 3. PAR ROW ---
	var par_bg = Color(0.16, 0.22, 0.34, 0.88)
	add_cell.call("Par", par_bg, false, Color(0.8, 0.8, 0.8), 15, false, player_col_width)
	
	var front_par_sum: int = 0
	for i in range(front_holes.size()):
		var hole_id = front_holes[i]
		var hole = MultiplayerManager.hole_info.get(hole_id, {})
		var par: int = int(round(float(hole.get("Par", 4))))
		front_par_sum += par
		if render_front:
			var is_act = (MultiplayerManager.get_hole_number_from_id(hole_id, i) == active_hole_num)
			add_cell.call(str(par), par_bg, false, Color(0.85, 0.85, 0.85), 15, is_act)
			
	if render_front and (num_holes > 9 or _scorecard_view_tab == "Front 9"):
		add_cell.call(str(front_par_sum), par_bg, false, Color(1.0, 0.85, 0.38), 15)
		
	var back_par_sum: int = 0
	if num_holes > 9:
		for i in range(back_holes.size()):
			var hole_id = back_holes[i]
			var hole = MultiplayerManager.hole_info.get(hole_id, {})
			var par: int = int(round(float(hole.get("Par", 4))))
			back_par_sum += par
			if render_back:
				var is_act = (MultiplayerManager.get_hole_number_from_id(hole_id, 9 + i) == active_hole_num)
				add_cell.call(str(par), par_bg, false, Color(0.85, 0.85, 0.85), 15, is_act)
				
		if render_back:
			add_cell.call(str(back_par_sum), par_bg, false, Color(1.0, 0.85, 0.38), 15)
			
	if _scorecard_view_tab == "All":
		var total_par: int = front_par_sum + (back_par_sum if num_holes > 9 else 0)
		add_cell.call(str(total_par), par_bg, false, Color(1.0, 0.85, 0.38), 15)

	var sc_title = hud_scorecard.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if sc_title != null:
		sc_title.text = "Scorecard - MODE: %s" % MultiplayerManager.game_mode.to_upper()

	# --- 4. PLAYER ROWS ---
	var current_hole_id = MultiplayerManager.hole_ids[MultiplayerManager.current_hole_index] if MultiplayerManager.current_hole_index < num_holes else ""
	var is_skins_mode = (MultiplayerManager.game_mode == "Skins")
	var is_ctp_mode = (MultiplayerManager.game_mode == "Closest to Pin")
	
	# Active player count to determine if removal is permitted (min 1 active player)
	var active_count = 0
	for plyr in MultiplayerManager.players:
		if plyr.get("active", true):
			active_count += 1
	var can_remove = (active_count > 1)
	
	for p_idx in range(MultiplayerManager.players.size()):
		var p = MultiplayerManager.players[p_idx]
		var is_p_active = p.get("active", true)
		var is_p_paused = p.get("paused", false)
		var is_p_catching_up = (MultiplayerManager.is_in_catch_up and MultiplayerManager.catch_up_player_name == p.get("name", ""))
		var row_bg = Color(0.14, 0.16, 0.20, 0.94) if p_idx % 2 == 0 else Color(0.09, 0.11, 0.14, 0.94)
		
		# Name cell
		var name_text = p["name"]
		if not p.get("team", "").is_empty() and MultiplayerManager.game_mode == "2v2 Scramble":
			name_text = "%s [%s]" % [p["name"], p["team"]]
		var status_str = ""
		var name_fg = Color.WHITE
		if not is_p_active:
			status_str = " (Out)"
			name_fg = Color(0.6, 0.6, 0.6)
		elif is_p_paused:
			status_str = " (⏸️ Paused)"
			name_fg = Color(1.0, 0.82, 0.35)
		elif is_p_catching_up:
			status_str = " (⛳ Catching up)"
			name_fg = Color(0.35, 0.85, 1.0)
			
		name_text += status_str
			
		var cell = PanelContainer.new()
		cell.custom_minimum_size = Vector2(player_col_width, 38)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_FILL
		
		var style = StyleBoxFlat.new()
		style.bg_color = row_bg
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.3, 0.35, 0.45, 0.35)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		cell.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 6)
		cell.add_child(hbox)
		
		# Avatar or Color badge
		var avatar_path = p.get("avatar", "")
		if avatar_path.is_empty():
			avatar_path = MultiplayerManager.get_player_avatar(p.get("name", ""))
		
		if not avatar_path.is_empty() and ResourceLoader.exists(avatar_path):
			var avatar_rect = TextureRect.new()
			avatar_rect.texture = load(avatar_path)
			avatar_rect.custom_minimum_size = Vector2(24, 24)
			avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(avatar_rect)
		else:
			var badge = PanelContainer.new()
			badge.custom_minimum_size = Vector2(24, 24)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			var badge_style = StyleBoxFlat.new()
			var p_color = MultiplayerManager.get_player_color(p)
			badge_style.bg_color = p_color
			badge_style.corner_radius_top_left = 12
			badge_style.corner_radius_top_right = 12
			badge_style.corner_radius_bottom_left = 12
			badge_style.corner_radius_bottom_right = 12
			badge_style.content_margin_left = 3
			badge_style.content_margin_right = 3
			badge_style.content_margin_top = 1
			badge_style.content_margin_bottom = 1
			badge.add_theme_stylebox_override("panel", badge_style)
			
			var badge_lbl = Label.new()
			badge_lbl.text = p["name"].substr(0, 1).to_upper()
			badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge_lbl.add_theme_font_size_override("font_size", 12)
			badge_lbl.add_theme_color_override("font_color", Color.WHITE)
			badge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			badge_lbl.add_theme_constant_override("outline_size", 2)
			badge.add_child(badge_lbl)
			
			hbox.add_child(badge)
		
		var label = Label.new()
		label.text = name_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", name_fg)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hbox.add_child(label)
		
		var player_tee = str(p.get("tee", "Blue"))
		if _scorecard_settings_mode:
			# Tee selector dropdown with tee color swatch icon
			var tee_opt = OptionButton.new()
			tee_opt.name = "TeeOpt"
			tee_opt.custom_minimum_size = Vector2(98, 28)
			tee_opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tee_opt.focus_mode = Control.FOCUS_ALL
			tee_opt.add_theme_font_size_override("font_size", 13)
			tee_opt.expand_icon = true
			tee_opt.add_theme_constant_override("icon_max_width", 14)
			
			var opt_style_normal = StyleBoxFlat.new()
			opt_style_normal.bg_color = Color(0.12, 0.16, 0.24, 0.85)
			opt_style_normal.border_width_left = 1
			opt_style_normal.border_width_top = 1
			opt_style_normal.border_width_right = 1
			opt_style_normal.border_width_bottom = 1
			opt_style_normal.border_color = Color(0.32, 0.42, 0.58, 0.6)
			opt_style_normal.corner_radius_top_left = 6
			opt_style_normal.corner_radius_top_right = 6
			opt_style_normal.corner_radius_bottom_left = 6
			opt_style_normal.corner_radius_bottom_right = 6
			opt_style_normal.content_margin_left = 6
			opt_style_normal.content_margin_right = 6
			opt_style_normal.content_margin_top = 2
			opt_style_normal.content_margin_bottom = 2
			
			var opt_style_hover = opt_style_normal.duplicate()
			opt_style_hover.bg_color = Color(0.18, 0.26, 0.38, 0.95)
			opt_style_hover.border_color = Color(0.45, 0.72, 1.0, 0.85)
			
			var opt_style_pressed = opt_style_hover.duplicate()
			opt_style_pressed.bg_color = Color(0.10, 0.18, 0.30, 0.95)
			
			tee_opt.add_theme_stylebox_override("normal", opt_style_normal)
			tee_opt.add_theme_stylebox_override("hover", opt_style_hover)
			tee_opt.add_theme_stylebox_override("pressed", opt_style_pressed)
			tee_opt.add_theme_stylebox_override("focus", opt_style_hover)
			
			var popup = tee_opt.get_popup()
			if popup != null:
				ThemeManager.style_popup_menu(popup, 14)
				
			var available_tees = MultiplayerManager.get_course_tees()
			if not available_tees.has(player_tee):
				available_tees.append(player_tee)
				
			for t_idx in range(available_tees.size()):
				var t_name = available_tees[t_idx]
				var t_icon = _get_tee_icon(t_name, 14)
				tee_opt.add_icon_item(t_icon, t_name, t_idx)
				if t_name.to_lower() == player_tee.to_lower():
					tee_opt.selected = t_idx
					
			if not p.get("active", true):
				tee_opt.disabled = true
				
			tee_opt.pressed.connect(func():
				if _scorecard_countdown_active and not _scorecard_countdown_paused:
					_on_scorecard_pause_toggled()
			)
			
			var current_p_idx = p_idx
			tee_opt.item_selected.connect(func(sel_idx):
				var chosen_tee = tee_opt.get_item_text(sel_idx)
				MultiplayerManager.set_player_tee(current_p_idx, chosen_tee)
				_populate_scorecard(_last_scorecard_action_type, "TeeOpt:%d" % current_p_idx)
			)
			if has_node("/root/UIFocusGuard"):
				var guard = get_node("/root/UIFocusGuard")
				if guard.has_method("hook_option_button"):
					guard.hook_option_button(tee_opt)
			hbox.add_child(tee_opt)
			
			# Pause / Resume Button
			if is_p_active:
				var pause_btn = Button.new()
				pause_btn.name = "PauseBtn_%d" % p_idx
				pause_btn.custom_minimum_size = Vector2(80, 28)
				pause_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				pause_btn.focus_mode = Control.FOCUS_ALL
				pause_btn.add_theme_font_size_override("font_size", 12)
				var cur_idx = p_idx
				if is_p_paused:
					pause_btn.text = "▶ Resume"
					pause_btn.tooltip_text = "Resume player"
					apply_material_button_style(pause_btn, Color(0.2, 0.6, 0.5, 0.9))
					pause_btn.pressed.connect(func():
						if _scorecard_countdown_active and not _scorecard_countdown_paused:
							_on_scorecard_pause_toggled()
						var saved = p.get("saved_paused_state", {})
						var paused_hole_idx = saved.get("hole_index", MultiplayerManager.current_hole_index)
						if paused_hole_idx == MultiplayerManager.current_hole_index:
							MultiplayerManager.resume_player(cur_idx, "same_hole")
							_populate_scorecard(_last_scorecard_action_type, "PauseBtn_%d" % cur_idx)
						else:
							_show_resume_player_dialog(cur_idx, p, paused_hole_idx)
					)
				else:
					pause_btn.text = "⏸ Pause"
					pause_btn.tooltip_text = "Pause player"
					apply_material_button_style(pause_btn, Color(0.85, 0.55, 0.15, 0.9))
					pause_btn.disabled = MultiplayerManager.is_in_catch_up
					pause_btn.pressed.connect(func():
						if _scorecard_countdown_active and not _scorecard_countdown_paused:
							_on_scorecard_pause_toggled()
						MultiplayerManager.pause_player(cur_idx)
						_populate_scorecard(_last_scorecard_action_type, "PauseBtn_%d" % cur_idx)
					)
				hbox.add_child(pause_btn)

			# Remove / Add Back Button
			var toggle_btn = Button.new()
			toggle_btn.name = "ToggleBtn_%d" % p_idx
			toggle_btn.custom_minimum_size = Vector2(74, 28)
			toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			toggle_btn.focus_mode = Control.FOCUS_ALL
			toggle_btn.add_theme_font_size_override("font_size", 12)
			var t_idx = p_idx
			if is_p_active:
				toggle_btn.text = "Remove"
				toggle_btn.tooltip_text = "Remove player from round"
				apply_material_button_style(toggle_btn, Color(0.56, 0.22, 0.22, 0.85))
				toggle_btn.disabled = not can_remove
				toggle_btn.pressed.connect(func():
					if _scorecard_countdown_active and not _scorecard_countdown_paused:
						_on_scorecard_pause_toggled()
					MultiplayerManager.toggle_player_active(t_idx, false)
					_populate_scorecard(_last_scorecard_action_type, "ToggleBtn_%d" % t_idx)
				)
			else:
				toggle_btn.text = "Add Back"
				toggle_btn.tooltip_text = "Add player back into round"
				apply_material_button_style(toggle_btn, Color(0.25, 0.55, 0.35, 0.85))
				toggle_btn.pressed.connect(func():
					if _scorecard_countdown_active and not _scorecard_countdown_paused:
						_on_scorecard_pause_toggled()
					MultiplayerManager.toggle_player_active(t_idx, true)
					_populate_scorecard(_last_scorecard_action_type, "ToggleBtn_%d" % t_idx)
					_update_distance_queue()
				)
			hbox.add_child(toggle_btn)
		else:
			# Static tee color swatch indicator when settings are closed
			var tee_badge = HBoxContainer.new()
			tee_badge.name = "TeeBadge"
			tee_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tee_badge.add_theme_constant_override("separation", 5)
			
			var t_icon_rect = TextureRect.new()
			t_icon_rect.texture = _get_tee_icon(player_tee, 14)
			t_icon_rect.custom_minimum_size = Vector2(14, 14)
			t_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tee_badge.add_child(t_icon_rect)
			
			var t_lbl = Label.new()
			t_lbl.text = player_tee
			t_lbl.add_theme_font_size_override("font_size", 13)
			t_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
			t_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tee_badge.add_child(t_lbl)
			
			hbox.add_child(tee_badge)
		
		var email_btn = Button.new()
		email_btn.text = "✉️"
		email_btn.tooltip_text = "Email shot stats for " + p["name"]
		email_btn.custom_minimum_size = Vector2(30, 30)
		email_btn.focus_mode = Control.FOCUS_NONE
		email_btn.add_theme_font_size_override("font_size", 13)
		
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = Color(0.2, 0.4, 0.7, 0.8)
		btn_style_normal.corner_radius_top_left = 6
		btn_style_normal.corner_radius_top_right = 6
		btn_style_normal.corner_radius_bottom_left = 6
		btn_style_normal.corner_radius_bottom_right = 6
		
		var btn_style_hover = btn_style_normal.duplicate()
		btn_style_hover.bg_color = Color(0.25, 0.5, 0.85, 0.9)
		
		var btn_style_pressed = btn_style_normal.duplicate()
		btn_style_pressed.bg_color = Color(0.15, 0.3, 0.55, 0.95)
		
		email_btn.add_theme_stylebox_override("normal", btn_style_normal)
		email_btn.add_theme_stylebox_override("hover", btn_style_hover)
		email_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
		
		email_btn.pressed.connect(func():
			_email_player_stats(p)
		)
		hbox.add_child(email_btn)
		
		scorecard_grid.add_child(cell)
		
		# Front 9 scores
		var front_score_sum = 0
		for i in range(front_holes.size()):
			var hole_id = front_holes[i]
			var display_score = "-"
			var is_current = (hole_id == current_hole_id)
			if is_ctp_mode:
				var s = p["hole_scores"].get(hole_id)
				if s != null:
					display_score = str(s)
					front_score_sum += int(s)
				elif is_current and p.get("active", true) and p["strokes"] > 0:
					display_score = "*"
			elif is_current:
				if p.get("active", true) and p["strokes"] > 0:
					display_score = str(p["strokes"])
					front_score_sum += p["strokes"]
					if not p.get("holed_out", false):
						display_score += "*"
			else:
				var s = p["hole_scores"].get(hole_id)
				if s != null:
					display_score = str(s)
					front_score_sum += s
			
			var hole = MultiplayerManager.hole_info.get(hole_id, {})
			var par = int(round(float(hole.get("Par", 4))))
			if display_score != "-" and display_score != "*":
				if is_skins_mode:
					var h_res = MultiplayerManager.hole_skins_results.get(hole_id, {})
					if not h_res.is_empty():
						if h_res.get("winner", "") == p["name"]:
							display_score += " 🏆"
						elif h_res.get("winner", "") == "Tie":
							display_score += " (C)"
								
			if render_front:
				var is_act = (MultiplayerManager.get_hole_number_from_id(hole_id, i) == active_hole_num)
				add_score_cell.call(display_score, par, row_bg, is_act, is_ctp_mode, 17)
			
		if render_front and (num_holes > 9 or _scorecard_view_tab == "Front 9"):
			add_cell.call(str(front_score_sum) if front_score_sum > 0 else "-", row_bg, false, Color(1.0, 0.85, 0.38), 17)
			
		# Back 9 scores
		var back_score_sum = 0
		if num_holes > 9:
			for i in range(back_holes.size()):
				var hole_id = back_holes[i]
				var display_score = "-"
				var is_current = (hole_id == current_hole_id)
				if is_ctp_mode:
					var s = p["hole_scores"].get(hole_id)
					if s != null:
						display_score = str(s)
						back_score_sum += int(s)
					elif is_current and p.get("active", true) and p["strokes"] > 0:
						display_score = "*"
				elif is_current:
					if p.get("active", true) and p["strokes"] > 0:
						display_score = str(p["strokes"])
						back_score_sum += p["strokes"]
						if not p.get("holed_out", false):
							display_score += "*"
				else:
					var s = p["hole_scores"].get(hole_id)
					if s != null:
						display_score = str(s)
						back_score_sum += s
						
				var hole = MultiplayerManager.hole_info.get(hole_id, {})
				var par = int(round(float(hole.get("Par", 4))))
				if display_score != "-" and display_score != "*":
					if is_skins_mode:
						var h_res = MultiplayerManager.hole_skins_results.get(hole_id, {})
						if not h_res.is_empty():
							if h_res.get("winner", "") == p["name"]:
								display_score += " 🏆"
							elif h_res.get("winner", "") == "Tie":
								display_score += " (C)"
									
				if render_back:
					var is_act = (MultiplayerManager.get_hole_number_from_id(hole_id, 9 + i) == active_hole_num)
					add_score_cell.call(display_score, par, row_bg, is_act, is_ctp_mode, 17)
					
			if render_back:
				add_cell.call(str(back_score_sum) if back_score_sum > 0 else "-", row_bg, false, Color(1.0, 0.85, 0.38), 17)
				
		if _scorecard_view_tab == "All":
			var total_score = front_score_sum + back_score_sum
			var tot_display = str(total_score) if total_score > 0 else "-"
			if is_skins_mode:
				tot_display = "%d Skins (%s)" % [MultiplayerManager.skins_won.get(p["name"], 0), tot_display]
			elif is_ctp_mode:
				tot_display = "%d pts" % total_score
			add_cell.call(tot_display, row_bg, false, Color(1.0, 0.85, 0.38), 17)

	# --- 5. ACTION BUTTON CONFIGURATION ---
	var action_btn = _scorecard_action_btn
	if action_btn == null:
		action_btn = hud_scorecard.find_child("ScorecardActionBtn", true, false) as Button
	if action_btn != null:
		for conn in action_btn.pressed.get_connections():
			action_btn.pressed.disconnect(conn.callable)
		
	if action_type == "toggle":
		_stop_scorecard_countdown()
		if action_btn != null:
			action_btn.text = "Close"
			action_btn.pressed.connect(func():
				if has_node("/root/UIFocusGuard"):
					var guard = get_node("/root/UIFocusGuard")
					if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
						guard.pop_lock(hud_scorecard, false)
				_stop_scorecard_countdown()
				hud_scorecard.visible = false
				_scorecard_selected_hole_index = -1
				_scorecard_settings_mode = false
				_update_scorecard_settings_button_style()
				_set_other_elements_visible(true)
				var sc_btn = toggles_container.find_child("ScorecardToggleButton", true, false) as Control if toggles_container != null else null
				if sc_btn != null and is_instance_valid(sc_btn) and sc_btn.is_visible_in_tree():
					sc_btn.call_deferred("grab_focus")
			)
	elif action_type == "hole_completed":
		var is_final_hole = (MultiplayerManager.current_hole_index >= MultiplayerManager.hole_ids.size() - 1)
		if action_btn != null:
			if MultiplayerManager.is_in_catch_up:
				if MultiplayerManager.current_hole_index + 1 < MultiplayerManager.catch_up_saved_group_hole_index:
					action_btn.text = "Next Missed Hole (Hole %d)" % (MultiplayerManager.current_hole_index + 2)
				else:
					action_btn.text = "Rejoin Group (Hole %d)" % (MultiplayerManager.catch_up_saved_group_hole_index + 1)
			else:
				action_btn.text = "Finish Round" if is_final_hole else "Next Hole"
			action_btn.pressed.connect(func():
				_scorecard_selected_hole_index = -1
				_on_scorecard_advance()
			)
		_start_scorecard_countdown(3.5 if MultiplayerManager.is_in_catch_up else 5.0)
	elif action_type == "game_over":
		_stop_scorecard_countdown()
		if action_btn != null:
			action_btn.text = "Main Menu"
			action_btn.pressed.connect(func():
				if has_node("/root/UIFocusGuard"):
					var guard = get_node("/root/UIFocusGuard")
					if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
						guard.pop_lock(hud_scorecard, false)
				_scorecard_selected_hole_index = -1
				SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
			)

	# --- 6. FOCUS NEIGHBORS CONFIGURATION ---
	_update_scorecard_focus_neighbors(focus_target_name)


func _update_scorecard_focus_neighbors(focus_target_name: String = "") -> void:
	if hud_scorecard == null or not is_instance_valid(hud_scorecard):
		return

	var vbox = hud_scorecard.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		return

	var filter_tabs = vbox.get_node_or_null("FilterTabs") as HBoxContainer
	var active_tab_btn: Control = null
	if filter_tabs != null and filter_tabs.visible and filter_tabs.get_child_count() > 0:
		for c in filter_tabs.get_children():
			if c is Button:
				c.focus_mode = Control.FOCUS_ALL
				if c.text == _scorecard_view_tab:
					active_tab_btn = c
		if active_tab_btn == null:
			active_tab_btn = filter_tabs.get_child(0) as Control

	# Collect hole buttons from scorecard_grid
	var hole_buttons: Array[Button] = []
	if scorecard_grid != null and is_instance_valid(scorecard_grid):
		for child in scorecard_grid.get_children():
			if child is Button and child.name.begins_with("HoleBtn_"):
				child.focus_mode = Control.FOCUS_ALL
				hole_buttons.append(child)

	var sel_btn: Button = null
	for h_b in hole_buttons:
		if h_b.name == "HoleBtn_%d" % _scorecard_selected_hole_index:
			sel_btn = h_b
			break
	if sel_btn == null and not hole_buttons.is_empty():
		sel_btn = hole_buttons[0]

	# Hole buttons horizontal wiring
	for i in range(hole_buttons.size()):
		var h_btn = hole_buttons[i]
		if i > 0 and hole_buttons[i - 1].is_inside_tree():
			h_btn.focus_neighbor_left = hole_buttons[i - 1].get_path()
		if i < hole_buttons.size() - 1 and hole_buttons[i + 1].is_inside_tree():
			h_btn.focus_neighbor_right = hole_buttons[i + 1].get_path()

	# Scorecard settings cog button
	if _scorecard_settings_btn != null and is_instance_valid(_scorecard_settings_btn) and _scorecard_settings_btn.is_inside_tree():
		_scorecard_settings_btn.focus_mode = Control.FOCUS_ALL
		if not hole_buttons.is_empty():
			var last_hole_btn = hole_buttons[hole_buttons.size() - 1]
			if last_hole_btn.is_inside_tree():
				_scorecard_settings_btn.focus_neighbor_left = last_hole_btn.get_path()
				last_hole_btn.focus_neighbor_right = _scorecard_settings_btn.get_path()
				last_hole_btn.focus_neighbor_top = _scorecard_settings_btn.get_path()

	# Filter tabs vertical wiring
	if filter_tabs != null and filter_tabs.visible and filter_tabs.get_child_count() > 0:
		if active_tab_btn != null and active_tab_btn.is_inside_tree():
			for h_btn in hole_buttons:
				if h_btn.is_inside_tree():
					h_btn.focus_neighbor_top = active_tab_btn.get_path()
		if sel_btn != null and sel_btn.is_inside_tree():
			for t_btn in filter_tabs.get_children():
				if t_btn is Button and t_btn.is_inside_tree():
					t_btn.focus_neighbor_bottom = sel_btn.get_path()

	# Action button and countdown pause button
	var action_btn = _scorecard_action_btn
	if action_btn != null and is_instance_valid(action_btn):
		action_btn.focus_mode = Control.FOCUS_ALL
	var pause_btn_cd = _scorecard_pause_btn
	var has_pause_cd = pause_btn_cd != null and is_instance_valid(pause_btn_cd) and pause_btn_cd.is_visible_in_tree()
	if has_pause_cd:
		pause_btn_cd.focus_mode = Control.FOCUS_ALL
		if action_btn != null and action_btn.is_inside_tree() and pause_btn_cd.is_inside_tree():
			action_btn.focus_neighbor_right = pause_btn_cd.get_path()
			pause_btn_cd.focus_neighbor_left = action_btn.get_path()

	# Player rows in scorecard_grid (only present when _scorecard_settings_mode is true)
	var player_rows: Array[Array] = []
	if _scorecard_settings_mode and scorecard_grid != null and is_instance_valid(scorecard_grid):
		for col_cell in scorecard_grid.get_children():
			var hbox = col_cell.get_node_or_null("HBox") as HBoxContainer
			if hbox == null:
				for ch in col_cell.get_children():
					if ch is HBoxContainer:
						hbox = ch
						break
			if hbox != null:
				var row_ctrls: Array[Control] = []
				for ctrl in hbox.get_children():
					if (ctrl is Button or ctrl is OptionButton) and ctrl.focus_mode != Control.FOCUS_NONE and not (ctrl is BaseButton and ctrl.disabled):
						ctrl.focus_mode = Control.FOCUS_ALL
						row_ctrls.append(ctrl)
				if not row_ctrls.is_empty():
					player_rows.append(row_ctrls)

	# Wire horizontal neighbors for each player row
	for row_ctrls in player_rows:
		for j in range(row_ctrls.size()):
			var ctrl = row_ctrls[j]
			var left_ctrl = row_ctrls[maxi(0, j - 1)]
			var right_ctrl = row_ctrls[mini(row_ctrls.size() - 1, j + 1)]
			if left_ctrl.is_inside_tree():
				ctrl.focus_neighbor_left = ctrl.get_path_to(left_ctrl)
			if right_ctrl.is_inside_tree():
				ctrl.focus_neighbor_right = ctrl.get_path_to(right_ctrl)

	# Add player section controls
	var add_controls: Array[Control] = []
	if _scorecard_settings_mode and _scorecard_add_player_section != null and is_instance_valid(_scorecard_add_player_section) and _scorecard_add_player_section.visible:
		var sel_opt = _scorecard_add_player_section.get_node_or_null("AddRow/PlayerSelectOpt") as OptionButton
		var name_inp = _scorecard_add_player_section.get_node_or_null("AddRow/NameInput") as LineEdit
		var t_opt = _scorecard_add_player_section.get_node_or_null("AddRow/TeeOpt") as OptionButton
		var a_btn = _scorecard_add_player_section.get_node_or_null("AddRow/AddBtn") as Button

		if sel_opt != null and sel_opt.is_inside_tree():
			sel_opt.focus_mode = Control.FOCUS_ALL
			add_controls.append(sel_opt)
		if name_inp != null and name_inp.is_inside_tree() and name_inp.visible:
			name_inp.focus_mode = Control.FOCUS_ALL
			add_controls.append(name_inp)
		if t_opt != null and t_opt.is_inside_tree():
			t_opt.focus_mode = Control.FOCUS_ALL
			add_controls.append(t_opt)
		if a_btn != null and a_btn.is_inside_tree():
			a_btn.focus_mode = Control.FOCUS_ALL
			add_controls.append(a_btn)

		for j in range(add_controls.size()):
			var ctrl = add_controls[j]
			var left_ctrl = add_controls[(j - 1 + add_controls.size()) % add_controls.size()]
			var right_ctrl = add_controls[(j + 1) % add_controls.size()]
			if left_ctrl.is_inside_tree():
				ctrl.focus_neighbor_left = ctrl.get_path_to(left_ctrl)
			if right_ctrl.is_inside_tree():
				ctrl.focus_neighbor_right = ctrl.get_path_to(right_ctrl)

	# Vertical wiring
	if not _scorecard_settings_mode:
		# Standard mode: Hole buttons link down to action_btn
		if action_btn != null and action_btn.is_inside_tree():
			for h_btn in hole_buttons:
				if h_btn.is_inside_tree():
					h_btn.focus_neighbor_bottom = action_btn.get_path()
			if _scorecard_settings_btn != null and _scorecard_settings_btn.is_inside_tree():
				_scorecard_settings_btn.focus_neighbor_bottom = action_btn.get_path()
			if sel_btn != null and sel_btn.is_inside_tree():
				action_btn.focus_neighbor_top = sel_btn.get_path()
				action_btn.focus_neighbor_bottom = sel_btn.get_path()
				if has_pause_cd and pause_btn_cd.is_inside_tree():
					pause_btn_cd.focus_neighbor_top = sel_btn.get_path()
					pause_btn_cd.focus_neighbor_bottom = sel_btn.get_path()
	else:
		# Settings mode: Hole buttons / settings cog link down to player rows or add section
		var top_dest: Control = null
		if not player_rows.is_empty():
			top_dest = player_rows[0][0]
		elif not add_controls.is_empty():
			top_dest = add_controls[0]
		elif action_btn != null:
			top_dest = action_btn

		if top_dest != null and top_dest.is_inside_tree():
			for h_btn in hole_buttons:
				if h_btn.is_inside_tree():
					h_btn.focus_neighbor_bottom = top_dest.get_path()
			if _scorecard_settings_btn != null and _scorecard_settings_btn.is_inside_tree():
				var rightmost_top = player_rows[0][mini(1, player_rows[0].size() - 1)] if not player_rows.is_empty() else (add_controls[mini(2, add_controls.size() - 1)] if not add_controls.is_empty() else top_dest)
				if rightmost_top != null and rightmost_top.is_inside_tree():
					_scorecard_settings_btn.focus_neighbor_bottom = rightmost_top.get_path()

		# Player rows vertical links
		var top_up_target = sel_btn if (sel_btn != null and sel_btn.is_inside_tree()) else _scorecard_settings_btn
		if not player_rows.is_empty():
			for j in range(player_rows[0].size()):
				var ctrl = player_rows[0][j]
				if top_up_target != null and top_up_target.is_inside_tree():
					ctrl.focus_neighbor_top = top_up_target.get_path()

			for r in range(1, player_rows.size()):
				var cur_row = player_rows[r]
				var prev_row = player_rows[r - 1]
				for j in range(cur_row.size()):
					var prev_target = prev_row[mini(j, prev_row.size() - 1)]
					if prev_target.is_inside_tree():
						cur_row[j].focus_neighbor_top = prev_target.get_path()
				for j in range(prev_row.size()):
					var next_target = cur_row[mini(j, cur_row.size() - 1)]
					if next_target.is_inside_tree():
						prev_row[j].focus_neighbor_bottom = next_target.get_path()

		# Between last player row and add_controls
		if not player_rows.is_empty() and not add_controls.is_empty():
			var last_row = player_rows[player_rows.size() - 1]
			for j in range(last_row.size()):
				var add_target = add_controls[mini(j, add_controls.size() - 1)]
				if add_target.is_inside_tree():
					last_row[j].focus_neighbor_bottom = add_target.get_path()
			for j in range(add_controls.size()):
				var last_row_target = last_row[mini(j, last_row.size() - 1)]
				if last_row_target.is_inside_tree():
					add_controls[j].focus_neighbor_top = last_row_target.get_path()
		elif player_rows.is_empty() and not add_controls.is_empty():
			for ctrl in add_controls:
				if top_up_target != null and top_up_target.is_inside_tree():
					ctrl.focus_neighbor_top = top_up_target.get_path()

		# Between add_controls (or last player row) and action_btn
		var bottom_source_ctrl = add_controls[mini(2, add_controls.size() - 1)] if not add_controls.is_empty() else (player_rows[player_rows.size() - 1][0] if not player_rows.is_empty() else null)
		if not add_controls.is_empty():
			for ctrl in add_controls:
				if action_btn != null and action_btn.is_inside_tree():
					ctrl.focus_neighbor_bottom = action_btn.get_path()
		elif not player_rows.is_empty():
			for ctrl in player_rows[player_rows.size() - 1]:
				if action_btn != null and action_btn.is_inside_tree():
					ctrl.focus_neighbor_bottom = action_btn.get_path()

		if action_btn != null and action_btn.is_inside_tree():
			if bottom_source_ctrl != null and bottom_source_ctrl.is_inside_tree():
				action_btn.focus_neighbor_top = bottom_source_ctrl.get_path()
				if has_pause_cd and pause_btn_cd.is_inside_tree():
					pause_btn_cd.focus_neighbor_top = bottom_source_ctrl.get_path()
			if sel_btn != null and sel_btn.is_inside_tree():
				action_btn.focus_neighbor_bottom = sel_btn.get_path()
				if has_pause_cd and pause_btn_cd.is_inside_tree():
					pause_btn_cd.focus_neighbor_bottom = sel_btn.get_path()

	# Focus restoration / targeting
	if not focus_target_name.is_empty():
		var target_ctrl: Control = null
		if focus_target_name.begins_with("TeeOpt:"):
			var p_target_idx = focus_target_name.trim_prefix("TeeOpt:").to_int()
			if p_target_idx >= 0 and p_target_idx < player_rows.size():
				for c in player_rows[p_target_idx]:
					if c is OptionButton:
						target_ctrl = c
						break
		else:
			target_ctrl = hud_scorecard.find_child(focus_target_name, true, false) as Control

		if target_ctrl != null and is_instance_valid(target_ctrl) and target_ctrl.is_inside_tree() and target_ctrl.is_visible_in_tree():
			target_ctrl.call_deferred("grab_focus")
			return

	if not _scorecard_settings_mode:
		_focus_selected_hole_button()


func _start_scorecard_countdown(seconds: float = 5.0) -> void:
	_scorecard_countdown_time_left = seconds
	_scorecard_countdown_active = true
	_scorecard_countdown_paused = false
	if _scorecard_countdown_container != null:
		_scorecard_countdown_container.visible = true
	if _scorecard_pause_btn != null:
		_scorecard_pause_btn.text = "⏸ Pause"
		apply_material_button_style(_scorecard_pause_btn, Color(0.35, 0.38, 0.45, 0.85))
	if _scorecard_countdown_lbl != null:
		_scorecard_countdown_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 1.0))
	_update_scorecard_countdown_display()


func _stop_scorecard_countdown() -> void:
	_scorecard_countdown_active = false
	_scorecard_countdown_paused = false
	_scorecard_countdown_time_left = 0.0
	if _scorecard_countdown_container != null:
		_scorecard_countdown_container.visible = false


func _on_scorecard_pause_toggled() -> void:
	if not _scorecard_countdown_active:
		return
	_scorecard_countdown_paused = not _scorecard_countdown_paused
	_update_scorecard_pause_ui()


func _update_scorecard_pause_ui() -> void:
	if _scorecard_countdown_paused:
		if _scorecard_pause_btn != null:
			_scorecard_pause_btn.text = "▶ Resume"
			apply_material_button_style(_scorecard_pause_btn, Color(0.22, 0.52, 0.32, 0.85))
		if _scorecard_countdown_lbl != null:
			_scorecard_countdown_lbl.text = "Auto-advance paused"
			_scorecard_countdown_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4, 1.0))
	else:
		if _scorecard_pause_btn != null:
			_scorecard_pause_btn.text = "⏸ Pause"
			apply_material_button_style(_scorecard_pause_btn, Color(0.35, 0.38, 0.45, 0.85))
		if _scorecard_countdown_lbl != null:
			_scorecard_countdown_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 1.0))
		if _scorecard_countdown_time_left < 1.0:
			_scorecard_countdown_time_left = 1.0
		_update_scorecard_countdown_display()


func _update_scorecard_countdown_display() -> void:
	if not _scorecard_countdown_active or _scorecard_countdown_paused:
		return
	var secs = ceili(_scorecard_countdown_time_left)
	if secs < 1:
		secs = 1
	var is_final_hole = (MultiplayerManager.current_hole_index >= MultiplayerManager.hole_ids.size() - 1)
	if _scorecard_countdown_lbl != null:
		if MultiplayerManager.is_in_catch_up:
			if MultiplayerManager.current_hole_index + 1 < MultiplayerManager.catch_up_saved_group_hole_index:
				_scorecard_countdown_lbl.text = "Next missed hole in %ds..." % secs
			else:
				_scorecard_countdown_lbl.text = "Rejoining group in %ds..." % secs
		elif is_final_hole:
			_scorecard_countdown_lbl.text = "Finishing round in %ds..." % secs
		else:
			_scorecard_countdown_lbl.text = "Next hole in %ds..." % secs


func _on_scorecard_advance() -> void:
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		if guard.is_locked() and guard.current_lock_root() == hud_scorecard:
			guard.pop_lock(hud_scorecard, false)
	_stop_scorecard_countdown()
	hud_scorecard.visible = false
	_scorecard_selected_hole_index = -1
	_set_other_elements_visible(true)
	reset_zoom_to_default()
	MultiplayerManager.advance_hole()


func _set_other_elements_visible(is_visible: bool) -> void:
	_hud_elements_visible = is_visible
	if range_ui != null:
		range_ui.visible = is_visible
		if range_ui.has_method("set_hud_elements_visible"):
			range_ui.call("set_hud_elements_visible", is_visible)
	if _minimap_group != null:
		var is_aerial = false
		if course_instance != null and course_instance.get("is_aerial_view") != null:
			is_aerial = course_instance.get("is_aerial_view") as bool
		_minimap_group.visible = is_visible and not is_aerial
	if top_bar != null:
		top_bar.visible = is_visible
	if settings_btn != null:
		settings_btn.visible = is_visible
	if home_btn != null:
		home_btn.visible = is_visible
	if hide_helpers_btn != null:
		hide_helpers_btn.visible = is_visible
	if right_panel != null:
		right_panel.visible = is_visible
	if stats_btn != null:
		stats_btn.visible = is_visible
	if grid_btn != null:
		grid_btn.visible = is_visible
	if map_btn != null:
		map_btn.visible = is_visible
	if mulligan_btn != null:
		var is_match_play = not MultiplayerManager.players.is_empty() and not MultiplayerManager.practice_mode_active
		mulligan_btn.visible = is_visible and is_match_play and not _is_online_match()
	if forfeit_btn != null:
		var is_match_play = not MultiplayerManager.players.is_empty() and not MultiplayerManager.practice_mode_active
		var active_p = MultiplayerManager.get_active_player()
		var p_strokes = active_p.get("strokes", 0) if not active_p.is_empty() else 0
		var p_holed = active_p.get("holed_out", false) if not active_p.is_empty() else true
		forfeit_btn.visible = is_visible and (_is_spectating() or (is_match_play and (p_strokes >= 10 or _is_online_match()) and not p_holed))
	if not is_visible and forfeit_confirm_dialog != null and forfeit_confirm_dialog.visible:
		forfeit_confirm_dialog.visible = false
	if not is_visible and hole_intro_card != null and hole_intro_card.visible:
		if _hole_card_tween != null and _hole_card_tween.is_valid():
			_hole_card_tween.kill()
		hole_intro_card.visible = false
	if not is_visible:
		if add_player_prompt_dialog != null and add_player_prompt_dialog.visible:
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == add_player_prompt_dialog:
				UIFocusGuard.pop_lock(false)
			add_player_prompt_dialog.visible = false
		if resume_player_prompt_dialog != null and resume_player_prompt_dialog.visible:
			if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == resume_player_prompt_dialog:
				UIFocusGuard.pop_lock(false)
			resume_player_prompt_dialog.visible = false
	if catch_up_banner != null:
		catch_up_banner.visible = is_visible and MultiplayerManager.is_in_catch_up
	if club_selector_node != null:
		club_selector_node.visible = is_visible


func _on_manage_players_toggle_pressed() -> void:
	_on_scorecard_toggle_pressed()


func _open_manage_players_panel() -> void:
	if _scorecard_selected_hole_index < 0:
		_scorecard_selected_hole_index = MultiplayerManager.current_hole_index
	_populate_scorecard("toggle")
	hud_scorecard.visible = true
	_set_other_elements_visible(false)
	if hud_manage_players != null and hud_manage_players.get_parent() != null:
		_populate_manage_players()
		_refresh_manage_players_dropdown()
		hud_manage_players.visible = true
		UIFocusGuard.push_lock(hud_manage_players)
		hud_manage_players.set_meta("on_focus_lock_popped", Callable(self, "_on_manage_players_lock_popped"))
		var select_opt = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/PlayerSelectOpt") as Control
		if select_opt != null and select_opt.is_visible_in_tree():
			select_opt.call_deferred("grab_focus")


func _close_manage_players_panel() -> void:
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == hud_manage_players:
		UIFocusGuard.pop_lock(false)
	if hud_manage_players != null:
		hud_manage_players.visible = false
	if hud_scorecard != null and hud_scorecard.visible:
		_stop_scorecard_countdown()
		hud_scorecard.visible = false
		_scorecard_selected_hole_index = -1
		_set_other_elements_visible(true)
	var sc_btn = find_child("ScorecardToggleButton", true, false) as Control
	if sc_btn != null and is_instance_valid(sc_btn) and sc_btn.is_visible_in_tree():
		sc_btn.call_deferred("grab_focus")


func _on_manage_players_lock_popped() -> void:
	if hud_manage_players != null:
		hud_manage_players.visible = false
	_set_other_elements_visible(true)
	var sc_btn = find_child("ScorecardToggleButton", true, false) as Control
	if sc_btn != null and is_instance_valid(sc_btn) and sc_btn.is_visible_in_tree():
		sc_btn.call_deferred("grab_focus")


func _refresh_manage_players_dropdown() -> void:
	var add_sec = hud_manage_players.get_node_or_null("VBoxContainer/AddSection") as Control
	if add_sec != null:
		add_sec.visible = not _is_online_match()
	var select_opt = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/PlayerSelectOpt") as OptionButton
	var name_input = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/NameInput") as LineEdit
	if select_opt != null and name_input != null:
		select_opt.clear()
		select_opt.add_item("New Player...", 0)
		var registered = MultiplayerManager.get_registered_players()
		for i in range(registered.size()):
			select_opt.add_item(registered[i].get("name", "Player"), i + 1)
		select_opt.selected = 0
		name_input.visible = true
	_update_manage_players_focus_neighbors()


func _populate_manage_players() -> void:
	var add_sec = hud_manage_players.get_node_or_null("VBoxContainer/AddSection") as Control
	if add_sec != null:
		add_sec.visible = not _is_online_match()
	var list_node = hud_manage_players.get_node_or_null("VBoxContainer/ScrollContainer/PlayerList") as VBoxContainer
	if list_node == null:
		return
		
	# Clear previous entries
	for child in list_node.get_children():
		child.queue_free()
		
	# Count active players
	var active_count = 0
	for p in MultiplayerManager.players:
		if p.get("active", true):
			active_count += 1
			
	var can_remove = (active_count > 1)
		
	for i in range(MultiplayerManager.players.size()):
		var p = MultiplayerManager.players[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		
		var name_lbl = Label.new()
		var status_str = ""
		if not p.get("active", true):
			status_str = " (Out)"
		elif p.get("paused", false):
			status_str = " (⏸️ Paused)"
		elif MultiplayerManager.is_in_catch_up and MultiplayerManager.catch_up_player_name == p.get("name", ""):
			status_str = " (⛳ Catching up)"
		var p_name_str = p.get("name", "Player")
		var p_tee_str = p.get("tee", "White")
		name_lbl.text = "%s (%s)%s" % [p_name_str, p_tee_str, status_str]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not p.get("active", true):
			name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		elif p.get("paused", false):
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		elif MultiplayerManager.is_in_catch_up and MultiplayerManager.catch_up_player_name == p["name"]:
			name_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
		row.add_child(name_lbl)
		
		# Pause / Resume Button
		if p.get("active", true) and not _is_online_match():
			var pause_btn = Button.new()
			pause_btn.name = "PauseBtn"
			pause_btn.custom_minimum_size = Vector2(105, 44)
			pause_btn.focus_mode = Control.FOCUS_ALL
			if p.get("paused", false):
				pause_btn.text = "▶ Resume"
				apply_material_button_style(pause_btn, Color(0.2, 0.6, 0.5, 0.9))
				pause_btn.pressed.connect(func():
					var saved = p.get("saved_paused_state", {})
					var paused_hole_idx = saved.get("hole_index", MultiplayerManager.current_hole_index)
					if paused_hole_idx == MultiplayerManager.current_hole_index:
						MultiplayerManager.resume_player(i, "same_hole")
						_close_manage_players_panel()
						_populate_scorecard("toggle")
					else:
						_show_resume_player_dialog(i, p, paused_hole_idx)
				)
			else:
				pause_btn.text = "⏸ Pause"
				apply_material_button_style(pause_btn, Color(0.85, 0.55, 0.15, 0.9))
				pause_btn.disabled = MultiplayerManager.is_in_catch_up
				pause_btn.pressed.connect(func():
					MultiplayerManager.pause_player(i)
					_populate_manage_players()
					_populate_scorecard("toggle")
				)
			row.add_child(pause_btn)
		
		var toggle_btn = Button.new()
		toggle_btn.name = "ToggleBtn"
		toggle_btn.custom_minimum_size = Vector2(100, 44)
		toggle_btn.focus_mode = Control.FOCUS_ALL
		if p.get("active", true):
			toggle_btn.text = "Remove"
			apply_material_button_style(toggle_btn, Color(0.56, 0.22, 0.22, 0.85)) # Red
			toggle_btn.disabled = not can_remove
			toggle_btn.pressed.connect(func():
				MultiplayerManager.toggle_player_active(i, false)
				_populate_manage_players()
				_populate_scorecard("toggle")
			)
		else:
			toggle_btn.text = "Add Back"
			apply_material_button_style(toggle_btn, Color(0.25, 0.55, 0.35, 0.85)) # Green
			toggle_btn.pressed.connect(func():
				MultiplayerManager.toggle_player_active(i, true)
				_populate_manage_players()
				_populate_scorecard("toggle")
				_update_distance_queue()
			)
		row.add_child(toggle_btn)
		list_node.add_child(row)

	_update_manage_players_focus_neighbors()


func _update_manage_players_focus_neighbors() -> void:
	if hud_manage_players == null or not is_instance_valid(hud_manage_players):
		return
	var list_node = hud_manage_players.get_node_or_null("VBoxContainer/ScrollContainer/PlayerList") as VBoxContainer
	var select_opt = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/PlayerSelectOpt") as OptionButton
	var name_input = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/NameInput") as LineEdit
	var tee_opt = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/TeeOpt") as OptionButton
	var add_btn = hud_manage_players.get_node_or_null("VBoxContainer/AddSection/AddRow/AddBtn") as Button
	var close_btn = hud_manage_players.get_node_or_null("VBoxContainer/CloseBtn") as Button

	if select_opt == null or tee_opt == null or add_btn == null or close_btn == null:
		return

	# Determine visible controls in AddRow
	var add_controls: Array[Control] = [select_opt]
	if name_input != null and is_instance_valid(name_input) and name_input.visible:
		add_controls.append(name_input)
	add_controls.append(tee_opt)
	add_controls.append(add_btn)

	# Wire horizontal neighbors for AddRow
	for i in range(add_controls.size()):
		var ctrl = add_controls[i]
		ctrl.focus_mode = Control.FOCUS_ALL
		var left_ctrl = add_controls[(i - 1 + add_controls.size()) % add_controls.size()]
		var right_ctrl = add_controls[(i + 1) % add_controls.size()]
		ctrl.focus_neighbor_left = ctrl.get_path_to(left_ctrl)
		ctrl.focus_neighbor_right = ctrl.get_path_to(right_ctrl)

	# Close button horizontal links wrap to self
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.focus_neighbor_left = close_btn.get_path_to(close_btn)
	close_btn.focus_neighbor_right = close_btn.get_path_to(close_btn)

	# Collect all interactive player rows
	var player_rows: Array[Array] = []
	if list_node != null and is_instance_valid(list_node):
		for row_child in list_node.get_children():
			var row_btns: Array[Button] = []
			var pause_b = row_child.get_node_or_null("PauseBtn") as Button
			var toggle_b = row_child.get_node_or_null("ToggleBtn") as Button
			if pause_b != null and is_instance_valid(pause_b) and pause_b.visible and not pause_b.disabled:
				pause_b.focus_mode = Control.FOCUS_ALL
				row_btns.append(pause_b)
			if toggle_b != null and is_instance_valid(toggle_b) and toggle_b.visible and not toggle_b.disabled:
				toggle_b.focus_mode = Control.FOCUS_ALL
				row_btns.append(toggle_b)
			if not row_btns.is_empty():
				player_rows.append(row_btns)

	# Wire player row internal horizontal neighbors
	for row_btns in player_rows:
		if row_btns.size() == 2:
			row_btns[0].focus_neighbor_right = row_btns[0].get_path_to(row_btns[1])
			row_btns[1].focus_neighbor_left = row_btns[1].get_path_to(row_btns[0])

	# Wire vertical neighbors
	if player_rows.is_empty():
		for ctrl in add_controls:
			ctrl.focus_neighbor_top = ctrl.get_path_to(close_btn)
			ctrl.focus_neighbor_bottom = ctrl.get_path_to(close_btn)
		close_btn.focus_neighbor_top = close_btn.get_path_to(add_btn)
		close_btn.focus_neighbor_bottom = close_btn.get_path_to(select_opt)
	else:
		# Between player rows
		for r in range(player_rows.size()):
			var cur_row_btns = player_rows[r]
			if r == 0:
				for b in cur_row_btns:
					b.focus_neighbor_top = b.get_path_to(close_btn)
			else:
				var prev_row_btns = player_rows[r - 1]
				for b_idx in range(cur_row_btns.size()):
					var b = cur_row_btns[b_idx]
					var target_prev = prev_row_btns[mini(b_idx, prev_row_btns.size() - 1)]
					b.focus_neighbor_top = b.get_path_to(target_prev)

			if r == player_rows.size() - 1:
				for b in cur_row_btns:
					b.focus_neighbor_bottom = b.get_path_to(select_opt)
			else:
				var next_row_btns = player_rows[r + 1]
				for b_idx in range(cur_row_btns.size()):
					var b = cur_row_btns[b_idx]
					var target_next = next_row_btns[mini(b_idx, next_row_btns.size() - 1)]
					b.focus_neighbor_bottom = b.get_path_to(target_next)

		# AddRow controls vertical neighbors
		var last_row_btns = player_rows[player_rows.size() - 1]
		var top_player_target = last_row_btns[0]
		for ctrl in add_controls:
			ctrl.focus_neighbor_top = ctrl.get_path_to(top_player_target)
			ctrl.focus_neighbor_bottom = ctrl.get_path_to(close_btn)

		# Close button vertical neighbors
		close_btn.focus_neighbor_top = close_btn.get_path_to(add_btn)
		close_btn.focus_neighbor_bottom = close_btn.get_path_to(player_rows[0][0])


func _show_add_player_dialog(p_name: String, tee_color: String) -> void:
	if add_player_prompt_dialog == null:
		return
		
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == hud_manage_players:
		UIFocusGuard.pop_lock(false)
	hud_manage_players.visible = false
	for child in add_player_prompt_dialog.get_children():
		add_player_prompt_dialog.remove_child(child)
		child.queue_free()
		
	var cur_hole_num = MultiplayerManager.get_current_hole_number()
	var missed_cnt = MultiplayerManager.current_hole_index
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	var title = Label.new()
	title.text = "Add Player Mid-Game: %s" % p_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	vbox.add_child(title)
	
	var msg = Label.new()
	msg.text = "The group is currently on Hole %d.\nHow would you like %s to join?" % [cur_hole_num, p_name]
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 16)
	vbox.add_child(msg)
	
	var join_cur_btn = Button.new()
	join_cur_btn.name = "JoinCurrentButton"
	join_cur_btn.text = "⛳ Put on Hole %d (Dashes on Holes 1-%d)" % [cur_hole_num, missed_cnt]
	join_cur_btn.custom_minimum_size = Vector2(0, 48)
	join_cur_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(join_cur_btn, Color(0.24, 0.46, 0.72, 0.9))
	join_cur_btn.pressed.connect(func():
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == add_player_prompt_dialog:
			UIFocusGuard.pop_lock(false)
		add_player_prompt_dialog.visible = false
		hud_manage_players.visible = false
		MultiplayerManager.add_new_player_with_mode(p_name, tee_color, "current_hole")
		_refresh_manage_players_dropdown()
		_populate_manage_players()
		_refresh_scorecard_add_player_section()
		_populate_scorecard("toggle", "PlayerSelectOpt")
		_update_distance_queue()
		hud_scorecard.visible = true
		_set_other_elements_visible(false)
		if has_node("/root/UIFocusGuard"):
			var guard = get_node("/root/UIFocusGuard")
			guard.push_lock(hud_scorecard)
	)
	vbox.add_child(join_cur_btn)
	
	var play_missed_btn = Button.new()
	play_missed_btn.name = "PlayMissedButton"
	play_missed_btn.text = "🏌️ Play Missed Holes (Holes 1-%d Solo Catch-Up)" % missed_cnt
	play_missed_btn.custom_minimum_size = Vector2(0, 48)
	play_missed_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(play_missed_btn, Color(0.25, 0.65, 0.35, 0.9))
	play_missed_btn.pressed.connect(func():
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == add_player_prompt_dialog:
			UIFocusGuard.pop_lock(false)
		add_player_prompt_dialog.visible = false
		hud_manage_players.visible = false
		hud_scorecard.visible = false
		_set_other_elements_visible(true)
		MultiplayerManager.add_new_player_with_mode(p_name, tee_color, "catch_up")
		_refresh_manage_players_dropdown()
		_populate_manage_players()
		_refresh_scorecard_add_player_section()
		_populate_scorecard("toggle")
		_update_catch_up_hud()
		_update_distance_queue()
		var sc_btn = find_child("ScorecardToggleButton", true, false) as Control
		if sc_btn != null and is_instance_valid(sc_btn) and sc_btn.is_visible_in_tree():
			sc_btn.call_deferred("grab_focus")
	)
	vbox.add_child(play_missed_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(cancel_btn, Color(0.45, 0.45, 0.48, 0.85))
	cancel_btn.pressed.connect(func():
		_dismiss_add_player_dialog()
	)
	vbox.add_child(cancel_btn)
	
	join_cur_btn.focus_neighbor_bottom = join_cur_btn.get_path_to(play_missed_btn)
	join_cur_btn.focus_neighbor_top = join_cur_btn.get_path_to(cancel_btn)
	play_missed_btn.focus_neighbor_top = play_missed_btn.get_path_to(join_cur_btn)
	play_missed_btn.focus_neighbor_bottom = play_missed_btn.get_path_to(cancel_btn)
	cancel_btn.focus_neighbor_top = cancel_btn.get_path_to(play_missed_btn)
	cancel_btn.focus_neighbor_bottom = cancel_btn.get_path_to(join_cur_btn)
	
	add_player_prompt_dialog.add_child(vbox)
	add_player_prompt_dialog.visible = true
	UIFocusGuard.push_lock(add_player_prompt_dialog)
	add_player_prompt_dialog.set_meta("on_focus_lock_popped", Callable(self, "_on_add_player_lock_popped"))
	join_cur_btn.call_deferred("grab_focus")


func _dismiss_add_player_dialog() -> void:
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == add_player_prompt_dialog:
		UIFocusGuard.pop_lock(false)
	add_player_prompt_dialog.visible = false
	_populate_scorecard(_last_scorecard_action_type, "PlayerSelectOpt")
	hud_scorecard.visible = true
	_set_other_elements_visible(false)
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		guard.push_lock(hud_scorecard)


func _on_add_player_lock_popped() -> void:
	add_player_prompt_dialog.visible = false
	_populate_scorecard(_last_scorecard_action_type, "PlayerSelectOpt")
	hud_scorecard.visible = true
	_set_other_elements_visible(false)
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		guard.push_lock(hud_scorecard)


func _show_resume_player_dialog(idx: int, p: Dictionary, paused_hole_idx: int) -> void:
	if resume_player_prompt_dialog == null:
		return
		
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == hud_manage_players:
		UIFocusGuard.pop_lock(false)
	hud_manage_players.visible = false
	for child in resume_player_prompt_dialog.get_children():
		resume_player_prompt_dialog.remove_child(child)
		child.queue_free()
		
	var cur_hole_num = MultiplayerManager.get_current_hole_number()
	var paused_hole_num = MultiplayerManager.get_hole_number(paused_hole_idx)
	var p_name = p.get("name", "Player")
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	var title = Label.new()
	title.text = "Resume: %s" % p_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	vbox.add_child(title)
	
	var msg = Label.new()
	msg.text = "The group is on Hole %d, but %s paused on Hole %d.\nHow would you like to resume?" % [cur_hole_num, p_name, paused_hole_num]
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 16)
	vbox.add_child(msg)
	
	var catch_up_btn = Button.new()
	catch_up_btn.name = "CatchUpButton"
	catch_up_btn.text = "🏌️ Continue Where Left Off (Play Missed Holes Solo)"
	catch_up_btn.custom_minimum_size = Vector2(0, 48)
	catch_up_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(catch_up_btn, Color(0.25, 0.65, 0.35, 0.9))
	catch_up_btn.pressed.connect(func():
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == resume_player_prompt_dialog:
			UIFocusGuard.pop_lock(false)
		resume_player_prompt_dialog.visible = false
		hud_manage_players.visible = false
		hud_scorecard.visible = false
		_set_other_elements_visible(true)
		MultiplayerManager.resume_player(idx, "catch_up")
		_populate_manage_players()
		_populate_scorecard("toggle")
		_update_catch_up_hud()
		var sc_btn = find_child("ScorecardToggleButton", true, false) as Control
		if sc_btn != null and is_instance_valid(sc_btn) and sc_btn.is_visible_in_tree():
			sc_btn.call_deferred("grab_focus")
	)
	vbox.add_child(catch_up_btn)
	
	var skip_btn = Button.new()
	skip_btn.name = "SkipButton"
	skip_btn.text = "⛳ Skip to Hole %d (Dashes on Missed Holes)" % cur_hole_num
	skip_btn.custom_minimum_size = Vector2(0, 48)
	skip_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(skip_btn, Color(0.24, 0.46, 0.72, 0.9))
	skip_btn.pressed.connect(func():
		if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == resume_player_prompt_dialog:
			UIFocusGuard.pop_lock(false)
		resume_player_prompt_dialog.visible = false
		hud_manage_players.visible = false
		MultiplayerManager.resume_player(idx, "current_hole")
		_populate_manage_players()
		_populate_scorecard("toggle", "PauseBtn_%d" % idx)
		hud_scorecard.visible = true
		_set_other_elements_visible(false)
		if has_node("/root/UIFocusGuard"):
			var guard = get_node("/root/UIFocusGuard")
			guard.push_lock(hud_scorecard)
	)
	vbox.add_child(skip_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.focus_mode = Control.FOCUS_ALL
	apply_material_button_style(cancel_btn, Color(0.45, 0.45, 0.48, 0.85))
	cancel_btn.pressed.connect(func():
		_dismiss_resume_player_dialog()
	)
	vbox.add_child(cancel_btn)
	
	catch_up_btn.focus_neighbor_bottom = catch_up_btn.get_path_to(skip_btn)
	catch_up_btn.focus_neighbor_top = catch_up_btn.get_path_to(cancel_btn)
	skip_btn.focus_neighbor_top = skip_btn.get_path_to(catch_up_btn)
	skip_btn.focus_neighbor_bottom = skip_btn.get_path_to(cancel_btn)
	cancel_btn.focus_neighbor_top = cancel_btn.get_path_to(skip_btn)
	cancel_btn.focus_neighbor_bottom = cancel_btn.get_path_to(catch_up_btn)
	
	resume_player_prompt_dialog.add_child(vbox)
	resume_player_prompt_dialog.visible = true
	UIFocusGuard.push_lock(resume_player_prompt_dialog)
	resume_player_prompt_dialog.set_meta("on_focus_lock_popped", Callable(self, "_on_resume_player_lock_popped"))
	catch_up_btn.call_deferred("grab_focus")


func _dismiss_resume_player_dialog() -> void:
	if UIFocusGuard.is_locked() and UIFocusGuard.current_lock_root() == resume_player_prompt_dialog:
		UIFocusGuard.pop_lock(false)
	resume_player_prompt_dialog.visible = false
	_populate_scorecard(_last_scorecard_action_type)
	hud_scorecard.visible = true
	_set_other_elements_visible(false)
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		guard.push_lock(hud_scorecard)


func _on_resume_player_lock_popped() -> void:
	resume_player_prompt_dialog.visible = false
	_populate_scorecard(_last_scorecard_action_type)
	hud_scorecard.visible = true
	_set_other_elements_visible(false)
	if has_node("/root/UIFocusGuard"):
		var guard = get_node("/root/UIFocusGuard")
		guard.push_lock(hud_scorecard)


var _last_dialog_nav_time: float = 0.0
const DIALOG_NAV_COOLDOWN: float = 0.15

func _navigate_dialog_buttons(buttons: Array[Button], dir: int) -> void:
	if buttons.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if (now - _last_dialog_nav_time) < DIALOG_NAV_COOLDOWN:
		return
	_last_dialog_nav_time = now
	var cur_focus = get_viewport().gui_get_focus_owner()
	var idx = buttons.find(cur_focus)
	if idx == -1:
		buttons[0].grab_focus()
	else:
		var next_idx = (idx + dir + buttons.size()) % buttons.size()
		buttons[next_idx].grab_focus()


func _update_catch_up_hud() -> void:
	if catch_up_banner == null:
		return
	if _is_online_match():
		catch_up_banner.visible = false
		return
	if MultiplayerManager.is_in_catch_up:
		catch_up_banner.visible = _hud_elements_visible
		if catch_up_lbl != null:
			catch_up_lbl.text = "⛳ Solo Catch-Up: %s on Hole %d (Group on Hole %d)" % [
				MultiplayerManager.catch_up_player_name,
				MultiplayerManager.current_hole_index + 1,
				MultiplayerManager.catch_up_saved_group_hole_index + 1
			]
	else:
		catch_up_banner.visible = false


func _email_player_stats(p: Dictionary) -> void:
	var player_name = p.get("name", "Player")
	var course_title = MultiplayerManager.course_title
	var total_strokes = p.get("total_strokes", 0)
	var tee_color = p.get("tee", "Blue")
	var date_str = Time.get_date_string_from_system() + " " + Time.get_time_string_from_system().substr(0, 5)
	
	var subject = "Heckle Golf Simulator - Round Stats for %s on %s" % [player_name, course_title]
	
	var pars = {}
	var distances = {}
	for hole_id in MultiplayerManager.hole_ids:
		var hole = MultiplayerManager.hole_info.get(hole_id, {})
		pars[hole_id] = int(round(float(hole.get("Par", 4))))
		distances[hole_id] = { tee_color: _get_hole_distance(hole_id, tee_color) }

	var match_data = {
		"course_title": course_title,
		"formatted_date": date_str,
		"pars": pars,
		"distances": distances,
		"hole_ids": MultiplayerManager.hole_ids
	}

	# Build clean email summary
	var body = "Round Stats for %s\n" % player_name
	body += "Course: %s\n" % course_title
	body += "Tee: %s\n" % tee_color
	body += "Date: %s\n" % date_str
	body += "Total Strokes: %d\n\n" % total_strokes
	body += "Hole-by-Hole Scores:\n"
	body += "==================================================\n"
	
	for hole_id in MultiplayerManager.hole_ids:
		var par = pars.get(hole_id, 4)
		var dist = _get_hole_distance(hole_id, tee_color)
		var score_val = p["hole_scores"].get(hole_id)
		var score_str = str(score_val) if score_val != null else "-"
		body += "%s (Par %d, %d Yds) - Score: %s\n" % [hole_id, par, dist, score_str]
	body += "\n"

	# Generate golf data CSV
	var csv_content = GolfDataExporter.generate_round_csv(p, match_data)
	var safe_player = GolfDataExporter.sanitize_filename(player_name)
	var safe_course = GolfDataExporter.sanitize_filename(course_title)
	var safe_date = GolfDataExporter.sanitize_filename(date_str)
	var attachment_basename = "%s_%s_%s_golf_data" % [safe_player, safe_course, safe_date]
		
	# Load and append historical averages by club
	var stats_path = "user://player_club_stats.json"
	if FileAccess.file_exists(stats_path):
		var file = FileAccess.open(stats_path, FileAccess.READ)
		if file != null:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var player_club_stats = json.data.get(player_name, {})
				if not player_club_stats.is_empty():
					body += "PLAYER CLUB STATISTICS (HISTORICAL AVERAGES):\n"
					body += "=============================================\n"
					body += "%-6s | %-10s | %-10s | %-9s | %-12s | %-14s\n" % ["Club", "Avg Carry", "Avg Speed", "Avg Spin", "Avg Offline", "Avg +/- Target"]
					body += "--------------------------------------------------------------------------------\n"
					
					var club_order = ["Dr", "3w", "5w", "2H", "3H", "4H", "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw", "Pt"]
					for c in player_club_stats.keys():
						if not club_order.has(c):
							club_order.append(c)
							
					for club in club_order:
						if not player_club_stats.has(club) or player_club_stats[club].is_empty():
							continue
							
						var club_shots = player_club_stats[club]
						var sum_carry := 0.0
						var sum_speed := 0.0
						var sum_spin := 0.0
						var sum_offline := 0.0
						var sum_target_diff := 0.0
						var valid_target_diff_count := 0
						
						for shot in club_shots:
							sum_carry += float(shot.get("CarryDistance", 0.0))
							sum_speed += float(shot.get("Speed", 0.0))
							sum_spin += float(shot.get("TotalSpin", 0.0))
							sum_offline += absf(float(shot.get("SideDistance", 0.0)))
							
							var target_dist = float(shot.get("TargetDistance", 0.0))
							var total_dist = float(shot.get("TotalDistance", 0.0))
							if target_dist > 0.0:
								sum_target_diff += (total_dist - target_dist)
								valid_target_diff_count += 1
								
						var cnt = club_shots.size()
						var avg_carry = sum_carry / cnt
						var avg_speed = sum_speed / cnt
						var avg_spin = sum_spin / cnt
						var avg_offline = sum_offline / cnt
						var avg_target_diff = sum_target_diff / valid_target_diff_count if valid_target_diff_count > 0 else 0.0
						
						# Convert to imperial values for the email scorecard
						var carry_val = avg_carry * 1.09361
						var speed_val = avg_speed
						var spin_val = avg_spin
						var offline_val = avg_offline * 1.09361
						var target_diff_val = avg_target_diff * 1.09361
						
						var carry_str = "%.1f yds" % carry_val
						var speed_str = "%.1f mph" % speed_val
						var spin_str = "%.0f rpm" % spin_val
						var offline_str = "%.1f yds" % offline_val
						var target_diff_sign = "+" if target_diff_val >= 0.0 else ""
						var target_diff_str = "%s%.1f yds" % [target_diff_sign, target_diff_val]
						
						if valid_target_diff_count == 0:
							target_diff_str = "---"
							
						body += "%-6s | %-10s | %-10s | %-9s | %-12s | %-14s\n" % [club, carry_str, speed_str, spin_str, offline_str, target_diff_str]
					body += "\n"
		
	body += MultiplayerManager.format_player_swing_issues_summary(player_name)
	
	var to_email = p.get("email", "")
	if to_email.is_empty():
		to_email = MultiplayerManager.get_player_email(player_name)

	GolfDataExporter.export_and_email(to_email, subject, body, attachment_basename, csv_content)
	print("[CoursePlay] Opened email client with attached CSV for %s" % player_name)


func _get_player_circle_texture(color: Color) -> ImageTexture:
	var color_key = color.to_html()
	if _cached_player_textures.has(color_key):
		return _cached_player_textures[color_key]
		
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	var radius := size / 2.0 - 2.0
	
	for y in range(size):
		for x in range(size):
			var dx := x - center + 0.5
			var dy := y - center + 0.5
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= radius - 10.0:
				img.set_pixel(x, y, color)
			elif dist <= radius - 2.0:
				img.set_pixel(x, y, Color.WHITE)
			elif dist <= radius:
				var alpha = clamp((radius - dist) / 1.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	var tex := ImageTexture.create_from_image(img)
	_cached_player_textures[color_key] = tex
	return tex


func _create_player_map_marker(player: Dictionary, letter: String, color: Color) -> Node3D:
	var marker = Node3D.new()
	marker.name = "PlayerMapMarker_" + player["name"]
	
	# Cylinder mesh for the vertical line/stem
	var line_mesh = MeshInstance3D.new()
	line_mesh.name = "LineMesh"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 3.0
	line_mesh.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 2
	line_mesh.material_override = mat
	line_mesh.layers = 2
	line_mesh.position = Vector3(0, 1.5, 0)
	marker.add_child(line_mesh)
	
	# Sprite3D for the circle background or avatar
	var sprite = Sprite3D.new()
	sprite.name = "Sprite"
	
	var avatar_path = player.get("avatar", "")
	if avatar_path.is_empty():
		avatar_path = MultiplayerManager.get_player_avatar(player.get("name", ""))
	var has_avatar = not avatar_path.is_empty() and ResourceLoader.exists(avatar_path)
	
	if has_avatar:
		sprite.texture = load(avatar_path)
	else:
		sprite.texture = _get_player_circle_texture(color)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.render_priority = 3
	sprite.double_sided = true
	sprite.pixel_size = 0.025 # ~3.2m wide
	sprite.position = Vector3(0, 3.0, 0)
	sprite.layers = 2
	marker.add_child(sprite)
	
	# Label3D for the letter (only when not using custom avatar)
	var label = Label3D.new()
	label.name = "Label"
	label.text = "" if has_avatar else letter
	label.font_size = 64
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 4
	label.double_sided = true
	label.position = Vector3(0, 0.0, 0.05) # avoid z-fighting
	label.layers = 2
	sprite.add_child(label)
	
	return marker


func _clear_map_markers() -> void:
	for idx in _player_map_markers:
		var marker = _player_map_markers[idx]
		if is_instance_valid(marker):
			marker.queue_free()
	_player_map_markers.clear()


func _get_player_holes_played(p: Dictionary) -> int:
	var count = 0
	for hole_id in MultiplayerManager.hole_ids:
		if p["hole_scores"].get(hole_id) != null:
			count += 1
	return count


func _get_player_overall_diff(p: Dictionary) -> int:
	var player_total_strokes: int = 0
	var total_par_for_player: int = 0
	for hole_id in MultiplayerManager.hole_ids:
		var s = p["hole_scores"].get(hole_id)
		if s != null:
			player_total_strokes += int(s)
			var hole = MultiplayerManager.hole_info.get(hole_id, {})
			var par = int(hole.get("Par", 4))
			total_par_for_player += par
	return player_total_strokes - total_par_for_player


func _get_player_points(p: Dictionary) -> int:
	var total_pts: int = 0
	for hole_id in MultiplayerManager.hole_ids:
		var s = p["hole_scores"].get(hole_id)
		if s != null:
			total_pts += int(s)
	return total_pts


func _get_overall_par_string(p: Dictionary) -> String:
	var diff = _get_player_overall_diff(p)
	if diff > 0:
		return "+" + str(diff)
	elif diff < 0:
		return str(diff)
	else:
		return "E"


func _get_player_furthest_drive(p: Dictionary) -> float:
	var max_drive = 0.0
	var stats = p.get("shot_stats", {})
	for hole_id in stats:
		var shots = stats[hole_id]
		for shot in shots:
			if shot.get("shot_num") == 1:
				var dist = shot.get("total_yds", 0.0)
				if dist > max_drive:
					max_drive = dist
	return max_drive


func _get_player_best_hole(p: Dictionary) -> Dictionary:
	var best_hole_id = ""
	var best_diff = 9999
	var best_score = 0
	
	for hole_id in MultiplayerManager.hole_ids:
		var s = p["hole_scores"].get(hole_id)
		if s != null:
			var hole = MultiplayerManager.hole_info.get(hole_id, {})
			var par = int(round(float(hole.get("Par", 4))))
			var diff = s - par
			if diff < best_diff:
				best_diff = diff
				best_hole_id = hole_id
				best_score = s
				
	if best_hole_id == "":
		return {}
	return {
		"hole_id": best_hole_id,
		"diff": best_diff,
		"score": best_score
	}


func _populate_overview() -> void:
	# Clear previous contents of hud_overview
	for child in hud_overview.get_children():
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 24)
	hud_overview.add_child(vbox)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.text = "Tournament Results"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.46, 0.72, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title_lbl)
	
	if MultiplayerManager.players.is_empty():
		return
		
	var is_ctp = (MultiplayerManager.game_mode == "Closest to Pin")
	var sorted_players = MultiplayerManager.players.duplicate()
	sorted_players.sort_custom(func(a, b):
		var holes_a = _get_player_holes_played(a)
		var holes_b = _get_player_holes_played(b)
		if holes_a == 0 and holes_b > 0:
			return false
		if holes_b == 0 and holes_a > 0:
			return true
		if holes_a == 0 and holes_b == 0:
			return a["name"] < b["name"]
			
		if is_ctp:
			var pts_a = _get_player_points(a)
			var pts_b = _get_player_points(b)
			if pts_a != pts_b:
				return pts_a > pts_b # HIGHEST SCORE WINS!
			return a["name"] < b["name"]

		var diff_a = _get_player_overall_diff(a)
		var diff_b = _get_player_overall_diff(b)
		if diff_a != diff_b:
			return diff_a < diff_b
		return a["name"] < b["name"]
	)
	
	# Winner presentation (First place)
	var winner = sorted_players[0]
	var winner_diff = ("%d pts" % _get_player_points(winner)) if is_ctp else _get_overall_par_string(winner)
	
	var winner_panel = PanelContainer.new()
	var wp_style = StyleBoxFlat.new()
	wp_style.bg_color = Color(0.12, 0.20, 0.32, 0.8) # Highlighted dark blue
	wp_style.border_width_left = 2
	wp_style.border_width_top = 2
	wp_style.border_width_right = 2
	wp_style.border_width_bottom = 2
	wp_style.border_color = Color(1.0, 0.85, 0.38) # Gold border for winner
	wp_style.corner_radius_top_left = 12
	wp_style.corner_radius_top_right = 12
	wp_style.corner_radius_bottom_left = 12
	wp_style.corner_radius_bottom_right = 12
	wp_style.content_margin_left = 16
	wp_style.content_margin_right = 16
	wp_style.content_margin_top = 16
	wp_style.content_margin_bottom = 16
	winner_panel.add_theme_stylebox_override("panel", wp_style)
	vbox.add_child(winner_panel)
	
	var winner_vbox = VBoxContainer.new()
	winner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	winner_vbox.add_theme_constant_override("separation", 4)
	winner_panel.add_child(winner_vbox)
	
	var winner_title = Label.new()
	winner_title.text = "🏆 WINNER 🏆"
	winner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_title.add_theme_font_size_override("font_size", 24)
	winner_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	winner_title.add_theme_color_override("font_outline_color", Color.BLACK)
	winner_title.add_theme_constant_override("outline_size", 4)
	winner_vbox.add_child(winner_title)
	
	var winner_name_lbl = Label.new()
	winner_name_lbl.text = "%s (%s)" % [winner["name"], winner_diff]
	winner_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_name_lbl.add_theme_font_size_override("font_size", 32)
	winner_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	winner_name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	winner_name_lbl.add_theme_constant_override("outline_size", 4)
	winner_vbox.add_child(winner_name_lbl)
	
	var winner_drive = _get_player_furthest_drive(winner)
	var winner_drive_str = "%.1f yds" % winner_drive if winner_drive > 0.0 else "N/A"
	
	var winner_best = _get_player_best_hole(winner)
	var winner_best_str = "N/A"
	if not winner_best.is_empty():
		var b_diff = winner_best["diff"]
		var b_diff_str = str(b_diff) if b_diff < 0 else ("+" + str(b_diff) if b_diff > 0 else "E")
		winner_best_str = "%s (%s)" % [winner_best["hole_id"], b_diff_str]
		
	var winner_stats_lbl = Label.new()
	if is_ctp:
		winner_stats_lbl.text = "Total Points: %d  |  Furthest Drive: %s" % [_get_player_points(winner), winner_drive_str]
	else:
		winner_stats_lbl.text = "Furthest Drive: %s  |  Best Hole: %s" % [winner_drive_str, winner_best_str]
	winner_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_stats_lbl.add_theme_font_size_override("font_size", 16)
	winner_stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	winner_vbox.add_child(winner_stats_lbl)
	
	# Other Players list
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ThemeManager.apply_scroll_container_style(scroll, 28)
	vbox.add_child(scroll)
	
	var players_list_vbox = VBoxContainer.new()
	players_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(players_list_vbox)
	
	for i in range(1, sorted_players.size()):
		var p = sorted_players[i]
		var p_diff = ("%d pts" % _get_player_points(p)) if is_ctp else _get_overall_par_string(p)
		
		var p_panel = PanelContainer.new()
		var pp_style = StyleBoxFlat.new()
		pp_style.bg_color = Color(0.06, 0.08, 0.12, 0.8) if i % 2 == 1 else Color(0.1, 0.12, 0.18, 0.8)
		pp_style.border_width_bottom = 1
		pp_style.border_color = Color(0.25, 0.25, 0.25, 0.5)
		pp_style.corner_radius_top_left = 6
		pp_style.corner_radius_top_right = 6
		pp_style.corner_radius_bottom_left = 6
		pp_style.corner_radius_bottom_right = 6
		pp_style.content_margin_left = 12
		pp_style.content_margin_right = 12
		pp_style.content_margin_top = 8
		pp_style.content_margin_bottom = 8
		p_panel.add_theme_stylebox_override("panel", pp_style)
		players_list_vbox.add_child(p_panel)
		
		var p_vbox = VBoxContainer.new()
		p_vbox.add_theme_constant_override("separation", 2)
		p_panel.add_child(p_vbox)
		
		var row = HBoxContainer.new()
		p_vbox.add_child(row)
		
		var name_lbl = Label.new()
		name_lbl.text = "%d. %s" % [i + 1, p["name"]]
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		
		var diff_lbl = Label.new()
		diff_lbl.text = p_diff
		diff_lbl.add_theme_font_size_override("font_size", 20)
		if is_ctp:
			diff_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
		elif p_diff.begins_with("-"):
			diff_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
		elif p_diff.begins_with("+"):
			diff_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
		else:
			diff_lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(diff_lbl)
		
		var p_drive = _get_player_furthest_drive(p)
		var p_drive_str = "%.1f yds" % p_drive if p_drive > 0.0 else "N/A"
		
		var stats_lbl = Label.new()
		if is_ctp:
			stats_lbl.text = "Total Points: %d  |  Furthest Drive: %s" % [_get_player_points(p), p_drive_str]
		else:
			var p_best = _get_player_best_hole(p)
			var p_best_str = "N/A"
			if not p_best.is_empty():
				var b_diff = p_best["diff"]
				var b_diff_str = str(b_diff) if b_diff < 0 else ("+" + str(b_diff) if b_diff > 0 else "E")
				p_best_str = "%s (%s)" % [p_best["hole_id"], b_diff_str]
			stats_lbl.text = "Furthest Drive: %s  |  Best Hole: %s" % [p_drive_str, p_best_str]
		stats_lbl.add_theme_font_size_override("font_size", 14)
		stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		p_vbox.add_child(stats_lbl)
		
	# Return to Menu Button
	var menu_btn = Button.new()
	menu_btn.name = "ReturnToMenuBtn"
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apply_material_button_style(menu_btn, Color(0.56, 0.22, 0.22, 0.85))
	menu_btn.pressed.connect(func():
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
	)
	vbox.add_child(menu_btn)


func _draw_ball_overlays(overlay: Control) -> void:
	if MultiplayerManager.is_finished:
		return
		
	# Skip if scorecard, players list, camera setup dialog, replay modal, exit confirm dialog, forfeit dialog, mulligan dialog, or prompt dialogs are open
	if is_any_dialog_open():
		return
	var root = get_tree().root
	var replay_modal = root.find_child("SwingReplayModal", true, false)
	if root.find_child("CameraSetupDialog", true, false) != null or (replay_modal != null and not replay_modal.get("is_detached")):
		return
		
	var is_aerial = false
	if course_instance != null and course_instance.get("is_aerial_view") != null:
		is_aerial = course_instance.get("is_aerial_view") as bool
	if is_aerial:
		return
		
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
		
	var font = overlay.get_theme_font("font")
	var font_size = 18
	
	# Determine active player position for dynamic scaling
	var active_player_pos = Vector3.ZERO
	if active_ball != null:
		active_player_pos = active_ball.global_position
	else:
		var p = MultiplayerManager.get_active_player()
		if not p.is_empty():
			active_player_pos = p.get("position", Vector3.ZERO)
			
	# Draw flag/hole icon
	var pin_pos = course_instance.get("current_hole_location") if course_instance != null else null
	if GlobalSettings.is_chipping_minigame and course_instance != null and course_instance.get("aim_target_pos") != null:
		pin_pos = course_instance.get("aim_target_pos")
	if pin_pos != null and not pin_pos.is_zero_approx():
		var is_on_green = false
		if active_ball != null and not is_player_on_wrong_green():
			is_on_green = (active_ball.get("lie_type") == "green")
		var dist_m = active_player_pos.distance_to(pin_pos)
		var dist_feet = dist_m * 3.28084
		if not is_on_green and dist_feet >= 50.0 and not camera.is_position_behind(pin_pos):
			var screen_pos = camera.unproject_position(pin_pos)
			var view_rect = overlay.get_viewport_rect()
			if view_rect.has_point(screen_pos):
				# Calculate dynamic height based on distance
				var dist_yards = dist_m * 1.09361
				var height = 0.0
				if dist_yards > 10.0:
					var t = clamp((dist_yards - 10.0) / (80.0 - 10.0), 0.0, 1.0)
					height = t * 2.4
					
				var offset_pos = pin_pos + Vector3(0, height, 0)
				if not camera.is_position_behind(offset_pos):
					var circle_pos = camera.unproject_position(offset_pos)
					
					# Draw stem line if height is significant
					if height > 0.1:
						overlay.draw_line(screen_pos, circle_pos, Color(1.0, 1.0, 1.0, 0.5), 2.0)
					
					# Draw circle shadow
					overlay.draw_circle(circle_pos, 17.0, Color(0.0, 0.0, 0.0, 0.35))
					# Draw circle border
					overlay.draw_circle(circle_pos, 16.0, Color(1.0, 1.0, 1.0, 0.6))
					# Draw circle fill (nice flag red)
					overlay.draw_circle(circle_pos, 14.0, Color(0.85, 0.15, 0.15, 0.65))
					
					# Draw flagpole (translucent white)
					overlay.draw_line(circle_pos + Vector2(-2, 7), circle_pos + Vector2(-2, -7), Color(1.0, 1.0, 1.0, 0.7), 2.0)
					
					# Draw flag banner (translucent white triangle)
					var banner_points = PackedVector2Array([
						circle_pos + Vector2(-2, -7),
						circle_pos + Vector2(6, -3.5),
						circle_pos + Vector2(-2, 0)
					])
					var banner_colors = PackedColorArray([
						Color(1.0, 1.0, 1.0, 0.7),
						Color(1.0, 1.0, 1.0, 0.7),
						Color(1.0, 1.0, 1.0, 0.7)
					])
					overlay.draw_polygon(banner_points, banner_colors)
					
	# Don't show player ball icons when you are within 50 feet of the hole
	if pin_pos != null and not pin_pos.is_zero_approx():
		var dist_to_hole_m = active_player_pos.distance_to(pin_pos)
		var dist_to_hole_feet = dist_to_hole_m * 3.28084
		if dist_to_hole_feet < 50.0:
			return

	# Draw other players' balls
	for i in range(MultiplayerManager.players.size()):
		var p = MultiplayerManager.players[i]
		if p.get("holed_out", false) or not p.get("active", true) or p.get("paused", false):
			continue
			
		# Do not show circle for the current player
		if i == MultiplayerManager.active_player_index:
			continue
			
		var ball_pos = p.get("position", Vector3.ZERO)
		if ball_pos.is_zero_approx():
			continue
			
		# Don't show player ball icons anywhere if they are within 20 feet of you
		var dist_m = active_player_pos.distance_to(ball_pos)
		var dist_feet = dist_m * 3.28084
		if dist_feet < 20.0:
			continue
			
		if camera.is_position_behind(ball_pos):
			continue
			
		var screen_pos = camera.unproject_position(ball_pos)
		var view_rect = overlay.get_viewport_rect()
		if not view_rect.has_point(screen_pos):
			continue
			
		# Calculate dynamic height based on distance
		var dist_yards = dist_m * 1.09361
		var height = 0.0
		if dist_yards > 10.0:
			var t = clamp((dist_yards - 10.0) / (80.0 - 10.0), 0.0, 1.0)
			height = t * 2.4
			
		var offset_pos = ball_pos + Vector3(0, height, 0)
		if camera.is_position_behind(offset_pos):
			continue
			
		var circle_pos = camera.unproject_position(offset_pos)
		
		# Draw stem line if height is significant
		if height > 0.1:
			overlay.draw_line(screen_pos, circle_pos, Color(1.0, 1.0, 1.0, 0.5), 2.0)
		
		var p_color = MultiplayerManager.get_player_color(p)
		var translucent_color = Color(p_color.r, p_color.g, p_color.b, 0.65)
		
		var avatar_path = p.get("avatar", "")
		if avatar_path.is_empty():
			avatar_path = MultiplayerManager.get_player_avatar(p.get("name", ""))
		var has_avatar = not avatar_path.is_empty() and ResourceLoader.exists(avatar_path)

		# Draw circle shadow
		overlay.draw_circle(circle_pos, 17.0, Color(0.0, 0.0, 0.0, 0.35))

		if has_avatar:
			var tex = load(avatar_path) as Texture2D
			if tex != null:
				overlay.draw_texture_rect(tex, Rect2(circle_pos - Vector2(16, 16), Vector2(32, 32)), false)
		else:
			# Draw circle border
			overlay.draw_circle(circle_pos, 16.0, Color(1.0, 1.0, 1.0, 0.6))
			# Draw circle fill
			overlay.draw_circle(circle_pos, 14.0, translucent_color)
			
			var letter = p["name"].substr(0, 1).to_upper()
			var text_pos = Vector2(circle_pos.x - 16, circle_pos.y + font.get_ascent(font_size) * 0.35)
			
			overlay.draw_string_outline(font, text_pos, letter, HORIZONTAL_ALIGNMENT_CENTER, 32.0, font_size, 3, Color(0.0, 0.0, 0.0, 0.5))
			overlay.draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_CENTER, 32.0, font_size, Color(1.0, 1.0, 1.0, 0.7))


func apply_zoom_button_style(btn: Button, bg_color: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 20
	style_normal.corner_radius_top_right = 20
	style_normal.corner_radius_bottom_left = 20
	style_normal.corner_radius_bottom_right = 20
	style_normal.content_margin_left = 2
	style_normal.content_margin_right = 2
	style_normal.content_margin_top = 2
	style_normal.content_margin_bottom = 2

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 20)


func _update_grid_button_state(active: bool) -> void:
	if grid_btn == null:
		return
	if active:
		apply_circular_button_style(grid_btn, Color(0.2, 0.6, 0.3, 0.85)) # Green when active
	else:
		apply_circular_button_style(grid_btn, Color(0.15, 0.15, 0.15, 0.85)) # Gray when inactive


func _exit_tree() -> void:
	if _hole_card_tween != null and _hole_card_tween.is_valid():
		_hole_card_tween.kill()
	if has_node("/root/ScreenOffsetManager"):
		var som = get_node("/root/ScreenOffsetManager")
		if som != null:
			if course_instance != null:
				var cam = course_instance.get_node_or_null("PhantomCamera3D")
				if cam == null:
					cam = course_instance.get_node_or_null("Camera3D")
				if cam != null:
					som.call("unregister_camera", cam)
			som.call("set_putter_active", false)


class MultiplayerBallOverlay extends Control:
	var _controller: Node = null
	
	func _init(controller: Node) -> void:
		_controller = controller
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	func _draw() -> void:
		if _controller != null and _controller.has_method("_draw_ball_overlays"):
			_controller._draw_ball_overlays(self)
