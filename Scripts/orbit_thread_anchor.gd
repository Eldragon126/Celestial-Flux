extends CharacterBody2D
class_name OrbitThreadAnchor

signal anchor_destroyed(anchor: OrbitThreadAnchor)

@export var max_health: float = 34.0

var current_health: float = 34.0
var _core: Polygon2D = null
var _ring: Line2D = null
var _anchor_color: Color = Color(0.18, 0.92, 1.0, 1.0)


func configure(anchor_health: float, anchor_color: Color) -> void:
	max_health = maxf(anchor_health, 1.0)
	current_health = max_health
	_anchor_color = anchor_color
	_apply_visual_state()


func _ready() -> void:
	add_to_group("orbit_thread_anchor")
	current_health = max_health
	_build_body()
	_apply_visual_state()


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	_apply_visual_state()
	if current_health <= 0.0:
		anchor_destroyed.emit(self)
		queue_free()


func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation += delta * 1.4
	if _core != null:
		_core.rotation -= delta * 0.8


func _build_body() -> void:
	_core = Polygon2D.new()
	_core.name = "AnchorKnotCore"
	_core.polygon = _regular_points(6, 26.0)
	add_child(_core)

	var collision := CollisionShape2D.new()
	collision.name = "AnchorKnotCollision"
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	collision.shape = circle
	add_child(collision)

	_ring = Line2D.new()
	_ring.name = "AnchorKnotRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.4
	_ring.points = _regular_points(28, 38.0)
	add_child(_ring)


func _apply_visual_state() -> void:
	var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var color := Settings.apply_readability_color(_anchor_color)
	if _core != null:
		_core.color = Color(color.r, color.g, color.b, 0.52 + 0.48 * health_ratio)
	if _ring != null:
		_ring.default_color = Color(color.r, color.g, color.b, Settings.world_visual_alpha(0.16 + 0.28 * health_ratio, 0.32))
		_ring.width = lerpf(1.2, 3.0, health_ratio)


func _regular_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := -PI * 0.5 + TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
