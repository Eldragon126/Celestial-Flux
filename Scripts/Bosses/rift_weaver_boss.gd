extends PhaseBoss

const CHAOS_WISP_SCENE = preload("res://Nodes/chaos_wisp.tscn")
const SHIELD_BREAKER_SCENE = preload("res://Nodes/shield_breaker_unit.tscn")
const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

@export var move_speed = 430.0
@export var rift_radius = 880.0
@export var rift_width = 72.0
@export var lane_force = 720.0
@export var projectile_speed = 840.0

var _lane_angle = 0.0
var _orbit_angle = 0.0
var _core: Polygon2D
var _rift_lanes: Array[Polygon2D] = []

func _ready() -> void:
	max_health = max(max_health, 1060.0)
	mass = 290000.0
	attack_interval = 2.35
	_build_body()
	super._ready()

func _boss_physics(delta: float) -> void:
	if player == null:
		return

	_orbit_angle += delta * (0.28 + current_phase * 0.08)
	_lane_angle += delta * (0.25 + current_phase * 0.13)
	var target = player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * (720.0 - 60.0 * current_phase)
	velocity = velocity.lerp((target - global_position).limit_length(move_speed + 45.0 * current_phase), clampf(delta * 1.6, 0.0, 1.0))
	move_and_slide()
	_apply_rift_lanes(delta)
	_update_lanes()

func _run_attack_pattern() -> void:
	_pulse_core()
	await get_tree().create_timer(0.3).timeout

	if current_phase == 1:
		_fire_spiral(6)
	elif current_phase == 2:
		_fire_spiral(8)
		_spawn_wisps(2)
	else:
		_fire_spiral(10)
		_spawn_breaker()
		_rift_snap()

func on_damage_taken(_amount: float) -> void:
	_lane_angle += 0.18

func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.0, attack_interval - 0.4 * float(phase - 1))
	if _core != null:
		_core.color = [Color(0.24, 1.0, 0.72, 1.0), Color(0.86, 0.42, 1.0, 1.0), Color(1.0, 0.82, 0.22, 1.0)][phase - 1]

func _build_body() -> void:
	var hull = Polygon2D.new()
	hull.name = "RiftWeaverHull"
	hull.color = Color(0.07, 0.11, 0.12, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(0.0, -100.0),
		Vector2(88.0, -26.0),
		Vector2(62.0, 76.0),
		Vector2(0.0, 112.0),
		Vector2(-62.0, 76.0),
		Vector2(-88.0, -26.0),
	])
	add_child(hull)

	_core = Polygon2D.new()
	_core.name = "RiftWeaverCore"
	_core.color = Color(0.24, 1.0, 0.72, 1.0)
	_core.polygon = _circle_points(9, 38.0)
	add_child(_core)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = hull.polygon
	add_child(collision)

	for i in range(3):
		var lane = Polygon2D.new()
		lane.name = "RiftLane%d" % i
		lane.z_index = -3
		lane.color = Color(0.24, 1.0, 0.72, 0.10)
		lane.polygon = PackedVector2Array([
			Vector2(-rift_radius, -rift_width),
			Vector2(rift_radius, -rift_width),
			Vector2(rift_radius, rift_width),
			Vector2(-rift_radius, rift_width),
		])
		add_child(lane)
		_rift_lanes.append(lane)

func _apply_rift_lanes(delta: float) -> void:
	if player == null:
		return

	var offset = player.global_position - global_position
	if offset.length() > rift_radius:
		return

	for i in range(_rift_lanes.size()):
		var lane_dir = Vector2.RIGHT.rotated(_lane_angle + TAU * float(i) / float(_rift_lanes.size()))
		if absf(offset.dot(lane_dir.orthogonal())) <= rift_width:
			var player_velocity = player.get("velocity")
			player.set("velocity", player_velocity + lane_dir * lane_force * delta)
			return

func _update_lanes() -> void:
	for i in range(_rift_lanes.size()):
		var lane = _rift_lanes[i]
		if lane != null:
			lane.rotation = _lane_angle + TAU * float(i) / float(_rift_lanes.size())

func _fire_spiral(count: int) -> void:
	if get_parent() == null:
		return
	for i in range(count):
		var direction = Vector2.RIGHT.rotated(_lane_angle + TAU * float(i) / float(count))
		var bullet = ENEMY_BULLET_SCENE.instantiate()
		bullet.global_position = global_position + direction * 112.0
		bullet.apply_impulse(direction * projectile_speed)
		get_parent().call_deferred("add_child", bullet)

func _spawn_wisps(count: int) -> void:
	if get_parent() == null:
		return
	for i in range(count):
		var wisp = CHAOS_WISP_SCENE.instantiate()
		wisp.global_position = global_position + Vector2.RIGHT.rotated(_lane_angle + TAU * float(i) / float(count)) * 190.0
		wisp.add_to_group("wave_enemy")
		get_parent().call_deferred("add_child", wisp)

func _spawn_breaker() -> void:
	if get_parent() == null:
		return
	var breaker = SHIELD_BREAKER_SCENE.instantiate()
	breaker.global_position = global_position + Vector2.RIGHT.rotated(_lane_angle) * 210.0
	breaker.add_to_group("wave_enemy")
	get_parent().call_deferred("add_child", breaker)

func _rift_snap() -> void:
	if player == null:
		return
	var offset = player.global_position - global_position
	if offset.length() < 780.0:
		var player_velocity = player.get("velocity")
		player.set("velocity", player_velocity.rotated(0.32).limit_length(maxf(player_velocity.length(), 420.0)))
		CombatStatus.apply_local_slow(player, 0.82, 0.55)

func _pulse_core() -> void:
	if _core == null:
		return
	var tween = create_tween()
	_core.scale = Vector2.ONE
	tween.tween_property(_core, "scale", Vector2(1.3, 1.3), 0.12)
	tween.tween_property(_core, "scale", Vector2.ONE, 0.2)

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

