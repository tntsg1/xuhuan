extends Control

const W := 1024.0
const H := 768.0
const ROOM_RECT := Rect2(36, 118, 952, 570)
const PLAYER_SIZE := Vector2(18, 20)
const PLAYER_SPEED := 220.0
const INTERACT_DISTANCE := 56.0
const BG_TEXTURE := "res://assets/reference/observatory_room_clean_bg_1024.png"
const PLAYER_TEXTURE := "res://assets/characters/player_observer_4dir_clean.png"
const PLAYER_FRAME_SIZE := Vector2(96, 128)
# Uniform scale only — the old 44x62 display size squashed the 96x128 frame.
const PLAYER_DISPLAY_HEIGHT := 72.0
const PLAYER_DISPLAY_SCALE := PLAYER_DISPLAY_HEIGHT / PLAYER_FRAME_SIZE.y
const PLAYER_DISPLAY_SIZE := PLAYER_FRAME_SIZE * PLAYER_DISPLAY_SCALE
# Feet row inside the 128px frame (content ends ~y120, below is padding).
const PLAYER_FOOT_Y := 120.0
const PLAYER_ANIM_FPS := 8.0

const NAVY := Color(0.025, 0.040, 0.075, 0.92)
const NAVY_SOFT := Color(0.050, 0.075, 0.120, 0.82)
const WARM_TEXT := Color(0.96, 0.91, 0.78)
const BRASS := Color(0.90, 0.63, 0.28)
const CYAN := Color(0.52, 0.86, 1.00)

var player: Sprite2D
var player_atlas: AtlasTexture
var player_shadow: ColorRect
var mission_board_popup: Control
var stats_terminal_popup: Control
var unlock_popup: Control
var level_value_label: Label
var credits_value_label: Label
var telescope_status_label: Label
var guidance_overlay: Control
var guidance_panel: Panel
var guidance_title_label: Label
var guidance_hint_label: Label
var guidance_action_label: Label
var focus_label: Label
var feedback_label: Label
var interactables: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var nearby_id := ""
var player_pos := Vector2(517, 630)
var active_guidance := ""
var feedback_override := ""
var feedback_override_until_msec := 0
var interact_key_was_down := false
var mission_key_was_down := false
var player_facing := "down"
var player_anim_frame := 0
var player_anim_time := 0.0
var player_is_moving := false


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	if GameManager.last_guidance == "ready_to_observe":
		active_guidance = GameManager.last_guidance
		GameManager.last_guidance = ""
	elif GameManager.room_guidance_target != "":
		active_guidance = "room_guidance"
	player_pos = _spawn_position(GameManager.take_observatory_spawn())
	_build()
	set_process(true)
	call_deferred("_maybe_show_unlock_popup")


func _process(delta: float) -> void:
	if unlock_popup != null:
		_update_hud()
		return
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
	_register_interactable("cabinet", GameManager.text("Parts Cabinet", "零件柜"), GameManager.text("Review unlocked telescope parts.", "查看已解锁的望远镜零件。"), Rect2(82, 124, 214, 182))
	_register_interactable("door", GameManager.text("Observatory Door", "天文台门"), GameManager.text("Enter the observatory control room.", "进入天文台控制室。"), Rect2(468, 88, 88, 188))
	_register_interactable("mission", GameManager.text("Mission Board", "任务公告板"), GameManager.text("Read the current level goal here.", "在此查看当前关卡目标。"), Rect2(622, 108, 138, 124))
	_register_interactable("assembly", GameManager.text("Assembly Table", "组装台"), GameManager.text("Build and align the telescope.", "组装和校准望远镜。"), Rect2(782, 214, 170, 160))
	if GameManager.current_observation_mode() == "naked_eye":
		_register_interactable("telescope", GameManager.text("Naked Eye Observation", "肉眼观测"), GameManager.text("Observe the night sky with your own eyes.", "用肉眼观察夜空。"), Rect2(455, 398, 120, 124))
	else:
		_register_interactable("telescope", GameManager.text("Telescope Observation Pad", "望远镜观测台"), GameManager.text("Start observation here after assembly.", "组装完成后在此开始观测。"), Rect2(455, 398, 120, 124))
	_register_interactable("journal", GameManager.text("Learning Journal", "学习日志"), GameManager.text("Review completed observations and learning cards.", "查看已完成的观测和学习卡。"), Rect2(96, 476, 214, 132))
	_register_interactable("computer", GameManager.text("Stats Terminal", "统计终端"), GameManager.text("Check telescope performance and readiness.", "查看望远镜性能和就绪状态。"), Rect2(730, 492, 146, 116))

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
	var click_target := _transparent_click_target(rect, id)
	interactables.append({
		"id": id,
		"name": display_name,
		"hint": hint,
		"rect": rect,
		"glow": frame,
		"click_target": click_target
	})


