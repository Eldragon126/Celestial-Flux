extends CharacterBody2D
class_name GravityUndertaker

signal debris_charge_collected(data: Dictionary)
signal funeral_ring_released(data: Dictionary)

const ENEMY_GROUPS: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses"]
const DEBRIS_GROUPS: Array[StringName] = [&"law_gravity_debris"]
const HOSTILE_BURST_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses"]
const REWARD_BURST_GROUPS: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses"]

@export var max_health: float = 132.0
@export var collection_radius: float = 560.0
@export var max_debris_count: int = 9
@export var orbit_radius: float = 118.0
@export var orbit_speed: float = 2.1
@export var armor_scaling: float = 0.075
@export var launch_cooldown: float = 2.7
@export var burst_damage: float = 34.0
@export var death_explosion_scaling: float = 1.18

@export_group("Scavenger Behavior")
@export var collection_scan_interval: float = 0.28
@export var launch_speed: float = 760.0
@export var launch_damage: float = 18.0
@export var collapse_telegraph_time: float = 0.58
@export var move_acceleration: float = 460.0
@export var max_speed: float = 340.0
@export var contact_damage: float = 16.0
@export var max_targets_per_burst: int = 36

var _player: Node2D = null
var _health: HealthComponent = null
var _debris_charges: Array[Dictionary] = []
var _launched_debris: Array[Dictionary] = []
var _observed_enemy_ids: Dictionary = {}
var _collect_query: Array[Node2D] = []
var _enemy_query: Array[Node2D] = []
var _targets: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}
var _scan_elapsed: float = 999.0
var _launch_remaining: float = 1.6
var _collapse_pending: bool = false
var _collapse_elapsed: float = 0.0
var _core: Polygon2D = null
var _ring: Line2D = null
var _armor_ring: Line2D = null
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


func _process(delta: float) -> void:
	_scan_elapsed += delta
	_launch_remaining = maxf(_launch_remaining - delta, 0.0)
	if _scan_elapsed >= collection_scan_interval:
		_scan_elapsed = 0.0
		_scan_for_collection()
		_watch_nearby_enemy_deaths()
	if _collapse_pending:
		_update_collapse_telegraph(delta)
	elif _launch_remaining <= 0.0 and not _debris_charges.is_empty():
		_release_funeral_ring_pressure()
	_update_orbiting_debris(delta)
	_update_launched_debris(delta)
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	var target := _best_scavenge_target()
	var to_target := target - global_position
	if to_target.length_squared() > 4.0:
		velocity = velocity.move_toward(to_target.normalized() * max_speed, move_acceleration * scaled_delta)
	velocity *= pow(0.92, delta * 60.0)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(scaled_delta * 5.5, 0.0, 1.0))


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _health == null:
		return
	var reduction := clampf(float(_debris_charges.size()) * armor_scaling, 0.0, 0.72)
	var remaining := amount * (1.0 - reduction)
	if reduction > 0.0:
		_pulse_armor_ring(reduction)
	_health.take_damage(remaining)


func _scan_for_collection() -> void:
	if _debris_charges.size() >= max_debris_count:
		return
	_fill_targets_in_radius(DEBRIS_GROUPS, global_position, collection_radius, max_debris_count, false, _collect_query)
	for debris in _collect_query:
		if _debris_charges.size() >= max_debris_count:
			return
		if debris == null or not is_instance_valid(debris) or debris.is_queued_for_deletion():
			continue
		_add_debris_charge(debris.global_position, 1.0)
		debris.queue_free()


func _watch_nearby_enemy_deaths() -> void:
	_fill_targets_in_radius(ENEMY_GROUPS, global_position, collection_radius, 48, false, _enemy_query)
	for enemy in _enemy_query:
		if enemy == null or enemy == self or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var id := enemy.get_instance_id()
		if _observed_enemy_ids.has(id):
			continue
		var health := enemy.get_node_or_null("HealthComponent")
		if health == null or not health.has_signal(&"died"):
			continue
		var callback := Callable(self, "_on_observed_enemy_died").bind(enemy)
		if not health.is_connected(&"died", callback):
			health.connect(&"died", callback, CONNECT_ONE_SHOT)
		_observed_enemy_ids[id] = true


