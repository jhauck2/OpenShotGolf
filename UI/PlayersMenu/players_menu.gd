extends Control

const BallTypePhysics = preload("res://Utils/ball_type_physics.gd")
const ClubDeliveryVisuals = preload("res://UI/GolferCamera/club_delivery_visuals.gd")
const ShotAnalyticsEngineScript = preload("res://Utils/shot_analytics_engine.gd")
const AnalyticsVisualWidgetsScript = preload("res://UI/ShotAnalysis/analytics_visual_widgets.gd")
const BudgetPausedBanner = preload("res://UI/Account/budget_paused_banner.gd")
const AccountModalScene = preload("res://UI/Account/account_modal.tscn")
const LinkServiceClass = preload("res://Utils/Cloud/link_service.gd")
const LinkGuestModalClass = preload("res://UI/PlayersMenu/link_guest_modal.gd")
const ApprovalsModalClass = preload("res://UI/PlayersMenu/approvals_modal.gd")

const CLUB_CATEGORIES = [
	{
		"category": "Drivers & Fairway Woods",
		"clubs": [
			{"code": "Dr", "name": "Driver"},
			{"code": "3w", "name": "3 Wood"},
			{"code": "5w", "name": "5 Wood"}
		]
	},
	{
		"category": "Hybrids",
		"clubs": [
			{"code": "2H", "name": "2 Hybrid"},
			{"code": "3H", "name": "3 Hybrid"},
			{"code": "4H", "name": "4 Hybrid"}
		]
	},
	{
		"category": "Irons",
		"clubs": [
			{"code": "1i", "name": "1 Iron"},
			{"code": "2i", "name": "2 Iron"},
			{"code": "3i", "name": "3 Iron"},
			{"code": "4i", "name": "4 Iron"},
			{"code": "5i", "name": "5 Iron"},
			{"code": "6i", "name": "6 Iron"},
			{"code": "7i", "name": "7 Iron"},
			{"code": "8i", "name": "8 Iron"},
			{"code": "9i", "name": "9 Iron"}
		]
	},
	{
		"category": "Wedges",
		"clubs": [
			{"code": "Pw", "name": "Pitching Wedge"},
			{"code": "Gw", "name": "Gap Wedge"},
			{"code": "Sw", "name": "Sand Wedge"},
			{"code": "Lw", "name": "Lob Wedge"}
		]
	},
	{
		"category": "Putters",
		"clubs": [
			{"code": "Pt", "name": "Putter"}
		]
	}
]

const STANDARD_14_BAG: Array[String] = [
	"Dr", "3w", "5w", "4H", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw", "Pt"
]

@onready var players_list_vbox = VBoxContainer.new()
@onready var stats_panel = PanelContainer.new()
@onready var new_player_input = LineEdit.new()
@onready var new_player_email_input = LineEdit.new()

@onready var delete_confirm_dialog = ConfirmationDialog.new()
@onready var clear_confirm_dialog = ConfirmationDialog.new()
@onready var clear_club_confirm_dialog = ConfirmationDialog.new()
@onready var alert_dialog = AcceptDialog.new()

@onready var avatar_picker_dialog = ConfirmationDialog.new()
@onready var edit_profile_dialog = ConfirmationDialog.new()
@onready var create_profile_dialog = ConfirmationDialog.new()

var selected_player_name: String = ""
var pending_club_to_clear: String = ""
var show_only_active_clubs: bool = true
var last_active_tab_index: int = 0

var new_player_avatar_path: String = ""
var avatar_preview_btn: Button = Button.new()
var new_player_tee_opt: OptionButton = OptionButton.new()
var new_player_skill_opt: OptionButton = OptionButton.new()
var new_player_handedness_opt: OptionButton = OptionButton.new()
var avatar_picker_callback: Callable
var avatar_picker_selected_path: String = ""
var avatar_picker_content: VBoxContainer = VBoxContainer.new()
var avatar_picker_buttons: Array = []

var new_player_ball_opt: OptionButton = OptionButton.new()
var new_player_ball_type_opt: OptionButton = OptionButton.new()
var new_player_ball_preview_container: Control = null
var create_profile_content: VBoxContainer = VBoxContainer.new()
var create_profile_avatar_preview_container: Control = null
var create_profile_ball_preview_container: Control = null
var open_create_profile_btn: Button = null

var edit_profile_player_name: String = ""
var edit_profile_email_input: LineEdit = LineEdit.new()
var edit_profile_avatar_path: String = ""
var edit_profile_ball_graphic: String = "single_line"
var edit_profile_ball_type: String = "standard"
var edit_profile_tee_opt: OptionButton = null
var edit_profile_skill_opt: OptionButton = null
var edit_profile_handedness_opt: OptionButton = null
var edit_profile_ball_opt: OptionButton = null
var edit_profile_ball_type_opt: OptionButton = null
var edit_profile_content: VBoxContainer = VBoxContainer.new()
var edit_profile_avatar_preview_container: Control = null
var edit_profile_ball_preview_container: Control = null
var back_btn: Button = null

var cloud_bar_container: VBoxContainer = null
var budget_paused_banner: BudgetPausedBanner = null
var cloud_status_label: Label = null
var cloud_account_btn: Button = null
var cloud_approvals_btn: Button = null
var cloud_sync_now_btn: Button = null
var cloud_sign_in_btn: Button = null
var primary_confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
var register_btn: Button = null

func _ball_graphic_id_to_name(graphic_id: String) -> String:
	for bg in MultiplayerManager.AVAILABLE_BALL_GRAPHICS:
		if bg["id"] == graphic_id:
			return bg["name"]
	return "Single Alignment Line (Default)"

func _ball_graphic_id_to_index(graphic_id: String) -> int:
	for i in range(MultiplayerManager.AVAILABLE_BALL_GRAPHICS.size()):
		if MultiplayerManager.AVAILABLE_BALL_GRAPHICS[i]["id"] == graphic_id:
			return i
	return 0

func _ball_graphic_index_to_id(idx: int) -> String:
	if idx >= 0 and idx < MultiplayerManager.AVAILABLE_BALL_GRAPHICS.size():
		return MultiplayerManager.AVAILABLE_BALL_GRAPHICS[idx]["id"]
	return "single_line"

func _ball_type_id_to_name(ball_type_id: String) -> String:
	return BallTypePhysics.id_to_display_name(ball_type_id)

func _ball_type_id_to_index(ball_type_id: String) -> int:
	var norm_id = BallTypePhysics.normalize_ball_type(ball_type_id)
	for i in range(MultiplayerManager.AVAILABLE_BALL_TYPES.size()):
		if MultiplayerManager.AVAILABLE_BALL_TYPES[i]["id"] == norm_id:
			return i
	return 0

func _ball_type_index_to_id(idx: int) -> String:
	if idx >= 0 and idx < MultiplayerManager.AVAILABLE_BALL_TYPES.size():
		return MultiplayerManager.AVAILABLE_BALL_TYPES[idx]["id"]
	return "standard"

func _create_ball_preview_icon(graphic_id: String, avatar_path: String = "", player_name: String = "", size: Vector2 = Vector2(56, 56)) -> Control:
	var root_ctrl := Control.new()
	root_ctrl.custom_minimum_size = size
	root_ctrl.clip_contents = true

	var bg_panel := Panel.new()
	bg_panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = int(size.x / 2.0)
	style.corner_radius_top_right = int(size.x / 2.0)
	style.corner_radius_bottom_left = int(size.x / 2.0)
	style.corner_radius_bottom_right = int(size.x / 2.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.40, 0.48, 0.58, 0.8)
	style.bg_color = Color(0.97, 0.97, 0.99)
	bg_panel.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(bg_panel)

	match graphic_id:
		"single_line":
			# Wilson Staff Model style: Bold center black alignment line with parallel accents
			var line_c := ColorRect.new()
			line_c.color = Color(0.08, 0.08, 0.10)
			line_c.size = Vector2(size.x * 0.94, 5.0)
			line_c.position = Vector2(size.x * 0.03, size.y / 2.0 - 2.5)
			root_ctrl.add_child(line_c)

			var line_top := ColorRect.new()
			line_top.color = Color(0.28, 0.30, 0.36)
			line_top.size = Vector2(size.x * 0.82, 2.5)
			line_top.position = Vector2(size.x * 0.09, size.y / 2.0 - 7.5)
			root_ctrl.add_child(line_top)

			var line_bot := ColorRect.new()
			line_bot.color = Color(0.28, 0.30, 0.36)
			line_bot.size = Vector2(size.x * 0.82, 2.5)
			line_bot.position = Vector2(size.x * 0.09, size.y / 2.0 + 5.0)
			root_ctrl.add_child(line_bot)

			# Central aim indicator
			var arr := Label.new()
			arr.text = "►"
			arr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arr.size = size
			arr.add_theme_font_size_override("font_size", int(size.y * 0.32))
			arr.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
			root_ctrl.add_child(arr)

		"triple_track":
			# Bold red center line, two bold blue outer lines
			var red_line := ColorRect.new()
			red_line.color = Color(0.88, 0.10, 0.12)
			red_line.size = Vector2(size.x * 0.96, 6.0)
			red_line.position = Vector2(size.x * 0.02, size.y / 2.0 - 3.0)
			root_ctrl.add_child(red_line)

			var blue_top := ColorRect.new()
			blue_top.color = Color(0.08, 0.38, 0.88)
			blue_top.size = Vector2(size.x * 0.84, 3.5)
			blue_top.position = Vector2(size.x * 0.08, size.y / 2.0 - 9.5)
			root_ctrl.add_child(blue_top)

			var blue_bot := ColorRect.new()
			blue_bot.color = Color(0.08, 0.38, 0.88)
			blue_bot.size = Vector2(size.x * 0.84, 3.5)
			blue_bot.position = Vector2(size.x * 0.08, size.y / 2.0 + 6.0)
			root_ctrl.add_child(blue_bot)

		"arrow_track":
			# High-contrast directional chevrons pointing along aim
			var chevrons_box := HBoxContainer.new()
			chevrons_box.alignment = BoxContainer.ALIGNMENT_CENTER
			chevrons_box.add_theme_constant_override("separation", 3)
			chevrons_box.size = size
			chevrons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for i in range(3):
				var ch := Label.new()
				ch.text = "»"
				ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ch.add_theme_font_size_override("font_size", int(size.y * 0.44))
				ch.add_theme_color_override("font_color", Color(1.0, 0.48, 0.04) if i == 1 else Color(0.10, 0.10, 0.12))
				chevrons_box.add_child(ch)
			root_ctrl.add_child(chevrons_box)

		"player_icon":
			if not avatar_path.is_empty() and ResourceLoader.exists(avatar_path):
				var trect := TextureRect.new()
				trect.texture = load(avatar_path)
				trect.custom_minimum_size = Vector2(size.x * 0.55, size.y * 0.55)
				trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				trect.position = Vector2(size.x * 0.225, size.y * 0.225)
				root_ctrl.add_child(trect)
			else:
				var init_lbl := Label.new()
				init_lbl.text = player_name.substr(0, 1).to_upper() if not player_name.is_empty() else "P"
				init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				init_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				init_lbl.size = size
				init_lbl.add_theme_font_size_override("font_size", int(size.y * 0.44))
				init_lbl.add_theme_color_override("font_color", Color(0.2, 0.45, 0.85))
				root_ctrl.add_child(init_lbl)

	return root_ctrl

func _skill_key_to_index(skill_key: String) -> int:
	match skill_key.to_lower().strip_edges():
		"tour_pro": return 3
		"scratch", "low_handicap": return 1
		"high_handicap", "beginner": return 2
		_: return 0 # mid_handicap is default

func _skill_index_to_key(idx: int) -> String:
	match idx:
		1: return "scratch"
		2: return "high_handicap"
		3: return "tour_pro"
		_: return "mid_handicap"

func _skill_key_to_display(skill_key: String) -> String:
	match skill_key.to_lower().strip_edges():
		"tour_pro": return "Tour Professional (+ HCP)"
		"scratch", "low_handicap": return "Scratch / Low (0–9 HCP)"
		"high_handicap", "beginner": return "High Handicap (20+ HCP)"
		_: return "Mid Handicap (10–19 HCP)"

func _ready() -> void:
	name = "PlayersMenu"
	
	# Background Cabo Texture
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
	
	# Semi-transparent dark green overlay
	var glass_panel = ColorRect.new()
	glass_panel.color = Color(0.05, 0.08, 0.05, 0.82)
	glass_panel.anchor_left = 0.0
	glass_panel.anchor_right = 1.0
	glass_panel.anchor_top = 0.0
	glass_panel.anchor_bottom = 1.0
	add_child(glass_panel)
	
	# Main layout margin
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
	
	# Header with Title, Cloud Account Bar & Back Button
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "Player Profiles"
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	header_hbox.add_child(title_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	# Top Cloud Account Bar integrated between Player Profiles header and Main Menu button
	_setup_cloud_account_bar(header_hbox)
	
	back_btn = Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "Main Menu"
	back_btn.icon = load("res://UI/MainMenu/images/menu.svg")
	back_btn.expand_icon = true
	back_btn.custom_minimum_size = Vector2(160, 48)
	back_btn.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_nav_button_style(back_btn)
	back_btn.pressed.connect(func():
		if has_node("/root/SceneManager"):
			get_node("/root/SceneManager").call("change_scene", "res://UI/MainMenu/main_menu.tscn")
		elif get_tree() != null:
			get_tree().change_scene_to_file("res://UI/MainMenu/main_menu.tscn")
	)
	header_hbox.add_child(back_btn)
	
	# Horizontal Split for Left (List) and Right (Stats)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(content_hbox)
	
	# --- LEFT COLUMN: Players List & Registration ---
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(360, 0)
	left_vbox.add_theme_constant_override("separation", 16)
	content_hbox.add_child(left_vbox)
	
	var list_title = Label.new()
	list_title.text = "Players Registry"
	list_title.add_theme_font_size_override("font_size", 24)
	list_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	left_vbox.add_child(list_title)
	
	# ScrollContainer for player list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(scroll, 28)
	left_vbox.add_child(scroll)
	
	players_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(players_list_vbox)
	
	# Create Profile Button at the bottom of the left column
	var reg_section = VBoxContainer.new()
	reg_section.add_theme_constant_override("separation", 8)
	left_vbox.add_child(reg_section)

	open_create_profile_btn = Button.new()
	open_create_profile_btn.name = "OpenCreateProfileBtn"
	open_create_profile_btn.text = "➕ Create New Profile"
	open_create_profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_create_profile_btn.custom_minimum_size = Vector2(0, 50)
	open_create_profile_btn.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_primary_button_style(open_create_profile_btn, 6)
	open_create_profile_btn.pressed.connect(_open_create_profile_dialog)
	reg_section.add_child(open_create_profile_btn)

	new_player_input.name = "NewPlayerInput"
	new_player_input.placeholder_text = "New Player Name"
	new_player_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_input.custom_minimum_size = Vector2(0, 50)
	new_player_input.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_input_style(new_player_input)
	new_player_input.text_submitted.connect(func(_t): new_player_email_input.grab_focus())
	new_player_input.gui_input.connect(func(ev: InputEvent):
		if has_node("/root/VirtualKeyboardManager"):
			var vkm = get_node("/root/VirtualKeyboardManager")
			if vkm.is_controller_mode_active():
				if (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_A) or ev.is_action_pressed("ui_accept"):
					vkm.open_for(new_player_input, true)
					get_viewport().set_input_as_handled()
	)

	new_player_email_input.name = "NewPlayerEmailInput"
	new_player_email_input.placeholder_text = "Optional Email Address"
	new_player_email_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_email_input.custom_minimum_size = Vector2(0, 50)
	new_player_email_input.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_input_style(new_player_email_input)
	new_player_email_input.text_submitted.connect(func(_t): new_player_tee_opt.grab_focus())
	new_player_email_input.gui_input.connect(func(ev: InputEvent):
		if has_node("/root/VirtualKeyboardManager"):
			var vkm = get_node("/root/VirtualKeyboardManager")
			if vkm.is_controller_mode_active():
				if (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_A) or ev.is_action_pressed("ui_accept"):
					vkm.open_for(new_player_email_input, true)
					get_viewport().set_input_as_handled()
	)

	new_player_tee_opt.name = "NewPlayerTeeOpt"
	new_player_tee_opt.clear()
	new_player_tee_opt.add_item("Preferred Tee: None", 0)
	new_player_tee_opt.add_item("Preferred Tee: Blue", 1)
	new_player_tee_opt.add_item("Preferred Tee: Red", 2)
	new_player_tee_opt.add_item("Preferred Tee: White", 3)
	new_player_tee_opt.add_item("Preferred Tee: Black", 4)
	new_player_tee_opt.add_item("Preferred Tee: Gold", 5)
	new_player_tee_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_tee_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(new_player_tee_opt, 17, Vector2(0, 50))

	new_player_skill_opt.name = "NewPlayerSkillOpt"
	new_player_skill_opt.clear()
	new_player_skill_opt.add_item("Skill: Mid Handicap (10–19 HCP)", 0)
	new_player_skill_opt.add_item("Skill: Scratch / Low (0–9 HCP)", 1)
	new_player_skill_opt.add_item("Skill: High Handicap (20+ HCP)", 2)
	new_player_skill_opt.add_item("Skill: Tour Professional (+ HCP)", 3)
	new_player_skill_opt.selected = 0
	new_player_skill_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_skill_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(new_player_skill_opt, 17, Vector2(0, 50))

	new_player_handedness_opt.name = "NewPlayerHandednessOpt"
	new_player_handedness_opt.clear()
	new_player_handedness_opt.add_item("Dexterity: Right-Handed", 0)
	new_player_handedness_opt.add_item("Dexterity: Left-Handed", 1)
	new_player_handedness_opt.selected = 0
	new_player_handedness_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_handedness_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(new_player_handedness_opt, 17, Vector2(0, 50))

	new_player_ball_preview_container = HBoxContainer.new()

	new_player_ball_opt.name = "NewPlayerBallOpt"
	new_player_ball_opt.clear()
	for bg in MultiplayerManager.AVAILABLE_BALL_GRAPHICS:
		new_player_ball_opt.add_item("Ball: " + bg["name"], new_player_ball_opt.item_count)
	new_player_ball_opt.selected = 0
	new_player_ball_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_ball_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(new_player_ball_opt, 17, Vector2(0, 50))
	new_player_ball_opt.item_selected.connect(func(_idx: int): _update_new_player_ball_preview())

	new_player_ball_type_opt.name = "NewPlayerBallTypeOpt"
	new_player_ball_type_opt.clear()
	for bt in MultiplayerManager.AVAILABLE_BALL_TYPES:
		new_player_ball_type_opt.add_item("Ball Type: " + bt["name"], new_player_ball_type_opt.item_count)
	new_player_ball_type_opt.selected = 0
	new_player_ball_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player_ball_type_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(new_player_ball_type_opt, 17, Vector2(0, 50))

	avatar_preview_btn.name = "AvatarPreviewBtn"
	avatar_preview_btn.text = "Avatar: None"
	avatar_preview_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar_preview_btn.custom_minimum_size = Vector2(0, 50)
	avatar_preview_btn.add_theme_font_size_override("font_size", 17)
	ThemeManager.apply_secondary_button_style(avatar_preview_btn)
	avatar_preview_btn.pressed.connect(func():
		_open_avatar_picker(new_player_avatar_path, func(chosen):
			new_player_avatar_path = chosen
			_update_new_player_avatar_preview()
		)
	)

	register_btn = Button.new()
	register_btn.name = "RegisterBtn"
	register_btn.text = "Register"
	register_btn.custom_minimum_size = Vector2(120, 50)
	register_btn.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_primary_button_style(register_btn)
	register_btn.pressed.connect(_on_register_pressed)
	
	# --- RIGHT COLUMN: Stats & Profile Details ---
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_modal_style(stats_panel)
	content_hbox.add_child(stats_panel)
	
	# Dialog Setup
	delete_confirm_dialog.title = "Delete Player permanently"
	delete_confirm_dialog.dialog_text = "Are you sure you want to permanently delete this player profile? This will also wipe their club averages statistics, and cannot be undone."
	delete_confirm_dialog.min_size = Vector2(480, 180)
	ThemeManager.apply_dialog_style(delete_confirm_dialog)
	delete_confirm_dialog.confirmed.connect(_confirm_delete_player)
	add_child(delete_confirm_dialog)
	
	clear_confirm_dialog.title = "Clear All Ball History"
	clear_confirm_dialog.dialog_text = "Are you sure you want to clear this player's entire ball history across all clubs? This resets all their club average carries, speed, spin, and target diff statistics, and cannot be undone."
	clear_confirm_dialog.min_size = Vector2(500, 180)
	ThemeManager.apply_dialog_style(clear_confirm_dialog)
	clear_confirm_dialog.confirmed.connect(_confirm_clear_history)
	add_child(clear_confirm_dialog)
	
	clear_club_confirm_dialog.title = "Clear Club Shot Data"
	clear_club_confirm_dialog.min_size = Vector2(500, 180)
	ThemeManager.apply_dialog_style(clear_club_confirm_dialog)
	clear_club_confirm_dialog.confirmed.connect(_confirm_clear_club_shot_data)
	add_child(clear_club_confirm_dialog)

	primary_confirm_dialog.title = "Set Primary Cloud Profile"
	primary_confirm_dialog.min_size = Vector2(500, 180)
	ThemeManager.apply_dialog_style(primary_confirm_dialog)
	add_child(primary_confirm_dialog)
	
	alert_dialog.title = "Alert"
	alert_dialog.min_size = Vector2(380, 160)
	ThemeManager.apply_dialog_style(alert_dialog)
	add_child(alert_dialog)

	# Avatar Picker Dialog
	avatar_picker_dialog.title = "Select Player Avatar"
	avatar_picker_dialog.min_size = Vector2(620, 540)
	ThemeManager.apply_dialog_style(avatar_picker_dialog, Vector2(160, 52), 18)
	avatar_picker_dialog.confirmed.connect(_on_avatar_picker_confirmed)
	avatar_picker_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar_picker_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar_picker_content.add_theme_constant_override("separation", 12)
	avatar_picker_dialog.add_child(avatar_picker_content)
	add_child(avatar_picker_dialog)
	
	# Edit Profile Dialog
	edit_profile_dialog.title = "Edit Player Profile"
	edit_profile_dialog.min_size = Vector2(580, 500)
	ThemeManager.apply_dialog_style(edit_profile_dialog, Vector2(160, 52), 18)
	edit_profile_dialog.confirmed.connect(_on_edit_profile_confirmed)
	edit_profile_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_profile_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_profile_content.add_theme_constant_override("separation", 14)
	edit_profile_dialog.add_child(edit_profile_content)
	add_child(edit_profile_dialog)

	# Create Profile Dialog
	create_profile_dialog.title = "Create Player Profile"
	create_profile_dialog.min_size = Vector2(580, 500)
	ThemeManager.apply_dialog_style(create_profile_dialog, Vector2(160, 52), 18)
	create_profile_dialog.confirmed.connect(_on_register_pressed)
	create_profile_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_profile_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	create_profile_content.add_theme_constant_override("separation", 14)
	create_profile_dialog.add_child(create_profile_content)
	add_child(create_profile_dialog)
	
	# Load and render registered list
	_refresh_players_list()
	_render_empty_stats()
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if not is_visible_in_tree():
		return
	if has_node("/root/VirtualKeyboardManager"):
		var vkm = get_node("/root/VirtualKeyboardManager")
		if vkm.is_controller_mode_active():
			var registered = MultiplayerManager.get_registered_players()
			if registered.is_empty():
				if open_create_profile_btn != null and is_instance_valid(open_create_profile_btn):
					open_create_profile_btn.call_deferred("grab_focus")
				else:
					new_player_input.call_deferred("grab_focus")
				return
	if has_node("/root/KeybindingManager"):
		var km = get_node("/root/KeybindingManager")
		km.focus_first_control(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		var guest_modal = get_node_or_null("LinkGuestModal")
		if guest_modal != null and is_instance_valid(guest_modal):
			if guest_modal.has_method("close"):
				guest_modal.close()
			else:
				guest_modal.queue_free()
			get_viewport().set_input_as_handled()
			return
		var app_modal = get_node_or_null("ApprovalsModal")
		if app_modal != null and is_instance_valid(app_modal):
			if app_modal.has_method("close"):
				app_modal.close()
			else:
				app_modal.queue_free()
			get_viewport().set_input_as_handled()
			return
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg.is_modal_active():
			return
	if event.is_action_pressed("ui_cancel"):
		if delete_confirm_dialog != null and delete_confirm_dialog.visible:
			delete_confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if clear_confirm_dialog != null and clear_confirm_dialog.visible:
			clear_confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if clear_club_confirm_dialog != null and clear_club_confirm_dialog.visible:
			clear_club_confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if alert_dialog != null and alert_dialog.visible:
			alert_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		var issue_modal = get_node_or_null("IssueDetailModal")
		if issue_modal != null and is_instance_valid(issue_modal):
			InAppVideoPlayer.stop_all_players()
			if has_node("/root/UIFocusGuard"):
				get_node("/root/UIFocusGuard").pop_lock()
			issue_modal.queue_free()
			get_viewport().set_input_as_handled()
			return
		if avatar_picker_dialog != null and avatar_picker_dialog.visible:
			avatar_picker_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if edit_profile_dialog != null and edit_profile_dialog.visible:
			edit_profile_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if create_profile_dialog != null and create_profile_dialog.visible:
			create_profile_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
		get_viewport().set_input_as_handled()
		return

	# Controller bumper tab cycling in player profile (LB/RB or L1/R1)
	if stats_panel != null and is_instance_valid(stats_panel):
		var tabs = stats_panel.find_child("TabContainer", true, false) as TabContainer
		if tabs != null and tabs.is_visible_in_tree() and tabs.get_tab_count() > 1:
			var is_lb: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER and event.pressed)
			var is_rb: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER and event.pressed)
			if is_lb:
				tabs.current_tab = (tabs.current_tab - 1 + tabs.get_tab_count()) % tabs.get_tab_count()
				last_active_tab_index = tabs.current_tab
				get_viewport().set_input_as_handled()
				return
			elif is_rb:
				tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count()
				last_active_tab_index = tabs.current_tab
				get_viewport().set_input_as_handled()
				return


