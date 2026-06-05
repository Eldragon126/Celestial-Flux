# orbital_trajectory_predictor.gd - instability-aware movement forecast
extends Node2D
class_name OrbitalTrajectoryPredictor

signal prediction_recalculated(confidence: float, branch_count: int)
signal prediction_confidence_changed(confidence: float, instability: float)

@export_node_path("CharacterBody2D") var player_path: NodePath = ^"../Player"

@export_group("Simulation")
@export var prediction_steps: int = 140
@export var time_step: float = 0.014
@export var max_prediction_distance: float = 5000.0
@export var max_gravity_sources: int = 4
@export var collision_radius: float = 55.0
@export var stop_speed: float = 8.0
@export var prediction_recalculate_interval: float = 0.045
@export var draw_stride: int = 1
@export var max_draw_segments: int = 132
@export var pressure_hide_threshold: int = 128

@export_group("Ghost Branches")
@export var show_prediction_line: bool = true
@export var branch_min_instability: float = 0.18
@export var max_branch_count: int = 3
@export var branch_angle_degrees: float = 8.5
@export var branch_velocity_variance: float = 0.12
@export var branch_gravity_variance: float = 0.16
@export var branch_step_stride: int = 2
@export var branch_confidence_alpha: float = 0.58

@export_group("Instability")
@export var instability_sample_interval: float = 0.08
@export var confidence_recover_rate: float = 3.0
@export var confidence_drop_rate: float = 7.0
@export var minimum_confidence: float = 0.16
@export var visual_distortion_pixels: float = 38.0
@export var resonance_prediction_weight: float = 0.82
@export var scar_prediction_weight: float = 1.0

@export_group("Visuals")
@export var prediction_color: Color = Color(0.0, 0.85, 1.0, 0.78)
@export var branch_color: Color = Color(0.22, 0.78, 1.0, 0.38)
@export var confidence_color: Color = Color(1.0, 0.92, 0.36, 0.72)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var line_width: float = 2.35
@export var glow_width_multiplier: float = 2.35
@export var glow_alpha_scale: float = 0.32
@export var immediate_danger_segments: int = 25
@export var branch_line_width: float = 1.45
@export var confidence_tick_spacing: int = 18

var _player: CharacterBody2D = null
var _prediction_points: PackedVector2Array = PackedVector2Array()
var _branch_paths: Array[PackedVector2Array] = []
var _predicted_collisions: Array[Dictionary] = []
var _gravity_sources: Array[Node2D] = []
var _resonance_zones: Array[Dictionary] = []

var _resonance_manager: Node = null
var _scar_manager: Node = null
var _arena_manager: Node = null
var _time_manager: Node = null

var _instability_sample_elapsed: float = 999.0
var _calculation_elapsed: float = 999.0
var _prediction_instability: float = 0.0
var _prediction_confidence: float = 1.0
var _last_emitted_confidence: float = 1.0
var _local_time: float = 0.0
var _projectile_pressure: int = 0


func _ready() -> void:
	top_level = true
	_resolve_player()
	_resolve_rule_sources()
	set_process(true)


func _process(delta: float) -> void:
	_local_time += delta
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		return

	_instability_sample_elapsed += delta
	if _instability_sample_elapsed >= maxf(instability_sample_interval, 0.02):
		_instability_sample_elapsed = 0.0
		_resolve_rule_sources()
		_refresh_gravity_sources()
		_sample_instability(delta)

	_calculation_elapsed += delta
	if _calculation_elapsed < maxf(prediction_recalculate_interval, 0.02):
		return
	_calculation_elapsed = 0.0

	_projectile_pressure = _projectile_pressure_count()
	if _projectile_pressure >= pressure_hide_threshold:
		_prediction_points = PackedVector2Array()
		_branch_paths.clear()
		_predicted_collisions.clear()
	else:
		_calculate_trajectory()

	if show_prediction_line:
		queue_redraw()


func _resolve_player() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player == null:
		_player = get_parent() as CharacterBody2D
	if _player == null:
		_player = MultiplayerTargeting.local_player(get_tree()) as CharacterBody2D


func _resolve_rule_sources() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)

	if _scar_manager == null or not is_instance_valid(_scar_manager):
		_scar_manager = root.find_child("GravityScarManager", true, false)

	if _arena_manager == null or not is_instance_valid(_arena_manager):
		_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)

	if _time_manager == null or not is_instance_valid(_time_manager):
		_time_manager = root.find_child("TimeDilationManager", true, false)


