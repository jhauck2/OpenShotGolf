shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// ============================================================================
// High-Resolution Recessed 3D Bunker Shader (Sod Rim + Steep Soil Lip + Raked Sand)
// Replicates the crisp recessed bunker lips and raked white silica sand in
// Warwick Hills reference frames (7:05 & 7:28).
// Vertex COLOR encoding:
//   COLOR.r = Sand floor weight
//   COLOR.g = Steep vertical dark soil/sod wall lip weight
//   COLOR.b = Outer rough turf collar blend weight
//   COLOR.a = Outer feather alpha (1.0 inside & on lip, feathers to 0.0 on outer collar)
// ============================================================================

uniform sampler2D tex_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_sand : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_rough : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 sand_tint : source_color = vec3(1.06, 0.99, 0.87);
uniform vec3 soil_lip_color : source_color = vec3(0.36, 0.26, 0.16);
uniform vec3 deep_root_color : source_color = vec3(0.24, 0.16, 0.09);
uniform vec3 rough_collar_tint : source_color = vec3(0.78, 1.02, 0.66);

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vert_color;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
	               dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
	           mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
	               dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vert_color = COLOR;
}

void fragment() {
	float w_sand = v_vert_color.r;
	float w_lip  = v_vert_color.g;
	float w_turf = v_vert_color.b;
	float total = max(w_sand + w_lip + w_turf, 0.001);
	w_sand /= total;
	w_lip  /= total;
	w_turf /= total;

	vec2 uv_sand = v_world_pos.xz * 0.42;
	vec2 uv_turf = v_world_pos.xz * 0.38;

	// 1. Warm fine raked silica sand floor: subtle organically curved combing & grain
	vec3 col_sand = texture(tex_sand, uv_sand).rgb * sand_tint;
	float rake_phase = dot(v_world_pos.xz, vec2(0.707, -0.707)) * 36.0 + gnoise(v_world_pos.xz * 0.35) * 4.5;
	float rake_wave = sin(rake_phase) * 0.5 + 0.5;
	col_sand *= mix(0.97, 1.03, rake_wave);
	float sand_grain = gnoise(v_world_pos.xz * 140.0) * 0.5 + gnoise(v_world_pos.xz * 55.0) * 0.5;
	col_sand *= 1.0 + sand_grain * 0.05;
	// Subtle wind-blown contour patches
	float dune = gnoise(v_world_pos.xz * 0.35) * 0.5 + 0.5;
	col_sand = mix(col_sand, col_sand * vec3(0.95, 0.91, 0.83), smoothstep(0.55, 0.9, dune) * 0.45);

	float view_dist = length(VERTEX);
	float rake_dist_fade = 1.0 - smoothstep(10.0, 42.0, view_dist);
	vec3 n_sand = texture(normal_sand, uv_sand).rgb * 2.0 - 1.0;
	vec2 rake_tangent = vec2(cos(rake_phase), -sin(rake_phase)) * 0.14 * rake_dist_fade;
	n_sand = normalize(vec3(n_sand.xy + rake_tangent + vec2(sand_grain) * 0.08, max(n_sand.z, 0.78)));

	// 2. Vertical sod / warm brown earthy lip wall with layered strata and exposed roots
	float strata_noise = gnoise(vec2(v_world_pos.x * 3.5 + v_world_pos.z * 3.5, v_world_pos.y * 24.0));
	float strata_band = sin(v_world_pos.y * 55.0 + strata_noise * 3.0) * 0.5 + 0.5;
	float clod_noise = gnoise(v_world_pos.xz * 6.5);
	vec3 col_lip = mix(deep_root_color, soil_lip_color, clamp(strata_noise * 0.5 + 0.5, 0.0, 1.0));
	col_lip = mix(col_lip, vec3(0.50, 0.35, 0.22), strata_band * 0.35);
	col_lip *= (0.88 + 0.30 * (clod_noise * 0.5 + 0.5));
	// Warm sand-soil wash streaks
	col_lip = mix(col_lip, col_sand * 0.88, smoothstep(0.50, 0.95, gnoise(v_world_pos.xz * 9.0 + v_world_pos.y * 30.0) * 0.5 + 0.5) * 0.30);
	vec3 n_lip = normalize(vec3(clod_noise * 0.80, strata_noise * 0.90 + (strata_band - 0.5) * 0.6, 1.0));

	// 3. Overhanging rough turf rim, with tufted ragged fringe
	vec3 col_turf = texture(tex_rough, uv_turf).rgb * rough_collar_tint;
	float tuft = gnoise(v_world_pos.xz * 14.0) * 0.5 + gnoise(v_world_pos.xz * 37.0) * 0.5;
	col_turf *= 1.0 + tuft * 0.30;
	vec3 n_turf = mix(vec3(0.0, 0.0, 1.0), texture(normal_rough, uv_turf).rgb * 2.0 - 1.0, 0.75);
	n_turf = normalize(n_turf + vec3(tuft * 0.25, gnoise(v_world_pos.xz * 21.0) * 0.25, 0.0));

	// Ragged organic breakup between turf overhang, root-shadowed lip, and sand face
	float edge_breakup = gnoise(v_world_pos.xz * 4.8) * 0.14 + gnoise(v_world_pos.xz * 16.0) * 0.08;
	float lip_mask = smoothstep(0.18, 0.62, w_lip + edge_breakup);
	float turf_mask = smoothstep(0.18, 0.62, w_turf + edge_breakup * 0.6);

	vec3 final_col = mix(col_sand, col_lip, lip_mask * 0.60);
	final_col = mix(final_col, col_turf, turf_mask);

	// Subtle dark root-shadow under the grass overhang
	float soil_line = lip_mask * (1.0 - turf_mask) * smoothstep(0.3, 0.9, w_lip);
	final_col *= 1.0 - soil_line * 0.22;

	// Undercut shadow cavity where overhanging grass meets steep sand wall
	float lip_sand_crevice = clamp(w_sand * w_lip * 4.0, 0.0, 1.0);
	final_col *= (1.0 - lip_sand_crevice * 0.30);

	vec3 final_n = normalize(mix(mix(n_sand, n_lip, lip_mask), n_turf, turf_mask));

	ALBEDO = clamp(final_col, 0.0, 1.0);
	ALPHA = clamp(v_vert_color.a, 0.0, 1.0);
	if (ALPHA < 0.01) {
		discard;
	}
	NORMAL_MAP = final_n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.25;
	ROUGHNESS = mix(mix(0.88, 0.98, lip_mask), 0.90, turf_mask);
	SPECULAR = mix(0.10, 0.02, lip_mask + turf_mask);
	AO = clamp(1.0 - lip_mask * 0.45 - lip_sand_crevice * 0.50, 0.25, 1.0);
	AO_LIGHT_AFFECT = 0.55;
}
