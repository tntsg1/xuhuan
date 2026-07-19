extends SceneTree


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(26, true)
	gm.set_collimation_score(92.0)
	gm.selected_object_id = gm.current_target_object_id()
	var scene: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set("focus_error", 0.0)
	scene.set("visual_focus_error", 0.0)
	scene.set("focus_locked", true)
	scene.call("_update_target_visuals")
	await process_frame
	var output_dir := ProjectSettings.globalize_path("res://artifacts/chromatic_comparison")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var error := root.get_texture().get_image().save_png(output_dir.path_join("l26_newtonian_clean_vega.png"))
	print("L26 CAPTURE %s" % error_string(error))
	quit(0 if error == OK else 1)
