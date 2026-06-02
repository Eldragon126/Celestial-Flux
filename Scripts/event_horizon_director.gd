extends Node2D
class_name EventHorizonDirector

signal event_horizon_started(data: Dictionary)
signal event_horizon_ended(data: Dictionary)
signal event_horizon_intensity_changed(intensity: float)
signal horizon_escape_scored(data: Dictionary)

const CombatStatusApi := preload("res://Scripts/combat_status.gd")

@export var enabled: bool = true

@export_group("Trigger")
@export var scan_interval: float = 0.08
@export var trigger_pressure: float = 0.78
@export var minimum_instability: float = 0.26
@export var trigger_speed_ratio: float = 1.05
@export var critical_health_threshold: float = 0.28
@export var gravity_pressure_full: float = 860.0
@export var near_miss_pressure_decay: float = 1.8
@export var cooldown: float = 18.0

@export_group("Moment Field")
@export var duration: float = 2.7
@export var horizon_radius: float = 760.0
@export var pull_strength: float = 1080.0
@export var player_escape_tangent: float = 420.0
@export var player_escape_outward: float = 160.0
@export var enemy_slow_multiplier: float = 0.34
@export var projectile_slow_multiplier: float = 0.26
@export var local_slow_duration: float = 0.2
@export var field_tick_interval: float = 0.025
@export var max_targets_per_tick: int = 72
@export var affected_groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles", &"Projectiles"]

@export_group("Aftermath")
@export var create_resonance_afterimage: bool = true
@export var create_gravity_scar: bool = true
@export var scar_duration_multiplier: float = 1.45
@export var near_escape_time_charge: float = 34.0

@export_group("Visuals")
@export var screen_warp_enabled: bool = true
@export var overlay_layer: int = 44
@export var overlay_fade_rate: float = 7.5

const AUTO_FOCUS_POSITION := Vector2(999999999.0, 999999999.0)

var _player: CharacterBody2D = null
var _time_manager: Node = null
var _resonance_manager: Node = null
var _arena_manager: Node = null
var _scar_manager: Node = null
var _momentum_component: Node = null

var _active: bool = false
var _timer: float = 0.0
var _cooldown_remaining: float = 0.0
var _scan_elapsed: float = 999.0
var _field_elapsed: float = 0.0
var _intensity: float = 0.0
var _target_overlay_intensity: float = 0.0
var _focus_position: Vector2 = Vector2.ZERO
var _near_miss_pressure: float = 0.0
var _last_intensity_bucket: int = -1
var _activation_data: Dictionary = {}
var _horizon_target_buffer: Array[Node2D] = []
var _nearest_gravity_buffer: Array[Node2D] = []

var _overlay_layer: CanvasLayer = null
var _overlay_rect: ColorRect = null
var _overlay_material: ShaderMaterial = null


func _ready() -> void:
	add_to_group("event_horizon_director")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	call_deferred("_resolve_sources")
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	if not enabled:
		_update_overlay(delta)
		return

	_resolve_sources()
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_near_miss_pressure = maxf(_near_miss_pressure - near_miss_pressure_decay * delta, 0.0)

	if _active:
		_timer -= delta
		_update_active_intensity(delta)
		if _timer <= 0.0:
			_end_event_horizon()
	else:
		_scan_elapsed += delta
		if _scan_elapsed >= maxf(scan_interval, 0.03):
			_scan_elapsed = 0.0
			_try_start_event_horizon()

	_update_overlay(delta)
	_emit_intensity_if_changed()


