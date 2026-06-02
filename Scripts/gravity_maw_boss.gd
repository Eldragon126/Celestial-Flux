extends PhaseBoss
class_name GravityMawBoss

## Hidden boss that consumes nearby gravity sources instead of only firing shots.
## The scene keeps the hull/rings/particles editable; this script drives rules.

const PULL_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"Projectiles", &"enemy_projectiles"]
const PULL_TARGET_LIMIT := 36

@export var display_name: String = "GRAVITY MAW"
@export var orbit_distance: float = 620.0
@export var move_speed: float = 380.0
@export var absorb_radius: float = 720.0
@export var pull_radius: float = 860.0
@export var pull_force: float = 760.0
@export var absorb_tick_interval: float = 0.18
@export var max_sources_per_tick: int = 8
@export var planet_damage_per_second: float = 34.0
@export var debris_lifetime_loss_per_second: float = 1.2
@export var mass_gain_scale: float = 0.026
@export var max_consumed_mass_bonus: float = 430000.0
@export var scar_stamp_interval: float = 1.15

var _orbit_angle := 0.0
var _absorb_elapsed := 0.0
var _consume_charge := 0.0
var _consumed_mass := 0.0
var _last_scar_time := -999.0
var _hull: Polygon2D = null
var _core: Polygon2D = null
var _rings: Array[Line2D] = []
var _particles: GPUParticles2D = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _pull_targets: Array[Node2D] = []
var _gravity_sources: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}


func _ready() -> void:
	max_health = maxf(max_health, 1450.0)
	mass = 470000.0
	attack_interval = 2.55
	_build_editable_body()
	super._ready()


func _boss_physics(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_update_motion(delta)
	_update_absorption(delta)
	_update_visuals(delta)


func _run_attack_pattern() -> void:
	if player == null or not is_instance_valid(player):
		return
	_consume_charge = 1.0
	_spawn_consumption_zone()
	_stamp_gravity_scar(global_position, absorb_radius * 0.62, GravityScarManager.ScarType.INVERSION_WAKE, 0.74)


func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.25, attack_interval - 0.32 * float(phase - 1))
	if _core != null:
		_core.color = _phase_color(phase)


func _update_motion(delta: float) -> void:
	_orbit_angle += delta * (0.24 + 0.08 * float(current_phase))
	var source_pos := _nearest_gravity_source_position()
	var anchor := player.global_position.lerp(source_pos, 0.45) if source_pos != Vector2.ZERO else player.global_position
	var target := anchor + Vector2.from_angle(_orbit_angle) * orbit_distance
	var desired := (target - global_position).limit_length(move_speed)
	velocity = velocity.lerp(desired, clampf(delta * 1.8, 0.0, 1.0))
	move_and_slide()


func _update_absorption(delta: float) -> void:
	_consume_charge = maxf(_consume_charge - delta * 0.34, 0.0)
	_absorb_elapsed += delta
	if _absorb_elapsed < maxf(absorb_tick_interval, 0.03):
		return
	var tick_delta := _absorb_elapsed
	_absorb_elapsed = 0.0
	_pull_nearby_bodies(tick_delta)
	_absorb_gravity_sources(tick_delta)


func _pull_nearby_bodies(delta: float) -> void:
	var affected := 0
	_fill_targets_in_radius(PULL_TARGET_GROUPS, global_position, pull_radius, PULL_TARGET_LIMIT, true, _pull_targets)
	for target_2d in _pull_targets:
		if affected >= PULL_TARGET_LIMIT:
			return
		if target_2d == self or not is_instance_valid(target_2d) or target_2d.is_queued_for_deletion():
			continue
		var offset := global_position - target_2d.global_position
		var distance_squared := offset.length_squared()
		if distance_squared <= 1.0:
			continue
		var falloff := 1.0 - sqrt(distance_squared) / pull_radius
		var multiplier := 0.35 if target_2d == player else 1.0
		CombatStatus.add_velocity(target_2d, offset.normalized() * pull_force * falloff * multiplier * delta)
		affected += 1


