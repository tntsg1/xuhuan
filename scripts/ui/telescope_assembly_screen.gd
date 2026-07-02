extends Control

const AssemblyManagerScript = preload("res://scripts/systems/assembly_manager.gd")

const SCREEN_SIZE := Vector2(1024, 768)
const PART_ORDER: Array[String] = ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope"]
const CORE_PARTS: Array[String] = ["tripod", "mount", "tube", "objective", "eyepiece"]
const ASSET_DIR := "res://assets/pixel_observatory/"

const PART_TEXTURES := {
	"tripod": "res://assets/pixel_observatory/tripod.png",
	"mount": "res://assets/pixel_observatory/mount.png",
	"tube": "res://assets/pixel_observatory/tube.png",
	"objective": "res://assets/pixel_observatory/objective.png",
	"eyepiece": "res://assets/pixel_observatory/eyepiece.png",
	"finder_scope": "res://assets/pixel_observatory/finder_scope.png"
}

const PART_LABELS := {
	"tripod": {"short": "Tripod", "zh": "三脚架", "role": "Base support / 底部支撑"},
	"mount": {"short": "Mount", "zh": "支架", "role": "Holds and turns the tube / 支撑并转动镜筒"},
	"tube": {"short": "Tube", "zh": "镜筒", "role": "Keeps optics aligned / 保持光路对齐"},
	"objective": {"short": "Lens", "zh": "物镜", "role": "Collects light / 收集光线"},
	"eyepiece": {"short": "Eye", "zh": "目镜", "role": "Magnifies the image / 放大图像"},
	"finder_scope": {"short": "Finder", "zh": "寻星镜", "role": "Helps aim the telescope / 帮助瞄准"}
}

const SLOT_RECTS := {
	"finder_scope": Rect2(163, 40, 116, 46),
	"eyepiece": Rect2(69, 147, 74, 54),
	"tube": Rect2(144, 128, 158, 72),
	"objective": Rect2(299, 133, 72, 62),
	"mount": Rect2(165, 213, 72, 56),
	"tripod": Rect2(144, 281, 112, 74)
}

const PART_COLORS := {
	"tripod": Color(0.55, 0.61, 0.68),
	"mount": Color(0.62, 0.68, 0.74),
	"tube": Color(0.31, 0.57, 0.84),
	"objective": Color(0.63, 0.85, 0.92),
	"eyepiece": Color(0.45, 0.53, 0.62),
	"finder_scope": Color(0.38, 0.68, 0.92)
}

var selected_part_type := ""
var wrong_attempts: Dictionary = {}

var parts_list: Control
var blueprint_layer: Control
var inspector_title: Label
var inspector_body: Label
var feedback_label: Label
var stats_list: Control


func _ready() -> void:
	_load_wrong_attempts()
	_build()


func _load_wrong_attempts() -> void:
	var assembly_state: Dictionary = _assembly_state()
	for part_type in PART_ORDER:
		var entry: Dictionary = _dict_value(assembly_state.get(part_type, {}))
		wrong_attempts[part_type] = int(entry.get("wrong_attempts", 0))


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = SCREEN_SIZE

	_rect(Vector2.ZERO, SCREEN_SIZE, Color(0.006, 0.009, 0.018))
	_draw_grid()
	_draw_title_bar()
	_build_parts_panel()
	_build_blueprint_panel()
	_build_inspector_panel()
	_refresh_all()


