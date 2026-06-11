extends Area2D
class_name EnergyDroplet

@export var restore_amount: float = 8.0
@export var pickup_radius: float = 28.0
@export var attract_radius: float = 260.0
@export var attract_acceleration: float = 1800.0
@export var max_speed: float = 520.0
@export var lifetime: float = 7.0
@export var spin_speed: float = 3.8
@export var particle_focus_radius: float = 1500.0
@export var particle_focus_refresh_interval: float = 0.22

var _age: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _core: Polygon2D = null
var _ring: Line2D = null
var _particles: GPUParticles2D = null
var _attract_radius_sq: float = 67600.0
var _particle_focus_radius_sq: float = 2250000.0
var _particle_focus_elapsed: float = 0.0
var _particles_in_focus: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_attract_radius_sq = attract_radius * attract_radius
	_particle_focus_radius_sq = particle_focus_radius * particle_focus_radius
	_cache_player()
	_build_collision()
	_build_visuals()
	_update_particle_focus(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	rotation += spin_speed * delta
	_particle_focus_elapsed += delta
	if _particle_focus_elapsed >= particle_focus_refresh_interval:
		_particle_focus_elapsed = 0.0
		_update_particle_focus(false)

	_update_motion(delta)
	_update_visuals()


func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group(&"Player"):
		return
	var energy: EnergyComponent = body.get_node_or_null("EnergyComponent") as EnergyComponent
	if energy != null and is_instance_valid(energy):
		energy.restore(restore_amount)
	queue_free()


func configure(amount: float, impulse: Vector2) -> void:
	restore_amount = maxf(amount, 0.0)
	_velocity = impulse.limit_length(max_speed)


func _update_motion(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		global_position += _velocity * delta
		_velocity = _velocity.move_toward(Vector2.ZERO, attract_acceleration * 0.18 * delta)
		return

	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length_squared() <= _attract_radius_sq:
		var desired: Vector2 = to_player.normalized() * max_speed
		_velocity = _velocity.move_toward(desired, attract_acceleration * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, attract_acceleration * 0.18 * delta)
	global_position += _velocity * delta


func _update_visuals() -> void:
	var remaining: float = clampf(1.0 - _age / maxf(lifetime, 0.001), 0.0, 1.0)
	var pulse: float = 0.72 + sin(_age * 8.0) * 0.18
	if _core != null:
		_core.scale = Vector2.ONE * pulse
		_core.color = Color(0.2, 0.95, 1.0, 0.82 * remaining)
	if _ring != null:
		_ring.width = 2.0 + pulse
		_ring.default_color = Color(0.6, 1.0, 0.86, 0.58 * remaining)
	if _particles != null:
		_particles.emitting = _particles_in_focus and remaining > 0.08


func _build_collision() -> void:
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "PickupCollision"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = pickup_radius
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	_core = Polygon2D.new()
	_core.name = "EnergyCore"
	_core.polygon = _circle_points(6, pickup_radius * 0.36)
	_core.color = Color(0.2, 0.95, 1.0, 0.82)
	add_child(_core)

	_ring = Line2D.new()
	_ring.name = "EnergyRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.points = _circle_points(18, pickup_radius * 0.74)
	_ring.width = 2.4
	_ring.default_color = Color(0.6, 1.0, 0.86, 0.58)
	add_child(_ring)

	_particles = GPUParticles2D.new()
	_particles.name = "EnergyParticles"
	_particles.amount = 18
	_particles.lifetime = 0.7
	_particles.randomness = 0.56
	_particles.process_material = _make_particle_material()
	add_child(_particles)


func _make_particle_material() -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = pickup_radius * 0.35
	material.spread = 180.0
	material.initial_velocity_min = 6.0
	material.initial_velocity_max = 30.0
	material.radial_accel_min = -18.0
	material.radial_accel_max = 6.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.8
	material.scale_max = 2.2
	material.color = Color(0.2, 0.95, 1.0, 0.58)
	return material


func _circle_points(count: int, point_radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * point_radius)
	return points


func _cache_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var found: Node = tree.get_first_node_in_group(&"Player")
	if found == null or not is_instance_valid(found):
		return
	if not (found is Node2D):
		return
	_player = found as Node2D


func _update_particle_focus(_force: bool) -> void:
	if _particles == null or not is_instance_valid(_particles):
		return
	_cache_player()
	_particles_in_focus = false
	if _player != null and is_instance_valid(_player):
		_particles_in_focus = global_position.distance_squared_to(_player.global_position) <= _particle_focus_radius_sq
	_particles.visible = _particles_in_focus
