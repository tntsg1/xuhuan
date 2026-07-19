extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, true)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"

	var bench: Control = load("res://scenes/collimation.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var preview: Control = bench.get("star_preview")
	_check(preview != null, "collimation bench contains a live focused-star preview")
	_check((preview.get("alignment_error") as Vector2).length() > 0.02, "initial mirror error produces an asymmetric star preview")
	bench.set("secondary_x", 0.0)
	bench.set("secondary_y", 0.0)
	bench.set("primary_x", 0.0)
	bench.set("primary_y", 0.0)
	bench.call("_refresh", true)
	_check((preview.get("alignment_error") as Vector2).length() < 0.001, "aligned mirrors produce a symmetric Airy-disc preview")
	bench.queue_free()
	await process_frame

	gm.set_collimation_score(20.0)
	var low_clarity := float(gm.calculate_stats().get("clarity_score", 0.0))
	gm.selected_object_id = "vega"
	var scope: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(scope)
	await process_frame
	await process_frame
	scope.set("focus_error", 0.0)
	scope.set("visual_focus_error", 0.0)
	scope.set("blur_weight", 0.0)
	scope.call("_update_target_visuals")
	var ghost: TextureRect = scope.get("ghost_a")
	print("  poor-collimation ghost alpha: %.3f" % (ghost.modulate.a if ghost != null else -1.0))
	_check(float(scope.call("_collimation_severity")) > 0.95, "poor collimation maps to strong optical aberration")
	_check(ghost != null and ghost.modulate.a > 0.15, "poor collimation leaves visible coma even at exact focus")

	gm.set_collimation_score(100.0)
	var high_clarity := float(gm.calculate_stats().get("clarity_score", 0.0))
	scope.set("observation", scope.call("_evaluate"))
	scope.call("_update_target_visuals")
	_check(float(scope.call("_collimation_severity")) < 0.001, "perfect collimation removes the coma severity")
	_check(ghost.modulate.a < 0.02, "perfect collimation removes residual coma at exact focus")
	_check(high_clarity > low_clarity, "the same collimation value also changes real clarity scoring")

	print("COLLIMATION OPTICS FEEDBACK TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
