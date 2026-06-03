extends RigidBody2D

# ========================
# == EXPORT VARIABLES ==
# ========================
@export var max_gravity_sources: int = 4
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var damage_min: float = 28.0
@export var damage_max: float = 38.0
@export var momentum_damage_cap: float = 2.75

@export var initial_speed: float = 1080.0
@export var gravity_pull_radius: float = 2000.0
@export var player_gravity_deadzone_radius: float = 520.0
@export var debug_logging: bool = false

@export_group("Projectile Readability")
@export var windowkill_visual_scale: float = 1.18
@export var vector_trail_length: float = 142.0
@export var vector_trail_width: float = 6.2
@export var vector_trail_alpha: float = 0.54
@export var vector_core_color: Color = Color(0.42, 1.0, 0.92, 1.0)

@export_group("Vector Anomaly Upgrade Responses")
@export var relativistic_rail_acceleration: float = 640.0
@export var relativistic_rail_speed_cap: float = 2850.0
@export var relativistic_rail_warp_threshold: float = 1550.0
@export var relativistic_trail_max_length: float = 360.0

# ========================
# == STATE VARIABLES ==
# ========================
var planets: Array[Node2D] = []
var _rail_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _vector_trail_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _has_launched: bool = false
var _rail_trail: Line2D = null
var _vector_trail: Line2D = null
var _rail_heat: float = 0.0

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
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Projectiles")
		RuntimeRegistry.register_node(self, &"player_projectiles")
	
	_configure_windowkill_visuals()
	_refresh_gravity_sources()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if debug_logging:
		print("Projectile instantiated at ", global_position)

func _physics_process(delta: float) -> void:
	var total_grav_accel = Vector2.ZERO
	_apply_relativistic_rail(delta)
	_update_vector_trail(delta)
	if has_meta(&"orbital_satellite_owner"):
		return
	
	# Iterate backwards to safely handle potential deletions
	for i in range(planets.size() - 1, -1, -1):
		var planet = planets[i]
		
		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue
		
		var offset = planet.global_position - global_position
		var distance = offset.length()
		
		# Only apply gravity within a reasonable range
		if _should_ignore_gravity_source(planet):
			continue

		if distance < gravity_pull_radius and distance > 0.0:
			var effective_dist = max(distance, min_grav_dist)
			var dir = offset.normalized()
			
			var p_mass: float = 100.0
			var mass_value = planet.get("mass")
			if mass_value is float or mass_value is int:
				p_mass = float(mass_value)
			
			var strength = gravity_constant * p_mass / (effective_dist * effective_dist)
			total_grav_accel += dir * strength
	
	if total_grav_accel != Vector2.ZERO:
		if Engine.time_scale > 1.0 or Engine.time_scale < 0.97 and Engine.time_scale != 0.0:
			var time_scale_compensation = 1.0 / (Engine.time_scale * Engine.time_scale)
			apply_force(total_grav_accel * time_scale_compensation * 0.08)
			#less gravity when time dilation to compensate for bullets dropping faster. Compensation doesn't work by the way.
		else:
			apply_force(total_grav_accel)

	if linear_velocity.length_squared() > 64.0:
		global_rotation = linear_velocity.angle()
			

# ========================
# == INTEGRATE FORCES ==
# ========================
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# FIX: If the global engine timescale is completely paused, freeze the 
	# simulation velocities completely so the bullet locks perfectly in place.
	if Engine.time_scale == 0.0:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0

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

	_trigger_upgrade_impacts(body)
	
	# 2. Check for damageable targets (Enemies)
	if body.has_method("take_damage"):
		body.take_damage(_roll_damage())
		queue_free()
		return
	elif body.is_in_group("obstacle") or body.is_in_group("Projectiles"):
		#Trying the is_in_group("Projectiles") for now. May take out later.
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


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Projectiles")
		RuntimeRegistry.unregister_node(self, &"player_projectiles")

func _apply_relativistic_rail(delta: float) -> void:
	if not has_meta(&"relativistic_rail_stacks"):
		_update_rail_trail(false, delta)
		return

	var stacks := maxi(int(get_meta(&"relativistic_rail_stacks", 1)), 1)
	var speed := linear_velocity.length()
	if speed <= 1.0:
		_update_rail_trail(false, delta)
		return

	var direction := linear_velocity / speed
	var acceleration := relativistic_rail_acceleration * (1.0 + 0.22 * float(stacks - 1))
	var speed_cap := relativistic_rail_speed_cap * (1.0 + 0.08 * float(stacks - 1))
	linear_velocity = (linear_velocity + direction * acceleration * delta).limit_length(speed_cap)
	global_rotation = linear_velocity.angle()

	var ratio := clampf(linear_velocity.length() / maxf(relativistic_rail_warp_threshold, 1.0), 0.0, 1.0)
	set_meta(&"relativistic_speed_ratio", ratio)
	_update_rail_trail(ratio > 0.08, delta, ratio)


