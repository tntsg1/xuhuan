extends SceneTree

# Visual + online-data check for the sky observation dome view.
# Run WITHOUT --headless:
# godot --script res://tools/capture_sky_view.gd
# Saves two captures and prints each object's alt/az/source (never secrets).

const CAPTURE_TARGET := "user://sky_view_capture.png"
const CAPTURE_HORIZON := "user://sky_view_capture_horizon.png"

var frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/sky_observation.tscn")
	root.add_child(scene.instantiate())
	process_frame.connect(_tick)


func _view() -> Node:
	return root.get_child(root.get_child_count() - 1)


func _tick() -> void:
	frames += 1
	if frames == 30:
		# aim the telescope near the mission target and select it
		var view: Node = _view()
		var target_id: String = str(view.get("target_id"))
		var sky_data: Dictionary = view.get("sky_data")
		var item: Dictionary = sky_data.get(target_id, {})
		view.set("telescope_azimuth", float(item.get("azimuth", 180.0)) - 4.0)
		view.set("telescope_altitude", float(item.get("altitude", 45.0)) + 3.0)
		view.call("_rebuild_view")
		view.call("_select_object", target_id)
	if frames == 240:
		# online request has had ~4s; report every object's data source
		var view: Node = _view()
		var sky_data: Dictionary = view.get("sky_data")
		var ids: Array = sky_data.keys()
		ids.sort()
		print("--- object positions after online window ---")
		for id_value in ids:
			var item: Dictionary = sky_data[str(id_value)]
			print("%-14s alt %7.2f  az %7.2f  %s" % [
				str(id_value),
				float(item.get("altitude", 0.0)),
				float(item.get("azimuth", 0.0)),
				str(item.get("source", "?"))
			])
		root.get_texture().get_image().save_png(CAPTURE_TARGET)
		print("saved ", CAPTURE_TARGET)
	if frames == 250:
		# low-altitude aim to show horizon, ground band and compass ribbon
		var view: Node = _view()
		view.set("telescope_altitude", 12.0)
		view.set("telescope_azimuth", 350.0)
		view.call("_rebuild_view")
	if frames == 260:
		root.get_texture().get_image().save_png(CAPTURE_HORIZON)
		print("saved ", CAPTURE_HORIZON)
		quit()