func _physics_process(delta: float) -> void:
	if not enabled or not _active:
		return

	_field_elapsed += delta
	if _field_elapsed < maxf(field_tick_interval, 0.005):
		return

	var field_delta := _field_elapsed
	_field_elapsed = 0.0
	_apply_horizon_field(field_delta)


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
		if _player != null:
			_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
			_connect_signal(_momentum_component, &"near_miss_velocity_gained", Callable(self, "_on_near_miss_velocity_gained"))
			_connect_signal(_momentum_component, &"kinetic_overload_started", Callable(self, "_on_kinetic_overload_started"))

	if _time_manager == null or not is_instance_valid(_time_manager):
		_time_manager = root.find_child("TimeDilationManager", true, false)

	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)
		_connect_signal(_resonance_manager, &"resonance_instability_changed", Callable(self, "_on_resonance_instability_changed"))

	if _arena_manager == null or not is_instance_valid(_arena_manager):
		_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)

	if _scar_manager == null or not is_instance_valid(_scar_manager):
		_scar_manager = root.find_child("GravityScarManager", true, false)
		_connect_signal(_scar_manager, &"gravity_scar_instability_changed", Callable(self, "_on_gravity_scar_instability_changed"))


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _try_start_event_horizon() -> void:
	if _cooldown_remaining > 0.0 or _player == null or not is_instance_valid(_player):
		return

	var pressure := _calculate_survival_pressure()
	var instability := _calculate_instability_pressure()
	var speed_ratio := _player.velocity.length() / maxf(_player_speed_cap(), 1.0)
	var health_pressure := _calculate_health_pressure()
	var gravity_pressure := _calculate_gravity_pressure()

	var primary_trigger := pressure >= trigger_pressure and instability >= minimum_instability and speed_ratio >= trigger_speed_ratio
	var critical_trigger := health_pressure >= 1.0 - critical_health_threshold and speed_ratio >= 0.72 and gravity_pressure >= 0.48

	if not primary_trigger and not critical_trigger:
		return

	var event_intensity := clampf(maxf(maxf(pressure, instability), gravity_pressure), 0.42, 1.0)
	_start_event_horizon(_horizon_focus_position(), event_intensity, {
		"pressure": pressure,
		"instability": instability,
		"speed_ratio": speed_ratio,
		"health_pressure": health_pressure,
		"gravity_pressure": gravity_pressure,
	})


func force_event_horizon(position: Vector2 = AUTO_FOCUS_POSITION, forced_intensity: float = 1.0) -> void:
	var event_position := position
	if event_position == AUTO_FOCUS_POSITION:
		event_position = _horizon_focus_position()
	_start_event_horizon(event_position, clampf(forced_intensity, 0.1, 1.0), {"forced": true})


func _start_event_horizon(position: Vector2, event_intensity: float, context: Dictionary) -> void:
	if _active:
		return

	_active = true
	_timer = duration
	_field_elapsed = field_tick_interval
	_focus_position = position
	_intensity = clampf(event_intensity, 0.1, 1.0)
	_target_overlay_intensity = _intensity

	_activation_data = {
		"position": _focus_position,
		"radius": horizon_radius,
		"intensity": _intensity,
		"duration": duration,
		"context": context,
	}

	if _player != null and is_instance_valid(_player):
		_player.set_meta(&"event_horizon_active", true)
		_player.set_meta(&"event_horizon_intensity", _intensity)

	if create_resonance_afterimage:
		_create_resonance_afterimage()

	if create_gravity_scar:
		_create_horizon_scar()

	event_horizon_started.emit(_activation_data.duplicate(true))


func _end_event_horizon() -> void:
	if not _active:
		return

	_active = false
	_cooldown_remaining = cooldown
	_target_overlay_intensity = 0.0

	var escaped := _player != null and is_instance_valid(_player) and _player.global_position.distance_to(_focus_position) > horizon_radius * 0.36
	var data := _activation_data.duplicate(true)
	data["escaped"] = escaped
	data["remaining_speed"] = _player.velocity.length() if _player != null and is_instance_valid(_player) else 0.0

	if _player != null and is_instance_valid(_player):
		if _player.has_meta(&"event_horizon_active"):
			_player.remove_meta(&"event_horizon_active")
		if _player.has_meta(&"event_horizon_intensity"):
			_player.remove_meta(&"event_horizon_intensity")

	if escaped:
		_reward_near_escape(data)
		horizon_escape_scored.emit(data)

	event_horizon_ended.emit(data)
	_activation_data.clear()


