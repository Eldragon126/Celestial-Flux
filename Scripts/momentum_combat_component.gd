extends Node2D
class_name MomentumCombatComponent

# Player add-on for slingshot momentum combat.
# It turns high-speed orbital movement into combat pressure without replacing
# player.gd movement. The component samples nearby gravity, rewards clean
# near-misses, prepares shots with velocity-scaled damage, and creates a
# conservative kinetic impact zone around the player.
#
# Known limitation: orbit detection is intentionally heuristic. It favors
# readable boosts and stable speed caps over physically exact orbital mechanics.

signal momentum_state_changed(state: StringName, speed_ratio: float)
signal orbit_charge_changed(charge: float)
signal orbit_escape_boost_applied(boost: float, charge_spent: float)
signal near_miss_velocity_gained(target: Node, amount: float)
signal kinetic_overload_started(speed: float)
signal kinetic_overload_ended(speed: float)
signal kinetic_impact_dealt(target: Node, damage: float, speed: float)
signal momentum_projectile_prepared(projectile: Node, damage_multiplier: float, inherited_speed: float)

@export var enabled: bool = true

@export_group("Projectile Momentum")
@export var projectile_speed_damage_start: float = 650.0
@export var projectile_speed_damage_full: float = 1750.0
@export var projectile_max_damage_multiplier: float = 2.15
@export var projectile_velocity_inherit: float = 0.34
@export var projectile_max_inherited_speed: float = 520.0
@export var overload_projectile_damage_bonus: float = 0.35

@export_group("Orbit Assist")
@export var orbit_assist_enabled: bool = true
@export var orbit_assist_radius: float = 620.0
@export var orbit_min_distance: float = 95.0
@export var orbit_min_tangential_speed: float = 420.0
@export var orbit_charge_rate: float = 0.42
@export var orbit_charge_decay: float = 0.38
@export var orbit_escape_radial_speed: float = 190.0
@export var orbit_escape_min_charge: float = 0.34
@export var orbit_escape_boost_min: float = 160.0
@export var orbit_escape_boost_max: float = 540.0
@export var orbit_escape_cooldown: float = 0.85

@export_group("Near Miss")
@export var near_miss_enabled: bool = true
@export var near_miss_scan_interval: float = 0.08
@export var near_miss_radius: float = 82.0
@export var near_miss_inner_deadzone: float = 28.0
@export var near_miss_min_speed: float = 540.0
@export var near_miss_side_dot: float = 0.52
@export var near_miss_velocity_gain: float = 95.0
@export var near_miss_time_charge: float = 6.0
@export var near_miss_cooldown: float = 0.7
@export var max_near_miss_targets_per_scan: int = 36
@export var max_near_miss_grants_per_scan: int = 3

@export_group("Kinetic Impact")
@export var kinetic_impact_enabled: bool = true
@export var kinetic_impact_radius: float = 58.0
@export var kinetic_impact_min_speed: float = 760.0
@export var kinetic_impact_full_speed: float = 1850.0
@export var kinetic_impact_damage_min: float = 10.0
@export var kinetic_impact_damage_max: float = 46.0
@export var kinetic_impact_cooldown: float = 0.42
@export var kinetic_impact_player_boost: float = 58.0
@export var kinetic_impact_target_knockback: float = 380.0

@export_group("Kinetic Overload")
@export var overload_enter_speed: float = 1450.0
@export var overload_exit_speed: float = 1120.0
@export var overload_speed_cap_bonus: float = 820.0
@export var overload_near_miss_bonus_multiplier: float = 1.35

@export_group("Momentum Preservation")
@export var speed_cap_bonus_decay: float = 640.0
@export var orbit_speed_cap_bonus: float = 420.0
@export var near_miss_speed_cap_bonus: float = 180.0
@export var impact_speed_cap_bonus: float = 260.0

@export_group("Performance")
@export var gravity_source_refresh_interval: float = 0.28

@export_group("Debug Visual")
@export var enable_local_visual: bool = true
@export var visual_radius: float = 76.0

var _player: CharacterBody2D = null
var _impact_area: Area2D = null
var _impact_shape: CollisionShape2D = null
var _overload_ring: Polygon2D = null
var _time_dilation_manager: Node = null

var _orbit_charge: float = 0.0
var _speed_cap_bonus: float = 0.0
var _near_miss_elapsed: float = 0.0
var _last_escape_time: float = -999.0
var _recent_slingshot_time: float = -999.0
var _recent_slingshot_strength: float = 0.0
var _last_state: StringName = &"stable"
var _overload_active: bool = false
var _was_orbiting: bool = false
var _orbit_source_id: int = 0

