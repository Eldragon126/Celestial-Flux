extends Node2D
class_name VectorAnomalyDirector

signal micro_lens_created(lens_data: Dictionary)
signal vacuum_collapse_triggered(collapse_data: Dictionary)
signal relativistic_impact_triggered(impact_data: Dictionary)
signal orbital_memory_recorded(memory_data: Dictionary)
signal time_debt_zone_created(zone_data: Dictionary)
signal resonance_cascade_triggered(cascade_data: Dictionary)
signal orbital_debris_seeded(debris: Node, debris_data: Dictionary)

const CombatStatusApi := preload("res://Scripts/combat_status.gd")
const GravityDebrisScript := preload("res://Scripts/gravity_debris.gd")
const TARGET_GROUPS: Array[StringName] = [&"Projectiles", &"player_projectiles", &"enemy_projectiles", &"enemies", &"wave_enemy", &"bosses", &"law_gravity_debris"]
const PLAYER_TARGET_GROUPS: Array[StringName] = [&"Projectiles", &"player_projectiles", &"enemy_projectiles", &"enemies", &"wave_enemy", &"bosses", &"law_gravity_debris", &"Player"]

@export var enabled: bool = true
@export var field_tick_interval: float = 0.045
@export var system_resolve_interval: float = 0.35
@export var max_targets_per_tick: int = 56

@export_group("Micro-Lensing Emitter")
@export var micro_lens_radius: float = 270.0
@export var micro_lens_strength: float = 520.0
@export var micro_lens_duration: float = 2.6
@export var micro_lens_forward_offset: float = 150.0
@export var micro_lens_drift_speed: float = 130.0
@export var max_active_micro_lenses: int = 6

@export_group("Vacuum Collapse Injector")
@export var collapse_radius: float = 360.0
@export var collapse_momentum_retention: float = 0.18
@export var collapse_inward_force: float = 620.0
@export var collapse_damage: float = 18.0

@export_group("Relativistic Rail")
@export var relativistic_impact_radius: float = 320.0
@export var relativistic_impact_force: float = 780.0
@export var relativistic_impact_damage: float = 20.0
@export var relativistic_time_slow: float = 0.62

@export_group("Orbital Debris Seeder")
@export var debris_seed_interval: float = 3.4
@export var debris_seed_radius: float = 132.0
@export var debris_seed_mass: float = 68000.0
@export var debris_seed_lifetime: float = 8.0
@export var debris_orbit_speed: float = 1.45
@export var max_seeded_debris: int = 10

@export_group("Orbital Memory")
@export var memory_sample_interval: float = 0.08
@export var memory_min_distance: float = 54.0
@export var memory_max_points: int = 96
@export var memory_influence_radius: float = 120.0
@export var memory_curve_strength: float = 180.0
@export var memory_visual_alpha: float = 0.36

@export_group("Localized Time Debt")
@export var time_debt_radius: float = 320.0
@export var time_debt_duration: float = 3.2
@export var time_debt_slow_scale: float = 0.54
@export var time_debt_repay_scale: float = 1.28
@export var max_time_debt_zones: int = 4

@export_group("Momentum Conservation Drift")
@export var momentum_drift_min_speed: float = 1050.0
@export var momentum_drift_force: float = 210.0
@export var momentum_drift_mutation_degrees: float = 18.0
@export var momentum_drift_cooldown: float = 0.2

@export_group("Resonance Cascades")
@export var cascade_sample_interval: float = 0.22
@export var cascade_charge_threshold: float = 1.8
@export var cascade_charge_decay: float = 0.7
@export var cascade_radius: float = 520.0
@export var cascade_force: float = 620.0
@export var cascade_damage: float = 16.0

var _player: CharacterBody2D = null
var _inventory: Node = null
var _momentum_component: Node = null
var _weapon_system: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _time_manager: Node = null

var _resolve_elapsed := 999.0
var _field_elapsed := 999.0
var _memory_elapsed := 999.0
var _debris_elapsed := 0.0
var _cascade_elapsed := 999.0
var _local_time := 0.0
var _last_momentum_drift_time := -999.0
var _dilation_start_position := Vector2.ZERO

var _micro_lenses: Array[Dictionary] = []
var _time_debt_zones: Array[Dictionary] = []
var _orbital_memory_points: Array[Vector2] = []
var _debris_orbits: Dictionary = {}
var _gravity_sources: Array[Node2D] = []
var _cascade_charge: Dictionary = {}
var _lens_visual_pool: Array[Line2D] = []
var _transient_ring_pool: Array[Line2D] = []
var _query_targets: Array[Node2D] = []
var _memory_line: Line2D = null
var _memory_line_points := PackedVector2Array()
var _memory_points_dirty: bool = true
var _nearest_memory_distance: float = INF
var _nearest_memory_tangent: Vector2 = Vector2.RIGHT
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("vector_anomaly_director")
	_rng.randomize()
	set_process(true)
	set_physics_process(true)
	call_deferred("_resolve_systems")


