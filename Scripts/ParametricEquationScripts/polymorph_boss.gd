extends CharacterBody2D

# ============================================================================
# VECTOR ANOMALY: "THE POLYMORPH"
# A shape-shifting geometric boss that mutates:
#
# - Polygon2D visuals
# - CollisionPolygon2D hitbox
# - Movement equations
# - Attack patterns
# - Orbit behavior
#
# Every health phase changes:
# - geometry
# - movement logic
# - bullet behavior
# - emotional tone of the fight
#
# ============================================================================
#
# PHASES
# ----------------------------------------------------------------------------
#
# Phase 1:
#   Stable geometric intelligence
#   Hexagonal orbit entity
#
# Phase 2:
#   Rotating star fracture
#   Splits into aggressive vectors
#
# Phase 3:
#   Chaotic organic spiral
#   Geometry destabilizes
#
# Final Phase:
#   Reality collapse singularity
#   Shape becomes corrupted black sun
#
# ============================================================================

signal boss_health_changed(current_health: float, max_health: float)
signal boss_defeated
signal phase_changed(phase: int)

const BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

# ============================================================================
# CORE
# ============================================================================

@export var max_health := 2400.0
@export var contact_damage := 24.0
@export var bullet_spawn_distance := 155.0

var current_health := 2400.0

var player: Node2D

# ============================================================================
# MOVEMENT
# ============================================================================

var t := 0.0

@export var engine_force := 2400.0
@export var drag := 1.2
@export var max_speed := 900.0
@export var anchor_follow_rate := 2.8

var anchor_position := Vector2.ZERO

# ============================================================================
# PHASE
# ============================================================================

var phase := 1

# ============================================================================
# VISUALS
# ============================================================================

var body_polygon: Polygon2D
var collision_polygon: CollisionPolygon2D
var core_polygon: Polygon2D
var aura_polygon: Polygon2D
var spark_particles: GPUParticles2D

# ============================================================================
# TIMERS
# ============================================================================

var fire_timer: Timer
var morph_timer: Timer
var attack_area: Area2D
var _rng := RandomNumberGenerator.new()

# ============================================================================
# READY
# ============================================================================

func _ready() -> void:

	add_to_group("bosses")
	add_to_group("enemies")
	add_to_group("wave_enemy")

	_rng.randomize()
	player = get_tree().get_first_node_in_group("Player")

	current_health = max_health

	build_visuals()
	build_timers()

	enter_phase(1)

# ============================================================================
# VISUAL SETUP
# ============================================================================

func build_visuals() -> void:
	aura_polygon = get_node_or_null("PolymorphAura") as Polygon2D
	if aura_polygon == null:
		aura_polygon = Polygon2D.new()
		aura_polygon.name = "PolymorphAura"
		aura_polygon.z_index = -4
		aura_polygon.color = Color(0.2, 0.95, 1.0, 0.13)
		add_child(aura_polygon)
	if aura_polygon.polygon.is_empty():
		aura_polygon.polygon = make_circle_points(40, 165.0)

	# ------------------------------------------------------------------------
	# MAIN BODY
	# ------------------------------------------------------------------------

	body_polygon = get_node_or_null("PolymorphBody") as Polygon2D
	if body_polygon == null:
		body_polygon = Polygon2D.new()
		body_polygon.name = "PolymorphBody"
		body_polygon.color = Color(0.1, 0.9, 1.0, 1.0)
		add_child(body_polygon)

	# ------------------------------------------------------------------------
	# CORE
	# ------------------------------------------------------------------------

	core_polygon = get_node_or_null("PolymorphCore") as Polygon2D
	if core_polygon == null:
		core_polygon = Polygon2D.new()
		core_polygon.name = "PolymorphCore"
		core_polygon.color = Color.WHITE
		add_child(core_polygon)
	if core_polygon.polygon.is_empty():
		core_polygon.polygon = make_circle_points(24, 26.0)

	# ------------------------------------------------------------------------
	# COLLISION
	# ------------------------------------------------------------------------

	collision_polygon = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision_polygon == null:
		collision_polygon = CollisionPolygon2D.new()
		collision_polygon.name = "CollisionPolygon2D"
		add_child(collision_polygon)

	attack_area = get_node_or_null("PolymorphContactArea") as Area2D
	if attack_area == null:
		attack_area = Area2D.new()
		attack_area.name = "PolymorphContactArea"
		add_child(attack_area)
	attack_area.monitoring = true
	if not attack_area.body_entered.is_connected(_on_contact_body_entered):
		attack_area.body_entered.connect(_on_contact_body_entered)

	var attack_shape := attack_area.get_node_or_null("ContactShape") as CollisionShape2D
	if attack_shape == null:
		attack_shape = CollisionShape2D.new()
		attack_shape.name = "ContactShape"
		attack_area.add_child(attack_shape)
	if attack_shape.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 136.0
		attack_shape.shape = circle

	spark_particles = get_node_or_null("PolymorphVectorSparks") as GPUParticles2D
	if spark_particles == null:
		spark_particles = GPUParticles2D.new()
		spark_particles.name = "PolymorphVectorSparks"
		spark_particles.amount = 96
		spark_particles.lifetime = 1.4
		spark_particles.randomness = 0.55
		add_child(spark_particles)
	if spark_particles.process_material == null:
		spark_particles.process_material = make_particle_material(Color(0.25, 0.95, 1.0, 0.76))

