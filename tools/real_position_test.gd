extends SceneTree

# Real-position acceptance: expansion bodies must be DATE-DRIVEN (ephemeris
# or RA/Dec), never frozen fallbacks; lunar features ride the Moon; one
# coordinate source feeds every view.

var failures := 0


func _initialize() -> void:
	await process_frame
	var service: RefCounted = load("res://scripts/systems/sky_position_service.gd").new()
	var july := {"year": 2026, "month": 7, "day": 19, "hour": 6, "minute": 0, "second": 0}
	var october := {"year": 2026, "month": 10, "day": 19, "hour": 6, "minute": 0, "second": 0}

	# 1. Planet ephemeris changes with the DATE.
	for body in ["mercury", "venus", "saturn", "uranus", "neptune"]:
		var a: Dictionary = service.planet_ra_dec(body, july)
		var b: Dictionary = service.planet_ra_dec(body, october)
		_check(not a.is_empty() and not b.is_empty(), "%s has an offline ephemeris" % body)
		var ra_shift: float = absf(fmod(float(a.get("ra_hours", 0.0)) - float(b.get("ra_hours", 0.0)) + 12.0, 24.0) - 12.0)
		var expected_minimum := 0.35 if body in ["uranus", "neptune"] else 1.0
		_check(ra_shift * 15.0 >= expected_minimum, "%s RA moves over three months (%.2f deg)" % [body, ra_shift * 15.0])

	# 2. Sanity: Saturn's position is a plausible ecliptic-neighborhood value.
	var saturn: Dictionary = service.planet_ra_dec("saturn", july)
	_check(absf(float(saturn.get("dec_degrees", 90.0))) < 30.0, "Saturn declination stays near the ecliptic")

	# 3. Fixed bodies move with the CLOCK (alt/az differs by hour).
	var positions_a: Dictionary = service.get_sky_positions(Rect2(0, 0, 600, 400), july)
	var later := july.duplicate()
	later["hour"] = 12
	var positions_b: Dictionary = service.get_sky_positions(Rect2(0, 0, 600, 400), later)
	for id in ["pleiades", "albireo", "m13"]:
		_check(positions_a.has(id), "%s present in sky positions" % id)
		# Find two hours where the body is comfortably up, then require a
		# calculated source and clock-driven azimuth motion between them.
		var seen_hours: Array[int] = []
		for hour in range(0, 24, 2):
			var probe := july.duplicate()
			probe["hour"] = hour
			var sample: Dictionary = service.get_sky_positions(Rect2(0, 0, 600, 400), probe)
			if str(sample.get(id, {}).get("source", "")) == "calculated":
				seen_hours.append(hour)
		_check(seen_hours.size() >= 2, "%s is calculated for multiple hours of the night" % id)
		if seen_hours.size() >= 2:
			var first_probe := july.duplicate()
			first_probe["hour"] = seen_hours[0]
			var second_probe := july.duplicate()
			second_probe["hour"] = seen_hours[seen_hours.size() - 1]
			var sample_a: Dictionary = service.get_sky_positions(Rect2(0, 0, 600, 400), first_probe)
			var sample_b: Dictionary = service.get_sky_positions(Rect2(0, 0, 600, 400), second_probe)
			var moved: float = absf(float(sample_a[id].get("azimuth", 0.0)) - float(sample_b[id].get("azimuth", 0.0)))
			_check(moved > 3.0, "%s azimuth moves with the clock (%.1f deg)" % [id, moved])

	# 4. Lunar features ride the Moon exactly.
	for feature in ["moon_crater_copernicus", "moon_mare_tranquillitatis", "moon_terminator"]:
		if positions_a.has(feature) and positions_a.has("moon"):
			_check(is_equal_approx(float(positions_a[feature].get("azimuth", -1.0)), float(positions_a["moon"].get("azimuth", -2.0))),
				"%s shares the Moon's azimuth" % feature)

	# 5. Planets flow through the same catalog pipeline as everything else.
	var mercury_calculated := false
	for hour in range(0, 24, 2):
		var mercury_probe := july.duplicate()
		mercury_probe["hour"] = hour
		var mercury_sample: Dictionary = service.get_sky_positions(Rect2(0, 0, 600, 400), mercury_probe)
		if str(mercury_sample.get("mercury", {}).get("source", "")) == "calculated":
			mercury_calculated = true
			break
	_check(mercury_calculated, "Mercury reaches a calculated (ephemeris) position at some hour")

	if failures == 0:
		print("REAL POSITION TEST PASS")
		quit(0)
	else:
		print("REAL POSITION TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
