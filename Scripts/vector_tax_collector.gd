extends CharacterBody2D
class_name VectorTaxCollector

signal momentum_absorbed(amount: float, stored_momentum: float)
signal momentum_released(release_data: Dictionary)

enum CollectorState { HOVER, TELEGRAPH, RELEASE, RECOVER }

const RELEASE_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses"]
const DEATH_EXPLOSION_GROUPS: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses"]

@export var max_health: float = 106.0
@export var detection_radius: float = 560.0
@export var momentum_absorption_rate: float = 0.16
@export var charge_threshold: float = 310.0
@export var max_stored_momentum: float = 760.0
@export var release_cooldown: float = 3.8
@export var explosion_radius: float = 360.0
@export var explosion_damage: float = 44.0

@export_group("Release Attack")
@export var momentum_spike_threshold: float = 165.0
@export var telegraph_time: float = 0.86
@export var release_dash_speed: float = 860.0
@export var release_duration: float = 0.72
@export var release_damage: float = 18.0
@export var hover_acceleration: float = 430.0
@export var hover_max_speed: float = 320.0
@export var max_targets_per_burst: int = 34

var stored_momentum: float = 0.0

var _player: Node2D = null
var _health: HealthComponent = null
var _state: int = CollectorState.HOVER
var _state_elapsed: float = 0.0
var _cooldown_remaining: float = 1.4
var _last_player_velocity: Vector2 = Vector2.ZERO
var _has_player_velocity_sample: bool = false
var _release_direction: Vector2 = Vector2.RIGHT
var _release_hit_ids: Dictionary = {}
var _targets: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}
var _core: Polygon2D = null
var _glow: Polygon2D = null
var _ring: Line2D = null
var _warning_line: Line2D = null
var _particles: GPUParticles2D = null
var _attack_area: Area2D = null


func _ready() -> void:
	add_to_group("enemies")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
	_cleanup_warning_line()


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_detect_momentum_burst()
	if _state == CollectorState.HOVER and stored_momentum >= charge_threshold and _cooldown_remaining <= 0.0:
		_begin_release_telegraph()
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		_has_player_velocity_sample = false
		return

	match _state:
		CollectorState.HOVER:
			_hover_near_player(scaled_delta)
		CollectorState.TELEGRAPH:
			_state_elapsed += delta
			velocity = velocity.move_toward(Vector2.ZERO, hover_acceleration * 1.8 * scaled_delta)
			move_and_slide()
			_update_warning_line()
			if _state_elapsed >= telegraph_time:
				_begin_release_dash()
		CollectorState.RELEASE:
			_state_elapsed += scaled_delta
			velocity = _release_direction * (release_dash_speed + stored_momentum * 0.58)
			move_and_slide()
			if _state_elapsed >= release_duration:
				_emit_release_shockwave()
				_finish_release()
		CollectorState.RECOVER:
			_state_elapsed += delta
			velocity = velocity.move_toward(Vector2.ZERO, hover_acceleration * 2.2 * scaled_delta)
			move_and_slide()
			if _state_elapsed >= 0.55:
				_state = CollectorState.HOVER
				_state_elapsed = 0.0


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _detect_momentum_burst() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_velocity := _body_velocity(_player)
	if not _has_player_velocity_sample:
		_last_player_velocity = player_velocity
		_has_player_velocity_sample = true
		return
	if global_position.distance_squared_to(_player.global_position) > detection_radius * detection_radius:
		_last_player_velocity = player_velocity
		return

	var velocity_delta := player_velocity - _last_player_velocity
	var speed_gain := player_velocity.length() - _last_player_velocity.length()
	if speed_gain > momentum_spike_threshold * 0.42 and velocity_delta.length() >= momentum_spike_threshold:
		var absorbed := velocity_delta.length() * momentum_absorption_rate
		stored_momentum = clampf(stored_momentum + absorbed, 0.0, max_stored_momentum)
		CombatStatus.add_velocity(_player, -velocity_delta * clampf(momentum_absorption_rate * 0.32, 0.0, 0.12))
		momentum_absorbed.emit(absorbed, stored_momentum)
	_last_player_velocity = _body_velocity(_player)


func _hover_near_player(delta: float) -> void:
	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.001:
		return
	var tangent := to_player.normalized().orthogonal()
	var desired := tangent * hover_max_speed * 0.52
	if distance > detection_radius * 0.74:
		desired += to_player.normalized() * hover_max_speed
	elif distance < detection_radius * 0.34:
		desired -= to_player.normalized() * hover_max_speed * 0.82
	var charge_ratio := _charge_ratio()
	velocity = velocity.move_toward(desired.limit_length(hover_max_speed * (1.0 + charge_ratio * 0.24)), hover_acceleration * delta)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 6.0, 0.0, 1.0))