# ============================================================================
# TIMERS
# ============================================================================

func build_timers() -> void:

	fire_timer = Timer.new()
	fire_timer.wait_time = 1.4
	fire_timer.timeout.connect(fire_attack)
	add_child(fire_timer)
	fire_timer.start()

	morph_timer = Timer.new()
	morph_timer.wait_time = 0.12
	morph_timer.timeout.connect(update_shape_animation)
	add_child(morph_timer)
	morph_timer.start()

# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)

	t += scaled_delta

	update_phase()

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		return

	var offset := get_phase_movement()

	var target := player.global_position + offset

	anchor_position = anchor_position.lerp(
		target,
		scaled_delta * anchor_follow_rate
	)

	var to_target := anchor_position - global_position

	if to_target.length() > 10.0:

		velocity += (
			to_target.normalized()
			* engine_force
			* scaled_delta
		)

	velocity -= velocity * drag * scaled_delta

	velocity = velocity.limit_length(max_speed)

	move_and_slide()

	# rotation drift
	rotation += scaled_delta * (
		0.4
		+ phase * 0.25
	)

	if aura_polygon != null:
		aura_polygon.rotation -= scaled_delta * (0.9 + float(phase) * 0.35)
		aura_polygon.scale = Vector2.ONE * (1.0 + 0.05 * sin(t * 7.0))

# ============================================================================
# PHASE SYSTEM
# ============================================================================

func update_phase() -> void:

	var hp := current_health / max_health

	if hp <= 0.25 and phase != 4:
		enter_phase(4)

	elif hp <= 0.50 and phase != 3:
		enter_phase(3)

	elif hp <= 0.75 and phase != 2:
		enter_phase(2)

# ============================================================================
# ENTER PHASE
# ============================================================================

func enter_phase(new_phase: int) -> void:

	phase = new_phase

	phase_changed.emit(phase)

	match phase:

		# ================================================================
		# PHASE 1
		# ================================================================

		1:

			body_polygon.color = Color(
				0.1,
				0.9,
				1.0
			)

			engine_force = 2200.0
			max_speed = 780.0
			anchor_follow_rate = 2.6

			fire_timer.wait_time = 1.6

		# ================================================================
		# PHASE 2
		# ================================================================

		2:

			body_polygon.color = Color(
				1.0,
				0.3,
				0.2
			)

			engine_force = 3100.0
			max_speed = 1080.0
			anchor_follow_rate = 3.0

			fire_timer.wait_time = 0.92

		# ================================================================
		# PHASE 3
		# ================================================================

		3:

			body_polygon.color = Color(
				0.9,
				0.1,
				0.8
			)

			engine_force = 4300.0
			max_speed = 1450.0
			anchor_follow_rate = 3.4

			fire_timer.wait_time = 0.62

		# ================================================================
		# FINAL PHASE
		# ================================================================

		4:

			body_polygon.color = Color(0.02, 0.0, 0.06, 1.0)
			core_polygon.color = Color(1.0, 0.08, 0.18, 1.0)

			engine_force = 5200.0
			max_speed = 1650.0
			anchor_follow_rate = 4.0

			fire_timer.wait_time = 0.46

	if aura_polygon != null:
		aura_polygon.color = Color(body_polygon.color.r, body_polygon.color.g, body_polygon.color.b, 0.16)

