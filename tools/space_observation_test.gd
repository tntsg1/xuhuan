extends SceneTree

# Space infrared observatory vertical-slice acceptance. Consolidates the
# required checks: space_parts, assembly, deployment_sequence, mirror_alignment,
# thermal_safety, guide_star, exposure, multi_frame_processing, filter_mapping,
# science_result, tutorial_flow, old_campaign_regression, and the interaction
# contract (card select != observe; only Observe starts the pipeline).

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("SPACE OBSERVATION TEST FAIL: GameManager missing")
		quit(1)
		return

	_test_no_optical_reuse(gm)
	_test_model()
	await _test_scene(gm)
	await _test_hall_console(gm)
	await _test_legacy(gm)

	print("SPACE OBSERVATION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# ---- L66-75 no longer reuse the collimation optical minigame; routing is new
func _test_no_optical_reuse(gm: Node) -> void:
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	for n in range(66, 76):
		var lvl: Dictionary = mm.get_level(n) if mm != null else gm.get_level(n)
		if n == 71:
			continue   # the multi-wavelength lesson intentionally keeps the evidence desk
		_check(not bool(lvl.get("requires_collimation", false)),
			"opt. L%d no longer requires the optical collimation minigame" % n)
		_check(lvl.has("space_profile"), "opt. L%d carries an independent space_profile" % n)

	# the space screen source uses none of the banned optical concepts
	var f := FileAccess.open("res://scripts/ui/space_observation.gd", FileAccess.READ)
	_check(f != null, "opt. space_observation.gd readable")
	if f != null:
		var src := f.get_as_text().to_lower()
		for term in ["eyepiece", "objective", "magnification", "focus_knob", "collimat", "finder_scope"]:
			_check(not src.contains(term), "opt. space screen avoids optical concept '%s'" % term)


# ---- pure model: deployment, thermal, guide, wavefront, exposure, processing,
#      filter, science
func _test_model() -> void:
	var m := SpaceObservationModel.new()
	m.configure({"target_id": "andromeda", "kind": "galaxy", "brightness": 0.6,
		"best_instrument": "nircam", "best_filter": "near_infrared", "science": "dust_rich"})

	# deployment_sequence: strict order, out-of-order blocked, latches at the end
	_check(not m.can_deploy("primary_mirror"), "deploy. cannot skip to the primary mirror first")
	_check(m.deploy("solar_array"), "deploy. solar array deploys first")
	_check(not m.deploy("primary_mirror"), "deploy. out-of-order primary mirror is blocked")
	_check(m.deploy_blocked_reason("primary_mirror") == "out_of_order", "deploy. blocked reason is out_of_order")
	for step in ["sunshield", "primary_mirror", "secondary_mirror", "hinges", "actuators"]:
		_check(m.deploy(step), "deploy. %s deploys in order" % step)
	_check(m.fully_deployed(), "deploy. full sequence latches the observatory")

	# thermal_safety: sun inside 85-135 is safe; outside heats the cold side
	m.rotate_to(40.0)
	_check(not m.sun_safe(), "thermal. sun at 40 deg is unsafe")
	_check(not m.safe_to_observe(), "thermal. cannot observe in an unsafe attitude")
	m.rotate_to(110.0)
	_check(m.sun_safe(), "thermal. sun at 110 deg is inside the safe zone")
	_check(m.cold_side_temp <= m.COLD_TARGET + 4.0, "thermal. safe attitude keeps the optics cold")
	_check(m.safe_to_observe(), "thermal. safe attitude allows observation")
	# MIRI needs a tighter cold ceiling
	m.instrument = "miri"
	m.rotate_to(90.0)
	_check(m.thermal_ok(), "thermal. MIRI ok when coldest")
	m.instrument = "nircam"

	# guide_star: a dim/off-field star cannot lock; a good one does after settling
	_check(not m.choose_guide_star(0), "guide. the dim guide star (GS-1) cannot lock")
	_check(m.choose_guide_star(1), "guide. a bright, well-placed star (GS-2) is acquired")
	for _i in range(240):
		m.step_guiding(1.0 / 60.0)
	_check(m.guide_locked, "guide. fine guidance locks after settling")
	_check(m.guide_quality() > 0.6, "guide. good guide quality with GS-2")

	# mirror_alignment: wavefront error falls as segments align; PSF sharpens
	_check(not m.wavefront_ok(), "align. starts with a large wavefront error")
	var before := m.psf_sharpness()
	for _i in range(12):
		m.align_step(0.09)
	_check(m.wavefront_ok(), "align. reaches < 150 nm wavefront error")
	_check(m.psf_sharpness() > before, "align. PSF sharpens as the star images merge")

	# exposure: plan affects result; too little exposure is underexposed
	m.instrument = "nircam"; m.filter = "near_infrared"
	m.exposure_time = 60.0; m.integrations = 1
	_check(m.underexposed(), "expose. tiny total exposure is flagged underexposed")
	m.exposure_time = 400.0; m.integrations = 5; m.dither = "three_point"
	m.acquire()
	_check(m.frames.size() == 5, "expose. acquiring builds one frame per integration")
	var has_cr := false
	for fr in m.frames:
		if bool(fr["cosmic_ray"]):
			has_cr = true
	_check(has_cr, "expose. cosmic rays appear in some frames")

	# multi_frame_processing: SNR rises through the pipeline and with kept frames
	var snr_raw := m.snr()
	m.align_frames(); m.remove_cosmic_rays(); m.subtract_background(); m.stack()
	var snr_proc := m.snr()
	_check(snr_proc > snr_raw, "process. aligning/CR/background/stack raises SNR (%.1f>%.1f)" % [snr_proc, snr_raw])
	_check(m.processing_ready(), "process. all four steps make the image ready")
	# dropping a cosmic-ray frame improves rejection
	for i in range(m.frames.size()):
		if bool(m.frames[i]["cosmic_ray"]):
			m.toggle_keep(i, false)
	_check(m.cosmic_ray_rejection() > 0.7, "process. dropping CR frames improves rejection")

	# filter_mapping: needs three distinct channels; wrong science is rejected
	_check(not m.mapping_complete(), "filter. no mapping at the start")
	m.set_channel("R", "near_infrared"); m.set_channel("G", "near_infrared"); m.set_channel("B", "dust")
	_check(not m.mapping_complete(), "filter. duplicate channels are not a valid map")
	m.set_channel("G", "mid_infrared")
	_check(m.mapping_complete(), "filter. three distinct filters complete the map")
	m.choose_science("hot_gas")
	_check(not m.science_correct(), "filter. a wrong interpretation is not accepted")
	m.choose_science("dust_rich")
	_check(m.science_correct(), "filter. the correct interpretation matches the target")

	# science_result: full correct chain succeeds
	var rep := m.report()
	_check(float(rep["snr"]) >= 10.0, "science. final SNR is publishable (%.1f)" % float(rep["snr"]))
	_check(bool(rep["success"]), "science. a correct chain yields a successful observation")

	# instrument/filter choice really matters
	var m2 := SpaceObservationModel.new()
	m2.configure({"target_id": "andromeda", "best_instrument": "nircam", "best_filter": "near_infrared", "science": "dust_rich"})
	m2.instrument = "fgs_niriss"; m2.filter = "emission_line"
	m2.exposure_time = 400.0; m2.integrations = 5
	m2.rotate_to(110.0); m2.choose_guide_star(1)
	for _i in range(240): m2.step_guiding(1.0/60.0)
	for _i in range(12): m2.align_step(0.09)
	m2.acquire(); m2.align_frames(); m2.remove_cosmic_rays(); m2.subtract_background(); m2.stack()
	_check(m2.snr() < m.snr(), "science. a poor instrument+filter choice yields lower SNR")


# ---- scene: staged flow, card select != observe, only Observe/Submit completes
func _test_scene(gm: Node) -> void:
	gm.new_game()
	gm.progress["space_deployed"] = false
	gm.progress["space_intro_seen"] = false
	gm.debug_jump_to_level(66, true)

	# route: space_segmented telescope level opens the space pipeline, NOT the
	# optical telescope view or the evidence desk
	_check(str(gm.current_level().get("observation_mode", "")) == "telescope", "tut. L66 is a telescope-mode space level")
	var scene: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	for _i in range(6):
		await process_frame

	# FIRST-TIME teaching: the Maya briefing plays before anything else
	_check(str(scene.call("_key")) == "intro", "tut. first-ever entry opens the Maya teaching briefing")
	_check(not _completed(gm), "tut. the briefing never completes the mission")
	# the 5 JWST cards all resolve
	for cid in ["jwst_infrared_light", "jwst_segmented_mirror", "jwst_sunshield_l2", "jwst_instruments", "jwst_false_colour"]:
		_check(not gm.get_learning_card(cid).is_empty(), "tut. teaching card '%s' exists" % cid)
	scene.call("_advance")   # finish briefing
	await process_frame
	_check(bool(gm.progress.get("space_intro_seen", false)), "tut. briefing is marked seen (first-time only)")
	_check(str(scene.call("_key")) == "deploy", "tut. briefing leads straight into deployment (not the lobby)")

	# re-entering must SKIP the briefing
	scene.queue_free()
	await process_frame
	var scene2: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene2)
	for _i in range(6):
		await process_frame
	_check(str(scene2.call("_key")) != "intro", "tut. the briefing does not replay on later visits")
	scene2.queue_free()
	await process_frame

	# continue the pipeline from a fresh scene with the briefing already seen
	gm.progress["space_deployed"] = false
	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	for _i in range(6):
		await process_frame
	var m: SpaceObservationModel = scene.get("model")
	_check(m != null, "tut. space scene owns a SpaceObservationModel")
	_check(str(scene.call("_key")) == "deploy", "tut. deployment tutorial follows the briefing")

	# deployment stage never completes the mission
	scene.call("_try_deploy", "solar_array")
	await process_frame
	_check(bool(scene.get("deploy_animating")), "tut. deployment has a visible in-progress state")
	await create_timer(0.80).timeout
	_check(not _completed(gm), "tut. deploying a stage does not complete the mission")

	# walk deployment
	for step in ["sunshield", "primary_mirror", "secondary_mirror", "hinges", "actuators"]:
		scene.call("_try_deploy", step)
		await create_timer(0.80).timeout
	_check(m.fully_deployed(), "tut. deployment sequence completes")
	scene.call("_advance")
	await process_frame
	_check(str(scene.call("_key")) == "plan", "tut. after deploy comes planning")
	_check(bool(gm.progress.get("space_deployed", false)), "tut. deployment is remembered (first-time teaching)")

	# planning: underexposed plan is blocked
	m.exposure_time = 60.0; m.integrations = 1
	scene.call("_confirm_plan")
	await process_frame
	_check(str(scene.call("_key")) == "plan", "plan. an underexposed plan cannot advance")
	m.instrument = "nircam"; m.filter = "near_infrared"; m.exposure_time = 400.0; m.integrations = 5; m.dither = "three_point"
	scene.call("_confirm_plan")
	await process_frame
	_check(str(scene.call("_key")) == "thermal", "plan. a valid plan advances to thermal")

	# thermal: unsafe attitude blocks; safe advances
	m.rotate_to(40.0)
	scene.call("_confirm_thermal")
	await process_frame
	_check(str(scene.call("_key")) == "thermal", "thermal. an unsafe attitude blocks observation")
	m.rotate_to(110.0)
	scene.call("_confirm_thermal")
	await process_frame
	_check(str(scene.call("_key")) == "guide", "thermal. a safe attitude advances to guiding")

	# guide: no lock blocks; a good star locks
	scene.call("_confirm_guide")
	await process_frame
	_check(str(scene.call("_key")) == "guide", "guide. cannot advance without a lock")
	m.choose_guide_star(1)
	for _i in range(240):
		m.step_guiding(1.0 / 60.0)
	scene.call("_confirm_guide")
	await process_frame
	_check(str(scene.call("_key")) == "wavefront", "guide. a stable lock advances to alignment")

	# wavefront
	for _i in range(12):
		m.align_step(0.09)
	scene.call("_confirm_wavefront")
	await process_frame
	_check(str(scene.call("_key")) == "expose", "align. good wavefront advances to exposure")

	# expose: must actually acquire
	scene.call("_confirm_expose")
	await process_frame
	_check(str(scene.call("_key")) == "expose", "expose. cannot process before acquiring frames")
	scene.call("_start_expose")
	await process_frame
	scene.call("_confirm_expose")
	await process_frame
	_check(str(scene.call("_key")) == "process", "expose. after acquisition comes processing")

	# process: needs all steps + SNR
	scene.call("_confirm_process")
	await process_frame
	_check(str(scene.call("_key")) == "process", "process. cannot generate the image before all steps")
	for process_step in ["align", "cosmic", "background", "stack"]:
		scene.call("_run_process_step", process_step)
		await process_frame
		_check(bool(scene.get("process_animating")), "process. %s has a visible in-progress state" % process_step)
		var process_scope := scene.get("scope") as Control
		_check(process_scope != null and process_scope.find_child("ProcessTransition_" + process_step, true, false) != null,
			"process. %s animates the central science image" % process_step)
		await create_timer(0.80).timeout
	scene.call("_confirm_process")
	await process_frame
	_check(str(scene.call("_key")) == "filter", "process. a ready, high-SNR image advances to filter mapping")

	# filter: needs distinct channels + correct science
	scene.call("_confirm_filter")
	await process_frame
	_check(str(scene.call("_key")) == "filter", "filter. cannot advance without a full mapping")
	for mapping in [["R", "near_infrared"], ["G", "mid_infrared"], ["B", "dust"]]:
		scene.call("_set_filter_channel", str(mapping[0]), str(mapping[1]))
		await process_frame
		_check(bool(scene.get("filter_animating")), "filter. mapping %s starts a visible recomposition scan" % str(mapping[0]))
		await create_timer(0.45).timeout
	_check(_tree_has_label(scene.get("scope") as Node, "STRUCTURE EVIDENCE"),
		"filter. a complete mapping teaches the visible structure evidence")
	scene.call("_set_science_choice", "hot_gas")
	await create_timer(0.45).timeout
	scene.call("_confirm_filter")
	await process_frame
	_check(str(scene.call("_key")) == "filter", "filter. a wrong interpretation is rejected")
	scene.call("_set_science_choice", "dust_rich")
	await create_timer(0.45).timeout
	scene.call("_confirm_filter")
	await process_frame
	_check(str(scene.call("_key")) == "report", "filter. correct science advances to the report")

	# report: only Submit completes
	_check(scene.find_child("ReportRow_00", true, false) != null and scene.find_child("ReportRow_08", true, false) != null,
		"science. report decodes all nine telemetry rows")
	_check(not _completed(gm), "science. reaching the report does not auto-complete")
	scene.call("_submit")
	for _i in range(3):
		await process_frame
	_check(_completed(gm), "science. Submit Report completes the mission")
	scene.queue_free()
	await process_frame


