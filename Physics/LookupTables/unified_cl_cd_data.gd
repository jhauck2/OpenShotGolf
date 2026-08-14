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
	[0.000, -0.150, 0.085, 0.190, 0.245],  # Re = 5.0e4 (Deep -0.150 peak inversion)
	[0.000, -0.100, 0.120, 0.215, 0.250],  # Re = 7.5e4 (Sustained -0.100 transition)
	[0.000,  0.080, 0.180, 0.235, 0.252],  # Re = 1.0e5 
	[0.000,  0.095, 0.185, 0.240, 0.252],  # Re = 1.25e5
	[0.000,  0.100, 0.182, 0.238, 0.250],  # Re = 1.5e5
	[0.000,  0.102, 0.180, 0.236, 0.248],  # Re = 1.75e5 (Asymptotic cap implemented)
	[0.000,  0.101, 0.179, 0.235, 0.245],  # Re = 2.0e5
	[0.000,  0.100, 0.178, 0.234, 0.242]   # Re = 2.25e5
]


func getCd(Re: float, spin: float) -> float:
	return getValue(Re, spin, cd_data)
	
func getCl(Re: float, spin: float) -> float:
	return getValue(Re, spin, cl_data)

func getValue(Re: float, spin: float, data: Array[Array]) -> float:
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
	
	var spinIndexBelow : int = 0
	var spinIndexAbove : int = 1
	
	# Check for off table - Lower Re
	if spin < spinValues[0]:
		spinIndexAbove = 0
	elif spin > spinValues[-1]:
		spinIndexBelow = spinValues.size()-1
		spinIndexBelow = spinValues.size()-1
	else:
		for i in range(1, spinValues.size()):
			if spin < spinValues[i]:
				spinIndexAbove = i
				spinIndexBelow = i - 1
				break
	
	var valLowRe : float
	var valHiRe : float
	if ReIndexBelow == ReIndexAbove: # Re off table
		if spinIndexBelow == spinIndexAbove: # Both off table, take value directly
			return data[ReIndexBelow][spinIndexBelow]
		else: # Only Re off table, interpolate between spin values
			var spinBelow : float = spinValues[spinIndexBelow]
			var spinAbove : float = spinValues[spinIndexAbove]
			var weight : float = (spin - spinBelow)/(spinAbove - spinBelow)
			return lerpf(data[ReIndexBelow][spinIndexBelow], data[ReIndexBelow][spinIndexAbove], weight)
	else: # Re not off table
		if spinIndexBelow == spinIndexAbove: # Low Re spin off table, set cdLowRe directly
			valLowRe = data[ReIndexBelow][spinIndexBelow]
		else: # Spin not off table
			# interpolate valLowRe
			var spinBelowLowRe : float = spinValues[spinIndexBelow]
			var spinAboveLowRe : float = spinValues[spinIndexAbove]
			var weightSpin : float = (spin - spinBelowLowRe)/(spinAboveLowRe - spinBelowLowRe)
			valLowRe = lerpf(data[ReIndexBelow][spinIndexBelow], data[ReIndexBelow][spinIndexAbove], weightSpin)
			
			# interpolate valHiRe
			valHiRe = lerpf(data[ReIndexAbove][spinIndexBelow], data[ReIndexAbove][spinIndexAbove], weightSpin)
	
	var ReBelow : float = reValues[ReIndexBelow]
	var ReAbove : float = reValues[ReIndexAbove]
	var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
	
	return lerpf(valLowRe, valHiRe, weightRe)
