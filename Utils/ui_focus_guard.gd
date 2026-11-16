extends Node
## UIFocusGuard — Centralized input-context / focus-lock system.
##
## Prevents directional navigation (arrow keys, analog stick, D-pad) from
## "bleeding" to other UI elements when the user is interacting with a
## nested control such as an OptionButton popup, a Slider, a SpinBox, or a
## modal overlay.
##
## HOW IT WORKS
## ────────────
## 1. This script sits at the TOP of the input chain (_input, not
##    _unhandled_input) so it can intercept events before Godot's built-in
##    GUI focus system propagates them.
##
## 2. It monitors for open OptionButton popups using a signal-based
##    approach that works even with `embed_subwindows = false` (native OS
##    popup windows).  When a popup opens, directional input is suppressed
##    until the popup closes.
##
## 3. When a Range (HSlider, VSlider, SpinBox internal slider) has focus,
##    left/right input is consumed (the Range already handles it internally
##    via Godot's built-in GUI) so it doesn't also jump focus to a
##    neighbouring control.
##
## 4. Provides a manual push/pop focus_lock API so that any scene can call
##    UIFocusGuard.push_lock(node) / UIFocusGuard.pop_lock() to restrict
##    all navigation to descendants of `node` while the lock is active.
##
## SETUP
## ─────
## Register as autoload in project.godot AFTER KeybindingManager and
## GlobalSettings.

const LOG_PREFIX := "[UIFocusGuard]"

## Currently open OptionButton popup state.
var _option_popup_open: bool = false
var _active_option_button: OptionButton = null

## Stack of focus-lock contexts. Each entry:
##   { "root": Node, "prev_focus": Control }
var _lock_stack: Array[Dictionary] = []

## Timer to periodically discover new OptionButtons in the tree.
var _scan_timer: float = 0.0

## Controller repeat timing for dropdown popups to prevent skipping items.
const DROPDOWN_INITIAL_REPEAT_DELAY := 0.42
const DROPDOWN_REPEAT_INTERVAL := 0.20
var _last_dropdown_nav_time: float = 0.0
var _dropdown_press_start_time: float = 0.0
var _dropdown_stick_neutral: bool = true
var _last_tracked_dropdown_idx: int = -1
const SCAN_INTERVAL: float = 0.5

const SLIDER_REPEAT_INTERVAL := 0.08
var _last_slider_nav_time: float = 0.0

## Controller repeat timing for UI directional stick navigation.
const NAV_INITIAL_REPEAT_DELAY := 0.35
const NAV_REPEAT_INTERVAL := 0.16
var _stick_nav_neutral_x: bool = true
var _stick_nav_neutral_y: bool = true
var _stick_nav_first_repeat_x: bool = true
var _stick_nav_first_repeat_y: bool = true
var _last_stick_nav_time_x: float = 0.0
var _last_stick_nav_time_y: float = 0.0
var _last_stick_dir_x: int = 0
var _last_stick_dir_y: int = 0

## Controller repeat timing for analog triggers (e.g. club switching and list paging).
const TRIGGER_INITIAL_REPEAT_DELAY := 0.40
const TRIGGER_REPEAT_INTERVAL := 0.22
var _trigger_lt_neutral: bool = true
var _trigger_lt_first_repeat: bool = true
var _last_trigger_lt_time: float = 0.0
var _trigger_rt_neutral: bool = true
var _trigger_rt_first_repeat: bool = true
var _last_trigger_rt_time: float = 0.0

## Set of OptionButton instance IDs we've already hooked signals onto.
var _hooked_option_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Hook any OptionButtons already in the tree.
	_scan_and_hook_option_buttons()
	var vp := get_viewport()
	if vp != null and not vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
		vp.gui_focus_changed.connect(_on_gui_focus_changed)


func _process(delta: float) -> void:
	# Periodically scan for new OptionButtons added dynamically.
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_and_hook_option_buttons()

	_validate_option_popup_state()


# ── PUBLIC API ─────────────────────────────────────────────────────────

## Whether an OptionButton dropdown is currently open.
func is_dropdown_open() -> bool:
	_validate_option_popup_state()
	return _option_popup_open


## Push a focus lock — all directional navigation will be confined to
## descendants of `root_node` until pop_lock() is called or the modal closes.
func push_lock(root_node: Node) -> bool:
	if root_node == null or not is_instance_valid(root_node):
		return false
	_prune_invalid_locks()
	# Avoid duplicate push of the exact same node
	for entry in _lock_stack:
		if entry.get("root") == root_node:
			return true

	var vp := get_viewport()
	var prev_focus: Control = null
	if vp != null:
		prev_focus = vp.gui_get_focus_owner()

	_lock_stack.push_back({
		"root": root_node,
		"prev_focus": prev_focus
	})

	if not root_node.tree_exiting.is_connected(_on_lock_root_tree_exiting):
		root_node.tree_exiting.connect(_on_lock_root_tree_exiting.bind(root_node))

	call_deferred("_focus_first_control", root_node)
	return true


func _on_lock_root_tree_exiting(root_node: Node) -> void:
	pop_lock(root_node)


