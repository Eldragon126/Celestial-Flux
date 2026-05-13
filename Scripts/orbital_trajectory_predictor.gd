# orbital_trajectory_predictor.gd - SLINGSHOT-ACCURATE VERSION
extends Node2D
class_name OrbitalTrajectoryPredictor

@export_node_path("CharacterBody2D") var player_path: NodePath = ^"../Player"

@export var prediction_steps: int = 160
@export var time_step: float = 0.014
@export var max_prediction_distance: float = 3500.0

@export var show_prediction_line: bool = true
@export var prediction_color: Color = Color(0.0, 0.88, 1.0, 0.7)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var line_width: float = 2.6

var _player: CharacterBody2D
var _prediction_points: Array[Vector2] = []
var _predicted_collisions: Array[Dictionary] = []

func _ready() -> void:
	_resolve_player()
	set_process(true)


func _process(_delta: float) -> void:
	if _player == null:
		_resolve_player()
		return

	_calculate_trajectory()

	if show_prediction_line:
		queue_redraw()


func _resolve_player() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as CharacterBody2D


# ============================================================
# MAIN SIMULATION
# ============================================================

func _calculate_trajectory() -> void:
	if _player == null:
		return

	_prediction_points.clear()
	_predicted_collisions.clear()

	var planets: Array = _player.planets if "planets" in _player else []

	var pos: Vector2 = _player.global_position
	var vel: Vector2 = _player.velocity
	var distance_traveled := 0.0

	var gravity_constant: float = 400.0
	var min_grav_dist: float = 50.0
	var slingshot_factor: float = _player.slingshot_factor if "slingshot_factor" in _player else 1.5
	var orbit_control_bonus: float = _player.orbit_control_bonus if "orbit_control_bonus" in _player else 0.0
	var DRAG_enabled := true

	for i in range(prediction_steps):

		# ====================================================
		# GRAVITY (IDENTICAL TO PLAYER)
		# ====================================================
		var gravity := Vector2.ZERO
		var closest_planet = null
		var closest_dist := INF

		for p in planets:
			if not is_instance_valid(p):
				continue

			var offset = p.global_position - pos
			var raw_dist = offset.length()

			if raw_dist < 0.001:
				continue

			if raw_dist < closest_dist:
				closest_dist = raw_dist
				closest_planet = p

			var dist = max(raw_dist, min_grav_dist)

			var mass_value = p.get("mass")
			var mass = float(mass_value) if typeof(mass_value) in [TYPE_FLOAT, TYPE_INT] else 100.0

			gravity += offset / raw_dist * (gravity_constant * mass / (dist * dist))


		# apply gravity
		vel += gravity * time_step


		# ====================================================
		# SLINGSHOT (1:1 PLAYER LOGIC)
		# ====================================================
		if is_instance_valid(closest_planet):

			var offset = closest_planet.global_position - pos
			var raw_dist = offset.length()

			if raw_dist > 70.0 and raw_dist < 500.0 and vel.length() > 1.0:

				var grav_dir = gravity.normalized() if gravity.length() > 0.0001 else offset.normalized()
				var tangent = grav_dir.orthogonal()

				if tangent.dot(vel) < 0:
					tangent = -tangent

				var accel_tangent = gravity.dot(vel.normalized())

				if accel_tangent > 0 and DRAG_enabled:
					vel += tangent * accel_tangent * (slingshot_factor + orbit_control_bonus) * time_step


		# ====================================================
		# MOVE FORWARD
		# ====================================================
		pos += vel * time_step
		distance_traveled += vel.length() * time_step

		_prediction_points.append(pos)


		# ====================================================
		# COLLISION CHECK
		# ====================================================
		for p in planets:
			if not is_instance_valid(p):
				continue

			if pos.distance_to(p.global_position) < 55.0:
				_predicted_collisions.append({"position": pos})
				return


		if distance_traveled > max_prediction_distance:
			break

		if vel.length() < 8.0:
			break


# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	if not show_prediction_line or _prediction_points.size() < 2:
		return

	for i in range(1, _prediction_points.size()):
		var p1 = to_local(_prediction_points[i - 1])
		var p2 = to_local(_prediction_points[i])

		var t = float(i) / _prediction_points.size()
		var col = danger_color if i < 22 else prediction_color

		draw_line(
			p1,
			p2,
			Color(col.r, col.g, col.b, col.a * (1.0 - t * 0.75)),
			line_width
		)

	draw_circle(to_local(_player.global_position), 6, Color(0.0, 1.0, 0.6, 0.9))
