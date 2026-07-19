extends Node

signal progress_changed
signal language_changed

const LocalizationScript := preload("res://scripts/systems/localization.gd")
const TelescopeMathScript := preload("res://scripts/systems/telescope_math.gd")
const AssemblyManagerScript := preload("res://scripts/systems/assembly_manager.gd")
const ObservationSystemScript := preload("res://scripts/systems/observation_system.gd")
const DeveloperConsoleScript := preload("res://scripts/ui/developer_console.gd")
const ADVANCED_LEVELS_PATH := "res://data/advanced_levels.json"
const ADVANCED_PARTS_PATH := "res://data/advanced_telescope_parts.json"

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"observatory": "res://scenes/observatory_room.tscn",
	"interior": "res://scenes/observatory_interior.tscn",
	"parts": "res://scenes/parts_cabinet.tscn",
	"assembly": "res://scenes/telescope_assembly.tscn",
	"advanced_assembly": "res://scenes/advanced_assembly.tscn",
	"optical_tube_assembly": "res://scenes/optical_tube_assembly.tscn",
	"collimation": "res://scenes/collimation.tscn",
	"radio_observation": "res://scenes/radio_observation.tscn",
	"multi_observation": "res://scenes/multi_observation.tscn",
	"sky": "res://scenes/sky_observation.tscn",
	"telescope": "res://scenes/telescope_view.tscn",
	"journal": "res://scenes/learning_journal.tscn",
	"card": "res://scenes/learning_card.tscn",
	"story": "res://scenes/story_dialogue.tscn"
}

var parts_data: Array = []
var objects_data: Array = []
var levels_data: Array = []
var learning_cards_data: Array = []
var progress: Dictionary = {}
var selected_object_id := ""
var last_observation: Dictionary = {}
var last_learning_card: Dictionary = {}
var last_guidance := ""
var room_guidance_target := ""
var room_guidance_title := ""
var room_guidance_hint := ""
var language_mode := "en"
var observatory_spawn_id := "default"
# Last sky-observation aim, restored when re-entering the pad.
var last_sky_aim: Dictionary = {"valid": false}
var developer_console: Control


func _ready() -> void:
	parts_data = _load_json_array("res://data/telescope_parts.json")
	parts_data.append_array(_load_json_array(ADVANCED_PARTS_PATH))
	objects_data = _load_json_array("res://data/celestial_objects.json")
	levels_data = _load_json_array("res://data/levels.json")
	levels_data.append_array(_load_json_array(ADVANCED_LEVELS_PATH))
	learning_cards_data = _load_json_array("res://data/learning_cards.json")
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null:
		mission_manager.load_levels(levels_data)
	progress = SaveManager.load_progress(default_progress())
	_normalize_progress()
	language_mode = _normalized_language_mode(str(progress.get("language_mode", "en")))
	_unlock_parts_for_current_level()
	save()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_EQUAL:
		return
	toggle_developer_console()
	get_viewport().set_input_as_handled()


func toggle_developer_console() -> void:
	if developer_console != null and is_instance_valid(developer_console):
		developer_console.queue_free()
		developer_console = null
		return
	var current: Node = get_tree().current_scene
	if current == null:
		return
	developer_console = DeveloperConsoleScript.new()
	current.add_child(developer_console)


func debug_jump_to_level(level_number: int, prepare_equipment: bool = false) -> void:
	var max_level: int = max(1, levels_data.size())
	progress["current_level"] = clampi(level_number, 1, max_level)
	selected_object_id = current_target_object_id()
	last_observation = {}
	last_learning_card = {}
	last_sky_aim = {"valid": false}
	_unlock_parts_for_current_level()
	# Developer jumps should not be interrupted by normal progression popups.
	progress["pending_unlock_notice"] = []
	if prepare_equipment:
		_debug_prepare_equipment()
	else:
		reset_assembly()
	update_room_guidance_for_level()
	progress_changed.emit()


func debug_launch(scene_key: String, prepare_equipment: bool = false) -> void:
	if prepare_equipment:
		_debug_prepare_equipment()
	selected_object_id = current_target_object_id()
	if scene_key == "observatory":
		update_room_guidance_for_level()
		set_observatory_spawn("default")
	go(scene_key)


func available_level_numbers() -> Array[int]:
	var result: Array[int] = []
	for level_value in levels_data:
		if not level_value is Dictionary:
			continue
		var level: Dictionary = level_value
		var number := int(level.get("level_number", 0))
		if number > 0 and not result.has(number):
			result.append(number)
	result.sort()
	return result


func _debug_prepare_equipment() -> void:
	# A repeatable level sandbox: select the best parts currently unlocked and
	# perfectly install the parts the selected lesson actually requires.
	var part_types: Array[String] = ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope", "focus_knob"]
	for required_type_value in current_level().get("required_parts", []):
		var required_type := str(required_type_value)
		if not part_types.has(required_type):
			part_types.append(required_type)
	for part_type in part_types:
		var options: Array = unlocked_parts_by_type(part_type)
		if not options.is_empty():
			equip_part(str(options[options.size() - 1].get("id", "")))
	# Lessons that prescribe exact component IDs override the "best unlocked"
	# pick, matching what the assembly screens themselves enforce.
	for required_id_value in current_level().get("required_part_ids", []):
		equip_part(str(required_id_value))
	if _uses_tube_subassembly():
		var tube_config := tube_subassembly_config()
		var tube_order: Array = tube_config.get("order", [])
		var tube_ids: Array = tube_config.get("ids", [])
		var completed_subparts := {}
		for index in range(tube_order.size()):
			var subpart := str(tube_order[index])
			completed_subparts[subpart] = true
			if index < tube_ids.size():
				equip_part(str(tube_ids[index]))
		save_tube_assembly(completed_subparts, 100.0, 100.0, true)
	reset_assembly()
	for required_type_value in _effective_required_parts():
		install_part(str(required_type_value), 0)
	progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	progress["finder_offset_seeded"] = false
	progress["tracking_rate"] = 1.0 if has_tracking_mount_equipped() else 0.0


func focus_control_installed() -> bool:
	var state: Dictionary = progress.get("assembly_state", {})
	for focus_type in ["focus_knob", "focuser"]:
		var entry: Dictionary = state.get(focus_type, {})
		if bool(entry.get("installed", false)):
			return true
	# Advanced reflector focusers live inside the optical-tube subassembly.
	if _uses_tube_subassembly():
		var tube_state := tube_assembly()
		var subparts: Dictionary = tube_state.get("installed_subparts", tube_state.get("tube_assembly_state", {}))
		if bool(subparts.get("focuser", false)):
			return true
	return false


func default_progress() -> Dictionary:
	return {
		"campaign_version": 91,
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
			"finder_scope": "basic_finder_scope",
			"focus_knob": "basic_focus_knob"
		},
		"assembly_state": _fresh_assembly_state(),
		"telescope_ready": false,
		"observed_objects": [],
		"badges": [],
		"journal_entries": [],
		"completed_concept_cards": [],
		"seen_teaching_steps": [],
		"seen_concept_briefs": [],
		"seen_story_events": [],
		"pending_unlock_notice": [],
		"unlocked_equipment_stages": ["eye"],
		"language_mode": "en",
		"mission_step_state": {},
		"level_target_overrides": {},
		"finder_offset": {"az": 0.0, "alt": 0.0},
		"finder_offset_seeded": false,
		"tracking_rate": 0.0,
		"collimation_scores": {"newtonian": 0.0},
		"tube_assemblies": {}
	}


func new_game() -> void:
	progress = SaveManager.reset_progress(default_progress())
	language_mode = _normalized_language_mode(str(progress.get("language_mode", "en")))
	selected_object_id = ""
	last_observation = {}
	last_learning_card = {}
	last_guidance = ""
	clear_room_guidance()
	observatory_spawn_id = "default"
	last_sky_aim = {"valid": false}
	TeachingFlowManager.reset_flow()
	StoryManager.reset_flow()
	progress_changed.emit()


func has_save() -> bool:
	return SaveManager.has_save()


func save() -> void:
	progress["language_mode"] = language_mode
	SaveManager.save_progress(progress)
	progress_changed.emit()


