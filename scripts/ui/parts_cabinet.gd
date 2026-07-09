extends Control

const SCREEN_SIZE := Vector2(1024, 768)
const PANEL := Color(0.045, 0.065, 0.115, 0.96)
const PANEL_DARK := Color(0.020, 0.030, 0.055, 0.98)
const CARD_BG := Color(0.040, 0.058, 0.100, 0.96)
const CARD_EQUIPPED := Color(0.050, 0.075, 0.070, 0.98)
const CARD_LOCKED := Color(0.035, 0.040, 0.052, 0.92)
const BRASS := Color(0.78, 0.56, 0.28)
const GOLD := Color(0.96, 0.76, 0.38)
const BLUE_EDGE := Color(0.18, 0.28, 0.44)
const WARM_TEXT := Color(0.95, 0.93, 0.86)
const MUTED := Color(0.68, 0.76, 0.80)
const GREEN := Color(0.45, 0.95, 0.56)
const WARNING := Color(1.0, 0.70, 0.34)

const HEADER_RECT := Rect2(18, 14, 988, 56)
const SUMMARY_RECT := Rect2(36, 86, 952, 86)
const LIST_RECT := Rect2(36, 188, 952, 510)
const CARD_SIZE := Vector2(916, 170)
const PART_ICON_TEXTURES := {
	"basic_tripod": "res://assets/telescope_parts/basic_tripod.png",
	"basic_mount": "res://assets/telescope_parts/basic_mount.png",
	"starter_tube": "res://assets/telescope_parts/starter_tube.png",
	"objective_60mm": "res://assets/telescope_parts/objective_60mm.png",
	"eyepiece_20mm": "res://assets/telescope_parts/eyepiece_20mm.png",
	"basic_finder_scope": "res://assets/telescope_parts/basic_finder_scope.png",
	"eyepiece_10mm": "res://assets/telescope_parts/eyepiece_10mm.png",
	"objective_100mm": "res://assets/telescope_parts/objective_100mm.png",
	"stable_mount": "res://assets/telescope_parts/stable_mount.png",
	"tracking_mount": "res://assets/telescope_parts/tracking_mount.png",
	"basic_focus_knob": "res://assets/telescope_parts/basic_focus_knob.png"
}

const CATEGORY_ORDER := ["Support", "Optics", "Aiming", "Control"]
func _category_label(cat: String) -> String:
	var labels := {"Support": ["Support", "支撑"], "Optics": ["Optics", "光学"], "Aiming": ["Aiming", "瞄准"], "Control": ["Control", "控制"]}
	var pair: Array = labels.get(cat, [cat, cat])
	return GameManager.text(str(pair[0]), str(pair[1]))

# TYPE_LABELS helper — returns localized label per field
func _type_label(part_type: String, field: String) -> String:
	var labels := {
		"tripod": {"en": "Tripod", "zh": "三脚架", "role_en": "Support", "role_zh": "支撑", "category": "Support"},
		"mount": {"en": "Mount", "zh": "支架", "role_en": "Turns and steadies the telescope", "role_zh": "转动与稳定", "category": "Support"},
		"tube": {"en": "Tube", "zh": "镜筒", "role_en": "Keeps optics aligned", "role_zh": "保持光路对齐", "category": "Support"},
		"objective": {"en": "Objective Lens", "zh": "物镜", "role_en": "Collects light", "role_zh": "集光", "category": "Optics"},
		"eyepiece": {"en": "Eyepiece", "zh": "目镜", "role_en": "Magnifies the image", "role_zh": "放大", "category": "Optics"},
		"finder_scope": {"en": "Finder Scope", "zh": "寻星镜", "role_en": "Aims before high power", "role_zh": "寻星", "category": "Aiming"},
		"focus_knob": {"en": "Focus Knob", "zh": "调焦旋钮", "role_en": "Sharpens the image", "role_zh": "调清图像", "category": "Control"}
	}
	var entry: Dictionary = labels.get(part_type, {"en": part_type, "zh": part_type, "role_en": "", "role_zh": "", "category": "Control"})
	if field == "category":
		return str(entry.get("category", "Control"))
	return GameManager.text(str(entry.get(field + "_en", entry.get(field, ""))), str(entry.get(field + "_zh", "")))

