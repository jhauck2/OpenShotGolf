extends Control

var progress = []
var target_scene_path: String
var scene_load_status = 0

func _ready() -> void:
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(_delta: float) -> void:
	scene_load_status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	get_node("%ProgressBar").value = floor(progress[0] * 100)
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		var newScene = ResourceLoader.load_threaded_get(target_scene_path)
		SceneManager.change_scene(target_scene_path)
