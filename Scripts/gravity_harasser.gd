extends CharacterBody2D

# Enemy variant: a moving mass that pulls the player off-course.

@export var mass := 120000.0
@export var move_speed := 460.0
@export var max_speed := 620.0
@export var gravity_radius := 620.0
@export var gravity_strength := 1450.0
@export var max_health := 42.0

var _player: Node = null
var _health: HealthComponent = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("planets")
	_player = get_tree().get_first_node_in_group("Player")
	_build_body()
	_build_health()

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		return

	var to_player = _player.global_position - global_position
	var desired = to_player.normalized() * move_speed
	velocity = velocity.lerp(desired, clampf(delta * 2.2, 0.0, 1.0)).limit_length(max_speed)
	rotation += delta * 2.7
	move_and_slide()
	_pull_player(delta)

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _pull_player(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var offset = global_position - _player.global_position
	var dist = offset.length()
	if dist <= 1.0 or dist > gravity_radius:
		return

	var pull = offset.normalized() * gravity_strength * mass / maxf(dist * dist, 1200.0)
	var player_velocity: Vector2 = _player.get("velocity")
	_player.set("velocity", player_velocity + pull * delta)

func _build_body() -> void:
	var core := Polygon2D.new()
	core.name = "GravityCorePolygon"
	core.color = Color(0.08, 0.9, 0.72, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(0.0, -34.0),
		Vector2(30.0, -10.0),
		Vector2(20.0, 28.0),
		Vector2(-20.0, 28.0),
		Vector2(-30.0, -10.0),
	])
	add_child(core)

	var field := Polygon2D.new()
	field.name = "GravityFieldPolygon"
	field.z_index = -2
	field.color = Color(0.1, 0.95, 0.72, 0.12)
	field.polygon = _circle_points(42, 92.0)
	add_child(field)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)

	var particles := GPUParticles2D.new()
	particles.name = "GravityFieldParticles"
	particles.z_index = -1
	particles.amount = 120
	particles.lifetime = 1.8
	particles.randomness = 0.6
	particles.process_material = _make_field_material()
	add_child(particles)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

func _on_died() -> void:
	queue_free()

func _make_field_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 92.0
	material.spread = 180.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 90.0
	material.radial_accel_min = -120.0
	material.radial_accel_max = -40.0
	material.orbit_velocity_min = 0.3
	material.orbit_velocity_max = 1.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.2
	material.scale_max = 4.0
	material.color = Color(0.0, 1.0, 0.72, 0.72)
	return material

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
