extends Node

# Story Manager - Astronomy Club narrative layer.
#
# Plays short Maya dialogues at key moments (new game intro, before an
# observation / assembly / focus session, and recap lines on the Mission
# Complete card). Works IN FRONT of TeachingFlowManager: an entry point
# first asks for a story intercept, and when the dialogue finishes this
# manager chains into the teaching intercept for the same trigger, so the
# order is always  story -> concept brief -> gameplay scene.
#
# Bookkeeping: progress["seen_story_events"] stores event ids; an event
# never replays.

const DIALOGUES_PATH := "res://data/story_dialogues.json"

# Events are found by naming convention against the loaded dialogue data:
#   before_observation -> "level_N_before"
#   before_assembly    -> "level_N_before_assembly"
#   before_focus       -> "level_N_before_focus"
# A level has a story for a trigger exactly when that key exists in
# story_dialogues.json - no hardcoded per-level table to maintain.
const TRIGGER_SUFFIXES := {
	"before_observation": "level_%d_before",
	"before_assembly": "level_%d_before_assembly",
	"before_focus": "level_%d_before_focus"
}

# Semantic mechanic name -> first-time story event. UI scenes ask by mechanic
# name; they never hardcode event ids.
const MECHANIC_EVENTS := {
	"tube_subassembly": "first_tube_subassembly",
	"collimation": "first_collimation"
}

# Levels whose "level_N_after" lines play as a short epilogue dialogue after
# the Mission Complete card (L25+ family arcs). L1-24 keep recap-only behavior.
const EPILOGUE_MIN_LEVEL := 25

var dialogues: Dictionary = {}
var active_event_id := ""
var active_lines: Array = []
var return_scene_key := ""
var pending_trigger := ""


func _ready() -> void:
	dialogues = _load_json_dict(DIALOGUES_PATH)


# ------------------------------------------------------------------ queries


func get_dialogue(event_id: String) -> Array:
	var lines: Variant = dialogues.get(event_id, [])
	if lines is Array and not lines.is_empty():
		return lines
	return _advanced_fallback_dialogue(event_id)


func _advanced_fallback_dialogue(event_id: String) -> Array:
	if not event_id.begins_with("level_"):
		return []
	var gm := _game_manager()
	if gm == null:
		return []
	var family := str(gm.current_level().get("telescope_family", ""))
	var target: String = str(gm.dict_text(gm.current_target(), "name"))
	var line_en := ""
	var line_zh := ""
	match family:
		"newtonian":
			line_en = "This reflector uses mirrors in a new light path. Build it in order, then align it before Orion."
			line_zh = "这台反射镜使用新的光路。按顺序组装，再为猎户座完成准直。"
		"dobsonian":
			line_en = "A Dobsonian is simple and bright, but your hands provide the tracking. Use gentle corrections."
			line_zh = "多布森结构简单而明亮，但追踪要靠你的双手。请使用轻微修正。"
		"cassegrain":
			line_en = "This compact tube folds a long focal length with two mirrors. The narrow view rewards careful aiming."
			line_zh = "这台紧凑镜筒用两面镜子折叠长焦距，狭窄视场需要更仔细地对准。"
		"gregorian":
			line_en = "This two-mirror layout is not a power upgrade. Trace where the light focuses and compare it deliberately."
			line_zh = "这套双镜布局不是单纯性能升级。追踪光线在哪里聚焦，再有目的地比较它。"
		"space_segmented":
			line_en = "A segmented mirror and cold infrared instruments reveal signals that visible light misses."
			line_zh = "分段主镜和低温红外仪器能揭示可见光错过的信号。"
		"fast_radio":
			line_en = "This time there is no eyepiece image. A dish, receiver, and data trace will guide you to the source."
			line_zh = "这次没有目镜图像。天线、接收机和数据轨迹会引导你找到目标。"
		"multi_device":
			line_en = "Choose the observatory that measures the signal needed for " + target + "."
			line_zh = "请选择能测量 " + target + " 所需信号的观测台。"
		_:
			return []
	return [{"speaker": "Maya", "portrait": "maya", "text_en": line_en, "text_zh": line_zh}]


