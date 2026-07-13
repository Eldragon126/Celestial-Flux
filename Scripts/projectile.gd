extends RigidBody2D

signal projectile_hit(hit_data: Dictionary)

# ========================
# == EXPORT VARIABLES ==
# ========================
@export var max_gravity_sources: int = 4
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var max_gravity_acceleration_per_source: float = 2600.0
@export var max_total_gravity_acceleration: float = 5200.0
@export var damage_min: float = 28.0
@export var damage_max: float = 38.0
@export var momentum_damage_cap: float = 2.75

@export var initial_speed: float = 1080.0
@export var gravity_pull_radius: float = 2000.0
@export var gravity_source_refresh_interval: float = 0.22
@export var gravity_refresh_distance_threshold: float = 440.0
@export var player_gravity_deadzone_radius: float = 520.0
@export var debug_logging: bool = false

@export_group("Projectile Cleanup")
@export var max_lifetime: float = 3.8
@export var min_speed_cleanup: float = 38.0
@export var min_speed_cleanup_delay: float = 0.8
@export var low_speed_cleanup_window: float = 0.36
@export var planet_absorb_padding: float = 18.0
@export var planet_orbit_cleanup_margin: float = 92.0
@export var planet_orbit_cleanup_time: float = 0.46
@export var max_gravity_deflections: int = 18
@export_range(0.5, 1.0, 0.01) var deflection_damage_falloff: float = 0.92

@export_group("Projectile Readability")
@export var visual_scale: float = 1.34
@export var vector_trail_alpha: float = 0.66
@export var vector_core_color: Color = Color(0.62, 1.0, 0.98, 1.0)
@export var vector_trail_fade_color: Color = Color(1.0, 0.35, 0.1, 0.95) # Danger Orange
@export var vector_trail_particle_cap: int = 18
@export var rail_trail_particle_cap: int = 28
@export var visual_pressure_soft_cap: int = 56
@export var visual_pressure_hard_cap: int = 104
@export var trail_focus_radius: float = 1640.0
@export var trail_budget_refresh_interval: float = 0.18
@export var preserve_trail_after_destroy: bool = true
@export var enable_vector_wake: bool = true
@export var vector_wake_length: float = 90.0
@export var vector_wake_width: float = 5.4
@export var readability_halo_padding: float = 5.0
@export_range(0.0, 1.0, 0.01) var vector_core_alpha_cap: float = 1.0
@export_range(0.0, 1.0, 0.01) var vector_wake_alpha_cap: float = 0.5
@export var projectile_light_energy_cap: float = 1.85
@export var projectile_light_reduced_flash_energy_cap: float = 0.88

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
var _rail_trail: GPUParticles2D = null
var _vector_trail: GPUParticles2D = null
var _vector_wake: Line2D = null
var _vector_wake_core: Line2D = null
var _readability_halo: Line2D = null
var _rail_heat: float = 0.0
var _visual_player: Node2D = null
var _visual_budget_elapsed: float = 999.0
var _visual_pressure: int = 0
var _visual_in_focus: bool = true
var _weapon_payload: Dictionary = {}
var _pierced_body_ids: Dictionary = {}
var _weapon_phase_offset: float = 0.0
var _field_targets: Array[Node2D] = []
var _destroying_projectile: bool = false
var _wake_phase: float = 0.0
var _age: float = 0.0
var _low_speed_elapsed: float = 0.0
var _near_planet_elapsed: float = 0.0
var _last_near_planet_id: int = -1
var _gravity_deflection_count: int = 0
var _last_gravity_direction := Vector2.ZERO
var _gravity_refresh_elapsed: float = 999.0
var _last_gravity_refresh_position := Vector2.ZERO
var _has_gravity_refresh_position: bool = false

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
	
	_connect_accessibility_settings()
	_configure_windowkill_visuals()
	_refresh_gravity_sources()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if debug_logging:
		print("Projectile instantiated at ", global_position)

