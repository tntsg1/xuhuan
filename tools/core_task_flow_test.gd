extends SceneTree

# Regression coverage for the core handoff:
# Mission Board -> persistent hall route -> physical destination -> observation
# result -> next level route and a retained logbook record.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return
	gm.new_game()

	var room_scene: PackedScene = load("res://scenes/observatory_room.tscn")
	var room: Node = room_scene.instantiate()
	root.add_child(room)
	await process_frame

	# L1 starts at the board, creates a route, and keeps its route indicator
	# active until the player reaches the Observation Pad.
	room.call("_open_mission_board")
	_check(room.get("mission_board_popup") != null, "Mission Board opens")
	room.call("_close_mission_board", true)
	_check(str(gm.room_guidance_target) == "telescope", "L1 route targets Observation Pad")
	room.call("_update_room_guidance_panel")
	_check(bool(room.get("route_edge_indicator").visible), "Route indicator remains visible away from target")
	var pad: Dictionary = room.call("_get_interactable", "telescope")
	room.set("player_pos", (pad.get("rect", Rect2()) as Rect2).get_center())
	room.call("_update_nearby")
	room.call("_update_room_guidance_panel")
	_check(str(room.get("nearby_id")) == "telescope", "Player can reach the routed interaction range")
	_check(not bool(room.get("route_edge_indicator").visible), "Route indicator yields to the E prompt in range")

	# Simulate the completed L1 observation. Completion must update the route to
	# the next level and add a durable, data-rich journal record.
	gm.selected_object_id = gm.current_target_object_id()
	var observation: Dictionary = gm.evaluate_selected_object()
	_check(bool(observation.get("success", false)), "L1 naked-eye observation succeeds")
	_check(gm.complete_current_mission(gm.selected_object_id, observation), "L1 completion succeeds")
	_check(int(gm.progress.get("current_level", 0)) == 2, "Completion advances to L2")
	var next_route: Dictionary = gm.current_room_route()
	_check(str(next_route.get("target", "")) == "telescope", "Completion resolves the next physical route")
	var entries: Array = gm.progress.get("journal_entries", [])
	_check(entries.size() == 1, "Completion keeps one historical log entry")
	if not entries.is_empty():
		var entry: Dictionary = entries[0]
		_check(entry.has("equipment_en") and entry.has("environment_en") and entry.has("actions_en") and entry.has("knowledge_en"), "Log entry stores setup, environment, action, and knowledge")

	room.queue_free()
	if failures == 0:
		print("CORE TASK FLOW TEST PASS")
		quit(0)
	else:
		print("CORE TASK FLOW TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
