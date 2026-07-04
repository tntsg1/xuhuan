extends SceneTree

# Captures the intro dialogue and mission board popup. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0
var view: Node


func _tick_shot(file_name: String) -> void:
	root.get_texture().get_image().save_png("user://" + file_name)
	print("saved ", file_name)


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	match frames:
		10:
			gm.new_game()
			gm.call("try_story_event", "intro", "observatory")
		35:
			_tick_shot("story_intro.png")
			gm.call("complete_current_story")
		60:
			# now in observatory; open the mission board popup
			view = current_scene
			view.call("_toggle_mission_board")
		75:
			_tick_shot("story_mission_board.png")
			quit()
