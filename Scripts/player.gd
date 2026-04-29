extends CharacterBody2D

@export var slingshot_factor: float = 1.5 #Multiplier for velocity parallel to planet.
var current_max_speed: float = 800.0
@export var thrust_power: float = 4000.0      # >> gravity for control
@export var rotation_speed: float = 10.0      # rad/s, tune for snappy turns
@export var max_speed: float = 1000.0
@export var drag: float = 0.98              # Per-frame multiplier (0.9-0.99)
@export var gravity_constant: float = 300.0   # Low for arenas
@export var min_grav_dist: float = 50.0       # Avoid div0/singularity
var lastThrustPress := 0.0
var planets: Array[Node] = []  # Populated in _ready
var DRAG_bool : bool = true
var can_dash : bool = true
var shields_on : bool = false
var shield_health : int = 10
func _ready():
	planets = get_tree().get_nodes_in_group("planets")
	if Settings.input_type == false: 
		$Camera2D.ignore_rotation = true
		$Camera2D.rotation_degrees = 0
	else:
		$Camera2D.ignore_rotation = false
		$Camera2D.rotation_degrees = 270
func _physics_process(delta: float):
	
	
	
	# 1. Custom Gravity (sum from all planets)
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
		
	# 2. Rotation (predictable, instant response)
	var rot_input = Input.get_axis("rotate_ccw", "rotate_cw")  # Left=A/D, Right=D/A?
	if Settings.input_type == true: rotation += rot_input * rotation_speed * delta 
	else: rotation = ((global_position - get_global_mouse_position() ).normalized()).angle()
	#rotate parallel to planet IF goofy mode is activated.
	if Closest_Planet != null and Settings.input_type == true: 
		var parallel
		var velocity_dir = velocity.normalized()
		var target_dir = (Closest_Planet.global_position - self.global_position).normalized()
		var cross = velocity_dir.cross(target_dir)
		if cross > 0:
			parallel = PI / 2
			#print("clockwise. The cross is: " + str(cross))
		elif cross < 0:
			parallel = -PI / 2
			#print("Counterclockwise. The cross is: " + str(cross))
		else:
			parallel = 0
		#There is a problem with this on the bottom right of the planet when clockwise and upper right when ocunter clockwise but I don't know why
		rotation = lerp_angle(rotation, (Closest_Planet.global_position - global_position).normalized().angle()  + parallel, 0.005 * Closest_Planet.mass / (global_position.distance_to(Closest_Planet.global_position) * (global_position.distance_to(Closest_Planet.global_position))))
	
	#Calculate Tangential Acceleration (a_t) to increase it around planets.
	var a_t = 0.0
	if velocity.length() > 0 and Closest_Planet != null and (Closest_Planet.global_position - self.global_position).length() < 500 and (Closest_Planet.global_position - self.global_position).length() > 50:
		var grav_dir = grav_accel.normalized()
		# a_t = (grav_accel * velocity) / velocity.length()this is the same as the following code.
		var tangent_dir = grav_dir.orthogonal()
		if tangent_dir.dot(velocity) < 0:
			tangent_dir = -tangent_dir # Flip it if it's pointing backward
		a_t = grav_accel.dot(velocity.normalized())
	# If a_t is positive, we are adding a force to "fall" with gravity.
		if a_t > 0 and DRAG_bool == true: #if the dot product is greater than zero, meaning the velocity component is parallel to the gravity acceleration and drag is on
			var boost_vector = tangent_dir * (a_t * slingshot_factor)
			velocity += boost_vector * delta
			current_max_speed = lerp(current_max_speed, max_speed + (a_t * slingshot_factor), 0.1)
		else:
			current_max_speed = lerp(current_max_speed, max_speed, 0.01)
		#apply velocity
	velocity += grav_accel * delta #add the gravity.
	shoot()
	# 3. Thrust (forward from nose; -transform.x = "backwards" relative to right-facing sprite)

	if Input.is_action_pressed("thrust"):  # W/Space
		var thrust_dir = -transform.x.normalized()  # Assumes sprite points RIGHT
		velocity += thrust_dir * thrust_power * delta
	if Input.is_action_just_released("thrust"):
		var thrust_dir = -transform.x.normalized()  # Assumes sprite points RIGHT
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - lastThrustPress < 0.5 and can_dash == true:
			boost(thrust_dir)
		lastThrustPress = current_time
	# 4. Drag (essential for tightness—stops on release)
	if DRAG_bool: velocity *= pow(drag, delta * 60.0)  # Frame-rate independent
	
	# 5. Clamp & Move (predictable collisions)
	velocity = velocity.limit_length(current_max_speed)
	move_and_slide()  # Handles walls/planets if CollisionShape2D
	if Input.is_action_just_released("Toggle"):
		if DRAG_bool == true:
			DRAG_bool = false
		else:
			DRAG_bool = true
	if DRAG_bool == true:
		$CanvasLayer/Drag.text = "Drag: Enabled"
	else:
		$CanvasLayer/Drag.text = "Drag: Disabled"
func boost(thrust_dir):
	print("BOOST")
	velocity += thrust_dir * 100000
	DRAG_bool = false
	current_max_speed = 3000.0
	can_dash = false
	await get_tree().create_timer(0.3).timeout
	$Dash.start()
	DRAG_bool = true
	current_max_speed = 800.0
	print("Timer timed out and everything should be back to normal from the boost.")


func _on_dash_timeout() -> void:
	can_dash = true

func shoot():
	if Input.is_action_just_pressed("shoot"):
		var projectile_scene = load("res://Nodes/projectile.tscn")
		var projectile = projectile_scene.instantiate()
		
		var force_of_impulse = 900
		projectile.apply_impulse(-transform.x.normalized() * force_of_impulse)
		var mouse = get_global_mouse_position()
		var projectile_direction = mouse - global_position
		projectile_direction = projectile_direction.normalized()
		#print("Mouse current position: " + str(mouse))
		projectile.global_position = global_position + -transform.x.normalized() * 70
		#print("player applied a force away from the mouse which was: " + str(-projectile_direction * force_of_impulse))
		get_parent().add_child(projectile)

func _process(delta: float) -> void:
	shield_process()
	
	var mouse_pos = get_global_mouse_position()
	if Settings.input_type == false: 
		$Camera2D.offset = lerp($Camera2D.offset, Vector2((mouse_pos.x - global_position.x),(mouse_pos.y - global_position.y)).normalized() * 200, 0.01)
	else:
		pass
		
func shield_process() -> void:
	if shields_on == true:
		$Shield.show()
		$Shield/Polygon2D.show()
		$Shield/CollisionPolygon2D.show()
	else:
		$Shield.hide()
		$Shield/Polygon2D.hide()
		$Shield/CollisionPolygon2D.hide()

# Inside player.gd

func take_damage(amount: float):
	# Route damage to shields first if they are active
	if shields_on and shield_health > 0:
		shield_health -= 1 # Or subtract the 'amount' if you want heavy hits to do more
		
		# Assuming your player_shield is a child node named "PlayerShield"
		if has_node("Shield"):
			$Shield.hit() 
			
		if shield_health <= 0:
			shields_on = false
			print("Shields depleted!")
	else:
		# If no shields, damage the hull/health component
		if has_node("HealthComponent"):
			$HealthComponent.take_damage(amount)

func _on_health_component_died():
	print("Player Died!")
	get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")
	
	#get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")
	


func _on_health_component_health_changed(current_health: Variant, max_health: Variant) -> void:
	$CanvasLayer/Health.text = "Health: " + str($HealthComponent.current_health)
