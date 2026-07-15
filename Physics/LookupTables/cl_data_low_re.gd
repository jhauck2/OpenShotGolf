extends Resource

# each column corresponds to the following Re values
var reValues : Array[float] = [39564.04, 62378.35, 86347.81, 110894.85, 135441.89]

# each row gives the spin values for the associated Re values above
var spinValues : Array[Array] = [
	[0.16308, 0.20385, 0.24462, 0.28539, 0.32616, 0.36693, 0.40770, 0.44847, 0.48924, 0.53001, 0.57078, 0.61155, 0.65232, 0.69309, 0.73386, 0.77463, 0.81540, 0.85617, 0.89694 , 0.93771, 0.97848, 1.01925, 1.06002],
	[0.10343, 0.12929, 0.15515, 0.18101, 0.20687, 0.23273, 0.25859, 0.28445, 0.31030, 0.33616, 0.36202, 0.38788, 0.41374, 0.43960, 0.46546, 0.49132, 0.51717, 0.54303, 0.56889, 0.59475, 0.62061, 0.64647, 0.67233],
	[0.07472, 0.09340, 0.11208, 0.13076, 0.14944, 0.16813, 0.18681, 0.20549, 0.22417, 0.24285, 0.26153, 0.28021, 0.29889, 0.31757, 0.33625, 0.35493, 0.37361, 0.39229, 0.41097, 0.42965, 0.44833, 0.46701, 0.48569],
	[0.05818, 0.07273, 0.08727, 0.10182, 0.11636, 0.13091, 0.14546, 0.16000, 0.17455, 0.18909, 0.20364, 0.21818, 0.23273, 0.24727, 0.26182, 0.27637, 0.29091, 0.30546, 0.32000, 0.33455, 0.34909, 0.36364, 0.37818],
	[0.04764, 0.05955, 0.07146, 0.08337, 0.09527, 0.10718, 0.11909, 0.13100, 0.14291, 0.15482, 0.16673, 0.17864, 0.19055, 0.20246, 0.21437, 0.22628, 0.23819, 0.25010, 0.26201, 0.27392, 0.28582, 0.29773, 0.30964]
]

# each row corresponds to the above Re values
# each collumn corresponds to the spin values for the corresponding Re value
var data : Array[Array] = [
	[-0.06, -0.037, -0.009, 0.029, 0.105, 0.212, 0.289, 0.339, 0.364, 0.378, 0.388, 0.395, 0.4, 0.404, 0.408, 0.411, 0.417, 0.425, 0.436, 0.45, 0.471, 0.5, 0.52],
	[0.119, 0.128, 0.138, 0.155, 0.188, 0.24, 0.288, 0.318, 0.338, 0.35, 0.36, 0.364, 0.367, 0.374, 0.378, 0.385, 0.392, 0.398, 0.403, 0.415, 0.425, 0.445, 0.47],
	[0.17, 0.194, 0.215, 0.232, 0.25, 0.265, 0.27, 0.285, 0.305, 0.318, 0.327, 0.332, 0.338, 0.341, 0.345, 0.348, 0.35, 0.355, 0.36, 0.369, 0.377, 0.39, 0.41],
	[0.141, 0.156, 0.17, 0.183, 0.199, 0.21, 0.224, 0.237, 0.247, 0.26, 0.271, 0.28, 0.287, 0.295, 0.302, 0.306, 0.313, 0.318, 0.322, 0.331, 0.34, 0.352, 0.37],
	[0.125, 0.138, 0.15, 0.162, 0.172, 0.182, 0.192, 0.201, 0.209, 0.218, 0.226, 0.233, 0.24, 0.25, 0.257, 0.267, 0.274, 0.281, 0.288, 0.295, 0.301, 0.312, 0.32]
]


