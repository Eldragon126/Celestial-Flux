extends Node2D

# Decorative planet add-on: a soft polygon atmosphere plus orbiting dust.

var _halo: Polygon2D
var _dust: GPUParticles2D
var _parent_planet: Node = null

func _ready() -> void:
    _parent_planet = get_parent()
    var radius = _get_planet_radius()
    _build_halo(radius)
    _build_dust(radius)

func _process(_delta: float) -> void:
    if _parent_planet == null or not is_instance_valid(_parent_planet):
        return

    var radius = _get_planet_radius()
    if _dust != null and _dust.process_material is ParticleProcessMaterial:
        var material = _dust.process_material as ParticleProcessMaterial
        material.emission_sphere_radius = radius * 1.24

func _build_halo(radius: float) -> void:
    _halo = Polygon2D.new()
    _halo.name = "AtmospherePolygon"
    _halo.z_index = -3
    _halo.color = Color(0.06, 0.78, 1.0, 0.13)
    _halo.polygon = _circle_points(48, radius * 1.32)
    add_child(_halo)

func _build_dust(radius: float) -> void:
    _dust = GPUParticles2D.new()
    _dust.name = "AtmosphereDustParticles"
    _dust.z_index = -2
    _dust.amount = 90
    _dust.lifetime = 5.0
    _dust.randomness = 0.55
    _dust.fixed_fps = 60
    _dust.process_material = _make_dust_material(radius)
    add_child(_dust)

func _make_dust_material(radius: float) -> ParticleProcessMaterial:
    var gradient = Gradient.new()
    gradient.set_color(0, Color(0.36, 0.95, 1.0, 0.36))
    gradient.set_color(1, Color(0.45, 0.2, 1.0, 0.0))

    var texture = GradientTexture1D.new()
    texture.gradient = gradient

    var material = ParticleProcessMaterial.new()
    material.particle_flag_disable_z = true
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = radius * 1.24
    material.spread = 180.0
    material.initial_velocity_min = 6.0
    material.initial_velocity_max = 32.0
    material.orbit_velocity_min = -0.18
    material.orbit_velocity_max = 0.18
    material.gravity = Vector3.ZERO
    material.scale_min = 1.0
    material.scale_max = 3.6
    material.color_ramp = texture
    material.turbulence_enabled = true
    material.turbulence_noise_strength = 0.7
    material.turbulence_noise_scale = 9.0
    return material

func _get_planet_radius() -> float:
    if _parent_planet != null and _parent_planet.get("radius") != null:
        return maxf(float(_parent_planet.get("radius")), 40.0)

    var shape_node = _parent_planet.get_node_or_null("CollisionShape2D") if _parent_planet != null else null
    if shape_node != null and shape_node.shape is CircleShape2D:
        return shape_node.shape.radius

    return 150.0

func _circle_points(count: int, radius: float) -> PackedVector2Array:
    var points = PackedVector2Array()
    for i in range(count):
        var angle = TAU * float(i) / float(count)
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
