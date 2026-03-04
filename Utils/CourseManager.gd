extends Node3D

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
var course_info: Dictionary = {}
var hole_info: Dictionary = {}
var _current_config_path: String = ""


func initialize(scene_path: String, config_path: String) -> void:
	_load_course_config(config_path)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[CourseManager] Could not load course scene: %s" % scene_path)
		return
	var course_scene := packed.instantiate()
	if course_scene == null:
		push_error("[CourseManager] Could not instantiate course scene: %s" % scene_path)
		return
	add_child(course_scene)


func _load_course_config(config_path: String) -> void:
	_current_config_path = config_path
	if config_path.is_empty():
		return

	if not FileAccess.file_exists(config_path):
		push_error("[CourseManager] Course config not found: %s" % config_path)
		return

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("[CourseManager] Unable to read course config: %s" % config_path)
		return

	var json_text := file.get_as_text()
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[CourseManager] Invalid JSON in %s." % config_path)
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


func reload_current_config() -> void:
	_load_course_config(_current_config_path)

func get_current_config_path() -> String:
	return _current_config_path
