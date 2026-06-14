extends CharacterBody2D
class_name OrbitWeaver

const ORBIT_THREAD_SCRIPT := preload("res://Scripts/orbit_thread.gd")

@export var max_health: float = 118.0
@export var anchor_search_radius: float = 1150.0
@export var thread_duration: float = 5.6
@export var telegraph_time: float = 1.0
@export var pull_strength: float = 720.0
@export var max_affected_bodies: int = 30
@export var cooldown: float = 4.4
@export var anchor_health: float = 36.0

@export_group("Movement")
@export var drift_acceleration: float = 430.0
@export var max_speed: float = 320.0
@export var preferred_distance: float = 760.0
@export var max_active_threads: int = 2
@export var contact_damage: float = 14.0

var _player: Node2D = null
var _health: HealthComponent = null
var _cooldown_remaining: float = 1.8
var _active_threads: Array[OrbitThread] = []
var _anchor_candidates: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _core: Polygon2D = null
var _ring: Line2D = null
var _attack_area: Area2D = null


func _ready() -> void:
	add_to_group("enemies")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
	_rng.randomize()
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_cleanup_threads()
	if _cooldown_remaining <= 0.0 and _active_threads.size() < max_active_threads:
		_create_orbit_thread()
		_cooldown_remaining = cooldown
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return
	_drift_near_player(scaled_delta)


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _drift_near_player(delta: float) -> void:
	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.001:
		return
	var tangent := to_player.normalized().orthogonal()
	var desired := tangent * max_speed * 0.46
	if distance > preferred_distance:
		desired += to_player.normalized() * max_speed
	elif distance < preferred_distance * 0.52:
		desired -= to_player.normalized() * max_speed * 0.82
	velocity = velocity.move_toward(desired.limit_length(max_speed), drift_acceleration * delta)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 5.5, 0.0, 1.0))


func _create_orbit_thread() -> void:
	var pair := _select_anchor_pair()
	if pair.is_empty():
		return
	var thread := ORBIT_THREAD_SCRIPT.new() as OrbitThread
	if thread == null:
		return
	thread.name = "OrbitThread"
	thread.configure(
		pair[0],
		pair[1],
		thread_duration,
		telegraph_time,
		pull_strength,
		max_affected_bodies,
		anchor_health
	)
	thread.thread_disabled.connect(_on_thread_disabled)
	var parent := get_tree().current_scene
	if parent == null:
		add_child(thread)
	else:
		parent.add_child(thread)
	_active_threads.append(thread)


func _select_anchor_pair() -> Array[Vector2]:
	_anchor_candidates.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(global_position, _anchor_candidates, 8, anchor_search_radius, self)
	else:
		_collect_anchor_candidates_fallback()
	var points: Array[Vector2] = []
	for anchor in _anchor_candidates:
		if anchor == null or not is_instance_valid(anchor) or anchor.is_queued_for_deletion():
			continue
		if anchor.global_position.distance_squared_to(global_position) > anchor_search_radius * anchor_search_radius:
			continue
		points.append(anchor.global_position)
		if points.size() >= 4:
			break
	while points.size() < 2:
		points.append(_fallback_anchor_point(points.size()))
	if points[0].distance_squared_to(points[1]) < 220.0 * 220.0:
		points[1] = _fallback_anchor_point(5)
	return [points[0], points[1]]


func _collect_anchor_candidates_fallback() -> void:
	var seen: Dictionary = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var anchor := node as Node2D
			if anchor == null or anchor == self or not is_instance_valid(anchor) or anchor.is_queued_for_deletion():
				continue
			var id := anchor.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_anchor_candidates.append(anchor)
			if _anchor_candidates.size() >= 8:
				return


func _fallback_anchor_point(salt: int) -> Vector2:
	var center := _player.global_position if _player != null and is_instance_valid(_player) else global_position
	var angle := _rng.randf_range(0.0, TAU) + float(salt) * 1.73
	var radius := _rng.randf_range(anchor_search_radius * 0.36, anchor_search_radius * 0.72)
	return center + Vector2.RIGHT.rotated(angle) * radius


func _cleanup_threads() -> void:
	for index in range(_active_threads.size() - 1, -1, -1):
		var thread := _active_threads[index]
		if thread == null or not is_instance_valid(thread) or thread.is_queued_for_deletion():
			_active_threads.remove_at(index)


func _build_body() -> void:
	_core = Polygon2D.new()
	_core.name = "OrbitWeaverCore"
	_core.color = Settings.apply_readability_color(Color(0.08, 0.74, 1.0, 1.0))
	_core.polygon = PackedVector2Array([
		Vector2(0.0, -44.0),
		Vector2(36.0, -18.0),
		Vector2(36.0, 18.0),
		Vector2(0.0, 44.0),
		Vector2(-36.0, 18.0),
		Vector2(-36.0, -18.0),
	])
	add_child(_core)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)

	_ring = Line2D.new()
	_ring.name = "WeaverAnchorSearchRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 1.8
	_ring.points = _circle_points(64, 96.0)
	_ring.default_color = Settings.apply_readability_color(Color(0.1, 0.9, 1.0, Settings.world_visual_alpha(0.18, 0.24)))
	add_child(_ring)

	_attack_area = Area2D.new()
	_attack_area.name = "WeaverContactArea"
	_attack_area.monitoring = true
	_attack_area.body_entered.connect(_on_attack_area_body_entered)
	var shape := CollisionShape2D.new()
	shape.name = "WeaverContactShape"
	var circle := CircleShape2D.new()
	circle.radius = 46.0
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
	if _core != null:
		_core.rotation -= delta * 0.7
	if _ring != null:
		var ready := 1.0 - clampf(_cooldown_remaining / maxf(cooldown, 0.001), 0.0, 1.0)
		_ring.rotation += delta * (0.4 + ready * 1.5)
		_ring.scale = Vector2.ONE * (1.0 + ready * 0.48)
		_ring.default_color = Settings.apply_readability_color(Color(0.1, 0.9, 1.0, Settings.world_visual_alpha(0.1 + ready * 0.24, 0.28)))


func _on_attack_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)


func _on_thread_disabled(thread: OrbitThread, _reason: StringName) -> void:
	var index := _active_threads.find(thread)
	if index >= 0:
		_active_threads.remove_at(index)


func _on_died() -> void:
	for thread in _active_threads:
		if thread != null and is_instance_valid(thread):
			thread.disable_thread(&"weaver_destroyed")
	_active_threads.clear()
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.18, true)
	queue_free()


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
