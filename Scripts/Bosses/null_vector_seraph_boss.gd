extends PhaseBoss

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

@export var lane_radius = 900.0
@export var lane_width = 84.0
@export var lane_force = 760.0
@export var move_speed = 510.0
@export var projectile_speed = 880.0
@export var ability_lock_duration = 1.1
@export var lane_time_multiplier = 0.58
@export var lane_time_duration = 0.22

var _lane_angle = 0.0
var _phase_shift_angle = 0.0
var _lane_visuals: Array[Polygon2D] = []
var _body_core: Polygon2D

func _ready() -> void:
	max_health = max(max_health, 900.0)
	attack_interval = 2.25
	_build_body()
	super._ready()

func _boss_physics(delta: float) -> void:
	if player == null:
		return

	_phase_shift_angle += delta * (0.75 + current_phase * 0.22)
	_lane_angle += delta * (0.34 + current_phase * 0.16)
	var target = player.global_position + Vector2(cos(_phase_shift_angle), sin(_phase_shift_angle * 1.4)) * 680.0
	velocity = velocity.lerp((target - global_position).limit_length(move_speed), clampf(delta * 2.0, 0.0, 1.0))
	if current_phase == 2:
		velocity = velocity.rotated(sin(_phase_shift_angle) * 0.02)
	elif current_phase == 3:
		velocity += (player.global_position - global_position).normalized() * 120.0 * delta

	move_and_slide()
	_apply_rotating_lanes(delta)
	_apply_lane_time_disruption()
	_update_lane_visuals()

func _run_attack_pattern() -> void:
	_telegraph()
	await get_tree().create_timer(0.28).timeout

	if current_phase == 1:
		_fire_lane_shots(4)
	elif current_phase == 2:
		_disable_player_abilities()
		_fire_lane_shots(6)
	else:
		_disable_player_abilities()
		_fire_lane_shots(8)
		CombatStatus.apply_local_slow(player, 0.72, 0.8)

func on_damage_taken(_amount: float) -> void:
	_phase_shift_angle += 0.4

func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(0.95, attack_interval - 0.36 * float(phase - 1))
	if _body_core != null:
		_body_core.color = [Color(0.64, 0.86, 1.0, 1.0), Color(1.0, 0.32, 0.84, 1.0), Color(1.0, 1.0, 0.28, 1.0)][phase - 1]

func _build_body() -> void:
	var hull = Polygon2D.new()
	hull.name = "SeraphHull"
	hull.color = Color(0.06, 0.08, 0.16, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(0.0, -112.0),
		Vector2(76.0, -24.0),
		Vector2(46.0, 92.0),
		Vector2(0.0, 46.0),
		Vector2(-46.0, 92.0),
		Vector2(-76.0, -24.0),
	])
	add_child(hull)

	_body_core = Polygon2D.new()
	_body_core.name = "SeraphCore"
	_body_core.color = Color(0.64, 0.86, 1.0, 1.0)
	_body_core.polygon = _circle_points(8, 34.0)
	add_child(_body_core)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = hull.polygon
	add_child(collision)

	for i in range(4):
		var lane = Polygon2D.new()
		lane.name = "GravityLane%d" % i
		lane.z_index = -3
		lane.color = Color(0.45, 0.92, 1.0, 0.11)
		lane.polygon = PackedVector2Array([
			Vector2(-lane_radius, -lane_width),
			Vector2(lane_radius, -lane_width),
			Vector2(lane_radius, lane_width),
			Vector2(-lane_radius, lane_width),
		])
		add_child(lane)
		_lane_visuals.append(lane)

func _apply_rotating_lanes(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var offset = player.global_position - global_position
	if offset.length() > lane_radius:
		return

	for i in range(4):
		var lane_dir = Vector2.RIGHT.rotated(_lane_angle + TAU * float(i) / 4.0)
		var lateral = absf(offset.dot(lane_dir.orthogonal()))
		if lateral <= lane_width:
			var player_velocity = player.get("velocity")
			player.set("velocity", player_velocity + lane_dir * lane_force * delta)
			return

func _apply_lane_time_disruption() -> void:
	var seen := {}
	for group_name in [&"enemy_projectiles", &"player_projectiles", &"Projectiles", &"enemies"]:
		for body in get_tree().get_nodes_in_group(group_name):
			if body == self or body == player or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var body_2d := body as Node2D
			if body_2d == null:
				continue
			var id := body_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var offset := body_2d.global_position - global_position
			if offset.length() > lane_radius:
				continue

			for i in range(4):
				var lane_dir := Vector2.RIGHT.rotated(_lane_angle + TAU * float(i) / 4.0)
				if absf(offset.dot(lane_dir.orthogonal())) <= lane_width:
					CombatStatus.apply_local_slow(body_2d, lane_time_multiplier, lane_time_duration)
					break

func _update_lane_visuals() -> void:
	for i in range(_lane_visuals.size()):
		var lane = _lane_visuals[i]
		if lane != null:
			lane.rotation = _lane_angle + TAU * float(i) / 4.0

func _fire_lane_shots(count: int) -> void:
	if get_parent() == null:
		return

	for i in range(count):
		var direction = Vector2.RIGHT.rotated(_lane_angle + TAU * float(i) / float(count))
		var bullet = ENEMY_BULLET_SCENE.instantiate()
		get_parent().call_deferred("add_child", bullet)
		bullet.global_position = global_position + direction * 116.0
		bullet.apply_impulse(direction * projectile_speed)

func _disable_player_abilities() -> void:
	if player == null:
		return

	if player.get("can_dash") != null:
		player.set("can_dash", false)
	if player.has_method("apply_shield_disruption"):
		player.call("apply_shield_disruption", 0.48, ability_lock_duration)
	_restore_player_abilities_later()

func _restore_player_abilities_later() -> void:
	await get_tree().create_timer(ability_lock_duration).timeout
	if player != null and is_instance_valid(player) and player.get("can_dash") != null:
		player.set("can_dash", true)

func _telegraph() -> void:
	if _body_core == null:
		return

	var tween = create_tween()
	_body_core.scale = Vector2.ONE
	tween.tween_property(_body_core, "scale", Vector2(1.34, 1.34), 0.12)
	tween.tween_property(_body_core, "scale", Vector2.ONE, 0.22)

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
