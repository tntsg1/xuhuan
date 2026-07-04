extends SceneTree

# Verifies: mission-target panel with delta angles, big guidance banner,
# and aim persistence across visits. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0
var saved_azimuth := 0.0


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
			gm.progress["current_level"] = 4
			gm.call("_unlock_parts_for_current_level")
			gm.call("reset_assembly")
			for part_type in gm.current_level().get("required_parts", []):
				gm.call("install_part", str(part_type), 0)
			gm.call("go", "sky")
		40:
			var view: Node = current_scene
			var sky_data: Dictionary = view.get("sky_data")
			var item: Dictionary = sky_data.get("jupiter", {})
			view.set("telescope_azimuth", wrapf(float(item.get("azimuth", 180.0)) - 80.0, 0.0, 360.0))
			view.set("telescope_altitude", clampf(float(item.get("altitude", 45.0)) - 10.0, 0.0, 90.0))
			view.call("_rebuild_view")
			saved_azimuth = float(view.get("telescope_azimuth"))
		55:
			_shot("aimux1_target_panel_banner.png")
			gm.call("go", "observatory")
		80:
			gm.call("go", "sky")
		105:
			var view: Node = current_scene
			var restored: float = float(view.get("telescope_azimuth"))
			print("aim persistence: saved=%.2f restored=%.2f match=%s" % [
				saved_azimuth, restored, absf(restored - saved_azimuth) < 0.01
			])
			_shot("aimux2_restored_aim.png")
			quit()
