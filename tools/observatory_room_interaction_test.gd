extends SceneTree

# Observatory room interaction QA.
# Run: godot --headless --path <project> --script res://tools/observatory_room_interaction_test.gd

const POINTS := {
	"cabinet": Vector2(300, 350),
	"assembly": Vector2(756, 410),
	"door": Vector2(517, 304),
	"telescope": Vector2(517, 570),
	"mission": Vector2(610, 250),
	"journal": Vector2(350, 628),
	"computer": Vector2(693, 632)
}

var failures := 0
var gm: Node
var view: Node


func _initialize() -> void:
	await process_frame
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager missing")
		quit(1)
		return
	gm.new_game()
	_load_room()
	_check_remote_click_requires_nearby()
	_check_focus_points()
	await _check_not_ready_pad()
	await _check_ready_pad()
	_check_return_spawns()
	if failures == 0:
		print("OBSERVATORY INTERACTION TEST PASS")
		quit(0)
	else:
		print("OBSERVATORY INTERACTION TEST FAIL (%d failures)" % failures)
		quit(1)


func _load_room() -> void:
	if view != null:
		view.queue_free()
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	view = scene.instantiate()
	root.add_child(view)


func _set_player_at(id: String) -> void:
	view.call("_set_player_position", POINTS[id])
	view.call("_update_nearby")


func _nearby_id() -> String:
	return str(view.get("nearby_id"))


func _check_focus_points() -> void:
	for id in POINTS.keys():
		_set_player_at(id)
		_check(_nearby_id() == id, "E focus near " + id)


func _check_remote_click_requires_nearby() -> void:
	view.call("_set_player_position", Vector2(517, 630))
	view.call("_update_nearby")
	view.call("_click_interactable", "cabinet")
	_check(_scene_is("observatory_room"), "remote click cabinet does not navigate")


func _check_not_ready_pad() -> void:
	gm.new_game()
	gm.progress["current_level"] = 3
	gm.progress["seen_story_events"] = ["intro", "level_1_before", "level_3_before_assembly"]
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro", "refractor_intro"]
	gm.progress["seen_concept_briefs"] = ["eye_imaging", "refractor_light_path"]
	gm.reset_assembly()
	_load_room()
	_set_player_at("telescope")
	view.call("_interact_with_nearby")
	await process_frame
	_check(_scene_is("observatory_room"), "not-ready pad stays in observatory")


func _check_ready_pad() -> void:
	gm.new_game()
	gm.progress["seen_story_events"] = ["intro", "level_1_before"]
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro"]
	gm.progress["seen_concept_briefs"] = ["eye_imaging"]
	gm.progress["current_level"] = 3
	gm.progress["seen_story_events"].append("level_3_before_assembly")
	# Mark the pre-observation story AND Maya's one-time below-horizon lesson as
	# seen, so this case exercises the pad -> observation routing itself rather
	# than stopping on a story panel.
	gm.progress["seen_story_events"].append("level_3_before")
	gm.progress["seen_story_events"].append("first_below_horizon")
	gm.progress["seen_teaching_steps"].append("refractor_intro")
	gm.progress["seen_concept_briefs"].append("refractor_light_path")
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece"]:
		gm.install_part(part_type, 0)
	gm.save()
	_load_room()
	_set_player_at("telescope")
	view.call("_interact_with_nearby")
	await process_frame
	# The base always enters Sky Observation. Only Sky may offer/open the map.
	_check(_scene_is("sky_observation"), "ready pad enters Sky Observation, never the map directly")


func _check_return_spawns() -> void:
	var expected := {
		"cabinet": Vector2(300, 350),
		"assembly": Vector2(756, 410),
		"journal": Vector2(350, 628),
		"door": Vector2(517, 320),
		"telescope": Vector2(517, 570)
	}
	for id in expected.keys():
		gm.set_observatory_spawn(id)
		_load_room()
		var actual: Vector2 = view.get("player_pos")
		_check(actual.distance_to(expected[id]) < 1.0, "return spawn near " + id)


func _scene_is(name_part: String) -> bool:
	var scene: Node = current_scene
	if scene == null:
		scene = root.get_child(root.get_child_count() - 1)
	return scene != null and str(scene.scene_file_path).contains(name_part)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
