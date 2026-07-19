extends Control

const AssemblyUITemplate = preload("res://scripts/ui/assembly_ui_template.gd")

const BG := Color(0.018, 0.028, 0.055)
const PANEL := Color(0.040, 0.065, 0.110)
const GOLD := Color(0.92, 0.67, 0.30)
const CYAN := Color(0.42, 0.82, 1.0)
const GREEN := Color(0.46, 0.90, 0.58)
const RED := Color(0.92, 0.38, 0.32)
const TEXT := Color(0.92, 0.91, 0.84)
const ADVANCED_FAMILY_ATLAS := "res://assets/telescope_parts/placeholders/advanced_family_atlas_placeholder.png"
const NEWTONIAN_MAIN_BLUEPRINT := "res://assets/assembly/newtonian_main_blueprint.png"
const NEWTONIAN_MAIN_SOURCE_SIZE := Vector2(563.0, 612.0)
const NEWTONIAN_MAIN_SOURCE_CROP := Rect2(Vector2.ZERO, NEWTONIAN_MAIN_SOURCE_SIZE)
const NEWTONIAN_MAIN_SOURCE_SLOTS := {
	"optical_tube_assembly": Rect2(35.0, 227.0, 91.0, 105.0),
	"finder_scope": Rect2(350.0, 109.0, 82.0, 71.0),
	"mount": Rect2(444.0, 289.0, 83.0, 90.0),
	"tripod": Rect2(256.0, 479.0, 118.0, 83.0),
}
const DOBSONIAN_MAIN_BLUEPRINT := "res://assets/assembly/dobsonian_main_blueprint.png"
const DOBSONIAN_MAIN_SOURCE_SIZE := Vector2(746.0, 879.0)
# Source-pixel rects of the dashed boxes printed on the cropped board art,
# measured by cyan-pixel detection + overlay verification (never guessed).
const DOBSONIAN_MAIN_SOURCE_SLOTS := {
	"optical_tube_assembly": Rect2(340.0, 212.0, 112.0, 125.0),
	"finder_scope": Rect2(363.0, 52.0, 72.0, 66.0),
	"mount": Rect2(292.0, 560.0, 121.0, 132.0),
}

var selected_type := ""
var order: Array[String] = []
var status_label: Label
var blueprint: Control
var template_parts_scroll: ScrollContainer
var template_parts_list: Control
var template_blueprint_layer: Control
var template_inspector_title: Label
var template_feedback: Label
var template_stats: Control
var template_ready_dot: Panel
var template_finish: Button


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _family() in ["newtonian", "dobsonian"]:
		_build_newtonian_template_main()
		return
	if _is_nested_ground_family():
		_build_nested_main()
		return
	order.clear()
	for type_value in GameManager.current_level().get("assembly_order", []):
		order.append(str(type_value))
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_label(GameManager.text("REFLECTOR ASSEMBLY BENCH", "反射镜组装台"), Vector2(20, 14), Vector2(984, 32), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Newtonian blueprint: front opening -> primary mirror -> diagonal secondary -> side focuser.", "牛顿镜蓝图：前端入光 -> 主镜 -> 斜副镜 -> 侧置调焦座。"), Vector2(20, 50), Vector2(984, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var tray := _panel(Vector2(20, 88), Vector2(278, 614), GameManager.text("REFLECTOR PARTS", "反射镜零件"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 42)
	scroll.size = Vector2(254, 558)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(236, 0)
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	for part_type in order:
		list.add_child(_part_card(part_type))

	var board_panel := _panel(Vector2(316, 88), Vector2(448, 614), GameManager.text("NEWTONIAN LIGHT PATH", "牛顿反射光路"))
	blueprint = Control.new()
	blueprint.position = Vector2(10, 38)
	blueprint.size = Vector2(428, 500)
	board_panel.add_child(blueprint)
	_draw_specialized_blueprint()

	var inspector := _panel(Vector2(782, 88), Vector2(222, 614), GameManager.text("ASSEMBLY CHECK", "组装检查"))
	var level := GameManager.current_level()
	inspector.add_child(_label(GameManager.dict_text(level, "title"), Vector2(12, 42), Vector2(198, 46), 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	status_label = _label(_status_text(), Vector2(14, 106), Vector2(194, 178), 12, TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(status_label)
	var finish := _button(GameManager.text("Finish Assembly", "完成组装"), Vector2(14, 500), Vector2(194, 42), Color(0.10, 0.30, 0.20))
	finish.pressed.connect(_finish)
	inspector.add_child(finish)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 550), Vector2(194, 34), Color(0.10, 0.14, 0.22))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	)
	inspector.add_child(back)


func _is_nested_ground_family() -> bool:
	return _family() in ["newtonian", "dobsonian", "cassegrain", "gregorian"]


func _build_nested_main() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_label(GameManager.text("ADVANCED TELESCOPE MAIN ASSEMBLY", "高级望远镜主组装台"), Vector2(20, 14), Vector2(984, 32), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Build the support system here. Assemble every mirror and optical part inside the Optical Tube Assembly.", "此处组装支撑系统。所有镜面和光学零件请在光学镜筒组件中完成。"), Vector2(30, 50), Vector2(964, 22), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	var tray := _panel(Vector2(20, 88), Vector2(278, 614), GameManager.text("MAIN COMPONENTS", "主组件"))
	var list := VBoxContainer.new()
	list.position = Vector2(16, 48)
	list.size = Vector2(246, 310)
	list.add_theme_constant_override("separation", 8)
	tray.add_child(list)
	var tray_order: Array[String] = ["tripod", "mount"]
	for subpart_value in GameManager.tube_subassembly_config().get("order", []):
		tray_order.append(str(subpart_value))
	for part_type in tray_order:
		list.add_child(_main_part_card(part_type))

	var board := _panel(Vector2(316, 88), Vector2(448, 614), GameManager.text("MAIN BLUEPRINT", "主装配蓝图"))
	blueprint = Control.new()
	blueprint.position = Vector2(10, 38)
	blueprint.size = Vector2(428, 500)
	board.add_child(blueprint)
	_draw_main_blueprint()

	var inspector := _panel(Vector2(782, 88), Vector2(222, 614), GameManager.text("ASSEMBLY CHECK", "组装检查"))
	status_label = _label(_main_status_text(), Vector2(14, 50), Vector2(194, 196), 12, TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(status_label)
	var finish := _button(GameManager.text("Finish Main Assembly", "完成主组装"), Vector2(14, 500), Vector2(194, 42), Color(0.10, 0.30, 0.20))
	finish.pressed.connect(_finish)
	inspector.add_child(finish)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 550), Vector2(194, 34), Color(0.10, 0.14, 0.22))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("assembly"); GameManager.go("observatory"))
	inspector.add_child(back)


