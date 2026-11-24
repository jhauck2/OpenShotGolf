extends Node

signal scene_changed

var current_scene = null
var _is_changing_scene: bool = false
var _pending_scene_path: String = ""
var _loading_screen: CanvasLayer = null
var _loading_progress_bar: ProgressBar = null
var _loading_percent_label: Label = null
var _loading_status_label: Label = null
var _loading_target_percent: float = 0.0
var _loading_current_percent: float = 0.0
var _loading_stage_cap: float = 4.0


const CourseGraphicsUpgraderScript = preload("res://Utils/CourseGraphicsUpgrader.gd")


func _ready() -> void:
	MobilePerformance.apply_global_render_settings(get_tree())
	if DisplayServer.get_name() != "headless":
		call_deferred("_run_startup_course_upgrader")


func _run_startup_course_upgrader() -> void:
	for raw_arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges()
		if arg.begins_with("--screenshot=") or arg.begins_with("--capture-screenshot=") or arg == "--capture" or arg == "--write-movie":
			return
	await get_tree().process_frame
	await CourseGraphicsUpgraderScript.check_and_upgrade_courses_on_startup(get_tree())


func load_main_menu() -> void:
	change_scene("res://UI/MainMenu/main_menu.tscn")


func change_scene(path) -> void:
	var target_path := str(path)
	if target_path.is_empty():
		return
	# Coalesce rapid/duplicate scene switch requests within the same frame so we never
	# tear down a newly added scene before its deferred setup completes.
	_pending_scene_path = target_path
	if _is_changing_scene:
		return
	_is_changing_scene = true
	call_deferred("_deferred_change_scene")


func _cleanup_ui_before_scene_change() -> void:
	# Close any active OptionButton/PopupMenu/Window and clear modal focus locks
	# before detaching the departing scene to prevent dangling native window/focus state.
	if has_node("/root/UIFocusGuard"):
		var ufg = get_node("/root/UIFocusGuard")
		if ufg != null and ufg.has_method("reset_for_scene_change"):
			ufg.reset_for_scene_change()
	if has_node("/root/VirtualKeyboardManager"):
		var vkm = get_node("/root/VirtualKeyboardManager")
		if vkm != null and vkm.has_method("is_open") and vkm.is_open():
			vkm.close(false)
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()


func _detach_and_free_scene(scene_node: Node) -> void:
	if scene_node == null or not is_instance_valid(scene_node):
		return
	var parent := scene_node.get_parent()
	if parent != null and is_instance_valid(parent):
		parent.remove_child(scene_node)
	if not scene_node.is_queued_for_deletion():
		scene_node.queue_free()


func _deferred_change_scene() -> void:
	var scene_path := _pending_scene_path
	_pending_scene_path = ""
	if scene_path.is_empty():
		_is_changing_scene = false
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s" % scene_path)
		_is_changing_scene = false
		return

	var next_scene := packed.instantiate()
	if next_scene == null:
		push_error("Could not instantiate scene: %s" % scene_path)
		_is_changing_scene = false
		return

	var tree := get_tree()
	if tree == null or tree.get_root() == null:
		next_scene.queue_free()
		_is_changing_scene = false
		return

	_cleanup_ui_before_scene_change()

	var old_scene: Node = current_scene if (current_scene != null and is_instance_valid(current_scene)) else null
	var tree_scene: Node = tree.current_scene if (tree.current_scene != null and is_instance_valid(tree.current_scene)) else null

	# Clear references before detaching so _exit_tree() and the new scene's _ready()
	# never observe a stale/dangling current_scene pointer.
	current_scene = null
	tree.current_scene = null

	if old_scene != null:
		_detach_and_free_scene(old_scene)
	if tree_scene != null and tree_scene != old_scene:
		_detach_and_free_scene(tree_scene)

	current_scene = next_scene
	tree.get_root().add_child(current_scene)
	tree.current_scene = next_scene
	_is_changing_scene = false
	scene_changed.emit()

	# If another scene change was requested while switching, process the latest target next.
	if not _pending_scene_path.is_empty():
		var next_pending := _pending_scene_path
		_pending_scene_path = ""
		change_scene(next_pending)


