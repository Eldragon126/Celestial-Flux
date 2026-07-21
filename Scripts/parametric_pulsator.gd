extends CharacterBody2D
class_name ParametricPulsator

signal parametric_pulse_released(pulse_data: Dictionary)
signal gravity_bead_seeded(bead_data: Dictionary)
signal black_hole_mode_started(mode_data: Dictionary)

const MASS_POINT_SCENE := preload("res://Nodes/mass_point.tscn")
const PULSE_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses"]
const BEAD_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles"]
const BLACK_HOLE_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]

enum PulseMode {
	COMPRESSION,
	REPULSION
}

@export_group("Rare Enemy Identity")
@export var max_health: float = 640.0
@export var mass: float = 520000.0
@export var contact_damage: float = 34.0
@export var contact_knockback: float = 760.0

@export_group("Parametric Drift")
@export var equation_speed: float = 1.12
@export var orbit_scale: float = 310.0
@export var anchor_follow_speed: float = 3.4
@export var engine_thrust: float = 2550.0
@export var drag: float = 1.18
@export var max_speed: float = 860.0
@export var pursuit_bias: float = 0.22
@export var arrival_distance: float = 18.0
@export var player_velocity_lead: float = 0.16

@export_group("Parametric Pulse")
@export var pulse_cooldown: float = 3.25
@export var pulse_charge_time: float = 0.82
@export var pulse_radius: float = 430.0
@export var pulse_damage: float = 32.0
@export var pulse_impulse: float = 820.0
@export var pulse_time_slow: float = 0.74
@export var max_targets_per_pulse: int = 36

@export_group("Gravity Beads")
@export var bead_seed_cooldown: float = 5.2
@export var bead_count: int = 6
@export var max_active_beads: int = 14
@export var bead_lifetime: float = 1.72
@export var bead_orbit_radius: float = 260.0
@export var bead_gravity_mass: float = 260000.0
@export var bead_blast_radius: float = 150.0
@export var bead_damage: float = 16.0
@export var bead_impulse: float = 520.0

@export_group("Black Hole Mode")
@export_range(0.05, 0.5, 0.01) var black_hole_health_threshold: float = 0.22
@export var black_hole_mass_multiplier: float = 3.4
@export var black_hole_event_horizon_radius: float = 520.0
@export var black_hole_spaghettify_radius: float = 230.0
@export var black_hole_consume_radius: float = 48.0
@export var black_hole_pull_force: float = 1580.0
@export var black_hole_tangent_shear_force: float = 340.0
@export var black_hole_spaghettify_damage_per_second: float = 28.0
@export var black_hole_consume_damage: float = 72.0
@export var black_hole_enemy_consume_damage: float = 10000000.0
@export var black_hole_field_tick_interval: float = 0.045
@export var black_hole_max_targets_per_tick: int = 44
@export var black_hole_max_field_impulse_per_tick: float = 155.0
@export var black_hole_max_body_speed_after_pull: float = 2600.0
@export var black_hole_player_consume_cooldown: float = 0.78

@export_group("Dance Partner")
@export var dance_beats_per_loop: int = 8
@export var dance_window_width: float = 0.09
@export var dance_damage_multiplier: float = 1.72
@export var slingshot_jam_multiplier: float = 1.32
@export var skill_hit_energy_reward: float = 8.0

@export_group("Readable Visuals")
@export var calm_color: Color = Color(0.44, 0.92, 1.0, 1.0)
@export var charge_color: Color = Color(1.0, 0.86, 0.24, 1.0)
@export var rupture_color: Color = Color(1.0, 0.18, 0.42, 1.0)
@export var rare_core_color: Color = Color(0.72, 0.42, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var transient_alpha_cap: float = 0.42

var player: Node2D = null
var anchor_position: Vector2 = Vector2.ZERO
var desired_position: Vector2 = Vector2.ZERO
var phase_time: float = 0.0
var lifetime: float = 0.0
var _base_mass: float = 0.0

var _rng := RandomNumberGenerator.new()
var _health: HealthComponent = null
var _gravity_component: GravityComponent = null
var _phase: int = 0
var _health_ratio: float = 1.0
var _pulse_cooldown_remaining: float = 0.8
var _pulse_charge_elapsed: float = 0.0
var _pulse_mode: int = PulseMode.COMPRESSION
var _is_charging_pulse: bool = false
var _seed_cooldown_remaining: float = 1.4
var _hit_cooldown: float = 0.0
var _dance_window_active: bool = false
var _dance_window_intensity: float = 0.0
var _last_skill_reward_time: float = -999.0
var _active_beads: Array[Dictionary] = []
var _mass_point_pool: Array[Node2D] = []
var _target_buffer: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}
var _black_hole_mode_active: bool = false
var _black_hole_field_elapsed: float = 999.0
var _black_hole_visual_time: float = 0.0
var _black_hole_spaghettified_ids: Dictionary = {}
var _black_hole_damage_queue: Dictionary = {}
var _black_hole_consume_cooldowns: Dictionary = {}
var _black_hole_pending_free_ids: Dictionary = {}

@onready var _body: Polygon2D = get_node_or_null("Body") as Polygon2D
@onready var _inner_core: Polygon2D = get_node_or_null("InnerCore") as Polygon2D
@onready var _phase_halo: Line2D = get_node_or_null("PhaseHalo") as Line2D
@onready var _orbit_trace: Line2D = get_node_or_null("OrbitTrace") as Line2D
@onready var _pulse_telegraph: Line2D = get_node_or_null("PulseTelegraph") as Line2D
@onready var _black_hole_horizon: Line2D = get_node_or_null("BlackHoleHorizon") as Line2D
@onready var _black_hole_shear: Line2D = get_node_or_null("BlackHoleShear") as Line2D
@onready var _particles: GPUParticles2D = _resolve_particles()
@onready var _attack_area: Area2D = get_node_or_null("Attack") as Area2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ParametricEnemies")
	add_to_group("rare_enemy")
	add_to_group("elite")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	_base_mass = mass
	_register_runtime_groups()
	_rng.randomize()
	player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	anchor_position = global_position
	desired_position = global_position
	_pulse_cooldown_remaining = _rng.randf_range(0.6, 1.3)
	_seed_cooldown_remaining = _rng.randf_range(1.1, 2.1)
	_setup_health()
	_setup_gravity_component()
	_setup_attack_area()
	_refresh_static_visual_geometry()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	_unregister_runtime_groups()
	_restore_all_black_hole_spaghettified_targets()
	for bead in _active_beads:
		_release_bead(bead, true)
	_active_beads.clear()
	for point in _mass_point_pool:
		if point != null and is_instance_valid(point) and not point.is_queued_for_deletion():
			point.queue_free()
	_mass_point_pool.clear()


