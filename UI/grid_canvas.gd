extends Control

var show_grid := false
var _edit_mode := true
const CELL_SIZE = Vector2(120, 93)
const GRID_SPACING = Vector2(10, 10)
const GRID_SIZE = CELL_SIZE + GRID_SPACING
const GRID_ORIGIN := Vector2(15, 15	)
		
func _draw() -> void:
	if not show_grid:
		return

	var padding_correction := Vector2(0, 0)  # Adjust Y as needed
	var offset : Vector2 = global_position - global_position + padding_correction
	var viewport_size : Vector2 = get_viewport_rect().size
	var origin := Vector2(0, 0)  # if we need to offset the grid (x+10 for the top)
	for x in range(0, viewport_size.x, GRID_SIZE.x):
		var grid_x : float = x + offset.x + origin.x
		draw_line(Vector2(grid_x, 0), Vector2(grid_x, viewport_size.y), Color.GRAY)
	for y in range(0, viewport_size.y, GRID_SIZE.y):
		var grid_y : float = y + offset.y + origin.y
		draw_line(Vector2(0, grid_y), Vector2(viewport_size.x, grid_y), Color.GRAY)

func _ready() -> void:
	load_layout()
	
	GlobalSettings.range_settings.range_units.setting_changed.connect(set_units)

func snap_to_grid(panel: Control) -> void:
	var global_snap_x : float = round((panel.global_position.x - GRID_ORIGIN.x) / GRID_SIZE.x) * GRID_SIZE.x + GRID_ORIGIN.x
	var global_snap_y : float = round((panel.global_position.y - GRID_ORIGIN.y) / GRID_SIZE.y) * GRID_SIZE.y + GRID_ORIGIN.y
	panel.global_position = Vector2(global_snap_x, global_snap_y)

func toggle_edit_mode() -> void:
	_edit_mode = !_edit_mode
	for panel: Control in $VBoxContainer.get_children():
		panel.set_editable(_edit_mode)

func save_layout() -> void:
	var config := ConfigFile.new()
	for panel in get_children():
		config.set_value("positions", panel.name, panel.position)
	config.save("user://layout.cfg")

func load_layout() -> void:
	var config := ConfigFile.new()
	if config.load("user://layout.cfg") != OK: # User does not have a saved config
		config.load("res://UI/default_layout.cfg") # Load default config
		
	for panel: Control in get_children():
		if config.has_section_key("positions", panel.name):  # <-- not "layout"
			panel.position = config.get_value("positions", panel.name)
	
				
func _on_panel_drag_started() -> void:
	show_grid = true
	queue_redraw()

func _on_panel_drag_ended(panel: Control) -> void:
	show_grid = false
	queue_redraw()
	snap_to_grid(panel)
	
func _notification(what: int)-> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_layout()
		get_tree().quit()  # Actually close the game after saving
		
func set_units(value: PhysicsEnums.Units) -> void:
	if value == PhysicsEnums.Units.IMPERIAL:
		$Distance.set_units("yd")
		$Carry.set_units("yd")
		$Side.set_units("yd")
		$Apex.set_units("ft")
	else:
		$Distance.set_units("m")
		$Carry.set_units("m")
		$Side.set_units("m")
		$Apex.set_units("m")
