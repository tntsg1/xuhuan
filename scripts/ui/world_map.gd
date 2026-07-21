extends Control

# World Map — astronomical navigation transition.
#
# The map is the authored image (assets/world_map/world_map_base.png, 1672x941),
# aspect-fit + NEAREST, never redrawn procedurally. Everything dynamic lives on
# a transparent overlay above it.
#
# The relocation is a SEVEN-PHASE state machine, not a static arc:
#   INTRO   circular globe reveal, current site blue pulse, "below horizon"
#   SCAN    cyan scan wave sweeps out; candidate sites resolve one by one
#   FOUND   "Visible site found", recommended site turns gold
#   ROUTE   glowing arc draws from current -> recommended, light head travels
#   READY   waits for the player; Confirm Site enabled, compass points at it
#   CONFIRM press feedback, expanding ring, zoom-in, big destination name
#   TRAVEL  camera pans to the destination, other markers fade, arrival burst
#   DEPART  map contracts into a point of light -> sky observation
#
# Site visibility is computed ONCE in _ready (before any animation), so Skip can
# never skip the calculation - only its presentation.

const MAP_TEXTURE := "res://assets/world_map/world_map_base.png"
const MAP_SIZE := Vector2(1672.0, 941.0)
const MAP_INNER := Rect2(161.0, 96.0, 1349.0, 742.0)
const MAP_AREA := Rect2(0.0, 92.0, 764.0, 600.0)

const GOLD := Color("e0aa46")
const GOLD_BRIGHT := Color("ffd27a")
const CYAN := Color("55c7df")
const CYAN_BRIGHT := Color("8ae6ff")
const GREEN := Color("6fdf8a")
const RED := Color("ef6a5a")
const WHITE_DATA := Color("eef2f6")
const TEXT := Color("ece8dc")
const DIM := Color("7f8ba0")
const SITE_DIM := Color("2f5578")

enum Phase { INTRO, SCAN, FOUND, ROUTE, READY, CONFIRM, TRAVEL, DEPART }

const DURATIONS := {
	Phase.INTRO: 1.7, Phase.SCAN: 1.5, Phase.FOUND: 0.7, Phase.ROUTE: 1.5,
	Phase.CONFIRM: 1.1, Phase.TRAVEL: 1.7, Phase.DEPART: 0.9
}

var utc: Dictionary = {}
var home_site: Dictionary = {}
var current_site: Dictionary = {}
var recommended: Dictionary = {}
var sites: Array = []
var radec: Dictionary = {}
var minimum_altitude := 10.0
var target_below := false
var target_low := false
var target_alt_now := 0.0

var site_visibility: Dictionary = {}
var scan_order: Array = []          # site ids sorted by distance from current
var resolved_count := 0             # how many candidates the scan has revealed
var selected_id := ""

var phase: int = Phase.INTRO
var phase_t := 0.0
var anim_t := 0.0
var reveal := 0.0                   # circular globe reveal 0..1
var arc_progress := 0.0
var scan_radius := 0.0
var confirm_ring := 0.0
var travel_blend := 0.0
var depart_shrink := 0.0
var panel_reveal := 0.0

# view transform
var map_scale := 0.0
var user_scale := 0.0
var base_scale := 1.0
var view_initialized := false
var map_origin := Vector2.ZERO
var pan := Vector2.ZERO
var zoom_boost := 0.0
var travel_pan_from := Vector2.ZERO
var travel_pan_to := Vector2.ZERO
var dragging := false
var pinch_points: Dictionary = {}
var pinch_start_dist := -1.0
var pinch_start_scale := 1.0

var map_image: TextureRect
var map_material: ShaderMaterial
var overlay: Control
var info_panel: Control
var confirm_button: Button
var skip_button: Button
var back_button: Button
var status_label: Label
var headline_label: Label
var panel_rows: Array = []   # [{labels:[Label], order:int}] for staggered reveal


func _ready() -> void:
	utc = Time.get_datetime_dict_from_system(true)
	home_site = GameManager.home_location()
	current_site = GameManager.observing_location()
	sites = GameManager.location_sites()
	radec = GameManager.current_target_radec()
	var service := SkyPositionService.new()
	minimum_altitude = float(service.config.get("minimum_visible_altitude_degrees", 10.0))
	var vis_now: Dictionary = GameManager.target_visibility()
	target_alt_now = float(vis_now.get("altitude", 0.0))
	target_below = bool(vis_now.get("below_horizon", false))
	target_low = (not target_below) and not bool(vis_now.get("visible", true))
	# ALL site maths happens here, before a single frame of animation.
	_compute_all_visibility(service)
	recommended = GameManager.recommend_observation_location()
	selected_id = str(recommended.get("site", {}).get("id", "")) if not recommended.is_empty() else ""
	_build_scan_order()
	_build()
	# Target already comfortably up: short confirm beat, no full search.
	if not target_below and not target_low:
		_set_phase(Phase.READY)
		resolved_count = scan_order.size()
		arc_progress = 1.0
		reveal = 1.0
	set_process(true)


