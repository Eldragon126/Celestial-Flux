extends Node2D
class_name GravityScarManager

signal gravity_scar_created(scar_data: Dictionary)
signal gravity_scar_intensified(scar_data: Dictionary)
signal gravity_scar_decayed(scar_id: int)
signal gravity_scar_applied(body: Node, impulse: Vector2, scar_data: Dictionary)
signal gravity_scar_instability_changed(value: float)

const CombatStatusApi := preload("res://Scripts/combat_status.gd")

enum ScarType { CURVATURE, VELOCITY_SHEAR, INVERSION_WAKE, TEMPORAL_RIP, HARMONIC_FRACTURE }
enum VisualQuality { OFF, LOW, HIGH }

const SCAR_TYPE_NAMES := {
	ScarType.CURVATURE: &"curvature",
	ScarType.VELOCITY_SHEAR: &"velocity_shear",
	ScarType.INVERSION_WAKE: &"inversion_wake",
	ScarType.TEMPORAL_RIP: &"temporal_rip",
	ScarType.HARMONIC_FRACTURE: &"harmonic_fracture",
}

const SCAR_DISPLAY_NAMES := {
	ScarType.CURVATURE: "Curvature Scar",
	ScarType.VELOCITY_SHEAR: "Velocity Shear",
	ScarType.INVERSION_WAKE: "Inversion Wake",
	ScarType.TEMPORAL_RIP: "Temporal Rip",
	ScarType.HARMONIC_FRACTURE: "Harmonic Fracture",
}

const SCAR_RULE_NAMES := {
	ScarType.CURVATURE: "BEND",
	ScarType.VELOCITY_SHEAR: "SHEAR",
	ScarType.INVERSION_WAKE: "REPEL",
	ScarType.TEMPORAL_RIP: "STRETCH",
	ScarType.HARMONIC_FRACTURE: "ORBIT",
}

const SCAR_COLORS := {
	ScarType.CURVATURE: Color(0.1, 0.82, 1.0, 1.0),
	ScarType.VELOCITY_SHEAR: Color(0.0, 1.0, 0.72, 1.0),
	ScarType.INVERSION_WAKE: Color(1.0, 0.32, 0.12, 1.0),
	ScarType.TEMPORAL_RIP: Color(0.55, 0.64, 1.0, 1.0),
	ScarType.HARMONIC_FRACTURE: Color(1.0, 0.88, 0.24, 1.0),
}

const ANY_SAMPLE_POSITION := Vector2(999999999.0, 999999999.0)

@export var enabled: bool = true

@export_group("Scar Creation")
@export var max_active_scars: int = 5
@export var base_radius: float = 340.0
@export var radius_instability_bonus: float = 220.0
@export var base_duration: float = 24.0
@export var duration_instability_bonus: float = 18.0
@export var residual_intensity: float = 0.16
@export var residual_decay_rate: float = 0.018
@export var merge_distance: float = 180.0
@export var fracture_stamp_cooldown: float = 2.4
@export var slingshot_stamp_min_score: float = 0.92
@export var persistent_scar_intensity_threshold: float = 0.9
@export var persistent_scar_min_radius: float = 260.0
@export var restore_persistent_scars_on_ready: bool = true

@export_group("Field Mutation")
@export var field_tick_interval: float = 0.045
@export var field_acceleration: float = 410.0
@export var temporal_slow_multiplier: float = 0.58
@export var temporal_slow_duration: float = 0.22
@export var max_body_targets_per_tick: int = 42
@export var max_projectile_targets_per_tick: int = 54
@export var player_multiplier: float = 0.38
@export var enemy_multiplier: float = 0.82
@export var boss_multiplier: float = 0.52
@export var projectile_multiplier: float = 0.74
@export var prediction_multiplier: float = 0.42
@export var body_groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses"]
@export var projectile_groups: Array[StringName] = [&"Projectiles", &"player_projectiles", &"enemy_projectiles", &"bullets"]

@export_group("Visuals")
@export var enable_visuals: bool = true
@export_enum("Off", "Low", "High") var visual_quality: int = VisualQuality.HIGH
@export var simple_polygon_visuals: bool = true
@export var ring_segments: int = 42
@export var max_particles_per_scar: int = 12
@export var label_min_intensity: float = 0.22
@export var visual_player_focus_radius: float = 1550.0
@export var visual_radius_cap: float = 380.0
@export_range(0.0, 1.0, 0.01) var visual_fill_alpha_cap: float = 0.065
@export_range(0.0, 1.0, 0.01) var visual_ring_alpha_cap: float = 0.34
@export_range(0.0, 1.0, 0.01) var visual_seam_alpha_cap: float = 0.26

var _scars: Array[Dictionary] = []
var _visuals: Dictionary = {}
var _scar_counter: int = 10000
var _field_elapsed: float = 0.0
var _visual_root: Node2D = null
var _arena_manager: Node = null
var _resonance_manager: Node = null
var _time_manager: Node = null
var _player: Node = null
var _source_cooldowns: Dictionary = {}
var _last_instability_bucket: int = -1
var _local_time: float = 0.0
var _scar_target_buffer: Array[Node2D] = []