func _absorb_gravity_sources(delta: float) -> void:
	var consumed_this_tick := 0.0
	var affected := 0
	_fill_absorbable_sources()
	for source_2d in _gravity_sources:
		if affected >= max_sources_per_tick:
			break
		if not _can_absorb_source(source_2d):
			continue
		var distance := source_2d.global_position.distance_to(global_position)
		if distance > absorb_radius:
			continue

		var source_mass := _source_mass(source_2d)
		var falloff := clampf(1.0 - distance / maxf(absorb_radius, 1.0), 0.12, 1.0)
		var charge_bonus := 1.0 + _consume_charge * 1.65
		var consumed := source_mass * mass_gain_scale * falloff * charge_bonus * delta
		_apply_source_consumption(source_2d, source_2d, falloff, charge_bonus, delta)
		_spawn_absorb_line(source_2d.global_position, falloff)
		consumed_this_tick += consumed
		affected += 1

	if consumed_this_tick <= 0.0:
		return

	_consumed_mass = minf(_consumed_mass + consumed_this_tick, max_consumed_mass_bonus)
	mass = 470000.0 + _consumed_mass
	if health != null:
		health.heal(consumed_this_tick * 0.0025)


func _apply_source_consumption(
	source: Node,
	source_2d: Node2D,
	falloff: float,
	charge_bonus: float,
	delta: float
) -> void:
	if source.has_method("apply_spacetime_damage"):
		source.call("apply_spacetime_damage", planet_damage_per_second * falloff * charge_bonus * delta, source_2d.global_position, &"gravity_maw")
		_stamp_gravity_scar(source_2d.global_position, 240.0, GravityScarManager.ScarType.CURVATURE, 0.44 * falloff)
		return

	if source.is_in_group("law_gravity_debris"):
		if source.get("lifetime") != null:
			source.set("lifetime", maxf(float(source.get("lifetime")) - debris_lifetime_loss_per_second * charge_bonus * delta, 0.12))
		if source.has_method("apply_fusion_impulse"):
			source.call("apply_fusion_impulse", (global_position - source_2d.global_position).normalized() * 260.0 * falloff, Color(0.88, 0.34, 1.0, 1.0))
		return

	if source.get("mass") != null:
		var current_mass := _source_mass(source)
		source.set("mass", maxf(current_mass * (1.0 - 0.08 * falloff * charge_bonus * delta), 1000.0))


func _spawn_consumption_zone() -> void:
	var resonance := _get_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	resonance.call(
		"create_manual_resonance_zone",
		global_position,
		absorb_radius * 0.54,
		GravityResonanceManager.ZoneType.COMPRESSION,
		0.78 + 0.06 * float(current_phase),
		2.4
	)


func _stamp_gravity_scar(position: Vector2, radius: float, scar_type: int, intensity: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_scar_time < scar_stamp_interval:
		return
	_last_scar_time = now
	var scars := _get_scar_manager()
	if scars == null or not scars.has_method("create_gravity_scar"):
		return
	scars.call("create_gravity_scar", position, radius, scar_type, intensity, 34.0, &"gravity_maw")


func _can_absorb_source(source: Node) -> bool:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return false
	if source == self or source == player:
		return false
	if source.is_in_group("bosses") or source.is_in_group("Player"):
		return false
	return source is Node2D


func _nearest_gravity_source_position() -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	_fill_nearest_gravity_sources(global_position, max_sources_per_tick, 0.0, _gravity_sources)
	for source in _gravity_sources:
		if not _can_absorb_source(source):
			continue
		var distance := source.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = source.global_position
	return best


func _fill_absorbable_sources() -> void:
	_fill_nearest_gravity_sources(global_position, max_sources_per_tick, absorb_radius, _gravity_sources)


func _fill_nearest_gravity_sources(position: Vector2, limit: int, radius: float, out_sources: Array[Node2D]) -> void:
	out_sources.clear()
	if limit == 0:
		return
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(position, out_sources, limit, radius, self)
		return

	var radius_squared := radius * radius
	var max_count := maxi(limit, 0)
	_query_seen_ids.clear()
	for source in get_tree().get_nodes_in_group("Objects_With_Gravity"):
		if not _can_absorb_source(source):
			continue
		var source_2d := source as Node2D
		if source_2d == null:
			continue
		var id := source_2d.get_instance_id()
		if _query_seen_ids.has(id):
			continue
		_query_seen_ids[id] = true
		if radius > 0.0 and source_2d.global_position.distance_squared_to(position) > radius_squared:
			continue
		out_sources.append(source_2d)
	out_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if not is_instance_valid(a) or not is_instance_valid(b):
			return false
		return a.global_position.distance_squared_to(position) < b.global_position.distance_squared_to(position)
	)
	if max_count > 0 and out_sources.size() > max_count:
		out_sources.resize(max_count)


