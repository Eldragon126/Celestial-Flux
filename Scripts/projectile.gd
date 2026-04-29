extends RigidBody2D
const force_of_impulse = 500
var mouse
var planets
@export var gravity_constant: float = 200.0   # Low for arenas
@export var min_grav_dist: float = 50.0    
func _ready() -> void:
	#var mouse = get_global_mouse_position()
	#var direction = mouse - global_position
	#direction = direction.normalized()
	#apply_impulse(direction * force_of_impulse)
	planets = get_tree().get_nodes_in_group("planets")
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


func _on_body_entered(body: Node) -> void:
	set_deferred("monitoring", false) 
	set_deferred("monitorable", false)
	if body.has_method("take_damage"):
		if not body.is_in_group("Player"):
			body.take_damage(4 + randi_range(-2,3))
			queue_free()
	elif body.is_in_group("planets"):
		queue_free()
	else:
		set_deferred("monitoring", true) 
		set_deferred("monitorable", true)
		
