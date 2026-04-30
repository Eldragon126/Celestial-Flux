extends RigidBody2D

const force_of_impulse = 500
var planets: Array = []

@export var gravity_constant: float = 200.0   # Low for arenas
@export var min_grav_dist: float = 50.0     

func _ready() -> void:
	planets = get_tree().get_nodes_in_group("planets")
	contact_monitor = true
	max_contacts_reported = 2
	# Connect the signal via code if you haven't in the editor

func _physics_process(delta: float) -> void:
	var total_grav_accel = Vector2.ZERO
	
	# Iterate backwards so we can safely remove dead planets from the array
	for i in range(planets.size() - 1, -1, -1):
		var planet = planets[i]
		
		# FIX: Check if the planet still exists
		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue
			
		var offset = planet.global_position - global_position
		var distance = offset.length()
		
		# Only apply gravity if within range (e.g., 2000 units)
		if distance < 2000.0:
			var effective_dist = max(distance, min_grav_dist)
			var dir = offset.normalized()
			
			# Standard gravity formula: (G * m1 * m2) / r^2
			# We use planet.mass (ensure your planet script has a 'mass' variable)
			var p_mass = planet.get("mass") if "mass" in planet else 100.0
			var strength = gravity_constant * p_mass / (effective_dist * effective_dist)
			
			total_grav_accel += dir * strength
	
	# FIX: Apply the total accumulated force ONCE outside the loop
	if total_grav_accel != Vector2.ZERO:
		apply_force(total_grav_accel)

func _on_body_entered(body: Node) -> void:
	# RigidBody2D uses contact_monitor, not 'monitoring' (which is for Area2D)
	# To stop further collisions after the first hit:
	if not is_queued_for_deletion():
		if body.is_in_group("planets"):
			queue_free()
		elif body.has_method("take_damage"):
			# Don't hit the player who fired it (if they are in 'Player' group)
			if not body.is_in_group("Player"):
				body.take_damage(4 + randi_range(50, 100))
				queue_free()
