extends CharacterBody3D
class_name GolfBall

const RainPhysics = preload("res://Utils/rain_physics.gd")
const BallTypePhysics = preload("res://Utils/ball_type_physics.gd")

signal rest

const BALL_RADIUS := 0.021335
const TEE_LIFT_HEIGHT := 0.0381 # 1.5 inches in meters
const TEED_CENTER_HEIGHT := BALL_RADIUS + TEE_LIFT_HEIGHT # 0.059435m
const GROUND_CENTER_HEIGHT := BALL_RADIUS # 0.021335m
const START_HEIGHT := TEED_CENTER_HEIGHT
const COLLISION_SAFE_MARGIN := 0.0005
const BELOW_GROUND_RECOVERY_Y := -0.5
const FALLTHROUGH_FAILSAFE_Y := -500.0
const GROUND_SNAP_OFFSET := 0.001
const GROUND_RAYCAST_UP := 2.0
const GROUND_RAYCAST_DOWN := 8.0
const GROUND_PROBE_DISTANCE := 0.08
const MIN_GROUND_NORMAL := 0.7

# Foliage / tree canopy physics parameters
const FOLIAGE_DAMPING_BASE: float = 0.04
const FOLIAGE_DAMPING_MAX: float = 0.14
const FOLIAGE_RAMP_DURATION: float = 0.40
const TREE_CHECK_INTERVAL: float = 0.05 # 20 Hz responsive canopy detection

# Obstacle clearance parameters
const TWO_FEET_METERS: float = 0.6096 # 2 feet in meters (rock clearance)
const TREE_CLEARANCE_RADIUS: float = 1.0 # Minimum clearance away from tree trunks
var _airborne_low_speed_timer: float = 0.0
var _shot_duration: float = 0.0

var ball_model : PackedScene = preload("res://assets/models/balls/golf_ball.glb")
var _ball_mesh: Node3D = null
var _current_ball_graphic_id: String = "single_line"
var _current_ball_type_id: String = BallTypePhysics.TYPE_STANDARD
var _ball_type_bounce_retention: float = 1.0
var _ball_type_spinback_mult: float = 1.0
static var _ball_material_cache: Dictionary = {}
var _tee_mesh: Node3D = null
var current_selected_club: String = "Dr"
var spawn_position := Vector3(0.0, START_HEIGHT, 0.0)

# Preloaded sound streams
var _sfx_hit_drive = preload("res://assets/audio/sfx/golf_tee_shot.wav")
var _sfx_hit_other = preload("res://assets/audio/sfx/golf_sand_shot.mp3")
var _sfx_hit_putt = preload("res://assets/audio/sfx/putt.mp3")
var _sfx_tree_hit = preload("res://assets/audio/sfx/ball_hit_tree.mp3")
var _sfx_leaf_rustle = preload("res://assets/audio/sfx/leaves.mp3")
var _sfx_water_splash = preload("res://assets/audio/sfx/water.mp3")
var _sfx_sand_thud = preload("res://assets/audio/sfx/sand.mp3")
var _sfx_bounce_fairway = preload("res://assets/audio/sfx/fairway_maybe.mp3")
var _sfx_bounce_green = preload("res://assets/audio/sfx/fairway_maybe.mp3")
var _sfx_bounce_cart_path = preload("res://assets/audio/sfx/bounce_cart_path.mp3")
var _sfx_rough_thump = preload("res://assets/audio/sfx/rough.mp3")
var _sfx_cup_drop = preload("res://assets/audio/sfx/cup_drop.mp3")

# SFX players
var _sfx_player: AudioStreamPlayer = null
var tee_shot_view: Node = null
var _leaves_player: AudioStreamPlayer = null
var _cup_player: AudioStreamPlayer = null

# C# addon instances
var _physics
var _aero
var _surface
var _shot_setup
var _physics_params_factory

# Physics parameters
var params = null

# Ball state variables
var state: int = PhysicsEnums.BallState.REST
var omega := Vector3.ZERO  # Angular velocity (rad/s)
var on_ground := false
var floor_normal := Vector3.UP
var is_in_water := false
var water_collider: Node3D = null
var is_in_sand := false
var is_on_cart_path_or_road := false
var lie_type: String = "fairway"
var is_replaying_remote_shot: bool = false

# Cup/hole physical 3D cup parameters & state variables
const CUP_DEPTH := 0.108        # Regulation 4.25 inch (10.8 cm) physical cup depth
const CUP_BEVEL_WIDTH := 0.005  # 5 mm manicured turf lip bevel around cup opening
var is_falling_in_hole := false
var falling_target_hole := Vector3.ZERO
var falling_time := 0.0
var holed_out_this_shot := false
var flight_time := 0.0
var _cached_target_hole := Vector3.ZERO
var _cup_sound_played := false

# Tree canopy detection variables (throttled point check, 20 Hz)
var _has_canopy_trees: bool = false
var _scene_tree_checked: bool = false
var _tree_check_timer: float = 0.0
var _canopy_time: float = 0.0
var _is_in_tree_canopy: bool = false
var _surface_check_timer: float = 0.0

# Precise physics tick tracking for visual camera interpolation
var prev_physics_pos := Vector3.ZERO
var curr_physics_pos := Vector3.ZERO
var _physics_pos_initialized := false

# Cached world colliders
var _cached_terrain_static: CollisionObject3D = null
var _cached_rough_static: CollisionObject3D = null
var _terrain_cache_searched: bool = false


# Surface parameters (base values from C# Surface addon, then multiplied below).
# TODO - some of these values should not be in ball. Ball type shouldn't matter grass viscosity.
# Change the *_mult values to create a different "feel" for this ball without touching global settings.
var surface_type: int = -1
var _surface_zone_stack: Array[int] = []
var _kinetic_friction: float = 0.44
var _rolling_friction: float = 0.085
var _grass_viscosity: float = 0.0020
var _critical_angle: float = 0.30  # radians
var _kinetic_mult := 1.0
var _rolling_mult := 1.0
var _grass_mult := 1.0
var _critical_mult := 1.0
var _spinback_response_scale: float = 0.69
var _spinback_theta_boost_max: float = 0.0
var _spinback_spin_start_rpm: float = 0.0
var _spinback_spin_end_rpm: float = 0.0
var _spinback_speed_start_mps: float = 0.0
var _spinback_speed_end_mps: float = 0.0
@export var slope_force_scale: float = 0.5

# Environment
var _air_density: float
var _air_viscosity: float
# TODO: takeout these scale and mult variables
var _drag_scale := 1.0
var _lift_scale := 1.0

# Shot tracking
var shot_start_pos := Vector3.ZERO
var shot_start_pos_global := Vector3.ZERO
var shot_was_in_sand := false
var shot_was_from_teebox := false
var shot_hit_other_ground := false
var shot_dir := Vector3(1.0, 0.0, 0.0)  # Normalized horizontal direction
var target_dir := Vector3(1.0, 0.0, 0.0)  # Normalized target aim direction (horizontal)
var aim_yaw_offset_deg := 0.0:  # Camera/world rotation offset applied at launch
	set(value):
		aim_yaw_offset_deg = value
		if state == PhysicsEnums.BallState.REST:
			target_dir = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(aim_yaw_offset_deg)).normalized()
			_orient_ball_to_aim()
var launch_spin_rpm := 0.0  # Stored for bounce calculations
var rollout_impact_spin_rpm := 0.0  # Spin on first impact; used for rollout friction
var is_putt := false
var _hit_leaves_this_shot := false
var _hit_trunk_this_shot := false
var hit_tree_this_shot := false
var _skipping_flight := false

# Wind altitude scaling
const WIND_PEAK_ALTITUDE_METERS: float = 25.0
var _current_ground_y: float = 0.0
var _ground_elevation_timer: float = 0.0


# Ball physics constants (cached from C# addon in _init)
var _ball_mass: float
var _ball_radius: float
var _ball_moi: float
var _ball_initialized := false
var _openfairway_error_reported: Dictionary = {}

const OPENFAIRWAY_CLASS_PATHS := {
	"BallPhysics": "res://addons/openfairway/physics/BallPhysics.cs",
	"Aerodynamics": "res://addons/openfairway/physics/Aerodynamics.cs",
	"Surface": "res://addons/openfairway/physics/Surface.cs",
	"PhysicsParams": "res://addons/openfairway/physics/PhysicsParams.cs",
	"ShotSetup": "res://addons/openfairway/physics/ShotSetup.cs",
	"PhysicsParamsFactory": "res://addons/openfairway/physics/PhysicsParamsFactory.cs",
}
const DEFAULT_BALL_MASS := 0.04592623
const DEFAULT_BALL_RADIUS := 0.021335
const DEFAULT_BALL_MOI := 0.4 * DEFAULT_BALL_MASS * DEFAULT_BALL_RADIUS * DEFAULT_BALL_RADIUS


func _ready() -> void:
	add_to_group("golf_ball")
	_try_initialize_ball()
	_create_physics_params()
	reset()
	
	# Create physical impact SFX player
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "BallSfxPlayer"
	add_child(_sfx_player)

	# Create leaves rustling SFX player
	_leaves_player = AudioStreamPlayer.new()
	_leaves_player.name = "BallLeavesPlayer"
	_leaves_player.stream = _sfx_leaf_rustle
	add_child(_leaves_player)

	# Create ball cup drop SFX player
	_cup_player = AudioStreamPlayer.new()
	_cup_player.name = "BallCupPlayer"
	_cup_player.stream = _sfx_cup_drop
	add_child(_cup_player)



func _new_openfairway(openfairway_class: StringName):
	var class_key := String(openfairway_class)
	var fallback_script_path: String = OPENFAIRWAY_CLASS_PATHS.get(class_key, "")
	if fallback_script_path != "":
		var script_resource: Script = load(fallback_script_path) as Script
		if script_resource != null:
			var instance = script_resource.new()
			if instance != null:
				return instance

	if fallback_script_path == "" and ClassDB.class_exists(openfairway_class) and ClassDB.can_instantiate(openfairway_class):
		var classdb_instance = ClassDB.instantiate(openfairway_class)
		if classdb_instance != null:
			return classdb_instance

	if not _openfairway_error_reported.has(class_key):
		_openfairway_error_reported[class_key] = true
		if not OS.has_feature("C#"):
			push_error("OpenFairway class '%s' is unavailable because this runtime has no C# support. Launch the project with the Godot .NET editor/runtime." % class_key)
		elif fallback_script_path != "":
			push_error("OpenFairway class '%s' could not be instantiated from '%s'. Build HeckleGolfSim.csproj and restart the Godot .NET editor/runtime." % [class_key, fallback_script_path])
		else:
			push_error("OpenFairway class '%s' is unavailable. Build HeckleGolfSim.csproj and restart the Godot .NET editor/runtime." % class_key)
	return null


var _property_name_cache: Dictionary = {}
var _method_name_cache: Dictionary = {}


func _resolve_openfairway_property(target: Object, snake_name: StringName, pascal_name: StringName) -> StringName:
	if target == null:
		return &""
	var target_class := target.get_class()
	var cache_key := target_class + ":" + String(snake_name)
	if _property_name_cache.has(cache_key):
		return _property_name_cache[cache_key]

	if snake_name in target:
		_property_name_cache[cache_key] = snake_name
		return snake_name
	elif pascal_name in target:
		_property_name_cache[cache_key] = pascal_name
		return pascal_name

	for property_info in target.get_property_list():
		var p_name = StringName(property_info.get("name", ""))
		if p_name == snake_name:
			_property_name_cache[cache_key] = snake_name
			return snake_name
		if p_name == pascal_name:
			_property_name_cache[cache_key] = pascal_name
			return pascal_name

	_property_name_cache[cache_key] = &""
	return &""


func _has_openfairway_property(target: Object, property_name: StringName) -> bool:
	if target == null:
		return false
	var target_class := target.get_class()
	var cache_key := target_class + ":" + String(property_name)
	if _property_name_cache.has(cache_key):
		return _property_name_cache[cache_key] != &""
	if property_name in target:
		_property_name_cache[cache_key] = property_name
		return true
	for property_info in target.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			_property_name_cache[cache_key] = property_name
			return true
	_property_name_cache[cache_key] = &""
	return false


func _get_openfairway_property(target: Object, snake_name: StringName, pascal_name: StringName, default_value = null):
	var prop_name := _resolve_openfairway_property(target, snake_name, pascal_name)
	if prop_name != &"":
		return target.get(prop_name)
	return default_value


func _set_openfairway_property(target: Object, snake_name: StringName, pascal_name: StringName, value) -> bool:
	var prop_name := _resolve_openfairway_property(target, snake_name, pascal_name)
	if prop_name != &"":
		target.set(prop_name, value)
		return true
	return false


func _resolve_openfairway_method(target: Object, snake_name: StringName, pascal_name: StringName) -> StringName:
	if target == null:
		return &""
	var target_class := target.get_class()
	var cache_key := target_class + ":" + String(snake_name)
	if _method_name_cache.has(cache_key):
		return _method_name_cache[cache_key]

	if target.has_method(snake_name):
		_method_name_cache[cache_key] = snake_name
		return snake_name
	elif target.has_method(pascal_name):
		_method_name_cache[cache_key] = pascal_name
		return pascal_name

	_method_name_cache[cache_key] = &""
	return &""


func _call_openfairway_method(target: Object, snake_name: StringName, pascal_name: StringName, args: Array = []):
	var method_name := _resolve_openfairway_method(target, snake_name, pascal_name)
	if method_name != &"":
		return target.callv(method_name, args)
	return null


func _init_openfairway_instances() -> bool:
	_physics = _new_openfairway(&"BallPhysics")
	_aero = _new_openfairway(&"Aerodynamics")
	_surface = _new_openfairway(&"Surface")
	_shot_setup = _new_openfairway(&"ShotSetup")
	_physics_params_factory = _new_openfairway(&"PhysicsParamsFactory")
	if _physics == null or _aero == null or _surface == null:
		return false
	_ball_mass = float(_get_openfairway_property(_physics, &"ball_mass", &"BallMass", DEFAULT_BALL_MASS))
	_ball_radius = float(_get_openfairway_property(_physics, &"ball_radius", &"BallRadius", DEFAULT_BALL_RADIUS))
	_ball_moi = float(_get_openfairway_property(_physics, &"ball_moment_of_inertia", &"BallMomentOfInertia", DEFAULT_BALL_MOI))
	return true


func _try_initialize_ball() -> bool:
	if _ball_initialized:
		return true
	if not _init_openfairway_instances():
		return false
	initialize_ball()
	_ball_initialized = true
	return true


func initialize_ball() -> void:
	# Put ball on physics layer 3 (bitmask 4) so terrain/ground raycasts on layer 1 do not hit it.
	# Ball still collides with all terrain/props on layer 1 via collision_mask = 1.
	collision_layer = 4
	collision_mask = 1
	_connect_settings()
	_update_environment()
	set_surface(int(GlobalSettings.range_settings.surface_type.value))
	_create_collision_and_model()


func get_visual_scale() -> float:
	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("GlobalSettings"):
		var gs = tree.root.get_node("GlobalSettings")
		if gs != null and gs.range_settings != null and gs.range_settings.settings.has("ball_visual_scale"):
			return float(gs.range_settings.ball_visual_scale.value)
	return 1.35


func get_visual_y_offset() -> float:
	return _ball_radius * (get_visual_scale() - 1.0)


func get_mesh_scale() -> float:
	return (_ball_radius / 1.007168) * get_visual_scale()


func _on_ball_visual_scale_changed(_val = null) -> void:
	if _ball_mesh != null and is_instance_valid(_ball_mesh):
		var mesh_scale := get_mesh_scale()
		_ball_mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
		_ball_mesh.position.y = get_visual_y_offset()
		_orient_ball_to_aim()


func _create_collision_and_model():
	# Create collision shape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.set_radius(_ball_radius)
	collision.set_shape(shape)
	add_child(collision)
	# Create model
	_ball_mesh = ball_model.instantiate()
	# golf_ball.glb Icosphere has radius ~1.007168m; scale so visual mesh matches physical ball radius with visual scaling
	var mesh_scale := get_mesh_scale()
	_ball_mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
	_ball_mesh.position.y = get_visual_y_offset()

	# Canonical alignment of Icosphere planar UV projection
	# Maps texture +U (horizontal equator/aim) along local +X, texture normal (pole) along local +Y (crown),
	# and texture +V (right) along local +Z, forming an exact right-handed orthonormal basis.
	var icosphere = _ball_mesh.find_child("Icosphere", true, false) as MeshInstance3D
	if icosphere != null:
		var c0 := Vector3(0.88574782, -0.42354276, -0.18990081)
		var c1 := Vector3(-0.00734311, -0.42185689, 0.90663270)
		var c2 := Vector3(-0.46410868, -0.80165348, -0.37676894)
		icosphere.transform.basis = Basis(c0, c1, c2)

	add_child(_ball_mesh)
	apply_ball_graphic(_current_ball_graphic_id)
	_orient_ball_to_aim()

	# Create 3D golf tee peg model
	_tee_mesh = Node3D.new()
	_tee_mesh.name = "TeePeg"
	var tee_instance = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.0045 # Flared head under ball
	cyl.bottom_radius = 0.0018 # Peg shaft
	cyl.height = TEE_LIFT_HEIGHT
	cyl.radial_segments = 16
	var tee_mat = StandardMaterial3D.new()
	tee_mat.albedo_color = Color(0.96, 0.95, 0.92) # Classic white golf tee
	tee_mat.roughness = 0.35
	tee_instance.mesh = cyl
	tee_instance.material_override = tee_mat
	tee_instance.position.y = -_ball_radius - (TEE_LIFT_HEIGHT / 2.0)
	_tee_mesh.add_child(tee_instance)
	_tee_mesh.visible = false
	add_child(_tee_mesh)


func _check_scene_has_trees() -> bool:
	if _scene_tree_checked:
		return _has_canopy_trees
	_scene_tree_checked = true
	var current_scene = get_tree().current_scene if is_inside_tree() else null
	if current_scene != null:
		# Range scene has no trees
		if current_scene.name == "Range" or (current_scene.scene_file_path != "" and current_scene.scene_file_path.ends_with("range.tscn")):
			_has_canopy_trees = false
			return false
		# Look for TreesFolder or CanopyArea in course
		if current_scene.has_node("TreesFolder") or current_scene.find_child("CanopyArea", true, false) != null or current_scene.find_child("ConsolidatedCanopyArea", true, false) != null:
			_has_canopy_trees = true
			return true
	_has_canopy_trees = false
	return false


func _check_tree_canopy() -> void:
	var world := get_world_3d()
	if world == null:
		_is_in_tree_canopy = false
		return
	var point_query := PhysicsPointQueryParameters3D.new()
	point_query.position = global_position
	point_query.collide_with_areas = true
	point_query.collide_with_bodies = false
	point_query.collision_mask = 1
	var results := world.direct_space_state.intersect_point(point_query, 4)
	var found_canopy := false
	for hit in results:
		var col = hit.get("collider")
		if col is Area3D and (col.name == "CanopyArea" or col.name == "ConsolidatedCanopyArea" or col.has_meta("is_canopy")):
			found_canopy = true
			break
	_is_in_tree_canopy = found_canopy


