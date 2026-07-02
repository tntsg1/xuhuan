extends Control


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label(GameManager.text("Learning Journal", "学习记录"), 30)
	title.position = Vector2(28, 18)
	title.size = Vector2(420, 44)
	add_child(title)

	var list := VBoxContainer.new()
	list.position = Vector2(32, 82)
	list.size = Vector2(930, 570)
	list.add_theme_constant_override("separation", 10)
	add_child(list)

	var entries: Array = GameManager.progress.get("journal_entries", [])
	if entries.is_empty():
		list.add_child(_label(GameManager.text("No observations recorded yet.", "还没有观测记录。"), 20))
	else:
		for entry in entries:
			var line: String = "%s / %s\n%s: %s | %s: %s\n%s\n%s" % [
				entry.get("object_name_en", ""),
				entry.get("object_name_zh", ""),
				GameManager.text("Quality", "质量"),
				entry.get("observation_quality", ""),
				GameManager.text("Assembly", "组装"),
				entry.get("assembly_score", 0),
				entry.get("learning_text_en", ""),
				entry.get("learning_text_zh", "")
			]
			list.add_child(_label(line, 16))

	var back := _button(GameManager.text("Back to Observatory", "返回观测室"))
	back.position = Vector2(760, 675)
	back.size = Vector2(230, 48)
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("journal")
		GameManager.go("observatory")
	)
	add_child(back)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	return button
