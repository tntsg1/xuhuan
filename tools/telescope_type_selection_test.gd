extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(80, false)
	var selector: Node = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(selector)
	await process_frame
	var ids: Array[String] = []
	var constants: Dictionary = (selector.get_script() as Script).get_script_constant_map()
	for entry_value in constants.get("FAMILIES", []):
		ids.append(str((entry_value as Dictionary).get("id", "")))
	for expected in ["refractor", "newtonian", "dobsonian", "cassegrain", "gregorian", "space_segmented", "fast_radio"]:
		_check(ids.has(expected), "selector includes " + expected)
	selector.call("_select", "newtonian")
	_check(str(selector.get("selected_family")) == "newtonian", "an unlocked non-recommended family can be selected")
	# _proceed stores the player's explicit bench choice before routing. Avoid a
	# scene switch in the test; the assignment itself is the navigation contract.
	gm.select_assembly_family(str(selector.get("selected_family")))
	_check(gm.assembly_family() == "newtonian", "assembly context preserves the player's choice")
	_check(str(gm.progress.get("selected_telescope_family", "")) == "newtonian", "bench choice is stored in save progress")
	_check(gm.assembly_scene_key() == "advanced_assembly", "non-refractor choice routes directly to the advanced blueprint")
	gm.assembly_family_id = ""
	_check(gm.assembly_family() == "newtonian", "saved bench choice survives transient navigation state")
	_check(str(gm.current_level().get("telescope_family", "")) == "fast_radio", "choosing a bench does not rewrite mission data")
	selector.queue_free()
	await process_frame
	gm.new_game()
	_check(gm.assembly_family() == "refractor", "new game starts with the refractor blueprint")
	_check(gm.assembly_scene_key() == "assembly", "refractor choice routes directly to the basic blueprint")
	print("TELESCOPE TYPE SELECTION TEST PASS" if failures == 0 else "TELESCOPE TYPE SELECTION TEST FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
