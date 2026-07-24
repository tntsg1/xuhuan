extends SceneTree

# Round 28: Cassegrain family uses the same three-column bench + tube
# subassembly as Newtonian/Dobsonian, with its own parts, blueprint and optics.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(46, false)   # first cassegrain level
	_check(str(gm.current_level().get("telescope_family", "")) == "cassegrain", "0. L46 is a Cassegrain level")

	# --- 1. Main bench: 4 external slots, no internal parts ---
	var main: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(main)
	for _i in range(8):
		await process_frame
	var main_parts: Array = main.call("_main_parts")
	_check(main_parts == ["tripod", "mount", "optical_tube_assembly", "finder_scope"], "1. main bench shows exactly 4 external parts")
	var internal := ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_mirror", "central_baffle", "focuser", "eyepiece", "collimation_tool"]
	var leak := false
	for p in internal:
		if main_parts.has(p):
			leak = true
	_check(not leak, "1. no internal tube part appears on the main bench")
	var mbp: Dictionary = main.call("_main_blueprint_config")
	_check((mbp["slots"] as Dictionary).size() == 4, "1. main blueprint has 4 slots")
	_check(str(mbp["path"]).contains("cassegrain_main_blueprint"), "1. main uses the Cassegrain blueprint art")
	# fork mount + finder are the right parts
	_check(str((main.call("_main_template_part", "mount") as Dictionary).get("id", "")) == "cassegrain_fork_mount", "1. mount slot resolves the Cassegrain Fork Mount")
	_check(str((main.call("_main_template_part", "finder_scope") as Dictionary).get("id", "")) == "basic_finder_scope", "1. finder reuses Basic Finder Scope")
	main.queue_free()
	await process_frame

	# --- 2. Tube bench: 8 slots in the correct order, with real sprites ---
	var cfg: Dictionary = gm.tube_subassembly_config()
	_check((cfg["order"] as Array).size() == 8, "2. tube subassembly has 8 slots")
	_check((cfg["order"] as Array) == internal, "2. tube order is tube/cell/primary/secondary/baffle/focuser/eyepiece/collimation")
	_check((cfg["ids"] as Array)[1] == "cassegrain_mirror_cell", "2. slot 2 is the Cassegrain Primary Mirror Cell")
	_check((cfg["ids"] as Array)[7] == "cassegrain_collimation_tool", "2. slot 8 is the Cassegrain Collimation Tool")
	var tube: Node = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(tube)
	for _i in range(8):
		await process_frame
	var tbp: Dictionary = tube.call("_tube_blueprint_config")
	_check((tbp["slots"] as Dictionary).size() == 8, "2. tube blueprint has 8 slots")
	_check(str(tbp["path"]).contains("cassegrain_tube_blueprint"), "2. tube uses the Cassegrain tube blueprint art")
	tube.queue_free()
	await process_frame

	# --- 3. Every part uses a real PNG (no placeholder / geometry) ---
	for pid in (cfg["ids"] as Array) + ["cassegrain_fork_mount"]:
		var part: Dictionary = gm.get_part(str(pid))
		_check(not part.is_empty(), "3. part %s exists in data" % pid)
		var icon := str(part.get("icon_path", ""))
		_check(icon != "" and ResourceLoader.exists(icon), "3. %s has a real icon: %s" % [pid, icon.get_file()])
		if ResourceLoader.exists(icon):
			var img: Image = (load(icon) as Texture2D).get_image()
			_check(img.detect_alpha(), "3. %s icon has transparency" % pid)

	# --- 4. Full flow: build tube -> save -> main OTA shows complete ---
	gm.reset_assembly()
	var completed := {}
	for sub in cfg["order"]:
		completed[str(sub)] = true
	var saved: bool = gm.save_tube_assembly(completed, 100.0, 100.0, false)
	_check(saved, "4. tube saves once all 8 subparts are installed")
	_check(gm.advanced_tube_completed(), "4. main bench sees the completed optical tube")
	# a partial tube must NOT save
	gm.reset_assembly()
	var partial := completed.duplicate()
	partial.erase("collimation_tool")
	_check(not gm.save_tube_assembly(partial, 100.0, 100.0, false), "4. an incomplete tube (missing collimation) will not save")

	# --- 5. Family isolation: Newtonian and refractor untouched ---
	gm.debug_jump_to_level(26, false)   # newtonian
	_check((gm.tube_subassembly_config()["order"] as Array).has("secondary_spider"), "5. Newtonian still uses its spider-based 8-slot tube")
	gm.debug_jump_to_level(4, false)    # refractor
	_check(gm.tube_subassembly_config().is_empty(), "5. refractor has no tube subassembly (unchanged)")
	# one-key equip stays within the family
	gm.debug_jump_to_level(46, false)
	var plan: Array = gm.auto_equip_plan()
	var wrong_family := false
	for entry_value in plan:
		var part: Dictionary = gm.get_part(str((entry_value as Dictionary).get("part_id", "")))
		var fam := str(part.get("telescope_family", ""))
		if fam != "" and fam != "cassegrain":
			wrong_family = true
	_check(not wrong_family, "5. auto-equip never picks another family's part on a Cassegrain level")

	# --- 6. Cassegrain optics facts + bilingual names (no language mixing) ---
	_check(str(gm.tube_subassembly_config()["family"]) == "cassegrain", "6. tube config family is cassegrain")
	var all_bilingual := true
	for pid in (cfg["ids"] as Array) + ["cassegrain_fork_mount"]:
		var part: Dictionary = gm.get_part(str(pid))
		var zh := str(part.get("name_zh", ""))
		var has_cjk := false
		for c in zh:
			if c >= "一" and c <= "鿿":
				has_cjk = true
		if not has_cjk:
			all_bilingual = false
	_check(all_bilingual, "6. every Cassegrain part has a real Chinese name (no EN leaking into ZH)")

	if failures == 0:
		print("CASSEGRAIN ASSEMBLY TEST PASS")
		quit(0)
	else:
		print("CASSEGRAIN ASSEMBLY TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
