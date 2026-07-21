extends CharacterBody2D
class_name ParametricWaveSkimmer

signal gravity_wave_seeded(global_position: Vector2, wave_radius: float)

const GRAVITY_WAVE_MAKER_SCENE: PackedScene = preload("res://Nodes/gravity_wave_maker.tscn")

@export_group("Parametric Flight")
@export var max_health: float = 76.0
@export var A: float = 320.0
@export var B: float = 210.0
@export var a: float = 2.0
@export var b: float = 3.0
@export var equation_speed: float = 1.15
@export var engine_thrust: float = 1180.0
@export var drift_drag: float = 2.6
@export var max_speed: float = 620.0
@export var player_lead_distance: float = 115.0

@export_group("Gravity Wave Seed")
@export var wave_cooldown_min: float = 3.2
@export var wave_cooldown_max: float = 4.8
@export var wave_telegraph_time: float = 0.48
@export var wave_spawn_distance: float = 124.0
@export var wave_trigger_range: float = 960.0
@export var wave_base_radius: float = 42.0
@export var wave_point_count: int = 20
@export var wave_max_groups: int = 2
@export var wave_physics_points: int = 4
@export var wave_max_expansion_scale: float = 3.35
@export var wave_expansion_speed: float = 1.75
@export var wave_frequency: float = 4.0
@export var wave_amplitude: float = 18.0
@export var wave_spawn_interval: float = 0.54
@export var wave_lifetime: float = 2.75
@export var wave_base_mass: float = 82000.0

@export_group("Combat")
@export var contact_damage: float = 12.0
@export var impact_knockback: float = 320.0
@export var charged_hit_damage_multiplier: float = 1.18
@export var charged_hit_energy_reward: float = 2.5
@export var drop_chance: float = 0.14
@export var death_wave_enabled: bool = true

var _player: Node2D = null
var _health: HealthComponent = null
var _rng := RandomNumberGenerator.new()
var _phase: float = 0.0
var _total_time: float = 0.0
var _wave_cooldown_remaining: float = 0.0
var _charging_wave: bool = false
var _charge_elapsed: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT
var _hit_cooldown: float = 0.0
var _last_skill_reward_time: float = -999.0

var _body: Polygon2D = null
var _inner_core: Polygon2D = null
var _glow: Polygon2D = null
var _orbit_ring: Line2D = null
var _telegraph_ring: Line2D = null
var _trail_particles: GPUParticles2D = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ParametricEnemies")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")

	_rng.randomize()
	_phase = _rng.randf() * TAU
	_wave_cooldown_remaining = _rng.randf_range(wave_cooldown_min * 0.55, wave_cooldown_max)
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")


func _process(delta: float) -> void:
	_update_visuals(delta * CombatStatus.get_time_scale(self))


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	_total_time += scaled_delta
	_phase = fmod(_phase + scaled_delta * equation_speed, TAU)
	_hit_cooldown = maxf(_hit_cooldown - scaled_delta, 0.0)

	_update_player()
	_update_wave_logic(scaled_delta)
	_fly_parametric(scaled_delta)
	move_and_slide()
	_damage_slide_collisions()


func take_damage(amount: float) -> void:
	var final_amount := amount
	if _charging_wave:
		final_amount *= charged_hit_damage_multiplier
		_reward_charged_hit()
		_charge_elapsed = maxf(_charge_elapsed - wave_telegraph_time * 0.28, 0.0)
		velocity -= _charge_direction * 150.0

	if _health != null:
		_health.take_damage(final_amount)


func _update_player() -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())


func _fly_parametric(delta: float) -> void:
	var target_position := global_position + _parametric_offset(_phase)
	if _player != null and is_instance_valid(_player):
		target_position = _player.global_position + _parametric_offset(_phase) + _player_lead()

	var to_target := target_position - global_position
	if to_target.length_squared() > 25.0:
		velocity += to_target.normalized() * engine_thrust * delta

	if _charging_wave and _player != null and is_instance_valid(_player):
		var from_player := global_position - _player.global_position
		if from_player.length_squared() > 1.0:
			velocity += from_player.normalized().orthogonal() * engine_thrust * 0.18 * delta
			velocity *= pow(0.97, delta * 60.0)

	velocity -= velocity * clampf(drift_drag * delta, 0.0, 0.92)
	velocity = velocity.limit_length(max_speed)

	if velocity.length_squared() > 25.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 8.0, 0.0, 1.0))


func _parametric_offset(phase: float) -> Vector2:
	var twist := 0.18 * sin(_total_time * 0.31)
	var wobble := 0.32 * sin(_total_time * 0.43)
	return Vector2(
		A * sin(a * phase + wobble),
		B * cos(b * phase)
	).rotated(twist)


