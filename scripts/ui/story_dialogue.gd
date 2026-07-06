extends Control

# Astronomy Club dialogue scene. Plays StoryManager.active_lines one line
# at a time; Space / Enter / click advances. Pure presentation - all flow
# decisions live in StoryManager.

const BG := Color(0.012, 0.020, 0.045)
const PANEL_BG := Color(0.030, 0.045, 0.085, 0.97)
const BORDER := Color(0.78, 0.56, 0.28)
const NAME_COLOR := Color(0.98, 0.82, 0.50)
const TEXT_COLOR := Color(0.94, 0.94, 0.90)
const MUTED := Color(0.66, 0.74, 0.84)

const PORTRAITS := {
	"maya": "res://assets/characters/maya_portrait.png",
	"player": "res://assets/characters/player_portrait.png"
}

const TARGET_VISUALS := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_large.png",
	"andromeda": "res://assets/telescope_view/andromeda_large.png"
}

var line_index := 0
var speaker_label: Label
var text_label: Label
var counter_label: Label
var portrait_rect: TextureRect
var next_button: Button


func _ready() -> void:
	if StoryManager.active_lines.is_empty():
		GameManager.call_deferred("go", "observatory")
		return
	_build()
	_show_line()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_advance()
	elif event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_advance()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_draw_night_sky()

	# Astronomy Club plaque
	var plaque := Panel.new()
	plaque.position = Vector2(342, 60)
	plaque.size = Vector2(340, 64)
	plaque.add_theme_stylebox_override("panel", _style(Color(0.16, 0.11, 0.05, 0.96), BORDER, 3, 4))
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plaque)
	_label("ASTRONOMY CLUB", Vector2(342, 70), Vector2(340, 26), 20, NAME_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_label("天文俱乐部", Vector2(342, 96), Vector2(340, 22), 14, Color(0.88, 0.80, 0.62), HORIZONTAL_ALIGNMENT_CENTER)

	# dialogue panel
	var panel := Panel.new()
	panel.position = Vector2(72, 520)
	panel.size = Vector2(880, 190)
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, BORDER, 3, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	portrait_rect = TextureRect.new()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_rect.position = Vector2(96, 544)
	portrait_rect.size = Vector2(140, 140)
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_rect)

	speaker_label = _label("", Vector2(262, 540), Vector2(300, 28), 19, NAME_COLOR)
	text_label = _label("", Vector2(262, 574), Vector2(650, 100), 16, TEXT_COLOR)
	text_label.max_lines_visible = 4

	counter_label = _label("", Vector2(96, 686), Vector2(120, 20), 11, MUTED)

	next_button = Button.new()
	next_button.position = Vector2(812, 664)
	next_button.size = Vector2(120, 38)
	next_button.add_theme_font_size_override("font_size", 14)
	next_button.pressed.connect(_advance)
	add_child(next_button)

	var hint := _label(GameManager.text("Space / Enter / Click to continue", "空格 / 回车 / 点击继续"), Vector2(262, 682), Vector2(420, 24), 9, MUTED)
	hint.max_lines_visible = 2


func _draw_night_sky() -> void:
	# Generic starfield. A target visual is only shown for current-target
	# observation story events; equipment/assembly teaching stays generic.
	for i in range(90):
		var x := 14.0 + fmod(float(i * 89), 996.0)
		var y := 10.0 + fmod(float(i * 53), 480.0)
		var b := 0.45 + fmod(float(i), 5.0) * 0.10
		_rect(Vector2(x, y), Vector2(2, 2), Color(b, b, 0.95, 0.7))
	var visual_id := _story_visual_id()
	if visual_id == "":
		return
	var visual_path: String = TARGET_VISUALS.get(visual_id, "")
	if visual_path == "" or not ResourceLoader.exists(visual_path):
		return
	var moon := TextureRect.new()
	moon.texture = load(visual_path)
	moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moon.position = Vector2(790, 150)
	moon.size = Vector2(160, 160)
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moon.modulate = Color(1, 1, 1, 0.9)
	add_child(moon)


func _story_visual_id() -> String:
	var event_id := StoryManager.active_event_id
	if event_id.contains("assembly") or event_id.contains("focus") or event_id == "intro":
		return ""
	return GameManager.current_target_object_id()


func _show_line() -> void:
	var line: Dictionary = StoryManager.active_lines[line_index]
	var speaker := str(line.get("speaker", "Maya"))
	if speaker == "You":
		speaker_label.text = GameManager.text("You", "你")
	else:
		speaker_label.text = speaker
	text_label.text = GameManager.text(str(line.get("text_en", "")), str(line.get("text_zh", "")))
	counter_label.text = "%d / %d" % [line_index + 1, StoryManager.active_lines.size()]
	var portrait_path: String = PORTRAITS.get(str(line.get("portrait", "maya")), "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false
	if line_index >= StoryManager.active_lines.size() - 1:
		next_button.text = GameManager.text("Let's go!", "出发！").replace("\n", " · ")
	else:
		next_button.text = GameManager.text("Next", "继续").replace("\n", " · ")


func _advance() -> void:
	if StoryManager.active_lines.is_empty():
		return
	if line_index < StoryManager.active_lines.size() - 1:
		line_index += 1
		_show_line()
	else:
		StoryManager.finish_active_event()


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
