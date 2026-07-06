extends SceneTree

# Verifies the E1 observation-condition effects (turbulence, cloud,
# sky brightness) render and animate. In-memory level override only -
# nothing is written to the savegame.
# Run WITHOUT --headless:
# godot --script res://tools/capture_effects_e1.gd

const CASES := [
	{"id": "mars", "level": 11, "name": "effects_L11_poor_seeing"},
	{"id": "sirius", "level": 17, "name": "effects_L17_clouds"},
	{"id": "andromeda", "level": 20, "name": "effects_L20_city"},
	{"id": "andromeda", "level": 21, "name": "effects_L21_dark"},
	{"id": "jupiter", "level": 5, "name": "effects_L5_baseline"}
]

var frames := 0
var case_index := -1
var phase := 0
var view: Node
var second_shot_frame := 0


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if case_index >= CASES.size():
		return
	if phase == 0 and frames >= 5:
		case_index += 1
		if case_index >= CASES.size():
			quit()
			return
		var case_data: Dictionary = CASES[case_index]
		var gm: Node = root.get_node("/root/GameManager")
		var progress: Dictionary = gm.get("progress")
		progress["current_level"] = int(case_data.get("level", 5))
		gm.set("selected_object_id", str(case_data.get("id", "")))
		var scene: PackedScene = load("res://scenes/telescope_view.tscn")
		view = scene.instantiate()
		root.add_child(view)
		phase = 1
		frames = 0
		return
	if phase == 1 and frames >= 40:
		# First frame: let turbulence/breathing settle into a visible state.
		var name: String = str(CASES[case_index].get("name", "case"))
		root.get_texture().get_image().save_png("user://%s_a.png" % name)
		print("saved user://%s_a.png" % name,
			"  cond_turbulence=", view.get("cond_turbulence"),
			"  cond_cloud_atten=", view.get("cond_cloud_atten"),
			"  cond_sky_lift=", view.get("cond_sky_lift"))
		phase = 2
		second_shot_frame = frames + 60  # ~1 second later at 60fps
		return
	if phase == 2 and frames >= second_shot_frame:
		var name: String = str(CASES[case_index].get("name", "case"))
		root.get_texture().get_image().save_png("user://%s_b.png" % name)
		print("saved user://%s_b.png" % name,
			"  cond_turbulence=", view.get("cond_turbulence"),
			"  cond_cloud_atten=", view.get("cond_cloud_atten"))
		view.queue_free()
		view = null
		phase = 0
		frames = 0
