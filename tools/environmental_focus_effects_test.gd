extends SceneTree

const OUTPUT_DIR := "res://artifacts/environmental_focus_acceptance"

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(20, true)
	# Keep this visual test on the refractor configuration used by L20. A
	# mature save can contain later reflector families, which makes the debug
	# helper's "last unlocked" choice unsuitable for this earlier lesson.
	for part_id in [
		"basic_tripod",
		"stable_mount",
		"starter_tube",
		"objective_100mm",
		"eyepiece_20mm",
		"basic_finder_scope",
		"basic_focus_knob"
	]:
		gm.equip_part(part_id)
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = gm.current_target_object_id()

	view = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	for index in range(5):
		await process_frame
	view.call("_dismiss_pre_quiz_guide")
	await process_frame

	var environment: Dictionary = gm.current_environment()
	_check(str(environment.get("sky_brightness", "")) == "city", "L20 keeps the city-sky lesson")
	_check(str(environment.get("seeing", "")) == "average", "L20 restores average atmospheric seeing")
	_check(float(environment.get("cloud_cover", 0.0)) > 0.0, "L20 restores moving cloud cover")
	_check(float(view.get("cond_turbulence")) > 0.1, "telescope view activates atmospheric turbulence")
	_check((view.get("cloud_nodes") as Array).size() > 0, "telescope view creates moving cloud sprites")

	var target := float(view.get("target_focus_value"))
	var tolerance := float(view.get("focus_tolerance"))
	view.call("_set_focus_value", target)
	var blur_exact := float(view.call("_target_blur_weight"))
	view.call("_set_focus_value", target + tolerance * 0.5)
	var blur_half := float(view.call("_target_blur_weight"))
	view.call("_set_focus_value", target + tolerance)
	var blur_edge := float(view.call("_target_blur_weight"))
	view.call("_set_focus_value", target + tolerance * 1.8)
	var blur_outside := float(view.call("_target_blur_weight"))
	_check(is_zero_approx(blur_exact), "exact focal plane is fully sharp")
	_check(blur_half > blur_exact and blur_half < blur_edge, "focus blur changes continuously inside the success tolerance")
	_check(blur_outside > blur_edge, "moving farther from focus increases blur")

	view.call("_set_focus_value", target)
	view.call("_apply_breathing_and_jitter", 1.0)
	var atmosphere_blur: TextureRect = view.get("blur_overlay")
	_check(atmosphere_blur != null and atmosphere_blur.modulate.a > 0.0, "average seeing adds visible blur breathing even at mechanical focus")
	await _settle_visuals()
	await _capture("l20_focused_with_atmosphere_and_clouds.png")

	view.call("_set_focus_value", clampf(target + tolerance * 1.8, 0.0, 1.0))
	view.set("focus_guide_active", false)
	view.call("_update_focus_novice_guide")
	view.call("_apply_breathing_and_jitter", 1.0)
	await _settle_visuals()
	await _capture("l20_defocused_with_atmosphere_and_clouds.png")

	if failures == 0:
		print("ENVIRONMENTAL FOCUS EFFECTS TEST PASS")
		quit(0)
	else:
		print("ENVIRONMENTAL FOCUS EFFECTS TEST FAIL: ", failures)
		quit(1)


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	_check(error == OK, "saved " + file_name)
	print("CAPTURE ", output_path)


func _settle_visuals() -> void:
	# The clear and blurred target textures cross-fade by design. Let that
	# transition finish so each acceptance image represents its requested state.
	for frame in range(30):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