func _begin_release_telegraph() -> void:
	var player_velocity := _body_velocity(_player)
	var predicted := _player.global_position + player_velocity * telegraph_time * 0.28
	_release_direction = (predicted - global_position).normalized()
	if _release_direction.length_squared() <= 0.001:
		_release_direction = Vector2.RIGHT.rotated(rotation)
	_state = CollectorState.TELEGRAPH
	_state_elapsed = 0.0
	_release_hit_ids.clear()
	_ensure_warning_line()
	_update_warning_line()


func _begin_release_dash() -> void:
	_state = CollectorState.RELEASE
	_state_elapsed = 0.0
	_release_hit_ids.clear()
	if _attack_area != null:
		_attack_area.monitoring = true
	_cleanup_warning_line()
	momentum_released.emit({
		"position": global_position,
		"direction": _release_direction,
		"stored_momentum": stored_momentum,
		"speed": release_dash_speed + stored_momentum * 0.58,
	})


func _finish_release() -> void:
	stored_momentum *= 0.18
	_cooldown_remaining = release_cooldown
	_state = CollectorState.RECOVER
	_state_elapsed = 0.0
	velocity *= 0.24


func _emit_release_shockwave() -> void:
	var radius := lerpf(explosion_radius * 0.44, explosion_radius, _charge_ratio())
	var damage_amount := release_damage + explosion_damage * 0.38 * _charge_ratio()
	_damage_targets(RELEASE_TARGET_GROUPS, global_position, radius, damage_amount, true, false)
	_spawn_ring_burst(global_position, radius, _debt_color(0.56))


func _charged_death_explosion() -> void:
	if stored_momentum <= charge_threshold * 0.18:
		return
	var ratio := _charge_ratio()
	var radius := lerpf(explosion_radius * 0.58, explosion_radius * 1.18, ratio)
	var damage_amount := explosion_damage * lerpf(0.42, 1.35, ratio)
	_damage_targets(DEATH_EXPLOSION_GROUPS, global_position, radius, damage_amount, false, true)
	_spawn_ring_burst(global_position, radius, Color(0.36, 1.0, 0.64, Settings.world_visual_alpha(0.62, 0.34)))


func _damage_targets(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	damage_amount: float,
	include_player: bool,
	enemies_only: bool
) -> void:
	_fill_targets_in_radius(groups, center, radius, max_targets_per_burst, include_player, _targets)
	for target in _targets:
		if target == null or not is_instance_valid(target) or target == self or target.is_queued_for_deletion():
			continue
		if enemies_only and not (target.is_in_group("enemies") or target.is_in_group("wave_enemy") or target.is_in_group("bosses")):
			continue
		var offset := target.global_position - center
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / maxf(radius, 1.0), 0.0, 1.0)
		if target.has_method("take_damage"):
			target.call("take_damage", damage_amount * (0.35 + 0.65 * falloff))
		CombatStatus.add_velocity(target, offset.normalized() * lerpf(240.0, 720.0, falloff) * (0.65 + _charge_ratio()))


func _fill_targets_in_radius(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	limit: int,
	include_player: bool,
	out_targets: Array[Node2D]
) -> void:
	out_targets.clear()
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


func _build_body() -> void:
	_glow = Polygon2D.new()
	_glow.name = "DebtGlow"
	_glow.z_index = -2
	_glow.color = _debt_color(0.13)
	_glow.polygon = _circle_points(36, 72.0)
	add_child(_glow)

	_core = Polygon2D.new()
	_core.name = "TaxCollectorCore"
	_core.color = _debt_color(1.0)
	_core.polygon = PackedVector2Array([
		Vector2(0.0, -42.0),
		Vector2(38.0, -12.0),
		Vector2(24.0, 36.0),
		Vector2(-24.0, 36.0),
		Vector2(-38.0, -12.0),
	])
	add_child(_core)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)

	_ring = Line2D.new()
	_ring.name = "DebtDetectionRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.0
	_ring.points = _circle_points(64, detection_radius)
	_ring.default_color = _debt_color(0.2)
	add_child(_ring)

	_particles = GPUParticles2D.new()
	_particles.name = "DebtParticles"
	_particles.z_index = -1
	_particles.amount = 42
	_particles.lifetime = 1.2
	_particles.randomness = 0.42
	_particles.process_material = _make_particle_material()
	add_child(_particles)

	_attack_area = Area2D.new()
	_attack_area.name = "ReleaseRamArea"
	_attack_area.monitoring = true
	_attack_area.body_entered.connect(_on_release_area_body_entered)
	var shape := CollisionShape2D.new()
	shape.name = "ReleaseRamShape"
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	_attack_area.add_child(shape)
	add_child(_attack_area)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _ensure_warning_line() -> void:
	if _warning_line != null and is_instance_valid(_warning_line):
		return
	_warning_line = Line2D.new()
	_warning_line.name = "VectorTaxCollectorReleaseWarning"
	_warning_line.z_index = 34
	_warning_line.antialiased = true
	_warning_line.width = 6.0
	_add_effect_node(_warning_line)