func _on_observed_enemy_died(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or _debris_charges.size() >= max_debris_count:
		return
	var enemy_2d := enemy as Node2D
	if enemy_2d == null:
		return
	if enemy_2d.global_position.distance_squared_to(global_position) > collection_radius * collection_radius * 1.44:
		return
	_add_debris_charge(enemy_2d.global_position, 1.25)


func _add_debris_charge(source_position: Vector2, strength: float) -> void:
	if _debris_charges.size() >= max_debris_count:
		return
	var local_offset := source_position - global_position
	var angle := local_offset.angle() if local_offset.length_squared() > 0.001 else randf() * TAU
	var shard := Polygon2D.new()
	shard.name = "FuneralDebrisCharge"
	shard.z_index = -1
	shard.polygon = _jagged_points(9, 15.0 + 4.0 * strength)
	shard.color = _undertaker_color(0.86)
	add_child(shard)
	var charge := {
		"angle": angle,
		"strength": strength,
		"node": shard,
	}
	_debris_charges.append(charge)
	debris_charge_collected.emit({
		"position": global_position,
		"source_position": source_position,
		"count": _debris_charges.size(),
		"max_count": max_debris_count,
	})


func _release_funeral_ring_pressure() -> void:
	_launch_remaining = launch_cooldown
	if _debris_charges.size() >= max_debris_count:
		_begin_collapse_burst()
		return
	_launch_one_debris()


func _begin_collapse_burst() -> void:
	if _collapse_pending:
		return
	_collapse_pending = true
	_collapse_elapsed = 0.0


func _update_collapse_telegraph(delta: float) -> void:
	_collapse_elapsed += delta
	if _armor_ring != null:
		var ratio := clampf(_collapse_elapsed / maxf(collapse_telegraph_time, 0.001), 0.0, 1.0)
		_armor_ring.scale = Vector2.ONE * (1.0 + ratio * 0.62)
		_armor_ring.width = 2.0 + ratio * 7.0
		_armor_ring.default_color = _undertaker_warning_color(Settings.world_visual_alpha(0.18 + 0.42 * ratio, 0.36))
	if _collapse_elapsed >= collapse_telegraph_time:
		_collapse_pending = false
		_collapse_ring_burst(false)


func _launch_one_debris() -> void:
	if _debris_charges.is_empty():
		return
	var charge = _debris_charges.pop_front()
	var visual := charge.get("node") as Node2D
	var start_position := global_position
	if visual != null and is_instance_valid(visual):
		start_position = visual.global_position
		visual.queue_free()
	var direction := Vector2.RIGHT.rotated(float(charge.get("angle", 0.0)))
	if _player != null and is_instance_valid(_player):
		direction = (_player.global_position - start_position).normalized()
	var shard := Area2D.new()
	shard.name = "FuneralDebrisLaunch"
	shard.monitoring = true
	shard.z_index = 30
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	shard.add_child(shape)
	var poly := Polygon2D.new()
	poly.name = "FuneralDebrisShard"
	poly.polygon = _jagged_points(8, 20.0)
	poly.color = _undertaker_warning_color(0.88)
	shard.add_child(poly)
	shard.global_position = start_position
	var parent := get_tree().current_scene
	if parent == null:
		add_child(shard)
	else:
		parent.add_child(shard)
	shard.body_entered.connect(_on_launched_debris_body_entered.bind(shard))
	_launched_debris.append({
		"node": shard,
		"velocity": direction * launch_speed,
		"age": 0.0,
		"strength": charge.get("strength", 1.0),
	})


func _collapse_ring_burst(death_reward: bool) -> void:
	var count := _debris_charges.size()
	if count <= 0:
		return
	var charge_ratio := clampf(float(count) / maxf(float(max_debris_count), 1.0), 0.0, 1.0)
	var radius := lerpf(orbit_radius * 1.5, collection_radius * 0.82, charge_ratio)
	var damage_amount := burst_damage * (0.6 + charge_ratio * 1.2)
	if death_reward:
		damage_amount *= death_explosion_scaling
	_damage_targets(REWARD_BURST_GROUPS if death_reward else HOSTILE_BURST_GROUPS, global_position, radius, damage_amount, not death_reward)
	_spawn_ring_burst(global_position, radius, _undertaker_warning_color(Settings.world_visual_alpha(0.62, 0.36)))
	for charge in _debris_charges:
		var node := charge.get("node") as Node2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_debris_charges.clear()
	funeral_ring_released.emit({
		"position": global_position,
		"radius": radius,
		"damage": damage_amount,
		"death_reward": death_reward,
		"charge_count": count,
	})


func _damage_targets(groups: Array[StringName], center: Vector2, radius: float, damage_amount: float, include_player: bool) -> void:
	_fill_targets_in_radius(groups, center, radius, max_targets_per_burst, include_player, _targets)
	for target in _targets:
		if target == null or target == self or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		var offset := target.global_position - center
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / maxf(radius, 1.0), 0.0, 1.0)
		if target.has_method("take_damage"):
			target.call("take_damage", damage_amount * (0.35 + falloff * 0.65))
		CombatStatus.add_velocity(target, offset.normalized() * lerpf(220.0, 660.0, falloff))