## Pop a focus lock and restore focus. Supports pop_lock(), pop_lock(bool), and pop_lock(Node, bool).
func pop_lock(target: Variant = null, restore_focus: bool = true) -> void:
	var target_node: Node = null
	if target is bool:
		restore_focus = target as bool
	elif target is Node:
		target_node = target as Node

	if _lock_stack.is_empty():
		return

	var entry: Dictionary = {}
	if target_node != null:
		var found_idx := -1
		for i in range(_lock_stack.size() - 1, -1, -1):
			if _lock_stack[i].get("root") == target_node:
				found_idx = i
				break
		if found_idx >= 0:
			entry = _lock_stack[found_idx]
			_lock_stack.remove_at(found_idx)
		else:
			return
	else:
		entry = _lock_stack.pop_back()

	var raw_root = entry.get("root")
	var root: Node = raw_root as Node if (raw_root != null and is_instance_valid(raw_root)) else null
	if root != null:
		if root.tree_exiting.is_connected(_on_lock_root_tree_exiting):
			root.tree_exiting.disconnect(_on_lock_root_tree_exiting)
		if root.has_method("_on_focus_lock_popped"):
			root._on_focus_lock_popped()
		elif root.has_meta("on_focus_lock_popped"):
			var cb = root.get_meta("on_focus_lock_popped")
			if cb is Callable and cb.is_valid():
				cb.call()

	if restore_focus:
		var raw_prev = entry.get("prev_focus")
		var prev: Control = raw_prev as Control if (raw_prev != null and is_instance_valid(raw_prev)) else null
		if _lock_stack.is_empty():
			if prev != null and prev.is_visible_in_tree():
				prev.call_deferred("grab_focus")
		else:
			var raw_next_root = _lock_stack.back().get("root")
			var next_root: Node = raw_next_root as Node if (raw_next_root != null and is_instance_valid(raw_next_root)) else null
			if next_root != null:
				call_deferred("_focus_first_control", next_root)


## Returns `true` when any focus lock is active.
func is_locked() -> bool:
	return current_lock_root() != null


## Returns `true` when any modal or focus lock is currently active.
func is_modal_active() -> bool:
	return current_lock_root() != null


## Returns the root of the current (topmost) lock, or auto-detected visible modal, or null.
func current_lock_root() -> Node:
	_prune_invalid_locks()
	if _lock_stack.is_empty():
		var auto_modal := _find_visible_modal_in_tree()
		if auto_modal != null:
			push_lock(auto_modal)
	if _lock_stack.is_empty():
		return null
	return _lock_stack.back()["root"]


