extends Node
class_name AnimationComponent

##
# Reusable UI animation component for Godot 4
# Attach this script as a child of a Control node for hover animations
# Taken from https://www.youtube.com/watch?v=jF3UgstQ1Yk&pp=ygUYZ29kb3QgdWkgaG92ZXIgYW5pbWF0aW9u
##

# Animation configuration
@export var duration: float = 0.2
@export var scale_animation: bool = true
@export var hover_scale: Vector2 = Vector2(1.05, 1.05)
@export var fade_animation: bool = false
@export var position_animation: bool = false
@export var hover_offset: Vector2 = Vector2(0, -20)  # Move up 20px by default

@export var trans_type: int = Tween.TRANS_CUBIC
@export var ease_type: int = Tween.EASE_OUT

@onready var target: Control = get_parent() as Control
var tween: Tween
var is_hovered: bool = false
var original_global_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if not target:
		push_error("AnimationComponent must be a child of a Control node.")
		return

	# Store original global position for animation (works with layout systems)
	await get_tree().process_frame  # Wait one frame for layout to settle
	original_global_position = target.global_position

	# Connect hover signals
	target.mouse_entered.connect(_on_mouse_entered)
	target.mouse_exited.connect(_on_mouse_exited)

	# Initialize tween
	tween = create_tween()
	tween.kill()


##
# PRIVATE SIGNAL HANDLERS
##

func _on_mouse_entered() -> void:
	is_hovered = true
	animate_hover_in()


func _on_mouse_exited() -> void:
	is_hovered = false
	animate_hover_out()


##
# PUBLIC METHODS
##

func animate_hover_in() -> void:
	if not target:
		return

	if tween:
		tween.kill()
	tween = create_tween()

	# Scale
	if scale_animation:
		tween.tween_property(target, "scale", hover_scale, duration)

	# Position (move up/out) - uses global_position to work with layout systems
	if position_animation:
		tween.tween_property(target, "global_position", original_global_position + hover_offset, duration)

	# Fade
	if fade_animation:
		tween.tween_property(target, "modulate:a", 0.9, duration)

	tween.set_trans(trans_type)
	tween.set_ease(ease_type)


func animate_hover_out() -> void:
	if not target:
		return

	if tween:
		tween.kill()
	tween = create_tween()

	# Scale back to normal
	if scale_animation:
		tween.tween_property(target, "scale", Vector2.ONE, duration)

	# Position back to original - uses global_position to work with layout systems
	if position_animation:
		tween.tween_property(target, "global_position", original_global_position, duration)

	# Fade back to full
	if fade_animation:
		tween.tween_property(target, "modulate:a", 1.0, duration)

	tween.set_trans(trans_type)
	tween.set_ease(ease_type)