func _is_collider_tree(collider: Object) -> bool:
	if collider == null:
		return false
	if collider.has_meta("is_tree"):
		return bool(collider.get_meta("is_tree"))
	if collider is Node and (collider.is_in_group("trees") or collider.is_in_group("tree")):
		return true
	var c_name := String(collider.name).to_lower()
	if c_name.contains("tree") or c_name.contains("trunk") or c_name.contains("branch") or c_name.contains("foliage") or c_name.contains("canopy"):
		return true
	var parent := (collider as Node).get_parent() if collider is Node else null
	if parent != null:
		if parent.has_meta("is_tree") and bool(parent.get_meta("is_tree")):
			return true
		if parent.is_in_group("trees") or parent.is_in_group("tree"):
			return true
		var p_name := String(parent.name).to_lower()
		if p_name.contains("tree") or p_name.contains("trunk") or p_name.contains("branch") or p_name.contains("foliage") or p_name.contains("canopy"):
			return true
	return false


func _is_collider_flagstick(collider: Object) -> bool:
	if collider == null:
		return false
	if collider.has_meta("is_flagstick"):
		return bool(collider.get_meta("is_flagstick"))
	var c_name := String(collider.name)
	if c_name.containsn("flagstick") or c_name.containsn("flagpole") or c_name.containsn("flagpin") or c_name.containsn("pinmarker"):
		return true
	var parent := (collider as Node).get_parent() if collider is Node else null
	if parent != null:
		if parent.has_meta("is_flagstick") or String(parent.name).containsn("flagpin"):
			return true
	return false


func _is_collider_rock(collider: Object) -> bool:
	if collider == null:
		return false
	if collider.has_meta("is_rock") and bool(collider.get_meta("is_rock")):
		return true
	if collider is Node and (collider.is_in_group("rocks") or collider.is_in_group("rock")):
		return true
	var c_name := String(collider.name).to_lower()
	if c_name.begins_with("rock") or c_name.contains("rock"):
		return true
	var parent := (collider as Node).get_parent() if collider is Node else null
	if parent != null:
		if parent.has_meta("is_rock") and bool(parent.get_meta("is_rock")):
			return true
		if parent.is_in_group("rocks") or parent.is_in_group("rock"):
			return true
		var p_name := String(parent.name).to_lower()
		if p_name.begins_with("rock") or p_name.contains("rock"):
			return true
	return false


func _get_nearby_rocks(pos: Vector3, max_dist: float) -> Array:
	var rocks: Array = []
	var world := get_world_3d()
	if world != null and world.direct_space_state != null:
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = max_dist
		query.shape = sphere
		query.transform = Transform3D(Basis(), pos)
		query.collision_mask = 1
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		var hits := world.direct_space_state.intersect_shape(query, 64)
		for hit in hits:
			var col = hit.get("collider")
			if col != null and _is_collider_rock(col):
				var target_node = col
				if col is CollisionObject3D and col.get_child_count() > 1 and hit.has("shape"):
					var owner_id: int = col.shape_find_owner(int(hit["shape"]))
					if owner_id != -1:
						var shape_node = col.shape_owner_get_owner(owner_id)
						if shape_node is Node3D:
							target_node = shape_node
				if not rocks.has(target_node):
					rocks.append(target_node)

	if get_tree() != null:
		var group_rocks := get_tree().get_nodes_in_group("rocks")
		for r in group_rocks:
			if r is Node3D and not rocks.has(r):
				var r_scale: float = 1.0
				if "scale" in r:
					r_scale = maxf(r.scale.x, maxf(r.scale.y, r.scale.z))
				if pos.distance_to(r.global_position) <= (r_scale * 0.9 + max_dist):
					rocks.append(r)
	return rocks


func _get_nearby_trees(pos: Vector3, max_dist: float) -> Array:
	var trees: Array = []
	var world := get_world_3d()
	if world != null and world.direct_space_state != null:
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = max_dist
		query.shape = sphere
		query.transform = Transform3D(Basis(), pos)
		query.collision_mask = 1
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		var hits := world.direct_space_state.intersect_shape(query, 64)
		for hit in hits:
			var col = hit.get("collider")
			if col != null and _is_collider_tree(col):
				var target_node = col
				if col is CollisionObject3D and col.get_child_count() > 1 and hit.has("shape"):
					var owner_id: int = col.shape_find_owner(int(hit["shape"]))
					if owner_id != -1:
						var shape_node = col.shape_owner_get_owner(owner_id)
						if shape_node is Node3D:
							target_node = shape_node
				if not trees.has(target_node):
					trees.append(target_node)

	if get_tree() != null:
		var group_trees := get_tree().get_nodes_in_group("trees")
		for t in group_trees:
			if t is Node3D and not trees.has(t):
				if t.name == "ConsolidatedFoliageCollision" or not t.is_visible_in_tree():
					continue
				var t_scale: float = 1.0
				if "scale" in t:
					t_scale = maxf(t.scale.x, maxf(t.scale.y, t.scale.z))
				var trunk_rad := 0.28 * t_scale
				var t_pos: Vector3 = t.global_position
				var dist_2d := Vector2(pos.x - t_pos.x, pos.z - t_pos.z).length()
				if dist_2d <= (trunk_rad + max_dist):
					trees.append(t)
	return trees


func _get_ground_y_at(x: float, z: float) -> float:
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null or not course.has_method("get_height"):
		var root = get_tree().current_scene if get_tree() != null else null
		if root != null and root.has_method("get_height"):
			course = root

	if course != null and course.has_method("get_height"):
		return float(course.call("get_height", x, z))

	var world := get_world_3d()
	if world != null and world.direct_space_state != null:
		var ray_start := Vector3(x, 500.0, z)
		var ray_end := Vector3(x, -500.0, z)
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [get_rid()]
		for attempt in range(5):
			var hit := world.direct_space_state.intersect_ray(query)
			if hit.is_empty():
				break
			var col = hit.get("collider")
			if col != null and (_is_collider_rock(col) or _is_collider_tree(col)):
				query.exclude.append(col.get_rid())
			else:
				return float(hit["position"].y)

	if not spawn_position.is_zero_approx():
		return spawn_position.y
	return 0.0


func _is_position_in_water(x: float, z: float, y_ref: float) -> bool:
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null:
		course = get_tree().current_scene if get_tree() != null else null

	if course != null and "water_polygons" in course:
		var w_polys = course.water_polygons
		if w_polys is Array:
			var pt_2d := Vector2(x, z)
			for poly in w_polys:
				if poly is PackedVector2Array and Geometry2D.is_point_in_polygon(pt_2d, poly):
					return true

	var world := get_world_3d()
	if world != null and world.direct_space_state != null:
		var ray_start := Vector3(x, y_ref + 2.0, z)
		var ray_end := Vector3(x, y_ref - 5.0, z)
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [get_rid()]
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var col = hit.get("collider")
			if col != null and ((col.has_meta("is_water") and bool(col.get_meta("is_water"))) or col.name.to_lower().contains("water")):
				return true
	return false


## Checks if the ball ends within 2 feet (0.6096m) of any rock, and moves the ball 2 feet away onto playable ground.
func ensure_rock_clearance() -> bool:
	var rocks := _get_nearby_rocks(global_position, TWO_FEET_METERS)
	if rocks.is_empty():
		return false

	var ball_pos_2d := Vector2(global_position.x, global_position.z)
	var away_dir_2d := Vector2.ZERO
	for r in rocks:
		var r_pos_3d: Vector3 = r.global_position if r is Node3D else global_position
		var diff := ball_pos_2d - Vector2(r_pos_3d.x, r_pos_3d.z)
		if diff.length_squared() > 0.0001:
			away_dir_2d += diff.normalized()
		else:
			away_dir_2d += Vector2(1.0, 0.0)

	if away_dir_2d.length_squared() > 0.0001:
		away_dir_2d = away_dir_2d.normalized()
	else:
		if not shot_start_pos_global.is_zero_approx():
			var s_diff := Vector2(shot_start_pos_global.x - global_position.x, shot_start_pos_global.z - global_position.z)
			if s_diff.length_squared() > 0.0001:
				away_dir_2d = s_diff.normalized()
		if away_dir_2d.length_squared() <= 0.0001:
			away_dir_2d = Vector2(0.0, 1.0)

	var test_angles = [
		0.0,
		deg_to_rad(30.0), deg_to_rad(-30.0),
		deg_to_rad(60.0), deg_to_rad(-60.0),
		deg_to_rad(90.0), deg_to_rad(-90.0),
		deg_to_rad(120.0), deg_to_rad(-120.0),
		deg_to_rad(150.0), deg_to_rad(-150.0),
		deg_to_rad(180.0)
	]

	var best_pos: Vector3 = Vector3.ZERO
	var found_spot := false

	# Step outward starting from 2 feet (0.6096m), increasing if the rock is large or multiple rocks are nearby
	for dist_mult in [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0]:
		var test_dist: float = TWO_FEET_METERS * dist_mult
		for angle in test_angles:
			var cand_dir: Vector2 = away_dir_2d.rotated(angle)
			var cand_2d: Vector2 = ball_pos_2d + cand_dir * test_dist
			var cand_y: float = _get_ground_y_at(cand_2d.x, cand_2d.y)
			var cand_pos := Vector3(cand_2d.x, cand_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET, cand_2d.y)

			if _is_position_in_water(cand_2d.x, cand_2d.y, cand_y):
				continue

			var rocks_at_cand := _get_nearby_rocks(cand_pos, TWO_FEET_METERS)
			if rocks_at_cand.is_empty():
				best_pos = cand_pos
				found_spot = true
				break

		if found_spot:
			break

	if not found_spot:
		# Fallback: move 2 feet along away_dir_2d
		var cand_2d: Vector2 = ball_pos_2d + away_dir_2d * TWO_FEET_METERS
		var cand_y: float = _get_ground_y_at(cand_2d.x, cand_2d.y)
		best_pos = Vector3(cand_2d.x, cand_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET, cand_2d.y)

	var prev_pos := global_position
	global_position = best_pos
	curr_physics_pos = best_pos
	prev_physics_pos = best_pos
	_current_ground_y = best_pos.y - (GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET)
	_update_surface_from_underneath()

	print("[ball.gd] Rock relief applied: Ball ended within 2 feet of rock at %s. Moved 2 feet away to %s." % [str(prev_pos), str(best_pos)])
	return true


## Checks if the ball ends within tree trunk collision radius (1.0m) and moves the ball clear of the tree onto playable ground.
func ensure_tree_clearance() -> bool:
	var trees := _get_nearby_trees(global_position, TREE_CLEARANCE_RADIUS)
	if trees.is_empty():
		return false

	var ball_pos_2d := Vector2(global_position.x, global_position.z)
	var away_dir_2d := Vector2.ZERO
	for t in trees:
		var t_pos_3d: Vector3 = t.global_position if t is Node3D else global_position
		var diff := ball_pos_2d - Vector2(t_pos_3d.x, t_pos_3d.z)
		if diff.length_squared() > 0.0001:
			away_dir_2d += diff.normalized()
		else:
			away_dir_2d += Vector2(1.0, 0.0)

	if away_dir_2d.length_squared() > 0.0001:
		away_dir_2d = away_dir_2d.normalized()
	else:
		if not shot_start_pos_global.is_zero_approx():
			var s_diff := Vector2(shot_start_pos_global.x - global_position.x, shot_start_pos_global.z - global_position.z)
			if s_diff.length_squared() > 0.0001:
				away_dir_2d = s_diff.normalized()
		if away_dir_2d.length_squared() <= 0.0001:
			away_dir_2d = Vector2(0.0, 1.0)

	var test_angles = [
		0.0,
		deg_to_rad(30.0), deg_to_rad(-30.0),
		deg_to_rad(60.0), deg_to_rad(-60.0),
		deg_to_rad(90.0), deg_to_rad(-90.0),
		deg_to_rad(120.0), deg_to_rad(-120.0),
		deg_to_rad(150.0), deg_to_rad(-150.0),
		deg_to_rad(180.0)
	]

	var best_pos: Vector3 = Vector3.ZERO
	var found_spot := false

	for dist_mult in [1.2, 1.6, 2.0, 2.5, 3.0]:
		var test_dist: float = TREE_CLEARANCE_RADIUS * dist_mult
		for angle in test_angles:
			var cand_dir: Vector2 = away_dir_2d.rotated(angle)
			var cand_2d: Vector2 = ball_pos_2d + cand_dir * test_dist
			var cand_y: float = _get_ground_y_at(cand_2d.x, cand_2d.y)
			var cand_pos := Vector3(cand_2d.x, cand_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET, cand_2d.y)

			if _is_position_in_water(cand_2d.x, cand_2d.y, cand_y):
				continue

			var trees_at_cand := _get_nearby_trees(cand_pos, TREE_CLEARANCE_RADIUS)
			var rocks_at_cand := _get_nearby_rocks(cand_pos, TWO_FEET_METERS)
			if trees_at_cand.is_empty() and rocks_at_cand.is_empty():
				best_pos = cand_pos
				found_spot = true
				break

		if found_spot:
			break

	if not found_spot:
		var cand_2d: Vector2 = ball_pos_2d + away_dir_2d * (TREE_CLEARANCE_RADIUS * 1.5)
		var cand_y: float = _get_ground_y_at(cand_2d.x, cand_2d.y)
		best_pos = Vector3(cand_2d.x, cand_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET, cand_2d.y)

	var prev_pos := global_position
	global_position = best_pos
	curr_physics_pos = best_pos
	prev_physics_pos = best_pos
	_current_ground_y = best_pos.y - (GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET)
	_update_surface_from_underneath()

	print("[ball.gd] Tree clearance applied: Ball ended within tree at %s. Moved to %s." % [str(prev_pos), str(best_pos)])
	return true



func _connect_settings() -> void:
	if not GlobalSettings.range_settings.temperature.setting_changed.is_connected(_on_environment_changed):
		GlobalSettings.range_settings.temperature.setting_changed.connect(_on_environment_changed)
	if not GlobalSettings.range_settings.altitude.setting_changed.is_connected(_on_environment_changed):
		GlobalSettings.range_settings.altitude.setting_changed.connect(_on_environment_changed)
	if not GlobalSettings.range_settings.range_units.setting_changed.is_connected(_on_environment_changed):
		GlobalSettings.range_settings.range_units.setting_changed.connect(_on_environment_changed)
	if not GlobalSettings.range_settings.surface_type.setting_changed.is_connected(_on_surface_type_changed):
		GlobalSettings.range_settings.surface_type.setting_changed.connect(_on_surface_type_changed)
	if not GlobalSettings.range_settings.green_speed.setting_changed.is_connected(_on_green_speed_changed):
		GlobalSettings.range_settings.green_speed.setting_changed.connect(_on_green_speed_changed)
	if GlobalSettings.range_settings.settings.has("ball_visual_scale") and not GlobalSettings.range_settings.ball_visual_scale.setting_changed.is_connected(_on_ball_visual_scale_changed):
		GlobalSettings.range_settings.ball_visual_scale.setting_changed.connect(_on_ball_visual_scale_changed)
	
	if is_inside_tree() and has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected") and not eb.is_connected("club_selected", Callable(self, "_on_club_selected")):
			eb.connect("club_selected", Callable(self, "_on_club_selected"))


func _on_club_selected(club_name: String) -> void:
	current_selected_club = club_name
	_update_tee_elevation()


func can_tee_up() -> bool:
	# Driving range always allows teeing up
	var player_parent = get_parent()
	var parent_scene = player_parent.get_parent() if player_parent != null else null
	if parent_scene != null:
		if ("is_driving_range" in parent_scene and bool(parent_scene.get("is_driving_range"))) or (parent_scene.has_meta("is_driving_range") and bool(parent_scene.get_meta("is_driving_range"))):
			return true
	var cur_scene = get_tree().current_scene if is_inside_tree() else null
	if cur_scene != null:
		if ("is_driving_range" in cur_scene and bool(cur_scene.get("is_driving_range"))) or (cur_scene.has_meta("is_driving_range") and bool(cur_scene.get_meta("is_driving_range"))):
			return true
		if "practice_mode_active" in cur_scene and bool(cur_scene.practice_mode_active):
			return true

	# On a course, only the first shot for a player on a hole (0 strokes taken) can be teed up.
	# Never tee up on second or subsequent shots even if the ball lands or stops in a tee box.
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var ap = mp_mgr.get_active_player()
		if ap != null and not ap.is_empty():
			return int(ap.get("strokes", 0)) == 0

	if cur_scene != null and "shot_count" in cur_scene:
		return int(cur_scene.shot_count) == 0

	return false


func _update_tee_elevation() -> void:
	if _tee_mesh == null:
		return
	if state != PhysicsEnums.BallState.REST:
		_tee_mesh.visible = false
		return

	var is_teebox := (lie_type == "teebox")
	if not is_teebox or not can_tee_up():
		_tee_mesh.visible = false
		return

	var is_driver := current_selected_club.to_lower() in ["dr", "driver", "1w"]
	var probe := _try_probe_ground()
	if probe.get("hit", false):
		var hit_pos: Vector3 = probe.get("position", Vector3.ZERO)
		var hit_norm: Vector3 = probe.get("normal", Vector3.UP)
		var nys := maxf(hit_norm.y, MIN_GROUND_NORMAL)
		if is_driver:
			_tee_mesh.visible = true
			global_position.y = hit_pos.y + TEED_CENTER_HEIGHT
		else:
			_tee_mesh.visible = false
			global_position.y = hit_pos.y + (_ball_radius + GROUND_SNAP_OFFSET) / nys
			floor_normal = hit_norm
			on_ground = true
	_orient_ball_to_aim()


func _create_physics_params():
	if params != null:
		return
	if _physics_params_factory != null:
		var created_params = _call_openfairway_method(
			_physics_params_factory,
			&"create_params",
			&"CreateParams",
			[
				_air_density,
				_air_viscosity,
				_drag_scale,
				_lift_scale,
				surface_type,
				floor_normal,
				rollout_impact_spin_rpm,
				0.0,
				0.0,
				0.0,
				is_putt,
				1.0
			]
		)
		if created_params == null:
			created_params = _call_openfairway_method(
				_physics_params_factory,
				&"create_params",
				&"CreateParams",
				[
					_air_density,
					_air_viscosity,
					_drag_scale,
					_lift_scale,
					surface_type,
					floor_normal,
					rollout_impact_spin_rpm,
					0.0,
					0.0,
					0.0
				]
			)
		if created_params != null:
			params = created_params
			_set_openfairway_property(params, &"slope_force_scale", &"SlopeForceScale", slope_force_scale)
			_apply_surface_params()
			return

	var _params = _new_openfairway(&"PhysicsParams")
	if _params == null:
		return
	_set_openfairway_property(_params, &"air_density", &"AirDensity", _air_density)
	_set_openfairway_property(_params, &"air_viscosity", &"AirViscosity", _air_viscosity)
	_set_openfairway_property(_params, &"drag_scale", &"DragScale", _drag_scale)
	_set_openfairway_property(_params, &"lift_scale", &"LiftScale", _lift_scale)
	_set_openfairway_property(_params, &"kinetic_friction", &"KineticFriction", _kinetic_friction)
	_set_openfairway_property(_params, &"rolling_friction", &"RollingFriction", _rolling_friction)
	_set_openfairway_property(_params, &"grass_viscosity", &"GrassViscosity", _grass_viscosity)
	_set_openfairway_property(_params, &"critical_angle", &"CriticalAngle", _critical_angle)
	_set_openfairway_property(_params, &"floor_normal", &"FloorNormal", floor_normal)
	_set_openfairway_property(_params, &"rollout_impact_spin", &"RolloutImpactSpin", rollout_impact_spin_rpm)
	_set_openfairway_property(_params, &"slope_force_scale", &"SlopeForceScale", slope_force_scale)
	_set_openfairway_property(_params, &"initial_launch_angle_deg", &"InitialLaunchAngleDeg", 0.0)
	_set_openfairway_property(_params, &"is_putt", &"IsPutt", false)
	_set_openfairway_property(_params, &"lateral_curve_scale", &"LateralCurveScale", 1.0)
	
	params = _params

