shader_type spatial;

uniform vec3 color = vec3(0.2, 0.5, 0.05);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = color;
	AO = 0.5;
	ROUGHNESS = 0.4;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
