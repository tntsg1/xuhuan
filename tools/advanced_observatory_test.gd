extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var game_manager: Node = root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("GameManager autoload is missing")
		quit(1)
		return
	game_manager.new_game()
	_expect(game_manager.levels_data.size() == 91, "campaign reaches L91")
	_expect(str(game_manager.levels_data[23].get("id", "")) == "level_24", "L1-L24 data remains intact")
	_expect(str(game_manager.levels_data[24].get("telescope_family", "")) == "refractor", "L25 uses refractor for the chromatic-aberration comparison")
	_expect(str(game_manager.levels_data[25].get("telescope_family", "")) == "newtonian", "L26 introduces the Newtonian family")
	_expect(str(game_manager.levels_data[35].get("telescope_family", "")) == "dobsonian", "L36 uses Dobsonian family")
	_expect(str(game_manager.levels_data[45].get("telescope_family", "")) == "cassegrain", "L46 uses Cassegrain family")
	_expect(str(game_manager.levels_data[55].get("telescope_family", "")) == "gregorian", "L56 uses Gregorian family")
	_expect(str(game_manager.levels_data[65].get("telescope_family", "")) == "space_segmented", "L66 uses segmented space family")
	_expect(str(game_manager.levels_data[75].get("telescope_family", "")) == "fast_radio", "L76 uses FAST radio family")
	_expect(str(game_manager.levels_data[90].get("telescope_family", "")) == "multi_device", "L91 uses multi-device synthesis")
	_expect(not game_manager.get_object("pulsar_b0329").is_empty(), "FAST has a local radio target")
	_check_family(game_manager, 36, ["dobsonian_rocker_mount", "dobsonian_primary_mirror", "dobsonian_30mm_eyepiece"])
	_check_family(game_manager, 46, ["cassegrain_fork_mount", "cassegrain_primary_mirror", "cassegrain_12mm_eyepiece"])
	_check_family(game_manager, 56, ["gregorian_equatorial_mount", "gregorian_primary_mirror", "gregorian_18mm_eyepiece"])
	_check_family(game_manager, 66, ["segmented_primary_array", "infrared_instrument_package", "space_sunshield"])
	_check_family(game_manager, 76, ["fast_active_dish", "fast_feed_cabin", "fast_signal_processor"])
	if failures == 0:
		print("ADVANCED OBSERVATORY TEST PASS")
		quit(0)
	else:
		push_error("ADVANCED OBSERVATORY TEST FAILED: %d" % failures)
		quit(1)


func _check_family(game_manager: Node, level_number: int, ids: Array[String]) -> void:
	game_manager.debug_jump_to_level(level_number, true)
	for id in ids:
		_expect(not game_manager.get_part(id).is_empty(), "L%d part exists: %s" % [level_number, id])
		_expect(game_manager.progress.get("unlocked_parts", []).has(id), "L%d part unlocks for test: %s" % [level_number, id])
	var level: Dictionary = game_manager.current_level()
	if bool(level.get("requires_telescope", false)):
		_expect(game_manager.missing_required_parts().is_empty(), "L%d exact advanced parts are selected" % level_number)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok: %s" % message)
	else:
		failures += 1
		push_error("  fail: %s" % message)
