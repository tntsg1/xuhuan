extends Control

# Sky Observation — three-stage observing flow.
#
#   1 Naked Eye  (120° x 70°)  scan the sky, bright objects only
#   2 Finder     (28° x 18°)   aim precisely, targets stay small dots
#   3 Telescope  (6° x 4°)     center the target, then enter Telescope View
#
# The view is a rotatable alt/az window with a graduated azimuth scale on
# top (N/E/S/W + degree numbers) and an altitude scale on the left. All
# angles display as DMS. Real positions come from SkyPositionService
# (AstronomyAPI online, local RA/Dec, or offline fallback).

const W := 1024.0
const H := 768.0
const BG_TEXTURE := "res://assets/reference/sky_observation_ui_bg_v2_1024.png"
const MODE_BUTTONS_TEXTURE := "res://assets/reference/sky_view_mode_buttons_uniform_250x76.png"
const BRIGHT_STARS_PATH := "res://data/bright_stars.json"
const SkyPositionServiceScript := preload("res://scripts/systems/sky_position_service.gd")
const ICON_DIR := "res://assets/celestial_icons/"

# Layout for the v2 mockup background: the baked crosshair + reticle ring
# are centered at (403, 383), so VIEW_RECT is symmetric around that point.
const VIEW_RECT := Rect2(88, 103, 630, 560)
const AZ_BAND := Rect2(80, 55, 630, 44)
const ALT_BAND := Rect2(38, 103, 46, 560)
const OBSERVE_RECT := Rect2(760, 570, 238, 84)
const BACK_RECT := Rect2(760, 668, 238, 72)
const MODE_BUTTONS_OVERLAY_RECT := Rect2(754, 486, 250, 76)
const MODE_RECTS := {
	"naked_eye": Rect2(756, 488, 72, 72),
	"finder": Rect2(843, 488, 72, 72),
	"telescope": Rect2(930, 488, 72, 72)
}

const PANEL_COVER := Color(0.026, 0.048, 0.080, 1.0)
const SKY_BG := Color(0.006, 0.013, 0.035, 1.0)
const BAND_BG := Color(0.020, 0.034, 0.062, 1.0)
const TEXT := Color(0.96, 0.92, 0.82)
const GOLD := Color(0.96, 0.72, 0.30)
const GREEN := Color(0.42, 0.95, 0.50)
const MUTED := Color(0.72, 0.78, 0.84)
const WARNING := Color(1.0, 0.72, 0.35)
const CROSSHAIR := Color(0.45, 0.78, 1.0, 0.30)
const FINDER_ASSIST := Color(0.45, 0.78, 1.0, 0.55)
const GROUND_COLOR := Color(0.018, 0.040, 0.026, 1.0)
const HORIZON_COLOR := Color(0.42, 0.62, 0.44, 0.75)

const AZIMUTH_SPEED := 45.0
const ALTITUDE_SPEED := 32.0
const MINIMUM_VISIBLE_ALTITUDE := 10.0
const STAR_POOL_SIZE := 320
const AZ_TICK_POOL := 64
const AZ_LABEL_POOL := 16
const ALT_TICK_POOL := 40
const ALT_LABEL_POOL := 12

const CENTER_TOLERANCE_FINDER := 2.0
const CENTER_TOLERANCE_TELESCOPE := 0.5

const CALIBRATE_STEP_DEGREES := 0.1
const CALIBRATE_REPEAT_DELAY := 0.09
const CALIBRATE_RECT := Rect2(148, 668, 460, 46)

# L16 "Narrow Field Problem": how long / how much aimless movement in the
# telescope before Maya's stronger reminder panel appears (once per visit).
const WORKFLOW_LOST_SECONDS := 45.0
const WORKFLOW_LOST_MOVES := 25

# fov_x / fov_y per view mode.
const VIEW_MODES := {
	"naked_eye": {"fov_x": 120.0, "fov_y": 70.0, "en": "Naked Eye", "zh": "肉眼"},
	"finder": {"fov_x": 28.0, "fov_y": 18.0, "en": "Finder", "zh": "寻星镜"},
	"telescope": {"fov_x": 6.0, "fov_y": 4.0, "en": "Telescope", "zh": "望远镜"}
}

# Rendered target size in pixels per mode and object category.
# Wide FOV means objects look SMALLER, not bigger; resolved detail images
# exist only in the Telescope View scene.
const RENDER_SIZES := {
	"naked_eye": {"star": 2.0, "planet": 4.0, "moon": 18.0, "deep_sky": 10.0},
	"finder": {"star": 3.0, "planet": 6.0, "moon": 34.0, "deep_sky": 18.0},
	"telescope": {"star": 2.0, "planet": 7.0, "moon": 46.0, "deep_sky": 30.0}
}

var telescope_azimuth := 180.0
var telescope_altitude := 45.0
var view_mode := "naked_eye"
var fov_x := 120.0
var fov_y := 70.0
var observation_mode := "telescope"
var selected_object_id := ""
var target_id := ""
var sky_service: RefCounted
var sky_data: Dictionary = {}
var in_view_targets: Dictionary = {}

var view_layer: Control
var az_band_layer: Control
var alt_band_layer: Control
var star_points: Array[Vector4] = []
var star_pool: Array[ColorRect] = []
var object_icons: Dictionary = {}
var object_buttons: Dictionary = {}
var selection_frame: Control
var assist_frame: Control
var ground_rect: ColorRect
var horizon_line: ColorRect
var view_mode_caption: Label
var az_ticks: Array[ColorRect] = []
var az_labels: Array[Label] = []
var alt_ticks: Array[ColorRect] = []
var alt_labels: Array[Label] = []
var az_readout: Label
var alt_readout: Label
var guidance_banner: Label
var guidance_banner_bg: ColorRect
var mode_buttons: Dictionary = {}

# --- E3 sky-realism: background lift, cloud drift, star twinkle. All
# purely visual; the star magnitude filter is the only thing that changes
# what CAN be picked, and it mirrors the aim/select logic exactly.
var sky_lift_layer: ColorRect
var cloud_layer: Control
var cloud_nodes: Array[TextureRect] = []
# Clouds are anchored to SKY coordinates (azimuth, altitude in degrees) and
# reprojected to the screen every frame - panning the telescope slides them
# together with the stars. Velocities are angular (deg/s wind).
var cloud_sky_anchors: Array[Vector2] = []
var cloud_velocities: Array[Vector2] = []
var twinkle_seed := 0.0
const SKY_CLOUD_TEXTURES := [
	"res://assets/telescope_view/cloud_wisp_a.png",
	"res://assets/telescope_view/cloud_wisp_b.png",
	"res://assets/telescope_view/cloud_wisp_c.png"
]
const SKY_CLOUD_SCALE := 1.8
const TWINKLE_STAR_COUNT := 40

var mission_tonight_label: Label
var sky_condition_label: Label
var aim_label: Label
var selected_title: Label
var selected_detail: Label
var guidance_label: Label
var visited_modes: Dictionary = {}

var calibration_panel: Control
var calibration_pct_label: Label
var calibration_hint_label: Label
var calibrate_repeat_timer := 0.0

var workflow_elapsed := 0.0
var workflow_move_count := 0
var workflow_move_tick := 0
var workflow_prompt_shown := false


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	if str(GameManager.current_level().get("variation", "")) == "finder_calibration":
		GameManager.seed_finder_offset_if_needed()
	target_id = GameManager.current_target_object_id()
	observation_mode = GameManager.current_observation_mode()
	selected_object_id = ""
	GameManager.selected_object_id = ""
	view_mode = "naked_eye"
	# Restore the aim from the previous visit instead of resetting to south.
	var saved_aim: Dictionary = GameManager.last_sky_aim
	if bool(saved_aim.get("valid", false)):
		telescope_azimuth = wrapf(float(saved_aim.get("azimuth", 180.0)), 0.0, 360.0)
		telescope_altitude = clampf(float(saved_aim.get("altitude", 45.0)), 0.0, 90.0)
		var saved_mode := str(saved_aim.get("view_mode", "naked_eye"))
		if bool(_mode_available(saved_mode).get("ok", false)):
			view_mode = saved_mode
	visited_modes[view_mode] = true
	_apply_view_mode()
	sky_service = SkyPositionServiceScript.new()
	sky_data = sky_service.get_sky_positions(VIEW_RECT)
	_ensure_target_observable()
	_load_real_star_points()
	_build()
	sky_service.request_online_planet_data(self, VIEW_RECT, _apply_online_sky_data)


func _process(delta: float) -> void:
	_handle_aim_input(delta)
	_handle_calibration_input(delta)
	_update_workflow_discipline_timer(delta)
	_advance_sky_conditions(delta)
	_advance_sky_rotation(delta)
	# Keep the big in-view banner mirroring whatever the side panel says
	# (guidance, observe errors, mode hints).
	if guidance_banner != null and guidance_label != null and guidance_banner.text != guidance_label.text:
		guidance_banner.text = guidance_label.text


