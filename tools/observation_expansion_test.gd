extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	_check(gm != null and mm != null and sm != null, "autoloads available")
	if gm == null or mm == null or sm == null:
		quit(1)
		return
	_check(mm.get_max_level() == 131, "campaign extends through L131")
	_check(mm.get_level(91).get("id", "") == "level_91", "legacy L91 remains unchanged")
	_check(gm.constellations_data.size() == 9, "nine constellation patterns loaded")

	var required_objects := ["mercury","venus","saturn","uranus","neptune","moon_crater_copernicus","moon_mare_tranquillitatis","moon_terminator","albireo","pleiades","m13","ring_nebula","lagoon_nebula","sombrero_galaxy"]
	for id in required_objects:
		var obj: Dictionary = gm.get_object(id)
		_check(not obj.is_empty(), "%s can be selected" % id)
		var sprite := str(obj.get("sprite_path", ""))
		_check(sprite != "" and FileAccess.file_exists(sprite), "%s has independent visual" % id)

	var expected_constellations := ["ursa_major","cassiopeia","cygnus","lyra","aquila","taurus","scorpius","orion_constellation","leo"]
	for id in expected_constellations:
		var data: Dictionary = gm.get_constellation(id)
		_check(data.get("stars", []).size() >= 5, "%s has a real star pattern" % id)
		_check(data.get("connection_order", []).size() >= data.get("stars", []).size(), "%s has ordered connection logic" % id)
		_check(not data.get("visible_seasons", []).is_empty(), "%s has seasonal visibility" % id)

	var evaluator = load("res://scripts/systems/observation_system.gd")
	var stats := {"light_score":95.0,"clarity_score":95.0,"stability_score":95.0,"magnification":80.0,"useful_magnification_limit":180.0}
	var venus: Dictionary = gm.get_object("venus")
	var base := {"observation_mode":"telescope","minimum_success_quality":"Good","focus_error":0.0,"requires_focus":true,"focus_tolerance":0.06,"magnification":80.0,"altitude":35.0,"environment":{"seeing":"good","sky_brightness":"dark"},"observation_requirements":{"exposure_min":0.2,"exposure_max":0.48}}
	var overexposed: Dictionary = evaluator.evaluate(stats, venus, base.merged({"exposure":0.9}, true))
	var exposed: Dictionary = evaluator.evaluate(stats, venus, base.merged({"exposure":0.35}, true))
	_check(not overexposed.get("success", true) and overexposed.get("technique_failure", {}).get("code", "") == "overexposed", "Venus overexposure is a real failure")
	_check(exposed.get("technique_failure", {}).is_empty(), "Venus succeeds at controlled exposure")

	var ring: Dictionary = gm.get_object("ring_nebula")
	var faint_context := base.merged({"observation_requirements":{"filter":"nebula","dark_adaptation_min":0.8,"require_averted_vision":true},"exposure":0.5,"filter":"none","dark_adaptation":1.0,"averted_vision":true}, true)
	var no_filter: Dictionary = evaluator.evaluate(stats, ring, faint_context)
	var ready: Dictionary = evaluator.evaluate(stats, ring, faint_context.merged({"filter":"nebula"}, true))
	_check(no_filter.get("technique_failure", {}).get("code", "") == "filter", "nebula filter requirement is enforced")
	_check(ready.get("technique_failure", {}).is_empty(), "filter + adaptation + averted vision can satisfy the technique")

	var sky_scene: PackedScene = load("res://scenes/sky_observation.tscn")
	_check(sky_scene != null, "shared sky observation scene loads")
	gm.debug_jump_to_level(114, true)
	_check(gm.current_requires_telescope(), "constellation search uses the telescope workflow")
	_check(gm.telescope_is_ready(), "prepared constellation search has a telescope and finder")
	_check(str(gm.SCENES.get("sky", "")) == "res://scenes/sky_observation.tscn", "constellation route resolves through the shared sky scene")
	var constellation_view: Node = sky_scene.instantiate()
	root.add_child(constellation_view)
	await process_frame
	_check(str(constellation_view.get("target_id")) == "ursa_major", "shared sky scene binds the constellation target")
	_check(constellation_view.get("constellation_overlay") != null, "constellation renders as a star field in the shared sky view")
	constellation_view.queue_free()
	await process_frame
	var telescope_constellation: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(telescope_constellation)
	await process_frame
	_check(telescope_constellation.get("constellation_field") != null, "centered constellation opens in the regular telescope observation view")
	telescope_constellation.queue_free()
	await process_frame
	gm.debug_jump_to_level(94, true)
	var telescope_view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(telescope_view)
	await process_frame
	_check(str(telescope_view.get("current_sprite_path")).contains("venus.svg"), "Venus uses its dedicated crescent visual at runtime")
	_check(telescope_view.get("technique_status_label") != null, "expansion technique HUD is built")
	telescope_view.queue_free()
	await process_frame
	for n in range(92, 132):
		var level: Dictionary = mm.get_level(n)
		_check(int(level.get("level_number", 0)) == n, "L%d is contiguous" % n)
		_check(gm.get_learning_card(str(level.get("required_concept_card", ""))).size() > 0, "L%d has bilingual teaching" % n)
	if failures == 0:
		print("OBSERVATION EXPANSION TEST PASS")
		quit(0)
	else:
		print("OBSERVATION EXPANSION TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
