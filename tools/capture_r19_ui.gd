extends SceneTree

# Windowed captures for Round 19: constellation 4 phases (EN+ZH),
# telescope type selection, quick-prepare readiness.

var current: Node


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/shots"))

	# Telescope type selection (recommendation mode at L26)
	gm.debug_jump_to_level(26, false)
	gm.set_meta("telescope_types_browse", false)
	await _open("res://scenes/telescope_types.tscn", 10)
	await _shoot("r19_telescope_types_en")
	gm.language_mode = "zh"; gm.language_changed.emit()
	current.call("_build")
	await _wait(6)
	await _shoot("r19_telescope_types_zh")
	gm.language_mode = "en"; gm.language_changed.emit()
	_free()

	# Constellation phases (Big Dipper, L114)
	gm.debug_jump_to_level(114, true)
	await _constellation_phases("en")
	gm.language_mode = "zh"; gm.language_changed.emit()
	gm.debug_jump_to_level(114, true)
	await _constellation_phases("zh")
	gm.language_mode = "en"; gm.language_changed.emit()
	quit(0)


func _constellation_phases(lang: String) -> void:
	# Phase 1: identify
	await _open("res://scenes/constellation_observation.tscn", 12)
	await _shoot("r19_constellation_1_identify_" + lang)
	# Phase 2: connect
	current.call("_choose_shape", "ursa_major")
	await _wait(8)
	var order: Array = current.get("ordered_indices")
	current.call("_try_connect_star", int(order[0]))
	current.call("_try_connect_star", int(order[1]))
	current.call("_try_connect_star", int(order[2]))
	await _wait(6)
	await _shoot("r19_constellation_2_connect_" + lang)
	# Phase 3: navigate
	for idx in order:
		current.call("_try_connect_star", int(idx))
	await _wait(6)
	await _shoot("r19_constellation_3_navigate_" + lang)
	# Phase 4: ready
	current.set("aim_az", current.get("target_az"))
	current.set("aim_alt", current.get("target_alt"))
	current.call("_update_status")
	await _wait(6)
	await _shoot("r19_constellation_4_ready_" + lang)
	_free()


func _open(path: String, frames: int) -> void:
	_free()
	current = load(path).instantiate()
	root.add_child(current)
	await _wait(frames)


func _free() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
		current = null


func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame


func _shoot(tag: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/shots/%s.png" % tag))
	print("SAVED " + tag)