func _reduced() -> bool:
	return InteractionFeedback.is_reduced_motion()


func _duration(p: int) -> float:
	var d := float(DURATIONS.get(p, 1.0))
	return d * (0.35 if _reduced() else 1.0)


func _compute_all_visibility(service: SkyPositionService) -> void:
	if radec.is_empty():
		return
	for site_value in sites:
		var site: Dictionary = site_value
		var v := service.visibility_at(float(radec["ra_hours"]), float(radec["dec_degrees"]), float(site.get("lat", 0.0)), float(site.get("lon", 0.0)), utc)
		site_visibility[str(site.get("id", ""))] = {
			"site": site,
			"altitude": float(v["altitude"]),
			"azimuth": float(v["azimuth"]),
			"visible": bool(v["visible"]),
			"direction_text": str(v["direction_text"]),
			"local_time": service.local_time_string(float(site.get("lon", 0.0)), utc),
			"visible_hours": service.visible_duration_hours(float(radec["ra_hours"]), float(radec["dec_degrees"]), float(site.get("lat", 0.0)), float(site.get("lon", 0.0)), utc)
		}


func _build_scan_order() -> void:
	# The scan wave resolves sites in order of distance from the current site.
	var cur := Vector2(float(current_site.get("lon", 0.0)), float(current_site.get("lat", 0.0)))
	var entries: Array = []
	for site_value in sites:
		var s: Dictionary = site_value
		var d := Vector2(float(s.get("lon", 0.0)), float(s.get("lat", 0.0))).distance_to(cur)
		entries.append({"id": str(s.get("id", "")), "d": d})
	entries.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	scan_order.clear()
	for e in entries:
		scan_order.append(str((e as Dictionary)["id"]))


# ------------------------------------------------------- view transform


func _recompute_view() -> void:
	# user_scale is the player's own zoom; zoom_boost is the animation's, applied
	# as a DERIVED factor so it can never compound frame over frame.
	base_scale = minf(MAP_AREA.size.x / MAP_SIZE.x, MAP_AREA.size.y / MAP_SIZE.y)
	if not view_initialized:
		user_scale = base_scale
		view_initialized = true
	user_scale = clampf(user_scale, base_scale, base_scale * 3.0)
	map_scale = user_scale * (1.0 + zoom_boost)
	var drawn := MAP_SIZE * map_scale
	map_origin = MAP_AREA.position + (MAP_AREA.size - drawn) * 0.5 + pan


func _image_to_screen(p: Vector2) -> Vector2:
	return map_origin + p * map_scale


func _project(lat: float, lon: float) -> Vector2:
	var ix := MAP_INNER.position.x + (lon + 180.0) / 360.0 * MAP_INNER.size.x
	var iy := MAP_INNER.position.y + (90.0 - lat) / 180.0 * MAP_INNER.size.y
	return _image_to_screen(Vector2(ix, iy))