func _physics_process(delta: float) -> void:
	if bool(get_meta(&"black_hole_consumed", false)) or _destroying_projectile:
		return
	_age += delta
	var total_grav_accel = Vector2.ZERO
	_update_visual_budget(delta)
	_update_gravity_source_cache(delta)
	_apply_relativistic_rail(delta)
	_apply_weapon_curve(delta)
	_update_vector_trail(delta)
	_update_vector_wake(delta)
	_update_projectile_light()
	if has_meta(&"orbital_satellite_owner"):
		return
	if _update_projectile_cleanup(delta):
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
			var contribution = (dir * strength).limit_length(maxf(max_gravity_acceleration_per_source, 1.0))
			total_grav_accel = (total_grav_accel + contribution).limit_length(maxf(max_total_gravity_acceleration, 1.0))
	
	if total_grav_accel != Vector2.ZERO:
		_track_gravity_deflection(total_grav_accel)
		if max_gravity_deflections > 0 and _gravity_deflection_count > max_gravity_deflections:
			set_meta(&"cleanup_reason", "gravity_deflection_limit")
			_destroy_projectile()
			return
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
	if is_queued_for_deletion() or _destroying_projectile or bool(get_meta(&"black_hole_consumed", false)):
		return
	
	if body.is_in_group("Player"):
		return
	if _should_ignore_projectile_body(body):
		return
	if _already_hit_body(body):
		return

	var rolled_damage := _roll_damage() if body.has_method("take_damage") else 0.0
	_emit_projectile_hit(body, rolled_damage)
	_trigger_upgrade_impacts(body)
	_apply_weapon_contact_effects(body)

	if _is_hostile_projectile(body):
		_destroy_hostile_projectile(body)
		_destroy_projectile()
		return
	
	if body.has_method("take_damage"):
		_stamp_player_weapon_hit(body, rolled_damage)
		body.take_damage(rolled_damage)
		if _should_continue_after_hit(body):
			return
		_destroy_projectile()
		return
	elif body.is_in_group("obstacle"):
		_destroy_projectile()
		return
	
	if body.is_in_group("planets") or body.is_in_group("obstacles") or body is StaticBody2D:
		_destroy_projectile()


