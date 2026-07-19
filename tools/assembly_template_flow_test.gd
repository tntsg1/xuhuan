extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)

	var main: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.call("_select_newtonian_main_part", "mount")
	main.call("_install_main_part", "mount")
	_check(not _installed(gm, "mount"), "wrong main-assembly order is rejected")
	main.call("_select_newtonian_main_part", "tripod")
	main.call("_install_main_part", "tripod")
	main.call("_select_newtonian_main_part", "mount")
	main.call("_install_main_part", "mount")
	_check(_installed(gm, "tripod") and _installed(gm, "mount"), "main support components install through card then slot flow")

	main.queue_free()
	await process_frame
	var tube: Node = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(tube)
	current_scene = tube
	await process_frame
	for subpart_value in gm.tube_subassembly_config().get("order", []):
		var subpart := str(subpart_value)
		tube.call("_select_newtonian_tube_part", subpart)
		tube.call("_install_subpart", subpart)
	_check(str(tube.call("_next_required_subpart")) == "", "all eight tube parts install in required order")
	tube.call("_save_assembly")
	await process_frame
	await process_frame
	_check(gm.advanced_tube_completed(), "Save Tube Assembly completes the nested component")
	_check(_installed(gm, "optical_tube_assembly"), "saved Newtonian tube is marked installed on the main bench")
	_check(_installed(gm, "tripod") and _installed(gm, "mount"), "return from tube assembly preserves external components")
	_check(current_scene != null and current_scene.scene_file_path.ends_with("advanced_assembly.tscn"), "tube save returns to Newtonian main assembly")

	if failures == 0:
		print("ASSEMBLY TEMPLATE FLOW TEST PASS")
		quit(0)
	else:
		print("ASSEMBLY TEMPLATE FLOW TEST FAIL")
		quit(1)


func _installed(gm: Node, part_type: String) -> bool:
	var state: Dictionary = gm.progress.get("assembly_state", {})
	var entry: Dictionary = state.get(part_type, {})
	return bool(entry.get("installed", false))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
