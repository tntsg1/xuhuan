extends Control

const W := 1024.0
const H := 768.0
const ROOM_RECT := Rect2(36, 118, 952, 570)
const PLAYER_SIZE := Vector2(30, 36)
const PLAYER_SPEED := 220.0
const INTERACT_DISTANCE := 56.0
const BG_TEXTURE := "res://assets/reference/observatory_room_clean_bg_1024.png"
const PLAYER_TEXTURE := "res://assets/sprout_lands/characters/basic_character.png"

const NOT_READY_TEXT := "The telescope is not ready yet. Go to the Assembly Table and install the core parts."
const READY_GUIDANCE_TEXT := "Telescope ready. Go to the Telescope Observation Pad or Observatory Door to begin sky observation."
const READY_FOCUS_TEXT := "Ready to observe. Press E at the telescope pad or observatory door."

const NAVY := Color(0.025, 0.040, 0.075, 0.92)
const NAVY_SOFT := Color(0.050, 0.075, 0.120, 0.82)
const WARM_TEXT := Color(0.96, 0.91, 0.78)
const BRASS := Color(0.90, 0.63, 0.28)
const CYAN := Color(0.52, 0.86, 1.00)

var player: TextureRect
var player_shadow: ColorRect
var level_value_label: Label
var credits_value_label: Label
var telescope_status_label: Label
var focus_label: Label
var feedback_label: Label
var interactables: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var nearby_id := ""
var player_pos := Vector2(506, 602)
var active_guidance := ""
var feedback_override := ""
var feedback_override_until_msec := 0
var interact_key_was_down := false
var mission_key_was_down := false


func _ready() -> void:
	if GameManager.last_guidance == "ready_to_observe":
		active_guidance = GameManager.last_guidance
		GameManager.last_guidance = ""
	player_pos = _spawn_position(GameManager.take_observatory_spawn())
	_build()
	set_process(true)


func _process(delta: float) -> void:
	_move_player(delta)
	_poll_action_keys()
	_update_nearby()
	_update_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or _event_action_pressed(event, "interact")):
			_interact_with_nearby()
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_TAB or _event_action_pressed(event, "view_missions")):
			_handle_interaction("mission")
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			GameManager.go("menu")
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_interact_at(mouse_event.position)


func _poll_action_keys() -> void:
	var interact_down := Input.is_key_pressed(KEY_E) or _action_pressed("interact")
	if interact_down and not interact_key_was_down:
		_interact_with_nearby()
	interact_key_was_down = interact_down

	var mission_down := Input.is_key_pressed(KEY_TAB) or _action_pressed("view_missions")
	if mission_down and not mission_key_was_down:
		_handle_interaction("mission")
	mission_key_was_down = mission_down


func _action_pressed(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func _event_action_pressed(event: InputEvent, action_name: String) -> bool:
	return InputMap.has_action(action_name) and event.is_action_pressed(action_name)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	interactables.clear()
	obstacles.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_draw_full_background()
	_register_hitboxes()
	_draw_player()
	_draw_hud()
	_set_player_position(player_pos)
	_update_nearby()
	_update_hud()


func _draw_full_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.position = Vector2.ZERO
	bg.size = Vector2(W, H)
	bg.ignore_texture_size = true
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _register_hitboxes() -> void:
	_register_interactable("cabinet", "Parts Cabinet", "Review unlocked telescope parts.", Rect2(70, 108, 235, 210))
	_register_interactable("door", "Observatory Door", "Enter the observatory control room.", Rect2(455, 70, 116, 214))
	_register_interactable("mission", "Mission Board", "Read the current level goal here.", Rect2(607, 96, 170, 150))
	_register_interactable("assembly", "Assembly Table", "Build and align the telescope.", Rect2(758, 188, 222, 205))
	_register_interactable("telescope", "Telescope Observation Pad", "Start observation here after assembly.", Rect2(378, 360, 280, 216))
	_register_interactable("journal", "Learning Journal", "Review completed observations and learning cards.", Rect2(70, 454, 272, 190))
	_register_interactable("computer", "Stats Terminal", "Check telescope performance and readiness.", Rect2(707, 474, 197, 152))

	# Foot blockers only: keep furniture edges walkable while preventing the player from standing inside bases.
	obstacles.append_array([
		Rect2(92, 302, 190, 22),
		Rect2(474, 260, 74, 18),
		Rect2(646, 232, 94, 16),
		Rect2(812, 366, 126, 26),
		Rect2(128, 618, 150, 22),
		Rect2(756, 610, 106, 22)
	])


func _register_interactable(id: String, display_name: String, hint: String, rect: Rect2) -> void:
	var frame_color := BRASS if _is_ready_observation_target(id) else CYAN
	var frame := _thin_highlight_frame(rect, frame_color)
	frame.modulate.a = 0.0
	interactables.append({
		"id": id,
		"name": display_name,
		"hint": hint,
		"rect": rect,
		"glow": frame
	})


func _draw_player() -> void:
	player_shadow = _rect(player_pos + Vector2(4, 30), Vector2(22, 7), Color(0.0, 0.0, 0.0, 0.36))
	player = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(PLAYER_TEXTURE)
	atlas.region = Rect2(17, 16, 14, 16)
	player.texture = atlas
	player.position = player_pos + Vector2(0, -6)
	player.size = Vector2(30, 34)
	player.ignore_texture_size = true
	player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.stretch_mode = TextureRect.STRETCH_SCALE
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)


