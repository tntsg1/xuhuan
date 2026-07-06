extends SceneTree

const OUT_ASSEMBLY := "user://parts_asset_assembly.png"
const OUT_BASIC := "user://parts_asset_assembly_basic.png"


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.progress = gm.default_progress()
	gm.progress["current_level"] = 8
	gm.progress["unlocked_parts"] = [
		"basic_tripod",
		"basic_mount",
		"starter_tube",
		"objective_60mm",
		"eyepiece_20mm",
		"basic_focus_knob",
		"basic_finder_scope",
		"eyepiece_10mm",
		"objective_100mm",
		"stable_mount"
	]
	gm.progress["selected_parts"]["mount"] = "stable_mount"
	gm.progress["selected_parts"]["objective"] = "objective_100mm"
	gm.progress["selected_parts"]["eyepiece"] = "eyepiece_10mm"
	gm.progress["assembly_state"] = gm.call("_fresh_assembly_state")
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		gm.progress["assembly_state"][part_type] = {
			"installed": true,
			"alignment_score": 100,
			"wrong_attempts": 0
		}
	gm.progress["telescope_ready"] = true

	var scene: Control = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT_ASSEMBLY)
	print("saved ", OUT_ASSEMBLY)

	scene.queue_free()
	await process_frame
	gm.progress["selected_parts"]["mount"] = "basic_mount"
	gm.progress["selected_parts"]["objective"] = "objective_60mm"
	gm.progress["selected_parts"]["eyepiece"] = "eyepiece_20mm"
	scene = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT_BASIC)
	print("saved ", OUT_BASIC)
	quit()
