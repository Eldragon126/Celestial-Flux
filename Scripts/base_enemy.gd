extends CharacterBody2D

@export var thrust_power: float = 3000.0
@export var rotation_speed: float = 10.0
@export var max_speed: float = 650.0
@export var drag: float = 0.55
@export var gravity_constant: float = 500.0
@export var min_grav_dist: float = 50.0
@export var gravity_refresh_interval: float = 0.45
@export var max_gravity_sources: int = 4
@export var planet_escape_clearance: float = 48.0
@export var planet_escape_force: float = 780.0
@export var planet_escape_spin: float = 260.0

var Player: Node2D
var planets: Array[Node2D] = []
var direction_variance: Vector2
var _gravity_refresh_elapsed = 0.0

@onready var trail_particles: GPUParticles2D = $GPUParticles2D2


func _ready() -> void:
	# Randomize stats slightly
	max_speed += randf_range(-100.0, 100.0)
	direction_variance = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))

	var scale_size = randf_range(0.8, 1.2)
	scale = Vector2(scale_size, scale_size)

	Player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_refresh_planets()


func _process(delta: float) -> void:
	delta *= CombatStatus.get_time_scale(self)
	_gravity_refresh_elapsed += delta

	# Refresh player reference if needed
	if not is_instance_valid(Player):
		Player = MultiplayerTargeting.nearest_player(global_position, get_tree())

	if planets.is_empty() or _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_planets()

	var grav_accel: Vector2 = Vector2.ZERO

	for planet in planets:
		if not is_instance_valid(planet):
			continue

		var distance: float = global_position.distance_to(planet.global_position)

		if distance < min_grav_dist:
			distance = min_grav_dist

		var dir: Vector2 = (planet.global_position - global_position).normalized()

		# ✅ FIXED: Proper mass handling
		var mass: float = 1.0
		if planet.has_method("get"):
			var m = planet.get("mass")
			if typeof(m) == TYPE_FLOAT or typeof(m) == TYPE_INT:
				mass = float(m)

		var strength: float = gravity_constant * mass / (distance * distance)
		grav_accel += dir * strength

	# === Movement towards player ===
	if is_instance_valid(Player):
		var direction_to_player: Vector2 = (Player.global_position - global_position).normalized()

		# Apply thrust
		velocity += (direction_to_player + direction_variance) * thrust_power * delta

		# Rotate toward player
		var target_angle = direction_to_player.angle()
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)

	# Apply gravity
	velocity += grav_accel * delta
	velocity += _planet_escape_velocity(delta)

	# Apply drag
	velocity *= pow(drag, delta * 60.0)

	# Clamp speed
	velocity = velocity.limit_length(max_speed)

	move_and_slide()


# ============================
# DAMAGE & DEATH
# ============================

func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)


func _on_health_component_died() -> void:
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
		trail_particles.reparent(get_tree().get_current_scene(), true)
		if trail_particles.has_method("fade_and_free"):
			trail_particles.call("fade_and_free")

	queue_free()


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(20.0)

		# Knockback
		var knockback_dir = (global_position - body.global_position).normalized()
		velocity += knockback_dir * 600

		CombatStatus.add_velocity(body, -knockback_dir * 600)

func _refresh_planets() -> void:
	_gravity_refresh_elapsed = 0.0
	planets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			global_position,
			planets,
			max_gravity_sources,
			0.0,
			self
		)
		return

	var seen: Dictionary = {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == null or not is_instance_valid(source):
				continue
			var source_2d := source as Node2D
			if source_2d == null or source_2d == self or source_2d.is_queued_for_deletion():
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			planets.append(source_2d)


func _planet_escape_velocity(delta: float) -> Vector2:
	var impulse := Vector2.ZERO
	for planet in planets:
		if planet == null or not is_instance_valid(planet):
			continue
		var radius := _planet_radius(planet)
		var escape_radius := radius + planet_escape_clearance
		var offset := global_position - planet.global_position
		var distance := maxf(offset.length(), 0.001)
		if distance >= escape_radius:
			continue
		var outward := offset / distance
		var tangent := outward.orthogonal()
		if is_instance_valid(Player) and tangent.dot(Player.global_position - global_position) < 0.0:
			tangent = -tangent
		var pressure := 1.0 - clampf(distance / escape_radius, 0.0, 1.0)
		set_meta(&"planet_escape_blastoff", pressure)
		impulse += (outward * planet_escape_force + tangent * planet_escape_spin) * pressure * delta
	return impulse


func _planet_radius(planet: Node2D) -> float:
	var radius_value: Variant = planet.get("radius")
	if radius_value is float or radius_value is int:
		return maxf(float(radius_value), 24.0)
	var collision := planet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return maxf((collision.shape as CircleShape2D).radius, 24.0)
	return 150.0
