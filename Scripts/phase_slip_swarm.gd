extends CharacterBody2D
class_name PhaseSlipSwarm

@export var max_health: float = 54.0
@export var max_speed: float = 640.0
@export var acceleration: float = 760.0
@export var drag: float = 0.9
@export var contact_damage: float = 13.0
@export var phase_count: int = 4
@export var phase_history_step: int = 5
@export var history_limit: int = 36
@export var phase_proxy_radius: float = 22.0
@export var jitter_strength: float = 180.0
@export var offscreen_simulation_distance: float = 2200.0
@export var offscreen_simulation_interval: float = 0.08

var _player: Node2D = null
var _health: HealthComponent = null
var _history: Array[Vector2] = []
var _phase_proxies: Array[Area2D] = []
var _rng := RandomNumberGenerator.new()
var _simulation_accumulator: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	set_physics_process(true)
	set_process(true)


func _process(delta: float) -> void:
	if _should_use_coarse_simulation():
		return
	_update_history()
	_update_phase_proxies(delta)


func _physics_process(delta: float) -> void:
	var scaled_delta := delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return
	if _should_use_coarse_simulation():
		_simulation_accumulator += scaled_delta
		if _simulation_accumulator < maxf(offscreen_simulation_interval, 0.016):
			return
		scaled_delta = _simulation_accumulator
		_simulation_accumulator = 0.0
	else:
		_simulation_accumulator = 0.0
	var player_velocity := _body_velocity(_player)
	var predicted := _player.global_position + player_velocity * 0.22
	var direction := (predicted - global_position).normalized()
	var jitter := Vector2.RIGHT.rotated(Time.get_ticks_msec() / 180.0 + float(get_instance_id()) * 0.07)
	velocity += (direction * acceleration + jitter * jitter_strength) * scaled_delta
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(scaled_delta * 8.0, 0.0, 1.0))


func take_damage(amount: float) -> void:
	velocity += Vector2.RIGHT.rotated(_rng.randf() * TAU) * 180.0
	if _health != null:
		_health.take_damage(amount)


func _update_history() -> void:
	if _history.is_empty() or _history[_history.size() - 1].distance_to(global_position) > 18.0:
		_history.append(global_position)
	while _history.size() > history_limit:
		_history.remove_at(0)


func _update_phase_proxies(delta: float) -> void:
	for i in range(_phase_proxies.size()):
		var proxy := _phase_proxies[i]
		if proxy == null or not is_instance_valid(proxy):
			continue
		var history_index := maxi(_history.size() - 1 - (i + 1) * phase_history_step, 0)
		var target_position := _history[history_index] if _history.size() > history_index else global_position
		var jitter := Vector2.RIGHT.rotated(Time.get_ticks_msec() / 220.0 + float(i) * TAU / float(maxi(_phase_proxies.size(), 1))) * (10.0 + float(i) * 4.0)
		proxy.global_position = proxy.global_position.lerp(target_position + jitter, clampf(delta * 12.0, 0.0, 1.0))
		proxy.rotation += delta * (2.0 + float(i))
		var glyph := proxy.get_node_or_null("PhaseGlyph") as Polygon2D
		if glyph != null:
			glyph.color.a = 0.14 + 0.24 * sin(Time.get_ticks_msec() / 130.0 + float(i))


func _build_body() -> void:
	var core := Polygon2D.new()
	core.name = "PhaseCore"
	core.color = Color(0.95, 0.18, 0.34, 1.0)
	core.polygon = PackedVector2Array([Vector2(34, 0), Vector2(8, 24), Vector2(-26, 16), Vector2(-34, 0), Vector2(-26, -16), Vector2(8, -24)])
	add_child(core)
	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)

	for i in range(maxi(phase_count - 1, 1)):
		var proxy := Area2D.new()
		proxy.name = "PhaseProxy%d" % i
		proxy.monitoring = true
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = phase_proxy_radius
		shape.shape = circle
		proxy.add_child(shape)
		var glyph := Polygon2D.new()
		glyph.name = "PhaseGlyph"
		glyph.color = Color(0.95, 0.18, 0.34, 0.26)
		glyph.polygon = _circle_points(8, phase_proxy_radius)
		proxy.add_child(glyph)
		proxy.body_entered.connect(_on_phase_proxy_body_entered)
		add_child(proxy)
		_phase_proxies.append(proxy)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _on_phase_proxy_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)
		CombatStatus.add_velocity(body, (body.global_position - global_position).normalized() * 180.0)


func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.12)
	queue_free()


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


func _should_use_coarse_simulation() -> bool:
	if offscreen_simulation_distance <= 0.0:
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	return global_position.distance_squared_to(_player.global_position) > offscreen_simulation_distance * offscreen_simulation_distance


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
