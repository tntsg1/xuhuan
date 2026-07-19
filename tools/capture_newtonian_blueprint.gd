extends SceneTree

var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)
	await _capture("res://scenes/advanced_assembly.tscn", "newtonian_main_empty.png")
	var partial := {"reflector_tube": true, "mirror_cell": true, "primary_mirror": true}
	gm.update_tube_subassembly_progress(partial)
	await _capture("res://scenes/optical_tube_assembly.tscn", "tube_partially_installed_acceptance.png")
	var complete := {}
	for subpart_value in gm.tube_subassembly_config().get("order", []):
		complete[str(subpart_value)] = true
	gm.save_tube_assembly(complete, 100.0, 100.0, false)
	gm.install_part("tripod", 0)
	gm.install_part("mount", 0)
	gm.install_part("optical_tube_assembly", 0)
	gm.install_part("finder_scope", 0)
	await _capture("res://scenes/advanced_assembly.tscn", "main_all_installed_acceptance.png")
	print("Newtonian captures: " + ProjectSettings.globalize_path("res://artifacts/newtonian/"))
	quit(0)


func _capture(scene_path: String, file_name: String) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = load(scene_path).instantiate()
	root.add_child(active_scene)
	await process_frame
	await process_frame
	var output_dir := ProjectSettings.globalize_path("res://artifacts/newtonian")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var error := root.get_texture().get_image().save_png(output_dir.path_join(file_name))
	print("CAPTURE %s | result=%s" % [output_dir.path_join(file_name), error_string(error)])
	if error != OK:
		push_error("Failed to save Newtonian capture: %s" % error_string(error))
