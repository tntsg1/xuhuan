extends Control

# Mode-driven learning card scene.
# - brief: concept preview before the player starts a key action.
# - complete: mission result recap after the player succeeds.

const GOLD := Color(0.96, 0.90, 0.58)
const TEXT := Color(0.92, 0.93, 0.90)
const MUTED := Color(0.72, 0.80, 0.88)
const GREEN := Color(0.72, 0.94, 0.68)
const BG := Color(0.050, 0.060, 0.090)
const PANEL_BG := Color(0.035, 0.050, 0.085, 0.96)
const BORDER := Color(0.78, 0.56, 0.28)
const PAPER_INK := Color(0.19, 0.13, 0.07)
const PAPER_MUTED := Color(0.39, 0.30, 0.18)
const PAPER_LINE := Color(0.55, 0.39, 0.20, 0.55)
const PAPER_BOX := Color(0.93, 0.82, 0.58, 0.54)
const DEEP_BLUE := Color(0.02, 0.04, 0.075, 0.92)

const MISSION_BG := "res://assets/mission_complete/bg_room.png"
const MISSION_PARCHMENT := "res://assets/mission_complete/parchment_card.png"
const MISSION_JOURNAL := "res://assets/mission_complete/journal_book_64_clean.png"
const MISSION_BADGE := "res://assets/mission_complete/badge_shield_64_clean.png"
const MISSION_CREDIT := "res://assets/mission_complete/credit_coin_64_clean.png"


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)

	var mode: String = GameManager.current_learning_card_mode()
	if mode == "brief":
		_build_concept_brief(GameManager.current_brief_card())
	elif mode == "complete" or not GameManager.last_learning_card.is_empty():
		TeachingFlowManager.acknowledge_card_shown()
		_build_mission_complete(GameManager.last_learning_card)
	else:
		GameManager.call_deferred("go", "observatory")


