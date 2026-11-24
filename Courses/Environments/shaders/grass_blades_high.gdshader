shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// ============================================================================
// High-Fidelity 3D Grass Blade & Fescue Shader (GPU MultiMesh)
// Replicates the dense foreground address turf & tall clumped rough/bunker-lip
// fescue seen in Warwick Hills reference frames (6:55, 7:05, 7:28).
// ============================================================================

uniform vec3 root_color : source_color = vec3(0.14, 0.24, 0.10);
uniform vec3 tip_color : source_color = vec3(0.38, 0.56, 0.24);
uniform vec3 dry_tip_color : source_color = vec3(0.58, 0.54, 0.34);
uniform float dry_tip_ratio : hint_range(0.0, 1.0) = 0.18;

uniform float roughness : hint_range(0.0, 1.0) = 0.58;
uniform float specular : hint_range(0.0, 1.0) = 0.22;
uniform vec3 backlight_color : source_color = vec3(0.45, 0.66, 0.20);
uniform float backlight_strength : hint_range(0.0, 2.0) = 0.85;

uniform vec2 wind_direction = vec2(0.85, 0.52);
uniform float wind_speed : hint_range(0.0, 5.0) = 1.35;
uniform float wind_strength : hint_range(0.0, 0.4) = 0.08;

uniform float max_render_distance : hint_range(5.0, 800.0) = 180.0;
uniform float fade_start_distance : hint_range(3.0, 700.0) = 120.0;
uniform float head_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec3 head_color : source_color = vec3(0.38, 0.25, 0.14);

// Optional course splat map masking (R=green, G=fairway, B=bunker, A=mulch)
uniform bool use_splat_mask = false;
uniform bool mask_allow_fairway = false;
uniform sampler2D splat_map : hint_default_black, filter_linear, repeat_disable;
uniform vec2 terrain_min_xz = vec2(-500.0, -500.0);
uniform vec2 terrain_size_xz = vec2(1000.0, 1000.0);

varying float v_height_pct;
varying float v_seed;
varying vec3 v_instance_tint;
varying float v_cull_mask;
varying vec2 v_world_xz;
varying vec4 v_vert_color;

