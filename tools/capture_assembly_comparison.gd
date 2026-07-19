extends SceneTree

var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(3, false)
	await _capture("res://scenes/telescope_assembly.tscn", "refractor_assembly.png")
	gm.debug_jump_to_level(26, false)
	await _capture("res://scenes/advanced_assembly.tscn", "newtonian_main_assembly.png")
	await _capture("res://scenes/optical_tube_assembly.tscn", "newtonian_tube_assembly.png")
	print("Assembly comparison captures: " + ProjectSettings.globalize_path("res://artifacts/assembly_comparison/"))
	quit(0)


func _capture(scene_path: String, file_name: String) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = load(scene_path).instantiate()
	root.add_child(active_scene)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/assembly_comparison"))
	root.get_texture().get_image().save_png("res://artifacts/assembly_comparison/" + file_name)