func _on_environment_changed(_value) -> void:
	_update_environment()

# TODO: clean up surface type and surface stack
func _on_surface_type_changed(value) -> void:
	if _surface_zone_stack.is_empty():
		set_surface(int(value))


func _on_green_speed_changed(_value) -> void:
	_apply_surface_params()


func _update_environment() -> void:
	var units: int = GlobalSettings.range_settings.range_units.value
	var density = _call_openfairway_method(
		_aero,
		&"get_air_density",
		&"GetAirDensity",
		[GlobalSettings.range_settings.altitude.value, GlobalSettings.range_settings.temperature.value, units]
	)
	var viscosity = _call_openfairway_method(
		_aero,
		&"get_dynamic_viscosity",
		&"GetDynamicViscosity",
		[GlobalSettings.range_settings.temperature.value, units]
	)
	if density == null:
		_air_density = 1.225
	if viscosity == null:
		_air_viscosity = 0.0000181
		return
	_air_density = float(density)
	_air_viscosity = float(viscosity)
	if params != null:
		_set_openfairway_property(params, &"air_density", &"AirDensity", _air_density)
		_set_openfairway_property(params, &"air_viscosity", &"AirViscosity", _air_viscosity)


func set_surface(surface: int) -> void:
	if surface_type == surface:
		return
	surface_type = surface
	_apply_surface_params()


func enter_surface_zone(surface: int) -> void:
	_surface_zone_stack.append(surface)
	set_surface(surface)


func exit_surface_zone(surface: int) -> void:
	for i in range(_surface_zone_stack.size() - 1, -1, -1):
		if _surface_zone_stack[i] == surface:
			_surface_zone_stack.remove_at(i)
			break

	if not _surface_zone_stack.is_empty():
		set_surface(_surface_zone_stack[_surface_zone_stack.size() - 1])
	else:
		set_surface(int(GlobalSettings.range_settings.surface_type.value))


func _apply_surface_params() -> void:
	if _surface == null:
		_try_initialize_ball()
	if _surface == null:
		return
	var params_variant = _call_openfairway_method(_surface, &"get_params", &"GetParams", [surface_type])
	var surface_params: Dictionary = {}
	if typeof(params_variant) == TYPE_DICTIONARY:
		surface_params = params_variant
	else:
		if is_in_sand or surface_type == PhysicsEnums.SurfaceType.BUNKER:
			surface_params = {"u_k": 0.95, "u_kr": 0.42, "nu_g": 0.020, "theta_c": 0.45}
		else:
			surface_params = {"u_k": 0.30, "u_kr": 0.085, "nu_g": 0.0014, "theta_c": 0.285}
	_kinetic_friction = float(surface_params.get("u_k", 0.30)) * _kinetic_mult
	_rolling_friction = float(surface_params.get("u_kr", 0.085)) * _rolling_mult
	
	# Determine green speed scaling exponent based on surface type.
	# Only GREEN uses the shifted effective green speed (where default 10.0 -> 5.0);
	# fairway/rough/other surfaces scale around the raw 10.0 baseline so default fairway
	# friction matches SurfacePhysicsCatalog (0.165) instead of exceeding rough (0.175).
	var green_speed = float(GlobalSettings.get_effective_green_speed())
	if surface_type != PhysicsEnums.SurfaceType.GREEN and GlobalSettings.range_settings != null and "green_speed" in GlobalSettings.range_settings:
		green_speed = float(GlobalSettings.range_settings.green_speed.value)
	var exponent := 0.0
	if is_in_sand or surface_type == PhysicsEnums.SurfaceType.BUNKER:
		exponent = 0.0
	elif surface_type == PhysicsEnums.SurfaceType.GREEN:
		exponent = 1.0
	elif surface_type == PhysicsEnums.SurfaceType.FAIRWAY or surface_type == PhysicsEnums.SurfaceType.FAIRWAY_SOFT:
		exponent = 0.40
	elif surface_type == PhysicsEnums.SurfaceType.ROUGH:
		exponent = 0.20
	else:
		exponent = 0.30 # Fallback for other surfaces like FIRM
		
	var speed_mult = pow(10.0 / green_speed, exponent)
	
	# Default friction scale is 1.0 (baseline calibrated to Stimp 10 physics)
	var default_friction_scale := 1.0
	
	_kinetic_friction *= speed_mult * default_friction_scale
	_rolling_friction *= speed_mult * default_friction_scale
	_grass_viscosity = float(surface_params.get("nu_g", 0.0010)) * _grass_mult

	# In rain, shot rollout is reduced by 60% (2.5x friction multiplier)
	if RainPhysics.is_rain_active():
		_kinetic_friction *= RainPhysics.RAIN_FRICTION_MULTIPLIER
		_rolling_friction *= RainPhysics.RAIN_FRICTION_MULTIPLIER
		_grass_viscosity *= RainPhysics.RAIN_FRICTION_MULTIPLIER
	_critical_angle = float(surface_params.get("theta_c", 0.25)) * _critical_mult
	_spinback_response_scale = float(surface_params.get("spinback_response_scale", 0.69)) * _ball_type_spinback_mult
	_spinback_theta_boost_max = float(surface_params.get("spinback_theta_boost_max", 0.0))
	_spinback_spin_start_rpm = float(surface_params.get("spinback_spin_start_rpm", 0.0))
	_spinback_spin_end_rpm = float(surface_params.get("spinback_spin_end_rpm", 0.0))
	_spinback_speed_start_mps = float(surface_params.get("spinback_speed_start_mps", 0.0))
	_spinback_speed_end_mps = float(surface_params.get("spinback_speed_end_mps", 0.0))

	if params != null:
		_set_openfairway_property(params, &"kinetic_friction", &"KineticFriction", _kinetic_friction)
		_set_openfairway_property(params, &"rolling_friction", &"RollingFriction", _rolling_friction)
		_set_openfairway_property(params, &"grass_viscosity", &"GrassViscosity", _grass_viscosity)
		_set_openfairway_property(params, &"critical_angle", &"CriticalAngle", _critical_angle)
		_set_openfairway_property(params, &"spinback_response_scale", &"SpinbackResponseScale", _spinback_response_scale)
		_set_openfairway_property(params, &"spinback_theta_boost_max", &"SpinbackThetaBoostMax", _spinback_theta_boost_max)
		_set_openfairway_property(params, &"spinback_spin_start_rpm", &"SpinbackSpinStartRpm", _spinback_spin_start_rpm)
		_set_openfairway_property(params, &"spinback_spin_end_rpm", &"SpinbackSpinEndRpm", _spinback_spin_end_rpm)
		_set_openfairway_property(params, &"spinback_speed_start_mps", &"SpinbackSpeedStartMps", _spinback_speed_start_mps)
		_set_openfairway_property(params, &"spinback_speed_end_mps", &"SpinbackSpeedEndMps", _spinback_speed_end_mps)

	if OS.is_debug_build():
		print("Surface set to %s (sand=%s) -> u_k=%.3f, u_kr=%.3f, nu_g=%.4f, theta_c=%.3f, speed_mult=%.3f" % [
			str(surface_type), str(is_in_sand), _kinetic_friction, _rolling_friction, _grass_viscosity, _critical_angle, speed_mult
		])


func get_target_dir() -> Vector3:
	if target_dir.length_squared() > 0.001:
		return target_dir
	return Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(aim_yaw_offset_deg)).normalized()


func get_target_right() -> Vector3:
	return get_target_dir().cross(Vector3.UP).normalized()


func get_downrange_meters() -> float:
	if shot_start_pos_global.is_zero_approx():
		return 0.0
	var delta: Vector3 = global_position - shot_start_pos_global
	var delta_h := Vector3(delta.x, 0.0, delta.z)
	return delta_h.dot(get_target_dir())


func get_downrange_yards() -> float:
	return get_downrange_meters() * 1.09361


func get_side_distance_meters() -> float:
	if shot_start_pos_global.is_zero_approx():
		return 0.0
	var delta: Vector3 = global_position - shot_start_pos_global
	var delta_h := Vector3(delta.x, 0.0, delta.z)
	return delta_h.dot(get_target_right())


func get_side_distance_yards() -> float:
	return get_side_distance_meters() * 1.09361


## Returns the height of the ball above the terrain/ground beneath it in meters.
func get_height_above_ground() -> float:
	var current_y: float = global_position.y if is_inside_tree() else position.y
	return maxf(0.0, current_y - _current_ground_y)


## Returns the atmospheric boundary layer wind factor (0.0 to 1.0) based on elevation.
## Near ground level (start/end of trajectory), wind has little to no effect.
## It increases smoothly up to 1.0 (the full listed amount) at peak heights (>= 25m).
func get_wind_factor() -> float:
	return smoothstep(0.0, WIND_PEAK_ALTITUDE_METERS, get_height_above_ground())


func _update_ground_elevation() -> void:
	if not is_inside_tree():
		return
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("get_height"):
		_current_ground_y = float(scene.call("get_height", global_position.x, global_position.z))
		return

	var world := get_world_3d()
	if world != null and world.direct_space_state != null:
		var ray_start := global_position + Vector3.UP * 1.0
		var ray_end := global_position + Vector3.DOWN * 500.0
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [get_rid()]
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_current_ground_y = float(hit["position"].y)
			return

	if not shot_start_pos_global.is_zero_approx():
		_current_ground_y = shot_start_pos_global.y



func _process(delta: float) -> void:
	if _ball_mesh != null:
		var base_y := get_visual_y_offset()
		var target_y := base_y
		var on_fairway_or_tee := (lie_type in ["fairway", "teebox", "fringe"] or surface_type in [PhysicsEnums.SurfaceType.FAIRWAY, PhysicsEnums.SurfaceType.FAIRWAY_SOFT] or (is_inside_tree() and _is_position_on_fringe(global_position)))
		var on_green_surface := false

		# Only sink into tall rough or bunker sand when the ball is at rest.
		# While rolling or in flight, roll cleanly on top of the surface without visual clipping.
		if state == PhysicsEnums.BallState.REST:
			if on_fairway_or_tee:
				target_y = base_y
			else:
				on_green_surface = (lie_type == "green" or surface_type == PhysicsEnums.SurfaceType.GREEN or is_putt or (is_inside_tree() and _is_position_on_green(global_position)))
				if on_green_surface:
					target_y = base_y
				elif is_in_sand or surface_type == PhysicsEnums.SurfaceType.BUNKER or lie_type == "sand":
					target_y = base_y - 0.017 # Sink 1.7 cm in sand traps
				elif lie_type == "rough" or surface_type == PhysicsEnums.SurfaceType.ROUGH:
					target_y = base_y - 0.014 # Sink 1.4 cm in tall rough
				else:
					target_y = base_y
		else:
			target_y = base_y

		if not is_equal_approx(_ball_mesh.position.y, target_y):
			# If cup rim dip is active (near hole lip) or ball is inside the cup, let the hole physics control the Y offset
			if not (is_falling_in_hole or holed_out_this_shot or (_ball_mesh.position.y < target_y and on_green_surface)):
				_ball_mesh.position.y = lerpf(_ball_mesh.position.y, target_y, delta * 15.0)


