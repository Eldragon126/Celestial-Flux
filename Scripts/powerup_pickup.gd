extends Area2D
class_name PowerupPickup

@export var definition: PowerupDefinition
@export var pickup_radius: float = 46.0
@export var drift_spin: float = 2.4
@export var particle_focus_radius: float = 1500.0
@export var particle_focus_refresh_interval: float = 0.2
@export var planet_clearance: float = 92.0
@export var planet_pushout_attempts: int = 4

var _core: Polygon2D = null
var _ring: Polygon2D = null
var _particles: GPUParticles2D = null
var _player: Node2D = null
var _particle_focus_elapsed: float = 0.0
var _particle_focus_radius_sq: float = 2250000.0

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_particle_focus_radius_sq = particle_focus_radius * particle_focus_radius
	_cache_player()
	_push_out_of_planets()
	_build_collision()
	_build_visuals()
	_update_particle_focus(true)
	call_deferred("_push_out_of_planets")

func _process(delta: float) -> void:
	rotation += drift_spin * delta
	if _ring != null:
		_ring.rotation -= drift_spin * 1.7 * delta
	_particle_focus_elapsed += delta
	if _particle_focus_elapsed >= particle_focus_refresh_interval:
		_particle_focus_elapsed = 0.0
		_update_particle_focus(false)

func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Player"):
		return

	var inventory: PowerupInventory = body.get_node_or_null("PowerupInventory") as PowerupInventory
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
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = pickup_radius
	collision.shape = shape
	add_child(collision)

func _build_visuals() -> void:
	var pickup_color: Color = Color(0.0, 0.9, 1.0, 1.0)
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

	_particles = GPUParticles2D.new()
	_particles.name = "PowerupParticles"
	_particles.amount = 36
	_particles.lifetime = 1.2
	_particles.randomness = 0.5
	_particles.process_material = _make_particle_material(pickup_color)
	add_child(_particles)
	_update_particle_focus(true)

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
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
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
	var in_focus: bool = false
	if _player != null and is_instance_valid(_player):
		in_focus = global_position.distance_squared_to(_player.global_position) <= _particle_focus_radius_sq
	_particles.visible = in_focus
	_particles.emitting = in_focus


func _push_out_of_planets() -> void:
	if not is_inside_tree():
		return
	for _attempt in range(maxi(planet_pushout_attempts, 1)):
		var moved := false
		for node in get_tree().get_nodes_in_group(&"planets"):
			var planet := node as Node2D
			if planet == null or planet == self or not is_instance_valid(planet) or planet.is_queued_for_deletion():
				continue
			var min_distance := _planet_radius(planet) + pickup_radius + planet_clearance
			var offset := global_position - planet.global_position
			var distance := offset.length()
			if distance >= min_distance:
				continue
			if distance <= 0.001:
				offset = _fallback_push_direction(planet)
			global_position = planet.global_position + offset.normalized() * min_distance
			moved = true
		if not moved:
			return


func _planet_radius(planet: Node2D) -> float:
	var radius_value: Variant = planet.get("radius")
	if radius_value is float or radius_value is int:
		return float(radius_value) * maxf(planet.scale.x, planet.scale.y)
	var collision := planet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return (collision.shape as CircleShape2D).radius * maxf(planet.scale.x, planet.scale.y)
	return 96.0 * maxf(planet.scale.x, planet.scale.y)


func _fallback_push_direction(planet: Node2D) -> Vector2:
	_cache_player()
	if _player != null and is_instance_valid(_player):
		var away_from_player := global_position - _player.global_position
		if away_from_player.length_squared() > 0.001:
			return away_from_player.normalized()
	var seed := float(planet.get_instance_id() % 997) * 0.017
	return Vector2.RIGHT.rotated(seed)
