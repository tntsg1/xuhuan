extends Control

const TURBULENCE_SHADER := preload("res://shaders/turbulence.gdshader")
const GRAIN_SHADER := preload("res://shaders/grain.gdshader")

const COL_BG := Color(0.004, 0.006, 0.014)
const COL_NAVY := Color(0.030, 0.045, 0.085, 0.96)
const COL_PANEL := Color(0.050, 0.070, 0.120, 0.96)
const COL_GOLD := Color(0.78, 0.56, 0.28)
const COL_GOLD_LIGHT := Color(0.95, 0.76, 0.42)
const COL_BLUE_BORDER := Color(0.17, 0.25, 0.40)
const COL_TEXT := Color(0.96, 0.94, 0.88)
const COL_CROSSHAIR := Color(0.50, 0.70, 0.90, 0.22)

# Large pixel-art sprites shown through the eyepiece.
const SPRITE_MAP := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_large.png",
	"andromeda": "res://assets/telescope_view/andromeda_large.png"
}

# Per-object state textures: clear (sharp art) / blurry (defocus photo,
# cross-fade overlay) / dim (light shortage). Add an entry here and the
# whole three-state pipeline picks it up automatically.
const STATE_TEXTURES := {
	"jupiter": {
		"clear": "res://assets/telescope_view/jupiter_clear.png",
		"blurry": "res://assets/telescope_view/jupiter_blurry.png",
		"dim": "res://assets/telescope_view/jupiter_dim.png"
	},
	"mars": {
		"clear": "res://assets/telescope_view/mars_clear.png",
		"blurry": "res://assets/telescope_view/mars_blurry.png",
		"dim": "res://assets/telescope_view/mars_dim.png"
	}
}

# Right panel layout (1024x768): everything must stay above y = 700.
const PANEL_POS := Vector2(752, 106)
const PANEL_SIZE := Vector2(236, 594)
const CONTENT_X := 772.0
const CONTENT_W := 194.0
const FOCUS_ADJUST_SPEED := 0.22

var feedback_label: Label
var quality_label: Label
var mission_step_label: Label
var choices_box: VBoxContainer
var observation: Dictionary
var selected_object: Dictionary

var observation_mode := "telescope"
var requires_focus := false
var allow_focus_input := true
var focus_value := 0.5
var target_focus_value := 0.5
var focus_tolerance := 0.06
var focus_error := 0.0
var focus_locked := false

var focus_slider: HSlider
var focus_state_label: Label
var focus_pct_label: Label
var updating_slider := false

var lens_center := Vector2.ZERO
var target_center := Vector2.ZERO
var main_sprite: TextureRect
var ghost_a: TextureRect
var ghost_b: TextureRect
var blur_overlay: TextureRect
var base_alpha := 1.0
var current_sprite_path := ""
var noise_quality := ""

# Smoothed display values: inputs are quantized (slider steps, quality
# tiers), so visuals chase their targets each frame instead of snapping.
var visual_focus_error := 0.0
var visual_target_center := Vector2.ZERO
var visual_base_alpha := 1.0
var blur_weight := 0.0
# Final on-screen scale for the target sprites (magnification vs fit cap).
var display_scale := 1.0

# L18 dark adaptation + averted vision (nebula/galaxy targets only): purely
# cosmetic alpha boosts that help the player SEE the faint smudge, without
# changing the underlying evaluation (the physics doesn't care if your eyes
# have adjusted).
const DARK_ADAPTATION_SECONDS := 8.0
const DARK_ADAPTATION_ALPHA_BONUS := 0.10
const AVERTED_VISION_ALPHA_BONUS := 0.10
const AVERTED_VISION_BRIGHTEN := 1.06
var dark_adaptation := 0.0
var averted_vision_active := false
var dark_adaptation_label: Label
var averted_vision_label: Label
var star_layer_nodes: Array[ColorRect] = []
var star_layer_container: Control

# --- Observation-condition realism (E1): conditions snapshot, all smoothed.
var cond_turbulence := 0.0     # 0-1, atmospheric turbulence (seeing x mag x altitude)
var cond_cloud_atten := 0.0    # 0-1, instantaneous cloud attenuation on the target
var cond_sky_lift := 0.0       # 0-1, background brightening (city 1.0 / suburban 0.5 / dark 0)
var effect_seed := 0.0         # per-observation random phase so breathing/jitter don't sync
var turbulence_material_main: ShaderMaterial
var turbulence_material_blur: ShaderMaterial
var turbulence_material_ghost: ShaderMaterial
var grain_layer: ColorRect
var grain_material: ShaderMaterial
var grain_intensity := 0.0
var target_grain_intensity := 0.0
var cloud_nodes: Array[TextureRect] = []
var cloud_velocities: Array[Vector2] = []
var cloud_cover_level := 0.0
var cloud_reevaluate_timer := 0.0
const CLOUD_TEXTURES := [
	"res://assets/telescope_view/cloud_wisp_a.png",
	"res://assets/telescope_view/cloud_wisp_b.png",
	"res://assets/telescope_view/cloud_wisp_c.png"
]

# --- Earth-drift and tracking (E2). drift_enabled levels move the target and
# the scope's star field together (the sky is turning); the player fights it
# with WASD/arrows, or a tracking mount cancels it automatically.
# NOTE: Vector2.rotated() is not a constant expression in GDScript 4.7, so
# the drift direction is computed once in _init_drift() instead of const.
var drift_direction := Vector2.RIGHT
const DRIFT_SPEED_BASE := 6.0            # px/s at magnification 35x
const DRIFT_CORRECTION_SPEED := 90.0     # px/s, player nudging the offset back
const DRIFT_OUT_OF_VIEW := 250.0         # px, |offset| beyond this = Failed
const DRIFT_HOLD_RADIUS := 46.0          # px, inside this counts toward hold
var drift_enabled := false
var drift_offset := Vector2.ZERO
var hold_seconds_required := 0.0
var hold_timer := 0.0
var hold_strict := false
var drift_reevaluate_timer := 0.0
var tracking_slider: HSlider
var tracking_label: Label
var hold_label: Label
var hold_bar_fill: ColorRect
var drift_label: Label
var target_off_center := false


func _ready() -> void:
	selected_object = GameManager.get_object(GameManager.selected_object_id)
	if selected_object.is_empty():
		selected_object = GameManager.current_target()
		GameManager.selected_object_id = str(selected_object.get("id", ""))
	observation_mode = GameManager.current_observation_mode()
	requires_focus = observation_mode == "telescope" and GameManager.current_requires_focus()
	allow_focus_input = _focus_knob_installed()
	_init_drift()
	if requires_focus:
		_init_focus()
	observation = _evaluate()
	_check_mission_step_progress()
	_build()


func _init_drift() -> void:
	var level := GameManager.current_level()
	drift_enabled = observation_mode == "telescope" and bool(level.get("drift_enabled", false))
	hold_seconds_required = float(level.get("hold_seconds", 0.0)) if drift_enabled else 0.0
	hold_strict = drift_enabled and bool(level.get("hold_strict", false))
	drift_offset = Vector2.ZERO
	drift_direction = Vector2.RIGHT.rotated(0.08)
	hold_timer = 0.0
	target_off_center = false


func _focus_knob_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var knob: Dictionary = state.get("focus_knob", {})
	return bool(knob.get("installed", false))


func _focus_control_score() -> float:
	var stats: Dictionary = GameManager.calculate_stats()
	return float(stats.get("focus_control_score", 0.0))


func _is_dark_adaptation_target() -> bool:
	if not requires_focus:
		return false
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("nebula") or type_lower.contains("galaxy")


# ------------------------------------------------------- object-type dispatch


func _is_star_target() -> bool:
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("star")


func _is_diffuse_target() -> bool:
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("nebula") or type_lower.contains("galaxy")


# --------------------------------------------------------- conditions snapshot


func _seeing_severity() -> float:
	var environment: Dictionary = GameManager.current_environment()
	if environment.is_empty():
		return 0.06
	var seeing_label := str(observation.get("seeing_label", "Good"))
	match seeing_label:
		"Poor":
			return 0.8
		"Average":
			return 0.35
	return 0.06


func _current_altitude() -> float:
	var aim: Dictionary = GameManager.last_sky_aim
	if bool(aim.get("valid", false)):
		return float(aim.get("altitude", 45.0))
	return 45.0


func _target_turbulence() -> float:
	var stats := GameManager.calculate_stats()
	var magnification := float(stats.get("magnification", 0.0))
	var severity := _seeing_severity()
	var mag_factor := clampf(magnification / 55.0, 0.4, 1.6)
	var altitude_factor := clampf(1.6 - _current_altitude() / 60.0, 0.7, 1.3)
	return clampf(severity * mag_factor * altitude_factor, 0.0, 1.0)


func _target_sky_lift() -> float:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	match sky_key:
		"city":
			return 1.0
		"suburban":
			return 0.5
	return 0.0


func _cloud_cover() -> float:
	var environment: Dictionary = GameManager.current_environment()
	return clampf(float(environment.get("cloud_cover", 0.0)), 0.0, 1.0)


