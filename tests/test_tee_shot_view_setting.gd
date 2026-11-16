extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var range_settings_script = load("res://Utils/Settings/range_settings.gd")
	assert(range_settings_script != null, "RangeSettings script must load")

	var default_settings = range_settings_script.new()
	assert(default_settings.tee_shot_view_enabled.value == false, "Tee-shot view must be OFF by default")
	assert(default_settings.settings.has("tee_shot_view_enabled"), "Tee-shot view must be registered in RangeSettings")

	# Verify GlobalSettings persistence round-trip without clobbering existing user config
	var gs = root.get_node_or_null("GlobalSettings")
	assert(gs != null, "GlobalSettings autoload must exist")

	var cfg_path := "user://global_settings.cfg"
	var had_existing := FileAccess.file_exists(cfg_path)
	var backup_bytes := FileAccess.get_file_as_bytes(cfg_path) if had_existing else PackedByteArray()
	var prev_suppress: bool = gs.suppress_save
	var prev_val: bool = bool(gs.range_settings.tee_shot_view_enabled.value)

	gs.suppress_save = false
	gs.range_settings.tee_shot_view_enabled.set_value(true)
	gs.save_settings()

	# Reset in memory without overwriting disk, then reload from disk
	gs.suppress_save = true
	gs.range_settings.tee_shot_view_enabled.set_value(false)
	gs.load_settings()
	assert(bool(gs.range_settings.tee_shot_view_enabled.value) == true, "Enabled tee-shot view setting must persist across save/load")

	# Restore previous state
	gs.suppress_save = true
	gs.range_settings.tee_shot_view_enabled.set_value(prev_val)
	gs.suppress_save = prev_suppress
	if had_existing:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup_bytes)
			f.close()
	elif FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))

	print("PASS: Tee-shot view defaults to OFF and persists when toggled.")
	quit(0)
