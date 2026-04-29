extends CharacterBody2D
var Player
var planets: Array[Node] = []
@export var thrust_power: float = 3000.0      # >> gravity for control
@export var rotation_speed: float = 10.0      # rad/s, tune for snappy turns
@export var max_speed: float = 650.0 + randf_range(-100.0, 100.0)
@export var drag: float = 0.55                # Per-frame multiplier (0.9-0.99)
@export var gravity_constant: float = 500.0   # Low for arenas
@export var min_grav_dist: float = 50.0  
var direction_variance = Vector2(randf_range(-0.2,0.2),randf_range(-0.2,0.2))
func _ready() -> void:
	Player = get_tree().get_first_node_in_group("Player")
	planets = get_tree().get_nodes_in_group("planets")
	var scale_size = randf_range(0.8,1.2)
	scale = Vector2(scale_size,scale_size)

func _process(delta: float) -> void:
	var Closest_Planet = null
	var grav_accel = Vector2.ZERO
	for planet in planets:
		
		var dir
		var to_planet
		var strength
		to_planet = global_position.distance_to(planet.global_position)
		if to_planet < 600:
			Closest_Planet = planet
		if to_planet < min_grav_dist: to_planet = min_grav_dist
		dir = (planet.global_position - global_position).normalized()
		strength = gravity_constant * planet.mass / (to_planet * to_planet)
		grav_accel += dir * strength
	var direction_to_go
	if Player != null: 
		#print("Player Global Position is: " + str(Player.global_position))
		direction_to_go = (Player.global_position - global_position).normalized()
		#print("direction to go is: " + str(direction_to_go))
		velocity += (direction_to_go + direction_variance) * thrust_power
		#rotation = direction_to_go.angle() #Negative would be good for a square enemy
		rotation = (global_position - Player.global_position).normalized().angle()
	else: 
		#print("No player was found.")
		Player = get_tree().get_first_node_in_group("Player")
	
	velocity += grav_accel * delta
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)
	move_and_slide()
	
# This allows bullets to just call body.take_damage() without searching for the component
func take_damage(amount: float):
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)

# This function is triggered by the HealthComponent's 'died' signal
func _on_health_component_died():
	var p = $GPUParticles2D2
	p.emitting = false
	p.reparent(get_tree().current_scene)
	# Add explosion effects, score, or item drops here
	queue_free() # Destroys the enemy


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# We call the same take_damage function
		body.take_damage(20.0) 
		
		# Optional: Bounce the enemy back so they don't multi-hit every frame
		var knockback_dir = (global_position - body.global_position).normalized()
		velocity += knockback_dir * 600
		body.velocity -= knockback_dir * 600
