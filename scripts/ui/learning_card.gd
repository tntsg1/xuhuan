extends Control


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.050, 0.060, 0.090))

	var card := VBoxContainer.new()
	card.position = Vector2(174, 52)
	card.size = Vector2(676, 560)
	card.add_theme_constant_override("separation", 13)
	add_child(card)

	var data := GameManager.last_learning_card
	var obj: Dictionary = data.get("object", {})
	var level: Dictionary = data.get("level", {})
	var observation: Dictionary = data.get("observation", {})

	card.add_child(_label("Mission Complete / 任务完成", 32, Color(0.96, 0.90, 0.58)))
	card.add_child(_label("Learning Card / 学习卡", 20, Color(0.78, 0.86, 0.92)))
	card.add_child(_label(GameManager.dict_text(obj, "name") + " - " + GameManager.dict_text(obj, "type"), 24, Color(0.95, 0.94, 0.86)))
	card.add_child(_label(GameManager.dict_text(obj, "learning_text"), 18, Color(0.88, 0.91, 0.88)))
	card.add_child(_label("Mission / 任务: " + GameManager.dict_text(level, "title"), 17, Color(0.82, 0.88, 0.94)))
	card.add_child(_label("Observation Quality / 观测质量: " + str(observation.get("quality", "Good")), 17, Color(0.76, 0.94, 0.66)))
	card.add_child(_label(GameManager.dict_text(level, "success_text"), 17, Color(0.88, 0.86, 0.78)))

	var continue_button := _button("Continue\n继续")
	continue_button.pressed.connect(func() -> void: GameManager.go("observatory"))
	card.add_child(continue_button)

	var journal_button := _button("Open Journal\n打开学习记录")
	journal_button.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("journal")
		GameManager.go("journal")
	)
	card.add_child(journal_button)


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 52)
	button.add_theme_font_size_override("font_size", 17)
	return button