func _ready() -> void:
	add_to_group("gravity_scar_manager")
	_ensure_visual_root()
	call_deferred("_resolve_sources")
	if restore_persistent_scars_on_ready:
		call_deferred("_restore_persistent_collapse_scars")
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	if not enabled:
		return

	_local_time += delta
	_update_scar_lifetimes(delta)
	_sync_visuals(delta)
	_emit_instability_if_changed()


func _physics_process(delta: float) -> void:
	if not enabled:
		return

	_field_elapsed += delta
	if _field_elapsed < maxf(field_tick_interval, 0.01):
		return

	var field_delta := _field_elapsed
	_field_elapsed = 0.0
	_resolve_sources()
	_apply_scar_fields(field_delta)


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if _arena_manager == null or not is_instance_valid(_arena_manager):
		_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
		_connect_signal(_arena_manager, &"arena_hazard_spawned", Callable(self, "_on_arena_hazard_spawned"))

	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)
		_connect_signal(_resonance_manager, &"fracture_applied", Callable(self, "_on_resonance_fracture_applied"))
		_connect_signal(_resonance_manager, &"chain_implosion_triggered", Callable(self, "_on_chain_implosion_triggered"))
		_connect_signal(_resonance_manager, &"slingshot_resonance_amplified", Callable(self, "_on_slingshot_resonance_amplified"))

	if _time_manager == null or not is_instance_valid(_time_manager):
		_time_manager = root.find_child("TimeDilationManager", true, false)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		_connect_signal(_player, &"slingshot_mastery_scored", Callable(self, "_on_player_slingshot_mastery"))


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_arena_hazard_spawned(hazard: Node, event_id: StringName) -> void:
	var hazard_2d := hazard as Node2D
	if hazard_2d == null:
		return

	var radius := _safe_node_float(hazard, &"radius", base_radius) * 0.92
	var intensity := clampf(0.38 + _arena_instability() * 0.52, 0.18, 1.0)
	var duration := base_duration + duration_instability_bonus * intensity
	create_gravity_scar(
		hazard_2d.global_position,
		maxf(radius, base_radius * 0.62),
		_scar_type_for_event(event_id),
		intensity,
		duration,
		event_id
	)


func _on_resonance_fracture_applied(position: Vector2, intensity: float) -> void:
	if not _can_stamp_scar(_cooldown_key(position, &"fracture"), fracture_stamp_cooldown):
		return

	create_gravity_scar(
		position,
		base_radius + radius_instability_bonus * clampf(intensity, 0.0, 1.0),
		ScarType.HARMONIC_FRACTURE if intensity > 0.88 else ScarType.CURVATURE,
		clampf(0.42 + intensity * 0.48, 0.18, 1.0),
		base_duration * lerpf(0.75, 1.35, intensity),
		&"resonance_fracture"
	)


func _on_chain_implosion_triggered(implosion_data: Dictionary) -> void:
	var position: Vector2 = implosion_data.get("position", Vector2.ZERO)
	var strength := clampf(float(implosion_data.get("strength", 0.6)) * 0.42, 0.22, 1.0)
	create_gravity_scar(
		position,
		maxf(float(implosion_data.get("radius", base_radius)), base_radius * 0.72),
		ScarType.INVERSION_WAKE,
		strength,
		base_duration * lerpf(0.65, 1.22, strength),
		&"chain_implosion"
	)


func _on_slingshot_resonance_amplified(zone_data: Dictionary) -> void:
	var score := clampf(float(zone_data.get("slingshot_score", 0.0)), 0.0, 1.0)
	if score < slingshot_stamp_min_score:
		return

	var position: Vector2 = zone_data.get("midpoint", Vector2.ZERO)
	create_gravity_scar(
		position,
		maxf(float(zone_data.get("radius", base_radius)) * 0.56, base_radius * 0.52),
		ScarType.HARMONIC_FRACTURE,
		clampf(0.24 + score * 0.36, 0.18, 0.72),
		base_duration * lerpf(0.42, 0.82, score),
		&"slingshot_resonance"
	)