# ============================================================================
# MOVEMENT PATTERNS
# ============================================================================

func get_phase_movement() -> Vector2:

	match phase:

		# ----------------------------------------------------------------
		# STABLE ORBIT
		# ----------------------------------------------------------------

		1:

			return Vector2(
				cos(t),
				sin(t)
			) * 340.0

		# ----------------------------------------------------------------
		# STAR FRACTURE
		# ----------------------------------------------------------------

		2:

			var r = 420.0 * (
				1.0
				+ 0.45 * cos(5.0 * t)
			)

			return Vector2(
				r * cos(t),
				r * sin(t)
			)

		# ----------------------------------------------------------------
		# CHAOTIC HYPER MOTION
		# ----------------------------------------------------------------

		3:

			return Vector2(
				300.0 * (
					sin(3.0 * t)
					+ sin(9.0 * t) * 0.3
				),
				240.0 * (
					cos(5.0 * t)
					+ cos(11.0 * t) * 0.3
				)
			)

		# ----------------------------------------------------------------
		# BLACK SUN
		# ----------------------------------------------------------------

		4:

			var radius = (
				220.0
				+ sin(12.0 * t) * 90.0
			)

			return Vector2(
				cos(t * 8.0),
				sin(t * 8.0)
			) * radius

	return Vector2.ZERO

# ============================================================================
# SHAPE ANIMATION
# ============================================================================

func update_shape_animation() -> void:

	match phase:

		# ----------------------------------------------------------------
		# HEXAGON
		# ----------------------------------------------------------------

		1:

			set_shape(
				make_ngon(
					6,
					90.0
				)
			)

		# ----------------------------------------------------------------
		# STAR
		# ----------------------------------------------------------------

		2:

			set_shape(
				make_star(
					7,
					120.0,
					50.0
				)
			)

		# ----------------------------------------------------------------
		# ORGANIC CHAOS
		# ----------------------------------------------------------------

		3:

			set_shape(
				make_chaos_blob(
					16,
					110.0,
					35.0
				)
			)

		# ----------------------------------------------------------------
		# BLACK SUN
		# ----------------------------------------------------------------

		4:

			set_shape(
				make_black_sun(
					28,
					140.0
				)
			)

# ============================================================================
# APPLY SHAPE
# ============================================================================

func set_shape(points: PackedVector2Array) -> void:

	body_polygon.polygon = points
	collision_polygon.polygon = points

# ============================================================================
# ATTACKS
# ============================================================================

func fire_attack() -> void:

	if player == null:
		return

	match phase:

		# ----------------------------------------------------------------
		# SIMPLE RING
		# ----------------------------------------------------------------

		1:

			fire_ring(6, 640.0)
			fire_aimed_fork(3, 760.0, 0.18)

		# ----------------------------------------------------------------
		# STAR BURST
		# ----------------------------------------------------------------

		2:

			fire_ring(10, 980.0)

			fire_spiral(5)
			fire_aimed_fork(5, 1040.0, 0.14)

		# ----------------------------------------------------------------
		# CHAOS SPRAY
		# ----------------------------------------------------------------

		3:

			for i in range(12):

				var dir = Vector2.RIGHT.rotated(
					TAU * i / 12.0
					+ _rng.randf_range(-0.24, 0.24)
				)

				spawn_bullet(
					dir,
					_rng.randf_range(860.0, 1420.0)
				)
			fire_aimed_fork(7, 1240.0, 0.11)

		# ----------------------------------------------------------------
		# FINAL PHASE
		# ----------------------------------------------------------------

		4:

			fire_ring(18, 1560.0)

			fire_spiral(8)
			fire_aimed_fork(9, 1660.0, 0.09)

# ============================================================================
# FIRE RING
# ============================================================================

func fire_ring(count: int, speed: float) -> void:

	for i in range(count):

		var angle = TAU * float(i) / float(count)

		var dir = Vector2.RIGHT.rotated(angle)

		spawn_bullet(dir, speed)