# The real sky never stands still: recompute every catalog star's alt/az
# from the CURRENT clock every few seconds, so the whole star field creeps
# westward at the true sidereal rate (0.25 deg/min) on every level. Mission
# target markers stay pinned by design (they are "tracked" waypoints) - at
# x1 real rate the mismatch within a session is far below aim tolerance.
# The L22-24 eyepiece drift mechanic is separate and unchanged.
const SKY_ROTATION_REFRESH_SECONDS := 10.0
var sky_rotation_accum := 0.0


func _advance_sky_rotation(delta: float) -> void:
	sky_rotation_accum += delta
	if sky_rotation_accum < SKY_ROTATION_REFRESH_SECONDS:
		return
	sky_rotation_accum = 0.0
	_load_real_star_points()
	_rebuild_view()


func _advance_sky_conditions(delta: float) -> void:
	var clouds_active := not cloud_nodes.is_empty()
	if clouds_active:
		_advance_clouds(delta)
	if star_pool.is_empty() and object_icons.is_empty():
		return
	if not clouds_active and _seeing_severity() <= 0.0:
		return
	_apply_star_and_icon_shading(clouds_active)


func _apply_star_and_icon_shading(clouds_active: bool) -> void:
	# Single per-frame pass: brightest ~40 visible stars twinkle (alpha
	# double-sine, amplitude by seeing severity); every visible star and
	# object icon darkens under whatever cloud currently covers it. Purely
	# visual - never touches aim/identification logic.
	var severity := _seeing_severity()
	var t := Time.get_ticks_msec() / 1000.0
	var twinkle_budget := TWINKLE_STAR_COUNT
	for i in range(star_pool.size()):
		var star := star_pool[i]
		if not star.visible:
			continue
		var base_color: Color = star.get_meta("base_color", star.color)
		var shading := 1.0
		if clouds_active:
			shading = 1.0 - 0.75 * _cloud_alpha_at(star.position + star.size * 0.5)
		var twinkle := 1.0
		if severity > 0.0 and twinkle_budget > 0:
			twinkle_budget -= 1
			var phase: float = twinkle_seed + float(i) * 0.7
			twinkle = 1.0 + 0.125 * (severity / 0.8) * sin(t * (2.0 + severity * 2.5) + phase)
		star.color = Color(base_color.r, base_color.g, base_color.b, clampf(base_color.a * twinkle * shading, 0.0, 1.0))
	if not clouds_active:
		return
	for id_value in object_icons.keys():
		var object_id: String = str(id_value)
		var icon: TextureRect = object_icons[object_id]
		if not icon.visible:
			continue
		var base_alpha: float = float(icon.get_meta("base_alpha", icon.modulate.a))
		var local_pos: Vector2 = icon.position + icon.size * icon.scale * 0.5
		var shading := 1.0 - 0.75 * _cloud_alpha_at(local_pos)
		icon.modulate.a = clampf(base_alpha * shading, 0.0, 1.0)


func _exit_tree() -> void:
	# Remember where the telescope was pointing for the next visit.
	GameManager.last_sky_aim = {
		"valid": true,
		"azimuth": telescope_azimuth,
		"altitude": telescope_altitude,
		"view_mode": view_mode
	}


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				_set_view_mode("naked_eye")
			KEY_2:
				_set_view_mode("finder")
			KEY_3:
				_set_view_mode("telescope")


func _handle_aim_input(delta: float) -> void:
	# Narrow views turn slowly for fine aiming.
	var speed_scale := clampf(fov_x / 90.0, 0.10, 1.0)
	var azimuth_speed := AZIMUTH_SPEED * speed_scale
	var altitude_speed := ALTITUDE_SPEED * speed_scale
	if Input.is_action_pressed("dodge") or Input.is_key_pressed(KEY_SHIFT):
		azimuth_speed *= 2.0
		altitude_speed *= 2.0

	var azimuth_dir := 0.0
	var altitude_dir := 0.0
	if Input.is_action_pressed("move_left"):
		azimuth_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		azimuth_dir += 1.0
	if Input.is_action_pressed("move_up"):
		altitude_dir += 1.0
	if Input.is_action_pressed("move_down"):
		altitude_dir -= 1.0
	if azimuth_dir == 0.0 and altitude_dir == 0.0:
		return

	telescope_azimuth = wrapf(telescope_azimuth + azimuth_dir * azimuth_speed * delta, 0.0, 360.0)
	telescope_altitude = clampf(telescope_altitude + altitude_dir * altitude_speed * delta, 0.0, 90.0)
	_count_workflow_move()
	_rebuild_view()


func _count_workflow_move() -> void:
	# One "move" per ~0.15s of active steering, so holding a key doesn't
	# spam thousands of counts per second - used by L16's lost-in-6-degrees
	# detection (see _update_workflow_discipline_timer).
	if str(GameManager.current_level().get("variation", "")) != "workflow_discipline":
		return
	if view_mode != "telescope":
		return
	workflow_move_tick += 1
	if workflow_move_tick >= 9:
		workflow_move_tick = 0
		workflow_move_count += 1


# ------------------------------------------------------------ view modes


func _is_finder_calibration_level() -> bool:
	return str(GameManager.current_level().get("variation", "")) == "finder_calibration"


func _handle_calibration_input(delta: float) -> void:
	if not _is_finder_calibration_level() or view_mode != "finder" or GameManager.is_finder_aligned():
		if calibration_panel != null:
			calibration_panel.visible = _is_finder_calibration_level() and view_mode == "finder"
		return
	if calibration_panel != null:
		calibration_panel.visible = true
	calibrate_repeat_timer -= delta
	var delta_az := 0.0
	var delta_alt := 0.0
	if Input.is_key_pressed(KEY_J):
		delta_az -= CALIBRATE_STEP_DEGREES
	if Input.is_key_pressed(KEY_L):
		delta_az += CALIBRATE_STEP_DEGREES
	if Input.is_key_pressed(KEY_I):
		delta_alt += CALIBRATE_STEP_DEGREES
	if Input.is_key_pressed(KEY_K):
		delta_alt -= CALIBRATE_STEP_DEGREES
	if delta_az == 0.0 and delta_alt == 0.0:
		return
	if calibrate_repeat_timer > 0.0:
		return
	calibrate_repeat_timer = CALIBRATE_REPEAT_DELAY
	# adjust_finder_offset REDUCES the misalignment: the offset represents
	# how far off the finder is, so nudging "toward true" subtracts from it.
	GameManager.adjust_finder_offset(-delta_az, -delta_alt)
	_update_calibration_panel()
	_rebuild_view()


func _update_calibration_panel() -> void:
	if calibration_pct_label == null:
		return
	var aligned := GameManager.is_finder_aligned()
	var pct := GameManager.finder_alignment_percent()
	if aligned:
		calibration_pct_label.text = GameManager.text("Aligned!", "校准完成！")
		calibration_pct_label.add_theme_color_override("font_color", GREEN)
		calibration_hint_label.text = GameManager.text("Finder now matches the telescope.", "寻星镜现在与主镜一致了。")
	else:
		# Single-line inline bilingual (GameManager.text stacks EN+ZH and
		# overflows this 46px panel) + a live signed readout so the player
		# always knows WHICH key moves toward zero.
		var offset: Dictionary = GameManager.finder_offset()
		var az := float(offset.get("az", 0.0))
		var alt := float(offset.get("alt", 0.0))
		calibration_pct_label.text = "Finder校准 %d%%   Δaz %+.1f°  Δalt %+.1f°" % [int(pct), az, alt]
		calibration_pct_label.add_theme_color_override("font_color", WARNING)
		var keys: Array[String] = []
		if absf(az) > 0.05:
			keys.append("L→" if az > 0.0 else "J←")
		if absf(alt) > 0.05:
			keys.append("I↑" if alt > 0.0 else "K↓")
		var key_hint := " ".join(keys) if not keys.is_empty() else "IJKL"
		calibration_hint_label.text = "Press按 %s 调向 0" % key_hint


func _mode_available(mode: String) -> Dictionary:
	if mode == "naked_eye":
		return {"ok": true}
	if not GameManager.current_requires_telescope():
		return {
			"ok": false,
			"en": "Tonight is a naked eye session.",
			"zh": "今晚是肉眼观测环节。"
		}
	if mode == "finder" and not _finder_installed():
		return {
			"ok": false,
			"en": "No finder scope installed yet.",
			"zh": "还没有安装寻星镜。"
		}
	if mode == "telescope" and not GameManager.telescope_is_ready():
		return {
			"ok": false,
			"en": "The telescope is not assembled yet.",
			"zh": "望远镜还没有组装完成。"
		}
	if mode == "telescope" and _is_finder_calibration_level() and not GameManager.is_finder_aligned():
		return {
			"ok": false,
			"en": "Calibrate the finder scope first (switch to Finder, use IJKL).",
			"zh": "请先校准寻星镜（切换到寻星镜视角，用 IJKL 微调）。"
		}
	return {"ok": true}