func _physics_process(delta: float) -> void:
	if is_replaying_remote_shot:
		return
	if state == PhysicsEnums.BallState.REST:
		return

	# Live proximity check for suspense (Course Play only)
	var target_hole_live = _cached_target_hole
	if target_hole_live.is_zero_approx():
		target_hole_live = _get_active_hole_position(global_position)
		_cached_target_hole = target_hole_live

	if has_node("/root/TensionManager") and not target_hole_live.is_zero_approx() and TensionManager.is_course_play_active():
		var start_p = shot_start_pos_global if not shot_start_pos_global.is_zero_approx() else (position if not position.is_zero_approx() else spawn_position)
		var is_airborne = (state == PhysicsEnums.BallState.FLIGHT)
		TensionManager.check_ball_proximity(global_position, target_hole_live, is_putt, start_p, shot_was_in_sand, is_airborne, velocity, hit_tree_this_shot, delta)

	# Check physical 3D hole cup and rim interaction
	if not is_falling_in_hole:
		var target_hole = _get_active_cup_position(global_position)

		if target_hole != null and not target_hole.is_zero_approx():
			var ball_pos = global_position
			var hole_diff_2d = Vector2(target_hole.x - ball_pos.x, target_hole.z - ball_pos.z)
			var dist_2d = hole_diff_2d.length()
			var vertical_diff = ball_pos.y - target_hole.y

			# Elevation check: ball must be near the green surface around the cup mouth
			if vertical_diff > -0.12 and vertical_diff < 0.25:
				var scene_cup_radius = _get_cup_radius()
				var rim_outer_radius = scene_cup_radius + CUP_BEVEL_WIDTH

				# Strictly zero inward pull outside the cut turf bevel (no artificial suction)
				if dist_2d <= rim_outer_radius:
					var speed_total = velocity.length()
					var vel_2d = Vector2(velocity.x, velocity.z)
					var speed_2d = vel_2d.length()
					var is_air_dunk = (not on_ground) and (not is_putt) and state == PhysicsEnums.BallState.FLIGHT and dist_2d < (scene_cup_radius - _ball_radius * 0.35) and vertical_diff <= (_ball_radius + 0.025) and velocity.y < -0.5 and speed_total < 5.0
					var is_ground_roll = not is_air_dunk

					var can_fall = false
					var s_along = 0.0
					var b_offset = dist_2d
					var dir_2d = Vector2.ZERO

					if speed_2d > 0.001:
						dir_2d = vel_2d / speed_2d
						s_along = hole_diff_2d.dot(dir_2d)
						var lat_vec = hole_diff_2d - dir_2d * s_along
						b_offset = lat_vec.length()

					# Physical critical capture speed calculation based on chord length and gravity drop
					var chord_length = 0.0
					if b_offset < scene_cup_radius:
						chord_length = 2.0 * sqrt(scene_cup_radius * scene_cup_radius - b_offset * b_offset)
					var chord_ratio = chord_length / (2.0 * scene_cup_radius)

					# Dave Pelz / Penner putting physics:
					# Max center-cup capture speed without flagstick is ~1.63 m/s (5.35 ft/s).
					# Off-center putts have reduced chord length, dropping capture speed proportionally.
					var v_crit_center = 1.63
					var is_flag_in = _is_flagstick_in_cup()
					if is_flag_in and b_offset <= (0.0065 + _ball_radius * 0.5):
						# Flagstick absorbs impact for direct pin hits
						v_crit_center = 2.25

					var max_capture_speed = v_crit_center * chord_ratio

					if is_air_dunk:
						can_fall = true
					elif is_ground_roll and dist_2d <= scene_cup_radius:
						# Ball center of mass is over the open cup mouth:
						# Ball falls in only if it is approaching/over center and moving slow enough to drop under gravity
						if (s_along >= -0.015 and speed_2d <= max_capture_speed) or speed_total < 0.25:
							can_fall = true

					if can_fall:
						is_falling_in_hole = true
						holed_out_this_shot = true
						falling_target_hole = target_hole
						falling_time = 0.0
						on_ground = false
						_cup_sound_played = false
						# Fold any current visual rim overhang dip into physical Y position seamlessly
						if _ball_mesh != null:
							var current_dip = get_visual_y_offset() - _ball_mesh.position.y
							if current_dip > 0.0:
								global_position.y -= current_dip
							_ball_mesh.position.y = get_visual_y_offset()
						# Preserve forward horizontal momentum on entry - no artificial brake or suction!
						# Downward gravity will naturally pull the ball into the cup.
					elif is_ground_roll and speed_2d > 0.001 and dist_2d > 0.0001:
						# Physical rim normal tilt (deflection / lip-out):
						# When the ball overhangs the circular lip, the contact normal exerts a LATERAL force
						# perpendicular to the ball's travel direction. This steers the ball slightly left/right
						# without creating artificial forward/backward suction toward the hole.
						var lat_vec = hole_diff_2d - dir_2d * s_along
						var lat_dist = lat_vec.length()
						var rim_overlap = clampf((rim_outer_radius - dist_2d) / (CUP_BEVEL_WIDTH + _ball_radius * 0.5), 0.0, 1.0)
						if lat_dist > 0.0005:
							var lat_dir = lat_vec / lat_dist
							# Perpendicular lateral acceleration curves fast grazing putts left or right
							var lateral_accel = 9.81 * rim_overlap * 0.40
							var lat_delta_v = lat_dir * (lateral_accel * delta)
							velocity.x += lat_delta_v.x
							velocity.z += lat_delta_v.y

						# Subtle turf edge rolling friction on the collar
						var drag_factor = 1.0 - clampf((0.6 * rim_overlap) * delta, 0.0, 0.05)
						velocity.x *= drag_factor
						velocity.z *= drag_factor
						if velocity.length_squared() > 0.0001 and _ball_radius > 0.0:
							omega = (floor_normal.cross(velocity)) / _ball_radius

						# Fast balls crossing over the opening hit the far lip and skip/hop forward
						if dist_2d < scene_cup_radius and s_along < 0.0 and dist_2d > (scene_cup_radius - 0.020):
							if velocity.y < 0.0:
								velocity.y = 0.18
								velocity.x *= 0.85
								velocity.z *= 0.85

						# Subtle geometric dip as the sphere overhangs the beveled rim
						if _ball_mesh != null:
							var dip_depth = clampf(rim_overlap * 0.008, 0.0, 0.008)
							_ball_mesh.position.y = get_visual_y_offset() - dip_depth
				else:
					# Restore mesh Y offset when rolling away from the rim
					if _ball_mesh != null and _ball_mesh.position.y < (get_visual_y_offset() - 0.001):
						_ball_mesh.position.y = lerpf(_ball_mesh.position.y, get_visual_y_offset(), delta * 15.0)
			else:
				if _ball_mesh != null and _ball_mesh.position.y < (get_visual_y_offset() - 0.001):
					_ball_mesh.position.y = lerpf(_ball_mesh.position.y, get_visual_y_offset(), delta * 15.0)

	if is_falling_in_hole:
		falling_time += delta
		var scene_cup_radius = _get_cup_radius()
		var cylinder_max_r = maxf(0.008, scene_cup_radius - _ball_radius)
		var cup_floor_y = falling_target_hole.y - CUP_DEPTH + _ball_radius

		# 1. Real downward gravity inside the recessed cup
		velocity.y -= 9.81 * delta
		global_position += velocity * delta

		# 2. Visual ball rotation from angular velocity while dropping & rattling in cup
		if _ball_mesh != null:
			_ball_mesh.position.y = get_visual_y_offset()
			var omega_len = omega.length()
			if omega_len > 0.001:
				_ball_mesh.rotate(omega / omega_len, omega_len * delta)

		# 3. Cylindrical inner cup wall & flagstick ferrule collision
		# When near the top opening, allow the ball center to enter smoothly across the rim without snapping!
		var offset_2d = Vector2(global_position.x - falling_target_hole.x, global_position.z - falling_target_hole.z)
		var r = offset_2d.length()
		var depth_below_rim = falling_target_hole.y - (global_position.y - _ball_radius)
		var rim_transition = clampf(depth_below_rim / maxf(0.001, _ball_radius * 1.5), 0.0, 1.0)
		var current_max_r = lerpf(scene_cup_radius, cylinder_max_r, rim_transition)

		if r > current_max_r:
			var wall_n = offset_2d / r
			global_position.x = falling_target_hole.x + wall_n.x * current_max_r
			global_position.z = falling_target_hole.z + wall_n.y * current_max_r
			var v_rad = velocity.x * wall_n.x + velocity.z * wall_n.y
			if v_rad > 0.0:
				var wall_restitution = 0.32
				velocity.x -= (1.0 + wall_restitution) * v_rad * wall_n.x
				velocity.z -= (1.0 + wall_restitution) * v_rad * wall_n.y
				velocity.x *= 0.82
				velocity.z *= 0.82
				omega *= 0.75
		elif _is_flagstick_in_cup():
			var pole_min_r = 0.0065 + _ball_radius
			if r < pole_min_r and pole_min_r < cylinder_max_r:
				var push_n = (offset_2d / r) if r > 0.0001 else Vector2(1.0, 0.0)
				global_position.x = falling_target_hole.x + push_n.x * pole_min_r
				global_position.z = falling_target_hole.z + push_n.y * pole_min_r
				var v_in = velocity.x * push_n.x + velocity.z * push_n.y
				if v_in < 0.0:
					velocity.x -= 1.25 * v_in * push_n.x
					velocity.z -= 1.25 * v_in * push_n.y
					velocity.x *= 0.75
					velocity.z *= 0.75

		# 4. Recessed cup bottom drain plate collision & bounce
		if global_position.y <= cup_floor_y:
			global_position.y = cup_floor_y
			if not _cup_sound_played:
				_cup_sound_played = true
				if _cup_player != null and not _skipping_flight:
					_cup_player.play()
			if velocity.y < -0.20:
				velocity.y = -velocity.y * 0.22
				velocity.x *= 0.65
				velocity.z *= 0.65
				omega *= 0.60
			else:
				velocity.y = 0.0
				velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
				omega = omega.move_toward(Vector3.ZERO, 15.0 * delta)

		# 5. Settle at rest at the bottom of the physical cup
		if (absf(global_position.y - cup_floor_y) <= 0.002 and velocity.length() < 0.05) or falling_time > 1.2:
			global_position.y = cup_floor_y
			var final_off = Vector2(global_position.x - falling_target_hole.x, global_position.z - falling_target_hole.z)
			if final_off.length() > cylinder_max_r:
				var clamped_off = final_off.normalized() * cylinder_max_r
				global_position.x = falling_target_hole.x + clamped_off.x
				global_position.z = falling_target_hole.z + clamped_off.y
			is_falling_in_hole = false
			on_ground = true
			_enter_rest_state()
		return

	if state == PhysicsEnums.BallState.FLIGHT:
		flight_time += delta
	else:
		flight_time = 0.0

	if on_ground or state != PhysicsEnums.BallState.FLIGHT:
		_surface_check_timer += delta
		if _surface_check_timer >= 0.10:
			_surface_check_timer = 0.0
			_update_surface_from_underneath()

	var was_on_ground := on_ground
	var prev_velocity := velocity

	if params != null and was_on_ground:
		_set_openfairway_property(params, &"floor_normal", &"FloorNormal", floor_normal)
		_set_openfairway_property(params, &"rollout_impact_spin", &"RolloutImpactSpin", rollout_impact_spin_rpm)
		_set_openfairway_property(params, &"kinetic_friction", &"KineticFriction", _kinetic_friction)
		_set_openfairway_property(params, &"rolling_friction", &"RollingFriction", _rolling_friction)
		_set_openfairway_property(params, &"grass_viscosity", &"GrassViscosity", _grass_viscosity)
		_set_openfairway_property(params, &"critical_angle", &"CriticalAngle", _critical_angle)
		_set_openfairway_property(params, &"surface_type", &"SurfaceType", surface_type)
		_set_openfairway_property(params, &"slope_force_scale", &"SlopeForceScale", slope_force_scale)
		_set_openfairway_property(params, &"is_in_sand", &"IsInSand", is_in_sand or surface_type == PhysicsEnums.SurfaceType.BUNKER)
		_set_openfairway_property(params, &"is_putt", &"IsPutt", is_putt)
		_set_openfairway_property(params, &"spinback_response_scale", &"SpinbackResponseScale", _spinback_response_scale)
		_set_openfairway_property(params, &"spinback_theta_boost_max", &"SpinbackThetaBoostMax", _spinback_theta_boost_max)
		_set_openfairway_property(params, &"spinback_spin_start_rpm", &"SpinbackSpinStartRpm", _spinback_spin_start_rpm)
		_set_openfairway_property(params, &"spinback_spin_end_rpm", &"SpinbackSpinEndRpm", _spinback_spin_end_rpm)
		_set_openfairway_property(params, &"spinback_speed_start_mps", &"SpinbackSpeedStartMps", _spinback_speed_start_mps)
		_set_openfairway_property(params, &"spinback_speed_end_mps", &"SpinbackSpeedEndMps", _spinback_speed_end_mps)

	# Calculate forces and torques using BallPhysics
	var total_force = _call_openfairway_method(_physics, &"calculate_forces", &"CalculateForces", [velocity, omega, was_on_ground, params])
	var total_torque = _call_openfairway_method(_physics, &"calculate_torques", &"CalculateTorques", [velocity, omega, was_on_ground, params])
	if total_force == null or total_torque == null:
		return

	# Update velocity and angular velocity
	velocity += (total_force / _ball_mass) * delta
	omega += (total_torque / _ball_moi) * delta

	# Apply wind aerodynamic forces during flight
	if (state == PhysicsEnums.BallState.FLIGHT or not was_on_ground):
		var gs = GlobalSettings if GlobalSettings != null else (get_node_or_null("/root/GlobalSettings") if is_inside_tree() else null)
		if gs != null and gs.is_wind_enabled():
			var wind_vec: Vector3 = gs.get_wind_vector_mps()
			if not wind_vec.is_zero_approx():
				_ground_elevation_timer += delta
				if _ground_elevation_timer >= 0.10:
					_ground_elevation_timer = 0.0
					_update_ground_elevation()

				# Altitude / elevation-based wind scaling:
				# Near ground level (start and end of trajectory), wind effect is ~0.0.
				# It increases smoothly up to 1.0 (the full listed amount) at peak heights (>= 25m).
				var wind_factor := get_wind_factor()
				var effective_wind := wind_vec * wind_factor
				if not effective_wind.is_zero_approx():
					var v_ball := velocity
					var v_rel := v_ball - effective_wind
					var v_ball_len := v_ball.length()
					var v_rel_len := v_rel.length()
					var cd := 0.28
					var rho := 1.204
					if params != null:
						rho = float(_get_openfairway_property(params, &"air_density", &"AirDensity", 1.204))
					var cross_area := 0.0014303 # PI * RADIUS^2
					var f_drag_wind: Vector3 = -0.5 * cd * rho * cross_area * v_rel_len * v_rel
					var f_drag_still: Vector3 = -0.5 * cd * rho * cross_area * v_ball_len * v_ball
					var wind_force: Vector3 = f_drag_wind - f_drag_still
					velocity += (wind_force / _ball_mass) * delta

	# Apply tree leaves reduction/damping (responsive check, 20 Hz)
	if state == PhysicsEnums.BallState.FLIGHT and _has_canopy_trees:
		_tree_check_timer += delta
		if _tree_check_timer >= TREE_CHECK_INTERVAL:
			_tree_check_timer = 0.0
			_check_tree_canopy()

		if _is_in_tree_canopy:
			_canopy_time += delta
			var damping_factor := lerpf(FOLIAGE_DAMPING_BASE, FOLIAGE_DAMPING_MAX, clampf(_canopy_time / FOLIAGE_RAMP_DURATION, 0.0, 1.0))
			velocity *= (1.0 - damping_factor * delta)
			omega *= (1.0 - damping_factor * delta)
			
			if _leaves_player and not _leaves_player.playing and not _skipping_flight:
				_leaves_player.play()
			
			if not _hit_leaves_this_shot:
				_hit_leaves_this_shot = true
				hit_tree_this_shot = true
				print("[ball.gd] Hitting tree leaves! Reducing velocity (initial damping=%.3f)." % damping_factor)
				if has_node("/root/TensionManager"):
					get_node("/root/TensionManager").on_tree_hit()
				if has_node("/root/AnnouncerEngine") and not _skipping_flight:
					get_node("/root/AnnouncerEngine").call("SpeakTreeHeckle", "leaves")
		else:
			_canopy_time = 0.0
			if _leaves_player and _leaves_player.playing:
				_leaves_player.stop()
	elif _leaves_player and _leaves_player.playing:
		_canopy_time = 0.0
		_leaves_player.stop()

	# Safety: catch NaN/infinity before it reaches the physics engine
	# Without this, ROUGH appears to error with FINITE bug. Do not remove until someone
	# better understands this. 
	if not velocity.is_finite() or not omega.is_finite():
		push_warning("BallPhysics: non-finite velocity or omega detected, entering rest")
		_enter_rest_state()
		return

	# Safety bounds check
	if _check_out_of_bounds():
		return

	# Move and handle collisions
	prev_physics_pos = global_position
	var collision := move_and_collide(velocity * delta, false, COLLISION_SAFE_MARGIN)
	_handle_collision(collision, was_on_ground, prev_velocity)
	curr_physics_pos = global_position
	_physics_pos_initialized = true

	# If on ground (rollout / putt / grounded), ensure ball spin matches physical forward roll along ground normal.
	# For putts, pure roll is immediate. For rollout after landing/bounce, allow kinetic sliding friction and torque
	# to spin up/down the ball naturally until slip velocity is small, preserving realistic turf deceleration.
	if on_ground and (state == PhysicsEnums.BallState.ROLLOUT or is_putt):
		if is_putt:
			if velocity.length_squared() > 0.0001:
				omega = (floor_normal.cross(velocity)) / _ball_radius
		else:
			var contact_vel := velocity + omega.cross(-floor_normal * _ball_radius)
			var tangent_slip := contact_vel - floor_normal * contact_vel.dot(floor_normal)
			if tangent_slip.length() < 0.15:
				if velocity.length_squared() > 0.0001:
					omega = (floor_normal.cross(velocity)) / _ball_radius
				rollout_impact_spin_rpm = 0.0

	# Rotate ball mesh based on angular velocity (omega)
	if _ball_mesh != null and omega.length_squared() > 0.00001:
		var axis = omega.normalized()
		if axis.is_normalized():
			var angle = omega.length() * delta
			_ball_mesh.global_rotate(axis, angle)

	# Check for rest
	if velocity.length() < 0.12 and state != PhysicsEnums.BallState.REST:
		var has_active_spin_slip := false
		if on_ground and not is_putt and not is_in_water and not is_falling_in_hole:
			var contact_vel := velocity + omega.cross(-floor_normal * _ball_radius)
			var tangent_slip := contact_vel - floor_normal * contact_vel.dot(floor_normal)
			has_active_spin_slip = tangent_slip.length() > 0.25 and (omega.length() * _ball_radius) > 0.20

		if not has_active_spin_slip and (on_ground or is_putt or is_in_water or is_falling_in_hole):
			_enter_rest_state()
		elif not on_ground:
			# Ball is airborne / in tree: don't rest in mid-air! Let gravity drop it.
			_airborne_low_speed_timer += delta
			if _airborne_low_speed_timer > 1.5:
				var g_y := _get_ground_y_at(global_position.x, global_position.z)
				global_position.y = g_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET
				velocity = Vector3.ZERO
				on_ground = true
				_enter_rest_state()
	elif not on_ground and velocity.length() < 0.5:
		# If trapped in tree foliage or collision seams at low speed, don't reset timer
		_airborne_low_speed_timer += delta
		if _airborne_low_speed_timer > 1.5:
			var g_y := _get_ground_y_at(global_position.x, global_position.z)
			global_position.y = g_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET
			velocity = Vector3.ZERO
			on_ground = true
			_enter_rest_state()
	else:
		_airborne_low_speed_timer = 0.0

	# Failsafe: prevent shots from rolling or hanging indefinitely
	_shot_duration += delta
	if _shot_duration > 25.0 or (_shot_duration > 15.0 and velocity.length() < 0.4 and on_ground):
		_enter_rest_state()


func _check_out_of_bounds() -> bool:
	if absf(position.x - shot_start_pos.x) > 3000.0 or absf(position.z - shot_start_pos.z) > 3000.0:
		print("WARNING: Ball out of bounds at: ", position)
		_enter_rest_state()
		return true

	var ground_y := _get_ground_y_at(global_position.x, global_position.z)
	if global_position.y < (ground_y - 2.0) or global_position.y < FALLTHROUGH_FAILSAFE_Y:
		if _try_recover_to_ground():
			return false
		if global_position.y < (ground_y - 2.0):
			print("WARNING: Ball fell through ground at: ", global_position, " (ground at: %.2f)" % ground_y)
			global_position.y = ground_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET
			velocity = Vector3.ZERO
			on_ground = true
			_enter_rest_state()
			return true

	return false


