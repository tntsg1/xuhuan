extends Node

signal reduced_motion_changed(enabled: bool)
signal feedback_sfx_requested(event_name: String)

const CONFIG_PATH := "user://accessibility.cfg"
const GOLD := Color(1.0, 0.78, 0.32, 1.0)
const CYAN := Color(0.38, 0.84, 1.0, 1.0)
const GREEN := Color(0.42, 0.96, 0.58, 1.0)
const ERROR := Color(1.0, 0.42, 0.32, 1.0)

var reduced_motion := false
var _tutorial_seen: Dictionary = {}
var _bound_buttons: Array[Button] = []
var _disabled_refresh_elapsed := 0.0


func _ready() -> void:
	_load_settings()
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_buttons(get_tree().root)


func _process(delta: float) -> void:
	_disabled_refresh_elapsed += delta
	if _disabled_refresh_elapsed < 0.2:
		return
	_disabled_refresh_elapsed = 0.0
	var live_buttons: Array[Button] = []
	for button in _bound_buttons:
		if button != null and is_instance_valid(button):
			_apply_disabled_visual(button)
			live_buttons.append(button)
	_bound_buttons = live_buttons


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
	var seen_value: Variant = config.get_value("tutorials", "seen", {})
	if seen_value is Dictionary:
		_tutorial_seen = seen_value


func set_reduced_motion(enabled: bool) -> void:
	if reduced_motion == enabled:
		return
	reduced_motion = enabled
	_save_settings()
	reduced_motion_changed.emit(enabled)


func is_reduced_motion() -> bool:
	return reduced_motion


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("tutorials", "seen", _tutorial_seen)
	config.save(CONFIG_PATH)


func _on_node_added(node: Node) -> void:
	if node is Button:
		(node as Button).call_deferred("set_meta", "feedback_pending", true)
		call_deferred("bind_button", node)


func _bind_existing_buttons(node: Node) -> void:
	if node is Button:
		bind_button(node as Button)
	for child in node.get_children():
		_bind_existing_buttons(child)


func bind_button(button: Button) -> void:
	if button == null or not is_instance_valid(button) or bool(button.get_meta("feedback_bound", false)):
		return
	button.set_meta("feedback_bound", true)
	button.set_meta("feedback_pending", false)
	button.pivot_offset = button.size * 0.5
	var border := Panel.new()
	border.name = "InteractionFeedbackBorder"
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.modulate.a = 0.0
	border.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", style)
	button.add_child(border)
	_bound_buttons.append(button)
	button.mouse_entered.connect(_button_hover.bind(button, border, true))
	button.mouse_exited.connect(_button_hover.bind(button, border, false))
	button.button_down.connect(_button_down.bind(button, border))
	button.button_up.connect(_button_up.bind(button, border))
	button.pressed.connect(_button_complete.bind(button, border))
	_apply_disabled_visual(button)


