extends Control

const COL_BG := Color(0.004, 0.006, 0.014)
const COL_NAVY := Color(0.030, 0.045, 0.085, 0.96)
const COL_PANEL := Color(0.050, 0.070, 0.120, 0.96)
const COL_GOLD := Color(0.78, 0.56, 0.28)
const COL_GOLD_LIGHT := Color(0.95, 0.76, 0.42)
const COL_BLUE_BORDER := Color(0.17, 0.25, 0.40)
const COL_TEXT := Color(0.96, 0.94, 0.88)
const COL_CROSSHAIR := Color(0.50, 0.70, 0.90, 0.22)

# Large pixel-art sprites shown through the eyepiece.
const SPRITE_MAP := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_large.png",
	"andromeda": "res://assets/telescope_view/andromeda_large.png"
}

# Right panel layout (1024x768): everything must stay above y = 700.
const PANEL_POS := Vector2(752, 106)
const PANEL_SIZE := Vector2(236, 594)
const CONTENT_X := 772.0
const CONTENT_W := 194.0
const FOCUS_ADJUST_SPEED := 0.22

var feedback_label: Label
var quality_label: Label
var choices_box: VBoxContainer
var observation: Dictionary
var selected_object: Dictionary

var observation_mode := "telescope"
var requires_focus := false
var allow_focus_input := true
var focus_value := 0.5
var target_focus_value := 0.5
var focus_tolerance := 0.06
var focus_error := 0.0
var focus_locked := false

var focus_slider: HSlider
var focus_state_label: Label
var focus_pct_label: Label
var updating_slider := false

var lens_center := Vector2.ZERO
var target_center := Vector2.ZERO
var main_sprite: TextureRect
var ghost_a: TextureRect
var ghost_b: TextureRect
var base_alpha := 1.0


func _ready() -> void:
	selected_object = GameManager.get_object(GameManager.selected_object_id)
	if selected_object.is_empty():
		selected_object = GameManager.current_target()
		GameManager.selected_object_id = str(selected_object.get("id", ""))
	observation_mode = GameManager.current_observation_mode()
	requires_focus = observation_mode == "telescope" and GameManager.current_requires_focus()
	allow_focus_input = _focus_knob_installed()
	if requires_focus:
		_init_focus()
	observation = _evaluate()
	_build()


func _focus_knob_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var knob: Dictionary = state.get("focus_knob", {})
	return bool(knob.get("installed", false))


func _focus_control_score() -> float:
	var stats: Dictionary = GameManager.calculate_stats()
	return float(stats.get("focus_control_score", 0.0))


func _process(delta: float) -> void:
	if not requires_focus or focus_locked or not allow_focus_input:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		direction -= 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		direction += 1.0
	if direction == 0.0:
		return
	_set_focus_value(clampf(focus_value + direction * FOCUS_ADJUST_SPEED * delta, 0.0, 1.0))


func _init_focus() -> void:
	var stage := GameManager.current_equipment_stage()
	var id := str(selected_object.get("id", ""))
	# Deterministic per target + stage: same level always needs the same focus.
	target_focus_value = 0.35 + fmod(float(absi((id + stage).hash())), 300.0) / 1000.0
	# Quantize to the slider grid so dragging can land EXACTLY on target.
	target_focus_value = snappedf(target_focus_value, 0.005)
	focus_tolerance = _tolerance_for(selected_object)
	focus_value = 0.5
	if absf(focus_value - target_focus_value) < 0.12:
		# Always start visibly out of focus so the player learns the knob.
		focus_value = fmod(focus_value + 0.27, 1.0)
	focus_error = absf(focus_value - target_focus_value)
	if not allow_focus_input:
		# No focus knob installed: the image stays clearly defocused.
		focus_error = maxf(focus_error, 0.25)


func _tolerance_for(obj: Dictionary) -> float:
	var object_type := str(obj.get("type_en", "")).to_lower()
	var id := str(obj.get("id", ""))
	if id == "moon":
		return 0.08
	if object_type.contains("planet"):
		return 0.05
	if object_type.contains("nebula") or object_type.contains("galaxy"):
		return 0.07
	return 0.06


func _evaluate() -> Dictionary:
	var context := {"observation_mode": observation_mode}
	if requires_focus:
		context["focus_error"] = focus_error
		context["requires_focus"] = true
		context["focus_tolerance"] = focus_tolerance
	return GameManager.evaluate_selected_object(context)


