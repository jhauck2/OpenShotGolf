class_name SettingsPanelStyles
extends RefCounted

const TEXT_PRIMARY := Color(0.91, 0.95, 1, 1)
const TEXT_BUTTON := Color(0.96, 0.98, 1, 1)
const TEXT_HELPER := Color(0.72, 0.80, 0.88, 0.96)
const PLACEHOLDER := Color(0.82, 0.88, 0.94, 0.60)
const CARD_BG := Color(0.063, 0.086, 0.125, 0.72)
const CARD_BORDER := Color(1, 1, 1, 0.20)
const FIELD_BG := Color(0.039, 0.071, 0.110, 0.96)
const FIELD_BG_FOCUS := Color(0.039, 0.071, 0.110, 0.98)
const FIELD_BORDER := Color(1, 1, 1, 0.20)
const FIELD_BORDER_FOCUS := Color(0.337, 0.698, 0.937, 0.80)
const PRIMARY_BG := Color(0.129, 0.529, 0.824, 0.96)
const PRIMARY_BG_HOVER := Color(0.188, 0.616, 0.902, 0.98)
const PRIMARY_BORDER := Color(1, 1, 1, 0.35)
const PRIMARY_BORDER_HOVER := Color(1, 1, 1, 0.45)
const SECONDARY_BG := Color(0.063, 0.086, 0.125, 0.95)
const SECONDARY_BG_HOVER := Color(0.090, 0.133, 0.192, 0.98)
const SECONDARY_BORDER := Color(0.337, 0.698, 0.937, 0.60)
const SECONDARY_BORDER_HOVER := Color(0.337, 0.698, 0.937, 0.80)


static func make_scroll_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "%sContent" % tab_name
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	return content


static func make_card(parent: Container, card_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.add_theme_stylebox_override("panel", make_style_box(CARD_BG, CARD_BORDER, 1, 8))
	parent.add_child(card)
	return card


static func make_card_content(card: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "%sMargin" % card.name
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "%sContent" % card.name
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	return content


static func make_row_card(parent: Container, card_name: String, label_text: String) -> HBoxContainer:
	var card := make_card(parent, card_name)
	return make_card_row(card, label_text)


static func make_card_row(card: PanelContainer, label_text: String) -> HBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "%sMargin" % card.name
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var row := make_labeled_row(label_text)
	margin.add_child(row)
	return row


static func make_labeled_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(210, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	return row


static func make_control_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	return row


static func make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	label.add_theme_font_size_override("font_size", 20)
	return label


static func make_helper_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_HELPER)
	label.add_theme_font_size_override("font_size", 15)
	return label


static func make_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


static func make_button(text: String, is_primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT_BUTTON)
	button.add_theme_color_override("font_hover_color", TEXT_BUTTON)
	button.add_theme_color_override("font_pressed_color", TEXT_BUTTON)
	button.add_theme_color_override("font_focus_color", TEXT_BUTTON)

	var normal_bg := PRIMARY_BG if is_primary else SECONDARY_BG
	var hover_bg := PRIMARY_BG_HOVER if is_primary else SECONDARY_BG_HOVER
	var normal_border := PRIMARY_BORDER if is_primary else SECONDARY_BORDER
	var hover_border := PRIMARY_BORDER_HOVER if is_primary else SECONDARY_BORDER_HOVER

	button.add_theme_stylebox_override("normal", make_button_style(normal_bg, normal_border))
	button.add_theme_stylebox_override("hover", make_button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", make_button_style(normal_bg, normal_border))
	button.add_theme_stylebox_override("focus", make_button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("disabled", make_button_style(normal_bg, normal_border))
	return button


static func apply_field_style(control: Control) -> void:
	control.add_theme_stylebox_override("normal", make_field_style(FIELD_BG, FIELD_BORDER))
	control.add_theme_stylebox_override("hover", make_field_style(FIELD_BG_FOCUS, FIELD_BORDER_FOCUS))
	control.add_theme_stylebox_override("pressed", make_field_style(FIELD_BG, FIELD_BORDER))
	control.add_theme_stylebox_override("focus", make_field_style(FIELD_BG_FOCUS, FIELD_BORDER_FOCUS))
	control.add_theme_stylebox_override("read_only", make_field_style(FIELD_BG, FIELD_BORDER))
	control.add_theme_stylebox_override("disabled", make_field_style(FIELD_BG, FIELD_BORDER))
	control.add_theme_color_override("font_color", TEXT_BUTTON)
	control.add_theme_color_override("font_hover_color", TEXT_BUTTON)
	control.add_theme_color_override("font_pressed_color", TEXT_BUTTON)
	control.add_theme_color_override("font_focus_color", TEXT_BUTTON)
	control.add_theme_color_override("font_placeholder_color", PLACEHOLDER)
	control.add_theme_font_size_override("font_size", 18)


static func apply_check_style(check_box: CheckBox) -> void:
	check_box.add_theme_color_override("font_color", TEXT_PRIMARY)
	check_box.add_theme_font_size_override("font_size", 20)


static func make_style_box(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int,
	all_borders: bool = true
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	if all_borders:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	else:
		style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style


static func make_tab_style(bg_color: Color, top_radius: int, bottom_radius: int) -> StyleBoxFlat:
	var style := make_style_box(bg_color, Color(1, 1, 1, 0.25), 1, top_radius)
	style.corner_radius_bottom_left = bottom_radius
	style.corner_radius_bottom_right = bottom_radius
	style.content_margin_left = 20.0
	style.content_margin_top = 10.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 8.0
	return style


static func make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := make_style_box(bg_color, border_color, 1, 7)
	style.content_margin_left = 16.0
	style.content_margin_top = 7.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 7.0
	return style


static func make_field_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := make_style_box(bg_color, border_color, 1, 6)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


static func set_centered_rect(control: Control, width: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -width * 0.5
	control.offset_top = -height * 0.5
	control.offset_right = width * 0.5
	control.offset_bottom = height * 0.5


static func build_panel_toggle_icon(is_checked: bool) -> Texture2D:
	const SIZE := 16
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var fill := Color(0.070, 0.149, 0.243, 1.0)
	var border := Color(0.820, 0.900, 0.980, 1.0)
	var check := Color(0.929, 0.969, 1.0, 1.0)
	image.fill(fill)

	for index in range(SIZE):
		image.set_pixel(index, 0, border)
		image.set_pixel(index, SIZE - 1, border)
		image.set_pixel(0, index, border)
		image.set_pixel(SIZE - 1, index, border)

	if is_checked:
		for index in range(4):
			image.set_pixel(3 + index, 8 + index, check)
			image.set_pixel(4 + index, 8 + index, check)

		for index in range(6):
			image.set_pixel(6 + index, 10 - index, check)
			image.set_pixel(6 + index, 9 - index, check)

	return ImageTexture.create_from_image(image)


static func apply_panel_toggle_icons(toggle: CheckBox, checked: Texture2D, unchecked: Texture2D) -> void:
	if toggle == null:
		return
	if checked != null:
		toggle.add_theme_icon_override("checked", checked)
		toggle.add_theme_icon_override("checked_disabled", checked)
		toggle.add_theme_icon_override("radio_checked", checked)
	if unchecked != null:
		toggle.add_theme_icon_override("unchecked", unchecked)
		toggle.add_theme_icon_override("unchecked_disabled", unchecked)
		toggle.add_theme_icon_override("radio_unchecked", unchecked)
