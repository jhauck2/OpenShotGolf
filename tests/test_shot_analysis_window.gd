extends SceneTree


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var analysis_script = load("res://UI/ShotAnalysis/shot_analysis_window.gd")
	assert(analysis_script != null, "Shot analysis window script must load")
	var analysis := Control.new()
	analysis.set_script(analysis_script)
	root.add_child(analysis)
	await process_frame

	var focus_guard := root.get_node_or_null("UIFocusGuard")
	assert(focus_guard != null, "UIFocusGuard autoload must be available")
	var analysis_window := Window.new()
	analysis_window.title = "Shot Data Analysis"
	analysis_window.transient = false
	analysis_window.exclusive = false
	root.add_child(analysis_window)
	analysis_window.show()
	await process_frame
	assert(focus_guard.call("_find_visible_modal_in_tree") == null, "A non-exclusive analysis window must not lock main-window focus")
	analysis_window.hide()
	analysis_window.queue_free()

	var shots := [
		{"player_name": "Player A", "Player": "Practice Player", "Player Name": "Practice Player", "club": "Driver", "CarryDistance": 10.0, "TotalDistance": 12.0, "Apex": 5.0, "Speed": 30.0, "BallSpeed": 31.0, "ClubPath": 2.0, "TotalSpin": 2500.0, "DescentAngle": 46.0, "VLA": 12.0, "HLA": 1.0, "Recorded In Averages": true, "Shot Reduction": 0.0, "Tracer Points": [Vector3.ZERO], "AimDistanceYards": 20.0, "TargetDistance": 18.0, "ShotType": "drive", "RawMonitorExtra": [1.0, 2.0], "MonitorFlag": true},
		{"player_name": "Player A", "club": "Driver", "CarryDistance": 20.0, "TotalDistance": 22.0, "Speed": 40.0},
		{"player_name": "Player B", "club": "Driver", "CarryDistance": 15.0, "TotalDistance": 17.0, "Speed": 35.0}
	]
	analysis.call("initialize", shots)
	var groups: Array = analysis.get("_groups")
	var records: Array = analysis.get("_records")
	assert(groups.size() == 2, "Shots should be grouped by player and club")
	assert(str(groups[0]["label"]) == "Player A - Driver", "Initial group label should use player and club")
	assert(records.size() == 3, "All shots should be retained")
	var data_keys: Array = analysis.get("_data_keys")
	assert(data_keys == ["Apex", "CarryDistance", "TotalDistance", "BallSpeed", "DescentAngle", "HLA", "VLA", "ClubPath", "TotalSpin", "MonitorFlag", "RawMonitorExtra"], "Descent Angle should appear first in the Ball Flight category")
	var spreadsheet: VBoxContainer = analysis.get("_spreadsheet")
	var table_header := spreadsheet.get_child(0) as VBoxContainer
	var category_header := table_header.get_child(0) as HBoxContainer
	assert((category_header.get_child(2) as Label).text == "Distance & Height", "Distance and height columns should share a category heading")
	assert((category_header.get_child(3) as Label).text == "Ball Speed", "Ball speed columns should have their own category heading")
	assert((category_header.get_child(4) as Label).text == "Ball Flight", "Ball Flight should remain grouped with the other stat categories")
	assert((category_header.get_child(5) as Label).text == "Club & Face", "Club and face columns should share a category heading")
	assert((category_header.get_child(6) as Label).text == "Spin", "Spin columns should have their own category heading")
	var extra_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(data_keys.find("RawMonitorExtra") + 2) as Label
	assert(extra_cell.text == "[1.0, 2.0]", "Raw array-valued launch monitor fields should be visible")
	var flag_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(data_keys.find("MonitorFlag") + 2) as Label
	assert(flag_cell.text == "true", "Raw boolean launch monitor fields should be visible")
	var ball_speed_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(data_keys.find("BallSpeed") + 2) as Label
	assert(ball_speed_cell.text == "31.00", "Ball Speed should be shown once using the canonical launch monitor field")
	assert((table_header.get_child(1) as HBoxContainer).get_child(data_keys.find("BallSpeed") + 2).text == "Ball Speed (mph)", "Imperial speed columns should show miles per hour")
	var descent_angle_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(data_keys.find("DescentAngle") + 2) as Label
	assert(descent_angle_cell.text == "46.00", "Descent Angle should be displayed as a ball flight stat")
	assert((table_header.get_child(1) as HBoxContainer).get_child(data_keys.find("CarryDistance") + 2).text == "Carry (yd)", "Imperial distance columns should show yards in their headers")
	var apex_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(data_keys.find("Apex") + 2) as Label
	assert(apex_cell.text == "16.40", "Imperial apex should be converted from meters to feet")
	assert((table_header.get_child(1) as HBoxContainer).get_child(data_keys.find("Apex") + 2).text == "Apex (ft)", "Imperial apex columns should show feet")
	var upload_data: Dictionary = analysis.call("_prepare_upload_value", {"tracer_points": [Vector3(1.0, 2.0, 3.0)]})
	assert(upload_data["tracer_points"][0] == [1.0, 2.0, 3.0], "Uploaded raw shot data should preserve tracer points as numeric coordinates")

	analysis.call("_set_record_included", 0, false)
	var averages: Dictionary = analysis.get("_averages")
	var keys: Array = analysis.get("_data_keys")
	var summary_row: HBoxContainer = averages[0]
	var carry_cell := summary_row.get_child(keys.find("CarryDistance") + 2) as Label
	assert(carry_cell.text == "21.87", "Imperial group averages should be converted to yards and exclude unchecked shots")

	GlobalSettings.range_settings.range_units.set_value(PhysicsEnums.Units.METRIC)
	spreadsheet = analysis.get("_spreadsheet")
	table_header = spreadsheet.get_child(0) as VBoxContainer
	averages = analysis.get("_averages")
	keys = analysis.get("_data_keys")
	var metric_carry_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(2).get_child(keys.find("CarryDistance") + 2) as Label
	assert(metric_carry_cell.text == "20.00", "Metric shot rows should display distances in meters")
	assert((table_header.get_child(1) as HBoxContainer).get_child(keys.find("CarryDistance") + 2).text == "Carry (m)", "Metric distance columns should show meters in their headers")
	var metric_ball_speed_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(keys.find("BallSpeed") + 2) as Label
	assert(metric_ball_speed_cell.text == "13.86", "Metric ball speed should be converted from mph to meters per second")
	assert((table_header.get_child(1) as HBoxContainer).get_child(keys.find("BallSpeed") + 2).text == "Ball Speed (m/s)", "Metric speed columns should show meters per second")
	var metric_apex_cell: Label = ((spreadsheet.get_child(1) as PanelContainer).get_child(0) as VBoxContainer).get_child(1).get_child(keys.find("Apex") + 2) as Label
	assert(metric_apex_cell.text == "5.00", "Metric apex should remain in meters")
	assert(float(analysis.get("_chart").call("_distance_yards", {"TotalDistance": 10.0})) == 10.0, "Metric charts should use meters on the shared distance scale")
	var metric_average_carry := (averages[0] as HBoxContainer).get_child(keys.find("CarryDistance") + 2) as Label
	assert(metric_average_carry.text == "20.00", "Metric group averages should use meters")
	GlobalSettings.range_settings.range_units.set_value(PhysicsEnums.Units.IMPERIAL)

	var chart: Control = analysis.get("_chart")
	analysis.call("_update_chart")
	assert(float(chart.call("_distance_x", 50.0, 40.0, 240.0, 100.0)) == 140.0, "The shared yardage scale should map the same distance consistently across both charts")
	assert(float(chart.call("_distance_scale_yards")) == 50.0, "The shared yardage scale should include all recorded shot distances")
	var dispersion_distance_stats: Vector2 = chart.call("_dispersion_axis_stats", 0, true)
	assert(float(chart.call("_distance_scale_yards")) > dispersion_distance_stats.x + dispersion_distance_stats.y, "Yardage scale should leave room for the full dispersion circle")
	var best: Dictionary = chart.call("_representative_shot", 0)
	assert(float(best["TotalDistance"]) == 22.0, "Best shot should be the longest included shot")
	assert(is_equal_approx(float(chart.call("_apex_feet", {"Apex": 10.0})), 32.8084), "Apex measurements in meters should be shown in feet")
	var edge_points: Array[Vector2] = [Vector2(96.0, 96.0), Vector2(100.0, 100.0)]
	var clipped_radii: Vector2 = chart.call("_bounded_ellipse_radii", edge_points, Rect2(Vector2(0, 0), Vector2(100, 100)))
	assert(clipped_radii.x <= 0.0 and clipped_radii.y <= 0.0, "Dispersion ellipses should not extend outside chart bounds")
	var mode_selector: OptionButton = analysis.get("_mode_selector")
	mode_selector.select(1)
	analysis.call("_update_chart")
	var average: Dictionary = chart.call("_representative_shot", 0)
	assert(float(average["CarryDistance"]) == 20.0, "Group average should use included shots")

	analysis.call("_on_add_group_pressed")
	analysis.call("_on_add_group_pressed")
	groups = analysis.get("_groups")
	assert(groups.size() == 3, "Only one pending custom group should be created before the next shot")
	var new_group_button: Button = analysis.get("_new_group_button")
	assert(new_group_button.disabled, "New Group should be disabled while waiting for the custom group's first shot")
	analysis.call("add_shot", {"player_name": "Player C", "club": "7 Iron", "CarryDistance": 30.0, "TotalDistance": 32.0})
	assert(groups.size() == 3, "A new shot should use the newly created custom group instead of making a default group")
	assert(int(records[3]["group_id"]) == 2, "A custom group should receive the next shot even after a player or club change")
	assert(not new_group_button.disabled, "New Group should be available again after the shot is recorded")
	analysis.call("add_shot", {"player_name": "Player B", "club": "Driver", "CarryDistance": 25.0, "TotalDistance": 27.0})
	assert(int(records[4]["group_id"]) == 1, "A player and club change should reuse an existing matching group")
	analysis.call("add_shot", {"player_name": "Player D", "club": "Driver", "CarryDistance": 35.0, "TotalDistance": 37.0})
	assert(groups.size() == 4, "A new default group should be created when the player and club have no matching group")
	assert(str(groups[3]["label"]) == "Player D - Driver", "Automatic groups should use the changed player and club label")
	analysis.call("_rename_group", 2, "Warmup")
	assert(str(groups[2]["label"]) == "Warmup", "Group labels should be editable")
	analysis.call("_move_record", 0, 2)
	assert(int(records[0]["group_id"]) == 2, "Shots should be movable between groups")
	analysis.call("_render_spreadsheet")
	analysis.call("_rename_group", 2, "Updated Warmup")
	assert(str(groups[2]["label"]) == "Updated Warmup", "Group labels should remain editable after rebuilding the spreadsheet")
	var group_panel := (spreadsheet.get_child(3) as PanelContainer)
	var group_heading := ((group_panel.get_child(0) as VBoxContainer).get_child(0) as HBoxContainer)
	var delete_button := group_heading.get_child(group_heading.get_child_count() - 1) as Button
	assert(delete_button.text == "Delete", "Each group should provide a delete action")
	analysis.call("_delete_group", 2)
	assert(groups.size() == 3, "Deleting a group should remove it from analysis")
	assert(records.size() == 4, "Deleting a group should remove its shots from analysis only")
	for record in records:
		assert(int(record["group_id"]) != 2, "Deleted-group shots should no longer remain in analysis")
	assert(shots.size() == 3, "Deleting an analysis group must not modify the source shot data")

	var empty_analysis := Control.new()
	empty_analysis.set_script(analysis_script)
	root.add_child(empty_analysis)
	await process_frame
	empty_analysis.call("_on_add_group_pressed")
	empty_analysis.call("_delete_group", 0)
	assert(int(empty_analysis.get("_pending_custom_group_id")) == -1, "Deleting a pending group should clear the pending group state")
	var empty_new_group_button: Button = empty_analysis.get("_new_group_button")
	assert(not empty_new_group_button.disabled, "Deleting a pending group should re-enable New Group")
	empty_analysis.call("_on_add_group_pressed")
	empty_analysis.call("add_shot", {"player_name": "Player E", "club": "Driver", "CarryDistance": 40.0})
	var empty_groups: Array = empty_analysis.get("_groups")
	var empty_records: Array = empty_analysis.get("_records")
	assert(empty_groups.size() == 1, "A custom group created before the first shot should prevent an extra default group")
	assert(int(empty_records[0]["group_id"]) == 1, "The first shot should use the pre-created custom group")
	empty_analysis.queue_free()

	print("Shot analysis grouping, inclusion, averages, and chart selection tests passed.")
	analysis.queue_free()
	quit(0)
