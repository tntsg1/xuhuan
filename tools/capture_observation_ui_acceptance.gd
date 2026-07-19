extends SceneTree

const OUTPUT_DIR := "res://artifacts/observation_ui_acceptance"

var gm: Node
var active_view: Control


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("GameManager autoload is missing")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_sky_states()
	await _capture_telescope_states()
	print("OBSERVATION UI CAPTURES PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture_sky_states() -> void:
	gm.debug_jump_to_level(14, true)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.last_sky_aim = {"valid": false}
	active_view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(active_view)
	await _settle()
	# Let the one-shot online callback finish, then replace only the acceptance
	# target coordinates so every lock-state capture is deterministic.
	await create_timer(1.25).timeout
	var target_id := str(active_view.get("target_id"))
	var target_az := 180.0
	var target_alt := 45.0
	var sky_data: Dictionary = active_view.get("sky_data")
	var target: Dictionary = sky_data.get(target_id, {}).duplicate(true)
	target["azimuth"] = target_az
	target["altitude"] = target_alt
	target["direction_text"] = "S"
	target["visibility_text"] = "Acceptance fixture"
	target["source"] = "acceptance"
	sky_data[target_id] = target
	active_view.set("sky_data", sky_data)

	for mode in ["naked_eye", "finder", "telescope"]:
		active_view.set("telescope_azimuth", target_az)
		active_view.set("telescope_altitude", target_alt)
		active_view.call("_set_view_mode", mode)
		active_view.call("_rebuild_view")
		await _settle_short()
		await _save("01_mode_%s.png" % mode)

	active_view.call("_set_view_mode", "telescope")
	active_view.set("telescope_azimuth", wrapf(target_az + 5.0, 0.0, 360.0))
	active_view.set("telescope_altitude", target_alt)
	active_view.call("_rebuild_view")
	await _settle_short()
	await _save("02_target_outside_view.png")

	active_view.set("telescope_azimuth", wrapf(target_az + 1.0, 0.0, 360.0))
	active_view.call("_rebuild_view")
	await _settle_short()
	await _save("03_target_approach.png")

	active_view.set("telescope_azimuth", target_az)
	active_view.call("_rebuild_view")
	await _settle_short()
	await _save("04_target_locked.png")

	active_view.call("_set_view_mode", "naked_eye")
	active_view.set("telescope_altitude", 45.0)
	for azimuth in [0.0, 90.0, 180.0, 270.0]:
		active_view.set("telescope_azimuth", azimuth)
		active_view.call("_rebuild_view")
		await _settle_short()
		await _save("05_azimuth_%03d.png" % int(azimuth))

	active_view.set("telescope_azimuth", 180.0)
	for altitude in [0.0, 30.0, 60.0, 90.0]:
		active_view.set("telescope_altitude", altitude)
		active_view.call("_rebuild_view")
		await _settle_short()
		await _save("06_altitude_%02d.png" % int(altitude))

	active_view.queue_free()
	active_view = null
	await process_frame


func _capture_telescope_states() -> void:
	_prepare_tracking_level()
	active_view = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(active_view)
	await _settle()
	if active_view.get("quiz_brief_overlay") != null:
		active_view.call("_dismiss_pre_quiz_guide")
	await create_timer(0.16).timeout
	for child in active_view.find_children("TutorialHighlight_*", "", true, false):
		child.queue_free()
	await process_frame
	var target_focus := float(active_view.get("target_focus_value"))
	active_view.call("_set_focus_value", target_focus)

	for state in [
		{"name": "07_tracking_off.png", "rate": 0.0},
		{"name": "08_tracking_matched.png", "rate": 1.0},
		{"name": "09_tracking_too_fast.png", "rate": 1.6},
	]:
		gm.set_tracking_rate(float(state["rate"]))
		active_view.call("_refresh_drift_ui")
		await _settle_short()
		await _save(str(state["name"]))

	gm.set_tracking_rate(1.0)
	active_view.call("_refresh_drift_ui")
	active_view.call("_set_focus_value", clampf(target_focus + 0.20, 0.0, 1.0))
	await _settle_short()
	await _save("10_focus_defocused.png")
	active_view.call("_set_focus_value", target_focus)
	await _settle_short()
	await _save("11_focus_sharp.png")

	active_view.queue_free()
	active_view = null
	await process_frame


func _prepare_tracking_level() -> void:
	gm.new_game()
	gm.progress["current_level"] = 23
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	for part_id in ["objective_100mm", "eyepiece_10mm", "tracking_mount", "basic_focus_knob", "basic_finder_scope", "basic_tripod", "starter_tube"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
		gm.equip_part(part_id)
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "jupiter"
	gm.set_tracking_rate(0.0)


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.30).timeout


func _settle_short() -> void:
	await process_frame
	await process_frame
	await create_timer(0.20).timeout


func _save(file_name: String) -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("CAPTURE ", output_path)
	await process_frame
