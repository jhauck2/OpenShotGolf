shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ============================================================================
// Photorealistic High-Definition Terrain Splat Shader (High Graphics Mode)
// Features:
// - Authentic championship golf course green turf grading (modeled on Bay Hill & Moon Bay)
// - Bold anisotropic alternating mower striping responsive to camera and sun angles
// - Velvet-smooth manicured green with subtle cross-cut grid (zero NaNs, no black holes)
// - Pinehurst-style organic bunker lips with exposed dark soil under-ledge & raked sand
// - Close-range (< 12m) procedural grass blade fiber definition at player address
// - Stable, balanced PBR normal mapping and subsurface sunlit grass glow
// ============================================================================

// -- Splat map & Macro Terrain AO --
uniform sampler2D splat_map : filter_linear, repeat_disable;
uniform sampler2D terrain_ao_map : hint_default_white, filter_linear, repeat_disable;
uniform sampler2D deep_rough_map : hint_default_black, filter_linear, repeat_disable;
uniform bool has_deep_rough_map = false;

// -- Surface albedo textures --
uniform sampler2D tex_rough   : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_green   : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_fairway : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_bunker  : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_mulch   : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// -- Normal maps --
uniform sampler2D normal_rough   : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_green   : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_fairway : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_bunker  : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_mulch   : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

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

// -- UV tiling scales per surface type (Tuned for high-resolution turf detail at golfer scale) --
uniform float uv_scale_rough   : hint_range(0.01, 1.0) = 0.38;
uniform float uv_scale_green   : hint_range(0.01, 1.0) = 0.50;
uniform float uv_scale_fairway : hint_range(0.01, 1.0) = 0.44;
uniform float uv_scale_bunker  : hint_range(0.01, 1.0) = 0.42;
uniform float uv_scale_mulch   : hint_range(0.01, 1.0) = 0.38;

// -- Per-surface base roughness --
uniform float roughness_rough   : hint_range(0.0, 1.0) = 0.94;
uniform float roughness_green   : hint_range(0.0, 1.0) = 0.84;
uniform float roughness_fairway : hint_range(0.0, 1.0) = 0.88;
uniform float roughness_bunker  : hint_range(0.0, 1.0) = 0.96;
uniform float roughness_mulch   : hint_range(0.0, 1.0) = 0.95;

// -- Normal map strength per surface --
uniform float normal_depth : hint_range(0.0, 2.0) = 0.85;

// -- Slope, Hole Mow Alignment & Tee Divot Readability --
uniform vec3 sun_direction = vec3(-0.45, -0.75, -0.45);
uniform float slope_shading_strength : hint_range(0.0, 1.0) = 0.22;
uniform float height_blend_contrast : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hole_mow_direction = vec2(0.707, 0.707);
uniform vec3 active_tee_pos = vec3(0.0, -9999.0, 0.0);
uniform vec3 active_hole_pos = vec3(0.0, -9999.0, 0.0);
uniform float active_hole_radius = 0.054;

const float BASE_UV_SCALE = 0.1;

varying vec3 v_world_normal;
varying vec3 v_world_pos;
varying vec3 v_cam_pos;

void vertex() {
	// Ground stays flush with collision; the elevated grass is real blade geometry (DeepRoughBladesMultiMesh)
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cam_pos = INV_VIEW_MATRIX[3].xyz;
}

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

// Breaks visible texture tiling by blending a rotated, offset second sample using low-frequency noise
vec3 sample_notile(sampler2D tex, vec2 uv, vec2 wp) {
	vec3 a = texture(tex, uv).rgb;
	vec2 ruv = vec2(uv.x * 0.8660 - uv.y * 0.5, uv.x * 0.5 + uv.y * 0.8660) * 0.73 + vec2(0.31, 0.57);
	vec3 b = texture(tex, ruv).rgb;
	float m = smoothstep(0.30, 0.70, gnoise(wp * 0.09) * 0.5 + 0.5);
	return mix(a, b, m);
}

// Multi-octave fine grain used in place of geometric grass blades
float turf_grain(vec2 wp) {
	return gnoise(wp * 38.0) * 0.5 + gnoise(wp * 91.0) * 0.3 + gnoise(wp * 7.0) * 0.2;
}

