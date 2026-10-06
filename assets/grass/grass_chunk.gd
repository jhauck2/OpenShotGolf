#@tool
extends Node3D

var lod_switch := 10.0
var impostor_fade_in_start := 10.0
var impostor_fade_in_end := 40.0
var impostor_fade_out_start := 60.0
var impostor_fade_out_end := 80.0
var grass_fade_out_start := 20.0
var grass_fade_out_end := 60.0


func _ready() -> void:
	$Ground.visible = false


func _process(_delta: float) -> void:
		var camera_pos: Vector3

		if Engine.is_editor_hint():
				camera_pos = EditorInterface.get_editor_viewport_3d().get_camera_3d().global_position
		else:
				camera_pos = get_viewport().get_camera_3d().global_position

		var camera_distance: float = global_position.distance_to(camera_pos) - camera_pos.y

		if camera_distance < lod_switch:
			$Grass.multimesh = preload("res://assets/grass/grass_multimesh_detailed.tres")
		else:
			$Grass.multimesh = preload("res://assets/grass/grass_multimesh_simple.tres")

		var impostor_fade_in: float = smoothstep(impostor_fade_in_start, impostor_fade_in_end, camera_distance)
		var grass_fade_out: float = smoothstep(grass_fade_out_start, grass_fade_out_end, camera_distance)
		var impostor_fade_out: float = smoothstep(impostor_fade_out_start,impostor_fade_out_end, camera_distance)
		
		$Grass.visible = grass_fade_out < 1.0
		$Impostor.visible = impostor_fade_in >= 0.0

		# Interpolate
		$Impostor.set_instance_shader_parameter("alpha", 1.0 - impostor_fade_out)
		$Impostor.set_instance_shader_parameter("ground_alpha", impostor_fade_in)
		$Grass.set_instance_shader_parameter("alpha", 1.0 - grass_fade_out)