func _process(delta: float) -> void:
	_update_active_beads(delta)
	_update_black_hole_cooldowns(delta)
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	lifetime += scaled_delta
	phase_time += scaled_delta * equation_speed * _phase_speed_multiplier()
	_hit_cooldown = maxf(_hit_cooldown - scaled_delta, 0.0)
	_pulse_cooldown_remaining = maxf(_pulse_cooldown_remaining - scaled_delta, 0.0)
	_seed_cooldown_remaining = maxf(_seed_cooldown_remaining - scaled_delta, 0.0)

	if player == null or not is_instance_valid(player):
		player = MultiplayerTargeting.nearest_player(global_position, get_tree())

	_update_dance_window(phase_time)
	_update_phase_from_health()
	_update_motion(scaled_delta)
	_update_pulse_attack(scaled_delta)
	_try_seed_gravity_beads()
	_update_black_hole_field(scaled_delta)
	_damage_slide_collisions()


func take_damage(amount: float) -> void:
	if _health == null:
		return
	var final_amount := amount * _skill_damage_multiplier()
	_health.take_damage(final_amount)
	if final_amount > amount + 0.01:
		_reward_skill_hit()


func _update_motion(delta: float) -> void:
	var center := global_position
	if player != null and is_instance_valid(player):
		var lead := _body_velocity(player) * player_velocity_lead
		center = player.global_position + lead

	var offset := _movement_offset(phase_time)
	desired_position = center + offset
	if player != null and is_instance_valid(player):
		var pressure := clampf(global_position.distance_to(player.global_position) / 900.0, 0.0, 1.0)
		desired_position = desired_position.lerp(player.global_position, pursuit_bias * pressure)

	anchor_position = anchor_position.lerp(desired_position, clampf(delta * anchor_follow_speed, 0.0, 1.0))
	var to_anchor := anchor_position - global_position
	var distance := to_anchor.length()
	if distance > arrival_distance:
		var arrival_force := clampf(distance / 280.0, 0.18, 1.0)
		velocity += to_anchor.normalized() * engine_thrust * arrival_force * delta

	velocity -= velocity * drag * delta
	velocity = velocity.limit_length(max_speed * _phase_speed_multiplier())
	move_and_slide()

	if velocity.length_squared() > 16.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 8.5, 0.0, 1.0))


func _movement_offset(time: float) -> Vector2:
	if _black_hole_mode_active:
		var collapse_radius := orbit_scale * (0.34 + 0.12 * sin(time * 8.0))
		var wobble := Vector2(sin(time * 13.0), cos(time * 11.0)) * 34.0
		return Vector2(cos(time * 5.0), sin(time * 4.0)) * collapse_radius + wobble

	var phase_scale := 1.0 + float(_phase) * 0.12
	match _phase:
		0:
			return Vector2(
				sin(time * 3.0) * orbit_scale,
				cos(time * 2.0) * orbit_scale * 0.62
			)
		1:
			return Vector2(
				sin(time * 4.0) * orbit_scale * 1.04,
				sin(time * 5.0 + PI * 0.35) * orbit_scale * 0.86
			)
		2:
			var r := orbit_scale * (0.72 + 0.34 * cos(time * 7.0))
			return Vector2(cos(time * 2.0), sin(time * 3.0)) * r * phase_scale
		_:
			var rose := orbit_scale * cos(time * 5.0)
			var fracture := Vector2(sin(time * 11.0), cos(time * 9.0)) * 46.0
			return Vector2(cos(time), sin(time * 1.35)) * rose + fracture


func _update_pulse_attack(delta: float) -> void:
	if _is_charging_pulse:
		_pulse_charge_elapsed += delta
		_update_pulse_telegraph()
		if _pulse_charge_elapsed >= pulse_charge_time * _phase_charge_multiplier():
			_release_parametric_pulse()
		return

	if _pulse_cooldown_remaining > 0.0 or player == null or not is_instance_valid(player):
		return
	if global_position.distance_squared_to(player.global_position) > pulse_radius * pulse_radius * 2.6:
		return

	_begin_pulse_charge()


func _begin_pulse_charge() -> void:
	_is_charging_pulse = true
	_pulse_charge_elapsed = 0.0
	if _black_hole_mode_active:
		_pulse_mode = PulseMode.COMPRESSION
	else:
		_pulse_mode = PulseMode.REPULSION if int(lifetime * 0.7 + float(_phase)) % 2 == 0 else PulseMode.COMPRESSION
	if _pulse_telegraph != null:
		_pulse_telegraph.visible = true
		_pulse_telegraph.scale = Vector2.ONE
	_update_pulse_telegraph()


func _update_pulse_telegraph() -> void:
	if _pulse_telegraph == null:
		return
	var charge_duration := maxf(pulse_charge_time * _phase_charge_multiplier(), 0.05)
	var ratio := clampf(_pulse_charge_elapsed / charge_duration, 0.0, 1.0)
	var radius := pulse_radius * lerpf(0.32, 1.0 + float(_phase) * 0.08, ratio)
	_set_circle_line(_pulse_telegraph, radius, _visual_segments(72))
	_pulse_telegraph.width = lerpf(2.0, 9.0, ratio)
	_pulse_telegraph.default_color = _pulse_color(lerpf(0.16, 0.66, ratio))
	_pulse_telegraph.rotation += 0.08 + ratio * 0.1


func _release_parametric_pulse() -> void:
	_is_charging_pulse = false
	_pulse_cooldown_remaining = pulse_cooldown * lerpf(1.0, 0.68, float(_phase) / 3.0)
	if _black_hole_mode_active:
		_pulse_cooldown_remaining *= 0.58
	if _pulse_telegraph != null:
		_pulse_telegraph.visible = false

	var radius := pulse_radius * (1.0 + float(_phase) * 0.12)
	var damage_amount := pulse_damage * (1.0 + float(_phase) * 0.18)
	if _black_hole_mode_active:
		radius = maxf(radius, black_hole_spaghettify_radius * 1.16)
		damage_amount *= 1.18
	_damage_targets(PULSE_TARGET_GROUPS, global_position, radius, damage_amount, true, false, true)
	_spawn_parametric_burst(global_position, radius, _pulse_color(0.58), "ParametricPulsatorPulse")
	_spawn_rose_burst(global_position, radius * 0.58, _pulse_color(0.42), 5 + _phase)
	parametric_pulse_released.emit({
		"position": global_position,
		"radius": radius,
		"damage": damage_amount,
		"mode": _pulse_mode,
	})


