extends Node

# Reference to current scene
var current_scene = null
const LEGACY_SCENE_REDIRECTS := {
	"res://game/shot_tracker.tscn": "res://Courses/Range/range.tscn",
	"res://game/ShotTracker.tscn": "res://Courses/Range/range.tscn"
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func _physics_process(_delta):
	pass


func change_scene(path):
	call_deferred("_deferred_change_scene", path)


func _deferred_change_scene(scene_path) -> void:
	var normalized_path := _normalize_scene_path(str(scene_path))
	var packed := load(normalized_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s (requested: %s)" % [normalized_path, scene_path])
		return

	var next_scene := packed.instantiate()
	if next_scene == null:
		push_error("Could not instantiate scene: %s" % normalized_path)
		return

	# Only swap scenes after the replacement loaded successfully.
	if current_scene != null:
		current_scene.queue_free()

	current_scene = next_scene
	get_tree().get_root().add_child(current_scene)
	
func play_course(course_folder_path : String, metadata : Dictionary, players : Array) -> void:
	close_scene()
	change_scene("res://Utils/course_manager.tscn")
	# wait for the scene change. probably a better way to do this
	while current_scene.name != "CourseManager":
		await get_tree().process_frame # bad practice
	current_scene.start_course(course_folder_path, metadata, players)

func _normalize_scene_path(scene_path: String) -> String:
	if LEGACY_SCENE_REDIRECTS.has(scene_path):
		var redirected: String = LEGACY_SCENE_REDIRECTS[scene_path]
		push_warning("Redirecting legacy scene path '%s' to '%s'." % [scene_path, redirected])
		return redirected
	return scene_path


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
