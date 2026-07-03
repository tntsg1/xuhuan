extends Control

const W := 1024.0
const H := 768.0
const BG_TEXTURE := "res://assets/reference/sky_observation_ui_bg_1024.png"

const PANEL_COVER := Color(0.026, 0.048, 0.080, 1.0)
const TEXT := Color(0.96, 0.92, 0.82)
const GOLD := Color(0.96, 0.72, 0.30)
const GREEN := Color(0.42, 0.95, 0.50)
const MUTED := Color(0.72, 0.78, 0.84)
const WARNING := Color(1.0, 0.72, 0.35)

const TARGET_HITBOXES := {
	"moon": Rect2(75, 72, 116, 128),
	"polaris": Rect2(356, 100, 84, 92),
	"sirius": Rect2(108, 282, 92, 104),
	"betelgeuse": Rect2(312, 250, 98, 102),
	"mars": Rect2(548, 86, 94, 108),
	"jupiter": Rect2(520, 250, 148, 160),
	"orion_nebula": Rect2(218, 408, 156, 162),
	"andromeda": Rect2(465, 472, 174, 104),
}

const OBSERVE_RECT := Rect2(755, 538, 239, 80)
const BACK_RECT := Rect2(758, 652, 236, 72)

var selected_object_id := ""
var target_id := ""
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
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_draw_background()
	_cover_baked_text()
	_draw_dynamic_text()
	_draw_target_hitboxes()
	_draw_action_hitboxes()
	_update_selection_visual()


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


func _cover_baked_text() -> void:
	# The supplied image provides the frame and instruments; these small covers
	# replace only baked sample copy with current mission data.
	_rect(Vector2(744, 86), Vector2(246, 150), PANEL_COVER)
	_rect(Vector2(742, 292), Vector2(268, 206), PANEL_COVER)
	_rect(Vector2(748, 620), Vector2(246, 24), PANEL_COVER)


func _draw_dynamic_text() -> void:
	var level := GameManager.current_level()
	var target := GameManager.get_object(target_id)

	_label("Target:", Vector2(762, 112), Vector2(70, 24), 16, WARNING)
	_label(str(target.get("name_en", target_id)), Vector2(834, 112), Vector2(150, 24), 16, Color(0.84, 0.62, 1.0))

	_label("Hint:", Vector2(762, 154), Vector2(56, 24), 16, WARNING)
	var hint := _mission_hint(level, target)
	var hint_label := _label(hint, Vector2(762, 180), Vector2(220, 44), 12, TEXT)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	selected_title = _label("", Vector2(764, 322), Vector2(220, 24), 15, Color(0.84, 0.62, 1.0))
	selected_detail = _label("", Vector2(764, 356), Vector2(220, 92), 12, TEXT)
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


func _draw_target_hitboxes() -> void:
	for id in TARGET_HITBOXES.keys():
		var button := Button.new()
		var rect: Rect2 = TARGET_HITBOXES[id]
		button.position = rect.position
		button.size = rect.size
		button.text = ""
		button.tooltip_text = GameManager.dict_text(GameManager.get_object(id), "name")
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.pressed.connect(_select_object.bind(id))
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
		feedback_label.text = "Select a sky target before observing."
		return
	GameManager.selected_object_id = selected_object_id
	GameManager.go("telescope")


func _update_selected_text() -> void:
	if selected_object_id == "":
		selected_title.text = "No target"
		selected_detail.text = "Choose an object on the sky map."
		return
	var obj := GameManager.get_object(selected_object_id)
	selected_title.text = str(obj.get("name_en", selected_object_id))
	var type_text := str(obj.get("type_en", "Object"))
	var clue := str(obj.get("short_hint_en", ""))
	selected_detail.text = "Type: %s\n%s" % [type_text, clue]


func _update_selection_visual() -> void:
	if selection_frame != null:
		selection_frame.queue_free()
		selection_frame = null
	if finder_frame != null:
		finder_frame.queue_free()
		finder_frame = null

	if _finder_installed() and TARGET_HITBOXES.has(target_id):
		var finder_rect: Rect2 = TARGET_HITBOXES[target_id]
		finder_frame = _border_frame(finder_rect.grow(16), Color(0.45, 0.78, 1.0, 0.55), 2)

	if selected_object_id == "" or not TARGET_HITBOXES.has(selected_object_id):
		return
	var rect: Rect2 = TARGET_HITBOXES[selected_object_id]
	selection_frame = _border_frame(rect.grow(6), GOLD, 3)


func _finder_text() -> String:
	if _finder_installed():
		return "Finder Scope active"
	return "Finder Scope inactive"


func _finder_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var finder: Dictionary = state.get("finder_scope", {})
	return bool(finder.get("installed", false))


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
