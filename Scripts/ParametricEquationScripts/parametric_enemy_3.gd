extends RigidBody2D

@export_group("Parametric Motion")
@export var A: float = 30.0
@export var B: float = 30.0
@export var alpha: float = 1.0
@export var beta: float = 1.0
@export var C: float = 0.0
@export var D: float = 0.0
@export var speed: float = 100.0
@export var max_speed: float = 1500.0
@export var orbit_force: float = 620.0
@export var pursuit_force: float = 360.0
@export var pulse_charge_time: float = 0.72
@export var pulse_cooldown_min: float = 2.4
@export var pulse_cooldown_max: float = 4.2
@export var pulse_impulse: float = 980.0
@export var contact_damage: float = 32.0

@export_group("Dance Partner")
@export var dance_beats_per_loop: int = 5
@export var dance_window_width: float = 0.11
@export var dance_damage_multiplier: float = 1.5
@export var slingshot_jam_multiplier: float = 1.24
@export var skill_hit_energy_reward: float = 6.0

@export_group("Readable Visuals")
@export var calm_color: Color = Color(0.42, 0.95, 1.0, 1.0)
@export var beat_color: Color = Color(1.0, 0.86, 0.28, 1.0)
@export var charge_color: Color = Color(1.0, 0.18, 0.08, 1.0)
@export var damaged_color: Color = Color(1.0, 0.28, 0.18, 1.0)
@export_range(0.0, 1.0, 0.01) var body_alpha_cap: float = 1.0

@export_group("Skill Hit Ring")
@export var show_skill_hit_ring: bool = true
@export var skill_reward_cooldown: float = 0.18
@export var skill_ring_radius: float = 118.0
@export var skill_ring_duration: float = 0.22
@export var skill_ring_width: float = 4.0
@export_range(0.0, 1.0, 0.01) var skill_ring_alpha_cap: float = 0.46
@export_range(8, 64, 1) var skill_ring_segments: int = 34
@export var skill_ring_color: Color = Color(1.0, 0.86, 0.28, 0.84)

var dt: float = 0.0
var timestep: int = 0
var player: Node2D = null
var _rng := RandomNumberGenerator.new()
var _pulse_cooldown: float = 0.0
var _pulse_charge: float = 0.0
var _hit_cooldown: float = 0.0
var _dance_window_active: bool = false
var _dance_window_intensity: float = 0.0
var _health_ratio: float = 1.0
var _last_skill_reward_time: float = -999.0
@onready var _body_polygon: Polygon2D = get_node_or_null("Polygon2D") as Polygon2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ParametricEnemies")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
	_rng.randomize()
	player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_pulse_cooldown = _rng.randf_range(pulse_cooldown_min, pulse_cooldown_max)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")


func _physics_process(delta: float) -> void:
	var time_scale: float = CombatStatus.get_time_scale(self)
	var scaled_delta: float = delta * time_scale
	_pulse_cooldown -= scaled_delta
	_hit_cooldown = maxf(_hit_cooldown - scaled_delta, 0.0)
	_update_dance_window(dt)

	apply_force(equation(scaled_delta) * time_scale)

	if player == null or not is_instance_valid(player):
		player = MultiplayerTargeting.nearest_player(global_position, get_tree())

	if player != null:
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		if distance > 0.001:
			var dir := to_player / distance
			var tangent := dir.orthogonal()
			apply_force((dir * pursuit_force + tangent * orbit_force * sign(sin(dt))) * time_scale)

			if _pulse_charge > 0.0:
				_pulse_charge -= scaled_delta
				if _body_polygon != null:
					_body_polygon.color = _safe_readability_color(charge_color, body_alpha_cap)
				if _pulse_charge <= 0.0:
					apply_central_impulse(dir * pulse_impulse)
					_pulse_cooldown = _rng.randf_range(pulse_cooldown_min, pulse_cooldown_max)
			elif _pulse_cooldown <= 0.0 and distance < 880.0 and _dance_window_intensity > 0.58:
				_pulse_charge = pulse_charge_time

	angular_velocity = clampf(linear_velocity.length() / 120.0, -18.0, 18.0)
	if linear_velocity.length() >= max_speed:
		linear_velocity = linear_velocity.lerp(
			linear_velocity.normalized() * max_speed,
			clampf(8.0 * delta, 0.0, 1.0)
		)
	elif _body_polygon != null and _pulse_charge <= 0.0:
		_refresh_body_visual()


