extends SceneTree

const OUTPUT_DIR := "res://artifacts/observatory_furniture"
const FURNITURE_IDS := [
	"cabinet",
	"door",
	"mission",
	"assembly",
	"journal",
	"computer",
]

var room: Control
var animator: ObservatoryFurnitureAnimator


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	room = scene.instantiate()
	root.add_child(room)
	await process_frame
	await create_timer(0.25).timeout
	_save("01_all_closed.png")

	animator = room.get_node("FurnitureAnimator") as ObservatoryFurnitureAnimator
	for id in FURNITURE_IDS:
		animator.play_open(id)
	await create_timer(0.50).timeout
	_save("02_all_open.png")

	for id in FURNITURE_IDS:
		animator.play_close(id)
	await create_timer(0.40).timeout
	_save("03_all_closed_after_cycle.png")
	print("OBSERVATORY FURNITURE VISUAL CAPTURE PASS")
	quit(0)


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
