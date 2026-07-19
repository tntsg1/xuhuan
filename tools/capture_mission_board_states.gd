extends SceneTree

# Captures Chinese Mission Board states at 1024x768. Run without --headless.
# The caller should back up the save because this script creates test progress.

const CASES := [
	{"level": 1, "file": "mission_board_L1_zh.png"},
	{"level": 3, "file": "mission_board_L3_zh.png"},
	{"level": 4, "file": "mission_board_L4_zh.png"},
	{"level": 10, "file": "mission_board_L10_zh.png"}
]

var case_index := -1
var frames := 0
var room: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if case_index < 0 or frames % 28 == 1:
		case_index += 1
		if case_index >= CASES.size():
			quit()
			return
		_open_case(CASES[case_index])
		return
	if frames % 28 == 16:
		var capture := root.get_texture().get_image()
		capture.save_png("user://" + str(CASES[case_index].get("file", "mission_board.png")))


func _open_case(case_data: Dictionary) -> void:
	if room != null:
		room.queue_free()
	var gm: Node = root.get_node_or_null("/root/GameManager")
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["current_level"] = int(case_data.get("level", 1))
	gm.call("_unlock_parts_for_current_level")
	gm.take_pending_unlock_notice()
	gm.reset_assembly()
	if int(case_data.get("level", 1)) == 10:
		for part_value in gm.parts_data:
			if not part_value is Dictionary:
				continue
			var part: Dictionary = part_value
			var part_id := str(part.get("id", ""))
			if part_id != "" and not gm.progress["unlocked_parts"].has(part_id):
				gm.progress["unlocked_parts"].append(part_id)
		for part_type in gm.current_level().get("required_parts", []):
			gm.install_part(str(part_type), 0)
	gm.take_pending_unlock_notice()
	var packed: PackedScene = load("res://scenes/observatory_room.tscn")
	room = packed.instantiate()
	root.add_child(room)
	room.call("_open_mission_board")
