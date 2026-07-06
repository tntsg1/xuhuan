extends SceneTree

# Verifies the E3 sky-observation-view effects (sky lift + magnitude
# filtering, cloud drift, star twinkle) render across all three view modes.
# In-memory level overrides only - new_game() resets the save first.
# Run WITHOUT --headless:
# godot --script res://tools/capture_effects_e3.gd

var gm: Node
var frames := 0
var phase := 0
var case_index := -1
var view: Node
var first_pixels: PackedByteArray
var second_pixels: PackedByteArray

const CASES := [
	{"level": 20, "id": "andromeda", "name": "sky_L20_city", "mode": "telescope"},
	{"level": 21, "id": "andromeda", "name": "sky_L21_dark", "mode": "telescope"},
	{"level": 17, "id": "sirius", "name": "sky_L17_clouds", "mode": "telescope", "diff": true},
	{"level": 5, "id": "jupiter", "name": "sky_L5_baseline", "mode": "telescope"},
	{"level": 20, "id": "andromeda", "name": "sky_L20_eye", "mode": "naked_eye"},
	{"level": 20, "id": "andromeda", "name": "sky_L20_finder", "mode": "finder"},
	{"level": 20, "id": "andromeda", "name": "sky_L20_scope", "mode": "telescope"}
]


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if case_index >= CASES.size():
		return
	if phase == 0 and frames >= 3:
		case_index += 1
		if case_index >= CASES.size():
			quit()
			return
		_setup_case(CASES[case_index])
		phase = 1
		frames = 0
		return
	if phase == 1 and frames >= 40:
		var case_data: Dictionary = CASES[case_index]
		var name: String = str(case_data.get("name", "case"))
		var img := root.get_texture().get_image()
		img.save_png("user://%s.png" % name)
		print("saved user://%s.png" % name,
			"  view_mode=", view.get("view_mode"),
			"  sky_key=", view.call("_sky_brightness_key"),
			"  cloud_cover=", view.call("_cloud_cover_amount"),
			"  star_points=", int((view.get("star_points") as Array).size()))
		if bool(case_data.get("diff", false)):
			first_pixels = img.get_data()
			phase = 2
			frames = 0
			return
		phase = 0
		frames = 0
		return
	if phase == 2 and frames >= 90:
		# ~1.5s later at 60fps - compare pixels to prove clouds are moving.
		var case_data: Dictionary = CASES[case_index]
		var name: String = str(case_data.get("name", "case"))
		var img := root.get_texture().get_image()
		img.save_png("user://%s_b.png" % name)
		second_pixels = img.get_data()
		var diff_count := 0
		var n: int = mini(first_pixels.size(), second_pixels.size())
		var i := 0
		while i < n:
			if first_pixels[i] != second_pixels[i]:
				diff_count += 1
			i += 4  # sample every 4th byte, cheap approximate diff
		print("saved user://%s_b.png  DIFF_SAMPLES_CHANGED=%d / %d" % [name, diff_count, n / 4])
		phase = 0
		frames = 0


func _setup_case(case_data: Dictionary) -> void:
	gm = root.get_node("/root/GameManager")
	gm.call("new_game")
	var progress: Dictionary = gm.get("progress")
	progress["current_level"] = int(case_data.get("level", 5))
	for part_id in ["objective_100mm", "eyepiece_10mm", "stable_mount", "basic_focus_knob", "basic_finder_scope", "basic_tripod", "starter_tube"]:
		if not progress["unlocked_parts"].has(part_id):
			progress["unlocked_parts"].append(part_id)
	gm.call("equip_part", "objective_100mm")
	gm.call("equip_part", "eyepiece_10mm")
	gm.call("equip_part", "basic_focus_knob")
	gm.call("equip_part", "basic_finder_scope")
	gm.call("equip_part", "basic_tripod")
	gm.call("equip_part", "starter_tube")
	gm.call("equip_part", "stable_mount")
	gm.call("reset_assembly")
	var level: Dictionary = gm.call("current_level")
	for part_type in level.get("required_parts", []):
		gm.call("install_part", str(part_type), 0)
	gm.set("selected_object_id", str(case_data.get("id", "")))
	if view != null:
		view.queue_free()
		view = null
	var scene: PackedScene = load("res://scenes/sky_observation.tscn")
	view = scene.instantiate()
	root.add_child(view)
	# Aim straight at the mission target so it's centered in frame regardless
	# of view mode (each mode's FOV differs, aim doesn't need to).
	var target_id: String = str(view.get("target_id"))
	var sky_data: Dictionary = view.get("sky_data")
	var item: Dictionary = sky_data.get(target_id, {})
	view.set("telescope_azimuth", float(item.get("azimuth", 180.0)))
	view.set("telescope_altitude", float(item.get("altitude", 45.0)))
	var desired_mode: String = str(case_data.get("mode", "telescope"))
	if desired_mode != str(view.get("view_mode")):
		view.call("_set_view_mode", desired_mode)
	view.call("_rebuild_view")
	print("case=", case_data.get("name"), " level=", case_data.get("level"),
		" mode=", case_data.get("mode"))
