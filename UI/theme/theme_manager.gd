class_name ThemeManager
extends Node

# --- Heckle Golf Simulator Design System Tokens ---

# Palette Colors
const COLOR_BG_OVERLAY = Color(0.05, 0.08, 0.11, 0.88)
const COLOR_GLASS_PANEL = Color(0.07, 0.11, 0.16, 0.85)
const COLOR_GLASS_BORDER = Color(0.24, 0.44, 0.65, 0.4)

const COLOR_PRIMARY_NORMAL = Color(0.14, 0.52, 0.28)
const COLOR_PRIMARY_HOVER = Color(0.18, 0.65, 0.35)
const COLOR_PRIMARY_PRESSED = Color(0.10, 0.42, 0.22)

const COLOR_SECONDARY_NORMAL = Color(0.18, 0.34, 0.50)
const COLOR_SECONDARY_HOVER = Color(0.24, 0.44, 0.65)
const COLOR_SECONDARY_PRESSED = Color(0.14, 0.26, 0.38)

const COLOR_NAV_NORMAL = Color(0.13, 0.17, 0.23, 0.85)
const COLOR_NAV_HOVER = Color(0.20, 0.27, 0.36, 0.95)
const COLOR_NAV_PRESSED = Color(0.09, 0.12, 0.16, 0.95)

const COLOR_DANGER_NORMAL = Color(0.65, 0.20, 0.20)
const COLOR_DANGER_HOVER = Color(0.80, 0.26, 0.26)
const COLOR_DANGER_PRESSED = Color(0.50, 0.15, 0.15)

const COLOR_INPUT_BG = Color(0.08, 0.12, 0.17, 0.90)
const COLOR_INPUT_BORDER = Color(0.24, 0.44, 0.65, 0.5)

const COLOR_TEXT_WHITE = Color(0.96, 0.98, 1.0)
const COLOR_TEXT_MUTED = Color(0.70, 0.76, 0.84)
const COLOR_TEXT_DIM = Color(0.50, 0.56, 0.64)

# High-contrast, mobile-readable semantic text tokens
const COLOR_TEXT_GOLD = Color(1.0, 0.85, 0.38)       # Warm rich gold for scorecard totals, winner highlights
const COLOR_TEXT_WARNING = Color(1.0, 0.82, 0.32)    # High-contrast warm amber for warnings / alerts
const COLOR_TEXT_DANGER = Color(1.0, 0.42, 0.42)     # High-luminance coral red (clearly readable on dark backgrounds)
const COLOR_TEXT_SUCCESS = Color(0.35, 0.95, 0.55)   # Vibrant mint green for under-par and ready states
const COLOR_TEXT_ACCENT = Color(0.35, 0.82, 1.0)     # Crisp vivid cyan for section titles and headers
const COLOR_SUCCESS = COLOR_TEXT_SUCCESS

# --- Helper Methods for Button Styling ---

static func apply_primary_button_style(btn: Button, corner_radius: int = 8) -> void:
	_apply_button_styles(
		btn,
		_create_stylebox(COLOR_PRIMARY_NORMAL, COLOR_PRIMARY_NORMAL.lightened(0.2), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_PRIMARY_HOVER, Color(1, 1, 1, 0.3), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_PRIMARY_PRESSED, Color(1, 1, 1, 0.2), corner_radius, 1, 18, 12, 18, 12),
		COLOR_TEXT_WHITE
	)

static func apply_secondary_button_style(btn: Button, corner_radius: int = 8) -> void:
	_apply_button_styles(
		btn,
		_create_stylebox(COLOR_SECONDARY_NORMAL, COLOR_SECONDARY_NORMAL.lightened(0.2), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_SECONDARY_HOVER, Color(1, 1, 1, 0.3), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_SECONDARY_PRESSED, Color(1, 1, 1, 0.2), corner_radius, 1, 18, 12, 18, 12),
		COLOR_TEXT_WHITE
	)

