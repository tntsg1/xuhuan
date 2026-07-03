extends Control

const W := 1024.0
const H := 768.0
const BG_TEXTURE := "res://assets/reference/sky_observation_ui_bg_1024.png"
const SkyPositionServiceScript := preload("res://scripts/systems/sky_position_service.gd")
const SKY_RECT := Rect2(32, 48, 700, 600)

const PANEL_COVER := Color(0.026, 0.048, 0.080, 1.0)
const SKY_BG := Color(0.006, 0.013, 0.035, 1.0)
const SKY_GRID := Color(0.12, 0.42, 0.74, 0.28)
const TEXT := Color(0.96, 0.92, 0.82)
const GOLD := Color(0.96, 0.72, 0.30)
const GREEN := Color(0.42, 0.95, 0.50)
const MUTED := Color(0.72, 0.78, 0.84)
const WARNING := Color(1.0, 0.72, 0.35)

const OBSERVE_RECT := Rect2(755, 538, 239, 80)
const BACK_RECT := Rect2(758, 652, 236, 72)

var selected_object_id := ""
var target_id := ""
var sky_service: RefCounted
var sky_data: Dictionary = {}
var target_rects: Dictionary = {}
var selected_title: Label
var selected_detail: Label
var feedback_label: Label
var finder_label: Label
var selection_frame: Control
var finder_frame: Control


func _ready() -> void:
	target_id = str(GameManager.current_level().get("target_object_id", "moon"))
	selected_object_id = ""
	GameManager.selected_object_id = ""
	sky_service = SkyPositionServiceScript.new()
	sky_data = sky_service.get_sky_positions(SKY_RECT)
	_build()
	sky_service.request_online_planet_data(self, SKY_RECT, _apply_online_sky_data)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	target_rects.clear()

	_draw_background()
	_draw_dynamic_sky_canvas()
	_cover_baked_text()
	_draw_dynamic_text()
	_draw_target_icons_and_hitboxes()
	_draw_action_hitboxes()
	_update_selection_visual()


func _apply_online_sky_data(online_data: Dictionary) -> void:
	for object_id_value in online_data.keys():
		var object_id: String = str(object_id_value)
		sky_data[object_id] = online_data[object_id]
	_build()


func _draw_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.position = Vector2.ZERO
	bg.size = Vector2(W, H)
	bg.ignore_texture_size = true
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _draw_dynamic_sky_canvas() -> void:
	_rect(SKY_RECT.position, SKY_RECT.size, SKY_BG)
	_draw_sky_grid()
	_draw_background_stars()