var feedback_text := ""
var feedback_color := GOLD
var parts_box: VBoxContainer
var parts_scroll: ScrollContainer
var next_step_part_type := ""


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	call_deferred("_scroll_to_next_step")


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = SCREEN_SIZE
	next_step_part_type = _next_step_part_type()

	_rect(Vector2.ZERO, SCREEN_SIZE, Color(0.010, 0.016, 0.032))
	_draw_star_grid()
	_draw_title_bar()
	if GameManager.current_equipment_stage() == "eye":
		_draw_empty_eye_stage()
		return
	_draw_summary_panel()
	_draw_parts_list()


func _draw_title_bar() -> void:
	_panel(HEADER_RECT.position, HEADER_RECT.size, Color(0.030, 0.045, 0.085, 0.98), BLUE_EDGE)
	var title := _label_to(self, GameManager.text("Parts Cabinet", "零件柜"), Vector2(252, 24), Vector2(520, 32), 24, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var back := _button(GameManager.text("Back to Base", "返回基地"), Vector2(842, 22), Vector2(144, 40))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("cabinet")
		GameManager.go("observatory")
	)
	add_child(back)


func _draw_empty_eye_stage() -> void:
	_panel(Vector2(202, 282), Vector2(620, 194), PANEL, BRASS)
	_label_to(
		self,
		GameManager.text("No telescope parts yet. Finish the naked-eye observations first.", "还没有望远镜零件。先完成肉眼观测，Maya 很快会解锁第一套折射镜组件。"),
		Vector2(244, 312),
		Vector2(536, 122),
		16,
		WARM_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _draw_summary_panel() -> void:
	_panel(SUMMARY_RECT.position, SUMMARY_RECT.size, Color(0.040, 0.060, 0.105, 0.96), BRASS)
	var mission := GameManager.current_level()
	var mission_title := GameManager.dict_text(mission, "title")
	var stage := _stage_label(GameManager.current_equipment_stage())
	var summary := GameManager.text("Mission: ", "任务: ") + mission_title + "\n" + GameManager.text("Equipment: ", "设备: ") + stage
	_label_to(self, summary, Vector2(58, 102), Vector2(558, 44), 13, Color(0.84, 0.90, 0.90))
	_label_to(self, GameManager.text("Recommended parts marked in gold. Reassemble at Assembly Table after swapping.", "当前任务零件建议会以金色标记。更换零件后需要回组装台重新安装。"), Vector2(58, 145), Vector2(560, 18), 12, Color(0.72, 0.82, 0.86))

	var ready_text := GameManager.text("READY", "已就绪") if GameManager.telescope_is_ready() else GameManager.text("NEEDS ASSEMBLY", "需要组装")
	var ready_color := GREEN if GameManager.telescope_is_ready() else WARNING
	_label_to(self, ready_text, Vector2(738, 100), Vector2(224, 20), 14, ready_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_label_to(self, GameManager.text("Club Credits: %d", "社团积分: %d") % int(GameManager.progress.get("credits", 0)) + "\n" + GameManager.text("Unlocked: %d / %d", "已解锁: %d / %d") % [_unlocked_count(), GameManager.parts_data.size()], Vector2(748, 124), Vector2(214, 42), 12, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

	if feedback_text != "":
		var chip := _badge_to(self, feedback_text, Vector2(624, 140), Vector2(342, 24), feedback_color, HORIZONTAL_ALIGNMENT_RIGHT)
		chip.add_theme_font_size_override("font_size", 11)


func _draw_parts_list() -> void:
	_panel(LIST_RECT.position, LIST_RECT.size, PANEL_DARK, BLUE_EDGE)
	parts_scroll = ScrollContainer.new()
	parts_scroll.position = LIST_RECT.position + Vector2(14, 16)
	parts_scroll.size = LIST_RECT.size - Vector2(28, 30)
	parts_scroll.clip_contents = true
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(parts_scroll)

	parts_box = VBoxContainer.new()
	parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_box.add_theme_constant_override("separation", 10)
	parts_scroll.add_child(parts_box)

	var grouped := _grouped_parts()
	for category in CATEGORY_ORDER:
		var group: Array = grouped.get(category, [])
		if group.is_empty():
			continue
		parts_box.add_child(_category_header(str(_category_label(category))))
		for part_value in group:
			var part: Dictionary = part_value
			parts_box.add_child(_part_card(part))


func _category_header(text: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(CARD_SIZE.x, 28)
	var line := _rect_to(root, Vector2(0, 20), Vector2(CARD_SIZE.x, 1), Color(BRASS.r, BRASS.g, BRASS.b, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_to(root, text, Vector2(8, 1), Vector2(280, 22), 15, GOLD)
	return root


func _part_card(part: Dictionary) -> Control:
	var part_type := str(part.get("type", ""))
	var part_id := str(part.get("id", ""))
	var type_info: Dictionary = {"en": _type_label(part_type, "en"), "zh": _type_label(part_type, "zh"), "role": _type_label(part_type, "role")}
	var unlocked := _is_unlocked(part_id)
	var equipped := GameManager.equipped_part_id(part_type) == part_id
	var recommended := _is_recommended(part)
	var is_next_step := part_type == next_step_part_type

	var root := Control.new()
	root.custom_minimum_size = CARD_SIZE
	root.name = "part_card_%s" % part_type

	var bg := CARD_BG
	var border := BLUE_EDGE
	if equipped:
		bg = CARD_EQUIPPED
		border = GREEN
	elif recommended or is_next_step:
		border = GOLD
	elif not unlocked:
		bg = CARD_LOCKED
		border = Color(0.18, 0.20, 0.24)

	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", _style(bg, border, 2 if not recommended else 3, 5))
	root.add_child(panel)
	_panel_corners_to(root, Vector2.ZERO, CARD_SIZE, border)

	if recommended:
		_badge_to(root, GameManager.text("Recommended for current mission", "当前任务推荐"), Vector2(122, 10), Vector2(322, 22), GOLD)
	elif is_next_step:
		_badge_to(root, GameManager.text("Next assembly step", "下一步安装"), Vector2(122, 10), Vector2(220, 22), WARNING)

	var icon_box := _rect_to(root, Vector2(18, 34), Vector2(70, 70), Color(0.070, 0.090, 0.120))
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_icon(root, part, Vector2(18, 34), Vector2(70, 70), unlocked)

	var text_x := 106.0
	var title_y := 36.0 if not recommended and not is_next_step else 34.0
	var name_color := WARM_TEXT if unlocked else Color(0.52, 0.58, 0.62)
	_label_to(root, GameManager.dict_text(part, "name"), Vector2(text_x, title_y), Vector2(370, 20), 15, name_color)
	_label_to(root, _type_label(str(part.get("type", "")), "role"), Vector2(text_x, title_y + 22), Vector2(370, 18), 13, Color(0.78, 0.88, 0.88) if unlocked else Color(0.46, 0.52, 0.54))
	_badge_to(root, str(type_info.get("role", GameManager.text("Equipment", "设备"))), Vector2(text_x, title_y + 45), Vector2(250, 20), Color(0.46, 0.66, 0.86))

	var desc := _short_description(part)
	var desc_label := _label_to(root, desc, Vector2(text_x, title_y + 72), Vector2(500, 34), 12, Color(0.78, 0.84, 0.84) if unlocked else Color(0.46, 0.50, 0.54))
	desc_label.max_lines_visible = 2

	_draw_stat_chips(root, part, Vector2(18, 132), unlocked)
	_draw_action_column(root, part, unlocked, equipped)
	return root


func _draw_action_column(root: Control, part: Dictionary, unlocked: bool, equipped: bool) -> void:
	var part_id := str(part.get("id", ""))
	var part_type := str(part.get("type", ""))
	var column_x := CARD_SIZE.x - 174.0
	var badge_text := GameManager.text("Locked", "未解锁")
	var badge_color := Color(0.42, 0.46, 0.50)
	if equipped:
		badge_text = GameManager.text("Equipped", "已装备")
		badge_color = GREEN
	elif unlocked:
		badge_text = GameManager.text("Available", "可装备")
		badge_color = GOLD
	_badge_to(root, badge_text, Vector2(column_x, 24), Vector2(146, 24), badge_color, HORIZONTAL_ALIGNMENT_CENTER)

	var button := Button.new()
	button.position = Vector2(column_x + 18, 62)
	button.size = Vector2(110, 38)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	if equipped:
		button.text = GameManager.text("Equipped", "已装备")
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.14, 0.10), GREEN, 2, 3))
		button.add_theme_color_override("font_disabled_color", Color(0.72, 1.0, 0.76))
	elif not unlocked:
		button.text = GameManager.text("Locked", "未解锁")
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _style(Color(0.05, 0.055, 0.065), Color(0.16, 0.17, 0.19), 2, 3))
		button.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.48))
	else:
		button.text = GameManager.text("Equip", "装备")
		button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.13, 0.22), BLUE_EDGE, 2, 3))
		button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.22, 0.34), BRASS, 2, 3))
		button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.14, 0.08), BRASS, 2, 3))
		button.pressed.connect(func() -> void:
			if GameManager.equip_part(part_id):
				feedback_color = GREEN
				feedback_text = GameManager.text("Equipped %s. Reassembly required." % str(part.get("name_en", part_id)), "已装备%s。请回组装台重新安装。" % _safe_zh_name(part, str(part_type)))
				GameManager.set_room_guidance("assembly", "Maya: Assembly Table", GameManager.text("Reassemble the telescope with the new part.", "使用新零件重新组装望远镜。"))
				_build()
				call_deferred("_scroll_to_part_type", part_type)
		)
	root.add_child(button)

	var lock_note := _unlock_note(part, unlocked)
	_label_to(root, lock_note, Vector2(column_x - 2, 110), Vector2(154, 28), 10, MUTED if unlocked else Color(0.45, 0.47, 0.50), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_stat_chips(parent: Control, part: Dictionary, pos: Vector2, unlocked: bool) -> void:
	var chips := _part_stat_chips(part)
	if chips.is_empty():
		chips.append(GameManager.text("No special stats", "暂无特殊属性"))
	var x := pos.x
	var y := pos.y
	for chip in chips:
		var width := clampf(46.0 + float(str(chip).length()) * 5.6, 72.0, 150.0)
		if x + width > CARD_SIZE.x - 190.0:
			x = pos.x
			y += 24.0
			if y > pos.y + 25.0:
				break
		_badge_to(parent, str(chip), Vector2(x, y), Vector2(width, 19), Color(0.38, 0.58, 0.72) if unlocked else Color(0.28, 0.32, 0.38), HORIZONTAL_ALIGNMENT_CENTER)
		x += width + 8.0


func _draw_icon(parent: Control, part: Dictionary, box_pos: Vector2, box_size: Vector2, unlocked: bool = true) -> void:
	var part_id := str(part.get("id", ""))
	var texture_path := str(PART_ICON_TEXTURES.get(part_id, ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture: Texture2D = load(texture_path)
		var native_size := texture.get_size()
		var scale := minf((box_size.x - 8.0) / native_size.x, (box_size.y - 8.0) / native_size.y)
		var draw_size := native_size * scale
		var icon := TextureRect.new()
		icon.texture = texture
		icon.position = box_pos + (box_size - draw_size) * 0.5
		icon.size = native_size
		icon.scale = Vector2.ONE * scale
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.28)
		parent.add_child(icon)
		return

	var part_type := str(part.get("type", ""))
	var alpha := 1.0 if unlocked else 0.35
	var color := Color(0.52, 0.70, 0.86, alpha)
	match part_type:
		"tripod":
			color = Color(0.56, 0.62, 0.68, alpha)
			_rect_to(parent, box_pos + Vector2(32, 12), Vector2(8, 34), color)
			_rect_to(parent, box_pos + Vector2(18, 46), Vector2(36, 6), color.lightened(0.08))
			_rect_to(parent, box_pos + Vector2(16, 52), Vector2(6, 12), color.darkened(0.10))
			_rect_to(parent, box_pos + Vector2(50, 52), Vector2(6, 12), color.darkened(0.10))
		"mount":
			color = Color(0.62, 0.68, 0.74, alpha)
			_rect_to(parent, box_pos + Vector2(22, 20), Vector2(28, 28), color)
			_rect_to(parent, box_pos + Vector2(31, 10), Vector2(10, 48), color.lightened(0.08))
			_rect_to(parent, box_pos + Vector2(17, 52), Vector2(42, 5), color.darkened(0.14))
		"tube":
			color = Color(0.30, 0.58, 0.86, alpha)
			_rect_to(parent, box_pos + Vector2(12, 31), Vector2(42, 14), color)
			_rect_to(parent, box_pos + Vector2(52, 24), Vector2(12, 28), color.lightened(0.12))
			_rect_to(parent, box_pos + Vector2(9, 28), Vector2(6, 20), color.darkened(0.12))
		"objective":
			color = Color(0.66, 0.88, 0.94, alpha)
			_rect_to(parent, box_pos + Vector2(24, 14), Vector2(24, 42), color)
			_rect_to(parent, box_pos + Vector2(20, 25), Vector2(32, 8), color.darkened(0.12))
			_rect_to(parent, box_pos + Vector2(30, 18), Vector2(8, 34), Color(0.90, 1.0, 1.0, alpha * 0.45))
		"eyepiece":
			color = Color(0.46, 0.54, 0.62, alpha)
			_rect_to(parent, box_pos + Vector2(22, 24), Vector2(30, 26), color)
			_rect_to(parent, box_pos + Vector2(12, 30), Vector2(14, 14), color.darkened(0.10))
			_rect_to(parent, box_pos + Vector2(50, 28), Vector2(8, 18), color.lightened(0.10))
		"focus_knob":
			color = Color(0.88, 0.68, 0.32, alpha)
			_rect_to(parent, box_pos + Vector2(20, 18), Vector2(30, 30), color)
			_rect_to(parent, box_pos + Vector2(26, 24), Vector2(18, 18), color.darkened(0.18))
			_rect_to(parent, box_pos + Vector2(34, 10), Vector2(4, 10), color.lightened(0.12))
			_rect_to(parent, box_pos + Vector2(34, 48), Vector2(4, 10), color.darkened(0.12))
			_rect_to(parent, box_pos + Vector2(12, 31), Vector2(10, 4), color.darkened(0.12))
			_rect_to(parent, box_pos + Vector2(48, 31), Vector2(10, 4), color.lightened(0.12))
		_:
			color = Color(0.38, 0.68, 0.92, alpha)
			_rect_to(parent, box_pos + Vector2(12, 30), Vector2(42, 12), color)
			_rect_to(parent, box_pos + Vector2(52, 24), Vector2(10, 24), color.lightened(0.12))
			_rect_to(parent, box_pos + Vector2(16, 22), Vector2(30, 4), color.darkened(0.10))


func _grouped_parts() -> Dictionary:
	var grouped := {}
	for category in CATEGORY_ORDER:
		grouped[category] = []
	var parts := GameManager.parts_data.duplicate()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac := _category_index(_category_for_part(a))
		var bc := _category_index(_category_for_part(b))
		if ac != bc:
			return ac < bc
		var at := _type_rank(str(a.get("type", "")))
		var bt := _type_rank(str(b.get("type", "")))
		if at != bt:
			return at < bt
		return int(a.get("unlock_level", 999)) < int(b.get("unlock_level", 999))
	)
	for part_value in parts:
		var part: Dictionary = part_value
		var category := _category_for_part(part)
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(part)
	return grouped


func _category_for_part(part: Dictionary) -> String:
	var part_type := str(part.get("type", ""))
	var info: Dictionary = {"en": _type_label(part_type, "en"), "zh": _type_label(part_type, "zh"), "role": _type_label(part_type, "role")}
	return str(info.get("category", "Control"))


func _category_index(category: String) -> int:
	var index := CATEGORY_ORDER.find(category)
	return index if index >= 0 else 99


func _type_rank(part_type: String) -> int:
	var order := ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope", "focus_knob"]
	var index := order.find(part_type)
	return index if index >= 0 else 99


func _is_unlocked(part_id: String) -> bool:
	return GameManager.progress.get("unlocked_parts", []).has(part_id)


func _unlocked_count() -> int:
	var total := 0
	for part in GameManager.parts_data:
		if _is_unlocked(str(part.get("id", ""))):
			total += 1
	return total


func _is_recommended(part: Dictionary) -> bool:
	var part_id := str(part.get("id", ""))
	var level := GameManager.current_level()
	if _array_has_string(level.get("recommended_part_ids", []), part_id):
		return true
	if _array_has_string(level.get("required_part_ids", []), part_id):
		return true
	var target_id := str(level.get("target_object_id", ""))
	if target_id in ["orion_nebula", "andromeda"] and part_id in ["objective_100mm", "stable_mount", "eyepiece_20mm", "tracking_mount"]:
		return _is_unlocked(part_id)
	if target_id in ["mars", "jupiter"] and part_id in ["stable_mount", "eyepiece_10mm"]:
		return _is_unlocked(part_id)
	if target_id == "moon" and part_id == "eyepiece_10mm":
		return _is_unlocked(part_id)
	return false


func _array_has_string(values: Variant, needle: String) -> bool:
	if not values is Array:
		return false
	for value in values:
		if str(value) == needle:
			return true
	return false


func _next_step_part_type() -> String:
	var required: Array = GameManager.current_level().get("required_parts", [])
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	for value in required:
		var part_type := str(value)
		var entry: Dictionary = state.get(part_type, {})
		if not bool(entry.get("installed", false)):
			return part_type
	return ""


func _scroll_to_next_step() -> void:
	if next_step_part_type != "":
		_scroll_to_part_type(next_step_part_type)


func _scroll_to_part_type(part_type: String) -> void:
	if parts_scroll == null or parts_box == null:
		return
	await get_tree().process_frame
	for child in parts_box.get_children():
		if child.name == "part_card_%s" % part_type:
			parts_scroll.scroll_vertical = max(0, int(child.position.y) - 36)
			return


func _short_description(part: Dictionary) -> String:
	var part_id := str(part.get("id", ""))
	match part_id:
		"objective_100mm":
			return GameManager.text("More light for faint targets.", "收集更多光，适合星云和星系。")
		"eyepiece_10mm":
			return GameManager.text("More magnification, narrower and dimmer view.", "倍率更高，但视野更窄更暗。")
		"stable_mount":
			return GameManager.text("Less shake at high magnification.", "高倍率下抖动更少。")
		"tracking_mount":
			return GameManager.text("Tracks sky drift for long observations.", "抵消星空漂移，适合长时间观测。")
		"basic_focus_knob":
			return GameManager.text("Moves the eyepiece to sharpen focus.", "移动目镜，让图像清晰。")
	return GameManager.dict_text(part, "description")


func _safe_zh_name(part: Dictionary, fallback: String) -> String:
	var part_id := str(part.get("id", ""))
	var names := {
		"basic_tripod": "基础三脚架",
		"basic_mount": "基础支架",
		"starter_tube": "入门镜筒",
		"objective_60mm": "60mm 入门物镜",
		"eyepiece_20mm": "20mm 低倍率目镜",
		"basic_finder_scope": "基础寻星镜",
		"eyepiece_10mm": "10mm 高倍率目镜",
		"objective_100mm": "100mm 大口径物镜",
		"stable_mount": "重型稳定支架",
		"tracking_mount": "追踪支架",
		"basic_focus_knob": "基础调焦旋钮"
	}
	return str(names.get(part_id, part.get("name_zh", fallback)))


func _part_stat_chips(part: Dictionary) -> Array[String]:
	var chips: Array[String] = []
	if part.has("aperture_mm"):
		chips.append(GameManager.text("Aperture: %smm", "口径: %smm") % part.get("aperture_mm"))
	if part.has("focal_length_mm"):
		chips.append(GameManager.text("Focal: %smm", "焦距: %smm") % part.get("focal_length_mm"))
	if part.has("quality"):
		chips.append(GameManager.text("Quality: %s", "质量: %s") % part.get("quality"))
	if part.has("field_of_view"):
		chips.append(GameManager.text("FOV: %s", "视野: %s") % part.get("field_of_view"))
	if part.has("stability"):
		chips.append(GameManager.text("Stability: %s", "稳定: %s") % part.get("stability"))
	if part.has("stability_bonus"):
		chips.append(GameManager.text("Stability: %s", "稳定: %s") % part.get("stability_bonus"))
	if part.has("tracking"):
		chips.append(GameManager.text("Tracking: %s", "追踪: %s") % part.get("tracking"))
	if part.has("aim_assist"):
		chips.append(GameManager.text("Aim: %s", "瞄准: %s") % part.get("aim_assist"))
	if part.has("focus_sensitivity"):
		chips.append(GameManager.text("Focus: %s", "调焦: %s") % part.get("focus_sensitivity"))
	return chips


func _unlock_note(part: Dictionary, unlocked: bool) -> String:
	if unlocked:
		return ""
	var level := int(part.get("unlock_level", 999))
	if level < 999:
		return GameManager.text("Unlocks at L%d" % level, "第 %d 关解锁" % level)
	return GameManager.text("Locked", "未解锁")


func _stage_label(stage: String) -> String:
	match stage:
		"eye":
			return GameManager.text("Naked Eye", "肉眼")
		"refractor_basic":
			return GameManager.text("Simple Refractor", "基础折射镜")
		"refractor_with_finder":
			return GameManager.text("Refractor + Finder", "折射镜 + 寻星镜")
		"newtonian_basic":
			return GameManager.text("Reflector Practice", "反射镜练习")
		"advanced":
			return GameManager.text("Advanced Kit", "高级设备")
	return stage


func _draw_star_grid() -> void:
	for index in range(90):
		var x := fmod(float(index * 89), SCREEN_SIZE.x)
		var y := fmod(float(index * 53), SCREEN_SIZE.y)
		var alpha := 0.08 + fmod(float(index), 5.0) * 0.025
		_rect(Vector2(x, y), Vector2(1, 1), Color(0.6, 0.75, 0.95, alpha))


func _panel(pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 3, 5))
	add_child(panel)
	_panel_corners_to(self, pos, panel_size, border)
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


func _badge_to(parent: Control, text: String, pos: Vector2, badge_size: Vector2, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var bg := _rect_to(parent, pos, badge_size, Color(color.r, color.g, color.b, 0.16))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label_to(parent, text, pos + Vector2(5, 2), badge_size - Vector2(10, 3), 10, color, align)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	return label


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _panel_corners_to(parent: Control, pos: Vector2, panel_size: Vector2, color: Color) -> void:
	_rect_to(parent, pos + Vector2(4, 4), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(4, 4), Vector2(3, 12), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 16, 4), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 7, 4), Vector2(3, 12), color)
	_rect_to(parent, pos + Vector2(4, panel_size.y - 7), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(4, panel_size.y - 16), Vector2(3, 12), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 16, panel_size.y - 7), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 7, panel_size.y - 16), Vector2(3, 12), color)


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	return _rect_to(self, pos, rect_size, color)


func _rect_to(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label_to(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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
	parent.add_child(label)
	return label

func _on_language_changed() -> void:
	_build()