func equation(delta: float) -> Vector2:
	dt += delta * 8
	if dt > TAU:
		dt = 0.0
		timestep += 1
		
	if timestep > 5:
		timestep = 0

	return Vector2((-A * cos(dt * alpha) + C) * speed, (-B * sin(dt * beta) + D) * speed)


func _on_health_component_health_changed(current_health: Variant, max_health: Variant) -> void:
	var max_value := maxf(_numeric_value(max_health, 1.0), 1.0)
	_health_ratio = clampf(_numeric_value(current_health, max_value) / max_value, 0.0, 1.0)
	_refresh_body_visual()


func _on_health_component_died() -> void:
	queue_free()


func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		var final_amount := amount * _skill_damage_multiplier()
		$HealthComponent.take_damage(final_amount)
		if final_amount > amount + 0.01:
			_reward_skill_hit()


func _on_attack_body_body_entered(body: Node2D) -> void:
	if _hit_cooldown > 0.0:
		return
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		CombatStatus.add_velocity(body, (body.global_position - global_position).normalized() * 720.0)
		_hit_cooldown = 0.8


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

	return (
		Time.get_ticks_msec() / 1000.0 - float(time_value) < 1.35
		and float(score_value) >= 0.58
	)


func _reward_skill_hit() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_skill_reward_time < maxf(skill_reward_cooldown, 0.0):
		return
	_last_skill_reward_time = now

	if player != null and is_instance_valid(player):
		var energy := player.get_node_or_null("EnergyComponent")
		if energy != null and energy.has_method("restore"):
			energy.call("restore", skill_hit_energy_reward * (1.0 + _dance_window_intensity))

	_spawn_skill_hit_ring()


func _spawn_skill_hit_ring() -> void:
	if not show_skill_hit_ring:
		return
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := Line2D.new()
	ring.name = "ParametricPulseReward"
	ring.closed = true
	ring.antialiased = true
	ring.width = skill_ring_width
	ring.default_color = _safe_transient_color(skill_ring_color, skill_ring_alpha_cap)
	ring.points = _circle_points(_ring_segment_count(), 1.0)
	ring.global_position = global_position
	ring.scale = Vector2.ONE * 10.0
	ring.z_index = 31
	root.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * skill_ring_radius, skill_ring_duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, skill_ring_duration)
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


func _refresh_body_visual() -> void:
	if _body_polygon == null:
		return
	var damage_pressure := 1.0 - _health_ratio
	var color := calm_color.lerp(beat_color, _dance_window_intensity)
	color = color.lerp(damaged_color, clampf(damage_pressure * 0.72, 0.0, 1.0))
	_body_polygon.color = _safe_readability_color(color, body_alpha_cap)
	_body_polygon.scale = Vector2.ONE * lerpf(
		1.0,
		1.12,
		maxf(_dance_window_intensity, damage_pressure * 0.78)
	)


func _ring_segment_count() -> int:
	if Settings != null and Settings.has_method("world_polygon_segments"):
		return int(Settings.world_polygon_segments(skill_ring_segments, skill_ring_segments))
	return clampi(skill_ring_segments, 8, 64)


func _safe_readability_color(color: Color, cap: float) -> Color:
	var adjusted := color
	if Settings != null and Settings.has_method("apply_readability_color"):
		adjusted = Settings.apply_readability_color(adjusted)
	return Color(adjusted.r, adjusted.g, adjusted.b, minf(adjusted.a, cap))


func _safe_transient_color(color: Color, cap: float) -> Color:
	var adjusted := _safe_readability_color(color, cap)
	var alpha := adjusted.a
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = minf(float(Settings.flash_alpha(alpha)), cap)
	return Color(adjusted.r, adjusted.g, adjusted.b, alpha)


func _numeric_value(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback
