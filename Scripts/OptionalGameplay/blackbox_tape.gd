extends Area2D
class_name BlackboxTape

signal tape_collected(tape_id: StringName, collector: Node)

@export var tape_id: StringName = &"blackbox_tape"
@export var unlocks_blackbox_challenges: Array[String] = []
@export var director_group_name: StringName = &"optional_challenge_director"
@export var collect_player_group: StringName = &"Player"
@export var collect_radius: float = 28.0
@export var visual_color: Color = Color(1.0, 0.72, 0.28, 0.96)
@export_multiline var archive_text: String = "Recovered telemetry: impossible vectors are repeatable."

var _collected: bool = false
var _core: Polygon2D = null
var _ring: Line2D = null


func _ready() -> void:
	add_to_group("blackbox_tape")
	_build_collision()
	_build_visuals()
	body_entered.connect(_on_body_entered)


func collect(collector: Node = null) -> void:
	if _collected:
		return
	_collected = true
	var director := get_tree().get_first_node_in_group(director_group_name)
	if director != null and director.has_method("mark_blackbox_tape_collected"):
		director.call("mark_blackbox_tape_collected", tape_id, unlocks_blackbox_challenges)
	elif RunProgress != null:
		RunProgress.record_blackbox_tape_collected(tape_id, unlocks_blackbox_challenges)
	if RunProgress != null:
		RunProgress.arena_flags["blackbox_archive_%s" % String(tape_id)] = archive_text
	tape_collected.emit(tape_id, collector)
	queue_free()


func _process(delta: float) -> void:
	if _core != null:
		_core.rotation += delta * 1.8
	if _ring != null:
		_ring.rotation -= delta * 0.8


func _on_body_entered(body: Node) -> void:
	if body != null and (body.is_in_group(collect_player_group) or (body.get_parent() != null and body.get_parent().is_in_group(collect_player_group))):
		collect(body)


func _build_collision() -> void:
	var collision := get_node_or_null("BlackboxTapeCollision") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "BlackboxTapeCollision"
		add_child(collision)
	var circle := collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision.shape = circle
	circle.radius = collect_radius


func _build_visuals() -> void:
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "BlackboxTapeCore"
		add_child(_core)
	_core.polygon = PackedVector2Array([
		Vector2(-18.0, -11.0),
		Vector2(18.0, -11.0),
		Vector2(18.0, 11.0),
		Vector2(-18.0, 11.0),
	])
	_core.color = visual_color
	_core.z_index = 20
	if _ring == null:
		_ring = Line2D.new()
		_ring.name = "BlackboxTapeRing"
		_ring.closed = true
		_ring.antialiased = true
		_ring.width = 1.5
		_ring.points = _circle_points(collect_radius * 1.3, 32)
		add_child(_ring)
	_ring.default_color = Color(visual_color.r, visual_color.g, visual_color.b, 0.32)
	_ring.z_index = 19


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
