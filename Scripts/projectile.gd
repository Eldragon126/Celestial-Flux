extends RigidBody2D
#The bullets are off from the projection predictor when time dialation happens.
# ========================
# == EXPORT VARIABLES ==
# ========================
@export var max_gravity_sources: int = 4
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var damage_min: float = 28.0
@export var damage_max: float = 38.0
@export var momentum_damage_cap: float = 2.75

@export var initial_speed: float = 850.0
@export var debug_logging: bool = false

# ========================
# == STATE VARIABLES ==
# ========================
var planets: Array[Node2D] = []
var _has_launched: bool = false

# ========================
# == LIFECYCLE ==
# ========================
func _ready() -> void:
	# RigidBody2D Setup for high-speed detection
	can_sleep = false
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	
	add_to_group("Projectiles")
	add_to_group("player_projectiles")
	
	_refresh_gravity_sources()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if debug_logging:
		print("Projectile instantiated at ", global_position)

func _physics_process(_delta: float) -> void:

	var total_grav_accel = Vector2.ZERO
	
	# Iterate backwards to safely handle potential deletions
	for i in range(planets.size() - 1, -1, -1):
		var planet = planets[i]
		
		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue
		
		var offset = planet.global_position - global_position
		var distance = offset.length()
		
		# Only apply gravity within a reasonable range
		if distance < 2000.0 and distance > 0.0:
			var effective_dist = max(distance, min_grav_dist)
			var dir = offset.normalized()
			
			var p_mass: float = 100.0
			var mass_value = planet.get("mass")
			if mass_value is float or mass_value is int:
				p_mass = float(mass_value)
			
			var strength = gravity_constant * p_mass / (effective_dist * effective_dist)
			total_grav_accel += dir * strength
	
	if total_grav_accel != Vector2.ZERO:
		apply_force(total_grav_accel)
	
	
		
		
		
# ========================
# == LAUNCH LOGIC ==
# ========================
func launch(direction: Vector2 = Vector2.RIGHT) -> void:
	if _has_launched:
		return
	_has_launched = true
	
	global_rotation = direction.angle()
	
	# Deferring velocity application ensures the combat component 
	# has finished modifying initial_speed before we move.
	call_deferred("_apply_launch_velocity", direction)

func _apply_launch_velocity(direction: Vector2) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	
	# initial_speed here includes the bonus from MomentumCombatComponent
	linear_velocity = direction.normalized() * initial_speed
	
	if debug_logging:
		print("Projectile LAUNCHED! Total Speed: ", linear_velocity.length())

# ========================
# == COLLISION & DAMAGE ==
# ========================
func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	
	# 1. Ignore the player so we don't shoot ourselves
	if body.is_in_group("Player"):
		return
	
	# 2. Check for damageable targets (Enemies)
	if body.has_method("take_damage"):
		body.take_damage(_roll_damage())
		queue_free()
		return
	
	# 3. Hit terrain or obstacles
	if body.is_in_group("planets") or body.is_in_group("obstacles") or body is StaticBody2D:
		queue_free()

func _roll_damage() -> float:
	# Retrieve metadata injected by MomentumCombatComponent
	var multiplier: float = 1.0
	if has_meta(&"momentum_damage_multiplier"):
		multiplier = get_meta(&"momentum_damage_multiplier")
	
	# Clamp the multiplier to your defined cap (minimum 1.0 for safety)
	multiplier = clampf(multiplier, 1.0, momentum_damage_cap)
	
	var base_damage = randf_range(damage_min, damage_max)
	var final_damage = base_damage * multiplier
	
	if debug_logging:
		print("Dealt Damage: ", final_damage, " (Mult: ", multiplier, ")")
		
	return final_damage

# ========================
# == UTILITY ==
# ========================
func _refresh_gravity_sources() -> void:
	if not is_inside_tree():
		return

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

func _on_timer_timeout() -> void:
	queue_free()
