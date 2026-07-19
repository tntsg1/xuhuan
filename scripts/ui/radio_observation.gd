extends Control

const BG := Color("07101c")
const PANEL := Color("101d30")
const GOLD := Color("d8a94d")
const CYAN := Color("61d8ff")
const GREEN := Color("67d78b")
const TEXT := Color("e9e5d8")

var frequency := 50.0
var feed_position := 50.0
var signal_label: Label
var trace: Line2D
var status_label: Label


func _ready() -> void:
	GameManager.language_changed.connect(_build)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_add_label(GameManager.text("FAST RADIO OBSERVATION", "FAST 无线电观测"), Vector2(32, 18), Vector2(960, 34), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(GameManager.text("A radio source is identified from its signal trace, not from a visible eyepiece image.", "无线电源通过信号轨迹识别，而不是通过目镜图像。"), Vector2(48, 55), Vector2(928, 22), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_add_panel(Vector2(42, 104), Vector2(626, 520), PANEL, GOLD)
	_add_label(GameManager.text("RECEIVED SIGNAL / 接收信号", "接收信号"), Vector2(66, 122), Vector2(578, 24), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	trace = Line2D.new()
	trace.width = 3.0
	trace.default_color = CYAN
	trace.position = Vector2(76, 0)
	add_child(trace)
	_add_panel(Vector2(698, 104), Vector2(284, 520), PANEL, GOLD)
	var target := GameManager.current_target()
	_add_label(GameManager.text("TARGET", "目标"), Vector2(716, 122), Vector2(248, 20), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var target_label := _add_label(GameManager.dict_text(target, "name"), Vector2(716, 148), Vector2(248, 42), 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_label(GameManager.text("Tune both controls until the repeated pulse becomes strongest.", "调节两个控制器，直到重复脉冲最强。"), Vector2(720, 205), Vector2(240, 48), 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_slider("Receiver frequency", "接收频率", 272, frequency, func(value: float) -> void: frequency = value; _refresh())
	_add_slider("Feed cabin position", "馈源舱位置", 358, feed_position, func(value: float) -> void: feed_position = value; _refresh())
	signal_label = _add_label("", Vector2(716, 448), Vector2(248, 32), 17, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	status_label = _add_label("", Vector2(716, 484), Vector2(248, 54), 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var record := _button(GameManager.text("Record Signal", "记录信号"), Vector2(716, 552), Vector2(118, 42), Color("175238"))
	record.pressed.connect(_record)
	add_child(record)
	var back := _button(GameManager.text("Back", "返回"), Vector2(846, 552), Vector2(118, 42), Color("15233a"))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("telescope"); GameManager.go("observatory"))
	add_child(back)
	_refresh()


func _add_slider(en: String, zh: String, y: float, value: float, changed: Callable) -> void:
	_add_label(GameManager.text(en, zh), Vector2(720, y), Vector2(240, 20), 12, TEXT)
	var slider := HSlider.new()
	slider.position = Vector2(720, y + 26)
	slider.size = Vector2(240, 18)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = value
	slider.value_changed.connect(changed)
	add_child(slider)


func _signal_strength() -> float:
	return clampf(100.0 - absf(frequency - 62.0) * 2.4 - absf(feed_position - 47.0) * 2.0, 0.0, 100.0)


func _refresh() -> void:
	var strength := _signal_strength()
	if signal_label == null:
		return
	signal_label.text = GameManager.text("Signal strength: %d%%" % roundi(strength), "信号强度：%d%%" % roundi(strength))
	var ready := strength >= 82.0
	status_label.text = GameManager.text("Strong repeating pulse. Ready to record." if ready else "Adjust frequency and feed position. A signal peak means the source is centered.", "重复脉冲很强，可以记录。" if ready else "调节频率和馈源位置。信号峰值表示目标已居中。")
	status_label.add_theme_color_override("font_color", GREEN if ready else CYAN)
	_draw_trace(strength)


func _draw_trace(strength: float) -> void:
	if trace == null:
		return
	trace.clear_points()
	var base_y := 370.0
	var amplitude := 12.0 + strength * 0.72
	for x in range(0, 548, 6):
		var phase := float(x % 86) / 86.0
		var pulse := pow(maxf(0.0, sin(phase * TAU)), 12.0) * amplitude
		trace.add_point(Vector2(float(x), base_y - pulse + sin(float(x) * 0.12) * 3.0))


func _record() -> void:
	var strength := _signal_strength()
	if strength < 82.0:
		status_label.text = GameManager.text("The trace is too weak to identify. Find the signal peak first.", "信号轨迹太弱，无法识别。请先找到信号峰值。")
		return
	var observation := {"success": true, "quality": "Good", "clarity": strength, "contrast": strength, "detail": strength, "feedback_en": "A stable radio pulse was recorded."}
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _add_panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
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


func _add_label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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
