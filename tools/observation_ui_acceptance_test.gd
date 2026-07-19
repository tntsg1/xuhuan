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


func _test_modes() -> void:
	var fovs := []
	var target_sizes := []
	var target_object: Dictionary = gm.get_object(str(view.get("target_id")))
	for mode in ["naked_eye", "finder", "telescope"]:
		view.call("_set_view_mode", mode)
		fovs.append(float(view.get("fov_x")))
		var info: Dictionary = view.call("_object_visual_for_mode", target_object)
		target_sizes.append(float(info.get("size_px", 0.0)))
		var reticle: Control = view.get("scope_reticle_layer")
		_check(reticle != null and str(reticle.get("mode")) == mode, "%s has its own reticle state" % mode)
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
	view.call("_rebuild_view")
	var icons: Dictionary = view.get("object_icons")
	var ring: TextureRect = view.get("target_state_ring")
	_check(icons.has(target_id) and ring != null, "centered target creates a lock ring")
	if icons.has(target_id) and ring != null:
		var icon: TextureRect = icons[target_id]
		var icon_center := icon.position + icon.size * icon.scale * 0.5
		var ring_center := ring.position + ring.size * 0.5
		_check(icon_center.distance_to(ring_center) < 1.5, "target lock ring matches the projected celestial position")


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