func _draw_title_bar() -> void:
	_rect(Vector2(0, 0), Vector2(1024, 58), Color(0.030, 0.045, 0.085, 0.96))
	_rect(Vector2(18, 12), Vector2(988, 3), Color(0.78, 0.56, 0.28))
	_rect(Vector2(18, 52), Vector2(988, 3), Color(0.17, 0.25, 0.40))
	var title := _label("Telescope Assembly Table / 望远镜组装台", 24, Color(0.96, 0.95, 0.90))
	title.position = Vector2(216, 13)
	title.size = Vector2(592, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(title)

	var subtitle := _label("Pick a part, then click its blueprint slot. / 选择零件，再点击蓝图安装位。", 11, Color(0.76, 0.84, 0.88))
	subtitle.position = Vector2(708, 16)
	subtitle.size = Vector2(286, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle)


func _build_parts_panel() -> void:
	_panel(Vector2(20, 74), Vector2(300, 636), Color(0.050, 0.070, 0.120, 0.96), Color(0.78, 0.56, 0.28))
	_rect(Vector2(24, 78), Vector2(292, 34), Color(0.30, 0.20, 0.10, 0.92))
	var heading := _label("Parts Tray / 零件托盘", 17, Color(0.96, 0.93, 0.84))
	heading.position = Vector2(40, 91)
	heading.size = Vector2(250, 26)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(heading)

	parts_list = Control.new()
	parts_list.position = Vector2(36, 128)
	parts_list.size = Vector2(268, 560)
	add_child(parts_list)


func _build_blueprint_panel() -> void:
	_panel(Vector2(336, 74), Vector2(420, 636), Color(0.030, 0.060, 0.115, 0.96), Color(0.78, 0.56, 0.28))
	_rect(Vector2(340, 78), Vector2(412, 34), Color(0.035, 0.070, 0.135, 0.96))
	var heading := _label("Assembly Blueprint / 组装蓝图", 17, Color(0.96, 0.93, 0.84))
	heading.position = Vector2(356, 91)
	heading.size = Vector2(310, 26)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(heading)

	blueprint_layer = Control.new()
	blueprint_layer.position = Vector2(354, 132)
	blueprint_layer.size = Vector2(382, 370)
	add_child(blueprint_layer)

	_rect(Vector2(354, 516), Vector2(382, 118), Color(0.028, 0.048, 0.082))
	var helper := _label("[1] Pick a part card.  [2] Click the matching slot.\n先选左侧零件卡，再点击中间对应安装位。", 13, Color(0.80, 0.86, 0.86))
	helper.position = Vector2(372, 532)
	helper.size = Vector2(346, 58)
	add_child(helper)

	var order := _label("Order / 顺序: Tripod → Mount → Tube → Lens → Eye", 12, Color(0.66, 0.76, 0.82))
	order.position = Vector2(372, 604)
	order.size = Vector2(346, 22)
	order.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(order)


func _build_inspector_panel() -> void:
	_panel(Vector2(772, 74), Vector2(232, 636), Color(0.050, 0.070, 0.120, 0.96), Color(0.78, 0.56, 0.28))
	_rect(Vector2(776, 78), Vector2(224, 34), Color(0.30, 0.20, 0.10, 0.92))
	var heading := _label("Inspector / 检查器", 17, Color(0.96, 0.93, 0.84))
	heading.position = Vector2(790, 91)
	heading.size = Vector2(194, 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(heading)

	inspector_title = _label("No part selected / 未选择零件", 15, Color(0.91, 0.96, 0.98))
	inspector_title.position = Vector2(790, 126)
	inspector_title.size = Vector2(194, 42)
	add_child(inspector_title)

	inspector_body = _label("Choose a card from the parts tray.\n从左侧零件托盘选择一个零件。", 12, Color(0.76, 0.83, 0.84))
	inspector_body.position = Vector2(790, 172)
	inspector_body.size = Vector2(194, 92)
	add_child(inspector_body)

	_rect(Vector2(790, 276), Vector2(194, 1), Color(0.32, 0.42, 0.48))
	var feedback_heading := _label("Assembly Hint / 组装提示", 13, Color(0.96, 0.89, 0.66))
	feedback_heading.position = Vector2(790, 288)
	feedback_heading.size = Vector2(194, 22)
	feedback_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(feedback_heading)

	feedback_label = _label("Start with Tripod at the bottom slot.\n先从底部三脚架安装位开始。", 12, Color(0.90, 0.88, 0.80))
	feedback_label.position = Vector2(790, 314)
	feedback_label.size = Vector2(194, 78)
	add_child(feedback_label)

	var stats_heading := _label("Telescope Stats / 性能", 13, Color(0.96, 0.89, 0.66))
	stats_heading.position = Vector2(790, 410)
	stats_heading.size = Vector2(194, 22)
	stats_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(stats_heading)

	stats_list = Control.new()
	stats_list.position = Vector2(790, 438)
	stats_list.size = Vector2(194, 146)
	add_child(stats_list)

	var finish := _button("Finish Assembly\n完成组装", Vector2(790, 600), Vector2(194, 42))
	finish.pressed.connect(_finish)
	add_child(finish)

	var reset := _button("Reassemble\n重新组装", Vector2(790, 650), Vector2(92, 38))
	reset.pressed.connect(_reset)
	add_child(reset)

	var back := _button("Back\n返回", Vector2(892, 650), Vector2(92, 38))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	)
	add_child(back)


func _refresh_all() -> void:
	_refresh_parts()
	_refresh_blueprint()
	_refresh_inspector()
	_refresh_stats()


func _refresh_parts() -> void:
	_clear(parts_list)
	var y := 0.0
	for part_type in PART_ORDER:
		var unlocked: Array = GameManager.unlocked_parts_by_type(part_type)
		if unlocked.is_empty():
			continue
		var part: Dictionary = _dict_value(unlocked[0])
		var installed := _is_installed(part_type)
		var selected := selected_part_type == part_type
		_draw_part_card(part_type, part, installed, selected, Vector2(0, y))
		y += 90.0


func _draw_part_card(part_type: String, part: Dictionary, installed: bool, selected: bool, pos: Vector2) -> void:
	var bg_color := Color(0.155, 0.172, 0.180)
	if installed:
		bg_color = Color(0.112, 0.128, 0.132)
	if selected:
		bg_color = Color(0.185, 0.245, 0.285)
	var border_color := Color(0.30, 0.38, 0.42)
	if installed:
		border_color = Color(0.34, 0.56, 0.42)
	if selected:
		border_color = Color(0.82, 0.72, 0.34)
	var card := _panel_local(parts_list, pos, Vector2(268, 78), bg_color, border_color)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_box := _panel_local(parts_list, pos + Vector2(10, 11), Vector2(56, 56), Color(0.070, 0.085, 0.095), Color(0.22, 0.30, 0.34))
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.clip_contents = true
	_draw_part_icon(parts_list, part_type, pos + Vector2(10, 11), installed)

	var name_en := _label(str(part.get("name_en", PART_LABELS[part_type]["short"])), 12, Color(0.94, 0.95, 0.92))
	name_en.position = pos + Vector2(76, 10)
	name_en.size = Vector2(172, 18)
	name_en.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_en.clip_text = true
	parts_list.add_child(name_en)

	var name_zh := _label(str(PART_LABELS[part_type]["zh"]), 12, Color(0.82, 0.88, 0.88))
	name_zh.position = pos + Vector2(76, 30)
	name_zh.size = Vector2(172, 18)
	name_zh.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_zh.clip_text = true
	parts_list.add_child(name_zh)

	var status_text := "Installed / 已安装" if installed else "Not Installed / 未安装"
	var status_color := Color(0.58, 0.86, 0.62) if installed else Color(0.86, 0.78, 0.48)
	var status := _label(status_text, 11, status_color)
	status.position = pos + Vector2(76, 52)
	status.size = Vector2(172, 16)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	parts_list.add_child(status)

	if installed:
		var check := _label("OK", 11, Color(0.66, 0.94, 0.70))
		check.position = pos + Vector2(235, 52)
		check.size = Vector2(24, 16)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		check.autowrap_mode = TextServer.AUTOWRAP_OFF
		parts_list.add_child(check)

	var click := Button.new()
	click.position = pos
	click.size = Vector2(268, 78)
	click.text = ""
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.pressed.connect(_select_part.bind(part_type))
	parts_list.add_child(click)


func _draw_part_icon(parent: Control, part_type: String, box_pos: Vector2, installed: bool) -> void:
	var color: Color = PART_COLORS[part_type]
	if installed:
		color = color.darkened(0.22)
	var p := box_pos + Vector2(4, 4)
	match part_type:
		"tripod":
			_rect_local(parent, p + Vector2(21, 8), Vector2(8, 24), color)
			_rect_local(parent, p + Vector2(12, 33), Vector2(28, 6), color.lightened(0.08))
			_rect_local(parent, p + Vector2(8, 39), Vector2(6, 8), color.darkened(0.08))
			_rect_local(parent, p + Vector2(37, 39), Vector2(6, 8), color.darkened(0.08))
		"mount":
			_rect_local(parent, p + Vector2(16, 13), Vector2(24, 23), color)
			_rect_local(parent, p + Vector2(22, 7), Vector2(12, 37), color.lightened(0.08))
			_rect_local(parent, p + Vector2(11, 20), Vector2(8, 9), color.darkened(0.10))
			_rect_local(parent, p + Vector2(37, 20), Vector2(8, 9), color.darkened(0.10))
		"tube":
			_rect_local(parent, p + Vector2(7, 22), Vector2(35, 12), color)
			_rect_local(parent, p + Vector2(37, 17), Vector2(10, 22), color.lightened(0.12))
			_rect_local(parent, p + Vector2(4, 19), Vector2(7, 18), color.darkened(0.10))
		"objective":
			_rect_local(parent, p + Vector2(16, 9), Vector2(22, 34), color)
			_rect_local(parent, p + Vector2(22, 5), Vector2(10, 42), color.lightened(0.14))
			_rect_local(parent, p + Vector2(13, 16), Vector2(28, 5), color.darkened(0.12))
		"eyepiece":
			_rect_local(parent, p + Vector2(17, 16), Vector2(23, 22), color)
			_rect_local(parent, p + Vector2(8, 21), Vector2(13, 12), color.darkened(0.10))
			_rect_local(parent, p + Vector2(35, 20), Vector2(8, 14), color.lightened(0.10))
		_:
			_rect_local(parent, p + Vector2(8, 20), Vector2(34, 10), color)
			_rect_local(parent, p + Vector2(36, 15), Vector2(10, 20), color.lightened(0.12))
			_rect_local(parent, p + Vector2(11, 16), Vector2(8, 18), color.darkened(0.10))


func _refresh_blueprint() -> void:
	_clear(blueprint_layer)
	_rect_local(blueprint_layer, Vector2.ZERO, blueprint_layer.size, Color(0.060, 0.075, 0.090))
	_draw_blueprint_grid()
	_draw_scope_guide()

	var next_part := _next_installable_part()
	for part_type in PART_ORDER:
		if part_type == "finder_scope" and GameManager.unlocked_parts_by_type(part_type).is_empty():
			continue
		_draw_slot(part_type, next_part)


func _draw_blueprint_grid() -> void:
	for x in range(24, 382, 48):
		_rect_local(blueprint_layer, Vector2(x, 12), Vector2(1, 334), Color(0.16, 0.25, 0.31, 0.34))
	for y in range(24, 350, 48):
		_rect_local(blueprint_layer, Vector2(18, y), Vector2(344, 1), Color(0.16, 0.25, 0.31, 0.34))
	var label := _label("blueprint view", 11, Color(0.34, 0.50, 0.58))
	label.position = Vector2(246, 8)
	label.size = Vector2(112, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	blueprint_layer.add_child(label)


func _draw_scope_guide() -> void:
	_rect_local(blueprint_layer, Vector2(91, 159), Vector2(226, 18), Color(0.26, 0.52, 0.72, 0.22))
	_rect_local(blueprint_layer, Vector2(306, 149), Vector2(30, 38), Color(0.62, 0.83, 0.91, 0.18))
	_rect_local(blueprint_layer, Vector2(72, 149), Vector2(24, 38), Color(0.58, 0.66, 0.74, 0.18))
	_rect_local(blueprint_layer, Vector2(192, 193), Vector2(18, 76), Color(0.55, 0.61, 0.66, 0.18))
	_rect_local(blueprint_layer, Vector2(165, 310), Vector2(96, 9), Color(0.55, 0.61, 0.66, 0.18))
	_draw_line(Vector2(201, 268), Vector2(150, 334), Color(0.55, 0.61, 0.66, 0.18))
	_draw_line(Vector2(201, 268), Vector2(244, 334), Color(0.55, 0.61, 0.66, 0.18))


func _draw_slot(part_type: String, next_part: String) -> void:
	var rect: Rect2 = SLOT_RECTS[part_type]
	var installed := _is_installed(part_type)
	var selected := selected_part_type == part_type
	var next := next_part == part_type
	var can_show_selected := selected_part_type != "" and selected

	var border := Color(0.43, 0.58, 0.66, 0.74)
	var fill := Color(0.11, 0.16, 0.18, 0.38)
	if installed:
		border = Color(0.52, 0.83, 0.64, 0.90)
		fill = Color(0.20, 0.30, 0.26, 0.54)
	elif can_show_selected:
		border = Color(0.96, 0.78, 0.30, 1.0)
		fill = Color(0.34, 0.26, 0.10, 0.46)
	elif selected_part_type == "" and next:
		border = Color(0.56, 0.78, 0.92, 0.90)
		fill = Color(0.12, 0.22, 0.28, 0.48)

	_panel_local(blueprint_layer, rect.position, rect.size, fill, border)
	_draw_corner_ticks(rect, border)

	if installed:
		_draw_installed_part(part_type, rect)
	else:
		var dot := _rect_local(blueprint_layer, rect.position + rect.size * 0.5 - Vector2(4, 4), Vector2(8, 8), border)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var slot_name := str(PART_LABELS[part_type]["short"])
	var label := _label(slot_name, 11, Color(0.88, 0.94, 0.92))
	label.position = rect.position + Vector2(5, 4)
	label.size = Vector2(rect.size.x - 10, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	blueprint_layer.add_child(label)

	var hot := Button.new()
	hot.position = rect.position
	hot.size = rect.size
	hot.text = ""
	hot.flat = true
	hot.focus_mode = Control.FOCUS_NONE
	hot.pressed.connect(_try_install.bind(part_type))
	blueprint_layer.add_child(hot)


func _draw_installed_part(part_type: String, rect: Rect2) -> void:
	var color: Color = PART_COLORS[part_type]
	var inner := rect.grow(-9.0)
	if part_type == "tripod":
		_rect_local(blueprint_layer, inner.position + Vector2(26, 0), Vector2(10, 34), color)
		_rect_local(blueprint_layer, inner.position + Vector2(8, 38), Vector2(72, 8), color.darkened(0.08))
		_draw_line(inner.position + Vector2(31, 32), inner.position + Vector2(6, 58), color)
		_draw_line(inner.position + Vector2(36, 32), inner.position + Vector2(82, 58), color)
	elif part_type == "mount":
		_rect_local(blueprint_layer, inner.position + Vector2(13, 10), Vector2(40, 28), color)
		_rect_local(blueprint_layer, inner.position + Vector2(23, 0), Vector2(20, 48), color.lightened(0.08))
	elif part_type == "tube":
		_rect_local(blueprint_layer, inner.position + Vector2(6, 20), Vector2(126, 22), color)
		_rect_local(blueprint_layer, inner.position + Vector2(116, 13), Vector2(24, 36), color.lightened(0.12))
	elif part_type == "objective":
		_rect_local(blueprint_layer, inner.position + Vector2(8, 7), Vector2(37, 38), color)
		_rect_local(blueprint_layer, inner.position + Vector2(18, 0), Vector2(17, 52), color.lightened(0.14))
	elif part_type == "eyepiece":
		_rect_local(blueprint_layer, inner.position + Vector2(13, 12), Vector2(34, 30), color)
		_rect_local(blueprint_layer, inner.position + Vector2(2, 19), Vector2(17, 16), color.darkened(0.10))
	else:
		_rect_local(blueprint_layer, inner.position + Vector2(10, 15), Vector2(72, 15), color)
		_rect_local(blueprint_layer, inner.position + Vector2(64, 9), Vector2(20, 28), color.lightened(0.12))


func _draw_corner_ticks(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var s := rect.size
	var tick := 10.0
	_rect_local(blueprint_layer, p, Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p, Vector2(2, tick), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - tick, 0), Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - 2, 0), Vector2(2, tick), color)
	_rect_local(blueprint_layer, p + Vector2(0, s.y - 2), Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p + Vector2(0, s.y - tick), Vector2(2, tick), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - tick, s.y - 2), Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - 2, s.y - tick), Vector2(2, tick), color)


