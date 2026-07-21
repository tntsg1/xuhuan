extends SceneTree

# Round 20: assembly bench part-state synchronization.
# Distinguishes locked / unlocked-not-equipped / equipped-not-installed /
# installed, and proves install uses the SELECTED part id (auto-equipping it).

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")

	# --- L3: focus knob is a REWARD of L3, not shown as an installable card ---
	gm.new_game()
	gm.debug_jump_to_level(3, false)
	_check(not gm.progress.get("unlocked_parts", []).has("basic_focus_knob"), "1. L3 focus knob not yet unlocked")
	_check(gm.unlocked_parts_by_type("focus_knob").is_empty(), "1. L3 shows no focus-knob card")

	# --- Completing L3 unlocks the focus knob ---
	gm.debug_jump_to_level(3, false)
	gm.complete_current_mission("moon", {"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}})
	_check(gm.progress.get("unlocked_parts", []).has("basic_focus_knob"), "2. L3 completion unlocks focus knob")

	# --- L4: focus knob unlocked-but-not-equipped is INSTALLABLE (the bug) ---
	gm.new_game()
	gm.debug_jump_to_level(4, false)
	gm.reset_assembly()
	_check(gm.progress.get("unlocked_parts", []).has("basic_focus_knob"), "3. L4 focus knob unlocked")
	gm.progress["selected_parts"].erase("focus_knob")  # unlocked but not equipped
	_check(str(gm.part_slot_state("focus_knob", "basic_focus_knob")) == "unlocked", "3. state = unlocked (not equipped)")
	var reason := str(gm.install_part_block_reason("focus_knob", "basic_focus_knob"))
	_check(not reason.contains("未解锁") and not reason.to_lower().contains("locked"), "4. unlocked part reason is NOT a locked/unlock message")
	var score: int = gm.install_part("focus_knob", 0, "basic_focus_knob")
	_check(score >= 0, "5. install unlocked-not-equipped focus knob succeeds (auto-equip)")
	_check(str(gm.equipped_part_id("focus_knob")) == "basic_focus_knob", "5. focus knob auto-equipped on install")
	_check(str(gm.part_slot_state("focus_knob")) == "installed", "5. state now installed")

	# --- Install uses the SELECTED part id, not a stale equipped default ---
	gm.new_game()
	gm.debug_jump_to_level(8, false)  # objective_100mm + eyepiece_10mm unlocked
	gm.reset_assembly()
	gm.equip_part("objective_60mm")  # equip the BASIC one first
	var score2: int = gm.install_part("objective", 0, "objective_100mm")  # but select the better one
	_check(score2 >= 0, "6. install objective with explicit better id succeeds")
	var slot: Dictionary = gm.progress.get("assembly_state", {}).get("objective", {})
	_check(str(slot.get("installed_part_id", "")) == "objective_100mm", "6. installed_part_id = the SELECTED part, not the equipped default")

	# --- Genuinely locked part gives a locked message ---
	gm.new_game()
	gm.debug_jump_to_level(4, false)
	var locked_reason := str(gm.install_part_block_reason("objective", "objective_100mm"))  # not unlocked at L4
	_check(locked_reason.contains("解锁") or locked_reason.to_lower().contains("locked"), "7. genuinely locked part gives a locked reason")
	_check(gm.install_part("objective", 0, "objective_100mm") < 0, "7. locked part cannot install")

	# --- Incompatible telescope family message ---
	gm.new_game()
	gm.debug_jump_to_level(4, false)  # refractor level
	# Force-unlock a newtonian-family part to reach the incompatible branch.
	if not gm.progress["unlocked_parts"].has("newtonian_reflector_tube"):
		gm.progress["unlocked_parts"].append("newtonian_reflector_tube")
	var incompat_part: Dictionary = gm.get_part("newtonian_reflector_tube")
	if not incompat_part.is_empty():
		var incompat_reason := str(gm.install_part_block_reason(str(incompat_part.get("type", "tube")), "newtonian_reflector_tube"))
		_check(incompat_reason.contains("牛顿") or incompat_reason.to_lower().contains("newtonian"), "8. incompatible part names the telescope family")
	else:
		_check(true, "8. (no newtonian tube part to test - skipped)")

	# --- Finder scope: unlocked at L5, installable at L6 ---
	gm.new_game()
	gm.debug_jump_to_level(6, false)
	gm.reset_assembly()
	_check(gm.progress.get("unlocked_parts", []).has("basic_finder_scope"), "9. finder unlocked by L6")
	# Install prerequisites in order (equip best unlocked for each), then finder.
	var defaults := {"tripod": "basic_tripod", "mount": "basic_mount", "tube": "starter_tube", "objective": "objective_60mm", "eyepiece": "eyepiece_20mm", "focus_knob": "basic_focus_knob"}
	for pt in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob"]:
		gm.install_part(str(pt), 0, str(defaults[pt]))
	var finder_score: int = gm.install_part("finder_scope", 0, "basic_finder_scope")
	_check(finder_score >= 0, "9. finder scope installs at L6")

	# --- 10. Card-click auto-equips an unlocked part and shows "Equipped" ---
	gm.new_game()
	gm.debug_jump_to_level(4, false)
	gm.reset_assembly()
	gm.progress["selected_parts"].erase("focus_knob")
	var asm: Node = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(asm)
	await process_frame
	asm.call("_select_part", "focus_knob")
	_check(str(gm.equipped_part_id("focus_knob")) == "basic_focus_knob", "10. selecting the card auto-equips the part")
	_check(str(gm.part_slot_state("focus_knob")) == "equipped", "10. state reads 'equipped' after card click")

	# --- 11. Replacing an installed part clears the old install snapshot ---
	gm.debug_jump_to_level(8, false)  # objective_60mm and objective_100mm both unlocked
	gm.reset_assembly()
	gm.install_part("objective", 0, "objective_60mm")
	var slot_a: Dictionary = gm.progress.get("assembly_state", {}).get("objective", {})
	_check(str(slot_a.get("installed_part_id", "")) == "objective_60mm", "11. first install records the 60mm objective")
	gm.install_part("objective", 0, "objective_100mm")  # replace
	var slot_b: Dictionary = gm.progress.get("assembly_state", {}).get("objective", {})
	_check(str(slot_b.get("installed_part_id", "")) == "objective_100mm", "11. replacing overwrites installed_part_id (old state cleared)")
	asm.queue_free()
	await process_frame

	if failures == 0:
		print("ASSEMBLY PART STATE TEST PASS")
		quit(0)
	else:
		print("ASSEMBLY PART STATE TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