func _on_player_slingshot_mastery(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < slingshot_stamp_min_score:
		return

	var position: Vector2 = data.get("position", Vector2.ZERO)
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT

	var scar_id := create_gravity_scar(
		position + tangent.normalized() * base_radius * 0.34,
		base_radius * lerpf(0.42, 0.68, score),
		ScarType.VELOCITY_SHEAR if score < 0.9 else ScarType.HARMONIC_FRACTURE,
		clampf(0.22 + score * 0.36, 0.16, 0.64),
		base_duration * lerpf(0.32, 0.64, score),
		&"mastered_vector"
	)

	_set_scar_axis(scar_id, tangent.normalized())


func create_gravity_scar(
	position: Vector2,
	radius: float,
	scar_type: int = ScarType.CURVATURE,
	intensity: float = 0.55,
	duration: float = 42.0,
	source_label: StringName = &"manual"
) -> int:
	if not enabled:
		return 0

	var clamped_type := clampi(scar_type, ScarType.CURVATURE, ScarType.HARMONIC_FRACTURE)
	var merged_id := _merge_nearby_scar(position, radius, clamped_type, intensity, duration, source_label)
	if merged_id != 0:
		return merged_id

	if max_active_scars > 0 and _scars.size() >= max_active_scars:
		_remove_lowest_intensity_scar()

	_scar_counter += 1
	var scar := {
		"id": _scar_counter,
		"position": position,
		"radius": maxf(radius, 60.0),
		"type": clamped_type,
		"type_name": _scar_type_name(clamped_type),
		"display_name": _scar_display_name(clamped_type),
		"rule_name": _scar_rule_name(clamped_type),
		"color": _scar_color(clamped_type),
		"axis": _axis_for_scar(position, _scar_counter),
		"base_intensity": clampf(intensity, 0.04, 1.0),
		"intensity": clampf(intensity, 0.04, 1.0),
		"instability": clampf(intensity * _scar_instability_bias(clamped_type), 0.0, 1.0),
		"duration": maxf(duration, 1.0),
		"age": 0.0,
		"decay": 0.0,
		"decay_state": &"fresh",
		"source": source_label,
	}
	_scars.append(scar)
	gravity_scar_created.emit(scar.duplicate(true))
	_record_persistent_scar_if_needed(scar)
	return _scar_counter


func _merge_nearby_scar(
	position: Vector2,
	radius: float,
	scar_type: int,
	intensity: float,
	duration: float,
	source_label: StringName
) -> int:
	var merge_distance_squared := merge_distance * merge_distance
	for idx in range(_scars.size()):
		var scar := _scars[idx]
		if int(scar.get("type", ScarType.CURVATURE)) != scar_type:
			continue
		var scar_position: Vector2 = scar.get("position", Vector2.ZERO)
		if scar_position.distance_squared_to(position) > merge_distance_squared:
			continue

		var next_intensity := clampf(maxf(float(scar.get("intensity", 0.0)), intensity) + 0.08, 0.04, 1.0)
		scar["position"] = scar_position.lerp(position, 0.28)
		scar["radius"] = maxf(float(scar.get("radius", radius)), radius)
		scar["base_intensity"] = maxf(float(scar.get("base_intensity", intensity)), next_intensity)
		scar["intensity"] = next_intensity
		scar["duration"] = maxf(float(scar.get("duration", duration)), duration)
		scar["age"] = minf(float(scar.get("age", 0.0)), float(scar.get("duration", duration)) * 0.42)
		scar["source"] = source_label
		scar["instability"] = clampf(next_intensity * _scar_instability_bias(scar_type), 0.0, 1.0)
		_scars[idx] = scar
		gravity_scar_intensified.emit(scar.duplicate(true))
		return int(scar.get("id", 0))

	return 0


func _update_scar_lifetimes(delta: float) -> void:
	for idx in range(_scars.size() - 1, -1, -1):
		var scar := _scars[idx]
		var age := float(scar.get("age", 0.0)) + delta
		var duration := maxf(float(scar.get("duration", 1.0)), 0.001)
		var base_intensity := clampf(float(scar.get("base_intensity", 0.3)), 0.0, 1.0)
		var life_ratio := clampf(age / duration, 0.0, 1.0)
		var fade_ratio := clampf((life_ratio - 0.62) / 0.38, 0.0, 1.0)
		var next_intensity := lerpf(base_intensity, minf(base_intensity, residual_intensity), fade_ratio)
		var decay_state := &"active"

		if age > duration:
			next_intensity = maxf(float(scar.get("intensity", residual_intensity)) - residual_decay_rate * delta, 0.0)
			decay_state = &"residual"
		elif fade_ratio > 0.0:
			decay_state = &"decaying"

		scar["age"] = age
		scar["intensity"] = next_intensity
		scar["decay"] = life_ratio
		scar["decay_state"] = decay_state
		scar["instability"] = clampf(next_intensity * _scar_instability_bias(int(scar.get("type", ScarType.CURVATURE))), 0.0, 1.0)

		if next_intensity <= 0.02:
			var scar_id := int(scar.get("id", 0))
			gravity_scar_decayed.emit(scar_id)
			_remove_visual(scar_id)
			_scars.remove_at(idx)
		else:
			_scars[idx] = scar


func _apply_scar_fields(delta: float) -> void:
	if _scars.is_empty():
		return

	_apply_group_fields(body_groups, max_body_targets_per_tick, delta, false)
	_apply_group_fields(projectile_groups, max_projectile_targets_per_tick, delta, true)


func _apply_group_fields(groups: Array[StringName], target_limit: int, delta: float, projectile_pass: bool) -> void:
	var affected := 0
	_scar_target_buffer.clear()

	if RuntimeRegistry != null:
		var sample_center := global_position
		if _player != null and is_instance_valid(_player):
			var player_2d := _player as Node2D
			if player_2d != null and not player_2d.is_queued_for_deletion():
				sample_center = player_2d.global_position
		RuntimeRegistry.fill_targets_in_radius(groups, sample_center, 2600.0, target_limit, true, _scar_target_buffer)
	else:
		var seen := {}
		for group_name in groups:
			for node in get_tree().get_nodes_in_group(group_name):
				if _scar_target_buffer.size() >= target_limit:
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
				_scar_target_buffer.append(node_2d)

	for body in _scar_target_buffer:
		if affected >= target_limit:
			return
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if projectile_pass and not _accepts_velocity(body):
			continue

		var velocity := _body_velocity(body)
		var acceleration := get_scar_acceleration_at_position(body.global_position, velocity, body)
		if acceleration == Vector2.ZERO:
			continue

		var multiplier := _target_multiplier(body)
		if projectile_pass:
			multiplier *= projectile_multiplier
		var impulse := acceleration * multiplier * delta
		if impulse.length_squared() <= 0.001:
			continue

		CombatStatusApi.add_velocity(body, impulse)
		_apply_temporal_side_effects(body, delta)
		body.set_meta(&"gravity_scar_pressure", minf(1.0, acceleration.length() / maxf(field_acceleration, 1.0)))
		gravity_scar_applied.emit(body, impulse, _nearest_scar_data(body.global_position))
		affected += 1


func get_scar_acceleration_at_position(position: Vector2, velocity_value: Vector2, target: Node = null) -> Vector2:
	var total := Vector2.ZERO
	for scar in _scars:
		total += _scar_acceleration(scar, position, velocity_value, target)
	return total


func get_prediction_acceleration(position: Vector2, velocity_value: Vector2, branch_index: int = 0) -> Vector2:
	var total := Vector2.ZERO
	for scar in _scars:
		var branch_bias := 1.0 + _branch_bias(branch_index, int(scar.get("id", 0))) * 0.18
		total += _scar_acceleration(scar, position, velocity_value, null) * prediction_multiplier * branch_bias
	return total


func get_prediction_instability(position: Vector2) -> float:
	var best := 0.0
	for scar in _scars:
		var center: Vector2 = scar.get("position", Vector2.ZERO)
		var radius := maxf(float(scar.get("radius", 1.0)), 1.0)
		var distance := position.distance_to(center)
		if distance > radius * 1.35:
			continue
		var local := float(scar.get("instability", 0.0)) * (1.0 - clampf(distance / (radius * 1.35), 0.0, 1.0))
		best = maxf(best, local)
	return best


func get_scar_debug_state(sample_position: Vector2 = ANY_SAMPLE_POSITION) -> Dictionary:
	var best := _nearest_scar_data(sample_position)
	return {
		"active": _scars.size(),
		"strongest": best,
		"instability": _total_instability(),
	}


func get_active_gravity_scars() -> Array[Dictionary]:
	return _scars.duplicate(true)


func dampen_scars_in_radius(position: Vector2, radius: float, amount: float) -> int:
	if radius <= 0.0 or amount <= 0.0:
		return 0

	var radius_squared := radius * radius
	var affected := 0
	for idx in range(_scars.size() - 1, -1, -1):
		var scar := _scars[idx]
		var center: Vector2 = scar.get("position", Vector2.ZERO)
		var distance_squared := center.distance_squared_to(position)
		if distance_squared > radius_squared:
			continue
		var falloff := 1.0 - clampf(sqrt(distance_squared) / radius, 0.0, 1.0)
		var next_intensity := maxf(float(scar.get("intensity", 0.0)) - amount * falloff, 0.0)
		if next_intensity <= 0.02:
			var scar_id := int(scar.get("id", 0))
			gravity_scar_decayed.emit(scar_id)
			_remove_visual(scar_id)
			_scars.remove_at(idx)
		else:
			scar["intensity"] = next_intensity
			scar["base_intensity"] = minf(float(scar.get("base_intensity", next_intensity)), next_intensity)
			scar["instability"] = clampf(next_intensity * _scar_instability_bias(int(scar.get("type", ScarType.CURVATURE))), 0.0, 1.0)
			scar["decay_state"] = &"harvested"
			_scars[idx] = scar
		affected += 1
	return affected


func get_scar_count_in_radius(position: Vector2, radius: float) -> int:
	var count := 0
	var radius_squared := radius * radius
	for scar in _scars:
		var center: Vector2 = scar.get("position", Vector2.ZERO)
		if center.distance_squared_to(position) <= radius_squared:
			count += 1
	return count


func clear_all_scars() -> void:
	for scar in _scars:
		_remove_visual(int(scar.get("id", 0)))
	_scars.clear()


func _restore_persistent_collapse_scars() -> void:
	if RunProgress == null or not RunProgress.has_method("get_persistent_collapse_scars"):
		return
	var scars := RunProgress.get_persistent_collapse_scars()
	for scar_data in scars:
		if typeof(scar_data) != TYPE_DICTIONARY:
			continue
		create_gravity_scar(
			scar_data.get("position", Vector2.ZERO),
			float(scar_data.get("radius", base_radius)),
			int(scar_data.get("type", ScarType.HARMONIC_FRACTURE)),
			clampf(float(scar_data.get("intensity", 0.64)), 0.05, 1.0),
			base_duration + duration_instability_bonus,
			&"persistent_collapse"
		)


func _record_persistent_scar_if_needed(scar: Dictionary) -> void:
	if RunProgress == null or not RunProgress.has_method("record_persistent_collapse_scar"):
		return
	var source := StringName(scar.get("source", &"manual"))
	if source == &"persistent_collapse" or source == &"mastered_vector" or source == &"slingshot_resonance":
		return
	var intensity := float(scar.get("intensity", 0.0))
	var radius := float(scar.get("radius", 0.0))
	var persistent_source := (
		source == &"planet_collapse"
		or source == &"positron_beam"
		or source == &"resonance_cascade"
		or source == &"vacuum_collapse"
		or source == &"relativistic_rail"
		or source == &"event_horizon"
		or source == &"gravity_maw"
	)
	if not persistent_source and (intensity < persistent_scar_intensity_threshold or radius < persistent_scar_min_radius):
		return
	RunProgress.record_persistent_collapse_scar(scar.duplicate(true))


func _scar_acceleration(scar: Dictionary, position: Vector2, velocity_value: Vector2, target: Node) -> Vector2:
	var center: Vector2 = scar.get("position", Vector2.ZERO)
	var radius := maxf(float(scar.get("radius", 1.0)), 1.0)
	var offset := position - center
	var distance := offset.length()
	if distance <= 0.001 or distance > radius:
		return Vector2.ZERO

	var radial := offset / distance
	var tangent := radial.orthogonal()
	if velocity_value != Vector2.ZERO and tangent.dot(velocity_value) < 0.0:
		tangent = -tangent

	var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
	var intensity := clampf(float(scar.get("intensity", 0.0)), 0.0, 1.0)
	var axis: Vector2 = scar.get("axis", Vector2.RIGHT)
	if axis.length_squared() <= 0.001:
		axis = Vector2.RIGHT
	axis = axis.normalized()

	var direction := Vector2.ZERO
	match int(scar.get("type", ScarType.CURVATURE)):
		ScarType.CURVATURE:
			direction = (tangent * 0.72 - radial * 0.28).normalized()
		ScarType.VELOCITY_SHEAR:
			var shear := axis if axis.dot(velocity_value) >= 0.0 else -axis
			direction = (shear * 0.82 + tangent * 0.18).normalized()
		ScarType.INVERSION_WAKE:
			direction = (radial * 0.82 + tangent * 0.18).normalized()
		ScarType.TEMPORAL_RIP:
			if target != null and target.is_in_group("Player"):
				direction = (tangent * 0.8 - radial * 0.2).normalized()
			else:
				direction = -velocity_value.normalized() if velocity_value != Vector2.ZERO else -radial
		ScarType.HARMONIC_FRACTURE:
			var pulse := sin(_local_time * 2.4 + float(scar.get("id", 0)) * 0.17)
			direction = (tangent * 0.72 + radial * pulse * 0.28).normalized()

	return direction * field_acceleration * intensity * falloff


func _apply_temporal_side_effects(body: Node2D, _delta: float) -> void:
	if body.is_in_group("Player"):
		return

	var nearest := _nearest_scar_data(body.global_position)
	if nearest.is_empty() or int(nearest.get("type", ScarType.CURVATURE)) != ScarType.TEMPORAL_RIP:
		return

	var local_intensity := clampf(float(nearest.get("local_intensity", 0.0)), 0.0, 1.0)
	if local_intensity <= 0.08:
		return

	var multiplier := lerpf(1.0, temporal_slow_multiplier, local_intensity)
	var time_manager := _get_time_manager()
	if time_manager != null and time_manager.has_method("apply_local_slow_to_target"):
		time_manager.call("apply_local_slow_to_target", body, multiplier, temporal_slow_duration)
	else:
		CombatStatusApi.apply_local_slow(body, multiplier, temporal_slow_duration)


func _nearest_scar_data(sample_position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_intensity := 0.0

	for scar in _scars:
		var center: Vector2 = scar.get("position", Vector2.ZERO)
		var radius := maxf(float(scar.get("radius", 1.0)), 1.0)
		var distance := sample_position.distance_to(center)
		if sample_position == ANY_SAMPLE_POSITION:
			distance = 0.0
		if distance > radius * 1.18:
			continue

		var local_intensity := clampf(float(scar.get("intensity", 0.0)) * (1.0 - distance / (radius * 1.18)), 0.0, 1.0)
		if local_intensity <= best_intensity:
			continue

		best = scar.duplicate(true)
		best["local_intensity"] = local_intensity
		best_intensity = local_intensity

	return best


func _sync_visuals(delta: float) -> void:
	if not enable_visuals or visual_quality == VisualQuality.OFF:
		_clear_visuals()
		return

	_ensure_visual_root()
	var active_ids := {}
	for scar in _scars:
		var scar_id := int(scar.get("id", 0))
		active_ids[scar_id] = true
		if not _scar_in_player_focus(scar):
			_remove_visual(scar_id)
			continue
		_update_visual(scar, delta)

	for visual_id in _visuals.keys():
		if not active_ids.has(int(visual_id)):
			_remove_visual(int(visual_id))


func _scar_in_player_focus(scar: Dictionary) -> bool:
	if visual_player_focus_radius <= 0.0:
		return true
	if _player == null or not is_instance_valid(_player):
		return true
	var player_2d := _player as Node2D
	if player_2d == null or player_2d.is_queued_for_deletion():
		return true
	var center: Vector2 = scar.get("position", Vector2.ZERO)
	var radius := maxf(float(scar.get("radius", base_radius)), 1.0)
	var max_distance := visual_player_focus_radius + radius
	return player_2d.global_position.distance_squared_to(center) <= max_distance * max_distance


func _visual_object(visual: Dictionary, key: String) -> Object:
	var value: Variant = visual.get(key)
	if value == null or not is_instance_valid(value):
		return null
	var object := value as Object
	if object == null:
		return null
	if object is Node:
		var node := object as Node
		if node.is_queued_for_deletion():
			return null
	return object


func _ensure_visual_root() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	if not enable_visuals or visual_quality == VisualQuality.OFF:
		return

	_visual_root = Node2D.new()
	_visual_root.name = "GravityScarVisuals"
	_visual_root.top_level = true
	_visual_root.z_index = -6
	add_child(_visual_root)


func _update_visual(scar: Dictionary, delta: float) -> void:
	var scar_id := int(scar.get("id", 0))
	if scar_id == 0:
		return

	var visual_value: Variant = _visuals.get(scar_id, {})
	var visual: Dictionary = visual_value if typeof(visual_value) == TYPE_DICTIONARY else {}
	if visual.is_empty():
		visual = _make_visual(scar_id, int(scar.get("type", ScarType.CURVATURE)))
		_visuals[scar_id] = visual

	var root_value: Variant = visual.get("root")
	if root_value == null or not is_instance_valid(root_value):
		_visuals.erase(scar_id)
		return
	var root := root_value as Node2D
	if root == null or root.is_queued_for_deletion():
		_visuals.erase(scar_id)
		return

	var core := _visual_object(visual, "core") as Polygon2D
	var ring := _visual_object(visual, "ring") as Line2D
	var seam := _visual_object(visual, "seam") as Line2D
	var label := _visual_object(visual, "label") as Label
	var particles := _visual_object(visual, "particles") as GPUParticles2D
	var material := _visual_object(visual, "particle_material") as ParticleProcessMaterial

	var position: Vector2 = scar.get("position", Vector2.ZERO)
	var gameplay_radius: float = maxf(float(scar.get("radius", base_radius)), 1.0)
	var visual_radius: float = _visual_radius(gameplay_radius)
	var intensity := clampf(float(scar.get("intensity", 0.0)), 0.0, 1.0)
	var scar_type := int(scar.get("type", ScarType.CURVATURE))
	var color: Color = _scar_color(scar_type)
	var alpha: float = lerpf(0.12, 0.62, intensity)
	var axis: Vector2 = scar.get("axis", Vector2.RIGHT)
	if axis.length_squared() <= 0.001:
		axis = Vector2.RIGHT

	root.global_position = position
	root.rotation += delta * _visual_spin(scar_type)

	if core != null:
		core.polygon = _soft_circle_points(_visual_segments(16), visual_radius * 0.45)
		core.color = Color(color.r, color.g, color.b, _visual_alpha(alpha * 0.12, visual_fill_alpha_cap))
	if ring != null:
		ring.points = _circle_points(_visual_segments(ring_segments), visual_radius)
		ring.width = lerpf(1.4, 3.2, intensity)
		ring.default_color = Color(color.r, color.g, color.b, _visual_alpha(alpha, visual_ring_alpha_cap))
	if seam != null:
		seam.rotation = axis.angle() - root.rotation
		seam.points = PackedVector2Array([
			Vector2(-visual_radius * 0.86, 0.0),
			Vector2(-visual_radius * 0.18, sin(_local_time * 5.0) * visual_radius * 0.03),
			Vector2(visual_radius * 0.18, -sin(_local_time * 4.4) * visual_radius * 0.03),
			Vector2(visual_radius * 0.86, 0.0),
		])
		seam.width = lerpf(1.2, 3.8, intensity)
		seam.default_color = Color(1.0, 1.0, 1.0, _visual_alpha(alpha * 0.58, visual_seam_alpha_cap))
	if label != null:
		label.visible = intensity >= label_min_intensity
		label.text = "%s  %s" % [String(scar.get("display_name", "Scar")).to_upper(), String(scar.get("rule_name", "BEND"))]
		label.position = Vector2(-128.0, -visual_radius - 32.0)
		label.size = Vector2(256.0, 26.0)
		label.modulate = Color(color.r, color.g, color.b, _visual_alpha(lerpf(0.34, 0.92, intensity), 0.72))
	if particles != null:
		particles.emitting = visual_quality == VisualQuality.HIGH and intensity > 0.2
		particles.amount = int(lerpf(3.0, float(max_particles_per_scar), intensity))
		if material != null:
			material.emission_sphere_radius = visual_radius * 0.64


func _make_visual(scar_id: int, scar_type: int) -> Dictionary:
	_ensure_visual_root()
	if _visual_root == null:
		return {}

	var root := Node2D.new()
	root.name = "GravityScar_%d" % scar_id
	_visual_root.add_child(root)

	var core := Polygon2D.new()
	core.name = "ScarCore"
	core.z_index = -2
	root.add_child(core)

	var ring := Line2D.new()
	ring.name = "ScarRing"
	ring.closed = true
	ring.antialiased = true
	ring.z_index = -1
	root.add_child(ring)

	var seam := Line2D.new()
	seam.name = "ScarSeam"
	seam.antialiased = true
	seam.z_index = 0
	root.add_child(seam)

	var label := Label.new()
	label.name = "ScarRuleLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	root.add_child(label)

	var particles: GPUParticles2D = null
	var material: ParticleProcessMaterial = null
	if visual_quality == VisualQuality.HIGH and max_particles_per_scar > 0:
		particles = GPUParticles2D.new()
		particles.name = "ScarParticles"
		particles.amount = max_particles_per_scar
		particles.lifetime = 1.4
		particles.randomness = 0.58
		particles.fixed_fps = 45
		material = _make_particle_material(scar_type)
		particles.process_material = material
		root.add_child(particles)

	return {
		"root": root,
		"core": core,
		"ring": ring,
		"seam": seam,
		"label": label,
		"particles": particles,
		"particle_material": material,
	}


func _make_particle_material(scar_type: int) -> ParticleProcessMaterial:
	var base: Color = _scar_color(scar_type)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(base.r, base.g, base.b, 0.72))
	gradient.set_color(1, Color(base.r, base.g, base.b, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.spread = 180.0
	material.initial_velocity_min = 12.0
	material.initial_velocity_max = 84.0
	material.orbit_velocity_min = -0.85
	material.orbit_velocity_max = 0.95
	material.radial_accel_min = -22.0
	material.radial_accel_max = 38.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.0
	material.scale_max = 4.6
	material.color_ramp = texture
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.44
	return material


func _remove_visual(scar_id: int) -> void:
	var visual_value: Variant = _visuals.get(scar_id, {})
	if typeof(visual_value) == TYPE_DICTIONARY:
		var visual: Dictionary = visual_value
		var root_value: Variant = visual.get("root")
		if root_value != null and is_instance_valid(root_value):
			var root := root_value as Node
			if root != null and not root.is_queued_for_deletion():
				root.queue_free()
	_visuals.erase(scar_id)


func _clear_visuals() -> void:
	for visual_id in _visuals.keys():
		_remove_visual(int(visual_id))
	if _visual_root != null and is_instance_valid(_visual_root) and not _visual_root.is_queued_for_deletion():
		_visual_root.queue_free()
	_visual_root = null


func _remove_lowest_intensity_scar() -> void:
	var weakest_idx := -1
	var weakest_intensity := INF
	for idx in range(_scars.size()):
		var intensity := float(_scars[idx].get("intensity", 0.0))
		if intensity < weakest_intensity:
			weakest_intensity = intensity
			weakest_idx = idx

	if weakest_idx < 0:
		return

	var scar_id := int(_scars[weakest_idx].get("id", 0))
	_remove_visual(scar_id)
	_scars.remove_at(weakest_idx)
	gravity_scar_decayed.emit(scar_id)


func _set_scar_axis(scar_id: int, axis: Vector2) -> void:
	if axis.length_squared() <= 0.001:
		return
	for idx in range(_scars.size()):
		if int(_scars[idx].get("id", 0)) == scar_id:
			var scar := _scars[idx]
			scar["axis"] = axis.normalized()
			_scars[idx] = scar
			return


func _target_multiplier(target: Node) -> float:
	if target.is_in_group("Player"):
		return player_multiplier
	if target.is_in_group("bosses"):
		return boss_multiplier
	if target.is_in_group("enemies") or target.is_in_group("wave_enemy"):
		return enemy_multiplier
	return 1.0


func _accepts_velocity(node: Node) -> bool:
	var velocity_value: Variant = node.get("velocity")
	if velocity_value is Vector2:
		return true
	var linear_velocity_value: Variant = node.get("linear_velocity")
	return linear_velocity_value is Vector2


func _body_velocity(node: Node) -> Vector2:
	var velocity_value: Variant = node.get("velocity")
	if velocity_value is Vector2:
		return velocity_value

	var linear_velocity_value: Variant = node.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value

	return Vector2.ZERO


func _get_time_manager() -> Node:
	if _time_manager != null and is_instance_valid(_time_manager) and not _time_manager.is_queued_for_deletion():
		return _time_manager

	var root := get_tree().current_scene
	if root == null:
		return null

	_time_manager = root.find_child("TimeDilationManager", true, false)
	return _time_manager


func _emit_instability_if_changed() -> void:
	var bucket := int(_total_instability() * 10.0)
	if bucket == _last_instability_bucket:
		return
	_last_instability_bucket = bucket
	gravity_scar_instability_changed.emit(_total_instability())


func _total_instability() -> float:
	var total := 0.0
	for scar in _scars:
		total = maxf(total, float(scar.get("instability", 0.0)))
	return total


func _arena_instability() -> float:
	if _arena_manager == null or not is_instance_valid(_arena_manager):
		return 0.0

	var value: Variant = _arena_manager.get("instability")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return clampf(float(value), 0.0, 1.0)

	return 0.0


func _safe_node_float(node: Node, property_name: StringName, fallback: float) -> float:
	if node == null or not is_instance_valid(node):
		return fallback

	var value: Variant = node.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)

	return fallback


func _can_stamp_scar(key: StringName, cooldown: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var next_time := float(_source_cooldowns.get(key, 0.0))
	if now < next_time:
		return false

	_source_cooldowns[key] = now + cooldown
	return true


func _cooldown_key(position: Vector2, label: StringName) -> StringName:
	var cell_x := int(round(position.x / 220.0))
	var cell_y := int(round(position.y / 220.0))
	return StringName("%s_%d_%d" % [String(label), cell_x, cell_y])


func _scar_type_for_event(event_id: StringName) -> int:
	match event_id:
		&"tide_slipstream", &"nebula_shear", &"wormhole_shear":
			return ScarType.VELOCITY_SHEAR
		&"tide_inversion":
			return ScarType.INVERSION_WAKE
		&"temporal_pocket":
			return ScarType.TEMPORAL_RIP
		&"resonance_storm":
			return ScarType.HARMONIC_FRACTURE
	return ScarType.CURVATURE


func _scar_instability_bias(scar_type: int) -> float:
	match scar_type:
		ScarType.INVERSION_WAKE:
			return 1.0
		ScarType.TEMPORAL_RIP:
			return 0.94
		ScarType.HARMONIC_FRACTURE:
			return 0.86
		ScarType.VELOCITY_SHEAR:
			return 0.72
	return 0.68


func _branch_bias(branch_index: int, scar_id: int) -> float:
	if branch_index == 0:
		return 0.0
	var value := sin(float(branch_index * 31 + scar_id * 7) * 4.118)
	return clampf(value, -1.0, 1.0)


func _axis_for_scar(position: Vector2, seed: int) -> Vector2:
	var angle := fmod(absf(sin(position.x * 0.011 + position.y * 0.017 + float(seed) * 1.37) * 17.0), TAU)
	return Vector2.RIGHT.rotated(angle)


func _visual_spin(scar_type: int) -> float:
	match scar_type:
		ScarType.VELOCITY_SHEAR:
			return 0.92
		ScarType.INVERSION_WAKE:
			return -0.74
		ScarType.TEMPORAL_RIP:
			return 0.28
		ScarType.HARMONIC_FRACTURE:
			return 1.16
	return 0.46


func _scar_type_name(scar_type: int) -> StringName:
	return SCAR_TYPE_NAMES.get(scar_type, &"curvature")


func _scar_display_name(scar_type: int) -> String:
	return String(SCAR_DISPLAY_NAMES.get(scar_type, "Curvature Scar"))


func _scar_rule_name(scar_type: int) -> String:
	return String(SCAR_RULE_NAMES.get(scar_type, "BEND"))


func _scar_color(scar_type: int) -> Color:
	return SCAR_COLORS.get(scar_type, Color(0.1, 0.82, 1.0, 1.0))


func _visual_radius(radius: float) -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(radius, visual_radius_cap)
	return clampf(radius, 0.0, maxf(visual_radius_cap, 1.0))


func _visual_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 3)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _soft_circle_points(count: int, base_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 3)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		var wave := sin(angle * 3.0 + _local_time * 0.5) * 0.05 + cos(angle * 7.0) * 0.03
		points.append(Vector2(cos(angle), sin(angle)) * base_radius * (1.0 + wave))
	return points


func _visual_segments(requested: int, hard_cap: int = 32) -> int:
	var cap_limit := 18 if simple_polygon_visuals else 32
	var local_cap := mini(hard_cap, cap_limit)
	if Settings != null and Settings.has_method("world_polygon_segments"):
		return Settings.world_polygon_segments(requested, local_cap)
	return clampi(requested, 3, local_cap)
