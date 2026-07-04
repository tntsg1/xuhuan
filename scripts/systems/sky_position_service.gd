extends RefCounted
class_name SkyPositionService

const CONFIG_PATH := "res://data/observing_config.json"
const CATALOG_PATH := "res://data/celestial_catalog.json"
const API_KEYS_PATH := "res://data/local_api_keys.json"
const ASTRONOMY_API_URL := "https://api.astronomyapi.com/api/v2/bodies/positions"

var config: Dictionary = {}
var catalog: Array = []


func _init() -> void:
	load_config()
	load_catalog()


func load_config() -> Dictionary:
	config = _load_json_dict(CONFIG_PATH)
	return config


func load_catalog() -> Array:
	catalog = _load_json_array(CATALOG_PATH)
	return catalog


func load_local_api_keys() -> Dictionary:
	return _astronomy_api_credentials()


func get_sky_positions(screen_rect: Rect2, utc_datetime: Dictionary = {}) -> Dictionary:
	if utc_datetime.is_empty():
		utc_datetime = Time.get_datetime_dict_from_system(true)
	var latitude: float = float(config.get("default_latitude", 34.0522))
	var longitude: float = float(config.get("default_longitude", -118.2437))
	var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var result: Dictionary = {}

	for entry_value in catalog:
		var entry: Dictionary = entry_value
		var id: String = str(entry.get("id", ""))
		if id == "":
			continue
		var item: Dictionary = _fallback_item(entry, minimum_altitude)
		if entry.has("ra_hours") and entry.has("dec_degrees"):
			var alt_az: Dictionary = calculate_alt_az_from_ra_dec(
				float(entry.get("ra_hours", 0.0)),
				float(entry.get("dec_degrees", 0.0)),
				latitude,
				longitude,
				utc_datetime
			)
			item["altitude"] = alt_az["altitude"]
			item["azimuth"] = alt_az["azimuth"]
			item["screen_pos"] = map_alt_az_to_screen(float(item["altitude"]), float(item["azimuth"]), screen_rect)
			item["visible"] = float(item["altitude"]) >= minimum_altitude
			item["visibility_text"] = _visibility_text(float(item["altitude"]), minimum_altitude)
			item["direction_text"] = direction_text(float(item["azimuth"]))
			item["source"] = "calculated"
		# Otherwise keep the fallback item: it already carries the catalog's
		# fallback alt/az estimate and source "fallback". Online data (Moon,
		# Mars, Jupiter) replaces it later via request_online_planet_data().
		result[id] = item
	return result


func get_sky_data(screen_rect: Rect2, utc_datetime: Dictionary = {}) -> Dictionary:
	return get_sky_positions(screen_rect, utc_datetime)


func fallback_positions(screen_rect: Rect2 = Rect2()) -> Dictionary:
	var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var result: Dictionary = {}
	for entry_value in catalog:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var item: Dictionary = _fallback_item(entry, minimum_altitude)
		if screen_rect.size != Vector2.ZERO and item.has("screen_pos"):
			var pos: Vector2 = item["screen_pos"]
			item["screen_pos"] = Vector2(
				clampf(pos.x, screen_rect.position.x, screen_rect.end.x),
				clampf(pos.y, screen_rect.position.y, screen_rect.end.y)
			)
		result[str(entry.get("id", ""))] = item
	return result