func _refresh_players_list() -> void:
	for child in players_list_vbox.get_children():
		players_list_vbox.remove_child(child)
		child.queue_free()
		
	var registered = MultiplayerManager.get_registered_players()
	
	if registered.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No players registered yet."
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		players_list_vbox.add_child(empty_lbl)
		call_deferred("_update_controller_focus_navigation")
		return
		
	for p in registered:
		var p_name = p.get("name", "Player")
		var p_avatar = p.get("avatar", "")
		var btn = Button.new()
		btn.text = "  " + p_name
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if not p_avatar.is_empty() and ResourceLoader.exists(p_avatar):
			btn.icon = load(p_avatar)
			btn.expand_icon = true
		
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = Color(0.12, 0.18, 0.12, 0.5)
		btn_style_normal.corner_radius_top_left = 6
		btn_style_normal.corner_radius_top_right = 6
		btn_style_normal.corner_radius_bottom_left = 6
		btn_style_normal.corner_radius_bottom_right = 6
		btn_style_normal.content_margin_left = 12
		btn_style_normal.content_margin_right = 12
		
		var btn_style_hover = btn_style_normal.duplicate()
		btn_style_hover.bg_color = Color(0.24, 0.46, 0.72, 0.6)
		
		var btn_style_pressed = btn_style_normal.duplicate()
		btn_style_pressed.bg_color = Color(0.24, 0.46, 0.72, 0.8)
		
		btn.add_theme_stylebox_override("normal", btn_style_normal)
		btn.add_theme_stylebox_override("hover", btn_style_hover)
		btn.add_theme_stylebox_override("pressed", btn_style_pressed)
		
		if p_name == selected_player_name:
			var btn_style_selected = btn_style_normal.duplicate()
			btn_style_selected.bg_color = Color(0.24, 0.46, 0.72, 0.7)
			btn_style_selected.border_width_left = 4
			btn_style_selected.border_color = Color(0.85, 0.65, 0.15)
			btn.add_theme_stylebox_override("normal", btn_style_selected)
			btn.call_deferred("grab_focus")
			
		btn.pressed.connect(func(): _select_player(p_name))
		players_list_vbox.add_child(btn)

	call_deferred("_update_controller_focus_navigation")


func _update_controller_focus_navigation() -> void:
	if not is_inside_tree() or not is_instance_valid(back_btn) or not back_btn.is_inside_tree() or not is_instance_valid(open_create_profile_btn) or not open_create_profile_btn.is_inside_tree() or not is_instance_valid(new_player_input):
		return

	var player_buttons: Array[Button] = []
	for child in players_list_vbox.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion():
			player_buttons.append(child)

	# Setup Cloud Bar buttons focus
	var active_cloud_btn: Button = null
	if is_instance_valid(cloud_sign_in_btn) and cloud_sign_in_btn.is_visible_in_tree():
		active_cloud_btn = cloud_sign_in_btn
		cloud_sign_in_btn.focus_mode = Control.FOCUS_ALL
		cloud_sign_in_btn.focus_neighbor_left = back_btn.get_path()
		back_btn.focus_neighbor_right = cloud_sign_in_btn.get_path()
	elif is_instance_valid(cloud_sync_now_btn) and cloud_sync_now_btn.is_visible_in_tree():
		active_cloud_btn = cloud_sync_now_btn
		cloud_sync_now_btn.focus_mode = Control.FOCUS_ALL
		var right_cursor: Button = cloud_sync_now_btn
		if is_instance_valid(cloud_approvals_btn) and cloud_approvals_btn.is_visible_in_tree():
			cloud_approvals_btn.focus_mode = Control.FOCUS_ALL
			cloud_sync_now_btn.focus_neighbor_right = cloud_approvals_btn.get_path()
			cloud_approvals_btn.focus_neighbor_left = cloud_sync_now_btn.get_path()
			right_cursor = cloud_approvals_btn
		if is_instance_valid(cloud_account_btn) and cloud_account_btn.is_visible_in_tree():
			cloud_account_btn.focus_mode = Control.FOCUS_ALL
			right_cursor.focus_neighbor_right = cloud_account_btn.get_path()
			cloud_account_btn.focus_neighbor_left = right_cursor.get_path()
		back_btn.focus_neighbor_right = cloud_sync_now_btn.get_path()
		cloud_sync_now_btn.focus_neighbor_left = back_btn.get_path()

	if player_buttons.is_empty():
		back_btn.focus_neighbor_bottom = open_create_profile_btn.get_path()
		back_btn.focus_neighbor_left = open_create_profile_btn.get_path()
		open_create_profile_btn.focus_neighbor_top = back_btn.get_path()
		if active_cloud_btn != null:
			active_cloud_btn.focus_neighbor_bottom = open_create_profile_btn.get_path()
		if is_instance_valid(cloud_approvals_btn) and cloud_approvals_btn.is_visible_in_tree():
			cloud_approvals_btn.focus_neighbor_bottom = open_create_profile_btn.get_path()
		if is_instance_valid(cloud_account_btn) and cloud_account_btn.is_visible_in_tree():
			cloud_account_btn.focus_neighbor_bottom = open_create_profile_btn.get_path()
	else:
		back_btn.focus_neighbor_bottom = player_buttons[0].get_path()
		back_btn.focus_neighbor_left = player_buttons[0].get_path()
		player_buttons[0].focus_neighbor_top = back_btn.get_path()
		if active_cloud_btn != null:
			active_cloud_btn.focus_neighbor_bottom = player_buttons[0].get_path()
		if is_instance_valid(cloud_approvals_btn) and cloud_approvals_btn.is_visible_in_tree():
			cloud_approvals_btn.focus_neighbor_bottom = player_buttons[0].get_path()
		if is_instance_valid(cloud_account_btn) and cloud_account_btn.is_visible_in_tree():
			cloud_account_btn.focus_neighbor_bottom = player_buttons[0].get_path()
		for i in range(player_buttons.size() - 1):
			player_buttons[i].focus_neighbor_bottom = player_buttons[i + 1].get_path()
			player_buttons[i + 1].focus_neighbor_top = player_buttons[i].get_path()
		player_buttons.back().focus_neighbor_bottom = open_create_profile_btn.get_path()
		open_create_profile_btn.focus_neighbor_top = player_buttons.back().get_path()

	open_create_profile_btn.focus_neighbor_bottom = back_btn.get_path()

	# Wire cross-navigation between player list and profile view
	if stats_panel != null and is_instance_valid(stats_panel):
		var primary_btn = stats_panel.find_child("PrimaryProfileBtn", true, false) as Button
		var cloud_link_sec = stats_panel.find_child("CloudLinkSection", true, false) as Control
		var edit_profile_btn = stats_panel.find_child("EditProfileBtn", true, false) as Button
		var tabs = stats_panel.find_child("TabContainer", true, false) as TabContainer
		var tab_bar: TabBar = tabs.get_tab_bar() if tabs != null else null
		var email_report_btn = stats_panel.find_child("EmailReportBtn", true, false) as Button
		var clear_btn = stats_panel.find_child("ClearBallHistoryBtn", true, false) as Button
		var delete_btn = stats_panel.find_child("DeleteProfileBtn", true, false) as Button

		if primary_btn != null and is_instance_valid(primary_btn):
			primary_btn.focus_mode = Control.FOCUS_ALL

		var right_target: Control = primary_btn if (primary_btn != null and is_instance_valid(primary_btn)) else (cloud_link_sec if (cloud_link_sec != null and is_instance_valid(cloud_link_sec) and cloud_link_sec.get_child_count() > 0) else (edit_profile_btn if (edit_profile_btn != null and is_instance_valid(edit_profile_btn)) else (tab_bar if (tab_bar != null and is_instance_valid(tab_bar)) else null)))
		if right_target != null and not player_buttons.is_empty():
			for p_btn in player_buttons:
				p_btn.focus_neighbor_right = p_btn.get_path_to(right_target)
			open_create_profile_btn.focus_neighbor_right = open_create_profile_btn.get_path_to(right_target)

		if primary_btn != null and is_instance_valid(primary_btn):
			if not player_buttons.is_empty():
				primary_btn.focus_neighbor_left = primary_btn.get_path_to(player_buttons[0])
			else:
				primary_btn.focus_neighbor_left = primary_btn.get_path_to(open_create_profile_btn)
			if tab_bar != null and is_instance_valid(tab_bar):
				primary_btn.focus_neighbor_bottom = primary_btn.get_path_to(tab_bar)
				tab_bar.focus_neighbor_top = tab_bar.get_path_to(primary_btn)

		var cloud_link_buttons: Array[Button] = []
		if cloud_link_sec != null and is_instance_valid(cloud_link_sec):
			for child in cloud_link_sec.get_children():
				if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion():
					child.focus_mode = Control.FOCUS_ALL
					cloud_link_buttons.append(child)

		if not cloud_link_buttons.is_empty():
			if primary_btn != null and is_instance_valid(primary_btn):
				primary_btn.focus_neighbor_right = primary_btn.get_path_to(cloud_link_buttons[0])
				cloud_link_buttons[0].focus_neighbor_left = cloud_link_buttons[0].get_path_to(primary_btn)
			elif not player_buttons.is_empty():
				cloud_link_buttons[0].focus_neighbor_left = cloud_link_buttons[0].get_path_to(player_buttons[0])

			for k in range(cloud_link_buttons.size() - 1):
				cloud_link_buttons[k].focus_neighbor_right = cloud_link_buttons[k].get_path_to(cloud_link_buttons[k + 1])
				cloud_link_buttons[k + 1].focus_neighbor_left = cloud_link_buttons[k + 1].get_path_to(cloud_link_buttons[k])
				if tab_bar != null and is_instance_valid(tab_bar):
					cloud_link_buttons[k].focus_neighbor_bottom = cloud_link_buttons[k].get_path_to(tab_bar)

			if edit_profile_btn != null and is_instance_valid(edit_profile_btn):
				cloud_link_buttons.back().focus_neighbor_right = cloud_link_buttons.back().get_path_to(edit_profile_btn)
				edit_profile_btn.focus_neighbor_left = edit_profile_btn.get_path_to(cloud_link_buttons.back())
			if tab_bar != null and is_instance_valid(tab_bar):
				cloud_link_buttons.back().focus_neighbor_bottom = cloud_link_buttons.back().get_path_to(tab_bar)
		elif primary_btn != null and is_instance_valid(primary_btn) and edit_profile_btn != null and is_instance_valid(edit_profile_btn):
			var sync_primary_btn = stats_panel.find_child("SyncPrimaryBtn", true, false) as Button
			if sync_primary_btn != null and is_instance_valid(sync_primary_btn) and sync_primary_btn.is_visible_in_tree():
				primary_btn.focus_neighbor_right = primary_btn.get_path_to(sync_primary_btn)
				sync_primary_btn.focus_neighbor_left = sync_primary_btn.get_path_to(primary_btn)
				sync_primary_btn.focus_neighbor_right = sync_primary_btn.get_path_to(edit_profile_btn)
				edit_profile_btn.focus_neighbor_left = edit_profile_btn.get_path_to(sync_primary_btn)
				if tab_bar != null and is_instance_valid(tab_bar):
					sync_primary_btn.focus_neighbor_bottom = sync_primary_btn.get_path_to(tab_bar)
			else:
				primary_btn.focus_neighbor_right = primary_btn.get_path_to(edit_profile_btn)
				edit_profile_btn.focus_neighbor_left = edit_profile_btn.get_path_to(primary_btn)

		if edit_profile_btn != null and is_instance_valid(edit_profile_btn):
			if (primary_btn == null or not is_instance_valid(primary_btn)) and cloud_link_buttons.is_empty():
				if not player_buttons.is_empty():
					edit_profile_btn.focus_neighbor_left = edit_profile_btn.get_path_to(player_buttons[0])
			if tab_bar != null and is_instance_valid(tab_bar):
				edit_profile_btn.focus_neighbor_bottom = edit_profile_btn.get_path_to(tab_bar)
				if primary_btn == null or not is_instance_valid(primary_btn):
					tab_bar.focus_neighbor_top = tab_bar.get_path_to(edit_profile_btn)
				if not player_buttons.is_empty():
					tab_bar.focus_neighbor_left = tab_bar.get_path_to(player_buttons[0])

		if email_report_btn != null and is_instance_valid(email_report_btn) and delete_btn != null and is_instance_valid(delete_btn):
			email_report_btn.focus_neighbor_right = email_report_btn.get_path_to(clear_btn if clear_btn != null else delete_btn)
			if clear_btn != null and is_instance_valid(clear_btn):
				clear_btn.focus_neighbor_left = clear_btn.get_path_to(email_report_btn)
				clear_btn.focus_neighbor_right = clear_btn.get_path_to(delete_btn)
				delete_btn.focus_neighbor_left = delete_btn.get_path_to(clear_btn)
			else:
				delete_btn.focus_neighbor_left = delete_btn.get_path_to(email_report_btn)
			delete_btn.focus_neighbor_bottom = delete_btn.get_path_to(back_btn)


func _setup_cloud_account_bar(parent: Container) -> void:
	cloud_bar_container = VBoxContainer.new()
	cloud_bar_container.name = "CloudAccountBarContainer"
	cloud_bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cloud_bar_container.add_theme_constant_override("separation", 4)
	parent.add_child(cloud_bar_container)

	# Budget paused banner (hidden unless paused, 0px height when hidden)
	budget_paused_banner = BudgetPausedBanner.new()
	budget_paused_banner.name = "BudgetPausedBanner"
	cloud_bar_container.add_child(budget_paused_banner)

	# Bar panel container
	var panel = PanelContainer.new()
	panel.name = "CloudBarPanel"
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.08, 0.14, 0.10, 0.90)
	panel_sb.border_color = Color(0.25, 0.45, 0.30, 0.8)
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(6)
	panel_sb.content_margin_left = 12.0
	panel_sb.content_margin_right = 12.0
	panel_sb.content_margin_top = 5.0
	panel_sb.content_margin_bottom = 5.0
	panel.add_theme_stylebox_override("panel", panel_sb)
	cloud_bar_container.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.name = "CloudBarHBox"
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	cloud_status_label = Label.new()
	cloud_status_label.name = "CloudStatusLabel"
	cloud_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cloud_status_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(cloud_status_label)

	cloud_sign_in_btn = Button.new()
	cloud_sign_in_btn.name = "CloudSignInBtn"
	cloud_sign_in_btn.text = "☁ Sign In to Sync Stats"
	cloud_sign_in_btn.custom_minimum_size = Vector2(195, 38)
	cloud_sign_in_btn.focus_mode = Control.FOCUS_ALL
	ThemeManager.apply_primary_button_style(cloud_sign_in_btn, 4)
	cloud_sign_in_btn.pressed.connect(_open_account_modal)
	hbox.add_child(cloud_sign_in_btn)

	cloud_sync_now_btn = Button.new()
	cloud_sync_now_btn.name = "CloudSyncNowBtn"
	cloud_sync_now_btn.text = "🔄 Sync Now"
	cloud_sync_now_btn.custom_minimum_size = Vector2(120, 38)
	cloud_sync_now_btn.focus_mode = Control.FOCUS_ALL
	ThemeManager.apply_secondary_button_style(cloud_sync_now_btn, 4)
	cloud_sync_now_btn.pressed.connect(_on_sync_now_pressed)
	hbox.add_child(cloud_sync_now_btn)

	cloud_approvals_btn = Button.new()
	cloud_approvals_btn.name = "CloudApprovalsBtn"
	cloud_approvals_btn.text = "🔑 Approvals & Shared Access"
	cloud_approvals_btn.custom_minimum_size = Vector2(210, 38)
	cloud_approvals_btn.focus_mode = Control.FOCUS_ALL
	ThemeManager.apply_nav_button_style(cloud_approvals_btn)
	cloud_approvals_btn.pressed.connect(_open_approvals_modal)
	hbox.add_child(cloud_approvals_btn)

	cloud_account_btn = Button.new()
	cloud_account_btn.name = "CloudAccountBtn"
	cloud_account_btn.text = "⚙️ Account"
	cloud_account_btn.custom_minimum_size = Vector2(105, 38)
	cloud_account_btn.focus_mode = Control.FOCUS_ALL
	ThemeManager.apply_nav_button_style(cloud_account_btn)
	cloud_account_btn.pressed.connect(_open_account_modal)
	hbox.add_child(cloud_account_btn)

	_update_cloud_account_bar()

	if has_node("/root/CloudAuth"):
		var auth = get_node("/root/CloudAuth")
		if auth.has_signal("auth_state_changed") and not auth.auth_state_changed.is_connected(_on_cloud_auth_state_changed):
			auth.auth_state_changed.connect(_on_cloud_auth_state_changed)
	if has_node("/root/CloudSync"):
		var cs = get_node("/root/CloudSync")
		if cs.has_signal("sync_started") and not cs.sync_started.is_connected(_on_cloud_sync_started):
			cs.sync_started.connect(_on_cloud_sync_started)
		if cs.has_signal("sync_completed") and not cs.sync_completed.is_connected(_on_cloud_sync_completed):
			cs.sync_completed.connect(_on_cloud_sync_completed)
		if cs.has_signal("sync_throttled") and not cs.sync_throttled.is_connected(_on_cloud_sync_throttled):
			cs.sync_throttled.connect(_on_cloud_sync_throttled)


func _on_cloud_auth_state_changed(_signed_in, _user) -> void:
	if not is_inside_tree():
		return
	_update_cloud_account_bar()
	_check_first_signin_primary_link()
	_refresh_players_list()
	if not selected_player_name.is_empty():
		_render_player_profile(selected_player_name)


func _on_cloud_sync_started() -> void:
	if not is_inside_tree():
		return
	_update_sync_buttons_state()


func _on_cloud_sync_completed(_ok, _synced) -> void:
	if not is_inside_tree():
		return
	_update_sync_buttons_state()
	_update_cloud_account_bar()
	_refresh_players_list()
	if selected_player_name.is_empty():
		var primary_name := MultiplayerManager.get_primary_player_name()
		if not primary_name.is_empty():
			selected_player_name = primary_name
	if not selected_player_name.is_empty():
		_render_player_profile(selected_player_name)


func _on_cloud_sync_throttled(_rem) -> void:
	if not is_inside_tree():
		return
	_update_sync_buttons_state()


func _process(_delta: float) -> void:
	_update_sync_buttons_state()


