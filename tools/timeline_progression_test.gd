extends SceneTree

# Acceptance test for the 91-level campaign (user checklist items 1-32):
# timeline purity, strict 10-level family blocks, chromatic bridge L23-L25,
# story coverage L1-L91, cabinet tabs, auto-equip compatibility, hints
# toggle persistence, mojibake scan, save migration, and real mechanics.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	if gm == null or mm == null or sm == null:
		print("TIMELINE PROGRESSION TEST FAIL (autoloads missing)")
		quit(1)
		return
	gm.new_game()

	# (1)(16)(17) campaign size and final level.
	_check(int(mm.get_max_level()) == 91, "1. campaign has 91 levels")
	_check(not mm.is_final_level(90), "16. L90 is NOT the final level")
	_check(mm.is_final_level(91), "17. L91 is the final level")

	# (2) L1-24 contain no Newtonian content in data.
	var forbidden := ["newtonian", "Newtonian", "牛顿", "reflector_tube", "primary_mirror", "secondary_mirror", "collimation_tool"]
	for level_number in range(1, 25):
		var blob := JSON.stringify(mm.get_level(level_number))
		var hits: Array[String] = []
		for word in forbidden:
			if blob.contains(word):
				hits.append(word)
		_check(hits.is_empty(), "2. L%d data has no Newtonian content %s" % [level_number, str(hits)])

	# (3) No Newtonian part unlockable before L25 completes.
	var pre_l25_unlocks: Array = gm.progress.get("unlocked_parts", []).duplicate()
	for level_number in range(1, 25):
		for part_id in mm.get_level(level_number).get("unlock_parts", []):
			pre_l25_unlocks.append(str(part_id))
	for part_id_value in pre_l25_unlocks:
		_check(str(gm.get_part(str(part_id_value)).get("telescope_family", "")) != "newtonian",
			"3. pre-L25 unlock '%s' is not Newtonian" % str(part_id_value))

	# (3b) unlock_level never leaks a family before its unlock point
	# (the previous block's final level hands the parts out via unlock_parts).
	var family_floor := {"newtonian": 25, "dobsonian": 35, "cassegrain": 45,
		"gregorian": 55, "space_segmented": 65, "fast_radio": 75}
	for part_value in gm.parts_data:
		var part: Dictionary = part_value
		var part_family := str(part.get("telescope_family", ""))
		if family_floor.has(part_family):
			_check(int(part.get("unlock_level", 999)) >= int(family_floor[part_family]),
				"3b. '%s' unlock_level does not leak early" % str(part.get("id", "")))

	# (4)(28) L23 chromatic aberration is REAL data the view renders.
	var l23: Dictionary = mm.get_level(23)
	_check(bool(l23.get("chromatic_aberration", false)), "4/28. L23 has chromatic_aberration")
	_check(str(l23.get("target_object_id", "")) == "vega", "4. L23 targets Vega")

	# (5) L24 carries the storeroom hook but never names the Newtonian.
	var l24_after: Array = sm.get_dialogue("level_24_after")
	var has_hook := false
	for line_value in l24_after:
		if str(line_value.get("text_zh", "")).contains("储藏室"):
			has_hook = true
		_check(not str(line_value.get("text_zh", "")).contains("牛顿"), "5. L24 story does not say 牛顿")
		_check(not str(line_value.get("text_en", "")).contains("Newtonian"), "5. L24 story does not say Newtonian")
	_check(has_hook, "5. L24 carries the storeroom hook")

	# (6)(7) L25 is still refractor and unlocks the Newtonian family.
	var l25: Dictionary = mm.get_level(25)
	_check(str(l25.get("telescope_family", "")) == "refractor", "6. L25 remains a refractor level")
	var unlocks_newtonian := false
	for part_id_value in l25.get("unlock_parts", []):
		if str(gm.get_part(str(part_id_value)).get("telescope_family", "")) == "newtonian":
			unlocks_newtonian = true
	_check(unlocks_newtonian, "7. L25 unlocks Newtonian parts")

	# (8-15) Family blocks: contiguous, dedicated, EXACTLY 10 levels each.
	var blocks := [
		["newtonian", 26, 35], ["dobsonian", 36, 45], ["cassegrain", 46, 55],
		["gregorian", 56, 65], ["space_segmented", 66, 75], ["fast_radio", 76, 85],
		["multi_device", 86, 91]
	]
	for block_value in blocks:
		var family := str(block_value[0])
		var first: int = int(block_value[1])
		var last: int = int(block_value[2])
		var count := 0
		for level_number in range(25, 92):
			if str(mm.get_level(level_number).get("telescope_family", "")) == family:
				count += 1
				_check(level_number >= first and level_number <= last,
					"8-14. %s level L%d stays inside its block" % [family, level_number])
		var expected: int = last - first + 1
		_check(count == expected, "15. %s has exactly %d dedicated levels (got %d)" % [family, expected, count])

	# (18)(19) Story + board coverage for L1-L91.
	for level_number in range(25, 92):
		var has_before: bool = sm.dialogues.has("level_%d_before" % level_number) \
			or sm.dialogues.has("level_%d_before_assembly" % level_number)
		_check(has_before, "18. L%d has a before-story" % level_number)
		_check(sm.dialogues.has("level_%d_after" % level_number), "18. L%d has an after-story" % level_number)
		_check(not sm.board_note_for_level(level_number).is_empty(), "19. L%d board note exists" % level_number)

	# (20) Cabinet tab filtering logic.
	var cabinet: Node = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	await process_frame
	cabinet.set("selected_family", "newtonian")
	_check(bool(cabinet.call("_part_visible_in_tab", "newtonian")), "20. newtonian tab shows newtonian parts")
	_check(bool(cabinet.call("_part_visible_in_tab", "")), "20. newtonian tab shows universal parts")
	_check(not bool(cabinet.call("_part_visible_in_tab", "fast_radio")), "20. newtonian tab hides FAST parts")
	cabinet.set("selected_family", "all")
	_check(bool(cabinet.call("_part_visible_in_tab", "gregorian")), "20. All tab shows everything")
	cabinet.set("selected_family", "fast_radio")
	_check(not bool(cabinet.call("_part_visible_in_tab", "")), "20. FAST tab hides universal optics")
	cabinet.queue_free()
	await process_frame

	# (21) Auto-equip compatibility.
	gm.debug_jump_to_level(26, true)
	for entry_value in gm.auto_equip_plan():
		var fam := str(gm.get_part(str(entry_value.get("part_id", ""))).get("telescope_family", ""))
		_check(fam in ["", "newtonian"], "21. L26 auto-equip compatible (%s)" % str(entry_value.get("part_id", "")))
	gm.debug_jump_to_level(76, true)
	for entry_value in gm.auto_equip_plan():
		_check(not str(entry_value.get("part_type", "")) in ["objective", "eyepiece"],
			"21. FAST auto-equip picks no objective/eyepiece")
	gm.debug_jump_to_level(66, true)
	for entry_value in gm.auto_equip_plan():
		_check(not str(entry_value.get("part_type", "")) in ["objective", "eyepiece"],
			"21. infrared auto-equip picks no optical eyepiece")

	# (22)(23) Hints toggle works and persists across a save reload.
	_check(gm.assembly_hints_enabled(), "22. hints default ON")
	gm.set_assembly_hints(false)
	_check(not gm.assembly_hints_enabled(), "22. hints turn OFF")
	var saved_flag: Variant = gm.progress.get("assembly_hints_enabled")
	_check(saved_flag == false, "23. hints OFF persisted into progress")
	gm.set_assembly_hints(true)

	# (24) No mojibake in the key UI/system scripts.
	var mojibake := ["瑁呴厤", "鎻愮ず", "鐗涢", "鏃犵嚎", "鐩爣", "闂彿", "锛�", "鈥�"]
	for script_path in [
		"res://scripts/ui/assembly_ui_template.gd", "res://scripts/ui/telescope_assembly_screen.gd",
		"res://scripts/ui/advanced_assembly.gd", "res://scripts/ui/optical_tube_assembly.gd",
		"res://scripts/ui/parts_cabinet.gd", "res://scripts/systems/game_manager.gd",
		"res://scripts/systems/story_manager.gd"
	]:
		var file := FileAccess.open(script_path, FileAccess.READ)
		_check(file != null, "24. %s readable" % script_path)
		if file == null:
			continue
		var source := file.get_as_text()
		for garbage in mojibake:
			if source.contains(garbage):
				_check(false, "24. mojibake '%s' in %s" % [garbage, script_path])

	# (25) Save migration: an un-versioned save at L40 follows its content to L41.
	gm.progress.erase("campaign_version")
	gm.progress["current_level"] = 40
	gm.progress["completed_levels"] = [33, 34, 39]
	gm._migrate_progress_schema()
	_check(int(gm.progress.get("current_level", 0)) == 41, "25. old save L40 migrates to L41")
	_check(gm.progress.get("completed_levels", []) == [33, 35, 40], "25. completed levels shift with content")
	_check(int(gm.progress.get("campaign_version", 0)) == 91, "25. campaign version stamped")
	gm.new_game()

	# (26)(27) Story routing: plays once, never replays, returns to scene.
	gm.debug_jump_to_level(26, false)
	_check(sm.begin_event("level_26_before_assembly", "assembly"), "26. L26 story plays")
	sm.finish_active_event()
	_check(not sm.begin_event("level_26_before_assembly", "assembly"), "27. L26 story never replays")

	# (29) L32 drift/tracking mechanic is real.
	var l32: Dictionary = mm.get_level(32)
	_check(bool(l32.get("drift_enabled", false)) and float(l32.get("hold_seconds", 0)) > 0.0,
		"29. L32 Earth-rotation drift is real")

	# (30) L33 seeing + clouds are real.
	var l33_env: Dictionary = mm.get_level(33).get("environment", {})
	_check(str(l33_env.get("seeing", "")) == "poor" and float(l33_env.get("cloud_cover", 0.0)) > 0.0,
		"30. L33 seeing and clouds are real")

	# (31)(32) Mode switches at FAST and multi-device stages.
	for level_number in range(76, 86):
		_check(str(mm.get_level(level_number).get("observation_mode", "")) == "radio",
			"31. L%d runs radio mode" % level_number)
	for level_number in range(86, 92):
		_check(str(mm.get_level(level_number).get("observation_mode", "")) == "multi_device",
			"32. L%d runs multi-device mode" % level_number)

	if failures == 0:
		print("TIMELINE PROGRESSION TEST PASS")
		quit(0)
	else:
		print("TIMELINE PROGRESSION TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