func request_online_planet_data(parent: Node, screen_rect: Rect2, callback: Callable) -> bool:
	if bool(config.get("offline_mode", false)) or not bool(config.get("use_online_planet_data", true)):
		return false
	var credentials: Dictionary = _astronomy_api_credentials()
	if credentials.is_empty():
		return false
	var local_datetime: Dictionary = Time.get_datetime_dict_from_system(false)
	var query := _astronomy_api_query(local_datetime)
	var request := HTTPRequest.new()
	request.timeout = 5.0
	parent.add_child(request)
	request.request_completed.connect(_on_online_positions_completed.bind(request, screen_rect, callback))
	var auth_text := "%s:%s" % [str(credentials.get("app_id", "")), str(credentials.get("app_secret", ""))]
	var headers := PackedStringArray(["Authorization: Basic " + Marshalls.utf8_to_base64(auth_text)])
	var error := request.request(ASTRONOMY_API_URL + "?" + query, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		return false
	return true


func calculate_alt_az_from_ra_dec(ra_hours: float, dec_degrees: float, latitude_degrees: float, longitude_degrees: float, utc_datetime: Dictionary) -> Dictionary:
	var jd: float = julian_date(utc_datetime)
	var gmst: float = gmst_degrees(jd)
	var lst: float = wrap_degrees(gmst + longitude_degrees)
	var hour_angle: float = wrap_degrees(lst - ra_hours * 15.0)
	if hour_angle > 180.0:
		hour_angle -= 360.0

	var ha: float = deg_to_rad(hour_angle)
	var dec: float = deg_to_rad(dec_degrees)
	var lat: float = deg_to_rad(latitude_degrees)
	var sin_alt: float = sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(ha)
	var altitude: float = rad_to_deg(asin(clamp(sin_alt, -1.0, 1.0)))

	var az_y: float = -sin(ha)
	var az_x: float = tan(dec) * cos(lat) - sin(lat) * cos(ha)
	var azimuth: float = wrap_degrees(rad_to_deg(atan2(az_y, az_x)))
	return {
		"altitude": altitude,
		"azimuth": azimuth
	}


func radec_to_altaz(ra_hours: float, dec_degrees: float, latitude_degrees: float, longitude_degrees: float, utc_datetime: Dictionary) -> Dictionary:
	return calculate_alt_az_from_ra_dec(ra_hours, dec_degrees, latitude_degrees, longitude_degrees, utc_datetime)


func map_alt_az_to_screen(altitude: float, azimuth: float, screen_rect: Rect2) -> Vector2:
	var center: Vector2 = screen_rect.position + screen_rect.size * 0.5
	var max_radius: float = min(screen_rect.size.x, screen_rect.size.y) * 0.46
	var radius: float = clamp((90.0 - altitude) / 90.0, 0.0, 1.0) * max_radius
	var angle: float = deg_to_rad(azimuth - 90.0)
	return center + Vector2(cos(angle), sin(angle)) * radius


func altaz_to_screen(altitude: float, azimuth: float, screen_rect: Rect2) -> Vector2:
	return map_alt_az_to_screen(altitude, azimuth, screen_rect)


func julian_date(utc_datetime: Dictionary) -> float:
	var year: int = int(utc_datetime.get("year", 2026))
	var month: int = int(utc_datetime.get("month", 1))
	var day: int = int(utc_datetime.get("day", 1))
	var hour: int = int(utc_datetime.get("hour", 0))
	var minute: int = int(utc_datetime.get("minute", 0))
	var second: int = int(utc_datetime.get("second", 0))
	if month <= 2:
		year -= 1
		month += 12
	var a: int = floori(float(year) / 100.0)
	var b: int = 2 - a + floori(float(a) / 4.0)
	var day_fraction: float = (float(hour) + float(minute) / 60.0 + float(second) / 3600.0) / 24.0
	return floor(365.25 * float(year + 4716)) + floor(30.6001 * float(month + 1)) + float(day) + day_fraction + float(b) - 1524.5


func gmst_degrees(julian: float) -> float:
	var d: float = julian - 2451545.0
	var t: float = d / 36525.0
	return wrap_degrees(280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - t * t * t / 38710000.0)


func wrap_degrees(value: float) -> float:
	var wrapped: float = fmod(value, 360.0)
	if wrapped < 0.0:
		wrapped += 360.0
	return wrapped


func direction_text(azimuth: float) -> String:
	var directions: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index: int = int(floor((wrap_degrees(azimuth) + 22.5) / 45.0)) % directions.size()
	return directions[index]


func _astronomy_api_query(utc_datetime: Dictionary) -> String:
	var latitude: String = str(config.get("default_latitude", 34.0522))
	var longitude: String = str(config.get("default_longitude", -118.2437))
	var year: int = int(utc_datetime.get("year", 2026))
	var month: int = int(utc_datetime.get("month", 1))
	var day: int = int(utc_datetime.get("day", 1))
	var hour: int = int(utc_datetime.get("hour", 0))
	var minute: int = int(utc_datetime.get("minute", 0))
	var second: int = int(utc_datetime.get("second", 0))
	var date_text := "%04d-%02d-%02d" % [year, month, day]
	var time_text := "%02d:%02d:%02d" % [hour, minute, second]
	var params := {
		"latitude": latitude,
		"longitude": longitude,
		"elevation": "0",
		"from_date": date_text,
		"to_date": date_text,
		"time": time_text,
		"output": "rows"
	}
	var parts: Array[String] = []
	for key_value in params.keys():
		var key: String = str(key_value)
		parts.append(key.uri_encode() + "=" + str(params[key]).uri_encode())
	return "&".join(parts)


func _on_online_positions_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, screen_rect: Rect2, callback: Callable) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var online_data: Dictionary = _parse_astronomy_api_positions(parsed, screen_rect)
	if online_data.is_empty():
		return
	callback.call(online_data)


