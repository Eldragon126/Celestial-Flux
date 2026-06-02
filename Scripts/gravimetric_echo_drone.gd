extends CharacterBody2D
class_name GravimetricEchoDrone

signal echo_replay_spawned(echo_data: Dictionary)

const RECORDABLE_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]

@export var max_health: float = 62.0
@export var contact_damage: float = 12.0
@export var record_radius: float = 760.0
@export var sample_interval: float = 0.08
@export var replay_interval: float = 2.2
@export var echo_speed: float = 1.25
@export var echo_damage: float = 16.0
@export var echo_radius: float = 34.0
@export var max_path_samples: int = 56
@export var max_active_echoes: int = 4

var _player: Node2D = null
var _health: HealthComponent = null
var _path_samples: Array[Vector2] = []
var _echoes: Array[Dictionary] = []
var _sample_elapsed := 999.0
var _replay_elapsed := 0.0
var _field_ring: Line2D = null
var _recordable_targets: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")


func _process(delta: float) -> void:
	_sample_elapsed += delta
	_replay_elapsed += delta
	if _sample_elapsed >= sample_interval:
		_sample_elapsed = 0.0
		_record_nearby_motion()
	if _replay_elapsed >= replay_interval:
		_replay_elapsed = 0.0
		_spawn_echo_replay()
	_update_echoes(delta)
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	move_and_slide()


func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)


func _record_nearby_motion() -> void:
	var target := _nearest_recordable_body()
	if target == null:
		return
	_path_samples.append(target.global_position)
	while _path_samples.size() > max_path_samples:
		_path_samples.remove_at(0)


func _nearest_recordable_body() -> Node2D:
	var best: Node2D = null
	var best_distance := record_radius * record_radius
	_fill_targets_in_radius(RECORDABLE_GROUPS, global_position, record_radius, max_path_samples, true, _recordable_targets)
	for body in _recordable_targets:
		if body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var distance := body.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


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


func _spawn_echo_replay() -> void:
	if _path_samples.size() < 8 or _echoes.size() >= max_active_echoes:
		return
	var echo := Area2D.new()
	echo.name = "GravimetricEchoReplay"
	echo.monitoring = true
	echo.z_index = 28
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = echo_radius
	shape.shape = circle
	echo.add_child(shape)
	var poly := Polygon2D.new()
	poly.name = "EchoGlyph"
	poly.color = Color(0.35, 0.9, 1.0, 0.24)
	poly.polygon = _circle_points(14, echo_radius)
	echo.add_child(poly)
	get_tree().current_scene.add_child(echo)
	echo.body_entered.connect(_on_echo_body_entered.bind(echo))

	var data := {
		"echo": echo,
		"path": _path_samples.duplicate(),
		"progress": 0.0,
		"glyph": poly,
	}
	_echoes.append(data)
	echo_replay_spawned.emit(data.duplicate(true))


func _update_echoes(delta: float) -> void:
	for idx in range(_echoes.size() - 1, -1, -1):
		var data := _echoes[idx]
		var echo := data.get("echo") as Area2D
		if echo == null or not is_instance_valid(echo):
			_echoes.remove_at(idx)
			continue
		var path: Array = data.get("path", [])
		if path.size() < 2:
			echo.queue_free()
			_echoes.remove_at(idx)
			continue
		data["progress"] = float(data.get("progress", 0.0)) + delta * echo_speed
		var progress := float(data["progress"])
		var segment := int(floor(progress))
		if segment >= path.size() - 1:
			echo.queue_free()
			_echoes.remove_at(idx)
			continue
		var t := progress - float(segment)
		echo.global_position = (path[segment] as Vector2).lerp(path[segment + 1] as Vector2, t)
		var glyph := data.get("glyph") as Polygon2D
		if glyph != null:
			glyph.rotation += delta * 4.0
			glyph.color.a = 0.18 + 0.18 * sin(Time.get_ticks_msec() / 110.0 + progress)
		_echoes[idx] = data


func _on_echo_body_entered(body: Node, echo: Area2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", echo_damage)
		CombatStatus.add_velocity(body, (body.global_position - echo.global_position).normalized() * 260.0)
		body.set_meta(&"trajectory_prediction_disrupted", Time.get_ticks_msec() / 1000.0 + 0.7)
		echo.queue_free()


func _build_body() -> void:
	var core := Polygon2D.new()
	core.name = "EchoDroneCore"
	core.color = Color(0.18, 0.54, 0.95, 1.0)
	core.polygon = PackedVector2Array([Vector2(0, -30), Vector2(32, 0), Vector2(0, 30), Vector2(-32, 0)])
	add_child(core)
	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)
	_field_ring = Line2D.new()
	_field_ring.name = "EchoRecordRing"
	_field_ring.closed = true
	_field_ring.antialiased = true
	_field_ring.width = 1.6
	_field_ring.points = _circle_points(48, record_radius * 0.18)
	_field_ring.default_color = Color(0.35, 0.9, 1.0, 0.28)
	add_child(_field_ring)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _update_visuals(delta: float) -> void:
	if _field_ring == null:
		return
	_field_ring.rotation += delta * 0.8
	_field_ring.scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 300.0))


func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.1)
	queue_free()


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
