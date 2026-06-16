extends Node2D
class_name RealityCollapseDirector

signal reality_collapse_level_changed(level: float, data: Dictionary)
signal reality_breach_opened(breach_id: StringName, data: Dictionary)
signal physics_constants_shifted(data: Dictionary)

const SPACETIME_FABRIC_SHADER := preload("res://Scripts/spacetime_fabric.gdshader")

@export var enabled: bool = true
@export var activation_instability: float = 0.68
@export var minimum_wave: int = 18
@export var sample_interval: float = 0.18
@export var breach_interval: float = 9.0
@export var min_breach_interval: float = 4.2
@export var overlay_alpha_cap: float = 0.055
@export var max_active_breaches: int = 4
@export var gravity_constant_swing: float = 0.08
@export var drag_swing: float = 0.035
@export var enable_fabric_shader: bool = true
@export var fabric_update_interval: float = 0.06
@export var fabric_intensity_scale: float = 0.92

var _player: Node2D = null
var _arena_manager: Node = null
var _wave_director: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _time_manager: Node = null
var _sample_elapsed: float = 999.0
var _breach_timer: float = 5.0
var _collapse_level: float = 0.0
var _last_level_bucket: int = -1
var _sequence: int = 0
var _active_breaches: Array[Dictionary] = []
var _base_gravity_constant: float = -1.0
var _base_drag: float = -1.0
var _canvas: CanvasLayer = null
var _overlay: ColorRect = null
var _notice_label: Label = null
var _fabric_material: ShaderMaterial = null
var _fabric_elapsed: float = 999.0