func _player_lead() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	var velocity_value: Variant = _player.get("velocity")
	if not (velocity_value is Vector2):
		return Vector2.ZERO
	var player_velocity := velocity_value as Vector2
	if player_velocity.length_squared() <= 1.0:
		return Vector2.ZERO
	return player_velocity.normalized() * player_lead_distance


func _update_wave_logic(delta: float) -> void:
	if _charging_wave:
		_charge_elapsed += delta
		if _charge_elapsed >= maxf(wave_telegraph_time, 0.02):
			_release_gravity_wave(false)
		return

	_wave_cooldown_remaining = maxf(_wave_cooldown_remaining - delta, 0.0)
	if _wave_cooldown_remaining > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_squared_to(_player.global_position) > wave_trigger_range * wave_trigger_range:
		return
	_begin_wave_charge()


func _begin_wave_charge() -> void:
	_charging_wave = true
	_charge_elapsed = 0.0
	if velocity.length_squared() > 100.0:
		_charge_direction = velocity.normalized()
	elif _player != null and is_instance_valid(_player):
		_charge_direction = (_player.global_position - global_position).normalized()
	else:
		_charge_direction = Vector2.RIGHT.rotated(rotation)
	if _charge_direction.length_squared() <= 0.001:
		_charge_direction = Vector2.RIGHT.rotated(rotation)


func _release_gravity_wave(final_wave: bool) -> void:
	var spawn_position := global_position
	if not final_wave:
		spawn_position += _charge_direction * wave_spawn_distance
	_charging_wave = false
	_charge_elapsed = 0.0
	_reset_wave_cooldown()
	_seed_gravity_wave(spawn_position, final_wave)
	_spawn_release_ring(spawn_position, final_wave)


func _reset_wave_cooldown() -> void:
	_wave_cooldown_remaining = _rng.randf_range(
		maxf(wave_cooldown_min, 0.25),
		maxf(wave_cooldown_max, wave_cooldown_min + 0.25)
	)


