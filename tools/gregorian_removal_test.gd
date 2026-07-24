extends SceneTree

# Round 29: Gregorian family removed. Cassegrain -> Infrared -> FAST directly.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	var mm: Node = root.get_node("/root/MissionManager")
	gm.new_game()

	# --- 1. Campaign order skips Gregorian: 55 -> 66 ---
	_check(mm.order_index(55) >= 0, "1. Cassegrain finale L55 is in the campaign")
	_check(mm.next_level_number(55) == 66, "1. after L55 the campaign jumps straight to L66 (Infrared)")
	for g in range(56, 66):
		_check(mm.order_index(g) < 0, "1. Gregorian L%d is NOT in the campaign order" % g)
	_check(mm.order_index(66) >= 0 and mm.order_index(76) >= 0, "1. Infrared (66) and FAST (76) still in the campaign")
	_check(mm.next_level_number(75) == 76, "1. Infrared finale L75 -> FAST L76")

	# --- 2. Developer panel + level list exclude Gregorian ---
	var levels: Array = gm.available_level_numbers()
	var greg_visible := false
	for g in range(56, 66):
		if levels.has(g):
			greg_visible = true
	_check(not greg_visible, "2. developer level list hides all Gregorian levels")

	# --- 3. Cabinet tabs + telescope types have no Gregorian ---
	var cabinet := load("res://scripts/ui/parts_cabinet.gd")
	var tabs = cabinet.FAMILY_TABS
	var tab_ids: Array = []
	for t in tabs:
		tab_ids.append(str((t as Array)[0]))
	_check(not tab_ids.has("gregorian"), "3. Parts Cabinet has no Gregorian tab")
	_check(tab_ids.has("cassegrain") and tab_ids.has("space_segmented") and tab_ids.has("fast_radio"), "3. Cassegrain/Infrared/FAST tabs still present")
	var types := load("res://scripts/ui/telescope_types.gd")
	var fam_ids: Array = []
	for entry in types.FAMILIES:
		fam_ids.append(str((entry as Dictionary)["id"]))
	_check(not fam_ids.has("gregorian"), "3. Telescope Types browse has no Gregorian")
	_check(fam_ids.has("cassegrain") and fam_ids.has("space_segmented") and fam_ids.has("fast_radio"), "3. Cassegrain/Infrared/FAST families still browsable")

	# --- 4. Gregorian levels are marked deprecated but still exist (save compat) ---
	var l60: Dictionary = mm.get_level(60)
	_check(not l60.is_empty(), "4. Gregorian level data still present (no save crash)")
	_check(bool(l60.get("deprecated", false)), "4. Gregorian level flagged deprecated")

	# --- 5. Old save migration: parked on Gregorian -> Infrared, progress kept ---
	gm.new_game()
	gm.progress["campaign_version"] = 92          # pre-removal save
	gm.progress["current_level"] = 60             # a Gregorian level
	gm.progress["credits"] = 777
	gm.progress["completed_levels"] = [46, 47, 55]
	gm.progress["journal_entries"] = [{"object_id": "saturn"}]
	gm.progress["unlocked_parts"].append("gregorian_optical_tube")
	gm._migrate_progress_schema()
	_check(int(gm.progress["current_level"]) == 66, "5. save on Gregorian migrates to the first Infrared level")
	_check(int(gm.progress["credits"]) == 777, "5. credits preserved through migration")
	_check((gm.progress["completed_levels"] as Array).has(55), "5. completed levels preserved")
	_check((gm.progress["journal_entries"] as Array).size() == 1, "5. logbook preserved")
	_check(not (gm.progress["unlocked_parts"] as Array).has("gregorian_optical_tube"), "5. Gregorian parts un-unlocked during migration")
	_check(int(gm.progress["campaign_version"]) == 94, "5. campaign version includes post-FAST retirement")

	# --- 6. Non-Gregorian saves untouched ---
	gm.new_game()
	gm.progress["campaign_version"] = 92
	gm.progress["current_level"] = 50             # a Cassegrain level
	gm.progress["credits"] = 500
	gm._migrate_progress_schema()
	_check(int(gm.progress["current_level"]) == 50, "6. a Cassegrain-level save is NOT moved")
	_check(int(gm.progress["credits"]) == 500, "6. its progress is intact")

	# --- 7. Cassegrain still fully intact (8-slot tube, folded path) ---
	gm.new_game()
	gm.debug_jump_to_level(46, false)
	_check((gm.tube_subassembly_config()["order"] as Array).size() == 8, "7. Cassegrain still has its 8-slot folded-path tube")
	_check(str(gm.current_level().get("telescope_family", "")) == "cassegrain", "7. Cassegrain family intact")

	# --- 8. Cassegrain graduation story bridges to Infrared, not Gregorian ---
	var story := load("res://scripts/systems/story_manager.gd")
	var sm: Node = root.get_node("/root/StoryManager")
	var after: Array = sm.get_dialogue("level_55_after")
	var joined := ""
	for line in after:
		joined += " " + str((line as Dictionary).get("text_en", "")).to_lower()
	_check(joined.contains("infrared") or joined.contains("space"), "8. Cassegrain graduation now points to infrared/space")
	_check(not joined.contains("gregorian"), "8. Cassegrain graduation no longer mentions Gregorian")

	if failures == 0:
		print("GREGORIAN REMOVAL TEST PASS")
		quit(0)
	else:
		print("GREGORIAN REMOVAL TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
