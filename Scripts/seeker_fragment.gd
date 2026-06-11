extends RigidBody2D

const SELF_SCENE = preload("res://Nodes/seeker_fragment.tscn")

@export var generation = 0
@export var max_generation = 1
@export var max_health = 30.0
@export var launch_speed = 920.0
@export var steer_force = 520.0
@export var contact_damage = 18.0
@export var lead_time = 0.42
@export var gravity_constant = 120.0
@export var min_grav_dist = 60.0
@export var gravity_refresh_interval = 0.55

var _player: Node2D = null
var _health: HealthComponent = null
var _gravity_sources: Array[Node2D] = []
var _gravity_refresh_elapsed = 0.0
var _dead = false

func _ready() -> void:
	add_to_group("enemies")
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	_refresh_gravity_sources()
	_launch_at_player()

func _physics_process(delta: float) -> void:
	var scaled_delta = delta * CombatStatus.get_time_scale(self)
	_gravity_refresh_elapsed += delta
	if _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_gravity_sources()

	var gravity = _calculate_gravity()
	if gravity != Vector2.ZERO:
		apply_central_force(gravity)

	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())

	if _player != null and is_instance_valid(_player):
		var target = _predicted_player_position()
		var desired = (target - global_position).normalized() * launch_speed
		apply_central_force((desired - linear_velocity).limit_length(steer_force) / maxf(scaled_delta, 0.001))

	if linear_velocity.length() > 1.0:
		rotation = linear_velocity.angle()

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _launch_at_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	if _player == null or not is_instance_valid(_player):
		linear_velocity = Vector2.RIGHT.rotated(randf() * TAU) * launch_speed
		return

	linear_velocity = (_predicted_player_position() - global_position).normalized() * launch_speed

func _predicted_player_position() -> Vector2:
	if _player == null:
		return global_position

	var player_velocity: Variant = _player.get("velocity")
	if not (player_velocity is Vector2):
		player_velocity = Vector2.ZERO
	return _player.global_position + player_velocity * lead_time

func _build_body() -> void:
	var poly = _fragment_points(30.0 * pow(0.68, generation))
	if not has_node("CollisionPolygon2D"):
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = poly
		add_child(collision)

	var visual := get_node_or_null("SeekerFragmentPolygon") as Polygon2D
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "SeekerFragmentPolygon"
		visual.color = Color(1.0, 0.18, 0.12, 1.0)
		add_child(visual)
	if visual.polygon.is_empty():
		visual.polygon = poly

func _build_health() -> void:
	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		add_child(_health)
	_health.max_health = max_health * pow(0.55, generation)
	if not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)

func _calculate_gravity() -> Vector2:
	var total = Vector2.ZERO
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		var offset = source.global_position - global_position
		var distance = maxf(offset.length(), min_grav_dist)
		if distance <= 0.0:
			continue
		var mass_value: Variant = source.get("mass")
		var value_type = typeof(mass_value)
		var source_mass = float(mass_value) if value_type == TYPE_FLOAT or value_type == TYPE_INT else 100.0
		total += offset.normalized() * gravity_constant * source_mass / (distance * distance)
	return total

func _refresh_gravity_sources() -> void:
	_gravity_refresh_elapsed = 0.0
	_gravity_sources.clear()
	var seen = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == null or not is_instance_valid(source):
				continue
			var source_2d = source as Node2D
			if source_2d == null or source_2d == self or source_2d.is_queued_for_deletion():
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source_2d)
	_gravity_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)
	if _gravity_sources.size() > 4:
		_gravity_sources.resize(4)

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		_on_died()
	elif body.is_in_group("planets") or body.is_in_group("Objects_With_Gravity"):
		_on_died()

func _on_died() -> void:
	if _dead:
		return
	_dead = true

	var parent = get_parent()
	if parent != null and generation < max_generation:
		for i in range(3):
			var fragment = SELF_SCENE.instantiate()
			fragment.generation = generation + 1
			fragment.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / 3.0) * 26.0
			fragment.linear_velocity = Vector2.RIGHT.rotated(TAU * float(i) / 3.0 + randf_range(-0.25, 0.25)) * launch_speed * 0.82
			parent.call_deferred("add_child", fragment)

	PowerupLibrary.try_spawn_drop(parent, global_position, 0.06)
	queue_free()

func _fragment_points(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(radius, 0.0),
		Vector2(-radius * 0.42, radius * 0.72),
		Vector2(-radius * 0.72, -radius * 0.62),
	])
