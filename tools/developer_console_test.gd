extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager missing")
		quit(1)
		return
	gm.new_game()
	gm.go("observatory")
	await process_frame
	gm.toggle_developer_console()
	_check(gm.developer_console != null and is_instance_valid(gm.developer_console), "developer console opens over the current scene")
	_check(gm.available_level_numbers().size() == gm.levels_data.size(), "developer console reads the full level dataset")
	_check(gm.available_level_numbers().has(45), "developer console includes L45")
	var has_l45_button := false
	for node in gm.developer_console.find_children("*", "Button", true, false):
		if str(node.get("text")) == "L45":
			has_l45_button = true
			break
	_check(has_l45_button, "developer console renders an L45 button")
	gm.debug_jump_to_level(18, true)
	_check(int(gm.progress.get("current_level", 0)) == 18, "developer console can select L18")
	_check(gm.selected_object_id == "orion_nebula", "selected target follows the chosen lesson")
	_check(gm.telescope_is_ready(), "prepared level installs required telescope parts")
	gm.debug_launch("telescope", true)
	await process_frame
	_check(current_scene != null and str(current_scene.scene_file_path).contains("telescope_view"), "developer launch opens Telescope View")
	if failures == 0:
		print("DEVELOPER CONSOLE TEST PASS")
		quit(0)
	else:
		print("DEVELOPER CONSOLE TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
