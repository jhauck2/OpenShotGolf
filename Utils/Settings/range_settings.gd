class_name RangeSettings
extends SettingCollector

var range_units := Setting.new(PhysicsEnums.Units.IMPERIAL)
var camera_follow_mode := Setting.new(true)
var shot_replay_follow := Setting.new(false)
var shot_injector_enabled := Setting.new(false)
var auto_ball_reset := Setting.new(false)
var ball_reset_timer := Setting.new(1.5, 0.0, 15.0)
var temperature := Setting.new(75, -40, 120)
var altitude := Setting.new(0.0, -1000.0, 10000.0)
var surface_type := Setting.new(PhysicsEnums.SurfaceType.FAIRWAY)
var shot_tracer_count := Setting.new(10, 0, 10)
var ball_type := Setting.new(0)
var camera_height := Setting.new(1.35, 0.5, 10.0)
var camera_distance := Setting.new(3.6, 1.0, 30.0)
var camera_fov := Setting.new(55.0, 1.0, 90.0)
var camera_far := Setting.new(1000.0, 100.0, 1000.0)
var ball_visual_scale := Setting.new(1.35, 1.0, 2.5)
var dof_enabled := Setting.new(false)
var dof_blur_amount := Setting.new(0.03, 0.0, 0.3)
var vignette_enabled := Setting.new(false)
var vignette_intensity := Setting.new(1.5, 0.0, 3.0)
var gimme_range_1_enabled := Setting.new(true)
var gimme_range_1_distance := Setting.new(4.0, 1.0, 100.0)
var gimme_range_2_enabled := Setting.new(false)
var gimme_range_2_distance := Setting.new(10.0, 1.0, 100.0)
var gimme_range_3_enabled := Setting.new(false)
var gimme_range_3_distance := Setting.new(30.0, 1.0, 100.0)
var custom_next_player := Setting.new(true)
var turn_order_mode := Setting.new("Stay Up")
var golf_clap_enabled := Setting.new(true)
var ambient_sound_enabled := Setting.new(true)
var menu_music_enabled := Setting.new(true)
var minigame_music_enabled := Setting.new(true)
var green_speed := Setting.new(10.0, 5.0, 16.0)
var random_pin_enabled := Setting.new(true)
var phone_cam_url := Setting.new("")
var use_phone_stream := Setting.new(false)
var tension_effects_enabled := Setting.new(true)
var shot_analysis_enabled := Setting.new(false)
var ball_rollout_enabled := Setting.new(true)
var displayed_stats := Setting.new(StatDefinitions.DEFAULT_ENABLED_STAT_IDS.duplicate())
var foam_ball_boost_enabled := Setting.new(false)
var foam_ball_boost_percent := Setting.new(20.0, 0.0, 100.0)
var power_calibration_percent := Setting.new(0.0, -10.0, 10.0)
var tcp_server_ip := Setting.new("0.0.0.0")
var tcp_server_port := Setting.new(49152, 1, 65535)
var launch_monitor_tab := Setting.new(0, 0, 3)
var fsx_csv_path := Setting.new("")
var fsx_poll_interval := Setting.new(0.25, 0.05, 2.0)
var gspro_selected_device := Setting.new("mlm2pro")
var graphics_quality := Setting.new(MobilePerformance.get_default_graphics_quality())
var wind_enabled := Setting.new(false)
var wind_speed := Setting.new(10.0, 0.0, 35.0)
var replay_window_detached := Setting.new(false)
var replay_window_position_x := Setting.new(-1)
var replay_window_position_y := Setting.new(-1)
var replay_window_width := Setting.new(1100)
var replay_window_height := Setting.new(750)
var putting_camera_enabled := Setting.new(false)
var putting_camera_fps := Setting.new(30, 15, 120)
var putting_camera_fps_mode := Setting.new("Auto")
var putting_camera_rotation := Setting.new(0)
var putting_camera_circle_x := Setting.new(0.5, 0.15, 0.85)
var putting_ball_color_hsv := Setting.new("")
var putting_ball_color_tolerance := Setting.new(30.0, 10.0, 90.0)
var putting_bg_color_hsv := Setting.new("")
var putting_min_speed_mph := Setting.new(1.5, 0.5, 5.0)
var putting_max_speed_mph := Setting.new(20.0, 10.0, 30.0)
var putting_mishit_filter_enabled := Setting.new(true)
var windowed_fullscreen := Setting.new(true)
var shot_curve_sensitivity := Setting.new(1.0, 0.5, 2.0)
var debug_show_suspense_cone := Setting.new(false)
var debug_show_hit_distance := Setting.new(false)
var debug_bypass_osm_limit := Setting.new(false)
var screen_offset_enabled := Setting.new(false)
var screen_offset_value := Setting.new(0.0, -1.0, 1.0)
var screen_offset_putter_value := Setting.new(0.0, -1.0, 1.0)
var debug_logging_enabled := Setting.new(OS.get_name() in ["iOS", "Android"])
var debug_log_path := Setting.new("user://debug.log")
var track_club_averages := Setting.new(true)

