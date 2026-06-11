extends PhaseBoss
class_name SecretLawBoss

## Optional hidden boss with variant-driven rules. The scene owns editable
## polygons, rings, and particles; this script only fills missing defaults.

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

@export_enum("Vector Shade", "Chronal Mirror") var secret_variant: int = 0
@export var display_name: String = "VECTOR SHADE"
@export var orbit_distance: float = 560.0
@export var move_speed: float = 460.0
@export var projectile_speed: float = 820.0
@export var projectile_count: int = 9
@export var rule_radius: float = 620.0
@export var rule_force: float = 820.0
@export var reward_drop_count: int = 2

var _orbit_angle := 0.0
var _rule_charge := 0.0
var _hull: Polygon2D = null
var _core: Polygon2D = null
var _rings: Array[Line2D] = []
var _particles: GPUParticles2D = null
var _resonance_manager: Node = null
var _time_manager: Node = null


func _ready() -> void:
	max_health = maxf(max_health, 1180.0)
	mass = 410000.0
	attack_interval = 2.35
	display_name = "CHRONAL MIRROR" if secret_variant == 1 else "VECTOR SHADE"
	_build_editable_body()
	super._ready()


func _boss_physics(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var direction := -1.0 if secret_variant == 1 else 1.0
	_orbit_angle += delta * direction * (0.32 + 0.08 * float(current_phase))
	var target := player.global_position + Vector2.from_angle(_orbit_angle) * orbit_distance
	if secret_variant == 1:
		target += _player_velocity().limit_length(180.0)

	velocity = velocity.lerp((target - global_position).limit_length(move_speed), clampf(delta * 2.0, 0.0, 1.0))
	move_and_slide()
	_apply_secret_rule(delta)
	_update_visuals(delta)


func _run_attack_pattern() -> void:
	if player == null or not is_instance_valid(player):
		return
	_rule_charge = 1.0
	if secret_variant == 1:
		_spawn_temporal_gate()
	else:
		_spawn_vector_shear()
	_spawn_projectile_pattern()


func _on_enter_phase(phase: int) -> void:
	if _core != null:
		_core.color = _phase_color(phase)
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.2, attack_interval - 0.28 * float(phase - 1))


func _build_editable_body() -> void:
	_hull = get_node_or_null("SecretHull") as Polygon2D
	if _hull == null:
		_hull = Polygon2D.new()
		_hull.name = "SecretHull"
		add_child(_hull)
	if _hull.polygon.is_empty():
		# CORRECTED: Passed the float (radius) first, then int (count)
		_hull.polygon = _circle_points(96.0, 9)
	_hull.color = Color(0.12, 0.08, 0.22, 0.92)

	_core = get_node_or_null("SecretCore") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "SecretCore"
		add_child(_core)
	if _core.polygon.is_empty():
		# CORRECTED: Passed the float (radius) first, then int (count)
		_core.polygon = _circle_points(38.0, 7)
	_core.color = _phase_color(1)

	_rings.clear()
	for child in get_children():
		if child is Line2D and String(child.name).begins_with("SecretRuleRing"):
			_rings.append(child as Line2D)
	if _rings.is_empty():
		for i in range(3):
			var ring := Line2D.new()
			ring.name = "SecretRuleRing%d" % i
			ring.closed = true
			ring.antialiased = true
			ring.width = 2.0
			add_child(ring)
			_rings.append(ring)

	_particles = get_node_or_null("SecretParticles") as GPUParticles2D
	if _particles != null:
		_particles.emitting = true

	if not has_node("CollisionShape2D") and not has_node("CollisionPolygon2D"):
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		# CORRECTED: Passed the float (radius) first, then int (count)
		collision.polygon = _circle_points(100.0, 9)
		add_child(collision)


