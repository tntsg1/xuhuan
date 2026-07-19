extends SceneTree

var frames := 0
var view: Control


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 10:
		var gm := root.get_node("/root/GameManager")
		gm.new_game()
		gm.progress["current_level"] = 4
		gm.call("_unlock_parts_for_current_level")
		if not gm.progress["unlocked_parts"].has("basic_finder_scope"):
			gm.progress["unlocked_parts"].append("basic_finder_scope")
		gm.reset_assembly()
		for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
			gm.install_part(part_type, 0)
		view = load("res://scenes/sky_observation.tscn").instantiate()
		root.add_child(view)
	if frames == 35:
		view.call("_set_view_mode", "finder")
		var target: Dictionary = view.get("sky_data").get(str(view.get("target_id")), {})
		view.set("telescope_azimuth", wrapf(float(target.get("azimuth", 180.0)) + 4.0, 0.0, 360.0))
		view.set("telescope_altitude", clampf(float(target.get("altitude", 45.0)) + 2.0, 0.0, 90.0))
		view.call("_rebuild_view")
	if frames == 50:
		_capture_window("sky_finder_1280x720.png")
		quit()


func _capture_window(file_name: String) -> void:
	var source := root.get_texture().get_image()
	source.convert(Image.FORMAT_RGBA8)
	var window_size := DisplayServer.window_get_size()
	var scale_factor := minf(float(window_size.x) / source.get_width(), float(window_size.y) / source.get_height())
	var content_size := Vector2i(roundi(source.get_width() * scale_factor), roundi(source.get_height() * scale_factor))
	source.resize(content_size.x, content_size.y, Image.INTERPOLATE_NEAREST)
	var captured := Image.create_empty(window_size.x, window_size.y, false, Image.FORMAT_RGBA8)
	captured.fill(Color.BLACK)
	var offset := (window_size - content_size) / 2
	captured.blit_rect(source, Rect2i(Vector2i.ZERO, content_size), offset)
	var output_dir := ProjectSettings.globalize_path("res://artifacts/observation_ui_acceptance/1280x720")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join(file_name)
	var error := captured.save_png(output_path)
	print("WINDOW CAPTURE %s size=%s result=%s" % [output_path, captured.get_size(), error_string(error)])
