extends Node

signal accessibility_changed(settings: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_ACCESSIBILITY := "accessibility"
const SECTION_INPUT := "input"
const WORLD_ALPHA_CAP: float = 0.32
const WORLD_FILL_ALPHA_CAP: float = 0.055
const WORLD_LIGHT_ALPHA_CAP: float = 0.2
const WORLD_EFFECT_RADIUS_CAP: float = 420.0
const WORLD_POLYGON_SEGMENT_CAP: int = 32
const REDUCED_FLASH_ALPHA_SCALE: float = 0.58
const REDUCED_FLASH_PERSISTENT_ALPHA_SCALE: float = 0.9
const REDUCED_FLASH_PERSISTENT_ALPHA_FLOOR: float = 0.095
const REDUCED_FLASH_PROJECTILE_ALPHA_FLOOR: float = 0.72

enum ColorblindMode {
	OFF,
	DEUTERANOPIA,
	PROTANOPIA,
	TRITANOPIA,
}

var input_type: bool = false # Controller true; mouse aim if false.
var controller_deadzone: float = 0.24
var controller_detect_threshold: float = 0.42
var controller_right_stick_aim: bool = true
var ui_scale: float = 1.0
var screen_shake_scale: float = 1.0
var reduce_flash: bool = false
var readability_halos_enabled: bool = true
var colorblind_mode: int = ColorblindMode.OFF
var trackpad_direct_camera: bool = false
var camera_follow_strength: float = 1.0
var alternate_movement_enabled: bool = false
var reverse_thrust_scale: float = 0.46
var strafe_turn_assist: float = 0.22
var player_auto_orbit_enabled: bool = false
var auto_orbiting_celestials_enabled: bool = true


func _ready() -> void:
	_ensure_runtime_input_actions()
	load_settings()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		set_input_type(true)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= controller_detect_threshold:
			set_input_type(true)
	elif event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey:
		set_input_type(false)


func set_input_type(use_controller: bool) -> void:
	if input_type == use_controller:
		return
	input_type = use_controller
	_emit_accessibility_changed()


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


func set_readability_halos_enabled(value: bool) -> void:
	readability_halos_enabled = value
	_emit_accessibility_changed()
	save_settings()


func set_controller_deadzone(value: float) -> void:
	controller_deadzone = clampf(value, 0.08, 0.55)
	_emit_accessibility_changed()
	save_settings()


func set_controller_right_stick_aim(value: bool) -> void:
	controller_right_stick_aim = value
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


func set_auto_orbiting_celestials_enabled(value: bool) -> void:
	auto_orbiting_celestials_enabled = value
	_emit_accessibility_changed()
	save_settings()


func set_player_auto_orbit_enabled(value: bool) -> void:
	player_auto_orbit_enabled = value
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
	readability_halos_enabled = bool(config.get_value(SECTION_ACCESSIBILITY, "readability_halos_enabled", readability_halos_enabled))
	colorblind_mode = clampi(
		int(config.get_value(SECTION_ACCESSIBILITY, "colorblind_mode", colorblind_mode)),
		ColorblindMode.OFF,
		ColorblindMode.TRITANOPIA
	)
	controller_deadzone = clampf(float(config.get_value(SECTION_INPUT, "controller_deadzone", controller_deadzone)), 0.08, 0.55)
	controller_right_stick_aim = bool(config.get_value(SECTION_INPUT, "controller_right_stick_aim", controller_right_stick_aim))
	trackpad_direct_camera = bool(config.get_value(SECTION_INPUT, "trackpad_direct_camera", trackpad_direct_camera))
	camera_follow_strength = clampf(float(config.get_value(SECTION_INPUT, "camera_follow_strength", camera_follow_strength)), 0.25, 2.5)
	alternate_movement_enabled = bool(config.get_value(SECTION_INPUT, "alternate_movement_enabled", alternate_movement_enabled))
	player_auto_orbit_enabled = bool(config.get_value(SECTION_INPUT, "player_auto_orbit_enabled", false))
	# The original key was shipped for the wrong feature and defaulted off. Use a
	# migrated key so existing players receive the corrected on-by-default event setting.
	auto_orbiting_celestials_enabled = bool(config.get_value(SECTION_INPUT, "orbiting_celestial_events_enabled_v2", true))
	reverse_thrust_scale = clampf(float(config.get_value(SECTION_INPUT, "reverse_thrust_scale", reverse_thrust_scale)), 0.15, 0.8)
	strafe_turn_assist = clampf(float(config.get_value(SECTION_INPUT, "strafe_turn_assist", strafe_turn_assist)), 0.0, 0.6)
	_emit_accessibility_changed()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_ACCESSIBILITY, "ui_scale", ui_scale)
	config.set_value(SECTION_ACCESSIBILITY, "screen_shake_scale", screen_shake_scale)
	config.set_value(SECTION_ACCESSIBILITY, "reduce_flash", reduce_flash)
	config.set_value(SECTION_ACCESSIBILITY, "readability_halos_enabled", readability_halos_enabled)
	config.set_value(SECTION_ACCESSIBILITY, "colorblind_mode", colorblind_mode)
	config.set_value(SECTION_INPUT, "controller_deadzone", controller_deadzone)
	config.set_value(SECTION_INPUT, "controller_right_stick_aim", controller_right_stick_aim)
	config.set_value(SECTION_INPUT, "trackpad_direct_camera", trackpad_direct_camera)
	config.set_value(SECTION_INPUT, "camera_follow_strength", camera_follow_strength)
	config.set_value(SECTION_INPUT, "alternate_movement_enabled", alternate_movement_enabled)
	config.set_value(SECTION_INPUT, "player_auto_orbit_enabled", player_auto_orbit_enabled)
	config.set_value(SECTION_INPUT, "auto_orbiting_celestials_enabled", auto_orbiting_celestials_enabled)
	config.set_value(SECTION_INPUT, "orbiting_celestial_events_enabled_v2", auto_orbiting_celestials_enabled)
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
	if not reduce_flash or capped_alpha <= 0.0:
		return capped_alpha
	# Reduced flash limits sudden luminance changes, not persistent navigation
	# geometry. Keep gravity rings readable instead of dimming them like bursts.
	var readable_floor := minf(REDUCED_FLASH_PERSISTENT_ALPHA_FLOOR, capped_alpha)
	return maxf(capped_alpha * REDUCED_FLASH_PERSISTENT_ALPHA_SCALE, readable_floor)


