extends Resource

# each column corresponds to the following Re values
var reValues : Array[float] = [40430.41, 63244.72, 88080.55, 112627.58, 136308.25]

# each row gives the spin values for the associated Re values above
var spinValues : Array[Array] = [
	[0, 0.0398963567, 0.07979271341, 0.1196890701, 0.1595854268, 0.1994817835, 0.2393781402, 0.2792744969, 0.3191708536, 0.3590672103, 0.398963567, 0.4388599238, 0.4787562805, 0.5186526372, 0.5585489939, 0.5984453506, 0.6383417073, 0.678238064, 0.7181344207, 0.7580307774, 0.7979271341, 0.8378234908, 0.8777198475, 0.9176162042, 0.9575125609, 0.9974089176, 1.037305274],
	[0, 0.02550452027, 0.05100904054, 0.0765135608, 0.1020180811, 0.1275226013, 0.1530271216, 0.1785316419, 0.2040361621, 0.2295406824, 0.2550452027, 0.2805497229, 0.3060542432, 0.3315587635, 0.3570632838, 0.382567804, 0.4080723243, 0.4335768446, 0.4590813648, 0.4845858851, 0.5100904054, 0.5355949256, 0.5610994459, 0.5866039662, 0.6121084864, 0.6376130067, 0.663117527],
	[0, 0.01831308177, 0.03662616353, 0.0549392453, 0.07325232706, 0.09156540883, 0.1098784906, 0.1281915724, 0.1465046541, 0.1648177359, 0.1831308177, 0.2014438994, 0.2197569812, 0.238070063, 0.2563831447, 0.2746962265, 0.2930093083, 0.31132239, 0.3296354718, 0.3479485536, 0.3662616353, 0.3845747171, 0.4028877989, 0.4212008806, 0.4395139624, 0.4578270442, 0.4761401259],
	[0, 0.01432176907, 0.02864353815, 0.04296530722, 0.05728707629, 0.07160884537, 0.08593061444, 0.1002523835, 0.1145741526, 0.1288959217, 0.1432176907, 0.1575394598, 0.1718612289, 0.186182998, 0.200504767, 0.2148265361, 0.2291483052, 0.2434700743, 0.2577918433, 0.2721136124, 0.2864353815, 0.3007571505, 0.3150789196, 0.3294006887, 0.3437224578, 0.3580442268, 0.3723659959],
	[0, 0.01183366512, 0.02366733025, 0.03550099537, 0.0473346605, 0.05916832562, 0.07100199075, 0.08283565587, 0.09466932099, 0.1065029861, 0.1183366512, 0.1301703164, 0.1420039815, 0.1538376466, 0.1656713117, 0.1775049769, 0.189338642, 0.2011723071, 0.2130059722, 0.2248396374, 0.2366733025, 0.2485069676, 0.2603406327, 0.2721742979, 0.284007963, 0.2958416281, 0.3076752932]
]

# each row corresponds to the above Re values
# each collumn corresponds to the spin values for the corresponding Re value
var data : Array[Array] = [
	[0.495, 0.497, 0.492, 0.488, 0.47, 0.43, 0.397, 0.371, 0.365, 0.373, 0.389, 0.402, 0.405, 0.406, 0.408, 0.409, 0.43, 0.479, 0.507, 0.522, 0.532, 0.54, 0.545, 0.547, 0.547, 0.547, 0.547],
	[0.355, 0.332, 0.309, 0.295, 0.29, 0.288, 0.29, 0.297, 0.301, 0.31, 0.325, 0.343, 0.357, 0.361, 0.362, 0.365, 0.397, 0.423, 0.436, 0.447, 0.451, 0.457, 0.459, 0.46, 0.459, 0.458, 0.455],
	[0.254, 0.261, 0.266, 0.268, 0.267, 0.262, 0.26, 0.262, 0.268, 0.284, 0.298, 0.302, 0.3, 0.301, 0.306, 0.313, 0.331, 0.348, 0.36, 0.37, 0.377, 0.382, 0.386, 0.389, 0.391, 0.393, 0.396],
	[0.254, 0.261, 0.266, 0.268, 0.267, 0.262, 0.26, 0.262, 0.268, 0.27, 0.273, 0.278, 0.278, 0.28, 0.286, 0.292, 0.3, 0.31, 0.32, 0.328, 0.334, 0.34, 0.344, 0.349, 0.351, 0.355, 0.358],
	[0.254, 0.261, 0.266, 0.268, 0.267, 0.262, 0.26, 0.262, 0.265, 0.267, 0.265, 0.267, 0.269, 0.278, 0.285, 0.286, 0.29, 0.299, 0.302, 0.308, 0.311, 0.315, 0.318, 0.32, 0.322, 0.326, 0.329]
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