func go(scene_key: String) -> void:
	if scene_key == "sky":
		match current_observation_mode():
			"radio": scene_key = "radio_observation"
			"multi_device": scene_key = "multi_observation"
			"telescope" when str(current_level().get("telescope_family", "")) == "space_segmented": scene_key = "multi_observation"
	if scene_key == "assembly" and str(current_level().get("assembly_mode", "")) == "advanced":
		scene_key = "advanced_assembly"
	if not SCENES.has(scene_key):
		push_error("Unknown scene key: " + scene_key)
		return
	# Reaching the guided destination completes the guidance.
	if (scene_key in ["sky", "telescope"] and room_guidance_target == "telescope") \
			or (scene_key == "assembly" and room_guidance_target == "assembly") \
			or (scene_key == "parts" and room_guidance_target == "cabinet"):
		clear_room_guidance()
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
	if language_mode == "en":
		language_mode = "zh"
	else:
		language_mode = "en"
	save()
	language_changed.emit()


func _normalized_language_mode(mode: String) -> String:
	if mode == "zh":
		return "zh"
	return "en"


func current_level() -> Dictionary:
	var mission_manager: Variant = _mission_manager()
	if mission_manager == null:
		return {}
	return mission_manager.get_level(int(progress.get("current_level", 1)))


func current_target() -> Dictionary:
	return get_object(current_target_object_id())


# Resolves the level's actual target for this playthrough: levels with a
# target_pool get a random pick on first visit (stable afterward via
# progress["level_target_overrides"]); levels without one just use their
# fixed target_object_id, unaffected.
func current_target_object_id() -> String:
	var level := current_level()
	var default_id := str(level.get("target_object_id", "moon"))
	var pool: Array = level.get("target_pool", [])
	if pool.is_empty():
		return default_id
	var level_id := str(level.get("id", ""))
	if level_id == "":
		return default_id
	var overrides: Dictionary = progress.get("level_target_overrides", {})
	if overrides.has(level_id):
		return str(overrides[level_id])
	var pick := str(pool[randi() % pool.size()])
	overrides[level_id] = pick
	progress["level_target_overrides"] = overrides
	save()
	return pick


func current_observation_mode() -> String:
	return str(current_level().get("observation_mode", "telescope"))


func current_equipment_stage() -> String:
	return str(current_level().get("equipment_stage", "refractor_basic"))


func current_requires_telescope() -> bool:
	var level := current_level()
	if level.has("requires_telescope"):
		return bool(level.get("requires_telescope", true))
	return current_observation_mode() != "naked_eye"


func current_requires_focus() -> bool:
	return bool(current_level().get("requires_focus", false))


func current_concept_card_id() -> String:
	return str(current_level().get("required_concept_card", ""))


func get_learning_card(card_id: String) -> Dictionary:
	for card in learning_cards_data:
		if str(card.get("id", "")) == card_id:
			return card
	return {}


func completed_concept_cards() -> Array:
	return progress.get("completed_concept_cards", [])


func current_concept_card() -> Dictionary:
	return get_learning_card(current_concept_card_id())


func has_seen_current_concept_brief() -> bool:
	var card_id := current_concept_card_id()
	if card_id == "":
		return true
	return progress.get("seen_concept_briefs", []).has(card_id)


func mark_concept_brief_seen(card_id: String) -> void:
	if card_id == "":
		return
	_ensure_progress_array("seen_concept_briefs")
	if not progress["seen_concept_briefs"].has(card_id):
		progress["seen_concept_briefs"].append(card_id)
	_ensure_progress_array("seen_teaching_steps")
	for step_value in TeachingFlowManager.get_steps_for_level(current_level()):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if str(step.get("card_id", "")) == card_id:
			var step_id: String = str(step.get("id", ""))
			if step_id != "" and not progress["seen_teaching_steps"].has(step_id):
				progress["seen_teaching_steps"].append(step_id)
	save()


func should_show_concept_brief_for_current_level() -> bool:
	var card_id := current_concept_card_id()
	if card_id == "":
		return false
	return not has_seen_current_concept_brief()


# ------------------------------------------------------ story flow wrappers


func try_story_event(event_id: String, return_scene_key: String) -> bool:
	return StoryManager.begin_event(event_id, return_scene_key)


func try_story_for_trigger(trigger: String, return_scene_key: String) -> bool:
	return StoryManager.begin_event_for_trigger(trigger, return_scene_key)


func complete_current_story() -> void:
	StoryManager.finish_active_event()


# Observing-site facts. The base site matches SkyPositionService's default
# observer (34.05N 118.24W): a suburban ridge NE of Los Angeles. Levels with
# a city/dark sky_brightness are field trips and override region + Bortle.
func site_info() -> Dictionary:
	var env := current_environment()
	var sky := str(env.get("sky_brightness", "suburban"))
	var region_en := "Suburban ridge, San Gabriel foothills"
	var region_zh := "郊区山脊 · 圣加布里埃尔山麓"
	var bortle := "Bortle 5"
	match sky:
		"city":
			region_en = "City rooftop field trip"
			region_zh = "城市天台（本关外出观测）"
			bortle = "Bortle 8"
		"dark":
			region_en = "Dark-sky camp field trip"
			region_zh = "暗夜营地（本关外出观测）"
			bortle = "Bortle 3"
	var seeing := str(env.get("seeing", "good"))
	var seeing_score := 8
	match seeing:
		"average": seeing_score = 6
		"poor": seeing_score = 3
	var cloud_pct := int(round(float(env.get("cloud_cover", 0.0)) * 100.0))
	var weather_index: int = clampi(seeing_score - cloud_pct / 20, 1, 10)
	return {
		"lat": "34.05° N", "lon": "118.24° W", "altitude": "1100 m",
		"region_en": region_en, "region_zh": region_zh, "bortle": bortle,
		"seeing": seeing, "cloud_pct": cloud_pct, "weather_index": weather_index
	}


func assembly_hints_enabled() -> bool:
	return bool(progress.get("assembly_hints_enabled", true))


func set_assembly_hints(enabled: bool) -> void:
	progress["assembly_hints_enabled"] = enabled
	save()


# ------------------------------------------------- auto-equip (scored)
# Task profile for part scoring: what does TONIGHT's observation reward?
func _task_profile() -> String:
	var target_type := str(current_target().get("type_en", "")).to_lower()
	if target_type.contains("nebula") or target_type.contains("galaxy"):
		return "deep_sky"
	if str(current_environment().get("seeing", "")) == "poor":
		return "steady"
	return "planet"


# Composite performance score of a part under the given task profile.
func _part_score(part: Dictionary, profile: String) -> float:
	var s := 0.0
	s += float(part.get("quality", 0.0))
	s += float(part.get("stability", 0.0)) * (1.5 if profile == "steady" else 0.8)
	s += float(part.get("stability_bonus", 0.0))
	s += float(part.get("alignment_quality", 0.0)) * 0.5
	s += float(part.get("tracking", 0.0)) * (1.2 if profile == "steady" else 0.5)
	if bool(part.get("tracking_capable", false)):
		s += 25.0 if profile == "steady" else 12.0
	s += (float(part.get("focus_sensitivity", 0.0)) + float(part.get("focus_stability", 0.0))) * 30.0
	s += float(part.get("aim_assist", 0.0))
	var aperture := float(part.get("aperture_mm", 0.0))
	if aperture > 0.0:
		s += log(aperture) * (22.0 if profile == "deep_sky" else 10.0)
	if str(part.get("type", "")) == "eyepiece":
		var focal := float(part.get("focal_length_mm", 20.0))
		s += float(part.get("field_of_view", 0.0)) * (0.8 if profile == "deep_sky" else 0.3)
		if profile == "planet":
			# Planetary detail wants magnification: shorter focal = higher power.
			s += (40.0 - focal) * 2.5
		else:
			# Deep sky / rough air want the wide, bright, forgiving field.
			s += focal * 2.0
	return s


# The exact part id this level PINS for a slot type ("" = free slot).
func pinned_part_id(part_type: String) -> String:
	for required_id_value in current_level().get("required_part_ids", []):
		var part := get_part(str(required_id_value))
		if str(part.get("type", "")) == part_type:
			return str(part.get("id", ""))
	return ""


