extends SceneTree

var failures := 0
var gm: Node
var feedback: Node
var sfx_events: Array[String] = []


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	feedback = root.get_node_or_null("/root/InteractionFeedback")
	_check(gm != null and feedback != null, "animation service autoloads without changing GameManager")
	if gm == null or feedback == null:
		quit(1)
		return
	feedback.feedback_sfx_requested.connect(func(event_name: String) -> void: sfx_events.append(event_name))
	await _test_common_feedback_and_accessibility()
	await _test_observation_motion()
	await _test_focus_feedback()
	await _test_assembly_snap()
	await _test_collimation_feedback()
	print("ANIMATION FEEDBACK ACCEPTANCE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _test_common_feedback_and_accessibility() -> void:
	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(160, 44)
	host.add_child(button)
	await process_frame
	_check(bool(button.get_meta("feedback_bound", false)), "important buttons receive the shared hover/click feedback")
	feedback.set_reduced_motion(true)
	var start_position := host.position
	feedback.page_enter(host, Vector2(0, 20))
	_check(host.position == start_position, "reduced motion removes page travel while preserving feedback")
	feedback.set_reduced_motion(false)
	var tutorial_key := "animation_acceptance_once_%d" % Time.get_ticks_usec()
	var first: Variant = feedback.tutorial_highlight_once(button, tutorial_key, "Guide", host)
	var second: Variant = feedback.tutorial_highlight_once(button, tutorial_key, "Guide", host)
	_check(first != null and second == null, "tutorial highlights do not repeat")
	if first is Control:
		var tutorial := first as Control
		var frame := tutorial.get_child(1) as Panel
		var label := tutorial.get_child(2) as Label
		_check(not frame.get_rect().intersects(label.get_rect()) and label.position.x >= 0.0 and label.position.x + label.size.x <= host.size.x, "tutorial copy stays on-screen without covering its highlighted control")
	host.queue_free()
	await process_frame


func _prepare_level(level_number: int) -> void:
	gm.new_game()
	gm.progress["current_level"] = level_number
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		if not gm.unlocked_parts_by_type(part_type).is_empty():
			gm.install_part(part_type, 0)
	gm.selected_object_id = str(gm.current_target_object_id())


func _test_observation_motion() -> void:
	_prepare_level(15)
	var view: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	view.call("_set_view_mode", "finder")
	var view_layer := view.get("view_layer") as Control
	_check(view_layer != null and (view_layer.scale != Vector2.ONE or view_layer.modulate.a < 1.0), "Eye/Finder/Scope switching starts a restrained visual transition")
	await create_timer(0.36).timeout
	_check(view_layer.scale.distance_to(Vector2.ONE) < 0.01, "mode transition settles without changing target coordinates")
	var real_before := float(view.get("telescope_azimuth"))
	var display_before := float(view.get("display_azimuth"))
	view.call("_apply_aim_delta", 12.0, 0.0)
	var real_after := float(view.get("telescope_azimuth"))
	var display_after := float(view.get("display_azimuth"))
	_check(real_after != real_before and display_after != display_before and display_after != real_after, "aim data is immediate while scale and pointer chase smoothly")
	await create_timer(0.35).timeout
	_check(absf(float(view.get("display_azimuth")) - real_after) < 0.5, "animated scale catches the real azimuth without desynchronizing")
	gm.progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	view.call("_update_calibration_panel")
	await process_frame
	var finder_events_before := sfx_events.count("finder_aligned") + sfx_events.count("finder_lock")
	view.call("_update_calibration_panel")
	await process_frame
	var finder_events_after := sfx_events.count("finder_aligned") + sfx_events.count("finder_lock")
	_check(bool(view.get("calibration_success_played")) and finder_events_after == finder_events_before, "finder alignment success feedback plays only once")
	var ring := view.get("target_state_ring") as TextureRect
	if ring != null and ring.texture != null:
		var center_alpha := ring.texture.get_image().get_pixel(ring.texture.get_width() / 2, ring.texture.get_height() / 2).a
		_check(center_alpha < 0.35, "target lock ring keeps its center transparent")
	view.queue_free()
	await process_frame


func _test_focus_feedback() -> void:
	_prepare_level(8)
	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	if bool(view.get("requires_focus")):
		var target := float(view.get("target_focus_value"))
		view.call("_set_focus_value", target)
		_check(bool(view.get("focus_lock_feedback_played")), "focus image and knob emit one sharp-focus lock")
		var count_before := sfx_events.count("focus_locked")
		view.call("_set_focus_value", target)
		_check(sfx_events.count("focus_locked") == count_before, "sharp-focus lock does not repeat")
		_check(float(view.get("focus_error")) <= float(view.get("focus_tolerance")), "focus animation leaves the original focus condition unchanged")
	view.queue_free()
	await process_frame


func _test_assembly_snap() -> void:
	gm.new_game()
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	var assembly: Control = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(assembly)
	await process_frame
	await process_frame
	assembly.call("_select_part", "tripod")
	assembly.call("_try_install", "tripod")
	await create_timer(0.05).timeout
	_check(assembly.find_child("InstallingPartFeedback", true, false) != null, "part icon travels from its card to the blueprint slot")
	await create_timer(0.65).timeout
	_check(bool(gm.progress.get("assembly_state", {}).get("tripod", {}).get("installed", false)), "snap animation commits through the original installation logic")
	assembly.queue_free()
	await process_frame


func _test_collimation_feedback() -> void:
	_prepare_level(26)
	var collimation: Control = load("res://scenes/collimation.tscn").instantiate()
	root.add_child(collimation)
	await process_frame
	await process_frame
	collimation.set("secondary_x", 0.0)
	collimation.set("secondary_y", 0.0)
	collimation.set("primary_x", 0.0)
	collimation.set("primary_y", 0.0)
	collimation.call("_refresh")
	await create_timer(0.18).timeout
	var axis := collimation.get("optical_axis") as Line2D
	_check(bool(collimation.get("collimation_success_played")), "collimation threshold produces one clear completion feedback")
	_check(axis != null and axis.default_color.is_equal_approx(Color(0.48, 0.92, 0.58)), "collimation light path turns green when aligned")
	_check(axis != null and axis.points.size() == 3, "mirror adjustments drive the primary-secondary-eyepiece light path")
	collimation.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		print("  FAIL: ", message)
