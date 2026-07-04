extends SceneTree

# Verifies mode-based render scales and the focus/quality message fix.
# Run WITHOUT --headless. NOTE: resets the save - back it up first.
# Setup: Level 8 (Orion Nebula, requires_focus) with BASIC parts, so the
# overall quality stays below Good even when focus is sharp.

var frames := 0
var view: Node


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _aim_at(object_id: String, az_offset: float, alt_offset: float) -> void:
	var sky_data: Dictionary = view.get("sky_data")
	var item: Dictionary = sky_data.get(object_id, {})
	view.set("telescope_azimuth", wrapf(float(item.get("azimuth", 180.0)) + az_offset, 0.0, 360.0))
	view.set("telescope_altitude", clampf(float(item.get("altitude", 45.0)) + alt_offset, 0.0, 90.0))
	view.call("_rebuild_view")


func _swap(scene_path: String) -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load(scene_path)
	view = packed.instantiate()
	root.add_child(view)


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			gm.new_game()
			gm.progress["current_level"] = 8
			gm.call("_unlock_parts_for_current_level")
			# force BASIC parts only -> low light for a nebula
			for part_pair in [["objective", "objective_60mm"], ["eyepiece", "eyepiece_20mm"], ["mount", "basic_mount"]]:
				gm.progress["selected_parts"][part_pair[0]] = part_pair[1]
			gm.call("reset_assembly")
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
				gm.call("install_part", part_type, 0)
			_swap("res://scenes/sky_observation.tscn")
		40:
			# naked eye near the nebula (stars should be tiny dots, nebula faint)
			_aim_at("orion_nebula", 6.0, 3.0)
		50:
			_shot("fix_naked_scale.png")
			view.call("_set_view_mode", "finder")
			_aim_at("orion_nebula", 2.0, 1.0)
		60:
			_shot("fix_finder_scale.png")
			# telescope view with sharp focus but low quality
			gm.set("selected_object_id", "orion_nebula")
			_swap("res://scenes/telescope_view.tscn")
		80:
			view.call("_set_focus_value", view.get("target_focus_value"))
		90:
			_shot("fix_view_sharp_lowq.png")
			print("quality=", view.get("observation").get("quality"),
				" can_identify=", view.call("can_identify_object"))
			view.call("_identify", "orion_nebula")
			print("after identify: completed_levels=", gm.progress.get("completed_levels"))
		100:
			_shot("fix_view_after_identify.png")
			quit()
