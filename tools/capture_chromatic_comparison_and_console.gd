extends SceneTree

var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"

	_prepare_level(gm, 22)
	await _capture_telescope("l22_refractor_chromatic_sirius.png")

	_prepare_level(gm, 24)
	await _capture_telescope("l24_refractor_chromatic_andromeda.png")

	_prepare_level(gm, 25)
	await _capture_telescope("l25_refractor_chromatic_aberration.png")

	_prepare_level(gm, 27)
	gm.set_collimation_score(92.0)
	await _capture_telescope("l27_newtonian_clean_vega.png")

	gm.debug_jump_to_level(45, false)
	await _replace_scene(load("res://scripts/ui/developer_console.gd").new())
	await _capture("developer_console_l1_l45_english.png")
	quit(0)


func _prepare_level(gm: Node, level_number: int) -> void:
	gm.new_game()
	for number in range(1, level_number + 1):
		gm.debug_jump_to_level(number, false)
	gm.debug_jump_to_level(level_number, true)


func _capture_telescope(file_name: String) -> void:
	var gm := root.get_node("/root/GameManager")
	gm.selected_object_id = gm.current_target_object_id()
	await _replace_scene(load("res://scenes/telescope_view.tscn").instantiate())
	active_scene.set("focus_error", 0.0)
	active_scene.set("visual_focus_error", 0.0)
	active_scene.set("focus_locked", true)
	active_scene.call("_update_target_visuals")
	if active_scene.get("quiz_brief_overlay") != null:
		active_scene.call("_dismiss_pre_quiz_guide")
		await process_frame
	# Freeze a normal-brightness, best-focus visual for comparison. Progression
	# tests may intentionally leave the save with zero quality stats.
	active_scene.set_process(false)
	var observation: Dictionary = active_scene.get("observation")
	observation["quality"] = "Excellent"
	observation["visual_effect"] = "clear"
	active_scene.set("observation", observation)
	active_scene.set("visual_base_alpha", 1.0)
	active_scene.set("blur_weight", 0.0)
	active_scene.call("_update_target_visuals")
	await _capture(file_name)


func _replace_scene(scene: Node) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = scene
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	await process_frame
	await process_frame


func _capture(file_name: String) -> void:
	var output_dir := ProjectSettings.globalize_path("res://artifacts/chromatic_comparison")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	print("CAPTURE %s | result=%s" % [output_path, error_string(error)])
	if error != OK:
		quit(1)