static func apply_nav_button_style(btn: Button, corner_radius: int = 8) -> void:
	_apply_button_styles(
		btn,
		_create_stylebox(COLOR_NAV_NORMAL, Color(1, 1, 1, 0.15), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_NAV_HOVER, Color(1, 1, 1, 0.30), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_NAV_PRESSED, Color(1, 1, 1, 0.10), corner_radius, 1, 18, 12, 18, 12),
		COLOR_TEXT_WHITE
	)

static func apply_tab_button_style(btn: Button, is_active: bool, corner_radius: int = 8) -> void:
	if btn == null:
		return
	btn.disabled = false
	if is_active:
		var normal_box = _create_stylebox(Color(0.18, 0.34, 0.50, 0.95), Color(0.35, 0.82, 1.0, 0.95), corner_radius, 2, 18, 10, 18, 10)
		var hover_box = _create_stylebox(Color(0.22, 0.40, 0.58, 0.95), Color(0.45, 0.90, 1.0, 1.0), corner_radius, 2, 18, 10, 18, 10)
		var pressed_box = _create_stylebox(Color(0.14, 0.28, 0.42, 0.95), Color(0.35, 0.82, 1.0, 0.95), corner_radius, 2, 18, 10, 18, 10)
		_apply_button_styles(btn, normal_box, hover_box, pressed_box, COLOR_TEXT_GOLD)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT_GOLD)
		btn.add_theme_color_override("font_focus_color", COLOR_TEXT_GOLD)
	else:
		var normal_box = _create_stylebox(Color(0.08, 0.12, 0.18, 0.70), Color(0.24, 0.44, 0.65, 0.30), corner_radius, 1, 18, 10, 18, 10)
		var hover_box = _create_stylebox(Color(0.15, 0.22, 0.32, 0.85), Color(0.35, 0.65, 0.95, 0.60), corner_radius, 1, 18, 10, 18, 10)
		var pressed_box = _create_stylebox(Color(0.06, 0.09, 0.14, 0.85), Color(0.24, 0.44, 0.65, 0.30), corner_radius, 1, 18, 10, 18, 10)
		_apply_button_styles(btn, normal_box, hover_box, pressed_box, COLOR_TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT_WHITE)
		btn.add_theme_color_override("font_focus_color", COLOR_TEXT_WHITE)

static func apply_icon_button_style(btn: Button, corner_radius: int = 8, padding: int = 12) -> void:
	_apply_button_styles(
		btn,
		_create_stylebox(COLOR_NAV_NORMAL, Color(1, 1, 1, 0.15), corner_radius, 1, padding, padding, padding, padding),
		_create_stylebox(COLOR_NAV_HOVER, Color(1, 1, 1, 0.30), corner_radius, 1, padding, padding, padding, padding),
		_create_stylebox(COLOR_NAV_PRESSED, Color(1, 1, 1, 0.10), corner_radius, 1, padding, padding, padding, padding),
		COLOR_TEXT_WHITE
	)

static func apply_danger_button_style(btn: Button, corner_radius: int = 8) -> void:
	_apply_button_styles(
		btn,
		_create_stylebox(COLOR_DANGER_NORMAL, COLOR_DANGER_NORMAL.lightened(0.2), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_DANGER_HOVER, Color(1, 1, 1, 0.3), corner_radius, 1, 18, 12, 18, 12),
		_create_stylebox(COLOR_DANGER_PRESSED, Color(1, 1, 1, 0.2), corner_radius, 1, 18, 12, 18, 12),
		COLOR_TEXT_WHITE
	)