func _build_newtonian_template_main() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.006, 0.009, 0.018))
	AssemblyUITemplate.add_title_bar(
		self,
		GameManager.text("Telescope Assembly", "望远镜组装台"),
		GameManager.text("Pick a part, then click its blueprint slot.", "选择零件，再点击蓝图安装位。")
	)
	AssemblyUITemplate.add_titled_panel(self, AssemblyUITemplate.LEFT_PANEL_RECT, GameManager.text("Parts Tray", "零件托盘"))
	AssemblyUITemplate.add_blueprint_panel(self, GameManager.text("Blueprint", "蓝图"))

	template_parts_scroll = ScrollContainer.new()
	template_parts_scroll.position = AssemblyUITemplate.PARTS_SCROLL_RECT.position
	template_parts_scroll.size = AssemblyUITemplate.PARTS_SCROLL_RECT.size
	template_parts_scroll.clip_contents = true
	template_parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(template_parts_scroll)
	template_parts_list = Control.new()
	template_parts_list.custom_minimum_size = AssemblyUITemplate.PARTS_LIST_SIZE
	template_parts_list.size = AssemblyUITemplate.PARTS_LIST_SIZE
	template_parts_scroll.add_child(template_parts_list)

	var y := 0.0
	for part_type in _main_parts():
		_add_newtonian_main_card(part_type, Vector2(0, y))
		y += AssemblyUITemplate.PART_CARD_STEP
	template_parts_list.custom_minimum_size.y = maxf(560.0, y)
	template_parts_list.size = template_parts_list.custom_minimum_size

	template_blueprint_layer = Control.new()
	template_blueprint_layer.position = Vector2(344, 122)
	template_blueprint_layer.size = Vector2(412, 448)
	add_child(template_blueprint_layer)
	var config := _main_blueprint_config()
	var source_size: Vector2 = config["size"]
	var slots: Dictionary = config["slots"]
	var layout := _calculate_blueprint_layout(source_size, Rect2(Vector2.ZERO, source_size), Rect2(Vector2.ZERO, template_blueprint_layer.size))
	var blueprint_image := TextureRect.new()
	blueprint_image.custom_minimum_size = Vector2.ZERO
	blueprint_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blueprint_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blueprint_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blueprint_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_image.texture = load(str(config["path"])) as Texture2D
	blueprint_image.position = layout["display_rect"].position
	blueprint_image.size = layout["display_rect"].size
	template_blueprint_layer.add_child(blueprint_image)
	for part_type in slots.keys():
		var slot_rect := _source_rect_to_blueprint(slots[part_type], layout)
		_newtonian_reference_slot(template_blueprint_layer, str(part_type), slot_rect)

	var helper := _label(GameManager.text("Select a card, then click the matching slot.", "选择零件卡，再点击对应安装位。"), Vector2(346, 580), Vector2(408, 28), 12, Color(0.72, 0.82, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(helper)
	var order_hint := GameManager.text("Tripod -> Mount -> Tube Assembly -> Finder", "三脚架 -> 支架 -> 镜筒组件 -> 寻星镜")
	if _family() == "dobsonian":
		order_hint = GameManager.text("Rocker Mount -> Tube Assembly -> Finder", "摇箱底座 -> 镜筒组件 -> 寻星镜")
	var order_text := _label(order_hint, Vector2(346, 614), Vector2(408, 22), 11, Color(0.56, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(order_text)

	var back_callback := func() -> void:
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	var shell := AssemblyUITemplate.add_inspector_shell(
		self,
		GameManager.text("Inspector", "检查器"),
		GameManager.text("Finish Assembly", "完成组装"),
		GameManager.text("Reassemble", "重装"),
		GameManager.text("Back", "返回"),
		_finish,
		_reset_newtonian_main,
		back_callback
	)
	template_inspector_title = shell["status"]
	template_feedback = shell["feedback"]
	template_stats = shell["stats"]
	template_ready_dot = shell["ready_dot"]
	template_finish = shell["finish"]
	status_label = template_feedback
	AssemblyUITemplate.add_hints_toggle(self, GameManager, _build)
	_refresh_newtonian_main_inspector()


func _add_newtonian_main_card(part_type: String, position: Vector2) -> void:
	var part := _main_template_part(part_type)
	var installed := _installed(part_type)
	var status_text := GameManager.text("Installed", "已安装") if installed else GameManager.text("Not Installed", "未安装")
	if part_type == "optical_tube_assembly":
		# Three card states: internals not built yet / built but not mounted /
		# mounted. The tube stays reopenable in every state (never one-shot).
		var built := GameManager.advanced_tube_completed()
		if installed:
			status_text = GameManager.text("Installed · click to edit", "已安装 · 点击可编辑")
		elif built:
			status_text = GameManager.text("Built · install on mount", "已组装 · 待装上支架")
		else:
			status_text = GameManager.text("%d/%d subparts · click to open", "%d/%d 子零件 · 点击打开") % [_tube_installed_count(), _tube_total_count()]
	var selected := selected_type == part_type
	var texture_path := str(part.get("icon_path", ""))
	var texture := load(texture_path) as Texture2D if texture_path != "" and ResourceLoader.exists(texture_path) else null
	AssemblyUITemplate.add_part_card(
		template_parts_list,
		position,
		GameManager.dict_text(part, "name"),
		_main_part_role(part_type),
		status_text,
		texture,
		installed,
		selected,
		_select_newtonian_main_part.bind(part_type)
	)


func _tube_installed_count() -> int:
	var state: Dictionary = GameManager.tube_assembly()
	var subparts: Dictionary = state.get("installed_subparts", state.get("tube_assembly_state", {}))
	var count := 0
	for key in subparts.keys():
		if bool(subparts[key]):
			count += 1
	return count


func _tube_total_count() -> int:
	return GameManager.tube_subassembly_config().get("order", []).size()


func _can_open_tube() -> bool:
	# The tube bench opens only after the external support exists - but once
	# open-able it stays open-able forever, installed or not.
	for part_type in _main_parts():
		if part_type in ["tripod", "mount"] and not _installed(part_type):
			return false
	return true


func _open_tube_or_hint() -> void:
	if not _can_open_tube():
		if _family() == "dobsonian":
			status_label.text = GameManager.text(
				"Install the Rocker Mount first.",
				"请先安装摇箱底座。"
			)
		else:
			status_label.text = GameManager.text(
				"Install the external components first: Tripod, then Mount.",
				"请先安装外部组件：先三脚架，再支架。"
			)
		return
	if GameManager.try_story_mechanic("tube_subassembly", "optical_tube_assembly"):
		return
	GameManager.go("optical_tube_assembly")


func _main_blueprint_config() -> Dictionary:
	if _family() == "dobsonian":
		return {"path": DOBSONIAN_MAIN_BLUEPRINT, "size": DOBSONIAN_MAIN_SOURCE_SIZE, "slots": DOBSONIAN_MAIN_SOURCE_SLOTS}
	return {"path": NEWTONIAN_MAIN_BLUEPRINT, "size": NEWTONIAN_MAIN_SOURCE_SIZE, "slots": NEWTONIAN_MAIN_SOURCE_SLOTS}


func _main_template_part(part_type: String) -> Dictionary:
	# The main bench reuses formal part sprites. Its optical tube is the
	# completed subassembly.
	match part_type:
		"tripod":
			return GameManager.get_part("basic_tripod")
		"mount":
			if _family() == "dobsonian":
				return GameManager.get_part("dobsonian_rocker_mount")
			# Newtonian mounts are a free slot now (upgrades like the
			# Tracking Mount are legal): show whatever is equipped.
			var equipped_mount := GameManager.get_part(GameManager.equipped_part_id("mount"))
			if not equipped_mount.is_empty() and str(equipped_mount.get("telescope_family", "")) in ["", _family()]:
				return equipped_mount
			return GameManager.get_part("basic_mount")
		"finder_scope":
			return GameManager.get_part("basic_finder_scope")
	if part_type == "optical_tube_assembly":
		if _family() == "dobsonian":
			return {
				"id": "dobsonian_optical_tube_assembly",
				"name_en": "Dobsonian Optical Tube Assembly",
				"name_zh": "多布森光学镜筒组件",
				"description_en": "A completed mirror, focuser, and eyepiece subassembly.",
				"description_zh": "由反射镜、调焦器和目镜组成的完整镜筒组件。",
				"icon_path": "res://assets/telescope_parts/dobsonian/dobsonian_reflector_tube.png",
			}
		return {
			"id": "newtonian_optical_tube_assembly",
			"name_en": "Newtonian Optical Tube Assembly",
			"name_zh": "牛顿光学镜筒组件",
			"description_en": "A completed mirror, focuser, and eyepiece subassembly.",
			"description_zh": "由反射镜、调焦器和目镜组成的完整镜筒组件。",
			"icon_path": "res://assets/telescope_parts/newtonian/newtonian_tube_complete.png",
		}
	return _part_for_type(part_type)


func _main_part_role(part_type: String) -> String:
	match part_type:
		"tripod": return GameManager.text("Base support", "底部支撑")
		"mount":
			if _family() == "dobsonian":
				return GameManager.text("Rocker box support", "摇箱支撑")
			return GameManager.text("Equatorial support", "赤道仪支撑")
		"optical_tube_assembly": return GameManager.text("Completed optical path", "完整光学组件")
		"finder_scope": return GameManager.text("Wide-field aiming", "宽视场寻星")
	return ""


func _select_newtonian_main_part(part_type: String) -> void:
	selected_type = part_type
	_build()


func _reset_newtonian_main() -> void:
	GameManager.reset_assembly()
	selected_type = ""
	_build()


func _refresh_newtonian_main_inspector() -> void:
	# Three honest states (never a hardcoded READY): missing parts ->
	# ASSEMBLING; everything mounted but collimation pending -> NEEDS
	# COLLIMATION; all conditions met -> READY.
	var parts_ready := GameManager.telescope_is_ready()
	var needs_collimation := bool(GameManager.current_level().get("requires_collimation", false)) \
		and not GameManager.collimation_is_acceptable()
	if not parts_ready:
		template_inspector_title.text = GameManager.text("ASSEMBLING", "组装中")
		template_inspector_title.add_theme_color_override("font_color", GOLD)
		_set_template_ready_dot(GOLD)
		template_finish.text = GameManager.text("Finish Assembly", "完成组装")
		template_finish.disabled = true
	elif needs_collimation:
		template_inspector_title.text = GameManager.text("COLLIMATE", "需要准直")
		template_inspector_title.add_theme_color_override("font_color", Color(0.95, 0.62, 0.30))
		_set_template_ready_dot(Color(0.95, 0.62, 0.30))
		template_finish.text = GameManager.text("Collimate Mirrors", "准直镜面")
		template_finish.disabled = false
	else:
		template_inspector_title.text = GameManager.text("READY", "已就绪")
		template_inspector_title.add_theme_color_override("font_color", GREEN)
		_set_template_ready_dot(GREEN)
		template_finish.text = GameManager.text("Finish Assembly", "完成组装")
		template_finish.disabled = false
	if selected_type != "":
		var part := _main_template_part(selected_type)
		var extra := GameManager.text("Click the matching blueprint slot.", "请点击对应蓝图安装位。")
		if selected_type == "optical_tube_assembly":
			extra = GameManager.text("Use the button below to open it.", "用下方按钮打开镜筒内部。")
		template_feedback.text = GameManager.dict_text(part, "name") + "\n" + extra
	else:
		template_feedback.text = _main_status_text()
	_clear_control(template_stats)
	var stats := GameManager.calculate_stats()
	var tube_state := GameManager.tube_assembly()
	var rows := [
		[GameManager.text("STABILITY", "稳定性"), float(stats.get("stability_score", 0.0)) / 100.0],
		[GameManager.text("OPTICS", "光学"), float(tube_state.get("subassembly_score", 0.0)) / 100.0],
		[GameManager.text("ALIGNMENT", "对齐"), GameManager.collimation_score() / 100.0],
		[GameManager.text("ASSEMBLY", "组装"), float(stats.get("assembly_score", 0.0)) / 100.0],
	]
	for index in range(rows.size()):
		_add_template_stat(template_stats, str(rows[index][0]), float(rows[index][1]), float(index) * 50.0)
	# Prominent, always-available tube entrance (item: the player must never
	# have to guess how to get back inside the optical tube).
	var tube_button := Button.new()
	var built := GameManager.advanced_tube_completed()
	tube_button.text = GameManager.text("Edit Optical Tube", "编辑光学镜筒") if built else GameManager.text("Open Optical Tube", "打开光学镜筒")
	tube_button.position = Vector2(0, 206)
	tube_button.size = Vector2(200, 42)
	tube_button.add_theme_font_size_override("font_size", 13)
	tube_button.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	var tube_style := StyleBoxFlat.new()
	tube_style.bg_color = Color(0.05, 0.14, 0.22)
	tube_style.border_color = CYAN
	tube_style.set_border_width_all(2)
	tube_style.set_corner_radius_all(5)
	var tube_hover := tube_style.duplicate()
	tube_hover.bg_color = Color(0.09, 0.20, 0.30)
	tube_button.add_theme_stylebox_override("normal", tube_style)
	tube_button.add_theme_stylebox_override("hover", tube_hover)
	tube_button.add_theme_stylebox_override("pressed", tube_style)
	tube_button.pressed.connect(_open_tube_or_hint)
	template_stats.add_child(tube_button)


func _set_template_ready_dot(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.14)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	template_ready_dot.add_theme_stylebox_override("panel", style)


func _add_template_stat(parent: Control, stat_name: String, ratio: float, y: float) -> void:
	var label := _label(stat_name, Vector2(0, y), Vector2(200, 18), 11, Color(0.86, 0.90, 0.94))
	parent.add_child(label)
	var clamped := clampf(ratio, 0.0, 1.0)
	for index in range(8):
		var cell := ColorRect.new()
		cell.position = Vector2(float(index) * 24.0, y + 24.0)
		cell.size = Vector2(20, 14)
		cell.color = GREEN if index < roundi(clamped * 8.0) else Color(0.10, 0.16, 0.14)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cell)


func _clear_control(parent: Control) -> void:
	for child in parent.get_children():
		child.queue_free()


func _build_newtonian_reference_main() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	add_child(_label(GameManager.text("NEWTONIAN REFLECTOR MAIN ASSEMBLY", "牛顿反射式望远镜主组装"), Vector2(20, 14), Vector2(984, 30), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_label(GameManager.text("Install the external support here. Open the Optical Tube Assembly to build the internal reflector path.", "此处安装外部支撑。打开光学镜筒组件，完成内部反射光路。"), Vector2(24, 46), Vector2(976, 26), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var tray := _panel(Vector2(20, 88), Vector2(278, 614), GameManager.text("PARTS TRAY", "零件托盘"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 42)
	scroll.size = Vector2(254, 558)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(236, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	# Only external components belong on the main bench. Internal optical
	# components exist exclusively in the Optical Tube sub-blueprint.
	var tray_order: Array[String] = ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	for part_type in tray_order:
		list.add_child(_main_part_card(part_type))
	var center := _panel(Vector2(316, 88), Vector2(448, 614), GameManager.text("BLUEPRINT", "蓝图"))
	var blueprint_visual := Control.new()
	blueprint_visual.position = Vector2(10, 72)
	blueprint_visual.size = Vector2(428, 466)
	center.add_child(blueprint_visual)
	var layout := _calculate_blueprint_layout(NEWTONIAN_MAIN_SOURCE_SIZE, NEWTONIAN_MAIN_SOURCE_CROP, Rect2(Vector2.ZERO, blueprint_visual.size))
	var reference := TextureRect.new()
	reference.custom_minimum_size = Vector2.ZERO
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference.texture = load(NEWTONIAN_MAIN_BLUEPRINT) as Texture2D
	reference.position = layout["display_rect"].position
	reference.size = layout["display_rect"].size
	blueprint_visual.add_child(reference)
	for part_type in NEWTONIAN_MAIN_SOURCE_SLOTS.keys():
		var local_rect := _source_rect_to_blueprint(NEWTONIAN_MAIN_SOURCE_SLOTS[part_type], layout)
		_newtonian_reference_slot(blueprint_visual, str(part_type), local_rect)
	var inspector := Panel.new()
	inspector.position = Vector2(770, 209)
	inspector.size = Vector2(216, 390)
	inspector.add_theme_stylebox_override("panel", _style(Color(0.025, 0.05, 0.08, 0.93), GOLD, 2))
	add_child(inspector)
	var hardware_ready := GameManager.telescope_is_ready()
	var needs_collimation := hardware_ready and bool(GameManager.current_level().get("requires_collimation", false)) and not GameManager.collimation_is_acceptable()
	var ready := hardware_ready and not needs_collimation
	var status := GameManager.text("READY", "已就绪") if ready else (GameManager.text("NEEDS COLLIMATION", "需要准直") if needs_collimation else GameManager.text("NOT READY", "未就绪"))
	inspector.add_child(_label(status, Vector2(10, 18), Vector2(196, 34), 20, GREEN if ready else (GOLD if needs_collimation else RED), HORIZONTAL_ALIGNMENT_CENTER))
	var tube_state := GameManager.tube_assembly()
	var sub_score := float(tube_state.get("subassembly_score", 0.0))
	inspector.add_child(_label(GameManager.text("Stability: %d" % roundi(GameManager.calculate_stats().get("stability_score", 0.0)), "稳定性：%d" % roundi(GameManager.calculate_stats().get("stability_score", 0.0))), Vector2(14, 76), Vector2(188, 22), 12, CYAN))
	inspector.add_child(_label(GameManager.text("Optics: %d" % roundi(sub_score), "光学：%d" % roundi(sub_score)), Vector2(14, 108), Vector2(188, 22), 12, CYAN))
	inspector.add_child(_label(GameManager.text("Collimation: %d%%" % roundi(GameManager.collimation_score()), "准直：%d%%" % roundi(GameManager.collimation_score())), Vector2(14, 140), Vector2(188, 22), 12, CYAN))
	var primary := _part_for_type("primary_mirror")
	var aperture := float(primary.get("aperture_mm", 0.0))
	var focal_length := float(primary.get("focal_length_mm", 0.0))
	var focal_ratio := focal_length / aperture if aperture > 0.0 else 0.0
	inspector.add_child(_label(GameManager.text("Aperture: %d mm" % roundi(aperture), "口径：%d mm" % roundi(aperture)), Vector2(14, 166), Vector2(188, 20), 11, CYAN))
	inspector.add_child(_label(GameManager.text("Focal: %d mm" % roundi(focal_length), "焦距：%d mm" % roundi(focal_length)), Vector2(14, 186), Vector2(188, 20), 11, CYAN))
	inspector.add_child(_label(GameManager.text("F-ratio: f/%.1f" % focal_ratio, "焦比：f/%.1f" % focal_ratio), Vector2(14, 206), Vector2(188, 20), 11, CYAN))
	# Built by hand (not the shared _label() helper) because property ORDER
	# matters here: Control.size always clamps up to the current minimum
	# size, and a Label's minimum size is computed from its shaped text
	# under whatever autowrap_mode was active AT SHAPING TIME. _label()
	# sets .text before autowrap is ever touched, so the first shape pass
	# happens unwrapped at natural (huge) width, permanently baking that
	# width in as the minimum - later setting autowrap_mode or reassigning
	# .size can't shrink it back down. Setting autowrap BEFORE .text avoids
	# that trap entirely.
	status_label = Label.new()
	status_label.position = Vector2(14, 234)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = _main_status_text()
	status_label.size = Vector2(188, 62)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", TEXT)
	inspector.add_child(status_label)
	var finish_text := GameManager.text("Collimate Mirrors", "准直镜面") if needs_collimation else GameManager.text("Finish Assembly", "完成组装")
	var finish := _button(finish_text, Vector2(14, 306), Vector2(188, 42), Color(0.28, 0.20, 0.06) if needs_collimation else Color(0.10, 0.30, 0.20))
	# Hardware completion unlocks this button. When collimation is pending,
	# _finish() routes into the collimation lesson instead of deadlocking behind
	# a disabled control.
	finish.disabled = not hardware_ready
	finish.pressed.connect(_finish)
	inspector.add_child(finish)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 352), Vector2(188, 28), Color(0.10, 0.14, 0.22))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("assembly"); GameManager.go("observatory"))
	inspector.add_child(back)


func _calculate_blueprint_layout(source_size: Vector2, source_crop: Rect2, bounds: Rect2) -> Dictionary:
	var crop := source_crop.intersection(Rect2(Vector2.ZERO, source_size))
	if crop.size.x <= 0.0 or crop.size.y <= 0.0:
		crop = Rect2(Vector2.ZERO, source_size)
	var scale_factor := minf(bounds.size.x / crop.size.x, bounds.size.y / crop.size.y)
	var display_size := crop.size * scale_factor
	var centered_offset := (bounds.size - display_size) * 0.5
	return {
		"source_size": source_size,
		"source_crop": crop,
		"display_rect": Rect2(bounds.position + centered_offset, display_size),
		"scale": scale_factor,
	}


func _source_rect_to_blueprint(source_rect: Rect2, layout: Dictionary) -> Rect2:
	var crop: Rect2 = layout["source_crop"]
	var display_rect: Rect2 = layout["display_rect"]
	var scale_factor := float(layout["scale"])
	var cropped_position := source_rect.position - crop.position
	return Rect2(display_rect.position + cropped_position * scale_factor, source_rect.size * scale_factor)


func _blueprint_rect_to_screen(parent: Control, local_rect: Rect2) -> Rect2:
	var transform := parent.get_global_transform_with_canvas()
	return Rect2(transform * local_rect.position, transform.basis_xform(local_rect.size))


func debug_newtonian_main_slot_geometry() -> Dictionary:
	var result := {}
	if template_blueprint_layer == null:
		return result
	var config := _main_blueprint_config()
	var source_size: Vector2 = config["size"]
	var slots: Dictionary = config["slots"]
	var layout := _calculate_blueprint_layout(
		source_size,
		Rect2(Vector2.ZERO, source_size),
		Rect2(Vector2.ZERO, template_blueprint_layer.size)
	)
	for part_type_value in slots.keys():
		var part_type := str(part_type_value)
		var source_rect: Rect2 = slots[part_type]
		var local_rect := _source_rect_to_blueprint(source_rect, layout)
		var slot := template_blueprint_layer.find_child("MainSlot_%s" % part_type, true, false) as Control
		var texture := template_blueprint_layer.find_child("MainTexture_%s" % part_type, true, false) as TextureRect
		result[part_type] = {
			"source_rect": source_rect,
			"blueprint_local_rect": local_rect,
			"screen_rect": _blueprint_rect_to_screen(template_blueprint_layer, local_rect),
			"installed_texture_rect": Rect2(slot.position + texture.position, texture.size) if slot != null and texture != null else Rect2(),
		}
	return result


func _newtonian_reference_slot(parent: Control, part_type: String, rect: Rect2) -> void:
	# The printed blueprint already carries this slot's dashed box AND its
	# label (e.g. "SECONDARY SPIDER") baked into the 730x730 art - drawing a
	# second text label or a permanent colored rectangle here would both
	# duplicate it and read as a debug overlay. So idle slots get NO visual
	# chrome at all (just an invisible click target); the only state chrome
	# is a gold border on the currently selected slot, and a small green
	# check badge once installed.
	var installed := _installed(part_type)
	if part_type == "optical_tube_assembly":
		installed = bool(GameManager.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false))
	var selected := selected_type == part_type
	var slot := Control.new()
	slot.name = "MainSlot_%s" % part_type
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(slot)

	# Layer order: installed PNG, state frame, OK badge, click target.
	if installed:
		var part := _main_template_part(part_type)
		var icon_path := str(part.get("icon_path", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var loaded_texture := load(icon_path) as Texture2D
			if loaded_texture != null:
				var installed_texture := TextureRect.new()
				installed_texture.name = "MainTexture_%s" % part_type
				installed_texture.custom_minimum_size = Vector2.ZERO
				installed_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				installed_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				installed_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				installed_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
				installed_texture.texture = loaded_texture
				installed_texture.position = Vector2.ZERO
				installed_texture.size = rect.size
				installed_texture.modulate = Color.WHITE
				slot.add_child(installed_texture)

	if selected and not installed:
		var border := Panel.new()
		border.position = Vector2.ZERO
		border.size = rect.size
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = GOLD
		style.set_border_width_all(2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		border.add_theme_stylebox_override("panel", style)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(border)
	elif installed:
		var completion_frame := Panel.new()
		completion_frame.name = "MainFrame_%s" % part_type
		completion_frame.position = Vector2.ZERO
		completion_frame.size = rect.size
		var completion_style := StyleBoxFlat.new()
		completion_style.bg_color = Color(0, 0, 0, 0)
		completion_style.border_color = GREEN
		completion_style.set_border_width_all(2)
		completion_style.set_corner_radius_all(4)
		completion_frame.add_theme_stylebox_override("panel", completion_style)
		completion_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(completion_frame)

		var badge_size := 20.0
		var badge_pos := Vector2(maxf(0.0, rect.size.x - badge_size), 0.0)
		var backdrop := Panel.new()
		backdrop.position = badge_pos
		backdrop.size = Vector2(badge_size, badge_size)
		var backdrop_style := StyleBoxFlat.new()
		backdrop_style.bg_color = Color(0.04, 0.10, 0.06, 0.92)
		backdrop_style.border_color = GREEN
		backdrop_style.set_border_width_all(2)
		backdrop_style.corner_radius_top_left = 10
		backdrop_style.corner_radius_top_right = 10
		backdrop_style.corner_radius_bottom_left = 10
		backdrop_style.corner_radius_bottom_right = 10
		backdrop.add_theme_stylebox_override("panel", backdrop_style)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(backdrop)
		var badge := _label("✓", badge_pos, Vector2(badge_size, badge_size), 14, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)

	AssemblyUITemplate.add_slot_hit_target(slot, Rect2(Vector2.ZERO, rect.size), func() -> void:
		if part_type == "optical_tube_assembly":
			# The tube slot doubles as the sub-bench entrance and it NEVER
			# locks: not built -> open to build; built + selected -> install
			# on the mount; installed -> open again to view/edit.
			var built := GameManager.advanced_tube_completed()
			if installed:
				_open_tube_or_hint()
				return
			if not built:
				_open_tube_or_hint()
				return
			if selected_type == part_type:
				_install_main_part(part_type)
			else:
				status_label.text = GameManager.text(
					"Tube is built. Select its card, then click here to mount it - or click again to edit it.",
					"镜筒已组装。选中它的卡片后点此安装到支架；再次点击可继续编辑内部。"
				)
			return
		if selected_type == "":
			status_label.text = GameManager.text("Select a part card from the left first.", "请先从左侧选择零件卡。")
			return
		if selected_type != part_type:
			status_label.text = GameManager.text("Wrong slot. Select the matching blueprint position.", "安装位不正确，请点击与所选零件对应的蓝图位置。")
			return
		_install_main_part(part_type)
	)


func _main_parts() -> Array[String]:
	if _family() == "newtonian":
		return ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	if _family() == "dobsonian":
		return ["mount", "optical_tube_assembly", "finder_scope"]
	return ["tripod", "mount", "optical_tube_assembly"]


func _main_part_card(part_type: String) -> Control:
	var is_tube_subpart := _is_newtonian_tube_subpart(part_type)
	var completed := GameManager.advanced_tube_completed() if part_type == "optical_tube_assembly" else (_subpart_installed(part_type) if is_tube_subpart else _installed(part_type))
	var card := Panel.new()
	card.custom_minimum_size = Vector2(246, 62)
	card.add_theme_stylebox_override("panel", _style(Color(0.075, 0.10, 0.15), GREEN if completed else Color(0.25, 0.43, 0.66), 2))
	var title_text := GameManager.text("Optical Tube Assembly", "光学镜筒组件") if part_type == "optical_tube_assembly" else GameManager.dict_text(_part_for_type(part_type), "name")
	var title := _label(title_text, Vector2(9, 5), Vector2(172, 22), 12, TEXT)
	title.clip_text = true
	card.add_child(title)
	var status := GameManager.text("Installed", "已安装") if completed else (GameManager.text("Open tube blueprint", "进入镜筒子蓝图") if part_type == "optical_tube_assembly" or is_tube_subpart else GameManager.text("Select", "选择"))
	card.add_child(_label(status, Vector2(9, 32), Vector2(132, 18), 10, GREEN if completed else CYAN))
	var use := Button.new()
	use.text = GameManager.text("Open", "打开") if (part_type == "optical_tube_assembly" or is_tube_subpart) and not completed else GameManager.text("Use", "使用")
	use.position = Vector2(186, 13)
	use.size = Vector2(50, 34)
	use.add_theme_font_size_override("font_size", 10)
	use.pressed.connect(func() -> void:
		if (part_type == "optical_tube_assembly" or is_tube_subpart) and not GameManager.advanced_tube_completed():
			GameManager.go("optical_tube_assembly")
			return
		selected_type = part_type
		status_label.text = GameManager.text("Selected " + title_text + ". Click its marked main slot.", "已选择" + title_text + "。请点击对应主装配槽位。")
		if _family() == "newtonian":
			_build()
		else:
			_draw_main_blueprint()
	)
	card.add_child(use)
	return card


func _is_newtonian_tube_subpart(part_type: String) -> bool:
	return _family() == "newtonian" and part_type in ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"]


func _subpart_installed(part_type: String) -> bool:
	var state := GameManager.tube_assembly()
	var subparts: Dictionary = state.get("installed_subparts", state.get("tube_assembly_state", {}))
	return bool(subparts.get(part_type, false))


func _draw_main_blueprint() -> void:
	for child in blueprint.get_children():
		child.queue_free()
	var art := TextureRect.new()
	art.texture = _main_family_art_texture()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = Vector2(32, 38)
	art.size = Vector2(364, 300)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint.add_child(art)
	var placements := {"tripod": Rect2(166, 378, 100, 60), "mount": Rect2(148, 308, 140, 54), "optical_tube_assembly": Rect2(78, 154, 272, 82)}
	for part_type in _main_parts():
		_draw_main_slot(part_type, placements.get(part_type, Rect2(150, 300, 120, 48)))


func _draw_main_slot(part_type: String, rect: Rect2) -> void:
	var tube_completed := GameManager.advanced_tube_completed()
	var installed_main := _installed(part_type)
	if part_type == "optical_tube_assembly":
		installed_main = bool(GameManager.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false))
	var active := selected_type == part_type
	var color := GREEN if installed_main else (GOLD if active or (part_type == "optical_tube_assembly" and not tube_completed) else Color(0.35, 0.66, 0.90))
	var slot := Panel.new()
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	slot.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.13, 0.78), color, 2))
	blueprint.add_child(slot)
	var label_text := ""
	var main_part := _part_for_type(part_type) if part_type != "optical_tube_assembly" else {}
	if not main_part.is_empty():
		var main_icon := _part_texture_control(main_part, Rect2(5, 4, rect.size.x - 10, rect.size.y - 8))
		if main_icon != null:
			slot.add_child(main_icon)
	if part_type == "optical_tube_assembly":
		label_text = GameManager.text("Optical Tube Assembly complete" if tube_completed else "Optical Tube Assembly\nClick to open sub-blueprint", "光学镜筒组件已完成" if tube_completed else "光学镜筒组件\n点击进入子蓝图")
	else:
		label_text = GameManager.dict_text(_part_for_type(part_type), "name") if installed_main else _short_type(part_type)
	var label := _label(label_text, Vector2(4, 4), rect.size - Vector2(8, 8), 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.pressed.connect(func() -> void:
		if part_type == "optical_tube_assembly" and not tube_completed:
			GameManager.go("optical_tube_assembly")
			return
		_install_main_part(part_type)
	)
	slot.add_child(hit)


func _install_main_part(part_type: String) -> void:
	if _installed(part_type):
		status_label.text = GameManager.text("This main component is already installed.", "该主组件已经安装。")
		return
	if selected_type != part_type:
		status_label.text = GameManager.text("Select this main component from the left first.", "请先从左侧选择该主组件。")
		return
	var index := _main_parts().find(part_type)
	if index > 0 and not _installed(_main_parts()[index - 1]):
		status_label.text = GameManager.text("Install " + _short_type(_main_parts()[index - 1]) + " first.", "请先安装" + _short_type(_main_parts()[index - 1]) + "。")
		return
	if part_type == "optical_tube_assembly" and not GameManager.advanced_tube_completed():
		status_label.text = GameManager.text("Complete the Optical Tube Assembly first.", "请先完成光学镜筒组件。")
		return
	GameManager.install_part(part_type, 0)
	GameManager.sync_newtonian_installed_equipment()
	selected_type = ""
	_build()


func _main_status_text() -> String:
	if not GameManager.advanced_tube_completed():
		return GameManager.text("The mirror system is not assembled yet. Open Optical Tube Assembly and build the internal light path first.", "镜面系统尚未组装。请打开光学镜筒组件，先完成内部光路。")
	var missing: Array = GameManager.missing_parts()
	if not missing.is_empty():
		return GameManager.text("Install the remaining main components: " + ", ".join(missing) + ".", "请安装剩余主组件：" + ", ".join(missing) + "。")
	if bool(GameManager.current_level().get("requires_collimation", false)) and not GameManager.collimation_is_acceptable():
		var threshold := int(GameManager.current_level().get("collimation_threshold", 80))
		return GameManager.text(
			"Hardware complete. Click Collimate Mirrors and align the optical axis to at least %d%%." % threshold,
			"硬件已装齐。点击“准直镜面”，将光轴校准到至少 %d%%。" % threshold
		)
	return GameManager.text("Support system and completed tube are installed. Finish main assembly to continue.", "支撑系统和完整镜筒已安装。完成主组装后即可继续。")


func _main_family_art_texture() -> Texture2D:
	return _family_art_texture(_family())


func _part_texture_control(part: Dictionary, bounds: Rect2) -> TextureRect:
	var path := str(part.get("icon_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = bounds.position
	icon.size = bounds.size
	icon.custom_minimum_size = Vector2.ZERO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _part_card(part_type: String) -> Control:
	var part := _part_for_type(part_type)
	var installed := _installed(part_type)
	var card := Panel.new()
	card.custom_minimum_size = Vector2(236, 54)
	card.add_theme_stylebox_override("panel", _style(Color(0.075, 0.10, 0.15), GREEN if installed else Color(0.25, 0.43, 0.66), 2))
	var title := _label(GameManager.dict_text(part, "name"), Vector2(10, 5), Vector2(166, 18), 12, TEXT)
	title.clip_text = true
	card.add_child(title)
	card.add_child(_label(GameManager.text("Installed", "已安装") if installed else GameManager.text("Select", "选择"), Vector2(10, 27), Vector2(92, 16), 11, GREEN if installed else CYAN))
	var choose := Button.new()
	choose.text = GameManager.text("Use", "使用")
	choose.position = Vector2(180, 10)
	choose.size = Vector2(46, 32)
	choose.add_theme_font_size_override("font_size", 11)
	choose.pressed.connect(func() -> void:
		selected_type = part_type
		status_label.text = GameManager.text("Selected " + GameManager.dict_text(part, "name") + ". Click its marked slot.", "已选择" + GameManager.dict_text(part, "name") + "，请点击对应安装位。")
		_draw_specialized_blueprint()
	)
	card.add_child(choose)
	return card


func _family() -> String:
	return str(GameManager.current_level().get("telescope_family", "newtonian"))


func _draw_specialized_blueprint() -> void:
	var family := _family()
	var art := TextureRect.new()
	art.texture = _family_art_texture(family)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = Vector2(28, 40)
	art.size = Vector2(372, 330)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint.add_child(art)
	var caption := _label_to(blueprint, _family_caption(family), Vector2(16, 374), Vector2(396, 34), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var placements := _specialized_slot_positions(family)
	for part_type in order:
		_draw_slot(part_type, placements.get(part_type, Rect2(156, 430, 116, 42)))


func _family_caption(family: String) -> String:
	match family:
		"dobsonian": return GameManager.text("Dobsonian: direct hand-guided wide-field reflector", "多布森：直接手动引导的宽视场反射镜")
		"cassegrain": return GameManager.text("Cassegrain: compact tube, long folded focal length", "卡塞格林：紧凑镜筒，长焦距折叠光路")
		"gregorian": return GameManager.text("Gregorian: a different two-concave-mirror light path", "格里高利：不同的双凹面镜光路")
		"space_segmented": return GameManager.text("Segmented infrared mirror and thermal protection", "分段红外主镜与热控保护")
		"fast_radio": return GameManager.text("Radio dish, feed cabin, then signal data", "无线电反射面、馈源舱，再到信号数据")
	return ""


func _specialized_slot_positions(family: String) -> Dictionary:
	match family:
		"dobsonian":
			return {"mount": Rect2(126, 286, 160, 48), "reflector_tube": Rect2(54, 132, 180, 48), "primary_mirror": Rect2(242, 132, 132, 48), "secondary_mirror": Rect2(104, 92, 120, 36), "focuser": Rect2(232, 82, 118, 36), "eyepiece": Rect2(254, 48, 92, 30)}
		"cassegrain", "gregorian":
			return {"mount": Rect2(140, 290, 140, 48), "reflector_tube": Rect2(88, 138, 176, 48), "primary_mirror": Rect2(272, 138, 122, 48), "secondary_mirror": Rect2(108, 102, 126, 34), "focuser": Rect2(280, 90, 110, 34), "eyepiece": Rect2(288, 54, 94, 30)}
		"space_segmented":
			return {"primary_mirror": Rect2(128, 114, 170, 44), "secondary_mirror": Rect2(146, 70, 134, 34), "detector": Rect2(118, 238, 170, 42), "sunshield": Rect2(88, 286, 234, 44)}
		"fast_radio":
			return {"radio_dish": Rect2(94, 136, 220, 54), "receiver": Rect2(144, 82, 128, 38), "signal_processor": Rect2(120, 276, 172, 46)}
	return {}


func _family_art_texture(family: String) -> Texture2D:
	var image := Image.load_from_file(ADVANCED_FAMILY_ATLAS)
	if image == null or image.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	match family:
		"dobsonian": atlas.region = Rect2(0, 0, 626, 630)
		"cassegrain": atlas.region = Rect2(628, 0, 626, 630)
		"gregorian": atlas.region = Rect2(0, 632, 370, 622)
		"space_segmented": atlas.region = Rect2(372, 632, 380, 622)
		"fast_radio": atlas.region = Rect2(754, 632, 500, 622)
		_: atlas.region = Rect2(0, 0, 626, 630)
	return atlas


func _draw_slot(part_type: String, rect: Rect2) -> void:
	var installed := _installed(part_type)
	var active := selected_type == part_type
	var color := GREEN if installed else (GOLD if active else Color(0.35, 0.66, 0.90))
	var slot := Panel.new()
	slot.position = rect.position
	slot.size = rect.size
	slot.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.13, 0.92), color, 2))
	blueprint.add_child(slot)
	var part := _part_for_type(part_type)
	var label := _label(GameManager.dict_text(part, "name") if installed else _short_type(part_type), Vector2(3, 3), rect.size - Vector2(6, 6), 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.pressed.connect(func() -> void: _install_at_slot(part_type))
	slot.add_child(hit)


func _install_at_slot(slot_type: String) -> void:
	if selected_type == "":
		status_label.text = GameManager.text("Select a reflector part first.", "请先选择一个反射镜零件。")
		return
	if selected_type != slot_type:
		status_label.text = GameManager.text("That part does not belong there. Newtonian optics must follow the reflected light path.", "该零件不属于这里。牛顿镜光学部件必须遵循反射光路。")
		return
	var index := order.find(slot_type)
	if index > 0 and not _installed(order[index - 1]):
		status_label.text = GameManager.text("Install " + _short_type(order[index - 1]) + " first.", "请先安装" + _short_type(order[index - 1]) + "。")
		return
	GameManager.install_part(slot_type, 0)
	selected_type = ""
	status_label.text = GameManager.text("Installed. The reflected light path is taking shape.", "已安装，反射光路正在成形。")
	_build()


func _finish() -> void:
	if not GameManager.telescope_is_ready():
		status_label.text = GameManager.text("Install every marked reflector component first.", "请先安装全部标记的反射镜组件。")
		return
	if bool(GameManager.current_level().get("requires_collimation", false)) and not GameManager.collimation_is_acceptable():
		if GameManager.try_story_mechanic("collimation", "collimation", "before_collimation"):
			return
		if GameManager.try_teaching_intercept("before_collimation", "collimation"):
			return
		GameManager.go("collimation")
		return
	GameManager.update_room_guidance_for_level()
	GameManager.set_observatory_spawn("assembly")
	GameManager.go("observatory")


func _part_for_type(part_type: String) -> Dictionary:
	# Advanced lessons prescribe exact components. Prefer that exact ID over a
	# previously equipped refractor part with the same broad type (eyepiece,
	# mount, and so on).
	for required_id_value in GameManager.current_level().get("required_part_ids", []):
		var required := GameManager.get_part(str(required_id_value))
		if str(required.get("type", "")) == part_type:
			if GameManager.equipped_part_id(part_type) != str(required.get("id", "")):
				GameManager.equip_part(str(required.get("id", "")))
			return required
	var equipped := GameManager.get_part(GameManager.equipped_part_id(part_type))
	if not equipped.is_empty():
		return equipped
	var options: Array = GameManager.unlocked_parts_by_type(part_type)
	if not options.is_empty():
		var selected: Dictionary = options[0]
		GameManager.equip_part(str(selected.get("id", "")))
		return selected
	return {"id": part_type, "name_en": part_type, "name_zh": part_type}


func _placeholder_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _installed(part_type: String) -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var entry: Dictionary = state.get(part_type, {})
	return bool(entry.get("installed", false))


func _status_text() -> String:
	var missing: Array = GameManager.missing_parts()
	return GameManager.text("Missing: ", "缺少：") + (", ".join(missing) if not missing.is_empty() else GameManager.text("All reflector parts installed.", "所有反射镜部件已安装。"))


func _short_type(part_type: String) -> String:
	return part_type.replace("_", " ").capitalize()


func _panel(pos: Vector2, size_value: Vector2, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 2))
	add_child(panel)
	panel.add_child(_label(title, Vector2(12, 8), Vector2(size_value.x - 24, 22), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	return panel


func _button(text_value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _style(color, GOLD, 2))
	button.add_theme_color_override("font_color", TEXT)
	return button


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


func _label_to(parent: Control, text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(text_value, pos, size_value, font_size, color, align)
	parent.add_child(label)
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


func _on_language_changed() -> void:
	_build()