void vertex() {
	// UV.y goes from 0.0 at root to 1.0 at blade tip
	v_height_pct = clamp(1.0 - UV.y, 0.0, 1.0);
	v_seed = INSTANCE_CUSTOM.a > 0.001 ? INSTANCE_CUSTOM.a : fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_instance_tint = INSTANCE_CUSTOM.a > 0.001 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
	v_vert_color = COLOR;

	vec3 world_origin = MODEL_MATRIX[3].xyz;
	v_world_xz = world_origin.xz;
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	float dist = distance(world_origin, cam_pos);

	// Smooth distance scale fade so grass blades never pop
	float dist_scale = 1.0 - smoothstep(fade_start_distance, max_render_distance, dist);

	// Suppress sub-pixel 3D grass blades in orthogonal top-down cameras (MinimapCamera / AerialCamera)
	// so thin swaying blades never alias or sparkle along water hazard shorelines on the minimap.
	float ortho_allow = step(abs(PROJECTION_MATRIX[3][3]), 0.5);

	// Optional splat map check so rough blades never grow inside greens or sand traps
	float surface_allow = 1.0;
	if (use_splat_mask && terrain_size_xz.x > 1.0 && terrain_size_xz.y > 1.0) {
		vec2 uv2 = clamp((world_origin.xz - terrain_min_xz) / terrain_size_xz, vec2(0.0), vec2(1.0));
		vec4 sp = textureLod(splat_map, uv2, 0.0);
		// B = Bunker/Sand (0.50 = exact edge), R = Green/Fringe (0.50 = 1.50m outer fringe edge), G = Fairway
		if (sp.b > 0.48 || sp.r > 0.52 || (!mask_allow_fairway && sp.g > 0.82)) {
			surface_allow = 0.0;
		} else {
			// Smooth cutoff aligned with outer fringe (sp.r == 0.50), bunker (sp.b == 0.50), and fairway edge
			float disallow_gb = max(sp.r, sp.b);
			float allow_gb = 1.0 - smoothstep(0.42, 0.52, disallow_gb);
			float allow_fw = mask_allow_fairway ? 1.0 : (1.0 - smoothstep(0.74, 0.84, sp.g));
			surface_allow = min(allow_gb, allow_fw);
		}
	}

	// Shoreline reed & cattail height variation + selective cattail spawning
	float reed_elem_allow = 1.0;
	if (head_ratio > 0.001) {
		if (COLOR.r > 0.25) {
			// Cattail stalk / cylindrical brown seed head: spawn occasionally in natural shoreline pockets
			float cat_hash = fract(sin(dot(world_origin.xz, vec2(19.19, 47.73)) + COLOR.g * 113.1) * 43758.5453);
			float cat_patch = sin(world_origin.x * 0.16 + world_origin.z * 0.13) * 0.5 + 0.5;
			float spawn_prob = head_ratio * mix(0.32, 1.12, cat_patch);
			if (cat_hash > spawn_prob) {
				reed_elem_allow = 0.0;
			} else if (VERTEX.y > 0.0) {
				float cat_h_scale = mix(0.78, 1.22, fract(cat_hash * 31.73));
				VERTEX.y *= cat_h_scale;
			}
		} else if (VERTEX.y > 0.0) {
			// Vary individual grass/reed blade height per clump & per blade so the top silhouette is organic
			float blade_hash = fract(sin(dot(world_origin.xz, vec2(12.9898, 78.233)) + COLOR.g * 91.73) * 43758.5453);
			float wave_patch = sin(world_origin.x * 0.14 - world_origin.z * 0.11) * 0.5 + 0.5;
			float h_mult = mix(0.65, 1.08, blade_hash) * mix(0.85, 1.12, wave_patch);
			if (blade_hash > 0.88) {
				h_mult *= mix(1.04, 1.15, (blade_hash - 0.88) / 0.12);
			}
			VERTEX.y *= h_mult;
			VERTEX.xz *= mix(0.92, 1.14, blade_hash);
		}
	}

	v_cull_mask = dist_scale * surface_allow * ortho_allow * reed_elem_allow;
	VERTEX *= v_cull_mask;

	// Natural blade arch & wind sway
	float flex = v_height_pct * v_height_pct;
	if (head_ratio > 0.001 && COLOR.r > 0.25) {
		// Cattail stems are stiffer than leafy grass blades
		flex *= 0.55;
	}
	vec2 wind_dir = length(wind_direction) > 0.01 ? normalize(wind_direction) : normalize(vec2(0.85, 0.52));
	float gust_phase = dot(world_origin.xz, wind_dir * 0.22) + TIME * wind_speed + v_seed * 6.28318;
	float gust = sin(gust_phase) * 0.7 + sin(gust_phase * 2.1 + 1.3) * 0.3;

	float sway = gust * wind_strength * flex * v_cull_mask;
	VERTEX.xz += wind_dir * sway;
	VERTEX.y -= abs(sway) * 0.22;

	// Preserve 3D cylindrical radial normal on cattail seed heads; tilt grass blade normals upward
	float normal_keep = (head_ratio > 0.001 && COLOR.r > 0.75) ? 0.78 : 0.22;
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), NORMAL, normal_keep));
}

