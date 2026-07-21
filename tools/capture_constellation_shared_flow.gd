extends SceneTree

const OUTPUT_DIR := "res://artifacts/constellation_shared_flow"

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
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(114, true)
	await _capture_finder_search()
	await _capture_telescope_field()
	print("CONSTELLATION SHARED FLOW CAPTURES PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture_finder_search() -> void:
	active_view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(active_view)
	await _settle()
	var target_id := str(active_view.get("target_id"))
	var target: Dictionary = active_view.get("sky_data").get(target_id, {})
	active_view.set("telescope_azimuth", float(target.get("azimuth", 0.0)))
	active_view.set("telescope_altitude", float(target.get("altitude", 45.0)))
	active_view.call("_set_view_mode", "finder")
	active_view.call("_rebuild_view")
	await _settle()
	await _save("01_finder_centered_constellation.png")
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": float(target.get("azimuth", 0.0)),
		"altitude": float(target.get("altitude", 45.0)),
		"view_mode": "finder"
	}
	active_view.queue_free()
	active_view = null
	await process_frame


func _capture_telescope_field() -> void:
	active_view = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(active_view)
	await _settle()
	if active_view.get("quiz_brief_overlay") != null:
		active_view.call("_dismiss_pre_quiz_guide")
	await _settle()
	await _save("02_telescope_constellation_field.png")
	active_view.queue_free()
	active_view = null
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.35).timeout


func _save(file_name: String) -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("CAPTURE ", output_path)
	await process_frame
