extends Control

const SKY_RECT := Rect2(32, 96, 672, 584)
const COL_BG := Color(0.004, 0.006, 0.014)
const COL_NAVY := Color(0.030, 0.045, 0.085, 0.96)
const COL_PANEL := Color(0.050, 0.070, 0.120, 0.96)
const COL_GOLD := Color(0.78, 0.56, 0.28)
const COL_GOLD_LIGHT := Color(0.95, 0.76, 0.42)
const COL_BLUE_BORDER := Color(0.17, 0.25, 0.40)
const COL_TEXT := Color(0.96, 0.94, 0.88)

var selected_label: Label
var selected_object_id := ""
var target_id := ""


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	target_id = str(GameManager.current_level().get("target_object_id", "moon"))

	_rect(self, Vector2.ZERO, Vector2(1024, 768), COL_BG)
	_pixel_frame(self, Vector2(12, 10), Vector2(1000, 744), Color(0.006, 0.008, 0.018), COL_BLUE_BORDER, COL_GOLD)
	_title_bar("Sky Observation")
	var sky := _build_sky_canvas()
	_build_mission_panel()
	_add_background_stars(sky)
	_add_direction_markers(sky)
	_add_celestial_targets(sky)


func _title_bar(title_text: String) -> void:
	_pixel_panel(self, Vector2(28, 20), Vector2(968, 60), COL_NAVY, COL_BLUE_BORDER)
	var title := _label(title_text, 34, COL_TEXT)
	title.position = Vector2(28, 28)
	title.size = Vector2(968, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(title)


func _build_sky_canvas() -> Control:
	var sky := Control.new()
	sky.position = SKY_RECT.position
	sky.size = SKY_RECT.size
	add_child(sky)
	_gold_panel(sky, Vector2.ZERO, sky.size)
	return sky


func _build_mission_panel() -> void:
	_gold_panel(self, Vector2(736, 96), Vector2(252, 584))
	var header := _label("Mission Panel", 22, COL_TEXT)
	header.position = Vector2(756, 108)
	header.size = Vector2(212, 30)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(header)

	var panel := VBoxContainer.new()
	panel.position = Vector2(758, 150)
	panel.size = Vector2(208, 500)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)

	var level := GameManager.current_level()
	panel.add_child(_label(GameManager.dict_text(level, "title"), 18, COL_TEXT))
	panel.add_child(_label("Hint:\n" + _mission_hint_text(level), 13, Color(0.80, 0.88, 0.96)))

	selected_label = _label(_selected_text(), 15, Color(0.94, 0.92, 0.84))
	panel.add_child(selected_label)

	var observe := _pixel_button("Observe")
	observe.pressed.connect(_observe)
	panel.add_child(observe)

	var back := _pixel_button("Back")
	back.pressed.connect(func() -> void: GameManager.go("observatory"))
	panel.add_child(back)

	panel.add_child(_label(_finder_text(), 13, Color(0.76, 0.83, 0.86)))


func _mission_hint_text(level: Dictionary) -> String:
	if str(level.get("target_object_id", "")) == "moon":
		return "Look for the brightest round object in the sky.\n寻找天空中最明亮的圆形目标。"
	return GameManager.dict_text(level, "hint_text")


func _add_direction_markers(parent: Control) -> void:
	_add_direction_label(parent, "North / 北", Vector2(281, 16), HORIZONTAL_ALIGNMENT_CENTER)
	_add_direction_label(parent, "South / 南", Vector2(281, 548), HORIZONTAL_ALIGNMENT_CENTER)
	_add_direction_label(parent, "West / 西", Vector2(18, 282), HORIZONTAL_ALIGNMENT_LEFT)
	_add_direction_label(parent, "East / 东", Vector2(548, 282), HORIZONTAL_ALIGNMENT_RIGHT)


func _add_direction_label(parent: Control, text: String, pos: Vector2, align: HorizontalAlignment) -> void:
	var label := _label(text, 12, Color(0.56, 0.66, 0.78))
	label.position = pos
	label.size = Vector2(110, 20)
	label.horizontal_alignment = align
	parent.add_child(label)


func _add_celestial_targets(parent: Control) -> void:
	for obj in GameManager.objects_data:
		var id := str(obj.get("id", ""))
		var selected := id == selected_object_id
		var is_target := id == target_id
		var pos := _sky_position(obj)
		if _finder_installed() and is_target:
			_draw_finder_assist(parent, pos)
		_draw_sky_object(parent, id, pos, selected)
		_add_target_hotspot(parent, id, pos)