func _update_sync_buttons_state() -> void:
	if not is_inside_tree():
		return
	var cs = get_node_or_null("/root/CloudSync")
	if cs == null:
		return

	var is_syncing: bool = bool(cs.get("_is_syncing"))
	var rem: float = cs.get_manual_sync_cooldown_remaining() if cs.has_method("get_manual_sync_cooldown_remaining") else 0.0

	# 1. Main header CloudSyncNowBtn
	if is_instance_valid(cloud_sync_now_btn) and cloud_sync_now_btn.is_visible_in_tree():
		if is_syncing:
			if cloud_sync_now_btn.text != "⏳ Syncing...":
				cloud_sync_now_btn.text = "⏳ Syncing..."
			cloud_sync_now_btn.disabled = true
			cloud_sync_now_btn.tooltip_text = "Syncing in progress..."
		elif rem > 0.0:
			var sec: int = int(ceil(rem))
			var cd_text := "⏳ Sync (%ds)" % sec
			if cloud_sync_now_btn.text != cd_text:
				cloud_sync_now_btn.text = cd_text
			cloud_sync_now_btn.disabled = true
			cloud_sync_now_btn.tooltip_text = "Sync cooldown active (%ds remaining) to preserve cloud limits." % sec
		else:
			if cloud_sync_now_btn.text != "🔄 Sync Now":
				cloud_sync_now_btn.text = "🔄 Sync Now"
			cloud_sync_now_btn.disabled = false
			cloud_sync_now_btn.tooltip_text = "Sync your player profiles and matches to the cloud."

	# 2. Stats panel Primary and Linked sync buttons if active
	if is_instance_valid(stats_panel) and stats_panel.is_visible_in_tree():
		var primary_sync = stats_panel.find_child("SyncPrimaryBtn", true, false) as Button
		if primary_sync != null and is_instance_valid(primary_sync) and primary_sync.is_visible_in_tree():
			if is_syncing:
				if primary_sync.text != "⏳...":
					primary_sync.text = "⏳..."
				primary_sync.disabled = true
			elif rem > 0.0:
				var sec_p: int = int(ceil(rem))
				var p_txt := "⏳ (%ds)" % sec_p
				if primary_sync.text != p_txt:
					primary_sync.text = p_txt
				primary_sync.disabled = true
				primary_sync.tooltip_text = "Sync cooldown active (%ds remaining) to preserve cloud limits." % sec_p
			else:
				if primary_sync.text != "🔄 Sync Now":
					primary_sync.text = "🔄 Sync Now"
				primary_sync.disabled = false
				primary_sync.tooltip_text = "Sync this primary profile to the cloud."

		var linked_sync = stats_panel.find_child("SyncLinkedBtn", true, false) as Button
		if linked_sync != null and is_instance_valid(linked_sync) and linked_sync.is_visible_in_tree():
			if is_syncing:
				if linked_sync.text != "⏳...":
					linked_sync.text = "⏳..."
				linked_sync.disabled = true
			elif rem > 0.0:
				var sec_l: int = int(ceil(rem))
				var l_txt := "⏳ (%ds)" % sec_l
				if linked_sync.text != l_txt:
					linked_sync.text = l_txt
				linked_sync.disabled = true
				linked_sync.tooltip_text = "Sync cooldown active (%ds remaining) to preserve cloud limits." % sec_l
			else:
				if linked_sync.text != "🔄 Sync Now":
					linked_sync.text = "🔄 Sync Now"
				linked_sync.disabled = false
				linked_sync.tooltip_text = "Sync this linked profile to the cloud."


func _update_cloud_account_bar() -> void:
	if not is_instance_valid(cloud_status_label):
		return
	var auth = get_node_or_null("/root/CloudAuth")
	var signed_in = (auth != null and auth.has_method("is_signed_in") and auth.is_signed_in())

	if signed_in:
		var email_text = auth.get_email()
		if email_text.is_empty():
			email_text = auth.get_display_name()
		if email_text.is_empty():
			email_text = auth.get_uid()
		cloud_status_label.text = "☁ Signed in as %s" % email_text
		cloud_status_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88))
		cloud_sign_in_btn.visible = false
		cloud_sync_now_btn.visible = true
		if is_instance_valid(cloud_approvals_btn):
			cloud_approvals_btn.visible = true
			_check_incoming_requests_notification_dot()
		cloud_account_btn.visible = true
	else:
		cloud_status_label.text = "☁ Cloud Sync: Not Signed In"
		cloud_status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		cloud_sign_in_btn.visible = true
		cloud_sync_now_btn.visible = false
		if is_instance_valid(cloud_approvals_btn):
			cloud_approvals_btn.visible = false
		cloud_account_btn.visible = false

	call_deferred("_update_controller_focus_navigation")


func _check_incoming_requests_notification_dot() -> void:
	if not is_instance_valid(cloud_approvals_btn):
		return
	var link_svc = LinkServiceClass.new()
	var reqs: Array[Dictionary] = await link_svc.fetch_incoming_link_requests()
	var pending_count := 0
	for r in reqs:
		if str(r.get("status", "pending")) == "pending":
			pending_count += 1
	if is_instance_valid(cloud_approvals_btn):
		if pending_count > 0:
			cloud_approvals_btn.text = "🔑 Approvals (● %d)" % pending_count
		else:
			cloud_approvals_btn.text = "🔑 Approvals & Shared Access"


func _open_approvals_modal() -> void:
	var existing = get_node_or_null("ApprovalsModal")
	if existing != null:
		existing.queue_free()
	var modal = ApprovalsModalClass.new()
	modal.setup()
	modal.modal_closed.connect(func():
		_update_cloud_account_bar()
		if not selected_player_name.is_empty():
			_render_player_profile(selected_player_name)
		call_deferred("_update_controller_focus_navigation")
	)
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _open_link_guest_modal(p_name: String, email: String = "") -> void:
	var existing = get_node_or_null("LinkGuestModal")
	if existing != null:
		existing.queue_free()
	var modal = LinkGuestModalClass.new()
	modal.setup(p_name, email)
	modal.link_completed.connect(func(target_name, _uid):
		_render_player_profile(target_name)
		_update_cloud_account_bar()
	)
	modal.modal_closed.connect(func():
		_render_player_profile(p_name)
		call_deferred("_update_controller_focus_navigation")
	)
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _populate_cloud_link_section(cloud_link_section: HBoxContainer, reg_p: Dictionary, p_name: String, signed_in: bool) -> void:
	var role := str(reg_p.get("link_role", "none"))
	if role == "primary":
		return

	if not signed_in:
		var link_guest_btn := Button.new()
		link_guest_btn.name = "LinkGuestBtn"
		link_guest_btn.text = "🔗 Link Guest Cloud Account"
		link_guest_btn.custom_minimum_size = Vector2(230, 38)
		link_guest_btn.focus_mode = Control.FOCUS_ALL
		ThemeManager.apply_secondary_button_style(link_guest_btn, 6)
		link_guest_btn.pressed.connect(_open_account_modal)
		cloud_link_section.add_child(link_guest_btn)
		return

	match role:
		"none":
			var link_guest_btn := Button.new()
			link_guest_btn.name = "LinkGuestBtn"
			link_guest_btn.text = "🔗 Link Guest Cloud Account"
			link_guest_btn.custom_minimum_size = Vector2(230, 38)
			link_guest_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(link_guest_btn, 6)
			link_guest_btn.pressed.connect(func():
				_open_link_guest_modal(p_name, str(reg_p.get("email", "")))
			)
			cloud_link_section.add_child(link_guest_btn)

		"pending_link":
			var pending_email := str(reg_p.get("pending_target_email", reg_p.get("email", "")))
			var pending_badge := PanelContainer.new()
			pending_badge.name = "PendingLinkBadge"
			var p_style := StyleBoxFlat.new()
			p_style.bg_color = Color(0.35, 0.25, 0.05, 0.85)
			p_style.border_color = Color(0.95, 0.75, 0.2, 1.0)
			p_style.set_border_width_all(1)
			p_style.set_corner_radius_all(6)
			p_style.content_margin_left = 10
			p_style.content_margin_right = 10
			p_style.content_margin_top = 4
			p_style.content_margin_bottom = 4
			pending_badge.add_theme_stylebox_override("panel", p_style)
			var lbl := Label.new()
			lbl.text = "⏳ Cloud Link Pending (%s)" % (pending_email if not pending_email.is_empty() else "Guest")
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
			lbl.add_theme_font_size_override("font_size", 13)
			pending_badge.add_child(lbl)
			cloud_link_section.add_child(pending_badge)

			var check_btn := Button.new()
			check_btn.name = "CheckStatusBtn"
			check_btn.text = "🔍 Check Status"
			check_btn.custom_minimum_size = Vector2(130, 38)
			check_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(check_btn, 6)
			check_btn.pressed.connect(func():
				_check_single_pending_status(p_name)
			)
			cloud_link_section.add_child(check_btn)

			var cancel_btn := Button.new()
			cancel_btn.name = "CancelLinkBtn"
			cancel_btn.text = "✕ Cancel"
			cancel_btn.custom_minimum_size = Vector2(90, 38)
			cancel_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(cancel_btn, 6)
			cancel_btn.pressed.connect(func():
				var link_svc = LinkServiceClass.new()
				link_svc.unlink_secondary_profile_locally(p_name)
				_render_player_profile(p_name)
			)
			cloud_link_section.add_child(cancel_btn)

		"linked":
			var linked_email := str(reg_p.get("email", ""))
			var linked_badge := PanelContainer.new()
			linked_badge.name = "LinkedBadge"
			var l_style := StyleBoxFlat.new()
			l_style.bg_color = Color(0.1, 0.25, 0.4, 0.85)
			l_style.border_color = Color(0.3, 0.6, 0.95, 1.0)
			l_style.set_border_width_all(1)
			l_style.set_corner_radius_all(6)
			l_style.content_margin_left = 10
			l_style.content_margin_right = 10
			l_style.content_margin_top = 4
			l_style.content_margin_bottom = 4
			linked_badge.add_theme_stylebox_override("panel", l_style)
			var lbl := Label.new()
			lbl.text = "🔗 Linked Cloud Account (%s)" % (linked_email if not linked_email.is_empty() else reg_p.get("cloud_uid", ""))
			lbl.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
			lbl.add_theme_font_size_override("font_size", 13)
			linked_badge.add_child(lbl)
			cloud_link_section.add_child(linked_badge)

			var sync_btn := Button.new()
			sync_btn.name = "SyncLinkedBtn"
			sync_btn.text = "🔄 Sync Now"
			sync_btn.custom_minimum_size = Vector2(110, 38)
			sync_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(sync_btn, 6)
			sync_btn.pressed.connect(func():
				var cs = get_node_or_null("/root/CloudSync")
				if cs != null and cs.has_method("sync_single_profile"):
					if cs.has_method("can_manual_sync") and not cs.can_manual_sync():
						return
					sync_btn.text = "⏳..."
					sync_btn.disabled = true
					await cs.sync_single_profile(p_name, str(reg_p.get("cloud_uid", "")), true)
					_render_player_profile(p_name)
			)
			cloud_link_section.add_child(sync_btn)

			var unlink_btn := Button.new()
			unlink_btn.name = "UnlinkBtn"
			unlink_btn.text = "Unlink"
			unlink_btn.custom_minimum_size = Vector2(90, 38)
			unlink_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(unlink_btn, 6)
			unlink_btn.pressed.connect(func():
				var link_svc = LinkServiceClass.new()
				link_svc.unlink_secondary_profile_locally(p_name)
				_render_player_profile(p_name)
			)
			cloud_link_section.add_child(unlink_btn)

		"revoked":
			var revoked_badge := PanelContainer.new()
			revoked_badge.name = "RevokedBadge"
			var r_style := StyleBoxFlat.new()
			r_style.bg_color = Color(0.35, 0.1, 0.1, 0.85)
			r_style.border_color = Color(0.9, 0.35, 0.35, 1.0)
			r_style.set_border_width_all(1)
			r_style.set_corner_radius_all(6)
			r_style.content_margin_left = 10
			r_style.content_margin_right = 10
			r_style.content_margin_top = 4
			r_style.content_margin_bottom = 4
			revoked_badge.add_theme_stylebox_override("panel", r_style)
			var lbl := Label.new()
			lbl.text = "⚠️ Cloud Access Revoked"
			lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
			lbl.add_theme_font_size_override("font_size", 13)
			revoked_badge.add_child(lbl)
			cloud_link_section.add_child(revoked_badge)

			var relink_btn := Button.new()
			relink_btn.name = "RelinkBtn"
			relink_btn.text = "🔗 Re-link Account"
			relink_btn.custom_minimum_size = Vector2(170, 38)
			relink_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(relink_btn, 6)
			relink_btn.pressed.connect(func():
				_open_link_guest_modal(p_name, str(reg_p.get("email", "")))
			)
			cloud_link_section.add_child(relink_btn)


func _check_single_pending_status(p_name: String) -> void:
	var link_svc = LinkServiceClass.new()
	var outgoing: Array[Dictionary] = await link_svc.check_outgoing_requests()
	for doc in outgoing:
		if str(doc.get("local_player_name", "")).to_lower() == p_name.to_lower():
			var status := str(doc.get("status", "pending"))
			if status == "approved":
				_render_player_profile(p_name)
				return
	_render_player_profile(p_name)


var _pending_primary_link_player: String = ""


func _open_account_modal() -> void:
	var existing = get_node_or_null("AccountModal")
	if existing != null:
		existing.visible = true
		return
	var modal = AccountModalScene.instantiate()
	modal.name = "AccountModal"
	add_child(modal)
	var on_closed_cb = func():
		_update_cloud_account_bar()
		_refresh_players_list()
		if not selected_player_name.is_empty():
			_render_player_profile(selected_player_name)
	if modal.has_signal("modal_closed"):
		modal.modal_closed.connect(on_closed_cb)
	elif modal.has_signal("closed"):
		modal.closed.connect(on_closed_cb)


func _on_sync_now_pressed() -> void:
	if not has_node("/root/CloudSync"):
		return
	var cs = get_node("/root/CloudSync")
	if cs.has_method("can_manual_sync") and not cs.can_manual_sync():
		var rem = cs.get_manual_sync_cooldown_remaining() if cs.has_method("get_manual_sync_cooldown_remaining") else 0.0
		if rem > 0.0:
			print("[PlayersMenu] Manual sync throttled. Cooldown remaining: %.1fs" % rem)
		return
	if is_instance_valid(cloud_sync_now_btn):
		cloud_sync_now_btn.disabled = true
		cloud_sync_now_btn.text = "⏳ Syncing..."
	cs.call("sync_all_eligible_profiles", "manual")


func _show_primary_confirm_dialog(player_name: String) -> void:
	primary_confirm_dialog.title = "Set Primary Cloud Profile"
	primary_confirm_dialog.dialog_text = "Associate local profile '%s' with your signed-in cloud account and sync all of its existing local stats and matches to the cloud?\n\nOnly your Primary Profile (and approved secondary/guest accounts) are synced to Firebase." % player_name
	primary_confirm_dialog.ok_button_text = "Associate & Sync"
	primary_confirm_dialog.cancel_button_text = "Cancel"

	for conn in primary_confirm_dialog.confirmed.get_connections():
		primary_confirm_dialog.confirmed.disconnect(conn["callable"])

	primary_confirm_dialog.confirmed.connect(func():
		var auth = get_node_or_null("/root/CloudAuth")
		var uid = auth.get_uid() if (auth != null and auth.has_method("get_uid")) else ""
		MultiplayerManager.set_primary_player(player_name, uid)
		_refresh_players_list()
		_render_player_profile(player_name)
		if has_node("/root/CloudSync"):
			var cs = get_node("/root/CloudSync")
			var res = await cs.sync_single_profile(player_name, uid)
			if not res.get("ok", false):
				print("[PlayersMenu] Primary link sync failed: %s" % res.get("error", "Unknown error"))
			_render_player_profile(player_name)
	)
	primary_confirm_dialog.popup_centered()


func _show_unset_primary_confirm_dialog(player_name: String) -> void:
	primary_confirm_dialog.title = "Unset Primary Cloud Profile"
	primary_confirm_dialog.dialog_text = "Remove '%s' as your Primary Cloud Profile?\n\nThis simulator will no longer automatically sync stats or matches for this profile to the cloud." % player_name
	primary_confirm_dialog.ok_button_text = "Unset Primary"
	primary_confirm_dialog.cancel_button_text = "Keep Primary"

	for conn in primary_confirm_dialog.confirmed.get_connections():
		primary_confirm_dialog.confirmed.disconnect(conn["callable"])

	primary_confirm_dialog.confirmed.connect(func():
		MultiplayerManager.set_primary_player("", "")
		_refresh_players_list()
		_render_player_profile(player_name)
	)
	primary_confirm_dialog.popup_centered()


func _check_first_signin_primary_link() -> void:
	var auth = get_node_or_null("/root/CloudAuth")
	if auth == null or not auth.has_method("is_signed_in") or not auth.is_signed_in():
		return
	var primary_name = MultiplayerManager.get_primary_player_name()
	if not primary_name.is_empty():
		_pending_primary_link_player = ""
		return
	var reg = MultiplayerManager.get_registered_players()
	if reg.is_empty():
		if has_node("/root/CloudSync"):
			get_node("/root/CloudSync").call("sync_all_eligible_profiles", "startup")
		return
	if not _pending_primary_link_player.is_empty():
		var target_p := _pending_primary_link_player
		_pending_primary_link_player = ""
		call_deferred("_show_primary_confirm_dialog", target_p)
		return
	var email = auth.get_email().strip_edges().to_lower()
	var email_prefix = email.split("@")[0] if email.contains("@") else email
	var dname = auth.get_display_name().strip_edges().to_lower()
	var matching_player = ""
	for p in reg:
		if not email.is_empty() and str(p.get("email", "")).strip_edges().to_lower() == email:
			matching_player = str(p.get("name", ""))
			break
	if matching_player.is_empty():
		for p in reg:
			var p_lower = str(p.get("name", "")).strip_edges().to_lower()
			if not p_lower.is_empty() and (p_lower == dname or p_lower == email_prefix):
				matching_player = str(p.get("name", ""))
				break
	if matching_player.is_empty() and reg.size() == 1:
		matching_player = str(reg[0].get("name", ""))
	if not matching_player.is_empty():
		MultiplayerManager.set_primary_player(matching_player, auth.get_uid())
		if has_node("/root/CloudSync"):
			get_node("/root/CloudSync").call("sync_single_profile", matching_player, auth.get_uid())
	elif not selected_player_name.is_empty():
		call_deferred("_show_primary_confirm_dialog", selected_player_name)


func _open_create_profile_dialog() -> void:
	for child in create_profile_content.get_children():
		child.queue_free()

	var title_lbl = Label.new()
	title_lbl.text = "Create New Player Profile"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	create_profile_content.add_child(title_lbl)

	# Name Section
	var name_sec = VBoxContainer.new()
	name_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(name_sec)

	var name_title = Label.new()
	name_title.text = "Player Name:"
	name_title.add_theme_font_size_override("font_size", 14)
	name_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	name_sec.add_child(name_title)

	if new_player_input.get_parent() != null:
		new_player_input.get_parent().remove_child(new_player_input)
	name_sec.add_child(new_player_input)
	if not new_player_input.text_changed.is_connected(_on_create_profile_name_changed):
		new_player_input.text_changed.connect(_on_create_profile_name_changed)

	# Email Section
	var email_sec = VBoxContainer.new()
	email_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(email_sec)

	var email_title = Label.new()
	email_title.text = "Email Address (auto-populates when clicking email buttons):"
	email_title.add_theme_font_size_override("font_size", 14)
	email_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	email_sec.add_child(email_title)

	if not new_player_email_input.gui_input.is_connected(_on_new_player_email_gui_input):
		new_player_email_input.gui_input.connect(_on_new_player_email_gui_input)
	if new_player_email_input.get_parent() != null:
		new_player_email_input.get_parent().remove_child(new_player_email_input)
	email_sec.add_child(new_player_email_input)

	# Avatar Section
	var av_sec = VBoxContainer.new()
	av_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(av_sec)

	var av_title = Label.new()
	av_title.text = "In-Game Avatar (replaces colored letter circle):"
	av_title.add_theme_font_size_override("font_size", 15)
	av_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	av_sec.add_child(av_title)

	var av_hbox = HBoxContainer.new()
	av_hbox.add_theme_constant_override("separation", 14)
	av_sec.add_child(av_hbox)

	create_profile_avatar_preview_container = HBoxContainer.new()
	create_profile_avatar_preview_container.add_theme_constant_override("separation", 10)
	av_hbox.add_child(create_profile_avatar_preview_container)
	_update_create_profile_avatar_ui()

	var change_av_btn = Button.new()
	change_av_btn.text = "Select Avatar..."
	change_av_btn.custom_minimum_size = Vector2(160, 50)
	change_av_btn.add_theme_font_size_override("font_size", 17)
	ThemeManager.apply_primary_button_style(change_av_btn)
	change_av_btn.pressed.connect(func():
		_open_avatar_picker(new_player_avatar_path, func(chosen):
			new_player_avatar_path = chosen
			_update_create_profile_avatar_ui()
		)
	)
	av_hbox.add_child(change_av_btn)

	var remove_av_btn = Button.new()
	remove_av_btn.text = "Remove Avatar"
	remove_av_btn.custom_minimum_size = Vector2(150, 50)
	remove_av_btn.add_theme_font_size_override("font_size", 17)
	ThemeManager.apply_secondary_button_style(remove_av_btn)
	remove_av_btn.pressed.connect(func():
		new_player_avatar_path = ""
		_update_create_profile_avatar_ui()
	)
	av_hbox.add_child(remove_av_btn)

	# Preferred Tee Section
	var tee_sec = VBoxContainer.new()
	tee_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(tee_sec)

	var tee_title = Label.new()
	tee_title.text = "Preferred Tee Box (auto-selected during match setup):"
	tee_title.add_theme_font_size_override("font_size", 15)
	tee_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	tee_sec.add_child(tee_title)

	if new_player_tee_opt.get_parent() != null:
		new_player_tee_opt.get_parent().remove_child(new_player_tee_opt)
	tee_sec.add_child(new_player_tee_opt)

	# Skill Level Section
	var skill_sec = VBoxContainer.new()
	skill_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(skill_sec)

	var skill_title = Label.new()
	skill_title.text = "Player Skill Level:"
	skill_title.add_theme_font_size_override("font_size", 15)
	skill_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	skill_sec.add_child(skill_title)

	var skill_hint = Label.new()
	skill_hint.text = "ℹ️ Tailors your shot recommendations, launch benchmarks, and flaw analysis."
	skill_hint.add_theme_font_size_override("font_size", 13)
	skill_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	skill_sec.add_child(skill_hint)

	if new_player_skill_opt.get_parent() != null:
		new_player_skill_opt.get_parent().remove_child(new_player_skill_opt)
	skill_sec.add_child(new_player_skill_opt)

	# Dexterity / Handedness Section
	var hand_sec = VBoxContainer.new()
	hand_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(hand_sec)

	var hand_title = Label.new()
	hand_title.text = "Player Dexterity / Handedness:"
	hand_title.add_theme_font_size_override("font_size", 15)
	hand_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hand_sec.add_child(hand_title)

	var hand_hint = Label.new()
	hand_hint.text = "ℹ️ Configures launch monitors requiring handedness tracking (e.g. Square Golf)."
	hand_hint.add_theme_font_size_override("font_size", 13)
	hand_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	hand_sec.add_child(hand_hint)

	if new_player_handedness_opt.get_parent() != null:
		new_player_handedness_opt.get_parent().remove_child(new_player_handedness_opt)
	hand_sec.add_child(new_player_handedness_opt)

	# Golf Ball Graphic Section
	var ball_sec = VBoxContainer.new()
	ball_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(ball_sec)

	var ball_title = Label.new()
	ball_title.text = "Golf Ball Graphics & Alignment Marker:"
	ball_title.add_theme_font_size_override("font_size", 15)
	ball_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ball_sec.add_child(ball_title)

	var ball_hint = Label.new()
	ball_hint.text = "ℹ️ Ball is always positioned in a canonical orientation with an alignment arrow directed at the hole."
	ball_hint.add_theme_font_size_override("font_size", 13)
	ball_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	ball_sec.add_child(ball_hint)

	var ball_hbox = HBoxContainer.new()
	ball_hbox.add_theme_constant_override("separation", 14)
	ball_sec.add_child(ball_hbox)

	create_profile_ball_preview_container = HBoxContainer.new()
	create_profile_ball_preview_container.add_theme_constant_override("separation", 10)
	ball_hbox.add_child(create_profile_ball_preview_container)

	if new_player_ball_opt.get_parent() != null:
		new_player_ball_opt.get_parent().remove_child(new_player_ball_opt)
	new_player_ball_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not new_player_ball_opt.item_selected.is_connected(_on_create_profile_ball_item_selected):
		new_player_ball_opt.item_selected.connect(_on_create_profile_ball_item_selected)
	ball_hbox.add_child(new_player_ball_opt)

	var match_icon_btn = Button.new()
	match_icon_btn.text = "Match Player Icon"
	match_icon_btn.custom_minimum_size = Vector2(170, 50)
	match_icon_btn.add_theme_font_size_override("font_size", 15)
	ThemeManager.apply_secondary_button_style(match_icon_btn, 6)
	match_icon_btn.pressed.connect(func():
		new_player_ball_opt.selected = _ball_graphic_id_to_index("player_icon")
		_update_create_profile_ball_ui()
	)
	ball_hbox.add_child(match_icon_btn)

	_update_create_profile_ball_ui()

	# Golf Ball Type (Physics) Section
	var ball_type_sec = VBoxContainer.new()
	ball_type_sec.add_theme_constant_override("separation", 6)
	create_profile_content.add_child(ball_type_sec)

	var ball_type_title = Label.new()
	ball_type_title.text = "Golf Ball Type (Physics):"
	ball_type_title.add_theme_font_size_override("font_size", 15)
	ball_type_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ball_type_sec.add_child(ball_type_title)

	var ball_type_hint = Label.new()
	ball_type_hint.text = "ℹ️ Standard uses default physics; Soft adds spin with less rollout; Distance adds speed and rollout with less spin."
	ball_type_hint.add_theme_font_size_override("font_size", 13)
	ball_type_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	ball_type_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ball_type_sec.add_child(ball_type_hint)

	if new_player_ball_type_opt.get_parent() != null:
		new_player_ball_type_opt.get_parent().remove_child(new_player_ball_type_opt)
	ball_type_sec.add_child(new_player_ball_type_opt)

	create_profile_dialog.popup_centered()
	new_player_input.call_deferred("grab_focus")


