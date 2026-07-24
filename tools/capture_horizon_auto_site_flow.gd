extends SceneTree

const OUTPUT_DIR := "res://artifacts/horizon_auto_site_flow"

var gm: Node
var save_path := ""
var saved_bytes := PackedByteArray()
var had_save := false
var arrival_site: Dictionary = {}
var arrival_visibility: Dictionary = {}


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	_snapshot_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_below_horizon()
	await _capture_recommended_site()
	await _capture_arrival()
	_restore_save()
	print("HORIZON AUTO SITE CAPTURES PASS")
	quit(0)


func _capture_below_horizon() -> void:
	await _clear_scene()
	gm.new_game()
	gm.debug_jump_to_level(1, false)
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1"]
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await process_frame
	var id := str(sky.get("target_id"))
	var data: Dictionary = sky.get("sky_data")
	var item: Dictionary = data.get(id, {}).duplicate(true)
	item["azimuth"] = 178.0
	item["altitude"] = -8.0
	item["below_horizon"] = true
	item["visible"] = false
	data[id] = item
	sky.set("sky_data", data)
	sky.call("_update_selected_text")
	sky.call("_update_guidance")
	sky.call("_redirect_to_world_map_if_needed")
	await create_timer(0.62).timeout
	await _save("01_below_horizon_explanation_1024x768.png")
	var tween: Tween = sky.get("horizon_explanation_tween")
	if tween != null:
		tween.kill()


func _capture_recommended_site() -> void:
	await _clear_scene()
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1"]
	var map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.call("_skip_animation")
	var recommendation: Dictionary = map.get("recommended")
	arrival_site = recommendation.get("site", {}).duplicate(true)
	arrival_visibility = recommendation.duplicate(true)
	await create_timer(0.35).timeout
	await _save("02_recommended_site_ready_1024x768.png")


func _capture_arrival() -> void:
	await _clear_scene()
	var id: String = str(gm.current_target_object_id())
	if not arrival_site.is_empty():
		gm.set_observing_location(arrival_site)
	gm.selected_object_id = id
	gm.selected_object_level = int(gm.progress.get("current_level", 1))
	gm.world_map_arrival_context = {
		"target_id": id,
		"site_id": str(gm.observing_location().get("id", "")),
		"altitude": float(arrival_visibility.get("altitude", 42.0)),
		"azimuth": float(arrival_visibility.get("azimuth", 180.0)),
		"free_observation": false
	}
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await create_timer(0.35).timeout
	await _save("03_arrival_feedback_1024x768.png")


func _clear_scene() -> void:
	for child in root.get_children():
		if child.name not in ["SaveManager", "MissionManager", "TeachingFlowManager", "StoryManager", "GameManager", "AudioManager", "BulletManager", "InteractionFeedback", "TouchInput"]:
			child.queue_free()
	await process_frame


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save " + output)
	else:
		print("CAPTURE ", output)
	await process_frame


func _snapshot_save() -> void:
	save_path = ProjectSettings.globalize_path("user://savegame.json")
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(save_path)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
