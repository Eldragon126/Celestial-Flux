extends CharacterBody2D

# =========================================
# PARAMETRIC ENEMY: DRIFTING VECTOR
# =========================================

var dt: float = 0.0
var total_time: float = 0.0
var player: Node2D

# =========================================
# SPACE PHYSICS SETTINGS
# =========================================
@export var A: float = 250.0  # Increased radius so it has room to drift
@export var B: float = 180.0

@export var a: float = 2.0
@export var b: float = 1.0

@export var equation_speed: float = 1.0

# Physics tuning for space inertia
@export var max_speed: float = 500.0
@export var engine_thrust: float = 1200.0  # How hard it pulls toward the pattern
@export var space_friction: float = 2.0    # Simulates slight dampening/thruster counter-burn
@export var contact_damage: float = 18.0
@export var dash_cooldown_min: float = 2.2
@export var dash_cooldown_max: float = 3.8
@export var dash_duration: float = 0.34
@export var dash_force_multiplier: float = 2.7
@export_group("Dance Partner")
@export var dance_beats_per_loop: int = 4
@export var dance_window_width: float = 0.12
@export var dance_damage_multiplier: float = 1.65
@export var slingshot_jam_multiplier: float = 1.35
@export var skill_hit_energy_reward: float = 4.0

var _rng := RandomNumberGenerator.new()
var _dash_cooldown := 0.0
var _dash_time := 0.0
var _dash_direction := Vector2.ZERO
var _hit_cooldown := 0.0
var _dance_window_active := false
var _dance_window_intensity := 0.0
var _last_skill_reward_time := -999.0
@onready var _body_polygon: Polygon2D = get_node_or_null("Body") as Polygon2D
@onready var _particles: GPUParticles2D = get_node_or_null("GPUParticles2D") as GPUParticles2D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ParametricEnemies")
	_rng.randomize()
	player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_dash_cooldown = _rng.randf_range(dash_cooldown_min, dash_cooldown_max)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	total_time += scaled_delta
	dt = fmod(dt + scaled_delta * equation_speed, TAU)
	_dash_cooldown -= scaled_delta
	_hit_cooldown = maxf(_hit_cooldown - scaled_delta, 0.0)
	
	# =========================
	# PHASE CHANGES
	# =========================
	if total_time > 150:
		A = 280; B = 100; a = 5; b = 2
	elif total_time > 100:
		A = 150; B = 250; a = 3; b = 2
	elif total_time > 70:
		A = 300; B = 120; a = 4; b = 3
	elif total_time > 40:
		A = 200; B = 200; a = 3; b = 2
	elif total_time > 20:
		A = 250; B = 150; a = 2; b = 1

	if total_time > 200.0:
		queue_free()
		return

	if player == null or not is_instance_valid(player):
		player = MultiplayerTargeting.nearest_player(global_position, get_tree())

	# =========================
	# THE "ANCHOR" POSITION
	# =========================
	var x = A * sin(a * dt)
	var y = B * cos(b * dt)
	_update_dance_window(dt)

	var anchor_position: Vector2
	if player != null:
		var player_velocity: Variant = player.get("velocity")
		var lead := Vector2.ZERO
		if player_velocity is Vector2 and player_velocity.length_squared() > 1.0:
			lead = player_velocity.normalized() * 90.0
		anchor_position = player.global_position + Vector2(x, y) + lead
	else:
		anchor_position = Vector2(x, y)

	# =========================
	# TRUE SPACE INERTIA PHYSICS
	# =========================
	# 1. Find direction to the moving pattern anchor
	var to_anchor = anchor_position - global_position
	var distance = to_anchor.length()

	if _dash_time > 0.0:
		_dash_time -= scaled_delta
		velocity += _dash_direction * engine_thrust * dash_force_multiplier * scaled_delta
	elif distance > 5.0:
		# 2. Apply a continuous thrust acceleration toward the pattern
		var thrust_direction = to_anchor.normalized()
		velocity += thrust_direction * engine_thrust * scaled_delta

	if _dash_cooldown <= 0.0 and player != null and distance < 720.0 and _dance_window_intensity > 0.58:
		_start_vector_dash(anchor_position)
	
	# 3. Apply space friction so it doesn't orbit infinitely or overshoot wildly
	velocity -= velocity * space_friction * scaled_delta

	# 4. Clamp to max speed so it doesn't accelerate into hyperspace
	velocity = velocity.limit_length(max_speed)

	move_and_slide()
	_damage_slide_collisions()

	if velocity.length() > 10:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(scaled_delta * 7.0, 0.0, 1.0))
	if _body_polygon != null:
		var pulse := 0.72 + 0.28 * sin(total_time * 9.0)
		var dance_glow := _dance_window_intensity
		_body_polygon.color = Color(1.0, 0.08 + pulse * 0.2 + dance_glow * 0.42, 0.28 + pulse * 0.25 + dance_glow * 0.52, 1.0)
	if _particles != null:
		_particles.speed_scale = lerpf(0.7, 1.8, _dance_window_intensity)
	
