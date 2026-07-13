extends RigidBody2D

@export var max_gravity_sources: int = 4
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var gravity_pull_radius: float = 2000.0
@export var gravity_source_refresh_interval: float = 0.24
@export var gravity_refresh_distance_threshold: float = 420.0
@export var max_gravity_acceleration_per_source: float = 2200.0
@export var max_total_gravity_acceleration: float = 4200.0
@export var damage_min: float = 9.0
@export var damage_max: float = 14.0

@export var initial_speed: float = 750.0
@export var homing_strength: float = 400.0
@export var max_speed: float = 1200.0
@export var is_homing: bool = true
@export var debug_logging: bool = false
@export var spawn_safe_time: float = 0.38

# Extra tuning
@export var homing_gravity_blend: float = 0.008
@export var minimum_homing_scale: float = 0.08
@export var homing_speed_floor_ratio: float = 0.45

@export_group("Projectile Cleanup")
@export var max_lifetime: float = 4.8
@export var min_speed_cleanup: float = 34.0
@export var min_speed_cleanup_delay: float = 0.9
@export var low_speed_cleanup_window: float = 0.48
@export var planet_absorb_padding: float = 18.0
@export var planet_orbit_cleanup_margin: float = 78.0
@export var planet_orbit_cleanup_time: float = 0.56

@export_group("Projectile Readability")
@export var enemy_projectile_color: Color = Color(1.0, 0.1, 0.75, 1.0)
@export var captured_projectile_color: Color = Color(0.2, 1.0, 0.85, 1.0)
@export var enemy_projectile_light_energy: float = 2.35
@export var captured_projectile_light_energy: float = 2.2
@export_range(0.0, 1.0, 0.01) var enemy_projectile_alpha_floor: float = 0.72
@export_range(0.0, 1.0, 0.01) var captured_projectile_alpha_floor: float = 0.78
@export var enemy_projectile_light_reduced_flash_cap: float = 0.92
@export var captured_projectile_light_reduced_flash_cap: float = 1.05
@export var visual_pressure_soft_cap: int = 58
@export var visual_pressure_hard_cap: int = 106
@export var trail_focus_radius: float = 1700.0
@export var visual_budget_refresh_interval: float = 0.18

var planets: Array[Node2D] = []
var target: Node2D = null

var _has_launched: bool = false
var _configured_launch_direction := Vector2.ZERO
var _configured_launch_speed := 0.0
var _source_id := -1
var _spawn_safe_until := 0.0
var _ownership_visual_state: StringName = &""
var _consumed_by_black_hole: bool = false
var _age: float = 0.0
var _low_speed_elapsed: float = 0.0
var _near_planet_elapsed: float = 0.0
var _last_near_planet_id: int = -1
var _gravity_refresh_elapsed: float = 999.0
var _last_gravity_refresh_position := Vector2.ZERO
var _has_gravity_refresh_position: bool = false
var _visual_budget_elapsed: float = 999.0
var _visual_pressure: int = 0
var _visual_in_focus: bool = true
var _visual_player: Node2D = null
var _current_projectile_color: Color = Color.WHITE
var _current_light_energy: float = 0.0


func _ready() -> void:
	can_sleep = false
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4

	add_to_group("Projectiles")
	add_to_group("enemy_projectiles")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Projectiles")
		RuntimeRegistry.register_node(self, &"enemy_projectiles")

	_update_ownership_accent()
	target = MultiplayerTargeting.nearest_player(global_position, get_tree())

	_refresh_gravity_sources()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	call_deferred("_auto_launch")


func configure_launch(direction: Vector2, speed: float, source: Node = null) -> void:
	_configured_launch_direction = direction.normalized()
	_configured_launch_speed = maxf(speed, 0.0)

	if _configured_launch_direction == Vector2.ZERO:
		_configured_launch_direction = Vector2.RIGHT.rotated(global_rotation)

	global_rotation = _configured_launch_direction.angle()

	if source != null and is_instance_valid(source):
		_source_id = source.get_instance_id()
		set_meta(&"source_id", _source_id)

		if source is CollisionObject2D:
			add_collision_exception_with(source)

	_spawn_safe_until = Time.get_ticks_msec() / 1000.0 + spawn_safe_time
	set_meta(&"spawn_safe_until", _spawn_safe_until)


