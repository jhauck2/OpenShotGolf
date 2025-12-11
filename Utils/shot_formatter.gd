extends Object
class_name ShotFormatter

# Formats ball/shot data for UI display, with unit conversion and derived spin.
# If show_distance is false, Distance is left unchanged from prev_data (or set to "---" if not provided).
static func format_ball_display(raw_ball_data: Dictionary, player: Node, units: Enums.Units, show_distance: bool, prev_data: Dictionary = {}) -> Dictionary:
	var ball_data: Dictionary = {}
	var m2yd := 1.09361
	var has_backspin := raw_ball_data.has("BackSpin")
	var has_sidespin := raw_ball_data.has("SideSpin")
	var has_total := raw_ball_data.has("TotalSpin")
	var has_axis := raw_ball_data.has("SpinAxis")
	var backspin: float = (raw_ball_data.get("BackSpin", 0.0) as float)
	var sidespin: float = (raw_ball_data.get("SideSpin", 0.0) as float)
	var total_spin: float = (raw_ball_data.get("TotalSpin", 0.0) as float)
	var spin_axis: float = (raw_ball_data.get("SpinAxis", 0.0) as float)
	if total_spin == 0.0 and (has_backspin or has_sidespin):
		total_spin = sqrt(backspin*backspin + sidespin*sidespin)
	if not has_axis and (has_backspin or has_sidespin):
		spin_axis = rad_to_deg(atan2(sidespin, backspin))
	if has_total and has_axis:
		if not has_backspin:
			backspin = total_spin * cos(deg_to_rad(spin_axis))
		if not has_sidespin:
			sidespin = total_spin * sin(deg_to_rad(spin_axis))
	
	if units == Enums.Units.IMPERIAL:
		if show_distance:
			ball_data["Distance"] = str(int(player.get_distance()*m2yd))
		else:
			ball_data["Distance"] = prev_data.get("Distance", "---")
		var carry_val = player.carry
		if carry_val <= 0 and raw_ball_data.has("CarryDistance"):
			carry_val = raw_ball_data.get("CarryDistance", 0.0) as float / 1.0 # raw is assumed yards
		ball_data["Carry"] = str(int(carry_val*m2yd if not raw_ball_data.has("CarryDistance") else carry_val))
		ball_data["Apex"] = str(int(player.apex*3.28084))
		var side_distance = int(player.get_side_distance()*m2yd)
		var side_text := "R"
		if side_distance < 0:
			side_text = "L"
		side_text += str(abs(side_distance))
		ball_data["Offline"] = side_text
		ball_data["Speed"] = "%3.1f" % raw_ball_data.get("Speed", 0.0)
	else:
		if show_distance:
			ball_data["Distance"] = str(player.get_distance())
		else:
			ball_data["Distance"] = prev_data.get("Distance", "---")
		var carry_val = player.carry
		if carry_val <= 0 and raw_ball_data.has("CarryDistance"):
			carry_val = raw_ball_data.get("CarryDistance", 0.0) as float
		ball_data["Carry"] = str(int(carry_val))
		ball_data["Apex"] = str(int(player.apex))
		var side_distance = player.get_side_distance()
		var side_text := "R"
		if side_distance < 0:
			side_text = "L"
		side_text += str(abs(side_distance))
		ball_data["Offline"] = side_text
		ball_data["Speed"] = "%3.1f" % (raw_ball_data.get("Speed", 0.0) * 0.44704)
	
	ball_data["BackSpin"] = str(int(backspin))
	ball_data["SideSpin"] = str(int(sidespin))
	ball_data["TotalSpin"] = str(int(total_spin))
	ball_data["SpinAxis"] = "%3.1f" % spin_axis
	ball_data["VLA"] = raw_ball_data.get("VLA", 0.0)
	ball_data["HLA"] = raw_ball_data.get("HLA", 0.0)
	return ball_data
