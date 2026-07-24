extends SceneTree

# Cassegrain blueprint readability + single-transform alignment (audit items 4-7).
#   4. Central blueprint enlarged -> higher render scale so baked labels stay legible.
#   5. Image, slots, installed sprites and completion frames all derive from ONE
#      transform: every installed texture rect must equal its slot's transformed rect.
#   6. No slot rect overlaps another, and every slot sits fully inside the displayed
#      blueprint image (so a slot never lands on top of a neighbour's baked label).
#   7. Empty / partial / complete states each render and are captured.

const OUTPUT_DIR := "res://artifacts/cassegrain_blueprint"

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.debug_jump_to_level(46, false)   # first Cassegrain level

	await _verify_main(gm)
	await _verify_tube(gm)

	print("CASSEGRAIN BLUEPRINT ALIGNMENT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _verify_main(gm: Node) -> void:
	# --- empty ---
	_clear_assembly(gm)
	var main: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(main)
	for _i in range(8):
		await process_frame

	var layer: Control = main.get("template_blueprint_layer")
	var cfg: Dictionary = main.call("_main_blueprint_config")
	var layout: Dictionary = main.call("_calculate_blueprint_layout", cfg["size"], Rect2(Vector2.ZERO, cfg["size"]), Rect2(Vector2.ZERO, layer.size))
	var scale := float(layout["scale"])
	_check(scale >= 0.58, "4. main blueprint renders at a legible scale (%.3f >= 0.58)" % scale)

	var geo: Dictionary = main.call("debug_newtonian_main_slot_geometry")
	_check(geo.size() == 4, "main bench exposes 4 slot geometries")
	_assert_within_and_disjoint(geo, layout["display_rect"], "main")
	await _capture("cas_main_empty.png")

	# --- partial: tripod + mount installed ---
	_set_installed(gm, ["tripod", "mount"])
	main.call("_build")
	for _i in range(6):
		await process_frame
	geo = main.call("debug_newtonian_main_slot_geometry")
	_assert_texture_matches_slot(geo, ["tripod", "mount"], "main")
	await _capture("cas_main_partial.png")

	# --- complete: all four external parts ---
	_set_installed(gm, ["tripod", "mount", "optical_tube_assembly", "finder_scope"])
	main.call("_build")
	for _i in range(6):
		await process_frame
	geo = main.call("debug_newtonian_main_slot_geometry")
	_assert_texture_matches_slot(geo, ["tripod", "mount", "optical_tube_assembly", "finder_scope"], "main")
	await _capture("cas_main_complete.png")

	main.queue_free()
	_clear_assembly(gm)
	await process_frame


func _verify_tube(gm: Node) -> void:
	var order: Array = gm.tube_subassembly_config().get("order", [])
	var tube: Node = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(tube)
	for _i in range(8):
		await process_frame

	var layer: Control = tube.get("blueprint")
	var tcfg: Dictionary = tube.call("_tube_blueprint_config")
	var layout: Dictionary = tube.call("_calculate_blueprint_layout", tcfg["size"], Rect2(Vector2.ZERO, tcfg["size"]), Rect2(Vector2.ZERO, layer.size))
	var scale := float(layout["scale"])
	_check(scale >= 0.48, "4. tube blueprint renders at a legible scale (%.3f >= 0.48)" % scale)

	var geo: Dictionary = tube.call("debug_newtonian_tube_slot_geometry")
	_check(geo.size() == 8, "tube bench exposes 8 slot geometries")
	_assert_within_and_disjoint(geo, layout["display_rect"], "tube")
	await _capture("cas_tube_empty.png")

	# --- partial: first three subparts ---
	var partial: Array = [str(order[0]), str(order[1]), str(order[2])]
	tube.set("installed", _installed_dict(partial))
	tube.call("_build")
	for _i in range(6):
		await process_frame
	geo = tube.call("debug_newtonian_tube_slot_geometry")
	_assert_texture_matches_slot(geo, partial, "tube")
	await _capture("cas_tube_partial.png")

	# --- complete: all eight ---
	var all_subs: Array = []
	for s in order:
		all_subs.append(str(s))
	tube.set("installed", _installed_dict(all_subs))
	tube.call("_build")
	for _i in range(6):
		await process_frame
	geo = tube.call("debug_newtonian_tube_slot_geometry")
	_assert_texture_matches_slot(geo, all_subs, "tube")
	await _capture("cas_tube_complete.png")

	tube.queue_free()
	await process_frame


# Item 6: every slot inside the displayed image, and no two slots overlap.
func _assert_within_and_disjoint(geo: Dictionary, display_rect: Rect2, bench: String) -> void:
	var padded := display_rect.grow(1.0)
	var rects := {}
	for part_type in geo.keys():
		var r: Rect2 = geo[part_type]["blueprint_local_rect"]
		_check(padded.encloses(r), "6. %s slot '%s' sits inside the blueprint image" % [bench, part_type])
		rects[part_type] = r
	var keys: Array = rects.keys()
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			var overlap := a.intersection(b)
			_check(overlap.size.x <= 0.5 or overlap.size.y <= 0.5,
				"6. %s slots '%s' and '%s' do not overlap" % [bench, keys[i], keys[j]])


# Item 5: the installed sprite occupies the SAME transformed rect as the slot.
func _assert_texture_matches_slot(geo: Dictionary, installed_parts: Array, bench: String) -> void:
	for part_type in installed_parts:
		if not geo.has(part_type):
			_check(false, "5. %s geometry has slot '%s'" % [bench, part_type])
			continue
		var slot_rect: Rect2 = geo[part_type]["blueprint_local_rect"]
		var tex_rect: Rect2 = geo[part_type]["installed_texture_rect"]
		_check(tex_rect.size.x > 0.0, "7. %s '%s' shows an installed sprite" % [bench, part_type])
		var matches := slot_rect.position.distance_to(tex_rect.position) <= 1.0 \
			and absf(slot_rect.size.x - tex_rect.size.x) <= 1.0 \
			and absf(slot_rect.size.y - tex_rect.size.y) <= 1.0
		_check(matches, "5. %s '%s' sprite shares the slot's transform (%s vs %s)" % [bench, part_type, str(slot_rect), str(tex_rect)])


func _clear_assembly(gm: Node) -> void:
	gm.progress["assembly_state"] = {}


func _set_installed(gm: Node, parts: Array) -> void:
	var state := {}
	for p in parts:
		state[str(p)] = {"installed": true}
	gm.progress["assembly_state"] = state


func _installed_dict(parts: Array) -> Dictionary:
	var d := {}
	for p in parts:
		d[str(p)] = true
	return d


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR + "/" + file_name)
	_check(error == OK, "7. captured %s" % file_name)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