func _focus_state() -> String:
	# Focus state depends ONLY on focus_error vs tolerance - never on the
	# overall observation quality. Inside tolerance is always "sharp".
	if is_focus_acceptable():
		return "sharp"
	if focus_error <= focus_tolerance * 1.75:
		return "slightly_blurry"
	if focus_error <= focus_tolerance * 3.0:
		return "blurry"
	return "very_blurry"


# Single source of truth for "can this observation be identified".
# Selection + centering are enforced by Sky Observation before entering
# this scene; here the remaining gates are focus and overall quality.


func is_focus_acceptable() -> bool:
	if not requires_focus:
		return true
	if not allow_focus_input:
		return false
	return focus_error <= focus_tolerance


func is_quality_acceptable() -> bool:
	return bool(observation.get("success", false))


func can_identify_object() -> bool:
	return is_focus_acceptable() and is_quality_acceptable()


func _quality_shortfall_text() -> String:
	# Focus is fine; the telescope itself is the limit. Deep-sky targets get
	# a specific hint about aperture/stability.
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	if type_lower.contains("nebula") or type_lower.contains("galaxy"):
		return GameManager.text(
			"Focus aligned, but deep-sky image is still too faint. Improve aperture/stability.",
			"焦点已对准，但深空图像仍太暗。需要更大口径或更高稳定性。"
		)
	return GameManager.text(
		"Focus aligned, but telescope quality is still too low.",
		"焦点已对准，但望远镜性能仍不足。"
	)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(self, Vector2.ZERO, Vector2(1024, 768), COL_BG)
	_pixel_frame(self, Vector2(12, 10), Vector2(1000, 744), Color(0.006, 0.008, 0.018), COL_BLUE_BORDER, COL_GOLD)
	if observation_mode == "naked_eye":
		_title_bar(GameManager.text("Naked Eye Observation", "肉眼观测"))
	else:
		_title_bar("Telescope View")

	var view := _scope_visual()
	view.position = Vector2(54, 98)
	add_child(view)
	_build_observation_panel()
	if requires_focus:
		_refresh_focus_ui()


