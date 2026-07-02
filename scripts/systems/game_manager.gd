extends Node

signal progress_changed
signal language_changed

const LocalizationScript := preload("res://scripts/systems/localization.gd")
const TelescopeMathScript := preload("res://scripts/systems/telescope_math.gd")
const AssemblyManagerScript := preload("res://scripts/systems/assembly_manager.gd")
const ObservationSystemScript := preload("res://scripts/systems/observation_system.gd")

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"observatory": "res://scenes/observatory_room.tscn",
	"interior": "res://scenes/observatory_interior.tscn",
	"parts": "res://scenes/parts_cabinet.tscn",
	"assembly": "res://scenes/telescope_assembly.tscn",
	"sky": "res://scenes/sky_observation.tscn",
	"telescope": "res://scenes/telescope_view.tscn",
	"journal": "res://scenes/learning_journal.tscn",
	"card": "res://scenes/learning_card.tscn"
}

var parts_data: Array = []
var objects_data: Array = []
var levels_data: Array = []
var progress: Dictionary = {}
var selected_object_id := ""
var last_observation: Dictionary = {}
var last_learning_card: Dictionary = {}
var last_guidance := ""
var language_mode := "both"
var observatory_spawn_id := "default"


func _ready() -> void:
	parts_data = _load_json_array("res://data/telescope_parts.json")
	objects_data = _load_json_array("res://data/celestial_objects.json")
	levels_data = _load_json_array("res://data/levels.json")
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null:
		mission_manager.load_levels(levels_data)
	progress = SaveManager.load_progress(default_progress())
	language_mode = str(progress.get("language_mode", "both"))
	_unlock_parts_for_current_level()
	save()


func default_progress() -> Dictionary:
	return {
		"current_level": 1,
		"credits": 0,
		"completed_levels": [],
		"unlocked_parts": ["basic_tripod", "basic_mount", "starter_tube", "objective_60mm", "eyepiece_20mm"],
		"selected_parts": {
			"tripod": "basic_tripod",
			"mount": "basic_mount",
			"tube": "starter_tube",
			"objective": "objective_60mm",
			"eyepiece": "eyepiece_20mm",
			"finder_scope": "basic_finder_scope"
		},
		"assembly_state": _fresh_assembly_state(),
		"telescope_ready": false,
		"observed_objects": [],
		"badges": [],
		"journal_entries": [],
		"language_mode": "both"
	}


func new_game() -> void:
	progress = SaveManager.reset_progress(default_progress())
	language_mode = str(progress.get("language_mode", "both"))
	selected_object_id = ""
	last_observation = {}
	last_learning_card = {}
	last_guidance = ""
	observatory_spawn_id = "default"
	progress_changed.emit()


func has_save() -> bool:
	return SaveManager.has_save()


func save() -> void:
	progress["language_mode"] = language_mode
	SaveManager.save_progress(progress)
	progress_changed.emit()


func go(scene_key: String) -> void:
	if not SCENES.has(scene_key):
		push_error("Unknown scene key: " + scene_key)
		return
	var packed_scene: PackedScene = load(SCENES[scene_key])
	if packed_scene == null:
		push_error("Could not load scene: " + str(SCENES[scene_key]))
		return
	var next_scene: Node = packed_scene.instantiate()
	var current: Node = get_tree().current_scene
	if current != null:
		current.queue_free()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene


func set_observatory_spawn(spawn_id: String) -> void:
	observatory_spawn_id = spawn_id


func take_observatory_spawn() -> String:
	var spawn_id := observatory_spawn_id
	observatory_spawn_id = "default"
	return spawn_id


func text(en: String, zh: String) -> String:
	return LocalizationScript.text(en, zh, language_mode)


func dict_text(data: Dictionary, base: String) -> String:
	return LocalizationScript.from_dict(data, base, language_mode)


func cycle_language() -> void:
	if language_mode == "both":
		language_mode = "en"
	elif language_mode == "en":
		language_mode = "zh"
	else:
		language_mode = "both"
	save()
	language_changed.emit()


func current_level() -> Dictionary:
	var mission_manager: Variant = _mission_manager()
	if mission_manager == null:
		return {}
	return mission_manager.get_level(int(progress.get("current_level", 1)))


func current_target() -> Dictionary:
	return get_object(str(current_level().get("target_object_id", "moon")))


func get_object(object_id: String) -> Dictionary:
	for obj in objects_data:
		if str(obj.get("id", "")) == object_id:
			return obj
	return {}


func get_part(part_id: String) -> Dictionary:
	for part in parts_data:
		if str(part.get("id", "")) == part_id:
			return part
	return {}