func _ready() -> void:
	add_to_group("reality_collapse_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_screen_effects()
	call_deferred("_resolve_sources")


func _process(delta: float) -> void:
	if not enabled:
		_set_overlay_alpha(0.0)
		_set_fabric_intensity(0.0)
		_restore_player_constants()
		return
	_sample_elapsed += delta
	_breach_timer -= delta
	_update_breaches(delta)
	_update_notice(delta)
	if _sample_elapsed >= maxf(sample_interval, 0.05):
		_sample_elapsed = 0.0
		_resolve_sources()
		_update_collapse_level()
		_apply_physics_constant_drift()
		_emit_level_if_changed()
	_update_overlay(delta)
	if _collapse_level > 0.05 and _breach_timer <= 0.0:
		_breach_timer = _next_breach_interval()
		_open_reality_breach(_choose_breach())


func force_reality_breach(breach_id: StringName = &"screen_edge_breach") -> void:
	_open_reality_breach(breach_id)


func get_reality_collapse_state() -> Dictionary:
	return {
		"level": _collapse_level,
		"active_breaches": _active_breaches.size(),
		"next_breach": maxf(_breach_timer, 0.0),
		"wave": _current_wave(),
	}


func _update_collapse_level() -> void:
	var instability := _instability()
	var wave_pressure := clampf(float(maxi(_current_wave() - minimum_wave, 0)) / 10.0, 0.0, 1.0)
	var phase_pressure := 0.0
	if RunProgress != null and RunProgress.phase >= RunProgress.Phase.LATE_GAME:
		phase_pressure = 0.25
	if instability < activation_instability and wave_pressure <= 0.0 and phase_pressure <= 0.0:
		_collapse_level = move_toward(_collapse_level, 0.0, 0.06)
		return
	var instability_pressure := clampf((instability - activation_instability) / maxf(1.0 - activation_instability, 0.01), 0.0, 1.0)
	_collapse_level = clampf(maxf(instability_pressure, wave_pressure * 0.82) + phase_pressure, 0.0, 1.0)


func _open_reality_breach(breach_id: StringName) -> void:
	if _active_breaches.size() >= max_active_breaches:
		_remove_oldest_breach()
	_sequence += 1
	var data := {
		"id": breach_id,
		"position": _screen_edge_world_position(_sequence),
		"duration": lerpf(2.2, 4.8, _collapse_level),
		"level": _collapse_level,
		"sequence": _sequence,
	}
	match breach_id:
		&"screen_edge_breach":
			_create_screen_edge_breach(data)
		&"corrupted_spacetime":
			_create_corrupted_region(data)
		&"overlapping_timeline":
			_create_timeline_echo(data)
		&"impossible_geometry":
			_create_boundary_fracture(data)
		_:
			_create_screen_edge_breach(data)
	_set_notice(String(breach_id).replace("_", " ").to_upper(), _breach_color(breach_id))
	reality_breach_opened.emit(breach_id, data.duplicate(true))
	_request_camera_shake(0.34 + _collapse_level * 0.38)


func _create_screen_edge_breach(data: Dictionary) -> void:
	var root := Node2D.new()
	root.name = "RealityScreenEdgeBreach"
	root.global_position = data.get("position", global_position)
	root.z_index = 42
	add_child(root)
	var direction := (_player.global_position - root.global_position).normalized() if _player != null else Vector2.RIGHT
	var limb := Polygon2D.new()
	limb.name = "OutsideSpaceLimb"
	limb.color = _safe_color(Color(0.9, 0.3, 1.0, 1.0), 0.22)
	limb.polygon = PackedVector2Array([
		Vector2.ZERO,
		direction.rotated(-0.38) * 360.0,
		direction * 520.0,
		direction.rotated(0.38) * 360.0,
	])
	root.add_child(limb)
	var eye := Line2D.new()
	eye.name = "BreachEye"
	eye.closed = true
	eye.antialiased = true
	eye.width = 3.2
	eye.default_color = _safe_color(Color(1.0, 0.82, 0.24, 1.0), 0.72)
	eye.points = _circle_points(30, 56.0)
	root.add_child(eye)
	_add_breach_entry(root, data)
	_create_zone(root.global_position + direction * 260.0, 260.0, GravityResonanceManager.ZoneType.INVERSION, 0.62, float(data.get("duration", 3.0)))


func _create_corrupted_region(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", global_position)
	var root := _create_fracture_visual(position, 260.0, _safe_color(Color(0.78, 0.38, 1.0, 1.0), 0.5))
	_add_breach_entry(root, data)
	_create_zone(position, 340.0, GravityResonanceManager.ZoneType.TEMPORAL_SCAR, 0.7, float(data.get("duration", 3.0)))
	if _scar_manager != null and _scar_manager.has_method("create_gravity_scar"):
		_scar_manager.call("create_gravity_scar", position, 360.0, GravityScarManager.ScarType.TEMPORAL_RIP, 0.72, 8.0, &"reality_collapse")


func _create_timeline_echo(data: Dictionary) -> void:
	if _player == null:
		return
	var root := Node2D.new()
	root.name = "OverlappingTimelineEcho"
	root.global_position = _player.global_position
	root.z_index = 38
	add_child(root)
	var line := Line2D.new()
	line.name = "TimelineEchoPath"
	line.antialiased = true
	line.width = 3.2
	line.default_color = _safe_color(Color(0.35, 1.0, 0.86, 1.0), 0.44)
	line.points = PackedVector2Array([
		Vector2(-180.0, -36.0),
		Vector2(-80.0, 42.0),
		Vector2(0.0, 0.0),
		Vector2(90.0, -52.0),
		Vector2(210.0, 34.0),
	])
	root.add_child(line)
	_add_breach_entry(root, data)
	if _time_manager != null and _time_manager.has_method("add_near_miss_charge"):
		_time_manager.call("add_near_miss_charge", 16.0)


func _create_boundary_fracture(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", global_position)
	var root := _create_fracture_visual(position, 360.0, _safe_color(Color(1.0, 0.32, 0.16, 1.0), 0.58))
	_add_breach_entry(root, data)
	_create_zone(position, 420.0, GravityResonanceManager.ZoneType.HARMONIC_ORBIT, 0.64, float(data.get("duration", 3.0)))


func _create_fracture_visual(position: Vector2, radius: float, color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "RealityFracture"
	root.global_position = position
	root.z_index = 41
	add_child(root)
	for i in range(5):
		var crack := Line2D.new()
		crack.name = "FractureLine%d" % i
		crack.antialiased = true
		crack.width = 2.0 + float(i % 2)
		crack.default_color = color
		var angle := TAU * float(i) / 5.0 + float(_sequence) * 0.21
		crack.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2.RIGHT.rotated(angle) * radius * 0.42,
			Vector2.RIGHT.rotated(angle + 0.18) * radius,
		])
		root.add_child(crack)
	return root


func _add_breach_entry(root: Node2D, data: Dictionary) -> void:
	_active_breaches.append({
		"root": root,
		"age": 0.0,
		"duration": float(data.get("duration", 3.0)),
		"spin": 0.35 + _collapse_level * 0.8,
	})


func _update_breaches(delta: float) -> void:
	for i in range(_active_breaches.size() - 1, -1, -1):
		var entry := _active_breaches[i]
		var root := entry.get("root") as Node2D
		if root == null or not is_instance_valid(root):
			_active_breaches.remove_at(i)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var duration := maxf(float(entry.get("duration", 3.0)), 0.1)
		root.rotation += float(entry.get("spin", 0.4)) * delta
		root.modulate.a = pow(1.0 - clampf(age / duration, 0.0, 1.0), 0.74)
		entry["age"] = age
		_active_breaches[i] = entry
		if age >= duration:
			if not root.is_queued_for_deletion():
				root.queue_free()
			_active_breaches.remove_at(i)


func _remove_oldest_breach() -> void:
	if _active_breaches.is_empty():
		return
	var entry = _active_breaches.pop_front()
	var root := entry.get("root") as Node
	if root != null and is_instance_valid(root) and not root.is_queued_for_deletion():
		root.queue_free()


func _apply_physics_constant_drift() -> void:
	if _player == null:
		return
	if _collapse_level <= 0.02:
		_restore_player_constants()
		return
	if _base_gravity_constant < 0.0:
		_base_gravity_constant = _safe_player_float(&"gravity_constant", 400.0)
	if _base_drag < 0.0:
		_base_drag = _safe_player_float(&"drag", 0.97)
	var phase := sin(_now_seconds() * 1.7 + float(_sequence))
	var gravity_scale := 1.0 + phase * gravity_constant_swing * _collapse_level
	var drag_scale := 1.0 - phase * drag_swing * _collapse_level
	_player.set("gravity_constant", _base_gravity_constant * gravity_scale)
	_player.set("drag", clampf(_base_drag * drag_scale, 0.82, 1.04))
	physics_constants_shifted.emit({
		"collapse_level": _collapse_level,
		"gravity_scale": gravity_scale,
		"drag_scale": drag_scale,
	})


func _restore_player_constants() -> void:
	if _player == null:
		return
	if _base_gravity_constant >= 0.0:
		_player.set("gravity_constant", _base_gravity_constant)
	if _base_drag >= 0.0:
		_player.set("drag", _base_drag)
	_base_gravity_constant = -1.0
	_base_drag = -1.0


func _create_zone(position: Vector2, radius: float, zone_type: int, intensity: float, duration: float) -> void:
	if _resonance_manager != null and _resonance_manager.has_method("create_manual_resonance_zone"):
		_resonance_manager.call("create_manual_resonance_zone", position, radius, zone_type, intensity, duration)


func _screen_edge_world_position(index: int) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return _player.global_position if _player != null else global_position
	var edge := index % 4
	var screen_pos := Vector2.ZERO
	match edge:
		0:
			screen_pos = Vector2(-180.0, viewport_size.y * 0.35)
		1:
			screen_pos = Vector2(viewport_size.x + 180.0, viewport_size.y * 0.62)
		2:
			screen_pos = Vector2(viewport_size.x * 0.42, -180.0)
		_:
			screen_pos = Vector2(viewport_size.x * 0.58, viewport_size.y + 180.0)
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _choose_breach() -> StringName:
	var options: Array[StringName] = [&"screen_edge_breach", &"corrupted_spacetime"]
	if _collapse_level > 0.42:
		options.append(&"overlapping_timeline")
	if _collapse_level > 0.62:
		options.append(&"impossible_geometry")
	var seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return options[absi(hash("%d:%d:%d:%d" % [seed, _current_wave(), _sequence, int(_collapse_level * 1000.0)])) % options.size()]


func _next_breach_interval() -> float:
	return maxf(breach_interval * lerpf(1.0, 0.46, _collapse_level), min_breach_interval)


func _instability() -> float:
	if _arena_manager == null:
		return 0.0
	var value: Variant = _arena_manager.get("instability")
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return 0.0


func _current_wave() -> int:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return int(RunProgress.wave_index if RunProgress != null else 0)


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if root == null:
		return
	_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
	_wave_director = root.find_child("WaveDirector", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_scar_manager = root.find_child("GravityScarManager", true, false)
	_time_manager = root.find_child("TimeDilationManager", true, false)


func _build_screen_effects() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "RealityCollapseCanvas"
	_canvas.layer = 79
	add_child(_canvas)

	_overlay = ColorRect.new()
	_overlay.name = "RealityCollapseOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_overlay)
	_configure_fabric_material()
	_set_overlay_alpha(0.0)

	_notice_label = Label.new()
	_notice_label.name = "RealityCollapseNotice"
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.offset_left = -280.0
	_notice_label.offset_right = 280.0
	_notice_label.offset_top = 206.0
	_notice_label.offset_bottom = 236.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.text = ""
	_notice_label.modulate.a = 0.0
	_canvas.add_child(_notice_label)


func _update_overlay(delta: float) -> void:
	var pulse := 0.68 + 0.32 * sin(_now_seconds() * 5.5)
	var target_alpha := _collapse_level * overlay_alpha_cap * pulse
	_set_overlay_alpha(target_alpha)
	_update_fabric_shader(delta, target_alpha)


func _set_overlay_alpha(alpha: float) -> void:
	if _overlay == null:
		return
	var capped_alpha := alpha
	if Settings != null and Settings.has_method("world_fill_alpha"):
		capped_alpha = Settings.world_fill_alpha(alpha)
	elif Settings != null and Settings.has_method("flash_alpha"):
		capped_alpha = minf(Settings.flash_alpha(alpha), overlay_alpha_cap)
	else:
		capped_alpha = minf(alpha, overlay_alpha_cap)
	_overlay.color = Color(0.18, 0.2, 0.38, capped_alpha)
	_overlay.visible = capped_alpha > 0.0005


func _configure_fabric_material() -> void:
	if _overlay == null:
		return
	if not enable_fabric_shader:
		_overlay.material = null
		_fabric_material = null
		return
	_fabric_material = ShaderMaterial.new()
	_fabric_material.shader = SPACETIME_FABRIC_SHADER
	_overlay.material = _fabric_material
	_fabric_material.set_shader_parameter("crack_density", 6.2)
	_fabric_material.set_shader_parameter("line_width", 0.007)
	_fabric_material.set_shader_parameter("red_bias", 0.74)
	_fabric_material.set_shader_parameter("triangle_alpha", 0.58)
	_set_fabric_intensity(0.0)


func _update_fabric_shader(delta: float, target_alpha: float) -> void:
	if not enable_fabric_shader:
		_set_fabric_intensity(0.0)
		return
	if _fabric_material == null:
		return
	_fabric_elapsed += delta
	var normalized_alpha := clampf(target_alpha / maxf(overlay_alpha_cap, 0.001), 0.0, 1.0)
	var shader_intensity := normalized_alpha * fabric_intensity_scale
	if _fabric_elapsed >= maxf(fabric_update_interval, 0.02):
		_fabric_elapsed = 0.0
		_fabric_material.set_shader_parameter("real_time", _now_seconds())
	_set_fabric_intensity(shader_intensity)


func _set_fabric_intensity(value: float) -> void:
	if _fabric_material != null:
		_fabric_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.0))


func _set_notice(text: String, color: Color) -> void:
	if _notice_label == null:
		return
	_notice_label.text = text
	_notice_label.modulate = Color(color.r, color.g, color.b, 1.0)


func _update_notice(delta: float) -> void:
	if _notice_label == null or _notice_label.text.is_empty():
		return
	_notice_label.modulate.a = move_toward(_notice_label.modulate.a, 0.0, delta * 0.3)
	if _notice_label.modulate.a <= 0.02:
		_notice_label.text = ""


func _emit_level_if_changed() -> void:
	var bucket := int(round(_collapse_level * 20.0))
	if bucket == _last_level_bucket:
		return
	_last_level_bucket = bucket
	reality_collapse_level_changed.emit(_collapse_level, get_reality_collapse_state())


func _request_camera_shake(amount: float) -> void:
	if _player == null:
		return
	var camera := _player.get_node_or_null("Camera2D")
	if camera == null:
		return
	var shake := camera.get_node_or_null("DamageCameraShake")
	if shake != null and shake.has_method("add_trauma"):
		shake.call("add_trauma", amount)


func _safe_player_float(property_name: StringName, fallback: float) -> float:
	if _player == null:
		return fallback
	var value: Variant = _player.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


func _breach_color(breach_id: StringName) -> Color:
	match breach_id:
		&"corrupted_spacetime":
			return Color(0.78, 0.38, 1.0, 1.0)
		&"overlapping_timeline":
			return Color(0.35, 1.0, 0.86, 1.0)
		&"impossible_geometry":
			return Color(1.0, 0.34, 0.16, 1.0)
	return Color(1.0, 0.82, 0.24, 1.0)


func _safe_color(color: Color, alpha_cap: float) -> Color:
	var alpha := minf(color.a, alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001