func _cloud_tier_label() -> Dictionary:
	# UI + numeric agreement: Clear / Thin / Moderate / Heavy.
	var cover := cloud_cover_level
	if cover <= 0.0:
		return {"en": "Clear", "zh": "晴朗"}
	if cover < 0.34:
		return {"en": "Thin", "zh": "薄云"}
	if cover < 0.67:
		return {"en": "Moderate", "zh": "中云"}
	return {"en": "Heavy", "zh": "厚云"}


func _sky_tier_label() -> Dictionary:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	match sky_key:
		"city":
			return {"en": "City", "zh": "城市"}
		"suburban":
			return {"en": "Suburban", "zh": "郊区"}
	return {"en": "Dark", "zh": "暗夜"}


func _contrast_label() -> Dictionary:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	var rank := 2  # 0=Low 1=Medium 2=High
	match sky_key:
		"city":
			rank = 0
		"suburban":
			rank = 1
	if cloud_tier_index() >= 2:  # Moderate or Heavy
		rank = maxi(rank - 1, 0)
	match rank:
		0:
			return {"en": "Low", "zh": "低"}
		1:
			return {"en": "Medium", "zh": "中"}
	return {"en": "High", "zh": "高"}


func cloud_tier_index() -> int:
	var cover := cloud_cover_level
	if cover <= 0.0:
		return 0
	if cover < 0.34:
		return 1
	if cover < 0.67:
		return 2
	return 3


func _process(delta: float) -> void:
	if _is_dark_adaptation_target():
		_advance_dark_adaptation(delta)
	if requires_focus:
		_advance_visual_smoothing(delta)
	if observation_mode != "naked_eye":
		_advance_conditions(delta)
	if drift_enabled:
		_advance_drift(delta)
	_handle_focus_input(delta)


func _handle_focus_input(delta: float) -> void:
	if not requires_focus or focus_locked or not allow_focus_input:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_Q):
		direction -= 1.0
	if Input.is_key_pressed(KEY_E):
		direction += 1.0
	if not drift_enabled:
		# Non-drift levels keep A/D and move_left/move_right as focus aliases
		# (unchanged behavior).
		if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
			direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
			direction += 1.0
	if direction == 0.0:
		return
	_set_focus_value(clampf(focus_value + direction * FOCUS_ADJUST_SPEED * delta, 0.0, 1.0))


func _advance_drift(delta: float) -> void:
	# The sky turns; drift_offset accumulates the apparent motion. Q/E stay
	# focus-only on drift levels (see _handle_focus_input) - WASD / arrow
	# keys become the centering correction instead.
	var magnification := float(GameManager.calculate_stats().get("magnification", 0.0))
	var mag_factor := magnification / 35.0 if magnification > 0.0 else 1.0
	var tracking_cancel := 0.0
	if GameManager.has_tracking_mount_equipped():
		tracking_cancel = GameManager.tracking_rate()
	var drift_speed := DRIFT_SPEED_BASE * mag_factor * (1.0 - tracking_cancel)
	drift_offset += drift_direction * drift_speed * delta

	var correction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		correction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		correction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_up"):
		correction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_down"):
		correction.y += 1.0
	if correction != Vector2.ZERO:
		drift_offset -= correction.normalized() * DRIFT_CORRECTION_SPEED * delta

	_apply_drift_offset()
	_advance_hold(delta)
	_refresh_drift_ui()

	if cloud_cover_level <= 0.0:
		# Cloud levels already re-evaluate on their own 0.6s timer; drift-only
		# levels need their own re-evaluate cadence so target_off_center /
		# hold-gated quality stays current without spamming every frame.
		drift_reevaluate_timer += delta
		if drift_reevaluate_timer >= 0.3:
			drift_reevaluate_timer = 0.0
			observation = _evaluate()
			_refresh_focus_ui()


func _apply_drift_offset() -> void:
	# Target and star field move together - "the sky is turning", not the
	# telescope. target_center just gets the new offset baked in directly;
	# the existing _advance_visual_smoothing() exponential chase (E1) is what
	# turns this into smooth on-screen motion, same as every other visual
	# target change - no separate drift-specific smoothing needed.
	target_off_center = drift_offset.length() > DRIFT_OUT_OF_VIEW
	if star_layer_container != null:
		star_layer_container.position = drift_offset
	var effect := str(observation.get("visual_effect", "clear"))
	var quality := str(observation.get("quality", "Unknown"))
	target_center = lens_center + _effect_offset(effect, quality) + drift_offset


func _advance_hold(delta: float) -> void:
	if hold_seconds_required <= 0.0:
		return
	if drift_offset.length() < DRIFT_HOLD_RADIUS:
		hold_timer = minf(hold_timer + delta, hold_seconds_required)
	elif hold_strict:
		# L24: drifting out of the hold radius actively drains progress
		# (2x delta) instead of just pausing.
		hold_timer = maxf(hold_timer - delta * 2.0, 0.0)
	# Loose mode (default): pauses outside the radius, does not reset.


func is_hold_satisfied() -> bool:
	if hold_seconds_required <= 0.0:
		return true
	return hold_timer >= hold_seconds_required


func _hold_progress_text() -> String:
	return GameManager.text(
		"Hold it steady a little longer: %.1f / %.1fs" % [hold_timer, hold_seconds_required],
		"再稳住 %.1f / %.1f 秒" % [hold_timer, hold_seconds_required]
	)


func _advance_dark_adaptation(delta: float) -> void:
	var moving := false
	if dark_adaptation < 1.0:
		dark_adaptation = clampf(dark_adaptation + delta / DARK_ADAPTATION_SECONDS, 0.0, 1.0)
		moving = true
	var shift_pressed := Input.is_key_pressed(KEY_SHIFT)
	if shift_pressed != averted_vision_active:
		averted_vision_active = shift_pressed
		moving = true
	if moving:
		var eased := _eased_dark_adaptation()
		for star_rect in star_layer_nodes:
			star_rect.modulate.a = lerpf(1.0, 0.55, eased)
		if dark_adaptation_label != null:
			dark_adaptation_label.text = "Dark adaptation: %d%%" % int(round(eased * 100.0))
		if averted_vision_label != null:
			averted_vision_label.text = "Averted侧视: Active启用" if averted_vision_active else "Averted侧视: Inactive未启用"
			averted_vision_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62) if averted_vision_active else Color(0.66, 0.72, 0.80))
		_update_target_visuals()


func _eased_dark_adaptation() -> float:
	# Non-linear ease: adaptation feels slow to start, then catches up
	# (spec: ease(dark_adaptation, 0.6)).
	return pow(dark_adaptation, 0.6)


func _dark_adaptation_alpha_bonus() -> float:
	if not _is_dark_adaptation_target():
		return 0.0
	var bonus := DARK_ADAPTATION_ALPHA_BONUS * _eased_dark_adaptation()
	if averted_vision_active:
		# Averted vision (spec): contour boost via alpha, not a flat add-on.
		bonus += AVERTED_VISION_ALPHA_BONUS
	return bonus


func _advance_visual_smoothing(delta: float) -> void:
	# Exponential chase toward the current targets - frame-rate independent.
	var weight := 1.0 - exp(-10.0 * delta)
	var target_blur := _target_blur_weight()
	var moving := false
	if absf(visual_focus_error - focus_error) > 0.0005:
		visual_focus_error = lerpf(visual_focus_error, focus_error, weight)
		moving = true
	elif visual_focus_error != focus_error:
		visual_focus_error = focus_error
		moving = true
	if visual_target_center.distance_to(target_center) > 0.25:
		visual_target_center = visual_target_center.lerp(target_center, weight)
		moving = true
	if absf(visual_base_alpha - base_alpha) > 0.004:
		visual_base_alpha = lerpf(visual_base_alpha, base_alpha, weight)
		moving = true
	if absf(blur_weight - target_blur) > 0.004:
		blur_weight = lerpf(blur_weight, target_blur, weight)
		moving = true
	if moving:
		_update_target_visuals()


func _target_blur_weight() -> float:
	# 0 = fully sharp art, 1 = fully blurry photo. Focus error drives a
	# smooth band around the tolerance; equipment-limited Fair quality
	# keeps the image soft even at perfect focus.
	if blur_overlay == null:
		return 0.0
	var focus_component: float = smoothstep(focus_tolerance * 0.8, focus_tolerance * 2.4, focus_error)
	# NOTE: visual_effect is a relative "weakest stat" hint and can say
	# "blurry" even at Excellent - never let it drive the image. Only the
	# authoritative quality verdict keeps the image soft at good focus.
	var quality := str(observation.get("quality", ""))
	if quality == "Fair" and is_focus_acceptable():
		return maxf(focus_component, 1.0)
	return focus_component