func _set_view_mode(mode: String) -> void:
	if mode == view_mode:
		return
	var check := _mode_available(mode)
	if not bool(check.get("ok", false)):
		if guidance_label != null:
			guidance_label.text = GameManager.text(str(check.get("en", "")), str(check.get("zh", "")))
		return
	view_mode = mode
	visited_modes[view_mode] = true
	_apply_view_mode()
	_update_mode_buttons()
	if cloud_layer != null:
		# Cloud screen-size/speed scale with FOV, so switching views rebuilds
		# them; the underlying cloud_cover amount is unchanged.
		for cloud in cloud_nodes:
			cloud.queue_free()
		_build_cloud_layer()
	_rebuild_view()


func _apply_view_mode() -> void:
	var config: Dictionary = VIEW_MODES[view_mode]
	fov_x = float(config.get("fov_x", 120.0))
	fov_y = float(config.get("fov_y", 70.0))


func _mode_label(mode: String) -> String:
	var config: Dictionary = VIEW_MODES[mode]
	return GameManager.text(str(config.get("en", mode)), str(config.get("zh", mode)))


func _center_tolerance() -> float:
	if view_mode == "telescope":
		return CENTER_TOLERANCE_TELESCOPE
	return CENTER_TOLERANCE_FINDER


# ------------------------------------------------------------- data


func _apply_online_sky_data(online_data: Dictionary) -> void:
	for object_id_value in online_data.keys():
		var object_id: String = str(object_id_value)
		sky_data[object_id] = online_data[object_id]
	_ensure_target_observable()
	_update_mission_tonight_text()
	_update_selected_text()
	_rebuild_view()


func _ensure_target_observable() -> void:
	# Keep every level completable: if tonight's real position of the mission
	# target is below the visible horizon, move it to a simulated observable
	# spot and mark the data as a fallback estimate.
	if not sky_data.has(target_id):
		return
	var item: Dictionary = sky_data[target_id]
	var seed_value: int = absi(target_id.hash())
	var altitude_bias := _target_altitude_bias()
	if altitude_bias == "low":
		# The mission deliberately wants a low-altitude target (seeing lesson):
		# pin it into a 12-18 deg band regardless of tonight's real position.
		var azimuth: float = float(item.get("azimuth", 0.0))
		if azimuth <= 0.001:
			azimuth = 120.0 + float(seed_value % 140)
		item["altitude"] = 12.0 + float(seed_value % 7)
		item["azimuth"] = azimuth
		item["visible"] = true
		item["visibility_text"] = "Offline estimate"
		item["direction_text"] = _direction_text_for_azimuth(azimuth)
		item["source"] = "fallback"
		sky_data[target_id] = item
		return
	if float(item.get("altitude", 0.0)) >= MINIMUM_VISIBLE_ALTITUDE:
		return
	var azimuth: float = float(item.get("azimuth", 0.0))
	if azimuth <= 0.001:
		azimuth = 120.0 + float(seed_value % 140)
	item["altitude"] = 32.0 + float(seed_value % 26)
	item["azimuth"] = azimuth
	item["visible"] = true
	item["visibility_text"] = "Offline estimate"
	item["direction_text"] = _direction_text_for_azimuth(azimuth)
	item["source"] = "fallback"
	sky_data[target_id] = item


func _target_altitude_bias() -> String:
	var level := GameManager.current_level()
	var environment: Dictionary = level.get("environment", {})
	return str(environment.get("target_altitude_bias", ""))


# ------------------------------------------------------ E3 sky conditions


func _sky_brightness_key() -> String:
	# No environment on the level at all = every legacy/no-environment level
	# (L1-L9, most of L10-24) behaves exactly as before: full star field, no
	# lift, no filtering.
	var environment := GameManager.current_environment()
	if environment.is_empty():
		return ""
	return str(environment.get("sky_brightness", "")).to_lower()


func _cloud_cover_amount() -> float:
	var environment := GameManager.current_environment()
	if environment.is_empty():
		return 0.0
	return clampf(float(environment.get("cloud_cover", 0.0)), 0.0, 1.0)


func _seeing_severity() -> float:
	var environment := GameManager.current_environment()
	if environment.is_empty():
		return 0.06
	match str(environment.get("seeing", "")).capitalize():
		"Poor":
			return 0.8
		"Average":
			return 0.35
	return 0.06


func _magnitude_limit() -> float:
	# Star-catalog visibility ceiling by sky brightness. No environment
	# (empty key) keeps every star, matching pre-E3 behavior exactly.
	match _sky_brightness_key():
		"city":
			return 3.6
		"suburban":
			return 4.5
	return 99.0


func _deep_sky_city_dim() -> float:
	# Deep-sky (faint, low-contrast) targets take the biggest hit under
	# city glow - matches the telescope-view E1 rule.
	if _sky_brightness_key() == "city":
		return 0.6
	return 1.0


func _sky_lift_color() -> Color:
	match _sky_brightness_key():
		"city":
			return Color(0.030, 0.034, 0.050, 1.0)
		"suburban":
			return Color(0.015, 0.017, 0.025, 1.0)
	return Color(0.0, 0.0, 0.0, 0.0)


func _build_cloud_layer() -> void:
	cloud_nodes.clear()
	cloud_velocities.clear()
	cloud_sky_anchors.clear()
	twinkle_seed = fmod(float(absi(target_id.hash())), 1000.0)
	var cover := _cloud_cover_amount()
	if cover <= 0.0:
		return
	var tier := 1
	if cover >= 0.67:
		tier = 3
	elif cover >= 0.34:
		tier = 2
	var alpha_for_tier := 0.28
	match tier:
		2:
			alpha_for_tier = 0.5
		3:
			alpha_for_tier = 0.75
	var count: int = clampi(1 + tier, 2, 5)
	for i in range(count):
		var tex_path: String = SKY_CLOUD_TEXTURES[i % SKY_CLOUD_TEXTURES.size()]
		if not ResourceLoader.exists(tex_path):
			continue
		var texture: Texture2D = load(tex_path)
		var cloud := TextureRect.new()
		cloud.texture = texture
		cloud.stretch_mode = TextureRect.STRETCH_KEEP
		# Soft wisp art, not pixel art - linear filtering keeps it a smooth
		# haze instead of blocky mush when scaled up for narrow FOVs.
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Narrower FOV = the same physical cloud fills more of the frame, but
		# capped gently so it never balloons past a soft haze over the view.
		var fov_scale := clampf(sqrt(60.0 / fov_x), 1.0, 2.2)
		cloud.scale = Vector2.ONE * SKY_CLOUD_SCALE * fov_scale
		cloud.size = texture.get_size()
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.modulate = Color(1, 1, 1, alpha_for_tier)
		# Sky-anchored spawn: scatter around the current aim in DEGREES.
		var seed_angle: float = fmod(float(i) * 137.5 + twinkle_seed, 360.0) * PI / 180.0
		var offset_az: float = cos(seed_angle) * fov_x * (0.20 + 0.12 * float(i))
		var offset_alt: float = sin(seed_angle) * 0.4 * fov_y * (0.20 + 0.12 * float(i))
		var anchor := Vector2(
			wrapf(telescope_azimuth + offset_az, 0.0, 360.0),
			clampf(telescope_altitude + offset_alt, 4.0, 86.0)
		)
		cloud_sky_anchors.append(anchor)
		# Angular wind (deg/s): same real speed in every mode - narrow FOV
		# crossings automatically look faster on screen, which is physical.
		var wind_az: float = (1.2 + fmod(float(i) * 0.7, 1.4)) * (1.0 if i % 2 == 0 else -1.0)
		var wind_alt: float = 0.05 + fmod(float(i), 3.0) * 0.03
		cloud_velocities.append(Vector2(wind_az, wind_alt))
		cloud_layer.add_child(cloud)
		cloud_nodes.append(cloud)
		_position_cloud(i)


