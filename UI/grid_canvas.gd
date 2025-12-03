extends Control

var show_grid := false
var _edit_mode := true
const CELL_SIZE = Vector2(120, 93)
const GRID_SPACING = Vector2(10, 10)
const GRID_SIZE = CELL_SIZE + GRID_SPACING
const GRID_ORIGIN := Vector2(15, 15	)
		
func _draw():
	if not show_grid:
		return

	var viewport_size = get_viewport_rect().size
	# Draw vertical lines starting from GRID_ORIGIN.x
	var x = GRID_ORIGIN.x
	while x < viewport_size.x:
		draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), Color.GRAY)
		x += GRID_SIZE.x
	# Draw horizontal lines starting from GRID_ORIGIN.y
	var y = GRID_ORIGIN.y
	while y < viewport_size.y:
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), Color.GRAY)
		y += GRID_SIZE.y

func _ready():
	load_layout()
	
	GlobalSettings.range_settings.range_units.setting_changed.connect(set_units)

func snap_to_grid(panel: Control):
	var snap_x = round((panel.position.x - GRID_ORIGIN.x) / GRID_SIZE.x) * GRID_SIZE.x + GRID_ORIGIN.x
	var snap_y = round((panel.position.y - GRID_ORIGIN.y) / GRID_SIZE.y) * GRID_SIZE.y + GRID_ORIGIN.y
	panel.position = Vector2(snap_x, snap_y)

func toggle_edit_mode():
	_edit_mode = !_edit_mode
	for panel in $VBoxContainer.get_children():
		panel.set_editable(_edit_mode)

func save_layout():
	var config = ConfigFile.new()
	for panel in get_children():
		config.set_value("positions", panel.name, panel.position)
	config.save("user://layout.cfg")

func load_layout():
	var config = ConfigFile.new()
	if config.load("user://layout.cfg") != OK: # User does not have a saved config
		config.load("res://UI/default_layout.cfg") # Load default config
		
	for panel in get_children():
		if config.has_section_key("positions", panel.name):  # <-- not "layout"
			panel.position = config.get_value("positions", panel.name)
	
				
func _on_panel_drag_started():
	show_grid = true
	queue_redraw()

func _on_panel_drag_ended(panel):
	show_grid = false
	queue_redraw()
	snap_to_grid(panel)
	
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_layout()
		get_tree().quit()  # Actually close the game after saving
		
func set_units(value):
	# Only update units if this GridCanvas node exists and is in the tree
	if not is_node_ready():
		return

	var distance = get_node_or_null("Distance")
	var carry = get_node_or_null("Carry")
	var offline = get_node_or_null("Offline")
	var apex = get_node_or_null("Apex")

	if value == Enums.Units.IMPERIAL:
		if distance: distance.set_units("yd")
		if carry: carry.set_units("yd")
		if offline: offline.set_units("yd")
		if apex: apex.set_units("ft")
	else:
		if distance: distance.set_units("m")
		if carry: carry.set_units("m")
		if offline: offline.set_units("m")
		if apex: apex.set_units("m")