func _draw_sky_grid() -> void:
	var center := SKY_RECT.position + SKY_RECT.size * 0.5
	var max_radius := min(SKY_RECT.size.x, SKY_RECT.size.y) * 0.46
	for index in range(1, 5):
		var radius := max_radius * float(index) / 4.0
		_circle(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0), Color(0, 0, 0, 0), SKY_GRID, 2)
	for index in range(0, 8):
		var angle := deg_to_rad(float(index) * 45.0)
		var end := center + Vector2(cos(angle), sin(angle)) * max_radius
		_draw_line(center, end, SKY_GRID, 2.0)
	_label("N", center + Vector2(-6, -max_radius - 22), Vector2(24, 18), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label("E", center + Vector2(max_radius + 6, -9), Vector2(24, 18), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label("S", center + Vector2(-6, max_radius + 4), Vector2(24, 18), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label("W", center + Vector2(-max_radius - 28, -9), Vector2(24, 18), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_background_stars() -> void:
	for index in range(90):
		var x := SKY_RECT.position.x + 14.0 + fmod(float(index * 83), SKY_RECT.size.x - 28.0)
		var y := SKY_RECT.position.y + 14.0 + fmod(float(index * 47), SKY_RECT.size.y - 28.0)
		var size := 1.0 + fmod(float(index), 3.0)
		var brightness := 0.52 + fmod(float(index), 5.0) * 0.09
		_rect(Vector2(x, y), Vector2(size, size), Color(brightness, brightness, 0.95, 0.72))


func _cover_baked_text() -> void:
	# The supplied image provides the frame and instruments; these small covers
	# replace only baked sample copy with current mission data.
	_rect(Vector2(744, 86), Vector2(246, 150), PANEL_COVER)
	_rect(Vector2(742, 292), Vector2(268, 206), PANEL_COVER)
	_rect(Vector2(748, 620), Vector2(246, 24), PANEL_COVER)


func _draw_dynamic_text() -> void:
	var level: Dictionary = GameManager.current_level()
	var target: Dictionary = GameManager.get_object(target_id)
	var target_sky: Dictionary = _sky_item(target_id)

	_label("Target:", Vector2(762, 112), Vector2(70, 24), 16, WARNING)
	_label(str(target.get("name_en", target_id)), Vector2(834, 112), Vector2(150, 24), 16, Color(0.84, 0.62, 1.0))

	_label("Hint:", Vector2(762, 154), Vector2(56, 24), 16, WARNING)
	var hint := _mission_hint(level, target)
	var hint_label := _label(hint, Vector2(762, 180), Vector2(220, 44), 12, TEXT)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("Tonight: " + str(target_sky.get("visibility_text", "Offline estimate")), Vector2(762, 218), Vector2(220, 18), 11, _visibility_color(target_sky))

	selected_title = _label("", Vector2(764, 322), Vector2(220, 24), 15, Color(0.84, 0.62, 1.0))
	selected_detail = _label("", Vector2(764, 350), Vector2(220, 126), 11, TEXT)
	selected_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label = _label("", Vector2(750, 456), Vector2(238, 24), 13, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
	finder_label = _label(_finder_text(), Vector2(750, 624), Vector2(240, 18), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_update_selected_text()


func _mission_hint(level: Dictionary, target: Dictionary) -> String:
	if str(target.get("id", "")) == "moon":
		return "Look for the brightest round object."
	match str(target.get("id", "")):
		"polaris":
			return "Look toward the northern sky."
		"sirius":
			return "Find a bright blue-white star."
		"betelgeuse":
			return "Find a reddish star in Orion."
		"mars":
			return "Find a reddish planet."
		"jupiter":
			return "Find the large striped planet."
		"orion_nebula":
			return "Find the purple cloud near Orion."
		"andromeda":
			return "Find a faint oval galaxy."
	return str(level.get("hint_text_en", "Use the sky map and choose the mission target."))


func _draw_target_icons_and_hitboxes() -> void:
	for placed_value in _target_layout():
		var placed: Dictionary = placed_value
		var object_id: String = str(placed.get("id", ""))
		var item: Dictionary = placed.get("item", {})
		var rect: Rect2 = placed.get("rect", Rect2())
		target_rects[object_id] = rect
		_draw_icon(item, rect)
		_add_target_button(object_id, rect.grow(8.0))


func _target_layout() -> Array:
	var ids: Array = sky_data.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _placement_priority(str(a)) < _placement_priority(str(b))
	)
	var placed_rects: Array[Rect2] = []
	var layout: Array = []
	for id_value in ids:
		var object_id: String = str(id_value)
		var item: Dictionary = sky_data[object_id]
		var size: Vector2 = _icon_size(str(item.get("icon_type", "white_star")))
		var center: Vector2 = _clamp_center_to_sky(_item_screen_pos(item), size)
		var base_rect := Rect2(center - size * 0.5, size)
		var rect: Rect2 = _avoid_target_overlap(base_rect, size, placed_rects)
		placed_rects.append(rect.grow(12.0))
		layout.append({
			"id": object_id,
			"item": item,
			"rect": rect
		})
	return layout


func _placement_priority(object_id: String) -> int:
	if object_id == target_id:
		return 0
	match object_id:
		"moon":
			return 1
		"jupiter":
			return 2
		"andromeda":
			return 3
		"orion_nebula":
			return 4
		"mars":
			return 5
		"sirius":
			return 6
		"betelgeuse":
			return 7
		"polaris":
			return 8
	return 20


func _avoid_target_overlap(base_rect: Rect2, size: Vector2, placed_rects: Array[Rect2]) -> Rect2:
	var base_center: Vector2 = base_rect.position + base_rect.size * 0.5
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for radius in [44.0, 72.0, 104.0, 138.0, 176.0]:
		for angle_degrees in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
			var angle: float = deg_to_rad(angle_degrees)
			offsets.append(Vector2(cos(angle), sin(angle)) * radius)

	var best_rect: Rect2 = base_rect
	var best_score := 99999999.0
	for offset in offsets:
		var center: Vector2 = _clamp_center_to_sky(base_center + offset, size)
		var candidate := Rect2(center - size * 0.5, size)
		var score: float = _overlap_score(candidate.grow(12.0), placed_rects) + offset.length() * 0.015
		if score < best_score:
			best_score = score
			best_rect = candidate
		if score <= 0.01:
			return candidate
	return best_rect


func _overlap_score(rect: Rect2, placed_rects: Array[Rect2]) -> float:
	var score := 0.0
	for placed in placed_rects:
		if rect.intersects(placed):
			var overlap: Rect2 = rect.intersection(placed)
			score += overlap.size.x * overlap.size.y
	return score


func _draw_icon(item: Dictionary, rect: Rect2) -> void:
	var icon_type := str(item.get("icon_type", "white_star"))
	var visible_alpha := 1.0
	if float(item.get("altitude", 0.0)) < 0.0:
		visible_alpha = 0.42
	elif str(item.get("visibility_text", "")) == "Low on horizon":
		visible_alpha = 0.68
	match icon_type:
		"moon":
			_draw_moon(rect, visible_alpha)
		"red_planet":
			_draw_planet(rect, Color(0.92, 0.22, 0.12, visible_alpha), false)
		"striped_planet":
			_draw_planet(rect, Color(0.92, 0.74, 0.46, visible_alpha), true)
		"blue_star":
			_draw_star(rect, Color(0.62, 0.82, 1.0, visible_alpha), true)
		"red_star":
			_draw_star(rect, Color(1.0, 0.35, 0.17, visible_alpha), true)
		"purple_nebula":
			_draw_nebula(rect, Color(0.66, 0.34, 0.95, visible_alpha))
		"blue_galaxy":
			_draw_galaxy(rect, Color(0.48, 0.62, 0.95, visible_alpha))
		_:
			_draw_star(rect, Color(0.94, 0.96, 1.0, visible_alpha), false)


func _draw_moon(rect: Rect2, alpha: float) -> void:
	_circle(rect.position, rect.size, Color(0.86, 0.82, 0.68, alpha), Color(1.0, 0.92, 0.62, alpha), 2)
	_circle(rect.position + rect.size * 0.56, rect.size * 0.34, Color(0.48, 0.46, 0.40, alpha * 0.36), Color(0, 0, 0, 0), 0)
	_rect(rect.position + rect.size * Vector2(0.32, 0.34), rect.size * 0.10, Color(0.42, 0.40, 0.34, alpha * 0.48))
	_rect(rect.position + rect.size * Vector2(0.52, 0.62), rect.size * 0.07, Color(0.42, 0.40, 0.34, alpha * 0.42))


func _draw_planet(rect: Rect2, color: Color, striped: bool) -> void:
	_circle(rect.position, rect.size, color, color.lightened(0.18), 2)
	if striped:
		_rect(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.36), Vector2(rect.size.x * 0.68, 3), color.darkened(0.28))
		_rect(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.55), Vector2(rect.size.x * 0.60, 3), color.lightened(0.14))


func _draw_star(rect: Rect2, color: Color, bright: bool) -> void:
	var center := rect.position + rect.size * 0.5
	var radius: float = min(rect.size.x, rect.size.y) * 0.5
	_draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, 3)
	_draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, 3)
	if bright:
		_draw_line(center + Vector2(-radius * 0.62, -radius * 0.62), center + Vector2(radius * 0.62, radius * 0.62), Color(color.r, color.g, color.b, color.a * 0.52), 2)
		_draw_line(center + Vector2(radius * 0.62, -radius * 0.62), center + Vector2(-radius * 0.62, radius * 0.62), Color(color.r, color.g, color.b, color.a * 0.52), 2)
	_circle(center - Vector2(4, 4), Vector2(8, 8), color.lightened(0.18), Color(0, 0, 0, 0), 0)


func _draw_nebula(rect: Rect2, color: Color) -> void:
	_circle(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.24), rect.size * Vector2(0.70, 0.48), color, color.lightened(0.08), 1)
	_circle(rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.08), rect.size * Vector2(0.44, 0.58), Color(color.r, color.g * 0.82, color.b, color.a * 0.62), Color(0, 0, 0, 0), 0)
	_rect(rect.position + rect.size * Vector2(0.36, 0.48), rect.size * Vector2(0.24, 0.08), color.lightened(0.20))


