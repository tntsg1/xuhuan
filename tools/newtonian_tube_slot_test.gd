extends SceneTree

var failures := 0
var scene: Node


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)
	scene = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var order: Array = gm.tube_subassembly_config().get("order", [])
	var mapped: Dictionary = scene.call("_newtonian_slot_positions")
	for index in range(order.size()):
		var subpart := str(order[index])
		var hit := scene.find_child("TubeHit_%s" % subpart, true, false) as Button
		_check(hit != null, "%s has a live central hit target" % subpart)
		if hit == null:
			continue
		var expected: Rect2 = mapped[subpart]
		_check(hit.position.is_equal_approx(expected.position) and hit.size.is_equal_approx(expected.size), "%s hit target uses mapped image coordinates" % subpart)
		scene.call("_select_newtonian_tube_part", subpart)
		await process_frame
		hit = scene.find_child("TubeHit_%s" % subpart, true, false) as Button
		hit.pressed.emit()
		await process_frame
		await process_frame
		var saved: Dictionary = gm.tube_assembly().get("installed_subparts", {})
		_check(bool(saved.get(subpart, false)), "%s installs through the visible slot center" % subpart)
		_check(scene.find_child("TubeTexture_%s" % subpart, true, false) != null, "%s renders its installed PNG in the blueprint" % subpart)

	for first_index in range(order.size()):
		var first_rect: Rect2 = mapped[str(order[first_index])]
		for second_index in range(first_index + 1, order.size()):
			var second_rect: Rect2 = mapped[str(order[second_index])]
			_check(not first_rect.intersects(second_rect), "%s and %s hit areas do not overlap" % [order[first_index], order[second_index]])

	var persisted: Dictionary = gm.tube_assembly().duplicate(true)
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	for subpart_value in order:
		var subpart := str(subpart_value)
		_check(scene.find_child("TubeTexture_%s" % subpart, true, false) != null, "%s installed texture survives scene reload" % subpart)
	_check(gm.tube_assembly().get("installed_subparts", {}) == persisted.get("installed_subparts", {}), "tube installation state survives scene reload")

	if failures == 0:
		print("NEWTONIAN TUBE SLOT TEST PASS")
		quit(0)
	else:
		print("NEWTONIAN TUBE SLOT TEST FAIL")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