func _advance_clouds(delta: float) -> void:
	if cloud_nodes.is_empty():
		return
	for i in range(cloud_nodes.size()):
		# Wind moves the anchor through the SKY; the screen position below
		# also re-reads the current aim, so panning slides clouds together
		# with the stars (they are part of the sky, not the UI).
		var anchor := cloud_sky_anchors[i]
		anchor.x = wrapf(anchor.x + cloud_velocities[i].x * delta, 0.0, 360.0)
		anchor.y = clampf(anchor.y + cloud_velocities[i].y * delta, 4.0, 86.0)
		# Recycle once the cloud has fully left the field: re-enter from the
		# opposite side of the CURRENT aim, slightly upwind.
		var d_az := shortest_angle_degrees(telescope_azimuth, anchor.x)
		var d_alt := anchor.y - telescope_altitude
		if absf(d_az) > fov_x * 0.95:
			anchor.x = wrapf(telescope_azimuth - signf(d_az) * fov_x * 0.9, 0.0, 360.0)
		if absf(d_alt) > fov_y * 0.95:
			anchor.y = clampf(telescope_altitude - signf(d_alt) * fov_y * 0.9, 4.0, 86.0)
		cloud_sky_anchors[i] = anchor
		_position_cloud(i)


func _position_cloud(index: int) -> void:
	var cloud := cloud_nodes[index]
	var anchor := cloud_sky_anchors[index]
	var d_az := shortest_angle_degrees(telescope_azimuth, anchor.x)
	var d_alt := anchor.y - telescope_altitude
	cloud.position = _fov_to_local(d_az, d_alt) - cloud.size * cloud.scale * 0.5


func _cloud_alpha_at(local_pos: Vector2) -> float:
	# How much a cloud dims a given point in the view (0 = clear, 1 = fully
	# obscured). Purely visual - never touches identification/aim logic.
	if cloud_nodes.is_empty():
		return 0.0
	var total := 0.0
	for cloud in cloud_nodes:
		var effective_size: Vector2 = cloud.size * cloud.scale
		var cloud_center: Vector2 = cloud.position + effective_size * 0.5
		var radius: float = maxf(effective_size.x, effective_size.y) * 0.5
		var d := cloud_center.distance_to(local_pos)
		var falloff := clampf(1.0 - d / maxf(radius, 1.0), 0.0, 1.0)
		total += falloff * cloud.modulate.a
	return clampf(total, 0.0, 1.0)