func _title_bar(title_text: String) -> void:
	_pixel_panel(self, Vector2(28, 20), Vector2(968, 60), COL_NAVY, COL_BLUE_BORDER)
	var title := _plabel(title_text, Vector2(28, 24), Vector2(968, 44), 26, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF


# ------------------------------------------------------------- right panel


func _build_observation_panel() -> void:
	_gold_panel(self, PANEL_POS, PANEL_SIZE)
	var quality := str(observation.get("quality", "Unknown"))

	var header := _plabel("Observation Quality", Vector2(CONTENT_X - 4, 118), Vector2(CONTENT_W + 8, 30), 19, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF

	var mystery := _mystery_description(selected_object)
	var observed := _plabel(
		GameManager.text("Observed: " + str(mystery.get("en", "")), "观测到：" + str(mystery.get("zh", ""))),
		Vector2(CONTENT_X, 156), Vector2(CONTENT_W, 40), 11, COL_TEXT
	)
	observed.max_lines_visible = 2

	quality_label = _plabel("Quality: " + quality, Vector2(CONTENT_X, 200), Vector2(CONTENT_W, 24), 16, _quality_color(quality))

	if observation_mode == "naked_eye":
		_plabel(GameManager.text("Equipment: Naked Eye", "装备：肉眼"), Vector2(CONTENT_X, 232), Vector2(CONTENT_W, 40), 13, COL_GOLD_LIGHT)
	else:
		_add_stat_bars()

	feedback_label = _plabel(_current_feedback(), Vector2(CONTENT_X, 298), Vector2(CONTENT_W, 48), 10, Color(0.86, 0.90, 0.88))
	feedback_label.max_lines_visible = 3

	if requires_focus:
		_build_focus_block()

	_plabel("Identify", Vector2(CONTENT_X, 414), Vector2(CONTENT_W, 20), 16, Color(0.98, 0.82, 0.50))

	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(CONTENT_X, 436)
	choices_box.size = Vector2(CONTENT_W, 146)
	choices_box.add_theme_constant_override("separation", 6)
	add_child(choices_box)
	_add_identify_choices()

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(CONTENT_X, 600)
	bottom.size = Vector2(CONTENT_W, 38)
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)

	var retry := _pixel_button("Retry", Vector2(92, 38), 14)
	retry.pressed.connect(func() -> void: GameManager.go("sky"))
	bottom.add_child(retry)

	var back := _pixel_button("Back", Vector2(92, 38), 14)
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	bottom.add_child(back)


func _build_focus_block() -> void:
	if not allow_focus_input:
		_plabel("Focus", Vector2(CONTENT_X, 348), Vector2(70, 18), 13, COL_GOLD_LIGHT)
		var missing := _plabel(GameManager.text("Knob: not installed", "旋钮：未安装"), Vector2(CONTENT_X + 60, 346), Vector2(CONTENT_W - 60, 26), 9, Color(1.0, 0.45, 0.32), HORIZONTAL_ALIGNMENT_RIGHT)
		missing.max_lines_visible = 2
		focus_state_label = _plabel(
			GameManager.text("Install it at the Assembly Table.", "请回组装台安装调焦旋钮。"),
			Vector2(CONTENT_X, 378), Vector2(CONTENT_W, 32), 9, Color(1.0, 0.62, 0.40)
		)
		focus_state_label.max_lines_visible = 3
		return

	_plabel("Focus · Ctrl %d%%" % int(_focus_control_score()), Vector2(CONTENT_X, 350), Vector2(126, 18), 11, COL_GOLD_LIGHT)
	focus_pct_label = _plabel("", Vector2(CONTENT_X + 126, 351), Vector2(CONTENT_W - 126, 18), 11, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	focus_slider = HSlider.new()
	focus_slider.min_value = 0.0
	focus_slider.max_value = 1.0
	# A better focus knob gives finer slider control.
	focus_slider.step = 0.005 if _focus_control_score() >= 60.0 else 0.015
	focus_slider.value = focus_value
	focus_slider.position = Vector2(CONTENT_X, 370)
	focus_slider.size = Vector2(CONTENT_W, 18)
	focus_slider.value_changed.connect(func(value: float) -> void:
		if not updating_slider:
			_set_focus_value(value)
	)
	add_child(focus_slider)

	focus_state_label = _plabel("", Vector2(CONTENT_X, 388), Vector2(CONTENT_W, 24), 9, COL_TEXT)
	focus_state_label.max_lines_visible = 2


func _set_focus_value(value: float) -> void:
	focus_value = clampf(value, 0.0, 1.0)
	focus_error = absf(focus_value - target_focus_value)
	observation = _evaluate()
	_refresh_focus_ui()


func _refresh_focus_ui() -> void:
	if focus_slider != null:
		updating_slider = true
		focus_slider.value = focus_value
		updating_slider = false
	if focus_pct_label != null:
		focus_pct_label.text = "%d%%  (Q/E)" % int(round(focus_value * 100.0))
	if focus_state_label != null and allow_focus_input:
		var state := _focus_state()
		match state:
			"sharp":
				# Sharp focus alone is not permission to identify - the
				# overall quality must also pass.
				if is_quality_acceptable():
					focus_state_label.text = GameManager.text("Image clear enough. Ready to identify.", "图像已足够清晰，可以识别。")
					focus_state_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
				else:
					focus_state_label.text = _quality_shortfall_text()
					focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			"slightly_blurry":
				focus_state_label.text = GameManager.text("Slightly blurry.", "略有模糊。")
				focus_state_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
			"blurry":
				focus_state_label.text = GameManager.text("Blurry. Keep adjusting.", "模糊，继续调整。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			_:
				focus_state_label.text = GameManager.text("Very blurry. Turn the focus knob.", "非常模糊，请转动调焦旋钮。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.30))
	var quality := str(observation.get("quality", "Unknown"))
	if quality_label != null:
		quality_label.text = "Quality: " + quality
		quality_label.add_theme_color_override("font_color", _quality_color(quality))
	if feedback_label != null:
		feedback_label.text = _current_feedback()
	_update_target_visuals()


func _current_feedback() -> String:
	if requires_focus and not allow_focus_input:
		return GameManager.text(
			"A focus knob is required. Return to the Assembly Table and install it near the eyepiece.",
			"需要调焦旋钮。请回到组装台，把它安装在目镜附近。"
		)
	if not is_focus_acceptable():
		return GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
	if requires_focus and not is_quality_acceptable():
		# The feedback box has room for a concrete next step.
		var type_lower := str(selected_object.get("type_en", "")).to_lower()
		if type_lower.contains("nebula") or type_lower.contains("galaxy"):
			return GameManager.text(
				"Focus aligned, but the image is too faint. Equip a bigger lens / stable mount at the Parts Cabinet, then reassemble.",
				"焦点已对准，但图像太暗。请到零件柜换装大口径物镜和稳定支架，再重新组装。"
			)
		return _quality_shortfall_text()
	if requires_focus and can_identify_object():
		return GameManager.text("Image clear enough. Ready to identify.", "图像已足够清晰，可以识别。")
	return _short_feedback(str(observation.get("quality", "Unknown")))


func _add_stat_bars() -> void:
	var stats := GameManager.calculate_stats()
	var rows: Array = [
		{"name": "Light", "value": float(stats.get("light_score", 0.0))},
		{"name": "Clarity", "value": float(stats.get("clarity_score", 0.0))},
		{"name": "Stability", "value": float(stats.get("stability_score", 0.0))}
	]
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var value: float = float(row.get("value", 0.0))
		var y := 228.0 + float(index) * 22.0
		_plabel("%s %s" % [str(row.get("name", "")), snapped(value, 0.1)], Vector2(CONTENT_X, y), Vector2(96, 16), 11, Color(0.78, 0.86, 0.90))
		_rect(self, Vector2(CONTENT_X + 100, y + 4), Vector2(94, 8), Color(0.10, 0.14, 0.22))
		var fill_width := clampf(value, 0.0, 100.0) * 0.94
		_rect(self, Vector2(CONTENT_X + 100, y + 4), Vector2(fill_width, 8), Color(0.45, 0.75, 0.50))


func _short_feedback(quality: String) -> String:
	if observation_mode == "naked_eye":
		return GameManager.text(str(observation.get("feedback_en", "")), str(observation.get("feedback_zh", "")))
	match quality:
		"Excellent":
			return GameManager.text("Clear image. Ready to identify.", "图像清晰，可以识别目标。")
		"Good":
			return GameManager.text("Stable enough to identify.", "足够稳定，可以识别目标。")
		"Fair":
			return GameManager.text("Visible, but slightly unclear.", "可以看到目标，但略有不清。")
		"Poor":
			return GameManager.text("Too blurry. Improve alignment.", "太模糊了，请改进安装对齐。")
		"Failed":
			return GameManager.text("Observation failed. Reassemble or retry.", "观测失败，请重新组装或重试。")
	return GameManager.text("Observation complete.", "观测完成。")


func _add_identify_choices() -> void:
	var ids: Array[String] = []
	_add_unique(ids, str(selected_object.get("id", "")))
	_add_unique(ids, str(GameManager.current_target().get("id", "")))
	for id in _distractors_for(str(selected_object.get("id", ""))):
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	for id in ["sirius", "betelgeuse", "jupiter", "polaris"]:
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	if ids.size() > 4:
		ids.resize(4)
	for id in ids:
		var obj := GameManager.get_object(id)
		if obj.is_empty():
			continue
		# Single line "Moon · 月球" keeps buttons at 32 px in bilingual mode.
		var button := _pixel_button(GameManager.dict_text(obj, "name").replace("\n", " · "), Vector2(CONTENT_W, 32), 12)
		button.clip_text = true
		button.pressed.connect(_identify.bind(id))
		choices_box.add_child(button)


func _identify(choice_id: String) -> void:
	if requires_focus and not allow_focus_input:
		feedback_label.text = GameManager.text(
			"Install the Focus Knob before trying to identify this target.",
			"请先安装调焦旋钮，再尝试识别这个目标。"
		)
		return
	if not is_focus_acceptable():
		feedback_label.text = GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
		return
	if choice_id != str(selected_object.get("id", "")):
		feedback_label.text = GameManager.text("Not what you observed. Try again.", "与观测到的目标不符，再试一次。")
		return
	if not is_quality_acceptable():
		# Correct answer, but the observation itself is not good enough:
		# the mission must not complete.
		if requires_focus:
			feedback_label.text = _quality_shortfall_text()
		else:
			feedback_label.text = GameManager.text(
				"Identified, but the observation quality is too low.",
				"识别正确，但观测质量不足。"
			)
		return
	# On success GameManager routes to the Mission Complete card itself.
	var completed := GameManager.complete_current_mission(choice_id, observation)
	if completed:
		return
	var target := GameManager.current_target()
	if choice_id != str(target.get("id", "")):
		feedback_label.text = GameManager.text("Correct, but not the mission target.", "识别正确，但不是当前任务目标。")
	else:
		feedback_label.text = GameManager.text("Identified, but quality is too low.", "识别正确，但观测质量不足。")


# ------------------------------------------------------------- scope visual


func _scope_visual() -> Control:
	var root := Control.new()
	root.size = Vector2(640, 620)
	var center := Vector2(318, 300)
	lens_center = center
	if observation_mode == "naked_eye":
		# Open night sky, no telescope barrel.
		_circle(root, center - Vector2(262, 262), Vector2(524, 524), Color(0.006, 0.012, 0.032), Color(0.10, 0.14, 0.26), 3)
	else:
		_circle(root, center - Vector2(270, 270), Vector2(540, 540), Color(0.05, 0.036, 0.026), COL_GOLD_LIGHT, 8)
		_circle(root, center - Vector2(252, 252), Vector2(504, 504), Color(0.012, 0.018, 0.052), Color(0.31, 0.23, 0.15), 6)
		_circle(root, center - Vector2(218, 218), Vector2(436, 436), Color(0.0, 0.0, 0.0), Color(0.06, 0.08, 0.15), 5)
	_add_scope_stars(root, center)
	_add_target_visual(root, center)
	if observation_mode != "naked_eye":
		_add_crosshair(root, center)
	_add_quality_noise(root, center)
	return root


func _add_crosshair(parent: Control, center: Vector2) -> void:
	# Thin reticle lines with a wide gap so the target stays unobstructed.
	_rect(parent, center + Vector2(-170, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(55, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, -170), Vector2(2, 115), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, 55), Vector2(2, 115), COL_CROSSHAIR)


func _add_target_visual(parent: Control, scope_center: Vector2) -> void:
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = scope_center + _effect_offset(effect, quality)
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif effect == "dim":
		base_alpha *= 0.55

	var path: String = SPRITE_MAP.get(id, SPRITE_MAP["polaris"])
	var texture: Texture2D = load(path)
	var sprite_scale := 1.0
	if observation_mode == "naked_eye":
		sprite_scale = _naked_eye_scale(id)

	ghost_a = _add_sprite(parent, texture, target_center, 0.0, sprite_scale)
	ghost_b = _add_sprite(parent, texture, target_center, 0.0, sprite_scale)
	main_sprite = _add_sprite(parent, texture, target_center, base_alpha, sprite_scale)
	if effect == "dim" and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, base_alpha)
	if effect == "shaky":
		ghost_a.modulate.a = base_alpha * 0.30
		ghost_a.position += Vector2(-9, 5)
	_update_target_visuals()


func _naked_eye_alpha() -> float:
	# What your eyes can actually see: bright targets clear, deep sky ~gone.
	var visible := bool(selected_object.get("naked_eye_visible", false))
	if not visible:
		return 0.06
	var brightness := float(selected_object.get("brightness", 50.0))
	return clampf(0.35 + brightness / 130.0, 0.35, 1.0)


func _naked_eye_scale(id: String) -> float:
	# No magnification: the Moon is small, planets are just points of light.
	match id:
		"moon":
			return 0.55
		"mars", "jupiter":
			return 0.28
		"orion_nebula", "andromeda":
			return 0.45
	return 0.55


func _update_target_visuals() -> void:
	if main_sprite == null:
		return
	if not requires_focus:
		return
	# Defocus: the main image fades and two ghost copies drift apart.
	var spread := focus_error * 130.0
	var ghost_alpha := clampf(focus_error * 2.6, 0.0, 0.55) * base_alpha
	var main_alpha := base_alpha * clampf(1.0 - focus_error * 1.1, 0.30, 1.0)
	var size: Vector2 = main_sprite.size
	main_sprite.modulate.a = main_alpha
	main_sprite.position = target_center - size * 0.5
	ghost_a.modulate.a = ghost_alpha
	ghost_a.position = target_center - size * 0.5 + Vector2(spread, spread * 0.6)
	ghost_b.modulate.a = ghost_alpha * 0.8
	ghost_b.position = target_center - size * 0.5 + Vector2(-spread * 0.8, spread * 0.4)


func _add_sprite(parent: Control, texture: Texture2D, center: Vector2, alpha: float, sprite_scale: float = 1.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = texture.get_size()
	icon.scale = Vector2.ONE * sprite_scale
	icon.position = center - icon.size * sprite_scale * 0.5
	icon.modulate = Color(1, 1, 1, alpha)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _add_scope_stars(parent: Control, scope_center: Vector2) -> void:
	for i in range(34):
		var pos := scope_center + Vector2(-178 + fmod(float(i * 83), 355.0), -178 + fmod(float(i * 47), 350.0))
		if (pos - scope_center).length() > 205:
			continue
		var bright := 0.50 + fmod(float(i), 5.0) * 0.08
		_rect(parent, pos, Vector2(2, 2), Color(bright, bright + 0.03, 0.92, 0.50))


func _add_quality_noise(parent: Control, scope_center: Vector2) -> void:
	var quality := str(observation.get("quality", "Unknown"))
	var count := 0
	if quality == "Fair":
		count = 18
	elif quality == "Poor":
		count = 42
	elif quality == "Failed":
		count = 76
	for i in range(count):
		var pos := scope_center + Vector2(-194 + fmod(float(i * 71), 390.0), -190 + fmod(float(i * 43), 382.0))
		if (pos - scope_center).length() <= 208:
			_rect(parent, pos, Vector2(3, 3), Color(0.70, 0.78, 0.88, 0.08 + fmod(float(i), 4.0) * 0.02))


# ------------------------------------------------------------------- logic


func _distractors_for(id: String) -> Array[String]:
	match id:
		"moon": return ["jupiter", "sirius"]
		"mars": return ["jupiter", "betelgeuse"]
		"jupiter": return ["mars", "moon"]
		"orion_nebula": return ["andromeda", "betelgeuse"]
		"andromeda": return ["orion_nebula", "sirius"]
	return ["sirius", "betelgeuse"]


func _mystery_description(obj: Dictionary) -> Dictionary:
	var id := str(obj.get("id", ""))
	match id:
		"moon":
			return {"en": "bright round object", "zh": "明亮圆形目标"}
		"mars", "jupiter":
			return {"en": "small disk-like object", "zh": "小圆盘状目标"}
		"orion_nebula":
			return {"en": "faint cloud-like object", "zh": "淡淡云雾状目标"}
		"andromeda":
			return {"en": "faint oval glow", "zh": "淡淡椭圆光斑"}
	return {"en": "star-like object", "zh": "星点状目标"}


func _effect_offset(effect: String, quality: String) -> Vector2:
	if effect == "shaky":
		return Vector2(10, -7)
	match quality:
		"Fair":
			return Vector2(6, -4)
		"Poor":
			return Vector2(12, 8)
	return Vector2.ZERO


func _quality_alpha(quality: String) -> float:
	match quality:
		"Excellent": return 1.0
		"Good": return 0.92
		"Fair": return 0.62
		"Poor": return 0.36
		"Failed": return 0.14
	return 0.80


func _quality_color(quality: String) -> Color:
	match quality:
		"Excellent": return Color(0.35, 1.0, 0.55)
		"Good": return Color(0.58, 0.92, 0.36)
		"Fair": return Color(0.95, 0.82, 0.28)
		"Poor": return Color(1.0, 0.55, 0.28)
		"Failed": return Color(1.0, 0.24, 0.24)
	return COL_TEXT


func _add_unique(ids: Array[String], id: String) -> void:
	if id != "" and not ids.has(id):
		ids.append(id)


# ----------------------------------------------------------------- helpers


func _pixel_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 3, false)


func _gold_panel(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	return _styled_panel(parent, pos, size, COL_PANEL, COL_GOLD, 3, 3, true)


func _pixel_frame(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, corner: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 4, true, corner)


func _styled_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, border_width: int, radius: int, decorated: bool, corner_color: Color = COL_GOLD) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	if decorated:
		_corner(parent, pos, corner_color)
		_corner(parent, pos + Vector2(size.x - 14, 0), corner_color)
		_corner(parent, pos + Vector2(0, size.y - 14), corner_color)
		_corner(parent, pos + size - Vector2(14, 14), corner_color)
	return panel


func _corner(parent: Control, pos: Vector2, color: Color) -> void:
	_rect(parent, pos, Vector2(12, 4), color)
	_rect(parent, pos, Vector2(4, 12), color)


func _pixel_button(text: String, min_size: Vector2 = Vector2(194, 32), font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.15, 0.25), COL_BLUE_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.23, 0.34), COL_GOLD_LIGHT))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.15, 0.08), COL_GOLD_LIGHT))
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _circle(parent: Control, pos: Vector2, size: Vector2, color: Color, border: Color, border_width: int) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(max(size.x, size.y) * 0.5))
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _plabel(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	# autowrap BEFORE size, otherwise the text's minimum width clamps the
	# label wider than the panel.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