# Best unlocked, family-compatible part for a slot under tonight's profile.
func best_part_for_type(part_type: String) -> Dictionary:
	var profile := _task_profile()
	var best: Dictionary = {}
	var best_score := -1.0
	var current_family := str(current_level().get("telescope_family", ""))
	for option_value in unlocked_parts_by_type(part_type):
		var option: Dictionary = option_value
		var part_family := str(option.get("telescope_family", ""))
		if part_family != "" and part_family != current_family:
			continue
		var score := _part_score(option, profile)
		if score > best_score:
			best_score = score
			best = option
	return best


func _auto_reason(part_type: String, profile: String, part: Dictionary) -> Dictionary:
	match part_type:
		"eyepiece":
			var focal := int(part.get("focal_length_mm", 0))
			if profile == "planet":
				return {"en": "Planetary detail needs power: the %dmm eyepiece gives the highest usable magnification." % focal,
					"zh": "行星/恒星细节需要倍率：%dmm 目镜提供最高可用放大倍数。" % focal}
			if profile == "steady":
				return {"en": "Rough air punishes high power: the %dmm keeps the image low-power and steady." % focal,
					"zh": "视宁度差时高倍率吃亏：%dmm 目镜保持低倍率、画面更稳。" % focal}
			return {"en": "Deep sky wants a wide, bright field: the %dmm shows the most sky." % focal,
				"zh": "深空目标需要宽而亮的视场：%dmm 目镜视场最大。" % focal}
		"mount":
			if bool(part.get("tracking_capable", false)):
				return {"en": "Highest stability, and its tracking motor cancels Earth-rotation drift.",
					"zh": "稳定性最高，且追踪马达能抵消地球自转漂移。"}
			return {"en": "Highest stability of the compatible mounts.", "zh": "兼容支架中稳定性最高。"}
		"objective", "primary_mirror":
			return {"en": "Largest aperture: %dmm collects the most light." % int(part.get("aperture_mm", 0)),
				"zh": "口径最大：%dmm 收集的光最多。" % int(part.get("aperture_mm", 0))}
		"finder_scope":
			return {"en": "Best available finder for this chapter.", "zh": "当前章节可用的最佳寻星镜。"}
		"focus_knob", "focuser":
			return {"en": "Finest focus control available.", "zh": "可用调焦部件中控制精度最高。"}
	return {"en": "Highest overall score among compatible parts.", "zh": "兼容零件中综合评分最高。"}


# One-click best loadout for the CURRENT level and target. Returns a plan
# WITHOUT touching the save - the cabinet shows a preview (with per-part
# reasons) and only applies on confirmation.
#
# Selection order per slot: family compatibility -> unlocked -> the level's
# PINNED part if any (teaching levels, shown with the teaching reason) ->
# otherwise the highest-scoring candidate for tonight's task profile.
func auto_equip_plan() -> Array:
	var profile := _task_profile()
	var plan: Array = []
	var slot_types: Array = []
	for type_value in _effective_required_parts():
		if str(type_value) != "optical_tube_assembly" and not slot_types.has(str(type_value)):
			slot_types.append(str(type_value))
	for type_value in current_level().get("required_parts", []):
		if str(type_value) != "optical_tube_assembly" and not slot_types.has(str(type_value)):
			slot_types.append(str(type_value))
	for slot_value in slot_types:
		var part_type := str(slot_value)
		var pinned_id := pinned_part_id(part_type)
		if pinned_id != "" and progress.get("unlocked_parts", []).has(pinned_id):
			var pinned := get_part(pinned_id)
			plan.append(_auto_equip_entry(part_type, pinned, true, {
				"en": "This lesson prescribes this exact part - it is what the level is teaching.",
				"zh": "本关指定使用该零件——这正是本关要学习/要求的设备。"
			}))
			continue
		var best := best_part_for_type(part_type)
		if best.is_empty():
			continue
		plan.append(_auto_equip_entry(part_type, best, false, _auto_reason(part_type, profile, best)))
	return plan


func _auto_equip_entry(part_type: String, part: Dictionary, pinned: bool, reason: Dictionary) -> Dictionary:
	return {
		"part_type": part_type,
		"part_id": str(part.get("id", "")),
		"name_en": str(part.get("name_en", part.get("id", ""))),
		"name_zh": str(part.get("name_zh", part.get("id", ""))),
		"changed": equipped_part_id(part_type) != str(part.get("id", "")),
		"pinned": pinned,
		"reason_en": str(reason.get("en", "")),
		"reason_zh": str(reason.get("zh", ""))
	}


func apply_auto_equip(plan: Array) -> int:
	var applied := 0
	for entry_value in plan:
		var entry: Dictionary = entry_value
		if bool(entry.get("changed", false)) and equip_part(str(entry.get("part_id", ""))):
			applied += 1
	return applied


func try_story_mechanic(mechanic: String, return_scene_key: String, follow_trigger: String = "") -> bool:
	return StoryManager.begin_mechanic_event(mechanic, return_scene_key, follow_trigger)


func try_story_epilogue(level_number: int, return_scene_key: String) -> bool:
	return StoryManager.begin_epilogue(level_number, return_scene_key)


func set_room_guidance(target: String, title: String, hint: String) -> void:
	room_guidance_target = target
	room_guidance_title = title
	room_guidance_hint = hint


func clear_room_guidance() -> void:
	room_guidance_target = ""
	room_guidance_title = ""
	room_guidance_hint = ""


func update_room_guidance_for_level() -> void:
	var route := current_room_route()
	set_room_guidance(
		str(route.get("target", "")),
		str(route.get("title", "")),
		str(route.get("hint", ""))
	)


func route_outcome_text() -> String:
	# "What happens after": the reward the guided step leads to.
	var pieces: Array[String] = []
	var concept := current_concept_card()
	if not concept.is_empty() and not completed_concept_cards().has(str(concept.get("id", ""))):
		pieces.append(text("learn \"" + dict_text(concept, "title") + "\"", "学到「" + dict_text(concept, "title") + "」"))
	var unlock_names: Array[String] = []
	for part_id_value in current_level().get("unlock_parts", []):
		var part := get_part(str(part_id_value))
		if not part.is_empty():
			unlock_names.append(dict_text(part, "name"))
	if not unlock_names.is_empty():
		pieces.append(text("unlock " + ", ".join(unlock_names), "解锁 " + "、".join(unlock_names)))
	if pieces.is_empty():
		return ""
	return text("Complete this mission to ", "完成本关将") + text(" and ", "并").join(pieces) + text(".", "。")


func _required_equipment_route(required_missing: Array) -> Dictionary:
	var required_id := str(required_missing[0])
	var required_part := get_part(required_id)
	var part_type := str(required_part.get("type", ""))
	var required_name := dict_text(required_part, "name") if not required_part.is_empty() else required_id
	var equipped_id := equipped_part_id(part_type)
	var equipped_part := get_part(equipped_id)
	var equipped_name := dict_text(equipped_part, "name") if not equipped_part.is_empty() else ""
	var total_required := int(current_level().get("required_part_ids", []).size())
	var matched_required := maxi(0, total_required - required_missing.size())
	var progress_en := "Required loadout matched: %d/%d." % [matched_required, total_required]
	var progress_zh := "本关指定配置已匹配：%d/%d。" % [matched_required, total_required]
	var title_en := "Maya: Equip " + required_name
	var title_zh := "Maya：装备" + required_name
	var hint_en := "Required: " + required_name + ". " + progress_en
	var hint_zh := "本关指定：" + required_name + "。" + progress_zh
	if equipped_name != "" and equipped_id != required_id:
		title_en = "Maya: Replace " + equipped_name
		title_zh = "Maya：更换" + equipped_name
		hint_en = "Equipped: %s. This mission specifically requires %s; higher stats do not replace the prescribed part. %s" % [equipped_name, required_name, progress_en]
		hint_zh = "当前装备：%s。本关指定：%s；数值更高也不能替代指定零件。%s" % [equipped_name, required_name, progress_zh]
	return {
		"target": "cabinet",
		"title": text(title_en, title_zh),
		"hint": text(hint_en, hint_zh),
		"action": text("Equip " + required_name, "装备" + required_name),
		"outcome": text("Then return to the Assembly Table. The guide will check the next item automatically.", "然后返回组装台；引导会自动检查下一项。"),
		"ready": false,
		"missing": required_missing,
		"required_part_id": required_id,
		"equipped_part_id": equipped_id,
		"matched_required": matched_required,
		"total_required": total_required
	}


