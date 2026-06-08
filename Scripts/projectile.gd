extends RigidBody2D

signal projectile_hit(hit_data: Dictionary)

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
@export var weapon_radial_impulse: float = 0.0
@export var weapon_tangent_impulse: float = 0.0
@export var weapon_field_radius: float = 0.0
@export var weapon_field_force: float = 0.0
@export var weapon_field_damage: float = 0.0
@export var weapon_field_slow_multiplier: float = 1.0
@export var weapon_field_slow_duration: float = 0.0
@export var weapon_field_max_targets: int = 18
@export var weapon_scar_type: int = -1
@export var weapon_scar_radius: float = 0.0
@export var weapon_scar_intensity: float = 0.0
@export var weapon_scar_duration: float = 0.0

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
var _field_targets: Array[Node2D] = []

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
	_apply_weapon_curve(delta)
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
	if _already_hit_body(body):
		return

	var rolled_damage := _roll_damage() if body.has_method("take_damage") else 0.0
	_emit_projectile_hit(body, rolled_damage)
	_trigger_upgrade_impacts(body)
	_apply_weapon_contact_effects(body)
	
	if body.has_method("take_damage"):
		body.take_damage(rolled_damage)
		if _should_continue_after_hit(body):
			return
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


func _emit_projectile_hit(body: Node, damage: float) -> void:
	var body_2d := body as Node2D
	var target_position := global_position
	if body_2d != null:
		target_position = body_2d.global_position
	projectile_hit.emit({
		"weapon_id": String(weapon_id),
		"position": global_position,
		"origin": global_position,
		"target_position": target_position,
		"target_name": String(body.name) if body != null else "",
		"target_group": _target_group_label(body),
		"target_has_damage": body.has_method("take_damage") if body != null else false,
		"damage": damage,
		"velocity": linear_velocity,
		"speed": linear_velocity.length(),
		"pierce_index": _pierced_body_ids.size(),
		"owner_peer_id": int(get_meta(&"network_owner_peer_id", 0)),
		"network_spawned": bool(get_meta(&"network_spawned", false)),
	})


func _target_group_label(body: Node) -> String:
	if body == null:
		return ""
	for group_name in ["bosses", "enemies", "wave_enemy", "planets", "obstacle", "obstacles", "Projectiles"]:
		if body.is_in_group(group_name):
			return group_name
	return ""


func _already_hit_body(body: Node) -> bool:
	if body == null:
		return true
	return _pierced_body_ids.has(body.get_instance_id())


func _should_continue_after_hit(body: Node) -> bool:
	if weapon_pierce_count <= 0 or body == null:
		return false
	_pierced_body_ids[body.get_instance_id()] = true
	return _pierced_body_ids.size() <= weapon_pierce_count


func _apply_weapon_contact_effects(body: Node) -> void:
	var body_2d := body as Node2D
	if body_2d == null or not is_instance_valid(body_2d):
		return

	var direction := _current_direction()
	var radial := (body_2d.global_position - global_position).normalized()
	if radial == Vector2.ZERO:
		radial = direction
	var tangent := radial.orthogonal()
	if tangent.dot(linear_velocity) < 0.0:
		tangent = -tangent

	if absf(weapon_axis_impulse) > 0.001:
		CombatStatus.add_velocity(body_2d, direction * weapon_axis_impulse)
	if absf(weapon_radial_impulse) > 0.001:
		CombatStatus.add_velocity(body_2d, radial * weapon_radial_impulse)
	if absf(weapon_tangent_impulse) > 0.001:
		CombatStatus.add_velocity(body_2d, tangent * weapon_tangent_impulse)
	if weapon_temporal_slow_duration > 0.0 and weapon_temporal_slow_multiplier < 1.0:
		CombatStatus.apply_local_time_scale(body_2d, weapon_temporal_slow_multiplier, weapon_temporal_slow_duration)

	_stamp_weapon_resonance(global_position)
	_stamp_weapon_scar(global_position)
	_apply_weapon_field(global_position, body_2d)
	_apply_weapon_planet_damage(body_2d)


