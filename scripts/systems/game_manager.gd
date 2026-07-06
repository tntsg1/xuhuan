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
var language_mode := "both"
var observatory_spawn_id := "default"
# Last sky-observation aim, restored when re-entering the pad.
var last_sky_aim: Dictionary = {"valid": false}


func _ready() -> void:
	parts_data = _load_json_array("res://data/telescope_parts.json")
	objects_data = _load_json_array("res://data/celestial_objects.json")
	levels_data = _load_json_array("res://data/levels.json")
	learning_cards_data = _load_json_array("res://data/learning_cards.json")
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null:
		mission_manager.load_levels(levels_data)
	progress = SaveManager.load_progress(default_progress())
	_normalize_progress()
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
		"language_mode": "both",
		"mission_step_state": {},
		"level_target_overrides": {},
		"finder_offset": {"az": 0.0, "alt": 0.0},
		"finder_offset_seeded": false,
		"tracking_rate": 0.0
	}


func new_game() -> void:
	progress = SaveManager.reset_progress(default_progress())
	language_mode = str(progress.get("language_mode", "both"))
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


func set_room_guidance(target: String, title: String, hint: String) -> void:
	room_guidance_target = target
	room_guidance_title = title
	room_guidance_hint = hint


func clear_room_guidance() -> void:
	room_guidance_target = ""
	room_guidance_title = ""
	room_guidance_hint = ""


func update_room_guidance_for_level() -> void:
	# Next-step guidance shown in the observatory after a mission completes
	# (or a new level starts): derived from the CURRENT level and progress.
	if not current_requires_telescope():
		set_room_guidance_for_scene("sky", "")
	elif not telescope_is_ready():
		set_room_guidance_for_scene("assembly", "")
	elif _deep_sky_target() and str(current_level().get("minimum_success_quality", "Good")) == "Good" and _has_better_unequipped_part():
		# Faint targets need the upgraded optics the player just unlocked.
		set_room_guidance_for_scene("parts", "")
	else:
		set_room_guidance_for_scene("sky", "")


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
	if not current_requires_telescope():
		return {
			"ok": true,
			"reason_en": "Naked eye observation - no telescope needed.",
			"reason_zh": "肉眼观测——不需要望远镜。"
		}
	if telescope_is_ready():
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
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], current_level().get("required_parts", []))
	save()
	return score


func telescope_is_ready() -> bool:
	return bool(progress.get("telescope_ready", false)) and AssemblyManagerScript.is_complete(progress["assembly_state"], current_level().get("required_parts", []))


func equip_part(part_id: String) -> bool:
	var part := get_part(part_id)
	if part.is_empty():
		return false
	var part_type: String = str(part.get("type", ""))
	if part_type == "":
		return false
	if not progress.get("unlocked_parts", []).has(part_id):
		return false
	if str(progress["selected_parts"].get(part_type, "")) == part_id:
		return true
	progress["selected_parts"][part_type] = part_id
	# Swapping a part means it must be reinstalled on the bench.
	if progress["assembly_state"].has(part_type):
		progress["assembly_state"][part_type] = {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], current_level().get("required_parts", []))
	save()
	return true


func equipped_part_id(part_type: String) -> String:
	return str(progress.get("selected_parts", {}).get(part_type, ""))


func missing_parts() -> Array:
	return AssemblyManagerScript.missing_parts(progress["assembly_state"], current_level().get("required_parts", []))


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
	return clampf(1.0 - finder_offset_length() / 3.0, 0.0, 1.0) * 100.0


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
	return TelescopeMathScript.calculate(get_selected_parts(), progress.get("assembly_state", {}))


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
		"learning_text_zh": obj.get("learning_text_zh", ""),
		"observation_mode": observation.get("observation_mode", current_observation_mode()),
		"concept_card_id": str(current_level().get("required_concept_card", "")),
		"concept_title_en": str(get_learning_card(str(current_level().get("required_concept_card", ""))).get("title_en", "")),
		"concept_title_zh": str(get_learning_card(str(current_level().get("required_concept_card", ""))).get("title_zh", ""))
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
		"focus_knob": {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
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
	if not (progress.get("tracking_rate") is float or progress.get("tracking_rate") is int):
		progress["tracking_rate"] = 0.0


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
