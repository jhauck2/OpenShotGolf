class_name PhysicsTest
extends Resource


static func runTests() -> void:
	var json_text : String = FileAccess.get_file_as_string("res://Resources/PhysicsTest/flightscope_shot_data.json")
	var shot_data : Variant = JSON.parse_string(json_text)
	var ball : GolfBall = GolfBall.new()
	
	var output: Array[Dictionary] = []
	
	for shot : Dictionary in shot_data:
		# Reset Ball
		ball.reset()
		
		# Simulate shot from data
		ball.hit_from_data({"Speed": shot["Ball (mph)"], "VLA": shot["Launch V (deg)"], "SpinAxis": shot["Spin Axis (deg)"],
							"HLA": shot["Launch H (deg)"], "TotalSpin": shot["Spin (rpm)"]})
		# Store min and max Re and spin ratio
		var minRe: float = INF
		var maxRe: float = 0.0
		var minS: float = INF
		var maxS: float = 0.0
		var apex: float = 0.0
		var distance: float = 0.0 # Carry only
		
		var delta: float = 1.0/60.0
		
		while(true):
			# Store max and min Re and Spin
			var curRe: float = Aero.GetRe(ball.velocity.length(), BPhysics.RADIUS)
			var curS: float = ball.omega.length()*BPhysics.RADIUS/ball.velocity.length()
			if curRe < minRe: minRe = curRe
			if curRe > maxRe: maxRe = curRe
			if curS < minS: minS = curS
			if curS > maxS: maxS = curS
			
			var force: Vector3 = BPhysics.CalculateForces(ball.velocity, ball.omega, false)
			var torque: Vector3 = BPhysics.CalculateTorques(ball.velocity, ball.omega, false)
			
			ball.velocity += (force / BPhysics.MASS) * delta
			ball.omega += (torque / BPhysics.I) * delta
			ball.position += ball.velocity * delta
			
			if ball.position.y > apex:
				apex = ball.position.y
			
			if ball.position.y <= 0:
				distance = ball.position.x
				break
				
		# Create output analysis
		var out: Dictionary = {}
		out["Shot Num"] = int(shot["No."])
		out["Expected Distance"] = shot["Carry (yd)"]
		out["Actual Distance"] = distance*1.09361
		out["% Distance Diff"] = out["Actual Distance"]/out["Expected Distance"]
		out["Expected Apex"] = shot["Height (ft)"]
		out["Actual Apex"] = apex*3.28084
		out["% Apex Diff"] = out["Actual Apex"]/out["Expected Apex"]
		out["Min Re"] = minRe
		out["Max Re"] = maxRe
		out["Min Spin"] = minS
		out["Max Spin"] = maxS
		
		output.append(out)
		
	# write output to file
	var output_string: String = JSON.stringify(output,"\t")
	var file: FileAccess = FileAccess.open("res://Resources/PhysicsTest/test_results.json", FileAccess.WRITE)
	file.store_string(output_string)
	file.close()
		
