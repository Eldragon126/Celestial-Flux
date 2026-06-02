extends Node2D
class_name GravityDebris

@export var mass: float = 85000.0
@export var radius: float = 92.0
@export var lifetime: float = 3.2
@export var particle_cap: int = 42
@export var color: Color = Color(0.78, 0.32, 1.0, 1.0)
@export var drift_drag: float = 4.2
@export var max_drift_speed: float = 420.0

var _age := 0.0
var _drift_velocity := Vector2.ZERO
var _fusion_flash := 0.0
var _fusion_flash_color := Color(0.42, 0.95, 1.0, 1.0)
var _core: Polygon2D = null
var _ring: Line2D = null
var _particles: GPUParticles2D = null

func _ready() -> void:
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	add_to_group("law_gravity_debris")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")
		RuntimeRegistry.register_node(self, &"law_gravity_debris")
	_build_visuals()
	set_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")
		RuntimeRegistry.unregister_node(self, &"law_gravity_debris")

func configure(new_mass: float, new_radius: float, new_lifetime: float, new_color: Color) -> void:
	mass = new_mass
	radius = maxf(new_radius, 24.0)
	lifetime = maxf(new_lifetime, 0.25)
	color = new_color

func _process(delta: float) -> void:
	_age += delta
	if _drift_velocity.length_squared() > 0.1:
		global_position += _drift_velocity * delta
		_drift_velocity = _drift_velocity.lerp(Vector2.ZERO, clampf(delta * drift_drag, 0.0, 1.0))

	_fusion_flash = maxf(_fusion_flash - delta * 3.8, 0.0)
	var remaining := clampf(1.0 - _age / maxf(lifetime, 0.001), 0.0, 1.0)
	rotation += delta * 1.5

	if _core != null:
		_core.scale = Vector2.ONE * (lerpf(0.72, 1.12, remaining) + _fusion_flash * 0.18)
		var core_color := color.lerp(_fusion_flash_color, _fusion_flash)
		_core.color = Color(core_color.r, core_color.g, core_color.b, (0.22 + _fusion_flash * 0.16) * remaining)
	if _ring != null:
		var ring_color := color.lerp(_fusion_flash_color, _fusion_flash)
		_ring.width = lerpf(1.0, 3.2, remaining) + _fusion_flash * 2.2
		_ring.default_color = Color(ring_color.r, ring_color.g, ring_color.b, (0.65 + _fusion_flash * 0.25) * remaining)
	if _particles != null:
		_particles.emitting = remaining > 0.12

	if _age >= lifetime:
		queue_free()

func apply_fusion_impulse(impulse: Vector2, flash_color: Color = Color(0.42, 0.95, 1.0, 1.0)) -> void:
	if impulse == Vector2.ZERO:
		return

	_drift_velocity = (_drift_velocity + impulse).limit_length(max_drift_speed)
	_fusion_flash = 1.0
	_fusion_flash_color = flash_color

func _build_visuals() -> void:
	_core = Polygon2D.new()
	_core.name = "DebrisCore"
	_core.z_index = -5
	_core.polygon = _soft_circle_points(24, radius * 0.65)
	_core.color = Color(color.r, color.g, color.b, 0.22)
	add_child(_core)

	_ring = Line2D.new()
	_ring.name = "DebrisRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.z_index = -4
	_ring.points = _circle_points(36, radius)
	_ring.width = 3.0
	_ring.default_color = Color(color.r, color.g, color.b, 0.65)
	add_child(_ring)

	if particle_cap <= 0:
		return

	_particles = GPUParticles2D.new()
	_particles.name = "DebrisParticles"
	_particles.z_index = -6
	_particles.amount = particle_cap
	_particles.lifetime = 1.4
	_particles.randomness = 0.72
	_particles.process_material = _make_particle_material()
	add_child(_particles)

func _make_particle_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = radius * 0.78
	material.spread = 180.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 48.0
	material.radial_accel_min = -46.0
	material.radial_accel_max = -8.0
	material.orbit_velocity_min = 0.18
	material.orbit_velocity_max = 0.9
	material.gravity = Vector3.ZERO
	material.scale_min = 1.1
	material.scale_max = 3.4
	material.color = Color(color.r, color.g, color.b, 0.72)
	return material

func _circle_points(count: int, point_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * point_radius)
	return points

func _soft_circle_points(count: int, point_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var wave := sin(angle * 3.0) * 0.08 + cos(angle * 8.0) * 0.04
		points.append(Vector2(cos(angle), sin(angle)) * point_radius * (1.0 + wave))
	return points
