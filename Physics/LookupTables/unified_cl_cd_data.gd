extends Resource

# each column corresponds to the following Re values
var reValues : Array[float] = [5.0e4, 7.5e4, 1.0e5, 1.25e5, 1.5e5, 1.75e5, 2.0e5, 2.25e5]

# each row gives the spin values for the associated Re values above
var spinValues : Array[float] = [0.00, 0.10, 0.20, 0.30, 0.40]

# each row corresponds to the above Re values
# each collumn corresponds to the spin values for the corresponding Re value
var cd_data : Array[Array] = [
	[0.340, 0.362, 0.385, 0.408, 0.430],  # Re = 5.0e4
	[0.285, 0.308, 0.330, 0.353, 0.375],  # Re = 7.5e4
	[0.245, 0.268, 0.290, 0.313, 0.335],  # Re = 1.0e5
	[0.230, 0.252, 0.275, 0.298, 0.320],  # Re = 1.25e5
	[0.222, 0.245, 0.268, 0.290, 0.312],  # Re = 1.5e5
	[0.218, 0.241, 0.263, 0.285, 0.308],  # Re = 1.75e5
	[0.215, 0.238, 0.260, 0.283, 0.305],  # Re = 2.0e5
	[0.214, 0.236, 0.259, 0.281, 0.304]   # Re = 2.25e5
]

var cl_data : Array[Array] = [
	[0.000, -0.085, 0.095, 0.210, 0.265],  # Re = 5.0e4
	[0.000, -0.030, 0.145, 0.235, 0.272],  # Re = 7.5e4
	[0.000,  0.090, 0.190, 0.246, 0.280],  # Re = 1.0e5
	[0.000,  0.108, 0.187, 0.243, 0.277],  # Re = 1.25e5
	[0.000,  0.105, 0.184, 0.240, 0.274],  # Re = 1.5e5
	[0.000,  0.103, 0.181, 0.237, 0.271],  # Re = 1.75e5
	[0.000,  0.102, 0.179, 0.235, 0.269],  # Re = 2.0e5
	[0.000,  0.101, 0.178, 0.234, 0.268]   # Re = 2.25e5
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
			var spinBelowHiRe : float = spinValues[ReIndexBelow][spinIndexHiReBelow]
			var spinAboveHiRe : float = spinValues[ReIndexBelow][spinIndexHiReAbove]
			var weightSpinHiRe : float = (spin - spinBelowHiRe)/(spinAboveHiRe - spinBelowHiRe)
			cdHiRe = lerpf(data[ReIndexBelow][spinIndexHiReBelow], data[ReIndexBelow][spinIndexHiReAbove], weightSpinHiRe)
	
	var ReBelow : float = reValues[ReIndexBelow]
	var ReAbove : float = reValues[ReIndexAbove]
	var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
	
	return lerpf(cdLowRe, cdHiRe, weightRe)