func _apply_weapon_planet_damage(body: Node) -> void:
	if weapon_planet_damage <= 0.0 or body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("planets") or not body.has_method("apply_spacetime_damage"):
		return
	var hit_position := global_position
	var body_2d := body as Node2D
	if body_2d != null:
		hit_position = body_2d.global_position
	body.call("apply_spacetime_damage", weapon_planet_damage, hit_position, weapon_id)


func _apply_weapon_curve(delta: float) -> void:
	if absf(weapon_curve_force) <= 0.001:
		return
	var direction := _current_direction()
	var side := signf(weapon_curve_side)
	if side == 0.0:
		side = 1.0
	var phase := Time.get_ticks_msec() / 1000.0 * maxf(weapon_curve_frequency, 0.01) + _weapon_phase_offset
	var pulse := 0.72 + 0.28 * sin(phase)
	apply_force(direction.orthogonal() * side * weapon_curve_force * pulse)
	if linear_velocity.length_squared() > 64.0:
		linear_velocity = linear_velocity.limit_length(maxf(initial_speed * 1.9, initial_speed + 520.0))


func _apply_weapon_field(position: Vector2, hit_body: Node2D) -> void:
	if weapon_field_radius <= 0.0:
		return
	var targets := _collect_weapon_field_targets(position, weapon_field_radius, maxi(weapon_field_max_targets, 1))
	for target in targets:
		if target == null or not is_instance_valid(target) or target == self:
			continue
		if target == hit_body:
			continue
		var offset := target.global_position - position
		var distance := maxf(offset.length(), 1.0)
		var falloff := 1.0 - clampf(distance / weapon_field_radius, 0.0, 1.0)
		var radial := offset / distance
		if absf(weapon_field_force) > 0.001:
			CombatStatus.add_velocity(target, radial * weapon_field_force * falloff)
		if weapon_field_slow_duration > 0.0 and weapon_field_slow_multiplier < 1.0:
			CombatStatus.apply_local_time_scale(target, weapon_field_slow_multiplier, weapon_field_slow_duration * (0.45 + falloff * 0.55))
		if weapon_field_damage > 0.0 and target.has_method("take_damage") and _is_hostile_target(target):
			target.call("take_damage", weapon_field_damage * falloff)
		target.set_meta(&"weapon_field_pressure", falloff)


func _collect_weapon_field_targets(position: Vector2, radius: float, limit: int) -> Array[Node2D]:
	_field_targets.clear()
	var groups: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles", &"law_gravity_debris"]
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, position, radius, limit, false, _field_targets)
		return _field_targets
	var seen := {}
	var radius_squared := radius * radius
	for group_name in groups:
		for value in get_tree().get_nodes_in_group(group_name):
			if limit > 0 and _field_targets.size() >= limit:
				return _field_targets
			var target := value as Node2D
			if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
				continue
			var id := target.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if target.global_position.distance_squared_to(position) <= radius_squared:
				_field_targets.append(target)
	return _field_targets


func _stamp_weapon_resonance(position: Vector2) -> void:
	if weapon_resonance_zone_type < 0 or weapon_resonance_radius <= 0.0:
		return
	var resonance := _find_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	resonance.call(
		"create_manual_resonance_zone",
		position,
		weapon_resonance_radius,
		weapon_resonance_zone_type,
		weapon_resonance_intensity,
		1.15
	)


func _stamp_weapon_scar(position: Vector2) -> void:
	if weapon_scar_type < 0 or weapon_scar_radius <= 0.0 or weapon_scar_intensity <= 0.0:
		return
	var scars := _find_gravity_scar_manager()
	if scars == null or not scars.has_method("create_gravity_scar"):
		return
	scars.call(
		"create_gravity_scar",
		position,
		weapon_scar_radius,
		weapon_scar_type,
		weapon_scar_intensity,
		weapon_scar_duration,
		weapon_id
	)


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

	var vacuum_stacks := _payload_stack_count(&"vacuum_collapse_stacks")
	if vacuum_stacks > 0 and director.has_method("trigger_vacuum_collapse"):
		director.call(
			"trigger_vacuum_collapse",
			global_position,
			vacuum_stacks,
			self,
			body
		)

	var rail_stacks := _payload_stack_count(&"relativistic_rail_stacks")
	if rail_stacks > 0 and director.has_method("trigger_relativistic_impact"):
		director.call(
			"trigger_relativistic_impact",
			global_position,
			linear_velocity,
			rail_stacks,
			self,
			body
		)