func _auto_launch() -> void:
	if _has_launched:
		return

	_has_launched = true

	if _configured_launch_direction != Vector2.ZERO:
		linear_velocity = (
			_configured_launch_direction
			* maxf(_configured_launch_speed, initial_speed)
		)

	elif linear_velocity.length_squared() <= 1.0:
		var launch_dir := Vector2.RIGHT.rotated(global_rotation)
		linear_velocity = launch_dir * initial_speed

	if debug_logging:
		print(
			"Enemy projectile auto-launched | Speed: ",
			linear_velocity.length()
		)


func _physics_process(delta: float) -> void:
	if _consumed_by_black_hole or bool(get_meta(&"black_hole_consumed", false)):
		return
	_age += delta
	_update_visual_budget(delta)
	_update_gravity_source_cache(delta)
	if _update_projectile_cleanup(delta):
		return
	_update_ownership_accent()
	var time_scale: float = CombatStatus.get_time_scale(self)

	var total_force := Vector2.ZERO

	# =========================
	# Planetary Gravity
	# =========================
	for i in range(planets.size() - 1, -1, -1):
		var planet := planets[i]

		if not is_instance_valid(planet):
			planets.remove_at(i)
			continue

		var offset := planet.global_position - global_position
		var distance := offset.length()

		if distance < gravity_pull_radius and distance > 0.0:
			var effective_dist = max(distance, min_grav_dist)
			var dir := offset.normalized()

			var p_mass: float = 100.0
			var mass_value = planet.get("mass")

			if mass_value is float or mass_value is int:
				p_mass = float(mass_value)

			var strength = (
				gravity_constant
				* p_mass
				/ (effective_dist * effective_dist)
			)

			var contribution: Vector2 = (dir * strength * time_scale).limit_length(
				maxf(max_gravity_acceleration_per_source, 1.0)
			)
			total_force = (total_force + contribution).limit_length(
				maxf(max_total_gravity_acceleration, 1.0)
			)

	if total_force != Vector2.ZERO:
		apply_force(total_force)

	# =========================
	# Homing Steering
	# =========================
	if is_homing and not is_instance_valid(target):
		target = MultiplayerTargeting.nearest_player(global_position, get_tree())

	if is_homing and is_instance_valid(target):
		var homing_offset := (
			target.global_position - global_position
		)

		if homing_offset.length_squared() > 1.0:
			var homing_dir := homing_offset.normalized()

			# Gravity weakens homing slightly
			# so orbits/slingshots can still happen.
			var gravity_influence := total_force.length()

			var homing_scale := clampf(
				1.0 - gravity_influence * homing_gravity_blend,
				minimum_homing_scale,
				1.0
			)

			var current_speed := maxf(
				linear_velocity.length(),
				initial_speed * homing_speed_floor_ratio
			)
			var desired_velocity := homing_dir * minf(current_speed, max_speed)
			var steer_amount: float = homing_strength * homing_scale * time_scale * delta

			linear_velocity = linear_velocity.move_toward(
				desired_velocity,
				steer_amount
			)

	# =========================
	# Speed Cap
	# =========================
	var effective_max_speed := (
		max_speed
		* lerpf(0.42, 1.0, time_scale)
	)

	if linear_velocity.length() > effective_max_speed:
		linear_velocity = linear_velocity.limit_length(
			effective_max_speed
		)

	# =========================
	# Visual Rotation
	# =========================
	if linear_velocity.length_squared() > 1.0:
		global_rotation = lerp_angle(
			global_rotation,
			linear_velocity.angle(),
			clampf(time_scale * delta * 8.0, 0.04, 0.32)
		)


func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion() or _consumed_by_black_hole or bool(get_meta(&"black_hole_consumed", false)):
		return

	if _should_ignore_body(body):
		return

	# =========================
	# Reflected / Converted Projectile
	# =========================
	if has_meta(&"converted_to_player_projectile"):
		if body.is_in_group("Player"):
			return

		if body.has_method("take_damage"):
			var converted_damage := randf_range(damage_min, damage_max) * 1.65
			_stamp_damage_feedback_context(body, converted_damage, &"converted_projectile")
			body.take_damage(converted_damage)
			queue_free()

		elif (
			body.is_in_group("planets")
			or body.is_in_group("obstacles")
		):
			queue_free()

		return

	# =========================
	# Normal Enemy Projectile
	# =========================
	if (body.is_in_group("Player") or body.is_in_group("player_allies")) and body.has_method("take_damage"):
		var damage := randf_range(damage_min, damage_max)
		_stamp_damage_feedback_context(body, damage, &"enemy_projectile")
		body.take_damage(damage)
		_emit_direct_damage_feedback_if_needed(body, damage)
		queue_free()

	elif (
		body.is_in_group("planets")
		or body.is_in_group("obstacles")
		or body.is_in_group("Projectiles") #Trying this out for now, 
		#might take it away later.
	):
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()


