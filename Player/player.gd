extends Node3D

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0.0
var carry := 0.0
var side_distance := 0.0
var shot_data: Dictionary = {}

var max_tracers : int = 4
var min_tracers : int = 0
var tracers : Array = []
var current_tracer : MeshInstance3D = null
var BallTrailScript = preload("res://Player/ball_trail.gd")

var ball : PhysicsBall = null

signal good_data
signal bad_data
signal rest(data: Dictionary)
signal manual_hit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create new golf ball
	ball = PhysicsBall.new(GolfBall.BallType.STANDARD)
	ball.position.y = 3.0
	add_child(ball)
	ball.rest.connect(_on_ball_rest)
	
	# Set initial value and connect to setting changes
	max_tracers = GlobalSettings.range_settings.shot_tracer_count.value
	GlobalSettings.range_settings.shot_tracer_count.setting_changed.connect(_on_tracer_count_changed)
	_apply_ball_type(GlobalSettings.range_settings.ball_type.value)
	GlobalSettings.range_settings.ball_type.setting_changed.connect(_on_ball_type_changed)

func _on_tracer_count_changed(value) -> void:
	max_tracers = value
	# Remove excess tracers if the new limit is lower
	while tracers.size() > max_tracers:
		var oldest = tracers.pop_front()
		oldest.queue_free()


func _on_ball_type_changed(value) -> void:
	_apply_ball_type(value)


func _apply_ball_type(_ball_type_value) -> void:
	reset_ball()

func create_new_tracer() -> MeshInstance3D:
	# Don't create tracer if max_tracers is 0
	if max_tracers == 0:
		current_tracer = null
		return null

	# Remove oldest tracer if we've hit the limit
	if tracers.size() >= max_tracers:
		var oldest = tracers.pop_front()
		oldest.queue_free()

	# Create new tracer
	var new_tracer = MeshInstance3D.new()
	new_tracer.set_script(BallTrailScript)
	add_child(new_tracer)
	# _ready gets called automatically when added to scene tree

	tracers.append(new_tracer)
	current_tracer = new_tracer
	return new_tracer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("hit"):
		track_points = false
		create_new_tracer()
		ball.call_deferred("hit")
		if current_tracer != null:
			current_tracer.add_point(Vector3(0.0, 0.05, 0.0))
		track_points = true
		trail_timer = 0.0
		emit_signal("manual_hit")
	if Input.is_action_just_pressed("reset"):
		ball.call_deferred("reset")
		apex = 0.0
		carry = 0.0
		side_distance = 0.0
		track_points = false
		# Clear all tracers
		for tracer in tracers:
			tracer.queue_free()
		tracers.clear()
		current_tracer = null


func _physics_process(delta: float) -> void:
	if track_points and current_tracer != null:
		apex = max(apex, ball.position.y)
		side_distance = ball.position.z
		if ball.state == GolfBall.BallState.FLIGHT:
			carry = ball.get_downrange_yards() / 1.09361  # Convert yards back to meters for consistency
		trail_timer += delta
		if trail_timer >= trail_resolution:
			current_tracer.add_point(ball.position)
			trail_timer = 0.0

func get_distance() -> int:
	# Returns the downrange distance in meters
	return int(ball.get_downrange_yards() / 1.09361)
	
func get_side_distance() -> int:
	return int(ball.position.z)

func validate_data(data: Dictionary) -> bool:
	# TODO: implement data validation
	if data:
		return true
	else:
		return false


func reset_ball():
	ball.call_deferred("reset")
	# Clear all tracers
	for tracer in tracers:
		tracer.queue_free()
	tracers.clear()
	current_tracer = null
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	reset_shot_data()
		

func reset_shot_data() -> void:
	for key in shot_data.keys():
		shot_data[key] = 0.0

func _on_ball_rest() -> void:
	track_points = false
	shot_data["TotalDistance"] = int(ball.get_downrange_yards() / 1.09361)  # Downrange distance in meters
	shot_data["CarryDistance"] = int(carry)
	shot_data["Apex"] = int(apex)
	shot_data["SideDistance"] = int(side_distance)
	emit_signal("rest", shot_data)


func get_ball_state():
	return ball.state


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	var success : bool = validate_data(data)
	if success:
		emit_signal("good_data")
	else:
		emit_signal("bad_data")
		return

	shot_data = data.duplicate()

	track_points = false
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	create_new_tracer()
	ball.call_deferred("hit_from_data", data)
	if current_tracer != null:
		current_tracer.add_point(Vector3(0.0, 0.05, 0.0))
	track_points = true
	trail_timer = 0.0


func _on_range_ui_hit_shot(data: Variant) -> void:
	shot_data = data.duplicate()
	print("Local shot injection payload: ", JSON.stringify(shot_data))

	track_points = false
	apex = 0.0
	carry = 0.0
	side_distance = 0.0
	create_new_tracer()
	ball.call_deferred("hit_from_data", data)
	if current_tracer != null:
		current_tracer.add_point(Vector3(0.0, 0.05, 0.0))
	track_points = true
	trail_timer = 0.0
	

func _on_range_ui_set_env(data: Variant) -> void:
	ball.call_deferred("set_env", data)
