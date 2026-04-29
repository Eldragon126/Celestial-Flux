extends RigidBody2D
const force_of_impulse = 500
var HomingMissiles: bool = randi_range(0,1)
var mouse
var planets
var Player
@export var gravity_constant: float = 200.0   # Low for arenas
@export var min_grav_dist: float = 50.0    
func _ready() -> void:
	#var mouse = get_global_mouse_position()
	#var direction = mouse - global_position
	#direction = direction.normalized()
	#apply_impulse(direction * force_of_impulse)
	planets = get_tree().get_nodes_in_group("planets")
	Player = get_tree().get_first_node_in_group("Player")
	contact_monitor = true
	max_contacts_reported = 2
	
func _draw() -> void:
	pass
func _physics_process(delta: float) -> void:
	var Closest_Planet = null
	var grav_accel = Vector2.ZERO
	for planet in planets:
		var dir
		var to_planet
		var strength
		to_planet = global_position.distance_to(planet.global_position)
		if to_planet < 600.0:
			Closest_Planet = planet
		if to_planet < min_grav_dist: to_planet = min_grav_dist
		dir = (planet.global_position - global_position).normalized()
		strength = gravity_constant * planet.mass / (to_planet * to_planet)
		grav_accel += dir * strength
		if to_planet < 2000: apply_force(grav_accel)
	if HomingMissiles == true:
		if Player != null:
			apply_force((Player.global_position - global_position).normalized() * 400)
			if $".".linear_velocity.length() > 1200:
				linear_velocity.limit_length(1200)
			linear_damp_mode = 1
			linear_damp = 0.01
		else:
			Player = get_tree().get_first_node_in_group("Player")
			

func _on_body_entered(body: Node) -> void:
	set_deferred("monitoring", false) 
	set_deferred("monitorable", false)
	if body.has_method("take_damage"):
		if body.is_in_group("Player"): #I also might want it to deal damage to it's own ship later
			body.take_damage(10 + randi_range(-2,3))
			queue_free()
	elif body.is_in_group("planets"):
		queue_free()
	else:
		set_deferred("monitoring", true) 
		set_deferred("monitorable", true)
		
