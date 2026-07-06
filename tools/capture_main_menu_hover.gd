extends SceneTree

var frames := 0
var view: Node


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main_menu.tscn")
	view = scene.instantiate()
	root.add_child(view)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 8 and view.has_method("_set_button_feedback"):
		view.call("_set_button_feedback", "new", "hover")
	if frames < 10:
		return
	var path := "user://main_menu_hover.png"
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	quit(0)
