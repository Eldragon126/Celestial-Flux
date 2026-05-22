extends CharacterBody2D

# Boss encounter for the wave game. The Gravity Warden is a moving mass,
# a bullet-pattern shooter, and a summoner so the previous modular ideas feel
# like one escalating fight instead of separate demos.

signal boss_health_changed(current_health: float, max_health: float)
signal boss_defeated
signal phase_entered(phase: int)
signal phase_exited(phase: int)

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")
const LEECH_SCENE = preload("res://Nodes/leech_parasite.tscn")
const SPLITTER_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")
const HARASSER_SCENE = preload("res://Nodes/gravity_harasser.tscn")
const COLLISION_SPARK_SCENE = preload("res://Nodes/collision_sparks.tscn")

@export var max_health = 880.0
@export var mass = 265000.0
@export var orbit_distance = 650.0
@export var move_speed = 335.0
@export var gravity_radius = 980.0
@export var gravity_strength = 2350.0
@export var projectile_speed = 860.0
@export var fire_interval = 1.75
@export var summon_interval = 10.5
@export var max_support_units = 4
@export var gravity_channel_duration = 1.25

var _player: Node = null
var _health: HealthComponent = null
var _fire_timer: Timer
var _summon_timer: Timer
var _phase = 1
var _orbit_angle = 0.0
var _aura_polygon: Polygon2D
var _core_polygon: Polygon2D
var _rng = RandomNumberGenerator.new()
var _resonance_manager: Node = null
var _gravity_channel_until := 0.0
var _support_units: Array[Node] = []

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wave_enemy")
	add_to_group("bosses")
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")

	_rng.randomize()
	_player = get_tree().get_first_node_in_group("Player")
	_build_body()
	_build_health()
	_build_timers()

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		return

	_update_phase()
	_move_around_player(delta)
	_pull_player(delta)

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func get_health_ratio() -> float:
	if _health == null or _health.max_health <= 0.0:
		return 0.0
	return clampf(_health.current_health / _health.max_health, 0.0, 1.0)

func _build_body() -> void:
	if has_node("GravityAuraPolygon"):
		_aura_polygon = get_node("GravityAuraPolygon") as Polygon2D
		_core_polygon = get_node("WardenCorePolygon") as Polygon2D
		if _aura_polygon != null and _aura_polygon.polygon.is_empty():
			_aura_polygon.polygon = _circle_points(56, 148.0)
		if _core_polygon != null and _core_polygon.polygon.is_empty():
			_core_polygon.polygon = _circle_points(8, 42.0)
	else:
		_build_body_polygons()

	if has_node("CollisionPolygon2D"):
		return

	var hull_polygon := PackedVector2Array([
		Vector2(116.0, 0.0),
		Vector2(58.0, 64.0),
		Vector2(-28.0, 84.0),
		Vector2(-106.0, 34.0),
		Vector2(-126.0, 0.0),
		Vector2(-106.0, -34.0),
		Vector2(-28.0, -84.0),
		Vector2(58.0, -64.0),
	])
	if has_node("WardenHullPolygon"):
		var hull_node := get_node("WardenHullPolygon") as Polygon2D
		if hull_node != null:
			hull_polygon = hull_node.polygon

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = hull_polygon
	add_child(collision)

	var attack_area = Area2D.new()
	attack_area.name = "RamDamageArea"
	attack_area.monitoring = true
	attack_area.body_entered.connect(_on_ram_damage_area_body_entered)
	add_child(attack_area)

	var attack_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 132.0
	attack_shape.shape = circle
	attack_area.add_child(attack_shape)

	if has_node("BossGravityParticles"):
		return

	var particles = GPUParticles2D.new()
	particles.name = "BossGravityParticles"
	particles.z_index = -2
	particles.amount = 120
	particles.lifetime = 2.2
	particles.randomness = 0.65
	particles.process_material = _make_gravity_material()
	add_child(particles)