var _near_miss_cooldowns: Dictionary = {}
var _impact_cooldowns: Dictionary = {}
var _gravity_sources: Array[Node2D] = []
var _gravity_source_refresh_elapsed: float = 999.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		set_physics_process(false)
		return

	_build_impact_area()
	_build_local_visual()
	_connect_player_signals()
	_resolve_optional_managers()
	_refresh_gravity_sources(true)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(_player):
		return

	_gravity_source_refresh_elapsed += delta
	_resolve_optional_managers()
	_refresh_gravity_sources(false)
	_update_orbit_assist(delta)
	_update_near_misses(delta)
	_update_kinetic_overload()
	_update_speed_cap(delta)
	_update_local_visual()
	_emit_state_if_changed()

func prepare_projectile(projectile: Node, direction: Vector2) -> void:
	if projectile == null or not enabled or not is_instance_valid(_player):
		return

	var shot_dir := direction.normalized()
	if shot_dir == Vector2.ZERO:
		shot_dir = Vector2.RIGHT.rotated(_player.global_rotation)

	var player_velocity := _get_player_velocity()
	var forward_speed := maxf(player_velocity.dot(shot_dir), 0.0)
	var inherited_speed := minf(forward_speed * projectile_velocity_inherit, projectile_max_inherited_speed)
	var damage_multiplier := _get_projectile_damage_multiplier(player_velocity.length())

	if projectile.get("initial_speed") != null:
		projectile.set("initial_speed", float(projectile.get("initial_speed")) + inherited_speed)

	projectile.set_meta(&"momentum_damage_multiplier", damage_multiplier)
	projectile.set_meta(&"momentum_source_speed", player_velocity.length())
	projectile.set_meta(&"momentum_state", _current_state())

	momentum_projectile_prepared.emit(projectile, damage_multiplier, inherited_speed)

func get_momentum_damage_multiplier() -> float:
	return _get_projectile_damage_multiplier(_get_player_velocity().length())

func get_momentum_debug_state() -> Dictionary:
	var velocity := _get_player_velocity()
	return {
		"state": _current_state(),
		"speed": velocity.length(),
		"damage_multiplier": _get_projectile_damage_multiplier(velocity.length()),
		"orbit_charge": _orbit_charge,
		"speed_cap_bonus": _speed_cap_bonus,
		"overload": _overload_active,
	}

func _build_impact_area() -> void:
	if not kinetic_impact_enabled:
		return

	_impact_area = Area2D.new()
	_impact_area.name = "KineticImpactArea"
	_impact_area.monitoring = true
	_impact_area.monitorable = false
	_impact_area.body_entered.connect(_on_impact_area_body_entered)
	add_child(_impact_area)

	_impact_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = kinetic_impact_radius
	_impact_shape.shape = circle
	_impact_area.add_child(_impact_shape)

func _build_local_visual() -> void:
	if not enable_local_visual:
		return

	_overload_ring = Polygon2D.new()
	_overload_ring.name = "MomentumOverloadRing"
	_overload_ring.z_index = -1
	_overload_ring.visible = false
	_overload_ring.polygon = _ring_points(40, visual_radius, visual_radius + 9.0)
	_overload_ring.color = Color(0.0, 0.95, 1.0, 0.0)
	add_child(_overload_ring)

func _connect_player_signals() -> void:
	if _player.has_signal("slingshot_assist_applied"):
		var callable := Callable(self, "_on_player_slingshot_assist_applied")
		if not _player.is_connected("slingshot_assist_applied", callable):
			_player.connect("slingshot_assist_applied", callable)

func _update_orbit_assist(delta: float) -> void:
	if not orbit_assist_enabled:
		_decay_orbit_charge(delta)
		return

	var source := _find_nearest_gravity_source()
	if source == null:
		_try_apply_escape_boost(null)
		_decay_orbit_charge(delta)
		_was_orbiting = false
		return

	var offset := _player.global_position - source.global_position
	var distance := offset.length()
	if distance < orbit_min_distance or distance > orbit_assist_radius:
		_try_apply_escape_boost(source)
		_decay_orbit_charge(delta)
		_was_orbiting = false
		return

	var velocity := _get_player_velocity()
	var speed := velocity.length()
	var radial := offset / maxf(distance, 0.001)
	var tangent := radial.orthogonal()
	var tangential_speed := absf(velocity.dot(tangent))
	var radial_speed := velocity.dot(radial)
	var orbiting := speed >= orbit_min_tangential_speed and tangential_speed >= orbit_min_tangential_speed

	if orbiting:
		var tangent_ratio := clampf(tangential_speed / maxf(overload_enter_speed, orbit_min_tangential_speed), 0.0, 1.0)
		_orbit_charge = clampf(_orbit_charge + orbit_charge_rate * tangent_ratio * delta, 0.0, 1.0)
		_speed_cap_bonus = maxf(_speed_cap_bonus, orbit_speed_cap_bonus * _orbit_charge)
		_was_orbiting = true
		_orbit_source_id = source.get_instance_id()
		orbit_charge_changed.emit(_orbit_charge)
	else:
		_decay_orbit_charge(delta)

	if _was_orbiting and radial_speed >= orbit_escape_radial_speed and _orbit_charge >= orbit_escape_min_charge:
		_try_apply_escape_boost(source)