func _try_seed_gravity_beads() -> void:
	if _seed_cooldown_remaining > 0.0:
		return
	if player == null or not is_instance_valid(player):
		return
	if _active_beads.size() >= max_active_beads:
		return

	var count := clampi(bead_count + _phase, 3, max_active_beads - _active_beads.size())
	var origin := player.global_position + _body_velocity(player) * 0.18
	if _black_hole_mode_active:
		count = clampi(count + 2, 3, max_active_beads - _active_beads.size())
		origin = global_position.lerp(origin, 0.45)
	for i in range(count):
		_seed_gravity_bead(origin, i, count)
	var mode_multiplier := 0.64 if _black_hole_mode_active else 1.0
	_seed_cooldown_remaining = bead_seed_cooldown * lerpf(1.0, 0.62, float(_phase) / 3.0) * mode_multiplier


func _seed_gravity_bead(origin: Vector2, index: int, count: int) -> void:
	var point := _acquire_mass_point()
	if point == null:
		return

	var phase_offset := TAU * float(index) / float(maxi(count, 1)) + _rng.randf_range(-0.16, 0.16)
	var bead_position := origin + _bead_offset(phase_offset, 0.0)
	point.global_position = bead_position
	if point.get("mass") != null:
		point.set("mass", bead_gravity_mass * (1.0 + float(_phase) * 0.12))
	if point.has_method("set_gravity_active"):
		point.call("set_gravity_active", true)

	var marker := Node2D.new()
	marker.name = "ParametricGravityBeadMarker"
	marker.global_position = bead_position
	marker.z_index = 34
	_add_effect_node(marker)

	var ring := Line2D.new()
	ring.name = "GravityBeadTelegraph"
	ring.closed = true
	ring.antialiased = true
	ring.width = 2.6
	ring.points = _circle_points(_visual_segments(34), bead_blast_radius)
	ring.default_color = _safe_color(charge_color, 0.34)
	marker.add_child(ring)

	var chord := Line2D.new()
	chord.name = "GravityBeadChord"
	chord.antialiased = true
	chord.width = 2.2
	chord.points = PackedVector2Array([
		Vector2(-bead_blast_radius * 0.52, 0.0),
		Vector2(bead_blast_radius * 0.52, 0.0),
	])
	chord.default_color = _safe_color(calm_color, 0.46)
	marker.add_child(chord)

	_active_beads.append({
		"node": point,
		"marker": marker,
		"ring": ring,
		"chord": chord,
		"origin": origin,
		"phase_offset": phase_offset,
		"age": 0.0,
		"lifetime": bead_lifetime * _rng.randf_range(0.9, 1.15),
	})
	gravity_bead_seeded.emit({
		"position": bead_position,
		"radius": bead_blast_radius,
		"lifetime": bead_lifetime,
	})


func _update_active_beads(delta: float) -> void:
	for index in range(_active_beads.size() - 1, -1, -1):
		var bead := _active_beads[index]
		var point := bead.get("node") as Node2D
		if point == null or not is_instance_valid(point):
			_active_beads.remove_at(index)
			continue

		var age := float(bead.get("age", 0.0)) + delta
		var lifetime_value := maxf(float(bead.get("lifetime", bead_lifetime)), 0.08)
		var ratio := clampf(age / lifetime_value, 0.0, 1.0)
		var origin := bead.get("origin", global_position) as Vector2
		var phase_offset := float(bead.get("phase_offset", 0.0))
		point.global_position = origin + _bead_offset(phase_offset, age)

		var marker := bead.get("marker") as Node2D
		var ring := bead.get("ring") as Line2D
		var chord := bead.get("chord") as Line2D
		if marker != null and is_instance_valid(marker):
			marker.global_position = point.global_position
			marker.rotation += delta * (1.1 + float(_phase) * 0.38)
		if ring != null:
			ring.scale = Vector2.ONE * lerpf(0.58, 1.0, ratio)
			ring.width = lerpf(1.6, 5.4, ratio)
			ring.default_color = _safe_color(charge_color.lerp(rupture_color, ratio), lerpf(0.18, 0.54, ratio))
		if chord != null:
			chord.rotation -= delta * 2.1
			chord.default_color = _safe_color(calm_color.lerp(rupture_color, ratio), 0.38)

		bead["age"] = age
		_active_beads[index] = bead
		if age >= lifetime_value:
			_detonate_bead(bead)
			_active_beads.remove_at(index)


func _bead_offset(phase_offset: float, age: float) -> Vector2:
	var t := phase_time * 0.76 + phase_offset + age * (0.9 + float(_phase) * 0.18)
	var radius := bead_orbit_radius * (0.72 + 0.12 * sin(t * 3.0))
	return Vector2(
		sin(t * 2.0) * radius,
		cos(t * 3.0 + phase_offset * 0.4) * radius * 0.72
	)


func _detonate_bead(bead: Dictionary) -> void:
	var point := bead.get("node") as Node2D
	var position := point.global_position if point != null and is_instance_valid(point) else global_position
	var radius := bead_blast_radius * (1.0 + float(_phase) * 0.08)
	_damage_targets(BEAD_TARGET_GROUPS, position, radius, bead_damage * (1.0 + float(_phase) * 0.15), true, false, false)
	_spawn_parametric_burst(position, radius, _safe_color(rupture_color, 0.46), "ParametricBeadDetonation")
	_release_bead(bead, true)


func _release_bead(bead: Dictionary, recycle_point: bool) -> void:
	var marker := bead.get("marker") as Node2D
	if marker != null and is_instance_valid(marker) and not marker.is_queued_for_deletion():
		marker.queue_free()

	var point := bead.get("node") as Node2D
	if point == null or not is_instance_valid(point):
		return
	if point.has_method("set_gravity_active"):
		point.call("set_gravity_active", false)
	else:
		if point.is_in_group("Objects_With_Gravity"):
			point.remove_from_group("Objects_With_Gravity")
		if point.is_in_group("planets"):
			point.remove_from_group("planets")
	if point.get("mass") != null:
		point.set("mass", 0.0)
	if recycle_point and not _mass_point_pool.has(point):
		_mass_point_pool.append(point)