void fragment() {
	if (v_cull_mask < 0.02) {
		discard;
	}

	if (head_ratio > 0.001 && v_vert_color.r > 0.75) {
		// 3D Cylindrical Brown Cattail Seed Head ("cigar")
		float head_v = clamp(v_vert_color.b, 0.0, 1.0);
		float end_taper = smoothstep(0.0, 0.16, head_v) * smoothstep(1.0, 0.84, head_v);
		float fuzzy_grain = fract(sin(dot(UV * vec2(23.1, 89.7) + vec2(v_seed * 17.3), vec2(12.9898, 78.233))) * 43758.5453);
		vec3 cat_col = head_color * mix(0.70, 1.15, end_taper) * (0.92 + 0.16 * fuzzy_grain);
		ALBEDO = clamp(cat_col, 0.0, 1.0);
		ROUGHNESS = 0.93;
		SPECULAR = 0.03;
		AO = mix(0.76, 1.0, end_taper);
		AO_LIGHT_AFFECT = 0.35;
		BACKLIGHT = head_color * 0.10;
	} else if (head_ratio > 0.001 && v_vert_color.r > 0.25) {
		// Cattail Stalk Stem (v_vert_color.b < 0.5) or Top Male Flower Spike (v_vert_color.b >= 0.5)
		vec3 stalk_col;
		if (v_vert_color.b >= 0.5) {
			stalk_col = mix(dry_tip_color, head_color * 1.45, 0.45);
		} else {
			stalk_col = mix(root_color, tip_color, 0.46) * 0.90 * v_instance_tint;
		}
		ALBEDO = clamp(stalk_col, 0.0, 1.0);
		ROUGHNESS = 0.82;
		SPECULAR = 0.08;
		AO = mix(0.75, 1.0, v_height_pct);
		AO_LIGHT_AFFECT = 0.25;
		BACKLIGHT = backlight_color * 0.25;
	} else {
		float blade_center_dist = abs(UV.x - 0.5) * 2.0;

		// Root-to-tip chlorophyll gradient (lush rich green matching authentic deep rough reference)
		vec3 blade_col = mix(root_color, tip_color, smoothstep(0.0, 0.85, v_height_pct));

		// Subtle sun-cured dry tip accent and occasional full golden-tan weathered reed blades
		if (dry_tip_ratio > 0.001) {
			if (head_ratio > 0.001) {
				float dry_seed = v_vert_color.b;
				if (dry_seed > 0.78) {
					// Weathered golden-tan reed blade from lower-mid stalk to tip (as in sample photo)
					float full_dry = smoothstep(0.22, 0.76, v_height_pct);
					blade_col = mix(blade_col, dry_tip_color, full_dry * 0.82);
				} else if (dry_seed > (1.0 - dry_tip_ratio - 0.15)) {
					float tip_dry = smoothstep(0.65, 1.0, v_height_pct);
					blade_col = mix(blade_col, dry_tip_color, tip_dry * 0.68);
				}
			} else {
				float dry_blade = step(1.0 - dry_tip_ratio, fract(v_seed * 17.31));
				float dry_pct = smoothstep(0.70, 1.0, v_height_pct) * dry_blade;
				blade_col = mix(blade_col, dry_tip_color, dry_pct * 0.65);
			}
		}

		blade_col *= v_instance_tint;

		// Soft natural blade-to-blade micro-variation
		float blade_noise = fract(sin(v_seed * 43.12 + UV.x * 7.89) * 43758.5453);
		blade_col *= (0.94 + 0.12 * blade_noise);

		// Macro undulating turf grain across terrain (matches golf reference frames)
		float macro_grain = sin(v_world_xz.x * 0.22 + v_world_xz.y * 0.15) * 0.5 + 0.5;
		blade_col *= mix(0.93, 1.07, macro_grain);

		// Center midrib highlight
		float rib = 1.0 - smoothstep(0.0, 0.45, blade_center_dist);
		blade_col *= (0.96 + 0.08 * rib);

		ALBEDO = clamp(blade_col, 0.0, 1.0);
		ROUGHNESS = mix(roughness + 0.08, roughness - 0.06, v_height_pct);
		SPECULAR = specular * v_height_pct;
		AO = mix(0.72, 1.0, smoothstep(0.0, 0.65, v_height_pct));
		AO_LIGHT_AFFECT = 0.25;
		BACKLIGHT = backlight_color * backlight_strength * (0.40 + 0.60 * v_height_pct);
	}
}
