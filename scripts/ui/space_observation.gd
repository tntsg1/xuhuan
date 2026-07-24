extends Control

const SpaceDeploymentVisualScript := preload("res://scripts/ui/space_deployment_visual.gd")
const SpaceGuideFieldScript := preload("res://scripts/ui/space_guide_field.gd")
const SpaceWavefrontDisplayScript := preload("res://scripts/ui/space_wavefront_display.gd")

# JWST-class space infrared observation. A staged science pipeline that works in
# photons, filters, attitude, temperature and data frames. It keeps its own
# space_observation state and deliberately borrows none of the ground-optic
# mechanics (no light-bucket viewer, no manual sharpening knob, no alignment
# spider game, no aiming scope).
#
# Stages: Deploy (first-time) -> Plan -> Thermal -> Guide -> Wavefront ->
#         Expose -> Process -> Filter -> Report.

# --- monochrome phosphor palette (no hue: intensity only) ---
const BG := Color("050505")          # tube black
const PANEL := Color("0b0b0b")       # panel well
const P_HOT := Color("ffffff")       # focused / active
const P_BRIGHT := Color("dcdcdc")    # primary text, headings
const P_MID := Color("9a9a9a")       # secondary text, idle borders
const P_DIM := Color("5a5a5a")       # disabled, grid, hints
const P_FAINT := Color("2e2e2e")     # separators
# legacy names kept so every stage re-themes at once
const GOLD := P_HOT
const GOLD_HI := Color("ffffff")
const CYAN := P_MID
const GREEN := P_BRIGHT
const RED := P_HOT
const ORANGE := P_BRIGHT
const TEXT := P_BRIGHT
const MUTED := P_DIM

var model: SpaceObservationModel
var stages: Array = []
var stage := 0
var running := false
var status_label: Label
var content: Control
var readout: Label
var scope: Control
var elapsed := 0.0
var acquiring := false
var deploy_animating := false
var deployment_visual: Control
var attitude_tween: Tween
var guide_candidate := -1
var guide_field: Control
var guide_lock_logged := false
var wavefront_animating := false
var wavefront_display: Control
var process_animating := false
var filter_animating := false


func _ready() -> void:
	model = SpaceObservationModel.new()
	model.configure(_profile())
	stages = _stage_list()
	GameManager.language_changed.connect(_rebuild)
	set_process(true)
	_rebuild()
	_boot_animation()


# ---- power-on / power-off tube animation --------------------------------
func _boot_animation() -> void:
	# A CRT does not just appear; it warms up. A bright horizontal scan line
	# sweeps down the black tube, then the picture snaps in.
	var cover := ColorRect.new()
	cover.name = "BootCover"
	cover.color = Color(0, 0, 0, 1)
	cover.position = Vector2.ZERO
	cover.size = Vector2(1024, 768)
	cover.z_index = 380
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var scan := ColorRect.new()
	scan.color = Color(1, 1, 1, 0.9)
	scan.size = Vector2(1024, 3)
	scan.position = Vector2(0, 383)
	scan.z_index = 381
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)
	_log_line("BOOT SEQUENCE", "RUN")
	# Bind to the cover itself. Stage rebuilds may remove the boot overlay while
	# the terminal scene remains alive; in that case the tween and its captures
	# must stop together instead of calling back with freed cover/scan nodes.
	var tw := create_tween().bind_node(cover)
	tw.tween_property(scan, "position:y", 0.0, 0.10)
	tw.parallel().tween_property(scan, "size:y", 768.0, 0.16)
	tw.parallel().tween_property(cover, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(scan, "modulate:a", 0.0, 0.20)
	tw.tween_callback(func() -> void:
		if is_instance_valid(cover): cover.queue_free()
		if is_instance_valid(scan): scan.queue_free()
		_log_line("DISPLAY", "READY"))


func _power_down(then: Callable) -> void:
	# Collapse the picture to a thin white line, then to a dot - a tube switching
	# off - before we actually change scene.
	_log_line("SESSION CLOSE", "SAVE")
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.size = Vector2(1024, 768)
	cover.z_index = 390
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 1)
	line.size = Vector2(1024, 384)
	line.position = Vector2(0, 192)
	line.pivot_offset = Vector2(512, 192)
	line.z_index = 391
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var tw := create_tween().bind_node(cover)
	tw.tween_property(cover, "color:a", 1.0, 0.12)
	tw.parallel().tween_property(line, "size:y", 2.0, 0.12)
	tw.parallel().tween_property(line, "position:y", 383.0, 0.12)
	tw.tween_property(line, "size:x", 4.0, 0.08)
	tw.parallel().tween_property(line, "position:x", 510.0, 0.08)
	tw.tween_property(line, "modulate:a", 0.0, 0.06)
	tw.tween_callback(then)