func _update_orbiting_debris(delta: float) -> void:
	for index in range(_debris_charges.size()):
		var charge := _debris_charges[index]
		var node := charge.get("node") as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var angle := float(charge.get("angle", 0.0)) + orbit_speed * delta * (1.0 + float(index) * 0.035)
		charge["angle"] = angle
		var radius := orbit_radius + sin(Time.get_ticks_msec() * 0.002 + float(index)) * 10.0
		node.position = Vector2.RIGHT.rotated(angle) * radius
		node.rotation += delta * (2.0 + float(index) * 0.12)
		_debris_charges[index] = charge


func _update_launched_debris(delta: float) -> void:
	for index in range(_launched_debris.size() - 1, -1, -1):
		var entry := _launched_debris[index]
		var shard := entry.get("node") as Area2D
		if shard == null or not is_instance_valid(shard):
			_launched_debris.remove_at(index)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var shard_velocity := entry.get("velocity", Vector2.ZERO) as Vector2
		shard.global_position += shard_velocity * delta
		shard.rotation += delta * 7.0
		entry["age"] = age
		if age >= 2.4:
			shard.queue_free()
			_launched_debris.remove_at(index)
			continue
		_launched_debris[index] = entry


func _on_launched_debris_body_entered(body: Node, shard: Area2D) -> void:
	if body == null or body == self or shard == null or not is_instance_valid(shard):
		return
	if not (body.is_in_group("Player") or body.is_in_group("enemies") or body.is_in_group("wave_enemy") or body.is_in_group("bosses")):
		return
	var damage_amount := launch_damage
	if body.has_method("take_damage"):
		body.call("take_damage", damage_amount)
	var body_2d := body as Node2D
	var direction := Vector2.RIGHT
	if body_2d != null:
		direction = (body_2d.global_position - shard.global_position).normalized()
	CombatStatus.add_velocity(body, direction * launch_speed * 0.36)
	shard.queue_free()


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


func _best_scavenge_target() -> Vector2:
	var best := _player.global_position if _player != null and is_instance_valid(_player) else global_position
	var best_distance := INF
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(DEBRIS_GROUPS, global_position, collection_radius * 1.35, 8, false, _collect_query)
	for debris in _collect_query:
		if debris == null or not is_instance_valid(debris) or debris.is_queued_for_deletion():
			continue
		var distance := debris.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = debris.global_position
	return best