func _process(delta: float) -> void:
	if _loading_screen == null or _loading_progress_bar == null:
		return
	
	if _loading_current_percent < _loading_target_percent:
		var step := maxf(0.5, absf(_loading_target_percent - _loading_current_percent) * 5.0 * delta)
		_loading_current_percent = minf(_loading_current_percent + step, _loading_target_percent)
	elif _loading_current_percent < _loading_stage_cap:
		# Paced crawl strictly bounded within the active stage
		_loading_current_percent = minf(_loading_current_percent + (0.8 * delta), _loading_stage_cap)
		
	_loading_progress_bar.value = _loading_current_percent
	if _loading_percent_label != null:
		_loading_percent_label.text = "%d%%" % int(_loading_current_percent)


func set_loading_stage(progress_percent: float, status_text: String = "", stage_cap: float = -1.0) -> void:
	if stage_cap >= 0.0:
		_loading_stage_cap = stage_cap
	else:
		_loading_stage_cap = maxf(_loading_stage_cap, progress_percent)
	_loading_target_percent = clampf(progress_percent, 0.0, _loading_stage_cap)
	if _loading_current_percent < _loading_target_percent and (_loading_target_percent - _loading_current_percent) > 15.0:
		_loading_current_percent = _loading_target_percent - 5.0
	if status_text != "" and _loading_status_label != null and is_instance_valid(_loading_status_label):
		_loading_status_label.text = status_text