func get_selected_parts() -> Dictionary:
	var selected: Dictionary = {}
	for part_type in progress.get("selected_parts", {}).keys():
		var part: Dictionary = get_part(str(progress["selected_parts"][part_type]))
		if not part.is_empty():
			selected[part_type] = part
	return selected


func unlocked_parts_by_type(part_type: String) -> Array:
	var result: Array = []
	var unlocked: Array = progress.get("unlocked_parts", [])
	for part in parts_data:
		if str(part.get("type", "")) == part_type and unlocked.has(str(part.get("id", ""))):
			result.append(part)
	return result


func reset_assembly() -> void:
	progress["assembly_state"] = _fresh_assembly_state()
	progress["telescope_ready"] = false
	save()


func install_part(part_type: String, wrong_attempts: int) -> int:
	var score: int = AssemblyManagerScript.alignment_from_wrong_attempts(wrong_attempts)
	progress["assembly_state"][part_type] = {
		"installed": true,
		"alignment_score": score,
		"wrong_attempts": wrong_attempts
	}
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], current_level().get("required_parts", []))
	save()
	return score


func telescope_is_ready() -> bool:
	return bool(progress.get("telescope_ready", false)) and AssemblyManagerScript.is_complete(progress["assembly_state"], current_level().get("required_parts", []))


func missing_parts() -> Array:
	return AssemblyManagerScript.missing_parts(progress["assembly_state"], current_level().get("required_parts", []))


func calculate_stats() -> Dictionary:
	return TelescopeMathScript.calculate(get_selected_parts(), progress.get("assembly_state", {}))


func evaluate_selected_object() -> Dictionary:
	var obj := get_object(selected_object_id)
	last_observation = ObservationSystemScript.evaluate(calculate_stats(), obj)
	return last_observation


func complete_current_mission(object_id: String, observation: Dictionary) -> bool:
	var level := current_level()
	if object_id != str(level.get("target_object_id", "")):
		return false
	if not bool(observation.get("success", false)):
		return false
	var level_number: int = int(level.get("level_number", progress.get("current_level", 1)))
	if not progress["completed_levels"].has(level_number):
		progress["completed_levels"].append(level_number)
		progress["credits"] = int(progress.get("credits", 0)) + int(level.get("reward_credits", 0))
		for part_id in level.get("unlock_parts", []):
			if not progress["unlocked_parts"].has(part_id):
				progress["unlocked_parts"].append(part_id)
		var badge: String = str(level.get("badge", ""))
		if badge != "" and not progress["badges"].has(badge):
			progress["badges"].append(badge)
	_add_journal_entry(object_id, observation)
	last_learning_card = {
		"object": get_object(object_id),
		"level": level,
		"observation": observation,
		"stats": calculate_stats()
	}
	var mission_manager: Variant = _mission_manager()
	if level_number >= int(progress.get("current_level", 1)) and mission_manager != null and not mission_manager.is_final_level(level_number):
		progress["current_level"] = level_number + 1
		_unlock_parts_for_current_level()
	save()
	return true


func _mission_manager() -> Variant:
	return get_node_or_null("/root/MissionManager")


func _add_journal_entry(object_id: String, observation: Dictionary) -> void:
	var obj := get_object(object_id)
	var stats := calculate_stats()
	progress["journal_entries"].append({
		"object_id": object_id,
		"object_name_en": obj.get("name_en", object_id),
		"object_name_zh": obj.get("name_zh", object_id),
		"object_type_en": obj.get("type_en", ""),
		"object_type_zh": obj.get("type_zh", ""),
		"level_completed": current_level().get("level_number", progress.get("current_level", 1)),
		"assembly_score": stats.get("assembly_score", 0),
		"observation_quality": observation.get("quality", "Unknown"),
		"learning_text_en": obj.get("learning_text_en", ""),
		"learning_text_zh": obj.get("learning_text_zh", "")
	})
	if not progress["observed_objects"].has(object_id):
		progress["observed_objects"].append(object_id)


func _unlock_parts_for_current_level() -> void:
	var current: int = int(progress.get("current_level", 1))
	for part in parts_data:
		if int(part.get("unlock_level", 999)) <= current:
			var part_id: String = str(part.get("id", ""))
			if part_id != "" and not progress["unlocked_parts"].has(part_id):
				progress["unlocked_parts"].append(part_id)


func _fresh_assembly_state() -> Dictionary:
	return {
		"tripod": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"mount": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"tube": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"objective": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"eyepiece": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"finder_scope": {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
	}


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	push_warning("Expected JSON array: " + path)
	return []
