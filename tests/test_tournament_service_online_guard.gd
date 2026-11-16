extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var service_script = load("res://Utils/Cloud/tournament_service.gd")
	assert(service_script != null, "Tournament service script must load")

	var online_session = root.get_node_or_null("OnlineSession")
	assert(online_session != null, "OnlineSession autoload must be available")
	var service = root.get_node_or_null("TournamentService")
	assert(service != null, "TournamentService autoload must be available")
	var original_state: Variant = online_session.get("is_online_match")

	online_session.set("is_online_match", true)
	assert(service._is_online_match_active(), "Online match guard must detect an active online session")
	service._on_hole_completed([])
	service._on_game_over([])

	online_session.set("is_online_match", false)
	assert(not service._is_online_match_active(), "Online match guard must allow local play")

	online_session.set("is_online_match", original_state)
	print("PASS: Tournament score handlers safely skip online matches.")
	quit(0)
