extends SceneTree

# Space Infrared Observatory (JWST-class) + FAST asset and data integrity.
#   1. Every space/FAST part has a real, loadable, transparent, single-subject icon.
#   2. No part is left as a placeholder, and none reuses refractor/newtonian
#      eyepiece / objective / focuser / finder / tripod logic.
#   3. Part art is uncropped: the drawing never touches the sprite border.
#   4. unlock_level respects the family floors, so no gear leaks early.
#   5. Every assembly blueprint board exists and is loadable.
#   6. The art manifest covers every shipped asset and marks temporary art.
#   7. Bilingual names/descriptions exist with no language bleed or mojibake.
#   8. The original families and L1-L24 part data are untouched.

const SPACE_DIR := "res://assets/telescope_parts/space_segmented/"
const FAST_DIR := "res://assets/telescope_parts/fast_radio/"
const MANIFEST := "res://data/art_manifest.json"
const BANNED_TYPES := ["eyepiece", "objective", "focus_knob", "finder_scope", "tripod"]
const BLUEPRINTS := [
	"res://assets/assembly/space_main_blueprint.png",
	"res://assets/assembly/space_mirror_blueprint.png",
	"res://assets/assembly/space_instrument_blueprint.png",
	"res://assets/assembly/space_thermal_blueprint.png",
	"res://assets/assembly/fast_main_blueprint.png",
	"res://assets/assembly/fast_feed_blueprint.png",
	"res://assets/assembly/fast_signal_blueprint.png",
]
const FAMILY_FLOOR := {"space_segmented": 65, "fast_radio": 75}
# Instruments the JWST teaching chain and mission planner rely on.
const REQUIRED_INSTRUMENTS := ["space_nircam", "space_nirspec", "space_miri", "space_fgs_niriss"]

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("SPACE/FAST ASSET TEST FAIL: GameManager missing")
		quit(1)
		return
	gm.new_game()

	var space: Array = []
	var fast: Array = []
	for part_value in gm.parts_data:
		var part: Dictionary = part_value
		match str(part.get("telescope_family", "")):
			"space_segmented": space.append(part)
			"fast_radio": fast.append(part)

	_check(space.size() >= 18, "1. space observatory has its full part set (%d)" % space.size())
	_check(fast.size() >= 14, "1. FAST has its full part set (%d)" % fast.size())

	_verify_family(space, "space", SPACE_DIR)
	_verify_family(fast, "FAST", FAST_DIR)

	# 4. no early leak
	for part_value in space + fast:
		var part: Dictionary = part_value
		var family := str(part.get("telescope_family", ""))
		var floor_level: int = int(FAMILY_FLOOR[family])
		_check(int(part.get("unlock_level", 0)) >= floor_level,
			"4. %s unlocks at or after L%d (%d)" % [str(part.get("id", "")), floor_level, int(part.get("unlock_level", 0))])

	# 5. blueprints
	for path in BLUEPRINTS:
		_check(ResourceLoader.exists(path), "5. blueprint exists: %s" % path.get_file())
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			_check(tex != null and tex.get_size().x >= 600.0,
				"5. blueprint is a usable board: %s %s" % [path.get_file(), str(tex.get_size()) if tex else "null"])

	# 6. manifest
	_verify_manifest(space, fast)

	# 7. instruments each have their own id, slot type and icon
	var seen_types := {}
	for pid in REQUIRED_INSTRUMENTS:
		var part: Dictionary = gm.get_part(pid)
		_check(not part.is_empty(), "7. instrument '%s' exists" % pid)
		if part.is_empty():
			continue
		var ptype := str(part.get("type", ""))
		_check(not seen_types.has(ptype), "7. instrument '%s' has its own slot type '%s'" % [pid, ptype])
		seen_types[ptype] = true
		_check(str(part.get("band", "")) != "", "7. instrument '%s' declares an infrared band" % pid)

	# 8. legacy families untouched
	_verify_legacy(gm)

	print("SPACE/FAST ASSET TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _verify_family(parts: Array, label: String, dir_prefix: String) -> void:
	for part_value in parts:
		var part: Dictionary = part_value
		var pid := str(part.get("id", ""))
		var icon := str(part.get("icon_path", ""))

		_check(icon.begins_with(dir_prefix), "1. %s '%s' icon lives in its family folder" % [label, pid])
		_check(ResourceLoader.exists(icon), "1. %s '%s' icon exists: %s" % [label, pid, icon.get_file()])
		if not ResourceLoader.exists(icon):
			continue
		var tex := load(icon) as Texture2D
		_check(tex != null, "1. %s '%s' icon loads" % [label, pid])
		if tex == null:
			continue
		var image := tex.get_image()
		_check(image.get_width() == 500 and image.get_height() == 500,
			"1. %s '%s' is 500x500 (%dx%d)" % [label, pid, image.get_width(), image.get_height()])
		_check(image.detect_alpha() != Image.ALPHA_NONE,
			"1. %s '%s' has a transparent background" % [label, pid])

		# 2. not a placeholder, no borrowed optical type
		_check(not bool(part.get("is_placeholder", false)), "2. %s '%s' is not a placeholder" % [label, pid])
		_check(not BANNED_TYPES.has(str(part.get("type", ""))),
			"2. %s '%s' does not reuse eyepiece/objective/focuser/finder/tripod logic" % [label, pid])

		# 3. uncropped + no opaque frame: the art must not touch the border
		var bounds := image.get_used_rect()
		_check(bounds.position.x > 0 and bounds.position.y > 0
			and bounds.end.x < image.get_width() and bounds.end.y < image.get_height(),
			"3. %s '%s' art is fully inside the sprite (bbox %s)" % [label, pid, str(bounds)])
		# corners must be clear -> no checkerboard, no black plate, no white edge
		var clear := true
		for corner in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0),
				Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			if image.get_pixelv(corner).a > 0.02:
				clear = false
		_check(clear, "3. %s '%s' corners are transparent (no plate or checkerboard)" % [label, pid])

		# 7. bilingual, no bleed
		var en := str(part.get("name_en", ""))
		var zh := str(part.get("name_zh", ""))
		_check(en != "" and not _has_cjk(en), "7. %s '%s' English name is English-only" % [label, pid])
		_check(zh != "" and _has_cjk(zh), "7. %s '%s' has a real Chinese name" % [label, pid])
		_check(not _is_mojibake(zh), "7. %s '%s' Chinese name is not mojibake" % [label, pid])
		_check(str(part.get("description_en", "")) != "" and str(part.get("description_zh", "")) != "",
			"7. %s '%s' has bilingual descriptions" % [label, pid])


