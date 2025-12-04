extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_btn_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/profile_screen.tscn")