func _update_active_intensity(delta: float) -> void:
	var life_ratio := clampf(_timer / maxf(duration, 0.001), 0.0, 1.0)
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() / 64.0)
	_intensity = lerpf(_intensity, clampf(float(_activation_data.get("intensity", 0.7)) * pulse * minf(1.0, life_ratio * 1.8), 0.0, 1.0), clampf(delta * 5.0, 0.0, 1.0))
	_target_overlay_intensity = _intensity

	if _player != null and is_instance_valid(_player):
		_player.set_meta(&"event_horizon_intensity", _intensity)


func _apply_horizon_field(delta: float) -> void:
	var affected := 0
	var radius_squared := horizon_radius * horizon_radius
	_horizon_target_buffer.clear()

	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(affected_groups, _focus_position, horizon_radius, max_targets_per_tick, true, _horizon_target_buffer)
	else:
		var seen := {}
		for group_name in affected_groups:
			for node in get_tree().get_nodes_in_group(group_name):
				if _horizon_target_buffer.size() >= max_targets_per_tick:
					break
				if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
					continue
				var node_2d := node as Node2D
				if node_2d == null:
					continue
				var id := node_2d.get_instance_id()
				if seen.has(id):
					continue
				seen[id] = true
				_horizon_target_buffer.append(node_2d)

	for body in _horizon_target_buffer:
		if affected >= max_targets_per_tick:
			return
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue

		var offset := body.global_position - _focus_position
		var distance_squared := offset.length_squared()
		if distance_squared <= 0.001 or distance_squared > radius_squared:
			continue

		var distance := sqrt(distance_squared)
		var radial := offset / distance
		var falloff := 1.0 - clampf(distance / horizon_radius, 0.0, 1.0)
		var impulse := _horizon_impulse_for_body(body, radial, falloff, delta)
		if impulse.length_squared() <= 0.001:
			continue

		CombatStatusApi.add_velocity(body, impulse)
		_apply_horizon_time_effect(body, falloff)
		affected += 1


func _horizon_impulse_for_body(body: Node2D, radial: Vector2, falloff: float, delta: float) -> Vector2:
	if body.is_in_group("Player"):
		var velocity_value := _body_velocity(body)
		var tangent := radial.orthogonal()
		if velocity_value != Vector2.ZERO and tangent.dot(velocity_value) < 0.0:
			tangent = -tangent
		return (tangent * player_escape_tangent + radial * player_escape_outward) * falloff * _intensity * delta

	var pull := -radial * pull_strength * falloff * _intensity * delta
	if body.is_in_group("bosses"):
		pull *= 0.46
	elif body.is_in_group("enemies") or body.is_in_group("wave_enemy"):
		pull *= 0.72
	return pull


func _apply_horizon_time_effect(body: Node2D, falloff: float) -> void:
	if body.is_in_group("Player"):
		return

	var multiplier := projectile_slow_multiplier if body.is_in_group("enemy_projectiles") or body.is_in_group("Projectiles") else enemy_slow_multiplier
	multiplier = lerpf(1.0, multiplier, clampf(falloff * _intensity, 0.0, 1.0))

	if _time_manager != null and is_instance_valid(_time_manager) and _time_manager.has_method("apply_local_slow_to_target"):
		_time_manager.call("apply_local_slow_to_target", body, multiplier, local_slow_duration)
	else:
		CombatStatusApi.apply_local_slow(body, multiplier, local_slow_duration)


func _create_resonance_afterimage() -> void:
	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		return
	if not _resonance_manager.has_method("create_manual_resonance_zone"):
		return

	_resonance_manager.call(
		"create_manual_resonance_zone",
		_focus_position,
		horizon_radius * 0.58,
		3,
		_intensity,
		duration + 0.85
	)


func _create_horizon_scar() -> void:
	if _scar_manager == null or not is_instance_valid(_scar_manager):
		return
	if not _scar_manager.has_method("create_gravity_scar"):
		return

	var scar_position := _focus_position
	if _player != null and is_instance_valid(_player):
		scar_position = _focus_position.lerp(_player.global_position, 0.34)

	_scar_manager.call(
		"create_gravity_scar",
		scar_position,
		horizon_radius * 0.72,
		3,
		_intensity,
		duration * scar_duration_multiplier + 18.0,
		&"event_horizon"
	)


