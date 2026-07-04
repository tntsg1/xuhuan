extends SceneTree

# Captures the three-stage sky observation flow. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.
# Shots: naked eye / finder / telescope alignment / target out of view /
# target centered and ready.

var frames := 0
var view: Node


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _aim_at_target(az_offset: float, alt_offset: float) -> void:
	var target_id: String = str(view.get("target_id"))
	var sky_data: Dictionary = view.get("sky_data")
	var item: Dictionary = sky_data.get(target_id, {})
	view.set("telescope_azimuth", wrapf(float(item.get("azimuth", 180.0)) + az_offset, 0.0, 360.0))
	view.set("telescope_altitude", clampf(float(item.get("altitude", 45.0)) + alt_offset, 0.0, 90.0))
	view.call("_rebuild_view")


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			# Level 4 setup: telescope + finder + focus knob all assembled.
			gm.new_game()
			gm.progress["current_level"] = 4
			gm.call("_unlock_parts_for_current_level")
			gm.progress["unlocked_parts"].append("basic_finder_scope")
			gm.call("reset_assembly")
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
				gm.call("install_part", part_type, 0)
			var packed: PackedScene = load("res://scenes/sky_observation.tscn")
			view = packed.instantiate()
			root.add_child(view)
		40:
			# 1. naked eye, target out of view (aim far away)
			_aim_at_target(150.0, 10.0)
			view.call("_update_guidance")
		50:
			_shot("ts_naked_out_of_view.png")
			# 2. naked eye with target in view
			_aim_at_target(20.0, 8.0)
		60:
			_shot("ts_naked_eye.png")
			# 3. finder mode, target slightly off center
			view.call("_set_view_mode", "finder")
			_aim_at_target(5.0, 3.0)
		70:
			_shot("ts_finder.png")
			# 4. telescope mode, off center
			view.call("_set_view_mode", "telescope")
			_aim_at_target(1.2, 0.8)
			var target_id: String = str(view.get("target_id"))
			view.call("_select_object", target_id)
		80:
			_shot("ts_telescope_off.png")
			# 5. telescope mode, centered
			_aim_at_target(0.1, -0.05)
		90:
			_shot("ts_telescope_centered.png")
			quit()
