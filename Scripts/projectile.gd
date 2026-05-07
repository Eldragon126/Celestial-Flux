extends RigidBody2D

const force_of_impulse = 500
var planets: Array = []
@export var max_gravity_sources: int = 4

@export var gravity_constant: float = 200.0   # Low for arenas
@export var min_grav_dist: float = 50.0     
@export var damage_min: float = 28.0
@export var damage_max: float = 38.0

func _ready() -> void:
	_refresh_gravity_sources()
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
			
			var mass_value: Variant = planet.get("mass")
			var mass_type = typeof(mass_value)
			var p_mass = float(mass_value) if mass_type == TYPE_FLOAT or mass_type == TYPE_INT else 100.0
			var strength = gravity_constant * p_mass / (effective_dist * effective_dist)
			
			total_grav_accel += dir * strength
	
	# FIX: Apply the total accumulated force ONCE outside the loop
	if total_grav_accel != Vector2.ZERO:
		apply_force(total_grav_accel)

func _on_body_entered(body: Node) -> void:
	# RigidBody2D uses contact_monitor, not 'monitoring' (which is for Area2D)
	# To stop further collisions after the first hit:
	if not is_queued_for_deletion():
		if body.has_method("take_damage"): #take damage first and then check if it's in the planet function.
			# Don't hit the player who fired it (if they are in 'Player' group)
			if not body.is_in_group("Player"):
				body.take_damage(randf_range(damage_min, damage_max))
				queue_free()
		elif body.is_in_group("planets"):
			queue_free()


func _on_timer_timeout() -> void:
	queue_free()

func _refresh_gravity_sources() -> void:
	planets.clear()
	var seen = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d = source as Node2D
			if source_2d == null:
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			planets.append(source_2d)

	planets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)

	if max_gravity_sources > 0 and planets.size() > max_gravity_sources:
		planets.resize(max_gravity_sources)
