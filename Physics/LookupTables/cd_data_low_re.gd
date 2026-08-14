extends Resource

# each column corresponds to the following Re values
var reValues : Array[float] = [39564.04, 62378.35, 86347.81, 110894.85, 135441.89]

# each row gives the spin values for the associated Re values above
var spinValues : Array[Array] = [
	[0.00000, 0.04077, 0.08154, 0.12231, 0.16308, 0.20385, 0.24462, 0.28539, 0.32616, 0.36693, 0.40770, 0.44847, 0.48924, 0.53001, 0.57078, 0.61155, 0.65232, 0.69309, 0.73386, 0.77463, 0.81540, 0.85617, 0.89694 , 0.93771, 0.97848, 1.01925, 1.06002],
	[0.00000, 0.02586, 0.05172, 0.07758, 0.10343, 0.12929, 0.15515, 0.18101, 0.20687, 0.23273, 0.25859, 0.28445, 0.31030, 0.33616, 0.36202, 0.38788, 0.41374, 0.43960, 0.46546, 0.49132, 0.51717, 0.54303, 0.56889, 0.59475, 0.62061, 0.64647, 0.67233],
	[0.00000, 0.01868, 0.03736, 0.05604, 0.07472, 0.09340, 0.11208, 0.13076, 0.14944, 0.16813, 0.18681, 0.20549, 0.22417, 0.24285, 0.26153, 0.28021, 0.29889, 0.31757, 0.33625, 0.35493, 0.37361, 0.39229, 0.41097, 0.42965, 0.44833, 0.46701, 0.48569],
	[0.00000, 0.01455, 0.02909, 0.04364, 0.05818, 0.07273, 0.08727, 0.10182, 0.11636, 0.13091, 0.14546, 0.16000, 0.17455, 0.18909, 0.20364, 0.21818, 0.23273, 0.24727, 0.26182, 0.27637, 0.29091, 0.30546, 0.32000, 0.33455, 0.34909, 0.36364, 0.37818],
	[0.00000, 0.01191, 0.02382, 0.03573, 0.04764, 0.05955, 0.07146, 0.08337, 0.09527, 0.10718, 0.11909, 0.13100, 0.14291, 0.15482, 0.16673, 0.17864, 0.19055, 0.20246, 0.21437, 0.22628, 0.23819, 0.25010, 0.26201, 0.27392, 0.28582, 0.29773, 0.30964]
]

# each row corresponds to the above Re values
# each collumn corresponds to the spin values for the corresponding Re value
var data : Array[Array] = [
	[0.528, 0.488, 0.453, 0.420, 0.395, 0.377, 0.362, 0.360, 0.369, 0.383, 0.403, 0.420, 0.423, 0.412, 0.397, 0.408, 0.433, 0.453, 0.469, 0.480, 0.490, 0.498, 0.502, 0.510, 0.515, 0.520, 0.524],
	[0.328, 0.300, 0.279, 0.261, 0.252, 0.249, 0.252, 0.267, 0.290, 0.318, 0.339, 0.356, 0.368, 0.374, 0.374, 0.383, 0.400, 0.415, 0.423, 0.430, 0.437, 0.440, 0.442, 0.448, 0.449, 0.449, 0.449],
	[0.225, 0.226, 0.228, 0.230, 0.232, 0.245, 0.252, 0.267, 0.278, 0.290, 0.300, 0.310, 0.319, 0.326, 0.335, 0.341, 0.349, 0.357, 0.365, 0.372, 0.378, 0.381, 0.384, 0.388, 0.389, 0.389, 0.389],
	[0.235, 0.230, 0.230, 0.230, 0.232, 0.235, 0.248, 0.249, 0.255, 0.260, 0.268, 0.274, 0.281, 0.289, 0.298, 0.303, 0.311, 0.319, 0.325, 0.330, 0.336, 0.340, 0.344, 0.349, 0.352, 0.358, 0.360],
	[0.235, 0.230, 0.230, 0.230, 0.232, 0.235, 0.237, 0.240, 0.247, 0.250, 0.258, 0.262, 0.269, 0.273, 0.278, 0.280, 0.287, 0.291, 0.298, 0.302, 0.310, 0.317, 0.320, 0.327, 0.331, 0.338, 0.340]
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
	
	var cdLowRe : float
	var cdHiRe : float
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
			cdLowRe = data[ReIndexBelow][spinIndexLowReBelow]
		else: # Low Re spin not off table, interpolate cdLowRe
			var spinBelowLowRe : float = spinValues[ReIndexBelow][spinIndexLowReBelow]
			var spinAboveLowRe : float = spinValues[ReIndexBelow][spinIndexLowReAbove]
			var weightSpinLowRe : float = (spin - spinBelowLowRe)/(spinAboveLowRe - spinBelowLowRe)
			cdLowRe = lerpf(data[ReIndexBelow][spinIndexLowReBelow], data[ReIndexBelow][spinIndexLowReAbove], weightSpinLowRe)
			
		if spinIndexHiReBelow == spinIndexHiReAbove: # Hi Re spin off table, set cdHiRe directly
			cdHiRe = data[ReIndexAbove][spinIndexHiReBelow]
		else: # Hi Re spin not off table, interpolate cdHiRe
			var spinBelowHiRe : float = spinValues[ReIndexAbove][spinIndexHiReBelow]
			var spinAboveHiRe : float = spinValues[ReIndexAbove][spinIndexHiReAbove]
			var weightSpinHiRe : float = (spin - spinBelowHiRe)/(spinAboveHiRe - spinBelowHiRe)
			cdHiRe = lerpf(data[ReIndexAbove][spinIndexHiReBelow], data[ReIndexAbove][spinIndexHiReAbove], weightSpinHiRe)
	
	var ReBelow : float = reValues[ReIndexBelow]
	var ReAbove : float = reValues[ReIndexAbove]
	var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
	
	return lerpf(cdLowRe, cdHiRe, weightRe)
