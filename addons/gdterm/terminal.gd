@tool
extends EditorPlugin

const MainPanel = preload("res://addons/gdterm/terminal/border.tscn")
const InactivePanel = preload("res://addons/gdterm/terminal/inactive.tscn")
const BottomPanel = preload("res://addons/gdterm/terminal/main.tscn")

var main_panel_instance = null
var bottom_panel_instance = null

var current_theme = null
var current_layout = null
var active_theme = null
var active_initial_cmds = null
var active_alt_meta = false
var active_font : Font = null
var active_font_size : int = 14

const THEME_EDITOR : int = 0
const THEME_DARK   : int = 1
const THEME_LIGHT  : int = 2

var theme_property_info = {
	"name": "gdterm/theme",
	"type": TYPE_INT,
	"hint": PROPERTY_HINT_ENUM,
	"hint_string": "editor,dark,light"
}

const LAYOUT_MAIN   : int = 0
const LAYOUT_BOTTOM : int = 1
const LAYOUT_BOTH   : int = 2

var layout_property_info = {
	"name": "gdterm/layout",
	"type": TYPE_INT,
	"hint": PROPERTY_HINT_ENUM,
	"hint_string": "main,bottom,both"
}

var initial_cmds_info = {
	"name": "gdterm/initial_commands",
	"type": TYPE_STRING,
	"hint": PROPERTY_HINT_MULTILINE_TEXT,
}

var send_alt_meta_as_esc_info = {
	"name": "gdterm/send_alt_meta_as_esc",
	"type": TYPE_BOOL,
}

var font_info = {
	"name": "gdterm/font",
	"type": TYPE_STRING,
	"hint" : PROPERTY_HINT_GLOBAL_FILE,
	"hint_string" : "*.ttf,*.otf,*.woff,*.woff2,*.pfb,*.pfm"
}

var font_size_info = {
	"name": "gdterm/font_size",
	"type": TYPE_INT,
	"hint" : PROPERTY_HINT_RANGE,
	"hint_string" : "8,64,1"
}

func _on_settings_changed():
	var settings = EditorInterface.get_editor_settings()
	
	var theme = THEME_EDITOR
	if settings.has_setting("gdterm/theme"):
		theme = settings.get_setting("gdterm/theme")
	var layout = LAYOUT_MAIN
	if settings.has_setting("gdterm/layout"):
		layout = settings.get_setting("gdterm/layout")
	var initial_cmds = String()
	if settings.has_setting("gdterm/initial_commands"):
		initial_cmds = settings.get_setting("gdterm/initial_commands")
	var send_alt_meta_as_esc = false
	if settings.has_setting("gdterm/send_alt_meta_as_esc"):
		send_alt_meta_as_esc = settings.get_setting("gdterm/send_alt_meta_as_esc")
	var font : FontFile = null
	if settings.has_setting("gdterm/font"):
		var font_name = settings.get_setting("gdterm/font")
		if not font_name.is_empty():
			font = FontFile.new()
			var err = font.load_dynamic_font(font_name)
			if err != Error.OK:
				print("Unable to load %s: (%s)" % [font_name, err])
				font = null
	var font_size : int = 14
	if settings.has_setting("gdterm/font_size"):
		font_size = settings.get_setting("gdterm/font_size")
	_apply_theme(theme)
	_apply_initial_cmds(initial_cmds)
	_apply_term_alt_meta_setting(send_alt_meta_as_esc)
	_apply_font_setting(font, font_size)
	_apply_layout(layout)

