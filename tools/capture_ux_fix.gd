extends SceneTree

# Captures the 8 UX-fix acceptance screenshots. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			gm.new_game()
			gm.call("try_story_event", "intro", "observatory")
		25:
			gm.call("complete_current_story")
		45:
			# 1. L1 guidance to observation pad after intro
			_shot("ux1_l1_guidance.png")
			gm.progress["current_level"] = 3
			gm.call("_unlock_parts_for_current_level")
			gm.call("try_teaching_intercept", "before_assembly", "observatory")
		60:
			# 2. L3 refractor brief with large diagram
			_shot("ux2_l3_brief.png")
			gm.call("complete_current_brief")
		80:
			# 3. back in the room, guided to the assembly table
			_shot("ux3_l3_guidance.png")
			gm.progress["current_level"] = 5
			gm.call("_unlock_parts_for_current_level")
			gm.call("try_story_for_trigger", "before_observation", "sky")
		100:
			# 4. Jupiter-mission story shows Jupiter, not the Moon
			_shot("ux4_story_target_visual.png")
			gm.call("complete_current_story")
		115:
			gm.progress["current_level"] = 8
			gm.call("_unlock_parts_for_current_level")
			gm.progress["unlocked_parts"].append("basic_finder_scope")
			gm.call("save")
			gm.call("go", "assembly")
		130:
			# 5. seven parts in a scroll list, no overflow (scroll to bottom)
			for scroll in current_scene.find_children("", "ScrollContainer", true, false):
				(scroll as ScrollContainer).scroll_vertical = 400
		140:
			_shot("ux5_assembly_scroll.png")
			gm.call("go", "observatory")
		155:
			current_scene.call("_toggle_stats_terminal")
		165:
			# 6. stats terminal explains Club Credits
			_shot("ux6_stats_terminal.png")
			current_scene.call("_toggle_stats_terminal")
			gm.call("reset_assembly")
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
				gm.call("install_part", part_type, 0)
			gm.set("selected_object_id", "orion_nebula")
			gm.call("go", "telescope")
		185:
			current_scene.call("_set_focus_value", current_scene.get("target_focus_value"))
		195:
			# 7. Orion Nebula at exact focus: sharp, quality message honest
			_shot("ux7_nebula_focus.png")
			gm.call("go", "observatory")
		215:
			# 8. clicking the far-away Parts Cabinet only warns
			current_scene.call("_click_interactable", "cabinet")
		225:
			_shot("ux8_remote_click.png")
			quit()
