extends CharacterBody2D
class_name ResonanceParalyticConstruct

signal resonance_feedback_triggered(feedback_data: Dictionary)

const FREQUENCIES: Array[StringName] = [&"compression", &"slipstream", &"inversion", &"temporal_scar", &"harmonic_orbit"]

@export var max_health: float = 112.0
@export var field_radius: float = 460.0
@export var frequency_cycle_time: float = 2.4
@export var control_damping: float = 0.2
@export var paralytic_damage: float = 8.0
@export var feedback_damage: float = 22.0
@export var drift_speed: float = 120.0
@export var max_targets_per_tick: int = 28

var _player: Node2D = null
var _health: HealthComponent = null
var _resonance_manager: Node = null
var _frequency_index := 0
var _frequency_elapsed := 0.0
var _ring: Line2D = null
var _core: Polygon2D = null


func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	_frequency_elapsed += delta
	if _frequency_elapsed >= frequency_cycle_time:
		_frequency_elapsed = 0.0
		_frequency_index = (_frequency_index + 1) % FREQUENCIES.size()
	_resolve_resonance_manager()
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return
	var to_player := _player.global_position - global_position
	if to_player.length() > field_radius * 0.82:
		velocity = velocity.lerp(to_player.normalized() * drift_speed, clampf(scaled_delta * 2.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(to_player.normalized().orthogonal() * drift_speed * 0.5, clampf(scaled_delta * 2.0, 0.0, 1.0))
	move_and_slide()
	_apply_paralytic_field(delta)


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _apply_paralytic_field(delta: float) -> void:
	var desired := _current_frequency()
	var affected := 0
	for group_name in [&"Player", &"Projectiles", &"player_projectiles", &"enemy_projectiles"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if affected >= max_targets_per_tick:
				return
			var body := node as Node2D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var distance := body.global_position.distance_to(global_position)
			if distance > field_radius:
				continue
			var match_quality := _frequency_match_quality(body, desired)
			if match_quality >= 0.72:
				_trigger_feedback(body, desired, match_quality)
			else:
				_apply_paralysis(body, desired, 1.0 - match_quality, delta)
			affected += 1


func _frequency_match_quality(body: Node2D, desired: StringName) -> float:
	var frequency := StringName(body.get_meta(&"resonance_frequency", &"none"))
	if frequency == desired:
		return clampf(float(body.get_meta(&"resonance_frequency_intensity", 0.8)), 0.0, 1.0)
	if body == _player:
		var zone := _player_zone()
		if not zone.is_empty() and StringName(zone.get("zone_type_name", &"none")) == desired:
			return clampf(float(zone.get("local_intensity", zone.get("intensity", 0.7))), 0.0, 1.0)
		var velocity := _body_velocity(body)
		if velocity.length_squared() > 1.0:
			var angle_score := absf(cos(velocity.angle() - global_position.direction_to(body.global_position).orthogonal().angle()))
			return clampf(angle_score * 0.62, 0.0, 0.7)
	return 0.0


func _apply_paralysis(body: Node2D, frequency: StringName, pressure: float, delta: float) -> void:
	var velocity := _body_velocity(body)
	if velocity.length_squared() > 1.0:
		_set_body_velocity(body, velocity * (1.0 - control_damping * pressure))
	CombatStatus.apply_local_time_scale(body, clampf(1.0 - pressure * 0.28, 0.58, 1.0), 0.18)
	body.set_meta(&"paralytic_frequency_mismatch", frequency)
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", paralytic_damage * pressure * delta)


func _trigger_feedback(body: Node2D, frequency: StringName, match_quality: float) -> void:
	if _health != null:
		_health.take_damage(feedback_damage * match_quality)
	CombatStatus.add_velocity(self, (global_position - body.global_position).normalized() * 140.0 * match_quality)
	resonance_feedback_triggered.emit({
		"position": global_position,
		"frequency": frequency,
		"match_quality": match_quality,
	})
	if _resonance_manager != null and _resonance_manager.has_method("create_manual_resonance_zone"):
		_resonance_manager.call(
			"create_manual_resonance_zone",
			global_position,
			field_radius * 0.52,
			_zone_type_for_frequency(frequency),
			0.48 + 0.24 * match_quality,
			1.0
		)


func _player_zone() -> Dictionary:
	if _resonance_manager == null or not _resonance_manager.has_method("get_resonance_zone_at_position") or _player == null:
		return {}
	var zone_value: Variant = _resonance_manager.call("get_resonance_zone_at_position", _player.global_position)
	return zone_value if typeof(zone_value) == TYPE_DICTIONARY else {}


func _resolve_resonance_manager() -> void:
	if _resonance_manager != null and is_instance_valid(_resonance_manager):
		return
	var root := get_tree().current_scene
	if root != null:
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)


func _current_frequency() -> StringName:
	return FREQUENCIES[_frequency_index % FREQUENCIES.size()]


func _zone_type_for_frequency(frequency: StringName) -> int:
	match frequency:
		&"slipstream":
			return GravityResonanceManager.ZoneType.SLIPSTREAM
		&"inversion":
			return GravityResonanceManager.ZoneType.INVERSION
		&"temporal_scar":
			return GravityResonanceManager.ZoneType.TEMPORAL_SCAR
		&"harmonic_orbit":
			return GravityResonanceManager.ZoneType.HARMONIC_ORBIT
	return GravityResonanceManager.ZoneType.COMPRESSION


func _build_body() -> void:
	_core = Polygon2D.new()
	_core.name = "ParalyticCore"
	_core.color = Color(0.9, 0.14, 0.24, 1.0)
	_core.polygon = _regular_points(6, 40.0)
	add_child(_core)
	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)
	_ring = Line2D.new()
	_ring.name = "FrequencyField"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.8
	_ring.points = _regular_points(72, field_radius)
	add_child(_ring)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _update_visuals(delta: float) -> void:
	var color := _frequency_color(_current_frequency())
	if _ring != null:
		_ring.rotation += delta * 0.7
		_ring.default_color = Color(color.r, color.g, color.b, 0.38)
	if _core != null:
		_core.color = color
		_core.rotation -= delta * 1.2


func _frequency_color(frequency: StringName) -> Color:
	match frequency:
		&"slipstream":
			return Color(0.08, 1.0, 0.78, 1.0)
		&"inversion":
			return Color(1.0, 0.24, 0.14, 1.0)
		&"temporal_scar":
			return Color(0.72, 0.34, 1.0, 1.0)
		&"harmonic_orbit":
			return Color(0.92, 0.78, 0.26, 1.0)
	return Color(0.28, 0.72, 1.0, 1.0)


func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.18, true)
	queue_free()


func _body_velocity(body: Node) -> Vector2:
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	return Vector2.ZERO


func _set_body_velocity(body: Node, velocity_value: Vector2) -> void:
	if body.get("velocity") is Vector2:
		body.set("velocity", velocity_value)
	elif body.get("linear_velocity") is Vector2:
		body.set("linear_velocity", velocity_value)


func _regular_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := -PI * 0.5 + TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
