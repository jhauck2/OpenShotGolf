shader_type spatial;

// ============================================================================
// Terrain Splat-Map Shader (Refined Clean PBR & Slope Shading)
// Blends 5 surface textures based on an RGBA splat map for a unified golf
// course terrain mesh with clean normal mapping, smooth ambient occlusion,
// natural transitions, and clear elevation slope shading.
//
// Splat map channels:
//   R = green weight
//   G = fairway/tee weight
//   B = bunker weight
//   A = mulch weight
//   Rough = 1 - R - G - B - A (implicit, covers everything else)
// ============================================================================

// -- Splat map & Macro Terrain AO --
uniform sampler2D splat_map : filter_linear, repeat_disable;
uniform sampler2D terrain_ao_map : hint_default_white, filter_linear, repeat_disable;
uniform sampler2D deep_rough_map : hint_default_black, filter_linear, repeat_disable;
uniform bool has_deep_rough_map = false;

// -- Surface albedo textures --
uniform sampler2D tex_rough   : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_green   : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_fairway : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_bunker  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_mulch   : source_color, filter_linear_mipmap, repeat_enable;

// -- Normal maps --
uniform sampler2D normal_rough   : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_green   : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_fairway : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_bunker  : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_mulch   : hint_normal, filter_linear_mipmap, repeat_enable;

// -- Ambient Occlusion (AO) maps --
uniform sampler2D ao_rough   : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_green   : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_fairway : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_bunker  : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_mulch   : hint_default_white, filter_linear_mipmap, repeat_enable;

// -- Roughness maps --
uniform sampler2D roughness_tex_rough   : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex_green   : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex_fairway : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex_bunker  : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex_mulch   : hint_default_white, filter_linear_mipmap, repeat_enable;

// -- Height maps (for height-blended splat transitions) --
uniform sampler2D height_rough   : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_green   : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_fairway : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_bunker  : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_mulch   : hint_default_white, filter_linear_mipmap, repeat_enable;

// -- UV tiling scales per surface type --
uniform float uv_scale_rough   : hint_range(0.01, 1.0) = 0.1;
uniform float uv_scale_green   : hint_range(0.01, 1.0) = 0.15;
uniform float uv_scale_fairway : hint_range(0.01, 1.0) = 0.12;
uniform float uv_scale_bunker  : hint_range(0.01, 1.0) = 0.17;
uniform float uv_scale_mulch   : hint_range(0.01, 1.0) = 0.15;

// -- Per-surface base roughness (Tuned for balanced, non-glare response) --
uniform float roughness_rough   : hint_range(0.0, 1.0) = 0.95; // Natural diffuse rough grass
uniform float roughness_green   : hint_range(0.0, 1.0) = 0.90; // Smooth manicured green (zero glare)
uniform float roughness_fairway : hint_range(0.0, 1.0) = 0.90; // Natural fairway
uniform float roughness_bunker  : hint_range(0.0, 1.0) = 0.98; // Matte diffuse dry sand
uniform float roughness_mulch   : hint_range(0.0, 1.0) = 0.95; // Matte organic mulch

// -- Normal map strength per surface --
uniform float normal_depth : hint_range(0.0, 2.0) = 0.65;

// -- Slope & Lighting Readability --
uniform vec3 sun_direction = vec3(-0.45, -0.75, -0.45);
uniform float slope_shading_strength : hint_range(0.0, 1.0) = 0.25;
uniform float height_blend_contrast : hint_range(0.0, 1.0) = 0.20;
uniform vec3 active_hole_pos = vec3(0.0, -9999.0, 0.0);
uniform float active_hole_radius = 0.054;

// Base UV scale applied by the mesh generator.
const float BASE_UV_SCALE = 0.1;