func _leave_observatory() -> void:
	_power_down(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory"))


func _profile() -> Dictionary:
	var level := GameManager.current_level()
	var prof: Dictionary = level.get("space_profile", {})
	if prof.is_empty():
		prof = {"target_id": GameManager.current_target_object_id()}
	return prof


# The five JWST teaching cards, shown as a first-time Maya briefing before the
# very first deployment. Content is pulled from data/learning_cards.json so the
# cards stay the single source of truth.
const INTRO_CARDS := ["jwst_infrared_light", "jwst_segmented_mirror", "jwst_sunshield_l2", "jwst_instruments", "jwst_false_colour"]

var intro_page := 0
var intro_why := false
var console_log: Array = []
var console_label: Label
var console_reveal := 1.0
var mission_clock := 0.0
var furthest_stage := 0
const CONSOLE_ROWS := 4
const CRT_SHADER := "res://shaders/crt_monitor.gdshader"


func _stage_list() -> Array:
	# First-ever entry: a Maya teaching briefing, then deployment. Both are
	# first-time only; later visits skip straight to planning.
	var out: Array = []
	if not bool(GameManager.progress.get("space_intro_seen", false)):
		out.append("intro")
	if not bool(GameManager.progress.get("space_deployed", false)):
		out.append("deploy")
	for s in ["plan", "thermal", "guide", "wavefront", "expose", "process", "filter", "report"]:
		out.append(s)
	return out


func _key() -> String:
	return str(stages[stage])


func _process(delta: float) -> void:
	if model == null:
		return
	mission_clock += delta
	if console_reveal < 1.0:
		console_reveal = minf(1.0, console_reveal + delta * 2.6)
		_render_console()
	if _key() == "guide" and model.chosen_guide >= 0 and not model.guide_locked:
		model.step_guiding(delta)
		_refresh_guide()
		if model.guide_locked and not guide_lock_logged:
			guide_lock_logged = true
			_log_line("FGS CLOSED LOOP", "LOCKED", "%.2f ARCSEC" % model.pointing_error)
			_say(GameManager.text(
				"Guide lock acquired. The bite marks have closed and drift is flat.",
				"导星锁定完成。锁定标记已经咬合，漂移曲线已拉平。"), GREEN)
			InteractionFeedback.success(self)
	if _key() == "expose" and acquiring:
		elapsed += delta
		_refresh_expose()


# ------------------------------------------------------------ shell
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_label(GameManager.text("SPACE INFRARED OBSERVATORY", "太空红外天文台"), Vector2(24, 14), Vector2(976, 28), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Target: ", "目标：") + GameManager.dict_text(GameManager.current_target(), "name")
		+ "   ·   " + GameManager.text("A space science observation, not a point-and-look image.", "这是一次空间科学观测，不是对准就看的简单成像。"),
		Vector2(24, 44), Vector2(976, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_build_stage_bar()
	content = Control.new()
	content.position = Vector2(0, 110)
	content.size = Vector2(1024, 566)
	add_child(content)
	# telemetry console strip (system-emitted, never typed by the player)
	var console_bg := Panel.new()
	console_bg.position = Vector2(36, 620)
	console_bg.size = Vector2(952, 56)
	console_bg.add_theme_stylebox_override("panel", _flat(Color("040a10"), Color("1d3550"), 1))
	console_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(console_bg)
	console_label = _label_to(console_bg, "", Vector2(12, 3), Vector2(928, 50), 10, GREEN)
	console_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if console_log.is_empty():
		_log_line("SPACECRAFT BUS LINK", "ONLINE")
		_log_line("CRYO SUBSYSTEM", "NOMINAL")
	console_label.text = "> " + "\n> ".join(console_log)

	status_label = _label("", Vector2(36, 686), Vector2(760, 44), 13, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(GameManager.text("Back", "返回"), Vector2(820, 690), Vector2(170, 40), Color("15233a"))
	back.pressed.connect(_leave_observatory)
	add_child(back)
	_build_stage()
	# Each stage opens with a "what to look at" teaching tip until the player acts.
	if status_label.text == "":
		_say(_stage_tip(), CYAN)
	_add_crt_overlay()


func _stage_tip() -> String:
	match _key():
		"intro": return GameManager.text("First-time briefing. Read each page.", "首次教学，逐页阅读。")
		"deploy": return GameManager.text("Watch the order: solar array, then sunshield, mirrors, hinges, actuators. Wrong order is blocked and explained.", "注意顺序：太阳能板→遮阳罩→镜面→铰链→执行器。乱序会被拦截并说明原因。")
		"plan": return GameManager.text("Pick the instrument and filter that fit THIS target. Each shows what it's good and bad for.", "为当前目标选择合适的仪器和滤镜。每个选项都会说明擅长与不擅长的方面。")
		"thermal": return GameManager.text("The sunshield side must face the Sun. Keep the sun 85-135 deg off boresight so the optics stay cold.", "遮阳罩一侧必须朝向太阳。让太阳保持在视轴 85-135 度，使光学保持低温。")
		"guide": return GameManager.text("A guide star is a steady reference star, not the target. Avoid dim or off-field stars.", "导星是一颗稳定的参考星，不是观测目标本身。避开太暗或偏离视场的星。")
		"wavefront": return GameManager.text("Nudge the 18 segments until the split star images merge into one small, sharp point.", "微调 18 块镜片，直到分裂的星点合并成一个又小又锐的点。")
		"expose": return GameManager.text("Photons build up frame by frame. Too short = weak signal; too long = heat noise and cosmic rays.", "光子逐帧累积。太短信号弱；太长热噪声和宇宙线增多。")
		"process": return GameManager.text("Drop cosmic-ray frames, then align, remove CR, subtract background and stack. Watch the image clean up.", "剔除宇宙线帧，再对齐、去宇宙线、扣背景、叠加。观察图像逐步变干净。")
		"filter": return GameManager.text("Map each filter to R/G/B, then read the structure to choose the science interpretation.", "把每个滤镜映射到 R/G/B，再根据结构选择科学解释。")
		"report": return GameManager.text("Review the real numbers, then Submit Report to finish the observation.", "查看真实数据，再点击提交报告完成观测。")
	return ""


func _build_stage_bar() -> void:
	var titles := {
		"intro": GameManager.text("Learn", "教学"),
		"deploy": GameManager.text("Deploy", "部署"), "plan": GameManager.text("Plan", "规划"),
		"thermal": GameManager.text("Thermal", "热控"), "guide": GameManager.text("Guide", "导星"),
		"wavefront": GameManager.text("Align", "对准"), "expose": GameManager.text("Expose", "曝光"),
		"process": GameManager.text("Process", "处理"), "filter": GameManager.text("Filter", "滤镜"),
		"report": GameManager.text("Report", "报告")}
	var holder := Control.new()
	holder.position = Vector2(24, 74)
	add_child(holder)
	var w := 976.0 / float(stages.size())
	for i in range(stages.size()):
		var done := i < stage
		var active := i == stage
		var reachable := i <= furthest_stage
		# Any stage you have already reached can be re-opened to review - the
		# console is a machine you can walk back through, not a one-way corridor.
		var chip := Button.new()
		chip.position = Vector2(i * w, 0)
		chip.size = Vector2(w - 6, 26)
		chip.focus_mode = Control.FOCUS_NONE
		chip.text = str(titles[stages[i]])
		chip.add_theme_font_size_override("font_size", 12)
		var border: Color = GREEN if done else (GOLD if active else Color("2a3f5a"))
		var fill: Color = Color("1c3350") if active else (Color("0e1e16") if done else Color("13233a"))
		chip.add_theme_stylebox_override("normal", _flat(fill, border, 3 if active else 2))
		chip.add_theme_stylebox_override("hover", _flat(fill.lightened(0.10), GOLD_HI if reachable else border, 3 if active else 2))
		chip.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.10), CYAN, 3))
		chip.add_theme_color_override("font_color", GREEN if done else (GOLD if active else MUTED))
		if reachable and not active:
			chip.pressed.connect(_goto_stage.bind(i))
		else:
			chip.disabled = not reachable
			chip.add_theme_stylebox_override("disabled", _flat(fill, border, 2))
			chip.add_theme_color_override("font_disabled_color", MUTED)
		holder.add_child(chip)


func _goto_stage(index: int) -> void:
	# Re-open an already reached stage. Reviewing never rewinds progress: the
	# furthest point stays, so you can jump straight back to where you were.
	if index < 0 or index > furthest_stage:
		return
	stage = index
	_log_line("RECALL %s" % str(stages[index]).to_upper(), "OK")
	_rebuild()


# --------------------------------------------------- CRT tube post-process
func _add_crt_overlay() -> void:
	var shader: Shader = load(CRT_SHADER) as Shader
	if shader == null:
		return
	var glass := ColorRect.new()
	glass.name = "CRTGlass"
	glass.position = Vector2.ZERO
	glass.size = Vector2(1024, 768)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.z_index = 400
	var mat := ShaderMaterial.new()
	mat.shader = shader
	glass.material = mat
	add_child(glass)


func _clear() -> void:
	for c in content.get_children():
		c.queue_free()


func _build_stage() -> void:
	_clear()
	match _key():
		"intro": _build_intro()
		"deploy": _build_deploy()
		"plan": _build_plan()
		"thermal": _build_thermal()
		"guide": _build_guide()
		"wavefront": _build_wavefront()
		"expose": _build_expose()
		"process": _build_process()
		"filter": _build_filter()
		"report": _build_report()


func _advance() -> void:
	if _key() == "intro":
		GameManager.progress["space_intro_seen"] = true
	if _key() == "deploy":
		GameManager.progress["space_deployed"] = true
	stage = mini(stage + 1, stages.size() - 1)
	furthest_stage = maxi(furthest_stage, stage)
	_rebuild()


# ============================================================ INTRO (Maya teaching)
func _build_intro() -> void:
	var total := INTRO_CARDS.size() + 1     # page 0 = Maya, pages 1..5 = cards
	intro_page = clampi(intro_page, 0, total - 1)
	var board := _panel_to(content, Vector2(112, 6), Vector2(800, 456), Color("0b1830"), GOLD, "")
	if intro_page == 0:
		_label_to(board, GameManager.text("Maya - Observatory Club", "Maya - 天文社"), Vector2(0, 14), Vector2(800, 28), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_label_to(board, GameManager.text("Why we need a space telescope", "我们为什么需要一台太空望远镜"), Vector2(0, 46), Vector2(800, 24), 15, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
		_intro_diagram(board, "jwst_segmented_mirror")
		var maya := GameManager.text(
			"Our ground telescopes hit a wall: the air blurs and absorbs the faint infrared glow of cold dust and distant galaxies. So we launch this observatory to L2, keep it deep-cold behind a sunshield, and read the sky in infrared. This time you do not look through a lens - we plan, point, expose and process real data. Let's learn the parts first.",
			"我们的地面望远镜遇到了瓶颈：大气会模糊并吸收冷尘埃与遥远星系微弱的红外光。所以我们把这台天文台送到 L2，用遮阳罩保持极低温，在红外波段读取天空。这一次没有目镜——我们要规划、指向、曝光并处理真实数据。先来认识各个部件。")
		_wrap_to(board, maya, Vector2(60, 328), Vector2(680, 110), 14, TEXT)
	else:
		var card: Dictionary = GameManager.get_learning_card(str(INTRO_CARDS[intro_page - 1]))
		_label_to(board, GameManager.dict_text(card, "title"), Vector2(0, 16), Vector2(800, 30), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_intro_diagram(board, str(INTRO_CARDS[intro_page - 1]))
		_wrap_to(board, GameManager.dict_text(card, "text"), Vector2(60, 328), Vector2(680, 70), 14, TEXT)
		if intro_why:
			_wrap_to(board, _intro_why_text(str(INTRO_CARDS[intro_page - 1])), Vector2(60, 402), Vector2(680, 36), 12, CYAN)

	# page dots
	var dots := ""
	for i in range(total):
		dots += ("●" if i == intro_page else "○") + " "
	_label_to(content, dots, Vector2(112, 446), Vector2(800, 20), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# nav: Back / Why / Next-or-Start. Beginner mode: one page at a time.
	if intro_page > 0:
		var prev := _button(GameManager.text("Back", "上一页"), Vector2(180, 466), Vector2(150, 42), Color("143247"))
		prev.pressed.connect(func() -> void: intro_page -= 1; intro_why = false; _build_stage())
		content.add_child(prev)
		var why_btn := _button(GameManager.text("Why?", "为什么？"), Vector2(437, 466), Vector2(150, 42), Color("1c3350"))
		why_btn.pressed.connect(func() -> void: intro_why = not intro_why; _build_stage())
		content.add_child(why_btn)
	if intro_page < total - 1:
		var nxt := _button(GameManager.text("Next", "下一页"), Vector2(694, 466), Vector2(150, 42), Color("175238"))
		nxt.pressed.connect(func() -> void: intro_page += 1; intro_why = false; _build_stage())
		content.add_child(nxt)
	else:
		var start := _button(GameManager.text("Start Deployment", "开始部署"), Vector2(662, 466), Vector2(210, 42), Color("175238"))
		start.pressed.connect(_advance)
		content.add_child(start)
	_say(GameManager.text("First-time briefing - shown only once. Read each page, then deploy.", "首次教学——只播放一次。逐页阅读后开始部署。"), MUTED)


# ============================================================ 3D ATTITUDE GIMBAL
# A real orientable observatory instead of a slider: you grab the sphere and turn
# it. The wireframe globe, the sun vector, the sunshield plane and the boresight
# are all projected 3D->2D by hand, so dragging genuinely re-points the craft.
class AttitudeGimbal extends Control:
	var yaw := 0.0            # drag left/right
	var pitch := -0.35        # drag up/down (view tilt only)
	var sun_angle := 40.0     # the value the model cares about
	var safe_min := 85.0
	var safe_max := 135.0
	var dragging := false
	var on_changed: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				dragging = mb.pressed
				accept_event()
		elif event is InputEventMouseMotion and dragging:
			var mm := event as InputEventMouseMotion
			sun_angle = clampf(sun_angle + mm.relative.x * 0.45, 0.0, 180.0)
			pitch = clampf(pitch + mm.relative.y * 0.006, -1.1, 0.35)
			if on_changed.is_valid():
				on_changed.call(sun_angle)
			queue_redraw()
			accept_event()
		elif event is InputEventScreenDrag:
			var sd := event as InputEventScreenDrag
			sun_angle = clampf(sun_angle + sd.relative.x * 0.45, 0.0, 180.0)
			pitch = clampf(pitch + sd.relative.y * 0.006, -1.1, 0.35)
			if on_changed.is_valid():
				on_changed.call(sun_angle)
			queue_redraw()
			accept_event()
		elif event is InputEventScreenTouch:
			dragging = (event as InputEventScreenTouch).pressed
			accept_event()

	func _project(v: Vector3) -> Vector2:
		# rotate by yaw/pitch, then a simple perspective divide
		var cy := cos(yaw); var sy := sin(yaw)
		var p := Vector3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy)
		var cp := cos(pitch); var sp := sin(pitch)
		p = Vector3(p.x, p.y * cp - p.z * sp, p.y * sp + p.z * cp)
		var d := 4.0
		var f := d / (d + p.z)
		return Vector2(size.x * 0.5 + p.x * size.x * 0.36 * f,
			size.y * 0.5 - p.y * size.y * 0.36 * f)

	func _safe() -> bool:
		return sun_angle >= safe_min and sun_angle <= safe_max

	func _draw() -> void:
		# phosphor intensities, not hues: brightest = the thing you control
		var green := Color(0.86, 0.86, 0.86)   # boresight
		var dim := Color(0.30, 0.30, 0.30)     # globe wireframe
		var gold := Color(1.00, 1.00, 1.00)    # sun vector (hottest)
		var red := Color(0.62, 0.62, 0.62)     # unsafe cone reads as dull, not red
		# wireframe globe: latitude rings + longitude meridians
		for lat in range(-60, 90, 30):
			var pts: PackedVector2Array = []
			for k in range(37):
				var a := TAU * float(k) / 36.0
				var r := cos(deg_to_rad(float(lat)))
				pts.append(_project(Vector3(cos(a) * r, sin(deg_to_rad(float(lat))), sin(a) * r)))
			draw_polyline(pts, dim, 1.0)
		for lon in range(0, 180, 30):
			var pts2: PackedVector2Array = []
			for k in range(37):
				var a2 := TAU * float(k) / 36.0
				var lr := deg_to_rad(float(lon))
				pts2.append(_project(Vector3(cos(a2) * cos(lr), sin(a2), cos(a2) * sin(lr))))
			draw_polyline(pts2, dim, 1.0)
		# the safe cone the sun must stay inside
		var safe_col := green if _safe() else red
		for edge in [safe_min, safe_max]:
			var pts3: PackedVector2Array = []
			for k in range(37):
				var a3 := TAU * float(k) / 36.0
				var e := deg_to_rad(edge)
				pts3.append(_project(Vector3(cos(e), sin(e) * cos(a3), sin(e) * sin(a3))))
			draw_polyline(pts3, safe_col * Color(1, 1, 1, 0.85), 2.0)
		# boresight (where the telescope looks) - always +X
		var o := _project(Vector3.ZERO)
		draw_line(o, _project(Vector3(1.45, 0, 0)), green, 3.0)
		draw_circle(_project(Vector3(1.45, 0, 0)), 5.0, green)
		# sun vector at the chosen angle
		var sa := deg_to_rad(sun_angle)
		var sun_v := Vector3(cos(sa), sin(sa), 0.0)
		draw_line(o, _project(sun_v * 1.7), gold, 3.0)
		draw_circle(_project(sun_v * 1.7), 9.0, gold)
		# sunshield plane: a quad normal to the sun, between sun and optics
		var shield_n := sun_v
		var up := Vector3(0, 0, 1)
		var side := shield_n.cross(up).normalized()
		var base := shield_n * 0.55
		var quad := PackedVector2Array([
			_project(base + side * 0.85 + up * 0.45),
			_project(base - side * 0.85 + up * 0.45),
			_project(base - side * 0.85 - up * 0.45),
			_project(base + side * 0.85 - up * 0.45)])
		draw_colored_polygon(quad, (safe_col if _safe() else red) * Color(1, 1, 1, 0.22))
		draw_polyline(quad + PackedVector2Array([quad[0]]), safe_col, 2.0)


# ============================================================ SCIENCE IMAGE
# Draws the ACTUAL target, never a stand-in disc or a field of random dots.
# `detail` 0..1 drives how much structure has emerged (exposure + processing);
# `tint` comes from the false-colour channel mapping.
func _draw_target_image(parent: Control, rect: Rect2, detail: float, tint: Color = Color(1, 1, 1), cosmic: bool = false, ghost: bool = false) -> void:
	var d := clampf(detail, 0.0, 1.0)
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5
	_rect_to(parent, rect.position, rect.size, Color("04080f"))
	# faint background field stars (always sparse, never the subject)
	var rnd := 1237
	for i in range(46):
		rnd = (rnd * 1103515245 + 12345) & 0x7fffffff
		var sx := rect.position.x + float(rnd % int(rect.size.x))
		rnd = (rnd * 1103515245 + 12345) & 0x7fffffff
		var sy := rect.position.y + float(rnd % int(rect.size.y))
		var sa := 0.18 + 0.5 * d
		_rect_to(parent, Vector2(sx, sy), Vector2(2, 2), Color(0.75, 0.82, 0.95, sa))

	match model.target_kind:
		"nebula", "star_forming":
			# emission nebula: irregular glowing cloud + embedded young stars
			for i in range(11):
				var t := float(i) / 10.0
				var rr := lerpf(rect.size.x * 0.42, rect.size.x * 0.06, t)
				var a := (0.05 + 0.30 * d) * (0.35 + t * 0.9)
				var col := Color(tint.r * (0.55 + 0.45 * t), tint.g * (0.35 + 0.5 * t), tint.b * (0.30 + 0.35 * t), a)
				_ellipse_to(parent, Vector2(cx - rr * 0.10, cy + rr * 0.06), Vector2(rr, rr * 0.72), col)
			for k in range(6):
				var ang := float(k) * 1.05
				var p := Vector2(cx + cos(ang) * rect.size.x * 0.17, cy + sin(ang) * rect.size.y * 0.15)
				_rect_to(parent, p, Vector2(3, 3), Color(1, 0.95, 0.85, 0.35 + 0.6 * d))
		"star":
			# a bright cool giant: point core + extended halo, no disc/crescent
			for i in range(9):
				var t2 := float(i) / 8.0
				var rr2 := lerpf(rect.size.x * 0.20, 3.0, t2)
				var a2 := (0.06 + 0.34 * d) * (0.25 + t2)
				_ellipse_to(parent, Vector2(cx, cy), Vector2(rr2, rr2), Color(tint.r, tint.g * 0.72, tint.b * 0.5, a2))
			_rect_to(parent, Vector2(cx - 2, cy - 2), Vector2(4, 4), Color(1, 0.94, 0.82, 0.5 + 0.5 * d))
		_:
			# GALAXY (Andromeda-class): inclined disc + bright core + dust lane
			var rx := rect.size.x * 0.40
			var ry := rx * 0.34
			for i in range(12):
				var t3 := float(i) / 11.0
				var a3 := (0.04 + 0.26 * d) * (0.30 + t3 * 1.1)
				var col3 := Color(tint.r * (0.52 + 0.48 * t3), tint.g * (0.48 + 0.42 * t3), tint.b * (0.55 + 0.30 * t3), a3)
				_ellipse_to(parent, Vector2(cx, cy), Vector2(lerpf(rx, rx * 0.10, t3), lerpf(ry, ry * 0.10, t3)), col3)
			# dust lane across the disc (only resolves once detail is high)
			if d > 0.35:
				var da := (d - 0.35) * 0.7
				_ellipse_to(parent, Vector2(cx - rx * 0.10, cy + ry * 0.22), Vector2(rx * 0.86, ry * 0.16), Color(0.05, 0.03, 0.04, da))
			# bright nucleus
			_ellipse_to(parent, Vector2(cx, cy), Vector2(rx * 0.13, ry * 0.30), Color(1.0, 0.95, 0.86, 0.35 + 0.6 * d))
	if ghost:
		# mis-registered frames show a doubled image until they are aligned
		_ellipse_to(parent, Vector2(cx + 12, cy + 8), Vector2(rect.size.x * 0.30, rect.size.y * 0.14), Color(0.8, 0.6, 0.5, 0.20))
	if cosmic:
		_line_to(parent, Vector2(rect.position.x + 18, rect.position.y + 20),
			Vector2(rect.end.x - 26, rect.end.y - 34), Color(1, 1, 1, 0.92))


func _ellipse_to(parent: Control, center: Vector2, radii: Vector2, color: Color) -> void:
	# filled ellipse approximated with horizontal spans (no textures needed)
	var steps := 22
	for i in range(steps):
		var t := (float(i) / float(steps - 1)) * 2.0 - 1.0
		var w := radii.x * sqrt(maxf(0.0, 1.0 - t * t))
		var y := center.y + t * radii.y
		if w <= 0.5:
			continue
		_rect_to(parent, Vector2(center.x - w, y), Vector2(w * 2.0, maxf(2.0, radii.y * 2.0 / float(steps) + 1.0)), color)


func _wrap_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	# Property ORDER matters for wrapping: autowrap_mode must be set BEFORE .text,
	# or a long CJK string caches an unwrapped width and overflows the panel.
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2.ZERO
	label.text = value
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _intro_diagram(board: Control, card_id: String) -> void:
	var card: Dictionary = GameManager.get_learning_card(card_id)
	var path := str(card.get("image", ""))
	var frame := _rect_to(board, Vector2(60, 78), Vector2(680, 240), Color("06101c"))
	if path != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2.ZERO
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.texture = load(path)
		tex.position = Vector2(60, 78)
		tex.size = Vector2(680, 240)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(tex)


func _intro_why_text(card_id: String) -> String:
	match card_id:
		"jwst_infrared_light": return GameManager.text("Why it matters in play: the filter you pick decides which structure your image reveals.", "在游戏中的意义：你选的滤镜决定图像能显现哪种结构。")
		"jwst_segmented_mirror": return GameManager.text("Why it matters in play: you align the 18 segments until the split star images merge into one.", "在游戏中的意义：你要校准 18 块镜片，直到分裂的星点合并成一个。")
		"jwst_sunshield_l2": return GameManager.text("Why it matters in play: keep the sun in the safe zone or the cold side warms and noise rises.", "在游戏中的意义：让太阳保持在安全区，否则冷侧升温、噪声上升。")
		"jwst_instruments": return GameManager.text("Why it matters in play: the wrong instrument for the target lowers your final SNR.", "在游戏中的意义：仪器选错会降低最终信噪比。")
		"jwst_false_colour": return GameManager.text("Why it matters in play: you map filters to R/G/B, then read the science from the colours.", "在游戏中的意义：你把滤镜映射到 RGB，再从颜色读出科学结论。")
	return ""


func _say(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


# Spacecraft telemetry log. The player never types anything: every real action
# makes the console report back the way flight software does - a mission clock,
# a dotted leader out to a value, and a status word. That readback is what makes
# a single button press feel like commanding hardware.
func _log_line(label: String, status: String = "", value: String = "") -> void:
	var clock := "T+%02d:%02d" % [int(mission_clock) / 60, int(mission_clock) % 60]
	var body := label
	if value != "":
		body += " " + value
	# pad with dot leaders out to a fixed column so the log lines up like a printout
	var target_len := 46
	var dots := ""
	var pad := target_len - body.length()
	for _i in range(maxi(2, pad)):
		dots += "."
	var line := "%s  %s %s %s" % [clock, body, dots, status]
	console_log.append(line.strip_edges(false, true))
	while console_log.size() > CONSOLE_ROWS:
		console_log.pop_front()
	console_reveal = 0.0
	_render_console()


func _log(line: String) -> void:
	_log_line(line, "OK")


func _render_console() -> void:
	if console_label == null or not is_instance_valid(console_label):
		return
	# typewriter: only the newest line is revealed character by character
	var out: Array = []
	for i in range(console_log.size()):
		var raw := str(console_log[i])
		if i == console_log.size() - 1:
			var shown := int(clampf(console_reveal, 0.0, 1.0) * float(raw.length()))
			out.append(raw.substr(0, shown) + ("_" if shown < raw.length() else ""))
		else:
			out.append(raw)
	console_label.text = "\n".join(out)


# ============================================================ DEPLOY
func _build_deploy() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("OBSERVATORY DEPLOYMENT", "天文台部署"))
	deployment_visual = SpaceDeploymentVisualScript.new()
	deployment_visual.name = "DeploymentVisual"
	deployment_visual.position = Vector2(40, 8)
	deployment_visual.size = Vector2(600, 500)
	deployment_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deployment_visual.set_state(model.deployed)
	content.add_child(deployment_visual)
	scope = deployment_visual
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("DEPLOY SEQUENCE", "部署顺序"))
	_label_to(pad, GameManager.text("Deploy in order. Each stage must latch before the next.", "按顺序部署。每一步锁定后才能进行下一步。"),
		Vector2(16, 40), Vector2(284, 44), 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var names := {"solar_array": GameManager.text("1. Solar Array", "1. 太阳能板"),
		"sunshield": GameManager.text("2. Sunshield (5 layers)", "2. 遮阳罩（五层）"),
		"primary_mirror": GameManager.text("3. Primary Mirror Wings", "3. 主镜镜翼"),
		"secondary_mirror": GameManager.text("4. Secondary Mirror", "4. 副镜"),
		"hinges": GameManager.text("5. Latch Hinges", "5. 锁定铰链"),
		"actuators": GameManager.text("6. Start Actuators", "6. 启动执行器")}
	var y := 96.0
	for step in model.DEPLOY_ORDER:
		var b := _button(str(names[step]), Vector2(16, y), Vector2(284, 40), Color("143247"))
		if model.deployed.has(step):
			b.text = "✓ " + b.text
			b.disabled = true
			b.add_theme_stylebox_override("disabled", _flat(Color("0d2a1c"), GREEN, 2))
		b.pressed.connect(_try_deploy.bind(step))
		pad.add_child(b)
		y += 50.0
	if model.fully_deployed():
		var go := _button(GameManager.text("Deployment Complete - Continue", "部署完成——继续"), Vector2(16, 440), Vector2(284, 44), Color("175238"))
		go.pressed.connect(_advance)
		pad.add_child(go)


func _try_deploy(step: String) -> void:
	if deploy_animating:
		return
	var before := model.deployed.duplicate()
	if model.deploy(step):
		deploy_animating = true
		_log_line("DEPLOY %s" % step.to_upper(), "MOVING")
		_say(GameManager.text(
			"%s is moving. Wait for the latch confirmation." % step,
			"%s 正在展开，请等待锁定确认。" % step), CYAN)
		if deployment_visual != null and is_instance_valid(deployment_visual):
			deployment_visual.play_step(step, before, func() -> void:
				deploy_animating = false
				_log_line("LATCH %s" % step.to_upper(), "CONFIRMED")
				_say(GameManager.text("%s deployed and latched." % step, "%s 已展开并锁定。" % step), GREEN)
				_build_stage())
		else:
			deploy_animating = false
			_build_stage()
	else:
		var reason := model.deploy_blocked_reason(step)
		_say(GameManager.text("Cannot deploy yet - finish the earlier stage first (%s)." % reason,
			"还不能部署——请先完成前一步（%s）。" % reason), RED)
		InteractionFeedback.error(self)


func _draw_deploy() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# folded -> unfolded observatory schematic tied to deployment progress
	var cx := 300.0
	# sunshield layers grow as deployed
	if model.deployed.has("sunshield"):
		for i in range(5):
			var wdt := 200.0 - i * 12.0
			_rect_to(scope, Vector2(cx - wdt, 360 + i * 12), Vector2(wdt * 2, 8), lerp_color(ORANGE, Color("2a3f5a"), i / 4.0))
	elif model.deployed.has("solar_array"):
		_rect_to(scope, Vector2(cx - 60, 400), Vector2(120, 10), Color("2a3f5a"))
	# solar array wing
	if model.deployed.has("solar_array"):
		_rect_to(scope, Vector2(cx - 250, 420), Vector2(120, 40), Color("2c4a8a"))
	# primary mirror hex array (grows when deployed)
	if model.deployed.has("primary_mirror"):
		_hexes(scope, Vector2(cx, 220), 22, true)
	else:
		_hexes(scope, Vector2(cx, 220), 14, false)
	if model.deployed.has("secondary_mirror"):
		_ring_to(scope, Vector2(cx, 120), 16, CYAN)
		_line_to(scope, Vector2(cx - 60, 150), Vector2(cx, 120), CYAN)
		_line_to(scope, Vector2(cx + 60, 150), Vector2(cx, 120), CYAN)
	_label_to(scope, "%d / %d" % [model.deployed.size(), model.DEPLOY_ORDER.size()], Vector2(0, 470), Vector2(600, 24), 14,
		GREEN if model.fully_deployed() else CYAN, HORIZONTAL_ALIGNMENT_CENTER)


# ============================================================ PLAN
func _build_plan() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(944, 500), PANEL, GOLD, GameManager.text("OBSERVATION PLANNING", "观测规划"))
	_choice_row(GameManager.text("Instrument", "科学仪器"), model.INSTRUMENTS, model.instrument, Vector2(60, 56), "instrument")
	_choice_row(GameManager.text("Infrared Filter", "红外滤镜"), model.FILTERS, model.filter, Vector2(60, 150), "filter")
	_choice_row(GameManager.text("Dither Pattern", "抖动模式"), model.DITHERS, model.dither, Vector2(60, 244), "dither")
	# exposure + integrations
	_slider_row(GameManager.text("Exposure time (s)", "曝光时间 (s)"), Vector2(60, 336), 60.0, 900.0, model.exposure_time,
		func(v: float) -> void: model.exposure_time = v; _refresh_plan())
	_int_row(GameManager.text("Integrations (frames)", "积分次数（帧）"), Vector2(520, 336), 1, 8, model.integrations,
		func(v: int) -> void: model.integrations = v; _refresh_plan())
	readout = _label_to(content, "", Vector2(60, 404), Vector2(720, 60), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := _button(GameManager.text("Confirm Plan", "确认规划"), Vector2(760, 452), Vector2(200, 44), Color("175238"))
	go.pressed.connect(_confirm_plan)
	content.add_child(go)
	_refresh_plan()


func _choice_row(title: String, options: Array, current: String, pos: Vector2, field: String) -> void:
	_label_to(content, title, pos, Vector2(220, 22), 14, GOLD)
	# Teach the choice: the option that best fits THIS target is marked, so a
	# first-timer is never left guessing which one to press.
	var best := ""
	if field == "instrument":
		best = model.best_instrument
	elif field == "filter":
		best = model.best_filter
	if best != "":
		_label_to(content, GameManager.text("▸ best for this target: %s" % _opt_label(field, best), "▸ 本目标推荐：%s" % _opt_label(field, best)),
			pos + Vector2(0, 22), Vector2(220, 18), 11, P_MID)
	var x := pos.x + 220.0
	for opt in options:
		var selected := str(opt) == current
		var recommended := str(opt) == best
		var b := _button(("★ " if recommended else "") + _opt_label(field, str(opt)), Vector2(x, pos.y - 4), Vector2(128, 56), Color("122234"))
		b.add_theme_font_size_override("font_size", 11)
		# selected = inverted white; recommended-but-unselected = bright dashed hint
		if selected:
			b.add_theme_stylebox_override("normal", _flat(P_BRIGHT, P_HOT, 3))
			b.add_theme_color_override("font_color", BG)
		elif recommended:
			b.add_theme_stylebox_override("normal", _flat(Color("161616"), P_BRIGHT, 2))
			b.add_theme_color_override("font_color", P_HOT)
		b.pressed.connect(func() -> void: _set_plan(field, str(opt)))
		content.add_child(b)
		x += 136.0


func _opt_label(field: String, opt: String) -> String:
	var en := {
		"nircam": "NIRCam", "nirspec": "NIRSpec", "miri": "MIRI", "fgs_niriss": "FGS/NIRISS",
		"near_infrared": "Near IR", "mid_infrared": "Mid IR", "dust": "Dust", "star_forming": "Star-forming", "emission_line": "Emission",
		"none": "None", "two_point": "Two-point", "three_point": "Three-point", "box": "Box"}
	var zh := {
		"nircam": "NIRCam", "nirspec": "NIRSpec", "miri": "MIRI", "fgs_niriss": "FGS/NIRISS",
		"near_infrared": "近红外", "mid_infrared": "中红外", "dust": "尘埃", "star_forming": "恒星形成", "emission_line": "发射线",
		"none": "无", "two_point": "两点", "three_point": "三点", "box": "方框"}
	return GameManager.text(str(en.get(opt, opt.capitalize())), str(zh.get(opt, opt)))


func _set_plan(field: String, value: String) -> void:
	match field:
		"instrument": model.instrument = value
		"filter": model.filter = value
		"dither": model.dither = value
	# console SET line + a clear "you chose X" readout, so a click is never silent
	var field_up: String = {"instrument": "INSTRUMENT", "filter": "FILTER", "dither": "DITHER"}.get(field, field.to_upper())
	_log_line("SET %s = %s" % [field_up, value.to_upper()], "OK")
	_build_stage()
	var label: String = {"instrument": GameManager.text("Instrument", "仪器"), "filter": GameManager.text("Filter", "滤镜"), "dither": GameManager.text("Dither", "抖动")}.get(field, field)
	_say(GameManager.text("▸ Selected %s: %s" % [label, _opt_label(field, value)], "▸ 已选择%s：%s" % [label, _opt_label(field, value)]), P_HOT)


func _refresh_plan() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var ih: Dictionary = model.plan_hint("instrument", model.instrument)
	var fh: Dictionary = model.plan_hint("filter", model.filter)
	var zh := GameManager.language_mode == "zh"
	var isuits: String = ih["suits_zh"] if zh else ih["suits_en"]
	var ienh: String = ih["enhances_zh"] if zh else ih["enhances_en"]
	var isac: String = ih["sacrifices_zh"] if zh else ih["sacrifices_en"]
	var fsuits: String = fh["suits_zh"] if zh else fh["suits_en"]
	var warn := ""
	if model.saturates():
		warn = GameManager.text("  WARNING: long exposure will saturate this bright target.", "  警告：过长曝光会使这个亮目标过曝。")
	elif model.underexposed():
		warn = GameManager.text("  WARNING: too little total exposure - signal will be weak.", "  警告：总曝光太少——信号会很弱。")
	readout.text = GameManager.text(
		"Instrument suits: %s (enhances %s, sacrifices %s).\nFilter suits: %s.  Total exposure %.0f s over %d frames.%s" % [
			isuits, ienh, isac, fsuits, model.planned_total_time(), model.integrations, warn],
		"仪器适合：%s（增强%s，牺牲%s）。\n滤镜适合：%s。总曝光 %.0f 秒，共 %d 帧。%s" % [
			isuits, ienh, isac, fsuits, model.planned_total_time(), model.integrations, warn])
	readout.add_theme_color_override("font_color", ORANGE if (model.saturates() or model.underexposed()) else TEXT)


func _confirm_plan() -> void:
	if model.underexposed():
		_say(GameManager.text("Total exposure too low. Raise exposure time or integrations.", "总曝光太低。请提高曝光时间或积分次数。"), RED)
		InteractionFeedback.error(self)
		return
	_say(GameManager.text("Plan set. Check the thermal safety next.", "规划已设定。下一步检查热安全。"), GREEN)
	_advance()


# ============================================================ THERMAL
func _build_thermal() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("THERMAL & SAFE ATTITUDE", "热控与安全姿态"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 500)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("ATTITUDE CONTROL", "姿态控制"))
	readout = _label_to(pad, "", Vector2(16, 44), Vector2(284, 150), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 3D gimbal: grab the globe and turn the observatory. Replaces the slider so
	# the player is orienting a spacecraft, not scrubbing a value.
	_label_to(pad, GameManager.text("Drag the globe to re-point", "拖动球体调整指向"), Vector2(16, 196), Vector2(284, 20), 12, GOLD)
	var gimbal := AttitudeGimbal.new()
	gimbal.name = "AttitudeGimbal"
	gimbal.position = Vector2(22, 216)
	gimbal.size = Vector2(272, 190)
	gimbal.sun_angle = model.attitude_deg
	gimbal.safe_min = model.SAFE_MIN
	gimbal.safe_max = model.SAFE_MAX
	gimbal.on_changed = func(v: float) -> void:
		model.rotate_to(v)
		_refresh_thermal()
	pad.add_child(gimbal)
	# Touch-friendly nudge buttons (mobile): rotate the attitude without a slider.
	var rot_minus := _button("−10°", Vector2(16, 412), Vector2(132, 36), Color("143247"))
	rot_minus.name = "AttitudeMinus"
	rot_minus.pressed.connect(func() -> void: _animate_attitude_to(model.attitude_deg - 10.0))
	pad.add_child(rot_minus)
	var rot_plus := _button("+10°", Vector2(152, 412), Vector2(132, 36), Color("143247"))
	rot_plus.name = "AttitudePlus"
	rot_plus.pressed.connect(func() -> void: _animate_attitude_to(model.attitude_deg + 10.0))
	pad.add_child(rot_plus)
	var go := _button(GameManager.text("Confirm Safe Attitude", "确认安全姿态"), Vector2(16, 456), Vector2(284, 40), Color("175238"))
	go.pressed.connect(_confirm_thermal)
	pad.add_child(go)
	_refresh_thermal()


func _animate_attitude_to(requested: float) -> void:
	var target := clampf(requested, 0.0, 180.0)
	if attitude_tween != null and attitude_tween.is_valid():
		attitude_tween.kill()
	_log_line("GIMBAL SLEW", "RUN", "%.0f -> %.0f DEG" % [model.attitude_deg, target])
	attitude_tween = create_tween().bind_node(self)
	attitude_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attitude_tween.tween_method(func(value: float) -> void:
		model.rotate_to(value)
		_refresh_thermal(), model.attitude_deg, target, 0.34)
	attitude_tween.tween_callback(func() -> void:
		_log_line("GIMBAL SLEW", "HOLD", "%.0f DEG" % model.attitude_deg))


func _refresh_thermal() -> void:
	# keep the 3D gimbal in step with the model no matter what moved it
	var g := content.find_child("AttitudeGimbal", true, false) if content != null else null
	if g != null and is_instance_valid(g):
		g.set("sun_angle", model.attitude_deg)
		g.queue_redraw()
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Sun %.0f deg  %s\nEarth %.0f deg   Moon %.0f deg\nCold side %.0f K (target ~%.0f K)\nHot side %.0f K" % [
			model.sun_angle, "SAFE" if model.sun_safe() else "DANGER", model.earth_angle, model.moon_angle,
			model.cold_side_temp, model.COLD_TARGET, model.hot_side_temp],
		"太阳 %.0f 度  %s\n地球 %.0f 度   月球 %.0f 度\n冷侧 %.0f K（目标约 %.0f K）\n热侧 %.0f K" % [
			model.sun_angle, "安全" if model.sun_safe() else "危险", model.earth_angle, model.moon_angle,
			model.cold_side_temp, model.COLD_TARGET, model.hot_side_temp])
	readout.add_theme_color_override("font_color", GREEN if model.safe_to_observe() else RED)
	_draw_thermal()


func _draw_thermal() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var cx := 300.0
	var cy := 240.0
	# sunshield line, hot side (sun) vs cold side (mirror)
	var ang := deg_to_rad(model.attitude_deg)
	var sun := Vector2(cx - cos(ang) * 180.0, cy - sin(ang) * 120.0)
	_line_to(scope, sun, Vector2(cx, cy), Color("f2c14a"))
	_ring_to(scope, sun, 20, Color("f2c14a"))
	_label_to(scope, GameManager.text("Sun", "太阳"), sun + Vector2(-20, 24), Vector2(40, 16), 11, Color("f2c14a"), HORIZONTAL_ALIGNMENT_CENTER)
	# observatory: hot side toward sun, cold side away
	var shield_ok := model.sun_safe()
	_rect_to(scope, Vector2(cx - 90, cy - 8), Vector2(180, 16), ORANGE if not shield_ok else Color("2a3f5a"))
	_hexes(scope, Vector2(cx + 40, cy - 70), 16, true)
	# temperature gauge (cold side)
	var temp_ratio := clampf((model.cold_side_temp - model.COLD_TARGET) / 120.0, 0.0, 1.0)
	_rect_to(scope, Vector2(60, 400), Vector2(480, 22), Color("102037"))
	_rect_to(scope, Vector2(60, 400), Vector2(480 * (1.0 - temp_ratio), 22), lerp_color(RED, CYAN, 1.0 - temp_ratio))
	_label_to(scope, GameManager.text("Cold-side temperature (colder is better)", "冷侧温度（越冷越好）"), Vector2(60, 426), Vector2(480, 20), 11, MUTED)
	_label_to(scope, GameManager.text("SAFE ZONE" if shield_ok else "SUN OUTSIDE SHIELD - DANGER", "安全区" if shield_ok else "太阳超出遮阳罩——危险"),
		Vector2(60, 452), Vector2(480, 24), 14, GREEN if shield_ok else RED, HORIZONTAL_ALIGNMENT_CENTER)


func _confirm_thermal() -> void:
	if not model.safe_to_observe():
		_say(GameManager.text("Unsafe attitude. Rotate so the sun stays 85-135 deg off boresight and the optics stay cold.",
			"姿态不安全。请旋转使太阳保持在视轴 85-135 度之间，让光学部分保持低温。"), RED)
		InteractionFeedback.error(self)
		return
	_log("THERMAL SYSTEM ONLINE")
	_say(GameManager.text("Thermally safe. Lock a guide star next.", "热安全。下一步锁定导星。"), GREEN)
	_advance()


# ============================================================ GUIDE
func _build_guide() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("STAR FIELD & GUIDING", "星场与导星"))
	guide_field = SpaceGuideFieldScript.new()
	guide_field.name = "GuideField"
	guide_field.position = Vector2(40, 8)
	guide_field.size = Vector2(600, 500)
	guide_field.set_stars(model.guide_stars)
	guide_field.candidate_changed.connect(_on_guide_candidate_changed)
	content.add_child(guide_field)
	scope = guide_field
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("FINE GUIDANCE", "精细导星"))
	readout = _label_to(pad, "", Vector2(16, 40), Vector2(284, 190), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_to(pad, GameManager.text(
		"Drag the box over a bright star. Acquire it, then watch the lock ring close and the drift trace flatten.",
		"拖动搜索框覆盖明亮恒星，捕获后观察锁定环收缩咬合，漂移曲线逐渐拉平。"),
		Vector2(16, 238), Vector2(284, 66), 11, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var acquire := _button(GameManager.text("Acquire Highlighted Star", "捕获搜索框中的导星"), Vector2(16, 314), Vector2(284, 44), Color("143247"))
	acquire.name = "AcquireGuideCandidate"
	acquire.pressed.connect(_acquire_guide_candidate)
	pad.add_child(acquire)
	var go := _button(GameManager.text("Confirm Lock", "确认锁定"), Vector2(16, 440), Vector2(284, 44), Color("175238"))
	go.pressed.connect(_confirm_guide)
	pad.add_child(go)
	_refresh_guide()


func _on_guide_candidate_changed(index: int) -> void:
	guide_candidate = index
	if index >= 0 and index < model.guide_stars.size():
		var star: Dictionary = model.guide_stars[index]
		_log_line("FGS SEARCH WINDOW", "CANDIDATE", str(star.get("id", "GS")))
	else:
		_log_line("FGS SEARCH WINDOW", "SCANNING")
	_refresh_guide()


func _acquire_guide_candidate() -> void:
	if guide_candidate < 0:
		_say(GameManager.text(
			"No candidate is inside the search box. Drag it over a star first.",
			"搜索框内没有候选星。请先把它拖到恒星上。"), RED)
		InteractionFeedback.error(content)
		return
	_choose_guide(guide_candidate)


func _choose_guide(index: int) -> void:
	if model.choose_guide_star(index):
		guide_lock_logged = false
		_log_line("FGS ACQUIRE", "TRACK", str(model.guide_stars[index].get("id", "GS")))
		_say(GameManager.text("Guide star acquired. Waiting for fine-guidance lock...", "已选定导星。等待精细导星锁定……"), CYAN)
	else:
		_log_line("FGS ACQUIRE", "REJECT", str(model.guide_stars[index].get("id", "GS")))
		_say(GameManager.text("That star is too dim or too far off the detector - it cannot hold a lock.", "该导星太暗或偏离探测器太远——无法保持锁定。"), RED)
		InteractionFeedback.error(content)
	_refresh_guide()


func _refresh_guide() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Search candidate: %s\nPointing error %.2f arcsec\nDrift rate %.2f arcsec/s\nGuide quality %d%%\nFine guidance: %s" % [
			_guide_candidate_name(),
			model.pointing_error, model.drift_rate, int(model.guide_quality() * 100),
			"LOCKED" if model.guide_locked else "searching"],
		"搜索候选：%s\n指向误差 %.2f 角秒\n漂移速率 %.2f 角秒/秒\n导星质量 %d%%\n精细导星：%s" % [
			_guide_candidate_name(),
			model.pointing_error, model.drift_rate, int(model.guide_quality() * 100),
			"已锁定" if model.guide_locked else "搜索中"])
	readout.add_theme_color_override("font_color", GREEN if model.guide_locked else (CYAN if model.chosen_guide >= 0 else MUTED))
	if guide_field != null and is_instance_valid(guide_field):
		guide_field.update_metrics(model.pointing_error, model.drift_rate, model.guide_locked, model.chosen_guide)


