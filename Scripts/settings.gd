extends Node

signal accessibility_changed(settings: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_ACCESSIBILITY := "accessibility"
const SECTION_INPUT := "input"
const WORLD_ALPHA_CAP: float = 0.28
const WORLD_FILL_ALPHA_CAP: float = 0.045
const WORLD_LIGHT_ALPHA_CAP: float = 0.16
const WORLD_EFFECT_RADIUS_CAP: float = 420.0
const WORLD_POLYGON_SEGMENT_CAP: int = 32
const REDUCED_FLASH_ALPHA_SCALE: float = 0.45

enum ColorblindMode {
	OFF,
	DEUTERANOPIA,
	PROTANOPIA,
	TRITANOPIA,
}

var input_type: bool = false # Controller true; mouse aim if false.
var ui_scale: float = 1.0
var screen_shake_scale: float = 1.0
var reduce_flash: bool = false
var colorblind_mode: int = ColorblindMode.OFF
var trackpad_direct_camera: bool = false
var camera_follow_strength: float = 1.0
var alternate_movement_enabled: bool = false
var reverse_thrust_scale: float = 0.46
var strafe_turn_assist: float = 0.22


func _ready() -> void:
	load_settings()


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.75, 1.35)
	_emit_accessibility_changed()
	save_settings()


func set_screen_shake_scale(value: float) -> void:
	screen_shake_scale = clampf(value, 0.0, 1.0)
	_emit_accessibility_changed()
	save_settings()


func set_reduce_flash(value: bool) -> void:
	reduce_flash = value
	_emit_accessibility_changed()
	save_settings()


func set_colorblind_mode(value: int) -> void:
	colorblind_mode = clampi(value, ColorblindMode.OFF, ColorblindMode.TRITANOPIA)
	_emit_accessibility_changed()
	save_settings()


func set_trackpad_direct_camera(value: bool) -> void:
	trackpad_direct_camera = value
	_emit_accessibility_changed()
	save_settings()


func set_camera_follow_strength(value: float) -> void:
	camera_follow_strength = clampf(value, 0.25, 2.5)
	_emit_accessibility_changed()
	save_settings()


func set_alternate_movement_enabled(value: bool) -> void:
	alternate_movement_enabled = value
	_emit_accessibility_changed()
	save_settings()


func set_reverse_thrust_scale(value: float) -> void:
	reverse_thrust_scale = clampf(value, 0.15, 0.8)
	_emit_accessibility_changed()
	save_settings()


func set_strafe_turn_assist(value: float) -> void:
	strafe_turn_assist = clampf(value, 0.0, 0.6)
	_emit_accessibility_changed()
	save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		_emit_accessibility_changed()
		return

	ui_scale = clampf(float(config.get_value(SECTION_ACCESSIBILITY, "ui_scale", ui_scale)), 0.75, 1.35)
	screen_shake_scale = clampf(float(config.get_value(SECTION_ACCESSIBILITY, "screen_shake_scale", screen_shake_scale)), 0.0, 1.0)
	reduce_flash = bool(config.get_value(SECTION_ACCESSIBILITY, "reduce_flash", reduce_flash))
	colorblind_mode = clampi(
		int(config.get_value(SECTION_ACCESSIBILITY, "colorblind_mode", colorblind_mode)),
		ColorblindMode.OFF,
		ColorblindMode.TRITANOPIA
	)
	trackpad_direct_camera = bool(config.get_value(SECTION_INPUT, "trackpad_direct_camera", trackpad_direct_camera))
	camera_follow_strength = clampf(float(config.get_value(SECTION_INPUT, "camera_follow_strength", camera_follow_strength)), 0.25, 2.5)
	alternate_movement_enabled = bool(config.get_value(SECTION_INPUT, "alternate_movement_enabled", alternate_movement_enabled))
	reverse_thrust_scale = clampf(float(config.get_value(SECTION_INPUT, "reverse_thrust_scale", reverse_thrust_scale)), 0.15, 0.8)
	strafe_turn_assist = clampf(float(config.get_value(SECTION_INPUT, "strafe_turn_assist", strafe_turn_assist)), 0.0, 0.6)
	_emit_accessibility_changed()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_ACCESSIBILITY, "ui_scale", ui_scale)
	config.set_value(SECTION_ACCESSIBILITY, "screen_shake_scale", screen_shake_scale)
	config.set_value(SECTION_ACCESSIBILITY, "reduce_flash", reduce_flash)
	config.set_value(SECTION_ACCESSIBILITY, "colorblind_mode", colorblind_mode)
	config.set_value(SECTION_INPUT, "trackpad_direct_camera", trackpad_direct_camera)
	config.set_value(SECTION_INPUT, "camera_follow_strength", camera_follow_strength)
	config.set_value(SECTION_INPUT, "alternate_movement_enabled", alternate_movement_enabled)
	config.set_value(SECTION_INPUT, "reverse_thrust_scale", reverse_thrust_scale)
	config.set_value(SECTION_INPUT, "strafe_turn_assist", strafe_turn_assist)
	config.save(SETTINGS_PATH)


