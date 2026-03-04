extends Node

signal scene_changed

var current_scene = null


func change_scene(path):
	call_deferred("_deferred_change_scene", path)


func _deferred_change_scene(scene_path) -> void:
	var packed := load(str(scene_path)) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s" % scene_path)
		return

	var next_scene := packed.instantiate()
	if next_scene == null:
		push_error("Could not instantiate scene: %s" % scene_path)
		return

	if current_scene != null:
		current_scene.queue_free()

	current_scene = next_scene
	get_tree().get_root().add_child(current_scene)
	scene_changed.emit()


func load_course(scene_path: String, config_path: String) -> void:
	change_scene("res://Utils/CourseManager.tscn")
	await scene_changed
	current_scene.initialize(scene_path, config_path)


func close_scene():
	call_deferred("_deferred_close_scene")


func _deferred_close_scene():
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null


func reload_scene():
	if current_scene == null:
		return
	var path: String = str(current_scene.scene_file_path)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Could not reload scene: " + path)
		return

	var next_scene := packed.instantiate()
	if next_scene == null:
		push_error("Could not instantiate reloaded scene: " + path)
		return

	current_scene.queue_free()
	current_scene = next_scene
	get_tree().get_root().add_child(current_scene)
	scene_changed.emit()