func _handle_collision(collision: KinematicCollision3D, was_on_ground: bool, prev_velocity: Vector3) -> void:
	if collision:
		var collider = collision.get_collider()
		var is_flagstick := _is_collider_flagstick(collider)
		if is_putt and is_flagstick:
			# Flagstick is pulled during putting: no collision
			var remainder := collision.get_remainder()
			if remainder.length_squared() > 0.000001:
				move_and_collide(remainder, false, COLLISION_SAFE_MARGIN)
			return

		var is_water_hit = collider != null and ((collider.has_meta("is_water") and bool(collider.get_meta("is_water"))) or collider.name.to_lower().contains("water"))
		if is_water_hit:
			is_in_water = true
			water_collider = collider
			velocity = Vector3.ZERO
			omega = Vector3.ZERO
			
			if _sfx_player != null and not _skipping_flight:
				_sfx_player.pitch_scale = randf_range(0.96, 1.04)
				_sfx_player.stream = _sfx_water_splash
				_sfx_player.play()
				
			_enter_rest_state()
			return

		var normal := collision.get_normal()
		var is_tree := _is_collider_tree(collider)
		var is_rock := _is_collider_rock(collider)
		var is_ground_norm := _is_ground_normal(normal) and not is_tree

		# Check for step-up / lip / mesh seam if rolling along ground (e.g. fringe-to-green collar or terrain seam)
		var is_rolling := was_on_ground or is_putt or state == PhysicsEnums.BallState.ROLLOUT
		if not is_ground_norm and is_rolling:
			if not is_tree and not is_flagstick and not is_rock:
				# Probe ahead across the edge to check if there is rollable ground on top of the step/lip
				var forward_dir := Vector3(prev_velocity.x, 0.0, prev_velocity.z).normalized()
				if forward_dir.is_zero_approx():
					forward_dir = -Vector3(normal.x, 0.0, normal.z).normalized()
				if not forward_dir.is_zero_approx():
					var probe_pos := collision.get_position() + forward_dir * 0.04
					var world := get_world_3d()
					if world != null:
						var step_query := PhysicsRayQueryParameters3D.create(probe_pos + Vector3.UP * 0.25, probe_pos + Vector3.DOWN * 0.35)
						step_query.collide_with_areas = false
						step_query.collide_with_bodies = true
						step_query.exclude = [get_rid()]
						var step_hit := world.direct_space_state.intersect_ray(step_query)
						if not step_hit.is_empty():
							var step_normal: Vector3 = step_hit["normal"]
							if _is_ground_normal(step_normal):
								var step_y: float = step_hit["position"].y
								var ball_bottom_y := global_position.y - _ball_radius
								var step_height := step_y - ball_bottom_y
								# Small step/lip up to 5cm or downward slope can be rolled over smoothly
								if step_height <= 0.050 and step_height >= -0.25:
									on_ground = true
									floor_normal = step_normal
									global_position.y = step_y + (_ball_radius + GROUND_SNAP_OFFSET) / maxf(step_normal.y, MIN_GROUND_NORMAL)
									global_position += forward_dir * 0.005
									var prev_speed := prev_velocity.length()
									velocity = _remove_velocity_along_normal(prev_velocity, floor_normal)
									if velocity.length_squared() > 0.0001 and prev_speed > 0.05:
										velocity = velocity.normalized() * maxf(velocity.length(), prev_speed * 0.95)
									if step_hit.has("collider") and step_hit["collider"] != null:
										_update_surface_from_collider(step_hit["collider"])
									var remainder := collision.get_remainder()
									remainder = _remove_velocity_along_normal(remainder, floor_normal)
									if remainder.length_squared() > 0.000001:
										move_and_collide(remainder, false, COLLISION_SAFE_MARGIN)
									return

		# If the collider is turf/terrain and not an obstacle, but normal is slightly steep (e.g. contour embankment or seam)
		if not is_ground_norm and not is_tree and not is_rock and not is_flagstick:
			var cname: String = String(collider.name).to_lower() if collider != null else ""
			var is_turf: bool = cname.contains("fairway") or cname.contains("green") or cname.contains("tee") or cname.contains("rough") or cname.contains("terrain") or (collider != null and collider.has_meta("surface_type"))
			if is_turf and normal.y > 0.25:
				is_ground_norm = true

		if is_ground_norm:
			floor_normal = normal
			var prev_normal_velocity := prev_velocity.dot(normal)
			if collider != null and _is_collider_tree(collider):
				hit_tree_this_shot = true
				if has_node("/root/TensionManager"):
					get_node("/root/TensionManager").on_tree_hit()

			# Ignore ground collision depenetration on launch/ascent while in FLIGHT state.
			# For low-speed chip/pitch shots off turf, fringe collars, or uphill lies,
			# allow ground depenetration during initial launch (first 0.25s or while ascending)
			# rather than prematurely killing vertical loft into a ground rollout.
			var is_launch_ascent := state == PhysicsEnums.BallState.FLIGHT and (
				flight_time < 0.25
				or velocity.y > 0.05
				or prev_velocity.y > 0.05
				or prev_normal_velocity >= -0.15
			)
			if is_launch_ascent and prev_normal_velocity > -3.5:
				on_ground = false
				global_position += normal * (COLLISION_SAFE_MARGIN * 2.0 + 0.004)
				var remainder := collision.get_remainder()
				if remainder.length_squared() > 0.000001:
					move_and_collide(remainder, false, COLLISION_SAFE_MARGIN)
				return

			# Track if ball hit other ground outside the tee box
			if shot_was_from_teebox:
				var hit_dist = global_position.distance_to(shot_start_pos_global)
				var cname = collider.name.to_lower() if collider != null else ""
				if hit_dist > 3.0:
					shot_hit_other_ground = true
				elif cname.contains("fairway") or cname.contains("green") or cname.contains("rough") or cname.contains("bunker") or cname.contains("sand"):
					shot_hit_other_ground = true
				elif not cname.contains("tee") and hit_dist > 1.5:
					shot_hit_other_ground = true
			else:
				shot_hit_other_ground = true

			var is_landing := (state == PhysicsEnums.BallState.FLIGHT) or prev_normal_velocity < -0.5

			if is_landing:
				if collider != null:
					_update_surface_from_collider(collider)
					
				# Sync updated friction parameters to C# params before calculating bounce
				if params != null:
					_set_openfairway_property(params, &"kinetic_friction", &"KineticFriction", _kinetic_friction)
					_set_openfairway_property(params, &"rolling_friction", &"RollingFriction", _rolling_friction)
					_set_openfairway_property(params, &"grass_viscosity", &"GrassViscosity", _grass_viscosity)
					_set_openfairway_property(params, &"critical_angle", &"CriticalAngle", _critical_angle)
					_set_openfairway_property(params, &"surface_type", &"SurfaceType", surface_type)
					_set_openfairway_property(params, &"is_in_sand", &"IsInSand", is_in_sand or surface_type == PhysicsEnums.SurfaceType.BUNKER)
					_set_openfairway_property(params, &"spinback_response_scale", &"SpinbackResponseScale", _spinback_response_scale)
					_set_openfairway_property(params, &"spinback_theta_boost_max", &"SpinbackThetaBoostMax", _spinback_theta_boost_max)
					_set_openfairway_property(params, &"spinback_spin_start_rpm", &"SpinbackSpinStartRpm", _spinback_spin_start_rpm)
					_set_openfairway_property(params, &"spinback_spin_end_rpm", &"SpinbackSpinEndRpm", _spinback_spin_end_rpm)
					_set_openfairway_property(params, &"spinback_speed_start_mps", &"SpinbackSpeedStartMps", _spinback_speed_start_mps)
					_set_openfairway_property(params, &"spinback_speed_end_mps", &"SpinbackSpeedEndMps", _spinback_speed_end_mps)

				if state == PhysicsEnums.BallState.FLIGHT:
					_print_impact_debug()
					rollout_impact_spin_rpm = omega.length() / 0.10472

				if _sfx_player != null and not _skipping_flight:
					_sfx_player.pitch_scale = randf_range(0.95, 1.05)
					if is_on_cart_path_or_road or surface_type == PhysicsEnums.SurfaceType.CART_PATH:
						_sfx_player.stream = _sfx_bounce_cart_path
					elif is_in_sand:
						_sfx_player.stream = _sfx_sand_thud
					elif lie_type == "green":
						_sfx_player.stream = _sfx_bounce_green
					elif lie_type == "fairway":
						_sfx_player.stream = _sfx_bounce_fairway
					elif lie_type == "rough":
						_sfx_player.stream = _sfx_rough_thump
					else:
						_sfx_player.stream = _sfx_bounce_fairway
					_sfx_player.play()

				var bounce_result = _call_openfairway_method(_physics, &"calculate_bounce", &"CalculateBounce", [velocity, omega, normal, state, params])
				if bounce_result == null:
					return
				velocity = _get_openfairway_property(bounce_result, &"new_velocity", &"NewVelocity", velocity)
				omega = _get_openfairway_property(bounce_result, &"new_omega", &"NewOmega", omega)
				state = int(_get_openfairway_property(bounce_result, &"new_state", &"NewState", state))

				var is_sand_surface = is_in_sand or (surface_type == PhysicsEnums.SurfaceType.BUNKER)
				if is_sand_surface:
					# Sand heavily deadens bounce height into a muffled pop (max normal vel 0.6 m/s)
					var normal_comp := velocity.dot(normal)
					if normal_comp > 0.6:
						velocity = velocity - (normal_comp - 0.6) * normal
					# Sand absorbs tangential momentum and immediately scrubs spin
					var tangent_vel := velocity - normal * velocity.dot(normal)
					if tangent_vel.length() > prev_velocity.length() * 0.25:
						velocity = (velocity.dot(normal) * normal) + (tangent_vel.normalized() * (prev_velocity.length() * 0.20))
					omega *= 0.15
				else:
					# Slightly scale the height of the bounce (normal component of velocity) based on green speed
					var green_speed : float = float(GlobalSettings.get_effective_green_speed())
					var bounce_sensitivity : float = 0.0025
					var bounce_mult : float = 1.0 + (green_speed - 10.0) * bounce_sensitivity
					var bounce_normal_vel := velocity.dot(normal)
					if bounce_normal_vel > 0.0:
						velocity = velocity - bounce_normal_vel * normal + (bounce_normal_vel * bounce_mult) * normal

					# In rain, wet turf dampens bounce height and tangential skip
					if RainPhysics.is_rain_active():
						var b_norm := velocity.dot(normal)
						var b_tang := velocity - (normal * b_norm)
						velocity = (normal * b_norm * RainPhysics.RAIN_BOUNCE_RETENTION) + (b_tang * RainPhysics.RAIN_BOUNCE_RETENTION)

					# Ball type bounce retention (Soft dampens bounce/rollout, Distance livens bounce/rollout)
					if not is_putt and absf(_ball_type_bounce_retention - 1.0) > 0.0001:
						var bt_norm := velocity.dot(normal)
						var bt_tang := velocity - (normal * bt_norm)
						velocity = (normal * bt_norm * _ball_type_bounce_retention) + (bt_tang * _ball_type_bounce_retention)

				print("  Velocity after bounce: ", velocity, " (%.2f m/s)" % velocity.length())
				var normal_velocity := velocity.dot(normal)
				var grounding_threshold := 1.2 if is_sand_surface else 0.5
				if absf(normal_velocity) < grounding_threshold and state == PhysicsEnums.BallState.ROLLOUT:
					on_ground = true
					velocity = _remove_velocity_along_normal(velocity, normal)
					print("  -> Ball grounded, continuing roll at %.2f m/s" % velocity.length())
				else:
					on_ground = false

				# If ball rollout is disabled by player in practice, immediately rest the ball at landing spot
				var rollout_active := true
				if Engine.has_singleton("GlobalSettings"):
					var gs = Engine.get_singleton("GlobalSettings")
					if gs.get("range_settings") != null and gs.range_settings.get("ball_rollout_enabled") != null:
						rollout_active = bool(gs.range_settings.ball_rollout_enabled.value)
				elif is_instance_valid(Engine.get_main_loop()):
					var root = Engine.get_main_loop().get("root") if Engine.get_main_loop().has_method("get") else null
					if root != null and root.has_node("GlobalSettings"):
						var gs = root.get_node("GlobalSettings")
						if gs.get("range_settings") != null and gs.range_settings.get("ball_rollout_enabled") != null:
							rollout_active = bool(gs.range_settings.ball_rollout_enabled.value)

				if not rollout_active and not is_putt:
					on_ground = true
					velocity = Vector3.ZERO
					omega = Vector3.ZERO
					var contact_pos := collision.get_position()
					var nys := maxf(normal.y, MIN_GROUND_NORMAL)
					global_position.y = contact_pos.y + (_ball_radius + GROUND_SNAP_OFFSET) / nys
					_enter_rest_state()
					return
			else:
				# Rolling / putting contact on ground
				on_ground = true
				if collider != null:
					_update_surface_from_collider(collider)
				var prev_speed := velocity.length()
				velocity = _remove_velocity_along_normal(velocity, normal)
				# Only protect against acute internal mesh seam micro-catches (e.g. nearly stopping on flat ground or slope seams)
				# without artificially boosting momentum when rolling uphill into normal slope contours.
				if was_on_ground and prev_speed > 0.3 and velocity.length() < 0.08 and normal.y > 0.70:
					if velocity.length_squared() > 0.0001:
						velocity = velocity.normalized() * (prev_speed * 0.92)
				# Snap ball Y to correct sphere-on-slope height at the collision point
				# instead of pushing along normal (which accumulates lift over frames)
				var contact_pos := collision.get_position()
				var nys := maxf(normal.y, MIN_GROUND_NORMAL)
				global_position.y = contact_pos.y + (_ball_radius + GROUND_SNAP_OFFSET) / nys
				# Continue motion along the slope tangent for the remainder of this frame
				var remainder := collision.get_remainder()
				remainder = _remove_velocity_along_normal(remainder, normal)
				if remainder.length_squared() > 0.000001:
					var col2 := move_and_collide(remainder, false, COLLISION_SAFE_MARGIN)
					if col2:
						var norm2 := col2.get_normal()
						if _is_ground_normal(norm2):
							floor_normal = norm2
							if col2.get_collider() != null:
								_update_surface_from_collider(col2.get_collider())
							var p_spd2 := velocity.length()
							velocity = _remove_velocity_along_normal(velocity, norm2)
							if was_on_ground and p_spd2 > 0.3 and velocity.length() < 0.08 and norm2.y > 0.70:
								if velocity.length_squared() > 0.0001:
									velocity = velocity.normalized() * (p_spd2 * 0.92)
							global_position.y = col2.get_position().y + (_ball_radius + GROUND_SNAP_OFFSET) / maxf(norm2.y, MIN_GROUND_NORMAL)
				# Ensure ball Y matches the ground height at the ball's final position after remainder
				if on_ground:
					var end_probe := _try_probe_ground()
					if bool(end_probe.get("hit", false)):
						var end_hit: Vector3 = end_probe.get("position", Vector3.ZERO)
						var end_norm: Vector3 = end_probe.get("normal", floor_normal)
						var end_nys := maxf(end_norm.y, MIN_GROUND_NORMAL)
						var end_y := end_hit.y + (_ball_radius + GROUND_SNAP_OFFSET) / end_nys
						global_position.y = maxf(global_position.y, end_y)
		else:
			# Wall collision - damped reflection
			on_ground = false
			floor_normal = Vector3.UP
			if is_tree:
				if _sfx_player != null and not _skipping_flight:
					_sfx_player.pitch_scale = randf_range(0.95, 1.05)
					_sfx_player.stream = _sfx_tree_hit
					_sfx_player.play()
				hit_tree_this_shot = true
				if not _hit_trunk_this_shot:
					_hit_trunk_this_shot = true
					if has_node("/root/AnnouncerEngine") and not _skipping_flight:
						get_node("/root/AnnouncerEngine").call("SpeakTreeHeckle", "trunk")
				if has_node("/root/TensionManager"):
					get_node("/root/TensionManager").on_tree_hit()
				# Damped reflection off tree trunk
				velocity = velocity.bounce(normal) * 0.45
				# If hit near top rim of trunk cylinder, deflect horizontally outward away from trunk axis
				if normal.y > 0.4:
					var horiz_out := Vector3(normal.x, 0.0, normal.z)
					if horiz_out.is_zero_approx():
						horiz_out = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
					else:
						horiz_out = horiz_out.normalized()
					velocity = Vector3(horiz_out.x * maxf(absf(velocity.x), 2.5), maxf(velocity.y, 0.5), horiz_out.z * maxf(absf(velocity.z), 2.5))
				omega = omega * 0.5
				state = PhysicsEnums.BallState.FLIGHT
				# Depenetrate ball slightly away from tree surface so it doesn't get stuck in collider
				global_position += normal * (COLLISION_SAFE_MARGIN * 2.0 + 0.008)
				var remainder := collision.get_remainder()
				var bounced_remainder := remainder.bounce(normal) * 0.45
				if bounced_remainder.length_squared() > 0.000001:
					move_and_collide(bounced_remainder, false, COLLISION_SAFE_MARGIN)
			elif is_flagstick:
				if _cup_player != null and not _skipping_flight:
					_cup_player.pitch_scale = randf_range(1.18, 1.30)
					_cup_player.play()
				print("[ball.gd] Ball struck the flagstick pin! Damped bounce.")
				velocity = velocity.bounce(normal) * 0.35
				omega = omega * 0.5
				global_position += normal * (COLLISION_SAFE_MARGIN * 2.0 + 0.008)
				var remainder := collision.get_remainder()
				var bounced_remainder := remainder.bounce(normal) * 0.35
				if bounced_remainder.length_squared() > 0.000001:
					move_and_collide(bounced_remainder, false, COLLISION_SAFE_MARGIN)
			else:
				# Damped reflection off vertical surfaces (walls, barriers, rocks, etc.)
				velocity = velocity.bounce(normal) * 0.35
				omega = omega * 0.5
				global_position += normal * (COLLISION_SAFE_MARGIN * 2.0 + 0.008)
				var remainder := collision.get_remainder()
				var bounced_remainder := remainder.bounce(normal) * 0.35
				if bounced_remainder.length_squared() > 0.000001:
					move_and_collide(bounced_remainder, false, COLLISION_SAFE_MARGIN)
	else:
		# No collision - only stay grounded if terrain is still directly beneath the ball.
		if state != PhysicsEnums.BallState.FLIGHT and was_on_ground:
			var probe := _try_probe_ground()
			if bool(probe.get("hit", false)):
				on_ground = true
				floor_normal = probe.get("normal", Vector3.UP)
				# Compute correct sphere center Y for a sphere resting on a slope.
				# The raycast fires vertically, so hit_pos is the vertical intersection.
				# For a sphere of radius R on a surface with normal N, the center is at:
				#   Y = hit_y + R / N.y  (geometrically: R / cos(slope_angle))
				# This prevents floating on uphills and clipping on downhills.
				var hit_pos: Vector3 = probe.get("position", Vector3.ZERO)
				var normal_y_safe := maxf(floor_normal.y, MIN_GROUND_NORMAL)
				var correct_y := hit_pos.y + (_ball_radius + GROUND_SNAP_OFFSET) / normal_y_safe
				global_position.x = global_position.x  # preserve horizontal motion from move_and_collide
				global_position.z = global_position.z
				global_position.y = correct_y
				# Align velocity with the slope tangent
				velocity = _remove_velocity_along_normal(velocity, floor_normal)
				if probe.get("collider", null) != null:
					_update_surface_from_collider(probe["collider"])
			else:
				on_ground = false
				floor_normal = Vector3.UP
		else:
			on_ground = false
			floor_normal = Vector3.UP


func _try_recover_to_ground() -> bool:
	var world := get_world_3d()
	if world == null:
		return false

	var ray_start := global_position + Vector3.UP * GROUND_RAYCAST_UP
	var ray_end := global_position + Vector3.DOWN * GROUND_RAYCAST_DOWN
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excludes: Array[RID] = [get_rid()]
	query.exclude = excludes

	for attempt in range(5):
		var ray_hit := world.direct_space_state.intersect_ray(query)
		if ray_hit.is_empty():
			return false

		var col = ray_hit.get("collider")
		if col != null and (_is_collider_tree(col) or _is_collider_rock(col)):
			excludes.append(col.get_rid())
			query.exclude = excludes
			continue

		var hit_position: Vector3 = ray_hit["position"]
		if hit_position.y <= global_position.y - _ball_radius:
			return false
		var hit_normal: Vector3 = ray_hit["normal"]
		if hit_normal.length_squared() < 0.000001:
			hit_normal = Vector3.UP
		else:
			hit_normal = hit_normal.normalized()

		var nys := maxf(hit_normal.y, MIN_GROUND_NORMAL)
		global_position = Vector3(hit_position.x, hit_position.y + (_ball_radius + GROUND_SNAP_OFFSET) / nys, hit_position.z)
		floor_normal = hit_normal
		velocity = _remove_velocity_along_normal(velocity, hit_normal)
		on_ground = true

		if state == PhysicsEnums.BallState.FLIGHT:
			state = PhysicsEnums.BallState.ROLLOUT

		print("Recovered ball-to-ground at %s (normal: %s)" % [str(global_position), str(hit_normal)])
		return true

	return false


func _try_probe_ground() -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {"hit": false, "normal": Vector3.UP}

	var ray_start := global_position + Vector3.UP * 1.5
	var ray_end := global_position + Vector3.DOWN * 4.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excludes: Array[RID] = [get_rid()]
	query.exclude = excludes

	for attempt in range(5):
		var ray_hit := world.direct_space_state.intersect_ray(query)
		if ray_hit.is_empty():
			return {"hit": false, "normal": Vector3.UP}

		var col = ray_hit.get("collider")
		if col != null and (_is_collider_tree(col) or _is_collider_rock(col)):
			excludes.append(col.get_rid())
			query.exclude = excludes
			continue

		var ground_normal: Vector3 = ray_hit["normal"]
		if ground_normal.length_squared() < 0.000001:
			ground_normal = Vector3.UP
		else:
			ground_normal = ground_normal.normalized()
		return {
			"hit": true,
			"normal": ground_normal,
			"position": ray_hit["position"],
			"collider": col
		}

	return {"hit": false, "normal": Vector3.UP}


static func is_ground_normal(normal: Vector3) -> bool:
	return normal.y > MIN_GROUND_NORMAL


func _is_ground_normal(normal: Vector3) -> bool:
	return is_ground_normal(normal)


## Adjusts launch velocity and spin for golfer stance matching the terrain slope.
## Decomposes the shot from the flat horizontal frame and reprojects it onto
## the orthonormal stance frame matching the hill's slope surface and normal.
## Returns Dictionary { "velocity": Vector3, "omega": Vector3, "shot_direction": Vector3 }
static func calculate_slope_adjusted_launch(
	flat_velocity: Vector3,
	flat_omega: Vector3,
	aim_fwd_flat: Vector3,
	slope_normal: Vector3
) -> Dictionary:
	if not is_ground_normal(slope_normal) or slope_normal.distance_squared_to(Vector3.UP) <= 0.0001:
		var flat_dir := Vector3(flat_velocity.x, 0.0, flat_velocity.z)
		var s_dir := flat_dir.normalized() if flat_dir.length_squared() > 0.0001 else aim_fwd_flat
		return {
			"velocity": flat_velocity,
			"omega": flat_omega,
			"shot_direction": s_dir
		}

	# Horizontal reference frame (line of play along flat ground)
	var f_flat := Vector3(aim_fwd_flat.x, 0.0, aim_fwd_flat.z).normalized()
	if f_flat.is_zero_approx():
		f_flat = Vector3.RIGHT
	var u_flat := Vector3.UP
	var r_flat := f_flat.cross(u_flat).normalized()

	# Slope reference frame (golfer stance matching the terrain slope)
	var u_slope := slope_normal.normalized()
	var f_proj := f_flat - u_slope * f_flat.dot(u_slope)
	var f_slope := f_proj.normalized() if f_proj.length_squared() > 0.0001 else f_flat
	var r_slope := f_slope.cross(u_slope).normalized()

	# Rotate launch velocity from flat frame into slope stance frame
	var v_f := flat_velocity.dot(f_flat)
	var v_u := flat_velocity.dot(u_flat)
	var v_r := flat_velocity.dot(r_flat)
	var adj_velocity := v_f * f_slope + v_u * u_slope + v_r * r_slope

	# Rotate launch angular velocity (spin) to match stance orientation
	var w_f := flat_omega.dot(f_flat)
	var w_u := flat_omega.dot(u_flat)
	var w_r := flat_omega.dot(r_flat)
	var adj_omega := w_f * f_slope + w_u * u_slope + w_r * r_slope

	var flat_adj := Vector3(adj_velocity.x, 0.0, adj_velocity.z)
	var adj_dir := flat_adj.normalized() if flat_adj.length_squared() > 0.0001 else f_flat

	return {
		"velocity": adj_velocity,
		"omega": adj_omega,
		"shot_direction": adj_dir
	}