void fragment() {
	if (active_hole_pos.y > -1000.0) {
		vec2 hole_delta = v_world_pos.xz - active_hole_pos.xz;
		if (dot(hole_delta, hole_delta) < active_hole_radius * active_hole_radius) {
			discard;
		}
	}
	float cam_dist = distance(v_world_pos, v_cam_pos);
	float near_detail_fade = 1.0 - smoothstep(25.0, 55.0, cam_dist);
	float close_blade_fade = 1.0 - smoothstep(8.0, 18.0, cam_dist);

	// -----------------------------------------------------------------------
	// 1. Splat Sampling: tight 3x3 anti-aliasing for turf + unblurred direct
	//    sampling for bunkers so visual zone edges align 1:1 with gameplay.
	//    (With 3.0m baked blendRadius, splat.r == 0.50 is exact 1.50m fringe edge.)
	// -----------------------------------------------------------------------
	vec2 splat_texel = 1.0 / vec2(textureSize(splat_map, 0));
	vec4 direct_splat = texture(splat_map, UV2);
	vec4 aa_splat = vec4(0.0);
	float tap_w_sum = 0.0;
	for (int sx = -1; sx <= 1; sx++) {
		for (int sy = -1; sy <= 1; sy++) {
			vec2 o = vec2(float(sx), float(sy));
			float tw = exp(-dot(o, o) * 0.75);
			aa_splat += texture(splat_map, UV2 + o * splat_texel * 0.45) * tw;
			tap_w_sum += tw;
		}
	}
	aa_splat /= tap_w_sum;
	float splat_green_raw = aa_splat.r;
	// Re-sharpen weights at exact gameplay zone boundaries:
	//   - Green + Fringe outer edge at splat.r == 0.50 (1.50m outside green polygon)
	//   - Fairway outer edge tightly hugging the fairway polygon
	//   - Bunker edge unblurred at direct_splat.b == 0.50 (exact bunker polygon)
	vec4 splat = vec4(
		smoothstep(0.44, 0.58, aa_splat.r),
		smoothstep(0.78, 0.94, aa_splat.g),
		smoothstep(0.42, 0.58, direct_splat.b),
		smoothstep(0.30, 0.70, aa_splat.a));

	float raw_green   = splat.r;
	float raw_fairway = splat.g;
	float raw_bunker  = splat.b;
	float raw_mulch   = splat.a;
	float raw_rough   = clamp(1.0 - raw_green - raw_fairway - raw_bunker - raw_mulch, 0.0, 1.0);

	vec2 uv_rough   = UV * (uv_scale_rough   / BASE_UV_SCALE);
	vec2 uv_green   = UV * (uv_scale_green   / BASE_UV_SCALE);
	vec2 uv_fairway = UV * (uv_scale_fairway / BASE_UV_SCALE);
	vec2 uv_bunker  = UV * (uv_scale_bunker  / BASE_UV_SCALE);
	vec2 uv_mulch   = UV * (uv_scale_mulch   / BASE_UV_SCALE);

	// -----------------------------------------------------------------------
	// 2. Height-Blended Splat Weights (Only sampled in active transition zones)
	// -----------------------------------------------------------------------
	float in_transition = smoothstep(0.02, 0.30, raw_rough)   * (1.0 - smoothstep(0.70, 0.98, raw_rough))
	                    + smoothstep(0.02, 0.30, raw_fairway) * (1.0 - smoothstep(0.70, 0.98, raw_fairway))
	                    + smoothstep(0.02, 0.30, raw_green)   * (1.0 - smoothstep(0.70, 0.98, raw_green))
	                    + smoothstep(0.02, 0.30, raw_bunker)  * (1.0 - smoothstep(0.70, 0.98, raw_bunker));
	in_transition = clamp(in_transition, 0.0, 1.0) * height_blend_contrast;

	float adj_rough   = raw_rough;
	float adj_green   = raw_green;
	float adj_fairway = raw_fairway;
	float adj_bunker  = raw_bunker;
	float adj_mulch   = raw_mulch;

	if (in_transition > 0.005 && near_detail_fade > 0.05) {
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

	// Macro organic moisture & soil fertility variation across the course
	float macro_mottle = gnoise(v_world_pos.xz * 0.032) * 0.5 + 0.5;
	vec3 macro_turf_tint = mix(vec3(0.95, 0.96, 0.91), vec3(1.04, 1.05, 1.01), macro_mottle);

	vec3 blended_albedo = vec3(0.0);
	vec3 blended_normal = vec3(0.0);
	float blended_roughness = 0.0;
	float blended_ao = 0.0;

	vec2 mow_dir = length(hole_mow_direction) > 0.01 ? normalize(hole_mow_direction) : normalize(vec2(0.707, 0.707));
	vec2 mow_perp = vec2(-mow_dir.y, mow_dir.x);
	vec3 view_dir = normalize(v_world_pos - v_cam_pos);

	// -----------------------------------------------------------------------
	// 3A. ROUGH: Lush green rough + Elevated 3D-textured Deep Rough (>= 25% lie resistance)
	// -----------------------------------------------------------------------
	if (rough_w > 0.005) {
		vec3 r_fine = sample_notile(tex_rough, uv_rough, v_world_pos.xz);
		vec3 r_base = r_fine;
		if (near_detail_fade > 0.05) {
			vec3 r_broad = texture(tex_rough, uv_rough * 0.41 + vec2(0.37, 0.71)).rgb;
			r_base = mix(r_fine, r_broad, 0.30 * near_detail_fade);
		}
		// Lush parkland green rough (zero yellow/straw discoloration)
		float clump_patch = gnoise(v_world_pos.xz * 0.28);
		vec3 rough_tint = mix(vec3(0.72, 0.94, 0.68), vec3(0.84, 1.02, 0.76), clump_patch * 0.5 + 0.5);
		vec3 col_rough = r_base * rough_tint * macro_turf_tint;

		// Subtle broad mowing / contour bands visible across the rough
		float rough_stripe_coord = dot(v_world_pos.xz, mow_perp) * 0.55;
		float rough_stripe = smoothstep(0.30, 0.70, sin(rough_stripe_coord) * 0.5 + 0.5);
		col_rough *= mix(0.92, 1.06, rough_stripe);

		float clump_dark = smoothstep(0.15, 0.65, gnoise(v_world_pos.xz * 1.6));
		col_rough *= mix(1.0, 0.84, clump_dark * 0.40);

		// Fine grain stands in for individual blades at close range
		float grain_r = turf_grain(v_world_pos.xz) * close_blade_fade;
		col_rough *= 1.0 + grain_r * 0.30;

		vec3 nr_rough = texture(normal_rough, uv_rough).rgb * 2.0 - 1.0;
		nr_rough = mix(vec3(0.0, 0.0, 1.0), nr_rough, 0.55);
		float luma_r = dot(r_base, vec3(0.299, 0.587, 0.114));
		float ao_r = clamp(0.78 + luma_r * 0.42, 0.70, 1.0);
		float rough_r = clamp(roughness_rough - clump_patch * 0.05, 0.80, 0.98);

		// Elevated Thick Rough Grass Texture wherever ball lie resistance >= 25%
		if (has_deep_rough_map) {
			float raw_dr = texture(deep_rough_map, UV2).r;
			if (raw_dr > 0.01) {
				// Feathered grassy cut-edge border between <25% intermediate rough and >=25% deep rough
				float edge_tuft = gnoise(v_world_pos.xz * 2.8) * 0.5 + gnoise(v_world_pos.xz * 7.5) * 0.5;
				float deep_rough_w = smoothstep(0.28, 0.72, raw_dr + edge_tuft * 0.22 * raw_dr * (1.0 - raw_dr));
				deep_rough_w *= smoothstep(0.04, 0.28, rough_w);

				// 3-layer parallax/relief thick grass blade canopy
				vec2 para_step = (view_dir.xz / max(abs(view_dir.y), 0.28)) * 0.018;
				vec2 wp0 = v_world_pos.xz;
				vec2 wp1 = v_world_pos.xz + para_step * 0.5;
				vec2 wp2 = v_world_pos.xz + para_step;

				float tuft_l0 = gnoise(wp0 * 6.5) * 0.5 + 0.5;
				float tuft_l1 = gnoise(wp1 * 14.5 + vec2(4.7, 9.2)) * 0.5 + 0.5;
				float tuft_l2 = gnoise(wp2 * 31.0 + vec2(13.1, 2.8)) * 0.5 + 0.5;
				float blade_fibers = gnoise(wp2 * 58.0) * 0.5 + 0.5;

				vec3 tex_layer1 = texture(tex_rough, uv_rough * 1.35 + para_step * 0.25).rgb;
				vec3 tex_layer2 = texture(tex_rough, uv_rough * 2.10 + para_step * 0.55 + vec2(0.23, 0.41)).rgb;

				// Rich dark-green thatch crevices -> dense lush forest-green mid-blades -> sunlit green tips
				float canopy_h = clamp(tuft_l0 * 0.30 + tuft_l1 * 0.42 + tuft_l2 * 0.28, 0.0, 1.0);
				float tip_mask = smoothstep(0.46, 0.78, canopy_h + (blade_fibers - 0.5) * 0.22);
				float thatch_pocket = 1.0 - smoothstep(0.22, 0.52, canopy_h);

				vec3 deep_thatch_col = vec3(0.16, 0.26, 0.10);
				vec3 mid_blade_col   = mix(tex_layer1, tex_layer2, 0.5) * vec3(0.84, 1.02, 0.76);
				vec3 blade_tip_col   = mix(tex_layer2, r_base, 0.4) * vec3(0.96, 1.12, 0.82);

				vec3 col_deep = mix(mid_blade_col, deep_thatch_col, thatch_pocket * 0.45);
				col_deep = mix(col_deep, blade_tip_col, tip_mask * 0.65);
				col_deep *= macro_turf_tint * mix(0.93, 1.07, rough_stripe);

				// Raised mown step-up lip shadow and 3D bevel normal at the 25% transition cut
				float cut_lip = smoothstep(0.04, 0.42, deep_rough_w) * (1.0 - smoothstep(0.48, 0.94, deep_rough_w));
				col_deep *= mix(1.0, 0.90, cut_lip);

				vec2 dr_texel = 1.5 / vec2(max(textureSize(deep_rough_map, 0), ivec2(1)));
				float dr_x = texture(deep_rough_map, UV2 + vec2(dr_texel.x, 0.0)).r - texture(deep_rough_map, UV2 - vec2(dr_texel.x, 0.0)).r;
				float dr_z = texture(deep_rough_map, UV2 + vec2(0.0, dr_texel.y)).r - texture(deep_rough_map, UV2 - vec2(0.0, dr_texel.y)).r;

				// High-relief 3D blade tuft normals + cut-edge step bevel
				float dh_x = gnoise((wp2 + vec2(0.03, 0.0)) * 22.0) - gnoise((wp2 - vec2(0.03, 0.0)) * 22.0);
				float dh_z = gnoise((wp2 + vec2(0.0, 0.03)) * 22.0) - gnoise((wp2 - vec2(0.0, 0.03)) * 22.0);
				vec3 nr_tuft = normalize(vec3(nr_rough.x + dh_x * 0.35 - dr_x * 1.2 * cut_lip, nr_rough.y + dh_z * 0.35 - dr_z * 1.2 * cut_lip, max(nr_rough.z, 0.80)));

				float ao_deep = clamp(mix(0.74, 1.0, canopy_h) * mix(1.0, 0.88, cut_lip), 0.70, 1.0);

				col_rough = mix(col_rough, col_deep, deep_rough_w);
				nr_rough = normalize(mix(nr_rough, nr_tuft, deep_rough_w));
				ao_r = mix(ao_r, ao_deep, deep_rough_w);
				rough_r = mix(rough_r, 0.92, deep_rough_w);
			}
		}

		blended_albedo += col_rough * rough_w;
		blended_normal += nr_rough * rough_w;
		blended_roughness += rough_r * rough_w;
		blended_ao += ao_r * rough_w;
	}

	// -----------------------------------------------------------------------
	// 3B. FAIRWAY & TEE: Hole-aligned mower stripes, first-cut collar, & tee divot scars
	// -----------------------------------------------------------------------
	if (fairway_w > 0.005) {
		vec3 f_fine = sample_notile(tex_fairway, uv_fairway, v_world_pos.xz);
		vec3 col_f = f_fine;
		if (near_detail_fade > 0.05) {
			vec3 f_broad = texture(tex_fairway, uv_fairway * 0.39 + vec2(0.53, 0.29)).rgb;
			col_f = mix(f_fine, f_broad, 0.25 * near_detail_fade);
		}

		// Broad (~5m) alternating mower stripes, crisp edges, plus subtle cross-band
		float stripe_along = dot(v_world_pos.xz, mow_perp) * 0.62;
		float stripe_cross = dot(v_world_pos.xz, mow_dir) * 0.52;
		float stripe_val = smoothstep(0.38, 0.62, sin(stripe_along) * 0.5 + 0.5);
		float cross_val  = smoothstep(0.25, 0.75, sin(stripe_cross) * 0.5 + 0.5);
		float combined_stripe = mix(stripe_val, stripe_val * 0.8 + cross_val * 0.2, 0.25);

		// Light bands lean warm lime-green, dark bands lean deep emerald (grass bent toward/away from sun)
		vec3 stripe_light = vec3(1.10, 1.14, 0.80);
		vec3 stripe_dark  = vec3(0.78, 0.96, 0.78);
		vec3 col_fairway = col_f * vec3(0.92, 1.06, 0.82) * mix(stripe_dark, stripe_light, combined_stripe) * macro_turf_tint;

		// Fine mown-turf grain (replaces geometric blades)
		float grain_f = turf_grain(v_world_pos.xz) * close_blade_fade;
		col_fairway *= 1.0 + grain_f * 0.16;

		// Anisotropic mower nap sheen relative to camera gaze
		float view_grain = dot(view_dir.xz, mow_dir);
		col_fairway *= (1.0 + (combined_stripe - 0.5) * 0.14 * (0.5 + 0.5 * view_grain));

		// First-cut intermediate rough collar border framing the fairway/tee
		float first_cut_w = smoothstep(0.01, 0.20, fairway_w) * (1.0 - smoothstep(0.28, 0.65, fairway_w));
		vec3 col_first_cut = col_fairway * vec3(0.76, 0.86, 0.72);
		col_fairway = mix(col_fairway, col_first_cut, first_cut_w * 0.65);

		vec3 nr_fairway = mix(vec3(0.0, 0.0, 1.0), texture(normal_fairway, uv_fairway).rgb * 2.0 - 1.0, 0.35);
		float rt_f = roughness_fairway + (combined_stripe - 0.5) * 0.04;
		float ao_f = 0.94;

		// Procedural Tee-Box Divot Scars (seen in reference video at 6:55 around golfer address)
		if (active_tee_pos.y > -1000.0) {
			vec2 tee_delta = v_world_pos.xz - active_tee_pos.xz;
			// Local tee coordinates aligned with hole direction
			vec2 tee_local = vec2(dot(tee_delta, mow_dir), dot(tee_delta, mow_perp));
			float tee_zone = (1.0 - smoothstep(1.2, 3.2, abs(tee_local.x)))
			               * (1.0 - smoothstep(1.8, 4.2, abs(tee_local.y)))
			               * (1.0 - smoothstep(0.18, 0.45, length(tee_delta))); // Keep ball spot clean
			if (tee_zone > 0.01) {
				// Elongated turf divot strips aligned with swing direction (mow_dir)
				vec2 divot_cell = vec2(tee_local.x * 2.8, tee_local.y * 9.5);
				float divot_n = gnoise(divot_cell) * 0.6 + gnoise(divot_cell * 2.3 + vec2(5.2, 9.1)) * 0.4;
				float divot_mask = smoothstep(0.28, 0.52, divot_n) * tee_zone;
				vec3 divot_soil = mix(vec3(0.34, 0.28, 0.20), vec3(0.56, 0.50, 0.38), gnoise(v_world_pos.xz * 18.0) * 0.5 + 0.5);
				col_fairway = mix(col_fairway, divot_soil, divot_mask * 0.78);
				nr_fairway = normalize(mix(nr_fairway, vec3(0.0, -0.35, 0.93), divot_mask));
				rt_f = mix(rt_f, 0.96, divot_mask);
				ao_f = mix(ao_f, 0.72, divot_mask);
			}
		}

		blended_albedo += clamp(col_fairway, 0.0, 1.0) * fairway_w;
		blended_normal += nr_fairway * fairway_w;
		blended_roughness += rt_f * fairway_w;
		blended_ao += ao_f * fairway_w;
	}

	// -----------------------------------------------------------------------
	// 3C. GREEN: Lighter, manicured bentgrass putting surface + distinct collar framing
	// -----------------------------------------------------------------------
	if (green_w > 0.005) {
		vec3 g_fine = texture(tex_green, uv_green).rgb;
		// Distinct vibrant bentgrass hue: lighter, high-vitality chartreuse-emerald matching reference
		vec3 col_green = g_fine * vec3(1.05, 1.32, 0.78);

		// Precision cross-cut tournament mowing pattern
		float cut_a = sin(dot(v_world_pos.xz, mow_dir) * 4.2) * 0.5 + 0.5;
		float cut_b = sin(dot(v_world_pos.xz, mow_perp) * 4.2) * 0.5 + 0.5;
		float green_grid = cut_a * cut_b;
		col_green *= mix(0.93, 1.07, green_grid);

		// Velvety sheen based on view angle and putting surface nap
		float view_sheen = abs(dot(view_dir.xz, mow_dir));
		col_green *= (1.0 + (view_sheen - 0.5) * 0.16);

		// Crisp distinctive putting green collar / fringe band framing the green perimeter
		// Pure putting green inside green polygon (splat_green_raw ~ 1.0), distinct fringe
		// collar from 0m..1.5m outside green polygon (splat_green_raw 0.985..0.50).
		float fringe_w = smoothstep(0.985, 0.91, splat_green_raw) * green_w;
		vec3 col_fringe = g_fine * vec3(0.68, 0.95, 0.58);
		vec3 green_output = mix(col_green, col_fringe, fringe_w * 0.85);

		// Very smooth, subtle normal map for manicured rolling green
		vec3 nr_green = mix(vec3(0.0, 0.0, 1.0), texture(normal_green, uv_green).rgb * 2.0 - 1.0, 0.08);
		blended_albedo += clamp(green_output, 0.0, 1.0) * green_w;
		blended_normal += nr_green * green_w;
		// Smooth bentgrass surface gives a soft, manicured sheen
		blended_roughness += clamp(roughness_green - 0.38, 0.38, 0.52) * green_w;
		blended_ao += 0.98 * green_w;
	}

	// -----------------------------------------------------------------------
	// 3D. BUNKER: Crisp silica sand + deep sod/soil under-lip shadow
	// -----------------------------------------------------------------------
	if (bunker_w > 0.005) {
		vec3 col_bunker = texture(tex_bunker, uv_bunker).rgb * vec3(1.06, 0.99, 0.87);
		float rake_angle = dot(v_world_pos.xz, vec2(0.707, -0.707)) * 36.0 + gnoise(v_world_pos.xz * 0.35) * 4.5;
		float rake_wave = sin(rake_angle) * 0.5 + 0.5;
		col_bunker = clamp(col_bunker * mix(0.975, 1.025, rake_wave), 0.0, 1.0);

		// Subtle natural turf-to-sand root transition along bunker edge
		float green_contact = smoothstep(0.02, 0.45, raw_green);
		float bunker_lip = smoothstep(0.015, 0.38, bunker_w) * (1.0 - smoothstep(0.30, 0.82, bunker_w));
		bunker_lip = max(bunker_lip, smoothstep(0.01, 0.35, bunker_w) * green_contact * (1.0 - smoothstep(0.40, 0.88, bunker_w)));
		float lip_noise = gnoise(v_world_pos.xz * 1.5) * 0.5 + 0.5;
		vec3 brown_soil = vec3(0.42, 0.28, 0.16) * (0.85 + 0.30 * lip_noise);
		col_bunker = mix(col_bunker, brown_soil, bunker_lip * 0.35);

		float rake_dist_fade = 1.0 - smoothstep(10.0, 42.0, length(VERTEX));
		vec3 nr_bunker = texture(normal_bunker, uv_bunker).rgb * 2.0 - 1.0;
		vec2 rake_tangent = vec2(cos(rake_angle), sin(rake_angle)) * 0.12 * rake_dist_fade;
		nr_bunker = normalize(vec3(nr_bunker.xy + rake_tangent, max(nr_bunker.z, 0.78)));

		blended_albedo += col_bunker * bunker_w;
		blended_normal += nr_bunker * bunker_w;
		blended_roughness += roughness_bunker * bunker_w;
		blended_ao += mix(0.95, 0.72, bunker_lip) * bunker_w;
	}

	// -----------------------------------------------------------------------
	// 3E. MULCH
	// -----------------------------------------------------------------------
	if (mulch_w > 0.005) {
		vec3 col_mulch = texture(tex_mulch, uv_mulch).rgb * 0.86;
		vec3 nr_mulch = texture(normal_mulch, uv_mulch).rgb * 2.0 - 1.0;
		blended_albedo += col_mulch * mulch_w;
		blended_normal += nr_mulch * mulch_w;
		blended_roughness += roughness_mulch * mulch_w;
		blended_ao += 0.85 * mulch_w;
	}

	// Mid-distance (to ~60m) turf micro-variation: keeps grass from reading as a smeared texture
	float grass_w_total = rough_w + fairway_w;
	if (grass_w_total > 0.01) {
		float mid_fade = 1.0 - smoothstep(18.0, 65.0, cam_dist);
		float mid_a = gnoise(v_world_pos.xz * 9.0);
		float mid_b = gnoise(v_world_pos.xz * 3.1 + vec2(11.0, 5.0));
		float amp = rough_w * 0.22 + fairway_w * 0.07;
		blended_albedo *= 1.0 + (mid_a * 0.6 + mid_b * 0.4) * amp * mid_fade;
		// Lush green highlights and cooler shade within the turf canopy (no yellow cast)
		blended_albedo = mix(blended_albedo, blended_albedo * vec3(0.98, 1.05, 0.94), clamp(mid_b * 0.5 + 0.5, 0.0, 1.0) * 0.20 * mid_fade * grass_w_total);
	}

	// Close-range (< 18m) procedural micro-blade normal perturbation at golfer address
	if (close_blade_fade > 0.01 && (rough_w + fairway_w) > 0.1) {
		float blade_nx = gnoise(v_world_pos.xz * 26.0);
		float blade_nz = gnoise(v_world_pos.xz * 26.0 + vec2(19.3, 41.7));
		vec3 micro_blade_n = vec3(blade_nx, blade_nz, 0.0) * 0.24 * close_blade_fade * (rough_w + fairway_w * 0.65);
		blended_normal = normalize(blended_normal + micro_blade_n);
	}

	// -----------------------------------------------------------------------
	// 4. Elevation Slope Relief & Subsurface Grass Translucency
	// -----------------------------------------------------------------------
	vec3 wn = normalize(v_world_normal);
	float slope_grade = length(wn.xz);
	float slope_intensity = clamp(slope_grade * 6.0, 0.0, 1.0);

	vec3 light_dir = normalize(-sun_direction);
	float NdotL = dot(wn, light_dir);
	float relief_diff = (NdotL - light_dir.y) * 2.0;
	float relief_factor = 1.0 + (relief_diff * slope_shading_strength);
	float bank_darkening = 1.0 - (slope_intensity * 0.25 * slope_shading_strength);

	blended_albedo *= clamp(relief_factor * bank_darkening, 0.45, 1.25);

	vec3 v_dir = normalize(v_cam_pos - v_world_pos);
	float backlight_dot = clamp(dot(-v_dir, light_dir), 0.0, 1.0);
	float grass_translucency = pow(backlight_dot, 2.8) * 0.16 * (rough_w * 0.75 + fairway_w * 0.40);
	blended_albedo += vec3(0.24, 0.40, 0.12) * grass_translucency;

	ALBEDO = clamp(blended_albedo, 0.0, 1.0);
	ROUGHNESS = clamp(blended_roughness, 0.5, 1.0);
	NORMAL_MAP = normalize(max(length(blended_normal), 0.001) > 0.002 ? blended_normal : vec3(0.0, 0.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;

	float macro_terrain_ao = mix(1.0, texture(terrain_ao_map, UV2).r, 0.45);
	AO = clamp(blended_ao * macro_terrain_ao, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.22;

	BACKLIGHT = vec3(0.11, 0.17, 0.05) * (rough_w * 0.60 + fairway_w * 0.35);
	SPECULAR = 0.03;
}

