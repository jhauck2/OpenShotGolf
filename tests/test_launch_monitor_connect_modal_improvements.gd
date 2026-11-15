extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=======================================================")
	print("  RUNNING LAUNCH MONITOR CONNECT MODAL IMPROVEMENTS TEST ")
	print("=======================================================")

	# 1. Test ThemeManager.apply_checkbox_style
	var cb = CheckBox.new()
	root.add_child(cb)
	ThemeManager.apply_checkbox_style(cb)
	assert(cb.has_theme_icon_override("unchecked"), "CheckBox must have unchecked icon override")
	assert(cb.has_theme_icon_override("checked"), "CheckBox must have checked icon override")
	assert(cb.get_theme_icon("unchecked") != null, "Unchecked icon texture must not be null")
	assert(cb.get_theme_icon("checked") != null, "Checked icon texture must not be null")
	cb.queue_free()
	print("  PASS: ThemeManager.apply_checkbox_style creates high-contrast icons.")

	# 2. Test LaunchMonitorConnectModal scene & styling
	var scene = load("res://UI/LaunchMonitorConnectModal/launch_monitor_connect_modal.tscn")
	assert(scene != null, "launch_monitor_connect_modal.tscn must load successfully")
	var modal = scene.instantiate()
	assert(modal != null, "Modal must instantiate successfully")
	root.add_child(modal)
	await process_frame

	var tab_container = modal.get_node("%TabContainer") as TabContainer
	assert(tab_container != null, "TabContainer must exist")
	assert(tab_container.clip_tabs == false, "TabContainer clip_tabs must be false")
	assert(tab_container.get_tab_count() == 4, "TabContainer must have 4 tabs")

	# Verify tab titles fit concisely without arrows
	assert(tab_container.get_tab_title(0) == "📶 Bluetooth", "Tab 0 must be '📶 Bluetooth'")
	assert(tab_container.get_tab_title(1) == "🌐 Other (GSPro)", "Tab 1 must be '🌐 Other (GSPro)'")
	assert(tab_container.get_tab_title(2) == "🔐 Encrypted BT", "Tab 2 must be '🔐 Encrypted BT'")
	assert(tab_container.get_tab_title(3) == "⛳ Bushnell (FSX)", "Tab 3 must be '⛳ Bushnell (FSX)'")
	print("  PASS: Tab titles are clean, concise, and clip_tabs is disabled.")

	# Verify remember device checkbox
	var remember_cb = modal.get_node("%RememberDeviceCheckBox") as CheckBox
	assert(remember_cb != null, "RememberDeviceCheckBox must exist")
	assert(remember_cb.has_theme_icon_override("unchecked"), "RememberDeviceCheckBox must have custom unchecked icon")
	assert(remember_cb.has_theme_icon_override("checked"), "RememberDeviceCheckBox must have custom checked icon")
	print("  PASS: RememberDeviceCheckBox has high-contrast icon styling applied.")

	# 3. Test status display for 'Detecting'
	var lm = root.get_node_or_null("/root/LaunchMonitorManager")
	if lm != null:
		lm.status = "Detecting"
		modal._update_status_display()
	else:
		modal.set("_launch_monitor", modal)
		modal.set("status", "Detecting")
		modal._update_status_display()

	var status_label = modal.get_node("%StatusLabel") as Label
	assert(status_label != null, "StatusLabel must exist")
	assert(status_label.text == "Status: Detecting", "Status text must be 'Status: Detecting'")
	var color = status_label.get_theme_color("font_color")
	var expected_green = Color(0.35, 0.85, 0.45)
	assert(abs(color.r - expected_green.r) < 0.05 and abs(color.g - expected_green.g) < 0.05 and abs(color.b - expected_green.b) < 0.05, "Status: Detecting must be displayed in green, got: %s" % str(color))
	print("  PASS: 'Detecting' status shows in green: %s" % str(color))

	# Clean up
	modal.queue_free()
	await process_frame

	print("=======================================================")
	print("  ALL TESTS PASSED!                                    ")
	print("=======================================================\n")
	quit(0)
