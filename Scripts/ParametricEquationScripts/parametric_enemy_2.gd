
# ============================================================================
# ORBITRON: VECTOR ENTITY
# Advanced Parametric Enemy Intelligence System
# ============================================================================
#
# FEATURES
# ----------------------------------------------------------------------------
# - 20+ movement equations
# - Health-based phase evolution
# - Inertial thrust movement
# - Curve blending
# - Rotating curve spaces
# - Chaotic motion
# - Boss-ready architecture
# - Space drift
# - Orbit collapse states
# - Pursuit bias
#
# ============================================================================
#
# HOW IT WORKS
# ----------------------------------------------------------------------------
# The equations generate a TARGET POSITION.
#
# The enemy DOES NOT teleport there.
#
# Instead:
# - the enemy accelerates toward the target
# - drifts with inertia
# - overshoots naturally
# - behaves like a real space object
#
# This makes the movement feel:
# - alive
# - physical
# - unstable
# - dangerous
#
# ============================================================================

extends RapierCharacterBody2D

# ============================================================================
# MOVEMENT TYPES
# ============================================================================

enum MovementType {
	CIRCLE,
	ELLIPSE,
	LISSAJOUS,
	ROSE,
	SPIRAL,
	SPIRAL_INWARD,
	FIGURE_EIGHT,
	ASTROID,
	CHAOS,
	COLLAPSE,
	WOBBLE,
	FRACTURE,
	SINE_WAVE,
	COSINE_DRIFT,
	DNA,
	MAGNETIC,
	ORBIT_PRECESSION,
	HEART,
	STAR,
	PETALS,
	BOUNCE,
	PULSE,
	SAW,
	GLITCH,
	SINGULARITY,
	SWARM,
	BUTTERFLY,
	HYPERCHAOS,
	BLACK_SUN
}

# ============================================================================
# REFERENCES
# ============================================================================

var player: Node2D

# ============================================================================
# CORE SETTINGS
# ============================================================================

@export var movement_type: MovementType = MovementType.LISSAJOUS

@export var equation_speed: float = 1.0
@export var orbit_scale: float = 200.0

@export var anchor_follow_speed: float = 2.5

# ============================================================================
# SPACE PHYSICS
# ============================================================================

@export var engine_thrust: float = 1800.0
@export var drag: float = 1.6
@export var max_speed: float = 700.0

@export var arrival_distance: float = 12.0

# ============================================================================
# CURVE PARAMETERS
# ============================================================================

@export var A: float = 250.0
@export var B: float = 180.0

@export var a: float = 3.0
@export var b: float = 2.0

@export var k: float = 4.0

# ============================================================================
# ROTATION
# ============================================================================

@export var rotate_to_velocity: bool = true
@export var rotation_speed: float = 7.0

# ============================================================================
# RUNTIME
# ============================================================================

var t: float = 0.0
var lifetime: float = 0.0

var anchor_position: Vector2
var desired_position: Vector2

var current_phase := 0

# ============================================================================
# READY
# ============================================================================

func _ready() -> void:

	player = get_tree().get_first_node_in_group("Player")

	anchor_position = global_position

# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:

	t += delta * equation_speed
	lifetime += delta

	update_health_phase()

	# ------------------------------------------------------------------------
	# MOVEMENT TARGET
	# ------------------------------------------------------------------------

	var offset := get_movement_position(t)

	var center := global_position

	if player != null:
		center = player.global_position

	desired_position = center + offset

	# ------------------------------------------------------------------------
	# DRIFTING ANCHOR
	# ------------------------------------------------------------------------

	anchor_position = anchor_position.lerp(
		desired_position,
		delta * anchor_follow_speed
	)

	# ------------------------------------------------------------------------
	# INERTIAL THRUST
	# ------------------------------------------------------------------------

	var to_anchor := anchor_position - global_position
	var distance := to_anchor.length()

	if distance > arrival_distance:

		var dir := to_anchor.normalized()

		var arrival_force = clamp(
			distance / 250.0,
			0.15,
			1.0
		)

		velocity += dir * engine_thrust * arrival_force * delta

	# ------------------------------------------------------------------------
	# DRAG
	# ------------------------------------------------------------------------

	velocity -= velocity * drag * delta

	velocity = velocity.limit_length(max_speed)

	move_and_slide()

	# ------------------------------------------------------------------------
	# ROTATION
	# ------------------------------------------------------------------------

	if rotate_to_velocity and velocity.length() > 20.0:

		rotation = lerp_angle(
			rotation,
			velocity.angle(),
			delta * rotation_speed
		)

# ============================================================================
# HEALTH PHASE SYSTEM
# ============================================================================

