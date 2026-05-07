extends CharacterBody2D

@export var mass = 90000.0
@export var distortion_mass = 320000.0
@export var move_speed = 230.0
@export var max_speed = 380.0
@export var max_health = 72.0
@export var distortion_radius = 260.0
@export var shield_drain = 18.0
@export var drain_interval = 0.9
@export var gravity_refresh_interval = 0.5

var _base_mass = 0.0
var _player: Node2D = null
var _health: HealthComponent = null
var _drain_timer: Timer
var _gravity_sources: Array[Node2D] = []
var _gravity_refresh_elapsed = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	_base_mass = mass
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_build_body()
	_build_health()
	_build_timer()
	_refresh_gravity_sources()

func _physics_process(delta: float) -> void:
	var scaled_delta = delta * CombatStatus.get_time_scale(self)
	_gravity_refresh_elapsed += delta
	if _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_gravity_sources()

	var target = _get_nearest_gravity_source()
	if target == null:
		target = _player

	if target != null and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized() * move_speed
		velocity = velocity.lerp(desired, clampf(scaled_delta * 2.0, 0.0, 1.0)).limit_length(max_speed)

	move_and_slide()
	_update_distortion()

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _update_distortion() -> void:
	mass = _base_mass
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return

	var distance = global_position.distance_to(_player.global_position)
	if distance <= distortion_radius:
		mass = distortion_mass
		if _player.has_method("apply_shield_disruption"):
			_player.call("apply_shield_disruption", 0.42, 0.32)

func _build_body() -> void:
	var core = Polygon2D.new()
	core.name = "GravityLeechPolygon"
	core.color = Color(0.16, 0.46, 1.0, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(38.0, 0.0),
		Vector2(10.0, 24.0),
		Vector2(-30.0, 16.0),
		Vector2(-42.0, 0.0),
		Vector2(-30.0, -16.0),
		Vector2(10.0, -24.0),
	])
	add_child(core)

	var field = Polygon2D.new()
	field.name = "DistortionFieldPolygon"
	field.z_index = -1
	field.color = Color(0.16, 0.46, 1.0, 0.12)
	field.polygon = _circle_points(28, 72.0)
	add_child(field)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)

	var drain_area = Area2D.new()
	drain_area.name = "DrainArea"
	drain_area.monitoring = true
	drain_area.body_entered.connect(_on_drain_area_body_entered)
	drain_area.body_exited.connect(_on_drain_area_body_exited)
	add_child(drain_area)

	var drain_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 52.0
	drain_shape.shape = circle
	drain_area.add_child(drain_shape)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

func _build_timer() -> void:
	_drain_timer = Timer.new()
	_drain_timer.name = "ShieldDrainTimer"
	_drain_timer.wait_time = drain_interval
	_drain_timer.timeout.connect(_drain_player_shield)
	add_child(_drain_timer)

func _drain_player_shield() -> void:
	if _player == null or not is_instance_valid(_player):
		_drain_timer.stop()
		return

	var overflow = CombatStatus.damage_shield_only(_player, shield_drain)
	if overflow >= shield_drain and _player.has_method("take_damage"):
		_player.take_damage(8.0)

func _get_nearest_gravity_source() -> Node2D:
	var best: Node2D = null
	var best_distance = INF
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		var distance = global_position.distance_squared_to(source.global_position)
		if distance < best_distance:
			best_distance = distance
			best = source
	return best

func _refresh_gravity_sources() -> void:
	_gravity_refresh_elapsed = 0.0
	_gravity_sources.clear()
	var seen = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d = source as Node2D
			if source_2d == null or source_2d == self:
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source_2d)
	if _gravity_sources.size() > 4:
		_gravity_sources.resize(4)

func _on_drain_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player = body as Node2D
		_drain_timer.start()
		_drain_player_shield()

func _on_drain_area_body_exited(body: Node) -> void:
	if body == _player:
		_drain_timer.stop()

func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.12)
	queue_free()

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
