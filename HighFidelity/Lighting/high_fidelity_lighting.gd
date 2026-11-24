extends RefCounted
class_name HighFidelityLighting

## HighFidelityLighting
## Configures Forward+ desktop lighting, SSAO, SSR, crisp 4-split directional shadows,
## single-pass atmospheric depth haze, and calibrated AgX tonemapping for High graphics mode
## with smooth performance on mainstream PCs (no heavy SDFGI/SSIL voxel overhead).

static var _cached_original_env_settings: Dictionary = {}
static var _cached_original_light_settings: Dictionary = {}

static func apply(scene_root: Node) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return

	# Configure clean MSAA anti-aliasing without TAA temporal motion blur
	var viewport = scene_root.get_viewport()
	if viewport != null:
		if "use_taa" in viewport:
			viewport.use_taa = false
		if "msaa_3d" in viewport:
			viewport.msaa_3d = Viewport.MSAA_4X
		if "scaling_3d_mode" in viewport:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		if "scaling_3d_scale" in viewport:
			viewport.scaling_3d_scale = 1.0

	# 1. Configure Directional Soft Shadows & Shadow Atlas (SOFT_HIGH balances crisp edges + fast GPU filter)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	)
	RenderingServer.directional_shadow_atlas_set_size(4096, true)

	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()

		# 2. Tune WorldEnvironment / Sky3D
		if node is WorldEnvironment and node.environment != null:
			_apply_environment_settings(node.environment)
			if node.camera_attributes != null and node.camera_attributes is CameraAttributesPractical:
				(node.camera_attributes as CameraAttributesPractical).dof_blur_far_enabled = false
			# Prevent double-fogging if Sky3D Skydome has its own fullscreen fog quad
			var skydome = node.get_node_or_null("Skydome")
			if skydome != null and "fog_visible" in skydome:
				skydome.fog_visible = false

		elif node is Camera3D:
			if node.attributes != null and node.attributes is CameraAttributesPractical:
				(node.attributes as CameraAttributesPractical).dof_blur_far_enabled = false

		# 3. Tune Sun / DirectionalLight3D
		elif node is DirectionalLight3D:
			_apply_directional_light_settings(node)

		for child in node.get_children():
			stack.append(child)


static func remove(scene_root: Node) -> void:
	if scene_root == null:
		return

	var viewport = scene_root.get_viewport()
	if viewport != null:
		if "use_taa" in viewport:
			viewport.use_taa = false
		if "msaa_3d" in viewport:
			viewport.msaa_3d = Viewport.MSAA_DISABLED

	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is WorldEnvironment and node.environment != null:
			_restore_environment_settings(node.environment)
		elif node is DirectionalLight3D:
			_restore_directional_light_settings(node)

		for child in node.get_children():
			stack.append(child)


static func _apply_environment_settings(env: Environment) -> void:
	if env == null:
		return

	var env_id = env.get_instance_id()
	if not _cached_original_env_settings.has(env_id):
		_cached_original_env_settings[env_id] = {
			"sdfgi_enabled": env.sdfgi_enabled,
			"ssil_enabled": env.ssil_enabled,
			"ssao_enabled": env.ssao_enabled,
			"ssr_enabled": env.ssr_enabled,
			"glow_enabled": env.glow_enabled,
			"glow_bloom": env.glow_bloom,
			"fog_enabled": env.fog_enabled,
			"fog_mode": env.fog_mode,
			"fog_density": env.fog_density,
			"fog_sky_affect": env.fog_sky_affect,
			"fog_aerial_perspective": env.fog_aerial_perspective,
			"fog_depth_begin": env.get("fog_depth_begin") if "fog_depth_begin" in env else 10.0,
			"fog_depth_end": env.get("fog_depth_end") if "fog_depth_end" in env else 100.0,
			"fog_depth_curve": env.get("fog_depth_curve") if "fog_depth_curve" in env else 1.0,
			"volumetric_fog_enabled": env.volumetric_fog_enabled,
			"tonemap_mode": env.tonemap_mode,
			"tonemap_exposure": env.tonemap_exposure,
			"tonemap_white": env.tonemap_white,
			"ambient_light_source": env.ambient_light_source,
			"ambient_light_energy": env.ambient_light_energy,
			"ambient_light_sky_contribution": env.ambient_light_sky_contribution,
			"ambient_light_color": env.ambient_light_color,
		}

	# Calibrated AgX / Filmic Tonemapping:
	# tonemap_white = 6.0 prevents highlight clipping on white silica sand and cumulus clouds
	if ClassDB.class_has_enum("Environment", "ToneMapper") and "TONE_MAPPER_AGX" in ClassDB.class_get_enum_constants("Environment", "ToneMapper"):
		env.tonemap_mode = 3 as Environment.ToneMapper
	else:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0

	# Disable heavy SDFGI & SSIL (saves 6-10 ms/frame on mainstream PCs & eliminates voxel blotching)
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.volumetric_fog_enabled = false

	# SSAO: Crisp contact & canopy pocket ambient occlusion
	env.ssao_enabled = true
	env.ssao_radius = 1.35
	env.ssao_intensity = 1.15
	env.ssao_power = 1.45
	env.ssao_detail = 0.55
	env.ssao_horizon = 0.06

	# Screen-Space Reflections (pond water reflections, capped at 32 steps for mainstream GPU speed)
	env.ssr_enabled = true
	env.ssr_max_steps = 32
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.25

	# Single-pass Atmospheric Depth Fog (crystal clear across playable hole distances 0-380m,
	# gentle aerial perspective only near far culling/horizon boundary 380m-1500m)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.76, 0.85, 0.95)
	env.fog_light_energy = 0.85
	env.fog_sun_scatter = 0.15
	env.fog_density = 0.45
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.25
	if "fog_depth_begin" in env:
		env.set("fog_depth_begin", 380.0)
	if "fog_depth_end" in env:
		env.set("fog_depth_end", 1500.0)
	if "fog_depth_curve" in env:
		env.set("fog_depth_curve", 1.6)

	# Incremental Sky Radiance (prevents per-frame full cubemap convolution spike)
	if env.sky != null:
		env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		env.sky.radiance_size = Sky.RADIANCE_SIZE_256

	# Balanced Daylight Sky IBL Fill (Crisp Warwick Hills shadow contrast)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.52
	env.ambient_light_energy = 0.28
	env.ambient_light_color = Color(0.68, 0.80, 0.94)

	# Subtle Natural HDR Highlight Bloom (glow_bloom=0.0 avoids full-screen softness/blur)
	env.glow_enabled = true
	env.glow_intensity = 0.15
	env.glow_bloom = 0.0


