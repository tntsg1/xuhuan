extends SceneTree

var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)

	var order: Array = gm.tube_subassembly_config().get("order", [])
	var partial := {}
	for index in range(mini(3, order.size())):
		partial[str(order[index])] = true
	gm.update_tube_subassembly_progress(partial)
	await _capture("res://scenes/optical_tube_assembly.tscn", "tube_partially_installed.png")

	var complete := {}
	for subpart_value in order:
		complete[str(subpart_value)] = true
	gm.save_tube_assembly(complete, 100.0, 100.0, false)
	await _capture("res://scenes/optical_tube_assembly.tscn", "tube_all_installed.png")

	for part_type in ["tripod", "mount", "optical_tube_assembly", "finder_scope"]:
		gm.install_part(part_type, 0)
	await _capture("res://scenes/advanced_assembly.tscn", "main_all_installed.png")
	quit(0)


func _capture(scene_path: String, file_name: String) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = load(scene_path).instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	var output_dir := ProjectSettings.globalize_path("res://artifacts/newtonian_texture_acceptance")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	print("CAPTURE %s | result=%s" % [output_path, error_string(error)])
	if error != OK:
		push_error("Failed to save acceptance capture: %s" % error_string(error))
		quit(1)