func projectile_alpha(alpha: float) -> float:
	var capped_alpha := clampf(alpha, 0.0, 1.0)
	if not reduce_flash or capped_alpha <= 0.0:
		return capped_alpha
	return maxf(capped_alpha * 0.92, minf(REDUCED_FLASH_PROJECTILE_ALPHA_FLOOR, capped_alpha))


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
		"readability_halos_enabled": readability_halos_enabled,
		"colorblind_mode": colorblind_mode,
		"input_type": input_type,
		"controller_deadzone": controller_deadzone,
		"controller_right_stick_aim": controller_right_stick_aim,
		"trackpad_direct_camera": trackpad_direct_camera,
		"camera_follow_strength": camera_follow_strength,
		"alternate_movement_enabled": alternate_movement_enabled,
		"player_auto_orbit_enabled": player_auto_orbit_enabled,
		"auto_orbiting_celestials_enabled": auto_orbiting_celestials_enabled,
		"reverse_thrust_scale": reverse_thrust_scale,
		"strafe_turn_assist": strafe_turn_assist,
	}


func _emit_accessibility_changed() -> void:
	accessibility_changed.emit(export_accessibility_settings())


func _ensure_runtime_input_actions() -> void:
	_ensure_action_exists(&"back", 0.2)
	_ensure_action_exists(&"move_left", 0.2)
	_ensure_action_exists(&"move_right", 0.2)
	_ensure_action_exists(&"move_down", 0.2)
	_ensure_action_exists(&"aim_left", 0.2)
	_ensure_action_exists(&"aim_right", 0.2)
	_ensure_action_exists(&"aim_up", 0.2)
	_ensure_action_exists(&"aim_down", 0.2)
	_ensure_action_exists(&"gravity_heat_map", 0.2)

	_add_key_event(&"back", KEY_S)
	_add_key_event(&"move_down", KEY_DOWN)
	_add_key_event(&"move_left", KEY_A)
	_add_key_event(&"move_left", KEY_LEFT)
	_add_key_event(&"move_right", KEY_D)
	_add_key_event(&"move_right", KEY_RIGHT)
	_add_key_event(&"gravity_heat_map", KEY_F10)

	_add_joy_axis_event(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_event(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_event(&"back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_event(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_event(&"aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis_event(&"aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis_event(&"aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis_event(&"aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_button_event(&"gravity_heat_map", JOY_BUTTON_DPAD_UP)


func _ensure_action_exists(action_name: StringName, deadzone: float) -> void:
	if InputMap.has_action(action_name):
		InputMap.action_set_deadzone(action_name, deadzone)
		return
	InputMap.add_action(action_name, deadzone)


func _add_key_event(action_name: StringName, key: Key) -> void:
	if not InputMap.has_action(action_name) or _has_key_event(action_name, key):
		return
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action_name, event)


func _add_joy_button_event(action_name: StringName, button: int) -> void:
	if not InputMap.has_action(action_name) or _has_joy_button_event(action_name, button):
		return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)


func _add_joy_axis_event(action_name: StringName, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action_name) or _has_joy_axis_event(action_name, axis, axis_value):
		return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)


func _has_key_event(action_name: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		var key_event := event as InputEventKey
		if key_event != null and (key_event.physical_keycode == key or key_event.keycode == key):
			return true
	return false


func _has_joy_button_event(action_name: StringName, button: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		var button_event := event as InputEventJoypadButton
		if button_event != null and button_event.button_index == button:
			return true
	return false


func _has_joy_axis_event(action_name: StringName, axis: int, axis_value: float) -> bool:
	for event in InputMap.action_get_events(action_name):
		var axis_event := event as InputEventJoypadMotion
		if axis_event != null and axis_event.axis == axis and signf(axis_event.axis_value) == signf(axis_value):
			return true
	return false