static func apply_card_panel_style(panel: Control, is_highlighted: bool = false, corner_radius: int = 12, m_left: int = 16, m_top: int = 16, m_right: int = 16, m_bottom: int = 16) -> void:
	var bg = COLOR_GLASS_PANEL if not is_highlighted else Color(0.10, 0.16, 0.24, 0.90)
	var border = COLOR_GLASS_BORDER if not is_highlighted else Color(0.35, 0.65, 0.95, 0.6)
	var style = _create_stylebox(bg, border, corner_radius, 1, m_left, m_top, m_right, m_bottom)
	if panel is PanelContainer or panel is Panel:
		panel.add_theme_stylebox_override("panel", style)

static func apply_data_panel_style(panel: Control, is_highlighted: bool = false) -> void:
	if panel != null:
		panel.clip_contents = true
	var bg = COLOR_GLASS_PANEL if not is_highlighted else Color(0.10, 0.16, 0.24, 0.90)
	var border = COLOR_GLASS_BORDER if not is_highlighted else Color(0.35, 0.65, 0.95, 0.6)
	var style = _create_stylebox(bg, border, 8, 1, 8, 4, 8, 4)
	if panel is PanelContainer or panel is Panel:
		panel.add_theme_stylebox_override("panel", style)

static func apply_add_remove_tile_style(btn: Button) -> void:
	var corner_radius = 8
	var normal_box = _create_stylebox(COLOR_GLASS_PANEL, Color(0.30, 0.55, 0.80, 0.6), corner_radius, 1, 6, 4, 6, 4)
	var hover_box = _create_stylebox(Color(0.12, 0.20, 0.30, 0.92), Color(0.45, 0.75, 1.0, 0.9), corner_radius, 1, 6, 4, 6, 4)
	var pressed_box = _create_stylebox(Color(0.08, 0.14, 0.22, 0.95), Color(0.25, 0.50, 0.75, 0.9), corner_radius, 1, 6, 4, 6, 4)
	_apply_button_styles(btn, normal_box, hover_box, pressed_box, COLOR_TEXT_WHITE)

static func apply_modal_style(panel: Control, corner_radius: int = 12) -> void:
	var style = _create_stylebox(COLOR_GLASS_PANEL, COLOR_GLASS_BORDER, corner_radius, 1, 20, 20, 20, 20)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	if panel is PanelContainer or panel is Panel:
		panel.add_theme_stylebox_override("panel", style)

static func apply_input_style(control: Control, corner_radius: int = 6) -> void:
	var normal_style = _create_stylebox(COLOR_INPUT_BG, COLOR_INPUT_BORDER, corner_radius, 1, 12, 10, 12, 10)
	var focus_style = _create_stylebox(COLOR_INPUT_BG, COLOR_SECONDARY_HOVER, corner_radius, 2, 12, 10, 12, 10)
	if control is LineEdit:
		control.add_theme_stylebox_override("normal", normal_style)
		control.add_theme_stylebox_override("focus", focus_style)
		control.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
		control.add_theme_color_override("placeholder_color", COLOR_TEXT_DIM)
		if control.custom_minimum_size.y < 48:
			control.custom_minimum_size.y = 48

static func apply_scrollbar_style(scrollbar: ScrollBar, width: int = -1) -> void:
	if scrollbar == null:
		return
	var is_mob = MobilePerformance.is_mobile()
	var effective_width = width
	if effective_width <= 0:
		effective_width = 56 if is_mob else 28
	elif is_mob and effective_width < 52:
		effective_width = 56

	if scrollbar is VScrollBar:
		scrollbar.custom_minimum_size = Vector2(effective_width, 0)
	else:
		scrollbar.custom_minimum_size = Vector2(0, effective_width)
	
	var corner_rad = 12 if is_mob else 8
	var pad = 4 if is_mob else 2
	var track_style = _create_stylebox(
		Color(0.04, 0.07, 0.11, 0.75),
		Color(0.24, 0.44, 0.65, 0.40),
		corner_rad, 1,
		pad + 1, pad + 1, pad + 1, pad + 1
	)
	var grabber_normal = _create_stylebox(
		COLOR_SECONDARY_HOVER,
		Color(0.45, 0.70, 0.95, 0.75),
		corner_rad, 1,
		pad, 14 if is_mob else 4, pad, 14 if is_mob else 4
	)
	var grabber_hover = _create_stylebox(
		Color(0.35, 0.65, 0.95, 0.95),
		Color(0.75, 0.90, 1.0, 0.90),
		corner_rad, 1,
		pad, 14 if is_mob else 4, pad, 14 if is_mob else 4
	)
	var grabber_pressed = _create_stylebox(
		COLOR_PRIMARY_HOVER,
		Color(0.80, 1.0, 0.80, 0.95),
		corner_rad, 1,
		pad, 14 if is_mob else 4, pad, 14 if is_mob else 4
	)

	scrollbar.add_theme_stylebox_override("scroll", track_style)
	scrollbar.add_theme_stylebox_override("scroll_focus", track_style)
	scrollbar.add_theme_stylebox_override("grabber", grabber_normal)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)

