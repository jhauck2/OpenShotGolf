extends Control
# TODO - add settings menu system on future PR. 
@onready var _settings_button: Button = $TopBanner/LeftButtons/SettingsButton
@onready var _exit_button: Button = $TopBanner/LeftButtons/ExitButton
@onready var _courses_button: Button = $TilesRow/CoursesTile/CoursesTextBackdrop/CoursesButton
@onready var _range_button: Button = $TilesRow/RangeTile/RangeTextBackdrop/RangeButton
@onready var _version_label: Label = $VersionLabel
var _version_fall_back: String = "dev"
var _version_setting_path: String = "application/config/version"
var _version_text: String


# Called when the node enters the scene tree for the first time.
func _ready():
	
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_range_button.pressed.connect(_on_range_pressed)
	_courses_button.pressed.connect(_on_courses_pressed)
		
	_update_version_label()
	SceneManager.current_scene = self

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_range_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/range.tscn")


func _on_courses_pressed() -> void:
	SceneManager.change_scene("res://Courses/CourseSelector/course_selector.tscn")


func _update_version_label():
	_version_text = _version_fall_back
	if (ProjectSettings.has_setting(_version_setting_path)):
		var _configured_version = str(ProjectSettings.get_setting(_version_setting_path)).strip_edges()
		_version_text = _configured_version;

	_version_label.text = "Version %s" % _version_text
	
func _on_settings_pressed() -> void:
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	get_tree().quit()
