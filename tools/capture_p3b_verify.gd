extends SceneTree

# P3b verification: (1) a story dialogue line carrying an "image" field
# renders the diagram centered without deforming or covering UI; (2) a new
# learning card (seeing_turbulence) renders correctly in brief mode.
# Run WITHOUT --headless. NOTE: resets the save - back it up first.

var frames := 0
var view: Node


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", ProjectSettings.globalize_path("user://" + file_name))


func _initialize() -> void:
	process_frame.connect(_tick)


func _swap_story() -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load("res://scenes/story_dialogue.tscn")
	view = packed.instantiate()
	root.add_child(view)


func _swap_card() -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load("res://scenes/learning_card.tscn")
	view = packed.instantiate()
	root.add_child(view)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	var tf: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or sm == null or tf == null:
		print("FAIL: missing autoload")
		quit(1)
		return

	match frames:
		4:
			gm.call("new_game")
			# level_11_before line 2 (index 2, 0-based) carries the
			# seeing_turbulence image per story_dialogues.json.
			sm.call("begin_event", "level_11_before", "sky_observation")
			_swap_story()
			view.line_index = 2
			view.call("_show_line")
		20:
			_shot("p3b_dialogue_image_line.png")
			view.queue_free()
			view = null
			# Concept Brief for the new seeing_turbulence card.
			tf.active_card_mode = "brief"
			tf.active_card_id = "seeing_turbulence"
			tf.active_step_id = "capture_seeing_intro"
			tf.return_scene_key = "sky_observation"
			_swap_card()
		36:
			_shot("p3b_learning_card_seeing.png")
			quit(0)