static func apply_scroll_container_style(scroll: ScrollContainer, width: int = -1) -> void:
	if scroll == null:
		return
	var v_bar = scroll.get_v_scroll_bar()
	if v_bar != null:
		apply_scrollbar_style(v_bar, width)
	var h_bar = scroll.get_h_scroll_bar()
	if h_bar != null:
		apply_scrollbar_style(h_bar, width)
	TouchScrollHelper.attach_to(scroll)

static func apply_item_list_style(list: ItemList, scrollbar_width: int = -1) -> void:
	if list == null:
		return
	var is_mob = MobilePerformance.is_mobile()
	var effective_width = scrollbar_width
	if effective_width <= 0:
		effective_width = 56 if is_mob else 28
	elif is_mob and effective_width < 52:
		effective_width = 56

	var v_bar = list.get_v_scroll_bar()
	if v_bar != null:
		apply_scrollbar_style(v_bar, effective_width)
	var h_bar = list.get_h_scroll_bar()
	if h_bar != null:
		apply_scrollbar_style(h_bar, effective_width)

	# Clean glass panel with right padding so items don't overlap the scrollbar
	var list_panel = _create_stylebox(
		Color(0.05, 0.08, 0.12, 0.50),
		Color(0.24, 0.44, 0.65, 0.25),
		8, 1,
		14, 10, effective_width + 12, 10
	)
	list.add_theme_stylebox_override("panel", list_panel)

	# Ensure item vertical separation is touch-friendly
	if is_mob:
		var curr_v_sep = list.get_theme_constant("v_separation")
		if curr_v_sep < 24:
			list.add_theme_constant_override("v_separation", 24)

	# Keep scrollbar width enforced if layout recalculates
	if not list.resized.is_connected(_on_item_list_resized):
		list.resized.connect(_on_item_list_resized.bind(list, effective_width))

	TouchScrollHelper.attach_to(list)

static func _on_item_list_resized(list: ItemList, effective_width: int) -> void:
	if list == null:
		return
	var v_bar = list.get_v_scroll_bar()
	if v_bar != null and v_bar.custom_minimum_size.x != effective_width:
		v_bar.custom_minimum_size = Vector2(effective_width, 0)

static func _apply_button_styles(btn: Button, style_normal: StyleBoxFlat, style_hover: StyleBoxFlat, style_pressed: StyleBoxFlat, text_color: Color) -> void:
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	var style_focus = style_hover.duplicate()
	style_focus.border_color = Color(0.35, 0.82, 1.0, 0.95)
	style_focus.border_width_left = maxi(style_hover.border_width_left, 2)
	style_focus.border_width_top = maxi(style_hover.border_width_top, 2)
	style_focus.border_width_right = maxi(style_hover.border_width_right, 2)
	style_focus.border_width_bottom = maxi(style_hover.border_width_bottom, 2)
	btn.add_theme_stylebox_override("focus", style_focus)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	if btn.custom_minimum_size.y < 48:
		btn.custom_minimum_size.y = 48
	if not btn.has_theme_font_size_override("font_size"):
		btn.add_theme_font_size_override("font_size", 16)
	elif btn.get_theme_font_size("font_size") < 15:
		btn.add_theme_font_size_override("font_size", 16)

