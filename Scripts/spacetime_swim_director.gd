extends Node2D
class_name SpacetimeSwimDirector

signal spacetime_swim_triggered(data: Dictionary)
signal spacetime_glitch_triggered(data: Dictionary)

const SPACETIME_FABRIC_SHADER := preload("res://Scripts/spacetime_fabric.gdshader")

@export var enabled: bool = true
@export var swim_lifetime: float = 0.42
@export var swim_spawn_interval: float = 0.16
@export var max_swim_ribbons: int = 7
@export var max_glitch_slices: int = 5
@export var overlay_alpha_cap: float = 0.075
@export var glitch_cooldown: float = 0.22
@export var ribbon_point_count: int = 9
@export var ribbon_length: float = 96.0
@export var ribbon_width: float = 3.0
@export var phase_shell_radius: float = 54.0
@export var break_boundary_radius: float = 132.0
@export var max_break_boundaries: int = 3
@export var enable_fabric_shader: bool = true
@export var fabric_update_interval: float = 0.05
@export var fabric_intensity_scale: float = 0.76
@export var fabric_crack_density: float = 7.0
@export var fabric_line_width: float = 0.006
@export var fabric_idle_alpha: float = 0.008

var _player: Node2D = null
var _time_manager: Node = null
var _weapon_system: Node = null
var _event_horizon: Node = null
var _canvas: CanvasLayer = null
var _overlay: ColorRect = null
var _glitch_root: Control = null
var _ribbons: Array[Dictionary] = []
var _glitch_slices: Array[Dictionary] = []
var _break_rings: Array[Dictionary] = []
var _swim_intensity := 0.0
var _swim_until := 0.0
var _swim_elapsed := 999.0
var _time_tear_intensity := 0.0
var _last_weapon_swim_time := -999.0
var _last_glitch_time := -999.0
var _fabric_material: ShaderMaterial = null
var _fabric_elapsed: float = 999.0


func _ready() -> void:
	add_to_group("spacetime_swim_director")
	_ensure_screen_nodes()
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		_set_overlay_alpha(0.0)
		_set_fabric_intensity(0.0)
		return
	_resolve_player()
	_update_swim(delta)
	_update_ribbons(delta)
	_update_glitch_slices(delta)
	_update_break_rings(delta)
	_update_overlay(delta)


func _bootstrap() -> void:
	_resolve_sources()
	_connect_sources()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_resolve_player()
	if _player != null:
		_weapon_system = _player.get_node_or_null("WeaponSystem")
	if root != null:
		_time_manager = root.find_child("TimeDilationManager", true, false)
		_event_horizon = root.find_child("EventHorizonDirector", true, false)


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("Player") as Node2D


