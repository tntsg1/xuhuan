extends SceneTree

# Verifies the per-planet state-texture cross-fade (blurry when out of
# focus, clear once focused). Covers every STATE_TEXTURES entry.
# Run WITHOUT --headless:
# godot --script res://tools/capture_planet_states.gd
# In-memory level override only - nothing is written to the savegame.

const CASES := [
	{"id": "jupiter", "level": 10},
	{"id": "mars", "level": 11},
	{"id": "moon", "level": 4},
	{"id": "andromeda", "level": 21},
	{"id": "sirius", "level": 22},
	{"id": "betelgeuse", "level": 12},
	{"id": "arcturus", "level": 17},
	{"id": "proxima", "level": 21},
	{"id": "orion_nebula", "level": 18}
]

var frames := 0
var case_index := -1
var phase := 0
var view: Node


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
	if phase == 1 and frames == 25:
		var id: String = str(CASES[case_index].get("id", ""))
		root.get_texture().get_image().save_png("user://%s_state_defocused.png" % id)
		print("saved user://%s_state_defocused.png  focus_error=" % id, view.get("focus_error"))
		var target_focus: float = view.get("target_focus_value")
		view.call("_set_focus_value", target_focus)
		phase = 2
		return
	if phase == 2 and frames == 115:
		var id: String = str(CASES[case_index].get("id", ""))
		root.get_texture().get_image().save_png("user://%s_state_focused.png" % id)
		print("saved user://%s_state_focused.png  focus_error=" % id, view.get("focus_error"),
			"  blur_weight=", view.get("blur_weight"),
			"  sprite=", view.get("current_sprite_path"))
		view.queue_free()
		view = null
		phase = 0
		frames = 0
