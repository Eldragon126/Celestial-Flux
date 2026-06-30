extends Area2D
class_name AnomalyShard

signal collected(shard_id: StringName, collector: Node)

@export var shard_id: StringName = &"anomaly_shard"
@export var rift_id: StringName = &""
@export var director_group_name: StringName = &"optional_challenge_director"
@export var collect_player_group: StringName = &"Player"
@export var collect_radius: float = 22.0
@export var shard_value: int = 1
@export var visual_color: Color = Color(0.52, 1.0, 0.88, 0.94)
@export var pulse_speed: float = 3.8

var _shape: CollisionShape2D = null
var _body: Polygon2D = null
var _ring: Line2D = null
var _collected: bool = false


func _ready() -> void:
	add_to_group("anomaly_shard")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"anomaly_shard")
	_build_collision()
	_build_visuals()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"anomaly_shard")


func _process(delta: float) -> void:
	if _body != null:
		_body.rotation += delta * pulse_speed
		_body.scale = Vector2.ONE * (0.86 + sin(Time.get_ticks_msec() * 0.006) * 0.08)
	if _ring != null:
		_ring.rotation -= delta * pulse_speed * 0.45


func collect(collector: Node = null) -> void:
	if _collected:
		return
	_collected = true
	var data := {
		"rift_id": String(rift_id),
		"value": shard_value,
		"position": global_position,
	}
	var director := get_tree().get_first_node_in_group(director_group_name)
	if director != null and director.has_method("mark_shard_collected"):
		director.call("mark_shard_collected", shard_id, data)
	elif RunProgress != null:
		RunProgress.record_anomaly_shard_collected(shard_id, data)
	collected.emit(shard_id, collector)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if _is_collector(body):
		collect(body)


func _on_area_entered(area: Area2D) -> void:
	if _is_collector(area):
		collect(area)


func _is_collector(node: Node) -> bool:
	if node == null:
		return false
	return node.is_in_group(collect_player_group) or (node.get_parent() != null and node.get_parent().is_in_group(collect_player_group))


func _build_collision() -> void:
	_shape = get_node_or_null("AnomalyShardCollision") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "AnomalyShardCollision"
		add_child(_shape)
	var circle := _shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		_shape.shape = circle
	circle.radius = collect_radius


func _build_visuals() -> void:
	if _body == null:
		_body = Polygon2D.new()
		_body.name = "AnomalyShardCore"
		add_child(_body)
	_body.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(14.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-14.0, 0.0),
	])
	_body.color = visual_color
	_body.z_index = 20
	if _ring == null:
		_ring = Line2D.new()
		_ring.name = "AnomalyShardRing"
		_ring.closed = true
		_ring.antialiased = true
		_ring.width = 1.6
		_ring.points = _circle_points(collect_radius * 1.25, 36)
		add_child(_ring)
	_ring.default_color = Color(visual_color.r, visual_color.g, visual_color.b, 0.36)
	_ring.z_index = 19


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
