extends RefCounted
class_name SpaceObservationModel

# Pure, deterministic JWST-class space-infrared observation model. No nodes, so
# tests and the space_observation UI drive the same logic. Every stage feeds the
# next, so the final science image really depends on the player's choices.
#
# It shares NOTHING with the ground-optical mechanics: no eyepiece, objective,
# magnification, manual focus knob, finder scope or collimation. Its own state
# lives under the space_observation namespace.
#
# Pipeline stages (mirrors the UI):
#   PLAN     instrument / filter / exposure / integrations / dither / priority
#   DEPLOY   ordered unfold of the observatory (first-time)
#   THERMAL  sun/earth/moon safe-attitude + sunshield + temperatures
#   GUIDE    guide-star pick + attitude drift + fine-guidance lock
#   WAVEFRONT segment alignment -> merge split star images -> low wavefront error
#   EXPOSE   photon accumulation, background, cosmic rays, saturation, frames
#   PROCESS  select/align/remove-CR/stack/background/SNR
#   FILTER   map bands to R/G/B, pick the science interpretation
#   REPORT   SNR / exposure quality / pointing / thermal / frames / confidence

# ------------------------------------------------------------------ target
var target_id := "andromeda"
var target_kind := "galaxy"          # galaxy | nebula | star | star_forming | distant_galaxy
var target_brightness := 0.55        # 0..1 (drives saturation vs weak-signal)
var best_instrument := "nircam"
var best_filter := "near_infrared"
var true_science := "dust_rich"      # correct scientific interpretation
var redshifted := false

# ------------------------------------------------------------------ 1. PLAN
const INSTRUMENTS := ["nircam", "nirspec", "miri", "fgs_niriss"]
const FILTERS := ["near_infrared", "mid_infrared", "dust", "star_forming", "emission_line"]
const DITHERS := ["none", "two_point", "three_point", "box"]
const PRIORITIES := ["survey", "balanced", "deep"]

var instrument := "nircam"
var filter := "near_infrared"
var exposure_time := 300.0           # seconds per frame
var integrations := 4                # number of frames
var dither := "three_point"
var priority := "balanced"

# ------------------------------------------------------------------ 2. DEPLOY
const DEPLOY_ORDER := ["solar_array", "sunshield", "primary_mirror", "secondary_mirror", "hinges", "actuators"]
var deployed: Array = []
var deploy_locked := false           # every step latched?

# ------------------------------------------------------------------ 3. THERMAL
var attitude_deg := 40.0             # observatory boresight vs the sun line
var sun_angle := 40.0
var earth_angle := 150.0
var moon_angle := 120.0
var hot_side_temp := 350.0           # K (sun side)
var cold_side_temp := 45.0           # K (mirror side)
const SAFE_MIN := 85.0               # sun must stay 85..135 deg off boresight
const SAFE_MAX := 135.0
const COLD_TARGET := 40.0            # optics must reach ~40 K (7 K extra for MIRI)

# ------------------------------------------------------------------ 4. GUIDE
var guide_stars: Array = []          # each {id, brightness, offset, usable}
var chosen_guide := -1
var pointing_error := 8.0            # arcsec
var drift_rate := 0.9                # arcsec/s before lock
var guide_locked := false

# ------------------------------------------------------------------ 5. WAVEFRONT
var segment_alignment := 0.25        # 0..1
var wavefront_error_nm := 900.0      # target < 150 nm
var calibration_progress := 0.0

# ------------------------------------------------------------------ 6. EXPOSE
var frames: Array = []               # each {signal, cosmic_ray, saturated, kept}
var acquired := false

# ------------------------------------------------------------------ 7. PROCESS
var frames_aligned := false
var cosmic_rays_removed := false
var stacked := false
var background_subtracted := false

# ------------------------------------------------------------------ 8. FILTER
var channel_map := {"R": "", "G": "", "B": ""}
var chosen_science := ""