func _refresh_inspector() -> void:
	if selected_part_type == "":
		var next_part := _next_installable_part()
		if next_part == "":
			inspector_title.text = "Ready to finish\n可以完成组装"
			inspector_body.text = "All required core parts are installed.\n核心部件已经装齐。"
			feedback_label.text = "Click Finish Assembly to return to the observatory.\n点击完成组装返回观测室。"
		else:
			inspector_title.text = "Next step: " + str(PART_LABELS[next_part]["short"]) + "\n下一步：" + str(PART_LABELS[next_part]["zh"])
			inspector_body.text = _next_step_description(next_part)
			feedback_label.text = "Select " + str(PART_LABELS[next_part]["short"]) + " on the left, then click its slot.\n先选择 " + str(PART_LABELS[next_part]["zh"]) + "，再点击对应安装位。"
		return
	var unlocked: Array = GameManager.unlocked_parts_by_type(selected_part_type)
	if unlocked.is_empty():
		return
	var part: Dictionary = _dict_value(unlocked[0])
	inspector_title.text = str(part.get("name_en", PART_LABELS[selected_part_type]["short"])) + "\n" + str(PART_LABELS[selected_part_type]["zh"])
	inspector_body.text = str(part.get("description_en", "")) + "\n" + str(PART_LABELS[selected_part_type]["role"])