func _load_real_star_points() -> void:
	# Real night sky: HYG bright-star catalog converted to tonight's alt/az.
	star_points.clear()
	var config: Dictionary = sky_service.load_config()
	var latitude: float = float(config.get("default_latitude", 34.0522))
	var longitude: float = float(config.get("default_longitude", -118.2437))
	var utc_now: Dictionary = Time.get_datetime_dict_from_system(true)

	var file := FileAccess.open(BRIGHT_STARS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var stars: Array = data.get("stars", [])
	for star_value in stars:
		if not star_value is Array:
			continue
		var star: Array = star_value
		if star.size() < 3:
			continue
		var alt_az: Dictionary = sky_service.calculate_alt_az_from_ra_dec(
			float(star[0]), float(star[1]), latitude, longitude, utc_now
		)
		var altitude: float = float(alt_az.get("altitude", -90.0))
		if altitude <= 0.0:
			continue
		var magnitude: float = float(star[2])
		if magnitude > _magnitude_limit():
			continue
		var size := 1.0
		if magnitude <= 1.0:
			size = 3.0
		elif magnitude <= 3.0:
			size = 2.0
		var brightness := clampf(1.0 - magnitude * 0.13, 0.42, 0.98)
		star_points.append(Vector4(float(alt_az.get("azimuth", 0.0)), altitude, size, brightness))


# ------------------------------------------------------------------ helpers


func shortest_angle_degrees(from_deg: float, to_deg: float) -> float:
	var diff := fmod((to_deg - from_deg + 540.0), 360.0) - 180.0
	return diff


func _direction_text_for_azimuth(azimuth: float) -> String:
	var directions: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index: int = int(floor((wrapf(azimuth, 0.0, 360.0) + 22.5) / 45.0)) % directions.size()
	return directions[index]


func _format_dms(value: float, signed: bool = false) -> String:
	var sign := ""
	var amount := value
	if signed and value < 0.0:
		sign = "-"
		amount = -value
	elif signed and value > 0.0:
		sign = "+"
	amount = absf(amount)
	var degrees := int(floor(amount))
	var minutes_float := (amount - float(degrees)) * 60.0
	var minutes := int(floor(minutes_float))
	var seconds := int(round((minutes_float - float(minutes)) * 60.0))
	if seconds >= 60:
		seconds -= 60
		minutes += 1
	if minutes >= 60:
		minutes -= 60
		degrees += 1
	return "%s%d°%02d'%02d\"" % [sign, degrees, minutes, seconds]


func _icon_path_for_object(object_id: String) -> String:
	return ICON_DIR + object_id + ".png"


# ---------------------------------------------------------------- build


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_background()
	_cover_baked_text()
	_build_scale_bands()
	_build_view_layer()
	_build_panel_text()
	_build_mode_buttons()
	_build_calibration_panel()
	_draw_action_hitboxes()
	_update_mode_buttons()
	_rebuild_view()


func _build_calibration_panel() -> void:
	if not _is_finder_calibration_level():
		return
	calibration_panel = Control.new()
	calibration_panel.position = CALIBRATE_RECT.position
	calibration_panel.size = CALIBRATE_RECT.size
	calibration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calibration_panel.visible = false
	add_child(calibration_panel)
	_rect(calibration_panel, Vector2.ZERO, CALIBRATE_RECT.size, Color(0.02, 0.03, 0.05, 0.72))
	calibration_pct_label = _label(calibration_panel, "", Vector2(10, 4), Vector2(CALIBRATE_RECT.size.x - 20, 20), 13, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
	calibration_hint_label = _label(calibration_panel, GameManager.text("IJKL to adjust", "IJKL 微调"), Vector2(10, 24), Vector2(CALIBRATE_RECT.size.x - 20, 18), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_update_calibration_panel()


func _draw_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.position = Vector2.ZERO
	bg.size = Vector2(W, H)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _load_png_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("Could not load sky observation texture: " + path)
		return null
	return ImageTexture.create_from_image(image)


func _build_scale_bands() -> void:
	# Azimuth band (top): 0-360 with N/E/S/W, numbered majors. The v2
	# background supplies the framing, we only draw ticks and numbers.
	_rect(self, AZ_BAND.position + Vector2(0, AZ_BAND.size.y - 2), Vector2(AZ_BAND.size.x, 1), Color(GOLD.r, GOLD.g, GOLD.b, 0.45))
	az_band_layer = Control.new()
	az_band_layer.position = AZ_BAND.position
	az_band_layer.size = AZ_BAND.size
	az_band_layer.clip_contents = true
	az_band_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(az_band_layer)
	for index in range(AZ_TICK_POOL):
		var tick := ColorRect.new()
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		az_band_layer.add_child(tick)
		az_ticks.append(tick)
	for index in range(AZ_LABEL_POOL):
		var label := _label(az_band_layer, "", Vector2.ZERO, Vector2(64, 16), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		label.visible = false
		az_labels.append(label)
	# fixed center pointer
	_rect(self, Vector2(AZ_BAND.position.x + AZ_BAND.size.x * 0.5 - 1, AZ_BAND.position.y), Vector2(2, AZ_BAND.size.y), Color(GOLD.r, GOLD.g, GOLD.b, 0.9))

	# Altitude band (left): 0 horizon .. 90 zenith.
	_rect(self, ALT_BAND.position + Vector2(ALT_BAND.size.x - 2, 0), Vector2(1, ALT_BAND.size.y), Color(GOLD.r, GOLD.g, GOLD.b, 0.45))
	alt_band_layer = Control.new()
	alt_band_layer.position = ALT_BAND.position
	alt_band_layer.size = ALT_BAND.size
	alt_band_layer.clip_contents = true
	alt_band_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alt_band_layer)
	for index in range(ALT_TICK_POOL):
		var tick := ColorRect.new()
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alt_band_layer.add_child(tick)
		alt_ticks.append(tick)
	for index in range(ALT_LABEL_POOL):
		var label := _label(alt_band_layer, "", Vector2.ZERO, Vector2(30, 14), 9, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		label.visible = false
		alt_labels.append(label)
	# Center pointer: small gold triangle at the current-altitude line.
	_rect(self, Vector2(ALT_BAND.position.x + ALT_BAND.size.x - 10, ALT_BAND.position.y + ALT_BAND.size.y * 0.5 - 5), Vector2(4, 10), Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
	_rect(self, Vector2(ALT_BAND.position.x + ALT_BAND.size.x - 6, ALT_BAND.position.y + ALT_BAND.size.y * 0.5 - 3), Vector2(3, 6), Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
	_rect(self, Vector2(ALT_BAND.position.x + ALT_BAND.size.x - 3, ALT_BAND.position.y + ALT_BAND.size.y * 0.5 - 1), Vector2(3, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.9))


func _build_view_layer() -> void:
	view_layer = Control.new()
	view_layer.position = VIEW_RECT.position
	view_layer.size = VIEW_RECT.size
	view_layer.clip_contents = true
	add_child(view_layer)

	# Sky brightness lift: a flat tint under everything else, strictly
	# clipped to the view rect by the parent's clip_contents (city/suburban
	# only; empty environment = fully transparent = zero visual change).
	sky_lift_layer = _rect(view_layer, Vector2.ZERO, VIEW_RECT.size, _sky_lift_color())
	sky_lift_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for index in range(STAR_POOL_SIZE):
		var star := ColorRect.new()
		star.visible = false
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view_layer.add_child(star)
		star_pool.append(star)

	# Ground band + horizon line, shown when aiming low.
	ground_rect = _rect(view_layer, Vector2.ZERO, Vector2.ZERO, GROUND_COLOR)
	ground_rect.visible = false
	horizon_line = _rect(view_layer, Vector2.ZERO, Vector2.ZERO, HORIZON_COLOR)
	horizon_line.visible = false

	# Cloud layer: above the star field, below the object icons/crosshair/UI.
	cloud_layer = Control.new()
	cloud_layer.size = VIEW_RECT.size
	cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_layer.add_child(cloud_layer)
	_build_cloud_layer()

	for id_value in sky_data.keys():
		var object_id: String = str(id_value)
		var icon_path := _icon_path_for_object(object_id)
		if not ResourceLoader.exists(icon_path):
			continue
		var texture: Texture2D = load(icon_path)
		var icon := TextureRect.new()
		icon.texture = texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size = texture.get_size()
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view_layer.add_child(icon)
		object_icons[object_id] = icon

		var button := _transparent_button(Rect2(Vector2.ZERO, texture.get_size()), GameManager.dict_text(GameManager.get_object(object_id), "name"))
		button.visible = false
		var captured_id := object_id
		button.pressed.connect(func() -> void: _select_object(captured_id))
		view_layer.add_child(button)
		object_buttons[object_id] = button

	# DMS readouts on the center lines (the crosshair + reticle ring are
	# baked into the v2 background, centered on this view).
	az_readout = _label(view_layer, "", Vector2(VIEW_RECT.size.x * 0.5 - 110, 6), Vector2(220, 22), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	alt_readout = _label(view_layer, "", Vector2(10, VIEW_RECT.size.y * 0.5 - 28), Vector2(180, 22), 14, GOLD)

	# Big in-view guidance banner: turn/raise instructions must be readable
	# at a glance, not tucked into the side panel in tiny type.
	guidance_banner_bg = _rect(view_layer, Vector2(0, VIEW_RECT.size.y - 96), Vector2(VIEW_RECT.size.x, 58), Color(0, 0, 0, 0.48))
	guidance_banner = _label(view_layer, "", Vector2(12, VIEW_RECT.size.y - 92), Vector2(VIEW_RECT.size.x - 24, 52), 15, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	guidance_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_banner.max_lines_visible = 2

	# Controls hint, small and unobtrusive above the bottom frame.
	var help := _label(
		view_layer,
		GameManager.text(
			"A/D az · W/S alt · 1/2/3 view mode · Shift fast",
			"A/D 方位 · W/S 俯仰 · 1/2/3 视角 · Shift 加速"
		),
		Vector2(0, VIEW_RECT.size.y - 34),
		Vector2(VIEW_RECT.size.x, 28),
		9,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate.a = 0.6


func _build_mode_buttons() -> void:
	# Cover the baked EYE / FINDER / SCOPE art with one uniform source image
	# so switching modes never gives the three buttons mismatched colors.
	var button_art := TextureRect.new()
	button_art.texture = _load_png_texture(MODE_BUTTONS_TEXTURE)
	button_art.position = MODE_BUTTONS_OVERLAY_RECT.position
	button_art.size = MODE_BUTTONS_OVERLAY_RECT.size
	button_art.clip_contents = true
	button_art.ignore_texture_size = true
	button_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	button_art.stretch_mode = TextureRect.STRETCH_SCALE
	button_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button_art)

	view_mode_caption = _label(self, "", Vector2(288, 708), Vector2(230, 20), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	for mode_value in MODE_RECTS.keys():
		var mode: String = str(mode_value)
		var rect: Rect2 = MODE_RECTS[mode]
		var shade := _rect(self, rect.position, rect.size, Color(0.01, 0.03, 0.07, 0.0))
		var frame := _make_frame(self, rect.grow(2.0), GOLD, 2)
		frame.visible = false
		var hot := _transparent_button(rect, _mode_label(mode))
		var captured := mode
		hot.pressed.connect(func() -> void: _set_view_mode(captured))
		add_child(hot)
		mode_buttons[mode] = {"shade": shade, "frame": frame}


func _update_mode_buttons() -> void:
	for mode_value in mode_buttons.keys():
		var mode: String = str(mode_value)
		var parts: Dictionary = mode_buttons[mode]
		var shade: ColorRect = parts.get("shade")
		var frame: Control = parts.get("frame")
		var active := mode == view_mode
		frame.visible = active
		shade.color = Color(0.01, 0.03, 0.07, 0.0)
	if view_mode_caption != null:
		var captions := {"naked_eye": "EYE VIEW", "finder": "FINDER VIEW", "telescope": "SCOPE VIEW"}
		view_mode_caption.text = "·  %s  ·" % str(captions.get(view_mode, "VIEW"))


func _cover_baked_text() -> void:
	# The v2 background bakes in static scale numbers, a sample galaxy at
	# the reticle center and a "SCOPE VIEW" caption - hide those so the
	# dynamic versions can take over. Background there is pure black.
	_rect(self, AZ_BAND.position, AZ_BAND.size, Color.BLACK)
	_rect(self, ALT_BAND.position, ALT_BAND.size, Color.BLACK)
	_rect(self, Vector2(386, 364), Vector2(48, 36), Color.BLACK)
	_rect(self, Vector2(326, 706), Vector2(170, 26), Color.BLACK)


func _build_panel_text() -> void:
	# MISSION panel interior: (775..995, 75..228) on the v2 background.
	var target: Dictionary = GameManager.get_object(target_id)

	_label(self, "Target:", Vector2(778, 80), Vector2(70, 22), 14, WARNING)
	_label(self, str(target.get("name_en", target_id)), Vector2(848, 80), Vector2(140, 22), 14, Color(0.84, 0.62, 1.0))

	var hint_label := _label(self, _mission_hint(target), Vector2(778, 108), Vector2(210, 62), 11, TEXT)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_tonight_label = _label(self, "", Vector2(778, 194), Vector2(212, 14), 10, MUTED)
	_update_mission_tonight_text()
	sky_condition_label = _label(self, "", Vector2(778, 210), Vector2(212, 14), 9, MUTED)
	_update_sky_condition_text()

	# SELECTED panel interior: (775..995, 292..470); baked divider at y 432.
	selected_title = _label(self, "", Vector2(778, 292), Vector2(214, 18), 12, Color(0.84, 0.62, 1.0))
	selected_title.clip_text = true
	selected_detail = _label(self, "", Vector2(778, 312), Vector2(214, 54), 9, TEXT)
	selected_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_detail.max_lines_visible = 4

	aim_label = _label(self, "", Vector2(778, 372), Vector2(214, 50), 9, TEXT)
	aim_label.max_lines_visible = 4

	guidance_label = _label(self, "", Vector2(778, 438), Vector2(214, 30), 9, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_label.max_lines_visible = 2

	_update_selected_text()


func _mission_hint(target: Dictionary) -> String:
	match str(target.get("id", "")):
		"moon":
			return GameManager.text("Look for the brightest round object.", "寻找最亮的圆形目标。")
		"polaris":
			return GameManager.text("Look toward the northern sky.", "望向北方天空。")
		"sirius":
			return GameManager.text("Find a bright blue-white star.", "寻找明亮的蓝白色恒星。")
		"betelgeuse":
			return GameManager.text("Find a reddish star in Orion.", "寻找猎户座方向偏红的恒星。")
		"mars":
			return GameManager.text("Find a reddish planet.", "寻找偏红的行星。")
		"jupiter":
			return GameManager.text("Find the large striped planet.", "寻找带条纹的大行星。")
		"orion_nebula":
			return GameManager.text("Find the purple cloud near Orion.", "寻找猎户座附近的紫色云雾。")
		"andromeda":
			return GameManager.text("Find a faint oval galaxy.", "寻找暗淡的椭圆形星系。")
	return str(GameManager.current_level().get("hint_text_en", "Rotate the view to find the mission target."))


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


# ------------------------------------------------------------ view refresh


func _fov_to_local(delta_az: float, delta_alt: float) -> Vector2:
	return Vector2(
		VIEW_RECT.size.x * 0.5 + (delta_az / (fov_x * 0.5)) * (VIEW_RECT.size.x * 0.48),
		VIEW_RECT.size.y * 0.5 - (delta_alt / (fov_y * 0.5)) * (VIEW_RECT.size.y * 0.48)
	)


func _object_category(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	if id == "moon":
		return "moon"
	var type_lower := str(obj.get("type_en", "")).to_lower()
	if type_lower.contains("nebula") or type_lower.contains("galaxy"):
		return "deep_sky"
	if type_lower.contains("planet"):
		return "planet"
	return "star"


func _object_visual_for_mode(obj: Dictionary) -> Dictionary:
	# How an object appears in the CURRENT view mode. Detail images belong
	# to the Telescope View only; here everything is a finding mark whose
	# rendered pixel size comes from RENDER_SIZES (mode x category).
	var magnitude: float = float(obj.get("apparent_magnitude", 6.0))
	var category := _object_category(obj)
	var sizes: Dictionary = RENDER_SIZES[view_mode]
	var size_px: float = float(sizes.get(category, 2.0))
	var alpha := 1.0
	var shown := true
	match view_mode:
		"naked_eye":
			if magnitude > 7.5:
				shown = false
			elif category == "deep_sky" or magnitude > 5.5:
				alpha = 0.14  # unknown faint smudge
			elif category == "star" and magnitude > 0.0:
				size_px = 1.0  # only the brightest stars reach 2 px
		"finder":
			if magnitude > 9.0:
				shown = false
			elif category == "deep_sky":
				alpha = 0.5  # still a blur, no structure
			elif category == "star" and magnitude > 0.0:
				size_px = 2.0
		"telescope":
			alpha = 0.9
			if category == "deep_sky":
				alpha = 0.6
	if category == "deep_sky":
		alpha *= _deep_sky_city_dim()
	return {"shown": shown, "alpha": alpha, "size_px": size_px}


func _rebuild_view() -> void:
	in_view_targets.clear()
	var half_x := fov_x * 0.5
	var half_y := fov_y * 0.5
	var offset_az := 0.0
	var offset_alt := 0.0
	if view_mode == "finder":
		# The finder crosshair itself does not move, but everything it shows
		# is displaced by the (uncalibrated) mechanical misalignment: what
		# looks centered in the finder may not really be centered.
		var offset: Dictionary = GameManager.finder_offset()
		offset_az = float(offset.get("az", 0.0))
		offset_alt = float(offset.get("alt", 0.0))

	var pool_index := 0
	for point in star_points:
		var star_delta_az := shortest_angle_degrees(telescope_azimuth, point.x) + offset_az
		var star_delta_alt := point.y - telescope_altitude + offset_alt
		if absf(star_delta_az) > half_x or absf(star_delta_alt) > half_y:
			continue
		if pool_index >= star_pool.size():
			break
		var star := star_pool[pool_index]
		pool_index += 1
		var star_pos := _fov_to_local(star_delta_az, star_delta_alt)
		star.position = star_pos - Vector2(point.z, point.z) * 0.5
		star.size = Vector2(point.z, point.z)
		var base_color := Color(point.w, point.w, minf(point.w + 0.08, 1.0), 0.85)
		star.set_meta("base_color", base_color)
		star.color = base_color
		star.visible = true
	for index in range(pool_index, star_pool.size()):
		star_pool[index].visible = false

	for id_value in sky_data.keys():
		var object_id: String = str(id_value)
		if not object_icons.has(object_id):
			continue
		var icon: TextureRect = object_icons[object_id]
		var button: Button = object_buttons[object_id]
		var item: Dictionary = sky_data[object_id]
		var obj: Dictionary = GameManager.get_object(object_id)
		var altitude: float = float(item.get("altitude", 0.0))
		var delta_az := shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0))) + offset_az
		var delta_alt := altitude - telescope_altitude + offset_alt
		var visual := _object_visual_for_mode(obj)
		var in_view: bool = altitude > 0.0 and absf(delta_az) <= half_x and absf(delta_alt) <= half_y and bool(visual.get("shown", true))
		icon.visible = in_view
		button.visible = in_view
		if not in_view:
			continue
		var texture_size: Vector2 = icon.texture.get_size()
		var icon_scale: float = float(visual.get("size_px", 2.0)) / maxf(texture_size.x, texture_size.y)
		icon.scale = Vector2.ONE * icon_scale
		var icon_size: Vector2 = texture_size * icon_scale
		var center_local := _fov_to_local(delta_az, delta_alt)
		var rect := Rect2(center_local - icon_size * 0.5, icon_size)
		icon.position = rect.position
		var alpha: float = float(visual.get("alpha", 1.0))
		if str(item.get("visibility_text", "")) == "Low on horizon":
			alpha *= 0.7
		icon.set_meta("base_alpha", alpha)
		icon.modulate = Color(1, 1, 1, alpha)
		var hit_rect := rect.grow(8.0)
		button.position = hit_rect.position
		button.size = hit_rect.size
		in_view_targets[object_id] = {
			"delta_az": delta_az,
			"delta_alt": delta_alt,
			"rect": rect
		}

	_update_ground()
	_update_scales()
	_update_marker_frames()
	_update_aim_text()
	_update_selected_text()
	_update_guidance()


func _update_ground() -> void:
	var horizon_y := _fov_to_local(0.0, -telescope_altitude).y
	if horizon_y >= VIEW_RECT.size.y:
		ground_rect.visible = false
		horizon_line.visible = false
		return
	var top := maxf(horizon_y, 0.0)
	ground_rect.position = Vector2(0, top)
	ground_rect.size = Vector2(VIEW_RECT.size.x, VIEW_RECT.size.y - top)
	ground_rect.visible = true
	horizon_line.position = Vector2(0, horizon_y - 1.0)
	horizon_line.size = Vector2(VIEW_RECT.size.x, 2.0)
	horizon_line.visible = horizon_y >= 0.0


func _scale_steps(fov: float) -> Vector3:
	# (minor, mid, major-with-number) tick spacing in degrees.
	if fov >= 60.0:
		return Vector3(5.0, 10.0, 30.0)
	if fov >= 12.0:
		return Vector3(1.0, 5.0, 10.0)
	return Vector3(0.25, 0.5, 2.0)


func _update_scales() -> void:
	_update_az_scale()
	_update_alt_scale()
	az_readout.text = "Az " + _format_dms(telescope_azimuth) + " " + _direction_text_for_azimuth(telescope_azimuth)
	alt_readout.text = "Alt " + _format_dms(telescope_altitude)


func _update_az_scale() -> void:
	for tick in az_ticks:
		tick.visible = false
	for label in az_labels:
		label.visible = false
	var steps := _scale_steps(fov_x)
	var minor := steps.x
	var mid := steps.y
	var major := steps.z
	var half := fov_x * 0.5
	var tick_index := 0
	var label_index := 0
	var start_index := int(ceil((telescope_azimuth - half) / minor))
	var end_index := int(floor((telescope_azimuth + half) / minor))
	for i in range(start_index, end_index + 1):
		var azimuth := float(i) * minor
		var delta := shortest_angle_degrees(telescope_azimuth, azimuth)
		var x := VIEW_RECT.size.x * 0.5 + (delta / half) * (VIEW_RECT.size.x * 0.48)
		if x < 2.0 or x > AZ_BAND.size.x - 2.0:
			continue
		var az_normalized := wrapf(azimuth, 0.0, 360.0)
		var is_major := absf(fmod(absf(az_normalized) + 0.001, major)) < 0.01
		var is_mid := absf(fmod(absf(az_normalized) + 0.001, mid)) < 0.01
		if tick_index >= az_ticks.size():
			break
		var tick := az_ticks[tick_index]
		tick_index += 1
		var height := 6.0
		if is_major:
			height = 16.0
		elif is_mid:
			height = 10.0
		tick.position = Vector2(x - 1.0, AZ_BAND.size.y - 2.0 - height)
		tick.size = Vector2(2.0, height)
		tick.color = GOLD if is_major else Color(MUTED.r, MUTED.g, MUTED.b, 0.7 if is_mid else 0.4)
		tick.visible = true
		if is_major and label_index < az_labels.size():
			var label := az_labels[label_index]
			label_index += 1
			var cardinal := _cardinal_for(az_normalized)
			if cardinal != "":
				label.text = "%s %d°" % [cardinal, int(round(az_normalized))]
				label.add_theme_color_override("font_color", GOLD)
			else:
				label.text = "%d°" % int(round(az_normalized))
				label.add_theme_color_override("font_color", MUTED)
			label.position = Vector2(x - 32.0, 2.0)
			label.visible = true


func _cardinal_for(az_normalized: float) -> String:
	var rounded := int(round(az_normalized)) % 360
	match rounded:
		0:
			return "N"
		90:
			return "E"
		180:
			return "S"
		270:
			return "W"
	return ""


func _update_alt_scale() -> void:
	for tick in alt_ticks:
		tick.visible = false
	for label in alt_labels:
		label.visible = false
	var steps := _scale_steps(fov_y)
	var minor := steps.x
	var mid := steps.y
	var major := steps.z
	var half := fov_y * 0.5
	var tick_index := 0
	var label_index := 0
	var start_index := int(ceil((telescope_altitude - half) / minor))
	var end_index := int(floor((telescope_altitude + half) / minor))
	for i in range(start_index, end_index + 1):
		var altitude := float(i) * minor
		if altitude < 0.0 or altitude > 90.0:
			continue
		var delta := altitude - telescope_altitude
		var y := ALT_BAND.size.y * 0.5 - (delta / half) * (VIEW_RECT.size.y * 0.48)
		if y < 2.0 or y > ALT_BAND.size.y - 2.0:
			continue
		var is_major := absf(fmod(absf(altitude) + 0.001, major)) < 0.01
		var is_mid := absf(fmod(absf(altitude) + 0.001, mid)) < 0.01
		if tick_index >= alt_ticks.size():
			break
		var tick := alt_ticks[tick_index]
		tick_index += 1
		var width := 6.0
		if is_major:
			width = 14.0
		elif is_mid:
			width = 9.0
		tick.position = Vector2(ALT_BAND.size.x - 2.0 - width, y - 1.0)
		tick.size = Vector2(width, 2.0)
		tick.color = GOLD if is_major else Color(MUTED.r, MUTED.g, MUTED.b, 0.7 if is_mid else 0.4)
		tick.visible = true
		if is_major and label_index < alt_labels.size():
			var label := alt_labels[label_index]
			label_index += 1
			label.text = "%d" % int(round(altitude))
			label.position = Vector2(0.0, y - 7.0)
			label.visible = true


func _update_marker_frames() -> void:
	if selection_frame != null:
		selection_frame.queue_free()
		selection_frame = null
	if assist_frame != null:
		assist_frame.queue_free()
		assist_frame = null

	# Faint hint frame around the mission target (the target itself stays
	# tiny; only the marker helps you find it).
	var current_level_data: Dictionary = GameManager.current_level()
	if view_mode != "telescope" and in_view_targets.has(target_id) and target_id != selected_object_id \
			and not bool(current_level_data.get("hide_target_hint", false)):
		var target_info: Dictionary = in_view_targets[target_id]
		var target_rect: Rect2 = target_info.get("rect", Rect2())
		var assist_color := FINDER_ASSIST
		if view_mode == "naked_eye":
			assist_color = Color(FINDER_ASSIST.r, FINDER_ASSIST.g, FINDER_ASSIST.b, 0.30)
		assist_frame = _make_frame(view_layer, target_rect.grow(12.0), assist_color, 2)

	if selected_object_id != "" and in_view_targets.has(selected_object_id):
		var info: Dictionary = in_view_targets[selected_object_id]
		var rect: Rect2 = info.get("rect", Rect2())
		selection_frame = _make_frame(view_layer, rect.grow(7.0), GOLD, 3)


func _single(en: String, zh: String) -> String:
	# One language only - for compact single-line rows that must not stack.
	if GameManager.language_mode == "zh":
		return zh
	return en


func _source_text() -> String:
	var item := _sky_item(target_id)
	var source := str(item.get("source", "fallback"))
	if source == "online" or source == "calculated":
		return _single("Live sky data", "实时星空数据")
	return _single("Offline fallback", "离线估算")


func _update_aim_text() -> void:
	var config: Dictionary = VIEW_MODES[view_mode]
	var mode_name := _single(str(config.get("en", view_mode)), str(config.get("zh", view_mode)))
	aim_label.text = "Az: %s (%s)\nAlt: %s\nFOV: %s x %s\n%s · %s" % [
		_format_dms(telescope_azimuth),
		_direction_text_for_azimuth(telescope_azimuth),
		_format_dms(telescope_altitude),
		_format_dms(fov_x),
		_format_dms(fov_y),
		mode_name,
		_source_text()
	]


func _update_mission_tonight_text() -> void:
	var target_sky := _sky_item(target_id)
	var direction := str(target_sky.get("direction_text", "Estimate"))
	mission_tonight_label.text = "Tonight: %s (%s)" % [str(target_sky.get("visibility_text", "Offline estimate")), direction]
	mission_tonight_label.add_theme_color_override("font_color", _visibility_color(target_sky))


func _update_sky_condition_text() -> void:
	# Single inline bilingual line, only shown when the level actually sets
	# an environment - legacy/no-environment levels show nothing here.
	if sky_condition_label == null:
		return
	var sky_key := _sky_brightness_key()
	var cover := _cloud_cover_amount()
	var parts: Array[String] = []
	if sky_key != "":
		var sky_names := {"city": "City城市", "suburban": "Suburban郊区", "dark": "Dark暗夜"}
		parts.append("Sky天空: %s" % str(sky_names.get(sky_key, sky_key.capitalize())))
	if cover > 0.0:
		var tier := "Thin薄云"
		if cover >= 0.67:
			tier = GameManager.text("Heavy clouds", "厚云")
		elif cover >= 0.34:
			tier = GameManager.text("Moderate clouds", "中云")
		parts.append("Cloud云: %s" % tier)
	sky_condition_label.text = "  ·  ".join(parts)
	sky_condition_label.visible = not parts.is_empty()


# --------------------------------------------------------------- interaction


func _select_object(object_id: String) -> void:
	selected_object_id = object_id
	GameManager.selected_object_id = object_id
	_update_selected_text()
	_update_marker_frames()
	_update_guidance()


func _center_offset(object_id: String) -> float:
	# Largest axis offset from the view center, in degrees.
	if not in_view_targets.has(object_id):
		return 99999.0
	var info: Dictionary = in_view_targets[object_id]
	return maxf(absf(float(info.get("delta_az", 999.0))), absf(float(info.get("delta_alt", 999.0))))


func _nearest_center_object() -> String:
	var nearest_id := ""
	var nearest_distance := 99999.0
	for id_value in in_view_targets.keys():
		var object_id: String = str(id_value)
		var distance := _center_offset(object_id)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = object_id
	return nearest_id


func _observe() -> void:
	# Naked-eye levels (L1/L2): the eyes ARE the instrument.
	if not GameManager.current_requires_telescope():
		if selected_object_id == "":
			var nearest_id := _nearest_center_object()
			if nearest_id != "" and _center_offset(nearest_id) < fov_x * 0.15:
				_select_object(nearest_id)
		if selected_object_id != "":
			GameManager.selected_object_id = selected_object_id
			GameManager.go("telescope")
			return
		guidance_label.text = GameManager.text("Pick a bright object first.", "先选择一个明亮的目标。")
		return

	# Telescope levels: only the telescope view mode can start an observation.
	if view_mode == "naked_eye":
		guidance_label.text = GameManager.text(
			"Naked eye is for scanning. Switch to the telescope (3) to observe.",
			"肉眼只用来找方向。请切换到望远镜（按 3）进行观测。"
		)
		return
	if view_mode == "finder":
		guidance_label.text = GameManager.text(
			"The finder is for aiming only. Press 3 for the telescope.",
			"寻星镜只用来对准目标。按 3 切换到主望远镜。"
		)
		return

	if selected_object_id == "":
		var nearest_id := _nearest_center_object()
		if nearest_id != "" and _center_offset(nearest_id) <= _center_tolerance():
			_select_object(nearest_id)
	if selected_object_id == "":
		guidance_label.text = GameManager.text("No target near the center.", "中心附近没有目标。")
		return
	var offset := _center_offset(selected_object_id)
	if offset > _center_tolerance():
		guidance_label.text = GameManager.text(
			"Center the target first. Off by %s." % _format_dms(offset),
			"请先把目标居中，还差 %s。" % _format_dms(offset)
		)
		return

	GameManager.selected_object_id = selected_object_id
	if GameManager.current_requires_focus():
		if GameManager.try_story_for_trigger("before_focus", "telescope"):
			return
		if GameManager.try_teaching_intercept("before_focus", "telescope"):
			return
	GameManager.go("telescope")


func _update_selected_text() -> void:
	# The mission target is always shown here (no manual pick needed);
	# clicking another object in the view temporarily inspects it instead.
	var display_id := selected_object_id
	if display_id == "":
		display_id = target_id
	var obj: Dictionary = GameManager.get_object(display_id)
	var item: Dictionary = _sky_item(display_id)
	var prefix := ""
	if display_id == target_id:
		prefix = "★ "
	selected_title.text = prefix + GameManager.dict_text(obj, "name").replace("\n", " · ")
	# Always show the target angles AND how far the current aim is from them.
	var delta_az := shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0)))
	var delta_alt := float(item.get("altitude", 0.0)) - telescope_altitude
	selected_detail.text = "Target Az: %s (%s)\nTarget Alt: %s\nΔ Az: %s   Δ Alt: %s\n%s · %s" % [
		_format_dms(float(item.get("azimuth", 0.0))),
		str(item.get("direction_text", "Estimate")),
		_format_dms(float(item.get("altitude", 0.0))),
		_format_dms(delta_az, true),
		_format_dms(delta_alt, true),
		str(obj.get("type_en", item.get("type", "Object"))),
		str(item.get("source", "fallback"))
	]


func _update_guidance() -> void:
	var text := _guidance_for_target()
	text = _apply_workflow_discipline_hint(text)
	text = _apply_mission_step_hint(text)
	guidance_label.text = text
	if guidance_banner != null:
		guidance_banner.text = text
		var centered := text.contains("Observe") or text.contains("识别") or text.contains("可以观测")
		guidance_banner.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62) if centered else Color(1.0, 0.85, 0.45))


func _guidance_for_target() -> String:
	var item := _sky_item(target_id)
	if item.is_empty():
		return ""
	var altitude: float = float(item.get("altitude", 0.0))
	if altitude <= 0.0:
		return GameManager.text("Below horizon. Cannot observe tonight.", "目标在地平线以下，今晚无法观测。")
	var delta_az := shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0)))
	var delta_alt := altitude - telescope_altitude
	var half_x := fov_x * 0.5
	var half_y := fov_y * 0.5

	if absf(delta_az) <= half_x and absf(delta_alt) <= half_y:
		var offset := maxf(absf(delta_az), absf(delta_alt))
		if view_mode == "telescope":
			if offset <= CENTER_TOLERANCE_TELESCOPE:
				return GameManager.text("Centered. Ready for telescope. Observe!", "已居中，可以观测了！")
			return GameManager.text(
				"In telescope view. Center within %s." % _format_dms(CENTER_TOLERANCE_TELESCOPE),
				"目标在望远镜视野中，请居中到 %s 以内。" % _format_dms(CENTER_TOLERANCE_TELESCOPE)
			)
		if view_mode == "finder":
			if offset <= CENTER_TOLERANCE_FINDER:
				return GameManager.text("Centered enough for telescope. Press 3.", "已接近望远镜视野，按 3 切换主望远镜。")
			return GameManager.text("Target in finder scope. Center it.", "目标已进入寻星镜视野，请居中。")
		if not GameManager.current_requires_telescope():
			if offset <= fov_x * 0.15:
				return GameManager.text("Target in sight. Observe with your eyes!", "目标就在眼前，直接观察吧！")
			return GameManager.text("Target in view. Move it toward the center.", "目标在视野中，把它移向中心。")
		if offset <= fov_x * 0.05:
			return GameManager.text("Target lined up. Zoom in with the finder (2).", "目标已对准，按 2 用寻星镜细看。")
		return GameManager.text("Target in view. Move it toward the center.", "目标在视野中，把它移向中心。")

	# Out of view: give exact DMS turn amounts.
	var en_parts: Array[String] = []
	var zh_parts: Array[String] = []
	if delta_az > 1.0:
		en_parts.append("Turn east %s." % _format_dms(absf(delta_az)))
		zh_parts.append("向东转 %s。" % _format_dms(absf(delta_az)))
	elif delta_az < -1.0:
		en_parts.append("Turn west %s." % _format_dms(absf(delta_az)))
		zh_parts.append("向西转 %s。" % _format_dms(absf(delta_az)))
	if delta_alt > 1.0:
		en_parts.append("Raise %s." % _format_dms(absf(delta_alt)))
		zh_parts.append("抬高 %s。" % _format_dms(absf(delta_alt)))
	elif delta_alt < -1.0:
		en_parts.append("Lower %s." % _format_dms(absf(delta_alt)))
		zh_parts.append("降低 %s。" % _format_dms(absf(delta_alt)))
	if en_parts.is_empty():
		return GameManager.text("Target just outside view. Nudge slightly.", "目标就在视野边缘，微调一下。")
	return GameManager.text(" ".join(en_parts), "".join(zh_parts))


