extends Control

const COL_BG := Color(0.004, 0.006, 0.014)
const COL_NAVY := Color(0.030, 0.045, 0.085, 0.96)
const COL_PANEL := Color(0.050, 0.070, 0.120, 0.96)
const COL_GOLD := Color(0.78, 0.56, 0.28)
const COL_GOLD_LIGHT := Color(0.95, 0.76, 0.42)
const COL_BLUE_BORDER := Color(0.17, 0.25, 0.40)
const COL_TEXT := Color(0.96, 0.94, 0.88)

var feedback_label: Label
var choices_box: VBoxContainer
var observation: Dictionary
var selected_object: Dictionary


func _ready() -> void:
	selected_object = GameManager.get_object(GameManager.selected_object_id)
	if selected_object.is_empty():
		selected_object = GameManager.current_target()
		GameManager.selected_object_id = str(selected_object.get("id", ""))
	observation = GameManager.evaluate_selected_object()
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(self, Vector2.ZERO, Vector2(1024, 768), COL_BG)
	_pixel_frame(self, Vector2(12, 10), Vector2(1000, 744), Color(0.006, 0.008, 0.018), COL_BLUE_BORDER, COL_GOLD)
	_title_bar("Telescope View")

	var view := _scope_visual()
	view.position = Vector2(54, 98)
	add_child(view)
	_build_observation_panel()


func _title_bar(title_text: String) -> void:
	_pixel_panel(self, Vector2(28, 20), Vector2(968, 60), COL_NAVY, COL_BLUE_BORDER)
	var title := _label(title_text, 34, COL_TEXT)
	title.position = Vector2(28, 28)
	title.size = Vector2(968, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(title)


func _build_observation_panel() -> void:
	_gold_panel(self, Vector2(752, 106), Vector2(236, 594))
	var header := _label("Observation Quality", 22, COL_TEXT)
	header.position = Vector2(770, 118)
	header.size = Vector2(200, 30)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(header)

	var panel := VBoxContainer.new()
	panel.position = Vector2(772, 158)
	panel.size = Vector2(194, 520)
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)

	var quality := str(observation.get("quality", "Unknown"))
	panel.add_child(_label("Observed object:\n" + _mystery_description(selected_object), 14, COL_TEXT))
	panel.add_child(_label("Quality: " + quality, 18, _quality_color(quality)))
	_add_stat_bars(panel)
	feedback_label = _label(GameManager.text(str(observation.get("feedback_en", "")), str(observation.get("feedback_zh", ""))), 13, Color(0.86, 0.90, 0.88))
	panel.add_child(feedback_label)
	panel.add_child(_label("Identify", 20, Color(0.98, 0.82, 0.50)))

	choices_box = panel
	_add_identify_choices()

	var retry := _pixel_button("Retry")
	retry.pressed.connect(func() -> void: GameManager.go("sky"))
	panel.add_child(retry)

	var back := _pixel_button("Back")
	back.pressed.connect(func() -> void: GameManager.go("assembly"))
	panel.add_child(back)


func _scope_visual() -> Control:
	var root := Control.new()
	root.size = Vector2(640, 620)
	var center := Vector2(318, 300)
	_circle(root, center - Vector2(270, 270), Vector2(540, 540), Color(0.05, 0.036, 0.026), COL_GOLD_LIGHT, 8)
	_circle(root, center - Vector2(252, 252), Vector2(504, 504), Color(0.012, 0.018, 0.052), Color(0.31, 0.23, 0.15), 6)
	_circle(root, center - Vector2(218, 218), Vector2(436, 436), Color(0.0, 0.0, 0.0), Color(0.06, 0.08, 0.15), 5)
	_draw_lens_shutters(root, center)
	_add_scope_stars(root, center)
	_add_target_visual(root, center)
	_add_quality_noise(root, center)
	return root


func _draw_lens_shutters(parent: Control, center: Vector2) -> void:
	var shade := Color(0.045, 0.065, 0.125, 0.76)
	_draw_line(parent, center + Vector2(-128, -188), center + Vector2(0, -74), shade, 70)
	_draw_line(parent, center + Vector2(128, -188), center + Vector2(0, -74), shade, 70)
	_draw_line(parent, center + Vector2(-128, 188), center + Vector2(0, 74), shade, 70)
	_draw_line(parent, center + Vector2(128, 188), center + Vector2(0, 74), shade, 70)
	_circle(parent, center - Vector2(72, 72), Vector2(144, 144), Color(0.0, 0.0, 0.0, 0.68), Color(0, 0, 0, 0), 0)