func _damage_targets(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	damage_amount: float,
	include_player: bool,
	enemies_only: bool,
	use_pulse_force: bool
) -> void:
	_fill_targets_in_radius(groups, center, radius, max_targets_per_pulse, include_player, _target_buffer)
	for target in _target_buffer:
		if target == null or not is_instance_valid(target) or target == self or target.is_queued_for_deletion():
			continue
		if enemies_only and not (target.is_in_group("enemies") or target.is_in_group("wave_enemy") or target.is_in_group("bosses")):
			continue

		var offset := target.global_position - center
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / maxf(radius, 1.0), 0.0, 1.0)
		var damage_multiplier := 1.0 if target.is_in_group("Player") else 0.62
		if target.has_method("take_damage"):
			target.call("take_damage", damage_amount * damage_multiplier * (0.34 + 0.66 * falloff))

		var direction := offset.normalized()
		if use_pulse_force and _pulse_mode == PulseMode.COMPRESSION:
			direction = -direction
		var force := (pulse_impulse if use_pulse_force else bead_impulse) * (0.35 + 0.65 * falloff)
		CombatStatus.add_velocity(target, direction * force)
		if use_pulse_force and target.is_in_group("Player"):
			CombatStatus.apply_local_time_scale(target, pulse_time_slow, 0.22 + 0.08 * float(_phase))


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
		for node in get_tree().get_nodes_in_group(group_name):
			if max_count > 0 and out_targets.size() >= max_count:
				return
			var body := node as Node2D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			if not include_player and body.is_in_group("Player"):
				continue
			var id := body.get_instance_id()
			if _query_seen_ids.has(id):
				continue
			_query_seen_ids[id] = true
			if body.global_position.distance_squared_to(center) <= radius_squared:
				out_targets.append(body)


func _enter_black_hole_mode() -> void:
	if _black_hole_mode_active:
		return
	_black_hole_mode_active = true
	_phase = 3
	_pulse_mode = PulseMode.COMPRESSION
	_pulse_cooldown_remaining = 0.18
	_seed_cooldown_remaining = 0.35
	_black_hole_field_elapsed = 999.0
	mass = _base_mass * black_hole_mass_multiplier
	if _gravity_component != null:
		_gravity_component.gravity_constant = _black_hole_gravity_constant()
		_gravity_component.max_gravity_distance = 1900.0
	_spawn_parametric_burst(global_position, black_hole_event_horizon_radius, _safe_color(Color(0.06, 0.02, 0.12, 1.0), 0.62), "ParametricBlackHoleIgnition")
	_spawn_rose_burst(global_position, black_hole_spaghettify_radius, _safe_color(rupture_color, 0.52), 9)
	black_hole_mode_started.emit({
		"position": global_position,
		"event_horizon_radius": black_hole_event_horizon_radius,
		"spaghettify_radius": black_hole_spaghettify_radius,
	})


func _update_black_hole_field(delta: float) -> void:
	if not _black_hole_mode_active:
		return
	_black_hole_field_elapsed += delta
	if _black_hole_field_elapsed < maxf(black_hole_field_tick_interval, 0.02):
		return
	var field_delta := _black_hole_field_elapsed
	_black_hole_field_elapsed = 0.0
	_fill_targets_in_radius(
		BLACK_HOLE_TARGET_GROUPS,
		global_position,
		black_hole_event_horizon_radius,
		black_hole_max_targets_per_tick,
		true,
		_target_buffer
	)
	var affected := 0
	for body in _target_buffer:
		if affected >= black_hole_max_targets_per_tick:
			break
		if not _black_hole_body_can_receive_field(body):
			continue
		var offset := global_position - body.global_position
		if not _finite_vector(offset):
			continue
		var distance := maxf(offset.length(), 1.0)
		if distance <= black_hole_consume_radius:
			_consume_black_hole_body(body)
			continue
		var radial := offset / distance
		var tangent := radial.orthogonal()
		var falloff := 1.0 - clampf(distance / maxf(black_hole_event_horizon_radius, 1.0), 0.0, 1.0)
		var shear_sign := signf(sin(float(body.get_instance_id()) * 0.17 + _black_hole_visual_time * 5.1))
		var pull := radial * black_hole_pull_force * falloff
		var shear := tangent * black_hole_tangent_shear_force * falloff * shear_sign
		_apply_safe_black_hole_velocity(body, (pull + shear) * field_delta)
		if distance <= black_hole_spaghettify_radius:
			_apply_black_hole_spaghettification(body, radial, 1.0 - distance / maxf(black_hole_spaghettify_radius, 1.0), field_delta)
		else:
			_restore_black_hole_spaghettified_shape(body)
		affected += 1
	_restore_black_hole_finished_targets()


func _apply_black_hole_spaghettification(body: Node2D, radial: Vector2, intensity: float, delta: float) -> void:
	if not _black_hole_body_can_receive_field(body):
		return
	var clamped := clampf(intensity, 0.0, 1.0)
	var id := body.get_instance_id()
	if not _black_hole_spaghettified_ids.has(id):
		var visual := _spaghettification_visual(body)
		_black_hole_spaghettified_ids[id] = {
			"visual_id": visual.get_instance_id() if visual != null else 0,
			"scale": visual.scale if visual != null else Vector2.ONE,
			"rotation": visual.rotation if visual != null else 0.0,
		}
	body.set_meta(&"pulsator_black_hole_axis", radial)
	body.set_meta(&"pulsator_black_hole_intensity", clamped)
	var entry_value: Variant = _black_hole_spaghettified_ids.get(id, {})
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var visual_id := int(entry.get("visual_id", 0))
	if visual_id > 0 and is_instance_id_valid(visual_id):
		var value := instance_from_id(visual_id)
		var visual_node := value as Node2D
		if visual_node != null and is_instance_valid(visual_node):
			var original_scale: Vector2 = entry.get("scale", Vector2.ONE)
			var original_rotation := float(entry.get("rotation", 0.0))
			var stretch := 1.0 + clamped * 1.35
			var pinch := maxf(1.0 - clamped * 0.36, 0.42)
			visual_node.scale = original_scale * Vector2(stretch, pinch)
			visual_node.rotation = lerp_angle(original_rotation, radial.angle(), clampf(clamped * 0.72, 0.0, 0.72))
	if body.has_method("take_damage"):
		var multiplier := 1.0 if body.is_in_group("Player") else 0.52
		_queue_black_hole_damage(body, black_hole_spaghettify_damage_per_second * clamped * delta * multiplier)


