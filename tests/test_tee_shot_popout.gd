extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		printerr("FAIL: " + msg)
		quit(1)
		return false
	return true


func _run_test() -> void:
	var view_script = load("res://UI/tee_shot_view.gd")
	if not _check(view_script != null, "Tee shot view script must load"):
		return

	var gs := root.get_node_or_null("GlobalSettings")
	if not _check(gs != null, "GlobalSettings autoload must exist"):
		return

	# Preserve user settings and restore at the end
	var orig_detached: bool = bool(gs.range_settings.tee_shot_view_detached.value)
	var orig_x: int = int(gs.range_settings.tee_shot_window_position_x.value)
	var orig_y: int = int(gs.range_settings.tee_shot_window_position_y.value)
	var orig_w: int = int(gs.range_settings.tee_shot_window_width.value)
	var orig_h: int = int(gs.range_settings.tee_shot_window_height.value)

	gs.range_settings.tee_shot_view_detached.set_value(false)
	gs.range_settings.tee_shot_window_position_x.set_value(-1)
	gs.range_settings.tee_shot_window_position_y.set_value(-1)
	gs.range_settings.tee_shot_window_width.set_value(480)
	gs.range_settings.tee_shot_window_height.set_value(640)

	var main_camera := Camera3D.new()
	main_camera.cull_mask = 3
	root.add_child(main_camera)

	var view = view_script.new()
	view._allow_detach_for_test = true
	root.add_child(view)
	view.set_main_camera(main_camera)
	view.set_minimap_rect(Rect2(Vector2(30.0, 60.0), Vector2(288.0, 333.0)))

	if not _check(not view.is_popped_out(), "Tee shot view must start docked"):
		return
	if not _check(not view.is_shot_active(), "Tee shot view must start inactive"):
		return

	var tee := Vector3(12.0, 0.0, -8.0)
	var target := Vector3(20.0, 0.0, -220.0)
	view.show_shot(tee, tee + Vector3(0.0, 2.0, -1.0), target)

	if not _check(view._split_mode and view.visible, "Docked tee shot must enter split mode"):
		return
	if not _check(view.is_shot_active(), "Shot must be active after show_shot"):
		return

	# Pop out mid-shot
	view.pop_out(true)
	if not _check(view.is_popped_out(), "View must be popped out after pop_out()"):
		return
	if not _check(not view._split_mode and not view.visible, "Main split overlay must close when popped out"):
		return
	if not _check(main_camera.cull_mask == 3, "Main camera must be restored when popped out"):
		return
	if not _check(view._popout_window != null and is_instance_valid(view._popout_window), "Pop-out window must exist"):
		return
	if not _check(view._popout_window.visible, "Pop-out window must be visible"):
		return
	if not _check(view._shot_panel.get_parent() == view._popout_window, "ShotPanel must be reparented to pop-out window"):
		return
	if not _check(view._popout_button.text == "↙ Dock", "Button must switch to Dock when popped out"):
		return
	if not _check(bool(gs.range_settings.tee_shot_view_detached.value), "Detached setting must be remembered"):
		return

	# Simulate dragging & resizing the pop-out window, then ending the shot
	view._popout_window.position = Vector2i(220, 140)
	view._popout_window.size = Vector2i(540, 720)
	view.hide_shot(false)

	if not _check(not view.is_shot_active(), "Shot must be inactive after hide_shot"):
		return
	if not _check(view.is_popped_out() and view._popout_window.visible, "Pop-out window must stay open between shots"):
		return
	if not _check(int(gs.range_settings.tee_shot_window_position_x.value) == 220, "Pop-out window X position must be saved"):
		return
	if not _check(int(gs.range_settings.tee_shot_window_position_y.value) == 140, "Pop-out window Y position must be saved"):
		return
	if not _check(int(gs.range_settings.tee_shot_window_width.value) == 540, "Pop-out window width must be saved"):
		return
	if not _check(int(gs.range_settings.tee_shot_window_height.value) == 720, "Pop-out window height must be saved"):
		return

	# Next tee shot while already popped out must stay popped out and not split
	view.show_shot(tee, tee + Vector3(0.0, 2.0, -1.0), target)
	if not _check(not view._split_mode and not view.visible, "Subsequent shot while popped out must not enter split mode"):
		return
	if not _check(view.is_popped_out() and view._popout_window.visible, "Pop-out window must remain open on subsequent shot"):
		return

	view.hide_shot(true)
	view.queue_free()
	await process_frame

	# New instance (simulating new round/session) must remember popped-out state and rect
	var view2 = view_script.new()
	view2._allow_detach_for_test = true
	root.add_child(view2)
	view2.set_main_camera(main_camera)
	view2.set_minimap_rect(Rect2(Vector2(30.0, 60.0), Vector2(288.0, 333.0)))

	view2.show_shot(tee, tee + Vector3(0.0, 2.0, -1.0), target)
	if not _check(view2.is_popped_out(), "New TeeShotView instance must remember popped-out state"):
		return
	if not _check(not view2._split_mode, "New TeeShotView instance must not enter split mode when remembered popped out"):
		return
	if not _check(view2._popout_window.position == Vector2i(220, 140), "New pop-out window must restore saved position"):
		return
	if not _check(view2._popout_window.size == Vector2i(540, 720), "New pop-out window must restore saved size"):
		return

	# Dock back mid-shot
	view2.dock_window(true)
	if not _check(not view2.is_popped_out(), "dock_window must clear popped-out state"):
		return
	if not _check(not bool(gs.range_settings.tee_shot_view_detached.value), "dock_window must persist detached=false"):
		return
	if not _check(view2._popout_window == null, "dock_window must close pop-out window"):
		return
	if not _check(view2._shot_panel.get_parent() == view2, "dock_window must return ShotPanel to TeeShotView"):
		return
	if not _check(view2._split_mode and view2.visible, "dock_window mid-shot must return to split mode"):
		return

	view2.hide_shot(true)
	view2.queue_free()
	main_camera.queue_free()

	# Restore original settings
	gs.range_settings.tee_shot_view_detached.set_value(orig_detached)
	gs.range_settings.tee_shot_window_position_x.set_value(orig_x)
	gs.range_settings.tee_shot_window_position_y.set_value(orig_y)
	gs.range_settings.tee_shot_window_width.set_value(orig_w)
	gs.range_settings.tee_shot_window_height.set_value(orig_h)
	gs.save_settings()

	print("PASS: Tee-shot pop-out window detaches, stays open, remembers position/size, and docks cleanly.")
	quit(0)