func _draw_hud() -> void:
	var top := Panel.new()
	top.position = Vector2(58, 10)
	top.size = Vector2(834, 50)
	top.add_theme_stylebox_override("panel", _style(NAVY, BRASS, 2, 4))
	add_child(top)
	_corner_pins(top)

	level_value_label = _label_to(top, "", Vector2(38, 10), Vector2(150, 26), 18, HORIZONTAL_ALIGNMENT_LEFT)
	credits_value_label = _label_to(top, "", Vector2(350, 10), Vector2(150, 26), 18, HORIZONTAL_ALIGNMENT_LEFT)
	telescope_status_label = _label_to(top, "", Vector2(590, 11), Vector2(224, 24), 16, HORIZONTAL_ALIGNMENT_LEFT)

	var menu := Button.new()
	menu.text = "ESC Menu"
	menu.position = Vector2(900, 18)
	menu.size = Vector2(76, 32)
	menu.add_theme_font_size_override("font_size", 10)
	menu.add_theme_stylebox_override("normal", _style(Color(0.055, 0.075, 0.120, 0.94), BRASS, 1, 3))
	menu.add_theme_stylebox_override("hover", _style(Color(0.10, 0.15, 0.22, 0.98), Color(1.0, 0.82, 0.42), 1, 3))
	menu.add_theme_stylebox_override("pressed", _style(Color(0.03, 0.05, 0.09, 1.0), Color(1.0, 0.82, 0.42), 1, 3))
	menu.add_theme_color_override("font_color", WARM_TEXT)
	menu.pressed.connect(func() -> void: GameManager.go("menu"))
	add_child(menu)

	var bottom := Panel.new()
	bottom.position = Vector2(172, 704)
	bottom.size = Vector2(680, 48)
	bottom.add_theme_stylebox_override("panel", _style(NAVY, BRASS, 2, 4))
	add_child(bottom)
	_corner_pins(bottom)
	_label_to(bottom, "[E]", Vector2(40, 13), Vector2(38, 20), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, "INTERACT", Vector2(84, 14), Vector2(96, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(bottom, "WASD / ARROWS", Vector2(250, 14), Vector2(150, 18), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, "MOVE", Vector2(406, 14), Vector2(58, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(bottom, "[TAB]", Vector2(510, 13), Vector2(54, 20), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, "MISSIONS", Vector2(570, 14), Vector2(82, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)

	focus_label = _label("", Vector2(260, 662), Vector2(504, 20), 13, HORIZONTAL_ALIGNMENT_CENTER)
	feedback_label = _label("Start at the Mission Board, then use the Assembly Table.", Vector2(112, 680), Vector2(800, 20), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction == Vector2.ZERO:
		return

	var next_pos := player_pos + direction.normalized() * PLAYER_SPEED * delta
	next_pos.x = clampf(next_pos.x, ROOM_RECT.position.x + 16, ROOM_RECT.end.x - PLAYER_SIZE.x - 16)
	next_pos.y = clampf(next_pos.y, ROOM_RECT.position.y + 8, ROOM_RECT.end.y - PLAYER_SIZE.y - 8)
	var next_rect := Rect2(next_pos + Vector2(4, 10), PLAYER_SIZE - Vector2(8, 10))
	for obstacle in obstacles:
		if next_rect.intersects(obstacle):
			return
	_set_player_position(next_pos)


func _set_player_position(pos: Vector2) -> void:
	player_pos = pos
	if player_shadow != null:
		player_shadow.position = player_pos + Vector2(4, 30)
	if player != null:
		player.position = player_pos + Vector2(0, -6)


func _update_nearby() -> void:
	var best_id := ""
	var best_distance := 99999.0
	var center := player_pos + PLAYER_SIZE * 0.5
	for data in interactables:
		var rect: Rect2 = data["rect"]
		var nearest := Vector2(
			clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y)
		)
		var distance := center.distance_to(nearest)
		if distance < best_distance and distance <= INTERACT_DISTANCE:
			best_distance = distance
			best_id = str(data["id"])
	nearby_id = best_id

	for data in interactables:
		var frame := data.get("glow") as CanvasItem
		if frame == null:
			continue
		var id := str(data["id"])
		if id == nearby_id:
			frame.modulate.a = 0.82
		else:
			frame.modulate.a = 0.0


func _update_hud() -> void:
	var ready := GameManager.telescope_is_ready()
	level_value_label.text = "LEVEL %02d" % int(GameManager.progress.get("current_level", 1))
	credits_value_label.text = "CREDITS %d" % int(GameManager.progress.get("credits", 0))
	telescope_status_label.text = "TELESCOPE: READY" if ready else "TELESCOPE: NOT READY"
	telescope_status_label.add_theme_color_override("font_color", Color(0.48, 0.95, 0.36) if ready else Color(0.95, 0.72, 0.36))

	if nearby_id == "":
		focus_label.text = "Move around the observatory room"
		if _has_feedback_override():
			feedback_label.text = feedback_override
		elif active_guidance == "ready_to_observe":
			feedback_label.text = READY_GUIDANCE_TEXT
		elif ready:
			feedback_label.text = READY_FOCUS_TEXT
		else:
			feedback_label.text = "Check the Mission Board, then build the telescope at the Assembly Table."
		return

	var item := _get_interactable(nearby_id)
	focus_label.text = "[E] " + str(item.get("name", ""))
	if _has_feedback_override():
		feedback_label.text = feedback_override
	else:
		feedback_label.text = str(item.get("hint", ""))


func _interact_with_nearby() -> void:
	if nearby_id != "":
		_handle_interaction(nearby_id)


func _interact_at(pos: Vector2) -> void:
	for data in interactables:
		var rect: Rect2 = data["rect"]
		if rect.grow(12).has_point(pos):
			_handle_interaction(str(data["id"]))
			return


func _handle_interaction(id: String) -> void:
	if id == "mission":
		GameManager.set_observatory_spawn("mission")
		var level := GameManager.current_level()
		_show_feedback(str(level.get("title_en", "Current Mission")) + " - " + str(level.get("description_en", "Check the mission target.")))
	elif id == "cabinet":
		GameManager.set_observatory_spawn("cabinet")
		GameManager.go("parts")
	elif id == "assembly":
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("assembly")
	elif id == "door":
		GameManager.set_observatory_spawn("door")
		GameManager.go("interior")
	elif id == "telescope":
		if GameManager.telescope_is_ready():
			GameManager.set_observatory_spawn("telescope")
			GameManager.go("sky")
		else:
			_show_feedback(NOT_READY_TEXT, 3600)
	elif id == "journal":
		GameManager.set_observatory_spawn("journal")
		GameManager.go("journal")
	elif id == "computer":
		GameManager.set_observatory_spawn("computer")
		var stats := GameManager.calculate_stats()
		_show_feedback("Assembly %s | Clarity %s | Light %s | Stability %s" % [
			stats.get("assembly_score", 0),
			stats.get("clarity_score", 0),
			stats.get("light_score", 0),
			stats.get("stability_score", 0)
		], 3600)


func _show_feedback(text: String, duration_msec: int = 2800) -> void:
	feedback_override = text
	feedback_override_until_msec = Time.get_ticks_msec() + duration_msec
	if feedback_label != null:
		feedback_label.text = text


func _has_feedback_override() -> bool:
	if feedback_override == "":
		return false
	if Time.get_ticks_msec() <= feedback_override_until_msec:
		return true
	feedback_override = ""
	return false


func _spawn_position(spawn_id: String) -> Vector2:
	match spawn_id:
		"cabinet":
			return Vector2(300, 340)
		"assembly":
			return Vector2(730, 398)
		"door":
			return Vector2(506, 292)
		"telescope":
			return Vector2(506, 604)
		"journal":
			return Vector2(354, 606)
		"computer":
			return Vector2(682, 604)
		"mission":
			return Vector2(590, 274)
	return Vector2(506, 602)


func _is_ready_observation_target(id: String) -> bool:
	return GameManager.telescope_is_ready() and (id == "door" or id == "telescope")


func _get_interactable(id: String) -> Dictionary:
	for data in interactables:
		if str(data["id"]) == id:
			return data
	return {}


func _thin_highlight_frame(rect: Rect2, color: Color) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_frame_rect(frame, Vector2.ZERO, Vector2(rect.size.x, 2), color)
	_frame_rect(frame, Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2), color)
	_frame_rect(frame, Vector2.ZERO, Vector2(2, rect.size.y), color)
	_frame_rect(frame, Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y), color)
	return frame


func _frame_rect(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _corner_pins(parent: Control) -> void:
	var pin_color := Color(1.0, 0.78, 0.36, 0.95)
	_frame_rect(parent, Vector2(5, 5), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(5, 5), Vector2(2, 8), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 13, 5), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 7, 5), Vector2(2, 8), pin_color)
	_frame_rect(parent, Vector2(5, parent.size.y - 7), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(5, parent.size.y - 13), Vector2(2, 8), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 13, parent.size.y - 7), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 7, parent.size.y - 13), Vector2(2, 8), pin_color)


func _label(text: String, pos: Vector2, label_size: Vector2, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	add_child(label)
	_setup_label(label, text, font_size, align)
	return label


func _label_to(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	parent.add_child(label)
	_setup_label(label, text, font_size, align)
	return label


func _setup_label(label: Label, text: String, font_size: int, align: HorizontalAlignment) -> void:
	label.text = text
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WARM_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.76))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
