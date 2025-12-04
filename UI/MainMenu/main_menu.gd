extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.current_scene = self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_range_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/range_mode_screen.tscn")


func _on_courses_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/course_select_screen.tscn")


func _on_settings_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/settings_screen.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_view_profile_btn_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/profile_screen.tscn")


func _on_add_player_btn_pressed() -> void:
	%AddPlayerModal.visible = not %AddPlayerModal.visible