static func _restore_environment_settings(env: Environment) -> void:
	if env == null:
		return
	var env_id = env.get_instance_id()
	if not _cached_original_env_settings.has(env_id):
		return

	var orig = _cached_original_env_settings[env_id]
	env.sdfgi_enabled = orig.get("sdfgi_enabled", false)
	env.ssil_enabled = orig.get("ssil_enabled", false)
	env.ssao_enabled = orig.get("ssao_enabled", false)
	env.ssr_enabled = orig.get("ssr_enabled", false)
	env.glow_enabled = orig.get("glow_enabled", false)
	env.glow_bloom = orig.get("glow_bloom", 0.0)
	env.fog_enabled = orig.get("fog_enabled", false)
	env.fog_mode = orig.get("fog_mode", Environment.FOG_MODE_EXPONENTIAL)
	env.fog_density = orig.get("fog_density", 0.01)
	env.fog_sky_affect = orig.get("fog_sky_affect", 1.0)
	env.fog_aerial_perspective = orig.get("fog_aerial_perspective", 0.0)
	if "fog_depth_begin" in env:
		env.set("fog_depth_begin", orig.get("fog_depth_begin", 10.0))
	if "fog_depth_end" in env:
		env.set("fog_depth_end", orig.get("fog_depth_end", 100.0))
	if "fog_depth_curve" in env:
		env.set("fog_depth_curve", orig.get("fog_depth_curve", 1.0))
	env.volumetric_fog_enabled = orig.get("volumetric_fog_enabled", false)
	env.tonemap_mode = orig.get("tonemap_mode", Environment.TONE_MAPPER_LINEAR)
	env.tonemap_exposure = orig.get("tonemap_exposure", 1.0)
	env.tonemap_white = orig.get("tonemap_white", 1.0)
	env.ambient_light_source = orig.get("ambient_light_source", Environment.AMBIENT_SOURCE_BG)
	env.ambient_light_energy = orig.get("ambient_light_energy", 1.0)
	env.ambient_light_sky_contribution = orig.get("ambient_light_sky_contribution", 1.0)
	env.ambient_light_color = orig.get("ambient_light_color", Color.WHITE)


static func _apply_directional_light_settings(light: DirectionalLight3D) -> void:
	if light == null:
		return
	var light_id = light.get_instance_id()
	if not _cached_original_light_settings.has(light_id):
		_cached_original_light_settings[light_id] = {
			"directional_shadow_mode": light.directional_shadow_mode,
			"directional_shadow_max_distance": light.directional_shadow_max_distance,
			"directional_shadow_blend_splits": light.directional_shadow_blend_splits,
			"directional_shadow_split_1": light.directional_shadow_split_1,
			"directional_shadow_split_2": light.directional_shadow_split_2,
			"directional_shadow_split_3": light.directional_shadow_split_3,
			"light_angular_distance": light.light_angular_distance,
			"shadow_bias": light.shadow_bias,
			"shadow_normal_bias": light.shadow_normal_bias
		}

	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = 550.0
	light.directional_shadow_blend_splits = true
	light.directional_shadow_split_1 = 0.025  # Razor-sharp leaf & bunker lip shadows at tee address (0-15m)
	light.directional_shadow_split_2 = 0.10
	light.directional_shadow_split_3 = 0.32
	light.shadow_enabled = true
	light.shadow_opacity = 0.92
	light.light_color = Color(1.0, 0.96, 0.88)
	light.light_energy = maxf(light.light_energy, 1.45)
	light.light_angular_distance = 0.35
	light.shadow_bias = 0.018
	light.shadow_normal_bias = 1.6


static func _restore_directional_light_settings(light: DirectionalLight3D) -> void:
	if light == null:
		return
	var light_id = light.get_instance_id()
	if not _cached_original_light_settings.has(light_id):
		return
	var orig = _cached_original_light_settings[light_id]
	light.directional_shadow_mode = orig.get("directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	light.directional_shadow_max_distance = orig.get("directional_shadow_max_distance", 500.0)
	light.directional_shadow_blend_splits = orig.get("directional_shadow_blend_splits", true)
	light.directional_shadow_split_1 = orig.get("directional_shadow_split_1", 0.05)
	light.directional_shadow_split_2 = orig.get("directional_shadow_split_2", 0.15)
	light.directional_shadow_split_3 = orig.get("directional_shadow_split_3", 0.40)
	light.light_angular_distance = orig.get("light_angular_distance", 0.0)
	light.shadow_bias = orig.get("shadow_bias", 0.03)
	light.shadow_normal_bias = orig.get("shadow_normal_bias", 2.0)

