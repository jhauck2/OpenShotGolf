extends Node

# Loading Screens
var default_loading_scene: String = "res://UI/LoadingScreens/progress_bar.tscn"

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
	if s != null:
		current_scene = s.instantiate()
	else:
		print("Could not load scene: " + scene_path)
	
	# Add the scene to the tree
	get_tree().get_root().add_child(current_scene, true)
	

func change_scene_with_loading(target_scene_path: String, loading_screen_path: String = default_loading_scene):
	call_deferred("_deferred_change_scene_with_loading", target_scene_path, loading_screen_path)


func _deferred_change_scene_with_loading(target_scene_path: String, loading_screen_path: String):
	# Remove current scene
	if current_scene != null:
		current_scene.queue_free()

	# Load the loading screen scene
	var loading_res = load(loading_screen_path)
	if loading_res == null:
		push_error("Could not load loading screen: " + loading_screen_path)
		return

	# Instantiate loading screen
	current_scene = loading_res.instantiate()

	# PASS THE PARAMETER
	current_scene.target_scene_path = target_scene_path

	# Add loading screen to tree
	get_tree().root.add_child(current_scene)


func close_scene():
	call_deferred("_deferred_close_scene")


func _deferred_close_scene():
	# Remove current scene
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null


func reload_scene():
	# Get current scene path
	var path = current_scene.filename
	# Remove current scene
	current_scene.queue_free()
	
	# Load the new scene
	var s = ResourceLoader.load(path)
	current_scene = s.instance()
	get_tree().get_root().add_child(current_scene)
