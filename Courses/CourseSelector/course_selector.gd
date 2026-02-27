extends Control

const DEFAULT_PLAYERS: Array[String] = ["John Birdie"]

@onready var _course_list = $ContentPanel/ContentMargin/VBoxContainer/ScrollContainer/CourseList
@onready var _course_directory_text: TextEdit = $ContentPanel/ContentMargin/VBoxContainer/CourseDirectory/CourseDirectoryText
@onready var _status_label: Label = $ContentPanel/ContentMargin/VBoxContainer/StatusLabel
@onready var _refresh_button: Button = $ContentPanel/ContentMargin/VBoxContainer/CourseDirectory/RefreshButton


func _ready() -> void:
	_refresh_button.mouse_entered.connect(_on_refresh_button_mouse_entered)
	_refresh_button.mouse_exited.connect(_on_refresh_button_mouse_exited)
	_reload_courses()


func _on_main_menu_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_load_button_pressed() -> void:
	_reload_courses("Load")


func _on_refresh_button_pressed() -> void:
	_flash_refresh_button()
	_reload_courses("Refresh")


func _on_course_list_item_activated(index: int) -> void:
	_course_list.emit_play_for_index(index, DEFAULT_PLAYERS)


func _on_course_list_play_course(path: String, _players: Array) -> void:
	if path.is_empty():
		printerr("[CourseSelector] Play requested with an empty scene path.")
		return

	SceneManager.change_scene(path)


func _reload_courses(source: String = "Refresh") -> void:
	var path: String = _course_directory_text.text.strip_edges()
	print("[CourseSelector] %s requested. Path: %s" % [source, path])
	var course_count: int = int(_course_list.parse_directory(path))
	var stamp := str(Time.get_ticks_msec())
	if course_count < 0:
		_status_label.text = "%s [%s]: invalid course directory" % [source, stamp]
		printerr("[CourseSelector] %s failed. Invalid course directory: %s" % [source, path])
		return
	if course_count == 0:
		_status_label.text = "%s [%s]: no valid courses found" % [source, stamp]
		print("[CourseSelector] %s completed. No valid courses found." % source)
		return

	print("[CourseSelector] %s completed. Loaded %d course(s)." % [source, course_count])


func _flash_refresh_button() -> void:
	_refresh_button.self_modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_refresh_button, "self_modulate", Color(0.75, 0.9, 1.0, 1), 0.08)
	tween.tween_property(_refresh_button, "self_modulate", Color(1, 1, 1, 1), 0.16)


func _on_refresh_button_mouse_entered() -> void:
	_refresh_button.self_modulate = Color(0.8, 0.92, 1.0, 1)


func _on_refresh_button_mouse_exited() -> void:
	_refresh_button.self_modulate = Color(1, 1, 1, 1)