func _update_create_profile_avatar_ui() -> void:
	if create_profile_avatar_preview_container == null:
		return
	for child in create_profile_avatar_preview_container.get_children():
		child.queue_free()

	if not new_player_avatar_path.is_empty() and ResourceLoader.exists(new_player_avatar_path):
		var trect = TextureRect.new()
		trect.texture = load(new_player_avatar_path)
		trect.custom_minimum_size = Vector2(48, 48)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		create_profile_avatar_preview_container.add_child(trect)

		var av_name = "Custom Avatar"
		for av in MultiplayerManager.AVAILABLE_AVATARS:
			if av["path"] == new_player_avatar_path:
				av_name = av["name"]
				break
		var name_l = Label.new()
		name_l.text = av_name
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		create_profile_avatar_preview_container.add_child(name_l)
	else:
		var circ = PanelContainer.new()
		circ.custom_minimum_size = Vector2(48, 48)
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.24, 0.46, 0.72)
		cs.corner_radius_top_left = 24
		cs.corner_radius_top_right = 24
		cs.corner_radius_bottom_left = 24
		cs.corner_radius_bottom_right = 24
		circ.add_theme_stylebox_override("panel", cs)
		var clbl = Label.new()
		var p_initial = new_player_input.text.strip_edges().substr(0, 1).to_upper()
		clbl.text = p_initial if not p_initial.is_empty() else "?"
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clbl.add_theme_font_size_override("font_size", 22)
		circ.add_child(clbl)
		create_profile_avatar_preview_container.add_child(circ)

		var name_l = Label.new()
		name_l.text = "None (Default Initial)"
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		create_profile_avatar_preview_container.add_child(name_l)

	_update_create_profile_ball_ui()


func _update_create_profile_ball_ui() -> void:
	if create_profile_ball_preview_container == null:
		return
	for child in create_profile_ball_preview_container.get_children():
		child.queue_free()

	var bg_id = _ball_graphic_index_to_id(new_player_ball_opt.selected) if new_player_ball_opt != null else "single_line"
	var preview = _create_ball_preview_icon(bg_id, new_player_avatar_path, new_player_input.text.strip_edges(), Vector2(48, 48))
	create_profile_ball_preview_container.add_child(preview)


func _on_create_profile_name_changed(_new_text: String) -> void:
	if new_player_avatar_path.is_empty():
		_update_create_profile_avatar_ui()
	else:
		_update_create_profile_ball_ui()


func _on_create_profile_ball_item_selected(_idx: int) -> void:
	_update_create_profile_ball_ui()


func _on_new_player_email_gui_input(ev: InputEvent) -> void:
	if has_node("/root/VirtualKeyboardManager"):
		var vkm = get_node("/root/VirtualKeyboardManager")
		if vkm.is_controller_mode_active():
			if (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_A) or ev.is_action_pressed("ui_accept"):
				vkm.open_for(new_player_email_input, true)
				get_viewport().set_input_as_handled()


func _select_player(player_name: String) -> void:
	selected_player_name = player_name
	_refresh_players_list()
	_render_player_profile(player_name)

func _on_register_pressed() -> void:
	var name_text = new_player_input.text.strip_edges()
	if name_text.is_empty():
		alert_dialog.dialog_text = "Please enter a valid player name."
		alert_dialog.popup_centered()
		return
		
	var registered = MultiplayerManager.get_registered_players()
	for p in registered:
		if p.get("name", "").to_lower() == name_text.to_lower():
			alert_dialog.dialog_text = "A player with this name already exists."
			alert_dialog.popup_centered()
			return
			
	var email_text = new_player_email_input.text.strip_edges()
	var pref_tee = ""
	if new_player_tee_opt != null and new_player_tee_opt.selected > 0:
		var raw_t = new_player_tee_opt.get_item_text(new_player_tee_opt.selected)
		pref_tee = raw_t.replace("Preferred Tee: ", "").strip_edges()
	var skill_level = _skill_index_to_key(new_player_skill_opt.selected)
	var handedness = new_player_handedness_opt.selected if new_player_handedness_opt != null else 0
	var ball_graphic = _ball_graphic_index_to_id(new_player_ball_opt.selected) if new_player_ball_opt != null else "single_line"
	var ball_type = _ball_type_index_to_id(new_player_ball_type_opt.selected) if new_player_ball_type_opt != null else "standard"
	MultiplayerManager.register_player(name_text, email_text, new_player_avatar_path, [], pref_tee, skill_level, handedness, ball_graphic, ball_type)
	if create_profile_dialog != null and create_profile_dialog.visible:
		create_profile_dialog.hide()
	new_player_input.clear()
	new_player_email_input.clear()
	new_player_avatar_path = ""
	new_player_tee_opt.selected = 0
	new_player_skill_opt.selected = 0
	if new_player_handedness_opt != null:
		new_player_handedness_opt.selected = 0
	if new_player_ball_opt != null:
		new_player_ball_opt.selected = 0
	if new_player_ball_type_opt != null:
		new_player_ball_type_opt.selected = 0
	_update_new_player_avatar_preview()
	_update_new_player_ball_preview()
	_update_create_profile_avatar_ui()
	_update_create_profile_ball_ui()
	_select_player(name_text)

func _update_new_player_avatar_preview() -> void:
	if new_player_avatar_path.is_empty():
		avatar_preview_btn.text = "Avatar: None"
		avatar_preview_btn.icon = null
	else:
		var name_str = ""
		for av in MultiplayerManager.AVAILABLE_AVATARS:
			if av["path"] == new_player_avatar_path:
				name_str = av["name"]
				break
		avatar_preview_btn.text = "Avatar: " + name_str
		if ResourceLoader.exists(new_player_avatar_path):
			avatar_preview_btn.icon = load(new_player_avatar_path)
			avatar_preview_btn.expand_icon = true
	_update_new_player_ball_preview()

func _update_new_player_ball_preview() -> void:
	if new_player_ball_preview_container == null:
		return
	for child in new_player_ball_preview_container.get_children():
		child.queue_free()
	var bg_id = _ball_graphic_index_to_id(new_player_ball_opt.selected) if new_player_ball_opt != null else "single_line"
	var preview = _create_ball_preview_icon(bg_id, new_player_avatar_path, new_player_input.text.strip_edges(), Vector2(48, 48))
	new_player_ball_preview_container.add_child(preview)

func _open_avatar_picker(current_path: String, callback: Callable) -> void:
	avatar_picker_callback = callback
	avatar_picker_selected_path = current_path
	_build_avatar_picker_ui()
	avatar_picker_dialog.popup_centered()
	# Grab initial focus on the currently selected avatar or first avatar option
	var focused_btn := false
	for entry in avatar_picker_buttons:
		if entry["path"] == avatar_picker_selected_path:
			var btn = entry["btn"] as Button
			if btn != null and is_instance_valid(btn):
				btn.call_deferred("grab_focus")
				focused_btn = true
				break
	if not focused_btn and avatar_picker_buttons.size() > 0:
		var first_btn = avatar_picker_buttons[0]["btn"] as Button
		if first_btn != null and is_instance_valid(first_btn):
			first_btn.call_deferred("grab_focus")

func _on_avatar_picker_confirmed() -> void:
	if avatar_picker_callback.is_valid():
		avatar_picker_callback.call(avatar_picker_selected_path)

func _build_avatar_picker_ui() -> void:
	for child in avatar_picker_content.get_children():
		child.queue_free()
	avatar_picker_buttons.clear()

	var desc_lbl = Label.new()
	desc_lbl.text = "Select an avatar to display in-game instead of your colored initial circle:"
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	avatar_picker_content.add_child(desc_lbl)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar_picker_content.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# Option 0: No avatar / default initials
	var none_btn = _create_avatar_picker_option("", "Default Initial", null)
	grid.add_child(none_btn)

	# Options 1-10
	for av in MultiplayerManager.AVAILABLE_AVATARS:
		var tex: Texture2D = null
		if ResourceLoader.exists(av["path"]):
			tex = load(av["path"])
		var av_btn = _create_avatar_picker_option(av["path"], av["name"], tex)
		grid.add_child(av_btn)

	_update_avatar_picker_highlights()

	# Connect bottom row to OK button and OK/Cancel to avatar buttons
	var ok_btn = avatar_picker_dialog.get_ok_button()
	var cancel_btn = avatar_picker_dialog.get_cancel_button()
	if ok_btn != null and cancel_btn != null and not avatar_picker_buttons.is_empty():
		var last_btn = avatar_picker_buttons.back()["btn"] as Button
		ok_btn.focus_neighbor_top = ok_btn.get_path_to(last_btn)
		cancel_btn.focus_neighbor_top = cancel_btn.get_path_to(last_btn)
		var count = avatar_picker_buttons.size()
		for i in range(maxi(0, count - 3), count):
			var b = avatar_picker_buttons[i]["btn"] as Button
			b.focus_neighbor_bottom = b.get_path_to(ok_btn)

func _create_avatar_picker_option(path: String, title: String, tex: Texture2D) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(165, 95)
	btn.focus_mode = Control.FOCUS_ALL
	
	var vb = VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	btn.add_child(vb)

	if tex != null:
		var trect = TextureRect.new()
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trect.texture = tex
		trect.custom_minimum_size = Vector2(46, 46)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(trect)
	else:
		var circ = PanelContainer.new()
		circ.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circ.custom_minimum_size = Vector2(44, 44)
		circ.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.24, 0.46, 0.72)
		cs.corner_radius_top_left = 22
		cs.corner_radius_top_right = 22
		cs.corner_radius_bottom_left = 22
		cs.corner_radius_bottom_right = 22
		circ.add_theme_stylebox_override("panel", cs)
		var clbl = Label.new()
		clbl.text = "ABC"
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clbl.add_theme_font_size_override("font_size", 14)
		circ.add_child(clbl)
		vb.add_child(circ)

	var lbl = Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(lbl)

	btn.pressed.connect(func():
		avatar_picker_selected_path = path
		_update_avatar_picker_highlights()
	)

	avatar_picker_buttons.append({"btn": btn, "path": path})
	return btn

func _update_avatar_picker_highlights() -> void:
	for entry in avatar_picker_buttons:
		var btn = entry["btn"] as Button
		var path = entry["path"] as String
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		if path == avatar_picker_selected_path:
			style.bg_color = Color(0.18, 0.35, 0.25, 0.9)
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.85, 0.75, 0.2)
		else:
			style.bg_color = Color(0.12, 0.16, 0.2, 0.6)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.25, 0.35, 0.45, 0.5)
		btn.add_theme_stylebox_override("normal", style)
		var style_hover = style.duplicate()
		style_hover.bg_color = style.bg_color.lightened(0.1)
		btn.add_theme_stylebox_override("hover", style_hover)
		var style_focus = style.duplicate()
		style_focus.border_color = Color(0.4, 0.85, 1.0)
		style_focus.border_width_left = 3
		style_focus.border_width_right = 3
		style_focus.border_width_top = 3
		style_focus.border_width_bottom = 3
		btn.add_theme_stylebox_override("focus", style_focus)

func _open_edit_profile_dialog(player_name: String) -> void:
	edit_profile_player_name = player_name
	var reg = MultiplayerManager.get_registered_player(player_name)
	edit_profile_email_input.text = reg.get("email", "")
	edit_profile_avatar_path = reg.get("avatar", "")
	
	for child in edit_profile_content.get_children():
		child.queue_free()
		
	var title_lbl = Label.new()
	title_lbl.text = "Profile Settings for " + player_name
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	edit_profile_content.add_child(title_lbl)
	
	# Email section
	var email_sec = VBoxContainer.new()
	email_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(email_sec)
	
	var email_title = Label.new()
	email_title.text = "Email Address (auto-populates when clicking email buttons):"
	email_title.add_theme_font_size_override("font_size", 14)
	email_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	email_sec.add_child(email_title)
	
	edit_profile_email_input.name = "EditProfileEmailInput"
	edit_profile_email_input.placeholder_text = "e.g. golfer@example.com"
	edit_profile_email_input.custom_minimum_size = Vector2(0, 50)
	edit_profile_email_input.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_input_style(edit_profile_email_input)
	if not edit_profile_email_input.gui_input.is_connected(_on_edit_profile_email_gui_input):
		edit_profile_email_input.gui_input.connect(_on_edit_profile_email_gui_input)
	if edit_profile_email_input.get_parent() != null:
		edit_profile_email_input.get_parent().remove_child(edit_profile_email_input)
	email_sec.add_child(edit_profile_email_input)
	
	# Avatar section
	var av_sec = VBoxContainer.new()
	av_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(av_sec)
	
	var av_title = Label.new()
	av_title.text = "In-Game Avatar (replaces colored letter circle):"
	av_title.add_theme_font_size_override("font_size", 15)
	av_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	av_sec.add_child(av_title)
	
	var av_hbox = HBoxContainer.new()
	av_hbox.add_theme_constant_override("separation", 14)
	av_sec.add_child(av_hbox)
	
	edit_profile_avatar_preview_container = HBoxContainer.new()
	edit_profile_avatar_preview_container.add_theme_constant_override("separation", 10)
	av_hbox.add_child(edit_profile_avatar_preview_container)
	_update_edit_profile_avatar_ui()
	
	var change_av_btn = Button.new()
	change_av_btn.text = "Select Avatar..."
	change_av_btn.custom_minimum_size = Vector2(160, 50)
	change_av_btn.add_theme_font_size_override("font_size", 17)
	ThemeManager.apply_primary_button_style(change_av_btn)
	change_av_btn.pressed.connect(func():
		_open_avatar_picker(edit_profile_avatar_path, func(chosen):
			edit_profile_avatar_path = chosen
			_update_edit_profile_avatar_ui()
		)
	)
	av_hbox.add_child(change_av_btn)
	
	var remove_av_btn = Button.new()
	remove_av_btn.text = "Remove Avatar"
	remove_av_btn.custom_minimum_size = Vector2(150, 50)
	remove_av_btn.add_theme_font_size_override("font_size", 17)
	ThemeManager.apply_secondary_button_style(remove_av_btn)
	remove_av_btn.pressed.connect(func():
		edit_profile_avatar_path = ""
		_update_edit_profile_avatar_ui()
	)
	av_hbox.add_child(remove_av_btn)
	
	# Preferred Tee Section
	var tee_sec = VBoxContainer.new()
	tee_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(tee_sec)
	
	var tee_title = Label.new()
	tee_title.text = "Preferred Tee Box (auto-selected during match setup):"
	tee_title.add_theme_font_size_override("font_size", 15)
	tee_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	tee_sec.add_child(tee_title)

	edit_profile_tee_opt = OptionButton.new()
	edit_profile_tee_opt.add_item("None (Default)", 0)
	edit_profile_tee_opt.add_item("Blue", 1)
	edit_profile_tee_opt.add_item("Red", 2)
	edit_profile_tee_opt.add_item("White", 3)
	edit_profile_tee_opt.add_item("Black", 4)
	edit_profile_tee_opt.add_item("Gold", 5)
	edit_profile_tee_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(edit_profile_tee_opt, 18, Vector2(0, 50))
	edit_profile_tee_opt.selected = 0
	var cur_pref_tee = reg.get("preferred_tee", "")
	for i in range(1, edit_profile_tee_opt.item_count):
		if edit_profile_tee_opt.get_item_text(i).to_lower() == cur_pref_tee.to_lower():
			edit_profile_tee_opt.selected = i
	tee_sec.add_child(edit_profile_tee_opt)

	# Skill Level Section
	var skill_sec = VBoxContainer.new()
	skill_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(skill_sec)
	
	var skill_title = Label.new()
	skill_title.text = "Player Skill Level:"
	skill_title.add_theme_font_size_override("font_size", 15)
	skill_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	skill_sec.add_child(skill_title)

	var skill_hint = Label.new()
	skill_hint.text = "ℹ️ Tailors your shot recommendations, launch benchmarks, and flaw analysis."
	skill_hint.add_theme_font_size_override("font_size", 13)
	skill_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	skill_sec.add_child(skill_hint)

	edit_profile_skill_opt = OptionButton.new()
	edit_profile_skill_opt.add_item("Mid Handicap (10–19 HCP)", 0)
	edit_profile_skill_opt.add_item("Scratch / Low Handicap (0–9 HCP)", 1)
	edit_profile_skill_opt.add_item("High Handicap (20+ HCP)", 2)
	edit_profile_skill_opt.add_item("Tour Professional (+ HCP)", 3)
	edit_profile_skill_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(edit_profile_skill_opt, 18, Vector2(0, 50))
	var cur_skill = reg.get("skill_level", "mid_handicap")
	edit_profile_skill_opt.selected = _skill_key_to_index(cur_skill)
	skill_sec.add_child(edit_profile_skill_opt)

	# Dexterity / Handedness Section
	var hand_sec = VBoxContainer.new()
	hand_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(hand_sec)

	var hand_title = Label.new()
	hand_title.text = "Player Dexterity / Handedness:"
	hand_title.add_theme_font_size_override("font_size", 15)
	hand_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hand_sec.add_child(hand_title)

	var hand_hint = Label.new()
	hand_hint.text = "ℹ️ Configures launch monitors requiring handedness tracking (e.g. Square Golf)."
	hand_hint.add_theme_font_size_override("font_size", 13)
	hand_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	hand_sec.add_child(hand_hint)

	edit_profile_handedness_opt = OptionButton.new()
	edit_profile_handedness_opt.add_item("Right-Handed", 0)
	edit_profile_handedness_opt.add_item("Left-Handed", 1)
	edit_profile_handedness_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(edit_profile_handedness_opt, 18, Vector2(0, 50))
	var cur_hand = int(reg.get("handedness", 0))
	edit_profile_handedness_opt.selected = cur_hand
	hand_sec.add_child(edit_profile_handedness_opt)

	# Golf Ball Graphic Section
	var ball_sec = VBoxContainer.new()
	ball_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(ball_sec)

	var ball_title = Label.new()
	ball_title.text = "Golf Ball Graphics & Alignment Marker:"
	ball_title.add_theme_font_size_override("font_size", 15)
	ball_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ball_sec.add_child(ball_title)

	var ball_hint = Label.new()
	ball_hint.text = "ℹ️ Ball is always positioned in a canonical orientation with an alignment arrow directed at the hole."
	ball_hint.add_theme_font_size_override("font_size", 13)
	ball_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	ball_sec.add_child(ball_hint)

	var ball_hbox = HBoxContainer.new()
	ball_hbox.add_theme_constant_override("separation", 14)
	ball_sec.add_child(ball_hbox)

	edit_profile_ball_preview_container = HBoxContainer.new()
	edit_profile_ball_preview_container.add_theme_constant_override("separation", 10)
	ball_hbox.add_child(edit_profile_ball_preview_container)

	edit_profile_ball_opt = OptionButton.new()
	edit_profile_ball_opt.clear()
	for bg in MultiplayerManager.AVAILABLE_BALL_GRAPHICS:
		edit_profile_ball_opt.add_item(bg["name"], edit_profile_ball_opt.item_count)
	edit_profile_ball_opt.custom_minimum_size = Vector2(240, 50)
	edit_profile_ball_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_option_button_style(edit_profile_ball_opt, 18, Vector2(0, 50))
	edit_profile_ball_graphic = reg.get("ball_graphic", "single_line")
	edit_profile_ball_opt.selected = _ball_graphic_id_to_index(edit_profile_ball_graphic)
	edit_profile_ball_opt.item_selected.connect(func(idx: int):
		edit_profile_ball_graphic = _ball_graphic_index_to_id(idx)
		_update_edit_profile_ball_ui()
	)
	ball_hbox.add_child(edit_profile_ball_opt)

	var match_icon_btn = Button.new()
	match_icon_btn.text = "Match Player Icon"
	match_icon_btn.custom_minimum_size = Vector2(170, 50)
	match_icon_btn.add_theme_font_size_override("font_size", 15)
	ThemeManager.apply_secondary_button_style(match_icon_btn, 6)
	match_icon_btn.pressed.connect(func():
		edit_profile_ball_graphic = "player_icon"
		edit_profile_ball_opt.selected = _ball_graphic_id_to_index("player_icon")
		_update_edit_profile_ball_ui()
	)
	ball_hbox.add_child(match_icon_btn)

	_update_edit_profile_ball_ui()

	# Golf Ball Type (Physics) Section
	var ball_type_sec = VBoxContainer.new()
	ball_type_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(ball_type_sec)

	var ball_type_title = Label.new()
	ball_type_title.text = "Golf Ball Type (Physics):"
	ball_type_title.add_theme_font_size_override("font_size", 15)
	ball_type_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ball_type_sec.add_child(ball_type_title)

	var ball_type_hint = Label.new()
	ball_type_hint.text = "ℹ️ Standard uses default physics; Soft adds spin with less rollout; Distance adds speed and rollout with less spin."
	ball_type_hint.add_theme_font_size_override("font_size", 13)
	ball_type_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	ball_type_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ball_type_sec.add_child(ball_type_hint)

	edit_profile_ball_type = MultiplayerManager.get_player_ball_type(player_name)
	edit_profile_ball_type_opt = OptionButton.new()
	edit_profile_ball_type_opt.clear()
	for bt in MultiplayerManager.AVAILABLE_BALL_TYPES:
		edit_profile_ball_type_opt.add_item(bt["name"], edit_profile_ball_type_opt.item_count)
	edit_profile_ball_type_opt.custom_minimum_size = Vector2(0, 50)
	ThemeManager.apply_option_button_style(edit_profile_ball_type_opt, 18, Vector2(0, 50))
	edit_profile_ball_type_opt.selected = _ball_type_id_to_index(edit_profile_ball_type)
	edit_profile_ball_type_opt.item_selected.connect(func(idx: int):
		edit_profile_ball_type = _ball_type_index_to_id(idx)
	)
	ball_type_sec.add_child(edit_profile_ball_type_opt)

	# Bag Section
	var bag_sec = VBoxContainer.new()
	bag_sec.add_theme_constant_override("separation", 6)
	edit_profile_content.add_child(bag_sec)
	
	var bag_title = Label.new()
	bag_title.text = "Golf Bag Configuration:"
	bag_title.add_theme_font_size_override("font_size", 15)
	bag_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bag_sec.add_child(bag_title)

	var cur_bag = MultiplayerManager.get_player_bag(player_name)
	var bag_status_str = "Default (All 20 clubs)" if cur_bag.is_empty() else "%d Clubs Configured" % cur_bag.size()
	
	var bag_hbox = HBoxContainer.new()
	bag_hbox.add_theme_constant_override("separation", 14)
	bag_sec.add_child(bag_hbox)

	var bag_status_lbl = Label.new()
	bag_status_lbl.text = "Current: " + bag_status_str
	bag_status_lbl.add_theme_font_size_override("font_size", 16)
	bag_status_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	bag_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_hbox.add_child(bag_status_lbl)

	var open_bag_btn = Button.new()
	open_bag_btn.text = "🎒 Build Your Bag..."
	open_bag_btn.custom_minimum_size = Vector2(200, 48)
	open_bag_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_primary_button_style(open_bag_btn, 6)
	open_bag_btn.pressed.connect(func():
		edit_profile_dialog.hide()
		_switch_to_bag_tab()
	)
	bag_hbox.add_child(open_bag_btn)
	
	edit_profile_dialog.popup_centered()
	edit_profile_email_input.call_deferred("grab_focus")