func _add_target_visual(parent: Control, lens_center: Vector2) -> void:
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	var center := lens_center + _effect_offset(effect, quality)
	var alpha := _quality_alpha(quality)
	if effect == "dim":
		alpha *= 0.48
	if effect == "blurry":
		alpha *= 0.70
	match id:
		"moon":
			_draw_moon(parent, center, alpha, effect)
		"polaris":
			_draw_star(parent, center, Color(0.95, 0.96, 1.0, alpha), 9, effect)
		"sirius":
			_draw_star(parent, center, Color(0.66, 0.84, 1.0, alpha), 16, effect)
		"betelgeuse":
			_draw_star(parent, center, Color(1.0, 0.34, 0.20, alpha), 13, effect)
		"mars":
			_draw_planet(parent, center, Color(0.94, 0.30, 0.12, alpha), 24, false, effect)
		"jupiter":
			_draw_planet(parent, center, Color(0.88, 0.74, 0.48, alpha), 40, true, effect)
		"orion_nebula":
			_draw_fog(parent, center, Color(0.58, 0.34, 0.90, alpha), Vector2(132, 78), effect)
		"andromeda":
			_draw_fog(parent, center, Color(0.46, 0.62, 0.88, alpha), Vector2(174, 58), effect)
		_:
			_draw_star(parent, center, Color(0.90, 0.92, 1.0, alpha), 9, effect)


func _draw_moon(parent: Control, center: Vector2, alpha: float, effect: String) -> void:
	_circle(parent, center - Vector2(58, 58), Vector2(116, 116), Color(0.88, 0.80, 0.54, alpha), Color(0.98, 0.88, 0.64, alpha), 2)
	_circle(parent, center + Vector2(-26, -16), Vector2(22, 22), Color(0.56, 0.50, 0.36, alpha * 0.50), Color(0, 0, 0, 0), 0)
	_circle(parent, center + Vector2(22, 16), Vector2(16, 16), Color(0.56, 0.50, 0.36, alpha * 0.34), Color(0, 0, 0, 0), 0)
	_circle(parent, center + Vector2(-4, 28), Vector2(13, 13), Color(0.56, 0.50, 0.36, alpha * 0.28), Color(0, 0, 0, 0), 0)
	if effect == "blurry":
		_circle(parent, center - Vector2(66, 53), Vector2(116, 116), Color(0.88, 0.80, 0.54, alpha * 0.23), Color(0, 0, 0, 0), 0)


func _draw_star(parent: Control, center: Vector2, color: Color, size: int, effect: String) -> void:
	_rect(parent, center - Vector2(size, 2), Vector2(size * 2, 4), color)
	_rect(parent, center - Vector2(2, size), Vector2(4, size * 2), color)
	_circle(parent, center - Vector2(size * 0.5, size * 0.5), Vector2(size, size), color.lightened(0.18), Color(0, 0, 0, 0), 0)
	if size >= 14:
		_draw_line(parent, center + Vector2(-size, -size), center + Vector2(size, size), Color(color.r, color.g, color.b, color.a * 0.45), 3)
		_draw_line(parent, center + Vector2(size, -size), center + Vector2(-size, size), Color(color.r, color.g, color.b, color.a * 0.45), 3)
	if effect == "blurry":
		_rect(parent, center + Vector2(7, 5) - Vector2(size, 2), Vector2(size * 2, 4), Color(color.r, color.g, color.b, color.a * 0.28))


func _draw_planet(parent: Control, center: Vector2, color: Color, radius: int, striped: bool, effect: String) -> void:
	_circle(parent, center - Vector2(radius, radius), Vector2(radius * 2, radius * 2), color, color.lightened(0.12), 2)
	_rect(parent, center + Vector2(-radius + 7, -3), Vector2(radius * 2 - 14, 5), color.darkened(0.20))
	if striped:
		_rect(parent, center + Vector2(-radius + 8, 8), Vector2(radius * 2 - 16, 4), color.lightened(0.18))
		_rect(parent, center + Vector2(-radius + 12, -14), Vector2(radius * 2 - 24, 3), color.darkened(0.10))
	if effect == "blurry":
		_circle(parent, center - Vector2(radius + 8, radius - 4), Vector2(radius * 2, radius * 2), Color(color.r, color.g, color.b, color.a * 0.22), Color(0, 0, 0, 0), 0)


