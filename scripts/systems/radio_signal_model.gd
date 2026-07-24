extends RefCounted
class_name RadioSignalModel

# Pure, deterministic FAST radio-observation model - no nodes, no rendering, so
# it can be driven headlessly by tests and by the radio_observation UI alike.
#
# The five real concepts a radio astronomer uses (none of them optical):
#   1. Feed-cabin pointing with inertia   -> az/alt with velocity + damping
#   2. Frequency tuning                    -> a (centre, bandwidth) window over a
#                                             live spectrum of noise + RFI + source
#   3. RFI discrimination                  -> classify man-made peaks vs the source
#   4. Pulsar folding                      -> trial period + dispersion measure
#   5. Integration                         -> longer integration raises SNR
#
# Everything derives from the target profile, so different targets/levels play
# differently without any new code.

# ---- target profile ----
var target_id := "pulsar_b0329"
var target_kind := "pulsar"          # pulsar | frb | hydrogen | galaxy | solar | unknown
var true_azimuth := 145.0
var true_altitude := 52.0
var true_period_ms := 714.0          # pulse period (pulsars only)
var true_dm := 26.8                  # dispersion measure (pc/cm^3)
var true_center_mhz := 1250.0        # source band centre
var true_bandwidth_mhz := 90.0
var source_strength := 1.0           # relative flux (weak-signal nights < 1)
var rfi_peaks: Array = []            # each: {mhz, strength, is_rfi:bool, source}

# ---- feed cabin state ----
var azimuth := 150.0
var altitude := 40.0
var az_velocity := 0.0
var alt_velocity := 0.0
var cable_tension := 0.30            # 0..1, rises with speed
const MAX_SLEW := 18.0               # deg/s cap
const DAMPING := 2.4                 # velocity damping per second
const ACCEL := 26.0                  # deg/s^2 per nudge unit
const LOCK_TOLERANCE := 2.2          # deg pointing error to count as on-target
const STABLE_SPEED := 1.4            # deg/s below which pointing is "settled"

# ---- frequency window ----
var window_center_mhz := 1400.0
var window_bandwidth_mhz := 80.0
const BAND_MIN := 1000.0
const BAND_MAX := 1500.0

# ---- folding / integration ----
var trial_period_ms := 500.0
var trial_dm := 0.0
var integration_s := 0.0
const MAX_INTEGRATION := 600.0

# ---- classification bookkeeping ----
var classifications := {}            # index -> "rfi" | "source"


func configure(profile: Dictionary) -> void:
	target_id = str(profile.get("target_id", target_id))
	target_kind = str(profile.get("kind", target_kind))
	true_azimuth = float(profile.get("azimuth", true_azimuth))
	true_altitude = float(profile.get("altitude", true_altitude))
	true_period_ms = float(profile.get("period_ms", true_period_ms))
	true_dm = float(profile.get("dm", true_dm))
	true_center_mhz = float(profile.get("center_mhz", true_center_mhz))
	true_bandwidth_mhz = float(profile.get("bandwidth_mhz", true_bandwidth_mhz))
	source_strength = float(profile.get("source_strength", source_strength))
	# start the cabin a realistic distance off-target
	azimuth = true_azimuth + float(profile.get("start_offset_az", 24.0))
	altitude = true_altitude - float(profile.get("start_offset_alt", 16.0))
	az_velocity = 0.0
	alt_velocity = 0.0
	window_center_mhz = float(profile.get("start_center_mhz", 1400.0))
	trial_period_ms = float(profile.get("start_period_ms", 500.0))
	trial_dm = 0.0
	integration_s = 0.0
	classifications.clear()
	_build_rfi(profile)


