extends SceneTree

# Headless end-to-end flow test: simulates completing all levels.
# Run: godot --headless --script res://tools/flow_test.gd

func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return
	gm.new_game()
	var max_level: int = root.get_node("/root/MissionManager").get_max_level()
	print("Levels loaded: ", max_level)
	var failures := 0
	for i in range(max_level):
		var level: Dictionary = gm.current_level()
		var level_number: int = int(level.get("level_number", -1))
		var target_id: String = str(level.get("target_object_id", ""))
		if target_id == "":
			print("FAIL L", level_number, ": no target")
			failures += 1
			break
		# Auto-equip best unlocked part per type (upgrade path)
		for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope"]:
			var options: Array = gm.unlocked_parts_by_type(part_type)
			if not options.is_empty():
				gm.equip_part(str(options[options.size() - 1].get("id", "")))
		# Perfect assembly of required parts
		gm.reset_assembly()
		for part_type in level.get("required_parts", []):
			gm.install_part(str(part_type), 0)
		if not gm.telescope_is_ready():
			print("FAIL L", level_number, ": telescope not ready, missing=", gm.missing_parts())
			failures += 1
			break
		var stats: Dictionary = gm.calculate_stats()
		gm.selected_object_id = target_id
		var observation: Dictionary = gm.evaluate_selected_object()
		var ok: bool = gm.complete_current_mission(target_id, observation)
		print("L", level_number, " target=", target_id,
			" quality=", observation.get("quality"),
			" light=", stats.get("light_score"),
			" clarity=", stats.get("clarity_score"),
			" stability=", stats.get("stability_score"),
			" completed=", ok)
		if not ok:
			print("FAIL L", level_number, ": mission not completed. feedback=", observation.get("feedback_en"))
			failures += 1
			break
	var completed: Array = gm.progress.get("completed_levels", [])
	var badges: Array = gm.progress.get("badges", [])
	print("Completed levels: ", completed)
	print("Badges: ", badges)
	print("Credits: ", gm.progress.get("credits"))
	print("Journal entries: ", gm.progress.get("journal_entries", []).size())
	if failures == 0 and completed.size() == max_level:
		print("FLOW TEST PASS")
		quit(0)
	else:
		print("FLOW TEST FAIL")
		quit(1)
