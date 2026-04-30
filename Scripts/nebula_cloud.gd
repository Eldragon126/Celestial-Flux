extends Area2D

# Celestial hazard: a cloud that slows the player while inside it.

@export var radius := 260.0
@export var speed_multiplier := 0.58
@export var swirl_speed := 0.18

var _affected_bodies := {}
var _swirl: Polygon2D

func _ready() -> void:
    monitoring = true
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _build_collision()
    _build_visuals()

func _process(delta: float) -> void:
    if _swirl != null:
        _swirl.rotation += swirl_speed * delta

func _build_collision() -> void:
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = radius
    collision.shape = shape
    add_child(collision)

func _build_visuals() -> void:
    _swirl = Polygon2D.new()
    _swirl.name = "NebulaPolygon"
    _swirl.color = Color(0.36, 0.15, 0.85, 0.28)
    _swirl.polygon = _soft_cloud_points(44, radius)
    add_child(_swirl)

    var inner := Polygon2D.new()
    inner.name = "NebulaCorePolygon"
    inner.color = Color(0.0, 0.9, 0.82, 0.18)
    inner.polygon = _soft_cloud_points(36, radius * 0.62)
    add_child(inner)

    var particles := GPUParticles2D.new()
    particles.name = "NebulaDust"
    particles.z_index = -1
    particles.amount = 180
    particles.lifetime = 6.5
    particles.randomness = 0.8
    particles.process_material = _make_nebula_material()
    add_child(particles)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("Player"):
        return

    var max_speed = body.get("max_speed")
    if max_speed == null:
        return

    var id := body.get_instance_id()
    if _affected_bodies.has(id):
        return

    _affected_bodies[id] = {
        "body": body,
        "max_speed": float(max_speed),
        "current_max_speed": float(body.get("current_max_speed")),
    }

    body.set("max_speed", float(max_speed) * speed_multiplier)
    body.set("current_max_speed", minf(float(body.get("current_max_speed")), float(body.get("max_speed"))))

func _on_body_exited(body: Node) -> void:
    var id := body.get_instance_id()
    if not _affected_bodies.has(id):
        return

    var original: Dictionary = _affected_bodies[id]
    if is_instance_valid(body):
        body.set("max_speed", original["max_speed"])
        body.set("current_max_speed", maxf(float(body.get("current_max_speed")), minf(original["current_max_speed"], original["max_speed"])))

    _affected_bodies.erase(id)

func _make_nebula_material() -> ParticleProcessMaterial:
    var gradient := Gradient.new()
    gradient.set_color(0, Color(0.25, 0.9, 1.0, 0.45))
    gradient.set_color(1, Color(0.7, 0.2, 1.0, 0.0))

    var texture := GradientTexture1D.new()
    texture.gradient = gradient

    var material := ParticleProcessMaterial.new()
    material.particle_flag_disable_z = true
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = radius
    material.spread = 180.0
    material.initial_velocity_min = 4.0
    material.initial_velocity_max = 34.0
    material.orbit_velocity_min = -0.24
    material.orbit_velocity_max = 0.24
    material.gravity = Vector3.ZERO
    material.scale_min = 2.0
    material.scale_max = 8.0
    material.color_ramp = texture
    material.turbulence_enabled = true
    material.turbulence_noise_strength = 1.0
    material.turbulence_noise_scale = 12.0
    return material

func _soft_cloud_points(count: int, base_radius: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        var wave := sin(angle * 3.0) * 0.08 + cos(angle * 7.0) * 0.05
        var r := base_radius * (1.0 + wave)
        points.append(Vector2(cos(angle), sin(angle)) * r)
    return points
