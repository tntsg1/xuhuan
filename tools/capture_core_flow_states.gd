extends SceneTree

# Non-headless visual proof at 1024x768. It intentionally creates disposable
# progress; invoke with a save backup and restore it afterwards.

const CASES := [
	{"kind": "room", "level": 1, "lang": "zh", "file": "core_route_L1_zh.png"},
	{"kind": "room", "level": 3, "lang": "zh", "file": "core_route_L3_zh.png"},
	{"kind": "room", "level": 4, "lang": "zh", "file": "core_route_L4_zh.png"},
	{"kind": "room", "level": 10, "lang": "zh", "file": "core_route_L10_zh.png"},
	{"kind": "room", "level": 16, "lang": "zh", "file": "core_route_L16_zh.png"},
	{"kind": "room", "level": 18, "lang": "zh", "file": "core_route_L18_zh.png"},
	{"kind": "room", "level": 10, "lang": "en", "file": "core_route_L10_en.png"},
	{"kind": "terminal", "level": 10, "lang": "en", "file": "core_stats_terminal_en.png"},
	{"kind": "complete", "level": 1, "lang": "zh", "file": "core_mission_complete_zh.png"},
	{"kind": "journal", "level": 18, "lang": "zh", "file": "core_logbook_zh.png"},
	{"kind": "telescope", "level": 18, "lang": "en", "file": "core_orion_environment_en.png"}
]

var case_index := -1
var frame_count := 0
var active_scene: Node


func _initialize() -> void:
	await process_frame
	process_frame.connect(_tick)


func _tick() -> void:
	frame_count += 1
	if case_index < 0 or frame_count % 42 == 1:
		case_index += 1
		if case_index >= CASES.size():
			quit()
			return
		_open_case(CASES[case_index])
		return
	if frame_count % 42 == 28:
		var capture := root.get_texture().get_image()
		capture.save_png("user://" + str(CASES[case_index].get("file", "capture.png")))


func _open_case(case_data: Dictionary) -> void:
	if active_scene != null:
		active_scene.queue_free()
	var gm: Node = root.get_node_or_null("/root/GameManager")
	gm.new_game()
	gm.language_mode = str(case_data.get("lang", "en"))
	gm.progress["language_mode"] = gm.language_mode
	gm.progress["current_level"] = int(case_data.get("level", 1))
	gm.call("_unlock_parts_for_current_level")
	gm.take_pending_unlock_notice()
	_prepare_level(gm, int(case_data.get("level", 1)))
	gm.update_room_guidance_for_level()
	match str(case_data.get("kind", "room")):
		"terminal":
			active_scene = load("res://scenes/observatory_room.tscn").instantiate()
			root.add_child(active_scene)
			active_scene.call("_toggle_stats_terminal")
		"journal":
			_add_sample_history(gm)
			active_scene = load("res://scenes/learning_journal.tscn").instantiate()
			root.add_child(active_scene)
		"complete":
			gm.selected_object_id = gm.current_target_object_id()
			var observation: Dictionary = gm.evaluate_selected_object()
			gm.complete_current_mission(gm.selected_object_id, observation)
			active_scene = current_scene
		"telescope":
			gm.selected_object_id = gm.current_target_object_id()
			active_scene = load("res://scenes/telescope_view.tscn").instantiate()
			root.add_child(active_scene)
		_:
			active_scene = load("res://scenes/observatory_room.tscn").instantiate()
			root.add_child(active_scene)


func _prepare_level(gm: Node, level_number: int) -> void:
	gm.reset_assembly()
	if level_number < 10:
		return
	for part_value in gm.parts_data:
		if part_value is Dictionary:
			var part_id := str((part_value as Dictionary).get("id", ""))
			if part_id != "" and not gm.progress["unlocked_parts"].has(part_id):
				gm.progress["unlocked_parts"].append(part_id)
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)


func _add_sample_history(gm: Node) -> void:
	gm.selected_object_id = gm.current_target_object_id()
	var observation: Dictionary = gm.evaluate_selected_object({"focus_error": 0.0, "focus_tolerance": 0.08})
	gm.call("_add_journal_entry", gm.selected_object_id, observation)
	var second := observation.duplicate()
	second["quality"] = "Fair"
	gm.call("_add_journal_entry", gm.selected_object_id, second)