# ── CORE INPUT INTERCEPTION ────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Always validate dropdown popup state so stale open flags never swallow input
	_validate_option_popup_state()

	# ── Controller Triggers and Left Stick Repeat Debounce ────────
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var axis := motion.axis
		var val := motion.axis_value

		# 1. Analog Triggers (LT / RT for club switching and list page up/down)
		if axis == JOY_AXIS_TRIGGER_LEFT:
			if val < 0.25:
				_trigger_lt_neutral = true
				_trigger_lt_first_repeat = true
			elif val >= 0.5:
				var now := Time.get_ticks_msec() / 1000.0
				if _trigger_lt_neutral:
					_trigger_lt_neutral = false
					_trigger_lt_first_repeat = true
					_last_trigger_lt_time = now
				else:
					var delay := TRIGGER_INITIAL_REPEAT_DELAY if _trigger_lt_first_repeat else TRIGGER_REPEAT_INTERVAL
					if (now - _last_trigger_lt_time) < delay:
						get_viewport().set_input_as_handled()
						return
					_last_trigger_lt_time = now
					_trigger_lt_first_repeat = false

		elif axis == JOY_AXIS_TRIGGER_RIGHT:
			if val < 0.25:
				_trigger_rt_neutral = true
				_trigger_rt_first_repeat = true
			elif val >= 0.5:
				var now := Time.get_ticks_msec() / 1000.0
				if _trigger_rt_neutral:
					_trigger_rt_neutral = false
					_trigger_rt_first_repeat = true
					_last_trigger_rt_time = now
				else:
					var delay := TRIGGER_INITIAL_REPEAT_DELAY if _trigger_rt_first_repeat else TRIGGER_REPEAT_INTERVAL
					if (now - _last_trigger_rt_time) < delay:
						get_viewport().set_input_as_handled()
						return
					_last_trigger_rt_time = now
					_trigger_rt_first_repeat = false

		# 2. Left Stick Directional Navigation (X / Y)
		elif axis == JOY_AXIS_LEFT_X:
			if abs(val) < 0.25:
				_stick_nav_neutral_x = true
				_stick_nav_first_repeat_x = true
				_last_stick_dir_x = 0
			elif abs(val) >= 0.5:
				var vp_check := get_viewport()
				var focused_ctrl := vp_check.gui_get_focus_owner() if vp_check != null else null
				var is_slider := focused_ctrl is Range or (focused_ctrl != null and focused_ctrl.get_parent() != null and focused_ctrl.get_parent() is SpinBox)
				if not is_slider and not _option_popup_open:
					var dir_x := 1 if val > 0.0 else -1
					var now := Time.get_ticks_msec() / 1000.0
					if _stick_nav_neutral_x or dir_x != _last_stick_dir_x:
						_stick_nav_neutral_x = false
						_stick_nav_first_repeat_x = true
						_last_stick_dir_x = dir_x
						_last_stick_nav_time_x = now
					else:
						var delay := NAV_INITIAL_REPEAT_DELAY if _stick_nav_first_repeat_x else NAV_REPEAT_INTERVAL
						if (now - _last_stick_nav_time_x) < delay:
							get_viewport().set_input_as_handled()
							return
						_last_stick_nav_time_x = now
						_stick_nav_first_repeat_x = false

		elif axis == JOY_AXIS_LEFT_Y:
			if abs(val) < 0.25:
				_stick_nav_neutral_y = true
				_stick_nav_first_repeat_y = true
				_last_stick_dir_y = 0
				_dropdown_stick_neutral = true
				_dropdown_press_start_time = 0.0
			elif abs(val) >= 0.5:
				if not _option_popup_open:
					var vp_check := get_viewport()
					var focused_ctrl := vp_check.gui_get_focus_owner() if vp_check != null else null
					var is_vslider := focused_ctrl is VSlider
					if not is_vslider:
						var dir_y := 1 if val > 0.0 else -1
						var now := Time.get_ticks_msec() / 1000.0
						if _stick_nav_neutral_y or dir_y != _last_stick_dir_y:
							_stick_nav_neutral_y = false
							_stick_nav_first_repeat_y = true
							_last_stick_dir_y = dir_y
							_last_stick_nav_time_y = now
						else:
							var delay := NAV_INITIAL_REPEAT_DELAY if _stick_nav_first_repeat_y else NAV_REPEAT_INTERVAL
							if (now - _last_stick_nav_time_y) < delay:
								get_viewport().set_input_as_handled()
								return
							_last_stick_nav_time_y = now
							_stick_nav_first_repeat_y = false

	var is_motion: bool = (event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis_value) >= 0.5)
	if not event.is_pressed() and not is_motion:
		return

	var is_directional: bool = _is_directional(event)
	var is_cancel: bool = event.is_action_pressed("ui_cancel")

	# ── 1.  OptionButton popup guard & controller navigation ──────
	if _option_popup_open:
		var popup: PopupMenu = _active_option_button.get_popup() if (_active_option_button != null and is_instance_valid(_active_option_button)) else null

		if is_cancel or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
			# Close the popup cleanly and restore focus.
			_close_active_popup()
			get_viewport().set_input_as_handled()
			if popup is Viewport:
				popup.set_input_as_handled()
			return

		if popup != null and is_instance_valid(popup) and popup.visible and popup.item_count > 0:
			var is_stick_down: bool = (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value >= 0.5)
			var is_stick_up: bool = (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value <= -0.5)
			var is_btn_down: bool = event.is_action_pressed("ui_down") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_DOWN and event.pressed)
			var is_btn_up: bool = event.is_action_pressed("ui_up") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed)

			var is_headless: bool = (DisplayServer.get_name() == "headless")

			# Handle analog stick or D-pad navigation
			if is_stick_down or is_stick_up or is_btn_down or is_btn_up:
				var now := Time.get_ticks_msec() / 1000.0
				var repeat_limit := DROPDOWN_REPEAT_INTERVAL
				if _dropdown_stick_neutral:
					repeat_limit = DROPDOWN_INITIAL_REPEAT_DELAY
					_dropdown_stick_neutral = false
				if (now - _last_dropdown_nav_time) < repeat_limit:
					get_viewport().set_input_as_handled()
					if popup is Viewport:
						popup.set_input_as_handled()
					return
				_last_dropdown_nav_time = now

				var dir := 1 if (is_stick_down or is_btn_down) else -1
				var cur := popup.get_focused_item()
				if cur < 0:
					cur = _last_tracked_dropdown_idx
				if cur < 0 and _active_option_button != null:
					cur = _active_option_button.selected
				var next_idx := _get_next_selectable_popup_item(popup, cur, dir)
				_last_tracked_dropdown_idx = next_idx
				popup.set_focused_item(next_idx)
				get_viewport().set_input_as_handled()
				if popup is Viewport:
					popup.set_input_as_handled()
				return
			elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
				(event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and abs(event.axis_value) >= 0.5):
				get_viewport().set_input_as_handled()
				if popup is Viewport:
					popup.set_input_as_handled()
				return
			elif event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed):
				var focused_idx := popup.get_focused_item()
				if focused_idx < 0:
					focused_idx = _last_tracked_dropdown_idx
				if focused_idx < 0 and _active_option_button != null:
					focused_idx = _active_option_button.selected
				if focused_idx >= 0 and focused_idx < popup.item_count:
					if not popup.is_item_disabled(focused_idx) and not popup.is_item_separator(focused_idx):
						if popup.has_method("activate_item"):
							popup.activate_item(focused_idx)
						if _active_option_button != null and is_instance_valid(_active_option_button):
							_active_option_button.select(focused_idx)
							_active_option_button.item_selected.emit(focused_idx)
						popup.hide()
						_option_popup_open = false
						_active_option_button = null
						_last_tracked_dropdown_idx = -1
						get_viewport().set_input_as_handled()
						if popup is Viewport:
							popup.set_input_as_handled()
						return

		if is_directional:
			get_viewport().set_input_as_handled()
			if popup is Viewport:
				popup.set_input_as_handled()
			return
		return

	var vp := get_viewport()

	# ── 2.  3D Gameplay Aim vs HUD Focus Release ──────────────────
	# In 3D gameplay (Course Play / Driving Range), D-pad is for aiming the ball.
	# If a HUD button has focus from previous controller/analog stick navigation,
	# pressing any aim input (D-pad or arrow key) or cancel releases HUD focus so
	# Godot GUI doesn't swallow D-pad for UI focus navigation, and ball aiming works immediately.
	if vp != null and _is_in_3d_gameplay() and not _option_popup_open and _lock_stack.is_empty():
		var focused := vp.gui_get_focus_owner()
		if focused != null and is_instance_valid(focused) and focused.is_visible_in_tree():
			var in_modal := _is_control_in_modal(focused)
			var in_editor := focused is LineEdit or focused is TextEdit or focused is Range or (focused.get_parent() != null and is_instance_valid(focused.get_parent()) and focused.get_parent() is SpinBox)
			if not in_modal and not in_editor:
				if _is_aim_input(event):
					vp.gui_release_focus()
					# Do not mark handled: let the event fall through to _unhandled_input so aim executes immediately!
				elif is_cancel or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
					vp.gui_release_focus()
					get_viewport().set_input_as_handled()
					return

	# ── 3.  Range / Slider / SpinBox guard ────────────────────────
	if vp != null and is_directional:
		var focused := vp.gui_get_focus_owner()
		if focused != null and is_instance_valid(focused):
			var effective_ctrl := focused
			# SpinBox wraps a LineEdit; check parent.
			if focused is LineEdit and focused.get_parent() != null and is_instance_valid(focused.get_parent()) and focused.get_parent() is SpinBox:
				effective_ctrl = focused.get_parent()

			if effective_ctrl is Range:
				var rng := effective_ctrl as Range
				var step_val := rng.step
				if is_zero_approx(step_val):
					step_val = (rng.max_value - rng.min_value) / 20.0
					if is_zero_approx(step_val):
						step_val = 1.0

				var now := Time.get_ticks_msec() / 1000.0
				var is_vslider: bool = (effective_ctrl is VSlider)
				var is_up: bool = event.is_action_pressed("ui_up") or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value <= -0.5)
				var is_down: bool = event.is_action_pressed("ui_down") or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value >= 0.5)
				var is_left: bool = event.is_action_pressed("ui_left") or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and event.axis_value <= -0.5)
				var is_right: bool = event.is_action_pressed("ui_right") or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and event.axis_value >= 0.5)

				if is_vslider:
					if is_up or is_down:
						if event is InputEventJoypadMotion and (now - _last_slider_nav_time) < SLIDER_REPEAT_INTERVAL:
							get_viewport().set_input_as_handled()
							return
						_last_slider_nav_time = now
						var delta_val = step_val if is_up else -step_val
						rng.value = clampf(rng.value + delta_val, rng.min_value, rng.max_value)
						rng.value_changed.emit(rng.value)
						get_viewport().set_input_as_handled()
						return
				else:
					if is_left or is_right:
						if event is InputEventJoypadMotion and (now - _last_slider_nav_time) < SLIDER_REPEAT_INTERVAL:
							get_viewport().set_input_as_handled()
							return
						_last_slider_nav_time = now
						var delta_val = step_val if is_right else -step_val
						rng.value = clampf(rng.value + delta_val, rng.min_value, rng.max_value)
						rng.value_changed.emit(rng.value)
						get_viewport().set_input_as_handled()
						return

	# ── 3.  Manual focus-lock guard & modal containment ───────────
	var lock_root: Node = current_lock_root()
	if lock_root != null:
		if is_cancel:
			_dismiss_modal_or_pop_lock(lock_root)
			get_viewport().set_input_as_handled()
			return

		var cur_focus := vp.gui_get_focus_owner() if vp != null else null

		# Tab switching with Gamepad Bumpers (LB/RB), Q/E (when not in LineEdit), or PageUp/PageDown
		var is_typing: bool = (cur_focus is LineEdit or cur_focus is TextEdit)
		var is_tab_prev: bool = (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER) or \
			(event is InputEventKey and event.pressed and (event.keycode == KEY_PAGEUP or (not is_typing and (event.keycode == KEY_Q or event.physical_keycode == KEY_Q))))
		var is_tab_next: bool = (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER) or \
			(event is InputEventKey and event.pressed and (event.keycode == KEY_PAGEDOWN or (not is_typing and (event.keycode == KEY_E or event.physical_keycode == KEY_E))))
		if is_tab_prev or is_tab_next:
			if _handle_modal_tab_switch(lock_root, is_tab_next):
				get_viewport().set_input_as_handled()
				return

		# ui_accept handling on ItemList and TabBar
		if cur_focus is ItemList:
			var item_list := cur_focus as ItemList
			if item_list.item_count > 0 and (event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)):
				var selected := item_list.get_selected_items()
				var idx := selected[0] if not selected.is_empty() else 0
				item_list.select(idx)
				item_list.ensure_current_is_visible()
				item_list.item_selected.emit(idx)
				item_list.item_activated.emit(idx)
				get_viewport().set_input_as_handled()
				return
		elif cur_focus is TabBar:
			var tab_bar := cur_focus as TabBar
			if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
				var tc: TabContainer = tab_bar.get_parent() as TabContainer if (tab_bar.get_parent() is TabContainer) else null
				var count: int = tc.get_tab_count() if tc != null else tab_bar.tab_count
				var cur: int = tc.current_tab if tc != null else tab_bar.current_tab
				var next_tab: int = (cur + 1) % count
				if tc != null:
					tc.current_tab = next_tab
					tc.tab_changed.emit(next_tab)
				else:
					tab_bar.current_tab = next_tab
					tab_bar.tab_changed.emit(next_tab)
				get_viewport().set_input_as_handled()
				return

		# If focus is null, invisible, or outside lock_root, redirect and consume input
		if cur_focus == null or not cur_focus.is_visible_in_tree() or (not lock_root.is_ancestor_of(cur_focus) and cur_focus != lock_root):
			var focused_ok := _focus_first_control(lock_root)
			if focused_ok:
				get_viewport().set_input_as_handled()
				return
			else:
				# Lock root has no interactive controls; pop stale lock
				pop_lock(lock_root, false)
				return

		# Tab / Shift-Tab cycling inside lock_root
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev") or \
		   (event is InputEventKey and event.pressed and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB)):
			var focusables := _get_all_focusable_controls(lock_root)
			if not focusables.is_empty():
				var cur_idx := focusables.find(cur_focus)
				var shift := (event is InputEventKey and (event as InputEventKey).shift_pressed) or event.is_action_pressed("ui_focus_prev")
				var next_idx: int = 0
				if cur_idx >= 0:
					next_idx = (cur_idx - 1 + focusables.size()) % focusables.size() if shift else (cur_idx + 1) % focusables.size()
				focusables[next_idx].grab_focus()
				get_viewport().set_input_as_handled()
				return

		# Directional modal navigation: 2D spatial movement across visible controls
		if is_directional:
			var side: int = -1
			if event.is_action_pressed("ui_left") or \
			   (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_LEFT) or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and event.axis_value <= -0.5):
				side = SIDE_LEFT
			elif event.is_action_pressed("ui_right") or \
			   (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_RIGHT) or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and event.axis_value >= 0.5):
				side = SIDE_RIGHT
			elif event.is_action_pressed("ui_up") or \
			   (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_UP) or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value <= -0.5):
				side = SIDE_TOP
			elif event.is_action_pressed("ui_down") or \
			   (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_DOWN) or \
			   (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value >= 0.5):
				side = SIDE_BOTTOM

			if side >= 0:
				# Keyboard caret navigation for LineEdit / TextEdit: allow Left/Right arrows on keyboard
				if (cur_focus is LineEdit or cur_focus is TextEdit) and (side == SIDE_LEFT or side == SIDE_RIGHT) and event is InputEventKey:
					return

				_navigate_directional(lock_root, cur_focus, side)
				get_viewport().set_input_as_handled()
				return


