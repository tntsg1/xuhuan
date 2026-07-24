extends Control
class_name SpaceDeploymentVisual

var deployed: Array = []
var active_step := ""
var animation_progress := 1.0:
	set(value):
		animation_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

const ORDER := ["solar_array", "sunshield", "primary_mirror", "secondary_mirror", "hinges", "actuators"]
const HOT := Color(0.94, 0.94, 0.94)
const MID := Color(0.58, 0.58, 0.58)
const DIM := Color(0.24, 0.24, 0.24)
const FAINT := Color(0.12, 0.12, 0.12)


func set_state(value: Array) -> void:
	deployed = value.duplicate()
	active_step = ""
	animation_progress = 1.0
	queue_redraw()


func play_step(step: String, base_state: Array, finished: Callable) -> void:
	deployed = base_state.duplicate()
	active_step = step
	animation_progress = 0.0
	var tween := create_tween().bind_node(self)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "animation_progress", 1.0, 0.72)
	tween.tween_callback(func() -> void:
		if not deployed.has(step):
			deployed.append(step)
		active_step = ""
		queue_redraw()
		if finished.is_valid():
			finished.call())


func _amount(step: String) -> float:
	if deployed.has(step):
		return 1.0
	return animation_progress if active_step == step else 0.0


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.49)
	_draw_grid()
	draw_string(ThemeDB.fallback_font, Vector2(28, 54), "L2 DEPLOYMENT TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MID)
	_draw_bus(center)
	_draw_solar(center, _amount("solar_array"))
	_draw_sunshield(center, _amount("sunshield"))
	_draw_primary(center, _amount("primary_mirror"))
	_draw_secondary(center, _amount("secondary_mirror"))
	_draw_hinges(center, _amount("hinges"))
	_draw_actuators(center, _amount("actuators"))
	var completed := deployed.size() + (1 if active_step != "" else 0)
	draw_string(ThemeDB.fallback_font, Vector2(28, size.y - 28),
		"MECHANISMS %02d/06    ACTIVE %s" % [completed, active_step.to_upper() if active_step != "" else "STANDBY"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HOT if active_step != "" else MID)


func _draw_grid() -> void:
	for x in range(28, int(size.x) - 20, 32):
		draw_line(Vector2(x, 70), Vector2(x, size.y - 54), Color(0.16, 0.16, 0.16, 0.55), 1.0)
	for y in range(70, int(size.y) - 50, 28):
		draw_line(Vector2(28, y), Vector2(size.x - 24, y), Color(0.16, 0.16, 0.16, 0.55), 1.0)


func _draw_bus(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-45, 80), Vector2(90, 50)), FAINT, true)
	draw_rect(Rect2(center + Vector2(-45, 80), Vector2(90, 50)), MID, false, 2.0)
	draw_line(center + Vector2(0, 80), center + Vector2(0, 130), DIM, 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-31, 111), "BUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MID)


func _draw_solar(center: Vector2, amount: float) -> void:
	var width := lerpf(18.0, 150.0, amount)
	var rect := Rect2(center + Vector2(-45.0 - width, 88), Vector2(width, 34))
	draw_rect(rect, Color(0.17, 0.17, 0.17), true)
	draw_rect(rect, HOT if amount >= 1.0 else MID, false, 2.0)
	for x in range(1, 5):
		var px := rect.position.x + rect.size.x * float(x) / 5.0
		draw_line(Vector2(px, rect.position.y), Vector2(px, rect.end.y), DIM, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, -6), "PWR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MID)


func _draw_sunshield(center: Vector2, amount: float) -> void:
	for index in range(5):
		var spread := lerpf(22.0, 205.0 - index * 12.0, amount)
		var y := center.y + 50.0 + index * lerpf(2.0, 9.0, amount)
		var points := PackedVector2Array([
			Vector2(center.x - spread, y),
			Vector2(center.x + spread, y),
			Vector2(center.x + spread * 0.78, y + 8),
			Vector2(center.x - spread * 0.78, y + 8),
		])
		draw_colored_polygon(points, Color(0.12 + index * 0.015, 0.12 + index * 0.015, 0.12 + index * 0.015))
		draw_polyline(points + PackedVector2Array([points[0]]), MID if index > 0 else HOT, 1.0)


func _mirror_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q in range(-2, 3):
		for r in range(-2, 3):
			var s := -q - r
			if maxi(abs(q), maxi(abs(r), abs(s))) <= 2 and not (q == 0 and r == 0):
				out.append(Vector2i(q, r))
	return out


func _draw_primary(center: Vector2, amount: float) -> void:
	var mirror_center := center + Vector2(0, -40)
	var radius := lerpf(8.0, 15.0, amount)
	for index in range(_mirror_coords().size()):
		var axial := _mirror_coords()[index]
		var target := Vector2(sqrt(3.0) * (axial.x + axial.y * 0.5), 1.5 * axial.y) * radius
		var folded := Vector2(signf(float(axial.x)) * 16.0, float(index % 3 - 1) * 5.0)
		_draw_hex(mirror_center + folded.lerp(target, amount), radius * lerpf(0.72, 1.0, amount),
			HOT if amount >= 0.98 else MID)


func _draw_secondary(center: Vector2, amount: float) -> void:
	var mirror_center := center + Vector2(0, -40)
	var secondary := mirror_center + Vector2(0, lerpf(-28.0, -112.0, amount))
	for side in [-1.0, 1.0]:
		var start := mirror_center + Vector2(side * 54.0, -18)
		draw_line(start, start.lerp(secondary, amount), MID, 2.0)
	draw_circle(secondary, lerpf(3.0, 11.0, amount), HOT, false, 2.0)


func _draw_hinges(center: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	for side in [-1.0, 1.0]:
		var p := center + Vector2(side * 78.0, -40)
		draw_arc(p, 8.0 + amount * 4.0, 0.0, TAU * amount, 18, HOT, 2.0)
		draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), MID, 1.0)


func _draw_actuators(center: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	var mirror_center := center + Vector2(0, -40)
	var count := clampi(int(ceil(amount * 18.0)), 1, 18)
	for index in range(count):
		var axial := _mirror_coords()[index]
		var p := mirror_center + Vector2(sqrt(3.0) * (axial.x + axial.y * 0.5), 1.5 * axial.y) * 15.0
		draw_circle(p, 2.0 + sin(float(index) * 1.7 + amount * 12.0), HOT, true)
	draw_string(ThemeDB.fallback_font, mirror_center + Vector2(-50, 78),
		"ACTUATOR BUS %03d%%" % roundi(amount * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HOT)


func _draw_hex(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(7):
		var angle := PI / 6.0 + float(index) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, 1.5)