func _verify_manifest(space: Array, fast: Array) -> void:
	_check(ResourceLoader.exists(MANIFEST) or FileAccess.file_exists(MANIFEST),
		"6. art manifest exists")
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		_check(false, "6. art manifest is readable")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "6. art manifest is valid JSON")
		return
	var data: Dictionary = parsed
	var assets: Array = data.get("assets", [])
	_check(assets.size() >= 39, "6. manifest lists every generated asset (%d)" % assets.size())
	_check(str(data.get("how_to_replace", "")) != "", "6. manifest explains how to swap in final art")

	var listed := {}
	for entry_value in assets:
		var entry: Dictionary = entry_value
		listed[str(entry.get("res_path", ""))] = entry
		_check(entry.has("temporary_art"), "6. manifest entry '%s' declares temporary_art" % str(entry.get("name", "")))
		_check(int((entry.get("size", [0, 0]) as Array)[0]) > 0, "6. manifest entry '%s' records its size" % str(entry.get("name", "")))
	for part_value in space + fast:
		var part: Dictionary = part_value
		_check(listed.has(str(part.get("icon_path", ""))),
			"6. manifest covers '%s'" % str(part.get("id", "")))


func _verify_legacy(gm: Node) -> void:
	# L1-L24 and the three ground optical families must be untouched.
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	if mm != null:
		_check(str(mm.get_level(2).get("required_concept_card", "")) == "naked_eye_limits",
			"8. L2 mainline data untouched")
		_check(int(mm.get_max_level()) >= 131, "8. campaign length unchanged (%d)" % int(mm.get_max_level()))
	for pid in ["basic_tripod", "objective_60mm", "eyepiece_20mm", "basic_finder_scope"]:
		var part: Dictionary = gm.get_part(pid)
		_check(not part.is_empty(), "8. refractor part '%s' still present" % pid)
	for family in ["newtonian", "dobsonian", "cassegrain"]:
		var count := 0
		for part_value in gm.parts_data:
			if str((part_value as Dictionary).get("telescope_family", "")) == family:
				count += 1
		_check(count >= 9, "8. %s family still has its parts (%d)" % [family, count])


func _has_cjk(text: String) -> bool:
	for c in text:
		if c >= "一" and c <= "鿿":
			return true
	return false


func _is_mojibake(text: String) -> bool:
	for garbage in ["瑁呴厤", "鎻愮ず", "鐗涢", "锛�", "鈥�", "�"]:
		if text.contains(garbage):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