func update_health_phase() -> void:

	if not has_node("HealthComponent"):
		return

	var hc = $HealthComponent

	var hp_percent := float(hc.current_health) / float(hc.max_health)

	# =========================================================================
	# PHASE 1
	# =========================================================================

	if hp_percent > 0.75:

		if current_phase != 1:

			current_phase = 1

			movement_type = MovementType.ELLIPSE

			A = 240.0
			B = 120.0

			equation_speed = 0.9

			engine_thrust = 1300.0
			max_speed = 500.0

	# =========================================================================
	# PHASE 2
	# =========================================================================

	elif hp_percent > 0.50:

		if current_phase != 2:

			current_phase = 2

			movement_type = MovementType.LISSAJOUS

			a = 5.0
			b = 4.0

			A = 280.0
			B = 220.0

			equation_speed = 1.4

			engine_thrust = 1800.0
			max_speed = 700.0

	# =========================================================================
	# PHASE 3
	# =========================================================================

	elif hp_percent > 0.25:

		if current_phase != 3:

			current_phase = 3

			movement_type = MovementType.CHAOS

			equation_speed = 2.0

			engine_thrust = 2500.0
			max_speed = 900.0

	# =========================================================================
	# FINAL PHASE
	# =========================================================================

	else:

		if current_phase != 4:

			current_phase = 4

			movement_type = MovementType.BLACK_SUN

			equation_speed = 3.5

			engine_thrust = 3400.0
			max_speed = 1400.0

			drag = 0.8

# ============================================================================
# MOVEMENT SELECTOR
# ============================================================================

func get_movement_position(time: float) -> Vector2:

	match movement_type:

		MovementType.CIRCLE:
			return movement_circle(time)

		MovementType.ELLIPSE:
			return movement_ellipse(time)

		MovementType.LISSAJOUS:
			return movement_lissajous(time)

		MovementType.ROSE:
			return movement_rose(time)

		MovementType.SPIRAL:
			return movement_spiral(time)

		MovementType.SPIRAL_INWARD:
			return movement_spiral_inward(time)

		MovementType.FIGURE_EIGHT:
			return movement_figure_eight(time)

		MovementType.ASTROID:
			return movement_astroid(time)

		MovementType.CHAOS:
			return movement_chaos(time)

		MovementType.COLLAPSE:
			return movement_collapse(time)

		MovementType.WOBBLE:
			return movement_wobble(time)

		MovementType.FRACTURE:
			return movement_fracture(time)

		MovementType.SINE_WAVE:
			return movement_sine_wave(time)

		MovementType.COSINE_DRIFT:
			return movement_cosine_drift(time)

		MovementType.DNA:
			return movement_dna(time)

		MovementType.MAGNETIC:
			return movement_magnetic(time)

		MovementType.ORBIT_PRECESSION:
			return movement_precession(time)

		MovementType.HEART:
			return movement_heart(time)

		MovementType.STAR:
			return movement_star(time)

		MovementType.PETALS:
			return movement_petals(time)

		MovementType.BOUNCE:
			return movement_bounce(time)

		MovementType.PULSE:
			return movement_pulse(time)

		MovementType.SAW:
			return movement_saw(time)

		MovementType.GLITCH:
			return movement_glitch(time)

		MovementType.SINGULARITY:
			return movement_singularity(time)

		MovementType.SWARM:
			return movement_swarm(time)

		MovementType.BUTTERFLY:
			return movement_butterfly(time)

		MovementType.HYPERCHAOS:
			return movement_hyperchaos(time)

		MovementType.BLACK_SUN:
			return movement_black_sun(time)

	return Vector2.ZERO

# ============================================================================
# MOVEMENT FUNCTIONS
# ============================================================================

func movement_circle(time: float) -> Vector2:
	return Vector2(
		cos(time),
		sin(time)
	) * orbit_scale

# ----------------------------------------------------------------------------