func _remove_velocity_along_normal(source_velocity: Vector3, normal: Vector3) -> Vector3:
	var normal_component : Vector3= source_velocity.dot(normal)*normal
	return source_velocity - normal_component


func _print_impact_debug() -> void:
	print("FIRST IMPACT at pos: ", position, ", downrange: %.2f yds" % get_downrange_yards())
	print("  Velocity at impact: ", velocity, " (%.2f m/s)" % velocity.length())
	print("  Spin at impact: ", omega, " (%.0f rpm)" % (omega.length() / 0.10472))
	print("  Normal: ", floor_normal)


func _get_cup_radius() -> float:
	var player_parent = get_parent()
	if player_parent != null:
		var parent_scene = player_parent.get_parent()
		if parent_scene != null and "cup_radius" in parent_scene:
			var r: float = float(parent_scene.cup_radius)
			if r > 0.01:
				return r
	return 0.054


func get_target_hole_position() -> Vector3:
	return _get_active_hole_position(global_position)


func _get_active_hole_position(ball_pos: Vector3 = Vector3.ZERO) -> Vector3:
	var player_parent = get_parent()
	if player_parent == null:
		return Vector3.ZERO
	var parent_scene = player_parent.get_parent()
	if parent_scene == null:
		return Vector3.ZERO

	# Driving range has no golf holes
	if ("is_driving_range" in parent_scene and bool(parent_scene.get("is_driving_range"))) or (parent_scene.has_meta("is_driving_range") and bool(parent_scene.get_meta("is_driving_range"))):
		return Vector3.ZERO

	# 1. Single-hole course play position
	if "current_hole_location" in parent_scene and not parent_scene.current_hole_location.is_zero_approx():
		return parent_scene.current_hole_location

	# 2. Multi-hole greens (e.g. Putting Practice with 8 holes)
	if "holes" in parent_scene and not parent_scene.holes.is_empty():
		var holes_arr: Array = parent_scene.holes
		# If a ball position is provided, find the closest hole within reasonable range (15m)
		if not ball_pos.is_zero_approx() and holes_arr.size() > 1:
			var closest_hole: Vector3 = Vector3.ZERO
			var min_dist: float = 999999.0
			for h in holes_arr:
				if h is Vector3:
					var d = Vector2(ball_pos.x, ball_pos.z).distance_to(Vector2(h.x, h.z))
					if d < min_dist:
						min_dist = d
						closest_hole = h
			if min_dist < 15.0:
				return closest_hole

		if "selected_hole_index" in parent_scene and parent_scene.selected_hole_index >= 0 and parent_scene.selected_hole_index < holes_arr.size():
			return holes_arr[parent_scene.selected_hole_index]
		return holes_arr[0]

	# 3. Island positions (Chipping minigame)
	if "island_positions" in parent_scene and "selected_island_index" in parent_scene and not parent_scene.island_positions.is_empty():
		var islands_arr: Array = parent_scene.island_positions
		var idx: int = parent_scene.selected_island_index
		if idx >= 0 and idx < islands_arr.size():
			return islands_arr[idx]
		return islands_arr[0]

	return Vector3.ZERO


func _get_active_cup_position(ball_pos: Vector3 = Vector3.ZERO) -> Vector3:
	var player_parent = get_parent()
	if player_parent == null:
		return Vector3.ZERO
	var parent_scene = player_parent.get_parent()
	if parent_scene == null:
		return Vector3.ZERO

	if ("is_driving_range" in parent_scene and bool(parent_scene.get("is_driving_range"))) or (parent_scene.has_meta("is_driving_range") and bool(parent_scene.get_meta("is_driving_range"))):
		return Vector3.ZERO

	# 1. Single-hole course play position
	if "current_hole_location" in parent_scene and not parent_scene.current_hole_location.is_zero_approx():
		return parent_scene.current_hole_location

	# 2. Multi-hole greens (e.g. Putting Practice with 8 recessed holes)
	if "holes" in parent_scene and not parent_scene.holes.is_empty():
		var holes_arr: Array = parent_scene.holes
		if not ball_pos.is_zero_approx() and holes_arr.size() > 1:
			var closest_hole: Vector3 = Vector3.ZERO
			var min_dist: float = 999999.0
			for h in holes_arr:
				if h is Vector3:
					var d = Vector2(ball_pos.x, ball_pos.z).distance_to(Vector2(h.x, h.z))
					if d < min_dist:
						min_dist = d
						closest_hole = h
			if min_dist < 15.0:
				return closest_hole

		if "selected_hole_index" in parent_scene and parent_scene.selected_hole_index >= 0 and parent_scene.selected_hole_index < holes_arr.size():
			return holes_arr[parent_scene.selected_hole_index]
		return holes_arr[0]

	return Vector3.ZERO


func _is_flagstick_in_cup() -> bool:
	var player_parent = get_parent()
	if player_parent == null:
		return false
	var parent_scene = player_parent.get_parent()
	if parent_scene == null:
		return false
	var col = parent_scene.get_node_or_null("FlagPin/FlagstickCollider/CollisionShape") as CollisionShape3D
	if col != null:
		return not col.disabled
	return false


func _enter_rest_state() -> void:
	if is_replaying_remote_shot:
		return
	if has_node("/root/TensionManager"):
		TensionManager.stop_tension()
	state = PhysicsEnums.BallState.REST
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	_is_in_tree_canopy = false
	_canopy_time = 0.0
	_airborne_low_speed_timer = 0.0
	_shot_duration = 0.0
	if _leaves_player and _leaves_player.playing:
		_leaves_player.stop()
	if not is_in_water and not is_falling_in_hole and not holed_out_this_shot:
		# If the ball ended up elevated in a tree or off the ground, drop to ground level
		var true_ground_y := _get_ground_y_at(global_position.x, global_position.z)
		if global_position.y > (true_ground_y + 0.35) or not on_ground:
			global_position.y = true_ground_y + GROUND_CENTER_HEIGHT + GROUND_SNAP_OFFSET
			on_ground = true
			floor_normal = Vector3.UP
		ensure_tree_clearance()
		ensure_rock_clearance()
		var rest_probe := _try_probe_ground()
		if bool(rest_probe.get("hit", false)):
			var r_hit: Vector3 = rest_probe.get("position", Vector3.ZERO)
			var r_norm: Vector3 = rest_probe.get("normal", floor_normal)
			if is_ground_normal(r_norm):
				floor_normal = r_norm.normalized()
			var r_nys := maxf(floor_normal.y, MIN_GROUND_NORMAL)
			var r_target_y := r_hit.y + (_ball_radius + GROUND_SNAP_OFFSET) / r_nys
			global_position.y = r_target_y
			on_ground = true
	_orient_ball_to_aim()
	emit_signal("rest")


func reset() -> void:
	if has_node("/root/TensionManager"):
		TensionManager.reset_for_new_shot()
	global_position = spawn_position
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	aim_yaw_offset_deg = 0.0
	launch_spin_rpm = 0.0
	rollout_impact_spin_rpm = 0.0
	is_putt = false
	shot_start_pos = spawn_position
	shot_start_pos_global = spawn_position
	_current_ground_y = spawn_position.y
	_ground_elevation_timer = 0.0
	target_dir = Vector3.RIGHT
	shot_was_in_sand = false
	shot_was_from_teebox = false
	shot_hit_other_ground = false
	_is_in_tree_canopy = false
	_tree_check_timer = 0.0
	_canopy_time = 0.0
	_surface_check_timer = 0.0
	_airborne_low_speed_timer = 0.0
	_shot_duration = 0.0
	if _leaves_player and _leaves_player.playing:
		_leaves_player.stop()
	_cached_target_hole = get_target_hole_position()
	_surface_zone_stack.clear()
	if lie_type == "teebox" or lie_type == "fairway" or lie_type == "fringe":
		set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
	elif lie_type == "rough":
		set_surface(PhysicsEnums.SurfaceType.ROUGH)
	elif lie_type == "sand":
		set_surface(PhysicsEnums.SurfaceType.BUNKER)
		is_in_sand = true
	elif lie_type == "green":
		set_surface(PhysicsEnums.SurfaceType.GREEN)
	else:
		set_surface(int(GlobalSettings.range_settings.surface_type.value))
	state = PhysicsEnums.BallState.REST
	on_ground = false
	is_in_water = false
	if lie_type != "sand":
		is_in_sand = false
	water_collider = null
	is_falling_in_hole = false
	falling_target_hole = Vector3.ZERO
	falling_time = 0.0
	holed_out_this_shot = false
	_cup_sound_played = false
	if _ball_mesh != null:
		var init_y := get_visual_y_offset()
		if lie_type == "sand" or is_in_sand:
			init_y -= 0.017
		elif lie_type == "rough":
			init_y -= 0.014
		_ball_mesh.position.y = init_y
	prev_physics_pos = global_position
	curr_physics_pos = global_position
	_physics_pos_initialized = true
	_update_tee_elevation()


func get_interpolated_position() -> Vector3:
	if is_replaying_remote_shot or state == PhysicsEnums.BallState.REST or not _physics_pos_initialized:
		return global_position
	var fraction = Engine.get_physics_interpolation_fraction()
	return prev_physics_pos.lerp(curr_physics_pos, fraction)


var _cached_is_pos_on_wrong_green_pos: Vector3 = Vector3.INF
var _cached_is_pos_on_wrong_green_res: bool = false

func _is_position_on_wrong_green(pos: Vector3) -> bool:
	if pos.is_equal_approx(_cached_is_pos_on_wrong_green_pos):
		return _cached_is_pos_on_wrong_green_res
	_cached_is_pos_on_wrong_green_pos = pos
	_cached_is_pos_on_wrong_green_res = _calc_is_position_on_wrong_green(pos)
	return _cached_is_pos_on_wrong_green_res

func _calc_is_position_on_wrong_green(pos: Vector3) -> bool:
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null or not course.has_method("is_ball_on_wrong_green"):
		var root = get_tree().current_scene if (is_inside_tree() and get_tree() != null) else null
		if root != null:
			course = root
	if course != null and course.has_method("is_ball_on_wrong_green"):
		return bool(course.call("is_ball_on_wrong_green", pos))
	return false


var _cached_is_pos_on_green_pos: Vector3 = Vector3.INF
var _cached_is_pos_on_green_res: bool = false

func _is_position_on_green(pos: Vector3) -> bool:
	if pos.is_equal_approx(_cached_is_pos_on_green_pos):
		return _cached_is_pos_on_green_res
	_cached_is_pos_on_green_pos = pos
	_cached_is_pos_on_green_res = _calc_is_position_on_green(pos)
	return _cached_is_pos_on_green_res

func _calc_is_position_on_green(pos: Vector3) -> bool:
	if _is_position_on_wrong_green(pos):
		return false
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null or not (course.has_method("get_distance_to_nearest_green") or course.has_method("is_inside_green") or course.has_method("get_distance_to_current_green")):
		var root = get_tree().current_scene if (is_inside_tree() and get_tree() != null) else null
		if root != null:
			course = root
	if course != null:
		if course.name == "PuttingPractice" or (course.scene_file_path != "" and course.scene_file_path.containsn("putting")):
			if course.has_method("is_inside_green"):
				return course.call("is_inside_green", pos.x, pos.z)
			return true
		if course.has_method("get_distance_to_current_green"):
			var d: float = course.get_distance_to_current_green(pos)
			if d <= 0.05:
				return true
			return false
		if course.has_method("get_distance_to_nearest_green"):
			var d: float = course.get_distance_to_nearest_green(pos)
			if d <= 0.05:
				return true
	return false

var _cached_is_pos_on_fairway_pos: Vector3 = Vector3.INF
var _cached_is_pos_on_fairway_res: bool = false

func _is_position_on_fairway(pos: Vector3) -> bool:
	if pos.is_equal_approx(_cached_is_pos_on_fairway_pos):
		return _cached_is_pos_on_fairway_res
	_cached_is_pos_on_fairway_pos = pos
	_cached_is_pos_on_fairway_res = _calc_is_position_on_fairway(pos)
	return _cached_is_pos_on_fairway_res

func _calc_is_position_on_fairway(pos: Vector3) -> bool:
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null or not course.has_method("is_point_in_fairway"):
		var root = get_tree().current_scene if (is_inside_tree() and get_tree() != null) else null
		if root != null and root.has_method("is_point_in_fairway"):
			course = root
	if course != null and course.has_method("is_point_in_fairway"):
		return bool(course.call("is_point_in_fairway", Vector2(pos.x, pos.z)))
	return false


func _has_course_green_geometry() -> bool:
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null or not (course.has_method("get_distance_to_nearest_green") or course.has_method("is_inside_green") or course.has_method("get_distance_to_current_green")):
		var root = get_tree().current_scene if (is_inside_tree() and get_tree() != null) else null
		if root != null:
			course = root
	if course != null:
		return course.has_method("get_distance_to_nearest_green") or course.has_method("is_inside_green") or course.has_method("get_distance_to_current_green")
	return false


var _cached_is_pos_on_fringe_pos: Vector3 = Vector3.INF
var _cached_is_pos_on_fringe_res: bool = false

func _is_position_on_fringe(pos: Vector3) -> bool:
	if pos.is_equal_approx(_cached_is_pos_on_fringe_pos):
		return _cached_is_pos_on_fringe_res
	_cached_is_pos_on_fringe_pos = pos
	_cached_is_pos_on_fringe_res = _calc_is_position_on_fringe(pos)
	return _cached_is_pos_on_fringe_res

func _calc_is_position_on_fringe(pos: Vector3) -> bool:
	if _is_position_on_wrong_green(pos):
		return false
	var course = null
	var player_parent = get_parent()
	if player_parent != null:
		course = player_parent.get_parent()
	if course == null or not (course.has_method("get_distance_to_nearest_green") or course.has_method("get_distance_to_current_green")):
		var root = get_tree().current_scene if (is_inside_tree() and get_tree() != null) else null
		if root != null and (root.has_method("get_distance_to_nearest_green") or root.has_method("get_distance_to_current_green")):
			course = root
	if course != null:
		if course.has_method("get_distance_to_current_green"):
			var d: float = course.get_distance_to_current_green(pos)
			if d > 0.05 and d <= 2.5:
				return true
			return false
		if course.has_method("get_distance_to_nearest_green"):
			var d: float = course.get_distance_to_nearest_green(pos)
			if d > 0.05 and d <= 2.5:
				return true
	return false


func _check_is_on_teebox() -> bool:
	var player_parent = get_parent()
	var parent_scene = player_parent.get_parent() if player_parent != null else null
	if parent_scene != null:
		if ("is_driving_range" in parent_scene and bool(parent_scene.get("is_driving_range"))) or (parent_scene.has_meta("is_driving_range") and bool(parent_scene.get_meta("is_driving_range"))):
			return true

	if lie_type == "teebox":
		return true
	var p_node = get_parent()
	if p_node != null and p_node.get("current_lie_type") == "teebox":
		return true
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and not mp_mgr.players.is_empty():
		var ap = mp_mgr.get_active_player()
		if ap != null:
			if ap.get("lie_type") == "teebox" or ap.get("strokes", 0) == 0:
				return true
	var course = get_tree().current_scene if is_inside_tree() else null
	if course != null:
		if ("is_driving_range" in course and bool(course.get("is_driving_range"))) or (course.has_meta("is_driving_range") and bool(course.get_meta("is_driving_range"))):
			return true
		if course.has_method("get_distance_to_nearest_teebox"):
			if course.call("get_distance_to_nearest_teebox", global_position) <= 2.0:
				return true
		if "practice_start_pos" in course and typeof(course.practice_start_pos) == TYPE_VECTOR3:
			if not course.practice_start_pos.is_zero_approx() and global_position.distance_to(course.practice_start_pos) < 2.5:
				return true
		if "shot_count" in course and course.shot_count == 0:
			return true
	return false


func hit() -> void:
	var target_pos := Vector3.ZERO
	var player_node = get_parent()
	var course = player_node.get_parent() if player_node != null else null
	var on_wrong_green = _is_position_on_wrong_green(global_position)
	var is_on_green = (not on_wrong_green) and (lie_type == "green" or lie_type == "fringe" or _is_position_on_fringe(global_position) or current_selected_club.to_lower() in ["pt", "putt", "putter"])

	if is_on_green:
		target_pos = get_target_hole_position()
	elif course != null and "aim_target_pos" in course and course.aim_target_pos is Vector3 and not course.aim_target_pos.is_zero_approx():
		target_pos = course.aim_target_pos
	else:
		target_pos = get_target_hole_position()
	
	# Determine distance and payload
	var dist_yards := 150.0
	if not target_pos.is_zero_approx():
		var p1_flat = Vector2(global_position.x, global_position.z)
		var p2_flat = Vector2(target_pos.x, target_pos.z)
		var horizontal_dist_yards = p1_flat.distance_to(p2_flat) * 1.09361
		var elevation_diff_yards = (target_pos.y - global_position.y) * 1.09361
		dist_yards = maxf(1.0, horizontal_dist_yards + elevation_diff_yards)
	elif is_on_green:
		dist_yards = 5.0

	var is_putter_sel := current_selected_club.to_lower() in ["pt", "putt", "putter"] or current_selected_club.to_lower().begins_with("putt")
	var club = current_selected_club if not current_selected_club.is_empty() else ("Pt" if is_on_green else "Dr")
	if not is_putter_sel and not current_selected_club.is_empty():
		club = current_selected_club
	var distance_menu_script = load("res://UI/distance_menu.gd")
	var data: Dictionary = {}
	if distance_menu_script != null and distance_menu_script.has_method("build_shot_payload"):
		data = distance_menu_script.build_shot_payload(dist_yards, club)
	else:
		if is_putter_sel or (current_selected_club.is_empty() and is_on_green):
			var putt_speed = 1.8 * sqrt(dist_yards)
			data = {
				"Speed": clampf(putt_speed, 2.0, 40.0),
				"VLA": 0.0,
				"HLA": 0.0,
				"TotalSpin": 50.0,
				"SpinAxis": 0.0,
				"Club": "Pt",
				"ShotType": "putt"
			}
		else:
			data = {
				"Speed": 100.0,
				"VLA": 22.0,
				"HLA": 0.0,
				"TotalSpin": 6000.0,
				"SpinAxis": 0.0,
				"Club": club
			}

	if player_node != null and "shot_data" in player_node:
		player_node.shot_data = data.duplicate()
		player_node.shot_data["TargetDistance"] = dist_yards / 1.09361

	hit_from_data(data)


