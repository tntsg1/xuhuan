extends SceneTree

# Round 19 new-systems acceptance: telescope-type selection, quick-prepare
# readiness report, and the four-phase constellation flow.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()

	# --- 1. Telescope type selection ---------------------------------------
	_check(gm.uses_family_selection() == false, "1a. L1 refractor skips family selection")
	gm.debug_jump_to_level(26, false)
	_check(gm.uses_family_selection(), "1b. L26 newtonian shows family selection")
	gm.debug_jump_to_level(66, false)
	_check(gm.uses_family_selection(), "1c. L66 space/IR shows family selection")
	gm.new_game()
	gm.set_meta("telescope_types_browse", true)
	var types: Node = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(types)
	await process_frame
	_check(bool(types.call("_is_unlocked", types.call("_entry", "refractor"))), "1d. refractor unlocked at start")
	_check(not bool(types.call("_is_unlocked", types.call("_entry", "newtonian"))), "1e. newtonian locked at start")
	types.call("_select", "newtonian")
	_check((types.get("proceed_button") as Button).disabled, "1f. locked family cannot proceed")
	types.queue_free()
	await process_frame

	# --- 2. Quick-prepare readiness report ---------------------------------
	gm.debug_jump_to_level(26, true)  # newtonian: main + tube + collimation
	var r_newt: Dictionary = gm.prepared_readiness_report()
	_check(bool(r_newt.get("main_assembly", false)), "2a. newtonian main assembly complete")
	_check(bool(r_newt.get("tube_interior", false)), "2b. newtonian tube interior complete")
	_check(float(r_newt.get("collimation", -1.0)) >= 80.0, "2c. newtonian collimation written (>=80)")
	_check(bool(r_newt.get("observation_open", false)), "2d. newtonian observation entry open")
	gm.debug_jump_to_level(36, true)  # dobsonian
	var r_dob: Dictionary = gm.prepared_readiness_report()
	_check(bool(r_dob.get("observation_open", false)), "2e. dobsonian prepared and open")
	gm.debug_jump_to_level(92, true)  # refractor expansion (mercury)
	var r_ref: Dictionary = gm.prepared_readiness_report()
	_check(bool(r_ref.get("main_assembly", false)), "2f. L92 refractor main assembly complete")
	_check(bool(r_ref.get("observation_open", false)), "2g. L92 observation entry open")
	gm.debug_jump_to_level(114, true)  # constellation
	var r_con: Dictionary = gm.prepared_readiness_report()
	_check(bool(r_con.get("needs_telescope", false)), "2h. constellation search uses the shared telescope rig")
	_check(bool(r_con.get("observation_open", false)), "2i. constellation entry open")

	# --- 3. Four-phase constellation flow ----------------------------------
	gm.debug_jump_to_level(114, true)
	var con: Node = load("res://scenes/constellation_observation.tscn").instantiate()
	root.add_child(con)
	await process_frame
	_check(str(con.get("target_id")) == "ursa_major", "3a. constellation binds target")
	_check((con.get("pattern") as Array).size() == 7, "3b. seven key stars")
	_check(int(con.call("_phase")) == 0, "3c. starts in IDENTIFY phase")
	con.call("_choose_shape", "cygnus")
	_check(int(con.call("_phase")) == 0, "3d. wrong shape stays in IDENTIFY")
	con.call("_choose_shape", "ursa_major")
	_check(int(con.call("_phase")) == 1, "3e. correct shape advances to CONNECT")
	var order: Array = con.get("ordered_indices")
	con.call("_try_connect_star", int(order[2]))
	_check(int(con.get("completed_edges")) == 0, "3f. out-of-order star rejected")
	for idx in order:
		con.call("_try_connect_star", int(idx))
	_check(int(con.call("_phase")) == 2, "3g. full pattern advances to NAVIGATE")
	_check((con.get("record_button") as Button).disabled, "3h. record locked before aim lock")
	con.set("aim_az", con.get("target_az"))
	con.set("aim_alt", con.get("target_alt"))
	con.call("_update_status")
	_check(int(con.call("_phase")) == 3, "3i. centered aim reaches READY")
	_check(not (con.get("record_button") as Button).disabled, "3j. record unlocked when all conditions met")
	_check(str(con.call("_record_block_reason")) == "", "3k. no block reason at READY")
	con.queue_free()
	await process_frame

	if failures == 0:
		print("EXPANSION PLAYABILITY TEST PASS")
		quit(0)
	else:
		print("EXPANSION PLAYABILITY TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
