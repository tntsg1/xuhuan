extends SceneTree

# Screenshots for the concept-diagram replacement and the mobile parts list.
# Run WITHOUT --headless at 1024x768.

const OUT := "res://artifacts/r31_verification"

var view: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var tf: Node = root.get_node_or_null("/root/TeachingFlowManager")
	var ti: Node = root.get_node_or_null("/root/TouchInput")
	gm.new_game()

	# --- Concept Brief, both languages ---
	for language in ["en", "zh"]:
		gm.language_mode = language
		gm.progress["language_mode"] = language
		tf.active_card_mode = "brief"
		tf.active_card_id = "naked_eye_limits"
		await _swap(load("res://scenes/learning_card.tscn"))
		await _shot("concept_brief_%s.png" % language)

	# --- Mission Complete (layout preserved) ---
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = 2
	var level: Dictionary = gm.current_level()
	gm.last_learning_card = tf.call(
		"make_mission_complete_payload",
		level,
		gm.get_object("moon"),
		{"quality": "Good", "success": true, "observation_mode": "naked_eye",
			"effective_clarity": 78.0, "ratios": {"light": 1.04, "clarity": 1.04, "stability": 1.04}},
		{"light_score": 78.0, "clarity_score": 78.0, "stability_score": 78.0, "magnification": 1.0}
	)
	tf.active_card_mode = "complete"
	await _swap(load("res://scenes/learning_card.tscn"))
	await _shot("mission_complete.png")

	# --- Parts Cabinet in mobile mode ---
	gm.new_game()
	gm.debug_jump_to_level(46, true)
	ti.set_mobile_mode(true)
	await _swap(load("res://scenes/parts_cabinet.tscn"))
	view.set("selected_family", "all")
	view.call("_build")
	for _i in range(6):
		await process_frame
	await _shot("cabinet_mobile_top.png")

	# Finger swipe up: the list scrolls down and a card stays tappable.
	var scroll: ScrollContainer = view.get("parts_scroll")
	var start := Vector2(300, 560)
	await _swipe(start, -300.0)
	print("scroll after swipe = ", scroll.scroll_vertical, " / max ", view.call("max_scroll_offset"))
	await _shot("cabinet_mobile_scrolled.png")

	# Short tap selects a card (selection outline, no equip).
	await _tap(Vector2(300, 400))
	print("selected = ", view.get("selected_part_id"))
	await _shot("cabinet_mobile_tap_selected.png")

	ti.set_mobile_mode(false)
	quit(0)


func _swap(packed: PackedScene) -> void:
	if view != null:
		view.queue_free()
		await process_frame
	view = packed.instantiate()
	root.add_child(view)
	for _i in range(8):
		await process_frame


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var err := image.save_png(OUT + "/" + file_name)
	print("CAPTURE %s -> %s" % [file_name, "OK" if err == OK else str(err)])


func _swipe(from: Vector2, delta_y: float) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = from
	root.push_input(press)
	await process_frame
	for i in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = from + Vector2(0, delta_y * float(i) / 8.0)
		drag.relative = Vector2(0, delta_y / 8.0)
		root.push_input(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = from + Vector2(0, delta_y)
	root.push_input(release)
	await process_frame


func _tap(at: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = at
	root.push_input(press)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = at
	root.push_input(release)
	await process_frame