func GetValue(Re: float, spin: float) -> float:
	# Get min and max Re values from table
	var ReMin : float = reValues[0]
	var ReMax : float = reValues[-1]
	
	var ReIndexBelow : int = 0
	var ReIndexAbove : int = 1
	
	# Check for off table
	if Re < ReMin:
		ReIndexAbove = 0
	elif Re > ReMax:
		ReIndexBelow = reValues.size()-1
		ReIndexAbove = reValues.size()-1
	else: # Get bounding values
		for i in range(1, reValues.size()):
			if Re < reValues[i]:
				ReIndexAbove = i
				ReIndexBelow = i - 1
				break
	
	var spinIndexLowReBelow : int = 0
	var spinIndexLowReAbove : int = 1
	
	var spinIndexHiReBelow : int = 0
	var spinIndexHiReAbove : int = 1
	
	# Check for off table - Lower Re
	if spin < spinValues[ReIndexBelow][0]:
		spinIndexLowReAbove = 0
	elif spin > spinValues[ReIndexBelow][-1]:
		spinIndexLowReBelow = spinValues[ReIndexBelow].size()-1
		spinIndexLowReAbove = spinValues[ReIndexBelow].size()-1
	else:
		for i in range(1, spinValues[ReIndexBelow].size()):
			if spin < spinValues[ReIndexBelow][i]:
				spinIndexLowReAbove = i
				spinIndexLowReBelow = i - 1
				break
	
	# Check for off table - Higher Re
	if spin < spinValues[ReIndexAbove][0]:
		spinIndexHiReAbove = 0
	elif spin > spinValues[ReIndexAbove][-1]:
		spinIndexHiReBelow = spinValues[ReIndexAbove].size()-1
		spinIndexHiReAbove = spinValues[ReIndexAbove].size()-1
	else:
		for i in range(1, spinValues[ReIndexAbove].size()):
			if spin < spinValues[ReIndexAbove][i]:
				spinIndexHiReAbove = i
				spinIndexHiReBelow = i - 1
				break
	
	var clLowRe : float
	var clHiRe : float
	if ReIndexBelow == ReIndexAbove: # Re off table
		if spinIndexLowReBelow == spinIndexLowReAbove: # Both off table, take value directly
			return data[ReIndexBelow][spinIndexLowReBelow]
		else: # Only Re off table, interpolate between spin values
			var spinBelow : float = spinValues[ReIndexBelow][spinIndexLowReBelow]
			var spinAbove : float = spinValues[ReIndexBelow][spinIndexLowReAbove]
			var weight : float = (spin - spinBelow)/(spinAbove - spinBelow)
			return lerpf(data[ReIndexBelow][spinIndexLowReBelow], data[ReIndexBelow][spinIndexLowReAbove], weight)
	else: # Re not off table
		if spinIndexLowReBelow == spinIndexLowReAbove: # Low Re spin off table, set cdLowRe directly
			clLowRe = data[ReIndexBelow][spinIndexLowReBelow]
		else: # Low Re spin not off table, interpolate cdLowRe
			var spinBelowLowRe : float = spinValues[ReIndexBelow][spinIndexLowReBelow]
			var spinAboveLowRe : float = spinValues[ReIndexBelow][spinIndexLowReAbove]
			var weightSpinLowRe : float = (spin - spinBelowLowRe)/(spinAboveLowRe - spinBelowLowRe)
			clLowRe = lerpf(data[ReIndexBelow][spinIndexLowReBelow], data[ReIndexBelow][spinIndexLowReAbove], weightSpinLowRe)
			
		if spinIndexHiReBelow == spinIndexHiReAbove: # Hi Re spin off table, set cdHiRe directly
			clHiRe = data[ReIndexAbove][spinIndexHiReBelow]
		else: # Hi Re spin not off table, interpolate cdHiRe
			var spinBelowHiRe : float = spinValues[ReIndexBelow][spinIndexHiReBelow]
			var spinAboveHiRe : float = spinValues[ReIndexBelow][spinIndexHiReAbove]
			var weightSpinHiRe : float = (spin - spinBelowHiRe)/(spinAboveHiRe - spinBelowHiRe)
			clHiRe = lerpf(data[ReIndexBelow][spinIndexHiReBelow], data[ReIndexBelow][spinIndexHiReAbove], weightSpinHiRe)
	
	var ReBelow : float = reValues[ReIndexBelow]
	var ReAbove : float = reValues[ReIndexAbove]
	var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
	
	return lerpf(clLowRe, clHiRe, weightRe)
