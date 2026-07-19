extends SceneTree

var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(34, false)
	_unlock_and_select_gregorian(gm)
	await _capture_scene("res://scenes/optical_tube_assembly.tscn", "gregorian_sub_blueprint_open.png")
	var complete := {}
	for subpart_value in gm.tube_subassembly_config().get("order", []):
		complete[str(subpart_value)] = true
	gm.save_tube_assembly(complete, 100.0, 100.0, false)
	await _capture_scene("res://scenes/optical_tube_assembly.tscn", "gregorian_sub_blueprint_complete.png")
	gm.reset_assembly()
	gm.install_part("tripod", 0)
	gm.install_part("mount", 0)
	gm.install_part("optical_tube_assembly", 0)
	await _capture_scene("res://scenes/advanced_assembly.tscn", "gregorian_main_assembly_complete.png")
	print("Gregorian screenshots: " + ProjectSettings.globalize_path("res://artifacts/gregorian/"))
	quit(0)


func _unlock_and_select_gregorian(gm: Node) -> void:
	for part_id_value in gm.tube_subassembly_config().get("ids", []):
		var part_id := str(part_id_value)
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
		gm.equip_part(part_id)
	for part_id in ["basic_tripod", "gregorian_equatorial_mount"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
		gm.equip_part(part_id)


func _capture_scene(scene_path: String, file_name: String) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = load(scene_path).instantiate()
	root.add_child(active_scene)
	await process_frame
	await process_frame
	var output_dir := "res://artifacts/gregorian"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.get_texture().get_image().save_png(output_dir + "/" + file_name)