func _build_rfi(profile: Dictionary) -> void:
	rfi_peaks.clear()
	# The source itself is a "peak" the player must keep (is_rfi = false).
	rfi_peaks.append({"mhz": true_center_mhz, "strength": 0.85 * source_strength,
		"is_rfi": false, "source": "celestial"})
	# Deterministic man-made interference - seeded off the target id length so
	# each target has its own RFI environment without Math.random().
	var seed: Variant = profile.get("rfi", [])
	if typeof(seed) == TYPE_ARRAY and not (seed as Array).is_empty():
		for entry in seed:
			var e: Dictionary = entry
			rfi_peaks.append({"mhz": float(e.get("mhz", 1100.0)), "strength": float(e.get("strength", 0.7)),
				"is_rfi": true, "source": str(e.get("source", "rfi"))})
		return
	var presets := [
		{"mhz": 1090.0, "strength": 0.95, "source": "radar"},
		{"mhz": 1176.0, "strength": 0.80, "source": "satellite"},
		{"mhz": 1310.0, "strength": 0.72, "source": "phone"},
		{"mhz": 1447.0, "strength": 0.66, "source": "powerline"},
	]
	for p in presets:
		rfi_peaks.append({"mhz": float(p["mhz"]), "strength": float(p["strength"]),
			"is_rfi": true, "source": str(p["source"])})


# ---------------------------------------------------------------- 1. pointing
func nudge(d_az: float, d_alt: float) -> void:
	az_velocity = clampf(az_velocity + d_az * ACCEL * 0.1, -MAX_SLEW, MAX_SLEW)
	alt_velocity = clampf(alt_velocity + d_alt * ACCEL * 0.1, -MAX_SLEW, MAX_SLEW)


func step(dt: float) -> void:
	# inertia + exponential damping = the cabin coasts and settles, never snaps
	azimuth += az_velocity * dt
	altitude += alt_velocity * dt
	var damp := clampf(1.0 - DAMPING * dt, 0.0, 1.0)
	az_velocity *= damp
	alt_velocity *= damp
	altitude = clampf(altitude, 5.0, 88.0)
	var speed := pointing_speed()
	# cable tension tracks how hard the drive is working
	cable_tension = clampf(0.22 + speed / MAX_SLEW * 0.85, 0.0, 1.0)


func pointing_error() -> float:
	var d_az := wrapf(azimuth - true_azimuth, -180.0, 180.0)
	return sqrt(d_az * d_az + (altitude - true_altitude) * (altitude - true_altitude))


func pointing_speed() -> float:
	return sqrt(az_velocity * az_velocity + alt_velocity * alt_velocity)


func is_on_target() -> bool:
	return pointing_error() <= LOCK_TOLERANCE


func is_locked() -> bool:
	return is_on_target() and pointing_speed() <= STABLE_SPEED


func tension_warning() -> bool:
	return cable_tension >= 0.9


# ---------------------------------------------------------------- 2. tuning
func window_covers_source() -> float:
	# fraction of the source band that falls inside the tuned window (0..1)
	var lo := window_center_mhz - window_bandwidth_mhz * 0.5
	var hi := window_center_mhz + window_bandwidth_mhz * 0.5
	var s_lo := true_center_mhz - true_bandwidth_mhz * 0.5
	var s_hi := true_center_mhz + true_bandwidth_mhz * 0.5
	var overlap := minf(hi, s_hi) - maxf(lo, s_lo)
	return clampf(overlap / true_bandwidth_mhz, 0.0, 1.0)


func window_rfi_load() -> float:
	# how much strong RFI sits inside the window (0..1) - the player must avoid it
	var lo := window_center_mhz - window_bandwidth_mhz * 0.5
	var hi := window_center_mhz + window_bandwidth_mhz * 0.5
	var load := 0.0
	for peak in rfi_peaks:
		if not bool(peak["is_rfi"]):
			continue
		if float(peak["mhz"]) >= lo and float(peak["mhz"]) <= hi:
			load = maxf(load, float(peak["strength"]))
	return load


func tuning_quality() -> float:
	return clampf(window_covers_source() - window_rfi_load() * 0.8, 0.0, 1.0)


func spectrum_samples(count: int) -> Array:
	# deterministic spectrum for drawing: noise floor + source bump + RFI spikes
	var out: Array = []
	for i in range(count):
		var mhz := BAND_MIN + (BAND_MAX - BAND_MIN) * float(i) / float(max(1, count - 1))
		var v := 0.12 + 0.05 * sin(mhz * 0.09)     # noise floor ripple
		# source bump (broad)
		var ds := (mhz - true_center_mhz) / (true_bandwidth_mhz * 0.6)
		v += 0.55 * source_strength * exp(-ds * ds)
		# RFI spikes (narrow, tall)
		for peak in rfi_peaks:
			if not bool(peak["is_rfi"]):
				continue
			var dp := (mhz - float(peak["mhz"])) / 6.0
			v += float(peak["strength"]) * exp(-dp * dp)
		out.append(clampf(v, 0.0, 1.4))
	return out