func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		var final_amount := amount * _skill_damage_multiplier()
		$HealthComponent.take_damage(final_amount)
		if final_amount > amount + 0.01:
			_reward_skill_hit()

func _on_health_component_died() -> void:
	queue_free()


func _on_health_component_health_changed(current_health: Variant, max_health: Variant) -> void:
	var ratio := _health_ratio(current_health, max_health)
	if _body_polygon != null:
		_body_polygon.modulate.a = lerpf(0.7, 1.0, ratio)
	if _particles != null:
		_particles.amount_ratio = lerpf(1.0, 0.55, 1.0 - ratio)

func _start_vector_dash(anchor_position: Vector2) -> void:
	var to_player := (player.global_position - global_position).normalized() if player != null else Vector2.RIGHT.rotated(rotation)
	var tangent := to_player.orthogonal()
	if tangent.dot(anchor_position - global_position) < 0.0:
		tangent = -tangent
	_dash_direction = (to_player * 0.58 + tangent * 0.42).normalized()
	_dash_time = dash_duration
	_dash_cooldown = _rng.randf_range(dash_cooldown_min, dash_cooldown_max)

func _damage_slide_collisions() -> void:
	if _hit_cooldown > 0.0:
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		var body_2d := body as Node2D
		if body_2d != null and body.is_in_group("Player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			CombatStatus.add_velocity(body, (body_2d.global_position - global_position).normalized() * 420.0)
			_hit_cooldown = 0.65
			return

func _update_dance_window(phase_time: float) -> void:
	var phase := fposmod(phase_time, TAU) / TAU
	var beats := maxi(dance_beats_per_loop, 1)
	var beat_phase := fposmod(phase * float(beats), 1.0)
	var distance_to_beat := minf(beat_phase, 1.0 - beat_phase)
	var width := clampf(dance_window_width, 0.01, 0.48)
	_dance_window_intensity = clampf(1.0 - distance_to_beat / width, 0.0, 1.0)
	_dance_window_active = _dance_window_intensity > 0.0

func _skill_damage_multiplier() -> float:
	var multiplier := 1.0
	if _dance_window_active:
		multiplier *= lerpf(1.0, dance_damage_multiplier, _dance_window_intensity)

	if _player_recently_slinged():
		multiplier *= slingshot_jam_multiplier

	return multiplier

func _player_recently_slinged() -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var time_value: Variant = player.get("last_slingshot_time")
	var score_value: Variant = player.get("last_slingshot_score")
	if not (typeof(time_value) == TYPE_FLOAT or typeof(time_value) == TYPE_INT):
		return false
	if not (typeof(score_value) == TYPE_FLOAT or typeof(score_value) == TYPE_INT):
		return false

	return Time.get_ticks_msec() / 1000.0 - float(time_value) < 1.35 and float(score_value) >= 0.58

func _reward_skill_hit() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_skill_reward_time < 0.18:
		return
	_last_skill_reward_time = now

	if player != null and is_instance_valid(player):
		var energy := player.get_node_or_null("EnergyComponent")
		if energy != null and energy.has_method("restore"):
			energy.call("restore", skill_hit_energy_reward * (1.0 + _dance_window_intensity))

	_spawn_skill_hit_ring()

func _spawn_skill_hit_ring() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := Line2D.new()
	ring.name = "ParametricSkillHit"
	ring.closed = true
	ring.antialiased = true
	ring.width = 3.0
	ring.default_color = Color(0.32, 1.0, 0.86, 0.82)
	ring.points = _circle_points(28, 1.0)
	ring.global_position = global_position
	ring.scale = Vector2.ONE * 8.0
	ring.z_index = 31
	root.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 78.0, 0.2)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.2)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(ring))


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _health_ratio(current_health: Variant, max_health: Variant) -> float:
	var current := float(current_health) if typeof(current_health) == TYPE_FLOAT or typeof(current_health) == TYPE_INT else 0.0
	var maximum := float(max_health) if typeof(max_health) == TYPE_FLOAT or typeof(max_health) == TYPE_INT else 1.0
	return clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
