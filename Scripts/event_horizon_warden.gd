extends CharacterBody2D
class_name EventHorizonWarden

signal collapse_field_expanded(radius: float, intensity: float)

@export var mass: float = 420000.0
@export var max_health: float = 150.0
@export var move_speed: float = 190.0
@export var anchor_distance: float = 620.0
@export var anchor_lock_time: float = 1.8
@export var field_start_radius: float = 180.0
@export var field_max_radius: float = 720.0
@export var field_expand_rate: float = 42.0
@export var pull_force: float = 720.0
@export var boundary_shear: float = 310.0
@export var contact_damage: float = 22.0
@export var max_targets_per_tick: int = 42

var _player: Node2D = null
var _health: HealthComponent = null
var _anchored := false
var _anchor_timer := 0.0
var _field_radius := 180.0
var _ring: Line2D = null
var _core: Polygon2D = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_field_radius = field_start_radius
	_build_body()
	_build_health()
	set_physics_process(true)
	set_process(true)


func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation += delta * (0.35 if _anchored else 0.9)
		_ring.points = _circle_points(72, _field_radius)
		_ring.default_color = Color(1.0, 0.24, 0.14, 0.28 + 0.22 * _field_intensity())
	if _core != null:
		_core.rotation -= delta * 1.4


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return

	if not _anchored:
		_seek_anchor(delta)
	else:
		_expand_and_pull(delta)
	move_and_slide()


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _seek_anchor(delta: float) -> void:
	var to_player := _player.global_position - global_position
	var distance := maxf(to_player.length(), 1.0)
	var desired_position := _player.global_position - to_player.normalized() * anchor_distance
	var to_anchor := desired_position - global_position
	velocity = velocity.lerp(to_anchor.normalized() * move_speed, clampf(delta * 2.2, 0.0, 1.0)).limit_length(move_speed)
	if distance <= anchor_distance * 1.16 or to_anchor.length() < 80.0:
		_anchor_timer += delta
		if _anchor_timer >= anchor_lock_time:
			_anchored = true
			velocity = Vector2.ZERO
	else:
		_anchor_timer = maxf(_anchor_timer - delta, 0.0)


func _expand_and_pull(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	_field_radius = minf(_field_radius + field_expand_rate * delta, field_max_radius)
	_apply_collapse_field(delta)
	collapse_field_expanded.emit(_field_radius, _field_intensity())


func _apply_collapse_field(delta: float) -> void:
	var radius_squared := _field_radius * _field_radius
	var affected := 0
	for group_name in [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if affected >= max_targets_per_tick:
				return
			var body := node as Node2D
			if body == null or body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var offset := global_position - body.global_position
			var distance_squared := offset.length_squared()
			if distance_squared <= 0.001 or distance_squared > radius_squared:
				continue
			var distance := sqrt(distance_squared)
			var radial := offset / distance
			var falloff := 1.0 - clampf(distance / _field_radius, 0.0, 1.0)
			var boundary := 1.0 - absf(distance - _field_radius * 0.82) / maxf(_field_radius * 0.18, 1.0)
			var impulse := radial * pull_force * falloff
			if boundary > 0.0:
				impulse += radial.orthogonal() * boundary_shear * clampf(boundary, 0.0, 1.0)
			CombatStatus.add_velocity(body, impulse * delta)
			if distance < 58.0 and body.has_method("take_damage"):
				body.call("take_damage", contact_damage * delta)
			affected += 1


func _field_intensity() -> float:
	return clampf((_field_radius - field_start_radius) / maxf(field_max_radius - field_start_radius, 1.0), 0.0, 1.0)


func _build_body() -> void:
	_core = Polygon2D.new()
	_core.name = "WardenCore"
	_core.color = Color(0.82, 0.12, 0.12, 1.0)
	_core.polygon = _circle_points(9, 46.0)
	add_child(_core)
	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = _core.polygon
	add_child(collision)
	_ring = Line2D.new()
	_ring.name = "CollapseBoundary"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 3.0
	_ring.points = _circle_points(72, _field_radius)
	add_child(_ring)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.18, true)
	queue_free()


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
