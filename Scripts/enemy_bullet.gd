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
@export var debug_logging: bool = false
@export var spawn_safe_time: float = 0.38

# Extra tuning
@export var homing_gravity_blend: float = 0.002
@export var minimum_homing_scale: float = 0.15
@export var homing_speed_floor_ratio: float = 0.45

var planets: Array[Node2D] = []
var target: Node2D = null

var _has_launched: bool = false
var _configured_launch_direction := Vector2.ZERO
var _configured_launch_speed := 0.0
var _source_id := -1
var _spawn_safe_until := 0.0


func _ready() -> void:
	can_sleep = false
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4

	add_to_group("Projectiles")
	add_to_group("enemy_projectiles")

	target = get_tree().get_first_node_in_group("Player")

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
	var time_scale := CombatStatus.get_time_scale(self)

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

		if distance < 2000.0 and distance > 0.0:
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

			total_force += dir * strength * time_scale

	if total_force != Vector2.ZERO:
		apply_force(total_force)

	# =========================
	# Homing Steering
	# =========================
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
			var steer_amount := homing_strength * homing_scale * time_scale * delta

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
	if is_queued_for_deletion():
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
			body.take_damage(
				randf_range(damage_min, damage_max) * 1.65
			)
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
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(
			randf_range(damage_min, damage_max)
		)
		queue_free()

	elif (
		body.is_in_group("planets")
		or body.is_in_group("obstacles")
	):
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()


func _refresh_gravity_sources() -> void:
	if not is_inside_tree():
		return

	planets.clear()

	var seen := {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):

			if not source is Node2D:
				continue

			var id := source.get_instance_id()

			if seen.has(id):
				continue

			seen[id] = true
			planets.append(source)

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