func consume_by_black_hole() -> void:
	if _consumed_by_black_hole or is_queued_for_deletion():
		return
	_consumed_by_black_hole = true
	set_meta(&"black_hole_consumed", true)
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	queue_free()


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Projectiles")
		RuntimeRegistry.unregister_node(self, &"enemy_projectiles")
		RuntimeRegistry.unregister_node(self, &"player_projectiles")


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
		return

	var seen := {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == null or not is_instance_valid(source):
				continue

			var source_2d := source as Node2D
			if source_2d == null:
				continue

			var id := source_2d.get_instance_id()

			if seen.has(id):
				continue

			seen[id] = true
			planets.append(source_2d)

	planets.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return (
				a.global_position.distance_squared_to(global_position)
				< b.global_position.distance_squared_to(global_position)
			)
	)

	if max_gravity_sources > 0 and planets.size() > max_gravity_sources:
		planets.resize(max_gravity_sources)


func _should_ignore_body(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return true

	if (
		_source_id != -1
		and body.get_instance_id() == _source_id
	):
		return true

	var now := Time.get_ticks_msec() / 1000.0

	var safe_until := maxf(
		_spawn_safe_until,
		float(get_meta(&"spawn_safe_until", 0.0))
	)

	if (
		now < safe_until
		and (
			body.is_in_group("bosses")
			or body.is_in_group("enemies")
		)
	):
		return true

	if (
		not has_meta(&"converted_to_player_projectile")
		and (
			body.is_in_group("bosses")
			or body.is_in_group("enemies")
		)
	):
		return true

	return false


func _update_ownership_accent() -> void:
	var state := &"captured" if has_meta(&"converted_to_player_projectile") else &"enemy"
	if state == _ownership_visual_state:
		return
	_ownership_visual_state = state

	if state == &"captured":
		if is_in_group("enemy_projectiles"):
			remove_from_group("enemy_projectiles")
			if RuntimeRegistry != null:
				RuntimeRegistry.unregister_node(self, &"enemy_projectiles")
		if not is_in_group("player_projectiles"):
			add_to_group("player_projectiles")
			if RuntimeRegistry != null:
				RuntimeRegistry.register_node(self, &"player_projectiles")
		_apply_projectile_color(captured_projectile_color, captured_projectile_light_energy)
	else:
		if not is_in_group("enemy_projectiles"):
			add_to_group("enemy_projectiles")
			if RuntimeRegistry != null:
				RuntimeRegistry.register_node(self, &"enemy_projectiles")
		if is_in_group("player_projectiles"):
			remove_from_group("player_projectiles")
			if RuntimeRegistry != null:
				RuntimeRegistry.unregister_node(self, &"player_projectiles")
		_apply_projectile_color(enemy_projectile_color, enemy_projectile_light_energy)


func _apply_projectile_color(color: Color, light_energy: float) -> void:
	_current_projectile_color = color
	_current_light_energy = light_energy
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.color = _safe_projectile_color(color)
	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light != null:
		light.color = Color(color.r, color.g, color.b, 1.0)
		light.energy = _projectile_light_energy(light_energy)
		light.visible = _projectile_light_visible()


func _safe_projectile_color(color: Color) -> Color:
	var adjusted := color
	if Settings != null and Settings.has_method("apply_readability_color"):
		adjusted = Settings.apply_readability_color(adjusted)
	var alpha := adjusted.a
	if Settings != null and Settings.has_method("projectile_alpha"):
		alpha = float(Settings.projectile_alpha(alpha))
	var floor_alpha := (
		captured_projectile_alpha_floor
		if _ownership_visual_state == &"captured"
		else enemy_projectile_alpha_floor
	)
	var pressure := _projectile_pressure_ratio()
	alpha = maxf(alpha, minf(floor_alpha, adjusted.a))
	alpha *= lerpf(1.0, 0.68, pressure)
	return Color(adjusted.r, adjusted.g, adjusted.b, clampf(alpha, 0.0, adjusted.a))


func _update_visual_budget(delta: float) -> void:
	_visual_budget_elapsed += delta
	if _visual_budget_elapsed < maxf(visual_budget_refresh_interval, 0.05):
		return
	_visual_budget_elapsed = 0.0
	_visual_pressure = _projectile_pressure_count()
	_visual_in_focus = _is_in_player_focus()
	_refresh_current_visuals()


func _refresh_current_visuals() -> void:
	if _ownership_visual_state == &"":
		return
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.color = _safe_projectile_color(_current_projectile_color)
	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light != null:
		light.visible = _projectile_light_visible()
		if light.visible:
			light.energy = _projectile_light_energy(_current_light_energy)


func _projectile_light_visible() -> bool:
	return _visual_in_focus and _visual_pressure < visual_pressure_hard_cap


func _projectile_light_energy(base_energy: float) -> float:
	var cap := base_energy
	if Settings != null and bool(Settings.reduce_flash):
		if _ownership_visual_state == &"captured":
			cap = minf(cap, captured_projectile_light_reduced_flash_cap)
		else:
			cap = minf(cap, enemy_projectile_light_reduced_flash_cap)
	var pressure := _projectile_pressure_ratio()
	return maxf(0.0, minf(base_energy, cap) * lerpf(1.0, 0.38, pressure))


func _projectile_pressure_ratio() -> float:
	if visual_pressure_hard_cap <= visual_pressure_soft_cap:
		return 0.0
	if _visual_pressure <= visual_pressure_soft_cap:
		return 0.0
	var span := float(maxi(visual_pressure_hard_cap - visual_pressure_soft_cap, 1))
	return clampf(float(_visual_pressure - visual_pressure_soft_cap) / span, 0.0, 1.0)


func _projectile_pressure_count() -> int:
	if RuntimeRegistry != null:
		return int(RuntimeRegistry.get_count(&"Projectiles"))
	return get_tree().get_nodes_in_group("Projectiles").size()


func _is_in_player_focus() -> bool:
	if trail_focus_radius <= 0.0:
		return true
	if _visual_player == null or not is_instance_valid(_visual_player):
		_visual_player = MultiplayerTargeting.local_player(get_tree())
	if _visual_player == null or not is_instance_valid(_visual_player):
		return true
	return (
		global_position.distance_squared_to(_visual_player.global_position)
		<= trail_focus_radius * trail_focus_radius
	)


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


func _update_projectile_cleanup(delta: float) -> bool:
	if max_lifetime > 0.0 and _age >= max_lifetime:
		queue_free()
		return true

	var speed := linear_velocity.length()
	if _age >= min_speed_cleanup_delay and min_speed_cleanup > 0.0 and speed <= min_speed_cleanup:
		_low_speed_elapsed += delta
		if _low_speed_elapsed >= low_speed_cleanup_window:
			queue_free()
			return true
	else:
		_low_speed_elapsed = 0.0

	var nearest_orbit_id := -1
	for planet in planets:
		if planet == null or not is_instance_valid(planet) or planet.is_queued_for_deletion():
			continue
		var radius := _planet_absorb_radius(planet)
		var distance := planet.global_position.distance_to(global_position)
		if distance <= radius + planet_absorb_padding:
			queue_free()
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
			queue_free()
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
	return maxf(radius * maxf(absf(planet.scale.x), absf(planet.scale.y)), 20.0)


func _stamp_damage_feedback_context(body: Node, damage: float, damage_type: StringName) -> void:
	if body == null or not is_instance_valid(body):
		return
	var body_2d := body as Node2D
	body.set_meta(&"last_damage_feedback_context", {
		"damage_type": damage_type,
		"amount": damage,
		"source_position": global_position,
		"source_velocity": linear_velocity,
		"hit_position": body_2d.global_position if body_2d != null else global_position,
		"hit_direction": linear_velocity.normalized() if linear_velocity.length_squared() > 0.001 else Vector2.RIGHT.rotated(global_rotation),
	})


func _emit_direct_damage_feedback_if_needed(body: Node, damage: float) -> void:
	if body == null or body.get_node_or_null("HealthComponent") != null:
		return
	var manager := get_tree().get_first_node_in_group("damage_feedback_manager")
	if manager != null and manager.has_method("show_damage"):
		manager.call("show_damage", body, damage, body.get_meta(&"last_damage_feedback_context", {}))
