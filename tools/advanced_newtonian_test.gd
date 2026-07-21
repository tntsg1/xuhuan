extends SceneTree

var failures := 0

func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	_check(gm.levels_data.size() >= 27, "advanced level data loads after L24")
	gm.debug_jump_to_level(26, true)
	_check(str(gm.current_level().get("telescope_family", "")) == "newtonian", "L26 selects Newtonian family")
	_check(gm.telescope_is_ready(), "L26 prepared reflector satisfies independent required parts")
	var stats: Dictionary = gm.calculate_stats()
	_check(float(stats.get("light_score", 0.0)) > 90.0, "primary mirror contributes aperture/light stats")
	# Debug-prepare now aligns the mirrors too; reset the score so the gate
	# logic itself stays under test.
	gm.set_collimation_score(0.0)
	_check(not gm.collimation_is_acceptable(), "L26 collimation gate blocks when unaligned")
	gm.set_collimation_score(92.0)
	_check(gm.collimation_is_acceptable(), "collimation threshold unlocks observation")
	if failures == 0:
		print("ADVANCED NEWTONIAN TEST PASS")
		quit(0)
	else:
		print("ADVANCED NEWTONIAN TEST FAIL")
		quit(1)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
