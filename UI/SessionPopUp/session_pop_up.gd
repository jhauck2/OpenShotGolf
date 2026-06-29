extends CenterContainer

var bad_dir_text : String = "This directory does not exist."


signal dir_selected(dir: String, player_name: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func open() -> void:
	visible = true
	get_tree().paused = true
	$PanelContainer/MarginContainer/VBoxContainer/Label2.visible = false
	$PanelContainer/MarginContainer/VBoxContainer/Label2.text = ""
	
func set_session_data(user: String, dir: String) -> void:
	$PanelContainer/MarginContainer/VBoxContainer/PlayerName/TextEdit.text = user
	$PanelContainer/MarginContainer/VBoxContainer/Directory/TextEdit.text = dir
	
func close() -> void:
	visible = false
	get_tree().paused = false

func _on_ok_button_pressed() -> void:
	var dir_text : String = $PanelContainer/MarginContainer/VBoxContainer/Directory/TextEdit.text
	var player_name : String = $PanelContainer/MarginContainer/VBoxContainer/PlayerName/TextEdit.text
	if DirAccess.dir_exists_absolute(dir_text):
		emit_signal("dir_selected", dir_text, player_name)
		close()
	else:
		$PanelContainer/MarginContainer/VBoxContainer/Label2. visible = true
		$PanelContainer/MarginContainer/VBoxContainer/Label2.text = bad_dir_text
