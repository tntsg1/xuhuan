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

# trigger -> level_number -> event id
const TRIGGER_EVENTS := {
	"before_observation": {
		1: "level_1_before",
		2: "level_2_before",
		5: "level_5_before",
		6: "level_6_before",
		8: "level_8_before",
		9: "level_9_before",
		10: "level_10_before",
		11: "level_11_before",
		12: "level_12_before",
		13: "level_13_before",
		14: "level_14_before",
		15: "level_15_before",
		16: "level_16_before",
		17: "level_17_before",
		18: "level_18_before",
		19: "level_19_before",
		20: "level_20_before",
		21: "level_21_before",
		22: "level_22_before",
		23: "level_23_before",
		24: "level_24_before"
	},
	"before_assembly": {
		3: "level_3_before_assembly",
		7: "level_7_before_assembly"
	},
	"before_focus": {
		4: "level_4_before_focus"
	}
}

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
	if lines is Array:
		return lines
	return []


func has_seen(event_id: String, progress: Dictionary) -> bool:
	return progress.get("seen_story_events", []).has(event_id)


func event_for_trigger(trigger: String, level_number: int) -> String:
	var by_level: Dictionary = TRIGGER_EVENTS.get(trigger, {})
	return str(by_level.get(level_number, ""))


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