func _build_body() -> void:
	_core = Polygon2D.new()
	_core.name = "GravityUndertakerCore"
	_core.color = _undertaker_color(1.0)
	_core.polygon = PackedVector2Array([
		Vector2(0.0, -48.0),
		Vector2(34.0, -26.0),
		Vector2(42.0, 18.0),
		Vector2(0.0, 48.0),
		Vector2(-42.0, 18.0),
		Vector2(-34.0, -26.0),
	])
	add_child(_core)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)

	_ring = Line2D.new()
	_ring.name = "FuneralOrbitRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.0
	_ring.points = _circle_points(72, orbit_radius)
	_ring.default_color = _undertaker_color(Settings.world_visual_alpha(0.16, 0.24))
	add_child(_ring)

	_armor_ring = Line2D.new()
	_armor_ring.name = "FuneralArmorRing"
	_armor_ring.closed = true
	_armor_ring.antialiased = true
	_armor_ring.width = 2.0
	_armor_ring.points = _circle_points(72, orbit_radius + 28.0)
	_armor_ring.default_color = _undertaker_color(Settings.world_visual_alpha(0.08, 0.18))
	add_child(_armor_ring)

	_attack_area = Area2D.new()
	_attack_area.name = "UndertakerContactArea"
	_attack_area.monitoring = true
	_attack_area.body_entered.connect(_on_attack_area_body_entered)
	var shape := CollisionShape2D.new()
	shape.name = "UndertakerContactShape"
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


func _update_visuals(delta: float) -> void:
	var charge_ratio := clampf(float(_debris_charges.size()) / maxf(float(max_debris_count), 1.0), 0.0, 1.0)
	if _core != null:
		_core.rotation -= delta * (0.35 + charge_ratio * 0.8)
		_core.color = _undertaker_color(0.82 + charge_ratio * 0.18)
	if _ring != null:
		_ring.rotation += delta * (0.55 + charge_ratio * 1.1)
		_ring.width = 1.6 + charge_ratio * 3.8
		_ring.default_color = _undertaker_color(Settings.world_visual_alpha(0.1 + charge_ratio * 0.28, 0.3))
	if _armor_ring != null and not _collapse_pending:
		_armor_ring.rotation -= delta * (0.38 + charge_ratio * 0.85)
		_armor_ring.scale = Vector2.ONE
		_armor_ring.width = 1.4 + charge_ratio * 3.2
		_armor_ring.default_color = _undertaker_color(Settings.world_visual_alpha(0.07 + charge_ratio * 0.2, 0.24))


func _pulse_armor_ring(reduction: float) -> void:
	if _armor_ring == null:
		return
	_armor_ring.width = 3.0 + reduction * 8.0
	_armor_ring.default_color = _undertaker_warning_color(Settings.world_visual_alpha(0.28 + reduction * 0.4, 0.36))


func _spawn_ring_burst(position: Vector2, radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.name = "FuneralRingBurst"
	ring.z_index = 38
	ring.closed = true
	ring.antialiased = true
	ring.width = 5.0
	ring.points = _circle_points(72, 1.0)
	ring.default_color = color
	ring.global_position = position
	var parent := get_tree().current_scene
	if parent == null:
		add_child(ring)
	else:
		parent.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.32)
	tween.tween_callback(Callable(ring, "queue_free"))


func _on_attack_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)


func _on_died() -> void:
	_collapse_ring_burst(true)
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.2, true)
	queue_free()


func _undertaker_color(alpha: float) -> Color:
	return Settings.apply_readability_color(Color(0.28, 0.72, 1.0, alpha))


func _undertaker_warning_color(alpha: float) -> Color:
	return Settings.apply_readability_color(Color(1.0, 0.48, 0.14, alpha))


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _jagged_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		var jag := 0.76 + 0.28 * sin(angle * 3.0 + float(i))
		points.append(Vector2(cos(angle), sin(angle)) * radius * jag)
	return points
