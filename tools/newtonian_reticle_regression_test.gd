extends SceneTree

const OUTPUT_DIR := "res://artifacts/newtonian_reticle_acceptance"
const RETICLE_CENTER := Vector2i(403, 383)
const LEVELS := [26, 27, 32, 35]

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"

	for level_number in LEVELS:
		gm.debug_jump_to_level(level_number, true)
		gm.last_sky_aim = {"valid": false}
		var view: Control = load("res://scenes/sky_observation.tscn").instantiate()
		root.add_child(view)
		current_scene = view
		await _settle()
		var target_id: String = str(gm.current_target_object_id())
		var sky_item: Dictionary = (view.get("sky_data") as Dictionary).get(target_id, {})
		view.set("telescope_azimuth", float(sky_item.get("azimuth", 180.0)))
		view.set("telescope_altitude", float(sky_item.get("altitude", 45.0)))
		view.call("_rebuild_view")
		for mode in ["naked_eye", "finder", "telescope"]:
			view.call("_set_view_mode", mode)
			await _settle()
			await _check_reticle(view, level_number, mode)
			if level_number == 26 and mode == "finder":
				await _capture("l26_newtonian_moon_finder_reticle.png")

		if level_number == 26:
			var old_reticle: Control = view.get("scope_reticle_layer")
			old_reticle.queue_free()
			await _settle()
			var rebuilt_reticle: Control = view.get("scope_reticle_layer")
			_check(rebuilt_reticle != null and rebuilt_reticle != old_reticle, "L26 recreates a freed reticle instance")
			await _check_reticle(view, level_number, "telescope after recreation")

		view.queue_free()
		await process_frame

	if failures == 0:
		print("NEWTONIAN RETICLE REGRESSION TEST PASS")
		quit(0)
	else:
		print("NEWTONIAN RETICLE REGRESSION TEST FAIL: ", failures)
		quit(1)


func _check_reticle(view: Control, level_number: int, mode: String) -> void:
	var reticle: Control = view.get("scope_reticle_layer")
	_check(reticle != null and reticle.visible and reticle.is_visible_in_tree(), "L%d %s reticle node is visible" % [level_number, mode])
	if DisplayServer.get_name() == "headless":
		return
	var colored_pixels := _reticle_pixel_count(root.get_texture().get_image())
	_check(colored_pixels >= 80, "L%d %s reticle is rendered (%d pixels)" % [level_number, mode, colored_pixels])


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	_check(root.get_texture().get_image().save_png(output_path) == OK, "saved " + file_name)
	print("CAPTURE ", output_path)


func _reticle_pixel_count(image: Image) -> int:
	var count := 0
	for y in range(RETICLE_CENTER.y - 60, RETICLE_CENTER.y + 61):
		for x in range(RETICLE_CENTER.x - 60, RETICLE_CENTER.x + 61):
			var radius := Vector2(float(x - RETICLE_CENTER.x), float(y - RETICLE_CENTER.y)).length()
			if radius < 48.0 or radius > 56.0:
				continue
			var color := image.get_pixel(x, y)
			if color.r > 0.45 and color.g > 0.35 and color.b < 0.55:
				count += 1
	return count


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