func _apply_theme(theme):
	if current_theme != theme:
		if theme == THEME_EDITOR:
			var editor_theme = Theme.new()
			var settings = EditorInterface.get_editor_settings()
			var background = settings.get_setting("text_editor/theme/highlighting/background_color")
			var foreground = settings.get_setting("text_editor/theme/highlighting/text_color")
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "background", "GDTerm", background)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "foreground", "GDTerm", foreground)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "black", "GDTerm", Color.BLACK)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "white", "GDTerm", Color.WHITE.darkened(.2))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "red", "GDTerm", Color.FIREBRICK)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "green", "GDTerm", Color.WEB_GREEN)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "blue", "GDTerm", Color.CORNFLOWER_BLUE)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "yellow", "GDTerm", Color.GOLDENROD.darkened(0.2))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "cyan", "GDTerm", Color.DARK_CYAN)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "magenta", "GDTerm", Color.DARK_MAGENTA)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_black", "GDTerm", Color(0.5, 0.5, 0.5))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_white", "GDTerm", Color.WHITE)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_red", "GDTerm", Color.FIREBRICK.lightened(0.2))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_green", "GDTerm", Color.WEB_GREEN.lightened(0.2))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_blue", "GDTerm", Color.CORNFLOWER_BLUE.lightened(0.2))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_yellow", "GDTerm", Color.GOLDENROD)
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_cyan", "GDTerm", Color.DARK_CYAN.lightened(0.2))
			editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "bright_magenta", "GDTerm", Color.DARK_MAGENTA.lightened(0.2))
			active_theme = editor_theme
		elif theme == THEME_LIGHT:
			active_theme = preload("res://addons/gdterm/themes/light.tres")
		elif theme == THEME_DARK:
			active_theme = preload("res://addons/gdterm/themes/dark.tres")
		if main_panel_instance != null:
			main_panel_instance.get_main().set_theme(active_theme)
			main_panel_instance.get_main().theme_changed()
		if bottom_panel_instance != null:
			bottom_panel_instance.set_theme(active_theme)
			bottom_panel_instance.theme_changed()
		current_theme = theme
	
func _apply_layout(layout):
	if current_layout != layout:
		if layout == LAYOUT_MAIN or layout == LAYOUT_BOTH:
			var show_main = false
			if current_layout == LAYOUT_BOTTOM:
				if main_panel_instance != null:
					show_main = main_panel_instance.visible
					EditorInterface.get_editor_main_screen().remove_child(main_panel_instance)
					main_panel_instance.queue_free()
					main_panel_instance = null
				else:
					printerr("Must restart editor using Project->Reload Current Project for Terminal to be displayed in the main editor window")
					return
			if main_panel_instance == null:
				main_panel_instance = MainPanel.instantiate()
				if active_theme != null:
					main_panel_instance.get_main().set_theme(active_theme)
				main_panel_instance.get_main().set_initial_cmds(active_initial_cmds)
				main_panel_instance.get_main().set_alt_meta(active_alt_meta)
				main_panel_instance.get_main().set_font_setting(active_font, active_font_size)
				main_panel_instance.get_main().set_active(true)
				main_panel_instance.visible = show_main
				EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
		if layout == LAYOUT_BOTTOM or layout == LAYOUT_BOTH:
			if bottom_panel_instance == null:
				bottom_panel_instance = BottomPanel.instantiate()
				if active_theme != null:
					bottom_panel_instance.set_theme(active_theme)
					bottom_panel_instance.set_initial_cmds(active_initial_cmds)
					bottom_panel_instance.set_alt_meta(active_alt_meta)
					bottom_panel_instance.set_font_setting(active_font, active_font_size)
					bottom_panel_instance.set_active(true)
					bottom_panel_instance.theme_changed()
				add_control_to_bottom_panel(bottom_panel_instance, "Terminal")
		if layout == LAYOUT_MAIN:
			if bottom_panel_instance != null:
				remove_control_from_bottom_panel(bottom_panel_instance)
				bottom_panel_instance.queue_free()
				bottom_panel_instance = null
		if layout == LAYOUT_BOTTOM:
			if main_panel_instance != null:
				EditorInterface.get_editor_main_screen().remove_child(main_panel_instance)
				main_panel_instance.queue_free()
				main_panel_instance = InactivePanel.instantiate()
				EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
		current_layout = layout

func _apply_initial_cmds(cmds):
	if active_initial_cmds != cmds:
		if main_panel_instance != null:
			main_panel_instance.get_main().set_initial_cmds(cmds)
		if bottom_panel_instance != null:
			bottom_panel_instance.set_initial_cmds(cmds)
		active_initial_cmds = cmds