func _process(delta: float) -> void:
	if not enabled:
		return

	_local_time += delta
	_resolve_elapsed += delta
	_memory_elapsed += delta
	_debris_elapsed += delta
	_cascade_elapsed += delta

	if _resolve_elapsed >= system_resolve_interval:
		_resolve_elapsed = 0.0
		_resolve_systems()
		_refresh_gravity_sources()

	_update_lens_lifetimes(delta)
	_update_orbital_memory(delta)
	_update_time_debt_lifetimes(delta)
	_update_debris_orbits(delta)
	_try_seed_orbital_debris()

	if _cascade_elapsed >= cascade_sample_interval:
		var sample_delta := _cascade_elapsed
		_cascade_elapsed = 0.0
		_update_resonance_cascades(sample_delta)

	_sync_memory_visual()


func _physics_process(delta: float) -> void:
	if not enabled:
		return

	_field_elapsed += delta
	if _field_elapsed < field_tick_interval:
		return

	var field_delta := _field_elapsed
	_field_elapsed = 0.0
	_apply_micro_lens_fields(field_delta)
	_apply_orbital_memory_fields(field_delta)
	_apply_time_debt_fields(field_delta)


func trigger_vacuum_collapse(position: Vector2, stacks: int, source: Node = null, hit_body: Node = null) -> void:
	var radius := collapse_radius * (1.0 + 0.12 * float(maxi(stacks - 1, 0)))
	var affected := 0
	var center := position
	var targets := _collect_targets(center, radius, max_targets_per_tick, false)
	for target in targets:
		var target_2d := target as Node2D
		if target_2d == null:
			continue
		var offset := center - target_2d.global_position
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
		var current_velocity := _body_velocity(target_2d)
		_set_body_velocity(target_2d, current_velocity * collapse_momentum_retention)
		_add_velocity(target_2d, offset / distance * collapse_inward_force * falloff)
		if target_2d.has_method("take_damage") and _is_hostile(target_2d):
			target_2d.call("take_damage", collapse_damage * falloff * (1.0 + 0.18 * float(stacks - 1)))
		affected += 1

	_stamp_resonance(center, radius * 0.72, GravityResonanceManager.ZoneType.COMPRESSION, 0.74, 1.6)
	_stamp_scar(center, radius * 0.82, GravityScarManager.ScarType.TEMPORAL_RIP, 0.66, 36.0, &"vacuum_collapse")
	_spawn_transient_ring(center, radius, Color(0.72, 0.36, 1.0, 0.58), 0.28, 3.4)

	var payload := {
		"position": center,
		"radius": radius,
		"stacks": stacks,
		"affected": affected,
		"source": source,
		"hit_body": hit_body,
	}
	vacuum_collapse_triggered.emit(payload)


func trigger_relativistic_impact(position: Vector2, velocity: Vector2, stacks: int, source: Node = null, hit_body: Node = null) -> void:
	var speed := velocity.length()
	if speed < 900.0:
		return

	var direction := velocity.normalized() if speed > 0.001 else Vector2.RIGHT
	var intensity := clampf(speed / 2600.0, 0.2, 1.0)
	var radius := relativistic_impact_radius * (0.8 + intensity * 0.42 + 0.08 * float(stacks - 1))
	var affected := 0
	for target in _collect_targets(position, radius, max_targets_per_tick, false):
		var target_2d := target as Node2D
		if target_2d == null:
			continue
		var offset := target_2d.global_position - position
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
		var warp_dir := (direction * 0.68 + offset.normalized() * 0.32).normalized()
		_add_velocity(target_2d, warp_dir * relativistic_impact_force * intensity * falloff)
		if not target_2d.is_in_group("Player"):
			CombatStatusApi.apply_local_time_scale(target_2d, relativistic_time_slow, 0.28 + intensity * 0.18)
		if target_2d.has_method("take_damage") and _is_hostile(target_2d):
			target_2d.call("take_damage", relativistic_impact_damage * intensity * falloff)
		affected += 1

	_stamp_resonance(position + direction * radius * 0.18, radius * 0.74, GravityResonanceManager.ZoneType.SLIPSTREAM, 0.62 + intensity * 0.22, 1.3)
	_stamp_scar(position, radius * 0.78, GravityScarManager.ScarType.VELOCITY_SHEAR, 0.52 + intensity * 0.28, 32.0, &"relativistic_rail")
	_spawn_transient_ring(position, radius, Color(0.42, 0.9, 1.0, 0.6), 0.22, 3.0)

	var payload := {
		"position": position,
		"velocity": velocity,
		"speed": speed,
		"radius": radius,
		"stacks": stacks,
		"affected": affected,
		"source": source,
		"hit_body": hit_body,
	}
	relativistic_impact_triggered.emit(payload)


