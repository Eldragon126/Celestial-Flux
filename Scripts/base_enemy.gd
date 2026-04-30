extends CharacterBody2D

@export var thrust_power: float = 3000.0
@export var rotation_speed: float = 10.0
@export var max_speed: float = 650.0
@export var drag: float = 0.55
@export var gravity_constant: float = 500.0
@export var min_grav_dist: float = 50.0

var Player: Node2D
var planets: Array[Node] = []
var direction_variance: Vector2

@onready var trail_particles: GPUParticles2D = $GPUParticles2D2


func _ready() -> void:
	# Randomize stats slightly
	max_speed += randf_range(-100.0, 100.0)
	direction_variance = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))

	var scale_size = randf_range(0.8, 1.2)
	scale = Vector2(scale_size, scale_size)

	Player = get_tree().get_first_node_in_group("Player")
	planets = get_tree().get_nodes_in_group("planets")


func _physics_process(delta: float) -> void:
	if is_instance_valid(trail_particles):
		trail_particles.global_position = global_position


func _process(delta: float) -> void:
	# Refresh player reference if needed
	if not is_instance_valid(Player):
		Player = get_tree().get_first_node_in_group("Player")

	# Clean up planet list
	planets = planets.filter(func(p): return is_instance_valid(p))
	if planets.is_empty():
		planets = get_tree().get_nodes_in_group("planets")

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
		trail_particles.reparent(get_tree().get_current_scene())

	queue_free()


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(20.0)

		# Knockback
		var knockback_dir = (global_position - body.global_position).normalized()
		velocity += knockback_dir * 600

		if "velocity" in body:
			body.velocity -= knockback_dir * 600
