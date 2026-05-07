extends PhaseBoss

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")
const SPLITTER_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")

@export var orbit_distance = 720.0
@export var move_speed = 395.0
@export var gravity_radius = 920.0
@export var gravity_strength = 1550.0
@export var projectile_speed = 720.0

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

	if get_parent() == null:
		return

	if current_phase == 1:
		_spawn_radial_bullets(10, projectile_speed)
	elif current_phase == 2:
		_spawn_radial_bullets(14, projectile_speed * 0.95)
		_spawn_debris_ring(5)
	else:
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
	_aura = Polygon2D.new()
	_aura.name = "AccretionAura"
	_aura.z_index = -3
	_aura.color = Color(0.12, 0.86, 1.0, 0.11)
	_aura.polygon = _circle_points(64, 170.0)
	add_child(_aura)

	var shell = Polygon2D.new()
	shell.name = "AccretionShell"
	shell.color = Color(0.12, 0.08, 0.24, 1.0)
	shell.polygon = _circle_points(12, 118.0)
	add_child(shell)

	_core = Polygon2D.new()
	_core.name = "AccretionCore"
	_core.color = Color(0.04, 0.95, 0.84, 1.0)
	_core.polygon = _circle_points(10, 56.0)
	add_child(_core)

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

	var player_velocity = player.get("velocity")
	var pull = offset.normalized() * gravity_strength * mass / maxf(distance * distance, 1600.0)
	player.set("velocity", player_velocity + pull * delta)

func _spawn_radial_bullets(count: int, speed: float) -> void:
	for i in range(count):
		var direction = Vector2.RIGHT.rotated(TAU * float(i) / float(count) + _orbit_angle * 0.35)
		var bullet = ENEMY_BULLET_SCENE.instantiate()
		get_parent().call_deferred("add_child", bullet)
		bullet.global_position = global_position + direction * 132.0
		bullet.apply_impulse(direction * speed)

func _spawn_debris_ring(count: int) -> void:
	for i in range(count):
		var debris = SPLITTER_SCENE.instantiate()
		debris.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * 210.0
		debris.velocity = Vector2.RIGHT.rotated(TAU * float(i) / float(count) + PI * 0.5) * 240.0
		debris.add_to_group("wave_enemy")
		get_parent().call_deferred("add_child", debris)

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