func _on_edit_profile_email_gui_input(ev: InputEvent) -> void:
	if has_node("/root/VirtualKeyboardManager"):
		var vkm = get_node("/root/VirtualKeyboardManager")
		if vkm.is_controller_mode_active():
			if (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_A) or ev.is_action_pressed("ui_accept"):
				vkm.open_for(edit_profile_email_input, true)
				get_viewport().set_input_as_handled()


func _switch_to_bag_tab() -> void:
	var tabs_node = stats_panel.find_child("TabContainer", true, false)
	if tabs_node != null and tabs_node is TabContainer:
		for i in range(tabs_node.get_tab_count()):
			if "Bag" in tabs_node.get_tab_title(i):
				tabs_node.current_tab = i
				last_active_tab_index = i
				break

func _update_edit_profile_avatar_ui() -> void:
	if edit_profile_avatar_preview_container == null:
		return
	for child in edit_profile_avatar_preview_container.get_children():
		child.queue_free()
		
	if not edit_profile_avatar_path.is_empty() and ResourceLoader.exists(edit_profile_avatar_path):
		var trect = TextureRect.new()
		trect.texture = load(edit_profile_avatar_path)
		trect.custom_minimum_size = Vector2(48, 48)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		edit_profile_avatar_preview_container.add_child(trect)
		
		var av_name = "Custom Avatar"
		for av in MultiplayerManager.AVAILABLE_AVATARS:
			if av["path"] == edit_profile_avatar_path:
				av_name = av["name"]
				break
		var name_l = Label.new()
		name_l.text = av_name
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		edit_profile_avatar_preview_container.add_child(name_l)
	else:
		var circ = PanelContainer.new()
		circ.custom_minimum_size = Vector2(48, 48)
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.24, 0.46, 0.72)
		cs.corner_radius_top_left = 24
		cs.corner_radius_top_right = 24
		cs.corner_radius_bottom_left = 24
		cs.corner_radius_bottom_right = 24
		circ.add_theme_stylebox_override("panel", cs)
		var clbl = Label.new()
		clbl.text = edit_profile_player_name.substr(0, 1).to_upper()
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clbl.add_theme_font_size_override("font_size", 22)
		circ.add_child(clbl)
		edit_profile_avatar_preview_container.add_child(circ)
		
		var name_l = Label.new()
		name_l.text = "None (Default Initial)"
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		edit_profile_avatar_preview_container.add_child(name_l)

	if edit_profile_ball_graphic == "player_icon":
		_update_edit_profile_ball_ui()

func _update_edit_profile_ball_ui() -> void:
	if edit_profile_ball_preview_container == null:
		return
	for child in edit_profile_ball_preview_container.get_children():
		child.queue_free()

	var preview = _create_ball_preview_icon(edit_profile_ball_graphic, edit_profile_avatar_path, edit_profile_player_name, Vector2(48, 48))
	edit_profile_ball_preview_container.add_child(preview)

func _on_edit_profile_confirmed() -> void:
	if edit_profile_player_name.is_empty():
		return
	var new_email = edit_profile_email_input.text.strip_edges()
	var new_tee = ""
	if edit_profile_tee_opt != null and edit_profile_tee_opt.selected > 0:
		new_tee = edit_profile_tee_opt.get_item_text(edit_profile_tee_opt.selected)
	var new_skill = _skill_index_to_key(edit_profile_skill_opt.selected)
	var new_handedness = edit_profile_handedness_opt.selected if edit_profile_handedness_opt != null else 0
	var new_ball_graphic = edit_profile_ball_graphic
	var new_ball_type = edit_profile_ball_type
	MultiplayerManager.update_player_profile(edit_profile_player_name, new_email, edit_profile_avatar_path, new_tee, new_skill, new_handedness, new_ball_graphic, new_ball_type)
	_refresh_players_list()
	_render_player_profile(edit_profile_player_name)



func _confirm_delete_player() -> void:
	if not selected_player_name.is_empty():
		MultiplayerManager.delete_player_permanently(selected_player_name)
		selected_player_name = ""
		last_active_tab_index = 0
		_refresh_players_list()
		_render_empty_stats()

func _confirm_clear_history() -> void:
	if not selected_player_name.is_empty():
		MultiplayerManager.clear_player_ball_history(selected_player_name)
		_select_player(selected_player_name)

func _request_clear_club_data(club_name: String, display_name: String, count: int) -> void:
	if selected_player_name.is_empty():
		return
	pending_club_to_clear = club_name
	clear_club_confirm_dialog.dialog_text = "Are you sure you want to clear shot data for %s for %s?\n\nThis will reset all %d recorded shots for this club and cannot be undone." % [display_name, selected_player_name, count]
	clear_club_confirm_dialog.popup_centered()

func _confirm_clear_club_shot_data() -> void:
	if not selected_player_name.is_empty() and not pending_club_to_clear.is_empty():
		MultiplayerManager.clear_player_club_shot_data(selected_player_name, pending_club_to_clear)
		pending_club_to_clear = ""
		_select_player(selected_player_name)

func _render_empty_stats() -> void:
	for child in stats_panel.get_children():
		child.queue_free()
		
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(center)
	
	var lbl = Label.new()
	lbl.text = "Select a player from the registry to view stats & manage profiles."
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	center.add_child(lbl)

func _render_player_profile(player_name: String) -> void:
	for child in stats_panel.get_children():
		child.queue_free()
		
	var stats = _calculate_player_stats(player_name)
	
	var main_layout = VBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 14)
	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(main_layout)
	
	# Header with Player Avatar, Name, Email, and Edit Button
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	main_layout.add_child(header_hbox)
	
	var reg_p = MultiplayerManager.get_registered_player(player_name)
	var p_avatar = reg_p.get("avatar", "")
	var p_email = reg_p.get("email", "")

	if not p_avatar.is_empty() and ResourceLoader.exists(p_avatar):
		var av_rect = TextureRect.new()
		av_rect.texture = load(p_avatar)
		av_rect.custom_minimum_size = Vector2(56, 56)
		av_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_hbox.add_child(av_rect)
	else:
		var circ = PanelContainer.new()
		circ.custom_minimum_size = Vector2(56, 56)
		circ.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.24, 0.46, 0.72)
		cs.corner_radius_top_left = 28
		cs.corner_radius_top_right = 28
		cs.corner_radius_bottom_left = 28
		cs.corner_radius_bottom_right = 28
		circ.add_theme_stylebox_override("panel", cs)
		var clbl = Label.new()
		clbl.text = player_name.substr(0, 1).to_upper()
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clbl.add_theme_font_size_override("font_size", 28)
		clbl.add_theme_color_override("font_color", Color.WHITE)
		circ.add_child(clbl)
		header_hbox.add_child(circ)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(info_vbox)

	# Name and inline Cloud Profile / Cloud Link controls
	var name_row = HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("separation", 12)
	name_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	info_vbox.add_child(name_row)

	var name_lbl = Label.new()
	name_lbl.text = player_name
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_lbl)

	var p_tee = reg_p.get("preferred_tee", "")

	# Cloud Profile controls & CloudLinkSection placed to the right of the profile name
	var cloud_profile_hbox = HBoxContainer.new()
	cloud_profile_hbox.name = "CloudProfileHBox"
	cloud_profile_hbox.add_theme_constant_override("separation", 10)
	cloud_profile_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_child(cloud_profile_hbox)

	var auth = get_node_or_null("/root/CloudAuth")
	var signed_in = (auth != null and auth.has_method("is_signed_in") and auth.is_signed_in())
	var is_primary = (str(reg_p.get("link_role", "none")) == "primary")

	if signed_in:
		if is_primary:
			var cs = get_node_or_null("/root/CloudSync")
			var last_synced_at = float(reg_p.get("last_synced_at", 0.0))
			var is_dirty = (cs != null and cs.dirty_profiles.has(player_name))
			var is_syncing = (cs != null and bool(cs.get("_is_syncing")))

			var primary_badge = Button.new()
			primary_badge.name = "PrimaryProfileBtn"
			if is_syncing:
				primary_badge.text = "★ Primary Cloud Profile (Syncing...)"
			elif last_synced_at > 0.0 and not is_dirty:
				primary_badge.text = "★ Primary Cloud Profile (Synced)"
			else:
				primary_badge.text = "★ Primary Cloud Profile (Sync Pending)"

			primary_badge.custom_minimum_size = Vector2(250, 38)
			primary_badge.focus_mode = Control.FOCUS_ALL
			var p_style = StyleBoxFlat.new()
			if last_synced_at > 0.0 and not is_dirty:
				p_style.bg_color = Color(0.12, 0.35, 0.18, 0.95)
				p_style.border_color = Color(0.35, 0.85, 0.45, 1.0)
				primary_badge.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
			else:
				p_style.bg_color = Color(0.35, 0.25, 0.08, 0.95)
				p_style.border_color = Color(0.95, 0.75, 0.2, 1.0)
				primary_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
			p_style.set_border_width_all(2)
			p_style.set_corner_radius_all(6)
			p_style.content_margin_left = 12.0
			p_style.content_margin_right = 12.0
			primary_badge.add_theme_stylebox_override("normal", p_style)
			primary_badge.tooltip_text = "Primary cloud profile for this account. Click to unset primary."
			primary_badge.pressed.connect(func():
				_show_unset_primary_confirm_dialog(player_name)
			)
			cloud_profile_hbox.add_child(primary_badge)

			var sync_primary_btn = Button.new()
			sync_primary_btn.name = "SyncPrimaryBtn"
			sync_primary_btn.text = "🔄 Sync Now"
			sync_primary_btn.custom_minimum_size = Vector2(110, 38)
			sync_primary_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(sync_primary_btn, 6)
			sync_primary_btn.pressed.connect(func():
				if cs != null and cs.has_method("sync_single_profile"):
					if cs.has_method("can_manual_sync") and not cs.can_manual_sync():
						return
					sync_primary_btn.text = "⏳..."
					sync_primary_btn.disabled = true
					var uid_to_sync = str(reg_p.get("cloud_uid", ""))
					if uid_to_sync.is_empty() and auth != null and auth.has_method("get_uid"):
						uid_to_sync = auth.get_uid()
					var sync_res = await cs.sync_single_profile(player_name, uid_to_sync, true)
					if not sync_res.get("ok", false):
						print("[PlayersMenu] Primary profile sync error: %s" % sync_res.get("error", "Unknown error"))
					_render_player_profile(player_name)
			)
			cloud_profile_hbox.add_child(sync_primary_btn)
		else:
			var set_primary_btn = Button.new()
			set_primary_btn.name = "PrimaryProfileBtn"
			set_primary_btn.text = "☆ Set as Primary Cloud Profile"
			set_primary_btn.custom_minimum_size = Vector2(250, 38)
			set_primary_btn.focus_mode = Control.FOCUS_ALL
			ThemeManager.apply_secondary_button_style(set_primary_btn, 6)
			set_primary_btn.pressed.connect(func():
				_show_primary_confirm_dialog(player_name)
			)
			cloud_profile_hbox.add_child(set_primary_btn)
	else:
		var offline_primary_btn = Button.new()
		offline_primary_btn.name = "PrimaryProfileBtn"
		offline_primary_btn.text = "☁ Sign in to set as Primary Cloud Profile"
		offline_primary_btn.custom_minimum_size = Vector2(270, 38)
		offline_primary_btn.focus_mode = Control.FOCUS_ALL
		ThemeManager.apply_secondary_button_style(offline_primary_btn, 6)
		offline_primary_btn.pressed.connect(func():
			_pending_primary_link_player = player_name
			_open_account_modal()
		)
		cloud_profile_hbox.add_child(offline_primary_btn)

	# CloudLinkSection container populated for Package 04
	var cloud_link_section = HBoxContainer.new()
	cloud_link_section.name = "CloudLinkSection"
	cloud_link_section.add_theme_constant_override("separation", 8)
	cloud_profile_hbox.add_child(cloud_link_section)
	_populate_cloud_link_section(cloud_link_section, reg_p, player_name, signed_in)

	var edit_profile_btn = Button.new()
	edit_profile_btn.name = "EditProfileBtn"
	edit_profile_btn.text = "✏️ Edit Profile"
	edit_profile_btn.custom_minimum_size = Vector2(160, 50)
	edit_profile_btn.add_theme_font_size_override("font_size", 17)
	ThemeManager.apply_secondary_button_style(edit_profile_btn, 6)
	edit_profile_btn.pressed.connect(func(): _open_edit_profile_dialog(player_name))
	header_hbox.add_child(edit_profile_btn)
	
	# Divider
	var divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.3, 0.4, 0.5, 0.4)
	main_layout.add_child(divider)
	
	# TabContainer for Stats and Achievements
	var tabs = TabContainer.new()
	tabs.name = "TabContainer"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	main_layout.add_child(tabs)
	
	# --- TAB 1: Career Overview ---
	var overview_vbox = VBoxContainer.new()
	overview_vbox.name = "📊 Overview & Records"
	overview_vbox.add_theme_constant_override("separation", 16)
	overview_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(overview_vbox)

	# Profile Info Section Card
	var profile_panel = PanelContainer.new()
	profile_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prof_box = StyleBoxFlat.new()
	prof_box.bg_color = Color(0.12, 0.16, 0.22, 0.75)
	prof_box.border_color = Color(0.25, 0.35, 0.45, 0.7)
	prof_box.set_border_width_all(1)
	prof_box.set_corner_radius_all(8)
	prof_box.content_margin_left = 16.0
	prof_box.content_margin_right = 16.0
	prof_box.content_margin_top = 12.0
	prof_box.content_margin_bottom = 12.0
	profile_panel.add_theme_stylebox_override("panel", prof_box)
	overview_vbox.add_child(profile_panel)

	var prof_vbox = VBoxContainer.new()
	prof_vbox.add_theme_constant_override("separation", 10)
	prof_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_panel.add_child(prof_vbox)

	var prof_title = Label.new()
	prof_title.text = "Player Details"
	prof_title.add_theme_font_size_override("font_size", 17)
	prof_title.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	prof_vbox.add_child(prof_title)

	var prof_grid = GridContainer.new()
	prof_grid.columns = 3
	prof_grid.add_theme_constant_override("h_separation", 32)
	prof_grid.add_theme_constant_override("v_separation", 8)
	prof_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prof_vbox.add_child(prof_grid)

	var add_detail_item = func(label_text: String, value_text: String, val_color: Color):
		var item_vbox = VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 2)
		var l = Label.new()
		l.text = label_text
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		item_vbox.add_child(l)
		var v = Label.new()
		v.text = value_text
		v.add_theme_font_size_override("font_size", 15)
		v.add_theme_color_override("font_color", val_color)
		item_vbox.add_child(v)
		prof_grid.add_child(item_vbox)

	var email_display = p_email if not p_email.is_empty() else "None set"
	var email_color = Color(0.75, 0.88, 1.0) if not p_email.is_empty() else Color(0.6, 0.6, 0.6)
	add_detail_item.call("Email", "✉ " + email_display, email_color)

	var tee_color = Color(0.8, 0.9, 1.0)
	if not p_tee.is_empty():
		match p_tee.to_lower():
			"blue": tee_color = Color(0.4, 0.7, 1.0)
			"red": tee_color = Color(1.0, 0.45, 0.45)
			"white": tee_color = Color(0.95, 0.95, 0.95)
			"black": tee_color = Color(0.7, 0.7, 0.7)
			"gold": tee_color = Color(1.0, 0.85, 0.3)
	var tee_display = p_tee if not p_tee.is_empty() else "None"
	add_detail_item.call("Preferred Tee", "⛳ " + tee_display, tee_color)

	var p_skill = reg_p.get("skill_level", "mid_handicap")
	add_detail_item.call("Skill Level", "🎯 " + _skill_key_to_display(p_skill), Color(0.4, 0.9, 0.6))

	var p_hand = int(reg_p.get("handedness", 0))
	add_detail_item.call("Dexterity", "🏌️ " + ("Left-Handed" if p_hand == 1 else "Right-Handed"), Color(0.95, 0.82, 0.45))

	var p_ball = reg_p.get("ball_graphic", "single_line")
	add_detail_item.call("Ball Alignment", "⚪ " + _ball_graphic_id_to_name(p_ball), Color(0.85, 0.88, 1.0))

	var p_ball_type = reg_p.get("ball_type", "standard")
	add_detail_item.call("Ball Type", "🏌️ " + _ball_type_id_to_name(p_ball_type), Color(0.82, 0.94, 0.88))
	
	# Stats Grid Layout
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 14)
	overview_vbox.add_child(grid)
	
	var add_stat_box = func(label_text: String, value_text: String):
		var vbox = VBoxContainer.new()
		
		var val_lbl = Label.new()
		val_lbl.text = value_text
		val_lbl.add_theme_font_size_override("font_size", 26)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		vbox.add_child(val_lbl)
		
		var lbl = Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(lbl)
		
		grid.add_child(vbox)
		
	add_stat_box.call("Total Matches Played", str(stats["matches_played"]))
	add_stat_box.call("Multiplayer Wins", str(stats["wins"]))
	add_stat_box.call("Multiplayer Losses", str(stats["losses"]))
	add_stat_box.call("Multiplayer Ties", str(stats["ties"]))
	add_stat_box.call("Single Player Completed", str(stats["single_player_completed"]))
	
	var avg_par_str = "---"
	if stats["avg_to_par_valid"]:
		var val = stats["avg_to_par"]
		if val > 0:
			avg_par_str = "+%.1f" % val
		elif val < 0:
			avg_par_str = "%.1f" % val
		else:
			avg_par_str = "Even (E)"
	add_stat_box.call("Avg +/- Par per Round", avg_par_str)
	
	var drive_str = "---"
	if stats["longest_drive"] > 0:
		drive_str = "%.1f yds" % stats["longest_drive"]
	add_stat_box.call("Longest Drive", drive_str)
	
	var putt_str = "---"
	if stats.get("longest_putt_ft", 0.0) > 0:
		putt_str = "%.1f ft" % stats["longest_putt_ft"]
	add_stat_box.call("Longest Putt", putt_str)
	add_stat_box.call("Preferred Tee", p_tee if not p_tee.is_empty() else "None")
	
	var records_lbl = Label.new()
	records_lbl.text = "Best completed scores per course:"
	records_lbl.add_theme_font_size_override("font_size", 18)
	records_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	overview_vbox.add_child(records_lbl)
	
	var records_scroll = ScrollContainer.new()
	records_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(records_scroll, 28)
	overview_vbox.add_child(records_scroll)
	
	var records_vbox = VBoxContainer.new()
	records_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records_scroll.add_child(records_vbox)
	
	var best_courses_dict = stats["best_courses"]
	if best_courses_dict.is_empty():
		var no_records = Label.new()
		no_records.text = "No completed course matches recorded yet."
		no_records.add_theme_font_size_override("font_size", 15)
		no_records.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		records_vbox.add_child(no_records)
	else:
		for course_name in best_courses_dict:
			var record_data = best_courses_dict[course_name]
			var record_lbl = Label.new()
			record_lbl.text = "  ⛳  %s:  %s" % [course_name, record_data["str"]]
			record_lbl.add_theme_font_size_override("font_size", 17)
			record_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			records_vbox.add_child(record_lbl)
			
	# --- TAB 2: Club Distances & Shot History ---
	var club_vbox = _build_club_distances_tab(player_name)
	tabs.add_child(club_vbox)

	# --- TAB 3: Build Your Bag ---
	var bag_vbox = _build_bag_tab(player_name)
	tabs.add_child(bag_vbox)

	# --- TAB 4: Achievements Gallery ---
	var ach_vbox = VBoxContainer.new()
	ach_vbox.name = "🏆 Achievements"
	ach_vbox.add_theme_constant_override("separation", 12)
	ach_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(ach_vbox)
	
	var all_ach = AchievementManager.get_all_achievements()
	var unlocked_map = AchievementManager.get_unlocked_achievements(player_name)
	var unlocked_count = unlocked_map.size()
	var total_count = all_ach.size()
	var percent = int((float(unlocked_count) / float(total_count)) * 100.0) if total_count > 0 else 0
	
	var ach_summary_lbl = Label.new()
	ach_summary_lbl.text = "Unlocked: %d / %d (%d%%)" % [unlocked_count, total_count, percent]
	ach_summary_lbl.add_theme_font_size_override("font_size", 18)
	ach_summary_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	ach_vbox.add_child(ach_summary_lbl)
	
	var ach_scroll = ScrollContainer.new()
	ach_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(ach_scroll, 28)
	ach_vbox.add_child(ach_scroll)
	
	var ach_grid = GridContainer.new()
	ach_grid.columns = 2
	ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_grid.add_theme_constant_override("h_separation", 14)
	ach_grid.add_theme_constant_override("v_separation", 12)
	ach_scroll.add_child(ach_grid)
	
	for ach in all_ach:
		var ach_id = ach.get("id", "")
		var is_unlocked = unlocked_map.has(ach_id)
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(280, 80)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var card_style = StyleBoxFlat.new()
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left = 10
		card_style.content_margin_top = 8
		card_style.content_margin_right = 10
		card_style.content_margin_bottom = 8
		
		if is_unlocked:
			card_style.bg_color = Color(0.12, 0.2, 0.12, 0.85)
			card_style.border_width_left = 2
			card_style.border_width_top = 2
			card_style.border_width_right = 2
			card_style.border_width_bottom = 2
			card_style.border_color = Color(0.95, 0.76, 0.2, 0.9)
		else:
			card_style.bg_color = Color(0.06, 0.08, 0.06, 0.45)
			card_style.border_width_left = 1
			card_style.border_width_top = 1
			card_style.border_width_right = 1
			card_style.border_width_bottom = 1
			card_style.border_color = Color(0.2, 0.25, 0.2, 0.4)
			
		card.add_theme_stylebox_override("panel", card_style)
		
		var card_hbox = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 10)
		card.add_child(card_hbox)
		
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(52, 52)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var b_path = ach.get("badge_path", "")
		if ResourceLoader.exists(b_path):
			icon_rect.texture = load(b_path)
			
		if not is_unlocked:
			icon_rect.modulate = Color(0.35, 0.35, 0.35, 0.45)
			
		card_hbox.add_child(icon_rect)
		
		var ach_info_vbox = VBoxContainer.new()
		ach_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ach_info_vbox.add_theme_constant_override("separation", 2)
		card_hbox.add_child(ach_info_vbox)
		
		var title_l = Label.new()
		title_l.text = ach.get("title", "Achievement")
		title_l.add_theme_font_size_override("font_size", 15)
		if is_unlocked:
			title_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		else:
			title_l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		ach_info_vbox.add_child(title_l)
		
		var desc_l = Label.new()
		desc_l.text = ach.get("description", "")
		desc_l.add_theme_font_size_override("font_size", 12)
		desc_l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7) if is_unlocked else Color(0.45, 0.45, 0.45))
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ach_info_vbox.add_child(desc_l)
		
		var status_l = Label.new()
		if is_unlocked:
			var unix_t = unlocked_map[ach_id].get("unlocked_at", 0)
			var date_str = Time.get_date_string_from_unix_time(int(unix_t)) if unix_t > 0 else ""
			status_l.text = "✓ Unlocked %s" % date_str if not date_str.is_empty() else "✓ Unlocked"
			status_l.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		elif ach_id == "all_heckles":
			var heard_count = AchievementManager.get_heard_heckles_count(player_name)
			var total_count_heckles = AchievementManager.get_total_heckles_count()
			status_l.text = "🔒 %d / %d Heard" % [heard_count, total_count_heckles]
			status_l.add_theme_color_override("font_color", Color(0.85, 0.7, 0.3))
		else:
			status_l.text = "🔒 Locked"
			status_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		status_l.add_theme_font_size_override("font_size", 11)
		ach_info_vbox.add_child(status_l)
		
		ach_grid.add_child(card)
		
	# --- TAB 3: Video Swing Recommendations ---
	var swing_vbox = VBoxContainer.new()
	swing_vbox.name = "🎯 Swing Recommendations"
	swing_vbox.add_theme_constant_override("separation", 14)
	swing_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swing_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(swing_vbox)

	var p_issues = MultiplayerManager.get_player_swing_issues(player_name)
	var all_time_issues: Dictionary = p_issues.get("all_time", {})
	var monthly_issues: Dictionary = p_issues.get("monthly", {})
	var issues_meta: Dictionary = MultiplayerManager.get_player_swing_issues_meta(player_name) if MultiplayerManager.has_method("get_player_swing_issues_meta") else {}
	var date_dict = Time.get_date_dict_from_system()
	var current_month_key = "%04d-%02d" % [date_dict.year, date_dict.month]
	var current_month_name = MultiplayerManager.get_month_display_name(current_month_key)
	var cur_analyzed: int = int(issues_meta.get(current_month_key, {}).get("analyzed_shots", 0))
	var sorted_months: Array = monthly_issues.keys()
	sorted_months.sort()
	var prev_month_key: String = ""
	for mk in sorted_months:
		if str(mk) < current_month_key:
			prev_month_key = str(mk)
	var prev_month_data: Dictionary = monthly_issues.get(prev_month_key, {}) if not prev_month_key.is_empty() else {}
	var prev_analyzed: int = int(issues_meta.get(prev_month_key, {}).get("analyzed_shots", 0)) if not prev_month_key.is_empty() else 0

	var swing_scroll = ScrollContainer.new()
	swing_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(swing_scroll, 28)
	swing_vbox.add_child(swing_scroll)

	var swing_content_vbox = VBoxContainer.new()
	swing_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swing_content_vbox.add_theme_constant_override("separation", 16)
	swing_scroll.add_child(swing_content_vbox)

	if all_time_issues.is_empty():
		var empty_swing_lbl = Label.new()
		empty_swing_lbl.text = "No swing recommendations recorded yet.\nTurn on Shot Analysis and/or Golfer Camera during Driving Range, Course Play, or Practice to track swing fixes!"
		empty_swing_lbl.add_theme_font_size_override("font_size", 16)
		empty_swing_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		swing_content_vbox.add_child(empty_swing_lbl)
	else:
		# Monthly section
		var cur_month_data: Dictionary = monthly_issues.get(current_month_key, {})
		var month_hdr = Label.new()
		var analyzed_suffix: String = (" · %d shots analyzed" % cur_analyzed) if cur_analyzed > 0 else ""
		month_hdr.text = "📅 Current Month Running Totals (%s%s)" % [current_month_name, analyzed_suffix]
		month_hdr.add_theme_font_size_override("font_size", 18)
		month_hdr.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		swing_content_vbox.add_child(month_hdr)

		if cur_month_data.is_empty():
			var no_m = Label.new()
			no_m.text = "No swing recommendations recorded for %s." % current_month_name
			no_m.add_theme_font_size_override("font_size", 14)
			no_m.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			swing_content_vbox.add_child(no_m)
		else:
			var m_grid = GridContainer.new()
			m_grid.columns = 2
			m_grid.add_theme_constant_override("h_separation", 16)
			m_grid.add_theme_constant_override("v_separation", 10)
			swing_content_vbox.add_child(m_grid)

			for issue in cur_month_data:
				var cnt_cur: int = int(cur_month_data[issue])
				var badge_parts: Array[String] = []
				if cur_analyzed > 0:
					var cur_rate: float = (float(cnt_cur) / float(maxi(cnt_cur, cur_analyzed))) * 100.0
					badge_parts.append("Rate: %.0f%%" % cur_rate)
					if prev_analyzed > 0 and prev_month_data.has(issue):
						var cnt_prev: int = int(prev_month_data[issue])
						var prev_rate: float = (float(cnt_prev) / float(maxi(cnt_prev, prev_analyzed))) * 100.0
						var delta_pct: float = cur_rate - prev_rate
						badge_parts.append("MoM %+.0f%%" % delta_pct)
				var card = _create_issue_card(issue, cnt_cur, "This Month", " · ".join(badge_parts))
				m_grid.add_child(card)

		# All-Time Section
		var at_hdr = Label.new()
		at_hdr.text = "🏆 All-Time Running Totals"
		at_hdr.add_theme_font_size_override("font_size", 18)
		at_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		swing_content_vbox.add_child(at_hdr)

		var at_grid = GridContainer.new()
		at_grid.columns = 2
		at_grid.add_theme_constant_override("h_separation", 16)
		at_grid.add_theme_constant_override("v_separation", 10)
		swing_content_vbox.add_child(at_grid)

		for issue in all_time_issues:
			var card = _create_issue_card(issue, int(all_time_issues[issue]), "All Time")
			at_grid.add_child(card)

	# --- TAB 6: Improvement Trends & Active Focus ---
	var trends_vbox: VBoxContainer = _build_improvement_trends_tab(player_name)
	tabs.add_child(trends_vbox)

	if last_active_tab_index >= 0 and last_active_tab_index < tabs.get_tab_count():
		tabs.current_tab = last_active_tab_index
	tabs.tab_changed.connect(func(tab_idx: int): last_active_tab_index = tab_idx)

	# Actions row at the bottom of the right stats panel
	var actions_hbox = HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 16)
	main_layout.add_child(actions_hbox)
	
	var spacer_act = Control.new()
	spacer_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_hbox.add_child(spacer_act)

	var email_report_btn = Button.new()
	email_report_btn.name = "EmailReportBtn"
	email_report_btn.text = "✉ Email Profile Report"
	email_report_btn.custom_minimum_size = Vector2(210, 52)
	email_report_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_primary_button_style(email_report_btn, 6)
	email_report_btn.pressed.connect(func(): _email_player_profile_report(player_name))
	actions_hbox.add_child(email_report_btn)
	
	var clear_btn = Button.new()
	clear_btn.name = "ClearBallHistoryBtn"
	clear_btn.text = "🧹 Clear All Ball History"
	clear_btn.custom_minimum_size = Vector2(210, 52)
	clear_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_secondary_button_style(clear_btn, 6)
	clear_btn.pressed.connect(func(): clear_confirm_dialog.popup_centered())
	actions_hbox.add_child(clear_btn)
	
	var delete_btn = Button.new()
	delete_btn.name = "DeleteProfileBtn"
	delete_btn.text = "❌ Delete Profile permanently"
	delete_btn.custom_minimum_size = Vector2(250, 52)
	delete_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_danger_button_style(delete_btn, 6)
	delete_btn.pressed.connect(func(): delete_confirm_dialog.popup_centered())
	actions_hbox.add_child(delete_btn)

	call_deferred("_update_controller_focus_navigation")

