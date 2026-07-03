extends Control

const SCREEN_SIZE := Vector2(1024, 768)
const PANEL := Color(0.045, 0.065, 0.115, 0.96)
const BRASS := Color(0.78, 0.56, 0.28)
const BLUE_EDGE := Color(0.18, 0.28, 0.44)
const WARM_TEXT := Color(0.95, 0.93, 0.86)

const TYPE_LABELS := {
	"tripod": {"en": "Tripod", "zh": "三脚架", "role": "Bottom support / 底部支撑"},
	"mount": {"en": "Mount", "zh": "支架", "role": "Holds and turns the tube / 支撑并转动镜筒"},
	"tube": {"en": "Tube", "zh": "镜筒", "role": "Keeps optics aligned / 保持光路对齐"},
	"objective": {"en": "Objective Lens", "zh": "物镜", "role": "Collects light / 收集光线"},
	"eyepiece": {"en": "Eyepiece", "zh": "目镜", "role": "Magnifies the image / 放大图像"},
	"finder_scope": {"en": "Finder Scope", "zh": "寻星镜", "role": "Helps aiming / 帮助瞄准"}
}


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = SCREEN_SIZE

	_rect(Vector2.ZERO, SCREEN_SIZE, Color(0.010, 0.016, 0.032))
	_draw_title_bar()
	_draw_summary_panel()
	_draw_parts_grid()


func _draw_title_bar() -> void:
	_panel(Vector2(18, 14), Vector2(988, 56), Color(0.030, 0.045, 0.085, 0.98), BLUE_EDGE)
	var title := _label("Parts Cabinet / 零件柜", Vector2(252, 24), Vector2(520, 32), 24, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var back := _button("Back to Base\n返回基地", Vector2(842, 22), Vector2(144, 40))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("cabinet")
		GameManager.go("observatory")
	)
	add_child(back)


func _draw_summary_panel() -> void:
	_panel(Vector2(36, 92), Vector2(952, 92), Color(0.040, 0.060, 0.105, 0.96), BRASS)
	_label(
		"Inventory view only. Choose the Assembly Table when you are ready to build.\n这里只查看零件库存和说明。准备安装时请去组装台。",
		Vector2(60, 112),
		Vector2(700, 48),
		15,
		Color(0.84, 0.90, 0.90)
	)
	var ready_text := "Ready / 已就绪" if GameManager.telescope_is_ready() else "Not Ready / 未就绪"
	_label(
		"Telescope: " + ready_text + "\nUnlocked parts: " + str(GameManager.progress.get("unlocked_parts", []).size()),
		Vector2(780, 108),
		Vector2(180, 56),
		14,
		Color(0.95, 0.84, 0.52),
		HORIZONTAL_ALIGNMENT_RIGHT
	)