func current_room_route() -> Dictionary:
	# The observatory, mission board, result card, and route indicator all use
	# this one decision. It keeps the next physical action consistent.
	var target_name := dict_text(current_target(), "name")
	if current_observation_mode() == "naked_eye":
		return {
			"target": "telescope",
			"title": text("Maya: Observation Pad", "Maya：观测台"),
			"hint": text("Use naked-eye observation to find " + target_name + ".", "用肉眼观测寻找" + target_name + "。"),
			"action": text("Go to the Observation Pad", "前往观测台"),
			"outcome": route_outcome_text(),
			"ready": true
		}

	var required_missing: Array = missing_required_parts()
	if not required_missing.is_empty():
		return _required_equipment_route(required_missing)

	var assembly_missing: Array = missing_parts()
	if not assembly_missing.is_empty() or not telescope_is_ready():
		var install_names: Array[String] = []
		for part_type_value in assembly_missing:
			var part_type := str(part_type_value)
			var selected_part := get_part(equipped_part_id(part_type))
			var part_name := dict_text(selected_part, "name") if not selected_part.is_empty() else part_type.capitalize()
			if not install_names.has(part_name):
				install_names.append(part_name)
		var install_text := ", ".join(install_names)
		var focus_missing := assembly_missing.has("focus_knob")
		var hint := text("Install " + install_text + " at the Assembly Table.", "在组装台安装" + install_text + "。")
		if focus_missing:
			hint = text("Install the Focus Knob near the eyepiece before focus training.", "开始调焦训练前，请在目镜附近安装调焦旋钮。")
		return {
			"target": "assembly",
			"title": text("Maya: Assembly Table", "Maya：组装台"),
			"hint": hint,
			"action": text("Install " + install_text, "安装" + install_text),
			"outcome": text("A finished telescope unlocks the Observation Pad.", "望远镜组装完成后，观测台即可使用。"),
			"ready": false,
			"missing": assembly_missing
		}

	if bool(current_level().get("requires_collimation", false)) and not collimation_is_acceptable():
		var collimation_now := roundi(collimation_score())
		var collimation_target := int(current_level().get("collimation_threshold", 80))
		return {
			"target": "assembly",
			"title": text("Maya: Collimation Bench", "Maya：准直工作台"),
			"hint": text(
				"Collimation is %d%%; this mission requires at least %d%%. Open the Assembly Table and choose Collimate Mirrors." % [collimation_now, collimation_target],
				"当前准直 %d%%；本关至少需要 %d%%。进入组装台后点击“准直镜面”。" % [collimation_now, collimation_target]
			),
			"action": text("Collimate the reflector", "为反射镜准直"),
			"outcome": text("A collimated mirror gives sharp, centered images.", "准直合格后，反射镜才能给出清晰居中的图像。"),
			"ready": false
		}

	if current_level().get("required_part_ids", []).is_empty() and _deep_sky_target() and str(current_level().get("minimum_success_quality", "Good")) == "Good" and _has_better_unequipped_part():
		return {
			"target": "cabinet",
			"title": text("Maya: Upgrade the optics", "Maya：升级光学部件"),
			"hint": text("Equip the stronger unlocked optics for this faint target.", "为这个暗弱目标装备刚解锁的更强光学部件。"),
			"action": text("Choose a better optical part", "选择更好的光学部件"),
			"outcome": text("More aperture means a brighter deep-sky image.", "更大口径意味着更亮的深空图像。"),
			"ready": false
		}

	return {
		"target": "telescope",
		"title": text("Maya: Observation Pad", "Maya：观测台"),
		"hint": text("The telescope is ready. Find and observe " + target_name + ".", "望远镜已准备好。寻找并观测" + target_name + "。"),
		"action": text("Observe " + target_name, "观测" + target_name),
		"outcome": route_outcome_text(),
		"ready": true
	}


func _part_name_list(part_ids: Array) -> String:
	var names: Array[String] = []
	for part_id_value in part_ids:
		var part := get_part(str(part_id_value))
		var part_name := dict_text(part, "name") if not part.is_empty() else str(part_id_value)
		if not names.has(part_name):
			names.append(part_name)
	return ", ".join(names)


func _deep_sky_target() -> bool:
	var type_lower := str(current_target().get("type_en", "")).to_lower()
	return type_lower.contains("nebula") or type_lower.contains("galaxy")


func _has_better_unequipped_part() -> bool:
	# Unlocked upgrades (later entries in parts_data) that are not equipped.
	for part_type in ["objective", "mount"]:
		var options: Array = unlocked_parts_by_type(part_type)
		if options.size() < 2:
			continue
		var best_id := str(options[options.size() - 1].get("id", ""))
		if equipped_part_id(part_type) != best_id:
			return true
	return false


func set_room_guidance_for_scene(scene_key: String, trigger: String = "") -> void:
	var target := ""
	var title := ""
	var hint := ""
	match scene_key:
		"assembly":
			target = "assembly"
			title = "Maya: Assembly Table"
			hint = "Walk to the Assembly Table and press E."
		"sky", "telescope":
			target = "telescope"
			title = "Maya: Observation Pad"
			hint = "Walk to the Observation Pad and press E."
		"interior":
			target = "door"
			title = "Maya: Observatory Door"
			hint = "Walk to the Observatory Door and press E."
		"parts":
			target = "cabinet"
			title = "Maya: Parts Cabinet"
			hint = "Walk to the Parts Cabinet and press E."
	var assembly_state: Dictionary = progress.get("assembly_state", {})
	var focus_entry: Dictionary = assembly_state.get("focus_knob", {})
	if trigger == "before_focus" and not bool(focus_entry.get("installed", false)):
		target = "assembly"
		title = "Maya: Install the Focus Knob"
		hint = "Install the Focus Knob at the Assembly Table before focusing."
	if target != "":
		set_room_guidance(target, title, hint)


func mission_board_note() -> Dictionary:
	return StoryManager.board_note_for_level(int(current_level().get("level_number", 0)))


# --------------------------------------------------- teaching flow wrappers


func try_teaching_intercept(trigger: String, return_scene_key: String, return_payload: Dictionary = {}) -> bool:
	return TeachingFlowManager.begin_step(current_level(), trigger, return_scene_key, return_payload)


func show_concept_brief(card_id: String, return_scene_key: String) -> void:
	if not TeachingFlowManager.show_brief(card_id, return_scene_key):
		go(return_scene_key)


func current_learning_card_mode() -> String:
	return TeachingFlowManager.active_card_mode


func current_brief_card() -> Dictionary:
	return get_learning_card(TeachingFlowManager.active_card_id)


func complete_current_brief() -> void:
	TeachingFlowManager.complete_active_brief(progress)
	save()
	go(TeachingFlowManager.consume_return_scene())


func show_mission_complete_card(payload: Dictionary) -> void:
	TeachingFlowManager.show_mission_complete(payload)