func _reward_near_escape(data: Dictionary) -> void:
	if _time_manager != null and is_instance_valid(_time_manager) and _time_manager.has_method("add_near_miss_charge"):
		_time_manager.call("add_near_miss_charge", near_escape_time_charge * clampf(float(data.get("intensity", _intensity)), 0.2, 1.0))


func _calculate_survival_pressure() -> float:
	var speed_ratio := 0.0
	if _player != null and is_instance_valid(_player):
		speed_ratio = _player.velocity.length() / maxf(_player_speed_cap(), 1.0)

	var instability := _calculate_instability_pressure()
	var gravity_pressure := _calculate_gravity_pressure()
	var health_pressure := _calculate_health_pressure()
	var resonance_pressure := _calculate_resonance_pressure()
	var pressure := (
		clampf(speed_ratio / maxf(trigger_speed_ratio, 0.1), 0.0, 1.35) * 0.34
		+ instability * 0.24
		+ gravity_pressure * 0.18
		+ health_pressure * 0.14
		+ resonance_pressure * 0.06
		+ clampf(_near_miss_pressure, 0.0, 1.0) * 0.04
	)
	return clampf(pressure, 0.0, 1.25)


func _calculate_instability_pressure() -> float:
	var pressure := 0.0
	if _arena_manager != null and is_instance_valid(_arena_manager):
		var value: Variant = _arena_manager.get("instability")
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			pressure = maxf(pressure, clampf(float(value), 0.0, 1.0))

	if _scar_manager != null and is_instance_valid(_scar_manager) and _scar_manager.has_method("get_prediction_instability") and _player != null and is_instance_valid(_player):
		pressure = maxf(pressure, clampf(float(_scar_manager.call("get_prediction_instability", _player.global_position)), 0.0, 1.0))

	return pressure


func _calculate_resonance_pressure() -> float:
	if _resonance_manager == null or not is_instance_valid(_resonance_manager) or _player == null or not is_instance_valid(_player):
		return 0.0
	if not _resonance_manager.has_method("get_resonance_at_position"):
		return 0.0
	return clampf(float(_resonance_manager.call("get_resonance_at_position", _player.global_position)), 0.0, 1.0)


func _calculate_health_pressure() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0

	var health_component := _player.get_node_or_null("HealthComponent")
	if health_component == null:
		return 0.0

	var max_health := _safe_node_float(health_component, &"max_health", 1.0)
	var current_health := _safe_node_float(health_component, &"current_health", max_health)
	var ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	return 1.0 - ratio


func _calculate_gravity_pressure() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0

	if _player.has_method("calculate_gravity"):
		var gravity_value: Variant = _player.call("calculate_gravity")
		if gravity_value is Vector2:
			return clampf((gravity_value as Vector2).length() / maxf(gravity_pressure_full, 1.0), 0.0, 1.0)

	return 0.0


func _horizon_focus_position() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return global_position

	var best_source := _nearest_gravity_source()
	if best_source != null:
		return best_source.global_position

	var direction := _player.velocity.normalized() if _player.velocity.length_squared() > 0.001 else -_player.transform.x.normalized()
	return _player.global_position + direction * horizon_radius * 0.42


