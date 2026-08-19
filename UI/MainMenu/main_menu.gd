extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/HBoxContainer/Version.text = "Version " + GlobalSettings.get_version_string()
	SceneManager.current_scene = self


func _on_range_button_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/range2.tscn")


func _on_physics_test_button_pressed() -> void:
	PhysicsTest.runTests()
