extends CharacterBody2D
class_name CausalityShrike

signal rupture_marker_placed(marker_data: Dictionary)
signal rupture_triggered(marker_data: Dictionary)

const RUPTURE_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses"]
const INVALID_POSITION: Vector2 = Vector2(1000000000.0, 1000000000.0)

@export var max_health: float = 86.0
@export_range(2.0, 4.0, 0.05) var history_delay: float = 2.8
@export var marker_spacing: float = 145.0
@export var marker_telegraph_time: float = 0.84
@export var rupture_radius: float = 94.0
@export var damage: float = 22.0
@export var path_sample_rate: float = 0.08
@export var cooldown: float = 0.32

@export_group("Movement")
@export var acceleration: float = 720.0
@export var max_speed: float = 620.0
@export var drag: float = 0.91
@export var max_active_markers: int = 18
@export var max_targets_per_rupture: int = 28
@export var contact_damage: float = 12.0

var _player: Node2D = null
var _health: HealthComponent = null
var _history: Array[Dictionary] = []
var _markers: Array[Dictionary] = []
var _targets: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}
var _sample_elapsed: float = 999.0
var _cooldown_remaining: float = 0.7
var _last_marker_position: Vector2 = INVALID_POSITION
var _core: Polygon2D = null
var _trail_line: Line2D = null
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
	for marker in _markers:
		var node := marker.get("node") as Node2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_markers.clear()


func _process(delta: float) -> void:
	_sample_elapsed += delta
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	if _sample_elapsed >= path_sample_rate:
		_sample_elapsed = 0.0
		_sample_player_path()
	_try_place_marker()
	_update_markers(delta)
	_update_trail_visual()
	_update_body_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		return
	var target_position := _delayed_position()
	if target_position == INVALID_POSITION:
		target_position = _player.global_position
	var to_target := target_position - global_position
	if to_target.length_squared() > 4.0:
		velocity = velocity.move_toward(to_target.normalized() * max_speed, acceleration * scaled_delta)
	velocity *= pow(drag, delta * 60.0)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(scaled_delta * 8.0, 0.0, 1.0))


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _sample_player_path() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var now := _now_seconds()
	_history.append({
		"time": now,
		"position": _player.global_position,
	})
	var keep_after := now - history_delay - 1.6
	while _history.size() > 0 and float(_history[0].get("time", 0.0)) < keep_after:
		_history.remove_at(0)


func _try_place_marker() -> void:
	if _cooldown_remaining > 0.0 or _markers.size() >= max_active_markers:
		return
	var delayed := _delayed_position()
	if delayed == INVALID_POSITION:
		return
	if _last_marker_position != INVALID_POSITION and delayed.distance_squared_to(_last_marker_position) < marker_spacing * marker_spacing:
		return
	_place_rupture_marker(delayed)
	_last_marker_position = delayed
	_cooldown_remaining = cooldown


func _delayed_position() -> Vector2:
	if _history.size() < 2:
		return INVALID_POSITION
	var target_time := _now_seconds() - history_delay
	for index in range(_history.size() - 2, -1, -1):
		var previous: Dictionary = _history[index]
		var next: Dictionary = _history[index + 1]
		var previous_time := float(previous.get("time", 0.0))
		var next_time := float(next.get("time", 0.0))
		if previous_time <= target_time and next_time >= target_time:
			var span := maxf(next_time - previous_time, 0.001)
			var t := clampf((target_time - previous_time) / span, 0.0, 1.0)
			return (previous.get("position", Vector2.ZERO) as Vector2).lerp(next.get("position", Vector2.ZERO) as Vector2, t)
	if float(_history[0].get("time", 0.0)) > target_time:
		return INVALID_POSITION
	return _history[0].get("position", INVALID_POSITION) as Vector2


func _place_rupture_marker(position: Vector2) -> void:
	var marker := Node2D.new()
	marker.name = "CausalityRuptureMarker"
	marker.global_position = position
	marker.z_index = 31

	var ring := Line2D.new()
	ring.name = "RuptureTelegraphRing"
	ring.closed = true
	ring.antialiased = true
	ring.width = 3.0
	ring.points = _circle_points(36, rupture_radius)
	ring.default_color = _rupture_color(0.34)
	marker.add_child(ring)

	var slash := Line2D.new()
	slash.name = "OldPathSlash"
	slash.antialiased = true
	slash.width = 3.2
	slash.points = PackedVector2Array([Vector2(-rupture_radius * 0.62, 0.0), Vector2(rupture_radius * 0.62, 0.0)])
	slash.default_color = _rupture_color(0.62)
	marker.add_child(slash)

	var parent := get_tree().current_scene
	if parent == null:
		add_child(marker)
	else:
		parent.add_child(marker)

	var data := {
		"node": marker,
		"ring": ring,
		"slash": slash,
		"age": 0.0,
		"position": position,
		"triggered": false,
	}
	_markers.append(data)
	rupture_marker_placed.emit({
		"position": position,
		"radius": rupture_radius,
		"telegraph_time": marker_telegraph_time,
	})


