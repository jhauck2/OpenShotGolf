extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


func _on_course_list_play_course(path: String, players: Array) -> void:
	# load metadata
	var metadata_file = FileAccess.open(path+"/metadata.json", FileAccess.READ)
	var metadata_string = metadata_file.get_as_text()
	var json = JSON.new()
	var error = json.parse(metadata_string)
	if error != OK:
		# bad metadata
		return
	var metadata = json.data
	SceneManager.play_course(path, metadata, players)
