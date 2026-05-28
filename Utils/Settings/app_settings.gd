class_name AppSettings
extends SettingCollector

const DEFAULT_PLAYER_NAME := "Tiger"
const DEFAULT_TEST_SHOTS_ENABLED := true
const DEFAULT_RESOLUTION_PRESET := "1728x972"
const FEET_PER_CAMERA_DISTANCE_UNIT := 3.28084
const DEFAULT_CAMERA_ORBIT_DISTANCE := 7.0 / FEET_PER_CAMERA_DISTANCE_UNIT
const DEFAULT_CAMERA_FOLLOW_DELAY_SECONDS := 3.0
const DEFAULT_TCP_PORT := 49152
const DEFAULT_SHOT_RECORDING_ENABLED := false
const DEFAULT_SHOT_RECORDING_PATH := ""
const DEFAULT_RANGE_DEFAULT_CLUB := "DRIVER"
const LAUNCH_MONITOR_PROVIDER_PITRAC := "PiTrac"
const LAUNCH_MONITOR_PROVIDER_SQUARE := "Square"
const LAUNCH_MONITOR_PROVIDERS := [LAUNCH_MONITOR_PROVIDER_PITRAC, LAUNCH_MONITOR_PROVIDER_SQUARE]


static func is_valid_provider(provider: String) -> bool:
	return provider in LAUNCH_MONITOR_PROVIDERS


static func normalize_provider(provider: String) -> String:
	if is_valid_provider(provider):
		return provider
	return LAUNCH_MONITOR_PROVIDER_PITRAC

var player_name: Setting = Setting.new(DEFAULT_PLAYER_NAME)
var test_shots_enabled: Setting = Setting.new(DEFAULT_TEST_SHOTS_ENABLED)
var display_resolution_preset: Setting = Setting.new(DEFAULT_RESOLUTION_PRESET)
var display_fullscreen: Setting = Setting.new(false)
var camera_orbit_distance: Setting = Setting.new(DEFAULT_CAMERA_ORBIT_DISTANCE, 1.0, 8.0)
var camera_follow_delay_seconds: Setting = Setting.new(DEFAULT_CAMERA_FOLLOW_DELAY_SECONDS, 0.0, 5.0)
var tcp_port: Setting = Setting.new(DEFAULT_TCP_PORT, 1, 65535)
var shot_recording_enabled: Setting = Setting.new(DEFAULT_SHOT_RECORDING_ENABLED)
var shot_recording_path: Setting = Setting.new(DEFAULT_SHOT_RECORDING_PATH)
var range_default_club: Setting = Setting.new(DEFAULT_RANGE_DEFAULT_CLUB)
var launch_monitor_enabled: Setting = Setting.new(false)
var launch_monitor_provider: Setting = Setting.new(LAUNCH_MONITOR_PROVIDER_PITRAC)
var square_device_id: Setting = Setting.new("")
var square_club_code: Setting = Setting.new(SquareClubCatalog.DEFAULT_CLUB_CODE)
var square_handedness: Setting = Setting.new(0, 0, 1)


func _init() -> void:
	settings = {
		"player_name": player_name,
		"test_shots_enabled": test_shots_enabled,
		"display_resolution_preset": display_resolution_preset,
		"display_fullscreen": display_fullscreen,
		"camera_orbit_distance": camera_orbit_distance,
		"camera_follow_delay_seconds": camera_follow_delay_seconds,
		"tcp_port": tcp_port,
		"shot_recording_enabled": shot_recording_enabled,
		"shot_recording_path": shot_recording_path,
		"range_default_club": range_default_club,
		"launch_monitor_enabled": launch_monitor_enabled,
		"launch_monitor_provider": launch_monitor_provider,
		"square_device_id": square_device_id,
		"square_club_code": square_club_code,
		"square_handedness": square_handedness
	}