func _on_player_slingshot_assist_applied(source: Node, _gravity: Vector2, _impulse: Vector2, assist_strength: float, speed: float) -> void:
	if not enabled or not orbit_assist_enabled:
		return

	var source_2d := source as Node2D
	if source_2d == null:
		return

	_recent_slingshot_time = _now_seconds()
	_recent_slingshot_strength = assist_strength
	var strength_ratio := clampf(assist_strength / maxf(overload_enter_speed, 1.0), 0.0, 1.0)
	var speed_ratio := clampf(speed / maxf(overload_enter_speed, 1.0), 0.0, 1.0)
	_orbit_charge = clampf(_orbit_charge + 0.08 + 0.22 * maxf(strength_ratio, speed_ratio), 0.0, 1.0)
	_speed_cap_bonus = maxf(_speed_cap_bonus, orbit_speed_cap_bonus * (0.35 + _orbit_charge))
	_was_orbiting = true
	_orbit_source_id = source_2d.get_instance_id()
	orbit_charge_changed.emit(_orbit_charge)

func _try_apply_escape_boost(source: Node2D) -> void:
	if not _was_orbiting or _orbit_charge < orbit_escape_min_charge:
		return

	var now := _now_seconds()
	if now - _last_escape_time < orbit_escape_cooldown:
		return

	if source != null and _orbit_source_id != 0 and source.get_instance_id() != _orbit_source_id:
		return

	var velocity := _get_player_velocity()
	if velocity.length() < orbit_min_tangential_speed:
		return

	var charge_spent := _orbit_charge
	var boost := lerpf(orbit_escape_boost_min, orbit_escape_boost_max, clampf(charge_spent, 0.0, 1.0))
	_set_player_velocity(velocity + velocity.normalized() * boost)
	_speed_cap_bonus = maxf(_speed_cap_bonus, boost + orbit_speed_cap_bonus * charge_spent)
	_orbit_charge = 0.0
	_last_escape_time = now
	_was_orbiting = false

	orbit_escape_boost_applied.emit(boost, charge_spent)
	orbit_charge_changed.emit(_orbit_charge)

func _update_near_misses(delta: float) -> void:
	if not near_miss_enabled:
		return

	_near_miss_elapsed += delta
	if _near_miss_elapsed < maxf(near_miss_scan_interval, 0.03):
		return

	_near_miss_elapsed = 0.0
	_cleanup_cooldowns(_near_miss_cooldowns)

	var velocity := _get_player_velocity()
	var speed := velocity.length()
	if speed < near_miss_min_speed:
		return

	var velocity_dir := velocity / maxf(speed, 0.001)
	var granted := 0
	var checked := 0
	var radius_squared := near_miss_radius * near_miss_radius
	var inner_squared := near_miss_inner_deadzone * near_miss_inner_deadzone

	for target in _near_miss_targets():
		if checked >= max_near_miss_targets_per_scan or granted >= max_near_miss_grants_per_scan:
			break

		var target_2d := target as Node2D
		if target_2d == null or not is_instance_valid(target_2d) or target_2d == _player:
			continue

		checked += 1
		var offset := target_2d.global_position - _player.global_position
		var distance_squared := offset.length_squared()
		if distance_squared > radius_squared or distance_squared < inner_squared:
			continue

		var side_dot := absf(velocity_dir.dot(offset.normalized()))
		if side_dot > near_miss_side_dot:
			continue

		var id := target_2d.get_instance_id()
		if _near_miss_cooldowns.has(id):
			continue

		var closeness := 1.0 - sqrt(distance_squared) / near_miss_radius
		var speed_ratio := clampf((speed - near_miss_min_speed) / maxf(overload_enter_speed - near_miss_min_speed, 1.0), 0.0, 1.0)
		var overload_bonus := overload_near_miss_bonus_multiplier if _overload_active else 1.0
		var gain := near_miss_velocity_gain * (0.55 + closeness) * (0.75 + speed_ratio) * overload_bonus

		_set_player_velocity(velocity + velocity_dir * gain)
		_speed_cap_bonus = maxf(_speed_cap_bonus, near_miss_speed_cap_bonus + gain)
		_near_miss_cooldowns[id] = _now_seconds() + near_miss_cooldown
		_grant_time_dilation_charge()
		near_miss_velocity_gained.emit(target_2d, gain)

		velocity = _get_player_velocity()
		speed = velocity.length()
		velocity_dir = velocity / maxf(speed, 0.001)
		granted += 1