func _restore_black_hole_spaghettified_shape(body: Node2D) -> void:
	if body == null:
		return
	var id := body.get_instance_id()
	if not _black_hole_spaghettified_ids.has(id):
		return
	var entry_value: Variant = _black_hole_spaghettified_ids.get(id, {})
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var visual_id := int(entry.get("visual_id", 0))
	if visual_id > 0 and is_instance_id_valid(visual_id):
		var value := instance_from_id(visual_id)
		var visual_node := value as Node2D
		if visual_node != null and is_instance_valid(visual_node):
			visual_node.scale = entry.get("scale", Vector2.ONE)
			visual_node.rotation = float(entry.get("rotation", 0.0))
	_black_hole_spaghettified_ids.erase(id)
	if body.has_meta(&"pulsator_black_hole_axis"):
		body.remove_meta(&"pulsator_black_hole_axis")
	if body.has_meta(&"pulsator_black_hole_intensity"):
		body.remove_meta(&"pulsator_black_hole_intensity")


func _restore_black_hole_finished_targets() -> void:
	for key in _black_hole_spaghettified_ids.keys():
		var id := int(key)
		if not is_instance_id_valid(id):
			_black_hole_spaghettified_ids.erase(key)
			continue
		var value := instance_from_id(id)
		var body := value as Node2D
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			_black_hole_spaghettified_ids.erase(key)
			continue
		if body.global_position.distance_squared_to(global_position) > black_hole_spaghettify_radius * black_hole_spaghettify_radius:
			_restore_black_hole_spaghettified_shape(body)


func _restore_all_black_hole_spaghettified_targets() -> void:
	for key in _black_hole_spaghettified_ids.keys():
		var id := int(key)
		if not is_instance_id_valid(id):
			continue
		var value := instance_from_id(id)
		var body := value as Node2D
		if body != null and is_instance_valid(body):
			_restore_black_hole_spaghettified_shape(body)
	_black_hole_spaghettified_ids.clear()


func _consume_black_hole_body(body: Node2D) -> void:
	if not _black_hole_body_can_receive_field(body):
		return
	var id := body.get_instance_id()
	if _black_hole_consume_cooldowns.has(id):
		return
	_black_hole_consume_cooldowns[id] = black_hole_player_consume_cooldown if body.is_in_group("Player") else 0.26
	_restore_black_hole_spaghettified_shape(body)
	body.set_meta(&"last_death_context", &"parametric_black_hole")
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			_queue_black_hole_damage(body, black_hole_consume_damage)
		CombatStatus.apply_local_time_scale(body, 0.58, 0.34)
		CombatStatus.add_velocity(body, (body.global_position - global_position).normalized() * 520.0)
		return
	if body.is_in_group("bosses"):
		if body.has_method("take_damage"):
			_queue_black_hole_damage(body, black_hole_consume_damage * 0.65)
		return
	if body.has_method("take_damage"):
		_queue_black_hole_damage(body, black_hole_enemy_consume_damage)
	elif body is RigidBody2D or body is Area2D or body.is_in_group("Projectiles") or body.is_in_group("enemy_projectiles") or body.is_in_group("player_projectiles"):
		_queue_free_black_hole_body(body)


func _apply_safe_black_hole_velocity(body: Node, impulse: Vector2) -> void:
	if not _black_hole_body_can_receive_field(body as Node2D) or not _finite_vector(impulse):
		return
	var safe_impulse := impulse.limit_length(maxf(black_hole_max_field_impulse_per_tick, 1.0))
	if body is RigidBody2D:
		var rigid_body := body as RigidBody2D
		if rigid_body.freeze:
			return
		rigid_body.apply_central_impulse(safe_impulse * maxf(rigid_body.mass, 0.01))
		if _finite_vector(rigid_body.linear_velocity) and rigid_body.linear_velocity.length() > black_hole_max_body_speed_after_pull:
			rigid_body.linear_velocity = rigid_body.linear_velocity.limit_length(maxf(black_hole_max_body_speed_after_pull, 1.0))
		return
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		var next_velocity: Vector2 = velocity_value
		if not _finite_vector(next_velocity):
			next_velocity = Vector2.ZERO
		body.set("velocity", (next_velocity + safe_impulse).limit_length(maxf(black_hole_max_body_speed_after_pull, 1.0)))
		return
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		var next_linear_velocity: Vector2 = linear_velocity_value
		if not _finite_vector(next_linear_velocity):
			next_linear_velocity = Vector2.ZERO
		body.set("linear_velocity", (next_linear_velocity + safe_impulse).limit_length(maxf(black_hole_max_body_speed_after_pull, 1.0)))


func _queue_black_hole_damage(body: Node, amount: float) -> void:
	if body == null or amount <= 0.0 or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if _body_death_in_progress(body):
		return
	var id := body.get_instance_id()
	if _black_hole_damage_queue.has(id):
		_black_hole_damage_queue[id] = float(_black_hole_damage_queue[id]) + amount
		return
	_black_hole_damage_queue[id] = amount
	call_deferred("_deal_queued_black_hole_damage", id)


func _deal_queued_black_hole_damage(instance_id: int) -> void:
	if not _black_hole_damage_queue.has(instance_id):
		return
	var amount := float(_black_hole_damage_queue.get(instance_id, 0.0))
	_black_hole_damage_queue.erase(instance_id)
	if amount <= 0.0 or not is_instance_id_valid(instance_id):
		return
	var value := instance_from_id(instance_id)
	var body := value as Node
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion() or not body.has_method("take_damage"):
		return
	if _body_death_in_progress(body):
		return
	body.call("take_damage", amount)


func _queue_free_black_hole_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	var id := body.get_instance_id()
	if _black_hole_pending_free_ids.has(id):
		return
	_black_hole_pending_free_ids[id] = true
	body.call_deferred("queue_free")


func _update_black_hole_cooldowns(delta: float) -> void:
	for key in _black_hole_consume_cooldowns.keys():
		var remaining := float(_black_hole_consume_cooldowns.get(key, 0.0)) - delta
		if remaining <= 0.0 or not is_instance_id_valid(int(key)):
			_black_hole_consume_cooldowns.erase(key)
		else:
			_black_hole_consume_cooldowns[key] = remaining
	for key in _black_hole_pending_free_ids.keys():
		if not is_instance_id_valid(int(key)):
			_black_hole_pending_free_ids.erase(key)


