extends Control
class_name SpaceGuideField

signal candidate_changed(index: int)

var guide_stars: Array = []
var candidate := -1
var chosen := -1
var pointing_error := 8.0
var drift_rate := 0.9
var locked := false
var dragging := false
var search_center := Vector2(118, 322)
var history: Array[float] = []

const STAR_POSITIONS := [
	Vector2(118, 118), Vector2(302, 218), Vector2(456, 112), Vector2(226, 338),
	Vector2(388, 320), Vector2(500, 260)
]
const HOT := Color(0.96, 0.96, 0.96)
const MID := Color(0.58, 0.58, 0.58)
const DIM := Color(0.28, 0.28, 0.28)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func set_stars(value: Array) -> void:
	guide_stars = value
	queue_redraw()


func update_metrics(error: float, drift: float, is_locked: bool, chosen_index: int) -> void:
	pointing_error = error
	drift_rate = drift
	locked = is_locked
	chosen = chosen_index
	history.append(clampf(error / 10.0, 0.0, 1.0))
	while history.size() > 70:
		history.pop_front()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		dragging = (event as InputEventMouseButton).pressed
		if dragging:
			_move_search((event as InputEventMouseButton).position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_move_search((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventScreenTouch:
		dragging = (event as InputEventScreenTouch).pressed
		if dragging:
			_move_search((event as InputEventScreenTouch).position)
		accept_event()
	elif event is InputEventScreenDrag:
		_move_search((event as InputEventScreenDrag).position)
		accept_event()


func _move_search(position: Vector2) -> void:
	search_center = Vector2(
		clampf(position.x, 48.0, size.x - 48.0),
		clampf(position.y, 82.0, size.y - 118.0)
	)
	var next := -1
	var nearest := 46.0
	for index in range(mini(guide_stars.size(), STAR_POSITIONS.size())):
		var distance := search_center.distance_to(STAR_POSITIONS[index])
		if distance < nearest:
			nearest = distance
			next = index
	if next != candidate:
		candidate = next
		candidate_changed.emit(candidate)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(28, 68), Vector2(size.x - 56, size.y - 150)), Color(0.025, 0.025, 0.025), true)
	draw_rect(Rect2(Vector2(28, 68), Vector2(size.x - 56, size.y - 150)), DIM, false, 1.0)
	for x in range(44, int(size.x) - 30, 32):
		draw_line(Vector2(x, 68), Vector2(x, size.y - 82), Color(0.12, 0.12, 0.12), 1.0)
	for y in range(84, int(size.y) - 82, 28):
		draw_line(Vector2(28, y), Vector2(size.x - 28, y), Color(0.12, 0.12, 0.12), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 50), GameManager.text(
		"DRAG SEARCH BOX ACROSS THE SENSOR FIELD", "拖动搜索框扫描传感器星场"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MID)

	for index in range(mini(guide_stars.size(), STAR_POSITIONS.size())):
		var star: Dictionary = guide_stars[index]
		var p: Vector2 = STAR_POSITIONS[index]
		var brightness := float(star.get("brightness", 0.4))
		var usable := bool(star.get("usable", false))
		var radius := 2.0 + brightness * 5.0
		draw_circle(p, radius, HOT if usable else DIM, true)
		draw_line(p - Vector2(10, 0), p + Vector2(10, 0), Color(HOT, 0.35), 1.0)
		draw_line(p - Vector2(0, 10), p + Vector2(0, 10), Color(HOT, 0.35), 1.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-18, 24), str(star.get("id", "GS")),
			HORIZONTAL_ALIGNMENT_CENTER, 36, 10, HOT if index == candidate else MID)
		if index == chosen:
			var lock_radius := lerpf(34.0, 12.0, clampf(1.0 - pointing_error / 8.0, 0.0, 1.0))
			draw_arc(p, lock_radius, 0.0, TAU, 48, HOT if locked else MID, 2.0)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(p + direction * (lock_radius + 7.0), p + direction * (lock_radius - 5.0), HOT, 2.0)

	var box := Rect2(search_center - Vector2(42, 32), Vector2(84, 64))
	draw_rect(box, HOT if candidate >= 0 else MID, false, 2.0)
	var corner := 10.0
	for p in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var sx := 1.0 if p.x == box.position.x else -1.0
		var sy := 1.0 if p.y == box.position.y else -1.0
		draw_line(p, p + Vector2(sx * corner, 0), HOT, 3.0)
		draw_line(p, p + Vector2(0, sy * corner), HOT, 3.0)

	_draw_drift_graph(Rect2(66, size.y - 68, size.x - 132, 48))


func _draw_drift_graph(rect: Rect2) -> void:
	draw_rect(rect, Color(0.02, 0.02, 0.02), true)
	draw_rect(rect, DIM, false, 1.0)
	draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), DIM, 1.0)
	if history.size() < 2:
		return
	var points := PackedVector2Array()
	for index in range(history.size()):
		var x := rect.position.x + float(index) / float(maxi(1, history.size() - 1)) * rect.size.x
		var y := rect.end.y - float(history[index]) * rect.size.y
		points.append(Vector2(x, y))
	draw_polyline(points, HOT if locked else MID, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 14),
		"DRIFT %.2f arcsec/s" % drift_rate, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MID)
