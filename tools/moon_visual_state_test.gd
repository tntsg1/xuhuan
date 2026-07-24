extends SceneTree

# Round 30: all Moon visuals (48px sky icon, 96px large, 360px telescope states)
# derive from the same high-quality lunar surface - no low-res/high-res mismatch.

var failures := 0


func _initialize() -> void:
	await process_frame

	# Sample mean colour + a crater-detail proxy (luminance variance) for each
	# Moon asset. All must share the same greyscale lunar palette AND carry real
	# surface detail (not a flat disc or striped placeholder).
	var assets := {
		"icon_48": "res://assets/celestial_icons/moon.png",
		"large_96": "res://assets/telescope_view/moon_large.png",
		"clear_360": "res://assets/telescope_view/moon_clear.png",
		"blurry_360": "res://assets/telescope_view/moon_blurry.png",
		"dim_360": "res://assets/telescope_view/moon_dim.png",
	}
	var stats := {}
	for key in assets.keys():
		stats[key] = _stats(str(assets[key]))
		var s: Dictionary = stats[key]
		_check(s["lit"] > 50, "%s has a lit disc" % key)

	# --- 1. Same lunar palette: neutral grey (R≈G≈B), not tinted ---
	for key in ["icon_48", "large_96", "clear_360"]:
		var s: Dictionary = stats[key]
		var spread: float = maxf(s["r"], maxf(s["g"], s["b"])) - minf(s["r"], minf(s["g"], s["b"]))
		_check(spread < 0.06, "1. %s is neutral grey lunar palette (channel spread %.3f)" % [key, spread])

	# --- 2. icon + large match the canonical clear-moon brightness ---
	_check(absf(float(stats["icon_48"]["v"]) - float(stats["clear_360"]["v"])) < 0.06, "2. 48px icon brightness matches the 360px lunar surface")
	_check(absf(float(stats["large_96"]["v"]) - float(stats["clear_360"]["v"])) < 0.06, "2. 96px large matches the 360px lunar surface")

	# --- 3. Real surface detail (variance) at every size, not a flat/striped disc ---
	for key in ["icon_48", "large_96", "clear_360"]:
		_check(float(stats[key]["var"]) > 0.0015, "3. %s carries crater/maria detail (variance %.4f)" % [key, float(stats[key]["var"])])

	# --- 4. Telescope texture maps for the moon point at the unified assets ---
	var f := FileAccess.open("res://scripts/ui/telescope_view.gd", FileAccess.READ)
	var src := f.get_as_text()
	_check(src.contains("\"moon\": \"res://assets/telescope_view/moon_large.png\""), "4. eyepiece sprite map uses the unified moon_large")
	_check(src.contains("moon_clear.png") and src.contains("moon_dim.png") and src.contains("moon_blurry.png"), "4. moon telescope states use the 360px lunar set")

	# --- 5. dim keeps a brightness floor (not a black disc) ---
	var d: Dictionary = stats["dim_360"]
	_check(float(d["v"]) > 0.18, "5. moon_dim is not crushed to black (mean value %.2f)" % float(d["v"]))
	_check(float(d["maxch"]) > 0.35, "5. moon_dim keeps lit highlights (maxCh %.2f)" % float(d["maxch"]))

	if failures == 0:
		print("MOON VISUAL STATE TEST PASS")
		quit(0)
	else:
		print("MOON VISUAL STATE TEST FAIL (%d)" % failures)
		quit(1)


func _stats(path: String) -> Dictionary:
	var img := (load(path) as Texture2D).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var rs := 0.0
	var gs := 0.0
	var bs := 0.0
	var vs := 0.0
	var v2 := 0.0
	var lit := 0
	var maxch := 0.0
	var step: int = maxi(1, int(w / 60))
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			if c.a > 0.2 and c.v > 0.04:
				rs += c.r
				gs += c.g
				bs += c.b
				vs += c.v
				v2 += c.v * c.v
				maxch = maxf(maxch, maxf(c.r, maxf(c.g, c.b)))
				lit += 1
	var n := maxf(lit, 1)
	var mv := vs / n
	return {"r": rs / n, "g": gs / n, "b": bs / n, "v": mv, "var": (v2 / n) - mv * mv, "maxch": maxch, "lit": lit}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