func _black_hole_body_can_receive_field(body: Node2D) -> bool:
	if body == null or body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	if _body_death_in_progress(body):
		return false
	return true


func _spaghettification_visual(body: Node) -> Node2D:
	if body == null or not is_instance_valid(body):
		return null
	var direct := body.get_node_or_null("Polygon2D") as Node2D
	if direct != null:
		return direct
	var polygons := body.find_children("*", "Polygon2D", true, false)
	if polygons.is_empty():
		return null
	return polygons[0] as Node2D


func _body_death_in_progress(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return true
	if body.has_method("is_death_in_progress") and bool(body.call("is_death_in_progress")):
		return true
	return bool(body.get_meta(&"death_in_progress", false))


func _finite_vector(value: Vector2) -> bool:
	return _finite_float(value.x) and _finite_float(value.y)


func _finite_float(value: float) -> bool:
	return value == value and absf(value) < INF


func _update_phase_from_health() -> void:
	var desired_phase := 0
	if _health_ratio <= black_hole_health_threshold:
		desired_phase = 3
		_enter_black_hole_mode()
	elif _health_ratio <= 0.24:
		desired_phase = 3
	elif _health_ratio <= 0.48:
		desired_phase = 2
	elif _health_ratio <= 0.72:
		desired_phase = 1

	if desired_phase == _phase:
		return
	_phase = desired_phase
	_pulse_cooldown_remaining = minf(_pulse_cooldown_remaining, 0.55)
	_seed_cooldown_remaining = minf(_seed_cooldown_remaining, 0.8)
	mass = _base_mass * (black_hole_mass_multiplier if _black_hole_mode_active else 1.0 + float(_phase) * 0.2)
	if _gravity_component != null:
		_gravity_component.gravity_constant = _black_hole_gravity_constant()
		_gravity_component.max_gravity_distance = 1900.0 if _black_hole_mode_active else 1600.0
	_spawn_rose_burst(global_position, 170.0 + float(_phase) * 60.0, _phase_color(0.52), 4 + _phase)


func _damage_slide_collisions() -> void:
	if _hit_cooldown > 0.0:
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		var body_2d := body as Node2D
		if body_2d != null:
			_apply_contact_damage(body_2d)


func _apply_contact_damage(body: Node2D) -> void:
	if _hit_cooldown > 0.0:
		return
	if not body.is_in_group("Player") or not body.has_method("take_damage"):
		return
	body.call("take_damage", contact_damage)
	var direction := (body.global_position - global_position).normalized()
	CombatStatus.add_velocity(body, direction * contact_knockback)
	_hit_cooldown = 0.58


func _on_attack_body_entered(body: Node2D) -> void:
	if body != null:
		_apply_contact_damage(body)


func _on_health_component_died() -> void:
	_trigger_death_supernova()
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.24, true)
	PowerupLibrary.try_spawn_energy_droplets(get_parent(), global_position, 5, 1.0, 76.0, 9.0)
	queue_free()


func _on_health_component_health_changed(current_health: Variant, max_health_value: Variant) -> void:
	_health_ratio = _health_ratio_from_values(current_health, max_health_value)
	if _particles != null:
		_particles.amount_ratio = lerpf(1.0, 0.62, 1.0 - _health_ratio)


func _trigger_death_supernova() -> void:
	var radius := pulse_radius * 1.36
	_damage_targets(PULSE_TARGET_GROUPS, global_position, radius, pulse_damage * 1.45, true, false, true)
	_spawn_parametric_burst(global_position, radius, _safe_color(rupture_color, 0.62), "ParametricPulsatorDeathWave")
	_spawn_rose_burst(global_position, radius * 0.74, _safe_color(charge_color, 0.58), 9)
	if _black_hole_mode_active:
		_spawn_parametric_burst(global_position, black_hole_event_horizon_radius, _safe_color(Color(0.04, 0.02, 0.09, 1.0), 0.64), "ParametricBlackHoleCollapse")
	for bead in _active_beads:
		_release_bead(bead, true)
	_active_beads.clear()
	_restore_all_black_hole_spaghettified_targets()


func _update_visuals(delta: float) -> void:
	_black_hole_visual_time += delta
	var pulse := 0.5 + 0.5 * sin(lifetime * (5.8 + float(_phase) * 1.6))
	var charge_ratio := _pulse_charge_ratio()
	var stress := maxf(charge_ratio, 1.0 - _health_ratio)
	var body_color := calm_color.lerp(_phase_color(1.0), clampf(0.22 + stress * 0.68, 0.0, 1.0))
	body_color = body_color.lerp(charge_color, charge_ratio)
	if _black_hole_mode_active:
		body_color = body_color.lerp(Color(0.04, 0.01, 0.09, 1.0), 0.72)

	if _body != null:
		_body.color = _safe_color(body_color, 1.0)
		var black_hole_swell := 0.22 if _black_hole_mode_active else 0.0
		_body.scale = Vector2.ONE * (1.0 + pulse * 0.06 + stress * 0.16 + black_hole_swell)
		_body.rotation += delta * (0.9 + float(_phase) * 0.35 + (1.2 if _black_hole_mode_active else 0.0))

	if _inner_core != null:
		var core_color := rare_core_color.lerp(charge_color, charge_ratio)
		if _black_hole_mode_active:
			core_color = Color(0.0, 0.0, 0.0, 1.0).lerp(rupture_color, 0.18 + pulse * 0.12)
		_inner_core.color = _safe_color(core_color, 0.9)
		_inner_core.scale = Vector2.ONE * (0.82 + pulse * 0.14 + charge_ratio * 0.22 + (0.34 if _black_hole_mode_active else 0.0))
		_inner_core.rotation -= delta * (2.0 + float(_phase) * 0.6 + (2.8 if _black_hole_mode_active else 0.0))

	if _phase_halo != null:
		var halo_radius := 72.0 + float(_phase) * 18.0 + pulse * 12.0
		_set_circle_line(_phase_halo, halo_radius, _visual_segments(56))
		_phase_halo.width = 2.0 + charge_ratio * 4.0 + float(_phase) * 0.5
		_phase_halo.default_color = _phase_color(_safe_alpha(0.16 + 0.18 * pulse + charge_ratio * 0.28))
		_phase_halo.rotation -= delta * (0.8 + float(_phase) * 0.34)

	if _orbit_trace != null:
		_orbit_trace.width = 1.35 + _dance_window_intensity * 2.2
		_orbit_trace.default_color = _safe_color(calm_color.lerp(charge_color, _dance_window_intensity), 0.24 + _dance_window_intensity * 0.24)
		_orbit_trace.rotation += delta * (0.28 + float(_phase) * 0.12)

	if _particles != null:
		_particles.speed_scale = 0.9 + _dance_window_intensity * 1.2 + charge_ratio * 1.4 + float(_phase) * 0.2
		if _black_hole_mode_active:
			_particles.speed_scale += 1.6
			_particles.modulate = Color(0.62, 0.38, 1.0, 0.74)
		else:
			_particles.modulate = Color.WHITE
		_particles.emitting = true

	_update_black_hole_visuals(delta)