# ---------------------------------------------------------------- 3. RFI
func classify(index: int, as_rfi: bool) -> void:
	classifications[index] = "rfi" if as_rfi else "source"


func classification_score() -> float:
	if rfi_peaks.is_empty():
		return 0.0
	var correct := 0
	for i in range(rfi_peaks.size()):
		var want := "rfi" if bool(rfi_peaks[i]["is_rfi"]) else "source"
		if str(classifications.get(i, "")) == want:
			correct += 1
	return float(correct) / float(rfi_peaks.size())


func all_classified() -> bool:
	return classifications.size() >= rfi_peaks.size()


# ---------------------------------------------------------------- 4/5. folding
func set_integration(seconds: float) -> void:
	integration_s = clampf(seconds, 0.0, MAX_INTEGRATION)


func period_match() -> float:
	if target_kind != "pulsar":
		return 1.0
	var err := absf(trial_period_ms - true_period_ms)
	return clampf(1.0 - err / 40.0, 0.0, 1.0)   # within ~40 ms to score


func dm_match() -> float:
	if target_kind != "pulsar":
		return 1.0
	var err := absf(trial_dm - true_dm)
	return clampf(1.0 - err / 12.0, 0.0, 1.0)


func fold_snr() -> float:
	# SNR grows with sqrt(integration), scaled by how well the whole chain is set:
	# pointing lock, tuning, RFI rejection, correct period + DM.
	var chain := 0.0
	chain += 0.28 * (1.0 if is_locked() else clampf(1.0 - pointing_error() / 12.0, 0.0, 1.0))
	chain += 0.24 * tuning_quality()
	chain += 0.18 * classification_score()
	chain += 0.15 * period_match()
	chain += 0.15 * dm_match()
	var integ := sqrt(integration_s / 30.0)     # sqrt(t) radiometer scaling
	return clampf(chain, 0.0, 1.0) * integ * 22.0 * source_strength


func folded_profile(bins: int) -> Array:
	# a single clean pulse when period+DM are right; smears/flattens when wrong
	var out: Array = []
	var sharp := period_match() * dm_match()
	var width := lerpf(0.5, 0.045, sharp)         # phase width of the pulse
	var amp := clampf(fold_snr() / 20.0, 0.05, 1.0)
	for i in range(bins):
		var phase := float(i) / float(bins)
		# pulse centred at phase 0.5
		var dphi := (phase - 0.5) / width
		var v := amp * exp(-dphi * dphi)
		v += 0.06 * sin(phase * TAU * 3.0) * (1.0 - sharp)   # residual smear
		out.append(clampf(v, 0.0, 1.2))
	return out


func pulse_width_ms() -> float:
	return true_period_ms * lerpf(0.32, 0.04, period_match() * dm_match())


func timing_stability() -> float:
	return clampf(0.55 + 0.4 * period_match() * dm_match() + 0.05 * classification_score(), 0.0, 1.0)


func report() -> Dictionary:
	var snr := fold_snr()
	return {
		"target_id": target_id,
		"kind": target_kind,
		"pulse_period_ms": true_period_ms if period_match() > 0.6 else trial_period_ms,
		"dispersion_measure": true_dm if dm_match() > 0.6 else trial_dm,
		"snr": snr,
		"pulse_width_ms": pulse_width_ms(),
		"timing_stability": timing_stability(),
		"band_mhz": window_center_mhz,
		"bandwidth_mhz": window_bandwidth_mhz,
		"integration_s": integration_s,
		"rfi_score": classification_score(),
		"tuning_quality": tuning_quality(),
		"pointing_error": pointing_error(),
		"success": snr >= 8.0 and period_match() > 0.6 and dm_match() > 0.6,
	}
