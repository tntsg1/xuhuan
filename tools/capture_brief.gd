extends SceneTree

# Captures the Concept Brief screen. Run WITHOUT --headless.
# NOTE: resets the save - back it up before running.

var frames := 0


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if frames == 10:
		gm.new_game()
		gm.call("try_teaching_intercept", "before_observation", "sky")
	if frames == 40:
		root.get_texture().get_image().save_png("user://v2_concept_brief.png")
		print("saved v2_concept_brief.png")
		quit()