# ── OPTION BUTTON SIGNAL HOOKING ───────────────────────────────────────

## Scan the full scene tree for OptionButtons and hook popup signals.
func scan_and_hook_option_buttons() -> void:
	_scan_and_hook_option_buttons()


func hook_option_button(opt: OptionButton) -> void:
	if opt == null or not is_instance_valid(opt):
		return
	var iid := opt.get_instance_id()
	if not _hooked_option_buttons.has(iid):
		_hook_option_button(opt)
		_hooked_option_buttons[iid] = true


func _scan_and_hook_option_buttons() -> void:
	var root := get_tree().root
	if root == null:
		return
	_hook_option_buttons_recursive(root)


func _hook_option_buttons_recursive(node: Node) -> void:
	if node is OptionButton:
		var opt := node as OptionButton
		var iid := opt.get_instance_id()
		if not _hooked_option_buttons.has(iid):
			_hook_option_button(opt)
			_hooked_option_buttons[iid] = true

	for child in node.get_children():
		_hook_option_buttons_recursive(child)


func _hook_option_button(opt: OptionButton) -> void:
	# The OptionButton's internal PopupMenu has visibility_changed and
	# id_pressed signals we can use to track open/close state.
	var popup := opt.get_popup()
	if popup == null:
		return

	popup.hide_on_item_selection = true
	popup.hide_on_checkable_item_selection = true

	# Use a lambda that captures the OptionButton reference.
	# visibility_changed fires when the popup shows AND hides.
	if not popup.visibility_changed.is_connected(_on_popup_visibility_changed):
		popup.visibility_changed.connect(_on_popup_visibility_changed.bind(opt, popup))

	if not popup.index_pressed.is_connected(_on_popup_index_pressed):
		popup.index_pressed.connect(_on_popup_index_pressed.bind(opt, popup))

	if not opt.item_selected.is_connected(_on_option_item_selected):
		opt.item_selected.connect(_on_option_item_selected.bind(opt, popup))

	# Also handle the OptionButton being freed.
	if not opt.tree_exiting.is_connected(_on_option_button_exiting):
		opt.tree_exiting.connect(_on_option_button_exiting.bind(opt))


