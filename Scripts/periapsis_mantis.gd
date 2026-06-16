extends CharacterBody2D
class_name PeriapsisMantis

signal periapsis_strike_started(strike_data: Dictionary)

enum StrikeState { WATCHING, TELEGRAPH, DASH, RECOVER }

@export var max_health: float = 92.0
@export var trigger_speed: float = 980.0
@export var gravity_source_distance: float = 430.0
@export var telegraph_time: float = 0.72
@export var dash_speed: float = 1780.0
@export var cooldown: float = 3.2
@export var damage: float = 26.0

@export_group("Movement")
@export var watch_acceleration: float = 520.0
@export var watch_max_speed: float = 360.0
@export var preferred_watch_distance: float = 720.0
@export var strike_half_length: float = 560.0
@export var recover_time: float = 0.42
@export var gravity_refresh_interval: float = 0.22

var _player: Node2D = null
var _health: HealthComponent = null
var _state: int = StrikeState.WATCHING
var _state_elapsed: float = 0.0
var _cooldown_remaining: float = 1.1
var _gravity_elapsed: float = 999.0
var _strike_center: Vector2 = Vector2.ZERO
var _strike_tangent: Vector2 = Vector2.RIGHT
var _strike_start: Vector2 = Vector2.ZERO
var _strike_end: Vector2 = Vector2.ZERO
var _dash_distance: float = 0.0
var _dash_hit_ids: Dictionary = {}
var _gravity_sources: Array[Node2D] = []
var _warning_line: Line2D = null
var _warning_glyph: Line2D = null
var _core: Polygon2D = null
var _wing: Polygon2D = null
var _attack_area: Area2D = null


func _ready() -> void:
	add_to_group("enemies")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
	_cleanup_warning_nodes()


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_gravity_elapsed += delta
	if _gravity_elapsed >= gravity_refresh_interval:
		_refresh_player_gravity_sources()
	_update_warning_visuals()
	_update_body_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return

	match _state:
		StrikeState.WATCHING:
			_watch_player(scaled_delta)
			if _cooldown_remaining <= 0.0 and _player_is_in_periapsis_state():
				_begin_telegraph()
		StrikeState.TELEGRAPH:
			_state_elapsed += delta
			_move_to_strike_start(scaled_delta)
			if _state_elapsed >= telegraph_time:
				_begin_dash()
		StrikeState.DASH:
			_state_elapsed += scaled_delta
			velocity = _strike_tangent * dash_speed
			move_and_slide()
			_dash_distance = global_position.distance_to(_strike_start)
			if _dash_distance >= strike_half_length * 2.0 or _state_elapsed >= 0.82:
				_end_dash()
		StrikeState.RECOVER:
			_state_elapsed += delta
			velocity = velocity.move_toward(Vector2.ZERO, dash_speed * 2.0 * scaled_delta)
			move_and_slide()
			if _state_elapsed >= recover_time:
				_state = StrikeState.WATCHING
				_state_elapsed = 0.0


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _watch_player(delta: float) -> void:
	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.001:
		return
	var tangent := to_player.normalized().orthogonal()
	var desired := tangent * watch_max_speed * 0.62
	if distance > preferred_watch_distance:
		desired += to_player.normalized() * watch_max_speed
	elif distance < preferred_watch_distance * 0.55:
		desired -= to_player.normalized() * watch_max_speed * 0.7
	velocity = velocity.move_toward(desired.limit_length(watch_max_speed), watch_acceleration * delta)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 8.0, 0.0, 1.0))


func _move_to_strike_start(delta: float) -> void:
	var to_start := _strike_start - global_position
	if to_start.length() <= 18.0:
		velocity = velocity.move_toward(Vector2.ZERO, dash_speed * delta)
	else:
		velocity = velocity.move_toward(to_start.normalized() * dash_speed * 0.48, dash_speed * delta)
	move_and_slide()
	rotation = lerp_angle(rotation, _strike_tangent.angle(), clampf(delta * 9.0, 0.0, 1.0))


func _player_is_in_periapsis_state() -> bool:
	var player_velocity := _body_velocity(_player)
	var speed := player_velocity.length()
	if speed < trigger_speed:
		return false
	var source := _nearest_player_gravity_source()
	if source == null:
		return false
	var offset := _player.global_position - source.global_position
	var distance := offset.length()
	if distance > gravity_source_distance or distance <= 0.001:
		return false
	var radial := offset / distance
	var tangent := radial.orthogonal()
	if tangent.dot(player_velocity) < 0.0:
		tangent = -tangent
	var tangential_speed := player_velocity.dot(tangent)
	var radial_speed := player_velocity.dot(radial)
	var entering_or_turning := radial_speed < -trigger_speed * 0.08 or absf(radial_speed) < trigger_speed * 0.24
	return tangential_speed >= trigger_speed * 0.62 and (entering_or_turning or _recent_high_grade_slingshot())


