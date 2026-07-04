extends SceneTree

# Captures focus-knob + DMS verification screens. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0
var view: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _swap(scene_path: String) -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load(scene_path)
	view = packed.instantiate()
	root.add_child(view)


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			gm.new_game()
			gm.progress["current_level"] = 4
			gm.call("_unlock_parts_for_current_level")
			gm.call("reset_assembly")
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece"]:
				gm.call("install_part", part_type, 0)
			_swap("res://scenes/telescope_assembly.tscn")
		30:
			_shot("fk_assembly.png")
			gm.set("selected_object_id", "jupiter")
			_swap("res://scenes/telescope_view.tscn")
		50:
			_shot("fk_view_no_knob.png")
			gm.call("install_part", "focus_knob", 0)
			gm.set("selected_object_id", "jupiter")
			_swap("res://scenes/telescope_view.tscn")
		70:
			_shot("fk_view_with_knob.png")
			_swap("res://scenes/sky_observation.tscn")
		95:
			var target_id: String = str(view.get("target_id"))
			view.call("_select_object", target_id)
			var sky_data: Dictionary = view.get("sky_data")
			var item: Dictionary = sky_data.get(target_id, {})
			view.set("telescope_azimuth", float(item.get("azimuth", 180.0)) - 8.0)
			view.set("telescope_altitude", float(item.get("altitude", 45.0)) - 6.0)
			view.call("_rebuild_view")
		105:
			_shot("fk_sky_dms.png")
			quit()
