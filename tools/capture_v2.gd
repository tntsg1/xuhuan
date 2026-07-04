extends SceneTree

# Captures v2 teaching flow screens. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0
var view: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _swap(scene_path: String) -> void:
	if view != null:
		view.queue_free()
	var packed: PackedScene = load(scene_path)
	view = packed.instantiate()
	root.add_child(view)


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			gm.new_game()
			_swap("res://scenes/sky_observation.tscn")
		30:
			_shot("v2_sky_naked_eye.png")
			gm.set("selected_object_id", "moon")
			_swap("res://scenes/telescope_view.tscn")
		50:
			_shot("v2_view_naked_eye.png")
			gm.set("selected_object_id", "moon")
			gm.call("evaluate_selected_object")
			gm.call("complete_current_mission", "moon", gm.get("last_observation"))
			_swap("res://scenes/learning_card.tscn")
		70:
			_shot("v2_learning_card.png")
			gm.progress["current_level"] = 4
			gm.call("reset_assembly")
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece"]:
				gm.call("install_part", part_type, 0)
			gm.set("selected_object_id", "jupiter")
			_swap("res://scenes/telescope_view.tscn")
		90:
			_shot("v2_focus_blurry.png")
			view.call("_set_focus_value", view.get("target_focus_value"))
		100:
			_shot("v2_focus_sharp.png")
			quit()
