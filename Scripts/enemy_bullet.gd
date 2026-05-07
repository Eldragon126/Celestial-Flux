extends RigidBody2D

const force_of_impulse = 500
var HomingMissiles: bool = bool(randi_range(0, 1))
var planets: Array = []
var Player: Node2D = null
@export var max_gravity_sources: int = 4

@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var damage_min: float = 9.0
@export var damage_max: float = 14.0

func _ready() -> void:
	_refresh_gravity_sources()
	Player = get_tree().get_first_node_in_group("Player")
	contact_monitor = true
	max_contacts_reported = 2
	
	# Connect signal in code for safety
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var total_grav_accel = Vector2.ZERO
	
	# 1. GRAVITY CALCULATION
	# Loop backwards to safely remove dead planets from the list
	for i in range(planets.size() - 1, -1, -1):
		var planet = planets[i]
		
		# CRITICAL FIX: Check if planet still exists
		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue
			
		var offset = planet.global_position - global_position
		var to_planet_dist = offset.length()
		
		# Only apply gravity within range
		if to_planet_dist < 2000.0:
			var effective_dist = max(to_planet_dist, min_grav_dist)
			var dir = offset.normalized()
			
			var mass_value: Variant = planet.get("mass")
			var mass_type = typeof(mass_value)
			var p_mass = float(mass_value) if mass_type == TYPE_FLOAT or mass_type == TYPE_INT else 100.0
			var strength = gravity_constant * p_mass / (effective_dist * effective_dist)
			total_grav_accel += dir * strength
	
	# Apply gravity force once
	if total_grav_accel != Vector2.ZERO:
		apply_force(total_grav_accel)

	# 2. HOMING LOGIC
	if HomingMissiles:
		if is_instance_valid(Player):
			var to_player_dir = (Player.global_position - global_position).normalized()
			apply_force(to_player_dir * 400)
			
			# Speed Limit Fix: limit_length returns a value, must be assigned
			if linear_velocity.length() > 1200:
				linear_velocity = linear_velocity.limit_length(1200)
				
			linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
			linear_damp = 0.01
		else:
			# Try to find the player again if they respawned
			Player = get_tree().get_first_node_in_group("Player")

func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return

	if body.has_method("take_damage"):
		# Check if it hit the player
		if body.is_in_group("Player"):
			body.take_damage(randf_range(damage_min, damage_max))
			queue_free()
		# Optional: Add logic here if you want it to damage other things
			
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
