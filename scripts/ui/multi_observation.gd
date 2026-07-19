extends Control

const BG := Color("07101c")
const PANEL := Color("101d30")
const GOLD := Color("d8a94d")
const CYAN := Color("61d8ff")
const GREEN := Color("67d78b")
const TEXT := Color("e9e5d8")

var status_label: Label


func _ready() -> void:
	GameManager.language_changed.connect(_build)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_label(GameManager.text("MULTI-OBSERVATORY EVIDENCE DESK", "多观测台证据工作台"), Vector2(32, 22), Vector2(960, 32), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var target := GameManager.current_target()
	_label(GameManager.text("Target: ", "目标：") + GameManager.dict_text(target, "name"), Vector2(50, 72), Vector2(924, 28), 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Choose the record that best answers the current question. Each instrument measures a different signal.", "选择最能回答当前问题的记录。每台仪器测量不同的信号。"), Vector2(70, 112), Vector2(884, 36), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_add_record("Optical", "可见光", "Surface detail, star colors, and visual shape.", "表面细节、恒星颜色与可见形状。", Vector2(70, 190), "optical")
	_add_record("Infrared", "红外", "Warm dust and structure hidden behind visible-light dust.", "温暖尘埃，以及可见光尘埃后隐藏的结构。", Vector2(362, 190), "infrared")
	_add_record("Radio", "无线电", "Pulses, gas, and signals that never form a visible image.", "脉冲、气体和永远不会形成可见图像的信号。", Vector2(654, 190), "radio")
	status_label = _label(GameManager.text("Review the evidence, then choose a record.", "阅读证据后，选择一份记录。"), Vector2(100, 560), Vector2(824, 42), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(GameManager.text("Back", "返回"), Vector2(412, 636), Vector2(200, 44), Color("15233a"))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("telescope"); GameManager.go("observatory"))
	add_child(back)


func _add_record(en: String, zh: String, en_desc: String, zh_desc: String, pos: Vector2, key: String) -> void:
	_panel(pos, Vector2(250, 310), PANEL, GOLD)
	_label(GameManager.text(en, zh), pos + Vector2(12, 18), Vector2(226, 32), 19, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var desc := _label(GameManager.text(en_desc, zh_desc), pos + Vector2(18, 78), Vector2(214, 104), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var choose := _button(GameManager.text("Use this record", "使用这份记录"), pos + Vector2(26, 230), Vector2(198, 42), Color("164560"))
	choose.pressed.connect(func() -> void: _choose(key))
	add_child(choose)


func _expected_record() -> String:
	var level := int(GameManager.current_level().get("level_number", 43))
	if level >= 37 and level <= 39:
		return "infrared"
	if level == 43:
		return "infrared"
	if level == 44:
		return "optical"
	return "radio"


func _choose(key: String) -> void:
	if key != _expected_record():
		status_label.text = GameManager.text("This record is useful, but it does not answer this mission's question best. Compare the signal type again.", "这份记录有价值，但它并非最适合回答本任务问题。请再次比较信号类型。")
		status_label.add_theme_color_override("font_color", GOLD)
		return
	status_label.text = GameManager.text("Correct instrument choice. The observation report is ready.", "仪器选择正确，观测报告已准备好。")
	status_label.add_theme_color_override("font_color", GREEN)
	var observation := {"success": true, "quality": "Good", "clarity": 88.0, "contrast": 88.0, "detail": 88.0, "feedback_en": "The evidence matches the observing method."}
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = GOLD
	style.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", TEXT)
	return button