func _draw_sky_object(parent: Control, id: String, pos: Vector2, selected: bool) -> void:
	match id:
		"moon":
			_draw_sky_moon(parent, pos, selected)
		"polaris":
			_draw_sky_polaris(parent, pos, selected)
		"sirius":
			_draw_sky_sirius(parent, pos, selected)
		"betelgeuse":
			_draw_sky_betelgeuse(parent, pos, selected)
		"mars":
			_draw_sky_mars(parent, pos, selected)
		"jupiter":
			_draw_sky_jupiter(parent, pos, selected)
		"orion_nebula":
			_draw_sky_nebula(parent, pos, Color(0.64, 0.34, 0.90, 0.46), selected)
		"andromeda":
			_draw_sky_galaxy(parent, pos, Color(0.48, 0.62, 0.92, 0.40), selected)
		_:
			_draw_sky_star(parent, pos, Color(0.88, 0.90, 1.0, 0.80), 8, selected)


func _draw_sky_moon(parent: Control, pos: Vector2, selected: bool) -> void:
	var center := pos + Vector2(28, 28)
	_draw_selection(parent, center, 76, selected)
	_circle(parent, center - Vector2(25, 25), Vector2(50, 50), Color(0.94, 0.86, 0.56, 0.98), Color(1.0, 0.94, 0.68, 0.92), 2)
	_circle(parent, center - Vector2(2, 0), Vector2(38, 44), Color(0.010, 0.016, 0.055, 0.42), Color(0, 0, 0, 0), 0)
	_rect(parent, center + Vector2(-12, -9), Vector2(6, 6), Color(0.55, 0.50, 0.34, 0.45))
	_rect(parent, center + Vector2(7, 10), Vector2(4, 4), Color(0.55, 0.50, 0.34, 0.35))


func _draw_sky_polaris(parent: Control, pos: Vector2, selected: bool) -> void:
	_draw_sky_star(parent, pos, Color(0.96, 0.97, 1.0, 0.96), 8, selected)


func _draw_sky_sirius(parent: Control, pos: Vector2, selected: bool) -> void:
	_draw_sky_star(parent, pos, Color(0.66, 0.84, 1.0, 0.98), 14, selected)


func _draw_sky_betelgeuse(parent: Control, pos: Vector2, selected: bool) -> void:
	_draw_sky_star(parent, pos, Color(1.0, 0.36, 0.20, 0.96), 12, selected)


func _draw_sky_mars(parent: Control, pos: Vector2, selected: bool) -> void:
	_draw_sky_planet(parent, pos, Color(0.96, 0.30, 0.12, 0.96), 11, selected)


func _draw_sky_jupiter(parent: Control, pos: Vector2, selected: bool) -> void:
	_draw_sky_planet(parent, pos, Color(0.92, 0.78, 0.48, 0.96), 16, selected)


func _draw_sky_star(parent: Control, pos: Vector2, color: Color, size: int, selected: bool) -> void:
	var center := pos + Vector2(size, size)
	_draw_selection(parent, center, float(size * 4), selected)
	_rect(parent, center - Vector2(size, 1), Vector2(size * 2, 2), color)
	_rect(parent, center - Vector2(1, size), Vector2(2, size * 2), color)
	_rect(parent, center - Vector2(2, 2), Vector2(4, 4), color.lightened(0.18))
	if size >= 13:
		_draw_line(parent, center + Vector2(-size * 0.75, -size * 0.75), center + Vector2(size * 0.75, size * 0.75), Color(color.r, color.g, color.b, color.a * 0.52), 2)
		_draw_line(parent, center + Vector2(size * 0.75, -size * 0.75), center + Vector2(-size * 0.75, size * 0.75), Color(color.r, color.g, color.b, color.a * 0.52), 2)


func _draw_sky_planet(parent: Control, pos: Vector2, color: Color, radius: int, selected: bool) -> void:
	var center := pos + Vector2(radius, radius)
	_draw_selection(parent, center, float(radius * 4), selected)
	_circle(parent, center - Vector2(radius, radius), Vector2(radius * 2, radius * 2), color, color.lightened(0.18), 1)
	if radius >= 15:
		_rect(parent, center + Vector2(-radius + 4, -3), Vector2(radius * 2 - 8, 3), color.darkened(0.20))
		_rect(parent, center + Vector2(-radius + 7, 5), Vector2(radius * 2 - 14, 2), color.lightened(0.12))


func _draw_sky_nebula(parent: Control, pos: Vector2, color: Color, selected: bool) -> void:
	var center := pos + Vector2(24, 18)
	_draw_selection(parent, center, 64, selected)
	_circle(parent, center - Vector2(26, 14), Vector2(52, 28), color, color.lightened(0.12), 1)
	_circle(parent, center - Vector2(14, 22), Vector2(34, 34), Color(color.r, color.g * 0.82, color.b, color.a * 0.60), Color(0, 0, 0, 0), 0)
	_rect(parent, center + Vector2(-10, -2), Vector2(20, 4), color.lightened(0.20))


