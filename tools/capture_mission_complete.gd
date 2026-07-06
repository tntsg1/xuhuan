extends SceneTree

# Captures the rebuilt Mission Complete screen for several target types.
# Run:
# Godot --headless --path E:/godot/ai-game-0628 --script res://tools/capture_mission_complete.gd

const CASES := [
	{"level": 3, "object": "moon", "quality": "Excellent", "file": "mission_complete_moon.png"},
	{"level": 4, "object": "jupiter", "quality": "Good", "file": "mission_complete_jupiter.png"},
	{"level": 18, "object": "orion_nebula", "quality": "Fair", "file": "mission_complete_orion_nebula.png"},
	{"level": 21, "object": "andromeda", "quality": "Good", "file": "mission_complete_andromeda.png"}
]

var frames := 0
var case_index := -1
var view: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		_next_case()
		return
	if case_index >= 0 and frames % 8 == 0:
		_capture_current()
		_next_case()


func _next_case() -> void:
	case_index += 1
	if case_index >= CASES.size():
		quit(0)
		return
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var tf: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or tf == null:
		print("FAIL: missing GameManager or TeachingFlowManager")
		quit(1)
		return
	var item: Dictionary = CASES[case_index]
	gm.call("new_game")
	gm.progress["current_level"] = int(item["level"])
	var level: Dictionary = gm.call("current_level")
	var observation: Dictionary = _observation(str(item["quality"]))
	gm.last_learning_card = tf.call(
		"make_mission_complete_payload",
		level,
		gm.call("get_object", str(item["object"])),
		observation,
		_stats_for_quality(str(item["quality"]))
	)
	tf.active_card_mode = "complete"
	_swap_card()


func _swap_card() -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load("res://scenes/learning_card.tscn")
	view = packed.instantiate()
	root.add_child(view)


func _capture_current() -> void:
	var item: Dictionary = CASES[case_index]
	var path := "user://" + str(item["file"])
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	if view != null:
		view.queue_free()
		view = null


func _observation(quality: String) -> Dictionary:
	var ratio := 1.0
	match quality:
		"Excellent":
			ratio = 1.30
		"Good":
			ratio = 1.04
		"Fair":
			ratio = 0.78
		_:
			ratio = 0.55
	return {
		"quality": quality,
		"success": true,
		"observation_mode": "telescope",
		"effective_clarity": clampf(ratio * 78.0, 0.0, 100.0),
		"ratios": {
			"light": ratio,
			"clarity": ratio,
			"stability": ratio
		}
	}


func _stats_for_quality(quality: String) -> Dictionary:
	var value := 82.0
	match quality:
		"Excellent":
			value = 95.0
		"Good":
			value = 78.0
		"Fair":
			value = 58.0
	return {
		"light_score": value,
		"clarity_score": value,
		"stability_score": value,
		"magnification": 60.0
	}