func _update_black_hole_visuals(delta: float) -> void:
	if not _black_hole_mode_active:
		_set_black_hole_rings_visible(false)
		return
	_set_black_hole_rings_visible(true)
	var pulse := 0.5 + 0.5 * sin(_black_hole_visual_time * 3.4)
	if _black_hole_horizon != null:
		var horizon_radius := _world_effect_radius(black_hole_event_horizon_radius, 680.0)
		_black_hole_horizon.points = _black_hole_ring_points(horizon_radius, _visual_segments(72), 0.018 + pulse * 0.014)
		_black_hole_horizon.width = lerpf(3.0, 8.0, pulse)
		_black_hole_horizon.default_color = Color(1.0, 0.18, 0.08, _safe_alpha(0.18 + pulse * 0.18))
		_black_hole_horizon.rotation += delta * 0.24
	if _black_hole_shear != null:
		var shear_radius := _world_effect_radius(black_hole_spaghettify_radius, 360.0)
		_black_hole_shear.points = _black_hole_ring_points(shear_radius, _visual_segments(46), 0.055)
		_black_hole_shear.width = lerpf(1.6, 4.4, pulse)
		_black_hole_shear.default_color = Color(0.68, 0.38, 1.0, _safe_alpha(0.16 + pulse * 0.12))
		_black_hole_shear.rotation -= delta * 0.72


func _refresh_static_visual_geometry() -> void:
	if _phase_halo != null:
		_phase_halo.closed = true
		_phase_halo.antialiased = true
		_set_circle_line(_phase_halo, 72.0, _visual_segments(56))
	if _orbit_trace != null:
		_orbit_trace.closed = true
		_orbit_trace.antialiased = true
		_orbit_trace.points = _movement_trace_points(_visual_segments(96))
	if _pulse_telegraph != null:
		_pulse_telegraph.closed = true
		_pulse_telegraph.antialiased = true
		_pulse_telegraph.visible = false
	for ring in [_black_hole_horizon, _black_hole_shear]:
		if ring != null:
			ring.closed = true
			ring.antialiased = true
			ring.visible = false


func _set_black_hole_rings_visible(visible: bool) -> void:
	if _black_hole_horizon != null:
		_black_hole_horizon.visible = visible
	if _black_hole_shear != null:
		_black_hole_shear.visible = visible


func _movement_trace_points(count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 8)
	for i in range(safe_count):
		var t := TAU * float(i) / float(safe_count)
		points.append(Vector2(sin(t * 3.0) * 88.0, cos(t * 2.0) * 58.0))
	return points


func _spawn_parametric_burst(position: Vector2, radius: float, color: Color, node_name: String) -> void:
	var ring := Line2D.new()
	ring.name = node_name
	ring.z_index = 44
	ring.closed = true
	ring.antialiased = true
	ring.width = 5.2
	ring.points = _circle_points(_visual_segments(72), 1.0)
	ring.default_color = color
	ring.global_position = position
	_add_effect_node(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "width", 0.6, 0.28)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(ring))


func _spawn_rose_burst(position: Vector2, radius: float, color: Color, petals: int) -> void:
	var rose := Line2D.new()
	rose.name = "ParametricRoseBurst"
	rose.z_index = 45
	rose.closed = true
	rose.antialiased = true
	rose.width = 3.2
	rose.points = _rose_points(_visual_segments(120), radius, petals)
	rose.default_color = color
	rose.global_position = position
	rose.scale = Vector2.ONE * 0.18
	_add_effect_node(rose)
	var tween := rose.create_tween()
	tween.tween_property(rose, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(rose, "rotation", PI * 0.32, 0.22)
	tween.parallel().tween_property(rose, "modulate:a", 0.0, 0.34)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(rose))


func _spawn_skill_hit_ring() -> void:
	var radius := 110.0 + _dance_window_intensity * 48.0
	_spawn_parametric_burst(global_position, radius, _safe_color(Color(0.3, 1.0, 0.86, 1.0), 0.46), "ParametricPulsatorSkillReward")


func _setup_health() -> void:
	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		add_child(_health)
	_health.max_health = max_health
	_health.current_health = max_health
	_health_ratio = _health_ratio_from_values(_health.current_health, _health.max_health)
	var died_callable := Callable(self, "_on_health_component_died")
	if not _health.died.is_connected(died_callable):
		_health.died.connect(died_callable)
	var changed_callable := Callable(self, "_on_health_component_health_changed")
	if not _health.health_changed.is_connected(changed_callable):
		_health.health_changed.connect(changed_callable)


func _setup_gravity_component() -> void:
	_gravity_component = get_node_or_null("GravityComponent") as GravityComponent
	if _gravity_component == null:
		_gravity_component = GravityComponent.new()
		_gravity_component.name = "GravityComponent"
		add_child(_gravity_component)
	_gravity_component.gravity_constant = _black_hole_gravity_constant()
	_gravity_component.max_sources = 4
	_gravity_component.max_gravity_distance = 1900.0 if _black_hole_mode_active else 1600.0
	_gravity_component.min_gravity_distance = 70.0


func _setup_attack_area() -> void:
	if _attack_area == null:
		return
	var callback := Callable(self, "_on_attack_body_entered")
	if not _attack_area.body_entered.is_connected(callback):
		_attack_area.body_entered.connect(callback)


func _acquire_mass_point() -> Node2D:
	var point: Node2D = null
	while not _mass_point_pool.is_empty() and point == null:
		var candidate: Node2D = _mass_point_pool.pop_back()
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			point = candidate
	if point == null:
		point = MASS_POINT_SCENE.instantiate() as Node2D
		if point == null:
			return null
	_add_effect_node(point)
	return point