func _update_kinetic_overload() -> void:
	var speed := _get_player_velocity().length()
	if not _overload_active and speed >= overload_enter_speed:
		_overload_active = true
		_speed_cap_bonus = maxf(_speed_cap_bonus, overload_speed_cap_bonus)
		kinetic_overload_started.emit(speed)
	elif _overload_active and speed <= overload_exit_speed:
		_overload_active = false
		kinetic_overload_ended.emit(speed)

func _update_speed_cap(delta: float) -> void:
	var current_speed := _get_player_velocity().length()
	var current_cap := _safe_float(_player.get("current_max_speed"), _safe_float(_player.get("max_speed"), 800.0))
	var base_cap := maxf(_safe_float(_player.get("max_speed"), 800.0), current_cap)

	if _overload_active:
		_speed_cap_bonus = maxf(_speed_cap_bonus, overload_speed_cap_bonus)

	if _speed_cap_bonus > 0.0:
		_speed_cap_bonus = maxf(_speed_cap_bonus - speed_cap_bonus_decay * delta, 0.0)
		var desired_cap := maxf(base_cap + _speed_cap_bonus, current_speed + 80.0)
		_player.set("current_max_speed", maxf(current_cap, desired_cap))

func _update_local_visual() -> void:
	if _overload_ring == null:
		return

	var visible_amount := maxf(_orbit_charge * 0.7, 1.0 if _overload_active else 0.0)
	_overload_ring.visible = visible_amount > 0.04
	_overload_ring.rotation += get_physics_process_delta_time() * lerpf(1.2, 5.4, visible_amount)
	_overload_ring.color = Color(0.0, 0.95, 1.0, lerpf(0.0, 0.46, clampf(visible_amount, 0.0, 1.0)))
	_overload_ring.scale = Vector2.ONE * lerpf(0.86, 1.22, clampf(visible_amount, 0.0, 1.0))

