extends SceneTree

const OUTPUT_DIR := "res://artifacts/collimation_optics_feedback"


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.debug_jump_to_level(26, true)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"

	var bench: Control = load("res://scenes/collimation.tscn").instantiate()
	root.add_child(bench)
	current_scene = bench
	await _settle()
	await _capture("01_bench_misaligned_star.png")
	bench.set("secondary_x", 0.0)
	bench.set("secondary_y", 0.0)
	bench.set("primary_x", 0.0)
	bench.set("primary_y", 0.0)
	bench.call("_refresh", true)
	await _settle()
	await _capture("02_bench_aligned_star.png")
	bench.queue_free()
	await process_frame

	gm.selected_object_id = "vega"
	gm.set_collimation_score(20.0)
	var scope: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(scope)
	current_scene = scope
	await _settle()
	scope.call("_dismiss_pre_quiz_guide")
	await create_timer(0.45).timeout
	_set_exact_focus(scope)
	await _settle()
	await _capture("03_scope_poor_collimation.png")

	gm.set_collimation_score(100.0)
	scope.set("observation", scope.call("_evaluate"))
	scope.call("_update_target_visuals")
	await _settle()
	await _capture("04_scope_perfect_collimation.png")
	quit(0)


func _set_exact_focus(scope: Control) -> void:
	scope.set("focus_value", scope.get("target_focus_value"))
	scope.set("focus_error", 0.0)
	scope.set("visual_focus_error", 0.0)
	scope.set("blur_weight", 0.0)
	scope.set("focus_locked", true)
	scope.set("observation", scope.call("_evaluate"))
	scope.call("_refresh_focus_ui")


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	if image.save_png(path) != OK:
		quit(1)