static func _create_stylebox(bg: Color, border: Color, corner_radius: int, border_width: int, m_left: int, m_top: int, m_right: int, m_bottom: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.content_margin_left = m_left
	style.content_margin_top = m_top
	style.content_margin_right = m_right
	style.content_margin_bottom = m_bottom
	return style

static var _slider_grabber_normal: Texture2D = null
static var _slider_grabber_hover: Texture2D = null
static var _slider_grabber_pressed: Texture2D = null
static var _slider_grabber_normal_mob: Texture2D = null
static var _slider_grabber_hover_mob: Texture2D = null
static var _slider_grabber_pressed_mob: Texture2D = null

static func get_slider_grabber_icon(state: String = "normal", is_mob: bool = false) -> Texture2D:
	if is_mob:
		if state == "hover" and _slider_grabber_hover_mob != null:
			return _slider_grabber_hover_mob
		if state == "pressed" and _slider_grabber_pressed_mob != null:
			return _slider_grabber_pressed_mob
		if state == "normal" and _slider_grabber_normal_mob != null:
			return _slider_grabber_normal_mob
	else:
		if state == "hover" and _slider_grabber_hover != null:
			return _slider_grabber_hover
		if state == "pressed" and _slider_grabber_pressed != null:
			return _slider_grabber_pressed
		if state == "normal" and _slider_grabber_normal != null:
			return _slider_grabber_normal

	var size = 36 if is_mob else 28
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var radius = (size - 4) * 0.5
	var border_w = 2.5 if is_mob else 2.0
	var dot_r = 3.5 if is_mob else 2.5

	var fill_col = Color(0.94, 0.97, 1.0, 1.0)
	var border_col = Color(0.35, 0.82, 1.0, 1.0)
	var dot_col = Color(0.18, 0.38, 0.60, 1.0)
	var shadow_col = Color(0.0, 0.0, 0.0, 0.4)

	if state == "hover":
		fill_col = Color(1.0, 1.0, 1.0, 1.0)
		border_col = Color(0.55, 0.92, 1.0, 1.0)
		dot_col = Color(0.24, 0.55, 0.85, 1.0)
	elif state == "pressed":
		fill_col = Color(0.85, 1.0, 0.92, 1.0)
		border_col = Color(0.35, 0.95, 0.55, 1.0)
		dot_col = Color(0.12, 0.50, 0.25, 1.0)

	for y in range(size):
		for x in range(size):
			var d = center.distance_to(Vector2(x, y))
			if d <= dot_r:
				img.set_pixel(x, y, dot_col)
			elif d <= radius - border_w:
				img.set_pixel(x, y, fill_col)
			elif d <= radius:
				img.set_pixel(x, y, border_col)
			elif d <= radius + 1.2:
				var alpha = 1.0 - (d - radius) / 1.2
				img.set_pixel(x, y, Color(border_col.r, border_col.g, border_col.b, border_col.a * alpha))
			elif d <= radius + 2.0:
				var s_alpha = (1.0 - (d - (radius + 1.0))) * shadow_col.a
				img.set_pixel(x, y, Color(0, 0, 0, s_alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	var tex = ImageTexture.create_from_image(img)
	if is_mob:
		if state == "hover":
			_slider_grabber_hover_mob = tex
		elif state == "pressed":
			_slider_grabber_pressed_mob = tex
		else:
			_slider_grabber_normal_mob = tex
	else:
		if state == "hover":
			_slider_grabber_hover = tex
		elif state == "pressed":
			_slider_grabber_pressed = tex
		else:
			_slider_grabber_normal = tex
	return tex

static func apply_slider_style(slider: Slider, min_height: int = -1, min_width: int = -1) -> void:
	if slider == null:
		return
	var is_mob = MobilePerformance.is_mobile()
	var effective_height = min_height
	if effective_height <= 0:
		effective_height = 48 if is_mob else 36
	elif is_mob and effective_height < 44:
		effective_height = 48

	var current_min = slider.custom_minimum_size
	var target_w = maxf(current_min.x, float(min_width) if min_width > 0 else (100.0 if is_mob else 70.0))
	var target_h = maxf(current_min.y, float(effective_height))
	slider.custom_minimum_size = Vector2(target_w, target_h)
	slider.focus_mode = Control.FOCUS_ALL

	var grab_normal = get_slider_grabber_icon("normal", is_mob)
	var grab_hover = get_slider_grabber_icon("hover", is_mob)
	var grab_pressed = get_slider_grabber_icon("pressed", is_mob)

	slider.add_theme_icon_override("grabber", grab_normal)
	slider.add_theme_icon_override("grabber_highlight", grab_hover)
	slider.add_theme_icon_override("grabber_disabled", grab_normal)
	slider.add_theme_constant_override("center_grabber", 1)

	var corner_rad = 5 if is_mob else 4
	var margin_v = 5 if is_mob else 4

	var track_bg = StyleBoxFlat.new()
	track_bg.bg_color = Color(0.08, 0.12, 0.18, 0.90)
	track_bg.border_color = Color(0.24, 0.44, 0.65, 0.45)
	track_bg.border_width_left = 1
	track_bg.border_width_right = 1
	track_bg.border_width_top = 1
	track_bg.border_width_bottom = 1
	track_bg.corner_radius_top_left = corner_rad
	track_bg.corner_radius_top_right = corner_rad
	track_bg.corner_radius_bottom_right = corner_rad
	track_bg.corner_radius_bottom_left = corner_rad
	track_bg.content_margin_top = margin_v
	track_bg.content_margin_bottom = margin_v

	var track_fill = StyleBoxFlat.new()
	track_fill.bg_color = Color(0.22, 0.58, 0.90, 0.95)
	track_fill.corner_radius_top_left = corner_rad
	track_fill.corner_radius_bottom_left = corner_rad
	track_fill.content_margin_top = margin_v
	track_fill.content_margin_bottom = margin_v

	var track_fill_hi = StyleBoxFlat.new()
	track_fill_hi.bg_color = Color(0.32, 0.72, 1.0, 1.0)
	track_fill_hi.corner_radius_top_left = corner_rad
	track_fill_hi.corner_radius_bottom_left = corner_rad
	track_fill_hi.content_margin_top = margin_v
	track_fill_hi.content_margin_bottom = margin_v

	slider.add_theme_stylebox_override("slider", track_bg)
	slider.add_theme_stylebox_override("grabber_area", track_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", track_fill_hi)

static var _dialog_close_icon_normal: Texture2D = null
static var _dialog_close_icon_pressed: Texture2D = null

static func get_dialog_close_icon(pressed: bool = false) -> Texture2D:
	if pressed and _dialog_close_icon_pressed != null:
		return _dialog_close_icon_pressed
	if not pressed and _dialog_close_icon_normal != null:
		return _dialog_close_icon_normal

	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg_color = Color(0.65, 0.20, 0.20, 0.95) if pressed else Color(0.16, 0.24, 0.34, 0.85)
	var border_color = Color(0.9, 0.4, 0.4, 0.9) if pressed else Color(0.35, 0.55, 0.75, 0.7)
	var x_color = Color(1.0, 1.0, 1.0, 1.0)
	
	# Draw rounded circular badge background
	var center = Vector2(size * 0.5, size * 0.5)
	var radius = size * 0.46
	var radius_sq = radius * radius
	var inner_radius_sq = (radius - 1.5) * (radius - 1.5)
	for y in range(size):
		for x in range(size):
			var dist_sq = (Vector2(x, y) - center).length_squared()
			if dist_sq <= inner_radius_sq:
				img.set_pixel(x, y, bg_color)
			elif dist_sq <= radius_sq:
				img.set_pixel(x, y, border_color)

	# Draw crisp thick 'X'
	for i in range(10, 22):
		for t in range(-1, 2):
			var px1 = i
			var py1 = i + t
			var px2 = size - 1 - i
			var py2 = i + t
			if px1 >= 0 and px1 < size and py1 >= 0 and py1 < size:
				img.set_pixel(px1, py1, x_color)
			if px2 >= 0 and px2 < size and py2 >= 0 and py2 < size:
				img.set_pixel(px2, py2, x_color)

	var tex = ImageTexture.create_from_image(img)
	if pressed:
		_dialog_close_icon_pressed = tex
	else:
		_dialog_close_icon_normal = tex
	return tex

static func apply_option_button_style(opt: OptionButton, font_size: int = 20, min_size: Vector2 = Vector2(180, 52)) -> void:
	if opt == null:
		return
	opt.custom_minimum_size = min_size
	opt.add_theme_font_size_override("font_size", font_size)
	opt.expand_icon = true
	opt.add_theme_constant_override("icon_max_width", 28)
	apply_secondary_button_style(opt, 8)

	var popup = opt.get_popup()
	if popup != null:
		style_popup_menu(popup, font_size)

static func style_popup_menu(popup: PopupMenu, font_size: int = 20) -> void:
	if popup == null:
		return
	popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_constant_override("v_separation", 8)
	popup.add_theme_constant_override("item_start_padding", 14)
	popup.add_theme_constant_override("item_end_padding", 14)
	popup.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	popup.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	
	var panel_style = _create_stylebox(COLOR_GLASS_PANEL, COLOR_GLASS_BORDER, 10, 1, 10, 10, 10, 10)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 12
	popup.add_theme_stylebox_override("panel", panel_style)
	
	var hover_style = _create_stylebox(COLOR_SECONDARY_HOVER, Color(0.40, 0.65, 0.90, 0.5), 6, 1, 12, 6, 12, 6)
	popup.add_theme_stylebox_override("hover", hover_style)

static func apply_dialog_style(dialog: AcceptDialog, min_button_size: Vector2 = Vector2(150, 52), font_size: int = 18) -> void:
	if dialog == null:
		return
		
	dialog.add_theme_font_size_override("title_font_size", 22)
	dialog.add_theme_color_override("title_color", COLOR_TEXT_WHITE)
	dialog.add_theme_constant_override("title_height", 48)
	dialog.add_theme_constant_override("close_h_offset", 34)
	dialog.add_theme_constant_override("close_v_offset", 24)
	dialog.add_theme_constant_override("buttons_separation", 24)

	var close_normal = get_dialog_close_icon(false)
	var close_pressed = get_dialog_close_icon(true)
	dialog.add_theme_icon_override("close", close_normal)
	dialog.add_theme_icon_override("close_pressed", close_pressed)

	var border_style = _create_stylebox(COLOR_GLASS_PANEL, COLOR_GLASS_BORDER, 12, 1, 16, 16, 16, 16)
	dialog.add_theme_stylebox_override("embedded_border", border_style)
	dialog.add_theme_stylebox_override("panel", border_style)

	var ok_btn = dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.custom_minimum_size = min_button_size
		ok_btn.add_theme_font_size_override("font_size", font_size)
		apply_primary_button_style(ok_btn)

	if dialog is ConfirmationDialog:
		var cancel_btn = (dialog as ConfirmationDialog).get_cancel_button()
		if cancel_btn != null:
			cancel_btn.custom_minimum_size = min_button_size
			cancel_btn.add_theme_font_size_override("font_size", font_size)
			apply_secondary_button_style(cancel_btn)

	var label = dialog.get_label()
	if label != null:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)

	# Re-enforce sizing on about_to_popup to prevent engine resets
	if not dialog.about_to_popup.is_connected(_on_dialog_about_to_popup):
		dialog.about_to_popup.connect(_on_dialog_about_to_popup.bind(dialog, min_button_size, font_size))

static func _on_dialog_about_to_popup(dialog: AcceptDialog, min_button_size: Vector2, font_size: int) -> void:
	if dialog == null:
		return
	var ok_btn = dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.custom_minimum_size = min_button_size
		ok_btn.add_theme_font_size_override("font_size", font_size)
		apply_primary_button_style(ok_btn)
	if dialog is ConfirmationDialog:
		var cancel_btn = (dialog as ConfirmationDialog).get_cancel_button()
		if cancel_btn != null:
			cancel_btn.custom_minimum_size = min_button_size
			cancel_btn.add_theme_font_size_override("font_size", font_size)
			apply_secondary_button_style(cancel_btn)
	var label = dialog.get_label()
	if label != null:
		label.add_theme_font_size_override("font_size", 18)

static var _checkbox_unchecked_icon: Texture2D = null
static var _checkbox_checked_icon: Texture2D = null
static var _checkbox_unchecked_disabled_icon: Texture2D = null
static var _checkbox_checked_disabled_icon: Texture2D = null

const SVG_CHECKBOX_UNCHECKED = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="5" fill="#142132" stroke="#6098cc" stroke-width="2.2"/></svg>'
const SVG_CHECKBOX_CHECKED = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="5" fill="#156e34" stroke="#4ade80" stroke-width="2.2"/><path d="M6 12.5 L10 16.5 L18 8.5" fill="none" stroke="#ffffff" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
const SVG_CHECKBOX_UNCHECKED_DISABLED = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="5" fill="#0f1722" stroke="#334d66" stroke-width="1.8"/></svg>'
const SVG_CHECKBOX_CHECKED_DISABLED = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="5" fill="#1a3b25" stroke="#2e6d42" stroke-width="1.8"/><path d="M6 12.5 L10 16.5 L18 8.5" fill="none" stroke="#8fa896" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>'

static func _init_checkbox_icons() -> void:
	_checkbox_unchecked_icon = _svg_to_texture(SVG_CHECKBOX_UNCHECKED)
	_checkbox_checked_icon = _svg_to_texture(SVG_CHECKBOX_CHECKED)
	_checkbox_unchecked_disabled_icon = _svg_to_texture(SVG_CHECKBOX_UNCHECKED_DISABLED)
	_checkbox_checked_disabled_icon = _svg_to_texture(SVG_CHECKBOX_CHECKED_DISABLED)

static func _svg_to_texture(svg_code: String) -> Texture2D:
	var img = Image.new()
	if img.load_svg_from_string(svg_code, 1.0) == OK:
		return ImageTexture.create_from_image(img)
	return null

static func apply_checkbox_style(cb: CheckBox) -> void:
	if cb == null:
		return
	if _checkbox_unchecked_icon == null:
		_init_checkbox_icons()
	if _checkbox_unchecked_icon != null:
		cb.add_theme_icon_override("unchecked", _checkbox_unchecked_icon)
	if _checkbox_checked_icon != null:
		cb.add_theme_icon_override("checked", _checkbox_checked_icon)
	if _checkbox_unchecked_disabled_icon != null:
		cb.add_theme_icon_override("unchecked_disabled", _checkbox_unchecked_disabled_icon)
	if _checkbox_checked_disabled_icon != null:
		cb.add_theme_icon_override("checked_disabled", _checkbox_checked_disabled_icon)
	cb.add_theme_constant_override("h_separation", 10)
	cb.add_theme_constant_override("check_v_offset", 0)
	cb.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	cb.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	cb.add_theme_color_override("font_pressed_color", Color(0.4, 0.85, 0.55))
	cb.add_theme_color_override("font_hover_pressed_color", Color(0.5, 0.95, 0.65))