func load_course(scene_path: String, config_path: String) -> void:
	_show_loading_screen(config_path)
	# Yield 2 frames to ensure the loading screen overlay is drawn and blocks input
	await get_tree().process_frame
	await get_tree().process_frame
	
	set_loading_stage(0.0, "Reading course configuration...", 4.0)
	change_scene("res://Utils/CourseManager.tscn")
	await scene_changed
	var load_success: bool = await current_scene.initialize(scene_path, config_path)
	if not load_success:
		_hide_loading_screen()
		return
	
	# Yield one more frame to ensure the new scene is drawn before hiding the overlay
	set_loading_stage(100.0, "Ready!", 100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_hide_loading_screen()
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()


func close_scene():
	call_deferred("_deferred_close_scene")


func _deferred_close_scene():
	_cleanup_ui_before_scene_change()
	var old_scene: Node = current_scene if (current_scene != null and is_instance_valid(current_scene)) else null
	current_scene = null
	if get_tree() != null:
		get_tree().current_scene = null
	if old_scene != null:
		_detach_and_free_scene(old_scene)


func reload_scene():
	if current_scene == null or not is_instance_valid(current_scene):
		return
	var path: String = str(current_scene.scene_file_path)
	if path.is_empty():
		return
	change_scene(path)


## Approximate time (seconds) a course takes to load; the progress bar is paced to this.
const LOADING_BAR_DURATION := 20.0
const LOADING_BAR_MAX := 99.0
## Bundled photo shown when a course has no course-specific photo.
const GENERIC_COURSE_PHOTO := "res://UI/Assets/generic_course_photo.jpg"
const BLUR_SHADER_CODE := """
shader_type canvas_item;
uniform float blur_lod : hint_range(0.0, 8.0) = 3.5;
void fragment() {
	COLOR = textureLod(TEXTURE, UV, blur_lod);
}
"""


func _read_course_title(config_path: String) -> String:
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return ""
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return str(parsed.get("Title", ""))
	return ""


## Decodes JPEG/PNG/WebP bytes by sniffing the file header (downloaded photos may not match their extension).
func _decode_image_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0x52 and bytes[1] == 0x49:
		err = img.load_webp_from_buffer(bytes)
	return img if err == OK else null


func _load_course_photo(config_path: String) -> Texture2D:
	var img: Image = null
	var photo_path := config_path.get_base_dir().path_join("course_photo.jpg")
	if FileAccess.file_exists(photo_path):
		img = _decode_image_bytes(FileAccess.get_file_as_bytes(photo_path))
	# Fall back to the bundled generic course photo
	if img == null or img.is_empty():
		if ResourceLoader.exists(GENERIC_COURSE_PHOTO):
			var tex := load(GENERIC_COURSE_PHOTO) as Texture2D
			if tex != null:
				img = tex.get_image()
				if img != null and img.is_compressed():
					img.decompress()
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _show_loading_screen(config_path: String = "") -> void:
	if _loading_screen != null:
		return

	var title := _read_course_title(config_path) if config_path != "" else ""
	var photo := _load_course_photo(config_path) if config_path != "" else null

	_loading_screen = CanvasLayer.new()
	_loading_screen.layer = 100

	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_screen.add_child(control)

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.12, 0.16, 1.0 if photo != null else 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(bg)

	if photo != null:
		var photo_rect := TextureRect.new()
		photo_rect.texture = photo
		photo_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var blur_shader := Shader.new()
		blur_shader.code = BLUR_SHADER_CODE
		var blur_mat := ShaderMaterial.new()
		blur_mat.shader = blur_shader
		photo_rect.material = blur_mat
		control.add_child(photo_rect)

		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.35)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	# Wide-tracked, emboldened font for a more distinctive course title
	var title_font := FontVariation.new()
	title_font.base_font = ThemeDB.fallback_font
	title_font.variation_embolden = 0.8
	title_font.spacing_glyph = 6

	var eyebrow := Label.new()
	eyebrow.text = "NOW LOADING"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", title_font)
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", Color(0.75, 0.9, 0.7))
	eyebrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	eyebrow.add_theme_constant_override("outline_size", 6)
	vbox.add_child(eyebrow)

	var label = Label.new()
	label.text = title.to_upper() if title != "" else "LOADING COURSE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", title_font)
	label.add_theme_font_size_override("font_size", 64 if title != "" else 36)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(label)

	# Loading bar pinned to the bottom of the screen
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 80)
	bar_margin.add_theme_constant_override("margin_right", 80)
	bar_margin.add_theme_constant_override("margin_bottom", 48)
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(bar_margin)
	# Must be set after parenting; grow upward so it stays on screen
	bar_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	bar_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 6)
	bar_margin.add_child(bar_box)

	var info_row := HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_child(info_row)

	var status_label := Label.new()
	status_label.text = "Initializing Course..."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.96, 0.9))
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("outline_size", 4)
	info_row.add_child(status_label)
	_loading_status_label = status_label

	var percent_label := Label.new()
	percent_label.text = "0%"
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label.add_theme_font_size_override("font_size", 18)
	percent_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	percent_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	percent_label.add_theme_constant_override("outline_size", 6)
	info_row.add_child(percent_label)
	_loading_percent_label = percent_label

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = 0.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.24, 0.46, 0.72, 1.0)
	fill.set_corner_radius_all(7)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.5)
	track.set_corner_radius_all(7)
	progress.add_theme_stylebox_override("fill", fill)
	progress.add_theme_stylebox_override("background", track)
	bar_box.add_child(progress)
	_loading_progress_bar = progress

	_loading_current_percent = 0.0
	_loading_target_percent = 0.0
	_loading_stage_cap = 4.0

	get_tree().get_root().add_child(_loading_screen)


func _hide_loading_screen() -> void:
	if _loading_screen != null:
		_loading_screen.queue_free()
		_loading_screen = null
	_loading_progress_bar = null
	_loading_percent_label = null
	_loading_status_label = null
	_loading_current_percent = 0.0
	_loading_target_percent = 0.0
	_loading_stage_cap = 4.0