func _apply_mission_step_hint(default_text: String) -> String:
	# When the level has an unfinished checklist (e.g. L10's 20mm-then-10mm),
	# lead with which step is still pending instead of the generic aim hint.
	var step := GameManager.next_pending_mission_step()
	if step.is_empty():
		return default_text
	var label := GameManager.dict_text(step, "label")
	var steps := GameManager.mission_steps()
	var done := GameManager.completed_mission_steps().size()
	return GameManager.text(
		"Step %d/%d: %s" % [done + 1, steps.size(), label],
		"步骤 %d/%d：%s" % [done + 1, steps.size(), label]
	)


func _update_workflow_discipline_timer(delta: float) -> void:
	# L16 "Narrow Field Problem": if the player is stuck in the telescope
	# view without ever visiting the finder, and the target still isn't
	# centered after a while, show Maya's stronger one-time reminder panel
	# (the persistent bottom-bar hint from _apply_workflow_discipline_hint
	# stays as-is; this is an additional, harder-to-miss layer).
	var level_variation: String = str(GameManager.current_level().get("variation", ""))
	if level_variation != "workflow_discipline" or workflow_prompt_shown:
		return
	if view_mode != "telescope" or visited_modes.has("finder"):
		return
	var target_centered := in_view_targets.has(target_id) and _center_offset(target_id) <= _center_tolerance()
	if target_centered:
		return
	workflow_elapsed += delta
	if workflow_elapsed >= WORKFLOW_LOST_SECONDS or workflow_move_count >= WORKFLOW_LOST_MOVES:
		_show_workflow_lost_panel()