func _apply_disabled_visual(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.modulate = Color(0.58, 0.60, 0.64, 0.62) if button.disabled else Color.WHITE


func _button_hover(button: Button, border: Panel, entering: bool) -> void:
	if button.disabled:
		_apply_disabled_visual(button)
		return
	var duration := 0.14 if not reduced_motion else 0.06
	_tween_property(button, "modulate", Color(1.08, 1.06, 1.0, 1.0) if entering else Color.WHITE, duration, "feedback_hover")
	_tween_property(border, "modulate:a", 0.58 if entering else 0.0, duration, "feedback_border")


func _button_down(button: Button, border: Panel) -> void:
	if button.disabled:
		return
	_tween_property(border, "modulate:a", 0.9, 0.08, "feedback_border")
	if reduced_motion:
		return
	_tween_property(button, "scale", Vector2.ONE * 0.97, 0.09, "feedback_press", Tween.TRANS_QUAD, Tween.EASE_OUT)


func _button_up(button: Button, border: Panel) -> void:
	if button.disabled:
		return
	_tween_property(button, "scale", Vector2.ONE, 0.10 if not reduced_motion else 0.04, "feedback_press", Tween.TRANS_BACK, Tween.EASE_OUT)
	_tween_property(border, "modulate:a", 0.58 if button.is_hovered() else 0.0, 0.12, "feedback_border")


func _button_complete(button: Button, border: Panel) -> void:
	if button.disabled:
		return
	flash_border(button, GOLD, 0.38, border)


func flash_border(control: Control, color: Color = GOLD, duration := 0.42, existing_border: Panel = null) -> void:
	if control == null or not is_instance_valid(control):
		return
	var border := existing_border
	if border == null:
		border = _feedback_border(control, color)
	var style := border.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = color
	border.modulate.a = 1.0
	var tween := _replace_tween(border, "feedback_flash")
	tween.tween_property(border, "modulate:a", 0.12, duration if not reduced_motion else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func success(control: Control, event_name := "success") -> void:
	if control == null or not is_instance_valid(control):
		return
	flash_border(control, GREEN, 0.48)
	if not reduced_motion:
		control.pivot_offset = control.size * 0.5
		var tween := _replace_tween(control, "feedback_success")
		tween.tween_property(control, "scale", Vector2.ONE * 1.035, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	feedback_sfx_requested.emit(event_name)


func error(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	flash_border(control, ERROR, 0.28)
	if reduced_motion:
		return
	var origin := control.position
	var tween := _replace_tween(control, "feedback_error")
	for offset in [-4.0, 4.0, -3.0, 3.0, 0.0]:
		tween.tween_property(control, "position:x", origin.x + offset, 0.045)


func pulse(control: Control, color := CYAN, duration := 0.5) -> void:
	if control == null or not is_instance_valid(control):
		return
	if reduced_motion:
		flash_border(control, color, 0.14)
		return
	var tween := _replace_tween(control, "feedback_pulse")
	var start := control.modulate
	tween.tween_property(control, "modulate", color, duration * 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", start, duration * 0.55).set_trans(Tween.TRANS_SINE)


func page_enter(control: Control, from_offset := Vector2(0, 10)) -> void:
	if control == null or not is_instance_valid(control):
		return
	var final_position := control.position
	control.modulate.a = 0.0
	if not reduced_motion:
		control.position = final_position + from_offset
	var tween := _replace_tween(control, "feedback_page")
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.20 if not reduced_motion else 0.08)
	if not reduced_motion:
		tween.tween_property(control, "position", final_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func fade_then(control: Control, callback: Callable) -> void:
	if control == null or not is_instance_valid(control):
		callback.call()
		return
	var tween := _replace_tween(control, "feedback_page_exit")
	tween.tween_property(control, "modulate:a", 0.0, 0.16 if not reduced_motion else 0.06)
	tween.tween_callback(callback)


func tween_rotation(control: Control, target: float, duration := 0.12) -> void:
	if control == null or not is_instance_valid(control):
		return
	_tween_property(control, "rotation", target, 0.04 if reduced_motion else duration, "feedback_rotation", Tween.TRANS_QUAD, Tween.EASE_OUT)


func tween_size(control: Control, target: Vector2, duration := 0.16) -> void:
	if control == null or not is_instance_valid(control):
		return
	_tween_property(control, "size", target, 0.05 if reduced_motion else duration, "feedback_size", Tween.TRANS_QUAD, Tween.EASE_OUT)


func fly_texture(texture: Texture2D, from_global: Rect2, to_global: Rect2, parent: Control) -> Tween:
	var icon := TextureRect.new()
	icon.name = "InstallingPartFeedback"
	icon.custom_minimum_size = Vector2.ZERO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 850
	parent.add_child(icon)
	var parent_origin := parent.get_global_rect().position
	icon.position = from_global.position - parent_origin
	icon.size = from_global.size
	icon.pivot_offset = icon.size * 0.5
	icon.modulate = Color(1.08, 1.04, 0.92, 0.94)
	var target_position := to_global.position - parent_origin
	var tween := create_tween().bind_node(icon)
	if reduced_motion:
		tween.set_parallel(true)
		tween.tween_property(icon, "position", target_position, 0.08)
		tween.tween_property(icon, "size", to_global.size, 0.08)
	else:
		tween.set_parallel(true)
		tween.tween_property(icon, "position", target_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "size", to_global.size, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "rotation", 0.025, 0.12).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(icon, "scale", Vector2.ONE * 1.04, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.08)
	tween.tween_property(icon, "modulate:a", 0.0, 0.06)
	tween.finished.connect(icon.queue_free)
	return tween


func tutorial_highlight_once(target: Control, key: String, text: String, parent: Control) -> Control:
	if target == null or parent == null or bool(_tutorial_seen.get(key, false)):
		return null
	_tutorial_seen[key] = true
	_save_settings()
	var overlay := Control.new()
	overlay.name = "TutorialHighlight_%s" % key
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 900
	parent.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.34)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var target_rect := target.get_global_rect()
	var local_origin := parent.get_global_rect().position
	var frame := Panel.new()
	frame.position = target_rect.position - local_origin - Vector2(8, 8)
	frame.size = target_rect.size + Vector2(16, 16)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", style)
	overlay.add_child(frame)
	var label := Label.new()
	label.text = text
	var parent_size := parent.size
	var label_size := Vector2(minf(340.0, parent_size.x - 60.0), 52.0)
	var label_x := frame.position.x + frame.size.x * 0.5 - label_size.x * 0.5
	if frame.position.x > parent_size.x * 0.58:
		label_x = frame.position.x - label_size.x - 18.0
	elif frame.position.x + frame.size.x < parent_size.x * 0.42:
		label_x = frame.position.x + frame.size.x + 18.0
	label_x = clampf(label_x, 30.0, parent_size.x - label_size.x - 30.0)
	var label_y := frame.position.y - label_size.y - 10.0
	if label_y < 24.0:
		label_y = frame.position.y + frame.size.y + 10.0
	label.position = Vector2(label_x, clampf(label_y, 24.0, parent_size.y - label_size.y - 24.0))
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	overlay.add_child(label)
	if not reduced_motion:
		var tween := _replace_tween(frame, "feedback_tutorial")
		tween.set_loops(3)
		tween.tween_property(frame, "modulate:a", 0.50, 0.38).set_trans(Tween.TRANS_SINE)
		tween.tween_property(frame, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 2.4 if not reduced_motion else 1.2
	timer.timeout.connect(overlay.queue_free)
	overlay.add_child(timer)
	timer.start()
	return overlay


func was_tutorial_seen(key: String) -> bool:
	return bool(_tutorial_seen.get(key, false))


func _feedback_border(control: Control, color: Color) -> Panel:
	var existing := control.get_node_or_null("InteractionFeedbackEffectBorder") as Panel
	if existing != null:
		return existing
	var border := Panel.new()
	border.name = "InteractionFeedbackEffectBorder"
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.z_index = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", style)
	control.add_child(border)
	return border


func _tween_property(control: Object, property: NodePath, value: Variant, duration: float, key: String, trans := Tween.TRANS_SINE, ease := Tween.EASE_IN_OUT) -> Tween:
	var tween := _replace_tween(control, key)
	tween.tween_property(control, property, value, duration).set_trans(trans).set_ease(ease)
	return tween


func _replace_tween(control: Object, key: String) -> Tween:
	var old: Variant = control.get_meta(key) if control.has_meta(key) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := create_tween()
	if control is Node:
		tween.bind_node(control as Node)
	control.set_meta(key, tween)
	return tween
