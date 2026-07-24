extends SceneTree

# Regression coverage for the mission/free split. The test keeps user:// intact:
# it snapshots the save before exercising GameManager and restores it on exit.

var failures := 0
var save_path := ""
var saved_bytes := PackedByteArray()
var had_save := false


func _initialize() -> void:
	await process_frame
	save_path = ProjectSettings.globalize_path("user://savegame.json")
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(save_path)

	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(7, true)
	if gm.target_requires_relocation():
		var recommendation: Dictionary = gm.recommend_observation_location()
		if not recommendation.is_empty():
			gm.set_observing_location(recommendation["site"])

	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _frame in range(8):
		await process_frame

	var target_id := str(sky.get("target_id"))
	var candidate := _visible_non_mission(sky, target_id)
	_check(candidate != "", "1. a non-mission catalog object is selectable above the horizon")
	if candidate != "":
		var item: Dictionary = (sky.get("sky_data") as Dictionary)[candidate]
		sky.set("telescope_azimuth", float(item["azimuth"]))
		sky.set("telescope_altitude", clampf(float(item["altitude"]), 1.0, 89.0))
		sky.call("_set_view_mode", "telescope")
		sky.call("_rebuild_view")
		# A centered non-mission object must make Observe available even while
		# the mission target is still selected, then a real short click must
		# switch the active object through the same path used by players.
		var centered_available: Dictionary = sky.call("_observe_availability")
		_check(bool(centered_available.get("ok", false)), "2. a centered visible object can be observed without first selecting the mission target")
		var target_info: Dictionary = (sky.get("in_view_targets") as Dictionary)[candidate]
		var click_position: Vector2 = sky.get("VIEW_RECT").position + (target_info.get("detection_rect", target_info.get("rect", Rect2())) as Rect2).get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = click_position
		press.pressed = true
		sky.call("_input", press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = click_position
		release.pressed = false
		sky.call("_input", release)
		await process_frame
		_check(str(gm.selected_object_id) == candidate, "2. clicking a non-mission body becomes the active observation")
		_check(gm.is_free_observation(), "2. non-mission selection enters FREE OBSERVATION")
		var available: Dictionary = sky.call("_observe_availability")
		_check(bool(available.get("ok", false)), "3. centered free target is observable without the mission target in view")
		var level_before := int(gm.progress.get("current_level", 0))
		var completed_before := (gm.progress.get("completed_levels", []) as Array).duplicate()
		var logged: Dictionary = gm.record_free_observation(candidate, {"quality": "Good"})
		_check(int(gm.progress.get("current_level", 0)) == level_before, "4. free observation never advances the main level")
		_check((gm.progress.get("completed_levels", []) as Array) == completed_before, "4. free observation never completes or fails the mission")
		_check(bool(logged.get("new_record", false)) or bool(logged.get("repeat", false)), "4. free observation records independently in Club Logbook")
		sky.call("_open_detail_panel")
		await process_frame
		var detail: Control = sky.get("detail_panel")
		_check(detail != null and detail.position.x >= 750.0 and detail.size.y < 220.0, "5. details are a compact right-side inspector")
		var scrollable := false
		if detail != null:
			for node in detail.find_children("*"):
				if node is ScrollContainer:
					scrollable = true
		_check(scrollable or (detail != null and bool(detail.get_meta("scrollable_details", false))), "5. details use a scrollable body")
		var observe_rect: Rect2 = sky.get("OBSERVE_RECT")
		_check(detail == null or not Rect2(detail.position, detail.size).intersects(observe_rect), "5. details do not cover fixed Observe / Back controls")

	# The horizon/environment remains a coordinate-only visual. It must not move
	# celestial coordinates while altitude changes from 0 through 60 degrees.
	var before_vis: Dictionary = gm.target_visibility()
	for altitude in [0.0, 15.0, 30.0, 60.0]:
		sky.set("display_altitude", altitude)
		sky.call("_update_ground")
	_check(absf(float(before_vis.get("altitude", 0.0)) - float(gm.target_visibility().get("altitude", 0.0))) < 0.001, "6. horizon visuals never alter real target coordinates")

	# A map opened from sky records a sky return route; cancellation preserves the
	# current observing location rather than silently resetting it.
	gm.world_map_return_scene = "sky"
	var location_before: Dictionary = gm.observing_location().duplicate(true)
	var map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.call("_on_back")
	await process_frame
	_check(str(gm.observing_location().get("id", "")) == str(location_before.get("id", "")), "7. cancelling relocation keeps the original observing site")

	if is_instance_valid(sky):
		sky.queue_free()
	_restore_save()
	if failures == 0:
		print("FREE OBSERVATION / LOCATION / ENVIRONMENT TEST PASS")
		quit(0)
	else:
		print("FREE OBSERVATION / LOCATION / ENVIRONMENT TEST FAIL (%d)" % failures)
		quit(1)


func _visible_non_mission(sky: Node, target_id: String) -> String:
	var gm: Node = root.get_node("/root/GameManager")
	for id_value in (sky.get("sky_data") as Dictionary).keys():
		var id := str(id_value)
		var item: Dictionary = (sky.get("sky_data") as Dictionary)[id]
		if id != target_id and float(item.get("altitude", -90.0)) > 8.0 and not gm.get_object(id).is_empty():
			return id
	return ""


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
