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
	gm.update_tube_subassembly_progress({})
	await _capture("tube_initial.png")

	var order: Array = gm.tube_subassembly_config().get("order", [])
	var partial := {}
	for index in range(mini(3, order.size())):
		partial[str(order[index])] = true
	gm.update_tube_subassembly_progress(partial)
	await _capture("tube_three_parts.png")

	var complete := {}
	for subpart_value in order:
		complete[str(subpart_value)] = true
	gm.update_tube_subassembly_progress(complete)
	await _capture("tube_all_installed_acceptance.png")
	print("Newtonian tube state captures: " + ProjectSettings.globalize_path("res://artifacts/newtonian_tube/"))
	quit(0)


func _capture(file_name: String) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	var output_dir := ProjectSettings.globalize_path("res://artifacts/newtonian_tube")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var error := root.get_texture().get_image().save_png(output_dir.path_join(file_name))
	print("CAPTURE %s | result=%s" % [output_dir.path_join(file_name), error_string(error)])
	if error != OK:
		push_error("Failed to save Newtonian tube capture: %s" % error_string(error))
