extends StaticBody2D

# Celestial hazard: a small planet-group body that explodes into a bullet ring.

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")
const COLLISION_SPARK_SCENE = preload("res://Nodes/collision_sparks.tscn")

@export var mass = 180000.0
@export var radius = 86.0
@export var min_explosion_delay = 10.0
@export var max_explosion_delay = 20.0
@export var bullet_count = 18
@export var bullet_speed = 780.0

var _timer: Timer
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
    add_to_group("planets")
    add_to_group("Objects_With_Gravity")
    _rng.randomize()
    _build_body()
    _build_timer()

func _build_body() -> void:
    var collision = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = radius
    collision.shape = circle
    add_child(collision)

    var polygon = Polygon2D.new()
    polygon.name = "FracturedMoonPolygon"
    polygon.color = Color(0.58, 0.72, 0.84, 1.0)
    polygon.polygon = _jagged_circle_points(28, radius)
    add_child(polygon)

    var warning_ring = Polygon2D.new()
    warning_ring.name = "WarningGlowPolygon"
    warning_ring.z_index = -1
    warning_ring.color = Color(1.0, 0.26, 0.1, 0.22)
    warning_ring.polygon = _circle_points(36, radius * 1.18)
    add_child(warning_ring)

    var dust = GPUParticles2D.new()
    dust.name = "VolatileDust"
    dust.z_index = -2
    dust.amount = 70
    dust.lifetime = 1.8
    dust.randomness = 0.65
    dust.process_material = _make_dust_material()
    add_child(dust)

func _build_timer() -> void:
    _timer = Timer.new()
    _timer.name = "ExplosionTimer"
    _timer.one_shot = true
    _timer.wait_time = _rng.randf_range(min_explosion_delay, max_explosion_delay)
    _timer.timeout.connect(_explode)
    add_child(_timer)
    _timer.start()

func _explode() -> void:
    var parent = get_parent()
    if parent == null:
        queue_free()
        return

    for i in range(bullet_count):
        var angle = TAU * float(i) / float(bullet_count)
        var direction = Vector2(cos(angle), sin(angle))
        var bullet = ENEMY_BULLET_SCENE.instantiate()
        bullet.global_position = global_position + direction * (radius + 14.0)
        bullet.apply_impulse(direction * bullet_speed)
        parent.call_deferred("add_child", bullet)

    var sparks = COLLISION_SPARK_SCENE.instantiate()
    parent.add_child(sparks)
    sparks.global_position = global_position
    sparks.scale = Vector2(3.0, 3.0)
    queue_free()

func _make_dust_material() -> ParticleProcessMaterial:
    var material = ParticleProcessMaterial.new()
    material.particle_flag_disable_z = true
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = radius
    material.spread = 180.0
    material.initial_velocity_min = 24.0
    material.initial_velocity_max = 90.0
    material.gravity = Vector3.ZERO
    material.radial_accel_min = 4.0
    material.radial_accel_max = 24.0
    material.scale_min = 2.0
    material.scale_max = 6.0
    material.color = Color(1.0, 0.34, 0.08, 0.86)
    material.turbulence_enabled = true
    return material

func _jagged_circle_points(count: int, base_radius: float) -> PackedVector2Array:
    var points = PackedVector2Array()
    for i in range(count):
        var angle = TAU * float(i) / float(count)
        var radius_variation = base_radius * _rng.randf_range(0.82, 1.12)
        points.append(Vector2(cos(angle), sin(angle)) * radius_variation)
    return points

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
    var points = PackedVector2Array()
    for i in range(count):
        var angle = TAU * float(i) / float(count)
        points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
    return points