func _on_impact_area_body_entered(body: Node) -> void:
	if not enabled or not kinetic_impact_enabled or body == _player:
		return
	if not _is_valid_impact_target(body):
		return

	var speed := _get_player_velocity().length()
	if speed < kinetic_impact_min_speed:
		return

	var id := body.get_instance_id()
	if _impact_cooldowns.has(id):
		return

	var speed_ratio := clampf((speed - kinetic_impact_min_speed) / maxf(kinetic_impact_full_speed - kinetic_impact_min_speed, 1.0), 0.0, 1.0)
	var damage := lerpf(kinetic_impact_damage_min, kinetic_impact_damage_max, speed_ratio)
	if _overload_active:
		damage *= 1.25

	if body.has_method("take_damage"):
		body.call("take_damage", damage)

	var target_2d := body as Node2D
	if target_2d != null:
		var push_dir := (target_2d.global_position - _player.global_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = _get_player_velocity().normalized()
		CombatStatus.add_velocity(body, push_dir * kinetic_impact_target_knockback * (0.5 + speed_ratio))

	var player_velocity := _get_player_velocity()
	if player_velocity.length() > 0.01:
		_set_player_velocity(player_velocity + player_velocity.normalized() * kinetic_impact_player_boost)

	_speed_cap_bonus = maxf(_speed_cap_bonus, impact_speed_cap_bonus)
	_impact_cooldowns[id] = _now_seconds() + kinetic_impact_cooldown
	_cleanup_cooldowns(_impact_cooldowns)
	kinetic_impact_dealt.emit(body, damage, speed)

func _find_nearest_gravity_source() -> Node2D:
	var best: Node2D = null
	var best_distance_squared := orbit_assist_radius * orbit_assist_radius

	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source == _player:
			continue

		var distance_squared := source.global_position.distance_squared_to(_player.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = source

	return best

func _refresh_gravity_sources(force: bool) -> void:
	if _player == null:
		return
	if not force and _gravity_source_refresh_elapsed < maxf(gravity_source_refresh_interval, 0.05):
		return

	_gravity_source_refresh_elapsed = 0.0
	_gravity_sources.clear()
	var seen := {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d := source as Node2D
			if source_2d == null or source_2d == _player or not is_instance_valid(source_2d):
				continue

			var id := source_2d.get_instance_id()
			if seen.has(id):
				continue

			seen[id] = true
			_gravity_sources.append(source_2d)

	_gravity_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)

	if _gravity_sources.size() > 10:
		_gravity_sources.resize(10)

func _near_miss_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var seen := {}
	var radius_squared := near_miss_radius * near_miss_radius

	for group_name in [&"enemies", &"enemy_projectiles"]:
		for target in get_tree().get_nodes_in_group(group_name):
			var target_2d := target as Node2D
			if target_2d == null or target_2d == _player or not is_instance_valid(target_2d):
				continue

			var id := target_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			if target_2d.global_position.distance_squared_to(_player.global_position) > radius_squared:
				continue

			targets.append(target_2d)

	targets.sort_custom(func(a: Node, b: Node) -> bool:
		var a_2d := a as Node2D
		var b_2d := b as Node2D
		if a_2d == null:
			return false
		if b_2d == null:
			return true
		return a_2d.global_position.distance_squared_to(_player.global_position) < b_2d.global_position.distance_squared_to(_player.global_position)
	)

	if max_near_miss_targets_per_scan > 0 and targets.size() > max_near_miss_targets_per_scan:
		targets.resize(max_near_miss_targets_per_scan)

	return targets

func _grant_time_dilation_charge() -> void:
	if _time_dilation_manager != null and _time_dilation_manager.has_method("add_near_miss_charge"):
		_time_dilation_manager.call("add_near_miss_charge", near_miss_time_charge)

func _resolve_optional_managers() -> void:
	if _time_dilation_manager != null and is_instance_valid(_time_dilation_manager):
		return

	var root := get_tree().current_scene
	if root == null:
		return

	_time_dilation_manager = root.find_child("TimeDilationManager", true, false)

func _emit_state_if_changed() -> void:
	var state := _current_state()
	if state == _last_state:
		return

	_last_state = state
	var speed_ratio := clampf(_get_player_velocity().length() / maxf(overload_enter_speed, 1.0), 0.0, 2.0)
	momentum_state_changed.emit(state, speed_ratio)

func _current_state() -> StringName:
	if _overload_active:
		return &"kinetic_overload"
	if _orbit_charge >= orbit_escape_min_charge:
		return &"charged_orbit"
	if _orbit_charge > 0.05:
		return &"orbit_building"
	if _get_player_velocity().length() >= near_miss_min_speed:
		return &"fast"
	return &"stable"

func _get_projectile_damage_multiplier(speed: float) -> float:
	var ratio := clampf((speed - projectile_speed_damage_start) / maxf(projectile_speed_damage_full - projectile_speed_damage_start, 1.0), 0.0, 1.0)
	var multiplier := lerpf(1.0, projectile_max_damage_multiplier, ratio)
	if _overload_active:
		multiplier += overload_projectile_damage_bonus
	return clampf(multiplier, 1.0, projectile_max_damage_multiplier + overload_projectile_damage_bonus)

func _is_valid_impact_target(body: Node) -> bool:
	return (
		body.has_method("take_damage")
		and (
			body.is_in_group("enemies")
			or body.is_in_group("wave_enemy")
			or body.is_in_group("bosses")
		)
	)

func _decay_orbit_charge(delta: float) -> void:
	if _orbit_charge <= 0.0:
		return

	_orbit_charge = maxf(_orbit_charge - orbit_charge_decay * delta, 0.0)
	orbit_charge_changed.emit(_orbit_charge)

func _cleanup_cooldowns(cooldowns: Dictionary) -> void:
	var now := _now_seconds()
	var expired: Array = []
	for id in cooldowns.keys():
		if float(cooldowns[id]) <= now:
			expired.append(id)

	for id in expired:
		cooldowns.erase(id)

func _get_player_velocity() -> Vector2:
	if _player == null:
		return Vector2.ZERO

	var value: Variant = _player.get("velocity")
	if value is Vector2:
		return value
	return Vector2.ZERO

func _set_player_velocity(value: Vector2) -> void:
	if _player != null:
		_player.set("velocity", value)

func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback

func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ring_points(count: int, inner_radius: float, outer_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	return points