func _parse_astronomy_api_positions(payload: Dictionary, screen_rect: Rect2) -> Dictionary:
	var output: Dictionary = {}
	var data: Dictionary = payload.get("data", {})
	var table: Dictionary = data.get("table", {})
	var rows: Array = table.get("rows", [])
	if rows.is_empty():
		rows = data.get("rows", [])
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var astronomy_item: Dictionary = _parse_astronomy_api_row(row, screen_rect)
		if not astronomy_item.is_empty():
			output[str(astronomy_item.get("id", ""))] = astronomy_item
			continue
		var entry: Dictionary = row.get("entry", {})
		var object_id: String = str(entry.get("id", "")).to_lower()
		if not ["moon", "mars", "jupiter"].has(object_id):
			continue
		var cells: Array = row.get("cells", [])
		if cells.is_empty() or not cells[0] is Dictionary:
			continue
		var cell: Dictionary = cells[0]
		var position: Dictionary = cell.get("position", {})
		var horizontal: Dictionary = position.get("horizontal", {})
		var altitude_data: Dictionary = horizontal.get("altitude", {})
		var azimuth_data: Dictionary = horizontal.get("azimuth", {})
		var altitude: float = float(altitude_data.get("degrees", 0.0))
		var azimuth: float = float(azimuth_data.get("degrees", 0.0))
		var item: Dictionary = _catalog_item_for_id(object_id)
		if item.is_empty():
			continue
		var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
		output[object_id] = {
			"id": object_id,
			"name": str(item.get("name", object_id)),
			"type": str(item.get("type", "planet")),
			"icon_type": str(item.get("icon_type", "white_star")),
			"altitude": altitude,
			"azimuth": azimuth,
			"screen_pos": map_alt_az_to_screen(altitude, azimuth, screen_rect),
			"visible": altitude >= minimum_altitude,
			"visibility_text": _visibility_text(altitude, minimum_altitude),
			"direction_text": direction_text(azimuth),
			"source": "online"
		}
	return output


func _parse_astronomy_api_row(row: Dictionary, screen_rect: Rect2) -> Dictionary:
	var body: Dictionary = row.get("body", {})
	var object_id: String = str(body.get("id", "")).to_lower()
	if not ["moon", "mars", "jupiter"].has(object_id):
		return {}
	var positions: Array = row.get("positions", [])
	if positions.is_empty() or not positions[0] is Dictionary:
		return {}
	var position_row: Dictionary = positions[0]
	var position: Dictionary = position_row.get("position", {})
	var horizontal: Dictionary = position.get("horizontal", {})
	if horizontal.is_empty():
		horizontal = position.get("horizonal", {})
	var altitude_data: Dictionary = horizontal.get("altitude", {})
	var azimuth_data: Dictionary = horizontal.get("azimuth", {})
	var altitude: float = float(altitude_data.get("degrees", 0.0))
	var azimuth: float = float(azimuth_data.get("degrees", 0.0))
	var item: Dictionary = _catalog_item_for_id(object_id)
	if item.is_empty():
		return {}
	var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	return {
		"id": object_id,
		"name": str(item.get("name", body.get("name", object_id))),
		"type": str(item.get("type", "planet")),
		"icon_type": str(item.get("icon_type", "white_star")),
		"altitude": altitude,
		"azimuth": azimuth,
		"screen_pos": map_alt_az_to_screen(altitude, azimuth, screen_rect),
		"visible": altitude >= minimum_altitude,
		"visibility_text": _visibility_text(altitude, minimum_altitude),
		"direction_text": direction_text(azimuth),
		"source": "online"
	}


func _catalog_item_for_id(object_id: String) -> Dictionary:
	for entry_value in catalog:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == object_id:
			return entry
	return {}


func _astronomy_api_credentials() -> Dictionary:
	var keys: Dictionary = _load_json_dict(API_KEYS_PATH)
	if keys.is_empty():
		return {}
	var nested: Dictionary = keys.get("astronomyapi", {})
	var app_id: String = str(nested.get("app_id", keys.get("astronomyapi_app_id", "")))
	var app_secret: String = str(nested.get("app_secret", keys.get("astronomyapi_app_secret", "")))
	if app_id == "" or app_secret == "":
		return {}
	return {
		"app_id": app_id,
		"app_secret": app_secret
	}


func _fallback_item(entry: Dictionary, minimum_altitude: float) -> Dictionary:
	var pos: Vector2 = Vector2(float(entry.get("fallback_x", 100.0)), float(entry.get("fallback_y", 100.0)))
	var has_fallback_altaz: bool = entry.has("fallback_altitude") and entry.has("fallback_azimuth")
	var altitude: float = float(entry.get("fallback_altitude", 0.0))
	var azimuth: float = float(entry.get("fallback_azimuth", 0.0))
	return {
		"id": str(entry.get("id", "")),
		"name": str(entry.get("name", entry.get("id", ""))),
		"type": str(entry.get("type", "object")),
		"icon_type": str(entry.get("icon_type", "white_star")),
		"altitude": altitude,
		"azimuth": azimuth,
		"screen_pos": pos,
		"visible": has_fallback_altaz and altitude >= minimum_altitude,
		"visibility_text": "Offline estimate",
		"direction_text": direction_text(azimuth) if has_fallback_altaz else "Estimate",
		"source": "fallback"
	}


func _visibility_text(altitude: float, minimum_altitude: float) -> String:
	if altitude < 0.0:
		return "Below horizon"
	if altitude < minimum_altitude:
		return "Low on horizon"
	return "Visible tonight"


func _has_local_api_keys() -> bool:
	if not FileAccess.file_exists(API_KEYS_PATH):
		return false
	var keys: Dictionary = _load_json_dict(API_KEYS_PATH)
	return not keys.is_empty()


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text().trim_prefix("\uFEFF")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text().trim_prefix("\uFEFF")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []
