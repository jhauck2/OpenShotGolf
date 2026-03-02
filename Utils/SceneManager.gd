extends Node

# Reference to current scene
var current_scene = null
const LEGACY_SCENE_REDIRECTS := {
	"res://game/shot_tracker.tscn": "res://Courses/Range/range.tscn",
	"res://game/ShotTracker.tscn": "res://Courses/Range/range.tscn"
}

# Course data keys from JSON file
const COURSE_INFO_KEY := "Course Info"
const HOLE_INFO_KEY := "Hole Info"

# Defaults applied when Course Info is missing keys
const DEFAULT_TEE_COLORS: Array[String] = ["Black", "Blue", "White", "Red"]
# TO be used in future implemenation at course hole level. 
const DEFAULT_TEXTURE_INDICES := {
	"Green": [0],
	"Fairway": [1],
	"Rough": [2],
	"Sand": [3],
	"Water": [4],
	"Penalty": [5],
}

# Course state — populated after loading a course scene
# TODO: Consume course_info and hole_info in gameplay scripts. Future implementation.
var course_info: Dictionary = {}
var hole_info: Dictionary = {}
var _current_config_path: String = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func _physics_process(_delta):
	pass


func change_scene(path, config_path: String = ""):
	call_deferred("_deferred_change_scene", path, config_path)


func _deferred_change_scene(scene_path, config_path: String = "") -> void:
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
	_load_course_config(config_path)


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
	_clear_course_state()


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
	_load_course_config(_current_config_path)


func _load_course_config(config_path: String) -> void:
	_clear_course_state()
	_current_config_path = config_path
	if config_path.is_empty():
		return

	if not FileAccess.file_exists(config_path):
		push_error("[SceneManager] Course config not found: %s" % config_path)
		return

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("[SceneManager] Unable to read course config: %s" % config_path)
		return

	var json_text := file.get_as_text()
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SceneManager] Invalid JSON in %s." % config_path)
		return

	# Extract Course Info with defaults for missing keys
	var info = parsed.get(COURSE_INFO_KEY, {})
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	if not info.has("Tee Colors"):
		info["Tee Colors"] = DEFAULT_TEE_COLORS.duplicate()
	if not info.has("Texture Indices"):
		info["Texture Indices"] = DEFAULT_TEXTURE_INDICES.duplicate()
	course_info = info

	# Extract Hole Info
	var holes = parsed.get(HOLE_INFO_KEY, {})
	if typeof(holes) != TYPE_DICTIONARY:
		holes = {}
	hole_info = holes


func _clear_course_state() -> void:
	course_info = {}
	hole_info = {}
	_current_config_path = ""
