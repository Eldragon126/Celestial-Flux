extends CharacterBody2D

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

@export var orbit_radius = 260.0
@export var orbit_speed = 1.72
@export var follow_strength = 4.9
@export var max_speed = 580.0
@export var max_health = 42.0
@export var burst_interval = 2.75
@export var burst_projectiles = 8
@export var burst_speed = 650.0
@export var contact_damage = 12.0
@export var gravity_refresh_interval = 0.45

var _player: Node2D = null
var _health: HealthComponent = null
var _burst_timer: Timer
var _orbit_angle = 0.0
var _gravity_sources: Array[Node2D] = []
var _gravity_refresh_elapsed = 0.0
var _telegraph_ring: Polygon2D

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_orbit_angle = randf() * TAU
	_build_body()
	_build_health()
	_build_timer()
	_refresh_gravity_sources()

func _physics_process(delta: float) -> void:
	var time_scale = CombatStatus.get_time_scale(self)
	var scaled_delta = delta * time_scale
	_gravity_refresh_elapsed += delta
	if _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_gravity_sources()

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return

	var anchor = _get_orbit_anchor()
	_orbit_angle += orbit_speed * scaled_delta
	var target = anchor.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
	velocity = velocity.lerp((target - global_position) * follow_strength, clampf(scaled_delta * 3.0, 0.0, 1.0))
	velocity = velocity.limit_length(max_speed)
	move_and_slide()

	var aim = (anchor.global_position - global_position).normalized()
	if aim != Vector2.ZERO:
		rotation = lerp_angle(rotation, aim.angle(), clampf(scaled_delta * 7.0, 0.0, 1.0))

func take_damage(amount: float) -> void:
	_orbit_angle += randf_range(-0.8, 0.8)
	orbit_radius = clampf(orbit_radius + randf_range(-38.0, 38.0), 180.0, 380.0)
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var core = Polygon2D.new()
	core.name = "OrbiterCorePolygon"
	core.color = Color(0.72, 0.25, 1.0, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(0.0, -30.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, 30.0),
		Vector2(-28.0, 0.0),
	])
	add_child(core)

	_telegraph_ring = Polygon2D.new()
	_telegraph_ring.name = "BurstTelegraphRing"
	_telegraph_ring.z_index = -1
	_telegraph_ring.color = Color(0.72, 0.25, 1.0, 0.18)
	_telegraph_ring.polygon = _circle_points(18, 48.0)
	add_child(_telegraph_ring)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)

	var attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.monitoring = true
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	add_child(attack_area)

	var attack_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 42.0
	attack_shape.shape = circle
	attack_area.add_child(attack_shape)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

func _build_timer() -> void:
	_burst_timer = Timer.new()
	_burst_timer.name = "RadialBurstTimer"
	_burst_timer.wait_time = burst_interval
	_burst_timer.timeout.connect(_telegraph_and_burst)
	add_child(_burst_timer)
	_burst_timer.start()

func _telegraph_and_burst() -> void:
	if _telegraph_ring != null:
		var tween = create_tween()
		_telegraph_ring.scale = Vector2.ONE
		tween.tween_property(_telegraph_ring, "scale", Vector2(1.8, 1.8), 0.22)
		tween.parallel().tween_property(_telegraph_ring, "color:a", 0.42, 0.22)
		tween.tween_property(_telegraph_ring, "color:a", 0.18, 0.18)

	await get_tree().create_timer(0.26).timeout
	_fire_radial_burst()

func _fire_radial_burst() -> void:
	if get_parent() == null:
		return

	var offset = randf() * TAU
	for i in range(burst_projectiles):
		var direction = Vector2.RIGHT.rotated(offset + TAU * float(i) / float(burst_projectiles))
		var bullet = ENEMY_BULLET_SCENE.instantiate()
		get_parent().call_deferred("add_child", bullet)
		bullet.global_position = global_position + direction * 44.0
		bullet.apply_impulse(direction * burst_speed)

func _get_orbit_anchor() -> Node2D:
	var best = _player
	var best_dist = INF

	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue

		var distance = global_position.distance_squared_to(source.global_position)
		if distance < best_dist:
			best_dist = distance
			best = source

	return best

func _refresh_gravity_sources() -> void:
	_gravity_refresh_elapsed = 0.0
	_gravity_sources.clear()
	var seen = {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d = source as Node2D
			if source_2d == null or source_2d == self:
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

func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)

func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.08)
	queue_free()

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