func record_chronal_refraction(position: Vector2, direction: Vector2, intensity: float, radius: float) -> void:
	var clamped_intensity := clampf(intensity, 0.05, 1.0)
	_create_time_debt_zone(
		position - direction.normalized() * radius * 0.35,
		position + direction.normalized() * radius * 0.55,
		maxf(radius, time_debt_radius * 0.5),
		time_debt_duration * lerpf(0.7, 1.2, clamped_intensity),
		clamped_intensity,
		&"chronal_refraction"
	)
	_stamp_resonance(position, radius * 0.72, GravityResonanceManager.ZoneType.TEMPORAL_SCAR, 0.48 + clamped_intensity * 0.28, 1.1)


func activate_upgrade_pulse(powerup_id: StringName, position: Vector2, stacks: int) -> void:
	match powerup_id:
		&"micro_lensing_emitter":
			_create_micro_lens(position, Vector2.ZERO, stacks, powerup_id)
		&"vacuum_collapse_injector":
			trigger_vacuum_collapse(position, stacks, self, null)
		&"relativistic_rail":
			trigger_relativistic_impact(position, Vector2.RIGHT.rotated(_local_time) * 1450.0, stacks, self, null)
		&"orbital_debris_seeder":
			_seed_debris_near(position, stacks, powerup_id)
		&"chronal_refraction_beam":
			record_chronal_refraction(position, Vector2.RIGHT.rotated(_local_time), 0.55 + 0.08 * float(stacks - 1), time_debt_radius)


func _resolve_systems() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
		_connect_player_signals()

	if _player != null and is_instance_valid(_player):
		_inventory = _player.get_node_or_null("PowerupInventory")
		_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
		_weapon_system = _player.get_node_or_null("WeaponSystem")
		_connect_momentum_signals()

	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)

	if _scar_manager == null or not is_instance_valid(_scar_manager):
		_scar_manager = root.find_child("GravityScarManager", true, false)

	if _time_manager == null or not is_instance_valid(_time_manager):
		_time_manager = root.find_child("TimeDilationManager", true, false)
		_connect_time_signals()


func _connect_player_signals() -> void:
	if _player == null:
		return
	_connect_once(_player, &"momentum_projectile_spawned", Callable(self, "_on_player_projectile_spawned"))
	_connect_once(_player, &"slingshot_mastery_scored", Callable(self, "_on_player_slingshot_mastery"))


func _connect_momentum_signals() -> void:
	if _momentum_component == null:
		return
	_connect_once(_momentum_component, &"kinetic_impact_dealt", Callable(self, "_on_kinetic_impact_dealt"))


