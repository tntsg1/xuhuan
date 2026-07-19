extends SceneTree

const ASSET_DIR := "res://assets/ui/observation/suc/processed/"

var failures := 0
var view: Control
var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		quit(1)
		return
	_setup_level()
	view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	_test_assets_and_layers()
	_test_live_scales()
	_test_pointer_extremes()
	_test_modes()
	_test_availability_and_environment()
	_test_target_lock_alignment()
	_test_language_and_input_math()
	print("OBSERVATION UI ACCEPTANCE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _setup_level() -> void:
	gm.new_game()
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	if not gm.progress["unlocked_parts"].has("basic_finder_scope"):
		gm.progress["unlocked_parts"].append("basic_finder_scope")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		gm.install_part(part_type, 0)


func _test_assets_and_layers() -> void:
	_check(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "keep", "window scaling preserves pixel-art aspect ratio")
	var names := [
		"1.png", "2.png", "3.png", "eye_large_center.png", "finder_second_ring.png",
		"azimuth_scale_shell.png", "altitude_scale_shell.png",
		"azimuth_tick_major.png", "azimuth_tick_minor.png",
		"altitude_tick_major.png", "altitude_tick_minor.png",
		"azimuth_pointer.png", "altitude_pointer.png",
		"mode_eye_icon.png", "mode_finder_icon.png", "mode_scope_icon.png",
		"target_approach_ring.png", "target_lock_ring.png",
		"focus_knob_ui.png", "tracking_rate_knob.png", "tracking_enabled_icon.png",
	]
	for file_name in names:
		var path: String = ASSET_DIR + str(file_name)
		_check(ResourceLoader.exists(path) and load(path) is Texture2D, "%s loads as Texture2D" % file_name)
	var az_ticks: Array = view.get("az_ticks")
	var alt_ticks: Array = view.get("alt_ticks")
	_check(not az_ticks.is_empty() and az_ticks[0] is TextureRect, "azimuth uses supplied texture ticks")
	_check(not alt_ticks.is_empty() and alt_ticks[0] is TextureRect, "altitude uses supplied texture ticks")
	_check(view.get("az_target_pointer") is TextureRect, "one independent azimuth pointer exists")
	_check(view.get("alt_target_pointer") is TextureRect, "one independent altitude pointer exists")
	var reticle := view.get("scope_reticle_layer") as TextureRect
	_check(reticle != null and reticle.get_rect().get_center().distance_to(Vector2(315.0, 280.0)) < 0.1, "reticle center matches the celestial projection center")
	_check(reticle != null and reticle.position.y + reticle.size.y <= 486.0, "reticle stays above the bottom guidance band")
	for file_name in ["eye_large_center.png", "finder_second_ring.png", "3.png", "target_approach_ring.png", "target_lock_ring.png"]:
		var image: Image = (load(ASSET_DIR + file_name) as Texture2D).get_image()
		var center := Vector2i(image.get_width() / 2, image.get_height() / 2)
		_check(image.get_pixelv(center).a < 0.15, "%s keeps the celestial target center transparent" % file_name)
	var finder_image: Image = (load(ASSET_DIR + "finder_second_ring.png") as Texture2D).get_image()
	_check(_visible_pixels_outside_annulus(finder_image, 105.0, 122.0) == 0, "Finder artwork contains only the second circular ring")
	var eye_image: Image = (load(ASSET_DIR + "eye_large_center.png") as Texture2D).get_image()
	_check(_visible_pixels_in_annulus(eye_image, 31.0, 44.0) > 80, "Eye artwork contains the enlarged center aperture")
	var object_icons: Dictionary = view.get("object_icons")
	if not object_icons.is_empty():
		var first_icon := object_icons.values()[0] as TextureRect
		_check(first_icon.z_index < (view.get("cloud_layer") as Control).z_index, "atmosphere is above celestial targets")
	_check((view.get("cloud_layer") as Control).z_index < reticle.z_index, "atmosphere remains below aiming artwork")
	_check(reticle.z_index < (view.get("az_readout") as Label).z_index, "dynamic readouts remain above aiming artwork")
	_check((view.get("az_readout") as Label).z_index < (view.get("guidance_banner") as Label).z_index, "bottom guidance remains the top sky-viewport layer")


func _first_visible_tick_position(property_name: String) -> Vector2:
	for tick in view.get(property_name):
		if tick.visible:
			return tick.position
	return Vector2(-9999, -9999)


func _north_label_position() -> Vector2:
	for label in view.get("az_labels"):
		if label.visible and str(label.text).begins_with("N"):
			return label.position
	return Vector2(-9999, -9999)


func _test_live_scales() -> void:
	var az_before := _first_visible_tick_position("az_ticks")
	view.call("_apply_aim_delta", 4.0, 0.0)
	var az_after := _first_visible_tick_position("az_ticks")
	_check(az_before != az_after, "A/D aim moves the actual azimuth tick textures")
	var alt_before := _first_visible_tick_position("alt_ticks")
	view.call("_apply_aim_delta", 0.0, 3.0)
	var alt_after := _first_visible_tick_position("alt_ticks")
	_check(alt_before != alt_after, "W/S aim moves the actual altitude tick textures")

	view.set("telescope_azimuth", 359.5)
	view.call("_rebuild_view")
	var north_before := _north_label_position()
	view.call("_apply_aim_delta", 1.0, 0.0)
	var north_after := _north_label_position()
	_check(float(view.get("telescope_azimuth")) < 1.0, "azimuth wraps from 359 to 0")
	_check(north_before.x > -1000.0 and north_after.x > -1000.0 and absf(north_after.x - north_before.x) < 20.0, "0/360 scale crossing is visually continuous")
	for tick in view.get("az_ticks"):
		if tick.visible:
			_check(tick.position.x >= -1.0 and tick.position.x + tick.size.x <= 603.0, "azimuth tick remains clipped to its band")
	for tick in view.get("alt_ticks"):
		if tick.visible:
			_check(tick.position.y >= -1.0 and tick.position.y + tick.size.y <= 531.0, "altitude tick remains clipped to its band")


func _test_pointer_extremes() -> void:
	var az_pointer := view.get("az_target_pointer") as TextureRect
	var alt_pointer := view.get("alt_target_pointer") as TextureRect
	_check(az_pointer.flip_v, "azimuth pointer tip is oriented downward")
	_check(is_equal_approx(alt_pointer.rotation, PI * 0.5), "altitude pointer tip is oriented toward the sky window")
	var az_positions: Array[float] = []
	for azimuth in [0.0, 90.0, 180.0, 270.0, 359.0]:
		view.set("display_azimuth", azimuth)
		view.call("_update_scale_asset_state")
		az_positions.append(az_pointer.position.x)
	_check(az_positions[0] < az_positions[1] and az_positions[1] < az_positions[2] and az_positions[2] < az_positions[3] and az_positions[3] < az_positions[4], "Az 0/90/180/270/359 move the pointer monotonically across the scale")
	var alt_positions: Array[float] = []
	for altitude in [0.0, 30.0, 60.0, 90.0]:
		view.set("display_altitude", altitude)
		view.call("_update_scale_asset_state")
		alt_positions.append(alt_pointer.position.y)
	_check(alt_positions[0] > alt_positions[1] and alt_positions[1] > alt_positions[2] and alt_positions[2] > alt_positions[3], "Alt 0/30/60/90 move upward without reversing")


func _test_modes() -> void:
	var fovs := []
	var target_sizes := []
	var target_object: Dictionary = gm.get_object(str(view.get("target_id")))
	for mode in ["naked_eye", "finder", "telescope"]:
		view.call("_set_view_mode", mode)
		fovs.append(float(view.get("fov_x")))
		var info: Dictionary = view.call("_object_visual_for_mode", target_object)
		target_sizes.append(float(info.get("size_px", 0.0)))
		var reticle := view.get("scope_reticle_layer") as TextureRect
		var expected_path := "res://assets/ui/observation/suc/processed/%s.png" % ({"naked_eye": "eye_large_center", "finder": "finder_second_ring", "telescope": "3"}[mode])
		_check(reticle != null and reticle.texture != null and reticle.texture.resource_path == expected_path, "%s uses exactly one supplied reticle texture" % mode)
	_check(fovs == [120.0, 28.0, 6.0], "Eye/Finder/Scope FOV values remain 120/28/6")
	_check(target_sizes[0] < target_sizes[1] and target_sizes[1] < target_sizes[2], "target is smallest in Eye and largest in Scope")


func _test_availability_and_environment() -> void:
	var finder_state: Dictionary = gm.progress["assembly_state"].get("finder_scope", {}).duplicate(true)
	gm.progress["assembly_state"]["finder_scope"] = {"installed": false}
	var unavailable: Dictionary = view.call("_mode_available", "finder")
	_check(not bool(unavailable.get("ok", true)), "Finder is unavailable when no finder is installed")
	gm.progress["assembly_state"]["finder_scope"] = finder_state
	var cloud_layer: Control = view.get("cloud_layer")
	var view_layer: Control = view.get("view_layer")
	_check(cloud_layer != null and cloud_layer.get_parent() == view_layer, "clouds are clipped inside the sky viewport")
	_check(view_layer.position.x + view_layer.size.x < 752.0, "cloud viewport cannot cover the right mission panel")


func _test_target_lock_alignment() -> void:
	var target_id := str(view.get("target_id"))
	var sky_data: Dictionary = view.get("sky_data")
	var target: Dictionary = sky_data.get(target_id, {})
	view.set("telescope_azimuth", float(target.get("azimuth", 180.0)))
	view.set("telescope_altitude", float(target.get("altitude", 45.0)))
	view.call("_set_view_mode", "telescope")
	view.set("telescope_azimuth", wrapf(float(target.get("azimuth", 180.0)) + 1.0, 0.0, 360.0))
	view.call("_rebuild_view")
	var approach_ring := view.get("target_state_ring") as TextureRect
	var approach_size := approach_ring.size if approach_ring != null else Vector2.ZERO
	_check(str(view.get("target_lock_state")) == "approach" and approach_ring != null and approach_ring.texture.resource_path.ends_with("target_approach_ring.png"), "near target shows only the approach ring")
	_check((view.get("observe_button") as Button).disabled, "Observe stays disabled before target lock")

	view.set("telescope_azimuth", float(target.get("azimuth", 180.0)))
	view.call("_rebuild_view")
	var icons: Dictionary = view.get("object_icons")
	var ring: TextureRect = view.get("target_state_ring")
	_check(icons.has(target_id) and ring != null, "centered target creates a lock ring")
	if icons.has(target_id) and ring != null:
		var icon: TextureRect = icons[target_id]
		var icon_center := icon.position + icon.size * icon.scale * 0.5
		var ring_center := ring.position + ring.size * 0.5
		_check(icon_center.distance_to(ring_center) < 1.5, "target lock ring matches the projected celestial position")
		_check(ring.texture.resource_path.ends_with("target_lock_ring.png"), "centered target replaces approach with the lock ring")
		_check(ring.size.x > maxf(icon.size.x * icon.scale.x, icon.size.y * icon.scale.y), "lock ring remains larger than the rendered celestial target")
		_check(ring.size == approach_size, "approach and lock states keep one consistent target-derived frame size")
	_check(not (view.get("observe_button") as Button).disabled, "Observe enables from the same centered-target condition")


func _test_language_and_input_math() -> void:
	gm.language_mode = "en"
	view.call("_update_scales")
	_check(str(view.get("az_readout").text).begins_with("Az "), "English dynamic azimuth readout is English")
	gm.language_mode = "zh"
	view.call("_update_scales")
	_check(str(view.get("alt_readout").text).contains("°"), "Chinese mode retains dynamic DMS values")
	gm.language_mode = "en"
	view.set("telescope_azimuth", 100.0)
	view.set("telescope_altitude", 40.0)
	view.call("_apply_aim_delta", 2.5, -1.25)
	_check(is_equal_approx(float(view.get("telescope_azimuth")), 102.5) and is_equal_approx(float(view.get("telescope_altitude")), 38.75), "mouse and keyboard share the same aim-delta path")
	gm.set_observatory_spawn("telescope")
	_check(gm.take_observatory_spawn() == "telescope", "return route restores the player at the telescope")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


func _visible_pixels_in_annulus(image: Image, inner_radius: float, outer_radius: float) -> int:
	var center := Vector2(image.get_width(), image.get_height()) * 0.5
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var radius := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if radius >= inner_radius and radius <= outer_radius and image.get_pixel(x, y).a >= 0.1:
				count += 1
	return count


func _visible_pixels_outside_annulus(image: Image, inner_radius: float, outer_radius: float) -> int:
	var center := Vector2(image.get_width(), image.get_height()) * 0.5
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var radius := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if (radius < inner_radius or radius > outer_radius) and image.get_pixel(x, y).a >= 0.1:
				count += 1
	return count