func _should_ignore_projectile_body(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return true
	if body.is_in_group("player_allies") or body.is_in_group("campaign_mother_planet"):
		return true
	if not body.is_in_group("Projectiles"):
		return false
	if body == self:
		return true
	if is_in_group("player_projectiles") and body.is_in_group("player_projectiles") and not body.is_in_group("enemy_projectiles"):
		return true
	return false


func _is_hostile_projectile(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return body.is_in_group("enemy_projectiles") and not body.is_in_group("player_projectiles")


func _destroy_hostile_projectile(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if body.has_method("consume_by_black_hole"):
		body.call_deferred("consume_by_black_hole")
	else:
		body.call_deferred("queue_free")

func _roll_damage() -> float:
	var multiplier: float = 1.0
	if has_meta(&"momentum_damage_multiplier"):
		multiplier = get_meta(&"momentum_damage_multiplier")
	if has_meta(&"campaign_damage_multiplier"):
		multiplier *= maxf(float(get_meta(&"campaign_damage_multiplier")), 0.1)
	
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
			var field_damage := weapon_field_damage * falloff
			_stamp_player_weapon_hit(target, field_damage)
			target.call("take_damage", field_damage)
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


func _stamp_player_weapon_hit(target: Node, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set_meta(&"last_player_weapon_hit_time", Time.get_ticks_msec() / 1000.0)
	target.set_meta(&"last_player_weapon_id", String(weapon_id))
	target.set_meta(&"last_player_weapon_hit_damage", damage)
	target.set_meta(&"last_player_weapon_hit_speed", linear_velocity.length())
	var target_2d := target as Node2D
	target.set_meta(&"last_damage_feedback_context", {
		"damage_type": _damage_type_for_weapon(weapon_id),
		"weapon_id": String(weapon_id),
		"hit_position": target_2d.global_position if target_2d != null else global_position,
		"source_position": global_position,
		"source_velocity": linear_velocity,
		"hit_direction": _current_direction(),
		"was_slingshot_hit": bool(has_meta(&"momentum_damage_multiplier")),
		"was_momentum_hit": false,
		"was_apex": bool(get_meta(&"slingshot_apex_projectile", false)),
		"mod_source": _mod_source_for_weapon(weapon_id),
	})


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
	if _destroying_projectile or is_queued_for_deletion():
		return
	_destroying_projectile = true
	# Unparent particles so they gracefully fade out instead of instantly disappearing
	var parent = get_parent()
	if parent != null:
		if is_instance_valid(_vector_trail):
			_vector_trail.emitting = false
			if _should_preserve_trail_after_destroy():
				_vector_trail.reparent(parent)
				var vector_trail := _vector_trail
				var free_vector_trail := func() -> void:
					if vector_trail != null and is_instance_valid(vector_trail) and not vector_trail.is_queued_for_deletion():
						vector_trail.queue_free()
				get_tree().create_timer(vector_trail.lifetime).timeout.connect(free_vector_trail, CONNECT_ONE_SHOT)
			else:
				_queue_free_if_valid(_vector_trail)
		
		if is_instance_valid(_rail_trail):
			_rail_trail.emitting = false
			if _should_preserve_trail_after_destroy():
				_rail_trail.reparent(parent)
				var rail_trail := _rail_trail
				var free_rail_trail := func() -> void:
					if rail_trail != null and is_instance_valid(rail_trail) and not rail_trail.is_queued_for_deletion():
						rail_trail.queue_free()
				get_tree().create_timer(rail_trail.lifetime).timeout.connect(free_rail_trail, CONNECT_ONE_SHOT)
			else:
				_queue_free_if_valid(_rail_trail)
			
	queue_free()


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


func consume_by_black_hole() -> void:
	if _destroying_projectile or is_queued_for_deletion():
		return
	set_meta(&"black_hole_consumed", true)
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	_destroy_projectile()


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
		_rail_trail = GPUParticles2D.new()
		_rail_trail.name = "RelativisticRailParticles"
		_rail_trail.z_index = -1
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_rail_trail.material = mat
		_rail_trail.local_coords = false
		_rail_trail.amount = _trail_amount(rail_trail_particle_cap)
		_rail_trail.lifetime = 0.6
		var ramp = Gradient.new()
		var rail_core := _safe_projectile_color(Color(0.42, 0.9, 1.0, 0.62))
		var rail_mid := _safe_projectile_color(Color(0.28, 0.64, 1.0, 0.44))
		ramp.add_point(0.0, rail_core)
		ramp.add_point(0.5, rail_mid)
		ramp.add_point(1.0, Color(0.0, 0.2, 1.0, 0.0))
		_rail_trail.process_material = _make_projectile_particle_material(ramp, 4.0, 14.0, 34.0, 2.0, 7.0)
		add_child(_rail_trail)

	if _rail_heat > 0.03:
		_rail_trail.emitting = true
		_rail_trail.amount = _trail_amount(rail_trail_particle_cap)
		_update_projectile_particle_material(
			_rail_trail,
			-linear_velocity.normalized(),
			lerpf(12.0, 38.0, _rail_heat),
			lerpf(26.0, 72.0, _rail_heat),
			lerpf(2.0, 6.0, _rail_heat),
			lerpf(4.0, 9.0, _rail_heat),
			lerpf(18.0, 48.0, _rail_heat)
		)
	else:
		_rail_trail.emitting = false


func _configure_windowkill_visuals() -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.color = _safe_projectile_color(vector_core_color)
		polygon.scale = Vector2.ONE * visual_scale
		_center_polygon_visual(polygon)

	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light != null:
		light.energy = minf(maxf(light.energy, 0.85), _projectile_light_cap())
		light.texture_scale = maxf(light.texture_scale, 0.9)

	_ensure_vector_trail()
	_ensure_vector_wake()
	_configure_readability_halo()


func _connect_accessibility_settings() -> void:
	if Settings == null or not Settings.has_signal("accessibility_changed"):
		return
	var callable := Callable(self, "_on_accessibility_changed")
	if not Settings.is_connected("accessibility_changed", callable):
		Settings.connect("accessibility_changed", callable)


func _on_accessibility_changed(_settings: Dictionary) -> void:
	_update_readability_halo_visibility()


func _configure_readability_halo() -> void:
	_readability_halo = get_node_or_null("ReadabilityHalo") as Line2D
	if _readability_halo == null:
		return
	_readability_halo.default_color = _safe_projectile_color(Color(0.85, 1.0, 1.0, 0.95))
	_sync_readability_halo_to_core()
	_update_readability_halo_visibility()


func _sync_readability_halo_to_core() -> void:
	if _readability_halo == null:
		return
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null and polygon.polygon.size() >= 3:
		var transformed_points := PackedVector2Array()
		for point in polygon.polygon:
			transformed_points.append(polygon.position + Vector2(point.x * polygon.scale.x, point.y * polygon.scale.y))
		var center := _points_bounds_center(transformed_points)
		var halo_points := PackedVector2Array()
		var padding := maxf(readability_halo_padding, 0.0)
		for point in transformed_points:
			var offset := point - center
			var halo_point := point
			if offset.length_squared() > 0.001:
				halo_point = center + offset.normalized() * (offset.length() + padding)
			halo_points.append(halo_point)
		if not halo_points.is_empty():
			halo_points.append(halo_points[0])
			_readability_halo.points = halo_points
			_readability_halo.position = Vector2.ZERO
			_readability_halo.rotation = 0.0
			_readability_halo.scale = Vector2.ONE
			_readability_halo.width = maxf(2.4, 2.5 * maxf(visual_scale, 0.7))
			return

	var radius := _projectile_collision_radius() * maxf(visual_scale, 1.0) + maxf(readability_halo_padding, 0.0)
	_readability_halo.points = PackedVector2Array([
		Vector2(-radius, 0.0),
		Vector2(0.0, -radius),
		Vector2(radius, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius, 0.0),
	])


func _center_polygon_visual(polygon: Polygon2D) -> void:
	if polygon == null or polygon.polygon.is_empty():
		return
	var center := _points_bounds_center(polygon.polygon)
	polygon.position = -Vector2(center.x * polygon.scale.x, center.y * polygon.scale.y)


func _points_bounds_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return (min_point + max_point) * 0.5


func _projectile_collision_radius() -> float:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return maxf((collision.shape as CircleShape2D).radius, 1.0)
	return 12.0


func _update_readability_halo_visibility() -> void:
	if _readability_halo == null:
		_readability_halo = get_node_or_null("ReadabilityHalo") as Line2D
	if _readability_halo == null:
		return
	_readability_halo.visible = _readability_halos_enabled() and _visual_in_focus and _visual_pressure < visual_pressure_hard_cap


func _readability_halos_enabled() -> bool:
	return Settings != null and bool(Settings.readability_halos_enabled)


func _ensure_vector_trail() -> void:
	if _vector_trail != null:
		return
	if not _should_emit_projectile_trails(false):
		return
		
	_vector_trail = GPUParticles2D.new()
	_vector_trail.name = "VectorBoltParticles"
	_vector_trail.z_index = -2
	
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_vector_trail.material = mat
	
	_vector_trail.local_coords = false
	_vector_trail.amount = _trail_amount(vector_trail_particle_cap)
	_vector_trail.lifetime = 0.45
	
	var alpha := clampf(vector_trail_alpha, 0.0, 1.0)
	if Settings != null and Settings.has_method("projectile_alpha"):
		alpha = minf(Settings.projectile_alpha(alpha), vector_trail_alpha)
		
	# Mimics the visualizer fade: Main color fading into the danger color, then to transparent
	var ramp = Gradient.new()
	var safe_core := _safe_projectile_color(Color(vector_core_color.r, vector_core_color.g, vector_core_color.b, alpha))
	ramp.add_point(0.0, safe_core)
	ramp.add_point(0.65, Color(vector_trail_fade_color.r, vector_trail_fade_color.g, vector_trail_fade_color.b, alpha * 0.8))
	ramp.add_point(1.0, Color(vector_trail_fade_color.r, vector_trail_fade_color.g, vector_trail_fade_color.b, 0.0))
	_vector_trail.process_material = _make_projectile_particle_material(ramp, 4.0, 4.0, 18.0, 1.7, 4.8)
	
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
		_update_projectile_particle_material(
			_vector_trail,
			-linear_velocity.normalized(),
			5.0,
			18.0,
			1.7,
			4.8,
			24.0
		)


func _make_projectile_particle_material(
	color_ramp: Gradient,
	emission_radius: float,
	initial_velocity_min: float,
	initial_velocity_max: float,
	scale_min: float,
	scale_max: float,
	spread: float = 24.0
) -> ParticleProcessMaterial:
	var process_material := ParticleProcessMaterial.new()
	process_material.particle_flag_disable_z = true
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = emission_radius
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = initial_velocity_min
	process_material.initial_velocity_max = initial_velocity_max
	process_material.scale_min = scale_min
	process_material.scale_max = scale_max
	process_material.spread = spread
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = color_ramp
	process_material.color_ramp = ramp_texture
	return process_material


func _update_projectile_particle_material(
	particles: GPUParticles2D,
	direction: Vector2,
	initial_velocity_min: float,
	initial_velocity_max: float,
	scale_min: float,
	scale_max: float,
	spread: float
) -> void:
	if particles == null or particles.process_material == null:
		return
	var process_material := particles.process_material as ParticleProcessMaterial
	if process_material == null:
		return
	var safe_direction := direction
	if safe_direction.length_squared() <= 0.001:
		safe_direction = Vector2.LEFT
	else:
		safe_direction = safe_direction.normalized()
	process_material.direction = Vector3(safe_direction.x, safe_direction.y, 0.0)
	process_material.initial_velocity_min = initial_velocity_min
	process_material.initial_velocity_max = initial_velocity_max
	process_material.scale_min = scale_min
	process_material.scale_max = scale_max
	process_material.spread = spread


func _ensure_vector_wake() -> void:
	if not enable_vector_wake:
		return
	if _vector_wake == null:
		_vector_wake = Line2D.new()
		_vector_wake.name = "VectorBoltWake"
		_vector_wake.antialiased = true
		_vector_wake.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_vector_wake.end_cap_mode = Line2D.LINE_CAP_ROUND
		_vector_wake.z_index = -3
		add_child(_vector_wake)
	if _vector_wake_core == null:
		_vector_wake_core = Line2D.new()
		_vector_wake_core.name = "VectorBoltWakeCore"
		_vector_wake_core.antialiased = true
		_vector_wake_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_vector_wake_core.end_cap_mode = Line2D.LINE_CAP_ROUND
		_vector_wake_core.z_index = -2
		add_child(_vector_wake_core)


func _update_vector_wake(delta: float) -> void:
	if not enable_vector_wake:
		_set_vector_wake_visible(false)
		return
	_ensure_vector_wake()
	if _vector_wake == null or _vector_wake_core == null:
		return
	_wake_phase += delta
	var speed := linear_velocity.length()
	var visible := speed > 32.0 and _visual_in_focus and _visual_pressure < visual_pressure_hard_cap
	_set_vector_wake_visible(visible)
	if not visible:
		return

	var pressure := clampf(float(_visual_pressure) / maxf(float(visual_pressure_soft_cap), 1.0), 0.0, 1.0)
	var heat := clampf(speed / maxf(initial_speed, 1.0), 0.0, 1.8)
	var rail_ratio := clampf(float(get_meta(&"relativistic_speed_ratio", 0.0)), 0.0, 1.0)
	var length := vector_wake_length * lerpf(0.76, 1.72, clampf(heat, 0.0, 1.0)) * lerpf(1.0, 1.38, rail_ratio)
	var wave := sin(_wake_phase * 22.0 + float(get_instance_id() % 17)) * 3.6 * clampf(heat, 0.0, 1.0)
	var wake_points := PackedVector2Array([
		Vector2(-length, -wave * 0.25),
		Vector2(-length * 0.48, wave),
		Vector2(6.0, 0.0),
	])
	var core_points := PackedVector2Array([
		Vector2(-length * 0.54, 0.0),
		Vector2(8.0, 0.0),
	])
	_vector_wake.points = wake_points
	_vector_wake_core.points = core_points
	_vector_wake.width = vector_wake_width * lerpf(0.72, 1.38, clampf(heat, 0.0, 1.0))
	_vector_wake_core.width = maxf(1.0, vector_wake_width * 0.36)

	var accent := vector_trail_fade_color.lerp(Color(0.36, 1.0, 0.88, 1.0), clampf(rail_ratio + heat * 0.18, 0.0, 0.62))
	var alpha := _safe_visual_alpha(vector_wake_alpha_cap * lerpf(1.0, 0.42, pressure), vector_wake_alpha_cap)
	_vector_wake.default_color = Color(accent.r, accent.g, accent.b, alpha)
	_vector_wake_core.default_color = Color(1.0, 1.0, 1.0, _safe_visual_alpha(0.22 * lerpf(1.0, 0.5, pressure), 0.24))


func _set_vector_wake_visible(visible: bool) -> void:
	if _vector_wake != null:
		_vector_wake.visible = visible
	if _vector_wake_core != null:
		_vector_wake_core.visible = visible

func _safe_visual_alpha(alpha: float, fallback_alpha: float = 1.0) -> float:
	var resolved_alpha := alpha
	if is_nan(resolved_alpha) or is_inf(resolved_alpha):
		resolved_alpha = fallback_alpha

	if Settings != null and Settings.has_method("projectile_alpha"):
		resolved_alpha = minf(float(Settings.projectile_alpha(resolved_alpha)), fallback_alpha)

	if is_nan(resolved_alpha) or is_inf(resolved_alpha):
		resolved_alpha = fallback_alpha

	return clampf(resolved_alpha, 0.0, 1.0)



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
		if property_name == "windowkill_visual_scale":
			visual_scale = float(payload[key])
		elif _is_projectile_payload_property(property_name):
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
		"gravity_source_refresh_interval",
		"gravity_refresh_distance_threshold",
		"max_gravity_acceleration_per_source",
		"max_total_gravity_acceleration",
		"player_gravity_deadzone_radius",
		"visual_scale",
		"vector_trail_alpha",
		"vector_core_color",
		"vector_trail_fade_color",
		"vector_core_alpha_cap",
		"vector_wake_alpha_cap",
		"projectile_light_energy_cap",
		"projectile_light_reduced_flash_energy_cap",
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
		"max_lifetime",
		"planet_absorb_padding",
		"planet_orbit_cleanup_time",
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


func _update_projectile_cleanup(delta: float) -> bool:
	if max_lifetime > 0.0 and _age >= max_lifetime:
		set_meta(&"cleanup_reason", "lifetime")
		_destroy_projectile()
		return true

	var speed := linear_velocity.length()
	if _age >= min_speed_cleanup_delay and min_speed_cleanup > 0.0 and speed <= min_speed_cleanup:
		_low_speed_elapsed += delta
		if _low_speed_elapsed >= low_speed_cleanup_window:
			set_meta(&"cleanup_reason", "low_speed")
			_destroy_projectile()
			return true
	else:
		_low_speed_elapsed = 0.0

	var nearest_orbit_id := -1
	for planet in planets:
		if planet == null or not is_instance_valid(planet) or planet.is_queued_for_deletion():
			continue
		if _should_ignore_gravity_source(planet):
			continue
		var radius := _planet_absorb_radius(planet)
		var distance := planet.global_position.distance_to(global_position)
		if distance <= radius + planet_absorb_padding:
			set_meta(&"cleanup_reason", "planet_absorb")
			_destroy_projectile()
			return true
		if distance <= radius + planet_absorb_padding + planet_orbit_cleanup_margin:
			nearest_orbit_id = planet.get_instance_id()
			break

	if nearest_orbit_id != -1:
		if nearest_orbit_id == _last_near_planet_id:
			_near_planet_elapsed += delta
		else:
			_last_near_planet_id = nearest_orbit_id
			_near_planet_elapsed = 0.0
		if _near_planet_elapsed >= planet_orbit_cleanup_time:
			set_meta(&"cleanup_reason", "planet_orbit_decay")
			_destroy_projectile()
			return true
	else:
		_last_near_planet_id = -1
		_near_planet_elapsed = 0.0

	return false


func _planet_absorb_radius(planet: Node2D) -> float:
	var radius := 0.0
	for property_name in [&"radius", &"base_radius", &"body_radius"]:
		var value: Variant = planet.get(String(property_name))
		if value is float or value is int:
			radius = maxf(radius, float(value))
	var collision := planet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = planet.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		radius = maxf(radius, (collision.shape as CircleShape2D).radius)
	var scale_value := maxf(absf(planet.scale.x), absf(planet.scale.y))
	return maxf(radius * scale_value, 20.0)


func _track_gravity_deflection(acceleration: Vector2) -> void:
	if acceleration.length_squared() <= 0.001:
		return
	var direction := acceleration.normalized()
	if _last_gravity_direction != Vector2.ZERO and direction.dot(_last_gravity_direction) < 0.64:
		_gravity_deflection_count += 1
		if deflection_damage_falloff < 0.999:
			damage_min = maxf(damage_min * deflection_damage_falloff, 1.0)
			damage_max = maxf(damage_max * deflection_damage_falloff, damage_min)
	_last_gravity_direction = direction


func _damage_type_for_weapon(id: StringName) -> StringName:
	var text := String(id).to_lower()
	if text.contains("gravity") or text.contains("singularity") or text.contains("resonance") or text.contains("scar"):
		return &"gravity"
	if text.contains("time") or text.contains("chronal") or text.contains("temporal"):
		return &"temporal"
	if text.contains("beam"):
		return &"beam"
	return &"projectile"


func _mod_source_for_weapon(id: StringName) -> String:
	var text := String(id)
	var slash_index := text.find("/")
	return text.substr(0, slash_index) if slash_index > 0 else ""

# ========================
# == UTILITY ==
# ========================
func _refresh_gravity_sources() -> void:
	if not is_inside_tree():
		return

	planets.clear()
	_gravity_refresh_elapsed = 0.0
	_last_gravity_refresh_position = global_position
	_has_gravity_refresh_position = true
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


func _update_gravity_source_cache(delta: float) -> void:
	_gravity_refresh_elapsed += delta
	if _gravity_refresh_elapsed < maxf(gravity_source_refresh_interval, 0.05):
		return
	if _has_gravity_refresh_position:
		var distance_threshold := maxf(gravity_refresh_distance_threshold, 1.0)
		if (
			global_position.distance_squared_to(_last_gravity_refresh_position)
			< distance_threshold * distance_threshold
		):
			_gravity_refresh_elapsed = 0.0
			return
	_refresh_gravity_sources()

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
	_update_readability_halo_visibility()


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
	light.energy = lerpf(_projectile_light_cap(), 0.42, pressure)


func _safe_projectile_color(color: Color) -> Color:
	var adjusted := color
	if Settings != null and Settings.has_method("apply_readability_color"):
		adjusted = Settings.apply_readability_color(adjusted)
	var alpha := minf(adjusted.a, vector_core_alpha_cap)
	if Settings != null and Settings.has_method("projectile_alpha"):
		alpha = minf(Settings.projectile_alpha(alpha), vector_core_alpha_cap)
	return Color(adjusted.r, adjusted.g, adjusted.b, alpha)


func _projectile_light_cap() -> float:
	var cap := maxf(projectile_light_energy_cap, 0.0)
	if Settings != null and bool(Settings.reduce_flash):
		cap = minf(cap, projectile_light_reduced_flash_energy_cap)
	return cap


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