func configure(profile: Dictionary) -> void:
	target_id = str(profile.get("target_id", target_id))
	target_kind = str(profile.get("kind", target_kind))
	target_brightness = float(profile.get("brightness", target_brightness))
	best_instrument = str(profile.get("best_instrument", best_instrument))
	best_filter = str(profile.get("best_filter", best_filter))
	true_science = str(profile.get("science", true_science))
	redshifted = bool(profile.get("redshifted", false))
	# starting (deliberately non-ideal) plan
	instrument = str(profile.get("start_instrument", "nircam"))
	filter = str(profile.get("start_filter", "near_infrared"))
	exposure_time = float(profile.get("start_exposure", 120.0))
	integrations = int(profile.get("start_integrations", 2))
	dither = str(profile.get("start_dither", "none"))
	priority = "balanced"
	deployed.clear()
	deploy_locked = false
	attitude_deg = float(profile.get("start_attitude", 40.0))
	_recompute_thermal()
	_build_guide_stars(profile)
	segment_alignment = 0.25
	wavefront_error_nm = 900.0
	calibration_progress = 0.0
	frames.clear()
	acquired = false
	frames_aligned = false
	cosmic_rays_removed = false
	stacked = false
	background_subtracted = false
	channel_map = {"R": "", "G": "", "B": ""}
	chosen_science = ""


# ============================================================= 1. PLANNING
func plan_hint(field: String, value: String) -> Dictionary:
	# Every option says what it suits / enhances / sacrifices plus its SNR & time
	# cost. Text is bilingual (the UI picks the language) so neither mode bleeds.
	var t: Dictionary = _HINTS.get(field, {}).get(value, {})
	return {
		"suits_en": t.get("s_en", ""), "suits_zh": t.get("s_zh", ""),
		"enhances_en": t.get("e_en", ""), "enhances_zh": t.get("e_zh", ""),
		"sacrifices_en": t.get("x_en", ""), "sacrifices_zh": t.get("x_zh", ""),
		"snr": t.get("snr", 1.0), "time": t.get("time", 1.0),
	}


const _HINTS := {
	"instrument": {
		"nircam": {"s_en": "near-IR imaging of stars & galaxies", "s_zh": "恒星与星系的近红外成像", "e_en": "sharp structure", "e_zh": "清晰结构", "x_en": "no spectrum", "x_zh": "没有光谱", "snr": 1.0, "time": 1.0},
		"nirspec": {"s_en": "spectra: composition, motion, redshift", "s_zh": "光谱：成分、运动、红移", "e_en": "spectral lines", "e_zh": "谱线", "x_en": "no wide image", "x_zh": "没有宽场图像", "snr": 0.85, "time": 1.2},
		"miri": {"s_en": "mid-IR cold dust & molecules", "s_zh": "中红外冷尘埃与分子", "e_en": "cold dust", "e_zh": "冷尘埃", "x_en": "needs 7 K, slower", "x_zh": "需要 7K，更慢", "snr": 0.8, "time": 1.4},
		"fgs_niriss": {"s_en": "precise guiding + niche near-IR", "s_zh": "精确导星 + 特定近红外", "e_en": "pointing", "e_zh": "指向", "x_en": "weak imaging", "x_zh": "成像较弱", "snr": 0.7, "time": 1.0},
	},
	"filter": {
		"near_infrared": {"s_en": "young stars, galaxies", "s_zh": "年轻恒星、星系", "e_en": "stellar cores", "e_zh": "恒星核心", "x_en": "misses coldest dust", "x_zh": "看不到最冷的尘埃", "snr": 1.0, "time": 1.0},
		"mid_infrared": {"s_en": "cold dust, distant galaxies", "s_zh": "冷尘埃、遥远星系", "e_en": "cold structure", "e_zh": "冷结构", "x_en": "brighter thermal background", "x_zh": "热背景更强", "snr": 0.85, "time": 1.2},
		"dust": {"s_en": "dust lanes & clouds", "s_zh": "尘埃带与尘埃云", "e_en": "dust", "e_zh": "尘埃", "x_en": "faint on hot stars", "x_zh": "对高温恒星较弱", "snr": 0.9, "time": 1.0},
		"star_forming": {"s_en": "star-forming knots", "s_zh": "恒星形成结点", "e_en": "young nurseries", "e_zh": "年轻恒星苗圃", "x_en": "loses old stars", "x_zh": "丢失老年恒星", "snr": 0.9, "time": 1.0},
		"emission_line": {"s_en": "hot gas emission", "s_zh": "高温气体发射", "e_en": "ionised gas", "e_zh": "电离气体", "x_en": "narrow, needs more time", "x_zh": "窄带，需要更多时间", "snr": 0.8, "time": 1.3},
	},
	"dither": {
		"none": {"s_en": "fastest", "s_zh": "最快", "e_en": "nothing", "e_zh": "无", "x_en": "keeps bad pixels & gaps", "x_zh": "保留坏点与缝隙", "snr": 0.85, "time": 1.0},
		"two_point": {"s_en": "basic defect removal", "s_zh": "基础缺陷去除", "e_en": "cleaner", "e_zh": "更干净", "x_en": "small time cost", "x_zh": "少量时间成本", "snr": 1.0, "time": 1.1},
		"three_point": {"s_en": "good defect + gap filling", "s_zh": "良好缺陷与缝隙填补", "e_en": "clean image", "e_zh": "干净图像", "x_en": "more time", "x_zh": "更多时间", "snr": 1.08, "time": 1.2},
		"box": {"s_en": "best sampling", "s_zh": "最佳采样", "e_en": "sharpest", "e_zh": "最锐利", "x_en": "most time", "x_zh": "时间最多", "snr": 1.12, "time": 1.35},
	},
}


