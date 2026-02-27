extends ItemList

var course_dir := ""
const COURSE_CONFIG_FILE := "course.json"
const COURSE_SCENE_KEY := "scene_path"
const COURSE_SCENE_FILE := "course.tscn"
const COURSE_SCRIPT_FILE := "course.gd"
const COURSE_TITLE_KEY := "Title"
const COURSE_INFO_KEY := "Course Info"

signal play_course(path: String, players: Array)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func parse_directory(path: String) -> int:
	clear()
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		course_dir = ""
		print("[CourseList] Skipped scan because course directory is empty.")
		return 0
	if normalized_path.ends_with("/"):
		normalized_path = normalized_path.substr(0, normalized_path.length() - 1)
	course_dir = normalized_path
	print("[CourseList] Scanning directory: %s" % course_dir)

	var dir := DirAccess.open(course_dir)
	if dir == null:
		printerr("[CourseList] Unable to open course directory: %s" % course_dir)
		return -1

	var courses: Array[String] = []

	# Get a list of all courses by directories within "course_dir".
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var has_config := FileAccess.file_exists(_course_config_path(file_name))
			var has_scene := FileAccess.file_exists(_course_scene_path(file_name))
			var has_script := FileAccess.file_exists(_course_script_path(file_name))
			if has_config and has_scene and has_script:
				courses.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	courses.sort()
	for course in courses:
		var display_title := _read_course_title(course)
		var item_index := get_item_count()
		add_item(display_title)
		set_item_metadata(item_index, course)

	print("[CourseList] Found %d valid course(s)." % courses.size())
	return courses.size()


func emit_play_for_index(selected_index: int, players: Array) -> void:
	if selected_index < 0 or selected_index >= get_item_count():
		printerr("[CourseList] Selected course index is out of bounds.")
		return

	var selected_course := String(get_item_metadata(selected_index)).strip_edges()
	if selected_course.is_empty():
		printerr("[CourseList] Selected course metadata is invalid.")
		return

	var scene_path := _read_course_scene_path(selected_course)
	if scene_path.is_empty():
		return

	emit_signal("play_course", scene_path, players)


func _course_config_path(course_name: String) -> String:
	return "%s/%s/%s" % [course_dir, course_name, COURSE_CONFIG_FILE]


func _course_scene_path(course_name: String) -> String:
	return "%s/%s/%s" % [course_dir, course_name, COURSE_SCENE_FILE]


func _course_script_path(course_name: String) -> String:
	return "%s/%s/%s" % [course_dir, course_name, COURSE_SCRIPT_FILE]


func _read_course_title(course_name: String) -> String:
	var parsed := _parse_course_config(course_name)
	if parsed.is_empty():
		return course_name

	var top_level_title = parsed.get(COURSE_TITLE_KEY, "")
	if typeof(top_level_title) == TYPE_STRING:
		var normalized_title := String(top_level_title).strip_edges()
		if not normalized_title.is_empty():
			return normalized_title

	var course_info = parsed.get(COURSE_INFO_KEY, {})
	if typeof(course_info) == TYPE_DICTIONARY:
		var legacy_title = course_info.get(COURSE_TITLE_KEY, "")
		if typeof(legacy_title) == TYPE_STRING:
			var normalized_legacy_title := String(legacy_title).strip_edges()
			if not normalized_legacy_title.is_empty():
				return normalized_legacy_title

	return course_name


func _read_course_scene_path(course_name: String) -> String:
	var parsed := _parse_course_config(course_name)
	if parsed.is_empty():
		return ""
	var config_path := _course_config_path(course_name)

	var scene_value = parsed.get(COURSE_SCENE_KEY, COURSE_SCENE_FILE)
	if typeof(scene_value) != TYPE_STRING:
		printerr("[CourseList] '%s' must be a string in %s." % [COURSE_SCENE_KEY, config_path])
		return ""

	var scene_path := String(scene_value).strip_edges()
	if scene_path.is_empty():
		scene_path = COURSE_SCENE_FILE

	var resolved_scene_path := scene_path
	if not resolved_scene_path.begins_with("res://"):
		resolved_scene_path = "%s/%s/%s" % [course_dir, course_name, resolved_scene_path]

	if not FileAccess.file_exists(resolved_scene_path):
		printerr("[CourseList] Scene path for '%s' does not exist: %s" % [course_name, resolved_scene_path])
		return ""

	return resolved_scene_path


func _parse_course_config(course_name: String) -> Dictionary:
	var config_path := _course_config_path(course_name)
	if not FileAccess.file_exists(config_path):
		printerr("[CourseList] Missing %s for course '%s'." % [COURSE_CONFIG_FILE, course_name])
		return {}

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		printerr("[CourseList] Unable to read course config: %s" % config_path)
		return {}

	var json_text := file.get_as_text()
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[CourseList] Invalid JSON in %s." % config_path)
		return {}

	return parsed
