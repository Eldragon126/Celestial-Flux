extends CharacterBody2D

# ============================================================================
# ORBITRON: "THE POLYMORPH"
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

signal boss_defeated
signal phase_changed(phase: int)

const BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

# ============================================================================
# CORE
# ============================================================================

@export var max_health := 2400.0

var current_health := 2400.0

var player: Node2D

# ============================================================================
# MOVEMENT
# ============================================================================

var t := 0.0

@export var engine_force := 2400.0
@export var drag := 1.2
@export var max_speed := 900.0

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

# ============================================================================
# TIMERS
# ============================================================================

var fire_timer: Timer
var morph_timer: Timer

# ============================================================================
# READY
# ============================================================================

func _ready() -> void:

	add_to_group("bosses")
	add_to_group("enemies")

	player = get_tree().get_first_node_in_group("Player")

	current_health = max_health

	build_visuals()
	build_timers()

	enter_phase(1)

# ============================================================================
# VISUAL SETUP
# ============================================================================

func build_visuals() -> void:

	# ------------------------------------------------------------------------
	# MAIN BODY
	# ------------------------------------------------------------------------

	body_polygon = Polygon2D.new()
	body_polygon.color = Color(0.1, 0.9, 1.0, 1.0)
	add_child(body_polygon)

	# ------------------------------------------------------------------------
	# CORE
	# ------------------------------------------------------------------------

	core_polygon = Polygon2D.new()
	core_polygon.color = Color.WHITE
	core_polygon.polygon = make_circle_points(24, 26.0)

	add_child(core_polygon)

	# ------------------------------------------------------------------------
	# COLLISION
	# ------------------------------------------------------------------------

	collision_polygon = CollisionPolygon2D.new()
	add_child(collision_polygon)

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

	t += delta

	update_phase()

	if player == null:
		return

	var offset := get_phase_movement()

	var target := player.global_position + offset

	anchor_position = anchor_position.lerp(
		target,
		delta * 2.0
	)

	var to_target := anchor_position - global_position

	if to_target.length() > 10.0:

		velocity += (
			to_target.normalized()
			* engine_force
			* delta
		)

	velocity -= velocity * drag * delta

	velocity = velocity.limit_length(max_speed)

	move_and_slide()

	# rotation drift
	rotation += delta * (
		0.4
		+ phase * 0.25
	)

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

			engine_force = 1800.0
			max_speed = 600.0

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

			engine_force = 2400.0
			max_speed = 900.0

			fire_timer.wait_time = 1.0

		# ================================================================
		# PHASE 3
		# ================================================================

		3:

			body_polygon.color = Color(
				0.9,
				0.1,
				0.8
			)

			engine_force = 3400.0
			max_speed = 1300.0

			fire_timer.wait_time = 0.7

		# ================================================================
		# FINAL PHASE
		# ================================================================

		4:

			body_polygon.color = Color.BLACK
			core_polygon.color = Color.RED

			engine_force = 5200.0
			max_speed = 2200.0

			fire_timer.wait_time = 0.35

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

			fire_ring(6, 600.0)

		# ----------------------------------------------------------------
		# STAR BURST
		# ----------------------------------------------------------------

		2:

			fire_ring(12, 900.0)

			fire_spiral(5)

		# ----------------------------------------------------------------
		# CHAOS SPRAY
		# ----------------------------------------------------------------

		3:

			for i in range(18):

				var dir = Vector2.RIGHT.rotated(
					TAU * i / 18.0
					+ randf() * 0.7
				)

				spawn_bullet(
					dir,
					randf_range(700.0, 1400.0)
				)

		# ----------------------------------------------------------------
		# FINAL PHASE
		# ----------------------------------------------------------------

		4:

			fire_ring(30, 1800.0)

			fire_spiral(14)

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
			900.0 + i * 80.0
		)

# ============================================================================
# SPAWN BULLET
# ============================================================================

func spawn_bullet(
	direction: Vector2,
	speed: float
) -> void:

	if get_parent() == null:
		return

	var bullet = BULLET_SCENE.instantiate()

	bullet.global_position = (
		global_position
		+ direction * 100.0
	)

	get_parent().add_child(bullet)

	if bullet.has_method("apply_impulse"):
		bullet.apply_impulse(
			direction * speed
		)

# ============================================================================
# DAMAGE
# ============================================================================

func take_damage(amount: float) -> void:

	current_health -= amount

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
