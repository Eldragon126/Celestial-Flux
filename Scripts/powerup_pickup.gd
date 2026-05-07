extends Area2D
class_name PowerupPickup

@export var definition: PowerupDefinition
@export var pickup_radius: float = 46.0
@export var drift_spin: float = 2.4

var _core: Polygon2D
var _ring: Polygon2D

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_collision()
	_build_visuals()

func _process(delta: float) -> void:
	rotation += drift_spin * delta
	if _ring != null:
		_ring.rotation -= drift_spin * 1.7 * delta

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	var inventory = body.get_node_or_null("PowerupInventory") as PowerupInventory
	if inventory == null:
		inventory = PowerupInventory.new()
		inventory.name = "PowerupInventory"
		body.call_deferred("add_child", inventory)
		inventory.call_deferred("apply_powerup", definition)
		queue_free()
		return

	if inventory != null:
		inventory.apply_powerup(definition)

	queue_free()

func _build_collision() -> void:
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pickup_radius
	collision.shape = shape
	add_child(collision)

func _build_visuals() -> void:
	var pickup_color = Color(0.0, 0.9, 1.0, 1.0)
	if definition != null:
		pickup_color = definition.color

	_ring = Polygon2D.new()
	_ring.name = "PowerupRing"
	_ring.color = Color(pickup_color.r, pickup_color.g, pickup_color.b, 0.28)
	_ring.polygon = _circle_points(6, pickup_radius * 0.78)
	add_child(_ring)

	_core = Polygon2D.new()
	_core.name = "PowerupCore"
	_core.color = pickup_color
	_core.polygon = _circle_points(4, pickup_radius * 0.34)
	add_child(_core)

	var particles = GPUParticles2D.new()
	particles.name = "PowerupParticles"
	particles.amount = 50
	particles.lifetime = 1.2
	particles.randomness = 0.5
	particles.process_material = _make_particle_material(pickup_color)
	add_child(particles)

func _make_particle_material(pickup_color: Color) -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = pickup_radius * 0.55
	material.spread = 180.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 42.0
	material.orbit_velocity_min = 0.25
	material.orbit_velocity_max = 0.9
	material.gravity = Vector3.ZERO
	material.scale_min = 1.4
	material.scale_max = 3.6
	material.color = Color(pickup_color.r, pickup_color.g, pickup_color.b, 0.7)
	return material

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
