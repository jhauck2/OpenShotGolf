class_name ClCdTableGenerator
extends Object

static func GenerateClTable() -> void:
	var aero_instance := Aerodynamics.new()
	var ReMin : float = 29000.0
	var ReMax : float = 210000.0
	var ReStep : float = 1000.0
	
	var spinMin : float = 0.0
	var spinMax : float = 0.35
	var spinStep : float = 0.01
	# Generate header information
	
	# Loop through range of Re and Spin Ratio values, store cl
	var spin : float = spinMin
	var data : Array[Array] = []
	var spinValues : Array[float] = []
	var ReValues : Array[float] = []
	while (spin <= spinMax):
		spinValues.append(spin)
		var Re : float = ReMin
		var line : Array[float] = []
		while (Re <= ReMax):
			if spin == spinMin:
				ReValues.append(Re)
			line.append(aero_instance.GetCl(Re, spin))
			Re += ReStep
		
		data.append(line)
		spin += spinStep
	
	WriteClToResource(data, spinValues, ReValues, "res://Physics/LookupTables/cl_data.gd")
	return
	

static func GenerateCdTable() -> void:
	var aero_instance := Aerodynamics.new()
	var ReMin : float = 29000.0
	var ReMax : float = 210000.0
	var ReStep : float = 1000.0
	
	# Loop through range of Re , store cd
	var Re : float = ReMin
	var data : Array[float] = []
	var ReValues : Array[float] = []
	
	while (Re <= ReMax):
		ReValues.append(Re)
		data.append(aero_instance.GetCd(Re))
		Re += ReStep
	
	WriteCdToResource(data, ReValues, "res://Physics/LookupTables/cd_data.gd")
	
	return
	
# Write data to csv file
static func WriteClToResource(table : Array, spinValues : Array, ReValues : Array, filepath : String) -> void:
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	
	# write header lines
	file.store_line("extends Resource")
	file.store_line("")
	
	# write spin values
	file.store_line("# each row corresponds to the following spin values")
	file.store_string("var spinValues : Array[float] = [")
	for i in spinValues.size():
		file.store_string(str(spinValues[i]))
		if i != spinValues.size() - 1:
			file.store_string(", ")
	file.store_string("]\n")
	file.store_line("")
	
	# write Re values
	file.store_line("# each column corresponds to the following Re values")
	file.store_string("var reValues : Array[float] = [")
	for i in ReValues.size():
		file.store_string(str(ReValues[i]))
		if i != ReValues.size() - 1:
			file.store_string(", ")
	file.store_string("]\n")
	file.store_line("")
	
	# store table
	file.store_string("var data = [")
	for i in table.size():
		var row: Array = table[i]
		if i != 0:
			file.store_string("            ")
		file.store_string("[")
		for j:float in row.size():
			file.store_string(str(row[j]))
			if j != row.size() - 1:
				file.store_string(", ")
		file.store_string("]")
		if i != table.size() - 1:
			file.store_string(",\n")
		
	file.store_string("]")

		
	file.close()


static func WriteCdToResource(table : Array, ReValues : Array, filepath : String) -> void:
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	
	# write header lines
	file.store_line("extends Resource")
	file.store_line("")
	
	# write Re values
	file.store_line("# each column corresponds to the following Re values")
	file.store_string("var reValues : Array[float] = [")
	for i in ReValues.size():
		file.store_string(str(ReValues[i]))
		if i != ReValues.size() - 1:
			file.store_string(", ")
	file.store_string("]\n")
	file.store_line("")
	
	# store table
	file.store_string("var data : Array[float] = [")
	for i in table.size():
		file.store_string(str(table[i]))
		if i != table.size() - 1:
			file.store_string(", ")
	file.store_string("]\n")
	
	return
