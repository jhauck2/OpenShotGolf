extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_free_practice_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/Modes/FreePractice/range_free_practice.tscn")


func _on_target_practice_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/Modes/TargetPractice/range_target_practice.tscn")


func _on_club_fitting_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/Modes/ClubFitting/range_club_fitting.tscn")


func _on_back_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")
