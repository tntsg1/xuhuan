extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(5, false)
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _frame in range(4):
		await process_frame
	sky.call("_open_detail_panel")
	await process_frame
	var panel := sky.get_node_or_null("ObjectDetailsPanel") as Control
	_check(panel != null, "Details uses the existing compact right-panel region")
	if panel != null:
		_check(panel.position.x >= 752.0 and panel.get_rect().end.x <= 1008.0, "Details stays inside the right inspector")
		_check(panel.position.y >= 280.0 and panel.get_rect().end.y <= 480.0, "Details does not cover fixed Observe/Back controls")
		var scroll := panel.get_node_or_null("Panel/DetailsScroll") as ScrollContainer
		if scroll == null:
			for node in panel.find_children("DetailsScroll", "ScrollContainer", true, false):
				scroll = node as ScrollContainer
		_check(scroll != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Details scrolls vertically without horizontal overflow")
		if scroll != null and scroll.get_child_count() > 0:
			_check((scroll.get_child(0) as Control).custom_minimum_size.x <= scroll.size.x, "Scrollable body fits its viewport")
	sky.queue_free()
	await process_frame
	print("DETAILS SCROLL LAYOUT TEST PASS" if failures == 0 else "DETAILS SCROLL LAYOUT TEST FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)

