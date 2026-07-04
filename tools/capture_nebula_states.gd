extends SceneTree

# Captures the three Orion Nebula focus states. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0
var view: Node


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _open_view(gm: Node) -> void:
	if view != null:
		view.queue_free()
	gm.set("selected_object_id", "orion_nebula")
	var packed: PackedScene = load("res://scenes/telescope_view.tscn")
	view = packed.instantiate()
	root.add_child(view)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			gm.new_game()
			gm.progress["current_level"] = 7
			gm.call("_unlock_parts_for_current_level")
			gm.call("reset_assembly")
			for part_type in gm.current_level().get("required_parts", []):
				gm.call("install_part", str(part_type), 0)
			_open_view(gm)
		35:
			# 1. out of focus (initial state is deliberately blurred)
			_shot("nf1_out_of_focus.png")
			view.call("_set_focus_value", view.get("target_focus_value"))
		50:
			# 2. focus aligned, quality still Fair (basic parts)
			_shot("nf2_aligned_low_quality.png")
			gm.call("equip_part", "objective_100mm")
			gm.call("equip_part", "stable_mount")
			gm.call("reset_assembly")
			for part_type in gm.current_level().get("required_parts", []):
				gm.call("install_part", str(part_type), 0)
			_open_view(gm)
		70:
			view.call("_set_focus_value", view.get("target_focus_value"))
		80:
			# 3. focus aligned AND quality acceptable (upgraded parts)
			_shot("nf3_aligned_ready.png")
			quit()


func _initialize() -> void:
	process_frame.connect(_tick)