func _apply_term_alt_meta_setting(setting):
	if active_alt_meta != setting:
		if main_panel_instance != null:
			main_panel_instance.get_main().set_alt_meta(setting)
		if bottom_panel_instance != null:
			bottom_panel_instance.set_alt_meta(setting)
		active_alt_meta = setting

func _apply_font_setting(font : Font, font_size : int):
	if active_font != font or active_font_size != font_size:
		if main_panel_instance != null:
			main_panel_instance.get_main().set_font_setting(font, font_size)
		if bottom_panel_instance != null:
			bottom_panel_instance.set_font_setting(font, font_size)
		active_font = font
		active_font_size = font_size

func _enter_tree() -> void:
	var settings = EditorInterface.get_editor_settings()
	
	var theme = THEME_EDITOR
	if settings.has_setting("gdterm/theme"):
		theme = settings.get_setting("gdterm/theme")
	else:
		settings.set_setting("gdterm/theme", theme)
		theme = settings.get_setting("gdterm/theme")
	_apply_theme(theme)
	
	var layout = LAYOUT_MAIN
	if settings.has_setting("gdterm/layout"):
		layout = settings.get_setting("gdterm/layout")
	else:
		settings.set_setting("gdterm/layout", layout)
		layout = settings.get_setting("gdterm/layout")
	_apply_layout(layout)

	var font_setting : FontFile = null
	if settings.has_setting("gdterm/font"):
		var font_setting_name : String = settings.get_setting("gdterm/font")
		if not font_setting_name.is_empty(): 
			font_setting = FontFile.new()
			var err = font_setting.load_dynamic_font(font_setting_name)
			if err != Error.OK:
				print("Unable to load font %s (%s)" % [font_setting_name, err])
				font_setting = null
	else:
		settings.set_setting("gdterm/font", "")

	var font_size_setting : int = 14
	if settings.has_setting("gdterm/font_size"):
		font_size_setting = settings.get_setting("gdterm/font_size")
	else:
		settings.set_setting("gdterm/font_size", font_size_setting)
	_apply_font_setting(font_setting, font_size_setting)

	var alt_meta_setting = false
	if settings.has_setting("gdterm/send_alt_meta_as_esc"):
		alt_meta_setting = settings.get_setting("gdterm/send_alt_meta_as_esc")
	else:
		settings.set_setting("gdterm/send_alt_meta_as_esc", alt_meta_setting)
	_apply_term_alt_meta_setting(alt_meta_setting)

	# Make sure shows as enum
	settings.add_property_info(theme_property_info)
	settings.add_property_info(layout_property_info)
	settings.add_property_info(initial_cmds_info)
	settings.add_property_info(send_alt_meta_as_esc_info)
	settings.add_property_info(font_info)
	settings.add_property_info(font_size_info)
	settings.settings_changed.connect(_on_settings_changed)
	
	# All the initial settings have been made, so make it active
	if main_panel_instance != null:
		main_panel_instance.get_main().set_active(true)
	if bottom_panel_instance != null:
		bottom_panel_instance.set_active(true)

	var initial_cmds = String()
	if settings.has_setting("gdterm/initial_commands"):
		initial_cmds = settings.get_setting("gdterm/initial_commands")
	else:
		settings.set_setting("gdterm/initial_commands", initial_cmds)
	_apply_initial_cmds(initial_cmds)

	# Hide the main panel. Very much required.
	_make_visible(false)

func _exit_tree() -> void:
	if main_panel_instance:
		main_panel_instance.queue_free()
	if bottom_panel_instance:
		remove_control_from_bottom_panel(bottom_panel_instance)
		bottom_panel_instance.queue_free()

func _has_main_screen():
	var settings = EditorInterface.get_editor_settings()
	if settings.has_setting("gdterm/layout"):
		var layout = settings.get_setting("gdterm/layout")
		if layout == LAYOUT_MAIN or layout == LAYOUT_BOTH:
			return true
		else:
			return false
	else:
		settings.set_setting("gdterm/layout", 0)
		return true

func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible

func _get_plugin_name():
	return "Terminal"

func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