func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	if _player == null or not is_instance_valid(_player):
		return

	var seen := {}
	var player_sources: Variant = _player.get("planets")
	if typeof(player_sources) == TYPE_ARRAY:
		for source_value in player_sources:
			var source : Node2D
			if is_instance_valid(source_value):
				source = source_value
			if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
				continue
			var id := source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source)

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source_value in get_tree().get_nodes_in_group(group_name):
			if _gravity_sources.size() >= max_gravity_sources:
				return
			var source := source_value as Node2D
			if source == null or source == _player or not is_instance_valid(source) or source.is_queued_for_deletion():
				continue
			var id := source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source)

	_gravity_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)

	if max_gravity_sources > 0 and _gravity_sources.size() > max_gravity_sources:
		_gravity_sources.resize(max_gravity_sources)


func _sample_instability(delta: float) -> void:
	var previous_confidence := _prediction_confidence
	var target_instability := 0.0

	if _arena_manager != null and is_instance_valid(_arena_manager):
		var arena_value: Variant = _arena_manager.get("instability")
		if typeof(arena_value) == TYPE_FLOAT or typeof(arena_value) == TYPE_INT:
			target_instability = maxf(target_instability, float(arena_value))

	if _resonance_manager != null and is_instance_valid(_resonance_manager):
		if _resonance_manager.has_method("get_resonance_at_position"):
			target_instability = maxf(
				target_instability,
				clampf(float(_resonance_manager.call("get_resonance_at_position", _player.global_position)) * resonance_prediction_weight, 0.0, 1.0)
			)
		if _resonance_manager.has_method("get_active_resonance_zones"):
			var zones_value: Variant = _resonance_manager.call("get_active_resonance_zones")
			_resonance_zones = zones_value if typeof(zones_value) == TYPE_ARRAY else []

	if _scar_manager != null and is_instance_valid(_scar_manager) and _scar_manager.has_method("get_prediction_instability"):
		target_instability = maxf(
			target_instability,
			clampf(float(_scar_manager.call("get_prediction_instability", _player.global_position)) * scar_prediction_weight, 0.0, 1.0)
		)

	if _time_manager != null and is_instance_valid(_time_manager):
		var time_scale_value: Variant = _time_manager.get("current_time_scale")
		if typeof(time_scale_value) == TYPE_FLOAT or typeof(time_scale_value) == TYPE_INT:
			target_instability = maxf(target_instability, clampf(1.0 - float(time_scale_value), 0.0, 1.0) * 0.62)

	_prediction_instability = lerpf(_prediction_instability, clampf(target_instability, 0.0, 1.0), clampf(delta * 5.0, 0.0, 1.0))
	var target_confidence := clampf(1.0 - _prediction_instability * 0.92, minimum_confidence, 1.0)
	var rate := confidence_drop_rate if target_confidence < _prediction_confidence else confidence_recover_rate
	_prediction_confidence = lerpf(_prediction_confidence, target_confidence, clampf(delta * rate, 0.0, 1.0))

	if absf(_prediction_confidence - _last_emitted_confidence) >= 0.04:
		_last_emitted_confidence = _prediction_confidence
		prediction_confidence_changed.emit(_prediction_confidence, _prediction_instability)
	elif absf(previous_confidence - _prediction_confidence) >= 0.001:
		_last_emitted_confidence = _prediction_confidence


func _calculate_trajectory() -> void:
	if _player == null:
		return

	_branch_paths.clear()
	_predicted_collisions.clear()
	_prediction_points = _simulate_branch(0, 0.0, false)

	var branch_count := _branch_count_for_instability()
	for branch_index in range(branch_count):
		var signed_index := _signed_branch_index(branch_index)
		var branch_path := _simulate_branch(branch_index + 1, signed_index, true)
		if branch_path.size() >= 2:
			_branch_paths.append(branch_path)

	prediction_recalculated.emit(_prediction_confidence, _branch_paths.size())