func _draw_galaxy(rect: Rect2, color: Color) -> void:
	_circle(rect.position + Vector2(0, rect.size.y * 0.20), Vector2(rect.size.x, rect.size.y * 0.60), color, color.lightened(0.10), 1)
	_rect(rect.position + rect.size * Vector2(0.18, 0.46), rect.size * Vector2(0.64, 0.08), color.lightened(0.26))
	_rect(rect.position + rect.size * Vector2(0.31, 0.57), rect.size * Vector2(0.38, 0.05), Color(color.r, color.g, color.b, color.a * 0.48))


func _add_target_button(object_id: String, rect: Rect2) -> void:
	var button := _transparent_button(rect, GameManager.dict_text(GameManager.get_object(object_id), "name"))
	button.pressed.connect(_select_object.bind(object_id))
	add_child(button)


func _draw_action_hitboxes() -> void:
	var observe := _transparent_button(OBSERVE_RECT, "Observe")
	observe.pressed.connect(_observe)
	add_child(observe)

	var back := _transparent_button(BACK_RECT, "Back")
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	add_child(back)


func _transparent_button(rect: Rect2, tooltip: String) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = ""
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button


func _select_object(object_id: String) -> void:
	selected_object_id = object_id
	GameManager.selected_object_id = object_id
	feedback_label.text = ""
	_update_selected_text()
	_update_selection_visual()


