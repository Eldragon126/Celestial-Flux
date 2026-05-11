extends RigidBody2D

@export var max_gravity_sources: int = 4
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var damage_min: float = 9.0
@export var damage_max: float = 14.0

@export var initial_speed: float = 750.0
@export var homing_strength: float = 400.0
@export var max_speed: float = 1200.0
@export var is_homing: bool = true

var planets: Array[Node2D] = []
var target: Node2D = null
var _has_launched: bool = false

func _ready() -> void:
	can_sleep = false
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	
	target = get_tree().get_first_node_in_group("Player")
	
	_refresh_gravity_sources()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Auto launch after a safe delay (important for Rapier)
	call_deferred("_auto_launch")


func _auto_launch() -> void:
	if _has_launched:
		return
	_has_launched = true
	
	# Launch in the direction the bullet is facing
	var launch_dir = Vector2.RIGHT.rotated(global_rotation)
	linear_velocity = launch_dir * initial_speed
	
	print("Enemy projectile auto-launched | Speed: ", linear_velocity.length())


func _physics_process(_delta: float) -> void:
	var total_force = Vector2.ZERO
	
	# Planetary Gravity
	for i in range(planets.size() - 1, -1, -1):
		var planet = planets[i]
		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue
			
		var offset = planet.global_position - global_position
		var distance = offset.length()
		
		if distance < 2000.0 and distance > 0.0:
			var effective_dist = max(distance, min_grav_dist)
			var dir = offset.normalized()
			
			var p_mass: float = 100.0
			var mass_value = planet.get("mass")
			if mass_value is float or mass_value is int:
				p_mass = float(mass_value)
			
			var strength = gravity_constant * p_mass / (effective_dist * effective_dist)
			total_force += dir * strength
	
	# Homing
	if is_homing and is_instance_valid(target):
		var homing_dir = (target.global_position - global_position).normalized()
		total_force += homing_dir * homing_strength
		# Face target while homing
		global_rotation = homing_dir.angle()
	
	if total_force != Vector2.ZERO:
		apply_force(total_force)
	
	# Speed cap
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.limit_length(max_speed)


func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	
	if body.has_method("take_damage"):
		if body.is_in_group("Player"):
			body.take_damage(randf_range(damage_min, damage_max))
		queue_free()
	
	elif body.is_in_group("planets") or body.is_in_group("obstacles"):
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()


func _refresh_gravity_sources() -> void:
	planets.clear()
	var seen = {}
	
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if not source is Node2D:
				continue
			var id = source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			planets.append(source)
	
	planets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < \
			   b.global_position.distance_squared_to(global_position)
	)
	
	if max_gravity_sources > 0 and planets.size() > max_gravity_sources:
		planets.resize(max_gravity_sources)
