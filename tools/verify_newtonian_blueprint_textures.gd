extends SceneTree

var failures := 0
var active_scene: Node


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)

	var complete := {}
	for subpart_value in gm.tube_subassembly_config().get("order", []):
		complete[str(subpart_value)] = true
	gm.save_tube_assembly(complete, 100.0, 100.0, false)
	for part_type in ["tripod", "mount", "optical_tube_assembly", "finder_scope"]:
		gm.install_part(part_type, 0)

	await _load_scene("res://scenes/advanced_assembly.tscn")
	print("MAIN ICON LOAD CHECK")
	for part_type in ["tripod", "mount", "optical_tube_assembly", "finder_scope"]:
		var part: Dictionary = active_scene.call("_main_template_part", part_type)
		_check_icon(str(part.get("id", part_type)), str(part.get("icon_path", "")))
		_check(active_scene.find_child("MainTexture_%s" % part_type, true, false) is TextureRect, "%s central main slot has TextureRect" % part_type)
	_print_geometry("MAIN SLOT GEOMETRY", active_scene.call("debug_newtonian_main_slot_geometry"))

	await _load_scene("res://scenes/optical_tube_assembly.tscn")
	print("TUBE ICON LOAD CHECK")
	for subpart_value in gm.tube_subassembly_config().get("order", []):
		var subpart := str(subpart_value)
		var part: Dictionary = active_scene.call("_part_for_subpart", subpart)
		_check_icon(str(part.get("id", subpart)), str(part.get("icon_path", "")))
		_check(active_scene.find_child("TubeTexture_%s" % subpart, true, false) is TextureRect, "%s central tube slot has TextureRect" % subpart)
	_print_geometry("TUBE SLOT GEOMETRY", active_scene.call("debug_newtonian_tube_slot_geometry"))

	print("NEWTONIAN BLUEPRINT TEXTURE VERIFY %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _load_scene(path: String) -> void:
	if active_scene != null:
		active_scene.queue_free()
		await process_frame
	active_scene = load(path).instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame


func _check_icon(part_id: String, icon_path: String) -> void:
	var exists := icon_path != "" and ResourceLoader.exists(icon_path)
	var texture := load(icon_path) as Texture2D if exists else null
	print("part_id=%s | icon_path=%s | exists=%s | Texture2D=%s" % [part_id, icon_path, exists, texture != null])
	_check(exists and texture != null, "%s icon is a loadable Texture2D" % part_id)


func _print_geometry(title: String, geometry: Dictionary) -> void:
	print(title)
	for part_id_value in geometry.keys():
		var part_id := str(part_id_value)
		var row: Dictionary = geometry[part_id]
		var local_rect: Rect2 = row["blueprint_local_rect"]
		var texture_rect: Rect2 = row["installed_texture_rect"]
		print("part_id=%s | source rect=%s | blueprint local rect=%s | screen rect=%s | installed texture rect=%s" % [part_id, row["source_rect"], local_rect, row["screen_rect"], texture_rect])
		_check(texture_rect.position.is_equal_approx(local_rect.position) and texture_rect.size.is_equal_approx(local_rect.size), "%s installed texture rect matches slot rect" % part_id)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + label)