func _observe() -> void:
	if selected_object_id == "":
		feedback_label.text = "Select a sky target first."
		return
	GameManager.selected_object_id = selected_object_id
	GameManager.go("telescope")


func _update_selected_text() -> void:
	if selected_object_id == "":
		selected_title.text = "No target"
		selected_detail.text = "Choose an object on the sky map."
		return
	var obj: Dictionary = GameManager.get_object(selected_object_id)
	var item: Dictionary = _sky_item(selected_object_id)
	selected_title.text = str(obj.get("name_en", selected_object_id))
	selected_detail.text = "Type: %s\nAltitude: %.1f deg\nAzimuth: %.1f deg\nDirection: %s\nVisibility: %s\nSource: %s" % [
		str(obj.get("type_en", item.get("type", "Object"))),
		float(item.get("altitude", 0.0)),
		float(item.get("azimuth", 0.0)),
		str(item.get("direction_text", "Estimate")),
		str(item.get("visibility_text", "Offline estimate")),
		str(item.get("source", "fallback"))
	]


func _update_selection_visual() -> void:
	if selection_frame != null:
		selection_frame.queue_free()
		selection_frame = null
	if finder_frame != null:
		finder_frame.queue_free()
		finder_frame = null

	if _finder_installed() and target_rects.has(target_id):
		var finder_rect: Rect2 = target_rects[target_id]
		finder_frame = _border_frame(finder_rect.grow(18), Color(0.45, 0.78, 1.0, 0.55), 2)

	if selected_object_id == "" or not target_rects.has(selected_object_id):
		return
	var rect: Rect2 = target_rects[selected_object_id]
	selection_frame = _border_frame(rect.grow(8), GOLD, 3)


func _finder_text() -> String:
	if _finder_installed():
		return "Finder Scope active"
	return "Finder Scope inactive"


func _finder_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var finder: Dictionary = state.get("finder_scope", {})
	return bool(finder.get("installed", false))


func _sky_item(object_id: String) -> Dictionary:
	if sky_data.has(object_id):
		return sky_data[object_id]
	return {}


func _item_screen_pos(item: Dictionary) -> Vector2:
	var pos_variant: Variant = item.get("screen_pos", SKY_RECT.position + SKY_RECT.size * 0.5)
	if pos_variant is Vector2:
		return pos_variant
	return SKY_RECT.position + SKY_RECT.size * 0.5


func _clamp_center_to_sky(center: Vector2, size: Vector2) -> Vector2:
	var half := size * 0.5
	return Vector2(
		clampf(center.x, SKY_RECT.position.x + half.x + 4.0, SKY_RECT.end.x - half.x - 4.0),
		clampf(center.y, SKY_RECT.position.y + half.y + 4.0, SKY_RECT.end.y - half.y - 4.0)
	)


func _icon_size(icon_type: String) -> Vector2:
	match icon_type:
		"moon":
			return Vector2(74, 74)
		"striped_planet":
			return Vector2(92, 92)
		"red_planet":
			return Vector2(44, 44)
		"purple_nebula":
			return Vector2(112, 78)
		"blue_galaxy":
			return Vector2(128, 72)
		"blue_star", "red_star":
			return Vector2(48, 48)
	return Vector2(34, 34)


func _visibility_color(item: Dictionary) -> Color:
	var text := str(item.get("visibility_text", ""))
	if text == "Visible tonight":
		return GREEN
	if text == "Low on horizon":
		return WARNING
	return MUTED


func _border_frame(rect: Rect2, color: Color, width: int) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_frame_line(frame, Vector2.ZERO, Vector2(rect.size.x, width), color)
	_frame_line(frame, Vector2(0, rect.size.y - width), Vector2(rect.size.x, width), color)
	_frame_line(frame, Vector2.ZERO, Vector2(width, rect.size.y), color)
	_frame_line(frame, Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y), color)
	return frame


func _frame_line(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var line := ColorRect.new()
	line.position = pos
	line.size = size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _draw_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([from_pos, to_pos])
	line.default_color = color
	line.width = width
	add_child(line)
	return line


func _circle(pos: Vector2, size: Vector2, color: Color, border: Color, border_width: int) -> Panel:
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
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