func _refresh_stats() -> void:
	_clear(stats_list)
	var stats: Dictionary = GameManager.calculate_stats()
	var values := [
		{"name": "Magnification", "value": float(stats.get("magnification", 0.0)), "max": 120.0, "suffix": "x"},
		{"name": "Light", "value": float(stats.get("light_score", 0.0)), "max": 100.0, "suffix": ""},
		{"name": "Stability", "value": float(stats.get("stability_score", 0.0)), "max": 100.0, "suffix": ""},
		{"name": "Clarity", "value": float(stats.get("clarity_score", 0.0)), "max": 100.0, "suffix": ""},
		{"name": "Field", "value": float(stats.get("field_of_view", 0.0)), "max": 70.0, "suffix": ""},
		{"name": "Assembly", "value": float(stats.get("assembly_score", 0.0)), "max": 100.0, "suffix": ""}
	]
	var y := 0.0
	for row in values:
		_draw_stat_row(str(row["name"]), float(row["value"]), float(row["max"]), str(row["suffix"]), y)
		y += 23.0


func _draw_stat_row(name: String, value: float, max_value: float, suffix: String, y: float) -> void:
	var label := _label(name, 10, Color(0.82, 0.88, 0.86))
	label.position = Vector2(0, y)
	label.size = Vector2(82, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	stats_list.add_child(label)

	_rect_local(stats_list, Vector2(84, y + 4), Vector2(72, 8), Color(0.060, 0.075, 0.086))
	var ratio := clampf(value / maxf(1.0, max_value), 0.0, 1.0)
	_rect_local(stats_list, Vector2(84, y + 4), Vector2(72.0 * ratio, 8), Color(0.46, 0.72, 0.86))

	var value_text := str(snapped(value, 0.1)) + suffix
	var value_label := _label(value_text, 10, Color(0.95, 0.91, 0.76))
	value_label.position = Vector2(160, y)
	value_label.size = Vector2(34, 16)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.clip_text = true
	stats_list.add_child(value_label)


func _select_part(part_type: String) -> void:
	if _is_installed(part_type):
		selected_part_type = part_type
		feedback_label.text = str(PART_LABELS[part_type]["short"]) + " is already installed.\n" + str(PART_LABELS[part_type]["zh"]) + " 已安装。"
	else:
		selected_part_type = part_type
		feedback_label.text = "Click the " + str(PART_LABELS[part_type]["short"]) + " slot on the blueprint.\n点击蓝图上的 " + str(PART_LABELS[part_type]["zh"]) + " 安装位。"
	_refresh_all()


func _try_install(slot_type: String) -> void:
	if selected_part_type == "":
		feedback_label.text = "Select a part card from the left first.\n请先从左侧选择零件卡。"
		return
	if _is_installed(slot_type):
		feedback_label.text = str(PART_LABELS[slot_type]["short"]) + " is already installed.\n这个安装位已经完成。"
		return
	if selected_part_type != slot_type:
		wrong_attempts[selected_part_type] = int(wrong_attempts.get(selected_part_type, 0)) + 1
		feedback_label.text = _wrong_feedback(selected_part_type, slot_type)
		_refresh_all()
		return

	var order_check: Dictionary = AssemblyManagerScript.can_install(slot_type, _assembly_state())
	if not bool(order_check.get("ok", false)):
		wrong_attempts[selected_part_type] = int(wrong_attempts.get(selected_part_type, 0)) + 1
		feedback_label.text = _order_feedback(slot_type)
		_refresh_all()
		return

	var score: int = GameManager.install_part(slot_type, int(wrong_attempts.get(slot_type, 0)))
	feedback_label.text = "Installed " + str(PART_LABELS[slot_type]["short"]) + ". Alignment " + str(score) + ".\n已安装 " + str(PART_LABELS[slot_type]["zh"]) + "，对齐 " + str(score) + "。"
	selected_part_type = ""
	_refresh_all()


func _finish() -> void:
	if GameManager.telescope_is_ready():
		GameManager.last_guidance = "ready_to_observe"
		GameManager.set_observatory_spawn("assembly")
		GameManager.save()
		GameManager.go("observatory")
		return
	var missing := GameManager.missing_parts()
	var names: Array[String] = []
	for part_type in missing:
		names.append(str(PART_LABELS.get(part_type, {"short": part_type})["short"]))
	feedback_label.text = "Missing core parts: " + ", ".join(names) + ".\n核心部件未齐，请先装完缺少部件。"


func _reset() -> void:
	GameManager.reset_assembly()
	for part_type in PART_ORDER:
		wrong_attempts[part_type] = 0
	selected_part_type = ""
	feedback_label.text = "Assembly reset. Start with Tripod.\n已重新组装，请从三脚架开始。"
	_refresh_all()


func _wrong_feedback(part_type: String, slot_type: String) -> String:
	return "Wrong slot. " + str(PART_LABELS[part_type]["short"]) + " belongs in the " + str(PART_LABELS[part_type]["short"]) + " slot.\n" \
		+ "位置不对。" + str(PART_LABELS[part_type]["zh"]) + " 应安装到对应安装位。\n" \
		+ str(PART_LABELS[part_type]["role"])


func _order_feedback(part_type: String) -> String:
	var previous := _previous_required(part_type)
	if previous == "":
		return "Install the lower support parts first.\n请先安装底部支撑结构。"
	return "Install " + str(PART_LABELS[previous]["short"]) + " first.\n请先安装 " + str(PART_LABELS[previous]["zh"]) + "。"


func _previous_required(part_type: String) -> String:
	var index := CORE_PARTS.find(part_type)
	if index <= 0:
		return ""
	for i in range(index):
		var required_type := CORE_PARTS[i]
		if not _is_installed(required_type):
			return required_type
	return ""


func _next_step_description(part_type: String) -> String:
	match part_type:
		"tripod":
			return "Start with the bottom support.\n先从底部支撑开始。"
		"mount":
			return "Add the mount above the tripod.\n把支架安装到三脚架上方。"
		"tube":
			return "Place the tube on the mount.\n把镜筒安装到支架上。"
		"objective":
			return "Install the front lens to collect light.\n安装前端物镜来收集光线。"
		"eyepiece":
			return "Install the eyepiece at the viewing end.\n把目镜安装到观察端。"
		_:
			return "Add the finder scope for easier aiming.\n安装寻星镜帮助瞄准。"


func _next_installable_part() -> String:
	for part_type in CORE_PARTS:
		if not _is_installed(part_type):
			return part_type
	if GameManager.unlocked_parts_by_type("finder_scope").is_empty():
		return ""
	if not _is_installed("finder_scope"):
		return "finder_scope"
	return ""


func _is_installed(part_type: String) -> bool:
	return bool(_dict_value(_assembly_state().get(part_type, {})).get("installed", false))


func _assembly_state() -> Dictionary:
	return _dict_value(GameManager.progress.get("assembly_state", {}))


func _dict_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _draw_grid() -> void:
	for x in range(0, 1024, 32):
		_rect(Vector2(x, 56), Vector2(1, 712), Color(0.13, 0.18, 0.20, 0.14))
	for y in range(56, 768, 32):
		_rect(Vector2(0, y), Vector2(1024, 1), Color(0.13, 0.18, 0.20, 0.14))


func _draw_line(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var points := [from_pos, to_pos]
	var line := Line2D.new()
	line.points = PackedVector2Array(points)
	line.width = 4.0
	line.default_color = color
	blueprint_layer.add_child(line)


func _panel(pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 3, 3))
	add_child(panel)
	_panel_corners(pos, panel_size, border)
	return panel


func _panel_local(parent: Control, pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 2, 4))
	parent.add_child(panel)
	return panel


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


func _rect_local(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _texture(path: String, rect_size: Vector2) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.texture = load(path)
	texture_rect.size = rect_size
	texture_rect.custom_minimum_size = rect_size
	texture_rect.ignore_texture_size = true
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return texture_rect


func _button(text: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.13, 0.22), Color(0.17, 0.25, 0.40), 2, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.22, 0.34), Color(0.95, 0.76, 0.42), 2, 3))
	button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.14, 0.08), Color(0.95, 0.76, 0.42), 2, 3))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
