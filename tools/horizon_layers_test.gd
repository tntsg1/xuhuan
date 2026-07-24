extends SceneTree

# Round 27: horizon panorama layers from the user's transparent art.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")

	# --- 1. Only genuinely transparent assets shipped ---
	var names := ["far_mountain", "far_snow", "far_desert", "far_city", "far_forest",
		"mid_observatory", "mid_city", "mid_desert", "mid_forest",
		"near_platform", "near_platform_b", "near_forest",
		"cloud_band", "cloud_wisp", "cloud_layer"]
	var missing := 0
	var opaque := 0
	for n in names:
		var p := "res://assets/horizon/processed/%s.png" % n
		if not ResourceLoader.exists(p):
			missing += 1
			continue
		var tex: Texture2D = load(p)
		var img := tex.get_image()
		if not img.detect_alpha():
			opaque += 1
	_check(missing == 0, "1. all %d horizon assets present (%d missing)" % [names.size(), missing])
	_check(opaque == 0, "1. every horizon asset has real alpha (%d opaque)" % opaque)
	_check(FileAccess.file_exists("res://assets/horizon/processed/processing_manifest.json"),
		"1. non-destructive processing/source mapping manifest present")
	var process_file := FileAccess.open("res://assets/horizon/processed/processing_manifest.json", FileAccess.READ)
	var process_manifest: Dictionary = JSON.parse_string(process_file.get_as_text())
	var contaminated_assets: Array = []
	var bad_top_edges: Array = []
	var bad_seams: Array = []
	for record_value in process_manifest.get("assets", []):
		var record: Dictionary = record_value
		var after_stats: Dictionary = record.get("after", {})
		if int(after_stats.get("bright_semi_pixels", 999999)) > 100:
			contaminated_assets.append(str(record.get("output", "")))
		if int(after_stats.get("top_edge_visible_pixels", 999999)) > 8:
			bad_top_edges.append(str(record.get("output", "")))
		if float(after_stats.get("left_right_alpha_mae", 999999.0)) > 0.01:
			bad_seams.append(str(record.get("output", "")))
	_check(contaminated_assets.is_empty(),
		"1. processed translucent edges have no broad white/gray matte (%s)" % str(contaminated_assets))
	_check(bad_top_edges.is_empty(),
		"1. transparent skyline has no rectangular top edge (%s)" % str(bad_top_edges))
	_check(bad_seams.is_empty(),
		"1. left/right alpha boundaries are loop-safe (%s)" % str(bad_seams))

	# --- 2. Manifest maps every world site to a horizon set ---
	var f := FileAccess.open("res://data/horizon_sets.json", FileAccess.READ)
	_check(f != null, "2. horizon manifest present")
	var manifest: Dictionary = JSON.parse_string(f.get_as_text())
	var site_sets: Dictionary = manifest.get("site_sets", {})
	var sets: Dictionary = manifest.get("sets", {})
	var unmapped: Array = []
	for site_value in gm.location_sites():
		var id := str((site_value as Dictionary).get("id", ""))
		if not site_sets.has(id):
			unmapped.append(id)
	_check(unmapped.is_empty(), "2. every observing site maps to a set (unmapped: %s)" % str(unmapped))
	_check(site_sets.has(str(gm.home_location().get("id", ""))), "2. home site mapped too")
	for set_name in sets.keys():
		var s: Dictionary = sets[set_name]
		_check(s.has("far") and s.has("mid") and s.has("near"), "2. set '%s' has far/mid/near" % set_name)

	# --- 3. Sky scene builds the layers below the horizon ---
	gm.new_game()
	gm.debug_jump_to_level(7, true)
	if gm.target_requires_relocation():
		var rec: Dictionary = gm.recommend_observation_location()
		if not rec.is_empty():
			gm.set_observing_location(rec["site"])
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _i in range(10):
		await process_frame
	var layers: Array = sky.get("horizon_layers")
	_check(layers.size() == 3, "3. three available art layers built (far/mid/near)")
	_check((sky.get("horizon_cloud_sprites") as Array).size() >= 1, "3. horizon cloud layer built")
	# Every strip needs enough repeated copies to cover the viewport even when
	# the scaled source texture is narrower than the sky window.
	var enough_tiles := true
	for l in layers:
		if (l as Dictionary).get("sprites", []).size() < 4:
			enough_tiles = false
	_check(enough_tiles, "3. every layer uses enough repeated tiles for gap-free wrap")

	# --- 4. Layers sit BELOW celestial objects and below the UI ---
	var max_layer_z := -999
	for l in layers:
		for s in (l as Dictionary)["sprites"]:
			max_layer_z = maxi(max_layer_z, (s as CanvasItem).z_index)
	_check(max_layer_z < 20, "4. horizon z (%d) is below Z_OBJECTS (20) - objects draw on top" % max_layer_z)
	var star_pool: Array = sky.get("star_pool")
	_check(not star_pool.is_empty() and (star_pool[0] as CanvasItem).z_index > max_layer_z,
		"4. stars draw above every environmental layer")
	var cloud_layer: CanvasItem = sky.get("cloud_layer")
	_check(cloud_layer.z_index < (star_pool[0] as CanvasItem).z_index,
		"4. cloud artwork stays below stars/targets")
	var cleanup_material_ok := true
	for l in layers:
		for s in (l as Dictionary)["sprites"]:
			if not (s as CanvasItem).material is ShaderMaterial:
				cleanup_material_ok = false
	_check(cleanup_material_ok, "4. every horizon sprite uses the night/edge cleanup shader")

	# --- 5. Azimuth rotation scrolls the panorama ---
	sky.set_process(false)   # freeze camera easing so the test controls the aim
	sky.set("telescope_altitude", 6.0)
	sky.set("display_altitude", 6.0)
	sky.set("telescope_azimuth", 0.0)
	sky.set("display_azimuth", 0.0)
	sky.call("_update_ground")
	var near_layer: Dictionary = layers[layers.size() - 1]
	var x0: float = (near_layer["sprites"][0] as Control).position.x
	sky.set("telescope_azimuth", 90.0)
	sky.set("display_azimuth", 90.0)
	sky.call("_update_ground")
	var x1: float = (near_layer["sprites"][0] as Control).position.x
	_check(absf(x1 - x0) > 1.0, "5. turning in azimuth scrolls the panorama")

	# --- 6. Different layers move at different speeds (parallax) ---
	var far_layer: Dictionary = layers[0]
	var mid_layer: Dictionary = layers[1]
	sky.set("display_azimuth", 0.0)
	sky.call("_update_ground")
	var fx0: float = (far_layer["sprites"][0] as Control).position.x
	var mx0: float = (mid_layer["sprites"][0] as Control).position.x
	var nx0: float = (near_layer["sprites"][0] as Control).position.x
	sky.set("display_azimuth", 40.0)
	sky.call("_update_ground")
	var fd: float = absf((far_layer["sprites"][0] as Control).position.x - fx0)
	var md: float = absf((mid_layer["sprites"][0] as Control).position.x - mx0)
	var nd: float = absf((near_layer["sprites"][0] as Control).position.x - nx0)
	_check(absf(fd - nd) > 0.5, "6. far and near layers move at DIFFERENT rates (parallax %.1f vs %.1f)" % [fd, nd])
	_check(fd < md and md < nd, "6. horizontal travel follows far < mid < near (%.1f < %.1f < %.1f)" % [fd, md, nd])

	# Crossing north must advance by two degrees, not jump backward by 358.
	sky.set("display_azimuth", 359.0)
	sky.call("_update_ground")
	var unwrap_359: float = float(sky.get("horizon_unwrapped_azimuth"))
	sky.set("display_azimuth", 1.0)
	sky.call("_update_ground")
	var unwrap_001: float = float(sky.get("horizon_unwrapped_azimuth"))
	_check(absf((unwrap_001 - unwrap_359) - 2.0) < 0.01, "6. 359 to 0/1 degrees is continuous")
	# A full rotation must return to the same visual phase instead of allowing
	# the depth factors to accumulate permanent inter-layer drift.
	sky.set("display_azimuth", 0.0)
	sky.call("_update_ground")
	var loop_x0: float = (near_layer["sprites"][0] as Control).position.x
	sky.set("display_azimuth", 360.0)
	sky.call("_update_ground")
	var loop_x1: float = (near_layer["sprites"][0] as Control).position.x
	_check(absf(loop_x1 - loop_x0) < 0.01, "6. 360-degree turn returns to the same texture phase")

	# --- 7. Raising the aim lifts the horizon out of frame ---
	sky.set("display_altitude", 6.0)
	sky.call("_update_ground")
	var low_y: float = (near_layer["sprites"][0] as Control).position.y
	sky.set("display_altitude", 60.0)
	sky.call("_update_ground")
	var high_y: float = (near_layer["sprites"][0] as Control).position.y
	_check(high_y > low_y, "7. aiming higher pushes the horizon band down/out of view")
	sky.set("display_altitude", 6.0)
	sky.call("_update_ground")
	var far_low_y: float = (far_layer["sprites"][0] as Control).position.y
	var near_low_y: float = (near_layer["sprites"][0] as Control).position.y
	sky.set("display_altitude", 18.0)
	sky.call("_update_ground")
	var far_pitch_delta := absf((far_layer["sprites"][0] as Control).position.y - far_low_y)
	var near_pitch_delta := absf((near_layer["sprites"][0] as Control).position.y - near_low_y)
	_check(near_pitch_delta > far_pitch_delta, "7. foreground responds more to pitch than distant mountains")

	# --- 8. Optical modes progressively reduce environmental prominence ---
	sky.set("display_altitude", 0.0)
	sky.set("view_mode", "naked_eye")
	sky.call("_update_ground")
	var naked_alpha: float = (near_layer["sprites"][0] as CanvasItem).modulate.a
	sky.set("view_mode", "finder")
	sky.call("_update_ground")
	var finder_alpha: float = (near_layer["sprites"][0] as CanvasItem).modulate.a
	sky.set("view_mode", "telescope")
	sky.call("_update_ground")
	var scope_alpha: float = (near_layer["sprites"][0] as CanvasItem).modulate.a
	_check(naked_alpha > finder_alpha and finder_alpha > scope_alpha,
		"8. Eye > Finder > Telescope environmental visibility")
	_check(scope_alpha <= 0.04, "8. Telescope suppresses nearby platform at high magnification")

	# --- 9. Real sky untouched: horizon art never moves a target ---
	var before: Dictionary = gm.target_visibility()
	sky.call("_update_ground")
	var after: Dictionary = gm.target_visibility()
	_check(absf(float(before.get("altitude", 0.0)) - float(after.get("altitude", 0.0))) < 0.001, "9. horizon layers do not change target altitude")
	sky.queue_free()
	await process_frame

	if failures == 0:
		print("HORIZON LAYERS TEST PASS")
		quit(0)
	else:
		print("HORIZON LAYERS TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
