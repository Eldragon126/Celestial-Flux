extends Node

signal accessibility_changed(settings: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_ACCESSIBILITY := "accessibility"

enum ColorblindMode {
	OFF,
	DEUTERANOPIA,
	PROTANOPIA,
	TRITANOPIA,
}

var input_type: bool = false # Arrow keys true; mouse aim if false.
var ui_scale: float = 1.0
var screen_shake_scale: float = 1.0
var reduce_flash: bool = false
var colorblind_mode: int = ColorblindMode.OFF


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
	_emit_accessibility_changed()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_ACCESSIBILITY, "ui_scale", ui_scale)
	config.set_value(SECTION_ACCESSIBILITY, "screen_shake_scale", screen_shake_scale)
	config.set_value(SECTION_ACCESSIBILITY, "reduce_flash", reduce_flash)
	config.set_value(SECTION_ACCESSIBILITY, "colorblind_mode", colorblind_mode)
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
	return alpha * 0.55 if reduce_flash else alpha


func export_accessibility_settings() -> Dictionary:
	return {
		"ui_scale": ui_scale,
		"screen_shake_scale": screen_shake_scale,
		"reduce_flash": reduce_flash,
		"colorblind_mode": colorblind_mode,
	}


func _emit_accessibility_changed() -> void:
	accessibility_changed.emit(export_accessibility_settings())