func instrument_match() -> float:
	return 1.0 if instrument == best_instrument else 0.55


func filter_match() -> float:
	return 1.0 if filter == best_filter else 0.5


func planned_total_time() -> float:
	var dh: Dictionary = plan_hint("dither", dither)
	return exposure_time * float(integrations) * float(dh.get("time", 1.0))


func saturates() -> bool:
	# a bright target with very long single exposures overexposes
	return exposure_time > 500.0 and target_brightness > 0.7


func underexposed() -> bool:
	return exposure_time * float(integrations) < 300.0


# ============================================================= 2. DEPLOYMENT
func can_deploy(step: String) -> bool:
	if deployed.has(step):
		return false
	var idx := DEPLOY_ORDER.find(step)
	if idx < 0:
		return false
	return idx == deployed.size()     # must be the next in order


func deploy(step: String) -> bool:
	if not can_deploy(step):
		return false
	deployed.append(step)
	if deployed.size() == DEPLOY_ORDER.size():
		deploy_locked = true
	return true


func deploy_blocked_reason(step: String) -> String:
	if deployed.has(step):
		return "already_deployed"
	var idx := DEPLOY_ORDER.find(step)
	if idx < 0:
		return "unknown"
	if idx > deployed.size():
		return "out_of_order"          # needs the previous stage first
	return ""


func fully_deployed() -> bool:
	return deploy_locked


# ============================================================= 3. THERMAL
func rotate_to(attitude: float) -> void:
	attitude_deg = clampf(attitude, 0.0, 180.0)
	_recompute_thermal()


func _recompute_thermal() -> void:
	sun_angle = attitude_deg
	# earth & moon trail the sun line; they stay roughly opposite the cold side
	earth_angle = wrapf(attitude_deg + 110.0, 0.0, 180.0)
	moon_angle = wrapf(attitude_deg + 80.0, 0.0, 180.0)
	# when the sunshield faces the sun (safe zone) the cold side stays cold
	var in_zone := attitude_deg >= SAFE_MIN and attitude_deg <= SAFE_MAX
	var penalty := 0.0
	if not in_zone:
		penalty = minf(absf(attitude_deg - clampf(attitude_deg, SAFE_MIN, SAFE_MAX)), 90.0)
	cold_side_temp = COLD_TARGET + penalty * 2.4
	hot_side_temp = 300.0 + (85.0 - absf(attitude_deg - 90.0)) * 0.4


func sun_safe() -> bool:
	return sun_angle >= SAFE_MIN and sun_angle <= SAFE_MAX


func thermal_ok() -> bool:
	var limit := 7.0 if instrument == "miri" else COLD_TARGET + 8.0
	if instrument == "miri":
		# MIRI needs the extra cryocooler; model it as a tighter cold ceiling
		return sun_safe() and cold_side_temp <= COLD_TARGET + 4.0
	return sun_safe() and cold_side_temp <= limit


func thermal_stability() -> float:
	var over := maxf(0.0, cold_side_temp - COLD_TARGET)
	return clampf(1.0 - over / 60.0, 0.0, 1.0)


func safe_to_observe() -> bool:
	return sun_safe() and thermal_ok()


