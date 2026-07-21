extends SceneTree

# Story flow test: Astronomy Club narrative layer.
# Run: godot --headless --script res://tools/story_flow_test.gd
# NOTE: resets the save - back it up before running.

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		print("FAIL: autoloads missing")
		quit(1)
		return
	gm.new_game()

	# --- intro ----------------------------------------------------------------
	_check(gm.progress.get("seen_story_events", []).is_empty(), "new game: seen_story_events empty")
	_check(not sm.has_seen("intro", gm.progress), "intro not seen at start")
	_check(gm.try_story_event("intro", "observatory"), "intro plays on new game")
	_check(_scene_is("story_dialogue"), "intro routed to story dialogue scene")
	_check(sm.active_lines.size() >= 3, "intro has multiple lines")
	gm.complete_current_story()
	await process_frame
	_check(gm.progress.get("seen_story_events", []).has("intro"), "intro recorded in seen_story_events")
	_check(_scene_is("observatory_room"), "intro returns to observatory")
	_check(str(gm.room_guidance_target) == "telescope", "intro guides player to observation pad")
	_check(not gm.try_story_event("intro", "observatory"), "intro does not replay")

	# --- L1: story -> concept brief -> sky ------------------------------------
	_check(gm.try_story_for_trigger("before_observation", "sky"), "L1 before_observation story plays")
	_check(_scene_is("story_dialogue"), "L1 story on dialogue scene")
	gm.complete_current_story()
	await process_frame
	_check(gm.progress.get("seen_story_events", []).has("level_1_before"), "level_1_before recorded")
	_check(_scene_is("learning_card"), "L1 story chains into concept brief")
	_check(gm.current_learning_card_mode() == "brief", "chained card is a brief")
	gm.complete_current_brief()
	await process_frame
	_check(_scene_is("sky_observation"), "device-triggered brief continues straight to sky observation")
	_check(not gm.try_story_for_trigger("before_observation", "sky"), "L1 story does not replay")

	# --- L1 mission complete carries Maya recap --------------------------------
	gm.selected_object_id = "moon"
	var naked_moon: Dictionary = gm.evaluate_selected_object()
	_check(gm.complete_current_mission("moon", naked_moon), "L1 mission completes")
	var recap: String = str(gm.last_learning_card.get("maya_recap_en", ""))
	_check(recap.contains("retina"), "mission complete payload has Maya recap")
	_check(str(gm.room_guidance_target) == "telescope", "mission complete sets next-step room guidance")
	await process_frame

	# --- finish L2, then L3 assembly story -------------------------------------
	gm.selected_object_id = "polaris"
	gm.complete_current_mission("polaris", gm.evaluate_selected_object())
	await process_frame
	gm.debug_jump_to_level(3, false)
	_check(int(gm.progress.get("current_level", 0)) == 3, "at level 3")
	_check(gm.try_story_for_trigger("before_assembly", "assembly"), "L3 before_assembly story plays")
	gm.complete_current_story()
	await process_frame
	_check(gm.progress.get("seen_story_events", []).has("level_3_before_assembly"), "level_3_before_assembly recorded")
	_check(_scene_is("learning_card"), "L3 story chains into refractor brief")
	gm.complete_current_brief()
	await process_frame
	_check(_scene_is("telescope_assembly"), "device-triggered L3 brief continues straight to assembly")
	_check(not gm.try_story_for_trigger("before_assembly", "assembly"), "L3 story does not replay")

	# --- finish L3, then L4 focus story ----------------------------------------
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "moon"
	gm.complete_current_mission("moon", gm.evaluate_selected_object())
	await process_frame
	gm.debug_jump_to_level(4, false)
	_check(int(gm.progress.get("current_level", 0)) == 4, "at level 4")
	gm.selected_object_id = "jupiter"
	_check(gm.try_story_for_trigger("before_focus", "telescope"), "L4 before_focus story plays")
	gm.complete_current_story()
	await process_frame
	_check(gm.progress.get("seen_story_events", []).has("level_4_before_focus"), "level_4_before_focus recorded")
	_check(_scene_is("learning_card"), "L4 story chains into focus brief")
	_check(gm.selected_object_id == "jupiter", "selection survives story + brief chain")
	gm.complete_current_brief()
	await process_frame
	_check(_scene_is("telescope_view"), "L4 focus brief continues straight to telescope view")
	_check(not gm.try_story_for_trigger("before_focus", "telescope"), "L4 story does not replay")

	# --- board notes ------------------------------------------------------------
	var note: Dictionary = gm.mission_board_note()
	_check(str(note.get("en", "")) != "", "mission board has a Maya note for current level")

	if failures == 0:
		print("STORY FLOW TEST PASS")
		quit(0)
	else:
		print("STORY FLOW TEST FAIL (%d failures)" % failures)
		quit(1)


func _scene_is(name_part: String) -> bool:
	var scene: Node = current_scene
	if scene == null:
		return false
	return str(scene.scene_file_path).contains(name_part)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