func _advance_conditions(delta: float) -> void:
	# Conditions snapshot: chase targets exponentially, same pattern as
	# _advance_visual_smoothing, so nothing ever hard-cuts.
	var weight := 1.0 - exp(-6.0 * delta)
	var t := Time.get_ticks_msec() / 1000.0
	var moving := false
	var target_turb := _target_turbulence()
	if absf(cond_turbulence - target_turb) > 0.002:
		cond_turbulence = lerpf(cond_turbulence, target_turb, weight)
		moving = true
	elif cond_turbulence != target_turb:
		cond_turbulence = target_turb
		moving = true
	var target_lift := _target_sky_lift()
	if absf(cond_sky_lift - target_lift) > 0.002:
		cond_sky_lift = lerpf(cond_sky_lift, target_lift, weight)
		moving = true
	elif cond_sky_lift != target_lift:
		cond_sky_lift = target_lift
		moving = true
	_advance_clouds(delta)
	if absf(cond_cloud_atten - _cloud_target_atten()) > 0.002:
		cond_cloud_atten = lerpf(cond_cloud_atten, _cloud_target_atten(), weight)
		moving = true
	if absf(grain_intensity - target_grain_intensity) > 0.001:
		grain_intensity = lerpf(grain_intensity, target_grain_intensity, weight)
		if grain_material != null:
			grain_material.set_shader_parameter("intensity", grain_intensity)
	if moving:
		_apply_turbulence_uniforms()
		_apply_breathing_and_jitter(t)
		_apply_star_twinkle(t)
	elif cond_turbulence > 0.001:
		# Even when converged, the low-frequency breathing/jitter/twinkle
		# keeps animating every frame (that IS the effect).
		_apply_breathing_and_jitter(t)
		_apply_star_twinkle(t)
	if cloud_cover_level > 0.0:
		cloud_reevaluate_timer += delta
		if cloud_reevaluate_timer >= 0.6:
			cloud_reevaluate_timer = 0.0
			observation = _evaluate()
			_refresh_target_sprite()
			if quality_label != null:
				var quality := str(observation.get("quality", "Unknown"))
				quality_label.text = "Quality: " + quality
				quality_label.add_theme_color_override("font_color", _quality_color(quality))
			if feedback_label != null:
				feedback_label.text = _current_feedback()


func _apply_turbulence_uniforms() -> void:
	if turbulence_material_main != null:
		turbulence_material_main.set_shader_parameter("turbulence", cond_turbulence)
	if turbulence_material_blur != null:
		turbulence_material_blur.set_shader_parameter("turbulence", cond_turbulence)
	if turbulence_material_ghost != null:
		turbulence_material_ghost.set_shader_parameter("turbulence", cond_turbulence)


func _apply_breathing_and_jitter(t: float) -> void:
	if cond_turbulence <= 0.001 or main_sprite == null:
		return
	var cloud_mult := _cloud_alpha_multiplier()
	if _is_star_target():
		# Stars: flicker via alpha, tiny position jitter, no UV shader.
		var flicker := 0.875 + 0.125 * sin(t * (2.2 + cond_turbulence * 3.0) + effect_seed)
		main_sprite.modulate.a = visual_base_alpha * flicker * cloud_mult
		var jitter := Vector2(
			sin(t * 3.7 + effect_seed) * cond_turbulence * 2.5,
			cos(t * 2.9 + effect_seed * 1.3) * cond_turbulence * 2.5
		)
		main_sprite.position = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
	elif _is_diffuse_target():
		# Nebula/galaxy: whole-image alpha "breathing", no shape distortion.
		var breathe := 1.0 + 0.05 * cond_turbulence * sin(t * 1.1 + effect_seed)
		main_sprite.modulate.a = clampf(visual_base_alpha * breathe * cloud_mult, 0.0, 1.0)
	else:
		# Planet/Moon: shader-driven UV wobble + breathing blur + jitter.
		var breathing := cond_turbulence * 0.18 * (0.5 + 0.5 * sin(t * 1.3 + effect_seed))
		var jitter_scale: float = cond_turbulence * (1.2 if str(selected_object.get("id", "")) == "moon" else 2.5)
		var jitter := Vector2(
			sin(t * 2.6 + effect_seed) * jitter_scale,
			cos(t * 1.9 + effect_seed * 0.7) * jitter_scale * 0.6
		)
		var origin: Vector2 = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
		main_sprite.position = origin
		if blur_overlay != null:
			blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5 + jitter
			blur_overlay.modulate.a = visual_base_alpha * clampf(blur_weight + breathing, 0.0, 1.0) * cloud_mult
			main_sprite.modulate.a = visual_base_alpha * (1.0 - clampf(blur_weight + breathing, 0.0, 1.0) * 0.85) * cloud_mult


func _apply_star_twinkle(t: float) -> void:
	# Background scope stars twinkle a little too, scaled by seeing severity.
	var severity := _seeing_severity()
	var base_a := lerpf(1.0, 0.55, _eased_dark_adaptation())
	for i in range(star_layer_nodes.size()):
		var star_rect := star_layer_nodes[i]
		var twinkle := 1.0 + 0.18 * severity * sin(t * (1.5 + fmod(float(i), 5.0) * 0.3) + float(i))
		star_rect.modulate.a = clampf(base_a * twinkle, 0.0, 1.0)


func _cloud_target_atten() -> float:
	# Weighted overlap of drifting cloud sprites over the target center.
	if cloud_nodes.is_empty():
		return 0.0
	var total := 0.0
	for cloud in cloud_nodes:
		var cloud_center: Vector2 = cloud.position + cloud.size * 0.5
		var d := cloud_center.distance_to(target_center)
		var falloff := clampf(1.0 - d / 170.0, 0.0, 1.0)
		total += falloff * cloud.modulate.a
	return clampf(total, 0.0, 1.0)


func _advance_clouds(delta: float) -> void:
	if cloud_nodes.is_empty():
		return
	for i in range(cloud_nodes.size()):
		var cloud := cloud_nodes[i]
		cloud.position += cloud_velocities[i] * delta
		# Recycle once fully outside the scope circle (diameter ~436, radius
		# 218 around lens_center) - re-enter from the opposite side.
		var c := cloud.position + cloud.size * 0.5
		if c.distance_to(lens_center) > 340.0:
			var angle: float = atan2(cloud_velocities[i].y, cloud_velocities[i].x) + PI
			cloud.position = lens_center + Vector2(cos(angle), sin(angle)) * 260.0 - cloud.size * 0.5


func _init_focus() -> void:
	var stage := GameManager.current_equipment_stage()
	var id := str(selected_object.get("id", ""))
	var eyepiece_id := GameManager.equipped_part_id("eyepiece")
	# Deterministic per target + stage + eyepiece: same level always needs
	# the same focus, but swapping the eyepiece shifts the focal plane and
	# forces a real re-focus.
	target_focus_value = 0.35 + fmod(float(absi((id + stage + eyepiece_id).hash())), 300.0) / 1000.0
	# Quantize to the slider grid so dragging can land EXACTLY on target.
	target_focus_value = snappedf(target_focus_value, 0.005)
	focus_tolerance = _tolerance_for(selected_object)
	focus_value = 0.5
	if absf(focus_value - target_focus_value) < 0.12:
		# Always start visibly out of focus so the player learns the knob.
		focus_value = fmod(focus_value + 0.27, 1.0)
	focus_error = absf(focus_value - target_focus_value)
	if not allow_focus_input:
		# No focus knob installed: the image stays clearly defocused.
		focus_error = maxf(focus_error, 0.25)


func _tolerance_for(obj: Dictionary) -> float:
	var object_type := str(obj.get("type_en", "")).to_lower()
	var id := str(obj.get("id", ""))
	if id == "moon":
		return 0.08
	if object_type.contains("planet"):
		return 0.05
	if object_type.contains("nebula") or object_type.contains("galaxy"):
		return 0.07
	return 0.06


func _evaluate() -> Dictionary:
	var context := {"observation_mode": observation_mode}
	if requires_focus:
		context["focus_error"] = focus_error
		context["requires_focus"] = true
		context["focus_tolerance"] = focus_tolerance
	if cloud_cover_level > 0.0:
		# Real-time cloud attenuation: as clouds drift across the target the
		# instantaneous darkening feeds back into the actual quality math
		# (observation_system uses this key when present; the static
		# cloud_cover formula stays untouched for callers that don't pass it,
		# e.g. flow_test's direct evaluate() calls).
		context["cloud_attenuation"] = cond_cloud_atten
	if drift_enabled and target_off_center:
		# E2: drifted out of the eyepiece entirely - hard Failed. Only this
		# live telescope_view loop ever sets this key; GameManager's own
		# evaluate_selected_object() call (used by flow_test) never passes
		# it, so the 24-level numeric regression path is unaffected.
		context["target_off_center"] = true
	return GameManager.evaluate_selected_object(context)


func _focus_state() -> String:
	# Focus state depends ONLY on focus_error vs tolerance - never on the
	# overall observation quality. Inside tolerance is always "sharp".
	if is_focus_acceptable():
		return "sharp"
	if focus_error <= focus_tolerance * 1.75:
		return "slightly_blurry"
	if focus_error <= focus_tolerance * 3.0:
		return "blurry"
	return "very_blurry"


# Single source of truth for "can this observation be identified".
# Selection + centering are enforced by Sky Observation before entering
# this scene; here the remaining gates are focus and overall quality.


func is_focus_acceptable() -> bool:
	if not requires_focus:
		return true
	if not allow_focus_input:
		return false
	return focus_error <= focus_tolerance


func is_quality_acceptable() -> bool:
	return bool(observation.get("success", false))


func can_identify_object() -> bool:
	return is_focus_acceptable() and is_quality_acceptable() and _missing_required_parts().is_empty() and is_hold_satisfied()