func apply_weapon_payload(payload: Dictionary) -> void:
	_weapon_payload = payload.duplicate(true)
	set_meta(&"weapon_payload", _weapon_payload.duplicate(true))
	for key in payload.keys():
		var property_name := String(key)
		if _is_projectile_payload_property(property_name):
			set(property_name, payload[key])
	_apply_payload_stack_meta(&"relativistic_rail_stacks")
	_apply_payload_stack_meta(&"vacuum_collapse_stacks")
	_weapon_phase_offset = float(payload.get("phase_offset", _weapon_phase_offset))
	if is_inside_tree():
		_configure_windowkill_visuals()


func get_weapon_payload() -> Dictionary:
	if not _weapon_payload.is_empty():
		return _weapon_payload.duplicate(true)
	if has_meta(&"weapon_payload"):
		var payload_value: Variant = get_meta(&"weapon_payload")
		if payload_value is Dictionary:
			var payload: Dictionary = payload_value
			return payload.duplicate(true)
	return {}


func _find_anomaly_director() -> Node:
	var root := get_tree().current_scene
	if root != null:
		var director := root.find_child("VectorAnomalyDirector", true, false)
		if director != null and is_instance_valid(director) and not director.is_queued_for_deletion():
			return director
	return null


func _find_resonance_manager() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	var resonance := root.find_child("GravityResonanceManager", true, false)
	if resonance != null and is_instance_valid(resonance) and not resonance.is_queued_for_deletion():
		return resonance
	return null


func _find_gravity_scar_manager() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	var scars := root.find_child("GravityScarManager", true, false)
	if scars != null and is_instance_valid(scars) and not scars.is_queued_for_deletion():
		return scars
	return null


func _payload_stack_count(key: StringName) -> int:
	if has_meta(key):
		return maxi(int(get_meta(key, 0)), 0)
	return maxi(int(_weapon_payload.get(key, 0)), 0)


func _apply_payload_stack_meta(key: StringName) -> void:
	var count := maxi(int(_weapon_payload.get(key, 0)), 0)
	if count > 0:
		set_meta(key, count)
	elif has_meta(key):
		remove_meta(key)


func _is_projectile_payload_property(property_name: String) -> bool:
	return [
		"weapon_id",
		"initial_speed",
		"damage_min",
		"damage_max",
		"gravity_constant",
		"gravity_pull_radius",
		"player_gravity_deadzone_radius",
		"windowkill_visual_scale",
		"vector_core_color",
		"vector_trail_fade_color",
		"weapon_axis_impulse",
		"weapon_temporal_slow_multiplier",
		"weapon_temporal_slow_duration",
		"weapon_pierce_count",
		"weapon_resonance_zone_type",
		"weapon_resonance_radius",
		"weapon_resonance_intensity",
		"weapon_curve_force",
		"weapon_curve_side",
		"weapon_curve_frequency",
		"weapon_planet_damage",
		"weapon_radial_impulse",
		"weapon_tangent_impulse",
		"weapon_field_radius",
		"weapon_field_force",
		"weapon_field_damage",
		"weapon_field_slow_multiplier",
		"weapon_field_slow_duration",
		"weapon_field_max_targets",
		"weapon_scar_type",
		"weapon_scar_radius",
		"weapon_scar_intensity",
		"weapon_scar_duration",
	].has(property_name)


func _current_direction() -> Vector2:
	if linear_velocity.length_squared() > 0.001:
		return linear_velocity.normalized()
	var direction := Vector2.RIGHT.rotated(global_rotation)
	return direction if direction.length_squared() > 0.001 else Vector2.RIGHT


func _is_hostile_target(target: Node) -> bool:
	return target != null and (
		target.is_in_group("enemies")
		or target.is_in_group("wave_enemy")
		or target.is_in_group("bosses")
	)

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
		_visual_player = MultiplayerTargeting.local_player(get_tree())
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