# ============================================================================
# FIRE SPIRAL
# ============================================================================

func fire_spiral(arms: int) -> void:

	for i in range(arms):

		var angle = (
			TAU * i / arms
			+ t * 4.0
		)

		var dir = Vector2.RIGHT.rotated(angle)

		spawn_bullet(
			dir,
			980.0 + i * 75.0
		)

func fire_aimed_fork(count: int, speed: float, spread_step: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var aim := (player.global_position - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT.rotated(rotation)

	var center := float(count - 1) * 0.5
	for i in range(count):
		var offset := (float(i) - center) * spread_step
		spawn_bullet(aim.rotated(offset), speed)

# ============================================================================
# SPAWN BULLET
# ============================================================================

func spawn_bullet(
	direction: Vector2,
	speed: float
) -> void:

	if get_parent() == null:
		return

	# Check global bullet cap before spawning
	if not BulletManager.can_spawn_bullet():
		return

	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(rotation)

	var bullet = BULLET_SCENE.instantiate()

	bullet.global_position = (
		global_position
		+ direction * bullet_spawn_distance
	)
	bullet.global_rotation = direction.angle()

	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, speed, self)
	elif bullet.get("initial_speed") != null:
		bullet.set("initial_speed", speed)

	get_parent().add_child(bullet)

# ============================================================================
# DAMAGE
# ============================================================================

func take_damage(amount: float) -> void:

	current_health -= amount
	current_health = maxf(current_health, 0.0)
	boss_health_changed.emit(current_health, max_health)

	# pulse effect
	core_polygon.scale = Vector2.ONE * 1.6

	var tween = create_tween()

	tween.tween_property(
		core_polygon,
		"scale",
		Vector2.ONE,
		0.25
	)

	if current_health <= 0.0:
		die()

# ============================================================================
# DEATH
# ============================================================================

func die() -> void:

	boss_defeated.emit()

	queue_free()

func get_health_ratio() -> float:
	return clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)

func _on_contact_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("Player") or not body.has_method("take_damage"):
		return

	body.take_damage(contact_damage + 6.0 * float(phase - 1))
	var push := (body.global_position - global_position).normalized()
	if push == Vector2.ZERO:
		push = Vector2.RIGHT.rotated(rotation)
	CombatStatus.add_velocity(body, push * (420.0 + 90.0 * float(phase)))

# ============================================================================
# SHAPE GENERATORS
# ============================================================================

func make_circle_points(
	count: int,
	radius: float
) -> PackedVector2Array:

	var points := PackedVector2Array()

	for i in range(count):

		var angle = TAU * i / count

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	return points

# ----------------------------------------------------------------------------

func make_ngon(
	sides: int,
	radius: float
) -> PackedVector2Array:

	return make_circle_points(
		sides,
		radius
	)

# ----------------------------------------------------------------------------

func make_star(
	points_count: int,
	outer_radius: float,
	inner_radius: float
) -> PackedVector2Array:

	var points := PackedVector2Array()

	for i in range(points_count * 2):

		var angle = TAU * i / (points_count * 2)

		var radius = outer_radius

		if i % 2 == 1:
			radius = inner_radius

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	return points

# ----------------------------------------------------------------------------

func make_chaos_blob(
	points_count: int,
	radius: float,
	noise_strength: float
) -> PackedVector2Array:

	var points := PackedVector2Array()

	for i in range(points_count):

		var angle = TAU * i / points_count

		var r = radius + sin(
			t * 5.0 + i
		) * noise_strength

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * r
		)

	return points

# ----------------------------------------------------------------------------

func make_black_sun(
	points_count: int,
	radius: float
) -> PackedVector2Array:

	var points := PackedVector2Array()

	for i in range(points_count):

		var angle = TAU * i / points_count

		var spike = (
			sin(i * 3.0 + t * 8.0)
			* 35.0
		)

		var r = radius + spike

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * r
		)

	return points

func make_particle_material(particle_color: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 132.0
	material.spread = 180.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 120.0
	material.orbit_velocity_min = -0.85
	material.orbit_velocity_max = 1.35
	material.radial_accel_min = -80.0
	material.radial_accel_max = 34.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.2
	material.scale_max = 4.6
	material.color = particle_color
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.65
	return material