# Checks whether the CURRENTLY equipped part satisfies the level's next
# pending mission step (e.g. L10: step 1 needs the 20mm, step 2 the 10mm),
# and if the observation itself is good enough, marks that step done.
# Only advances forward - never un-marks a step that was already completed.
func _check_mission_step_progress() -> void:
	if not is_focus_acceptable() or not is_quality_acceptable():
		return
	var step := GameManager.next_pending_mission_step()
	if step.is_empty():
		return
	var require_part_id := str(step.get("require_part_id", ""))
	if require_part_id == "":
		return
	var part := GameManager.get_part(require_part_id)
	var part_type := str(part.get("type", ""))
	if part_type == "" or GameManager.equipped_part_id(part_type) != require_part_id:
		return
	GameManager.mark_mission_step_done(str(step.get("id", "")))


func _pending_step_label() -> String:
	var step := GameManager.next_pending_mission_step()
	if step.is_empty():
		return ""
	return GameManager.dict_text(step, "label")


func _mission_step_progress_text() -> String:
	var steps := GameManager.mission_steps()
	if steps.is_empty():
		return ""
	var done := GameManager.completed_mission_steps().size()
	var total := steps.size()
	var label := _pending_step_label()
	if label == "":
		return "Step %d/%d: %s" % [total, total, GameManager.text("All steps complete", "全部步骤已完成")]
	return "Step %d/%d: %s" % [mini(done + 1, total), total, label]


func _missing_required_parts() -> Array[String]:
	var missing: Array[String] = GameManager.missing_required_parts()
	return missing


func _missing_required_parts_text() -> String:
	var missing := _missing_required_parts()
	var names_en: Array[String] = []
	var names_zh: Array[String] = []
	for part_id in missing:
		var part := GameManager.get_part(part_id)
		names_en.append(str(part.get("name_en", part_id)))
		names_zh.append(str(part.get("name_zh", part_id)))
	return GameManager.text(
		"This mission requires: " + ", ".join(names_en) + ". Equip it at the Parts Cabinet and reassemble.",
		"本次任务需要：" + "、".join(names_zh) + "。请到零件柜换装并重新组装。"
	)


func _quality_shortfall_text() -> String:
	# Focus is fine - name the REAL limiting factor so the player never
	# blames the wrong thing (audit: story must match the mechanic).
	# Priority (spec): focus (already excluded by caller) > cloud > seeing
	# > sky brightness > aperture/stability.
	if cond_cloud_atten > 0.35:
		return GameManager.text(
			"Clouds are crossing the target. Wait for a gap.",
			"云层正在遮挡目标。等云隙再观测。"
		)
	if str(observation.get("seeing_label", "Good")) != "Good":
		return GameManager.text(
			"Focus is fine - the air itself is unsteady. Lower the magnification.",
			"焦点没问题——是大气在抖动。降低倍率试试。"
		)
	var ratios: Dictionary = observation.get("ratios", {})
	var light_ratio := float(ratios.get("light", 1.0))
	var clarity_ratio := float(ratios.get("clarity", 1.0))
	var stability_ratio := float(ratios.get("stability", 1.0))
	var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
	if sky_key == "city" and light_ratio <= clarity_ratio and light_ratio <= stability_ratio:
		return GameManager.text(
			"City sky-glow is drowning the faint light. A darker site or bigger aperture would help.",
			"城市光污染淹没了微弱的光。更暗的观测点或更大口径会有帮助。"
		)
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	if type_lower.contains("nebula") or type_lower.contains("galaxy"):
		return GameManager.text(
			"Focus aligned, but deep-sky image is still too faint. Improve aperture/stability.",
			"焦点已对准，但深空图像仍太暗。需要更大口径或更高稳定性。"
		)
	return GameManager.text(
		"Focus aligned, but telescope quality is still too low.",
		"焦点已对准，但望远镜性能仍不足。"
	)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(self, Vector2.ZERO, Vector2(1024, 768), COL_BG)
	_pixel_frame(self, Vector2(12, 10), Vector2(1000, 744), Color(0.006, 0.008, 0.018), COL_BLUE_BORDER, COL_GOLD)
	if observation_mode == "naked_eye":
		_title_bar(GameManager.text("Naked Eye Observation", "肉眼观测"))
	else:
		_title_bar("Telescope View")

	var view := _scope_visual()
	view.position = Vector2(54, 98)
	add_child(view)
	_build_observation_panel()
	if drift_enabled:
		_build_drift_panel()
	if requires_focus:
		_refresh_focus_ui()


