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
@export var vector_trail_alpha: float = 0.54
@export var vector_core_color: Color = Color(0.0, 0.85, 1.0, 0.75) # Cyan
@export var vector_trail_fade_color: Color = Color(1.0, 0.35, 0.1, 0.95) # Danger Orange
@export var vector_trail_particle_cap: int = 28
@export var rail_trail_particle_cap: int = 36
@export var visual_pressure_soft_cap: int = 64
@export var visual_pressure_hard_cap: int = 118
@export var trail_focus_radius: float = 1640.0
@export var trail_budget_refresh_interval: float = 0.18
@export var preserve_trail_after_destroy: bool = true

@export_group("Vector Anomaly Upgrade Responses")
@export var relativistic_rail_acceleration: float = 640.0
@export var relativistic_rail_speed_cap: float = 2850.0
@export var relativistic_rail_warp_threshold: float = 1550.0

@export_group("Weapon Payload")
@export var weapon_id: StringName = &"vector_bolt"
@export var weapon_axis_impulse: float = 0.0
@export var weapon_temporal_slow_multiplier: float = 1.0
@export var weapon_temporal_slow_duration: float = 0.0
@export var weapon_pierce_count: int = 0
@export var weapon_resonance_zone_type: int = -1
@export var weapon_resonance_radius: float = 0.0
@export var weapon_resonance_intensity: float = 0.0
@export var weapon_curve_force: float = 0.0
@export var weapon_curve_side: float = 0.0
@export var weapon_curve_frequency: float = 7.0
@export var weapon_planet_damage: float = 0.0

# ========================
# == STATE VARIABLES ==
# ========================
var planets: Array[Node2D] = []
var _has_launched: bool = false
var _rail_trail: CPUParticles2D = null
var _vector_trail: CPUParticles2D = null
var _rail_heat: float = 0.0
var _visual_player: Node2D = null
var _visual_budget_elapsed: float = 999.0
var _visual_pressure: int = 0
var _visual_in_focus: bool = true
var _weapon_payload: Dictionary = {}
var _pierced_body_ids: Dictionary = {}
var _weapon_phase_offset: float = 0.0

# ========================
# == LIFECYCLE ==
# ========================
func _ready() -> void:
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
	_update_visual_budget(delta)
	_apply_relativistic_rail(delta)
	_update_vector_trail(delta)
	_update_projectile_light()
	if has_meta(&"orbital_satellite_owner"):
		return
	
	for i in range(planets.size() - 1, -1, -1):
		var planet = planets[i]
		
		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue
		
		var offset = planet.global_position - global_position
		var distance = offset.length()
		
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
		else:
			apply_force(total_grav_accel)

	if linear_velocity.length_squared() > 64.0:
		global_rotation = linear_velocity.angle()
			
# ========================
# == INTEGRATE FORCES ==
# ========================
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
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
	call_deferred("_apply_launch_velocity", direction)

func _apply_launch_velocity(direction: Vector2) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	linear_velocity = direction.normalized() * initial_speed
	
	if debug_logging:
		print("Projectile LAUNCHED! Total Speed: ", linear_velocity.length())

# ========================
# == COLLISION & DAMAGE ==
# ========================
func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	
	if body.is_in_group("Player"):
		return

	_trigger_upgrade_impacts(body)
	
	if body.has_method("take_damage"):
		body.take_damage(_roll_damage())
		_destroy_projectile()
		return
	elif body.is_in_group("obstacle") or body.is_in_group("Projectiles"):
		_destroy_projectile()
		return
	
	if body.is_in_group("planets") or body.is_in_group("obstacles") or body is StaticBody2D:
		_destroy_projectile()

func _roll_damage() -> float:
	var multiplier: float = 1.0
	if has_meta(&"momentum_damage_multiplier"):
		multiplier = get_meta(&"momentum_damage_multiplier")
	
	multiplier = clampf(multiplier, 1.0, momentum_damage_cap)
	
	var base_damage = randf_range(damage_min, damage_max)
	var final_damage = base_damage * multiplier
	
	if debug_logging:
		print("Dealt Damage: ", final_damage, " (Mult: ", multiplier, ")")
		
	return final_damage

func _destroy_projectile() -> void:
	# Unparent particles so they gracefully fade out instead of instantly disappearing
	var parent = get_parent()
	if parent != null:
		if is_instance_valid(_vector_trail):
			_vector_trail.emitting = false
			if _should_preserve_trail_after_destroy():
				_vector_trail.reparent(parent)
				get_tree().create_timer(_vector_trail.lifetime).timeout.connect(_vector_trail.queue_free)
			else:
				_vector_trail.queue_free()
		
		if is_instance_valid(_rail_trail):
			_rail_trail.emitting = false
			if _should_preserve_trail_after_destroy():
				_rail_trail.reparent(parent)
				get_tree().create_timer(_rail_trail.lifetime).timeout.connect(_rail_trail.queue_free)
			else:
				_rail_trail.queue_free()
			
	queue_free()

func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Projectiles")
		RuntimeRegistry.unregister_node(self, &"player_projectiles")

