extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_stats_btn_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/Screens/stats_screen.tscn")


func _on_edit_btn_pressed() -> void:
	%RenameModal.visible = not $RenameModal.visible


func _on_delete_btn_pressed() -> void:
	%DeleteConfirmModal.visible = not %DeleteConfirmModal.visible
