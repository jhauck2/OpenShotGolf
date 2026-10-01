#@tool
extends MultiMeshInstance3D


func _process(delta: float) -> void:
	if has_node("MeshInstance3D"):
		material_override.set_shader_parameter("object_position", $MeshInstance3D.position)
