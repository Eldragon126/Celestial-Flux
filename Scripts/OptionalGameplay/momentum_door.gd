extends Area2D
class_name MomentumDoor

signal door_opened(opener: Node, speed: float)
signal door_rejected(opener: Node, speed: float)

@export var required_speed: float = 900.0
@export var required_direction: Vector2 = Vector2.RIGHT
@export_range(0.0, 1.0, 0.01) var direction_alignment: float = 0.28
@export var one_time_open: bool = true
@export var stay_open_seconds: float = 2.5
@export var door_size: Vector2 = Vector2(48.0, 220.0)
@export var player_group_name: StringName = &"Player"
@export var closed_color: Color = Color(1.0, 0.42, 0.18, 0.86)
@export var open_color: Color = Color(0.34, 1.0, 0.78, 0.62)

var open: bool = false
var _open_remaining: float = 0.0
var _collision: CollisionShape2D = null
var _visual: Polygon2D = null


func _ready() -> void:
	add_to_group("momentum_door")
	_build_collision()
	_build_visuals()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if open and not one_time_open:
		_open_remaining = maxf(_open_remaining - delta, 0.0)
		if _open_remaining <= 0.0:
			_set_open(false)
	if _visual != null:
		_visual.color = open_color if open else closed_color


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group(player_group_name):
		return
	var speed := _body_speed(body)
	if _qualifies(body, speed):
		_set_open(true)
		door_opened.emit(body, speed)
	else:
		door_rejected.emit(body, speed)


func _qualifies(body: Node, speed: float) -> bool:
	if speed < required_speed:
		return false
	var velocity: Variant = body.get("velocity")
	if not (velocity is Vector2):
		return true
	var direction := (required_direction if required_direction.length_squared() > 0.001 else Vector2.RIGHT).normalized()
	return (velocity as Vector2).normalized().dot(direction) >= direction_alignment


func _body_speed(body: Node) -> float:
	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		return (velocity as Vector2).length()
	return 0.0


func _set_open(value: bool) -> void:
	open = value
	_open_remaining = maxf(stay_open_seconds, 0.05)
	if _collision != null:
		_collision.disabled = open
	monitoring = not open or not one_time_open


func _build_collision() -> void:
	_collision = get_node_or_null("MomentumDoorCollision") as CollisionShape2D
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "MomentumDoorCollision"
		add_child(_collision)
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision.shape = shape
	shape.size = door_size


func _build_visuals() -> void:
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "MomentumDoorVisual"
		add_child(_visual)
	var half := door_size * 0.5
	_visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	_visual.color = closed_color
	_visual.z_index = 18
