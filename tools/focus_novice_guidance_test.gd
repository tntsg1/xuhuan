extends SceneTree

const OUTPUT_DIR := "res://artifacts/focus_guidance_acceptance"

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(8, true)
	gm.selected_object_id = gm.current_target_object_id()

	view = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	for index in range(5):
		await process_frame

	var original_focus := float(view.get("focus_value"))
	Input.action_press("move_right")
	view.call("_handle_focus_input", 0.5)
	Input.action_release("move_right")
	_check(is_equal_approx(float(view.get("focus_value")), original_focus), "pre-quiz guide blocks background focus input")
	view.call("_dismiss_pre_quiz_guide")
	await process_frame

	var guide_panel: Panel = view.get("focus_guide_panel")
	var guide_zone: ColorRect = view.get("focus_guide_zone")
	_check(guide_panel != null and not guide_panel.visible, "focus help stays hidden before the player struggles")
	_check(guide_zone != null and not guide_zone.visible, "clear-zone marker is initially hidden")

	var target := float(view.get("target_focus_value"))
	var tolerance := float(view.get("focus_tolerance"))
	for attempt in range(8):
		var offset := tolerance * 1.55 * (1.0 if attempt % 2 == 0 else -1.0)
		view.call("_set_focus_value", clampf(target + offset, 0.0, 1.0))
	# Finish on the low side so the guidance must point right with E.
	view.call("_set_focus_value", clampf(target - tolerance * 1.55, 0.0, 1.0))
	await process_frame

	var guide_text: Label = view.get("focus_guide_text")
	_check(bool(view.get("focus_guide_active")), "repeated near misses trigger novice focus guidance")
	_check(guide_panel.visible, "focus guidance panel becomes visible")
	_check(guide_zone.visible, "green clear-zone marker becomes visible")
	_check(guide_text.text.contains("Hold E"), "guidance names the correct key and direction")
	_check(guide_text.text.contains("green clear zone"), "guidance explains when to stop")
	await _capture("l8_focus_help_after_near_misses.png")

	view.call("_set_focus_value", target)
	await process_frame
	_check(bool(view.call("is_focus_acceptable")), "target focus value is accepted")
	_check(not bool(view.get("focus_guide_active")), "successful focus clears the struggling state")
	_check(not guide_panel.visible and not guide_zone.visible, "focus help automatically hides after success")

	if failures == 0:
		print("FOCUS NOVICE GUIDANCE TEST PASS")
		quit(0)
	else:
		print("FOCUS NOVICE GUIDANCE TEST FAIL: ", failures)
		quit(1)


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	_check(error == OK, "saved focus guidance screenshot")
	print("CAPTURE ", output_path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