func _recent_high_grade_slingshot() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var last_time_value: Variant = _player.get("last_slingshot_time")
	if not (last_time_value is float or last_time_value is int):
		return false
	var age := Time.get_ticks_msec() * 0.001 - float(last_time_value)
	if age > 0.82:
		return false
	var grade := StringName(_player.get("last_slingshot_grade"))
	return grade == &"perfect" or grade == &"apex"


func _begin_telegraph() -> void:
	var player_velocity := _body_velocity(_player)
	var source := _nearest_player_gravity_source()
	var tangent := player_velocity.normalized() if player_velocity.length_squared() > 1.0 else Vector2.RIGHT
	if source != null:
		var radial := (_player.global_position - source.global_position).normalized()
		tangent = radial.orthogonal()
		if tangent.dot(player_velocity) < 0.0:
			tangent = -tangent
	_strike_tangent = tangent.normalized()
	_strike_center = _player.global_position + player_velocity * telegraph_time * 0.42
	_strike_start = _strike_center - _strike_tangent * strike_half_length
	_strike_end = _strike_center + _strike_tangent * strike_half_length
	_state = StrikeState.TELEGRAPH
	_state_elapsed = 0.0
	_dash_distance = 0.0
	_dash_hit_ids.clear()
	_ensure_warning_nodes()
	_update_warning_visuals()


func _begin_dash() -> void:
	global_position = _strike_start
	velocity = _strike_tangent * dash_speed
	_state = StrikeState.DASH
	_state_elapsed = 0.0
	_dash_distance = 0.0
	_dash_hit_ids.clear()
	if _attack_area != null:
		_attack_area.monitoring = true
	periapsis_strike_started.emit({
		"start": _strike_start,
		"end": _strike_end,
		"center": _strike_center,
		"damage": damage,
		"speed": dash_speed,
	})


func _end_dash() -> void:
	_state = StrikeState.RECOVER
	_state_elapsed = 0.0
	_cooldown_remaining = cooldown
	velocity *= 0.16
	_cleanup_warning_nodes()


func _nearest_player_gravity_source() -> Node2D:
	if _gravity_sources.is_empty():
		_refresh_player_gravity_sources()
	return _gravity_sources[0] if not _gravity_sources.is_empty() else null


func _refresh_player_gravity_sources() -> void:
	_gravity_elapsed = 0.0
	_gravity_sources.clear()
	if _player == null or not is_instance_valid(_player):
		return
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_player.global_position,
			_gravity_sources,
			1,
			gravity_source_distance * 1.35,
			self
		)
		return
	var best: Node2D = null
	var best_distance := gravity_source_distance * gravity_source_distance * 1.82
	var seen: Dictionary = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var source := node as Node2D
			if source == null or source == self or not is_instance_valid(source) or source.is_queued_for_deletion():
				continue
			var id := source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			var distance := source.global_position.distance_squared_to(_player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = source
	if best != null:
		_gravity_sources.append(best)


func _build_body() -> void:
	_core = Polygon2D.new()
	_core.name = "MantisCore"
	_core.color = Color(0.95, 0.18, 0.08, 1.0)
	_core.polygon = PackedVector2Array([
		Vector2(48.0, 0.0),
		Vector2(8.0, 18.0),
		Vector2(-34.0, 12.0),
		Vector2(-44.0, 0.0),
		Vector2(-34.0, -12.0),
		Vector2(8.0, -18.0),
	])
	add_child(_core)

	_wing = Polygon2D.new()
	_wing.name = "PeriapsisGlyph"
	_wing.z_index = -1
	_wing.color = Color(1.0, 0.46, 0.12, 0.2)
	_wing.polygon = PackedVector2Array([
		Vector2(18.0, -42.0),
		Vector2(-16.0, -18.0),
		Vector2(-52.0, 0.0),
		Vector2(-16.0, 18.0),
		Vector2(18.0, 42.0),
		Vector2(2.0, 0.0),
	])
	add_child(_wing)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)

	_attack_area = Area2D.new()
	_attack_area.name = "StrikeArea"
	_attack_area.monitoring = true
	_attack_area.body_entered.connect(_on_strike_area_body_entered)
	var shape := CollisionShape2D.new()
	shape.name = "StrikeShape"
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	_attack_area.add_child(shape)
	add_child(_attack_area)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _ensure_warning_nodes() -> void:
	if _warning_line == null or not is_instance_valid(_warning_line):
		_warning_line = Line2D.new()
		_warning_line.name = "PeriapsisMantisWarningBeam"
		_warning_line.z_index = 34
		_warning_line.antialiased = true
		_warning_line.width = 8.0
		_warning_line.default_color = Color(1.0, 0.2, 0.05, 0.22)
		_add_effect_node(_warning_line)
	if _warning_glyph == null or not is_instance_valid(_warning_glyph):
		_warning_glyph = Line2D.new()
		_warning_glyph.name = "PeriapsisMantisStrikeGlyph"
		_warning_glyph.z_index = 35
		_warning_glyph.antialiased = true
		_warning_glyph.closed = true
		_warning_glyph.width = 2.6
		_add_effect_node(_warning_glyph)


