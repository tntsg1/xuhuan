extends SceneTree

const OUTPUT_DIR := "res://artifacts/identify_quiz_acceptance"

var failures := 0
var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(4, true)
	gm.selected_object_id = gm.current_target_object_id()

	var telescope: Control = load("res://scenes/telescope_view.tscn").instantiate()
	await _replace_scene(telescope)
	var guide: Control = telescope.get("quiz_brief_overlay")
	var choices: VBoxContainer = telescope.get("choices_box")
	var ids: Array[String] = telescope.get("identify_choice_ids")
	_check(guide != null and guide.visible, "pre-quiz object guide appears before identification")
	_check(choices != null and not choices.visible, "answer buttons remain hidden during the guide")
	_check(ids.size() == 4, "quiz builds four unique candidates")
	_check(_guide_covers_candidates(guide, ids), "guide teaches every candidate shown in the quiz")
	await _capture("object_field_guide.png")

	var correct_id := str(telescope.get("selected_object").get("id", ""))
	var observed_positions: Dictionary = {}
	for attempt in range(12):
		var shuffled: Array[String] = telescope.call("_build_identify_choice_ids")
		var correct_index := shuffled.find(correct_id)
		_check(correct_index >= 0, "shuffle %d retains the correct answer" % (attempt + 1))
		observed_positions[correct_index] = true
	_check(observed_positions.size() > 1, "correct answer is not fixed at A")

	telescope.call("_dismiss_pre_quiz_guide")
	await process_frame
	_check(choices.visible, "A-D choices appear only after the guide is dismissed")
	var button_letters: Array[String] = []
	for child in choices.get_children():
		if child is Button:
			button_letters.append((child as Button).text.left(2))
	_check(button_letters == ["A.", "B.", "C.", "D."], "answer buttons are labeled A-D")
	await _capture("randomized_identification_quiz.png")

	gm.last_sky_aim = {"valid": false}
	var sky: Control = load("res://scenes/sky_observation.tscn").instantiate()
	await _replace_scene(sky)
	var sky_data: Dictionary = sky.get("sky_data")
	var target_id: String = gm.current_target_object_id()
	var item: Dictionary = sky_data.get(target_id, {})
	sky.set("telescope_azimuth", float(item.get("azimuth", 180.0)))
	sky.set("telescope_altitude", float(item.get("altitude", 45.0)))
	sky.call("_set_view_mode", "telescope")
	await process_frame
	var reticle: Control = sky.get("scope_reticle_layer")
	var sky_lift: ColorRect = sky.get("sky_lift_layer")
	var icons: Dictionary = sky.get("object_icons")
	var target_icon: TextureRect = icons.get(target_id)
	_check(reticle != null and reticle.visible, "Scope mode enables the dynamic reticle overlay")
	_check(target_icon != null and reticle.z_index > target_icon.z_index, "Scope reticle renders above the centered planet")
	_check(sky_lift != null and reticle.z_index > sky_lift.z_index, "aiming reticle renders above city-sky brightness layers")
	await _capture("scope_reticle_above_jupiter.png")

	sky.call("_set_view_mode", "naked_eye")
	await process_frame
	_check(reticle.visible, "Eye mode keeps the aiming reticle visible")
	await _capture("eye_mode_aiming_reticle_restored.png")
	sky.call("_set_view_mode", "finder")
	await process_frame
	_check(reticle.visible, "Finder mode keeps the aiming reticle visible")

	if failures == 0:
		print("IDENTIFY QUIZ AND SCOPE LAYER TEST PASS")
		quit(0)
	else:
		print("IDENTIFY QUIZ AND SCOPE LAYER TEST FAIL: ", failures)
		quit(1)


func _guide_covers_candidates(guide: Control, ids: Array[String]) -> bool:
	if guide == null:
		return false
	var all_text := _collect_label_text(guide)
	var gm := root.get_node("/root/GameManager")
	for id in ids:
		var obj: Dictionary = gm.get_object(id)
		if not all_text.contains(str(obj.get("name_en", ""))):
			return false
		if not all_text.contains(str(obj.get("short_hint_en", ""))):
			return false
	return true


func _collect_label_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	for child in node.get_children():
		result += _collect_label_text(child)
	return result


func _replace_scene(scene: Node) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = scene
	root.add_child(scene)
	current_scene = scene
	for index in range(5):
		await process_frame


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	_check(error == OK, "saved screenshot " + file_name)
	print("CAPTURE ", output_path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
