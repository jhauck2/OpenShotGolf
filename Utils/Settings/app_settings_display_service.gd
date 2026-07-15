class_name AppSettingsDisplayService
extends RefCounted

const DEFAULT_SIZE := Vector2i(1728, 972)
const PRESETS := [
	"1024x768",
	"1280x720",
	"1600x900",
	"1728x972",
	"1920x1080",
	"2560x1080",
	"3440x1440"
]


static func apply(app_settings: AppSettings, window: Window) -> void:
	if app_settings == null or window == null:
		return

	window.size = parse_resolution_preset(str(app_settings.display_resolution_preset.value))
	window.mode = Window.MODE_FULLSCREEN if bool(app_settings.display_fullscreen.value) else Window.MODE_WINDOWED


static func parse_resolution_preset(preset: String) -> Vector2i:
	var parts := preset.strip_edges().to_lower().split("x", false)
	if parts.size() != 2:
		return DEFAULT_SIZE

	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return DEFAULT_SIZE

	var width := int(parts[0])
	var height := int(parts[1])
	if width < 320 or height < 240:
		return DEFAULT_SIZE

	return Vector2i(width, height)
