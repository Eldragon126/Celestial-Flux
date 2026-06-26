extends Area2D
class_name VectorTunnel

signal tunnel_entered(body: Node)
signal tunnel_exited(body: Node)

@export var tunnel_force: float = 1450.0
@export var tunnel_speed_cap: float = 1350.0
@export var tunnel_direction: Vector2 = Vector2.RIGHT
@export var tunnel_size: Vector2 = Vector2(560.0, 140.0)
@export var player_group_name: StringName = &"Player"
@export_range(0.0, 1.0, 0.01) var lateral_damping: float = 0.18
@export var tunnel_color: Color = Color(0.36, 0.86, 1.0, 0.18)
@export var vector_color: Color = Color(0.56, 1.0, 0.82, 0.5)

var _inside: Array[Node] = []
var _collision: CollisionShape2D = null
var _field: Polygon2D = null
var _vector_line: Line2D = null


func _ready() -> void:
	add_to_group("vector_tunnel")
	_build_collision()
	_build_visuals()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	var direction := (tunnel_direction if tunnel_direction.length_squared() > 0.001 else Vector2.RIGHT).normalized()
	for index in range(_inside.size() - 1, -1, -1):
		var body := _inside[index]
		if body == null or not is_instance_valid(body):
			_inside.remove_at(index)
			continue
		var velocity_value: Variant = body.get("velocity")
		if not (velocity_value is Vector2):
			continue
		var velocity := velocity_value as Vector2
		var forward_speed := velocity.dot(direction)
		var lateral := velocity - direction * forward_speed
		velocity += direction * tunnel_force * delta
		velocity -= lateral * clampf(lateral_damping, 0.0, 1.0)
		velocity = velocity.limit_length(tunnel_speed_cap)
		body.set("velocity", velocity)


func _process(delta: float) -> void:
	if _vector_line != null:
		_vector_line.position += tunnel_direction.normalized() * delta * 24.0
		if _vector_line.position.length() > 18.0:
			_vector_line.position = Vector2.ZERO


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group(player_group_name):
		return
	if not _inside.has(body):
		_inside.append(body)
	tunnel_entered.emit(body)


func _on_body_exited(body: Node) -> void:
	_inside.erase(body)
	tunnel_exited.emit(body)


func _build_collision() -> void:
	_collision = get_node_or_null("VectorTunnelCollision") as CollisionShape2D
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "VectorTunnelCollision"
		add_child(_collision)
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision.shape = shape
	shape.size = tunnel_size


func _build_visuals() -> void:
	if _field == null:
		_field = Polygon2D.new()
		_field.name = "VectorTunnelField"
		add_child(_field)
	var half := tunnel_size * 0.5
	_field.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	_field.color = tunnel_color
	_field.z_index = 11
	if _vector_line == null:
		_vector_line = Line2D.new()
		_vector_line.name = "VectorTunnelFlow"
		_vector_line.antialiased = true
		_vector_line.width = 2.0
		add_child(_vector_line)
	var direction := (tunnel_direction if tunnel_direction.length_squared() > 0.001 else Vector2.RIGHT).normalized()
	var tangent := direction.orthogonal()
	_vector_line.points = PackedVector2Array([
		-direction * tunnel_size.x * 0.44 - tangent * 22.0,
		direction * tunnel_size.x * 0.44 - tangent * 22.0,
		-direction * tunnel_size.x * 0.44 + tangent * 22.0,
		direction * tunnel_size.x * 0.44 + tangent * 22.0,
	])
	_vector_line.default_color = vector_color
	_vector_line.z_index = 12