func _on_popup_index_pressed(_index: int, opt: OptionButton, popup: PopupMenu) -> void:
	if popup != null and is_instance_valid(popup) and popup.visible:
		popup.call_deferred("hide")
	if _active_option_button == opt:
		_option_popup_open = false
		_active_option_button = null
		_last_tracked_dropdown_idx = -1


func _on_option_item_selected(_index: int, opt: OptionButton, popup: PopupMenu) -> void:
	if popup != null and is_instance_valid(popup) and popup.visible:
		popup.call_deferred("hide")
	if _active_option_button == opt:
		_option_popup_open = false
		_active_option_button = null
		_last_tracked_dropdown_idx = -1


func _on_popup_visibility_changed(opt: OptionButton, popup: PopupMenu) -> void:
	if popup == null or not is_instance_valid(popup):
		_option_popup_open = false
		_active_option_button = null
		_last_tracked_dropdown_idx = -1
		return

	if popup.visible:
		# If another OptionButton popup was still open, close it first.
		if _active_option_button != null and _active_option_button != opt and is_instance_valid(_active_option_button):
			var prev_popup := _active_option_button.get_popup()
			if prev_popup != null and is_instance_valid(prev_popup) and prev_popup.visible:
				prev_popup.hide()
		# Popup just opened.
		_option_popup_open = true
		_active_option_button = opt
		_dropdown_stick_neutral = true
		_dropdown_press_start_time = 0.0
		_last_dropdown_nav_time = 0.0
		if opt != null and is_instance_valid(opt) and popup.item_count > 0:
			var init_idx = opt.selected if (opt.selected >= 0 and opt.selected < popup.item_count) else 0
			_last_tracked_dropdown_idx = init_idx
			popup.set_focused_item(init_idx)
	else:
		# Popup just closed — restore focus to the OptionButton.
		if _active_option_button == opt or _active_option_button == null:
			_option_popup_open = false
			_active_option_button = null
			_last_tracked_dropdown_idx = -1
		if opt != null and is_instance_valid(opt) and opt.is_inside_tree() and opt.is_visible_in_tree():
			opt.call_deferred("grab_focus")


func _on_option_button_exiting(opt: OptionButton) -> void:
	var iid := opt.get_instance_id()
	_hooked_option_buttons.erase(iid)
	if _active_option_button == opt:
		_option_popup_open = false
		_active_option_button = null


func _close_active_popup() -> void:
	_option_popup_open = false
	var opt := _active_option_button
	_active_option_button = null
	_last_tracked_dropdown_idx = -1
	if opt != null and is_instance_valid(opt):
		var popup := opt.get_popup()
		if popup != null and is_instance_valid(popup) and popup.visible:
			popup.hide()
		if is_instance_valid(opt) and opt.is_inside_tree() and opt.is_visible_in_tree():
			opt.call_deferred("grab_focus")


