extends SceneTree

const OUTPUT_DIR := "res://artifacts/l25_reticle_acceptance"
var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.debug_jump_to_level(25, true)
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.last_sky_aim = {"valid": false}

	view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await _settle()
	await _check_mode("naked_eye", "l25_zh_eye_reticle.png")
	await _check_mode("finder", "l25_zh_finder_reticle.png")
	await _check_mode("telescope", "l25_zh_scope_reticle.png")

	# Rebuild the live scene exactly as the language button does. This catches
	# stale/deferred UI children that a simple visible-property test misses.
	gm.cycle_language()
	await _settle()
	gm.cycle_language()
	await _settle()
	var rebuilt_reticle: Control = view.get("scope_reticle_layer")
	rebuilt_reticle.visible = false
	await process_frame
	_check(rebuilt_reticle.visible, "hidden reticle self-recovers on the next frame")
	await _check_mode("naked_eye", "l25_zh_eye_reticle_after_language_rebuild.png")

	if failures == 0:
		print("L25 RETICLE REGRESSION TEST PASS")
		quit(0)
	else:
		print("L25 RETICLE REGRESSION TEST FAIL: ", failures)
		quit(1)


func _check_mode(mode: String, file_name: String) -> void:
	view.call("_set_view_mode", mode)
	await _settle()
	var reticle: Control = view.get("scope_reticle_layer")
	_check(reticle != null and reticle.visible and reticle.is_visible_in_tree(), "%s reticle node is visible" % mode)
	if reticle is TextureRect and reticle.texture != null:
		var texture_image: Image = reticle.texture.get_image()
		var colored_pixels := _reticle_pixel_count(texture_image)
		_check(colored_pixels >= 80, "%s supplied reticle contains visible pixels (%d)" % [mode, colored_pixels])
	if DisplayServer.get_name() == "headless":
		return
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	_check(image.save_png(output_path) == OK, "saved " + file_name)
	print("CAPTURE ", output_path)


func _reticle_pixel_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a >= 0.2:
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