# ============================================================= 4. GUIDE STAR
func _build_guide_stars(profile: Dictionary) -> void:
	guide_stars.clear()
	var preset: Variant = profile.get("guide_stars", [])
	if typeof(preset) == TYPE_ARRAY and not (preset as Array).is_empty():
		for e in preset:
			guide_stars.append(e)
	else:
		guide_stars = [
			{"id": "GS-1", "brightness": 0.28, "offset": 4.0, "usable": false},   # too dim
			{"id": "GS-2", "brightness": 0.82, "offset": 2.0, "usable": true},    # good
			{"id": "GS-3", "brightness": 0.9, "offset": 14.0, "usable": false},   # too far off-detector
			{"id": "GS-4", "brightness": 0.66, "offset": 3.2, "usable": true},    # ok
		]
	chosen_guide = -1
	pointing_error = 8.0
	drift_rate = 0.9
	guide_locked = false


func choose_guide_star(index: int) -> bool:
	if index < 0 or index >= guide_stars.size():
		return false
	chosen_guide = index
	var gs: Dictionary = guide_stars[index]
	if not bool(gs.get("usable", false)):
		# dim or off-detector stars cannot hold a lock
		drift_rate = 1.4
		guide_locked = false
		return false
	drift_rate = lerpf(0.6, 0.05, float(gs.get("brightness", 0.5)))
	pointing_error = float(gs.get("offset", 3.0)) + 4.0
	return true


func nudge_pointing(delta: float) -> void:
	pointing_error = maxf(0.0, pointing_error + delta)


func step_guiding(dt: float) -> void:
	# fine guidance pulls the error down only if a usable star is chosen
	if chosen_guide < 0:
		return
	var gs: Dictionary = guide_stars[chosen_guide]
	if not bool(gs.get("usable", false)):
		pointing_error += drift_rate * dt      # drifts away
		return
	pointing_error = maxf(0.0, pointing_error - (2.0 - drift_rate) * dt * 3.0)
	guide_locked = pointing_error <= 1.2


func guide_quality() -> float:
	if chosen_guide < 0:
		return 0.0
	var gs: Dictionary = guide_stars[chosen_guide]
	if not bool(gs.get("usable", false)):
		return 0.1
	return clampf(float(gs.get("brightness", 0.5)) - float(gs.get("offset", 3.0)) / 30.0, 0.0, 1.0)


# ============================================================= 5. WAVEFRONT
func align_step(amount: float) -> void:
	set_segment_alignment(segment_alignment + amount)


func set_segment_alignment(value: float) -> void:
	segment_alignment = clampf(value, 0.0, 1.0)
	wavefront_error_nm = lerpf(900.0, 60.0, segment_alignment)
	calibration_progress = clampf(segment_alignment, 0.0, 1.0)


func psf_sharpness() -> float:
	# split star images merge into one sharp peak as alignment improves
	return clampf(1.0 - wavefront_error_nm / 900.0, 0.0, 1.0)


func wavefront_ok() -> bool:
	return wavefront_error_nm <= 150.0


# ============================================================= 6. EXPOSURE
func acquire() -> void:
	frames.clear()
	var per_frame := clampf(exposure_time / 300.0, 0.2, 2.0)
	var dh: Dictionary = plan_hint("dither", dither)
	var base_signal := per_frame * target_brightness * instrument_match() * filter_match() * float(dh.get("snr", 1.0))
	# a deterministic cosmic-ray pattern: roughly one hit every 3rd frame
	for i in range(integrations):
		var cosmic := (i % 3 == 2)
		var saturated := saturates()
		var sig := base_signal * (0.6 + 0.4 * float(i + 1) / float(integrations))
		frames.append({"signal": sig, "cosmic_ray": cosmic, "saturated": saturated, "kept": true})
	acquired = true


func photon_progress(elapsed_ratio: float) -> Dictionary:
	# for the animated acquisition bar: signal rises, noise falls with sqrt(frames)
	var f := clampf(elapsed_ratio, 0.0, 1.0)
	var shown := int(round(f * integrations))
	return {
		"frames_done": shown,
		"signal": clampf(f * target_brightness * 1.1, 0.0, 1.0),
		"noise": clampf(0.6 / sqrt(maxf(1.0, f * integrations)), 0.0, 1.0),
		"cosmic_this_frame": (shown % 3 == 0 and shown > 0),
	}


