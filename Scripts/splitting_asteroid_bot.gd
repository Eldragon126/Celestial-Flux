extends CharacterBody2D

# Enemy variant: breaks into smaller faster bots when its health reaches zero.

const SELF_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")
const COLLISION_SPARK_SCENE = preload("res://Nodes/collision_sparks.tscn")

@export var split_generation = 0
@export var max_split_generation = 2
@export var base_health = 34.0
@export var thrust_power = 760.0
@export var max_speed = 520.0
@export var contact_damage = 14.0

var _player: Node = null
var _health: HealthComponent = null
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("Player")
	_build_body()
	_build_health()
	scale = Vector2.ONE * pow(0.72, split_generation)
	max_speed *= pow(1.22, split_generation)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		return

	var desired = (_player.global_position - global_position).normalized() * thrust_power
	velocity += desired * delta
	velocity = velocity.limit_length(max_speed)
	velocity *= pow(0.88, delta * 60.0)
	rotation += delta * (2.0 + split_generation)
	move_and_slide()

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var radius = 38.0
	var polygon = Polygon2D.new()
	polygon.name = "AsteroidBotPolygon"
	polygon.color = Color(0.72, 0.52, 0.38, 1.0)
	polygon.polygon = _jagged_circle_points(13, radius)
	add_child(polygon)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = polygon.polygon
	add_child(collision)

	var attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.monitoring = true
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	add_child(attack_area)

	var attack_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius + 10.0
	attack_shape.shape = circle
	attack_area.add_child(attack_shape)

	var particles = GPUParticles2D.new()
	particles.name = "RockChipParticles"
	particles.z_index = -1
	particles.amount = 28
	particles.lifetime = 1.5
	particles.randomness = 0.6
	particles.process_material = _make_chip_material()
	add_child(particles)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = base_health * pow(0.58, split_generation)
	add_child(_health)
	_health.died.connect(_on_died)

func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		var push = (global_position - body.global_position).normalized()
		var body_velocity = body.get("velocity")
		velocity += push * 420.0
		body.set("velocity", body_velocity - push * 260.0)

func _on_died() -> void:
	var parent = get_parent()
	if parent != null and split_generation < max_split_generation:
		var count = _rng.randi_range(2, 3)
		for i in range(count):
			var child = SELF_SCENE.instantiate()
			child.split_generation = split_generation + 1
			child.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * 36.0
			child.velocity = Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * (260.0 + split_generation * 120.0)
			# FIX: Defer the addition of the new physics bodies to the tree
			parent.call_deferred("add_child", child)

	if parent != null:
		var sparks = COLLISION_SPARK_SCENE.instantiate()
		sparks.global_position = global_position
		sparks.scale = Vector2(1.6, 1.6)
		# FIX: Defer adding sparks as well to be safe and maintain execution order
		parent.call_deferred("add_child", sparks)

	queue_free()

func _make_chip_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 28.0
	material.spread = 180.0
	material.initial_velocity_min = 12.0
	material.initial_velocity_max = 80.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.0
	material.scale_max = 3.0
	material.color = Color(0.92, 0.68, 0.42, 0.82)
	return material

func _jagged_circle_points(count: int, base_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		var r = base_radius * _rng.randf_range(0.72, 1.16)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	return points
