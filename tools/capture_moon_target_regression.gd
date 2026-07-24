extends SceneTree

const OUTPUT_DIR := "res://artifacts/moon_target_regression"

var gm: Node
var sky_view: Control


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.debug_jump_to_level(12, true)
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.selected_object_id = ""
	gm.last_sky_aim = {"valid": true, "azimuth": 180.0, "altitude": 45.0, "view_mode": "naked_eye"}
	sky_view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky_view)
	_set_moon_fixture(250.0, 45.0, "calculated")
	await _settle()
	_clear_tutorial_overlays()
	await process_frame
	await _save("01_moon_outside_fov.png")

	sky_view.set("telescope_azimuth", 250.0)
	sky_view.set("telescope_altitude", 45.0)
	sky_view.call("_rebuild_view")
	await _settle()
	await _save("02_moon_in_view_locked.png")

	sky_view.call("_set_view_mode", "finder")
	sky_view.call("_rebuild_view")
	await _settle()
	await _save("03_moon_after_mode_switch.png")

	var service: RefCounted = sky_view.get("sky_service")
	service.config["offline_mode"] = true
	_set_moon_fixture(250.0, 45.0, "calculated")
	sky_view.call("_update_selected_text")
	sky_view.call("_rebuild_view")
	await _settle()
	await _save("04_moon_api_offline_local.png")
	print("MOON TARGET CAPTURES PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _set_moon_fixture(azimuth: float, altitude: float, source: String) -> void:
	var sky: Dictionary = sky_view.get("sky_data")
	var moon: Dictionary = sky.get("moon", {}).duplicate(true)
	moon["azimuth"] = azimuth
	moon["altitude"] = altitude
	moon["visible"] = true
	moon["below_horizon"] = false
	moon["direction_text"] = "W"
	moon["source"] = source
	sky["moon"] = moon
	sky_view.set("sky_data", sky)
	gm.publish_sky_positions(sky)
	sky_view.call("_rebuild_view")


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.30).timeout


func _clear_tutorial_overlays() -> void:
	for child in root.find_children("TutorialHighlight_*", "", true, false):
		child.queue_free()


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	else:
		print("CAPTURE ", output)
	await process_frame