func has_seen(event_id: String, progress: Dictionary) -> bool:
	return progress.get("seen_story_events", []).has(event_id)


func event_for_trigger(trigger: String, level_number: int) -> String:
	var pattern := str(TRIGGER_SUFFIXES.get(trigger, ""))
	if pattern == "":
		return ""
	var event_id := pattern % level_number
	if dialogues.has(event_id):
		return event_id
	return ""


func recap_for_level(level_number: int) -> Dictionary:
	# First line of "level_N_after" becomes Maya's recap on Mission Complete.
	var lines := get_dialogue("level_%d_after" % level_number)
	if lines.is_empty() or not lines[0] is Dictionary:
		return {}
	var line: Dictionary = lines[0]
	return {
		"en": str(line.get("text_en", "")),
		"zh": str(line.get("text_zh", ""))
	}


func board_note_for_level(level_number: int) -> Dictionary:
	var notes: Dictionary = dialogues.get("board_notes", {})
	var note: Variant = notes.get(str(level_number), {})
	if note is Dictionary:
		return note
	return {}


# ------------------------------------------------------------------- routing


func begin_event(event_id: String, scene_key: String, follow_trigger: String = "") -> bool:
	var gm := _game_manager()
	if gm == null or event_id == "":
		return false
	if has_seen(event_id, gm.progress):
		return false
	var lines := get_dialogue(event_id)
	if lines.is_empty():
		return false
	active_event_id = event_id
	active_lines = lines
	return_scene_key = scene_key
	pending_trigger = follow_trigger
	gm.go("story")
	return true


func begin_mechanic_event(mechanic: String, scene_key: String, follow_trigger: String = "") -> bool:
	# First-time introduction for a game mechanic (tube sub-assembly,
	# collimation, ...). Replays never happen thanks to seen_story_events.
	return begin_event(str(MECHANIC_EVENTS.get(mechanic, "")), scene_key, follow_trigger)


func begin_epilogue(level_number: int, scene_key: String) -> bool:
	# Post-mission Maya dialogue for advanced levels: summary + motivation for
	# the next stage. The same lines' first entry stays the recap on the
	# Mission Complete card.
	if level_number < EPILOGUE_MIN_LEVEL:
		return false
	return begin_event("level_%d_after" % level_number, scene_key)


func begin_event_for_trigger(trigger: String, scene_key: String) -> bool:
	var gm := _game_manager()
	if gm == null:
		return false
	var level_number: int = int(gm.current_level().get("level_number", 0))
	return begin_event(event_for_trigger(trigger, level_number), scene_key, trigger)


func finish_active_event() -> void:
	# Mark seen, then hand over to the teaching flow (concept brief) or go
	# straight to the stored scene.
	var gm := _game_manager()
	if gm == null:
		return
	if active_event_id != "":
		if not gm.progress.has("seen_story_events"):
			gm.progress["seen_story_events"] = []
		if not gm.progress["seen_story_events"].has(active_event_id):
			gm.progress["seen_story_events"].append(active_event_id)
	var completed_event_id := active_event_id
	var scene := return_scene_key
	var trigger := pending_trigger
	active_event_id = ""
	active_lines = []
	return_scene_key = ""
	pending_trigger = ""
	if scene == "":
		scene = "observatory"
	gm.save()
	# Device-triggered stories continue straight into the destination the
	# player already chose; only the intro routes through the observatory
	# with room guidance.
	if completed_event_id == "intro":
		gm.set_room_guidance("telescope", "Maya: Observation Pad", "Walk to the Observation Pad and press E.")
	if trigger != "" and gm.try_teaching_intercept(trigger, scene):
		return
	gm.go(scene)


func reset_flow() -> void:
	active_event_id = ""
	active_lines = []
	return_scene_key = ""
	pending_trigger = ""


func _game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
