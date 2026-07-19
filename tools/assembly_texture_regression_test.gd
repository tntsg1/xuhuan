extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var screen: Control = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var cases: Array[Dictionary] = [
		{"id": "starter_tube", "expected": "res://assets/telescope_parts/starter_tube.png"},
		{"id": "objective_100mm", "expected": "res://assets/telescope_parts/objective_100mm.png"},
		{
			"id": "dobsonian_rocker_mount",
			"icon_path": "res://assets/telescope_parts/dobsonian/dobsonian_rocker_mount.png",
			"expected": "res://assets/telescope_parts/dobsonian/dobsonian_rocker_mount.png"
		},
		{
			"id": "dobsonian_30mm_eyepiece",
			"icon_path": "res://assets/telescope_parts/dobsonian/dobsonian_30mm_eyepiece.png",
			"expected": "res://assets/telescope_parts/dobsonian/dobsonian_30mm_eyepiece.png"
		}
	]

	for part in cases:
		var resolved := str(screen.call("_part_texture_path", part))
		_check(resolved == str(part.get("expected", "")), "%s resolves its formal texture" % part.get("id", ""))
		var texture := load(resolved) as Texture2D if resolved != "" else null
		_check(texture != null, "%s loads as Texture2D" % part.get("id", ""))

	var parent := Control.new()
	var slot_position := Vector2(17, 29)
	var slot_size := Vector2(96, 52)
	var rendered := bool(screen.call("_draw_part_texture", parent, cases[2], slot_position, slot_size))
	_check(rendered and parent.get_child_count() == 1, "icon_path-only part renders in the central slot")
	if parent.get_child_count() == 1:
		var icon := parent.get_child(0) as TextureRect
		_check(icon != null and icon.position == slot_position and icon.size == slot_size, "installed texture rect matches the slot rect")
		_check(icon != null and icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "installed texture ignores native size")
		_check(icon != null and icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "installed texture keeps aspect and stays centered")
		_check(icon != null and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "installed texture uses nearest-neighbor filtering")

	parent.free()
	screen.queue_free()
	if failures == 0:
		print("ASSEMBLY TEXTURE REGRESSION TEST PASS")
		quit(0)
	else:
		print("ASSEMBLY TEXTURE REGRESSION TEST FAIL")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
