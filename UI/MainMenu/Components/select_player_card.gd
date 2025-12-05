extends Button

@export var hover_brightness: float = 1.3
@export var animation_duration: float = 0.2
@export var scale_animation: bool = true
@export var hover_scale: Vector2 = Vector2(1.02, 1.02)

@onready var panel = $PanelContainer
var original_color: Color
var original_scale: Vector2
var tween: Tween

func _ready() -> void:
	original_scale = scale

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)

	# Brighten the background color
	var brighter_color = original_color.lightened(0.2)
	var style_box = panel.get_theme_stylebox("panel").duplicate()
	style_box.bg_color = brighter_color
	panel.add_theme_stylebox_override("panel", style_box)

	# Optional scale animation
	if scale_animation:
		tween.tween_property(self, "scale", hover_scale, animation_duration)

func _on_mouse_exited() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)

	# Restore original color
	var style_box = panel.get_theme_stylebox("panel").duplicate()
	style_box.bg_color = original_color
	panel.add_theme_stylebox_override("panel", style_box)

	# Return to original scale
	if scale_animation:
		tween.tween_property(self, "scale", original_scale, animation_duration)
