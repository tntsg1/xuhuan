extends SceneTree

# Captures the unlock notification chain: mission-complete card with NEW
# PARTS line, then the Maya unlock popup back in the observatory.
# Run WITHOUT --headless. NOTE: resets the save - back it up first.

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
			# Play through to the end of L6 so completing it unlocks the
			# L7 upgrades (100mm lens, stable mount) plus the 10mm eyepiece.
			gm.new_game()
			gm.progress["current_level"] = 6
			gm.call("_unlock_parts_for_current_level")
			gm.progress["pending_unlock_notice"] = []
			gm.call("reset_assembly")
			for part_type in gm.current_level().get("required_parts", []):
				gm.call("install_part", str(part_type), 0)
			gm.set("selected_object_id", "sirius")
			gm.call("evaluate_selected_object")
			gm.call("complete_current_mission", "sirius", gm.get("last_observation"))
		30:
			_shot("un1_mission_complete_new_parts.png")
			gm.call("go", "observatory")
		55:
			_shot("un2_unlock_popup.png")
			quit()
