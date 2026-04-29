extends CharacterBody2D
@onready var polygon_2d = $Polygon2D
@onready var collision_polygon_2d = $CollisionPolygon2D
@export var gravity_constant: float = 200.0   # Low for arenas
@export var max_speed: float = 500.0
@export var min_grav_dist: float = 50.0 
@export var drag = 0.5
var Player
var planets
func _ready():
	#collision_polygon_2d.polygon = polygon_2d.polygon
	#$CollisionPolygon2D.rotation_degrees = 90
	Player = get_tree().get_first_node_in_group("Player")
	planets = get_tree().get_nodes_in_group("planets")
	
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
		if Player != null: 
			var direction_to_go = (Player.global_position - global_position).normalized()
			if  global_position.distance_to(Player.global_position) < 300:
				velocity += direction_to_go * 100
				velocity = velocity.limit_length(200)
			else: 
				velocity += (direction_to_go) * 500
			rotation = (global_position - Player.global_position).normalized().angle()
				
		else:
			Player = get_tree().get_first_node_in_group("Player")
			
		velocity += grav_accel * delta
		velocity *= pow(drag, delta * 60.0)
		velocity = velocity.limit_length(max_speed)
		move_and_slide()


func _on_shoot_animation_animation_started(anim_name: StringName) -> void:
	if anim_name == "Blast":
		var projectile_scene = load("res://Nodes/enemy_bullet.tscn")
		var projectile = projectile_scene.instantiate()
		var force_of_impulse = 900
		if Player != null: 
			var projectile_direction = (Player.global_position - global_position).normalized()
			projectile.apply_impulse(projectile_direction * force_of_impulse)
		else: 
			Player = get_tree().get_first_node_in_group("Player")
		projectile.global_position = $ShootGPU.global_position
		get_parent().add_child.call_deferred(projectile)
		print("Projectile Created.")
		



func _on_shoot_animation_animation_finished(anim_name: StringName) -> void:
	$ShootAnimation.play("Blast")
# Add this to both base_enemy.gd and base_shooter_enemy.gd

# This allows bullets to just call body.take_damage() without searching for the component
func take_damage(amount: float):
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)

# This function is triggered by the HealthComponent's 'died' signal
func _on_health_component_died():
	# Add explosion effects, score, or item drops here
	queue_free() # Destroys the enemy


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# We call the same take_damage function
		body.take_damage(20.0) 
		
		# Optional: Bounce the enemy back so they don't multi-hit every frame
		var knockback_dir = (global_position - body.global_position).normalized()
		velocity += knockback_dir * 500
		body.velocity -= knockback_dir * 400
