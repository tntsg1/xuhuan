extends SceneTree

const REPRESENTATIVE_LEVELS := [4, 20, 22, 33, 42]

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("TELESCOPE MODAL LAYER REGRESSION FAIL: GameManager missing")
		quit(1)
		return

	for level_number in REPRESENTATIVE_LEVELS:
		gm.debug_jump_to_level(level_number, true)
		gm.selected_object_id = gm.current_target_object_id()
		var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
		root.add_child(view)
		await process_frame
		await process_frame
		var guide := view.get("quiz_brief_overlay") as Control
		_check(guide != null and guide.z_index >= 1000, "L%d object guide owns the modal layer" % level_number)
		view.call("_show_focus_tutorial")
		await process_frame
		_check(view.find_children("TutorialHighlight_*", "Control", true, false).is_empty(), "L%d tutorial HUD cannot pierce the object guide" % level_number)
		var focus_guide := view.get("focus_guide_panel") as Control
		_check(focus_guide == null or guide == null or focus_guide.z_index < guide.z_index, "L%d focus assistance stays below the modal" % level_number)
		view.queue_free()
		await process_frame

	print("TELESCOPE MODAL LAYER REGRESSION %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
