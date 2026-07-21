extends SceneTree

# Windowed captures of Mobile Controller Mode surfaces:
#   1. lobby with joystick + Interact/Missions buttons
#   2. mobile settings popup
#   3. sky observation with Boost + touch layout
#   4. telescope view with focus nudge buttons

var shots := []
var step := 0
var current: Node


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	root.get_node("/root/TouchInput").set_mobile_mode(true)
	await _capture_room()
	await _capture_settings()
	await _capture_sky()
	await _capture_view()
	quit(0)


func _capture_room() -> void:
	current = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(current)
	for _i in range(14):
		await process_frame
	current.set("player_pos", Vector2(690, 250))
	current.call("_update_nearby")
	await _shoot("mobile_lobby")


func _capture_settings() -> void:
	current.call("_toggle_mobile_settings")
	for _i in range(8):
		await process_frame
	await _shoot("mobile_settings")
	current.call("_toggle_mobile_settings")
	current.queue_free()
	await process_frame


func _capture_sky() -> void:
	var gm: Node = root.get_node("/root/GameManager")
	gm.debug_jump_to_level(7, true)
	current = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(current)
	for _i in range(20):
		await process_frame
	await _shoot("mobile_sky")
	current.queue_free()
	await process_frame


func _capture_view() -> void:
	var gm: Node = root.get_node("/root/GameManager")
	gm.debug_jump_to_level(4, true)
	current = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(current)
	for _i in range(20):
		await process_frame
	var quiz: Node = current.get("quiz_brief_overlay")
	if quiz != null:
		quiz.queue_free()
		current.set("quiz_brief_overlay", null)
		current.set("quiz_brief_dismissed", true)
		for _i in range(4):
			await process_frame
	await _shoot("mobile_telescope")
	current.queue_free()
	await process_frame


func _shoot(tag: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := "res://tools/shots/%s.png" % tag
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	image.save_png(ProjectSettings.globalize_path(path))
	print("SAVED " + path)