func _update_warning_visuals() -> void:
	if _warning_line == null or not is_instance_valid(_warning_line):
		return
	var telegraph_ratio := clampf(_state_elapsed / maxf(telegraph_time, 0.001), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.038)
	var alpha := Settings.world_visual_alpha(lerpf(0.16, 0.48, maxf(telegraph_ratio, pulse * 0.45)), 0.34)
	_warning_line.points = PackedVector2Array([_strike_start, _strike_end])
	_warning_line.width = lerpf(5.0, 12.0, telegraph_ratio)
	_warning_line.default_color = Settings.apply_readability_color(Color(1.0, 0.18, 0.04, alpha))
	if _warning_glyph != null and is_instance_valid(_warning_glyph):
		_warning_glyph.points = _diamond_points(_strike_center, 54.0 + 28.0 * telegraph_ratio, _strike_tangent.angle())
		_warning_glyph.default_color = Settings.apply_readability_color(Color(1.0, 0.7, 0.18, alpha))


func _update_body_visuals(delta: float) -> void:
	if _core != null:
		var armed := 1.0 - clampf(_cooldown_remaining / maxf(cooldown, 0.001), 0.0, 1.0)
		_core.color = Settings.apply_readability_color(Color(0.72 + 0.28 * armed, 0.1 + 0.16 * armed, 0.08, 1.0))
	if _wing != null:
		_wing.rotation += delta * (1.6 if _state == StrikeState.TELEGRAPH else 0.45)
		_wing.color.a = Settings.world_visual_alpha(0.12 + 0.16 * float(_state == StrikeState.TELEGRAPH), 0.24)


func _on_strike_area_body_entered(body: Node) -> void:
	if _state != StrikeState.DASH or body == null or body == self or not is_instance_valid(body):
		return
	var id := body.get_instance_id()
	if _dash_hit_ids.has(id):
		return
	_dash_hit_ids[id] = true
	var body_2d := body as Node2D
	var push_dir := _strike_tangent
	if body_2d != null and body_2d.global_position.distance_squared_to(global_position) > 0.001:
		push_dir = (body_2d.global_position - global_position).normalized().lerp(_strike_tangent, 0.55).normalized()
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", damage)
		CombatStatus.add_velocity(body, push_dir * dash_speed * 0.34)
	elif (body.is_in_group("enemies") or body.is_in_group("wave_enemy") or body.is_in_group("bosses")) and body.has_method("take_damage"):
		body.call("take_damage", damage * 0.82)
		CombatStatus.add_velocity(body, push_dir * dash_speed * 0.24)


func _on_died() -> void:
	_cleanup_warning_nodes()
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.18, true)
	queue_free()


func _add_effect_node(node: Node) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		add_child(node)
		return
	parent.add_child(node)


func _cleanup_warning_nodes() -> void:
	if _warning_line != null and is_instance_valid(_warning_line) and not _warning_line.is_queued_for_deletion():
		_warning_line.queue_free()
	if _warning_glyph != null and is_instance_valid(_warning_glyph) and not _warning_glyph.is_queued_for_deletion():
		_warning_glyph.queue_free()
	_warning_line = null
	_warning_glyph = null


func _body_velocity(body: Node) -> Vector2:
	if body == null or not is_instance_valid(body):
		return Vector2.ZERO
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	return Vector2.ZERO


func _diamond_points(center: Vector2, radius: float, angle: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2.RIGHT.rotated(angle) * radius,
		center + Vector2.DOWN.rotated(angle) * radius * 0.55,
		center - Vector2.RIGHT.rotated(angle) * radius,
		center - Vector2.DOWN.rotated(angle) * radius * 0.55,
	])