func _guide_candidate_name() -> String:
	if guide_candidate < 0 or guide_candidate >= model.guide_stars.size():
		return GameManager.text("none - drag the search box", "无——请拖动搜索框")
	return str((model.guide_stars[guide_candidate] as Dictionary).get("id", "GS"))


func _draw_guide() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# detector box + candidate stars
	_rect_to(scope, Vector2(120, 100), Vector2(360, 300), Color("0a1626"))
	_label_to(scope, GameManager.text("detector field", "探测器视场"), Vector2(120, 76), Vector2(200, 18), 11, MUTED)
	var positions := [Vector2(180, 150), Vector2(300, 250), Vector2(430, 130), Vector2(250, 340)]
	for i in range(model.guide_stars.size()):
		var gs: Dictionary = model.guide_stars[i]
		var p: Vector2 = positions[i % positions.size()]
		var r := 3.0 + float(gs["brightness"]) * 7.0
		var col := GOLD if i == model.chosen_guide else (Color(0.8, 0.85, 0.95) if bool(gs["usable"]) else Color("55606e"))
		_ring_to(scope, p, r, col)
		_label_to(scope, str(gs["id"]), p + Vector2(-16, 12), Vector2(40, 14), 10, col, HORIZONTAL_ALIGNMENT_CENTER)
	# target reticle center
	_ring_to(scope, Vector2(300, 250), 20, GREEN if model.guide_locked else CYAN)
	_label_to(scope, GameManager.text("target", "目标"), Vector2(270, 274), Vector2(60, 14), 10, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(scope, GameManager.text("Bright, well-placed stars lock; dim or off-field stars drift.", "明亮且位置合适的星能锁定；暗淡或偏离视场的星会漂移。"),
		Vector2(120, 410), Vector2(360, 40), 11, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _confirm_guide() -> void:
	if not model.guide_locked:
		_say(GameManager.text("No stable lock yet. Choose a bright, well-placed guide star and let it settle.", "尚未稳定锁定。请选择明亮且位置合适的导星并等待稳定。"), RED)
		InteractionFeedback.error(self)
		return
	_log("GUIDE STAR LOCKED")
	_say(GameManager.text("Fine-guidance locked. Align the mirror segments next.", "精细导星已锁定。下一步校准镜面分段。"), GREEN)
	_advance()


# ============================================================ WAVEFRONT
func _build_wavefront() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("WAVEFRONT / MIRROR ALIGNMENT", "波前 / 镜面校准"))
	wavefront_display = SpaceWavefrontDisplayScript.new()
	wavefront_display.name = "WavefrontDisplay"
	wavefront_display.position = Vector2(40, 8)
	wavefront_display.size = Vector2(600, 500)
	wavefront_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(wavefront_display)
	scope = wavefront_display
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("SEGMENT ACTUATORS", "镜片执行器"))
	readout = _label_to(pad, "", Vector2(16, 44), Vector2(284, 150), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var coarse := _button(GameManager.text("Coarse align +", "粗对准 +"), Vector2(16, 250), Vector2(284, 44), Color("143247"))
	coarse.pressed.connect(_animate_wavefront_step.bind(0.18, "COARSE"))
	pad.add_child(coarse)
	var fine := _button(GameManager.text("Fine align +", "精对准 +"), Vector2(16, 306), Vector2(284, 44), Color("143247"))
	fine.pressed.connect(_animate_wavefront_step.bind(0.07, "FINE"))
	pad.add_child(fine)
	var go := _button(GameManager.text("Confirm Alignment", "确认对准"), Vector2(16, 440), Vector2(284, 44), Color("175238"))
	go.pressed.connect(_confirm_wavefront)
	pad.add_child(go)
	_refresh_wavefront()


func _animate_wavefront_step(amount: float, mode: String) -> void:
	if wavefront_animating or model.segment_alignment >= 1.0:
		return
	wavefront_animating = true
	var start := model.segment_alignment
	var target := clampf(start + amount, 0.0, 1.0)
	_log_line("WFS %s ACTUATION" % mode, "RUN", "%02d/18" % roundi(target * 18.0))
	var tween := create_tween().bind_node(self)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void:
		model.set_segment_alignment(value)
		_refresh_wavefront(), start, target, 0.58)
	tween.tween_callback(func() -> void:
		wavefront_animating = false
		_log_line("WFS %s ACTUATION" % mode, "HOLD", "%d NM" % roundi(model.wavefront_error_nm)))