func _init():
	init({
		"range_units": range_units,
		"camera_follow_mode": camera_follow_mode,
		"shot_replay_follow": shot_replay_follow,
		"shot_injector_enabled": shot_injector_enabled,
		"auto_ball_reset": auto_ball_reset,
		"ball_reset_timer": ball_reset_timer,
		"temperature": temperature,
		"altitude": altitude,
		"surface_type": surface_type,
		"shot_tracer_count": shot_tracer_count,
		"ball_type": ball_type,
		"camera_height": camera_height,
		"camera_distance": camera_distance,
		"camera_fov": camera_fov,
		"camera_far": camera_far,
		"ball_visual_scale": ball_visual_scale,
		"dof_enabled": dof_enabled,
		"dof_blur_amount": dof_blur_amount,
		"vignette_enabled": vignette_enabled,
		"vignette_intensity": vignette_intensity,
		"gimme_range_1_enabled": gimme_range_1_enabled,
		"gimme_range_1_distance": gimme_range_1_distance,
		"gimme_range_2_enabled": gimme_range_2_enabled,
		"gimme_range_2_distance": gimme_range_2_distance,
		"gimme_range_3_enabled": gimme_range_3_enabled,
		"gimme_range_3_distance": gimme_range_3_distance,
		"custom_next_player": custom_next_player,
		"turn_order_mode": turn_order_mode,
		"golf_clap_enabled": golf_clap_enabled,
		"ambient_sound_enabled": ambient_sound_enabled,
		"menu_music_enabled": menu_music_enabled,
		"minigame_music_enabled": minigame_music_enabled,
		"green_speed": green_speed,
		"random_pin_enabled": random_pin_enabled,
		"phone_cam_url": phone_cam_url,
		"use_phone_stream": use_phone_stream,
		"tension_effects_enabled": tension_effects_enabled,
		"shot_analysis_enabled": shot_analysis_enabled,
		"ball_rollout_enabled": ball_rollout_enabled,
		"displayed_stats": displayed_stats,
		"foam_ball_boost_enabled": foam_ball_boost_enabled,
		"foam_ball_boost_percent": foam_ball_boost_percent,
		"power_calibration_percent": power_calibration_percent,
		"tcp_server_ip": tcp_server_ip,
		"tcp_server_port": tcp_server_port,
		"launch_monitor_tab": launch_monitor_tab,
		"fsx_csv_path": fsx_csv_path,
		"fsx_poll_interval": fsx_poll_interval,
		"gspro_selected_device": gspro_selected_device,
		"graphics_quality": graphics_quality,
		"wind_enabled": wind_enabled,
		"wind_speed": wind_speed,
		"replay_window_detached": replay_window_detached,
		"replay_window_position_x": replay_window_position_x,
		"replay_window_position_y": replay_window_position_y,
		"replay_window_width": replay_window_width,
		"replay_window_height": replay_window_height,
		"putting_camera_enabled": putting_camera_enabled,
		"putting_camera_fps": putting_camera_fps,
		"putting_camera_fps_mode": putting_camera_fps_mode,
		"putting_camera_rotation": putting_camera_rotation,
		"putting_camera_circle_x": putting_camera_circle_x,
		"putting_ball_color_hsv": putting_ball_color_hsv,
		"putting_ball_color_tolerance": putting_ball_color_tolerance,
		"putting_bg_color_hsv": putting_bg_color_hsv,
		"putting_min_speed_mph": putting_min_speed_mph,
		"putting_max_speed_mph": putting_max_speed_mph,
		"putting_mishit_filter_enabled": putting_mishit_filter_enabled,
		"windowed_fullscreen": windowed_fullscreen,
		"shot_curve_sensitivity": shot_curve_sensitivity,
		"debug_show_suspense_cone": debug_show_suspense_cone,
		"debug_show_hit_distance": debug_show_hit_distance,
		"debug_bypass_osm_limit": debug_bypass_osm_limit,
		"screen_offset_enabled": screen_offset_enabled,
		"screen_offset_value": screen_offset_value,
		"screen_offset_putter_value": screen_offset_putter_value,
		"debug_logging_enabled": debug_logging_enabled,
		"debug_log_path": debug_log_path,
		"track_club_averages": track_club_averages,
	})


