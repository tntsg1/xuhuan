extends SceneTree

const OUTPUT_DIR := "res://artifacts/observation_ui_responsibility"

var gm: Node
var touch: Node
var saved_bytes := PackedByteArray()
var save_path := ""
var had_save := false


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	touch = root.get_node("/root/TouchInput")
	save_path = ProjectSettings.globalize_path("user://savegame.json")
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(save_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_lobby(false, "01_lobby_pc_1024x768.png")
	await _capture_mission_board()
	await _capture_sky()
	await _capture_below_horizon()
	await _capture_map_recommendation()
	await _capture_returned_target()
	await _capture_free_details()
	await _capture_telescope_types()
	touch.set_mobile_mode(false)
	_restore_save()
	print("OBSERVATION UI RESPONSIBILITY CAPTURES PASS")
	quit(0)


func _capture_lobby(mobile: bool, file_name: String) -> void:
	await _clear_root()
	gm.new_game()
	touch.set_mobile_mode(mobile)
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await _settle()
	await _save(file_name)


func _capture_sky() -> void:
	await _clear_root()
	gm.new_game()
	touch.set_mobile_mode(false)
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro", "world_map_controls_v1"]
	gm.suppress_next_world_map_redirect = true
	gm.last_sky_aim = {"valid": true, "azimuth": 180.0, "altitude": 42.0, "view_mode": "naked_eye"}
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await _settle()
	var target_id := str(sky.get("target_id"))
	var data: Dictionary = sky.get("sky_data")
	var target: Dictionary = data.get(target_id, {}).duplicate(true)
	target["azimuth"] = 238.0
	target["altitude"] = 55.0
	target["visible"] = true
	target["below_horizon"] = false
	data[target_id] = target
	sky.set("sky_data", data)
	sky.call("_rebuild_view")
	await _settle()
	await _save("03_sky_location_and_target_guidance.png")


func _capture_mission_board() -> void:
	await _clear_root()
	gm.new_game()
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await _settle()
	room.call("_open_mission_board")
	await _settle()
	await _save("02_mission_board_route.png")


func _capture_below_horizon() -> void:
	await _clear_root()
	gm.new_game()
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro", "world_map_controls_v1", "below_horizon_flow_v1"]
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await _settle()
	var object_id := str(sky.get("target_id"))
	var data: Dictionary = sky.get("sky_data")
	var item: Dictionary = data.get(object_id, {}).duplicate(true)
	item["altitude"] = -8.0
	item["azimuth"] = 145.0
	item["visible"] = false
	item["below_horizon"] = true
	item["source"] = "calculated"
	data[object_id] = item
	sky.set("sky_data", data)
	sky.call("_redirect_to_world_map_if_needed")
	await create_timer(0.75).timeout
	await _save("04_below_horizon_transition.png")


func _capture_map_recommendation() -> void:
	await _clear_root()
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1"]
	var map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await _settle()
	map.call("_skip_animation")
	await _settle()
	await _save("05_world_map_recommended_site.png")


func _capture_returned_target() -> void:
	await _clear_root()
	var object_id := str(gm.world_map_target_id)
	if object_id == "":
		object_id = gm.current_target_object_id()
	gm.selected_object_id = object_id
	gm.selected_object_level = int(gm.progress.get("current_level", 1))
	gm.world_map_arrival_context = {
		"target_id": object_id,
		"site_id": str(gm.observing_location().get("id", "home")),
		"site_name_en": str(gm.observing_location().get("name_en", "Home Base")),
		"site_name_zh": str(gm.observing_location().get("name_zh", "主基地")),
		"altitude": 42.0,
		"azimuth": 145.0,
		"free_observation": object_id != gm.current_target_object_id()
	}
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await _settle()
	await _save("06_returned_same_target.png")


func _capture_free_details() -> void:
	await _clear_root()
	gm.new_game()
	gm.debug_jump_to_level(5, false)
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro", "world_map_controls_v1", "below_horizon_flow_v1"]
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await _settle()
	var free_id := "moon" if str(sky.get("target_id")) != "moon" else "mars"
	var data: Dictionary = sky.get("sky_data")
	var item: Dictionary = data.get(free_id, {}).duplicate(true)
	item["altitude"] = 38.0
	item["azimuth"] = 160.0
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "calculated"
	data[free_id] = item
	sky.set("sky_data", data)
	sky.call("_select_object", free_id)
	sky.call("_open_detail_panel")
	await _settle()
	await _save("07_free_observation_details.png")


func _capture_telescope_types() -> void:
	await _clear_root()
	gm.new_game()
	gm.debug_jump_to_level(80, false)
	gm.set_meta("telescope_types_browse", false)
	var selector: Node = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(selector)
	await _settle()
	await _save("08_assembly_telescope_type_selection.png")


func _clear_root() -> void:
	for child in root.get_children():
		if child.name not in ["SaveManager", "MissionManager", "TeachingFlowManager", "StoryManager", "GameManager", "AudioManager", "BulletManager", "InteractionFeedback", "TouchInput"]:
			child.queue_free()
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.35).timeout


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save " + output)
	else:
		print("CAPTURE ", output)
	await process_frame


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