func _refresh_wavefront() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Segment alignment %d%%\nWavefront error %.0f nm (target < 150)\nPSF sharpness %d%%\nCalibration %d%%" % [
			int(model.segment_alignment * 100), model.wavefront_error_nm, int(model.psf_sharpness() * 100), int(model.calibration_progress * 100)],
		"镜片对准 %d%%\n波前误差 %.0f nm（目标 < 150）\n点扩散锐度 %d%%\n校准进度 %d%%" % [
			int(model.segment_alignment * 100), model.wavefront_error_nm, int(model.psf_sharpness() * 100), int(model.calibration_progress * 100)])
	readout.add_theme_color_override("font_color", GREEN if model.wavefront_ok() else CYAN)
	if wavefront_display != null and is_instance_valid(wavefront_display):
		wavefront_display.alignment = model.segment_alignment
		wavefront_display.wavefront_error_nm = model.wavefront_error_nm


func _draw_wavefront() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var cx := 300.0
	var cy := 200.0
	var sharp := model.psf_sharpness()
	# many split star images that merge into one as alignment improves
	var spread := lerpf(70.0, 0.0, sharp)
	for i in range(6):
		var a := TAU * float(i) / 6.0
		var p := Vector2(cx + cos(a) * spread, cy + sin(a) * spread)
		var r := lerpf(6.0, 14.0, sharp)
		_ring_to(scope, p, r, lerp_color(Color("55606e"), Color(0.9, 0.95, 1.0), sharp))
	if sharp > 0.9:
		_ring_to(scope, Vector2(cx, cy), 18, Color(1, 1, 1))
	_label_to(scope, GameManager.text("Star image: 6 split spots merge into one sharp point.", "星点：6 个分裂光斑逐渐合并成一个锐利点。"),
		Vector2(60, 360), Vector2(480, 40), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _confirm_wavefront() -> void:
	if not model.wavefront_ok():
		_say(GameManager.text("Wavefront error still too high. Keep aligning until the star images merge (< 150 nm).",
			"波前误差仍然太大。继续对准直到星点合并（< 150 nm）。"), RED)
		InteractionFeedback.error(self)
		return
	_log("WAVEFRONT CONVERGED")
	_say(GameManager.text("Optics aligned. Begin the exposure.", "光学已对准。开始曝光。"), GREEN)
	_advance()


# ============================================================ EXPOSE
func _build_expose() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 470), PANEL, GOLD, GameManager.text("DETECTOR EXPOSURE", "探测器曝光"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 470)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	# What exposure IS - stated plainly, every visit.
	_wrap_to(content, GameManager.text(
		"Exposure collects infrared photons from the target over time. Longer total exposure lifts faint structure out of the noise.",
		"曝光就是让探测器在一段时间内累积目标发出的红外光子。总曝光越长，微弱结构越能从噪声中显现。"),
		Vector2(668, 44), Vector2(300, 74), 12, MUTED)
	var pad := _panel_to(content, Vector2(660, 8), Vector2(324, 470), PANEL, GOLD, GameManager.text("DETECTOR STATUS", "探测器状态"))
	readout = _label_to(pad, "", Vector2(16, 118), Vector2(292, 210), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Button states: before / during / after - never an endless Start.
	var start := _button("", Vector2(16, 344), Vector2(292, 44), Color("175238"))
	start.name = "StartExposure"
	if acquiring:
		start.text = GameManager.text("Exposing...", "曝光中……")
		start.disabled = true
		start.add_theme_stylebox_override("disabled", _flat(Color("1a2c1e"), GOLD, 2))
	elif model.acquired:
		start.text = GameManager.text("Exposure Complete", "曝光完成")
		start.disabled = true
		start.add_theme_stylebox_override("disabled", _flat(Color("0d2a1c"), GREEN, 2))
	else:
		start.text = GameManager.text("Start Exposure", "开始曝光")
		start.pressed.connect(_start_expose)
	pad.add_child(start)

	# Process Data becomes the primary highlighted button once frames exist.
	var go := _button(GameManager.text("Process Data", "处理数据"), Vector2(16, 398), Vector2(292, 44),
		Color("175238") if (model.acquired and not acquiring) else Color("101c2c"))
	go.name = "ProcessData"
	if model.acquired and not acquiring:
		go.add_theme_stylebox_override("normal", _flat(Color("175238"), GOLD_HI, 3))
	else:
		go.disabled = true
		go.add_theme_stylebox_override("disabled", _flat(Color("101c2c"), Color("2a3f5a"), 2))
	go.pressed.connect(_confirm_expose)
	pad.add_child(go)
	if not model.acquired:
		elapsed = 0.0
	_refresh_expose()


func _start_expose() -> void:
	if acquiring or model.acquired:
		return
	model.acquire()
	elapsed = 0.0
	acquiring = true
	_log("PHOTON INTEGRATION STARTED")
	_say(GameManager.text("Collecting photons frame by frame...", "逐帧采集光子……"), CYAN)
	_build_stage()


func _refresh_expose() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var total_time := 4.0
	var ratio := clampf(elapsed / total_time, 0.0, 1.0) if acquiring else (1.0 if model.acquired else 0.0)
	var p: Dictionary = model.photon_progress(ratio)
	var was := acquiring
	if acquiring and ratio >= 1.0:
		acquiring = false
	# The real target, growing out of the noise as photons accumulate.
	_draw_target_image(scope, Rect2(50, 56, 500, 300), float(p["signal"]),
		Color(1, 1, 1), bool(p["cosmic_this_frame"]), false)
	_label_to(scope, GameManager.dict_text(GameManager.current_target(), "name"),
		Vector2(50, 364), Vector2(500, 22), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	# per-frame progress bars
	for i in range(model.integrations):
		var done := i < int(p["frames_done"])
		_rect_to(scope, Vector2(50 + i * 62, 396), Vector2(54, 18), GREEN if done else Color("2a3f5a"))
		_label_to(scope, "%d" % (i + 1), Vector2(50 + i * 62, 396), Vector2(54, 18), 11,
			Color(0.05, 0.1, 0.08) if done else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(scope, GameManager.text("frames captured", "已采集帧"), Vector2(50, 420), Vector2(300, 18), 11, MUTED)
	if readout != null and is_instance_valid(readout):
		var integ := model.exposure_time * float(p["frames_done"])
		readout.text = GameManager.text(
			"Target        %s\nInstrument    %s\nFilter        %s\nFrame         %d / %d\nExposure time %.0f s per frame\nIntegration   %.0f s total\nSignal        %d%%\nBackground    %d%%\nDetector      %s" % [
				GameManager.dict_text(GameManager.current_target(), "name"),
				_opt_label("instrument", model.instrument), _opt_label("filter", model.filter),
				int(p["frames_done"]), model.integrations, model.exposure_time, integ,
				int(float(p["signal"]) * 100), int(float(p["noise"]) * 100),
				("INTEGRATING" if acquiring else ("READ OUT" if model.acquired else "IDLE"))],
			"目标      %s\n仪器      %s\n滤镜      %s\n帧        %d / %d\n单帧曝光  %.0f 秒\n累计积分  %.0f 秒\n信号      %d%%\n背景噪声  %d%%\n探测器    %s" % [
				GameManager.dict_text(GameManager.current_target(), "name"),
				_opt_label("instrument", model.instrument), _opt_label("filter", model.filter),
				int(p["frames_done"]), model.integrations, model.exposure_time, integ,
				int(float(p["signal"]) * 100), int(float(p["noise"]) * 100),
				("积分中" if acquiring else ("已读出" if model.acquired else "空闲"))])
		readout.add_theme_color_override("font_color", GREEN if model.acquired and not acquiring else TEXT)
	if bool(p["cosmic_this_frame"]):
		_label_to(scope, GameManager.text("COSMIC RAY EVENT", "宇宙射线事件"), Vector2(50, 56), Vector2(500, 20), 12, RED, HORIZONTAL_ALIGNMENT_CENTER)
	# the moment the last frame lands, rebuild so the buttons flip state
	if was and not acquiring:
		_log("PHOTON INTEGRATION COMPLETE")
		call_deferred("_build_stage")


func _confirm_expose() -> void:
	if not model.acquired:
		_say(GameManager.text("Start the exposure first.", "请先开始曝光。"), RED)
		return
	_advance()


# ============================================================ PROCESS
func _build_process() -> void:
	process_animating = false
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("FRAME PROCESSING", "数据帧处理"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 500)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("PROCESSING STEPS", "处理步骤"))
	# per-frame keep toggles (drop cosmic-ray frames)
	_label_to(pad, GameManager.text("Frames (drop bad ones):", "数据帧（剔除坏帧）："), Vector2(16, 40), Vector2(284, 20), 12, MUTED)
	var y := 66.0
	for i in range(model.frames.size()):
		var f: Dictionary = model.frames[i]
		var b := _button("%s #%d%s" % [GameManager.text("Frame", "帧"), i + 1, "  ☄" if bool(f["cosmic_ray"]) else ""],
			Vector2(16, y), Vector2(284, 30), Color("143247") if bool(f["kept"]) else Color("3a2418"))
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func() -> void: model.toggle_keep(i, not bool(model.frames[i]["kept"])); _build_stage())
		pad.add_child(b)
		y += 36.0
	var steps := [
		["align", GameManager.text("Align Frames", "对齐帧"), model.frames_aligned],
		["cosmic", GameManager.text("Remove Cosmic Rays", "移除宇宙射线"), model.cosmic_rays_removed],
		["background", GameManager.text("Subtract Background", "扣除背景"), model.background_subtracted],
		["stack", GameManager.text("Stack Exposures", "叠加曝光"), model.stacked],
	]
	for s in steps:
		var complete := bool(s[2])
		var b := _button(("✓ " if complete else "") + str(s[1]), Vector2(16, y), Vector2(284, 32), Color("0d2a1c") if complete else Color("143247"))
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = complete
		b.pressed.connect(_run_process_step.bind(str(s[0])))
		pad.add_child(b)
		y += 38.0
	var go := _button(GameManager.text("Generate Science Image", "生成科学图像"), Vector2(16, 452), Vector2(284, 40), Color("175238"))
	go.pressed.connect(_confirm_process)
	pad.add_child(go)
	_refresh_process()


func _refresh_process() -> void:
	_draw_process()


func _run_process_step(step_id: String) -> void:
	if process_animating:
		return
	var before_snr := model.snr()
	match step_id:
		"align":
			model.align_frames()
		"cosmic":
			model.remove_cosmic_rays()
		"background":
			model.subtract_background()
		"stack":
			model.stack()
		_:
			return
	process_animating = true
	_log_line("PIPELINE %s" % step_id.to_upper(), "RUN", "SNR %.1f" % before_snr)
	_say(_process_action_text(step_id), CYAN)
	_play_process_animation(step_id, before_snr)


func _process_action_text(step_id: String) -> String:
	match step_id:
		"align":
			return GameManager.text("Registering star centroids. Watch the four frame outlines converge.", "正在配准星点质心。观察四个帧框合拢。")
		"cosmic":
			return GameManager.text("Scanning transient hits. The diagonal cosmic-ray streak is being erased.", "正在扫描瞬态撞击。斜向宇宙线亮痕正在被清除。")
		"background":
			return GameManager.text("Estimating the infrared background. The noise floor is dropping.", "正在估计红外背景。噪声底正在下降。")
		"stack":
			return GameManager.text("Co-adding the registered frames. Faint structure is emerging.", "正在叠加已配准帧。微弱结构正在显现。")
	return ""


func _play_process_animation(step_id: String, before_snr: float) -> void:
	if scope == null or not is_instance_valid(scope):
		process_animating = false
		return
	var image_rect := Rect2(60, 52, 480, 300)
	var overlay := Control.new()
	overlay.name = "ProcessTransition_" + step_id
	overlay.position = Vector2.ZERO
	overlay.size = scope.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 40
	scope.add_child(overlay)
	var tween := create_tween().bind_node(self).set_parallel(true)
	match step_id:
		"align":
			var offsets := [Vector2(-18, -12), Vector2(14, 9), Vector2(-9, 16), Vector2(20, -5)]
			for index in range(offsets.size()):
				var frame := Panel.new()
				frame.position = image_rect.position + offsets[index]
				frame.size = image_rect.size
				frame.modulate.a = 0.72
				frame.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), P_BRIGHT, 1))
				overlay.add_child(frame)
				tween.tween_property(frame, "position", image_rect.position, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(frame, "modulate:a", 0.0, 0.54).set_delay(0.12)
		"cosmic":
			var hit := Line2D.new()
			hit.width = 3.0
			hit.default_color = P_HOT
			hit.points = PackedVector2Array([image_rect.position + Vector2(18, 20), image_rect.end - Vector2(26, 34)])
			overlay.add_child(hit)
			var scan := ColorRect.new()
			scan.color = P_HOT
			scan.position = image_rect.position
			scan.size = Vector2(image_rect.size.x, 2)
			overlay.add_child(scan)
			tween.tween_property(scan, "position:y", image_rect.end.y, 0.48).set_trans(Tween.TRANS_LINEAR)
			tween.tween_property(hit, "modulate:a", 0.0, 0.42).set_delay(0.10)
			tween.tween_property(scan, "modulate:a", 0.0, 0.12).set_delay(0.46)
		"background":
			var veil := ColorRect.new()
			veil.color = Color(1, 1, 1, 0.18)
			veil.position = image_rect.position
			veil.size = image_rect.size
			overlay.add_child(veil)
			for row in range(12):
				var noise_line := ColorRect.new()
				noise_line.color = Color(1, 1, 1, 0.16 if row % 2 == 0 else 0.08)
				noise_line.position = image_rect.position + Vector2(0, 8 + row * 23)
				noise_line.size = Vector2(image_rect.size.x, 1)
				overlay.add_child(noise_line)
				tween.tween_property(noise_line, "modulate:a", 0.0, 0.42 + row * 0.008)
			tween.tween_property(veil, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		"stack":
			var offsets := [Vector2(-24, -15), Vector2(-8, -5), Vector2(9, 6), Vector2(25, 15)]
			for index in range(offsets.size()):
				var frame := Panel.new()
				frame.position = image_rect.position + offsets[index]
				frame.size = image_rect.size
				frame.modulate.a = 0.35 + index * 0.10
				frame.add_theme_stylebox_override("panel", _flat(Color(0.02, 0.02, 0.02, 0.08), P_MID, 1))
				overlay.add_child(frame)
				tween.tween_property(frame, "position", image_rect.position, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				if index < offsets.size() - 1:
					tween.tween_property(frame, "modulate:a", 0.0, 0.18).set_delay(0.40)
	tween.chain().tween_callback(_finish_process_animation.bind(step_id, before_snr, overlay))


func _finish_process_animation(step_id: String, before_snr: float, overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	process_animating = false
	_log_line("PIPELINE %s" % step_id.to_upper(), "COMPLETE", "SNR %.1f -> %.1f" % [before_snr, model.snr()])
	_say(GameManager.text("Processing step complete. The image and telemetry now agree.", "处理步骤完成。图像与遥测数据已同步更新。"), GREEN)
	if _key() == "process":
		_build_stage()


func _draw_process() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# The real target: each processing step visibly cleans the image.
	var quality := clampf(model.snr() / 26.0, 0.06, 1.0)
	_draw_target_image(scope, Rect2(60, 52, 480, 300), quality, Color(1, 1, 1),
		not model.cosmic_rays_removed, not model.frames_aligned)
	_label_to(scope, GameManager.dict_text(GameManager.current_target(), "name"),
		Vector2(60, 358), Vector2(480, 20), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	# tell the player exactly what they are looking at right now
	var note := GameManager.text("Raw stack: cosmic-ray streak and doubled image still present.", "原始叠加：仍有宇宙线亮线与重影。")
	if model.cosmic_rays_removed and not model.frames_aligned:
		note = GameManager.text("Cosmic rays gone. Frames still mis-registered - align them.", "宇宙线已去除。各帧仍未对齐——请对齐。")
	elif model.frames_aligned and not model.background_subtracted:
		note = GameManager.text("Frames aligned. Subtract the background to drop the noise floor.", "各帧已对齐。扣除背景以降低噪声底。")
	elif model.background_subtracted and not model.stacked:
		note = GameManager.text("Background removed. Stack the frames to raise the signal.", "背景已扣除。叠加各帧以提升信号。")
	elif model.processing_ready():
		note = GameManager.text("Stacked science image - faint structure is now visible.", "叠加完成——微弱结构已经显现。")
	_wrap_to(scope, note, Vector2(60, 380), Vector2(480, 36), 12, CYAN)
	_label_to(scope, GameManager.text("Live SNR %.1f   Kept frames %d" % [model.snr(), model.kept_frames()],
		"实时信噪比 %.1f   保留帧 %d" % [model.snr(), model.kept_frames()]), Vector2(60, 418), Vector2(480, 22), 13,
		GREEN if model.snr() >= 10.0 else CYAN)


func _confirm_process() -> void:
	if not model.processing_ready():
		_say(GameManager.text("Finish align, cosmic-ray removal, background and stacking first.", "请先完成对齐、移除宇宙射线、扣除背景和叠加。"), RED)
		InteractionFeedback.error(self)
		return
	if model.snr() < 10.0:
		_say(GameManager.text("SNR still below 10. Keep more good frames or improve earlier stages.", "信噪比仍低于 10。请保留更多好帧或改进前面的步骤。"), ORANGE)
		return
	_log("SCIENCE IMAGE RECONSTRUCTED")
	_say(GameManager.text("Science image generated. Map the filters.", "科学图像已生成。进行滤镜映射。"), GREEN)
	_advance()


# ============================================================ FILTER
func _build_filter() -> void:
	filter_animating = false
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("FALSE-COLOUR FILTER MAPPING", "假彩色滤镜映射"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 500)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("CHANNELS & SCIENCE", "通道与科学"))
	_label_to(pad, GameManager.text("1 MAP BANDS  >  2 READ STRUCTURE  >  3 INFER",
		"1 映射波段  >  2 读取结构  >  3 作出推断"), Vector2(16, 40), Vector2(284, 22), 11, P_BRIGHT)
	_label_to(pad, GameManager.text("The colour is a code for wavelength, not what an eye would see.",
		"颜色是波长编码，不是肉眼看到的颜色。"), Vector2(16, 64), Vector2(284, 34), 10, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var y := 102.0
	for ch in ["R", "G", "B"]:
		_label_to(pad, ch, Vector2(16, y), Vector2(24, 30), 15, GOLD)
		var x := 44.0
		for filt in ["near_infrared", "mid_infrared", "dust"]:
			var b := _button(_opt_label("filter", filt), Vector2(x, y - 2), Vector2(80, 30), Color("1c3a5c") if str(model.channel_map[ch]) == filt else Color("122234"))
			b.add_theme_font_size_override("font_size", 10)
			b.pressed.connect(_set_filter_channel.bind(ch, filt))
			pad.add_child(b)
			x += 84.0
		y += 44.0
	_label_to(pad, GameManager.text("Scientific interpretation:", "科学解释："), Vector2(16, y + 6), Vector2(284, 20), 12, MUTED)
	y += 34.0
	for opt in model.science_options():
		var b := _button(_science_label(opt), Vector2(16, y), Vector2(284, 30), Color("1c3a5c") if model.chosen_science == opt else Color("143247"))
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_set_science_choice.bind(opt))
		pad.add_child(b)
		y += 36.0
	var go := _button(GameManager.text("Confirm Science Image", "确认科学图像"), Vector2(16, 452), Vector2(284, 40), Color("175238"))
	go.pressed.connect(_confirm_filter)
	pad.add_child(go)
	_draw_filter()


func _set_filter_channel(channel: String, filter_id: String) -> void:
	if filter_animating:
		return
	model.set_channel(channel, filter_id)
	_log_line("MAP CHANNEL %s" % channel, "RUN", filter_id.to_upper())
	_say(GameManager.text(
		"Recomposing %s from the %s band. Watch the scan reveal which structures brighten." % [channel, _opt_label("filter", filter_id)],
		"正在用%s波段重组%s通道。观察扫描后哪些结构变亮。" % [_opt_label("filter", filter_id), channel]), CYAN)
	_draw_filter()
	_play_filter_scan("MAP " + channel)


func _set_science_choice(option: String) -> void:
	if filter_animating:
		return
	model.choose_science(option)
	_log_line("SCIENCE HYPOTHESIS", "SET", option.to_upper())
	_draw_filter()
	if model.science_correct():
		_say(GameManager.text(
			"Hypothesis matches the visible structure. Confirm the science image.",
			"推断与可见结构吻合。请确认科学图像。"), GREEN)
	else:
		_say(GameManager.text(
			"Hypothesis recorded. Compare it with the evidence callouts before confirming.",
			"推断已记录。确认前请将它与结构证据标注对照。"), CYAN)
	_play_filter_scan("HYPOTHESIS")


func _play_filter_scan(label_text: String) -> void:
	if scope == null or not is_instance_valid(scope):
		return
	filter_animating = true
	var scan := ColorRect.new()
	scan.name = "FilterScan"
	scan.color = P_HOT
	scan.position = Vector2(60, 52)
	scan.size = Vector2(480, 2)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.z_index = 50
	scope.add_child(scan)
	var tag := _label_to(scope, label_text, Vector2(66, 58), Vector2(180, 18), 10, P_HOT)
	tag.z_index = 51
	var tween := create_tween().bind_node(self).set_parallel(true)
	tween.tween_property(scan, "position:y", 352.0, 0.34).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(scan, "modulate:a", 0.0, 0.12).set_delay(0.30)
	tween.tween_property(tag, "modulate:a", 0.0, 0.24).set_delay(0.16)
	tween.chain().tween_callback(_finish_filter_scan.bind(scan, tag))


func _finish_filter_scan(scan: ColorRect, tag: Label) -> void:
	if is_instance_valid(scan):
		scan.queue_free()
	if is_instance_valid(tag):
		tag.queue_free()
	filter_animating = false
	_log_line("FALSE COLOUR COMPOSITE", "UPDATED")
	if _key() == "filter":
		_build_stage()


func _science_label(opt: String) -> String:
	var m := {"dust_rich": ["Dust-rich region", "富尘埃区"], "star_forming": ["Star-forming region", "恒星形成区"],
		"old_stellar": ["Old stellar population", "老年恒星族"], "hot_gas": ["Hot gas", "高温气体"],
		"distant_galaxy": ["Redshifted distant galaxy", "红移遥远星系"]}
	var pair: Array = m.get(opt, [opt, opt])
	return GameManager.text(str(pair[0]), str(pair[1]))


func _draw_filter() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# composite tinted by the channel mapping so different maps look different
	var tint := Color(0.2, 0.2, 0.2)
	var band_col := {"near_infrared": Color(0.9, 0.4, 0.3), "mid_infrared": Color(0.3, 0.5, 0.9), "dust": Color(0.4, 0.8, 0.5)}
	if str(model.channel_map["R"]) != "":
		tint.r += 0.5 * band_col.get(str(model.channel_map["R"]), Color.WHITE).r
	if str(model.channel_map["G"]) != "":
		tint.g += 0.5 * band_col.get(str(model.channel_map["G"]), Color.WHITE).g
	if str(model.channel_map["B"]) != "":
		tint.b += 0.5 * band_col.get(str(model.channel_map["B"]), Color.WHITE).b
	# the SAME target, recoloured by the channel mapping the player chose
	_draw_target_image(scope, Rect2(60, 52, 480, 300), clampf(model.snr() / 26.0, 0.2, 1.0), tint)
	_label_to(scope, GameManager.dict_text(GameManager.current_target(), "name") + "  ·  " +
		GameManager.text("false colour", "假彩色"), Vector2(60, 358), Vector2(480, 20), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var mapped := "R=%s  G=%s  B=%s" % [
		_opt_label("filter", str(model.channel_map["R"])) if str(model.channel_map["R"]) != "" else "-",
		_opt_label("filter", str(model.channel_map["G"])) if str(model.channel_map["G"]) != "" else "-",
		_opt_label("filter", str(model.channel_map["B"])) if str(model.channel_map["B"]) != "" else "-"]
	_label_to(scope, mapped, Vector2(60, 380), Vector2(480, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	if model.mapping_complete():
		_draw_filter_evidence(scope)
	else:
		_wrap_to(scope, GameManager.text(
			"Assign three different bands. Longer-wavelength dust emission and shorter-wavelength stellar light will separate into different structures.",
			"分配三个不同波段。长波尘埃辐射与短波恒星光会分离成不同结构。"),
			Vector2(60, 404), Vector2(480, 52), 12, MUTED)


func _draw_filter_evidence(parent: Control) -> void:
	var evidence := _filter_evidence()
	_label_to(parent, GameManager.text("STRUCTURE EVIDENCE", "结构证据"), Vector2(60, 402), Vector2(480, 18), 11, P_HOT)
	for index in range(mini(3, evidence.size())):
		_label_to(parent, "▸ " + str(evidence[index]), Vector2(70, 422 + index * 18), Vector2(466, 18), 10, P_BRIGHT)
	# A restrained callout points at the diagnostic feature without covering it.
	var feature_pos := Vector2(360, 230)
	var feature_text := GameManager.text("DIAGNOSTIC FEATURE", "诊断结构")
	if model.true_science == "star_forming":
		feature_pos = Vector2(338, 198)
		feature_text = GameManager.text("COMPACT KNOTS", "致密亮结")
	elif model.true_science == "dust_rich":
		feature_pos = Vector2(350, 250)
		feature_text = GameManager.text("DUST LANE", "尘埃带")
	elif model.true_science == "old_stellar":
		feature_text = GameManager.text("SMOOTH HALO", "平滑晕")
	elif model.true_science == "hot_gas":
		feature_text = GameManager.text("SHELL / ARC", "壳层 / 弧")
	elif model.true_science == "distant_galaxy":
		feature_text = GameManager.text("SHIFTED CORE", "红移核心")
	_line_to(parent, feature_pos, Vector2(474, 174), P_HOT)
	_label_to(parent, feature_text, Vector2(412, 154), Vector2(132, 18), 9, P_HOT, HORIZONTAL_ALIGNMENT_RIGHT)


func _filter_evidence() -> Array:
	match model.true_science:
		"dust_rich":
			return [
				GameManager.text("Broad dark lanes split the stellar glow.", "宽阔暗带切开恒星辉光。"),
				GameManager.text("Long-wave dust emission is spatially extended.", "长波尘埃辐射呈延展分布。"),
				GameManager.text("The compact stellar knots are not dominant.", "致密恒星亮结并不占主导。")]
		"star_forming":
			return [
				GameManager.text("Several compact bright knots mark young clusters.", "多个致密亮结标记年轻星团。"),
				GameManager.text("Filaments wrap around the embedded stars.", "丝状结构环绕嵌入恒星。"),
				GameManager.text("Dust and short-wave starlight overlap locally.", "尘埃与短波恒星光局部重合。")]
		"old_stellar":
			return [
				GameManager.text("The halo is smooth rather than clumpy.", "星晕平滑而非成团。"),
				GameManager.text("Dust lanes and compact knots are weak.", "尘埃带和致密亮结都较弱。"),
				GameManager.text("Diffuse stellar light dominates the frame.", "弥散恒星光主导画面。")]
		"hot_gas":
			return [
				GameManager.text("Shell-like arcs trace heated gas.", "壳状弧线勾勒受热气体。"),
				GameManager.text("Emission extends beyond compact stars.", "辐射延伸到致密恒星之外。"),
				GameManager.text("Shock structures are brighter than dust lanes.", "激波结构比尘埃带更明亮。")]
		"distant_galaxy":
			return [
				GameManager.text("A compact core sits inside a faint broad disc.", "致密核心位于暗弱宽盘之中。"),
				GameManager.text("The strongest signal shifts to longer bands.", "最强信号偏向更长波段。"),
				GameManager.text("Surface brightness falls smoothly outward.", "表面亮度向外平滑降低。")]
	return []


func _confirm_filter() -> void:
	if not model.mapping_complete():
		_say(GameManager.text("Assign a different filter to each of R, G and B first.", "请先给 R、G、B 各分配一个不同的滤镜。"), RED)
		InteractionFeedback.error(self)
		return
	if model.chosen_science == "":
		_say(GameManager.text("Choose the scientific interpretation.", "请选择科学解释。"), ORANGE)
		return
	if not model.science_correct():
		_say(GameManager.text("That interpretation does not match the structure this filter set reveals. Look again.",
			"该解释与这组滤镜显示的结构不符。请再观察。"), ORANGE)
		InteractionFeedback.error(self)
		return
	_log("FALSE-COLOUR COMPOSITE READY")
	_say(GameManager.text("Science image confirmed. Read the report.", "科学图像已确认。查看报告。"), GREEN)
	_advance()


# ============================================================ REPORT
func _build_report() -> void:
	var rep := model.report()
	_panel_to(content, Vector2(212, 8), Vector2(600, 480), PANEL, GOLD, GameManager.text("SCIENCE OBSERVATION REPORT", "科学观测报告"))
	var rows := [
		[GameManager.text("Signal-to-noise", "信噪比"), "%.1f" % float(rep["snr"])],
		[GameManager.text("Exposure quality", "曝光质量"), "%d%%" % int(float(rep["exposure_quality"]) * 100)],
		[GameManager.text("Pointing accuracy", "指向精度"), "%d%%" % int(float(rep["pointing_accuracy"]) * 100)],
		[GameManager.text("Thermal stability", "热稳定度"), "%d%%" % int(float(rep["thermal_stability"]) * 100)],
		[GameManager.text("Frame count", "帧数"), "%d" % int(rep["frame_count"])],
		[GameManager.text("Cosmic-ray rejection", "宇宙射线剔除"), "%d%%" % int(float(rep["cosmic_ray_rejection"]) * 100)],
		[GameManager.text("Instrument / filter", "仪器 / 滤镜"), "%s / %s" % [_opt_label("instrument", str(rep["instrument"])), _opt_label("filter", str(rep["filter"]))]],
		[GameManager.text("Scientific confidence", "科学置信度"), "%d%%" % int(float(rep["scientific_confidence"]) * 100)],
		[GameManager.text("Finding", "结论"), _science_label(str(rep["science_finding"]))],
	]
	var y := 52.0
	var reveal := create_tween().bind_node(self).set_parallel(true)
	for index in range(rows.size()):
		var row: Array = rows[index]
		var holder := Control.new()
		holder.name = "ReportRow_%02d" % index
		holder.position = Vector2(246, y)
		holder.size = Vector2(540, 28)
		holder.modulate.a = 0.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(holder)
		_label_to(holder, str(row[0]), Vector2(6, 0), Vector2(280, 24), 14, MUTED)
		_label_to(holder, str(row[1]), Vector2(294, 0), Vector2(240, 24), 14, TEXT)
		var pulse := ColorRect.new()
		pulse.color = Color(1, 1, 1, 0.22)
		pulse.position = Vector2(0, 25)
		pulse.size = Vector2(0, 1)
		pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pulse)
		var delay := float(index) * 0.075
		reveal.tween_property(holder, "modulate:a", 1.0, 0.16).set_delay(delay)
		reveal.tween_property(holder, "position:x", 252.0, 0.18).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal.tween_property(pulse, "size:x", 534.0, 0.18).set_delay(delay)
		reveal.tween_property(pulse, "modulate:a", 0.0, 0.14).set_delay(delay + 0.15)
		y += 38.0
	var submit := _button(GameManager.text("Submit Report", "提交报告"), Vector2(392, 430), Vector2(240, 46), Color("175238"))
	submit.modulate.a = 0.28
	submit.pressed.connect(_submit)
	content.add_child(submit)
	reveal.tween_property(submit, "modulate:a", 1.0, 0.22).set_delay(float(rows.size()) * 0.075)
	_log_line("REPORT TELEMETRY", "DECODE", "%02d FIELDS" % rows.size())


func _submit() -> void:
	if running:
		return
	running = true
	var rep := model.report()
	var observation := {
		"success": true, "quality": _quality(float(rep["snr"])),
		"clarity": clampf(float(rep["snr"]) * 3.0, 0.0, 100.0),
		"contrast": clampf(float(rep["scientific_confidence"]) * 100.0, 0.0, 100.0),
		"detail": clampf(float(rep["thermal_stability"]) * 100.0, 0.0, 100.0),
		"snr": float(rep["snr"]), "observation_mode": "space_infrared",
		"instrument": rep["instrument"], "filter": rep["filter"],
		"science_finding": rep["science_finding"],
		"feedback_en": "Infrared science image confirmed the target's structure.",
		"feedback_zh": "红外科学图像确认了目标的结构。",
	}
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _quality(v: float) -> String:
	if v >= 24.0: return "Excellent"
	if v >= 16.0: return "Good"
	if v >= 10.0: return "Fair"
	return "Poor"


# ============================================================ helpers
func _slider_row(title: String, pos: Vector2, lo: float, hi: float, value: float, changed: Callable) -> void:
	_slider_row_to(content, title, pos, lo, hi, value, changed)


func _slider_row_to(parent: Control, title: String, pos: Vector2, lo: float, hi: float, value: float, changed: Callable) -> void:
	_label_to(parent, title, pos, Vector2(300, 18), 13, GOLD)
	var s := HSlider.new()
	s.position = pos + Vector2(0, 24)
	s.size = Vector2(300, 20)
	s.min_value = lo; s.max_value = hi; s.step = (hi - lo) / 200.0; s.value = value
	s.value_changed.connect(changed)
	parent.add_child(s)


func _int_row(title: String, pos: Vector2, lo: int, hi: int, value: int, changed: Callable) -> void:
	_label_to(content, title + ": " + str(value), pos, Vector2(300, 18), 13, GOLD).name = "IntLabel"
	var minus := _button("-", pos + Vector2(0, 24), Vector2(40, 30), Color("143247"))
	minus.pressed.connect(func() -> void: changed.call(maxi(lo, value - 1)); _build_stage())
	content.add_child(minus)
	var plus := _button("+", pos + Vector2(48, 24), Vector2(40, 30), Color("143247"))
	plus.pressed.connect(func() -> void: changed.call(mini(hi, value + 1)); _build_stage())
	content.add_child(plus)


func lerp_color(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


func _hexes(parent: Control, center: Vector2, r: float, full: bool) -> void:
	var coords := [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [1, -1], [-1, 1]] if full else [[0, 0], [1, 0], [-1, 0]]
	var w := r * sqrt(3.0)
	for c in coords:
		var cx: float = center.x + w * (c[0] + c[1] / 2.0)
		var cy: float = center.y + r * 1.5 * c[1]
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color("e8c65a") if full else Color("6a5a2a")
		for i in range(7):
			var a := PI / 6.0 + i * PI / 3.0
			line.add_point(Vector2(cx + cos(a) * r, cy + sin(a) * r))
		parent.add_child(line)


func _ring_to(parent: Control, center: Vector2, radius: float, color: Color) -> void:
	var node := Line2D.new()
	node.width = 2.5
	node.default_color = color
	for i in range(25):
		var a := TAU * float(i) / 24.0
		node.add_point(center + Vector2(cos(a), sin(a)) * radius)
	parent.add_child(node)


func _line_to(parent: Control, a: Vector2, b: Vector2, color: Color) -> void:
	var node := Line2D.new()
	node.width = 2.0
	node.default_color = color
	node.add_point(a); node.add_point(b)
	parent.add_child(node)


func _rect_to(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos; r.size = size; r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	return _panel_to(self, pos, size_value, fill, border, "")


func _panel_to(parent: Control, pos: Vector2, size_value: Vector2, fill: Color, border: Color, title: String) -> Panel:
	# Monochrome instrument bay: a hairline rule, dark well, and corner ticks like
	# a machine faceplate. No coloured slabs.
	var panel := Panel.new()
	panel.position = pos; panel.size = size_value
	panel.add_theme_stylebox_override("panel", _flat(PANEL, P_MID, 1))
	parent.add_child(panel)
	var tick := 12.0
	for corner in [Vector2(0, 0), Vector2(size_value.x, 0), Vector2(0, size_value.y), Vector2(size_value.x, size_value.y)]:
		var sx: float = -1.0 if corner.x > 0.0 else 1.0
		var sy: float = -1.0 if corner.y > 0.0 else 1.0
		_rect_to(panel, Vector2(corner.x + (0.0 if sx > 0.0 else -tick), corner.y + (0.0 if sy > 0.0 else -2.0)), Vector2(tick, 2), P_BRIGHT)
		_rect_to(panel, Vector2(corner.x + (0.0 if sx > 0.0 else -2.0), corner.y + (0.0 if sy > 0.0 else -tick)), Vector2(2, tick), P_BRIGHT)
	if title != "":
		# heading sits on a ruled line, printed like a section header
		_label_to(panel, title.to_upper(), Vector2(0, 7), Vector2(size_value.x, 22), 14, P_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
		_rect_to(panel, Vector2(10, 32), Vector2(size_value.x - 20, 1), P_FAINT)
	return panel


func _flat(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill; style.border_color = border
	style.set_border_width_all(width); style.set_corner_radius_all(0)
	return style


func _label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label_to(self, value, pos, size_value, font_size, color, alignment)


func _label_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value; label.position = pos; label.size = size_value
	label.horizontal_alignment = alignment; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	# One monochrome control style. `color` is now read only as an EMPHASIS hint:
	# anything that used to be the green "go" colour becomes the inverted
	# (filled-white) primary control; everything else is an outline control.
	# Legacy callers still pass their old semantic tint. Only the old green
	# action colour is primary; navy/blue choices often also have G > R, so they
	# must additionally be greener than blue and sufficiently bright.
	var primary := color.g > color.b and color.g > color.r * 1.35 and color.g > 0.25
	var button := Button.new()
	button.text = value; button.position = pos; button.size = size_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	if primary:
		button.add_theme_stylebox_override("normal", _flat(P_BRIGHT, P_HOT, 1))
		button.add_theme_stylebox_override("hover", _flat(P_HOT, P_HOT, 2))
		button.add_theme_stylebox_override("pressed", _flat(P_MID, P_HOT, 2))
		button.add_theme_color_override("font_color", BG)
		button.add_theme_color_override("font_hover_color", BG)
		button.add_theme_color_override("font_pressed_color", BG)
	else:
		button.add_theme_stylebox_override("normal", _flat(Color("101010"), P_MID, 1))
		button.add_theme_stylebox_override("hover", _flat(Color("1e1e1e"), P_HOT, 2))
		button.add_theme_stylebox_override("pressed", _flat(P_BRIGHT, P_HOT, 2))
		button.add_theme_color_override("font_color", P_BRIGHT)
		button.add_theme_color_override("font_hover_color", P_HOT)
		button.add_theme_color_override("font_pressed_color", BG)
	button.add_theme_stylebox_override("disabled", _flat(Color("0a0a0a"), P_FAINT, 1))
	button.add_theme_color_override("font_disabled_color", P_DIM)
	# Every press makes the console react - this is the "the machine is doing
	# what I told it" feedback. Connected FIRST so it fires before the specific
	# handler (which may rebuild the stage and re-render the log).
	button.pressed.connect(_emit_button.bind(value))
	return button


# Turn a button label into a plausible command line the console prints back.
func _emit_button(label: String) -> void:
	var t := label.strip_edges()
	if t == "" or t == "-" or t == "+" or t.begins_with("✓") or t.length() > 30:
		return
	var code := "CMD %s" % t.to_upper()
	var lower := t.to_lower()
	if lower.contains("confirm") or lower.contains("确认") or lower.contains("complete") or lower.contains("完成"):
		code = "COMMIT %s" % t.to_upper()
	elif lower.contains("start") or lower.contains("开始") or lower.contains("generate") or lower.contains("生成"):
		code = "EXEC %s" % t.to_upper()
	elif lower.contains("submit") or lower.contains("提交"):
		code = "UPLINK REPORT"
	elif lower.contains("back") or lower.contains("返回"):
		return
	_log_line(code, "OK")
