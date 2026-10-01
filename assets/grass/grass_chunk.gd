#@tool
extends Node3D

@export var lod_switch := 10.0
@export var impostor_fade_in_start := 10.0
@export var impostor_fade_in_end := 20.0
@export var grass_fade_out_start := 20.0
@export var grass_fade_out_end := 50.0


func _process(_delta: float) -> void:
		var camera_pos: Vector3

		if Engine.is_editor_hint():
				camera_pos = EditorInterface.get_editor_viewport_3d().get_camera_3d().global_position
		else:
				camera_pos = get_viewport().get_camera_3d().global_position

		var camera_distance: float = global_position.distance_to(camera_pos)

		if camera_distance < lod_switch:
			$Grass.multimesh = preload("res://assets/grass/grass_multimesh_detailed.tres")
		else:
			$Grass.multimesh = preload("res://assets/grass/grass_multimesh_simple.tres")

		var start_to_mid: float = smoothstep(impostor_fade_in_start, impostor_fade_in_end, camera_distance)
		var mid_to_end: float = smoothstep(grass_fade_out_start, grass_fade_out_end, camera_distance)
		
		$Grass.visible = mid_to_end < 1.0
		$Impostor.visible = start_to_mid >= 0.0

		# Interpolate
		$Impostor.set_instance_shader_parameter("alpha", start_to_mid)
		$Grass.set_instance_shader_parameter("alpha", 1.0 - mid_to_end)