func _draw_fog(parent: Control, center: Vector2, color: Color, size: Vector2, effect: String) -> void:
	_circle(parent, center - size * 0.5, size, color, color.lightened(0.10), 1)
	_circle(parent, center - size * 0.34 + Vector2(28, 8), size * 0.62, Color(color.r, color.g, color.b, color.a * 0.44), Color(0, 0, 0, 0), 0)
	_rect(parent, center + Vector2(-size.x * 0.22, -2), Vector2(size.x * 0.44, 4), color.lightened(0.24))
	if effect == "blurry":
		_circle(parent, center - size * 0.5 + Vector2(12, -8), size, Color(color.r, color.g, color.b, color.a * 0.24), Color(0, 0, 0, 0), 0)


func _add_scope_stars(parent: Control, lens_center: Vector2) -> void:
	for i in range(34):
		var pos := lens_center + Vector2(-178 + fmod(float(i * 83), 355.0), -178 + fmod(float(i * 47), 350.0))
		if (pos - lens_center).length() > 205:
			continue
		var bright := 0.50 + fmod(float(i), 5.0) * 0.08
		_rect(parent, pos, Vector2(2, 2), Color(bright, bright + 0.03, 0.92, 0.50))


func _add_quality_noise(parent: Control, lens_center: Vector2) -> void:
	var quality := str(observation.get("quality", "Unknown"))
	var count := 0
	if quality == "Fair":
		count = 18
	elif quality == "Poor":
		count = 42
	elif quality == "Failed":
		count = 76
	for i in range(count):
		var pos := lens_center + Vector2(-194 + fmod(float(i * 71), 390.0), -190 + fmod(float(i * 43), 382.0))
		if (pos - lens_center).length() <= 208:
			_rect(parent, pos, Vector2(3, 3), Color(0.70, 0.78, 0.88, 0.08 + fmod(float(i), 4.0) * 0.02))


func _add_stat_bars(panel: VBoxContainer) -> void:
	var stats := GameManager.calculate_stats()
	for row in [
		{"name": "Light", "value": float(stats.get("light_score", 0.0))},
		{"name": "Clarity", "value": float(stats.get("clarity_score", 0.0))},
		{"name": "Stability", "value": float(stats.get("stability_score", 0.0))}
	]:
		var label := _label("%s: %s" % [row["name"], snapped(float(row["value"]), 0.1)], 13, Color(0.78, 0.86, 0.90))
		panel.add_child(label)


func _add_identify_choices() -> void:
	var ids: Array[String] = []
	_add_unique(ids, str(selected_object.get("id", "")))
	_add_unique(ids, str(GameManager.current_target().get("id", "")))
	for id in _distractors_for(str(selected_object.get("id", ""))):
		_add_unique(ids, id)
	for id in ids:
		var obj := GameManager.get_object(id)
		if obj.is_empty():
			continue
		var button := _pixel_button(GameManager.dict_text(obj, "name"))
		button.pressed.connect(_identify.bind(id))
		choices_box.add_child(button)


func _identify(choice_id: String) -> void:
	if choice_id != str(selected_object.get("id", "")):
		feedback_label.text = "That does not match what you observed. Try again.\n这和刚才观测到的目标不匹配，请再试一次。"
		return
	var completed := GameManager.complete_current_mission(choice_id, observation)
	if completed:
		GameManager.go("card")
		return
	var target := GameManager.current_target()
	if choice_id != str(target.get("id", "")):
		feedback_label.text = "Correct identification, but this is not the current mission target.\n识别正确，但不是当前任务目标。"
	else:
		feedback_label.text = "The object is identified, but observation quality is not high enough.\n目标识别正确，但观测质量还不够。"


func _distractors_for(id: String) -> Array[String]:
	match id:
		"moon": return ["jupiter", "sirius"]
		"mars": return ["jupiter", "betelgeuse"]
		"jupiter": return ["mars", "moon"]
		"orion_nebula": return ["andromeda", "betelgeuse"]
		"andromeda": return ["orion_nebula", "sirius"]
	return ["sirius", "betelgeuse"]


func _mystery_description(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	match id:
		"moon":
			return "bright round object\n明亮圆形目标"
		"mars", "jupiter":
			return "small disk-like object\n小圆盘状目标"
		"orion_nebula":
			return "faint cloud-like object\n淡淡云雾状目标"
		"andromeda":
			return "faint oval glow\n淡淡椭圆光斑"
	return "star-like object\n星点状目标"


func _effect_offset(effect: String, quality: String) -> Vector2:
	if effect == "shaky":
		return Vector2(10, -7)
	if quality == "Poor":
		return Vector2(4, 3)
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


func _pixel_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 42)
	button.add_theme_font_size_override("font_size", 15)
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


func _draw_line(parent: Control, from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([from_pos, to_pos])
	line.default_color = color
	line.width = width
	parent.add_child(line)
	return line


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


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
