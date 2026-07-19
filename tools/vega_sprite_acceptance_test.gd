extends SceneTree

const OUTPUT_DIR := "res://artifacts/vega_sprite_acceptance"
const TEXTURES := {
	"clear": "res://assets/telescope_view/vega_user_clear.png",
	"blurry": "res://assets/telescope_view/vega_user_blurry.png",
	"dim": "res://assets/telescope_view/vega_user_dim.png"
}

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	for state in TEXTURES:
		_validate_texture(str(state), str(TEXTURES[state]))

	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(25, true)
	gm.selected_object_id = "vega"
	await _open_view()
	_check(str(view.get("current_sprite_path")) in [TEXTURES.clear, TEXTURES.blurry, TEXTURES.dim], "L25 uses the imported Vega state textures")
	var target := float(view.get("target_focus_value"))
	var tolerance := float(view.get("focus_tolerance"))
	view.call("_set_focus_value", target)
	await _settle()
	await _capture("l25_refractor_vega_focused.png")
	view.call("_set_focus_value", clampf(target + tolerance * 2.2, 0.0, 1.0))
	await _settle()
	await _capture("l25_refractor_vega_defocused.png")

	view.queue_free()
	await process_frame
	gm.debug_jump_to_level(27, true)
	gm.selected_object_id = "vega"
	await _open_view()
	view.call("_set_focus_value", view.get("target_focus_value"))
	await _settle()
	_check(not bool(gm.current_level().get("chromatic_aberration", false)), "L27 Newtonian view does not add refractor color fringe")
	await _capture("l27_newtonian_vega_focused.png")

	if failures == 0:
		print("VEGA SPRITE ACCEPTANCE TEST PASS")
		quit(0)
	else:
		print("VEGA SPRITE ACCEPTANCE TEST FAIL: ", failures)
		quit(1)


func _open_view() -> void:
	view = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await _settle()
	view.call("_dismiss_pre_quiz_guide")
	await process_frame


func _validate_texture(state: String, path: String) -> void:
	_check(ResourceLoader.exists(path), "%s file exists" % state)
	var texture := load(path) as Texture2D
	_check(texture != null, "%s loads as Texture2D" % state)
	if texture == null:
		return
	_check(texture.get_size() == Vector2(256, 256), "%s is 256x256" % state)
	var image := texture.get_image()
	_check(image.get_pixel(0, 0).a <= 0.02, "%s has a transparent corner" % state)
	_check(image.get_pixel(128, 128).a >= 0.5, "%s keeps an opaque star center" % state)


func _settle() -> void:
	for frame in range(24):
		await process_frame


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	_check(root.get_texture().get_image().save_png(output_path) == OK, "saved " + file_name)
	print("CAPTURE ", output_path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