func _draw_parts_grid() -> void:
	var unlocked: Array = GameManager.progress.get("unlocked_parts", [])
	var visible_parts: Array[Dictionary] = []
	for part in GameManager.parts_data:
		var part_id := str(part.get("id", ""))
		if unlocked.has(part_id):
			visible_parts.append(part)

	if visible_parts.is_empty():
		_label("No unlocked parts yet.\n还没有已解锁零件。", Vector2(80, 240), Vector2(864, 48), 18, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		return

	for i in range(visible_parts.size()):
		var row := i / 2
		var col := i % 2
		var pos := Vector2(48 + col * 474, 214 + row * 150)
		_draw_part_card(visible_parts[i], pos)


func _draw_part_card(part: Dictionary, pos: Vector2) -> void:
	_panel(pos, Vector2(444, 124), PANEL, BRASS)
	var part_type := str(part.get("type", ""))
	var part_id := str(part.get("id", ""))
	var type_info: Dictionary = TYPE_LABELS.get(part_type, {"en": part_type.capitalize(), "zh": "零件", "role": ""})
	var equipped: bool = GameManager.equipped_part_id(part_type) == part_id

	_rect(pos + Vector2(18, 22), Vector2(70, 70), Color(0.070, 0.090, 0.120))
	_draw_icon(part_type, pos + Vector2(18, 22))

	_label(str(part.get("name_en", type_info["en"])), pos + Vector2(104, 16), Vector2(210, 20), 15, WARM_TEXT)
	_label(str(type_info["zh"]), pos + Vector2(104, 38), Vector2(210, 18), 13, Color(0.78, 0.88, 0.88))
	if equipped:
		_label("Equipped / 已装备", pos + Vector2(310, 18), Vector2(110, 18), 12, Color(0.98, 0.82, 0.36), HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var equip := _button("Equip\n装备", pos + Vector2(352, 12), Vector2(76, 40))
		equip.pressed.connect(func() -> void:
			if GameManager.equip_part(part_id):
				_build()
		)
		add_child(equip)
	_label(str(type_info["role"]), pos + Vector2(104, 60), Vector2(240, 18), 12, Color(0.92, 0.78, 0.48))

	var desc := str(part.get("description_en", ""))
	_label(desc, pos + Vector2(104, 82), Vector2(292, 30), 11, Color(0.78, 0.84, 0.84))

	var stats := _part_stats(part)
	_label(stats, pos + Vector2(18, 96), Vector2(390, 18), 11, Color(0.62, 0.76, 0.86))


func _part_stats(part: Dictionary) -> String:
	var keys := ["aperture_mm", "focal_length_mm", "stability_bonus", "stability", "quality", "field_of_view", "aim_assist"]
	var result: Array[String] = []
	for key in keys:
		if part.has(key):
			result.append(key.replace("_", " ") + ": " + str(part.get(key)))
	if result.is_empty():
		return "No special stats / 暂无特殊属性"
	return "  |  ".join(result)


func _draw_icon(part_type: String, box_pos: Vector2) -> void:
	var color := Color(0.52, 0.70, 0.86)
	match part_type:
		"tripod":
			color = Color(0.56, 0.62, 0.68)
			_rect(box_pos + Vector2(32, 12), Vector2(8, 34), color)
			_rect(box_pos + Vector2(18, 46), Vector2(36, 6), color.lightened(0.08))
			_rect(box_pos + Vector2(16, 52), Vector2(6, 12), color.darkened(0.10))
			_rect(box_pos + Vector2(50, 52), Vector2(6, 12), color.darkened(0.10))
		"mount":
			color = Color(0.62, 0.68, 0.74)
			_rect(box_pos + Vector2(22, 20), Vector2(28, 28), color)
			_rect(box_pos + Vector2(31, 10), Vector2(10, 48), color.lightened(0.08))
		"tube":
			color = Color(0.30, 0.58, 0.86)
			_rect(box_pos + Vector2(12, 31), Vector2(42, 14), color)
			_rect(box_pos + Vector2(52, 24), Vector2(12, 28), color.lightened(0.12))
		"objective":
			color = Color(0.66, 0.88, 0.94)
			_rect(box_pos + Vector2(24, 14), Vector2(24, 42), color)
			_rect(box_pos + Vector2(20, 25), Vector2(32, 8), color.darkened(0.12))
		"eyepiece":
			color = Color(0.46, 0.54, 0.62)
			_rect(box_pos + Vector2(22, 24), Vector2(30, 26), color)
			_rect(box_pos + Vector2(12, 30), Vector2(14, 14), color.darkened(0.10))
		_:
			color = Color(0.38, 0.68, 0.92)
			_rect(box_pos + Vector2(12, 30), Vector2(42, 12), color)
			_rect(box_pos + Vector2(52, 24), Vector2(10, 24), color.lightened(0.12))


func _panel(pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 3, 4))
	add_child(panel)
	_panel_corners(pos, panel_size, border)
	return panel


func _button(text: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.13, 0.22), BLUE_EDGE, 2, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.22, 0.34), BRASS, 2, 3))
	button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.14, 0.08), BRASS, 2, 3))
	return button


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _panel_corners(pos: Vector2, panel_size: Vector2, color: Color) -> void:
	_rect(pos + Vector2(4, 4), Vector2(12, 3), color)
	_rect(pos + Vector2(4, 4), Vector2(3, 12), color)
	_rect(pos + Vector2(panel_size.x - 16, 4), Vector2(12, 3), color)
	_rect(pos + Vector2(panel_size.x - 7, 4), Vector2(3, 12), color)
	_rect(pos + Vector2(4, panel_size.y - 7), Vector2(12, 3), color)
	_rect(pos + Vector2(4, panel_size.y - 16), Vector2(3, 12), color)
	_rect(pos + Vector2(panel_size.x - 16, panel_size.y - 7), Vector2(12, 3), color)
	_rect(pos + Vector2(panel_size.x - 7, panel_size.y - 16), Vector2(3, 12), color)


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label(text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
