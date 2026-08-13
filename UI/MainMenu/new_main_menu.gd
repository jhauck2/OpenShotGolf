extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/Version.text = "Version " + GlobalSettings.get_version_string()
	SceneManager.current_scene = self


func _on_range_button_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/range.tscn")
