extends PhaseBoss

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")
const SPLITTER_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")

@export var orbit_distance = 720.0
@export var move_speed = 395.0
@export var gravity_radius = 920.0
@export var gravity_strength = 1550.0
@export var projectile_speed = 720.0
@export var compression_pressure_radius = 520.0
@export var compression_pressure_force = 620.0
@export var max_debris_ring_count: int = 3
@export var max_active_debris: int = 7

var _orbit_angle = 0.0
var _aura: Polygon2D
var _core: Polygon2D

func _ready() -> void:
	max_health = max(max_health, 960.0)
	attack_interval = 2.65
	_build_body()
	super._ready()

func _boss_physics(delta: float) -> void:
	if player == null:
		return

	_orbit_angle += delta * (0.22 + 0.1 * float(current_phase))
	var target = player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_distance
	if current_phase == 3:
		target = player.global_position + (global_position - player.global_position).normalized() * 360.0

	velocity = velocity.lerp((target - global_position).limit_length(move_speed + 70.0 * current_phase), clampf(delta * 1.8, 0.0, 1.0))
	move_and_slide()
	_pull_player(delta)

	if _aura != null:
		_aura.rotation -= delta * (0.65 + current_phase * 0.25)

func _run_attack_pattern() -> void:
	_telegraph_pulse()
	await get_tree().create_timer(0.34).timeout

	if is_queued_for_deletion() or get_parent() == null:
		return

	if current_phase == 1:
		_spawn_radial_bullets(10, projectile_speed)
	elif current_phase == 2:
		_apply_compression_pressure(0.72)
		_spawn_radial_bullets(14, projectile_speed * 0.95)
		_spawn_debris_ring(max_debris_ring_count)
	else:
		_apply_compression_pressure(1.0)
		_spawn_radial_bullets(18, projectile_speed * 1.04)
		_pull_player(0.28)

func on_damage_taken(_amount: float) -> void:
	if _core != null:
		_core.scale = Vector2(1.15, 1.15)
		var tween = create_tween()
		tween.tween_property(_core, "scale", Vector2.ONE, 0.16)

func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.05, attack_interval - 0.42 * float(phase - 1))
	gravity_radius = [900.0, 1040.0, 1180.0][phase - 1]
	gravity_strength = [1550.0, 1900.0, 2450.0][phase - 1]
	if _core != null:
		_core.color = [Color(0.04, 0.95, 0.84, 1.0), Color(0.82, 0.28, 1.0, 1.0), Color(1.0, 0.16, 0.08, 1.0)][phase - 1]

func _build_body() -> void:
	if has_node("AccretionAura"):
		_aura = get_node("AccretionAura") as Polygon2D
	else:
		_aura = Polygon2D.new()
		_aura.name = "AccretionAura"
		_aura.z_index = -3
		_aura.color = Color(0.12, 0.86, 1.0, 0.11)
		add_child(_aura)
	if _aura != null and _aura.polygon.is_empty():
		_aura.polygon = _circle_points(64, 170.0)

	var shell := get_node_or_null("AccretionShell") as Polygon2D
	if shell == null:
		shell = Polygon2D.new()
		shell.name = "AccretionShell"
		shell.color = Color(0.12, 0.08, 0.24, 1.0)
		add_child(shell)
	if shell.polygon.is_empty():
		shell.polygon = _circle_points(12, 118.0)

	if has_node("AccretionCore"):
		_core = get_node("AccretionCore") as Polygon2D
	else:
		_core = Polygon2D.new()
		_core.name = "AccretionCore"
		_core.color = Color(0.04, 0.95, 0.84, 1.0)
		add_child(_core)
	if _core != null and _core.polygon.is_empty():
		_core.polygon = _circle_points(10, 56.0)

	if not has_node("CollisionPolygon2D"):
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = shell.polygon
		add_child(collision)

func _pull_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var offset = global_position - player.global_position
	var distance = offset.length()
	if distance <= 1.0 or distance > gravity_radius:
		return

	var player_velocity: Variant = player.get("velocity")
	if not player_velocity is Vector2:
		return
	var pull = offset.normalized() * gravity_strength * mass / maxf(distance * distance, 1600.0)
	player.set("velocity", player_velocity + pull * delta)

func _spawn_radial_bullets(count: int, speed: float) -> void:
	for i in range(count):
		# Check global bullet cap before spawning each projectile
		if not BulletManager.can_spawn_bullet():
			break

		var direction = Vector2.RIGHT.rotated(TAU * float(i) / float(count) + _orbit_angle * 0.35)
		var bullet = ENEMY_BULLET_SCENE.instantiate()
		bullet.global_position = global_position + direction * 132.0
		bullet.global_rotation = direction.angle()
		if bullet.has_method("configure_launch"):
			bullet.call("configure_launch", direction, speed, self)
		elif bullet.get("initial_speed") != null:
			bullet.set("initial_speed", speed)
		get_parent().call_deferred("add_child", bullet)

func _spawn_debris_ring(count: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var active_debris := 0
	for debris_node in get_tree().get_nodes_in_group("accretion_core_debris"):
		if debris_node != null and is_instance_valid(debris_node) and not debris_node.is_queued_for_deletion():
			active_debris += 1
	if active_debris >= max_active_debris:
		return
	var spawn_count := mini(maxi(count, 0), max_active_debris - active_debris)
	for i in range(spawn_count):
		var debris = SPLITTER_SCENE.instantiate()
		debris.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * 210.0
		debris.velocity = Vector2.RIGHT.rotated(TAU * float(i) / float(count) + PI * 0.5) * 240.0
		debris.set("max_split_generation", 0)
		debris.add_to_group("wave_enemy")
		debris.add_to_group("accretion_core_debris")
		parent.call_deferred("add_child", debris)

func _apply_compression_pressure(multiplier: float) -> void:
	var radius: float = compression_pressure_radius + 90.0 * float(current_phase - 1)
	var radius_squared := radius * radius
	var seen := {}
	for group_name in [&"Projectiles", &"enemies", &"wave_enemy"]:
		for body in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(body):
				if body == self or body == player or not is_instance_valid(body) or body.is_queued_for_deletion():
					continue
				var body_2d := body as Node2D
				if body_2d == null:
					continue
				var id := body_2d.get_instance_id()
				if seen.has(id):
					continue
				seen[id] = true
				var offset := global_position - body_2d.global_position
				var dist_squared := offset.length_squared()
				if dist_squared <= 0.001 or dist_squared > radius_squared:
					continue
				var falloff := 1.0 - sqrt(dist_squared) / radius
				CombatStatus.add_velocity(body_2d, offset.normalized() * compression_pressure_force * multiplier * falloff)

func _telegraph_pulse() -> void:
	if _aura == null:
		return

	_aura.scale = Vector2.ONE
	var tween = create_tween()
	tween.tween_property(_aura, "scale", Vector2(1.45, 1.45), 0.28)
	tween.parallel().tween_property(_aura, "color:a", 0.28, 0.28)
	tween.tween_property(_aura, "color:a", 0.11, 0.24)

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