func _update_rail_trail(active: bool, delta: float, ratio: float = 0.0) -> void:
	_rail_heat = lerpf(_rail_heat, ratio if active else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if _rail_heat <= 0.02 and _rail_trail == null:
		return
	if _rail_trail == null:
		_rail_trail = Line2D.new()
		_rail_trail.name = "RelativisticRailTrail"
		_rail_trail.antialiased = true
		_rail_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_rail_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		_rail_trail.z_index = -1
		add_child(_rail_trail)

	var length := lerpf(42.0, relativistic_trail_max_length, _rail_heat)
	_rail_points[0] = Vector2(-length, 0.0)
	_rail_points[1] = Vector2.ZERO
	_rail_trail.points = _rail_points
	_rail_trail.width = lerpf(2.0, 9.0, _rail_heat)
	_rail_trail.default_color = Color(
		lerpf(0.42, 0.72, _rail_heat),
		lerpf(0.86, 1.0, _rail_heat),
		1.0,
		lerpf(0.0, 0.68, _rail_heat)
	)
	_rail_trail.visible = _rail_heat > 0.03


func _configure_windowkill_visuals() -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.color = vector_core_color
		polygon.scale = Vector2.ONE * windowkill_visual_scale

	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light != null:
		light.energy = maxf(light.energy, 2.65)
		light.texture_scale = maxf(light.texture_scale, 0.72)

	_ensure_vector_trail()


func _ensure_vector_trail() -> void:
	if _vector_trail != null:
		return
	_vector_trail = Line2D.new()
	_vector_trail.name = "VectorBoltTrail"
	_vector_trail.antialiased = true
	_vector_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_vector_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_vector_trail.z_index = -2
	add_child(_vector_trail)


func _update_vector_trail(_delta: float) -> void:
	_ensure_vector_trail()
	if _vector_trail == null:
		return

	var speed := linear_velocity.length()
	var speed_ratio := clampf(speed / maxf(initial_speed, 1.0), 0.35, 1.55)
	var length := vector_trail_length * lerpf(0.72, 1.36, clampf((speed_ratio - 0.35) / 1.2, 0.0, 1.0))
	_vector_trail_points[0] = Vector2(-length, 0.0)
	_vector_trail_points[1] = Vector2.ZERO
	_vector_trail.points = _vector_trail_points
	_vector_trail.width = vector_trail_width * lerpf(0.8, 1.18, clampf(speed_ratio, 0.0, 1.0))
	var alpha := vector_trail_alpha
	if Settings != null and Settings.has_method("world_visual_alpha"):
		alpha = Settings.world_visual_alpha(alpha, 0.34)
	_vector_trail.default_color = Color(vector_core_color.r, vector_core_color.g, vector_core_color.b, alpha)
	_vector_trail.visible = speed > 24.0


func _trigger_upgrade_impacts(body: Node) -> void:
	var director := _find_anomaly_director()
	if director == null:
		return

	if has_meta(&"vacuum_collapse_stacks") and director.has_method("trigger_vacuum_collapse"):
		director.call(
			"trigger_vacuum_collapse",
			global_position,
			maxi(int(get_meta(&"vacuum_collapse_stacks", 1)), 1),
			self,
			body
		)

	if has_meta(&"relativistic_rail_stacks") and director.has_method("trigger_relativistic_impact"):
		director.call(
			"trigger_relativistic_impact",
			global_position,
			linear_velocity,
			maxi(int(get_meta(&"relativistic_rail_stacks", 1)), 1),
			self,
			body
		)


func _find_anomaly_director() -> Node:
	var root := get_tree().current_scene
	if root != null:
		var director := root.find_child("VectorAnomalyDirector", true, false)
		if director != null and is_instance_valid(director) and not director.is_queued_for_deletion():
			return director
	return null

# ========================
# == UTILITY ==
# ========================
func _refresh_gravity_sources() -> void:
	if not is_inside_tree():
		return

	planets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			global_position,
			planets,
			max_gravity_sources,
			gravity_pull_radius,
			self
		)
		_filter_ignored_gravity_sources()
		return

	var seen: Dictionary = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == null or not is_instance_valid(source):
				continue
			var source_2d := source as Node2D
			if source_2d == null or source_2d.is_queued_for_deletion():
				continue
			if _should_ignore_gravity_source(source_2d):
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			planets.append(source_2d)

func _on_timer_timeout() -> void:
	queue_free()


func _filter_ignored_gravity_sources() -> void:
	for index in range(planets.size() - 1, -1, -1):
		var source := planets[index]
		if source == null or not is_instance_valid(source) or _should_ignore_gravity_source(source):
			planets.remove_at(index)


func _should_ignore_gravity_source(source: Node2D) -> bool:
	if source == null or source == self or not is_instance_valid(source):
		return true
	if source.is_queued_for_deletion():
		return true
	if source.is_in_group("Player") or source.is_in_group("player_projectiles"):
		return true
	if source.is_ancestor_of(self):
		return true
	if source.global_position.distance_squared_to(global_position) <= player_gravity_deadzone_radius * player_gravity_deadzone_radius:
		if source.is_in_group("Objects_With_Gravity") and not source.is_in_group("planets"):
			return true
	return false
