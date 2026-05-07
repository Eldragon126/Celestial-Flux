extends CharacterBody2D

@export var max_health = 24.0
@export var max_speed = 700.0
@export var random_acceleration = 840.0
@export var gravity_constant = 170.0
@export var min_grav_dist = 70.0
@export var evade_radius = 280.0
@export var contact_damage = 8.0
@export var vector_refresh_interval = 0.32
@export var gravity_refresh_interval = 0.55

var _player: Node2D = null
var _health: HealthComponent = null
var _gravity_sources: Array[Node2D] = []
var _chaos_vector = Vector2.ZERO
var _vector_elapsed = 0.0
var _gravity_refresh_elapsed = 0.0
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_build_body()
	_build_health()
	_refresh_gravity_sources()
	_pick_chaos_vector()

func _physics_process(delta: float) -> void:
	var scaled_delta = delta * CombatStatus.get_time_scale(self)
	_vector_elapsed += delta
	_gravity_refresh_elapsed += delta
	if _vector_elapsed >= vector_refresh_interval:
		_pick_chaos_vector()
	if _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_gravity_sources()

	var accel = _chaos_vector * random_acceleration + _calculate_gravity()

	if _player != null and is_instance_valid(_player):
		var away = global_position - _player.global_position
		if away.length() < evade_radius:
			accel += away.normalized() * random_acceleration * 1.25

	velocity += accel * scaled_delta
	velocity = velocity.limit_length(max_speed)
	velocity *= pow(0.94, delta * 60.0)
	move_and_slide()
	rotation += scaled_delta * 9.0

func take_damage(amount: float) -> void:
	_pick_chaos_vector()
	velocity += _chaos_vector * 260.0
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var glow = Polygon2D.new()
	glow.name = "ChaosWispGlow"
	glow.z_index = -1
	glow.color = Color(0.16, 1.0, 0.44, 0.26)
	glow.polygon = _circle_points(18, 42.0)
	add_child(glow)

	var core = Polygon2D.new()
	core.name = "ChaosWispCore"
	core.color = Color(0.2, 1.0, 0.46, 1.0)
	core.polygon = _circle_points(7, 22.0)
	add_child(core)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)

	var attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.monitoring = true
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	add_child(attack_area)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	attack_area.add_child(shape)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

func _pick_chaos_vector() -> void:
	_vector_elapsed = 0.0
	_chaos_vector = Vector2.RIGHT.rotated(_rng.randf() * TAU)

func _calculate_gravity() -> Vector2:
	var total = Vector2.ZERO
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		var offset = source.global_position - global_position
		var distance = maxf(offset.length(), min_grav_dist)
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
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.38, true)
	queue_free()

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