func _build_body_polygons() -> void:
	_aura_polygon = Polygon2D.new()
	_aura_polygon.name = "GravityAuraPolygon"
	_aura_polygon.z_index = -3
	_aura_polygon.color = Color(0.0, 0.95, 0.78, 0.11)
	_aura_polygon.polygon = _circle_points(56, 148.0)
	add_child(_aura_polygon)

	var hull = Polygon2D.new()
	hull.name = "WardenHullPolygon"
	hull.color = Color(0.52, 0.06, 0.32, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(116.0, 0.0),
		Vector2(58.0, 64.0),
		Vector2(-28.0, 84.0),
		Vector2(-106.0, 34.0),
		Vector2(-126.0, 0.0),
		Vector2(-106.0, -34.0),
		Vector2(-28.0, -84.0),
		Vector2(58.0, -64.0),
	])
	add_child(hull)

	_core_polygon = Polygon2D.new()
	_core_polygon.name = "WardenCorePolygon"
	_core_polygon.color = Color(0.0, 0.92, 1.0, 1.0)
	_core_polygon.polygon = _circle_points(8, 42.0)
	add_child(_core_polygon)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)

func _build_timers() -> void:
	_fire_timer = Timer.new()
	_fire_timer.name = "BossFireTimer"
	_fire_timer.wait_time = fire_interval
	_fire_timer.timeout.connect(_fire_pattern)
	add_child(_fire_timer)
	_fire_timer.start()

	_summon_timer = Timer.new()
	_summon_timer.name = "BossSummonTimer"
	_summon_timer.wait_time = summon_interval
	_summon_timer.timeout.connect(_summon_support)
	add_child(_summon_timer)
	_summon_timer.start()

func _update_phase() -> void:
	var ratio = get_health_ratio()
	var next_phase = 1
	if ratio < 0.34:
		next_phase = 3
	elif ratio < 0.67:
		next_phase = 2

	if next_phase == _phase:
		return

	phase_exited.emit(_phase)
	_phase = next_phase
	phase_entered.emit(_phase)
	_fire_timer.wait_time = maxf(0.82, fire_interval - 0.24 * float(_phase - 1))
	_summon_timer.wait_time = maxf(7.0, summon_interval - 0.7 * float(_phase - 1))

	if _core_polygon != null:
		_core_polygon.color = Color(1.0, 0.23, 0.08, 1.0) if _phase == 3 else Color(0.0, 0.92, 1.0, 1.0)

func _move_around_player(delta: float) -> void:
	_orbit_angle += delta * (0.24 + 0.08 * float(_phase))
	var target = _player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_distance
	var speed_limit: float = float(move_speed) + 45.0 * float(_phase - 1)
	if _is_gravity_channeling():
		speed_limit *= 0.48

	var desired = (target - global_position).limit_length(speed_limit)

	velocity = velocity.lerp(desired, clampf(delta * 1.9, 0.0, 1.0))
	move_and_slide()

	var aim = (_player.global_position - global_position).normalized()
	if aim != Vector2.ZERO:
		rotation = lerp_angle(rotation, aim.angle(), clampf(delta * 4.5, 0.0, 1.0))

	if _aura_polygon != null:
		_aura_polygon.rotation -= delta * (0.8 + float(_phase) * 0.22)

