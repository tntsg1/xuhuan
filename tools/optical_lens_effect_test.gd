extends SceneTree

var failures := 0
var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	if not gm.progress["unlocked_parts"].has("basic_finder_scope"):
		gm.progress["unlocked_parts"].append("basic_finder_scope")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		gm.install_part(part_type, 0)

	_test_shader()
	await _test_sky_observation()
	await _test_telescope_view()
	print("OPTICAL LENS EFFECT TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _test_shader() -> void:
	var path := "res://shaders/optical_lens.gdshader"
	_check(ResourceLoader.exists(path), "full-colour optical lens shader exists")
	var shader := load(path) as Shader
	_check(shader != null, "optical lens shader loads")
	if shader != null:
		_check(not shader.code.contains("uniform float monochrome"), "ordinary lens does not expose a monochrome conversion")
		_check(shader.code.contains("vec3(red, green, blue)"), "ordinary lens samples and preserves RGB channels")


func _test_sky_observation() -> void:
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var overlay := view.get("optical_lens_overlay") as ColorRect
	var reticle := view.get("scope_reticle_layer") as Control
	_check(overlay != null, "Sky Observation owns one optical glass overlay")
	_check(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "optical glass never blocks mouse or touch input")
	_check(overlay != null and reticle != null and overlay.z_index < reticle.z_index, "reticle remains straight and readable above curved glass")
	var curvatures: Array[float] = []
	for mode in ["naked_eye", "finder", "telescope"]:
		view.call("_set_view_mode", mode)
		var material := view.get("optical_lens_material") as ShaderMaterial
		curvatures.append(float(material.get_shader_parameter("curvature")))
		_check(float(material.get_shader_parameter("circular_lens")) == 0.0, "%s search view uses the rectangular observation-window lens" % mode)
	_check(curvatures[0] < curvatures[1] and curvatures[1] < curvatures[2], "Eye < Finder < Scope optical curvature")
	_check(float(view.get("fov_x")) == 6.0, "mode switching keeps the existing Scope FOV")
	view.queue_free()
	await process_frame


func _test_telescope_view() -> void:
	gm.selected_object_id = str(gm.current_target_object_id())
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var overlay := view.find_child("OpticalLensOverlay", true, false) as ColorRect
	_check(overlay != null, "detailed Telescope View owns a curved optical glass layer")
	if overlay != null:
		var material := overlay.material as ShaderMaterial
		print("  info: telescope mode=", view.get("observation_mode"),
			" path=", overlay.get_path(),
			" circular=", material.get_shader_parameter("circular_lens") if material != null else "no material",
			" curvature=", material.get_shader_parameter("curvature") if material != null else "no material")
		_check(material != null and float(material.get_shader_parameter("circular_lens")) == 1.0, "detailed Telescope View uses a circular lens")
		_check(material != null and float(material.get_shader_parameter("curvature")) >= 0.05, "detailed telescope curvature is visible but restrained")
		_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "detailed lens does not block controls")
	view.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