func _build_concept_brief(card: Dictionary) -> void:
	_label("Concept Brief", Vector2(0, 18), Vector2(1024, 42), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label("Before you start, learn the idea you are about to use.", Vector2(0, 62), Vector2(1024, 24), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_panel(Vector2(92, 104), Vector2(840, 560))
	_label(GameManager.dict_text(card, "title"), Vector2(150, 114), Vector2(724, 28), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_diagram(str(card.get("image", "")), Vector2(152, 142), Vector2(720, 405))

	var body: Label = _label(
		GameManager.dict_text(card, "text"),
		Vector2(150, 562),
		Vector2(724, 72),
		15,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	body.max_lines_visible = 3

	var start: Button = _button(GameManager.text("Start", "开始"), Vector2(382, 686), Vector2(260, 48))
	start.pressed.connect(func() -> void:
		GameManager.complete_current_brief()
	)


func _build_mission_complete(data: Dictionary) -> void:
	var obj: Dictionary = data.get("object", {})
	var level: Dictionary = data.get("level", {})
	var observation: Dictionary = data.get("observation", {})
	var concept: Dictionary = data.get("concept_card", {})

	_mission_bg()
	_title_banner()
	_mission_texture(MISSION_PARCHMENT, Vector2(180, 78), Vector2(664, 528), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

	var object_name := _dict_inline(obj, "name")
	_paper_label(object_name, Vector2(250, 94), Vector2(524, 42), 28, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle := _target_subtitle(obj)
	if subtitle != "":
		var subtitle_label := _paper_label(subtitle, Vector2(250, 134), Vector2(524, 26), 14, PAPER_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		subtitle_label.max_lines_visible = 2

	_mission_section_line(Vector2(228, 162), 568)
	_observation_image(obj, level, observation)
	_quality_panel(observation, data.get("stats", {}))
	_learned_panel(obj, level, observation, data, concept)
	_rewards_panel(level, concept)
	var next_route := GameManager.current_room_route()
	var next_step := _label(
		GameManager.text("NEXT: ", "下一步：") + str(next_route.get("action", "")),
		Vector2(170, 610), Vector2(684, 28), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER
	)
	next_step.clip_text = true

	var continue_button: Button = _mission_button(GameManager.text("Continue", "继续"), Vector2(298, 650), Vector2(210, 50), Color(0.08, 0.38, 0.20))
	continue_button.pressed.connect(func() -> void:
		GameManager.update_room_guidance_for_level()
		# Family-arc levels close with a short Maya epilogue (summary plus the
		# motivation for the next stage) before returning to the lobby.
		var completed_level_number: int = int(level.get("level_number", 0))
		if GameManager.try_story_epilogue(completed_level_number, "observatory"):
			return
		GameManager.go("observatory")
	)

	var journal_button: Button = _mission_button(GameManager.text("Open Journal", "打开观测日志"), Vector2(536, 650), Vector2(230, 50), Color(0.06, 0.20, 0.42))
	journal_button.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("journal")
		GameManager.go("journal")
	)


func _mission_bg() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.01, 0.015, 0.03))
	_mission_texture(MISSION_BG, Vector2.ZERO, Vector2(1024, 768), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var shade := _rect(Vector2.ZERO, Vector2(1024, 768), Color(0.0, 0.0, 0.0, 0.16))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _title_banner() -> void:
	_dark_panel(Vector2(362, 14), Vector2(300, 54), Color(0.025, 0.045, 0.080, 0.96), GOLD)
	_label(GameManager.text("MISSION COMPLETE", "观测完成"), Vector2(362, 20), Vector2(300, 36), 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


func _observation_image(obj: Dictionary, level: Dictionary, observation: Dictionary) -> void:
	_dark_panel(Vector2(220, 176), Vector2(330, 158), Color(0.025, 0.025, 0.030, 0.88), Color(0.50, 0.34, 0.16))
	if bool(level.get("requires_focus", false)):
		_focus_comparison_image(obj, observation)
		return
	var path := _mission_object_image(obj)
	if path != "":
		_mission_texture(path, Vector2(232, 186), Vector2(306, 138), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var check := _dark_panel(Vector2(204, 158), Vector2(40, 40), Color(0.12, 0.08, 0.03, 0.95), GOLD)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label("✓", Vector2(204, 158), Vector2(40, 36), 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


func _focus_comparison_image(obj: Dictionary, observation: Dictionary) -> void:
	var clear_path := _mission_object_state_image(obj, "clear")
	var blurry_path := _mission_object_state_image(obj, "blurry")
	if clear_path == "" or blurry_path == "":
		var fallback_path := _mission_object_image(obj)
		if fallback_path != "":
			_mission_texture(fallback_path, Vector2(232, 186), Vector2(306, 138), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		return

	var states := [
		{
			"label": _inline_text("Out of Focus", "失焦"),
			"border": Color(0.72, 0.24, 0.12),
			"clear_alpha": 0.0,
			"blur_alpha": 1.0
		},
		{
			"label": _inline_text("Near Focus", "接近焦点"),
			"border": Color(0.82, 0.56, 0.12),
			"clear_alpha": 0.52,
			"blur_alpha": 0.58
		},
		{
			"label": _inline_text("In Focus", "准焦"),
			"border": Color(0.20, 0.56, 0.24),
			"clear_alpha": 1.0,
			"blur_alpha": 0.0
		}
	]
	var start_x := 228.0
	var cell_size := Vector2(100, 140)
	for index in range(states.size()):
		var state: Dictionary = states[index]
		var cell_pos := Vector2(start_x + float(index) * 106.0, 184)
		_dark_panel(cell_pos, cell_size, Color(0.018, 0.022, 0.030, 0.96), state["border"])
		var image_pos := cell_pos + Vector2(5, 5)
		var image_size := Vector2(90, 103)
		var blur_alpha := float(state["blur_alpha"])
		if blur_alpha > 0.0:
			var blurry := _mission_texture(blurry_path, image_pos, image_size, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
			blurry.modulate.a = blur_alpha
		var clear_alpha := float(state["clear_alpha"])
		if clear_alpha > 0.0:
			var clear := _mission_texture(clear_path, image_pos, image_size, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
			clear.modulate.a = clear_alpha
		var label := _label(str(state["label"]), cell_pos + Vector2(3, 111), Vector2(94, 24), 10, state["border"], HORIZONTAL_ALIGNMENT_CENTER)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.max_lines_visible = 2

	# A completed focus mission records the successful state. Mark that state
	# without covering the clear target image.
	var focus_error := float(observation.get("focus_error", 0.0))
	var focus_tolerance := maxf(float(observation.get("focus_tolerance", 0.06)), 0.001)
	if focus_error <= focus_tolerance:
		var badge := _dark_panel(Vector2(510, 180), Vector2(34, 22), Color(0.08, 0.30, 0.12, 0.96), Color(0.34, 0.76, 0.34))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label("OK", Vector2(510, 180), Vector2(34, 20), 10, Color(0.72, 1.0, 0.70), HORIZONTAL_ALIGNMENT_CENTER)


func _quality_panel(observation: Dictionary, stats: Dictionary) -> void:
	_paper_label(_inline_text("Observation Quality", "观测质量"), Vector2(584, 182), Vector2(220, 24), 16, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	_mission_section_line(Vector2(596, 210), 194)
	var scores := _quality_scores(observation, stats)
	var rows := [
		{"name": _inline_text("Clarity", "清晰度"), "score": int(scores.get("clarity", 3))},
		{"name": _inline_text("Contrast", "对比度"), "score": int(scores.get("contrast", 3))},
		{"name": _inline_text("Detail", "细节"), "score": int(scores.get("detail", 3))}
	]
	var y := 222.0
	for row in rows:
		_paper_label(str(row["name"]), Vector2(594, y), Vector2(92, 20), 13, PAPER_INK)
		_paper_label(_star_string(int(row["score"])), Vector2(688, y - 4.0), Vector2(112, 24), 20, Color(0.80, 0.48, 0.08))
		y += 32.0
	var quality := str(observation.get("quality", "Good"))
	_paper_label(quality, Vector2(592, 306), Vector2(198, 22), 14, _paper_quality_color(quality), HORIZONTAL_ALIGNMENT_CENTER)


func _learned_panel(obj: Dictionary, level: Dictionary, observation: Dictionary, data: Dictionary, concept: Dictionary) -> void:
	_mission_section_line(Vector2(228, 354), 568)
	_paper_label(_inline_text("What We Learned", "本次学到"), Vector2(312, 340), Vector2(400, 26), 18, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var lines := _learned_lines(obj, level, observation, data, concept)
	var y := 370.0
	for line_value in lines:
		var line: String = str(line_value)
		var label := _paper_label("✦ " + line, Vector2(272, y), Vector2(520, 28), 12, PAPER_INK)
		label.max_lines_visible = 1
		y += 32.0


func _rewards_panel(level: Dictionary, concept: Dictionary) -> void:
	_mission_section_line(Vector2(228, 486), 568)
	_paper_label(_inline_text("Rewards Unlocked", "奖励解锁"), Vector2(312, 474), Vector2(400, 24), 18, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var rewards := _reward_items(level, concept)
	var count: int = max(1, rewards.size())
	var slot_w := 144.0
	var total_w := slot_w * float(count)
	var start_x := 512.0 - total_w * 0.5
	for i in range(rewards.size()):
		var reward: Dictionary = rewards[i]
		var x := start_x + float(i) * slot_w
		_reward_slot(reward, Vector2(x, 510))


func _reward_slot(reward: Dictionary, pos: Vector2) -> void:
	var icon_path := str(reward.get("icon", ""))
	if icon_path != "":
		_mission_texture(icon_path, pos + Vector2(43, 0), Vector2(44, 44), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var title := str(reward.get("title", ""))
	var detail := str(reward.get("detail", ""))
	var title_label := _paper_label(title, pos + Vector2(2, 42), Vector2(126, 20), 11, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.max_lines_visible = 1
	var detail_label := _paper_label(detail, pos + Vector2(2, 60), Vector2(126, 20), 10, PAPER_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	detail_label.max_lines_visible = 1


func _reward_items(level: Dictionary, concept: Dictionary) -> Array:
	var items: Array = []
	var credits := int(level.get("reward_credits", 0))
	if credits > 0:
		items.append({
			"icon": MISSION_CREDIT,
			"title": "+%d" % credits,
			"detail": _inline_text("Club Credits", "社团积分")
		})
	var badge := str(level.get("badge", ""))
	if badge != "":
		items.append({
			"icon": MISSION_BADGE,
			"title": badge,
			"detail": _inline_text("Observer Badge", "观测徽章")
		})
	if not concept.is_empty():
		items.append({
			"icon": MISSION_JOURNAL,
			"title": _inline_text("Journal Entry", "日志条目"),
			"detail": _inline_text("Unlocked", "已解锁")
		})
	var unlock_names := _unlock_names(level)
	if not unlock_names.is_empty():
		items.append({
			"icon": MISSION_BADGE,
			"title": _inline_text("New Gear", "新装备"),
			"detail": ", ".join(unlock_names)
		})
	return items


func _unlock_names(level: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for part_id in level.get("unlock_parts", []):
		var part := GameManager.get_part(str(part_id))
		if part.is_empty():
			continue
		names.append(_dict_inline(part, "name"))
	return names


func _quality_scores(observation: Dictionary, stats: Dictionary) -> Dictionary:
	var quality := str(observation.get("quality", "Good"))
	var base := _quality_to_stars(quality)
	var ratios: Dictionary = observation.get("ratios", {})
	var clarity_value := float(observation.get("effective_clarity", stats.get("clarity_score", 60.0)))
	var clarity := int(clampf(round(clarity_value / 20.0), 0.0, 5.0))
	if clarity == 0 and base > 0:
		clarity = base
	var contrast_ratio := float(ratios.get("light", base / 5.0))
	var contrast := int(clampf(round(contrast_ratio * 4.0), 0.0, 5.0))
	if contrast == 0 and base > 0:
		contrast = max(1, base - 1)
	var stability_ratio := float(ratios.get("stability", base / 5.0))
	var detail := int(clampf(round((float(base) + stability_ratio * 4.0) * 0.5), 0.0, 5.0))
	return {
		"clarity": clampi(clarity, 0, 5),
		"contrast": clampi(contrast, 0, 5),
		"detail": clampi(detail, 0, 5)
	}


func _quality_to_stars(quality: String) -> int:
	match quality:
		"Excellent":
			return 5
		"Good":
			return 4
		"Fair":
			return 3
		"Poor":
			return 2
		"Failed":
			return 1
	return 3


func _star_string(score: int) -> String:
	var full := clampi(score, 0, 5)
	var text := ""
	for i in range(5):
		text += "★" if i < full else "☆"
	return text


func _paper_quality_color(quality: String) -> Color:
	match quality:
		"Excellent":
			return Color(0.20, 0.44, 0.15)
		"Good":
			return Color(0.18, 0.38, 0.16)
		"Fair":
			return Color(0.56, 0.38, 0.10)
		"Poor":
			return Color(0.65, 0.22, 0.12)
		"Failed":
			return Color(0.55, 0.12, 0.10)
	return PAPER_MUTED


func _target_subtitle(obj: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["messier", "constellation", "type", "distance"]:
		var value := ""
		if key == "messier":
			value = str(obj.get(key, ""))
		else:
			value = GameManager.dict_text(obj, key)
		if value != "":
			parts.append(value)
	if not parts.is_empty():
		return " · ".join(parts)
	# Backward compatibility for older object rows that only have English
	# subtitle metadata.
	for key in ["constellation_en", "type_en", "distance_en"]:
		var value := str(obj.get(key, ""))
		if value != "":
			parts.append(value)
	if parts.is_empty():
		return ""
	return " · ".join(parts)


func _learned_lines(obj: Dictionary, level: Dictionary, observation: Dictionary, data: Dictionary, concept: Dictionary) -> Array[String]:
	var id := str(obj.get("id", ""))
	var type_text := str(obj.get("type_en", "")).to_lower()
	var lines: Array[String] = []
	var success := _dict_inline(level, "success_text")
	if success != "":
		lines.append(success.replace("\n", " / "))
	var variation := str(level.get("variation", ""))
	var concept_title := _dict_inline(concept, "title")
	if concept_title != "":
		lines.append(_inline_text("Concept logged:", "知识点记录：") + " " + concept_title.replace("\n", " / "))

	if id == "moon":
		lines.append(_inline_text(
			"The Moon is bright enough to show craters and maria when the optics are steady.",
			"月球足够明亮，光学稳定时可以看到陨石坑和月海。"
		))
		if bool(level.get("requires_telescope", false)):
			lines.append(_inline_text(
				"A telescope reveals detail your naked eye cannot separate.",
				"望远镜能分辨肉眼无法分开的细节。"
			))
	elif id == "jupiter" or id == "mars" or type_text.find("planet") >= 0:
		lines.append(_inline_text(
			"Planet detail depends on focus, magnification, and a steady mount.",
			"行星细节取决于调焦、倍率和支架稳定性。"
		))
		if variation != "":
			lines.append(_inline_text(
				"Tonight's variable: " + variation.replace("_", " ") + ".",
				"今晚变化的条件：" + variation.replace("_", " ") + "。"
			))
	elif type_text.find("star") >= 0:
		lines.append(_inline_text(
			"Even through a telescope, stars stay point-like; brightness and color carry the clue.",
			"即使用望远镜，恒星也多半仍是点状；亮度和颜色才是线索。"
		))
		lines.append(_inline_text(
			"The finder scope helps place a tiny target into the narrow telescope view.",
			"寻星镜帮助把小目标送进狭窄的主镜视野。"
		))
	elif type_text.find("nebula") >= 0 or type_text.find("galaxy") >= 0 or id == "orion_nebula" or id == "andromeda":
		lines.append(_inline_text(
			"Faint deep-sky objects often look like soft smudges, not sharp planets.",
			"暗弱深空天体常像柔和的淡斑，而不是清晰的行星。"
		))
		lines.append(_inline_text(
			"Aperture, dark skies, and patient viewing matter more than raw magnification.",
			"口径、暗空和耐心观测比单纯高倍率更重要。"
		))
	else:
		var object_learning := _dict_inline(obj, "learning_text")
		if object_learning != "":
			lines.append(object_learning.replace("\n", " / "))

	var maya_recap := str(data.get("maya_recap_zh", "")) if GameManager.language_mode == "zh" else str(data.get("maya_recap_en", ""))
	if maya_recap != "":
		lines.append("Maya: " + maya_recap)
	while lines.size() > 3:
		lines.pop_back()
	return lines


func _mission_object_image(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	var path := ""
	match id:
		"moon":
			path = "res://assets/telescope_view/moon_clear.png"
		"mars":
			path = "res://assets/telescope_view/mars_clear.png"
		"jupiter":
			path = "res://assets/telescope_view/jupiter_clear.png"
		"vega":
			path = "res://assets/telescope_view/vega_user_clear.png"
		"orion_nebula":
			path = "res://assets/telescope_view/orion_nebula_clear.png"
		"andromeda":
			path = "res://assets/telescope_view/andromeda_clear.png"
		"betelgeuse":
			path = "res://assets/telescope_view/star_red_clear.png"
		"sirius":
			path = "res://assets/telescope_view/star_blue_clear.png"
		"polaris":
			path = "res://assets/telescope_view/star_white_clear.png"
		"arcturus":
			path = "res://assets/telescope_view/arcturus_clear.png"
		"canopus":
			path = "res://assets/telescope_view/canopus_clear.png"
		"alpha_centauri":
			path = "res://assets/telescope_view/alpha_cen_clear.png"
		"proxima":
			path = "res://assets/telescope_view/proxima_clear.png"
	if path != "" and ResourceLoader.exists(path):
		return path
	return ""


func _mission_object_state_image(obj: Dictionary, state: String) -> String:
	var clear_path := _mission_object_image(obj)
	if clear_path == "" or state == "clear":
		return clear_path
	var state_path := clear_path.replace("_clear.png", "_%s.png" % state)
	if ResourceLoader.exists(state_path):
		return state_path
	return clear_path


func _mission_section_line(pos: Vector2, width: float) -> void:
	_rect(pos, Vector2(width, 1), PAPER_LINE)


func _paper_box(pos: Vector2, size: Vector2) -> void:
	var box := _rect(pos, size, PAPER_BOX)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect(pos, Vector2(size.x, 1), PAPER_LINE)
	_rect(pos + Vector2(0, size.y - 1), Vector2(size.x, 1), PAPER_LINE)
	_rect(pos, Vector2(1, size.y), PAPER_LINE)
	_rect(pos + Vector2(size.x - 1, 0), Vector2(1, size.y), PAPER_LINE)


func _paper_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(text, pos, size, font_size, color, align)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _dark_panel(pos: Vector2, size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _mission_texture(path: String, pos: Vector2, size: Vector2, stretch: TextureRect.StretchMode) -> TextureRect:
	var rect := TextureRect.new()
	var texture: Texture2D = _load_texture(path)
	if texture != null:
		rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.position = pos
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _mission_button(text: String, pos: Vector2, size: Vector2, color: Color) -> Button:
	var button := _button(text, pos, size)
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = GOLD
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	return button


func _inline_text(en: String, zh: String) -> String:
	if GameManager.language_mode == "zh":
		return zh
	return en


func _dict_inline(data: Dictionary, base: String) -> String:
	var en := str(data.get(base + "_en", data.get(base, "")))
	var zh := str(data.get(base + "_zh", en))
	return _inline_text(en, zh)


func _diagram(image_path: String, pos: Vector2, size: Vector2) -> void:
	if image_path == "" or not ResourceLoader.exists(image_path):
		return
	var diagram := TextureRect.new()
	diagram.texture = load(image_path)
	diagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diagram.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diagram.position = pos
	diagram.size = size
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(diagram)


func _panel(pos: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
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


func _button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 16)
	add_child(button)
	return button

func _on_language_changed() -> void:
	_build()