# ========================
# == VISUALS & PARTICLES ==
# ========================
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
	if not _should_emit_projectile_trails(true):
		if _rail_trail != null:
			_rail_trail.emitting = false
		return
		
	if _rail_trail == null:
		_rail_trail = CPUParticles2D.new()
		_rail_trail.name = "RelativisticRailParticles"
		_rail_trail.z_index = -1
		
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_rail_trail.material = mat
		
		_rail_trail.local_coords = false # Leaves a trail in global space
		_rail_trail.amount = _trail_amount(rail_trail_particle_cap)
		_rail_trail.lifetime = 0.6
		_rail_trail.gravity = Vector2.ZERO
		_rail_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_rail_trail.emission_sphere_radius = 4.0
		
		var ramp = Gradient.new()
		ramp.add_point(0.0, Color(0.86, 1.0, 1.0, 1.0)) # Bright white/blue core
		ramp.add_point(0.5, Color(0.42, 0.72, 1.0, 0.8))
		ramp.add_point(1.0, Color(0.0, 0.2, 1.0, 0.0))
		_rail_trail.color_ramp = ramp
		
		add_child(_rail_trail)

	if _rail_heat > 0.03:
		_rail_trail.emitting = true
		_rail_trail.amount = _trail_amount(rail_trail_particle_cap)
		_rail_trail.scale_amount_min = lerpf(2.0, 6.0, _rail_heat)
		_rail_trail.scale_amount_max = lerpf(4.0, 9.0, _rail_heat)
		_rail_trail.initial_velocity_min = lerpf(5.0, 30.0, _rail_heat)
		_rail_trail.initial_velocity_max = lerpf(15.0, 60.0, _rail_heat)
		_rail_trail.direction = -linear_velocity.normalized()
		_rail_trail.spread = lerpf(15.0, 45.0, _rail_heat)
	else:
		_rail_trail.emitting = false


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
	if not _should_emit_projectile_trails(false):
		return
		
	_vector_trail = CPUParticles2D.new()
	_vector_trail.name = "VectorBoltParticles"
	_vector_trail.z_index = -2
	
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_vector_trail.material = mat
	
	_vector_trail.local_coords = false # Leaves a trail in global space
	_vector_trail.amount = _trail_amount(vector_trail_particle_cap)
	_vector_trail.lifetime = 0.45
	_vector_trail.gravity = Vector2.ZERO
	
	_vector_trail.spread = 180.0
	_vector_trail.initial_velocity_min = 2.0
	_vector_trail.initial_velocity_max = 12.0
	_vector_trail.scale_amount_min = 2.0
	_vector_trail.scale_amount_max = 5.5
	
	var alpha := vector_trail_alpha
	if Settings != null and Settings.has_method("world_visual_alpha"):
		alpha = Settings.world_visual_alpha(alpha, 0.34)
		
	# Mimics the visualizer fade: Main color fading into the danger color, then to transparent
	var ramp = Gradient.new()
	ramp.add_point(0.0, Color(vector_core_color.r, vector_core_color.g, vector_core_color.b, alpha))
	ramp.add_point(0.65, Color(vector_trail_fade_color.r, vector_trail_fade_color.g, vector_trail_fade_color.b, alpha * 0.8))
	ramp.add_point(1.0, Color(vector_trail_fade_color.r, vector_trail_fade_color.g, vector_trail_fade_color.b, 0.0))
	_vector_trail.color_ramp = ramp
	
	add_child(_vector_trail)


func _update_vector_trail(_delta: float) -> void:
	_ensure_vector_trail()
	if _vector_trail == null:
		return

	var speed := linear_velocity.length()
	var can_emit := speed > 24.0 and _should_emit_projectile_trails(false)
	_vector_trail.emitting = can_emit
	if can_emit:
		_vector_trail.amount = _trail_amount(vector_trail_particle_cap)


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
	_destroy_projectile()


func _filter_ignored_gravity_sources() -> void:
	for index in range(planets.size() - 1, -1, -1):
		var source := planets[index]
		if source == null or not is_instance_valid(source) or _should_ignore_gravity_source(source):
			planets.remove_at(index)


func _update_visual_budget(delta: float) -> void:
	_visual_budget_elapsed += delta
	if _visual_budget_elapsed < maxf(trail_budget_refresh_interval, 0.05):
		return
	_visual_budget_elapsed = 0.0
	_visual_pressure = _projectile_pressure()
	_visual_in_focus = _is_in_player_focus()


func _should_emit_projectile_trails(include_upgraded: bool) -> bool:
	if _visual_pressure >= visual_pressure_hard_cap:
		return false
	if not _visual_in_focus:
		return false
	if _visual_pressure >= visual_pressure_soft_cap and not include_upgraded:
		return false
	return true


func _trail_amount(base_cap: int) -> int:
	var cap := maxi(base_cap, 0)
	if cap <= 0:
		return 0
	if _visual_pressure <= visual_pressure_soft_cap:
		return cap
	var span := maxf(float(visual_pressure_hard_cap - visual_pressure_soft_cap), 1.0)
	var pressure := clampf(float(_visual_pressure - visual_pressure_soft_cap) / span, 0.0, 1.0)
	return clampi(int(round(float(cap) * lerpf(0.62, 0.28, pressure))), 4, cap)


func _projectile_pressure() -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(&"Projectiles")
	return get_tree().get_nodes_in_group("Projectiles").size()


func _is_in_player_focus() -> bool:
	if trail_focus_radius <= 0.0:
		return true
	if _visual_player == null or not is_instance_valid(_visual_player):
		_visual_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _visual_player == null or not is_instance_valid(_visual_player):
		return true
	return global_position.distance_squared_to(_visual_player.global_position) <= trail_focus_radius * trail_focus_radius


func _should_preserve_trail_after_destroy() -> bool:
	return preserve_trail_after_destroy and _visual_in_focus and _visual_pressure < visual_pressure_soft_cap


func _update_projectile_light() -> void:
	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light == null:
		return
	var enabled := _visual_in_focus and _visual_pressure < visual_pressure_hard_cap
	light.visible = enabled
	if not enabled:
		return
	var pressure := clampf(float(_visual_pressure) / maxf(float(visual_pressure_soft_cap), 1.0), 0.0, 1.0)
	light.energy = lerpf(2.65, 0.74, pressure)


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
