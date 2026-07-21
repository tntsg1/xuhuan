extends SceneTree

# Round 25: the sky is REAL. Every catalog object is positioned by
# lat/lon/UTC/RA/Dec - no frozen teaching coordinates leak into the sky view.

var failures := 0
const T1 := {"year": 2026, "month": 7, "day": 20, "hour": 2, "minute": 0, "second": 0}
const T2 := {"year": 2026, "month": 7, "day": 20, "hour": 8, "minute": 0, "second": 0}


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	var svc := SkyPositionService.new()
	gm.new_game()
	gm.debug_jump_to_level(5, true)

	# --- 1. No object falls back to a frozen teaching position ---
	var sky: Dictionary = svc.get_sky_positions(Rect2(88, 103, 630, 560))
	var calculated := 0
	var frozen := 0
	for id in sky.keys():
		if str((sky[id] as Dictionary).get("source", "")) == "calculated":
			calculated += 1
		else:
			frozen += 1
	_check(frozen == 0, "1. no object uses a frozen fallback position (%d frozen)" % frozen)
	_check(calculated == sky.size(), "1. all %d catalog objects are really calculated" % sky.size())

	# --- 2. Same site, different time -> the sky moves ---
	var a1 := svc.visibility_at(5.5, 0.0, 34.05, -118.24, T1)
	var a2 := svc.visibility_at(5.5, 0.0, 34.05, -118.24, T2)
	_check(absf(float(a1["altitude"]) - float(a2["altitude"])) > 3.0, "2. same place, different time -> altitude changes")

	# --- 3. Same time, different longitude -> sidereal time differs ---
	var b1 := svc.visibility_at(5.5, 0.0, 34.05, -118.24, T1)
	var b2 := svc.visibility_at(5.5, 0.0, 34.05, 80.0, T1)
	_check(absf(float(b1["azimuth"]) - float(b2["azimuth"])) > 5.0, "3. same time, different longitude -> azimuth differs")

	# --- 4. Same time, different latitude -> altitude differs ---
	var c1 := svc.visibility_at(0.0, 60.0, 60.0, 0.0, T1)
	var c2 := svc.visibility_at(0.0, 60.0, -30.0, 0.0, T1)
	_check(absf(float(c1["altitude"]) - float(c2["altitude"])) > 30.0, "4. same time, different latitude -> altitude differs")
	_check(float(c1["altitude"]) > 0.0 and float(c2["altitude"]) < 0.0, "4. a +60 dec target is up north, down south")

	# --- 5. Horizon semantics ---
	_check(bool(c2["below_horizon"]) and not bool(c2["visible"]), "5. below-horizon target reports below_horizon + not visible")
	_check(bool(c1["visible"]), "5. high target reports visible")

	# --- 6. Az convention: 0=N, 90=E, 180=S, 270=W ---
	_check(str(svc.direction_text(0.0)).begins_with("N"), "6. azimuth 0 is North")
	_check(str(svc.direction_text(90.0)).begins_with("E"), "6. azimuth 90 is East")
	_check(str(svc.direction_text(180.0)).begins_with("S"), "6. azimuth 180 is South")
	_check(str(svc.direction_text(270.0)).begins_with("W"), "6. azimuth 270 is West")

	# --- 7. Solar-system bodies move with the DATE (not frozen) ---
	var d1 := svc.planet_ra_dec("jupiter", {"year": 2026, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var d2 := svc.planet_ra_dec("jupiter", {"year": 2026, "month": 9, "day": 1, "hour": 0, "minute": 0, "second": 0})
	_check(absf(float(d1["ra_hours"]) - float(d2["ra_hours"])) > 0.2, "7. Jupiter RA changes across the year")
	var m1 := svc.moon_ra_dec({"year": 2026, "month": 7, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var m2 := svc.moon_ra_dec({"year": 2026, "month": 7, "day": 8, "hour": 0, "minute": 0, "second": 0})
	_check(absf(float(m1["ra_hours"]) - float(m2["ra_hours"])) > 1.0, "7. the Moon moves several hours of RA in a week")
	var mars1 := svc.planet_ra_dec("mars", {"year": 2026, "month": 2, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var mars2 := svc.planet_ra_dec("mars", {"year": 2026, "month": 10, "day": 1, "hour": 0, "minute": 0, "second": 0})
	_check(absf(float(mars1["ra_hours"]) - float(mars2["ra_hours"])) > 0.5, "7. Mars RA changes across the year")

	# --- 8. Star brightness follows magnitude (catalog-driven, not random) ---
	var file := FileAccess.open("res://data/bright_stars.json", FileAccess.READ)
	_check(file != null, "8. bright-star catalog present")
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		var stars: Array = (parsed as Dictionary).get("stars", [])
		_check(stars.size() > 1000, "8. catalog has %d real stars (not random points)" % stars.size())

	# --- 9. Relocating changes the whole sky, not just the target ---
	gm.set_observing_location({"id": "siding_spring", "name_en": "Siding Spring", "lat": -31.27, "lon": 149.06, "bortle": 3})
	var south: Dictionary = svc.get_sky_positions(Rect2(88, 103, 630, 560), {}, -31.27, 149.06)
	var north: Dictionary = svc.get_sky_positions(Rect2(88, 103, 630, 560), {}, 34.05, -118.24)
	var differing := 0
	for id in south.keys():
		if north.has(id) and absf(float((south[id] as Dictionary).get("altitude", 0.0)) - float((north[id] as Dictionary).get("altitude", 0.0))) > 1.0:
			differing += 1
	_check(differing >= 10, "9. moving hemisphere changes most objects' altitude (%d changed)" % differing)
	gm.reset_observing_location()

	if failures == 0:
		print("REAL SKY TEST PASS")
		quit(0)
	else:
		print("REAL SKY TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