func _exit_tree() -> void:
	InAppVideoPlayer.stop_all_players()
	# Free any lazily-parented dialog controls that were never added to the scene tree
	# so their internal PopupMenu Viewports/RenderTargets/ShadowAtlases do not leak.
	var maybe_orphans: Array = [
		new_player_input,
		new_player_email_input,
		avatar_preview_btn,
		new_player_tee_opt,
		new_player_skill_opt,
		new_player_handedness_opt,
		new_player_ball_opt,
		new_player_ball_type_opt,
		new_player_ball_preview_container,
		register_btn,
		avatar_picker_content,
		create_profile_content,
		edit_profile_email_input,
		edit_profile_tee_opt,
		edit_profile_skill_opt,
		edit_profile_handedness_opt,
		edit_profile_ball_opt,
		edit_profile_ball_type_opt,
		edit_profile_content,
	]
	for ctrl in maybe_orphans:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.get_parent() == null:
			ctrl.call_deferred("free")

func _create_issue_card(issue_name: String, count: int, period_label: String, extra_badge: String = "") -> Button:
	var card = Button.new()
	card.custom_minimum_size = Vector2(260, 64)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Click to view swing explanation, causes, and drill guide for %s" % issue_name
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.14, 0.18, 0.85)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.content_margin_left = 12
	normal_style.content_margin_top = 8
	normal_style.content_margin_right = 12
	normal_style.content_margin_bottom = 8
	normal_style.border_width_left = 3
	normal_style.border_color = Color(0.3, 0.7, 0.9, 0.7)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.22, 0.28, 0.95)
	hover_style.border_color = Color(0.4, 0.85, 1.0, 1.0)
	hover_style.border_width_left = 4

	var focus_style = hover_style.duplicate()
	focus_style.border_width_right = 3
	focus_style.border_width_top = 3
	focus_style.border_width_bottom = 3
	
	card.add_theme_stylebox_override("normal", normal_style)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)
	card.add_theme_stylebox_override("focus", focus_style)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = issue_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = period_label + (" • " + extra_badge if not extra_badge.is_empty() else "") + " • 🔍 Click for drill & fix"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)
	
	var cnt_lbl = Label.new()
	cnt_lbl.text = str(count)
	cnt_lbl.add_theme_font_size_override("font_size", 24)
	cnt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cnt_lbl)
	
	card.pressed.connect(func():
		_show_issue_detail_modal(issue_name)
	)
	
	return card

func _show_issue_detail_modal(issue_name: String) -> void:
	var existing = get_node_or_null("IssueDetailModal")
	if existing != null:
		InAppVideoPlayer.stop_all_players()
		if has_node("/root/UIFocusGuard"):
			get_node("/root/UIFocusGuard").pop_lock()
		existing.queue_free()
	
	var info = GolfSwingAnalyzer.get_issue_info(issue_name)
	var modal = _create_issue_detail_modal(info)
	add_child(modal)
	if has_node("/root/UIFocusGuard"):
		get_node("/root/UIFocusGuard").push_lock(modal)

func _create_issue_detail_modal(info: Dictionary) -> Control:
	var vp_size = get_viewport_rect().size
	var root = Control.new()
	root.name = "IssueDetailModal"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 50
	
	var dismiss_modal = func():
		InAppVideoPlayer.stop_all_players()
		if has_node("/root/UIFocusGuard"):
			get_node("/root/UIFocusGuard").pop_lock()
		root.queue_free()
	
	root.tree_exiting.connect(func():
		InAppVideoPlayer.stop_all_players()
	)
	
	# Backdrop dimmer
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.75)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dismiss_modal.call()
	)
	root.add_child(dimmer)
	
	# Centered Modal Panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	
	var is_mob: bool = (vp_size.x < 850 or vp_size.y > vp_size.x or OS.has_feature("mobile"))
	var has_video: bool = not str(info.get("video_url", "")).is_empty()
	var panel_w = clamp(vp_size.x * 0.94, 320, 840) if is_mob else (clamp(vp_size.x * 0.72, 700, 920) if has_video else clamp(vp_size.x * 0.62, 500, 850))
	var panel_h = clamp(vp_size.y * 0.90, 360, 820) if is_mob else (clamp(vp_size.y * 0.88, 560, 780) if has_video else clamp(vp_size.y * 0.70, 400, 680))
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	ThemeManager.apply_modal_style(panel, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(outer_vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title_lbl = Label.new()
	title_lbl.text = "🎯 " + str(info.get("title", "Swing Flaw Diagnostic"))
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	title_vbox.add_child(title_lbl)
	
	var sub_lbl = Label.new()
	var sev = str(info.get("severity", "HIGH"))
	var cat = str(info.get("category", "SWING MECHANICS"))
	sub_lbl.text = "Category: %s  •  Priority: %s" % [cat, sev]
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 0.98))
	title_vbox.add_child(sub_lbl)
	
	header.add_child(title_vbox)
	
	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.custom_minimum_size = Vector2(46, 46)
	close_btn.add_theme_font_size_override("font_size", 22)
	ThemeManager.apply_danger_button_style(close_btn, 6)
	close_btn.pressed.connect(dismiss_modal)
	header.add_child(close_btn)
	
	outer_vbox.add_child(header)
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(sep)
	
	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ThemeManager.apply_scroll_container_style(scroll, 28)
	outer_vbox.add_child(scroll)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(content_vbox)
	
	# Section 1: Biomechanics / Setup Cause
	var cam_flaw = str(info.get("camera_flaw", ""))
	if not cam_flaw.is_empty():
		var cam_panel = PanelContainer.new()
		var cam_style = StyleBoxFlat.new()
		cam_style.bg_color = Color(0.05, 0.09, 0.14, 0.95)
		cam_style.corner_radius_top_left = 8
		cam_style.corner_radius_top_right = 8
		cam_style.corner_radius_bottom_left = 8
		cam_style.corner_radius_bottom_right = 8
		cam_style.border_width_left = 4
		cam_style.border_color = Color(0.35, 0.85, 1.0, 0.9)
		cam_style.content_margin_left = 16
		cam_style.content_margin_top = 12
		cam_style.content_margin_right = 16
		cam_style.content_margin_bottom = 12
		cam_panel.add_theme_stylebox_override("panel", cam_style)
		
		var c_vbox = VBoxContainer.new()
		c_vbox.add_theme_constant_override("separation", 6)
		var c_hdr = Label.new()
		c_hdr.text = "🔍 What Causes It (Biomechanics & Delivery)"
		c_hdr.add_theme_font_size_override("font_size", 17)
		c_hdr.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		c_vbox.add_child(c_hdr)
		
		var c_lbl = Label.new()
		c_lbl.text = cam_flaw
		c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_lbl.add_theme_font_size_override("font_size", 15)
		c_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
		c_vbox.add_child(c_lbl)
		
		cam_panel.add_child(c_vbox)
		content_vbox.add_child(cam_panel)
	
	# Section 2: Launch Impact / Flight Consequence
	var launch_effect = str(info.get("launch_effect", ""))
	if not launch_effect.is_empty():
		var eff_panel = PanelContainer.new()
		var eff_style = StyleBoxFlat.new()
		eff_style.bg_color = Color(0.10, 0.08, 0.05, 0.95)
		eff_style.corner_radius_top_left = 8
		eff_style.corner_radius_top_right = 8
		eff_style.corner_radius_bottom_left = 8
		eff_style.corner_radius_bottom_right = 8
		eff_style.border_width_left = 4
		eff_style.border_color = Color(1.0, 0.85, 0.40, 0.9)
		eff_style.content_margin_left = 16
		eff_style.content_margin_top = 12
		eff_style.content_margin_right = 16
		eff_style.content_margin_bottom = 12
		eff_panel.add_theme_stylebox_override("panel", eff_style)
		
		var e_vbox = VBoxContainer.new()
		e_vbox.add_theme_constant_override("separation", 6)
		var e_hdr = Label.new()
		e_hdr.text = "⚡ Launch Symptom & Distance Effect"
		e_hdr.add_theme_font_size_override("font_size", 17)
		e_hdr.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
		e_vbox.add_child(e_hdr)
		
		var e_lbl = Label.new()
		e_lbl.text = launch_effect
		e_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e_lbl.add_theme_font_size_override("font_size", 15)
		e_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
		e_vbox.add_child(e_lbl)
		
		eff_panel.add_child(e_vbox)
		content_vbox.add_child(eff_panel)
	
	# Section 3: How to Fix
	var fix_instruction = str(info.get("fix_instruction", ""))
	if not fix_instruction.is_empty():
		var fix_panel = PanelContainer.new()
		var fix_style = StyleBoxFlat.new()
		fix_style.bg_color = Color(0.04, 0.11, 0.08, 0.95)
		fix_style.corner_radius_top_left = 8
		fix_style.corner_radius_top_right = 8
		fix_style.corner_radius_bottom_left = 8
		fix_style.corner_radius_bottom_right = 8
		fix_style.border_width_left = 4
		fix_style.border_color = Color(0.35, 1.0, 0.65, 0.9)
		fix_style.content_margin_left = 16
		fix_style.content_margin_top = 12
		fix_style.content_margin_right = 16
		fix_style.content_margin_bottom = 12
		fix_panel.add_theme_stylebox_override("panel", fix_style)
		
		var f_vbox = VBoxContainer.new()
		f_vbox.add_theme_constant_override("separation", 6)
		var f_hdr = Label.new()
		f_hdr.text = "💡 How to Fix It (Swing Cue)"
		f_hdr.add_theme_font_size_override("font_size", 17)
		f_hdr.add_theme_color_override("font_color", Color(0.40, 1.0, 0.68))
		f_vbox.add_child(f_hdr)
		
		var f_lbl = Label.new()
		f_lbl.text = fix_instruction
		f_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f_lbl.add_theme_font_size_override("font_size", 15)
		f_lbl.add_theme_color_override("font_color", Color(0.88, 0.98, 0.90))
		f_vbox.add_child(f_lbl)
		
		fix_panel.add_child(f_vbox)
		content_vbox.add_child(fix_panel)
	
	# Section 4: Practice Drill
	var drill_str = str(info.get("drill", ""))
	if not drill_str.is_empty():
		var drill_panel = PanelContainer.new()
		var drill_style = StyleBoxFlat.new()
		drill_style.bg_color = Color(0.10, 0.06, 0.17, 0.95)
		drill_style.corner_radius_top_left = 8
		drill_style.corner_radius_top_right = 8
		drill_style.corner_radius_bottom_left = 8
		drill_style.corner_radius_bottom_right = 8
		drill_style.border_width_left = 4
		drill_style.border_color = Color(0.80, 0.55, 1.0, 0.95)
		drill_style.content_margin_left = 16
		drill_style.content_margin_top = 14
		drill_style.content_margin_right = 16
		drill_style.content_margin_bottom = 14
		drill_panel.add_theme_stylebox_override("panel", drill_style)
		
		var d_vbox = VBoxContainer.new()
		d_vbox.add_theme_constant_override("separation", 8)
		var d_hdr = Label.new()
		d_hdr.text = "🏋️ Prescribed Practice Drill"
		d_hdr.add_theme_font_size_override("font_size", 17)
		d_hdr.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
		d_vbox.add_child(d_hdr)
		
		var d_lbl = Label.new()
		d_lbl.text = drill_str
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 15)
		d_lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 1.0))
		d_vbox.add_child(d_lbl)
		
		drill_panel.add_child(d_vbox)
		content_vbox.add_child(drill_panel)
	
	# Section 5: Video Tutorial
	var video_url = str(info.get("video_url", ""))
	if not video_url.is_empty():
		var video_vbox = VBoxContainer.new()
		video_vbox.add_theme_constant_override("separation", 8)
		
		var v_hdr = Label.new()
		v_hdr.text = "▶ Video Drill Tutorial"
		v_hdr.add_theme_font_size_override("font_size", 17)
		v_hdr.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
		video_vbox.add_child(v_hdr)
		
		var player = InAppVideoPlayer.new()
		player.setup(
			video_url,
			str(info.get("video_title", "HackMotion Video Drill Tutorial")),
			drill_str,
			str(info.get("category", "")),
			is_mob
		)
		video_vbox.add_child(player)
		content_vbox.add_child(video_vbox)
	
	# Footer
	var footer_btn = Button.new()
	footer_btn.text = "Close"
	footer_btn.custom_minimum_size = Vector2(160, 46)
	footer_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer_btn.add_theme_font_size_override("font_size", 16)
	ThemeManager.apply_secondary_button_style(footer_btn, 6)
	footer_btn.pressed.connect(dismiss_modal)
	outer_vbox.add_child(footer_btn)
	
	footer_btn.focus_neighbor_top = footer_btn.get_path_to(close_btn)
	close_btn.focus_neighbor_bottom = close_btn.get_path_to(footer_btn)
	footer_btn.call_deferred("grab_focus")
	
	return root