func _connect_sources() -> void:
	_connect_once(_time_manager, &"dilation_started", Callable(self, "_on_dilation_started"))
	_connect_once(_time_manager, &"dilation_ended", Callable(self, "_on_dilation_ended"))
	_connect_once(_time_manager, &"dilation_break_triggered", Callable(self, "_on_dilation_break_triggered"))
	_connect_once(_time_manager, &"time_tear_intensity_changed", Callable(self, "_on_time_tear_intensity_changed"))
	_connect_once(_time_manager, &"local_time_pocket_entered", Callable(self, "_on_local_time_pocket_entered"))
	_connect_once(_player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))
	_connect_once(_weapon_system, &"weapon_fired", Callable(self, "_on_weapon_fired"))
	_connect_once(_event_horizon, &"event_horizon_started", Callable(self, "_on_event_horizon_started"))
	_connect_once(_event_horizon, &"horizon_escape_scored", Callable(self, "_on_horizon_escape_scored"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_dilation_started() -> void:
	_trigger_swim(_player_position(), _player_velocity(), 0.72, 0.9, Color(0.42, 0.9, 1.0, 1.0), true)


func _on_dilation_ended() -> void:
	_trigger_glitch(0.34, Color(0.72, 0.42, 1.0, 1.0), 4)


func _on_dilation_break_triggered(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", _player_position())
	var velocity: Vector2 = data.get("velocity", _player_velocity())
	var intensity := clampf(float(data.get("intensity", 0.76)), 0.35, 1.0)
	var color := Color(0.42, 0.92, 1.0, 1.0)
	_trigger_glitch(intensity, color, 5)
	_trigger_swim(position, velocity, intensity, 0.58, color, false)
	_spawn_break_ring(position, intensity, color)


func _on_time_tear_intensity_changed(intensity: float) -> void:
	_time_tear_intensity = clampf(intensity, 0.0, 1.0)
	if _time_tear_intensity > 0.52:
		_trigger_swim(_player_position(), _player_velocity(), _time_tear_intensity, 0.34, Color(0.48, 0.78, 1.0, 1.0), _time_tear_intensity > 0.72)


func _on_local_time_pocket_entered(target: Node, multiplier: float, _duration: float) -> void:
	if target != _player:
		return
	_trigger_swim(_player_position(), _player_velocity(), 1.0 - multiplier, 0.5, Color(0.5, 1.0, 0.9, 1.0), false)


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < 0.92:
		return
	var position: Vector2 = data.get("position", _player_position())
	var tangent: Vector2 = data.get("tangent", _player_velocity())
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	_trigger_swim(
		position,
		tangent,
		minf(score * 0.62, 0.64),
		0.34 + score * 0.18,
		Color(0.28, 0.84, 0.78, 1.0),
		score >= 0.98
	)


func _on_weapon_fired(weapon_id: StringName, weapon_data: Dictionary) -> void:
	if weapon_id == &"vector_bolt":
		return
	var now := _now_seconds()
	if now - _last_weapon_swim_time < 0.22:
		return
	_last_weapon_swim_time = now
	var origin: Vector2 = weapon_data.get("origin", _player_position())
	var direction: Vector2 = weapon_data.get("direction", _player_velocity())
	_trigger_swim(origin, direction, 0.46, 0.28, Color(1.0, 0.76, 0.32, 1.0), weapon_id == &"positron_beam")


func _on_event_horizon_started(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", _player_position())
	_trigger_swim(position, _player_position() - position, 0.84, 1.1, Color(0.92, 0.38, 1.0, 1.0), true)


func _on_horizon_escape_scored(data: Dictionary) -> void:
	var direction: Vector2 = data.get("escape_vector", _player_velocity())
	_trigger_swim(_player_position(), direction, 0.9, 1.0, Color(0.36, 1.0, 0.86, 1.0), true)


func _trigger_swim(
	position: Vector2,
	direction: Vector2,
	intensity: float,
	duration: float,
	color: Color,
	with_glitch: bool
) -> void:
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_swim_intensity = maxf(_swim_intensity, clampf(intensity, 0.0, 1.0))
	_swim_until = maxf(_swim_until, _now_seconds() + maxf(duration, 0.05))
	_spawn_ribbon(position, direction.normalized(), _swim_intensity, color)
	if with_glitch:
		_trigger_glitch(_swim_intensity, color, 5)
	spacetime_swim_triggered.emit({
		"position": position,
		"direction": direction.normalized(),
		"intensity": _swim_intensity,
	})


func _trigger_glitch(intensity: float, color: Color, count: int) -> void:
	if _canvas == null or _glitch_root == null:
		return
	var now := _now_seconds()
	if now - _last_glitch_time < glitch_cooldown:
		return
	_last_glitch_time = now
	var available := maxi(max_glitch_slices - _glitch_slices.size(), 1)
	for _i in range(mini(count, available)):
		_spawn_glitch_slice(clampf(intensity, 0.0, 1.0), color)
	spacetime_glitch_triggered.emit({
		"intensity": clampf(intensity, 0.0, 1.0),
		"count": count,
	})


func _update_swim(delta: float) -> void:
	var active := _now_seconds() < _swim_until or _time_tear_intensity > 0.1
	var target := maxf(_time_tear_intensity * 0.62, _swim_intensity if active else 0.0)
	_swim_intensity = move_toward(_swim_intensity, target, delta * 1.8)
	if not active:
		_swim_intensity = move_toward(_swim_intensity, 0.0, delta * 1.2)
	if _swim_intensity <= 0.08 or _player == null:
		return
	_swim_elapsed += delta
	if _swim_elapsed < maxf(swim_spawn_interval, 0.02):
		return
	_swim_elapsed = 0.0
	_spawn_ribbon(_player.global_position, _player_velocity(), _swim_intensity, Color(0.28, 0.84, 0.78, 1.0))


func _spawn_ribbon(position: Vector2, direction: Vector2, intensity: float, color: Color) -> void:
	if _ribbons.size() >= max_swim_ribbons:
		var oldest := _ribbons.pop_front() as Dictionary
		var old_value: Variant = oldest.get("node")
		if old_value != null and is_instance_valid(old_value):
			var old_node := old_value as Node
			if old_node != null:
				old_node.queue_free()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	var ribbon := Line2D.new()
	ribbon.name = "SpacetimeSwimRibbon"
	ribbon.antialiased = true
	ribbon.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon.end_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon.width = ribbon_width * lerpf(0.72, 1.45, intensity)
	ribbon.default_color = _safe_color(color, lerpf(0.16, 0.46, intensity))
	ribbon.z_index = 33
	ribbon.global_position = position
	ribbon.points = _swim_points(direction, intensity)
	add_child(ribbon)

	_ribbons.append({
		"node": ribbon,
		"age": 0.0,
		"lifetime": swim_lifetime * lerpf(0.75, 1.35, intensity),
		"base_width": ribbon.width,
	})


func _spawn_glitch_slice(intensity: float, color: Color) -> void:
	while _glitch_slices.size() >= max_glitch_slices and not _glitch_slices.is_empty():
		var oldest := _glitch_slices.pop_front() as Dictionary
		var old_value: Variant = oldest.get("node")
		if old_value != null and is_instance_valid(old_value):
			var old_node := old_value as Node
			if old_node != null:
				old_node.queue_free()

	var rect := ColorRect.new()
	rect.name = "SpacetimeGlitchSlice"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = _safe_color(color, lerpf(0.08, 0.28, intensity))
	rect.anchor_left = 0.0
	rect.anchor_right = 0.0
	rect.anchor_top = 0.0
	rect.anchor_bottom = 0.0
	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x * randf_range(0.18, 0.74)
	var height := randf_range(2.0, 10.0) * lerpf(0.7, 1.6, intensity)
	rect.position = Vector2(randf_range(0.0, maxf(viewport_size.x - width, 1.0)), randf_range(0.0, viewport_size.y))
	rect.size = Vector2(width, height)
	_glitch_root.add_child(rect)

	_glitch_slices.append({
		"node": rect,
		"age": 0.0,
		"lifetime": randf_range(0.12, 0.28) * lerpf(0.7, 1.4, intensity),
		"drift": randf_range(-70.0, 70.0) * intensity,
	})


func _spawn_break_ring(position: Vector2, intensity: float, color: Color) -> void:
	while _break_rings.size() >= max_break_boundaries and not _break_rings.is_empty():
		var oldest := _break_rings.pop_front() as Dictionary
		var old_value: Variant = oldest.get("node")
		if old_value != null and is_instance_valid(old_value):
			var old_node := old_value as Node
			if old_node != null:
				old_node.queue_free()

	var ring := Line2D.new()
	ring.name = "TimeDilationBreakBoundary"
	ring.closed = true
	ring.antialiased = true
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	ring.width = lerpf(2.0, 4.2, intensity)
	ring.default_color = _safe_color(color, lerpf(0.2, 0.38, intensity))
	ring.z_index = 34
	ring.global_position = position
	ring.points = _ring_points(48, break_boundary_radius * lerpf(0.88, 1.26, intensity))
	add_child(ring)

	_break_rings.append({
		"node": ring,
		"age": 0.0,
		"lifetime": lerpf(0.34, 0.64, intensity),
		"base_width": ring.width,
		"base_scale": ring.scale,
	})


func _update_ribbons(delta: float) -> void:
	for i in range(_ribbons.size() - 1, -1, -1):
		var entry := _ribbons[i]
		var line_value: Variant = entry.get("node")
		if line_value == null or not is_instance_valid(line_value):
			_ribbons.remove_at(i)
			continue
		var line := line_value as Line2D
		if line == null:
			_ribbons.remove_at(i)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var lifetime := maxf(float(entry.get("lifetime", swim_lifetime)), 0.05)
		var t := clampf(age / lifetime, 0.0, 1.0)
		line.modulate.a = pow(1.0 - t, 1.4)
		line.width = float(entry.get("base_width", ribbon_width)) * lerpf(1.0, 0.18, t)
		entry["age"] = age
		_ribbons[i] = entry
		if age >= lifetime:
			line.queue_free()
			_ribbons.remove_at(i)


func _update_glitch_slices(delta: float) -> void:
	for i in range(_glitch_slices.size() - 1, -1, -1):
		var entry := _glitch_slices[i]
		var rect_value: Variant = entry.get("node")
		if rect_value == null or not is_instance_valid(rect_value):
			_glitch_slices.remove_at(i)
			continue
		var rect := rect_value as ColorRect
		if rect == null:
			_glitch_slices.remove_at(i)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var lifetime := maxf(float(entry.get("lifetime", 0.15)), 0.03)
		var t := clampf(age / lifetime, 0.0, 1.0)
		rect.position.x += float(entry.get("drift", 0.0)) * delta
		rect.modulate.a = 1.0 - t
		entry["age"] = age
		_glitch_slices[i] = entry
		if age >= lifetime:
			rect.queue_free()
			_glitch_slices.remove_at(i)


func _update_break_rings(delta: float) -> void:
	for i in range(_break_rings.size() - 1, -1, -1):
		var entry := _break_rings[i]
		var ring_value: Variant = entry.get("node")
		if ring_value == null or not is_instance_valid(ring_value):
			_break_rings.remove_at(i)
			continue
		var ring := ring_value as Line2D
		if ring == null:
			_break_rings.remove_at(i)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var lifetime := maxf(float(entry.get("lifetime", 0.4)), 0.05)
		var t := clampf(age / lifetime, 0.0, 1.0)
		ring.scale = Vector2.ONE * lerpf(1.0, 1.55, t)
		ring.width = float(entry.get("base_width", 2.0)) * lerpf(1.0, 0.25, t)
		ring.modulate.a = pow(1.0 - t, 1.6)
		entry["age"] = age
		_break_rings[i] = entry
		if age >= lifetime:
			ring.queue_free()
			_break_rings.remove_at(i)


func _update_overlay(delta: float) -> void:
	var active_alpha := (_swim_intensity * 0.8 + _time_tear_intensity * 0.45) * overlay_alpha_cap
	var idle_alpha := fabric_idle_alpha if enable_fabric_shader else 0.0
	var target_alpha := minf(overlay_alpha_cap, maxf(active_alpha, idle_alpha))
	if Settings != null and Settings.has_method("flash_alpha"):
		target_alpha = Settings.flash_alpha(target_alpha)
	_set_overlay_alpha(target_alpha)
	_update_fabric_shader(delta, target_alpha)


func _set_overlay_alpha(alpha: float) -> void:
	if _overlay == null:
		return
	_overlay.color = Color(0.12, 0.48, 0.72, clampf(alpha, 0.0, overlay_alpha_cap))
	_overlay.visible = alpha > 0.0005


func _ensure_screen_nodes() -> void:
	_canvas = get_node_or_null("SpacetimeCanvas") as CanvasLayer
	if _canvas == null:
		_canvas = CanvasLayer.new()
		_canvas.name = "SpacetimeCanvas"
		_canvas.layer = 78
		add_child(_canvas)

	_overlay = _canvas.get_node_or_null("SwimOverlay") as ColorRect
	if _overlay == null:
		_overlay = ColorRect.new()
		_overlay.name = "SwimOverlay"
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_canvas.add_child(_overlay)
	_configure_fabric_material()
	_set_overlay_alpha(0.0)

	_glitch_root = _canvas.get_node_or_null("GlitchRoot") as Control
	if _glitch_root == null:
		_glitch_root = Control.new()
		_glitch_root.name = "GlitchRoot"
		_glitch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glitch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_canvas.add_child(_glitch_root)


func _configure_fabric_material() -> void:
	if _overlay == null:
		return
	if not enable_fabric_shader:
		_overlay.material = null
		_fabric_material = null
		return
	_fabric_material = _overlay.material as ShaderMaterial
	if _fabric_material == null or _fabric_material.shader != SPACETIME_FABRIC_SHADER:
		_fabric_material = ShaderMaterial.new()
		_fabric_material.shader = SPACETIME_FABRIC_SHADER
		_overlay.material = _fabric_material
	_fabric_material.set_shader_parameter("crack_density", fabric_crack_density)
	_fabric_material.set_shader_parameter("line_width", fabric_line_width)
	_fabric_material.set_shader_parameter("red_bias", 0.14)
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
	if _fabric_elapsed < maxf(fabric_update_interval, 0.02):
		_set_fabric_intensity(shader_intensity)
		return
	_fabric_elapsed = 0.0
	_fabric_material.set_shader_parameter("real_time", _now_seconds())
	_fabric_material.set_shader_parameter("crack_density", fabric_crack_density)
	_fabric_material.set_shader_parameter("line_width", fabric_line_width)
	_set_fabric_intensity(shader_intensity)


func _set_fabric_intensity(value: float) -> void:
	if _fabric_material != null:
		_fabric_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.0))


func _swim_points(direction: Vector2, intensity: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := direction.orthogonal()
	var radius := phase_shell_radius * lerpf(0.85, 1.42, intensity)
	var arc := lerpf(0.85, 1.55, intensity)
	var rear_offset := -direction * radius * 0.28
	var shimmer := sin(_now_seconds() * 18.0) * radius * 0.04 * intensity
	for i in range(maxi(ribbon_point_count, 4)):
		var t := float(i) / float(maxi(ribbon_point_count - 1, 1))
		var angle := lerpf(-arc, arc, t)
		var point := rear_offset + direction.rotated(angle) * radius
		point += normal * sin(t * PI) * shimmer
		points.append(point)
	return points


func _ring_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 6)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		var wobble := 1.0 + sin(angle * 5.0 + _now_seconds() * 9.0) * 0.025
		points.append(Vector2(cos(angle), sin(angle)) * radius * wobble)
	return points


func _player_position() -> Vector2:
	return _player.global_position if _player != null and is_instance_valid(_player) else global_position


func _player_velocity() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.RIGHT
	var value: Variant = _player.get("velocity")
	if value is Vector2 and value.length_squared() > 0.001:
		return value.normalized()
	return -_player.transform.x.normalized()


func _safe_color(color: Color, alpha_cap: float) -> Color:
	var alpha := minf(color.a, alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
