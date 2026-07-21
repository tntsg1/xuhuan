extends Node

# Mobile input abstraction layer. Scenes never talk to raw touch events for
# CONTINUOUS controls - they read this singleton alongside the keyboard:
#   movement:  Input keys  OR  TouchInput.move_vector()
#   boost:     KEY_SHIFT   OR  TouchInput.boost_held
#   focus:     KEY_Q/E     OR  TouchInput.focus_direction
# One-shot actions (interact, missions) arrive as signals from the on-screen
# buttons, wired by each scene to the SAME handlers the keyboard uses.
# PC behavior is untouched: with mobile mode off, everything here is inert.

signal interact_pressed
signal missions_pressed
signal settings_changed

const SETTINGS_PATH := "user://mobile_controls.cfg"

var mobile_mode := false
var joystick_visible := true
var joystick_scale := 1.0
var touch_sensitivity := 1.0
var invert_pitch := false
var show_touch_hints := true

# Live virtual state fed by the on-screen controls.
var virtual_move := Vector2.ZERO
var boost_held := false
var focus_direction := 0.0
var calibration_vector := Vector2.ZERO


func _ready() -> void:
	_load_settings()
	if not _has_saved_mode_choice():
		mobile_mode = DisplayServer.is_touchscreen_available()


func move_vector() -> Vector2:
	return virtual_move if mobile_mode else Vector2.ZERO


func is_mobile() -> bool:
	return mobile_mode


func trigger_interact() -> void:
	interact_pressed.emit()


func trigger_missions() -> void:
	missions_pressed.emit()


func set_mobile_mode(enabled: bool) -> void:
	mobile_mode = enabled
	_save_settings()
	settings_changed.emit()


func apply_setting(key: String, value: Variant) -> void:
	match key:
		"joystick_visible": joystick_visible = bool(value)
		"joystick_scale": joystick_scale = clampf(float(value), 0.7, 1.6)
		"touch_sensitivity": touch_sensitivity = clampf(float(value), 0.4, 2.5)
		"invert_pitch": invert_pitch = bool(value)
		"show_touch_hints": show_touch_hints = bool(value)
	_save_settings()
	settings_changed.emit()


func _has_saved_mode_choice() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return config.has_section_key("mobile", "mobile_mode")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	mobile_mode = bool(config.get_value("mobile", "mobile_mode", false))
	joystick_visible = bool(config.get_value("mobile", "joystick_visible", true))
	joystick_scale = float(config.get_value("mobile", "joystick_scale", 1.0))
	touch_sensitivity = float(config.get_value("mobile", "touch_sensitivity", 1.0))
	invert_pitch = bool(config.get_value("mobile", "invert_pitch", false))
	show_touch_hints = bool(config.get_value("mobile", "show_touch_hints", true))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("mobile", "mobile_mode", mobile_mode)
	config.set_value("mobile", "joystick_visible", joystick_visible)
	config.set_value("mobile", "joystick_scale", joystick_scale)
	config.set_value("mobile", "touch_sensitivity", touch_sensitivity)
	config.set_value("mobile", "invert_pitch", invert_pitch)
	config.set_value("mobile", "show_touch_hints", show_touch_hints)
	config.save(SETTINGS_PATH)