func _title_bar(title_text: String) -> void:
	_pixel_panel(self, Vector2(28, 20), Vector2(968, 60), COL_NAVY, COL_BLUE_BORDER)
	var title := _plabel(title_text, Vector2(28, 24), Vector2(968, 44), 26, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF


# ------------------------------------------------------------- right panel


func _build_observation_panel() -> void:
	_gold_panel(self, PANEL_POS, PANEL_SIZE)
	var quality := str(observation.get("quality", "Unknown"))

	var header := _plabel("Observation Quality", Vector2(CONTENT_X - 4, 118), Vector2(CONTENT_W + 8, 30), 19, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF

	var mystery := _mystery_description(selected_object)
	var observed := _plabel(
		GameManager.text("Observed: " + str(mystery.get("en", "")), "观测到：" + str(mystery.get("zh", ""))),
		Vector2(CONTENT_X, 162), Vector2(CONTENT_W, 32), 10, COL_TEXT
	)
	observed.max_lines_visible = 2

	quality_label = _plabel("Quality: " + quality, Vector2(CONTENT_X, 198), Vector2(CONTENT_W, 22), 15, _quality_color(quality))

	var feedback_y := 320.0
	if observation_mode == "naked_eye":
		_plabel(GameManager.text("Equipment: Naked Eye", "装备：肉眼"), Vector2(CONTENT_X, 232), Vector2(CONTENT_W, 40), 13, COL_GOLD_LIGHT)
	else:
		_add_stat_bars()
		var rows_end := _add_condition_rows()
		# 4 slots max (283/295/307/319); once slot 4 is used, feedback must
		# shift down from 320 to 332 and shrink to a single line to still
		# fit above the Focus block at y=348.
		if rows_end > CONDITION_ROW_Y + CONDITION_ROW_H * 3.0 + 0.5:
			feedback_y = 332.0

	if not GameManager.mission_steps().is_empty():
		# L10-style step checklist: squeezed onto the header row's right
		# side so it costs no extra vertical space (only levels with
		# mission_steps show it; currently just L10).
		mission_step_label = _plabel(_mission_step_progress_text(), Vector2(CONTENT_X - 4, 148), Vector2(CONTENT_W + 8, 12), 8, Color(0.70, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		mission_step_label.max_lines_visible = 1
		mission_step_label.clip_text = true

	var feedback_h := 26.0 if feedback_y <= 320.0 else 14.0
	feedback_label = _plabel(_current_feedback(), Vector2(CONTENT_X, feedback_y), Vector2(CONTENT_W, feedback_h), 9, Color(0.86, 0.90, 0.88))
	feedback_label.max_lines_visible = 1 if feedback_y > 320.0 else 2

	if requires_focus:
		_build_focus_block()

	_plabel("Identify", Vector2(CONTENT_X, 414), Vector2(CONTENT_W, 20), 16, Color(0.98, 0.82, 0.50))

	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(CONTENT_X, 436)
	choices_box.size = Vector2(CONTENT_W, 146)
	choices_box.add_theme_constant_override("separation", 6)
	add_child(choices_box)
	_add_identify_choices()

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(CONTENT_X, 600)
	bottom.size = Vector2(CONTENT_W, 38)
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)

	var retry := _pixel_button("Retry", Vector2(92, 38), 14)
	retry.pressed.connect(func() -> void: GameManager.go("sky"))
	bottom.add_child(retry)

	var back := _pixel_button("Back", Vector2(92, 38), 14)
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	bottom.add_child(back)


func _build_focus_block() -> void:
	if not allow_focus_input:
		_plabel("Focus", Vector2(CONTENT_X, 348), Vector2(70, 18), 13, COL_GOLD_LIGHT)
		var missing := _plabel(GameManager.text("Knob: not installed", "旋钮：未安装"), Vector2(CONTENT_X + 60, 346), Vector2(CONTENT_W - 60, 26), 9, Color(1.0, 0.45, 0.32), HORIZONTAL_ALIGNMENT_RIGHT)
		missing.max_lines_visible = 2
		focus_state_label = _plabel(
			GameManager.text("Install it at the Assembly Table.", "请回组装台安装调焦旋钮。"),
			Vector2(CONTENT_X, 378), Vector2(CONTENT_W, 32), 9, Color(1.0, 0.62, 0.40)
		)
		focus_state_label.max_lines_visible = 3
		return

	_plabel("Focus · Ctrl %d%%" % int(_focus_control_score()), Vector2(CONTENT_X, 350), Vector2(126, 18), 11, COL_GOLD_LIGHT)
	focus_pct_label = _plabel("", Vector2(CONTENT_X + 126, 351), Vector2(CONTENT_W - 126, 18), 11, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	focus_slider = HSlider.new()
	focus_slider.min_value = 0.0
	focus_slider.max_value = 1.0
	# A better focus knob gives finer slider control.
	focus_slider.step = 0.005 if _focus_control_score() >= 60.0 else 0.015
	focus_slider.value = focus_value
	focus_slider.position = Vector2(CONTENT_X, 370)
	focus_slider.size = Vector2(CONTENT_W, 18)
	focus_slider.value_changed.connect(func(value: float) -> void:
		if not updating_slider:
			_set_focus_value(value)
	)
	add_child(focus_slider)

	focus_state_label = _plabel("", Vector2(CONTENT_X, 388), Vector2(CONTENT_W, 24), 9, COL_TEXT)
	focus_state_label.max_lines_visible = 2


func _set_focus_value(value: float) -> void:
	focus_value = clampf(value, 0.0, 1.0)
	focus_error = absf(focus_value - target_focus_value)
	observation = _evaluate()
	_refresh_focus_ui()


# --------------------------------------------------------- E2 drift / track


const DRIFT_PANEL_POS := Vector2(54, 664)
const DRIFT_PANEL_SIZE := Vector2(560, 72)
const DRIFT_ROW_H := 20.0


func _build_drift_panel() -> void:
	# Center Hold / tracking UI lives below the scope circle, left of the
	# right-hand observation panel - never competes with it for space.
	# Three fixed, non-wrapping rows: Drift+Track status / Hold bar / rate slider.
	var panel_h := DRIFT_PANEL_SIZE.y if GameManager.has_tracking_mount_equipped() else DRIFT_PANEL_SIZE.y - DRIFT_ROW_H
	_pixel_panel(self, DRIFT_PANEL_POS, Vector2(DRIFT_PANEL_SIZE.x, panel_h), COL_NAVY, COL_BLUE_BORDER)
	var x := DRIFT_PANEL_POS.x + 12.0
	var y := DRIFT_PANEL_POS.y + 8.0

	drift_label = _plabel(_drift_status_text(), Vector2(x, y), Vector2(DRIFT_PANEL_SIZE.x - 24.0, 14), 10, Color(0.90, 0.86, 0.60))
	drift_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	drift_label.clip_text = true
	y += DRIFT_ROW_H

	if hold_seconds_required > 0.0:
		_rect(self, Vector2(x, y + 3.0), Vector2(74, 8), Color(0.10, 0.14, 0.22))
		hold_bar_fill = _rect(self, Vector2(x, y + 3.0), Vector2(0, 8), Color(0.45, 0.80, 0.95))
		hold_label = _plabel("", Vector2(x + 84.0, y - 2.0), Vector2(DRIFT_PANEL_SIZE.x - 24.0 - 84.0, 14), 9, Color(0.80, 0.90, 0.95))
		hold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		hold_label.clip_text = true
		y += DRIFT_ROW_H

	if GameManager.has_tracking_mount_equipped():
		var rate_label := _plabel("Rate速率", Vector2(x, y + 2.0), Vector2(90, 14), 9, Color(0.75, 0.85, 0.95))
		rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tracking_slider = HSlider.new()
		tracking_slider.min_value = 0.0
		tracking_slider.max_value = 2.0
		tracking_slider.step = 0.05
		tracking_slider.value = GameManager.tracking_rate()
		tracking_slider.position = Vector2(x + 88.0, y)
		tracking_slider.size = Vector2(200, 18)
		tracking_slider.value_changed.connect(func(value: float) -> void:
			GameManager.set_tracking_rate(value)
			_refresh_drift_ui()
		)
		add_child(tracking_slider)
		tracking_label = _plabel("", Vector2(x + 294.0, y + 2.0), Vector2(DRIFT_PANEL_SIZE.x - 24.0 - 294.0, 14), 9, Color(0.80, 0.90, 0.95))
		tracking_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	_refresh_drift_ui()


func _drift_status_text() -> String:
	# Compact single-line bilingual row (spec: no GameManager.text stacking
	# in tight UI rows - that returns a two-line "en\nzh" string).
	return "Drift漂移: On开启"


func _tracking_state_label() -> Dictionary:
	if not GameManager.has_tracking_mount_equipped():
		return {"en": "Off", "zh": "关"}
	var rate := GameManager.tracking_rate()
	if rate < 0.05:
		return {"en": "Off", "zh": "关"}
	if absf(rate - 1.0) <= 0.1:
		return {"en": "1x", "zh": "1倍"}
	return {"en": "Misaligned", "zh": "未对准"}


func _refresh_drift_ui() -> void:
	if drift_label != null:
		var tracking_state := _tracking_state_label()
		var track_text := "Track追踪: %s·%s" % [str(tracking_state.get("en", "")), str(tracking_state.get("zh", ""))]
		if GameManager.has_tracking_mount_equipped():
			var rate_error := absf(GameManager.tracking_rate() - 1.0)
			track_text += "  Δ%.2fx" % rate_error
		drift_label.text = "%s   %s" % [_drift_status_text(), track_text]
	if hold_bar_fill != null and hold_seconds_required > 0.0:
		var ratio := clampf(hold_timer / hold_seconds_required, 0.0, 1.0)
		hold_bar_fill.size = Vector2(74.0 * ratio, 8)
	if hold_label != null:
		hold_label.text = "Hold居中: %.1f/%.1fs" % [hold_timer, hold_seconds_required]
	if tracking_label != null:
		tracking_label.text = "%.2fx" % GameManager.tracking_rate()


func _refresh_focus_ui() -> void:
	_check_mission_step_progress()
	if mission_step_label != null:
		mission_step_label.text = _mission_step_progress_text()
	if focus_slider != null:
		updating_slider = true
		focus_slider.value = focus_value
		updating_slider = false
	if focus_pct_label != null:
		focus_pct_label.text = "%d%%  (Q/E)" % int(round(focus_value * 100.0))
	if focus_state_label != null and allow_focus_input:
		var state := _focus_state()
		match state:
			"sharp":
				# Sharp focus alone is not permission to identify - the
				# overall quality (and, on drift levels, the hold timer) must
				# also pass.
				if drift_enabled and not is_hold_satisfied():
					focus_state_label.text = _hold_progress_text()
					focus_state_label.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
				elif is_quality_acceptable():
					focus_state_label.text = GameManager.text("Image clear enough. Ready to identify.", "图像已足够清晰，可以识别。")
					focus_state_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
				else:
					focus_state_label.text = _quality_shortfall_text()
					focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			"slightly_blurry":
				focus_state_label.text = GameManager.text("Slightly blurry.", "略有模糊。")
				focus_state_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
			"blurry":
				focus_state_label.text = GameManager.text("Blurry. Keep adjusting.", "模糊，继续调整。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			_:
				focus_state_label.text = GameManager.text("Very blurry. Turn the focus knob.", "非常模糊，请转动调焦旋钮。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.30))
	var quality := str(observation.get("quality", "Unknown"))
	if quality_label != null:
		quality_label.text = "Quality: " + quality
		quality_label.add_theme_color_override("font_color", _quality_color(quality))
	if feedback_label != null:
		feedback_label.text = _current_feedback()
	if drift_enabled:
		_refresh_drift_ui()
	_update_target_visuals()


func _current_feedback() -> String:
	if requires_focus and not allow_focus_input:
		return GameManager.text(
			"A focus knob is required. Return to the Assembly Table and install it near the eyepiece.",
			"需要调焦旋钮。请回到组装台，把它安装在目镜附近。"
		)
	if not _missing_required_parts().is_empty():
		return _missing_required_parts_text()
	if drift_enabled and not is_hold_satisfied():
		return _hold_progress_text()
	if not is_focus_acceptable():
		return GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
	if requires_focus and not is_quality_acceptable():
		# The feedback box names the REAL limiting factor, in priority order
		# (cloud > seeing > sky brightness > aperture/stability): see
		# _quality_shortfall_text(). Only fall back to the generic "equip a
		# bigger lens" nebula copy when none of those environmental causes
		# are the dominant one.
		var type_lower := str(selected_object.get("type_en", "")).to_lower()
		var is_diffuse := type_lower.contains("nebula") or type_lower.contains("galaxy")
		var environmental_cause := cond_cloud_atten > 0.35 or str(observation.get("seeing_label", "Good")) != "Good"
		if is_diffuse and not environmental_cause:
			return GameManager.text(
				"Focus aligned, but the image is too faint. Equip a bigger lens / stable mount at the Parts Cabinet, then reassemble.",
				"焦点已对准，但图像太暗。请到零件柜换装大口径物镜和稳定支架，再重新组装。"
			)
		return _quality_shortfall_text()
	if requires_focus and can_identify_object():
		return GameManager.text("Image clear enough. Ready to identify.", "图像已足够清晰，可以识别。")
	return _short_feedback(str(observation.get("quality", "Unknown")))


func _add_stat_bars() -> void:
	var stats := GameManager.calculate_stats()
	var rows: Array = [
		{"name": "Light", "value": float(stats.get("light_score", 0.0))},
		{"name": "Clarity", "value": float(stats.get("clarity_score", 0.0))},
		{"name": "Stability", "value": float(stats.get("stability_score", 0.0))}
	]
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var value: float = float(row.get("value", 0.0))
		var y := 224.0 + float(index) * 20.0
		_plabel("%s %s" % [str(row.get("name", "")), snapped(value, 0.1)], Vector2(CONTENT_X, y), Vector2(96, 15), 10, Color(0.78, 0.86, 0.90))
		_rect(self, Vector2(CONTENT_X + 100, y + 3), Vector2(94, 8), Color(0.10, 0.14, 0.22))
		var fill_width := clampf(value, 0.0, 100.0) * 0.94
		_rect(self, Vector2(CONTENT_X + 100, y + 3), Vector2(fill_width, 8), Color(0.45, 0.75, 0.50))


# Dynamic condition-row slots (spec: UI 条件行重构). Slot 1 (equipment) is
# always shown; slots 2-4 (condition A / condition B / dark adaptation)
# appear only when there is something real to report. Returns the Y
# position immediately below the last slot used, so the caller can place
# feedback_label without overlapping.
const CONDITION_ROW_Y := 283.0
const CONDITION_ROW_H := 12.0


func _add_condition_rows() -> float:
	var y := CONDITION_ROW_Y
	y = _add_equipment_row(y)
	y = _add_condition_row_a(y)
	y = _add_condition_row_b(y)
	y = _add_dark_adaptation_row(y)
	return y


func _add_equipment_row(y: float) -> float:
	# Slot 1: "100mm · 10mm · 80.0x" - always shown.
	var stats := GameManager.calculate_stats()
	var objective := GameManager.get_part(GameManager.equipped_part_id("objective"))
	var eyepiece := GameManager.get_part(GameManager.equipped_part_id("eyepiece"))
	var objective_mm := int(objective.get("aperture_mm", 0))
	var eyepiece_mm := int(eyepiece.get("focal_length_mm", 0))
	var magnification := float(stats.get("magnification", 0.0))
	var equip_line := "%dmm · %dmm · %sx" % [objective_mm, eyepiece_mm, snapped(magnification, 0.1)]
	_plabel(equip_line, Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.72, 0.80, 0.88))
	return y + CONDITION_ROW_H


func _add_condition_row_a(y: float) -> float:
	# Slot 2: "Seeing视宁度: Poor·差  Cloud云: Thin·薄" - shown when either
	# seeing or cloud cover is defined for this level.
	var environment: Dictionary = GameManager.current_environment()
	var parts: Array[String] = []
	if environment.has("seeing"):
		var seeing_label := str(observation.get("seeing_label", ""))
		if seeing_label == "":
			seeing_label = str(environment.get("seeing", "")).capitalize()
		var seeing_zh := "好"
		match seeing_label:
			"Poor": seeing_zh = "差"
			"Average": seeing_zh = "中"
		parts.append("Seeing视宁度: %s·%s" % [seeing_label, seeing_zh])
	if cloud_cover_level > 0.0:
		var cloud_tier := _cloud_tier_label()
		parts.append("Cloud云: %s·%s" % [str(cloud_tier.get("en", "")), str(cloud_tier.get("zh", ""))])
	if parts.is_empty():
		return y
	_plabel("  ".join(parts), Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.95, 0.78, 0.45))
	return y + CONDITION_ROW_H


func _add_condition_row_b(y: float) -> float:
	# Slot 3: "Sky天空: City·城市  Contrast对比: Low·低" - shown when the
	# level defines a sky_brightness tier.
	var environment: Dictionary = GameManager.current_environment()
	if not environment.has("sky_brightness"):
		return y
	var sky_tier := _sky_tier_label()
	var contrast_tier := _contrast_label()
	var line := "Sky天空: %s·%s  Contrast对比: %s·%s" % [
		str(sky_tier.get("en", "")), str(sky_tier.get("zh", "")),
		str(contrast_tier.get("en", "")), str(contrast_tier.get("zh", ""))
	]
	_plabel(line, Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.95, 0.78, 0.45))
	return y + CONDITION_ROW_H


func _add_dark_adaptation_row(y: float) -> float:
	# Slot 4: dark adaptation % (left) + averted vision state (right) -
	# deep-sky targets only.
	if not _is_dark_adaptation_target():
		return y
	dark_adaptation_label = _plabel(
		"Dark adaptation: %d%%" % int(round(dark_adaptation * 100.0)),
		Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 8, Color(0.70, 0.82, 0.98)
	)
	averted_vision_label = _plabel(
		"Averted侧视: Active启用" if averted_vision_active else "Averted侧视: Inactive未启用",
		Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 8, Color(0.66, 0.72, 0.80), HORIZONTAL_ALIGNMENT_RIGHT
	)
	return y + CONDITION_ROW_H


func _short_feedback(quality: String) -> String:
	if observation_mode == "naked_eye":
		return GameManager.text(str(observation.get("feedback_en", "")), str(observation.get("feedback_zh", "")))
	match quality:
		"Excellent":
			return GameManager.text("Clear image. Ready to identify.", "图像清晰，可以识别目标。")
		"Good":
			return GameManager.text("Stable enough to identify.", "足够稳定，可以识别目标。")
		"Fair":
			return GameManager.text("Visible, but slightly unclear.", "可以看到目标，但略有不清。")
		"Poor":
			return GameManager.text("Too blurry. Improve alignment.", "太模糊了，请改进安装对齐。")
		"Failed":
			return GameManager.text("Observation failed. Reassemble or retry.", "观测失败，请重新组装或重试。")
	return GameManager.text("Observation complete.", "观测完成。")


func _add_identify_choices() -> void:
	var ids: Array[String] = []
	_add_unique(ids, str(selected_object.get("id", "")))
	_add_unique(ids, str(GameManager.current_target().get("id", "")))
	for id in _distractors_for(str(selected_object.get("id", ""))):
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	for id in ["sirius", "betelgeuse", "jupiter", "polaris"]:
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	if ids.size() > 4:
		ids.resize(4)
	for id in ids:
		var obj := GameManager.get_object(id)
		if obj.is_empty():
			continue
		# Single line "Moon · 月球" keeps buttons at 32 px in bilingual mode.
		var button := _pixel_button(GameManager.dict_text(obj, "name").replace("\n", " · "), Vector2(CONTENT_W, 32), 12)
		button.clip_text = true
		button.pressed.connect(_identify.bind(id))
		choices_box.add_child(button)


func _identify(choice_id: String) -> void:
	if requires_focus and not allow_focus_input:
		feedback_label.text = GameManager.text(
			"Install the Focus Knob before trying to identify this target.",
			"请先安装调焦旋钮，再尝试识别这个目标。"
		)
		return
	if not _missing_required_parts().is_empty():
		feedback_label.text = _missing_required_parts_text()
		return
	if drift_enabled and not is_hold_satisfied():
		feedback_label.text = _hold_progress_text()
		return
	if not is_focus_acceptable():
		feedback_label.text = GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
		return
	if choice_id != str(selected_object.get("id", "")):
		feedback_label.text = GameManager.text("Not what you observed. Try again.", "与观测到的目标不符，再试一次。")
		return
	if not is_quality_acceptable():
		# Correct answer, but the observation itself is not good enough:
		# the mission must not complete.
		if requires_focus:
			feedback_label.text = _quality_shortfall_text()
		else:
			feedback_label.text = GameManager.text(
				"Identified, but the observation quality is too low.",
				"识别正确，但观测质量不足。"
			)
		return
	var pending_step := GameManager.next_pending_mission_step()
	if not pending_step.is_empty():
		feedback_label.text = GameManager.text(
			"Not yet - complete: " + GameManager.dict_text(pending_step, "label"),
			"还没完成：" + GameManager.dict_text(pending_step, "label")
		)
		return
	# On success GameManager routes to the Mission Complete card itself.
	var completed := GameManager.complete_current_mission(choice_id, observation)
	if completed:
		return
	var target := GameManager.current_target()
	if choice_id != str(target.get("id", "")):
		feedback_label.text = GameManager.text("Correct, but not the mission target.", "识别正确，但不是当前任务目标。")
	else:
		feedback_label.text = GameManager.text("Identified, but quality is too low.", "识别正确，但观测质量不足。")


# ------------------------------------------------------------- scope visual


func _scope_visual() -> Control:
	var root := Control.new()
	root.size = Vector2(640, 620)
	var center := Vector2(318, 300)
	lens_center = center
	effect_seed = fmod(float(str(selected_object.get("id", "")).hash()), 100.0)
	cloud_cover_level = _cloud_cover() if observation_mode != "naked_eye" else 0.0
	if observation_mode == "naked_eye":
		# Open night sky, no telescope barrel.
		_circle(root, center - Vector2(262, 262), Vector2(524, 524), Color(0.006, 0.012, 0.032), Color(0.10, 0.14, 0.26), 3)
	else:
		_circle(root, center - Vector2(270, 270), Vector2(540, 540), Color(0.05, 0.036, 0.026), COL_GOLD_LIGHT, 8)
		_circle(root, center - Vector2(252, 252), Vector2(504, 504), Color(0.012, 0.018, 0.052), Color(0.31, 0.23, 0.15), 6)
		_circle(root, center - Vector2(218, 218), Vector2(436, 436), Color(0.0, 0.0, 0.0), Color(0.06, 0.08, 0.15), 5)
		_add_sky_background(root, center)
	_add_scope_stars(root, center)
	_add_target_visual(root, center)
	if observation_mode != "naked_eye":
		_add_cloud_layer(root, center)
		_add_crosshair(root, center)
	_add_quality_noise(root, center)
	return root


func _add_sky_background(parent: Control, center: Vector2) -> void:
	# Light-pollution background fill, clipped to the inner scope circle.
	# dark = pure black (no fill needed) / suburban / city get a lifted tint.
	var lift := _target_sky_lift()
	if lift <= 0.0:
		return
	var color := Color(0.020, 0.024, 0.036).lerp(Color(0.045, 0.052, 0.075), lift)
	var panel := Panel.new()
	panel.position = center - Vector2(218, 218)
	panel.size = Vector2(436, 436)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(218)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)


func _add_crosshair(parent: Control, center: Vector2) -> void:
	# Thin reticle lines with a wide gap so the target stays unobstructed.
	_rect(parent, center + Vector2(-170, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(55, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, -170), Vector2(2, 115), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, 55), Vector2(2, 115), COL_CROSSHAIR)


func _add_target_visual(parent: Control, scope_center: Vector2) -> void:
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = scope_center + _effect_offset(effect, quality) + drift_offset
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif effect == "dim" and quality in ["Poor", "Failed"]:
		base_alpha *= 0.55
	base_alpha = clampf(base_alpha + _dark_adaptation_alpha_bonus(), 0.0, 1.0)

	var path: String = _sprite_path_for_target(id, quality, effect)
	current_sprite_path = path
	var texture: Texture2D = _load_target_texture(path)

	var has_blur_variant := _has_blur_variant(id)
	var ghost_texture := texture
	if has_blur_variant:
		var state_textures: Dictionary = STATE_TEXTURES[id]
		ghost_texture = _load_target_texture(str(state_textures["blurry"]))

	var sprite_scale := 1.0
	if observation_mode == "naked_eye":
		sprite_scale = _naked_eye_scale(id)
	else:
		sprite_scale = _magnification_scale()
		if base_alpha > 0.0 and sprite_scale > 1.0:
			# Higher magnification spreads the same light over a larger
			# image: bigger but dimmer, same real telescope trade-off.
			base_alpha *= 0.85
		# The scaled sprite must stay inside the 436px scope circle - the
		# large state textures are already 300-360px at scale 1.0.
		var largest_dim := maxf(
			maxf(texture.get_size().x, texture.get_size().y),
			maxf(ghost_texture.get_size().x, ghost_texture.get_size().y)
		)
		if largest_dim > 0.0:
			sprite_scale = minf(sprite_scale, 380.0 / largest_dim)
	display_scale = sprite_scale

	ghost_a = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	ghost_b = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	main_sprite = _add_sprite(parent, texture, target_center, base_alpha, sprite_scale)
	if has_blur_variant:
		blur_overlay = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	if effect == "dim" and quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, base_alpha)
	if effect == "shaky":
		ghost_a.modulate.a = base_alpha * 0.30
		ghost_a.position += Vector2(-9, 5)
	_setup_turbulence_materials()
	# Poor/Failed contrast flattening + averted-vision brighten are applied
	# uniformly in _refresh_target_sprite (called below via
	# _update_target_visuals), so they stay correct every frame instead of
	# only at build time.
	# Deep-sky targets take an extra contrast hit under a city sky.
	if _is_diffuse_target() and observation_mode != "naked_eye":
		var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
		if sky_key == "city":
			base_alpha *= 0.8
	# Start the smoothed values converged so the scene doesn't animate in.
	visual_focus_error = focus_error
	visual_target_center = target_center
	visual_base_alpha = base_alpha
	blur_weight = _target_blur_weight()
	cond_turbulence = _target_turbulence()
	cond_sky_lift = _target_sky_lift()
	cond_cloud_atten = 0.0
	_apply_turbulence_uniforms()
	_update_target_visuals()


func _has_blur_variant(id: String) -> bool:
	return STATE_TEXTURES.has(id) and requires_focus and observation_mode != "naked_eye"


func _sprite_path_for_target(id: String, quality: String, effect: String) -> String:
	if STATE_TEXTURES.has(id):
		var textures: Dictionary = STATE_TEXTURES[id]
		if _has_blur_variant(id):
			# Focus blur is handled by the cross-fade overlay; the base
			# sprite only distinguishes light shortage (dim) vs sharp art.
			# Quality verdict only - visual_effect is a relative hint.
			if quality in ["Poor", "Failed"] and is_focus_acceptable():
				return str(textures["dim"])
			return str(textures["clear"])
		if effect == "dim" or quality in ["Poor", "Failed"]:
			return str(textures["dim"])
		if effect == "blurry" or quality == "Fair":
			return str(textures["blurry"])
		return str(textures["clear"])
	return str(SPRITE_MAP.get(id, SPRITE_MAP["polaris"]))


func _load_target_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path)
		if loaded != null:
			return loaded
	var image := Image.load_from_file(path)
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return load(SPRITE_MAP["polaris"])


func _naked_eye_alpha() -> float:
	# What your eyes can actually see: bright targets clear, deep sky ~gone.
	var visible := bool(selected_object.get("naked_eye_visible", false))
	if not visible:
		return 0.06
	var brightness := float(selected_object.get("brightness", 50.0))
	return clampf(0.35 + brightness / 130.0, 0.35, 1.0)


func _magnification_scale() -> float:
	# Higher magnification makes the target visibly larger in the eyepiece
	# (and, per base_alpha above, dimmer) - a real trade-off, not just text.
	# Stars stay point-like regardless of magnification (verdict 9): higher
	# power never turns a star into a resolvable disc.
	if _is_star_target():
		return 1.0
	var stats: Dictionary = GameManager.calculate_stats()
	var magnification := float(stats.get("magnification", 0.0))
	return clampf(magnification / 35.0, 1.0, 1.4)


func _naked_eye_scale(id: String) -> float:
	# No magnification: the Moon is small, planets are just points of light.
	match id:
		"moon":
			return 0.55
		"mars", "jupiter":
			return 0.28
		"orion_nebula", "andromeda":
			return 0.45
	return 0.55


func _refresh_target_sprite() -> void:
	# Re-pick the state texture (clear/blurry/dim) whenever the evaluation
	# changes - the build-time pick goes stale as soon as focus improves.
	if main_sprite == null:
		return
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = lens_center + _effect_offset(effect, quality) + drift_offset
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif effect == "dim" and quality in ["Poor", "Failed"]:
		base_alpha *= 0.55
	base_alpha = clampf(base_alpha + _dark_adaptation_alpha_bonus(), 0.0, 1.0)
	var path := _sprite_path_for_target(id, quality, effect)
	if path != current_sprite_path:
		current_sprite_path = path
		var texture: Texture2D = _load_target_texture(path)
		main_sprite.texture = texture
		main_sprite.size = texture.get_size()
		if blur_overlay == null:
			# No cross-fade overlay: ghosts share the base texture.
			ghost_a.texture = texture
			ghost_a.size = texture.get_size()
			ghost_b.texture = texture
			ghost_b.size = texture.get_size()
	if effect == "dim" and quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, main_sprite.modulate.a)
	else:
		var rgb := 1.0
		if quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
			# Contrast flattening for poor/failed quality (grain layer above
			# handles the noise half of this; this is the color-desaturation half).
			rgb *= 0.85
		if averted_vision_active and _is_diffuse_target():
			# Averted vision: subtle contour brighten, not a flat clean-up.
			rgb *= AVERTED_VISION_BRIGHTEN
		main_sprite.modulate = Color(rgb, rgb, rgb, main_sprite.modulate.a)
	_rebuild_quality_noise()


