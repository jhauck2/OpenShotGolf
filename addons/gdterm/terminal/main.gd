@tool
extends MarginContainer

func set_active(flag : bool):
	$term_container.set_active(flag)

func theme_changed():
	$term_container.apply_themes()

func set_initial_cmds(cmds):
	$term_container.set_initial_cmds(cmds)

func set_alt_meta(setting):
	$term_container.set_alt_meta(setting)

func set_font_setting(font, font_size):
	$term_container.set_font_setting(font, font_size)

func _on_theme_changed():
	theme_changed()