func _update_warning_line() -> void:
	if _warning_line == null or not is_instance_valid(_warning_line):
		return
	var end := global_position + _release_direction * (520.0 + stored_momentum * 0.28)
	var ratio := clampf(_state_elapsed / maxf(telegraph_time, 0.001), 0.0, 1.0)
	_warning_line.points = PackedVector2Array([global_position, end])
	_warning_line.width = lerpf(4.0, 13.0, ratio)
	_warning_line.default_color = _debt_color(lerpf(0.18, 0.58, ratio))


func _update_visuals(delta: float) -> void:
	var ratio := _charge_ratio()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
	if _core != null:
		_core.rotation += delta * (0.9 + ratio * 2.6)
		_core.scale = Vector2.ONE * (1.0 + ratio * 0.2 + pulse * ratio * 0.08)
		_core.color = _debt_color(0.78 + ratio * 0.22)
	if _glow != null:
		_glow.scale = Vector2.ONE * (1.0 + ratio * 0.9 + pulse * ratio * 0.18)
		_glow.color = _debt_color(Settings.world_visual_alpha(0.08 + ratio * 0.24, 0.24))
	if _ring != null:
		_ring.rotation -= delta * (0.42 + ratio * 1.8)
		_ring.width = 1.4 + ratio * 4.4
		_ring.default_color = _debt_color(Settings.world_visual_alpha(0.12 + ratio * 0.34, 0.32))
	if _particles != null:
		_particles.emitting = ratio > 0.04
		_particles.speed_scale = 0.55 + ratio * 2.2


func _on_release_area_body_entered(body: Node) -> void:
	if _state != CollectorState.RELEASE or body == null or body == self or not is_instance_valid(body):
		return
	var id := body.get_instance_id()
	if _release_hit_ids.has(id):
		return
	_release_hit_ids[id] = true
	if not (body.is_in_group("Player") or body.is_in_group("enemies") or body.is_in_group("wave_enemy") or body.is_in_group("bosses")):
		return
	var hit_damage := release_damage + explosion_damage * 0.55 * _charge_ratio()
	if body.has_method("take_damage"):
		body.call("take_damage", hit_damage)
	CombatStatus.add_velocity(body, _release_direction * (release_dash_speed * 0.42 + stored_momentum * 0.52))


func _on_died() -> void:
	_charged_death_explosion()
	_cleanup_warning_line()
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.16, true)
	queue_free()


func _charge_ratio() -> float:
	return clampf(stored_momentum / maxf(max_stored_momentum, 1.0), 0.0, 1.0)


func _debt_color(alpha: float) -> Color:
	return Settings.apply_readability_color(Color(0.32, 1.0, 0.68, alpha))


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


func _make_particle_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 42.0
	material.spread = 180.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 84.0
	material.orbit_velocity_min = 0.2
	material.orbit_velocity_max = 1.2
	material.gravity = Vector3.ZERO
	material.scale_min = 1.2
	material.scale_max = 4.2
	material.color = _debt_color(0.72)
	return material


func _spawn_ring_burst(position: Vector2, radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.name = "VectorTaxMomentumBurst"
	ring.z_index = 42
	ring.closed = true
	ring.antialiased = true
	ring.width = 4.0
	ring.points = _circle_points(72, 1.0)
	ring.default_color = color
	ring.global_position = position
	_add_effect_node(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.28)
	tween.tween_callback(Callable(ring, "queue_free"))


func _add_effect_node(node: Node) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		add_child(node)
		return
	parent.add_child(node)


func _cleanup_warning_line() -> void:
	if _warning_line != null and is_instance_valid(_warning_line):
		_warning_line.queue_free()
	_warning_line = null


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
