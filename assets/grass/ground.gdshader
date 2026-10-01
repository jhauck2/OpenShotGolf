shader_type spatial;

uniform vec3 color = vec3(0.1, 0.15, 0.004);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	AO = 0.1;
	AO_LIGHT_AFFECT = 1.0;
	ALBEDO = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
