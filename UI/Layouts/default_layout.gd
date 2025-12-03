extends "res://UI/Layouts/base_layout.gd"

signal hit_shot(data)

func _ready() -> void:
	# Connect shot injector
	var shot_injector = get_node_or_null("ShotInjector")
	if shot_injector:
		shot_injector.inject.connect(_on_shot_injector_inject)

	# Connect club selector
	var club_selector = get_node_or_null("GridCanvas/ClubSelector")
	if club_selector and club_selector.has_signal("club_selected"):
		club_selector.club_selected.connect(_on_club_selector_club_selected)

	# Connect EventBus
	EventBus.club_selected.connect(_on_club_selected)

	# Connect to range systems
	_connect_to_range_systems()

func _connect_to_range_systems() -> void:
	if not range_ref:
		return

	var golf_ball = range_ref.get_node_or_null("GolfBall")
	if golf_ball:
		hit_shot.connect(golf_ball._on_range_ui_hit_shot)

func activate() -> void:
	visible = true

func deactivate() -> void:
	visible = false

func update_data(data: Dictionary) -> void:
	var grid_canvas = get_node_or_null("GridCanvas")
	if grid_canvas and grid_canvas.has_method("set_data"):
		var imperial = GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL
		if imperial:
			grid_canvas.get_node_or_null("Distance").set_data(data.get("Distance", "---"))
			grid_canvas.get_node_or_null("Carry").set_data(data.get("Carry", "---"))
			grid_canvas.get_node_or_null("Side").set_data(data.get("Offline", "---"))
			grid_canvas.get_node_or_null("Apex").set_data(data.get("Apex", "---"))
			grid_canvas.get_node_or_null("VLA").set_data("%.1f" % data.get("VLA", 0.0))
			grid_canvas.get_node_or_null("HLA").set_data("%.1f" % data.get("HLA", 0.0))
		else:
			grid_canvas.get_node_or_null("Distance").set_data(data.get("Distance", "---"))
			grid_canvas.get_node_or_null("Carry").set_data(data.get("Carry", "---"))
			grid_canvas.get_node_or_null("Side").set_data(data.get("Offline", "---"))
			grid_canvas.get_node_or_null("Apex").set_data(data.get("Apex", "---"))
			grid_canvas.get_node_or_null("VLA").set_data("%.1f" % data.get("VLA", 0.0))
			grid_canvas.get_node_or_null("HLA").set_data("%.1f" % data.get("HLA", 0.0))

func _on_club_selected(club: String) -> void:
	club_selected.emit(club)

func _on_club_selector_club_selected(club: String) -> void:
	EventBus.club_selected.emit(club)

func _on_shot_injector_inject(data: Dictionary) -> void:
	hit_shot.emit(data)