func _draw_player() -> void:
	player_shadow = _rect(_player_shadow_position(), Vector2(26, 7), Color(0.0, 0.0, 0.0, 0.32))
	player = Sprite2D.new()
	player_atlas = AtlasTexture.new()
	player_atlas.atlas = load(PLAYER_TEXTURE)
	player.texture = player_atlas
	player.position = _player_visual_position()
	player.centered = true
	player.scale = Vector2.ONE * PLAYER_DISPLAY_SCALE
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(player)
	_set_player_animation_frame("down", 0)


func _draw_hud() -> void:
	var top := Panel.new()
	top.position = Vector2(58, 10)
	top.size = Vector2(834, 50)
	top.add_theme_stylebox_override("panel", _style(NAVY, BRASS, 2, 4))
	add_child(top)
	_corner_pins(top)

	level_value_label = _label_to(top, "", Vector2(38, 10), Vector2(150, 26), 18, HORIZONTAL_ALIGNMENT_LEFT)
	credits_value_label = _label_to(top, "", Vector2(330, 10), Vector2(220, 26), 18, HORIZONTAL_ALIGNMENT_LEFT)
	telescope_status_label = _label_to(top, "", Vector2(590, 11), Vector2(224, 24), 16, HORIZONTAL_ALIGNMENT_LEFT)

	var menu := Button.new()
	menu.text = GameManager.text("Menu", "菜单")
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
	_label_to(bottom, GameManager.text("INTERACT", "互动"), Vector2(84, 14), Vector2(96, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(bottom, GameManager.text("WASD / ARROWS", "WASD / 方向键"), Vector2(250, 14), Vector2(150, 18), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, GameManager.text("MOVE", "移动"), Vector2(406, 14), Vector2(58, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(bottom, "[TAB]", Vector2(510, 13), Vector2(54, 20), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, GameManager.text("MISSIONS", "任务"), Vector2(570, 14), Vector2(82, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)

	guidance_overlay = Control.new()
	guidance_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	guidance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(guidance_overlay)

	guidance_panel = Panel.new()
	guidance_panel.position = Vector2(222, 76)
	guidance_panel.size = Vector2(580, 126)
	guidance_panel.add_theme_stylebox_override("panel", _style(Color(0.030, 0.045, 0.080, 0.96), BRASS, 3, 6))
	add_child(guidance_panel)
	_corner_pins(guidance_panel)
	guidance_title_label = _label_to(guidance_panel, "", Vector2(24, 14), Vector2(532, 30), 22, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_hint_label = _label_to(guidance_panel, "", Vector2(32, 50), Vector2(516, 34), 17, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_action_label = _label_to(guidance_panel, "", Vector2(32, 88), Vector2(516, 22), 14, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_action_label.add_theme_color_override("font_color", Color(0.52, 0.86, 1.0))

	focus_label = _label("", Vector2(260, 662), Vector2(504, 20), 13, HORIZONTAL_ALIGNMENT_CENTER)
	feedback_label = _label(GameManager.text("Start at the Mission Board, then use the Assembly Table.", "先从任务公告板开始，然后去组装台。"), Vector2(112, 680), Vector2(800, 20), 13, HORIZONTAL_ALIGNMENT_CENTER)


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
		player_is_moving = false
		_update_player_animation(delta)
		return

	direction = direction.normalized()
	player_is_moving = true
	player_facing = _facing_from_direction(direction)
	_update_player_animation(delta)

	var next_pos := player_pos + direction * PLAYER_SPEED * delta
	next_pos.x = clampf(next_pos.x, ROOM_RECT.position.x + PLAYER_SIZE.x * 0.5, ROOM_RECT.end.x - PLAYER_SIZE.x * 0.5)
	next_pos.y = clampf(next_pos.y, ROOM_RECT.position.y + PLAYER_SIZE.y, ROOM_RECT.end.y)
	var next_rect := _player_collision_rect_for(next_pos)
	for obstacle in obstacles:
		if next_rect.intersects(obstacle):
			return
	_set_player_position(next_pos)


func _set_player_position(pos: Vector2) -> void:
	player_pos = pos
	if player_shadow != null:
		player_shadow.position = _player_shadow_position()
	if player != null:
		player.position = _player_visual_position()


func _player_visual_position() -> Vector2:
	# player_pos is the foot center; anchor the sprite so the drawn feet
	# (frame row PLAYER_FOOT_Y) land exactly on it.
	return player_pos - Vector2(0.0, (PLAYER_FOOT_Y - PLAYER_FRAME_SIZE.y * 0.5) * PLAYER_DISPLAY_SCALE)


func _player_shadow_position() -> Vector2:
	return player_pos - Vector2(13, 4)


func _player_collision_rect_for(pos: Vector2) -> Rect2:
	return Rect2(pos - Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y), PLAYER_SIZE)


func _facing_from_direction(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


func _update_player_animation(delta: float) -> void:
	if player_atlas == null:
		return
	if not player_is_moving:
		player_anim_frame = 0
		player_anim_time = 0.0
		_set_player_animation_frame(player_facing, player_anim_frame)
		return
	player_anim_time += delta
	var frame_duration := 1.0 / PLAYER_ANIM_FPS
	if player_anim_time >= frame_duration:
		player_anim_time = fmod(player_anim_time, frame_duration)
		player_anim_frame += 1
		if player_anim_frame > 3:
			player_anim_frame = 1
	if player_anim_frame == 0:
		player_anim_frame = 1
	_set_player_animation_frame(player_facing, player_anim_frame)


func _set_player_animation_frame(facing: String, frame: int) -> void:
	if player_atlas == null:
		return
	var row := 3
	match facing:
		"up":
			row = 3
		"left":
			row = 1
		"right":
			row = 2
		_:
			row = 0
	player_atlas.region = Rect2(
		float(frame) * PLAYER_FRAME_SIZE.x,
		float(row) * PLAYER_FRAME_SIZE.y,
		PLAYER_FRAME_SIZE.x,
		PLAYER_FRAME_SIZE.y
	)


func _update_nearby() -> void:
	var best_id := ""
	var best_distance := 99999.0
	var center := player_pos
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
		elif id == GameManager.room_guidance_target:
			frame.modulate.a = 0.72 + 0.18 * sin(float(Time.get_ticks_msec()) / 220.0)
		else:
			frame.modulate.a = 0.0


func _update_hud() -> void:
	var ready := GameManager.telescope_is_ready()
	level_value_label.text = GameManager.text("LEVEL %02d", "第 %02d 关") % int(GameManager.progress.get("current_level", 1))
	credits_value_label.text = GameManager.text("CLUB CREDITS %d", "社团积分 %d") % int(GameManager.progress.get("credits", 0))
	if GameManager.current_observation_mode() == "naked_eye":
		telescope_status_label.text = GameManager.text("MODE: NAKED EYE", "模式: 肉眼")
		telescope_status_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		telescope_status_label.text = GameManager.text("TELESCOPE: READY", "望远镜: 就绪") if ready else GameManager.text("TELESCOPE: NOT READY", "望远镜: 未就绪")
		telescope_status_label.add_theme_color_override("font_color", Color(0.48, 0.95, 0.36) if ready else Color(0.95, 0.72, 0.36))

	if nearby_id == "":
		focus_label.text = GameManager.text("Move around the observatory room", "在观测室里移动")
		if _has_feedback_override():
			feedback_label.text = feedback_override
		elif GameManager.room_guidance_target != "":
			feedback_label.text = GameManager.room_guidance_hint
		elif active_guidance == "ready_to_observe":
			feedback_label.text = GameManager.text(
				"Telescope ready. Go to the Telescope Observation Pad or Observatory Door to begin sky observation.",
				"望远镜已就绪。前往望远镜观测台或天文台门开始观星。"
			)
		elif ready:
			feedback_label.text = GameManager.text(
				"Ready to observe. Press E at the telescope pad or observatory door.",
				"可以观测了。在观测台或天文台门前按 E。"
			)
		else:
			feedback_label.text = GameManager.text("Check the Mission Board, then build the telescope at the Assembly Table.", "先查看任务公告板，然后去组装台制造望远镜。")
		_update_room_guidance_panel()
		return

	var item := _get_interactable(nearby_id)
	focus_label.text = "[E] " + str(item.get("name", ""))
	if _has_feedback_override():
		feedback_label.text = feedback_override
	else:
		feedback_label.text = str(item.get("hint", ""))
	_update_room_guidance_panel()


func _interact_with_nearby() -> void:
	if nearby_id != "":
		_handle_interaction(nearby_id)


func _interact_at(pos: Vector2) -> void:
	for data in interactables:
		var rect: Rect2 = data["rect"]
		if rect.grow(12).has_point(pos):
			_click_interactable(str(data["id"]))
			return


func _click_interactable(id: String) -> void:
	if nearby_id == id:
		_handle_interaction(id)
		return
	_show_feedback(GameManager.text("Move closer to interact.", "靠近后互动。"), 1800)


func _handle_interaction(id: String) -> void:
	if id == "mission":
		GameManager.set_observatory_spawn("mission")
		_toggle_mission_board()
	elif id == "cabinet":
		GameManager.set_observatory_spawn("cabinet")
		GameManager.clear_room_guidance()
		GameManager.go("parts")
	elif id == "assembly":
		GameManager.set_observatory_spawn("assembly")
		if GameManager.try_story_for_trigger("before_assembly", "assembly"):
			return
		if GameManager.try_teaching_intercept("before_assembly", "assembly"):
			return
		GameManager.clear_room_guidance()
		GameManager.go("assembly")
	elif id == "door":
		GameManager.set_observatory_spawn("door")
		if GameManager.current_observation_mode() == "naked_eye":
			if GameManager.try_story_for_trigger("before_observation", "sky"):
				return
			if GameManager.try_teaching_intercept("before_observation", "sky"):
				return
			GameManager.clear_room_guidance()
			GameManager.go("sky")
		else:
			GameManager.clear_room_guidance()
			GameManager.go("interior")
	elif id == "telescope":
		if GameManager.try_story_for_trigger("before_observation", "sky"):
			GameManager.set_observatory_spawn("telescope")
			return
		if GameManager.try_teaching_intercept("before_observation", "sky"):
			GameManager.set_observatory_spawn("telescope")
			return
		var gate: Dictionary = GameManager.can_enter_observation()
		if bool(gate.get("ok", false)):
			GameManager.set_observatory_spawn("telescope")
			GameManager.clear_room_guidance()
			GameManager.go("sky")
		else:
			_show_feedback(GameManager.text(
				str(gate.get("reason_en", "The telescope is not ready yet. Go to the Assembly Table and install the core parts.")),
				str(gate.get("reason_zh", "望远镜还没有准备好。请到组装台安装核心部件。"))
			), 3600)
	elif id == "journal":
		GameManager.set_observatory_spawn("journal")
		GameManager.clear_room_guidance()
		GameManager.go("journal")
	elif id == "computer":
		GameManager.set_observatory_spawn("computer")
		_toggle_stats_terminal()


func _toggle_mission_board() -> void:
	if mission_board_popup != null:
		mission_board_popup.queue_free()
		mission_board_popup = null
		return
	var level := GameManager.current_level()
	var note := GameManager.mission_board_note()
	var concept := GameManager.get_learning_card(GameManager.current_concept_card_id())
	var stage_names := {
		"eye": GameManager.text("Naked Eye", "肉眼"),
		"refractor_basic": GameManager.text("Basic Refractor", "基础折射镜"),
		"refractor_with_finder": GameManager.text("Refractor + Finder", "折射镜+寻星镜"),
		"newtonian_basic": GameManager.text("Newtonian Reflector", "牛顿反射镜"),
		"advanced": GameManager.text("Advanced Setup", "高级设备")
	}

	mission_board_popup = Control.new()
	mission_board_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mission_board_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(262, 148)
	panel.size = Vector2(500, 452)
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.050, 0.090, 0.98), BRASS, 3, 5))
	mission_board_popup.add_child(panel)

	_popup_label(GameManager.text("CLUB MISSION", "俱乐部任务"), Vector2(282, 164), Vector2(460, 22), 13, BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	var title_label := _popup_label(GameManager.dict_text(level, "title"), Vector2(282, 190), Vector2(460, 52), 20, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.max_lines_visible = 2

	_popup_label(GameManager.text("Maya's Note", "Maya 的提示"), Vector2(292, 252), Vector2(440, 18), 11, Color(0.66, 0.76, 0.86))
	var note_label := _popup_label(
		"\"" + GameManager.text(str(note.get("en", "")), str(note.get("zh", ""))) + "\"",
		Vector2(292, 272), Vector2(440, 58), 12, Color(0.98, 0.85, 0.58)
	)
	note_label.max_lines_visible = 3

	var objective_heading := GameManager.text("Objective", "目标")
	if not level.get("target_pool", []).is_empty():
		var picked := GameManager.current_target()
		objective_heading = GameManager.text("Objective -> ", "目标 -> ") + GameManager.dict_text(picked, "name")
	_popup_label(objective_heading, Vector2(292, 334), Vector2(440, 18), 11, Color(0.66, 0.76, 0.86))
	var objective_label := _popup_label(GameManager.dict_text(level, "description"), Vector2(292, 354), Vector2(440, 56), 12, WARM_TEXT)
	objective_label.max_lines_visible = 4

	_popup_label(GameManager.text("Equipment", "设备阶段"), Vector2(292, 416), Vector2(220, 18), 11, Color(0.66, 0.76, 0.86))
	_popup_label(str(stage_names.get(GameManager.current_equipment_stage(), GameManager.current_equipment_stage())), Vector2(292, 436), Vector2(220, 40), 12, CYAN)

	_popup_label(GameManager.text("Concept", "学习概念"), Vector2(522, 416), Vector2(210, 18), 11, Color(0.66, 0.76, 0.86))
	var concept_label := _popup_label(GameManager.dict_text(concept, "title") if not concept.is_empty() else "-", Vector2(522, 436), Vector2(210, 60), 12, Color(0.86, 0.72, 1.0))
	concept_label.max_lines_visible = 3

	var close := Button.new()
	close.text = GameManager.text("Close", "关闭")
	close.position = Vector2(432, 546)
	close.size = Vector2(160, 40)
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(_toggle_mission_board)
	mission_board_popup.add_child(close)


func _popup_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_board_popup.add_child(label)
	return label


func _maybe_show_unlock_popup() -> void:
	# Announce newly unlocked equipment with an unmissable Maya popup, so
	# upgrades never arrive silently.
	var pending: Array = GameManager.take_pending_unlock_notice()
	if pending.is_empty():
		return

	unlock_popup = Control.new()
	unlock_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(unlock_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.60)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	unlock_popup.add_child(dim)

	var line_count := mini(pending.size(), 4)
	var panel_height := 250.0 + float(line_count) * 26.0
	var panel := Panel.new()
	panel.position = Vector2(252, 384.0 - panel_height * 0.5)
	panel.size = Vector2(520, panel_height)
	panel.add_theme_stylebox_override("panel", _style(Color(0.040, 0.055, 0.100, 0.98), Color(0.98, 0.80, 0.36), 3, 6))
	unlock_popup.add_child(panel)

	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/characters/maya_portrait.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = panel.position + Vector2(24, 40)
	portrait.size = Vector2(96, 96)
	unlock_popup.add_child(portrait)

	var x_text := panel.position.x + 140.0
	var y := panel.position.y + 18.0
	_popup_label_on(unlock_popup, GameManager.text("NEW EQUIPMENT UNLOCKED!", "新装备已解锁！"), Vector2(panel.position.x + 20, y), Vector2(480, 24), 15, Color(0.98, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	y += 34.0
	var maya_line := _popup_label_on(unlock_popup,
		GameManager.text("Maya: \"New parts just arrived for the club!\"", "Maya：“俱乐部的新零件到货啦！”"),
		Vector2(x_text, y), Vector2(360, 40), 12, WARM_TEXT)
	maya_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 44.0
	for index in range(line_count):
		var part: Dictionary = GameManager.get_part(str(pending[index]))
		var part_name := GameManager.dict_text(part, "name")
		_popup_label_on(unlock_popup, "•  " + part_name, Vector2(x_text, y), Vector2(360, 22), 13, Color(0.60, 0.95, 0.70))
		y += 26.0
	y += 10.0
	var hint := _popup_label_on(unlock_popup,
		GameManager.text("Equip them at the Parts Cabinet, then reassemble at the Assembly Table.", "到零件柜装备它们，然后在组装台重新组装。"),
		Vector2(x_text, y), Vector2(360, 40), 11, Color(0.78, 0.86, 0.92))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var ok := Button.new()
	ok.text = GameManager.text("Got it!", "知道了！").replace("\n", " · ")
	ok.position = Vector2(432, panel.position.y + panel_height - 52.0)
	ok.size = Vector2(160, 38)
	ok.add_theme_font_size_override("font_size", 14)
	ok.pressed.connect(func() -> void:
		if unlock_popup != null:
			unlock_popup.queue_free()
			unlock_popup = null
	)
	unlock_popup.add_child(ok)


func _popup_label_on(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _toggle_stats_terminal() -> void:
	# Stats Terminal popup: telescope performance + what Club Credits are for.
	if stats_terminal_popup != null:
		stats_terminal_popup.queue_free()
		stats_terminal_popup = null
		return
	var stats := GameManager.calculate_stats()

	stats_terminal_popup = Control.new()
	stats_terminal_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stats_terminal_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(272, 168)
	panel.size = Vector2(480, 412)
	panel.add_theme_stylebox_override("panel", _style(Color(0.030, 0.055, 0.060, 0.98), Color(0.35, 0.85, 0.55), 3, 5))
	stats_terminal_popup.add_child(panel)

	_terminal_label(GameManager.text("STATS TERMINAL", "统计终端"), Vector2(292, 184), Vector2(440, 22), 13, Color(0.45, 0.95, 0.60), HORIZONTAL_ALIGNMENT_CENTER)

	var rows: Array = [
		[GameManager.text("Assembly", "组装"), float(stats.get("assembly_score", 0.0))],
		[GameManager.text("Light", "集光"), float(stats.get("light_score", 0.0))],
		[GameManager.text("Clarity", "清晰"), float(stats.get("clarity_score", 0.0))],
		[GameManager.text("Stability", "稳定"), float(stats.get("stability_score", 0.0))],
		[GameManager.text("Focus Ctrl", "调焦"), float(stats.get("focus_control_score", 0.0))]
	]
	var y := 220.0
	for row_value in rows:
		var row: Array = row_value
		var value: float = float(row[1])
		_terminal_label(str(row[0]), Vector2(300, y), Vector2(160, 18), 12, WARM_TEXT)
		var bar_bg := ColorRect.new()
		bar_bg.position = Vector2(470, y + 4)
		bar_bg.size = Vector2(180, 10)
		bar_bg.color = Color(0.06, 0.10, 0.10)
		stats_terminal_popup.add_child(bar_bg)
		var fill := ColorRect.new()
		fill.position = Vector2(470, y + 4)
		fill.size = Vector2(clampf(value, 0.0, 100.0) * 1.8, 10)
		fill.color = Color(0.40, 0.85, 0.55)
		stats_terminal_popup.add_child(fill)
		_terminal_label(str(snapped(value, 0.1)), Vector2(660, y), Vector2(60, 18), 12, Color(0.80, 0.95, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
		y += 28.0

	var divider := ColorRect.new()
	divider.position = Vector2(292, y + 8)
	divider.size = Vector2(440, 1)
	divider.color = Color(0.35, 0.85, 0.55, 0.4)
	stats_terminal_popup.add_child(divider)

	_terminal_label(GameManager.text("CLUB CREDITS: %d", "社团积分: %d") % int(GameManager.progress.get("credits", 0)), Vector2(292, y + 20), Vector2(440, 24), 16, Color(0.98, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	var note := _terminal_label(
		GameManager.text("Club Credits are saved for future equipment upgrades.", "社团积分将用于后续设备升级。"),
		Vector2(300, y + 50), Vector2(424, 40), 11, Color(0.78, 0.88, 0.82), HORIZONTAL_ALIGNMENT_CENTER
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var shop := Button.new()
	shop.text = GameManager.text("Upgrade Shop - Coming Soon", "升级商店 - 即将开放")
	shop.disabled = true
	shop.position = Vector2(312, y + 96)
	shop.size = Vector2(400, 34)
	shop.add_theme_font_size_override("font_size", 12)
	stats_terminal_popup.add_child(shop)

	var close := Button.new()
	close.text = GameManager.text("Close", "关闭").replace("\n", " · ")
	close.position = Vector2(432, y + 140)
	close.size = Vector2(160, 36)
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(_toggle_stats_terminal)
	stats_terminal_popup.add_child(close)


func _terminal_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_terminal_popup.add_child(label)
	return label


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


func _update_room_guidance_panel() -> void:
	if guidance_panel == null:
		return
	if GameManager.room_guidance_target == "":
		guidance_panel.visible = false
		_update_guidance_overlay({})
		return
	guidance_panel.visible = true
	guidance_title_label.text = GameManager.room_guidance_title
	var target_name := ""
	var item := _get_interactable(GameManager.room_guidance_target)
	if not item.is_empty():
		target_name = str(item.get("name", ""))
	if nearby_id == GameManager.room_guidance_target:
		guidance_hint_label.text = "[E] " + target_name
		guidance_action_label.text = GameManager.text("Press E to continue", "按 E 继续")
	else:
		guidance_hint_label.text = GameManager.room_guidance_hint
		guidance_action_label.text = GameManager.text("Follow the highlighted area", "跟随高亮区域")
	_update_guidance_overlay(item)


func _update_guidance_overlay(item: Dictionary) -> void:
	if guidance_overlay == null:
		return
	_clear(guidance_overlay)
	if item.is_empty():
		guidance_overlay.visible = false
		return
	guidance_overlay.visible = true
	var rect: Rect2 = item.get("rect", Rect2()).grow(24.0)
	rect.position.x = clampf(rect.position.x, 0.0, W)
	rect.position.y = clampf(rect.position.y, 0.0, H)
	rect.size.x = clampf(rect.size.x, 0.0, W - rect.position.x)
	rect.size.y = clampf(rect.size.y, 0.0, H - rect.position.y)
	var shade := Color(0.0, 0.0, 0.0, 0.50)
	_rect_to(guidance_overlay, Vector2.ZERO, Vector2(W, rect.position.y), shade)
	_rect_to(guidance_overlay, Vector2(0, rect.end.y), Vector2(W, H - rect.end.y), shade)
	_rect_to(guidance_overlay, Vector2(0, rect.position.y), Vector2(rect.position.x, rect.size.y), shade)
	_rect_to(guidance_overlay, Vector2(rect.end.x, rect.position.y), Vector2(W - rect.end.x, rect.size.y), shade)

	var pulse := 0.70 + 0.25 * sin(float(Time.get_ticks_msec()) / 180.0)
	var outer := _thin_highlight_frame_to(guidance_overlay, rect.grow(8.0), Color(1.0, 0.78, 0.26, pulse))
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := _thin_highlight_frame_to(guidance_overlay, rect.grow(2.0), Color(1.0, 0.95, 0.58, 0.92))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_guidance_arrow(guidance_overlay, rect)


func _draw_guidance_arrow(parent: Control, target_rect: Rect2) -> void:
	var label := Label.new()
	label.text = ">>>"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32, 0.92))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var from := player_pos
	var to := target_rect.get_center()
	var mid := from.lerp(to, 0.55)
	label.position = mid - Vector2(32, 18)
	label.size = Vector2(64, 36)
	var direction := to - from
	label.rotation = atan2(direction.y, direction.x)
	parent.add_child(label)


func _spawn_position(spawn_id: String) -> Vector2:
	match spawn_id:
		"cabinet":
			return Vector2(300, 350)
		"assembly":
			return Vector2(756, 410)
		"door":
			return Vector2(517, 320)
		"telescope":
			return Vector2(517, 570)
		"journal":
			return Vector2(350, 628)
		"computer":
			return Vector2(693, 632)
		"mission":
			return Vector2(610, 250)
	return Vector2(517, 630)


func _is_ready_observation_target(id: String) -> bool:
	return bool(GameManager.can_enter_observation().get("ok", false)) and (id == "door" or id == "telescope")


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


func _thin_highlight_frame_to(parent: Control, rect: Rect2, color: Color) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_frame_rect(frame, Vector2.ZERO, Vector2(rect.size.x, 3), color)
	_frame_rect(frame, Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3), color)
	_frame_rect(frame, Vector2.ZERO, Vector2(3, rect.size.y), color)
	_frame_rect(frame, Vector2(rect.size.x - 3, 0), Vector2(3, rect.size.y), color)
	return frame


func _transparent_click_target(rect: Rect2, id: String) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.pressed.connect(_click_interactable.bind(id))
	add_child(button)
	return button


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


func _rect_to(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


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

func _on_language_changed() -> void:
	_build()