func can_enter_observation() -> Dictionary:
	# Some later instruments (infrared and radio) are not player-held
	# telescopes, but they still need their own assembled hardware. Only true
	# naked-eye lessons may bypass equipment and collimation checks.
	var level := current_level()
	if current_observation_mode() != "naked_eye" and not current_requires_telescope():
		if not missing_required_parts().is_empty():
			return {"ok": false, "reason_en": "Required equipment is not selected. Use the Parts Cabinet first.", "reason_zh": "尚未选择所需设备。请先前往零件柜。"}
		if not missing_parts().is_empty():
			return {"ok": false, "reason_en": "Equipment is not assembled. Use the Assembly Table.", "reason_zh": "设备尚未组装。请前往组装台。"}
		if bool(level.get("requires_collimation", false)) and not collimation_is_acceptable():
			return {"ok": false, "reason_en": "Collimation is required. Return to the Assembly Table and align the optical axis.", "reason_zh": "需要先完成准直。请回到组装台校正光轴。"}
	if current_observation_mode() == "naked_eye":
		return {
			"ok": true,
			"reason_en": "Naked eye observation - no telescope needed.",
			"reason_zh": "肉眼观测——不需要望远镜。"
		}
	if telescope_is_ready():
		if bool(current_level().get("requires_collimation", false)) and not collimation_is_acceptable():
			return {
				"ok": false,
				"reason_en": "Collimation is required. Return to the Assembly Table and align the optical axis.",
				"reason_zh": "需要先完成准直。请回到组装台校正光轴。"
			}
		return {"ok": true, "reason_en": "", "reason_zh": ""}
	var missing: Array = missing_parts()
	var names_en: Array[String] = []
	var names_zh: Array[String] = []
	for part_type_value in missing:
		var part_type := str(part_type_value)
		names_en.append(part_type.capitalize())
		names_zh.append(AssemblyManagerScript._zh_name(part_type))
	return {
		"ok": false,
		"reason_en": "Telescope not ready. Missing: " + ", ".join(names_en) + ". Use the Assembly Table.",
		"reason_zh": "望远镜未就绪，缺少：" + "、".join(names_zh) + "。请前往组装台。"
	}


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
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())
	save()
	return score


func telescope_is_ready() -> bool:
	if _uses_tube_subassembly():
		return advanced_tube_completed() and AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())
	return bool(progress.get("telescope_ready", false)) and AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())


func equip_part(part_id: String) -> bool:
	var part := get_part(part_id)
	if part.is_empty():
		return false
	var part_type: String = str(part.get("type", ""))
	if part_type == "":
		return false
	if not progress.get("unlocked_parts", []).has(part_id):
		return false
	var part_family := str(part.get("telescope_family", ""))
	var current_family := str(current_level().get("telescope_family", ""))
	if part_family != "" and part_family != current_family:
		return false
	if str(progress["selected_parts"].get(part_type, "")) == part_id:
		return true
	progress["selected_parts"][part_type] = part_id
	# Swapping a part means it must be reinstalled on the bench.
	if progress["assembly_state"].has(part_type):
		progress["assembly_state"][part_type] = {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())
	save()
	return true


func equipped_part_id(part_type: String) -> String:
	return str(progress.get("selected_parts", {}).get(part_type, ""))


func missing_parts() -> Array:
	return AssemblyManagerScript.missing_parts(progress["assembly_state"], _effective_required_parts())


func _uses_tube_subassembly() -> bool:
	return str(current_level().get("assembly_mode", "")) == "advanced" and str(current_level().get("telescope_family", "")) in ["newtonian", "dobsonian", "cassegrain", "gregorian"]


func _effective_required_parts() -> Array:
	if not _uses_tube_subassembly():
		return current_level().get("required_parts", [])
	if str(current_level().get("telescope_family", "")) == "dobsonian":
		# The rocker box replaces tripod+mount; the finder rides on the tube.
		return ["mount", "optical_tube_assembly", "finder_scope"]
	if str(current_level().get("telescope_family", "")) == "newtonian":
		# Newtonian main bench mirrors the refractor flow: base, mount, the
		# completed optical tube, then the aiming aid.
		return ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	return ["tripod", "mount", "optical_tube_assembly"]


func tube_assembly() -> Dictionary:
	var family := str(current_level().get("telescope_family", ""))
	var all_states: Dictionary = progress.get("tube_assemblies", {})
	var state: Variant = all_states.get(family, {})
	return state if state is Dictionary else {}


func advanced_tube_completed() -> bool:
	return bool(tube_assembly().get("completed", false))


func update_tube_subassembly_progress(installed_subparts: Dictionary) -> void:
	var config := tube_subassembly_config()
	if config.is_empty():
		return
	var family := str(config.get("family", ""))
	if not progress.get("tube_assemblies") is Dictionary:
		progress["tube_assemblies"] = {}
	var previous := tube_assembly()
	progress["tube_assemblies"][family] = {
		"telescope_family": family,
		"tube_assembly_state": installed_subparts.duplicate(),
		"installed_subparts": installed_subparts.duplicate(),
		"subassembly_score": float(previous.get("subassembly_score", 0.0)),
		"collimation_score": collimation_score(),
		"optical_alignment": float(previous.get("optical_alignment", 0.0)),
		"completed": false,
		"placeholder_assets_used": true
	}
	save()