func movement_ellipse(time: float) -> Vector2:
	return Vector2(
		A * cos(time),
		B * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_lissajous(time: float) -> Vector2:
	return Vector2(
		A * sin(a * time),
		B * sin(b * time)
	)

# ----------------------------------------------------------------------------

func movement_rose(time: float) -> Vector2:

	var r = orbit_scale * cos(k * time)

	return Vector2(
		r * cos(time),
		r * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_spiral(time: float) -> Vector2:

	var r = orbit_scale * (0.1 * time)

	return Vector2(
		cos(time),
		sin(time)
	) * r

# ----------------------------------------------------------------------------

func movement_spiral_inward(time: float) -> Vector2:

	var r = max(
		30.0,
		orbit_scale * (1.5 - time * 0.05)
	)

	return Vector2(
		cos(time * 4.0),
		sin(time * 4.0)
	) * r

# ----------------------------------------------------------------------------

func movement_figure_eight(time: float) -> Vector2:
	return Vector2(
		A * sin(time),
		B * sin(2.0 * time)
	)

# ----------------------------------------------------------------------------

func movement_astroid(time: float) -> Vector2:
	return Vector2(
		A * pow(cos(time), 3),
		B * pow(sin(time), 3)
	)

# ----------------------------------------------------------------------------

func movement_chaos(time: float) -> Vector2:
	return Vector2(
		A * (sin(3.0 * time) + 0.5 * sin(9.0 * time)),
		B * (cos(5.0 * time) + 0.5 * cos(11.0 * time))
	)

# ----------------------------------------------------------------------------

func movement_collapse(time: float) -> Vector2:

	var r = max(
		20.0,
		orbit_scale * (1.0 - time * 0.04)
	)

	return Vector2(
		cos(6.0 * time),
		sin(6.0 * time)
	) * r

# ----------------------------------------------------------------------------

func movement_wobble(time: float) -> Vector2:
	return Vector2(
		A * cos(time) + 40.0 * sin(8.0 * time),
		B * sin(time) + 40.0 * cos(7.0 * time)
	)

# ----------------------------------------------------------------------------

func movement_fracture(time: float) -> Vector2:
	return Vector2(
		A * sin(time * 2.0) * cos(time * 0.5),
		B * cos(time * 3.0) * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_sine_wave(time: float) -> Vector2:
	return Vector2(
		time * 80.0,
		B * sin(a * time)
	)

# ----------------------------------------------------------------------------

func movement_cosine_drift(time: float) -> Vector2:
	return Vector2(
		A * cos(time),
		time * 70.0
	)

# ----------------------------------------------------------------------------

func movement_dna(time: float) -> Vector2:
	return Vector2(
		A * sin(time),
		B * sin(time * 2.0)
	)

# ----------------------------------------------------------------------------

func movement_magnetic(time: float) -> Vector2:
	return Vector2(
		time * 50.0,
		B * (sin(time) + 0.4 * sin(7.0 * time))
	)

# ----------------------------------------------------------------------------

func movement_precession(time: float) -> Vector2:
	return Vector2(
		A * cos(time + time * 0.1),
		B * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_heart(time: float) -> Vector2:

	var x = 16.0 * pow(sin(time), 3)

	var y = (
		13.0 * cos(time)
		- 5.0 * cos(2.0 * time)
		- 2.0 * cos(3.0 * time)
		- cos(4.0 * time)
	)

	return Vector2(x, -y) * 12.0

# ----------------------------------------------------------------------------

func movement_star(time: float) -> Vector2:

	var r = orbit_scale * (
		1.0 + 0.5 * cos(5.0 * time)
	)

	return Vector2(
		r * cos(time),
		r * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_petals(time: float) -> Vector2:

	var r = orbit_scale * sin(8.0 * time)

	return Vector2(
		r * cos(time),
		r * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_bounce(time: float) -> Vector2:
	return Vector2(
		A * sin(time),
		abs(B * sin(3.0 * time))
	)

# ----------------------------------------------------------------------------

func movement_pulse(time: float) -> Vector2:

	var pulse = (
		1.0 +
		0.4 * sin(12.0 * time)
	)

	return Vector2(
		cos(time),
		sin(time)
	) * orbit_scale * pulse

# ----------------------------------------------------------------------------

func movement_saw(time: float) -> Vector2:

	var wave = fmod(time * 100.0, A)

	return Vector2(
		wave,
		B * sin(time)
	)

# ----------------------------------------------------------------------------

func movement_glitch(time: float) -> Vector2:

	return Vector2(
		A * sign(sin(7.0 * time)),
		B * sign(cos(5.0 * time))
	)

# ----------------------------------------------------------------------------

func movement_singularity(time: float) -> Vector2:

	var r = (
		orbit_scale /
		(1.0 + time * 0.5)
	)

	return Vector2(
		cos(12.0 * time),
		sin(12.0 * time)
	) * r

# ----------------------------------------------------------------------------

func movement_swarm(time: float) -> Vector2:

	return Vector2(
		A * sin(time + sin(5.0 * time)),
		B * cos(time + cos(7.0 * time))
	)

# ----------------------------------------------------------------------------

func movement_butterfly(time: float) -> Vector2:

	var x = sin(time) * (
		exp(cos(time))
		- 2.0 * cos(4.0 * time)
		- pow(sin(time / 12.0), 5)
	)

	var y = cos(time) * (
		exp(cos(time))
		- 2.0 * cos(4.0 * time)
		- pow(sin(time / 12.0), 5)
	)

	return Vector2(x, y) * 90.0

# ----------------------------------------------------------------------------

func movement_hyperchaos(time: float) -> Vector2:

	return Vector2(
		A * (
			sin(3.0 * time)
			+ sin(11.0 * time)
			+ sin(17.0 * time) * 0.4
		),
		B * (
			cos(5.0 * time)
			+ cos(13.0 * time)
			+ cos(19.0 * time) * 0.4
		)
	)

# ----------------------------------------------------------------------------

func movement_black_sun(time: float) -> Vector2:

	var radius = (
		orbit_scale *
		(1.0 + 0.3 * sin(9.0 * time))
	)

	return Vector2(
		cos(time * 8.0),
		sin(time * 8.0)
	) * radius

# ============================================================================
# DAMAGE
# ============================================================================

func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)

# ============================================================================
# SIGNALS
# ============================================================================

func _on_health_component_died() -> void:
	queue_free()

func _on_health_component_health_changed(
	current_health,
	max_health
) -> void:

	print(
		name,
		" HP: ",
		current_health,
		"/",
		max_health
	)
