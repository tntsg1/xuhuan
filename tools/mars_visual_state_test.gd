extends SceneTree

# Round 30: Mars stays red and identifiable in every observing condition; the
# _dim texture is no longer a near-black disc and a runtime brightness floor
# stops seeing/cloud/low-light from crushing solid targets to black.

var failures := 0


func _initialize() -> void:
	await process_frame

	# --- 1. mars_dim texture keeps red dominance + a real brightness floor ---
	var dim := (load("res://assets/telescope_view/mars_dim.png") as Texture2D).get_image()
	var w := dim.get_width()
	var h := dim.get_height()
	var rsum := 0.0
	var gsum := 0.0
	var bsum := 0.0
	var lit := 0
	var maxch := 0.0
	for y in range(0, h, 3):
		for x in range(0, w, 3):
			var c := dim.get_pixel(x, y)
			if c.a > 0.15 and c.v > 0.06:
				rsum += c.r
				gsum += c.g
				bsum += c.b
				maxch = maxf(maxch, maxf(c.r, maxf(c.g, c.b)))
				lit += 1
	var mr := rsum / maxf(lit, 1)
	var mg := gsum / maxf(lit, 1)
	var mb := bsum / maxf(lit, 1)
	_check(mr > mg and mg >= mb, "1. mars_dim stays red-dominant (R>G>=B: %.2f/%.2f/%.2f)" % [mr, mg, mb])
	_check(mr > 0.22, "1. mars_dim red channel is not crushed to black (meanR=%.2f)" % mr)
	_check(maxch > 0.40, "1. mars_dim has bright surface highlights (maxCh=%.2f)" % maxch)

	# --- 2. Runtime brightness floor keeps a solid target visible ---
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(11, true)   # Mars, poor seeing
	gm.current_level()["environment"] = {"seeing": "poor", "sky_brightness": "city", "cloud_cover": 0.7}
	gm.selected_object_id = "mars"
	var tv: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(tv)
	for _i in range(8):
		await process_frame
	var quiz = tv.get("quiz_brief_overlay")
	if quiz != null:
		quiz.queue_free()
		tv.set("quiz_brief_overlay", null)
		tv.set("quiz_brief_dismissed", true)
	for _i in range(40):
		await process_frame
	_check(float(tv.get("base_alpha")) >= 0.5, "2. base_alpha floored for a solid target under poor+city+cloud (%.2f)" % float(tv.get("base_alpha")))
	var floor: float = float(tv.call("_target_alpha_floor"))
	_check(absf(floor - 0.55) < 0.01, "2. solid-target alpha floor is 0.55")
	# cloud multiplier floored for solid targets
	tv.set("cond_cloud_atten", 1.0)
	_check(float(tv.call("_cloud_alpha_multiplier")) >= 0.45, "2. cloud multiplier floored (>=0.45) for a solid target")
	# The blur cross-fade splits brightness between the sharp sprite and the
	# blur overlay, so identifiability is their COMBINED alpha, not one alone.
	var main_sprite = tv.get("main_sprite")
	var blur_overlay = tv.get("blur_overlay")
	var combined := 0.0
	if main_sprite != null:
		combined += float(main_sprite.modulate.a)
	if blur_overlay != null:
		combined += float(blur_overlay.modulate.a)
	_check(combined > 0.20, "2. Mars stays visible (combined sprite alpha=%.2f, not a black disc)" % combined)
	tv.queue_free()
	await process_frame

	# --- 3. Diffuse targets are NOT floored (faint-object mechanic intact) ---
	gm.new_game()
	gm.debug_jump_to_level(7, true)    # orion nebula (deep sky)
	gm.selected_object_id = "orion_nebula"
	var tv2: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(tv2)
	for _i in range(8):
		await process_frame
	_check(float(tv2.call("_target_alpha_floor")) < 0.2, "3. diffuse target keeps a LOW floor (%.2f) so it can still fade" % float(tv2.call("_target_alpha_floor")))
	tv2.queue_free()
	await process_frame

	if failures == 0:
		print("MARS VISUAL STATE TEST PASS")
		quit(0)
	else:
		print("MARS VISUAL STATE TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
