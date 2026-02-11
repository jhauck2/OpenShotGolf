extends Node

# Reference to current scene
var current_scene = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func _physics_process(_delta):
	pass


func change_scene(path):
	call_deferred("_deferred_change_scene", path)


func _deferred_change_scene(scene_path):
	# Remove current scene
	if current_scene != null:
		current_scene.queue_free()
	
	# Load the new scene
	var s = load(scene_path)
	if s == null:
		push_error("Could not load scene: " + scene_path)
		return
	current_scene = s.instantiate()
	get_tree().get_root().add_child(current_scene)
	


func close_scene():
	call_deferred("_deferred_close_scene")


func _deferred_close_scene():
	# Remove current scene
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null


func reload_scene():
	if current_scene == null:
		return
	var path = current_scene.scene_file_path
	current_scene.queue_free()

	var s = load(path)
	if s == null:
		push_error("Could not reload scene: " + path)
		current_scene = null
		return
	current_scene = s.instantiate()
	get_tree().get_root().add_child(current_scene)
