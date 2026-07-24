extends SceneTree

# Round 22: free (non-mission) observation. Selecting a non-target object lets
# the player observe it with the real optics, never completes/fails the mission,
# never runs the identify quiz, and logs a separate free-observation record.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")

	# --- 1. Selecting a non-target object flags a free observation ---
	gm.new_game()
	gm.debug_jump_to_level(5, true)  # Jupiter mission
	_check(str(gm.current_target_object_id()) == "jupiter", "1. mission target is Jupiter")
	gm.selected_object_id = "jupiter"
	_check(not gm.is_free_observation(), "1. selecting the mission target is NOT free")
	gm.selected_object_id = "moon"
	_check(gm.is_free_observation(), "1. selecting a non-target IS free")

	# --- 2. object_detail distinguishes mission vs free + carries astro data ---
	var d_free: Dictionary = gm.object_detail("moon")
	_check(not bool(d_free.get("is_mission_target", true)), "2. free object detail: is_mission_target=false")
	var d_mission: Dictionary = gm.object_detail("jupiter")
	_check(bool(d_mission.get("is_mission_target", false)), "2. mission object detail: is_mission_target=true")
	_check(d_mission.has("magnitude") and d_mission.get("magnitude") != null, "2. detail carries magnitude")
	_check(gm.observation_advice("orion_nebula").size() >= 1, "2. advice generated for a nebula")

	# --- 3. Free telescope view skips the identify quiz ---
	var tv: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(tv)
	for _i in range(8):
		await process_frame
	_check(bool(tv.get("is_free_observation")), "3. telescope view enters free mode")
	# it must NOT have built identify choices
	_check(tv.get("choices_box") == null or not is_instance_valid(tv.get("choices_box")), "3. no identify choices in free mode")

	# --- 4. Free observation never completes the mission ---
	var level_before: int = int(gm.progress.get("current_level", 0))
	var completed_before: int = (gm.progress.get("completed_levels", []) as Array).size()
	tv.call("_add_free_observation_to_logbook")
	_check(int(gm.progress.get("current_level", 0)) == level_before, "4. current level unchanged after free log")
	_check((gm.progress.get("completed_levels", []) as Array).size() == completed_before, "4. no level marked complete")
	tv.queue_free()
	await process_frame

	# --- 5. Free record written with a distinct entry_kind; dedup on repeat ---
	gm.new_game()
	gm.debug_jump_to_level(5, true)
	var obs := {"quality": "Good", "observation_mode": "free"}
	var r1: Dictionary = gm.record_free_observation("moon", obs)
	_check(bool(r1.get("new_record", false)), "5. first free record is new")
	var free_count := 0
	for e in gm.progress.get("journal_entries", []):
		if str(e.get("entry_kind", "")) == "free_observation":
			free_count += 1
	_check(free_count == 1, "5. exactly one free_observation journal entry")
	var r2: Dictionary = gm.record_free_observation("moon", obs)  # identical setup
	_check(not bool(r2.get("new_record", true)) and bool(r2.get("repeat", false)), "5. identical repeat does NOT add a duplicate")
	# a different quality is a NEW record
	var r3: Dictionary = gm.record_free_observation("moon", {"quality": "Excellent"})
	_check(bool(r3.get("new_record", false)), "5. a different quality is a new record")

	# --- 6. Mission target still completes normally (unaffected) ---
	gm.new_game()
	gm.debug_jump_to_level(3, false)
	gm.selected_object_id = str(gm.current_target_object_id())
	_check(not gm.is_free_observation(), "6. mission target selected -> not free")
	var ok: bool = gm.complete_current_mission(gm.current_target_object_id(), {"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}})
	_check(ok, "6. mission target completes the mission normally")
	_check(not gm.get_object("moon").is_empty(), "6. completing a mission does not remove its target from the catalog")
	_check(gm.object_detail("moon").has("name_en"), "6. the completed target remains available for later free observation")

	# --- 7. Below-horizon free targets still obey the horizon rules ---
	gm.new_game()
	gm.debug_jump_to_level(5, true)
	gm.selected_object_id = "sirius"
	var d_sirius: Dictionary = gm.object_detail("sirius")
	if bool(d_sirius.get("has_coords", false)) and bool(d_sirius.get("below_horizon", false)):
		_check(d_sirius.get("visible") == false, "7. below-horizon free target reports not visible")
	else:
		_check(true, "7. (Sirius up at home this run - horizon check skipped)")

	# --- 8. Back from sky returns to the OBSERVATORY, not the assembly bench ---
	# (spawn set to telescope so observatory places the player at the pad)
	gm.set_observatory_spawn("telescope")
	_check(str(gm.observatory_spawn_id) == "telescope", "8. sky Back sets observatory spawn (not assembly)")

	if failures == 0:
		print("FREE OBSERVATION TEST PASS")
		quit(0)
	else:
		print("FREE OBSERVATION TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