func _cloud_alpha_multiplier() -> float:
	# Clouds crossing the target darken it in real time - the 0.6s
	# re-evaluation loop (_advance_conditions) applies the same factor to
	# the actual quality math via extra_context["cloud_attenuation"].
	return 1.0 - 0.75 * cond_cloud_atten


func _update_target_visuals() -> void:
	if main_sprite == null:
		return
	_refresh_target_sprite()
	if not requires_focus:
		return
	# Defocus rendering, driven by SMOOTHED values so quantized inputs
	# (slider steps, quality tiers) never snap the image around.
	# NOTE: TextureRect scales from its top-left corner, so centering must
	# use size * display_scale, not the raw texture size.
	var spread := visual_focus_error * 130.0
	var cloud_mult := _cloud_alpha_multiplier()
	var ghost_alpha := clampf(visual_focus_error * 2.6, 0.0, 0.55) * visual_base_alpha * cloud_mult
	var origin := visual_target_center - main_sprite.size * display_scale * 0.5
	if blur_overlay != null:
		# Cross-fade: blurry photo dissolves into the sharp art.
		main_sprite.modulate.a = visual_base_alpha * (1.0 - blur_weight * 0.85) * cloud_mult
		blur_overlay.modulate.a = visual_base_alpha * blur_weight * cloud_mult
		blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5
	else:
		main_sprite.modulate.a = visual_base_alpha * clampf(1.0 - visual_focus_error * 1.1, 0.30, 1.0) * cloud_mult
	main_sprite.position = origin
	ghost_a.modulate.a = ghost_alpha
	ghost_a.position = visual_target_center - ghost_a.size * display_scale * 0.5 + Vector2(spread, spread * 0.6)
	ghost_b.modulate.a = ghost_alpha * 0.8
	ghost_b.position = visual_target_center - ghost_b.size * display_scale * 0.5 + Vector2(-spread * 0.8, spread * 0.4)


