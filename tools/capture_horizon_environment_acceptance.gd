extends SceneTree

const OUTPUT_DIR := "res://artifacts/horizon_environment_acceptance"

var gm: Node
var sky: Control
var capture_failures := 0


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1", "first_finder"]
	gm.debug_jump_to_level(7, true)
	gm.suppress_next_world_map_redirect = true
	await _spawn_sky()

	await _shot("01_initial_eye.png", 0.0, 4.0, "naked_eye")
	await _shot("02_rotate_left_90.png", 270.0, 4.0, "naked_eye")
	await _shot("03_rotate_right_90.png", 90.0, 4.0, "naked_eye")
	await _shot("04_rotate_180.png", 180.0, 4.0, "naked_eye")
	await _shot("05_wrap_359.png", 359.0, 4.0, "naked_eye")
	await _shot("06_wrap_001.png", 1.0, 4.0, "naked_eye")
	await _shot("07_pitch_high.png", 1.0, 34.0, "naked_eye")
	await _shot("08_pitch_low.png", 1.0, 0.0, "naked_eye")
	await _shot("09_mode_eye.png", 150.0, 4.0, "naked_eye")
	await _shot("10_mode_finder.png", 150.0, 4.0, "finder")
	await _shot("11_mode_telescope.png", 150.0, 1.0, "telescope")
	await _shot("12_low_power.png", 210.0, 3.0, "naked_eye")
	await _shot("13_high_power.png", 210.0, 1.0, "telescope")
	await _cloud_shot("14_cloud_layer.png", true)
	await _cloud_shot("15_clear_layer.png", false)
	await _shot("16_below_horizon_aim.png", 90.0, -8.0, "naked_eye")

	# A real map return rebuilds Sky Observation at the selected site. Recreate
	# that scene boundary and verify the new site's environment is wired in.
	sky.queue_free()
	await process_frame
	for site_value in gm.location_sites():
		var site: Dictionary = site_value
		if str(site.get("id", "")) == "greenwich":
			gm.set_observing_location(site)
			break
	gm.suppress_next_world_map_redirect = true
	await _spawn_sky()
	await _shot("17_world_map_return_city.png", 180.0, 4.0, "naked_eye")

	sky.queue_free()
	if capture_failures == 0:
		print("HORIZON ENVIRONMENT CAPTURES PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		push_error("HORIZON ENVIRONMENT CAPTURES FAILED: %d images" % capture_failures)
		quit(1)


func _spawn_sky() -> void:
	sky = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await _settle()
	var target_id := str(sky.get("target_id"))
	var positions: Dictionary = sky.get("sky_data")
	if positions.has(target_id):
		var target: Dictionary = positions[target_id]
		target["altitude"] = 42.0
		target["azimuth"] = 225.0
		target["visible"] = true
		target["below_horizon"] = false
		positions[target_id] = target
		sky.set("sky_data", positions)
		sky.call("_rebuild_view")


func _shot(file_name: String, azimuth: float, altitude: float, mode: String) -> void:
	sky.set_process(false)
	sky.set("view_mode", mode)
	sky.call("_apply_view_mode")
	sky.call("_update_mode_buttons")
	sky.set("display_fov_x", sky.get("fov_x"))
	sky.set("display_fov_y", sky.get("fov_y"))
	sky.set("telescope_azimuth", azimuth)
	sky.set("display_azimuth", azimuth)
	sky.set("telescope_altitude", altitude)
	sky.set("display_altitude", altitude)
	sky.call("_rebuild_view", false)
	sky.call("_update_ground")
	sky.call("_ensure_scope_reticle_visible")
	await process_frame
	_save(file_name)


func _cloud_shot(file_name: String, visible_clouds: bool) -> void:
	await _shot(file_name, 120.0, 1.0, "naked_eye")
	var entries: Array = sky.get("horizon_cloud_sprites")
	for entry_value in entries:
		for sprite_value in (entry_value as Dictionary).get("sprites", []):
			var sprite := sprite_value as TextureRect
			sprite.visible = visible_clouds
			sprite.modulate.a = 0.24 if visible_clouds else 0.0
	await process_frame
	_save(file_name)


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.30).timeout


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		capture_failures += 1
		push_error("No rendered viewport for " + path)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		capture_failures += 1
		push_error("Empty rendered image for " + path)
		return
	var error := image.save_png(path)
	if error != OK:
		capture_failures += 1
		push_error("Could not capture " + path)
	else:
		print("CAPTURE ", path)