func hit_from_data(data: Dictionary) -> void:
	if not _try_initialize_ball():
		push_error("Cannot hit shot: OpenFairway classes are not available yet.")
		return
	is_in_water = false
	is_in_sand = false
	water_collider = null
	_hit_leaves_this_shot = false
	_hit_trunk_this_shot = false
	hit_tree_this_shot = false
	_is_in_tree_canopy = false
	_tree_check_timer = 0.0
	_canopy_time = 0.0
	_surface_check_timer = 0.0
	_airborne_low_speed_timer = 0.0
	_shot_duration = 0.0
	_check_scene_has_trees()
	_cached_target_hole = get_target_hole_position()
	is_falling_in_hole = false
	falling_target_hole = Vector3.ZERO
	falling_time = 0.0
	holed_out_this_shot = false
	_cup_sound_played = false
	if _ball_mesh != null:
		_ball_mesh.position.y = get_visual_y_offset()
	flight_time = 0.0
	shot_hit_other_ground = false
	shot_was_from_teebox = _check_is_on_teebox()
	
	RainPhysics.apply_rain_shot_reduction(data)
	BallTypePhysics.apply_ball_type_to_shot_data(data, _current_ball_type_id, str(data.get("Club", data.get("club", current_selected_club))))
	PowerCalibration.apply_calibration(data)
	var speed_mph: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	var raw_ball_speed := speed_mph
	data["RawBallSpeed"] = raw_ball_speed
	data["RawSpeed"] = raw_ball_speed
	
	# Apply lie reduction penalty if any (tee shots NEVER suffer lie reduction)
	var reduction := 0.0
	var player_node = get_parent()
	if not shot_was_from_teebox:
		if player_node != null:
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				var active_player = mp_mgr.get_active_player()
				reduction = active_player.get("shot_reduction", 0.0)
			else:
				var val = player_node.get("current_shot_reduction")
				reduction = val if val != null else 0.0

	if reduction > 0.0:
		var prev_speed = speed_mph
		speed_mph = speed_mph * (1.0 - reduction)
		data["Speed"] = speed_mph
		data["BallSpeed"] = speed_mph
		data["shot_reduction"] = reduction
		print("[ball.gd] Shot reduction applied! Speed reduced from %.2f to %.2f (%.1f%% reduction)" % [prev_speed, speed_mph, reduction * 100.0])
		
		# Reset the reduction now that it has been applied to this shot, saving last_shot_reduction for tracking
		if player_node != null:
			player_node.set("last_shot_reduction", reduction)
			if "shot_data" in player_node and player_node.shot_data is Dictionary:
				player_node.shot_data["shot_reduction"] = reduction
				player_node.shot_data["Speed"] = speed_mph
				player_node.shot_data["BallSpeed"] = speed_mph
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				var active_player = mp_mgr.get_active_player()
				active_player["last_shot_reduction"] = reduction
				active_player["shot_reduction"] = 0.0
				active_player["lie_type"] = "fairway"
			else:
				player_node.current_shot_reduction = 0.0
				player_node.current_lie_type = "fairway"
	else:
		data["shot_reduction"] = 0.0
		if player_node != null:
			player_node.set("last_shot_reduction", 0.0)
			if "shot_data" in player_node and player_node.shot_data is Dictionary:
				player_node.shot_data["shot_reduction"] = 0.0
			var mp_mgr = get_node_or_null("/root/MultiplayerManager")
			if mp_mgr != null and not mp_mgr.players.is_empty():
				var active_player = mp_mgr.get_active_player()
				active_player["last_shot_reduction"] = 0.0

	var speed_mps: float = speed_mph * 0.44704  # mph to m/s
	var vla_deg: float = float(data.get("VLA", 0.0))
	var hla_deg: float = float(data.get("HLA", 0.0))

	var shot_type: String = str(data.get("ShotType", ""))
	var club_name: String = str(data.get("Club", data.get("club", current_selected_club)))
	if club_name != "":
		current_selected_club = club_name

	var is_driver := current_selected_club.to_lower() in ["dr", "driver", "1w"]
	var is_putter := current_selected_club.to_lower() in ["pt", "putt", "putter"] or current_selected_club.to_lower().begins_with("putt")
	var is_teebox := (lie_type == "teebox")

	# Putt determination logic:
	# A hit should only be considered as a putt when a putter is being used.
	# Driver shots, teebox shots, non-putters, and full swings (> 45 mph) are strictly never putts.
	if not is_putter or is_driver or is_teebox or speed_mph > 45.0:
		is_putt = false
	else:
		# Putting stroke with putter: allow putting up to 14.0 deg VLA
		# (permits natural turf pops off fringe collar grass without converting into an airborne iron flight)
		is_putt = (vla_deg < 14.0)

	# If VLA is 0 or unmeasured on a driver shot with high speed (> 45 mph),
	# default VLA to standard driver launch angle (11.5 deg) to prevent grounded rollout.
	if is_driver and vla_deg <= 0.01 and speed_mph > 45.0 and not is_putt:
		vla_deg = 11.5
		print("[ball.gd] Driver shot detected with zero/missing VLA. Auto-correcting VLA to 11.5 deg.")

	var spin_data: Dictionary = {}
	if _shot_setup != null:
		var parsed_spin = _call_openfairway_method(_shot_setup, &"parse_spin", &"ParseSpin", [data])
		if typeof(parsed_spin) == TYPE_DICTIONARY:
			spin_data = parsed_spin
	if spin_data.is_empty():
		spin_data = _parse_spin_data(data)
	var total_spin: float = spin_data.total
	var spin_axis: float = spin_data.axis

	var launch_data: Dictionary = {}
	if _shot_setup != null:
		var launch_result = _call_openfairway_method(
			_shot_setup,
			&"build_launch_vectors",
			&"BuildLaunchVectors",
			[speed_mph, vla_deg, hla_deg, total_spin, spin_axis]
		)
		if typeof(launch_result) == TYPE_DICTIONARY:
			launch_data = launch_result

	var launch_velocity: Vector3
	var launch_omega: Vector3
	var launch_direction: Vector3
	if launch_data.is_empty():
		launch_velocity = Vector3(speed_mps, 0, 0) \
			.rotated(Vector3.FORWARD, deg_to_rad(-vla_deg)) \
			.rotated(Vector3.UP, deg_to_rad(-hla_deg))
		var flat_velocity := Vector3(launch_velocity.x, 0.0, launch_velocity.z)
		launch_direction = flat_velocity.normalized() if flat_velocity.length() > 0.001 else Vector3.RIGHT
		launch_omega = Vector3(0.0, 0.0, total_spin * 0.10472) \
			.rotated(Vector3.RIGHT, deg_to_rad(spin_axis)) \
			.rotated(Vector3.UP, deg_to_rad(-hla_deg))
	else:
		launch_velocity = launch_data.get("velocity", Vector3.ZERO)
		launch_omega = launch_data.get("omega", Vector3.ZERO)
		launch_direction = launch_data.get("shot_direction", Vector3.RIGHT)

	if absf(aim_yaw_offset_deg) > 0.0001:
		var aim_yaw_rad := deg_to_rad(aim_yaw_offset_deg)
		launch_velocity = launch_velocity.rotated(Vector3.UP, aim_yaw_rad)
		launch_omega = launch_omega.rotated(Vector3.UP, aim_yaw_rad)
		launch_direction = launch_direction.rotated(Vector3.UP, aim_yaw_rad)
	launch_direction.y = 0.0
	if launch_direction.length_squared() < 0.000001:
		launch_direction = Vector3.RIGHT
	launch_direction = launch_direction.normalized()

	if is_putt:
		state = PhysicsEnums.BallState.ROLLOUT
		on_ground = true
		if lie_type == "fringe" or _is_position_on_fringe(global_position):
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		else:
			set_surface(PhysicsEnums.SurfaceType.GREEN)
		if _tee_mesh != null:
			_tee_mesh.visible = false
	else:
		state = PhysicsEnums.BallState.FLIGHT
		on_ground = false
		_surface_zone_stack.clear()
		if is_teebox or lie_type == "teebox":
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		elif lie_type == "fairway":
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		elif lie_type == "rough":
			set_surface(PhysicsEnums.SurfaceType.ROUGH)
		elif lie_type == "sand":
			set_surface(PhysicsEnums.SurfaceType.BUNKER)
		else:
			set_surface(int(GlobalSettings.range_settings.surface_type.value))
		if _tee_mesh != null:
			_tee_mesh.visible = false

	rollout_impact_spin_rpm = 0.0
	if position.length_squared() < 0.0001:
		position = Vector3(0.0, START_HEIGHT, 0.0)

	if is_putt:
		var probe := _try_probe_ground()
		if probe.get("hit", false):
			var hit_pos: Vector3 = probe.get("position", global_position)
			var probed_norm: Vector3 = probe.get("normal", Vector3.UP)
			if is_ground_normal(probed_norm):
				floor_normal = probed_norm.normalized()
			var nys := maxf(floor_normal.y, MIN_GROUND_NORMAL)
			global_position.y = hit_pos.y + (_ball_radius + GROUND_SNAP_OFFSET) / nys
		var speed_mag := speed_mps
		var flat_vel := Vector3(launch_velocity.x, 0.0, launch_velocity.z)
		if flat_vel.length_squared() > 0.000001:
			launch_velocity = flat_vel
		# Project launch velocity along the slope contour to avoid ramming into uphill slopes or floating
		launch_velocity = _remove_velocity_along_normal(launch_velocity, floor_normal)
		if launch_velocity.length_squared() > 0.000001:
			launch_velocity = launch_velocity.normalized() * speed_mag
		launch_omega = (floor_normal.cross(launch_velocity)) / _ball_radius
	else:
		# Airborne shots (driver, woods, irons, wedges)
		var probe := _try_probe_ground()
		if probe.get("hit", false):
			var probed_norm: Vector3 = probe.get("normal", floor_normal)
			if is_ground_normal(probed_norm):
				floor_normal = probed_norm.normalized()
			var hit_pos: Vector3 = probe.get("position", global_position)
			var nys := maxf(floor_normal.y, MIN_GROUND_NORMAL)
			var target_launch_y: float
			if is_teebox and can_tee_up():
				# Teebox shot: Driver is teed up 1.5 inches above ground; other clubs rest right on grass
				target_launch_y = hit_pos.y + (TEED_CENTER_HEIGHT if is_driver else GROUND_CENTER_HEIGHT)
			else:
				# Sphere center resting on slope is (R + snap) / nys; add 6mm safety clearance
				target_launch_y = hit_pos.y + (_ball_radius + GROUND_SNAP_OFFSET + 0.006) / nys
			if global_position.y < target_launch_y:
				global_position.y = target_launch_y
		elif global_position.y < (GROUND_CENTER_HEIGHT + 0.006):
			global_position.y = GROUND_CENTER_HEIGHT + 0.006

		# Adjust launch vectors for golfer stance matching the terrain slope
		if not is_teebox and is_ground_normal(floor_normal) and floor_normal.distance_squared_to(Vector3.UP) > 0.0001:
			var slope_res := calculate_slope_adjusted_launch(
				launch_velocity,
				launch_omega,
				launch_direction,
				floor_normal
			)
			launch_velocity = slope_res.velocity
			launch_omega = slope_res.omega
			launch_direction = slope_res.shot_direction

	var lateral_curve_scale: float = 1.0
	if GlobalSettings != null and GlobalSettings.range_settings != null and "shot_curve_sensitivity" in GlobalSettings.range_settings:
		lateral_curve_scale = float(GlobalSettings.range_settings.shot_curve_sensitivity.value)

	if params != null:
		if _physics_params_factory != null:
			_call_openfairway_method(
				_physics_params_factory,
				&"configure_shot",
				&"ConfigureShot",
				[params, _air_density, _air_viscosity, _drag_scale, _lift_scale, vla_deg, speed_mph, total_spin, is_putt, lateral_curve_scale]
			)
		else:
			_set_openfairway_property(params, &"drag_scale", &"DragScale", _drag_scale)
			_set_openfairway_property(params, &"lift_scale", &"LiftScale", _lift_scale)
			_set_openfairway_property(params, &"initial_launch_angle_deg", &"InitialLaunchAngleDeg", vla_deg)
			_set_openfairway_property(params, &"is_putt", &"IsPutt", is_putt)
			_set_openfairway_property(params, &"lateral_curve_scale", &"LateralCurveScale", lateral_curve_scale)

	shot_start_pos = position
	shot_start_pos_global = global_position
	_current_ground_y = global_position.y
	_ground_elevation_timer = 0.0
	_update_ground_elevation()
	shot_was_in_sand = is_in_sand or (lie_type == "sand")
	launch_spin_rpm = total_spin

	if has_node("/root/TensionManager"):
		TensionManager.reset_for_new_shot()
		if TensionManager.is_course_play_active() and not _cached_target_hole.is_zero_approx():
			if TensionManager.is_shot_eligible_for_suspense(global_position, _cached_target_hole, is_putt, shot_was_in_sand):
				TensionManager.predict_shot_outcome(global_position, launch_velocity, is_putt, _cached_target_hole, shot_was_in_sand)

	_print_launch_debug(data, speed_mps, vla_deg, hla_deg, total_spin, spin_axis)

	if shot_was_from_teebox and is_instance_valid(tee_shot_view) and tee_shot_view.has_method("prepare_for_shot"):
		var target_pos := _cached_target_hole
		if target_pos.is_zero_approx():
			target_pos = get_target_hole_position()
		var launch_state := state
		state = PhysicsEnums.BallState.REST
		await tee_shot_view.prepare_for_shot(shot_start_pos_global, global_position, target_pos)
		state = launch_state

	# Play hit sound after the tee-shot window finishes opening.
	if _sfx_player != null:
		_sfx_player.volume_db = 0.0
		_sfx_player.pitch_scale = randf_range(0.97, 1.03)
		if is_putt:
			_sfx_player.stream = _sfx_hit_putt
		elif is_driver:
			_sfx_player.stream = _sfx_hit_drive
		else:
			_sfx_player.stream = _sfx_hit_other
		_sfx_player.play()

	velocity = launch_velocity
	omega = launch_omega
	shot_dir = launch_direction
	target_dir = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(aim_yaw_offset_deg)).normalized()


func _parse_spin_data(data: Dictionary) -> Dictionary:
	var has_backspin := data.has("BackSpin")
	var has_sidespin := data.has("SideSpin")
	var has_total := data.has("TotalSpin")
	var has_axis := data.has("SpinAxis")

	var backspin: float = float(data.get("BackSpin", 0.0))
	var sidespin: float = float(data.get("SideSpin", 0.0))
	var total_spin: float = float(data.get("TotalSpin", 0.0))
	var spin_axis: float = float(data.get("SpinAxis", 0.0))

	# Calculate missing values
	if total_spin == 0.0 and (has_backspin or has_sidespin):
		total_spin = sqrt(backspin * backspin + sidespin * sidespin)

	if not has_axis and (has_backspin or has_sidespin):
		spin_axis = rad_to_deg(atan2(sidespin, backspin))

	if has_total and has_axis:
		if not has_backspin:
			backspin = total_spin * cos(deg_to_rad(spin_axis))
		if not has_sidespin:
			sidespin = total_spin * sin(deg_to_rad(spin_axis))

	return {
		"backspin": backspin,
		"sidespin": sidespin,
		"total": total_spin,
		"axis": spin_axis
	}


func _print_launch_debug(data: Dictionary, speed_mps: float, vla: float, hla: float, spin: float, axis: float) -> void:
	print("=== SHOT DEBUG ===")
	print("Ball Speed: %.2f mph (%.2f m/s)" % [float(data.get("BallSpeed", data.get("Speed", 0.0))), speed_mps])
	print("VLA: %.2f deg, HLA: %.2f deg" % [vla, hla])
	print("Aim yaw offset: %.2f deg" % aim_yaw_offset_deg)
	print("Spin: %.0f rpm, Axis: %.2f deg" % [spin, axis])

	var eff_drag: float = float(_get_openfairway_property(params, &"drag_scale", &"DragScale", _drag_scale))
	var eff_lift: float = float(_get_openfairway_property(params, &"lift_scale", &"LiftScale", _lift_scale))
	var eff_curve: float = float(_get_openfairway_property(params, &"lateral_curve_scale", &"LateralCurveScale", 1.0))
	print("drag_scale: %.3f, lift_scale: %.3f, lateral_curve_scale: %.2f (base: %.2f, %.2f)" % [eff_drag, eff_lift, eff_curve, _drag_scale, _lift_scale])

	if _physics_params_factory != null:
		var regime_info = _call_openfairway_method(
			_physics_params_factory,
			&"get_regime_info",
			&"GetRegimeInfo",
			[float(data.get("BallSpeed", data.get("Speed", 0.0))), vla, spin]
		)
		if typeof(regime_info) == TYPE_DICTIONARY and not regime_info.is_empty():
			var matched_key: String = str(regime_info.get("matched_key", ""))
			var regime_key: String = str(regime_info.get("regime_key", ""))
			var profile_name: String = str(regime_info.get("flight_profile_name", "Default"))
			if matched_key != "":
				print("Regime: %s (matched: %s) -> drag_mult=%.3f, lift_mult=%.3f, profile=%s" % [
					regime_key, matched_key,
					float(regime_info.get("drag_multiplier", 1.0)),
					float(regime_info.get("lift_multiplier", 1.0)),
					profile_name
				])
			else:
				print("Regime: %s (neutral, profile=%s)" % [regime_key, profile_name])

	print("Air density: %.4f kg/m^3" % _air_density)
	print("Dynamic viscosity: %.11f" % _air_viscosity)

	var Re_initial = _air_density * speed_mps * _ball_radius * 2.0 / _air_viscosity
	var spin_ratio = (spin * 0.10472) * _ball_radius / speed_mps if speed_mps > 0.1 else 0.0
	var cl_result = _call_openfairway_method(_aero, &"get_cl", &"GetCl", [Re_initial, spin_ratio])
	var Cl_initial = float(cl_result) if cl_result != null else 0.0
	print("Reynolds number: %.0f" % Re_initial)
	print("Spin ratio: %.3f" % spin_ratio)
	print("Cl (before scale): %.3f, after: %.3f" % [Cl_initial, Cl_initial * _lift_scale])
	print("Initial velocity: ", velocity)
	print("Initial omega: ", omega, " (%.0f rpm)" % (omega.length() / 0.10472))
	print("Shot direction: ", shot_dir)
	if is_ground_normal(floor_normal) and floor_normal.distance_squared_to(Vector3.UP) > 0.0001:
		var slope_deg := rad_to_deg(acos(clampf(floor_normal.y, -1.0, 1.0)))
		print("Lie slope: %.1f deg (normal: %s)" % [slope_deg, floor_normal])
	print("===================")