func _build_club_distances_tab(player_name: String) -> VBoxContainer:
	var tab_vbox = VBoxContainer.new()
	tab_vbox.name = "🏌 Club Distances"
	tab_vbox.add_theme_constant_override("separation", 14)
	tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var is_imperial: bool = GlobalSettings.range_settings.range_units.value == PhysicsEnums.Units.IMPERIAL if has_node("/root/GlobalSettings") else true
	var u_label: String = "yds" if is_imperial else "m"
	var s_label: String = "mph" if is_imperial else "m/s"
	var dist_mult: float = 1.09361 if is_imperial else 1.0
	var speed_mult: float = 1.0 if is_imperial else 0.44704

	var avgs = MultiplayerManager.calculate_player_club_averages(player_name)
	var total_shots := 0
	var active_clubs_count := 0
	for clb in avgs:
		total_shots += int(avgs[clb]["shot_count"])
		if avgs[clb]["has_data"]:
			active_clubs_count += 1

	# Top toolbar / summary header
	var toolbar_hbox = HBoxContainer.new()
	toolbar_hbox.add_theme_constant_override("separation", 16)
	tab_vbox.add_child(toolbar_hbox)

	var summary_lbl = Label.new()
	summary_lbl.text = "📊 %d Total Shots Recorded across %d Clubs (Units: %s)" % [
		total_shots,
		active_clubs_count,
		"Yards" if is_imperial else "Meters"
	]
	summary_lbl.add_theme_font_size_override("font_size", 16)
	summary_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	toolbar_hbox.add_child(summary_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_hbox.add_child(spacer)

	var active_filter_cb = CheckBox.new()
	active_filter_cb.text = "Show active clubs only"
	active_filter_cb.button_pressed = show_only_active_clubs
	active_filter_cb.add_theme_font_size_override("font_size", 14)
	active_filter_cb.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_WHITE)
	toolbar_hbox.add_child(active_filter_cb)

	# Scroll container for club list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(scroll, 28)
	tab_vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vbox)

	if total_shots == 0:
		var empty_panel = PanelContainer.new()
		empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ep_style = StyleBoxFlat.new()
		ep_style.bg_color = Color(0.08, 0.12, 0.16, 0.5)
		ep_style.corner_radius_top_left = 8
		ep_style.corner_radius_top_right = 8
		ep_style.corner_radius_bottom_left = 8
		ep_style.corner_radius_bottom_right = 8
		ep_style.content_margin_top = 16
		ep_style.content_margin_bottom = 16
		ep_style.content_margin_left = 16
		ep_style.content_margin_right = 16
		empty_panel.add_theme_stylebox_override("panel", ep_style)

		var empty_lbl = Label.new()
		empty_lbl.text = "No club shots recorded yet for this player.\nHit balls in the Driving Range or Course Play to track your distances and club averages!"
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		empty_panel.add_child(empty_lbl)
		list_vbox.add_child(empty_panel)

	if active_clubs_count >= 2:
		var gapping_rows: Array[Dictionary] = ShotAnalyticsEngineScript.analyze_bag_gapping(avgs)
		if gapping_rows.size() >= 2:
			var g_chart: Control = AnalyticsVisualWidgetsScript.create_bag_gapping_chart(gapping_rows, Vector2(360, 180))
			list_vbox.add_child(g_chart)

	var club_row_nodes: Array[Dictionary] = []

	for clb in avgs:
		var c_data = avgs[clb]
		c_data["player"] = player_name
		c_data["handedness"] = MultiplayerManager.get_player_handedness(player_name)
		c_data["is_lefty"] = (int(c_data["handedness"]) == 1)
		var shot_cnt: int = c_data["shot_count"]
		var has_shots: bool = (shot_cnt > 0)

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 68)

		var card_style = StyleBoxFlat.new()
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left = 16
		card_style.content_margin_right = 14
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8

		if has_shots:
			card_style.bg_color = Color(0.08, 0.13, 0.18, 0.85)
			card_style.border_width_left = 4
			card_style.border_color = Color(0.24, 0.65, 0.38, 0.9)
		else:
			card_style.bg_color = Color(0.06, 0.08, 0.10, 0.45)
			card_style.border_width_left = 1
			card_style.border_color = Color(0.2, 0.25, 0.3, 0.25)
		card.add_theme_stylebox_override("panel", card_style)

		var card_vbox = VBoxContainer.new()
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 14)
		card_vbox.add_child(row_hbox)

		# Column 1: Club Badge & Name
		var name_vbox = VBoxContainer.new()
		name_vbox.custom_minimum_size = Vector2(150, 0)
		name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		name_vbox.add_theme_constant_override("separation", 1)
		row_hbox.add_child(name_vbox)

		var code_lbl = Label.new()
		code_lbl.text = clb
		code_lbl.add_theme_font_size_override("font_size", 20)
		code_lbl.add_theme_color_override("font_color", Color.WHITE if has_shots else Color(0.5, 0.5, 0.5))
		name_vbox.add_child(code_lbl)

		var full_lbl = Label.new()
		full_lbl.text = c_data["display_name"]
		full_lbl.add_theme_font_size_override("font_size", 12)
		full_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8) if has_shots else Color(0.4, 0.4, 0.4))
		name_vbox.add_child(full_lbl)

		# Column 2: Shots Taken
		var count_vbox = VBoxContainer.new()
		count_vbox.custom_minimum_size = Vector2(100, 0)
		count_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		count_vbox.add_theme_constant_override("separation", 1)
		row_hbox.add_child(count_vbox)

		var count_val = Label.new()
		count_val.text = "%d shots" % shot_cnt if has_shots else "0 shots"
		count_val.add_theme_font_size_override("font_size", 17)
		count_val.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_ACCENT if has_shots else Color(0.45, 0.45, 0.45))
		count_vbox.add_child(count_val)

		var count_cap = Label.new()
		var mishits_cnt: int = c_data.get("mishits_excluded", 0)
		if mishits_cnt > 0:
			count_cap.text = "Valid (%d miss-hit%s)" % [mishits_cnt, "" if mishits_cnt == 1 else "s"]
			count_cap.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35, 0.9))
		else:
			count_cap.text = "Recorded"
			count_cap.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DIM)
		count_cap.add_theme_font_size_override("font_size", 11)
		count_vbox.add_child(count_cap)

		# Column 3: Stats (Total Distance, Carry Distance, Speed, Spin, Offline)
		var stats_hbox = HBoxContainer.new()
		stats_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_hbox.add_theme_constant_override("separation", 18)
		row_hbox.add_child(stats_hbox)

		var add_metric = func(value_str: String, cap_str: String, is_gold: bool = false, min_w: float = 85.0):
			var vb = VBoxContainer.new()
			vb.custom_minimum_size = Vector2(min_w, 0)
			vb.alignment = BoxContainer.ALIGNMENT_CENTER
			vb.add_theme_constant_override("separation", 1)

			var vl = Label.new()
			vl.text = value_str
			vl.add_theme_font_size_override("font_size", 17)
			if has_shots:
				vl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD if is_gold else Color.WHITE)
			else:
				vl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			vb.add_child(vl)

			var cl = Label.new()
			cl.text = cap_str
			cl.add_theme_font_size_override("font_size", 11)
			cl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DIM)
			vb.add_child(cl)
			stats_hbox.add_child(vb)

		var total_str = "%.1f %s" % [c_data["avg_total_m"] * dist_mult, u_label] if has_shots else "---"
		var carry_str = "%.1f %s" % [c_data["avg_carry_m"] * dist_mult, u_label] if has_shots else "---"
		var speed_str = "%.1f %s" % [c_data["avg_speed_mph"] * speed_mult, s_label] if has_shots else "---"
		var spin_str = "%.0f rpm" % c_data["avg_spin_rpm"] if has_shots else "---"
		var off_str = "%.1f %s" % [c_data["avg_offline_m"] * dist_mult, u_label] if has_shots else "---"

		add_metric.call(total_str, "Avg Total", true, 95.0)
		add_metric.call(carry_str, "Avg Carry", false, 95.0)
		add_metric.call(speed_str, "Avg Speed", false, 85.0)
		add_metric.call(spin_str, "Avg Spin", false, 85.0)
		add_metric.call(off_str, "Avg Offline", false, 85.0)

		# Column 4: Expand & Reset Buttons
		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 6)
		row_hbox.add_child(btn_hbox)

		var expand_btn = Button.new()
		expand_btn.text = "▼ Expand"
		expand_btn.custom_minimum_size = Vector2(92, 44)
		expand_btn.add_theme_font_size_override("font_size", 13)
		if has_shots:
			ThemeManager.apply_nav_button_style(expand_btn, 6)
		else:
			expand_btn.disabled = true
			expand_btn.modulate = Color(1, 1, 1, 0.3)
		btn_hbox.add_child(expand_btn)

		var reset_btn = Button.new()
		reset_btn.text = "🗑"
		reset_btn.tooltip_text = "Clear Shot Data for this Club"
		reset_btn.custom_minimum_size = Vector2(44, 44)
		reset_btn.add_theme_font_size_override("font_size", 15)

		if has_shots:
			ThemeManager.apply_danger_button_style(reset_btn, 6)
			var cur_clb = clb
			var cur_disp = c_data["display_name"]
			var cur_cnt = shot_cnt
			reset_btn.pressed.connect(func(): _request_clear_club_data(cur_clb, cur_disp, cur_cnt))
		else:
			reset_btn.disabled = true
			reset_btn.modulate = Color(1, 1, 1, 0.3)
		btn_hbox.add_child(reset_btn)

		# Expandable Drawer with Launch Monitor Stats & Delivery Visuals
		var drawer = PanelContainer.new()
		drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drawer.visible = false
		var drawer_style = StyleBoxFlat.new()
		drawer_style.bg_color = Color(0.04, 0.06, 0.09, 0.85)
		drawer_style.corner_radius_top_left = 6
		drawer_style.corner_radius_top_right = 6
		drawer_style.corner_radius_bottom_left = 6
		drawer_style.corner_radius_bottom_right = 6
		drawer_style.border_width_top = 1
		drawer_style.border_color = Color(0.2, 0.35, 0.5, 0.5)
		drawer_style.content_margin_left = 8
		drawer_style.content_margin_top = 8
		drawer_style.content_margin_right = 8
		drawer_style.content_margin_bottom = 8
		drawer.add_theme_stylebox_override("panel", drawer_style)

		var drawer_vbox = VBoxContainer.new()
		drawer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drawer_vbox.add_theme_constant_override("separation", 10)
		drawer.add_child(drawer_vbox)

		# 1. Other Launch Monitor Club Data Panel
		var lm_panel = _build_club_launch_monitor_panel(c_data, is_imperial, dist_mult, speed_mult, u_label, s_label)
		drawer_vbox.add_child(lm_panel)

		# 2. Club Delivery Visuals (Face Angle, Impact Location, Club Path)
		var delivery_panel = ClubDeliveryVisuals.create_panel(c_data, true)
		drawer_vbox.add_child(delivery_panel)

		card_vbox.add_child(drawer)

		expand_btn.pressed.connect(func():
			drawer.visible = not drawer.visible
			expand_btn.text = "▲ Collapse" if drawer.visible else "▼ Expand"
		)

		if show_only_active_clubs and not has_shots:
			card.visible = false

		list_vbox.add_child(card)
		club_row_nodes.append({"card": card, "has_shots": has_shots})

	active_filter_cb.toggled.connect(func(pressed: bool):
		show_only_active_clubs = pressed
		for entry in club_row_nodes:
			if pressed:
				entry["card"].visible = entry["has_shots"]
			else:
				entry["card"].visible = true
	)

	return tab_vbox

func _build_club_launch_monitor_panel(c_data: Dictionary, is_imperial: bool, dist_mult: float, speed_mult: float, u_label: String, s_label: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.38, 0.55, 0.6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "📡 LAUNCH MONITOR CLUB AVERAGES"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	vbox.add_child(title_lbl)

	var flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	vbox.add_child(flow)

	var add_tile = func(title: String, val_str: String, is_active: bool, accent_color: Color = Color.WHITE):
		var tile = PanelContainer.new()
		tile.custom_minimum_size = Vector2(98, 48)
		var tile_style = StyleBoxFlat.new()
		if is_active:
			tile_style.bg_color = Color(0.08, 0.13, 0.18, 0.85)
			tile_style.border_color = Color(0.2, 0.35, 0.5, 0.5)
		else:
			tile_style.bg_color = Color(0.05, 0.07, 0.10, 0.45)
			tile_style.border_color = Color(0.18, 0.22, 0.28, 0.3)
		tile_style.border_width_left = 1
		tile_style.border_width_top = 1
		tile_style.border_width_right = 1
		tile_style.border_width_bottom = 1
		tile_style.corner_radius_top_left = 6
		tile_style.corner_radius_top_right = 6
		tile_style.corner_radius_bottom_left = 6
		tile_style.corner_radius_bottom_right = 6
		tile_style.content_margin_left = 8
		tile_style.content_margin_right = 8
		tile_style.content_margin_top = 4
		tile_style.content_margin_bottom = 4
		tile.add_theme_stylebox_override("panel", tile_style)

		var tvb = VBoxContainer.new()
		tvb.alignment = BoxContainer.ALIGNMENT_CENTER
		tvb.add_theme_constant_override("separation", 1)

		var val_lbl = Label.new()
		val_lbl.text = val_str
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.add_theme_color_override("font_color", accent_color if is_active else Color(0.45, 0.45, 0.45))
		tvb.add_child(val_lbl)

		var cap_lbl = Label.new()
		cap_lbl.text = title
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 10)
		cap_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_DIM)
		tvb.add_child(cap_lbl)

		tile.add_child(tvb)
		flow.add_child(tile)

	# 1. Club Speed
	var has_cs: bool = c_data.get("has_club_speed", false)
	var cs_val: float = c_data.get("avg_club_speed_mph", 0.0) * speed_mult
	var cs_str = ("%.1f %s" % [cs_val, s_label]) if has_cs else "---"
	add_tile.call("Club Speed", cs_str, has_cs, Color(1.0, 0.85, 0.3))

	# 2. Smash Factor
	var has_sf: bool = c_data.get("has_smash_factor", false)
	var sf_val: float = c_data.get("avg_smash_factor", 0.0)
	var sf_str = ("%.2f" % sf_val) if has_sf else "---"
	var sf_col = Color(0.35, 0.95, 0.6) if sf_val >= 1.45 else Color(1.0, 0.8, 0.3)
	add_tile.call("Smash Factor", sf_str, has_sf, sf_col)

	# 3. Angle of Attack (AoA)
	var has_aoa: bool = c_data.get("has_attack_angle", false)
	var aoa_val: float = c_data.get("avg_attack_angle", 0.0)
	var aoa_str = ("%+.1f°" % aoa_val) if has_aoa else "---"
	add_tile.call("Attack Angle", aoa_str, has_aoa, Color(0.7, 0.85, 1.0))

	# 4. Dynamic Loft
	var has_dl: bool = c_data.get("has_dynamic_loft", false)
	var dl_val: float = c_data.get("avg_dynamic_loft", 0.0)
	var dl_str = ("%.1f°" % dl_val) if has_dl else "---"
	add_tile.call("Dynamic Loft", dl_str, has_dl, Color(0.85, 0.75, 1.0))

	# 5. Launch Angle (VLA)
	var has_vla: bool = c_data.get("has_vla", false)
	var vla_val: float = c_data.get("avg_vla_deg", 0.0)
	var vla_str = ("%.1f°" % vla_val) if has_vla else "---"
	add_tile.call("Launch (VLA)", vla_str, has_vla, Color(0.85, 0.75, 1.0))

	# 6. Launch Direction (HLA)
	var has_hla: bool = c_data.get("has_hla", false)
	var hla_val: float = c_data.get("avg_hla_deg", 0.0)
	var hla_str = "---"
	if has_hla:
		if absf(hla_val) < 0.05:
			hla_str = "0.0°"
		elif hla_val > 0.0:
			hla_str = "%.1f° R" % hla_val
		else:
			hla_str = "%.1f° L" % absf(hla_val)
	add_tile.call("Launch Dir", hla_str, has_hla, Color(0.7, 0.85, 1.0))

	# 7. Club Path
	var has_cp: bool = c_data.get("has_club_path", false)
	var cp_val: float = c_data.get("avg_club_path", 0.0)
	var cp_str = "---"
	if has_cp:
		if absf(cp_val) < 0.05:
			cp_str = "0.0° Str"
		elif cp_val > 0.0:
			cp_str = "%.1f° I-O" % cp_val
		else:
			cp_str = "%.1f° O-I" % absf(cp_val)
	add_tile.call("Club Path", cp_str, has_cp, Color(0.4, 0.9, 1.0))

	# 8. Face Angle
	var has_fa: bool = c_data.get("has_face_angle", false)
	var fa_val: float = c_data.get("avg_face_angle", 0.0)
	var fa_str = "---"
	if has_fa:
		if absf(fa_val) < 0.05:
			fa_str = "0.0° Sq"
		elif fa_val > 0.0:
			fa_str = "%.1f° O" % fa_val
		else:
			fa_str = "%.1f° C" % absf(fa_val)
	add_tile.call("Face Angle", fa_str, has_fa, Color(0.4, 0.9, 1.0))

	# 9. Face to Path
	var has_ftp: bool = c_data.get("has_face_to_path", false)
	var ftp_val: float = c_data.get("avg_face_to_path", 0.0)
	var ftp_str = "---"
	if has_ftp:
		if absf(ftp_val) < 0.05:
			ftp_str = "0.0° Sq"
		elif ftp_val > 0.0:
			ftp_str = "%.1f° O" % ftp_val
		else:
			ftp_str = "%.1f° C" % absf(ftp_val)
	add_tile.call("Face to Path", ftp_str, has_ftp, Color(0.4, 0.9, 1.0))

	# 10. Back Spin
	var has_bs: bool = c_data.get("has_back_spin", false)
	var bs_val: float = c_data.get("avg_back_spin_rpm", 0.0)
	var bs_str = ("%.0f rpm" % bs_val) if has_bs else "---"
	add_tile.call("Back Spin", bs_str, has_bs, Color.WHITE)

	# 11. Side Spin
	var has_ss: bool = c_data.get("has_side_spin", false)
	var ss_val: float = c_data.get("avg_side_spin_rpm", 0.0)
	var ss_str = "---"
	if has_ss:
		if absf(ss_val) < 5.0:
			ss_str = "0 rpm"
		elif ss_val > 0.0:
			ss_str = "%.0f R" % ss_val
		else:
			ss_str = "%.0f L" % absf(ss_val)
	add_tile.call("Side Spin", ss_str, has_ss, Color.WHITE)

	# 12. Spin Axis
	var has_sa: bool = c_data.get("has_spin_axis", false)
	var sa_val: float = c_data.get("avg_spin_axis_deg", 0.0)
	var sa_str = ("%+.1f°" % sa_val) if has_sa else "---"
	var sa_col = Color(0.4, 0.9, 1.0) if absf(sa_val) <= 4.0 else (Color(1.0, 0.7, 0.3) if absf(sa_val) <= 9.0 else Color(1.0, 0.4, 0.4))
	add_tile.call("Spin Axis", sa_str, has_sa, sa_col)

	# 13. Apex (Peak Height)
	var has_ap: bool = c_data.get("has_apex", false)
	var ap_val: float = c_data.get("avg_apex_m", 0.0) * (3.28084 if is_imperial else 1.0)
	var ap_u: String = "ft" if is_imperial else "m"
	var ap_str = ("%.1f %s" % [ap_val, ap_u]) if has_ap else "---"
	add_tile.call("Apex Height", ap_str, has_ap, Color(0.35, 0.95, 0.6))

	# 14. Rollout Distance
	var has_ro: bool = c_data.get("has_rollout", false)
	var ro_val: float = c_data.get("avg_rollout_m", 0.0) * dist_mult
	var ro_str = ("%.1f %s" % [ro_val, u_label]) if has_ro else "---"
	add_tile.call("Rollout", ro_str, has_ro, Color(0.35, 0.95, 0.6))

	# 15. Hang Time
	var has_ht: bool = c_data.get("has_hang_time", false)
	var ht_val: float = c_data.get("avg_hang_time_s", 0.0)
	var ht_str = ("%.1f s" % ht_val) if has_ht else "---"
	add_tile.call("Hang Time", ht_str, has_ht, Color(0.85, 0.75, 1.0))

	# 16. Descent Angle
	var has_da: bool = c_data.get("has_descent_angle", false)
	var da_val: float = c_data.get("avg_descent_angle_deg", 0.0)
	var da_str = ("%.1f°" % da_val) if has_da else "---"
	add_tile.call("Descent Ang", da_str, has_da, Color(0.85, 0.75, 1.0))

	return panel