func _pull_player(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var offset = global_position - _player.global_position
	var dist = offset.length()
	if dist <= 1.0 or dist > gravity_radius:
		return

	var player_velocity = _player.get("velocity")
	if not player_velocity is Vector2:
		return

	var channel_bonus := 1.35 if _is_gravity_channeling() else 1.0
	var readable_falloff := clampf((dist - 120.0) / maxf(gravity_radius - 120.0, 1.0), 0.32, 1.0)
	var pull = offset.normalized() * gravity_strength * mass * channel_bonus * readable_falloff / maxf(dist * dist, 2200.0)
	var next_velocity: Vector2 = player_velocity + pull * delta
	var player_cap_value = _player.get("current_max_speed")
	if typeof(player_cap_value) == TYPE_FLOAT or typeof(player_cap_value) == TYPE_INT:
		next_velocity = next_velocity.limit_length(float(player_cap_value) + 520.0)
	_player.set("velocity", next_velocity)

func _fire_pattern() -> void:
	if _player == null or not is_instance_valid(_player) or get_parent() == null:
		return

	var aim = (_player.global_position - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT.rotated(rotation)

	_pulse_core()
	_gravity_channel_until = Time.get_ticks_msec() / 1000.0 + gravity_channel_duration

	if _phase == 1:
		_command_resonance_field(GravityResonanceManager.ZoneType.HARMONIC_ORBIT)
		_spawn_bullet(aim, projectile_speed * 0.92)
	elif _phase == 2:
		_command_resonance_field(GravityResonanceManager.ZoneType.COMPRESSION)
		_spawn_bullet(aim, projectile_speed * 1.02)
	else:
		_command_resonance_field(GravityResonanceManager.ZoneType.INVERSION)
		for i in range(4):
			var ring_dir = aim.rotated(TAU * float(i) / 4.0 + _orbit_angle * 0.4)
			_spawn_bullet(ring_dir, projectile_speed * 0.82)

func _spawn_bullet(direction: Vector2, speed: float) -> void:
	var bullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position + direction * 130.0
	bullet.global_rotation = direction.angle()
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, speed, self)
	elif bullet.get("initial_speed") != null:
		bullet.set("initial_speed", speed)
	get_parent().call_deferred("add_child", bullet)

func _summon_support() -> void:
	if get_parent() == null:
		return

	_cleanup_support_units()
	if _support_units.size() >= max_support_units:
		return

	var summon_count = mini(max_support_units - _support_units.size(), 1 + int(_phase >= 2))
	for i in range(summon_count):
		var scene: PackedScene = LEECH_SCENE
		if _phase == 2:
			scene = HARASSER_SCENE if i == 0 else LEECH_SCENE
		elif _phase >= 3:
			scene = HARASSER_SCENE if i == 0 else SPLITTER_SCENE

		var minion = scene.instantiate()
		minion.add_to_group("wave_enemy")
		var minion_2d = minion as Node2D
		if minion_2d != null:
			minion_2d.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(summon_count) + _rng.randf_range(-0.2, 0.2)) * 210.0
		get_parent().call_deferred("add_child", minion)
		_support_units.append(minion)

	if _player != null and _player.has_method("_refresh_gravity_sources"):
		_player.call_deferred("_refresh_gravity_sources", true)

func _on_ram_damage_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and body.has_method("take_damage"):
		var body_2d = body as Node2D
		if body_2d == null:
			return

		body.take_damage(14.0 + 5.0 * float(_phase))

		var body_velocity = body.get("velocity")
		var push = (body_2d.global_position - global_position).normalized()
		body.set("velocity", body_velocity + push * 520.0)

func _pulse_core() -> void:
	if _core_polygon == null:
		return

	var tween = create_tween()
	_core_polygon.scale = Vector2.ONE
	tween.tween_property(_core_polygon, "scale", Vector2(1.22, 1.22), 0.08)
	tween.tween_property(_core_polygon, "scale", Vector2.ONE, 0.18)

func _command_resonance_field(zone_type: int) -> void:
	var manager := _get_resonance_manager()
	if manager == null or not manager.has_method("create_manual_resonance_zone"):
		return

	var center := global_position
	if _player != null and is_instance_valid(_player):
		center = (global_position + _player.global_position) * 0.5

	manager.call(
		"create_manual_resonance_zone",
		center,
		260.0 + 42.0 * float(_phase),
		zone_type,
		0.58 + 0.12 * float(_phase),
		2.4
	)

func _get_resonance_manager() -> Node:
	if _resonance_manager != null and is_instance_valid(_resonance_manager):
		return _resonance_manager
	var root := get_tree().current_scene
	if root == null:
		return null
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	return _resonance_manager

func _is_gravity_channeling() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _gravity_channel_until

func _cleanup_support_units() -> void:
	var kept: Array[Node] = []
	for unit in _support_units:
		if unit != null and is_instance_valid(unit) and not unit.is_queued_for_deletion():
			kept.append(unit)
	_support_units = kept

func _on_health_changed(current_health: float, new_max_health: float) -> void:
	boss_health_changed.emit(current_health, new_max_health)

func _on_died() -> void:
	if get_parent() != null:
		var sparks = COLLISION_SPARK_SCENE.instantiate()
		get_parent().add_child(sparks)
		sparks.global_position = global_position
		sparks.scale = Vector2(5.0, 5.0)

	boss_defeated.emit()
	queue_free()

func _make_gravity_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 150.0
	material.spread = 180.0
	material.initial_velocity_min = 12.0
	material.initial_velocity_max = 90.0
	material.radial_accel_min = -170.0
	material.radial_accel_max = -54.0
	material.orbit_velocity_min = 0.25
	material.orbit_velocity_max = 1.4
	material.gravity = Vector3.ZERO
	material.scale_min = 1.8
	material.scale_max = 6.4
	material.color = Color(0.0, 0.92, 1.0, 0.72)
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.7
	return material

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
