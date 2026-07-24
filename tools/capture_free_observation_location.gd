extends SceneTree

const OUTPUT_DIR := "res://artifacts/free_observation_location"

var save_path := ""
var saved_bytes := PackedByteArray()
var had_save := false


func _initialize() -> void:
	await process_frame
	save_path = ProjectSettings.globalize_path("user://savegame.json")
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(save_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(7, true)
	if gm.target_requires_relocation():
		var rec: Dictionary = gm.recommend_observation_location()
		if not rec.is_empty():
			gm.set_observing_location(rec["site"])

	var sky: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await _settle()
	var target_id := str(sky.get("target_id"))
	var selected_id := _candidate(sky, target_id)
	if selected_id != "":
		var item: Dictionary = (sky.get("sky_data") as Dictionary)[selected_id]
		sky.set("telescope_azimuth", float(item["azimuth"]))
		sky.set("telescope_altitude", clampf(float(item["altitude"]), 1.0, 89.0))
		sky.call("_set_view_mode", "telescope")
		sky.call("_rebuild_view")
		sky.call("_select_object", selected_id)
		sky.call("_open_detail_panel")
	await _settle()
	_save("01_free_observation_selected.png")
	sky.call("_close_detail_panel")
	sky.call("_set_view_mode", "naked_eye")
	sky.set("telescope_altitude", 0.0)
	sky.set("display_altitude", 0.0)
	sky.set("telescope_azimuth", 90.0)
	sky.set("display_azimuth", 90.0)
	sky.call("_rebuild_view")
	await _settle()
	_save("02_horizon_parallax_low_altitude.png")
	sky.queue_free()
	await process_frame

	# Use any currently-down target location so the capture always shows a real
	# recommendation rather than a fabricated teaching coordinate.
	gm.debug_jump_to_level(5, true)
	_force_below_horizon(gm)
	var map: Control = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await _settle()
	map.call("_skip_animation")
	await _settle()
	_save("03_world_map_recommendation.png")
	map.queue_free()
	_restore_save()
	print("FREE OBSERVATION / LOCATION CAPTURES PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _candidate(sky: Node, target_id: String) -> String:
	var gm: Node = root.get_node("/root/GameManager")
	for id_value in (sky.get("sky_data") as Dictionary).keys():
		var id := str(id_value)
		var item: Dictionary = (sky.get("sky_data") as Dictionary)[id]
		if id != target_id and float(item.get("altitude", -90.0)) > 8.0 and not gm.get_object(id).is_empty():
			return id
	return ""


func _force_below_horizon(gm: Node) -> void:
	var radec: Dictionary = gm.current_target_radec()
	if radec.is_empty():
		return
	var service := SkyPositionService.new()
	for site_value in gm.location_sites():
		var site: Dictionary = site_value
		var vis := service.visibility_at(float(radec["ra_hours"]), float(radec["dec_degrees"]), float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
		if bool(vis.get("below_horizon", false)):
			gm.set_observing_location(site)
			return


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.35).timeout


func _save(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + name)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not capture " + path)
	else:
		print("CAPTURE ", path)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