func _validate_option_popup_state() -> void:
	if not _option_popup_open:
		return
	if _active_option_button == null or not is_instance_valid(_active_option_button):
		_option_popup_open = false
		_active_option_button = null
		_last_tracked_dropdown_idx = -1
		return
	var popup: PopupMenu = _active_option_button.get_popup()
	if popup == null or not is_instance_valid(popup) or not popup.visible:
		_option_popup_open = false
		_active_option_button = null
		_last_tracked_dropdown_idx = -1


# ── HELPERS ────────────────────────────────────────────────────────────

func _prune_invalid_locks() -> void:
	var i := _lock_stack.size() - 1
	while i >= 0:
		var root = _lock_stack[i].get("root")
		if root == null or not is_instance_valid(root):
			_lock_stack.remove_at(i)
		elif root is Node and not (root as Node).is_inside_tree():
			_lock_stack.remove_at(i)
		elif root is Control and not (root as Control).is_visible_in_tree():
			_lock_stack.remove_at(i)
		elif root is Window and not (root as Window).visible:
			_lock_stack.remove_at(i)
		elif root is CanvasLayer and "visible" in root and not root.visible:
			_lock_stack.remove_at(i)
		i -= 1


func _is_directional(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
		or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		return true
	if event is InputEventJoypadButton and event.pressed:
		var btn: int = event.button_index
		if btn == JOY_BUTTON_DPAD_UP or btn == JOY_BUTTON_DPAD_DOWN or btn == JOY_BUTTON_DPAD_LEFT or btn == JOY_BUTTON_DPAD_RIGHT:
			return true
	if event is InputEventJoypadMotion and abs(event.axis_value) >= 0.5:
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
			return true
		return event.is_action("ui_up") or event.is_action("ui_down") \
			or event.is_action("ui_left") or event.is_action("ui_right")
	return false


func _get_next_selectable_popup_item(popup: PopupMenu, from_idx: int, dir: int) -> int:
	var count := popup.item_count
	if count <= 0:
		return -1
	var start := clampi(from_idx, 0, count - 1)
	var cur := start + dir
	while cur >= 0 and cur < count:
		if not popup.is_item_separator(cur) and not popup.is_item_disabled(cur):
			return cur
		cur += dir
	return start


func _is_control_in_modal(ctrl: Node) -> bool:
	if ctrl == null or not is_instance_valid(ctrl):
		return false
	var cur: Node = ctrl
	var root: Node = get_tree().root if get_tree() != null else null
	while cur != null and is_instance_valid(cur) and cur != root:
		if cur is Popup or cur is AcceptDialog or cur is ConfirmationDialog:
			return true
		if cur is Window and cur.exclusive:
			return true
		if cur.is_in_group("modals") or cur.is_in_group("modal_dialogs"):
			return true
		var c_name := str(cur.name).to_lower()
		if c_name.contains("modal") or c_name.contains("dialog") or c_name.contains("popup") \
			or c_name == "distancemenu" or c_name == "settingslayer" or c_name == "settingsmodallayer" \
			or c_name == "scorecardpanel" or c_name == "manageplayerspanel" \
			or c_name == "placeballbutton" or c_name == "prevholebutton" or c_name == "nextholebutton":
			return true
		if not cur.is_inside_tree():
			break
		cur = cur.get_parent()
	return false


func _find_visible_modal_in_tree() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene

	# 1. Group "modals"
	var modal_nodes := tree.get_nodes_in_group("modals")
	for m in modal_nodes:
		if is_instance_valid(m) and m is Node and m != current_scene and m != self:
			if (m is Control and m.is_visible_in_tree()) or (m is Window and m.visible and m.exclusive) or (m is CanvasLayer and m.visible):
				return m

	# 2. Search direct children of current_scene and root
	var search_roots: Array[Node] = []
	if current_scene != null:
		search_roots.append(current_scene)
	if tree.root != null:
		search_roots.append(tree.root)

	for s_root in search_roots:
		for child in s_root.get_children():
			if not is_instance_valid(child) or child == current_scene or child == self:
				continue
			if child is Window and child.visible and child.exclusive:
				return child
			if child is Control and child.is_visible_in_tree():
				var c_name := str(child.name).to_lower()
				if c_name.contains("modal") or c_name.contains("dialog") or c_name.contains("customcoursecreator") or c_name.contains("creator"):
					return child
				if child.get_script() != null:
					var path := str(child.get_script().resource_path).to_lower()
					if path.contains("modal") or path.contains("dialog") or path.contains("custom_course_creator"):
						return child
			if child is CanvasLayer and child.visible:
				var c_name := str(child.name).to_lower()
				if c_name.contains("modal") or c_name.contains("dialog"):
					return child

	return null


func _dismiss_modal_or_pop_lock(lock_root: Node) -> void:
	if lock_root == null or not is_instance_valid(lock_root):
		pop_lock(lock_root, true)
		return

	if lock_root.has_method("_on_skip_pressed"):
		lock_root._on_skip_pressed()
	elif lock_root.has_method("_on_cancel_pressed"):
		lock_root._on_cancel_pressed()
	elif lock_root.has_method("_on_close_pressed"):
		lock_root._on_close_pressed()
	elif lock_root.has_method("close"):
		lock_root.close()
	else:
		var btn = lock_root.find_child("*Cancel*", true, false)
		if btn == null:
			btn = lock_root.find_child("*Close*", true, false)
		if btn == null:
			btn = lock_root.find_child("*Skip*", true, false)
		if btn != null and btn is BaseButton and not btn.disabled:
			btn.emit_signal("pressed")
		else:
			pop_lock(lock_root, true)
			if lock_root is Window or lock_root is Popup:
				lock_root.hide()
			elif lock_root.is_inside_tree():
				lock_root.queue_free()


func _on_gui_focus_changed(new_focus: Control) -> void:
	if new_focus == null or _option_popup_open:
		return
	_prune_invalid_locks()
	var lock_root: Node = current_lock_root()
	if lock_root != null and is_instance_valid(lock_root):
		if not lock_root.is_ancestor_of(new_focus) and new_focus != lock_root:
			if new_focus.has_meta("toggle_target") and new_focus.get_meta("toggle_target") == lock_root:
				return
			if new_focus.name == "HitDistanceButton":
				return
			new_focus.release_focus()
			call_deferred("_restore_lock_focus", lock_root)


func _restore_lock_focus(lock_root: Node) -> void:
	if lock_root != null and is_instance_valid(lock_root) and is_locked() and current_lock_root() == lock_root:
		var vp := get_viewport()
		if vp != null:
			var cur := vp.gui_get_focus_owner()
			if cur == null or (not lock_root.is_ancestor_of(cur) and cur != lock_root):
				_focus_first_control(lock_root)


static func _get_all_focusable_controls(root: Node) -> Array[Control]:
	var list: Array[Control] = []
	_gather_focusable_controls_recursive(root, list)
	return list


static func _gather_focusable_controls_recursive(node: Node, list: Array[Control]) -> void:
	if node == null:
		return
	if node is TabContainer:
		var tc := node as TabContainer
		var tb := tc.get_tab_bar()
		if tb != null and tb.is_visible_in_tree() and tb.focus_mode != Control.FOCUS_NONE:
			if not list.has(tb):
				list.push_back(tb)
	if node is Control:
		var c := node as Control
		if not c.is_visible_in_tree():
			return
		if c.focus_mode != Control.FOCUS_NONE:
			if not (c is BaseButton and c.disabled):
				if not (c is Container and not (c is ItemList or c is Tree or c is TabBar)):
					if not list.has(c):
						list.push_back(c)
	for child in node.get_children():
		_gather_focusable_controls_recursive(child, list)


static func _focus_first_control(root: Node) -> bool:
	if root == null:
		return false
	if root.has_method("_grab_initial_focus"):
		root._grab_initial_focus()
		var vp := root.get_viewport()
		if vp != null and vp.gui_get_focus_owner() != null:
			var cur := vp.gui_get_focus_owner()
			if cur.is_visible_in_tree() and (root.is_ancestor_of(cur) or cur == root):
				return true
	var focusables := _get_all_focusable_controls(root)
	if not focusables.is_empty():
		focusables[0].grab_focus()
		return true
	return false


func _navigate_directional(lock_root: Node, cur_focus: Control, side: int) -> bool:
	if lock_root == null or not is_instance_valid(lock_root):
		return false

	var focusables := _get_all_focusable_controls(lock_root)
	if focusables.is_empty():
		return false

	if cur_focus == null or not is_instance_valid(cur_focus) or not cur_focus.is_visible_in_tree() or (not lock_root.is_ancestor_of(cur_focus) and cur_focus != lock_root):
		return _focus_first_control(lock_root)

	# Special handling for ItemList internal navigation:
	if cur_focus is ItemList:
		var item_list := cur_focus as ItemList
		if item_list.item_count > 0:
			var selected := item_list.get_selected_items()
			var cur_idx := selected[0] if not selected.is_empty() else -1
			if cur_idx == -1:
				if side == SIDE_BOTTOM:
					item_list.select(0)
					item_list.ensure_current_is_visible()
					item_list.item_selected.emit(0)
					return true
				# If side == SIDE_TOP and nothing selected, fall through to navigate UP out of ItemList
			else:
				if side == SIDE_TOP and cur_idx > 0:
					item_list.select(cur_idx - 1)
					item_list.ensure_current_is_visible()
					item_list.item_selected.emit(cur_idx - 1)
					return true
				elif side == SIDE_BOTTOM and cur_idx < item_list.item_count - 1:
					item_list.select(cur_idx + 1)
					item_list.ensure_current_is_visible()
					item_list.item_selected.emit(cur_idx + 1)
					return true

	# Special handling for TabBar tab switching:
	if cur_focus is TabBar:
		var tab_bar := cur_focus as TabBar
		if side == SIDE_LEFT or side == SIDE_RIGHT:
			var tc: TabContainer = tab_bar.get_parent() as TabContainer if (tab_bar.get_parent() is TabContainer) else null
			var count: int = tc.get_tab_count() if tc != null else tab_bar.tab_count
			var cur: int = tc.current_tab if tc != null else tab_bar.current_tab
			var next_tab: int = clampi(cur - 1 if side == SIDE_LEFT else cur + 1, 0, count - 1)
			if next_tab != cur:
				if tc != null:
					tc.current_tab = next_tab
					tc.tab_changed.emit(next_tab)
				else:
					tab_bar.current_tab = next_tab
					tab_bar.tab_changed.emit(next_tab)
			return true

	# Explicit neighbor override check if scene author set one:
	var explicit_prop: StringName = &""
	match side:
		SIDE_LEFT: explicit_prop = &"focus_neighbor_left"
		SIDE_TOP: explicit_prop = &"focus_neighbor_top"
		SIDE_RIGHT: explicit_prop = &"focus_neighbor_right"
		SIDE_BOTTOM: explicit_prop = &"focus_neighbor_bottom"

	if explicit_prop != &"":
		var target_path: NodePath = cur_focus.get(explicit_prop)
		if target_path != null and not target_path.is_empty():
			var neighbor = cur_focus.get_node_or_null(target_path)
			if neighbor is Control and neighbor.is_visible_in_tree() and (lock_root.is_ancestor_of(neighbor) or neighbor == lock_root):
				if neighbor.focus_mode != Control.FOCUS_NONE and not (neighbor is BaseButton and neighbor.disabled):
					neighbor.grab_focus()
					return true

	# 2D Spatial Best-Candidate Search
	var cur_rect := cur_focus.get_global_rect()
	var cur_c := cur_rect.get_center()

	var best_candidate: Control = null
	var best_score: float = INF

	for cand in focusables:
		if cand == cur_focus:
			continue
		var cand_rect := cand.get_global_rect()
		if cand_rect.size.x <= 0 or cand_rect.size.y <= 0:
			continue
		var cand_c := cand_rect.get_center()

		var primary_dist: float = 0.0
		var ortho_dist: float = 0.0
		var is_valid_dir: bool = false

		match side:
			SIDE_LEFT:
				primary_dist = cur_c.x - cand_c.x
				ortho_dist = abs(cand_c.y - cur_c.y)
				var overlap = max(0.0, min(cur_rect.end.y, cand_rect.end.y) - max(cur_rect.position.y, cand_rect.position.y))
				if primary_dist > 1.0 and (overlap > 0.0 or ortho_dist <= max(cur_rect.size.y, cand_rect.size.y) * 3.0):
					is_valid_dir = true
					ortho_dist = max(0.0, ortho_dist - overlap * 0.75)

			SIDE_RIGHT:
				primary_dist = cand_c.x - cur_c.x
				ortho_dist = abs(cand_c.y - cur_c.y)
				var overlap = max(0.0, min(cur_rect.end.y, cand_rect.end.y) - max(cur_rect.position.y, cand_rect.position.y))
				if primary_dist > 1.0 and (overlap > 0.0 or ortho_dist <= max(cur_rect.size.y, cand_rect.size.y) * 3.0):
					is_valid_dir = true
					ortho_dist = max(0.0, ortho_dist - overlap * 0.75)

			SIDE_TOP:
				primary_dist = cur_c.y - cand_c.y
				ortho_dist = abs(cand_c.x - cur_c.x)
				var overlap = max(0.0, min(cur_rect.end.x, cand_rect.end.x) - max(cur_rect.position.x, cand_rect.position.x))
				if primary_dist > 1.0 and (overlap > 0.0 or ortho_dist <= max(cur_rect.size.x, cand_rect.size.x) * 3.5):
					is_valid_dir = true
					ortho_dist = max(0.0, ortho_dist - overlap * 0.75)

			SIDE_BOTTOM:
				primary_dist = cand_c.y - cur_c.y
				ortho_dist = abs(cand_c.x - cur_c.x)
				var overlap = max(0.0, min(cur_rect.end.x, cand_rect.end.x) - max(cur_rect.position.x, cand_rect.position.x))
				if primary_dist > 1.0 and (overlap > 0.0 or ortho_dist <= max(cur_rect.size.x, cand_rect.size.x) * 3.5):
					is_valid_dir = true
					ortho_dist = max(0.0, ortho_dist - overlap * 0.75)

		if not is_valid_dir:
			continue

		var score: float = primary_dist + ortho_dist * 2.0
		if score < best_score:
			best_score = score
			best_candidate = cand

	if best_candidate != null:
		best_candidate.grab_focus()
		return true

	# Boundary preserved: no candidate in this direction
	return true


func _handle_modal_tab_switch(lock_root: Node, forward: bool) -> bool:
	var tab_container := _find_tab_container(lock_root)
	if tab_container == null or tab_container.get_tab_count() <= 1:
		return false
	var count := tab_container.get_tab_count()
	var cur := tab_container.current_tab
	var next_tab := (cur + 1) % count if forward else (cur - 1 + count) % count
	tab_container.current_tab = next_tab
	tab_container.tab_changed.emit(next_tab)
	var tab_ctrl := tab_container.get_current_tab_control()
	if tab_ctrl != null:
		call_deferred("_focus_first_control", tab_ctrl)
	else:
		call_deferred("_focus_first_control", lock_root)
	return true


func _find_tab_container(node: Node) -> TabContainer:
	if node is TabContainer and (node as TabContainer).is_visible_in_tree():
		return node as TabContainer
	for child in node.get_children():
		var res := _find_tab_container(child)
		if res != null:
			return res
	return null


func _is_in_3d_gameplay() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var cur_scene := tree.current_scene
	if cur_scene == null:
		return false
	var scene_name := str(cur_scene.name).to_lower()
	var path: String = ""
	if cur_scene.get_script() != null:
		path = str(cur_scene.get_script().resource_path).to_lower()

	# Menu screens, setup screens, creators, or dialogs are never 3D gameplay
	if scene_name.contains("setup") or path.contains("setup") or \
	   scene_name.contains("menu") or path.contains("menu") or \
	   scene_name.contains("dialog") or path.contains("dialog") or \
	   scene_name.contains("creator") or path.contains("creator"):
		return false

	if scene_name == "courseplay" or scene_name == "range" or scene_name == "coursemanager":
		return true
	if path.ends_with("course_play.gd") or path.ends_with("range.gd"):
		return true
	return false


func _is_aim_input(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return false
	if event is InputEventJoypadButton:
		var btn: int = event.button_index
		if (btn == JOY_BUTTON_DPAD_UP or btn == JOY_BUTTON_DPAD_DOWN or
			btn == JOY_BUTTON_DPAD_LEFT or btn == JOY_BUTTON_DPAD_RIGHT):
			return true
	if event is InputEventKey:
		var kc: Key = event.keycode
		if kc == KEY_NONE:
			kc = event.physical_keycode
		if kc == KEY_LEFT or kc == KEY_RIGHT or kc == KEY_UP or kc == KEY_DOWN:
			return true
	if event.is_action("aim_left") or event.is_action("aim_right") or \
	   event.is_action("aim_forward") or event.is_action("aim_backward"):
		return true
	return false