func _draw_sky_galaxy(parent: Control, pos: Vector2, color: Color, selected: bool) -> void:
	var center := pos + Vector2(28, 16)
	_draw_selection(parent, center, 72, selected)
	_circle(parent, center - Vector2(34, 13), Vector2(68, 26), color, color.lightened(0.12), 1)
	_rect(parent, center + Vector2(-25, -2), Vector2(50, 4), color.lightened(0.26))
	_rect(parent, center + Vector2(-14, 5), Vector2(28, 3), Color(color.r, color.g, color.b, color.a * 0.45))


func _draw_selection(parent: Control, center: Vector2, size: float, selected: bool) -> void:
	if not selected:
		return
	var pos := center - Vector2(size, size) * 0.5
	_circle(parent, pos, Vector2(size, size), Color(0.95, 0.78, 0.26, 0.08), COL_GOLD_LIGHT, 2)
	var tick := 8.0
	_rect(parent, pos + Vector2(-2, -2), Vector2(tick, 2), COL_GOLD_LIGHT)
	_rect(parent, pos + Vector2(-2, -2), Vector2(2, tick), COL_GOLD_LIGHT)
	_rect(parent, pos + Vector2(size - tick + 2, -2), Vector2(tick, 2), COL_GOLD_LIGHT)
	_rect(parent, pos + Vector2(size, -2), Vector2(2, tick), COL_GOLD_LIGHT)


func _draw_finder_assist(parent: Control, pos: Vector2) -> void:
	var center := pos + Vector2(28, 28)
	_circle(parent, center - Vector2(48, 48), Vector2(96, 96), Color(0.28, 0.54, 0.84, 0.05), Color(0.44, 0.72, 1.0, 0.28), 2)


func _add_target_hotspot(parent: Control, id: String, pos: Vector2) -> void:
	var button := Button.new()
	button.position = pos - Vector2(10, 10)
	button.size = _hotspot_size(id)
	button.text = ""
	button.tooltip_text = _tooltip_for(id)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.pressed.connect(_select_object.bind(id))
	parent.add_child(button)


func _select_object(object_id: String) -> void:
	selected_object_id = object_id
	GameManager.selected_object_id = object_id
	_build()


func _observe() -> void:
	if selected_object_id == "":
		selected_label.text = "Select a sky target before observing.\n请先选择天空中的目标。"
		return
	GameManager.selected_object_id = selected_object_id
	GameManager.go("telescope")


func _selected_text() -> String:
	if selected_object_id == "":
		return "No target selected.\n尚未选择目标。"
	var obj := GameManager.get_object(selected_object_id)
	return "Selected target\n已选择目标\n" + GameManager.dict_text(obj, "short_hint")


func _finder_text() -> String:
	if _finder_installed():
		return "Finder Scope active.\n寻星镜已启用。\nA wider assist circle appears near the mission target."
	return "Finder Scope not installed.\n寻星镜未安装。\nUse the mission hint and sky directions."


func _finder_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var finder: Dictionary = state.get("finder_scope", {})
	return bool(finder.get("installed", false))


func _sky_position(obj: Dictionary) -> Vector2:
	var x := clampf(float(obj.get("x", 100)) * 0.76, 38.0, 600.0)
	var y := clampf(float(obj.get("y", 100)) * 0.90, 54.0, 512.0)
	return Vector2(x, y)


func _hotspot_size(id: String) -> Vector2:
	match id:
		"moon": return Vector2(76, 76)
		"jupiter", "orion_nebula", "andromeda": return Vector2(70, 58)
		"sirius", "betelgeuse", "mars": return Vector2(54, 54)
	return Vector2(46, 46)


func _tooltip_for(id: String) -> String:
	var obj := GameManager.get_object(id)
	return GameManager.dict_text(obj, "short_hint")


func _add_background_stars(parent: Control) -> void:
	for i in range(125):
		var star := ColorRect.new()
		var bright := 0.42 + fmod(float(i), 6.0) * 0.08
		star.color = Color(bright, bright + 0.04, 0.92 + fmod(float(i), 3.0) * 0.04, 0.82)
		star.position = Vector2(fmod(float(i * 97), 632.0) + 20, fmod(float(i * 53), 520.0) + 36)
		star.size = Vector2(1 + fmod(float(i), 2.0), 1 + fmod(float(i), 2.0))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(star)


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
	button.custom_minimum_size = Vector2(190, 44)
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
