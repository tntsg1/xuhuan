extends SceneTree

const OUTPUT_DIR := "res://artifacts/animation_feedback"
var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_observation()
	await _capture_focus()
	await _capture_assembly()
	await _capture_collimation()
	print("ANIMATION VISUAL CAPTURE PASS")
	quit(0)


func _prepare_level(level_number: int) -> void:
	gm.new_game()
	gm.progress["current_level"] = level_number
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		if not gm.unlocked_parts_by_type(part_type).is_empty():
			gm.install_part(part_type, 0)
	gm.selected_object_id = str(gm.current_target_object_id())


func _capture_observation() -> void:
	_prepare_level(4)
	var view: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	await _settle()
	view.call("_set_view_mode", "telescope")
	var sky_item: Dictionary = (view.get("sky_data") as Dictionary).get(str(view.get("target_id")), {})
	view.set("telescope_azimuth", float(sky_item.get("azimuth", 180.0)))
	view.set("telescope_altitude", float(sky_item.get("altitude", 45.0)))
	view.call("_rebuild_view")
	await create_timer(0.22).timeout
	_save("01_scope_target_lock.png")
	view.queue_free()
	await process_frame


func _capture_focus() -> void:
	_prepare_level(8)
	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	await _settle()
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	var tutorial := view.find_child("TutorialHighlight_first_focus_control", true, false)
	if tutorial != null:
		tutorial.queue_free()
	await process_frame
	if bool(view.get("requires_focus")):
		var target := float(view.get("target_focus_value"))
		var tolerance := float(view.get("focus_tolerance"))
		view.call("_set_focus_value", clampf(target + tolerance * 0.85, 0.0, 1.0))
	await create_timer(0.16).timeout
	_save("02_focus_lock_feedback.png")
	view.queue_free()
	await process_frame


func _capture_assembly() -> void:
	gm.new_game()
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	var assembly: Control = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(assembly)
	await _settle()
	assembly.call("_select_part", "tripod")
	assembly.call("_try_install", "tripod")
	await create_timer(0.15).timeout
	_save("03_part_snap_in_motion.png")
	await create_timer(0.55).timeout
	assembly.queue_free()
	await process_frame


func _capture_collimation() -> void:
	_prepare_level(26)
	var view: Control = load("res://scenes/collimation.tscn").instantiate()
	root.add_child(view)
	await _settle()
	view.set("secondary_x", 0.01)
	view.set("secondary_y", 0.0)
	view.set("primary_x", 0.0)
	view.set("primary_y", 0.0)
	view.call("_refresh")
	await create_timer(0.20).timeout
	_save("04_collimation_complete.png")
	view.queue_free()
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.28).timeout


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