func _connect_time_signals() -> void:
	if _time_manager == null:
		return
	_connect_once(_time_manager, &"dilation_started", Callable(self, "_on_dilation_started"))
	_connect_once(_time_manager, &"dilation_ended", Callable(self, "_on_dilation_ended"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_player_projectile_spawned(projectile: Node, direction: Vector2) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return

	var micro_stacks := _stack_count(&"micro_lensing_emitter")
	if micro_stacks > 0:
		var velocity := direction.normalized() * micro_lens_drift_speed
		if _player != null and is_instance_valid(_player):
			velocity += _player.velocity * 0.08
		_create_micro_lens(projectile.global_position + direction.normalized() * micro_lens_forward_offset, velocity, micro_stacks, &"projectile")

	var vacuum_stacks := _stack_count(&"vacuum_collapse_injector")
	if vacuum_stacks > 0:
		projectile.set_meta(&"vacuum_collapse_stacks", vacuum_stacks)

	var rail_stacks := _stack_count(&"relativistic_rail")
	if rail_stacks > 0:
		projectile.set_meta(&"relativistic_rail_stacks", rail_stacks)


func _on_player_slingshot_mastery(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var position: Vector2 = data.get("position", _player.global_position if _player != null else global_position)
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	tangent = tangent.normalized()

	if _stack_count(&"micro_lensing_emitter") > 0 and score >= 0.58:
		_create_micro_lens(position + tangent * micro_lens_forward_offset * 0.52, tangent * micro_lens_drift_speed * 0.5, _stack_count(&"micro_lensing_emitter"), &"slingshot")

	if _stack_count(&"orbital_debris_seeder") > 0 and score >= 0.72:
		_seed_debris_near(position, _stack_count(&"orbital_debris_seeder"), &"mastery_slingshot")

	if score >= 0.52:
		_apply_momentum_drift(tangent, score, &"slingshot_mastery")


func _on_kinetic_impact_dealt(target: Node, _damage: float, speed: float) -> void:
	if speed < momentum_drift_min_speed:
		return
	var target_2d := target as Node2D
	var direction := Vector2.RIGHT
	if _player != null and is_instance_valid(_player):
		direction = _player.velocity.normalized() if _player.velocity.length_squared() > 0.001 else Vector2.RIGHT
	if target_2d != null and is_instance_valid(target_2d) and _player != null:
		var radial := (target_2d.global_position - _player.global_position).normalized()
		if radial.length_squared() > 0.001:
			direction = (direction * 0.7 + radial * 0.3).normalized()
	_apply_momentum_drift(direction, clampf(speed / 2200.0, 0.0, 1.0), &"kinetic_impact")


func _on_dilation_started() -> void:
	if _player != null and is_instance_valid(_player):
		_dilation_start_position = _player.global_position


func _on_dilation_ended() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var velocity := _player.velocity
	var direction := velocity.normalized() if velocity.length_squared() > 0.001 else Vector2.RIGHT.rotated(_player.global_rotation)
	_create_time_debt_zone(
		_dilation_start_position,
		_player.global_position + direction * time_debt_radius * 0.85,
		time_debt_radius,
		time_debt_duration,
		clampf(velocity.length() / 1800.0, 0.28, 1.0),
		&"player_dilation"
	)


func _create_micro_lens(position: Vector2, velocity: Vector2, stacks: int, source_label: StringName) -> void:
	if _micro_lenses.size() >= max_active_micro_lenses:
		_release_lens_visual(_micro_lenses[0])
		_micro_lenses.remove_at(0)

	var radius := micro_lens_radius * (1.0 + 0.1 * float(stacks - 1))
	var lens := {
		"position": position,
		"velocity": velocity,
		"radius": radius,
		"strength": micro_lens_strength * (1.0 + 0.16 * float(stacks - 1)),
		"duration": micro_lens_duration,
		"age": 0.0,
		"source": source_label,
		"visual": _acquire_lens_visual(),
	}
	_micro_lenses.append(lens)
	micro_lens_created.emit(lens.duplicate(true))


func _update_lens_lifetimes(delta: float) -> void:
	for idx in range(_micro_lenses.size() - 1, -1, -1):
		var lens := _micro_lenses[idx]
		lens["age"] = float(lens.get("age", 0.0)) + delta
		lens["position"] = Vector2(lens.get("position", Vector2.ZERO)) + Vector2(lens.get("velocity", Vector2.ZERO)) * delta
		if float(lens["age"]) >= float(lens.get("duration", 1.0)):
			_release_lens_visual(lens)
			_micro_lenses.remove_at(idx)
			continue
		_update_lens_visual(lens, delta)
		_micro_lenses[idx] = lens


func _apply_micro_lens_fields(delta: float) -> void:
	if _micro_lenses.is_empty():
		return

	var affected_total := 0
	for lens in _micro_lenses:
		if affected_total >= max_targets_per_tick:
			return
		var center: Vector2 = lens.get("position", Vector2.ZERO)
		var radius := float(lens.get("radius", micro_lens_radius))
		var strength := float(lens.get("strength", micro_lens_strength))
		var radius_squared := radius * radius
		for target in _collect_targets(center, radius, max_targets_per_tick - affected_total, false):
			var body := target as Node2D
			if body == null:
				continue
			var offset := body.global_position - center
			var distance_squared := offset.length_squared()
			if distance_squared <= 0.001 or distance_squared > radius_squared:
				continue
			var distance := sqrt(distance_squared)
			var radial := offset / distance
			var tangent := radial.orthogonal()
			var body_velocity := _body_velocity(body)
			if body_velocity.length_squared() > 0.001 and tangent.dot(body_velocity) < 0.0:
				tangent = -tangent
			var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
			var curve := (tangent * 0.76 - radial * 0.24).normalized()
			_add_velocity(body, curve * strength * falloff * delta)
			body.set_meta(&"micro_lens_pressure", falloff)
			affected_total += 1


func _update_orbital_memory(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _memory_elapsed < memory_sample_interval:
		return
	_memory_elapsed = 0.0

	if _orbital_memory_points.is_empty():
		_orbital_memory_points.append(_player.global_position)
		_memory_points_dirty = true
		return

	if _orbital_memory_points[_orbital_memory_points.size() - 1].distance_to(_player.global_position) < memory_min_distance:
		return

	_orbital_memory_points.append(_player.global_position)
	_memory_points_dirty = true
	while _orbital_memory_points.size() > memory_max_points:
		_orbital_memory_points.remove_at(0)
		_memory_points_dirty = true

	orbital_memory_recorded.emit({
		"position": _player.global_position,
		"points": _orbital_memory_points.size(),
		"speed": _player.velocity.length(),
		"delta": delta,
	})


func _apply_orbital_memory_fields(delta: float) -> void:
	if _orbital_memory_points.size() < 3:
		return

	var affected := 0
	for target in _collect_targets(_player.global_position if _player != null else global_position, 2400.0, max_targets_per_tick, false):
		if affected >= max_targets_per_tick:
			return
		var body := target as Node2D
		if body == null or body.is_in_group("Player"):
			continue
		if not _find_nearest_memory_segment(body.global_position):
			continue
		if _nearest_memory_distance > memory_influence_radius:
			continue
		var falloff := 1.0 - clampf(_nearest_memory_distance / memory_influence_radius, 0.0, 1.0)
		_add_velocity(body, _nearest_memory_tangent * memory_curve_strength * falloff * delta)
		body.set_meta(&"orbital_memory_pressure", falloff)
		affected += 1


func _find_nearest_memory_segment(position: Vector2) -> bool:
	_nearest_memory_distance = INF
	_nearest_memory_tangent = Vector2.RIGHT
	for idx in range(1, _orbital_memory_points.size()):
		var a := _orbital_memory_points[idx - 1]
		var b := _orbital_memory_points[idx]
		var segment := b - a
		if segment.length_squared() <= 1.0:
			continue
		var t := clampf((position - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var closest := a + segment * t
		var distance := position.distance_to(closest)
		if distance >= _nearest_memory_distance:
			continue
		_nearest_memory_distance = distance
		_nearest_memory_tangent = segment.normalized()
	return _nearest_memory_distance < INF


func _create_time_debt_zone(slow_position: Vector2, repay_position: Vector2, radius: float, duration: float, intensity: float, source_label: StringName) -> void:
	if _time_debt_zones.size() >= max_time_debt_zones:
		_time_debt_zones.remove_at(0)

	var zone := {
		"slow_position": slow_position,
		"repay_position": repay_position,
		"radius": radius,
		"duration": duration,
		"remaining": duration,
		"intensity": clampf(intensity, 0.05, 1.0),
		"source": source_label,
	}
	_time_debt_zones.append(zone)
	_spawn_transient_ring(slow_position, radius, Color(0.72, 0.36, 1.0, 0.34), 0.24, 2.2)
	_spawn_transient_ring(repay_position, radius, Color(0.16, 0.92, 1.0, 0.34), 0.24, 2.2)
	time_debt_zone_created.emit(zone.duplicate(true))


func _update_time_debt_lifetimes(delta: float) -> void:
	for idx in range(_time_debt_zones.size() - 1, -1, -1):
		var zone := _time_debt_zones[idx]
		zone["remaining"] = float(zone.get("remaining", 0.0)) - delta
		if float(zone["remaining"]) <= 0.0:
			_time_debt_zones.remove_at(idx)
		else:
			_time_debt_zones[idx] = zone


func _apply_time_debt_fields(delta: float) -> void:
	if _time_debt_zones.is_empty():
		return

	var affected := 0
	for zone in _time_debt_zones:
		if affected >= max_targets_per_tick:
			return
		var slow_position: Vector2 = zone.get("slow_position", Vector2.ZERO)
		var repay_position: Vector2 = zone.get("repay_position", Vector2.ZERO)
		var radius := float(zone.get("radius", time_debt_radius))
		var intensity := clampf(float(zone.get("intensity", 0.4)), 0.0, 1.0)
		var slow_scale := lerpf(1.0, time_debt_slow_scale, intensity)
		var repay_scale := lerpf(1.0, time_debt_repay_scale, intensity)
		for target in _collect_targets((slow_position + repay_position) * 0.5, radius * 2.7, max_targets_per_tick - affected, true):
			var body := target as Node2D
			if body == null:
				continue
			var slow_distance := body.global_position.distance_to(slow_position)
			var repay_distance := body.global_position.distance_to(repay_position)
			if slow_distance <= radius:
				CombatStatusApi.apply_local_time_scale(body, slow_scale, field_tick_interval * 2.4)
				affected += 1
			elif repay_distance <= radius:
				CombatStatusApi.apply_local_time_scale(body, repay_scale, field_tick_interval * 2.4)
				var velocity := _body_velocity(body)
				if velocity.length_squared() > 1.0:
					_add_velocity(body, velocity.normalized() * 80.0 * intensity * delta)
				affected += 1


func _try_seed_orbital_debris() -> void:
	var stacks := _stack_count(&"orbital_debris_seeder")
	if stacks <= 0:
		return
	if _debris_elapsed < maxf(debris_seed_interval / float(maxi(stacks, 1)), 0.65):
		return
	_debris_elapsed = 0.0
	_seed_debris_near(_player.global_position if _player != null else global_position, stacks, &"orbital_debris_seeder")


func _seed_debris_near(position: Vector2, stacks: int, source_label: StringName) -> void:
	if _count_valid_seeded_debris() >= max_seeded_debris:
		return

	var anchor := _nearest_gravity_source(position)
	if anchor == null:
		return

	var angle := _rng.randf() * TAU
	var orbit_radius := maxf(debris_seed_radius + _rng.randf_range(-24.0, 48.0), 56.0)
	var debris := GravityDebrisScript.new()
	debris.name = "OrbitalSeededDebris"
	debris.configure(
		debris_seed_mass * (1.0 + 0.12 * float(stacks - 1)),
		52.0 + 8.0 * float(stacks - 1),
		debris_seed_lifetime * (1.0 + 0.08 * float(stacks - 1)),
		Color(0.28, 0.86, 1.0, 1.0)
	)
	debris.global_position = anchor.global_position + Vector2.RIGHT.rotated(angle) * orbit_radius
	get_tree().current_scene.add_child(debris)
	_debris_orbits[debris.get_instance_id()] = {
		"debris": debris,
		"anchor_id": anchor.get_instance_id(),
		"angle": angle,
		"radius": orbit_radius,
		"speed": debris_orbit_speed * (1.0 + 0.08 * float(stacks - 1)) * (1.0 if _rng.randf() > 0.5 else -1.0),
		"source": source_label,
	}
	orbital_debris_seeded.emit(debris, _debris_orbits[debris.get_instance_id()].duplicate(true))


func _update_debris_orbits(delta: float) -> void:
	if _debris_orbits.is_empty():
		return

	var erase_ids: Array[int] = []
	for id in _debris_orbits.keys():
		var orbit: Dictionary = _debris_orbits[id]
		var debris : Node2D
		if is_instance_valid(orbit.get("debris")):
			debris = orbit.get("debris") 
		if debris == null or not is_instance_valid(debris) or debris.is_queued_for_deletion():
			erase_ids.append(id)
			continue
		var anchor_id := int(orbit.get("anchor_id", -1))
		if not is_instance_id_valid(anchor_id):
			erase_ids.append(id)
			continue
		var anchor := instance_from_id(anchor_id) as Node2D
		if anchor == null or not is_instance_valid(anchor):
			erase_ids.append(id)
			continue

		orbit["angle"] = float(orbit.get("angle", 0.0)) + float(orbit.get("speed", debris_orbit_speed)) * delta
		var radius := float(orbit.get("radius", debris_seed_radius))
		var offset := Vector2.RIGHT.rotated(float(orbit["angle"])) * radius
		debris.global_position = anchor.global_position + offset
		_debris_orbits[id] = orbit

	for id in erase_ids:
		_debris_orbits.erase(id)


func _update_resonance_cascades(delta: float) -> void:
	if _resonance_manager == null or not is_instance_valid(_resonance_manager) or not _resonance_manager.has_method("get_active_resonance_zones"):
		return

	var zones_value: Variant = _resonance_manager.call("get_active_resonance_zones")
	if typeof(zones_value) != TYPE_ARRAY:
		return
	var zones: Array = zones_value
	var buckets := {}
	for zone_value in zones:
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone: Dictionary = zone_value
		var intensity := clampf(float(zone.get("intensity", 0.0)), 0.0, 1.0)
		if intensity < 0.38:
			continue
		var type_name := StringName(zone.get("zone_type_name", &"compression"))
		if not buckets.has(type_name):
			buckets[type_name] = []
		buckets[type_name].append(zone)
		_tag_resonant_targets(zone, type_name, intensity)

	for key in _cascade_charge.keys():
		if not buckets.has(key):
			_cascade_charge[key] = maxf(float(_cascade_charge[key]) - cascade_charge_decay * delta, 0.0)

	for type_name in buckets.keys():
		var typed_zones: Array = buckets[type_name]
		var pressure := 0.0
		for zone in typed_zones:
			pressure += float(zone.get("intensity", 0.0))
		if typed_zones.size() >= 2:
			_cascade_charge[type_name] = float(_cascade_charge.get(type_name, 0.0)) + pressure * delta
		else:
			_cascade_charge[type_name] = maxf(float(_cascade_charge.get(type_name, 0.0)) - cascade_charge_decay * delta, 0.0)
		if float(_cascade_charge[type_name]) >= cascade_charge_threshold:
			_trigger_resonance_cascade(type_name, typed_zones, float(_cascade_charge[type_name]))
			_cascade_charge[type_name] = 0.0


func _tag_resonant_targets(zone: Dictionary, type_name: StringName, intensity: float) -> void:
	var center: Vector2 = zone.get("midpoint", Vector2.ZERO)
	var radius := float(zone.get("radius", cascade_radius * 0.5))
	for target in _collect_targets(center, radius, 16, false):
		target.set_meta(&"resonance_frequency", type_name)
		target.set_meta(&"resonance_frequency_intensity", intensity)


func _trigger_resonance_cascade(type_name: StringName, zones: Array, charge: float) -> void:
	var center := Vector2.ZERO
	var count := 0
	var radius := cascade_radius
	for zone in zones:
		if typeof(zone) != TYPE_DICTIONARY:
			continue
		center += zone.get("midpoint", Vector2.ZERO)
		radius = maxf(radius, float(zone.get("radius", cascade_radius)) * 1.4)
		count += 1
	if count <= 0:
		return
	center /= float(count)

	var affected := 0
	for target in _collect_targets(center, radius, max_targets_per_tick, false):
		var body := target as Node2D
		if body == null:
			continue
		var offset := body.global_position - center
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
		var radial := offset / distance
		var tangent := radial.orthogonal()
		_add_velocity(body, (tangent * 0.55 + radial * 0.45).normalized() * cascade_force * falloff)
		if body.has_method("take_damage") and _is_hostile(body):
			body.call("take_damage", cascade_damage * falloff)
		affected += 1

	var zone_type := _zone_type_from_name(type_name)
	_stamp_resonance(center, radius * 0.52, zone_type, 0.86, 1.8)
	_stamp_scar(center, radius * 0.46, GravityScarManager.ScarType.HARMONIC_FRACTURE, 0.72, 48.0, &"resonance_cascade")
	_spawn_transient_ring(center, radius, _cascade_color(type_name), 0.32, 3.6)

	resonance_cascade_triggered.emit({
		"position": center,
		"radius": radius,
		"type_name": type_name,
		"charge": charge,
		"zone_count": count,
		"affected": affected,
	})


func _apply_momentum_drift(direction: Vector2, intensity: float, source_label: StringName) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_momentum_drift_time < momentum_drift_cooldown:
		return
	_last_momentum_drift_time = now

	var speed := _player.velocity.length()
	if speed < momentum_drift_min_speed * 0.72:
		return

	var mutation := deg_to_rad(momentum_drift_mutation_degrees) * sin(speed * 0.013 + now * 3.1)
	var drift := direction.normalized().rotated(mutation) * momentum_drift_force * clampf(intensity, 0.1, 1.0)
	_player.velocity = (_player.velocity + drift).limit_length(float(_player.get("absolute_velocity_cap")) if _player.get("absolute_velocity_cap") != null else speed + drift.length())
	_spawn_transient_ring(_player.global_position, 86.0 + intensity * 84.0, Color(0.38, 1.0, 0.84, 0.36), 0.18, 2.4)
	_player.set_meta(&"momentum_conservation_drift", source_label)


func _collect_targets(center: Vector2, radius: float, limit: int, include_player: bool) -> Array[Node2D]:
	_query_targets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(
			PLAYER_TARGET_GROUPS if include_player else TARGET_GROUPS,
			center,
			radius,
			limit,
			include_player,
			_query_targets
		)
		return _query_targets

	var radius_squared := radius * radius
	var seen := {}
	var groups: Array[StringName] = [&"Projectiles", &"player_projectiles", &"enemy_projectiles", &"enemies", &"wave_enemy", &"bosses", &"law_gravity_debris"]
	if include_player:
		groups.append(&"Player")

	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if _query_targets.size() >= limit:
				return _query_targets
			var body := node as Node2D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			if not include_player and body.is_in_group("Player"):
				continue
			var id := body.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if body.global_position.distance_squared_to(center) > radius_squared:
				continue
			_query_targets.append(body)
	return _query_targets


func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_player.global_position if _player != null and is_instance_valid(_player) else global_position,
			_gravity_sources,
			14,
			0.0,
			_player
		)
		return

	var seen := {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var source := node as Node2D
			if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
				continue
			var id := source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source)

	if _player != null and is_instance_valid(_player):
		_gravity_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			if not is_instance_valid(a) or not is_instance_valid(b):
				return false
			return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
		)
	if _gravity_sources.size() > 14:
		_gravity_sources.resize(14)


func _nearest_gravity_source(position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion() or source == _player:
			continue
		var distance := source.global_position.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best = source
	return best


func _count_valid_seeded_debris() -> int:
	var count := 0
	var erase_ids: Array[int] = []
	for id in _debris_orbits.keys():
		var debris := (_debris_orbits[id] as Dictionary).get("debris") as Node
		if debris != null and is_instance_valid(debris) and not debris.is_queued_for_deletion():
			count += 1
		else:
			erase_ids.append(id)
	for id in erase_ids:
		_debris_orbits.erase(id)
	return count


func _body_velocity(body: Node) -> Vector2:
	if body == null or not is_instance_valid(body):
		return Vector2.ZERO
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	return Vector2.ZERO


func _set_body_velocity(body: Node, velocity_value: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.get("velocity") is Vector2:
		body.set("velocity", velocity_value)
	elif body.get("linear_velocity") is Vector2:
		body.set("linear_velocity", velocity_value)


func _add_velocity(body: Node, impulse: Vector2) -> void:
	if body == null or not is_instance_valid(body) or impulse.length_squared() <= 0.001:
		return
	if body.has_method("apply_fusion_impulse"):
		body.call("apply_fusion_impulse", impulse)
	else:
		CombatStatusApi.add_velocity(body, impulse)


func _stack_count(powerup_id: StringName) -> int:
	if _inventory == null or not is_instance_valid(_inventory) or not _inventory.has_method("get_stack_count"):
		return 0
	return int(_inventory.call("get_stack_count", powerup_id))


func _is_hostile(node: Node) -> bool:
	return node.is_in_group("enemies") or node.is_in_group("wave_enemy") or node.is_in_group("bosses")


func _stamp_resonance(position: Vector2, radius: float, zone_type: int, intensity: float, duration: float) -> void:
	if _resonance_manager != null and is_instance_valid(_resonance_manager) and _resonance_manager.has_method("create_manual_resonance_zone"):
		_resonance_manager.call("create_manual_resonance_zone", position, radius, zone_type, intensity, duration)


func _stamp_scar(position: Vector2, radius: float, scar_type: int, intensity: float, duration: float, source_label: StringName) -> void:
	if _scar_manager != null and is_instance_valid(_scar_manager) and _scar_manager.has_method("create_gravity_scar"):
		_scar_manager.call("create_gravity_scar", position, radius, scar_type, intensity, duration, source_label)


func _zone_type_from_name(type_name: StringName) -> int:
	match type_name:
		&"slipstream":
			return GravityResonanceManager.ZoneType.SLIPSTREAM
		&"inversion":
			return GravityResonanceManager.ZoneType.INVERSION
		&"temporal_scar":
			return GravityResonanceManager.ZoneType.TEMPORAL_SCAR
		&"harmonic_orbit":
			return GravityResonanceManager.ZoneType.HARMONIC_ORBIT
	return GravityResonanceManager.ZoneType.COMPRESSION


func _cascade_color(type_name: StringName) -> Color:
	match type_name:
		&"slipstream":
			return Color(0.08, 1.0, 0.78, 0.58)
		&"inversion":
			return Color(1.0, 0.28, 0.16, 0.62)
		&"temporal_scar":
			return Color(0.74, 0.32, 1.0, 0.6)
		&"harmonic_orbit":
			return Color(0.96, 0.82, 0.22, 0.58)
	return Color(0.26, 0.72, 1.0, 0.58)


func _acquire_lens_visual() -> Line2D:
	for visual in _lens_visual_pool:
		if visual != null and is_instance_valid(visual) and not visual.visible:
			visual.visible = true
			return visual

	var ring := Line2D.new()
	ring.name = "MicroLensRing"
	ring.closed = true
	ring.antialiased = true
	ring.width = 2.4
	ring.z_index = 22
	ring.top_level = true
	ring.points = _circle_points(48, 1.0)
	add_child(ring)
	_lens_visual_pool.append(ring)
	return ring


func _release_lens_visual(lens: Dictionary) -> void:
	var visual := lens.get("visual") as Line2D
	if visual != null and is_instance_valid(visual):
		visual.visible = false


func _update_lens_visual(lens: Dictionary, delta: float) -> void:
	var visual := lens.get("visual") as Line2D
	if visual == null or not is_instance_valid(visual):
		return
	var age := float(lens.get("age", 0.0))
	var duration := maxf(float(lens.get("duration", 1.0)), 0.001)
	var life := 1.0 - clampf(age / duration, 0.0, 1.0)
	var radius := float(lens.get("radius", micro_lens_radius))
	visual.global_position = lens.get("position", Vector2.ZERO)
	visual.rotation += delta * 2.2
	visual.scale = Vector2.ONE * radius
	visual.width = lerpf(1.2, 3.2, life)
	visual.default_color = Color(0.24, 0.92, 1.0, 0.52 * life)
	visual.visible = true


func _sync_memory_visual() -> void:
	if _orbital_memory_points.size() < 2:
		if _memory_line != null:
			_memory_line.visible = false
		return
	if _memory_line == null:
		_memory_line = Line2D.new()
		_memory_line.name = "OrbitalMemoryTrace"
		_memory_line.antialiased = true
		_memory_line.width = 2.0
		_memory_line.z_index = -2
		_memory_line.top_level = true
		add_child(_memory_line)
	if _memory_points_dirty:
		_memory_line_points.clear()
		for point in _orbital_memory_points:
			_memory_line_points.append(point)
		_memory_line.points = _memory_line_points
		_memory_points_dirty = false
	_memory_line.default_color = Color(0.32, 0.78, 1.0, memory_visual_alpha)
	_memory_line.visible = true


func _spawn_transient_ring(center: Vector2, radius: float, color: Color, duration: float, width: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var ring := _acquire_transient_ring(root)
	ring.closed = true
	ring.antialiased = true
	ring.width = width
	ring.default_color = color
	ring.global_position = center
	ring.scale = Vector2.ONE * 12.0
	ring.modulate.a = 1.0
	ring.z_index = 30
	ring.visible = true
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * maxf(radius, 16.0), duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(self, "_release_transient_ring").bind(ring))


func _acquire_transient_ring(root: Node) -> Line2D:
	for ring in _transient_ring_pool:
		if ring != null and is_instance_valid(ring) and not ring.visible:
			if ring.get_parent() != root:
				ring.reparent(root)
			return ring

	var ring := Line2D.new()
	ring.name = "VectorAnomalyTransientRing"
	ring.closed = true
	ring.antialiased = true
	ring.top_level = true
	ring.points = _circle_points(56, 1.0)
	root.add_child(ring)
	_transient_ring_pool.append(ring)
	return ring


func _release_transient_ring(ring: Line2D) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	ring.visible = false
	ring.modulate.a = 1.0


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
