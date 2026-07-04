extends SceneTree

# Captures the telescope view for each target type. Run WITHOUT --headless:
# godot --script res://tools/capture_telescope_view.gd

const TARGETS: Array[String] = ["moon", "sirius", "jupiter", "orion_nebula", "andromeda"]

var frames := 0
var current := -1
var view: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames % 20 == 1:
		if current >= 0:
			var path := "user://tele_%s.png" % TARGETS[current]
			root.get_texture().get_image().save_png(path)
			print("saved ", path)
		if view != null:
			view.queue_free()
			view = null
		current += 1
		if current >= TARGETS.size():
			quit()
			return
		var gm: Node = root.get_node("/root/GameManager")
		gm.set("selected_object_id", TARGETS[current])
		var scene: PackedScene = load("res://scenes/telescope_view.tscn")
		view = scene.instantiate()
		root.add_child(view)
