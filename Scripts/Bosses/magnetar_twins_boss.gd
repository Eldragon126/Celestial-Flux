extends PhaseBoss

const ORBITER_SCENE = preload("res://Nodes/orbiter_drone.tscn")
const SEEKER_SCENE = preload("res://Nodes/seeker_fragment.tscn")
const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

@export var orbit_distance = 640.0
@export var move_speed = 500.0
@export var lobe_radius = 165.0
@export var lobe_force = 1320.0
@export var projectile_speed = 900.0
@export var polarity_window_duration = 2.6

var _angle = 0.0
var _polarity_sign = 1.0
var _polarity_timer = 0.0
var _core: Polygon2D
var _north_lobe: Polygon2D
var _south_lobe: Polygon2D

func _ready() -> void:
	max_health = max(max_health, 980.0)
	mass = 320000.0
	attack_interval = 2.15
	_build_body()
	super._ready()

func _boss_physics(delta: float) -> void:
	if player == null:
		return

	_angle += delta * (0.45 + current_phase * 0.14)
	_update_polarity_window(delta)
	var target = player.global_position + Vector2(cos(_angle), sin(_angle * 0.7)) * orbit_distance
	velocity = velocity.lerp((target - global_position).limit_length(move_speed + 30.0 * current_phase), clampf(delta * 1.9, 0.0, 1.0))
	move_and_slide()
	_apply_lobe_forces(delta)
	_update_lobes()

func _run_attack_pattern() -> void:
	_pulse_core()
	await get_tree().create_timer(0.22).timeout

	if is_queued_for_deletion() or get_parent() == null:
		return

	if current_phase == 1:
		_fire_paired_shots()
	elif current_phase == 2:
		_fire_paired_shots()
		_spawn_orbiter_pair()
	else:
		_magnetic_inversion()
		_spawn_seekers()

func on_damage_taken(_amount: float) -> void:
	_angle += 0.22

func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.05, attack_interval - 0.35 * float(phase - 1))
	if _core != null:
		_core.color = [Color(0.96, 0.25, 0.92, 1.0), Color(0.25, 0.86, 1.0, 1.0), Color(1.0, 0.28, 0.18, 1.0)][phase - 1]

func _build_body() -> void:
	_north_lobe = _get_or_make_lobe("NorthMagnetarLobe", Color(0.26, 0.86, 1.0, 0.52))
	_south_lobe = _get_or_make_lobe("SouthMagnetarLobe", Color(1.0, 0.18, 0.72, 0.52))

	var hull := get_node_or_null("MagnetarHull") as Polygon2D
	if hull == null:
		hull = Polygon2D.new()
		hull.name = "MagnetarHull"
		hull.color = Color(0.08, 0.06, 0.18, 1.0)
		add_child(hull)
	if hull.polygon.is_empty():
		hull.polygon = _circle_points(10, 94.0)

	_core = get_node_or_null("MagnetarCore") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "MagnetarCore"
		_core.color = Color(0.96, 0.25, 0.92, 1.0)
		add_child(_core)
	if _core.polygon.is_empty():
		_core.polygon = _circle_points(8, 42.0)

	if not has_node("CollisionPolygon2D"):
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = hull.polygon
		add_child(collision)

func _get_or_make_lobe(node_name: String, color: Color) -> Polygon2D:
	var lobe := get_node_or_null(node_name) as Polygon2D
	if lobe == null:
		lobe = Polygon2D.new()
		lobe.name = node_name
		lobe.z_index = -2
		lobe.color = color
		add_child(lobe)
	if lobe.polygon.is_empty():
		lobe.polygon = _circle_points(24, 46.0)
	return lobe

func _apply_lobe_forces(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	for lobe in [_north_lobe, _south_lobe]:
		if lobe == null:
			continue
		var offset = lobe.global_position - player.global_position
		var distance = offset.length()
		if distance <= 1.0 or distance > 540.0:
			continue
		var player_velocity: Variant = player.get("velocity")
		if not player_velocity is Vector2:
			continue
		var polarity = _polarity_sign if lobe == _north_lobe else -_polarity_sign
		player.set("velocity", player_velocity + offset.normalized() * lobe_force * polarity * delta * 540.0 / maxf(distance, 90.0))

func _update_lobes() -> void:
	var lobe_axis = Vector2.RIGHT.rotated(_angle)
	if _north_lobe != null:
		_north_lobe.position = lobe_axis * lobe_radius
		_north_lobe.rotation = _angle
	if _south_lobe != null:
		_south_lobe.position = -lobe_axis * lobe_radius
		_south_lobe.rotation = _angle + PI

func _fire_paired_shots() -> void:
	if player == null or get_parent() == null:
		return

	var aim = (player.global_position - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT.rotated(rotation)

	if _polarity_sign > 0.0:
		_spawn_bullet(aim, projectile_speed * 0.94)
	else:
		_spawn_bullet(aim.rotated(-0.12), projectile_speed * 0.88)

func _spawn_bullet(direction: Vector2, speed: float) -> void:
	# Check global bullet cap before spawning
	if not BulletManager.can_spawn_bullet():
		return

	var bullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position + direction * 118.0
	bullet.global_rotation = direction.angle()
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, speed, self)
	elif bullet.get("initial_speed") != null:
		bullet.set("initial_speed", speed)
	get_parent().call_deferred("add_child", bullet)

func _spawn_orbiter_pair() -> void:
	if get_parent() == null:
		return
	for i in range(2):
		var orbiter = ORBITER_SCENE.instantiate()
		orbiter.global_position = global_position + Vector2.RIGHT.rotated(_angle + PI * float(i)) * 210.0
		orbiter.add_to_group("wave_enemy")
		get_parent().call_deferred("add_child", orbiter)

func _spawn_seekers() -> void:
	if get_parent() == null:
		return
	for i in range(3):
		var seeker = SEEKER_SCENE.instantiate()
		seeker.global_position = global_position + Vector2.RIGHT.rotated(_angle + TAU * float(i) / 3.0) * 150.0
		seeker.add_to_group("wave_enemy")
		get_parent().call_deferred("add_child", seeker)

func _magnetic_inversion() -> void:
	if player == null:
		return
	_polarity_sign *= -1.0
	_polarity_timer = 0.0
	var offset = player.global_position - global_position
	if offset.length() < 760.0:
		var player_velocity: Variant = player.get("velocity")
		if not player_velocity is Vector2:
			return
		player.set("velocity", player_velocity + offset.normalized() * 460.0)
		if player.has_method("apply_shield_disruption"):
			player.call("apply_shield_disruption", 0.38, 0.75)

func _update_polarity_window(delta: float) -> void:
	_polarity_timer += delta
	if _polarity_timer >= maxf(polarity_window_duration, 0.4):
		_polarity_timer = 0.0
		_polarity_sign *= -1.0
		_pulse_core()

	if _north_lobe != null:
		_north_lobe.color = Color(0.26, 0.86, 1.0, 0.52) if _polarity_sign > 0.0 else Color(1.0, 0.18, 0.72, 0.52)
	if _south_lobe != null:
		_south_lobe.color = Color(1.0, 0.18, 0.72, 0.52) if _polarity_sign > 0.0 else Color(0.26, 0.86, 1.0, 0.52)

func _pulse_core() -> void:
	if _core == null:
		return
	var tween = create_tween()
	_core.scale = Vector2.ONE
	tween.tween_property(_core, "scale", Vector2(1.28, 1.28), 0.1)
	tween.tween_property(_core, "scale", Vector2.ONE, 0.2)

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