func _update_surface_from_collider(collider: Object) -> void:
	if collider == null:
		return
		
	if collider.has_meta("is_water") and bool(collider.get_meta("is_water")):
		var was_in_flight = (state != PhysicsEnums.BallState.REST)
		is_in_water = true
		water_collider = collider
		is_in_sand = false
		_enter_rest_state()
		if was_in_flight and _sfx_player != null and not _skipping_flight:
			_sfx_player.stream = _sfx_water_splash
			_sfx_player.play()
		return

	is_in_water = false
	water_collider = null

	var name_lower = collider.name.to_lower()
	var on_wrong_green = _is_position_on_wrong_green(global_position)
	var on_green_geo = (not on_wrong_green) and _is_position_on_green(global_position)
	var on_fairway_geo = (not on_wrong_green) and (not on_green_geo) and _is_position_on_fairway(global_position)
	var is_sand = (collider.has_meta("is_sand") and bool(collider.get_meta("is_sand"))) or name_lower.contains("bunker") or name_lower.contains("sand") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.BUNKER)
	var is_green = (not on_wrong_green) and (on_green_geo or name_lower.contains("green") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.GREEN))
	var is_cart_path = (collider.has_meta("is_cart_path") and bool(collider.get_meta("is_cart_path"))) or (collider.has_meta("is_road") and bool(collider.get_meta("is_road"))) or (collider.has_meta("is_cart_bridge") and bool(collider.get_meta("is_cart_bridge"))) or name_lower.contains("cartpath") or name_lower.contains("cartbridge") or name_lower.contains("road_static") or name_lower.contains("cart_path")
	var is_tee = name_lower.contains("tee")
	var is_fairway = on_wrong_green or on_fairway_geo or name_lower.contains("fairway") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.FAIRWAY)
	var is_rough = (not on_wrong_green) and (not on_green_geo) and (not on_fairway_geo) and (name_lower.contains("rough") or name_lower.contains("terrain") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.ROUGH))

	var changed_sand = (is_in_sand != is_sand)
	is_in_sand = is_sand

	var changed_cart_path = (is_on_cart_path_or_road != is_cart_path)
	is_on_cart_path_or_road = is_cart_path

	if is_sand:
		lie_type = "sand"
		set_surface(PhysicsEnums.SurfaceType.BUNKER)
		if changed_sand:
			_apply_surface_params()
	elif is_green:
		lie_type = "green"
		set_surface(PhysicsEnums.SurfaceType.GREEN)
		if changed_sand:
			_apply_surface_params()
	elif is_cart_path:
		lie_type = "fairway"
		set_surface(PhysicsEnums.SurfaceType.CART_PATH)
		if changed_sand or changed_cart_path:
			_apply_surface_params()
	elif is_tee:
		lie_type = "teebox"
		set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		if changed_sand:
			_apply_surface_params()
	elif is_fairway:
		lie_type = "fairway"
		set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
	elif is_rough:
		if _is_position_on_fringe(global_position):
			lie_type = "fringe"
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		else:
			lie_type = "rough"
			set_surface(PhysicsEnums.SurfaceType.ROUGH)
		if changed_sand:
			_apply_surface_params()
	elif name_lower.contains("dynamicground") or (collider.get_parent() != null and collider.get_parent().name.to_lower().contains("dynamicground")):
		if global_position.distance_to(spawn_position) < 1.5:
			lie_type = "teebox"
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		elif abs(global_position.z) <= 26.0 and global_position.x >= -12.0:
			lie_type = "fairway"
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		else:
			lie_type = "rough"
			set_surface(PhysicsEnums.SurfaceType.ROUGH)
		if changed_sand:
			_apply_surface_params()
	else:
		# Fallback to original checks
		if collider.has_meta("surface_type"):
			var st = int(collider.get_meta("surface_type"))
			set_surface(st)
			if on_green_geo or name_lower.contains("green") or st == PhysicsEnums.SurfaceType.GREEN:
				lie_type = "green"
			elif st == PhysicsEnums.SurfaceType.BUNKER:
				lie_type = "sand"
				is_in_sand = true
			elif name_lower.contains("tee"):
				lie_type = "teebox"
			elif name_lower.contains("fairway") or st == PhysicsEnums.SurfaceType.FAIRWAY:
				lie_type = "fairway"
			elif name_lower.contains("rough") or st == PhysicsEnums.SurfaceType.ROUGH:
				if _is_position_on_fringe(global_position):
					lie_type = "fringe"
					set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
				else:
					lie_type = "rough"
			else:
				if _is_position_on_fringe(global_position):
					lie_type = "fringe"
					set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
				else:
					lie_type = "rough"
		else:
			if on_green_geo or name_lower.contains("green"):
				set_surface(PhysicsEnums.SurfaceType.GREEN)
				lie_type = "green"
			elif name_lower.contains("tee"):
				set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
				lie_type = "teebox"
			elif name_lower.contains("fairway"):
				set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
				lie_type = "fairway"
			elif name_lower.contains("rough"):
				if _is_position_on_fringe(global_position):
					set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
					lie_type = "fringe"
				else:
					set_surface(PhysicsEnums.SurfaceType.ROUGH)
					lie_type = "rough"
			else:
				if _is_position_on_fringe(global_position):
					set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
					lie_type = "fringe"
				else:
					set_surface(PhysicsEnums.SurfaceType.ROUGH)
					lie_type = "rough"
		if changed_sand:
			_apply_surface_params()

func _update_surface_from_underneath() -> void:
	var player_parent = get_parent()
	var parent_scene = player_parent.get_parent() if player_parent != null else null
	var is_range := false
	if parent_scene != null:
		if ("is_driving_range" in parent_scene and bool(parent_scene.get("is_driving_range"))) or (parent_scene.has_meta("is_driving_range") and bool(parent_scene.get_meta("is_driving_range"))):
			is_range = true
	var cur_scene = get_tree().current_scene if is_inside_tree() else null
	if cur_scene != null:
		if ("is_driving_range" in cur_scene and bool(cur_scene.get("is_driving_range"))) or (cur_scene.has_meta("is_driving_range") and bool(cur_scene.get_meta("is_driving_range"))):
			is_range = true

	if is_range:
		is_in_water = false
		water_collider = null
		var changed_sand = is_in_sand
		is_in_sand = false
		set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
		lie_type = "teebox"
		if changed_sand:
			_apply_surface_params()
		return

	var world := get_world_3d()
	if world == null:
		return
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 0.6)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	
	# Exclude TerrainStatic and RoughStatic from initial search if possible
	# to prioritize hitting specific surface colliders first.
	if not _terrain_cache_searched:
		_terrain_cache_searched = true
		var curr = get_parent() if is_inside_tree() else null
		while curr != null and is_instance_valid(curr):
			if _cached_terrain_static == null:
				_cached_terrain_static = curr.get_node_or_null("TerrainStatic") as CollisionObject3D
			if _cached_rough_static == null:
				_cached_rough_static = curr.get_node_or_null("RoughStatic") as CollisionObject3D
			if not curr.is_inside_tree():
				break
			curr = curr.get_parent()
		
	if is_instance_valid(_cached_terrain_static):
		query.exclude.append(_cached_terrain_static.get_rid())
	if is_instance_valid(_cached_rough_static):
		query.exclude.append(_cached_rough_static.get_rid())
		
	# Collect all colliders hit at this point
	var hit_colliders: Array = []
	for attempt in range(4):
		var hit = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider = hit["collider"]
		if collider:
			hit_colliders.append(collider)
			query.exclude.append(collider.get_rid())
		else:
			break

	var on_green_geo = _is_position_on_green(global_position)
	var on_fairway_geo = (not _is_position_on_wrong_green(global_position)) and (not on_green_geo) and _is_position_on_fairway(global_position)

	if hit_colliders.is_empty():
		var has_green_geo := _has_course_green_geometry()
		# Check if we are on green
		if on_green_geo or (is_putt and not is_in_sand and not has_green_geo):
			is_in_water = false
			water_collider = null
			var changed_sand = is_in_sand
			is_in_sand = false
			set_surface(PhysicsEnums.SurfaceType.GREEN)
			lie_type = "green"
			if changed_sand:
				_apply_surface_params()
			return

		# Check if we are on the fringe bordering a green
		if _is_position_on_fringe(global_position):
			is_in_water = false
			water_collider = null
			var changed_sand = is_in_sand
			is_in_sand = false
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
			lie_type = "fringe"
			if changed_sand:
				_apply_surface_params()
			return

		# Check if on teebox
		if _check_is_on_teebox():
			is_in_water = false
			water_collider = null
			var changed_sand = is_in_sand
			is_in_sand = false
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
			lie_type = "teebox"
			if changed_sand:
				_apply_surface_params()
			return

		# Check if on fairway
		if on_fairway_geo:
			is_in_water = false
			water_collider = null
			var changed_sand = is_in_sand
			is_in_sand = false
			set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
			lie_type = "fairway"
			if changed_sand:
				_apply_surface_params()
			return

		# If the ray hit nothing specific, we are on the base rough terrain!
		is_in_water = false
		water_collider = null
		var changed_sand = is_in_sand
		is_in_sand = false
		set_surface(PhysicsEnums.SurfaceType.ROUGH)
		lie_type = "rough"
		if changed_sand:
			_apply_surface_params()
		return

	# Evaluate which is the highest-priority collider
	var best_collider = null
	var best_priority = -1 # Higher is better

	for collider in hit_colliders:
		var priority = 0
		
		# 1. Check for water
		if collider.has_meta("is_water") and bool(collider.get_meta("is_water")):
			priority = 7
		# 2. Check for sand
		elif (collider.has_meta("is_sand") and bool(collider.get_meta("is_sand"))) or collider.name.to_lower().contains("bunker") or collider.name.to_lower().contains("sand") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.BUNKER):
			priority = 6
		# 3. Check for green
		elif (not _is_position_on_wrong_green(global_position)) and (on_green_geo or collider.name.to_lower().contains("green") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.GREEN)):
			priority = 5
		elif (collider.has_meta("is_cart_path") and bool(collider.get_meta("is_cart_path"))) or (collider.has_meta("is_road") and bool(collider.get_meta("is_road"))) or (collider.has_meta("is_cart_bridge") and bool(collider.get_meta("is_cart_bridge"))) or collider.name.to_lower().contains("cartpath") or collider.name.to_lower().contains("cartbridge") or collider.name.to_lower().contains("road_static") or collider.name.to_lower().contains("cart_path"):
			priority = 4
		# 4. Check for tee
		elif collider.name.to_lower().contains("tee"):
			priority = 3
		# 5. Check for fairway
		elif _is_position_on_wrong_green(global_position) or on_fairway_geo or collider.name.to_lower().contains("fairway") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.FAIRWAY):
			priority = 2
		# 6. Check for rough
		elif (not on_fairway_geo) and (collider.name.to_lower().contains("rough") or (collider.has_meta("surface_type") and int(collider.get_meta("surface_type")) == PhysicsEnums.SurfaceType.ROUGH)):
			priority = 1
		else:
			# Unknown/default priority
			priority = 0
			
		if priority > best_priority:
			best_priority = priority
			best_collider = collider

	if best_collider != null:
		_update_surface_from_collider(best_collider)


func _orient_ball_to_aim() -> void:
	if _ball_mesh == null or not is_instance_valid(_ball_mesh):
		return
	var mesh_scale := get_mesh_scale()
	var forward_dir := get_target_dir()
	var up_dir := Vector3.UP
	if on_ground and floor_normal.length_squared() > 0.5 and is_ground_normal(floor_normal):
		up_dir = floor_normal.normalized()
		var proj_fwd = forward_dir - up_dir * forward_dir.dot(up_dir)
		if proj_fwd.length_squared() > 0.0001:
			forward_dir = proj_fwd.normalized()
	var right_dir := forward_dir.cross(up_dir).normalized()
	if right_dir.length_squared() < 0.0001:
		right_dir = Vector3.RIGHT
	var target_basis := Basis(forward_dir, up_dir, right_dir).scaled(Vector3(mesh_scale, mesh_scale, mesh_scale))
	_ball_mesh.basis = target_basis
	if _ball_mesh.is_inside_tree():
		var t := _ball_mesh.global_transform
		t.basis = target_basis
		_ball_mesh.global_transform = t



func apply_ball_type(ball_type_id: String) -> void:
	var prev_drag := _drag_scale
	var prev_lift := _lift_scale
	_current_ball_type_id = BallTypePhysics.normalize_ball_type(ball_type_id)
	_drag_scale = BallTypePhysics.get_drag_scale_multiplier(_current_ball_type_id)
	_lift_scale = BallTypePhysics.get_lift_scale_multiplier(_current_ball_type_id)
	var friction_mult := BallTypePhysics.get_friction_multiplier(_current_ball_type_id)
	_kinetic_mult = friction_mult
	_rolling_mult = friction_mult
	_ball_type_bounce_retention = BallTypePhysics.get_bounce_retention_multiplier(_current_ball_type_id)
	_ball_type_spinback_mult = BallTypePhysics.get_spinback_multiplier(_current_ball_type_id)
	_apply_surface_params()
	if params != null:
		if absf(prev_drag) > 0.0001:
			var cur_p_drag := float(_get_openfairway_property(params, &"drag_scale", &"DragScale", prev_drag))
			_set_openfairway_property(params, &"drag_scale", &"DragScale", cur_p_drag * (_drag_scale / prev_drag))
		if absf(prev_lift) > 0.0001:
			var cur_p_lift := float(_get_openfairway_property(params, &"lift_scale", &"LiftScale", prev_lift))
			_set_openfairway_property(params, &"lift_scale", &"LiftScale", cur_p_lift * (_lift_scale / prev_lift))


func get_ball_type() -> String:
	return _current_ball_type_id


func apply_ball_graphic(graphic_id: String, avatar_path: String = "", player_name: String = "", player_color: Color = Color(0.24, 0.46, 0.72)) -> void:
	_current_ball_graphic_id = graphic_id if not graphic_id.is_empty() else "single_line"
	if _current_ball_graphic_id == "osg_pro" or _current_ball_graphic_id == "classic_white" or _current_ball_graphic_id == "tour_yellow" or _current_ball_graphic_id == "neon_orange":
		_current_ball_graphic_id = "single_line"

	if _ball_mesh != null and is_instance_valid(_ball_mesh):
		var icosphere = _ball_mesh.find_child("Icosphere", true, false) as MeshInstance3D
		if icosphere != null:
			var cache_key = "%s|%s|%s|%s" % [_current_ball_graphic_id, avatar_path, player_name, str(player_color)]
			var mat: StandardMaterial3D = _ball_material_cache.get(cache_key, null)
			if mat == null:
				mat = StandardMaterial3D.new()
				mat.roughness = 0.22
				mat.metallic = 0.0
				mat.albedo_color = Color.WHITE
				match _current_ball_graphic_id:
					"single_line":
						if ResourceLoader.exists("res://assets/models/balls/ball_single_line.png"):
							mat.albedo_texture = load("res://assets/models/balls/ball_single_line.png")
					"triple_track":
						if ResourceLoader.exists("res://assets/models/balls/ball_triple_track.png"):
							mat.albedo_texture = load("res://assets/models/balls/ball_triple_track.png")
					"arrow_track":
						if ResourceLoader.exists("res://assets/models/balls/ball_arrow_track.png"):
							mat.albedo_texture = load("res://assets/models/balls/ball_arrow_track.png")
					"player_icon":
						var img: Image = null
						if ResourceLoader.exists("res://assets/models/balls/ball_single_line.png"):
							var base_tex = load("res://assets/models/balls/ball_single_line.png")
							if base_tex is Texture2D:
								var base_img = base_tex.get_image()
								if base_img != null:
									img = base_img.duplicate()
									img.convert(Image.FORMAT_RGBA8)
						if img == null:
							img = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
							img.fill(Color(0.98, 0.98, 0.99))

						var loaded_icon := false
						var avatar_img: Image = null
						if not avatar_path.is_empty():
							if ResourceLoader.exists(avatar_path):
								var av_res = load(avatar_path)
								if av_res is Texture2D:
									var res_img = av_res.get_image()
									if res_img != null:
										avatar_img = res_img.duplicate()
							if avatar_img == null:
								var raw_img := Image.new()
								var p = ProjectSettings.globalize_path(avatar_path) if avatar_path.begins_with("res://") or avatar_path.begins_with("user://") else avatar_path
								if raw_img.load_svg_from_file(p, 2.0) == OK or raw_img.load(p) == OK:
									avatar_img = raw_img

						var decal_size := 180
						if avatar_img != null and not avatar_img.is_empty():
							avatar_img = avatar_img.duplicate()
							avatar_img.convert(Image.FORMAT_RGBA8)
							avatar_img.resize(decal_size, decal_size, Image.INTERPOLATE_LANCZOS)
							loaded_icon = true

							# Stamp on +Z side (address/golfer side, y=132): flipped vertically for upright 3D orientation
							var av_flipped = avatar_img.duplicate()
							av_flipped.flip_y()
							img.blend_rect(av_flipped, Rect2i(0, 0, decal_size, decal_size), Vector2i(512 - decal_size / 2, 132 - decal_size / 2))

							# Stamp on -Z side (opposite side, y=892): standard orientation
							img.blend_rect(avatar_img, Rect2i(0, 0, decal_size, decal_size), Vector2i(512 - decal_size / 2, 892 - decal_size / 2))

						if not loaded_icon:
							var badge_rad: int = 70
							var side_centers: Array[Vector2i] = [Vector2i(512, 132), Vector2i(512, 892)]
							for sc in side_centers:
								var cx: int = sc.x
								var cy: int = sc.y
								for y in range(cy - badge_rad - 4, cy + badge_rad + 4):
									for x in range(cx - badge_rad - 4, cx + badge_rad + 4):
										if x < 0 or x >= 1024 or y < 0 or y >= 1024:
											continue
										var dist = Vector2(x - cx, y - cy).length()
										if dist <= badge_rad:
											if dist <= badge_rad - 14 and dist >= badge_rad - 20:
												img.set_pixel(x, y, Color.WHITE)
											else:
												img.set_pixel(x, y, player_color)
										elif dist <= badge_rad + 3:
											img.set_pixel(x, y, Color(1, 1, 1, 0.8))
						mat.albedo_texture = ImageTexture.create_from_image(img)
					_:
						if ResourceLoader.exists("res://assets/models/balls/ball_single_line.png"):
							mat.albedo_texture = load("res://assets/models/balls/ball_single_line.png")
				_ball_material_cache[cache_key] = mat
			icosphere.material_override = mat

	_orient_ball_to_aim()


var _is_glow_mode: bool = false
var _glow_omni_light: OmniLight3D = null

func set_glow_mode(enabled: bool) -> void:
	if _is_glow_mode == enabled:
		return
	_is_glow_mode = enabled
	_update_ball_glow_visuals()


func is_glow_mode() -> bool:
	return _is_glow_mode


func _update_ball_glow_visuals() -> void:
	if _ball_mesh == null or not is_instance_valid(_ball_mesh):
		return
	var icosphere = _ball_mesh.find_child("Icosphere", true, false) as MeshInstance3D
	if icosphere == null:
		return

	if _is_glow_mode:
		var glow_mat = StandardMaterial3D.new()
		glow_mat.albedo_color = Color(0.32, 1.0, 0.58) # Radiant electric glow in the dark
		glow_mat.roughness = 0.15
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(0.32, 1.0, 0.58)
		glow_mat.emission_energy_multiplier = 1.4 # Softened glow, less overly bright
		icosphere.material_override = glow_mat

		if _glow_omni_light == null:
			_glow_omni_light = OmniLight3D.new()
			_glow_omni_light.name = "BallGlowLight"
			_glow_omni_light.light_color = Color(0.32, 1.0, 0.58)
			_glow_omni_light.light_energy = 0.75 # Controlled illumination
			_glow_omni_light.omni_range = 1.6
			_glow_omni_light.omni_attenuation = 1.5
			_glow_omni_light.shadow_enabled = false
			add_child(_glow_omni_light)
		_glow_omni_light.visible = true
	else:
		if _glow_omni_light != null:
			_glow_omni_light.visible = false
		apply_ball_graphic(_current_ball_graphic_id)