func _show_workflow_lost_panel() -> void:
	workflow_prompt_shown = true
	var lines: Array = StoryManager.get_dialogue("level_16_mid")
	var text_en := "Lost? Everyone gets lost in six degrees. Wide first, narrow last."
	var text_zh := "迷路了吧？在 6 度的视野里谁都会迷路。先宽后窄。"
	if not lines.is_empty() and lines[0] is Dictionary:
		var line: Dictionary = lines[0]
		text_en = str(line.get("text_en", text_en))
		text_zh = str(line.get("text_zh", text_zh))

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_rect(overlay, Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.55))

	var panel_size := Vector2(560, 220)
	var panel_pos := Vector2((W - panel_size.x) * 0.5, (H - panel_size.y) * 0.5)
	_rect(overlay, panel_pos, panel_size, Color(0.04, 0.05, 0.09, 0.97))
	var frame := _make_frame(overlay, Rect2(panel_pos, panel_size), GOLD, 3)
	frame.visible = true

	var name_label := _label(overlay, "Maya", panel_pos + Vector2(24, 18), Vector2(panel_size.x - 48, 24), 15, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := _label(overlay, GameManager.text(text_en, text_zh), panel_pos + Vector2(24, 52), Vector2(panel_size.x - 48, 110), 14, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 5

	var hint := _label(overlay, GameManager.text("Press SPACE to continue", "按 SPACE 继续"), panel_pos + Vector2(24, panel_size.y - 34), Vector2(panel_size.x - 48, 20), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			overlay.queue_free()
		elif event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)
	# Also allow unhandled key input in case focus isn't on the overlay.
	overlay.focus_mode = Control.FOCUS_ALL
	overlay.grab_focus()


func _apply_workflow_discipline_hint(default_text: String) -> String:
	# L16 "Narrow Field Problem": if the player jumps straight to the
	# telescope without ever visiting the finder, swap in Maya's reminder
	# instead of the normal guidance line.
	var level_variation: String = str(GameManager.current_level().get("variation", ""))
	if level_variation != "workflow_discipline":
		return default_text
	if view_mode != "telescope" or visited_modes.has("finder"):
		return default_text
	return GameManager.text(
		"Lost? Everyone gets lost in six degrees. Wide first, narrow last.",
		"迷路了吧？在 6 度的视野里谁都会迷路。先宽后窄。"
	)


# --------------------------------------------------------------------- state


func _finder_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var finder: Dictionary = state.get("finder_scope", {})
	return bool(finder.get("installed", false))


func _sky_item(object_id: String) -> Dictionary:
	if sky_data.has(object_id):
		return sky_data[object_id]
	return {}


func _visibility_color(item: Dictionary) -> Color:
	var text := str(item.get("visibility_text", ""))
	if text == "Visible tonight":
		return GREEN
	if text == "Low on horizon":
		return WARNING
	return MUTED


# ------------------------------------------------------------------- helpers


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


func _make_frame(parent: Control, rect: Rect2, color: Color, width: int) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_rect(frame, Vector2.ZERO, Vector2(rect.size.x, width), color)
	_rect(frame, Vector2(0, rect.size.y - width), Vector2(rect.size.x, width), color)
	_rect(frame, Vector2.ZERO, Vector2(width, rect.size.y), color)
	_rect(frame, Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y), color)
	return frame


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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
	parent.add_child(label)
	return label

func _on_language_changed() -> void:
	_build()
