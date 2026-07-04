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


func _ready() -> void:
	_build()


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
	_label(str(card.get("title_en", "Concept")), Vector2(150, 114), Vector2(724, 28), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_diagram(str(card.get("image", "")), Vector2(152, 142), Vector2(720, 405))

	var body: Label = _label(
		str(card.get("text_en", "")),
		Vector2(150, 562),
		Vector2(724, 72),
		15,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	body.max_lines_visible = 3

	var start: Button = _button("Start", Vector2(382, 686), Vector2(260, 48))
	start.pressed.connect(func() -> void:
		GameManager.complete_current_brief()
	)


func _build_mission_complete(data: Dictionary) -> void:
	var obj: Dictionary = data.get("object", {})
	var level: Dictionary = data.get("level", {})
	var observation: Dictionary = data.get("observation", {})
	var concept: Dictionary = data.get("concept_card", {})

	_label("Mission Complete", Vector2(0, 18), Vector2(1024, 42), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label("Result, reward, and a short recap.", Vector2(0, 62), Vector2(1024, 24), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_panel(Vector2(110, 102), Vector2(804, 560))

	var observed_text: String = "Observed: " + str(obj.get("name_en", obj.get("id", "Target")))
	var quality_text: String = "Quality: " + str(observation.get("quality", "Good"))
	var reward_text: String = "Reward: +%d credits" % int(level.get("reward_credits", 0))
	var badge_text: String = str(level.get("badge", ""))

	_label(observed_text, Vector2(150, 132), Vector2(300, 28), 18, TEXT)
	_label(quality_text, Vector2(150, 168), Vector2(300, 28), 18, GREEN)
	_label(reward_text, Vector2(150, 204), Vector2(300, 24), 15, MUTED)
	if badge_text != "":
		_label("Badge: " + badge_text, Vector2(150, 234), Vector2(300, 24), 15, MUTED)

	# Announce any parts unlocked by this completion (queued notice is
	# consumed later by the observatory popup, so just read it here).
	var pending_unlocks: Array = GameManager.progress.get("pending_unlock_notice", [])
	if not pending_unlocks.is_empty():
		var names: Array[String] = []
		for part_id in pending_unlocks:
			names.append(str(GameManager.get_part(str(part_id)).get("name_en", part_id)))
		var unlock_label := _label("NEW PARTS: " + ", ".join(names), Vector2(150, 256), Vector2(310, 40), 11, Color(0.60, 0.95, 0.70))
		unlock_label.max_lines_visible = 2

	if not concept.is_empty():
		_label("Concept learned", Vector2(150, 280), Vector2(300, 22), 14, MUTED)
		_label(str(concept.get("title_en", "Concept")), Vector2(150, 304), Vector2(300, 56), 19, GOLD)
		_diagram(str(concept.get("image", "")), Vector2(440, 136), Vector2(460, 259))
	else:
		_label("Concept learned", Vector2(150, 280), Vector2(300, 22), 14, MUTED)
		_label("Observation practice", Vector2(150, 304), Vector2(300, 56), 19, GOLD)

	var maya_recap: String = str(data.get("maya_recap_en", ""))
	if maya_recap != "":
		var maya_line: Label = _label(
			"Maya: \"" + maya_recap + "\"",
			Vector2(160, 400), Vector2(700, 44), 15, Color(0.98, 0.82, 0.50), HORIZONTAL_ALIGNMENT_CENTER
		)
		maya_line.max_lines_visible = 2

	var recap_text: String = _recap_text(obj, level)
	var recap: Label = _label(recap_text, Vector2(160, 448), Vector2(700, 96), 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	recap.max_lines_visible = 4

	_label("The full card is now available in the Learning Journal.", Vector2(160, 552), Vector2(700, 28), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	var continue_button: Button = _button("Continue", Vector2(232, 686), Vector2(260, 48))
	continue_button.pressed.connect(func() -> void:
		GameManager.go("observatory")
	)

	var journal_button: Button = _button("Open Journal", Vector2(532, 686), Vector2(260, 48))
	journal_button.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("journal")
		GameManager.go("journal")
	)


func _recap_text(obj: Dictionary, level: Dictionary) -> String:
	var success: String = str(level.get("success_text_en", "You completed the mission."))
	var object_learning: String = str(obj.get("learning_text_en", ""))
	if object_learning == "":
		return success
	return success + "\n\n" + object_learning


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