func _simulate_branch(branch_index: int, signed_index: float, is_uncertain_branch: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	if _player == null or not is_instance_valid(_player):
		return points

	var pos := _player.global_position
	var vel := _player.velocity
	var branch_strength := clampf(_prediction_instability, 0.0, 1.0)
	var angle_offset := deg_to_rad(branch_angle_degrees) * signed_index * branch_strength
	if is_uncertain_branch:
		vel = vel.rotated(angle_offset) * (1.0 + branch_velocity_variance * signed_index * branch_strength)

	var distance_traveled := 0.0
	var slingshot_factor := _safe_player_float(&"slingshot_factor", 1.5)
	var orbit_control_bonus := _safe_player_float(&"orbit_control_bonus", 0.0)
	var drag_enabled := bool(_player.get("DRAG_enabled")) if typeof(_player.get("DRAG_enabled")) == TYPE_BOOL else true

	for step in range(prediction_steps):
		var gravity := _calculate_gravity(pos, branch_index, signed_index)
		var closest_source := _closest_source(pos)
		vel += gravity * time_step

		if closest_source != null:
			vel = _apply_predicted_slingshot(
				pos,
				vel,
				gravity,
				closest_source,
				slingshot_factor,
				orbit_control_bonus,
				drag_enabled
			)

		var resonance_accel := _calculate_resonance_acceleration(pos, vel)
		if resonance_accel != Vector2.ZERO:
			vel += resonance_accel * time_step

		if _scar_manager != null and is_instance_valid(_scar_manager) and _scar_manager.has_method("get_prediction_acceleration"):
			var scar_accel_value: Variant = _scar_manager.call("get_prediction_acceleration", pos, vel, branch_index)
			if scar_accel_value is Vector2:
				vel += (scar_accel_value as Vector2) * time_step

		pos += vel * time_step
		distance_traveled += vel.length() * time_step

		if branch_step_stride <= 1 or step % maxi(branch_step_stride, 1) == 0:
			points.append(pos)

		if _record_collision_if_needed(pos, step, branch_index, is_uncertain_branch):
			break

		if distance_traveled > max_prediction_distance or vel.length() < stop_speed:
			break

	return points


func _calculate_gravity(position: Vector2, branch_index: int, signed_index: float) -> Vector2:
	var total := Vector2.ZERO
	var gravity_constant := _safe_player_float(&"gravity_constant", 400.0)
	var min_grav_dist := maxf(_safe_player_float(&"min_grav_dist", 50.0), 1.0)
	var gravity_pull_radius := _safe_player_float(&"gravity_pull_radius", 1800.0)
	var uncertainty := clampf(_prediction_instability, 0.0, 1.0)

	for i in range(_gravity_sources.size()):
		var source := _gravity_sources[i]
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue

		var offset := source.global_position - position
		var raw_dist := offset.length()
		if raw_dist <= 0.001:
			continue
		if gravity_pull_radius > 0.0 and raw_dist > gravity_pull_radius:
			continue

		var mass_value: Variant = source.get("mass")
		var source_mass := float(mass_value) if typeof(mass_value) == TYPE_FLOAT or typeof(mass_value) == TYPE_INT else 100.0
		if branch_index > 0:
			source_mass *= 1.0 + _deterministic_variance(branch_index, i) * branch_gravity_variance * uncertainty

		var dist := maxf(raw_dist, min_grav_dist)
		total += offset / raw_dist * (gravity_constant * source_mass / (dist * dist))

	return total


func _apply_predicted_slingshot(
	position: Vector2,
	velocity_value: Vector2,
	gravity: Vector2,
	source: Node2D,
	slingshot_factor: float,
	orbit_control_bonus: float,
	drag_enabled: bool
) -> Vector2:
	var offset := source.global_position - position
	var raw_dist := offset.length()
	if raw_dist <= 70.0 or raw_dist >= 500.0 or velocity_value.length() <= 1.0:
		return velocity_value
	if gravity.length_squared() <= 0.001:
		return velocity_value

	var grav_dir := gravity.normalized()
	var tangent := grav_dir.orthogonal()
	if tangent.dot(velocity_value) < 0.0:
		tangent = -tangent

	var accel_tangent := gravity.dot(velocity_value.normalized())
	if accel_tangent > 0.0 and drag_enabled:
		velocity_value += tangent * accel_tangent * (slingshot_factor + orbit_control_bonus) * time_step

	return velocity_value


func _calculate_resonance_acceleration(position: Vector2, velocity_value: Vector2) -> Vector2:
	if _resonance_zones.is_empty():
		return Vector2.ZERO

	var total := Vector2.ZERO
	for zone in _resonance_zones:
		var center: Vector2 = zone.get("midpoint", Vector2.ZERO)
		var radius := maxf(float(zone.get("radius", 0.0)), 1.0)
		var offset := position - center
		var distance := offset.length()
		if distance <= 0.001 or distance > radius:
			continue

		var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
		var intensity := clampf(float(zone.get("intensity", 0.0)), 0.0, 1.0)
		var direction := _zone_prediction_direction(zone, offset, velocity_value)
		total += direction * 220.0 * intensity * falloff

	return total


func _zone_prediction_direction(zone: Dictionary, offset_from_center: Vector2, velocity_value: Vector2) -> Vector2:
	var radial := offset_from_center.normalized()
	var tangent := radial.orthogonal()
	if velocity_value != Vector2.ZERO and tangent.dot(velocity_value) < 0.0:
		tangent = -tangent

	var zone_name := StringName(zone.get("zone_type_name", &"compression"))
	match zone_name:
		&"compression":
			return -radial
		&"inversion":
			return radial
		&"slipstream":
			return tangent
		&"temporal_scar":
			return -velocity_value.normalized() if velocity_value != Vector2.ZERO else -radial
		&"harmonic_orbit":
			return (tangent * 0.74 - radial * 0.26).normalized()

	return tangent


func _closest_source(position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var distance := source.global_position.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best = source
	return best


func _record_collision_if_needed(position: Vector2, step: int, branch_index: int, is_uncertain_branch: bool) -> bool:
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		if not source.is_in_group("planets"):
			continue
		if position.distance_to(source.global_position) < collision_radius:
			if not is_uncertain_branch:
				_predicted_collisions.append({
					"position": position,
					"step": step,
					"branch": branch_index,
					"source": source,
				})
			return true
	return false


func _branch_count_for_instability() -> int:
	if _prediction_instability < branch_min_instability:
		return 0

	var available := clampi(int(ceil((_prediction_instability - branch_min_instability) / maxf(1.0 - branch_min_instability, 0.001) * float(max_branch_count))), 1, max_branch_count)
	return available


func _signed_branch_index(branch_index: int) -> float:
	var lane := int(floor(float(branch_index) * 0.5)) + 1
	var direction := -1.0 if branch_index % 2 == 0 else 1.0
	return float(lane) * direction


func _deterministic_variance(branch_index: int, source_index: int) -> float:
	var value := sin(float(branch_index * 37 + source_index * 19) * 12.9898) * 43758.5453
	return (value - floor(value)) * 2.0 - 1.0


func _safe_player_float(property_name: StringName, fallback: float) -> float:
	if _player == null or not is_instance_valid(_player):
		return fallback

	var value: Variant = _player.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _draw() -> void:
	if not show_prediction_line or _prediction_points.size() < 2:
		return
	if _projectile_pressure >= pressure_hide_threshold:
		return

	_draw_branch_predictions()
	_draw_primary_prediction()
	_draw_confidence_ticks()
	_draw_player_origin()


func _draw_branch_predictions() -> void:
	if _branch_paths.is_empty():
		return

	var stride := maxi(draw_stride, 1)
	for branch_index in range(_branch_paths.size()):
		var path := _branch_paths[branch_index]
		var branch_alpha := branch_color.a * branch_confidence_alpha * (1.0 - _prediction_confidence * 0.24)
		var drawn := 0
		for i in range(stride, path.size(), stride):
			if drawn >= max_draw_segments:
				break
			var t := float(i) / float(maxi(path.size(), 1))
			var p1 := to_local(_distorted_point(path[i - stride], i - stride, branch_index + 1))
			var p2 := to_local(_distorted_point(path[i], i, branch_index + 1))
			var alpha := _safe_visual_alpha(branch_alpha * (1.0 - t * 0.72), 0.34)
			if alpha <= 0.004:
				continue
			var glow_alpha := _safe_visual_alpha(alpha * 0.34, 0.18)
			draw_line(
				p1,
				p2,
				Color(branch_color.r, branch_color.g, branch_color.b, glow_alpha),
				maxf(branch_line_width * 2.25, branch_line_width + 1.0),
				true
			)
			draw_line(p1, p2, Color(branch_color.r, branch_color.g, branch_color.b, alpha), branch_line_width, true)
			drawn += 1


func _draw_primary_prediction() -> void:
	var collision_step := _first_collision_step()
	var stride := maxi(draw_stride, 1)
	var drawn := 0
	for i in range(stride, _prediction_points.size(), stride):
		if drawn >= max_draw_segments:
			break
		var p1 := to_local(_distorted_point(_prediction_points[i - stride], i - stride, 0))
		var p2 := to_local(_distorted_point(_prediction_points[i], i, 0))
		var t := float(i) / float(maxi(_prediction_points.size(), 1))
		var color := _primary_segment_color(i, collision_step)
		var alpha := _primary_segment_alpha(color, t)
		if alpha <= 0.004:
			continue
		var glow_alpha := _safe_visual_alpha(alpha * glow_alpha_scale, 0.46)
		draw_line(
			p1,
			p2,
			Color(color.r, color.g, color.b, glow_alpha),
			maxf(line_width * glow_width_multiplier, line_width + 1.0),
			true
		)
		draw_line(p1, p2, Color(color.r, color.g, color.b, alpha), line_width, true)
		drawn += 1


func _primary_segment_color(step_index: int, collision_step: int) -> Color:
	if step_index <= immediate_danger_segments:
		return danger_color
	if collision_step >= 0 and step_index >= maxi(collision_step - immediate_danger_segments, 0):
		return danger_color
	return prediction_color


func _primary_segment_alpha(color: Color, progress: float) -> float:
	var confidence_alpha := lerpf(0.58, 1.0, _prediction_confidence)
	var fade_alpha := 1.0 - progress * 0.65
	return _safe_visual_alpha(color.a * confidence_alpha * fade_alpha, 0.92)


func _draw_confidence_ticks() -> void:
	if confidence_tick_spacing <= 0 or _prediction_instability < 0.08:
		return

	for i in range(confidence_tick_spacing, _prediction_points.size(), confidence_tick_spacing):
		var previous := _prediction_points[i - 1]
		var current := _prediction_points[i]
		var segment := current - previous
		if segment.length_squared() <= 0.001:
			continue
		var t := float(i) / float(maxi(_prediction_points.size(), 1))
		var normal := segment.normalized().orthogonal()
		var width := lerpf(5.0, visual_distortion_pixels * 0.42, _prediction_instability) * (1.0 - t * 0.5)
		var center := to_local(_distorted_point(current, i, 0))
		var alpha := _safe_visual_alpha(confidence_color.a * _prediction_instability * (1.0 - t * 0.65), 0.38)
		draw_line(
			center - normal * width,
			center + normal * width,
			Color(confidence_color.r, confidence_color.g, confidence_color.b, alpha),
			maxf(branch_line_width, 1.0),
			true
		)


func _draw_player_origin() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var alpha := _safe_visual_alpha(lerpf(0.42, 0.9, _prediction_confidence), 0.68)
	var origin := to_local(_player.global_position)
	draw_circle(origin, 10.0, Color(0.0, 1.0, 0.6, alpha * 0.22))
	draw_circle(origin, 5.5, Color(0.0, 1.0, 0.6, alpha))


func _distorted_point(point: Vector2, step: int, branch_index: int) -> Vector2:
	if _prediction_instability <= 0.02:
		return point

	var progress := float(step) / float(maxi(prediction_steps, 1))
	var wave := sin(_local_time * 5.2 + float(step) * 0.24 + float(branch_index) * 1.73)
	var drift := cos(_local_time * 3.6 + float(step) * 0.17 + float(branch_index) * 2.1)
	var amount := visual_distortion_pixels * _prediction_instability * progress * progress
	return point + Vector2(wave, drift).normalized() * amount


func _first_collision_step() -> int:
	if _predicted_collisions.is_empty():
		return -1
	return int(_predicted_collisions[0].get("step", -1))


func get_prediction_debug_state() -> Dictionary:
	return {
		"points": _prediction_points.size(),
		"branches": _branch_paths.size(),
		"confidence": _prediction_confidence,
		"instability": _prediction_instability,
		"collisions": _predicted_collisions.size(),
	}


func _projectile_pressure_count() -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(&"Projectiles")
	return get_tree().get_nodes_in_group("Projectiles").size()


func _safe_visual_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)