func _build_bag_tab(player_name: String) -> VBoxContainer:
	var tab_vbox = VBoxContainer.new()
	tab_vbox.name = "🎒 Build Bag"
	tab_vbox.add_theme_constant_override("separation", 14)
	tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var saved_bag = MultiplayerManager.get_player_bag(player_name)
	var is_using_default = [saved_bag.is_empty()]
	
	# Current active clubs map: club_code -> bool
	var active_map: Dictionary = {}
	for std_code in MultiplayerManager.STANDARD_CLUBS:
		if is_using_default[0]:
			active_map[std_code] = true
		else:
			active_map[std_code] = saved_bag.has(std_code)

	# --- Header panel with title, info, and controls ---
	var header_panel = PanelContainer.new()
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color(0.08, 0.12, 0.16, 0.7)
	hp_style.corner_radius_top_left = 8
	hp_style.corner_radius_top_right = 8
	hp_style.corner_radius_bottom_left = 8
	hp_style.corner_radius_bottom_right = 8
	hp_style.content_margin_left = 16
	hp_style.content_margin_top = 12
	hp_style.content_margin_right = 16
	hp_style.content_margin_bottom = 12
	header_panel.add_theme_stylebox_override("panel", hp_style)
	tab_vbox.add_child(header_panel)

	var hp_vbox = VBoxContainer.new()
	hp_vbox.add_theme_constant_override("separation", 10)
	header_panel.add_child(hp_vbox)

	var desc_lbl = Label.new()
	desc_lbl.text = "Select what clubs you have in your bag. In Course Play, Driving Range, and Minigames, only your chosen clubs will be available to select.\nIf no custom bag is set (or 'Reset to Default' is selected), all 20 clubs will be available by default."
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	hp_vbox.add_child(desc_lbl)

	# Toolbar: Count label, presets, save button
	var toolbar_hbox = HBoxContainer.new()
	toolbar_hbox.add_theme_constant_override("separation", 10)
	hp_vbox.add_child(toolbar_hbox)

	var count_lbl = Label.new()
	count_lbl.add_theme_font_size_override("font_size", 16)
	count_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	toolbar_hbox.add_child(count_lbl)

	var toast_lbl = Label.new()
	toast_lbl.text = ""
	toast_lbl.add_theme_font_size_override("font_size", 14)
	toast_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.45))
	toolbar_hbox.add_child(toast_lbl)

	var spacer_tb = Control.new()
	spacer_tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_hbox.add_child(spacer_tb)

	var standard_preset_btn = Button.new()
	standard_preset_btn.text = "Standard 14"
	standard_preset_btn.tooltip_text = "Quickly set standard 14-club bag"
	standard_preset_btn.custom_minimum_size = Vector2(130, 42)
	standard_preset_btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_secondary_button_style(standard_preset_btn, 4)
	toolbar_hbox.add_child(standard_preset_btn)

	var select_all_btn = Button.new()
	select_all_btn.text = "Select All"
	select_all_btn.tooltip_text = "Select all 20 clubs"
	select_all_btn.custom_minimum_size = Vector2(110, 42)
	select_all_btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_secondary_button_style(select_all_btn, 4)
	toolbar_hbox.add_child(select_all_btn)

	var clear_all_btn = Button.new()
	clear_all_btn.text = "Clear All"
	clear_all_btn.tooltip_text = "Deselect all clubs"
	clear_all_btn.custom_minimum_size = Vector2(100, 42)
	clear_all_btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_secondary_button_style(clear_all_btn, 4)
	toolbar_hbox.add_child(clear_all_btn)

	var reset_default_btn = Button.new()
	reset_default_btn.text = "Reset to Default"
	reset_default_btn.tooltip_text = "Clear custom bag setting so simulator displays all 20 clubs by default"
	reset_default_btn.custom_minimum_size = Vector2(150, 42)
	reset_default_btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_secondary_button_style(reset_default_btn, 4)
	toolbar_hbox.add_child(reset_default_btn)

	var save_btn = Button.new()
	save_btn.text = "💾 Save Bag"
	save_btn.custom_minimum_size = Vector2(130, 42)
	save_btn.add_theme_font_size_override("font_size", 15)
	ThemeManager.apply_primary_button_style(save_btn, 4)
	toolbar_hbox.add_child(save_btn)

	# --- ScrollContainer with Categorized Club Grids ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(scroll, 28)
	tab_vbox.add_child(scroll)

	var categories_vbox = VBoxContainer.new()
	categories_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	categories_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(categories_vbox)

	var club_buttons_ref: Array[Dictionary] = [] # Array of {"code": String, "btn": Button, "status_lbl": Label}

	var update_ui_state = func():
		var active_count = 0
		for c in MultiplayerManager.STANDARD_CLUBS:
			if active_map.get(c, false):
				active_count += 1
				
		if is_using_default[0]:
			count_lbl.text = "⛳ Bag Status: Default (All 20 clubs available)"
		else:
			var suffix = " (Standard Limit: 14)" if active_count == 14 else ""
			count_lbl.text = "⛳ Clubs in Bag: %d of 20%s" % [active_count, suffix]
			
		for item in club_buttons_ref:
			var code = item["code"] as String
			var btn = item["btn"] as Button
			var s_lbl = item["status_lbl"] as Label
			var is_in = active_map.get(code, false)
			
			var style = StyleBoxFlat.new()
			style.corner_radius_top_left = 8
			style.corner_radius_top_right = 8
			style.corner_radius_bottom_left = 8
			style.corner_radius_bottom_right = 8
			style.content_margin_left = 14
			style.content_margin_right = 14
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			
			if is_in:
				style.bg_color = Color(0.12, 0.28, 0.18, 0.85)
				style.border_width_left = 2
				style.border_width_top = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				style.border_color = Color(0.35, 0.85, 0.45, 0.85)
				s_lbl.text = "✓ In Bag"
				s_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
			else:
				style.bg_color = Color(0.08, 0.11, 0.14, 0.5)
				style.border_width_left = 1
				style.border_width_top = 1
				style.border_width_right = 1
				style.border_width_bottom = 1
				style.border_color = Color(0.2, 0.28, 0.35, 0.4)
				s_lbl.text = "✕ Out"
				s_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
				
			btn.add_theme_stylebox_override("normal", style)
			var style_hover = style.duplicate()
			style_hover.bg_color = style.bg_color.lightened(0.12)
			btn.add_theme_stylebox_override("hover", style_hover)
			var style_focus = style.duplicate()
			style_focus.border_color = Color(0.4, 0.85, 1.0)
			style_focus.border_width_left = 3
			style_focus.border_width_right = 3
			style_focus.border_width_top = 3
			style_focus.border_width_bottom = 3
			btn.add_theme_stylebox_override("focus", style_focus)

	var save_current_bag = func(show_toast: bool = true):
		var bag_to_save: Array[String] = []
		if not is_using_default[0]:
			for c in MultiplayerManager.STANDARD_CLUBS:
				if active_map.get(c, false):
					bag_to_save.append(c)
		MultiplayerManager.set_player_bag(player_name, bag_to_save)
		if show_toast:
			toast_lbl.text = "✓ Bag saved!"
			var t = tab_vbox.get_tree().create_timer(2.5)
			t.timeout.connect(func(): if is_instance_valid(toast_lbl): toast_lbl.text = "")

	var category_grids: Array[Array] = []
	for cat in CLUB_CATEGORIES:
		var cat_name = cat["category"] as String
		var cat_clubs = cat["clubs"] as Array
		
		var cat_section = VBoxContainer.new()
		cat_section.add_theme_constant_override("separation", 8)
		categories_vbox.add_child(cat_section)
		
		var cat_title = Label.new()
		cat_title.text = cat_name
		cat_title.add_theme_font_size_override("font_size", 18)
		cat_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		cat_section.add_child(cat_title)
		
		var grid = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_section.add_child(grid)
		
		var cat_btn_list: Array[Button] = []
		for club_info in cat_clubs:
			var code = club_info["code"] as String
			var full_name = club_info["name"] as String
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(180, 68)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.focus_mode = Control.FOCUS_ALL
			
			var btn_vbox = VBoxContainer.new()
			btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_vbox.add_theme_constant_override("separation", 2)
			btn.add_child(btn_vbox)
			
			var top_row = HBoxContainer.new()
			top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_vbox.add_child(top_row)
			
			var code_lbl = Label.new()
			code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			code_lbl.text = code
			code_lbl.add_theme_font_size_override("font_size", 20)
			code_lbl.add_theme_color_override("font_color", Color.WHITE)
			top_row.add_child(code_lbl)
			
			var spacer_code = Control.new()
			spacer_code.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spacer_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.add_child(spacer_code)
			
			var s_lbl = Label.new()
			s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_lbl.add_theme_font_size_override("font_size", 13)
			top_row.add_child(s_lbl)
			
			var name_lbl = Label.new()
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_lbl.text = full_name
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			btn_vbox.add_child(name_lbl)
			
			btn.pressed.connect(func():
				is_using_default[0] = false
				active_map[code] = not active_map.get(code, false)
				update_ui_state.call()
				save_current_bag.call(false)
			)
			
			grid.add_child(btn)
			club_buttons_ref.append({"code": code, "btn": btn, "status_lbl": s_lbl})
			cat_btn_list.append(btn)
		category_grids.append(cat_btn_list)

	# Wire focus neighbors across toolbar and categories for controller navigation
	if not club_buttons_ref.is_empty():
		var first_club_btn: Button = club_buttons_ref[0]["btn"]
		standard_preset_btn.focus_neighbor_bottom = standard_preset_btn.get_path_to(first_club_btn)
		select_all_btn.focus_neighbor_bottom = select_all_btn.get_path_to(first_club_btn)
		clear_all_btn.focus_neighbor_bottom = clear_all_btn.get_path_to(first_club_btn)
		reset_default_btn.focus_neighbor_bottom = reset_default_btn.get_path_to(first_club_btn)
		save_btn.focus_neighbor_bottom = save_btn.get_path_to(first_club_btn)
		for i in range(mini(3, club_buttons_ref.size())):
			var top_c_btn: Button = club_buttons_ref[i]["btn"]
			top_c_btn.focus_neighbor_top = top_c_btn.get_path_to(standard_preset_btn)

	for c in range(category_grids.size() - 1):
		var cur_cat_btns: Array = category_grids[c]
		var next_cat_btns: Array = category_grids[c + 1]
		if not cur_cat_btns.is_empty() and not next_cat_btns.is_empty():
			var start_idx = maxi(0, cur_cat_btns.size() - 3)
			for idx in range(start_idx, cur_cat_btns.size()):
				var b: Button = cur_cat_btns[idx]
				b.focus_neighbor_bottom = b.get_path_to(next_cat_btns[0])
			var end_idx = mini(3, next_cat_btns.size())
			for idx in range(end_idx):
				var b: Button = next_cat_btns[idx]
				b.focus_neighbor_top = b.get_path_to(cur_cat_btns.back())

	# Presets and action handlers
	standard_preset_btn.pressed.connect(func():
		is_using_default[0] = false
		for c in MultiplayerManager.STANDARD_CLUBS:
			active_map[c] = STANDARD_14_BAG.has(c)
		update_ui_state.call()
		save_current_bag.call(true)
	)

	select_all_btn.pressed.connect(func():
		is_using_default[0] = false
		for c in MultiplayerManager.STANDARD_CLUBS:
			active_map[c] = true
		update_ui_state.call()
		save_current_bag.call(true)
	)

	clear_all_btn.pressed.connect(func():
		is_using_default[0] = false
		for c in MultiplayerManager.STANDARD_CLUBS:
			active_map[c] = false
		update_ui_state.call()
		save_current_bag.call(true)
	)

	reset_default_btn.pressed.connect(func():
		is_using_default[0] = true
		for c in MultiplayerManager.STANDARD_CLUBS:
			active_map[c] = true
		update_ui_state.call()
		save_current_bag.call(true)
	)

	save_btn.pressed.connect(func():
		save_current_bag.call(true)
	)

	update_ui_state.call()
	return tab_vbox

func _email_player_profile_report(player_name: String) -> void:
	var subject = "Heckle Golf Simulator - Player Profile & Swing Report: " + player_name
	var stats = MultiplayerManager.calculate_player_stats(player_name)
	
	var body = "PLAYER PROFILE REPORT: %s\n" % player_name
	body += "=============================================\n"
	body += "Total Matches Played: %d\n" % stats.get("matches_played", 0)
	body += "Multiplayer Wins: %d | Losses: %d | Ties: %d\n" % [stats.get("wins", 0), stats.get("losses", 0), stats.get("ties", 0)]
	body += "Single Player Completed: %d\n" % stats.get("single_player_completed", 0)
	if stats.get("longest_drive", 0.0) > 0:
		body += "Longest Drive: %.1f yds\n" % stats["longest_drive"]
	if stats.get("longest_putt_ft", 0.0) > 0:
		body += "Longest Putt: %.1f ft\n" % stats["longest_putt_ft"]
	body += "\n"
	
	body += MultiplayerManager.format_player_club_stats_summary(player_name)
	body += MultiplayerManager.format_player_swing_issues_summary(player_name)
	
	var csv_content = GolfDataExporter.generate_profile_csv(player_name)
	var safe_player = GolfDataExporter.sanitize_filename(player_name)
	var date_slug = Time.get_date_string_from_system().replace("-", "")
	var attachment_basename = "%s_profile_club_stats_%s" % [safe_player, date_slug]

	var to_email = MultiplayerManager.get_player_email(player_name)
	GolfDataExporter.export_and_email(to_email, subject, body, attachment_basename, csv_content)
	print("[PlayersMenu] Opened email client with attached CSV for %s" % player_name)

func _calculate_player_stats(player_name: String) -> Dictionary:
	return MultiplayerManager.calculate_player_stats(player_name)


func _build_improvement_trends_tab(player_name: String) -> VBoxContainer:
	var tab_vbox := VBoxContainer.new()
	tab_vbox.name = "📈 Improvement Trends"
	tab_vbox.add_theme_constant_override("separation", 12)
	tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var all_stats: Dictionary = MultiplayerManager.load_global_club_stats()
	var matching_key: String = MultiplayerManager._find_matching_player_key_in_dict(all_stats, player_name)
	var p_stats: Dictionary = all_stats.get(matching_key, {}) if not matching_key.is_empty() else {}
	var skill_level: String = MultiplayerManager.get_player_skill_level(player_name)
	var is_lefty: bool = MultiplayerManager.get_player_handedness(player_name) == 1

	var available_clubs: Array[String] = []
	var all_shots: Array[Dictionary] = []
	for k in p_stats.keys():
		var k_str: String = str(k)
		if k_str.begins_with("_"):
			continue
		if p_stats[k] is Array and not (p_stats[k] as Array).is_empty():
			available_clubs.append(k_str)
			for sh in p_stats[k]:
				if sh is Dictionary:
					var copy_sh: Dictionary = (sh as Dictionary).duplicate()
					if not copy_sh.has("club") and not copy_sh.has("Club"):
						copy_sh["club"] = k_str
					all_shots.append(copy_sh)

	# Header / Club Filter Bar
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	tab_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "📈 Rolling Trends, D-Plane & Active Focus Plan"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_GOLD)
	top_bar.add_child(title_lbl)

	var club_sel := OptionButton.new()
	club_sel.custom_minimum_size = Vector2(180, 36)
	club_sel.add_item("All Clubs (%d shots)" % all_shots.size())
	club_sel.set_item_metadata(0, "All")
	for i in range(available_clubs.size()):
		var clb: String = available_clubs[i]
		club_sel.add_item("%s (%d)" % [clb, (p_stats[clb] as Array).size()])
		club_sel.set_item_metadata(i + 1, clb)
	top_bar.add_child(club_sel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_scroll_container_style(scroll, 28)
	tab_vbox.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	var populate := func(club_filter: String) -> void:
		for ch in body.get_children():
			body.remove_child(ch)
			ch.queue_free()

		var target_shots: Array[Dictionary] = []
		if club_filter == "All":
			target_shots = all_shots
		elif p_stats.has(club_filter) and p_stats[club_filter] is Array:
			for sh in p_stats[club_filter]:
				if sh is Dictionary:
					var cs: Dictionary = (sh as Dictionary).duplicate()
					if not cs.has("club") and not cs.has("Club"):
						cs["club"] = club_filter
					target_shots.append(cs)

		if target_shots.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "No shot telemetry recorded yet for %s. Hit balls on the Driving Range or Course Play to unlock rolling trends, D-Plane flight matrices, and guided coaching milestones." % club_filter
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty_lbl.add_theme_color_override("font_color", Color(0.68, 0.74, 0.84))
			body.add_child(empty_lbl)
			return

		var eff_club: String = str(target_shots[-1].get("club", "Driver")) if club_filter == "All" else club_filter
		var analysis: Dictionary = ShotAnalyticsEngineScript.analyze_shot_group(target_shots, eff_club, skill_level, is_lefty)
		var recent: Dictionary = analysis.get("recent", {})
		var focus: Dictionary = analysis.get("active_focus", {})
		var loss: Dictionary = analysis.get("distance_loss", {})
		var aim: Dictionary = recent.get("aim_shift", {})
		var bf: Dictionary = recent.get("ball_flight", {})
		var bench: Dictionary = ShotAnalyticsEngineScript.GolfSwingAnalyzer.get_benchmark(eff_club, skill_level)

		# 1. Active "One-Thing Focus" Hero Card & Set Active Goal Button
		var hero := PanelContainer.new()
		hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0.08, 0.14, 0.21, 0.92)
		hs.border_width_left = 4
		hs.border_color = Color(0.24, 0.88, 0.58, 0.95)
		hs.set_corner_radius_all(8)
		hs.set_content_margin_all(14)
		hero.add_theme_stylebox_override("panel", hs)
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 6)

		var hero_top := HBoxContainer.new()
		hero_top.add_theme_constant_override("separation", 10)
		var hero_lbl := Label.new()
		hero_lbl.text = "🎯 Priority Focus: %s (Est. -%.1f strokes/rd)" % [str(focus.get("title", "Ball Flight Stability")), float(focus.get("estimated_strokes_saved", 0.5))]
		hero_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_lbl.add_theme_font_size_override("font_size", 16)
		hero_lbl.add_theme_color_override("font_color", Color(0.42, 0.96, 0.68))
		hero_top.add_child(hero_lbl)

		var existing_goal: Dictionary = MultiplayerManager.get_player_coaching_goal(player_name)
		var goal_matches: bool = not existing_goal.is_empty() and str(existing_goal.get("issue_key", "")) == str(focus.get("issue_key", ""))
		var set_goal_btn := Button.new()
		set_goal_btn.text = "✅ Active Range Goal (%d reps)" % int(existing_goal.get("total_reps", 0)) if goal_matches else "🎯 Set as Active Focus Goal"
		ThemeManager.apply_primary_button_style(set_goal_btn, 4)
		set_goal_btn.pressed.connect(func():
			MultiplayerManager.set_player_coaching_goal(player_name, focus)
			set_goal_btn.text = "✅ Active Range Goal Set!"
		)
		hero_top.add_child(set_goal_btn)
		hv.add_child(hero_top)

		var why_lbl := Label.new()
		why_lbl.text = str(focus.get("why", ""))
		why_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
		hv.add_child(why_lbl)

		var milestones: Array = focus.get("milestones", []) if focus.get("milestones", null) is Array else []
		for ms in milestones:
			if ms is Dictionary:
				var st_status: String = str(ms.get("status", "upcoming"))
				var icon: String = "✅" if st_status == "achieved" else ("▶" if st_status == "active" else "○")
				var mlbl := Label.new()
				mlbl.text = "  %s Step %s: %s (%s)" % [icon, str(ms.get("step", "")), str(ms.get("label", "")), str(ms.get("pass_rule", ""))]
				mlbl.add_theme_font_size_override("font_size", 13)
				mlbl.add_theme_color_override("font_color", Color(0.48, 0.96, 0.72) if st_status == "achieved" else (Color(0.55, 0.85, 1.0) if st_status == "active" else Color(0.65, 0.72, 0.82)))
				hv.add_child(mlbl)

		hero.add_child(hv)
		body.add_child(hero)

		# 2. KPI Bullet Gauges
		var gauge_panel := PanelContainer.new()
		var gp_style := StyleBoxFlat.new()
		gp_style.bg_color = Color(0.09, 0.12, 0.18, 0.88)
		gp_style.set_corner_radius_all(8)
		gp_style.set_content_margin_all(12)
		gauge_panel.add_theme_stylebox_override("panel", gp_style)
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 6)

		var corridor_y: float = float(recent.get("corridor_yds", 12.0))
		gv.add_child(AnalyticsVisualWidgetsScript.create_bullet_gauge(
			"Avg Miss Offline",
			float(recent.get("avg_abs_offline", 0.0)),
			0.0, corridor_y, 0.0, maxf(corridor_y * 2.5, float(recent.get("avg_abs_offline", 0.0)) + 4.0), "yds"
		))
		var avg_sm: float = float(recent.get("avg_smash", NAN))
		if not is_nan(avg_sm):
			var sm_min: float = float(bench.get("smash_min", 1.38))
			var sm_max: float = float(bench.get("smash_max", 1.48))
			gv.add_child(AnalyticsVisualWidgetsScript.create_bullet_gauge(
				"Smash Factor", avg_sm, sm_min, sm_max, maxf(0.9, sm_min - 0.18), minf(1.52, sm_max + 0.06), ""
			))
		var avg_ftp: float = float(recent.get("avg_ftp", NAN))
		if not is_nan(avg_ftp):
			gv.add_child(AnalyticsVisualWidgetsScript.create_bullet_gauge(
				"Face-to-Path", avg_ftp, -2.0, 2.0, -8.0, 8.0, "°"
			))
		gauge_panel.add_child(gv)
		body.add_child(gauge_panel)

		# 3. D-Plane Matrix + Trend Sparklines
		var visuals_row := HBoxContainer.new()
		visuals_row.add_theme_constant_override("separation", 12)
		visuals_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		visuals_row.add_child(AnalyticsVisualWidgetsScript.create_d_plane_matrix(
			bf.get("counts", {}),
			int(bf.get("total_classified", target_shots.size())),
			is_lefty,
			Vector2(280, 185)
		))

		var spark_col := VBoxContainer.new()
		spark_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spark_col.add_theme_constant_override("separation", 8)
		var norm_shots: Array = analysis.get("normalized_shots", [])
		var off_pts: Array = []
		var sm_pts: Array = []
		for ns in norm_shots:
			if ns is Dictionary:
				off_pts.append(float(ns.get("abs_offline_yds", 0.0)))
				var sm_val: float = float(ns.get("smash", NAN))
				if not is_nan(sm_val):
					sm_pts.append(sm_val)
		spark_col.add_child(AnalyticsVisualWidgetsScript.create_trend_sparkline(off_pts, "Offline Dispersion Trend (Abs yds)", "yd", 0.0, corridor_y, Vector2(260, 110)))
		if sm_pts.size() >= 2:
			spark_col.add_child(AnalyticsVisualWidgetsScript.create_trend_sparkline(sm_pts, "Smash Factor Trend", "", float(bench.get("smash_min", 1.38)), float(bench.get("smash_max", 1.48)), Vector2(260, 110)))
		visuals_row.add_child(spark_col)
		body.add_child(visuals_row)

		# 4. Distance Loss & Aim Shift Summary
		var foot_lbl := Label.new()
		foot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var txt_parts: Array[String] = []
		if bool(loss.get("has_data", false)) and float(loss.get("total_lost_yds", 0.0)) >= 2.0:
			txt_parts.append("📏 Distance Recovery Opportunity: %.1f potential carry yds vs %.1f current (Strike: %.1f · Spin/Launch: %.1f · Curve: %.1f yds)" % [
				float(loss.get("potential_carry_yds", 0.0)), float(recent.get("avg_carry_yds", 0.0)),
				float(loss.get("smash_loss_yds", 0.0)), float(loss.get("launch_spin_loss_yds", 0.0)), float(loss.get("curve_loss_yds", 0.0))
			])
		var sh_yds: float = float(aim.get("shift_yds", 0.0))
		var sh_dir: String = str(aim.get("shift_dir", ""))
		if not sh_dir.is_empty() and sh_yds >= 2.0:
			txt_parts.append("🧭 Quick Scoring Fix: Shifting aim %.1f yds %s projects +%d%% fairway/corridor hits (to %d%%)." % [sh_yds, sh_dir, int(aim.get("gain_pct", 0)), int(aim.get("projected_pct_in_corridor", 0))])
		if txt_parts.is_empty():
			txt_parts.append("✨ Metrics track within expected target corridors for %s." % _skill_key_to_display(skill_level))
		foot_lbl.text = "\n".join(txt_parts)
		foot_lbl.add_theme_color_override("font_color", Color(0.84, 0.91, 0.98))
		body.add_child(foot_lbl)

	club_sel.item_selected.connect(func(idx: int):
		var meta: String = str(club_sel.get_item_metadata(idx))
		populate.call(meta)
	)
	populate.call("All")
	return tab_vbox
