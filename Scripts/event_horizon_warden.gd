extends CharacterBody2D
class_name EventHorizonWarden

signal collapse_field_expanded(radius: float, intensity: float)

const FIELD_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]
const COLLAPSE_RING_WIDTH: float = 3.0

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

@export_group("Visual Caps")
@export var field_visual_radius_cap: float = 360.0
@export_range(0.0, 0.42, 0.01) var field_ring_alpha_cap: float = 0.24

var _player: Node2D = null
var _health: HealthComponent = null
var _anchored := false
var _anchor_timer := 0.0
var _field_radius := 180.0
var _ring: Line2D = null
var _core: Polygon2D = null
var _field_targets: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_field_radius = field_start_radius
	_build_body()
	_build_health()
	set_physics_process(true)
	set_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")


func _process(delta: float) -> void:
	if _ring != null:
		var visual_radius := _visual_radius(_field_radius)
		_ring.rotation += delta * (0.35 if _anchored else 0.9)
		_ring.scale = Vector2.ONE * visual_radius
		_ring.width = COLLAPSE_RING_WIDTH / maxf(visual_radius, 1.0)
		_ring.default_color = _ring_color(0.28 + 0.22 * _field_intensity())
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
	var affected := 0
	_fill_targets_in_radius(FIELD_TARGET_GROUPS, global_position, _field_radius, max_targets_per_tick, true, _field_targets)
	for body in _field_targets:
		if affected >= max_targets_per_tick:
			return
		if body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var offset := global_position - body.global_position
		var distance_squared := offset.length_squared()
		if distance_squared <= 0.001:
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


func _fill_targets_in_radius(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	limit: int,
	include_player: bool,
	out_targets: Array[Node2D]
) -> void:
	out_targets.clear()
	if limit == 0:
		return
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, limit, include_player, out_targets)
		return

	var radius_squared := radius * radius
	var max_count := maxi(limit, 0)
	_query_seen_ids.clear()
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if max_count > 0 and out_targets.size() >= max_count:
				return
			var body := node as Node2D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			if not include_player and body.is_in_group("Player"):
				continue
			var id := body.get_instance_id()
			if _query_seen_ids.has(id):
				continue
			_query_seen_ids[id] = true
			if body.global_position.distance_squared_to(center) > radius_squared:
				continue
			out_targets.append(body)


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
	_ring.width = COLLAPSE_RING_WIDTH / maxf(_visual_radius(_field_radius), 1.0)
	_ring.points = _circle_points(72, 1.0)
	_ring.scale = Vector2.ONE * _visual_radius(_field_radius)
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


func _ring_color(alpha: float) -> Color:
	return Color(1.0, 0.24, 0.14, Settings.world_visual_alpha(alpha, field_ring_alpha_cap))


func _visual_radius(radius: float) -> float:
	return Settings.world_effect_radius(radius, field_visual_radius_cap)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
