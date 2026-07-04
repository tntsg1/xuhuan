extends SceneTree

# Captures the L4 focus concept brief and mission-complete card.
# Run: godot --headless --path <project> --script res://tools/capture_learning_card.gd

var frames := 0
var view: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _swap_card() -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load("res://scenes/learning_card.tscn")
	view = packed.instantiate()
	root.add_child(view)


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", ProjectSettings.globalize_path("user://" + file_name))


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var tf: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or tf == null:
		print("FAIL: missing GameManager or TeachingFlowManager")
		quit(1)
		return

	match frames:
		4:
			gm.call("new_game")
			gm.progress["current_level"] = 4
			tf.active_card_mode = "brief"
			tf.active_card_id = "focus_focal_plane"
			tf.active_step_id = "capture_focus_intro"
			tf.return_scene_key = "telescope"
			_swap_card()
			print("Concept Brief image rect: 720x405 at (152,142)")
		12:
			_shot("learning_card_focus_brief.png")
			view.queue_free()
			var level: Dictionary = gm.call("current_level")
			gm.call("reset_assembly")
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob"]:
				gm.call("install_part", part_type, 0)
			var observation: Dictionary = {
				"quality": "Good",
				"success": true,
				"observation_mode": "telescope"
			}
			gm.last_learning_card = tf.call(
				"make_mission_complete_payload",
				level,
				gm.call("get_object", "jupiter"),
				observation,
				gm.call("calculate_stats")
			)
			tf.active_card_mode = "complete"
			_swap_card()
			print("Mission Complete image rect: 460x259 at (440,136)")
		20:
			_shot("learning_card_focus_complete.png")
			quit(0)