func _apply_secret_rule(delta: float) -> void:
	if _rule_charge <= 0.0:
		return
	_rule_charge = maxf(_rule_charge - delta * 0.42, 0.0)

	for group_name in [&"Player", &"Projectiles", &"enemy_projectiles"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if target == self or not is_instance_valid(target) or target.is_queued_for_deletion():
				continue
			var target_2d := target as Node2D
			if target_2d == null:
				continue
			var offset := target_2d.global_position - global_position
			var distance := offset.length()
			if distance <= 1.0 or distance > rule_radius:
				continue

			var radial := offset.normalized()
			var tangent := radial.orthogonal()
			if tangent.dot(_body_velocity(target_2d)) < 0.0:
				tangent = -tangent
			var falloff := 1.0 - distance / rule_radius
			var direction := tangent if secret_variant == 0 else -_body_velocity(target_2d).normalized()
			if direction == Vector2.ZERO:
				direction = -radial if secret_variant == 1 else tangent
			CombatStatus.add_velocity(target_2d, direction.normalized() * rule_force * _rule_charge * falloff * delta)

			if secret_variant == 1 and not target_2d.is_in_group("Player"):
				CombatStatus.apply_local_slow(target_2d, 0.62, 0.28)


func _spawn_vector_shear() -> void:
	var resonance := _get_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	var center := (global_position + player.global_position) * 0.5
	resonance.call("create_manual_resonance_zone", center, 300.0, GravityResonanceManager.ZoneType.SLIPSTREAM, 0.78, 2.7)


func _spawn_temporal_gate() -> void:
	var resonance := _get_resonance_manager()
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		var center := (global_position + player.global_position) * 0.5
		resonance.call("create_manual_resonance_zone", center, 310.0, GravityResonanceManager.ZoneType.TEMPORAL_SCAR, 0.82, 2.9)
	var time_manager := _get_time_manager()
	if time_manager != null and time_manager.has_method("create_time_pocket"):
		time_manager.call("create_time_pocket", global_position, 360.0, 0.54, 2.2)


func _spawn_projectile_pattern() -> void:
	if get_parent() == null:
		return
	var aim := (player.global_position - global_position).angle()
	var count = projectile_count + current_phase * 2
	for i in range(count):
		# Check global bullet cap before spawning each projectile
		if not BulletManager.can_spawn_bullet():
			break

		var spread := (float(i) - float(count - 1) * 0.5) * 0.18
		var dir := Vector2.from_angle(aim + spread)
		if secret_variant == 0 and i % 2 == 1:
			dir = dir.rotated(PI * 0.5)
		var bullet := ENEMY_BULLET_SCENE.instantiate()
		bullet.global_position = global_position + dir * 116.0
		if bullet.has_method("configure_launch"):
			bullet.call("configure_launch", dir, projectile_speed, self)
		elif bullet.get("initial_speed") != null:
			bullet.set("initial_speed", projectile_speed)
		get_parent().call_deferred("add_child", bullet)


func _update_visuals(delta: float) -> void:
	rotation += delta * (0.2 + 0.06 * float(current_phase))
	for i in range(_rings.size()):
		var ring := _rings[i]
		if ring == null:
			continue
		var radius := 126.0 + float(i) * 46.0 + _rule_charge * 34.0
		# CORRECTED: Passed the float (radius) first, then int (count)
		ring.points = _circle_points(radius, 64)
		ring.rotation += delta * (0.5 + float(i) * 0.22) * (-1.0 if secret_variant == 1 else 1.0)
		var color := Color(0.36, 1.0, 0.88, 0.32) if secret_variant == 0 else Color(0.82, 0.42, 1.0, 0.32)
		ring.default_color = color
	if _core != null:
		_core.scale = Vector2.ONE * (1.0 + _rule_charge * 0.12 + sin(Time.get_ticks_msec() / 140.0) * 0.035)


func _on_died() -> void:
	_drop_secret_rewards()
	super._on_died()


func _drop_secret_rewards() -> void:
	if get_parent() == null:
		return
	for i in range(reward_drop_count):
		var offset := Vector2.from_angle(TAU * float(i) / float(maxi(reward_drop_count, 1))) * 90.0
		PowerupLibrary.try_spawn_drop(get_parent(), global_position + offset, 1.0, true)


func _get_resonance_manager() -> Node:
	if _resonance_manager != null and is_instance_valid(_resonance_manager):
		return _resonance_manager
	var root := get_tree().current_scene
	if root == null:
		return null
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	return _resonance_manager


func _get_time_manager() -> Node:
	if _time_manager != null and is_instance_valid(_time_manager):
		return _time_manager
	var root := get_tree().current_scene
	if root == null:
		return null
	_time_manager = root.find_child("TimeDilationManager", true, false)
	return _time_manager


func _player_velocity() -> Vector2:
	if player == null:
		return Vector2.ZERO
	var value: Variant = player.get("velocity")
	return value if value is Vector2 else Vector2.ZERO


func _body_velocity(body: Node) -> Vector2:
	var value: Variant = body.get("velocity")
	if value is Vector2:
		return value
	value = body.get("linear_velocity")
	return value if value is Vector2 else Vector2.ZERO


func _phase_color(phase: int) -> Color:
	if secret_variant == 1:
		return [Color(0.72, 0.42, 1.0, 1.0), Color(0.42, 0.9, 1.0, 1.0), Color(1.0, 0.38, 0.86, 1.0)][clampi(phase - 1, 0, 2)]
	return [Color(0.32, 1.0, 0.78, 1.0), Color(1.0, 0.82, 0.24, 1.0), Color(1.0, 0.34, 0.16, 1.0)][clampi(phase - 1, 0, 2)]


# CORRECTED: Function signature now matches parent (float, int)
func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