func apply_readability_color(color: Color) -> Color:
	match colorblind_mode:
		ColorblindMode.DEUTERANOPIA:
			return Color(
				color.r * 0.78 + color.b * 0.22,
				color.g * 0.72 + color.b * 0.28,
				maxf(color.b, color.g * 0.42),
				color.a
			)
		ColorblindMode.PROTANOPIA:
			return Color(
				color.r * 0.56 + color.b * 0.34 + color.g * 0.1,
				maxf(color.g, color.r * 0.42),
				color.b,
				color.a
			)
		ColorblindMode.TRITANOPIA:
			return Color(
				maxf(color.r, color.b * 0.38),
				color.g * 0.84 + color.r * 0.16,
				color.b * 0.55 + color.g * 0.45,
				color.a
			)
	return color


func flash_alpha(alpha: float) -> float:
	var capped_alpha: float = clampf(alpha, 0.0, WORLD_ALPHA_CAP)
	return capped_alpha * REDUCED_FLASH_ALPHA_SCALE if reduce_flash else capped_alpha


func world_visual_alpha(alpha: float, hard_cap: float = WORLD_ALPHA_CAP) -> float:
	var capped_alpha: float = clampf(alpha, 0.0, minf(hard_cap, WORLD_ALPHA_CAP))
	return flash_alpha(capped_alpha)


func world_fill_alpha(alpha: float) -> float:
	return world_visual_alpha(alpha, WORLD_FILL_ALPHA_CAP)


func world_light_alpha(alpha: float) -> float:
	return world_visual_alpha(alpha, WORLD_LIGHT_ALPHA_CAP)


func world_effect_radius(radius: float, hard_cap: float = WORLD_EFFECT_RADIUS_CAP) -> float:
	return clampf(radius, 0.0, clampf(hard_cap, 1.0, WORLD_EFFECT_RADIUS_CAP))


func world_polygon_segments(requested: int, hard_cap: int = WORLD_POLYGON_SEGMENT_CAP) -> int:
	return clampi(requested, 3, clampi(hard_cap, 3, WORLD_POLYGON_SEGMENT_CAP))


func export_accessibility_settings() -> Dictionary:
	return {
		"ui_scale": ui_scale,
		"screen_shake_scale": screen_shake_scale,
		"reduce_flash": reduce_flash,
		"colorblind_mode": colorblind_mode,
		"trackpad_direct_camera": trackpad_direct_camera,
		"camera_follow_strength": camera_follow_strength,
		"alternate_movement_enabled": alternate_movement_enabled,
		"reverse_thrust_scale": reverse_thrust_scale,
		"strafe_turn_assist": strafe_turn_assist,
	}


func _emit_accessibility_changed() -> void:
	accessibility_changed.emit(export_accessibility_settings())
