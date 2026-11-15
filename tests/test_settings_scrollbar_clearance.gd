extends SceneTree

var _tested := false

func _initialize() -> void:
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_tests()

func _run_tests() -> void:
	print("=== Running Settings Scrollbar Clearance Tests ===")

	var settings_scene = load("res://UI/Settings/RangeSettings/range_settings.tscn")
	assert(settings_scene != null, "range_settings.tscn must load successfully")
	var inst = settings_scene.instantiate()
	root.add_child(inst)
	current_scene = inst

	await process_frame
	await process_frame

	var tab_container = inst.get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	assert(tab_container != null, "TabContainer must exist")

	var is_mob: bool = MobilePerformance.is_mobile()
	var min_expected_margin: int = 72 if is_mob else 40
	print("Device is_mobile: %s, requiring minimum right margin of %d px" % [str(is_mob), min_expected_margin])

	var tabs_tested: int = 0
	for child in tab_container.get_children():
		if not (child is ScrollContainer):
			continue
		var scroll: ScrollContainer = child as ScrollContainer
		var tab_name: String = scroll.name
		var v_bar: VScrollBar = scroll.get_v_scroll_bar()
		assert(v_bar != null, "ScrollContainer '%s' must have a VScrollBar" % tab_name)

		var v_bar_width: float = v_bar.custom_minimum_size.x
		var margin_container: MarginContainer = null
		for c in scroll.get_children():
			if c is MarginContainer:
				margin_container = c as MarginContainer
				break

		assert(margin_container != null, "ScrollContainer '%s' must have a child MarginContainer" % tab_name)
		var actual_margin_right: int = margin_container.get_theme_constant("margin_right")

		print("Tab '%s': scrollbar width = %.1f px, margin_right = %d px (clearance = %.1f px)" % [
			tab_name, v_bar_width, actual_margin_right, actual_margin_right - v_bar_width
		])

		assert(actual_margin_right >= min_expected_margin,
			"Tab '%s' margin_right (%d) must be >= %d to prevent scrollbar overlap" % [tab_name, actual_margin_right, min_expected_margin])
		assert(actual_margin_right > v_bar_width,
			"Tab '%s' margin_right (%d) must exceed scrollbar width (%.1f) with positive clearance" % [tab_name, actual_margin_right, v_bar_width])
		assert(actual_margin_right - v_bar_width >= 16.0,
			"Tab '%s' clearance (%f) must be at least 16px to prevent buttons/toggles touching the scrollbar" % [tab_name, actual_margin_right - v_bar_width])

		tabs_tested += 1

	assert(tabs_tested >= 7, "Must test at least 7 tabs (Gameplay, Stats, Camera, LaunchMonitor, Announcer, Keybindings, DeveloperDebug), tested %d" % tabs_tested)
	print("PASS: Verified %d tabs with adequate scrollbar clearance." % tabs_tested)

	# Test simulated touch / mobile scrollbar width (56px)
	print("\n--- Test Simulated Touch/Mobile Scrollbar (56px width) ---")
	for child in tab_container.get_children():
		if not (child is ScrollContainer):
			continue
		var scroll: ScrollContainer = child as ScrollContainer
		var v_bar: VScrollBar = scroll.get_v_scroll_bar()
		v_bar.custom_minimum_size = Vector2(56, 0)
		var expected_mobile_margin = inst._get_tab_scroll_margin_right(scroll)

		var margin_container: MarginContainer = null
		for c in scroll.get_children():
			if c is MarginContainer:
				margin_container = c as MarginContainer
				break

		margin_container.add_theme_constant_override("margin_right", expected_mobile_margin)
		var actual_margin: int = margin_container.get_theme_constant("margin_right")
		var clearance: float = actual_margin - v_bar.custom_minimum_size.x
		print("Mobile Sim Tab '%s': scrollbar width = %.1f px, margin_right = %d px (clearance = %.1f px)" % [
			scroll.name, v_bar.custom_minimum_size.x, actual_margin, clearance
		])
		assert(actual_margin >= 72, "Mobile simulated tab margin must be >= 72, got %d" % actual_margin)
		assert(clearance >= 16.0, "Mobile simulated clearance must be >= 16px, got %f" % clearance)

	print("PASS: Verified all tabs adapt with >= 16px clearance for touch/mobile 56px scrollbars.")

	inst.queue_free()
	await process_frame
	print("=== All Settings Scrollbar Clearance Tests PASSED ===")
	quit(0)
