extends SceneTree

# Verifies the E2 drift/tracking effects (Earth-drift centering + tracking
# mount) render and animate. In-memory level/progress overrides only -
# nothing meaningful is written to the savegame (new_game() resets first).
# Run WITHOUT --headless:
# godot --script res://tools/capture_effects_e2.gd

var gm: Node
var frames := 0
var phase := 0
var case_index := -1
var view: Node
var first_offset := Vector2.ZERO
var second_offset := Vector2.ZERO

const CASES := [
	{"level": 22, "id": "sirius", "name": "effects_L22_drift", "equip_tracking": false, "tracking_rate": 0.0},
	{"level": 23, "id": "jupiter", "name": "effects_L23_tracking_1x", "equip_tracking": true, "tracking_rate": 1.0}
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
	if phase == 1 and frames >= 20:
		# Settle a beat, then record the first frame's drifted position.
		first_offset = view.get("visual_target_center")
		var name: String = str(CASES[case_index].get("name", "case"))
		root.get_texture().get_image().save_png("user://%s_a.png" % name)
		print("saved user://%s_a.png" % name,
			"  visual_target_center=", first_offset,
			"  drift_offset=", view.get("drift_offset"),
			"  hold_timer=", view.get("hold_timer"))
		phase = 2
		frames = 0
		return
	if phase == 2 and frames >= 90:
		# ~1.5s later at 60fps.
		second_offset = view.get("visual_target_center")
		var name: String = str(CASES[case_index].get("name", "case"))
		root.get_texture().get_image().save_png("user://%s_b.png" % name)
		var delta: Vector2 = second_offset - first_offset
		print("saved user://%s_b.png" % name,
			"  visual_target_center=", second_offset,
			"  drift_offset=", view.get("drift_offset"),
			"  hold_timer=", view.get("hold_timer"),
			"  DELTA=", delta,
			"  DELTA_LEN=", delta.length())
		view.queue_free()
		view = null
		phase = 0
		frames = 0


func _setup_case(case_data: Dictionary) -> void:
	gm = root.get_node("/root/GameManager")
	gm.call("new_game")
	var progress: Dictionary = gm.get("progress")
	progress["current_level"] = int(case_data.get("level", 22))
	# Unlock + equip best gear so the telescope is ready and focus is
	# achievable; equip tracking_mount when the case calls for it.
	for part_id in ["objective_100mm", "eyepiece_10mm", "stable_mount", "basic_focus_knob", "basic_finder_scope", "basic_tripod", "starter_tube", "tracking_mount"]:
		if not progress["unlocked_parts"].has(part_id):
			progress["unlocked_parts"].append(part_id)
	gm.call("equip_part", "objective_100mm")
	gm.call("equip_part", "eyepiece_10mm")
	gm.call("equip_part", "basic_focus_knob")
	gm.call("equip_part", "basic_finder_scope")
	gm.call("equip_part", "basic_tripod")
	gm.call("equip_part", "starter_tube")
	if bool(case_data.get("equip_tracking", false)):
		gm.call("equip_part", "tracking_mount")
	else:
		gm.call("equip_part", "stable_mount")
	gm.call("set_tracking_rate", float(case_data.get("tracking_rate", 0.0)))
	gm.call("reset_assembly")
	var level: Dictionary = gm.call("current_level")
	for part_type in level.get("required_parts", []):
		gm.call("install_part", str(part_type), 0)
	gm.set("selected_object_id", str(case_data.get("id", "")))
	print("case=", case_data.get("name"), " telescope_ready=", gm.call("telescope_is_ready"),
		" tracking_equipped=", gm.call("has_tracking_mount_equipped"),
		" tracking_rate=", gm.call("tracking_rate"))
	var scene: PackedScene = load("res://scenes/telescope_view.tscn")
	view = scene.instantiate()
	root.add_child(view)
	# Bring focus to sharp immediately so quality/hold isn't blocked by
	# defocus while we measure drift motion.
	var target_focus: float = float(view.get("target_focus_value"))
	view.call("_set_focus_value", target_focus)
