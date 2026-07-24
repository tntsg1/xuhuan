extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	var mm := root.get_node_or_null("/root/MissionManager")
	_check(gm != null and mm != null, "reflector test autoloads are available")
	if gm == null or mm == null:
		quit(1)
		return

	var newtonian_targets: Array[String] = []
	var dobsonian_targets: Array[String] = []
	for level_number in range(26, 46):
		var level: Dictionary = mm.get_level(level_number)
		var target_id := str(level.get("target_object_id", ""))
		if level_number <= 35:
			newtonian_targets.append(target_id)
			_check(str(level.get("telescope_family", "")) == "newtonian", "L%d remains Newtonian" % level_number)
		else:
			dobsonian_targets.append(target_id)
			_check(str(level.get("telescope_family", "")) == "dobsonian", "L%d remains Dobsonian" % level_number)
		_check(not target_id.is_empty(), "L%d has an observation target" % level_number)
		_check(_object_by_id(gm.objects_data, target_id).size() > 0, "L%d target %s exists" % [level_number, target_id])
		_check(not str(level.get("title_zh", "")).contains("?"), "L%d Chinese title is intact" % level_number)
		var cloud_cover := float(level.get("environment", {}).get("cloud_cover", 0.0))
		_check(cloud_cover >= 0.0 and cloud_cover <= 1.0, "L%d cloud cover remains normalized" % level_number)

	_check(_unique_count(newtonian_targets) >= 9, "Newtonian curriculum has at least nine distinct targets")
	_check(_unique_count(dobsonian_targets) >= 9, "Dobsonian curriculum has at least nine distinct targets")
	_check(newtonian_targets.has("crab_nebula") and newtonian_targets.has("albireo"), "Newtonian reaches a supernova remnant and resolves a double star")
	_check(dobsonian_targets.has("m13") and dobsonian_targets.has("neptune") and dobsonian_targets.has("needle_galaxy"), "Dobsonian reaches a globular cluster, Neptune, and a 40-million-light-year galaxy")

	for target_id in ["crab_nebula", "dumbbell_nebula", "double_cluster", "whirlpool_galaxy", "needle_galaxy"]:
		var object: Dictionary = _object_by_id(gm.objects_data, target_id)
		var texture_path := str(object.get("sprite_path", ""))
		_check(not texture_path.is_empty() and ResourceLoader.exists(texture_path), "%s temporary art exists" % target_id)
		_check(load(texture_path) is Texture2D, "%s temporary art loads as Texture2D" % target_id)
		_check(float(object.get("distance_light_years", 0.0)) > 1000.0, "%s has an explicit deep-sky distance" % target_id)
		_check(not str(object.get("name_zh", "")).contains("?") and not str(object.get("learning_text_zh", "")).contains("?"), "%s Chinese object text is intact" % target_id)
		var image := (load(texture_path) as Texture2D).get_image()
		_check(image != null and image.get_pixel(0, 0).a < 0.01, "%s art has a transparent background" % target_id)

	var needle: Dictionary = _object_by_id(gm.objects_data, "needle_galaxy")
	_check(float(needle.get("distance_light_years", 0.0)) >= 40000000.0, "Dobsonian has a target about 40 million light-years away")

	var newtonian_stats := _prepared_stats(gm, 30)
	var dobsonian_stats := _prepared_stats(gm, 39)
	_check(is_equal_approx(float(newtonian_stats.get("aperture_mm", 0.0)), 150.0), "Newtonian exposes its real 150mm aperture")
	_check(is_equal_approx(float(dobsonian_stats.get("aperture_mm", 0.0)), 200.0), "Dobsonian exposes its real 200mm aperture")
	var gate_context := {"observation_requirements": {"aperture_min": 180}}
	var small_gate: Dictionary = ObservationSystem._requirement_failure(newtonian_stats, gate_context)
	var large_gate: Dictionary = ObservationSystem._requirement_failure(dobsonian_stats, gate_context)
	_check(str(small_gate.get("code", "")) == "aperture_mm", "150mm mirror cannot satisfy a 180mm deep-sky gate")
	_check(large_gate.is_empty(), "200mm mirror satisfies a 180mm deep-sky gate")

	for level_number in [36, 39, 40, 43, 44, 45]:
		var level: Dictionary = mm.get_level(level_number)
		_check(float(level.get("observation_requirements", {}).get("aperture_min", 0.0)) >= 180.0, "L%d makes the Dobsonian aperture meaningful" % level_number)

	print("REFLECTOR TARGET DIVERSITY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _prepared_stats(gm: Node, level_number: int) -> Dictionary:
	gm.debug_jump_to_level(level_number, true)
	return gm.calculate_stats()


func _object_by_id(objects: Array, target_id: String) -> Dictionary:
	for object_value in objects:
		if object_value is Dictionary and str(object_value.get("id", "")) == target_id:
			return object_value
	return {}


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