func exposure_quality() -> float:
	if saturates():
		return 0.35
	if underexposed():
		return 0.45
	return clampf(0.7 + 0.3 * clampf(float(integrations) / 6.0, 0.0, 1.0), 0.0, 1.0)


# ============================================================= 7. PROCESSING
func toggle_keep(index: int, keep: bool) -> void:
	if index >= 0 and index < frames.size():
		frames[index]["kept"] = keep


func kept_frames() -> int:
	var n := 0
	for f in frames:
		if bool(f.get("kept", false)):
			n += 1
	return n


func align_frames() -> void:
	frames_aligned = true


func remove_cosmic_rays() -> void:
	cosmic_rays_removed = true


func stack() -> void:
	stacked = true


func subtract_background() -> void:
	background_subtracted = true


func cosmic_ray_rejection() -> float:
	if not cosmic_rays_removed:
		return 0.0
	# rejection also credits dropping the worst frames manually
	var cr_frames := 0
	var dropped := 0
	for f in frames:
		if bool(f.get("cosmic_ray", false)):
			cr_frames += 1
			if not bool(f.get("kept", false)):
				dropped += 1
	var auto := 0.7
	if cr_frames > 0:
		auto += 0.3 * float(dropped) / float(cr_frames)
	return clampf(auto, 0.0, 1.0)


func pointing_accuracy() -> float:
	return clampf(1.0 - pointing_error / 8.0, 0.0, 1.0) if guide_locked else clampf(0.4 - pointing_error / 20.0, 0.0, 0.4)


func snr() -> float:
	if not acquired:
		return 0.0
	var kept := kept_frames()
	if kept == 0:
		return 0.0
	var chain := 0.0
	chain += 0.20 * exposure_quality()
	chain += 0.18 * pointing_accuracy()
	chain += 0.16 * thermal_stability()
	chain += 0.16 * psf_sharpness()
	chain += 0.10 * guide_quality()
	chain += 0.10 * (1.0 if stacked else 0.3)
	chain += 0.10 * cosmic_ray_rejection()
	var stack_gain := sqrt(float(kept)) if stacked else 1.0
	# the chosen instrument + filter set how much real target signal is collected,
	# so a poor match genuinely lowers the achievable SNR
	var signal_factor := 0.5 + 0.5 * instrument_match() * filter_match()
	var raw := chain * stack_gain * 12.0 * signal_factor
	if saturates():
		raw *= 0.5
	if not background_subtracted:
		raw *= 0.8
	return clampf(raw, 0.0, 99.0)


func processing_ready() -> bool:
	return frames_aligned and cosmic_rays_removed and stacked and background_subtracted


# ============================================================= 8. FILTER MAP
func set_channel(channel: String, filter_id: String) -> void:
	if channel_map.has(channel):
		channel_map[channel] = filter_id


func mapping_complete() -> bool:
	return channel_map["R"] != "" and channel_map["G"] != "" and channel_map["B"] != "" \
		and channel_map["R"] != channel_map["G"] and channel_map["G"] != channel_map["B"] and channel_map["R"] != channel_map["B"]


func science_options() -> Array:
	return ["dust_rich", "star_forming", "old_stellar", "hot_gas", "distant_galaxy"]


func choose_science(option: String) -> void:
	chosen_science = option


func science_correct() -> bool:
	return chosen_science == true_science


# ============================================================= REPORT
func spectral_confidence() -> float:
	var c := 0.5 * filter_match() + 0.3 * clampf(snr() / 20.0, 0.0, 1.0) + 0.2 * psf_sharpness()
	if mapping_complete():
		c += 0.1
	return clampf(c, 0.0, 1.0)


func report() -> Dictionary:
	return {
		"target_id": target_id,
		"snr": snr(),
		"exposure_quality": exposure_quality(),
		"pointing_accuracy": pointing_accuracy(),
		"thermal_stability": thermal_stability(),
		"frame_count": kept_frames(),
		"cosmic_ray_rejection": cosmic_ray_rejection(),
		"filter": filter,
		"instrument": instrument,
		"scientific_confidence": spectral_confidence(),
		"science_finding": chosen_science,
		"science_correct": science_correct(),
		"success": snr() >= 10.0 and science_correct() and safe_to_observe(),
	}
