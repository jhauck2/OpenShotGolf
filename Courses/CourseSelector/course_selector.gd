extends Control

@onready var _course_list = $ContentPanel/ContentMargin/VBoxContainer/ScrollContainer/CourseList
@onready var _course_directory_text: TextEdit = $ContentPanel/ContentMargin/VBoxContainer/CourseDirectory/CourseDirectoryText
@onready var _status_label: Label = $ContentPanel/ContentMargin/VBoxContainer/StatusLabel
@onready var _refresh_button: Button = $ContentPanel/ContentMargin/VBoxContainer/CourseDirectory/RefreshButton


func _ready() -> void:
	_refresh_button.mouse_entered.connect(_on_refresh_button_mouse_entered)
	_refresh_button.mouse_exited.connect(_on_refresh_button_mouse_exited)
	_request_course_reload()


func _on_main_menu_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_refresh_button_pressed() -> void:
	_flash_refresh_button()
	_request_course_reload()


func _on_course_list_item_activated(index: int) -> void:
	var scene_path: String = _course_list.get_scene_path_for_index(index)
	var config_path: String = _course_list.get_config_path_for_index(index)
	_play_course(scene_path, config_path)


func _play_course(scene_path: String, config_path: String = "") -> void:
	if scene_path.is_empty():
		printerr("[CourseSelector] Play requested with an empty scene scene_path.")
		return

	SceneManager.load_course(scene_path, config_path)


func _request_course_reload() -> void:
	var status_text := String(_course_list.reload_courses(_course_directory_text.text))
	_status_label.text = status_text if not status_text.is_empty() else "Ready"


func _flash_refresh_button() -> void:
	_refresh_button.self_modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_refresh_button, "self_modulate", Color(0.75, 0.9, 1.0, 1), 0.08)
	tween.tween_property(_refresh_button, "self_modulate", Color(1, 1, 1, 1), 0.16)


func _on_refresh_button_mouse_entered() -> void:
	_refresh_button.self_modulate = Color(0.8, 0.92, 1.0, 1)


func _on_refresh_button_mouse_exited() -> void:
	_refresh_button.self_modulate = Color(1, 1, 1, 1)
