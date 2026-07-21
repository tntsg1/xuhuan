extends Control

# Reusable mobile control overlay: virtual joystick (bottom-left), boost,
# and a configurable action button column (bottom-right). Scenes add this
# only when TouchInput.is_mobile() and wire the buttons to the SAME handlers
# their keyboard shortcuts use. Draw-only + touch: never grabs PC mouse
# focus away from the scene beneath (buttons still work with mouse clicks,
# which is what makes headless/PC testing possible).

const BRASS := Color(0.72, 0.53, 0.26)
const NAVY := Color(0.045, 0.065, 0.11, 0.85)

var show_joystick := true
var joystick_center := Vector2(120, 640)
var joystick_radius := 62.0
var cap_offset := Vector2.ZERO
var joystick_touch_index := -1
var action_buttons: Dictionary = {}
var boost_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 150
	_apply_settings()
	TouchInput.settings_changed.connect(_apply_settings)
	set_process_input(true)


func _apply_settings() -> void:
	show_joystick = TouchInput.joystick_visible and TouchInput.is_mobile()
	joystick_radius = 62.0 * TouchInput.joystick_scale
	joystick_center = Vector2(58.0 + joystick_radius, 768.0 - 66.0 - joystick_radius)
	queue_redraw()


# ---- joystick -------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not show_joystick:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and joystick_touch_index < 0 and touch.position.distance_to(joystick_center) <= joystick_radius * 1.5:
			joystick_touch_index = touch.index
			_update_cap(touch.position)
		elif not touch.pressed and touch.index == joystick_touch_index:
			joystick_touch_index = -1
			cap_offset = Vector2.ZERO
			TouchInput.virtual_move = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == joystick_touch_index:
		_update_cap((event as InputEventScreenDrag).position)
	# Mouse fallback so the joystick is testable on PC / in headless runs.
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and joystick_touch_index < 0 and mouse.position.distance_to(joystick_center) <= joystick_radius * 1.5:
			joystick_touch_index = 999
			_update_cap(mouse.position)
		elif not mouse.pressed and joystick_touch_index == 999:
			joystick_touch_index = -1
			cap_offset = Vector2.ZERO
			TouchInput.virtual_move = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseMotion and joystick_touch_index == 999:
		_update_cap((event as InputEventMouseMotion).position)


func _update_cap(touch_position: Vector2) -> void:
	var raw := touch_position - joystick_center
	cap_offset = raw.limit_length(joystick_radius)
	var strength := cap_offset / joystick_radius
	# 8-direction snap keeps pixel movement crisp, matching WASD feel.
	if strength.length() > 0.25:
		var angle := snappedf(strength.angle(), PI / 4.0)
		TouchInput.virtual_move = Vector2(cos(angle), sin(angle)) * minf(strength.length(), 1.0)
	else:
		TouchInput.virtual_move = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not show_joystick:
		return
	draw_circle(joystick_center, joystick_radius + 4.0, Color(0.03, 0.045, 0.08, 0.62))
	draw_arc(joystick_center, joystick_radius + 4.0, 0.0, TAU, 40, BRASS, 3.0)
	draw_circle(joystick_center + cap_offset, joystick_radius * 0.42, Color(0.62, 0.46, 0.24, 0.92))
	draw_arc(joystick_center + cap_offset, joystick_radius * 0.42, 0.0, TAU, 28, Color(0.9, 0.74, 0.42), 2.0)


# ---- action buttons --------------------------------------------------------


func add_action_button(button_id: String, label_text: String, callback: Callable, slot: int = 0) -> Button:
	var button := Button.new()
	button.text = label_text
	var button_size := Vector2(168, 56)
	button.position = Vector2(1024.0 - button_size.x - 18.0, 768.0 - 78.0 - float(slot) * 66.0)
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = NAVY
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.10, 0.14, 0.20, 0.95)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover", style)
	var disabled_style := style.duplicate()
	disabled_style.bg_color = Color(0.05, 0.06, 0.09, 0.55)
	disabled_style.border_color = Color(0.38, 0.32, 0.22)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.pressed.connect(callback)
	add_child(button)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	action_buttons[button_id] = button
	return button


func set_action_enabled(button_id: String, enabled: bool, label_text: String = "") -> void:
	if not action_buttons.has(button_id):
		return
	var button := action_buttons[button_id] as Button
	button.disabled = not enabled
	if label_text != "":
		button.text = label_text


func add_hold_button(label_text: String, on_state: Callable, slot: int = 0) -> Button:
	# Hold-to-activate (boost / focus nudge): reports true while pressed.
	var button := add_action_button("hold_%d" % slot, label_text, func() -> void: pass, slot)
	button.button_down.connect(func() -> void: on_state.call(true))
	button.button_up.connect(func() -> void: on_state.call(false))
	return button