func tube_subassembly_config() -> Dictionary:
	var family := str(current_level().get("telescope_family", ""))
	match family:
		"newtonian":
			return {"family": family, "order": ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"], "ids": ["newtonian_reflector_tube", "newtonian_mirror_cell", "newtonian_primary_mirror", "newtonian_secondary_spider", "newtonian_secondary_mirror", "newtonian_focuser", "newtonian_25mm_eyepiece", "newtonian_collimation_cap"]}
		"dobsonian":
			return {"family": family, "order": ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"], "ids": ["dobsonian_reflector_tube", "dobsonian_mirror_cell", "dobsonian_primary_mirror", "dobsonian_secondary_spider", "dobsonian_secondary_mirror", "dobsonian_crayford_focuser", "dobsonian_30mm_eyepiece", "dobsonian_collimation_tool"]}
		"cassegrain":
			return {"family": family, "order": ["reflector_tube", "primary_mirror", "secondary_mirror", "central_baffle", "focuser", "eyepiece"], "ids": ["cassegrain_compact_tube", "cassegrain_primary_mirror", "cassegrain_convex_secondary", "cassegrain_central_baffle", "cassegrain_rear_focuser", "cassegrain_12mm_eyepiece"]}
		"gregorian":
			return {"family": family, "order": ["reflector_tube", "primary_mirror", "optical_support", "secondary_mirror", "focuser", "eyepiece"], "ids": ["gregorian_optical_tube", "gregorian_primary_mirror", "gregorian_optical_support", "gregorian_concave_secondary", "gregorian_focuser", "gregorian_18mm_eyepiece"]}
	return {}


func save_tube_assembly(installed_subparts: Dictionary, score: float, optical_alignment: float, placeholder_assets_used: bool) -> bool:
	var config := tube_subassembly_config()
	if config.is_empty():
		return false
	for subpart_value in config.get("order", []):
		if not bool(installed_subparts.get(str(subpart_value), false)):
			return false
	var family := str(config.get("family", ""))
	if not progress.get("tube_assemblies") is Dictionary:
		progress["tube_assemblies"] = {}
	progress["tube_assemblies"][family] = {
		"telescope_family": family,
		"tube_assembly_state": installed_subparts.duplicate(),
		"installed_subparts": installed_subparts.duplicate(),
		"subassembly_score": clampf(score, 0.0, 100.0),
		"collimation_score": collimation_score(),
		"optical_alignment": clampf(optical_alignment, 0.0, 100.0),
		"completed": true,
		"placeholder_assets_used": placeholder_assets_used
	}
	progress["assembly_state"]["optical_tube_assembly"] = {"installed": false, "alignment_score": roundi(score), "wrong_attempts": 0}
	progress["telescope_ready"] = false
	save()
	return true


# Hard gate: specific part IDs (not just part types) the current level
# requires, e.g. ["eyepiece_10mm"]. Empty when the level has no such field
# (older levels are unaffected).
func missing_required_parts() -> Array[String]:
	var required: Array = current_level().get("required_part_ids", [])
	var missing: Array[String] = []
	var selected: Dictionary = progress.get("selected_parts", {})
	for required_value in required:
		var required_id := str(required_value)
		var part := get_part(required_id)
		var part_type := str(part.get("type", ""))
		var equipped_id := str(selected.get(part_type, ""))
		if equipped_id != required_id:
			missing.append(required_id)
	return missing


# Older Newtonian saves can have a main slot installed while selected_parts
# still names the previously equipped mount, incorrectly locking Identify.
func sync_newtonian_installed_equipment() -> bool:
	var level := current_level()
	if str(level.get("assembly_mode", "")) != "advanced" or not str(level.get("telescope_family", "")) in ["newtonian", "dobsonian"]:
		return false
	var state: Dictionary = progress.get("assembly_state", {})
	var selected: Dictionary = progress.get("selected_parts", {})
	var changed := false
	for required_value in level.get("required_part_ids", []):
		var required_id := str(required_value)
		var part := get_part(required_id)
		var part_type := str(part.get("type", ""))
		if not part_type in ["tripod", "mount", "finder_scope"]:
			continue
		var installed_entry: Dictionary = state.get(part_type, {})
		if bool(installed_entry.get("installed", false)) and str(selected.get(part_type, "")) != required_id:
			selected[part_type] = required_id
			changed = true
	if changed:
		progress["selected_parts"] = selected
		save()
	return changed


# ------------------------------------------------------------ mission steps


# The current level's ordered checklist (e.g. L10's "observe with 20mm, then
# switch to 10mm"). Empty array when the level has none.
func mission_steps() -> Array:
	return current_level().get("mission_steps", [])


func completed_mission_steps() -> Array:
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return []
	var state: Dictionary = progress.get("mission_step_state", {})
	var done: Variant = state.get(level_id, [])
	if done is Array:
		return done
	return []


# First step (in declared order) not yet marked done; empty dict when the
# level has no steps or all steps are complete.
func next_pending_mission_step() -> Dictionary:
	var steps := mission_steps()
	if steps.is_empty():
		return {}
	var done := completed_mission_steps()
	for step_value in steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var step_id := str(step.get("id", ""))
		if step_id != "" and not done.has(step_id):
			return step
	return {}


# Only ever appends (steps do not un-complete once reached).
func mark_mission_step_done(step_id: String) -> void:
	if step_id == "":
		return
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return
	if not progress.get("mission_step_state") is Dictionary:
		progress["mission_step_state"] = {}
	var state: Dictionary = progress["mission_step_state"]
	var done: Variant = state.get(level_id, [])
	if not done is Array:
		done = []
	if not done.has(step_id):
		done.append(step_id)
	state[level_id] = done
	progress["mission_step_state"] = state
	save()


# ------------------------------------------------------------ finder offset


const FINDER_ALIGNED_THRESHOLD := 0.5


# A persistent (across sessions) misalignment between the finder scope and
# the main telescope. Only L15's variation surfaces a calibration UI for it,
# but the offset itself applies whenever it is non-zero, everywhere.
func finder_offset() -> Dictionary:
	var offset: Variant = progress.get("finder_offset", {"az": 0.0, "alt": 0.0})
	if offset is Dictionary:
		return offset
	return {"az": 0.0, "alt": 0.0}


func finder_offset_length() -> float:
	var offset := finder_offset()
	return Vector2(float(offset.get("az", 0.0)), float(offset.get("alt", 0.0))).length()


func finder_alignment_percent() -> float:
	# Normalize by the INITIAL seeded misalignment, not a fixed 3.0 - the
	# seed can exceed 3 deg, which pinned the readout at 0% and gave the
	# player no feedback gradient while adjusting.
	var initial := maxf(float(progress.get("finder_offset_initial_len", 3.0)), 0.5)
	return clampf(1.0 - finder_offset_length() / initial, 0.0, 1.0) * 100.0


func is_finder_aligned() -> bool:
	return finder_offset_length() < FINDER_ALIGNED_THRESHOLD


# L15 seeds a real, persistent misalignment the first time the player enters
# the sky on that level; every level after inherits whatever offset is left
# (zero once L15 is calibrated, per the design).
func seed_finder_offset_if_needed() -> void:
	if bool(progress.get("finder_offset_seeded", false)):
		return
	var sign_az := 1.0 if (randi() % 2 == 0) else -1.0
	var sign_alt := 1.0 if (randi() % 2 == 0) else -1.0
	var az := sign_az * (1.5 + randf() * 1.5)
	var alt := sign_alt * (1.5 + randf() * 1.5)
	# Guarantee a real, noticeable misalignment (>= 2 deg total).
	if Vector2(az, alt).length() < 2.0:
		az *= 1.6
		alt *= 1.6
	progress["finder_offset"] = {"az": az, "alt": alt}
	progress["finder_offset_initial_len"] = Vector2(az, alt).length()
	progress["finder_offset_seeded"] = true
	save()


func adjust_finder_offset(delta_az: float, delta_alt: float) -> void:
	var offset := finder_offset()
	var az := float(offset.get("az", 0.0)) + delta_az
	var alt := float(offset.get("alt", 0.0)) + delta_alt
	progress["finder_offset"] = {"az": az, "alt": alt}
	if finder_offset_length() < FINDER_ALIGNED_THRESHOLD:
		# Calibrated: snap to true zero and persist so the finder stays
		# trustworthy in every later level.
		progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	save()


# ------------------------------------------------------------ tracking rate


# Tracking-mount rate (0-2x), persisted across sessions (E2 drift/tracking).
# Only meaningful when a tracking-capable mount is equipped on a drift level,
# but the value itself is harmless to keep around otherwise.
func tracking_rate() -> float:
	return float(progress.get("tracking_rate", 0.0))


func set_tracking_rate(value: float) -> void:
	progress["tracking_rate"] = clampf(value, 0.0, 2.0)
	save()


func has_tracking_mount_equipped() -> bool:
	var mount := get_part(equipped_part_id("mount"))
	return bool(mount.get("tracking_capable", false))


func current_environment() -> Dictionary:
	var level := current_level()
	var environment: Dictionary = level.get("environment", {})
	if not environment.is_empty():
		return environment
	# Backward-compatible fallback: L20/21-style top-level fields, folded
	# into an environment dict so ObservationSystem only has one shape to read.
	if level.has("sky_brightness"):
		return {"sky_brightness": str(level.get("sky_brightness", ""))}
	return {}


func calculate_stats() -> Dictionary:
	var selected_parts := get_selected_parts()
	# A save can retain selections from a different telescope family. Keep
	# those parts in inventory, but only feed generic parts and parts belonging
	# to this lesson's family into the optical calculation.
	var family := str(current_level().get("telescope_family", "refractor"))
	for part_type in selected_parts.keys():
		var part: Dictionary = selected_parts[part_type]
		var part_family := str(part.get("telescope_family", ""))
		if part_family != "" and part_family != family:
			selected_parts.erase(part_type)
	var assembly_state: Dictionary = progress.get("assembly_state", {}).duplicate(true)
	if _uses_tube_subassembly():
		var installed_subparts: Dictionary = tube_assembly().get("installed_subparts", {})
		if bool(installed_subparts.get("focuser", false)):
			var tube_focus_score := float(tube_assembly().get("optical_alignment", tube_assembly().get("subassembly_score", 0.0)))
			assembly_state["focuser"] = {"installed": true, "alignment_score": tube_focus_score, "wrong_attempts": 0}
	var stats: Dictionary = TelescopeMathScript.calculate(selected_parts, assembly_state)
	if _uses_tube_subassembly():
		var tube_state := tube_assembly()
		var subassembly_score := float(tube_state.get("subassembly_score", 0.0))
		stats["subassembly_score"] = subassembly_score
		stats["assembly_score"] = minf(float(stats.get("assembly_score", 0.0)), subassembly_score)
		stats["clarity_score"] = snapped(float(stats.get("clarity_score", 0.0)) * subassembly_score / 100.0, 0.1)
	if bool(current_level().get("requires_collimation", false)):
		var score: float = collimation_score()
		stats["collimation_score"] = score
		stats["clarity_score"] = snapped(float(stats.get("clarity_score", 0.0)) * (0.45 + score / 200.0), 0.1)
	else:
		stats["collimation_score"] = 100.0
	return stats


func collimation_score() -> float:
	var family := str(current_level().get("telescope_family", "newtonian"))
	var scores: Dictionary = progress.get("collimation_scores", {})
	return float(scores.get(family, 0.0))


func collimation_is_acceptable() -> bool:
	var threshold := float(current_level().get("collimation_threshold", 0.0))
	return threshold <= 0.0 or collimation_score() >= threshold


func set_collimation_score(value: float) -> void:
	var family := str(current_level().get("telescope_family", "newtonian"))
	if not progress.get("collimation_scores") is Dictionary:
		progress["collimation_scores"] = {}
	progress["collimation_scores"][family] = clampf(value, 0.0, 100.0)
	if progress.get("tube_assemblies") is Dictionary and progress["tube_assemblies"].has(family):
		var tube_state: Dictionary = progress["tube_assemblies"][family]
		tube_state["collimation_score"] = progress["collimation_scores"][family]
		progress["tube_assemblies"][family] = tube_state
	save()


func evaluate_selected_object(extra_context: Dictionary = {}) -> Dictionary:
	var obj := get_object(selected_object_id)
	if not extra_context.has("observation_mode"):
		extra_context["observation_mode"] = current_observation_mode()
	if not extra_context.has("minimum_success_quality"):
		extra_context["minimum_success_quality"] = str(current_level().get("minimum_success_quality", "Good"))
	var stats := calculate_stats()
	if str(extra_context["observation_mode"]) == "telescope":
		if not extra_context.has("environment"):
			extra_context["environment"] = current_environment()
		if not extra_context.has("altitude"):
			var aim: Dictionary = last_sky_aim
			var altitude := 45.0
			if bool(aim.get("valid", false)):
				altitude = float(aim.get("altitude", 45.0))
			extra_context["altitude"] = altitude
		if not extra_context.has("magnification"):
			extra_context["magnification"] = float(stats.get("magnification", 0.0))
	last_observation = ObservationSystemScript.evaluate(stats, obj, extra_context)
	return last_observation


func complete_current_mission(object_id: String, observation: Dictionary) -> bool:
	var level := current_level()
	if object_id != current_target_object_id():
		return false
	if not next_pending_mission_step().is_empty():
		return false
	if not bool(observation.get("success", false)):
		return false
	var level_number: int = int(level.get("level_number", progress.get("current_level", 1)))
	var already_completed: bool = progress["completed_levels"].has(level_number)
	if already_completed:
		set_room_guidance(
			"journal",
			"Maya: Already Logged",
			"This observation is already complete. Open the Club Logbook or keep exploring."
		)
		save()
		go("observatory")
		return true
	if not already_completed:
		progress["completed_levels"].append(level_number)
		progress["credits"] = int(progress.get("credits", 0)) + int(level.get("reward_credits", 0))
		for part_id in level.get("unlock_parts", []):
			if not progress["unlocked_parts"].has(part_id):
				progress["unlocked_parts"].append(part_id)
				_queue_unlock_notice(str(part_id))
		var badge: String = str(level.get("badge", ""))
		if badge != "" and not progress["badges"].has(badge):
			progress["badges"].append(badge)
	var concept_card_id := str(level.get("required_concept_card", ""))
	if concept_card_id != "":
		if not progress.has("completed_concept_cards"):
			progress["completed_concept_cards"] = []
		if not progress["completed_concept_cards"].has(concept_card_id):
			progress["completed_concept_cards"].append(concept_card_id)
	var stage := str(level.get("unlock_equipment_stage", level.get("equipment_stage", "")))
	if stage != "":
		if not progress.has("unlocked_equipment_stages"):
			progress["unlocked_equipment_stages"] = ["eye"]
		if not progress["unlocked_equipment_stages"].has(stage):
			progress["unlocked_equipment_stages"].append(stage)
	_add_journal_entry(object_id, observation)
	var payload: Dictionary = TeachingFlowManager.make_mission_complete_payload(
		level, get_object(object_id), observation, calculate_stats()
	)
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null and mission_manager.is_final_level(level_number):
		# Finishing the whole club program earns the final story badge.
		if not progress["badges"].has("Young Observer"):
			progress["badges"].append("Young Observer")
		progress["program_completed"] = true
		set_room_guidance(
			"journal",
			"Maya: Program Complete",
			"Great work. Open the Club Logbook to review your discoveries."
		)
	if level_number >= int(progress.get("current_level", 1)) and mission_manager != null and not mission_manager.is_final_level(level_number):
		progress["current_level"] = level_number + 1
		_unlock_parts_for_current_level()
	save()
	# Point the player at the next step for the (possibly new) level.
	update_room_guidance_for_level()
	show_mission_complete_card(payload)
	return true


func _mission_manager() -> Variant:
	return get_node_or_null("/root/MissionManager")


func _add_journal_entry(object_id: String, observation: Dictionary) -> void:
	var obj := get_object(object_id)
	var stats := calculate_stats()
	var level := current_level()
	var objective := get_part(equipped_part_id("objective"))
	var eyepiece := get_part(equipped_part_id("eyepiece"))
	var mount := get_part(equipped_part_id("mount"))
	var environment := current_environment()
	var concept_id := str(level.get("required_concept_card", ""))
	var concept := get_learning_card(concept_id)
	# Repeat practice of a known concept is logged as a comparison run, not a
	# duplicate knowledge card.
	var prior_index := -1
	for entry_index in range(progress["journal_entries"].size()):
		var prior: Dictionary = progress["journal_entries"][entry_index]
		if concept_id != "" and str(prior.get("concept_card_id", "")) == concept_id:
			prior_index = entry_index + 1
			break
	var knowledge_en := str(concept.get("title_en", obj.get("learning_text_en", "")))
	var knowledge_zh := str(concept.get("title_zh", obj.get("learning_text_zh", "")))
	var entry_kind_en := "First experiment"
	var entry_kind_zh := "首次实验"
	if prior_index > 0:
		entry_kind_en = "Repeat experiment"
		entry_kind_zh = "对比实验"
		knowledge_en = "Repeat practice of \"%s\" - compare with entry #%02d." % [knowledge_en, prior_index]
		knowledge_zh = "再次练习「%s」——与第 %02d 条记录对比。" % [knowledge_zh, prior_index]
	var recap: Dictionary = StoryManager.recap_for_level(int(level.get("level_number", 0)))
	# Process record: what the player actually had to manage this session.
	var process_en: Array[String] = []
	var process_zh: Array[String] = []
	if bool(level.get("requires_focus", false)):
		process_en.append("Focus: locked in")
		process_zh.append("调焦：已合焦")
	if bool(level.get("requires_collimation", false)):
		process_en.append("Collimation: %d%%" % roundi(collimation_score()))
		process_zh.append("准直：%d%%" % roundi(collimation_score()))
	if bool(level.get("drift_enabled", false)):
		if has_tracking_mount_equipped() and tracking_rate() > 0.5:
			process_en.append("Tracking: mount at %.2fx" % tracking_rate())
			process_zh.append("追踪：支架 %.2f 倍速" % tracking_rate())
		else:
			process_en.append("Tracking: held by hand (%ds)" % int(level.get("hold_seconds", 0)))
			process_zh.append("追踪：手动保持 %d 秒" % int(level.get("hold_seconds", 0)))
	progress["journal_entries"].append({
		"object_id": object_id,
		"object_name_en": obj.get("name_en", object_id),
		"object_name_zh": obj.get("name_zh", object_id),
		"object_type_en": obj.get("type_en", ""),
		"object_type_zh": obj.get("type_zh", ""),
		"level_completed": level.get("level_number", progress.get("current_level", 1)),
		"assembly_score": stats.get("assembly_score", 0),
		"observation_quality": observation.get("quality", "Unknown"),
		"learning_text_en": obj.get("learning_text_en", ""),
		"learning_text_zh": obj.get("learning_text_zh", ""),
		"observation_mode": observation.get("observation_mode", current_observation_mode()),
		"concept_card_id": concept_id,
		"concept_title_en": str(concept.get("title_en", "")),
		"concept_title_zh": str(concept.get("title_zh", "")),
		"variation": str(level.get("variation", "")),
		"magnification": float(stats.get("magnification", 0.0)),
		"objective_aperture_mm": int(objective.get("aperture_mm", 0)),
		"objective_focal_length_mm": int(objective.get("focal_length_mm", 0)),
		"eyepiece_focal_length_mm": int(eyepiece.get("focal_length_mm", 0)),
		"equipment_en": _journal_equipment_summary("en", objective, eyepiece, mount),
		"equipment_zh": _journal_equipment_summary("zh", objective, eyepiece, mount),
		"environment_en": _journal_environment_summary("en", environment),
		"environment_zh": _journal_environment_summary("zh", environment),
		"actions_en": _journal_action_summary("en", level, observation),
		"actions_zh": _journal_action_summary("zh", level, observation),
		"result_en": "Recorded " + str(observation.get("quality", "Unknown")) + " quality after this setup.",
		"result_zh": "使用本次配置记录到" + str(observation.get("quality", "Unknown")) + "质量的观测结果。",
		"knowledge_en": knowledge_en,
		"knowledge_zh": knowledge_zh,
		"entry_kind_en": entry_kind_en,
		"entry_kind_zh": entry_kind_zh,
		"process_en": " | ".join(process_en),
		"process_zh": " | ".join(process_zh),
		"maya_en": str(recap.get("en", "")),
		"maya_zh": str(recap.get("zh", ""))
	})
	if not progress["observed_objects"].has(object_id):
		progress["observed_objects"].append(object_id)


func _journal_equipment_summary(locale: String, objective: Dictionary, eyepiece: Dictionary, mount: Dictionary) -> String:
	var objective_name := str(objective.get("name_%s" % locale, objective.get("id", "objective")))
	var eyepiece_name := str(eyepiece.get("name_%s" % locale, eyepiece.get("id", "eyepiece")))
	var mount_name := str(mount.get("name_%s" % locale, mount.get("id", "mount")))
	return "%s | %s | %s" % [objective_name, eyepiece_name, mount_name]


func _journal_environment_summary(locale: String, environment: Dictionary) -> String:
	if environment.is_empty():
		return "Clear sky" if locale == "en" else "晴朗天空"
	var parts: Array[String] = []
	var seeing := str(environment.get("seeing", ""))
	var clouds := float(environment.get("cloud_cover", 0.0))
	var sky := str(environment.get("sky_brightness", ""))
	if seeing != "":
		parts.append("Seeing: " + seeing.capitalize() if locale == "en" else "视宁度：" + seeing)
	if clouds > 0.0:
		parts.append("Cloud: %d%%" % int(round(clouds * 100.0)) if locale == "en" else "云量：%d%%" % int(round(clouds * 100.0)))
	if sky != "":
		parts.append("Sky: " + sky.capitalize() if locale == "en" else "天空：" + sky)
	return " | ".join(parts)


func _journal_action_summary(locale: String, level: Dictionary, observation: Dictionary) -> String:
	var actions: Array[String] = []
	if bool(level.get("requires_focus", false)):
		actions.append("Focused the eyepiece" if locale == "en" else "调节目镜焦点")
	var variation := str(level.get("variation", ""))
	if variation == "eyepiece_comparison":
		actions.append("Compared low and high power" if locale == "en" else "比较低倍率与高倍率")
	elif variation == "finder_calibration":
		actions.append("Calibrated finder alignment" if locale == "en" else "校准寻星镜")
	elif variation == "tracking_mount":
		actions.append("Set the tracking rate" if locale == "en" else "设置追踪速率")
	elif variation == "accept_fair_quality" or variation == "dark_sky":
		actions.append("Waited for dark adaptation" if locale == "en" else "等待暗适应")
	elif bool(level.get("drift_enabled", false)):
		actions.append("Kept the target centered" if locale == "en" else "持续保持目标居中")
	if actions.is_empty():
		actions.append("Centered and identified the target" if locale == "en" else "居中并识别目标")
	return "; ".join(actions)


func _unlock_parts_for_current_level() -> void:
	var current: int = int(progress.get("current_level", 1))
	for part in parts_data:
		if int(part.get("unlock_level", 999)) <= current:
			var part_id: String = str(part.get("id", ""))
			if part_id != "" and not progress["unlocked_parts"].has(part_id):
				progress["unlocked_parts"].append(part_id)
				_queue_unlock_notice(part_id)


func _queue_unlock_notice(part_id: String) -> void:
	# Newly unlocked parts are announced with a popup the next time the
	# player stands in the observatory (see observatory_room).
	if not progress.has("pending_unlock_notice") or not progress["pending_unlock_notice"] is Array:
		progress["pending_unlock_notice"] = []
	if not progress["pending_unlock_notice"].has(part_id):
		progress["pending_unlock_notice"].append(part_id)


func take_pending_unlock_notice() -> Array:
	var pending: Array = progress.get("pending_unlock_notice", [])
	if pending.is_empty():
		return []
	var result := pending.duplicate()
	progress["pending_unlock_notice"] = []
	save()
	return result


func _fresh_assembly_state() -> Dictionary:
	return {
		"tripod": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"mount": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"tube": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"objective": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"eyepiece": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"finder_scope": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"focus_knob": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"reflector_tube": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"mirror_cell": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"primary_mirror": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"secondary_spider": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"secondary_mirror": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"focuser": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"collimation_tool": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"detector": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"sunshield": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"radio_dish": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"receiver": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"signal_processor": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"optical_tube_assembly": {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
	}


func _normalize_progress() -> void:
	var defaults := default_progress()
	for key in defaults.keys():
		if not progress.has(key):
			progress[key] = defaults[key]
	_ensure_progress_array("completed_levels")
	_ensure_progress_array("unlocked_parts")
	_ensure_progress_array("observed_objects")
	_ensure_progress_array("badges")
	_ensure_progress_array("journal_entries")
	_ensure_progress_array("completed_concept_cards")
	_ensure_progress_array("seen_teaching_steps")
	_ensure_progress_array("seen_concept_briefs")
	_ensure_progress_array("seen_story_events")
	_ensure_progress_array("pending_unlock_notice")
	_migrate_progress_schema()


func _migrate_progress_schema() -> void:
	# Campaign renumbering (90 -> 91 levels, 2026-07-18): the 10th Newtonian
	# level was inserted at L34, shifting every later level up by one. Saves
	# without a campaign_version that sit at L34+ follow their content.
	if int(progress.get("campaign_version", 0)) < 91:
		var current: int = int(progress.get("current_level", 1))
		if current >= 34:
			progress["current_level"] = current + 1
		var shifted_completed: Array = []
		for completed_value in progress.get("completed_levels", []):
			var completed: int = int(completed_value)
			shifted_completed.append(completed + 1 if completed >= 34 else completed)
		progress["completed_levels"] = shifted_completed
		progress["campaign_version"] = 91
	# Old saves predate newer part types (e.g. focus_knob): backfill any
	# missing assembly_state slots and selected_parts defaults.
	if not progress.get("assembly_state") is Dictionary:
		progress["assembly_state"] = _fresh_assembly_state()
	if not progress.get("selected_parts") is Dictionary:
		progress["selected_parts"] = default_progress()["selected_parts"]
	var fresh := _fresh_assembly_state()
	for part_type in fresh.keys():
		if not progress["assembly_state"].has(part_type):
			progress["assembly_state"][part_type] = fresh[part_type]
	var default_selected: Dictionary = default_progress()["selected_parts"]
	for part_type in default_selected.keys():
		if not progress["selected_parts"].has(part_type):
			progress["selected_parts"][part_type] = default_selected[part_type]
	if not progress.get("mission_step_state") is Dictionary:
		progress["mission_step_state"] = {}
	if not progress.get("level_target_overrides") is Dictionary:
		progress["level_target_overrides"] = {}
	if not progress.get("finder_offset") is Dictionary:
		progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	if not progress.has("finder_offset_seeded"):
		progress["finder_offset_seeded"] = false
	if not progress.has("finder_offset_initial_len"):
		# Saves seeded before the field existed: use whichever is larger of
		# the legacy 3.0 baseline and the live offset, so the alignment
		# readout starts responsive instead of pinned at 0%.
		progress["finder_offset_initial_len"] = maxf(3.0, finder_offset_length())
	if not (progress.get("tracking_rate") is float or progress.get("tracking_rate") is int):
		progress["tracking_rate"] = 0.0
	if not progress.get("collimation_scores") is Dictionary:
		progress["collimation_scores"] = {"newtonian": 0.0}
	elif not progress["collimation_scores"].has("newtonian"):
		progress["collimation_scores"]["newtonian"] = 0.0
	if not progress.get("tube_assemblies") is Dictionary:
		progress["tube_assemblies"] = {}
	progress["language_mode"] = _normalized_language_mode(str(progress.get("language_mode", "en")))
	language_mode = str(progress["language_mode"])


func _ensure_progress_array(key: String) -> void:
	if not progress.has(key) or not progress[key] is Array:
		progress[key] = []


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