# --------------------------------------------------------------- build


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("03050c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_recompute_view()
	map_image = TextureRect.new()
	map_image.name = "MapImage"
	map_image.texture = load(MAP_TEXTURE)
	map_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_image.stretch_mode = TextureRect.STRETCH_SCALE
	map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_image.position = map_origin
	map_image.size = MAP_SIZE * map_scale
	# Circular "globe" reveal: the map opens out of a disc instead of a fade.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.6) = 0.0;
uniform float aspect = 1.78;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = UV - vec2(0.5);
	d.x *= aspect;
	float r = length(d);
	float edge = smoothstep(reveal, reveal - 0.06, r);
	float rim = smoothstep(reveal - 0.02, reveal, r) * smoothstep(reveal + 0.05, reveal, r);
	c.rgb += vec3(0.55, 0.42, 0.16) * rim * 1.4;
	c.a *= edge;
	COLOR = c;
}"""
	map_material = ShaderMaterial.new()
	map_material.shader = shader
	map_material.set_shader_parameter("reveal", 0.0)
	map_material.set_shader_parameter("aspect", MAP_SIZE.x / MAP_SIZE.y)
	map_image.material = map_material
	add_child(map_image)

	overlay = Control.new()
	overlay.name = "DynamicOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)

	headline_label = _label("", Vector2(20, 12), Vector2(744, 30), 21, RED, HORIZONTAL_ALIGNMENT_CENTER)
	status_label = _label("", Vector2(20, 44), Vector2(744, 22), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_refresh_headline()

	info_panel = Control.new()
	info_panel.position = Vector2(784, 150)
	info_panel.size = Vector2(228, 452)
	add_child(info_panel)

	# Buttons live at FIXED positions and never move with the animation.
	confirm_button = _button(GameManager.text("Confirm Site", "确认地点"), Vector2(784, 614), Vector2(228, 46), GOLD)
	confirm_button.pressed.connect(_on_confirm)
	add_child(confirm_button)
	skip_button = _button(GameManager.text("Skip", "跳过"), Vector2(784, 668), Vector2(110, 34), Color(0.16, 0.20, 0.28))
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.pressed.connect(_skip_animation)
	add_child(skip_button)
	back_button = _button(GameManager.text("Back", "返回"), Vector2(902, 668), Vector2(110, 34), Color(0.16, 0.20, 0.28))
	back_button.add_theme_font_size_override("font_size", 12)
	back_button.pressed.connect(_on_back)
	add_child(back_button)

	_build_site_buttons()
	_refresh_info()


func _refresh_headline() -> void:
	if headline_label == null:
		return
	if target_below:
		headline_label.text = GameManager.text("TARGET BELOW THE HORIZON", "目标位于地平线以下")
		headline_label.add_theme_color_override("font_color", RED)
	elif target_low:
		headline_label.text = GameManager.text("TARGET TOO LOW HERE", "目标在此高度过低")
		headline_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	else:
		headline_label.text = GameManager.text("CHANGE OBSERVATION SITE", "更换观测地点")
		headline_label.add_theme_color_override("font_color", GOLD)


func _build_site_buttons() -> void:
	for site_value in sites:
		var site: Dictionary = site_value
		var id := str(site.get("id", ""))
		var btn := Button.new()
		btn.name = "site_" + id
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(34, 34)
		btn.size = Vector2(34, 34)
		btn.tooltip_text = GameManager.dict_text(site, "name")
		btn.modulate = Color(1, 1, 1, 0)
		var captured := id
		btn.pressed.connect(func() -> void: _pick_site(captured))
		add_child(btn)


func _update_site_button_positions() -> void:
	var interactive := phase == Phase.READY or phase == Phase.SCAN or phase == Phase.FOUND or phase == Phase.ROUTE
	for site_value in sites:
		var site: Dictionary = site_value
		var btn := get_node_or_null(NodePath("site_" + str(site.get("id", "")))) as Button
		if btn == null:
			continue
		var p := _project(float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
		btn.position = p - Vector2(17, 17)
		btn.visible = interactive and MAP_AREA.has_point(p) and _is_resolved(str(site.get("id", "")))


func _is_resolved(id: String) -> bool:
	var idx := scan_order.find(id)
	return idx >= 0 and idx < resolved_count


func _pick_site(id: String) -> void:
	if not _is_resolved(id):
		return
	selected_id = id
	arc_progress = 0.0
	if phase == Phase.READY:
		_set_phase(Phase.ROUTE)
	_refresh_info()


# ------------------------------------------------------------ state machine


func _set_phase(p: int) -> void:
	phase = p
	phase_t = 0.0
	match p:
		Phase.INTRO:
			pass
		Phase.SCAN:
			scan_radius = 0.0
			resolved_count = 0
		Phase.FOUND:
			resolved_count = scan_order.size()
		Phase.ROUTE:
			arc_progress = 0.0
		Phase.READY:
			resolved_count = scan_order.size()
			arc_progress = 1.0
		Phase.CONFIRM:
			confirm_ring = 0.0
		Phase.TRAVEL:
			travel_pan_from = pan
			travel_pan_to = _pan_to_center(selected_id)
		Phase.DEPART:
			depart_shrink = 0.0
	_update_status_text()
	_update_button_states()


func _pan_to_center(id: String) -> Vector2:
	var v: Dictionary = site_visibility.get(id, {})
	var s: Dictionary = v.get("site", {})
	if s.is_empty():
		return pan
	# pan so the destination sits at the middle of the map area
	var target_img := Vector2(
		MAP_INNER.position.x + (float(s.get("lon", 0.0)) + 180.0) / 360.0 * MAP_INNER.size.x,
		MAP_INNER.position.y + (90.0 - float(s.get("lat", 0.0))) / 180.0 * MAP_INNER.size.y)
	var centre := MAP_AREA.position + MAP_AREA.size * 0.5
	var drawn := MAP_SIZE * map_scale
	var origin_wanted := centre - target_img * map_scale
	return origin_wanted - (MAP_AREA.position + (MAP_AREA.size - drawn) * 0.5)


func _update_status_text() -> void:
	if status_label == null:
		return
	var t := ""
	var c := CYAN
	match phase:
		Phase.INTRO:
			t = GameManager.text("Searching for visible sites...", "正在寻找可观测地点……")
		Phase.SCAN:
			t = GameManager.text("Scanning the globe...", "正在扫描全球观测点……")
		Phase.FOUND:
			t = GameManager.text("Visible site found", "找到可观测地点")
			c = GOLD_BRIGHT
		Phase.ROUTE:
			t = GameManager.text("Calculating a new observing location...", "正在计算新的观测地点……")
		Phase.READY:
			t = GameManager.text("Confirm the site to travel there.", "点击确认地点即可前往。")
			c = GOLD
		Phase.CONFIRM:
			t = GameManager.text("The target is now above the horizon.", "目标现在已经升到地平线以上。")
			c = GREEN
		Phase.TRAVEL:
			t = GameManager.text("Travelling to the observing site...", "正在前往观测地点……")
			c = GOLD_BRIGHT
		Phase.DEPART:
			t = GameManager.text("Arriving...", "抵达中……")
			c = GOLD_BRIGHT
	status_label.text = t
	status_label.add_theme_color_override("font_color", c)


func _update_button_states() -> void:
	if confirm_button == null:
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	var can_confirm := phase == Phase.READY and bool(v.get("visible", false))
	confirm_button.disabled = not can_confirm
	if skip_button != null:
		skip_button.disabled = phase >= Phase.CONFIRM
	# Back is always available.


func _process(delta: float) -> void:
	anim_t += delta
	phase_t += delta
	var d := _duration(phase)

	match phase:
		Phase.INTRO:
			reveal = _ease_out(clampf(phase_t / d, 0.0, 1.0)) * 1.25
			if phase_t >= d:
				reveal = 1.25
				_set_phase(Phase.SCAN)
		Phase.SCAN:
			reveal = 1.25
			var k := clampf(phase_t / d, 0.0, 1.0)
			scan_radius = k * 1100.0
			resolved_count = int(round(k * float(scan_order.size())))
			if phase_t >= d:
				_set_phase(Phase.FOUND)
		Phase.FOUND:
			if phase_t >= d:
				_set_phase(Phase.ROUTE)
		Phase.ROUTE:
			arc_progress = _ease_out(clampf(phase_t / d, 0.0, 1.0))
			if phase_t >= d:
				arc_progress = 1.0
				_set_phase(Phase.READY)
		Phase.READY:
			pass
		Phase.CONFIRM:
			confirm_ring = clampf(phase_t / d, 0.0, 1.0)
			zoom_boost = _ease_out(confirm_ring) * 0.16
			if phase_t >= d:
				_set_phase(Phase.TRAVEL)
		Phase.TRAVEL:
			travel_blend = _ease_in_out(clampf(phase_t / d, 0.0, 1.0))
			pan = travel_pan_from.lerp(travel_pan_to, travel_blend)
			zoom_boost = 0.16 + travel_blend * 0.22
			if phase_t >= d:
				_set_phase(Phase.DEPART)
		Phase.DEPART:
			depart_shrink = clampf(phase_t / d, 0.0, 1.0)
			zoom_boost = 0.38 - depart_shrink * 0.9
			reveal = 1.25 * (1.0 - _ease_in_out(depart_shrink))
			if phase_t >= d:
				_enter_sky()
				return

	panel_reveal = minf(panel_reveal + delta * (5.0 if _reduced() else 1.9), 1.0)
	for row_value in panel_rows:
		var row: Dictionary = row_value
		var node := row["node"] as Control
		if node != null and is_instance_valid(node):
			node.modulate = Color(1, 1, 1, clampf(panel_reveal * 14.0 - float(row["order"]), 0.0, 1.0))
	if map_material != null:
		map_material.set_shader_parameter("reveal", reveal)
	_recompute_view()
	if map_image != null:
		map_image.position = map_origin
		map_image.size = MAP_SIZE * map_scale
	_update_site_button_positions()
	_update_button_states()
	if overlay != null:
		overlay.queue_redraw()


func _skip_animation() -> void:
	# Presentation only: the site maths already ran in _ready.
	if phase >= Phase.CONFIRM:
		return
	reveal = 1.25
	resolved_count = scan_order.size()
	arc_progress = 1.0
	panel_reveal = 1.0
	_set_phase(Phase.READY)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ input


func _gui_input(event: InputEvent) -> void:
	if phase >= Phase.CONFIRM:
		return  # camera is under animation control
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed and MAP_AREA.has_point(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.12)
	elif event is InputEventMouseMotion and dragging:
		pan += (event as InputEventMouseMotion).relative
		_clamp_pan()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			pinch_points[t.index] = t.position
		else:
			pinch_points.erase(t.index)
			pinch_start_dist = -1.0
	elif event is InputEventScreenDrag:
		var dg := event as InputEventScreenDrag
		if pinch_points.has(dg.index):
			pinch_points[dg.index] = dg.position
		if pinch_points.size() >= 2:
			var keys: Array = pinch_points.keys()
			var span: float = (pinch_points[keys[0]] as Vector2).distance_to(pinch_points[keys[1]] as Vector2)
			if pinch_start_dist <= 0.0:
				pinch_start_dist = span
				pinch_start_scale = user_scale
			else:
				var c: Vector2 = ((pinch_points[keys[0]] as Vector2) + (pinch_points[keys[1]] as Vector2)) * 0.5
				_set_zoom(pinch_start_scale * (span / pinch_start_dist), c)
		else:
			pan += dg.relative
			_clamp_pan()


func _zoom_at(center: Vector2, factor: float) -> void:
	_set_zoom(map_scale * factor, center)


func _set_zoom(new_scale: float, center: Vector2) -> void:
	var before := (center - map_origin) / map_scale
	user_scale = clampf(new_scale, base_scale, base_scale * 3.0)
	_recompute_view()
	var after := (center - map_origin) / map_scale
	pan += (after - before) * map_scale
	_clamp_pan()


func _clamp_pan() -> void:
	var slack: Vector2 = (MAP_SIZE * map_scale - MAP_AREA.size) * 0.5
	slack.x = maxf(slack.x, 0.0)
	slack.y = maxf(slack.y, 0.0)
	pan.x = clampf(pan.x, -slack.x, slack.x)
	pan.y = clampf(pan.y, -slack.y, slack.y)
	_recompute_view()
	if map_image != null:
		map_image.position = map_origin
		map_image.size = MAP_SIZE * map_scale
	if overlay != null:
		overlay.queue_redraw()


# ---------------------------------------------------------------- drawing


func _draw_overlay() -> void:
	if overlay == null or reveal <= 0.02:
		return
	var font := get_theme_default_font()
	var fade: float = clampf(reveal / 1.25, 0.0, 1.0)
	_draw_terminator(fade)
	_draw_scan(font)
	_draw_route(font, fade)
	_draw_markers(font, fade)
	_draw_confirm_fx(font)


func _draw_terminator(fade: float) -> void:
	# Subtle day/night shading, drawn on the overlay (the artwork is untouched).
	var utc_hour := float(utc.get("hour", 0)) + float(utc.get("minute", 0)) / 60.0
	var night_lon := fposmod(180.0 - utc_hour * 15.0 + 180.0 + 180.0, 360.0) - 180.0
	var cols := 60
	for c in range(cols):
		var lon := -180.0 + (float(c) + 0.5) / float(cols) * 360.0
		var dlon := absf(fposmod(lon - night_lon + 180.0, 360.0) - 180.0)
		if dlon >= 90.0:
			continue
		var a := (1.0 - dlon / 90.0) * 0.22 * fade
		var x0 := _project(0.0, lon - 180.0 / float(cols)).x
		var x1 := _project(0.0, lon + 180.0 / float(cols)).x
		var top := _project(90.0, lon).y
		var bot := _project(-90.0, lon).y
		var r := Rect2(Vector2(x0, top), Vector2(maxf(x1 - x0, 1.5), bot - top))
		var clipped := r.intersection(MAP_AREA)
		if clipped.size.x > 0.0 and clipped.size.y > 0.0:
			overlay.draw_rect(clipped, Color(0.0, 0.02, 0.06, a))


func _draw_scan(font: Font) -> void:
	if phase != Phase.SCAN or scan_radius <= 0.0:
		return
	var origin := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	# expanding cyan scan wave
	for i in range(3):
		var r := scan_radius - float(i) * 42.0
		if r <= 0.0:
			continue
		var a: float = clampf(1.0 - r / 1100.0, 0.0, 1.0) * (0.5 - float(i) * 0.13)
		overlay.draw_arc(origin, r, 0.0, TAU, 64, Color(CYAN.r, CYAN.g, CYAN.b, a), 2.0)
	# scanning graticule rows sweeping down
	var sweep_y: float = MAP_AREA.position.y + fmod(anim_t * 300.0, MAP_AREA.size.y)
	overlay.draw_line(Vector2(MAP_AREA.position.x, sweep_y), Vector2(MAP_AREA.end.x, sweep_y), Color(CYAN.r, CYAN.g, CYAN.b, 0.22), 1.0)


func _draw_markers(font: Font, fade: float) -> void:
	# --- current site: blue pulse (3 beats during INTRO) ---
	var cur := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	if MAP_AREA.has_point(cur):
		var beat := sin(anim_t * 4.2)
		var fading_out: float = 1.0 - travel_blend
		_draw_marker(cur, CYAN_BRIGHT, 6.0, true, fade * fading_out)
		if phase <= Phase.ROUTE:
			# expanding confirmation rings
			var t: float = fmod(anim_t * 0.9, 1.0)
			overlay.draw_arc(cur, 8.0 + t * 26.0, 0.0, TAU, 32, Color(CYAN.r, CYAN.g, CYAN.b, (1.0 - t) * 0.55 * fade), 2.0)
		_draw_tag(font, cur + Vector2(11, -12), GameManager.dict_text(current_site, "name"), CYAN_BRIGHT, fade * fading_out)
		if phase <= Phase.FOUND:
			var alt_txt := GameManager.text("%s Alt: %s" % [GameManager.dict_text(GameManager.current_target(), "name"), _dms(target_alt_now)],
				"%s 高度：%s" % [GameManager.dict_text(GameManager.current_target(), "name"), _dms(target_alt_now)])
			_draw_tag(font, cur + Vector2(11, 4), alt_txt, WHITE_DATA, fade * fading_out)
			if target_below:
				_draw_tag(font, cur + Vector2(11, 20), GameManager.text("Below horizon", "地平线以下"), RED, fade * fading_out)

	# --- candidate sites, resolved progressively by the scan ---
	for i in range(scan_order.size()):
		var id: String = scan_order[i]
		if id == str(current_site.get("id", "")):
			continue
		var v: Dictionary = site_visibility.get(id, {})
		var s: Dictionary = v.get("site", {})
		if s.is_empty():
			continue
		var p := _project(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))
		if not MAP_AREA.has_point(p):
			continue
		var resolved := i < resolved_count
		var is_rec := id == str(recommended.get("site", {}).get("id", ""))
		var is_sel := id == selected_id
		var vis := bool(v.get("visible", false))
		var alpha := fade
		if phase >= Phase.TRAVEL and not is_sel:
			alpha *= (1.0 - travel_blend)        # others fade out while travelling
		if not resolved:
			# not yet reached by the scan: faint tick only
			overlay.draw_arc(p, 4.0, 0.0, TAU, 16, Color(SITE_DIM.r, SITE_DIM.g, SITE_DIM.b, 0.35 * alpha), 1.0)
			continue
		var color := SITE_DIM if not vis else Color(0.36, 0.60, 0.82)
		if is_rec:
			color = GOLD_BRIGHT
		_draw_marker(p, color, 6.0 if is_rec else 4.5, is_rec or is_sel, alpha)
		# brief Alt/Az preview as each candidate resolves
		if phase == Phase.SCAN and i >= resolved_count - 3:
			_draw_tag(font, p + Vector2(9, -9), "Alt %.0f°" % float(v.get("altitude", 0.0)), CYAN if vis else RED, alpha)
		elif is_rec or is_sel:
			_draw_tag(font, p + Vector2(10, -11), GameManager.dict_text(s, "name"), GOLD_BRIGHT if is_rec else CYAN, alpha)
		if is_sel and phase >= Phase.READY:
			overlay.draw_arc(p, 13.0 + sin(anim_t * 4.0) * 2.0, 0.0, TAU, 28, Color(GOLD.r, GOLD.g, GOLD.b, alpha), 2.0)


func _draw_route(font: Font, fade: float) -> void:
	if selected_id == "" or phase < Phase.ROUTE or arc_progress <= 0.0:
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	var s: Dictionary = v.get("site", {})
	if s.is_empty():
		return
	var a := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	var b := _project(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))
	var mid := (a + b) * 0.5 - Vector2(0, a.distance_to(b) * 0.34)
	var last := a
	var segments := 52
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		if t > arc_progress:
			break
		var q := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		if MAP_AREA.has_point(last) and MAP_AREA.has_point(q):
			# double-stroke: soft glow under a crisp core
			overlay.draw_line(last, q, Color(GOLD.r, GOLD.g, GOLD.b, 0.28 * fade), 5.0)
			overlay.draw_line(last, q, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.95 * fade), 1.8)
		last = q
	# travelling light head + trailing sparks
	if arc_progress < 1.0 and MAP_AREA.has_point(last):
		overlay.draw_circle(last, 4.0, GOLD_BRIGHT)
		overlay.draw_circle(last, 9.0, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.25))
		for k in range(4):
			var sp := last - (last - a).normalized() * float(k + 1) * 7.0
			if MAP_AREA.has_point(sp):
				overlay.draw_circle(sp, 1.4, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.42 - float(k) * 0.09))


func _draw_confirm_fx(font: Font) -> void:
	if phase < Phase.CONFIRM or selected_id == "":
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	var s: Dictionary = v.get("site", {})
	if s.is_empty():
		return
	var p := _project(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))
	# expanding confirmation rings at the destination
	if phase == Phase.CONFIRM:
		for i in range(3):
			var t: float = clampf(confirm_ring - float(i) * 0.18, 0.0, 1.0)
			if t <= 0.0:
				continue
			overlay.draw_arc(p, 10.0 + t * 70.0, 0.0, TAU, 40, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, (1.0 - t) * 0.8), 2.5)
	# arrival burst
	if phase >= Phase.TRAVEL and MAP_AREA.has_point(p):
		var burst: float = clampf(travel_blend, 0.0, 1.0)
		for i in range(10):
			var ang := TAU * float(i) / 10.0 + anim_t * 0.4
			var rr := 12.0 + burst * 30.0
			overlay.draw_line(p + Vector2(cos(ang), sin(ang)) * (rr - 8.0), p + Vector2(cos(ang), sin(ang)) * rr,
				Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, burst * 0.7), 2.0)
		_draw_marker(p, GOLD_BRIGHT, 8.0, true, 1.0)
	# big destination name during confirm/travel
	if phase >= Phase.CONFIRM:
		var name_alpha: float = clampf(confirm_ring * 1.4, 0.0, 1.0) * (1.0 - depart_shrink)
		var nm := GameManager.dict_text(s, "name")
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		overlay.draw_string(font, Vector2(MAP_AREA.position.x + (MAP_AREA.size.x - w) * 0.5, MAP_AREA.position.y + 44),
			nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, name_alpha))
		var sub := GameManager.text("Alt %.1f°   Az %.1f° %s   %s" % [float(v.get("altitude", 0.0)), float(v.get("azimuth", 0.0)), str(v.get("direction_text", "")), str(v.get("local_time", ""))],
			"高度 %.1f°   方位 %.1f° %s   当地 %s" % [float(v.get("altitude", 0.0)), float(v.get("azimuth", 0.0)), str(v.get("direction_text", "")), str(v.get("local_time", ""))])
		var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		overlay.draw_string(font, Vector2(MAP_AREA.position.x + (MAP_AREA.size.x - w2) * 0.5, MAP_AREA.position.y + 68),
			sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(WHITE_DATA.r, WHITE_DATA.g, WHITE_DATA.b, name_alpha))


func _draw_tag(font: Font, pos: Vector2, value: String, color: Color, alpha := 1.0) -> void:
	if alpha <= 0.02:
		return
	var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	overlay.draw_rect(Rect2(pos - Vector2(3, 11), Vector2(w + 6, 15)), Color(0.02, 0.03, 0.06, 0.7 * alpha))
	overlay.draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color.r, color.g, color.b, alpha))


func _draw_marker(p: Vector2, color: Color, r: float, pulse: bool, alpha := 1.0) -> void:
	if alpha <= 0.02:
		return
	var rr := r
	if pulse:
		rr = r + sin(anim_t * 4.0) * 1.8
		overlay.draw_circle(p, rr + 6.0, Color(color.r, color.g, color.b, 0.16 * alpha))
	overlay.draw_circle(p, rr, Color(color.r, color.g, color.b, alpha))
	overlay.draw_circle(p, rr * 0.42, Color(0.04, 0.06, 0.10, alpha))


func _dms(degrees: float) -> String:
	var sign_txt := "-" if degrees < 0.0 else ""
	var a := absf(degrees)
	var d := int(a)
	var m := int((a - float(d)) * 60.0)
	var s := int((((a - float(d)) * 60.0) - float(m)) * 60.0)
	return "%s%d° %02d' %02d\"" % [sign_txt, d, m, s]


# ------------------------------------------------------------------- panel


func _refresh_info() -> void:
	if info_panel == null:
		return
	for child in info_panel.get_children():
		child.queue_free()
	panel_rows.clear()
	var v: Dictionary = site_visibility.get(selected_id, {})
	var site: Dictionary = v.get("site", {})
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(228, 452)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(210, 0)
	body.add_theme_constant_override("separation", 3)
	scroll.add_child(body)

	_prow(body, GameManager.text("SELECTED SITE", "选中地点"), "", GOLD, 13, 0)
	if site.is_empty():
		_prow(body, GameManager.text("Scanning...", "扫描中……"), "", DIM, 12, 1)
		return
	var is_rec := str(site.get("id", "")) == str(recommended.get("site", {}).get("id", ""))
	_prow(body, GameManager.dict_text(site, "name"), "", GOLD_BRIGHT, 16, 1)
	_prow(body, GameManager.dict_text(site, "country"), "", DIM, 11, 2)
	var rows := [
		[GameManager.text("Latitude", "纬度"), "%.2f°" % float(site.get("lat", 0.0))],
		[GameManager.text("Longitude", "经度"), "%.2f°" % float(site.get("lon", 0.0))],
		[GameManager.text("Target Alt", "目标高度角"), "%.1f°" % float(v.get("altitude", 0.0))],
		[GameManager.text("Target Az", "目标方位角"), "%.1f° %s" % [float(v.get("azimuth", 0.0)), str(v.get("direction_text", ""))]],
		[GameManager.text("Local time", "当地时间"), str(v.get("local_time", "--:--"))],
		[GameManager.text("Visible for", "可见时长"), "%.1f h" % float(v.get("visible_hours", 0.0))],
		[GameManager.text("Sky quality", "天空条件"), "Bortle %d" % int(site.get("bortle", 5))],
		[GameManager.text("Conditions", "观测条件"), GameManager.dict_text(site, "condition")],
	]
	var step := 3
	for row in rows:
		_prow(body, str(row[0]), str(row[1]), TEXT, 11, step)
		step += 1
	var vis := bool(v.get("visible", false))
	_prow(body, ("★ " if is_rec else "") + (GameManager.text("Above the horizon", "在地平线以上") if vis else GameManager.text("Not visible here", "此处不可见")), "", GREEN if vis else RED, 12, step + 1)


func _prow(parent: Control, key: String, value: String, color: Color, size_px: int, order: int) -> void:
	# Staggered reveal: rows are registered and their alpha is animated in
	# _process, so the reveal actually plays instead of freezing at build time.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", size_px)
	k.add_theme_color_override("font_color", color)
	k.custom_minimum_size = Vector2(210, 0)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(k)
	if value != "":
		var val := Label.new()
		val.text = value
		val.add_theme_font_size_override("font_size", 12)
		val.add_theme_color_override("font_color", WHITE_DATA)
		val.custom_minimum_size = Vector2(210, 0)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(val)
	parent.add_child(box)
	box.modulate = Color(1, 1, 1, 0)
	panel_rows.append({"node": box, "order": order})


# ----------------------------------------------------------------- actions


func _on_confirm() -> void:
	if phase != Phase.READY:
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	if v.is_empty() or not bool(v.get("visible", false)):
		return
	InteractionFeedback.success(confirm_button, "site_confirmed")
	_set_phase(Phase.CONFIRM)


func _enter_sky() -> void:
	var v: Dictionary = site_visibility.get(selected_id, {})
	var site: Dictionary = v.get("site", {})
	if site.is_empty():
		GameManager.go("observatory")
		return
	GameManager.set_observing_location(site)
	GameManager.record_horizon_lesson_if_first()
	GameManager.go_to_observation("door")


func _on_back() -> void:
	# Never clears the target, the save, or the observing location.
	GameManager.go("observatory")


# ----------------------------------------------------------------- helpers


func _label(value: String, pos: Vector2, sz: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = sz
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _button(value: String, pos: Vector2, sz: Vector2, tint: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = sz
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = tint.darkened(0.5)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = tint.darkened(0.3)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = tint.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate()
	disabled.bg_color = Color(0.07, 0.09, 0.13)
	disabled.border_color = Color(0.28, 0.32, 0.38)
	button.add_theme_stylebox_override("disabled", disabled)
	InteractionFeedback.bind_button(button)
	return button