func _seed_gravity_wave(spawn_position: Vector2, final_wave: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return

	var wave := GRAVITY_WAVE_MAKER_SCENE.instantiate() as Node2D
	if wave == null:
		return

	var radius_multiplier := 1.42 if final_wave else 1.0
	var mass_multiplier := 1.35 if final_wave else 1.0
	wave.name = "ParametricSkimmerWave"
	wave.z_index = 16
	wave.global_position = spawn_position
	wave.set("base_radius", wave_base_radius * radius_multiplier)
	wave.set("number_of_points", maxi(wave_point_count, 8))
	wave.set("max_active_groups", maxi(wave_max_groups + (1 if final_wave else 0), 1))
	wave.set("max_expansion_scale", wave_max_expansion_scale * (1.18 if final_wave else 1.0))
	wave.set("expansion_speed", wave_expansion_speed)
	wave.set("wave_frequency", wave_frequency)
	wave.set("wave_amplitude", wave_amplitude * (1.35 if final_wave else 1.0))
	wave.set("spawn_interval", maxf(wave_spawn_interval, 0.12))
	wave.set("run_lifetime_seconds", wave_lifetime * (1.2 if final_wave else 1.0))
	wave.set("max_physics_points_per_group", clampi(wave_physics_points, 1, maxi(wave_point_count, 8)))
	wave.set("base_mass", wave_base_mass * mass_multiplier)
	wave.set("base_color", Color(0.02, 0.11, 0.16, 0.18))
	wave.set("wave_line_color", Color(0.2, 1.0, 0.78, 0.78))
	wave.set("point_color", Color(0.84, 1.0, 0.92, 0.82))
	if wave.has_method("configure_deterministic"):
		wave.call("configure_deterministic", _rng.randi(), &"parametric_wave_skimmer")
	root.call_deferred("add_child", wave)
	gravity_wave_seeded.emit(spawn_position, wave_base_radius * wave_max_expansion_scale * radius_multiplier)


func _reward_charged_hit() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_skill_reward_time < 0.24:
		return
	_last_skill_reward_time = now
	if _player != null and is_instance_valid(_player):
		var energy := _player.get_node_or_null("EnergyComponent")
		if energy != null and energy.has_method("restore"):
			energy.call("restore", charged_hit_energy_reward)
	_spawn_charged_hit_ring()


func _damage_slide_collisions() -> void:
	if _hit_cooldown > 0.0:
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as Node
		if _try_damage_player(body):
			_hit_cooldown = 0.55
			return


func _on_attack_area_body_entered(body: Node) -> void:
	if _try_damage_player(body):
		_hit_cooldown = 0.55


func _try_damage_player(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or _hit_cooldown > 0.0:
		return false
	var body_2d := body as Node2D
	if body_2d == null or not body.is_in_group("Player") or not body.has_method("take_damage"):
		return false
	body.call("take_damage", contact_damage)
	var knockback := (body_2d.global_position - global_position).normalized() * impact_knockback
	CombatStatus.add_velocity(body, knockback)
	return true


func _build_body() -> void:
	_glow = get_node_or_null("WaveGlow") as Polygon2D
	if _glow == null:
		_glow = Polygon2D.new()
		_glow.name = "WaveGlow"
		_glow.z_index = -3
		add_child(_glow)
	_glow.color = Color(0.04, 0.9, 0.72, 0.17)
	if _glow.polygon.is_empty():
		_glow.polygon = _circle_points(36, 72.0)

	_body = get_node_or_null("SkimmerBody") as Polygon2D
	if _body == null:
		_body = Polygon2D.new()
		_body.name = "SkimmerBody"
		add_child(_body)
	_body.color = Color(0.07, 1.0, 0.72, 1.0)
	if _body.polygon.is_empty():
		_body.polygon = PackedVector2Array([
			Vector2(42.0, 0.0),
			Vector2(8.0, 19.0),
			Vector2(-32.0, 28.0),
			Vector2(-18.0, 0.0),
			Vector2(-32.0, -28.0),
			Vector2(8.0, -19.0),
		])

	_inner_core = get_node_or_null("InnerCore") as Polygon2D
	if _inner_core == null:
		_inner_core = Polygon2D.new()
		_inner_core.name = "InnerCore"
		add_child(_inner_core)
	_inner_core.color = Color(0.9, 1.0, 0.94, 0.88)
	if _inner_core.polygon.is_empty():
		_inner_core.polygon = _circle_points(6, 13.0)

	if not has_node("CollisionPolygon2D"):
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = _body.polygon
		add_child(collision)

	_orbit_ring = get_node_or_null("OrbitGlyph") as Line2D
	if _orbit_ring == null:
		_orbit_ring = Line2D.new()
		_orbit_ring.name = "OrbitGlyph"
		_orbit_ring.z_index = -1
		add_child(_orbit_ring)
	_orbit_ring.closed = true
	_orbit_ring.antialiased = true
	_orbit_ring.width = 1.8
	_orbit_ring.default_color = Color(0.2, 1.0, 0.78, 0.34)
	if _orbit_ring.points.is_empty():
		_orbit_ring.points = _circle_points(48, 58.0)

	_telegraph_ring = get_node_or_null("WaveTelegraph") as Line2D
	if _telegraph_ring == null:
		_telegraph_ring = Line2D.new()
		_telegraph_ring.name = "WaveTelegraph"
		add_child(_telegraph_ring)
	_telegraph_ring.top_level = true
	_telegraph_ring.z_index = 34
	_telegraph_ring.closed = true
	_telegraph_ring.antialiased = true
	_telegraph_ring.visible = false
	_telegraph_ring.points = _circle_points(56, 1.0)

	var attack_area := get_node_or_null("AttackArea") as Area2D
	if attack_area == null:
		attack_area = Area2D.new()
		attack_area.name = "AttackArea"
		add_child(attack_area)
	attack_area.monitoring = true
	if not attack_area.body_entered.is_connected(Callable(self, "_on_attack_area_body_entered")):
		attack_area.body_entered.connect(_on_attack_area_body_entered)

	var attack_shape := attack_area.get_node_or_null("AttackShape") as CollisionShape2D
	if attack_shape == null:
		attack_shape = CollisionShape2D.new()
		attack_shape.name = "AttackShape"
		attack_area.add_child(attack_shape)
	if attack_shape.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 42.0
		attack_shape.shape = circle

	_trail_particles = get_node_or_null("WaveTrailParticles") as GPUParticles2D
	if _trail_particles == null:
		_trail_particles = GPUParticles2D.new()
		_trail_particles.name = "WaveTrailParticles"
		_trail_particles.z_index = -2
		_trail_particles.amount = 44
		_trail_particles.lifetime = 0.8
		_trail_particles.randomness = 0.45
		add_child(_trail_particles)
	if _trail_particles.process_material == null:
		_trail_particles.process_material = _make_trail_material()


func _build_health() -> void:
	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		add_child(_health)
	_health.max_health = max_health
	if not _health.died.is_connected(Callable(self, "_on_died")):
		_health.died.connect(_on_died)
	if not _health.health_changed.is_connected(Callable(self, "_on_health_changed")):
		_health.health_changed.connect(_on_health_changed)


func _update_visuals(delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_total_time * 8.0)
	var charge := _charge_progress()
	if _body != null:
		_body.scale = Vector2.ONE * (1.0 + pulse * 0.045 + charge * 0.08)
		_body.color = Color(0.07 + charge * 0.26, 0.82 + pulse * 0.18, 0.62 + charge * 0.22, 1.0)
	if _inner_core != null:
		_inner_core.rotation -= delta * (3.5 + charge * 7.0)
		_inner_core.scale = Vector2.ONE * (0.85 + pulse * 0.16 + charge * 0.2)
	if _glow != null:
		_glow.scale = Vector2.ONE * (0.92 + pulse * 0.09 + charge * 0.16)
		_glow.color.a = 0.13 + pulse * 0.08 + charge * 0.12
	if _orbit_ring != null:
		_orbit_ring.rotation += delta * (0.85 + charge * 1.6)
		_orbit_ring.default_color.a = 0.22 + charge * 0.28
	if _trail_particles != null:
		_trail_particles.speed_scale = 0.85 + charge * 1.4
		_trail_particles.emitting = true
	_update_telegraph_visual(delta)


func _update_telegraph_visual(delta: float) -> void:
	if _telegraph_ring == null:
		return
	if not _charging_wave:
		_telegraph_ring.visible = false
		return
	var progress := _charge_progress()
	var radius := lerpf(18.0, wave_base_radius * 1.85, progress)
	_telegraph_ring.visible = true
	_telegraph_ring.global_position = global_position + _charge_direction * wave_spawn_distance
	_telegraph_ring.rotation -= delta * (2.8 + progress * 5.0)
	_telegraph_ring.scale = Vector2.ONE * radius
	_telegraph_ring.width = 2.8 / maxf(radius, 1.0)
	_telegraph_ring.default_color = Color(0.2 + progress * 0.7, 1.0, 0.72, 0.22 + progress * 0.56)


func _charge_progress() -> float:
	return clampf(_charge_elapsed / maxf(wave_telegraph_time, 0.02), 0.0, 1.0) if _charging_wave else 0.0


func _on_health_changed(current_health: float, new_max_health: float) -> void:
	var ratio := clampf(current_health / maxf(new_max_health, 0.001), 0.0, 1.0)
	if _trail_particles != null:
		_trail_particles.amount_ratio = lerpf(0.5, 1.0, ratio)
	if _glow != null:
		_glow.modulate.a = lerpf(0.65, 1.0, ratio)


func _on_died() -> void:
	if death_wave_enabled:
		_seed_gravity_wave(global_position, true)
		_spawn_release_ring(global_position, true)
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, drop_chance, true)
	queue_free()


func _spawn_charged_hit_ring() -> void:
	var ring := _make_world_ring("SkimmerChargedHit", global_position, Color(0.75, 1.0, 0.82, 0.82), 28.0)
	if ring == null:
		return
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 58.0, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.tween_callback(Callable(ring, "queue_free"))


func _spawn_release_ring(spawn_position: Vector2, final_wave: bool) -> void:
	var color := Color(0.2, 1.0, 0.78, 0.76)
	if final_wave:
		color = Color(1.0, 0.92, 0.42, 0.82)
	var ring := _make_world_ring("SkimmerWaveBurst", spawn_position, color, 22.0)
	if ring == null:
		return
	var target_radius := wave_base_radius * (3.1 if final_wave else 2.15)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * target_radius, 0.24)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(ring, "queue_free"))


func _make_world_ring(ring_name: String, ring_position: Vector2, color: Color, width: float) -> Line2D:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return null
	var ring := Line2D.new()
	ring.name = ring_name
	ring.closed = true
	ring.antialiased = true
	ring.width = width
	ring.default_color = color
	ring.points = _circle_points(60, 1.0)
	ring.global_position = ring_position
	ring.z_index = 36
	ring.scale = Vector2.ONE * 5.0
	root.add_child(ring)
	return ring


func _make_trail_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 16.0
	material.spread = 155.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 84.0
	material.radial_accel_min = -54.0
	material.radial_accel_max = 18.0
	material.orbit_velocity_min = -0.7
	material.orbit_velocity_max = 0.7
	material.gravity = Vector3.ZERO
	material.scale_min = 0.8
	material.scale_max = 2.4
	material.color = Color(0.2, 1.0, 0.78, 0.72)
	return material


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 3)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
