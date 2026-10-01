shader_type spatial;

uniform vec3 color_small: source_color = vec3(0.3, 0.6, 0.1);
uniform vec3 color_large: source_color = vec3(0.9, 0.9, 0.2);

uniform vec3 ground_color: source_color = vec3(0.0, 0.0, 0.0);

uniform sampler2D patch_noise;
uniform float patch_scale = 5.0;

uniform sampler2D high_frequency_noise: filter_linear_mipmap_anisotropic;
uniform sampler2D baked_normals: hint_normal, filter_linear_mipmap_anisotropic;

uniform sampler2D wind_noise;
uniform float wind_strength = 0.1;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_bend_strength = 2.0;
uniform float wind_ao_affect = 1.5;

instance uniform float alpha = 1.0;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float normal_to_view = 1.0 - dot(VIEW, NORMAL);

	float patch_factor = texture(patch_noise, world_vertex.xz / patch_scale).r;
	patch_factor = mix(patch_factor, 1.0, normal_to_view * 0.4);

	ALBEDO = mix(color_small, color_large, patch_factor);

	float high_frequency_sample = texture(high_frequency_noise, world_vertex.xz / patch_scale, -1.0).r;

	float spottiness = (1.0 - normal_to_view) * 0.5 - patch_factor * 0.2;
	float ground_factor = smoothstep(spottiness + 0.1, spottiness - 0.1, high_frequency_sample);

	ALBEDO = mix(ALBEDO, ground_color, clamp(ground_factor + 1.0 - alpha, 0.0, 1.0));

	// Wind
	vec2 wind_position = world_vertex.xz / 10.0;
	wind_position -= (TIME + 8.0) * wind_direction * wind_strength;

	float current_wind_bend = texture(wind_noise, wind_position).x;
	current_wind_bend *= wind_strength * 2.0;

	float bottom_to_top_simulation = high_frequency_sample + smoothstep(0.6, 1.0, normal_to_view) * 0.4;
	AO = mix(0.5, 1.0, bottom_to_top_simulation) - current_wind_bend * wind_ao_affect;
	AO_LIGHT_AFFECT = 1.0;

	// Normal Map
	NORMAL_MAP = texture(baked_normals, world_vertex.xz / 5.0, -1.0).xyz;

	// Lighting
	BACKLIGHT = vec3(0.2);
	ROUGHNESS = 0.4;
	SPECULAR = 0.12;
}
