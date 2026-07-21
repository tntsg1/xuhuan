extends SceneTree

# v2 teaching progression test: naked eye -> refractor -> focus training.
# Run: godot --headless --script res://tools/v2_progression_test.gd
# NOTE: resets the save - back it up before running.

const ObservationSystemScript := preload("res://scripts/systems/observation_system.gd")

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return
	gm.new_game()

	# --- Level 1: naked eye Moon, no telescope needed -----------------------
	_check(int(gm.progress.get("current_level", 0)) == 1, "starts at level 1")
	_check(gm.progress.get("seen_concept_briefs", []).is_empty(), "new game: seen_concept_briefs empty")
	_check(gm.progress.get("completed_concept_cards", []).is_empty(), "new game: completed_concept_cards empty")
	_check(gm.current_observation_mode() == "naked_eye", "L1 observation_mode naked_eye")
	_check(gm.current_requires_telescope() == false, "L1 does not require telescope")
	_check(gm.current_requires_focus() == false, "L1 does not require focus")
	_check(gm.should_show_concept_brief_for_current_level(), "L1 should show eye_imaging brief before observation")
	gm.mark_concept_brief_seen("eye_imaging")
	_check(not gm.should_show_concept_brief_for_current_level(), "L1 brief does not repeat after mark")
	_check(not gm.completed_concept_cards().has("eye_imaging"), "brief seen does not unlock completed concept card")
	var gate: Dictionary = gm.can_enter_observation()
	_check(bool(gate.get("ok", false)), "L1 can enter observation WITHOUT telescope")

	gm.selected_object_id = "moon"
	var naked_moon: Dictionary = gm.evaluate_selected_object()
	_check(str(naked_moon.get("observation_mode", "")) == "naked_eye", "L1 evaluate uses naked eye mode")
	_check(bool(naked_moon.get("success", false)), "naked eye Moon observation succeeds")

	gm.selected_object_id = "andromeda"
	var naked_galaxy: Dictionary = gm.evaluate_selected_object()
	_check(str(naked_galaxy.get("quality", "")) == "Failed", "naked eye Andromeda fails (too faint)")

	gm.selected_object_id = "moon"
	var ok1: bool = gm.complete_current_mission("moon", naked_moon)
	_check(ok1, "L1 mission completes")
	_check(gm.completed_concept_cards().has("eye_imaging"), "L1 unlocks eye_imaging concept card")
	var entry1: Dictionary = gm.progress.get("journal_entries", [])[0]
	_check(str(entry1.get("concept_card_id", "")) == "eye_imaging", "journal records concept card")

	# --- Level 2: naked eye Polaris ------------------------------------------
	_check(int(gm.progress.get("current_level", 0)) == 2, "advanced to level 2")
	_check(gm.current_requires_telescope() == false, "L2 does not require telescope")
	gm.selected_object_id = "polaris"
	var naked_star: Dictionary = gm.evaluate_selected_object()
	_check(bool(naked_star.get("success", false)), "naked eye Polaris succeeds")
	gm.complete_current_mission("polaris", naked_star)
	_check(gm.progress.get("unlocked_equipment_stages", []).has("refractor_basic"), "L2 unlocks refractor_basic stage")

	# --- Level 3: refractor required -----------------------------------------
	_check(int(gm.progress.get("current_level", 0)) == root.get_node("/root/MissionManager").next_level_number(2), "advanced along campaign order after L2")
	gm.debug_jump_to_level(3, false)
	_check(gm.current_observation_mode() == "telescope", "L3 observation_mode telescope")
	_check(gm.current_requires_telescope() == true, "L3 requires telescope")
	_check(gm.should_show_concept_brief_for_current_level(), "L3 should show refractor brief before assembly")
	gm.mark_concept_brief_seen("refractor_light_path")
	_check(not gm.should_show_concept_brief_for_current_level(), "L3 refractor brief does not repeat after mark")
	var gate3: Dictionary = gm.can_enter_observation()
	_check(not bool(gate3.get("ok", true)), "L3 blocked without assembled telescope")
	_check(str(gate3.get("reason_en", "")).contains("Missing"), "L3 block reason lists missing parts")
	var required: Array = gm.current_level().get("required_parts", [])
	_check(required.has("objective") and required.has("eyepiece") and required.size() == 5, "L3 requires 5 refractor core parts")

	gm.reset_assembly()
	for part_type in required:
		gm.install_part(str(part_type), 0)
	_check(bool(gm.can_enter_observation().get("ok", false)), "L3 enterable after assembly")
	gm.selected_object_id = "moon"
	var scope_moon: Dictionary = gm.evaluate_selected_object()
	_check(bool(scope_moon.get("success", false)), "L3 telescope Moon observation succeeds")
	gm.complete_current_mission("moon", scope_moon)
	_check(gm.completed_concept_cards().has("refractor_light_path"), "L3 unlocks refractor_light_path card")
	_check(gm.progress.get("unlocked_parts", []).has("basic_focus_knob"), "L3 unlocks the basic focus knob")

	# --- Level 4: focus training ---------------------------------------------
	_check(int(gm.progress.get("current_level", 0)) == root.get_node("/root/MissionManager").next_level_number(3), "advanced along campaign order after L3")
	gm.debug_jump_to_level(4, false)
	# The jump resets assembly; rebuild the base rig but leave the Focus Knob
	# uninstalled - that untouched gap is exactly what L4 teaches.
	for rebuilt_part in ["tripod", "mount", "tube", "objective", "eyepiece"]:
		gm.install_part(rebuilt_part, 0)
	_check(gm.current_requires_focus() == true, "L4 requires_focus true")
	_check(gm.should_show_concept_brief_for_current_level(), "L4 should show focus brief before telescope view")
	gm.mark_concept_brief_seen("focus_focal_plane")
	_check(not gm.should_show_concept_brief_for_current_level(), "L4 focus brief does not repeat after mark")
	var required4: Array = gm.current_level().get("required_parts", [])
	_check(required4.has("focus_knob"), "L4 required parts include focus_knob")
	var gate4_no_knob: Dictionary = gm.can_enter_observation()
	_check(not bool(gate4_no_knob.get("ok", true)), "L4 blocked before Focus Knob is installed")
	_check(str(gate4_no_knob.get("reason_en", "")).contains("Focus"), "L4 missing reason mentions Focus Knob")
	var state4: Dictionary = gm.progress.get("assembly_state", {})
	_check(not bool(state4.get("focus_knob", {}).get("installed", false)), "Focus Knob starts uninstalled at L4")
	gm.install_part("focus_knob", 0)
	_check(bool(gm.can_enter_observation().get("ok", false)), "L4 enterable after installing Focus Knob")

	var stats: Dictionary = gm.calculate_stats()
	_check(float(stats.get("focus_control_score", 0.0)) > 0.0, "Focus Knob contributes focus_control_score")
	var jupiter: Dictionary = gm.get_object("jupiter")
	var sharp: Dictionary = ObservationSystemScript.evaluate(stats, jupiter, {
		"observation_mode": "telescope", "focus_error": 0.0, "requires_focus": true, "focus_tolerance": 0.05
	})
	var blurred: Dictionary = ObservationSystemScript.evaluate(stats, jupiter, {
		"observation_mode": "telescope", "focus_error": 0.30, "requires_focus": true, "focus_tolerance": 0.05
	})
	var order: Array = ["Failed", "Poor", "Fair", "Good", "Excellent"]
	var sharp_rank: int = order.find(str(sharp.get("quality", "Failed")))
	var blurred_rank: int = order.find(str(blurred.get("quality", "Failed")))
	print("  focus check: sharp=%s blurred=%s" % [sharp.get("quality"), blurred.get("quality")])
	_check(sharp_rank > blurred_rank, "large focus_error lowers observation quality")
	_check(bool(blurred.get("out_of_focus", false)), "focus_error above tolerance flags out_of_focus")
	_check(not str(blurred.get("quality", "")) in ["Excellent", "Good"], "out of focus cannot be Excellent/Good")
	_check(str(blurred.get("feedback_en", "")).contains("focus"), "out of focus feedback mentions the knob")

	# --- deep-sky focus must be solvable (spec 7.5) -----------------------------
	# When focus_value equals target_focus_value the focus must be acceptable,
	# even if overall quality stays Fair with basic parts.
	gm.selected_object_id = "orion_nebula"
	var view_scene: PackedScene = load("res://scenes/telescope_view.tscn")
	var focus_probe: Node = view_scene.instantiate()
	# telescope_view reads requires_focus from the current level (L4 here).
	root.add_child(focus_probe)
	focus_probe.call("_set_focus_value", focus_probe.get("target_focus_value"))
	_check(float(focus_probe.get("focus_tolerance")) >= 0.06, "deep-sky focus tolerance widened (>= 0.06)")
	_check(bool(focus_probe.call("is_focus_acceptable")), "orion_nebula at exact target focus is acceptable")
	_check(str(focus_probe.call("_focus_state")) == "sharp", "orion_nebula at exact target focus reads as sharp")
	var probe_feedback: String = str(focus_probe.call("_current_feedback"))
	_check(not probe_feedback.contains("Adjust focus"), "in-focus nebula never asks to adjust focus again")
	focus_probe.queue_free()
	gm.selected_object_id = ""

	# --- L7/L8 Orion Nebula balance -------------------------------------------
	gm.progress["current_level"] = 7
	gm.call("_unlock_parts_for_current_level")
	gm.equip_part("objective_60mm")
	gm.equip_part("basic_mount")
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "orion_nebula"
	var l7_probe: Node = view_scene.instantiate()
	root.add_child(l7_probe)
	l7_probe.call("_set_focus_value", l7_probe.get("target_focus_value"))
	_check(str(l7_probe.get("observation").get("quality", "")) == "Fair", "L7 basic Orion quality is Fair")
	_check(bool(l7_probe.call("is_focus_acceptable")), "L7 Orion focus acceptable at exact target")
	_check(bool(l7_probe.call("can_identify_object")), "L7 focused Fair Orion can be identified")
	l7_probe.queue_free()

	gm.progress["current_level"] = 8
	gm.call("_unlock_parts_for_current_level")
	gm.equip_part("objective_60mm")
	gm.equip_part("basic_mount")
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "orion_nebula"
	var l8_basic_probe: Node = view_scene.instantiate()
	root.add_child(l8_basic_probe)
	l8_basic_probe.call("_set_focus_value", l8_basic_probe.get("target_focus_value"))
	var l8_basic_feedback: String = str(l8_basic_probe.call("_current_feedback"))
	var l8_basic_feedback_lower := l8_basic_feedback.to_lower()
	_check(str(l8_basic_probe.get("observation").get("quality", "")) == "Fair", "L8 basic Orion remains Fair")
	_check(not bool(l8_basic_probe.call("can_identify_object")), "L8 Fair Orion cannot complete aperture lesson")
	_check(l8_basic_feedback_lower.contains("aperture") or l8_basic_feedback_lower.contains("stable") or l8_basic_feedback_lower.contains("equipment") or l8_basic_feedback_lower.contains("equip"), "L8 focused-but-low-quality feedback names equipment")
	_check(not l8_basic_feedback.contains("Adjust focus"), "L8 focused-but-low-quality feedback does not ask to refocus")
	l8_basic_probe.queue_free()

	gm.equip_part("objective_100mm")
	gm.equip_part("stable_mount")
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	var l8_upgrade_probe: Node = view_scene.instantiate()
	root.add_child(l8_upgrade_probe)
	l8_upgrade_probe.call("_set_focus_value", l8_upgrade_probe.get("target_focus_value"))
	_check(bool(l8_upgrade_probe.call("can_identify_object")), "L8 upgraded focused Orion can be identified")
	l8_upgrade_probe.queue_free()

	# --- learning cards data --------------------------------------------------
	for card_id in ["eye_imaging", "refractor_light_path", "focus_focal_plane"]:
		var card: Dictionary = gm.get_learning_card(card_id)
		_check(not card.is_empty(), "learning card exists: " + card_id)
		_check(ResourceLoader.exists(str(card.get("image", ""))), "diagram image exists: " + card_id)

	if failures == 0:
		print("V2 PROGRESSION TEST PASS")
		quit(0)
	else:
		print("V2 PROGRESSION TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
