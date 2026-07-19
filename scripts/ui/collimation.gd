extends Control

const BG := Color(0.012, 0.020, 0.042)
const GOLD := Color(0.94, 0.72, 0.30)
const CYAN := Color(0.44, 0.84, 1.0)
const GREEN := Color(0.48, 0.92, 0.58)
const TEXT := Color(0.92, 0.91, 0.84)

var secondary_x := 0.18
var secondary_y := -0.14
var primary_x := -0.12
var primary_y := 0.16
var result_label: Label
var score_label: Label
var reticle: Control


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_label(GameManager.text("NEWTONIAN COLLIMATION", "牛顿镜准直"), Vector2(0, 22), Vector2(1024, 34), 27, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Align the optical axis. Focus cannot fix a tilted mirror.", "校正光轴。调焦不能修复倾斜的镜面。"), Vector2(0, 58), Vector2(1024, 22), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var field := Panel.new()
	field.position = Vector2(78, 112)
	field.size = Vector2(560, 560)
	field.add_theme_stylebox_override("panel", _style(Color(0.02, 0.035, 0.065), GOLD, 2))
	add_child(field)
	reticle = Control.new()
	reticle.position = Vector2(30, 30)
	reticle.size = Vector2(500, 500)
	field.add_child(reticle)
	_draw_reticle()

	var panel := Panel.new()
	panel.position = Vector2(666, 112)
	panel.size = Vector2(292, 560)
	panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.065, 0.11), GOLD, 2))
	add_child(panel)
	panel.add_child(_label(GameManager.text("ALIGNMENT CONTROLS", "对准控制"), Vector2(16, 16), Vector2(260, 22), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_add_slider(panel, GameManager.text("Secondary horizontal", "副镜水平"), 60, secondary_x, func(value: float) -> void: secondary_x = value; _refresh())
	_add_slider(panel, GameManager.text("Secondary vertical", "副镜垂直"), 126, secondary_y, func(value: float) -> void: secondary_y = value; _refresh())
	_add_slider(panel, GameManager.text("Primary horizontal", "主镜水平"), 192, primary_x, func(value: float) -> void: primary_x = value; _refresh())
	_add_slider(panel, GameManager.text("Primary vertical", "主镜垂直"), 258, primary_y, func(value: float) -> void: primary_y = value; _refresh())
	score_label = _label("", Vector2(20, 340), Vector2(252, 28), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(score_label)
	result_label = _label("", Vector2(20, 376), Vector2(252, 76), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(result_label)
	var finish := Button.new()
	finish.text = GameManager.text("Confirm Collimation", "确认准直")
	finish.position = Vector2(28, 474)
	finish.size = Vector2(236, 42)
	finish.add_theme_font_size_override("font_size", 15)
	finish.pressed.connect(_confirm)
	panel.add_child(finish)
	_refresh()


func _add_slider(parent: Control, title: String, y: float, value: float, changed: Callable) -> void:
	parent.add_child(_label(title, Vector2(20, y), Vector2(250, 18), 12, CYAN))
	var slider := HSlider.new()
	slider.min_value = -0.25
	slider.max_value = 0.25
	slider.step = 0.01
	slider.value = value
	slider.position = Vector2(20, y + 24)
	slider.size = Vector2(252, 18)
	slider.value_changed.connect(changed)
	parent.add_child(slider)


func _score() -> float:
	var error := Vector2(secondary_x + primary_x * 0.7, secondary_y + primary_y * 0.7).length()
	return clampf(100.0 - error * 250.0, 0.0, 100.0)


func _refresh() -> void:
	var score: float = _score()
	score_label.text = GameManager.text("Collimation: %.0f%%" % score, "准直：%.0f%%" % score)
	if score >= float(GameManager.current_level().get("collimation_threshold", 86.0)):
		result_label.text = GameManager.text("Optical axis aligned. This is not focus - the reflected light is centered.", "光轴已对齐。这不是调焦，而是反射光已经居中。")
		result_label.add_theme_color_override("font_color", GREEN)
	else:
		result_label.text = GameManager.text("The star test would look lopsided. Adjust the mirrors, not the focus knob.", "星点测试会偏斜。请调整镜面，而不是调焦旋钮。")
		result_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.34))
	_draw_reticle()


func _draw_reticle() -> void:
	if reticle == null:
		return
	for child in reticle.get_children():
		child.queue_free()
	var center := Vector2(250, 250)
	for radius in [210.0, 150.0, 90.0, 38.0]:
		var ring := Panel.new()
		ring.position = center - Vector2.ONE * radius
		ring.size = Vector2.ONE * radius * 2.0
		ring.add_theme_stylebox_override("panel", _ring_style(Color(0.30, 0.68, 0.90, 0.75), int(radius)))
		reticle.add_child(ring)
	var offset := Vector2(secondary_x + primary_x * 0.7, secondary_y + primary_y * 0.7) * 360.0
	var spot := Panel.new()
	spot.position = center + offset - Vector2(18, 18)
	spot.size = Vector2(36, 36)
	spot.add_theme_stylebox_override("panel", _ring_style(GOLD, 18))
	reticle.add_child(spot)
	var cross := _label("+", center + offset - Vector2(18, 22), Vector2(36, 40), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	reticle.add_child(cross)


func _confirm() -> void:
	var score: float = _score()
	GameManager.set_collimation_score(score)
	if GameManager.collimation_is_acceptable():
		GameManager.update_room_guidance_for_level()
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	else:
		_refresh()


func _label(text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _rect(pos: Vector2, size_value: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size_value
	rect.color = color
	add_child(rect)


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _ring_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style


func _on_language_changed() -> void:
	_build()