func _nearest_gravity_source() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		return null

	if RuntimeRegistry != null:
		_nearest_gravity_buffer.clear()
		RuntimeRegistry.fill_nearest_gravity_sources(_player.global_position, _nearest_gravity_buffer, 1, 0.0, _player)
		if not _nearest_gravity_buffer.is_empty():
			return _nearest_gravity_buffer[0]
		return null

	var best: Node2D = null
	var best_distance := INF
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var source := node as Node2D
			if source == null or source == _player or not is_instance_valid(source) or source.is_queued_for_deletion():
				continue
			var distance := source.global_position.distance_squared_to(_player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = source
	return best


func _player_speed_cap() -> float:
	if _player == null or not is_instance_valid(_player):
		return 1.0

	var current_cap := _safe_node_float(_player, &"current_max_speed", 0.0)
	var base_cap := _safe_node_float(_player, &"max_speed", 1000.0)
	return maxf(maxf(current_cap, base_cap), 1.0)


func _body_velocity(body: Node) -> Vector2:
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	return Vector2.ZERO


func _safe_node_float(node: Node, property_name: StringName, fallback: float) -> float:
	if node == null or not is_instance_valid(node):
		return fallback
	var value: Variant = node.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _on_near_miss_velocity_gained(_target: Node, amount: float) -> void:
	_near_miss_pressure = clampf(_near_miss_pressure + amount / 380.0, 0.0, 1.0)


func _on_kinetic_overload_started(speed: float) -> void:
	_near_miss_pressure = clampf(_near_miss_pressure + speed / 2600.0, 0.0, 1.0)


func _on_resonance_instability_changed(zone_data: Dictionary) -> void:
	_near_miss_pressure = maxf(_near_miss_pressure, clampf(float(zone_data.get("instability", 0.0)) * 0.42, 0.0, 1.0))


func _on_gravity_scar_instability_changed(value: float) -> void:
	_near_miss_pressure = maxf(_near_miss_pressure, clampf(value * 0.28, 0.0, 1.0))


func _build_overlay() -> void:
	if not screen_warp_enabled:
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "EventHorizonOverlay"
	_overlay_layer.layer = overlay_layer
	add_child(_overlay_layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "HorizonWarp"
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.color = Color.TRANSPARENT
	_overlay_layer.add_child(_overlay_rect)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity = 0.0;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 offset = UV - center;
	float dist = length(offset);
	float gravity = smoothstep(0.86, 0.02, dist) * intensity;
	vec2 direction = normalize(offset + vec2(0.0001, -0.0001));
	vec2 warped_uv = UV + direction * gravity * 0.018 * sin(dist * 42.0 - TIME * 8.0);
	vec4 screen_color = texture(screen_texture, warped_uv);
	float rim = smoothstep(0.28, 0.96, dist);
	vec3 cyan = vec3(0.08, 0.95, 1.0);
	vec3 red = vec3(1.0, 0.12, 0.04);
	vec3 color = mix(screen_color.rgb, cyan, gravity * 0.1);
	color += red * rim * intensity * 0.22;
	color += cyan * (1.0 - rim) * intensity * 0.08;
	COLOR = vec4(color, intensity * (0.18 + rim * 0.48));
}
"""
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter("intensity", 0.0)
	_overlay_rect.material = _overlay_material
	_overlay_rect.visible = false


func _update_overlay(delta: float) -> void:
	if _overlay_rect == null or _overlay_material == null:
		return

	var current := float(_overlay_material.get_shader_parameter("intensity"))
	var next := lerpf(current, _target_overlay_intensity, clampf(delta * overlay_fade_rate, 0.0, 1.0))
	_overlay_material.set_shader_parameter("intensity", next)
	_overlay_material.set_shader_parameter("center", _focus_screen_position())
	_overlay_rect.visible = next > 0.01


func _focus_screen_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var screen_position := get_viewport().get_canvas_transform() * _focus_position
	return Vector2(
		clampf(screen_position.x / viewport_size.x, 0.0, 1.0),
		clampf(screen_position.y / viewport_size.y, 0.0, 1.0)
	)


func _emit_intensity_if_changed() -> void:
	var bucket := int(_intensity * 20.0) if _active else 0
	if bucket == _last_intensity_bucket:
		return
	_last_intensity_bucket = bucket
	event_horizon_intensity_changed.emit(_intensity if _active else 0.0)


func get_event_horizon_debug_state() -> Dictionary:
	return {
		"active": _active,
		"intensity": _intensity if _active else 0.0,
		"cooldown": _cooldown_remaining,
		"timer": _timer,
		"near_miss_pressure": _near_miss_pressure,
		"focus": _focus_position,
	}