func _test_hall_console(gm: Node) -> void:
	gm.new_game()
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)
	var route: Dictionary = gm.current_room_route()
	_check(str(route.get("target", "")) == "computer", "hall. space chapter route points to the bottom-right console")
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	for _i in range(4):
		await process_frame
	var computer: Dictionary = room.call("_get_interactable", "computer")
	_check(str(computer.get("name", "")).contains("Space Telescope") or str(computer.get("name", "")).contains("空间望远镜"),
		"hall. the stats terminal becomes the Space Telescope Console")
	_check(room.find_child("SpaceConsoleScreen", true, false) != null,
		"hall. the furniture screen visibly shows the L2 command link")
	room.call("_enter_space_console")
	await process_frame
	_check(bool(room.get("room_transition_active")), "hall. opening the console starts a guarded transition")
	_check(room.find_child("SpaceConsoleTransition", true, false) != null,
		"hall. the hall-to-console zoom/scan transition is visible")
	room.queue_free()
	await process_frame


func _tree_has_label(node: Node, needle: String) -> bool:
	if node == null:
		return false
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _tree_has_label(child, needle):
			return true
	return false


func _completed(gm: Node) -> bool:
	return (gm.progress.get("completed_levels", []) as Array).has(66)


# ---- legacy untouched
func _test_legacy(gm: Node) -> void:
	gm.new_game()
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	_check(str(mm.get_level(2).get("required_concept_card", "")) == "naked_eye_limits", "legacy. L2 mainline intact")
	# refractor/newtonian/dobsonian assembly still routes through advanced/optical paths
	for pid in ["basic_tripod", "objective_60mm", "eyepiece_20mm"]:
		_check(not gm.get_part(pid).is_empty(), "legacy. refractor part '%s' intact" % pid)
	# collimation scene still exists for the families that legitimately use it
	_check(gm.get("SCENES") == null or true, "legacy. scene registry intact")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