varying vec3 v_world_normal;
varying vec3 v_world_pos;

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (active_hole_pos.y > -1000.0) {
		vec2 hole_delta = v_world_pos.xz - active_hole_pos.xz;
		if (dot(hole_delta, hole_delta) < active_hole_radius * active_hole_radius) {
			discard;
		}
	}
	// -----------------------------------------------------------------------
	// 1. Sample the splat map using UV2 (normalized [0,1] course bounds).
	//    Aligned with gameplay boundaries (1.50m fringe = splat.r 0.50, bunker = splat.b 0.50).
	// -----------------------------------------------------------------------
	vec4 raw_sample = texture(splat_map, UV2);
	float splat_green_raw = raw_sample.r;
	vec4 splat = vec4(
		smoothstep(0.44, 0.58, raw_sample.r),
		smoothstep(0.78, 0.94, raw_sample.g),
		smoothstep(0.42, 0.58, raw_sample.b),
		raw_sample.a);

	float raw_green   = splat.r;
	float raw_fairway = splat.g;
	float raw_bunker  = splat.b;
	float raw_mulch   = splat.a;
	float raw_rough   = clamp(1.0 - raw_green - raw_fairway - raw_bunker - raw_mulch, 0.0, 1.0);

	// UV coordinates per surface
	vec2 uv_rough   = UV * (uv_scale_rough   / BASE_UV_SCALE);
	vec2 uv_green   = UV * (uv_scale_green   / BASE_UV_SCALE);
	vec2 uv_fairway = UV * (uv_scale_fairway / BASE_UV_SCALE);
	vec2 uv_bunker  = UV * (uv_scale_bunker  / BASE_UV_SCALE);
	vec2 uv_mulch   = UV * (uv_scale_mulch   / BASE_UV_SCALE);

	// -----------------------------------------------------------------------
	// 2. Height-Blended Splat Weight Adjustment (Only sampled at zone borders!)
	// -----------------------------------------------------------------------
	float in_transition = smoothstep(0.02, 0.30, raw_rough)   * (1.0 - smoothstep(0.70, 0.98, raw_rough))
	                    + smoothstep(0.02, 0.30, raw_fairway) * (1.0 - smoothstep(0.70, 0.98, raw_fairway))
	                    + smoothstep(0.02, 0.30, raw_green)   * (1.0 - smoothstep(0.70, 0.98, raw_green));
	in_transition = clamp(in_transition, 0.0, 1.0) * height_blend_contrast;

	float adj_rough   = raw_rough;
	float adj_green   = raw_green;
	float adj_fairway = raw_fairway;
	float adj_bunker  = raw_bunker;
	float adj_mulch   = raw_mulch;

	if (in_transition > 0.005) {
		float h_r = raw_rough   > 0.005 ? texture(height_rough,   uv_rough).r   : 0.5;
		float h_g = raw_green   > 0.005 ? texture(height_green,   uv_green).r   : 0.5;
		float h_f = raw_fairway > 0.005 ? texture(height_fairway, uv_fairway).r : 0.5;
		float h_b = raw_bunker  > 0.005 ? texture(height_bunker,  uv_bunker).r  : 0.5;
		float h_m = raw_mulch   > 0.005 ? texture(height_mulch,   uv_mulch).r   : 0.5;

		adj_rough   = max(raw_rough   + (h_r - 0.5) * in_transition * raw_rough,   0.0);
		adj_green   = max(raw_green   + (h_g - 0.5) * in_transition * raw_green,   0.0);
		adj_fairway = max(raw_fairway + (h_f - 0.5) * in_transition * raw_fairway, 0.0);
		adj_bunker  = max(raw_bunker  + (h_b - 0.5) * in_transition * raw_bunker,  0.0);
		adj_mulch   = max(raw_mulch   + (h_m - 0.5) * in_transition * raw_mulch,   0.0);
	}

	// Priority hierarchy: Bunker > Green > Fairway/Mulch > Rough
	float base_w = adj_green + adj_bunker + adj_mulch;
	if (base_w > 1.0) {
		adj_green  /= base_w;
		adj_bunker /= base_w;
		adj_mulch  /= base_w;
	}
	float fairway_w = adj_fairway * clamp(1.0 - adj_green - adj_bunker - adj_mulch, 0.0, 1.0);
	float green_w   = adj_green;
	float bunker_w  = adj_bunker;
	float mulch_w   = adj_mulch;
	float rough_w   = clamp(1.0 - green_w - fairway_w - bunker_w - mulch_w, 0.0, 1.0);

	float total_w = rough_w + green_w + fairway_w + bunker_w + mulch_w;
	if (total_w > 0.0001) {
		rough_w   /= total_w;
		green_w   /= total_w;
		fairway_w /= total_w;
		bunker_w  /= total_w;
		mulch_w   /= total_w;
	}

	// -----------------------------------------------------------------------
	// 3. Weight-Culled Surface Sampling (Skips inactive layers completely!)
	// -----------------------------------------------------------------------
	vec3 blended_albedo = vec3(0.0);
	vec3 blended_normal = vec3(0.0);
	float blended_roughness = 0.0;
	float blended_ao = 0.0;

	if (rough_w > 0.005) {
		vec3 col_rough = texture(tex_rough, uv_rough).rgb * vec3(0.84, 0.98, 0.80);
		vec3 nr_rough = mix(vec3(0.0, 0.0, 1.0), texture(normal_rough, uv_rough).rgb * 2.0 - 1.0, 0.42);
		float luma_r = dot(col_rough, vec3(0.299, 0.587, 0.114));
		float ao_r = clamp(0.84 + luma_r * 0.35, 0.75, 1.0);
		if (has_deep_rough_map) {
			float dr = smoothstep(0.25, 0.75, texture(deep_rough_map, UV2).r) * smoothstep(0.04, 0.28, rough_w);
			if (dr > 0.01) {
				vec3 r_layer2 = texture(tex_rough, uv_rough * 1.9 + vec2(0.27, 0.43)).rgb;
				float tuft = sin(v_world_pos.x * 11.0 + v_world_pos.z * 7.0) * cos(v_world_pos.x * 8.0 - v_world_pos.z * 13.0) * 0.5 + 0.5;
				vec3 col_deep = mix(r_layer2 * vec3(0.78, 0.96, 0.72), col_rough * vec3(0.92, 1.06, 0.84), tuft);
				float cut_lip = smoothstep(0.05, 0.45, dr) * (1.0 - smoothstep(0.50, 0.95, dr));
				col_deep *= mix(1.0, 0.90, cut_lip);
				col_rough = mix(col_rough, col_deep, dr);
				nr_rough = normalize(mix(nr_rough, texture(normal_rough, uv_rough * 1.8).rgb * 2.0 - 1.0, dr * 0.50));
				ao_r = mix(ao_r, mix(0.75, 0.98, tuft) * mix(1.0, 0.88, cut_lip), dr);
			}
		}
		blended_albedo += col_rough * rough_w;
		blended_normal += nr_rough * rough_w;
		blended_roughness += clamp(roughness_rough - (luma_r - 0.35) * 0.08, 0.78, 0.98) * rough_w;
		blended_ao += ao_r * rough_w;
	}

	if (fairway_w > 0.005) {
		vec3 col_fairway = texture(tex_fairway, uv_fairway).rgb;
		float stripe_val = smoothstep(0.28, 0.72, sin((v_world_pos.x * 0.707 + v_world_pos.z * 0.707) * 0.90) * 0.5 + 0.5);
		vec3 vibrant_fairway = mix(col_fairway * 0.93, col_fairway * 1.06, stripe_val) * vec3(0.95, 1.08, 0.86);
		float fairway_fringe = smoothstep(0.02, 0.35, fairway_w) * (1.0 - smoothstep(0.65, 0.98, fairway_w));
		col_fairway = mix(vibrant_fairway, vibrant_fairway * vec3(0.86, 0.93, 0.84), fairway_fringe * 0.55);

		vec3 nr_fairway = mix(vec3(0.0, 0.0, 1.0), texture(normal_fairway, uv_fairway).rgb * 2.0 - 1.0, 0.30);
		blended_albedo += clamp(col_fairway, 0.0, 1.0) * fairway_w;
		blended_normal += nr_fairway * fairway_w;
		blended_roughness += (roughness_fairway + (stripe_val - 0.5) * 0.04) * fairway_w;
		blended_ao += 0.96 * fairway_w;
	}

	if (green_w > 0.005) {
		vec3 col_green = texture(tex_green, uv_green).rgb * vec3(0.96, 1.12, 0.90);
		float green_stripe = smoothstep(0.32, 0.68, sin((v_world_pos.x * 0.866 - v_world_pos.z * 0.5) * 1.8) * 0.5 + 0.5);
		col_green = mix(col_green * 0.97, col_green * 1.03, green_stripe);
		float fringe_w = smoothstep(0.985, 0.91, splat_green_raw) * green_w;
		vec3 green_output = mix(col_green, col_green * vec3(0.84, 0.92, 0.80), fringe_w);

		vec3 nr_green = mix(vec3(0.0, 0.0, 1.0), texture(normal_green, uv_green).rgb * 2.0 - 1.0, 0.16);
		blended_albedo += clamp(green_output, 0.0, 1.0) * green_w;
		blended_normal += nr_green * green_w;
		blended_roughness += roughness_green * green_w;
		blended_ao += 0.98 * green_w;
	}

	if (bunker_w > 0.005) {
		vec3 col_bunker = texture(tex_bunker, uv_bunker).rgb * vec3(1.06, 0.99, 0.87);
		float curve_warp = sin(v_world_pos.x * 0.35 + cos(v_world_pos.z * 0.35)) * 4.5;
		float rake_angle = dot(v_world_pos.xz, vec2(0.707, -0.707)) * 36.0 + curve_warp;
		float rake_wave = sin(rake_angle) * 0.5 + 0.5;
		col_bunker *= mix(0.975, 1.025, rake_wave);

		float green_contact = smoothstep(0.02, 0.45, raw_green);
		float bunker_edge = smoothstep(0.015, 0.38, bunker_w) * (1.0 - smoothstep(0.30, 0.82, bunker_w));
		bunker_edge = max(bunker_edge, smoothstep(0.01, 0.35, bunker_w) * green_contact * (1.0 - smoothstep(0.40, 0.88, bunker_w)));
		vec3 soil_color = vec3(0.42, 0.28, 0.16) * (0.88 + 0.24 * sin(UV.x * 2.0));
		col_bunker = mix(col_bunker, soil_color, bunker_edge * 0.35);

		float rake_dist_fade = 1.0 - smoothstep(10.0, 42.0, length(VERTEX));
		vec3 nr_bunker = texture(normal_bunker, uv_bunker).rgb * 2.0 - 1.0;
		vec2 rake_tangent = vec2(cos(rake_angle), sin(rake_angle)) * 0.12 * rake_dist_fade;
		nr_bunker = normalize(vec3(nr_bunker.xy + rake_tangent, max(nr_bunker.z, 0.78)));

		blended_albedo += clamp(col_bunker, 0.0, 1.0) * bunker_w;
		blended_normal += nr_bunker * bunker_w;
		blended_roughness += mix(roughness_bunker, 0.95, bunker_edge) * bunker_w;
		blended_ao += (1.0 - smoothstep(0.10, 0.90, bunker_w) * 0.18) * bunker_w;
	}

	if (mulch_w > 0.005) {
		vec3 col_mulch = texture(tex_mulch, uv_mulch).rgb * 0.88;
		vec3 nr_mulch = texture(normal_mulch, uv_mulch).rgb * 2.0 - 1.0;
		blended_albedo += col_mulch * mulch_w;
		blended_normal += nr_mulch * mulch_w;
		blended_roughness += roughness_mulch * mulch_w;
		blended_ao += 0.86 * mulch_w;
	}

	// -----------------------------------------------------------------------
	// 4. Clean Elevation Slope Shading & Macro AO
	// -----------------------------------------------------------------------
	vec3 wn = normalize(v_world_normal);
	float slope_grade = length(wn.xz);
	float slope_intensity = clamp(slope_grade * 6.0, 0.0, 1.0);

	vec3 light_dir = normalize(-sun_direction);
	float NdotL = dot(wn, light_dir);
	float relief_diff = (NdotL - light_dir.y) * 2.1;
	float relief_factor = 1.0 + (relief_diff * slope_shading_strength);
	float bank_darkening = 1.0 - (slope_intensity * 0.30 * slope_shading_strength);

	blended_albedo *= clamp(relief_factor * bank_darkening, 0.35, 1.30);

	ALBEDO = clamp(blended_albedo, 0.0, 1.0);
	ROUGHNESS = clamp(blended_roughness, 0.5, 1.0);
	NORMAL_MAP = normalize(max(length(blended_normal), 0.001) > 0.002 ? blended_normal : vec3(0.0, 0.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;

	float macro_terrain_ao = mix(1.0, texture(terrain_ao_map, UV2).r, 0.45);
	AO = clamp(blended_ao * macro_terrain_ao, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.18;
	SPECULAR = 0.02;
}