func _update_markers(delta: float) -> void:
	for index in range(_markers.size() - 1, -1, -1):
		var marker := _markers[index]
		var node := marker.get("node") as Node2D
		if node == null or not is_instance_valid(node):
			_markers.remove_at(index)
			continue
		var age := float(marker.get("age", 0.0)) + delta
		marker["age"] = age
		var triggered := bool(marker.get("triggered", false))
		if not triggered and age >= marker_telegraph_time:
			_trigger_marker(marker)
			marker["triggered"] = true
		elif triggered and age >= marker_telegraph_time + 0.24:
			node.queue_free()
			_markers.remove_at(index)
			continue
		_update_marker_visual(marker)
		_markers[index] = marker


func _update_marker_visual(marker: Dictionary) -> void:
	var ring := marker.get("ring") as Line2D
	var slash := marker.get("slash") as Line2D
	var age := float(marker.get("age", 0.0))
	var ratio := clampf(age / maxf(marker_telegraph_time, 0.001), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.032 + age * 7.0)
	if ring != null:
		ring.rotation += 0.035 + ratio * 0.04
		ring.scale = Vector2.ONE * lerpf(0.52, 1.0, ratio)
		ring.width = lerpf(1.4, 5.4, ratio)
		ring.default_color = _rupture_color(Settings.world_visual_alpha(0.12 + 0.34 * maxf(ratio, pulse * 0.45), 0.34))
	if slash != null:
		slash.rotation += 0.05 + ratio * 0.07
		slash.default_color = _rupture_color(Settings.world_visual_alpha(0.24 + 0.44 * ratio, 0.36))


func _trigger_marker(marker: Dictionary) -> void:
	var position := marker.get("position", Vector2.ZERO) as Vector2
	_fill_targets_in_radius(RUPTURE_TARGET_GROUPS, position, rupture_radius, max_targets_per_rupture, true, _targets)
	for target in _targets:
		if target == null or not is_instance_valid(target) or target == self or target.is_queued_for_deletion():
			continue
		var offset := target.global_position - position
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / maxf(rupture_radius, 1.0), 0.0, 1.0)
		if target.has_method("take_damage"):
			target.call("take_damage", damage * (0.42 + falloff * 0.58))
		CombatStatus.add_velocity(target, offset.normalized() * lerpf(180.0, 460.0, falloff))
	_spawn_rupture_burst(position)
	rupture_triggered.emit({
		"position": position,
		"radius": rupture_radius,
		"damage": damage,
	})


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
	_core = Polygon2D.new()
	_core.name = "CausalityShrikeCore"
	_core.color = _rupture_color(1.0)
	_core.polygon = PackedVector2Array([
		Vector2(50.0, 0.0),
		Vector2(8.0, 14.0),
		Vector2(-18.0, 38.0),
		Vector2(-12.0, 8.0),
		Vector2(-48.0, 0.0),
		Vector2(-12.0, -8.0),
		Vector2(-18.0, -38.0),
		Vector2(8.0, -14.0),
	])
	add_child(_core)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)

	_trail_line = Line2D.new()
	_trail_line.name = "DelayedPathTrace"
	_trail_line.z_index = -1
	_trail_line.antialiased = true
	_trail_line.width = 2.0
	_trail_line.default_color = _rupture_color(Settings.world_visual_alpha(0.16, 0.22))
	add_child(_trail_line)

	_attack_area = Area2D.new()
	_attack_area.name = "ShrikeContactArea"
	_attack_area.monitoring = true
	_attack_area.body_entered.connect(_on_attack_area_body_entered)
	var shape := CollisionShape2D.new()
	shape.name = "ShrikeContactShape"
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	shape.shape = circle
	_attack_area.add_child(shape)
	add_child(_attack_area)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _update_trail_visual() -> void:
	if _trail_line == null:
		return
	var points := PackedVector2Array()
	var target_time := _now_seconds() - history_delay
	for entry in _history:
		var entry_time := float(entry.get("time", 0.0))
		if absf(entry_time - target_time) <= history_delay * 0.36:
			var position := entry.get("position", Vector2.ZERO) as Vector2
			points.append(to_local(position))
			if points.size() >= 16:
				break
	_trail_line.points = points


func _update_body_visuals(delta: float) -> void:
	if _core != null:
		_core.rotation += delta * 0.9
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.016)
		_core.color = _rupture_color(0.78 + pulse * 0.22)


func _spawn_rupture_burst(position: Vector2) -> void:
	var ring := Line2D.new()
	ring.name = "CausalityRuptureBurst"
	ring.z_index = 36
	ring.closed = true
	ring.antialiased = true
	ring.width = 5.0
	ring.points = _circle_points(48, 1.0)
	ring.default_color = _rupture_color(Settings.world_visual_alpha(0.58, 0.34))
	ring.global_position = position
	var parent := get_tree().current_scene
	if parent == null:
		add_child(ring)
	else:
		parent.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * rupture_radius, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.22)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(ring))


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


func _on_attack_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)


func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.18, true)
	queue_free()


func _rupture_color(alpha: float) -> Color:
	return Settings.apply_readability_color(Color(1.0, 0.28, 0.72, alpha))


func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
