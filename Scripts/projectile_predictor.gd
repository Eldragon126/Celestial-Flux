extends Node2D
class_name ProjectileAimPredictor

# ============================================================
# VISUAL SETTINGS
# ============================================================

@export var prediction_steps: int = 140
@export var substeps: int = 3

@export var line_width: float = 2.2

@export var ghost_count: int = 4
@export var ghost_amplitude: float = 18.0
@export var ghost_frequency: float = 2.2
@export var ghost_speed: float = 6.0

@export var prediction_color: Color = Color(0.0, 0.85, 1.0, 0.75)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var ghost_color: Color = Color(0.0, 0.6, 1.0, 0.22)

# ============================================================
# PROJECTILE MATCHING
# ============================================================

@export var projectile_speed: float = 850.0
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var gravity_radius: float = 2000.0
@export var spawn_offset: float = 70.0

@export var projectile_mass: float = 0.25
@export var friction: float = 0.5
@export var bounce: float = 0.5
@export var solver_correction: float = 0.995

# ============================================================
# INTERNAL
# ============================================================

var _player: CharacterBody2D
var _points: Array[Vector2] = []
var _gravity_sources: Array[Node2D] = []

var _dt: float
var _time := 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	top_level = true
	_player = get_parent() as CharacterBody2D
	_dt = 1.0 / Engine.physics_ticks_per_second
	process_mode = Node.PROCESS_MODE_ALWAYS

# ============================================================
# LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var unscaled_delta = delta / Engine.time_scale
	_time += unscaled_delta

	_update_gravity_sources()
	_simulate()
	queue_redraw()


# ============================================================
# GRAVITY SOURCES
# ============================================================

func _update_gravity_sources() -> void:
	_gravity_sources.clear()

	var seen := {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for n in get_tree().get_nodes_in_group(group_name):
			var node := n as Node2D
			if node == null:
				continue

			var id := node.get_instance_id()
			if seen.has(id):
				continue

			seen[id] = true
			_gravity_sources.append(node)


# ============================================================
# MAIN SIMULATION
# ============================================================

func _simulate() -> void:
	_points.clear()

	var dir := -_player.transform.x.normalized()

	var pos := _player.global_position + dir * spawn_offset
	var vel := dir * projectile_speed

	var step_dt := _dt / float(substeps)

	for i in range(prediction_steps):

		# ----------------------------
		# physics integration
		# ----------------------------
		for s in range(substeps):

			var force := Vector2.ZERO

			for g in _gravity_sources:
				if not is_instance_valid(g):
					continue

				var offset := g.global_position - pos
				var dist := offset.length()

				if dist < 0.001 or dist > gravity_radius:
					continue

				var d = max(dist, min_grav_dist)

				var mass_value = g.get("mass")
				var mass := 100.0
				if mass_value is float or mass_value is int:
					mass = float(mass_value)

				force += offset.normalized() * (gravity_constant * mass / (d * d))

			var accel := force / projectile_mass
			vel += accel * step_dt
			pos += vel * step_dt

		# ----------------------------
		# collision
		# ----------------------------
		for p in get_tree().get_nodes_in_group("planets"):
			var planet := p as Node2D
			if planet == null:
				continue

			var delta := pos - planet.global_position
			var dist := delta.length()

			if dist < 55.0:

				var normal = delta / max(dist, 0.0001)

				vel = vel.bounce(normal) * bounce

				var tangent = vel - normal * vel.dot(normal)
				vel -= tangent * (1.0 - friction)

				pos = planet.global_position + normal * 55.0

				vel *= solver_correction

		_points.append(pos)

		if vel.length() < 6.0:
			return


# ============================================================
# DRAW (MAIN + PULSING PARALLEL FIELD)
# ============================================================

func _draw() -> void:
	if Engine.time_scale > 1.0 or Engine.time_scale < 0.97 and Engine.time_scale != 0.0: #if it's not in a regular time
		#We just don't draw it if the engine time is off because for some reason the projectile is not working correctly when time slows.
		#I think it has to do with the apply_force() function of the projectile.
		return
	if _points.size() < 2:
		return

	# ----------------------------
	# GHOST PULSING FIELD
	# ----------------------------

	for g in range(ghost_count):

		var phase := float(g) / float(ghost_count) * PI * 2.0

		for i in range(1, _points.size()):

			var p0 := _points[i - 1]
			var p1 := _points[i]

			var dir := (p1 - p0).normalized()
			var normal := Vector2(-dir.y, dir.x)

			var dist_phase := float(i) * ghost_frequency

			var pulse := sin(_time * ghost_speed + dist_phase + phase)

			var offset := normal * pulse * ghost_amplitude * (1.0 - float(i) / float(_points.size()))

			var a := to_local(p0 + offset)
			var b := to_local(p1 + offset)

			var fade := ghost_color.a * (2.0 - float(i) / float(_points.size()))

			draw_line(
				a,
				b,
				Color(ghost_color.r, ghost_color.g, ghost_color.b, fade),
				line_width * 0.7
			)

	# ----------------------------
	# MAIN LINE
	# ----------------------------

	for i in range(1, _points.size()):

		var a := to_local(_points[i - 1])
		var b := to_local(_points[i])

		var t := float(i) / float(_points.size())

		var col := prediction_color
		if i > _points.size() - 20:
			col = danger_color

		draw_line(
			a,
			b,
			Color(col.r, col.g, col.b, (1.0 - t) * col.a),
			line_width
		)

	draw_circle(to_local(_points[0]), 4.0, Color.WHITE)