func _fill_targets_in_radius(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	limit: int,
	include_player: bool,
	out_targets: Array[Node2D]
) -> void:
	out_targets.clear()
	if limit == 0:
		return
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, limit, include_player, out_targets)
		return

	var radius_squared := radius * radius
	var max_count := maxi(limit, 0)
	_query_seen_ids.clear()
	for group_name in groups:
		for target in get_tree().get_nodes_in_group(group_name):
			if max_count > 0 and out_targets.size() >= max_count:
				return
			if not is_instance_valid(target) or target.is_queued_for_deletion():
				continue
			var target_2d := target as Node2D
			if target_2d == null:
				continue
			if not include_player and target_2d.is_in_group("Player"):
				continue
			var id := target_2d.get_instance_id()
			if _query_seen_ids.has(id):
				continue
			_query_seen_ids[id] = true
			if target_2d.global_position.distance_squared_to(center) > radius_squared:
				continue
			out_targets.append(target_2d)


func _source_mass(source: Node) -> float:
	var value: Variant = source.get("mass")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return maxf(absf(float(value)), 1.0)
	return 100.0


func _spawn_absorb_line(source_position: Vector2, intensity: float) -> void:
	var line := Line2D.new()
	line.name = "GravityMawAbsorbLine"
	line.antialiased = true
	line.width = lerpf(1.0, 3.6, intensity)
	line.default_color = Color(0.86, 0.34, 1.0, minf(0.52, 0.18 + intensity * 0.34))
	line.points = PackedVector2Array([Vector2.ZERO, to_local(source_position)])
	line.z_index = 6
	add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)


func _build_editable_body() -> void:
	_hull = get_node_or_null("MawHull") as Polygon2D
	if _hull == null:
		_hull = Polygon2D.new()
		_hull.name = "MawHull"
		add_child(_hull)
	if _hull.polygon.is_empty():
		_hull.polygon = _soft_circle_points(14, 112.0)
	_hull.color = Color(0.08, 0.03, 0.13, 0.94)

	_core = get_node_or_null("MawCore") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "MawCore"
		add_child(_core)
	if _core.polygon.is_empty():
		_core.polygon = _soft_circle_points(9, 46.0)
	_core.color = _phase_color(1)

	_rings.clear()
	for child in get_children():
		if child is Line2D and String(child.name).begins_with("MawRing"):
			_rings.append(child as Line2D)
	if _rings.is_empty():
		for i in range(3):
			var ring := Line2D.new()
			ring.name = "MawRing%d" % i
			ring.closed = true
			ring.antialiased = true
			ring.width = 2.0
			add_child(ring)
			_rings.append(ring)

	_particles = get_node_or_null("MawParticles") as GPUParticles2D
	if _particles != null:
		_particles.emitting = true


func _update_visuals(delta: float) -> void:
	rotation += delta * (0.16 + _consume_charge * 0.34)
	for i in range(_rings.size()):
		var ring := _rings[i]
		if ring == null:
			continue
		var radius := 138.0 + float(i) * 54.0 + _consume_charge * 52.0
		ring.points = _circle_points(64, radius)
		ring.rotation -= delta * (0.38 + float(i) * 0.18 + _consume_charge * 0.8)
		ring.default_color = Color(0.82, 0.28, 1.0, 0.24 + _consume_charge * 0.18)
	if _core != null:
		var pulse := 1.0 + sin(Time.get_ticks_msec() / 120.0) * 0.05 + _consume_charge * 0.18
		_core.scale = Vector2.ONE * pulse


func _get_resonance_manager() -> Node:
	if _resonance_manager != null and is_instance_valid(_resonance_manager):
		return _resonance_manager
	var root := get_tree().current_scene
	_resonance_manager = root.find_child("GravityResonanceManager", true, false) if root != null else null
	return _resonance_manager


func _get_scar_manager() -> Node:
	if _scar_manager != null and is_instance_valid(_scar_manager):
		return _scar_manager
	var root := get_tree().current_scene
	_scar_manager = root.find_child("GravityScarManager", true, false) if root != null else null
	return _scar_manager


func _phase_color(phase: int) -> Color:
	return [Color(0.84, 0.34, 1.0, 1.0), Color(0.34, 0.9, 1.0, 1.0), Color(1.0, 0.28, 0.22, 1.0)][clampi(phase - 1, 0, 2)]


func _circle_points(count: int, point_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * point_radius)
	return points


func _soft_circle_points(count: int, point_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		var warp := 1.0 + sin(angle * 3.0) * 0.18 + cos(angle * 7.0) * 0.08
		points.append(Vector2(cos(angle), sin(angle)) * point_radius * warp)
	return points