func _setup_turbulence_materials() -> void:
	# Only planets/moon get the UV-distortion shader (verdict 9): stars
	# flicker via alpha/position only, nebula/galaxy breathe via alpha only.
	turbulence_material_main = null
	turbulence_material_blur = null
	turbulence_material_ghost = null
	if _is_star_target() or _is_diffuse_target():
		return
	if main_sprite != null:
		var mat_main := ShaderMaterial.new()
		mat_main.shader = TURBULENCE_SHADER
		main_sprite.material = mat_main
		turbulence_material_main = mat_main
	if blur_overlay != null:
		var mat_blur := ShaderMaterial.new()
		mat_blur.shader = TURBULENCE_SHADER
		blur_overlay.material = mat_blur
		turbulence_material_blur = mat_blur
	if ghost_a != null:
		var mat_ghost := ShaderMaterial.new()
		mat_ghost.shader = TURBULENCE_SHADER
		ghost_a.material = mat_ghost
		ghost_b.material = mat_ghost
		turbulence_material_ghost = mat_ghost


func _add_sprite(parent: Control, texture: Texture2D, center: Vector2, alpha: float, sprite_scale: float = 1.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = texture.get_size()
	icon.scale = Vector2.ONE * sprite_scale
	icon.position = center - icon.size * sprite_scale * 0.5
	icon.modulate = Color(1, 1, 1, alpha)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _add_scope_stars(parent: Control, scope_center: Vector2) -> void:
	star_layer_nodes.clear()
	# All star dots live inside one container so drift (E2) can translate the
	# whole star field with a single position set - "the sky is turning",
	# not each star repositioned individually.
	star_layer_container = Control.new()
	star_layer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_layer_container.position = drift_offset
	parent.add_child(star_layer_container)
	if observation_mode == "naked_eye":
		_add_scope_stars_count(star_layer_container, scope_center, 34, 1.0)
		return
	# Light pollution thins out the faint background stars: city shows only
	# the brightest ~40%, suburban ~70%, dark sky shows all of them.
	var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
	var keep_fraction := 1.0
	match sky_key:
		"city":
			keep_fraction = 0.4
		"suburban":
			keep_fraction = 0.7
	_add_scope_stars_count(star_layer_container, scope_center, 34, keep_fraction)


func _add_scope_stars_count(parent: Control, scope_center: Vector2, total: int, keep_fraction: float) -> void:
	# fmod(i, 5) buckets brightness into 5 tiers (0.50 dimmest .. 0.82
	# brightest); keep only the brightest tiers so light pollution reads as
	# "fewer, brighter dots survive" rather than a uniform random thin-out.
	var keep_tiers: int = maxi(1, int(round(keep_fraction * 5.0)))
	for i in range(total):
		var pos := scope_center + Vector2(-178 + fmod(float(i * 83), 355.0), -178 + fmod(float(i * 47), 350.0))
		if (pos - scope_center).length() > 205:
			continue
		var tier := int(fmod(float(i), 5.0))
		var bright := 0.50 + float(tier) * 0.08
		if tier >= keep_tiers:
			continue
		var star_rect := _rect(parent, pos, Vector2(2, 2), Color(bright, bright + 0.03, 0.92, 0.50))
		star_layer_nodes.append(star_rect)


func _add_cloud_layer(parent: Control, scope_center: Vector2) -> void:
	cloud_nodes.clear()
	cloud_velocities.clear()
	if cloud_cover_level <= 0.0:
		return
	var tier := cloud_tier_index()  # 1 Thin / 2 Moderate / 3 Heavy
	var alpha_for_tier := 0.28
	match tier:
		2:
			alpha_for_tier = 0.5
		3:
			alpha_for_tier = 0.75
	var count: int = clampi(1 + tier, 2, 4)
	for i in range(count):
		var tex_path: String = CLOUD_TEXTURES[i % CLOUD_TEXTURES.size()]
		var texture: Texture2D = _load_target_texture(tex_path)
		var cloud := TextureRect.new()
		cloud.texture = texture
		cloud.stretch_mode = TextureRect.STRETCH_KEEP
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.size = texture.get_size()
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.modulate = Color(1, 1, 1, alpha_for_tier)
		# Deterministic per-index seed: same level always drifts the same
		# way, but the field still fills the scope circle unevenly.
		var seed_angle: float = fmod(float(i) * 137.5 + effect_seed, 360.0) * PI / 180.0
		var start_offset := Vector2(cos(seed_angle), sin(seed_angle) * 0.5) * (60.0 + float(i) * 35.0)
		cloud.position = scope_center + start_offset - cloud.size * 0.5
		var speed: float = 8.0 + fmod(float(i) * 3.7, 8.0)
		var direction := Vector2(1.0, 0.15 + fmod(float(i), 3.0) * 0.05).normalized()
		if i % 2 == 1:
			direction.x = -direction.x
		cloud_velocities.append(direction * speed)
		parent.add_child(cloud)
		cloud_nodes.append(cloud)


func _add_quality_noise(parent: Control, scope_center: Vector2) -> void:
	# Quality "grain" shader layer replaces the old white-dot noise system:
	# a single shimmering ColorRect masked to the scope circle, intensity
	# smoothly chased toward the current quality tier (never a hard cut).
	if observation_mode == "naked_eye":
		return
	grain_layer = ColorRect.new()
	grain_layer.position = scope_center - Vector2(218, 218)
	grain_layer.size = Vector2(436, 436)
	grain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GRAIN_SHADER
	mat.set_shader_parameter("intensity", 0.0)
	grain_layer.material = mat
	grain_material = mat
	parent.add_child(grain_layer)
	target_grain_intensity = _grain_intensity_for_quality(str(observation.get("quality", "Unknown")))
	grain_intensity = target_grain_intensity
	mat.set_shader_parameter("intensity", grain_intensity)


func _grain_intensity_for_quality(quality: String) -> float:
	match quality:
		"Excellent":
			return 0.0
		"Good":
			return 0.03
		"Fair":
			return 0.08
		"Poor":
			return 0.16
		"Failed":
			return 0.30
	return 0.0


func _rebuild_quality_noise() -> void:
	# Retarget the grain intensity toward the current quality tier; the
	# actual value is chased in _advance_conditions (no hard cuts).
	var quality := str(observation.get("quality", "Unknown"))
	target_grain_intensity = _grain_intensity_for_quality(quality)
	if grain_material == null:
		return
	if noise_quality == quality:
		return
	noise_quality = quality


# ------------------------------------------------------------------- logic


func _distractors_for(id: String) -> Array[String]:
	match id:
		"moon": return ["jupiter", "sirius"]
		"mars": return ["jupiter", "betelgeuse"]
		"jupiter": return ["mars", "moon"]
		"orion_nebula": return ["andromeda", "betelgeuse"]
		"andromeda": return ["orion_nebula", "sirius"]
	return ["sirius", "betelgeuse"]


func _mystery_description(obj: Dictionary) -> Dictionary:
	var id := str(obj.get("id", ""))
	match id:
		"moon":
			return {"en": "bright round object", "zh": "明亮圆形目标"}
		"mars", "jupiter":
			return {"en": "small disk-like object", "zh": "小圆盘状目标"}
		"orion_nebula":
			return {"en": "faint cloud-like object", "zh": "淡淡云雾状目标"}
		"andromeda":
			return {"en": "faint oval glow", "zh": "淡淡椭圆光斑"}
	return {"en": "star-like object", "zh": "星点状目标"}


func _effect_offset(effect: String, quality: String) -> Vector2:
	if effect == "shaky":
		return Vector2(10, -7)
	match quality:
		"Fair":
			return Vector2(6, -4)
		"Poor":
			return Vector2(12, 8)
	return Vector2.ZERO


func _quality_alpha(quality: String) -> float:
	match quality:
		"Excellent": return 1.0
		"Good": return 0.92
		"Fair": return 0.62
		"Poor": return 0.36
		"Failed": return 0.14
	return 0.80


func _quality_color(quality: String) -> Color:
	match quality:
		"Excellent": return Color(0.35, 1.0, 0.55)
		"Good": return Color(0.58, 0.92, 0.36)
		"Fair": return Color(0.95, 0.82, 0.28)
		"Poor": return Color(1.0, 0.55, 0.28)
		"Failed": return Color(1.0, 0.24, 0.24)
	return COL_TEXT


func _add_unique(ids: Array[String], id: String) -> void:
	if id != "" and not ids.has(id):
		ids.append(id)


# ----------------------------------------------------------------- helpers


func _pixel_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 3, false)


func _gold_panel(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	return _styled_panel(parent, pos, size, COL_PANEL, COL_GOLD, 3, 3, true)


func _pixel_frame(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, corner: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 4, true, corner)


func _styled_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, border_width: int, radius: int, decorated: bool, corner_color: Color = COL_GOLD) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	if decorated:
		_corner(parent, pos, corner_color)
		_corner(parent, pos + Vector2(size.x - 14, 0), corner_color)
		_corner(parent, pos + Vector2(0, size.y - 14), corner_color)
		_corner(parent, pos + size - Vector2(14, 14), corner_color)
	return panel


func _corner(parent: Control, pos: Vector2, color: Color) -> void:
	_rect(parent, pos, Vector2(12, 4), color)
	_rect(parent, pos, Vector2(4, 12), color)


func _pixel_button(text: String, min_size: Vector2 = Vector2(194, 32), font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.15, 0.25), COL_BLUE_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.23, 0.34), COL_GOLD_LIGHT))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.15, 0.08), COL_GOLD_LIGHT))
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _circle(parent: Control, pos: Vector2, size: Vector2, color: Color, border: Color, border_width: int) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(max(size.x, size.y) * 0.5))
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _plabel(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	# autowrap BEFORE size, otherwise the text's minimum width clamps the
	# label wider than the panel.
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