func _add_effect_node(node: Node) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		if node.get_parent() == null:
			add_child(node)
		elif node.get_parent() != self:
			node.reparent(self)
		return
	if node.get_parent() == null:
		parent.add_child(node)
	elif node.get_parent() != parent:
		node.reparent(parent)


func _update_dance_window(time: float) -> void:
	var phase := fposmod(time, TAU) / TAU
	var beats := maxi(dance_beats_per_loop, 1)
	var beat_phase := fposmod(phase * float(beats), 1.0)
	var distance_to_beat := minf(beat_phase, 1.0 - beat_phase)
	var width := clampf(dance_window_width, 0.01, 0.48)
	_dance_window_intensity = clampf(1.0 - distance_to_beat / width, 0.0, 1.0)
	_dance_window_active = _dance_window_intensity > 0.0


func _skill_damage_multiplier() -> float:
	var multiplier := 1.0
	if _dance_window_active:
		multiplier *= lerpf(1.0, dance_damage_multiplier, _dance_window_intensity)
	if _player_recently_slinged():
		multiplier *= slingshot_jam_multiplier
	return multiplier


func _player_recently_slinged() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var time_value: Variant = player.get("last_slingshot_time")
	var score_value: Variant = player.get("last_slingshot_score")
	if not (typeof(time_value) == TYPE_FLOAT or typeof(time_value) == TYPE_INT):
		return false
	if not (typeof(score_value) == TYPE_FLOAT or typeof(score_value) == TYPE_INT):
		return false
	return Time.get_ticks_msec() / 1000.0 - float(time_value) < 1.35 and float(score_value) >= 0.58


func _reward_skill_hit() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_skill_reward_time < 0.18:
		return
	_last_skill_reward_time = now
	if player != null and is_instance_valid(player):
		var energy := player.get_node_or_null("EnergyComponent")
		if energy != null and energy.has_method("restore"):
			energy.call("restore", skill_hit_energy_reward * (1.0 + _dance_window_intensity))
	_spawn_skill_hit_ring()


func _phase_speed_multiplier() -> float:
	if _black_hole_mode_active:
		return 1.52
	return 1.0 + float(_phase) * 0.16


func _phase_charge_multiplier() -> float:
	if _black_hole_mode_active:
		return 0.58
	return lerpf(1.0, 0.72, float(_phase) / 3.0)


func _black_hole_gravity_constant() -> float:
	return 230.0 + float(_phase) * 34.0 if _black_hole_mode_active else 90.0 + float(_phase) * 28.0


func _pulse_charge_ratio() -> float:
	if not _is_charging_pulse:
		return 0.0
	return clampf(_pulse_charge_elapsed / maxf(pulse_charge_time * _phase_charge_multiplier(), 0.05), 0.0, 1.0)


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


func _resolve_particles() -> GPUParticles2D:
	var direct := get_node_or_null("GPUParticles2D") as GPUParticles2D
	if direct != null:
		return direct
	return get_node_or_null("GPUParticles2D3") as GPUParticles2D


func _register_runtime_groups() -> void:
	if RuntimeRegistry == null:
		return
	RuntimeRegistry.register_node(self, &"enemies")
	RuntimeRegistry.register_node(self, &"ParametricEnemies")
	RuntimeRegistry.register_node(self, &"rare_enemy")
	RuntimeRegistry.register_node(self, &"elite")
	RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
	RuntimeRegistry.register_node(self, &"planets")


func _unregister_runtime_groups() -> void:
	if RuntimeRegistry == null:
		return
	RuntimeRegistry.unregister_node(self, &"enemies")
	RuntimeRegistry.unregister_node(self, &"ParametricEnemies")
	RuntimeRegistry.unregister_node(self, &"rare_enemy")
	RuntimeRegistry.unregister_node(self, &"elite")
	RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
	RuntimeRegistry.unregister_node(self, &"planets")


func _pulse_color(alpha: float) -> Color:
	var base := rupture_color if _pulse_mode == PulseMode.REPULSION else charge_color
	return _safe_color(base, alpha)


func _phase_color(alpha: float) -> Color:
	var color := rare_core_color
	match _phase:
		0:
			color = calm_color
		1:
			color = Color(0.36, 1.0, 0.72, 1.0)
		2:
			color = Color(1.0, 0.62, 0.18, 1.0)
		_:
			color = rupture_color
	return _safe_color(color, alpha)


func _safe_color(color: Color, alpha: float) -> Color:
	var adjusted := color
	if Settings != null and Settings.has_method("apply_readability_color"):
		adjusted = Settings.apply_readability_color(adjusted)
	return Color(adjusted.r, adjusted.g, adjusted.b, _safe_alpha(alpha))


func _safe_alpha(alpha: float) -> float:
	var capped := minf(alpha, transient_alpha_cap if alpha < 1.0 else 1.0)
	if Settings != null and Settings.has_method("world_visual_alpha") and alpha < 1.0:
		return Settings.world_visual_alpha(capped, transient_alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha") and alpha < 1.0:
		return minf(Settings.flash_alpha(capped), transient_alpha_cap)
	return capped


func _health_ratio_from_values(current_health: Variant, max_health_value: Variant) -> float:
	var current := _numeric_value(current_health, max_health)
	var maximum := maxf(_numeric_value(max_health_value, max_health), 1.0)
	return clampf(current / maximum, 0.0, 1.0)


func _numeric_value(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback


func _visual_segments(default_count: int) -> int:
	if Settings != null and Settings.has_method("world_polygon_segments"):
		return int(Settings.world_polygon_segments(default_count, default_count))
	return clampi(default_count, 8, 128)


func _set_circle_line(line: Line2D, radius: float, count: int) -> void:
	line.points = _circle_points(count, radius)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 3)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _black_hole_ring_points(radius: float, count: int, wobble: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 8)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		var radius_offset := 1.0 + sin(angle * 5.0 + _black_hole_visual_time * 4.0) * wobble
		points.append(Vector2(cos(angle), sin(angle)) * radius * radius_offset)
	return points


func _rose_points(count: int, radius: float, petals: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 16)
	var safe_petals := maxi(petals, 2)
	for i in range(safe_count):
		var t := TAU * float(i) / float(safe_count)
		var r := radius * (0.42 + 0.58 * absf(cos(float(safe_petals) * t)))
		points.append(Vector2(cos(t), sin(t)) * r)
	return points


func _world_effect_radius(value: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(value, hard_cap)
	return clampf(value, 0.0, maxf(hard_cap, 1.0))


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()
