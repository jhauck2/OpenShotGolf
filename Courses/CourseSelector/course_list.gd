extends ItemList

var course_dir := ""


## Scan the course directory, validate each course, repopulate the list,
## and return the count (-1 on open failure).
func parse_directory(path: String) -> int:
	clear()
	if path.is_empty():
		course_dir = ""
		print("[CourseList] Skipped scan because course directory is empty.")
		return 0
	if path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
	course_dir = path
	print("[CourseList] Scanning directory: %s" % course_dir)

	var dir := DirAccess.open(course_dir)
	if dir == null:
		printerr("[CourseList] Unable to open course directory: %s" % course_dir)
		return -1

	var validated: Array[Dictionary] = []

	dir.list_dir_begin()
	var dir_name := dir.get_next()
	while dir_name != "":
		if dir.current_is_dir() and not dir_name.begins_with("."):
			var result := CourseValidator.validate(course_dir, dir_name)
			if not result.is_empty():
				result["dir_name"] = dir_name
				validated.append(result)
		dir_name = dir.get_next()
	dir.list_dir_end()

	validated.sort_custom(func(a, b): return a["dir_name"] < b["dir_name"])
	for course in validated:
		var item_index := get_item_count()
		add_item(course["title"])
		set_item_metadata(item_index, course)

	print("[CourseList] Found %d valid course(s)." % validated.size())
	return validated.size()


## Normalize a reload request and return a status string.
func reload_courses(path: String) -> String:
	var normalized_path := path.strip_edges()
	print("[CourseList] Refresh requested. Path: %s" % normalized_path)
	var course_count: int = parse_directory(normalized_path)
	var stamp := str(Time.get_ticks_msec())

	if course_count < 0:
		printerr("[CourseList] Refresh failed. Invalid course directory: %s" % normalized_path)
		return "Refresh [%s]: invalid course directory" % stamp

	if course_count == 0:
		print("[CourseList] Refresh completed. No valid courses found.")
		return "Refresh [%s]: no valid courses found" % stamp

	print("[CourseList] Refresh completed. Loaded %d course(s)." % course_count)
	return ""


func get_scene_path_for_index(selected_index: int) -> String:
	if selected_index < 0 or selected_index >= get_item_count():
		printerr("[CourseList] Selected course index is out of bounds.")
		return ""
	return get_item_metadata(selected_index).get("scene_path", "")


func get_config_path_for_index(selected_index: int) -> String:
	if selected_index < 0 or selected_index >= get_item_count():
		printerr("[CourseList] Selected course index is out of bounds.")
		return ""
	return get_item_metadata(selected_index).get("config_path", "")
